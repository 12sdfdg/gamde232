--!nonstrict
-- Малює екіпірованих улюбленців біля кожного гравця (лише на клієнті — без навантаження на сервер).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Panels = require(script.Parent.Panels)

local localPlayer = Players.LocalPlayer

local PetsVisual = {}

local folder: Folder
local owned: { [Player]: { text: string, parts: { BasePart } } } = {}

local function makePet(name: string): BasePart
	local def = Config.GetPetDef(name)
	local color = if def then Config.Rarities[def.rarity].color else Color3.new(1, 1, 1)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(3.2, 3.2)
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = part

	local glow = Instance.new("Frame")
	glow.Size = UDim2.fromScale(0.8, 0.8)
	glow.Position = UDim2.fromScale(0.1, 0.1)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = 0.55
	glow.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = glow

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.TextScaled = true
	icon.Text = if def then def.icon else "?"
	icon.Parent = gui

	part.Parent = folder
	return part
end

local function sync(player: Player)
	local text = (player:GetAttribute("EquippedPets") :: string?) or ""
	if player ~= localPlayer and Panels.HideOtherPets then
		text = ""
	end
	local entry = owned[player]
	if entry and entry.text == text then
		return
	end
	if entry then
		for _, part in entry.parts do
			part:Destroy()
		end
	end
	local parts = {}
	for name in string.gmatch(text, "[^,]+") do
		table.insert(parts, makePet(name))
	end
	owned[player] = { text = text, parts = parts }
end

function PetsVisual.Start()
	folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = workspace

	Players.PlayerRemoving:Connect(function(player)
		local entry = owned[player]
		if entry then
			for _, part in entry.parts do
				part:Destroy()
			end
		end
		owned[player] = nil
	end)

	local syncTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		syncTimer += dt
		if syncTimer > 0.5 then
			syncTimer = 0
			for _, player in Players:GetPlayers() do
				sync(player)
			end
		end
		local now = os.clock()
		for player, entry in owned do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local count = #entry.parts
				for index, part in entry.parts do
					-- Дугою позаду гравця, з легким підстрибуванням.
					local spread = if count > 1 then (index - 1) / (count - 1) - 0.5 else 0
					local angle = spread * math.rad(110)
					local radius = 6 + math.floor((index - 1) / 4) * 2
					local bob = math.sin(now * 4 + index) * 0.4
					local target = root.CFrame * CFrame.new(math.sin(angle) * radius, 0.5 + bob, math.cos(angle) * radius)
					if (part.Position - target.Position).Magnitude > 40 then
						part.CFrame = target
					else
						part.CFrame = part.CFrame:Lerp(target, math.min(1, dt * 10))
					end
				end
			end
		end
	end)
end

return PetsVisual
