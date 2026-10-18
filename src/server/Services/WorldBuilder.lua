--!strict
-- Builds the surface world (hub + per-plot buildings) procedurally from anchored Parts.
-- No external models or meshes: every piece is created here, so licensing is never an issue.
-- Everything stays outside the dig area, and digging is validated against the dig area,
-- so buildings can never be damaged by excavation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local WorldBuilder = {}

local N = GameConfig.PlotDigCells
local CELL = GameConfig.CellSize
local HALF_DIG = N * CELL / 2

local Palette = {
	wood = Color3.fromRGB(150, 104, 66),
	darkWood = Color3.fromRGB(96, 66, 44),
	wall = Color3.fromRGB(236, 224, 200),
	roof = Color3.fromRGB(176, 74, 58),
	garageRoof = Color3.fromRGB(70, 82, 96),
	metal = Color3.fromRGB(120, 128, 138),
	trim = Color3.fromRGB(250, 246, 236),
	glass = Color3.fromRGB(170, 210, 240),
	leaves = Color3.fromRGB(86, 150, 64),
	leavesDark = Color3.fromRGB(64, 124, 52),
	path = Color3.fromRGB(176, 160, 130),
	sign = Color3.fromRGB(60, 46, 34),
	accent = Color3.fromRGB(255, 196, 64),
	sell = Color3.fromRGB(80, 190, 90),
}

type PartProps = {
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	name: string?,
	transparency: number?,
	collide: boolean?,
	wedge: boolean?,
	shadow: boolean?,
}

local function make(parent: Instance, props: PartProps): BasePart
	local p: BasePart
	if props.wedge then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		part.Shape = props.shape or Enum.PartType.Block
		p = part
	end
	p.Name = props.name or "Part"
	p.Anchored = true
	p.Size = props.size
	p.CFrame = props.cframe
	p.Color = props.color
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.CanCollide = if props.collide == nil then true else props.collide
	p.CastShadow = if props.shadow == nil then true else props.shadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3, background: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = part
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = if background then 0 else 1
	textLabel.BackgroundColor3 = background or Color3.new()
	textLabel.Text = text
	textLabel.TextColor3 = textColor
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = textLabel
	return textLabel
end

local function prompt(parent: BasePart, action: string, objectText: string, actionText: string, distance: number?)
	local p = Instance.new("ProximityPrompt")
	p.Name = action .. "Prompt"
	p.ActionText = actionText
	p.ObjectText = objectText
	p.KeyboardKeyCode = Enum.KeyCode.F
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.MaxActivationDistance = distance or 10
	p.RequiresLineOfSight = false
	p:SetAttribute("Action", action)
	p.Parent = parent
	return p
end

local function lamp(parent: Instance, base: Vector3, height: number)
	make(parent, {
		name = "LampPost",
		size = Vector3.new(0.5, height, 0.5),
		cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)),
		color = Palette.darkWood,
		material = Enum.Material.Wood,
	})
	local bulb = make(parent, {
		name = "LampBulb",
		size = Vector3.new(1.1, 1.1, 1.1),
		cframe = CFrame.new(base + Vector3.new(0, height + 0.4, 0)),
		color = Color3.fromRGB(255, 220, 150),
		material = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = bulb
end

local function tree(parent: Instance, base: Vector3, scale: number)
	local trunkHeight = 7 * scale
	make(parent, {
		name = "Trunk",
		size = Vector3.new(1.4, trunkHeight, 1.4) * Vector3.new(scale, 1, scale),
		cframe = CFrame.new(base + Vector3.new(0, trunkHeight / 2, 0)),
		color = Palette.darkWood,
		material = Enum.Material.Wood,
	})
	local crowns = {
		{ offset = Vector3.new(0, trunkHeight + 1.5 * scale, 0), size = 7 },
		{ offset = Vector3.new(1.6, trunkHeight + 3.6 * scale, 0.8), size = 5 },
		{ offset = Vector3.new(-1.2, trunkHeight + 4.2 * scale, -1), size = 4.2 },
	}
	for i, crown in crowns do
		local size = crown.size * scale
		make(parent, {
			name = "Leaves",
			size = Vector3.new(size, size * 0.85, size),
			cframe = CFrame.new(base + crown.offset * Vector3.new(scale, 1, scale))
				* CFrame.Angles(0, math.rad(i * 37), math.rad(8)),
			color = if i == 1 then Palette.leavesDark else Palette.leaves,
			material = Enum.Material.SmoothPlastic,
		})
	end
end

local function fenceLine(parent: Instance, from: Vector3, to: Vector3, gapCenter: Vector3?, gapWidth: number?)
	local direction = to - from
	local length = direction.Magnitude
	local unit = direction.Unit
	local posts = math.floor(length / 8)
	-- Rails run unbroken between gaps: one part per run and height instead of one per segment.
	-- Same look, ~220 fewer parts per plot (every plot is built even when empty; Studio test 2).
	local function rails(runFrom: Vector3, runTo: Vector3)
		local mid = (runFrom + runTo) / 2
		for _, h in { 1.3, 2.7 } do
			make(parent, {
				name = "FenceRail",
				size = Vector3.new(0.3, 0.4, (runTo - runFrom).Magnitude),
				cframe = CFrame.lookAt(mid + Vector3.new(0, h, 0), runTo + Vector3.new(0, h, 0)),
				color = Palette.trim,
				material = Enum.Material.Wood,
			})
		end
	end
	local runStart: Vector3? = nil
	for i = 0, posts do
		local p = from + unit * (i * length / posts)
		local inGap = gapCenter and (p - gapCenter).Magnitude < (gapWidth or 0) / 2
		if not inGap then
			make(parent, {
				name = "FencePost",
				size = Vector3.new(0.6, 3.6, 0.6),
				cframe = CFrame.new(p + Vector3.new(0, 1.8, 0)),
				color = Palette.trim,
				material = Enum.Material.Wood,
			})
		end
		local nextP = from + unit * ((i + 1) * length / posts)
		local segmentOpen = i < posts
			and not (gapCenter and (((p + nextP) / 2) - gapCenter).Magnitude < (gapWidth or 0) / 2)
		if segmentOpen and not runStart then
			runStart = p
		elseif not segmentOpen and runStart then
			rails(runStart, p)
			runStart = nil
		end
	end
end

-- Hub where players spawn before their plot is ready ------------------------------------------
function WorldBuilder.buildHub(parent: Instance, center: Vector3)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = parent

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0))
	spawn.Color = Palette.path
	spawn.Material = Enum.Material.Cobblestone
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local board = make(hub, {
		name = "WelcomeSign",
		size = Vector3.new(18, 6, 0.6),
		cframe = CFrame.new(center + Vector3.new(0, 7, 14)),
		color = Palette.sign,
		material = Enum.Material.Wood,
	})
	label(board, Enum.NormalId.Front, GameConfig.GameName, Palette.accent)
	for _, x in { -8, 8 } do
		make(hub, {
			name = "SignPost",
			size = Vector3.new(0.8, 10, 0.8),
			cframe = CFrame.new(center + Vector3.new(x, 5, 14)),
			color = Palette.darkWood,
			material = Enum.Material.Wood,
		})
	end
	lamp(hub, center + Vector3.new(-10, 0, -8), 8)
	lamp(hub, center + Vector3.new(10, 0, -8), 8)
	tree(hub, center + Vector3.new(-22, 0, 10), 1.2)
	tree(hub, center + Vector3.new(24, 0, -14), 1)
end

-- Plot -----------------------------------------------------------------------------------------
export type PlotPoints = {
	spawn: CFrame,
	sell: Vector3,
	shop: Vector3,
	lift: Vector3,
	vitrine: { Vector3 }, -- slots of the house display case, in Config/Collections "relics" order
	depthLabel: TextLabel,
	ownerLabel: TextLabel,
}

-- `originX/originZ` is the dig-area corner. Returns the folder and important points.
function WorldBuilder.buildPlot(parent: Instance, index: number, originX: number, originZ: number): (Folder, PlotPoints)
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. index
	folder:SetAttribute("OriginX", originX)
	folder:SetAttribute("OriginZ", originZ)
	folder:SetAttribute("Index", index)

	local C = Vector3.new(originX + HALF_DIG, GameConfig.SurfaceY, originZ + HALF_DIG)
	local function at(x: number, y: number, z: number): Vector3
		return C + Vector3.new(x, y, z)
	end
	local half = GameConfig.PlotFootprint / 2

	-- Hole rim: wooden frame on the protected border ring --------------------------------------
	local rimOuter = HALF_DIG + CELL
	for _, side in { -1, 1 } do
		make(folder, {
			name = "Rim",
			size = Vector3.new(rimOuter * 2, 0.8, CELL - 0.4),
			cframe = CFrame.new(at(0, 0.4, side * (HALF_DIG + CELL / 2))),
			color = Palette.wood,
			material = Enum.Material.WoodPlanks,
		})
		make(folder, {
			name = "Rim",
			size = Vector3.new(CELL - 0.4, 0.8, HALF_DIG * 2),
			cframe = CFrame.new(at(side * (HALF_DIG + CELL / 2), 0.4, 0)),
			color = Palette.wood,
			material = Enum.Material.WoodPlanks,
		})
	end
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		local base = at(corner[1] * (HALF_DIG + CELL / 2), 0, corner[2] * (HALF_DIG + CELL / 2))
		lamp(folder, base, 6)
	end

	-- Paths ------------------------------------------------------------------------------------
	local function path(from: Vector3, to: Vector3, width: number)
		local mid = (from + to) / 2
		make(folder, {
			name = "Path",
			size = Vector3.new(width, 0.2, (to - from).Magnitude + width),
			cframe = CFrame.lookAt(mid + Vector3.new(0, 0.1, 0), to + Vector3.new(0, 0.1, 0)),
			color = Palette.path,
			material = Enum.Material.Cobblestone,
			shadow = false,
		})
	end
	path(at(0, 0, -half + 4), at(0, 0, -HALF_DIG - CELL - 4), 8)
	path(at(-HALF_DIG - CELL - 4, 0, -46), at(-62, 0, -46), 6)
	path(at(-62, 0, -46), at(-62, 0, -4), 6)
	path(at(HALF_DIG + CELL + 4, 0, -46), at(58, 0, -46), 6)
	path(at(58, 0, -46), at(58, 0, -10), 6)
	path(at(-HALF_DIG - CELL - 4, 0, -46), at(HALF_DIG + CELL + 4, 0, -46), 6)

	-- Spawn pad --------------------------------------------------------------------------------
	make(folder, {
		name = "SpawnPad",
		size = Vector3.new(10, 0.4, 10),
		cframe = CFrame.new(at(0, 0.2, -56)),
		color = Palette.path,
		material = Enum.Material.Slate,
	})
	local spawnCFrame = CFrame.lookAt(at(0, 4, -56), at(0, 4, 0))

	-- House (behind the hole) -------------------------------------------------------------------
	local vitrineSlots: { Vector3 } = {}
	do
		local hx, hz, w, dpt, h = 0, 76, 30, 22, 12
		local front = hz - dpt / 2
		make(folder, {
			name = "HouseFloor",
			size = Vector3.new(w, 1, dpt),
			cframe = CFrame.new(at(hx, 0.5, hz)),
			color = Palette.darkWood,
			material = Enum.Material.WoodPlanks,
		})
		make(folder, {
			name = "HouseWall",
			size = Vector3.new(w, h, 1),
			cframe = CFrame.new(at(hx, h / 2 + 1, hz + dpt / 2 - 0.5)),
			color = Palette.wall,
			material = Enum.Material.Plaster,
		})
		for _, side in { -1, 1 } do
			make(folder, {
				name = "HouseWall",
				size = Vector3.new(1, h, dpt),
				cframe = CFrame.new(at(hx + side * (w / 2 - 0.5), h / 2 + 1, hz)),
				color = Palette.wall,
				material = Enum.Material.Plaster,
			})
			-- front wall pieces around a central door (5 wide, 8 tall)
			local pieceWidth = (w - 5) / 2
			make(folder, {
				name = "HouseFront",
				size = Vector3.new(pieceWidth, h, 1),
				cframe = CFrame.new(at(hx + side * (2.5 + pieceWidth / 2), h / 2 + 1, front + 0.5)),
				color = Palette.wall,
				material = Enum.Material.Plaster,
			})
			local window = make(folder, {
				name = "Window",
				size = Vector3.new(4, 3.5, 0.3),
				cframe = CFrame.new(at(hx + side * 8, 6.5, front - 0.05)),
				color = Palette.glass,
				material = Enum.Material.Glass,
				transparency = 0.3,
			})
			window.Reflectance = 0.2
			make(folder, {
				name = "WindowFrame",
				size = Vector3.new(4.6, 0.4, 0.5),
				cframe = CFrame.new(at(hx + side * 8, 4.6, front - 0.1)),
				color = Palette.trim,
				material = Enum.Material.Wood,
			})
		end
		make(folder, {
			name = "HouseFront",
			size = Vector3.new(5, h - 8, 1),
			cframe = CFrame.new(at(hx, 9 + (h - 8) / 2, front + 0.5)),
			color = Palette.wall,
			material = Enum.Material.Plaster,
		})
		make(folder, {
			name = "Door",
			size = Vector3.new(4.6, 7.8, 0.3),
			cframe = CFrame.new(at(hx - 2.5, 4.9, front + 0.4))
				* CFrame.Angles(0, math.rad(-70), 0)
				* CFrame.new(2.3, 0, 0),
			color = Palette.wood,
			material = Enum.Material.Wood,
		})
		-- Gable roof
		for _, side in { -1, 1 } do
			make(folder, {
				name = "Roof",
				wedge = true,
				size = Vector3.new(w + 2, 6, dpt / 2 + 1),
				cframe = CFrame.new(at(hx, h + 1 + 3, hz + side * (dpt / 4 + 0.5)))
					* CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
				color = Palette.roof,
				material = Enum.Material.SmoothPlastic,
			})
		end
		make(folder, {
			name = "Chimney",
			size = Vector3.new(2.4, 7, 2.4),
			cframe = CFrame.new(at(hx + 9, h + 5, hz + 4)),
			color = Color3.fromRGB(140, 80, 66),
			material = Enum.Material.Brick,
		})
		make(folder, {
			name = "Porch",
			size = Vector3.new(10, 0.6, 4),
			cframe = CFrame.new(at(hx, 0.3, front - 2)),
			color = Palette.wood,
			material = Enum.Material.WoodPlanks,
		})
		-- Table with the mysterious note
		make(folder, {
			name = "Table",
			size = Vector3.new(5, 0.4, 3),
			cframe = CFrame.new(at(hx - 6, 4, hz + 3)),
			color = Palette.wood,
			material = Enum.Material.Wood,
		})
		for _, leg in { { -2.2, -1.2 }, { 2.2, -1.2 }, { -2.2, 1.2 }, { 2.2, 1.2 } } do
			make(folder, {
				name = "TableLeg",
				size = Vector3.new(0.4, 3, 0.4),
				cframe = CFrame.new(at(hx - 6 + leg[1], 2.5, hz + 3 + leg[2])),
				color = Palette.darkWood,
				material = Enum.Material.Wood,
			})
		end
		local note = make(folder, {
			name = "MysteryNote",
			size = Vector3.new(1.2, 0.05, 1.6),
			cframe = CFrame.new(at(hx - 6, 4.25, hz + 3)) * CFrame.Angles(0, math.rad(12), 0),
			color = Color3.fromRGB(245, 232, 196),
			material = Enum.Material.Fabric,
			collide = false,
		})
		prompt(note, "Note", "Nota misteriosa", "Leer", 8):SetAttribute("NoteId", "house_note")
		-- Display case on the east wall: the pieces the player chose to keep instead of selling.
		local cabinet = make(folder, {
			name = "VitrineBase",
			size = Vector3.new(10, 3, 2.6),
			cframe = CFrame.new(at(hx + 8, 2.5, hz + 8)),
			color = Palette.darkWood,
			material = Enum.Material.Wood,
		})
		make(folder, {
			name = "VitrineGlass",
			size = Vector3.new(10, 3.2, 2.6),
			cframe = CFrame.new(at(hx + 8, 5.6, hz + 8)),
			color = Color3.fromRGB(200, 225, 235),
			material = Enum.Material.Glass,
			transparency = 0.75,
			collide = false,
			shadow = false,
		})
		label(cabinet, Enum.NormalId.Front, "VITRINA", Color3.fromRGB(255, 220, 160))
		local vitrineLight = Instance.new("PointLight")
		vitrineLight.Range = 9
		vitrineLight.Brightness = 0.7
		vitrineLight.Color = Color3.fromRGB(255, 236, 200)
		vitrineLight.Parent = cabinet
		prompt(cabinet, "Exhibit", "Vitrina", "Exponer", 8)
		vitrineSlots = {
			at(hx + 5, 4.6, hz + 8),
			at(hx + 8, 4.6, hz + 8),
			at(hx + 11, 4.6, hz + 8),
		}
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 0.8
		light.Color = Color3.fromRGB(255, 220, 170)
		light.Parent = make(folder, {
			name = "CeilingLamp",
			size = Vector3.new(1.2, 0.6, 1.2),
			cframe = CFrame.new(at(hx, h, hz)),
			color = Color3.fromRGB(255, 230, 180),
			material = Enum.Material.Neon,
			collide = false,
		})
	end

	-- Garage + shop (west of the hole, open towards it) -------------------------------------------
	local shopPoint: Vector3
	do
		local gx, gz, dpt, w, h = -76, 6, 24, 32, 13
		local back = gx - dpt / 2
		make(folder, {
			name = "GarageFloor",
			size = Vector3.new(dpt, 0.6, w),
			cframe = CFrame.new(at(gx, 0.3, gz)),
			color = Color3.fromRGB(150, 150, 150),
			material = Enum.Material.Concrete,
		})
		make(folder, {
			name = "GarageWall",
			size = Vector3.new(1, h, w),
			cframe = CFrame.new(at(back + 0.5, h / 2, gz)),
			color = Color3.fromRGB(180, 70, 56),
			material = Enum.Material.Brick,
		})
		for _, side in { -1, 1 } do
			make(folder, {
				name = "GarageWall",
				size = Vector3.new(dpt, h, 1),
				cframe = CFrame.new(at(gx, h / 2, gz + side * (w / 2 - 0.5))),
				color = Color3.fromRGB(180, 70, 56),
				material = Enum.Material.Brick,
			})
			make(folder, {
				name = "GaragePillar",
				size = Vector3.new(1.6, h, 1.6),
				cframe = CFrame.new(at(gx + dpt / 2 - 0.8, h / 2, gz + side * (w / 2 - 0.8))),
				color = Palette.trim,
				material = Enum.Material.Concrete,
			})
		end
		make(folder, {
			name = "GarageRoof",
			size = Vector3.new(dpt + 3, 1, w + 2),
			cframe = CFrame.new(at(gx + 1, h + 0.5, gz)),
			color = Palette.garageRoof,
			material = Enum.Material.Metal,
		})
		local sign = make(folder, {
			name = "GarageSign",
			size = Vector3.new(0.5, 3, 16),
			cframe = CFrame.new(at(gx + dpt / 2 + 0.6, h - 1.5, gz)),
			color = Palette.sign,
			material = Enum.Material.Wood,
		})
		label(sign, Enum.NormalId.Right, "GARAJE · TIENDA", Palette.accent)
		-- Shop counter
		local counter = make(folder, {
			name = "ShopCounter",
			size = Vector3.new(3, 3.4, 10),
			cframe = CFrame.new(at(gx + 3, 1.7, gz)),
			color = Palette.wood,
			material = Enum.Material.WoodPlanks,
		})
		make(folder, {
			name = "CounterTop",
			size = Vector3.new(3.4, 0.3, 10.4),
			cframe = CFrame.new(at(gx + 3, 3.55, gz)),
			color = Palette.darkWood,
			material = Enum.Material.Wood,
		})
		prompt(counter, "Shop", "Garaje", "Abrir tienda", 12)
		shopPoint = at(gx + 3, 0, gz)
		-- Tool wall: pegboard for decoration
		make(folder, {
			name = "Pegboard",
			size = Vector3.new(0.3, 6, 18),
			cframe = CFrame.new(at(back + 1.2, 6, gz)),
			color = Color3.fromRGB(196, 160, 110),
			material = Enum.Material.Wood,
		})
		make(folder, {
			name = "Workbench",
			size = Vector3.new(4, 3, 8),
			cframe = CFrame.new(at(back + 3, 1.5, gz + 10)),
			color = Palette.darkWood,
			material = Enum.Material.WoodPlanks,
		})
		local garageLight = Instance.new("PointLight")
		garageLight.Range = 22
		garageLight.Brightness = 1
		garageLight.Color = Color3.fromRGB(255, 236, 200)
		garageLight.Parent = make(folder, {
			name = "GarageLamp",
			size = Vector3.new(6, 0.3, 1),
			cframe = CFrame.new(at(gx, h - 0.3, gz)),
			color = Color3.fromRGB(255, 250, 230),
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
	end

	-- Sell station (east of the hole) ------------------------------------------------------------
	local sellPoint: Vector3
	do
		local sx, sz = 58, -4
		make(folder, {
			name = "SellDeck",
			size = Vector3.new(14, 0.6, 12),
			cframe = CFrame.new(at(sx, 0.3, sz)),
			color = Palette.wood,
			material = Enum.Material.WoodPlanks,
		})
		for _, c in { { -6, -5 }, { 6, -5 }, { -6, 5 }, { 6, 5 } } do
			make(folder, {
				name = "SellPost",
				size = Vector3.new(0.8, 10, 0.8),
				cframe = CFrame.new(at(sx + c[1], 5, sz + c[2])),
				color = Palette.darkWood,
				material = Enum.Material.Wood,
			})
		end
		make(folder, {
			name = "SellRoof",
			size = Vector3.new(16, 0.8, 14),
			cframe = CFrame.new(at(sx, 10.4, sz)),
			color = Palette.sell,
			material = Enum.Material.SmoothPlastic,
		})
		local cart = make(folder, {
			name = "SellCart",
			size = Vector3.new(5, 2.6, 7),
			cframe = CFrame.new(at(sx - 2, 2.2, sz)),
			color = Palette.metal,
			material = Enum.Material.DiamondPlate,
		})
		for _, c in { { -2.6, -2.4 }, { -2.6, 2.4 }, { 2.6, -2.4 }, { 2.6, 2.4 } } do
			make(folder, {
				name = "CartWheel",
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.5, 1.6, 1.6),
				cframe = CFrame.new(at(sx - 2 + c[1], 0.9, sz + c[2])),
				color = Color3.fromRGB(40, 40, 40),
				material = Enum.Material.Metal,
			})
		end
		make(folder, {
			name = "CartOre",
			size = Vector3.new(4.2, 0.6, 6.2),
			cframe = CFrame.new(at(sx - 2, 3.5, sz)),
			color = Color3.fromRGB(214, 120, 64),
			material = Enum.Material.Sandstone,
			collide = false,
		})
		local board = make(folder, {
			name = "SellSign",
			size = Vector3.new(0.5, 3, 12),
			cframe = CFrame.new(at(sx - 7.2, 8.6, sz)),
			color = Palette.sign,
			material = Enum.Material.Wood,
		})
		label(board, Enum.NormalId.Left, "VENDER MINERALES", Palette.sell)
		prompt(cart, "Sell", "Estación de venta", "Vender todo", 12)
		sellPoint = at(sx - 2, 0, sz)
	end

	-- Lift winch (west rim of the hole): the surface end of the lift stations ---------------
	local liftPoint: Vector3
	do
		local wx, wz = -HALF_DIG - CELL - 7, 16
		for _, side in { -1, 1 } do
			make(folder, {
				name = "WinchPost",
				size = Vector3.new(0.9, 12, 0.9),
				cframe = CFrame.new(at(wx, 6, wz + side * 3)) * CFrame.Angles(side * math.rad(8), 0, 0),
				color = Palette.darkWood,
				material = Enum.Material.Wood,
			})
		end
		make(folder, {
			name = "WinchBeam",
			size = Vector3.new(1, 1, 7.5),
			cframe = CFrame.new(at(wx, 11.6, wz)),
			color = Palette.metal,
			material = Enum.Material.Metal,
		})
		make(folder, {
			name = "WinchWheel",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.6, 4, 4),
			cframe = CFrame.new(at(wx + 0.8, 10.4, wz)),
			color = Color3.fromRGB(70, 70, 76),
			material = Enum.Material.DiamondPlate,
		})
		make(folder, {
			name = "WinchCable",
			size = Vector3.new(0.15, 0.15, 12),
			cframe = CFrame.lookAt(at(wx + 0.8, 10.4, wz), at(-HALF_DIG + 2, 0.2, wz)) * CFrame.new(0, 0, -6),
			color = Color3.fromRGB(40, 40, 44),
			material = Enum.Material.Metal,
			collide = false,
		})
		local panel = make(folder, {
			name = "LiftPanel",
			size = Vector3.new(1.4, 3.2, 1),
			cframe = CFrame.new(at(wx - 2.5, 1.6, wz - 4)),
			color = Color3.fromRGB(200, 160, 60),
			material = Enum.Material.Metal,
		})
		prompt(panel, "Lift", "Montacargas", "Viajar", 10)
		label(
			make(folder, {
				name = "LiftSign",
				size = Vector3.new(4, 1.4, 0.3),
				cframe = CFrame.new(at(wx - 2.5, 4, wz - 4)) * CFrame.Angles(0, math.rad(90), 0),
				color = Palette.sign,
				material = Enum.Material.Wood,
			}),
			Enum.NormalId.Front,
			"MONTACARGAS",
			Palette.accent
		)
		liftPoint = at(wx - 2.5, 0, wz - 4)
	end

	-- Depth board (next to the hole) ------------------------------------------------------------
	local depthLabel, ownerLabel
	do
		local bx, bz = 22, -40
		for _, off in { -3.5, 3.5 } do
			make(folder, {
				name = "BoardPost",
				size = Vector3.new(0.6, 9, 0.6),
				cframe = CFrame.new(at(bx + off, 4.5, bz)),
				color = Palette.darkWood,
				material = Enum.Material.Wood,
			})
		end
		local board = make(folder, {
			name = "DepthBoard",
			size = Vector3.new(8, 4.6, 0.4),
			cframe = CFrame.new(at(bx, 6.4, bz)),
			color = Palette.sign,
			material = Enum.Material.Wood,
		})
		ownerLabel = label(board, Enum.NormalId.Front, "Parcela libre", Palette.trim)
		ownerLabel.Size = UDim2.fromScale(1, 0.45)
		depthLabel = label(board, Enum.NormalId.Front, "Récord: 0 m", Palette.accent)
		local extraGui = depthLabel.Parent
		depthLabel.Size = UDim2.fromScale(1, 0.5)
		depthLabel.Position = UDim2.fromScale(0, 0.48)
		depthLabel.Parent = ownerLabel.Parent
		if extraGui then
			extraGui:Destroy()
		end
	end

	-- Fence with the entrance at the front ------------------------------------------------------
	local corners = { at(-half, 0, -half), at(half, 0, -half), at(half, 0, half), at(-half, 0, half) }
	fenceLine(folder, corners[1], corners[2], at(0, 0, -half), 14)
	fenceLine(folder, corners[2], corners[3])
	fenceLine(folder, corners[3], corners[4])
	fenceLine(folder, corners[4], corners[1])

	-- Trees and lamps ---------------------------------------------------------------------------
	for _, t in
		{
			{ -96, -94, 1.1 },
			{ 92, -90, 1.3 },
			{ -98, 60, 1.2 },
			{ 96, 96, 1 },
			{ 40, 96, 1.2 },
			{ -40, 98, 0.9 },
			{ 96, 30, 1.1 },
		}
	do
		tree(folder, at(t[1], 0, t[2]), t[3])
	end
	lamp(folder, at(-8, 0, -60), 8)
	lamp(folder, at(8, 0, -60), 8)

	folder.Parent = parent
	return folder,
		{
			spawn = spawnCFrame,
			sell = sellPoint,
			shop = shopPoint,
			lift = liftPoint,
			vitrine = vitrineSlots,
			depthLabel = depthLabel,
			ownerLabel = ownerLabel,
		}
end

return WorldBuilder
