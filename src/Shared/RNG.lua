--!strict
-- Weighted random selection shared by client (for display) and server (authoritative rolls).

local RNG = {}

-- entries: array of { id = string, weight = number }. Returns a chosen id.
function RNG.weighted(entries: { { id: string, weight: number } }): string
	local total = 0
	for _, e in ipairs(entries) do
		total += e.weight
	end
	local r = math.random() * total
	local acc = 0
	for _, e in ipairs(entries) do
		acc += e.weight
		if r <= acc then
			return e.id
		end
	end
	return entries[#entries].id
end

-- Builds weighted entries from a turret table keyed by id, using weight = 1 / oneIn.
function RNG.turretEntries(turrets: { [string]: { oneIn: number } }): { { id: string, weight: number } }
	local entries = {}
	for id, def in pairs(turrets) do
		table.insert(entries, { id = id, weight = 1 / def.oneIn })
	end
	return entries
end

return RNG
