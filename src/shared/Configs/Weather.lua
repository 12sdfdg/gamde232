-- Weather types. Lighting fields are applied on top of the current world's lighting profile.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Weather = {}

Weather.List = {
	{ Name = "Clear", Weight = 40, Multiplier = 1, Icon = "☀️", Color = rgb(255, 214, 80),
		Description = "Calm skies.", Particles = "Motes" },
	{ Name = "Rain", Weight = 18, Multiplier = 1.25, Icon = "🌧️", Color = rgb(90, 170, 255),
		Description = "+25% EXP & Coins", Particles = "Rain",
		Lighting = { Brightness = -1.1, Saturation = -0.12, Tint = rgb(214, 228, 246), Density = 0.12, Haze = 0.8, CloudCover = 0.86, CloudColor = rgb(170, 180, 196) } },
	{ Name = "Storm", Weight = 10, Multiplier = 1.6, Icon = "⛈️", Color = rgb(170, 120, 255),
		Description = "+60% Coins. Lightning strikes!", Particles = "Rain", Lightning = true,
		Lighting = { Brightness = -1.6, Saturation = -0.2, Tint = rgb(190, 196, 226), Density = 0.2, Haze = 1.2, CloudCover = 0.95, CloudColor = rgb(110, 116, 140) } },
	{ Name = "Fog", Weight = 14, Multiplier = 1.15, Icon = "🌫️", Color = rgb(200, 210, 220),
		Description = "+15% rewards", Particles = "Motes",
		Lighting = { Brightness = -0.5, Saturation = -0.15, Tint = rgb(236, 240, 246), Density = 0.3, Haze = 2.6, CloudCover = 0.8, CloudColor = rgb(230, 236, 240) } },
	{ Name = "Golden", Weight = 10, Multiplier = 2, Icon = "✨", Color = rgb(255, 200, 40),
		Description = "x2 Coins! Golden hour.", Particles = "Gold",
		Lighting = { ClockTime = 17.4, Brightness = 0.2, Saturation = 0.1, Tint = rgb(255, 228, 170), Density = 0.05, Haze = 0.6, CloudColor = rgb(255, 220, 160), Bloom = 0.25 } },
	{ Name = "Eclipse", Weight = 8, Multiplier = 3, Icon = "🌑", Color = rgb(255, 60, 90),
		Description = "x3 rewards! Darkness falls.", Particles = "Eclipse",
		Lighting = { ClockTime = 21.5, Brightness = -0.6, Saturation = 0.15, Tint = rgb(255, 170, 190), Density = 0.1, Haze = 1.2, CloudCover = 0.7, CloudColor = rgb(120, 40, 70), Bloom = 0.4, Ambient = rgb(140, 60, 90) } },
}

Weather.ByName = {}
for _, w in ipairs(Weather.List) do
	Weather.ByName[w.Name] = w
end

return Weather
