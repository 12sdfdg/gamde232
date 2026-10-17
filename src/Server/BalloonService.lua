-- Spawns balloons, moves them along the path, applies damage and handles pops/leaks.

local BalloonService = {}

local ctx
local balloons = {}
local folder

local function makeHealthBar(adornee: BasePart, name: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthGui"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffset = Vector3.new(0, adornee.Size.Y / 2 + 1.8, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Adornee = adornee

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.5, 0)
	title.BackgroundTransparency = 1
	title.Text = name
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.3
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = gui

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.new(1, 0, 0.42, 0)
	back.Position = UDim2.new(0, 0, 0.55, 0)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 4)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 230, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.ZIndex = 2
	text.Parent = back

	gui.Parent = adornee
	return gui
end

local function refreshBar(b)
	local back = b.gui.Back
	back.Fill.Size = UDim2.fromScale(math.clamp(b.hp / b.maxHp, 0, 1), 1)
	back.Text.Text = string.format("%d / %d", math.ceil(b.hp), b.maxHp)
end

local function removeAt(index: number)
	local b = balloons[index]
	table.remove(balloons, index)
	b.part:Destroy()
end

function BalloonService.init(context)
	ctx = context
	folder = Instance.new("Folder")
	folder.Name = "Balloons"
	folder.Parent = workspace
end

function BalloonService.spawn(def, hpMultiplier: number)
	local waypoints = ctx.map.waypoints
	local hover = def.size / 2 + 1.5

	local p = Instance.new("Part")
	p.Name = def.name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(def.size, def.size * 1.15, def.size)
	p.Color = def.color
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0.1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CFrame = CFrame.new(waypoints[1] + Vector3.new(0, hover, 0))
	p.Parent = folder

	local maxHp = math.floor(def.hp * hpMultiplier)
	local b = {
		part = p,
		def = def,
		hp = maxHp,
		maxHp = maxHp,
		reward = math.floor(def.reward * (1 + (hpMultiplier - 1) * 0.5)),
		speed = def.speed,
		hover = hover,
		target = 2,
	}
	b.gui = makeHealthBar(p, def.name)
	refreshBar(b)
	table.insert(balloons, b)
	return b
end

function BalloonService.update(dt: number)
	local waypoints = ctx.map.waypoints
	for i = #balloons, 1, -1 do
		local b = balloons[i]
		local remaining = b.speed * dt
		local pos = b.part.Position
		while remaining > 0 and b.target <= #waypoints do
			local goal = waypoints[b.target] + Vector3.new(0, b.hover, 0)
			local offset = goal - pos
			local dist = offset.Magnitude
			if dist <= remaining then
				pos = goal
				remaining -= dist
				b.target += 1
			else
				pos += offset.Unit * remaining
				remaining = 0
			end
		end

		if b.target > #waypoints then
			ctx.WaveService.onLeak(b.def.damage)
			removeAt(i)
		else
			-- gentle bob so balloons feel floaty
			local bob = math.sin(os.clock() * 3 + i) * 0.3
			b.part.CFrame = CFrame.new(pos + Vector3.new(0, bob, 0))
			b.distanceLeft = (waypoints[b.target] - pos).Magnitude
		end
	end
end

-- Returns the balloon in range that is furthest along the path ("first" targeting).
function BalloonService.findTarget(origin: Vector3, range: number)
	local best, bestScore = nil, -math.huge
	for _, b in ipairs(balloons) do
		if (b.part.Position - origin).Magnitude <= range then
			local score = b.target * 10000 - (b.distanceLeft or 0)
			if score > bestScore then
				best, bestScore = b, score
			end
		end
	end
	return best
end

function BalloonService.damage(b, amount: number, byPlayer: Player?)
	if b.hp <= 0 then
		return
	end
	b.hp -= amount
	if b.hp > 0 then
		refreshBar(b)
		return
	end
	local index = table.find(balloons, b)
	if index then
		removeAt(index)
	end
	if byPlayer then
		ctx.PlayerData.addCash(byPlayer, b.reward)
	end
end

function BalloonService.count(): number
	return #balloons
end

function BalloonService.clear()
	for i = #balloons, 1, -1 do
		removeAt(i)
	end
end

return BalloonService
