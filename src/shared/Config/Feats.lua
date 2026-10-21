--!strict
-- Feats: optional challenges nobody asks for. They are not a task list: none is shown until the
-- journal hints at it (Config/Journal, after something related has happened), and each one is
-- earned once and gives a lasting, useful edge instead of coins.
--
-- All of them happen inside one DESCENT: from the moment the player leaves the surface until they
-- are back at it (Logic/Descent). A lift ride, the beacon or a respawn makes the descent "assisted".
--
--   three_geodes   open `geodes` geodes in one descent          -> detector recharges faster
--   bare_descent   reach `depth` m from the surface, no lift    -> carry more ropes
--   unaided_climb  climb from `depth` m back to the surface, no lift or beacon, with the
--                  backpack at least `fill` full                -> the beacon costs less

export type Feat = {
	id: string,
	name: string,
	reward: string, -- shown when earned and in the journal
}

local Feats = {}

Feats.List = {
	{ id = "three_geodes", name = "Tres geodas en una bajada", reward = "El detector se recarga más rápido." },
	{ id = "bare_descent", name = "A pulso", reward = "Puedes llevar dos cuerdas más." },
	{ id = "unaided_climb", name = "La subida", reward = "La baliza te cuesta la mitad." },
} :: { Feat }

Feats.ById = {} :: { [string]: Feat }
for _, feat in Feats.List do
	Feats.ById[feat.id] = feat
end

-- E.'s bets, chalked on a slate at each camp in the Mines (CaveScenes), the same as in the journal.
Feats.Chalk = {
	"Tres geodas sin ver el cielo",
	"Hasta las Cavernas sin montacargas",
	"Del Cristal al cielo, cargado y sin baliza",
}

Feats.Geodes = 3
Feats.BareDescentDepth = 350 -- metres: the Ancient Caverns
Feats.ClimbDepth = 150 -- metres: below the Mines
Feats.ClimbFill = 0.8 -- fraction of the backpack

-- A descent starts when the player is deeper than this and ends back above it (metres).
Feats.SurfaceDepth = 2

-- Rewards (pure: server and client read the same numbers).
Feats.DetectorCooldownFactor = 0.6
Feats.ExtraRopes = 2
Feats.RescueCostFactor = 0.5

local function has(feats: { [string]: boolean }?, id: string): boolean
	return feats ~= nil and feats[id] == true
end
Feats.has = has

function Feats.ropeCapacity(base: number, feats: { [string]: boolean }?): number
	return base + (if has(feats, "bare_descent") then Feats.ExtraRopes else 0)
end

function Feats.detectorCooldown(base: number, feats: { [string]: boolean }?): number
	return base * (if has(feats, "three_geodes") then Feats.DetectorCooldownFactor else 1)
end

function Feats.rescueCostFactor(feats: { [string]: boolean }?): number
	return if has(feats, "unaided_climb") then Feats.RescueCostFactor else 1
end

return Feats
