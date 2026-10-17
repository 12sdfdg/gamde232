local Config = require(script.Parent.Config)

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Util.Abbrev(n: number): string
	n = math.floor(n)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local i = 1
	local v = n
	while math.abs(v) >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local s = if math.abs(v) >= 100 then string.format("%d", v) else string.format("%.1f", v)
	s = s:gsub("%.0$", "")
	return s .. SUFFIXES[i]
end

function Util.Commas(n: number): string
	local s = string.format("%d", math.floor(n))
	local formatted, k = s, 0
	repeat
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

-- RNG pick: try the rarest entries first with probability luck / chance.
-- `list` must be sorted from most common to rarest; list[1] is the fallback.
function Util.RollFrom(list, luck: number, rng: Random?)
	local r = rng or Random.new()
	for i = #list, 2, -1 do
		local item = list[i]
		if r:NextNumber() < math.min(1, luck / item.chance) then
			return item
		end
	end
	return list[1]
end

-- Shortest distance from a plot-local XZ point to the balloon path.
function Util.DistToPath(p: Vector2): number
	local best = math.huge
	local pts = Config.PathPoints
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		local d = (p - (a + ab * t)).Magnitude
		if d < best then
			best = d
		end
	end
	return best
end

-- Shared placement rule (server enforces, client previews).
-- origin: plot centre (Vector3); pos: world position; others: list of Vector3 turret positions.
function Util.CanPlace(origin: Vector3, pos: Vector3, others: { Vector3 }): (boolean, string?)
	local lx, lz = pos.X - origin.X, pos.Z - origin.Z
	local half = Config.PlotSize / 2 - 3
	if math.abs(lx) > half or math.abs(lz) > half then
		return false, "Place turrets on your own base!"
	end
	if Util.DistToPath(Vector2.new(lx, lz)) < Config.PathClearance then
		return false, "Too close to the path"
	end
	for _, o in others do
		if (Vector2.new(o.X, o.Z) - Vector2.new(pos.X, pos.Z)).Magnitude < Config.MinTurretSpacing then
			return false, "Too close to another turret"
		end
	end
	return true, nil
end

function Util.ChanceText(chance: number): string
	return "1 in " .. Util.Commas(chance)
end

return Util
