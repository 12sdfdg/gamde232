-- Client-side visuals and sounds: pops, tracers, floating coin text.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local Effects = {}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFX"
fxFolder.Parent = workspace

local rng = Random.new()

local function anchor(pos: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = pos
	p.Parent = fxFolder
	return p
end

function Effects.Play(name: string, pos: Vector3?, speed: number?)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.5
	s.PlaybackSpeed = speed or 1
	if pos then
		local a = anchor(pos)
		s.RollOffMaxDistance = 150
		s.Parent = a
		s:Play()
		Debris:AddItem(a, 3)
	else
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 3)
	end
end

function Effects.FloatText(pos: Vector3, text: string, color: Color3)
	local a = anchor(pos)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 40)
	bb.AlwaysOnTop = true
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.Parent = a
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bb, info, { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	Debris:AddItem(a, 1)
end

function Effects.Pop(pos: Vector3, color: Color3, coins: number, id: string)
	-- rubber shreds
	for _ = 1, 9 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color
		p.Size = Vector3.new(rng:NextNumber(0.4, 0.9), 0.15, rng:NextNumber(0.4, 0.9))
		p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		p.Parent = fxFolder
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1)).Unit
		local goal = CFrame.new(pos + dir * rng:NextNumber(3, 6)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal, Transparency = 1 }):Play()
		Debris:AddItem(p, 0.5)
	end
	-- white flash ring
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.new(1, 1, 1)
	ring.Size = Vector3.new(1, 1, 1)
	ring.Transparency = 0.3
	ring.Position = pos
	ring.Parent = fxFolder
	TweenService:Create(ring, TweenInfo.new(0.2), { Size = Vector3.new(6, 6, 6), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.25)

	if coins > 0 then
		Effects.FloatText(pos, "+$" .. Util.Abbrev(coins), Color3.fromRGB(255, 220, 60))
	end
	local def = Config.Get(id)
	local rare = def and def.chance >= 500
	Effects.Play(if rare then "RareRoll" else "Pop", pos, rng:NextNumber(0.9, 1.15))
end

function Effects.Shot(from: Vector3, to: Vector3, color: Color3, splash: boolean)
	local dist = (to - from).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(0.25, 0.25, dist)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	beam.Parent = fxFolder
	TweenService:Create(beam, TweenInfo.new(0.12), { Transparency = 1, Size = Vector3.new(0.05, 0.05, dist) }):Play()
	Debris:AddItem(beam, 0.15)
	if splash then
		local boom = Instance.new("Part")
		boom.Shape = Enum.PartType.Ball
		boom.Anchored = true
		boom.CanCollide = false
		boom.CanQuery = false
		boom.Material = Enum.Material.Neon
		boom.Color = Color3.fromRGB(255, 160, 40)
		boom.Size = Vector3.new(1, 1, 1)
		boom.Position = to
		boom.Transparency = 0.2
		boom.Parent = fxFolder
		TweenService:Create(boom, TweenInfo.new(0.25), { Size = Vector3.new(9, 9, 9), Transparency = 1 }):Play()
		Debris:AddItem(boom, 0.3)
	end
end

return Effects
