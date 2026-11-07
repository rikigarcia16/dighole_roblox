--!strict
-- Mobility v1: ropes, lift stations and the rescue beacon (balance in Config/Mobility, pure rules
-- in Util/MobilityRules). Everything is validated here; the client only asks.
--
--   Rope     : hangs in front of the player through open space down to a floor (never dangling),
--              climbable both ways, picked up again from the top only, saved per plot.
--   Stations : installed where the player stands once they reach a zone; saved in the profile and
--              rebuilt on join. The lift travels between the surface winch and owned stations.
--   Beacon   : below the free-return depth, a channelled rescue to the nearest station above (or the
--              surface). Shows its cost first; never takes items; cancelled by moving or digging.
--   Death    : respawn at the nearest station above where the player died.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Mobility = require(ReplicatedStorage.Shared.Config.Mobility)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local MobilityRules = require(ReplicatedStorage.Shared.Util.MobilityRules)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local Inventory = require(script.Parent.Parent.Logic.Inventory)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local CaveProps = require(script.Parent.CaveProps)
local AnomalyService = require(script.Parent.AnomalyService)
local EnergyService = require(script.Parent.EnergyService)
local TelemetryService = require(script.Parent.TelemetryService)
local Gear = require(ReplicatedStorage.Shared.Config.Gear)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local Feats = require(ReplicatedStorage.Shared.Config.Feats)

local MobilityService = {}

local CELL = GameConfig.CellSize
local part = CaveProps.part

type PlotObjects = { folder: Folder, stations: { [string]: Model }, ropes: { Model } }
local objects: { [any]: PlotObjects } = {}

type Rescue = { started: number, position: Vector3, token: number }
local rescues: { [Player]: Rescue } = {}
local rescueToken = 0
local deathDepth: { [Player]: number } = {}

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- Helpers ---------------------------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function depthOf(position: Vector3): number
	return Grid.depthMetersFromY(position.Y - 3)
end

local function objectsFor(plot: any): PlotObjects?
	local existing = objects[plot]
	if existing then
		return existing
	end
	if not plot.folder then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Mobility"
	folder.Parent = plot.folder
	local created: PlotObjects = { folder = folder, stations = {}, ropes = {} }
	objects[plot] = created
	return created
end

local function stationFloor(plot: any, station: MobilityRules.Station): CFrame
	local center = Grid.cellCenter(plot.originX, plot.originZ, station.cx, station.d, station.cz)
	return CFrame.new(center.X, center.Y - CELL / 2, center.Z)
end

-- Where a lift ride, the beacon or a respawn leaves the player: the centre of the platform. Any
-- horizontal offset can land half inside a wall (the Counter's station sits against the room's
-- shell), and walking from there drops the character through the terrain.
local function stationArrival(plot: any, station: MobilityRules.Station): CFrame
	return stationFloor(plot, station) * CFrame.new(0, 4, 0)
end

-- Station model ---------------------------------------------------------------------------------
-- An industrial lift landing in the same 7x7 footprint as before (never more: it is built where the
-- player stands, often in a narrow gallery): steel grating with hazard edges, a yellow gantry with
-- braces and a turning pulley whose cable disappears into the rock, side railings, caged lamps,
-- a control panel with blinking lights and a lit sign in the colour of the zone.

local function buildStation(plot: any, station: MobilityRules.Station, parent: Instance): Model
	local def = Mobility.StationById[station.id]
	local floor = stationFloor(plot, station)
	local model = Instance.new("Model")
	model.Name = "Station_" .. station.id
	local accent = Zones.at(station.d).accent
	local yellow = Color3.fromRGB(255, 196, 40)
	local black = Color3.fromRGB(40, 40, 44)
	local steel = Color3.fromRGB(120, 128, 138)
	local iron = Color3.fromRGB(54, 58, 66)
	local function deco(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): BasePart
		local p = part(model, name, size, cf, color, material)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		return p
	end

	-- grating platform with hazard stripes on every edge
	part(model, "Platform", Vector3.new(7, 0.6, 7), floor * CFrame.new(0, 0.3, 0), steel, Enum.Material.DiamondPlate)
	for i = 0, 3 do
		local edge = floor * CFrame.Angles(0, i * math.pi / 2, 0)
		for k = 0, 4 do
			deco(
				"Hazard",
				Vector3.new(1.4, 0.12, 0.45),
				edge * CFrame.new(-2.8 + k * 1.4, 0.66, 3.25),
				if (k + i) % 2 == 0 then yellow else black,
				Enum.Material.SmoothPlastic
			)
		end
	end

	-- gantry at the back: two posts, braces, a beam and a pulley
	for _, side in { -1, 1 } do
		part(
			model,
			"Post",
			Vector3.new(0.7, 9.4, 0.7),
			floor * CFrame.new(side * 3, 4.7, -3),
			yellow,
			Enum.Material.Metal
		)
		local a = floor * CFrame.new(side * 3, 8.4, -3.4)
		local b = floor * CFrame.new(side * 1.6, 9.4, -3.4)
		deco(
			"Brace",
			Vector3.new(0.4, 0.4, (b.Position - a.Position).Magnitude),
			CFrame.lookAt((a.Position + b.Position) / 2, b.Position),
			yellow,
			Enum.Material.Metal
		)
		-- railing along each side, open at the front so the player steps on
		deco("Rail", Vector3.new(0.25, 0.25, 4.6), floor * CFrame.new(side * 3.3, 3, -0.6), yellow, Enum.Material.Metal)
		deco(
			"RailPost",
			Vector3.new(0.3, 2.7, 0.3),
			floor * CFrame.new(side * 3.3, 1.65, 1.6),
			yellow,
			Enum.Material.Metal
		)
		-- cable bundle down the post
		deco(
			"Cables",
			Vector3.new(0.2, 8.8, 0.2),
			floor * CFrame.new(side * 3.45, 4.7, -2.55),
			black,
			Enum.Material.Plastic
		)
		-- caged lamp on each post
		local lamp = deco(
			"Lantern",
			Vector3.new(0.7, 0.9, 0.7),
			floor * CFrame.new(side * 2.4, 7.4, -2.6),
			Color3.fromRGB(255, 210, 130),
			Enum.Material.Neon
		)
		CaveProps.light(lamp, Color3.fromRGB(255, 196, 110), 20, 1.2)
		if side > 0 then
			CollectionService:AddTag(lamp, "THNE_Flicker")
		end
		deco("LampCage", Vector3.new(0.9, 0.15, 0.9), lamp.CFrame * CFrame.new(0, 0.5, 0), iron, Enum.Material.Metal)
		deco("LampCage", Vector3.new(0.9, 0.15, 0.9), lamp.CFrame * CFrame.new(0, -0.5, 0), iron, Enum.Material.Metal)
	end
	part(model, "Beam", Vector3.new(7.2, 0.8, 0.8), floor * CFrame.new(0, 9.4, -3), iron, Enum.Material.Metal)
	local pulleyCf = floor * CFrame.new(0, 10.6, -3)
	for i, size in { 2.6, 1.6 } do
		local wheel = deco(
			"Pulley",
			Vector3.new(0.5 + i * 0.1, size, size),
			pulleyCf * CFrame.Angles(0, math.rad(90), 0),
			if i == 1 then Color3.fromRGB(226, 84, 60) else iron,
			Enum.Material.Metal
		)
		wheel.Shape = Enum.PartType.Cylinder
		wheel:SetAttribute("RotorSpeed", 0.8)
		CollectionService:AddTag(wheel, "THNE_Rotor")
	end
	local cable =
		deco("Cable", Vector3.new(0.15, 30, 0.15), floor * CFrame.new(0, 10.6 + 15, -1.8), black, Enum.Material.Metal)
	_ = cable

	-- control panel (the lift prompt) with two blinking lights
	local panel = part(
		model,
		"LiftPanel",
		Vector3.new(1.2, 2.6, 0.8),
		floor * CFrame.new(-2.2, 1.9, -2.6),
		yellow,
		Enum.Material.Metal
	)
	for i, color in { Color3.fromRGB(80, 255, 120), Color3.fromRGB(255, 70, 70) } do
		local light = deco(
			"PanelLamp",
			Vector3.new(0.35, 0.35, 0.35),
			panel.CFrame * CFrame.new(-0.25 + (i - 1) * 0.5, 0.8, 0.45),
			color,
			Enum.Material.Neon
		)
		light.Shape = Enum.PartType.Ball
		light:SetAttribute("PulsePeriod", 1.1 + i * 0.6)
		CollectionService:AddTag(light, "THNE_Pulse")
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Viajar"
	prompt.ObjectText = if def then def.name else "Estación"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Action", "Lift")
	prompt.Parent = panel

	-- lit sign: dark box, a glowing strip in the zone's colour, the name and depth
	local sign =
		part(model, "Sign", Vector3.new(5, 1.6, 0.4), floor * CFrame.new(0, 8, -3.3), iron, Enum.Material.Metal)
	sign.CanCollide = false
	deco("SignGlow", Vector3.new(5.2, 0.2, 0.5), floor * CFrame.new(0, 7.1, -3.3), accent, Enum.Material.Neon)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = string.format("%s · %d m", if def then def.name else station.id, station.d)
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.35)
	text.Parent = gui
	model.PrimaryPart = panel
	model:SetAttribute("StationId", station.id)
	model.Parent = parent
	return model
end

-- Rope model ------------------------------------------------------------------------------------

local function buildRope(top: Vector3, length: number, index: number, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Rope"
	local truss = Instance.new("TrussPart") -- humanoids climb trusses natively
	truss.Name = "Truss"
	truss.Anchored = true
	truss.Size = Vector3.new(2, length, 2)
	truss.CFrame = CFrame.new(top - Vector3.new(0, length / 2, 0))
	truss.Color = Color3.fromRGB(150, 116, 74)
	truss.Material = Enum.Material.Fabric
	truss.Transparency = 0.15
	truss.Parent = model
	part(
		model,
		"Anchor",
		Vector3.new(1.2, 0.6, 1.2),
		CFrame.new(top + Vector3.new(0, 0.3, 0)),
		Color3.fromRGB(90, 90, 96),
		Enum.Material.Metal
	)
	-- Picked up only from the top: you cannot strand yourself by taking the rope from below.
	for _, at in { top + Vector3.new(0, 1.5, 0) } do
		local handle = part(
			model,
			"RopeHandle",
			Vector3.new(1, 1, 1),
			CFrame.new(at),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic
		)
		handle.Transparency = 1
		handle.CanCollide = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Recoger"
		prompt.ObjectText = "Cuerda"
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Action", "RopeRetrieve")
		prompt.Parent = handle
	end
	model:SetAttribute("RopeIndex", index)
	model.Parent = parent
	return model
end

local function rebuildRopes(plot: any, profile: any)
	local objs = objectsFor(plot)
	if not objs then
		return
	end
	for _, rope in objs.ropes do
		rope:Destroy()
	end
	table.clear(objs.ropes)
	for i, rope in profile.mobility.placedRopes do
		local top = Vector3.new(
			plot.originX + rope.cx * CELL,
			GameConfig.SurfaceY - rope.d * CELL,
			plot.originZ + rope.cz * CELL
		)
		objs.ropes[i] = buildRope(top, rope.length, i, objs.folder)
	end
end

-- Stations --------------------------------------------------------------------------------------

local function addStation(player: Player, plot: any, station: MobilityRules.Station)
	local profile = PlayerDataService.get(player)
	local objs = objectsFor(plot)
	if not profile or not objs or objs.stations[station.id] then
		return
	end
	table.insert(profile.mobility.stations, station)
	objs.stations[station.id] = buildStation(plot, station, objs.folder)
	StateService.push(player)
end

local function installStation(player: Player)
	local profile = PlayerDataService.get(player)
	local plot = PlotService.get(player)
	local root = rootOf(player)
	if not profile or not plot or not root then
		return
	end
	local depth = depthOf(root.Position)
	local def, reason = MobilityRules.installable(depth, profile.mobility.stations)
	if not def then
		StateService.notify(player, "info", reason or "No se puede instalar aquí.", "station_no", 3)
		return
	end
	local cx, d, cz = Grid.worldToCell(plot.originX, plot.originZ, root.Position - Vector3.new(0, 2.5, 0))
	if not Grid.inDigArea(cx, d, cz) then
		StateService.notify(player, "info", "Instálala dentro de tu agujero.", "station_no", 3)
		return
	end
	if not MobilityRules.farEnough(cx, d, cz, profile.mobility.stations) then
		StateService.notify(player, "info", "Demasiado cerca de otra estación.", "station_no", 3)
		return
	end
	if profile.coins < def.cost then
		StateService.notify(
			player,
			"error",
			"Te faltan " .. Format.number(def.cost - profile.coins) .. " monedas.",
			"station_no",
			3
		)
		return
	end
	profile.coins -= def.cost
	addStation(player, plot, { id = def.id, cx = cx, d = d, cz = cz })
	StateService.notify(player, "success", def.name .. " instalada: el montacargas ya puede bajar hasta aquí.")
end

-- Lift --------------------------------------------------------------------------------------------

local function nearLift(player: Player, plot: any): boolean
	local root = rootOf(player)
	local objs = objects[plot]
	if not root then
		return false
	end
	if plot.points and (plot.points.lift - root.Position).Magnitude <= Mobility.StationUseDistance + 4 then
		return true
	end
	if objs then
		for _, model in objs.stations do
			if (model:GetPivot().Position - root.Position).Magnitude <= Mobility.StationUseDistance then
				return true
			end
		end
	end
	return false
end

local function travel(player: Player, destination: string): (boolean, string)
	local profile = PlayerDataService.get(player)
	local plot = PlotService.get(player)
	if not profile or not plot then
		return false, "No disponible."
	end
	if rescues[player] then
		return false, "Estás usando la baliza."
	end
	if not nearLift(player, plot) then
		return false, "Acércate a un montacargas."
	end
	local target: CFrame? = nil
	if destination == "surface" then
		target = plot.points and plot.points.spawn
	else
		for _, station in profile.mobility.stations do
			if station.id == destination then
				target = stationArrival(plot, station)
			end
		end
	end
	if not target then
		return false, "Esa estación no existe."
	end
	Remotes.event("LiftRide"):FireClient(player, Mobility.LiftRideSeconds)
	local destinationCFrame = target :: CFrame
	task.delay(Mobility.LiftRideSeconds * 0.5, function()
		if player.Parent then
			PlotService.teleportTo(player, destinationCFrame)
		end
	end)
	return true, "En marcha..."
end

-- Ropes -----------------------------------------------------------------------------------------

local function placeRope(player: Player)
	local profile = PlayerDataService.get(player)
	local plot = PlotService.get(player)
	local root = rootOf(player)
	if not profile or not plot or not root then
		return
	end
	if profile.mobility.ropes <= 0 then
		StateService.notify(player, "info", "No te quedan cuerdas. Cómpralas en el garaje.", "rope_none", 3)
		return
	end
	if #profile.mobility.placedRopes >= Mobility.Rope.maxPlaced then
		StateService.notify(player, "info", "Ya hay demasiadas cuerdas colocadas. Recoge alguna.", "rope_max", 3)
		return
	end
	local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 then
		return
	end
	local feet = root.Position - Vector3.new(0, 2.5, 0)
	local function tryAt(forward: number): (Vector3?, number, string?)
		local top = feet + flat.Unit * forward + Vector3.new(0, 1, 0)
		-- the rope must hang inside the player's own hole...
		local cx, d, cz = Grid.worldToCell(plot.originX, plot.originZ, top - Vector3.new(0, 2, 0))
		if not Grid.inDigArea(cx, math.max(d, 0), cz) then
			return nil, 0, "La cuerda tiene que colgar dentro de tu agujero."
		end
		-- ...from open space (nothing between the player and the anchor)...
		if workspace:Raycast(root.Position, top - root.Position, terrainOnly) then
			return nil, 0, "No hay espacio para colgar la cuerda ahí."
		end
		-- ...down to a floor within reach: never a rope that leaves you hanging.
		local hit = workspace:Raycast(top, Vector3.new(0, -Mobility.Rope.maxLength, 0), terrainOnly)
		if not hit then
			return nil, 0, "No llega al fondo: la cuerda mide 20 m."
		end
		local length = top.Y - hit.Position.Y
		if length < Mobility.Rope.minDrop then
			return nil, 0, "Aquí no hace falta cuerda."
		end
		return top, length, nil
	end
	-- Smooth terrain rounds the rim of a hole into a slope a few studs wide, so a player standing at
	-- the edge often has the slope 4 studs ahead (Studio test 2): look a little further before
	-- giving up. The first attempt's message is the one shown.
	local top, length, reason = tryAt(Mobility.Rope.reachForward)
	for _, extra in { 1.5, 3, 4.5 } do
		if top then
			break
		end
		local laterTop, laterLength = tryAt(Mobility.Rope.reachForward + extra)
		if laterTop then
			top, length = laterTop, laterLength
		end
	end
	if not top then
		StateService.notify(player, "info", reason or "No se puede colgar aquí.", "rope_bad", 3)
		return
	end
	profile.mobility.ropes -= 1
	table.insert(profile.mobility.placedRopes, {
		cx = (top.X - plot.originX) / CELL,
		d = (GameConfig.SurfaceY - top.Y) / CELL,
		cz = (top.Z - plot.originZ) / CELL,
		length = length,
	})
	rebuildRopes(plot, profile)
	StateService.notify(
		player,
		"success",
		string.format("Cuerda colocada (%d m). Te quedan %d.", math.floor(length / 4), profile.mobility.ropes)
	)
	StateService.push(player)
end

local function retrieveRope(player: Player, prompt: ProximityPrompt)
	local plot = PlotService.get(player)
	local profile = PlayerDataService.get(player)
	local objs = plot and objects[plot]
	if not plot or not profile or not objs then
		return
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	local index = model and model:GetAttribute("RopeIndex")
	if not model or type(index) ~= "number" or not model:IsDescendantOf(objs.folder) then
		return -- only ropes in your own plot
	end
	if profile.mobility.ropes >= Feats.ropeCapacity(Mobility.Rope.maxCarried, profile.feats) then
		StateService.notify(player, "info", "Ya llevas el máximo de cuerdas.", "rope_full", 3)
		return
	end
	table.remove(profile.mobility.placedRopes, index)
	profile.mobility.ropes += 1
	rebuildRopes(plot, profile)
	StateService.push(player)
end

-- Rescue beacon ---------------------------------------------------------------------------------

local function quoteFor(player: Player): MobilityRules.Quote?
	local profile = PlayerDataService.get(player)
	local root = rootOf(player)
	if not profile or not root then
		return nil
	end
	return MobilityRules.quote(
		depthOf(root.Position),
		Inventory.value(profile.inventory),
		profile.coins,
		profile.mobility.stations,
		Feats.rescueCostFactor(profile.feats)
	)
end

local function destinationCFrame(player: Player, destination: string): CFrame?
	local plot = PlotService.get(player)
	local profile = PlayerDataService.get(player)
	if not plot or not profile then
		return nil
	end
	if destination ~= "surface" then
		for _, station in profile.mobility.stations do
			if station.id == destination then
				return stationArrival(plot, station)
			end
		end
	end
	return plot.points and plot.points.spawn
end

function MobilityService.interrupt(player: Player, reason: string?)
	if rescues[player] then
		rescues[player] = nil
		Remotes.event("RescueState"):FireClient(player, "cancelled", reason or "")
	end
end

local function startRescue(player: Player)
	local quote = quoteFor(player)
	local root = rootOf(player)
	if not quote or not root or rescues[player] then
		return
	end
	rescueToken += 1
	local token = rescueToken
	rescues[player] = { started = os.clock(), position = root.Position, token = token }
	Remotes.event("RescueState"):FireClient(player, "channel", Mobility.Rescue.channelSeconds)
	task.delay(Mobility.Rescue.channelSeconds, function()
		local rescue = rescues[player]
		if not rescue or rescue.token ~= token or not player.Parent then
			return
		end
		rescues[player] = nil
		local nowRoot = rootOf(player)
		if not nowRoot or (nowRoot.Position - rescue.position).Magnitude > Mobility.Rescue.cancelDistance then
			Remotes.event("RescueState"):FireClient(player, "cancelled", "Te has movido.")
			return
		end
		-- recompute at the moment of paying (coins may have changed); never take items
		local final = quoteFor(player)
		local profile = PlayerDataService.get(player)
		if not final or not profile then
			return
		end
		profile.coins -= final.pay
		profile.mobility.rescues += 1
		TelemetryService.event(player, "Rescate", final.pay, "Tipo - baliza")
		local target = destinationCFrame(player, final.destination)
		if target then
			Remotes.event("LiftRide"):FireClient(player, 1.6)
			task.delay(0.8, function()
				if player.Parent then
					PlotService.teleportTo(player, target)
				end
			end)
		end
		Remotes.event("RescueState"):FireClient(player, "done", "")
		StateService.notify(
			player,
			"info",
			if final.pay > 0
				then string.format("Rescatado hasta %s (-%s monedas).", final.destinationName, Format.number(final.pay))
				else "Rescatado hasta " .. final.destinationName .. "."
		)
		StateService.push(player)
	end)
end

-- Lifecycle ---------------------------------------------------------------------------------------

function MobilityService.start()
	PlotService.onReady(function(player, plot)
		local profile = PlayerDataService.get(player)
		local objs = objectsFor(plot)
		if not profile or not objs then
			return
		end
		for _, station in profile.mobility.stations do
			if not objs.stations[station.id] then
				objs.stations[station.id] = buildStation(plot, station, objs.folder)
			end
		end
		rebuildRopes(plot, profile)
	end)
	PlotService.onReleased(function(plot)
		local objs = objects[plot]
		if objs then
			objs.folder:Destroy()
			objects[plot] = nil
		end
	end)

	-- The battery recharges next to any of your stations (EnergyService).
	EnergyService.addRechargeSource(function(player: Player): boolean
		local plot = PlotService.get(player)
		local root = rootOf(player)
		local objs = plot and objects[plot]
		if not root or not objs then
			return false
		end
		for _, model in objs.stations do
			if (model:GetPivot().Position - root.Position).Magnitude <= Gear.StationRechargeDistance then
				return true
			end
		end
		return false
	end)

	-- The Counter gives its own station once solved.
	AnomalyService.setStationGranter(function(player: Player, id: string, spot: CFrame)
		local plot = PlotService.get(player)
		local profile = PlayerDataService.get(player)
		if not plot or not profile then
			return
		end
		for _, s in profile.mobility.stations do
			if s.id == id then
				return
			end
		end
		local cx, d, cz = Grid.worldToCell(plot.originX, plot.originZ, spot.Position + Vector3.new(0, 1, 0))
		addStation(player, plot, { id = id, cx = cx, d = d, cz = cz })
		StateService.notify(player, "success", "Un montacargas ha encontrado el camino hasta esta sala.")
	end)

	-- Respawn at the nearest station above the place of death.
	PlotService.setRespawnResolver(function(player: Player): CFrame?
		local depth = deathDepth[player]
		deathDepth[player] = nil
		local profile = PlayerDataService.get(player)
		if not depth or not profile then
			return nil
		end
		local station = MobilityRules.nearestStationAbove(profile.mobility.stations, depth)
		return if station then destinationCFrame(player, station.id) else nil
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						deathDepth[player] = depthOf(root.Position)
					end
					MobilityService.interrupt(player, "")
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		rescues[player] = nil
		deathDepth[player] = nil
	end)

	local limiter = RateLimiter.new(2, 4)
	Remotes.event("PlaceRope").OnServerEvent:Connect(function(player)
		if limiter:allow(player) then
			placeRope(player)
		end
	end)
	Remotes.event("InstallStation").OnServerEvent:Connect(function(player)
		if limiter:allow(player) then
			installStation(player)
		end
	end)
	Remotes.event("RescueStart").OnServerEvent:Connect(function(player)
		if limiter:allow(player) then
			startRescue(player)
		end
	end)
	Remotes.event("RescueCancel").OnServerEvent:Connect(function(player)
		MobilityService.interrupt(player, "Cancelado.")
	end)
	Remotes.func("RescueQuote").OnServerInvoke = function(player: Player)
		if not limiter:allow(player) then
			return nil
		end
		return quoteFor(player)
	end
	Remotes.func("LiftTravel").OnServerInvoke = function(player: Player, destination: any)
		if not limiter:allow(player) or type(destination) ~= "string" or #destination > 24 then
			return { ok = false, message = "Petición no válida." }
		end
		local ok, message = travel(player, destination)
		return { ok = ok, message = message }
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("Action") == "RopeRetrieve" then
			retrieveRope(player, prompt)
		end
	end)

	StateService.addSnapshotProvider(function(_player, profile, snapshot)
		snapshot.mobility = profile.mobility
	end)
end

return MobilityService
