--!strict
-- Server-authoritative excavation.
--
-- The client only says "I hit this point" (position + surface normal). The server decides
-- everything else: which cell is hit, whether the player may dig there, tool cooldown, reach,
-- line of sight, energy, damage per cell, what breaks, what is collected and how the terrain
-- changes. Terrain writes replicate to every client automatically, so all players see the same
-- hole and collide with the same geometry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local OreGeneration = require(script.Parent.Parent.Logic.OreGeneration)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local TerrainChunkService = require(script.Parent.TerrainChunkService)
local InventoryService = require(script.Parent.InventoryService)
local EquipmentService = require(script.Parent.EquipmentService)
local EnergyService = require(script.Parent.EnergyService)
local StateService = require(script.Parent.StateService)
local SpecialsService = require(script.Parent.SpecialsService)
local FxService = require(script.Parent.FxService)

local DiggingService = {}

local CELL = GameConfig.CellSize
local PROBE_DEPTHS = { 0.5, 2, 3.5 }

local lastHit: { [Player]: number } = {}
local zoneEvent = Remotes.event("ZoneEntered")

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) < 1e6
		and math.abs(v.Y) < 1e6
		and math.abs(v.Z) < 1e6
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Include
losParams.FilterDescendantsInstances = { workspace.Terrain }

type Hit = { cx: number, d: number, cz: number, key: number, resource: Resources.Resource }

local function rarityOrder(resource: Resources.Resource): number
	return Resources.Rarities[resource.rarity].order
end

local function handleDig(player: Player, position: any, normal: any)
	if typeof(position) ~= "Vector3" or typeof(normal) ~= "Vector3" then
		return
	end
	if not isFiniteVector(position) or not isFiniteVector(normal) then
		return
	end
	local unitNormal = if normal.Magnitude > 1e-3 then normal.Unit else Vector3.zero

	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local tool = Tools.get(profile.equippedTool)
	if not tool or EquipmentService.heldToolId(player) ~= tool.id then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	local now = os.clock()
	if now - (lastHit[player] or 0) < tool.cooldown * GameConfig.CooldownTolerance then
		return
	end
	if (root.Position - position).Magnitude > tool.reach + GameConfig.DigReachPadding then
		return
	end

	local plot = PlotService.plotAt(position)
	if not plot then
		return
	end
	if not PlotService.canDig(player, plot) then
		StateService.notify(
			player,
			"error",
			"Esta parcela no es tuya: pide permiso a su dueño para cavar.",
			"foreign_plot",
			4
		)
		return
	end

	-- Resolve the target cell: the first solid, diggable cell just behind the hit surface.
	local tx, td, tz
	for _, depthIn in PROBE_DEPTHS do
		local cx, d, cz = Grid.worldToCell(plot.originX, plot.originZ, position - unitNormal * depthIn)
		if
			Grid.inDigArea(cx, d, cz)
			and not plot.dug[Grid.key(cx, d, cz)]
			and OreGeneration.resourceAt(plot.seed, cx, d, cz) ~= "air"
		then
			tx, td, tz = cx, d, cz
			break
		end
	end
	if not tx then
		return
	end

	-- Line of sight: nothing solid may sit between the player's head and the target cell.
	local head = character:FindFirstChild("Head") :: BasePart?
	local eye = if head then head.Position else root.Position
	local targetCenter = Grid.cellCenter(plot.originX, plot.originZ, tx, td, tz)
	local toTarget = targetCenter - eye
	if toTarget.Magnitude > 1 then
		local result = workspace:Raycast(eye, toTarget, losParams)
		if result and (result.Position - targetCenter).Magnitude > CELL * 1.5 then
			return
		end
	end

	-- Collect affected cells.
	local hits: { Hit } = {}
	local blockedBy: Resources.Resource? = nil
	for _, offset in Grid.sphereOffsets(tool.radius) do
		local cx, d, cz = tx + offset[1], td - offset[2], tz + offset[3]
		if Grid.inDigArea(cx, d, cz) then
			local key = Grid.key(cx, d, cz)
			if not plot.dug[key] then
				local resource = Resources.get(OreGeneration.resourceAt(plot.seed, cx, d, cz))
				if resource then
					if tool.power >= resource.requiredPower then
						table.insert(hits, { cx = cx, d = d, cz = cz, key = key, resource = resource })
					elseif offset[4] == 0 then
						blockedBy = resource
					end
				end
			end
		end
	end

	if #hits == 0 then
		if blockedBy then
			StateService.notify(
				player,
				"error",
				string.format(
					"%s es demasiado dura: necesitas potencia %d (tienes %d).",
					blockedBy.name,
					blockedBy.requiredPower,
					tool.power
				),
				"too_hard",
				3
			)
			FxService.broadcast(player, targetCenter, blockedBy.id, false, tool.id, nil)
		end
		return
	end

	if not EnergyService.consume(player, tool.energyCost) then
		StateService.notify(
			player,
			"error",
			"¡Sin energía! Vuelve a la superficie para recargar la batería.",
			"no_energy",
			3
		)
		return
	end
	lastHit[player] = now

	-- Apply damage.
	local broken: { Hit } = {}
	local minX, maxX, minD, maxD, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, hit in hits do
		local damage = (plot.damage[hit.key] or 0) + tool.power
		if damage >= hit.resource.hardness then
			plot.damage[hit.key] = nil
			plot.dug[hit.key] = true
			table.insert(broken, hit)
		else
			plot.damage[hit.key] = damage
		end
		minX, maxX = math.min(minX, hit.cx), math.max(maxX, hit.cx)
		minD, maxD = math.min(minD, hit.d), math.max(maxD, hit.d)
		minZ, maxZ = math.min(minZ, hit.cz), math.max(maxZ, hit.cz)
	end
	TerrainChunkService.writeBox(plot, minX, maxX, minD, maxD, minZ, maxZ)

	-- Rewards and progression.
	local best: Resources.Resource? = nil
	if #broken > 0 then
		local counts: { [string]: number } = {}
		local deepest = -1
		for _, hit in broken do
			counts[hit.resource.id] = (counts[hit.resource.id] or 0) + 1
			deepest = math.max(deepest, hit.d)
			if not best or rarityOrder(hit.resource) > rarityOrder(best) then
				best = hit.resource
			end
		end
		local lost = 0
		for id, count in counts do
			lost += count - InventoryService.collect(player, id, count)
		end

		-- Hidden finds inside base rock (weightless: they always fit in the backpack).
		for _, hit in broken do
			if not hit.resource.isOre then
				local findId = OreGeneration.findAt(plot.seed, hit.cx, hit.d, hit.cz)
				local find = findId and Resources.get(findId)
				if find then
					InventoryService.collect(player, find.id, 1, true)
					profile.stats.findsFound += 1
					StateService.notify(player, "find", "¡Hallazgo! " .. find.name)
					if not best or rarityOrder(find) > rarityOrder(best) then
						best = find
					end
				end
			end
		end
		if lost > 0 then
			StateService.notify(
				player,
				"warning",
				"¡Mochila llena! Vuelve a la superficie y vende tus minerales.",
				"backpack_full",
				4
			)
		end

		profile.stats.cellsDug += #broken
		local depthMeters = deepest + 1
		if depthMeters > plot.deepestDug then
			plot.deepestDug = depthMeters
			TerrainChunkService.onDugTo(plot, deepest)
			PlotService.updateBoard(plot)
		end
		if depthMeters > profile.stats.maxDepth then
			profile.stats.maxDepth = depthMeters
		end
		local zone = Zones.at(deepest)
		if not profile.zonesReached[zone.id] then
			profile.zonesReached[zone.id] = true
			zoneEvent:FireClient(player, zone.id, true)
		end
		SpecialsService.onCellsBroken(player, plot, broken)
		StateService.push(player)
	end

	local targetResource = hits[1].resource
	FxService.broadcast(
		player,
		targetCenter,
		targetResource.id,
		#broken > 0,
		tool.id,
		if best and Resources.isRareOrBetter(best) then best.id else nil
	)
end

function DiggingService.start()
	local limits = GameConfig.RateLimits.Dig
	local limiter = RateLimiter.new(limits.rate, limits.burst)
	Remotes.event("Dig").OnServerEvent:Connect(function(player, position, normal)
		if limiter:allow(player) then
			handleDig(player, position, normal)
		end
	end)

	local surfaceLimiter =
		RateLimiter.new(GameConfig.RateLimits.ReturnToSurface.rate, GameConfig.RateLimits.ReturnToSurface.burst)
	local lastReturn: { [Player]: number } = {}
	Remotes.event("ReturnToSurface").OnServerEvent:Connect(function(player)
		if not surfaceLimiter:allow(player) then
			return
		end
		local now = os.clock()
		if lastReturn[player] and now - lastReturn[player] < GameConfig.ReturnToSurfaceCooldown then
			StateService.notify(player, "info", "Espera un momento antes de volver a subir.", "return_cd", 2)
			return
		end
		lastReturn[player] = now
		PlotService.teleportToSurface(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		lastReturn[player] = nil
		limiter:forget(player)
		surfaceLimiter:forget(player)
	end)
end

return DiggingService
