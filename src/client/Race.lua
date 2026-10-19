--!nonstrict
-- Клієнтська анімація забігу: рухаємо свого персонажа по трасі.
-- Нагорода вже порахована сервером, тож це лише візуал.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.UI)

local player = Players.LocalPlayer

local Race = {}

local controls: any = nil
local connection: RBXScriptConnection? = nil
local DEFAULT_FOV = 70

function Race.Init()
	task.spawn(function()
		local ok, module = pcall(function()
			local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript
			return (require :: any)(playerModule)
		end)
		if ok and module then
			controls = module:GetControls()
		end
	end)
end

function Race.Start(info: { start: CFrame, distance: number, duration: number }, onZone: (number) -> ())
	Race.Stop()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if controls then
		controls:Disable()
	end
	local camera = workspace.CurrentCamera
	UI.tween(camera, 0.6, { FieldOfView = 95 })

	local start = info.start
	local forward = start.LookVector
	local velocity = info.distance / math.max(info.duration, 0.1)
	local elapsed = 0
	local lastZone = 0
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local t = math.min(elapsed / info.duration, 1)
		local distance = info.distance * t
		root.CFrame = start + forward * distance
		root.AssemblyLinearVelocity = if t < 1 then forward * velocity else Vector3.zero

		local zone = math.min(Config.ZoneForDistance(distance), Config.Race.ZoneCount)
		if zone > lastZone then
			lastZone = zone
			onZone(zone)
		end
		if t >= 1 and connection then
			connection:Disconnect()
			connection = nil
			UI.tween(camera, 0.8, { FieldOfView = DEFAULT_FOV })
		end
	end)
end

function Race.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if controls then
		controls:Enable()
	end
	local camera = workspace.CurrentCamera
	if camera.FieldOfView ~= DEFAULT_FOV then
		UI.tween(camera, 0.5, { FieldOfView = DEFAULT_FOV })
	end
end

return Race
