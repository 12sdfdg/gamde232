-- Interactable structures (summon machine, shop, rewards chest, portal) and per-theme landmarks.
local CollectionService = game:GetService("CollectionService")
local Props = require(script.Parent.Props)

local Landmarks = {}

local V3 = Vector3.new
local CF = CFrame.new
local part = Props.Part
local GOLD = Color3.fromRGB(255, 200, 70)
local STONE = Color3.fromRGB(236, 232, 226)
local STONE2 = Color3.fromRGB(206, 200, 196)

local function cylinderY(parent, height, diameter, position, color, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Cylinder
	return part(parent, V3(height, diameter, diameter), CF(position) * CFrame.Angles(0, 0, math.rad(90)), color, opts)
end
Landmarks.CylinderY = cylinderY

local function surfaceText(target, face, text, color, bg)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg or Color3.fromRGB(30, 20, 50)
	label.BackgroundTransparency = bg and 0 or 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 12, 30)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = target
	return gui
end
Landmarks.SurfaceText = surfaceText

-- Circular plaza with a summon machine (glowing star on a pedestal with spinning rings).
function Landmarks.Plaza(parent, center, accent, worldId)
	local m = Props.Model(parent, "SummonPlaza")
	cylinderY(m, 1, 76, center + V3(0, -0.3, 0), STONE2)
	cylinderY(m, 1.1, 66, center + V3(0, -0.2, 0), STONE)
	cylinderY(m, 1.2, 46, center + V3(0, -0.15, 0), GOLD, { material = Enum.Material.Metal })
	cylinderY(m, 1.3, 43, center + V3(0, -0.1, 0), STONE)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = center + V3(math.cos(a) * 28, 0.45, math.sin(a) * 28)
		part(m, V3(6, 0.3, 1.2), CF(p) * CFrame.Angles(0, -a, 0), accent, { material = Enum.Material.Neon, collide = false })
	end

	local machine = Props.Model(m, "SummonMachine")
	cylinderY(machine, 3, 20, center + V3(0, 1.5, 0), STONE2)
	cylinderY(machine, 2, 16, center + V3(0, 4, 0), STONE)
	cylinderY(machine, 0.6, 16.6, center + V3(0, 5.2, 0), GOLD, { material = Enum.Material.Metal })
	cylinderY(machine, 6, 6, center + V3(0, 8, 0), STONE)
	cylinderY(machine, 0.8, 8, center + V3(0, 11.2, 0), GOLD, { material = Enum.Material.Metal })

	-- Star
	local starCenter = center + V3(0, 20, 0)
	local star = Props.Model(machine, "Star")
	part(star, V3(4.6, 4.6, 4.6), CF(starCenter), GOLD, { shape = Enum.PartType.Ball, material = Enum.Material.Neon })
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local dir = V3(math.sin(a), math.cos(a), 0)
		local base = starCenter + dir * 1.6
		local tip = starCenter + dir * 7
		local mid = (base + tip) / 2
		part(star, V3(2.2, 1.6, (tip - base).Magnitude), CFrame.lookAt(mid, tip, V3(0, 0, 1)), GOLD, { class = "WedgePart", material = Enum.Material.Neon, collide = false })
		part(star, V3(2.2, 1.6, (tip - base).Magnitude), CFrame.lookAt(mid, tip, V3(0, 0, -1)), GOLD:Lerp(Color3.new(1, 1, 1), 0.2), { class = "WedgePart", material = Enum.Material.Neon, collide = false })
	end
	CollectionService:AddTag(star, "Spin")
	star:SetAttribute("SpinSpeed", 0.8)
	star:SetAttribute("Bob", 1.2)

	-- Rings
	for r = 1, 2 do
		local ring = Props.Model(machine, "Ring" .. r)
		local radius = 7 + r * 2.5
		for i = 0, 17 do
			local a = i / 18 * math.pi * 2
			local a2 = (i + 1) / 18 * math.pi * 2
			local p1 = starCenter + V3(math.cos(a) * radius, 0, math.sin(a) * radius)
			local p2 = starCenter + V3(math.cos(a2) * radius, 0, math.sin(a2) * radius)
			part(ring, V3(0.5, 0.5, (p2 - p1).Magnitude + 0.2), CFrame.lookAt((p1 + p2) / 2, p2), r == 1 and accent or GOLD, { material = Enum.Material.Neon, collide = false, shadow = false })
		end
		ring:PivotTo(ring:GetPivot() * CFrame.Angles(math.rad(r == 1 and 20 or -25), 0, math.rad(r == 1 and 10 or -15)))
		CollectionService:AddTag(ring, "Spin")
		ring:SetAttribute("SpinSpeed", r == 1 and 1.4 or -1.1)
		ring:SetAttribute("Tilted", true)
	end
	local glowPart = part(machine, V3(1, 1, 1), CF(starCenter), GOLD, { transparency = 1, collide = false, name = "Glow" })
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 30
	light.Brightness = 2.5
	light.Parent = glowPart
	Props.Sparkles(glowPart, GOLD, 20, 1)

	machine:SetAttribute("World", worldId)
	machine:SetAttribute("Prompt", "SUMMON")
	machine:SetAttribute("Range", 26)
	CollectionService:AddTag(machine, "SummonMachine")
	CollectionService:AddTag(machine, "Interactable")
	return m
end

function Landmarks.ShopStand(parent, position, facing, accent)
	local m = Props.Model(parent, "ShopStand")
	local base = CFrame.lookAt(position, position + facing)
	local wood = Color3.fromRGB(150, 98, 60)
	part(m, V3(16, 3.4, 5), base * CF(0, 1.7, 0), wood)
	part(m, V3(16.6, 0.6, 5.6), base * CF(0, 3.5, 0), Color3.fromRGB(110, 70, 44))
	for _, x in ipairs({ -7.6, 7.6 }) do
		for _, z in ipairs({ -2.2, 2.2 }) do
			part(m, V3(0.9, 11, 0.9), base * CF(x, 5.5, z), wood)
		end
	end
	-- Striped awning
	for i = 0, 7 do
		local color = i % 2 == 0 and accent or Color3.new(1, 1, 1)
		part(m, V3(2.05, 1.2, 8), base * CF(-7 + i * 2, 11.6, 0.6) * CFrame.Angles(math.rad(-14), 0, 0), color, { class = "WedgePart" })
	end
	local sign = part(m, V3(10, 3, 0.5), base * CF(0, 14, -1.8), Color3.fromRGB(40, 24, 60))
	surfaceText(sign, Enum.NormalId.Front, "SHOP", GOLD)
	part(m, V3(10.8, 3.6, 0.4), base * CF(0, 14, -1.6), GOLD, { material = Enum.Material.Metal })
	-- Coins & gems on the counter
	for i = 1, 7 do
		part(m, V3(1, 1, 1), base * CF(-5 + i * 1.2, 4.3 + (i % 2) * 0.4, -0.5), GOLD, { shape = Enum.PartType.Ball, material = Enum.Material.Metal, collide = false })
	end
	part(m, V3(1.6, 2.4, 1.6), base * CF(4, 5, 0) * CFrame.Angles(0, 0.6, math.rad(45)), Color3.fromRGB(90, 220, 255), { material = Enum.Material.Neon, collide = false })
	m:SetAttribute("Prompt", "SHOP")
	m:SetAttribute("Range", 18)
	m:SetAttribute("Window", "Shop")
	CollectionService:AddTag(m, "Interactable")
	return m
end

function Landmarks.RewardsChest(parent, position, facing)
	local m = Props.Model(parent, "RewardsChest")
	local base = CFrame.lookAt(position, position + facing)
	cylinderY(m, 1.6, 14, position + V3(0, 0.8, 0), STONE2)
	cylinderY(m, 0.4, 14.6, position + V3(0, 1.7, 0), Color3.fromRGB(170, 90, 255), { material = Enum.Material.Neon })
	local purple = Color3.fromRGB(110, 60, 200)
	part(m, V3(9, 5, 6), base * CF(0, 4.3, 0), purple)
	part(m, V3(9.2, 3, 6.2), base * CF(0, 8.3, 0), purple:Lerp(Color3.new(1, 1, 1), 0.1))
	for _, x in ipairs({ -3.8, 0, 3.8 }) do
		part(m, V3(0.8, 8.4, 6.4), base * CF(x, 5.8, 0), GOLD, { material = Enum.Material.Metal })
	end
	part(m, V3(2, 2.2, 0.6), base * CF(0, 6.6, -3.2), GOLD, { material = Enum.Material.Metal })
	local glow = part(m, V3(8, 0.5, 5.6), base * CF(0, 6.8, 0), Color3.fromRGB(255, 230, 120), { material = Enum.Material.Neon, collide = false })
	Props.Sparkles(glow, Color3.fromRGB(255, 220, 120), 14, 0.8)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 140, 255)
	light.Range = 20
	light.Brightness = 1.8
	light.Parent = glow
	m:SetAttribute("Prompt", "REWARDS")
	m:SetAttribute("Range", 18)
	m:SetAttribute("Window", "Rewards")
	CollectionService:AddTag(m, "Interactable")
	return m
end

function Landmarks.Portal(parent, position, facing, accent)
	local m = Props.Model(parent, "WorldPortal")
	local base = CFrame.lookAt(position, position + facing)
	cylinderY(m, 1.2, 22, position + V3(0, 0.6, 0), STONE2)
	local radius = 9
	local center = base * CF(0, radius + 1.5, 0)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local a2 = (i + 1) / 16 * math.pi * 2
		local p1 = (center * CF(math.cos(a) * radius, math.sin(a) * radius, 0)).Position
		local p2 = (center * CF(math.cos(a2) * radius, math.sin(a2) * radius, 0)).Position
		part(m, V3(2.4, 2.4, (p2 - p1).Magnitude + 0.6), CFrame.lookAt((p1 + p2) / 2, p2), i % 2 == 0 and STONE or STONE2)
		if i % 4 == 0 then
			part(m, V3(1.2, 1.2, 1.2), CF(p1) * (center - center.Position), accent, { material = Enum.Material.Neon, collide = false })
		end
	end
	local disc = part(m, V3(0.4, radius * 2 - 1, radius * 2 - 1), center * CFrame.Angles(0, math.rad(90), 0), accent, { shape = Enum.PartType.Cylinder, material = Enum.Material.Neon, transparency = 0.35, collide = false })
	Props.Sparkles(disc, accent, 25, 1)
	local sign = part(m, V3(12, 2.6, 0.5), base * CF(0, radius * 2 + 4.6, 0), Color3.fromRGB(30, 20, 50))
	surfaceText(sign, Enum.NormalId.Front, "WORLDS", accent)
	surfaceText(sign, Enum.NormalId.Back, "WORLDS", accent)
	m:SetAttribute("Prompt", "WORLDS")
	m:SetAttribute("Range", 20)
	m:SetAttribute("Window", "Worlds")
	CollectionService:AddTag(m, "Interactable")
	return m
end

-- Ring of tall rocks and torches marking the boss arena.
function Landmarks.BossArena(parent, center, radius, palette, groundAt)
	local m = Props.Model(parent, "BossArena")
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		if i ~= 6 and i ~= 7 then -- opening facing the passage
			local p = center + V3(math.cos(a) * radius, 0, math.sin(a) * radius)
			local y = groundAt(p.X, p.Z) or center.Y
			Props.Cliff(m, V3(p.X, y - 2, p.Z), 26 + (i % 3) * 8, 11, palette.Rock, palette.RockShade)
			if i % 2 == 0 then
				local torch = part(m, V3(1, 6, 1), CF(p + V3(0, y + 3, 0) - V3(0, p.Y, 0)) * CF((center - p).Unit * 6), Color3.fromRGB(60, 40, 30))
				local fire = Instance.new("Fire")
				fire.Size = 4
				fire.Heat = 6
				fire.Color = Color3.fromRGB(255, 120, 40)
				fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
				fire.Parent = torch
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 150, 60)
				light.Range = 18
				light.Parent = torch
				fire.Enabled = true
				torch.CFrame = torch.CFrame + V3(0, 3, 0)
			end
		end
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Theme landmarks
---------------------------------------------------------------------------------------------------

function Landmarks.Pyramid(parent, position, size)
	local m = Props.Model(parent, "Pyramid")
	local layers = 9
	for i = 0, layers - 1 do
		local w = size * (1 - i / layers)
		local h = size * 0.62 / layers
		part(m, V3(w, h, w), CF(position + V3(0, h * (i + 0.5), 0)), i % 2 == 0 and Color3.fromRGB(236, 196, 128) or Color3.fromRGB(222, 178, 110))
	end
	local top = position + V3(0, size * 0.62, 0)
	part(m, V3(size * 0.12, size * 0.1, size * 0.12), CF(top + V3(0, size * 0.05, 0)), GOLD, { material = Enum.Material.Neon })
	part(m, V3(size * 0.16, size * 0.22, 1), CF(position + V3(0, size * 0.11, -size / 2 - 0.3)), Color3.fromRGB(40, 26, 20))
	return m
end

function Landmarks.Obelisk(parent, position, height)
	local m = Props.Model(parent, "Obelisk")
	part(m, V3(height * 0.16, height, height * 0.16), CF(position + V3(0, height / 2, 0)), Color3.fromRGB(230, 200, 140))
	part(m, V3(height * 0.16, height * 0.14, height * 0.16), CF(position + V3(0, height + height * 0.05, 0)) * CFrame.Angles(0, 0, math.rad(45)), GOLD, { class = "WedgePart", material = Enum.Material.Metal })
	part(m, V3(height * 0.05, height * 0.6, 0.3), CF(position + V3(0, height * 0.5, -height * 0.08 - 0.1)), Color3.fromRGB(60, 140, 200), { material = Enum.Material.Neon })
	return m
end

function Landmarks.IceCastle(parent, position)
	local m = Props.Model(parent, "IceCastle")
	local ice = Color3.fromRGB(190, 230, 255)
	local deep = Color3.fromRGB(120, 180, 240)
	part(m, V3(60, 30, 40), CF(position + V3(0, 15, 0)), ice, { material = Enum.Material.Glass, transparency = 0.15 })
	for _, offset in ipairs({ V3(-30, 0, -20), V3(30, 0, -20), V3(-30, 0, 20), V3(30, 0, 20), V3(0, 0, 0) }) do
		local h = offset.Magnitude < 1 and 70 or 46
		cylinderY(m, h, offset.Magnitude < 1 and 18 or 12, position + offset + V3(0, h / 2, 0), offset.Magnitude < 1 and deep or ice, { material = Enum.Material.Glass, transparency = 0.1 })
		for k = 0, 3 do
			part(m, V3(6, 14, 6), CF(position + offset + V3(0, h + 6, 0)) * CFrame.Angles(0, k * math.pi / 2, 0) * CF(0, 0, 1.5), Color3.fromRGB(240, 250, 255), { class = "WedgePart" })
		end
	end
	part(m, V3(12, 18, 1), CF(position + V3(0, 9, -20.5)), Color3.fromRGB(80, 160, 230), { material = Enum.Material.Neon, transparency = 0.2 })
	return m
end

function Landmarks.Tower(parent, position, width, height, color, neon)
	local m = Props.Model(parent, "Tower")
	part(m, V3(width, height, width), CF(position + V3(0, height / 2, 0)), color)
	local rows = math.floor(height / 8)
	for r = 1, rows - 1 do
		for _, side in ipairs({ 0, 1, 2, 3 }) do
			if (r + side) % 3 ~= 0 then
				local cf = CF(position + V3(0, r * 8, 0)) * CFrame.Angles(0, side * math.pi / 2, 0) * CF(0, 0, -width / 2 - 0.1)
				part(m, V3(width * 0.8, 1.2, 0.3), cf, neon, { material = Enum.Material.Neon, collide = false, shadow = false })
			end
		end
	end
	part(m, V3(width * 1.1, 1.5, width * 1.1), CF(position + V3(0, height + 0.75, 0)), neon, { material = Enum.Material.Neon })
	part(m, V3(1, height * 0.25, 1), CF(position + V3(0, height + height * 0.125, 0)), color)
	return m
end

function Landmarks.Temple(parent, position, accent)
	local m = Props.Model(parent, "Temple")
	cylinderY(m, 4, 70, position + V3(0, 2, 0), Color3.fromRGB(250, 248, 255))
	cylinderY(m, 1, 72, position + V3(0, 4.3, 0), GOLD, { material = Enum.Material.Metal })
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = position + V3(math.cos(a) * 30, 0, math.sin(a) * 30)
		cylinderY(m, 34, 4.5, p + V3(0, 21, 0), Color3.fromRGB(255, 255, 255))
		cylinderY(m, 1.4, 6, p + V3(0, 38.5, 0), GOLD, { material = Enum.Material.Metal })
	end
	cylinderY(m, 3, 72, position + V3(0, 40.5, 0), Color3.fromRGB(250, 246, 255))
	part(m, V3(40, 40, 40), CF(position + V3(0, 42, 0)), GOLD, { shape = Enum.PartType.Ball, material = Enum.Material.Metal })
	local orb = part(m, V3(10, 10, 10), CF(position + V3(0, 72, 0)), accent, { shape = Enum.PartType.Ball, material = Enum.Material.Neon })
	CollectionService:AddTag(orb, "Bob")
	Props.Sparkles(orb, accent, 20, 2)
	return m
end

return Landmarks
