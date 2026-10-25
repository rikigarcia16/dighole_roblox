--!strict
-- "El fondo" on the client: on the way down through the Core, both rhythms are heard at once, the
-- Counter's three knocks and E.'s three deeper hammer blows. Far away they are out of step; the
-- closer you get, the closer together they fall, until at the room they strike as one. Once the
-- player's number is engraved on the wall, both stop. Presentational only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local CoreController = {}

local player = Players.LocalPlayer

local RHYTHM_PERIOD = 3.1
local BLOW_TIMES = { 0, 0.5, 1.0 }
local MAX_OFFSET = 1.4 -- seconds between the two rhythms when first heard
local HEAR_DISTANCE = 1500 -- studs (~375 m): from about 1 780 m

type Voice = { sound: Sound, eq: EqualizerSoundEffect, last: number }
type Core = { model: Model, emitter: BasePart, knock: Voice, hammer: Voice }

local cores: { [Model]: Core } = {}

local function voice(emitter: BasePart, pitch: number, volume: number): Voice
	local def = Sounds.counter_knock
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = def.volume * volume
	sound.PlaybackSpeed = def.pitchMin * pitch
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 30
	sound.RollOffMaxDistance = HEAR_DISTANCE
	sound.Parent = emitter
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Parent = sound
	return { sound = sound, eq = eq, last = 0 }
end

local function track(model: Model)
	if cores[model] then
		return
	end
	local emitter = model:WaitForChild("Emitter", 10) :: BasePart?
	if not emitter then
		return
	end
	cores[model] = {
		model = model,
		emitter = emitter,
		knock = voice(emitter, 1, 0.9), -- the machine
		hammer = voice(emitter, 0.8, 0.85), -- E.'s hammer, deeper
	}
	model.Destroying:Connect(function()
		cores[model] = nil
	end)
end

local function strike(v: Voice, phase: number, dt: number, now: number, closeness: number)
	v.eq.HighGain = -42 + 20 * closeness
	v.eq.MidGain = -16 + 10 * closeness
	v.eq.LowGain = 5
	for _, t in BLOW_TIMES do
		if phase >= t and phase - dt < t and now - v.last > 0.2 then
			v.last = now
			v.sound:Play()
		end
	end
end

local function update(core: Core, dt: number, now: number, rootPosition: Vector3)
	if core.model:GetAttribute("Engraved") == true then
		return -- both stopped at once
	end
	local distance = (core.emitter.Position - rootPosition).Magnitude
	if distance > HEAR_DISTANCE then
		return
	end
	local closeness = math.clamp(1 - distance / HEAR_DISTANCE, 0, 1)
	local offset = MAX_OFFSET * (1 - closeness)
	strike(core.knock, now % RHYTHM_PERIOD, dt, now, closeness)
	strike(core.hammer, (now - offset) % RHYTHM_PERIOD, dt, now, closeness)
end

function CoreController.start()
	for _, model in CollectionService:GetTagged("THNE_Core") do
		if model:IsA("Model") then
			task.spawn(track, model)
		end
	end
	CollectionService:GetInstanceAddedSignal("THNE_Core"):Connect(function(model)
		if model:IsA("Model") then
			task.spawn(track, model)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local now = os.clock()
		for _, core in cores do
			if core.model.Parent then
				update(core, dt, now, root.Position)
			end
		end
	end)
end

return CoreController
