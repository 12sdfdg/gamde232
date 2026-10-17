--!strict
-- Central, data-driven definitions for Pop a Balloon RNG.
-- Everything balance-related lives here so designers can tune without touching logic.

local Config = {}

Config.Economy = {
	startCash = 300,
	rollCooldown = 1.1, -- seconds between rolls
	baseHealth = 100, -- shared base HP; balloons that leak subtract their damage
	waveBonus = 40, -- cash granted to every player when a wave is cleared
	intermission = 4, -- seconds between waves
}

-- Rarity is expressed as "1 in N". Roll weight is 1/N, so lower chance = rarer turret.
-- color is the turret's accent color; damage/range/cooldown drive combat.
Config.Turrets = {
	Old = {
		name = "Old Turret",
		oneIn = 2,
		damage = 8,
		range = 34,
		cooldown = 0.65,
		color = Color3.fromRGB(150, 150, 150),
	},
	Modern = {
		name = "Modern Turret",
		oneIn = 3,
		damage = 14,
		range = 40,
		cooldown = 0.55,
		color = Color3.fromRGB(90, 170, 255),
	},
	Heavy = {
		name = "Heavy Turret",
		oneIn = 5,
		damage = 32,
		range = 38,
		cooldown = 0.9,
		color = Color3.fromRGB(240, 170, 60),
	},
	Laser = {
		name = "Laser Turret",
		oneIn = 10,
		damage = 55,
		range = 48,
		cooldown = 0.4,
		color = Color3.fromRGB(255, 70, 90),
	},
	Plasma = {
		name = "Plasma Turret",
		oneIn = 25,
		damage = 120,
		range = 52,
		cooldown = 0.5,
		color = Color3.fromRGB(180, 90, 255),
	},
	Rail = {
		name = "Rail Turret",
		oneIn = 100,
		damage = 500,
		range = 70,
		cooldown = 1.1,
		color = Color3.fromRGB(80, 255, 210),
	},
}

-- Ordered list used by the UI (common -> rare).
Config.TurretOrder = { "Old", "Modern", "Heavy", "Laser", "Plasma", "Rail" }

-- Balloon archetypes. hp/reward are the wave-1 base values; WaveService scales them up.
Config.Balloons = {
	Red = { name = "Red Balloon", hp = 45, speed = 14, reward = 5, damage = 1, color = Color3.fromRGB(230, 50, 50), size = 3 },
	Blue = { name = "Blue Balloon", hp = 110, speed = 16, reward = 9, damage = 1, color = Color3.fromRGB(60, 120, 255), size = 3.2 },
	Green = { name = "Green Balloon", hp = 260, speed = 12, reward = 16, damage = 2, color = Color3.fromRGB(60, 200, 90), size = 3.6 },
	Boss = { name = "Boss Balloon", hp = 2200, speed = 8, reward = 120, damage = 10, color = Color3.fromRGB(40, 40, 40), size = 6 },
}

-- Placement rules.
Config.Placement = {
	minSpacing = 7, -- min distance between two turret bases
	pathClearance = 7, -- turrets cannot be placed closer than this to the path
}

return Config
