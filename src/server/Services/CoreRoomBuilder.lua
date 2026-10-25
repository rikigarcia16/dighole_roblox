--!strict
-- Builds "El fondo": the third anomaly, in the Unknown Core just above the bedrock. After the cold
-- machine (the Counter) and the warm workshop, this room is plain and final: black polished walls,
-- thin cracks of white light in the floor, and on the north wall three columns of engraved counts.
-- The first holds diggers older than E. with their names worn away, the second E., the third is
-- empty but for the shape of a hand. Pure construction: CoreService owns state and interaction;
-- CoreController (client) plays the two rhythms heard on the way down.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Anomalies = require(ReplicatedStorage.Shared.Config.Anomalies)
local CaveProps = require(script.Parent.CaveProps)

local CoreRoomBuilder = {}

local CELL = GameConfig.CellSize
local part = CaveProps.part

local BLACK = Color3.fromRGB(22, 22, 26)
local STONE = Color3.fromRGB(34, 34, 40)
local ENGRAVED = Color3.fromRGB(200, 214, 220)
local COLD = Color3.fromRGB(214, 236, 255)

export type Room = {
	model: Model,
	center: Vector3, -- floor centre
	hand: BasePart, -- the hand plate under the empty column (its prompt engraves the player's count)
	handPrompt: ProximityPrompt,
	column: TextLabel, -- the third column, written when the player lays a hand on the wall
	emitter: BasePart,
}

-- "18402" -> "18 402", the way the counts are cut into the wall
function CoreRoomBuilder.spaced(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
end

local function engraving(target: BasePart, text: string, size: number): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextSize = size
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextColor3 = ENGRAVED
	label.Font = Enum.Font.Antique
	label.Parent = gui
	return label
end

-- The worn names of the older diggers: a dot per letter.
local function worn(i: number): string
	return string.rep("· ", 2 + (i * 3) % 4)
end

function CoreRoomBuilder.build(plot: { originX: number, originZ: number }, parent: Instance): Room
	local roomDef = Anomalies.Rooms.core
	local box = roomDef.box
	-- build on the visible surfaces: the terrain bulges into the cell box (Anomalies.TerrainBulge)
	local pad = Anomalies.TerrainBulge
	local cellFloorY = GameConfig.SurfaceY - (box.d1 + 1) * CELL
	local minX, maxX = plot.originX + box.x0 * CELL + pad, plot.originX + (box.x1 + 1) * CELL - pad
	local minZ, maxZ = plot.originZ + box.z0 * CELL + pad, plot.originZ + (box.z1 + 1) * CELL - pad
	local floorY = cellFloorY + pad
	local topY = GameConfig.SurfaceY - box.d0 * CELL - pad
	local sizeX, sizeZ, height = maxX - minX, maxZ - minZ, topY - floorY
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2

	local model = Instance.new("Model")
	model.Name = "CoreRoom"

	-- Floor and ceiling of black stone; cracks of cold light across the floor ---------------------
	local floor = part(
		model,
		"Floor",
		Vector3.new(sizeX, 0.4, sizeZ),
		CFrame.new(cx, floorY + 0.2, cz),
		BLACK,
		Enum.Material.Marble
	)
	floor.Reflectance = 0.15
	part(model, "Ceiling", Vector3.new(sizeX, 0.5, sizeZ), CFrame.new(cx, topY - 0.25, cz), STONE, Enum.Material.Slate)
	local cracks = {
		{ 0.1, 0.3, 0.55, 0.35 },
		{ 0.55, 0.35, 0.9, 0.25 },
		{ 0.3, 0.6, 0.7, 0.8 },
		{ 0.2, 0.85, 0.45, 0.65 },
	}
	for _, c in cracks do
		local a = Vector3.new(minX + c[1] * sizeX, floorY + 0.42, minZ + c[2] * sizeZ)
		local b = Vector3.new(minX + c[3] * sizeX, floorY + 0.42, minZ + c[4] * sizeZ)
		local crack = part(
			model,
			"Crack",
			Vector3.new(0.12, 0.04, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			COLD,
			Enum.Material.Neon
		)
		crack.CanCollide = false
		crack.Transparency = 0.25
	end

	-- Polished black lining, leaving the two doorways open ----------------------------------------
	local inset = 0.3
	local door = roomDef.doorways[1]
	local doorZ0 = plot.originZ + door.z0 * CELL
	local doorZ1 = plot.originZ + (door.z1 + 1) * CELL
	local doorTop = cellFloorY + 2 * CELL
	local function wall(size: Vector3, position: Vector3)
		local w = part(model, "Wall", size, CFrame.new(position), BLACK, Enum.Material.Marble)
		w.Reflectance = 0.1
	end
	wall(Vector3.new(sizeX, height, 0.4), Vector3.new(cx, floorY + height / 2, minZ + inset))
	wall(Vector3.new(sizeX, height, 0.4), Vector3.new(cx, floorY + height / 2, maxZ - inset))
	for _, x in { minX + inset, maxX - inset } do
		wall(Vector3.new(0.4, height, doorZ0 - minZ), Vector3.new(x, floorY + height / 2, (minZ + doorZ0) / 2))
		wall(Vector3.new(0.4, height, maxZ - doorZ1), Vector3.new(x, floorY + height / 2, (doorZ1 + maxZ) / 2))
		wall(
			Vector3.new(0.4, topY - doorTop, doorZ1 - doorZ0),
			Vector3.new(x, (doorTop + topY) / 2, (doorZ0 + doorZ1) / 2)
		)
	end

	-- The three columns on the north wall ------------------------------------------------------------
	local wallZ = minZ + inset + 0.25
	local columnWidth = (sizeX - 4) / 3
	local columnHeight = height - 6
	local columnTop = floorY + 3 + columnHeight
	local function columnPart(i: number): BasePart
		local x = minX + 2 + (i - 0.5) * columnWidth
		local p = part(
			model,
			"Column" .. i,
			Vector3.new(columnWidth - 0.6, columnHeight, 0.05),
			CFrame.new(x, columnTop - columnHeight / 2, wallZ),
			BLACK,
			Enum.Material.Marble
		)
		p.Transparency = 1
		p.CanCollide = false
		return p
	end
	local older = {}
	for i, count in Anomalies.CoreOlderCounts do
		table.insert(older, worn(i) .. "— " .. CoreRoomBuilder.spaced(count))
	end
	engraving(columnPart(1), table.concat(older, "\n\n"), 38)
	engraving(columnPart(2), "E. — " .. CoreRoomBuilder.spaced(Anomalies.WorkshopEBlocks), 38)
	local column = engraving(columnPart(3), "", 38)

	-- The hand plate under the empty column
	local handX = minX + 2 + 2.5 * columnWidth
	local hand = part(
		model,
		"Hand",
		Vector3.new(1.4, 1.8, 0.08),
		CFrame.new(handX, floorY + 4.2, wallZ + 0.05),
		COLD,
		Enum.Material.Neon
	)
	hand.Transparency = 0.6
	hand.CanCollide = false
	CollectionService:AddTag(hand, "THNE_Pulse")
	local handPrompt = Instance.new("ProximityPrompt")
	handPrompt.ActionText = "Apoyar la mano"
	handPrompt.ObjectText = "Pared"
	handPrompt.KeyboardKeyCode = Enum.KeyCode.F
	handPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	handPrompt.HoldDuration = 1.5
	handPrompt.MaxActivationDistance = 9
	handPrompt.RequiresLineOfSight = false
	handPrompt.Enabled = false
	handPrompt:SetAttribute("Action", "CoreEngrave")
	handPrompt.Parent = hand

	-- Cold light, low: the room is lit from the cracks ----------------------------------------------
	local glow =
		part(model, "Glow", Vector3.new(0.4, 0.4, 0.4), CFrame.new(cx, floorY + 1, cz), COLD, Enum.Material.Neon)
	glow.Transparency = 1
	glow.CanCollide = false
	CaveProps.light(glow, COLD, 40, 0.9)

	-- Sound source for the two rhythms (client) ----------------------------------------------------
	local emitter =
		part(model, "Emitter", Vector3.new(0.4, 0.4, 0.4), CFrame.new(cx, floorY + 4, cz), STONE, Enum.Material.Slate)
	emitter.Transparency = 1
	emitter.CanCollide = false

	model.PrimaryPart = emitter
	model:SetAttribute("RoomMin", Vector3.new(minX, floorY, minZ))
	model:SetAttribute("RoomMax", Vector3.new(maxX, topY, maxZ))
	model:SetAttribute("Revealed", false)
	model:SetAttribute("Engraved", false)
	model.Parent = parent
	CollectionService:AddTag(model, "THNE_Core")

	return {
		model = model,
		center = Vector3.new(cx, floorY, cz),
		hand = hand,
		handPrompt = handPrompt,
		column = column,
		emitter = emitter,
	}
end

return CoreRoomBuilder
