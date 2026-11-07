--!strict
-- A new tool gets a moment of its own: the real 3D model turning in the middle of the screen over a
-- slowly rotating burst of light, with its name and power, for about three seconds. It never takes
-- input (the player can keep moving) and fades away by itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local ToolModels = require(ReplicatedStorage.Shared.Util.ToolModels)
local Theme = require(script.Parent.Theme)

local ToolShowcase = {}

local SECONDS = 3.2
local RAYS = 12

export type Api = { show: (toolId: string) -> () }

function ToolShowcase.new(gui: ScreenGui): Api
	local root = Instance.new("Frame")
	root.Name = "ToolShowcase"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.45)
	root.Size = UDim2.fromOffset(420, 380)
	root.BackgroundTransparency = 1
	root.Active = false
	root.Visible = false
	root.ZIndex = 35
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root

	-- burst of light: thin rays around the centre, turning slowly
	local burst = Instance.new("Frame")
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.5, 0.42)
	burst.Size = UDim2.fromOffset(340, 340)
	burst.BackgroundTransparency = 1
	burst.ZIndex = 35
	burst.Parent = root
	local rays: { Frame } = {}
	for i = 1, RAYS do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(0, 26, 1, 0)
		ray.Rotation = (i - 1) * 180 / RAYS
		ray.BorderSizePixel = 0
		ray.ZIndex = 35
		ray.Parent = burst
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = ray
		table.insert(rays, ray)
	end
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.42)
	halo.Size = UDim2.fromOffset(190, 190)
	halo.BorderSizePixel = 0
	halo.ZIndex = 35
	halo.Parent = root
	local haloCorner = Instance.new("UICorner")
	haloCorner.CornerRadius = UDim.new(0.5, 0)
	haloCorner.Parent = halo
	local haloGradient = Instance.new("UIGradient")
	haloGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	haloGradient.Parent = halo

	local viewport = Instance.new("ViewportFrame")
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.42)
	viewport.Size = UDim2.fromOffset(260, 260)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(190, 190, 190)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -1, -0.6)
	viewport.ZIndex = 36
	viewport.Parent = root
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local function label(y: number, height: number, size: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y)
		l.Size = UDim2.fromOffset(420, height)
		l.Font = Theme.font
		l.TextSize = size
		l.TextColor3 = color
		l.ZIndex = 37
		l.Parent = root
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = Color3.fromRGB(20, 16, 12)
		s.Parent = l
		return l
	end
	local heading = label(10, 34, 28, Theme.coins)
	heading.Text = "¡NUEVA HERRAMIENTA!"
	local nameLabel = label(300, 40, 36, Color3.new(1, 1, 1))
	local powerLabel = label(340, 30, 24, Color3.fromRGB(150, 230, 150))

	local model: Model? = nil
	local spin: RBXScriptConnection? = nil
	local token = 0

	local api = {}
	function api.show(toolId: string)
		local tool = Tools.get(toolId)
		if not tool then
			return
		end
		token += 1
		local mine = token
		if model then
			model:Destroy()
		end
		local ok, built = pcall(ToolModels.buildModel, toolId)
		if not ok or not built then
			return
		end
		local m = built :: Model
		m:PivotTo(CFrame.new())
		local cf, size = m:GetBoundingBox()
		m.PrimaryPart = nil
		m.WorldPivot = CFrame.new(cf.Position)
		m.Parent = viewport
		model = m
		camera.CFrame =
			CFrame.lookAt(cf.Position + Vector3.new(0, size.Magnitude * 0.25, size.Magnitude * 1.9), cf.Position)
		-- the tool's own colour for the light (its glow or its handle), so each tier looks different
		local accent = Theme.coins
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
				accent = d.Color
				break
			end
		end
		for _, ray in rays do
			ray.BackgroundColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.4)
		end
		halo.BackgroundColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.6)
		nameLabel.Text = tool.name
		powerLabel.Text = string.format("Potencia %d · área %d", tool.power, tool.radius * 2 + 1)
		root.Visible = true
		scale.Scale = 0.3
		TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		if spin then
			spin:Disconnect()
		end
		local start = os.clock()
		spin = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			m:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(math.rad(-20), t * 1.6, math.rad(35)))
			burst.Rotation = t * 18
		end)
		task.delay(SECONDS, function()
			if mine ~= token then
				return
			end
			local out =
				TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Scale = 0,
				})
			out.Completed:Connect(function()
				if mine == token then
					root.Visible = false
					if spin then
						spin:Disconnect()
						spin = nil
					end
				end
			end)
			out:Play()
		end)
	end
	return api
end

return ToolShowcase
