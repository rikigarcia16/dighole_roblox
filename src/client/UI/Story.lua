--!strict
-- Narrative text shown in game. Kept separate so writers can edit it without touching code.

local Story = {}

Story.FirstNote = {
	title = "Una nota bajo la puerta",
	body = "Si estás leyendo esto, la casa ya es tuya.\n\n"
		.. "Lo que buscábamos no está en ningún mapa. Está debajo, siempre más abajo. "
		.. "Yo llegué hasta donde la tierra empieza a cantar y tuve que parar.\n\n"
		.. "En el garaje dejé mi vieja pala. No es gran cosa, pero empieza por ahí. "
		.. "Vende lo que encuentres en el carro y mejora tu equipo.\n\n"
		.. "Y si alguna vez oyes un zumbido bajo los pies... no te detengas.\n\n— E.",
}

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
