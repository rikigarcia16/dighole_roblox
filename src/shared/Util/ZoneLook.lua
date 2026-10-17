--!strict
-- The underground look at a given depth: the zone's art direction (Config/Visuals) plus its lighting
-- (Config/Zones), darkened towards the bottom of the zone and blended with the neighbouring zone near
-- a boundary so layers change gradually instead of switching. Pure: tested offline.

local Visuals = require(script.Parent.Parent.Config.Visuals)
local Zones = require(script.Parent.Parent.Config.Zones)

local ZoneLook = {}

export type Resolved = {
	zoneId: string,
	ambient: Color3,
	fogColor: Color3,
	fogEnd: number,
	lamp: number,
	tint: Color3,
	saturation: number,
	contrast: number,
	brightness: number,
	bloom: number,
	density: number,
	haze: number,
	air: Visuals.Air,
}

local function mix(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function mixColor(a: Color3, b: Color3, t: number): Color3
	return Color3.new(mix(a.R, b.R, t), mix(a.G, b.G, t), mix(a.B, b.B, t))
end

local function scaleColor(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

-- One zone, `t` = 0 at its top and 1 at its bottom.
local function single(zone: Zones.Zone, t: number): Resolved
	local look = Visuals.Zones[zone.id] or Visuals.Zones.garden
	local dark = 1 - Visuals.DepthDarkening * t
	return {
		zoneId = zone.id,
		ambient = scaleColor(zone.lighting.ambient, dark),
		fogColor = scaleColor(zone.lighting.fogColor, dark),
		fogEnd = zone.lighting.fogEnd * (1 - Visuals.DepthFogClosing * t),
		lamp = zone.lighting.lampBrightness,
		tint = look.tint,
		saturation = look.saturation,
		contrast = look.contrast,
		brightness = look.brightness,
		bloom = look.bloom,
		density = look.density,
		haze = look.haze,
		air = look.air,
	}
end

local function blend(a: Resolved, b: Resolved, t: number): Resolved
	local air = if t < 0.5 then a.air else b.air
	return {
		zoneId = if t < 0.5 then a.zoneId else b.zoneId,
		ambient = mixColor(a.ambient, b.ambient, t),
		fogColor = mixColor(a.fogColor, b.fogColor, t),
		fogEnd = mix(a.fogEnd, b.fogEnd, t),
		lamp = mix(a.lamp, b.lamp, t),
		tint = mixColor(a.tint, b.tint, t),
		saturation = mix(a.saturation, b.saturation, t),
		contrast = mix(a.contrast, b.contrast, t),
		brightness = mix(a.brightness, b.brightness, t),
		bloom = mix(a.bloom, b.bloom, t),
		density = mix(a.density, b.density, t),
		haze = mix(a.haze, b.haze, t),
		air = {
			color = mixColor(a.air.color, b.air.color, t),
			rate = mix(a.air.rate, b.air.rate, t),
			size = mix(a.air.size, b.air.size, t),
			speed = mix(a.air.speed, b.air.speed, t),
			rise = mix(a.air.rise, b.air.rise, t),
			drift = mix(a.air.drift, b.air.drift, t),
			glow = air.glow,
			lifetime = mix(a.air.lifetime, b.air.lifetime, t),
		},
	}
end

local function zoneT(zone: Zones.Zone, depth: number): number
	local height = if zone.maxDepth == math.huge then 1000 else zone.maxDepth - zone.minDepth
	return math.clamp((depth - zone.minDepth) / height, 0, 1)
end

function ZoneLook.at(depth: number): Resolved
	local zone = Zones.at(depth)
	local here = single(zone, zoneT(zone, depth))
	local w = Visuals.BlendMeters
	local index = zone.index
	-- near the bottom: lean towards the next zone (half way exactly at the boundary)
	local nextZone = Zones.List[index + 1]
	if nextZone and zone.maxDepth - depth < w then
		local t = 0.5 * (1 - (zone.maxDepth - depth) / w)
		return blend(here, single(nextZone, 0), t)
	end
	-- near the top: lean towards the previous zone
	local previous = Zones.List[index - 1]
	if previous and depth - zone.minDepth < w then
		local t = 0.5 * (1 - (depth - zone.minDepth) / w)
		return blend(here, single(previous, 1), t)
	end
	return here
end

return ZoneLook
