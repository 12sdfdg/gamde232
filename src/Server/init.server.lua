-- Server entry point: builds the map, wires services together and runs the main loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local MapBuilder = require(script.MapBuilder)
local PlayerData = require(script.PlayerData)
local BalloonService = require(script.BalloonService)
local TurretService = require(script.TurretService)
local WaveService = require(script.WaveService)
local RollService = require(script.RollService)

local ctx = {
	Config = Config,
	Net = Net.setupServer(),
	map = MapBuilder.build(),
	MapBuilder = MapBuilder,
	PlayerData = PlayerData,
	BalloonService = BalloonService,
	TurretService = TurretService,
	WaveService = WaveService,
	RollService = RollService,
}

WaveService.init(ctx)
BalloonService.init(ctx)
TurretService.init(ctx)
RollService.init(ctx)
PlayerData.init(ctx)

RunService.Heartbeat:Connect(function(dt)
	BalloonService.update(dt)
	TurretService.update(dt)
end)

WaveService.start()
