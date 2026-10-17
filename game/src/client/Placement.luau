-- Turret placement with a green/red ghost preview, plus delete mode.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Placement = {}

local remotes: any
local onHint: (string?) -> ()
local onNotify: (string, Color3?) -> ()
local getAvailable: (string) -> number

local activeId: string? = nil
local deleteMode = false
local ghost: Model? = nil
local yaw = 0
local lastPos: Vector3? = nil
local lastValid = false
local pointer: Vector2? = nil
local busy = false
local renderConn: RBXScriptConnection? = nil

local GREEN = Color3.fromRGB(80, 255, 110)
local RED = Color3.fromRGB(255, 70, 70)

function Placement.MyPlot(): Model?
	local index = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("Plots")
	return if index and plots then plots:FindFirstChild("Plot" .. index) :: Model? else nil
end

local function myTurretPositions(): { Vector3 }
	local out = {}
	local plot = Placement.MyPlot()
	if plot then
		for _, m in plot.Turrets:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart then
				table.insert(out, m.PrimaryPart.Position)
			end
		end
	end
	return out
end

function Placement.PlacedCount(id: string): number
	local n = 0
	local plot = Placement.MyPlot()
	if plot then
		for _, m in plot.Turrets:GetChildren() do
			if m:GetAttribute("TurretId") == id then
				n += 1
			end
		end
	end
	return n
end

function Placement.TotalPlaced(): number
	local plot = Placement.MyPlot()
	return if plot then #plot.Turrets:GetChildren() else 0
end

local function makeGhost(def): Model
	local m = Instance.new("Model")
	m.Name = "PlacementGhost"
	local function p(size: Vector3, offset: CFrame, shape: Enum.PartType?)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.ForceField
		part.Transparency = 0.2
		part.Size = size
		if shape then
			part.Shape = shape
		end
		part:SetAttribute("Offset", offset)
		part.Parent = m
		return part
	end
	p(Vector3.new(1.2, 5.5, 5.5), CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	p(Vector3.new(3, 2.2, 3.2), CFrame.new(0, 3.6, 0))
	p(Vector3.new(0.7, 0.7, 3.2), CFrame.new(0, 3.7, -3))
	local ring = p(Vector3.new(0.2, def.range * 2, def.range * 2), CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.85
	ring.Name = "Range"
	m.Parent = workspace
	return m
end

local function setGhost(cf: CFrame, valid: boolean)
	if not ghost then
		return
	end
	for _, part in ghost:GetChildren() do
		if part:IsA("BasePart") then
			part.CFrame = cf * (part:GetAttribute("Offset") :: CFrame)
			part.Color = if valid then GREEN else RED
		end
	end
end

local function screenRay(screen: Vector2)
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local plots = workspace:FindFirstChild("Plots")
	params.FilterDescendantsInstances = if plots then { plots } else {}
	return workspace:Raycast(ray.Origin, ray.Direction * 600, params)
end

local function currentScreenPoint(): Vector2
	if pointer then
		return pointer
	end
	return UserInputService:GetMouseLocation()
end

local function update()
	if not activeId or not ghost then
		return
	end
	local plot = Placement.MyPlot()
	local hit = screenRay(currentScreenPoint())
	if not plot or not hit then
		lastPos = nil
		setGhost(CFrame.new(0, -500, 0), false)
		return
	end
	local p = hit.Position
	local pos = Vector3.new(math.round(p.X * 2) / 2, Config.GroundY, math.round(p.Z * 2) / 2)
	local origin = plot:GetAttribute("Origin") :: Vector3
	local ok = Util.CanPlace(origin, pos, myTurretPositions())
	lastPos = pos
	lastValid = ok
	setGhost(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0), ok)
end

function Placement.Cancel()
	activeId = nil
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if not deleteMode then
		onHint(nil)
	end
end

function Placement.Start(id: string)
	Placement.SetDeleteMode(false)
	Placement.Cancel()
	local def = Config.Get(id)
	if not def then
		return
	end
	activeId = id
	ghost = makeGhost(def)
	yaw = 0
	pointer = nil
	renderConn = RunService.RenderStepped:Connect(update)
	onHint(string.format("Placing %s  •  Click to place  •  R = rotate  •  Q = cancel", def.name))
end

function Placement.SetDeleteMode(on: boolean)
	deleteMode = on
	if on then
		Placement.Cancel()
		onHint("Delete mode  •  Click a turret to remove it  •  Q = exit")
	else
		onHint(nil)
	end
end

function Placement.IsDeleteMode(): boolean
	return deleteMode
end

local function tryPlace()
	if busy or not activeId or not lastPos then
		return
	end
	if not lastValid then
		onNotify("Can't place here", RED)
		return
	end
	busy = true
	local id = activeId
	local ok, reason = (remotes:FindFirstChild("Place") :: RemoteFunction):InvokeServer(id, lastPos, yaw)
	busy = false
	if ok then
		Effects.Play("Place", lastPos)
		if getAvailable(id) <= 0 then
			Placement.Cancel()
		end
	else
		onNotify(reason or "Can't place here", RED)
	end
end

local function tryDelete(screen: Vector2)
	local hit = screenRay(screen)
	local plot = Placement.MyPlot()
	if not hit or not plot then
		return
	end
	local inst: Instance? = hit.Instance
	while inst and inst.Parent ~= plot.Turrets do
		inst = inst.Parent
	end
	if inst then
		(remotes:FindFirstChild("RemoveTurret") :: RemoteEvent):FireServer(inst)
		Effects.Play("Click")
	end
end

function Placement.Init(remoteFolder: Folder, hint: (string?) -> (), notify: (string, Color3?) -> (), available: (string) -> number)
	remotes = remoteFolder
	onHint = hint
	onNotify = notify
	getAvailable = available

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
			if activeId then
				Placement.Cancel()
			elseif deleteMode then
				Placement.SetDeleteMode(false)
			end
			return
		end
		if input.KeyCode == Enum.KeyCode.R and activeId and not processed then
			yaw = (yaw + 45) % 360
			return
		end
		if processed then
			return
		end
		local isClick = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		if not isClick then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			local inset = GuiService:GetGuiInset() -- touch Position excludes the top bar inset
			pointer = Vector2.new(input.Position.X, input.Position.Y) + inset
			update()
		else
			pointer = nil
		end
		if activeId then
			tryPlace()
		elseif deleteMode then
			tryDelete(currentScreenPoint())
		end
	end)
end

return Placement
