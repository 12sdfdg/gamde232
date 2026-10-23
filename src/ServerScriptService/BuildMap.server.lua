-- Hatch-eggs style map (as in the reference video): flat green plain, terraced
-- voxel hills with blocky trees, egg stands with yellow/black canopies, a yellow
-- crane tower, an event billboard with a countdown, a blocky green building.
-- Synced into ServerScriptService by Rojo. To build the map in edit mode, run in
-- the Studio Command Bar:
--   loadstring(game.ServerScriptService.BuildMap.Source)()
-- In Play mode it also runs on its own. Re-running replaces the previous build.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local old = Workspace:FindFirstChild("HatchMap")
if old then old:Destroy() end
local map = Instance.new("Folder")
map.Name = "HatchMap"
map.Parent = Workspace

local GRASS = Color3.fromRGB(96, 196, 72)
local GRASS_DARK = Color3.fromRGB(70, 160, 56)
local DIRT = Color3.fromRGB(120, 86, 52)
local WOOD = Color3.fromRGB(150, 110, 66)
local LEAF = Color3.fromRGB(58, 150, 52)
local YELLOW = Color3.fromRGB(255, 200, 40)
local BLACK = Color3.fromRGB(35, 35, 35)
local CONCRETE = Color3.fromRGB(170, 170, 170)
local STEEL = Color3.fromRGB(60, 60, 70)

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent or map
	return p
end

local function block(size, pos, color, parent, material)
	return part({
		Size = size,
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	}, parent)
end

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = map
	return f
end

----------------------------------------------------------------------
-- Ground
----------------------------------------------------------------------
local ground = folder("Ground")
local PLAIN = 420
block(Vector3.new(PLAIN, 4, PLAIN), Vector3.new(0, -2, 0), GRASS, ground, Enum.Material.Grass)

----------------------------------------------------------------------
-- Terraced voxel hills on three sides (north, west, east) with blocky trees
----------------------------------------------------------------------
local hills = folder("Hills")
local trees = folder("Trees")
local STEP = 12          -- block size of one voxel step
local rng = Random.new(7)

local function tree(pos, parent)
	local h = 10 + rng:NextInteger(0, 4)
	block(Vector3.new(3, h, 3), pos + Vector3.new(0, h / 2, 0), WOOD, parent)
	local c = 9 + rng:NextInteger(0, 3)
	block(Vector3.new(c, c, c), pos + Vector3.new(0, h + c / 2 - 1, 0), LEAF, parent)
end

-- One terraced ridge along an axis. `cells` long, `tiers` high, stepping back one
-- cell per tier. dir is a unit Vector3 pointing from the plain into the ridge.
local function ridge(origin, along, dir, cells, tiers)
	for t = 1, tiers do
		for i = 0, cells - 1 do
			-- ragged edge: some cells skip the top tier to break the straight line
			if t == tiers and rng:NextNumber() < 0.35 then continue end
			local pos = origin + along * (i * STEP) + dir * ((t - 1) * STEP)
			local y = (t - 1) * STEP + STEP / 2
			block(Vector3.new(STEP, STEP, STEP), Vector3.new(pos.X, y, pos.Z),
				(t % 2 == 0) and GRASS_DARK or GRASS, hills, Enum.Material.Grass)
			-- dirt strip under the grass top of each tier, on the face toward the plain
			local face = Vector3.new(pos.X, y - STEP * 0.15, pos.Z) - dir * (STEP / 2 - 0.3)
			block(Vector3.new(dir.X ~= 0 and 0.6 or STEP, STEP * 0.7, dir.Z ~= 0 and 0.6 or STEP), face, DIRT, hills)
			if rng:NextNumber() < 0.18 then
				tree(Vector3.new(pos.X, y + STEP / 2, pos.Z), trees)
			end
		end
	end
end

local half = PLAIN / 2
ridge(Vector3.new(-half + STEP / 2, 0, -half + STEP / 2), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), PLAIN / STEP, 4) -- north
ridge(Vector3.new(-half + STEP / 2, 0, -half + STEP * 1.5), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), PLAIN / STEP - 1, 3) -- west
ridge(Vector3.new(half - STEP / 2, 0, -half + STEP * 1.5), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), PLAIN / STEP - 1, 3) -- east

-- a few loose trees on the plain edge
for _, p in ipairs({ Vector3.new(-150, 0, 60), Vector3.new(-170, 0, 120), Vector3.new(160, 0, 100), Vector3.new(-120, 0, -90) }) do
	tree(p, trees)
end

-- low fence line in front of the north hills
local fence = folder("Fence")
for x = -half + 30, half - 30, 8 do
	block(Vector3.new(0.6, 5, 0.6), Vector3.new(x, 2.5, -half + STEP * 1.5 + 2), WOOD, fence)
end
block(Vector3.new(PLAIN - 60, 0.5, 0.5), Vector3.new(0, 4.3, -half + STEP * 1.5 + 2), WOOD, fence)
block(Vector3.new(PLAIN - 60, 0.5, 0.5), Vector3.new(0, 2.3, -half + STEP * 1.5 + 2), WOOD, fence)

----------------------------------------------------------------------
-- Egg stands: concrete pad, four posts, yellow/black striped canopy, egg on pedestal
----------------------------------------------------------------------
local stands = folder("EggStands")

local function eggStand(center, name, eggColor)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = stands
	block(Vector3.new(16, 1, 12), center + Vector3.new(0, 0.5, 0), CONCRETE, m, Enum.Material.Concrete)
	for _, dx in ipairs({ -7, 7 }) do
		for _, dz in ipairs({ -5, 5 }) do
			block(Vector3.new(1, 9, 1), center + Vector3.new(dx, 5.5, dz), WOOD, m)
		end
	end
	-- striped canopy: alternating yellow/black strips
	for i = 0, 7 do
		local x = -7 + i * 2
		block(Vector3.new(2, 0.8, 13), center + Vector3.new(x, 10.4, 0), (i % 2 == 0) and YELLOW or BLACK, m)
	end
	-- pedestal + egg
	block(Vector3.new(4, 2, 4), center + Vector3.new(0, 2, 0), STEEL, m, Enum.Material.Metal)
	local egg = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 5, 4),
		CFrame = CFrame.new(center + Vector3.new(0, 5.5, 0)),
		Color = eggColor,
		Material = Enum.Material.SmoothPlastic,
	}, m)
	egg.Name = "Egg"
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(160, 40)
	label.StudsOffset = Vector3.new(0, 4, 0)
	label.AlwaysOnTop = true
	label.Parent = egg
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = name
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.Parent = label
	m.PrimaryPart = egg
end

eggStand(Vector3.new(-40, 0, -40), "Basic Egg", Color3.fromRGB(235, 225, 200))
eggStand(Vector3.new(0, 0, -60), "Pumpkin Egg", Color3.fromRGB(240, 130, 40))
eggStand(Vector3.new(40, 0, -40), "Cursed Egg", Color3.fromRGB(120, 60, 180))

----------------------------------------------------------------------
-- Crane tower (yellow lattice) with boom
----------------------------------------------------------------------
local crane = folder("Crane")
local cx, cz = 120, -60
local H = 110
for _, dx in ipairs({ -4, 4 }) do
	for _, dz in ipairs({ -4, 4 }) do
		block(Vector3.new(1.2, H, 1.2), Vector3.new(cx + dx, H / 2, cz + dz), YELLOW, crane, Enum.Material.Metal)
	end
end
for y = 8, H - 4, 8 do
	block(Vector3.new(9.2, 0.8, 0.8), Vector3.new(cx, y, cz - 4), YELLOW, crane, Enum.Material.Metal)
	block(Vector3.new(9.2, 0.8, 0.8), Vector3.new(cx, y, cz + 4), YELLOW, crane, Enum.Material.Metal)
	block(Vector3.new(0.8, 0.8, 9.2), Vector3.new(cx - 4, y, cz), YELLOW, crane, Enum.Material.Metal)
	block(Vector3.new(0.8, 0.8, 9.2), Vector3.new(cx + 4, y, cz), YELLOW, crane, Enum.Material.Metal)
end
block(Vector3.new(90, 2, 3), Vector3.new(cx - 40, H + 1, cz), YELLOW, crane, Enum.Material.Metal) -- boom
block(Vector3.new(14, 2, 3), Vector3.new(cx + 10, H + 1, cz), YELLOW, crane, Enum.Material.Metal) -- counter-jib
block(Vector3.new(6, 6, 6), Vector3.new(cx, H + 5, cz), STEEL, crane, Enum.Material.Metal)       -- cab
block(Vector3.new(0.4, 30, 0.4), Vector3.new(cx - 70, H - 14, cz), BLACK, crane)                  -- cable
block(Vector3.new(3, 2, 2), Vector3.new(cx - 70, H - 30, cz), STEEL, crane, Enum.Material.Metal)  -- hook

----------------------------------------------------------------------
-- Event billboard with countdown
----------------------------------------------------------------------
local board = folder("Billboard")
local bx, bz = 20, -130
block(Vector3.new(3, 60, 3), Vector3.new(bx - 50, 30, bz), STEEL, board, Enum.Material.Metal)
block(Vector3.new(3, 60, 3), Vector3.new(bx + 50, 30, bz), STEEL, board, Enum.Material.Metal)
local screen = block(Vector3.new(110, 30, 2), Vector3.new(bx, 58, bz), BLACK, board)
screen.Name = "Screen"
-- yellow/black hazard trim along the bottom
for i = 0, 10 do
	block(Vector3.new(10, 2, 2.4), Vector3.new(bx - 50 + i * 10, 42, bz), (i % 2 == 0) and YELLOW or BLACK, board)
end
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.CanvasSize = Vector2.new(1100, 300)
gui.Parent = screen
local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.45)
title.BackgroundTransparency = 1
title.Text = "HALLOWEEN EVENT STARTS IN"
title.TextColor3 = Color3.fromRGB(255, 140, 0)
title.TextScaled = true
title.Font = Enum.Font.FredokaOne
title.Parent = gui
local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.Position = UDim2.fromScale(0, 0.45)
timer.Size = UDim2.fromScale(1, 0.55)
timer.BackgroundTransparency = 1
timer.Text = "00:04:29"
timer.TextColor3 = Color3.new(1, 1, 1)
timer.TextScaled = true
timer.Font = Enum.Font.Code
timer.Parent = gui

-- Countdown driver: a Script that ticks the billboard (copy to ServerScriptService to run in play)
local tick = Instance.new("Script")
tick.Name = "BillboardCountdown"
tick.Source = [[
local timer = workspace:WaitForChild("HatchMap"):WaitForChild("Billboard"):WaitForChild("Screen").SurfaceGui.Timer
local seconds = 4 * 60 + 29
while seconds >= 0 do
	timer.Text = string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	task.wait(1)
	seconds -= 1
end
timer.Text = "EVENT LIVE!"
]]
tick.Parent = screen

----------------------------------------------------------------------
-- Blocky green building (right side), stacked boxes with wood frames
----------------------------------------------------------------------
local bld = folder("Building")
local ox, oz = 150, 30
local boxes = {
	{ Vector3.new(60, 24, 50), Vector3.new(ox, 12, oz) },
	{ Vector3.new(40, 20, 36), Vector3.new(ox + 6, 34, oz - 4) },
	{ Vector3.new(24, 16, 24), Vector3.new(ox + 10, 52, oz) },
	{ Vector3.new(30, 14, 30), Vector3.new(ox - 20, 31, oz + 14) },
}
for _, b in ipairs(boxes) do
	local size, pos = b[1], b[2]
	block(size, pos, GRASS, bld, Enum.Material.Grass)
	-- wood edge frames on the front face
	block(Vector3.new(size.X, 1.5, 1.5), pos + Vector3.new(0, size.Y / 2, -size.Z / 2), WOOD, bld)
	block(Vector3.new(1.5, size.Y, 1.5), pos + Vector3.new(-size.X / 2, 0, -size.Z / 2), WOOD, bld)
	block(Vector3.new(1.5, size.Y, 1.5), pos + Vector3.new(size.X / 2, 0, -size.Z / 2), WOOD, bld)
end
-- doorway
block(Vector3.new(8, 12, 1), Vector3.new(ox - 10, 6, oz - 25), BLACK, bld)
for i = 0, 3 do
	block(Vector3.new(2, 1, 1.2), Vector3.new(ox - 13 + i * 2, 12.6, oz - 25), (i % 2 == 0) and YELLOW or BLACK, bld)
end

----------------------------------------------------------------------
-- Spawn, lighting, sky
----------------------------------------------------------------------
local spawn = Instance.new("SpawnLocation")
spawn.Size = Vector3.new(12, 1, 12)
spawn.CFrame = CFrame.new(0, 0.5, 20)
spawn.Anchored = true
spawn.Color = GRASS_DARK
spawn.Material = Enum.Material.Grass
spawn.Neutral = true
spawn.Parent = map

Lighting.ClockTime = 13
Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromRGB(140, 140, 140)
Lighting.OutdoorAmbient = Color3.fromRGB(160, 170, 180)
if not Lighting:FindFirstChildOfClass("Sky") then
	local sky = Instance.new("Sky")
	sky.Parent = Lighting
end
local terrain = Workspace:FindFirstChildOfClass("Terrain")
if terrain and not terrain:FindFirstChildOfClass("Clouds") then
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.6
	clouds.Density = 0.3
	clouds.Parent = terrain
end

print("HatchMap built:", #map:GetDescendants(), "instances")
