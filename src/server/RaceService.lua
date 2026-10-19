--!nonstrict
-- Цикл раундів: лобі (клікаєш, набираєш швидкість) → забіг (всі біжать, сервер рахує зони й виграші).
-- Виграші рахуються на сервері лише зі збереженої швидкості — позиція клієнта ні на що не впливає.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerState = require(script.Parent.PlayerState)

local RoundStateRemote = Net.Get("RoundState")
local RaceStartRemote = Net.Get("RaceStart")
local RaceResultRemote = Net.Get("RaceResult")

local RaceService = {}

local phase = "Lobby"
local endsAt = 0
local roundLabel: TextLabel? = nil
local racers: { [Player]: boolean } = {}

function RaceService.GetRoundState()
	return { phase = phase, endsAt = endsAt }
end

local function broadcast()
	RoundStateRemote:FireAllClients(RaceService.GetRoundState())
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function finishRace(player: Player, zone: number, distance: number)
	local data = DataService.Get(player)
	local session = PlayerState.GetSession(player)
	if not data or not session then
		return
	end
	local wins = 0
	if zone >= 1 then
		wins = math.floor(Config.WinsForZone(zone) * PlayerState.WinsMultiplier(player, data))
		data.totalWins += wins
		PlayerState.AddWins(player, data, wins, "Race")
	end
	data.races += 1
	local newBest = zone > data.bestZone
	if newBest then
		data.bestZone = zone
	end
	PlayerState.LogFunnel(player, 3, "First Race")

	session.racesSinceUpsell += 1
	local upsell: string? = nil
	if zone >= 1 and session.racesSinceUpsell >= Config.UpsellEveryRaces then
		if not session.passes.DoubleWins then
			upsell = "DoubleWins"
		elseif not session.passes.DoubleSpeed then
			upsell = "DoubleSpeed"
		end
		session.racesSinceUpsell = 0
	end

	PlayerState.MarkDirty(player)
	RaceResultRemote:FireClient(player, {
		zone = zone,
		wins = wins,
		distance = distance,
		newBest = newBest and zone >= 1,
		upsell = upsell,
	})
end

local function startRace()
	phase = "Race"
	endsAt = workspace:GetServerTimeNow() + Config.Race.RaceTime
	broadcast()

	table.clear(racers)
	local lane = 0
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		local root = getRoot(player)
		if data and root and player.Character then
			local distance = Config.DistanceForSpeed(data.speed)
			local zone = Config.ZoneForDistance(distance)
			if distance < 5 then
				PlayerState.Notify(player, "Click to gain Speed before the next race! ⚡", "warn")
			else
				lane = lane % Config.Race.Lanes + 1
				local start = MapBuilder.LaneStart(lane)
				local velocity = math.max(Config.Race.MinRunVelocity, distance / (Config.Race.RaceTime - 2))
				local duration = distance / velocity
				racers[player] = true
				player.Character:PivotTo(start)
				RaceStartRemote:FireClient(player, {
					start = start,
					distance = distance,
					duration = duration,
				})
				task.delay(duration, finishRace, player, zone, distance)
			end
		end
	end
end

local function endRace()
	for player in racers do
		local root = getRoot(player)
		if root and player.Character and player.Parent then
			local offset = Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
			player.Character:PivotTo(MapBuilder.LobbySpawn() + offset)
		end
	end
	table.clear(racers)
	phase = "Lobby"
	endsAt = workspace:GetServerTimeNow() + Config.Race.LobbyTime
	broadcast()
end

function RaceService.IsRacing(player: Player): boolean
	return racers[player] == true
end

function RaceService.Start(map: MapBuilder.Map)
	roundLabel = map.roundLabel
	Players.PlayerRemoving:Connect(function(player)
		racers[player] = nil
	end)

	phase = "Lobby"
	endsAt = workspace:GetServerTimeNow() + Config.Race.LobbyTime
	broadcast()

	task.spawn(function()
		while true do
			local remaining = endsAt - workspace:GetServerTimeNow()
			if roundLabel then
				roundLabel.Text = if phase == "Lobby"
					then string.format("🏁 Next race in %s", Format.Time(math.ceil(remaining)))
					else "🔥 RACE IN PROGRESS!"
			end
			if remaining <= 0 then
				if phase == "Lobby" then
					startRace()
				else
					endRace()
				end
			end
			task.wait(0.25)
		end
	end)
end

return RaceService
