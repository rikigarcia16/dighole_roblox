--!strict
-- Mobility v1: ropes, lift stations and the rescue beacon. All balance lives here.
--
-- Design rules (see docs/DESIGN_MOBILITY_AND_MINES.md):
--   * the first descent is an expedition; returning to a conquered depth is quick (stations)
--   * mobility opens routes, it never skips digging (ropes only hang through open space)
--   * nobody gets stuck: ropes always reach a floor and can be picked up; the beacon always works

local Mobility = {}

Mobility.Rope = {
	price = 25,
	maxCarried = 5,
	maxPlaced = 12, -- per plot, saved
	maxLength = 80, -- studs (20 m)
	minDrop = 8, -- studs: no ropes for a single step
	reachForward = 4, -- studs in front of the player where the rope hangs
}

-- Free return to the surface (the old "Superficie" button) above this depth.
Mobility.FreeReturnDepth = 50

-- Lift stations: one per zone, installed where the player stands once they reach that zone.
-- `cost` in coins; the Counter grants its own station for free ("counter").
export type StationDef = { id: string, name: string, minDepth: number, maxDepth: number, cost: number }
Mobility.Stations = {
	{ id = "mines", name = "Estación de las Minas", minDepth = 50, maxDepth = 150, cost = 250 },
	{ id = "counter", name = "Estación del Contador", minDepth = 128, maxDepth = 160, cost = 0 },
	{ id = "crystal", name = "Estación de Cristal", minDepth = 150, maxDepth = 350, cost = 1500 },
	{ id = "ancient", name = "Estación de las Cavernas", minDepth = 350, maxDepth = 650, cost = 6000 },
	{ id = "volcanic", name = "Estación Volcánica", minDepth = 650, maxDepth = 1000, cost = 20000 },
	{ id = "abyss", name = "Estación del Abismo", minDepth = 1000, maxDepth = 1500, cost = 60000 },
	{ id = "core", name = "Estación del Núcleo", minDepth = 1500, maxDepth = 99999, cost = 150000 },
} :: { StationDef }
Mobility.StationById = {} :: { [string]: StationDef }
for _, def in Mobility.Stations do
	Mobility.StationById[def.id] = def
end
Mobility.MinStationSpacing = 6 -- cells between two stations
Mobility.StationUseDistance = 12 -- studs from a station / the surface winch to call the lift
Mobility.LiftRideSeconds = 2.5

-- Rescue beacon --------------------------------------------------------------------------------
-- cost = clamp(depthRate * depth + valueRate * backpackValue, min, maxBase + maxPerMeter * depth)
-- Never takes items: if the player cannot afford it they pay what they have and the rest is waived.
Mobility.Rescue = {
	channelSeconds = 4,
	cancelDistance = 4, -- studs moved during the channel cancels it
	depthRate = 0.5,
	valueRate = 0.04,
	min = 10,
	maxBase = 50,
	maxPerMeter = 1.5,
}

return Mobility
