-- Plot ownership and path geometry for each player's base.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlotService = {}

export type Plot = {
	index: number,
	model: Model,
	origin: Vector3,
	owner: Player?,
	path: { Vector3 },
	cumulative: { number },
	length: number,
	balloons: { any },
	turrets: { any },
	running: boolean,
	wave: number,
	lives: number,
	runId: number,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

function PlotService.Init(models: { Model })
	for i, model in models do
		local origin = model:GetAttribute("Origin") :: Vector3
		local path = {}
		local cumulative = { 0 }
		for k, p in Config.PathPoints do
			path[k] = origin + Vector3.new(p.X, 0, p.Y)
			if k > 1 then
				cumulative[k] = cumulative[k - 1] + (path[k] - path[k - 1]).Magnitude
			end
		end
		plots[i] = {
			index = i,
			model = model,
			origin = origin,
			owner = nil,
			path = path,
			cumulative = cumulative,
			length = cumulative[#cumulative],
			balloons = {},
			turrets = {},
			running = false,
			wave = 0,
			lives = Config.StartingLives,
			runId = 0,
		}
	end
end

local function setSign(plot: Plot, text: string)
	local board = plot.model:FindFirstChild("Sign", true)
	local label = board and board:FindFirstChild("Owner", true)
	if label then
		(label :: TextLabel).Text = text
	end
end

function PlotService.Assign(player: Player): Plot?
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			plot.model:SetAttribute("OwnerId", player.UserId)
			player:SetAttribute("PlotIndex", plot.index)
			setSign(plot, player.DisplayName .. "'s Base")
			byPlayer[player] = plot
			return plot
		end
	end
	return nil
end

function PlotService.Release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.owner = nil
	plot.running = false
	plot.runId += 1
	plot.wave = 0
	plot.lives = Config.StartingLives
	plot.model:SetAttribute("OwnerId", 0)
	setSign(plot, "Empty Base")
end

function PlotService.Get(player: Player): Plot?
	return byPlayer[player]
end

function PlotService.All(): { Plot }
	return plots
end

-- Position along the path at distance d (clamped).
function PlotService.PointAt(plot: Plot, d: number): (Vector3, Vector3)
	local cum = plot.cumulative
	local path = plot.path
	for k = 2, #path do
		if d <= cum[k] then
			local a, b = path[k - 1], path[k]
			local t = (d - cum[k - 1]) / (cum[k] - cum[k - 1])
			return a:Lerp(b, t), (b - a).Unit
		end
	end
	return path[#path], (path[#path] - path[#path - 1]).Unit
end

function PlotService.SpawnCFrame(plot: Plot): CFrame
	local att = plot.model:FindFirstChild("SpawnPoint", true) :: Attachment?
	local pos = if att then att.WorldPosition else plot.origin + Vector3.new(0, 5, 0)
	return CFrame.lookAt(pos, Vector3.new(plot.origin.X, pos.Y, plot.origin.Z))
end

function PlotService.TeleportHome(player: Player)
	local plot = byPlayer[player]
	local char = player.Character
	if plot and char then
		char:PivotTo(PlotService.SpawnCFrame(plot))
	end
end

return PlotService
