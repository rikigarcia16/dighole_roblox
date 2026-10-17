--!strict
-- Pure, deterministic world generation: which resource occupies a given plot cell.
-- No Roblox services are touched here, so the module is unit-testable outside Studio.
--
-- Ores are placed in veins: the dig area is divided into 3x3x3 blocks. Each block rolls once to
-- decide whether it is a vein and which ore it holds, then each cell rolls against the zone's
-- vein density. This produces readable clusters instead of salt-and-pepper noise.
--
-- The same function also places natural empty space:
--   * caves    : tunnels, chambers, chimneys, pools and geode pockets (see Logic/Caves)
--   * landmarks: hand-placed story objects (one cell each) at fixed depths.
-- and hidden finds (treasures inside base rock, see Resources `find`).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hash = require(Shared.Util.Hash)
local Zones = require(Shared.Config.Zones)
local Resources = require(Shared.Config.Resources)
local GameConfig = require(Shared.Config.GameConfig)
local Caves = require(script.Parent.Caves)

local OreGeneration = {}

local VEIN_BLOCK = 3
local SALT_VEIN = 11
local SALT_ORE_PICK = 23
local SALT_CELL = 37
local SALT_BASE = 53
local SALT_FIND = 97
local SALT_LANDMARK = 113
local N = GameConfig.PlotDigCells

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
-- "air" for natural empty space (caves, geode and landmark pockets) or "water" for cave pools.
function OreGeneration.resourceAt(seed: number, cx: number, d: number, cz: number): string
	if d <= 0 then
		return "grass"
	end
	if d >= Caves.FirstDepth then
		local system, water = Caves.cellAt(seed, cx, d, cz)
		if system > 0 then
			return if water then "water" else "air"
		end
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
