--!strict
-- Geological regions. Depths are in metres (1 cell = 1 m).
--
-- base       : weighted base rock mix. `fromDepth`/`toDepth` (optional, relative to the zone start)
--              let a material fade in/out inside a zone so transitions do not look like flat bands.
-- veinChance : probability (0..1) that a 3x3x3 vein block contains ore at all.
-- veinDensity: probability (0..1) that a cell inside an ore vein block is ore.

export type BaseRule = { id: string, weight: number, fadeInMeters: number? }

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
			ambient = Color3.fromRGB(60, 60, 110),
			fogColor = Color3.fromRGB(30, 30, 70),
			fogEnd = 240,
			lampBrightness = 1.6,
		},
		accent = Color3.fromRGB(120, 140, 255),
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
			ambient = Color3.fromRGB(24, 40, 52),
			fogColor = Color3.fromRGB(4, 10, 16),
			fogEnd = 180,
			lampBrightness = 2,
		},
		accent = Color3.fromRGB(40, 255, 220),
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
