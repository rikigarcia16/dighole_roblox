--!strict
-- Hit feedback: arm swings, terrain debris, dust/sparkle particles and positional sounds.
-- Everything is pooled and capped so hundreds of hits never allocate new instances.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EffectsController = {}

local localPlayer = Players.LocalPlayer
local DEBRIS_POOL = 48
local EMITTER_POOL = 8
local SOUND_POOL = 12
local GRAVITY = Vector3.new(0, -60, 0)

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalEffects"

-- Swings ---------------------------------------------------------------------------------------
type Swing = { motor: Motor6D, start: number, duration: number, kind: string }
local swings: { [Motor6D]: Swing } = {}

local function shoulderOf(character: Model): Motor6D?
	local upperArm = character:FindFirstChild("RightUpperArm")
	local motor = upperArm and upperArm:FindFirstChild("RightShoulder")
	if not motor then
		local torso = character:FindFirstChild("Torso")
		motor = torso and torso:FindFirstChild("Right Shoulder")
	end
	return if motor and motor:IsA("Motor6D") then motor :: Motor6D else nil
end

function EffectsController.swing(character: Model?, animation: string)
	if not character then
		return
	end
	local motor = shoulderOf(character)
	if not motor then
		return
	end
	local duration = if animation == "drill" then 0.14 elseif animation == "chop" then 0.3 else 0.26
	swings[motor] = { motor = motor, start = os.clock(), duration = duration, kind = animation }
end

local function swingOffset(kind: string, t: number): CFrame
	if kind == "drill" then
		-- short shake instead of a swing
		local shake = math.sin(t * math.pi * 6) * math.rad(3)
		return CFrame.Angles(shake, 0, shake * 0.5)
	end
	-- wind up (raise the arm), then strike down slightly past the rest pose and settle back
	local amplitude = if kind == "chop" then 95 else 70
	local angle
	if t < 0.35 then
		angle = amplitude * math.sin(t / 0.35 * math.pi / 2)
	else
		local u = (t - 0.35) / 0.65
		angle = amplitude * (1 - u) - amplitude * 0.6 * math.sin(u * math.pi)
	end
	return CFrame.Angles(math.rad(angle), 0, 0)
end

-- Debris ---------------------------------------------------------------------------------------
type Debris = { part: BasePart, velocity: Vector3, spin: CFrame, ends: number, active: boolean }
local debris: { Debris } = {}
local debrisCursor = 1

local function makeDebrisPool()
	for i = 1, DEBRIS_POOL do
		local p = Instance.new("Part")
		p.Name = "Debris"
		p.Size = Vector3.new(0.6, 0.6, 0.6)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Parent = fxFolder
		debris[i] = { part = p, velocity = Vector3.zero, spin = CFrame.identity, ends = 0, active = false }
	end
end

local function spawnDebris(position: Vector3, resource: Resources.Resource, count: number)
	for _ = 1, count do
		local d = debris[debrisCursor]
		debrisCursor = debrisCursor % DEBRIS_POOL + 1
		local size = 0.35 + math.random() * 0.5
		d.part.Size = Vector3.new(size, size, size)
		d.part.Color = resource.color
		d.part.Material = if resource.isOre then Enum.Material.SmoothPlastic else Enum.Material.Slate
		d.part.Transparency = 0
		d.part.CFrame =
			CFrame.new(position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2)
		d.velocity = Vector3.new((math.random() - 0.5) * 18, 10 + math.random() * 12, (math.random() - 0.5) * 18)
		d.spin = CFrame.Angles(math.random() * 0.3, math.random() * 0.3, math.random() * 0.3)
		d.ends = os.clock() + 0.55 + math.random() * 0.3
		d.active = true
	end
end

-- Particles ------------------------------------------------------------------------------------
type Emitter = { part: BasePart, dust: ParticleEmitter, sparkle: ParticleEmitter, light: PointLight }
local emitters: { Emitter } = {}
local emitterCursor = 1

local function makeEmitterPool()
	for i = 1, EMITTER_POOL do
		local p = Instance.new("Part")
		p.Name = "Emitter"
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = fxFolder

		local dust = Instance.new("ParticleEmitter")
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Enabled = false
		dust.Lifetime = NumberRange.new(0.35, 0.7)
		dust.Speed = NumberRange.new(4, 9)
		dust.SpreadAngle = Vector2.new(180, 180)
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
		dust.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		dust.Acceleration = Vector3.new(0, -6, 0)
		dust.Drag = 3
		dust.LightInfluence = 1
		dust.Parent = p

		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Enabled = false
		sparkle.Lifetime = NumberRange.new(0.6, 1.2)
		sparkle.Speed = NumberRange.new(6, 16)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		sparkle.LightEmission = 1
		sparkle.Drag = 2
		sparkle.Parent = p

		local light = Instance.new("PointLight")
		light.Brightness = 0
		light.Range = 14
		light.Parent = p

		emitters[i] = { part = p, dust = dust, sparkle = sparkle, light = light }
	end
end

local function nextEmitter(position: Vector3): Emitter
	local e = emitters[emitterCursor]
	emitterCursor = emitterCursor % EMITTER_POOL + 1
	e.part.Position = position
	return e
end

-- Sounds ---------------------------------------------------------------------------------------
local soundParts: { { part: BasePart, sound: Sound } } = {}
local soundCursor = 1

local function makeSoundPool()
	for i = 1, SOUND_POOL do
		local p = Instance.new("Part")
		p.Name = "SoundSource"
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = fxFolder
		local s = Instance.new("Sound")
		s.RollOffMaxDistance = 120
		s.RollOffMinDistance = 8
		s.Parent = p
		soundParts[i] = { part = p, sound = s }
	end
end

function EffectsController.playAt(soundKey: string, position: Vector3)
	local def = Sounds[soundKey]
	if not def then
		return
	end
	local entry = soundParts[soundCursor]
	soundCursor = soundCursor % SOUND_POOL + 1
	entry.part.Position = position
	entry.sound.SoundId = def.id
	entry.sound.Volume = def.volume
	entry.sound.PlaybackSpeed = def.pitchMin + math.random() * (def.pitchMax - def.pitchMin)
	entry.sound:Play()
end

local uiSounds: { [string]: Sound } = {}
function EffectsController.playUi(soundKey: string)
	local def = Sounds[soundKey]
	if not def then
		return
	end
	local sound = uiSounds[soundKey]
	if not sound then
		local s = Instance.new("Sound")
		s.SoundId = def.id
		s.Volume = def.volume
		s.Parent = SoundService
		uiSounds[soundKey] = s
		sound = s
	end
	sound.PlaybackSpeed = def.pitchMin + math.random() * (def.pitchMax - def.pitchMin)
	SoundService:PlayLocalSound(sound)
end

-- Public effects ---------------------------------------------------------------------------------
function EffectsController.hit(position: Vector3, resourceId: string, broke: boolean)
	local resource = Resources.get(resourceId)
	if not resource then
		return
	end
	local e = nextEmitter(position)
	e.dust.Color = ColorSequence.new(resource.color)
	e.dust:Emit(if broke then 10 else 5)
	if resource.isOre then
		e.sparkle.Color = ColorSequence.new(resource.color)
		e.sparkle:Emit(if broke then 6 else 2)
	end
	spawnDebris(position, resource, if broke then 6 else 2)
	EffectsController.playAt(resource.sound, position)
end

function EffectsController.discovery(position: Vector3, resourceId: string)
	local resource = Resources.get(resourceId)
	if not resource then
		return
	end
	local e = nextEmitter(position)
	e.sparkle.Color = ColorSequence.new(resource.color, Color3.new(1, 1, 1))
	e.sparkle:Emit(40)
	e.light.Color = resource.color
	e.light.Brightness = 4
	TweenService
		:Create(e.light, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
		:Play()
	EffectsController.playAt(resource.sound, position)
end

function EffectsController.start()
	fxFolder.Parent = workspace
	makeDebrisPool()
	makeEmitterPool()
	makeSoundPool()

	RunService.Stepped:Connect(function()
		local now = os.clock()
		for motor, s in swings do
			local t = (now - s.start) / s.duration
			if t >= 1 or not motor.Parent then
				swings[motor] = nil
			else
				motor.Transform = motor.Transform * swingOffset(s.kind, t)
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, d in debris do
			if d.active then
				if now >= d.ends then
					d.active = false
					d.part.Transparency = 1
				else
					d.velocity += GRAVITY * dt
					d.part.CFrame = (d.part.CFrame + d.velocity * dt) * d.spin
					local remaining = d.ends - now
					if remaining < 0.2 then
						d.part.Transparency = 1 - remaining / 0.2
					end
				end
			end
		end
	end)

	Remotes.event("DigFx").OnClientEvent:Connect(
		function(player: Player, position: Vector3, resourceId: string, broke: boolean, toolId: string, bestId: string?)
			if player ~= localPlayer then
				local tool = Tools.get(toolId)
				EffectsController.swing(player.Character, tool and tool.animation or "swing")
			end
			EffectsController.hit(position, resourceId, broke)
			if bestId then
				EffectsController.discovery(position, bestId)
			end
		end
	)
end

return EffectsController
