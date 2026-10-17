--!strict
-- Deterministic cave systems (pure: no Roblox services, unit-testable outside Studio).
--
-- The underground is split into horizontal "sectors" of SECTOR cell layers. Each sector is laid
-- out once from (seed, sector index) following the recipe of its zone (Config/Zones `caves`):
--
--   * tunnels  : polylines with a flat floor, optional branch (mine galleries are straighter)
--   * chamber  : a large rough ellipsoid with a flat floor, rock pillars and maybe a sunken pool
--   * shaft    : a vertical chimney rising from the chamber ceiling
--   * geodes   : sealed 3x3x3 pockets fully wrapped in rock, opened later as a structure
--
-- Air carved by overlapping shapes is merged into connected "systems" (union-find), so breaking
-- into any part of a system reveals the whole system (its chests, its chamber). Each sector is
-- rasterised into a small grid (16 x 32 x 16 cells) cached per seed, so asking "what is in this
-- cell?" costs one table read.
--
-- Shapes only ever carve cells inside the dig area (0..N-1), so the protected border ring stays
-- solid, and sectors never carve above FIRST_DEPTH, so the garden and the surface stay intact.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hash = require(Shared.Util.Hash)
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)
local Anomalies = require(Shared.Config.Anomalies)

local Caves = {}

local N = GameConfig.PlotDigCells
local SECTOR = 32
local FIRST_SECTOR = 2 -- caves start at 64 m
Caves.SectorHeight = SECTOR
Caves.FirstDepth = FIRST_SECTOR * SECTOR

local SALT_LAYOUT = 401
local SALT_ROUGH = 409

export type Point = { x: number, d: number, z: number }

export type Feature = {
	id: string,
	kind: "tunnel" | "chamber" | "shaft",
	shape: string?, -- chamber shape: dome / hall / pit / split
	system: number,
	points: { Point }?, -- tunnel polyline (cell coordinates, fractional)
	radius: number,
	center: Point?, -- chamber / shaft
	rx: number?,
	rd: number?,
	rz: number?,
	floorD: number?, -- deepest air layer of a chamber
	water: boolean?,
	pillars: { Point }?,
	guided: boolean?, -- gallery leading to an anomaly (decorated with E.'s chalk marks)
	top: number?, -- shaft top layer
}

export type Spot = {
	id: string,
	kind: "chest" | "geode",
	cx: number,
	d: number,
	cz: number,
	system: number,
}

export type Sector = {
	index: number,
	top: number,
	zoneId: string,
	style: string,
	grid: { number }, -- 0 = solid, >0 = id of the connected air system
	water: { [number]: boolean },
	features: { Feature },
	spots: { Spot },
	systems: { [number]: { hasCave: boolean, counter: boolean? } },
	counterSystem: number?, -- system id of the Counter room (only in its sector)
}

local function idx(x: number, y: number, z: number): number
	return (y * N + z) * N + x + 1
end

local cache: { [string]: Sector } = {}
local cacheSize = 0

local function build(seed: number, index: number): Sector
	local top = index * SECTOR
	local zone = Zones.at(top + SECTOR / 2)
	local recipe = zone.caves
	local grid = table.create(N * SECTOR * N, 0)
	local sector: Sector = {
		index = index,
		top = top,
		zoneId = zone.id,
		style = if recipe then recipe.style else "none",
		grid = grid,
		water = {},
		features = {},
		spots = {},
		systems = {},
	}
	if not recipe or index < FIRST_SECTOR then
		return sector
	end

	-- The Counter's sector keeps its room and shell untouched by every random shape.
	local hasCounter = index == Anomalies.CounterSector

	local counter = 0
	local function rand(): number
		counter += 1
		return Hash.unit(seed, index, counter, 0, SALT_LAYOUT)
	end
	local function range(pair: { number }): number
		return pair[1] + rand() * (pair[2] - pair[1])
	end

	-- union-find over system ids
	local parent: { number } = {}
	local function newSystem(): number
		local id = #parent + 1
		parent[id] = id
		return id
	end
	local function find(a: number): number
		while parent[a] ~= a do
			parent[a] = parent[parent[a]]
			a = parent[a]
		end
		return a
	end
	local function carve(x: number, y: number, z: number, system: number)
		if x < 0 or x >= N or z < 0 or z >= N or y < 0 or y >= SECTOR then
			return
		end
		if hasCounter and (Anomalies.inReserved(x, y + top, z) or Anomalies.inFoundation(x, y + top, z)) then
			return
		end
		local i = idx(x, y, z)
		local existing = grid[i]
		if existing > 0 then
			local a, b = find(existing), find(system)
			if a ~= b then
				parent[a] = b
			end
		else
			grid[i] = system
		end
	end

	-- Tunnel helpers -----------------------------------------------------------------------------
	local straight = recipe.style == "mine" or recipe.style == "ruin"
	local function walk(start: Point, heading: number, segments: number): { Point }
		local points = { start }
		local p = start
		for _ = 1, segments do
			heading += (rand() - 0.5) * (if straight then 0.5 else 1.3)
			local length = 4.5 + rand() * 4
			local dd = if straight then (rand() - 0.5) * 0.6 else (rand() - 0.5) * 3
			local nx = p.x + math.cos(heading) * length
			local nz = p.z + math.sin(heading) * length
			-- bounce off the dig area walls
			if nx < 1.5 or nx > N - 1.5 then
				heading = math.pi - heading
				nx = math.clamp(nx, 1.5, N - 1.5)
			end
			if nz < 1.5 or nz > N - 1.5 then
				heading = -heading
				nz = math.clamp(nz, 1.5, N - 1.5)
			end
			local q = { x = nx, d = math.clamp(p.d + dd, top + 5, top + SECTOR - 6), z = nz }
			table.insert(points, q)
			p = q
		end
		return points
	end

	local function rasteriseTunnel(points: { Point }, radius: number, system: number)
		for s = 1, #points - 1 do
			local a, b = points[s], points[s + 1]
			local minX, maxX = math.floor(math.min(a.x, b.x) - radius), math.ceil(math.max(a.x, b.x) + radius)
			local minZ, maxZ = math.floor(math.min(a.z, b.z) - radius), math.ceil(math.max(a.z, b.z) + radius)
			local minD, maxD = math.floor(math.min(a.d, b.d) - radius), math.ceil(math.max(a.d, b.d) + radius)
			local abx, abd, abz = b.x - a.x, b.d - a.d, b.z - a.z
			local len2 = abx * abx + abd * abd + abz * abz
			for x = minX, maxX do
				for d = minD, maxD do
					for z = minZ, maxZ do
						local px, pd, pz = x + 0.5, d + 0.5, z + 0.5
						local t = if len2 > 0
							then math.clamp(((px - a.x) * abx + (pd - a.d) * abd + (pz - a.z) * abz) / len2, 0, 1)
							else 0
						local cx, cd, cz = a.x + abx * t, a.d + abd * t, a.z + abz * t
						local dx, dy, dz = px - cx, pd - cd, pz - cz
						local horizontal2 = dx * dx + dz * dz
						-- flat floor 0.55 r below the centre line; ceiling 1.2 r above it (walkable height
						-- of ~2.5 cells). Mine/ruin galleries are carved square, natural ones oval.
						local inside
						if straight then
							inside = horizontal2 <= radius * radius and dy >= -radius * 1.2
						else
							inside = horizontal2 / (radius * radius) + (dy * dy) / (radius * radius * 1.44) <= 1
						end
						if inside and dy <= radius * 0.55 then
							carve(x, d - top, z, system)
						end
					end
				end
			end
		end
	end

	-- Chamber ------------------------------------------------------------------------------------
	-- Shapes: dome (round), hall (long and low), pit (narrow and tall: a vertical cavity),
	-- split (two lobes joined by their overlap). Weights come from the zone recipe.
	local chamber: Feature? = nil
	if rand() < recipe.chamberChance then
		local system = newSystem()
		local shapes = recipe.shapes or { dome = 1 }
		local total = 0
		for _, w in shapes do
			total += w
		end
		local pick = rand() * total
		local shape = "dome"
		for _, name in { "dome", "hall", "pit", "split" } do
			local w = shapes[name] or 0
			if pick < w then
				shape = name
				break
			end
			pick -= w
		end

		type Lobe = { x: number, d: number, z: number, rx: number, rd: number, rz: number }
		local lobes: { Lobe } = {}
		local function place(rx: number, rd: number, rz: number): Lobe
			return {
				x = rx * 0.6 + rand() * math.max(0, N - rx * 1.2),
				d = top + rd + 2 + rand() * math.max(0, SECTOR - 2 * rd - 6),
				z = rz * 0.6 + rand() * math.max(0, N - rz * 1.2),
				rx = rx,
				rd = rd,
				rz = rz,
			}
		end
		if shape == "hall" then
			local long, short = 6 + rand() * 1.5, 2.8 + rand()
			local alongX = rand() < 0.5
			table.insert(lobes, place(if alongX then long else short, 3 + rand() * 1.5, if alongX then short else long))
		elseif shape == "pit" then
			local r = 2.6 + rand()
			table.insert(lobes, place(r, 8 + rand() * 4, r))
		elseif shape == "split" then
			local r = 3.4 + rand()
			local first = place(r, range(recipe.chamberHeight) * 0.8, r)
			local alongX = rand() < 0.5
			local offset = (2 * r - 1.5) * (if rand() < 0.5 then 1 else -1)
			local second = {
				x = math.clamp(first.x + (if alongX then offset else 0), r * 0.6, N - r * 0.6),
				d = first.d + (rand() - 0.5) * 4,
				z = math.clamp(first.z + (if alongX then 0 else offset), r * 0.6, N - r * 0.6),
				rx = r * (0.8 + rand() * 0.3),
				rd = first.rd * (0.8 + rand() * 0.3),
				rz = r * (0.8 + rand() * 0.3),
			}
			table.insert(lobes, first)
			table.insert(lobes, second)
		else
			table.insert(
				lobes,
				place(range(recipe.chamberRadius), range(recipe.chamberHeight), range(recipe.chamberRadius))
			)
		end

		local main = lobes[1]
		local center = { x = main.x, d = main.d, z = main.z }
		local rx, rd, rz = main.rx, main.rd, main.rz
		local floorD = -1
		for _, lobe in lobes do
			local floorLimit = lobe.d + lobe.rd * 0.55
			for x = math.floor(lobe.x - lobe.rx - 1), math.ceil(lobe.x + lobe.rx + 1) do
				for d = math.floor(lobe.d - lobe.rd - 1), math.ceil(lobe.d + lobe.rd + 1) do
					for z = math.floor(lobe.z - lobe.rz - 1), math.ceil(lobe.z + lobe.rz + 1) do
						local px, pd, pz = x + 0.5, d + 0.5, z + 0.5
						local v = ((px - lobe.x) / lobe.rx) ^ 2
							+ ((pd - lobe.d) / lobe.rd) ^ 2
							+ ((pz - lobe.z) / lobe.rz) ^ 2
						local rough = (Hash.unit(seed, x, d, z, SALT_ROUGH) - 0.5) * 0.35
						if v <= 1 + rough and pd <= floorLimit then
							carve(x, d - top, z, system)
							if lobe == main and d > floorD then
								floorD = d
							end
						end
					end
				end
			end
		end
		-- rock pillars: solid columns from floor to ceiling
		local pillars = {}
		for _ = 1, math.floor(rand() * (recipe.pillars + 1)) do
			local px = center.x + (rand() - 0.5) * rx
			local pz = center.z + (rand() - 0.5) * rz
			if (px - center.x) ^ 2 + (pz - center.z) ^ 2 > 4 then -- keep the middle open
				table.insert(pillars, { x = px, d = center.d, z = pz })
				for x = math.floor(px - 1), math.ceil(px + 1) do
					for z = math.floor(pz - 1), math.ceil(pz + 1) do
						if
							(x + 0.5 - px) ^ 2 + (z + 0.5 - pz) ^ 2 <= 0.85
							and x >= 0
							and x < N
							and z >= 0
							and z < N
						then
							for d = math.floor(center.d - rd - 1), math.ceil(center.d + rd + 1) do
								local y = d - top
								if y >= 0 and y < SECTOR then
									grid[idx(x, y, z)] = 0
								end
							end
						end
					end
				end
			end
		end
		-- sunken pool below the floor, fully contained by rock
		local water = false
		if floorD >= 0 and rand() < recipe.waterChance and floorD + 2 < top + SECTOR then
			water = true
			for x = math.floor(center.x - rx), math.ceil(center.x + rx) do
				for z = math.floor(center.z - rz), math.ceil(center.z + rz) do
					local ratio = ((x + 0.5 - center.x) / rx) ^ 2 + ((z + 0.5 - center.z) / rz) ^ 2
					for depthBelow, limit in { 0.32, 0.14 } do
						if ratio <= limit and x >= 1 and x < N - 1 and z >= 1 and z < N - 1 then
							local y = floorD + depthBelow - top
							local above = idx(x, y - 1, z)
							if grid[above] > 0 or sector.water[above] then
								carve(x, y, z, system)
								sector.water[idx(x, y, z)] = true
							end
						end
					end
				end
			end
		end
		local feature: Feature = {
			id = string.format("s%d_c", index),
			kind = "chamber",
			shape = shape,
			system = system,
			radius = math.max(rx, rz),
			center = center,
			rx = rx,
			rd = rd,
			rz = rz,
			floorD = floorD,
			water = water,
			pillars = pillars,
		}
		chamber = feature
		table.insert(sector.features, feature)

		-- chimney rising from the ceiling
		if rand() < recipe.shaftChance then
			local sx = math.clamp(center.x + (rand() - 0.5) * rx, 2, N - 2)
			local sz = math.clamp(center.z + (rand() - 0.5) * rz, 2, N - 2)
			local shaftTop = math.max(top + 1, math.floor(center.d - rd - 4 - rand() * 8))
			local bottom = math.floor(center.d)
			for x = math.floor(sx - 2), math.ceil(sx + 2) do
				for z = math.floor(sz - 2), math.ceil(sz + 2) do
					if (x + 0.5 - sx) ^ 2 + (z + 0.5 - sz) ^ 2 <= 1.3 * 1.3 then
						for d = shaftTop, bottom do
							carve(x, d - top, z, system)
						end
					end
				end
			end
			table.insert(sector.features, {
				id = string.format("s%d_v", index),
				kind = "shaft",
				system = system,
				radius = 1.3,
				center = { x = sx, d = bottom, z = sz },
				top = shaftTop,
			})
		end
	end

	-- The Counter room --------------------------------------------------------------------------
	-- Its interior is one sealed system; two mine galleries lead to the only two doorways (west and
	-- east). The galleries stop one cell short: the player digs the doorway and breaks in.
	if hasCounter then
		local room = Anomalies.CounterRoom
		local roomSystem = newSystem()
		for x = room.x0, room.x1 do
			for d = room.d0, room.d1 do
				for z = room.z0, room.z1 do
					grid[idx(x, d - top, z)] = roomSystem
				end
			end
		end
		sector.counterSystem = roomSystem
		local floorCentre = room.d1 -- gallery centre line at the room's floor layer
		local c = N // 2
		local guided = {
			{
				{ x = 1.6, d = floorCentre - 3, z = 1.6 },
				{ x = 1.6, d = floorCentre - 1, z = c - 3 },
				{ x = room.x0 - 2 + 0.5, d = floorCentre, z = c },
			},
			{
				{ x = N - 1.6, d = floorCentre - 4, z = N - 1.6 },
				{ x = N - 1.6, d = floorCentre - 1.5, z = c + 3 },
				{ x = room.x1 + 2 + 0.5, d = floorCentre, z = c },
			},
		}
		for g, points in guided do
			local system = newSystem()
			rasteriseTunnel(points, 1.45, system)
			table.insert(sector.features, {
				id = string.format("s%d_guide%d", index, g),
				kind = "tunnel",
				system = system,
				points = points,
				radius = 1.45,
				guided = true,
			})
		end
	end

	-- Tunnels ------------------------------------------------------------------------------------
	local deadEnds: { { point: Point, system: number } } = {}
	for t = 1, recipe.tunnels do
		local system = newSystem()
		local side = math.floor(rand() * 4)
		local along = 2 + rand() * (N - 4)
		local depth = top + 6 + rand() * (SECTOR - 12)
		local start: Point
		local heading: number
		if side == 0 then
			start, heading = { x = 1.5, d = depth, z = along }, 0
		elseif side == 1 then
			start, heading = { x = N - 1.5, d = depth, z = along }, math.pi
		elseif side == 2 then
			start, heading = { x = along, d = depth, z = 1.5 }, math.pi / 2
		else
			start, heading = { x = along, d = depth, z = N - 1.5 }, -math.pi / 2
		end
		-- The first gallery heads for the chamber so sectors form connected networks.
		if t == 1 and chamber and chamber.center then
			local c = chamber.center
			heading = math.atan2(c.z - start.z, c.x - start.x)
			start.d = math.clamp((chamber.floorD or c.d) - 1, top + 5, top + SECTOR - 6)
		end
		local points = walk(start, heading, 3)
		local radius = recipe.tunnelRadius * (0.9 + rand() * 0.2)
		rasteriseTunnel(points, radius, system)
		table.insert(sector.features, {
			id = string.format("s%d_t%d", index, t),
			kind = "tunnel",
			system = system,
			points = points,
			radius = radius,
		})
		table.insert(deadEnds, { point = points[#points], system = system })
		if rand() < recipe.branchChance then
			local branchStart = points[2]
			local branch = walk(branchStart, heading + (if rand() < 0.5 then 1.4 else -1.4), 2)
			rasteriseTunnel(branch, radius * 0.85, system)
			table.insert(sector.features, {
				id = string.format("s%d_t%db", index, t),
				kind = "tunnel",
				system = system,
				points = branch,
				radius = radius * 0.85,
			})
			table.insert(deadEnds, { point = branch[#branch], system = system })
		end
	end

	-- Drain unsupported water: galleries carved after the pool may have opened its side. Water
	-- must only touch rock or water sideways and below, otherwise it would hang in the air.
	local changed = true
	while changed do
		changed = false
		for i, _ in sector.water do
			local local0 = i - 1
			local x, z, y = local0 % N, (local0 // N) % N, local0 // (N * N)
			for _, n in { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, 0, -1 }, { 0, 1, 0 } } do
				local nx, ny, nz = x + n[1], y + n[2], z + n[3]
				if nx >= 0 and nx < N and nz >= 0 and nz < N and ny >= 0 and ny < SECTOR then
					local j = idx(nx, ny, nz)
					if grid[j] > 0 and not sector.water[j] then
						sector.water[i] = nil
						changed = true
						break
					end
				end
			end
		end
	end

	-- Resolve systems ----------------------------------------------------------------------------
	for i = 1, #grid do
		local v = grid[i]
		if v > 0 then
			grid[i] = find(v)
		end
	end
	for _, feature in sector.features do
		feature.system = find(feature.system)
		sector.systems[feature.system] = { hasCave = true }
	end
	if sector.counterSystem then
		sector.systems[sector.counterSystem] = { hasCave = false, counter = true }
	end

	local function solidAt(x: number, d: number, z: number): boolean
		local y = d - top
		if x < 0 or x >= N or z < 0 or z >= N or y < 0 or y >= SECTOR then
			return true
		end
		return grid[idx(x, y, z)] == 0
	end

	-- Chests -------------------------------------------------------------------------------------
	local chestCount = 0
	local function tryChest(x: number, d: number, z: number, system: number)
		local y = d - top
		if x < 0 or x >= N or z < 0 or z >= N or y < 0 or y >= SECTOR - 1 then
			return
		end
		if hasCounter and Anomalies.inReserved(x, d, z) then
			return
		end
		local i = idx(x, y, z)
		if grid[i] > 0 and not sector.water[i] and solidAt(x, d + 1, z) then
			chestCount += 1
			table.insert(sector.spots, {
				id = string.format("s%d_k%d", index, chestCount),
				kind = "chest",
				cx = x,
				d = d,
				cz = z,
				system = find(system),
			})
		end
	end
	if chamber and chamber.center and chamber.floorD and rand() < recipe.chestChance then
		-- next to the middle of the floor, never inside the pool
		local c = chamber.center
		local ox = if rand() < 0.5 then -2 else 2
		tryChest(math.floor(c.x) + ox, chamber.floorD, math.floor(c.z), chamber.system)
	end
	for _, deadEnd in deadEnds do
		if rand() < recipe.chestChance * 0.5 then
			local p = deadEnd.point
			local x, z = math.floor(p.x), math.floor(p.z)
			-- drop to the floor of the tunnel at its end
			local d = math.floor(p.d)
			while d + 1 < top + SECTOR and not solidAt(x, d + 1, z) do
				d += 1
			end
			tryChest(x, d, z, deadEnd.system)
		end
	end

	-- Geodes -------------------------------------------------------------------------------------
	local geodeCount = math.floor(range({ recipe.geodes[1], recipe.geodes[2] + 0.999 }))
	local placed = 0
	for _ = 1, geodeCount * 8 do
		if placed >= geodeCount then
			break
		end
		local gx = 2 + math.floor(rand() * (N - 4))
		local gz = 2 + math.floor(rand() * (N - 4))
		local gd = top + 3 + math.floor(rand() * (SECTOR - 6))
		-- the pocket (radius 1) and a full rock shell around it (radius 2.5) must be solid
		local clear = not (hasCounter and Anomalies.inReserved(gx, gd, gz))
		for x = gx - 3, gx + 3 do
			for d = gd - 3, gd + 3 do
				for z = gz - 3, gz + 3 do
					if
						(x - gx) ^ 2 + (d - gd) ^ 2 + (z - gz) ^ 2 <= 2.6 * 2.6
						and (not solidAt(x, d, z) or (hasCounter and Anomalies.inReserved(x, d, z)))
					then
						clear = false
					end
				end
			end
		end
		if clear then
			placed += 1
			local system = newSystem()
			for x = gx - 1, gx + 1 do
				for d = gd - 1, gd + 1 do
					for z = gz - 1, gz + 1 do
						if (x - gx) ^ 2 + (d - gd) ^ 2 + (z - gz) ^ 2 <= 1.35 * 1.35 then
							grid[idx(x, d - top, z)] = system
						end
					end
				end
			end
			sector.systems[system] = { hasCave = false }
			table.insert(sector.spots, {
				id = string.format("s%d_g%d", index, placed),
				kind = "geode",
				cx = gx,
				d = gd,
				cz = gz,
				system = system,
			})
		end
	end

	return sector
end

-- Sector layout for (seed, index). Cached; the cache is bounded.
function Caves.sector(seed: number, index: number): Sector
	local key = seed .. ":" .. index
	local cached = cache[key]
	if cached then
		return cached
	end
	if cacheSize >= 48 then
		table.clear(cache)
		cacheSize = 0
	end
	local sector = build(seed, index)
	cache[key] = sector
	cacheSize += 1
	return sector
end

-- Last sector used, to avoid even the key lookup for consecutive cells of the same sector.
local lastSeed, lastIndex, lastSector = -1, -1, nil :: Sector?

-- Returns (systemId, isWater) for a cell; systemId 0 means solid rock.
function Caves.cellAt(seed: number, cx: number, d: number, cz: number): (number, boolean)
	if d < Caves.FirstDepth or cx < 0 or cz < 0 or cx >= N or cz >= N then
		return 0, false
	end
	local index = d // SECTOR
	local sector = lastSector
	if not sector or seed ~= lastSeed or index ~= lastIndex then
		sector = Caves.sector(seed, index)
		lastSeed, lastIndex, lastSector = seed, index, sector
	end
	local s = sector :: Sector
	local i = idx(cx, d - s.top, cz)
	local v = s.grid[i]
	if v > 0 then
		return v, s.water[i] == true
	end
	return 0, false
end

-- Sectors overlapping the depth range [d0, d1].
function Caves.sectorsInRange(seed: number, d0: number, d1: number): { Sector }
	local list = {}
	for index = math.max(FIRST_SECTOR, d0 // SECTOR), d1 // SECTOR do
		table.insert(list, Caves.sector(seed, index))
	end
	return list
end

-- Stable key of a connected system, used to remember revealed caves.
function Caves.systemKey(sectorIndex: number, system: number): string
	return string.format("s%d_%d", sectorIndex, system)
end

return Caves
