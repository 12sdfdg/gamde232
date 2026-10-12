-- World definitions: placement, unlock costs, palettes and lighting profiles.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Worlds = {}

-- Shared island layout (offsets from world Origin). Every island uses the same readable structure.
Worlds.Layout = {
	Radius = 390,
	Spawn = Vector3.new(0, 0, 205),
	SpawnLook = Vector3.new(-150, 0, -60),
	Plaza = Vector3.new(0, 0, 0),
	Shop = Vector3.new(-52, 0, 142),
	Rewards = Vector3.new(52, 0, 142),
	Portal = Vector3.new(78, 0, 70),
	Dock = Vector3.new(-345, 0, -75),
	Zones = {
		East = { Center = Vector3.new(180, 0, 15), Radius = 50 },
		North = { Center = Vector3.new(-10, 0, -200), Radius = 52 },
		Boss = { Center = Vector3.new(245, 0, -245), Radius = 42 },
	},
	-- Roads are poly-lines that get smoothed by the builder.
	Roads = {
		{ Vector3.new(0, 0, 225), Vector3.new(18, 0, 150), Vector3.new(-14, 0, 70), Vector3.new(0, 0, 22) },
		{ Vector3.new(26, 0, 6), Vector3.new(80, 0, 22), Vector3.new(130, 0, 8) },
		{ Vector3.new(-6, 0, -26), Vector3.new(16, 0, -90), Vector3.new(-10, 0, -145) },
		{ Vector3.new(40, 0, -205), Vector3.new(110, 0, -225), Vector3.new(160, 0, -232), Vector3.new(205, 0, -240) },
		{ Vector3.new(-24, 0, -10), Vector3.new(-90, 0, -55), Vector3.new(-190, 0, -60), Vector3.new(-280, 0, -80), Vector3.new(-345, 0, -75) },
		{ Vector3.new(-52, 0, 130), Vector3.new(-20, 0, 120) },
		{ Vector3.new(52, 0, 130), Vector3.new(24, 0, 120) },
	},
	-- Rock passage (cave/arch) on the way to the boss arena.
	Passage = { Center = Vector3.new(135, 0, -230), Direction = Vector3.new(1, 0, -0.12) },
}

Worlds.List = {
	{
		Id = 1,
		Name = "Green Sky Island",
		Origin = Vector3.new(0, 0, 0),
		UnlockCost = 0,
		RequiredLevel = 1,
		SummonCost = 120,
		Theme = "Grass",
		Zones = { East = { "slimo", "slimo", "slimo", "deckthug", "slimo", "deckthug" }, North = { "deckthug", "buggo", "deckthug", "buggo", "deckthug" }, Boss = { "kragg" } },
		Palette = {
			Top = Enum.Material.Grass, TopColor = rgb(98, 206, 74),
			Under = Enum.Material.Rock, UnderColor = rgb(214, 222, 230),
			Road = Enum.Material.Ground, RoadColor = rgb(214, 178, 122),
			Rock = rgb(238, 240, 244), RockShade = rgb(196, 204, 214),
			Leaf = rgb(46, 132, 58), Leaf2 = rgb(78, 176, 72), Trunk = rgb(70, 52, 46),
			Flowers = { rgb(255, 255, 255), rgb(255, 214, 70), rgb(255, 120, 170), rgb(150, 120, 255) },
			Accent = rgb(80, 220, 255),
		},
		Lighting = {
			ClockTime = 14.3, Brightness = 3.1, ExposureCompensation = 0.12,
			Ambient = rgb(110, 128, 150), OutdoorAmbient = rgb(150, 172, 196),
			Atmosphere = { Color = rgb(196, 240, 255), Decay = rgb(92, 190, 255), Density = 0.28, Offset = 0.18, Glare = 1.4, Haze = 1.3 },
			CC = { TintColor = rgb(250, 254, 255), Saturation = 0.28, Contrast = 0.1, Brightness = 0.02 },
			Bloom = { Intensity = 0.55, Size = 28, Threshold = 1.55 },
			SunRays = { Intensity = 0.11, Spread = 0.8 },
			Clouds = { Cover = 0.62, Density = 0.72, Color = rgb(255, 255, 255) },
			CloudSea = rgb(255, 255, 255),
		},
	},
	{
		Id = 2,
		Name = "Desert Kingdom",
		Origin = Vector3.new(3200, 0, 0),
		UnlockCost = 25000,
		RequiredLevel = 6,
		SummonCost = 2500,
		Theme = "Desert",
		Zones = { East = { "scarab", "scarab", "scarab", "sandbandit", "scarab", "sandbandit" }, North = { "sandbandit", "mummyguard", "sandbandit", "mummyguard", "sandbandit" }, Boss = { "pharaok" } },
		Palette = {
			Top = Enum.Material.Sand, TopColor = rgb(240, 206, 140),
			Under = Enum.Material.Sandstone, UnderColor = rgb(214, 150, 96),
			Road = Enum.Material.Pavement, RoadColor = rgb(250, 236, 200),
			Rock = rgb(232, 176, 116), RockShade = rgb(196, 132, 84),
			Leaf = rgb(70, 150, 70), Leaf2 = rgb(110, 190, 80), Trunk = rgb(150, 110, 70),
			Flowers = { rgb(255, 120, 80), rgb(255, 220, 90), rgb(120, 200, 120) },
			Accent = rgb(255, 200, 60),
		},
		Lighting = {
			ClockTime = 15.6, Brightness = 3.4, ExposureCompensation = 0.1,
			Ambient = rgb(150, 120, 96), OutdoorAmbient = rgb(200, 170, 130),
			Atmosphere = { Color = rgb(255, 222, 170), Decay = rgb(255, 170, 90), Density = 0.32, Offset = 0.2, Glare = 1.8, Haze = 1.8 },
			CC = { TintColor = rgb(255, 244, 226), Saturation = 0.22, Contrast = 0.1, Brightness = 0.02 },
			Bloom = { Intensity = 0.6, Size = 30, Threshold = 1.5 },
			SunRays = { Intensity = 0.14, Spread = 0.9 },
			Clouds = { Cover = 0.4, Density = 0.5, Color = rgb(255, 236, 210) },
			CloudSea = rgb(255, 232, 200),
		},
	},
	{
		Id = 3,
		Name = "Frozen Mountains",
		Origin = Vector3.new(6400, 0, 0),
		UnlockCost = 400000,
		RequiredLevel = 15,
		SummonCost = 40000,
		Theme = "Frozen",
		Zones = { East = { "snowpup", "snowpup", "snowpup", "iceraider", "snowpup", "iceraider" }, North = { "iceraider", "frostgolem", "iceraider", "frostgolem", "iceraider" }, Boss = { "yetiking" } },
		Palette = {
			Top = Enum.Material.Snow, TopColor = rgb(244, 250, 255),
			Under = Enum.Material.Glacier, UnderColor = rgb(150, 210, 245),
			Road = Enum.Material.Slate, RoadColor = rgb(150, 170, 196),
			Rock = rgb(214, 232, 248), RockShade = rgb(150, 186, 220),
			Leaf = rgb(40, 96, 84), Leaf2 = rgb(240, 248, 255), Trunk = rgb(70, 56, 54),
			Flowers = { rgb(170, 220, 255), rgb(255, 255, 255) },
			Accent = rgb(120, 210, 255),
		},
		Lighting = {
			ClockTime = 9.4, Brightness = 2.9, ExposureCompensation = 0.05,
			Ambient = rgb(120, 140, 170), OutdoorAmbient = rgb(170, 190, 220),
			Atmosphere = { Color = rgb(210, 232, 255), Decay = rgb(130, 170, 230), Density = 0.36, Offset = 0.22, Glare = 0.8, Haze = 2.0 },
			CC = { TintColor = rgb(236, 246, 255), Saturation = 0.12, Contrast = 0.08, Brightness = 0.03 },
			Bloom = { Intensity = 0.6, Size = 26, Threshold = 1.6 },
			SunRays = { Intensity = 0.08, Spread = 0.7 },
			Clouds = { Cover = 0.75, Density = 0.8, Color = rgb(235, 245, 255) },
			CloudSea = rgb(235, 245, 255),
		},
	},
	{
		Id = 4,
		Name = "Dark City",
		Origin = Vector3.new(9600, 0, 0),
		UnlockCost = 6000000,
		RequiredLevel = 25,
		SummonCost = 600000,
		Theme = "City",
		Zones = { East = { "glitch", "glitch", "glitch", "streetboss", "glitch", "streetboss" }, North = { "streetboss", "voidstalker", "streetboss", "voidstalker", "streetboss" }, Boss = { "overlord" } },
		Palette = {
			Top = Enum.Material.Asphalt, TopColor = rgb(52, 50, 66),
			Under = Enum.Material.Basalt, UnderColor = rgb(40, 36, 52),
			Road = Enum.Material.Concrete, RoadColor = rgb(96, 92, 116),
			Rock = rgb(70, 66, 90), RockShade = rgb(44, 40, 60),
			Leaf = rgb(120, 40, 170), Leaf2 = rgb(255, 60, 170), Trunk = rgb(30, 26, 36),
			Flowers = { rgb(60, 255, 230), rgb(255, 60, 200) },
			Accent = rgb(255, 50, 160),
		},
		Lighting = {
			ClockTime = 19.4, Brightness = 2.2, ExposureCompensation = 0.25,
			Ambient = rgb(90, 70, 120), OutdoorAmbient = rgb(110, 90, 150),
			Atmosphere = { Color = rgb(150, 110, 200), Decay = rgb(90, 40, 140), Density = 0.4, Offset = 0.25, Glare = 0.5, Haze = 2.2 },
			CC = { TintColor = rgb(236, 226, 255), Saturation = 0.3, Contrast = 0.16, Brightness = 0.02 },
			Bloom = { Intensity = 0.9, Size = 32, Threshold = 1.2 },
			SunRays = { Intensity = 0.05, Spread = 0.6 },
			Clouds = { Cover = 0.55, Density = 0.6, Color = rgb(180, 150, 220) },
			CloudSea = rgb(150, 120, 200),
		},
	},
	{
		Id = 5,
		Name = "Celestial Realm",
		Origin = Vector3.new(12800, 0, 0),
		UnlockCost = 100000000,
		RequiredLevel = 40,
		SummonCost = 10000000,
		Theme = "Celestial",
		Zones = { East = { "sprite", "sprite", "sprite", "fallenangel", "sprite", "fallenangel" }, North = { "fallenangel", "titan", "fallenangel", "titan", "fallenangel" }, Boss = { "archon" } },
		Palette = {
			Top = Enum.Material.LeafyGrass, TopColor = rgb(200, 236, 255),
			Under = Enum.Material.Salt, UnderColor = rgb(250, 246, 255),
			Road = Enum.Material.Cobblestone, RoadColor = rgb(255, 222, 130),
			Rock = rgb(255, 255, 255), RockShade = rgb(226, 220, 248),
			Leaf = rgb(255, 190, 230), Leaf2 = rgb(255, 230, 245), Trunk = rgb(240, 236, 255),
			Flowers = { rgb(255, 230, 120), rgb(200, 170, 255), rgb(255, 255, 255) },
			Accent = rgb(255, 220, 120),
		},
		Lighting = {
			ClockTime = 16.8, Brightness = 3.3, ExposureCompensation = 0.15,
			Ambient = rgb(160, 150, 200), OutdoorAmbient = rgb(200, 190, 240),
			Atmosphere = { Color = rgb(255, 230, 250), Decay = rgb(180, 150, 255), Density = 0.3, Offset = 0.2, Glare = 2.0, Haze = 1.6 },
			CC = { TintColor = rgb(255, 248, 255), Saturation = 0.25, Contrast = 0.08, Brightness = 0.04 },
			Bloom = { Intensity = 0.75, Size = 34, Threshold = 1.35 },
			SunRays = { Intensity = 0.16, Spread = 1 },
			Clouds = { Cover = 0.55, Density = 0.65, Color = rgb(255, 240, 255) },
			CloudSea = rgb(255, 236, 255),
		},
	},
}

Worlds.ById = {}
for _, world in ipairs(Worlds.List) do
	Worlds.ById[world.Id] = world
end

-- Returns which world contains a position (by nearest origin).
function Worlds.FromPosition(position)
	local best, bestDist = Worlds.List[1], math.huge
	for _, world in ipairs(Worlds.List) do
		local d = (Vector3.new(position.X, 0, position.Z) - world.Origin).Magnitude
		if d < bestDist then
			best, bestDist = world, d
		end
	end
	return best
end

return Worlds
