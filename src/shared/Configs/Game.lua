-- Global gameplay constants shared by server and client.
return {
	StartingCoins = 300,
	StartingGems = 50,
	StartingFighters = { "rook", "tessa" },

	MaxInventory = 250,
	BaseEquip = 3,
	MaxEquip = 12,

	AttackRange = 110, -- max distance (character -> enemy) to start an attack
	FighterReach = 7, -- how close fighters must be to deal damage
	CombatTick = 0.25,

	ClickRate = 14, -- max accepted clicks per second
	ClickPowerBase = 1,
	AbilityCooldown = 12,
	AbilityDpsMultiplier = 8,

	AutosaveInterval = 120,
	WeatherDuration = 230,

	SummonPity = 100, -- guaranteed Legendary+ after this many opens
	SummonGemCost = 60,
	FreeGemsInterval = 600,
	FreeGemsAmount = 25,

	FighterMaxLevel = 10,
	SwordDamageBonus = 0.05,

	EnemyResetTime = 12, -- seconds without hits before an enemy heals back
}
