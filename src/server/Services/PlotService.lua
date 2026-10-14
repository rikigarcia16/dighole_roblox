--!strict
-- Assigns each player a personal plot, builds it, restores its excavation and handles
-- spawning / returning to the surface.
--
-- Persistence of the hole: the profile stores the plot seed and the set of excavated cells
-- (run-length encoded). On join the terrain is regenerated from the seed and the dug cells are
-- carved again, so the hole looks exactly as the player left it. Partial damage on cells is not
-- saved (it is cosmetic and at most one hit's worth of progress).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local CellSet = require(ReplicatedStorage.Shared.Util.CellSet)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local PlayerDataService = require(script.Parent.PlayerDataService)
local TerrainChunkService = require(script.Parent.TerrainChunkService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local PlotService = {}

export type Plot = {
	index: number,
	originX: number,
	originZ: number,
	owner: Player?,
	seed: number,
	dug: { [number]: boolean },
	damage: { [number]: number },
	generatedDepth: number,
	deepestDug: number,
	ready: boolean,
	releasing: boolean, -- terrain is being cleared; the plot cannot be claimed yet
	collaborators: { [number]: boolean }, -- userIds allowed to dig (owner always allowed)
	folder: Folder?,
	points: WorldBuilder.PlotPoints?,
}

local N = GameConfig.PlotDigCells
local CELL = GameConfig.CellSize

local plots: { Plot } = {}
local plotByPlayer: { [Player]: Plot } = {}
local readyCallbacks: { (Player, Plot) -> () } = {}
local releasedCallbacks: { (Plot) -> () } = {}
local worldFolder: Folder

local function originFor(index: number): (number, number)
	local x = GameConfig.WorldOrigin.X + (index - 1) * GameConfig.PlotSpacing
	local z = GameConfig.WorldOrigin.Z
	-- Origins must sit on the 4-stud terrain grid.
	return math.floor(x / CELL) * CELL, math.floor(z / CELL) * CELL
end

local function worldBounds(): (number, number, number, number)
	local half = GameConfig.PlotFootprint / 2
	local firstX, firstZ = originFor(1)
	local lastX = originFor(GameConfig.MaxPlots)
	local digHalf = N * CELL / 2
	return firstX + digHalf - half - 160, lastX + digHalf + half, firstZ + digHalf - half, firstZ + digHalf + half
end

function PlotService.get(player: Player): Plot?
	return plotByPlayer[player]
end

function PlotService.all(): { Plot }
	return plots
end

-- Plot whose dig area (or border) contains the world position.
function PlotService.plotAt(position: Vector3): Plot?
	for _, plot in plots do
		if plot.owner then
			local cx, _, cz = Grid.worldToCell(plot.originX, plot.originZ, position)
			if cx >= -1 and cx <= N and cz >= -1 and cz <= N then
				return plot
			end
		end
	end
	return nil
end

function PlotService.canDig(player: Player, plot: Plot): boolean
	if not plot.ready or not plot.owner then
		return false
	end
	return plot.owner == player or plot.collaborators[player.UserId] == true
end

function PlotService.onReady(callback: (Player, Plot) -> ())
	table.insert(readyCallbacks, callback)
end

-- Called after a plot is freed (its owner left), before its terrain is cleared.
function PlotService.onReleased(callback: (Plot) -> ())
	table.insert(releasedCallbacks, callback)
end

function PlotService.updateBoard(plot: Plot)
	local points = plot.points
	if not points then
		return
	end
	if plot.owner then
		points.ownerLabel.Text = "Parcela de " .. plot.owner.DisplayName
		points.depthLabel.Text = "Récord: " .. Format.depth(plot.deepestDug)
	else
		points.ownerLabel.Text = "Parcela libre"
		points.depthLabel.Text = ""
	end
end

function PlotService.teleportToSurface(player: Player)
	local plot = plotByPlayer[player]
	local character = player.Character
	if not plot or not plot.points or not character then
		return
	end
	local target = plot.points.spawn
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 5)
	end)
	if character.Parent then
		character:PivotTo(target)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function findFreePlot(): (Plot?, boolean)
	local anyReleasing = false
	for _, candidate in plots do
		if not candidate.owner then
			if not candidate.releasing then
				return candidate, false
			end
			anyReleasing = true
		end
	end
	return nil, anyReleasing
end

local function claim(player: Player, profile: any)
	local plot, waitForRelease = findFreePlot()
	-- A plot whose previous owner just left frees up as soon as its terrain is cleared.
	local deadline = os.clock() + 15
	while not plot and waitForRelease and os.clock() < deadline and player.Parent do
		task.wait(0.5)
		plot, waitForRelease = findFreePlot()
	end
	if not player.Parent then
		return
	end
	if not plot then
		warn("[PlotService] no free plot for", player.Name)
		player:Kick("El servidor está lleno de parcelas. Prueba en otro servidor.")
		return
	end
	local p = plot :: Plot

	p.owner = player
	p.seed = profile.plot.seed
	p.dug = CellSet.decode(profile.plot.dug)
	p.damage = {}
	p.collaborators = {}
	p.ready = false
	p.generatedDepth = 0
	p.deepestDug = 0
	for key in p.dug do
		local _, d = Grid.fromKey(key)
		if d + 1 > p.deepestDug then
			p.deepestDug = d + 1
		end
	end
	plotByPlayer[player] = p
	PlotService.updateBoard(p)

	-- Rebuild the terrain from the seed and the saved excavation.
	TerrainChunkService.ensureDepth(
		p,
		math.max(GameConfig.InitialChunks * GameConfig.ChunkDepth, p.deepestDug + GameConfig.GenerateAheadCells),
		true,
		function()
			return plotByPlayer[player] == p
		end
	)

	if plotByPlayer[player] ~= p then
		return -- player left during generation
	end
	p.ready = true
	player:SetAttribute("PlotIndex", p.index)
	if p.folder then
		p.folder:SetAttribute("Owner", player.UserId)
	end

	for _, callback in readyCallbacks do
		task.spawn(callback, player, p)
	end
	PlotService.teleportToSurface(player)
end

local function release(player: Player)
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	plot.owner = nil
	plot.ready = false
	plot.releasing = true
	plot.dug = {}
	plot.damage = {}
	plot.deepestDug = 0
	if plot.folder then
		plot.folder:SetAttribute("Owner", nil)
	end
	PlotService.updateBoard(plot)
	for _, callback in releasedCallbacks do
		local ok, err = pcall(callback, plot)
		if not ok then
			warn("[PlotService] release callback failed:", err)
		end
	end
	TerrainChunkService.clear(plot)
	plot.releasing = false
end

function PlotService.start()
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = workspace

	local minX, maxX, minZ, maxZ = worldBounds()
	TerrainChunkService.applyMaterialColors()
	TerrainChunkService.fillSurfaceSlab(minX, maxX, minZ, maxZ)

	local _, firstZ = originFor(1)
	WorldBuilder.buildHub(worldFolder, Vector3.new(minX + 80, GameConfig.SurfaceY, firstZ + N * CELL / 2))

	for index = 1, GameConfig.MaxPlots do
		local originX, originZ = originFor(index)
		local plot: Plot = {
			index = index,
			originX = originX,
			originZ = originZ,
			owner = nil,
			seed = 0,
			dug = {},
			damage = {},
			generatedDepth = 0,
			deepestDug = 0,
			ready = false,
			releasing = false,
			collaborators = {},
		}
		local folder, points = WorldBuilder.buildPlot(worldFolder, index, originX, originZ)
		plot.folder = folder
		plot.points = points
		table.insert(plots, plot)
		PlotService.updateBoard(plot)
	end
	PlayerDataService.onLoaded(claim)
	PlayerDataService.beforeSave(function(player, profile)
		local plot = plotByPlayer[player]
		if plot and plot.ready then
			profile.plot.seed = plot.seed
			profile.plot.dug = CellSet.encode(plot.dug)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Let PlayerDataService capture the excavation first (it runs on the same event).
		task.defer(release, player)
	end)

	local function watchCharacters(player: Player)
		player.CharacterAdded:Connect(function()
			local plot = plotByPlayer[player]
			if plot and plot.ready then
				task.defer(PlotService.teleportToSurface, player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchCharacters)
	for _, player in Players:GetPlayers() do
		watchCharacters(player)
	end
end

return PlotService
