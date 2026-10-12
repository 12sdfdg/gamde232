-- Spawns enemies on every island, owns their HP and respawning, and builds their overhead UI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Configs = ReplicatedStorage.Configs
local Game = require(Configs.Game)
local Enemies = require(Configs.Enemies)
local Worlds = require(Configs.Worlds)
local Rarities = require(Configs.Rarities)
local Rig = require(ReplicatedStorage.Modules.Rig)
local Format = require(ReplicatedStorage.Modules.Format)

local EnemyService = {}

local enemyFolder
local nextId = 0
local active = {} -- [model] = state
local killedEvent = Instance.new("BindableEvent")
EnemyService.Killed = killedEvent.Event -- (model, def, contributors)

local function stroke(parent, thickness)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2.5
	s.Color = Color3.fromRGB(14, 10, 22)
	s.Parent = parent
	return s
end

local function text(parent, value, size, position, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = font or Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = value
	l.TextColor3 = color
	stroke(l)
	l.Parent = parent
	return l
end

local function buildBillboard(model, def, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EnemyUI"
	gui.Size = UDim2.fromOffset(260, 170)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = def.Boss and 260 or 130
	gui.Adornee = model.PrimaryPart

	text(gui, def.Name, UDim2.new(1, 0, 0, 34), UDim2.fromOffset(0, 0), Color3.new(1, 1, 1), Enum.Font.LuckiestGuy)
	text(gui, def.Difficulty, UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 32), Rarities.Difficulty[def.Difficulty] or Color3.new(1, 1, 1))

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(0.9, 0, 0, 24)
	bar.Position = UDim2.new(0.05, 0, 0, 58)
	bar.BackgroundColor3 = Color3.fromRGB(24, 18, 36)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bar
	stroke(bar, 2.5)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 40, 80))
	gradient.Rotation = 90
	gradient.Parent = fill
	fill.Parent = bar
	local hpText = text(bar, "", UDim2.fromScale(1, 0.9), UDim2.fromScale(0, 0.05), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	hpText.Name = "HpText"
	hpText.ZIndex = 3
	bar.Parent = gui

	local lootFrame = Instance.new("Frame")
	lootFrame.Name = "Loot"
	lootFrame.BackgroundTransparency = 1
	lootFrame.Size = UDim2.new(1, 0, 0, 80)
	lootFrame.Position = UDim2.fromOffset(0, 86)
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 0)
	layout.Parent = lootFrame
	local shown = 0
	for _, loot in ipairs(def.Loot) do
		if shown < 4 then
			shown += 1
			local pct = loot.Chance * 100
			local pctText = pct >= 10 and string.format("%d%%", pct) or string.format("%.1f%%", pct)
			local color = loot.Chance >= 1 and Color3.fromRGB(220, 220, 230) or (loot.Chance < 0.05 and Color3.fromRGB(255, 170, 40) or Color3.fromRGB(120, 220, 255))
			local l = text(lootFrame, pctText .. " " .. (Enemies.ItemNames[loot.Item] or loot.Item), UDim2.new(1, 0, 0, 18), UDim2.new(), color)
			l.LayoutOrder = shown
		end
	end
	if #def.Loot > 4 then
		local more = text(lootFrame, "+", UDim2.new(1, 0, 0, 16), UDim2.new(), Color3.fromRGB(255, 230, 120))
		more.LayoutOrder = 99
	end
	lootFrame.Parent = gui
	gui.Parent = model
	return gui
end

local function updateBillboard(state)
	local gui = state.model:FindFirstChild("EnemyUI")
	if not gui then
		return
	end
	local bar = gui:FindFirstChild("Bar")
	local frac = math.clamp(state.hp / state.def.Hp, 0, 1)
	bar.Fill.Size = UDim2.fromScale(frac, 1)
	bar.HpText.Text = "[" .. Format.Number(math.ceil(state.hp)) .. " / " .. Format.Number(state.def.Hp) .. "]"
end

local function spawnEnemy(def, cframe, world)
	local model = Rig.BuildEnemy(def)
	nextId += 1
	model.Name = def.Name
	local root = model.PrimaryPart
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = p == root
		end
	end
	local _, size = model:GetBoundingBox()
	cframe = cframe * CFrame.new(0, model:GetAttribute("HipHeight") or 2, 0)
	model:PivotTo(cframe)
	model:SetAttribute("EnemyId", def.Id)
	model:SetAttribute("Uid", nextId)
	model:SetAttribute("World", world.Id)
	model:SetAttribute("MaxHp", def.Hp)
	model:SetAttribute("Hp", def.Hp)
	model:SetAttribute("Alive", true)
	model:SetAttribute("Boss", def.Boss == true)
	model:SetAttribute("Radius", math.max(size.X, size.Z) / 2)
	model:SetAttribute("Height", size.Y)
	buildBillboard(model, def, size.Y - (model:GetAttribute("HipHeight") or 2))
	model.Parent = enemyFolder
	CollectionService:AddTag(model, "Enemy")
	CollectionService:AddTag(model, "AnimeRig")

	local state = { model = model, def = def, hp = def.Hp, home = cframe, world = world, damage = {}, lastHit = 0 }
	active[model] = state
	updateBillboard(state)
	return state
end

function EnemyService.Get(model)
	return active[model]
end

function EnemyService.IsAlive(model)
	local state = active[model]
	return state ~= nil and state.hp > 0
end

-- Applies damage from a player. Returns damage actually dealt and whether the enemy died.
function EnemyService.Damage(model, player, amount)
	local state = active[model]
	if not state or state.hp <= 0 or amount <= 0 then
		return 0, false
	end
	local dealt = math.min(amount, state.hp)
	state.hp -= dealt
	state.lastHit = os.clock()
	state.damage[player] = (state.damage[player] or 0) + dealt
	model:SetAttribute("Hp", state.hp)
	updateBillboard(state)
	if state.hp <= 0 then
		model:SetAttribute("Alive", false)
		local contributors = state.damage
		state.damage = {}
		killedEvent:Fire(model, state.def, contributors)
		task.delay(1.2, function()
			if model.Parent then
				model.Parent = nil
			end
			task.wait(state.def.Respawn or 5)
			state.hp = state.def.Hp
			model:SetAttribute("Hp", state.hp)
			model:SetAttribute("Alive", true)
			updateBillboard(state)
			model:PivotTo(state.home)
			model.Parent = enemyFolder
		end)
		return dealt, true
	end
	return dealt, false
end

-- Enemies regenerate if nobody hits them for a while.
local function regenLoop()
	while true do
		task.wait(2)
		local now = os.clock()
		for _, state in pairs(active) do
			if state.hp > 0 and state.hp < state.def.Hp and now - state.lastHit > Game.EnemyResetTime then
				state.hp = state.def.Hp
				state.damage = {}
				state.model:SetAttribute("Hp", state.hp)
				updateBillboard(state)
			end
		end
	end
end

-- Spawn points come from the WorldBuilder (tagged parts) so enemies stand on real ground.
function EnemyService.SpawnAll(spawnPoints)
	enemyFolder = workspace:WaitForChild("Enemies")
	for _, point in ipairs(spawnPoints) do
		local def = Enemies.ById[point.EnemyId]
		local world = Worlds.ById[point.World]
		if def and world then
			spawnEnemy(def, point.CFrame, world)
		end
	end
end

function EnemyService.Init() end

function EnemyService.Start()
	task.spawn(regenLoop)
end

return EnemyService
