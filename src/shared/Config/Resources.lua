--!strict
-- Data-driven definitions for every diggable material / collectable resource.
--
-- terrainMaterial : the Roblox terrain material that represents this resource in the world.
--                   Terrain colours are global, so each material maps to exactly one resource.
-- hardness        : hit points of one cell; each hit deals the tool's power as damage.
-- requiredPower   : minimum tool power able to damage the material at all.
-- value           : coins per unit when sold.
-- weight          : backpack units used by one collected cell.
-- spawn           : ore placement (base rocks are placed by Zones.lua instead).

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Unique"

export type SpawnRule = {
	minDepth: number,
	maxDepth: number,
	chance: number, -- relative weight of this ore inside a vein roll
}

export type Resource = {
	id: string,
	name: string,
	value: number,
	color: Color3,
	terrainMaterial: Enum.Material,
	rarity: Rarity,
	hardness: number,
	requiredPower: number,
	weight: number,
	isOre: boolean,
	spawn: SpawnRule?,
	effect: string, -- key into EffectsController presets
	sound: string, -- key into Sounds config
	icon: string, -- glyph used by the UI icon generator
	uses: { string },
	order: number,
}

local Rarities = {
	Common = { order = 1, name = "Común", color = Color3.fromRGB(200, 200, 200) },
	Uncommon = { order = 2, name = "Poco común", color = Color3.fromRGB(110, 220, 110) },
	Rare = { order = 3, name = "Raro", color = Color3.fromRGB(80, 160, 255) },
	Epic = { order = 4, name = "Épico", color = Color3.fromRGB(190, 100, 255) },
	Legendary = { order = 5, name = "Legendario", color = Color3.fromRGB(255, 180, 40) },
	Unique = { order = 6, name = "Único", color = Color3.fromRGB(255, 90, 90) },
}

local M = Enum.Material

local list: { Resource } = {
	-- Base materials ----------------------------------------------------------------
	{
		id = "grass",
		name = "Césped",
		value = 1,
		color = Color3.fromRGB(106, 170, 72),
		terrainMaterial = M.Grass,
		rarity = "Common",
		hardness = 2,
		requiredPower = 1,
		weight = 1,
		isOre = false,
		effect = "soil",
		sound = "dig_soil",
		icon = "●",
		uses = {},
	},
	{
		id = "dirt",
		name = "Tierra",
		value = 1,
		color = Color3.fromRGB(124, 86, 56),
		terrainMaterial = M.Ground,
		rarity = "Common",
		hardness = 2,
		requiredPower = 1,
		weight = 1,
		isOre = false,
		effect = "soil",
		sound = "dig_soil",
		icon = "●",
		uses = { "Rellenar plataformas (próximamente)" },
	},
	{
		id = "stone",
		name = "Piedra",
		value = 2,
		color = Color3.fromRGB(128, 128, 132),
		terrainMaterial = M.Rock,
		rarity = "Common",
		hardness = 4,
		requiredPower = 1,
		weight = 1,
		isOre = false,
		effect = "rock",
		sound = "dig_rock",
		icon = "◆",
		uses = { "Construcción (próximamente)" },
	},
	{
		id = "slate",
		name = "Pizarra",
		value = 3,
		color = Color3.fromRGB(88, 84, 92),
		terrainMaterial = M.Slate,
		rarity = "Common",
		hardness = 8,
		requiredPower = 2,
		weight = 1,
		isOre = false,
		effect = "rock",
		sound = "dig_rock",
		icon = "◆",
		uses = {},
	},
	{
		id = "crystal_rock",
		name = "Roca cristalina",
		value = 5,
		color = Color3.fromRGB(70, 74, 110),
		terrainMaterial = M.Mud,
		rarity = "Common",
		hardness = 16,
		requiredPower = 4,
		weight = 1,
		isOre = false,
		effect = "crystal",
		sound = "dig_rock",
		icon = "◆",
		uses = {},
	},
	{
		id = "ancient_sandstone",
		name = "Arenisca antigua",
		value = 8,
		color = Color3.fromRGB(196, 168, 120),
		terrainMaterial = M.Sand,
		rarity = "Common",
		hardness = 30,
		requiredPower = 7,
		weight = 1,
		isOre = false,
		effect = "rock",
		sound = "dig_rock",
		icon = "◆",
		uses = {},
	},
	{
		id = "basalt",
		name = "Basalto",
		value = 14,
		color = Color3.fromRGB(46, 40, 40),
		terrainMaterial = M.Basalt,
		rarity = "Common",
		hardness = 60,
		requiredPower = 12,
		weight = 1,
		isOre = false,
		effect = "lava",
		sound = "dig_rock",
		icon = "◆",
		uses = {},
	},
	{
		id = "abyss_rock",
		name = "Roca abisal",
		value = 22,
		color = Color3.fromRGB(26, 28, 36),
		terrainMaterial = M.Cobblestone,
		rarity = "Common",
		hardness = 100,
		requiredPower = 20,
		weight = 1,
		isOre = false,
		effect = "abyss",
		sound = "dig_rock",
		icon = "◆",
		uses = {},
	},
	{
		id = "core_matter",
		name = "Materia del núcleo",
		value = 40,
		color = Color3.fromRGB(210, 236, 232),
		terrainMaterial = M.Snow,
		rarity = "Common",
		hardness = 160,
		requiredPower = 35,
		weight = 1,
		isOre = false,
		effect = "core",
		sound = "dig_crystal",
		icon = "◆",
		uses = {},
	},

	-- Ores --------------------------------------------------------------------------
	{
		id = "coal",
		name = "Carbón",
		value = 5,
		color = Color3.fromRGB(34, 34, 38),
		terrainMaterial = M.Asphalt,
		rarity = "Common",
		hardness = 4,
		requiredPower = 1,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 2, maxDepth = 160, chance = 10 },
		effect = "ore",
		sound = "dig_ore",
		icon = "▲",
		uses = { "Combustible del taller (próximamente)" },
	},
	{
		id = "copper",
		name = "Cobre",
		value = 12,
		color = Color3.fromRGB(214, 120, 64),
		terrainMaterial = M.Sandstone,
		rarity = "Common",
		hardness = 5,
		requiredPower = 1,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 4, maxDepth = 220, chance = 7 },
		effect = "ore",
		sound = "dig_ore",
		icon = "▲",
		uses = { "Cableado de taladros (próximamente)" },
	},
	{
		id = "iron",
		name = "Hierro",
		value = 25,
		color = Color3.fromRGB(150, 120, 108),
		terrainMaterial = M.Granite,
		rarity = "Uncommon",
		hardness = 10,
		requiredPower = 2,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 40, maxDepth = 400, chance = 6 },
		effect = "ore",
		sound = "dig_ore",
		icon = "▲",
		uses = {},
	},
	{
		id = "silver",
		name = "Plata",
		value = 55,
		color = Color3.fromRGB(206, 214, 226),
		terrainMaterial = M.Pavement,
		rarity = "Uncommon",
		hardness = 14,
		requiredPower = 3,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 70, maxDepth = 450, chance = 4 },
		effect = "shine",
		sound = "dig_ore",
		icon = "▲",
		uses = {},
	},
	{
		id = "gold",
		name = "Oro",
		value = 110,
		color = Color3.fromRGB(255, 200, 40),
		terrainMaterial = M.Salt,
		rarity = "Rare",
		hardness = 20,
		requiredPower = 4,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 150, maxDepth = 700, chance = 3.5 },
		effect = "shine",
		sound = "discover_rare",
		icon = "★",
		uses = {},
	},
	{
		id = "amethyst",
		name = "Amatista",
		value = 170,
		color = Color3.fromRGB(160, 90, 230),
		terrainMaterial = M.Limestone,
		rarity = "Rare",
		hardness = 24,
		requiredPower = 4,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 160, maxDepth = 400, chance = 3 },
		effect = "crystal",
		sound = "discover_rare",
		icon = "★",
		uses = {},
	},
	{
		id = "blue_crystal",
		name = "Cristal azul",
		value = 250,
		color = Color3.fromRGB(70, 180, 255),
		terrainMaterial = M.Ice,
		rarity = "Rare",
		hardness = 28,
		requiredPower = 4,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 180, maxDepth = 420, chance = 2.4 },
		effect = "crystal",
		sound = "discover_rare",
		icon = "★",
		uses = {},
	},
	{
		id = "ruby",
		name = "Rubí",
		value = 425,
		color = Color3.fromRGB(220, 30, 60),
		terrainMaterial = M.Brick,
		rarity = "Epic",
		hardness = 45,
		requiredPower = 7,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 350, maxDepth = 900, chance = 2 },
		effect = "crystal",
		sound = "discover_epic",
		icon = "✦",
		uses = {},
	},
	{
		id = "emerald",
		name = "Esmeralda",
		value = 600,
		color = Color3.fromRGB(40, 210, 110),
		terrainMaterial = M.Glacier,
		rarity = "Epic",
		hardness = 55,
		requiredPower = 7,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 380, maxDepth = 950, chance = 1.6 },
		effect = "crystal",
		sound = "discover_epic",
		icon = "✦",
		uses = {},
	},
	{
		id = "titanium",
		name = "Titanio",
		value = 850,
		color = Color3.fromRGB(176, 196, 210),
		terrainMaterial = M.Concrete,
		rarity = "Epic",
		hardness = 70,
		requiredPower = 12,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 450, maxDepth = 1200, chance = 1.4 },
		effect = "shine",
		sound = "discover_epic",
		icon = "✦",
		uses = {},
	},
	{
		id = "obsidian",
		name = "Obsidiana especial",
		value = 1250,
		color = Color3.fromRGB(90, 40, 110),
		terrainMaterial = M.CrackedLava,
		rarity = "Legendary",
		hardness = 110,
		requiredPower = 20,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 650, maxDepth = 1100, chance = 1 },
		effect = "lava",
		sound = "discover_legendary",
		icon = "✸",
		uses = {},
	},
	{
		id = "abyss_crystal",
		name = "Cristal abisal",
		value = 2500,
		color = Color3.fromRGB(40, 255, 220),
		terrainMaterial = M.LeafyGrass,
		rarity = "Legendary",
		hardness = 200,
		requiredPower = 35,
		weight = 1,
		isOre = true,
		spawn = { minDepth = 1000, maxDepth = 2200, chance = 0.8 },
		effect = "abyss",
		sound = "discover_legendary",
		icon = "✸",
		uses = {},
	},
} :: any

local Resources = {}
Resources.Rarities = Rarities
Resources.List = list
Resources.ById = {} :: { [string]: Resource }
Resources.ByMaterial = {} :: { [Enum.Material]: Resource }
Resources.Ores = {} :: { Resource }

for index, resource in list do
	resource.order = index
	assert(Resources.ById[resource.id] == nil, "Duplicate resource id " .. resource.id)
	assert(Resources.ByMaterial[resource.terrainMaterial] == nil, "Terrain material reused by " .. resource.id)
	Resources.ById[resource.id] = resource
	Resources.ByMaterial[resource.terrainMaterial] = resource
	if resource.isOre then
		table.insert(Resources.Ores, resource)
	end
end

function Resources.get(id: string): Resource?
	return Resources.ById[id]
end

function Resources.fromMaterial(material: Enum.Material): Resource?
	return Resources.ByMaterial[material]
end

function Resources.isRareOrBetter(resource: Resource): boolean
	return Rarities[resource.rarity].order >= Rarities.Rare.order
end

return Resources
