-- Balloon waves: spawning, movement along the path, damage, popping and rewards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local WaveService = {}

local remotes: any
local rng = Random.new()

local function notify(player: Player?, text: string, color: Color3?)
	if player then
		remotes.Notify:FireClient(player, text, color)
	else
		remotes.Notify:FireAllClients(text, color)
	end
end

local function sendState(plot)
	if plot.owner then
		remotes.WaveState:FireClient(plot.owner, {
			running = plot.running,
			wave = plot.wave,
			lives = plot.lives,
			maxLives = Config.StartingLives,
			alive = #plot.balloons,
		})
	end
end
WaveService.SendState = sendState

---------------------------------------------------------------------- balloon model
local function makeBalloon(def, hp: number)
	local scale = def.size or 1
	local model = Instance.new("Model")
	model.Name = def.id .. "Balloon"

	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(4.2, 4.2, 4.2) * scale
	ball.Color = def.color
	ball.Material = if def.golden then Enum.Material.Foil elseif def.rainbow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	ball.Reflectance = if def.golden then 0.3 else 0.08
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = true
	ball.CastShadow = true
	ball.Parent = model

	local knot = Instance.new("Part")
	knot.Name = "Knot"
	knot.Size = Vector3.new(0.7, 0.6, 0.7) * scale
	knot.Color = def.color
	knot.Anchored = false
	knot.Massless = true
	knot.CanCollide = false
	knot.CFrame = ball.CFrame * CFrame.new(0, -ball.Size.Y / 2, 0)
	knot.Parent = model

	local str = Instance.new("Part")
	str.Name = "String"
	str.Size = Vector3.new(0.08, 3.5, 0.08)
	str.Color = Color3.new(1, 1, 1)
	str.Anchored = false
	str.Massless = true
	str.CanCollide = false
	str.CanQuery = false
	str.CFrame = ball.CFrame * CFrame.new(0, -ball.Size.Y / 2 - 1.75, 0)
	str.Parent = model

	for _, p in { knot, str } do
		local w = Instance.new("WeldConstraint")
		w.Part0 = ball
		w.Part1 = p
		w.Parent = p
	end

	if def.mystery then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		local q = Instance.new("TextLabel")
		q.Size = UDim2.fromScale(1, 1)
		q.BackgroundTransparency = 1
		q.Text = "?"
		q.TextScaled = true
		q.Font = Enum.Font.FredokaOne
		q.TextColor3 = Color3.fromRGB(180, 180, 190)
		q.Parent = gui
		gui.Parent = ball
	end
	if def.rainbow or def.golden or def.mystery then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Rate = 12
		sparkle.Lifetime = NumberRange.new(0.6, 1)
		sparkle.Speed = NumberRange.new(2, 4)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.6)
		sparkle.Parent = ball
		local light = Instance.new("PointLight")
		light.Color = def.color
		light.Range = 12
		light.Brightness = 2
		light.Parent = ball
	end

	-- name + HP bar
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Size = UDim2.fromOffset(170, 52)
	bb.StudsOffset = Vector3.new(0, ball.Size.Y / 2 + 2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 140
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Size = UDim2.new(1, 0, 0.45, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = def.name
	name.Parent = bb
	local s1 = Instance.new("UIStroke")
	s1.Thickness = 2
	s1.Parent = name
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0.05, 0.5)
	bar.Size = UDim2.fromScale(0.9, 0.45)
	bar.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
	bar.Parent = bb
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	local s2 = Instance.new("UIStroke")
	s2.Thickness = 2
	s2.Color = Color3.fromRGB(20, 40, 20)
	s2.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 230, 70)
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local hpText = Instance.new("TextLabel")
	hpText.Name = "Hp"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.FredokaOne
	hpText.TextScaled = true
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.Text = Util.Abbrev(hp) .. " / " .. Util.Abbrev(hp)
	hpText.ZIndex = 2
	hpText.Parent = bar
	local s3 = Instance.new("UIStroke")
	s3.Thickness = 1.5
	s3.Parent = hpText
	bb.Parent = ball

	model.PrimaryPart = ball
	return model
end

local function updateBar(b)
	local bb = b.model.PrimaryPart and b.model.PrimaryPart:FindFirstChild("Info")
	if bb then
		local bar = bb:FindFirstChild("Bar")
		bar.Fill.Size = UDim2.fromScale(math.max(0, b.hp / b.maxHp), 1)
		bar.Hp.Text = Util.Abbrev(math.max(0, math.ceil(b.hp))) .. " / " .. Util.Abbrev(b.maxHp)
	end
end

---------------------------------------------------------------------- spawning
local function spawnBalloon(plot)
	local owner = plot.owner
	if not owner then
		return
	end
	local stats = DataService.Stats(owner)
	local luck = stats.luck * (1 + plot.wave * 0.05)
	local def = Util.RollFrom(Config.Balloons, luck, rng)
	local hp = math.floor(def.hp * Config.HpGrowth ^ (plot.wave - 1))
	local model = makeBalloon(def, hp)
	local b = {
		def = def,
		hp = hp,
		maxHp = hp,
		reward = def.reward * (1 + Config.RewardGrowth * (plot.wave - 1)),
		dist = 0,
		speed = def.speed,
		model = model,
		plot = plot,
		alive = true,
		phase = rng:NextNumber(0, 6.28),
	}
	local pos = PlotService.PointAt(plot, 0)
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 5, 0)))
	model.Parent = plot.model.Balloons
	table.insert(plot.balloons, b)
	if def.chance >= 500 then
		notify(nil, string.format("🎈 %s found a %s! (%s)", owner.DisplayName, def.name, Util.ChanceText(def.chance)), def.color)
	end
	return b
end

local function removeBalloon(b)
	b.alive = false
	local list = b.plot.balloons
	local i = table.find(list, b)
	if i then
		table.remove(list, i)
	end
	b.model:Destroy()
end

function WaveService.Damage(b, amount: number, attacker: Player?)
	if not b.alive then
		return
	end
	b.hp -= amount
	if b.hp <= 0 then
		local plot = b.plot
		local owner = plot.owner
		local pos = b.model.PrimaryPart.Position
		removeBalloon(b)
		if owner then
			local stats = DataService.Stats(owner)
			local coins = math.max(1, math.floor(b.reward * stats.coinMult))
			DataService.AddCoins(owner, coins)
			local data = DataService.Get(owner)
			if data then
				data.popped += 1
			end
			remotes.Popped:FireClient(owner, pos, b.def.color, coins, b.def.id)
			if attacker and attacker ~= owner then
				remotes.Popped:FireClient(attacker, pos, b.def.color, 0, b.def.id)
			end
		end
	else
		updateBar(b)
	end
end

function WaveService.BalloonsNear(plot, pos: Vector3, radius: number)
	local out = {}
	for _, b in plot.balloons do
		if b.alive and (b.model.PrimaryPart.Position - pos).Magnitude <= radius then
			table.insert(out, b)
		end
	end
	return out
end

local function clearBalloons(plot)
	for i = #plot.balloons, 1, -1 do
		removeBalloon(plot.balloons[i])
	end
end

local function gameOver(plot)
	local owner = plot.owner
	plot.running = false
	plot.runId += 1
	clearBalloons(plot)
	if owner then
		notify(owner, string.format("💥 Your base fell on wave %d! Press Start to try again.", plot.wave), Color3.fromRGB(255, 90, 90))
		remotes.PlaySound:FireClient(owner, "Lose")
	end
	plot.wave = 0
	plot.lives = Config.StartingLives
	sendState(plot)
end

local function runWaves(plot, runId: number)
	while plot.running and plot.runId == runId and plot.owner do
		local owner = plot.owner
		local stats = DataService.Stats(owner)
		plot.wave += 1
		sendState(plot)
		local count = math.min(Config.WaveBaseCount + plot.wave * Config.WaveCountPerWave, Config.WaveMaxCount)
		for _ = 1, count do
			if not (plot.running and plot.runId == runId) then
				return
			end
			spawnBalloon(plot)
			sendState(plot)
			task.wait(Config.SpawnInterval / stats.waveSpeed)
		end
		while plot.running and plot.runId == runId and #plot.balloons > 0 do
			task.wait(0.25)
		end
		if not (plot.running and plot.runId == runId and plot.owner) then
			return
		end
		-- wave cleared
		local data = DataService.Get(owner)
		if data then
			local bonus = math.floor(Config.WaveClearBonus * plot.wave * stats.bonusMult * stats.coinMult)
			DataService.AddCoins(owner, bonus)
			if plot.wave > data.bestWave then
				data.bestWave = plot.wave
			end
			notify(owner, string.format("Wave %d cleared! +$%s", plot.wave, Util.Abbrev(bonus)), Color3.fromRGB(120, 255, 120))
			remotes.PlaySound:FireClient(owner, "WaveClear")
		end
		task.wait(Config.WaveBreak / stats.waveSpeed)
	end
end

function WaveService.Start(player: Player)
	local plot = PlotService.Get(player)
	if not plot or plot.running then
		return
	end
	plot.running = true
	plot.runId += 1
	plot.wave = 0
	plot.lives = Config.StartingLives
	task.spawn(runWaves, plot, plot.runId)
end

function WaveService.Stop(plot)
	plot.running = false
	plot.runId += 1
	clearBalloons(plot)
	plot.wave = 0
	plot.lives = Config.StartingLives
	sendState(plot)
end

---------------------------------------------------------------------- movement
local t = 0
local rainbowHue = 0
local function step(dt: number)
	t += dt
	rainbowHue = (rainbowHue + dt * 0.4) % 1
	for _, plot in PlotService.All() do
		local balloons = plot.balloons
		for i = #balloons, 1, -1 do
			local b = balloons[i]
			if b.alive then
				b.dist += b.speed * dt
				if b.dist >= plot.length then
					removeBalloon(b)
					plot.lives -= b.def.lives or 1
					sendState(plot)
					if plot.lives <= 0 then
						gameOver(plot)
						break
					end
				else
					local pos = PlotService.PointAt(plot, b.dist)
					local bob = math.sin(t * 3 + b.phase) * 0.5
					b.model.PrimaryPart.CFrame = CFrame.new(pos + Vector3.new(0, 5 + bob, 0)) * CFrame.Angles(0, t + b.phase, 0)
					if b.def.rainbow then
						b.model.PrimaryPart.Color = Color3.fromHSV(rainbowHue, 0.85, 1)
					end
				end
			end
		end
	end
end

function WaveService.Init(remoteFolder: Folder)
	remotes = remoteFolder
	RunService.Heartbeat:Connect(step)
end

return WaveService
