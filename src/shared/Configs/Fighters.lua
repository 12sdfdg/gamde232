-- All fighters (original characters). Look data drives the procedural anime rig in Modules/Rig.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local SKIN_LIGHT = rgb(255, 222, 196)
local SKIN_TAN = rgb(232, 182, 140)
local SKIN_DARK = rgb(150, 98, 70)
local SKIN_PALE = rgb(246, 232, 226)

local list = {
	-- ===== World 1: Green Sky Island (sky pirates) =====
	{ Id = "rook", Name = "Rook", Rarity = "Common", World = 1, Dps = 4,
		Passive = { Type = "Coins", Value = 0.03, Text = "+3% Coins" },
		Look = { skin = SKIN_TAN, hair = rgb(60, 40, 30), hairStyle = "Short", top = rgb(235, 235, 235), bottom = rgb(60, 80, 140), accent = rgb(200, 40, 40), eyes = rgb(60, 40, 30), outfit = "Tee", acc = { "Bandana" }, weapon = "Fists" } },
	{ Id = "tessa", Name = "Tessa", Rarity = "Common", World = 1, Dps = 5,
		Passive = { Type = "Exp", Value = 0.03, Text = "+3% EXP" },
		Look = { skin = SKIN_LIGHT, hair = rgb(255, 140, 60), hairStyle = "Ponytail", top = rgb(90, 160, 220), bottom = rgb(240, 220, 170), accent = rgb(255, 255, 255), eyes = rgb(40, 120, 200), outfit = "Vest", acc = {}, weapon = "Staff" } },
	{ Id = "ren", Name = "Ren Kurogane", Rarity = "Rare", World = 1, Dps = 11,
		Passive = { Type = "Damage", Value = 0.05, Text = "+5% Damage" },
		Look = { skin = SKIN_TAN, hair = rgb(60, 190, 110), hairStyle = "Short", top = rgb(245, 245, 245), bottom = rgb(30, 30, 36), accent = rgb(40, 140, 70), eyes = rgb(30, 30, 30), outfit = "Robe", acc = { "Headband" }, weapon = "Katana" } },
	{ Id = "lio", Name = "Lio Blaze", Rarity = "Epic", World = 1, Dps = 26,
		Passive = { Type = "Damage", Value = 0.1, Text = "+10% Damage" },
		Look = { skin = SKIN_LIGHT, hair = rgb(255, 222, 90), hairStyle = "Slick", top = rgb(30, 32, 44), bottom = rgb(30, 32, 44), accent = rgb(255, 120, 40), eyes = rgb(60, 140, 255), outfit = "Suit", acc = {}, weapon = "Fists", aura = rgb(255, 120, 40) } },
	{ Id = "mirae", Name = "Captain Mirae", Rarity = "Legendary", World = 1, Dps = 70,
		Passive = { Type = "Coins", Value = 0.2, Text = "+20% Coins" },
		Look = { skin = SKIN_LIGHT, hair = rgb(40, 30, 60), hairStyle = "Long", top = rgb(170, 30, 40), bottom = rgb(40, 34, 30), accent = rgb(255, 200, 60), eyes = rgb(200, 40, 60), outfit = "Coat", acc = { "Captain" }, weapon = "Sword", aura = rgb(255, 200, 60) } },
	{ Id = "oceanus", Name = "Oceanus", Rarity = "Mythic", World = 1, Dps = 190,
		Passive = { Type = "Damage", Value = 0.3, Text = "+30% Damage" },
		Look = { skin = SKIN_TAN, hair = rgb(80, 220, 255), hairStyle = "Wild", top = rgb(20, 70, 140), bottom = rgb(240, 240, 250), accent = rgb(80, 220, 255), eyes = rgb(80, 220, 255), outfit = "Armor", acc = { "Crown", "Cape" }, weapon = "Trident", aura = rgb(80, 220, 255) } },
	{ Id = "zephyr", Name = "Zephyr Prime", Rarity = "Secret", World = 1, Dps = 650,
		Passive = { Type = "Luck", Value = 0.25, Text = "+25% Luck" },
		Look = { skin = SKIN_PALE, hair = rgb(250, 250, 255), hairStyle = "Spiky", top = rgb(250, 250, 255), bottom = rgb(120, 220, 210), accent = rgb(120, 255, 220), eyes = rgb(120, 255, 220), outfit = "Robe", acc = { "Halo", "Cape" }, weapon = "Spear", aura = rgb(150, 255, 230) } },

	-- ===== World 2: Desert Kingdom =====
	{ Id = "sandor", Name = "Sandor", Rarity = "Common", World = 2, Dps = 30,
		Passive = { Type = "Coins", Value = 0.04, Text = "+4% Coins" },
		Look = { skin = SKIN_DARK, hair = rgb(30, 25, 20), hairStyle = "Short", top = rgb(230, 200, 150), bottom = rgb(160, 110, 70), accent = rgb(200, 60, 40), eyes = rgb(50, 30, 20), outfit = "Tee", acc = { "Headband" }, weapon = "Fists" } },
	{ Id = "amira", Name = "Amira", Rarity = "Common", World = 2, Dps = 34,
		Passive = { Type = "Exp", Value = 0.04, Text = "+4% EXP" },
		Look = { skin = SKIN_TAN, hair = rgb(40, 20, 30), hairStyle = "Long", top = rgb(60, 180, 170), bottom = rgb(240, 220, 180), accent = rgb(255, 210, 80), eyes = rgb(40, 160, 140), outfit = "Robe", acc = {}, weapon = "Staff" } },
	{ Id = "khepri", Name = "Khepri", Rarity = "Rare", World = 2, Dps = 70,
		Passive = { Type = "Damage", Value = 0.06, Text = "+6% Damage" },
		Look = { skin = SKIN_DARK, hair = rgb(20, 20, 30), hairStyle = "Slick", top = rgb(250, 240, 220), bottom = rgb(40, 60, 140), accent = rgb(255, 200, 40), eyes = rgb(255, 200, 40), outfit = "Armor", acc = { "Mask" }, weapon = "Spear" } },
	{ Id = "rashid", Name = "Rashid", Rarity = "Epic", World = 2, Dps = 160,
		Passive = { Type = "Coins", Value = 0.12, Text = "+12% Coins" },
		Look = { skin = SKIN_TAN, hair = rgb(240, 240, 240), hairStyle = "Spiky", top = rgb(140, 30, 50), bottom = rgb(250, 230, 190), accent = rgb(255, 210, 60), eyes = rgb(255, 80, 60), outfit = "Vest", acc = { "Scarf" }, weapon = "Sword", aura = rgb(255, 120, 60) } },
	{ Id = "azar", Name = "Sultan Azar", Rarity = "Legendary", World = 2, Dps = 420,
		Passive = { Type = "Luck", Value = 0.12, Text = "+12% Luck" },
		Look = { skin = SKIN_DARK, hair = rgb(30, 20, 20), hairStyle = "Long", top = rgb(90, 40, 160), bottom = rgb(250, 240, 230), accent = rgb(255, 210, 60), eyes = rgb(255, 210, 60), outfit = "Coat", acc = { "Crown", "Cape" }, weapon = "Scythe", aura = rgb(255, 210, 60) } },
	{ Id = "rakun", Name = "Sunfire Ra'kun", Rarity = "Mythic", World = 2, Dps = 1150,
		Passive = { Type = "Damage", Value = 0.32, Text = "+32% Damage" },
		Look = { skin = SKIN_TAN, hair = rgb(255, 110, 30), hairStyle = "Wild", top = rgb(255, 200, 60), bottom = rgb(120, 30, 20), accent = rgb(255, 90, 20), eyes = rgb(255, 230, 120), outfit = "Armor", acc = { "Horns", "Cape" }, weapon = "Spear", aura = rgb(255, 120, 20) } },
	{ Id = "mirage", Name = "Mirage", Rarity = "Secret", World = 2, Dps = 3900,
		Passive = { Type = "Coins", Value = 0.5, Text = "+50% Coins" },
		Look = { skin = SKIN_PALE, hair = rgb(255, 180, 230), hairStyle = "Long", top = rgb(255, 240, 250), bottom = rgb(255, 180, 230), accent = rgb(255, 120, 220), eyes = rgb(255, 120, 220), outfit = "Robe", acc = { "Halo", "Mask" }, weapon = "Staff", aura = rgb(255, 150, 230) } },

	-- ===== World 3: Frozen Mountains =====
	{ Id = "bjorn", Name = "Bjorn", Rarity = "Common", World = 3, Dps = 190,
		Passive = { Type = "Power", Value = 0.05, Text = "+5% Power" },
		Look = { skin = SKIN_LIGHT, hair = rgb(200, 110, 50), hairStyle = "Wild", top = rgb(120, 80, 60), bottom = rgb(70, 60, 50), accent = rgb(230, 230, 230), eyes = rgb(80, 140, 200), outfit = "Coat", acc = { "Horns" }, weapon = "Fists" } },
	{ Id = "yuki", Name = "Yuki", Rarity = "Common", World = 3, Dps = 210,
		Passive = { Type = "Exp", Value = 0.05, Text = "+5% EXP" },
		Look = { skin = SKIN_PALE, hair = rgb(180, 220, 255), hairStyle = "Short", top = rgb(240, 245, 255), bottom = rgb(60, 90, 160), accent = rgb(120, 190, 255), eyes = rgb(80, 160, 255), outfit = "Hoodie", acc = { "Scarf" }, weapon = "Katana" } },
	{ Id = "frosthunter", Name = "Frost Hunter", Rarity = "Rare", World = 3, Dps = 430,
		Passive = { Type = "Damage", Value = 0.07, Text = "+7% Damage" },
		Look = { skin = SKIN_LIGHT, hair = rgb(40, 50, 70), hairStyle = "Spiky", top = rgb(50, 70, 100), bottom = rgb(30, 36, 50), accent = rgb(140, 220, 255), eyes = rgb(140, 220, 255), outfit = "Coat", acc = { "Goggles" }, weapon = "Spear" } },
	{ Id = "glacia", Name = "Glacia", Rarity = "Epic", World = 3, Dps = 980,
		Passive = { Type = "Luck", Value = 0.08, Text = "+8% Luck" },
		Look = { skin = SKIN_PALE, hair = rgb(120, 200, 255), hairStyle = "Long", top = rgb(220, 240, 255), bottom = rgb(120, 200, 255), accent = rgb(255, 255, 255), eyes = rgb(120, 200, 255), outfit = "Robe", acc = { "Crown" }, weapon = "Staff", aura = rgb(160, 220, 255) } },
	{ Id = "kaze", Name = "Kaze Shiro", Rarity = "Legendary", World = 3, Dps = 2600,
		Passive = { Type = "Damage", Value = 0.18, Text = "+18% Damage" },
		Look = { skin = SKIN_LIGHT, hair = rgb(245, 245, 250), hairStyle = "Spiky", top = rgb(30, 34, 48), bottom = rgb(30, 34, 48), accent = rgb(120, 200, 255), eyes = rgb(120, 200, 255), outfit = "Coat", acc = { "Scarf" }, weapon = "Katana", aura = rgb(120, 200, 255) } },
	{ Id = "aurora", Name = "Aurora", Rarity = "Mythic", World = 3, Dps = 7000,
		Passive = { Type = "Exp", Value = 0.35, Text = "+35% EXP" },
		Look = { skin = SKIN_PALE, hair = rgb(150, 255, 200), hairStyle = "Ponytail", top = rgb(80, 60, 160), bottom = rgb(240, 240, 255), accent = rgb(150, 255, 200), eyes = rgb(200, 120, 255), outfit = "Robe", acc = { "Halo", "Cape" }, weapon = "Staff", aura = rgb(150, 255, 200) } },
	{ Id = "absolutezero", Name = "Absolute Zero", Rarity = "Secret", World = 3, Dps = 24000,
		Passive = { Type = "Damage", Value = 0.6, Text = "+60% Damage" },
		Look = { skin = SKIN_PALE, hair = rgb(200, 240, 255), hairStyle = "Wild", top = rgb(220, 245, 255), bottom = rgb(40, 60, 100), accent = rgb(80, 220, 255), eyes = rgb(80, 220, 255), outfit = "Armor", acc = { "Crown", "Cape" }, weapon = "Scythe", aura = rgb(120, 230, 255) } },

	-- ===== World 4: Dark City =====
	{ Id = "neonkid", Name = "Neon Kid", Rarity = "Common", World = 4, Dps = 1200,
		Passive = { Type = "Power", Value = 0.06, Text = "+6% Power" },
		Look = { skin = SKIN_TAN, hair = rgb(255, 60, 200), hairStyle = "Spiky", top = rgb(30, 30, 40), bottom = rgb(40, 40, 60), accent = rgb(60, 255, 230), eyes = rgb(60, 255, 230), outfit = "Hoodie", acc = { "Goggles" }, weapon = "Fists" } },
	{ Id = "vex", Name = "Vex", Rarity = "Common", World = 4, Dps = 1350,
		Passive = { Type = "Coins", Value = 0.06, Text = "+6% Coins" },
		Look = { skin = SKIN_LIGHT, hair = rgb(30, 30, 40), hairStyle = "Slick", top = rgb(120, 30, 40), bottom = rgb(20, 20, 26), accent = rgb(255, 60, 80), eyes = rgb(255, 60, 80), outfit = "Suit", acc = { "Mask" }, weapon = "Fists" } },
	{ Id = "raven", Name = "Raven", Rarity = "Rare", World = 4, Dps = 2700,
		Passive = { Type = "Damage", Value = 0.08, Text = "+8% Damage" },
		Look = { skin = SKIN_PALE, hair = rgb(20, 20, 30), hairStyle = "Long", top = rgb(30, 26, 44), bottom = rgb(30, 26, 44), accent = rgb(170, 80, 255), eyes = rgb(170, 80, 255), outfit = "Coat", acc = { "Hood" }, weapon = "Scythe" } },
	{ Id = "cipher", Name = "Cipher", Rarity = "Epic", World = 4, Dps = 6200,
		Passive = { Type = "Luck", Value = 0.1, Text = "+10% Luck" },
		Look = { skin = SKIN_LIGHT, hair = rgb(160, 90, 255), hairStyle = "Short", top = rgb(20, 20, 30), bottom = rgb(20, 20, 30), accent = rgb(160, 90, 255), eyes = rgb(160, 90, 255), outfit = "Coat", acc = { "Mask" }, weapon = "Katana", aura = rgb(160, 90, 255) } },
	{ Id = "shadelord", Name = "Shade Lord", Rarity = "Legendary", World = 4, Dps = 16500,
		Passive = { Type = "Damage", Value = 0.22, Text = "+22% Damage" },
		Look = { skin = rgb(120, 120, 140), hair = rgb(20, 10, 30), hairStyle = "Wild", top = rgb(30, 10, 40), bottom = rgb(20, 10, 30), accent = rgb(255, 40, 100), eyes = rgb(255, 40, 100), outfit = "Armor", acc = { "Horns", "Cape" }, weapon = "Scythe", aura = rgb(200, 40, 120) } },
	{ Id = "eclipseryu", Name = "Eclipse Ryu", Rarity = "Mythic", World = 4, Dps = 44000,
		Passive = { Type = "Coins", Value = 0.4, Text = "+40% Coins" },
		Look = { skin = SKIN_LIGHT, hair = rgb(20, 20, 26), hairStyle = "Spiky", top = rgb(240, 240, 245), bottom = rgb(20, 20, 26), accent = rgb(255, 50, 50), eyes = rgb(255, 50, 50), outfit = "Coat", acc = { "Scarf", "Cape" }, weapon = "Katana", aura = rgb(255, 50, 60) } },
	{ Id = "null", Name = "Null", Rarity = "Secret", World = 4, Dps = 150000,
		Passive = { Type = "Luck", Value = 0.4, Text = "+40% Luck" },
		Look = { skin = rgb(30, 30, 36), hair = rgb(255, 255, 255), hairStyle = "Wild", top = rgb(10, 10, 14), bottom = rgb(10, 10, 14), accent = rgb(255, 255, 255), eyes = rgb(255, 255, 255), outfit = "Robe", acc = { "Halo", "Mask" }, weapon = "Scythe", aura = rgb(240, 240, 255) } },

	-- ===== World 5: Celestial Realm =====
	{ Id = "cherub", Name = "Cherub", Rarity = "Common", World = 5, Dps = 7500,
		Passive = { Type = "Exp", Value = 0.07, Text = "+7% EXP" },
		Look = { skin = SKIN_LIGHT, hair = rgb(255, 230, 140), hairStyle = "Short", top = rgb(255, 250, 240), bottom = rgb(255, 220, 160), accent = rgb(255, 210, 80), eyes = rgb(80, 160, 255), outfit = "Robe", acc = { "Halo" }, weapon = "Fists" } },
	{ Id = "lumina", Name = "Lumina", Rarity = "Common", World = 5, Dps = 8200,
		Passive = { Type = "Coins", Value = 0.07, Text = "+7% Coins" },
		Look = { skin = SKIN_PALE, hair = rgb(255, 200, 240), hairStyle = "Ponytail", top = rgb(255, 255, 255), bottom = rgb(200, 170, 255), accent = rgb(255, 200, 240), eyes = rgb(200, 120, 255), outfit = "Vest", acc = {}, weapon = "Staff" } },
	{ Id = "solarknight", Name = "Solar Knight", Rarity = "Rare", World = 5, Dps = 17000,
		Passive = { Type = "Damage", Value = 0.1, Text = "+10% Damage" },
		Look = { skin = SKIN_LIGHT, hair = rgb(255, 210, 90), hairStyle = "Slick", top = rgb(255, 220, 120), bottom = rgb(250, 250, 250), accent = rgb(255, 180, 40), eyes = rgb(255, 160, 40), outfit = "Armor", acc = { "Cape" }, weapon = "Sword" } },
	{ Id = "astra", Name = "Astra", Rarity = "Epic", World = 5, Dps = 39000,
		Passive = { Type = "Luck", Value = 0.12, Text = "+12% Luck" },
		Look = { skin = SKIN_PALE, hair = rgb(90, 120, 255), hairStyle = "Long", top = rgb(30, 40, 110), bottom = rgb(250, 250, 255), accent = rgb(255, 230, 120), eyes = rgb(255, 230, 120), outfit = "Robe", acc = { "Crown" }, weapon = "Spear", aura = rgb(140, 170, 255) } },
	{ Id = "seraph", Name = "Seraph", Rarity = "Legendary", World = 5, Dps = 105000,
		Passive = { Type = "Coins", Value = 0.3, Text = "+30% Coins" },
		Look = { skin = SKIN_LIGHT, hair = rgb(255, 245, 210), hairStyle = "Long", top = rgb(255, 255, 255), bottom = rgb(255, 230, 160), accent = rgb(255, 210, 80), eyes = rgb(255, 210, 80), outfit = "Armor", acc = { "Halo", "Cape" }, weapon = "Sword", aura = rgb(255, 240, 170) } },
	{ Id = "celestine", Name = "Celestine", Rarity = "Mythic", World = 5, Dps = 280000,
		Passive = { Type = "Damage", Value = 0.45, Text = "+45% Damage" },
		Look = { skin = SKIN_PALE, hair = rgb(200, 160, 255), hairStyle = "Wild", top = rgb(250, 245, 255), bottom = rgb(150, 110, 255), accent = rgb(255, 220, 255), eyes = rgb(255, 220, 255), outfit = "Robe", acc = { "Halo", "Crown", "Cape" }, weapon = "Staff", aura = rgb(220, 180, 255) } },
	{ Id = "genesis", Name = "Genesis", Rarity = "Secret", World = 5, Dps = 950000,
		Passive = { Type = "Damage", Value = 1.0, Text = "+100% Damage" },
		Look = { skin = rgb(255, 250, 240), hair = rgb(255, 215, 100), hairStyle = "Wild", top = rgb(255, 215, 100), bottom = rgb(255, 255, 255), accent = rgb(255, 255, 255), eyes = rgb(255, 255, 255), outfit = "Armor", acc = { "Halo", "Crown", "Cape" }, weapon = "Trident", aura = rgb(255, 230, 150) } },

	-- ===== Shop exclusives =====
	{ Id = "valkyria", Name = "Valkyria", Rarity = "Mythic", World = 0, Dps = 900, Exclusive = true,
		Passive = { Type = "Damage", Value = 0.5, Text = "+50% Damage" },
		Look = { skin = SKIN_LIGHT, hair = rgb(255, 240, 200), hairStyle = "Ponytail", top = rgb(200, 210, 230), bottom = rgb(40, 60, 120), accent = rgb(255, 210, 80), eyes = rgb(80, 200, 255), outfit = "Armor", acc = { "Crown", "Cape" }, weapon = "Spear", aura = rgb(120, 220, 255) } },
	{ Id = "starkai", Name = "Starlord Kai", Rarity = "Legendary", World = 0, Dps = 260, Exclusive = true,
		Passive = { Type = "Coins", Value = 0.35, Text = "+35% Coins" },
		Look = { skin = SKIN_TAN, hair = rgb(255, 90, 90), hairStyle = "Spiky", top = rgb(255, 255, 255), bottom = rgb(30, 30, 60), accent = rgb(255, 210, 60), eyes = rgb(255, 210, 60), outfit = "Coat", acc = { "Goggles", "Scarf" }, weapon = "Sword", aura = rgb(255, 210, 60) } },
}

local Fighters = { List = list, ById = {}, ByWorld = {} }
for index, def in ipairs(list) do
	def.Order = index
	Fighters.ById[def.Id] = def
	if not def.Exclusive then
		Fighters.ByWorld[def.World] = Fighters.ByWorld[def.World] or {}
		table.insert(Fighters.ByWorld[def.World], def)
	end
end

-- Showcase NPCs placed in the world (not owned by anyone).
Fighters.WorldNPCs = {
	[1] = { "mirae", "lio", "ren", "oceanus", "tessa", "rook", "zephyr", "starkai" },
	[2] = { "azar", "rashid", "khepri", "rakun", "amira" },
	[3] = { "kaze", "glacia", "aurora", "frosthunter", "yuki" },
	[4] = { "shadelord", "cipher", "eclipseryu", "raven", "neonkid" },
	[5] = { "seraph", "celestine", "astra", "solarknight", "lumina" },
}

return Fighters
