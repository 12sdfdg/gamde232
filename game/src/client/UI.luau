-- All on-screen UI, built in code: HUD, roll reel, turret inventory,
-- upgrades (skill tree), index and toasts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Effects = require(script.Parent.Effects)
local Placement = require(script.Parent.Placement)

local player = Players.LocalPlayer

local UI = {}

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local BLUE = Color3.fromRGB(45, 120, 235)
local GREEN = Color3.fromRGB(70, 200, 80)
local RED = Color3.fromRGB(230, 60, 60)
local PANEL = Color3.fromRGB(35, 95, 200)

local remotes: any
local state: any
local gui: ScreenGui
local refs: { [string]: any } = {}

---------------------------------------------------------------------- helpers
local function create(className: string, props: { [string]: any }?, children: { Instance }?)
	local inst = Instance.new(className)
	local p: { [string]: any } = props or {}
	local kids: { Instance } = children or {}
	for k, v in p do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, c in kids do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r: number?)
	return create("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

local function stroke(thick: number?, color: Color3?)
	return create("UIStroke", { Thickness = thick or 3, Color = color or Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function textStroke(thick: number?)
	return create("UIStroke", { Thickness = thick or 2.5, Color = Color3.new(0, 0, 0) })
end

local function gradient(top: Color3, bottom: Color3)
	return create("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return create("TextLabel", props, { textStroke() })
end

local function button(props, color: Color3, onClick: () -> ())
	props.BackgroundColor3 = color
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	props.AutoButtonColor = true
	local b = create("TextButton", props, {
		corner(14),
		stroke(3),
		gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		create("UITextSizeConstraint", { MaxTextSize = 34 }),
		create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	}) :: TextButton
	b.MouseButton1Click:Connect(function()
		Effects.Play("Click")
		local scale = b:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = b })
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onClick()
	end)
	return b
end

local function remote(name: string): any
	return remotes:FindFirstChild(name)
end

---------------------------------------------------------------------- toasts
function UI.Toast(text: string, color: Color3?)
	local holder = refs.toasts
	if not holder then
		return
	end
	local t = label({
		Size = UDim2.new(1, 0, 0, 34),
		Text = text,
		TextColor3 = color or WHITE,
		TextTransparency = 1,
		Parent = holder,
	})
	TweenService:Create(t, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	task.delay(3.5, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		t:Destroy()
	end)
	local children = holder:GetChildren()
	local labels = 0
	for _, c in children do
		if c:IsA("TextLabel") then
			labels += 1
		end
	end
	if labels > 5 then
		for _, c in children do
			if c:IsA("TextLabel") then
				c:Destroy()
				break
			end
		end
	end
end

---------------------------------------------------------------------- panels
local panels: { [string]: Frame } = {}

local function closeAll(except: string?)
	for name, p in panels do
		if name ~= except then
			p.Visible = false
		end
	end
end

local function makePanel(name: string, title: string, size: UDim2, position: UDim2, anchor: Vector2)
	local frame = create("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = PANEL,
		Visible = false,
		Parent = gui,
	}, { corner(18), stroke(4), gradient(Color3.fromRGB(120, 190, 255), Color3.fromRGB(200, 200, 230)) }) :: Frame
	label({ Size = UDim2.new(1, -70, 0, 44), Position = UDim2.fromOffset(16, 8), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	button({ Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -52, 0, 8), Text = "X" }, RED, function()
		frame.Visible = false
	end).Parent = frame
	local scroll = create("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, -24, 1, -70),
		Position = UDim2.fromOffset(12, 60),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	})
	panels[name] = frame
	return frame, scroll
end

local function toggle(name: string)
	local p = panels[name]
	local show = not p.Visible
	closeAll()
	p.Visible = show
	if show then
		UI.Refresh()
	end
end

---------------------------------------------------------------------- inventory
local function availableCount(id: string): number
	local owned = state.data and state.data.inventory[id] or 0
	return owned - Placement.PlacedCount(id)
end

local function rebuildTurrets()
	local list = refs.turretList
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if not state.data then
		return
	end
	for i = #Config.Turrets, 1, -1 do
		local def = Config.Turrets[i]
		local owned = state.data.inventory[def.id] or 0
		if owned > 0 then
			local free = availableCount(def.id)
			local card = button({
				Name = def.id,
				Size = UDim2.fromOffset(120, 120),
				Text = "",
				LayoutOrder = -def.chance,
			}, Config.RarityColors[def.rarity]:Lerp(Color3.new(0.2, 0.2, 0.3), 0.35), function()
				if availableCount(def.id) > 0 then
					closeAll()
					Placement.Start(def.id)
				else
					UI.Toast("All your " .. def.name .. "s are placed", RED)
				end
			end)
			label({ Size = UDim2.new(1, 0, 0.42, 0), Position = UDim2.fromScale(0, 0.04), Text = def.name, Parent = card })
			label({ Size = UDim2.new(1, 0, 0.22, 0), Position = UDim2.fromScale(0, 0.48), Text = string.format("x%d free", free), TextColor3 = if free > 0 then Color3.fromRGB(180, 255, 180) else Color3.fromRGB(255, 160, 160), Parent = card })
			label({ Size = UDim2.new(1, 0, 0.2, 0), Position = UDim2.fromScale(0, 0.74), Text = Util.ChanceText(def.chance), TextColor3 = Config.RarityColors[def.rarity], Parent = card })
			card.Parent = list
		end
	end
	local stats = state.stats
	refs.slots.Text = string.format("Placed %d / %d", Placement.TotalPlaced(), stats and stats.maxTurrets or Config.BaseMaxTurrets)
end

---------------------------------------------------------------------- upgrades
local function rebuildUpgrades()
	local list = refs.upgradeList
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if not state.data then
		return
	end
	local owned = state.data.upgrades
	for i, up in Config.Upgrades do
		local has = owned[up.id] == true
		local locked = up.requires ~= nil and not owned[up.requires]
		local affordable = state.data.coins >= up.cost
		local color = if has then GREEN elseif locked then Color3.fromRGB(110, 110, 120) elseif affordable then BLUE else Color3.fromRGB(70, 90, 140)
		local card = button({ Name = up.id, Size = UDim2.fromOffset(150, 150), Text = "", LayoutOrder = i }, color, function()
			if has or locked then
				return
			end
			local ok, reason = remote("BuyUpgrade"):InvokeServer(up.id)
			if ok then
				Effects.Play("Buy")
				UI.Toast("Unlocked " .. up.name .. "!", Color3.fromRGB(150, 255, 150))
			else
				UI.Toast(reason or "Can't buy", RED)
			end
		end)
		label({ Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.02), Text = up.icon, Parent = card })
		label({ Size = UDim2.new(1, 0, 0.2, 0), Position = UDim2.fromScale(0, 0.33), Text = up.name, Parent = card })
		label({ Size = UDim2.new(1, 0, 0.16, 0), Position = UDim2.fromScale(0, 0.55), Text = up.desc, TextColor3 = Color3.fromRGB(230, 240, 255), Parent = card })
		local bottom = if has then "OWNED" elseif locked then ("🔒 " .. Config.Get(up.requires).name) else ("$" .. Util.Abbrev(up.cost))
		label({ Size = UDim2.new(1, 0, 0.2, 0), Position = UDim2.fromScale(0, 0.76), Text = bottom, TextColor3 = if has then WHITE else Color3.fromRGB(255, 225, 80), Parent = card })
		card.Parent = list
	end
end

---------------------------------------------------------------------- index
local function rebuildIndex()
	local list = refs.indexList
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if not state.data then
		return
	end
	local found = 0
	for i, def in Config.Turrets do
		local known = state.data.discovered[def.id] == true
		if known then
			found += 1
		end
		local card = create("Frame", {
			Size = UDim2.fromOffset(150, 150),
			LayoutOrder = i,
			BackgroundColor3 = if known then Config.RarityColors[def.rarity]:Lerp(Color3.new(0.15, 0.15, 0.25), 0.4) else Color3.fromRGB(60, 60, 70),
			Parent = list,
		}, { corner(14), stroke(3) })
		label({ Size = UDim2.new(1, 0, 0.24, 0), Position = UDim2.fromScale(0, 0.04), Text = if known then def.name else "???", Parent = card })
		label({ Size = UDim2.new(1, 0, 0.17, 0), Position = UDim2.fromScale(0, 0.3), Text = def.rarity, TextColor3 = Config.RarityColors[def.rarity], Parent = card })
		label({
			Size = UDim2.new(1, -8, 0.3, 0),
			Position = UDim2.fromScale(0, 0.48),
			Text = if known then string.format("DMG %s  RNG %d\n%.1f shots/s%s", Util.Abbrev(def.damage), def.range, def.fireRate, if def.splash then "  SPLASH" else "") else "Not discovered",
			TextColor3 = Color3.fromRGB(230, 235, 255),
			Parent = card,
		})
		label({ Size = UDim2.new(1, 0, 0.17, 0), Position = UDim2.fromScale(0, 0.8), Text = Util.ChanceText(def.chance), TextColor3 = Color3.fromRGB(255, 225, 80), Parent = card })
	end
	refs.indexTitle.Text = string.format("Index  %d / %d", found, #Config.Turrets)
end

---------------------------------------------------------------------- roll reel
local rolling = false
local autoRoll = false
local reelToken = 0

local function setReelLine(lbl: TextLabel, def)
	lbl.Text = def.name .. "   " .. Util.ChanceText(def.chance)
	lbl.TextColor3 = Config.RarityColors[def.rarity]
end

local function animateReel(resultId: string?, duration: number)
	reelToken += 1
	local token = reelToken
	local reel = refs.reel
	reel.Visible = true
	local luck = state.stats and state.stats.luck or 1
	local lines = { reel.Top, reel.Mid, reel.Bot }
	local seq = {}
	for i = 1, 3 do
		seq[i] = Util.RollFrom(Config.Turrets, luck)
	end
	local elapsed = 0
	local interval = 0.04
	while elapsed < duration do
		table.remove(seq, 1)
		table.insert(seq, Util.RollFrom(Config.Turrets, luck * 3))
		for i = 1, 3 do
			setReelLine(lines[i], seq[i])
		end
		Effects.Play("Roll", nil, 1.4)
		task.wait(interval)
		elapsed += interval
		interval = math.min(interval * 1.15, 0.22)
	end
	if resultId then
		local def = Config.Get(resultId)
		setReelLine(reel.Mid, def)
		reel.Top.Text = ""
		reel.Bot.Text = ""
		local scale = reel.Mid:FindFirstChildOfClass("UIScale")
		scale.Scale = 1.5
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if def.chance >= Config.RareAnnounceChance then
			Effects.Play("RareRoll")
			local flash = refs.flash
			flash.BackgroundColor3 = Config.RarityColors[def.rarity]
			flash.BackgroundTransparency = 0.3
			TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		end
	end
	task.delay(1.6, function()
		if reelToken == token then
			reel.Visible = false
		end
	end)
end

local function doRoll()
	if rolling then
		return
	end
	rolling = true
	local cooldown = state.stats and state.stats.rollCooldown or Config.RollCooldown
	local result = nil
	local done = false
	task.spawn(function()
		result = remote("Roll"):InvokeServer()
		done = true
	end)
	-- cooldown bar
	local fill = refs.rollFill
	fill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(fill, TweenInfo.new(cooldown, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	local spin = math.min(cooldown * 0.85, 1.4)
	animateReel(nil, spin)
	local waited = 0
	while not done and waited < 5 do
		task.wait(0.05)
		waited += 0.05
	end
	if result then
		animateReel(result.id, 0)
		local def = Config.Get(result.id)
		if result.isNew then
			UI.Toast("NEW! " .. def.name .. " added to your Index", Config.RarityColors[def.rarity])
		end
	end
	task.wait(math.max(0, cooldown - spin))
	rolling = false
end

---------------------------------------------------------------------- build
function UI.Init(remoteFolder: Folder, sharedState)
	remotes = remoteFolder
	state = sharedState
	gui = create("ScreenGui", {
		Name = "PopUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	create("UIScale", { Name = "Scale", Parent = gui })

	refs.flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = gui })

	-- coins
	local coins = create("Frame", {
		Size = UDim2.fromOffset(260, 66),
		Position = UDim2.new(0, 16, 1, -86),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	create("Frame", { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = Color3.fromRGB(255, 200, 40), Parent = coins }, {
		corner(28),
		stroke(3, Color3.fromRGB(150, 100, 10)),
		label({ Size = UDim2.fromScale(1, 1), Text = "$" }),
	})
	refs.coins = label({ Size = UDim2.new(1, -66, 1, 0), Position = UDim2.fromOffset(66, 0), Text = "$0", TextXAlignment = Enum.TextXAlignment.Left, Parent = coins })
	refs.luck = label({ Size = UDim2.fromOffset(260, 26), Position = UDim2.new(0, 16, 1, -116), Text = "🍀 Luck x1", TextXAlignment = Enum.TextXAlignment.Left, Parent = gui })

	-- wave info
	local wave = create("Frame", {
		Size = UDim2.fromOffset(300, 74),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { corner(16), stroke(3) })
	refs.wave = label({ Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.04), Text = "Wave 0", Parent = wave })
	local livesBar = create("Frame", { Size = UDim2.new(0.86, 0, 0.32, 0), Position = UDim2.fromScale(0.07, 0.58), BackgroundColor3 = Color3.fromRGB(60, 20, 20), Parent = wave }, { corner(10), stroke(2) })
	refs.livesFill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(240, 70, 80), Parent = livesBar }, { corner(10) })
	refs.lives = label({ Size = UDim2.fromScale(1, 1), Text = "❤ 20 / 20", ZIndex = 2, Parent = livesBar })

	-- toasts
	refs.toasts = create("Frame", {
		Size = UDim2.new(0.6, 0, 0, 220),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- start button
	refs.start = button({
		Size = UDim2.fromOffset(240, 76),
		Position = UDim2.new(0.5, 0, 1, -200),
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "▶ Start",
		Parent = gui,
	}, GREEN, function()
		remote("StartWaves"):FireServer()
	end)

	-- roll button + cooldown bar
	local rollBtn = button({
		Size = UDim2.fromOffset(240, 84),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "🎲 ROLL",
		Parent = gui,
	}, Color3.fromRGB(255, 170, 30), function()
		task.spawn(doRoll)
	end)
	local barBg = create("Frame", { Size = UDim2.new(1, -20, 0, 8), Position = UDim2.new(0, 10, 1, -14), BackgroundColor3 = Color3.fromRGB(80, 50, 10), ZIndex = 3, Parent = rollBtn }, { corner(4) })
	refs.rollFill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 4, Parent = barBg }, { corner(4) })
	refs.auto = button({
		Size = UDim2.fromOffset(130, 56),
		Position = UDim2.new(0.5, 132, 1, -96),
		Text = "Auto: OFF",
		Visible = false,
		Parent = gui,
	}, Color3.fromRGB(120, 120, 130), function()
		autoRoll = not autoRoll
		refs.auto.Text = if autoRoll then "Auto: ON" else "Auto: OFF"
		refs.auto.BackgroundColor3 = if autoRoll then GREEN else Color3.fromRGB(120, 120, 130)
		if autoRoll then
			task.spawn(function()
				while autoRoll do
					doRoll()
					task.wait(0.05)
				end
			end)
		end
	end)

	-- reel
	local reel = create("Frame", {
		Name = "Reel",
		Size = UDim2.fromOffset(460, 150),
		Position = UDim2.fromScale(0.5, 0.36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	label({ Name = "Top", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 0), TextTransparency = 0.45, Text = "", Parent = reel })
	local mid = label({ Name = "Mid", Size = UDim2.new(1, -120, 0, 56), Position = UDim2.fromOffset(60, 44), Text = "", Parent = reel })
	create("UIScale", { Parent = mid })
	label({ Name = "Bot", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 112), TextTransparency = 0.45, Text = "", Parent = reel })
	label({ Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(0, 47), Text = "➡", TextColor3 = Color3.fromRGB(255, 220, 40), Parent = reel })
	label({ Size = UDim2.fromOffset(50, 50), Position = UDim2.new(1, -50, 0, 47), Text = "⬅", TextColor3 = Color3.fromRGB(255, 220, 40), Parent = reel })
	refs.reel = reel

	-- side menu
	local menu = create("Frame", {
		Size = UDim2.fromOffset(96, 420),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, info in {
		{ "🏰\nTurrets", "Turrets", BLUE },
		{ "⬆\nSkills", "Upgrades", Color3.fromRGB(150, 70, 230) },
		{ "📖\nIndex", "Index", Color3.fromRGB(40, 170, 200) },
	} do
		button({ Size = UDim2.fromOffset(92, 92), Text = info[1], LayoutOrder = i, Parent = menu }, info[3], function()
			toggle(info[2])
		end)
	end
	button({ Size = UDim2.fromOffset(92, 60), Text = "🏠 Home", LayoutOrder = 4, Parent = menu }, Color3.fromRGB(240, 140, 40), function()
		remote("GoHome"):FireServer()
	end)

	-- turrets panel (left, like the reference)
	local tp, tList = makePanel("Turrets", "Turrets", UDim2.fromOffset(300, 460), UDim2.new(0, 124, 0.5, 0), Vector2.new(0, 0.5))
	tList.Size = UDim2.new(1, -24, 1, -170)
	create("UIGridLayout", { CellSize = UDim2.fromOffset(124, 124), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tList })
	refs.turretList = tList
	refs.slots = label({ Size = UDim2.new(1, -24, 0, 26), Position = UDim2.new(0, 12, 1, -104), Text = "", Parent = tp })
	button({ Size = UDim2.new(0.5, -18, 0, 54), Position = UDim2.new(0, 12, 1, -66), Text = "Remove All" }, RED, function()
		Placement.Cancel()
		remote("RemoveAll"):FireServer()
		task.delay(0.3, UI.Refresh)
	end).Parent = tp
	button({ Size = UDim2.new(0.5, -18, 0, 54), Position = UDim2.new(0.5, 6, 1, -66), Text = "Delete" }, Color3.fromRGB(240, 140, 40), function()
		closeAll()
		Placement.SetDeleteMode(not Placement.IsDeleteMode())
	end).Parent = tp

	local _, uList = makePanel("Upgrades", "Skill Tree", UDim2.fromOffset(700, 470), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	create("UIGridLayout", { CellSize = UDim2.fromOffset(152, 152), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = uList })
	refs.upgradeList = uList

	local ip, iList = makePanel("Index", "Index", UDim2.fromOffset(700, 470), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	create("UIGridLayout", { CellSize = UDim2.fromOffset(152, 152), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = iList })
	refs.indexList = iList
	refs.indexTitle = ip:FindFirstChildOfClass("TextLabel")

	-- placement hint
	refs.hint = label({
		Size = UDim2.fromOffset(700, 30),
		Position = UDim2.new(0.5, 0, 1, -240),
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "",
		Visible = false,
		Parent = gui,
	})

	-- scale UI down on small screens
	local camera = workspace.CurrentCamera
	local function rescale()
		local vp = camera.ViewportSize
		local uiScale = gui:FindFirstChild("Scale") :: UIScale
		uiScale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.55, 1.2)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- refresh inventory counts when turrets are added or removed on my plot
	task.spawn(function()
		local plot = nil
		while not plot do
			plot = Placement.MyPlot()
			task.wait(0.5)
		end
		plot.Turrets.ChildAdded:Connect(function()
			task.defer(UI.Refresh)
		end)
		plot.Turrets.ChildRemoved:Connect(function()
			task.defer(UI.Refresh)
		end)
	end)
end

function UI.SetHint(text: string?)
	refs.hint.Text = text or ""
	refs.hint.Visible = text ~= nil
end

function UI.Available(id: string): number
	return availableCount(id)
end

function UI.SetWave(w)
	refs.wave.Text = if w.running then string.format("Wave %d", w.wave) else "Press Start!"
	refs.lives.Text = string.format("❤ %d / %d", math.max(0, w.lives), w.maxLives)
	refs.livesFill.Size = UDim2.fromScale(math.clamp(w.lives / w.maxLives, 0, 1), 1)
	refs.start.Visible = not w.running
end

local shownCoins = 0
local coinTween: Tween? = nil
function UI.Refresh()
	local data = state.data
	if not data then
		return
	end
	-- smooth coin counter
	local target = data.coins
	if coinTween then
		coinTween:Cancel()
	end
	local nv = Instance.new("NumberValue")
	nv.Value = shownCoins
	nv.Changed:Connect(function(v)
		shownCoins = v
		refs.coins.Text = "$" .. Util.Abbrev(v)
	end)
	local tween = TweenService:Create(nv, TweenInfo.new(0.25), { Value = target })
	coinTween = tween
	tween:Play()

	local stats = state.stats
	if stats then
		refs.luck.Text = string.format("🍀 Luck x%s   🎲 %s rolls", string.format("%.4g", stats.luck), Util.Abbrev(data.rolls))
		refs.auto.Visible = stats.autoRoll
	end
	if panels.Turrets.Visible then
		rebuildTurrets()
	end
	if panels.Upgrades.Visible then
		rebuildUpgrades()
	end
	if panels.Index.Visible then
		rebuildIndex()
	end
end

return UI
