local Rarities = {}

Rarities.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarities.Info = {
	Common = { Rank = 1, Weight = 60, Sell = 10, Color = Color3.fromRGB(176, 184, 196), Dark = Color3.fromRGB(70, 76, 88) },
	Rare = { Rank = 2, Weight = 27, Sell = 40, Color = Color3.fromRGB(62, 152, 255), Dark = Color3.fromRGB(18, 58, 130) },
	Epic = { Rank = 3, Weight = 9.5, Sell = 150, Color = Color3.fromRGB(184, 86, 255), Dark = Color3.fromRGB(70, 20, 120) },
	Legendary = { Rank = 4, Weight = 2.9, Sell = 600, Color = Color3.fromRGB(255, 166, 28), Dark = Color3.fromRGB(130, 64, 0) },
	Mythic = { Rank = 5, Weight = 0.55, Sell = 2500, Color = Color3.fromRGB(255, 58, 120), Dark = Color3.fromRGB(120, 10, 50) },
	Secret = { Rank = 6, Weight = 0.05, Sell = 20000, Color = Color3.fromRGB(255, 255, 255), Dark = Color3.fromRGB(10, 10, 16) },
}

-- Rainbow sequence used for Secret rarity text/strokes.
Rarities.SecretGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
})

Rarities.Difficulty = {
	Easy = Color3.fromRGB(110, 230, 90),
	Medium = Color3.fromRGB(255, 220, 70),
	Hard = Color3.fromRGB(255, 120, 50),
	Insane = Color3.fromRGB(200, 70, 255),
	Boss = Color3.fromRGB(255, 50, 70),
}

function Rarities.Rank(name)
	local info = Rarities.Info[name]
	return info and info.Rank or 0
end

return Rarities
