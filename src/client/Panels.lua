--!nonstrict
-- Модальні вікна: Pets, Shop, Rebirth, Daily, Gifts, Codes, Settings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Store = require(script.Parent.Store)
local UI = require(script.Parent.UI)

local Panels = {}

type Panel = {
	frame: Frame,
	refresh: (state: any) -> (),
	tick: (() -> ())?,
}

local panels: { [string]: Panel } = {}
local window: Frame
local titleLabel: TextLabel
local current: string? = nil
local send: (string, any?, any?) -> () = function() end

local TITLES = {
	Pets = "🐾 Pets",
	Shop = "🛒 Shop",
	Rebirth = "🌟 Rebirth",
	Daily = "📅 Daily Rewards",
	Gifts = "🎁 Playtime Gifts",
	Codes = "🎟️ Codes",
	Settings = "⚙️ Settings",
}

local function rarityColor(name: string): Color3
	local def = Config.GetPetDef(name)
	return if def then Config.Rarities[def.rarity].color else Color3.new(1, 1, 1)
end

-- Текст нагороди з урахуванням множника ребьорту (як рахує сервер).
function Panels.DescribeReward(reward: any): string
	local state = Store.state
	local rebirthMult = 1 + (if state then state.rebirths else 0)
	local parts = {}
	if reward.kind == "Wins" then
		table.insert(parts, Format.Number(math.floor(reward.amount * rebirthMult)) .. " 🏆")
	elseif reward.kind == "Boost" then
		table.insert(parts, Config.Boosts[reward.boost].name .. " " .. Format.Time(reward.seconds))
	end
	if reward.bonusWins then
		table.insert(parts, Format.Number(math.floor(reward.bonusWins * rebirthMult)) .. " 🏆")
	end
	return table.concat(parts, "\n+ ")
end

local function scrolling(parent: Instance, cell: UDim2?): ScrollingFrame
	local frame = UI.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}) :: ScrollingFrame
	if cell then
		UI.new("UIGridLayout", {
			CellSize = cell,
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = frame,
		})
	else
		UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	end
	UI.padding(4).Parent = frame
	return frame
end

local function clearChildren(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Pets
---------------------------------------------------------------------------
local function buildPets(content: Frame): Panel
	local header = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content })
	local info = UI.label({ Size = UDim2.new(0.42, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = header })
	UI.button({ Size = UDim2.new(0.18, 0, 1, 0), Position = UDim2.fromScale(0.42, 0), Text = "Equip Best", BackgroundColor3 = UI.Colors.Green, Parent = header }, function()
		send("EquipBest")
	end)
	local auto = UI.button({ Size = UDim2.new(0.2, -6, 1, 0), Position = UDim2.new(0.6, 6, 0, 0), Text = "Auto: ON", BackgroundColor3 = UI.Colors.Speed, Parent = header }, function()
		local state = Store.state
		if state then
			send("Setting", "autoEquip", not state.settings.autoEquip)
		end
	end)
	UI.button({ Size = UDim2.new(0.2, -6, 1, 0), Position = UDim2.new(0.8, 6, 0, 0), Text = "🗑 Commons", BackgroundColor3 = UI.Colors.Red, Parent = header }, function()
		send("DeleteRarity", "Common")
	end)

	local body = UI.new("Frame", { Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 48), BackgroundTransparency = 1, Parent = content })
	local grid = scrolling(body, UDim2.fromOffset(104, 124))
	local empty = UI.label({ Size = UDim2.new(1, 0, 0, 40), Text = "No pets yet — open an egg in the lobby! 🥚", Parent = body })

	local signature = ""
	return {
		frame = content,
		refresh = function(state)
			local equipped = 0
			for _, pet in state.pets do
				if pet.equipped then
					equipped += 1
				end
			end
			info.Text = string.format("Equipped %d/%d  •  %s  •  %d/%d", equipped, state.equipSlots, Format.Mult(state.petMult), #state.pets, Config.Pets.InventoryLimit)
			auto.Text = if state.settings.autoEquip then "Auto: ON" else "Auto: OFF"
			empty.Visible = #state.pets == 0

			local parts = {}
			for _, pet in state.pets do
				table.insert(parts, pet.uid .. (if pet.equipped then "1" else "0"))
			end
			local newSignature = table.concat(parts, ",")
			if newSignature == signature then
				return
			end
			signature = newSignature

			clearChildren(grid)
			local sorted = table.clone(state.pets)
			table.sort(sorted, function(a, b)
				if a.equipped ~= b.equipped then
					return a.equipped
				end
				local da, db = Config.GetPetDef(a.name), Config.GetPetDef(b.name)
				return (if da then da.boost else 0) > (if db then db.boost else 0)
			end)
			for order, pet in sorted do
				local def = Config.GetPetDef(pet.name)
				if def then
					local color = rarityColor(pet.name)
					local card = UI.button({
						Text = "",
						LayoutOrder = order,
						BackgroundColor3 = color:Lerp(UI.Colors.Panel, 0.55),
						Parent = grid,
					}, function()
						send("Equip", pet.uid, not pet.equipped)
					end)
					local stroke = card:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Color = if pet.equipped then UI.Colors.Green else color
						stroke.Thickness = if pet.equipped then 4 else 2.5
					end
					UI.label({ Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 6), Text = def.icon, Parent = card })
					UI.label({ Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 60), Text = def.name, Parent = card })
					UI.label({ Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 82), Text = Format.Mult(def.boost), TextColor3 = UI.Colors.Speed, Parent = card })
					UI.label({ Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 104), Text = def.rarity, TextColor3 = color, Parent = card })
					if pet.equipped then
						UI.label({ Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(4, 4), Text = "✅", Parent = card })
					else
						local del = UI.button({
							Size = UDim2.fromOffset(24, 24),
							Position = UDim2.new(1, -28, 0, 4),
							Text = "✕",
							BackgroundColor3 = UI.Colors.Red,
							Parent = card,
						}, function()
							send("Delete", pet.uid)
						end)
						del.ZIndex = 3
					end
				end
			end
		end,
	}
end

---------------------------------------------------------------------------
-- Shop
---------------------------------------------------------------------------
local function shopCard(parent: Instance, order: number, title: string, desc: string, priceText: string, color: Color3, tag: string?, onBuy: () -> ()): TextButton
	local card = UI.new("Frame", {
		Size = UDim2.new(1, -8, 0, 70),
		BackgroundColor3 = UI.Colors.PanelLight,
		LayoutOrder = order,
		Parent = parent,
	})
	UI.corner(12).Parent = card
	UI.stroke(color, 2.5).Parent = card
	UI.label({ Size = UDim2.new(0.68, -12, 0, 30), Position = UDim2.fromOffset(12, 6), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	UI.label({
		Size = UDim2.new(0.68, -12, 0, 22),
		Position = UDim2.fromOffset(12, 40),
		Text = desc,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	if tag then
		local tagLabel = UI.label({
			Size = UDim2.fromOffset(100, 20),
			Position = UDim2.new(0.68, -110, 0, -8),
			BackgroundTransparency = 0,
			BackgroundColor3 = UI.Colors.Red,
			Text = tag,
			Parent = card,
		})
		UI.corner(6).Parent = tagLabel
	end
	return UI.button({
		Size = UDim2.new(0.3, -8, 0, 46),
		Position = UDim2.new(0.7, 0, 0, 12),
		Text = priceText,
		BackgroundColor3 = UI.Colors.Robux,
		Parent = card,
	}, onBuy)
end

local function sectionTitle(parent: Instance, order: number, text: string)
	UI.label({ Size = UDim2.new(1, -8, 0, 32), Text = text, LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent })
end

local function buildShop(content: Frame): Panel
	local list = scrolling(content)
	local signature = ""
	return {
		frame = content,
		refresh = function(state)
			local owned = {}
			for _, pass in Config.GamePasses do
				table.insert(owned, if state.passes[pass.key] then "1" else "0")
			end
			local newSignature = table.concat(owned) .. "|" .. state.rebirths
			if newSignature == signature then
				return
			end
			signature = newSignature
			clearChildren(list)

			local order = 0
			local function nextOrder()
				order += 1
				return order
			end
			sectionTitle(list, nextOrder(), "⚡ Boosts & Wins")
			for _, product in Config.Products do
				local desc = if product.kind == "Wins"
					then "+" .. Format.Number(math.floor(product.amount * (1 + state.rebirths))) .. " 🏆 Wins instantly"
					else "Stacks with everything. Timer adds up!"
				shopCard(list, nextOrder(), product.name, desc, " R$ " .. product.price, UI.Colors.Wins, product.tag, function()
					send("BuyProduct", product.key)
				end)
			end
			sectionTitle(list, nextOrder(), "💎 Game Passes (forever)")
			for _, pass in Config.GamePasses do
				local isOwned = state.passes[pass.key] == true
				local button = shopCard(list, nextOrder(), pass.name, pass.desc, if isOwned then "OWNED ✅" else " R$ " .. pass.price, UI.Colors.Rebirth, nil, function()
					if not isOwned then
						send("BuyPass", pass.key)
					end
				end)
				if isOwned then
					button.BackgroundColor3 = UI.Colors.PanelLight
				end
			end
		end,
	}
end

---------------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------------
local function buildRebirth(content: Frame): Panel
	local title = UI.label({ Size = UDim2.new(1, 0, 0, 40), Text = "", Parent = content })
	local benefits = UI.label({ Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 48), Text = "", Parent = content })
	local barBack = UI.new("Frame", {
		Size = UDim2.new(0.9, 0, 0, 30),
		Position = UDim2.new(0.05, 0, 0, 150),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		Parent = content,
	})
	UI.corner(10).Parent = barBack
	local bar = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.Colors.Wins, Parent = barBack })
	UI.corner(10).Parent = bar
	local barText = UI.label({ Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2, Parent = barBack })
	UI.label({
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 188),
		Text = "⚠️ Rebirth resets your Speed. Pets and Wins left over stay!",
		TextColor3 = UI.Colors.Muted,
		Parent = content,
	})
	local button = UI.button({
		Size = UDim2.new(0.5, 0, 0, 60),
		Position = UDim2.new(0.25, 0, 0, 226),
		Text = "🌟 REBIRTH",
		BackgroundColor3 = UI.Colors.Rebirth,
		Parent = content,
	}, function()
		send("Rebirth")
	end)
	return {
		frame = content,
		refresh = function(state)
			local cost = state.rebirthCost
			title.Text = string.format("Rebirths: <font color=\"#C86EFF\">%s</font>", Format.Number(state.rebirths))
			local nowSpeed = 1 + state.rebirths * Config.Rebirth.SpeedMultPerRebirth
			local nextSpeed = nowSpeed + Config.Rebirth.SpeedMultPerRebirth
			local nowWins = 1 + state.rebirths * Config.Rebirth.WinsMultPerRebirth
			local nextWins = nowWins + Config.Rebirth.WinsMultPerRebirth
			benefits.Text = string.format(
				"⚡ Speed per click: %s → <font color=\"#7CFF6B\">%s</font>\n🏆 Wins bonus: %s → <font color=\"#7CFF6B\">%s</font>\n🎁 Rewards & packs: %s → <font color=\"#7CFF6B\">%s</font>",
				Format.Mult(nowSpeed),
				Format.Mult(nextSpeed),
				Format.Mult(nowWins),
				Format.Mult(nextWins),
				Format.Mult(1 + state.rebirths),
				Format.Mult(2 + state.rebirths)
			)
			local progress = math.clamp(state.wins / cost, 0, 1)
			bar.Size = UDim2.fromScale(progress, 1)
			barText.Text = Format.Number(math.floor(state.wins)) .. " / " .. Format.Number(cost) .. " 🏆"
			button.BackgroundColor3 = if progress >= 1 then UI.Colors.Rebirth else UI.Colors.PanelLight
		end,
	}
end

---------------------------------------------------------------------------
-- Daily
---------------------------------------------------------------------------
local function buildDaily(content: Frame): Panel
	local holder = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 230), BackgroundTransparency = 1, Parent = content })
	UI.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -8, 0, 110),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = holder,
	})
	local cards = {}
	for day, reward in Config.DailyRewards do
		local card = UI.new("Frame", { BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = day, Parent = holder })
		UI.corner(12).Parent = card
		local stroke = UI.stroke(Color3.new(0, 0, 0), 2.5)
		stroke.Parent = card
		UI.label({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 4), Text = "Day " .. day, Parent = card })
		local text = UI.label({ Size = UDim2.new(1, -8, 0, 70), Position = UDim2.fromOffset(4, 34), Text = "", Parent = card })
		cards[day] = { card = card, stroke = stroke, text = text, reward = reward }
	end
	local claim = UI.button({
		Size = UDim2.new(0.5, 0, 0, 54),
		Position = UDim2.new(0.25, 0, 0, 244),
		Text = "CLAIM",
		Parent = content,
	}, function()
		send("ClaimDaily")
	end)
	return {
		frame = content,
		refresh = function(state)
			-- День, який буде виданий наступним (або вже виданий сьогодні).
			local nextDay = state.dailyDay
			for day, info in cards do
				info.text.Text = Panels.DescribeReward(info.reward)
				local isNext = day == nextDay
				info.stroke.Color = if isNext then UI.Colors.Wins else Color3.new(0, 0, 0)
				info.stroke.Thickness = if isNext then 4 else 2.5
				info.card.BackgroundColor3 = if day < nextDay or (isNext and state.dailyClaimedToday) then UI.Colors.Green:Lerp(UI.Colors.Panel, 0.5) else UI.Colors.PanelLight
			end
			claim.Text = if state.dailyClaimedToday then "Come back tomorrow! ⏰" else "CLAIM DAY " .. nextDay
			claim.BackgroundColor3 = if state.dailyClaimedToday then UI.Colors.PanelLight else UI.Colors.Green
		end,
	}
end

---------------------------------------------------------------------------
-- Gifts
---------------------------------------------------------------------------
local function buildGifts(content: Frame): Panel
	local grid = scrolling(content, UDim2.new(0.25, -8, 0, 140))
	local buttons = {}
	for index, gift in Config.PlaytimeGifts do
		local card = UI.new("Frame", { BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = index, Parent = grid })
		UI.corner(12).Parent = card
		UI.label({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), Text = "🎁", Parent = card })
		local text = UI.label({ Size = UDim2.new(1, -8, 0, 46), Position = UDim2.fromOffset(4, 36), Text = "", Parent = card })
		local button = UI.button({
			Size = UDim2.new(1, -12, 0, 40),
			Position = UDim2.new(0, 6, 1, -46),
			Text = "",
			Parent = card,
		}, function()
			send("ClaimGift", index)
		end)
		buttons[index] = { button = button, text = text, gift = gift }
	end
	local function tick()
		local state = Store.state
		if not state then
			return
		end
		local elapsed = Store.ServerNow() - state.joinTime
		for index, info in buttons do
			info.text.Text = Panels.DescribeReward(info.gift)
			if state.giftsClaimed[index] then
				info.button.Text = "✅"
				info.button.BackgroundColor3 = UI.Colors.PanelLight
			elseif elapsed >= info.gift.time then
				info.button.Text = "CLAIM"
				info.button.BackgroundColor3 = UI.Colors.Green
			else
				info.button.Text = Format.Time(info.gift.time - elapsed)
				info.button.BackgroundColor3 = UI.Colors.Panel
			end
		end
	end
	return { frame = content, refresh = function() tick() end, tick = tick }
end

---------------------------------------------------------------------------
-- Codes
---------------------------------------------------------------------------
local function buildCodes(content: Frame): Panel
	UI.label({
		Size = UDim2.new(1, 0, 0, 50),
		Text = "Find new codes in the game description\nand our community group! 🔔",
		TextColor3 = UI.Colors.Muted,
		Parent = content,
	})
	local box = UI.new("TextBox", {
		Size = UDim2.new(0.8, 0, 0, 56),
		Position = UDim2.new(0.1, 0, 0, 70),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		PlaceholderText = "Enter code...",
		Text = "",
		Font = UI.Font,
		TextScaled = true,
		TextColor3 = UI.Colors.Text,
		ClearTextOnFocus = false,
		Parent = content,
	}) :: TextBox
	UI.corner(12).Parent = box
	UI.padding(8).Parent = box
	UI.button({ Size = UDim2.new(0.5, 0, 0, 54), Position = UDim2.new(0.25, 0, 0, 142), Text = "REDEEM", Parent = content }, function()
		send("Code", box.Text)
		box.Text = ""
	end)
	return { frame = content, refresh = function() end }
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
Panels.HideOtherPets = false

local function buildSettings(content: Frame): Panel
	local list = scrolling(content)
	local function toggle(order: number, onClick: () -> ()): TextButton
		return UI.button({ Size = UDim2.new(1, -8, 0, 54), LayoutOrder = order, Text = "", Parent = list }, onClick)
	end
	local autoEquip = toggle(1, function()
		local state = Store.state
		if state then
			send("Setting", "autoEquip", not state.settings.autoEquip)
		end
	end)
	local autoClick = toggle(2, function()
		local state = Store.state
		if state then
			if state.passes.AutoClicker then
				send("Setting", "autoClick", not state.settings.autoClick)
			else
				send("BuyPass", "AutoClicker")
			end
		end
	end)
	local hidePets: TextButton
	hidePets = toggle(3, function()
		Panels.HideOtherPets = not Panels.HideOtherPets
		hidePets.Text = "Hide other players' pets: " .. (if Panels.HideOtherPets then "ON" else "OFF")
	end)
	hidePets.Text = "Hide other players' pets: OFF"
	return {
		frame = content,
		refresh = function(state)
			autoEquip.Text = "Auto-equip best pets: " .. (if state.settings.autoEquip then "ON" else "OFF")
			autoEquip.BackgroundColor3 = if state.settings.autoEquip then UI.Colors.Green else UI.Colors.PanelLight
			autoClick.Text = if state.passes.AutoClicker
				then "Auto Clicker: " .. (if state.settings.autoClick then "ON" else "OFF")
				else "Auto Clicker 🔒 (Game Pass)"
			autoClick.BackgroundColor3 = if state.passes.AutoClicker and state.settings.autoClick then UI.Colors.Green else UI.Colors.PanelLight
		end,
	}
end

---------------------------------------------------------------------------

function Panels.Build(gui: ScreenGui, sendAction: (string, any?, any?) -> ())
	send = sendAction
	window = UI.new("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(620, 420),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.Colors.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	UI.corner(18).Parent = window
	UI.stroke(Color3.new(0, 0, 0), 4).Parent = window
	UI.new("UIScale", { Parent = window })
	titleLabel = UI.label({ Size = UDim2.new(1, -120, 0, 44), Position = UDim2.fromOffset(16, 8), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = window })
	UI.button({
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -54, 0, 8),
		Text = "✕",
		BackgroundColor3 = UI.Colors.Red,
		Parent = window,
	}, function()
		Panels.Close()
	end)

	local builders: { [string]: (Frame) -> Panel } = {
		Pets = buildPets,
		Shop = buildShop,
		Rebirth = buildRebirth,
		Daily = buildDaily,
		Gifts = buildGifts,
		Codes = buildCodes,
		Settings = buildSettings,
	}
	for name, builder in builders do
		local content = UI.new("Frame", {
			Name = name,
			Size = UDim2.new(1, -32, 1, -72),
			Position = UDim2.fromOffset(16, 60),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = window,
		})
		panels[name] = builder(content)
	end

	Store.Changed:Connect(function(state)
		if current and panels[current] then
			panels[current].refresh(state)
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		local panel = current and panels[current]
		if panel and panel.tick then
			panel.tick()
		end
	end)
end

function Panels.Open(name: string)
	local panel = panels[name]
	if not panel then
		return
	end
	if current == name then
		Panels.Close()
		return
	end
	if current and panels[current] then
		panels[current].frame.Visible = false
	end
	current = name
	titleLabel.Text = TITLES[name] or name
	panel.frame.Visible = true
	if Store.state then
		panel.refresh(Store.state)
	end
	window.Visible = true
	local scale = window:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.6
	UI.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Panels.Close()
	if current and panels[current] then
		panels[current].frame.Visible = false
	end
	current = nil
	window.Visible = false
end

return Panels
