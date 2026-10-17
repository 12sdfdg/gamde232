-- Global leaderboards (OrderedDataStore) shown on the boards in the hub.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local KEYS = {
	BestWave = "bestWave",
	TopRolls = "rolls",
	TopCoins = "coins",
}
local REFRESH = 60

local names: { [number]: string } = {}
local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then name else ("Player " .. userId)
	return names[userId]
end

local function getStore(key: string)
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("LB_" .. key)
	end)
	return if ok then store else nil
end

local function render(board: BasePart, entries: { { name: string, value: number } })
	local gui = board:FindFirstChild("Gui")
	if not gui then
		return
	end
	for i = 1, 10 do
		local row = gui:FindFirstChild("Row" .. i) :: TextLabel?
		if row then
			local e = entries[i]
			row.Text = if e then string.format("  #%d  %s  —  %s", i, e.name, Util.Abbrev(e.value)) else string.format("  #%d  ---", i)
			row.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 60) elseif i == 2 then Color3.fromRGB(220, 220, 230) elseif i == 3 then Color3.fromRGB(230, 150, 90) else Color3.new(1, 1, 1)
		end
	end
end

-- Fallback when DataStores are unavailable (e.g. Studio without API access): show online players.
local function localEntries(field: string)
	local entries = {}
	for player, data in DataService.All() do
		table.insert(entries, { name = player.DisplayName, value = data[field] or 0 })
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)
	return entries
end

local function refresh(boards: { [string]: BasePart })
	for key, field in KEYS do
		local board = boards[key]
		if board then
			local store = getStore(key)
			local entries = nil
			if store then
				for player, data in DataService.All() do
					pcall(function()
						store:SetAsync(tostring(player.UserId), math.floor(data[field] or 0))
					end)
				end
				local ok, pages = pcall(function()
					return store:GetSortedAsync(false, 10)
				end)
				if ok and pages then
					entries = {}
					for _, item in pages:GetCurrentPage() do
						table.insert(entries, { name = nameOf(tonumber(item.key) or 0), value = item.value })
					end
				end
			end
			render(board, entries or localEntries(field))
		end
	end
end

function LeaderboardService.Start(boards: { [string]: BasePart })
	task.spawn(function()
		task.wait(5)
		while true do
			refresh(boards)
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
