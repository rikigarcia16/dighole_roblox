--!strict
-- Special equipment. Ordinary digging NEVER uses the battery: only these do (the hook is
-- mechanical and uses none). Bought once in the garage (Equipo tab), kept forever.
--
--   lamp      powerful lamp: lights a big cave around you while on; drains the battery
--   detector  resonance detector: a pulse tells the direction, rough distance and kind of the
--             nearest hidden thing (geode, chest, fossil, the Counter); costs battery per pulse
--   hook      grappling hook: pulls you to a rock surface in reach; to cross pits and reach
--             high galleries (never through rock: the server checks the line)
--   motor_hook upgrade of the hook (same key, no extra button): twice the reach and a stronger
--             pull, paid with battery on each throw; with an empty battery it works as the hook

export type GearDef = {
	id: string,
	name: string,
	description: string,
	price: number,
	order: number,
	key: string, -- keyboard hint shown in the UI
	upgradeOf: string?, -- an upgrade of another piece: needs it first and has no button of its own
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
	{
		id = "motor_hook",
		name = "Gancho motorizado",
		description = "Mejora del gancho: el doble de alcance y un tirón más fuerte. Cada lanzamiento gasta batería.",
		price = 12000,
		order = 4,
		key = "T",
		upgradeOf = "hook",
	},
} :: { GearDef }

Gear.ById = {} :: { [string]: GearDef }
for _, def in Gear.List do
	Gear.ById[def.id] = def
end

Gear.Lamp = { drainPerSecond = 0.6, range = 60, brightness = 2.2 }
Gear.Detector = { pulseCost = 12, cooldown = 2.5, range = 120 } -- studs (30 m)
Gear.Hook = { range = 40, cooldown = 1.6, speed = 70, maxSeconds = 1, hangSeconds = 1.5 } -- studs, s, studs/s, s
Gear.MotorHook = { range = 80, speed = 100, batteryCost = 6 } -- studs, studs/s, battery per throw

-- Pieces that draw on the battery (the plain hook does not). Until the player owns one, a bigger
-- battery is useless, so the shop does not sell it yet (a new player could spend their first coins on
-- it: Studio playtest).
Gear.UsesBattery = { lamp = true, detector = true, motor_hook = true } :: { [string]: boolean }

function Gear.needsBattery(owned: { [string]: boolean }?): boolean
	for id in Gear.UsesBattery do
		if owned and owned[id] == true then
			return true
		end
	end
	return false
end

-- Where the battery recharges besides the surface: within this many studs of an owned station.
Gear.StationRechargeDistance = 14

return Gear
