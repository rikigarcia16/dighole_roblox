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

local Sounds: { [string]: SoundDef } = {
	-- Hits (every swing that lands): short and quiet, they repeat hundreds of times.
	hit_soil = def(THUD, 0.55, 0.5, 0.62, "Golpe en tierra / césped"),
	hit_rock = def(COLLIDE, 0.45, 0.72, 0.86, "Golpe en roca"),
	hit_ore = def(COLLIDE, 0.5, 1.1, 1.25, "Golpe en mineral (metálico)"),
	hit_crystal = def(PING, 0.22, 1.7, 2.0, "Golpe en cristal (tintineo)"),
	hit_lava = def(COLLIDE, 0.45, 0.55, 0.65, "Golpe en basalto / obsidiana"),
	hit_dense = def(COLLIDE, 0.5, 0.45, 0.55, "Golpe en roca abisal / núcleo (grave)"),
	-- Breaks (the cell gives way): lower and fuller than the hit.
	break_soil = def(THUD, 0.8, 0.38, 0.45, "Rotura de tierra"),
	break_rock = def(COLLIDE, 0.7, 0.5, 0.6, "Rotura de roca"),
	break_ore = def(COLLIDE, 0.75, 0.85, 0.95, "Rotura de veta de mineral"),
	break_crystal = def(PING, 0.4, 1.2, 1.35, "Rotura de cristal"),
	-- Tool swings.
	swing_light = def(CLICK, 0.08, 0.45, 0.55, "Movimiento de pala (provisional: falta audio propio)"),
	swing_heavy = def(CLICK, 0.1, 0.32, 0.4, "Movimiento de pico (provisional: falta audio propio)"),
	drill = def(CLICK, 0.3, 0.7, 0.8, "Taladro"),
	plasma = def(PING, 0.2, 2.0, 2.3, "Excavador de plasma"),
	too_hard = def(COLLIDE, 0.5, 1.6, 1.7, "Rebote: material demasiado duro"),
	-- Discoveries, by rarity: each tier must be clearly distinct from ordinary hits.
	discover_rare = def(PING, 0.5, 1.0, 1.0, "Descubrimiento raro"),
	discover_epic = def(PING, 0.65, 0.8, 0.8, "Descubrimiento épico"),
	discover_legendary = def(PING, 0.85, 0.6, 0.6, "Descubrimiento legendario"),
	geode_open = def(PING, 0.6, 1.35, 1.35, "Apertura de geoda"),
	fossil_extract = def(THUD, 0.7, 0.8, 0.8, "Extracción de fósil"),
	cave_open = def(SPLASH, 0.35, 0.5, 0.5, "Abrir una cueva (eco de aire)"),
	-- The Counter. NEEDS ORIGINAL AUDIO: a deep three-knock rhythm and a low hum are its identity;
	-- these built-in placeholders only make the timing testable.
	counter_knock = def(COLLIDE, 0.9, 0.32, 0.36, "El Contador: golpe del ritmo (placeholder)"),
	counter_lock = def(PING, 0.5, 0.55, 0.55, "El Contador: un anillo encaja"),
	counter_hum = def(CLICK, 0.12, 0.22, 0.22, "El Contador: zumbido de la sala (placeholder, en bucle)"),
	counter_found = def(SPLASH, 0.5, 0.35, 0.35, "Entrar en la sala del Contador"),
	-- UI.
	pickup = def(PING, 0.18, 1.8, 2.0, "Recoger mineral"),
	sell = def(PING, 0.5, 1.3, 1.3, "Venta"),
	purchase = def(PING, 0.5, 1.6, 1.6, "Compra"),
	ui_click = def(BUTTON, 0.4, 1, 1, "Botón"),
	error = def(BUTTON, 0.4, 0.6, 0.6, "Error"),
	zone = def(PING, 0.6, 0.5, 0.5, "Nueva zona"),
	-- Kept for compatibility with older keys used in Resources.lua.
	dig_soil = def(THUD, 0.55, 0.5, 0.62, "(alias) golpe en tierra"),
	dig_rock = def(COLLIDE, 0.45, 0.72, 0.86, "(alias) golpe en roca"),
	dig_ore = def(COLLIDE, 0.5, 1.1, 1.25, "(alias) golpe en mineral"),
	dig_crystal = def(PING, 0.22, 1.7, 2.0, "(alias) golpe en cristal"),
}

return Sounds
