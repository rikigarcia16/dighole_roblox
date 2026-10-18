--!strict
-- Special equipment. Ordinary digging NEVER uses the battery: only these do (the hook is
-- mechanical and uses none). Bought once in the garage (Equipo tab), kept forever.
--
--   lamp      powerful lamp: lights a big cave around you while on; drains the battery
--   detector  resonance detector: a pulse tells the direction, rough distance and kind of the
--             nearest hidden thing (geode, chest, fossil, the Counter); costs battery per pulse
--   hook      grappling hook: pulls you to a rock surface in reach; to cross pits and reach
--             high galleries (never through rock: the server checks the line)

export type GearDef = {
	id: string,
	name: string,
	description: string,
	price: number,
	order: number,
	key: string, -- keyboard hint shown in the UI
}

local Gear = {}

Gear.List = {
	{
		id = "lamp",
		name = "Linterna potente",
		description = "Ilumina una cámara entera mientras está encendida. Gasta batería.",
		price = 400,
		order = 1,
		key = "L",
	},
	{
		id = "detector",
		name = "Detector de resonancia",
		description = "Cada pulso señala la dirección del hallazgo oculto más cercano. Gasta batería.",
		price = 1500,
		order = 2,
		key = "G",
	},
	{
		id = "hook",
		name = "Gancho",
		description = "Te lanza hacia una pared o un techo de roca cercano. Mecánico: no gasta batería.",
		price = 2500,
		order = 3,
		key = "T",
	},
} :: { GearDef }

Gear.ById = {} :: { [string]: GearDef }
for _, def in Gear.List do
	Gear.ById[def.id] = def
end

Gear.Lamp = { drainPerSecond = 0.6, range = 60, brightness = 2.2 }
Gear.Detector = { pulseCost = 12, cooldown = 2.5, range = 120 } -- studs (30 m)
Gear.Hook = { range = 40, cooldown = 1.6, speed = 70, maxSeconds = 1 } -- studs, s, studs/s

-- Where the battery recharges besides the surface: within this many studs of an owned station.
Gear.StationRechargeDistance = 14

return Gear
