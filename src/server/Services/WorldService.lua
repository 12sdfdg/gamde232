-- World unlocking and travel between islands. Also places characters on their current island.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage.Configs
local Worlds = require(Configs.Worlds)

local Router = require(script.Parent.Parent.Router)
local DataService = require(script.Parent.DataService)
local FighterService = require(script.Parent.FighterService)

local WorldService = {}
WorldService.SpawnCFrames = {} -- [worldId] = CFrame (ground level, facing the island)
WorldService.OnTravel = nil -- set by bootstrap (clears combat targets)

local function spawnFor(worldId)
	local cf = WorldService.SpawnCFrames[worldId]
	if not cf then
		local world = Worlds.ById[worldId]
		cf = CFrame.new(world.Origin + Worlds.Layout.Spawn + Vector3.new(0, 6, 0))
	end
	return cf
end

local function placeCharacter(player, worldId)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local cf = spawnFor(worldId) * CFrame.new(math.random(-6, 6), 4, math.random(-4, 4))
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)
	character:PivotTo(cf)
	FighterService.TeleportFollowers(player, cf.Position)
end

function WorldService.Travel(player, worldId)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.CurrentWorld = worldId
	player:SetAttribute("World", worldId)
	if WorldService.OnTravel then
		WorldService.OnTravel(player)
	end
	placeCharacter(player, worldId)
	DataService.Sync(player)
end

function WorldService.Init()
	workspace.FallenPartsDestroyHeight = -420

	Router.OnRequest("Teleport", function(player, worldId)
		local data = DataService.Get(player)
		worldId = tonumber(worldId)
		local world = worldId and Worlds.ById[worldId]
		if not data or not world then
			return { ok = false }
		end
		local key = tostring(worldId)
		if not data.Worlds[key] then
			if data.Level < world.RequiredLevel then
				return { ok = false, msg = "Requires Level " .. world.RequiredLevel }
			end
			if not DataService.Spend(player, "Coins", world.UnlockCost) then
				return { ok = false, msg = "Not enough Coins" }
			end
			data.Worlds[key] = true
			Router.Notify(player, "Unlocked " .. world.Name .. "!", "success")
		end
		WorldService.Travel(player, worldId)
		return { ok = true }
	end, 2)

	local function onCharacter(player, character)
		local data = DataService.WaitFor(player, 30)
		if not data or not character.Parent then
			return
		end
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		local worldId = data.Data.CurrentWorld or 1
		if not data.Data.Worlds[tostring(worldId)] then
			worldId = 1
		end
		player:SetAttribute("World", worldId)
		placeCharacter(player, worldId)
		FighterService.RefreshFollowers(player)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
end

return WorldService
