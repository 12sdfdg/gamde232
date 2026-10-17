-- Builds the tropical map at runtime: water, hub island, player plots with
-- balloon paths, caves, huts, palm trees, bridges and leaderboard boards.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local SAND = Color3.fromRGB(240, 222, 175)
local SAND_DARK = Color3.fromRGB(226, 203, 150)
local PATH_A = Color3.fromRGB(232, 205, 150)
local PATH_B = Color3.fromRGB(222, 190, 130)
local ROCK = Color3.fromRGB(130, 130, 140)
local WOOD = Color3.fromRGB(150, 100, 60)
local LEAF = Color3.fromRGB(70, 175, 70)
local GRASS = Color3.fromRGB(110, 190, 80)

local rng = Random.new(1234)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function palm(parent: Instance, base: Vector3, height: number?)
	local model = Instance.new("Model")
	model.Name = "Palm"
	local h = height or rng:NextNumber(14, 22)
	local segs = 6
	local lean = rng:NextNumber(-0.25, 0.25)
	local leanZ = rng:NextNumber(-0.25, 0.25)
	local pos = base
	for i = 1, segs do
		local step = Vector3.new(lean * i * 0.4, h / segs, leanZ * i * 0.4)
		local nextPos = pos + step
		local mid = (pos + nextPos) / 2
		local r = 1.6 - i * 0.12
		part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(step.Magnitude + 0.3, r * 2, r * 2),
			CFrame = CFrame.lookAt(mid, nextPos) * CFrame.Angles(0, math.rad(90), 0),
			Color = if i % 2 == 0 then WOOD else Color3.fromRGB(165, 115, 70),
			Material = Enum.Material.Wood,
			CanCollide = i <= 2,
			Parent = model,
		})
		pos = nextPos
	end
	local top = pos
	local leaves = 7
	for i = 1, leaves do
		local yaw = (i / leaves) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local len = rng:NextNumber(9, 12)
		local leaf = part({
			Name = "Leaf",
			Size = Vector3.new(3.2, 0.4, len),
			Color = if i % 2 == 0 then LEAF else Color3.fromRGB(90, 195, 80),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = model,
		})
		leaf.CFrame = CFrame.new(top) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(0, 0, -len / 2)
	end
	for i = 1, 3 do
		part({
			Name = "Coconut",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			Position = top + Vector3.new(math.cos(i * 2.1) * 1, -1, math.sin(i * 2.1) * 1),
			Color = Color3.fromRGB(110, 75, 40),
			CanCollide = false,
			Parent = model,
		})
	end
	model.Parent = parent
	return model
end

local function rock(parent: Instance, pos: Vector3, size: number)
	for i = 1, 3 do
		part({
			Name = "Rock",
			Size = Vector3.new(size * rng:NextNumber(0.7, 1.2), size * rng:NextNumber(0.5, 0.9), size * rng:NextNumber(0.7, 1.2)),
			CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), size * 0.25, rng:NextNumber(-1, 1)) * (i - 1) * 0.5)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
			Color = ROCK,
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
end

local function umbrella(parent: Instance, pos: Vector3, color: Color3)
	part({ Name = "Pole", Size = Vector3.new(0.4, 9, 0.4), Position = pos + Vector3.new(0, 4.5, 0), Color = Color3.new(1, 1, 1), Parent = parent })
	part({
		Name = "Canopy",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 10, 10),
		CFrame = CFrame.new(pos + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Parent = parent,
	})
end

-- Cave arch at the start of the path
local function cave(parent: Instance, pos: Vector3, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "Cave"
	local cf = CFrame.lookAt(pos, pos + facing)
	local function block(offset: Vector3, size: Vector3)
		return part({ Size = size, CFrame = cf * CFrame.new(offset), Color = ROCK, Material = Enum.Material.Slate, Parent = model })
	end
	block(Vector3.new(-8, 7, 2), Vector3.new(6, 14, 12))
	block(Vector3.new(8, 7, 2), Vector3.new(6, 14, 12))
	block(Vector3.new(0, 15, 2), Vector3.new(22, 5, 12))
	local back = block(Vector3.new(0, 7, 7), Vector3.new(12, 14, 2))
	back.Color = Color3.fromRGB(35, 35, 40)
	for i = 1, 4 do
		rock(model, (cf * CFrame.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(4, 10))).Position, rng:NextNumber(4, 7))
	end
	model.Parent = parent
end

-- Little beach hut at the end of the path
local function hut(parent: Instance, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Hut"
	part({ Size = Vector3.new(14, 8, 12), Position = pos + Vector3.new(0, 4, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Size = Vector3.new(4, 6, 0.4), Position = pos + Vector3.new(0, 3, -6.1), Color = Color3.fromRGB(60, 40, 25), Parent = model })
	local roof = part({ Size = Vector3.new(17, 1, 9), Color = Color3.fromRGB(205, 175, 90), Material = Enum.Material.Fabric, Parent = model })
	roof.CFrame = CFrame.new(pos + Vector3.new(0, 10, -3)) * CFrame.Angles(math.rad(-28), 0, 0)
	local roof2 = roof:Clone()
	roof2.CFrame = CFrame.new(pos + Vector3.new(0, 10, 3)) * CFrame.Angles(math.rad(28), 0, 0)
	roof2.Parent = model
	model.Parent = parent
end

local function buildPath(parent: Instance, origin: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "Path"
	local pts = Config.PathPoints
	local tile = Config.PathWidth
	local idx = 0
	for i = 1, #pts - 1 do
		local a = Vector3.new(pts[i].X, 0, pts[i].Y)
		local b = Vector3.new(pts[i + 1].X, 0, pts[i + 1].Y)
		local dir = (b - a).Unit
		local len = (b - a).Magnitude
		local n = math.max(1, math.round(len / tile))
		for k = 0, n do
			idx += 1
			local p = a + dir * (len * k / n)
			part({
				Name = "Tile",
				Size = Vector3.new(tile, 0.3, tile),
				Position = origin + p + Vector3.new(0, 0.15, 0),
				Color = if idx % 2 == 0 then PATH_A else PATH_B,
				Material = Enum.Material.Sand,
				CanCollide = false,
				Parent = folder,
			})
		end
	end
	-- glowing border strips along each segment
	for i = 1, #pts - 1 do
		local a = Vector3.new(pts[i].X, 0, pts[i].Y)
		local b = Vector3.new(pts[i + 1].X, 0, pts[i + 1].Y)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude + tile
		local cf = CFrame.lookAt(origin + mid + Vector3.new(0, 0.2, 0), origin + b + Vector3.new(0, 0.2, 0))
		for _, side in { -1, 1 } do
			part({
				Name = "Edge",
				Size = Vector3.new(0.6, 0.35, len),
				CFrame = cf * CFrame.new(side * (tile / 2 + 0.3), 0, 0),
				Color = Color3.fromRGB(240, 190, 60),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Parent = folder,
			})
		end
	end
	folder.Parent = parent
end

local function sign(parent: Instance, pos: Vector3, facing: Vector3)
	local post = part({ Name = "SignPost", Size = Vector3.new(0.8, 8, 0.8), Position = pos + Vector3.new(0, 4, 0), Color = WOOD, Parent = parent })
	local board = part({
		Name = "Sign",
		Size = Vector3.new(14, 4, 0.6),
		CFrame = CFrame.lookAt(pos + Vector3.new(0, 9, 0), pos + Vector3.new(0, 9, 0) + facing),
		Color = Color3.fromRGB(175, 120, 70),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Owner"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "Empty Base"
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	return post, board
end

-- Builds one plot and returns its model. Origin = centre of the island top (Y = GroundY).
local function buildPlot(index: number, origin: Vector3, hubSide: number)
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)
	plot:SetAttribute("Origin", origin)
	plot:SetAttribute("OwnerId", 0)
	local size = Config.PlotSize
	local ground = part({
		Name = "Ground",
		Size = Vector3.new(size, 6, size),
		Position = origin - Vector3.new(0, 3, 0),
		Color = SAND,
		Material = Enum.Material.Sand,
		Parent = plot,
	})
	-- soft rim
	part({
		Name = "Rim",
		Size = Vector3.new(size + 8, 4, size + 8),
		Position = origin - Vector3.new(0, 4.2, 0),
		Color = SAND_DARK,
		Material = Enum.Material.Sand,
		Parent = plot,
	})
	plot.PrimaryPart = ground
	buildPath(plot, origin)

	local pts = Config.PathPoints
	local first = Vector3.new(pts[1].X, 0, pts[1].Y)
	local second = Vector3.new(pts[2].X, 0, pts[2].Y)
	cave(plot, origin + first - (second - first).Unit * 4, (second - first).Unit)
	local last = Vector3.new(pts[#pts].X, 0, pts[#pts].Y)
	hut(plot, origin + last + Vector3.new(-6, 0, 0))

	for _, corner in { Vector3.new(-62, 0, -62), Vector3.new(62, 0, -62), Vector3.new(-62, 0, 62), Vector3.new(62, 0, 62), Vector3.new(-62, 0, 0), Vector3.new(62, 0, 30) } do
		palm(plot, origin + corner)
	end
	rock(plot, origin + Vector3.new(58, 0, -30), 5)
	rock(plot, origin + Vector3.new(-62, 0, 30), 4)

	local signPos = origin + Vector3.new(55, 0, hubSide * (size / 2 - 6))
	sign(plot, signPos + Vector3.new(8, 0, 0), Vector3.new(0, 0, hubSide))

	local turrets = Instance.new("Folder")
	turrets.Name = "Turrets"
	turrets.Parent = plot
	local balloons = Instance.new("Folder")
	balloons.Name = "Balloons"
	balloons.Parent = plot

	local spawnPoint = Instance.new("Attachment")
	spawnPoint.Name = "SpawnPoint"
	spawnPoint.WorldPosition = origin + Vector3.new(55, 4, hubSide * (size / 2 - 12))
	spawnPoint.Parent = ground
	return plot
end

local function leaderboardBoard(parent: Instance, cf: CFrame, title: string, key: string)
	local model = Instance.new("Model")
	model.Name = "Board_" .. key
	part({ Size = Vector3.new(1, 18, 1), CFrame = cf * CFrame.new(-8, 9, 0.6), Color = WOOD, Parent = model })
	part({ Size = Vector3.new(1, 18, 1), CFrame = cf * CFrame.new(8, 9, 0.6), Color = WOOD, Parent = model })
	local board = part({
		Name = "Screen",
		Size = Vector3.new(16, 16, 0.6),
		CFrame = cf * CFrame.new(0, 11, 0),
		Color = Color3.fromRGB(60, 120, 200),
		Parent = model,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 30
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	local head = Instance.new("TextLabel")
	head.Name = "Title"
	head.LayoutOrder = 0
	head.Size = UDim2.new(1, 0, 0, 60)
	head.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	head.Font = Enum.Font.FredokaOne
	head.TextScaled = true
	head.TextColor3 = Color3.new(1, 1, 1)
	head.Text = title
	head.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = head
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(0.94, 0, 0, 34)
		row.BackgroundColor3 = Color3.fromRGB(40, 90, 170)
		row.BackgroundTransparency = 0.2
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.new(1, 1, 1)
		row.Text = string.format("  #%d  ---", i)
		row.Parent = gui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = row
	end
	model.Parent = parent
	return board
end

function MapBuilder.Build()
	-- lighting
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.25
		atm.Haze = 0.5
		atm.Color = Color3.fromRGB(200, 225, 255)
		atm.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		Instance.new("Sky").Parent = Lighting
	end

	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end

	-- water
	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(40, 170, 220)
	terrain.WaterTransparency = 0.4
	terrain.WaterWaveSize = 0.1
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(1400, 12, 1400), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(0, -16, 0), Vector3.new(1400, 8, 1400), Enum.Material.Sand)

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	-- hub island
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	part({ Name = "HubGround", Size = Vector3.new(520, 6, 180), Position = Vector3.new(0, Config.GroundY - 3, 0), Color = SAND, Material = Enum.Material.Sand, Parent = hub })
	part({ Name = "Grass", Size = Vector3.new(120, 0.4, 70), Position = Vector3.new(0, Config.GroundY + 0.2, 0), Color = GRASS, Material = Enum.Material.Grass, Parent = hub })
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(0, Config.GroundY + 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 200, 60)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub
	for i = 1, 16 do
		palm(hub, Vector3.new(rng:NextNumber(-250, 250), Config.GroundY, (if i % 2 == 0 then 1 else -1) * rng:NextNumber(60, 85)))
	end
	for i = 1, 5 do
		umbrella(hub, Vector3.new(-200 + i * 70, Config.GroundY, rng:NextNumber(-40, 40)), if i % 2 == 0 then Color3.fromRGB(80, 200, 230) else Color3.fromRGB(240, 90, 90))
	end
	rock(hub, Vector3.new(-120, Config.GroundY, 30), 8)
	rock(hub, Vector3.new(140, Config.GroundY, -35), 9)
	hub.Parent = map

	-- leaderboards facing the spawn
	local boards = {}
	local lbFolder = Instance.new("Folder")
	lbFolder.Name = "Leaderboards"
	lbFolder.Parent = map
	for i, info in { { "Best Wave", "BestWave" }, { "Top Rolls", "TopRolls" }, { "Top Coins", "TopCoins" } } do
		local x = (i - 2) * 20
		local cf = CFrame.lookAt(Vector3.new(x, Config.GroundY, 45), Vector3.new(x, Config.GroundY, 0))
		boards[info[2]] = leaderboardBoard(lbFolder, cf, info[1], info[2])
	end

	-- plots in two rows of three
	local plots = {}
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
	local half = Config.PlotSize / 2
	for i = 1, Config.PlotCount do
		local row = if i <= 3 then -1 else 1
		local col = ((i - 1) % 3) - 1
		local origin = Vector3.new(col * 170, Config.GroundY, row * (90 + 25 + half))
		local plot = buildPlot(i, origin, -row)
		plot.Parent = plotsFolder
		plots[i] = plot
		-- bridge from hub to plot
		local zHub = row * 90
		local zPlot = origin.Z - row * half
		local x = origin.X + 55
		local len = math.abs(zPlot - zHub) + 4
		part({
			Name = "Bridge",
			Size = Vector3.new(10, 1, len),
			Position = Vector3.new(x, Config.GroundY - 0.4, (zHub + zPlot) / 2),
			Color = WOOD,
			Material = Enum.Material.WoodPlanks,
			Parent = map,
		})
		for _, side in { -1, 1 } do
			part({
				Name = "Rail",
				Size = Vector3.new(0.6, 2.5, len),
				Position = Vector3.new(x + side * 5, Config.GroundY + 1, (zHub + zPlot) / 2),
				Color = Color3.fromRGB(120, 80, 45),
				Material = Enum.Material.Wood,
				Parent = map,
			})
		end
	end
	return plots, boards
end

return MapBuilder
