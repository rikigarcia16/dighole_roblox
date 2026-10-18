--!strict
-- Collection sets: finding every item of a set once pays a one-time reward and adds a line to the
-- journal. Progress comes from the profile (discoveries, fossil collection), so nothing is
-- tracked twice; a completed set is remembered as quests.completed["set_" .. id] (no new save
-- field, see Logic/CollectionSets).

export type Set = {
	id: string,
	name: string,
	kind: "resources" | "fossils" | "exhibit", -- exhibit: kept pieces shown in the house display case
	items: { string }?, -- resource ids (kind "resources"); fossils use every species
	reward: number,
	line: string, -- journal line once complete
}

local Collections: { Set } = {
	{
		id = "upper_ores",
		name = "Menas del Jardín y las Minas",
		kind = "resources",
		items = { "coal", "copper", "iron", "silver" },
		reward = 300,
		line = "Carbón, cobre, hierro, plata: lo mismo que buscaban los mineros de E.",
	},
	{
		id = "gems_crystal",
		name = "Gemas de cristal",
		kind = "resources",
		items = { "gold", "amethyst", "blue_crystal" },
		reward = 1500,
		line = "Las gemas de cristal crecen hacia el centro del agujero, como si algo las atrajera.",
	},
	{
		id = "gems_deep",
		name = "Gemas profundas",
		kind = "resources",
		items = { "ruby", "emerald", "titanium" },
		reward = 8000,
		line = "Rubí, esmeralda, titanio: nadie de la superficie ha sostenido los tres a la vez.",
	},
	{
		id = "legendary",
		name = "Materia legendaria",
		kind = "resources",
		items = { "obsidian", "abyss_crystal" },
		reward = 40000,
		line = "El cristal abisal se oscurece cuando lo acercas a la obsidiana. Se reconocen.",
	},
	{
		id = "relics",
		name = "Restos de quien vino antes",
		kind = "exhibit", -- finding them is not enough: they must be kept and shown, not sold
		items = { "antique_fragment", "relic", "ancient_artifact" },
		reward = 10000,
		line = "Fragmento, reliquia, artefacto: tres épocas, la misma marca grabada.",
	},
	{
		id = "fossils",
		name = "Fósiles del agujero",
		kind = "fossils",
		reward = 2500,
		line = "Siete especies. Ninguna tiene ojos. La huella de pala es la más antigua de todas.",
	},
}

return Collections
