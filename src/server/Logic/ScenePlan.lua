--!strict
-- What each cave says about the world (pure: no instances; tested offline). CaveScenes turns the
-- plan into parts.
--
-- Every scene belongs to its place and tells something about who was there:
--   mine     rails along the galleries, a cart left at a dead end (sometimes tipped over, its ore
--            spilled), the camp of E. in a chamber, E.'s chalk arrows on the guided galleries
--   crystal  crystals hanging from the ceiling, a heart crystal that pulses in the larger chambers
--   ruin     arches built by someone, one of them collapsed, a column lying on the floor
--   lava     basalt columns and a vent breathing embers
--   abyss    luminous vines hanging from the ceiling, a cloud of spores
--   core     shards floating above the floor, turning slowly
--   all      stalactites and stalagmites in the chambers, for scale
--
-- A prop sits on a floor (air cell over rock) or hangs from a ceiling (air cell under rock): the
-- test checks every one. Each sector has a budget so deep plots do not pile up thousands of parts.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hash = require(Shared.Util.Hash)
local Anomalies = require(Shared.Config.Anomalies)
local GameConfig = require(Shared.Config.GameConfig)
local Caves = require(script.Parent.Caves)

local ScenePlan = {}

local N = GameConfig.PlotDigCells
local SALT = 811

export type Prop = {
	kind: string,
	x: number, -- cell coordinates of the prop's centre (fractional)
	z: number,
	d: number, -- the air layer it stands on (floor) or hangs from (ceiling)
	anchor: "floor" | "ceiling",
	yaw: number, -- radians
	scale: number, -- 0.6 .. 1.4
	variant: number, -- 1..4, meaning depends on the kind
	length: number?, -- rails: cells along the gallery
}

-- Maximum props per sector (one prop is 1-10 parts; see CaveScenes).
ScenePlan.Budget = 60
ScenePlan.MaxRails = 6

-- Kinds that can only appear in their style (used by the coverage test and the docs).
ScenePlan.Signature = {
	mine = { "rails", "cart", "camp", "chalk" },
	crystal = { "crystal_hang", "crystal_heart" },
	ruin = { "arch", "fallen_column" },
	lava = { "basalt", "vent" },
	abyss = { "vine", "spores" },
	core = { "shard" },
}

local function air(seed: number, x: number, d: number, z: number): boolean
	if x < 0 or x >= N or z < 0 or z >= N then
		return false
	end
	local id, water = Caves.cellAt(seed, x, d, z)
	return id > 0 and not water
end

local function solid(seed: number, x: number, d: number, z: number): boolean
	if x < 0 or x >= N or z < 0 or z >= N then
		return true
	end
	return Caves.cellAt(seed, x, d, z) == 0
end

-- Deepest air layer under (x, d, z) with rock below it, or nil.
local function floorOf(seed: number, x: number, d: number, z: number): number?
	if not air(seed, x, d, z) then
		return nil
	end
	local floorD = d
	while air(seed, x, floorD + 1, z) and floorD - d < 40 do
		floorD += 1
	end
	if not solid(seed, x, floorD + 1, z) then
		return nil -- water below
	end
	return floorD
end

local function ceilingOf(seed: number, x: number, d: number, z: number): number?
	if not air(seed, x, d, z) then
		return nil
	end
	local ceilD = d
	while air(seed, x, ceilD - 1, z) and d - ceilD < 40 do
		ceilD -= 1
	end
	return ceilD
end

local function reserved(x: number, d: number, z: number): boolean
	return Anomalies.inReserved(x, d, z) or Anomalies.inFoundation(x, d, z)
end

function ScenePlan.plan(seed: number, sector: Caves.Sector): { Prop }
	local props: { Prop } = {}
	local style = sector.style
	local counter = 0
	local function rand(): number
		counter += 1
		return Hash.unit(seed, sector.index, counter, 0, SALT)
	end
	local function add(prop: Prop): boolean
		if #props >= ScenePlan.Budget then
			return false
		end
		local cx, cz = math.floor(prop.x), math.floor(prop.z)
		if reserved(cx, prop.d, cz) then
			return false
		end
		table.insert(props, prop)
		return true
	end
	-- a floor prop at a fractional cell position, if there is a floor there
	local function onFloor(kind: string, x: number, d: number, z: number, yaw: number, variant: number): boolean
		local fd = floorOf(seed, math.floor(x), math.floor(d), math.floor(z))
		if not fd then
			return false
		end
		return add({
			kind = kind,
			x = x,
			z = z,
			d = fd,
			anchor = "floor",
			yaw = yaw,
			scale = 0.7 + rand() * 0.6,
			variant = variant,
		})
	end
	local function onCeiling(kind: string, x: number, d: number, z: number, variant: number): boolean
		local cd = ceilingOf(seed, math.floor(x), math.floor(d), math.floor(z))
		if not cd or cd <= sector.top then
			return false -- open to the sector above (shafts): nothing to hang from
		end
		-- leave head room: only hang from ceilings at least 3 cells above the floor
		local fd = floorOf(seed, math.floor(x), cd, math.floor(z))
		if not fd or fd - cd < 2 then
			return false
		end
		return add({
			kind = kind,
			x = x,
			z = z,
			d = cd,
			anchor = "ceiling",
			yaw = rand() * math.pi * 2,
			scale = 0.7 + rand() * 0.6,
			variant = variant,
		})
	end

	local rails = 0
	local cartPlaced, campPlaced = false, false
	for _, feature in sector.features do
		if feature.kind == "tunnel" and feature.points then
			local points = feature.points
			for s = 1, #points - 1 do
				local a, b = points[s], points[s + 1]
				local dx, dz = b.x - a.x, b.z - a.z
				local length = math.sqrt(dx * dx + dz * dz)
				local yaw = math.atan2(dx, dz)
				if length >= 2 then
					local mx, md, mz = (a.x + b.x) / 2, (a.d + b.d) / 2, (a.z + b.z) / 2
					if style == "mine" and rails < ScenePlan.MaxRails and math.abs(b.d - a.d) < 1.5 then
						-- the whole segment must have a floor at one level for the rails to lie flat
						local fa = floorOf(seed, math.floor(a.x), math.floor(a.d), math.floor(a.z))
						local fb = floorOf(seed, math.floor(b.x), math.floor(b.d), math.floor(b.z))
						local fm = floorOf(seed, math.floor(mx), math.floor(md), math.floor(mz))
						if fa and fb and fm and fa == fb and fb == fm then
							if
								add({
									kind = "rails",
									x = mx,
									z = mz,
									d = fm,
									anchor = "floor",
									yaw = yaw,
									scale = 1,
									variant = 1,
									length = length,
								})
							then
								rails += 1
							end
						end
					end
					if feature.guided then
						-- E.'s chalk arrows, pointing on towards the anomaly
						local steps = math.max(1, math.floor(length / 4))
						for k = 1, steps do
							local t = k / (steps + 1)
							onFloor("chalk", a.x + dx * t, a.d + (b.d - a.d) * t, a.z + dz * t, yaw, 1)
						end
					end
					if style == "abyss" and rand() < 0.5 then
						onCeiling("vine", mx, md, mz, 1 + math.floor(rand() * 3))
					elseif style == "crystal" and rand() < 0.5 then
						onCeiling("crystal_hang", mx, md, mz, 1 + math.floor(rand() * 3))
					end
				end
			end
			-- a cart abandoned at the end of a gallery
			if style == "mine" and not cartPlaced and #points >= 2 and rand() < 0.6 then
				local last, before = points[#points], points[#points - 1]
				local yaw = math.atan2(last.x - before.x, last.z - before.z)
				local tipped = rand() < 0.4
				cartPlaced = onFloor("cart", last.x, last.d, last.z, yaw, if tipped then 2 else 1)
			end
		elseif feature.kind == "chamber" and feature.center then
			local c = feature.center
			local rx, rz = feature.rx or 2, feature.rz or 2
			local big = rx * rz >= 16
			local function around(spread: number): (number, number)
				local angle = rand() * math.pi * 2
				local r = (0.25 + rand() * 0.65) * spread
				return c.x + math.cos(angle) * rx * r, c.z + math.sin(angle) * rz * r
			end
			local floorLevel = feature.floorD or c.d
			-- scale: stalactites and stalagmites in every style
			for _ = 1, if big then 4 else 2 do
				local x, z = around(0.9)
				onCeiling("stalactite", x, c.d, z, 1 + math.floor(rand() * 3))
				x, z = around(0.9)
				onFloor("stalagmite", x, floorLevel, z, rand() * 6.28, 1 + math.floor(rand() * 3))
			end
			if style == "mine" then
				if not campPlaced and rand() < 0.45 then
					local x, z = around(0.5)
					-- the variant picks which of E.'s bets is chalked on the camp slate (Config/Feats),
					-- a different one in each Mines sector
					campPlaced = onFloor("camp", x, floorLevel, z, rand() * 6.28, 1 + sector.index % 3)
				end
			elseif style == "crystal" then
				for _ = 1, if big then 5 else 3 do
					local x, z = around(0.9)
					onCeiling("crystal_hang", x, c.d, z, 1 + math.floor(rand() * 3))
				end
				if big then
					onFloor("crystal_heart", c.x, floorLevel, c.z, rand() * 6.28, 1)
				end
			elseif style == "ruin" then
				local x, z = around(0.6)
				onFloor("arch", x, floorLevel, z, rand() * 6.28, if rand() < 0.35 then 2 else 1)
				x, z = around(0.8)
				onFloor("fallen_column", x, floorLevel, z, rand() * 6.28, 1)
			elseif style == "lava" then
				for _ = 1, if big then 3 else 2 do
					local x, z = around(0.85)
					onFloor("basalt", x, floorLevel, z, rand() * 6.28, 1 + math.floor(rand() * 3))
				end
				onFloor("vent", c.x, floorLevel, c.z, 0, 1)
			elseif style == "abyss" then
				for _ = 1, if big then 5 else 3 do
					local x, z = around(0.9)
					onCeiling("vine", x, c.d, z, 1 + math.floor(rand() * 3))
				end
				onFloor("spores", c.x, floorLevel, c.z, 0, 1)
			elseif style == "core" then
				for _ = 1, if big then 4 else 2 do
					local x, z = around(0.7)
					onFloor("shard", x, floorLevel, z, rand() * 6.28, 1 + math.floor(rand() * 3))
				end
			end
		end
	end
	return props
end

return ScenePlan
