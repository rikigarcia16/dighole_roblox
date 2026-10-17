--!strict
-- Main quest chain. Quests are completed in order; progress is always derived from the
-- authoritative profile (stats, discoveries, tools, clues), so a quest can never be rewarded twice
-- and nothing depends on catching a specific event.
--
-- kind:
--   "stat"      profile.stats[key] >= target
--   "depth"     profile.stats.maxDepth >= target
--   "collect"   profile.discoveries[key] >= target   (lifetime units found)
--   "tool"      the player owns tool `key`
--   "clue"      the player has read note `key`

export type Quest = {
	id: string,
	title: string,
	hint: string,
	kind: "stat" | "depth" | "collect" | "tool" | "clue",
	key: string?,
	target: number,
	reward: number,
}

local Quests: { Quest } = {
	{
		id = "dig_10",
		title = "Excava tus primeros 10 bloques",
		hint = "Mantén pulsado para cavar.",
		kind = "stat",
		key = "cellsDug",
		target = 10,
		reward = 15,
	},
	{
		id = "first_sale",
		title = "Vende minerales por primera vez",
		hint = "Carro verde junto al agujero.",
		kind = "stat",
		key = "sales",
		target = 1,
		reward = 20,
	},
	{
		id = "copper_5",
		title = "Encuentra 5 unidades de cobre",
		hint = "El cobre es naranja.",
		kind = "collect",
		key = "copper",
		target = 5,
		reward = 30,
	},
	{
		id = "buy_reinforced",
		title = "Compra una pala reforzada",
		hint = "En el garaje.",
		kind = "tool",
		key = "reinforced_shovel",
		target = 1,
		reward = 40,
	},
	{
		id = "depth_25",
		title = "Alcanza 25 metros",
		hint = "Sigue bajando.",
		kind = "depth",
		target = 25,
		reward = 60,
	},
	{
		id = "miner_box",
		title = "Encuentra lo que E. dejó enterrado",
		hint = "Algo de madera, cerca de los 45 m.",
		kind = "clue",
		key = "miner_box",
		target = 1,
		reward = 0,
	},
	{
		id = "antique",
		title = "Recupera un objeto antiguo",
		hint = "Aparecen al romper roca y tierra.",
		kind = "collect",
		key = "antique_fragment",
		target = 1,
		reward = 80,
	},
	{
		id = "depth_50",
		title = "Llega a las Minas Olvidadas",
		hint = "A partir de 50 m.",
		kind = "depth",
		target = 50,
		reward = 150,
	},
	{
		id = "geode",
		title = "Encuentra tu primera geoda",
		hint = "Rocas huecas en las minas: cava a su lado y ábrelas.",
		kind = "collect",
		key = "geode",
		target = 1,
		reward = 200,
	},
	{
		id = "cave",
		title = "Explora una cueva",
		hint = "Hay galerías y cámaras a partir de los 64 m.",
		kind = "stat",
		key = "cavesFound",
		target = 1,
		reward = 200,
	},
	{
		id = "stone_tablet",
		title = "Descifra una pista del misterio",
		hint = "Una placa de piedra cerca de los 140 m.",
		kind = "clue",
		key = "stone_tablet",
		target = 1,
		reward = 0,
	},
	{
		id = "depth_150",
		title = "Alcanza 150 metros",
		hint = "Las Cuevas de Cristal te esperan.",
		kind = "depth",
		target = 150,
		reward = 600,
	},
}

return Quests
