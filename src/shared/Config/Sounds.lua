--!strict
-- Sound definitions. Only built-in `rbxasset://sounds/...` files shipped with the Roblox client are
-- referenced, so the project depends on no third-party audio.
--
-- VERIFICATION STATUS (Studio test 1, docs/STUDIO_REPORT_1.md): every file below LOADS in Studio.
-- `swoosh.wav` did not ("Asset is not approved for the requester") and is no longer used: the
-- swing is a soft, low click until there is original audio. `verified` stays false because loading
-- is not the same as sounding right; that is judged by ear (F7, SoundTestController).
-- A missing file never breaks the game: the Sound simply stays silent and a warning is printed.
-- For release, replace them with your own uploaded audio (keep the keys, change `id`).
--
-- Exception: digging, discoveries and the ending use library effects from the Roblox Creator Store
-- by ProSoundEffects (verified creator, free, licensed for use in Roblox experiences). Found with the
-- Studio asset search and checked to LOAD in Studio (lengths noted below); not original audio, so
-- replace them like the rest if you upload your own.
--
-- Pitch ranges are randomised per play so repeated hits never sound identical.

export type SoundDef = {
	id: string,
	volume: number,
	pitchMin: number,
	pitchMax: number,
	verified: boolean,
	purpose: string,
}

local function def(id: string, volume: number, pitchMin: number, pitchMax: number, purpose: string): SoundDef
	return { id = id, volume = volume, pitchMin = pitchMin, pitchMax = pitchMax, verified = false, purpose = purpose }
end

local THUD = "rbxasset://sounds/action_footsteps_plastic.mp3"
local COLLIDE = "rbxasset://sounds/collide.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local BUTTON = "rbxasset://sounds/button.wav"
local SPLASH = "rbxasset://sounds/impact_water.mp3"

-- Library effects (ProSoundEffects, see above).
local DIRT_HIT = "rbxassetid://9114083746" -- Dirt Dig, Throws from Shovel 12 (0.76 s)
local DIRT_BREAK = "rbxassetid://9114083260" -- Dirt Dig, Throws from Shovel 1 (0.90 s)
local ROCK_HIT = "rbxassetid://9118622414" -- Rock Impacts 7, hit rock with wood (0.40 s)
local ROCK_BREAK = "rbxassetid://9125879007" -- Rock Scrape, Deep Clunky Slides 11 (1.81 s)
local METAL_HIT = "rbxassetid://9113267751" -- Banging on Car Door 16, metal hit (0.36 s)
local CLINK = "rbxassetid://9125741593" -- Pipe Ring Off, soft ringing clink 18 (0.87 s)
local RING = "rbxassetid://9116224180" -- Large Metal Triangle, single ringing hit 7 (1.39 s)
local CHIMES_A = "rbxassetid://9125635426" -- Magical Exit, sparkling chimes 6 (3.86 s)
local CHIMES_B = "rbxassetid://9125635650" -- Magical Exit, sparkling chimes 10 (3.81 s)

local Sounds: { [string]: SoundDef } = {
	-- Hits (every swing that lands): short and quiet, they repeat hundreds of times.
	hit_soil = def(DIRT_HIT, 0.45, 1.0, 1.15, "Golpe en tierra / césped"),
	hit_rock = def(ROCK_HIT, 0.55, 0.9, 1.1, "Golpe en roca"),
	hit_ore = def(METAL_HIT, 0.3, 1.2, 1.35, "Golpe en mineral (metálico)"),
	hit_crystal = def(CLINK, 0.22, 1.6, 1.8, "Golpe en cristal (tintineo)"),
	hit_lava = def(ROCK_HIT, 0.55, 0.72, 0.82, "Golpe en basalto / obsidiana"),
	hit_dense = def(ROCK_HIT, 0.6, 0.6, 0.7, "Golpe en roca abisal / núcleo (grave)"),
	-- Breaks (the cell gives way): lower and fuller than the hit.
	break_soil = def(DIRT_BREAK, 0.65, 0.85, 0.95, "Rotura de tierra"),
	break_rock = def(ROCK_BREAK, 0.45, 1.15, 1.3, "Rotura de roca"),
	break_ore = def(CLINK, 0.45, 0.9, 1.0, "Rotura de veta de mineral"),
	break_crystal = def(RING, 0.35, 1.2, 1.3, "Rotura de cristal"),
	-- Tool swings.
	swing_light = def(CLICK, 0.08, 0.45, 0.55, "Movimiento de pala (provisional: falta audio propio)"),
	swing_heavy = def(CLICK, 0.1, 0.32, 0.4, "Movimiento de pico (provisional: falta audio propio)"),
	drill = def(CLICK, 0.3, 0.7, 0.8, "Taladro"),
	plasma = def(PING, 0.2, 2.0, 2.3, "Excavador de plasma"),
	too_hard = def(COLLIDE, 0.5, 1.6, 1.7, "Rebote: material demasiado duro"),
	-- Discoveries, by rarity: each tier must be clearly distinct from ordinary hits.
	discover_rare = def(CHIMES_A, 0.45, 1.15, 1.15, "Descubrimiento raro"),
	discover_epic = def(CHIMES_B, 0.6, 1.0, 1.0, "Descubrimiento épico"),
	discover_legendary = def(CHIMES_B, 0.8, 0.8, 0.8, "Descubrimiento legendario"),
	geode_open = def(PING, 0.6, 1.35, 1.35, "Apertura de geoda"),
	fossil_extract = def(THUD, 0.7, 0.8, 0.8, "Extracción de fósil"),
	cave_open = def(SPLASH, 0.35, 0.5, 0.5, "Abrir una cueva (eco de aire)"),
	-- The Counter. NEEDS ORIGINAL AUDIO: a deep three-knock rhythm and a low hum are its identity;
	-- these built-in placeholders only make the timing testable.
	counter_knock = def(COLLIDE, 0.9, 0.32, 0.36, "El Contador: golpe del ritmo (placeholder)"),
	-- The ending (library audio, see above).
	core_engrave = def(
		"rbxassetid://9118656994",
		0.7,
		1.05,
		1.1,
		"El fondo: la pared graba tu número (Rock Movement 21)"
	),
	core_break = def(
		"rbxassetid://9118666800",
		1,
		0.85,
		0.9,
		"La roca madre cede (Rock Scrape Deep Grinding Impacts 16)"
	),
	core_light = def("rbxassetid://9125635430", 0.8, 0.9, 0.9, "La luz blanca (Magical Exit Sparkling Chimes 5)"),
	counter_lock = def(PING, 0.5, 0.55, 0.55, "El Contador: un anillo encaja"),
	counter_hum = def(CLICK, 0.12, 0.22, 0.22, "El Contador: zumbido de la sala (placeholder, en bucle)"),
	counter_found = def(SPLASH, 0.5, 0.35, 0.35, "Entrar en la sala del Contador"),
	-- UI.
	pickup = def(PING, 0.18, 1.8, 2.0, "Recoger mineral"),
	sell = def(CLINK, 0.55, 1.35, 1.45, "Venta"),
	purchase = def(RING, 0.45, 1.5, 1.5, "Compra"),
	ui_click = def(BUTTON, 0.4, 1, 1, "Botón"),
	error = def(BUTTON, 0.4, 0.6, 0.6, "Error"),
	zone = def(CHIMES_A, 0.6, 0.8, 0.8, "Nueva zona"),
	-- Kept for compatibility with older keys used in Resources.lua.
	dig_soil = def(DIRT_HIT, 0.45, 1.0, 1.15, "(alias) golpe en tierra"),
	dig_rock = def(ROCK_HIT, 0.55, 0.9, 1.1, "(alias) golpe en roca"),
	dig_ore = def(METAL_HIT, 0.3, 1.2, 1.35, "(alias) golpe en mineral"),
	dig_crystal = def(CLINK, 0.22, 1.6, 1.8, "(alias) golpe en cristal"),
}

return Sounds
