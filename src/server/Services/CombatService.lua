-- Server-authoritative combat: targeting, fighter damage ticks, clicks, special ability, kill rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Configs = ReplicatedStorage.Configs
local Game = require(Configs.Game)
local Fighters = require(Configs.Fighters)
local Stats = require(ReplicatedStorage.Modules.Stats)

local Router = require(script.Parent.Parent.Router)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local FighterService = require(script.Parent.FighterService)
local RewardService = require(script.Parent.RewardService)

local CombatService = {}

local targets = {} -- [player] = enemy model
local rng = Random.new()

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function validTarget(player, model, range)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not CollectionService:HasTag(model, "Enemy") then
		return false
	end
	if not EnemyService.IsAlive(model) or model:GetAttribute("World") ~= player:GetAttribute("World") then
		return false
	end
	local hrp = rootOf(player)
	if not hrp or not model.PrimaryPart then
		return false
	end
	return (hrp.Position - model.PrimaryPart.Position).Magnitude <= range
end

function CombatService.GetTarget(player)
	local target = targets[player]
	if target and target.Parent and EnemyService.IsAlive(target) then
		return target
	end
	return nil
end

function CombatService.ClearTarget(player)
	if targets[player] then
		targets[player] = nil
		Router.Fx(player, { Kind = "Target", Target = nil })
	end
end

local function hitPosition(model)
	local root = model.PrimaryPart
	local height = model:GetAttribute("Height") or 6
	local radius = model:GetAttribute("Radius") or 3
	return root.Position + Vector3.new(rng:NextNumber(-radius, radius) * 0.6, height * 0.25 + rng:NextNumber(0, height * 0.3), rng:NextNumber(-radius, radius) * 0.6)
end

local function applyDamage(player, model, amount, kind)
	local crit = rng:NextNumber() < 0.1
	if crit then
		amount *= 2
	end
	local dealt = EnemyService.Damage(model, player, amount)
	if dealt > 0 then
		Router.Fx(player, { Kind = "Damage", Target = model, Position = hitPosition(model), Amount = dealt, Crit = crit, Source = kind })
	end
	return dealt
end

local function tick()
	for player, target in pairs(targets) do
		if not player.Parent or not validTarget(player, target, Game.AttackRange + 80) then
			CombatService.ClearTarget(player)
		else
			local data = DataService.Get(player)
			if data then
				local mult = Stats.Multipliers(data).Damage
				local total = 0
				for uid, follower in pairs(FighterService.GetFollowers(player)) do
					if follower:GetAttribute("State") == "Attack" then
						local entry = data.Fighters[uid]
						local def = entry and Fighters.ById[entry.Id]
						if def then
							total += Stats.FighterDps(def, entry.Level) * mult * Game.CombatTick
						end
					end
				end
				if total > 0 then
					applyDamage(player, target, total, "Fighters")
				end
			end
		end
	end
end

local function onKilled(model, def, contributors)
	for player in pairs(contributors) do
		if player.Parent then
			local drops = RewardService.GrantKill(player, def)
			Router.Fx(player, { Kind = "Kill", Target = model, Position = model.PrimaryPart and model.PrimaryPart.Position, Drops = drops, Boss = def.Boss })
		end
	end
	for player, target in pairs(targets) do
		if target == model then
			targets[player] = nil
			Router.Fx(player, { Kind = "Target", Target = nil, Killed = true })
		end
	end
end

function CombatService.Init()
	Router.OnAction("Attack", function(player, model)
		if not validTarget(player, model, Game.AttackRange) then
			return
		end
		targets[player] = model
		Router.Fx(player, { Kind = "Target", Target = model })
	end, 6)

	Router.OnAction("StopAttack", function(player)
		CombatService.ClearTarget(player)
	end, 6)

	Router.OnAction("Click", function(player)
		local data = DataService.Get(player)
		if not data then
			return
		end
		local power = Stats.ClickPower(data)
		data.Stats.Clicks += 1
		DataService.Add(player, "Power", power)
		local target = CombatService.GetTarget(player)
		if target and validTarget(player, target, Game.AttackRange + 40) then
			local damage = Stats.TeamDps(data) * 0.12 + power * 4
			applyDamage(player, target, damage, "Click")
		end
	end, Game.ClickRate)

	Router.OnAction("Ability", function(player)
		local profile = DataService.Profile(player)
		if not profile then
			return
		end
		local now = os.clock()
		if now < profile.Session.AbilityReady then
			return
		end
		local target = CombatService.GetTarget(player)
		if not target or not validTarget(player, target, Game.AttackRange + 40) then
			Router.Notify(player, "Select an enemy first!", "error")
			return
		end
		profile.Session.AbilityReady = now + Game.AbilityCooldown
		profile.Data.Stats.AbilityUses += 1
		local data = profile.Data
		local damage = Stats.TeamDps(data) * Game.AbilityDpsMultiplier + 50 * data.Level
		Router.FxAll({ Kind = "Ability", Position = target.PrimaryPart.Position, Owner = player.UserId })
		task.delay(0.35, function()
			if target.Parent and EnemyService.IsAlive(target) then
				applyDamage(player, target, damage, "Ability")
			end
		end)
		Router.Fx(player, { Kind = "AbilityCooldown", Ready = Game.AbilityCooldown })
	end, 2)

	Players.PlayerRemoving:Connect(function(player)
		targets[player] = nil
	end)

	EnemyService.Killed:Connect(onKilled)
end

function CombatService.Start()
	task.spawn(function()
		while true do
			task.wait(Game.CombatTick)
			local ok, err = pcall(tick)
			if not ok then
				warn("[CombatService] " .. tostring(err))
			end
		end
	end)
end

return CombatService
