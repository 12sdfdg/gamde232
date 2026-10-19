--!nonstrict
-- Візуальні ефекти й «соковитість»: спливаючі числа, вилуплення яєць, зони, результат забігу.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UI = require(script.Parent.UI)

local Effects = {}

-- Заміни на власні звуки з Creator Store (rbxassetid://...), якщо хочеш.
local SOUNDS = {
	Click = "rbxasset://sounds/clickfast.wav",
	Reward = "rbxasset://sounds/electronicpingshort.wav",
}

local gui: ScreenGui
local hatchQueue: { any } = {}
local hatching = false

function Effects.Init(screenGui: ScreenGui)
	gui = screenGui
end

function Effects.Play(name: string, volume: number?)
	local id = SOUNDS[name]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- "+N ⚡" там, де клікнули.
function Effects.ClickPopup(position: Vector2, text: string)
	local label = UI.label({
		Size = UDim2.fromOffset(160, 34),
		Position = UDim2.fromOffset(position.X - 80 + math.random(-30, 30), position.Y - 40),
		Text = text,
		TextColor3 = UI.Colors.Speed,
		ZIndex = 20,
		Parent = gui,
	})
	UI.tween(label, 0.7, { Position = label.Position - UDim2.fromOffset(0, 70), TextTransparency = 1 })
	task.delay(0.7, function()
		label:Destroy()
	end)
end

-- Великий напис посеред екрана.
function Effects.Banner(text: string, color: Color3?, duration: number?)
	local label = UI.label({
		Size = UDim2.fromOffset(600, 70),
		Position = UDim2.new(0.5, -300, 0.32, 0),
		Text = text,
		TextColor3 = color or UI.Colors.Wins,
		ZIndex = 20,
		Parent = gui,
	})
	local scale = UI.new("UIScale", { Scale = 0.3, Parent = label })
	UI.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration or 1.2, function()
		UI.tween(label, 0.3, { TextTransparency = 1 })
		task.wait(0.3)
		label:Destroy()
	end)
end

function Effects.ZonePopup(zone: number)
	Effects.Banner(string.format("ZONE %d  +%s 🏆", zone, Format.Number(Config.ZoneReward(zone))), UI.Colors.Wins, 0.8)
	Effects.Play("Reward", 0.3)
end

function Effects.RaceResult(result: any, onUpsell: (string) -> ())
	if result.zone < 1 then
		Effects.Banner("Click more to reach Zone 1! ⚡", UI.Colors.Speed, 2)
		return
	end
	local card = UI.new("Frame", {
		Size = UDim2.fromOffset(380, if result.upsell then 210 else 140),
		Position = UDim2.new(0.5, -190, 0.5, -60),
		BackgroundColor3 = UI.Colors.Panel,
		ZIndex = 30,
		Parent = gui,
	})
	UI.corner(18).Parent = card
	UI.stroke(UI.Colors.Wins, 4).Parent = card
	UI.label({
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.fromOffset(10, 10),
		Text = if result.newBest then "🏅 NEW BEST: ZONE " .. result.zone .. "!" else "🏁 REACHED ZONE " .. result.zone,
		ZIndex = 31,
		Parent = card,
	})
	UI.label({
		Size = UDim2.new(1, -20, 0, 54),
		Position = UDim2.fromOffset(10, 60),
		Text = "+" .. Format.Number(result.wins) .. " 🏆",
		TextColor3 = UI.Colors.Wins,
		ZIndex = 31,
		Parent = card,
	})
	if result.upsell then
		local pass = Config.GetPass(result.upsell)
		if pass then
			UI.button({
				Size = UDim2.new(1, -40, 0, 56),
				Position = UDim2.fromOffset(20, 130),
				Text = string.format("🔥 Get %s forever — R$ %d", pass.name, pass.price),
				BackgroundColor3 = UI.Colors.Robux,
				ZIndex = 31,
				Parent = card,
			}, function()
				onUpsell(pass.key)
				card:Destroy()
			end)
		end
	end
	local scale = UI.new("UIScale", { Scale = 0.5, Parent = card })
	UI.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	Effects.Play("Reward", 0.6)
	task.delay(if result.upsell then 6 else 2.5, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

local function playHatch(result: any)
	hatching = true
	local overlay = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = gui,
	})
	UI.tween(overlay, 0.25, { BackgroundTransparency = 0.35 })

	local count = #result.pets
	local eggs = {}
	for i = 1, count do
		local egg = UI.label({
			Size = UDim2.fromOffset(150, 150),
			Position = UDim2.new(0.5, -75 + (i - (count + 1) / 2) * 180, 0.5, -90),
			Text = "🥚",
			ZIndex = 41,
			Parent = overlay,
		})
		table.insert(eggs, egg)
	end
	-- Похитування яйця з наростанням.
	for step = 1, 8 do
		local angle = (if step % 2 == 0 then 1 else -1) * (6 + step * 2)
		for _, egg in eggs do
			UI.tween(egg, 0.12, { Rotation = angle })
		end
		task.wait(0.13)
	end

	for i, name in result.pets do
		local def = Config.GetPetDef(name)
		local egg = eggs[i]
		egg.Rotation = 0
		if def then
			local color = Config.Rarities[def.rarity].color
			egg.Text = def.icon
			local scale = UI.new("UIScale", { Scale = 0.2, Parent = egg })
			UI.tween(scale, 0.35, { Scale = 1.1 }, Enum.EasingStyle.Back)
			UI.label({
				Size = UDim2.new(1, 40, 0, 56),
				Position = UDim2.new(0, -20, 1, 4),
				Text = string.format("%s\n<font color=\"#%s\">%s</font>  %s", def.name, color:ToHex(), def.rarity, Format.Mult(def.boost)),
				ZIndex = 42,
				Parent = egg,
			})
			if Config.LuckyRarities[def.rarity] then
				Effects.Banner("✨ " .. def.rarity:upper() .. " PET! ✨", color, 2)
			end
		end
	end
	Effects.Play("Reward", 0.7)
	task.wait(2.2)
	UI.tween(overlay, 0.3, { BackgroundTransparency = 1 })
	for _, egg in eggs do
		UI.tween(egg, 0.3, { TextTransparency = 1 })
	end
	task.wait(0.3)
	overlay:Destroy()
	hatching = false
	local nextResult = table.remove(hatchQueue, 1)
	if nextResult then
		playHatch(nextResult)
	end
end

function Effects.Hatch(result: any)
	if hatching then
		table.insert(hatchQueue, result)
		return
	end
	task.spawn(playHatch, result)
end

return Effects
