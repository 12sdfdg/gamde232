-- Anime-style sky pirate ship: curved plank hull, gold trims, dark navy billowed sails, masts, ropes,
-- stern castle with glowing windows, figurehead, cannons and a magic levitation ring.
-- Local space: deck at Y=0, bow towards -Z, length along Z.
local Props = require(script.Parent.Props)

local Ship = {}

local V3 = Vector3.new
local CF = CFrame.new

local WOOD_DARK = Color3.fromRGB(78, 48, 36)
local WOOD = Color3.fromRGB(112, 72, 48)
local WOOD_LIGHT = Color3.fromRGB(176, 128, 86)
local DECK = Color3.fromRGB(196, 150, 104)
local GOLD = Color3.fromRGB(255, 200, 70)
local NAVY = Color3.fromRGB(26, 30, 68)
local NAVY2 = Color3.fromRGB(36, 44, 94)
local SAIL_TRIM = Color3.fromRGB(240, 196, 90)
local MAGIC = Color3.fromRGB(90, 230, 255)

local LENGTH = 112
local HALF_WIDTH = 17
local SEGMENTS = 14
local ROWS = 6
local ROW_STEP = 2.5

local function widthAt(t)
	-- t: 0 = bow, 1 = stern
	if t < 0.38 then
		return math.sin((t / 0.38) * math.pi / 2) ^ 0.85
	elseif t < 0.86 then
		return 1
	end
	return 1 - ((t - 0.86) / 0.14) * 0.22
end

local function rowScale(k)
	return 1 - (k / ROWS) ^ 1.7 * 0.82
end

function Ship.Build(parent, origin)
	local m = Instance.new("Model")
	m.Name = "SkyShip"
	m.Parent = parent

	local function p(size, localCF, color, opts)
		return Props.Part(m, size, origin * localCF, color, opts)
	end
	local function plank(a, b, width, height, color, tilt, opts)
		local center = (a + b) / 2
		local cf = CFrame.lookAt(center, b) * CFrame.Angles(0, 0, tilt or 0)
		return Props.Part(m, V3(width, height, (b - a).Magnitude + 0.7), origin * cf, color, opts)
	end

	-- Hull ---------------------------------------------------------------------------------------
	local zAt = function(i)
		return -LENGTH / 2 + (i / SEGMENTS) * LENGTH
	end
	for k = 0, ROWS - 1 do
		local y = -k * ROW_STEP - 1.2
		local scale = rowScale(k)
		local nextScale = rowScale(k + 1)
		local color = (k == 1) and NAVY or ((k % 2 == 0) and WOOD or WOOD_DARK)
		for i = 0, SEGMENTS - 1 do
			local t0, t1 = i / SEGMENTS, (i + 1) / SEGMENTS
			for _, side in ipairs({ -1, 1 }) do
				local a = V3(side * HALF_WIDTH * widthAt(t0) * scale, y, zAt(i))
				local b = V3(side * HALF_WIDTH * widthAt(t1) * scale, y, zAt(i + 1))
				local dx = HALF_WIDTH * (scale - nextScale) * (widthAt(t0) + widthAt(t1)) / 2
				local tilt = side * math.atan2(dx, ROW_STEP)
				plank(a, b, 1.1, ROW_STEP + 0.35, color, tilt)
			end
		end
	end
	-- Gold trim line along the hull.
	for i = 0, SEGMENTS - 1 do
		for _, side in ipairs({ -1, 1 }) do
			local a = V3(side * (HALF_WIDTH * widthAt(i / SEGMENTS) + 0.55), -0.1, zAt(i))
			local b = V3(side * (HALF_WIDTH * widthAt((i + 1) / SEGMENTS) + 0.55), -0.1, zAt(i + 1))
			plank(a, b, 0.4, 0.55, GOLD, 0, { material = Enum.Material.Metal })
			-- Bulwark + rail cap
			local ra = V3(side * HALF_WIDTH * widthAt(i / SEGMENTS) * 0.97, 1.3, zAt(i))
			local rb = V3(side * HALF_WIDTH * widthAt((i + 1) / SEGMENTS) * 0.97, 1.3, zAt(i + 1))
			plank(ra, rb, 0.9, 2.8, WOOD_DARK)
			plank(ra + V3(0, 1.55, 0), rb + V3(0, 1.55, 0), 1.2, 0.4, GOLD, 0, { material = Enum.Material.Metal })
		end
	end
	-- Keel
	p(V3(2.2, 2.4, LENGTH * 0.78), CF(0, -ROWS * ROW_STEP - 0.6, 3), WOOD_DARK)
	p(V3(1.4, 9, 2.2), CF(0, -ROWS * ROW_STEP + 3, LENGTH / 2 - 2) * CFrame.Angles(math.rad(-8), 0, 0), WOOD_DARK)

	-- Deck -----------------------------------------------------------------------------------------
	for i = 0, SEGMENTS - 1 do
		local w = HALF_WIDTH * math.min(widthAt(i / SEGMENTS), widthAt((i + 1) / SEGMENTS)) * 2 * 0.98
		p(V3(w, 0.8, LENGTH / SEGMENTS + 0.4), CF(0, -0.4, zAt(i) + LENGTH / SEGMENTS / 2), i % 2 == 0 and DECK or DECK:Lerp(WOOD_LIGHT, 0.5))
	end
	for x = -12, 12, 4 do
		p(V3(0.15, 0.1, LENGTH * 0.7), CF(x, 0.02, 6), WOOD_LIGHT:Lerp(WOOD, 0.4), { collide = false, shadow = false })
	end

	-- Stern castle ---------------------------------------------------------------------------------
	local sternZ = LENGTH / 2 - 13
	local castleW = HALF_WIDTH * 1.72
	p(V3(castleW, 7.5, 24), CF(0, 3.75, sternZ), WOOD)
	p(V3(castleW + 1, 0.8, 25), CF(0, 7.9, sternZ), DECK)
	p(V3(castleW + 1.4, 0.5, 25.4), CF(0, 7.4, sternZ), GOLD, { material = Enum.Material.Metal })
	for _, side in ipairs({ -1, 1 }) do
		p(V3(0.8, 2.6, 24), CF(side * castleW / 2, 9.4, sternZ), WOOD_DARK)
		p(V3(1.1, 0.4, 24.2), CF(side * castleW / 2, 10.8, sternZ), GOLD, { material = Enum.Material.Metal })
		-- side windows
		for w = -1, 1 do
			p(V3(0.3, 2.4, 2.6), CF(side * (castleW / 2 + 0.2), 4.2, sternZ + w * 6), Color3.fromRGB(255, 210, 120), { material = Enum.Material.Neon, collide = false })
			p(V3(0.5, 3.0, 3.2), CF(side * (castleW / 2 + 0.05), 4.2, sternZ + w * 6), GOLD, { material = Enum.Material.Metal })
		end
	end
	p(V3(castleW, 0.8, 0.8), CF(0, 9.4, sternZ - 12), WOOD_DARK)
	-- Stern windows on the back face
	for x = -2, 2 do
		local window = p(V3(3, 3.2, 0.3), CF(x * 5.5, 3.8, sternZ + 12.2), Color3.fromRGB(255, 214, 130), { material = Enum.Material.Neon, collide = false })
		if x == 0 then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 190, 110)
			light.Range = 22
			light.Brightness = 1.5
			light.Parent = window
		end
		p(V3(3.8, 4, 0.4), CF(x * 5.5, 3.8, sternZ + 12.1), GOLD, { material = Enum.Material.Metal })
	end
	-- Cabin door + steps
	p(V3(4, 6, 0.4), CF(0, 3, sternZ - 12.1), WOOD_DARK)
	p(V3(4.6, 0.5, 0.6), CF(0, 6.2, sternZ - 12.1), GOLD, { material = Enum.Material.Metal })
	for s = 0, 3 do
		p(V3(5, 1, 2), CF(9, 0.5 + s * 1.9, sternZ - 13 - (3 - s) * 1.6), WOOD_LIGHT)
	end
	-- Ship wheel
	local wheelCenter = V3(0, 11.2, sternZ - 6)
	p(V3(1, 2.4, 1), CF(0, 9.4, sternZ - 6), WOOD_DARK)
	for i = 0, 7 do
		local a = i * math.pi / 4
		p(V3(0.3, 3.4, 0.3), CF(wheelCenter) * CFrame.Angles(0, 0, a), WOOD_LIGHT, { collide = false })
	end
	p(V3(0.6, 1.2, 1.2), CF(wheelCenter), GOLD, { shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, collide = false })

	-- Forecastle
	local foreZ = -LENGTH / 2 + 20
	p(V3(HALF_WIDTH * 1.3, 4, 14), CF(0, 2, foreZ), WOOD)
	p(V3(HALF_WIDTH * 1.32, 0.6, 14.4), CF(0, 4.2, foreZ), DECK)

	-- Bowsprit + figurehead ------------------------------------------------------------------------
	local bowTip = V3(0, 0, -LENGTH / 2 - 2)
	local spritEnd = bowTip + V3(0, 14, -30)
	plank(bowTip + V3(0, 2, 2), spritEnd, 1.8, 1.8, WOOD_DARK)
	plank(spritEnd - V3(0, 0, -2), spritEnd + V3(0, -0.6, -6), 1, 1, GOLD, 0, { material = Enum.Material.Metal })
	-- Figurehead: golden winged beast
	local fh = V3(0, -3, -LENGTH / 2 - 4)
	p(V3(3.2, 3.2, 6), CF(fh) * CFrame.Angles(math.rad(-20), 0, 0), GOLD, { material = Enum.Material.Metal })
	p(V3(2.4, 2.4, 3.2), CF(fh + V3(0, 1.8, -3.4)) * CFrame.Angles(math.rad(-10), 0, 0), GOLD, { class = "WedgePart", material = Enum.Material.Metal })
	for _, side in ipairs({ -1, 1 }) do
		p(V3(0.5, 0.5, 0.3), CF(fh + V3(side * 0.7, 2.4, -4.6)), MAGIC, { material = Enum.Material.Neon, collide = false })
		for w = 0, 2 do
			local base = fh + V3(side * 1.4, 0.6 + w * 0.4, 0.8 + w * 1.2)
			local tip = base + V3(side * (5 - w), 2.6 - w * 0.4, 2.5)
			plank(base, tip, 0.5, 1.6 - w * 0.3, GOLD, side * 0.6, { material = Enum.Material.Metal })
		end
	end

	-- Masts, yards and sails ---------------------------------------------------------------------
	local masts = {
		{ z = -26, height = 64, yards = { 18, 34, 50 }, widths = { 30, 26, 18 } },
		{ z = 2, height = 84, yards = { 20, 40, 60, 74 }, widths = { 36, 32, 26, 16 } },
		{ z = 28, height = 58, yards = { 22, 36, 48 }, widths = { 26, 22, 14 } },
	}
	local mastTops = {}
	for mi, mast in ipairs(masts) do
		local base = mast.z
		p(V3(mast.height, 2.6, 2.6), CF(0, mast.height / 2, base) * CFrame.Angles(0, 0, math.rad(90)), WOOD_DARK, { shape = Enum.PartType.Cylinder })
		for ring = 1, 3 do
			p(V3(0.5, 3.0, 3.0), CF(0, mast.height * ring / 4, base) * CFrame.Angles(0, 0, math.rad(90)), GOLD, { shape = Enum.PartType.Cylinder, material = Enum.Material.Metal })
		end
		-- crow's nest
		local nestY = mast.height - 9
		p(V3(1.4, 7, 7), CF(0, nestY, base) * CFrame.Angles(0, 0, math.rad(90)), WOOD, { shape = Enum.PartType.Cylinder })
		p(V3(2.2, 7.4, 7.4), CF(0, nestY + 1.6, base) * CFrame.Angles(0, 0, math.rad(90)), WOOD_DARK, { shape = Enum.PartType.Cylinder, collide = false })
		mastTops[mi] = V3(0, mast.height, base)

		for yi, yardY in ipairs(mast.yards) do
			local w = mast.widths[yi]
			p(V3(w, 1.1, 1.1), CF(0, yardY, base - 1.4), WOOD_DARK, { shape = Enum.PartType.Cylinder })
			local nextY = mast.yards[yi + 1] or (yardY + 10)
			if yi < #mast.yards then
				-- Billowed sail between this yard and the next one.
				local top = nextY - 1
				local bottom = yardY + 0.6
				local sailWidth = (mast.widths[yi + 1] + w) / 2 * 0.92
				local strips = 6
				for s = 0, strips - 1 do
					local u = (s + 0.5) / strips
					local x = (u - 0.5) * sailWidth
					local bulge = math.sin(u * math.pi) * 3.2
					local color = (s % 2 == 0) and NAVY or NAVY2
					p(V3(sailWidth / strips + 0.25, top - bottom, 0.4), CF(x, (top + bottom) / 2, base - 2.6 - bulge) * CFrame.Angles(math.rad(4), 0, 0), color, { material = Enum.Material.Fabric, collide = false })
				end
				p(V3(sailWidth, 0.5, 0.5), CF(0, bottom + 0.2, base - 2.9), SAIL_TRIM, { collide = false })
				if mi == 2 and yi == 2 then
					-- Emblem on the main sail.
					local center = CF(0, (top + bottom) / 2, base - 6.3)
					p(V3(0.3, 9, 9), center * CFrame.Angles(0, math.rad(90), 0), SAIL_TRIM, { shape = Enum.PartType.Cylinder, material = Enum.Material.Neon, collide = false })
					p(V3(0.35, 7.4, 7.4), center * CF(0, 0, -0.05) * CFrame.Angles(0, math.rad(90), 0), NAVY, { shape = Enum.PartType.Cylinder, collide = false })
					for a = 0, 3 do
						p(V3(1.2, 6.5, 0.4), center * CF(0, 0, -0.2) * CFrame.Angles(0, 0, a * math.pi / 2 + math.pi / 4) * CF(0, 2.2, 0), SAIL_TRIM, { class = "WedgePart", material = Enum.Material.Neon, collide = false })
					end
				end
			end
		end
		-- Flag
		p(V3(0.4, 6, 1), CF(0, mast.height + 3, base), WOOD_DARK)
		p(V3(0.3, 3.4, 6), CF(0, mast.height + 4.2, base + 3.2), mi == 2 and Color3.fromRGB(200, 30, 50) or NAVY, { material = Enum.Material.Fabric, collide = false })
	end

	-- Rigging ropes ---------------------------------------------------------------------------------
	local ropeAnchor = Props.Part(m, V3(1, 1, 1), origin, WOOD, { transparency = 1, collide = false, name = "RopeAnchor" })
	local function anchorAttachment(position)
		local a = Instance.new("Attachment")
		a.Parent = ropeAnchor
		a.WorldPosition = (origin * CF(position)).Position
		return a
	end
	local function rope(a, b, thickness)
		local att0 = anchorAttachment(a)
		local att1 = anchorAttachment(b)
		local r = Instance.new("RopeConstraint")
		r.Attachment0 = att0
		r.Attachment1 = att1
		r.Length = (a - b).Magnitude
		r.Visible = true
		r.Thickness = thickness or 0.22
		r.Color = BrickColor.new("Dark taupe")
		r.Parent = ropeAnchor
	end
	for mi, top in ipairs(mastTops) do
		local z = masts[mi].z
		for _, side in ipairs({ -1, 1 }) do
			for k = -1, 1 do
				rope(top - V3(0, 10, 0), V3(side * HALF_WIDTH * 0.95, 2.8, z + k * 5))
			end
		end
	end
	rope(mastTops[1], spritEnd)
	rope(mastTops[1], mastTops[2] - V3(0, 6, 0))
	rope(mastTops[2], mastTops[3] - V3(0, 4, 0))
	rope(mastTops[3], V3(0, 10.5, LENGTH / 2 - 2))

	-- Cannons ----------------------------------------------------------------------------------------
	for _, side in ipairs({ -1, 1 }) do
		for c = -2, 1 do
			local z = c * 14 + 4
			local x = side * HALF_WIDTH * widthAt((z + LENGTH / 2) / LENGTH)
			p(V3(0.4, 2.8, 2.8), CF(x + side * 0.4, -3.4, z), Color3.fromRGB(20, 18, 24))
			p(V3(4, 1.4, 1.4), CF(x + side * 1.4, -3.4, z) * CFrame.Angles(0, 0, 0), Color3.fromRGB(36, 36, 44), { shape = Enum.PartType.Cylinder, material = Enum.Material.Metal })
		end
	end

	-- Lanterns ---------------------------------------------------------------------------------------
	for _, pos in ipairs({ V3(-castleW / 2, 12.5, sternZ + 11), V3(castleW / 2, 12.5, sternZ + 11), V3(-HALF_WIDTH + 1, 4.5, -18), V3(HALF_WIDTH - 1, 4.5, 14) }) do
		p(V3(0.4, 2, 0.4), CF(pos + V3(0, 1.4, 0)), WOOD_DARK)
		local lantern = p(V3(1.2, 1.5, 1.2), CF(pos), Color3.fromRGB(255, 200, 110), { material = Enum.Material.Neon, collide = false })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 110)
		light.Range = 16
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = lantern
	end

	-- Barrels & crates on deck
	for _, pos in ipairs({ V3(-11, 0, -8), V3(-12, 0, -4), V3(11, 0, 18), V3(10, 0, -34), V3(-9, 0, 20) }) do
		p(V3(3.2, 2.6, 2.6), CF(pos + V3(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), WOOD_LIGHT, { shape = Enum.PartType.Cylinder })
		p(V3(3.3, 2.7, 2.7), CF(pos + V3(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), WOOD_DARK, { shape = Enum.PartType.Cylinder, transparency = 0.6, collide = false })
	end
	p(V3(4, 4, 4), CF(12, 2, -14) * CFrame.Angles(0, 0.3, 0), WOOD)
	p(V3(3, 3, 3), CF(12, 5.5, -14) * CFrame.Angles(0, 0.8, 0), WOOD_LIGHT)

	-- Magic levitation ring + particles ------------------------------------------------------------
	local ringCenter = V3(0, -ROWS * ROW_STEP - 6, 4)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local a2 = (i + 1) / 24 * math.pi * 2
		local r = 30
		plank(ringCenter + V3(math.cos(a) * r, 0, math.sin(a) * r), ringCenter + V3(math.cos(a2) * r, 0, math.sin(a2) * r), 1.2, 0.5, MAGIC, 0, { material = Enum.Material.Neon, collide = false, transparency = 0.15, shadow = false })
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Props.Crystal(m, (origin * CF(ringCenter + V3(math.cos(a) * 14, 1, math.sin(a) * 24))).Position, 6, MAGIC, true)
	end
	local emitterPart = p(V3(26, 1, 70), CF(ringCenter + V3(0, 3, 0)), MAGIC, { transparency = 1, collide = false, shadow = false })
	Props.Sparkles(emitterPart, MAGIC, 30, 1.2)
	local glow = Instance.new("PointLight")
	glow.Color = MAGIC
	glow.Range = 40
	glow.Brightness = 2
	glow.Parent = emitterPart

	return m, {
		DeckPoints = {
			origin * CF(-6, 0, -10),
			origin * CF(5, 0, 8),
			origin * CF(0, 8.3, LENGTH / 2 - 10),
			origin * CF(0, 4.6, -LENGTH / 2 + 20),
		},
		Length = LENGTH,
		HalfWidth = HALF_WIDTH,
	}
end

return Ship
