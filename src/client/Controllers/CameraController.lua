--!strict
-- Puts the camera behind the character after a teleport. The character first appears on the
-- shared SpawnLocation and the server then moves it to its plot (PlotService), and later lift rides,
-- the beacon and respawns move it again; the default camera keeps its old direction, so a new
-- player started out looking at their own face with the hole behind them (Studio playtest).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraController = {}

local JUMP = 24 -- studs in one frame: no walk, fall or hook pull gets there
local BEHIND = 14
local ABOVE = 7

local player = Players.LocalPlayer

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

function CameraController.start()
	local last: Vector3? = nil
	player.CharacterAdded:Connect(function()
		last = nil
	end)
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			last = nil
			return
		end
		local now = root.Position
		-- the first frame too: the server may have moved the character before this script ran
		if not last or (now - last).Magnitude > JUMP then
			snapBehind(root)
		end
		last = now
	end)
end

return CameraController
