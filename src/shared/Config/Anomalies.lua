--!strict
-- Fixed anomalous structures (shared: the server generates and validates them, the client uses the
-- same geometry for feedback such as "this wall cannot be scratched").
--
-- Each room is a reserved box inside one cave sector: a sealed interior, a one-cell shell that no
-- tool can dig except for two doorways (west and east, at floor level, where two guided galleries
-- end), and a solid foundation under it. Positions are relative to the dig-area centre so they stay
-- in place if the underground is ever widened.
--
--   counter   The Counter, at the bottom of the Forgotten Mines (136-141 m).
--   workshop  E.'s workshop, in the Ancient Caverns (456-460 m).
--   core      "El fondo", in the Unknown Core just above the bedrock (2154-2158 m).

local GameConfig = require(script.Parent.GameConfig)

local Anomalies = {}

local N = GameConfig.PlotDigCells
local C = N // 2 -- centre column (8 with a 16-cell dig area)

export type Box = { x0: number, x1: number, d0: number, d1: number, z0: number, z1: number }
export type Door = { x: number, z0: number, z1: number, d0: number, d1: number }
export type Room = {
	id: string,
	sector: number, -- cave sector (32 m) that holds it
	box: Box, -- interior (air), inclusive cell box
	doorways: { Door },
	name: string,
}

local function doorwaysFor(box: Box): { Door }
	return {
		{ x = box.x0 - 1, z0 = C - 1, z1 = C, d0 = box.d1 - 1, d1 = box.d1 },
		{ x = box.x1 + 1, z0 = C - 1, z1 = C, d0 = box.d1 - 1, d1 = box.d1 },
	}
end

local function room(id: string, name: string, sector: number, box: Box): Room
	return { id = id, name = name, sector = sector, box = box, doorways = doorwaysFor(box) }
end

Anomalies.Rooms = {
	counter = room("counter", "El Contador", 4, { -- 128..159 m
		x0 = C - 4,
		x1 = C + 3,
		z0 = C - 4,
		z1 = C + 3,
		d0 = 136,
		d1 = 141,
	}),
	workshop = room("workshop", "El taller de E.", 14, { -- 448..479 m
		x0 = C - 3,
		x1 = C + 2,
		z0 = C - 3,
		z1 = C + 2,
		d0 = 456,
		d1 = 460,
	}),
	core = room("core", "El fondo", 67, { -- 2144..2175 m, above the bedrock at 2200 m
		x0 = C - 3,
		x1 = C + 2,
		z0 = C - 3,
		z1 = C + 2,
		d0 = 2154,
		d1 = 2158,
	}),
} :: { [string]: Room }

-- Smooth terrain bulges about half a cell into a room from every wall, the floor and the ceiling
-- (measured in Studio: 2 studs). Room builders put their parts on the visible surfaces, this far
-- inside the cell box; before that the Counter's glass floor and lining were buried in rock.
Anomalies.TerrainBulge = 2

Anomalies.RoomList = { Anomalies.Rooms.counter, Anomalies.Rooms.workshop, Anomalies.Rooms.core } :: { Room }

-- The Counter keeps its original names (used across the code and the tests).
Anomalies.CounterRoom = Anomalies.Rooms.counter.box
Anomalies.CounterSector = Anomalies.Rooms.counter.sector
Anomalies.CounterDoorways = Anomalies.Rooms.counter.doorways

function Anomalies.roomForSector(index: number): Room?
	for _, r in Anomalies.RoomList do
		if r.sector == index then
			return r
		end
	end
	return nil
end

local function inBox(box: Box, cx: number, d: number, cz: number, grow: number): boolean
	return cx >= box.x0 - grow
		and cx <= box.x1 + grow
		and cz >= box.z0 - grow
		and cz <= box.z1 + grow
		and d >= box.d0 - grow
		and d <= box.d1 + grow
end

-- The room whose reserved box (interior plus shell) contains the cell, if any.
function Anomalies.roomAt(cx: number, d: number, cz: number): Room?
	for _, r in Anomalies.RoomList do
		if inBox(r.box, cx, d, cz, 1) then
			return r
		end
	end
	return nil
end

function Anomalies.inRoom(cx: number, d: number, cz: number): boolean
	for _, r in Anomalies.RoomList do
		if inBox(r.box, cx, d, cz, 0) then
			return true
		end
	end
	return false
end

-- Room plus its one-cell shell (everything the cave generator must leave alone).
function Anomalies.inReserved(cx: number, d: number, cz: number): boolean
	return Anomalies.roomAt(cx, d, cz) ~= nil
end

-- Solid rock under each room (and one cell wider): the room stands on its own foundation. Without it
-- a natural chamber could open right below the floor and players fell under the room on their way
-- to a doorway (Studio test 1). The cave generator never carves here.
function Anomalies.inFoundation(cx: number, d: number, cz: number): boolean
	for _, r in Anomalies.RoomList do
		local box = r.box
		if
			cx >= box.x0 - 2
			and cx <= box.x1 + 2
			and cz >= box.z0 - 2
			and cz <= box.z1 + 2
			and d >= box.d1 + 2
			and d <= box.d1 + 8
		then
			return true
		end
	end
	return false
end

function Anomalies.isDoorway(cx: number, d: number, cz: number): boolean
	for _, r in Anomalies.RoomList do
		for _, door in r.doorways do
			if cx == door.x and cz >= door.z0 and cz <= door.z1 and d >= door.d0 and d <= door.d1 then
				return true
			end
		end
	end
	return false
end

-- Shell cells that no tool can dig.
function Anomalies.isSealed(cx: number, d: number, cz: number): boolean
	return Anomalies.inReserved(cx, d, cz) and not Anomalies.inRoom(cx, d, cz) and not Anomalies.isDoorway(cx, d, cz)
end

-- Counter puzzle -----------------------------------------------------------------------------------
-- Three rings, six glyphs each. The tablet in the room shows which glyph each ring must face.
Anomalies.Glyphs = { "◇", "ᚦ", "◈", "ᛟ", "◬", "ᚨ" }
Anomalies.Rings = 3

-- Workshop -----------------------------------------------------------------------------------------
-- E.'s count in the ledger, and the battery bonus the workbench gives once you hang your shovel.
Anomalies.WorkshopEBlocks = 3912
Anomalies.WorkshopBatteryBonus = 0.5 -- +50 % battery capacity

-- The bottom ---------------------------------------------------------------------------------------
-- The wall of "El fondo": three columns of engraved counts. The first holds diggers older than E.
-- (names worn away), the second E., the third is empty until the player lays a hand on it; then
-- the ancestral tool is theirs, and with it the bedrock gives way (CoreService): the crack opens
-- onto white light and the player comes out on the lawn of their own plot.
Anomalies.CoreOlderCounts = { 18402, 11930, 9771, 6215 }
Anomalies.CoreToolId = "ancestral_tool"
Anomalies.BedrockHits = 6 -- swings of the ancestral tool before the bedrock gives way

return Anomalies
