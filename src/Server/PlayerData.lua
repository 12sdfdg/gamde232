-- Per-player session state: cash, roll count, turret inventory and leaderstats.

local Players = game:GetService("Players")

local PlayerData = {}

local ctx
local data = {}

local function makeStat(parent, name, value)
	local v = Instance.new("IntValue")
	v.Name = name
	v.Value = value
	v.Parent = parent
	return v
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	data[player] = {
		cash = makeStat(leaderstats, "Cash", ctx.Config.Economy.startCash),
		rolls = makeStat(leaderstats, "Rolls", 0),
		bestWave = makeStat(leaderstats, "BestWave", 0),
		inventory = {},
		lastRoll = 0,
	}

	PlayerData.sendState(player)
end

function PlayerData.init(context)
	ctx = context
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		ctx.TurretService.removeOwnedBy(player)
		data[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
end

function PlayerData.get(player: Player)
	return data[player]
end

function PlayerData.addCash(player: Player, amount: number)
	local d = data[player]
	if d then
		d.cash.Value += amount
		PlayerData.sendState(player)
	end
end

function PlayerData.addToInventory(player: Player, turretId: string, amount: number)
	local d = data[player]
	if not d then
		return
	end
	d.inventory[turretId] = math.max(0, (d.inventory[turretId] or 0) + amount)
	if d.inventory[turretId] == 0 then
		d.inventory[turretId] = nil
	end
	PlayerData.sendState(player)
end

function PlayerData.sendState(player: Player)
	local d = data[player]
	if not d then
		return
	end
	local waveState = ctx.WaveService.getState()
	ctx.Net.events.StateChanged:FireClient(player, {
		cash = d.cash.Value,
		rolls = d.rolls.Value,
		inventory = d.inventory,
		wave = waveState.wave,
		health = waveState.health,
		maxHealth = ctx.Config.Economy.baseHealth,
		rollCooldown = ctx.Config.Economy.rollCooldown,
	})
end

function PlayerData.broadcastState()
	for player in pairs(data) do
		PlayerData.sendState(player)
	end
end

function PlayerData.each()
	return pairs(data)
end

return PlayerData
