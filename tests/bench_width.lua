-- Isolated comparison of underground widths (no game data is touched).
-- For each width the whole project is loaded from scratch with GameConfig.PlotDigCells overridden,
-- then generation cost, cave-sector cost, Lua memory and save size are measured in the Luau VM.
-- Run: luaucheck run tests/bench_width.lua
local WIDTHS = { 16, 24, 32, 40 }
local results = {}

local function median(list)
	table.sort(list)
	return list[math.ceil(#list / 2)]
end

for _, W in WIDTHS do
	local H = loadfile("tests/harness.lua")() -- fresh module cache
	H.mount("ReplicatedStorage", "Shared", "src/shared")
	H.mount("ServerScriptService", "Server", "src/server")
	H.globals.workspace =
		{ Terrain = { WriteVoxels = function() end, FillBlock = function() end, SetMaterialColor = function() end } }
	H.globals.Region3 = {
		new = function(a, b)
			return { a, b }
		end,
	}
	H.globals.task = { wait = function() end, spawn = function() end }
	local GameConfig = H.module("ReplicatedStorage", "Shared", "Config", "GameConfig")
	GameConfig.PlotDigCells = W
	local TerrainChunkService = H.module("ServerScriptService", "Server", "Services", "TerrainChunkService")
	local Caves = H.module("ServerScriptService", "Server", "Logic", "Caves")
	local CellSet = H.module("ReplicatedStorage", "Shared", "Util", "CellSet")
	local Grid = H.module("ReplicatedStorage", "Shared", "Util", "Grid")

	-- 1. generate whole plots top-down, slab by slab, exactly like the background worker does
	--    (one-time costs such as cave sectors and fossil bands are included where they happen)
	local slabTimes = {}
	local worst = 0
	for rep = 1, 2 do
		local plot = { originX = 0, originZ = 0, seed = 7000 + rep, dug = {}, damage = {}, generatedDepth = 0 }
		for d0 = 0, 412, 4 do
			local t0 = os.clock()
			TerrainChunkService.writeBox(plot, -1, W, d0, d0 + 3, -1, W)
			local ms = (os.clock() - t0) * 1000
			table.insert(slabTimes, ms)
			worst = math.max(worst, ms)
		end
	end
	local total = 0
	for _, v in slabTimes do
		total += v
	end
	local meanSlab = total / #slabTimes

	-- 2. cave sector build (cold) and Lua memory held by cached sectors
	collectgarbage("collect")
	local memBefore = collectgarbage("count")
	local sectorTimes = {}
	for k = 1, 10 do
		local t0 = os.clock()
		Caves.sector(90000 + k, 4)
		table.insert(sectorTimes, (os.clock() - t0) * 1000)
	end
	collectgarbage("collect")
	local memPerSectorKb = (collectgarbage("count") - memBefore) / 10

	-- 3. save size: a 6x6 shaft to 500 m plus 30 side galleries (3x3 section) spanning the width
	local dug = {}
	local c0 = W // 2 - 3
	for d = 0, 499 do
		for x = c0, c0 + 5 do
			for z = c0, c0 + 5 do
				dug[Grid.key(x, d, z)] = true
			end
		end
	end
	for g = 1, 30 do
		local d = 20 + g * 15
		for x = 0, W - 1 do
			for dd = 0, 2 do
				for z = c0 + 1, c0 + 3 do
					dug[Grid.key(x, d + dd, z)] = true
				end
			end
		end
	end
	local encoded = CellSet.encode(dug)
	local chars = 0
	for _, v in encoded do
		chars += #tostring(v) + 1
	end

	table.insert(results, {
		W = W,
		studs = W * 4,
		slab = meanSlab,
		worst = worst,
		chunk = meanSlab * 4,
		sector = median(sectorTimes),
		memSector = memPerSectorKb,
		voxels1500 = (W + 2) * (W + 2) * 1500,
		saveKb = chars / 1024,
	})
end

print(
	string.format(
		"%-6s %-6s %11s %11s %13s %12s %12s %14s %10s",
		"cells",
		"studs",
		"slab mean",
		"slab worst",
		"16 m (ms)",
		"sector (ms)",
		"sector (KB)",
		"voxels@1500m",
		"save (KB)"
	)
)
for _, r in results do
	print(
		string.format(
			"%-6d %-6d %11.1f %11.1f %13.1f %12.2f %12.0f %14d %10.1f",
			r.W,
			r.studs,
			r.slab,
			r.worst,
			r.chunk,
			r.sector,
			r.memSector,
			r.voxels1500,
			r.saveKb
		)
	)
end
local base = results[1]
print("\nrelative to 16 cells:")
for _, r in results do
	print(
		string.format(
			"  %2d cells: slab x%.2f (worst x%.2f), sector x%.2f, memory x%.2f, voxels x%.2f, area x%.2f",
			r.W,
			r.slab / base.slab,
			r.worst / base.worst,
			r.sector / base.sector,
			r.memSector / base.memSector,
			r.voxels1500 / base.voxels1500,
			(r.W * r.W) / (base.W * base.W)
		)
	)
end
