-- Achievements ("Feats"). Each has tiers; claiming a tier pays gems and moves to the next tier.
local Achievements = {}

Achievements.List = {
	{ Id = "playtime", Tab = "Worlds", Title = "Time Played", Description = "Play the longest as possible", Icon = "⏰", Stat = "PlayTime",
		Goals = { 600, 3600, 3 * 3600, 10 * 3600, 30 * 3600 }, Rewards = { 25, 60, 120, 250, 500 } },
	{ Id = "staropen", Tab = "Worlds", Title = "Star Open", Description = "Master the art of star opening", Icon = "⭐", Stat = "StarOpens",
		Goals = { 10, 50, 250, 1000, 5000 }, Rewards = { 25, 60, 120, 250, 500 } },
	{ Id = "power", Tab = "Worlds", Title = "Highest Power", Description = "Reach the highest power levels", Icon = "🔥", Stat = "HighestPower",
		Goals = { 500, 10000, 250000, 5000000, 1e8 }, Rewards = { 25, 60, 120, 250, 500 } },
	{ Id = "kills", Tab = "Worlds", Title = "Monster Hunter", Description = "Defeat enemies across the worlds", Icon = "💀", Stat = "Kills",
		Goals = { 50, 500, 2500, 10000, 50000 }, Rewards = { 20, 50, 100, 200, 400 } },
	{ Id = "worlds", Tab = "Worlds", Title = "Sky Explorer", Description = "Unlock new worlds", Icon = "🌍", Stat = "WorldsUnlocked",
		Goals = { 2, 3, 4, 5 }, Rewards = { 50, 120, 250, 600 } },
	{ Id = "collector", Tab = "Worlds", Title = "Collector", Description = "Discover fighters in the Index", Icon = "📖", Stat = "IndexCount",
		Goals = { 5, 10, 18, 26, 36 }, Rewards = { 30, 70, 140, 280, 600 } },
	{ Id = "bosses", Tab = "Gamemodes", Title = "Boss Slayer", Description = "Defeat world bosses", Icon = "👹", Stat = "BossKills",
		Goals = { 1, 10, 50, 200, 1000 }, Rewards = { 40, 90, 180, 350, 700 } },
	{ Id = "clicks", Tab = "Gamemodes", Title = "Click Frenzy", Description = "Click as fast as you can", Icon = "🖱️", Stat = "Clicks",
		Goals = { 500, 5000, 25000, 100000, 500000 }, Rewards = { 20, 50, 100, 200, 400 } },
	{ Id = "abilities", Tab = "Gamemodes", Title = "Special Move", Description = "Use your special ability", Icon = "💥", Stat = "AbilityUses",
		Goals = { 10, 100, 500, 2000, 10000 }, Rewards = { 20, 50, 100, 200, 400 } },
	{ Id = "level", Tab = "Gamemodes", Title = "Rising Star", Description = "Level up your hero", Icon = "🏆", Stat = "Level",
		Goals = { 5, 15, 30, 50, 80 }, Rewards = { 30, 70, 150, 300, 600 } },
	{ Id = "weather", Tab = "Gamemodes", Title = "Storm Chaser", Description = "Defeat enemies during special weather", Icon = "🌩️", Stat = "WeatherKills",
		Goals = { 25, 250, 1500, 8000 }, Rewards = { 30, 80, 160, 320 } },
}

Achievements.ById = {}
for _, a in ipairs(Achievements.List) do
	Achievements.ById[a.Id] = a
end

return Achievements
