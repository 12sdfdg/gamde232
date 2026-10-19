--!nonstrict
-- Процедурно будує карту: лобі, трасу з 40 зонами, стенди з яйцями, дошку лідерів.
-- Нічого не треба моделювати вручну, але можна замінити будь-яку частину своєю моделлю.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MapBuilder = {}

local LOBBY_SIZE = 220
local TRACK_START_X = LOBBY_SIZE / 2 + 20
local GROUND_Y = 0

local ZONE_COLORS = {
	Color3.fromRGB(255, 90, 90),
	Color3.fromRGB(255, 160, 60),
	Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(110, 220, 90),
	Color3.fromRGB(60, 200, 220),
	Color3.fromRGB(80, 120, 255),
	Color3.fromRGB(170, 90, 255),
	Color3.fromRGB(255, 90, 200),
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function label(parent: Instance, text: string, size: UDim2, offset: Vector3, color: Color3?, maxDistance: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance or 250
	gui.LightInfluence = 0
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Text = text
	text_.TextScaled = true
	text_.Font = Enum.Font.FredokaOne
	text_.TextColor3 = color or Color3.new(1, 1, 1)
	text_.RichText = true
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Parent = text_
	text_.Parent = gui
	gui.Parent = parent
	return gui
end

function MapBuilder.TrackStartX(): number
	return TRACK_START_X
end

-- CFrame старту на доріжці lane (1..Lanes). Траса йде вздовж +X.
function MapBuilder.LaneStart(lane: number): CFrame
	local width = Config.Race.TrackWidth
	local laneWidth = width / Config.Race.Lanes
	local z = -width / 2 + laneWidth * (lane - 0.5)
	return CFrame.lookAt(Vector3.new(TRACK_START_X, GROUND_Y + 4, z), Vector3.new(TRACK_START_X + 100, GROUND_Y + 4, z))
end

function MapBuilder.LobbySpawn(): CFrame
	return CFrame.new(-30, GROUND_Y + 5, 0)
end

local function buildLobby(map: Folder): TextLabel
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = map

	part({
		Name = "Floor",
		Size = Vector3.new(LOBBY_SIZE, 4, LOBBY_SIZE),
		Position = Vector3.new(0, GROUND_Y - 2, 0),
		Color = Color3.fromRGB(120, 200, 110),
		Material = Enum.Material.Grass,
		Parent = lobby,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.CFrame = MapBuilder.LobbySpawn() - Vector3.new(0, 4.5, 0)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby

	-- Невидимі стіни лобі, щоб ніхто не випав.
	local wallHeight = 40
	for _, cfg in {
		{ Vector3.new(0, 0, LOBBY_SIZE / 2), Vector3.new(LOBBY_SIZE, wallHeight, 2) },
		{ Vector3.new(0, 0, -LOBBY_SIZE / 2), Vector3.new(LOBBY_SIZE, wallHeight, 2) },
		{ Vector3.new(-LOBBY_SIZE / 2, 0, 0), Vector3.new(2, wallHeight, LOBBY_SIZE) },
		-- Схід: стіна з проходом під ширину траси.
		{ Vector3.new(LOBBY_SIZE / 2, 0, (LOBBY_SIZE + Config.Race.TrackWidth) / 4), Vector3.new(2, wallHeight, (LOBBY_SIZE - Config.Race.TrackWidth) / 2) },
		{ Vector3.new(LOBBY_SIZE / 2, 0, -(LOBBY_SIZE + Config.Race.TrackWidth) / 4), Vector3.new(2, wallHeight, (LOBBY_SIZE - Config.Race.TrackWidth) / 2) },
	} do
		part({
			Name = "Wall",
			Size = cfg[2],
			Position = cfg[1] + Vector3.new(0, GROUND_Y + wallHeight / 2, 0),
			Transparency = 1,
			Parent = lobby,
		})
	end

	-- Декоративні дерева.
	local rng = Random.new(42)
	for _ = 1, 26 do
		local x = rng:NextNumber(-LOBBY_SIZE / 2 + 10, LOBBY_SIZE / 2 - 10)
		local z = rng:NextNumber(-LOBBY_SIZE / 2 + 10, LOBBY_SIZE / 2 - 10)
		if math.abs(z) > 80 then
			local height = rng:NextNumber(10, 18)
			part({
				Name = "Trunk",
				Size = Vector3.new(2.5, height, 2.5),
				Position = Vector3.new(x, GROUND_Y + height / 2, z),
				Color = Color3.fromRGB(120, 80, 50),
				Material = Enum.Material.Wood,
				Parent = lobby,
			})
			part({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * rng:NextNumber(9, 13),
				Position = Vector3.new(x, GROUND_Y + height + 3, z),
				Color = Color3.fromRGB(60, rng:NextInteger(150, 190), 70),
				Material = Enum.Material.Grass,
				Parent = lobby,
			})
		end
	end

	-- Стартова арка.
	local arch = Instance.new("Model")
	arch.Name = "StartArch"
	arch.Parent = lobby
	local width = Config.Race.TrackWidth
	for _, side in { -1, 1 } do
		part({
			Size = Vector3.new(4, 30, 4),
			Position = Vector3.new(TRACK_START_X, GROUND_Y + 15, side * (width / 2 + 2)),
			Color = Color3.fromRGB(30, 30, 40),
			Parent = arch,
		})
	end
	local top = part({
		Name = "Top",
		Size = Vector3.new(4, 6, width + 8),
		Position = Vector3.new(TRACK_START_X, GROUND_Y + 32, 0),
		Color = Color3.fromRGB(255, 70, 70),
		Material = Enum.Material.Neon,
		Parent = arch,
	})
	label(top, "🏁 START", UDim2.fromScale(40, 8), Vector3.new(0, 8, 0), nil, 600)

	-- Табло раунду над спавном (текст оновлює RaceService).
	local board = part({
		Name = "RoundBoard",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(TRACK_START_X - 40, GROUND_Y + 30, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = lobby,
	})
	local roundGui = label(board, "", UDim2.fromScale(50, 10), Vector3.zero, nil, 500)
	return roundGui:FindFirstChildOfClass("TextLabel") :: TextLabel
end

local function buildTrack(map: Folder)
	local track = Instance.new("Folder")
	track.Name = "Track"
	track.Parent = map

	local width = Config.Race.TrackWidth
	local zoneLength = Config.Race.ZoneLength

	-- Перехідний місток від лобі до траси.
	part({
		Name = "Bridge",
		Size = Vector3.new(TRACK_START_X - LOBBY_SIZE / 2, 4, width),
		Position = Vector3.new((TRACK_START_X + LOBBY_SIZE / 2) / 2, GROUND_Y - 2, 0),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Concrete,
		Parent = track,
	})

	for zone = 0, Config.Race.ZoneCount do
		local startX = TRACK_START_X + zone * zoneLength
		local color = ZONE_COLORS[zone % #ZONE_COLORS + 1]
		part({
			Name = "Zone" .. zone,
			Size = Vector3.new(zoneLength, 4, width),
			Position = Vector3.new(startX + zoneLength / 2, GROUND_Y - 2, 0),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Parent = track,
		})
		for _, side in { -1, 1 } do
			part({
				Name = "Rail",
				Size = Vector3.new(zoneLength, 6, 2),
				Position = Vector3.new(startX + zoneLength / 2, GROUND_Y + 3, side * (width / 2 + 1)),
				Color = color:Lerp(Color3.new(1, 1, 1), 0.5),
				Material = Enum.Material.Neon,
				Parent = track,
			})
		end
		if zone >= 1 then
			local gate = part({
				Name = "Gate" .. zone,
				Size = Vector3.new(1, 22, width),
				Position = Vector3.new(startX, GROUND_Y + 11, 0),
				Color = color,
				Material = Enum.Material.ForceField,
				Transparency = 0.4,
				CanCollide = false,
				CanQuery = false,
				Parent = track,
			})
			local reward = Config.ZoneReward(zone)
			label(
				gate,
				string.format('ZONE %d\n<font color="#50C8FF">%s ⚡</font>  <font color="#7CFF6B">+%s 🏆</font>', zone, Format.Number(math.ceil(Config.SpeedForZone(zone))), Format.Number(reward)),
				UDim2.fromScale(26, 10),
				Vector3.new(0, 16, 0),
				nil,
				900
			)
		end
	end

	-- Фінальна стіна.
	local endX = TRACK_START_X + (Config.Race.ZoneCount + 1) * zoneLength
	part({
		Name = "EndWall",
		Size = Vector3.new(4, 60, width + 4),
		Position = Vector3.new(endX, GROUND_Y + 30, 0),
		Color = Color3.fromRGB(255, 215, 60),
		Material = Enum.Material.Neon,
		Parent = track,
	})
end

-- Стенди з яйцями з ProximityPrompt. Повертає { [eggId] = ProximityPrompt }.
local function buildEggs(map: Folder): { [string]: { ProximityPrompt } }
	local folder = Instance.new("Folder")
	folder.Name = "Eggs"
	folder.Parent = map

	local prompts: { [string]: { ProximityPrompt } } = {}
	for index, egg in Config.Eggs do
		local x = -60 + (index - 1) * 45
		local z = -60
		local stand = Instance.new("Model")
		stand.Name = egg.id
		stand.Parent = folder

		part({
			Name = "Base",
			Size = Vector3.new(16, 3, 16),
			Position = Vector3.new(x, GROUND_Y + 1.5, z),
			Color = Color3.fromRGB(60, 60, 75),
			Material = Enum.Material.Slate,
			Parent = stand,
		})
		local eggPart = part({
			Name = "Egg",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(8, 10, 8),
			Position = Vector3.new(x, GROUND_Y + 8, z),
			Color = egg.color,
			Material = Enum.Material.SmoothPlastic,
			Parent = stand,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 1.25, 1)
		mesh.Parent = eggPart
		stand.PrimaryPart = eggPart

		-- Шанси показуємо відкрито (правила Roblox для випадкових предметів).
		local lines = { string.format('<b>%s</b>  <font color="#FFD34D">%s 🏆</font>', egg.name, Format.Number(egg.cost)) }
		for _, pet in egg.pets do
			local hex = Config.Rarities[pet.rarity].color:ToHex()
			table.insert(lines, string.format('<font color="#%s">%s %s — %s%%</font>', hex, pet.name, Format.Mult(pet.boost), tostring(pet.chance)))
		end
		label(eggPart, table.concat(lines, "\n"), UDim2.fromScale(14, 3 + #egg.pets * 1.2), Vector3.new(0, 11 + #egg.pets * 0.6, 0), nil, 120)

		prompts[egg.id] = {}
		local function addPrompt(count: number, key: Enum.KeyCode, text: string)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Hatch" .. count
			prompt.ActionText = text
			prompt.ObjectText = egg.name
			prompt.KeyboardKeyCode = key
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("Count", count)
			prompt.Parent = eggPart
			table.insert(prompts[egg.id], prompt)
		end
		addPrompt(1, Enum.KeyCode.E, "Open x1")
		addPrompt(3, Enum.KeyCode.R, "Open x3 (Triple Hatch)")
	end
	return prompts
end

local function buildLeaderboard(map: Folder): SurfaceGui
	local board = part({
		Name = "Leaderboard",
		Size = Vector3.new(1, 34, 26),
		Position = Vector3.new(-LOBBY_SIZE / 2 + 6, GROUND_Y + 18, 30),
		Color = Color3.fromRGB(25, 25, 35),
		Parent = map,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.1, 0)
	title.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	title.Text = "🏆 TOP WINS (ALL-TIME)"
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = gui

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Size = UDim2.new(1, -20, 0.88, 0)
	list.Position = UDim2.new(0, 10, 0.11, 0)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list
	return gui
end

export type Map = {
	eggPrompts: { [string]: { ProximityPrompt } },
	leaderboard: SurfaceGui,
	roundLabel: TextLabel,
}

function MapBuilder.Build(): Map
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	local roundLabel = buildLobby(map)
	buildTrack(map)
	local eggPrompts = buildEggs(map)
	local leaderboard = buildLeaderboard(map)
	map.Parent = workspace

	return {
		eggPrompts = eggPrompts,
		leaderboard = leaderboard,
		roundLabel = roundLabel,
	}
end

return MapBuilder
