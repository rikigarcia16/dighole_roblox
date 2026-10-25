--!strict
-- Journal entries that grow with later discoveries. Each paragraph can require conditions; the
-- client composes the visible text (Util/JournalView). Placeholders: {solvedCount}, {cellsDug},
-- {hungCount} (blocks dug when the shovel was hung in E.'s workshop), {workshopShort} (how many
-- E. still had over you then), {engravedCount} (your number on the wall of "El fondo"), {loops}
-- (times the bedrock was broken).
--
-- requires keys (all must hold):
--   counterFound / counterSolved : the Counter room state
--   workshopFound / workshopHung : E.'s workshop state
--   workshopBeyondE              : you had dug more than E. when you hung your shovel
--   coreFound / coreEngraved     : "El fondo" found / your number engraved on its wall
--   coreLoops = n                : the bedrock broken at least n times
--   fossil = id                  : species registered in the collection
--   zone = id                    : zone reached
--   clue = id                    : note read
--   set = id / anySet = true     : collection set complete (Config/Collections)
--   feat = id / noFeat = id      : feat earned / not earned yet (Config/Feats)
--   geodes = n                   : at least n geodes opened
--   stations = n                 : at least n lift stations owned

export type Paragraph = { text: string, requires: { [string]: any }? }
export type Entry = { id: string, title: string, requires: { [string]: any }, paragraphs: { Paragraph } }

local Journal: { Entry } = {
	{
		id = "counter_found",
		title = "Una sala que nadie excavó",
		requires = { counterFound = true },
		paragraphs = {
			{
				text = "Al fondo de las Minas, las galerías de los mineros no terminan al azar: todas acaban aquí. "
					.. "Paredes lisas que ninguna herramienta raya. Una columna con tres anillos de símbolos que gira sola.",
			},
			{
				text = "El ritmo que oía a través de la roca venía de esta máquina: tres golpes, una pausa. "
					.. "Al entrar, se calló.",
				requires = { counterSolved = false },
			},
			{
				text = "La placa de la pared muestra un símbolo para cada anillo. Quizá la máquina espera algo.",
				requires = { counterSolved = false },
			},
		},
	},
	{
		id = "counter_solved",
		title = "Nos está contando",
		requires = { counterSolved = true },
		paragraphs = {
			{
				text = "Los anillos se detuvieron. Tres golpes, y en la base apareció un número: {solvedCount}. "
					.. "Lo comprobé dos veces. Es exactamente la cantidad de bloques que he excavado desde que llegué.",
			},
			{ text = "Ahora marca {cellsDug}. Sigue contando cada golpe de mi pala." },
			{
				text = "Desde que la encontré hay un montacargas que baja hasta ella. Alguien quería que volviera.",
			},
			{
				text = "La huella de pala fósil es idéntica a la mía, y la roca que la rodea tiene millones de años. "
					.. "Si la máquina cuenta palas, ¿a quién contaba antes que a mí?",
				requires = { fossil = "shovel_imprint" },
			},
			{
				text = "En las Cuevas de Cristal el ritmo vuelve a oírse, más grave, desde mucho más abajo. Hay otra.",
				requires = { zone = "crystal_caves" },
			},
			{
				text = "Los cristales de la criatura fósil vibran cuando pego la oreja a la roca. Tres golpes, una pausa.",
				requires = { fossil = "crystal_creature" },
			},
			{
				text = "En el Núcleo, tres anillos de hueso con seis marcas cada uno. La máquina no inventó nada: "
					.. "copió algo que estaba vivo.",
				requires = { fossil = "counting_bones" },
			},
		},
	},
	{
		id = "workshop_found",
		title = "El taller de E.",
		requires = { workshopFound = true },
		paragraphs = {
			{
				text = "Trescientos metros por debajo de la máquina, una puerta con marco de madera. Dentro, un banco, "
					.. "un martillo frío y un farol todavía tibio, y un estante con siete palas viejas. "
					.. "Cada una lleva una etiqueta con un número.",
			},
			{
				text = "El ritmo grave que se oía desde las Cuevas de Cristal venía de aquí: alguien martillaba en este "
					.. "banco, tres golpes y una pausa. Al abrir la puerta, el martillo ya estaba quieto.",
			},
			{
				text = "Hay un octavo gancho, vacío. Su etiqueta está en blanco.",
				requires = { workshopHung = false },
			},
			{
				text = "Los números de las etiquetas se parecen a los de la máquina: bloques. Cada pala contó los suyos.",
				requires = { counterSolved = true },
			},
		},
	},
	{
		id = "workshop_hung",
		title = "La octava pala",
		requires = { workshopHung = true },
		paragraphs = {
			{
				text = "Colgué mi pala en el gancho vacío. Las otras siete se balancearon a la vez, como si alguien "
					.. "hubiera abierto una puerta. En el libro del banco, debajo de «E. — 3 912», había una línea nueva "
					.. "con la misma letra: {hungCount}.",
			},
			{
				text = "Es mi número. Cuando llegué ya había cavado más que E. Nadie había bajado tanto.",
				requires = { workshopBeyondE = true },
			},
			{
				text = "E. llegó a 3 912. A mí me faltaban {workshopShort} cuando colgué la pala. "
					.. "La línea estaba escrita antes de que yo entrara.",
				requires = { workshopBeyondE = false },
			},
			{
				text = "La máquina me contó {solvedCount} al resolverla. El libro y la máquina llevan la misma cuenta.",
				requires = { counterSolved = true },
			},
			{
				text = "Desde entonces mi batería dura la mitad más. Las palas del estante no eran recuerdos: "
					.. "eran herramientas para el siguiente.",
			},
			{
				text = "La huella fósil de pala encaja con el gancho vacío. Alguien colgó una pala aquí antes de que "
					.. "la roca existiera.",
				requires = { fossil = "shovel_imprint" },
			},
			{
				text = "Más abajo, entre el basalto, una mano fosilizada agarraba un mango como los del estante. "
					.. "La madera no era piedra. Alguien la había dejado allí hace poco.",
				requires = { fossil = "tool_hand" },
			},
		},
	},
}

-- The bottom: the third anomaly and the end of the story (Config/Anomalies.Rooms.core).
table.insert(Journal, {
	id = "core_found",
	title = "El fondo",
	requires = { coreFound = true },
	paragraphs = {
		{
			text = "Debajo de todo, la roca deja de parecer roca: una pared negra y pulida, más dura que cualquier "
				.. "cosa que haya tocado. En ella hay tres columnas de números grabados.",
		},
		{
			text = "La primera tiene los nombres borrados y cifras enormes: 18 402, 11 930, 9 771, 6 215. La segunda "
				.. "dice «E. — 3 912». La tercera está vacía, salvo por la forma de una mano.",
			requires = { coreEngraved = false },
		},
		{
			text = "Apoyé la mano. La pared grabó {engravedCount} en la tercera columna, con la misma letra que el "
				.. "libro del taller. Los dos ritmos, el de la máquina y el del martillo, se pararon a la vez.",
			requires = { coreEngraved = true },
		},
		{
			text = "En el taller colgué mi pala debajo de la de E. Aquí abajo, mi número vuelve a quedar debajo del suyo.",
			requires = { coreEngraved = true, workshopHung = true },
		},
		{
			text = "Ahora lo entiendo. El agujero no es de nadie: se hereda. Cada uno llega hasta donde llegó el "
				.. "anterior y sigue un poco más. La máquina cuenta a quien cava, el taller guarda sus palas y el "
				.. "fondo guarda sus números.",
			requires = { coreEngraved = true },
		},
		{
			text = "La herramienta que salió de la pared no rebota contra la roca madre. Debajo del fondo hay algo.",
			requires = { coreEngraved = true, coreLoops = 0 },
		},
		{
			text = "Rompí la roca madre. Detrás no había más roca, sino luz, y después el césped de mi parcela, con el "
				.. "agujero delante, como el primer día. Debajo del fondo estaba el jardín.",
			requires = { coreLoops = 1 },
		},
		{
			text = "Ya van {loops} veces. El agujero nunca se acaba: da la vuelta.",
			requires = { coreLoops = 2 },
		},
	},
})

-- E.'s chalk marks: the feats (Config/Feats) are only ever hinted here, once something related has
-- happened, and confirmed when earned. Never a checklist.
table.insert(Journal, {
	id = "chalk",
	title = "Frases a tiza",
	requires = { zone = "forgotten_mines" },
	paragraphs = {
		{
			text = "En los campamentos de las Minas hay pizarras escritas con tiza, con la misma letra que la "
				.. "placa del Contador. No son avisos. Parecen apuestas.",
		},
		{
			text = "«Tres geodas sin ver el cielo. Después, el detector ya no duda.» — E.",
			requires = { geodes = 1, noFeat = "three_geodes" },
		},
		{
			text = "Tres geodas en una sola bajada. El detector responde antes, como si ya supiera qué busco.",
			requires = { feat = "three_geodes" },
		},
		{
			text = "«Hasta las Cavernas desde arriba, sin montacargas. Las manos aprenden a enrollar la cuerda.» — E.",
			requires = { stations = 1, noFeat = "bare_descent" },
		},
		{
			text = "Bajé hasta las Cavernas a pulso. Ahora caben dos cuerdas más en la mochila.",
			requires = { feat = "bare_descent" },
		},
		{
			text = "«Desde las Cuevas de Cristal hasta el cielo, cargado y sin baliza. Luego la baliza cobra la mitad.» — E.",
			requires = { zone = "crystal_caves", noFeat = "unaided_climb" },
		},
		{
			text = "Subí desde las Cuevas de Cristal con la mochila llena y sin ayuda. La baliza me cobra la mitad.",
			requires = { feat = "unaided_climb" },
		},
	},
})

-- One entry that grows with every completed collection set.
local Collections = require(script.Parent.Collections)
local collectionParagraphs: { Paragraph } = {
	{ text = "Lo que el agujero ha querido enseñarme, ordenado." },
}
for _, set in Collections do
	table.insert(collectionParagraphs, { text = "· " .. set.name .. ": " .. set.line, requires = { set = set.id } })
end
table.insert(Journal, {
	id = "collections",
	title = "Lo que guarda el agujero",
	requires = { anySet = true },
	paragraphs = collectionParagraphs,
})

return Journal
