--!nonstrict
-- Точка входу клієнта: UI, клікання, реакція на події сервера.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local Effects = require(script.Effects)
local Hud = require(script.Hud)
local Panels = require(script.Panels)
local PetsVisual = require(script.PetsVisual)
local Race = require(script.Race)
local Store = require(script.Store)

local player = Players.LocalPlayer

local ActionRemote = Net.Get("Action")
local ClickRemote = Net.Get("Click")

local function sendAction(name: string, a: any?, b: any?)
	ActionRemote:FireServer(name, a, b)
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "TurboRaceUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Інтерфейс намальовано під 1280x720 і масштабується під будь-який екран (телефони — більшість гравців).
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function updateScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.5, 1.2)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

local function openPanel(name: string)
	if name == "Invite" then
		local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and canInvite then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		else
			Hud.Notify("Invites are not available right now", "warn")
		end
		return
	end
	Panels.Open(name)
end

---------------------------------------------------------------------------
-- Клікання
---------------------------------------------------------------------------
local unsentClicks = 0
local clickTimes: { number } = {}

local function doClick(position: Vector2?)
	local state = Store.state
	if not state then
		return
	end
	-- Локальний ліміт, щоб не надсилати зайве (сервер теж перевіряє).
	local now = os.clock()
	while clickTimes[1] and now - clickTimes[1] > 1 do
		table.remove(clickTimes, 1)
	end
	if #clickTimes >= Config.Click.MaxClicksPerSecond then
		return
	end
	table.insert(clickTimes, now)

	unsentClicks += 1
	Store.pendingClicks += 1
	Hud.PulseClick()
	local gain = Config.Click.BaseGain * state.speedMult
	local camera = workspace.CurrentCamera
	local at = position or Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y - 140)
	-- Позиції вводу в пікселях екрана, а UI масштабований — переводимо.
	Effects.ClickPopup(at / uiScale.Scale, "+" .. Format.Number(math.floor(gain)) .. " ⚡")
	if #clickTimes % 3 == 1 then
		Effects.Play("Click", 0.25)
	end
end

Hud.Build(gui, openPanel, function()
	doClick(nil)
end, sendAction)
Panels.Build(gui, sendAction)
Effects.Init(gui)
PetsVisual.Start()
Race.Init()

-- Клік будь-де по екрану (як у топових клікерах) — без кнопки теж працює.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		doClick(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

-- Кліки пачками раз на 0.1 с — менше трафіку.
task.spawn(function()
	while true do
		task.wait(0.1)
		if unsentClicks > 0 then
			ClickRemote:FireServer(unsentClicks)
			unsentClicks = 0
		end
	end
end)

---------------------------------------------------------------------------
-- Події сервера
---------------------------------------------------------------------------
Net.Get("State").OnClientEvent:Connect(function(state)
	Store.pendingClicks = unsentClicks
	Store.Set(state)
end)

Net.Get("RoundState").OnClientEvent:Connect(function(round)
	local previous = Store.round.phase
	Store.round = round
	if round.phase == "Lobby" and previous == "Race" then
		Race.Stop()
	elseif round.phase == "Race" and previous == "Lobby" then
		Effects.Banner("🏁 GO! GO! GO!", Color3.fromRGB(255, 150, 50), 1)
	end
end)

Net.Get("RaceStart").OnClientEvent:Connect(function(info)
	Race.Start(info, Effects.ZonePopup)
end)

Net.Get("RaceResult").OnClientEvent:Connect(function(result)
	Effects.RaceResult(result, function(passKey)
		sendAction("BuyPass", passKey)
	end)
end)

Net.Get("HatchResult").OnClientEvent:Connect(function(result)
	Panels.Close()
	Effects.Hatch(result)
end)

Net.Get("Notify").OnClientEvent:Connect(function(text, kind)
	Hud.Notify(text, kind)
end)

---------------------------------------------------------------------------
-- VIP-тег у чаті
---------------------------------------------------------------------------
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	if source then
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if speaker and speaker:GetAttribute("VIP") then
			properties.PrefixText = "<font color=\"#FFD34D\">[VIP]</font> " .. message.PrefixText
		end
	end
	return properties
end
