--!strict
-- Builds the scenes planned by Logic/ScenePlan out of parts. Each kind is a small, hand-designed
-- model (1-10 parts). Only a few kinds carry a PointLight (heart crystal, vent, camp lantern) to
-- keep dynamic lights cheap. Living details (flicker, pulse, spin) are animated on the client
-- (AmbientLifeController) through CollectionService tags, only near the player.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Caves = require(script.Parent.Parent.Logic.Caves)
local ScenePlan = require(script.Parent.Parent.Logic.ScenePlan)
local CaveProps = require(script.Parent.CaveProps)

local CaveScenes = {}

local CELL = GameConfig.CellSize
local part = CaveProps.part
local light = CaveProps.light

type Plot = { originX: number, originZ: number, seed: number }

local WOOD = Color3.fromRGB(112, 78, 50)
local DARK_WOOD = Color3.fromRGB(78, 54, 36)
local RUST = Color3.fromRGB(120, 70, 44)
local IRON = Color3.fromRGB(70, 72, 78)
local CHALK = Color3.fromRGB(235, 232, 220)
local SANDSTONE = Color3.fromRGB(206, 184, 140)
local BASALT = Color3.fromRGB(42, 38, 40)
local EMBER = Color3.fromRGB(255, 120, 40)

-- Rock colour of the stalactites: close to the zone's main stone, a little darker.
local ROCK: { [string]: Color3 } = {
	garden = Color3.fromRGB(110, 100, 90),
	forgotten_mines = Color3.fromRGB(96, 90, 86),
	crystal_caves = Color3.fromRGB(74, 76, 104),
	ancient_caverns = Color3.fromRGB(150, 128, 92),
	volcanic_depths = Color3.fromRGB(48, 42, 42),
	abyss = Color3.fromRGB(30, 40, 48),
	unknown_core = Color3.fromRGB(176, 196, 204),
}

local function decor(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function tag(instance: Instance, name: string)
	CollectionService:AddTag(instance, name)
end

-- Builders --------------------------------------------------------------------------------------
-- `at` is the anchor point (floor surface or ceiling) with the prop's yaw applied.

type Ctx = { model: Model, at: CFrame, scale: number, variant: number, length: number, accent: Color3, rock: Color3 }

local function rails(c: Ctx)
	local length = c.length * CELL
	for _, side in { -1.1, 1.1 } do
		decor(
			part(
				c.model,
				"Rail",
				Vector3.new(0.22, 0.25, length),
				c.at * CFrame.new(side, 0.35, 0),
				IRON,
				Enum.Material.Metal
			)
		)
	end
	local sleepers = math.min(10, math.floor(length / 2.6))
	for k = 1, sleepers do
		local z = -length / 2 + (k - 0.5) * (length / sleepers)
		decor(
			part(
				c.model,
				"Sleeper",
				Vector3.new(3.2, 0.22, 0.6),
				c.at * CFrame.new(0, 0.12, z),
				DARK_WOOD,
				Enum.Material.Wood
			)
		)
	end
end

local function cart(c: Ctx)
	local tipped = c.variant == 2
	local base = if tipped
		then c.at * CFrame.new(0.6, 1.1, 0) * CFrame.Angles(0, 0, math.rad(100))
		else c.at * CFrame.new(0, 1.15, 0)
	part(c.model, "CartBody", Vector3.new(2.6, 1.5, 3.4), base, RUST, Enum.Material.CorrodedMetal)
	for _, x in { -1.35, 1.35 } do
		for _, z in { -1.1, 1.1 } do
			decor(
				part(
					c.model,
					"Wheel",
					Vector3.new(0.3, 1, 1),
					base * CFrame.new(x, -0.75, z),
					IRON,
					Enum.Material.Metal,
					Enum.PartType.Cylinder
				)
			)
		end
	end
	-- the load: still in the cart, or spilled on the floor
	local ore = Color3.fromRGB(184, 115, 72)
	if tipped then
		for k = 1, 3 do
			decor(
				part(
					c.model,
					"SpilledOre",
					Vector3.new(0.9, 0.6, 0.8),
					c.at * CFrame.new(-0.8 - k * 0.6, 0.3, (k - 2) * 0.7) * CFrame.Angles(0, k, 0.3),
					ore,
					Enum.Material.Slate
				)
			)
		end
	else
		decor(part(c.model, "Ore", Vector3.new(2, 0.6, 2.6), base * CFrame.new(0, 0.7, 0), ore, Enum.Material.Slate))
	end
end

local function camp(c: Ctx)
	-- E.'s camp: bedroll, crate with a lantern, a pickaxe against it, the cold fire, a mark.
	local red = Color3.fromRGB(140, 52, 44)
	decor(
		part(
			c.model,
			"Bedroll",
			Vector3.new(4.2, 0.8, 0.8),
			c.at * CFrame.new(-2, 0.4, 0) * CFrame.Angles(0, math.rad(90), 0),
			red,
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
	)
	part(
		c.model,
		"Crate",
		Vector3.new(1.8, 1.6, 1.8),
		c.at * CFrame.new(1.4, 0.8, -1.2) * CFrame.Angles(0, 0.3, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	local lantern = decor(
		part(
			c.model,
			"Lantern",
			Vector3.new(0.5, 0.7, 0.5),
			c.at * CFrame.new(1.4, 1.95, -1.2),
			Color3.fromRGB(255, 190, 90),
			Enum.Material.Neon
		)
	)
	light(lantern, Color3.fromRGB(255, 176, 90), 18, 1.1)
	tag(lantern, "THNE_Flicker")
	-- pickaxe leaning against the crate
	local lean = c.at * CFrame.new(2.5, 1.1, -0.4) * CFrame.Angles(0, 0, math.rad(-25))
	decor(part(c.model, "PickHandle", Vector3.new(0.18, 2.4, 0.18), lean, WOOD, Enum.Material.Wood))
	decor(
		part(c.model, "PickHead", Vector3.new(1.4, 0.2, 0.2), lean * CFrame.new(0, 1.15, 0), IRON, Enum.Material.Metal)
	)
	-- cold fire: a ring of ash and two burnt logs
	decor(
		part(
			c.model,
			"Ash",
			Vector3.new(0.12, 1.6, 1.6),
			c.at * CFrame.new(0, 0.06, 2) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(56, 52, 50),
			Enum.Material.Slate,
			Enum.PartType.Cylinder
		)
	)
	for k = -1, 1, 2 do
		decor(
			part(
				c.model,
				"Log",
				Vector3.new(1.4, 0.3, 0.3),
				c.at * CFrame.new(0, 0.2, 2) * CFrame.Angles(0, k * 0.6, 0),
				Color3.fromRGB(30, 26, 24),
				Enum.Material.Wood
			)
		)
	end
	-- "E." scratched on a plank, the same hand as the notes and the miner's box
	local plank = part(
		c.model,
		"Plank",
		Vector3.new(1.6, 0.9, 0.12),
		c.at * CFrame.new(1.4, 0.8, -0.28) * CFrame.Angles(0, 0.3, 0),
		Color3.fromRGB(150, 116, 74),
		Enum.Material.Wood
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = plank
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "E."
	label.TextScaled = true
	label.Font = Enum.Font.Antique
	label.TextColor3 = Color3.fromRGB(40, 30, 24)
	label.Parent = gui
end

local function chalk(c: Ctx)
	-- an arrow on the floor pointing further down the gallery
	local at = c.at * CFrame.new(0, 0.03, 0)
	decor(part(c.model, "Chalk", Vector3.new(0.16, 0.04, 1.3), at, CHALK, Enum.Material.SmoothPlastic)).Transparency =
		0.2
	for _, side in { -1, 1 } do
		decor(
			part(
				c.model,
				"Chalk",
				Vector3.new(0.16, 0.04, 0.6),
				at * CFrame.new(side * 0.2, 0, 0.5) * CFrame.Angles(0, side * math.rad(-40), 0),
				CHALK,
				Enum.Material.SmoothPlastic
			)
		).Transparency =
			0.2
	end
end

local function spike(c: Ctx, down: boolean)
	-- three tapered blocks: hanging (stalactite) or rising (stalagmite)
	local sign = if down then -1 else 1
	local heights = { 1.6, 1.4, 1.2 }
	local widths = { 1.5, 1, 0.55 }
	local tall = (0.8 + c.variant * 0.35) * c.scale
	local y = 0
	for k = 1, 3 do
		local h = heights[k] * tall
		local w = widths[k] * c.scale
		local p = part(
			c.model,
			if down then "Stalactite" else "Stalagmite",
			Vector3.new(w, h, w),
			c.at * CFrame.new(0, sign * (y + h / 2 - 0.3), 0) * CFrame.Angles(0, k * 0.7, 0),
			c.rock,
			Enum.Material.Slate
		)
		if down or k > 1 then
			decor(p)
		end
		y += h * 0.92
	end
end

local function crystalHang(c: Ctx)
	for k = 1, 3 do
		local h = (1.4 + k * 0.6) * c.scale
		local shard = decor(
			part(
				c.model,
				"HangingCrystal",
				Vector3.new(0.55, h, 0.55),
				c.at
					* CFrame.new((k - 2) * 0.6, -h / 2 + 0.2, (k % 2) * 0.5)
					* CFrame.Angles((k - 2) * 0.22, k, (k % 2 - 0.5) * 0.3),
				c.accent,
				Enum.Material.Neon
			)
		)
		shard.Transparency = 0.12
		if k == 2 then
			tag(shard, "THNE_Pulse")
		end
	end
end

local function crystalHeart(c: Ctx)
	local heart = decor(
		part(
			c.model,
			"HeartCrystal",
			Vector3.new(2.2, 9 * c.scale, 2.2),
			c.at * CFrame.new(0, 4.2 * c.scale, 0) * CFrame.Angles(0.12, 0, 0.08),
			c.accent,
			Enum.Material.Neon
		)
	)
	heart.Transparency = 0.08
	heart:SetAttribute("PulsePeriod", 4.5)
	tag(heart, "THNE_Pulse")
	light(heart, c.accent, 30, 1.4)
	for k = 1, 4 do
		local angle = k * math.pi / 2 + 0.4
		local h = 2 + (k % 2) * 1.6
		decor(
			part(
				c.model,
				"Crystal",
				Vector3.new(0.8, h, 0.8),
				c.at
					* CFrame.new(math.cos(angle) * 1.9, h / 2 - 0.2, math.sin(angle) * 1.9)
					* CFrame.Angles(math.cos(angle) * 0.35, 0, math.sin(angle) * 0.35),
				c.accent,
				Enum.Material.Neon
			)
		).Transparency =
			0.15
	end
	-- a solid core so the heart is not walk-through
	part(c.model, "HeartBase", Vector3.new(2.6, 1.2, 2.6), c.at * CFrame.new(0, 0.4, 0), c.rock, Enum.Material.Slate)
end

local function arch(c: Ctx)
	local glyphColor = Color3.fromRGB(80, 230, 255)
	if c.variant == 1 then
		for _, x in { -3.5, 3.5 } do
			part(
				c.model,
				"ArchColumn",
				Vector3.new(1.8, 8, 1.8),
				c.at * CFrame.new(x, 4, 0),
				SANDSTONE,
				Enum.Material.Sandstone
			)
		end
		part(
			c.model,
			"Lintel",
			Vector3.new(9.2, 1.4, 2),
			c.at * CFrame.new(0, 8.7, 0),
			SANDSTONE,
			Enum.Material.Sandstone
		)
		decor(
			part(
				c.model,
				"Glyph",
				Vector3.new(1.1, 1.1, 0.08),
				c.at * CFrame.new(0, 8.7, 1.02),
				glyphColor,
				Enum.Material.Neon
			)
		)
	else
		-- collapsed: one column still standing, the other and the lintel on the floor
		part(
			c.model,
			"ArchColumn",
			Vector3.new(1.8, 8, 1.8),
			c.at * CFrame.new(-3.5, 4, 0),
			SANDSTONE,
			Enum.Material.Sandstone
		)
		part(
			c.model,
			"FallenColumn",
			Vector3.new(1.8, 7, 1.8),
			c.at * CFrame.new(2.5, 0.9, 1.5) * CFrame.Angles(math.rad(90), 0.4, 0),
			SANDSTONE,
			Enum.Material.Sandstone
		)
		part(
			c.model,
			"FallenLintel",
			Vector3.new(6, 1.4, 2),
			c.at * CFrame.new(0.5, 0.75, -2) * CFrame.Angles(0, 0.25, math.rad(8)),
			SANDSTONE,
			Enum.Material.Sandstone
		)
		decor(
			part(
				c.model,
				"Glyph",
				Vector3.new(1.1, 0.08, 1.1),
				c.at * CFrame.new(0.5, 1.5, -2),
				glyphColor,
				Enum.Material.Neon
			)
		).Transparency =
			0.3
	end
end

local function fallenColumn(c: Ctx)
	part(
		c.model,
		"FallenColumn",
		Vector3.new(1.8, 8 * c.scale, 1.8),
		c.at * CFrame.new(0, 0.9, 0) * CFrame.Angles(math.rad(90), 0, 0),
		SANDSTONE,
		Enum.Material.Sandstone
	)
	part(
		c.model,
		"ColumnDrum",
		Vector3.new(2, 1.2, 2),
		c.at * CFrame.new(1.6, 0.6, 4.6 * c.scale) * CFrame.Angles(0, 0.5, 0.2),
		SANDSTONE,
		Enum.Material.Sandstone
	)
end

local function basalt(c: Ctx)
	local count = 3 + c.variant
	for k = 1, count do
		local angle = k * 2.4
		local r = if k == 1 then 0 else 1.2 + (k % 2) * 0.5
		local h = (3 + ((k * 37) % 5)) * c.scale
		local column = part(
			c.model,
			"Basalt",
			Vector3.new(h, 1.4, 1.4),
			c.at * CFrame.new(math.cos(angle) * r, h / 2 - 0.2, math.sin(angle) * r) * CFrame.Angles(0, 0, math.rad(90)),
			BASALT,
			Enum.Material.Basalt,
			Enum.PartType.Cylinder
		)
		if k > 2 then
			decor(column)
		end
	end
	decor(
		part(
			c.model,
			"Crack",
			Vector3.new(0.12, 2.2 * c.scale, 0.25),
			c.at * CFrame.new(0, 1.4 * c.scale, 0.71),
			EMBER,
			Enum.Material.Neon
		)
	)
end

local function vent(c: Ctx)
	local crack = decor(
		part(c.model, "Vent", Vector3.new(2.6, 0.1, 0.5), c.at * CFrame.new(0, 0.05, 0), EMBER, Enum.Material.Neon)
	)
	light(crack, EMBER, 22, 1.2)
	tag(crack, "THNE_Flicker")
	local embers = Instance.new("ParticleEmitter")
	embers.Rate = 5
	embers.Lifetime = NumberRange.new(2, 3.5)
	embers.Speed = NumberRange.new(2, 4)
	embers.SpreadAngle = Vector2.new(15, 15)
	embers.Acceleration = Vector3.new(0, 1.5, 0)
	embers.Size = NumberSequence.new(0.15, 0.05)
	embers.Color = ColorSequence.new(EMBER)
	embers.LightEmission = 1
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Parent = crack
end

local function vine(c: Ctx)
	local segments = 2 + c.variant
	local at = c.at
	for k = 1, segments do
		local seg = decor(
			part(
				c.model,
				"Vine",
				Vector3.new(0.22, 1.6, 0.22),
				at * CFrame.new(0, -0.8, 0),
				Color3.fromRGB(30, 70, 66),
				Enum.Material.Grass
			)
		)
		at = seg.CFrame * CFrame.new(0, -0.8, 0) * CFrame.Angles(0.15 * (k % 2 - 0.5), 0, 0.2 * ((k + 1) % 2 - 0.5))
	end
	local bulb = decor(
		part(c.model, "VineBulb", Vector3.new(0.6, 0.6, 0.6), at, c.accent, Enum.Material.Neon, Enum.PartType.Ball)
	)
	bulb:SetAttribute("PulsePeriod", 5)
	tag(bulb, "THNE_Pulse")
end

local function spores(c: Ctx)
	local anchor = decor(
		part(c.model, "Spores", Vector3.new(6, 1, 6), c.at * CFrame.new(0, 1, 0), c.accent, Enum.Material.SmoothPlastic)
	)
	anchor.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = 3
	e.Lifetime = NumberRange.new(6, 9)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.Acceleration = Vector3.new(0, 0.25, 0)
	e.Size = NumberSequence.new(0.18, 0.08)
	e.Color = ColorSequence.new(c.accent)
	e.LightEmission = 1
	e.Parent = anchor
end

local function shard(c: Ctx)
	local height = 2.6 + c.variant * 0.9
	local s = decor(
		part(
			c.model,
			"FloatingShard",
			Vector3.new(1, 1, 1) * (0.9 + c.scale * 0.6),
			c.at * CFrame.new(0, height, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color3.fromRGB(236, 250, 255),
			Enum.Material.Neon
		)
	)
	s.Transparency = 0.1
	s:SetAttribute("SpinSpeed", 0.4 + c.variant * 0.2)
	tag(s, "THNE_Spin")
end

local BUILDERS: { [string]: (Ctx) -> () } = {
	rails = rails,
	cart = cart,
	camp = camp,
	chalk = chalk,
	stalactite = function(c)
		spike(c, true)
	end,
	stalagmite = function(c)
		spike(c, false)
	end,
	crystal_hang = crystalHang,
	crystal_heart = crystalHeart,
	arch = arch,
	fallen_column = fallenColumn,
	basalt = basalt,
	vent = vent,
	vine = vine,
	spores = spores,
	shard = shard,
}
CaveScenes.Kinds = BUILDERS

-- Builds the sector's scenes into a new Model under `parent`.
function CaveScenes.build(plot: Plot, sector: Caves.Sector, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Scenes_" .. sector.index
	local zone = Zones.at(sector.top + Caves.SectorHeight / 2)
	local accent = if sector.style == "crystal" then Color3.fromRGB(130, 170, 255) else zone.accent
	local rock = ROCK[zone.id] or ROCK.garden
	for _, prop in ScenePlan.plan(plot.seed, sector) do
		local builder = BUILDERS[prop.kind]
		if builder then
			local wx, wz = plot.originX + prop.x * CELL, plot.originZ + prop.z * CELL
			-- sink a little into smooth terrain so nothing floats over the rounded voxels
			local y = if prop.anchor == "floor"
				then GameConfig.SurfaceY - (prop.d + 1) * CELL - 0.3
				else GameConfig.SurfaceY - prop.d * CELL + 0.5
			builder({
				model = model,
				at = CFrame.new(wx, y, wz) * CFrame.Angles(0, prop.yaw, 0),
				scale = prop.scale,
				variant = prop.variant,
				length = prop.length or 0,
				accent = accent,
				rock = rock,
			})
		end
	end
	model.Parent = parent
	return model
end

return CaveScenes
