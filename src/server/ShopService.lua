--!nonstrict
-- Геймпаси й Developer Products. Покупки обробляються ідемпотентно через ProcessReceipt.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local PlayerState = require(script.Parent.PlayerState)
local PetService = require(script.Parent.PetService)

local ShopService = {}

local function canTestPurchase(): boolean
	return RunService:IsStudio() and Config.TEST_PURCHASES_IN_STUDIO
end

local function applyPass(player: Player, key: string)
	local session = PlayerState.GetSession(player)
	local data = DataService.Get(player)
	if not session or session.passes[key] then
		return
	end
	session.passes[key] = true
	if key == "VIP" then
		player:SetAttribute("VIP", true)
	elseif key == "ExtraPets" and data and data.settings.autoEquip then
		PetService.EquipBest(player, data)
	end
	PlayerState.MarkDirty(player)
end

function ShopService.LoadPasses(player: Player)
	for _, pass in Config.GamePasses do
		if pass.id ~= 0 then
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
				if ok and owns and player.Parent then
					applyPass(player, pass.key)
				end
			end)
		end
	end
end

function ShopService.PromptPass(player: Player, key: string)
	local pass = Config.GetPass(key)
	local session = PlayerState.GetSession(player)
	if not pass or not session or session.passes[key] then
		return
	end
	if pass.id == 0 then
		if canTestPurchase() then
			applyPass(player, key)
			PlayerState.Notify(player, "[Studio test] Unlocked " .. pass.name .. "!", "success")
		else
			PlayerState.Notify(player, pass.name .. " is coming soon!", "info")
		end
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
end

local function grantProduct(player: Player, data: DataService.Data, product: any)
	if product.kind == "Wins" then
		local amount = math.floor(product.amount * (1 + data.rebirths))
		PlayerState.AddWins(player, data, amount, "Purchase", product.key)
		PlayerState.Notify(player, string.format("Thanks for your support! +%s 🏆 Wins", Format.Number(amount)), "success")
	elseif product.kind == "Boost" then
		PlayerState.AddBoost(player, data, product.boost, product.seconds)
		PlayerState.Notify(player, string.format("%s activated for %s! 🚀", Config.Boosts[product.boost].name, Format.Time(product.seconds)), "success")
	end
end

function ShopService.PromptProduct(player: Player, key: string)
	local product = Config.GetProduct(key)
	if not product then
		return
	end
	if product.id == 0 then
		local data = DataService.Get(player)
		if canTestPurchase() and data then
			grantProduct(player, data, product)
		else
			PlayerState.Notify(player, product.name .. " is coming soon!", "info")
		end
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if not DataService.HasReceipt(data, purchaseId) then
		local product = nil
		for _, p in Config.Products do
			if p.id ~= 0 and p.id == receipt.ProductId then
				product = p
			end
		end
		if not product then
			warn("[ShopService] Невідомий продукт", receipt.ProductId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		grantProduct(player, data, product)
		DataService.AddReceipt(data, purchaseId)
	end
	-- Зберігаємо одразу: якщо збереження не вдалося, Roblox повторить виклик,
	-- а receipt уже в пам'яті, тож товар не видасться двічі.
	if not DataService.Save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.Start()
	PetService.PromptPass = ShopService.PromptPass
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in Config.GamePasses do
			if pass.id == passId then
				applyPass(player, pass.key)
				PlayerState.Notify(player, "Thank you! " .. pass.name .. " unlocked! 💎", "success")
			end
		end
	end)
end

return ShopService
