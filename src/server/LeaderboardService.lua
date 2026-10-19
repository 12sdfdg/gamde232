--!nonstrict
-- Глобальний топ за загальною кількістю виграшів (OrderedDataStore) на дошці в лобі.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local UPDATE_INTERVAL = 120
local TOP_COUNT = 15

local nameCache: { [number]: string } = {}

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and name then name else "Player"
	nameCache[userId] = result
	return result
end

local function render(gui: SurfaceGui, entries: { { key: string, value: number } })
	local list = gui:FindFirstChild("List") :: Frame
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for rank, entry in entries do
		local userId = tonumber(string.sub(entry.key, 3)) or 0
		local row = Instance.new("TextLabel")
		row.LayoutOrder = rank
		row.Size = UDim2.new(1, 0, 1 / TOP_COUNT, -2)
		row.BackgroundColor3 = if rank == 1
			then Color3.fromRGB(255, 200, 60)
			elseif rank == 2 then Color3.fromRGB(200, 200, 215)
			elseif rank == 3 then Color3.fromRGB(205, 130, 70)
			else Color3.fromRGB(45, 45, 60)
		row.BackgroundTransparency = 0.15
		row.TextColor3 = Color3.new(1, 1, 1)
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = string.format("  #%d  %s — %s 🏆", rank, getName(userId), Format.Number(entry.value))
		row.Parent = list
	end
end

function LeaderboardService.Start(gui: SurfaceGui)
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.LEADERBOARD_STORE)
	if not ok then
		warn("[Leaderboard] OrderedDataStore недоступний")
		return
	end
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data and data.totalWins > 0 then
					pcall(store.SetAsync, store, "u_" .. player.UserId, math.floor(data.totalWins))
				end
			end
			local success, pages = pcall(store.GetSortedAsync, store, false, TOP_COUNT)
			if success and pages then
				render(gui, pages:GetCurrentPage())
			end
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return LeaderboardService
