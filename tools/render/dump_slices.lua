-- Dumps cross-sections of a generated plot for tools/render/render.py.
-- Usage: luaucheck run tools/render/dump_slices.lua  (seed and range edited below or via SEED file)
local H = loadfile("tests/harness.lua")()
H.mount("ReplicatedStorage", "Shared", "src/shared")
H.mount("ServerScriptService", "Server", "src/server")
local OreGeneration = H.module("ServerScriptService", "Server", "Logic", "OreGeneration")
local Resources = H.module("ReplicatedStorage", "Shared", "Config", "Resources")
local FossilBeds = H.module("ServerScriptService", "Server", "Logic", "FossilBeds")

local SEEDS = { 1234, 98765, 4242 }
local D0, D1 = 40, 360
local N = 16

local function code(id)
	if id == "air" then return "." end
	if id == "water" then return "~" end
	local r = Resources.get(id)
	if r and r.isOre then return "o" end
	return "#"
end

for _, seed in SEEDS do
	-- vertical sections through x = 4, 8, 12 (d rows, z columns)
	for _, x in { 4, 8, 12 } do
		print(string.format("SLICE seed=%d axis=x value=%d", seed, x))
		for d = D0, D1 do
			local row = {}
			for z = -1, N do
				table.insert(row, if FossilBeds.bedAt(seed, x, d, z) then "f" else code(OreGeneration.resourceAt(seed, x, d, z)))
			end
			print(table.concat(row))
		end
		print("END")
	end
	-- horizontal plans every 8 m (x rows, z columns)
	print(string.format("PLANS seed=%d", seed))
	for d = 64, D1, 4 do
		local rows = {}
		for x = -1, N do
			local row = {}
			for z = -1, N do
				table.insert(row, if FossilBeds.bedAt(seed, x, d, z) then "f" else code(OreGeneration.resourceAt(seed, x, d, z)))
			end
			table.insert(rows, table.concat(row))
		end
		print(string.format("PLAN d=%d %s", d, table.concat(rows, "|")))
	end
	print("END")
end
