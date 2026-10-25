--!strict
-- Owns every write to Roblox Terrain.
--
-- The terrain of a plot is never stored as voxels: it is a pure function of
--   (plot seed, set of dug cells, partial damage of cells)
-- so any region can be regenerated at any time. Generation happens in horizontal layer chunks
-- (GameConfig.ChunkDepth cells tall) and only ahead of the deepest excavation, which keeps
-- memory and generation cost proportional to how far the player has actually dug.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local OreGeneration = require(script.Parent.Parent.Logic.OreGeneration)

local Terrain = workspace.Terrain
local CELL = GameConfig.CellSize
local N = GameConfig.PlotDigCells
local AIR = Enum.Material.Air

local TerrainChunkService = {}

local chunkCallbacks: { (any, number, number) -> () } = {}

-- Called with (plot, firstDepth, lastDepth) after each generated slab of layers (used to place
-- cave props, chests and story objects).
function TerrainChunkService.onChunkGenerated(callback: (any, number, number) -> ())
	table.insert(chunkCallbacks, callback)
end

export type PlotTerrain = {
	originX: number,
	originZ: number,
	seed: number,
	dug: { [number]: boolean },
	damage: { [number]: number },
	generatedDepth: number, -- number of cell layers generated so far
}

local SIDES = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Whether a cell has a dug cell beside it on the same layer (its wall faces an opening).
local function besideDug(plot: PlotTerrain, cx: number, d: number, cz: number): boolean
	for _, side in SIDES do
		local nx, nz = cx + side[1], cz + side[2]
		if Grid.inDigArea(nx, d, nz) and plot.dug[Grid.key(nx, d, nz)] then
			return true
		end
	end
	return false
end

-- Material and occupancy of a single cell given the plot state.
function TerrainChunkService.cellState(plot: PlotTerrain, cx: number, d: number, cz: number): (Enum.Material, number)
	local diggable = Grid.inDigArea(cx, d, cz)
	if diggable and plot.dug[Grid.key(cx, d, cz)] then
		return AIR, 0
	end
	-- the bedrock: one black layer at the very bottom that no tool digs (CoreService)
	if d >= GameConfig.MaxDepthCells then
		return Enum.Material.Basalt, 1
	end
	-- the protected ring around the hole is bare earth on top, so the hole reads as a hole from the
	-- surface (grass blades hid it completely: Studio playtest)
	if d == 0 and not diggable then
		return Enum.Material.Ground, GameConfig.TopLayerOccupancy
	end
	local id = OreGeneration.resourceAt(plot.seed, cx, d, cz)
	if id == "air" then
		return AIR, 0
	elseif id == "water" then
		return Enum.Material.Water, 1
	end
	local resource = Resources.get(id)
	local material = resource and resource.terrainMaterial
	if not resource or not material then
		return Enum.Material.Rock, 1
	end
	local occupancy = if besideDug(plot, cx, d, cz) then GameConfig.DugWallOccupancy else 1
	if d == 0 then
		occupancy = math.min(occupancy, GameConfig.TopLayerOccupancy) -- flush with the ground around
	end
	if diggable then
		local damage = plot.damage[Grid.key(cx, d, cz)]
		if damage then
			local damaged = math.max(GameConfig.MinOccupancyWhileDamaged, 1 - damage / resource.hardness)
			return material, math.min(occupancy, damaged)
		end
	end
	return material, occupancy
end

-- Rewrites the inclusive cell box [x0..x1] x [d0..d1] x [z0..z1] from the plot state.
function TerrainChunkService.writeBox(
	plot: PlotTerrain,
	x0: number,
	x1: number,
	d0: number,
	d1: number,
	z0: number,
	z1: number
)
	x0, x1 = math.max(x0, -1), math.min(x1, N)
	z0, z1 = math.max(z0, -1), math.min(z1, N)
	d0, d1 = math.max(d0, 0), math.min(d1, GameConfig.MaxDepthCells)
	if x0 > x1 or z0 > z1 or d0 > d1 then
		return
	end

	local materials = table.create(x1 - x0 + 1)
	local occupancies = table.create(x1 - x0 + 1)
	for ix = 1, x1 - x0 + 1 do
		local cx = x0 + ix - 1
		local matX = table.create(d1 - d0 + 1)
		local occX = table.create(d1 - d0 + 1)
		for iy = 1, d1 - d0 + 1 do
			local d = d1 - (iy - 1) -- iy = 1 is the lowest (deepest) layer of the region
			local matY = table.create(z1 - z0 + 1)
			local occY = table.create(z1 - z0 + 1)
			for iz = 1, z1 - z0 + 1 do
				local material, occupancy = TerrainChunkService.cellState(plot, cx, d, z0 + iz - 1)
				matY[iz] = material
				occY[iz] = occupancy
			end
			matX[iy] = matY
			occX[iy] = occY
		end
		materials[ix] = matX
		occupancies[ix] = occX
	end

	local min = Vector3.new(plot.originX + x0 * CELL, GameConfig.SurfaceY - (d1 + 1) * CELL, plot.originZ + z0 * CELL)
	local max =
		Vector3.new(plot.originX + (x1 + 1) * CELL, GameConfig.SurfaceY - d0 * CELL, plot.originZ + (z1 + 1) * CELL)
	Terrain:WriteVoxels(Region3.new(min, max), CELL, materials, occupancies)
end

-- Generation happens in slabs of SLAB layers (~5 ms each in the Luau VM, see
-- tests/bench_generation.lua). Callbacks receive the depth range of each generated slab.
local SLAB = 4
local BACKGROUND_BUDGET_SECONDS = 0.004

-- MicroProfiler labels (Roblox only; no-ops in the offline test runner).
local profileBegin: (string) -> () = (debug :: any).profilebegin or function(_label: string) end
local profileEnd: () -> () = (debug :: any).profileend or function() end

local function generateSlab(plot: PlotTerrain)
	profileBegin("THNE.GenerateSlab")
	local d0 = plot.generatedDepth
	local d1 = math.min(d0 + SLAB - 1, GameConfig.MaxDepthCells)
	TerrainChunkService.writeBox(plot, -1, N, d0, d1, -1, N)
	plot.generatedDepth = d1 + 1
	profileEnd()
	for _, callback in chunkCallbacks do
		profileBegin("THNE.ChunkCallback")
		local ok, err = pcall(callback, plot, d0, d1)
		profileEnd()
		if not ok then
			warn("[TerrainChunkService] chunk callback failed:", err)
		end
	end
end

-- Generates terrain until `targetDepth` cells exist below the surface, yielding between slabs.
-- `stillValid` is checked before every slab so a generation whose owner left stops instead of
-- writing over a plot that is being cleared or reassigned.
function TerrainChunkService.ensureDepth(plot: PlotTerrain, targetDepth: number, stillValid: (() -> boolean)?)
	targetDepth = math.min(targetDepth, GameConfig.MaxDepthCells + 1)
	local sliceStart = os.clock()
	while plot.generatedDepth < targetDepth do
		if stillValid and not stillValid() then
			return
		end
		generateSlab(plot)
		if os.clock() - sliceStart > BACKGROUND_BUDGET_SECONDS * 3 then
			task.wait()
			sliceStart = os.clock()
		end
	end
end

-- Background queue: digging must never wait for generation. Requests are served a few slabs per
-- frame within BACKGROUND_BUDGET_SECONDS; GenerateAheadCells keeps the queue far ahead of players.
type Request = { target: number, owner: any }
local queue: { [any]: Request } = {}
local workerRunning = false

local function runWorker()
	while next(queue) do
		local frameStart = os.clock()
		repeat
			local worked = false
			for plot, request in queue do
				if plot.owner ~= request.owner or plot.generatedDepth >= request.target then
					queue[plot] = nil
				else
					generateSlab(plot)
					worked = true
				end
			end
		until not worked or os.clock() - frameStart > BACKGROUND_BUDGET_SECONDS
		task.wait()
	end
	workerRunning = false
end

function TerrainChunkService.requestDepth(plot: PlotTerrain, targetDepth: number)
	targetDepth = math.min(targetDepth, GameConfig.MaxDepthCells + 1)
	if plot.generatedDepth >= targetDepth then
		return
	end
	local owner = (plot :: any).owner
	local existing = queue[plot]
	if existing and existing.owner == owner then
		existing.target = math.max(existing.target, targetDepth)
	else
		queue[plot] = { target = targetDepth, owner = owner }
	end
	if not workerRunning then
		workerRunning = true -- set before spawning so a deferred start cannot launch two workers
		-- Deferred, not spawned: task.spawn would run the first slabs inside the caller (the Dig
		-- handler), which is exactly what the background queue exists to avoid.
		task.defer(runWorker)
	end
end

-- Keeps GenerateAheadCells of solid ground below a newly dug depth (in the background).
function TerrainChunkService.onDugTo(plot: PlotTerrain, depth: number)
	TerrainChunkService.requestDepth(plot, depth + GameConfig.GenerateAheadCells)
end

-- Writes the top layer of the ground over a world-space rectangle with `material`, at
-- GameConfig.TopLayerOccupancy so its surface sits at SurfaceY (FillBlock can only write full cells).
function TerrainChunkService.writeTopLayer(
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	material: Enum.Material
)
	local top = GameConfig.SurfaceY
	local region = Region3.new(Vector3.new(minX, top - CELL, minZ), Vector3.new(maxX, top, maxZ)):ExpandToGrid(CELL)
	local nx = math.floor(region.Size.X / CELL + 0.5)
	local ny = math.floor(region.Size.Y / CELL + 0.5)
	local nz = math.floor(region.Size.Z / CELL + 0.5)
	local materials = table.create(nx)
	local occupancies = table.create(nx)
	for x = 1, nx do
		local matX, occX = table.create(ny), table.create(ny)
		for y = 1, ny do
			-- only the highest row is the top layer (ExpandToGrid never shrinks the region)
			matX[y] = table.create(nz, material)
			occX[y] = table.create(nz, if y == ny then GameConfig.TopLayerOccupancy else 1)
		end
		materials[x], occupancies[x] = matX, occX
	end
	Terrain:WriteVoxels(region, CELL, materials, occupancies)
end

-- Fills the flat ground slab (grass over dirt) covering a world-space rectangle.
function TerrainChunkService.fillSurfaceSlab(minX: number, maxX: number, minZ: number, maxZ: number)
	local sizeX, sizeZ = maxX - minX, maxZ - minZ
	local centerX, centerZ = (minX + maxX) / 2, (minZ + maxZ) / 2
	local top = GameConfig.SurfaceY
	TerrainChunkService.writeTopLayer(minX, maxX, minZ, maxZ, Enum.Material.Grass)
	Terrain:FillBlock(
		CFrame.new(centerX, top - CELL * 1.5, centerZ),
		Vector3.new(sizeX, CELL, sizeZ),
		Enum.Material.Ground
	)
end

-- Removes everything generated for a plot and restores the flat slab over its dig area.
function TerrainChunkService.clear(plot: PlotTerrain)
	queue[plot] = nil
	local minX, maxX = plot.originX - CELL, plot.originX + (N + 1) * CELL
	local minZ, maxZ = plot.originZ - CELL, plot.originZ + (N + 1) * CELL
	local depth = plot.generatedDepth
	local d = 0
	while d < depth do
		local layers = math.min(64, depth - d)
		local topY = GameConfig.SurfaceY - d * CELL
		local height = layers * CELL
		Terrain:FillBlock(
			CFrame.new((minX + maxX) / 2, topY - height / 2, (minZ + maxZ) / 2),
			Vector3.new(maxX - minX, height, maxZ - minZ),
			AIR
		)
		d += layers
		task.wait()
	end
	plot.generatedDepth = 0
	TerrainChunkService.fillSurfaceSlab(minX, maxX, minZ, maxZ)
end

function TerrainChunkService.applyMaterialColors()
	for _, resource in Resources.List do
		local material = resource.terrainMaterial
		if material then
			pcall(function()
				Terrain:SetMaterialColor(material, resource.color)
			end)
		end
	end
end

return TerrainChunkService
