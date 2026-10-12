-- Shared formulas. The server is the authority; the client uses these only for display.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configs = ReplicatedStorage:WaitForChild("Configs")
local Game = require(Configs:WaitForChild("Game"))
local Fighters = require(Configs:WaitForChild("Fighters"))
local Rarities = require(Configs:WaitForChild("Rarities"))
local Shop = require(Configs:WaitForChild("Shop"))

local Stats = {}

function Stats.ExpForLevel(level)
	return math.floor(80 * level ^ 1.6)
end

function Stats.FighterDps(def, level)
	return def.Dps * (1 + 0.6 * ((level or 1) - 1))
end

function Stats.FighterPower(def, level)
	return math.floor(Stats.FighterDps(def, level) * 10 * Rarities.Rank(def.Rarity))
end

function Stats.UpgradeCost(def, level)
	local rank = Rarities.Rank(def.Rarity)
	return {
		Materials = 2 * level + rank,
		Power = math.floor(def.Dps * 20 * level * (1 + rank * 0.25)),
	}
end

function Stats.MaxEquip(data)
	local n = Game.BaseEquip + math.floor((data.Level - 1) / 8)
	if data.Gamepasses and data.Gamepasses.ExtraEquip then
		n += 2
	end
	return math.min(n, Game.MaxEquip)
end

function Stats.PowerMultiplier(power)
	return 1 + math.log10(1 + math.max(0, power)) * 0.35
end

local function boostActive(data, name, now)
	local boost = data.Boosts and data.Boosts[name]
	return boost and boost.Ends > now and boost.Value or 0
end

-- Sum of passives of equipped fighters, boosts and gamepasses.
function Stats.Multipliers(data, now)
	now = now or os.time()
	local result = { Coins = 1, Damage = 1, Exp = 1, Luck = 1, Power = 1 }
	local passives = { Coins = 0, Damage = 0, Exp = 0, Luck = 0, Power = 0 }
	for _, uid in ipairs(data.Equipped or {}) do
		local entry = data.Fighters[uid]
		local def = entry and Fighters.ById[entry.Id]
		if def and def.Passive then
			passives[def.Passive.Type] += def.Passive.Value
		end
	end
	for key in pairs(result) do
		result[key] = 1 + passives[key]
	end
	result.Coins *= 1 + boostActive(data, "Coins", now)
	result.Damage *= 1 + boostActive(data, "Damage", now)
	result.Luck *= 1 + boostActive(data, "Luck", now)

	local gp = data.Gamepasses or {}
	if gp.DoubleCoins then
		result.Coins *= 2
	end
	if gp.DoubleDamage then
		result.Damage *= 2
	end
	if gp.Lucky then
		result.Luck *= 1.5
	end
	if gp.VIP then
		result.Coins *= 1.2
		result.Damage *= 1.2
		result.Exp *= 1.2
	end
	result.Damage *= 1 + (data.Items and data.Items.Sword or 0) * Game.SwordDamageBonus
	result.Damage *= Stats.PowerMultiplier(data.Power or 0)
	return result
end

-- Base DPS of the equipped team (before damage multipliers).
function Stats.TeamBaseDps(data)
	local total = 0
	for _, uid in ipairs(data.Equipped or {}) do
		local entry = data.Fighters[uid]
		local def = entry and Fighters.ById[entry.Id]
		if def then
			total += Stats.FighterDps(def, entry.Level)
		end
	end
	return total
end

function Stats.TeamDps(data, now)
	return Stats.TeamBaseDps(data) * Stats.Multipliers(data, now).Damage
end

function Stats.ClickPower(data, now)
	local mult = Stats.Multipliers(data, now)
	return Game.ClickPowerBase * (1 + (data.Level - 1) * 0.15) * mult.Power
end

function Stats.GamepassOwned(data, key)
	return data.Gamepasses and data.Gamepasses[key] == true and Shop.GamepassByKey[key] ~= nil
end

return Stats
