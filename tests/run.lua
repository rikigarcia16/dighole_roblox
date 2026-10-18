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

test("tool feel: every tool has its own weight, heavier tools feel heavier, punches stay small", function()
	local DigFeel = H.module("ReplicatedStorage", "Shared", "Config", "DigFeel")
	local previous = 0
	for _, tool in Tools.List do
		local feel = DigFeel.ToolFeel[tool.id]
		ok(feel, tool.id .. " has no feel")
		ok(feel.weight >= previous, tool.id .. ": weight must not drop with a better tool")
		previous = feel.weight
		ok(feel.shake >= 0 and feel.shake <= 0.6, tool.id .. ": camera punch too strong")
		ok(not feel.glow or feel.spark, tool.id .. ": glow needs a colour")
	end
	eq(DigFeel.toolFeel(nil).weight, 1, "unknown tool falls back")
	ok(DigFeel.ToolFeel.rusty_shovel.spark == nil, "the rusty shovel throws no sparks")
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

test("battery: sold because gear uses it, never consumed by digging; gear is sane", function()
	ok(not Upgrades.ById.battery.hidden, "battery sold (lamp and detector use it)")
	for _, tool in Tools.List do
		ok(tool.energyCost ~= nil, tool.id) -- field kept for old saves; DiggingService ignores it
	end
	local Gear = H.module("ReplicatedStorage", "Shared", "Config", "Gear")
	local base = Upgrades.valueAt("battery", 1)
	ok(base / Gear.Lamp.drainPerSecond >= 60, "the starting battery lights the lamp for a minute or more")
	ok(base / Gear.Detector.pulseCost >= 4, "and gives a few detector pulses")
	local last = 0
	for _, def in Gear.List do
		ok(def.price > last, def.id .. ": gear ordered by price")
		last = def.price
		ok(#def.key == 1, def.id .. " key hint")
	end
	ok(Gear.Hook.range >= 30 and Gear.Hook.range <= 48, "hook reach")
end)

test("resonance detector: nearest within range, rough band, never exact", function()
	local Resonance = H.module("ServerScriptService", "Server", "Logic", "Resonance")
	local from = H.Vector3.new(0, 0, 0)
	local targets = {
		{ kind = "chest", position = H.Vector3.new(50, 0, 0) },
		{ kind = "geode", position = H.Vector3.new(0, -20, 0) },
		{ kind = "fossil", position = H.Vector3.new(500, 0, 0) },
	}
	local r = Resonance.read(targets, from, 120)
	eq(r.kind, "geode", "nearest wins")
	eq(r.band, "muy cerca")
	ok(math.abs(r.direction.Y + 1) < 1e-9, "points down towards it")
	eq(Resonance.read({ targets[3] }, from, 120), nil, "out of range: silence")
	eq(Resonance.read({}, from, 120), nil)
	eq(Resonance.read({ targets[1] }, from, 120).band, "cerca")
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
	-- the original 12 quests are done; the chain now continues with the layers below 150 m
	eq(p.quests.index, 13, "old chain finished")
	eq(QuestLogic.view(p).id, "station_1", "continues with the new chain")
	-- a player who had finished the old chain (saved index 13 = old #Quests + 1) continues too
	local veteran = ProfileSchema.reconcile({ version = 4, quests = { index = 13, completed = {} } }, 1)
	eq(QuestLogic.view(veteran).id, "station_1", "veteran continues")
	-- satisfy everything: the whole chain completes, each quest pays once
	table.insert(p.mobility.stations, { id = "mines", cx = 1, d = 60, cz = 1 })
	p.anomalies.counter.found = true
	p.anomalies.counter.solved = true
	local Fossils = H.module("ReplicatedStorage", "Shared", "Config", "Fossils")
	for _, sp in Fossils.List do
		p.collection.fossils[sp.id] = { count = 1, firstDepth = sp.minDepth }
	end
	for _, id in
		{ "amethyst", "gold", "blue_crystal", "ruby", "relic", "obsidian", "abyss_crystal", "ancient_artifact" }
	do
		p.discoveries[id] = 1
	end
	p.stats.geodesOpened = 3
	p.tools.industrial_pick = true
	p.tools.portable_drill = true
	p.stats.maxDepth = 1600
	local before = p.coins
	QuestLogic.advance(p)
	eq(QuestLogic.view(p), nil, "chain finished")
	eq(p.quests.index, #Quests + 1)
	local expected = 0
	for i, q in Quests do
		ok(p.quests.completed[q.id], q.id .. " completed")
		if i >= 13 then
			expected += q.reward
		end
	end
	eq(p.coins - before, expected, "each new quest paid exactly once")
	eq(#QuestLogic.advance(p), 0)
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
		if q.kind == "set" then
			local found = false
			for _, set in H.module("ReplicatedStorage", "Shared", "Config", "Collections") do
				found = found or set.id == q.key
			end
			ok(found, q.id .. ": unknown set")
		end
		if q.kind == "counter" then
			ok(q.key == "found" or q.key == "solved", q.id)
		end
		if q.kind == "fossils" then
			ok(q.target <= #H.module("ReplicatedStorage", "Shared", "Config", "Fossils").List, q.id)
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
	local QuestsConfig = H.module("ReplicatedStorage", "Shared", "Config", "Quests")
	ok(bad.quests.index <= #QuestsConfig + 1, "quest index clamped")
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
	eq(r.version, ProfileSchema.CURRENT_VERSION)
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
		-- solid foundation: nothing opens right under the floor (players fell under the room in Studio)
		for x = room.x0 - 2, room.x1 + 2 do
			for d = room.d1 + 2, room.d1 + 8 do
				for z = room.z0 - 2, room.z1 + 2 do
					ok(Anomalies.inFoundation(x, d, z), "foundation box")
					local id = Caves.cellAt(seed, x, d, z)
					-- a sealed geode pocket is fine (it is not open space to fall into)
					ok(
						id == 0 or (sector.systems[id] and sector.systems[id].hasCave == false),
						"open cave under the room at " .. x .. "," .. d .. "," .. z .. " (seed " .. seed .. ")"
					)
				end
			end
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

test("counter puzzle: per-plot solution, never starts solved, rings lock, solves in <= 15 turns", function()
	local CounterPuzzle = H.module("ServerScriptService", "Server", "Logic", "CounterPuzzle")
	local differentSolutions = {}
	for seed = 1, 60 do
		local solution = CounterPuzzle.solution(seed)
		differentSolutions[table.concat(solution, ",")] = true
		ok(not (solution[1] == solution[2] and solution[2] == solution[3]), "three identical glyphs")
		local state = CounterPuzzle.initial(seed)
		for ring = 1, 3 do
			ok(not CounterPuzzle.isLocked(seed, state, ring), "ring starts unlocked")
		end
		local turns = 0
		while not state.solved and turns < 40 do
			for ring = 1, 3 do
				local changed = CounterPuzzle.rotate(seed, state, ring)
				if changed then
					turns += 1
				end
			end
		end
		ok(state.solved and turns <= 15, "solved in " .. turns .. " turns")
		local changed = CounterPuzzle.rotate(seed, state, 1)
		ok(not changed, "nothing turns once solved")
	end
	local count = 0
	for _ in differentSolutions do
		count += 1
	end
	ok(count > 30, "solutions vary between plots: " .. count)
	-- a locked ring cannot be turned away from its glyph
	local seed = 11
	local state = CounterPuzzle.initial(seed)
	while not CounterPuzzle.isLocked(seed, state, 1) do
		CounterPuzzle.rotate(seed, state, 1)
	end
	local before = state.rings[1]
	ok(not CounterPuzzle.rotate(seed, state, 1) and state.rings[1] == before, "locked ring stays")
	-- sanitize never un-solves and repairs garbage
	eq(CounterPuzzle.sanitize(seed, { solved = true }).solved, true)
	local repaired = CounterPuzzle.sanitize(seed, { rings = { 99, "x" } })
	ok(#repaired.rings == 3 and repaired.rings[1] >= 1 and repaired.rings[1] <= 6, "repaired")
	ok(not CounterPuzzle.rotate(seed, state, 4) and not CounterPuzzle.rotate(seed, state, 1.5), "invalid ring ignored")
end)

test("journal: entries and paragraphs follow discoveries, numbers are filled in", function()
	local JournalView = H.module("ReplicatedStorage", "Shared", "Util", "JournalView")
	local p = ProfileSchema.default(1)
	eq(#JournalView.entries(p), 0, "nothing before finding the room")
	p.anomalies.counter.found = true
	local entries = JournalView.entries(p)
	eq(#entries, 1)
	ok(entries[1].body:find("se callo") or entries[1].body:find("se calló"), "unsolved text")
	p.anomalies.counter.solved = true
	p.anomalies.counter.solvedCount = 1247
	p.stats.cellsDug = 1300
	entries = JournalView.entries(p)
	local solved
	for _, e in entries do
		if e.id == "counter_solved" then
			solved = e
		end
	end
	ok(solved and solved.body:find("1247") and solved.body:find("1300"), "numbers filled")
	ok(not solved.body:find("huella"), "imprint paragraph hidden until the fossil is found")
	p.collection.fossils.shovel_imprint = { count = 1, firstDepth = 120 }
	for _, e in JournalView.entries(p) do
		if e.id == "counter_solved" then
			ok(e.body:find("huella"), "imprint paragraph appears")
		end
	end
	ok(not JournalView.holds({ somethingNew = true }, p), "unknown conditions hide content")
end)

test("collection sets: pay once when complete, progress visible, journal grows", function()
	local CollectionSets = H.module("ServerScriptService", "Server", "Logic", "CollectionSets")
	local Collections = H.module("ReplicatedStorage", "Shared", "Config", "Collections")
	local JournalView = H.module("ReplicatedStorage", "Shared", "Util", "JournalView")
	local p = ProfileSchema.default(3)
	for _, set in Collections do
		for _, id in set.items or {} do
			ok(Resources.get(id), set.id .. ": unknown item " .. id)
		end
		ok(set.reward > 0, set.id .. " reward")
	end
	p.discoveries.coal, p.discoveries.copper, p.discoveries.iron = 3, 1, 1
	eq(#CollectionSets.advance(p), 0, "3/4 is not complete")
	local view = CollectionSets.view(p)
	eq(view[1].have, 3)
	eq(view[1].total, 4)
	p.discoveries.silver = 1
	local coins = p.coins
	local done = CollectionSets.advance(p)
	eq(#done, 1)
	eq(done[1].id, "upper_ores")
	eq(p.coins - coins, done[1].reward)
	eq(#CollectionSets.advance(p), 0, "never pays twice")
	ok(CollectionSets.isComplete("upper_ores", p))
	-- the completion survives save and load (stored in quests.completed)
	local loaded = ProfileSchema.reconcile(dataStoreRoundTrip(p), 1)
	ok(CollectionSets.isComplete("upper_ores", loaded), "completion persisted")
	eq(#CollectionSets.advance(loaded), 0, "no second payment after rejoin")
	-- journal: the collections entry appears with its line
	local state = { sets = CollectionSets.view(loaded) }
	local entry
	for _, e in JournalView.entries(state) do
		if e.id == "collections" then
			entry = e
		end
	end
	ok(entry and entry.body:find("Carbón"), "journal line for the completed set")
	ok(not entry.body:find("Siete especies"), "no line for an incomplete set")
	eq(#JournalView.entries({ sets = CollectionSets.view(ProfileSchema.default(1)) }) >= 0, true)
	for _, e in JournalView.entries({ sets = CollectionSets.view(ProfileSchema.default(1)) }) do
		ok(e.id ~= "collections", "hidden until a set is complete")
	end
end)

test("keep or sell: relics survive 'sell all', the case completes their collection, saves are safe", function()
	local InventoryLogic = H.module("ServerScriptService", "Server", "Logic", "Inventory")
	local CollectionSets = H.module("ServerScriptService", "Server", "Logic", "CollectionSets")
	local inv = { copper = 3, relic = 1, antique_fragment = 2, stone = 5, bogus_item = 4 }
	local value = InventoryLogic.takeSellable(inv)
	eq(value, Resources.get("copper").value * 3 + Resources.get("stone").value * 5)
	eq(inv.copper, nil)
	eq(inv.relic, 1, "relic kept")
	eq(inv.antique_fragment, 2, "fragment kept")
	eq(inv.bogus_item, nil, "unknown ids dropped")
	eq(InventoryLogic.keptCount(inv), 3)
	for _, id in { "antique_fragment", "relic", "ancient_artifact" } do
		ok(Resources.get(id).keep, id .. " is a kept piece")
	end
	-- the relics collection needs the pieces EXHIBITED, not just found
	local p = ProfileSchema.default(5)
	p.discoveries.antique_fragment, p.discoveries.relic, p.discoveries.ancient_artifact = 1, 1, 1
	for _, set in CollectionSets.advance(p) do
		ok(set.id ~= "relics", "found is not enough for the relics set")
	end
	p.collection.exhibit.antique_fragment = true
	p.collection.exhibit.relic = true
	p.collection.exhibit.ancient_artifact = true
	local paid = false
	for _, set in CollectionSets.advance(p) do
		paid = paid or set.id == "relics"
	end
	ok(paid, "relics set completes once all three are shown")
	-- the case survives save/load; junk and non-keep ids are dropped; old saves get an empty case
	p.collection.exhibit.copper = true
	local loaded = ProfileSchema.reconcile(dataStoreRoundTrip(p), 1)
	ok(loaded.collection.exhibit.relic and loaded.collection.exhibit.ancient_artifact, "case persisted")
	eq(loaded.collection.exhibit.copper, nil, "only kept pieces can be exhibited")
	local old = ProfileSchema.reconcile({ version = 4, collection = { fossils = {} } }, 1)
	ok(type(old.collection.exhibit) == "table" and next(old.collection.exhibit) == nil, "old save: empty case")
	local junk = ProfileSchema.reconcile({ version = 4, collection = { exhibit = { [1] = true, relic = "yes" } } }, 1)
	eq(next(junk.collection.exhibit), nil, "junk exhibit dropped")
end)

test("tutorial: each hint follows what the player has done and ends for good", function()
	local TutorialLogic = H.module("ReplicatedStorage", "Shared", "Util", "TutorialLogic")
	local state = {
		stats = { cellsDug = 0, sales = 0 },
		used = 0,
		capacity = 20,
		coins = 0,
		tools = { rusty_shovel = true },
		maxDepth = 0,
		settings = { tutorialDone = false },
	}
	eq(TutorialLogic.step(state).id, "dig")
	ok(TutorialLogic.step(state, true).text:find("CAVAR"), "touch wording")
	state.stats.cellsDug = 5
	state.used = 4
	eq(TutorialLogic.step(state).id, "fill")
	state.used = 10
	local s = TutorialLogic.step(state)
	eq(s.id, "sell")
	eq(s.target, "sell")
	state.stats.sales, state.used = 1, 0
	eq(TutorialLogic.step(state).id, "earn")
	state.coins = Tools.get("reinforced_shovel").price
	eq(TutorialLogic.step(state).target, "shop")
	state.tools.reinforced_shovel = true
	eq(TutorialLogic.step(state).id, "deeper")
	state.maxDepth = TutorialLogic.FinishDepth
	eq(TutorialLogic.step(state), nil, "finished by depth")
	state.maxDepth, state.settings.tutorialDone = 0, true
	eq(TutorialLogic.step(state), nil, "never again once done")
	eq(TutorialLogic.step(nil), nil)
end)

test("settings: validated from the client and from saves, defaults for old saves", function()
	local p = ProfileSchema.default(1)
	eq(p.settings.effects, 0)
	ok(p.settings.shake and not p.settings.tutorialDone)
	ProfileSchema.applySettings(p.settings, { effects = 2, shake = false, tutorialDone = true, junk = 1 })
	eq(p.settings.effects, 2)
	eq(p.settings.shake, false)
	ok(p.settings.tutorialDone)
	eq(p.settings.junk, nil, "unknown keys ignored")
	ProfileSchema.applySettings(p.settings, { effects = 9, shake = "no", tutorialDone = false })
	eq(p.settings.effects, 2, "out of range ignored")
	eq(p.settings.shake, false, "wrong type ignored")
	ok(p.settings.tutorialDone, "tutorial cannot be reset from the client")
	ProfileSchema.applySettings(p.settings, { effects = 0 / 0 })
	eq(p.settings.effects, 2, "NaN ignored")
	ProfileSchema.applySettings(p.settings, "garbage")
	local loaded = ProfileSchema.reconcile(dataStoreRoundTrip(p), 1)
	eq(loaded.settings.effects, 2)
	eq(loaded.settings.shake, false)
	local old = ProfileSchema.reconcile({ version = 4 }, 1)
	eq(old.settings.effects, 0, "old save gets defaults")
	-- gear: owned items survive save/load; unknown ids and junk are dropped; old saves own nothing
	p.gear.lamp, p.gear.hook = true, true
	local withGear = ProfileSchema.reconcile(dataStoreRoundTrip(p), 1)
	ok(withGear.gear.lamp and withGear.gear.hook and not withGear.gear.detector, "gear persisted")
	local junk = ProfileSchema.reconcile({ version = 4, gear = { jetpack = true, lamp = "yes", [1] = true } }, 1)
	eq(next(junk.gear), nil, "junk gear dropped")
	eq(next(old.gear), nil, "old save owns no gear")
end)

test("profile v3 data migrates to v4; counter and mobility sanitised", function()
	local r = ProfileSchema.reconcile({
		version = 3,
		clues = { stone_tablet = true },
		anomalies = { counter = { found = true, solved = true, solvedCount = 812.7, rings = { 2, 9 } } },
		mobility = {
			ropes = 500,
			stations = {
				{ id = "mines", cx = 3, d = 60, cz = 4 },
				{ id = "mines", cx = 1, d = 1, cz = 1 },
				{ id = 5 },
				{ id = "from_a_newer_build", cx = 1, d = 1, cz = 1 },
				{ id = "crystal", cx = 0 / 0, d = 200, cz = 1 },
			},
			placedRopes = {
				{ cx = 1, d = 60, cz = 2, length = 18 },
				"bad",
				{ cx = 1, d = 60, cz = 2, length = math.huge },
				{ cx = 1, d = 60, cz = 2, length = 5000 },
			},
		},
	}, 1)
	eq(r.version, 4)
	ok(r.clues.stone_tablet, "tablet clue kept")
	ok(r.anomalies.counter.solved and r.anomalies.counter.solvedCount == 812, "counter kept")
	eq(#r.anomalies.counter.rings, 0, "invalid rings dropped (restarted from seed)")
	eq(r.mobility.ropes, 99, "ropes clamped")
	eq(#r.mobility.stations, 1, "duplicate, unknown, NaN stations dropped")
	eq(#r.mobility.placedRopes, 1, "infinite / oversized ropes dropped")
	dataStoreRoundTrip(r)
end)

test("cave scenes: on real floors / ceilings, within budget, each style tells its own story", function()
	local ScenePlan = H.module("ServerScriptService", "Server", "Logic", "ScenePlan")
	local seen = {} -- style -> kind -> sectors with it
	local sectorsOfStyle = {}
	local total, sectorsCounted, maxProps = 0, 0, 0
	for seed = 1, 30 do
		for index = 2, 48 do
			local sector = Caves.sector(seed, index)
			local props = ScenePlan.plan(seed, sector)
			ok(#props <= ScenePlan.Budget, "budget exceeded: " .. #props)
			total += #props
			sectorsCounted += 1
			maxProps = math.max(maxProps, #props)
			sectorsOfStyle[sector.style] = (sectorsOfStyle[sector.style] or 0) + 1
			local kinds = {}
			for _, prop in props do
				local x, z = math.floor(prop.x), math.floor(prop.z)
				local where = string.format("%s at %d,%d,%d (seed %d)", prop.kind, x, prop.d, z, seed)
				local id, water = Caves.cellAt(seed, x, prop.d, z)
				ok(id > 0 and not water, where .. " is not in open air")
				if prop.anchor == "floor" then
					eq(Caves.cellAt(seed, x, prop.d + 1, z), 0, where .. " floats: no rock below")
				else
					eq(Caves.cellAt(seed, x, prop.d - 1, z), 0, where .. " hangs from nothing")
				end
				ok(not Anomalies.inReserved(x, prop.d, z), where .. " inside the Counter's box")
				-- signature kinds stay in their style
				for style, list in ScenePlan.Signature do
					for _, kind in list do
						if kind == prop.kind and kind ~= "chalk" then
							eq(sector.style, style, prop.kind .. " outside its style")
						end
					end
				end
				kinds[prop.kind] = true
			end
			seen[sector.style] = seen[sector.style] or {}
			for kind in kinds do
				seen[sector.style][kind] = (seen[sector.style][kind] or 0) + 1
			end
		end
	end
	-- every style shows its signature scenes regularly
	for style, list in ScenePlan.Signature do
		local n = sectorsOfStyle[style] or 0
		ok(n > 0, "no sector of style " .. style)
		local withAny = 0
		for _, kind in list do
			withAny = math.max(withAny, (seen[style] or {})[kind] or 0)
		end
		ok(withAny / n >= 0.5, style .. ": signature scene in only " .. withAny .. "/" .. n .. " sectors")
	end
	-- rails and E.'s chalk exist (mines)
	ok(((seen.mine or {}).rails or 0) > 0, "rails")
	ok(((seen.mine or {}).chalk or 0) > 0, "chalk arrows on the guided galleries")
	print(string.format("       scenes: %.1f props per sector on average, max %d", total / sectorsCounted, maxProps))
end)

test("decoration streaming: far sectors unload, they come back near a player, stateful ones untouched", function()
	local DecorStreaming = H.module("ServerScriptService", "Server", "Logic", "DecorStreaming")
	local decorated = { [2] = true, [3] = true, [4] = true, [5] = true, [9] = true }
	local loaded = { [2] = true, [3] = true, [4] = true, [5] = true, [9] = true }
	local toLoad, toUnload = DecorStreaming.plan(decorated, loaded, { 3 })
	eq(#toLoad, 0)
	eq(table.concat(toUnload, ","), "9", "only the far sector unloads")
	loaded[9] = nil
	toLoad, toUnload = DecorStreaming.plan(decorated, loaded, { 8 })
	eq(table.concat(toLoad, ","), "9", "comes back when a player is near")
	eq(table.concat(toUnload, ","), "2,3,4,5")
	-- nobody in the plot: everything unloads; never loads a sector that was never decorated
	toLoad, toUnload = DecorStreaming.plan(decorated, loaded, {})
	eq(#toLoad, 0)
	eq(#toUnload, 4)
	toLoad = DecorStreaming.plan({}, {}, { 4 })
	eq(#toLoad, 0, "undecorated sectors are generated by SpecialsService, not here")
	-- two players far apart keep both neighbourhoods
	toLoad, toUnload = DecorStreaming.plan(decorated, {}, { 2, 9 })
	eq(table.concat(toLoad, ","), "2,3,4,9")
end)

test("zone look: every zone has an art direction, layers blend at boundaries and darken with depth", function()
	local Visuals = H.module("ReplicatedStorage", "Shared", "Config", "Visuals")
	local ZoneLook = H.module("ReplicatedStorage", "Shared", "Util", "ZoneLook")
	local function close(a, b, eps)
		return math.abs(a - b) <= (eps or 1e-6)
	end
	local function sameColor(a, b, eps)
		return close(a.R, b.R, eps) and close(a.G, b.G, eps) and close(a.B, b.B, eps)
	end
	for _, zone in Zones.List do
		ok(Visuals.Zones[zone.id], "art direction for " .. zone.id)
		local air = Visuals.Zones[zone.id].air
		ok(air.rate > 0 and air.rate <= 20, zone.id .. ": particle budget")
		ok(air.glow >= 0 and air.glow <= 1, zone.id .. ": glow range")
	end
	-- continuous across every boundary: just above and just below look (almost) the same
	for i = 1, #Zones.List - 1 do
		local boundary = Zones.List[i].maxDepth
		local above, below = ZoneLook.at(boundary - 0.01), ZoneLook.at(boundary + 0.01)
		ok(close(above.fogEnd, below.fogEnd, 2), "fog continuous at " .. boundary .. " m")
		ok(sameColor(above.ambient, below.ambient, 0.01), "ambient continuous at " .. boundary .. " m")
		ok(close(above.saturation, below.saturation, 0.01), "grade continuous at " .. boundary .. " m")
		-- and far from a boundary it is the zone's own look
		local mid = (Zones.List[i].minDepth + boundary) / 2
		eq(ZoneLook.at(mid).zoneId, Zones.List[i].id)
		eq(ZoneLook.at(mid).bloom, Visuals.Zones[Zones.List[i].id].bloom, "own look mid-zone")
	end
	-- deeper inside a zone is darker and the fog closer
	local top, bottom = ZoneLook.at(60), ZoneLook.at(140)
	ok(bottom.fogEnd < top.fogEnd, "fog closes with depth")
	ok(bottom.ambient.R < top.ambient.R, "ambient darkens with depth")
	-- the quality scale never turns the world off and never exceeds full
	for level = 0, 10 do
		local s = Visuals.qualityScale(level)
		ok(s > 0 and s <= 1, "quality scale " .. level)
	end
	ok(Visuals.qualityScale(1) < Visuals.qualityScale(10), "low quality spends less")
end)

test("discovery bonus: first find pays, structure rewards (fossil fragment, geode) never do", function()
	local InventoryLogic = H.module("ServerScriptService", "Server", "Logic", "Inventory")
	local copper = Resources.get("copper")
	eq(InventoryLogic.discoveryBonus(copper, true), copper.value * 5)
	eq(InventoryLogic.discoveryBonus(copper, false), 0)
	for _, r in Resources.List do
		if r.rewardOnly then
			eq(InventoryLogic.discoveryBonus(r, true), 0, r.id .. " pays a discovery bonus")
		end
	end
	eq(InventoryLogic.discoveryBonus(Resources.get("fossil"), true), 0, "repeated fossil pays +225 again")
end)

test("rescue beacon: free near the surface, bounded cost, never more than the coins held", function()
	local MobilityRules = H.module("ReplicatedStorage", "Shared", "Util", "MobilityRules")
	local q = MobilityRules.quote(30, 500, 0, {})
	ok(q.free and q.pay == 0 and q.destination == "surface", "free above 50 m")
	q = MobilityRules.quote(60, 0, 1000, {})
	eq(q.cost, 30, "0.5 per metre")
	eq(q.pay, 30)
	q = MobilityRules.quote(60, 0, 5, {})
	ok(q.pay == 5 and q.waived == 25, "a poor player pays what they have; nobody is stuck")
	q = MobilityRules.quote(55, 10, 1000, {})
	ok(q.cost >= 10, "minimum cost")
	-- huge backpacks are capped by depth so the beacon never becomes a tax on success
	q = MobilityRules.quote(100, 1e7, 1e9, {})
	eq(q.cost, 50 + 1.5 * 100, "max cost")
	-- newcomers: shallow mines with a modest backpack cost little
	ok(MobilityRules.rescueCost(70, 150) <= 45, "cheap for a new player: " .. MobilityRules.rescueCost(70, 150))
	-- destinations: nearest station above, never one below
	local stations = { { id = "mines", cx = 1, d = 60, cz = 1 }, { id = "counter", cx = 5, d = 141, cz = 5 } }
	eq(MobilityRules.quote(140, 0, 99, stations).destination, "mines", "counter is not above 140")
	eq(MobilityRules.quote(200, 0, 99, stations).destination, "counter")
	eq(MobilityRules.quote(63, 0, 99, stations).destination, "surface", "station must be clearly above")
end)

test("lift stations: one per zone, spacing, the Counter's is granted not bought", function()
	local MobilityRules = H.module("ReplicatedStorage", "Shared", "Util", "MobilityRules")
	local def = MobilityRules.installable(40, {})
	eq(def, nil, "nothing in the garden")
	def = MobilityRules.installable(70, {})
	ok(def and def.id == "mines", "mines station from 50 m")
	local none, reason = MobilityRules.installable(90, { { id = "mines", cx = 1, d = 60, cz = 1 } })
	ok(none == nil and reason and reason:find("Ya tienes"), "only one per zone")
	def = MobilityRules.installable(140, {})
	ok(def and def.id == "mines", "the Counter's station is never offered for purchase")
	ok(not MobilityRules.farEnough(2, 61, 2, { { id = "mines", cx = 1, d = 60, cz = 1 } }), "too close")
	ok(MobilityRules.farEnough(10, 70, 10, { { id = "mines", cx = 1, d = 60, cz = 1 } }), "far enough")
end)

print("Sessions (fake DataStore, several servers)")
do
	-- A DataStore that serialises every write (like the real one) and a scheduler where task.wait
	-- parks the coroutine until the test resumes it, so "time" passes only when the test says so.
	local records = {}
	local failNext = 0
	local onUpdate: ((string) -> ())? = nil
	local fakeStore = {
		UpdateAsync = function(_, key, transform)
			if failNext > 0 then
				failNext -= 1
				error("DataStore request failed (simulated)")
			end
			if onUpdate then
				onUpdate(key)
			end
			local current = records[key] and dataStoreRoundTrip(records[key], "record")
			local result = transform(current)
			if result ~= nil then
				records[key] = dataStoreRoundTrip(result, "record")
			end
		end,
	}
	H.service("DataStoreService", {
		GetDataStore = function()
			return fakeStore
		end,
	})
	H.service("RunService", {
		IsStudio = function()
			return false
		end,
		IsServer = function()
			return true
		end,
	})
	local parked = {}
	H.globals.task = {
		wait = function(seconds)
			local co = coroutine.running()
			table.insert(parked, { co = co, seconds = seconds or 0, job = H.game.JobId })
			return coroutine.yield()
		end,
		spawn = function(f, ...)
			local co = coroutine.create(f)
			local okRun, err = coroutine.resume(co, ...)
			if not okRun then
				error(err, 0)
			end
			return co
		end,
	}
	local function resumeParked(predicate)
		local list = parked
		parked = {}
		for _, entry in list do
			if predicate(entry) then
				local okRun, err = coroutine.resume(entry.co)
				if not okRun then
					error(err, 0)
				end
			else
				table.insert(parked, entry)
			end
		end
	end
	local function signal()
		local handlers = {}
		return {
			Connect = function(_, fn)
				table.insert(handlers, fn)
			end,
			fire = function(...)
				for _, fn in handlers do
					H.globals.task.spawn(fn, ...)
				end
			end,
		}
	end

	-- One "server": its own Players service, JobId and copy of PlayerDataService.
	local function server(jobId)
		local players = { PlayerAdded = signal(), PlayerRemoving = signal() }
		function players.GetPlayers()
			return {}
		end
		H.service("Players", players)
		local closers = {}
		H.game.JobId = jobId
		H.game.BindToClose = function(_, fn)
			table.insert(closers, fn)
		end
		local service = H.fresh("ServerScriptService", "Server", "Services", "PlayerDataService")
		service.start()
		return { service = service, players = players, closers = closers, job = jobId }
	end
	local function newPlayer(userId)
		return {
			UserId = userId,
			Name = "p" .. userId,
			Parent = {},
			Kick = function(self, message)
				self.kicked = message
			end,
		}
	end
	local function join(srv, player)
		player.Parent = {}
		srv.players.PlayerAdded.fire(player)
	end
	local function leave(srv, player)
		player.Parent = nil
		srv.players.PlayerRemoving.fire(player)
	end
	local KEY = "player_77"
	local isAutosave = function(entry)
		return entry.seconds == GameConfig.AutosaveSeconds
	end
	local warnings = {}
	_G.warn = function(...)
		table.insert(warnings, table.concat({ ... }, " "))
	end

	test("session: save on leave, rejoin elsewhere keeps counter, Counter, mobility and finds", function()
		local A = server("job-A")
		local p = newPlayer(77)
		join(A, p)
		local profile = A.service.get(p)
		ok(profile and A.service.isPersistent(p), "loaded with a session")
		eq(records[KEY].lock.jobId, "job-A", "lock taken")
		profile.stats.cellsDug = 3021
		profile.coins = 140
		profile.anomalies.counter.found = true
		profile.anomalies.counter.solved = true
		profile.anomalies.counter.solvedCount = 2990
		profile.mobility.ropes = 3
		table.insert(profile.mobility.stations, { id = "counter", cx = 7, d = 140, cz = 8 })
		table.insert(profile.mobility.placedRopes, { cx = 4.5, d = 61.25, cz = 9, length = 33.5 })
		profile.mobility.rescues = 2
		profile.collection.fossils.eyeless_fish = { count = 1, firstDepth = 96 }
		leave(A, p)
		eq(records[KEY].lock, nil, "lock released on leave")
		eq(A.service.get(p), nil, "session dropped")

		local B = server("job-B")
		join(B, p)
		local again = B.service.get(p)
		ok(again, "rejoined")
		eq(again.stats.cellsDug, 3021, "block counter survives")
		ok(again.anomalies.counter.solved and again.anomalies.counter.solvedCount == 2990, "Counter survives")
		eq(again.mobility.ropes, 3)
		eq(again.mobility.stations[1].id, "counter", "station survives")
		eq(again.mobility.placedRopes[1].length, 33.5, "rope survives")
		eq(again.mobility.rescues, 2)
		eq(again.collection.fossils.eyeless_fish.count, 1, "finds survive")
		-- B keeps the session for the next test
		_G.__sessionB = { srv = B, player = p }
	end)

	test("session: a second server waits for the lock, then loads the newest data", function()
		local B, p = _G.__sessionB.srv, _G.__sessionB.player
		local C = server("job-C")
		local pc = newPlayer(77)
		join(C, pc) -- the player hops servers before B has saved
		eq(C.service.get(pc), nil, "C must not load while B holds the session")
		eq(records[KEY].lock.jobId, "job-B", "B's lock untouched")
		B.service.get(p).stats.cellsDug = 3100 -- B keeps playing a moment
		leave(B, p)
		resumeParked(function(entry)
			return not isAutosave(entry)
		end)
		local profile = C.service.get(pc)
		ok(profile, "C loads once B released")
		eq(profile.stats.cellsDug, 3100, "C sees B's final save")
		eq(records[KEY].lock.jobId, "job-C")
		_G.__sessionC = { srv = C, player = pc }
	end)

	test("session: a crashed server's lock expires; its late autosave never overwrites the new owner", function()
		local C, pc = _G.__sessionC.srv, _G.__sessionC.player
		C.service.get(pc).stats.cellsDug = 1 -- stale state on the crashed server
		records[KEY].lock.time = os.time() - GameConfig.SessionLockTimeout - 5 -- C stopped refreshing
		local D = server("job-D")
		local pd = newPlayer(77)
		join(D, pd)
		local profile = D.service.get(pd)
		ok(profile, "D takes over a stale lock")
		eq(profile.stats.cellsDug, 3100)
		profile.stats.cellsDug = 3200
		-- C wakes up and autosaves: it lost the lock, so nothing is written
		resumeParked(function(entry)
			return isAutosave(entry) and entry.job == "job-C"
		end)
		eq(records[KEY].lock.jobId, "job-D", "lock still D's")
		eq(records[KEY].data.stats.cellsDug, 3100, "C's stale profile was not written")
		leave(D, pd)
		eq(records[KEY].data.stats.cellsDug, 3200, "D's final save written")
		eq(records[KEY].lock, nil)
	end)

	test("session: leaving while the profile loads releases the lock", function()
		local E = server("job-E")
		local p = newPlayer(77)
		onUpdate = function()
			p.Parent = nil -- the player closes the game during the request
			onUpdate = nil
		end
		join(E, p)
		eq(E.service.get(p), nil, "no session for a player who left")
		eq(records[KEY].lock, nil, "lock not leaked: a quick rejoin is not blocked")
		eq(records[KEY].data.stats.cellsDug, 3200, "data untouched")
	end)

	test("session: DataStore down gives a temporary profile that never overwrites real data", function()
		local F = server("job-F")
		local p = newPlayer(77)
		failNext = 3
		join(F, p)
		resumeParked(function(entry)
			return not isAutosave(entry)
		end) -- retry backoff
		resumeParked(function(entry)
			return not isAutosave(entry)
		end)
		local profile = F.service.get(p)
		ok(profile and not F.service.isPersistent(p), "temporary profile")
		eq(profile.stats.cellsDug, 0)
		leave(F, p)
		eq(records[KEY].data.stats.cellsDug, 3200, "real data untouched")
		eq(records[KEY].lock, nil)
	end)
	H.game.BindToClose = nil
end

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
		-- Like Roblox: task.spawn runs at once inside the caller (the Dig handler), task.defer later.
		-- With task.spawn the first slabs would be generated during the dig (found in Studio).
		H.globals.task.spawn = function(f, ...)
			f(...)
		end
		H.globals.task.defer = function(f)
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
