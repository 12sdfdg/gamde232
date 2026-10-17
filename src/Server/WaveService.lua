-- Drives the shared wave loop, base health and game-over reset.

local WaveService = {}

local ctx
local state = {
	wave = 0,
	health = 0,
	gameOver = false,
}

local function pickBalloon(wave: number, index: number, count: number)
	local B = ctx.Config.Balloons
	if wave % 5 == 0 and index == count then
		return B.Boss
	end
	local r = math.random()
	if wave >= 6 and r < 0.3 then
		return B.Green
	elseif wave >= 3 and r < 0.6 then
		return B.Blue
	end
	return B.Red
end

local function notifyAll(text: string)
	ctx.Net.events.Notify:FireAllClients(text)
end

local function resetGame()
	ctx.BalloonService.clear()
	state.wave = 0
	state.health = ctx.Config.Economy.baseHealth
	state.gameOver = false
	ctx.PlayerData.broadcastState()
end

local function runWave()
	state.wave += 1
	notifyAll(string.format("Wave %d", state.wave))
	ctx.PlayerData.broadcastState()

	local count = 6 + state.wave * 2
	local hpMultiplier = 1 + (state.wave - 1) * 0.22
	local interval = math.max(0.35, 1.1 - state.wave * 0.04)

	for i = 1, count do
		if state.gameOver then
			return
		end
		ctx.BalloonService.spawn(pickBalloon(state.wave, i, count), hpMultiplier)
		task.wait(interval)
	end

	while ctx.BalloonService.count() > 0 and not state.gameOver do
		task.wait(0.5)
	end
	if state.gameOver then
		return
	end

	for player, d in ctx.PlayerData.each() do
		d.cash.Value += ctx.Config.Economy.waveBonus
		if state.wave > d.bestWave.Value then
			d.bestWave.Value = state.wave
		end
	end
	notifyAll(string.format("Wave %d cleared! +%d cash", state.wave, ctx.Config.Economy.waveBonus))
	ctx.PlayerData.broadcastState()
end

function WaveService.init(context)
	ctx = context
	state.health = ctx.Config.Economy.baseHealth
end

function WaveService.getState()
	return state
end

function WaveService.onLeak(damage: number)
	if state.gameOver then
		return
	end
	state.health = math.max(0, state.health - damage)
	ctx.PlayerData.broadcastState()
	if state.health <= 0 then
		state.gameOver = true
		notifyAll(string.format("The base fell on wave %d! Restarting...", state.wave))
	end
end

function WaveService.start()
	task.spawn(function()
		while true do
			task.wait(ctx.Config.Economy.intermission)
			runWave()
			if state.gameOver then
				task.wait(3)
				resetGame()
			end
		end
	end)
end

return WaveService
