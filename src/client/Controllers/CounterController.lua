--!strict
-- The Counter's presence on the client: rhythm, sound through rock, living rings, the display and
-- the reveal sequence. Purely presentational: the server owns the puzzle and the number.
--
-- Rhythm: three knocks and a pause, emitted from the machine with 3D sound. While the room is
-- sealed the knocks are muffled (low-pass) and get clearer with distance; once the player stands
-- inside an unsolved room the knocks stop ("sudden silence") and only a hum remains.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Anomalies = require(ReplicatedStorage.Shared.Config.Anomalies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local CounterController = {}
CounterController.narrative = Signal.new() -- (text) short centred line shown by UIController

local player = Players.LocalPlayer

local RHYTHM_PERIOD = 2.6
local KNOCK_TIMES = { 0, 0.42, 0.84 }
local HEAR_DISTANCE = 220 -- studs (~55 m)
local COLD = Color3.fromRGB(200, 232, 255)
local LIT = Color3.fromRGB(120, 240, 255)

type Machine = {
	model: Model,
	knock: Sound,
	hum: Sound,
	eq: EqualizerSoundEffect,
	ringBase: { [number]: CFrame },
	ringYaw: { [number]: number },
	lastKnock: number,
	sequence: boolean,
	scramble: number,
	counted: number?, -- number shown by the sequence, kept until the server confirms Solved
}

local machines: { [Model]: Machine } = {}

local function makeSound(parent: Instance, key: string, looped: boolean): Sound
	local def = Sounds[key]
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.Volume = def.volume
	s.PlaybackSpeed = (def.pitchMin + def.pitchMax) / 2
	s.Looped = looped
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 18
	s.RollOffMaxDistance = HEAR_DISTANCE
	s.Parent = parent
	return s
end

local function track(model: Model)
	if machines[model] then
		return
	end
	local emitter = model:WaitForChild("Emitter", 10) :: BasePart?
	if not emitter then
		return
	end
	local knock = makeSound(emitter, "counter_knock", false)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Parent = knock
	local hum = makeSound(emitter, "counter_hum", true)
	local machine: Machine = {
		model = model,
		knock = knock,
		hum = hum,
		eq = eq,
		ringBase = {},
		ringYaw = {},
		lastKnock = 0,
		sequence = false,
		scramble = 0,
	}
	for r = 1, Anomalies.Rings do
		local ring = model:FindFirstChild("Ring" .. r)
		if ring and ring:IsA("Model") then
			machine.ringBase[r] = ring:GetPivot()
			machine.ringYaw[r] = 0
		end
	end
	machines[model] = machine
	model.Destroying:Connect(function()
		machines[model] = nil
	end)
end

local function insideRoom(model: Model, position: Vector3): boolean
	local min = model:GetAttribute("RoomMin") :: Vector3?
	local max = model:GetAttribute("RoomMax") :: Vector3?
	if not min or not max then
		return false
	end
	return position.X > min.X
		and position.X < max.X
		and position.Y > min.Y
		and position.Y < max.Y
		and position.Z > min.Z
		and position.Z < max.Z
end

local function displayOf(model: Model): TextLabel?
	local screen = model:FindFirstChild("Screen")
	return screen and screen:FindFirstChild("Display", true) :: TextLabel?
end

local function coreLight(model: Model): PointLight?
	local core = model:FindFirstChild("Core")
	return core and core:FindFirstChild("CoreLight") :: PointLight?
end

local function formatCount(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
end

local function pulseCore(model: Model, strength: number)
	local light = coreLight(model)
	if light then
		light.Brightness = 1.2 + strength
		TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 1.2 }):Play()
	end
end

local function update(machine: Machine, dt: number, now: number, rootPosition: Vector3)
	local model = machine.model
	local emitter = machine.knock.Parent :: BasePart
	local distance = (emitter.Position - rootPosition).Magnitude
	local revealed = model:GetAttribute("Revealed") == true
	local solved = model:GetAttribute("Solved") == true
	local inside = insideRoom(model, rootPosition)

	-- Sound: muffled through rock, clearer when close and once open; silent inside until solved.
	local closeness = math.clamp(1 - distance / HEAR_DISTANCE, 0, 1)
	machine.eq.HighGain = if revealed then -20 * (1 - closeness) else -40 + 15 * closeness
	machine.eq.MidGain = if revealed then -6 * (1 - closeness) else -14 + 6 * closeness
	machine.eq.LowGain = 4
	local wantHum = inside or (revealed and distance < 60)
	if wantHum and not machine.hum.Playing then
		machine.hum:Play()
	elseif not wantHum and machine.hum.Playing then
		machine.hum:Stop()
	end

	local phase = now % RHYTHM_PERIOD
	local knocking = not machine.sequence and not solved and not inside and distance < HEAR_DISTANCE
	for _, t in KNOCK_TIMES do
		if phase >= t and phase - dt < t and now - machine.lastKnock > 0.2 then
			machine.lastKnock = now
			if knocking then
				machine.knock:Play()
			end
			if not machine.sequence then
				pulseCore(model, if solved then 0.4 else 1.6)
			end
		end
	end

	-- Rings: ease towards their glyph (Index), breathe slightly while unlocked, drift together once solved.
	for r, base in machine.ringBase do
		local ring = model:FindFirstChild("Ring" .. r) :: Model?
		if ring then
			local index = (ring:GetAttribute("Index") :: number?) or 1
			local target = -(index - 1) * math.rad(60)
			local yaw = machine.ringYaw[r]
			if solved then
				yaw += dt * math.rad(8 + r * 3) * (if r % 2 == 0 then -1 else 1)
			else
				-- shortest way round to the target glyph
				local delta = (target - yaw + math.pi) % (2 * math.pi) - math.pi
				yaw += delta * math.min(1, dt * 6)
			end
			machine.ringYaw[r] = yaw
			local wobble = if ring:GetAttribute("Locked") == true or solved
				then 0
				else math.sin(now * 1.7 + r) * math.rad(2.5)
			ring:PivotTo(base * CFrame.Angles(0, yaw + wobble, 0))
		end
	end

	-- Display: noise until the machine speaks, then the number, always current.
	local display = displayOf(model)
	if display and not machine.sequence then
		if solved or machine.counted then
			-- the client sequence can end a moment before the server sets Solved: keep the number
			display.Text = formatCount((model:GetAttribute("Count") :: number?) or machine.counted or 0)
		elseif revealed and now - machine.scramble > 0.15 then
			machine.scramble = now
			local glyphs = {}
			for i = 1, 5 do
				glyphs[i] = Anomalies.Glyphs[math.random(1, #Anomalies.Glyphs)]
			end
			display.Text = table.concat(glyphs, " ")
		end
	end
end

local function playSequence(model: Model, count: number)
	local machine = machines[model]
	if not machine then
		return
	end
	machine.sequence = true
	local light = coreLight(model)
	if light then
		TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0.15 }):Play()
	end
	local display = displayOf(model)
	if display then
		display.Text = ""
	end
	task.wait(1)
	-- three knocks, each lighting a ring
	for r = 1, Anomalies.Rings do
		machine.eq.HighGain = 0
		machine.eq.MidGain = 0
		machine.knock:Play()
		local ring = model:FindFirstChild("Ring" .. r)
		local band = ring and ring:FindFirstChild("Band") :: BasePart?
		if band then
			band.Material = Enum.Material.Neon
			band.Color = LIT
		end
		task.wait(0.6)
	end
	-- the number rolls up to the exact count
	if display then
		local start = os.clock()
		while os.clock() - start < 3 do
			local t = (os.clock() - start) / 3
			local eased = 1 - (1 - t) ^ 3
			display.Text = formatCount(count * eased)
			task.wait()
		end
		display.Text = formatCount(count)
	end
	machine.counted = count
	if light then
		light.Brightness = 3
		TweenService:Create(light, TweenInfo.new(1.5), { Brightness = 1.2 }):Play()
	end
	CounterController.narrative:Fire("Nos está contando.")
	task.wait(1)
	for r = 1, Anomalies.Rings do
		local ring = model:FindFirstChild("Ring" .. r)
		local band = ring and ring:FindFirstChild("Band") :: BasePart?
		if band then
			band.Material = Enum.Material.Marble
			band.Color = COLD:Lerp(Color3.new(0.2, 0.22, 0.3), 0.7)
		end
	end
	machine.sequence = false
end

function CounterController.start()
	for _, model in CollectionService:GetTagged("THNE_Counter") do
		if model:IsA("Model") then
			task.spawn(track, model)
		end
	end
	CollectionService:GetInstanceAddedSignal("THNE_Counter"):Connect(function(model)
		if model:IsA("Model") then
			task.spawn(track, model)
		end
	end)

	Remotes.event("CounterSequence").OnClientEvent:Connect(function(model: Model, count: number)
		if typeof(model) == "Instance" and model:IsA("Model") and type(count) == "number" then
			task.spawn(playSequence, model, count)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local now = os.clock()
		for _, machine in machines do
			local emitter = machine.knock.Parent :: BasePart?
			-- only machines within hearing range are animated
			if
				machine.model.Parent
				and emitter
				and (emitter.Position - root.Position).Magnitude < HEAR_DISTANCE + 40
			then
				update(machine, dt, now, root.Position)
			elseif machine.hum.Playing then
				machine.hum:Stop()
			end
		end
	end)
end

return CounterController
