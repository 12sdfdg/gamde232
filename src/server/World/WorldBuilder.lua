-- Builds every floating island at server start: terrain body, roads, cliffs, rock passage, trees,
-- decoration, interactables, showcase NPCs, theme landmarks and enemy spawn points.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Configs = ReplicatedStorage.Configs
local Worlds = require(Configs.Worlds)
local Fighters = require(Configs.Fighters)
local Rarities = require(Configs.Rarities)
local Rig = require(ReplicatedStorage.Modules.Rig)

local Props = require(script.Parent.Props)
local Landmarks = require(script.Parent.Landmarks)
local Ship = require(script.Parent.Ship)

local WorldBuilder = {}

local V3 = Vector3.new
local CF = CFrame.new
local Terrain = workspace.Terrain
local Layout = Worlds.Layout

local folders = {}

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function setupWorkspace()
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	folders.Worlds = folder(workspace, "Worlds")
	folders.NPCs = folder(workspace, "NPCs")
	folders.Showcase = folder(folders.NPCs, "Showcase")
	folders.Followers = folder(folders.NPCs, "Followers")
	folders.Enemies = folder(workspace, "Enemies")
	folders.Interactables = folder(workspace, "Interactables")
	folders.VFX = folder(workspace, "VFX")
	pcall(function()
		Terrain.Decoration = true
	end)
	Terrain.WaterTransparency = 1
end

local function setMaterialColors()
	for _, world in ipairs(Worlds.List) do
		local p = world.Palette
		Terrain:SetMaterialColor(p.Top, p.TopColor)
		Terrain:SetMaterialColor(p.Under, p.UnderColor)
		Terrain:SetMaterialColor(p.Road, p.RoadColor)
	end
end

-- Ground query (terrain only) -------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Terrain }

local function groundAt(x, z)
	local result = workspace:Raycast(V3(x, 260, z), V3(0, -420, 0), groundParams)
	if result and result.Position.Y > -12 then
		return result.Position.Y
	end
	return nil
end

-- Smooth poly-line (Catmull-Rom) sampled every `step` studs.
local function smoothPath(points, step)
	local out = {}
	for i = 1, #points - 1 do
		local p0 = points[math.max(i - 1, 1)]
		local p1 = points[i]
		local p2 = points[i + 1]
		local p3 = points[math.min(i + 2, #points)]
		local samples = math.max(2, math.floor((p2 - p1).Magnitude / step))
		for s = 0, samples - 1 do
			local t = s / samples
			local t2, t3 = t * t, t * t * t
			local p = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
			table.insert(out, p)
		end
	end
	table.insert(out, points[#points])
	return out
end

---------------------------------------------------------------------------------------------------

local function buildWorld(world)
	local o = world.Origin
	local pal = world.Palette
	local R = Layout.Radius
	local rng = Random.new(world.Id * 7919)
	Props.Seed(world.Id * 104729)

	local root = folder(folders.Worlds, string.format("%d_%s", world.Id, world.Name:gsub("%s", "")))
	local decor = folder(root, "Decor")
	local nature = folder(root, "Nature")
	local structures = folder(root, "Structures")
	local interact = folder(folders.Interactables, "World" .. world.Id)

	-- Reserved areas: nothing big is scattered here.
	local reserved = {}
	local function reserve(p, r)
		table.insert(reserved, { p = V3(p.X, 0, p.Z), r = r })
	end
	local function isFree(p, r)
		local flat = V3(p.X, 0, p.Z)
		for _, area in ipairs(reserved) do
			if (flat - area.p).Magnitude < area.r + r then
				return false
			end
		end
		return true
	end
	reserve(o + Layout.Spawn, 34)
	reserve(o + Layout.Plaza, 46)
	reserve(o + Layout.Shop, 18)
	reserve(o + Layout.Rewards, 18)
	reserve(o + Layout.Portal, 18)
	reserve(o + Layout.Dock, 40)
	reserve(o + Layout.Passage.Center, 26)
	for _, zone in pairs(Layout.Zones) do
		reserve(o + zone.Center, zone.Radius + 10)
	end

	-- Terrain body ---------------------------------------------------------------------------------
	Terrain:FillCylinder(CF(o + V3(0, -7, 0)), 14, R, pal.Top)
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = R * rng:NextNumber(0.3, 0.42)
		Terrain:FillCylinder(CF(o + V3(math.cos(a) * R * 0.8, -7, math.sin(a) * R * 0.8)), 14, r, pal.Top)
	end
	Terrain:FillCylinder(CF(o + Layout.Dock + V3(-20, -7, 0)), 14, 74, pal.Top)
	for k = 1, 9 do
		local rr = R * (1.02 - k * 0.105)
		local jitter = V3(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
		Terrain:FillCylinder(CF(o + jitter + V3(0, -20 - (k - 1) * 11, 0)), 12, rr, pal.Under)
	end
	for _ = 1, 34 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = R * rng:NextNumber(0.45, 0.98)
		Terrain:FillBall(o + V3(math.cos(a) * d, -rng:NextNumber(18, 70), math.sin(a) * d), rng:NextNumber(16, 38), pal.Under)
	end
	-- Hanging stalactite rocks under the island
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = R * rng:NextNumber(0.1, 0.6)
		local top = o + V3(math.cos(a) * d, -100, math.sin(a) * d)
		for s = 0, 3 do
			Terrain:FillBall(top - V3(0, s * 14, 0), 14 - s * 3, pal.Under)
		end
	end

	-- Roads -----------------------------------------------------------------------------------------
	local roadSamples = {}
	for _, line in ipairs(Layout.Roads) do
		local points = {}
		for _, p in ipairs(line) do
			table.insert(points, o + p)
		end
		local samples = smoothPath(points, 4)
		for i = 1, #samples - 1 do
			local a, b = samples[i], samples[i + 1]
			local center = (a + b) / 2
			local look = (b - a).Magnitude > 0.1 and CFrame.lookAt(V3(center.X, -1.8, center.Z), V3(b.X, -1.8, b.Z)) or CF(center.X, -1.8, center.Z)
			Terrain:FillBlock(look, V3(14, 3.6, (b - a).Magnitude + 4), pal.Road)
			if i % 2 == 0 then
				reserve(center, 11)
				table.insert(roadSamples, { p = center, dir = (b - a).Unit })
			end
		end
	end
	-- Dirt arenas under enemy zones and the plaza.
	for _, zone in pairs(Layout.Zones) do
		Terrain:FillCylinder(CF(o + zone.Center + V3(0, -1.8, 0)), 3.6, zone.Radius * 0.85, pal.Road)
	end

	-- Hills (kept away from roads and areas)
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = R * rng:NextNumber(0.25, 0.85)
		local p = o + V3(math.cos(a) * d, 0, math.sin(a) * d)
		local radius = rng:NextNumber(20, 36)
		if isFree(p, radius * 0.7) then
			Terrain:FillBall(p - V3(0, radius * rng:NextNumber(0.55, 0.75), 0), radius, pal.Top)
		end
	end

	local function ground(p)
		return groundAt(p.X, p.Z)
	end

	-- Perimeter cliffs (north/east arcs) leaving the south and the ship side open ------------------
	local arcs = { { 218, 352 }, { 8, 44 } }
	for _, arc in ipairs(arcs) do
		local deg = arc[1]
		while deg < arc[2] do
			local a = math.rad(deg)
			local d = R * rng:NextNumber(0.9, 0.97)
			local p = o + V3(math.cos(a) * d, 0, math.sin(a) * d)
			local y = ground(p) or 0
			local northness = math.clamp(-math.sin(a), 0, 1)
			local height = rng:NextNumber(40, 70) + northness * 55
			Props.Cliff(nature, V3(p.X, y - 4, p.Z), height, rng:NextNumber(26, 40), pal.Rock, pal.RockShade)
			deg += rng:NextNumber(6, 9)
		end
	end

	-- Rock ridge with a passage (cave) to the boss arena --------------------------------------------
	do
		local center = o + Layout.Passage.Center
		local dir = Layout.Passage.Direction.Unit
		local perp = V3(-dir.Z, 0, dir.X)
		for _, sign in ipairs({ -1, 1 }) do
			local offset = 13
			while offset < 120 do
				local p = center + perp * sign * offset
				local y = ground(p) or 0
				Props.Cliff(nature, V3(p.X, y - 3, p.Z), rng:NextNumber(34, 52) + (offset < 20 and 0 or 10), rng:NextNumber(20, 28), pal.Rock, pal.RockShade)
				offset += rng:NextNumber(13, 17)
			end
		end
		local roof = Props.Model(nature, "PassageRoof")
		for i = -1, 1 do
			local p = center + dir * i * 10 + V3(0, 24, 0)
			Props.Rock(roof, p, 26, pal.Rock, pal.RockShade, { pieces = 6 })
		end
		for _, sign in ipairs({ -1, 1 }) do
			for i = -1, 1, 2 do
				local p = center + perp * sign * 8 + dir * i * 9
				Props.Lamp(decor, V3(p.X, (ground(p) or 0), p.Z), Color3.fromRGB(60, 44, 36), Color3.fromRGB(255, 180, 90))
			end
		end
	end

	-- Trees & nature ------------------------------------------------------------------------------
	local function plantTree(p, height)
		local y = ground(p)
		if not y then
			return
		end
		local base = V3(p.X, y, p.Z)
		if world.Theme == "Desert" then
			Props.Palm(nature, base, height * 0.8, pal)
		elseif world.Theme == "Frozen" then
			Props.Pine(nature, base, height, pal)
		elseif world.Theme == "City" then
			Props.Crystal(nature, base, height * 0.35, pal.Leaf2, true)
		else
			Props.Tree(nature, base, height, pal)
		end
	end

	-- Giant silhouette trees near the edge
	for i = 1, 7 do
		local a = math.rad(200 + i * 22 + rng:NextNumber(-6, 6))
		local p = o + V3(math.cos(a), 0, math.sin(a)) * R * rng:NextNumber(0.78, 0.86)
		if isFree(p, 16) then
			plantTree(p, rng:NextNumber(95, 130))
			reserve(p, 20)
		end
	end
	local planted, attempts = 0, 0
	while planted < 42 and attempts < 600 do
		attempts += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local d = R * math.sqrt(rng:NextNumber(0.04, 0.85))
		local p = o + V3(math.cos(a) * d, 0, math.sin(a) * d)
		if isFree(p, 12) then
			plantTree(p, rng:NextNumber(30, 62))
			reserve(p, 10)
			planted += 1
		end
	end
	-- Trees framing the roads
	for i, sample in ipairs(roadSamples) do
		if i % 7 == 0 then
			local side = (i % 14 == 0) and 1 or -1
			local p = sample.p + V3(-sample.dir.Z, 0, sample.dir.X) * side * 24
			if isFree(p, 6) then
				plantTree(p, rng:NextNumber(32, 50))
				reserve(p, 9)
			end
		end
	end

	-- Small decoration (not reserved, but avoid roads/areas)
	local function scatter(count, minRadius, fn)
		local n, tries = 0, 0
		while n < count and tries < count * 8 do
			tries += 1
			local a = rng:NextNumber(0, math.pi * 2)
			local d = R * math.sqrt(rng:NextNumber(0.01, 0.9))
			local p = o + V3(math.cos(a) * d, 0, math.sin(a) * d)
			if isFree(p, minRadius) then
				local y = ground(p)
				if y then
					fn(V3(p.X, y, p.Z))
					n += 1
				end
			end
		end
	end
	scatter(55, 2, function(p)
		Props.Bush(decor, p, rng:NextNumber(3, 6), pal)
	end)
	scatter(60, 1, function(p)
		Props.Flowers(decor, p, pal)
	end)
	scatter(30, 3, function(p)
		Props.Rock(decor, p, rng:NextNumber(3, 9), pal.Rock, pal.RockShade)
	end)
	if world.Theme == "Frozen" or world.Theme == "Celestial" or world.Theme == "City" then
		scatter(18, 3, function(p)
			Props.Crystal(decor, p, rng:NextNumber(5, 12), pal.Accent, world.Theme ~= "Frozen")
		end)
	end
	-- Rocks lining the roads
	for i, sample in ipairs(roadSamples) do
		if i % 5 == 0 then
			local side = (i % 10 == 0) and 1 or -1
			local p = sample.p + V3(-sample.dir.Z, 0, sample.dir.X) * side * 10
			local y = ground(p)
			if y then
				Props.Rock(decor, V3(p.X, y, p.Z), rng:NextNumber(2.5, 4.5), pal.Rock, pal.RockShade)
			end
		end
	end
	-- Lamps along the main road
	for i, sample in ipairs(roadSamples) do
		if i % 9 == 4 then
			local side = (i % 18 == 4) and 1 or -1
			local p = sample.p + V3(-sample.dir.Z, 0, sample.dir.X) * side * 9
			local y = ground(p)
			if y then
				Props.Lamp(decor, V3(p.X, y, p.Z), Color3.fromRGB(50, 40, 44), world.Theme == "City" and pal.Accent or Color3.fromRGB(255, 196, 110))
			end
		end
	end

	-- Fences around enemy zones (with gaps toward roads)
	for name, zone in pairs(Layout.Zones) do
		if name ~= "Boss" then
			local c = o + zone.Center
			for i = 0, 11 do
				if i % 4 ~= 1 then
					local a1 = i / 12 * math.pi * 2
					local a2 = (i + 1) / 12 * math.pi * 2
					local p1 = c + V3(math.cos(a1), 0, math.sin(a1)) * zone.Radius
					local p2 = c + V3(math.cos(a2), 0, math.sin(a2)) * zone.Radius
					local y1, y2 = ground(p1), ground(p2)
					if y1 and y2 then
						Props.Fence(decor, V3(p1.X, y1, p1.Z), V3(p2.X, y2, p2.Z), Color3.fromRGB(120, 82, 54))
					end
				end
			end
		end
	end
	Landmarks.BossArena(structures, o + Layout.Zones.Boss.Center, Layout.Zones.Boss.Radius + 6, pal, groundAt)

	-- Light shafts (god rays) over the island
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = R * rng:NextNumber(0.2, 0.8)
		local p = o + V3(math.cos(a) * d, 0, math.sin(a) * d)
		Props.LightShaft(decor, p, 220, rng:NextNumber(14, 26), Color3.fromRGB(255, 252, 230))
	end

	-- Interactables --------------------------------------------------------------------------------
	local plazaY = ground(o + Layout.Plaza) or 0
	Landmarks.Plaza(interact, V3(o.X, plazaY, o.Z) + Layout.Plaza, pal.Accent, world.Id)
	local toSpawn = (o + Layout.Spawn) - (o + Layout.Shop)
	local shopPos = o + Layout.Shop
	Landmarks.ShopStand(interact, V3(shopPos.X, ground(shopPos) or 0, shopPos.Z), V3(toSpawn.X, 0, toSpawn.Z).Unit + V3(0.3, 0, 0), Color3.fromRGB(230, 60, 80))
	local rewardsPos = o + Layout.Rewards
	Landmarks.RewardsChest(interact, V3(rewardsPos.X, ground(rewardsPos) or 0, rewardsPos.Z), V3(-0.3, 0, 1))
	local portalPos = o + Layout.Portal
	Landmarks.Portal(interact, V3(portalPos.X, ground(portalPos) or 0, portalPos.Z), (o - portalPos) * V3(1, 0, 1), pal.Accent)

	-- Theme landmarks --------------------------------------------------------------------------------
	local dock = o + Layout.Dock
	if world.Theme == "Grass" then
		-- Sky ship docked beside the island.
		local shipCF = CF(dock + V3(-128, 7, 0))
		Ship.Build(structures, shipCF)
		-- Pier + gangway
		local pierY = ground(dock) or 0
		for i = 0, 8 do
			Props.Part(structures, V3(14, 1, 4.6), CF(dock.X - 18 - i * 4.4, pierY + 0.6, dock.Z), i % 2 == 0 and Color3.fromRGB(176, 128, 86) or Color3.fromRGB(150, 104, 66))
		end
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 4 do
				Props.Part(structures, V3(1, 7, 1), CF(dock.X - 18 - i * 9, pierY - 1.5, dock.Z + side * 7), Color3.fromRGB(90, 60, 40))
			end
		end
		local gangStart = V3(dock.X - 56, pierY + 1, dock.Z)
		local gangEnd = V3(shipCF.X + 18, shipCF.Y + 0.4, shipCF.Z)
		local steps = 8
		for i = 0, steps - 1 do
			local a = gangStart:Lerp(gangEnd, i / steps)
			local b = gangStart:Lerp(gangEnd, (i + 1) / steps)
			Props.Part(structures, V3(9, 0.8, (b - a).Magnitude + 0.3), CFrame.lookAt((a + b) / 2, b), i % 2 == 0 and Color3.fromRGB(176, 128, 86) or Color3.fromRGB(150, 104, 66))
		end
		for _, side in ipairs({ -1, 1 }) do
			local a = gangStart + V3(0, 3, side * 4.4)
			local b = gangEnd + V3(0, 3, side * 4.4)
			Props.Part(structures, V3(0.4, 0.4, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(255, 200, 70), { material = Enum.Material.Metal, collide = false })
		end
		-- Barrels & crates on the dock
		for i = 1, 5 do
			Props.Part(structures, V3(3, 3, 3), CF(dock + V3(10 - i * 5, (ground(dock) or 0) + 1.5, 14)) * CFrame.Angles(0, i, 0), Color3.fromRGB(150, 104, 66))
		end
	elseif world.Theme == "Desert" then
		Landmarks.Pyramid(structures, o + V3(-210, (ground(o + V3(-210, 0, -150)) or 0) - 2, -150), 120)
		for i = 0, 3 do
			local p = o + V3(-90 + i * 60, 0, -60)
			if isFree(p, 4) then
				Landmarks.Obelisk(structures, V3(p.X, ground(p) or 0, p.Z), 26)
			end
		end
	elseif world.Theme == "Frozen" then
		Landmarks.IceCastle(structures, o + V3(-230, (ground(o + V3(-230, 0, -110)) or 0), -110))
	elseif world.Theme == "City" then
		for i = 0, 13 do
			local a = math.rad(160 + i * 9)
			local p = o + V3(math.cos(a), 0, math.sin(a)) * R * rng:NextNumber(0.62, 0.8)
			if isFree(p, 14) then
				Landmarks.Tower(structures, V3(p.X, (ground(p) or 0) - 1, p.Z), rng:NextNumber(18, 30), rng:NextNumber(60, 150), Color3.fromRGB(36, 32, 50), i % 2 == 0 and pal.Accent or Color3.fromRGB(60, 255, 230))
				reserve(p, 20)
			end
		end
	elseif world.Theme == "Celestial" then
		Landmarks.Temple(structures, o + V3(-230, (ground(o + V3(-230, 0, -100)) or 0), -100), pal.Accent)
	end

	-- Showcase NPCs ------------------------------------------------------------------------------------
	local slots = {
		Layout.Plaza + V3(-30, 0, 22), Layout.Plaza + V3(30, 0, 22), Layout.Plaza + V3(-34, 0, -14), Layout.Plaza + V3(34, 0, -14),
		V3(-22, 0, 168), V3(28, 0, 186), V3(-60, 0, -70), V3(-120, 0, -40),
	}
	if world.Theme == "Grass" then
		slots[7] = Layout.Dock + V3(8, 0, -12)
		slots[8] = Layout.Dock + V3(8, 0, 14)
	end
	local npcFolder = folder(folders.Showcase, "World" .. world.Id)
	for i, id in ipairs(Fighters.WorldNPCs[world.Id] or {}) do
		local slot = slots[i]
		local def = Fighters.ById[id]
		if slot and def then
			local p = o + slot
			local y = ground(p) or 0
			local base = V3(p.X, y, p.Z)
			local pedestal = Landmarks.CylinderY(decor, 1.2, 9, base + V3(0, 0.6, 0), Color3.fromRGB(236, 232, 226))
			pedestal.Name = "Pedestal"
			Landmarks.CylinderY(decor, 0.3, 9.6, base + V3(0, 1.1, 0), Rarities.Info[def.Rarity].Color, { material = Enum.Material.Neon, collide = false })
			local model = Rig.BuildFighter(def, 1)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = d == model.PrimaryPart
				end
			end
			local face = (o + Layout.Spawn) - base
			face = V3(face.X, 0, face.Z)
			if face.Magnitude < 1 then
				face = V3(0, 0, 1)
			end
			local hip = model:GetAttribute("HipHeight") or 3
			model:PivotTo(CFrame.lookAt(base + V3(0, 1.2 + hip, 0), base + V3(0, 1.2 + hip, 0) + face.Unit))
			Rig.NameTag(model, def, 1 + ((i * 3) % 9))
			model:SetAttribute("Showcase", true)
			model.Parent = npcFolder
			CollectionService:AddTag(model, "AnimeRig")
		end
	end

	-- Enemy spawn points ------------------------------------------------------------------------------
	local points = {}
	for zoneName, zone in pairs(Layout.Zones) do
		local list = world.Zones[zoneName] or {}
		local c = o + zone.Center
		for i, enemyId in ipairs(list) do
			local p
			if #list == 1 then
				p = c
			else
				local a = (i / #list) * math.pi * 2 + 0.3
				p = c + V3(math.cos(a), 0, math.sin(a)) * zone.Radius * (i % 2 == 0 and 0.55 or 0.35)
			end
			local y = ground(p) or 0
			local pos = V3(p.X, y, p.Z)
			local facing = (o + Layout.Plaza) - pos
			facing = V3(facing.X, 0, facing.Z).Unit
			table.insert(points, { EnemyId = enemyId, World = world.Id, CFrame = CFrame.lookAt(pos, pos + facing) })
		end
	end

	-- Spawn ---------------------------------------------------------------------------------------------
	local spawnPos = o + Layout.Spawn
	local spawnY = ground(spawnPos) or 0
	local spawnBase = V3(spawnPos.X, spawnY, spawnPos.Z)
	local lookTarget = o + Layout.SpawnLook
	local spawnCF = CFrame.lookAt(spawnBase, V3(lookTarget.X, spawnY, lookTarget.Z))
	Landmarks.CylinderY(decor, 1, 26, spawnBase + V3(0, 0.3, 0), Color3.fromRGB(236, 232, 226))
	Landmarks.CylinderY(decor, 1.1, 20, spawnBase + V3(0, 0.35, 0), pal.Accent, { material = Enum.Material.Neon, transparency = 0.2 })
	Landmarks.CylinderY(decor, 1.2, 17, spawnBase + V3(0, 0.4, 0), Color3.fromRGB(246, 244, 240))
	if world.Id == 1 then
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "Spawn"
		spawnLocation.Size = V3(12, 1, 12)
		spawnLocation.CFrame = spawnCF * CF(0, 0.5, 0)
		spawnLocation.Anchored = true
		spawnLocation.Transparency = 1
		spawnLocation.CanCollide = false
		spawnLocation.Neutral = true
		spawnLocation.Duration = 0
		spawnLocation.Parent = root
	end

	return { Spawn = spawnCF, EnemyPoints = points }
end

function WorldBuilder.Build()
	setupWorkspace()
	setMaterialColors()
	local result = { Spawns = {}, EnemyPoints = {} }
	for _, world in ipairs(Worlds.List) do
		local ok, info = pcall(buildWorld, world)
		if ok then
			result.Spawns[world.Id] = info.Spawn
			for _, point in ipairs(info.EnemyPoints) do
				table.insert(result.EnemyPoints, point)
			end
		else
			warn("[WorldBuilder] failed to build world " .. world.Id .. ": " .. tostring(info))
		end
		task.wait()
	end
	return result
end

return WorldBuilder
