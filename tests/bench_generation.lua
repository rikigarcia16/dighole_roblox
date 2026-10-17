-- Measures the cost of terrain generation in the Luau VM (same VM as Roblox, interpreter mode).
-- Run: luaucheck run tests/bench_generation.lua
local H = loadfile("tests/harness.lua")()
H.mount("ReplicatedStorage", "Shared", "src/shared")
H.mount("ServerScriptService", "Server", "src/server")
local writes = 0
H.globals.workspace = {
	Terrain = {
		WriteVoxels = function()
			writes += 1
		end,
		FillBlock = function() end,
		SetMaterialColor = function() end,
	},
}
H.globals.Region3 = {
	new = function(a, b)
		return { a, b }
	end,
}
H.globals.task = { wait = function() end }
local OreGeneration = H.module("ServerScriptService", "Server", "Logic", "OreGeneration")
local TerrainChunkService = H.module("ServerScriptService", "Server", "Services", "TerrainChunkService")
local GameConfig = H.module("ReplicatedStorage", "Shared", "Config", "GameConfig")

local function bench(label, fn, reps)
	local t0 = os.clock()
	for _ = 1, reps do
		fn()
	end
	local ms = (os.clock() - t0) / reps * 1000
	print(string.format("%-46s %8.2f ms", label, ms))
	return ms
end

local N = GameConfig.PlotDigCells
for _, d0 in { 16, 64, 160, 400 } do
	local seed = 1000 + d0
	bench(string.format("resourceAt, one chunk (%dx%dx16) at %d m", N + 2, N + 2, d0), function()
		for x = -1, N do
			for d = d0, d0 + 15 do
				for z = -1, N do
					OreGeneration.resourceAt(seed, x, d, z)
				end
			end
		end
	end, 5)
end
local reps = 0
bench("TerrainChunkService.writeBox, full chunk at 64 m", function()
	reps += 1
	local plot = { originX = 0, originZ = 0, seed = 77 + reps, dug = {}, damage = {}, generatedDepth = 0 }
	TerrainChunkService.writeBox(plot, -1, N, 64, 79, -1, N)
end, 5)
bench("writeBox, one radius-3 hit (7x7x7)", function()
	local plot = { originX = 0, originZ = 0, seed = 5, dug = {}, damage = {}, generatedDepth = 0 }
	TerrainChunkService.writeBox(plot, 4, 10, 100, 106, 4, 10)
end, 50)
