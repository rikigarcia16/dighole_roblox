--!strict
-- Audiovisual response of digging, per material family (Resources `effect`) and per tool animation.
-- Pure data: EffectsController reads it, tests check it is complete.
--
-- A hit should be readable but discreet (it repeats hundreds of times); a break is fuller; rare
-- discoveries escalate by rarity. Nothing here changes gameplay.

export type Preset = {
	hitSound: string,
	breakSound: string,
	dust: number, -- particles per hit
	breakDust: number,
	debris: number, -- fragments per break
	debrisSize: number,
	debrisMaterial: Enum.Material,
	sparkle: boolean, -- glints on every hit (ores and crystals)
}

export type Timing = {
	duration: number, -- seconds of the swing animation
	impact: number, -- fraction of the swing when the tool hits (request + hit sound are sent then)
}

local M = Enum.Material

local DigFeel = {}

DigFeel.Presets = {
	soil = {
		hitSound = "hit_soil",
		breakSound = "break_soil",
		dust = 6,
		breakDust = 12,
		debris = 4,
		debrisSize = 0.5,
		debrisMaterial = M.Ground,
		sparkle = false,
	},
	rock = {
		hitSound = "hit_rock",
		breakSound = "break_rock",
		dust = 4,
		breakDust = 10,
		debris = 6,
		debrisSize = 0.55,
		debrisMaterial = M.Slate,
		sparkle = false,
	},
	ore = {
		hitSound = "hit_ore",
		breakSound = "break_ore",
		dust = 3,
		breakDust = 8,
		debris = 6,
		debrisSize = 0.45,
		debrisMaterial = M.Slate,
		sparkle = true,
	},
	shine = {
		hitSound = "hit_ore",
		breakSound = "break_ore",
		dust = 3,
		breakDust = 8,
		debris = 5,
		debrisSize = 0.4,
		debrisMaterial = M.Metal,
		sparkle = true,
	},
	crystal = {
		hitSound = "hit_crystal",
		breakSound = "break_crystal",
		dust = 2,
		breakDust = 6,
		debris = 7,
		debrisSize = 0.4,
		debrisMaterial = M.Glass,
		sparkle = true,
	},
	lava = {
		hitSound = "hit_lava",
		breakSound = "break_rock",
		dust = 4,
		breakDust = 10,
		debris = 6,
		debrisSize = 0.5,
		debrisMaterial = M.Basalt,
		sparkle = true,
	},
	abyss = {
		hitSound = "hit_dense",
		breakSound = "break_rock",
		dust = 3,
		breakDust = 9,
		debris = 6,
		debrisSize = 0.5,
		debrisMaterial = M.Slate,
		sparkle = true,
	},
	core = {
		hitSound = "hit_dense",
		breakSound = "break_crystal",
		dust = 3,
		breakDust = 9,
		debris = 6,
		debrisSize = 0.45,
		debrisMaterial = M.Glass,
		sparkle = true,
	},
} :: { [string]: Preset }

DigFeel.DefaultPreset = "rock"

DigFeel.Timing = {
	swing = { duration = 0.26, impact = 0.35 },
	chop = { duration = 0.3, impact = 0.38 },
	drill = { duration = 0.14, impact = 0 },
} :: { [string]: Timing }

-- Highest number of segments drawn on the hardness bar (more hits than this show a percentage).
DigFeel.MaxHardnessSegments = 10

-- Hits needed to break a cell of `hardness` with `power`, given damage already dealt.
function DigFeel.hitsLeft(hardness: number, power: number, damage: number): number
	if power <= 0 then
		return math.huge
	end
	return math.max(0, math.ceil((hardness - damage) / power))
end

return DigFeel
