--!strict
-- Pure mobility rules (tested offline): rescue quotes, destinations and station placement.
-- Shared so the client can show the exact quote before the player confirms.

local Mobility = require(script.Parent.Parent.Config.Mobility)

local MobilityRules = {}

export type Station = { id: string, cx: number, d: number, cz: number }

export type Quote = {
	free: boolean, -- above the free-return depth
	cost: number, -- full price
	pay: number, -- what will actually be charged (never more than the coins held)
	waived: number, -- part forgiven because the player cannot afford it
	destination: string, -- station id or "surface"
	destinationName: string,
}

function MobilityRules.rescueCost(depth: number, backpackValue: number): number
	local r = Mobility.Rescue
	local raw = r.depthRate * depth + r.valueRate * backpackValue
	return math.floor(math.clamp(raw, r.min, r.maxBase + r.maxPerMeter * depth) + 0.5)
end

-- Deepest station above `depth` (at least 5 m above), or nil for the surface.
function MobilityRules.nearestStationAbove(stations: { Station }, depth: number): Station?
	local best: Station? = nil
	for _, station in stations do
		if station.d < depth - 5 and (not best or station.d > best.d) then
			best = station
		end
	end
	return best
end

-- `costFactor` lowers the price (the "unaided_climb" feat, Config/Feats); 1 when omitted.
function MobilityRules.quote(
	depth: number,
	backpackValue: number,
	coins: number,
	stations: { Station },
	costFactor: number?
): Quote
	local station = MobilityRules.nearestStationAbove(stations, depth)
	local destination = if station then station.id else "surface"
	local def = station and Mobility.StationById[station.id]
	local destinationName = if def then def.name else "la superficie"
	if depth <= Mobility.FreeReturnDepth then
		return {
			free = true,
			cost = 0,
			pay = 0,
			waived = 0,
			destination = destination,
			destinationName = destinationName,
		}
	end
	local cost = math.floor(MobilityRules.rescueCost(depth, backpackValue) * (costFactor or 1) + 0.5)
	local pay = math.min(cost, math.max(0, math.floor(coins)))
	return {
		free = false,
		cost = cost,
		pay = pay,
		waived = cost - pay,
		destination = destination,
		destinationName = destinationName,
	}
end

-- Which station can be installed at `depth` (metres), given those already owned. Returns the
-- definition or nil plus a reason.
function MobilityRules.installable(depth: number, owned: { Station }): (Mobility.StationDef?, string?)
	local have = {}
	for _, s in owned do
		have[s.id] = true
	end
	for _, def in Mobility.Stations do
		if def.cost > 0 and depth >= def.minDepth and depth < def.maxDepth then
			if have[def.id] then
				return nil, "Ya tienes la " .. def.name .. "."
			end
			return def, nil
		end
	end
	return nil, "Aquí no se puede instalar ninguna estación."
end

-- Stations must not crowd each other.
function MobilityRules.farEnough(cx: number, d: number, cz: number, owned: { Station }): boolean
	for _, s in owned do
		local dx, dd, dz = s.cx - cx, s.d - d, s.cz - cz
		if dx * dx + dd * dd + dz * dz < Mobility.MinStationSpacing * Mobility.MinStationSpacing then
			return false
		end
	end
	return true
end

return MobilityRules
