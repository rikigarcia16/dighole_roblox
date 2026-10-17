--!strict
-- Deterministic placement of fossils in the rock (pure; tested offline).
--
-- The column below the garden is split into bands of BAND metres. Each band may hold one fossil:
-- a sealed pocket two cells long, lying along X or Z, fully wrapped in rock (never touching a cave,
-- a geode or a story landmark), so it is found by digging next to it.
--
-- Each player only ever digs their own plot, so a species that is merely "rare" could be
-- impossible to collect for most players. Species are therefore picked with a novelty bias: a
-- species that has not appeared yet in this plot (in bands above) weighs NOVELTY times more. Bands
-- are resolved top-down and cached per seed, so the result stays deterministic.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hash = require(Shared.Util.Hash)
local Fossils = require(Shared.Config.Fossils)
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)
local Caves = require(script.Parent.Caves)

local FossilBeds = {}

local N = GameConfig.PlotDigCells
local BAND = 12
local SALT = 503
local NOVELTY = 6
FossilBeds.Band = BAND

-- Chance that a band holds a fossil, by zone.
local CHANCE: { [string]: number } = {
	garden = 0.5,
	forgotten_mines = 0.6,
	crystal_caves = 0.5,
	ancient_caverns = 0.35,
}

export type Bed = {
	id: string, -- stable id ("f<band>"), used to remember extraction
	speciesId: string,
	cx: number,
	d: number,
	cz: number,
	alongX: boolean, -- second cell is (cx+1, d, cz) if true, else (cx, d, cz+1)
}

-- Landmark cells are passed in to avoid a dependency cycle with OreGeneration.
local landmarkCheck: ((number, number, number, number) -> boolean)? = nil
function FossilBeds.setLandmarkCheck(check: (number, number, number, number) -> boolean)
	landmarkCheck = check
end

type SeedState = { beds: { [number]: Bed | false }, seen: { [string]: number }, resolved: number }
local seeds: { [number]: SeedState } = {}
local seedCount = 0

local function pickSpecies(seed: number, band: number, depth: number, seen: { [string]: number }): string?
	local total = 0
	local weights = {}
	for _, species in Fossils.List do
		if depth >= species.minDepth and depth < species.maxDepth then
			local w = species.weight * (if seen[species.id] then 1 else NOVELTY)
			weights[species.id] = w
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = Hash.unit(seed, band, 7, 0, SALT) * total
	for _, species in Fossils.List do
		local w = weights[species.id]
		if w then
			roll -= w
			if roll < 0 then
				return species.id
			end
		end
	end
	return nil
end

local function solidAround(seed: number, cells: { { number } }): boolean
	for _, c in cells do
		for dx = -1, 1 do
			for dd = -1, 1 do
				for dz = -1, 1 do
					local x, d, z = c[1] + dx, c[2] + dd, c[3] + dz
					if Caves.cellAt(seed, x, d, z) > 0 then
						return false
					end
					if landmarkCheck and (landmarkCheck :: any)(seed, x, d, z) then
						return false
					end
				end
			end
		end
	end
	return true
end

local function resolveBand(seed: number, band: number, seen: { [string]: number }): Bed?
	local top = band * BAND
	if top < Fossils.MinDepth - BAND or top >= Fossils.MaxDepth then
		return nil
	end
	local depth = math.max(Fossils.MinDepth, top + 2 + math.floor(Hash.unit(seed, band, 1, 0, SALT) * (BAND - 4)))
	local zone = Zones.at(depth)
	if Hash.unit(seed, band, 0, 0, SALT) >= (CHANCE[zone.id] or 0) then
		return nil
	end
	local alongX = Hash.unit(seed, band, 2, 0, SALT) < 0.5
	local cx = 2 + math.floor(Hash.unit(seed, band, 3, 0, SALT) * (N - 5))
	local cz = 2 + math.floor(Hash.unit(seed, band, 4, 0, SALT) * (N - 5))
	local cells = { { cx, depth, cz }, if alongX then { cx + 1, depth, cz } else { cx, depth, cz + 1 } }
	if not solidAround(seed, cells) then
		return nil
	end
	local speciesId = pickSpecies(seed, band, depth, seen)
	if not speciesId then
		return nil
	end
	seen[speciesId] = (seen[speciesId] or 0) + 1
	return { id = "f" .. band, speciesId = speciesId, cx = cx, d = depth, cz = cz, alongX = alongX }
end

-- The fossil bed of band `band`, or nil. Bands are resolved in order from the top (novelty bias).
function FossilBeds.bed(seed: number, band: number): Bed?
	if band < 0 then
		return nil
	end
	local state = seeds[seed]
	if not state then
		if seedCount >= 32 then
			table.clear(seeds)
			seedCount = 0
		end
		state = { beds = {}, seen = {}, resolved = -1 }
		seeds[seed] = state
		seedCount += 1
	end
	local st = state :: SeedState
	while st.resolved < band do
		st.resolved += 1
		st.beds[st.resolved] = resolveBand(seed, st.resolved, st.seen) or false
	end
	local bed = st.beds[band]
	return if bed then bed else nil
end

-- Is (cx, d, cz) one of the two pocket cells of a fossil? Returns the bed if so.
function FossilBeds.bedAt(seed: number, cx: number, d: number, cz: number): Bed?
	if d < Fossils.MinDepth or d >= Fossils.MaxDepth then
		return nil
	end
	local bed = FossilBeds.bed(seed, d // BAND)
	if not bed or bed.d ~= d then
		return nil
	end
	if
		(cx == bed.cx and cz == bed.cz)
		or (bed.alongX and cx == bed.cx + 1 and cz == bed.cz)
		or (not bed.alongX and cx == bed.cx and cz == bed.cz + 1)
	then
		return bed
	end
	return nil
end

function FossilBeds.bedsInRange(seed: number, d0: number, d1: number): { Bed }
	local list = {}
	for band = math.max(0, d0 // BAND), d1 // BAND do
		local bed = FossilBeds.bed(seed, band)
		if bed and bed.d >= d0 and bed.d <= d1 then
			table.insert(list, bed)
		end
	end
	return list
end

return FossilBeds
