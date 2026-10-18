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

-- How each tool FEELS when it lands, so an upgrade is noticed on the very next hit:
--   weight : scales dust and fragments and lowers the pitch (heavier tools sound deeper)
--   spark  : colour of the glints the tool itself throws (nil = none: wooden/rusty tools)
--   shake  : camera punch in degrees for the local player (0 = none); kept small
--   glow   : the hit point flashes in the spark colour (energy tools)
export type ToolFeel = { weight: number, spark: Color3?, shake: number, glow: boolean }

local STEEL = Color3.fromRGB(255, 236, 190)
local HOT = Color3.fromRGB(255, 150, 60)
DigFeel.ToolFeel = {
	rusty_shovel = { weight = 0.7, spark = nil, shake = 0, glow = false },
	reinforced_shovel = { weight = 0.85, spark = nil, shake = 0.15, glow = false },
	steel_shovel = { weight = 1, spark = STEEL, shake = 0.2, glow = false },
	miner_pick = { weight = 1.15, spark = STEEL, shake = 0.3, glow = false },
	industrial_pick = { weight = 1.3, spark = STEEL, shake = 0.4, glow = false },
	portable_drill = { weight = 1.35, spark = HOT, shake = 0.25, glow = false },
	advanced_drill = { weight = 1.45, spark = HOT, shake = 0.3, glow = false },
	plasma_digger = { weight = 1.5, spark = Color3.fromRGB(110, 230, 255), shake = 0.3, glow = true },
	abyss_borer = { weight = 1.6, spark = Color3.fromRGB(60, 255, 215), shake = 0.45, glow = true },
	ancestral_tool = { weight = 1.75, spark = Color3.fromRGB(235, 250, 255), shake = 0.5, glow = true },
} :: { [string]: ToolFeel }
DigFeel.DefaultToolFeel = { weight = 1, spark = nil, shake = 0, glow = false } :: ToolFeel

function DigFeel.toolFeel(toolId: string?): ToolFeel
	return (toolId and DigFeel.ToolFeel[toolId]) or DigFeel.DefaultToolFeel
end

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
