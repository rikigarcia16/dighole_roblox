--!strict
-- Pure, deterministic world generation: which resource occupies a given plot cell.
-- No Roblox services are touched here, so the module is unit-testable outside Studio.
--
-- Ores are placed in veins: the dig area is divided into 3x3x3 blocks. Each block rolls once to
-- decide whether it is a vein and which ore it holds, then each cell rolls against the zone's
-- vein density. This produces readable clusters instead of salt-and-pepper noise.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hash = require(Shared.Util.Hash)
local Zones = require(Shared.Config.Zones)
local Resources = require(Shared.Config.Resources)

local OreGeneration = {}

local VEIN_BLOCK = 3
local SALT_VEIN = 11
local SALT_ORE_PICK = 23
local SALT_CELL = 37
local SALT_BASE = 53

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

-- Returns the resource id stored in cell (cx, d, cz) of a plot generated with `seed`.
function OreGeneration.resourceAt(seed: number, cx: number, d: number, cz: number): string
	if d <= 0 then
		return "grass"
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

return OreGeneration
