-- Fighter inventory (equip/lock/delete/upgrade), star summoning with pity, and follower models.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Configs = ReplicatedStorage.Configs
local Game = require(Configs.Game)
local Fighters = require(Configs.Fighters)
local Rarities = require(Configs.Rarities)
local Worlds = require(Configs.Worlds)
local Stats = require(ReplicatedStorage.Modules.Stats)
local Rig = require(ReplicatedStorage.Modules.Rig)

local Router = require(script.Parent.Parent.Router)
local DataService = require(script.Parent.DataService)

local FighterService = {}

local FOLLOWER_SCALE = 0.72
local followers = {} -- [player] = { [uid] = model }
local followerFolder

-- Inventory helpers --------------------------------------------------------------------------------

local function count(dict)
	local n = 0
	for _ in pairs(dict) do
		n += 1
	end
	return n
end

local function isEquipped(data, uid)
	return table.find(data.Equipped, uid) ~= nil
end

function FighterService.Give(player, id)
	local data = DataService.Get(player)
	local def = Fighters.ById[id]
	if not data or not def then
		return nil
	end
	local uid = tostring(data.NextUid)
	data.NextUid += 1
	data.Fighters[uid] = { Id = id, Level = 1, Locked = Rarities.Rank(def.Rarity) >= 4 }
	local isNew = not data.Index[id]
	data.Index[id] = true
	DataService.Sync(player)
	return uid, isNew
end

local function sellValue(def)
	local info = Rarities.Info[def.Rarity]
	local world = math.max(def.World, 1)
	return math.floor(info.Sell * (8 ^ (world - 1)))
end

-- Followers ----------------------------------------------------------------------------------------

local function groundY(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(position + Vector3.new(0, 40, 0), Vector3.new(0, -140, 0), params)
	return result and result.Position.Y or position.Y
end

local function createFollower(player, uid, entry)
	local def = Fighters.ById[entry.Id]
	if not def then
		return nil
	end
	local model = Rig.BuildFighter(def, FOLLOWER_SCALE)
	model.Name = player.Name .. "_" .. def.Name
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Uid", uid)
	model:SetAttribute("FighterId", def.Id)
	model:SetAttribute("State", "Idle")
	local root = model.PrimaryPart

	local attachment = Instance.new("Attachment")
	attachment.Name = "Align"
	attachment.Parent = root

	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxForce = 1e7
	align.MaxVelocity = 95
	align.Responsiveness = 22
	align.Parent = root

	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.MaxTorque = 1e7
	orient.Responsiveness = 24
	orient.Parent = root

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local start = hrp and hrp.Position + Vector3.new(math.random(-4, 4), 0, math.random(3, 6)) or Vector3.new(0, 10, 0)
	model:PivotTo(CFrame.new(start))
	align.Position = start
	orient.CFrame = CFrame.new()
	model.Parent = followerFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	CollectionService:AddTag(model, "AnimeRig")
	CollectionService:AddTag(model, "Follower")
	return model
end

function FighterService.RefreshFollowers(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	followers[player] = followers[player] or {}
	local current = followers[player]
	for uid, model in pairs(current) do
		if not isEquipped(data, uid) or not data.Fighters[uid] then
			model:Destroy()
			current[uid] = nil
		end
	end
	for _, uid in ipairs(data.Equipped) do
		if not current[uid] and data.Fighters[uid] then
			current[uid] = createFollower(player, uid, data.Fighters[uid])
		end
	end
end

function FighterService.GetFollowers(player)
	return followers[player] or {}
end

function FighterService.TeleportFollowers(player, position)
	for _, model in pairs(FighterService.GetFollowers(player)) do
		if model.PrimaryPart then
			local p = position + Vector3.new(math.random(-5, 5), 2, math.random(-5, 5))
			model:PivotTo(CFrame.new(p))
			local align = model.PrimaryPart:FindFirstChildOfClass("AlignPosition")
			if align then
				align.Position = p
			end
		end
	end
end

-- Called ~10x per second: decide where each follower should be.
local function updateFollowers(getTarget)
	for player, list in pairs(followers) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local target = getTarget and getTarget(player)
			local ordered = {}
			for uid, model in pairs(list) do
				if model.Parent and model.PrimaryPart then
					table.insert(ordered, { uid = uid, model = model })
				end
			end
			table.sort(ordered, function(a, b)
				return a.uid < b.uid
			end)
			local n = #ordered
			for i, item in ipairs(ordered) do
				local model = item.model
				local root = model.PrimaryPart
				local align = root:FindFirstChildOfClass("AlignPosition")
				local orient = root:FindFirstChildOfClass("AlignOrientation")
				if align and orient then
					local goal, lookAt
					if target and target.PrimaryPart then
						local center = target.PrimaryPart.Position
						local radius = (target:GetAttribute("Radius") or 4) + 2.5
						local angle = (i / math.max(n, 1)) * math.pi * 2 + (player.UserId % 7)
						goal = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
						lookAt = center
					else
						local row = math.floor((i - 1) / 4)
						local col = (i - 1) % 4
						local offset = Vector3.new((col - 1.5) * 3.6, 0, 5 + row * 4)
						goal = (hrp.CFrame * CFrame.new(offset)).Position
						lookAt = goal + hrp.CFrame.LookVector * 10
					end
					local y = groundY(goal, { followerFolder, character }) + (model:GetAttribute("HipHeight") or 2)
					goal = Vector3.new(goal.X, y, goal.Z)
					-- Teleport if far away (respawn, world change).
					if (root.Position - goal).Magnitude > 160 then
						model:PivotTo(CFrame.new(goal))
					end
					align.Position = goal
					local flatLook = Vector3.new(lookAt.X, goal.Y, lookAt.Z)
					if (flatLook - goal).Magnitude > 0.1 then
						orient.CFrame = CFrame.lookAt(goal, flatLook)
					end
					local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(goal.X, 0, goal.Z)).Magnitude
					local state
					if distance > 2.5 then
						state = "Run"
					elseif target then
						state = "Attack"
					else
						state = "Idle"
					end
					if model:GetAttribute("State") ~= state then
						model:SetAttribute("State", state)
					end
				end
			end
		end
	end
end

-- Summoning ----------------------------------------------------------------------------------------

local function rollFighter(pool, luck, pityHit, rng)
	local candidates = {}
	local total = 0
	local perRarity = {}
	for _, def in ipairs(pool) do
		perRarity[def.Rarity] = (perRarity[def.Rarity] or 0) + 1
	end
	for _, def in ipairs(pool) do
		local rank = Rarities.Rank(def.Rarity)
		if not pityHit or rank >= 4 then
			local weight = Rarities.Info[def.Rarity].Weight / perRarity[def.Rarity]
			if rank >= 3 then
				weight *= luck
			end
			total += weight
			table.insert(candidates, { def = def, weight = weight })
		end
	end
	local pick = rng:NextNumber() * total
	for _, c in ipairs(candidates) do
		pick -= c.weight
		if pick <= 0 then
			return c.def
		end
	end
	return candidates[#candidates].def
end

local rng = Random.new()

local function summon(player, worldId, amount, currency)
	local data = DataService.Get(player)
	if not data then
		return { ok = false }
	end
	worldId = tonumber(worldId)
	local world = worldId and Worlds.ById[worldId]
	if not world or not data.Worlds[tostring(worldId)] then
		return { ok = false, msg = "World locked" }
	end
	if player:GetAttribute("World") ~= worldId then
		return { ok = false, msg = "Go to this world's summon machine" }
	end
	amount = tonumber(amount)
	if amount ~= 1 and amount ~= 3 and amount ~= 8 then
		return { ok = false, msg = "Bad amount" }
	end
	if amount == 8 and not data.Gamepasses.MultiOpen then
		return { ok = false, msg = "Requires Multi Open gamepass" }
	end
	if currency ~= "Coins" and currency ~= "Gems" then
		return { ok = false, msg = "Bad currency" }
	end
	if count(data.Fighters) + amount > Game.MaxInventory then
		return { ok = false, msg = "Inventory full! Delete some fighters." }
	end
	local price = (currency == "Coins" and world.SummonCost or Game.SummonGemCost) * amount
	if not DataService.Spend(player, currency, price) then
		return { ok = false, msg = "Not enough " .. currency }
	end

	local luck = Stats.Multipliers(data).Luck
	local pool = Fighters.ByWorld[worldId]
	local results = {}
	for _ = 1, amount do
		data.Pity += 1
		local pityHit = data.Pity >= Game.SummonPity
		local def = rollFighter(pool, luck, pityHit, rng)
		if Rarities.Rank(def.Rarity) >= 4 then
			data.Pity = 0
		end
		local uid, isNew = FighterService.Give(player, def.Id)
		table.insert(results, { Uid = uid, Id = def.Id, New = isNew })
	end
	data.Stats.StarOpens += amount
	DataService.Sync(player)
	return { ok = true, Results = results, Pity = data.Pity }
end

-- Request handlers -------------------------------------------------------------------------------

local function validUid(data, uid)
	return typeof(uid) == "string" and data.Fighters[uid] ~= nil
end

function FighterService.Init()
	followerFolder = workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("Followers")

	Router.OnRequest("Equip", function(player, uid)
		local data = DataService.Get(player)
		if not data or not validUid(data, uid) or isEquipped(data, uid) then
			return { ok = false }
		end
		if #data.Equipped >= Stats.MaxEquip(data) then
			return { ok = false, msg = "Max fighters equipped!" }
		end
		table.insert(data.Equipped, uid)
		FighterService.RefreshFollowers(player)
		DataService.Sync(player)
		return { ok = true }
	end, 10)

	Router.OnRequest("Unequip", function(player, uid)
		local data = DataService.Get(player)
		if not data or typeof(uid) ~= "string" then
			return { ok = false }
		end
		local index = table.find(data.Equipped, uid)
		if index then
			table.remove(data.Equipped, index)
		end
		FighterService.RefreshFollowers(player)
		DataService.Sync(player)
		return { ok = true }
	end, 10)

	Router.OnRequest("EquipBest", function(player)
		local data = DataService.Get(player)
		if not data then
			return { ok = false }
		end
		local list = {}
		for uid, entry in pairs(data.Fighters) do
			local def = Fighters.ById[entry.Id]
			if def then
				table.insert(list, { uid = uid, dps = Stats.FighterDps(def, entry.Level) })
			end
		end
		table.sort(list, function(a, b)
			return a.dps > b.dps
		end)
		data.Equipped = {}
		for i = 1, math.min(#list, Stats.MaxEquip(data)) do
			table.insert(data.Equipped, list[i].uid)
		end
		FighterService.RefreshFollowers(player)
		DataService.Sync(player)
		return { ok = true }
	end, 3)

	Router.OnRequest("Lock", function(player, uid)
		local data = DataService.Get(player)
		if not data or not validUid(data, uid) then
			return { ok = false }
		end
		data.Fighters[uid].Locked = not data.Fighters[uid].Locked
		DataService.Sync(player)
		return { ok = true, Locked = data.Fighters[uid].Locked }
	end, 10)

	Router.OnRequest("Delete", function(player, uids)
		local data = DataService.Get(player)
		if not data or type(uids) ~= "table" or #uids > 300 then
			return { ok = false }
		end
		local removed, coins = 0, 0
		for _, uid in ipairs(uids) do
			if validUid(data, uid) then
				local entry = data.Fighters[uid]
				local def = Fighters.ById[entry.Id]
				if not entry.Locked and not isEquipped(data, uid) and def then
					coins += sellValue(def)
					data.Fighters[uid] = nil
					removed += 1
				end
			end
		end
		if removed == 0 then
			return { ok = false, msg = "Nothing deleted (locked or equipped)" }
		end
		data.Coins += coins
		DataService.Sync(player)
		return { ok = true, Removed = removed, Coins = coins }
	end, 4)

	Router.OnRequest("Upgrade", function(player, uid)
		local data = DataService.Get(player)
		if not data or not validUid(data, uid) then
			return { ok = false }
		end
		local entry = data.Fighters[uid]
		local def = Fighters.ById[entry.Id]
		if entry.Level >= Game.FighterMaxLevel then
			return { ok = false, msg = "Max level!" }
		end
		local cost = Stats.UpgradeCost(def, entry.Level)
		if (data.Items.Material or 0) < cost.Materials or data.Power < cost.Power then
			return { ok = false, msg = "Need more Materials or Power" }
		end
		data.Items.Material -= cost.Materials
		data.Power -= cost.Power
		entry.Level += 1
		DataService.Sync(player)
		return { ok = true, Level = entry.Level }
	end, 8)

	Router.OnRequest("Summon", summon, 6)

	DataService.Loaded:Connect(function(player, profile)
		local data = profile.Data
		if data.NextUid == 1 then
			for _, id in ipairs(Game.StartingFighters) do
				local uid = FighterService.Give(player, id)
				table.insert(data.Equipped, uid)
			end
		end
		-- Drop equipped entries that no longer exist.
		for i = #data.Equipped, 1, -1 do
			if not data.Fighters[data.Equipped[i]] then
				table.remove(data.Equipped, i)
			end
		end
		while #data.Equipped > Stats.MaxEquip(data) do
			table.remove(data.Equipped)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, model in pairs(followers[player] or {}) do
			model:Destroy()
		end
		followers[player] = nil
	end)
end

function FighterService.Start(getTarget)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			updateFollowers(getTarget)
		end
	end)
end

return FighterService
