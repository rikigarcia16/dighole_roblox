--!strict
-- Builds E.'s workshop: the second anomaly, in the Ancient Caverns. Where the Counter is cold,
-- black and impossible, this room is human and warm, and that is what makes it wrong: a workshop
-- three hundred metres below the Counter, sealed in rock nobody dug. Planked floor, stone lining,
-- a bench with a ledger, a rack of seven old shovels with their counts on tags and one empty hook,
-- a lantern that is still warm. Pure construction: WorkshopService owns state and interaction;
-- WorkshopController (client) plays the distant digging heard through the rock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Anomalies = require(ReplicatedStorage.Shared.Config.Anomalies)
local CaveProps = require(script.Parent.CaveProps)

local WorkshopRoomBuilder = {}

local CELL = GameConfig.CellSize
local part = CaveProps.part

local WOOD = Color3.fromRGB(96, 66, 42)
local WOOD_DARK = Color3.fromRGB(62, 42, 28)
local STONE = Color3.fromRGB(150, 128, 98)
local IRON = Color3.fromRGB(88, 82, 76)
local WARM = Color3.fromRGB(255, 176, 96)
local CHALK = Color3.fromRGB(236, 228, 210)

-- The counts on the tags of the seven shovels already hanging (the last one is E.'s).
WorkshopRoomBuilder.PreviousCounts = { 840, 1530, 2044, 2790, 3101, 3640, Anomalies.WorkshopEBlocks }

export type Shovel = { model: Model, pivot: CFrame }

export type Room = {
	model: Model,
	center: Vector3, -- floor centre
	hook: BasePart, -- the empty hook (its prompt hangs the player's shovel)
	hookPrompt: ProximityPrompt,
	shovels: { Shovel },
	page: BasePart, -- the ledger page that turns
	pageHinge: CFrame, -- spine of the ledger, the page rotates around it
	ledgerText: TextLabel,
	emitter: BasePart,
}

local function surfaceText(
	target: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Enum.Font
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Font = font
	label.Parent = gui
	return label
end

-- An old shovel: wooden shaft and a worn iron blade, hanging from its top end at `pivot`.
local function shovelModel(parent: Instance, pivot: CFrame, count: number?): Model
	local model = Instance.new("Model")
	model.Name = "OldShovel"
	local shaft =
		part(model, "Shaft", Vector3.new(0.22, 3.6, 0.22), pivot * CFrame.new(0, -1.8, 0), WOOD, Enum.Material.Wood)
	shaft.CanCollide = false
	local grip =
		part(model, "Grip", Vector3.new(0.8, 0.2, 0.2), pivot * CFrame.new(0, -0.1, 0), WOOD_DARK, Enum.Material.Wood)
	grip.CanCollide = false
	local blade = part(
		model,
		"Blade",
		Vector3.new(1.1, 1.3, 0.1),
		pivot * CFrame.new(0, -4.2, 0),
		IRON,
		Enum.Material.CorrodedMetal
	)
	blade.CanCollide = false
	if count then
		local tag = part(
			model,
			"Tag",
			Vector3.new(0.7, 0.45, 0.04),
			pivot * CFrame.new(0, -2.4, 0.14), -- in front of the shaft, facing the room
			Color3.fromRGB(214, 196, 160),
			Enum.Material.Fabric
		)
		tag.CanCollide = false
		surfaceText(tag, Enum.NormalId.Back, tostring(count), Color3.fromRGB(60, 40, 30), Enum.Font.SpecialElite)
	end
	model.PrimaryPart = shaft
	model.Parent = parent
	return model
end

function WorkshopRoomBuilder.build(plot: { originX: number, originZ: number }, parent: Instance): Room
	local roomDef = Anomalies.Rooms.workshop
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
	model.Name = "Workshop"

	-- Floor of planks, stone ceiling ----------------------------------------------------------
	for i = 0, 5 do
		local plankZ = minZ + (i + 0.5) * sizeZ / 6
		part(
			model,
			"Plank",
			Vector3.new(sizeX - 0.2, 0.35, sizeZ / 6 - 0.12),
			CFrame.new(cx, floorY + 0.17, plankZ),
			if i % 2 == 0 then WOOD else WOOD_DARK,
			Enum.Material.WoodPlanks
		)
	end
	part(
		model,
		"Ceiling",
		Vector3.new(sizeX, 0.5, sizeZ),
		CFrame.new(cx, topY - 0.25, cz),
		STONE,
		Enum.Material.Sandstone
	)
	for i = 1, 3 do
		part(
			model,
			"Beam",
			Vector3.new(sizeX, 0.7, 0.7),
			CFrame.new(cx, topY - 0.85, minZ + i * sizeZ / 4),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end

	-- Stone lining, leaving the two doorways open ------------------------------------------------
	local inset = 0.3
	local door = roomDef.doorways[1]
	local doorZ0 = plot.originZ + door.z0 * CELL
	local doorZ1 = plot.originZ + (door.z1 + 1) * CELL
	local doorTop = cellFloorY + 2 * CELL
	local function wall(size: Vector3, position: Vector3)
		part(model, "Wall", size, CFrame.new(position), STONE, Enum.Material.Sandstone)
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
		-- timber door frame: somebody framed these doorways from the inside
		part(
			model,
			"DoorLintel",
			Vector3.new(0.6, 0.5, doorZ1 - doorZ0 + 0.8),
			CFrame.new(x, doorTop, (doorZ0 + doorZ1) / 2),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end

	-- Chalk tally on the west wall: days, or blocks, nobody knows -----------------------------------
	local tally = part(
		model,
		"Tally",
		Vector3.new(0.05, 4, 7),
		CFrame.new(minX + inset + 0.25, floorY + 9, (minZ + doorZ0) / 2),
		STONE,
		Enum.Material.Sandstone
	)
	tally.Transparency = 1
	tally.CanCollide = false
	surfaceText(
		tally,
		Enum.NormalId.Right,
		"|||| |||| |||| |||| ||||\n|||| |||| |||| |||| |||\n|||| |||| ||",
		CHALK,
		Enum.Font.PermanentMarker
	)

	-- The rack: eight hooks on the north wall, seven shovels and one empty hook ---------------------
	local rackZ = minZ + inset + 0.6
	local rackY = floorY + 9
	part(
		model,
		"Rack",
		Vector3.new(sizeX - 4, 0.5, 0.4),
		CFrame.new(cx, rackY + 0.4, rackZ - 0.2),
		WOOD,
		Enum.Material.Wood
	)
	local shovels: { Shovel } = {}
	local hook: BasePart? = nil
	local slots = 8
	for i = 1, slots do
		local x = minX + 2.5 + (i - 1) * (sizeX - 5) / (slots - 1)
		local peg = part(
			model,
			"Peg",
			Vector3.new(0.18, 0.18, 0.7),
			CFrame.new(x, rackY, rackZ + 0.15),
			IRON,
			Enum.Material.Metal
		)
		peg.CanCollide = false
		if i <= #WorkshopRoomBuilder.PreviousCounts then
			-- each hangs slightly askew
			local pivot = CFrame.new(x, rackY, rackZ + 0.35) * CFrame.Angles(0, 0, math.rad((i % 3 - 1) * 4))
			table.insert(
				shovels,
				{ model = shovelModel(model, pivot, WorkshopRoomBuilder.PreviousCounts[i]), pivot = pivot }
			)
		else
			hook = peg
			local emptyTag = part(
				model,
				"EmptyTag",
				Vector3.new(0.7, 0.45, 0.04),
				CFrame.new(x, rackY - 2.4, rackZ + 0.21),
				Color3.fromRGB(214, 196, 160),
				Enum.Material.Fabric
			)
			emptyTag.CanCollide = false
		end
	end
	local hookPart = hook :: BasePart
	local hookPrompt = Instance.new("ProximityPrompt")
	hookPrompt.ActionText = "Colgar tu pala"
	hookPrompt.ObjectText = "Gancho vacío"
	hookPrompt.KeyboardKeyCode = Enum.KeyCode.F
	hookPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	hookPrompt.HoldDuration = 1
	hookPrompt.MaxActivationDistance = 9
	hookPrompt.RequiresLineOfSight = false
	hookPrompt.Enabled = false
	hookPrompt:SetAttribute("Action", "WorkshopHang")
	hookPrompt.Parent = hookPart

	-- Bench with the ledger, against the south wall ------------------------------------------------
	local benchZ = maxZ - inset - 1.6
	local benchY = floorY + 3.2
	part(model, "BenchTop", Vector3.new(9, 0.4, 2.6), CFrame.new(cx, benchY, benchZ), WOOD, Enum.Material.Wood)
	for _, dx in { -4, 4 } do
		for _, dz in { -1, 1 } do
			part(
				model,
				"BenchLeg",
				Vector3.new(0.4, 3, 0.4),
				CFrame.new(cx + dx, floorY + 1.5, benchZ + dz),
				WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	-- the ledger: a closed half (left) and the page that turns over from the right
	local spine = CFrame.new(cx, benchY + 0.26, benchZ) * CFrame.Angles(0, math.rad(180), 0)
	part(
		model,
		"LedgerCover",
		Vector3.new(3.6, 0.12, 2.2),
		spine * CFrame.new(0, -0.06, 0),
		Color3.fromRGB(70, 34, 26),
		Enum.Material.Fabric
	)
	local leftPage = part(
		model,
		"LedgerLeft",
		Vector3.new(1.7, 0.08, 2),
		spine * CFrame.new(-0.88, 0.04, 0),
		Color3.fromRGB(226, 214, 184),
		Enum.Material.Fabric
	)
	surfaceText(
		leftPage,
		Enum.NormalId.Top,
		"840\n1 530\n2 044\n2 790\n3 101\n3 640\nE. — 3 912",
		Color3.fromRGB(60, 40, 30),
		Enum.Font.SpecialElite
	)
	-- under the page that turns: the next page, blank until the player hangs a shovel
	local nextPage = part(
		model,
		"LedgerNext",
		Vector3.new(1.7, 0.06, 2),
		spine * CFrame.new(0.88, 0.03, 0),
		Color3.fromRGB(238, 230, 204),
		Enum.Material.Fabric
	)
	nextPage.CanCollide = false
	local ledgerText = surfaceText(nextPage, Enum.NormalId.Top, "", Color3.fromRGB(60, 40, 30), Enum.Font.SpecialElite)
	local page = part(
		model,
		"LedgerPage",
		Vector3.new(1.7, 0.06, 2),
		spine * CFrame.new(0.88, 0.1, 0),
		Color3.fromRGB(226, 214, 184),
		Enum.Material.Fabric
	)
	page.CanCollide = false
	surfaceText(
		page,
		Enum.NormalId.Top,
		"· · ·\n· · · ·\n· ·",
		Color3.fromRGB(120, 96, 80),
		Enum.Font.SpecialElite
	)

	-- Lantern on the bench: still warm ------------------------------------------------------------
	local lantern = part(
		model,
		"Lantern",
		Vector3.new(0.7, 1, 0.7),
		CFrame.new(cx + 3.4, benchY + 0.7, benchZ),
		WARM,
		Enum.Material.Neon
	)
	lantern.CanCollide = false
	CaveProps.light(lantern, WARM, 34, 1.1)
	CollectionService:AddTag(lantern, "THNE_Flicker")

	-- Sound source for the distant digging (client) -------------------------------------------------
	local emitter = part(
		model,
		"Emitter",
		Vector3.new(0.4, 0.4, 0.4),
		CFrame.new(cx, floorY + 4, cz),
		STONE,
		Enum.Material.Sandstone
	)
	emitter.Transparency = 1
	emitter.CanCollide = false

	model.PrimaryPart = emitter
	model:SetAttribute("RoomMin", Vector3.new(minX, floorY, minZ))
	model:SetAttribute("RoomMax", Vector3.new(maxX, topY, maxZ))
	model:SetAttribute("Revealed", false)
	model:SetAttribute("Hung", false)
	model.Parent = parent
	CollectionService:AddTag(model, "THNE_Workshop")

	return {
		model = model,
		center = Vector3.new(cx, floorY, cz),
		hook = hookPart,
		hookPrompt = hookPrompt,
		shovels = shovels,
		page = page,
		pageHinge = spine,
		ledgerText = ledgerText,
		emitter = emitter,
	}
end

return WorkshopRoomBuilder
