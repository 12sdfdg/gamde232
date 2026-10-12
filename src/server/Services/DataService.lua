-- Profile wrapper around DataStoreService:
--  * session locking through UpdateAsync (prevents two servers writing the same profile)
--  * retries with backoff, autosave, save on leave and on shutdown
--  * template reconciliation so new fields appear in old profiles
--  * graceful fallback in Studio when API access is disabled (persistence = false)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage.Configs
local Game = require(Configs.Game)
local Net = require(ReplicatedStorage.Modules.Net)

local DataService = {}
DataService.Persistence = false

local STORE_NAME = "AnimeSkyFighters_v1"
local LOCK_TIMEOUT = 600

local store
local profiles = {}
local loadedEvent = Instance.new("BindableEvent")
DataService.Loaded = loadedEvent.Event
DataService.SyncExtras = {} -- functions(player, profile) -> table merged into the sync payload

local function template()
	return {
		Version = 1,
		Coins = Game.StartingCoins,
		Gems = Game.StartingGems,
		PaidGems = 0,
		Power = 0,
		Level = 1,
		Exp = 0,
		Fighters = {},
		Equipped = {},
		NextUid = 1,
		Index = {},
		Items = { Material = 0, Sword = 0, Potion_Luck = 1, Potion_Coins = 1, Potion_Damage = 0 },
		Boosts = {},
		Worlds = { ["1"] = true },
		CurrentWorld = 1,
		Stats = { PlayTime = 0, StarOpens = 0, HighestPower = 0, Kills = 0, BossKills = 0, Clicks = 0, AbilityUses = 0, WeatherKills = 0 },
		Achievements = {},
		Daily = { LastDay = -1, Streak = 0 },
		Pity = 0,
		Gamepasses = {},
		Bundles = {},
		Settings = { Music = true, Sfx = true, LowGraphics = false, AutoOpen = false, SkipAnimation = false, Shake = true },
		Receipts = {},
	}
end

local function reconcile(target, source)
	for key, value in pairs(source) do
		if target[key] == nil then
			if type(value) == "table" then
				local copy = {}
				reconcile(copy, value)
				target[key] = copy
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			-- Only reconcile dictionary-like templates (skip lists such as Equipped).
			if #value == 0 then
				reconcile(target[key], value)
			end
		end
	end
	return target
end

local function keyFor(player)
	return "u_" .. player.UserId
end

local function getStore()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		store = ok and result or false
	end
	return store
end

local function loadProfile(player)
	local ds = getStore()
	if not ds then
		return template(), false
	end
	local key = keyFor(player)
	for attempt = 1, 5 do
		local stolen = attempt >= 4
		local data
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(saved)
				saved = saved or {}
				local lock = saved.Lock
				if lock and lock.Job ~= game.JobId and os.time() - (lock.Time or 0) < LOCK_TIMEOUT and not stolen then
					data = nil
					return nil -- still locked by another server: cancel and retry
				end
				saved.Lock = { Job = game.JobId, Time = os.time() }
				data = saved.Data or template()
				return saved
			end)
		end)
		if ok and data then
			return reconcile(data, template()), true
		end
		if not ok then
			local message = tostring(err)
			if RunService:IsStudio() and (message:find("API") or message:find("403") or message:find("Studio")) then
				warn("[DataService] DataStore unavailable in Studio (enable 'Studio Access to API Services' to test saving).")
				store = false
				return template(), false
			end
			warn("[DataService] load attempt " .. attempt .. " failed: " .. message)
		end
		task.wait(attempt * 1.5)
		if not player.Parent then
			return nil, false
		end
	end
	return nil, false
end

local function saveProfile(player, profile, release)
	if not profile.Persistent then
		return true
	end
	local ds = getStore()
	if not ds then
		return false
	end
	local data = profile.Data
	local ok, err = pcall(function()
		ds:UpdateAsync(keyFor(player), function(saved)
			saved = saved or {}
			if saved.Lock and saved.Lock.Job ~= game.JobId then
				return nil -- another server owns this profile now
			end
			saved.Data = data
			saved.Lock = (not release) and { Job = game.JobId, Time = os.time() } or nil
			return saved
		end)
	end)
	if not ok then
		warn("[DataService] save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

local pendingSync = {}

function DataService.Sync(player)
	if pendingSync[player] then
		return
	end
	pendingSync[player] = true
	-- Throttled: many changes in a short window are batched into one payload.
	task.delay(0.15, function()
		pendingSync[player] = nil
		local profile = profiles[player]
		if not profile or not player.Parent then
			return
		end
		local payload = { Data = profile.Data, Persistence = profile.Persistent }
		for _, extra in ipairs(DataService.SyncExtras) do
			local ok, fields = pcall(extra, player, profile)
			if ok and type(fields) == "table" then
				for k, v in pairs(fields) do
					payload[k] = v
				end
			end
		end
		Net.Get("Sync"):FireClient(player, payload)
	end)
end

function DataService.Get(player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.Profile(player)
	return profiles[player]
end

function DataService.WaitFor(player, timeout)
	local start = os.clock()
	while player.Parent and not profiles[player] and os.clock() - start < (timeout or 30) do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.All()
	return profiles
end

-- Currency helpers -------------------------------------------------------------------------------

function DataService.Add(player, key, amount)
	local data = DataService.Get(player)
	if not data or type(amount) ~= "number" or amount ~= amount then
		return
	end
	data[key] = math.max(0, (data[key] or 0) + amount)
	if key == "Power" and data.Power > data.Stats.HighestPower then
		data.Stats.HighestPower = data.Power
	end
	DataService.Sync(player)
end

function DataService.CanAfford(data, currency, amount)
	if currency == "Gems" then
		return data.Gems + data.PaidGems >= amount
	end
	return (data[currency] or 0) >= amount
end

function DataService.Spend(player, currency, amount)
	local data = DataService.Get(player)
	if not data or amount < 0 or not DataService.CanAfford(data, currency, amount) then
		return false
	end
	if currency == "Gems" then
		local fromFree = math.min(data.Gems, amount)
		data.Gems -= fromFree
		data.PaidGems -= amount - fromFree
	else
		data[currency] -= amount
	end
	DataService.Sync(player)
	return true
end

function DataService.AddItem(player, item, amount)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Items[item] = (data.Items[item] or 0) + amount
	DataService.Sync(player)
end

function DataService.Stat(player, stat, amount)
	local data = DataService.Get(player)
	if data then
		data.Stats[stat] = (data.Stats[stat] or 0) + amount
	end
end

-- Lifecycle --------------------------------------------------------------------------------------

local function onPlayerAdded(player)
	local data, persistent = loadProfile(player)
	if not player.Parent then
		return
	end
	if not data then
		player:Kick("Could not load your data. Please rejoin in a moment.")
		return
	end
	local profile = {
		Data = data,
		Persistent = persistent,
		Session = { Start = os.clock(), ClaimedTime = {}, FreeGemsAt = os.clock() + Game.FreeGemsInterval, AbilityReady = 0 },
	}
	profiles[player] = profile
	DataService.Persistence = persistent
	player:SetAttribute("DataLoaded", true)
	player:SetAttribute("World", data.CurrentWorld)
	loadedEvent:Fire(player, profile)
	DataService.Sync(player)
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	saveProfile(player, profile, true)
	profiles[player] = nil
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(Game.AutosaveInterval)
			for player, profile in pairs(profiles) do
				task.spawn(saveProfile, player, profile, false)
			end
		end
	end)

	game:BindToClose(function()
		local threads = 0
		for player, profile in pairs(profiles) do
			threads += 1
			task.spawn(function()
				saveProfile(player, profile, true)
				threads -= 1
			end)
		end
		local start = os.clock()
		while threads > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
