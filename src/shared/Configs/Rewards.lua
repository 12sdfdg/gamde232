-- Daily login rewards and play-time rewards.
local Rewards = {}

Rewards.Daily = {
	{ Day = 1, Gems = 100 },
	{ Day = 2, Gems = 150 },
	{ Day = 3, Gems = 200 },
	{ Day = 4, Gems = 250 },
	{ Day = 5, Gems = 300 },
	{ Day = 6, Gems = 350 },
	{ Day = 7, Gems = 500 },
}

-- Session play-time rewards (seconds played in the current session).
Rewards.Time = {
	{ Time = 120, Reward = { Type = "Coins", Amount = 500 }, Icon = "🪙" },
	{ Time = 300, Reward = { Type = "Gems", Amount = 30 }, Icon = "💠" },
	{ Time = 600, Reward = { Type = "Potion_Coins", Amount = 1 }, Icon = "💰" },
	{ Time = 900, Reward = { Type = "Gems", Amount = 60 }, Icon = "💠" },
	{ Time = 1500, Reward = { Type = "Potion_Luck", Amount = 1 }, Icon = "🍀" },
	{ Time = 2400, Reward = { Type = "Material", Amount = 10 }, Icon = "💎" },
	{ Time = 3600, Reward = { Type = "Gems", Amount = 150 }, Icon = "💠" },
	{ Time = 5400, Reward = { Type = "Potion_Damage", Amount = 2 }, Icon = "⚔️" },
}

return Rewards
