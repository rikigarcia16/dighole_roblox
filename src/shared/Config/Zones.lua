--!strict
-- Geological regions. Depths are in metres (1 cell = 1 m).
--
-- base       : weighted base rock mix. `fromDepth`/`toDepth` (optional, relative to the zone start)
--              let a material fade in/out inside a zone so transitions do not look like flat bands.
-- veinChance : probability (0..1) that a 3x3x3 vein block contains ore at all.
-- veinDensity: probability (0..1) that a cell inside an ore vein block is ore.
-- caves      : cave system recipe for each 32 m "sector" of this zone (see Logic/Caves), or nil.
--   style          : decoration set ("mine", "crystal", "ruin", "lava", "abyss", "core")
--   tunnels        : galleries per sector; tunnelRadius in cells; branchChance per tunnel
--   chamberChance  : chance of a large chamber; chamberRadius / chamberHeight = {min, max} cells
--   shaftChance    : chance of a vertical chimney rising from the chamber
--   waterChance    : chance that the chamber floor holds a pool of water
--   pillars        : max rock pillars inside a chamber
--   geodes         : {min, max} sealed geodes per sector
--   chestChance    : chance of a chest on a chamber floor / at a tunnel dead end
--   shapes         : weights of chamber shapes (dome, hall, pit, split)

export type BaseRule = { id: string, weight: number, fadeInMeters: number? }

export type CaveRecipe = {
	style: string,
	tunnels: number,
	tunnelRadius: number,
	branchChance: number,
	chamberChance: number,
	chamberRadius: { number },
	chamberHeight: { number },
	shaftChance: number,
	waterChance: number,
	pillars: number,
	geodes: { number },
	chestChance: number,
	shapes: { [string]: number }?, -- chamber shape weights: dome, hall, pit, split
}

export type Zone = {
	id: string,
	index: number,
	name: string,
	subtitle: string,
	minDepth: number,
	maxDepth: number,
	base: { BaseRule },
	veinChance: number,
	veinDensity: number,
	lighting: {
		ambient: Color3,
		fogColor: Color3,
		fogEnd: number,
		lampBrightness: number,
	},
	accent: Color3,
	caves: CaveRecipe?,
}

local zones: { Zone } = {
	{
		id = "garden",
		index = 1,
		name = "El Jardín",
		subtitle = "0 – 50 m",
		minDepth = 0,
		maxDepth = 50,
		base = { { id = "dirt", weight = 10 }, { id = "stone", weight = 6, fadeInMeters = 30 } },
		veinChance = 0.16,
		veinDensity = 0.45,
		lighting = {
			ambient = Color3.fromRGB(120, 110, 100),
			fogColor = Color3.fromRGB(190, 210, 230),
			fogEnd = 1200,
			lampBrightness = 0,
		},
		accent = Color3.fromRGB(120, 200, 90),
	},
	{
		id = "forgotten_mines",
		index = 2,
		name = "Minas Olvidadas",
		subtitle = "50 – 150 m",
		minDepth = 50,
		maxDepth = 150,
		base = { { id = "stone", weight = 8 }, { id = "slate", weight = 6, fadeInMeters = 20 } },
		veinChance = 0.2,
		veinDensity = 0.5,
		lighting = {
			ambient = Color3.fromRGB(70, 60, 52),
			fogColor = Color3.fromRGB(40, 34, 30),
			fogEnd = 260,
			lampBrightness = 1.4,
		},
		accent = Color3.fromRGB(210, 160, 90),
		caves = {
			style = "mine",
			tunnels = 2,
			tunnelRadius = 1.45,
			branchChance = 0.5,
			chamberChance = 0.55,
			chamberRadius = { 4.5, 6 },
			chamberHeight = { 3.5, 5 },
			shaftChance = 0.35,
			waterChance = 0.3,
			pillars = 1,
			geodes = { 0, 1 },
			chestChance = 0.5,
			shapes = { dome = 1, hall = 3, pit = 1, split = 2 },
		},
	},
	{
		id = "crystal_caves",
		index = 3,
		name = "Cuevas de Cristal",
		subtitle = "150 – 350 m",
		minDepth = 150,
		maxDepth = 350,
		base = { { id = "slate", weight = 4 }, { id = "crystal_rock", weight = 10, fadeInMeters = 25 } },
		veinChance = 0.22,
		veinDensity = 0.5,
		lighting = {
			ambient = Color3.fromRGB(92, 94, 150), -- Studio test 2: (60, 60, 110) read almost black at 200 m
			fogColor = Color3.fromRGB(40, 40, 92),
			fogEnd = 240,
			lampBrightness = 1.6,
		},
		accent = Color3.fromRGB(120, 140, 255),
		caves = {
			style = "crystal",
			tunnels = 1,
			tunnelRadius = 1.8,
			branchChance = 0.6,
			chamberChance = 0.75,
			chamberRadius = { 5.5, 6.8 },
			chamberHeight = { 5, 8 },
			shaftChance = 0.5,
			waterChance = 0.35,
			pillars = 2,
			geodes = { 1, 2 },
			chestChance = 0.55,
			shapes = { dome = 3, hall = 1, pit = 2, split = 2 },
		},
	},
	{
		id = "ancient_caverns",
		index = 4,
		name = "Cavernas Antiguas",
		subtitle = "350 – 650 m",
		minDepth = 350,
		maxDepth = 650,
		base = { { id = "crystal_rock", weight = 3 }, { id = "ancient_sandstone", weight = 10, fadeInMeters = 30 } },
		veinChance = 0.16,
		veinDensity = 0.5,
		lighting = {
			ambient = Color3.fromRGB(90, 76, 54),
			fogColor = Color3.fromRGB(60, 46, 30),
			fogEnd = 260,
			lampBrightness = 1.6,
		},
		accent = Color3.fromRGB(230, 200, 120),
		caves = {
			style = "ruin",
			tunnels = 2,
			tunnelRadius = 1.6,
			branchChance = 0.4,
			chamberChance = 0.7,
			chamberRadius = { 5, 6.5 },
			chamberHeight = { 4.5, 7 },
			shaftChance = 0.3,
			waterChance = 0.2,
			pillars = 3,
			geodes = { 0, 1 },
			chestChance = 0.55,
			shapes = { dome = 1, hall = 3, pit = 0, split = 2 },
		},
	},
	{
		id = "volcanic_depths",
		index = 5,
		name = "Profundidades Volcánicas",
		subtitle = "650 – 1000 m",
		minDepth = 650,
		maxDepth = 1000,
		base = { { id = "ancient_sandstone", weight = 2 }, { id = "basalt", weight = 10, fadeInMeters = 25 } },
		veinChance = 0.15,
		veinDensity = 0.5,
		lighting = {
			ambient = Color3.fromRGB(110, 54, 30),
			fogColor = Color3.fromRGB(70, 24, 10),
			fogEnd = 220,
			lampBrightness = 1.2,
		},
		accent = Color3.fromRGB(255, 120, 40),
		caves = {
			style = "lava",
			tunnels = 1,
			tunnelRadius = 1.7,
			branchChance = 0.5,
			chamberChance = 0.6,
			chamberRadius = { 5, 6.5 },
			chamberHeight = { 4, 7 },
			shaftChance = 0.5,
			waterChance = 0,
			pillars = 2,
			geodes = { 0, 1 },
			chestChance = 0.5,
			shapes = { dome = 2, hall = 1, pit = 3, split = 1 },
		},
	},
	{
		id = "abyss",
		index = 6,
		name = "El Abismo",
		subtitle = "1000 – 1500 m",
		minDepth = 1000,
		maxDepth = 1500,
		base = { { id = "basalt", weight = 2 }, { id = "abyss_rock", weight = 10, fadeInMeters = 30 } },
		veinChance = 0.15,
		veinDensity = 0.5,
		lighting = {
			ambient = Color3.fromRGB(34, 56, 70), -- still the darkest layer, but not pure black
			fogColor = Color3.fromRGB(4, 10, 16),
			fogEnd = 180,
			lampBrightness = 2,
		},
		accent = Color3.fromRGB(40, 255, 220),
		caves = {
			style = "abyss",
			tunnels = 1,
			tunnelRadius = 1.8,
			branchChance = 0.6,
			chamberChance = 0.7,
			chamberRadius = { 5.5, 6.8 },
			chamberHeight = { 5, 9 },
			shaftChance = 0.6,
			waterChance = 0.25,
			pillars = 2,
			geodes = { 1, 2 },
			chestChance = 0.55,
			shapes = { dome = 2, hall = 1, pit = 3, split = 2 },
		},
	},
	{
		id = "unknown_core",
		index = 7,
		name = "El Núcleo Desconocido",
		subtitle = "1500 m +",
		minDepth = 1500,
		maxDepth = math.huge,
		base = { { id = "abyss_rock", weight = 2 }, { id = "core_matter", weight = 10, fadeInMeters = 30 } },
		veinChance = 0.15,
		veinDensity = 0.55,
		lighting = {
			ambient = Color3.fromRGB(120, 140, 150),
			fogColor = Color3.fromRGB(150, 210, 220),
			fogEnd = 400,
			lampBrightness = 1,
		},
		accent = Color3.fromRGB(200, 255, 250),
		caves = {
			style = "core",
			tunnels = 1,
			tunnelRadius = 2,
			branchChance = 0.5,
			chamberChance = 1,
			chamberRadius = { 6, 7 },
			chamberHeight = { 7, 11 },
			shaftChance = 0.6,
			waterChance = 0,
			pillars = 3,
			geodes = { 1, 2 },
			chestChance = 0.6,
			shapes = { dome = 4, hall = 0, pit = 1, split = 1 },
		},
	},
}

local Zones = {}
Zones.List = zones

-- Returns the zone that contains `depthMeters` (clamped to the first/last zone).
function Zones.at(depthMeters: number): Zone
	if depthMeters < 0 then
		return zones[1]
	end
	for _, zone in zones do
		if depthMeters < zone.maxDepth then
			return zone
		end
	end
	return zones[#zones]
end

return Zones
