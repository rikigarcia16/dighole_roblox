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

-- Called with (plot, firstDepth, lastDepth) after each generated chunk (used to place cave props,
-- chests and story objects).
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

-- Material and occupancy of a single cell given the plot state.
function TerrainChunkService.cellState(plot: PlotTerrain, cx: number, d: number, cz: number): (Enum.Material, number)
	local diggable = Grid.inDigArea(cx, d, cz)
	if diggable and plot.dug[Grid.key(cx, d, cz)] then
		return AIR, 0
	end
	local id = OreGeneration.resourceAt(plot.seed, cx, d, cz)
	if id == "air" then
		return AIR, 0
	end
	local resource = Resources.get(id)
	local material = resource and resource.terrainMaterial
	if not resource or not material then
		return Enum.Material.Rock, 1
	end
	if diggable then
		local damage = plot.damage[Grid.key(cx, d, cz)]
		if damage then
			return material, math.max(GameConfig.MinOccupancyWhileDamaged, 1 - damage / resource.hardness)
		end
	end
	return material, 1
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

-- Generates layer chunks until `targetDepth` cells exist below the surface.
function TerrainChunkService.ensureDepth(plot: PlotTerrain, targetDepth: number, yieldBetweenChunks: boolean?)
	targetDepth = math.min(targetDepth, GameConfig.MaxDepthCells + 1)
	while plot.generatedDepth < targetDepth do
		local d0 = plot.generatedDepth
		local d1 = d0 + GameConfig.ChunkDepth - 1
		TerrainChunkService.writeBox(plot, -1, N, d0, d1, -1, N)
		plot.generatedDepth = d1 + 1
		for _, callback in chunkCallbacks do
			local ok, err = pcall(callback, plot, d0, d1)
			if not ok then
				warn("[TerrainChunkService] chunk callback failed:", err)
			end
		end
		if yieldBetweenChunks then
			task.wait()
		end
	end
end

-- Keeps GenerateAheadCells of solid ground below a newly dug depth.
function TerrainChunkService.onDugTo(plot: PlotTerrain, depth: number)
	TerrainChunkService.ensureDepth(plot, depth + GameConfig.GenerateAheadCells)
end

-- Fills the flat ground slab (grass over dirt) covering a world-space rectangle.
function TerrainChunkService.fillSurfaceSlab(minX: number, maxX: number, minZ: number, maxZ: number)
	local sizeX, sizeZ = maxX - minX, maxZ - minZ
	local centerX, centerZ = (minX + maxX) / 2, (minZ + maxZ) / 2
	local top = GameConfig.SurfaceY
	Terrain:FillBlock(
		CFrame.new(centerX, top - CELL / 2, centerZ),
		Vector3.new(sizeX, CELL, sizeZ),
		Enum.Material.Grass
	)
	Terrain:FillBlock(
		CFrame.new(centerX, top - CELL * 1.5, centerZ),
		Vector3.new(sizeX, CELL, sizeZ),
		Enum.Material.Ground
	)
end

-- Removes everything generated for a plot and restores the flat slab over its dig area.
function TerrainChunkService.clear(plot: PlotTerrain)
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
