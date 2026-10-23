-- Animates HatchUI: popup open/close with a pop, rotating rays behind popups,
-- button hover/press, countdown timers, wheel spin, toast notifications,
-- settings slider/toggle. Layout lives in HUD / Popups (plain instances).

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local gui = script.Parent
local hud = gui:WaitForChild("HUD")
local popups = gui:WaitForChild("Popups")
local rays = popups:WaitForChild("Rays")
local toast = hud:WaitForChild("Toast")
local camera = workspace.CurrentCamera

local REF = Vector2.new(1280, 720)

----------------------------------------------------------------------
-- Responsive scale
----------------------------------------------------------------------
local function fitScale()
	local v = camera.ViewportSize
	local s = math.clamp(math.min(v.X / REF.X, v.Y / REF.Y), 0.6, 1.6)
	hud.Scale.Scale = s
	popups.Scale.Scale = s
end
fitScale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)

----------------------------------------------------------------------
-- Tweens
----------------------------------------------------------------------
local POP_IN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

----------------------------------------------------------------------
-- Toast
----------------------------------------------------------------------
local toastToken = 0
local function showToast(text)
	toastToken += 1
	local token = toastToken
	toast.Text.Text = "✅ " .. text
	toast.Visible = true
	toast.Position = UDim2.new(0.5, 0, 1, -40)
	toast.BackgroundTransparency = 1
	toast.Text.TextTransparency = 1
	tween(toast, POP_IN, { Position = UDim2.new(0.5, 0, 1, -70), BackgroundTransparency = 0 })
	tween(toast.Text, POP_IN, { TextTransparency = 0 })
	task.delay(2.2, function()
		if token ~= toastToken then return end
		tween(toast, POP_OUT, { Position = UDim2.new(0.5, 0, 1, -40), BackgroundTransparency = 1 })
		tween(toast.Text, POP_OUT, { TextTransparency = 1 }).Completed:Wait()
		if token == toastToken then toast.Visible = false end
	end)
end

----------------------------------------------------------------------
-- Popups
----------------------------------------------------------------------
local current = nil
local raysConn = nil

local function startRays()
	rays.Visible = true
	if raysConn then return end
	raysConn = RunService.RenderStepped:Connect(function(dt)
		for _, r in ipairs(rays:GetChildren()) do
			if r:IsA("Frame") then
				r.Rotation += dt * 12
			end
		end
	end)
end

local function stopRays()
	rays.Visible = false
	if raysConn then
		raysConn:Disconnect()
		raysConn = nil
	end
end

local function closePopup(p)
	p = p or current
	if not p then return end
	local sc = p:FindFirstChild("Pop")
	if sc then
		tween(sc, POP_OUT, { Scale = 0.7 }).Completed:Wait()
	end
	p.Visible = false
	if current == p then
		current = nil
		stopRays()
	end
end

local function openPopup(name)
	local p = popups:FindFirstChild(name)
	if not p then return end
	if current == p then
		closePopup(p)
		return
	end
	if current then
		local prev = current
		current = nil
		prev.Visible = false
	end
	current = p
	startRays()
	p.Visible = true
	local sc = p:FindFirstChild("Pop")
	if sc then
		sc.Scale = 0.6
		tween(sc, POP_IN, { Scale = 1 })
	end
end

----------------------------------------------------------------------
-- Button feel (every TextButton with a UIScale named Hover)
----------------------------------------------------------------------
local function wireButton(btn)
	local sc = btn:FindFirstChild("Hover")
	if not sc then return end
	btn.MouseEnter:Connect(function() tween(sc, HOVER, { Scale = 1.08 }) end)
	btn.MouseLeave:Connect(function() tween(sc, HOVER, { Scale = 1 }) end)
	btn.MouseButton1Down:Connect(function() tween(sc, HOVER, { Scale = 0.94 }) end)
	btn.MouseButton1Up:Connect(function() tween(sc, HOVER, { Scale = 1.08 }) end)
end
for _, d in ipairs(gui:GetDescendants()) do
	if d:IsA("TextButton") then wireButton(d) end
end
gui.DescendantAdded:Connect(function(d)
	if d:IsA("TextButton") then wireButton(d) end
end)

-- HUD buttons -> popups
local opens = {
	[hud.LeftButtons.Shop] = "Shop",
	[hud.LeftButtons.Index] = "Index",
}
for _, name in ipairs({ "Daily", "Spin", "Pass", "Eggs", "Playtime", "Pets", "Quests", "Settings" }) do
	local map = { Daily = "DailyRewards", Spin = "SpinWheel", Playtime = "PlaytimeRewards", Quests = "DailyQuests" }
	opens[hud.RightMenu[name]] = map[name] or name
end
for btn, popupName in pairs(opens) do
	btn.MouseButton1Click:Connect(function()
		openPopup(popupName)
		local badge = btn:FindFirstChild("Badge")
		if badge then badge.Visible = false end
	end)
end

-- Close buttons, Claim/Skip
for _, p in ipairs(popups:GetChildren()) do
	if not p:IsA("Frame") or p == rays then continue end
	local close = p:FindFirstChild("Close", true)
	if close then
		close.MouseButton1Click:Connect(function() closePopup(p) end)
	end
	for _, b in ipairs(p:GetDescendants()) do
		if b:IsA("TextButton") and (b.Name == "ClaimAll" or b.Name == "SkipAll") then
			b.MouseButton1Click:Connect(function()
				showToast((b.Name == "ClaimAll" and "Claim All " or "Skip All ") .. p.Name .. " !")
				closePopup(p)
			end)
		elseif b:IsA("TextButton") and (b.Name == "Claim" or b.Name == "Skip") then
			b.MouseButton1Click:Connect(function()
				showToast((b.Name == "Claim" and "Reward claimed" or "Quest skipped") .. " !")
			end)
		end
	end
end

-- Escape closes
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Escape and current then closePopup() end
end)

----------------------------------------------------------------------
-- Badges: show on Daily / Spin / Quests at start with a pulse
----------------------------------------------------------------------
for _, name in ipairs({ "Daily", "Spin", "Quests" }) do
	local badge = hud.RightMenu[name]:FindFirstChild("Badge")
	if badge then badge.Visible = true end
end
task.spawn(function()
	while true do
		for _, name in ipairs({ "Daily", "Spin", "Quests" }) do
			local badge = hud.RightMenu[name]:FindFirstChild("Badge")
			if badge and badge.Visible then
				tween(badge, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), { Size = UDim2.fromOffset(22, 22) })
			end
		end
		task.wait(1.6)
	end
end)

----------------------------------------------------------------------
-- Countdowns: Spin caption, Playtime caption, potions
----------------------------------------------------------------------
local function fmt(sec)
	if sec >= 3600 then
		return string.format("%d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
	end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local timers = {
	{ label = hud.RightMenu.Spin.Caption, seconds = 3 * 3600 + 59 * 60 + 59, done = "SPIN" },
	{ label = hud.RightMenu.Playtime.Caption, seconds = 2 * 60 + 58, done = "PLAYTIME" },
	{ label = hud.Potions.Lucky.Timer, seconds = 29 * 60 + 9, done = "" },
	{ label = hud.Potions.Cash.Timer, seconds = 29 * 60 + 8, done = "" },
}
task.spawn(function()
	while true do
		for _, t in ipairs(timers) do
			if t.seconds > 0 then
				t.label.Text = fmt(t.seconds)
				t.seconds -= 1
			else
				t.label.Text = t.done
			end
		end
		task.wait(1)
	end
end)

----------------------------------------------------------------------
-- Spin wheel
----------------------------------------------------------------------
local spin = popups.SpinWheel
local wheel = spin.Wheel
local spinning = false
local PRIZES = { "Cursed Egg", "Gold Lion", "x2 Cash 30m", "Speed 15m", "$10K", "Fast Hatch", "Pumpkin Egg", "Treadmill 30m" }
local fast = false

spin.FastSpin.Box.MouseEnter:Connect(function() end)
spin.FastSpin.Box.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		fast = not fast
		spin.FastSpin.Box.BackgroundColor3 = fast and Color3.fromRGB(90, 220, 110) or Color3.fromRGB(40, 45, 70)
	end
end)

spin.SpinButton.MouseButton1Click:Connect(function()
	if spinning then return end
	spinning = true
	local idx = math.random(1, #PRIZES)
	-- segment i sits at (i-1)*45 - 90 deg; the pointer is at -90 deg, so rotate
	-- the wheel so that segment lands under the pointer
	local target = -((idx - 1) * 45)
	local turns = fast and 3 or 6
	local goal = wheel.Rotation - (wheel.Rotation % 360) + 360 * turns + target
	tween(wheel, TweenInfo.new(fast and 1.4 or 4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = goal }).Completed:Wait()
	showToast("Obtenu : " .. PRIZES[idx] .. " !")
	spinning = false
end)

----------------------------------------------------------------------
-- Settings: slider drag, toggle
----------------------------------------------------------------------
local settings = popups.Settings.Body
local slider = settings.Music.Slider
local dragging = false
local function setSlider(x)
	local a = math.clamp((x - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
	slider.Fill.Size = UDim2.new(a, 0, 1, 0)
	slider.Knob.Position = UDim2.new(a, 0, 0.5, 0)
end
slider.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		setSlider(input.Position.X)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		setSlider(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local toggle = settings.Sound.Toggle
local soundOn = true
toggle.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	soundOn = not soundOn
	tween(toggle, HOVER, { BackgroundColor3 = soundOn and Color3.fromRGB(70, 200, 80) or Color3.fromRGB(120, 120, 140) })
	tween(toggle.Knob, HOVER, { Position = soundOn and UDim2.new(1, -2, 0.5, 0) or UDim2.new(0, 24, 0.5, 0) })
	toggle.State.Text = soundOn and "ON" or "OFF"
end)

----------------------------------------------------------------------
-- Player strip
----------------------------------------------------------------------
hud.PlayerStrip.Name.Text = Players.LocalPlayer.DisplayName
