--!strict
-- Special equipment on the HUD (Config/Gear): a button per owned item next to "Mochila" plus keys
-- (L lamp, G detector, T hook). The server validates everything; this module shows the result:
--   detector  a glowing arrow in front of the player pointing towards what it heard, for 2.5 s
--   hook      a visible line to the anchor and a short pull of the player's own character

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Gear = require(ReplicatedStorage.Shared.Config.Gear)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Build = require(script.Parent.Build)
local Theme = require(script.Parent.Theme)

local GearUI = {}

local player = Players.LocalPlayer

type Deps = {
	getState: () -> any,
	notify: (kind: string, text: string) -> (),
	playUi: (key: string) -> (),
	playAt: (key: string, position: Vector3) -> (),
	showEnergy: (visible: boolean) -> (),
}

local KIND_COLOR = {
	geode = Color3.fromRGB(190, 140, 255),
	chest = Color3.fromRGB(255, 205, 60),
	fossil = Color3.fromRGB(235, 225, 195),
	counter = Color3.fromRGB(120, 240, 255),
}

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- A glowing arrow 5 studs in front of the player, pointing along `direction`.
local function showArrow(direction: Vector3, color: Color3)
	local root = rootPart()
	if not root then
		return
	end
	local origin = root.Position + Vector3.new(0, 1.5, 0) + direction * 4
	local folder = Instance.new("Model")
	folder.Name = "THNE_Resonance"
	local function piece(size: Vector3, cframe: CFrame)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = 0.2
		p.Size = size
		p.CFrame = cframe
		p.Parent = folder
	end
	local frame = CFrame.lookAt(origin, origin + direction)
	piece(Vector3.new(0.25, 0.25, 2.4), frame)
	piece(Vector3.new(0.25, 0.25, 1), frame * CFrame.new(0.35, 0, -0.9) * CFrame.Angles(0, math.rad(-40), 0))
	piece(Vector3.new(0.25, 0.25, 1), frame * CFrame.new(-0.35, 0, -0.9) * CFrame.Angles(0, math.rad(40), 0))
	folder.Parent = workspace.CurrentCamera or workspace
	Debris:AddItem(folder, 2.5)
end

-- Pulls the local character to `point` (the server already checked it), with a visible line.
local function pull(point: Vector3, speed: number?)
	local root = rootPart()
	if not root then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local anchorPart = Instance.new("Part")
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.Transparency = 1
	anchorPart.Size = Vector3.new(0.2, 0.2, 0.2)
	anchorPart.CFrame = CFrame.new(point)
	anchorPart.Parent = workspace.CurrentCamera or workspace
	local a1 = Instance.new("Attachment")
	a1.Parent = anchorPart
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0, beam.Width1 = 0.12, 0.12
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(160, 140, 110))
	beam.Parent = anchorPart
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = a0
	velocity.MaxForce = math.huge
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Parent = root
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		velocity:Destroy()
		a0:Destroy()
		anchorPart:Destroy()
	end
	-- Studio test 2: releasing at the wall dropped the player straight back down a shaft with no
	-- ledge. Now the hook holds you against the wall for a moment (time to dig a foothold or jump);
	-- jumping lets go with a stronger push up.
	local hangingSince: number? = nil
	local character = root.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	connection = RunService.Heartbeat:Connect(function()
		if not root.Parent then
			finish()
			return
		end
		local now = os.clock()
		if hangingSince then
			local jumped = humanoid ~= nil and humanoid.Jump
			if jumped or now - hangingSince > Gear.Hook.hangSeconds then
				root.AssemblyLinearVelocity = Vector3.new(0, if jumped then 34 else 12, 0)
				finish()
			end
			return
		end
		local delta = point - root.Position
		if delta.Magnitude < 4 then
			-- stop just short of the wall and hold
			hangingSince = now
			velocity.VectorVelocity = Vector3.zero
			return
		end
		if now - started > Gear.Hook.maxSeconds then
			root.AssemblyLinearVelocity = Vector3.new(0, 18, 0)
			finish()
			return
		end
		velocity.VectorVelocity = delta.Unit * (speed or Gear.Hook.speed)
	end)
end

function GearUI.new(gui: ScreenGui, deps: Deps)
	-- own column on the right, above the touch DIG button, so the bottom bar stays short on phones
	local column = Build("Frame", {
		Name = "Gear",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -270),
		Size = UDim2.fromOffset(110, 170),
		Parent = gui,
		[Build.Children] = { Build.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right) },
	});
	(column:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment = Enum.VerticalAlignment.Bottom
	local buttons = column
	local buttonFor: { [string]: TextButton } = {}
	local colors = {
		lamp = Color3.fromRGB(230, 200, 90),
		detector = Color3.fromRGB(120, 200, 230),
		hook = Color3.fromRGB(150, 130, 100),
	}
	for _, def in Gear.List do
		if not def.upgradeOf then -- upgrades share the button of what they improve
			buttonFor[def.id] = Build.button(def.name:match("^(%S+)") or def.name, colors[def.id] or Theme.card, {
				Size = UDim2.fromOffset(104, 50),
				LayoutOrder = 10 + def.order,
				Visible = false,
				Parent = buttons,
			})
		end
	end

	local lampWanted = false
	local function toggleLamp()
		lampWanted = not (player:GetAttribute("GearLamp") == true)
		deps.playUi("ui_click")
		Remotes.event("GearLamp"):FireServer(lampWanted)
	end
	player:GetAttributeChangedSignal("GearLamp"):Connect(function()
		local on = player:GetAttribute("GearLamp") == true
		buttonFor.lamp.Text = if on then "Linterna ●" else "Linterna"
	end)

	local function pulse()
		deps.playUi("ui_click")
		local ok, result = pcall(function()
			return Remotes.func("GearPulse"):InvokeServer()
		end)
		if not ok or type(result) ~= "table" then
			return
		end
		if result.message and result.message ~= "" then
			deps.notify(if result.ok then "info" else "error", result.message)
		end
		local root = rootPart()
		if result.found and typeof(result.direction) == "Vector3" and root then
			showArrow(result.direction, KIND_COLOR[result.kind] or Color3.new(1, 1, 1))
			deps.playAt("counter_lock", root.Position + result.direction * 6)
		end
	end

	local function throwHook()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		-- aim where the screen centre (or the mouse on PC) points
		local location = if UserInputService.MouseEnabled
			then UserInputService:GetMouseLocation()
			else camera.ViewportSize / 2
		local ray = camera:ViewportPointToRay(location.X, location.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * (Gear.MotorHook.range + 30), params)
		if not hit then
			deps.notify("info", "Apunta a una pared o un techo de roca.")
			return
		end
		local ok, result = pcall(function()
			return Remotes.func("GearHook"):InvokeServer(hit.Position)
		end)
		if not ok or type(result) ~= "table" then
			return
		end
		if result.ok and typeof(result.point) == "Vector3" then
			deps.playAt("too_hard", result.point)
			pull(result.point, if type(result.speed) == "number" then result.speed else nil)
		elseif result.message and result.message ~= "" then
			deps.notify("info", result.message)
		end
	end

	buttonFor.lamp.Activated:Connect(toggleLamp)
	buttonFor.detector.Activated:Connect(pulse)
	buttonFor.hook.Activated:Connect(throwHook)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local state = deps.getState()
		local gear = state and state.gear or {}
		if input.KeyCode == Enum.KeyCode.L and gear.lamp then
			toggleLamp()
		elseif input.KeyCode == Enum.KeyCode.G and gear.detector then
			pulse()
		elseif (input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.ButtonR1) and gear.hook then
			throwHook()
		end
	end)

	local api = {}
	function api.refresh()
		local state = deps.getState()
		local gear = state and state.gear or {}
		for id, button in buttonFor do
			button.Visible = gear[id] == true
		end
		local usesBattery = Gear.needsBattery(gear)
		buttonFor.hook.Text = if gear.motor_hook then "Gancho ⚡" else "Gancho"
		deps.showEnergy(usesBattery)
	end
	return api
end

return GearUI
