--!strict
-- E.'s workshop on the client: the deep rhythm heard through the rock from the Crystal Caves down
-- (the Counter's journal already says "the rhythm is heard again, deeper, from much further down").
-- Three blows and a pause, lower and slower than the Counter: a hammer on the bench. Always muffled,
-- clearer as you get closer; once the room is open the hammer is still. Presentational only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local WorkshopController = {}

local player = Players.LocalPlayer

local RHYTHM_PERIOD = 3.1
local BLOW_TIMES = { 0, 0.55, 1.1 }
local HEAR_DISTANCE = 520 -- studs (~130 m): from the bottom of the Crystal Caves

type Workshop = { model: Model, emitter: BasePart, blow: Sound, eq: EqualizerSoundEffect, last: number }

local workshops: { [Model]: Workshop } = {}

local function track(model: Model)
	if workshops[model] then
		return
	end
	local emitter = model:WaitForChild("Emitter", 10) :: BasePart?
	if not emitter then
		return
	end
	local def = Sounds.counter_knock
	local blow = Instance.new("Sound")
	blow.SoundId = def.id
	blow.Volume = def.volume * 0.85
	blow.PlaybackSpeed = def.pitchMin * 0.8 -- deeper than the Counter
	blow.RollOffMode = Enum.RollOffMode.InverseTapered
	blow.RollOffMinDistance = 24
	blow.RollOffMaxDistance = HEAR_DISTANCE
	blow.Parent = emitter
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Parent = blow
	workshops[model] = { model = model, emitter = emitter, blow = blow, eq = eq, last = 0 }
	model.Destroying:Connect(function()
		workshops[model] = nil
	end)
end

local function update(w: Workshop, dt: number, now: number, rootPosition: Vector3)
	if w.model:GetAttribute("Revealed") == true then
		return -- the hammer is still
	end
	local distance = (w.emitter.Position - rootPosition).Magnitude
	if distance > HEAR_DISTANCE then
		return
	end
	local closeness = math.clamp(1 - distance / HEAR_DISTANCE, 0, 1)
	-- always through rock: muffled far away, a little clearer at the door
	w.eq.HighGain = -42 + 18 * closeness
	w.eq.MidGain = -16 + 8 * closeness
	w.eq.LowGain = 5
	local phase = now % RHYTHM_PERIOD
	for _, t in BLOW_TIMES do
		if phase >= t and phase - dt < t and now - w.last > 0.2 then
			w.last = now
			w.blow:Play()
		end
	end
end

function WorkshopController.start()
	for _, model in CollectionService:GetTagged("THNE_Workshop") do
		if model:IsA("Model") then
			task.spawn(track, model)
		end
	end
	CollectionService:GetInstanceAddedSignal("THNE_Workshop"):Connect(function(model)
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
		for _, w in workshops do
			if w.model.Parent then
				update(w, dt, now, root.Position)
			end
		end
	end)
end

return WorkshopController
