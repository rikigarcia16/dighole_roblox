--!strict
-- Global tuning values. Everything a designer may want to rebalance lives in Config/*.

local GameConfig = {}

GameConfig.GameName = "THE HOLE NEVER ENDS"

-- Grid ---------------------------------------------------------------------
-- One dig cell is one Roblox terrain voxel (4x4x4 studs) and represents 1 metre of depth.
GameConfig.CellSize = 4
GameConfig.StudsPerMeter = 4
GameConfig.SurfaceY = 0 -- world Y of the top of the ground

-- Plots --------------------------------------------------------------------
GameConfig.MaxPlots = 8
GameConfig.PlotDigCells = 16 -- dig area is PlotDigCells x PlotDigCells cells (64x64 studs)
GameConfig.PlotSpacing = 288 -- studs between plot origins along X
GameConfig.PlotFootprint = 224 -- size of the decorated surface square around each dig area
GameConfig.WorldOrigin = Vector3.new(0, 0, 0)

-- Terrain streaming --------------------------------------------------------
GameConfig.ChunkDepth = 16 -- cells per generated layer chunk
GameConfig.InitialChunks = 3 -- chunks generated when a plot is claimed
GameConfig.GenerateAheadCells = 32 -- keep this many cells generated below the deepest dug cell
GameConfig.MaxDepthCells = 2200 -- hard floor; below this there is unbreakable bedrock

-- Digging ------------------------------------------------------------------
GameConfig.DigReachPadding = 3 -- extra studs tolerated on top of a tool's reach (latency)
GameConfig.CooldownTolerance = 0.8 -- server accepts hits this fraction of the tool cooldown apart
GameConfig.MinOccupancyWhileDamaged = 0.25 -- partially damaged cells shrink down to this occupancy
-- Solid cells beside a dug cell (same layer) are written thinner, so walls recede to the cell edge.
-- At full occupancy smooth terrain rounds them 1-2 studs into the opening and a one-cell shaft became
-- a slit the character got wedged in (Studio playtest).
GameConfig.DugWallOccupancy = 0.5
-- The top layer of the ground (cells from SurfaceY - CellSize to SurfaceY) is written at half
-- occupancy so smooth terrain puts its surface exactly at SurfaceY, where every floor, path, deck and
-- the hole's rim are built. At full occupancy it sat 2 studs higher and buried them, and the grass
-- grew through them (measured in Studio: occupancy 1 -> y 2, 0.75 -> y 1, 0.5 -> y 0).
GameConfig.TopLayerOccupancy = 0.5

-- Energy -------------------------------------------------------------------
GameConfig.SurfaceRechargeDepth = 3 -- metres; above this depth the battery recharges
GameConfig.EnergyTickSeconds = 0.25

-- Surface return -----------------------------------------------------------
GameConfig.ReturnToSurfaceCooldown = 8
GameConfig.ReturnButtonMinDepth = 2 -- metres; return button from this depth (the tutorial asks to go up at ~3 m)

-- Interaction distances (studs) ---------------------------------------------
GameConfig.SellDistance = 18
GameConfig.ShopDistance = 22

-- Persistence --------------------------------------------------------------
GameConfig.DataStoreName = "THNE_PlayerData_v1"
GameConfig.AutosaveSeconds = 120
GameConfig.SessionLockTimeout = 360 -- seconds after which a lock from a dead server is considered stale
GameConfig.LoadRetries = 5

-- Remote rate limits (calls per second, burst) -----------------------------
GameConfig.RateLimits = {
	Dig = { rate = 12, burst = 14 },
	Shop = { rate = 4, burst = 8 },
	Sell = { rate = 2, burst = 4 },
	ReturnToSurface = { rate = 1, burst = 2 },
	GetState = { rate = 2, burst = 5 },
}

return GameConfig
