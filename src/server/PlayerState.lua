--!nonstrict
-- Стан гравця на сервері: множники, бусти, геймпаси, синхронізація з клієнтом, видача нагород.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)

local StateRemote = Net.Get("State")
local NotifyRemote = Net.Get("Notify")

export type Session = {
	passes: { [string]: boolean },
	inGroup: boolean,
	friendsInServer: number,
	joinTime: number,
	giftsClaimed: { [number]: boolean },
	clickSecond: number,
	clicksThisSecond: number,
	racesSinceUpsell: number,
	dirty: boolean,
	onboardingStep: number,
}

local PlayerState = {}

local sessions: { [Player]: Session } = {}

function PlayerState.CreateSession(player: Player): Session
	local session: Session = {
		passes = {},
		inGroup = false,
		friendsInServer = 0,
		joinTime = os.time(),
		giftsClaimed = {},
		clickSecond = 0,
		clicksThisSecond = 0,
		racesSinceUpsell = 0,
		dirty = true,
		onboardingStep = 0,
	}
	sessions[player] = session
	return session
end

function PlayerState.RemoveSession(player: Player)
	sessions[player] = nil
end

function PlayerState.GetSession(player: Player): Session?
	return sessions[player]
end

---------------------------------------------------------------------------
-- Множники
---------------------------------------------------------------------------
function PlayerState.IsBoostActive(data: DataService.Data, key: string): boolean
	local ends = data.boosts[key]
	return ends ~= nil and ends > os.time()
end

function PlayerState.EquipSlots(player: Player): number
	local session = sessions[player]
	local extra = if session and session.passes.ExtraPets then Config.Pets.ExtraSlotsPass else 0
	return Config.Pets.BaseEquipSlots + extra
end

function PlayerState.PetMultiplier(data: DataService.Data): number
	local mult = 1
	for _, pet in data.pets do
		if pet.equipped then
			local def = Config.GetPetDef(pet.name)
			if def then
				mult += def.boost - 1
			end
		end
	end
	return mult
end

function PlayerState.SpeedMultiplier(player: Player, data: DataService.Data): number
	local session = sessions[player]
	local mult = (1 + data.rebirths * Config.Rebirth.SpeedMultPerRebirth) * PlayerState.PetMultiplier(data)
	if session then
		if session.passes.DoubleSpeed then
			mult *= 2
		end
		if session.inGroup then
			mult *= 1 + Config.GROUP_SPEED_BONUS
		end
	end
	if PlayerState.IsBoostActive(data, "Speed2x") then
		mult *= Config.Boosts.Speed2x.mult
	end
	return mult
end

function PlayerState.WinsMultiplier(player: Player, data: DataService.Data): number
	local session = sessions[player]
	local mult = 1 + data.rebirths * Config.Rebirth.WinsMultPerRebirth
	local bonus = 0
	if session then
		if session.passes.VIP then
			mult *= 1.5
		end
		if session.passes.DoubleWins then
			mult *= 2
		end
		bonus += math.min(session.friendsInServer * Config.FriendBonusPerFriend, Config.FriendBonusMax)
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		bonus += Config.PremiumWinsBonus
	end
	if PlayerState.IsBoostActive(data, "Wins2x") then
		mult *= Config.Boosts.Wins2x.mult
	end
	return mult * (1 + bonus)
end

function PlayerState.Luck(player: Player, data: DataService.Data): number
	local session = sessions[player]
	local luck = 1
	if session and session.passes.LuckyEggs then
		luck *= 2
	end
	if PlayerState.IsBoostActive(data, "Lucky") then
		luck *= Config.Boosts.Lucky.mult
	end
	return luck
end

---------------------------------------------------------------------------
-- Синхронізація
---------------------------------------------------------------------------
function PlayerState.MarkDirty(player: Player)
	local session = sessions[player]
	if session then
		session.dirty = true
	end
end

local function updateLeaderstats(player: Player, data: DataService.Data)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local speed = stats:FindFirstChild("Speed") :: NumberValue?
	local wins = stats:FindFirstChild("Wins") :: NumberValue?
	local rebirths = stats:FindFirstChild("Rebirths") :: NumberValue?
	if speed then
		speed.Value = math.floor(data.speed)
	end
	if wins then
		wins.Value = math.floor(data.wins)
	end
	if rebirths then
		rebirths.Value = data.rebirths
	end
end

function PlayerState.CreateLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Speed", "Wins", "Rebirths" } do
		local value = Instance.new("NumberValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
end

function PlayerState.BuildPayload(player: Player, data: DataService.Data, session: Session)
	local today = math.floor(os.time() / 86400)
	-- Масив без «дір», бо таблиці з розрідженими числовими ключами погано передаються через Remote.
	local gifts = {}
	for index in Config.PlaytimeGifts do
		gifts[index] = session.giftsClaimed[index] == true
	end
	-- День 7-денного циклу, який показується як поточний.
	local cycle = #Config.DailyRewards
	local dailyDay = if data.daily.lastDay == today
		then (data.daily.streak - 1) % cycle + 1
		elseif data.daily.lastDay == today - 1 then data.daily.streak % cycle + 1
		else 1
	return {
		speed = data.speed,
		wins = data.wins,
		totalWins = data.totalWins,
		rebirths = data.rebirths,
		bestZone = data.bestZone,
		races = data.races,
		pets = data.pets,
		boosts = data.boosts,
		settings = data.settings,
		codes = data.codes,
		passes = session.passes,
		inGroup = session.inGroup,
		friendsInServer = session.friendsInServer,
		joinTime = session.joinTime,
		giftsClaimed = gifts,
		dailyStreak = data.daily.streak,
		dailyClaimedToday = data.daily.lastDay == today,
		dailyDay = dailyDay,
		speedMult = PlayerState.SpeedMultiplier(player, data),
		winsMult = PlayerState.WinsMultiplier(player, data),
		petMult = PlayerState.PetMultiplier(data),
		luck = PlayerState.Luck(player, data),
		equipSlots = PlayerState.EquipSlots(player),
		rebirthCost = Config.RebirthCost(data.rebirths),
	}
end

function PlayerState.Flush(player: Player)
	local session = sessions[player]
	local data = DataService.Get(player)
	if not session or not data or not session.dirty then
		return
	end
	session.dirty = false
	updateLeaderstats(player, data)
	-- Список екіпірованих улюбленців — щоб усі клієнти малювали їх біля гравця.
	local equipped = {}
	for _, pet in data.pets do
		if pet.equipped then
			table.insert(equipped, pet.name)
		end
	end
	local equippedText = table.concat(equipped, ",")
	if player:GetAttribute("EquippedPets") ~= equippedText then
		player:SetAttribute("EquippedPets", equippedText)
	end
	StateRemote:FireClient(player, PlayerState.BuildPayload(player, data, session))
end

function PlayerState.Notify(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
end

---------------------------------------------------------------------------
-- Економіка
---------------------------------------------------------------------------
function PlayerState.LogEconomy(player: Player, flow: Enum.AnalyticsEconomyFlowType, amount: number, balance: number, transaction: string, sku: string?)
	pcall(function()
		AnalyticsService:LogEconomyEvent(player, flow, "Wins", amount, balance, transaction, sku)
	end)
end

function PlayerState.LogFunnel(player: Player, step: number, name: string)
	local session = sessions[player]
	if not session or session.onboardingStep >= step then
		return
	end
	session.onboardingStep = step
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function PlayerState.AddWins(player: Player, data: DataService.Data, amount: number, transaction: string, sku: string?)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	data.wins += amount
	PlayerState.LogEconomy(player, Enum.AnalyticsEconomyFlowType.Source, amount, data.wins, transaction, sku)
	PlayerState.MarkDirty(player)
end

function PlayerState.SpendWins(player: Player, data: DataService.Data, amount: number, transaction: string, sku: string?): boolean
	if data.wins < amount then
		return false
	end
	data.wins -= amount
	PlayerState.LogEconomy(player, Enum.AnalyticsEconomyFlowType.Sink, amount, data.wins, transaction, sku)
	PlayerState.MarkDirty(player)
	return true
end

function PlayerState.AddBoost(player: Player, data: DataService.Data, key: string, seconds: number)
	local now = os.time()
	local current = data.boosts[key]
	local base = if current and current > now then current else now
	data.boosts[key] = base + seconds
	PlayerState.MarkDirty(player)
end

-- Видає нагороду з конфігу (щоденна, подарунок, промокод, продукт). Повертає текст для сповіщення.
function PlayerState.GrantReward(player: Player, data: DataService.Data, reward: any, transaction: string): string
	local parts = {}
	if reward.kind == "Wins" then
		local amount = math.floor(reward.amount * (1 + data.rebirths))
		PlayerState.AddWins(player, data, amount, transaction)
		table.insert(parts, "+" .. Format.Number(amount) .. " Wins")
	elseif reward.kind == "Boost" then
		PlayerState.AddBoost(player, data, reward.boost, reward.seconds)
		table.insert(parts, Config.Boosts[reward.boost].name .. " " .. Format.Time(reward.seconds))
	end
	if reward.bonusWins then
		local amount = math.floor(reward.bonusWins * (1 + data.rebirths))
		PlayerState.AddWins(player, data, amount, transaction)
		table.insert(parts, "+" .. Format.Number(amount) .. " Wins")
	end
	return table.concat(parts, " & ")
end

---------------------------------------------------------------------------
-- Клік
---------------------------------------------------------------------------
function PlayerState.HandleClick(player: Player, count: number)
	local session = sessions[player]
	local data = DataService.Get(player)
	if not session or not data then
		return
	end
	local now = os.time()
	if session.clickSecond ~= now then
		session.clickSecond = now
		session.clicksThisSecond = 0
	end
	local allowed = Config.Click.MaxClicksPerSecond - session.clicksThisSecond
	count = math.clamp(math.floor(count), 0, math.max(allowed, 0))
	if count <= 0 then
		return
	end
	session.clicksThisSecond += count
	data.speed += Config.Click.BaseGain * PlayerState.SpeedMultiplier(player, data) * count
	PlayerState.MarkDirty(player)
	if data.speed >= 1 then
		PlayerState.LogFunnel(player, 2, "First Click")
	end
end

---------------------------------------------------------------------------
-- Соціальні бонуси
---------------------------------------------------------------------------
function PlayerState.RefreshFriends()
	local players = Players:GetPlayers()
	for _, player in players do
		local session = sessions[player]
		if session then
			local count = 0
			for _, other in players do
				if other ~= player then
					local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
					if ok and isFriend then
						count += 1
					end
				end
			end
			if session.friendsInServer ~= count then
				session.friendsInServer = count
				session.dirty = true
			end
		end
	end
end

function PlayerState.Start()
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player in sessions do
				PlayerState.Flush(player)
			end
		end
	end)
	-- Бусти спливають — оновлюємо множники.
	task.spawn(function()
		while true do
			task.wait(5)
			for player in sessions do
				PlayerState.MarkDirty(player)
			end
		end
	end)
end

return PlayerState
