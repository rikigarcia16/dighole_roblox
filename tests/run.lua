-- Entry point: luaucheck run tests/run.lua (from the repository root)
local H = loadfile("tests/harness.lua")()
H.mount("ReplicatedStorage", "Shared", "src/shared")
H.mount("ServerScriptService", "Server", "src/server")

local test, eq, ok = H.test, H.eq, H.ok

print("Config")
local Resources = H.module("ReplicatedStorage", "Shared", "Config", "Resources")
local Zones = H.module("ReplicatedStorage", "Shared", "Config", "Zones")
local Tools = H.module("ReplicatedStorage", "Shared", "Config", "Tools")
local Upgrades = H.module("ReplicatedStorage", "Shared", "Config", "Upgrades")
local GameConfig = H.module("ReplicatedStorage", "Shared", "Config", "GameConfig")

test("every resource has the required fields", function()
	for _, r in Resources.List do
		ok(type(r.id) == "string" and type(r.name) == "string", "id/name")
		ok(r.value > 0 and r.hardness > 0 and r.requiredPower >= 1 and r.weight > 0, r.id .. " numbers")
		ok(Resources.Rarities[r.rarity], r.id .. " rarity")
		if r.isOre then
			ok(r.spawn and r.spawn.minDepth < r.spawn.maxDepth, r.id .. " spawn")
		end
	end
end)

test("zones are contiguous and reference existing base materials", function()
	local expectedStart = 0
	for i, z in Zones.List do
		eq(z.index, i, "zone index")
		eq(z.minDepth, expectedStart, z.id .. " start")
		expectedStart = z.maxDepth
		for _, rule in z.base do
			ok(Resources.get(rule.id), z.id .. " base " .. rule.id)
		end
	end
	eq(Zones.at(0).id, "garden")
	eq(Zones.at(49.9).id, "garden")
	eq(Zones.at(50).id, "forgotten_mines")
	eq(Zones.at(99999).id, "unknown_core")
end)

test("tools are ordered by price and power", function()
	local lastPrice, lastPower = -1, 0
	for _, t in Tools.List do
		if t.purchasable then
			ok(t.price > lastPrice, t.id .. " price order")
			lastPrice = t.price
		end
		ok(t.power > lastPower, t.id .. " power order")
		lastPower = t.power
		ok(t.cooldown > 0 and t.energyCost > 0 and t.reach > 0, t.id .. " stats")
	end
	ok(Tools.get(Tools.DefaultToolId).price == 0, "default tool is free")
end)

test("every base material of a zone is diggable by some purchasable tool", function()
	local maxPower = 0
	for _, t in Tools.List do
		if t.purchasable then
			maxPower = math.max(maxPower, t.power)
		end
	end
	for _, r in Resources.List do
		ok(r.requiredPower <= maxPower, r.id .. " is undiggable")
	end
end)

test("upgrade tracks start free and grow", function()
	for _, track in Upgrades.List do
		eq(track.levels[1].price, 0, track.id .. " level 1 price")
		for i = 2, #track.levels do
			ok(track.levels[i].price > track.levels[i - 1].price, track.id .. " price grows")
			ok(track.levels[i].value > track.levels[i - 1].value, track.id .. " value grows")
		end
	end
	eq(Upgrades.valueAt("backpack", 1), 20)
	eq(Upgrades.valueAt("backpack", 999), 1200)
end)

print("Util")
local Hash = H.module("ReplicatedStorage", "Shared", "Util", "Hash")
local Grid = H.module("ReplicatedStorage", "Shared", "Util", "Grid")
local CellSet = H.module("ReplicatedStorage", "Shared", "Util", "CellSet")
local Format = H.module("ReplicatedStorage", "Shared", "Util", "Format")
local RateLimiter = H.module("ReplicatedStorage", "Shared", "Util", "RateLimiter")

test("hash is deterministic, in range and well distributed", function()
	eq(Hash.int(123, 4, 5, 6), Hash.int(123, 4, 5, 6))
	ok(Hash.int(123, 4, 5, 6) ~= Hash.int(124, 4, 5, 6), "seed changes result")
	local buckets = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	local n = 20000
	for i = 1, n do
		local u = Hash.unit(99, i, -i, i * 7)
		ok(u >= 0 and u < 1, "unit range")
		local b = math.floor(u * 10) + 1
		buckets[b] += 1
	end
	for i, c in buckets do
		ok(math.abs(c - n / 10) < n / 10 * 0.1, "bucket " .. i .. " skewed: " .. c)
	end
	ok(Hash.int(1, -5, -1000, -3) >= 0, "negative coords")
end)

test("grid round trips world positions and keys", function()
	local ox, oz = 1024, -512
	for _, c in { { 0, 0, 0 }, { 15, 3, 7 }, { 8, 1999, 15 }, { -1, 4, 16 } } do
		local p = Grid.cellCenter(ox, oz, c[1], c[2], c[3])
		local x, d, z = Grid.worldToCell(ox, oz, p)
		eq(x, c[1], "x")
		eq(d, c[2], "d")
		eq(z, c[3], "z")
	end
	ok(Grid.inDigArea(0, 0, 0) and Grid.inDigArea(15, 10, 15), "inside")
	ok(not Grid.inDigArea(-1, 0, 0) and not Grid.inDigArea(16, 0, 0) and not Grid.inDigArea(0, -1, 0), "outside")
	for _, c in { { 0, 0, 0 }, { 15, 2100, 15 }, { 3, 77, 9 } } do
		local x, d, z = Grid.fromKey(Grid.key(c[1], c[2], c[3]))
		eq(x, c[1])
		eq(d, c[2])
		eq(z, c[3])
	end
	eq(#Grid.sphereOffsets(0), 1)
	eq(#Grid.sphereOffsets(1), 7)
	eq(#Grid.sphereOffsets(1.5), 19)
	eq(Grid.sphereOffsets(1.5)[1][4], 0, "target first")
end)

test("cell set encoding round trips", function()
	local set = {}
	for _, k in { 0, 1, 2, 3, 10, 12, 13, 500, 501, 99999 } do
		set[k] = true
	end
	local encoded = CellSet.encode(set)
	local decoded = CellSet.decode(encoded)
	local count = 0
	for k in decoded do
		ok(set[k], "unexpected " .. k)
		count += 1
	end
	eq(count, 10)
	eq(#encoded, 10, "5 runs")
	eq(next(CellSet.decode(nil)), nil)
	eq(next(CellSet.decode({ 5, -1 })), nil, "corrupt data ignored")
end)

test("format", function()
	eq(Format.number(0), "0")
	eq(Format.number(1234), "1,234")
	eq(Format.number(99999), "99,999")
	eq(Format.number(1234567), "1.23M")
	eq(Format.number(-1500), "-1,500")
end)

test("rate limiter allows bursts then throttles", function()
	local now = 0
	local rl = RateLimiter.new(2, 3, function()
		return now
	end)
	ok(rl:allow("a") and rl:allow("a") and rl:allow("a"), "burst")
	ok(not rl:allow("a"), "throttled")
	ok(rl:allow("b"), "independent keys")
	now = 0.5
	ok(rl:allow("a"), "refilled")
	ok(not rl:allow("a"), "throttled again")
end)

print("Server logic")
local OreGeneration = H.module("ServerScriptService", "Server", "Logic", "OreGeneration")
local Inventory = H.module("ServerScriptService", "Server", "Logic", "Inventory")
local ProfileSchema = H.module("ServerScriptService", "Server", "Logic", "ProfileSchema")

test("ore generation is deterministic and depth-correct", function()
	eq(OreGeneration.resourceAt(42, 3, 0, 3), "grass")
	for d = 1, 400, 7 do
		for x = 0, 15, 5 do
			local id = OreGeneration.resourceAt(42, x, d, 9)
			eq(id, OreGeneration.resourceAt(42, x, d, 9), "deterministic")
			local r = Resources.get(id)
			ok(r, "valid id " .. tostring(id))
			if r.isOre then
				ok(d >= r.spawn.minDepth and d < r.spawn.maxDepth, id .. " outside its depth at " .. d)
			end
		end
	end
end)

local function census(seed, fromDepth, toDepth)
	local counts, total = {}, 0
	for d = fromDepth, toDepth do
		for x = 0, 15 do
			for z = 0, 15 do
				local id = OreGeneration.resourceAt(seed, x, d, z)
				counts[id] = (counts[id] or 0) + 1
				total += 1
			end
		end
	end
	return counts, total
end

test("garden zone mix: mostly dirt, some stone, coal and copper present", function()
	local counts, total = census(7, 1, 49)
	ok((counts.dirt or 0) / total > 0.35, "dirt share " .. tostring(counts.dirt))
	ok((counts.stone or 0) > 0, "stone present")
	ok((counts.coal or 0) / total > 0.01, "coal share " .. tostring(counts.coal))
	ok((counts.copper or 0) / total > 0.008, "copper share " .. tostring(counts.copper))
	ok(not counts.slate and not counts.gold, "no deep materials")
	local oreValue, cells = 0, 0
	for id, c in counts do
		oreValue += Resources.get(id).value * c
		cells += c
	end
	print(
		string.format(
			"       garden: avg %.2f coins/cell, ore share %.1f%%",
			oreValue / cells,
			100 * ((counts.coal or 0) + (counts.copper or 0)) / total
		)
	)
end)

test("mines zone introduces slate and iron", function()
	local counts = census(7, 60, 149)
	ok((counts.slate or 0) > 0, "slate")
	ok((counts.iron or 0) > 0, "iron")
end)

test("inventory respects capacity", function()
	local inv = {}
	eq(Inventory.add(inv, "dirt", 15, 20), 15)
	eq(Inventory.add(inv, "copper", 10, 20), 5)
	eq(Inventory.used(inv), 20)
	eq(Inventory.add(inv, "coal", 1, 20), 0)
	eq(Inventory.value(inv), 15 * 1 + 5 * 12)
	eq(Inventory.add(inv, "not_a_resource", 1, 99), 0)
end)

test("profile defaults and reconcile sanitises bad data", function()
	local p = ProfileSchema.default(5)
	eq(p.coins, 0)
	ok(p.tools.rusty_shovel)
	eq(p.upgrades.backpack, 1)
	eq(p.plot.seed, 5)
	local r = ProfileSchema.reconcile({
		coins = -50,
		tools = { steel_shovel = true, fake = true },
		equippedTool = "fake",
		upgrades = { backpack = 99, battery = "x" },
		inventory = { dirt = 3.7, fake = 9, coal = -2 },
		stats = { maxDepth = 0 / 0, cellsDug = 12 },
		plot = { seed = 77, dug = { 0, 3 } },
	}, 1)
	eq(r.coins, 0, "negative coins")
	ok(r.tools.steel_shovel and r.tools.rusty_shovel and not r.tools.fake, "tools")
	eq(r.equippedTool, "rusty_shovel")
	eq(r.upgrades.backpack, #Upgrades.ById.backpack.levels)
	eq(r.upgrades.battery, 1)
	eq(r.inventory.dirt, 3)
	eq(r.inventory.fake, nil)
	eq(r.inventory.coal, nil)
	eq(r.stats.maxDepth, 0, "NaN rejected")
	eq(r.stats.cellsDug, 12)
	eq(r.plot.seed, 77)
	eq(ProfileSchema.reconcile(nil, 3).plot.seed, 3)
end)

print("Terrain writes (fake Terrain)")
local Enum = H.Enum
do
	local writes = {}
	H.globals.workspace = {
		Terrain = {
			WriteVoxels = function(_, region, resolution, materials, occupancies)
				table.insert(
					writes,
					{ region = region, resolution = resolution, materials = materials, occupancies = occupancies }
				)
			end,
			FillBlock = function() end,
			SetMaterialColor = function() end,
		},
	}
	H.globals.Region3 = {
		new = function(min, max)
			return { min = min, max = max }
		end,
	}
	H.globals.CFrame = {
		new = function(...)
			return { ... }
		end,
	}
	H.globals.task = { wait = function() end }
	H.mount("ServerScriptService", "Server", "src/server")
	local TerrainChunkService = H.module("ServerScriptService", "Server", "Services", "TerrainChunkService")
	local GridM = H.module("ReplicatedStorage", "Shared", "Util", "Grid")

	local plot = { originX = 400, originZ = -64, seed = 99, dug = {}, damage = {}, generatedDepth = 0 }
	plot.dug[GridM.key(3, 5, 7)] = true
	plot.damage[GridM.key(4, 5, 7)] = 2 -- half of stone/dirt hardness at most

	test("chunk generation writes region-aligned voxel arrays", function()
		TerrainChunkService.ensureDepth(plot, 20)
		eq(plot.generatedDepth, 32, "two chunks")
		eq(#writes, 2)
		local w = writes[1]
		eq(w.resolution, 4)
		local n = GameConfig.PlotDigCells + 2
		eq(#w.materials, n, "x size")
		eq(#w.materials[1], GameConfig.ChunkDepth, "y size")
		eq(#w.materials[1][1], n, "z size")
		local size = w.region.max - w.region.min
		eq(size.X, n * 4)
		eq(size.Y, GameConfig.ChunkDepth * 4)
		eq(size.Z, n * 4)
		eq(w.region.max.Y, 0, "top at surface")
		eq(w.region.min.X, 396, "border ring included")
		for _, v in { w.region.min.X, w.region.min.Y, w.region.min.Z } do
			eq(v % 4, 0, "grid aligned")
		end
	end)

	test("voxel array orientation matches cell coordinates", function()
		local w = writes[1]
		local function at(cx, d, cz)
			-- ix = cx + 2 (ring at -1), iy counts up from the deepest layer of the chunk, iz = cz + 2
			local iy = (GameConfig.ChunkDepth - 1 - d) + 1
			return w.materials[cx + 2][iy][cz + 2], w.occupancies[cx + 2][iy][cz + 2]
		end
		local m, o = at(3, 5, 7)
		eq(m, Enum.Material.Air, "dug cell is air")
		eq(o, 0)
		local m2, o2 = at(4, 5, 7)
		local r = Resources.get(OreGeneration.resourceAt(99, 4, 5, 7))
		eq(m2, r.terrainMaterial, "damaged cell keeps material")
		ok(o2 < 1 and o2 >= GameConfig.MinOccupancyWhileDamaged, "damaged cell shrinks: " .. o2)
		local m3 = at(0, 0, 0)
		eq(m3, Enum.Material.Grass, "top layer is grass")
		local m4 = at(-1, 9, 4)
		eq(m4, Resources.get(OreGeneration.resourceAt(99, -1, 9, 4)).terrainMaterial, "border ring solid")
		-- world position of a cell centre must fall inside the voxel the array assigns to it
		local center = GridM.cellCenter(plot.originX, plot.originZ, 3, 5, 7)
		local ix = math.floor((center.X - w.region.min.X) / 4) + 1
		local iy = math.floor((center.Y - w.region.min.Y) / 4) + 1
		local iz = math.floor((center.Z - w.region.min.Z) / 4) + 1
		eq(w.materials[ix][iy][iz], Enum.Material.Air, "world->array mapping")
	end)

	test("writeBox clamps to the plot and rewrites only the box", function()
		table.clear(writes)
		TerrainChunkService.writeBox(plot, -5, 2, 3, 4, 14, 30)
		eq(#writes, 1)
		local size = writes[1].region.max - writes[1].region.min
		eq(size.X, (2 - -1 + 1) * 4)
		eq(size.Y, 2 * 4)
		eq(size.Z, (GameConfig.PlotDigCells - 14 + 1) * 4)
	end)
end

H.finish()
