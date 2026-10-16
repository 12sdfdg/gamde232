-- Server bootstrap: remotes -> world -> services.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Net = require(ReplicatedStorage.Modules.Net)
Net.CreateAll()

local Router = require(script.Router)
local WorldBuilder = require(script.World.WorldBuilder)

local Services = script.Services
local DataService = require(Services.DataService)
local FighterService = require(Services.FighterService)
local EnemyService = require(Services.EnemyService)
local RewardService = require(Services.RewardService)
local CombatService = require(Services.CombatService)
local WeatherService = require(Services.WeatherService)
local WorldService = require(Services.WorldService)
local ShopService = require(Services.ShopService)

pcall(function()
	StarterGui.ResetPlayerGuiOnSpawn = false
end)

local started = os.clock()
local world = WorldBuilder.Build()
print(string.format("[Server] Worlds built in %.1fs", os.clock() - started))

WorldService.SpawnCFrames = world.Spawns
RewardService.WeatherMultiplier = WeatherService.Multiplier
WorldService.OnTravel = CombatService.ClearTarget

FighterService.Init()
EnemyService.Init()
RewardService.Init()
CombatService.Init()
WeatherService.Init()
WorldService.Init()
ShopService.Init()
DataService.Init() -- last: other services must be listening to DataService.Loaded first

Router.Start()

EnemyService.SpawnAll(world.EnemyPoints)
EnemyService.Start()
FighterService.Start(CombatService.GetTarget)
RewardService.Start()
CombatService.Start()
WeatherService.Start()

workspace:SetAttribute("ServerReady", true)
print("[Server] Anime Sky Fighters ready")
