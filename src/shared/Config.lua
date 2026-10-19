--!nonstrict
-- Центральний конфіг гри. Весь баланс, ціни та ID монетизації — тут.
-- Після створення Game Pass / Developer Product у Creator Hub впиши їх ID замість 0.

local Config = {}

Config.GAME_NAME = "Turbo Race Clicker"

-- Змінюй версію ключа, щоб скинути прогрес усім гравцям (наприклад, після бета-тесту).
Config.DATASTORE_NAME = "PlayerData_v1"
Config.LEADERBOARD_STORE = "TotalWinsBoard_v1"

-- ID твоєї Roblox-групи (справжня група на roblox.com). 0 = бонус вимкнено.
Config.GROUP_ID = 0
Config.GROUP_SPEED_BONUS = 0.10 -- +10% до швидкості за членство в групі

-- У Studio покупки з ID = 0 видаються безкоштовно, щоб можна було тестувати.
Config.TEST_PURCHASES_IN_STUDIO = true

---------------------------------------------------------------------------
-- Клікер
---------------------------------------------------------------------------
Config.Click = {
	BaseGain = 1,
	MaxClicksPerSecond = 20, -- усе, що понад цей ліміт, сервер ігнорує (антиавтоклікер)
	AutoClicksPerSecond = 6, -- швидкість геймпаса Auto Clicker
}

---------------------------------------------------------------------------
-- Забіг
---------------------------------------------------------------------------
Config.Race = {
	LobbyTime = 20, -- секунд клікання між забігами
	RaceTime = 12, -- тривалість фази забігу
	ZoneLength = 250, -- довжина однієї зони (studs)
	ZoneCount = 40,
	-- Зона k потребує ZoneSpeedBase * ZoneSpeedGrowth^(k-1) швидкості.
	-- 100 Speed = Зона 1 вже в першому забігу; Зона 40 ≈ 190M (20+ годин гри).
	ZoneSpeedBase = 100,
	ZoneSpeedGrowth = 1.45,
	MinRunVelocity = 70, -- студів/сек, щоб короткі забіги не були нудними
	TrackWidth = 64,
	Lanes = 8,
}

-- Нагорода за досягнення зони i (сумується за всі пройдені зони).
function Config.ZoneReward(zone: number): number
	return math.floor(2 * 1.18 ^ (zone - 1))
end

function Config.SpeedForZone(zone: number): number
	return Config.Race.ZoneSpeedBase * Config.Race.ZoneSpeedGrowth ^ (zone - 1)
end

function Config.DistanceForSpeed(speed: number): number
	local race = Config.Race
	local maxDistance = race.ZoneLength * race.ZoneCount
	if speed < race.ZoneSpeedBase then
		return race.ZoneLength * math.max(speed, 0) / race.ZoneSpeedBase
	end
	local zones = 1 + math.log(speed / race.ZoneSpeedBase) / math.log(race.ZoneSpeedGrowth)
	return math.min(zones * race.ZoneLength, maxDistance)
end

function Config.ZoneForDistance(distance: number): number
	return math.floor(distance / Config.Race.ZoneLength)
end

function Config.WinsForZone(zone: number): number
	local total = 0
	for i = 1, zone do
		total += Config.ZoneReward(i)
	end
	return total
end

---------------------------------------------------------------------------
-- Ребьорт
---------------------------------------------------------------------------
Config.Rebirth = {
	BaseCost = 100,
	CostGrowth = 2,
	SpeedMultPerRebirth = 1, -- кожен ребьорт: +100% до набору швидкості
	WinsMultPerRebirth = 0.25, -- кожен ребьорт: +25% до виграшів
}

function Config.RebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

---------------------------------------------------------------------------
-- Улюбленці
---------------------------------------------------------------------------
Config.Pets = {
	BaseEquipSlots = 3,
	ExtraSlotsPass = 3,
	InventoryLimit = 60,
}

Config.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(190, 190, 190) },
	Uncommon = { order = 2, color = Color3.fromRGB(85, 220, 95) },
	Rare = { order = 3, color = Color3.fromRGB(70, 150, 255) },
	Epic = { order = 4, color = Color3.fromRGB(180, 80, 255) },
	Legendary = { order = 5, color = Color3.fromRGB(255, 190, 40) },
	Mythic = { order = 6, color = Color3.fromRGB(255, 60, 120) },
}

-- boost — множник одного улюбленця. Загальний бонус = 1 + Σ(boost - 1) екіпірованих.
-- chance — відсоток (сума в яйці = 100). Шанси показуються гравцям над яйцем.
Config.Eggs = {
	{
		id = "Basic",
		name = "Basic Egg",
		cost = 15,
		color = Color3.fromRGB(240, 235, 210),
		pets = {
			{ name = "Dog", icon = "🐶", rarity = "Common", boost = 1.2, chance = 45 },
			{ name = "Cat", icon = "🐱", rarity = "Common", boost = 1.3, chance = 30 },
			{ name = "Bunny", icon = "🐰", rarity = "Uncommon", boost = 1.5, chance = 15 },
			{ name = "Fox", icon = "🦊", rarity = "Rare", boost = 2, chance = 8 },
			{ name = "Unicorn", icon = "🦄", rarity = "Legendary", boost = 3.5, chance = 2 },
		},
	},
	{
		id = "Golden",
		name = "Golden Egg",
		cost = 400,
		color = Color3.fromRGB(255, 205, 60),
		pets = {
			{ name = "Bee", icon = "🐝", rarity = "Uncommon", boost = 3, chance = 45 },
			{ name = "Bear", icon = "🐻", rarity = "Rare", boost = 4, chance = 30 },
			{ name = "Panda", icon = "🐼", rarity = "Rare", boost = 5.5, chance = 16 },
			{ name = "Dragon", icon = "🐲", rarity = "Epic", boost = 9, chance = 7.5 },
			{ name = "Phoenix", icon = "🔥", rarity = "Legendary", boost = 15, chance = 1.4 },
			{ name = "Galaxy Cat", icon = "🌌", rarity = "Mythic", boost = 40, chance = 0.1 },
		},
	},
	{
		id = "Cosmic",
		name = "Cosmic Egg",
		cost = 6000,
		color = Color3.fromRGB(110, 70, 255),
		pets = {
			{ name = "Alien", icon = "👽", rarity = "Rare", boost = 12, chance = 45 },
			{ name = "Robot", icon = "🤖", rarity = "Epic", boost = 16, chance = 30 },
			{ name = "Hydra", icon = "🐍", rarity = "Epic", boost = 24, chance = 16 },
			{ name = "Void Dragon", icon = "🐉", rarity = "Legendary", boost = 40, chance = 7.5 },
			{ name = "Cosmic Phoenix", icon = "☄️", rarity = "Legendary", boost = 75, chance = 1.4 },
			{ name = "Infinity Cat", icon = "😼", rarity = "Mythic", boost = 250, chance = 0.1 },
		},
	},
}

-- Множник шансів для Legendary/Mythic від Lucky-ефектів.
Config.LuckyRarities = { Legendary = true, Mythic = true }

function Config.GetEgg(eggId: string)
	for _, egg in Config.Eggs do
		if egg.id == eggId then
			return egg
		end
	end
	return nil
end

function Config.GetPetDef(petName: string)
	for _, egg in Config.Eggs do
		for _, pet in egg.pets do
			if pet.name == petName then
				return pet
			end
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Бусти (тимчасові)
---------------------------------------------------------------------------
Config.Boosts = {
	Speed2x = { name = "2x Speed", mult = 2 },
	Wins2x = { name = "2x Wins", mult = 2 },
	Lucky = { name = "Lucky", mult = 2 },
}

---------------------------------------------------------------------------
-- Монетизація
---------------------------------------------------------------------------
-- Ціни тут лише для відображення в магазині; реальну ціну ставиш у Creator Hub.
Config.GamePasses = {
	{ key = "VIP", id = 0, name = "VIP", price = 299, desc = "x1.5 Wins forever, VIP chat tag, golden name" },
	{ key = "DoubleSpeed", id = 0, name = "2x Speed", price = 149, desc = "Double speed from every click, forever" },
	{ key = "DoubleWins", id = 0, name = "2x Wins", price = 199, desc = "Double wins from every race, forever" },
	{ key = "AutoClicker", id = 0, name = "Auto Clicker", price = 99, desc = "Clicks for you, even while AFK" },
	{ key = "ExtraPets", id = 0, name = "+3 Pet Slots", price = 129, desc = "Equip 3 more pets at once" },
	{ key = "LuckyEggs", id = 0, name = "Lucky Eggs", price = 249, desc = "x2 chance for Legendary & Mythic pets" },
	{ key = "TripleHatch", id = 0, name = "Triple Hatch", price = 179, desc = "Open 3 eggs at once" },
}

-- kind: "Wins" — разовий пакет; amount множиться на (1 + rebirths), щоб пакет був цінний на будь-якому етапі.
-- kind: "Boost" — тимчасовий буст; seconds додаються до вже активного.
Config.Products = {
	{ key = "WinsSmall", id = 0, name = "Pile of Wins", price = 25, kind = "Wins", amount = 150 },
	{ key = "WinsMedium", id = 0, name = "Bag of Wins", price = 79, kind = "Wins", amount = 600, tag = "POPULAR" },
	{ key = "WinsLarge", id = 0, name = "Vault of Wins", price = 249, kind = "Wins", amount = 2500, tag = "BEST VALUE" },
	{ key = "BoostSpeed", id = 0, name = "2x Speed (15 min)", price = 39, kind = "Boost", boost = "Speed2x", seconds = 900 },
	{ key = "BoostWins", id = 0, name = "2x Wins (15 min)", price = 49, kind = "Boost", boost = "Wins2x", seconds = 900 },
	{ key = "BoostLucky", id = 0, name = "Lucky (15 min)", price = 59, kind = "Boost", boost = "Lucky", seconds = 900 },
}

function Config.GetPass(key: string)
	for _, pass in Config.GamePasses do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

function Config.GetProduct(key: string)
	for _, product in Config.Products do
		if product.key == key then
			return product
		end
	end
	return nil
end

-- Як часто (в забігах) після фінішу показувати пропозицію 2x Wins тим, хто її не має.
Config.UpsellEveryRaces = 6

---------------------------------------------------------------------------
-- Утримання
---------------------------------------------------------------------------
-- 7-денний цикл щоденних нагород. Серія скидається, якщо пропустити день.
Config.DailyRewards = {
	{ kind = "Wins", amount = 25 },
	{ kind = "Wins", amount = 60 },
	{ kind = "Boost", boost = "Speed2x", seconds = 900 },
	{ kind = "Wins", amount = 150 },
	{ kind = "Boost", boost = "Lucky", seconds = 900 },
	{ kind = "Wins", amount = 400 },
	{ kind = "Boost", boost = "Wins2x", seconds = 1800, bonusWins = 1000 },
}

-- Подарунки за час у грі (за сесію). time — секунди від входу.
Config.PlaytimeGifts = {
	{ time = 60, kind = "Wins", amount = 10 },
	{ time = 180, kind = "Wins", amount = 25 },
	{ time = 300, kind = "Boost", boost = "Speed2x", seconds = 300 },
	{ time = 600, kind = "Wins", amount = 60 },
	{ time = 900, kind = "Boost", boost = "Lucky", seconds = 600 },
	{ time = 1500, kind = "Wins", amount = 150 },
	{ time = 2400, kind = "Boost", boost = "Wins2x", seconds = 900 },
	{ time = 3600, kind = "Wins", amount = 500 },
}

-- Промокоди (регістр не важливий). Додавай нові з кожним оновленням і пиши їх в описі гри.
Config.Codes = {
	RELEASE = { kind = "Wins", amount = 100 },
	TURBO = { kind = "Boost", boost = "Speed2x", seconds = 600 },
	LUCKY = { kind = "Boost", boost = "Lucky", seconds = 600 },
}

Config.FriendBonusPerFriend = 0.10 -- +10% виграшів за кожного друга на сервері
Config.FriendBonusMax = 0.50
Config.PremiumWinsBonus = 0.10

return Config
