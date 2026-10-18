--!strict
-- Journal entries that grow with later discoveries. Each paragraph can require conditions; the
-- client composes the visible text (Util/JournalView). Placeholders: {solvedCount}, {cellsDug}.
--
-- requires keys (all must hold):
--   counterFound / counterSolved : the Counter room state
--   fossil = id                  : species registered in the collection
--   zone = id                    : zone reached
--   clue = id                    : note read
--   set = id / anySet = true     : collection set complete (Config/Collections)

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
		},
	},
}

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
