--!strict
-- Fixed anomalous structures (shared: the server generates and validates them, the client uses the
-- same geometry for feedback such as "this wall cannot be scratched").
--
-- The Counter room sits at the bottom of the Forgotten Mines, centred under the hole so it stays in
-- place if the underground is ever widened (positions are relative to the dig-area centre).

local GameConfig = require(script.Parent.GameConfig)

local Anomalies = {}

local N = GameConfig.PlotDigCells
local C = N // 2 -- centre column (8 with a 16-cell dig area)

export type Box = { x0: number, x1: number, d0: number, d1: number, z0: number, z1: number }

-- Interior (air), inclusive cell box.
Anomalies.CounterRoom = {
	x0 = C - 4,
	x1 = C + 3,
	z0 = C - 4,
	z1 = C + 3,
	d0 = 136,
	d1 = 141,
} :: Box
Anomalies.CounterSector = 4 -- 128..159 m

-- The only two ways in: openings in the west and east walls at floor level, where the guided
-- galleries end. They are ordinary rock (the player digs the last cell); the rest of the shell
-- cannot be dug.
local room = Anomalies.CounterRoom
Anomalies.CounterDoorways = {
	{ x = room.x0 - 1, z0 = C - 1, z1 = C, d0 = room.d1 - 1, d1 = room.d1 },
	{ x = room.x1 + 1, z0 = C - 1, z1 = C, d0 = room.d1 - 1, d1 = room.d1 },
}

function Anomalies.inRoom(cx: number, d: number, cz: number): boolean
	return cx >= room.x0 and cx <= room.x1 and cz >= room.z0 and cz <= room.z1 and d >= room.d0 and d <= room.d1
end

-- Room plus its one-cell shell (everything the cave generator must leave alone).
function Anomalies.inReserved(cx: number, d: number, cz: number): boolean
	return cx >= room.x0 - 1
		and cx <= room.x1 + 1
		and cz >= room.z0 - 1
		and cz <= room.z1 + 1
		and d >= room.d0 - 1
		and d <= room.d1 + 1
end

-- Solid rock under the room (and one cell wider): the room stands on its own foundation. Without it
-- a natural chamber could open right below the floor and players fell under the room on their way
-- to a doorway (Studio test 1). The cave generator never carves here.
function Anomalies.inFoundation(cx: number, d: number, cz: number): boolean
	return cx >= room.x0 - 2
		and cx <= room.x1 + 2
		and cz >= room.z0 - 2
		and cz <= room.z1 + 2
		and d >= room.d1 + 2
		and d <= room.d1 + 8
end

function Anomalies.isDoorway(cx: number, d: number, cz: number): boolean
	for _, door in Anomalies.CounterDoorways do
		if cx == door.x and cz >= door.z0 and cz <= door.z1 and d >= door.d0 and d <= door.d1 then
			return true
		end
	end
	return false
end

-- Shell cells that no tool can dig.
function Anomalies.isSealed(cx: number, d: number, cz: number): boolean
	return Anomalies.inReserved(cx, d, cz) and not Anomalies.inRoom(cx, d, cz) and not Anomalies.isDoorway(cx, d, cz)
end

-- Puzzle ---------------------------------------------------------------------------------------
-- Three rings, six glyphs each. The tablet in the room shows which glyph each ring must face.
Anomalies.Glyphs = { "◇", "ᚦ", "◈", "ᛟ", "◬", "ᚨ" }
Anomalies.Rings = 3

return Anomalies
