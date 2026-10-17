-- Server-authoritative turret rolls with a per-player cooldown.

local RollService = {}

local ctx
local RNG
local entries

function RollService.init(context)
	ctx = context
	RNG = require(game:GetService("ReplicatedStorage").Shared.RNG)
	entries = RNG.turretEntries(ctx.Config.Turrets)

	ctx.Net.funcs.Roll.OnServerInvoke = function(player)
		return RollService.roll(player)
	end
end

function RollService.roll(player: Player)
	local d = ctx.PlayerData.get(player)
	if not d then
		return nil
	end
	local now = os.clock()
	if now - d.lastRoll < ctx.Config.Economy.rollCooldown then
		return nil
	end
	d.lastRoll = now

	local turretId = RNG.weighted(entries)
	d.rolls.Value += 1
	ctx.PlayerData.addToInventory(player, turretId, 1)
	return turretId
end

return RollService
