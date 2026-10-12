-- Stylized low-poly props: rocks, cliffs, trees, bushes, flowers, lamps, fences, crystals.
local Props = {}

local V3 = Vector3.new
local CF = CFrame.new
local SMOOTH = Enum.Material.SmoothPlastic

local rng = Random.new(1337)
function Props.Seed(seed)
	rng = Random.new(seed)
end
function Props.Rng()
	return rng
end

local function part(parent, size, cframe, color, opts)
	opts = opts or {}
	local p = Instance.new(opts.class or "Part")
	if opts.shape then
		p.Shape = opts.shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = opts.material or SMOOTH
	p.Anchored = true
	p.CanCollide = opts.collide ~= false
	p.CastShadow = opts.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts.name then
		p.Name = opts.name
	end
	if opts.collide == false then
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = parent
	return p
end
Props.Part = part

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
Props.Model = model

local function randomAngles(amount)
	return CFrame.Angles(rng:NextNumber(-amount, amount), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-amount, amount))
end

-- Faceted boulder made from overlapping rotated blocks and wedges.
function Props.Rock(parent, position, size, color, shade, opts)
	opts = opts or {}
	local m = model(parent, "Rock")
	local pieces = opts.pieces or rng:NextInteger(4, 6)
	for i = 1, pieces do
		local s = size * rng:NextNumber(0.55, 0.95)
		local dims = V3(s * rng:NextNumber(0.8, 1.3), s * rng:NextNumber(0.6, 1.0), s * rng:NextNumber(0.8, 1.2))
		local offset = V3(rng:NextNumber(-0.35, 0.35) * size, rng:NextNumber(-0.1, 0.25) * size, rng:NextNumber(-0.35, 0.35) * size)
		local color3 = (i % 2 == 0) and shade or color
		local class = (i % 3 == 0) and "WedgePart" or "Part"
		part(m, dims, CF(position + offset) * randomAngles(0.45), color3, { class = class, material = opts.material })
	end
	return m
end

-- Tall cliff column made of stacked rocks, slightly tapering upwards.
function Props.Cliff(parent, base, height, width, color, shade, opts)
	local m = model(parent, "Cliff")
	local layers = math.max(2, math.floor(height / (width * 0.55)))
	for i = 0, layers - 1 do
		local t = i / layers
		local w = width * (1 - t * 0.35)
		local y = base.Y + t * height + w * 0.3
		local jitter = V3(rng:NextNumber(-0.18, 0.18) * width, 0, rng:NextNumber(-0.18, 0.18) * width)
		local rock = Props.Rock(m, V3(base.X, y, base.Z) + jitter, w, color, shade, opts)
		rock.Parent = m
	end
	return m
end

-- Large stylized tree: dark slim trunk, crooked branches, wide low-poly canopy clusters.
function Props.Tree(parent, position, height, palette, opts)
	opts = opts or {}
	local m = model(parent, "Tree")
	local trunkColor = palette.Trunk
	local segments = 3
	local lean = V3(rng:NextNumber(-0.25, 0.25), 1, rng:NextNumber(-0.25, 0.25)).Unit
	local points = { position + V3(0, -1, 0) }
	local current = position
	local trunkWidth = math.max(1.2, height * 0.065)
	for i = 1, segments do
		local dir = (lean + V3(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25))).Unit
		current = current + dir * (height * 0.62 / segments)
		table.insert(points, current)
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local w = trunkWidth * (1 - (i - 1) * 0.18)
		local center = (a + b) / 2
		part(m, V3(w, w, (b - a).Magnitude + w * 0.5), CFrame.lookAt(center, b), trunkColor)
	end
	-- Roots
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(0, 1)
		local dir = V3(math.cos(a), 0, math.sin(a))
		part(m, V3(trunkWidth * 0.6, trunkWidth * 0.5, trunkWidth * 2.4), CFrame.lookAt(position + dir * trunkWidth * 0.9 + V3(0, 0.2, 0), position + dir * 3 - V3(0, 1.5, 0)), trunkColor, { class = "WedgePart" })
	end

	local top = points[#points]
	local canopyCenters = { top + V3(0, height * 0.08, 0) }
	local branches = opts.branches or rng:NextInteger(3, 4)
	for i = 1, branches do
		local a = (i / branches) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local from = points[#points - 1]:Lerp(top, rng:NextNumber(0.3, 0.9))
		local to = from + V3(math.cos(a) * height * 0.3, height * rng:NextNumber(0.12, 0.22), math.sin(a) * height * 0.3)
		local center = (from + to) / 2
		part(m, V3(trunkWidth * 0.5, trunkWidth * 0.5, (to - from).Magnitude), CFrame.lookAt(center, to), trunkColor)
		table.insert(canopyCenters, to)
	end
	for i, c in ipairs(canopyCenters) do
		local blob = height * (i == 1 and 0.34 or 0.26)
		for j = 1, 4 do
			local offset = V3(rng:NextNumber(-0.6, 0.6) * blob, rng:NextNumber(-0.15, 0.35) * blob, rng:NextNumber(-0.6, 0.6) * blob)
			local size = blob * rng:NextNumber(0.75, 1.15)
			local color = (j % 2 == 0) and palette.Leaf2 or palette.Leaf
			part(m, V3(size, size * 0.7, size), CF(c + offset) * randomAngles(0.35), color, { collide = false })
		end
	end
	return m
end

-- Pine tree for snowy islands.
function Props.Pine(parent, position, height, palette)
	local m = model(parent, "Pine")
	part(m, V3(1.4, height * 0.4, 1.4), CF(position + V3(0, height * 0.2, 0)), palette.Trunk)
	for i = 0, 3 do
		local t = i / 4
		local w = height * 0.5 * (1 - t * 0.7)
		local y = height * (0.3 + t * 0.55)
		for k = 0, 3 do
			part(m, V3(w, height * 0.2, w * 0.5), CF(position + V3(0, y, 0)) * CFrame.Angles(0, k * math.pi / 2 + i * 0.4, 0) * CF(0, 0, w * 0.25), k % 2 == 0 and palette.Leaf or palette.Leaf:Lerp(Color3.new(1, 1, 1), 0.15), { class = "WedgePart", collide = false })
		end
		part(m, V3(w * 0.9, height * 0.04, w * 0.9), CF(position + V3(0, y + height * 0.1, 0)) * CFrame.Angles(0, i, 0), palette.Leaf2, { collide = false })
	end
	return m
end

-- Palm tree for the desert.
function Props.Palm(parent, position, height, palette)
	local m = model(parent, "Palm")
	local current = position
	local bend = V3(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * 0.12
	for i = 1, 6 do
		local nextPoint = current + (V3(0, 1, 0) + bend * i).Unit * (height / 6)
		local center = (current + nextPoint) / 2
		part(m, V3(1.5 - i * 0.08, 1.5 - i * 0.08, height / 6 + 0.4), CFrame.lookAt(center, nextPoint), i % 2 == 0 and palette.Trunk or palette.Trunk:Lerp(Color3.new(0, 0, 0), 0.15))
		current = nextPoint
	end
	for i = 1, 7 do
		local a = (i / 7) * math.pi * 2
		local tip = current + V3(math.cos(a) * height * 0.38, -height * 0.12, math.sin(a) * height * 0.38)
		local center = (current + tip) / 2
		part(m, V3(height * 0.12, 0.3, (tip - current).Magnitude), CFrame.lookAt(center, tip), i % 2 == 0 and palette.Leaf or palette.Leaf2, { collide = false })
	end
	return m
end

-- Crystal cluster (used in frozen/celestial/dark worlds).
function Props.Crystal(parent, position, height, color, glow)
	local m = model(parent, "Crystal")
	for i = 1, rng:NextInteger(3, 5) do
		local h = height * rng:NextNumber(0.5, 1)
		local w = h * 0.28
		local tilt = CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6.28), rng:NextNumber(-0.35, 0.35))
		local base = CF(position + V3(rng:NextNumber(-1, 1) * w, 0, rng:NextNumber(-1, 1) * w)) * tilt
		part(m, V3(w, h, w), base * CF(0, h / 2, 0), color, { material = glow and Enum.Material.Neon or Enum.Material.Glass, transparency = glow and 0.1 or 0.25 })
		part(m, V3(w, w * 1.2, w), base * CF(0, h + w * 0.3, 0) * CFrame.Angles(0, 0, math.rad(45)), color, { class = "WedgePart", material = glow and Enum.Material.Neon or Enum.Material.Glass, transparency = glow and 0.1 or 0.25 })
	end
	return m
end

function Props.Bush(parent, position, size, palette)
	local m = model(parent, "Bush")
	for i = 1, 3 do
		local s = size * rng:NextNumber(0.7, 1.1)
		part(m, V3(s, s, s), CF(position + V3(rng:NextNumber(-0.5, 0.5) * size, s * 0.3, rng:NextNumber(-0.5, 0.5) * size)), i % 2 == 0 and palette.Leaf2 or palette.Leaf, { shape = Enum.PartType.Ball, collide = false })
	end
	return m
end

function Props.Flowers(parent, position, palette)
	local m = model(parent, "Flowers")
	for _ = 1, rng:NextInteger(3, 6) do
		local p = position + V3(rng:NextNumber(-2.5, 2.5), 0.45, rng:NextNumber(-2.5, 2.5))
		local color = palette.Flowers[rng:NextInteger(1, #palette.Flowers)]
		part(m, V3(0.2, 0.9, 0.2), CF(p - V3(0, 0.2, 0)), palette.Leaf, { collide = false, shadow = false })
		part(m, V3(0.75, 0.75, 0.75), CF(p + V3(0, 0.35, 0)), color, { shape = Enum.PartType.Ball, collide = false, shadow = false })
	end
	return m
end

function Props.Lamp(parent, position, color, lightColor)
	local m = model(parent, "Lamp")
	part(m, V3(0.7, 9, 0.7), CF(position + V3(0, 4.5, 0)), color)
	part(m, V3(1.6, 0.5, 1.6), CF(position + V3(0, 0.25, 0)), color)
	part(m, V3(2.6, 0.4, 0.5), CF(position + V3(0.9, 8.8, 0)), color)
	local lantern = part(m, V3(1.3, 1.6, 1.3), CF(position + V3(1.8, 7.9, 0)), lightColor, { material = Enum.Material.Neon, collide = false })
	part(m, V3(1.6, 0.35, 1.6), CF(position + V3(1.8, 8.8, 0)), color)
	local light = Instance.new("PointLight")
	light.Color = lightColor
	light.Range = 18
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = lantern
	return m
end

function Props.Fence(parent, a, b, color)
	local m = model(parent, "Fence")
	local length = (b - a).Magnitude
	local posts = math.max(2, math.floor(length / 6))
	for i = 0, posts do
		local p = a:Lerp(b, i / posts)
		part(m, V3(0.7, 3.4, 0.7), CF(p + V3(0, 1.5, 0)), color)
	end
	for _, h in ipairs({ 1.2, 2.6 }) do
		local center = (a + b) / 2 + V3(0, h, 0)
		part(m, V3(0.35, 0.45, length), CFrame.lookAt(center, b + V3(0, h, 0)), color)
	end
	return m
end

-- Thin ground "beam" of light, adds god-ray atmosphere.
function Props.LightShaft(parent, position, height, width, color)
	local p = part(parent, V3(width, height, width), CF(position + V3(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12))), color, { material = Enum.Material.Neon, transparency = 0.93, collide = false, shadow = false, name = "LightShaft" })
	return p
end

function Props.Sparkles(parent, color, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = rate or 8
	e.Lifetime = NumberRange.new(1.5, 3)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = parent
	return e
end

return Props
