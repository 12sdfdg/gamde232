-- Shop catalog. Robux purchases need real IDs: fill GamePassId / ProductId with your own IDs
-- from the Creator Dashboard. While an ID is 0, the item can still be bought with Gems.
local Shop = {}

Shop.Gamepasses = {
	{ Key = "DoubleCoins", Name = "x2 Coins", Icon = "🪙", Description = "Double coins from every enemy.", Robux = 499, Gems = 4990, GamePassId = 0 },
	{ Key = "DoubleDamage", Name = "x2 Damage", Icon = "⚔️", Description = "Your fighters deal double damage.", Robux = 599, Gems = 5990, GamePassId = 0 },
	{ Key = "ExtraEquip", Name = "+2 Equip", Icon = "👥", Description = "Equip 2 more fighters.", Robux = 699, Gems = 6990, GamePassId = 0 },
	{ Key = "Lucky", Name = "Lucky", Icon = "🍀", Description = "x1.5 luck for rare fighters.", Robux = 799, Gems = 7990, GamePassId = 0 },
	{ Key = "MultiOpen", Name = "Multi Open", Icon = "⭐", Description = "Open 8 stars at once.", Robux = 399, Gems = 3990, GamePassId = 0 },
	{ Key = "VIP", Name = "VIP", Icon = "👑", Description = "+20% coins, damage & EXP.", Robux = 1033, Gems = 10330, GamePassId = 0 },
}

Shop.GamepassByKey = {}
for _, gp in ipairs(Shop.Gamepasses) do
	Shop.GamepassByKey[gp.Key] = gp
end

-- Bundles are one-time purchases (Limit 1).
Shop.Bundles = {
	{ Key = "AllPasses", Name = "All Gamepasses", Limit = 1, Robux = 3928, Gems = 39280, ProductId = 0,
		Art = "starkai", Colors = { Color3.fromRGB(255, 196, 40), Color3.fromRGB(255, 110, 30) },
		Grants = { Gamepasses = { "DoubleCoins", "DoubleDamage", "ExtraEquip", "Lucky", "MultiOpen", "VIP" } } },
	{ Key = "Valkyria", Name = "Valkyria Bundle", Limit = 1, Robux = 1499, Gems = 14990, ProductId = 0,
		Art = "valkyria", Colors = { Color3.fromRGB(90, 200, 255), Color3.fromRGB(120, 80, 255) },
		Grants = { Fighters = { "valkyria" }, Items = { Potion_Luck = 3, Potion_Damage = 3 }, Materials = 50 } },
	{ Key = "Starter", Name = "Starter Pack", Limit = 1, Robux = 299, Gems = 2990, ProductId = 0,
		Art = "starkai", Colors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 160, 60) },
		Grants = { Fighters = { "starkai" }, Coins = 25000, Items = { Potion_Coins = 3 } } },
}

-- Gem packs (Developer Products).
Shop.GemPacks = {
	{ Key = "Gems1", Amount = 500, Robux = 49, ProductId = 0, Icon = "💠" },
	{ Key = "Gems2", Amount = 1300, Robux = 119, ProductId = 0, Icon = "💠" },
	{ Key = "Gems3", Amount = 3600, Robux = 299, ProductId = 0, Icon = "💎" },
	{ Key = "Gems4", Amount = 8000, Robux = 599, ProductId = 0, Icon = "💎" },
}

Shop.Potions = {
	Potion_Luck = { Name = "Luck Potion", Boost = "Luck", Value = 0.5, Duration = 600, Icon = "🍀" },
	Potion_Coins = { Name = "Coin Potion", Boost = "Coins", Value = 1, Duration = 600, Icon = "💰" },
	Potion_Damage = { Name = "Damage Potion", Boost = "Damage", Value = 0.5, Duration = 600, Icon = "⚔️" },
}

return Shop
