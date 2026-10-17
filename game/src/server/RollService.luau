-- RNG rolling for turrets and the upgrade (skill tree) shop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)

local RollService = {}

local remotes: any
local lastRoll: { [Player]: number } = {}
local rng = Random.new()

function RollService.Roll(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local stats = DataService.Stats(player)
	local now = os.clock()
	if lastRoll[player] and now - lastRoll[player] < stats.rollCooldown * 0.9 then
		return nil
	end
	lastRoll[player] = now
	local def = Util.RollFrom(Config.Turrets, stats.luck, rng)
	data.inventory[def.id] = (data.inventory[def.id] or 0) + 1
	local isNew = not data.discovered[def.id]
	data.discovered[def.id] = true
	data.rolls += 1
	DataService.MarkDirty(player)
	if def.chance >= Config.RareAnnounceChance then
		remotes.Notify:FireAllClients(
			string.format("🎲 %s rolled %s (%s)!", player.DisplayName, def.name, Util.ChanceText(def.chance)),
			Config.RarityColors[def.rarity]
		)
	end
	return { id = def.id, isNew = isNew }
end

function RollService.BuyUpgrade(player: Player, id: string)
	local data = DataService.Get(player)
	local def = typeof(id) == "string" and Config.Get(id)
	if not data or not def or def.effect == nil then
		return false, "Unknown upgrade"
	end
	if data.upgrades[id] then
		return false, "Already owned"
	end
	if def.requires and not data.upgrades[def.requires] then
		return false, "Requires " .. Config.Get(def.requires).name
	end
	if data.coins < def.cost then
		return false, "Not enough coins"
	end
	data.coins -= def.cost
	data.upgrades[id] = true
	DataService.Sync(player)
	return true, nil
end

function RollService.Init(remoteFolder: Folder)
	remotes = remoteFolder
end

function RollService.Forget(player: Player)
	lastRoll[player] = nil
end

return RollService
