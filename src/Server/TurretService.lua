-- Validates placement, builds turret models and runs their targeting/firing.

local TurretService = {}

local ctx
local turrets = {}
local folder
local nextId = 0

local function buildModel(def, cframe: CFrame)
	local model = Instance.new("Model")
	model.Name = def.name

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(2, 6, 6)
	base.CFrame = cframe * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = Color3.fromRGB(60, 60, 70)
	base.Material = Enum.Material.Metal
	base.Anchored = true
	base.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(3, 2.4, 3)
	head.CFrame = cframe * CFrame.new(0, 3.2, 0)
	head.Color = def.color
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Size = Vector3.new(0.8, 0.8, 4)
	barrel.CFrame = head.CFrame * CFrame.new(0, 0, -2.5)
	barrel.Color = Color3.fromRGB(40, 40, 45)
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = true
	barrel.CanCollide = false
	barrel.Parent = model

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(120, 22)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.MaxDistance = 90
	tag.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = string.format("%s  •  1 in %d", def.name, def.oneIn)
	label.TextColor3 = def.color
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = tag
	tag.Parent = head

	model.PrimaryPart = base
	return model, head, barrel
end

local function canPlaceAt(position: Vector3): (boolean, string?)
	local MapBuilder = ctx.MapBuilder
	local rules = ctx.Config.Placement
	if MapBuilder.distanceToPath(ctx.map.waypoints, position) < rules.pathClearance then
		return false, "Too close to the path"
	end
	for _, t in ipairs(turrets) do
		if (t.position - position).Magnitude < rules.minSpacing then
			return false, "Too close to another turret"
		end
	end
	local ground = ctx.map.folder:FindFirstChild("Ground")
	local rel = ground.CFrame:PointToObjectSpace(position)
	if math.abs(rel.X) > ground.Size.X / 2 - 3 or math.abs(rel.Z) > ground.Size.Z / 2 - 3 then
		return false, "Outside the map"
	end
	return true
end

function TurretService.init(context)
	ctx = context
	folder = Instance.new("Folder")
	folder.Name = "Turrets"
	folder.Parent = workspace

	ctx.Net.funcs.Place.OnServerInvoke = function(player, turretId, position)
		return TurretService.place(player, turretId, position)
	end
	ctx.Net.funcs.Sell.OnServerInvoke = function(player, id)
		return TurretService.sell(player, id)
	end
end

function TurretService.place(player: Player, turretId: any, position: any)
	if typeof(turretId) ~= "string" or typeof(position) ~= "Vector3" then
		return false, "Bad request"
	end
	local def = ctx.Config.Turrets[turretId]
	local d = ctx.PlayerData.get(player)
	if not def or not d then
		return false, "Unknown turret"
	end
	if (d.inventory[turretId] or 0) <= 0 then
		return false, "You don't own this turret"
	end

	position = Vector3.new(position.X, 0, position.Z)
	local ok, reason = canPlaceAt(position)
	if not ok then
		return false, reason
	end

	ctx.PlayerData.addToInventory(player, turretId, -1)

	nextId += 1
	local model, head, barrel = buildModel(def, CFrame.new(position))
	model:SetAttribute("TurretId", nextId)
	model:SetAttribute("Owner", player.UserId)
	model.Parent = folder

	table.insert(turrets, {
		id = nextId,
		def = def,
		turretId = turretId,
		owner = player,
		model = model,
		head = head,
		barrel = barrel,
		position = position,
		cooldown = 0,
	})
	return true
end

-- Picking a turret back up returns it to the owner's inventory.
function TurretService.sell(player: Player, id: any)
	for i, t in ipairs(turrets) do
		if t.id == id and t.owner == player then
			table.remove(turrets, i)
			t.model:Destroy()
			ctx.PlayerData.addToInventory(player, t.turretId, 1)
			return true
		end
	end
	return false
end

function TurretService.removeOwnedBy(player: Player)
	for i = #turrets, 1, -1 do
		if turrets[i].owner == player then
			turrets[i].model:Destroy()
			table.remove(turrets, i)
		end
	end
end

function TurretService.update(dt: number)
	for _, t in ipairs(turrets) do
		t.cooldown -= dt
		if t.cooldown <= 0 then
			local origin = t.head.Position
			local target = ctx.BalloonService.findTarget(origin, t.def.range)
			if target then
				t.cooldown = t.def.cooldown

				local aim = Vector3.new(target.part.Position.X, origin.Y, target.part.Position.Z)
				if (aim - origin).Magnitude > 0.1 then
					t.head.CFrame = CFrame.lookAt(origin, aim)
					t.barrel.CFrame = t.head.CFrame * CFrame.new(0, 0, -2.5)
				end

				local muzzle = (t.barrel.CFrame * CFrame.new(0, 0, -2)).Position
				ctx.Net.events.FireBeam:FireAllClients(muzzle, target.part.Position, t.def.color)
				ctx.BalloonService.damage(target, t.def.damage, t.owner)
			end
		end
	end
end

return TurretService
