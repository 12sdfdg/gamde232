-- Enemy definitions. Loot "Chance" is 0..1. Coins/Exp are base values (scaled by multipliers on the server).
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local list = {
	-- World 1
	{ Id = "slimo", Name = "Slimo", World = 1, Difficulty = "Easy", Hp = 160, Coins = 14, Exp = 6, Respawn = 4,
		Body = "Slime", Scale = 1.1, Color = rgb(110, 220, 120), Accent = rgb(60, 150, 70),
		Loot = { { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Material", Chance = 0.08 } } },
	{ Id = "deckthug", Name = "Deck Thug", World = 1, Difficulty = "Medium", Hp = 1100, Coins = 70, Exp = 25, Respawn = 6,
		Body = "Pirate", Scale = 1.15, Color = rgb(220, 170, 130), Accent = rgb(120, 40, 40),
		Loot = { { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Material", Chance = 0.15 }, { Item = "Potion_Coins", Chance = 0.02 } } },
	{ Id = "buggo", Name = "Buggo", World = 1, Difficulty = "Hard", Hp = 15000, Coins = 650, Exp = 160, Respawn = 10,
		Body = "Brute", Scale = 1.5, Color = rgb(240, 200, 170), Accent = rgb(230, 60, 60),
		Loot = { { Item = "Sword", Chance = 0.025 }, { Item = "Material", Chance = 0.25 }, { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Potion_Damage", Chance = 0.04 } } },
	{ Id = "kragg", Name = "Captain Kragg", World = 1, Difficulty = "Boss", Hp = 180000, Coins = 9000, Exp = 1500, Respawn = 45, Boss = true,
		Body = "Pirate", Scale = 2.6, Color = rgb(200, 150, 120), Accent = rgb(40, 40, 70),
		Loot = { { Item = "Sword", Chance = 0.15 }, { Item = "Gems", Chance = 0.5, Amount = 25 }, { Item = "Material", Chance = 1, Amount = 3 }, { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Potion_Luck", Chance = 0.1 } } },

	-- World 2
	{ Id = "scarab", Name = "Scarab", World = 2, Difficulty = "Easy", Hp = 2400, Coins = 140, Exp = 40, Respawn = 4,
		Body = "Beast", Scale = 1.1, Color = rgb(60, 140, 160), Accent = rgb(255, 200, 60),
		Loot = { { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Material", Chance = 0.1 } } },
	{ Id = "sandbandit", Name = "Sand Bandit", World = 2, Difficulty = "Medium", Hp = 14000, Coins = 700, Exp = 140, Respawn = 6,
		Body = "Pirate", Scale = 1.2, Color = rgb(190, 130, 90), Accent = rgb(230, 210, 170),
		Loot = { { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Material", Chance = 0.18 }, { Item = "Potion_Coins", Chance = 0.03 } } },
	{ Id = "mummyguard", Name = "Mummy Guard", World = 2, Difficulty = "Hard", Hp = 160000, Coins = 6500, Exp = 900, Respawn = 10,
		Body = "Brute", Scale = 1.6, Color = rgb(230, 220, 190), Accent = rgb(255, 200, 40),
		Loot = { { Item = "Sword", Chance = 0.03 }, { Item = "Material", Chance = 0.3 }, { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Potion_Damage", Chance = 0.05 } } },
	{ Id = "pharaok", Name = "Pharaoh Ankor", World = 2, Difficulty = "Boss", Hp = 2200000, Coins = 95000, Exp = 9000, Respawn = 45, Boss = true,
		Body = "Golem", Scale = 2.7, Color = rgb(255, 210, 90), Accent = rgb(40, 70, 160),
		Loot = { { Item = "Sword", Chance = 0.15 }, { Item = "Gems", Chance = 0.5, Amount = 40 }, { Item = "Material", Chance = 1, Amount = 4 }, { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Potion_Luck", Chance = 0.1 } } },

	-- World 3
	{ Id = "snowpup", Name = "Snow Pup", World = 3, Difficulty = "Easy", Hp = 30000, Coins = 1500, Exp = 220, Respawn = 4,
		Body = "Beast", Scale = 1.1, Color = rgb(240, 245, 255), Accent = rgb(120, 190, 255),
		Loot = { { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Material", Chance = 0.1 } } },
	{ Id = "iceraider", Name = "Ice Raider", World = 3, Difficulty = "Medium", Hp = 180000, Coins = 7200, Exp = 700, Respawn = 6,
		Body = "Pirate", Scale = 1.25, Color = rgb(200, 220, 240), Accent = rgb(40, 70, 120),
		Loot = { { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Material", Chance = 0.2 }, { Item = "Potion_Coins", Chance = 0.03 } } },
	{ Id = "frostgolem", Name = "Frost Golem", World = 3, Difficulty = "Hard", Hp = 2000000, Coins = 70000, Exp = 4200, Respawn = 10,
		Body = "Golem", Scale = 1.7, Color = rgb(150, 210, 255), Accent = rgb(230, 250, 255),
		Loot = { { Item = "Sword", Chance = 0.035 }, { Item = "Material", Chance = 0.3 }, { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Potion_Damage", Chance = 0.05 } } },
	{ Id = "yetiking", Name = "Yeti King", World = 3, Difficulty = "Boss", Hp = 28000000, Coins = 1000000, Exp = 45000, Respawn = 45, Boss = true,
		Body = "Brute", Scale = 2.8, Color = rgb(245, 250, 255), Accent = rgb(80, 160, 255),
		Loot = { { Item = "Sword", Chance = 0.15 }, { Item = "Gems", Chance = 0.5, Amount = 60 }, { Item = "Material", Chance = 1, Amount = 5 }, { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Potion_Luck", Chance = 0.1 } } },

	-- World 4
	{ Id = "glitch", Name = "Glitch", World = 4, Difficulty = "Easy", Hp = 380000, Coins = 16000, Exp = 1200, Respawn = 4,
		Body = "Specter", Scale = 1.1, Color = rgb(60, 255, 230), Accent = rgb(255, 60, 200),
		Loot = { { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Material", Chance = 0.1 } } },
	{ Id = "streetboss", Name = "Street Enforcer", World = 4, Difficulty = "Medium", Hp = 2300000, Coins = 80000, Exp = 3800, Respawn = 6,
		Body = "Brute", Scale = 1.4, Color = rgb(120, 110, 130), Accent = rgb(255, 60, 90),
		Loot = { { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Material", Chance = 0.2 }, { Item = "Potion_Coins", Chance = 0.03 } } },
	{ Id = "voidstalker", Name = "Void Stalker", World = 4, Difficulty = "Hard", Hp = 26000000, Coins = 800000, Exp = 22000, Respawn = 10,
		Body = "Specter", Scale = 1.8, Color = rgb(60, 30, 90), Accent = rgb(200, 80, 255),
		Loot = { { Item = "Sword", Chance = 0.04 }, { Item = "Material", Chance = 0.3 }, { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Potion_Damage", Chance = 0.05 } } },
	{ Id = "overlord", Name = "Neon Overlord", World = 4, Difficulty = "Boss", Hp = 360000000, Coins = 11000000, Exp = 230000, Respawn = 45, Boss = true,
		Body = "Golem", Scale = 2.9, Color = rgb(30, 30, 40), Accent = rgb(255, 40, 120),
		Loot = { { Item = "Sword", Chance = 0.15 }, { Item = "Gems", Chance = 0.5, Amount = 80 }, { Item = "Material", Chance = 1, Amount = 6 }, { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Potion_Luck", Chance = 0.1 } } },

	-- World 5
	{ Id = "sprite", Name = "Star Sprite", World = 5, Difficulty = "Easy", Hp = 4500000, Coins = 170000, Exp = 6000, Respawn = 4,
		Body = "Slime", Scale = 1.2, Color = rgb(255, 230, 140), Accent = rgb(255, 180, 255),
		Loot = { { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Material", Chance = 0.1 } } },
	{ Id = "fallenangel", Name = "Fallen Angel", World = 5, Difficulty = "Medium", Hp = 28000000, Coins = 850000, Exp = 19000, Respawn = 6,
		Body = "Specter", Scale = 1.4, Color = rgb(240, 230, 255), Accent = rgb(120, 80, 200),
		Loot = { { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Material", Chance = 0.2 }, { Item = "Potion_Coins", Chance = 0.03 } } },
	{ Id = "titan", Name = "Astral Titan", World = 5, Difficulty = "Insane", Hp = 320000000, Coins = 9000000, Exp = 110000, Respawn = 10,
		Body = "Golem", Scale = 1.9, Color = rgb(120, 140, 255), Accent = rgb(255, 230, 120),
		Loot = { { Item = "Sword", Chance = 0.05 }, { Item = "Material", Chance = 0.35 }, { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Potion_Damage", Chance = 0.06 } } },
	{ Id = "archon", Name = "Archon Sol", World = 5, Difficulty = "Boss", Hp = 4500000000, Coins = 130000000, Exp = 1200000, Respawn = 45, Boss = true,
		Body = "Brute", Scale = 3.0, Color = rgb(255, 245, 220), Accent = rgb(255, 200, 60),
		Loot = { { Item = "Sword", Chance = 0.15 }, { Item = "Gems", Chance = 0.5, Amount = 120 }, { Item = "Material", Chance = 1, Amount = 8 }, { Item = "Coins", Chance = 1 }, { Item = "Star", Chance = 1 }, { Item = "Potion_Luck", Chance = 0.1 } } },
}

local Enemies = { List = list, ById = {} }
for _, def in ipairs(list) do
	Enemies.ById[def.Id] = def
end

Enemies.ItemNames = {
	Coins = "Coins",
	Star = "Star",
	Material = "Material",
	Sword = "Sword",
	Gems = "Gems",
	Potion_Luck = "Luck Potion",
	Potion_Coins = "Coin Potion",
	Potion_Damage = "Damage Potion",
}

Enemies.ItemIcons = {
	Coins = "🪙",
	Star = "⭐",
	Material = "💎",
	Sword = "🗡️",
	Gems = "💠",
	Potion_Luck = "🍀",
	Potion_Coins = "💰",
	Potion_Damage = "⚔️",
}

return Enemies
