--!strict
-- Builds the physical objects of a cave sector: per-style decoration along galleries and in
-- chambers, chests and geodes. Pure construction (no state, no rewards): SpecialsService owns
-- reveal, interaction and persistence.
--
-- Everything is anchored, placed only in open cells (positions are found by scanning the cave
-- grid for the floor/ceiling) and kept to a handful of parts per feature.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Anomalies = require(ReplicatedStorage.Shared.Config.Anomalies)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local Hash = require(ReplicatedStorage.Shared.Util.Hash)
local Caves = require(script.Parent.Parent.Logic.Caves)

local CaveProps = {}

local CELL = GameConfig.CellSize

type Plot = { originX: number, originZ: number, seed: number }

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.Parent = parent
	return p
end
CaveProps.part = part

function CaveProps.light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- World Y of the floor under (x, d, z) and of the ceiling above it, or nil if (x, d, z) is rock.
local function column(plot: Plot, x: number, d: number, z: number): (number?, number?)
	if Caves.cellAt(plot.seed, x, d, z) == 0 then
		return nil, nil
	end
	local floorD, ceilD = d, d
	while Caves.cellAt(plot.seed, x, floorD + 1, z) > 0 and floorD - d < 40 do
		floorD += 1
	end
	while Caves.cellAt(plot.seed, x, ceilD - 1, z) > 0 and d - ceilD < 40 do
		ceilD -= 1
	end
	return GameConfig.SurfaceY - (floorD + 1) * CELL, GameConfig.SurfaceY - ceilD * CELL
end

local function worldXZ(plot: Plot, x: number, z: number): (number, number)
	return plot.originX + x * CELL, plot.originZ + z * CELL
end

-- Galleries -------------------------------------------------------------------------------------

local WOOD = Color3.fromRGB(112, 78, 50)

local function mineSupports(plot: Plot, feature: Caves.Feature, parent: Instance)
	local points = feature.points
	if not points then
		return
	end
	local built = 0
	for s = 1, #points - 1 do
		local a, b = points[s], points[s + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local length = math.sqrt(dx * dx + dz * dz)
		if length > 0.5 then
			local steps = math.floor(length / 3.5)
			for k = 1, steps do
				local t = k / (steps + 1)
				local px, pd, pz = a.x + dx * t, a.d + (b.d - a.d) * t, a.z + dz * t
				local floorY, ceilY = column(plot, math.floor(px), math.floor(pd), math.floor(pz))
				if floorY and ceilY and ceilY - floorY >= 6 then
					local wx, wz = worldXZ(plot, px, pz)
					local height = ceilY - floorY
					local frame = CFrame.lookAt(Vector3.new(wx, floorY, wz), Vector3.new(wx + dx, floorY, wz + dz))
					local half = feature.radius * CELL * 0.7
					-- guided galleries end at an anomaly room: never put a frame inside its box
					-- (Studio test 3 found a post in the middle of E.'s workshop)
					local blocked = false
					for _, side in { -1, 1 } do
						local foot = (frame * CFrame.new(side * half, 1, 0)).Position
						local fx = math.floor((foot.X - plot.originX) / CELL)
						local fz = math.floor((foot.Z - plot.originZ) / CELL)
						local fd = math.floor((GameConfig.SurfaceY - foot.Y) / CELL)
						if Anomalies.inReserved(fx, fd, fz) then
							blocked = true
						end
					end
					if blocked then
						continue
					end
					for _, side in { -1, 1 } do
						part(
							parent,
							"Support",
							Vector3.new(0.7, height, 0.7),
							frame * CFrame.new(side * half, height / 2, 0),
							WOOD,
							Enum.Material.WoodPlanks
						)
					end
					part(
						parent,
						"Beam",
						Vector3.new(half * 2 + 0.8, 0.7, 0.8),
						frame * CFrame.new(0, height - 0.35, 0),
						WOOD,
						Enum.Material.WoodPlanks
					)
					built += 1
					if built % 2 == 1 then
						local lantern = part(
							parent,
							"Lantern",
							Vector3.new(0.6, 0.8, 0.6),
							frame * CFrame.new(0.8, height - 1.4, 0),
							Color3.fromRGB(255, 190, 90),
							Enum.Material.Neon
						)
						lantern.CanCollide = false
						CaveProps.light(lantern, Color3.fromRGB(255, 180, 90), 16, 1.2)
					end
				end
			end
		end
	end
end

local function glowMarkers(plot: Plot, feature: Caves.Feature, parent: Instance, color: Color3, kind: string)
	local points = feature.points
	if not points then
		return
	end
	for s = 2, #points do
		local p = points[s]
		local floorY = column(plot, math.floor(p.x), math.floor(p.d), math.floor(p.z))
		if floorY then
			local wx, wz = worldXZ(plot, p.x, p.z)
			if kind == "mushroom" then
				local stem = part(
					parent,
					"Stem",
					Vector3.new(0.4, 1.4, 0.4),
					CFrame.new(wx, floorY + 0.7, wz),
					Color3.fromRGB(200, 220, 210),
					Enum.Material.SmoothPlastic
				)
				stem.CanCollide = false
				local cap = part(
					parent,
					"Cap",
					Vector3.new(1.6, 0.5, 1.6),
					CFrame.new(wx, floorY + 1.5, wz),
					color,
					Enum.Material.Neon,
					Enum.PartType.Cylinder
				)
				cap.CFrame = CFrame.new(wx, floorY + 1.5, wz) * CFrame.Angles(0, 0, math.rad(90))
				cap.CanCollide = false
				CaveProps.light(cap, color, 12, 0.9)
			else
				local shard = part(
					parent,
					"Glow",
					Vector3.new(0.6, 1.8, 0.6),
					CFrame.new(wx, floorY + 0.8, wz) * CFrame.Angles(0.2, s, 0.15),
					color,
					Enum.Material.Neon
				)
				shard.CanCollide = false
				CaveProps.light(shard, color, 12, 0.9)
			end
		end
	end
end

-- Chambers --------------------------------------------------------------------------------------

-- Random open floor positions inside a chamber (deterministic).
local function floorSpots(plot: Plot, feature: Caves.Feature, count: number, salt: number): { Vector3 }
	local spots = {}
	local c = feature.center
	if not c or not feature.rx or not feature.rz then
		return spots
	end
	local rx, rz = feature.rx :: number, feature.rz :: number
	for i = 1, count * 4 do
		if #spots >= count then
			break
		end
		local u = Hash.unit(plot.seed, i, salt, 0, 701)
		local v = Hash.unit(plot.seed, i, salt, 1, 701)
		local x = math.floor(c.x + (u - 0.5) * rx * 1.6)
		local z = math.floor(c.z + (v - 0.5) * rz * 1.6)
		local floorY = column(plot, x, math.floor(c.d), z)
		if floorY then
			local wx, wz = worldXZ(plot, x + 0.5, z + 0.5)
			table.insert(spots, Vector3.new(wx, floorY, wz))
		end
	end
	return spots
end

local function chamberProps(
	plot: Plot,
	feature: Caves.Feature,
	style: string,
	accent: Color3,
	parent: Instance,
	salt: number
)
	if style == "mine" then
		local spots = floorSpots(plot, feature, 3, salt)
		for i, at in spots do
			if i == 1 then
				part(
					parent,
					"LampPost",
					Vector3.new(0.5, 6, 0.5),
					CFrame.new(at + Vector3.new(0, 3, 0)),
					WOOD,
					Enum.Material.Wood
				)
				local bulb = part(
					parent,
					"Lamp",
					Vector3.new(0.8, 0.9, 0.8),
					CFrame.new(at + Vector3.new(0, 6.3, 0)),
					Color3.fromRGB(255, 190, 90),
					Enum.Material.Neon
				)
				bulb.CanCollide = false
				CaveProps.light(bulb, Color3.fromRGB(255, 180, 90), 26, 1.4)
			else
				part(
					parent,
					"Crate",
					Vector3.new(2.2, 2.2, 2.2),
					CFrame.new(at + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, i, 0),
					WOOD,
					Enum.Material.WoodPlanks
				)
			end
		end
	elseif style == "ruin" then
		for i, at in floorSpots(plot, feature, 2, salt) do
			part(
				parent,
				"Column",
				Vector3.new(1.8, 7, 1.8),
				CFrame.new(at + Vector3.new(0, 3.5, 0)),
				Color3.fromRGB(206, 184, 140),
				Enum.Material.Sandstone
			)
			local glyph = part(
				parent,
				"Glyph",
				Vector3.new(0.1, 1.2, 1.2),
				CFrame.new(at + Vector3.new(0.95, 4, 0)),
				Color3.fromRGB(80, 230, 255),
				Enum.Material.Neon
			)
			glyph.CanCollide = false
			if i == 1 then
				CaveProps.light(glyph, Color3.fromRGB(80, 230, 255), 18, 1)
			end
		end
	elseif style == "lava" then
		for i, at in floorSpots(plot, feature, 4, salt) do
			local ember = part(
				parent,
				"Ember",
				Vector3.new(2, 1.2, 1.6),
				CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, i, 0.2),
				Color3.fromRGB(255, 110, 30),
				Enum.Material.Neon
			)
			ember.CanCollide = false
			if i <= 2 then
				CaveProps.light(ember, Color3.fromRGB(255, 120, 40), 20, 1.3)
			end
		end
	elseif style == "abyss" then
		for _, at in floorSpots(plot, feature, 5, salt) do
			local cap = part(
				parent,
				"GlowCap",
				Vector3.new(0.6, 2.2, 2.2),
				CFrame.new(at + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				accent,
				Enum.Material.Neon,
				Enum.PartType.Cylinder
			)
			cap.CanCollide = false
			part(
				parent,
				"GlowStem",
				Vector3.new(0.5, 2, 0.5),
				CFrame.new(at + Vector3.new(0, 1, 0)),
				Color3.fromRGB(190, 210, 210),
				Enum.Material.SmoothPlastic
			).CanCollide =
				false
			CaveProps.light(cap, accent, 14, 0.8)
		end
	else
		-- crystal / core: clusters of glowing shards
		local color = accent
		for i, at in floorSpots(plot, feature, 5, salt) do
			for k = 1, 3 do
				local h = 1.6 + Hash.unit(plot.seed, i, k, salt, 703) * 2.6
				local shard = part(
					parent,
					"Crystal",
					Vector3.new(0.7, h, 0.7),
					CFrame.new(at + Vector3.new((k - 2) * 0.7, h / 2 - 0.3, (k % 2) * 0.6))
						* CFrame.Angles((k - 2) * 0.25, i, (k % 2 - 0.5) * 0.4),
					color,
					Enum.Material.Neon
				)
				shard.CanCollide = false
				shard.Transparency = 0.1
			end
			if i <= 2 then
				local anchor = part(
					parent,
					"CrystalLight",
					Vector3.new(0.2, 0.2, 0.2),
					CFrame.new(at + Vector3.new(0, 2, 0)),
					color,
					Enum.Material.Neon
				)
				anchor.Transparency = 1
				anchor.CanCollide = false
				CaveProps.light(anchor, color, 22, 1.2)
			end
		end
	end
end

-- Decorates every feature of a sector into a new Model under `parent`.
function CaveProps.decorate(plot: Plot, sector: Caves.Sector, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Sector_" .. sector.index
	local zone = Zones.at(sector.top + Caves.SectorHeight / 2)
	local accent = if sector.style == "crystal" then Color3.fromRGB(130, 170, 255) else zone.accent
	for i, feature in sector.features do
		if feature.kind == "tunnel" then
			if sector.style == "mine" or sector.style == "ruin" then
				mineSupports(plot, feature, model)
			elseif sector.style == "abyss" then
				glowMarkers(plot, feature, model, accent, "mushroom")
			else
				glowMarkers(plot, feature, model, accent, "shard")
			end
		elseif feature.kind == "chamber" then
			chamberProps(plot, feature, sector.style, accent, model, sector.index * 10 + i)
		end
	end
	model.Parent = parent
	return model
end

-- Chest -----------------------------------------------------------------------------------------

function CaveProps.chest(plot: Plot, spot: Caves.Spot, parent: Instance): Model
	local center = Grid.cellCenter(plot.originX, plot.originZ, spot.cx, spot.d, spot.cz)
	local floorY = center.Y - CELL / 2
	local model = Instance.new("Model")
	model.Name = "Chest_" .. spot.id
	local wood = Color3.fromRGB(130, 84, 46)
	local gold = Color3.fromRGB(240, 190, 60)
	local base = part(
		model,
		"Base",
		Vector3.new(2.6, 1.4, 1.7),
		CFrame.new(center.X, floorY + 0.7, center.Z),
		wood,
		Enum.Material.WoodPlanks
	)
	part(
		model,
		"Band",
		Vector3.new(2.7, 0.25, 1.8),
		CFrame.new(center.X, floorY + 1.1, center.Z),
		gold,
		Enum.Material.Metal
	)
	part(
		model,
		"Lid",
		Vector3.new(2.6, 0.7, 1.7),
		CFrame.new(center.X, floorY + 1.75, center.Z),
		wood,
		Enum.Material.WoodPlanks
	)
	part(
		model,
		"Lock",
		Vector3.new(0.4, 0.5, 0.2),
		CFrame.new(center.X, floorY + 1.35, center.Z - 0.9),
		gold,
		Enum.Material.Metal
	)
	model.PrimaryPart = base
	model.Parent = parent
	return model
end

-- Geode -----------------------------------------------------------------------------------------
-- A lumpy rock shell around the 3x3x3 pocket; glowing crystals wait inside, hidden until opened.

function CaveProps.geode(plot: Plot, spot: Caves.Spot, crystalColor: Color3, parent: Instance): Model
	local center = Grid.cellCenter(plot.originX, plot.originZ, spot.cx, spot.d, spot.cz)
	local model = Instance.new("Model")
	model.Name = "Geode_" .. spot.id
	local crust = Color3.fromRGB(118, 104, 96)
	local shell = part(
		model,
		"Shell",
		Vector3.new(7.2, 6.6, 7.2),
		CFrame.new(center) * CFrame.Angles(0.2, 0.7, 0.1),
		crust,
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	for i = 1, 5 do
		local a = i * 1.9
		local lump = part(
			model,
			"Lump",
			Vector3.new(2.6, 2.2, 2.4),
			CFrame.new(center + Vector3.new(math.cos(a) * 3, ((i % 3) - 1) * 2, math.sin(a) * 3))
				* CFrame.Angles(a, a * 0.7, 0.3),
			crust,
			Enum.Material.Slate
		)
		lump.Name = "Lump"
	end
	-- The seam: a faint glowing crack hinting at what is inside.
	local seam = part(
		model,
		"Seam",
		Vector3.new(7.3, 0.15, 0.4),
		CFrame.new(center) * CFrame.Angles(0, 0.7, 0.25),
		crystalColor,
		Enum.Material.Neon
	)
	seam.CanCollide = false
	local interior = Instance.new("Folder")
	interior.Name = "Interior"
	interior.Parent = model
	for i = 1, 7 do
		local a = i * 0.9
		local h = 1.2 + (i % 3) * 0.6
		local crystal = part(
			interior,
			"Crystal",
			Vector3.new(0.6, h, 0.6),
			CFrame.new(center + Vector3.new(math.cos(a) * 1.4, -0.8 + (i % 2) * 1.2, math.sin(a) * 1.4))
				* CFrame.Angles(math.cos(a) * 0.6, a, math.sin(a) * 0.6),
			crystalColor,
			Enum.Material.Neon
		)
		crystal.CanCollide = false
		crystal.Transparency = 1 -- shown when the geode opens
	end
	model.PrimaryPart = shell
	model.Parent = parent
	return model
end

-- Fossil ----------------------------------------------------------------------------------------
-- Bones lie in a two-cell pocket (8 x 4 x 4 studs), along the pocket's axis. Each species has its
-- own silhouette so the collection reads at a glance.

local BONE = Color3.fromRGB(226, 214, 184)
local BONE_DARK = Color3.fromRGB(176, 162, 132)

function CaveProps.fossil(
	plot: Plot,
	bed: { cx: number, d: number, cz: number, alongX: boolean },
	model: string,
	parent: Instance
): Model
	local a = Grid.cellCenter(plot.originX, plot.originZ, bed.cx, bed.d, bed.cz)
	local b = if bed.alongX
		then Grid.cellCenter(plot.originX, plot.originZ, bed.cx + 1, bed.d, bed.cz)
		else Grid.cellCenter(plot.originX, plot.originZ, bed.cx, bed.d, bed.cz + 1)
	local mid = (a + b) / 2
	local floorY = mid.Y - CELL / 2
	-- local frame: +Z runs along the pocket, Y up, origin on the floor at the middle
	local frame = CFrame.lookAt(Vector3.new(mid.X, floorY, mid.Z), Vector3.new(b.X, floorY, b.Z))
	local m = Instance.new("Model")
	m.Name = "Fossil_" .. model
	local function bone(name: string, size: Vector3, offset: CFrame, color: Color3?, shape: Enum.PartType?): Part
		local p = part(m, name, size, frame * offset, color or BONE, Enum.Material.Limestone, shape)
		p.CanCollide = false
		return p
	end

	if model == "shell" then
		for i = -2, 2 do
			bone(
				"Plate",
				Vector3.new(2.2 - math.abs(i) * 0.25, 0.7, 0.9),
				CFrame.new(0, 0.5, i * 0.85) * CFrame.Angles(0.15, 0, 0)
			)
		end
		bone("Head", Vector3.new(1.2, 0.6, 0.9), CFrame.new(0, 0.45, -2.4), BONE_DARK)
		for _, side in { -1, 1 } do
			for k = -1, 1 do
				bone(
					"Leg",
					Vector3.new(1.2, 0.15, 0.15),
					CFrame.new(side * 1.5, 0.3, k * 0.9) * CFrame.Angles(0, side * 0.4, side * 0.3)
				)
			end
		end
	elseif model == "coil" then
		for i = 0, 13 do
			local t = i / 13 * math.pi * 3.2
			local r = 0.5 + i * 0.09
			bone(
				"Ring",
				Vector3.new(0.55, 0.55, 0.55),
				CFrame.new(math.cos(t) * r, 0.35, math.sin(t) * r),
				nil,
				Enum.PartType.Ball
			)
		end
	elseif model == "fish" or model == "crystal" then
		bone("Spine", Vector3.new(0.3, 0.3, 5.6), CFrame.new(0, 0.6, 0))
		for i = -2, 2 do
			for _, side in { -1, 1 } do
				bone(
					"Rib",
					Vector3.new(0.15, 1.3 - math.abs(i) * 0.15, 0.15),
					CFrame.new(side * 0.35, 0.6, i * 0.85) * CFrame.Angles(0, 0, side * 0.9)
				)
			end
		end
		bone("Skull", Vector3.new(1.1, 1, 1.3), CFrame.new(0, 0.7, -3.1), BONE_DARK)
		local tail = part(
			m,
			"Tail",
			Vector3.new(0.15, 1.4, 1.2),
			frame * CFrame.new(0, 0.7, 3.2),
			BONE,
			Enum.Material.Limestone,
			Enum.PartType.Wedge
		)
		tail.CanCollide = false
		if model == "crystal" then
			for i = 1, 5 do
				local shard = part(
					m,
					"Crystal",
					Vector3.new(0.35, 0.9 + (i % 3) * 0.4, 0.35),
					frame
						* CFrame.new((i % 2 - 0.5) * 0.8, 1.2, -2.2 + i * 0.9)
						* CFrame.Angles(0.3, i, (i % 2 - 0.5) * 0.8),
					Color3.fromRGB(110, 200, 255),
					Enum.Material.Neon
				)
				shard.CanCollide = false
			end
		end
	elseif model == "mole" then
		bone("Spine", Vector3.new(0.35, 0.35, 3.6), CFrame.new(0, 0.6, 0.4))
		bone("Skull", Vector3.new(1.2, 1, 1.5), CFrame.new(0, 0.7, -1.9), BONE_DARK, Enum.PartType.Ball)
		bone("Snout", Vector3.new(0.5, 0.45, 0.9), CFrame.new(0, 0.6, -2.8), BONE_DARK)
		for _, side in { -1, 1 } do
			for k = -1, 1 do -- six legs
				bone(
					"Leg",
					Vector3.new(1.4, 0.2, 0.2),
					CFrame.new(side * 0.9, 0.35, k * 1.1 + 0.3) * CFrame.Angles(0, side * 0.5, 0)
				)
				bone("Claw", Vector3.new(0.5, 0.15, 0.4), CFrame.new(side * 1.6, 0.25, k * 1.1 + 0.1))
			end
		end
	elseif model == "wing" then
		bone("Root", Vector3.new(0.4, 0.4, 1.4), CFrame.new(0, 0.5, -2.6))
		for i = 1, 6 do
			local angle = -0.75 + i * 0.25
			bone(
				"Feather",
				Vector3.new(0.18, 0.12, 4.2 - math.abs(i - 3.5) * 0.4),
				CFrame.new(0, 0.4, -2.4) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 2.1)
			)
		end
	elseif model == "salamander" then
		-- long body, four splayed legs, a tail that curls back on itself
		bone("Spine", Vector3.new(0.3, 0.3, 3.2), CFrame.new(0, 0.5, -0.4))
		bone("Skull", Vector3.new(0.9, 0.5, 1.2), CFrame.new(0, 0.55, -2.5), BONE_DARK)
		for i = 0, 5 do
			local t = i / 5
			bone(
				"Tail",
				Vector3.new(0.28 - t * 0.15, 0.25, 0.7),
				CFrame.new(math.sin(t * 2.4) * 1.2, 0.4, 1.4 + t * 1.8) * CFrame.Angles(0, t * 1.3, 0)
			)
		end
		for _, side in { -1, 1 } do
			for _, k in { -1.4, 0.6 } do
				bone(
					"Leg",
					Vector3.new(1.3, 0.18, 0.18),
					CFrame.new(side * 0.8, 0.35, k) * CFrame.Angles(0, side * 0.6, 0)
				)
			end
		end
		-- the tool marks on the vertebrae
		for i = 1, 3 do
			bone("Mark", Vector3.new(0.34, 0.05, 0.08), CFrame.new(0, 0.66, -1.2 + i * 0.5), BONE_DARK)
		end
	elseif model == "hand" then
		-- a palm and five fingers closed around a wooden handle that never turned to stone
		local handle = part(
			m,
			"Handle",
			Vector3.new(0.35, 0.35, 5.4),
			frame * CFrame.new(0, 0.55, 0.3),
			Color3.fromRGB(122, 86, 54),
			Enum.Material.Wood,
			Enum.PartType.Cylinder
		)
		handle.CFrame = frame * CFrame.new(0, 0.55, 0.3) * CFrame.Angles(0, math.rad(90), 0)
		handle.Size = Vector3.new(5.4, 0.35, 0.35)
		handle.CanCollide = false
		bone("Palm", Vector3.new(1.1, 0.35, 1.2), CFrame.new(0.45, 0.6, -0.9))
		for f = 0, 3 do
			bone(
				"Finger",
				Vector3.new(0.22, 0.22, 0.7),
				CFrame.new(-0.05, 0.85, -1.4 + f * 0.33) * CFrame.Angles(0, 0, 0.9)
			)
		end
		bone("Thumb", Vector3.new(0.24, 0.24, 0.8), CFrame.new(0.5, 0.95, -0.2) * CFrame.Angles(0.4, 0, -0.5))
		bone("Wrist", Vector3.new(0.5, 0.4, 1.2), CFrame.new(0.9, 0.45, -1.7), BONE_DARK)
	elseif model == "eye" then
		-- an eye socket bigger than a door, looking up
		bone("Socket", Vector3.new(3.6, 1, 3.6), CFrame.new(0, 0.5, 0), BONE_DARK, Enum.PartType.Cylinder).CFrame = frame
			* CFrame.new(0, 0.5, 0)
			* CFrame.Angles(0, 0, math.rad(90))
		bone("Eye", Vector3.new(3, 3, 3), CFrame.new(0, 0.9, 0), Color3.fromRGB(214, 206, 188), Enum.PartType.Ball)
		local iris = part(
			m,
			"Iris",
			Vector3.new(0.12, 1.5, 1.5),
			frame * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(26, 60, 58),
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		iris.CanCollide = false
	elseif model == "rings" then
		-- three rings of bone, six marks each: the Counter's machine, alive
		for r = 1, 3 do
			local radius = 0.8 + r * 0.35
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				bone(
					"Ring",
					Vector3.new(0.4, 0.4, 0.4),
					CFrame.new(math.cos(a) * radius, 0.35 + r * 0.05, math.sin(a) * radius),
					if k == 0 then BONE_DARK else nil,
					Enum.PartType.Ball
				)
			end
		end
		bone("Core", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0.5, 0), BONE_DARK, Enum.PartType.Ball)
	else -- "imprint": a slab of darker rock with the silhouette of a shovel pressed into it
		local slab = part(
			m,
			"Slab",
			Vector3.new(2.6, 0.6, 6.6),
			frame * CFrame.new(0, 0.3, 0),
			Color3.fromRGB(96, 90, 92),
			Enum.Material.Slate
		)
		slab.CanCollide = false
		local mark = Color3.fromRGB(150, 140, 130)
		bone("Handle", Vector3.new(0.3, 0.05, 3.4), CFrame.new(0, 0.62, 1.2), mark)
		bone("Grip", Vector3.new(0.9, 0.05, 0.25), CFrame.new(0, 0.62, 2.9), mark)
		bone("Blade", Vector3.new(1.3, 0.05, 1.5), CFrame.new(0, 0.62, -1.3), mark)
		bone("Tip", Vector3.new(0.7, 0.05, 0.5), CFrame.new(0, 0.62, -2.25), mark)
	end

	-- the first part is the pivot used for distance checks and effects
	local pivot =
		part(m, "Pivot", Vector3.new(0.2, 0.2, 0.2), frame * CFrame.new(0, 0.6, 0), BONE, Enum.Material.Limestone)
	pivot.Transparency = 1
	pivot.CanCollide = false
	m.PrimaryPart = pivot
	m.Parent = parent
	return m
end

return CaveProps
