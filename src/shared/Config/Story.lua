--!strict
-- Narrative content. Writers can edit this file without touching code.
--
-- Notes are the clues of the mystery. `reward` is paid the first time a player reads a note that
-- was found underground (the house note is free).

export type Note = { id: string, title: string, body: string, reward: number, source: string }

local Story = {}

Story.Notes = {
	house_note = {
		id = "house_note",
		title = "Una nota bajo la puerta",
		source = "Casa",
		reward = 0,
		body = "Si estás leyendo esto, la casa ya es tuya.\n\n"
			.. "Lo que buscábamos no está en ningún mapa. Está debajo, siempre más abajo. "
			.. "Yo llegué hasta donde la tierra empieza a cantar y tuve que parar.\n\n"
			.. "En el garaje dejé mi vieja pala. No es gran cosa, pero empieza por ahí. "
			.. "Vende lo que encuentres en el carro y mejora tu equipo.\n\n"
			.. "Y si alguna vez oyes un zumbido bajo los pies... no te detengas.\n\n— E.",
	},
	miner_box = {
		id = "miner_box",
		title = "La caja del minero",
		source = "45 m",
		reward = 150,
		body = "Diario de E., día 12.\n\n"
			.. "A cuarenta y tantos metros el zumbido se oye con claridad. No es agua ni maquinaria. "
			.. "Es un ritmo: tres golpes, una pausa, tres golpes.\n\n"
			.. "Encontré túneles más abajo. Alguien apuntaló las paredes con madera hace mucho, "
			.. "mucho antes de que se construyera la casa.\n\n"
			.. "Dejo aquí mis ahorros por si alguien sigue mis pasos. Úsalos para una pala mejor: "
			.. "la pizarra de abajo no se deja con cualquier cosa.",
	},
	stone_tablet = {
		id = "stone_tablet",
		title = "La placa de piedra",
		source = "140 m",
		reward = 1000,
		body = "La placa está tallada en una piedra que no se parece a ninguna de las capas de alrededor. "
			.. "Los símbolos brillan cuando acercas la mano.\n\n"
			.. "Junto a ella, una hoja del diario de E., casi borrada:\n\n"
			.. '"He copiado los símbolos. No es un idioma: es un mapa. Las marcas indican profundidades, '
			.. "y la última está mucho más abajo de lo que cualquier mina ha llegado nunca. "
			.. 'Debajo de la pizarra la roca se vuelve cristal. Ahí empieza lo de verdad."',
	},
} :: { [string]: Note }

Story.NoteOrder = { "house_note", "miner_box", "stone_tablet" }

Story.ZoneIntro = {
	garden = "La tierra todavía huele a lluvia.",
	forgotten_mines = "Alguien excavó aquí antes que tú.",
	crystal_caves = "La roca brilla con luz propia.",
	ancient_caverns = "Estas columnas no las hizo la naturaleza.",
	volcanic_depths = "El calor sube desde abajo.",
	abyss = "La oscuridad aquí parece respirar.",
	unknown_core = "Has llegado a donde nadie volvió.",
}

return Story
