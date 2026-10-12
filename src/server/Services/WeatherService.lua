-- Global weather cycle. State is replicated through ReplicatedStorage attributes:
--   Weather (string), WeatherEnds (server time from workspace:GetServerTimeNow()).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Configs = ReplicatedStorage.Configs
local Game = require(Configs.Game)
local Weather = require(Configs.Weather)

local WeatherService = {}

local current = Weather.ByName.Clear
local rng = Random.new()

local function pick()
	local total = 0
	for _, w in ipairs(Weather.List) do
		if w ~= current then
			total += w.Weight
		end
	end
	local roll = rng:NextNumber() * total
	for _, w in ipairs(Weather.List) do
		if w ~= current then
			roll -= w.Weight
			if roll <= 0 then
				return w
			end
		end
	end
	return Weather.List[1]
end

function WeatherService.Set(name, duration)
	current = Weather.ByName[name] or Weather.ByName.Clear
	ReplicatedStorage:SetAttribute("Weather", current.Name)
	ReplicatedStorage:SetAttribute("WeatherEnds", workspace:GetServerTimeNow() + (duration or Game.WeatherDuration))
end

function WeatherService.Current()
	return current
end

function WeatherService.Multiplier()
	return current.Multiplier, current.Name
end

function WeatherService.Init()
	WeatherService.Set("Clear", 150)
end

function WeatherService.Start()
	task.spawn(function()
		while true do
			local ends = ReplicatedStorage:GetAttribute("WeatherEnds") or 0
			if workspace:GetServerTimeNow() >= ends then
				local nextWeather = current.Name == "Clear" and pick() or (rng:NextNumber() < 0.55 and Weather.ByName.Clear or pick())
				local duration = nextWeather.Name == "Clear" and Game.WeatherDuration or math.floor(Game.WeatherDuration * 0.75)
				WeatherService.Set(nextWeather.Name, duration)
			end
			task.wait(1)
		end
	end)
end

return WeatherService
