--!strict
-- Art direction per zone: how each layer of the world LOOKS underground. Lighting colour and fog
-- come from Config/Zones (`lighting`); this adds colour grading, bloom, atmosphere and the particles
-- that float in the air. Util/ZoneLook blends neighbouring zones and darkens each zone with depth.
--
-- Direction (docs/ART_DIRECTION.md):
--   Garden   warm earth, soft light, a little dust: still close to the sun
--   Mines    sepia and lantern orange, heavy brown dust: somebody worked here
--   Crystal  cold violet-blue, bloom on the glow, sparkles drifting up: the rock is alive
--   Caverns  gold and sand, haze, motes drifting sideways: very old, very big
--   Volcanic red-orange, hard contrast, embers rising: hostile heat
--   Abyss    teal-black, almost no light, slow bioluminescent spores: it breathes
--   Core     pale and washed out, white motes rising fast: wrong, unnatural

export type Air = {
	color: Color3,
	rate: number, -- particles per second at full quality
	size: number, -- studs
	speed: number,
	rise: number, -- vertical acceleration (negative falls)
	drift: number, -- sideways acceleration
	glow: number, -- LightEmission 0..1
	lifetime: number,
}

export type Look = {
	tint: Color3,
	saturation: number,
	contrast: number,
	brightness: number,
	bloom: number, -- intensity
	density: number, -- Atmosphere.Density
	haze: number,
	air: Air,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Visuals = {}

Visuals.Zones = {
	garden = {
		tint = rgb(255, 244, 228),
		saturation = 0.05,
		contrast = 0.05,
		brightness = 0,
		bloom = 0.2,
		density = 0.3,
		haze = 1,
		air = {
			color = rgb(170, 140, 105),
			rate = 6,
			size = 0.12,
			speed = 0.3,
			rise = -0.05,
			drift = 0.05,
			glow = 0,
			lifetime = 6,
		},
	},
	forgotten_mines = {
		tint = rgb(255, 226, 188),
		saturation = -0.15,
		contrast = 0.12,
		brightness = -0.02,
		bloom = 0.35,
		density = 0.38,
		haze = 1.6,
		air = {
			color = rgb(150, 118, 86),
			rate = 14,
			size = 0.14,
			speed = 0.2,
			rise = -0.12,
			drift = 0.04,
			glow = 0,
			lifetime = 7,
		},
	},
	crystal_caves = {
		tint = rgb(214, 220, 255),
		saturation = 0.2,
		contrast = 0.08,
		brightness = 0.01,
		bloom = 0.8,
		density = 0.32,
		haze = 1.2,
		air = {
			color = rgb(150, 180, 255),
			rate = 10,
			size = 0.1,
			speed = 0.4,
			rise = 0.08,
			drift = 0.02,
			glow = 1,
			lifetime = 5,
		},
	},
	ancient_caverns = {
		tint = rgb(255, 236, 204),
		saturation = 0,
		contrast = 0.06,
		brightness = 0.01,
		bloom = 0.4,
		density = 0.42,
		haze = 2.2,
		air = {
			color = rgb(215, 186, 130),
			rate = 12,
			size = 0.11,
			speed = 0.5,
			rise = -0.02,
			drift = 0.25,
			glow = 0,
			lifetime = 6,
		},
	},
	volcanic_depths = {
		tint = rgb(255, 214, 190),
		saturation = 0.12,
		contrast = 0.18,
		brightness = 0,
		bloom = 0.7,
		density = 0.4,
		haze = 1.8,
		air = {
			color = rgb(255, 130, 50),
			rate = 12,
			size = 0.13,
			speed = 1.2,
			rise = 0.9,
			drift = 0.1,
			glow = 1,
			lifetime = 3.5,
		},
	},
	abyss = {
		tint = rgb(200, 236, 236),
		saturation = -0.1,
		contrast = 0.15,
		brightness = -0.03,
		bloom = 0.9,
		density = 0.5,
		haze = 2.6,
		air = {
			color = rgb(60, 255, 215),
			rate = 8,
			size = 0.16,
			speed = 0.15,
			rise = 0.03,
			drift = 0.03,
			glow = 1,
			lifetime = 8,
		},
	},
	unknown_core = {
		tint = rgb(236, 250, 255),
		saturation = -0.35,
		contrast = -0.05,
		brightness = 0.05,
		bloom = 1,
		density = 0.36,
		haze = 3,
		air = {
			color = rgb(235, 255, 255),
			rate = 16,
			size = 0.09,
			speed = 2,
			rise = 1.6,
			drift = 0,
			glow = 1,
			lifetime = 2.5,
		},
	},
} :: { [string]: Look }

-- How much darker and closer the fog gets from the top of a zone to its bottom.
Visuals.DepthDarkening = 0.22 -- ambient multiplier at the bottom: 1 - this
Visuals.DepthFogClosing = 0.3 -- fogEnd multiplier at the bottom: 1 - this
Visuals.BlendMeters = 6 -- each side of a zone boundary

-- Graphics quality (Roblox SavedQualityLevel 1..10) to effect scale.
function Visuals.qualityScale(level: number): number
	if level <= 0 then
		return 0.7 -- automatic
	elseif level <= 3 then
		return 0.3
	elseif level <= 6 then
		return 0.65
	end
	return 1
end

return Visuals
