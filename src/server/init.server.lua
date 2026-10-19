--!nonstrict
-- Точка входу сервера: будує карту, запускає сервіси, маршрутизує дії клієнта.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)

local DataService = require(script.DataService)
local LeaderboardService = require(script.LeaderboardService)
local MapBuilder = require(script.MapBuilder)
local PetService = require(script.PetService)
local PlayerState = require(script.PlayerState)
local RaceService = require(script.RaceService)
local RewardService = require(script.RewardService)
local ShopService = require(script.ShopService)

local map = MapBuilder.Build()

PlayerState.Start()
ShopService.Start()
PetService.Start(map.eggPrompts)
RaceService.Start(map)
LeaderboardService.Start(map.leaderboard)

local function rebirth(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local cost = Config.RebirthCost(data.rebirths)
	if not PlayerState.SpendWins(player, data, cost, "Rebirth") then
		PlayerState.Notify(player, string.format("Need %s 🏆 Wins to rebirth!", Format.Number(cost)), "warn")
		return
	end
	data.speed = 0
	data.rebirths += 1
	PlayerState.LogFunnel(player, 5, "First Rebirth")
	pcall(function()
		game:GetService("AnalyticsService"):LogProgressionEvent(player, "Rebirth", Enum.AnalyticsProgressionType.Complete, data.rebirths)
	end)
	PlayerState.Notify(player, string.format("REBIRTH %d! Speed gain is now %s 🌟", data.rebirths, Format.Mult(1 + data.rebirths * Config.Rebirth.SpeedMultPerRebirth)), "success")
	PlayerState.MarkDirty(player)
end

-- Маршрутизація дій. Усі аргументи від клієнта перевіряються.
local actions: { [string]: (Player, any, any) -> () } = {
	Rebirth = function(player)
		rebirth(player)
	end,
	Equip = function(player, uid, equip)
		if type(uid) == "string" and type(equip) == "boolean" then
			PetService.Equip(player, uid, equip)
		end
	end,
	EquipBest = function(player)
		local data = DataService.Get(player)
		if data then
			PetService.EquipBest(player, data)
		end
	end,
	Delete = function(player, uid)
		if type(uid) == "string" then
			PetService.Delete(player, uid)
		end
	end,
	DeleteRarity = function(player, rarity)
		if type(rarity) == "string" then
			PetService.DeleteRarity(player, rarity)
		end
	end,
	ClaimDaily = function(player)
		RewardService.ClaimDaily(player)
	end,
	ClaimGift = function(player, index)
		if type(index) == "number" then
			RewardService.ClaimGift(player, index)
		end
	end,
	Code = function(player, code)
		if type(code) == "string" and #code <= 30 then
			RewardService.RedeemCode(player, code)
		end
	end,
	BuyPass = function(player, key)
		if type(key) == "string" then
			ShopService.PromptPass(player, key)
		end
	end,
	BuyProduct = function(player, key)
		if type(key) == "string" then
			ShopService.PromptProduct(player, key)
		end
	end,
	Setting = function(player, name, value)
		local data = DataService.Get(player)
		if data and (name == "autoEquip" or name == "autoClick") and type(value) == "boolean" then
			data.settings[name] = value
			PlayerState.MarkDirty(player)
		end
	end,
}

Net.Get("Action").OnServerEvent:Connect(function(player, name, a, b)
	local handler = if type(name) == "string" then actions[name] else nil
	if handler then
		handler(player, a, b)
	end
end)

Net.Get("Click").OnServerEvent:Connect(function(player, count)
	if type(count) == "number" and count == count then
		PlayerState.HandleClick(player, count)
	end
end)

DataService.OnLoaded(function(player: Player, data: DataService.Data)
	local session = PlayerState.CreateSession(player)
	if data.races > 0 then
		session.onboardingStep = math.huge -- воронку онбордингу логуємо лише для новачків
	end
	PlayerState.CreateLeaderstats(player)
	PlayerState.LogFunnel(player, 1, "Joined")
	ShopService.LoadPasses(player)
	if data.settings.autoEquip then
		PetService.EquipBest(player, data)
	end
	Net.Get("RoundState"):FireClient(player, RaceService.GetRoundState())

	if Config.GROUP_ID ~= 0 then
		task.spawn(function()
			local ok, inGroup = pcall(player.IsInGroup, player, Config.GROUP_ID)
			local session = PlayerState.GetSession(player)
			if ok and inGroup and session then
				session.inGroup = true
				PlayerState.MarkDirty(player)
			end
		end)
	end
	task.spawn(PlayerState.RefreshFriends)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerState.RemoveSession(player)
	task.spawn(PlayerState.RefreshFriends)
end)

-- Сесію треба створити до запуску DataService, тому стартуємо його останнім.
DataService.Start()

-- Автоклікер (геймпас): працює на сервері, навіть якщо гравець AFK.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local session = PlayerState.GetSession(player)
			local data = DataService.Get(player)
			if session and data and session.passes.AutoClicker and data.settings.autoClick then
				PlayerState.HandleClick(player, Config.Click.AutoClicksPerSecond)
			end
		end
	end
end)
