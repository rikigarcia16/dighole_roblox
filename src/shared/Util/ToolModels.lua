--!strict
-- Builds tool models procedurally from the recipes in Config/Tools so the project has no
-- dependency on external meshes. Used by the server (equipped Tool) and the client (shop preview).
--
-- The returned model's primary part is "Handle"; the grip point is at the Handle centre and the
-- tool head points along -Z of the Handle (forward when held).

local Tools = require(script.Parent.Parent.Config.Tools)

local ToolModels = {}

local function part(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function attach(container: Instance, handle: BasePart, piece: BasePart, offset: CFrame)
	piece.CFrame = handle.CFrame * offset
	piece.Parent = container
	weld(handle, piece)
end

-- Fills `container` with the parts of the tool. Returns the Handle part.
function ToolModels.build(toolId: string, container: Instance): BasePart
	local tool = Tools.get(toolId)
	assert(tool, "Unknown tool " .. toolId)
	local recipe = tool.model
	local s = recipe.scale
	local accent = recipe.accentColor or recipe.headColor

	-- The grip is a short cylinder; the shaft extends forward from it.
	local handle = part("Handle", Vector3.new(0.35, 0.35, 1.1) * s, recipe.handleColor, recipe.handleMaterial)
	handle.CFrame = CFrame.new()
	handle.Parent = container

	if recipe.kind == "shovel" then
		local shaft = part("Shaft", Vector3.new(0.28, 0.28, 3.4) * s, recipe.handleColor, recipe.handleMaterial)
		attach(container, handle, shaft, CFrame.new(0, 0, -2.1 * s))
		local grip = part("Grip", Vector3.new(0.9, 0.22, 0.22) * s, accent, Enum.Material.SmoothPlastic)
		attach(container, handle, grip, CFrame.new(0, 0, 0.6 * s))
		local collar = part("Collar", Vector3.new(0.42, 0.42, 0.45) * s, accent, recipe.headMaterial)
		attach(container, handle, collar, CFrame.new(0, 0, -3.85 * s))
		local blade = part("Blade", Vector3.new(1.25, 0.12, 1.5) * s, recipe.headColor, recipe.headMaterial)
		attach(container, handle, blade, CFrame.new(0, 0, -4.75 * s) * CFrame.Angles(math.rad(-12), 0, 0))
		local tip =
			part("Tip", Vector3.new(0.12, 1.0, 0.75) * s, recipe.headColor, recipe.headMaterial, Enum.PartType.Wedge)
		attach(container, handle, tip, CFrame.new(0, 0, -5.75 * s) * CFrame.Angles(math.rad(-12), 0, math.rad(90)))
	elseif recipe.kind == "pick" then
		local shaft = part("Shaft", Vector3.new(0.3, 0.3, 3.6) * s, recipe.handleColor, recipe.handleMaterial)
		attach(container, handle, shaft, CFrame.new(0, 0, -2.2 * s))
		local head = part("Head", Vector3.new(0.45, 0.45, 0.7) * s, accent, recipe.headMaterial)
		attach(container, handle, head, CFrame.new(0, 0, -4.1 * s))
		for _, side in { -1, 1 } do
			local arm = part("Arm", Vector3.new(0.32, 1.5, 0.4) * s, recipe.headColor, recipe.headMaterial)
			attach(
				container,
				handle,
				arm,
				CFrame.new(0, side * 0.95 * s, -4.1 * s) * CFrame.Angles(side * math.rad(12), 0, 0)
			)
			local point = part(
				"Point",
				Vector3.new(0.32, 0.6, 0.4) * s,
				recipe.headColor,
				recipe.headMaterial,
				Enum.PartType.Wedge
			)
			attach(
				container,
				handle,
				point,
				CFrame.new(0, side * 1.95 * s, -3.95 * s) * CFrame.Angles(side > 0 and 0 or math.pi, 0, 0)
			)
		end
	elseif recipe.kind == "drill" or recipe.kind == "plasma" then
		local body = part("Body", Vector3.new(0.8, 0.9, 1.8) * s, recipe.handleColor, recipe.handleMaterial)
		attach(container, handle, body, CFrame.new(0, 0.55 * s, -0.7 * s))
		local battery = part("Battery", Vector3.new(0.6, 0.5, 0.7) * s, accent, Enum.Material.SmoothPlastic)
		attach(container, handle, battery, CFrame.new(0, -0.55 * s, 0))
		local chuck = part("Chuck", Vector3.new(0.6, 0.6, 0.5) * s, accent, Enum.Material.Metal, Enum.PartType.Cylinder)
		attach(container, handle, chuck, CFrame.new(0, 0.55 * s, -1.85 * s) * CFrame.Angles(0, math.rad(90), 0))
		if recipe.kind == "drill" then
			local bit = part(
				"Bit",
				Vector3.new(1.6, 0.3, 0.3) * s,
				recipe.headColor,
				recipe.headMaterial,
				Enum.PartType.Cylinder
			)
			attach(container, handle, bit, CFrame.new(0, 0.55 * s, -2.85 * s) * CFrame.Angles(0, math.rad(90), 0))
			local cone =
				part("Cone", Vector3.new(0.3, 0.4, 0.5) * s, recipe.headColor, recipe.headMaterial, Enum.PartType.Wedge)
			attach(container, handle, cone, CFrame.new(0, 0.55 * s, -3.8 * s))
		else
			local emitter = part(
				"Emitter",
				Vector3.new(1.4, 0.5, 0.5) * s,
				recipe.headColor,
				recipe.headMaterial,
				Enum.PartType.Cylinder
			)
			attach(container, handle, emitter, CFrame.new(0, 0.55 * s, -2.7 * s) * CFrame.Angles(0, math.rad(90), 0))
			for i = 1, 3 do
				local ring =
					part("Ring", Vector3.new(0.12, 0.8, 0.8) * s, accent, Enum.Material.Neon, Enum.PartType.Cylinder)
				attach(
					container,
					handle,
					ring,
					CFrame.new(0, 0.55 * s, -(2.2 + i * 0.3) * s) * CFrame.Angles(0, math.rad(90), 0)
				)
			end
		end
	end

	if recipe.glow then
		local light = Instance.new("PointLight")
		light.Color = recipe.headColor
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = handle
	end

	return handle
end

-- Builds a Roblox Tool instance ready to be given to a character.
function ToolModels.buildTool(toolId: string): Tool
	local config = Tools.get(toolId)
	assert(config, "Unknown tool " .. toolId)
	local tool = Instance.new("Tool")
	tool.Name = config.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	tool:SetAttribute("ToolId", toolId)
	ToolModels.build(toolId, tool)
	-- With an identity grip the Handle's -Z points forward out of the hand; tilt the head slightly
	-- downwards so the blade points at the ground in front of the character.
	tool.Grip = CFrame.new(0, 0, 0.3) * CFrame.Angles(math.rad(20), 0, 0)
	return tool
end

-- Builds a standalone Model (for previews).
function ToolModels.buildModel(toolId: string): Model
	local model = Instance.new("Model")
	model.Name = toolId
	local handle = ToolModels.build(toolId, model)
	model.PrimaryPart = handle
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).Anchored = true
		end
	end
	return model
end

return ToolModels
