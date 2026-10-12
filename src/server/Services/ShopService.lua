-- Gamepasses, bundles and gem packs. Gem purchases are fully server-side.
-- Robux purchases work once real GamePassId / ProductId values are set in Configs/Shop.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Configs.Shop)

local Router = require(script.Parent.Parent.Router)
local DataService = require(script.Parent.DataService)
local FighterService = require(script.Parent.FighterService)

local ShopService = {}

local function grantGamepass(player, key)
	local data = DataService.Get(player)
	if data and Shop.GamepassByKey[key] then
		data.Gamepasses[key] = true
		FighterService.RefreshFollowers(player)
		DataService.Sync(player)
	end
end

local function grantBundle(player, bundle)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local grants = bundle.Grants
	for _, key in ipairs(grants.Gamepasses or {}) do
		data.Gamepasses[key] = true
	end
	for _, id in ipairs(grants.Fighters or {}) do
		FighterService.Give(player, id)
	end
	for item, amount in pairs(grants.Items or {}) do
		data.Items[item] = (data.Items[item] or 0) + amount
	end
	if grants.Materials then
		data.Items.Material = (data.Items.Material or 0) + grants.Materials
	end
	if grants.Coins then
		data.Coins += grants.Coins
	end
	data.Bundles[bundle.Key] = (data.Bundles[bundle.Key] or 0) + 1
	DataService.Sync(player)
	return true
end

local function findBundle(key)
	for _, b in ipairs(Shop.Bundles) do
		if b.Key == key then
			return b
		end
	end
	return nil
end

local function findGemPack(key)
	for _, p in ipairs(Shop.GemPacks) do
		if p.Key == key then
			return p
		end
	end
	return nil
end

function ShopService.Init()
	Router.OnRequest("BuyGamepass", function(player, key, method)
		local data = DataService.Get(player)
		local gp = typeof(key) == "string" and Shop.GamepassByKey[key]
		if not data or not gp then
			return { ok = false }
		end
		if data.Gamepasses[key] then
			return { ok = false, msg = "Already owned" }
		end
		if method == "Robux" then
			if gp.GamePassId == 0 then
				return { ok = false, msg = "Set GamePassId in Configs/Shop to sell for Robux" }
			end
			MarketplaceService:PromptGamePassPurchase(player, gp.GamePassId)
			return { ok = true, Prompted = true }
		end
		if not DataService.Spend(player, "Gems", gp.Gems) then
			return { ok = false, msg = "Not enough Gems" }
		end
		grantGamepass(player, key)
		return { ok = true }
	end, 3)

	Router.OnRequest("BuyBundle", function(player, key, method)
		local data = DataService.Get(player)
		local bundle = typeof(key) == "string" and findBundle(key)
		if not data or not bundle then
			return { ok = false }
		end
		if (data.Bundles[key] or 0) >= bundle.Limit then
			return { ok = false, msg = "Limit reached" }
		end
		if method == "Robux" then
			if bundle.ProductId == 0 then
				return { ok = false, msg = "Set ProductId in Configs/Shop to sell for Robux" }
			end
			MarketplaceService:PromptProductPurchase(player, bundle.ProductId)
			return { ok = true, Prompted = true }
		end
		if not DataService.Spend(player, "Gems", bundle.Gems) then
			return { ok = false, msg = "Not enough Gems" }
		end
		grantBundle(player, bundle)
		FighterService.RefreshFollowers(player)
		return { ok = true }
	end, 3)

	Router.OnRequest("BuyGems", function(player, key)
		local pack = typeof(key) == "string" and findGemPack(key)
		if not pack then
			return { ok = false }
		end
		if pack.ProductId == 0 then
			return { ok = false, msg = "Set ProductId in Configs/Shop to sell gems" }
		end
		MarketplaceService:PromptProductPurchase(player, pack.ProductId)
		return { ok = true, Prompted = true }
	end, 3)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, gp in ipairs(Shop.Gamepasses) do
			if gp.GamePassId == passId and gp.GamePassId ~= 0 then
				grantGamepass(player, gp.Key)
			end
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local profile = player and DataService.WaitFor(player, 10)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local data = profile.Data
		if data.Receipts[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local handled = false
		for _, pack in ipairs(Shop.GemPacks) do
			if pack.ProductId ~= 0 and pack.ProductId == receipt.ProductId then
				data.PaidGems += pack.Amount
				handled = true
			end
		end
		for _, bundle in ipairs(Shop.Bundles) do
			if bundle.ProductId ~= 0 and bundle.ProductId == receipt.ProductId then
				handled = grantBundle(player, bundle)
			end
		end
		if not handled then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.Receipts[receipt.PurchaseId] = os.time()
		-- Keep the receipt log small.
		local count, oldestKey, oldestTime = 0, nil, math.huge
		for id, t in pairs(data.Receipts) do
			count += 1
			if t < oldestTime then
				oldestKey, oldestTime = id, t
			end
		end
		if count > 60 and oldestKey then
			data.Receipts[oldestKey] = nil
		end
		FighterService.RefreshFollowers(player)
		DataService.Sync(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	DataService.Loaded:Connect(function(player, profile)
		for _, gp in ipairs(Shop.Gamepasses) do
			if gp.GamePassId ~= 0 and not profile.Data.Gamepasses[gp.Key] then
				task.spawn(function()
					local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gp.GamePassId)
					if ok and owns then
						grantGamepass(player, gp.Key)
					end
				end)
			end
		end
	end)
end

return ShopService
