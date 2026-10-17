-- Server entry point: builds the map, wires remotes and player lifecycle.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MapBuilder = require(script.Parent.MapBuilder)
local PlotService = require(script.Parent.PlotService)
local RollService = require(script.Parent.RollService)
local TurretService = require(script.Parent.TurretService)
local WaveService = require(script.Parent.WaveService)

---------------------------------------------------------------------- remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className: string, name: string)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local Roll = remote("RemoteFunction", "Roll") :: RemoteFunction
local Place = remote("RemoteFunction", "Place") :: RemoteFunction
local BuyUpgrade = remote("RemoteFunction", "BuyUpgrade") :: RemoteFunction
local StartWaves = remote("RemoteEvent", "StartWaves") :: RemoteEvent
local RemoveAll = remote("RemoteEvent", "RemoveAll") :: RemoteEvent
local RemoveTurret = remote("RemoteEvent", "RemoveTurret") :: RemoteEvent
local GoHome = remote("RemoteEvent", "GoHome") :: RemoteEvent
remote("RemoteEvent", "DataChanged")
remote("RemoteEvent", "WaveState")
remote("RemoteEvent", "Popped")
remote("RemoteEvent", "Shot")
remote("RemoteEvent", "Notify")
remote("RemoteEvent", "PlaySound")
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------- world
local plotModels, boards = MapBuilder.Build()
PlotService.Init(plotModels)
DataService.Init(remotes)
WaveService.Init(remotes)
TurretService.Init(remotes)
RollService.Init(remotes)
LeaderboardService.Start(boards)

---------------------------------------------------------------------- sword
local function makeSword(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Popper Sword"
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, -1.6, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 4.5, 0.25)
	handle.Color = Color3.fromRGB(80, 200, 255)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Parent = tool
	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(1.6, 0.3, 0.5)
	guard.Color = Color3.fromRGB(255, 200, 50)
	guard.CanCollide = false
	guard.Massless = true
	guard.CFrame = handle.CFrame * CFrame.new(0, -1.2, 0)
	guard.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = guard
	w.Parent = guard
	local sound = Instance.new("Sound")
	sound.Name = "Slash"
	sound.SoundId = Config.Sounds.Slash
	sound.Volume = 0.6
	sound.Parent = handle

	local last = 0
	tool.Activated:Connect(function()
		local now = os.clock()
		if now - last < 0.35 then
			return
		end
		last = now
		local char = tool.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not player or not root then
			return
		end
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		game:GetService("Debris"):AddItem(anim, 1)
		sound:Play()
		local plot = PlotService.Get(player)
		if not plot then
			return
		end
		local stats = DataService.Stats(player)
		local front = root.Position + root.CFrame.LookVector * 4 + Vector3.new(0, 3, 0)
		for _, b in WaveService.BalloonsNear(plot, front, 8) do
			WaveService.Damage(b, Config.SwordDamage * stats.damageMult, player)
		end
	end)
	return tool
end

---------------------------------------------------------------------- players
local function onCharacter(player: Player, char: Model)
	task.wait(0.2)
	PlotService.TeleportHome(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and not backpack:FindFirstChild("Popper Sword") and not char:FindFirstChild("Popper Sword") then
		makeSword().Parent = backpack
	end
end

local function onPlayerAdded(player: Player)
	DataService.Load(player)
	if not player.Parent then
		DataService.Release(player)
		return
	end
	local plot = PlotService.Assign(player)
	if not plot then
		player:Kick("Server is full, please join another server.")
		return
	end
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	WaveService.SendState(plot)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local plot = PlotService.Get(player)
	if plot then
		WaveService.Stop(plot)
		TurretService.Clear(plot)
	end
	PlotService.Release(player)
	RollService.Forget(player)
	DataService.Release(player)
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.Save, player)
	end
	task.wait(3)
end)

---------------------------------------------------------------------- remote handlers
Roll.OnServerInvoke = function(player)
	return RollService.Roll(player)
end

Place.OnServerInvoke = function(player, id, pos, yaw)
	local ok, reason = TurretService.Place(player, id, pos, yaw)
	return ok, reason
end

BuyUpgrade.OnServerInvoke = function(player, id)
	return RollService.BuyUpgrade(player, id)
end

StartWaves.OnServerEvent:Connect(function(player)
	WaveService.Start(player)
end)

RemoveAll.OnServerEvent:Connect(function(player)
	local plot = PlotService.Get(player)
	if plot then
		TurretService.Clear(plot)
	end
end)

RemoveTurret.OnServerEvent:Connect(function(player, model)
	if typeof(model) == "Instance" then
		TurretService.Remove(player, model)
	end
end)

GoHome.OnServerEvent:Connect(function(player)
	PlotService.TeleportHome(player)
end)
