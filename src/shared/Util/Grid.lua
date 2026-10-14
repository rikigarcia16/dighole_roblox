--!strict
-- Conversion between world space and plot-local dig cells.
--
-- Local cell coordinates: (cx, d, cz)
--   cx, cz : 0..N-1 inside the dig area, -1 and N are the protected border ring
--   d      : depth in cells, 0 is the top layer just below the surface

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local Grid = {}

local CELL = GameConfig.CellSize
local N = GameConfig.PlotDigCells

Grid.CellSize = CELL
Grid.N = N

export type Cell = { x: number, d: number, z: number }

function Grid.cellCenter(originX: number, originZ: number, cx: number, d: number, cz: number): Vector3
	return Vector3.new(originX + (cx + 0.5) * CELL, GameConfig.SurfaceY - (d + 0.5) * CELL, originZ + (cz + 0.5) * CELL)
end

function Grid.worldToCell(originX: number, originZ: number, position: Vector3): (number, number, number)
	local cx = math.floor((position.X - originX) / CELL)
	local d = math.floor((GameConfig.SurfaceY - position.Y) / CELL)
	local cz = math.floor((position.Z - originZ) / CELL)
	return cx, d, cz
end

function Grid.inDigArea(cx: number, d: number, cz: number): boolean
	return cx >= 0 and cx < N and cz >= 0 and cz < N and d >= 0 and d < GameConfig.MaxDepthCells
end

function Grid.key(cx: number, d: number, cz: number): number
	return (d * N + cz) * N + cx
end

function Grid.fromKey(key: number): (number, number, number)
	local cx = key % N
	local rest = (key - cx) / N
	local cz = rest % N
	local d = (rest - cz) / N
	return cx, d, cz
end

function Grid.depthMetersFromY(y: number): number
	return math.max(0, (GameConfig.SurfaceY - y) / GameConfig.StudsPerMeter)
end

-- Cells (relative offsets) inside a sphere of `radius` cells, sorted by distance so the target
-- cell is always first.
local offsetCache: { [number]: { { number } } } = {}
function Grid.sphereOffsets(radius: number): { { number } }
	local cached = offsetCache[radius]
	if cached then
		return cached
	end
	local result = {}
	local r = math.ceil(radius)
	for dx = -r, r do
		for dy = -r, r do
			for dz = -r, r do
				local dist2 = dx * dx + dy * dy + dz * dz
				if dist2 <= radius * radius + 1e-6 then
					table.insert(result, { dx, dy, dz, dist2 })
				end
			end
		end
	end
	table.sort(result, function(a, b)
		return a[4] < b[4]
	end)
	offsetCache[radius] = result
	return result
end

return Grid
