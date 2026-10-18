--!strict
-- Depth-driven ambience: the look of each layer (Util/ZoneLook: lighting, fog, colour grading, bloom,
-- atmosphere and floating particles), the player's head lamp and zone banners.
--
-- Everything changes gradually: every tick the current values move a fraction towards the look at
-- the player's depth, so walking down a shaft slides from one palette to the next. The floating
-- particles come from one emitter that follows the camera and scale with the graphics quality.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Visuals = require(ReplicatedStorage.Shared.Config.Visuals)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ZoneLook = require(ReplicatedStorage.Shared.Util.ZoneLook)

local AmbienceController = {}
AmbienceController.depthChanged = Signal.new() -- (depthMeters, zone)
AmbienceController.zoneChanged = Signal.new() -- (zone)

local player = Players.LocalPlayer
local UNDERGROUND_DEPTH = 3
local TICK = 0.2
local EASE = 0.18 -- fraction of the remaining difference applied per tick

-- Surface: a clear afternoon. Captured from the place, with a warm grade on top.
local surface = {
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	FogColor = Lighting.FogColor,
	FogEnd = Lighting.FogEnd,
	tint = Color3.fromRGB(255, 250, 240),
	saturation = 0.08,
	contrast = 0.04,
	brightness = 0,
	bloom = 0.25,
	density = 0.28,
	haze = 1.2,
}

-- Effect overrides set by the settings menu (UIController): 0..1, nil = follow graphics quality.
local effectsOverride: number? = nil
function AmbienceController.setEffectsScale(scale: number?)
	effectsOverride = scale
end

function AmbienceController.effectsScale(): number
	if effectsOverride then
		return effectsOverride
	end
	local ok, level = pcall(function()
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	return Visuals.qualityScale(if ok and type(level) == "number" then level else 0)
end

local lamp: PointLight? = nil
local function ensureLamp(): PointLight?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return nil
	end
	if lamp and lamp.Parent == head then
		return lamp
	end
	local light = Instance.new("PointLight")
	light.Name = "HeadLamp"
	light.Range = 26
	light.Brightness = 0
	light.Color = Color3.fromRGB(255, 236, 200)
	light.Shadows = false
	light.Parent = head
	lamp = light
	return light
end

local function getOrCreate<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return (existing :: any) :: T
	end
	local created = Instance.new(className :: any)
	created.Name = name
	created.Parent = Lighting
	return (created :: any) :: T
end

local function ease(a: number, b: number): number
	return a + (b - a) * EASE
end

local function easeColor(a: Color3, b: Color3): Color3
	return a:Lerp(b, EASE)
end

-- Floating particles ------------------------------------------------------------------------------

local airPart: Part? = nil
local airEmitter: ParticleEmitter? = nil

local function ensureAir(): (Part, ParticleEmitter)
	if airPart and airEmitter and airPart.Parent then
		return airPart, airEmitter
	end
	local p = Instance.new("Part")
	p.Name = "THNE_Air"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(44, 22, 44) -- particles spawn anywhere in this box around the camera
	p.Parent = workspace.CurrentCamera or workspace
	local e = Instance.new("ParticleEmitter")
	e.Name = "Air"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 0
	e.LockedToPart = false
	e.SpreadAngle = Vector2.new(180, 180)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.35),
		NumberSequenceKeypoint.new(0.75, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = p
	airPart, airEmitter = p, e
	return p, e
end

local function applyAir(air: Visuals.Air?, scale: number)
	local p, e = ensureAir()
	local camera = workspace.CurrentCamera
	if camera then
		p.CFrame = CFrame.new(camera.Focus.Position)
	end
	if not air or scale <= 0 then
		e.Rate = 0
		return
	end
	e.Rate = air.rate * scale
	e.Color = ColorSequence.new(air.color)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, air.size * 0.6),
		NumberSequenceKeypoint.new(0.5, air.size),
		NumberSequenceKeypoint.new(1, air.size * 0.7),
	})
	e.Speed = NumberRange.new(air.speed * 0.5, air.speed)
	e.Acceleration = Vector3.new(air.drift, air.rise, air.drift * 0.6)
	e.LightEmission = air.glow
	e.LightInfluence = 1 - air.glow
	e.Lifetime = NumberRange.new(air.lifetime * 0.7, air.lifetime)
end

-- Main loop ---------------------------------------------------------------------------------------

local currentZoneId = ""
local wasUnderground = false

local function step(depth: number, grade: ColorCorrectionEffect, bloom: BloomEffect, atmosphere: Atmosphere)
	local underground = depth > UNDERGROUND_DEPTH
	local scale = AmbienceController.effectsScale()
	if underground then
		local look = ZoneLook.at(depth)
		Lighting.Ambient = easeColor(Lighting.Ambient, look.ambient)
		Lighting.OutdoorAmbient = easeColor(Lighting.OutdoorAmbient, look.ambient)
		Lighting.FogColor = easeColor(Lighting.FogColor, look.fogColor)
		Lighting.FogEnd = ease(Lighting.FogEnd, look.fogEnd)
		grade.TintColor = easeColor(grade.TintColor, look.tint)
		grade.Saturation = ease(grade.Saturation, look.saturation)
		grade.Contrast = ease(grade.Contrast, look.contrast)
		grade.Brightness = ease(grade.Brightness, look.brightness)
		bloom.Intensity = ease(bloom.Intensity, look.bloom * math.max(scale, 0.4))
		atmosphere.Density = ease(atmosphere.Density, look.density)
		atmosphere.Haze = ease(atmosphere.Haze, look.haze)
		atmosphere.Color = easeColor(atmosphere.Color, look.fogColor)
		atmosphere.Decay = easeColor(atmosphere.Decay, look.fogColor)
		applyAir(look.air, scale)
	else
		Lighting.Ambient = easeColor(Lighting.Ambient, surface.Ambient)
		Lighting.OutdoorAmbient = easeColor(Lighting.OutdoorAmbient, surface.OutdoorAmbient)
		Lighting.FogColor = easeColor(Lighting.FogColor, surface.FogColor)
		Lighting.FogEnd = ease(Lighting.FogEnd, surface.FogEnd)
		grade.TintColor = easeColor(grade.TintColor, surface.tint)
		grade.Saturation = ease(grade.Saturation, surface.saturation)
		grade.Contrast = ease(grade.Contrast, surface.contrast)
		grade.Brightness = ease(grade.Brightness, surface.brightness)
		bloom.Intensity = ease(bloom.Intensity, surface.bloom)
		atmosphere.Density = ease(atmosphere.Density, surface.density)
		atmosphere.Haze = ease(atmosphere.Haze, surface.haze)
		atmosphere.Color = easeColor(atmosphere.Color, Color3.fromRGB(199, 214, 230))
		atmosphere.Decay = easeColor(atmosphere.Decay, Color3.fromRGB(120, 140, 170))
		applyAir(nil, scale)
	end

	local zone = Zones.at(depth)
	if underground ~= wasUnderground or zone.id ~= currentZoneId then
		local light = ensureLamp()
		if light then
			local brightness = if underground then math.max(zone.lighting.lampBrightness, 0.8) else 0
			TweenService:Create(light, TweenInfo.new(1), { Brightness = brightness }):Play()
		end
		if zone.id ~= currentZoneId then
			AmbienceController.zoneChanged:Fire(zone)
		end
		currentZoneId = zone.id
		wasUnderground = underground
	end
end

function AmbienceController.start()
	local atmosphere = getOrCreate("Atmosphere", "THNE_Atmosphere") :: Atmosphere
	for _, other in Lighting:GetChildren() do
		if other:IsA("Atmosphere") and other ~= (atmosphere :: Instance) then
			other:Destroy() -- only one Atmosphere is used by the engine
		end
	end
	atmosphere.Density = surface.density
	atmosphere.Offset = 0.2
	atmosphere.Glare = 0.2
	atmosphere.Haze = surface.haze
	local grade = getOrCreate("ColorCorrectionEffect", "THNE_Grade") :: ColorCorrectionEffect
	local bloom = getOrCreate("BloomEffect", "THNE_Bloom") :: BloomEffect
	bloom.Threshold = 0.95 -- only neon (crystals, lanterns, embers) blooms
	bloom.Size = 28

	task.spawn(function()
		local lastDepth = -1
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local depth = Grid.depthMetersFromY(root.Position.Y - 3)
				if math.floor(depth) ~= lastDepth then
					lastDepth = math.floor(depth)
					AmbienceController.depthChanged:Fire(depth, Zones.at(depth))
				end
				-- respawned: the lamp belongs to the old head (destroyed or merely parented to nil)
				if lamp == nil or lamp.Parent ~= (character :: Model):FindFirstChild("Head") then
					wasUnderground = not (depth > UNDERGROUND_DEPTH) -- respawned: force the lamp update
				end
				step(depth, grade, bloom, atmosphere)
			end
			task.wait(TICK)
		end
	end)
end

return AmbienceController
