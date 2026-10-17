--!strict
-- Independent upgrade tracks. Each level lists the value granted and the price to reach it.
-- Level 1 is the starting level (price 0).

export type Level = { value: number, price: number }
export type Track = {
	id: string,
	hidden: boolean?, -- not sold yet (kept in saves); see the battery note below
	name: string,
	description: string,
	unit: string,
	levels: { Level },
	order: number,
}

local list: { Track } = {
	{
		id = "backpack",
		name = "Mochila",
		unit = "u",
		description = "Unidades de mineral que puedes llevar.",
		levels = {
			{ value = 20, price = 0 },
			{ value = 40, price = 75 },
			{ value = 80, price = 350 },
			{ value = 150, price = 2500 },
			{ value = 300, price = 15000 },
			{ value = 600, price = 90000 },
			{ value = 1200, price = 500000 },
		},
	},
	{
		id = "battery",
		name = "Batería",
		unit = "⚡",
		description = "Alimenta detectores, linternas potentes y herramientas especiales.",
		-- Hidden until special equipment consumes energy: ordinary digging no longer uses it.
		hidden = true,
		levels = {
			{ value = 60, price = 0 },
			{ value = 120, price = 120 },
			{ value = 250, price = 600 },
			{ value = 500, price = 4000 },
			{ value = 1000, price = 25000 },
			{ value = 2000, price = 150000 },
		},
	},
} :: any

local Upgrades = {}
Upgrades.List = list
Upgrades.ById = {} :: { [string]: Track }

-- Fraction of max energy recharged per second while at the surface.
Upgrades.SurfaceRechargePerSecond = 0.5

for index, track in list do
	track.order = index
	Upgrades.ById[track.id] = track
end

function Upgrades.valueAt(trackId: string, level: number): number
	local track = Upgrades.ById[trackId]
	assert(track, "Unknown upgrade " .. trackId)
	local clamped = math.clamp(level, 1, #track.levels)
	return track.levels[clamped].value
end

return Upgrades
