--!nonstrict
-- Яйця, улюбленці, екіпірування.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local PlayerState = require(script.Parent.PlayerState)

local HatchResultRemote = Net.Get("HatchResult")

local PetService = {}

local rng = Random.new()
local lastHatch: { [Player]: number } = {}

-- Зовнішній колбек для пропозиції геймпаса (встановлюється з ShopService, щоб уникнути циклічного require).
PetService.PromptPass = function(_player: Player, _key: string) end

local function boostOf(name: string): number
	local def = Config.GetPetDef(name)
	return if def then def.boost else 0
end

local function roll(egg: any, luck: number): string
	local total = 0
	local weights = {}
	for i, pet in egg.pets do
		local weight = pet.chance * (if Config.LuckyRarities[pet.rarity] then luck else 1)
		weights[i] = weight
		total += weight
	end
	local pick = rng:NextNumber(0, total)
	for i, pet in egg.pets do
		pick -= weights[i]
		if pick <= 0 then
			return pet.name
		end
	end
	return egg.pets[#egg.pets].name
end

function PetService.EquipBest(player: Player, data: DataService.Data)
	local sorted = table.clone(data.pets)
	table.sort(sorted, function(a, b)
		return boostOf(a.name) > boostOf(b.name)
	end)
	local slots = PlayerState.EquipSlots(player)
	local best: { [string]: boolean } = {}
	for i = 1, math.min(slots, #sorted) do
		best[sorted[i].uid] = true
	end
	for _, pet in data.pets do
		pet.equipped = best[pet.uid] == true
	end
	PlayerState.MarkDirty(player)
end

local function findPet(data: DataService.Data, uid: string)
	for index, pet in data.pets do
		if pet.uid == uid then
			return pet, index
		end
	end
	return nil, nil
end

local function equippedCount(data: DataService.Data): number
	local count = 0
	for _, pet in data.pets do
		if pet.equipped then
			count += 1
		end
	end
	return count
end

function PetService.Hatch(player: Player, eggId: string, count: number)
	local data = DataService.Get(player)
	local session = PlayerState.GetSession(player)
	local egg = Config.GetEgg(eggId)
	if not data or not session or not egg then
		return
	end
	local now = os.clock()
	if lastHatch[player] and now - lastHatch[player] < 0.6 then
		return
	end
	lastHatch[player] = now

	count = if count == 3 then 3 else 1
	if count == 3 and not session.passes.TripleHatch then
		PetService.PromptPass(player, "TripleHatch")
		return
	end
	if #data.pets + count > Config.Pets.InventoryLimit then
		PlayerState.Notify(player, "Pet inventory is full! Delete some pets 🐾", "warn")
		return
	end
	local cost = egg.cost * count
	if not PlayerState.SpendWins(player, data, cost, "Egg", egg.id) then
		PlayerState.Notify(player, string.format("Need %s 🏆 Wins — race further to earn more!", Format.Number(cost)), "warn")
		return
	end

	local luck = PlayerState.Luck(player, data)
	local hatched = {}
	for _ = 1, count do
		local name = roll(egg, luck)
		table.insert(data.pets, { uid = DataService.NewUid(), name = name, equipped = false })
		table.insert(hatched, name)
	end
	data.eggsHatched += count

	if data.settings.autoEquip then
		PetService.EquipBest(player, data)
	end
	PlayerState.MarkDirty(player)
	PlayerState.LogFunnel(player, 4, "First Egg")
	HatchResultRemote:FireClient(player, { eggId = egg.id, pets = hatched })
end

function PetService.Equip(player: Player, uid: string, equip: boolean)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local pet = findPet(data, uid)
	if not pet then
		return
	end
	if equip and not pet.equipped and equippedCount(data) >= PlayerState.EquipSlots(player) then
		PlayerState.Notify(player, "All pet slots are full! Get +3 Pet Slots in the shop 🛒", "warn")
		PetService.PromptPass(player, "ExtraPets")
		return
	end
	pet.equipped = equip
	PlayerState.MarkDirty(player)
end

function PetService.Delete(player: Player, uid: string)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local _, index = findPet(data, uid)
	if index then
		table.remove(data.pets, index)
		PlayerState.MarkDirty(player)
	end
end

-- Видаляє всі неекіпіровані улюбленці вказаної рідкості (швидке прибирання інвентарю).
function PetService.DeleteRarity(player: Player, rarity: string)
	local data = DataService.Get(player)
	if not data or not Config.Rarities[rarity] then
		return
	end
	local kept = {}
	for _, pet in data.pets do
		local def = Config.GetPetDef(pet.name)
		if pet.equipped or not def or def.rarity ~= rarity then
			table.insert(kept, pet)
		end
	end
	data.pets = kept
	PlayerState.MarkDirty(player)
end

function PetService.Start(eggPrompts: { [string]: { ProximityPrompt } })
	for eggId, prompts in eggPrompts do
		for _, prompt in prompts do
			prompt.Triggered:Connect(function(player)
				PetService.Hatch(player, eggId, prompt:GetAttribute("Count") :: number)
			end)
		end
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastHatch[player] = nil
	end)
end

return PetService
