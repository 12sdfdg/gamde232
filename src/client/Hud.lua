--!nonstrict
-- Основний HUD: статистика, таймер раунду, меню, кнопка кліку, бусти, сповіщення, підказки.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Store = require(script.Parent.Store)
local UI = require(script.Parent.UI)

local Hud = {}

local refs: { [string]: any } = {}
local notifyHolder: Frame

local NOTIFY_COLORS = {
	info = UI.Colors.PanelLight,
	success = UI.Colors.Green,
	warn = UI.Colors.Orange,
	error = UI.Colors.Red,
}

function Hud.Notify(text: string, kind: string?)
	local toast = UI.label({
		Size = UDim2.fromOffset(420, 40),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = NOTIFY_COLORS[kind or "info"] or UI.Colors.PanelLight,
		Text = text,
		TextScaled = true,
		Parent = notifyHolder,
	})
	UI.corner(10).Parent = toast
	UI.padding(6).Parent = toast
	local scale = UI.new("UIScale", { Scale = 0.4, Parent = toast })
	UI.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		UI.tween(toast, 0.3, { BackgroundTransparency = 1, TextTransparency = 1 })
		task.wait(0.3)
		toast:Destroy()
	end)
end

local function statCard(parent: Instance, order: number, icon: string, color: Color3): (TextLabel, TextLabel)
	local card = UI.new("Frame", {
		Size = UDim2.fromOffset(230, 52),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Parent = parent,
	})
	UI.corner(14).Parent = card
	UI.stroke(color, 2.5).Parent = card
	UI.label({ Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(6, 4), Text = icon, Parent = card })
	local value = UI.label({
		Size = UDim2.new(1, -60, 0, 30),
		Position = UDim2.fromOffset(54, 3),
		Text = "0",
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	local sub = UI.label({
		Size = UDim2.new(1, -60, 0, 16),
		Position = UDim2.fromOffset(54, 33),
		Text = "",
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	return value, sub
end

function Hud.Build(gui: ScreenGui, openPanel: (string) -> (), onClick: () -> (), sendAction: (string, any?, any?) -> ())
	-- Статистика (зліва зверху).
	local stats = UI.new("Frame", {
		Size = UDim2.fromOffset(230, 180),
		Position = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stats })
	refs.speed, refs.speedSub = statCard(stats, 1, "⚡", UI.Colors.Speed)
	refs.wins, refs.winsSub = statCard(stats, 2, "🏆", UI.Colors.Wins)
	refs.rebirths, refs.rebirthsSub = statCard(stats, 3, "🌟", UI.Colors.Rebirth)

	-- Таймер раунду (по центру зверху).
	local timer = UI.new("Frame", {
		Size = UDim2.fromOffset(320, 56),
		Position = UDim2.new(0.5, -160, 0, 10),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	UI.corner(16).Parent = timer
	UI.stroke(Color3.new(0, 0, 0), 3).Parent = timer
	refs.timerText = UI.label({ Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 4), Text = "", Parent = timer })
	local barBack = UI.new("Frame", {
		Size = UDim2.new(1, -24, 0, 8),
		Position = UDim2.new(0, 12, 1, -14),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		Parent = timer,
	})
	UI.corner(4).Parent = barBack
	refs.timerBar = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.Colors.Speed, Parent = barBack })
	UI.corner(4).Parent = refs.timerBar

	-- Сповіщення під таймером.
	notifyHolder = UI.new("Frame", {
		Size = UDim2.fromOffset(420, 200),
		Position = UDim2.new(0.5, -210, 0, 76),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = notifyHolder,
	})

	-- Меню (зліва).
	local menu = UI.new("Frame", {
		Size = UDim2.fromOffset(150, 330),
		Position = UDim2.new(0, 14, 0.5, -110),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(70, 70),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	local menuItems = {
		{ "Pets", "🐾\nPets", Color3.fromRGB(255, 140, 60) },
		{ "Shop", "🛒\nShop", UI.Colors.Robux },
		{ "Rebirth", "🌟\nRebirth", UI.Colors.Rebirth },
		{ "Daily", "📅\nDaily", Color3.fromRGB(70, 160, 255) },
		{ "Gifts", "🎁\nGifts", Color3.fromRGB(255, 80, 130) },
		{ "Codes", "🎟️\nCodes", Color3.fromRGB(90, 200, 200) },
		{ "Invite", "👥\nInvite", Color3.fromRGB(120, 120, 255) },
		{ "Settings", "⚙️\nSettings", Color3.fromRGB(120, 125, 140) },
	}
	refs.menuButtons = {}
	for order, item in menuItems do
		local button = UI.button({ Text = item[2], BackgroundColor3 = item[3], LayoutOrder = order, Parent = menu }, function()
			openPanel(item[1])
		end)
		refs.menuButtons[item[1]] = button
		UI.badge(button)
	end

	-- Велика кнопка кліку (знизу по центру).
	refs.clickButton = UI.button({
		Size = UDim2.fromOffset(240, 84),
		Position = UDim2.new(0.5, -120, 1, -110),
		Text = "⚡ CLICK!",
		BackgroundColor3 = UI.Colors.Speed,
	}, onClick)
	refs.clickButton.Parent = gui

	refs.hint = UI.label({
		Size = UDim2.fromOffset(520, 34),
		Position = UDim2.new(0.5, -260, 1, -152),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 240, 120),
		Parent = gui,
	})

	-- Бусти й таймер подарунка (справа).
	local right = UI.new("Frame", {
		Size = UDim2.fromOffset(220, 300),
		Position = UDim2.new(1, -234, 0.5, -60),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Parent = right,
	})
	refs.giftTimer = UI.button({
		Size = UDim2.fromOffset(220, 44),
		Text = "🎁 Gift",
		BackgroundColor3 = Color3.fromRGB(255, 80, 130),
		LayoutOrder = 0,
		Parent = right,
	}, function()
		openPanel("Gifts")
	end)
	refs.autoClick = UI.button({
		Size = UDim2.fromOffset(220, 40),
		Text = "🤖 Auto Click: OFF",
		BackgroundColor3 = UI.Colors.PanelLight,
		LayoutOrder = 1,
		Parent = right,
	}, function()
		local state = Store.state
		if not state then
			return
		end
		if state.passes.AutoClicker then
			sendAction("Setting", "autoClick", not state.settings.autoClick)
		else
			sendAction("BuyPass", "AutoClicker")
		end
	end)
	refs.boosts = {}
	for order, key in { "Speed2x", "Wins2x", "Lucky" } do
		local boost = UI.label({
			Size = UDim2.fromOffset(220, 32),
			BackgroundTransparency = 0.15,
			BackgroundColor3 = UI.Colors.Panel,
			LayoutOrder = 10 + order,
			Visible = false,
			Parent = right,
		})
		UI.corner(10).Parent = boost
		UI.padding(4).Parent = boost
		refs.boosts[key] = boost
	end

	RunService.RenderStepped:Connect(Hud.Tick)
end

local function setBadge(name: string, text: string?)
	local button = refs.menuButtons and refs.menuButtons[name]
	if not button then
		return
	end
	local badge = button:FindFirstChild("Badge") :: TextLabel
	badge.Visible = text ~= nil
	badge.Text = text or ""
end

-- Індекс наступного незабраного подарунка та скільки до нього чекати.
function Hud.GiftStatus(): (number, number, number)
	local state = Store.state
	if not state then
		return 0, 0, math.huge
	end
	local elapsed = Store.ServerNow() - state.joinTime
	local ready = 0
	local nextIndex, nextWait = 0, math.huge
	for index, gift in Config.PlaytimeGifts do
		if not state.giftsClaimed[index] then
			if elapsed >= gift.time then
				ready += 1
			elseif gift.time - elapsed < nextWait then
				nextIndex, nextWait = index, gift.time - elapsed
			end
		end
	end
	return ready, nextIndex, nextWait
end

local lastSecond = -1
function Hud.Tick()
	local state = Store.state
	local round = Store.round
	local now = Store.ServerNow()

	-- Таймер раунду.
	local remaining = math.max(0, round.endsAt - now)
	if round.phase == "Lobby" then
		refs.timerText.Text = string.format("🏁 Race in <font color=\"#FFD34D\">%d</font>s", math.ceil(remaining))
		refs.timerBar.Size = UDim2.fromScale(math.clamp(1 - remaining / Config.Race.LobbyTime, 0, 1), 1)
		refs.timerBar.BackgroundColor3 = UI.Colors.Speed
	else
		refs.timerText.Text = "🔥 RACE! 🔥"
		refs.timerBar.Size = UDim2.fromScale(math.clamp(remaining / Config.Race.RaceTime, 0, 1), 1)
		refs.timerBar.BackgroundColor3 = UI.Colors.Orange
	end

	if not state then
		return
	end

	-- Статистика (з урахуванням ще не надісланих кліків — миттєвий відгук).
	local predictedSpeed = state.speed + Store.pendingClicks * Config.Click.BaseGain * state.speedMult
	refs.speed.Text = Format.Number(math.floor(predictedSpeed))
	refs.speedSub.Text = "Speed  •  " .. Format.Mult(state.speedMult) .. " per click"
	refs.wins.Text = Format.Number(math.floor(state.wins))
	refs.winsSub.Text = "Wins  •  " .. Format.Mult(state.winsMult)
	refs.rebirths.Text = Format.Number(state.rebirths)
	refs.rebirthsSub.Text = "Rebirths  •  next: " .. Format.Number(state.rebirthCost) .. " 🏆"

	-- Раз на секунду: бейджі, бусти, подарунки, підказки.
	local second = math.floor(now)
	if second == lastSecond then
		return
	end
	lastSecond = second

	setBadge("Daily", if state.dailyClaimedToday then nil else "!")
	setBadge("Rebirth", if state.wins >= state.rebirthCost then "!" else nil)

	local ready, _, nextWait = Hud.GiftStatus()
	setBadge("Gifts", if ready > 0 then tostring(ready) else nil)
	if ready > 0 then
		refs.giftTimer.Text = string.format("🎁 %d gift%s ready!", ready, if ready > 1 then "s" else "")
		refs.giftTimer.Visible = true
	elseif nextWait < math.huge then
		refs.giftTimer.Text = "🎁 Next gift: " .. Format.Time(nextWait)
		refs.giftTimer.Visible = true
	else
		refs.giftTimer.Visible = false
	end

	if state.passes.AutoClicker then
		refs.autoClick.Text = if state.settings.autoClick then "🤖 Auto Click: ON" else "🤖 Auto Click: OFF"
		refs.autoClick.BackgroundColor3 = if state.settings.autoClick then UI.Colors.Green else UI.Colors.PanelLight
	else
		refs.autoClick.Text = "🤖 Auto Click 🔒"
		refs.autoClick.BackgroundColor3 = UI.Colors.PanelLight
	end

	for key, label in refs.boosts do
		local left = Store.BoostRemaining(key)
		label.Visible = left > 0
		if left > 0 then
			label.Text = string.format("%s  %s", Config.Boosts[key].name, Format.Time(left))
		end
	end

	-- Онбординг: одна підказка за раз, що робити далі.
	local hint = ""
	if state.speed < 10 and state.races == 0 then
		hint = "👆 Tap anywhere or press CLICK to gain Speed!"
	elseif state.races == 0 then
		hint = "🏁 Wait for the race — the faster you are, the further you run!"
	elseif #state.pets == 0 and state.wins >= Config.Eggs[1].cost then
		hint = "🥚 Open an egg! Pets multiply your Speed"
	elseif state.rebirths == 0 and state.wins >= state.rebirthCost then
		hint = "🌟 You can REBIRTH! Open the Rebirth menu"
	else
		-- Видима найближча мета: скільки швидкості до наступної зони.
		local zone = Config.ZoneForDistance(Config.DistanceForSpeed(predictedSpeed))
		if zone < Config.Race.ZoneCount then
			hint = string.format("🎯 Zone %d at %s ⚡", zone + 1, Format.Number(math.ceil(Config.SpeedForZone(zone + 1))))
		end
	end
	refs.hint.Text = hint
end

function Hud.PulseClick()
	local scale = refs.clickButton and refs.clickButton:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.93
		UI.tween(scale, 0.12, { Scale = 1 })
	end
end

return Hud
