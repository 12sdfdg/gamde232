-- Level/EXP, kill rewards & loot, daily rewards, play-time rewards, achievements, potions, free gems.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Configs = ReplicatedStorage.Configs
local Game = require(Configs.Game)
local Rewards = require(Configs.Rewards)
local Achievements = require(Configs.Achievements)
local Shop = require(Configs.Shop)
local Stats = require(ReplicatedStorage.Modules.Stats)
local Format = require(ReplicatedStorage.Modules.Format)

local Router = require(script.Parent.Parent.Router)
local DataService = require(script.Parent.DataService)

local RewardService = {}
RewardService.WeatherMultiplier = function()
	return 1, "Clear"
end

local rng = Random.new()

local function today()
	return os.time() // 86400
end

local function dailyState(data)
	local day = today()
	local canClaim = day > data.Daily.LastDay
	local nextDay
	if canClaim then
		nextDay = (data.Daily.LastDay == day - 1) and (data.Daily.Streak % 7 + 1) or 1
	else
		nextDay = data.Daily.Streak
	end
	return canClaim, nextDay
end

local function statValue(data, stat)
	if stat == "Level" then
		return data.Level
	elseif stat == "IndexCount" then
		local n = 0
		for _ in pairs(data.Index) do
			n += 1
		end
		return n
	elseif stat == "WorldsUnlocked" then
		local n = 0
		for _ in pairs(data.Worlds) do
			n += 1
		end
		return n
	end
	return data.Stats[stat] or 0
end
RewardService.StatValue = statValue

function RewardService.AddExp(player, amount)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Exp += math.floor(amount)
	local leveled = false
	while data.Exp >= Stats.ExpForLevel(data.Level) do
		data.Exp -= Stats.ExpForLevel(data.Level)
		data.Level += 1
		data.Gems += 10 + data.Level * 2
		leveled = true
	end
	if leveled then
		Router.Fx(player, { Kind = "LevelUp", Level = data.Level })
		Router.Notify(player, "LEVEL UP! Lv. " .. data.Level .. "  (+" .. (10 + data.Level * 2) .. " Gems)", "level")
		local FighterService = require(script.Parent.FighterService)
		FighterService.RefreshFollowers(player)
	end
	DataService.Sync(player)
end

function RewardService.GrantReward(player, kind, amount)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if kind == "Coins" or kind == "Gems" or kind == "Power" then
		DataService.Add(player, kind, amount)
	elseif kind == "Exp" then
		RewardService.AddExp(player, amount)
	elseif kind == "Material" or kind == "Sword" or Shop.Potions[kind] then
		DataService.AddItem(player, kind, amount)
	end
end

-- Called by CombatService when an enemy dies.
function RewardService.GrantKill(player, def)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local mult = Stats.Multipliers(data)
	local weatherMult, weatherName = RewardService.WeatherMultiplier()
	local drops = {}
	for _, loot in ipairs(def.Loot) do
		if rng:NextNumber() <= loot.Chance then
			local amount = loot.Amount or 1
			if loot.Item == "Coins" then
				amount = math.floor(def.Coins * mult.Coins * weatherMult * rng:NextNumber(0.9, 1.15))
				data.Coins += amount
			elseif loot.Item == "Star" then
				amount = math.floor(def.Exp * mult.Exp * weatherMult)
				RewardService.AddExp(player, amount)
			elseif loot.Item == "Gems" then
				data.Gems += amount
			else
				data.Items[loot.Item] = (data.Items[loot.Item] or 0) + amount
			end
			table.insert(drops, { Item = loot.Item, Amount = amount, Rare = loot.Chance < 0.1 })
		end
	end
	data.Stats.Kills += 1
	if def.Boss then
		data.Stats.BossKills += 1
	end
	if weatherName ~= "Clear" then
		data.Stats.WeatherKills += 1
	end
	DataService.Sync(player)
	return drops
end

local function claimAchievement(player, id)
	local data = DataService.Get(player)
	local def = Achievements.ById[id]
	if not data or not def then
		return false
	end
	local tier = (data.Achievements[id] or 0) + 1
	local goal = def.Goals[tier]
	if not goal or statValue(data, def.Stat) < goal then
		return false
	end
	data.Achievements[id] = tier
	data.Gems += def.Rewards[tier]
	return true, def.Rewards[tier]
end

function RewardService.Init()
	Router.OnRequest("ClaimDaily", function(player)
		local data = DataService.Get(player)
		if not data then
			return { ok = false }
		end
		local canClaim, nextDay = dailyState(data)
		if not canClaim then
			return { ok = false, msg = "Come back tomorrow!" }
		end
		local reward = Rewards.Daily[nextDay]
		data.Daily.LastDay = today()
		data.Daily.Streak = nextDay
		data.Gems += reward.Gems
		DataService.Sync(player)
		return { ok = true, Day = nextDay, Gems = reward.Gems }
	end, 2)

	Router.OnRequest("ClaimTime", function(player, index)
		local profile = DataService.Profile(player)
		index = tonumber(index)
		local reward = index and Rewards.Time[index]
		if not profile or not reward then
			return { ok = false }
		end
		local elapsed = os.clock() - profile.Session.Start
		if profile.Session.ClaimedTime[tostring(index)] or elapsed < reward.Time then
			return { ok = false, msg = "Not ready yet" }
		end
		profile.Session.ClaimedTime[tostring(index)] = true
		local r = reward.Reward
		if r.Type == "Coins" then
			-- Coin rewards scale with the best unlocked world.
			local best = 1
			for key in pairs(profile.Data.Worlds) do
				best = math.max(best, tonumber(key) or 1)
			end
			RewardService.GrantReward(player, "Coins", r.Amount * (12 ^ (best - 1)))
		else
			RewardService.GrantReward(player, r.Type, r.Amount)
		end
		DataService.Sync(player)
		return { ok = true }
	end, 4)

	Router.OnRequest("ClaimAchievement", function(player, id)
		if typeof(id) ~= "string" then
			return { ok = false }
		end
		local ok, gems = claimAchievement(player, id)
		DataService.Sync(player)
		return { ok = ok, Gems = gems }
	end, 6)

	Router.OnRequest("ClaimAllAchievements", function(player)
		local total = 0
		for _, def in ipairs(Achievements.List) do
			local guard = 0
			while guard < 10 do
				guard += 1
				local ok, gems = claimAchievement(player, def.Id)
				if not ok then
					break
				end
				total += gems
			end
		end
		DataService.Sync(player)
		if total == 0 then
			return { ok = false, msg = "Nothing to claim yet" }
		end
		return { ok = true, Gems = total }
	end, 2)

	Router.OnRequest("UsePotion", function(player, item)
		local data = DataService.Get(player)
		local potion = typeof(item) == "string" and Shop.Potions[item]
		if not data or not potion then
			return { ok = false }
		end
		if (data.Items[item] or 0) < 1 then
			return { ok = false, msg = "You have none" }
		end
		data.Items[item] -= 1
		local now = os.time()
		local boost = data.Boosts[potion.Boost]
		local base = (boost and boost.Ends > now) and boost.Ends or now
		data.Boosts[potion.Boost] = { Ends = base + potion.Duration, Value = potion.Value }
		DataService.Sync(player)
		return { ok = true }
	end, 4)

	Router.OnRequest("ClaimFreeGems", function(player)
		local profile = DataService.Profile(player)
		if not profile then
			return { ok = false }
		end
		if os.clock() < profile.Session.FreeGemsAt then
			return { ok = false, msg = "Free gems in " .. Format.Clock(profile.Session.FreeGemsAt - os.clock()) }
		end
		profile.Session.FreeGemsAt = os.clock() + Game.FreeGemsInterval
		profile.Data.Gems += Game.FreeGemsAmount
		DataService.Sync(player)
		return { ok = true, Gems = Game.FreeGemsAmount }
	end, 2)

	Router.OnRequest("SaveSettings", function(player, settings)
		local data = DataService.Get(player)
		if not data or type(settings) ~= "table" then
			return { ok = false }
		end
		for key, value in pairs(settings) do
			if data.Settings[key] ~= nil and type(value) == "boolean" then
				data.Settings[key] = value
			end
		end
		DataService.Sync(player)
		return { ok = true }
	end, 4)

	table.insert(DataService.SyncExtras, function(player, profile)
		local data = profile.Data
		local canClaim, nextDay = dailyState(data)
		local mult = Stats.Multipliers(data)
		local claimable = 0
		for _, def in ipairs(Achievements.List) do
			local tier = (data.Achievements[def.Id] or 0) + 1
			local goal = def.Goals[tier]
			if goal and statValue(data, def.Stat) >= goal then
				claimable += 1
			end
		end
		local timeReady = 0
		local elapsed = os.clock() - profile.Session.Start
		for i, reward in ipairs(Rewards.Time) do
			if not profile.Session.ClaimedTime[tostring(i)] and elapsed >= reward.Time then
				timeReady += 1
			end
		end
		return {
			ServerTime = os.time(),
			Session = { Elapsed = elapsed, Claimed = profile.Session.ClaimedTime, FreeGemsIn = math.max(0, profile.Session.FreeGemsAt - os.clock()) },
			Daily = { CanClaim = canClaim, Day = nextDay },
			Derived = {
				MaxEquip = Stats.MaxEquip(data),
				TeamDps = Stats.TeamDps(data),
				Multipliers = mult,
				AchievementsReady = claimable,
				TimeReady = timeReady,
			},
		}
	end)
end

function RewardService.Start()
	-- Play-time tracking + periodic sync so timers/achievements stay fresh.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.Get(player)
				if data then
					data.Stats.PlayTime += 1
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(15)
			for _, player in ipairs(Players:GetPlayers()) do
				if DataService.Get(player) then
					DataService.Sync(player)
				end
			end
		end
	end)
end

return RewardService
