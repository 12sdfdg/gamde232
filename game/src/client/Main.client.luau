-- Client entry point: wires remotes to the UI, placement and effects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effects = require(script.Parent.Effects)
local Placement = require(script.Parent.Placement)
local UI = require(script.Parent.UI)

local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder

local state = {
	data = nil,
	stats = nil,
}

UI.Init(remotes, state)
Placement.Init(remotes, UI.SetHint, UI.Toast, UI.Available)

remotes:WaitForChild("DataChanged").OnClientEvent:Connect(function(data, stats)
	state.data = data
	state.stats = stats
	UI.Refresh()
end)

remotes:WaitForChild("WaveState").OnClientEvent:Connect(function(w)
	UI.SetWave(w)
end)

remotes:WaitForChild("Popped").OnClientEvent:Connect(function(pos, color, coins, id)
	Effects.Pop(pos, color, coins, id)
end)

remotes:WaitForChild("Shot").OnClientEvent:Connect(function(from, to, color, splash)
	Effects.Shot(from, to, color, splash)
end)

remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text, color)
	UI.Toast(text, color)
end)

remotes:WaitForChild("PlaySound").OnClientEvent:Connect(function(name)
	Effects.Play(name)
end)

UI.SetWave({ running = false, wave = 0, lives = 20, maxLives = 20 })
UI.Toast("Welcome! Roll 🎲 for turrets, place them on your base, then press Start", Color3.fromRGB(255, 230, 120))
