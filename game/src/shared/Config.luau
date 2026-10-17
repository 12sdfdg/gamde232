-- Game balance and content. Edit freely: everything else reads from here.
local Config = {}

---------------------------------------------------------------------- map
Config.PlotCount = 6
Config.PlotSize = 140
Config.GroundY = 2 -- top surface of every island
Config.PathWidth = 10
Config.PathClearance = 7.5 -- turrets must be this far from the path centre line
Config.MinTurretSpacing = 5
-- Balloon path in plot-local X/Z (studs), from the cave (start) to the hut (end)
Config.PathPoints = {
	Vector2.new(-55, -50),
	Vector2.new(35, -50),
	Vector2.new(35, -18),
	Vector2.new(-35, -18),
	Vector2.new(-35, 14),
	Vector2.new(35, 14),
	Vector2.new(35, 46),
	Vector2.new(-55, 46),
}

---------------------------------------------------------------------- waves
Config.StartingLives = 20
Config.WaveBaseCount = 6
Config.WaveCountPerWave = 2
Config.WaveMaxCount = 80
Config.SpawnInterval = 0.6
Config.WaveBreak = 2.5
Config.HpGrowth = 1.12 -- balloon HP multiplier per wave
Config.RewardGrowth = 0.08 -- +8% reward per wave
Config.WaveClearBonus = 10 -- coins * wave

---------------------------------------------------------------------- rolling
Config.RollCooldown = 1.5
Config.RareAnnounceChance = 100 -- announce rolls of "1 in 100" or rarer to the server

Config.RarityColors = {
	Common = Color3.fromRGB(205, 205, 205),
	Uncommon = Color3.fromRGB(85, 220, 95),
	Rare = Color3.fromRGB(60, 150, 255),
	Epic = Color3.fromRGB(175, 80, 255),
	Legendary = Color3.fromRGB(255, 190, 30),
	Mythic = Color3.fromRGB(255, 70, 90),
	Divine = Color3.fromRGB(255, 255, 255),
}

-- Sorted from most common to rarest. chance = "1 in N".
Config.Turrets = {
	{ id = "Basic", name = "Basic Turret", chance = 2, rarity = "Common", damage = 4, range = 22, fireRate = 1.0, barrels = 1, color = Color3.fromRGB(120, 130, 150) },
	{ id = "Double", name = "Double Turret", chance = 3, rarity = "Common", damage = 3, range = 22, fireRate = 2.0, barrels = 2, color = Color3.fromRGB(70, 120, 220) },
	{ id = "Modern", name = "Modern Turret", chance = 6, rarity = "Uncommon", damage = 9, range = 26, fireRate = 1.3, barrels = 1, color = Color3.fromRGB(60, 190, 90) },
	{ id = "Sniper", name = "Sniper Turret", chance = 15, rarity = "Rare", damage = 40, range = 60, fireRate = 0.4, barrels = 1, long = true, color = Color3.fromRGB(40, 60, 90) },
	{ id = "Pirate", name = "Pirate Turret", chance = 40, rarity = "Rare", damage = 25, range = 28, fireRate = 1.0, barrels = 1, splash = 9, color = Color3.fromRGB(130, 85, 50) },
	{ id = "Laser", name = "Laser Turret", chance = 120, rarity = "Epic", damage = 14, range = 34, fireRate = 5, barrels = 1, neon = true, color = Color3.fromRGB(255, 60, 200) },
	{ id = "Viking", name = "Viking Turret", chance = 400, rarity = "Epic", damage = 90, range = 30, fireRate = 1.0, barrels = 2, splash = 10, color = Color3.fromRGB(190, 60, 40) },
	{ id = "Ancient", name = "Ancient Turret", chance = 1500, rarity = "Legendary", damage = 180, range = 42, fireRate = 1.5, barrels = 3, neon = true, color = Color3.fromRGB(255, 200, 40) },
	{ id = "Galaxy", name = "Galaxy Turret", chance = 12000, rarity = "Mythic", damage = 500, range = 52, fireRate = 2.0, barrels = 2, neon = true, splash = 12, color = Color3.fromRGB(90, 40, 200) },
	{ id = "Divine", name = "Divine Turret", chance = 150000, rarity = "Divine", damage = 2000, range = 65, fireRate = 2.5, barrels = 3, neon = true, splash = 14, color = Color3.fromRGB(255, 250, 220) },
}

-- Sorted from most common to rarest.
Config.Balloons = {
	{ id = "Red", name = "Red Balloon", chance = 1, hp = 10, reward = 2, speed = 9, color = Color3.fromRGB(235, 40, 50) },
	{ id = "Blue", name = "Blue Balloon", chance = 4, hp = 25, reward = 6, speed = 10, color = Color3.fromRGB(40, 110, 240) },
	{ id = "Green", name = "Green Balloon", chance = 10, hp = 60, reward = 15, speed = 11, color = Color3.fromRGB(50, 200, 70) },
	{ id = "Yellow", name = "Yellow Balloon", chance = 30, hp = 150, reward = 40, speed = 13, color = Color3.fromRGB(255, 215, 30) },
	{ id = "Pink", name = "Pink Balloon", chance = 100, hp = 400, reward = 120, speed = 14, color = Color3.fromRGB(255, 100, 190) },
	{ id = "Black", name = "Black Balloon", chance = 500, hp = 1500, reward = 500, speed = 8, size = 1.3, lives = 3, color = Color3.fromRGB(30, 30, 35) },
	{ id = "Rainbow", name = "Rainbow Balloon", chance = 5000, hp = 6000, reward = 3000, speed = 11, size = 1.4, lives = 5, rainbow = true, color = Color3.fromRGB(255, 0, 0) },
	{ id = "Golden", name = "Golden Balloon", chance = 50000, hp = 25000, reward = 25000, speed = 9, size = 1.5, lives = 8, golden = true, color = Color3.fromRGB(255, 200, 40) },
	{ id = "Mystery", name = "??? Balloon", chance = 52995392255, hp = 1000000, reward = 100000000, speed = 5, size = 2.2, lives = 20, mystery = true, color = Color3.fromRGB(245, 245, 250) },
}

---------------------------------------------------------------------- upgrades (skill tree)
-- effect keys are interpreted by Config.GetStats below
Config.Upgrades = {
	{ id = "CoinsI", name = "Coins I", icon = "💰", desc = "+25% coins", cost = 250, effect = { coins = 0.25 } },
	{ id = "LuckI", name = "Luck I", icon = "🍀", desc = "x1.5 luck", cost = 400, effect = { luck = 1.5 } },
	{ id = "RollSpeedI", name = "Roll Speed I", icon = "🎲", desc = "Roll 30% faster", cost = 600, effect = { roll = 0.7 } },
	{ id = "DamageI", name = "Damage I", icon = "💥", desc = "+25% turret damage", cost = 800, effect = { damage = 0.25 } },
	{ id = "AutoRoll", name = "Auto Roll", icon = "🔁", desc = "Unlock auto rolling", cost = 1500, requires = "RollSpeedI", effect = { autoRoll = true } },
	{ id = "CoinsII", name = "Coins II", icon = "💰", desc = "+50% coins", cost = 2500, requires = "CoinsI", effect = { coins = 0.5 } },
	{ id = "SlotsI", name = "Slots I", icon = "🧱", desc = "+4 turret slots", cost = 3000, effect = { slots = 4 } },
	{ id = "LuckII", name = "Luck II", icon = "🍀", desc = "x2 luck", cost = 5000, requires = "LuckI", effect = { luck = 2 } },
	{ id = "WaveSpeed", name = "X2 Wave Speed", icon = "⏩", desc = "Waves come twice as fast", cost = 5000, effect = { waveSpeed = 2 } },
	{ id = "BonusI", name = "Bonus I", icon = "🎁", desc = "x2 wave clear bonus", cost = 10000, requires = "CoinsII", effect = { bonus = 1 } },
	{ id = "DamageII", name = "Damage II", icon = "💥", desc = "+50% turret damage", cost = 12000, requires = "DamageI", effect = { damage = 0.5 } },
	{ id = "RollSpeedII", name = "Roll Speed II", icon = "🎲", desc = "Roll 40% faster", cost = 15000, requires = "RollSpeedI", effect = { roll = 0.6 } },
	{ id = "SlotsII", name = "Slots II", icon = "🧱", desc = "+6 turret slots", cost = 20000, requires = "SlotsI", effect = { slots = 6 } },
	{ id = "LuckIII", name = "Luck III", icon = "🍀", desc = "x3 luck", cost = 50000, requires = "LuckII", effect = { luck = 3 } },
	{ id = "CoinsIII", name = "Coins III", icon = "💰", desc = "+100% coins", cost = 100000, requires = "CoinsII", effect = { coins = 1 } },
}

Config.BaseMaxTurrets = 8
Config.SwordDamage = 6

---------------------------------------------------------------------- sounds
-- Built-in Roblox sounds as fallbacks. Upload the SFX pack (sfx_pack/ogg) to
-- Roblox and paste the rbxassetid://... ids here to use the custom sounds.
Config.Sounds = {
	Pop = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Roll = "rbxasset://sounds/clickfast.wav",
	RareRoll = "rbxasset://sounds/electronicpingshort.wav",
	Slash = "rbxasset://sounds/swordslash.wav",
	Place = "rbxasset://sounds/button.wav",
	WaveClear = "",
	Buy = "rbxasset://sounds/electronicpingshort.wav",
	Lose = "",
}

---------------------------------------------------------------------- helpers
local byId = {}
for _, list in { Config.Turrets, Config.Balloons, Config.Upgrades } do
	for _, def in list do
		byId[def.id] = def
	end
end

function Config.Get(id)
	return byId[id]
end

-- Combined effect of owned upgrades. `owned` is a set { [upgradeId] = true }.
function Config.GetStats(owned)
	local stats = {
		coinMult = 1,
		luck = 1,
		rollCooldown = Config.RollCooldown,
		damageMult = 1,
		maxTurrets = Config.BaseMaxTurrets,
		waveSpeed = 1,
		bonusMult = 1,
		autoRoll = false,
	}
	for _, up in Config.Upgrades do
		if owned and owned[up.id] then
			local e = up.effect
			if e.coins then stats.coinMult += e.coins end
			if e.luck then stats.luck *= e.luck end
			if e.roll then stats.rollCooldown *= e.roll end
			if e.damage then stats.damageMult += e.damage end
			if e.slots then stats.maxTurrets += e.slots end
			if e.waveSpeed then stats.waveSpeed *= e.waveSpeed end
			if e.bonus then stats.bonusMult += e.bonus end
			if e.autoRoll then stats.autoRoll = true end
		end
	end
	return stats
end

return Config
