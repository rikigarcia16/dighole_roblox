--!strict
-- Input -> dig requests.
--
-- PC: hold left mouse (aim with the cursor) or hold E (aim at screen centre).
-- Gamepad: hold R2 (aim at screen centre).
-- Touch: hold the DIG button (aim at screen centre).
-- If the aim ray does not reach diggable ground within reach, the controller digs in front of /
-- below the character, which makes digging straight down comfortable on every device.
--
-- The client predicts the swing and sound for responsiveness; the server decides the result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local ClientState = require(script.Parent.ClientState)
local EffectsController = require(script.Parent.EffectsController)
local PlotLocator = require(script.Parent.PlotLocator)

local DigController = {}
DigController.dug = Signal.new() -- fired after every local dig request (used by onboarding hints)

local player = Players.LocalPlayer
local digEvent = Remotes.event("Dig")

local holdSources: { [string]: boolean } = {}
local aimMode: "mouse" | "center" = "mouse"
local lastDig = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain }

-- Cell highlight --------------------------------------------------------------------------------
local highlightPart = Instance.new("Part")
highlightPart.Name = "DigTarget"
highlightPart.Anchored = true
highlightPart.CanCollide = false
highlightPart.CanQuery = false
highlightPart.CanTouch = false
highlightPart.Transparency = 1
highlightPart.Size = Vector3.one * (GameConfig.CellSize + 0.1)

local selection = Instance.new("SelectionBox")
selection.LineThickness = 0.06
selection.SurfaceTransparency = 0.85
selection.Adornee = highlightPart
selection.Parent = highlightPart

local function currentTool(): Tools.Tool?
	local data = ClientState.data
	return data and Tools.get(data.equippedTool)
end

local function holdingTool(): boolean
	local character = player.Character
	return character ~= nil and character:FindFirstChildOfClass("Tool") ~= nil
end

local function isHolding(): boolean
	for _, active in holdSources do
		if active then
			return true
		end
	end
	return false
end

function DigController.setHeld(source: string, held: boolean)
	holdSources[source] = held
end

-- Returns the aimed surface point and normal within reach, or nil.
local function computeTarget(reach: number): (Vector3?, Vector3?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return nil, nil
	end

	local screenPoint: Vector2
	if aimMode == "mouse" then
		screenPoint = UserInputService:GetMouseLocation()
	else
		screenPoint = camera.ViewportSize / 2
	end
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 400, rayParams)
	if result and (result.Position - root.Position).Magnitude <= reach then
		return result.Position, result.Normal
	end

	-- Fallback: dig in front of / beneath the feet.
	local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local direction = (forward.Unit * 0.45 - Vector3.yAxis).Unit
	local fallback = workspace:Raycast(root.Position, direction * reach, rayParams)
	if fallback then
		return fallback.Position, fallback.Normal
	end
	return nil, nil
end

local function updateHighlight(position: Vector3?, normal: Vector3?)
	if not position or not normal then
		highlightPart.Parent = nil
		return
	end
	local info = PlotLocator.cellAt(position - normal * 0.5)
	if not info or not Grid.inDigArea(info.cx, info.d, info.cz) then
		highlightPart.Parent = nil
		return
	end
	highlightPart.CFrame = CFrame.new(Grid.cellCenter(info.originX, info.originZ, info.cx, info.d, info.cz))
	local color = if info.canDig then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 80, 80)
	selection.Color3 = color
	selection.SurfaceColor3 = color
	highlightPart.Parent = workspace
end

function DigController.start()
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		if inputType == Enum.UserInputType.Touch or inputType.Name:find("Gamepad") then
			aimMode = "center"
		elseif inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.MouseButton1 then
			aimMode = "mouse"
		end
	end)
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		aimMode = "center"
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			aimMode = "mouse"
			holdSources.mouse = true
		elseif input.KeyCode == Enum.KeyCode.E and not processed then
			aimMode = "center"
			holdSources.key = true
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			aimMode = "center"
			holdSources.gamepad = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holdSources.mouse = false
		elseif input.KeyCode == Enum.KeyCode.E then
			holdSources.key = false
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			holdSources.gamepad = false
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(holdSources)
	end)

	RunService.RenderStepped:Connect(function()
		local tool = currentTool()
		if not tool or not holdingTool() then
			updateHighlight(nil, nil)
			return
		end
		local position, normal = computeTarget(tool.reach)
		updateHighlight(position, normal)

		if not isHolding() or not position or not normal then
			return
		end
		local now = os.clock()
		if now - lastDig < tool.cooldown then
			return
		end
		lastDig = now
		digEvent:FireServer(position, normal)
		EffectsController.swing(player.Character, tool.animation)
		EffectsController.playAt(tool.sound, position)
		DigController.dug:Fire()
	end)
end

return DigController
