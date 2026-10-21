--!strict
-- Fossil species. Original creatures of THE HOLE NEVER ENDS: each one is a physical model embedded
-- in the rock (see CaveProps.fossil) and an entry in the player's collection.
--
-- The lore lines are written to raise questions, and deeper species change how earlier ones read:
-- the crystal creature grew its crystals while alive; the shovel imprint is older than the rock.
--
-- minDepth / maxDepth : where the species can appear (metres)
-- weight              : relative chance among the species valid at that depth
-- model               : recipe used by CaveProps.fossil
-- reward              : coins the first time the species is registered

export type Species = {
	id: string,
	name: string,
	rarity: string,
	minDepth: number,
	maxDepth: number,
	weight: number,
	model: "shell"
		| "coil"
		| "fish"
		| "mole"
		| "wing"
		| "crystal"
		| "imprint"
		| "salamander"
		| "hand"
		| "eye"
		| "rings",
	reward: number,
	lore: string,
	order: number,
}

local list: { Species } = {
	{
		id = "tunnel_beetle",
		name = "Escarabajo de túnel",
		rarity = "Common",
		minDepth = 6,
		maxDepth = 60,
		weight = 10,
		model = "shell",
		reward = 40,
		lore = "Excavaba galerías. Sus túneles fosilizados bajan con el mismo ángulo que tu agujero.",
	},
	{
		id = "ringed_worm",
		name = "Gusano anillado",
		rarity = "Common",
		minDepth = 10,
		maxDepth = 130,
		weight = 8,
		model = "coil",
		reward = 60,
		lore = "Treinta anillos idénticos. Demasiado idénticos, como si alguien los hubiera fabricado en serie.",
	},
	{
		id = "eyeless_fish",
		name = "Pez sin ojos",
		rarity = "Uncommon",
		minDepth = 50,
		maxDepth = 160,
		weight = 7,
		model = "fish",
		reward = 120,
		lore = "Un pez a cien metros bajo tierra. Aquí hubo agua... o algo que ocupaba su lugar.",
	},
	{
		id = "six_legged_mole",
		name = "Topo de seis patas",
		rarity = "Rare",
		minDepth = 60,
		maxDepth = 180,
		weight = 5,
		model = "mole",
		reward = 220,
		lore = "Seis patas cavadoras. Ninguna especie conocida, viva o extinta, tiene seis.",
	},
	{
		id = "shovel_imprint",
		name = "Huella de una pala",
		rarity = "Epic",
		minDepth = 80,
		maxDepth = 220,
		weight = 4,
		model = "imprint",
		reward = 600,
		lore = "No es un animal. Es la huella de una pala, idéntica a la tuya, fosilizada en roca de millones de años.",
	},
	{
		id = "stone_wing",
		name = "Ala de piedra",
		rarity = "Rare",
		minDepth = 120,
		maxDepth = 320,
		weight = 4,
		model = "wing",
		reward = 350,
		lore = "Un ala, bajo tierra. Las marcas de las plumas no apuntan hacia el cielo: apuntan hacia abajo.",
	},
	{
		id = "crystal_creature",
		name = "Criatura cristalizada",
		rarity = "Epic",
		minDepth = 150,
		maxDepth = 400,
		weight = 3,
		model = "crystal",
		reward = 700,
		lore = "Los cristales no crecieron sobre sus huesos al morir. Crecieron dentro de ella mientras vivía.",
	},
	-- Deep layers (from 650 m). They form their own collection ("deep_fossils") so that the original
	-- seven-species set stays complete for players who had already finished it.
	{
		id = "ash_salamander",
		name = "Salamandra de ceniza",
		rarity = "Rare",
		minDepth = 650,
		maxDepth = 1000,
		weight = 6,
		model = "salamander",
		reward = 1500,
		lore = "Huesos que no se fundieron a mil grados. Las vértebras tienen marcas de herramienta: "
			.. "alguien la desenterró antes que tú y la volvió a enterrar.",
	},
	{
		id = "tool_hand",
		name = "Mano con mango",
		rarity = "Epic",
		minDepth = 700,
		maxDepth = 1100,
		weight = 4,
		model = "hand",
		reward = 3000,
		lore = "Cinco dedos cerrados sobre un mango de madera. La piedra es de hace millones de años; "
			.. "la madera no se ha fosilizado. Todavía huele a resina.",
	},
	{
		id = "abyss_eye",
		name = "Ojo del abismo",
		rarity = "Epic",
		minDepth = 1000,
		maxDepth = 1500,
		weight = 5,
		model = "eye",
		reward = 5000,
		lore = "Un ojo del tamaño de una puerta, mirando hacia arriba. Hacia el agujero. Hacia ti.",
	},
	{
		id = "counting_bones",
		name = "El que cuenta",
		rarity = "Legendary",
		minDepth = 1500,
		maxDepth = 2200,
		weight = 4,
		model = "rings",
		reward = 12000,
		lore = "Tres anillos de hueso, seis marcas en cada uno. La máquina del Contador no es una máquina: "
			.. "es una copia de esto.",
	},
} :: any

local Fossils = {}
Fossils.List = list
Fossils.ById = {} :: { [string]: Species }
Fossils.MinDepth = 6
Fossils.MaxDepth = 2200

for index, species in list do
	species.order = index
	assert(Fossils.ById[species.id] == nil, "Duplicate fossil " .. species.id)
	Fossils.ById[species.id] = species
end

function Fossils.get(id: string): Species?
	return Fossils.ById[id]
end

return Fossils
