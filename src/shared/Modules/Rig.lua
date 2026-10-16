-- Procedural anime-style characters built from parts.
-- Every rig uses the same joints so the client AnimationController can animate fighters, NPCs and enemies:
--   Root -> RootJoint -> Torso -> Neck -> Head
--   Torso -> LShoulder/RShoulder -> LArm/RArm
--   Root -> LHip/RHip -> LLeg/RLeg
-- Characters face -Z. Feet rest at Y = 0 in model space before pivoting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configs = ReplicatedStorage:WaitForChild("Configs")
local Rarities = require(Configs:WaitForChild("Rarities"))

local Rig = {}

local V3 = Vector3.new
local CF = CFrame.new
local SMOOTH = Enum.Material.SmoothPlastic
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(24, 20, 30)

local function part(model, name, size, cframe, color, opts)
	opts = opts or {}
	local p = Instance.new(opts.class or "Part")
	if opts.shape then
		p.Shape = opts.shape
	end
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = opts.material or SMOOTH
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = opts.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	p.Parent = model
	return p
end

local function weld(base, p)
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = p
	w.Parent = p
	return p
end

local function motor(name, p0, p1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p0
	return m
end

local function ball(model, name, diameter, position, color, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Ball
	return part(model, name, V3(diameter, diameter, diameter), CF(position), color, opts)
end

-- Cylinder whose axis points along `axis` (unit vector).
local function cylinder(model, name, length, diameter, position, axis, color, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Cylinder
	local look = axis.Unit
	local up = math.abs(look.Y) > 0.95 and V3(0, 0, 1) or V3(0, 1, 0)
	-- Cylinder length runs along local X; orient X along the axis.
	local cf = CFrame.lookAt(position, position + look, up) * CFrame.Angles(0, math.rad(90), 0)
	return part(model, name, V3(length, diameter, diameter), cf, color, opts)
end

-- Blade-like spike (WedgePart) from base towards direction, thin at the tip.
local function spike(model, name, base, direction, length, width, thickness, color, opts)
	opts = opts or {}
	opts.class = "WedgePart"
	local dir = direction.Unit
	local up = math.abs(dir.Y) > 0.95 and V3(0, 0, 1) or V3(0, 1, 0)
	local center = base + dir * (length / 2)
	local cf = CFrame.lookAt(center, center + dir, up)
	return part(model, name, V3(width, thickness, length), cf, color, opts)
end

-- Plain block between two points.
local function beam(model, name, a, b, width, thickness, color, opts)
	local center = (a + b) / 2
	local length = (b - a).Magnitude
	local up = math.abs((b - a).Unit.Y) > 0.95 and V3(0, 0, 1) or V3(0, 1, 0)
	return part(model, name, V3(width, thickness, length), CFrame.lookAt(center, b, up), color, opts)
end

Rig.Helpers = { part = part, weld = weld, ball = ball, cylinder = cylinder, spike = spike, beam = beam }

---------------------------------------------------------------------------------------------------
-- Skeleton
---------------------------------------------------------------------------------------------------

local function skeleton(model, s, prop, colors)
	local torsoSize = prop.torso * s
	local armSize = prop.arm * s
	local legSize = prop.leg * s
	local headD = prop.head * s
	local hip = legSize.Y + 0.6 * s

	local root = part(model, "Root", V3(2, 2, 1) * s, CF(0, hip, 0), WHITE, { transparency = 1, shadow = false })
	root.Massless = false
	model.PrimaryPart = root
	model:SetAttribute("HipHeight", hip)

	local torso = part(model, "Torso", torsoSize, CF(0, hip + torsoSize.Y / 2, 0), colors.torso)
	motor("RootJoint", root, torso, CF(), CF(0, -torsoSize.Y / 2, 0))

	local headCenter = V3(0, hip + torsoSize.Y + 0.15 * s + headD / 2, 0)
	local head = ball(model, "Head", headD, headCenter, colors.skin)
	motor("Neck", torso, head, CF(0, torsoSize.Y / 2, 0), CF(0, -(0.15 * s + headD / 2), 0))
	for _, side in ipairs({ -1, 1 }) do
		weld(head, ball(model, "Ear", headD * 0.22, headCenter + V3(side * headD * 0.48, -0.05 * s, 0.05 * s), colors.skin))
	end
	weld(head, cylinder(model, "NeckPart", 0.5 * s, 0.8 * s, V3(0, hip + torsoSize.Y + 0.1 * s, 0), V3(0, 1, 0), colors.skin))

	local shoulderX = torsoSize.X / 2 + armSize.X / 2 - 0.02 * s
	local shoulderY = torsoSize.Y / 2 - 0.2 * s
	local arms = {}
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "LArm" or "RArm"
		local pivot = V3(side * shoulderX, hip + torsoSize.Y / 2 + shoulderY, 0)
		local arm = part(model, name, armSize, CF(pivot - V3(0, armSize.Y / 2 - 0.15 * s, 0)), colors.arm)
		motor(side < 0 and "LShoulder" or "RShoulder", torso, arm, CF(side * shoulderX, shoulderY, 0), CF(0, armSize.Y / 2 - 0.15 * s, 0))
		local handPos = pivot - V3(0, armSize.Y - 0.1 * s, 0)
		weld(arm, ball(model, name .. "Hand", armSize.X * 1.15, handPos, colors.hand))
		-- Rounded shoulder so the arm blends into the torso.
		weld(arm, ball(model, name .. "Shoulder", armSize.X * 1.3, pivot - V3(0, 0.05 * s, 0), colors.torso))
		arms[side] = { part = arm, hand = handPos }
	end

	local legs = {}
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "LLeg" or "RLeg"
		local x = side * prop.legGap * s
		local leg = part(model, name, legSize, CF(x, hip - legSize.Y / 2, 0), colors.leg)
		motor(side < 0 and "LHip" or "RHip", root, leg, CF(x, 0, 0), CF(0, legSize.Y / 2, 0))
		weld(leg, part(model, name .. "Shoe", V3(legSize.X * 1.12, 0.6 * s, legSize.Z * 1.35), CF(x, 0.3 * s, -0.12 * s), colors.shoe))
		weld(leg, ball(model, name .. "Toe", legSize.X * 1.05, V3(x, 0.32 * s, -0.55 * s), colors.shoe))
		weld(leg, part(model, name .. "Cuff", V3(legSize.X * 1.2, 0.35 * s, legSize.Z * 1.2), CF(x, 0.75 * s, 0), colors.shoe:Lerp(WHITE, 0.25)))
		legs[side] = leg
	end
	-- Pelvis bridges the legs and torso.
	weld(torso, part(model, "Pelvis", V3(torsoSize.X * 0.96, 0.75 * s, torsoSize.Z * 0.98), CF(0, hip - 0.15 * s, 0), colors.leg))
	-- Chest highlight panel gives the torso some shading.
	weld(torso, part(model, "Chest", V3(torsoSize.X * 0.7, torsoSize.Y * 0.45, 0.06 * s), CF(0, hip + torsoSize.Y * 0.68, -torsoSize.Z / 2 - 0.02 * s), colors.torso:Lerp(WHITE, 0.12), { shadow = false }))

	return {
		s = s,
		root = root,
		torso = torso,
		head = head,
		headCenter = headCenter,
		headR = headD / 2,
		hip = hip,
		torsoSize = torsoSize,
		armSize = armSize,
		legSize = legSize,
		arms = arms,
		legs = legs,
	}
end

---------------------------------------------------------------------------------------------------
-- Face
---------------------------------------------------------------------------------------------------

local function surfacePoint(rig, x, y)
	local r = rig.headR
	local z = -math.sqrt(math.max(r * r - x * x - y * y, 0.01))
	local pos = rig.headCenter + V3(x, y, z)
	local normal = (pos - rig.headCenter).Unit
	return pos, normal
end

local function face(model, rig, eyeColor, angry, glowing)
	local r = rig.headR
	for _, side in ipairs({ -1, 1 }) do
		local pos, normal = surfacePoint(rig, side * 0.36 * r, -0.02 * r)
		local base = CFrame.lookAt(pos, pos + normal)
		if glowing then
			weld(rig.head, part(model, "Eye", V3(0.3 * r, 0.42 * r, 0.08 * r), base, eyeColor, { material = Enum.Material.Neon, shadow = false }))
		else
			weld(rig.head, part(model, "Sclera", V3(0.36 * r, 0.56 * r, 0.05 * r), base, WHITE, { shadow = false }))
			weld(rig.head, part(model, "EyeOuter", V3(0.28 * r, 0.48 * r, 0.06 * r), base * CF(-side * 0.02 * r, -0.03 * r, -0.02 * r), BLACK, { shadow = false }))
			weld(rig.head, part(model, "Iris", V3(0.22 * r, 0.36 * r, 0.06 * r), base * CF(-side * 0.02 * r, -0.07 * r, -0.04 * r), eyeColor, { shadow = false }))
			weld(rig.head, part(model, "IrisLight", V3(0.16 * r, 0.12 * r, 0.05 * r), base * CF(-side * 0.02 * r, -0.17 * r, -0.06 * r), eyeColor:Lerp(WHITE, 0.45), { shadow = false }))
			weld(rig.head, part(model, "Shine", V3(0.09 * r, 0.13 * r, 0.04 * r), base * CF(-side * 0.06 * r, 0.08 * r, -0.08 * r), WHITE, { material = Enum.Material.Neon, shadow = false }))
			weld(rig.head, part(model, "Lash", V3(0.44 * r, 0.09 * r, 0.07 * r), base * CF(side * 0.02 * r, 0.27 * r, -0.03 * r) * CFrame.Angles(0, 0, -side * 0.18), BLACK, { shadow = false }))
			if not angry then
				local cheek, cheekNormal = surfacePoint(rig, side * 0.55 * r, -0.36 * r)
				weld(rig.head, part(model, "Blush", V3(0.24 * r, 0.1 * r, 0.04 * r), CFrame.lookAt(cheek, cheek + cheekNormal), Color3.fromRGB(255, 130, 150), { transparency = 0.35, shadow = false }))
			end
		end
		local browPos, browNormal = surfacePoint(rig, side * 0.38 * r, 0.42 * r)
		local tilt = angry and side * 0.35 or -side * 0.12
		weld(rig.head, part(model, "Brow", V3(0.4 * r, 0.07 * r, 0.06 * r), CFrame.lookAt(browPos, browPos + browNormal) * CFrame.Angles(0, 0, tilt), BLACK, { shadow = false }))
	end
	local mouthPos, mouthNormal = surfacePoint(rig, 0, -0.46 * r)
	weld(rig.head, part(model, "Mouth", V3(angry and 0.36 * r or 0.24 * r, 0.05 * r, 0.05 * r), CFrame.lookAt(mouthPos, mouthPos + mouthNormal), BLACK, { shadow = false }))
end

---------------------------------------------------------------------------------------------------
-- Hair
---------------------------------------------------------------------------------------------------

local SPIKY_DIRS = {
	V3(0, 1, 0.25), V3(0.55, 0.8, 0.2), V3(-0.55, 0.8, 0.2), V3(0.85, 0.35, 0.35), V3(-0.85, 0.35, 0.35),
	V3(0.35, 0.55, 0.85), V3(-0.35, 0.55, 0.85), V3(0, 0.2, 1), V3(0.6, -0.1, 0.8), V3(-0.6, -0.1, 0.8),
}

local function bangs(model, rig, color, count, length)
	local r = rig.headR
	for i = 1, count do
		local x = (i - (count + 1) / 2) * 0.42 * r
		local base = rig.headCenter + V3(x, 0.78 * r, -0.62 * r)
		weld(rig.head, spike(model, "Bang", base, V3(x * 0.25, -1, -0.45), length * r, 0.42 * r, 0.3 * r, color))
	end
end

local function hair(model, rig, style, color)
	local r = rig.headR
	local hc = rig.headCenter
	if style == "Bald" then
		return
	end
	local capOffset = style == "Slick" and V3(0, 0.22 * r, 0.3 * r) or V3(0, 0.2 * r, 0.2 * r)
	weld(rig.head, ball(model, "HairCap", r * 2.12, hc + capOffset, color))
	weld(rig.head, ball(model, "HairVolume", r * 1.7, hc + V3(0, 0.35 * r, 0.55 * r), color:Lerp(BLACK, 0.08)))
	for _, side in ipairs({ -1, 1 }) do
		weld(rig.head, spike(model, "Sideburn", hc + V3(side * 0.9 * r, 0.35 * r, -0.2 * r), V3(side * 0.15, -1, -0.25), 0.75 * r, 0.32 * r, 0.32 * r, color))
	end

	if style == "Spiky" or style == "Wild" then
		local wild = style == "Wild"
		for i, dir in ipairs(SPIKY_DIRS) do
			if wild or i <= 8 then
				local d = dir.Unit
				local len = (wild and 1.5 or 1.1) * r * (0.8 + ((i * 37) % 10) / 25)
				weld(rig.head, spike(model, "Spike", hc + d * r * 0.7, d, len, 0.62 * r, 0.5 * r, color))
			end
		end
		if wild then
			for _, side in ipairs({ -1, 1 }) do
				weld(rig.head, spike(model, "Spike", hc + V3(side * 0.8 * r, -0.2 * r, 0.3 * r), V3(side, -0.6, 0.5), 1.2 * r, 0.5 * r, 0.45 * r, color))
			end
		end
		bangs(model, rig, color, 3, 0.55)
	elseif style == "Short" then
		for i = 1, 4 do
			local a = (i - 2.5) * 0.5
			local d = V3(math.sin(a) * 0.6, 0.85, 0.2 + math.cos(a) * 0.1).Unit
			weld(rig.head, spike(model, "Spike", hc + d * r * 0.75, d, 0.6 * r, 0.55 * r, 0.4 * r, color))
		end
		bangs(model, rig, color, 3, 0.45)
	elseif style == "Slick" then
		for i = 1, 5 do
			local x = (i - 3) * 0.32
			local d = V3(x, 0.35, 1).Unit
			weld(rig.head, spike(model, "Spike", hc + V3(x * r, 0.55 * r, 0.3 * r), d, 1.2 * r, 0.5 * r, 0.42 * r, color))
		end
		weld(rig.head, spike(model, "Bang", hc + V3(0.3 * r, 0.8 * r, -0.6 * r), V3(0.5, -1, -0.5), 0.7 * r, 0.45 * r, 0.3 * r, color))
	elseif style == "Long" then
		weld(rig.head, part(model, "HairBack", V3(2.0 * r, 2.6 * r, 0.6 * r), CF(hc + V3(0, -0.9 * r, 0.75 * r)), color))
		for _, side in ipairs({ -1, 1 }) do
			weld(rig.head, part(model, "HairSide", V3(0.45 * r, 1.9 * r, 0.6 * r), CF(hc + V3(side * 0.95 * r, -0.55 * r, -0.15 * r)), color))
		end
		bangs(model, rig, color, 4, 0.55)
	elseif style == "Ponytail" then
		weld(rig.head, ball(model, "Tie", 0.75 * r, hc + V3(0, 0.55 * r, 1.0 * r), color))
		local tail = beam(model, "Tail", hc + V3(0, 0.55 * r, 1.15 * r), hc + V3(0, -1.6 * r, 1.55 * r), 0.75 * r, 0.75 * r, color)
		weld(rig.head, tail)
		bangs(model, rig, color, 3, 0.55)
	end
end

---------------------------------------------------------------------------------------------------
-- Outfits & accessories
---------------------------------------------------------------------------------------------------

local function sleeve(model, rig, side, color, length, thickness)
	local arm = rig.arms[side].part
	local size = rig.armSize
	local top = arm.Position + V3(0, size.Y / 2, 0)
	weld(arm, part(model, "Sleeve", V3(size.X * thickness, size.Y * length, size.Z * thickness), CF(top - V3(0, size.Y * length / 2, 0)), color))
end

local function outfit(model, rig, look)
	local s = rig.s
	local t = rig.torso
	local ts = rig.torsoSize
	local tp = t.Position
	local style = look.outfit
	local accent = look.accent or WHITE

	-- Belt
	weld(t, part(model, "Belt", V3(ts.X * 1.04, 0.28 * s, ts.Z * 1.06), CF(tp - V3(0, ts.Y / 2 - 0.14 * s, 0)), BLACK))
	weld(t, part(model, "Buckle", V3(0.42 * s, 0.3 * s, 0.1 * s), CF(tp + V3(0, -ts.Y / 2 + 0.14 * s, -ts.Z / 2 - 0.04 * s)), Color3.fromRGB(255, 205, 70), { material = Enum.Material.Metal }))

	if style == "Tee" then
		for _, side in ipairs({ -1, 1 }) do
			sleeve(model, rig, side, look.top, 0.38, 1.12)
		end
		weld(t, part(model, "Stripe", V3(ts.X * 1.02, 0.25 * s, ts.Z * 1.02), CF(tp + V3(0, 0.35 * s, 0)), accent))
	elseif style == "Vest" then
		t.Color = look.skin
		for _, side in ipairs({ -1, 1 }) do
			weld(t, part(model, "VestPanel", V3(ts.X * 0.36, ts.Y * 1.0, ts.Z * 1.08), CF(tp + V3(side * ts.X * 0.33, 0, 0)), look.top))
		end
		weld(t, part(model, "VestBack", V3(ts.X * 1.04, ts.Y, ts.Z * 0.2), CF(tp + V3(0, 0, ts.Z * 0.46)), look.top))
		for _, side in ipairs({ -1, 1 }) do
			sleeve(model, rig, side, accent, 0.25, 1.1)
		end
	elseif style == "Suit" then
		for _, side in ipairs({ -1, 1 }) do
			sleeve(model, rig, side, look.top, 0.9, 1.08)
		end
		weld(t, part(model, "Shirt", V3(ts.X * 0.34, ts.Y * 0.9, 0.1 * s), CF(tp + V3(0, 0.05 * s, -ts.Z / 2 - 0.03 * s)), WHITE))
		weld(t, part(model, "Tie", V3(0.22 * s, ts.Y * 0.7, 0.12 * s), CF(tp + V3(0, 0.05 * s, -ts.Z / 2 - 0.08 * s)), accent))
	elseif style == "Coat" then
		for _, side in ipairs({ -1, 1 }) do
			sleeve(model, rig, side, look.top, 0.95, 1.12)
			weld(t, part(model, "Lapel", V3(0.22 * s, ts.Y * 0.95, 0.12 * s), CF(tp + V3(side * 0.25 * s, 0, -ts.Z / 2 - 0.04 * s)), accent))
			-- Coat tails hanging behind the legs.
			local tail = part(model, "CoatTail", V3(ts.X * 0.5, rig.legSize.Y * 0.95, 0.18 * s), CF(V3(side * ts.X * 0.25, rig.hip - rig.legSize.Y * 0.42, ts.Z * 0.42)) * CFrame.Angles(math.rad(8), 0, 0), look.top)
			weld(t, tail)
		end
		weld(t, part(model, "Collar", V3(ts.X * 1.1, 0.5 * s, ts.Z * 1.15), CF(tp + V3(0, ts.Y / 2 - 0.05 * s, 0.05 * s)), look.top))
	elseif style == "Robe" then
		for _, side in ipairs({ -1, 1 }) do
			sleeve(model, rig, side, look.top, 0.9, 1.35)
		end
		local skirt = part(model, "Robe", V3(ts.X * 1.12, rig.legSize.Y * 0.8, ts.Z * 1.3), CF(V3(0, rig.hip - rig.legSize.Y * 0.32, 0)), look.top)
		weld(t, skirt)
		weld(t, part(model, "Sash", V3(ts.X * 1.08, 0.4 * s, ts.Z * 1.12), CF(tp - V3(0, ts.Y / 2 - 0.25 * s, 0)), accent))
	elseif style == "Armor" then
		for _, side in ipairs({ -1, 1 }) do
			sleeve(model, rig, side, look.bottom, 0.95, 1.06)
			weld(t, ball(model, "Pauldron", rig.armSize.X * 1.9, tp + V3(side * (ts.X / 2 + 0.25 * s), ts.Y / 2 - 0.1 * s, 0), accent, { material = Enum.Material.Metal }))
		end
		weld(t, part(model, "Chestplate", V3(ts.X * 0.9, ts.Y * 0.6, 0.2 * s), CF(tp + V3(0, 0.25 * s, -ts.Z / 2 - 0.08 * s)), accent, { material = Enum.Material.Metal }))
	elseif style == "Hoodie" then
		for _, side in ipairs({ -1, 1 }) do
			sleeve(model, rig, side, look.top, 0.95, 1.15)
		end
		weld(t, part(model, "Pocket", V3(ts.X * 0.6, ts.Y * 0.3, 0.1 * s), CF(tp + V3(0, -0.4 * s, -ts.Z / 2 - 0.04 * s)), accent))
		weld(t, ball(model, "HoodBack", ts.X * 0.9, tp + V3(0, ts.Y / 2, ts.Z * 0.55), look.top))
	end
end

local function accessories(model, rig, look)
	local r = rig.headR
	local hc = rig.headCenter
	local s = rig.s
	local accent = look.accent or WHITE
	local gold = Color3.fromRGB(255, 205, 70)
	for _, acc in ipairs(look.acc or {}) do
		if acc == "Bandana" or acc == "Headband" then
			local thick = acc == "Bandana" and 0.42 or 0.24
			weld(rig.head, cylinder(model, acc, thick * r, 2.16 * r, hc + V3(0, 0.42 * r, 0.02 * r), V3(0, 1, 0), accent))
			for _, side in ipairs({ -1, 1 }) do
				weld(rig.head, spike(model, "Knot", hc + V3(side * 0.15 * r, 0.42 * r, 1.0 * r), V3(side * 0.6, -0.5, 1), 0.9 * r, 0.3 * r, 0.12 * r, accent))
			end
		elseif acc == "Captain" or acc == "Hat" then
			weld(rig.head, cylinder(model, "Brim", 0.18 * r, 3.3 * r, hc + V3(0, 0.82 * r, 0.05 * r), V3(0, 1, 0), BLACK))
			weld(rig.head, part(model, "HatTop", V3(1.9 * r, 1.0 * r, 1.8 * r), CF(hc + V3(0, 1.38 * r, 0.1 * r)), BLACK))
			weld(rig.head, part(model, "HatBand", V3(1.95 * r, 0.22 * r, 1.85 * r), CF(hc + V3(0, 1.0 * r, 0.1 * r)), gold, { material = Enum.Material.Metal }))
			weld(rig.head, ball(model, "Emblem", 0.45 * r, hc + V3(0, 1.38 * r, -0.82 * r), WHITE))
			weld(rig.head, spike(model, "Feather", hc + V3(0.7 * r, 1.4 * r, 0.3 * r), V3(0.4, 1, 0.5), 1.6 * r, 0.32 * r, 0.2 * r, accent))
		elseif acc == "Scarf" then
			local neck = V3(0, rig.hip + rig.torsoSize.Y + 0.05 * s, 0)
			weld(rig.torso, cylinder(model, "Scarf", 0.55 * s, 1.75 * s, neck, V3(0, 1, 0), accent, { material = Enum.Material.Fabric }))
			weld(rig.torso, part(model, "ScarfTail", V3(0.5 * s, 1.8 * s, 0.15 * s), CF(neck + V3(0.4 * s, -0.8 * s, 0.75 * s)) * CFrame.Angles(math.rad(20), 0, math.rad(-10)), accent, { material = Enum.Material.Fabric }))
		elseif acc == "Cape" then
			local top = rig.torso.Position + V3(0, rig.torsoSize.Y / 2 - 0.1 * s, rig.torsoSize.Z / 2 + 0.12 * s)
			local cape = part(model, "Cape", V3(rig.torsoSize.X * 1.15, 4.2 * s, 0.14 * s), CF(top + V3(0, -2.05 * s, 0.38 * s)) * CFrame.Angles(math.rad(-10), 0, 0), accent, { material = Enum.Material.Fabric })
			weld(rig.torso, cape)
			weld(rig.torso, part(model, "CapeLining", V3(rig.torsoSize.X * 1.05, 3.9 * s, 0.05 * s), cape.CFrame * CF(0, 0.1 * s, -0.08 * s), look.top, { material = Enum.Material.Fabric }))
		elseif acc == "Horns" then
			for _, side in ipairs({ -1, 1 }) do
				weld(rig.head, spike(model, "Horn", hc + V3(side * 0.55 * r, 0.75 * r, 0), V3(side * 0.55, 1, 0.15), 1.25 * r, 0.32 * r, 0.32 * r, Color3.fromRGB(40, 32, 40)))
			end
		elseif acc == "Halo" then
			local center = hc + V3(0, 1.55 * r, 0.25 * r)
			for i = 1, 12 do
				local a = (i / 12) * math.pi * 2
				local a2 = ((i + 1) / 12) * math.pi * 2
				local p1 = center + V3(math.cos(a), 0, math.sin(a)) * 0.95 * r
				local p2 = center + V3(math.cos(a2), 0, math.sin(a2)) * 0.95 * r
				weld(rig.head, beam(model, "Halo", p1, p2, 0.16 * r, 0.12 * r, Color3.fromRGB(255, 236, 140), { material = Enum.Material.Neon, shadow = false }))
			end
		elseif acc == "Mask" then
			weld(rig.head, part(model, "Mask", V3(1.75 * r, 0.75 * r, 0.6 * r), CF(hc + V3(0, -0.5 * r, -0.72 * r)), BLACK))
			weld(rig.head, part(model, "MaskLine", V3(1.6 * r, 0.08 * r, 0.62 * r), CF(hc + V3(0, -0.4 * r, -0.74 * r)), accent, { material = Enum.Material.Neon, shadow = false }))
		elseif acc == "Crown" then
			weld(rig.head, cylinder(model, "Crown", 0.35 * r, 1.6 * r, hc + V3(0, 1.08 * r, 0.1 * r), V3(0, 1, 0), gold, { material = Enum.Material.Metal }))
			for i = 1, 5 do
				local a = (i / 5) * math.pi * 2
				local p = hc + V3(math.cos(a) * 0.68 * r, 1.2 * r, 0.1 * r + math.sin(a) * 0.68 * r)
				weld(rig.head, spike(model, "CrownSpike", p, V3(0, 1, 0), 0.55 * r, 0.3 * r, 0.3 * r, gold, { material = Enum.Material.Metal }))
			end
		elseif acc == "Goggles" then
			weld(rig.head, cylinder(model, "Strap", 0.2 * r, 2.18 * r, hc + V3(0, 0.62 * r, 0.02 * r), V3(0, 1, 0), BLACK))
			for _, side in ipairs({ -1, 1 }) do
				weld(rig.head, cylinder(model, "Lens", 0.25 * r, 0.55 * r, hc + V3(side * 0.32 * r, 0.75 * r, -0.85 * r), V3(0, 0.35, -1), accent, { material = Enum.Material.Neon }))
			end
		elseif acc == "Hood" then
			weld(rig.head, ball(model, "Hood", r * 2.3, hc + V3(0, 0.15 * r, 0.32 * r), look.top))
		end
	end
end

local function weapon(model, rig, look)
	local kind = look.weapon
	local s = rig.s
	local arm = rig.arms[1].part
	local hand = rig.arms[1].hand
	local accent = look.accent or WHITE
	local gold = Color3.fromRGB(255, 205, 70)
	local steel = Color3.fromRGB(220, 228, 240)
	local dark = Color3.fromRGB(40, 32, 30)

	local function add(p)
		return weld(arm, p)
	end

	if kind == "Sword" or kind == "Katana" then
		local katana = kind == "Katana"
		local dir = V3(0, 0.25, -1).Unit
		add(beam(model, "Handle", hand - dir * 0.5 * s, hand + dir * 0.6 * s, 0.24 * s, 0.24 * s, dark))
		add(beam(model, "Guard", hand + dir * 0.6 * s, hand + dir * 0.75 * s, katana and 0.6 * s or 1.2 * s, katana and 0.6 * s or 0.25 * s, gold, { material = Enum.Material.Metal }))
		local len = katana and 4.6 or 3.8
		add(beam(model, "Blade", hand + dir * 0.75 * s, hand + dir * len * s, 0.12 * s, katana and 0.32 * s or 0.5 * s, steel, { material = Enum.Material.Metal }))
		add(beam(model, "Edge", hand + dir * 0.8 * s, hand + dir * (len - 0.1) * s, 0.06 * s, 0.12 * s, accent, { material = Enum.Material.Neon, shadow = false }))
	elseif kind == "Staff" then
		add(cylinder(model, "Staff", 6 * s, 0.26 * s, hand + V3(0, 1.2 * s, -0.1 * s), V3(0, 1, 0), Color3.fromRGB(110, 76, 52)))
		add(ball(model, "Orb", 0.9 * s, hand + V3(0, 4.4 * s, -0.1 * s), accent, { material = Enum.Material.Neon, shadow = false }))
		add(cylinder(model, "Ring", 0.2 * s, 1.2 * s, hand + V3(0, 3.9 * s, -0.1 * s), V3(0, 1, 0), gold, { material = Enum.Material.Metal }))
	elseif kind == "Spear" or kind == "Trident" then
		local dir = V3(0, 0.55, -1).Unit
		local tip = hand + dir * 5.2 * s
		add(beam(model, "Shaft", hand - dir * 1.8 * s, tip, 0.22 * s, 0.22 * s, kind == "Trident" and gold or Color3.fromRGB(110, 76, 52), { material = kind == "Trident" and Enum.Material.Metal or SMOOTH }))
		if kind == "Trident" then
			for _, x in ipairs({ -0.45, 0, 0.45 }) do
				add(spike(model, "Prong", tip + V3(x * s, 0, 0), dir, 1.3 * s, 0.22 * s, 0.22 * s, gold, { material = Enum.Material.Metal }))
			end
			add(beam(model, "Bar", tip + V3(-0.5 * s, 0, 0), tip + V3(0.5 * s, 0, 0), 0.2 * s, 0.2 * s, gold, { material = Enum.Material.Metal }))
		else
			add(spike(model, "Head", tip, dir, 1.3 * s, 0.5 * s, 0.2 * s, steel, { material = Enum.Material.Metal }))
			add(ball(model, "Tassel", 0.4 * s, tip - dir * 0.2 * s, accent))
		end
	elseif kind == "Scythe" then
		local top = hand + V3(0, 4.2 * s, 0)
		add(cylinder(model, "Shaft", 6.4 * s, 0.24 * s, hand + V3(0, 1.0 * s, 0), V3(0, 1, 0), Color3.fromRGB(40, 30, 40)))
		local prev = top
		for i = 1, 4 do
			local a = i * 0.32
			local p = top + V3(0, -math.sin(a) * 1.1 * s, -math.sin(a * 1.2) * 1.0 * s - i * 0.75 * s)
			add(beam(model, "Blade", prev, p, 0.1 * s, 0.6 * s - i * 0.1 * s, steel, { material = Enum.Material.Metal }))
			prev = p
		end
		add(ball(model, "Gem", 0.5 * s, top, accent, { material = Enum.Material.Neon, shadow = false }))
	elseif kind == "Fists" then
		for _, side in ipairs({ -1, 1 }) do
			local a = rig.arms[side]
			weld(a.part, ball(model, "Glove", rig.armSize.X * 1.45, a.hand, accent))
		end
	end
end

local function aura(model, rig, color, strong)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = strong and 14 or 7
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = V3(0, 4, 0)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * rig.s), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = rig.torso
	if strong then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10 * rig.s
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = rig.torso
	end
end

local function finish(model)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	return model
end

---------------------------------------------------------------------------------------------------
-- Public builders
---------------------------------------------------------------------------------------------------

local HUMAN = {
	torso = V3(2, 2, 1.1),
	head = 2.3,
	arm = V3(0.75, 1.95, 0.75),
	leg = V3(0.85, 2.3, 0.9),
	legGap = 0.5,
}

function Rig.BuildFighter(def, scale)
	scale = scale or 1
	local look = def.Look
	local model = Instance.new("Model")
	model.Name = def.Name
	local rig = skeleton(model, scale, HUMAN, {
		torso = look.top,
		skin = look.skin,
		arm = look.skin,
		hand = look.skin,
		leg = look.bottom,
		shoe = Color3.fromRGB(36, 30, 34),
	})
	face(model, rig, look.eyes or BLACK, false, false)
	outfit(model, rig, look)
	hair(model, rig, look.hairStyle, look.hair)
	accessories(model, rig, look)
	weapon(model, rig, look)
	local rank = Rarities.Rank(def.Rarity)
	if look.aura and rank >= 3 then
		aura(model, rig, look.aura, rank >= 5)
	end
	model:SetAttribute("Rig", "Humanoid")
	model:SetAttribute("Weapon", look.weapon or "Fists")
	return finish(model)
end

local ENEMY_PROPORTIONS = {
	Pirate = { torso = V3(2.2, 2.1, 1.3), head = 2.1, arm = V3(0.85, 2.0, 0.85), leg = V3(0.95, 2.2, 0.95), legGap = 0.55 },
	Brute = { torso = V3(3.2, 2.5, 1.8), head = 1.9, arm = V3(1.25, 2.6, 1.25), leg = V3(1.2, 2.0, 1.2), legGap = 0.8 },
	Golem = { torso = V3(3.4, 2.8, 2.2), head = 1.8, arm = V3(1.4, 2.8, 1.4), leg = V3(1.3, 2.0, 1.3), legGap = 0.85 },
	Beast = { torso = V3(2.4, 1.9, 1.6), head = 2.4, arm = V3(0.9, 1.8, 0.9), leg = V3(1.0, 1.7, 1.0), legGap = 0.6 },
	Specter = { torso = V3(2.4, 2.4, 1.4), head = 2.2, arm = V3(0.8, 2.1, 0.8), leg = V3(0.9, 2.0, 0.9), legGap = 0.5 },
}

local function buildSlime(model, def, s)
	local d = 4.2 * s
	local root = part(model, "Root", V3(2, 2, 1) * s, CF(0, d / 2, 0), WHITE, { transparency = 1, shadow = false })
	root.Massless = false
	model.PrimaryPart = root
	model:SetAttribute("HipHeight", d / 2)
	local body = ball(model, "Torso", d, V3(0, d / 2, 0), def.Color, { material = Enum.Material.SmoothPlastic })
	motor("RootJoint", root, body, CF(), CF())
	weld(body, ball(model, "Shine", d * 0.28, V3(-d * 0.22, d * 0.78, -d * 0.2), WHITE, { material = Enum.Material.Neon, transparency = 0.35, shadow = false }))
	weld(body, part(model, "Base", V3(d * 0.9, d * 0.18, d * 0.9), CF(0, d * 0.09, 0), def.Accent))
	local rig = { s = s, head = body, headCenter = V3(0, d / 2, 0), headR = d / 2, torso = body }
	face(model, rig, def.Accent, true, false)
	if def.Boss then
		weld(body, cylinder(model, "Crown", 0.5 * s, d * 0.45, V3(0, d * 0.98, 0), V3(0, 1, 0), Color3.fromRGB(255, 205, 70), { material = Enum.Material.Metal }))
	end
	model:SetAttribute("Rig", "Slime")
	return rig
end

function Rig.BuildEnemy(def)
	local s = def.Scale or 1
	local model = Instance.new("Model")
	model.Name = def.Name
	if def.Body == "Slime" then
		buildSlime(model, def, s)
		return finish(model)
	end

	local prop = ENEMY_PROPORTIONS[def.Body] or ENEMY_PROPORTIONS.Pirate
	local skin = def.Color
	local accent = def.Accent
	local isGolem = def.Body == "Golem"
	local rig = skeleton(model, s, prop, {
		torso = def.Body == "Pirate" and accent or skin,
		skin = skin,
		arm = skin,
		hand = skin,
		leg = (def.Body == "Pirate" or def.Body == "Brute") and Color3.fromRGB(50, 44, 52) or skin,
		shoe = Color3.fromRGB(30, 26, 30),
	})
	if isGolem then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "Root" then
				p.Material = Enum.Material.Slate
			end
		end
	end
	face(model, rig, (isGolem or def.Body == "Specter") and accent or Color3.fromRGB(200, 40, 40), true, isGolem or def.Body == "Specter")

	local r = rig.headR
	local hc = rig.headCenter
	if def.Body == "Pirate" then
		weld(rig.head, cylinder(model, "Bandana", 0.42 * r, 2.18 * r, hc + V3(0, 0.45 * r, 0.02 * r), V3(0, 1, 0), accent))
		weld(rig.head, part(model, "EyePatch", V3(0.5 * r, 0.5 * r, 0.2 * r), CF(hc + V3(0.38 * r, 0.02 * r, -0.98 * r)), BLACK))
		outfit(model, rig, { outfit = "Coat", top = accent, accent = Color3.fromRGB(255, 205, 70), skin = skin, bottom = skin })
		weapon(model, rig, { weapon = "Sword", accent = Color3.fromRGB(255, 120, 60) })
		if def.Boss then
			accessories(model, rig, { acc = { "Captain", "Cape" }, accent = Color3.fromRGB(150, 20, 30), top = accent })
		end
	elseif def.Body == "Brute" then
		for _, side in ipairs({ -1, 1 }) do
			weld(rig.head, spike(model, "Horn", hc + V3(side * 0.6 * r, 0.6 * r, 0), V3(side * 0.7, 1, -0.2), 1.3 * r, 0.4 * r, 0.4 * r, Color3.fromRGB(250, 240, 220)))
			weld(rig.arms[side].part, part(model, "Bracer", rig.armSize * V3(1.2, 0.35, 1.2), CF(rig.arms[side].hand + V3(0, 0.6 * s, 0)), accent, { material = Enum.Material.Metal }))
		end
		weld(rig.torso, part(model, "Strap", V3(0.5 * s, rig.torsoSize.Y * 1.3, rig.torsoSize.Z * 1.05), rig.torso.CFrame * CFrame.Angles(0, 0, math.rad(35)), accent))
		if def.Boss then
			accessories(model, rig, { acc = { "Crown", "Cape" }, accent = accent, top = accent })
		end
	elseif isGolem then
		for i = 1, 6 do
			local a = i * 1.7
			local p = rig.torso.Position + V3(math.cos(a) * rig.torsoSize.X * 0.45, (i % 3 - 1) * 0.7 * s, math.sin(a) * rig.torsoSize.Z * 0.45)
			weld(rig.torso, part(model, "Chunk", V3(1, 0.8, 0.9) * s * (0.8 + (i % 3) * 0.25), CF(p) * CFrame.Angles(a, a * 0.6, a * 0.3), skin:Lerp(BLACK, 0.15), { material = Enum.Material.Slate }))
		end
		weld(rig.torso, ball(model, "Core", 0.9 * s, rig.torso.Position + V3(0, 0.2 * s, -rig.torsoSize.Z / 2), accent, { material = Enum.Material.Neon, shadow = false }))
		if def.Boss then
			accessories(model, rig, { acc = { "Crown" }, accent = accent })
		end
	elseif def.Body == "Beast" then
		for _, side in ipairs({ -1, 1 }) do
			weld(rig.head, spike(model, "Ear", hc + V3(side * 0.6 * r, 0.7 * r, 0.1 * r), V3(side * 0.35, 1, 0.1), 1.0 * r, 0.6 * r, 0.25 * r, skin))
			weld(rig.head, spike(model, "EarInner", hc + V3(side * 0.6 * r, 0.75 * r, 0.02 * r), V3(side * 0.35, 1, 0.1), 0.75 * r, 0.35 * r, 0.27 * r, accent))
		end
		weld(rig.torso, beam(model, "Tail", rig.torso.Position + V3(0, -0.6 * s, rig.torsoSize.Z / 2), rig.torso.Position + V3(0, 0.6 * s, rig.torsoSize.Z / 2 + 2.2 * s), 0.55 * s, 0.55 * s, accent))
	elseif def.Body == "Specter" then
		for _, side in ipairs({ -1, 1 }) do
			rig.legs[side].Transparency = 1
			for _, child in ipairs(model:GetChildren()) do
				if child.Name == (side < 0 and "LLegShoe" or "RLegShoe") then
					child.Transparency = 1
				end
			end
		end
		local robe = part(model, "Robe", V3(rig.torsoSize.X * 1.2, rig.legSize.Y * 1.1, rig.torsoSize.Z * 1.3), CF(V3(0, rig.hip - rig.legSize.Y * 0.45, 0)), skin, { transparency = 0.1 })
		weld(rig.torso, robe)
		for i = 1, 6 do
			local a = (i / 6) * math.pi * 2
			weld(rig.torso, spike(model, "Tatter", V3(math.cos(a) * rig.torsoSize.X * 0.5, rig.hip - rig.legSize.Y * 0.9, math.sin(a) * rig.torsoSize.Z * 0.55), V3(math.cos(a) * 0.3, -1, math.sin(a) * 0.3), 1.2 * s, 0.8 * s, 0.2 * s, skin))
		end
		weld(rig.head, ball(model, "Hood", r * 2.3, hc + V3(0, 0.15 * r, 0.3 * r), accent:Lerp(BLACK, 0.5)))
		aura(model, rig, accent, true)
	end

	if def.Boss then
		aura(model, rig, accent, true)
	end
	model:SetAttribute("Rig", "Humanoid")
	return finish(model)
end

---------------------------------------------------------------------------------------------------
-- Name tag used by showcase NPCs: Name / Rarity / Lvl.
---------------------------------------------------------------------------------------------------

function Rig.NameTag(model, def, level)
	local info = Rarities.Info[def.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(220, 86)
	gui.StudsOffsetWorldSpace = V3(0, 9.5 * (model:GetAttribute("Scale") or 1), 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Adornee = model.PrimaryPart

	local function label(text, y, h, color, font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, h, 0)
		l.Position = UDim2.new(0, 0, y, 0)
		l.Font = font or Enum.Font.FredokaOne
		l.Text = text
		l.TextScaled = true
		l.TextColor3 = color
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(16, 12, 24)
		stroke.Parent = l
		l.Parent = gui
		return l
	end

	label(def.Name, 0, 0.4, WHITE, Enum.Font.LuckiestGuy)
	local rarity = label(def.Rarity, 0.38, 0.32, info.Color)
	if def.Rarity == "Secret" then
		rarity.TextColor3 = WHITE
		local g = Instance.new("UIGradient")
		g.Color = Rarities.SecretGradient
		g.Parent = rarity
	end
	label("Lvl. " .. tostring(level or 1), 0.68, 0.3, Color3.fromRGB(255, 236, 160))
	gui.Parent = model
	return gui
end

return Rig
