--!strict
-- Pure, deterministic world generation: which resource occupies a given plot cell.
-- No Roblox services are touched here, so the module is unit-testable outside Studio.
--
-- Ores are placed in veins: the dig area is divided into 3x3x3 blocks. Each block rolls once to
-- decide whether it is a vein and which ore it holds, then each cell rolls against the zone's
-- vein density. This produces readable clusters instead of salt-and-pepper noise.
--
-- The same function also places natural empty space ("air"):
--   * caves  : ellipsoid pockets, one at most per 8x8x8 cell block, from the Forgotten Mines down.
--              Each cave fits entirely inside its block, so the protected border ring is never
--              opened and a cell only has to look at its own block.
--   * landmarks: hand-placed story objects (one cell each) at fixed depths.
-- and hidden finds (treasures inside base rock, see Resources `find`).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hash = require(Shared.Util.Hash)
local Zones = require(Shared.Config.Zones)
local Resources = require(Shared.Config.Resources)
local GameConfig = require(Shared.Config.GameConfig)

local OreGeneration = {}

local VEIN_BLOCK = 3
local SALT_VEIN = 11
local SALT_ORE_PICK = 23
local SALT_CELL = 37
local SALT_BASE = 53
local SALT_CAVE = 71
local SALT_CAVE_SHAPE = 83
local SALT_FIND = 97
local SALT_LANDMARK = 113

local CAVE_BLOCK = 8
local CAVE_MIN_DEPTH = 56
local N = GameConfig.PlotDigCells

export type Cave = {
	key: string,
	bx: number,
	by: number,
	bz: number,
	cx: number, -- centre in cell coordinates (fractional)
	cd: number,
	cz: number,
	rx: number,
	rd: number,
	rz: number,
	zoneId: string,
	chest: { cx: number, d: number, cz: number }?,
}

export type Landmark = { id: string, cx: number, d: number, cz: number }

local function pickWeighted(entries: { { id: string, weight: number } }, roll: number): string?
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	if total <= 0 then
		return nil
	end
	local target = roll * total
	for _, entry in entries do
		target -= entry.weight
		if target < 0 then
			return entry.id
		end
	end
	return entries[#entries].id
end

-- Ore candidates valid at `depth` (cached per depth because it is queried for every cell).
local oreCache: { [number]: { { id: string, weight: number } } } = {}
local function oresAt(depth: number): { { id: string, weight: number } }
	local cached = oreCache[depth]
	if cached then
		return cached
	end
	local list = {}
	for _, ore in Resources.Ores do
		local spawn = ore.spawn
		if spawn and depth >= spawn.minDepth and depth < spawn.maxDepth then
			table.insert(list, { id = ore.id, weight = spawn.chance })
		end
	end
	oreCache[depth] = list
	return list
end

local baseCache: { [number]: { { id: string, weight: number } } } = {}
local function baseAt(depth: number): { { id: string, weight: number } }
	local cached = baseCache[depth]
	if cached then
		return cached
	end
	local zone = Zones.at(depth)
	local list = {}
	for _, rule in zone.base do
		local weight = rule.weight
		if rule.fadeInMeters and rule.fadeInMeters > 0 then
			weight *= math.clamp((depth - zone.minDepth) / rule.fadeInMeters, 0, 1)
		end
		if weight > 0 then
			table.insert(list, { id = rule.id, weight = weight })
		end
	end
	baseCache[depth] = list
	return list
end

-- Caves ---------------------------------------------------------------------------------------

-- Chance that an 8x8x8 block holds a cave, per zone.
local CAVE_CHANCE: { [string]: number } = {
	forgotten_mines = 0.32,
	crystal_caves = 0.45,
	ancient_caverns = 0.4,
	volcanic_depths = 0.35,
	abyss = 0.4,
	unknown_core = 0.45,
}
-- Chance that a cave hides a chest on its floor.
local CHEST_CHANCE = 0.45

local caveCache: { [string]: Cave | false } = {}
local caveCacheSize = 0

local function insideCave(cave: Cave, cx: number, d: number, cz: number): boolean
	local x = (cx + 0.5 - cave.cx) / cave.rx
	local y = (d + 0.5 - cave.cd) / cave.rd
	local z = (cz + 0.5 - cave.cz) / cave.rz
	return x * x + y * y + z * z <= 1
end

-- Returns the cave of block (bx, by, bz) or nil.
function OreGeneration.caveInBlock(seed: number, bx: number, by: number, bz: number): Cave?
	local blocksPerSide = N // CAVE_BLOCK
	if bx < 0 or bz < 0 or bx >= blocksPerSide or bz >= blocksPerSide then
		return nil
	end
	local key = seed .. ":" .. bx .. ":" .. by .. ":" .. bz
	local cached = caveCache[key]
	if cached ~= nil then
		return if cached then cached else nil
	end

	local result: Cave? = nil
	local top = by * CAVE_BLOCK
	if top >= CAVE_MIN_DEPTH then
		local zone = Zones.at(top + CAVE_BLOCK / 2)
		local chance = CAVE_CHANCE[zone.id] or 0
		if Hash.unit(seed, bx, by, bz, SALT_CAVE) < chance then
			local function roll(i: number): number
				return Hash.unit(seed, bx, by, bz, SALT_CAVE_SHAPE + i)
			end
			-- Bigger, taller caves in the crystal caves and deeper.
			local big = zone.index >= 3
			local cave: Cave = {
				key = bx .. "_" .. by .. "_" .. bz,
				bx = bx,
				by = by,
				bz = bz,
				cx = bx * CAVE_BLOCK + 3.6 + roll(1) * 0.8,
				cd = top + 3.6 + roll(2) * 0.8,
				cz = bz * CAVE_BLOCK + 3.6 + roll(3) * 0.8,
				rx = 2.2 + roll(4) * (if big then 1.2 else 0.8),
				rd = 1.6 + roll(5) * (if big then 1.4 else 0.6),
				rz = 2.2 + roll(6) * (if big then 1.2 else 0.8),
				zoneId = zone.id,
				chest = nil,
			}
			if roll(7) < CHEST_CHANCE then
				-- deepest air cell under the cave centre = the cave floor
				local ccx, ccz = math.floor(cave.cx), math.floor(cave.cz)
				for d = top + CAVE_BLOCK - 1, top, -1 do
					if insideCave(cave, ccx, d, ccz) then
						cave.chest = { cx = ccx, d = d, cz = ccz }
						break
					end
				end
			end
			result = cave
		end
	end

	if caveCacheSize > 20000 then
		table.clear(caveCache)
		caveCacheSize = 0
	end
	caveCache[key] = result or false
	caveCacheSize += 1
	return result
end

-- Cave containing a cell, if any.
function OreGeneration.caveAt(seed: number, cx: number, d: number, cz: number): Cave?
	if d < CAVE_MIN_DEPTH or cx < 0 or cz < 0 or cx >= N or cz >= N then
		return nil
	end
	local cave = OreGeneration.caveInBlock(seed, cx // CAVE_BLOCK, d // CAVE_BLOCK, cz // CAVE_BLOCK)
	if cave and insideCave(cave, cx, d, cz) then
		return cave
	end
	return nil
end

-- All caves whose block overlaps the depth range [d0, d1].
function OreGeneration.cavesInRange(seed: number, d0: number, d1: number): { Cave }
	local list = {}
	local blocksPerSide = N // CAVE_BLOCK
	for by = d0 // CAVE_BLOCK, d1 // CAVE_BLOCK do
		for bx = 0, blocksPerSide - 1 do
			for bz = 0, blocksPerSide - 1 do
				local cave = OreGeneration.caveInBlock(seed, bx, by, bz)
				if cave then
					table.insert(list, cave)
				end
			end
		end
	end
	return list
end

-- Landmarks -------------------------------------------------------------------------------------

local LANDMARK_DEFS = {
	{ id = "miner_box", depth = 44 },
	{ id = "stone_tablet", depth = 138 },
}

local landmarkDepths: { [number]: boolean } = {}
for _, def in LANDMARK_DEFS do
	landmarkDepths[def.depth] = true
end

local landmarkCache: { [number]: { Landmark } } = {}

-- Story objects of a plot. Horizontal position varies per plot but stays near the middle so the
-- usual shaft passes close to it.
function OreGeneration.landmarks(seed: number): { Landmark }
	local cached = landmarkCache[seed]
	if cached then
		return cached
	end
	local list = {}
	for i, def in LANDMARK_DEFS do
		table.insert(list, {
			id = def.id,
			cx = 4 + Hash.int(seed, i, 0, 0, SALT_LANDMARK) % (N - 8),
			d = def.depth,
			cz = 4 + Hash.int(seed, 0, i, 0, SALT_LANDMARK) % (N - 8),
		})
	end
	landmarkCache[seed] = list
	return list
end

local function landmarkAt(seed: number, cx: number, d: number, cz: number): Landmark?
	for _, landmark in OreGeneration.landmarks(seed) do
		if landmark.d == d and landmark.cx == cx and landmark.cz == cz then
			return landmark
		end
	end
	return nil
end
OreGeneration.landmarkAt = landmarkAt

-- Cells -----------------------------------------------------------------------------------------

-- Returns the resource id stored in cell (cx, d, cz) of a plot generated with `seed`,
-- or "air" for natural empty space (caves, landmark pockets).
function OreGeneration.resourceAt(seed: number, cx: number, d: number, cz: number): string
	if d <= 0 then
		return "grass"
	end
	if d >= CAVE_MIN_DEPTH and OreGeneration.caveAt(seed, cx, d, cz) then
		return "air"
	end
	if landmarkDepths[d] and landmarkAt(seed, cx, d, cz) then
		return "air"
	end

	local zone = Zones.at(d)
	local bx, by, bz = cx // VEIN_BLOCK, d // VEIN_BLOCK, cz // VEIN_BLOCK
	if Hash.unit(seed, bx, by, bz, SALT_VEIN) < zone.veinChance then
		local ores = oresAt(d)
		if #ores > 0 and Hash.unit(seed, cx, d, cz, SALT_CELL) < zone.veinDensity then
			local oreId = pickWeighted(ores, Hash.unit(seed, bx, by, bz, SALT_ORE_PICK))
			if oreId then
				return oreId
			end
		end
	end

	return pickWeighted(baseAt(d), Hash.unit(seed, cx, d, cz, SALT_BASE)) or "stone"
end

-- Hidden find inside a base-rock cell, if any. Deterministic, so a cell can only ever give it once.
function OreGeneration.findAt(seed: number, cx: number, d: number, cz: number): string?
	local roll = Hash.unit(seed, cx, d, cz, SALT_FIND)
	local cumulative = 0
	for _, resource in Resources.Finds do
		local rule = resource.find
		if rule and d >= rule.minDepth and d < rule.maxDepth then
			cumulative += rule.chance
			if roll < cumulative then
				return resource.id
			end
		end
	end
	return nil
end

return OreGeneration
