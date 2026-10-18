--!strict
-- Special equipment (Config/Gear). The server owns every rule: ownership, battery, cooldowns and,
-- for the hook, that the target is rock in reach with nothing in between. The client only asks
-- and plays the feedback (and moves its own character for the hook, as it moves it anyway).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = require(ReplicatedStorage.Shared.Config.Gear)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local Resonance = require(script.Parent.Parent.Logic.Resonance)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local EnergyService = require(script.Parent.EnergyService)
local SpecialsService = require(script.Parent.SpecialsService)
local AnomalyService = require(script.Parent.AnomalyService)

local GearService = {}

local lampOn: { [Player]: boolean } = {}
local lastPulse: { [Player]: number } = {}
local lastHook: { [Player]: number } = {}

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function owns(player: Player, id: string): boolean
	local profile = PlayerDataService.get(player)
	return profile ~= nil and profile.gear[id] == true
end

local function head(player: Player): BasePart?
	local character = player.Character
	return character and (character:FindFirstChild("Head") :: BasePart?)
end

-- Lamp -------------------------------------------------------------------------------------------

local function setLamp(player: Player, on: boolean)
	local h = head(player)
	local existing = h and h:FindFirstChild("THNE_GearLamp")
	if on and h then
		if not existing then
			local light = Instance.new("PointLight")
			light.Name = "THNE_GearLamp"
			light.Range = Gear.Lamp.range
			light.Brightness = Gear.Lamp.brightness
			light.Color = Color3.fromRGB(255, 244, 222)
			light.Shadows = true
			light.Parent = h -- on the server: other players see the cave light up too
		end
		lampOn[player] = true
	else
		if existing then
			existing:Destroy()
		end
		lampOn[player] = nil
	end
	player:SetAttribute("GearLamp", lampOn[player] == true)
end

-- Detector ---------------------------------------------------------------------------------------

local KIND_NAMES = {
	geode = "una geoda",
	chest = "un cofre",
	fossil = "un fósil",
	counter = "algo que no es roca",
}

local function pulse(player: Player): any
	if not owns(player, "detector") then
		return { ok = false, message = "No tienes el detector." }
	end
	local now = os.clock()
	if lastPulse[player] and now - lastPulse[player] < Gear.Detector.cooldown then
		return { ok = false, message = "El detector se está recargando." }
	end
	local h = head(player)
	local plot = PlotService.get(player)
	if not h or not plot then
		return { ok = false, message = "" }
	end
	if not EnergyService.consume(player, Gear.Detector.pulseCost) then
		return { ok = false, message = "Batería insuficiente: recárgala arriba o junto a una estación." }
	end
	lastPulse[player] = now
	local targets = SpecialsService.resonanceTargets(plot)
	local counter = AnomalyService.counterOf(plot)
	if counter and not counter.revealed then
		table.insert(targets, { kind = "counter", position = counter.room.center })
	end
	local reading = Resonance.read(targets, h.Position, Gear.Detector.range)
	if not reading then
		return { ok = true, found = false, message = "Silencio: nada a menos de 30 m." }
	end
	return {
		ok = true,
		found = true,
		kind = reading.kind,
		band = reading.band,
		direction = reading.direction,
		message = string.format("Resonancia: %s, %s.", KIND_NAMES[reading.kind] or "algo", reading.band),
	}
end

-- Hook -------------------------------------------------------------------------------------------

-- The client sends the point it aims at; the hook only fires if a straight line from the head
-- reaches rock within range close to that point, inside the player's own plot.
local function hook(player: Player, target: any): any
	if not owns(player, "hook") then
		return { ok = false, message = "No tienes el gancho." }
	end
	if typeof(target) ~= "Vector3" or target.X ~= target.X or target.Y ~= target.Y or target.Z ~= target.Z then
		return { ok = false, message = "" }
	end
	local now = os.clock()
	if lastHook[player] and now - lastHook[player] < Gear.Hook.cooldown then
		return { ok = false, message = "" }
	end
	local h = head(player)
	local plot = PlotService.get(player)
	if not h or not plot or PlotService.plotAt(target) ~= plot then
		return { ok = false, message = "Solo dentro de tu agujero." }
	end
	local toTarget = target - h.Position
	if toTarget.Magnitude > Gear.Hook.range + 2 or toTarget.Magnitude < 4 then
		return { ok = false, message = "Demasiado lejos para el gancho." }
	end
	local hit = workspace:Raycast(h.Position, toTarget.Unit * (Gear.Hook.range + 2), terrainOnly)
	if not hit or (hit.Position - target).Magnitude > 4 then
		return { ok = false, message = "El gancho no encuentra roca ahí." }
	end
	lastHook[player] = now
	return { ok = true, point = hit.Position, normal = hit.Normal }
end

function GearService.start()
	local limiter = RateLimiter.new(4, 6)
	Remotes.event("GearLamp").OnServerEvent:Connect(function(player, on)
		if not limiter:allow(player) or type(on) ~= "boolean" then
			return
		end
		if on and not owns(player, "lamp") then
			return
		end
		if on and EnergyService.get(player) <= 0 then
			StateService.notify(
				player,
				"info",
				"Batería vacía: recárgala arriba o junto a una estación.",
				"lamp_empty",
				3
			)
			return
		end
		setLamp(player, on)
	end)
	Remotes.func("GearPulse").OnServerInvoke = function(player: Player)
		if not limiter:allow(player) then
			return { ok = false, message = "" }
		end
		return pulse(player)
	end
	Remotes.func("GearHook").OnServerInvoke = function(player: Player, target: any)
		if not limiter:allow(player) then
			return { ok = false, message = "" }
		end
		return hook(player, target)
	end

	-- the lamp drains the battery while on, and goes out when it is empty
	task.spawn(function()
		local dt = 0.25
		while true do
			task.wait(dt)
			for player in lampOn do
				if not player.Parent then
					lampOn[player] = nil
				elseif not EnergyService.consume(player, Gear.Lamp.drainPerSecond * dt) then
					setLamp(player, false)
					StateService.notify(player, "info", "La linterna se ha quedado sin batería.", "lamp_empty", 3)
				elseif not head(player) or not (head(player) :: BasePart):FindFirstChild("THNE_GearLamp") then
					setLamp(player, true) -- respawned: the light goes back on the new head
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lampOn[player] = nil
		lastPulse[player] = nil
		lastHook[player] = nil
		limiter:forget(player)
	end)
end

return GearService
