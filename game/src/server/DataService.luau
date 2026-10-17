-- Player data: load/save (DataStore), leaderstats and syncing to the client.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local STORE_NAME = "PopBalloonRNG_v1"
local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore unavailable (enable Studio API access to save):", result)
	end
end

local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local remotes: any

local function defaultData()
	return {
		coins = 0,
		bestWave = 0,
		rolls = 0,
		popped = 0,
		inventory = { Basic = 1 },
		discovered = { Basic = true },
		upgrades = {},
	}
end

local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		end
	end
	return data
end

function DataService.Init(remoteFolder: Folder)
	remotes = remoteFolder
	-- batched sync so coin spam does not flood the network
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in dirty do
				dirty[player] = nil
				DataService.Sync(player)
			end
		end
	end)
	-- autosave
	task.spawn(function()
		while true do
			task.wait(120)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)
end

function DataService.Load(player: Player)
	local data = nil
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("u_" .. player.UserId)
		end)
		if ok and type(result) == "table" then
			data = result
		elseif not ok then
			warn("[Data] load failed for", player.Name, result)
		end
	end
	data = reconcile(data or {}, defaultData())
	profiles[player] = data

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in { "Coins", "Best Wave", "Rolls" } do
		local v = Instance.new("NumberValue")
		v.Name = name
		v.Parent = ls
	end
	ls.Parent = player
	DataService.UpdateLeaderstats(player)
	DataService.Sync(player)
	return data
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.Stats(player: Player)
	local data = profiles[player]
	return Config.GetStats(data and data.upgrades)
end

function DataService.UpdateLeaderstats(player: Player)
	local data = profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if not data or not ls then
		return
	end
	(ls :: any).Coins.Value = data.coins;
	(ls :: any)["Best Wave"].Value = data.bestWave;
	(ls :: any).Rolls.Value = data.rolls
end

function DataService.MarkDirty(player: Player)
	dirty[player] = true
end

function DataService.Sync(player: Player)
	local data = profiles[player]
	if data and player.Parent then
		DataService.UpdateLeaderstats(player)
		remotes.DataChanged:FireClient(player, data, DataService.Stats(player))
	end
end

function DataService.AddCoins(player: Player, amount: number)
	local data = profiles[player]
	if data then
		data.coins += amount
		DataService.MarkDirty(player)
	end
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if not data or not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("u_" .. player.UserId, data)
	end)
	if not ok then
		warn("[Data] save failed for", player.Name, err)
	end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
	dirty[player] = nil
end

function DataService.All()
	return profiles
end

return DataService
