--!strict
-- Small signs of life near the player, all client-side and purely visual:
--   THNE_Flicker  old lanterns and vents: the light wavers and sometimes dips
--   THNE_Pulse    crystals and luminous bulbs: slow breathing glow
--   THNE_Spin     the Core's floating shards: turn and bob
--   falling dust  every few seconds a little dust trickles from the ceiling above the player
--
-- Only objects within ACTIVE_RANGE of the camera are touched, at most MAX_PER_STEP per frame, and
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
local MAX_PER_STEP = 60

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
	for _, kind in { "THNE_Flicker", "THNE_Pulse", "THNE_Spin" } do
		for _, instance in CollectionService:GetTagged(kind) do
			register(instance, kind)
		end
		CollectionService:GetInstanceAddedSignal(kind):Connect(function(instance)
			register(instance, kind)
		end)
		CollectionService:GetInstanceRemovedSignal(kind):Connect(unregister)
	end

	-- round-robin over the living objects so the per-frame cost stays flat however many exist
	local cursor = 1
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera or #living == 0 then
			return
		end
		local eye = camera.CFrame.Position
		local now = os.clock()
		local count = math.min(MAX_PER_STEP, #living)
		for _ = 1, count do
			if cursor > #living then
				cursor = 1
			end
			local entry = living[cursor]
			cursor += 1
			if entry.part.Parent and (entry.part.Position - eye).Magnitude < ACTIVE_RANGE then
				animate(entry, now)
			end
		end
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
