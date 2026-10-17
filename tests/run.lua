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
		ok(r.value > 0 and r.hardness > 0 and r.requiredPower >= 1 and r.weight >= 0, r.id .. " numbers")
		ok(r.terrainMaterial ~= nil or r.find ~= nil or r.rewardOnly, r.id .. " cannot be obtained")
		if r.find then
			ok(r.weight == 0 and r.find.chance > 0 and r.find.chance < 0.05, r.id .. " find rule")
		end
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

test("dig feel: every material family has a complete preset with existing sounds", function()
	local DigFeel = H.module("ReplicatedStorage", "Shared", "Config", "DigFeel")
	local Sounds = H.module("ReplicatedStorage", "Shared", "Config", "Sounds")
	for _, r in Resources.List do
		ok(DigFeel.Presets[r.effect], r.id .. " uses unknown effect " .. r.effect)
		ok(Sounds[r.sound], r.id .. " uses unknown sound " .. r.sound)
	end
	for name, p in DigFeel.Presets do
		ok(Sounds[p.hitSound] and Sounds[p.breakSound], name .. " sounds")
		ok(p.dust > 0 and p.breakDust > p.dust and p.debris > 0, name .. " break is fuller than a hit")
	end
	for _, t in Tools.List do
		ok(DigFeel.Timing[t.animation], t.id .. " animation timing")
		ok(Sounds[t.sound], t.id .. " sound")
		local timing = DigFeel.Timing[t.animation]
		ok(timing.duration * timing.impact < t.cooldown, t.id .. ": impact must land before the next swing")
	end
	for key, sdef in Sounds do
		ok(sdef.id:find("^rbxasset://") or sdef.id:find("^rbxassetid://"), key .. " id format")
		ok(sdef.pitchMin <= sdef.pitchMax and sdef.volume > 0 and sdef.volume <= 1, key .. " ranges")
	end
	for _, needed in
		{
			"too_hard",
			"geode_open",
			"fossil_extract",
			"cave_open",
			"discover_rare",
			"discover_epic",
			"discover_legendary",
		}
	do
		ok(Sounds[needed], "missing sound " .. needed)
	end
end)

test("hardness indicator: hits left, segments and locks", function()
	local HardnessView = H.module("ReplicatedStorage", "Shared", "Util", "HardnessView")
	local dirt = Resources.get("dirt") -- hardness 2
	local v = HardnessView.compute(dirt, 1, 0)
	eq(v.locked, false)
	eq(v.totalHits, 2)
	eq(v.hitsLeft, 2)
	eq(v.segments, 2)
	eq(v.filled, 0)
	v = HardnessView.compute(dirt, 1, 0.5)
	eq(v.hitsLeft, 1)
	eq(v.filled, 1)
	local slate = Resources.get("slate") -- requires power 2
	v = HardnessView.compute(slate, 1, 0)
	ok(v.locked and v.requiredPower == 2 and v.label:find("potencia 2"), "locked label")
	v = HardnessView.compute(Resources.get("basalt"), 12, 0.5) -- 110 hardness / 12 = 10 hits
	eq(v.totalHits, 10)
	eq(v.hitsLeft, 5)
	eq(v.segments, 10)
	eq(v.filled, 5)
	v = HardnessView.compute(Resources.get("core_matter"), 35, 0.25) -- 9 hits, capped segments
	ok(v.segments <= 10 and v.filled <= v.segments, "segments capped")
	v = HardnessView.compute(dirt, 5, 0) -- one hit
	eq(v.hitsLeft, 1)
	eq(v.label, dirt.name)
end)

test("battery is not sold while nothing consumes energy", function()
	ok(Upgrades.ById.battery.hidden, "battery hidden")
	ok(not Upgrades.ById.backpack.hidden, "backpack still sold")
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

test("hash: neighbouring cells, axes and salts are independent", function()
	local function corr(f)
		local n, sx, sy, sxx, syy, sxy = 20000, 0, 0, 0, 0, 0
		for i = 1, n do
			local a, b = f(i)
			sx += a
			sy += b
			sxx += a * a
			syy += b * b
			sxy += a * b
		end
		local cov = sxy / n - (sx / n) * (sy / n)
		return cov / math.sqrt((sxx / n - (sx / n) ^ 2) * (syy / n - (sy / n) ^ 2))
	end
	local cases = {
		x = function(i)
			return Hash.unit(3, i, 50, 7), Hash.unit(3, i + 1, 50, 7)
		end,
		y = function(i)
			return Hash.unit(3, 5, i, 7), Hash.unit(3, 5, i + 1, 7)
		end,
		z = function(i)
			return Hash.unit(3, 5, 50, i), Hash.unit(3, 5, 50, i + 1)
		end,
		salt = function(i)
			return Hash.unit(3, i % 97, i // 97, 7, 11), Hash.unit(3, i % 97, i // 97, 7, 23)
		end,
		seed = function(i)
			return Hash.unit(i, 1, 2, 3), Hash.unit(i + 1, 1, 2, 3)
		end,
	}
	for name, f in cases do
		local c = corr(f)
		ok(math.abs(c) < 0.03, name .. " correlation " .. c)
	end
	-- pairs of consecutive values fill a 10x10 grid evenly
	local grid, n = {}, 50000
	for i = 1, n do
		local a, b = Hash.unit(9, i, 0, 0), Hash.unit(9, i + 1, 0, 0)
		local k = math.floor(a * 10) * 10 + math.floor(b * 10)
		grid[k] = (grid[k] or 0) + 1
	end
	for k = 0, 99 do
		ok(math.abs((grid[k] or 0) - n / 100) < n / 100 * 0.25, "pair cell " .. k .. " skewed")
	end
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
			ok(r or id == "air", "valid id " .. tostring(id))
			if r and r.isOre then
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
				if id ~= "air" then
					counts[id] = (counts[id] or 0) + 1
					total += 1
				end
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

local Caves = H.module("ServerScriptService", "Server", "Logic", "Caves")
local Anomalies = H.module("ReplicatedStorage", "Shared", "Config", "Anomalies")
local FossilBeds = H.module("ServerScriptService", "Server", "Logic", "FossilBeds")
local Fossils = H.module("ReplicatedStorage", "Shared", "Config", "Fossils")

test("caves: only inside the dig area, never above the first cave depth, deterministic", function()
	for _, seed in { 1, 2, 3 } do
		for d = 0, 400 do
			for x = -1, 16 do
				for z = -1, 16 do
					local id = OreGeneration.resourceAt(seed, x, d, z)
					if id == "air" or id == "water" then
						ok(
							x >= 0 and x < 16 and z >= 0 and z < 16,
							"open cell in the border ring at " .. x .. "," .. d .. "," .. z
						)
						ok(
							d >= Caves.FirstDepth
								or OreGeneration.landmarkAt(seed, x, d, z)
								or FossilBeds.bedAt(seed, x, d, z),
							"open cell above the caves at " .. d
						)
					end
				end
			end
		end
		local a = Caves.sector(seed, 5)
		local b = Caves.sector(seed + 1000, 5) -- different seed, then back: rebuilt from scratch
		for k = 1, 60 do
			Caves.sector(seed + 2000 + k, 3) -- flush the cache
		end
		local again = Caves.sector(seed, 5)
		ok(again ~= a, "cache was flushed")
		for i2 = 1, #a.grid do
			eq(again.grid[i2], a.grid[i2], "same layout after rebuild")
		end
		local _ = b
	end
end)

test("caves: varied shapes, galleries, pools and geodes over many plots", function()
	local shapes, counts = {}, { tunnel = 0, chamber = 0, shaft = 0, water = 0, geode = 0, chest = 0, sectors = 0 }
	for seed = 1, 40 do
		for index = 2, 11 do
			local sector = Caves.sector(seed, index)
			counts.sectors += 1
			for _, f in sector.features do
				counts[f.kind] += 1
				if f.shape then
					shapes[f.shape] = (shapes[f.shape] or 0) + 1
				end
				if f.water then
					counts.water += 1
				end
			end
			for _, spot in sector.spots do
				counts[spot.kind] += 1
			end
		end
	end
	for _, name in { "dome", "hall", "pit", "split" } do
		ok((shapes[name] or 0) > 10, "chamber shape " .. name .. " is rare: " .. tostring(shapes[name]))
	end
	ok(counts.tunnel > counts.sectors, "galleries in most sectors")
	ok(counts.water > 20 and counts.geode > 100 and counts.chest > 100, "pools, geodes and chests exist")
	print(
		string.format(
			"       %d sectors: %d galleries, %d chambers (dome %d, hall %d, pit %d, split %d), %d shafts, %d pools, %d geodes, %d chests",
			counts.sectors,
			counts.tunnel,
			counts.chamber,
			shapes.dome or 0,
			shapes.hall or 0,
			shapes.pit or 0,
			shapes.split or 0,
			counts.shaft,
			counts.water,
			counts.geode,
			counts.chest
		)
	)
end)

test("caves: galleries are tall enough to walk through and chambers have floors", function()
	local tooLow, columns, floorless, floorCells = 0, 0, 0, 0
	for seed = 1, 15 do
		for index = 2, 6 do
			local sector = Caves.sector(seed, index)
			for _, f in sector.features do
				if f.kind == "tunnel" and f.points then
					-- along every gallery centre line, the open column must be >= 2 cells tall
					for _, p in f.points do
						local x, z = math.floor(p.x), math.floor(p.z)
						local d = math.floor(p.d)
						if Caves.cellAt(seed, x, d, z) > 0 then
							columns += 1
							local height = 1
							while Caves.cellAt(seed, x, d - height, z) > 0 do
								height += 1
							end
							local below = 1
							while Caves.cellAt(seed, x, d + below, z) > 0 do
								below += 1
							end
							if height + below - 1 < 2 then
								tooLow += 1
							end
						end
					end
				elseif f.kind == "chamber" and f.floorD then
					local c = f.center
					for x = math.floor(c.x - 1), math.floor(c.x + 1) do
						for z = math.floor(c.z - 1), math.floor(c.z + 1) do
							local system, water = Caves.cellAt(seed, x, f.floorD, z)
							if system > 0 and not water then
								floorCells += 1
								local below, belowWater = Caves.cellAt(seed, x, f.floorD + 1, z)
								if below > 0 and not belowWater then
									floorless += 1
								end
							end
						end
					end
				end
			end
		end
	end
	ok(columns > 50, "sampled gallery columns: " .. columns)
	ok(tooLow / columns < 0.05, "galleries too low: " .. tooLow .. "/" .. columns)
	ok(
		floorCells > 50 and floorless / floorCells < 0.15,
		"chamber floors: " .. floorless .. "/" .. floorCells .. " open below"
	)
end)

test("caves: pools are contained by rock and geodes are sealed", function()
	local N = 16
	for seed = 1, 30 do
		for index = 2, 11 do
			local sector = Caves.sector(seed, index)
			for i2 in sector.water do
				local local0 = i2 - 1
				local x = local0 % N
				local z = (local0 // N) % N
				local d = sector.top + local0 // (N * N)
				for _, n in { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, 0, -1 }, { 0, 1, 0 } } do
					local system, water = Caves.cellAt(seed, x + n[1], d + n[2], z + n[3])
					ok(system == 0 or water, "water leaks sideways/down at " .. x .. "," .. d .. "," .. z)
				end
			end
			for _, spot in sector.spots do
				if spot.kind == "geode" then
					-- every cell around the pocket (within 2.5) is rock except the pocket itself
					for x = spot.cx - 3, spot.cx + 3 do
						for d = spot.d - 3, spot.d + 3 do
							for z = spot.cz - 3, spot.cz + 3 do
								local r2 = (x - spot.cx) ^ 2 + (d - spot.d) ^ 2 + (z - spot.cz) ^ 2
								local system = Caves.cellAt(seed, x, d, z)
								if r2 <= 1.35 * 1.35 then
									eq(system, spot.system, "geode pocket")
								elseif r2 <= 2.5 * 2.5 then
									eq(system, 0, "geode shell is solid")
								end
							end
						end
					end
				elseif spot.kind == "chest" then
					local system, water = Caves.cellAt(seed, spot.cx, spot.d, spot.cz)
					ok(system > 0 and not water, "chest stands in open air")
					eq(Caves.cellAt(seed, spot.cx, spot.d + 1, spot.cz), 0, "chest stands on rock")
				end
			end
		end
	end
end)

test("caves: overlapping shapes share one system", function()
	for seed = 1, 20 do
		local sector = Caves.sector(seed, 4)
		for _, f in sector.features do
			if f.kind == "tunnel" and f.points then
				for _, p in f.points do
					local px, pd, pz = math.floor(p.x), math.floor(p.d), math.floor(p.z)
					local system = Caves.cellAt(seed, px, pd, pz)
					-- a random gallery may pass through the Counter's reserved box without carving it
					if system > 0 and not Anomalies.inReserved(px, pd, pz) then
						eq(system, f.system, "gallery cells belong to the gallery's system")
					end
				end
			end
		end
	end
end)

test("landmarks are pockets of air at their depth", function()
	for _, seed in { 7, 8, 9 } do
		local list = OreGeneration.landmarks(seed)
		eq(#list, 1, "only the miner's box remains a loose landmark (the tablet is in the Counter)")
		for _, l in list do
			eq(OreGeneration.resourceAt(seed, l.cx, l.d, l.cz), "air")
			ok(l.cx >= 4 and l.cx <= 11 and l.cz >= 4 and l.cz <= 11, "landmark near the middle")
			ok(OreGeneration.resourceAt(seed, l.cx, l.d + 1, l.cz) ~= "air", "landmark has a floor")
		end
	end
end)

test("hidden finds respect their depth ranges and rates", function()
	local counts, cells = {}, 0
	for d = 2, 149 do
		for x = 0, 15 do
			for z = 0, 15 do
				local id = OreGeneration.findAt(77, x, d, z)
				cells += 1
				if id then
					counts[id] = (counts[id] or 0) + 1
					local rule = Resources.get(id).find
					ok(d >= rule.minDepth and d < rule.maxDepth, id .. " out of range at " .. d)
				end
			end
		end
	end
	local rate = (counts.antique_fragment or 0) / cells
	ok(rate > 0.003 and rate < 0.009, "antique rate " .. rate)
	ok(not counts.fossil, "no fossils above 150 m")
end)

test("weightless finds ignore backpack capacity", function()
	local inv = { dirt = 20 }
	eq(Inventory.add(inv, "geode", 1, 20), 1)
	eq(Inventory.used(inv), 20)
end)

test("quest chain advances in order and never pays twice", function()
	local QuestLogic = H.module("ServerScriptService", "Server", "Logic", "QuestLogic")
	local Quests = H.module("ReplicatedStorage", "Shared", "Config", "Quests")
	local p = ProfileSchema.default(1)
	eq(QuestLogic.view(p).id, "dig_10")
	p.stats.cellsDug = 12
	p.stats.sales = 1
	local done = QuestLogic.advance(p)
	eq(#done, 2, "two quests at once")
	eq(p.coins, 15 + 20)
	eq(QuestLogic.view(p).id, "copper_5")
	eq(#QuestLogic.advance(p), 0, "nothing more")
	eq(p.coins, 35, "no double reward")
	p.quests.index = 1 -- even if the index were rolled back, completed quests do not pay again
	QuestLogic.advance(p)
	eq(p.coins, 35)
	-- finishing everything
	p.discoveries.copper = 5
	p.tools.reinforced_shovel = true
	p.stats.maxDepth = 200
	p.clues.miner_box = true
	p.clues.stone_tablet = true
	p.discoveries.antique_fragment = 1
	p.discoveries.geode = 1
	p.stats.cavesFound = 1
	QuestLogic.advance(p)
	eq(QuestLogic.view(p), nil, "chain finished")
	eq(p.quests.index, #Quests + 1)
	for _, q in Quests do
		ok(p.quests.completed[q.id], q.id .. " completed")
	end
end)

test("every quest references something that exists", function()
	local Quests = H.module("ReplicatedStorage", "Shared", "Config", "Quests")
	local Story = H.module("ReplicatedStorage", "Shared", "Config", "Story")
	for _, q in Quests do
		if q.kind == "collect" then
			ok(Resources.get(q.key), q.id)
		end
		if q.kind == "tool" then
			ok(Tools.get(q.key), q.id)
		end
		if q.kind == "clue" then
			ok(Story.Notes[q.key], q.id)
		end
	end
	for _, id in Story.NoteOrder do
		ok(Story.Notes[id], id)
	end
end)

test("profile v1 data migrates to v2", function()
	local r =
		ProfileSchema.reconcile({ version = 1, coins = 10, stats = { cellsDug = 4 }, plot = { seed = 3, dug = {} } }, 1)
	eq(r.version, ProfileSchema.CURRENT_VERSION)
	eq(r.coins, 10)
	eq(r.quests.index, 1)
	eq(r.stats.cavesFound, 0)
	ok(type(r.plot.openedChests) == "table" and type(r.clues) == "table", "new tables")
	local bad = ProfileSchema.reconcile({
		quests = { index = 999 },
		clues = { fake = true, miner_box = true },
		plot = { openedChests = { "1_8_0", 5, string.rep("x", 100) } },
	}, 1)
	ok(bad.quests.index <= 13, "quest index clamped")
	ok(bad.clues.miner_box and not bad.clues.fake, "clues sanitised")
	eq(#bad.plot.openedChests, 1, "chest keys sanitised")
end)

test("fossils: sealed two-cell pockets in rock, species valid for their depth", function()
	local beds, species = 0, {}
	for seed = 1, 40 do
		for _, bed in FossilBeds.bedsInRange(seed, 0, 420) do
			beds += 1
			species[bed.speciesId] = (species[bed.speciesId] or 0) + 1
			local s = Fossils.get(bed.speciesId)
			ok(s and bed.d >= s.minDepth and bed.d < s.maxDepth, bed.speciesId .. " outside its depth at " .. bed.d)
			local second = if bed.alongX then { bed.cx + 1, bed.d, bed.cz } else { bed.cx, bed.d, bed.cz + 1 }
			for _, c in { { bed.cx, bed.d, bed.cz }, second } do
				ok(c[1] >= 1 and c[1] <= 14 and c[3] >= 1 and c[3] <= 14, "pocket away from the border")
				eq(OreGeneration.resourceAt(seed, c[1], c[2], c[3]), "air", "pocket is open")
				eq(FossilBeds.bedAt(seed, c[1], c[2], c[3]), bed, "bedAt finds the bed")
			end
			-- every neighbour that is not the pocket itself is solid rock (sealed until dug into)
			for _, c in { { bed.cx, bed.d, bed.cz }, second } do
				for _, n in { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } } do
					local x, d, z = c[1] + n[1], c[2] + n[2], c[3] + n[3]
					if not FossilBeds.bedAt(seed, x, d, z) then
						local id = OreGeneration.resourceAt(seed, x, d, z)
						ok(
							id ~= "air" and id ~= "water",
							"fossil pocket touches open space at " .. x .. "," .. d .. "," .. z
						)
					end
				end
			end
		end
	end
	local perPlot = beds / 40
	ok(perPlot > 12 and perPlot < 30, "fossils per plot (0-420 m): " .. perPlot)
	for _, s in Fossils.List do
		ok((species[s.id] or 0) > 0, s.id .. " never appears in 40 plots")
	end
	-- every species must be collectable in most plots (each player only digs their own plot)
	local coverage = {}
	for seed = 1, 100 do
		local here = {}
		for _, bed in FossilBeds.bedsInRange(seed + 500, 0, 420) do
			here[bed.speciesId] = true
		end
		for id in here do
			coverage[id] = (coverage[id] or 0) + 1
		end
	end
	local parts = {}
	for _, s in Fossils.List do
		table.insert(parts, string.format("%s %d%%", s.id, coverage[s.id] or 0))
		ok((coverage[s.id] or 0) >= 60, s.id .. " only in " .. tostring(coverage[s.id]) .. "% of plots")
	end
	print(
		string.format(
			"       %.1f fossils per plot down to 420 m; plots with each species: %s",
			perPlot,
			table.concat(parts, ", ")
		)
	)
end)

test("fossil collection: first registration pays once, repeats give fragments", function()
	local Collection = H.module("ServerScriptService", "Server", "Logic", "Collection")
	local p = ProfileSchema.default(1)
	local r = Collection.registerFossil(p, "eyeless_fish", 93.6)
	ok(r and r.isNew and r.reward == Fossils.get("eyeless_fish").reward and not r.fragment, "first")
	eq(p.coins, r.reward)
	eq(p.collection.fossils.eyeless_fish.firstDepth, 93)
	local again = Collection.registerFossil(p, "eyeless_fish", 120)
	ok(again and not again.isNew and again.reward == 0 and again.fragment, "repeat")
	eq(p.coins, r.reward, "no second reward")
	eq(p.collection.fossils.eyeless_fish.count, 2)
	eq(p.collection.fossils.eyeless_fish.firstDepth, 93, "first depth kept")
	eq(Collection.registerFossil(p, "not_a_species", 1), nil)
	local found, total = Collection.progress(p)
	eq(found, 1)
	eq(total, #Fossils.List)
end)

test("profile v2 data migrates to v3 with its collection sanitised", function()
	local r = ProfileSchema.reconcile({
		version = 2,
		inventory = { fossil = 2 },
		collection = {
			fossils = { eyeless_fish = { count = 3, firstDepth = 80 }, fake = { count = 1 }, ringed_worm = "x" },
		},
	}, 1)
	eq(r.version, 3)
	eq(r.inventory.fossil, 2, "old fossil items kept")
	eq(r.collection.fossils.eyeless_fish.count, 3)
	eq(r.collection.fossils.fake, nil)
	eq(r.collection.fossils.ringed_worm, nil)
	eq(r.stats.fossilsExtracted, 0)
end)

-- DataStores store JSON: every table must be a pure array (1..n) or have only string keys, and
-- numbers must be finite. This simulates a save + load through those rules.
local function dataStoreRoundTrip(value, path)
	path = path or "profile"
	local t = type(value)
	if t == "number" then
		ok(value == value and value ~= math.huge and value ~= -math.huge, path .. " is not a finite number")
		return value
	elseif t == "string" or t == "boolean" then
		return value
	elseif t ~= "table" then
		error(path .. " has a non-serialisable " .. t, 0)
	end
	local count, stringKeys, maxIndex = 0, 0, 0
	for k in value do
		count += 1
		if type(k) == "string" then
			stringKeys += 1
		elseif type(k) == "number" and k == math.floor(k) and k >= 1 then
			maxIndex = math.max(maxIndex, k)
		else
			error(path .. " has an invalid key " .. tostring(k), 0)
		end
	end
	ok(stringKeys == 0 or stringKeys == count, path .. " mixes array and string keys")
	ok(stringKeys > 0 or maxIndex == count, path .. " is a sparse array")
	local copy = {}
	for k, v in value do
		copy[k] = dataStoreRoundTrip(v, path .. "." .. tostring(k))
	end
	return copy
end

test("block counter: server stat survives save and load, never derived from the hole", function()
	local p = ProfileSchema.default(42)
	p.stats.cellsDug = 1247
	p.plot.dug = CellSet.encode({ [1] = true, [2] = true, [3] = true }) -- only 3 cells still open
	p.collection.fossils.eyeless_fish = { count = 2, firstDepth = 93 }
	p.quests.completed.dig_10 = true
	table.insert(p.plot.openedChests, "s4_k1")
	local loaded = ProfileSchema.reconcile(dataStoreRoundTrip(p), 1)
	eq(loaded.stats.cellsDug, 1247, "counter preserved")
	eq(loaded.collection.fossils.eyeless_fish.count, 2)
	eq(loaded.plot.openedChests[1], "s4_k1")
	-- a second round trip is stable
	local again = ProfileSchema.reconcile(dataStoreRoundTrip(loaded), 1)
	eq(again.stats.cellsDug, 1247)
	-- the whole default and loaded profiles are DataStore-safe
	dataStoreRoundTrip(ProfileSchema.default(7))
	dataStoreRoundTrip(again)
end)

test("counter room: sealed, two doorways, guided galleries, nothing random inside", function()
	local room = Anomalies.CounterRoom
	for seed = 1, 40 do
		local sector = Caves.sector(seed, Anomalies.CounterSector)
		local roomSystem = sector.counterSystem
		ok(roomSystem and sector.systems[roomSystem].counter, "room system registered")
		for x = room.x0 - 1, room.x1 + 1 do
			for d = room.d0 - 1, room.d1 + 1 do
				for z = room.z0 - 1, room.z1 + 1 do
					local id = OreGeneration.resourceAt(seed, x, d, z)
					if Anomalies.inRoom(x, d, z) then
						eq(id, "air", "room interior is open")
						eq(Caves.cellAt(seed, x, d, z), roomSystem, "room interior is one system")
						ok(not FossilBeds.bedAt(seed, x, d, z), "no fossil in the room")
					else
						ok(id ~= "air" and id ~= "water", "shell is rock at " .. x .. "," .. d .. "," .. z)
						ok(Anomalies.isSealed(x, d, z) ~= Anomalies.isDoorway(x, d, z), "shell is sealed or doorway")
					end
				end
			end
		end
		for _, spot in sector.spots do
			ok(not Anomalies.inReserved(spot.cx, spot.d, spot.cz), spot.kind .. " inside the reserved box")
		end
		-- each doorway has open gallery right outside it, at floor level
		for _, door in Anomalies.CounterDoorways do
			local outside = if door.x < room.x0 then door.x - 1 else door.x + 1
			local open = 0
			for z = door.z0, door.z1 do
				for d = door.d0, door.d1 do
					if Caves.cellAt(seed, outside, d, z) > 0 then
						open += 1
					end
				end
			end
			ok(
				open >= 2,
				"gallery reaches doorway at x=" .. door.x .. " (open cells " .. open .. ", seed " .. seed .. ")"
			)
		end
	end
	-- sealed walls cannot be dug, doorways can
	ok(Anomalies.isSealed(room.x0 - 1, room.d0, room.z0), "wall corner sealed")
	ok(
		not Anomalies.isSealed(Anomalies.CounterDoorways[1].x, room.d1, Anomalies.CounterDoorways[1].z0),
		"doorway diggable"
	)
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

	-- Finds the write that contains a cell and returns its material/occupancy there.
	local function voxelAt(cx, d, cz)
		local center = GridM.cellCenter(plot.originX, plot.originZ, cx, d, cz)
		for i = #writes, 1, -1 do
			local w = writes[i]
			local r = w.region
			if
				center.X > r.min.X
				and center.X < r.max.X
				and center.Y > r.min.Y
				and center.Y < r.max.Y
				and center.Z > r.min.Z
				and center.Z < r.max.Z
			then
				local ix = math.floor((center.X - r.min.X) / 4) + 1
				local iy = math.floor((center.Y - r.min.Y) / 4) + 1
				local iz = math.floor((center.Z - r.min.Z) / 4) + 1
				return w.materials[ix][iy][iz], w.occupancies[ix][iy][iz]
			end
		end
		return nil, nil
	end

	test("generation writes region-aligned voxel arrays in slabs", function()
		TerrainChunkService.ensureDepth(plot, 20)
		eq(plot.generatedDepth, 20, "five slabs of four layers")
		eq(#writes, 5)
		local w = writes[1]
		eq(w.resolution, 4)
		local n = GameConfig.PlotDigCells + 2
		eq(#w.materials, n, "x size")
		eq(#w.materials[1], 4, "y size")
		eq(#w.materials[1][1], n, "z size")
		local size = w.region.max - w.region.min
		eq(size.X, n * 4)
		eq(size.Y, 4 * 4)
		eq(size.Z, n * 4)
		eq(w.region.max.Y, 0, "top at surface")
		eq(w.region.min.X, 396, "border ring included")
		for _, write in writes do
			for _, v in { write.region.min.X, write.region.min.Y, write.region.min.Z } do
				eq(v % 4, 0, "grid aligned")
			end
		end
		eq(writes[2].region.max.Y, writes[1].region.min.Y, "slabs are contiguous")
	end)

	test("voxel array orientation matches cell coordinates", function()
		-- iy = 1 must be the deepest layer of each slab: check against the explicit index too
		local w = writes[2] -- layers 4..7
		local explicit = w.materials[3 + 2][(7 - 5) + 1][7 + 2]
		eq(explicit, Enum.Material.Air, "dug cell (3,5,7) via explicit index")
		local m, o = voxelAt(3, 5, 7)
		eq(m, Enum.Material.Air, "dug cell is air")
		eq(o, 0)
		local m2, o2 = voxelAt(4, 5, 7)
		local r = Resources.get(OreGeneration.resourceAt(99, 4, 5, 7))
		eq(m2, r.terrainMaterial, "damaged cell keeps material")
		ok(o2 < 1 and o2 >= GameConfig.MinOccupancyWhileDamaged, "damaged cell shrinks: " .. o2)
		eq(voxelAt(0, 0, 0), Enum.Material.Grass, "top layer is grass")
		eq(
			voxelAt(-1, 9, 4),
			Resources.get(OreGeneration.resourceAt(99, -1, 9, 4)).terrainMaterial,
			"border ring solid"
		)
	end)

	test("background generation stays ahead and stops when the owner changes", function()
		local spawned = {}
		H.globals.task.spawn = function(f)
			table.insert(spawned, f)
		end
		local owner = {}
		local p2 = { originX = 0, originZ = 0, seed = 5, dug = {}, damage = {}, generatedDepth = 0, owner = owner }
		TerrainChunkService.requestDepth(p2, 40)
		eq(p2.generatedDepth, 0, "nothing generated inside the request (no work on the dig path)")
		eq(#spawned, 1, "worker started")
		TerrainChunkService.requestDepth(p2, 48)
		eq(#spawned, 1, "one worker only")
		spawned[1]()
		eq(p2.generatedDepth, 48, "worker reached the highest requested depth")

		-- owner leaves mid-way: the worker must drop the request
		local p3 = { originX = 0, originZ = 0, seed = 6, dug = {}, damage = {}, generatedDepth = 0, owner = owner }
		local steps = 0
		H.globals.task.wait = function()
			steps += 1
			if steps == 2 then
				p3.owner = nil
			end
		end
		table.clear(spawned)
		TerrainChunkService.requestDepth(p3, 400)
		spawned[1]()
		ok(p3.generatedDepth < 400, "generation stopped after the owner left (" .. p3.generatedDepth .. ")")
		H.globals.task.wait = function() end
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
