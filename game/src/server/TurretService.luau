-- Turret placement on plots, turret models and auto-targeting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local WaveService = require(script.Parent.WaveService)

local TurretService = {}

local remotes: any

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function newPart(props)
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- Builds a turret model. Head is anchored and rotated to aim; barrels are welded to it.
function TurretService.BuildModel(def, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = def.id
	local dark = Color3.fromRGB(55, 60, 75)
	local base = newPart({
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 5.5, 5.5),
		CFrame = cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = dark,
		Anchored = true,
		Parent = model,
	})
	newPart({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 5.9, 5.9),
		CFrame = cf * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Config.RarityColors[def.rarity],
		Material = Enum.Material.Neon,
		Anchored = true,
		CanCollide = false,
		Parent = model,
	})
	newPart({
		Name = "Neck",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 2.2, 2.2),
		CFrame = cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = def.color:Lerp(Color3.new(0, 0, 0), 0.3),
		Anchored = true,
		Parent = model,
	})
	local head = newPart({
		Name = "Head",
		Size = Vector3.new(3, 2.2, 3.2),
		CFrame = cf * CFrame.new(0, 3.6, 0),
		Color = def.color,
		Material = if def.neon then Enum.Material.Glass else Enum.Material.SmoothPlastic,
		Anchored = true,
		Parent = model,
	})
	local barrelLen = if def.long then 5.5 else 3.2
	local n = def.barrels or 1
	for i = 1, n do
		local x = (i - (n + 1) / 2) * 0.9
		local barrel = newPart({
			Name = "Barrel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(barrelLen, 0.7, 0.7),
			CFrame = head.CFrame * CFrame.new(x, 0.1, -1.6 - barrelLen / 2) * CFrame.Angles(0, math.rad(90), 0),
			Color = if def.neon then def.color else Color3.fromRGB(40, 40, 50),
			Material = if def.neon then Enum.Material.Neon else Enum.Material.Metal,
			Anchored = false,
			CanCollide = false,
			Massless = true,
			Parent = model,
		})
		weld(head, barrel)
		local tip = Instance.new("Attachment")
		tip.Name = "Tip"
		tip.Position = Vector3.new(barrelLen / 2, 0, 0)
		tip.Parent = barrel
	end
	if Config.Get(def.id).chance >= 400 then
		local light = Instance.new("PointLight")
		light.Color = Config.RarityColors[def.rarity]
		light.Range = 14
		light.Brightness = 3
		light.Parent = head
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fx.Color = ColorSequence.new(Config.RarityColors[def.rarity])
		fx.Rate = 6
		fx.Lifetime = NumberRange.new(0.8, 1.2)
		fx.Speed = NumberRange.new(1, 2)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx.Size = NumberSequence.new(0.5)
		fx.Parent = head
	end
	-- name tag
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(140, 26)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = def.name
	label.TextColor3 = Config.RarityColors[def.rarity]
	label.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	bb.Parent = head

	model.PrimaryPart = base
	return model, head
end

local function placedCount(plot, id: string): number
	local n = 0
	for _, t in plot.turrets do
		if t.def.id == id then
			n += 1
		end
	end
	return n
end

function TurretService.Place(player: Player, id: string, pos: Vector3, yaw: number)
	if typeof(id) ~= "string" or typeof(pos) ~= "Vector3" or typeof(yaw) ~= "number" then
		return false, "Bad request"
	end
	local plot = PlotService.Get(player)
	local data = DataService.Get(player)
	local def = Config.Get(id)
	if not plot or not data or not def or def.fireRate == nil then
		return false, "Unknown turret"
	end
	local stats = DataService.Stats(player)
	if #plot.turrets >= stats.maxTurrets then
		return false, string.format("Turret limit reached (%d). Buy Slots upgrades!", stats.maxTurrets)
	end
	if placedCount(plot, id) >= (data.inventory[id] or 0) then
		return false, "You don't have any more " .. def.name .. "s"
	end
	local others = {}
	for _, t in plot.turrets do
		table.insert(others, t.position)
	end
	local ground = Vector3.new(pos.X, Config.GroundY, pos.Z)
	local ok, reason = Util.CanPlace(plot.origin, ground, others)
	if not ok then
		return false, reason
	end
	local cf = CFrame.new(ground) * CFrame.Angles(0, math.rad(yaw), 0)
	local model, head = TurretService.BuildModel(def, cf)
	model:SetAttribute("TurretId", id)
	model.Parent = plot.model.Turrets
	table.insert(plot.turrets, {
		def = def,
		model = model,
		head = head,
		headOffset = head.CFrame.Position,
		position = ground,
		cooldown = 0,
	})
	return true, nil
end

function TurretService.Remove(player: Player, model: Instance)
	local plot = PlotService.Get(player)
	if not plot then
		return
	end
	for i, t in plot.turrets do
		if t.model == model then
			t.model:Destroy()
			table.remove(plot.turrets, i)
			return
		end
	end
end

function TurretService.Clear(plot)
	for _, t in plot.turrets do
		t.model:Destroy()
	end
	table.clear(plot.turrets)
end

-- Pick the balloon furthest along the path within range.
local function pickTarget(plot, pos: Vector3, range: number)
	local best, bestDist = nil, -1
	for _, b in plot.balloons do
		if b.alive and b.dist > bestDist then
			local bp = b.model.PrimaryPart.Position
			local flat = Vector2.new(bp.X - pos.X, bp.Z - pos.Z)
			if flat.Magnitude <= range then
				best, bestDist = b, b.dist
			end
		end
	end
	return best
end

local function step(dt: number)
	for _, plot in PlotService.All() do
		if #plot.turrets > 0 and #plot.balloons > 0 and plot.owner then
			local stats = DataService.Stats(plot.owner)
			for _, t in plot.turrets do
				t.cooldown -= dt
				if t.cooldown <= 0 then
					local def = t.def
					local target = pickTarget(plot, t.position, def.range)
					if target then
						t.cooldown = 1 / def.fireRate
						local targetPos = target.model.PrimaryPart.Position
						local headPos = t.headOffset
						t.head.CFrame = CFrame.lookAt(headPos, Vector3.new(targetPos.X, headPos.Y, targetPos.Z))
						local damage = def.damage * stats.damageMult
						if def.splash then
							for _, b in WaveService.BalloonsNear(plot, targetPos, def.splash) do
								WaveService.Damage(b, damage, nil)
							end
						else
							WaveService.Damage(target, damage, nil)
						end
						remotes.Shot:FireAllClients(t.head.Position + t.head.CFrame.LookVector * 3, targetPos, Config.RarityColors[def.rarity], def.splash ~= nil)
					else
						t.cooldown = 0.1
					end
				end
			end
		end
	end
end

function TurretService.Init(remoteFolder: Folder)
	remotes = remoteFolder
	RunService.Heartbeat:Connect(step)
end

return TurretService
