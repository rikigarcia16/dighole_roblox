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
local HardnessView = require(ReplicatedStorage.Shared.Util.HardnessView)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local DigFeel = require(ReplicatedStorage.Shared.Config.DigFeel)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local CrackPattern = require(ReplicatedStorage.Shared.Util.CrackPattern)
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

-- Hardness indicator: a small bar of segments (one per remaining hit) above the aimed cell, or a
-- lock with the power required when the tool cannot damage the material.
local billboard = Instance.new("BillboardGui")
billboard.Name = "Hardness"
billboard.Size = UDim2.fromOffset(150, 34)
billboard.StudsOffsetWorldSpace = Vector3.new(0, GameConfig.CellSize * 0.75, 0)
billboard.AlwaysOnTop = true
billboard.LightInfluence = 0
billboard.MaxDistance = 40
billboard.Adornee = highlightPart
billboard.Parent = highlightPart

local hardnessLabel = Instance.new("TextLabel")
hardnessLabel.BackgroundTransparency = 1
hardnessLabel.Size = UDim2.new(1, 0, 0, 16)
hardnessLabel.Font = Enum.Font.GothamBold
hardnessLabel.TextSize = 13
hardnessLabel.TextColor3 = Color3.new(1, 1, 1)
hardnessLabel.TextStrokeTransparency = 0.4
hardnessLabel.Parent = billboard

local segmentBar = Instance.new("Frame")
segmentBar.BackgroundTransparency = 1
segmentBar.Position = UDim2.fromOffset(0, 19)
segmentBar.Size = UDim2.new(1, 0, 0, 10)
segmentBar.Parent = billboard
local segmentLayout = Instance.new("UIListLayout")
segmentLayout.FillDirection = Enum.FillDirection.Horizontal
segmentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
segmentLayout.Padding = UDim.new(0, 2)
segmentLayout.Parent = segmentBar
local segments: { Frame } = {}
for i = 1, DigFeel.MaxHardnessSegments do
	local seg = Instance.new("Frame")
	seg.Size = UDim2.fromOffset(11, 8)
	seg.BorderSizePixel = 0
	seg.LayoutOrder = i
	seg.Parent = segmentBar
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = seg
	segments[i] = seg
end

-- Damage the server reported per cell ("<plot>:<x>:<d>:<z>" -> fraction), forgotten after a while.
local progressCache: { [string]: { fraction: number, at: number } } = {}
local PROGRESS_MEMORY = 20

local function cellKey(info: PlotLocator.CellInfo): string
	return string.format("%s:%d:%d:%d", info.folder.Name, info.cx, info.d, info.cz)
end

-- Cracks -----------------------------------------------------------------------------------------
-- Thin dark lines on the surface around the last hit, more of them as the cell weakens (pattern in
-- Util/CrackPattern). Client only: the parts live in a local folder and never replicate.
local CRACK_COLOR = Color3.fromRGB(28, 22, 20)
local MAX_CRACKED_CELLS = 8
local crackFolder = Instance.new("Folder")
crackFolder.Name = "THNE_Cracks"
crackFolder.Parent = workspace
type Crack = { model: Model?, token: number }
local cracks: { [string]: Crack } = {}
local crackOrder: { string } = {}
local crackToken = 0
-- last local hit per cell: where the cracks start (the server only reports the cell)
local lastHits: { [string]: { position: Vector3, normal: Vector3 } } = {}

local function clearCracks(key: string)
	local crack = cracks[key]
	if crack and crack.model then
		crack.model:Destroy()
	end
	cracks[key] = nil
	lastHits[key] = nil
	local index = table.find(crackOrder, key)
	if index then
		table.remove(crackOrder, index)
	end
end

local function drawCracks(key: string, info: PlotLocator.CellInfo, fraction: number)
	local hit = lastHits[key]
	if fraction <= 0 or not hit then
		clearCracks(key)
		return
	end
	local existing = cracks[key]
	if existing and existing.model then
		existing.model:Destroy()
	end
	local normal = hit.normal
	local tangent = normal:Cross(if math.abs(normal.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
	local bitangent = normal:Cross(tangent).Unit
	local origin = hit.position + normal * 0.04
	local model = Instance.new("Model")
	model.Name = key
	local seed = info.cx + 97 * info.d + 9973 * info.cz
	for _, line in CrackPattern.lines(seed, fraction) do
		local direction = tangent * math.cos(line.angle) + bitangent * math.sin(line.angle)
		local from = origin + direction * line.start
		local to = from + direction * line.length
		local segment = Instance.new("Part")
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.SmoothPlastic
		segment.Color = CRACK_COLOR
		segment.Transparency = 0.15
		segment.Size = Vector3.new(0.09, 0.05, line.length)
		segment.CFrame = CFrame.lookAt((from + to) / 2, to, normal)
		segment.Parent = model
	end
	model.Parent = crackFolder
	crackToken += 1
	local token = crackToken
	cracks[key] = { model = model, token = token }
	if not table.find(crackOrder, key) then
		table.insert(crackOrder, key)
		if #crackOrder > MAX_CRACKED_CELLS then
			clearCracks(crackOrder[1])
		end
	end
	-- the server forgets partial damage after a while too (cells regenerate when the plot reloads)
	task.delay(PROGRESS_MEMORY, function()
		local current = cracks[key]
		if current and current.token == token then
			clearCracks(key)
		end
	end)
end

function DigController.reportProgress(position: Vector3, fraction: number)
	local info = PlotLocator.cellAt(position)
	if info then
		local key = cellKey(info)
		progressCache[key] = { fraction = fraction, at = os.clock() }
		drawCracks(key, info, fraction)
	end
end

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

-- Returns the aimed surface point, normal and terrain material within reach, or nil.
local function computeTarget(reach: number): (Vector3?, Vector3?, Enum.Material?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return nil, nil, nil
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
		return result.Position, result.Normal, result.Material
	end

	-- Fallback: dig beneath the feet, then in front of them. Straight down first: standing on the rim
	-- of a hole the screen-centre ray falls past the edge, and "in front and down" pointed into the
	-- hole too, so E / gamepad / touch did nothing at all (Studio test 2).
	-- From the head, not the root: in a narrow shaft the rounded walls can swallow the root, and a
	-- ray that starts inside terrain finds nothing (Studio playtest: E stopped digging at 2 m).
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local below = workspace:Raycast(origin, Vector3.new(0, -reach, 0), rayParams)
	if below then
		return below.Position, below.Normal, below.Material
	end
	local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local direction = (forward.Unit * 0.45 - Vector3.yAxis).Unit
	local fallback = workspace:Raycast(origin, direction * reach, rayParams)
	if fallback then
		return fallback.Position, fallback.Normal, fallback.Material
	end
	return nil, nil, nil
end

local LOCKED = Color3.fromRGB(255, 80, 80)

local function updateHighlight(position: Vector3?, normal: Vector3?, material: Enum.Material?, tool: Tools.Tool?)
	if not position or not normal or not tool then
		highlightPart.Parent = nil
		return
	end
	local info = PlotLocator.cellAt(position - normal * 0.5)
	if not info or not Grid.inDigArea(info.cx, info.d, info.cz) then
		highlightPart.Parent = nil
		return
	end
	highlightPart.CFrame = CFrame.new(Grid.cellCenter(info.originX, info.originZ, info.cx, info.d, info.cz))

	local resource = material and Resources.fromMaterial(material)
	local cached: { fraction: number, at: number }? = progressCache[cellKey(info)]
	if cached and os.clock() - cached.at > PROGRESS_MEMORY then
		progressCache[cellKey(info)] = nil
		cached = nil
	end
	local view = resource and HardnessView.compute(resource, tool.power, cached and cached.fraction)

	local color = Color3.fromRGB(255, 255, 255)
	if not info.canDig then
		color = LOCKED
		billboard.Enabled = false
	elseif view then
		billboard.Enabled = true
		hardnessLabel.Text = if view.locked then "🔒 " .. view.label else view.label
		hardnessLabel.TextColor3 = if view.locked then LOCKED else Color3.new(1, 1, 1)
		-- white -> warm as the cell weakens
		color = if view.locked
			then LOCKED
			else Color3.fromRGB(255, 255, 255):Lerp(Color3.fromRGB(255, 170, 60), view.fraction)
		for i, seg in segments do
			seg.Visible = not view.locked and i <= view.segments
			seg.BackgroundColor3 = if i <= view.filled then Color3.fromRGB(70, 70, 70) else resource.color
			seg.BackgroundTransparency = if i <= view.filled then 0.5 else 0
		end
	else
		billboard.Enabled = false
	end
	selection.Color3 = color
	selection.SurfaceColor3 = color
	selection.SurfaceTransparency = if view and not view.locked then 0.92 - view.fraction * 0.25 else 0.85
	highlightPart.Parent = workspace
end

function DigController.start()
	EffectsController.progressReported:Connect(DigController.reportProgress)
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

	-- A swing: the animation and whoosh start now; the request, the hit sound and the dust happen
	-- at the impact frame of the animation (DigFeel.Timing), aimed at what is under the cursor then.
	-- The hit is predicted from the terrain material under the cursor, so it sounds instantly;
	-- the server's answer only adds breaks and discoveries (EffectsController, DigFx).
	local function strike(tool: Tools.Tool)
		local position, normal, material = computeTarget(tool.reach)
		if not position or not normal then
			return
		end
		digEvent:FireServer(position, normal)
		local hitCell = PlotLocator.cellAt(position - normal * 0.5)
		if hitCell then
			lastHits[cellKey(hitCell)] = { position = position, normal = normal }
		end
		local resource = material and Resources.fromMaterial(material)
		if resource then
			if tool.power < resource.requiredPower then
				EffectsController.bounce(position, resource)
			else
				EffectsController.impact(position, resource, normal, tool.id, true)
			end
		end
		DigController.dug:Fire()
	end

	RunService.RenderStepped:Connect(function()
		local tool = currentTool()
		if not tool or not holdingTool() then
			updateHighlight(nil, nil, nil, nil)
			return
		end
		local position, normal, material = computeTarget(tool.reach)
		updateHighlight(position, normal, material, tool)

		if not isHolding() or not position or not normal then
			return
		end
		local now = os.clock()
		if now - lastDig < tool.cooldown then
			return
		end
		lastDig = now
		EffectsController.swing(player.Character, tool.animation)
		EffectsController.playAt(tool.sound, position)
		local timing = DigFeel.Timing[tool.animation] or DigFeel.Timing.swing
		local delay = timing.duration * timing.impact
		if delay <= 0.01 then
			strike(tool)
		else
			task.delay(delay, strike, tool)
		end
	end)
end

return DigController
