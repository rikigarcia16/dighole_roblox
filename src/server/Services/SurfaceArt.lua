--!strict
-- The surface's look: a premium cartoon village built from Parts (no external meshes or assets).
-- WorldBuilder decides where things go and keeps every interaction point; this module only knows
-- how things look. Shapes are chunky and rounded (Ball crowns, beveled trims), colours are bright
-- but harmonious, and the few moving things (smoke, butterflies, rotors, blinking lamps) are cheap:
-- particles or client animation through CollectionService tags (AmbientLifeController).

local CollectionService = game:GetService("CollectionService")

local SurfaceArt = {}

-- Palette -------------------------------------------------------------------------------------------
local C = {
	plaster = Color3.fromRGB(252, 240, 214),
	timber = Color3.fromRGB(112, 72, 44),
	timberLight = Color3.fromRGB(150, 100, 62),
	roof = Color3.fromRGB(222, 96, 70),
	roofDark = Color3.fromRGB(176, 66, 52),
	stone = Color3.fromRGB(168, 160, 150),
	stoneDark = Color3.fromRGB(126, 118, 112),
	trim = Color3.fromRGB(255, 252, 244),
	shutter = Color3.fromRGB(58, 156, 170),
	door = Color3.fromRGB(46, 128, 150),
	gold = Color3.fromRGB(255, 200, 70),
	windowGlow = Color3.fromRGB(255, 214, 140),
	soil = Color3.fromRGB(108, 72, 48),
	leafA = Color3.fromRGB(96, 190, 72),
	leafB = Color3.fromRGB(70, 160, 60),
	leafC = Color3.fromRGB(132, 214, 92),
	blossomA = Color3.fromRGB(255, 160, 196),
	blossomB = Color3.fromRGB(255, 196, 220),
	trunk = Color3.fromRGB(122, 82, 54),
	iron = Color3.fromRGB(54, 58, 66),
	lampGlow = Color3.fromRGB(255, 214, 140),
	brick = Color3.fromRGB(196, 92, 70),
	hazardY = Color3.fromRGB(255, 196, 40),
	hazardK = Color3.fromRGB(40, 40, 44),
	steel = Color3.fromRGB(150, 160, 172),
	awningA = Color3.fromRGB(236, 72, 72),
	awningB = Color3.fromRGB(255, 246, 232),
	marketA = Color3.fromRGB(70, 186, 96),
}
SurfaceArt.Palette = C

local FLOWERS = {
	Color3.fromRGB(255, 92, 110),
	Color3.fromRGB(255, 206, 64),
	Color3.fromRGB(176, 112, 255),
	Color3.fromRGB(255, 150, 210),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 140, 60),
}

-- Parts ---------------------------------------------------------------------------------------------
export type Props = {
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

local function part(parent: Instance, p: Props): BasePart
	local b: BasePart
	if p.wedge then
		b = Instance.new("WedgePart")
	else
		local x = Instance.new("Part")
		x.Shape = p.shape or Enum.PartType.Block
		b = x
	end
	b.Name = p.name or "Decor"
	b.Anchored = true
	b.Size = p.size
	b.CFrame = p.cframe
	b.Color = p.color
	b.Material = p.material or Enum.Material.SmoothPlastic
	b.Transparency = p.transparency or 0
	b.CanCollide = if p.collide == nil then true else p.collide
	b.CastShadow = if p.shadow == nil then true else p.shadow
	b.TopSurface = Enum.SurfaceType.Smooth
	b.BottomSurface = Enum.SurfaceType.Smooth
	b.Parent = parent
	return b
end
SurfaceArt.part = part

-- Decoration the player never stands on: no collisions, no queries (cheaper and never in the way).
local function deco(parent: Instance, p: Props): BasePart
	p.collide = false
	local b = part(parent, p)
	b.CanQuery = false
	b.CanTouch = false
	return b
end
SurfaceArt.deco = deco

local function light(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	-- decorative: switched off on low graphics (AmbientLifeController), the scene stays readable
	CollectionService:AddTag(l, "THNE_DecoLight")
	return l
end

function SurfaceArt.label(target: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.1
	gui.Parent = target
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.Font = font or Enum.Font.FredokaOne
	l.TextScaled = true
	l.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = l
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(40, 26, 18)
	stroke.Parent = l
	return l
end

-- A cylinder standing up (Roblox cylinders lie along X).
local function upright(position: Vector3): CFrame
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

-- Deterministic pseudo-random (stable layout on every server).
local function rng(seed: number)
	local r = Random.new(seed)
	return function(a: number, b: number): number
		return a + r:NextNumber() * (b - a)
	end
end
SurfaceArt.rng = rng

-- Nature --------------------------------------------------------------------------------------------

-- A round cartoon tree: thick tapered trunk and a crown of overlapping balls in three greens.
function SurfaceArt.tree(parent: Instance, base: Vector3, scale: number, seed: number, blossom: boolean?)
	local r = rng(seed)
	local trunkH = 6 * scale
	deco(parent, {
		name = "Trunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(trunkH, 1.6 * scale, 1.6 * scale),
		cframe = upright(base + Vector3.new(0, trunkH / 2, 0)),
		color = C.trunk,
		material = Enum.Material.Wood,
	}).CanCollide =
		true
	deco(parent, {
		name = "Root",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.8 * scale, 2.6 * scale, 2.6 * scale),
		cframe = upright(base + Vector3.new(0, 0.4 * scale, 0)),
		color = C.trunk,
		material = Enum.Material.Wood,
	})
	local colors = if blossom then { C.blossomA, C.blossomB, C.blossomA } else { C.leafB, C.leafA, C.leafC }
	local top = base + Vector3.new(0, trunkH, 0)
	local balls = {
		{ Vector3.new(0, 1.8, 0), 7.4 },
		{ Vector3.new(r(1.8, 2.6), 0.6, r(-1, 1)), 5.4 },
		{ Vector3.new(r(-2.6, -1.8), 0.9, r(-1, 1)), 5.6 },
		{ Vector3.new(r(-1, 1), 0.4, r(1.8, 2.6)), 5 },
		{ Vector3.new(r(-0.8, 0.8), 4.2, r(-0.8, 0.8)), 4.6 },
	}
	for i, b in balls do
		deco(parent, {
			name = "Crown",
			shape = Enum.PartType.Ball,
			size = Vector3.one * b[2] * scale,
			cframe = CFrame.new(top + b[1] * scale),
			color = colors[(i - 1) % 3 + 1],
			material = Enum.Material.SmoothPlastic,
		})
	end
	if blossom then
		for _ = 1, 4 do
			deco(parent, {
				name = "Petals",
				shape = Enum.PartType.Ball,
				size = Vector3.one * 0.7 * scale,
				cframe = CFrame.new(base + Vector3.new(r(-3, 3), 0.2, r(-3, 3)) * Vector3.new(scale, 1, scale)),
				color = C.blossomB,
				shadow = false,
			})
		end
	end
end

-- A tall cone-like tree made of stacked, shrinking discs.
function SurfaceArt.pine(parent: Instance, base: Vector3, scale: number)
	deco(parent, {
		name = "Trunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(3 * scale, 1.2 * scale, 1.2 * scale),
		cframe = upright(base + Vector3.new(0, 1.5 * scale, 0)),
		color = C.trunk,
		material = Enum.Material.Wood,
	}).CanCollide =
		true
	for i = 0, 3 do
		local d = (7 - i * 1.6) * scale
		deco(parent, {
			name = "Tier",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(2.4 * scale, d, d),
			cframe = upright(base + Vector3.new(0, (3.6 + i * 2.2) * scale, 0)),
			color = if i % 2 == 0 then Color3.fromRGB(52, 132, 72) else Color3.fromRGB(66, 152, 84),
		})
	end
	deco(parent, {
		name = "Tip",
		shape = Enum.PartType.Ball,
		size = Vector3.one * 1.6 * scale,
		cframe = CFrame.new(base + Vector3.new(0, 12.4 * scale, 0)),
		color = Color3.fromRGB(66, 152, 84),
	})
end

function SurfaceArt.bush(parent: Instance, base: Vector3, scale: number, seed: number, berries: boolean?)
	local r = rng(seed)
	for i = 1, 3 do
		deco(parent, {
			name = "Bush",
			shape = Enum.PartType.Ball,
			size = Vector3.one * r(2.4, 3.4) * scale,
			cframe = CFrame.new(
				base + Vector3.new(r(-1.4, 1.4), 1 * scale, r(-1.4, 1.4)) * Vector3.new(scale, 1, scale)
			),
			color = if i == 2 then C.leafA else C.leafB,
		})
	end
	if berries then
		for _ = 1, 4 do
			deco(parent, {
				name = "Berry",
				shape = Enum.PartType.Ball,
				size = Vector3.one * 0.45,
				cframe = CFrame.new(
					base + Vector3.new(r(-1.6, 1.6), r(1.4, 2.4), r(-1.6, 1.6)) * Vector3.new(scale, scale, scale)
				),
				color = Color3.fromRGB(230, 50, 80),
				shadow = false,
			})
		end
	end
end

-- A low-poly rock: three rotated chunks, a bit of moss on top.
function SurfaceArt.rock(parent: Instance, base: Vector3, scale: number, seed: number)
	local r = rng(seed)
	for i = 1, 3 do
		local s = Vector3.new(r(2.4, 4), r(1.6, 3), r(2.4, 4)) * scale * (if i == 1 then 1.2 else 0.8)
		local p = part(parent, {
			name = "Rock",
			size = s,
			cframe = CFrame.new(base + Vector3.new(r(-1.4, 1.4) * scale, s.Y * 0.35, r(-1.4, 1.4) * scale))
				* CFrame.Angles(r(-0.3, 0.3), r(0, 6.28), r(-0.3, 0.3)),
			color = if i == 2 then C.stoneDark else C.stone,
			material = Enum.Material.Slate,
		})
		if i == 1 then
			for m = 1, 3 do
				deco(parent, {
					name = "Moss",
					shape = Enum.PartType.Ball,
					size = Vector3.one * r(0.8, 1.3) * scale,
					cframe = CFrame.new(p.Position + Vector3.new(r(-1, 1) * scale, s.Y * 0.45, r(-1, 1) * scale)),
					color = if m == 2 then C.leafA else C.leafB,
				})
			end
		end
	end
end

-- A patch of flowers: thin stems with bright round heads, a couple of leaves.
function SurfaceArt.flowers(parent: Instance, center: Vector3, radius: number, count: number, seed: number)
	local r = rng(seed)
	for i = 1, count do
		local a = r(0, 6.28)
		local d = math.sqrt(r(0, 1)) * radius
		local p = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local h = r(1.1, 1.8)
		deco(parent, {
			name = "Stem",
			size = Vector3.new(0.18, h, 0.18),
			cframe = CFrame.new(p + Vector3.new(0, h / 2, 0)),
			color = C.leafB,
			shadow = false,
		})
		deco(parent, {
			name = "Bloom",
			shape = Enum.PartType.Ball,
			size = Vector3.one * r(0.7, 1),
			cframe = CFrame.new(p + Vector3.new(0, h, 0)),
			color = FLOWERS[(seed + i) % #FLOWERS + 1],
			shadow = false,
		})
	end
end

-- A round flower bed: a low soil mound with a stone ring and a patch of flowers on top (the
-- caller bares the ground under it, so the terrain's grass does not hide the flowers).
function SurfaceArt.flowerBed(parent: Instance, center: Vector3, radius: number, count: number, seed: number)
	deco(parent, {
		name = "BedRing",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.7, radius * 2 + 1.2, radius * 2 + 1.2),
		cframe = upright(center + Vector3.new(0, 0.3, 0)),
		color = C.stone,
		material = Enum.Material.Slate,
	})
	deco(parent, {
		name = "BedSoil",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.8, radius * 2 + 0.2, radius * 2 + 0.2),
		cframe = upright(center + Vector3.new(0, 0.38, 0)),
		color = C.soil,
		material = Enum.Material.Ground,
	})
	SurfaceArt.flowers(parent, center + Vector3.new(0, 0.75, 0), radius, count, seed)
end

-- A lamp post: stone base, iron post and arm, a warm lantern hanging from it.
function SurfaceArt.lantern(parent: Instance, base: Vector3, height: number, facing: number?)
	local yaw = CFrame.Angles(0, facing or 0, 0)
	part(parent, {
		name = "LampBase",
		size = Vector3.new(1.4, 0.8, 1.4),
		cframe = CFrame.new(base + Vector3.new(0, 0.4, 0)),
		color = C.stoneDark,
		material = Enum.Material.Slate,
	})
	part(parent, {
		name = "LampPost",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height, 0.5, 0.5),
		cframe = upright(base + Vector3.new(0, height / 2 + 0.6, 0)),
		color = C.iron,
		material = Enum.Material.Metal,
	})
	local arm = CFrame.new(base + Vector3.new(0, height + 0.4, 0)) * yaw
	deco(parent, {
		name = "LampArm",
		size = Vector3.new(0.3, 0.3, 2),
		cframe = arm * CFrame.new(0, 0, -0.8),
		color = C.iron,
		material = Enum.Material.Metal,
	})
	local lanternCf = arm * CFrame.new(0, -1, -1.6)
	deco(parent, {
		name = "LampCap",
		wedge = false,
		size = Vector3.new(1.4, 0.35, 1.4),
		cframe = lanternCf * CFrame.new(0, 0.85, 0),
		color = C.iron,
		material = Enum.Material.Metal,
	})
	local glass = deco(parent, {
		name = "LampBulb",
		size = Vector3.new(1, 1.4, 1),
		cframe = lanternCf,
		color = C.lampGlow,
		material = Enum.Material.Neon,
		shadow = false,
	})
	light(glass, Color3.fromRGB(255, 206, 140), 18, 1.3)
end

-- Butterflies: two wings each, animated on the client around `center` (THNE_Flutter).
function SurfaceArt.butterflies(parent: Instance, center: Vector3, count: number, seed: number)
	local r = rng(seed)
	for i = 1, count do
		local color = FLOWERS[(seed + i) % #FLOWERS + 1]
		local radius, speed, phase = r(3, 7), r(0.4, 0.8), r(0, 6.28)
		local height = r(2, 4)
		for _, side in { -1, 1 } do
			local wing = deco(parent, {
				name = "Wing",
				size = Vector3.new(0.6, 0.05, 0.5),
				cframe = CFrame.new(center + Vector3.new(radius, height, 0)),
				color = color,
				shadow = false,
			})
			wing:SetAttribute("Center", center + Vector3.new(0, height, 0))
			wing:SetAttribute("Radius", radius)
			wing:SetAttribute("Speed", speed)
			wing:SetAttribute("Phase", phase)
			wing:SetAttribute("Side", side)
			CollectionService:AddTag(wing, "THNE_Flutter")
		end
	end
end

-- Smoke from a chimney: a few slow puffs, cheap.
function SurfaceArt.smoke(at: BasePart)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Smoke"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 2.5
	e.Lifetime = NumberRange.new(4, 6)
	e.Speed = NumberRange.new(2, 3.5)
	e.SpreadAngle = Vector2.new(10, 10)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(1.2, 0.4, 0.4)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Color = ColorSequence.new(Color3.fromRGB(236, 236, 240))
	e.LightInfluence = 0.6
	e.Parent = at
end

-- Buildings -------------------------------------------------------------------------------------------

-- Window on a wall face: warm glowing pane, white frame and cross, teal shutters and a flower box.
-- `cf` is the window centre on the wall surface, its LookVector pointing out of the wall.
function SurfaceArt.window(parent: Instance, cf: CFrame, width: number, height: number, seed: number)
	local out = cf * CFrame.new(0, 0, -0.12)
	deco(parent, {
		name = "WindowGlow",
		size = Vector3.new(width, height, 0.1),
		cframe = out,
		color = C.windowGlow,
		material = Enum.Material.Neon,
		transparency = 0.12,
		shadow = false,
	})
	for _, y in { -height / 2, height / 2 } do
		deco(parent, {
			name = "WindowFrame",
			size = Vector3.new(width + 0.8, 0.4, 0.4),
			cframe = out * CFrame.new(0, y, -0.1),
			color = C.trim,
		})
	end
	for _, x in { -width / 2, width / 2 } do
		deco(parent, {
			name = "WindowFrame",
			size = Vector3.new(0.4, height + 0.4, 0.4),
			cframe = out * CFrame.new(x, 0, -0.1),
			color = C.trim,
		})
	end
	deco(parent, {
		name = "Mullion",
		size = Vector3.new(0.22, height, 0.25),
		cframe = out * CFrame.new(0, 0, -0.08),
		color = C.trim,
	})
	deco(parent, {
		name = "Mullion",
		size = Vector3.new(width, 0.22, 0.25),
		cframe = out * CFrame.new(0, 0, -0.08),
		color = C.trim,
	})
	for _, side in { -1, 1 } do
		deco(parent, {
			name = "Shutter",
			size = Vector3.new(width * 0.48, height + 0.3, 0.25),
			cframe = out * CFrame.new(side * (width * 0.74 + 0.4), 0, 0),
			color = C.shutter,
			material = Enum.Material.Wood,
		})
	end
	-- flower box under the sill
	local box = deco(parent, {
		name = "FlowerBox",
		size = Vector3.new(width + 1, 0.9, 1.1),
		cframe = out * CFrame.new(0, -height / 2 - 0.65, -0.5),
		color = C.timberLight,
		material = Enum.Material.Wood,
	})
	local r = rng(seed)
	for i = 1, 5 do
		deco(parent, {
			name = "Bloom",
			shape = Enum.PartType.Ball,
			size = Vector3.one * r(0.6, 0.9),
			cframe = box.CFrame * CFrame.new((i - 3) * width / 5, 0.6, r(-0.15, 0.15)),
			color = FLOWERS[(seed + i) % #FLOWERS + 1],
			shadow = false,
		})
	end
	deco(parent, {
		name = "Leaves",
		size = Vector3.new(width + 0.6, 0.35, 0.8),
		cframe = box.CFrame * CFrame.new(0, 0.5, 0),
		color = C.leafB,
		shadow = false,
	})
end

-- A sloped strip that follows a roof slope: `from`/`to` along the slope's fall line.
local function slopeStrip(parent: Instance, a: Vector3, b: Vector3, width: number, color: Color3, thickness: number)
	local mid = (a + b) / 2
	deco(parent, {
		name = "RoofTile",
		size = Vector3.new(width, thickness, (b - a).Magnitude),
		cframe = CFrame.lookAt(mid, b),
		color = color,
	})
end

-- The cottage's exterior. The interior and its walls stay in WorldBuilder (functional layout).
-- `base` is the centre of the floor at ground level; the front faces -Z.
export type CottageSpec = { width: number, depth: number, wallHeight: number }

function SurfaceArt.cottageExterior(parent: Instance, base: Vector3, spec: CottageSpec)
	local w, dpt, h = spec.width, spec.depth, spec.wallHeight
	local front = base.Z - dpt / 2
	local wallTop = base.Y + 1 + h
	local x0 = base.X

	-- stone plinth around the walls
	for _, side in { -1, 1 } do
		part(parent, {
			name = "Plinth",
			size = Vector3.new(1.2, 2, dpt + 2.4),
			cframe = CFrame.new(x0 + side * (w / 2 + 0.1), base.Y + 0.7, base.Z),
			color = C.stone,
			material = Enum.Material.Cobblestone,
		})
		part(parent, {
			name = "Plinth",
			size = Vector3.new((w - 5) / 2 + 1.2, 2, 1.2),
			cframe = CFrame.new(x0 + side * ((w - 5) / 4 + 2.5 + 0.6), base.Y + 0.7, front - 0.1),
			color = C.stone,
			material = Enum.Material.Cobblestone,
		})
	end
	part(parent, {
		name = "Plinth",
		size = Vector3.new(w + 2.4, 2, 1.2),
		cframe = CFrame.new(x0, base.Y + 0.7, base.Z + dpt / 2 + 0.1),
		color = C.stone,
		material = Enum.Material.Cobblestone,
	})

	-- corner posts
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			deco(parent, {
				name = "CornerPost",
				size = Vector3.new(1.3, h + 0.4, 1.3),
				cframe = CFrame.new(x0 + sx * (w / 2 + 0.05), base.Y + 1 + h / 2, base.Z + sz * (dpt / 2 + 0.05)),
				color = C.timber,
				material = Enum.Material.Wood,
			})
		end
	end

	-- half-timbering on the front: sill, middle and top beams, posts beside the door and windows,
	-- and braces in the outer panels
	local fz = front - 0.2
	local function beam(size: Vector3, cf: CFrame)
		deco(parent, { name = "Timber", size = size, cframe = cf, color = C.timber, material = Enum.Material.Wood })
	end
	for _, y in { 1.3, h * 0.55 + 1, h + 0.7 } do
		for _, side in { -1, 1 } do
			local width = (w - 5) / 2
			beam(Vector3.new(width, 0.55, 0.3), CFrame.new(x0 + side * (2.5 + width / 2), base.Y + y, fz))
		end
	end
	beam(Vector3.new(5.6, 0.55, 0.3), CFrame.new(x0, base.Y + h + 0.7, fz))
	for _, x in { -11.6, -4.6, -2.8, 2.8, 4.6, 11.6 } do
		if math.abs(x) < w / 2 then
			beam(Vector3.new(0.55, h, 0.3), CFrame.new(x0 + x, base.Y + 1 + h / 2, fz))
		end
	end
	for _, side in { -1, 1 } do
		local a = Vector3.new(x0 + side * 11.6, base.Y + h * 0.55 + 1, fz)
		local b = Vector3.new(x0 + side * 14.4, base.Y + h + 0.6, fz)
		beam(Vector3.new(0.45, 0.45, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b))
	end
	-- side walls: a band at the sill and the top
	for _, sx in { -1, 1 } do
		for _, y in { 1.3, h + 0.7 } do
			beam(Vector3.new(0.3, 0.55, dpt), CFrame.new(x0 + sx * (w / 2 + 0.2), base.Y + y, base.Z))
		end
		beam(Vector3.new(0.3, h, 0.55), CFrame.new(x0 + sx * (w / 2 + 0.2), base.Y + 1 + h / 2, base.Z))
	end

	-- windows: two at the front, one on each side
	for i, side in { -1, 1 } do
		SurfaceArt.window(
			parent,
			CFrame.lookAt(
				Vector3.new(x0 + side * 8, base.Y + 6.6, front - 0.05),
				Vector3.new(x0 + side * 8, base.Y + 6.6, front - 5)
			),
			4,
			3.6,
			i * 7
		)
		local sideCenter = Vector3.new(x0 + side * (w / 2 + 0.05), base.Y + 6.6, base.Z - 2)
		SurfaceArt.window(parent, CFrame.lookAt(sideCenter, sideCenter + Vector3.new(side * 5, 0, 0)), 3.6, 3.4, i * 11)
	end

	-- the door: trimmed frame, teal leaf open inwards, round brass knob, lanterns either side
	for _, side in { -1, 1 } do
		deco(parent, {
			name = "DoorFrame",
			size = Vector3.new(0.6, 8.4, 0.6),
			cframe = CFrame.new(x0 + side * 2.6, base.Y + 5.2, front - 0.25),
			color = C.trim,
		})
		local sconce = deco(parent, {
			name = "DoorLamp",
			size = Vector3.new(0.8, 1.2, 0.8),
			cframe = CFrame.new(x0 + side * 3.8, base.Y + 7.4, front - 0.6),
			color = C.lampGlow,
			material = Enum.Material.Neon,
			shadow = false,
		})
		light(sconce, Color3.fromRGB(255, 206, 140), 8, 0.7)
		deco(parent, {
			name = "DoorLampCap",
			size = Vector3.new(1, 0.3, 1),
			cframe = sconce.CFrame * CFrame.new(0, 0.75, 0),
			color = C.iron,
			material = Enum.Material.Metal,
		})
	end
	deco(parent, {
		name = "DoorFrame",
		size = Vector3.new(5.8, 0.7, 0.6),
		cframe = CFrame.new(x0, base.Y + 9.3, front - 0.25),
		color = C.trim,
	})
	local nameplate = deco(parent, {
		name = "HouseSign",
		size = Vector3.new(4.6, 1.3, 0.2),
		cframe = CFrame.new(x0, base.Y + 10.6, front - 0.3),
		color = C.timberLight,
		material = Enum.Material.Wood,
	})
	SurfaceArt.label(nameplate, Enum.NormalId.Front, "MI CASA", C.trim)

	-- porch: deck, two steps, posts and a little gable roof over the door
	part(parent, {
		name = "Porch",
		size = Vector3.new(12, 0.8, 5),
		cframe = CFrame.new(x0, base.Y + 0.6, front - 2.5),
		color = C.timberLight,
		material = Enum.Material.WoodPlanks,
	})
	part(parent, {
		name = "PorchStep",
		size = Vector3.new(7, 0.4, 1.4),
		cframe = CFrame.new(x0, base.Y + 0.2, front - 5.6),
		color = C.stone,
		material = Enum.Material.Slate,
	})
	for _, side in { -1, 1 } do
		part(parent, {
			name = "PorchPost",
			size = Vector3.new(0.7, 8.6, 0.7),
			cframe = CFrame.new(x0 + side * 5.2, base.Y + 5.3, front - 4.6),
			color = C.trim,
			material = Enum.Material.Wood,
		})
		-- porch roof: two slopes, ridge along Z
		local ridge = base.Y + 12.4
		deco(parent, {
			name = "PorchRoof",
			wedge = true,
			size = Vector3.new(6.6, 2.6, 6.6),
			cframe = CFrame.new(x0 + side * 3.3, ridge - 1.3, front - 2.6) * CFrame.Angles(0, side * math.rad(-90), 0),
			color = C.roof,
		})
	end
	deco(parent, {
		name = "PorchRidge",
		size = Vector3.new(0.6, 0.6, 6.8),
		cframe = CFrame.new(x0, base.Y + 12.5, front - 2.6),
		color = C.roofDark,
	})

	-- main roof: steep gable, overhanging, with tile rows, a ridge and gable infill
	local H, D = 10, dpt / 2 + 2.5
	local roofW = w + 4
	for _, side in { -1, 1 } do
		deco(parent, {
			name = "Roof",
			wedge = true,
			size = Vector3.new(roofW, H, D),
			cframe = CFrame.new(x0, wallTop + H / 2, base.Z + side * (D / 2))
				* CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			color = C.roof,
		}).CanCollide =
			true
		-- gable infill under the roof, at both ends
		for _, sx in { -1, 1 } do
			deco(parent, {
				name = "Gable",
				wedge = true,
				size = Vector3.new(0.8, H - 0.6, D - 2),
				cframe = CFrame.new(x0 + sx * (w / 2 - 0.2), wallTop + (H - 0.6) / 2, base.Z + side * ((D - 2) / 2))
					* CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
				color = C.plaster,
				material = Enum.Material.Plaster,
			})
		end
		-- rows of tiles: darker strips across the slope
		for i = 1, 5 do
			local t = i / 6
			local z = base.Z + side * D * t
			local y = wallTop + H * (1 - t) + 0.18
			deco(parent, {
				name = "RoofTile",
				size = Vector3.new(roofW + 0.2, 0.3, 0.7),
				cframe = CFrame.new(x0, y, z) * CFrame.Angles(side * math.atan(H / D), 0, 0),
				color = C.roofDark,
			})
		end
		-- eaves trim
		deco(parent, {
			name = "Eaves",
			size = Vector3.new(roofW + 0.4, 0.6, 0.6),
			cframe = CFrame.new(x0, wallTop + 0.2, base.Z + side * D),
			color = C.trim,
		})
	end
	deco(parent, {
		name = "Ridge",
		size = Vector3.new(roofW + 0.6, 0.9, 1.1),
		cframe = CFrame.new(x0, wallTop + H + 0.2, base.Z),
		color = C.roofDark,
	})
	-- round attic windows in the gables
	for _, sx in { -1, 1 } do
		local att = deco(parent, {
			name = "AtticWindow",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.3, 2.6, 2.6),
			cframe = CFrame.new(x0 + sx * (w / 2 + 0.25), wallTop + 3.5, base.Z),
			color = C.windowGlow,
			material = Enum.Material.Neon,
			shadow = false,
		})
		deco(parent, {
			name = "AtticFrame",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.2, 3.3, 3.3),
			cframe = att.CFrame * CFrame.new(-sx * 0.1, 0, 0),
			color = C.trim,
		})
	end
	-- dormer over the door: a small gabled window poking out of the front slope
	local dz = front + 3.2
	local dy = wallTop + H * (1 - 3.2 / D) - 0.6
	part(parent, {
		name = "Dormer",
		size = Vector3.new(5, 4, 4),
		cframe = CFrame.new(x0, dy + 1, dz),
		color = C.plaster,
		material = Enum.Material.Plaster,
	})
	SurfaceArt.window(
		parent,
		CFrame.lookAt(Vector3.new(x0, dy + 1.2, dz - 2.05), Vector3.new(x0, dy + 1.2, dz - 8)),
		2.4,
		2,
		31
	)
	for _, side in { -1, 1 } do
		deco(parent, {
			name = "DormerRoof",
			wedge = true,
			size = Vector3.new(4.6, 2.2, 3),
			cframe = CFrame.new(x0 + side * 1.5, dy + 4.1, dz) * CFrame.Angles(0, side * math.rad(-90), 0),
			color = C.roof,
		})
	end

	-- chimney with a cap and smoke
	local chimney = part(parent, {
		name = "Chimney",
		size = Vector3.new(3, 9, 3),
		cframe = CFrame.new(x0 + 9, wallTop + H - 1.5, base.Z + 4),
		color = C.brick,
		material = Enum.Material.Brick,
	})
	local cap = deco(parent, {
		name = "ChimneyCap",
		size = Vector3.new(3.8, 0.8, 3.8),
		cframe = chimney.CFrame * CFrame.new(0, 4.9, 0),
		color = C.stoneDark,
		material = Enum.Material.Slate,
	})
	SurfaceArt.smoke(cap)

	-- weathervane on the ridge: an arrow that turns slowly with the wind
	deco(parent, {
		name = "VanePole",
		size = Vector3.new(0.25, 3, 0.25),
		cframe = CFrame.new(x0 - 8, wallTop + H + 2, base.Z),
		color = C.iron,
		material = Enum.Material.Metal,
	})
	local vane = deco(parent, {
		name = "Vane",
		size = Vector3.new(0.2, 0.9, 3.2),
		cframe = CFrame.new(x0 - 8, wallTop + H + 3.2, base.Z),
		color = C.gold,
		material = Enum.Material.Metal,
	})
	vane:SetAttribute("SpinSpeed", 0.35)
	CollectionService:AddTag(vane, "THNE_Spin")
end

-- Front garden of the cottage: low picket fence with a gate, flower beds, mailbox and bushes.
function SurfaceArt.frontGarden(parent: Instance, frontCenter: Vector3, width: number, depth: number)
	local x0, z0, y = frontCenter.X, frontCenter.Z, frontCenter.Y
	local function picketRun(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local n = math.max(2, math.floor(len / 1.4))
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			deco(parent, {
				name = "Picket",
				size = Vector3.new(0.4, 2.4, 0.25),
				cframe = CFrame.lookAt(
					p + Vector3.new(0, 1.2, 0),
					p + Vector3.new(0, 1.2, 0) + (b - a).Unit:Cross(Vector3.yAxis)
				),
				color = C.trim,
				material = Enum.Material.Wood,
			})
		end
		for _, hy in { 0.8, 1.8 } do
			local mid = (a + b) / 2 + Vector3.new(0, hy, 0)
			deco(parent, {
				name = "PicketRail",
				size = Vector3.new(0.2, 0.3, len),
				cframe = CFrame.lookAt(mid, b + Vector3.new(0, hy, 0)),
				color = C.trim,
				material = Enum.Material.Wood,
			})
		end
	end
	local hw = width / 2
	local zf = z0 - depth
	picketRun(Vector3.new(x0 - hw, y, z0), Vector3.new(x0 - hw, y, zf))
	picketRun(Vector3.new(x0 + hw, y, z0), Vector3.new(x0 + hw, y, zf))
	picketRun(Vector3.new(x0 - hw, y, zf), Vector3.new(x0 - 3, y, zf))
	picketRun(Vector3.new(x0 + 3, y, zf), Vector3.new(x0 + hw, y, zf))
	-- gate posts with ball tops
	for _, side in { -1, 1 } do
		part(parent, {
			name = "GatePost",
			size = Vector3.new(0.8, 3, 0.8),
			cframe = CFrame.new(x0 + side * 3, y + 1.5, zf),
			color = C.trim,
			material = Enum.Material.Wood,
		})
		deco(parent, {
			name = "GateBall",
			shape = Enum.PartType.Ball,
			size = Vector3.one * 1,
			cframe = CFrame.new(x0 + side * 3, y + 3.3, zf),
			color = C.gold,
		})
	end
	-- flower beds along both sides of the garden path
	for i, side in { -1, 1 } do
		local cx = x0 + side * (hw / 2 + 1.5)
		local bed = deco(parent, {
			name = "FlowerBed",
			size = Vector3.new(hw - 4, 0.5, depth - 2),
			cframe = CFrame.new(cx, y + 0.25, z0 - depth / 2),
			color = C.soil,
			material = Enum.Material.Ground,
		})
		bed.CanCollide = false
		SurfaceArt.flowers(
			parent,
			Vector3.new(cx, y + 0.4, z0 - depth / 2),
			math.min(hw - 5, depth - 3) / 2,
			14,
			40 + i
		)
		SurfaceArt.bush(parent, Vector3.new(x0 + side * (hw - 1.5), y, z0 - 1.5), 0.9, 50 + i, i == 1)
	end
	-- garden path: stepping stones from the gate to the porch
	for i = 0, math.floor(depth / 2.4) do
		deco(parent, {
			name = "SteppingStone",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.3, 2.6, 2.6),
			cframe = upright(Vector3.new(x0 + (if i % 2 == 0 then -0.4 else 0.4), y + 0.15, zf + 1.2 + i * 2.4)),
			color = C.stone,
			material = Enum.Material.Slate,
		})
	end
	-- mailbox by the gate
	local mx = x0 + 4.8
	part(parent, {
		name = "MailPost",
		size = Vector3.new(0.4, 3.4, 0.4),
		cframe = CFrame.new(mx, y + 1.7, zf - 1.2),
		color = C.timber,
		material = Enum.Material.Wood,
	})
	deco(parent, {
		name = "Mailbox",
		size = Vector3.new(1.2, 1, 2),
		cframe = CFrame.new(mx, y + 3.8, zf - 1.2),
		color = Color3.fromRGB(70, 120, 210),
		material = Enum.Material.Metal,
	})
	deco(parent, {
		name = "MailboxTop",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(2, 1.2, 1.2),
		cframe = CFrame.new(mx, y + 4.3, zf - 1.2) * CFrame.Angles(0, math.rad(90), 0),
		color = Color3.fromRGB(70, 120, 210),
		material = Enum.Material.Metal,
	})
	deco(parent, {
		name = "MailFlag",
		size = Vector3.new(0.1, 0.9, 0.5),
		cframe = CFrame.new(mx + 0.7, y + 4.6, zf - 0.8),
		color = Color3.fromRGB(230, 50, 50),
	})
end

-- An arch of mine timbers over the path into the hole, with a sign and two lanterns.
function SurfaceArt.mineArch(parent: Instance, base: Vector3, width: number, text: string)
	local hw = width / 2
	for _, side in { -1, 1 } do
		part(parent, {
			name = "ArchPost",
			size = Vector3.new(1.4, 11, 1.4),
			cframe = CFrame.new(base + Vector3.new(side * hw, 5.5, 0)),
			color = C.timber,
			material = Enum.Material.Wood,
		})
		deco(parent, {
			name = "ArchBrace",
			size = Vector3.new(0.7, 0.7, 4.4),
			cframe = CFrame.lookAt(base + Vector3.new(side * (hw - 1.4), 9.6, 0), base + Vector3.new(side * hw, 8, 0))
				* CFrame.Angles(0, math.rad(90), 0),
			color = C.timber,
			material = Enum.Material.Wood,
		})
		part(parent, {
			name = "ArchStone",
			size = Vector3.new(2.4, 1.4, 2.4),
			cframe = CFrame.new(base + Vector3.new(side * hw, 0.7, 0)),
			color = C.stoneDark,
			material = Enum.Material.Slate,
		})
		local l = deco(parent, {
			name = "ArchLamp",
			size = Vector3.new(0.9, 1.2, 0.9),
			cframe = CFrame.new(base + Vector3.new(side * (hw - 1.4), 8.2, -0.6)),
			color = C.lampGlow,
			material = Enum.Material.Neon,
			shadow = false,
		})
		light(l, Color3.fromRGB(255, 206, 140), 14, 1)
		CollectionService:AddTag(l, "THNE_Flicker")
	end
	deco(parent, {
		name = "ArchBeam",
		size = Vector3.new(width + 3, 1.4, 1.6),
		cframe = CFrame.new(base + Vector3.new(0, 11.2, 0)),
		color = C.timber,
		material = Enum.Material.Wood,
	})
	local board = deco(parent, {
		name = "ArchSign",
		size = Vector3.new(width - 3, 2.6, 0.4),
		cframe = CFrame.new(base + Vector3.new(0, 9.4, -0.6)),
		color = C.timberLight,
		material = Enum.Material.Wood,
	})
	SurfaceArt.label(board, Enum.NormalId.Front, text, C.gold)
	-- a pick and a shovel crossed on top
	for _, side in { -1, 1 } do
		deco(parent, {
			name = "IconHandle",
			size = Vector3.new(0.35, 4.4, 0.35),
			cframe = CFrame.new(base + Vector3.new(0, 13.6, 0)) * CFrame.Angles(0, 0, side * math.rad(35)),
			color = C.timberLight,
			material = Enum.Material.Wood,
		})
	end
	deco(parent, {
		name = "IconPick",
		size = Vector3.new(3.2, 0.5, 0.5),
		cframe = CFrame.new(base + Vector3.new(-1.25, 15.3, 0)) * CFrame.Angles(0, 0, math.rad(35)),
		color = C.steel,
		material = Enum.Material.Metal,
	})
	deco(parent, {
		name = "IconShovel",
		size = Vector3.new(1.4, 1.6, 0.3),
		cframe = CFrame.new(base + Vector3.new(1.25, 15.4, 0)) * CFrame.Angles(0, 0, math.rad(-35)),
		color = C.steel,
		material = Enum.Material.Metal,
	})
end

-- Striped awning sloping out from a wall: `top` is the top edge centre at the wall, `out` the
-- horizontal direction away from the wall, `along` the direction of the stripes' row.
function SurfaceArt.awning(
	parent: Instance,
	top: Vector3,
	out: Vector3,
	along: Vector3,
	length: number,
	reach: number,
	drop: number,
	colors: { Color3 }
)
	local n = math.max(2, math.floor(length / 2))
	local stripe = length / n
	local a = top
	local b = top + out * reach - Vector3.new(0, drop, 0)
	for i = 0, n - 1 do
		local offset = along * (-length / 2 + (i + 0.5) * stripe)
		deco(parent, {
			name = "Awning",
			size = Vector3.new(stripe + 0.02, 0.3, (b - a).Magnitude),
			cframe = CFrame.lookAt((a + b) / 2 + offset, b + offset),
			color = colors[i % #colors + 1],
			material = Enum.Material.Fabric,
		})
		-- scalloped edge
		deco(parent, {
			name = "AwningEdge",
			shape = Enum.PartType.Ball,
			size = Vector3.one * stripe * 0.9,
			cframe = CFrame.new(b + offset - Vector3.new(0, stripe * 0.15, 0)),
			color = colors[i % #colors + 1],
			material = Enum.Material.Fabric,
		})
	end
end

-- Hazard stripes on a horizontal strip from `a` to `b` (black and yellow blocks).
function SurfaceArt.hazard(parent: Instance, a: Vector3, b: Vector3, width: number, height: number)
	local len = (b - a).Magnitude
	local n = math.max(2, math.floor(len / 1.6))
	for i = 0, n - 1 do
		local p = a:Lerp(b, (i + 0.5) / n)
		deco(parent, {
			name = "Hazard",
			size = Vector3.new(width, height, len / n),
			cframe = CFrame.lookAt(p, b),
			color = if i % 2 == 0 then C.hazardY else C.hazardK,
		})
	end
end

-- A crate of ore: wooden box with glowing gem chunks on top.
function SurfaceArt.oreCrate(parent: Instance, cf: CFrame, gem: Color3, seed: number)
	local box = part(parent, {
		name = "Crate",
		size = Vector3.new(2.6, 1.8, 2),
		cframe = cf * CFrame.new(0, 0.9, 0),
		color = C.timberLight,
		material = Enum.Material.WoodPlanks,
	})
	local r = rng(seed)
	for _ = 1, 4 do
		deco(parent, {
			name = "Gem",
			size = Vector3.new(r(0.6, 0.9), r(0.6, 1), r(0.6, 0.9)),
			cframe = box.CFrame * CFrame.new(r(-0.8, 0.8), 1, r(-0.5, 0.5)) * CFrame.Angles(r(0, 1), r(0, 3), r(0, 1)),
			color = gem,
			material = Enum.Material.Neon,
			shadow = false,
		})
	end
end

function SurfaceArt.barrel(parent: Instance, base: Vector3, color: Color3)
	part(parent, {
		name = "Barrel",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(3, 2.2, 2.2),
		cframe = upright(base + Vector3.new(0, 1.5, 0)),
		color = color,
		material = Enum.Material.Metal,
	})
	for _, y in { 0.5, 2.5 } do
		deco(parent, {
			name = "BarrelRing",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.25, 2.35, 2.35),
			cframe = upright(base + Vector3.new(0, y, 0)),
			color = C.iron,
			material = Enum.Material.Metal,
		})
	end
end

-- A spoked wheel that turns about its own axis (THNE_Rotor, animated on the client).
function SurfaceArt.wheel(parent: Instance, cf: CFrame, diameter: number, color: Color3, speed: number)
	local hub = deco(parent, {
		name = "Wheel",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.6, diameter, diameter),
		cframe = cf,
		color = color,
		material = Enum.Material.Metal,
	})
	hub:SetAttribute("RotorSpeed", speed)
	CollectionService:AddTag(hub, "THNE_Rotor")
	local inner = deco(parent, {
		name = "WheelInner",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.7, diameter * 0.7, diameter * 0.7),
		cframe = cf,
		color = C.iron,
		material = Enum.Material.Metal,
	})
	inner:SetAttribute("RotorSpeed", speed)
	CollectionService:AddTag(inner, "THNE_Rotor")
	for i = 0, 2 do
		local spoke = deco(parent, {
			name = "Spoke",
			size = Vector3.new(0.8, diameter * 0.95, 0.35),
			cframe = cf * CFrame.Angles(i * math.pi / 3, 0, 0),
			color = color,
			material = Enum.Material.Metal,
		})
		spoke:SetAttribute("RotorSpeed", speed)
		CollectionService:AddTag(spoke, "THNE_Rotor")
	end
	return hub
end

return SurfaceArt
