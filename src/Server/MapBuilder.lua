-- Builds a playable beach map on an empty place: sand ground, the balloon path,
-- a spawn marker and the base. Returns the path waypoints for BalloonService.

local MapBuilder = {}

local WAYPOINTS = {
	Vector3.new(-90, 0, -60),
	Vector3.new(-30, 0, -60),
	Vector3.new(-30, 0, 20),
	Vector3.new(40, 0, 20),
	Vector3.new(40, 0, -40),
	Vector3.new(90, 0, -40),
}

local PATH_WIDTH = 8

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

function MapBuilder.build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	part({
		Name = "Ground",
		Size = Vector3.new(220, 2, 180),
		Position = Vector3.new(0, -1, -20),
		Color = Color3.fromRGB(236, 214, 160),
		Material = Enum.Material.Sand,
		Parent = map,
	})

	part({
		Name = "Water",
		Size = Vector3.new(600, 1, 600),
		Position = Vector3.new(0, -2.5, -20),
		Color = Color3.fromRGB(60, 170, 220),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15,
		CanCollide = false,
		Parent = map,
	})

	-- Path segments between consecutive waypoints.
	local pathFolder = Instance.new("Folder")
	pathFolder.Name = "Path"
	pathFolder.Parent = map
	for i = 1, #WAYPOINTS - 1 do
		local a, b = WAYPOINTS[i], WAYPOINTS[i + 1]
		local length = (b - a).Magnitude + PATH_WIDTH
		local mid = (a + b) / 2
		part({
			Name = "PathSegment",
			Size = Vector3.new(PATH_WIDTH, 0.2, length),
			CFrame = CFrame.lookAt(mid, b) + Vector3.new(0, 0.1, 0),
			Color = Color3.fromRGB(214, 180, 110),
			Material = Enum.Material.WoodPlanks,
			CanCollide = false,
			Parent = pathFolder,
		})
	end

	part({
		Name = "Spawn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 12, 12),
		CFrame = CFrame.new(WAYPOINTS[1] + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 90, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = map,
	})

	part({
		Name = "Base",
		Size = Vector3.new(14, 10, 14),
		Position = WAYPOINTS[#WAYPOINTS] + Vector3.new(0, 5, 0),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Parent = map,
	})

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(10, 1, 10)
	spawnLocation.Position = Vector3.new(0, 0.5, -20)
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Neutral = true
	spawnLocation.Parent = map

	map.Parent = workspace

	return {
		waypoints = WAYPOINTS,
		pathWidth = PATH_WIDTH,
		folder = map,
	}
end

-- Shortest horizontal distance from a point to the path polyline.
function MapBuilder.distanceToPath(waypoints, point: Vector3): number
	local p = Vector3.new(point.X, 0, point.Z)
	local best = math.huge
	for i = 1, #waypoints - 1 do
		local a = Vector3.new(waypoints[i].X, 0, waypoints[i].Z)
		local b = Vector3.new(waypoints[i + 1].X, 0, waypoints[i + 1].Z)
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		best = math.min(best, (p - (a + ab * t)).Magnitude)
	end
	return best
end

return MapBuilder
