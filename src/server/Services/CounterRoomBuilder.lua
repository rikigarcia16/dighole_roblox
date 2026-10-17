--!strict
-- Builds the Counter room: a space that must not look natural. Black reflective floor with cold
-- light lines, wall lining with the two doorways left open, a staircase hanging upside down from
-- the ceiling, a door frame that leads nowhere, a tilted pillar floating above the floor, and the
-- machine itself: pedestal, column, core and three rings of six glyphs, plus the tablet that holds
-- the answer. Pure construction: AnomalyService owns state and interaction; CounterController
-- (client) animates the rings, the core and the sound.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Anomalies = require(ReplicatedStorage.Shared.Config.Anomalies)
local CaveProps = require(script.Parent.CaveProps)

local CounterRoomBuilder = {}

local CELL = GameConfig.CellSize
local part = CaveProps.part

local DARK = Color3.fromRGB(18, 20, 28)
local LINE = Color3.fromRGB(90, 220, 235)
local COLD = Color3.fromRGB(200, 232, 255)

export type Room = {
	model: Model,
	center: Vector3, -- floor centre
	rings: { Model },
	handles: { BasePart },
	tablet: BasePart,
	display: TextLabel,
	core: BasePart,
	emitter: BasePart,
	stationSpot: CFrame, -- where the lift station appears once unlocked
}

local RING_HEIGHTS = { 4, 7, 10 }
local RING_DIAMETERS = { 7, 5.8, 4.6 }
local ROMAN = { "I", "II", "III" }

local function glyphPlate(parent: Instance, cframe: CFrame, glyph: string): Part
	local plate = part(
		parent,
		"Glyph",
		Vector3.new(1.3, 1.3, 0.25),
		cframe,
		Color3.fromRGB(34, 38, 52),
		Enum.Material.SmoothPlastic
	)
	plate.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = glyph
	label.TextScaled = true
	label.TextColor3 = LINE
	label.Font = Enum.Font.Arcade
	label.Parent = gui
	return plate
end

function CounterRoomBuilder.build(
	plot: { originX: number, originZ: number },
	solution: { number },
	parent: Instance
): Room
	local room = Anomalies.CounterRoom
	local minX, maxX = plot.originX + room.x0 * CELL, plot.originX + (room.x1 + 1) * CELL
	local minZ, maxZ = plot.originZ + room.z0 * CELL, plot.originZ + (room.z1 + 1) * CELL
	local floorY = GameConfig.SurfaceY - (room.d1 + 1) * CELL
	local topY = GameConfig.SurfaceY - room.d0 * CELL
	local sizeX, sizeZ, height = maxX - minX, maxZ - minZ, topY - floorY
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local center = Vector3.new(cx, floorY, cz)

	local model = Instance.new("Model")
	model.Name = "TheCounter"

	-- Floor and ceiling ------------------------------------------------------------------------
	local floor = part(
		model,
		"Floor",
		Vector3.new(sizeX, 0.4, sizeZ),
		CFrame.new(cx, floorY + 0.2, cz),
		Color3.fromRGB(10, 11, 16),
		Enum.Material.Glass
	)
	floor.Reflectance = 0.35
	for i = 1, 3 do
		local offset = -sizeX / 2 + i * sizeX / 4
		part(
			model,
			"FloorLine",
			Vector3.new(0.12, 0.05, sizeZ),
			CFrame.new(cx + offset, floorY + 0.43, cz),
			LINE,
			Enum.Material.Neon
		).CanCollide =
			false
		part(
			model,
			"FloorLine",
			Vector3.new(sizeX, 0.05, 0.12),
			CFrame.new(cx, floorY + 0.43, cz + offset),
			LINE,
			Enum.Material.Neon
		).CanCollide =
			false
	end
	part(
		model,
		"Ceiling",
		Vector3.new(sizeX, 0.4, sizeZ),
		CFrame.new(cx, topY - 0.2, cz),
		DARK,
		Enum.Material.SmoothPlastic
	)

	-- Wall lining, leaving the doorways open ---------------------------------------------------------
	local inset = 0.3
	local doorZ0 = plot.originZ + Anomalies.CounterDoorways[1].z0 * CELL
	local doorZ1 = plot.originZ + (Anomalies.CounterDoorways[1].z1 + 1) * CELL
	local doorTop = floorY + 2 * CELL
	local function wall(name: string, size: Vector3, position: Vector3)
		local w = part(model, name, size, CFrame.new(position), DARK, Enum.Material.SmoothPlastic)
		w.Reflectance = 0.08
	end
	wall("WallNorth", Vector3.new(sizeX, height, 0.3), Vector3.new(cx, floorY + height / 2, minZ + inset))
	wall("WallSouth", Vector3.new(sizeX, height, 0.3), Vector3.new(cx, floorY + height / 2, maxZ - inset))
	for _, x in { minX + inset, maxX - inset } do
		wall(
			"WallSide",
			Vector3.new(0.3, height, doorZ0 - minZ),
			Vector3.new(x, floorY + height / 2, (minZ + doorZ0) / 2)
		)
		wall(
			"WallSide",
			Vector3.new(0.3, height, maxZ - doorZ1),
			Vector3.new(x, floorY + height / 2, (doorZ1 + maxZ) / 2)
		)
		wall(
			"WallSide",
			Vector3.new(0.3, topY - doorTop, doorZ1 - doorZ0),
			Vector3.new(x, (doorTop + topY) / 2, (doorZ0 + doorZ1) / 2)
		)
		-- a cold rim around each doorway: the only straight lines the player has seen down here
		local rim = part(
			model,
			"DoorRim",
			Vector3.new(0.2, 0.2, doorZ1 - doorZ0),
			CFrame.new(x, doorTop, (doorZ0 + doorZ1) / 2),
			LINE,
			Enum.Material.Neon
		)
		rim.CanCollide = false
	end
	-- light band around the room above head height
	local bandY = floorY + 12
	for _, z in { minZ + inset + 0.2, maxZ - inset - 0.2 } do
		part(model, "Band", Vector3.new(sizeX - 1, 0.15, 0.1), CFrame.new(cx, bandY, z), LINE, Enum.Material.Neon).CanCollide =
			false
	end
	for _, x in { minX + inset + 0.2, maxX - inset - 0.2 } do
		part(model, "Band", Vector3.new(0.1, 0.15, sizeZ - 1), CFrame.new(x, bandY, cz), LINE, Enum.Material.Neon).CanCollide =
			false
	end

	-- Impossible geometry ------------------------------------------------------------------------
	-- A staircase hanging upside down from the ceiling, climbing towards the floor.
	for i = 0, 5 do
		local step = part(
			model,
			"InvertedStep",
			Vector3.new(4, 1, 1.6),
			CFrame.new(maxX - 4, topY - 0.9 - i * 1.0, minZ + 3 + i * 1.6),
			Color3.fromRGB(28, 30, 40),
			Enum.Material.SmoothPlastic
		)
		step.CanCollide = false
	end
	-- A door frame on the north wall that opens onto nothing.
	local frameX = cx - 6
	for _, side in { -1, 1 } do
		part(
			model,
			"FramePost",
			Vector3.new(0.5, 8.5, 0.5),
			CFrame.new(frameX + side * 2.4, floorY + 4.25, minZ + 0.8),
			DARK,
			Enum.Material.Marble
		)
	end
	part(
		model,
		"FrameLintel",
		Vector3.new(5.3, 0.5, 0.5),
		CFrame.new(frameX, floorY + 8.6, minZ + 0.8),
		DARK,
		Enum.Material.Marble
	)
	local nowhere = part(
		model,
		"Nowhere",
		Vector3.new(4.3, 8.2, 0.1),
		CFrame.new(frameX, floorY + 4.3, minZ + 0.7),
		LINE,
		Enum.Material.ForceField
	)
	nowhere.CanCollide = false
	-- A tilted pillar floating one stud above the floor.
	local pillar = part(
		model,
		"FloatingPillar",
		Vector3.new(2, 14, 2),
		CFrame.new(minX + 6, floorY + 1 + 7, maxZ - 6) * CFrame.Angles(math.rad(10), 0, math.rad(-8)),
		Color3.fromRGB(26, 28, 38),
		Enum.Material.Marble
	)
	pillar.CanCollide = true

	-- The machine --------------------------------------------------------------------------------
	part(
		model,
		"Pedestal",
		Vector3.new(2.4, 8, 8),
		CFrame.new(cx, floorY + 1.2, cz) * CFrame.Angles(0, 0, math.rad(90)),
		DARK,
		Enum.Material.Marble,
		Enum.PartType.Cylinder
	)
	part(
		model,
		"Column",
		Vector3.new(13, 1.4, 1.4),
		CFrame.new(cx, floorY + 2.4 + 6.5, cz) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(40, 44, 58),
		Enum.Material.Marble,
		Enum.PartType.Cylinder
	)
	local core = part(
		model,
		"Core",
		Vector3.new(2.2, 2.2, 2.2),
		CFrame.new(cx, floorY + 15.6, cz),
		COLD,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	core.CanCollide = false
	local coreLight = CaveProps.light(core, COLD, 34, 1.2)
	coreLight.Name = "CoreLight"
	local emitter =
		part(model, "Emitter", Vector3.new(0.2, 0.2, 0.2), CFrame.new(cx, floorY + 8, cz), COLD, Enum.Material.Neon)
	emitter.Transparency = 1
	emitter.CanCollide = false

	-- Display on the pedestal, facing south (+Z): shows the count once the machine speaks.
	local screen = part(
		model,
		"Screen",
		Vector3.new(4.4, 1.6, 0.3),
		CFrame.new(cx, floorY + 1.3, cz + 4.05) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(8, 9, 12),
		Enum.Material.Glass
	)
	local screenGui = Instance.new("SurfaceGui")
	screenGui.Face = Enum.NormalId.Front
	screenGui.LightInfluence = 0
	screenGui.Brightness = 2
	screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screenGui.PixelsPerStud = 40
	screenGui.Parent = screen
	local display = Instance.new("TextLabel")
	display.Name = "Display"
	display.BackgroundTransparency = 1
	display.Size = UDim2.fromScale(1, 1)
	display.Text = ""
	display.TextScaled = true
	display.TextColor3 = COLD
	display.Font = Enum.Font.Code
	display.Parent = screenGui

	-- Rings: built with glyph 1 facing south; the client turns each ring to its Index.
	local rings, handles = {}, {}
	for r = 1, Anomalies.Rings do
		local ring = Instance.new("Model")
		ring.Name = "Ring" .. r
		local y = floorY + RING_HEIGHTS[r]
		local radius = RING_DIAMETERS[r] / 2
		local band = part(
			ring,
			"Band",
			Vector3.new(0.9, RING_DIAMETERS[r], RING_DIAMETERS[r]),
			CFrame.new(cx, y, cz) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(46, 50, 66),
			Enum.Material.Marble,
			Enum.PartType.Cylinder
		)
		band.CanCollide = false
		for g, glyph in Anomalies.Glyphs do
			local angle = (g - 1) * math.rad(60)
			local position =
				Vector3.new(cx + math.sin(angle) * (radius + 0.15), y, cz + math.cos(angle) * (radius + 0.15))
			-- the plate's Front face (its LookVector side) must face outwards, away from the column
			local outward = position - Vector3.new(cx, y, cz)
			glyphPlate(ring, CFrame.lookAt(position, position + outward), glyph)
		end
		ring.PrimaryPart = band
		ring:SetAttribute("Ring", r)
		ring.Parent = model
		rings[r] = ring
		-- fixed marker pointing at the south-facing glyph, and the handle the player interacts with
		local marker = part(
			model,
			"Marker",
			Vector3.new(0.3, 0.5, 0.6),
			CFrame.new(cx, y, cz + radius + 1) * CFrame.Angles(0, math.pi, 0),
			LINE,
			Enum.Material.Neon,
			Enum.PartType.Wedge
		)
		marker.CanCollide = false
		local handle = part(
			model,
			"Handle" .. r,
			Vector3.new(1, 1, 1),
			CFrame.new(cx, y, cz + radius + 1.6),
			LINE,
			Enum.Material.Neon
		)
		handle.Transparency = 1
		handle.CanCollide = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Girar"
		prompt.ObjectText = "Anillo " .. ROMAN[r]
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt:SetAttribute("Action", "CounterRing")
		prompt:SetAttribute("Ring", r)
		prompt.Parent = handle
		handles[r] = handle
	end

	-- Tablet on the north wall: the answer, one glyph per ring, marked with 1, 2 and 3 dots.
	local tablet = part(
		model,
		"Tablet",
		Vector3.new(6, 4.2, 0.4),
		CFrame.new(cx + 5, floorY + 5, minZ + 0.7) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(70, 74, 86),
		Enum.Material.Slate
	)
	local tabletGui = Instance.new("SurfaceGui")
	tabletGui.Face = Enum.NormalId.Front
	tabletGui.LightInfluence = 0
	tabletGui.Brightness = 1.6
	tabletGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	tabletGui.PixelsPerStud = 40
	tabletGui.Parent = tablet
	local lines = {}
	local dots = { "●", "●●", "●●●" }
	for r = 1, Anomalies.Rings do
		table.insert(lines, dots[r] .. "   " .. Anomalies.Glyphs[solution[r]])
	end
	local tabletText = Instance.new("TextLabel")
	tabletText.BackgroundTransparency = 1
	tabletText.Size = UDim2.fromScale(1, 1)
	tabletText.Text = table.concat(lines, "\n")
	tabletText.TextScaled = true
	tabletText.TextColor3 = Color3.fromRGB(90, 230, 255)
	tabletText.Font = Enum.Font.Arcade
	tabletText.Parent = tabletGui
	local tabletPrompt = Instance.new("ProximityPrompt")
	tabletPrompt.ActionText = "Leer"
	tabletPrompt.ObjectText = "Placa de piedra"
	tabletPrompt.KeyboardKeyCode = Enum.KeyCode.F
	tabletPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	tabletPrompt.MaxActivationDistance = 9
	tabletPrompt.RequiresLineOfSight = false
	tabletPrompt.Enabled = false
	tabletPrompt:SetAttribute("Action", "CounterTablet")
	tabletPrompt.Parent = tablet

	-- Cold, steady light: nothing like the lanterns of the mines.
	for _, corner in { Vector3.new(minX + 3, topY - 1, minZ + 3), Vector3.new(maxX - 3, topY - 1, maxZ - 3) } do
		local lamp = part(model, "ColdLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(corner), COLD, Enum.Material.Neon)
		lamp.Transparency = 1
		lamp.CanCollide = false
		CaveProps.light(lamp, COLD, 36, 0.7)
	end

	model.PrimaryPart = core
	model:SetAttribute("RoomMin", Vector3.new(minX, floorY, minZ))
	model:SetAttribute("RoomMax", Vector3.new(maxX, topY, maxZ))
	model:SetAttribute("Revealed", false)
	model:SetAttribute("Solved", false)
	model.Parent = parent
	CollectionService:AddTag(model, "THNE_Counter")

	return {
		model = model,
		center = center,
		rings = rings,
		handles = handles,
		tablet = tablet,
		display = display,
		core = core,
		emitter = emitter,
		stationSpot = CFrame.new(minX + 4, floorY + 0.4, maxZ - 4),
	}
end

return CounterRoomBuilder
