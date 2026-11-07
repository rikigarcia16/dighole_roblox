--!strict
-- Small signs of life near the player, all client-side and purely visual:
--   THNE_Flicker  old lanterns and vents: the light wavers and sometimes dips
--   THNE_Pulse    crystals and luminous bulbs: slow breathing glow
--   THNE_Spin     the Core's floating shards, a weathervane, a coin: turn and bob
--   THNE_Rotor    wheels and gears (garage sign, lift headframe): turn about their own axis
--   THNE_Flutter  butterfly wings over the gardens: fly in loose circles, flapping
--   falling dust  every few seconds a little dust trickles from the ceiling above the player
--
-- Only objects within ACTIVE_RANGE of the camera are animated (at most MAX_ACTIVE, list refreshed
-- every 0.5 s), and
-- dust follows the graphics quality (AmbienceController.effectsScale).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local ZoneLook = require(ReplicatedStorage.Shared.Util.ZoneLook)
local AmbienceController = require(script.Parent.AmbienceController)

local AmbientLifeController = {}

local player = Players.LocalPlayer
local ACTIVE_RANGE = 140
local MAX_ACTIVE = 120 -- most objects animated at once (the nearest ones within range)

type Living = { part: BasePart, kind: string, light: PointLight?, base: number, cframe: CFrame, phase: number }

local living: { Living } = {}
local index: { [Instance]: Living } = {}

local function register(instance: Instance, kind: string)
	if not instance:IsA("BasePart") or index[instance] then
		return
	end
	local p = instance :: BasePart
	local light = p:FindFirstChildOfClass("PointLight") :: PointLight?
	local entry: Living = {
		part = p,
		kind = kind,
		light = light,
		base = if light then light.Brightness else p.Transparency,
		cframe = p.CFrame,
		phase = math.random() * 10,
	}
	index[instance] = entry
	table.insert(living, entry)
end

local function unregister(instance: Instance)
	local entry = index[instance]
	if not entry then
		return
	end
	index[instance] = nil
	local i = table.find(living, entry)
	if i then
		living[i] = living[#living]
		living[#living] = nil
	end
end

local function animate(entry: Living, now: number)
	local p = entry.part
	if entry.kind == "THNE_Flicker" then
		if entry.light then
			-- two fast sines make an irregular waver; a rare deep dip reads as an old wire
			local w = math.sin(now * 13 + entry.phase) * 0.08 + math.sin(now * 29 + entry.phase * 2) * 0.05
			local dip = if math.sin(now * 0.7 + entry.phase) > 0.97 then 0.55 else 1
			entry.light.Brightness = entry.base * (0.92 + w) * dip
		end
	elseif entry.kind == "THNE_Pulse" then
		local period = (p:GetAttribute("PulsePeriod") :: number?) or 3.2
		local s = (math.sin((now + entry.phase) * 2 * math.pi / period) + 1) / 2
		if entry.light then
			entry.light.Brightness = entry.base * (0.65 + 0.5 * s)
		else
			p.Transparency = math.clamp(entry.base + 0.3 * (1 - s), 0, 0.9)
		end
	elseif entry.kind == "THNE_Rotor" then
		local speed = (p:GetAttribute("RotorSpeed") :: number?) or 0.5
		p.CFrame = entry.cframe * CFrame.Angles(now * speed, 0, 0)
	elseif entry.kind == "THNE_Flutter" then
		local center = p:GetAttribute("Center") :: Vector3?
		if not center then
			return
		end
		local radius = (p:GetAttribute("Radius") :: number?) or 4
		local speed = (p:GetAttribute("Speed") :: number?) or 0.6
		local side = (p:GetAttribute("Side") :: number?) or 1
		local t = now * speed + ((p:GetAttribute("Phase") :: number?) or 0)
		local pos = center + Vector3.new(math.cos(t) * radius, math.sin(t * 2.3) * 0.7, math.sin(t) * radius)
		local heading = Vector3.new(-math.sin(t), 0, math.cos(t))
		local flap = math.sin(now * 16 + t) * 0.9
		p.CFrame = CFrame.lookAt(pos, pos + heading) * CFrame.Angles(0, 0, side * flap) * CFrame.new(side * 0.3, 0, 0)
	elseif entry.kind == "THNE_Spin" then
		local speed = (p:GetAttribute("SpinSpeed") :: number?) or 0.5
		local bob = math.sin(now * 0.9 + entry.phase) * 0.35
		p.CFrame = CFrame.new(entry.cframe.Position + Vector3.new(0, bob, 0))
			* CFrame.Angles(0, now * speed + entry.phase, 0)
			* (entry.cframe - entry.cframe.Position)
	end
end

-- Falling dust ------------------------------------------------------------------------------------

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain }

local function dustFall()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local depth = Grid.depthMetersFromY(root.Position.Y - 3)
	if depth < 6 then
		return
	end
	local offset = Vector3.new(math.random(-18, 18), 0, math.random(-18, 18))
	local from = root.Position + offset
	local hit = workspace:Raycast(from, Vector3.new(0, 40, 0), rayParams)
	if not hit or hit.Distance < 6 then
		return -- no ceiling, or one so low the dust would land on the player's head
	end
	local look = ZoneLook.at(depth)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1.5, 0.2, 1.5)
	anchor.CFrame = CFrame.new(hit.Position - Vector3.new(0, 0.3, 0))
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(1.6, 2.4)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(0, -14, 0)
	e.Size = NumberSequence.new(0.22, 0.08)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Color = ColorSequence.new(look.air.color:Lerp(Color3.new(0.25, 0.22, 0.2), 0.5))
	e.LightInfluence = 1
	e.Parent = anchor
	anchor.Parent = workspace.CurrentCamera or workspace
	e:Emit(math.random(8, 16))
	Debris:AddItem(anchor, 3)
end

function AmbientLifeController.start()
	for _, kind in { "THNE_Flicker", "THNE_Pulse", "THNE_Spin", "THNE_Rotor", "THNE_Flutter" } do
		for _, instance in CollectionService:GetTagged(kind) do
			register(instance, kind)
		end
		CollectionService:GetInstanceAddedSignal(kind):Connect(function(instance)
			register(instance, kind)
		end)
		CollectionService:GetInstanceRemovedSignal(kind):Connect(unregister)
	end

	-- Every 0.5 s keep only what is near the camera; those few are animated every frame, so a
	-- nearby lantern never stutters however many tagged objects the place holds.
	local active: { Living } = {}
	task.spawn(function()
		while true do
			local camera = workspace.CurrentCamera
			local nextActive = {}
			if camera then
				local eye = camera.CFrame.Position
				for _, entry in living do
					if
						#nextActive < MAX_ACTIVE
						and entry.part.Parent
						and (entry.part.Position - eye).Magnitude < ACTIVE_RANGE
					then
						table.insert(nextActive, entry)
					end
				end
			end
			active = nextActive
			task.wait(0.5)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, entry in active do
			if entry.part.Parent then
				animate(entry, now)
			end
		end
	end)

	-- Decorative lights (lanterns, windows, signs) cost the most on modest devices: off on low
	-- graphics, back on otherwise. Checked every 2 s, cheap (a flag per light).
	task.spawn(function()
		local lightsOn: boolean? = nil
		while true do
			local on = AmbienceController.effectsScale() > 0.4
			if on ~= lightsOn then
				lightsOn = on
				for _, l in CollectionService:GetTagged("THNE_DecoLight") do
					(l :: PointLight).Enabled = on
				end
			end
			task.wait(2)
		end
	end)
	CollectionService:GetInstanceAddedSignal("THNE_DecoLight"):Connect(function(l)
		(l :: PointLight).Enabled = AmbienceController.effectsScale() > 0.4
	end)

	task.spawn(function()
		while true do
			local scale = AmbienceController.effectsScale()
			task.wait(if scale > 0 then (4 + math.random() * 6) / scale else 10)
			if scale > 0 then
				pcall(dustFall)
			end
		end
	end)
end

return AmbientLifeController
