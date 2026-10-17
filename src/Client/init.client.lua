-- Client entry point: HUD, roll animation, inventory, turret placement and shot effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net).waitClient()

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local state = { cash = 0, rolls = 0, inventory = {}, wave = 0, health = 0, maxHealth = 100, rollCooldown = 1 }
local placing = nil -- turret id currently being placed
local ghost = nil
local rolling = false

------------------------------------------------------------------ UI helpers

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	for k, v in pairs(props) do
		l[k] = v
	end
	stroke(l, Color3.fromRGB(20, 20, 40), 2)
	l.Parent = parent
	return l
end

------------------------------------------------------------------ HUD

local gui = Instance.new("ScreenGui")
gui.Name = "BalloonHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local topBar = Instance.new("Frame")
topBar.Size = UDim2.fromOffset(440, 54)
topBar.Position = UDim2.new(0.5, -220, 0, 10)
topBar.BackgroundColor3 = Color3.fromRGB(25, 30, 60)
topBar.BackgroundTransparency = 0.25
topBar.Parent = gui
corner(topBar, 12)

local waveLabel = label(topBar, { Size = UDim2.new(0.3, 0, 1, -12), Position = UDim2.fromOffset(10, 6), Text = "Wave 0" })
local cashLabel = label(topBar, {
	Size = UDim2.new(0.33, 0, 1, -12),
	Position = UDim2.new(0.33, 0, 0, 6),
	Text = "$0",
	TextColor3 = Color3.fromRGB(120, 255, 140),
})

local healthBack = Instance.new("Frame")
healthBack.Size = UDim2.new(0.3, 0, 0, 22)
healthBack.Position = UDim2.new(0.68, 0, 0.5, -11)
healthBack.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
healthBack.Parent = topBar
corner(healthBack, 8)
local healthFill = Instance.new("Frame")
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
healthFill.Parent = healthBack
corner(healthFill, 8)
local healthText = label(healthBack, { Size = UDim2.fromScale(1, 1), Text = "100", ZIndex = 2 })

-- Roll button (the dice)
local rollButton = Instance.new("TextButton")
rollButton.Size = UDim2.fromOffset(110, 110)
rollButton.Position = UDim2.new(0.5, -55, 1, -130)
rollButton.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
rollButton.Text = ""
rollButton.AutoButtonColor = false
rollButton.Parent = gui
corner(rollButton, 22)
stroke(rollButton, Color3.fromRGB(40, 40, 70), 4)

label(rollButton, { Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.fromScale(0, 0.08), Text = "🎲", TextStrokeTransparency = 1 })
local rollText = label(rollButton, {
	Size = UDim2.new(1, -10, 0.28, 0),
	Position = UDim2.new(0, 5, 0.68, 0),
	Text = "ROLL",
	TextColor3 = Color3.fromRGB(40, 40, 70),
})

local cooldownShade = Instance.new("Frame")
cooldownShade.Size = UDim2.fromScale(1, 0)
cooldownShade.AnchorPoint = Vector2.new(0, 1)
cooldownShade.Position = UDim2.fromScale(0, 1)
cooldownShade.BackgroundColor3 = Color3.new(0, 0, 0)
cooldownShade.BackgroundTransparency = 0.55
cooldownShade.ZIndex = 3
cooldownShade.Parent = rollButton
corner(cooldownShade, 22)

local rollsLabel = label(gui, {
	Size = UDim2.fromOffset(160, 22),
	Position = UDim2.new(0.5, -80, 1, -156),
	Text = "Rolls: 0",
	Font = Enum.Font.GothamBold,
})

-- Big roll reveal in the middle of the screen
local reveal = Instance.new("Frame")
reveal.Size = UDim2.fromOffset(320, 150)
reveal.Position = UDim2.new(0.5, -160, 0.42, -75)
reveal.BackgroundTransparency = 1
reveal.Visible = false
reveal.Parent = gui
local revealChance = label(reveal, { Size = UDim2.new(1, 0, 0.45, 0), Text = "1 in 2" })
local revealName = label(reveal, { Size = UDim2.new(1, 0, 0.35, 0), Position = UDim2.fromScale(0, 0.5), Text = "" })

-- Inventory (right side)
local inventoryFrame = Instance.new("Frame")
inventoryFrame.Size = UDim2.fromOffset(230, 320)
inventoryFrame.Position = UDim2.new(1, -244, 0.5, -160)
inventoryFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 60)
inventoryFrame.BackgroundTransparency = 0.25
inventoryFrame.Parent = gui
corner(inventoryFrame, 12)
label(inventoryFrame, { Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 6), Text = "Turrets" })

local list = Instance.new("Frame")
list.Size = UDim2.new(1, -20, 1, -48)
list.Position = UDim2.fromOffset(10, 40)
list.BackgroundTransparency = 1
list.Parent = inventoryFrame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local hint = label(gui, {
	Size = UDim2.fromOffset(520, 26),
	Position = UDim2.new(0.5, -260, 1, -190),
	Text = "",
	Font = Enum.Font.GothamBold,
	Visible = false,
})

local toast = label(gui, {
	Size = UDim2.fromOffset(600, 44),
	Position = UDim2.new(0.5, -300, 0, 76),
	Text = "",
	TextTransparency = 1,
})
toast:FindFirstChildOfClass("UIStroke").Transparency = 1

local function showToast(text: string, color: Color3?)
	toast.Text = text
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	local s = toast:FindFirstChildOfClass("UIStroke")
	toast.TextTransparency, s.Transparency = 0, 0
	task.delay(2.2, function()
		if toast.Text == text then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
end

------------------------------------------------------------------ Placement

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	placing = nil
	hint.Visible = false
end

local function startPlacing(turretId: string)
	clearGhost()
	local def = Config.Turrets[turretId]
	placing = turretId

	ghost = Instance.new("Model")
	ghost.Name = "PlacementGhost"
	local disc = Instance.new("Part")
	disc.Name = "Range"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.2, def.range * 2, def.range * 2)
	disc.Transparency = 0.8
	disc.Material = Enum.Material.Neon
	disc.Anchored, disc.CanCollide, disc.CanQuery = true, false, false
	disc.Parent = ghost
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4, 5, 4)
	body.Color = def.color
	body.Transparency = 0.4
	body.Anchored, body.CanCollide, body.CanQuery = true, false, false
	body.Parent = ghost
	ghost.Parent = workspace

	hint.Text = "Click to place " .. def.name .. "  •  Right-click / Q to cancel"
	hint.Visible = true
end

local function groundHit()
	local ground = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ground")
	if not ground then
		return nil
	end
	local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ground }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return result and result.Position
end

local function localPlacementValid(position: Vector3): boolean
	local turrets = workspace:FindFirstChild("Turrets")
	if turrets then
		for _, model in ipairs(turrets:GetChildren()) do
			local base = model.PrimaryPart
			if base and (Vector3.new(base.Position.X, 0, base.Position.Z) - position).Magnitude < Config.Placement.minSpacing then
				return false
			end
		end
	end
	local path = workspace.Map:FindFirstChild("Path")
	if path then
		for _, seg in ipairs(path:GetChildren()) do
			local rel = seg.CFrame:PointToObjectSpace(position)
			if math.abs(rel.X) < Config.Placement.pathClearance and math.abs(rel.Z) < seg.Size.Z / 2 then
				return false
			end
		end
	end
	return true
end

RunService.RenderStepped:Connect(function()
	if not ghost then
		return
	end
	local pos = groundHit()
	if not pos then
		return
	end
	pos = Vector3.new(pos.X, 0, pos.Z)
	local valid = localPlacementValid(pos)
	local color = valid and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 70, 70)
	ghost.Range.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ghost.Range.Color = color
	ghost.Body.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
end)

local function tryPlace()
	local pos = groundHit()
	if not (placing and pos) then
		return
	end
	local turretId = placing
	local ok, reason = Net.funcs.Place:InvokeServer(turretId, pos)
	if ok then
		if (state.inventory[turretId] or 0) <= 0 then
			clearGhost()
		end
	elseif reason then
		showToast(reason, Color3.fromRGB(255, 120, 120))
	end
end

local function tryPickUp()
	local target = mouse.Target
	local model = target and target:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("Owner") == player.UserId then
		Net.funcs.Sell:InvokeServer(model:GetAttribute("TurretId"))
	end
end

------------------------------------------------------------------ Inventory list

local function rebuildInventory()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for order, id in ipairs(Config.TurretOrder) do
		local count = state.inventory[id]
		if count and count > 0 then
			local def = Config.Turrets[id]
			local b = Instance.new("TextButton")
			b.LayoutOrder = order
			b.Size = UDim2.new(1, 0, 0, 38)
			b.BackgroundColor3 = def.color
			b.Text = ""
			b.Parent = list
			corner(b, 8)
			label(b, {
				Size = UDim2.new(0.72, -8, 1, -8),
				Position = UDim2.fromOffset(8, 4),
				Text = string.format("%s (1 in %d)", def.name, def.oneIn),
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Enum.Font.GothamBold,
			})
			label(b, { Size = UDim2.new(0.25, 0, 1, -8), Position = UDim2.new(0.73, 0, 0, 4), Text = "x" .. count })
			b.MouseButton1Click:Connect(function()
				startPlacing(id)
			end)
		end
	end
	if placing and (state.inventory[placing] or 0) <= 0 then
		clearGhost()
	end
end

------------------------------------------------------------------ Rolling

local function playReveal(turretId: string)
	local entries = {}
	for _, id in ipairs(Config.TurretOrder) do
		table.insert(entries, id)
	end

	reveal.Visible = true
	-- Spin through random results, slowing down, then land on the real one.
	for i = 1, 12 do
		local id = entries[math.random(#entries)]
		local def = Config.Turrets[id]
		revealChance.Text = "1 in " .. def.oneIn
		revealName.Text = def.name
		revealName.TextColor3 = def.color
		task.wait(0.03 + i * 0.012)
	end
	local def = Config.Turrets[turretId]
	revealChance.Text = "1 in " .. def.oneIn
	revealName.Text = def.name
	revealName.TextColor3 = def.color
	reveal.Size = UDim2.fromOffset(380, 180)
	reveal.Position = UDim2.new(0.5, -190, 0.42, -90)
	TweenService:Create(reveal, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		Size = UDim2.fromOffset(320, 150),
		Position = UDim2.new(0.5, -160, 0.42, -75),
	}):Play()

	if def.oneIn >= 10 then
		showToast(string.format("RARE! %s (1 in %d)", def.name, def.oneIn), def.color)
	end
	task.delay(1.2, function()
		reveal.Visible = false
	end)
end

local function roll()
	if rolling then
		return
	end
	rolling = true
	local turretId = Net.funcs.Roll:InvokeServer()
	if turretId then
		cooldownShade.Size = UDim2.fromScale(1, 1)
		TweenService:Create(cooldownShade, TweenInfo.new(state.rollCooldown, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(1, 0),
		}):Play()
		playReveal(turretId)
	end
	rolling = false
end

rollButton.MouseButton1Click:Connect(roll)

------------------------------------------------------------------ Input

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if placing then
			tryPlace()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if placing then
			clearGhost()
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		clearGhost()
	elseif input.KeyCode == Enum.KeyCode.R then
		roll()
	elseif input.KeyCode == Enum.KeyCode.E and not placing then
		tryPickUp()
	end
end)

------------------------------------------------------------------ Network

Net.events.StateChanged.OnClientEvent:Connect(function(newState)
	state = newState
	waveLabel.Text = "Wave " .. state.wave
	cashLabel.Text = "$" .. state.cash
	rollsLabel.Text = "Rolls: " .. state.rolls
	healthText.Text = tostring(state.health)
	TweenService:Create(healthFill, TweenInfo.new(0.25), {
		Size = UDim2.fromScale(math.clamp(state.health / state.maxHealth, 0, 1), 1),
	}):Play()
	rebuildInventory()
end)

Net.events.Notify.OnClientEvent:Connect(function(text)
	showToast(text)
end)

Net.events.FireBeam.OnClientEvent:Connect(function(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CastShadow = true, false, false, false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(0.25, 0.25, length)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(0.12), { Transparency = 1, Size = Vector3.new(0.05, 0.05, length) }):Play()
	Debris:AddItem(beam, 0.15)
end)

hint.Text = "R — roll  •  click a turret to place  •  E on your turret — pick up"
hint.Visible = true
task.delay(6, function()
	if not placing then
		hint.Visible = false
	end
end)
