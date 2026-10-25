--!strict
-- Camera help on top of the default Roblox camera:
--   * After a teleport the camera goes behind the character. The character first appears on the
--     shared SpawnLocation and the server then moves it to its plot (PlotService), and later lift
--     rides, the beacon and respawns move it again; the default camera keeps its old direction, so
--     a new player started out looking at their own face with the hole behind them.
--   * Inside a narrow shaft the camera rises above the character and looks down (Util/ShaftCamera);
--     the default one pressed against the walls and the picture became unreadable.
--   * A character wedged by the rounded walls over an open drop in a shaft is let down to the floor,
--     centred in its cell (otherwise the shovel cannot reach anything and the player is stuck).
-- Both from the Studio playtest of the first minutes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local ShaftCamera = require(ReplicatedStorage.Shared.Util.ShaftCamera)
local PlotLocator = require(script.Parent.PlotLocator)

local CameraController = {}

local JUMP = 24 -- studs in one frame: no walk, fall or hook pull gets there
local BEHIND = 14
local ABOVE = 7
local CHECK_SECONDS = 0.1
local FOLLOW = 10 -- how fast the shaft camera catches up (1/s)

local player = Players.LocalPlayer
local DIRECTIONS = ShaftCamera.directions()

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain }

local function snapBehind(root: BasePart)
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	flat = flat.Unit
	local focus = root.Position + Vector3.new(0, 1.5, 0)
	camera.CFrame = CFrame.lookAt(focus - flat * BEHIND + Vector3.new(0, ABOVE, 0), focus + flat * 4)
end

-- Side walls and free space above the head, from the terrain only.
local function probe(head: Vector3): (number, number)
	local hits = 0
	for _, direction in DIRECTIONS do
		if workspace:Raycast(head, direction * ShaftCamera.SideReach, rayParams) then
			hits += 1
		end
	end
	local up = workspace:Raycast(head, Vector3.new(0, ShaftCamera.MaxHeight + 4, 0), rayParams)
	local openAbove = if up then up.Distance else math.huge
	return hits, openAbove
end

local DROP_REACH = 200

-- The floor straight below the centre of the character's cell (the centre, not the root: a wedged
-- character hangs at the edge, on the rounded wall).
local function floorBelowCell(root: BasePart): RaycastResult?
	local info = PlotLocator.cellAt(root.Position)
	if not info then
		return nil
	end
	local center = Grid.cellCenter(info.originX, info.originZ, info.cx, info.d, info.cz)
	local from = Vector3.new(center.X, root.Position.Y, center.Z)
	return workspace:Raycast(from, Vector3.new(0, -DROP_REACH, 0), rayParams)
end

-- Lets a wedged character down to the floor of its shaft, centred in the cell.
local function unwedge(root: BasePart, floor: RaycastResult)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(floor.Position + Vector3.new(0, 3, 0)) * root.CFrame.Rotation
end

function CameraController.start()
	local last: Vector3? = nil
	local shaft = false
	local timer = 0
	local sinceCheck = CHECK_SECONDS
	local wanted = false
	local openAbove = math.huge
	local forward = Vector3.new(0, 0, 1)
	local stillFor = 0

	local function leaveShaft()
		if shaft then
			shaft = false
			local camera = workspace.CurrentCamera
			if camera then
				camera.CameraType = Enum.CameraType.Custom
			end
		end
		timer = 0
	end

	player.CharacterAdded:Connect(function()
		last = nil
		leaveShaft()
	end)

	RunService:BindToRenderStep("THNE_ShaftCamera", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not camera or not root then
			last = nil
			return
		end
		local now = root.Position
		-- a teleport, or the first frame (the server may have moved the character before this ran)
		if not last or (now - last).Magnitude > JUMP then
			leaveShaft()
			snapBehind(root)
			last = now
			return
		end
		last = now

		local head = now + Vector3.new(0, 1.5, 0)
		sinceCheck += dt
		if sinceCheck >= CHECK_SECONDS then
			local elapsed = sinceCheck
			sinceCheck = 0
			local hits
			hits, openAbove = probe(head)
			wanted = ShaftCamera.inShaft(hits, openAbove, GameConfig.SurfaceY - head.Y)
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local below = floorBelowCell(root)
			local floorDistance = if below then below.Distance else 0 -- nothing found: leave it be
			local climbing = humanoid ~= nil and humanoid:GetState() == Enum.HumanoidStateType.Climbing
			local speed = root.AssemblyLinearVelocity.Magnitude
			-- walls all round is enough here (no depth or open sky needed: it happens at the very top)
			local enclosed = hits >= ShaftCamera.MinSideHits
			if below and ShaftCamera.wedged(enclosed, speed, floorDistance, climbing) then
				stillFor += elapsed
				if stillFor >= ShaftCamera.WedgeSeconds then
					stillFor = 0
					unwedge(root, below)
					last = root.Position -- not a teleport for the camera
				end
			else
				stillFor = 0
			end
		end
		local was = shaft
		shaft, timer = ShaftCamera.step(shaft, wanted, timer, dt)
		if shaft and not was then
			-- keep the direction the player was facing as "forward" of the top view
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			forward = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, 1)
			camera.CameraType = Enum.CameraType.Scriptable
		elseif was and not shaft then
			camera.CameraType = Enum.CameraType.Custom
		end
		if shaft then
			local target = ShaftCamera.target(head, forward, openAbove)
			-- never inside the rock: if a wall stands between the head and the camera, come closer
			local toEye = target.Position - head
			local blocked = workspace:Raycast(head, toEye, rayParams)
			if blocked then
				local eye = blocked.Position - toEye.Unit
				target = CFrame.lookAt(eye, head - Vector3.new(0, 4, 0) + forward * 0.01)
			end
			camera.CFrame = camera.CFrame:Lerp(target, 1 - math.exp(-dt * FOLLOW))
		end
	end)
end

return CameraController
