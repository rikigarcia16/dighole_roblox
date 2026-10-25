--!strict
-- Tool, upgrade and rope purchases. Every request is validated on the server: ownership, price,
-- remaining levels and distance to a shop counter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Mobility = require(ReplicatedStorage.Shared.Config.Mobility)
local Gear = require(ReplicatedStorage.Shared.Config.Gear)
local Feats = require(ReplicatedStorage.Shared.Config.Feats)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local EquipmentService = require(script.Parent.EquipmentService)
local EnergyService = require(script.Parent.EnergyService)

local ShopService = {}

type Result = { ok: boolean, message: string }

local function nearShop(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, plot in PlotService.all() do
		local points = plot.points
		if points and (points.shop - root.Position).Magnitude <= GameConfig.ShopDistance then
			return true
		end
	end
	return false
end

local function buyTool(player: Player, profile: any, toolId: string): Result
	local tool = Tools.get(toolId)
	if not tool or not tool.purchasable then
		return { ok = false, message = "Esta herramienta no está a la venta." }
	end
	if profile.tools[toolId] then
		return { ok = false, message = "Ya tienes esta herramienta." }
	end
	if not nearShop(player) then
		return { ok = false, message = "Vuelve al garaje para comprar." }
	end
	if profile.coins < tool.price then
		return { ok = false, message = "Te faltan " .. Format.number(tool.price - profile.coins) .. " monedas." }
	end
	profile.coins -= tool.price
	profile.tools[toolId] = true
	profile.equippedTool = toolId
	EquipmentService.equip(player)
	StateService.push(player)
	return { ok = true, message = "¡" .. tool.name .. " comprada y equipada!" }
end

local function equipTool(player: Player, profile: any, toolId: string): Result
	if not Tools.get(toolId) or not profile.tools[toolId] then
		return { ok = false, message = "No tienes esta herramienta." }
	end
	profile.equippedTool = toolId
	EquipmentService.equip(player)
	StateService.push(player)
	return { ok = true, message = "Herramienta equipada." }
end

local function buyUpgrade(player: Player, profile: any, trackId: string): Result
	local track = Upgrades.ById[trackId]
	if not track or track.hidden then
		return { ok = false, message = "Mejora no disponible." }
	end
	local current = profile.upgrades[trackId] or 1
	local nextLevel = track.levels[current + 1]
	if not nextLevel then
		return { ok = false, message = "Ya está al máximo." }
	end
	if trackId == "battery" and not Gear.needsBattery(profile.gear) then
		return { ok = false, message = "Primero necesitas equipo que use batería (linterna o detector)." }
	end
	if not nearShop(player) then
		return { ok = false, message = "Vuelve al garaje para comprar." }
	end
	if profile.coins < nextLevel.price then
		return { ok = false, message = "Te faltan " .. Format.number(nextLevel.price - profile.coins) .. " monedas." }
	end
	profile.coins -= nextLevel.price
	profile.upgrades[trackId] = current + 1
	if trackId == "battery" then
		EnergyService.refresh(player)
	end
	StateService.push(player)
	return {
		ok = true,
		message = string.format("%s mejorada: %s %s", track.name, Format.number(nextLevel.value), track.unit),
	}
end

-- Ropes are consumables: carried in a small stack, placed and picked up again in the hole.
local function buyRope(player: Player, profile: any, _id: string): Result
	local rope = Mobility.Rope
	local maxCarried = Feats.ropeCapacity(rope.maxCarried, profile.feats)
	if profile.mobility.ropes >= maxCarried then
		return { ok = false, message = "Ya llevas " .. maxCarried .. " cuerdas." }
	end
	if not nearShop(player) then
		return { ok = false, message = "Vuelve al garaje para comprar." }
	end
	if profile.coins < rope.price then
		return { ok = false, message = "Te faltan " .. Format.number(rope.price - profile.coins) .. " monedas." }
	end
	profile.coins -= rope.price
	profile.mobility.ropes += 1
	StateService.push(player)
	return { ok = true, message = string.format("Cuerda comprada (%d/%d).", profile.mobility.ropes, maxCarried) }
end

local function buyGear(player: Player, profile: any, gearId: string): Result
	local def = Gear.ById[gearId]
	if not def then
		return { ok = false, message = "Equipo no disponible." }
	end
	if profile.gear[gearId] then
		return { ok = false, message = "Ya tienes " .. def.name .. "." }
	end
	local base = def.upgradeOf and Gear.ById[def.upgradeOf]
	if base and not profile.gear[base.id] then
		return { ok = false, message = "Primero necesitas: " .. base.name .. "." }
	end
	if not nearShop(player) then
		return { ok = false, message = "Vuelve al garaje para comprar." }
	end
	if profile.coins < def.price then
		return { ok = false, message = "Te faltan " .. Format.number(def.price - profile.coins) .. " monedas." }
	end
	profile.coins -= def.price
	profile.gear[gearId] = true
	StateService.push(player)
	return { ok = true, message = def.name .. " comprado. Tecla " .. def.key .. "." }
end

local actions: { [string]: (Player, any, string) -> Result } = {
	buyTool = buyTool,
	equipTool = equipTool,
	buyUpgrade = buyUpgrade,
	buyRope = buyRope,
	buyGear = buyGear,
}

function ShopService.start()
	local limiter = RateLimiter.new(GameConfig.RateLimits.Shop.rate, GameConfig.RateLimits.Shop.burst)
	Remotes.func("Shop").OnServerInvoke = function(player: Player, action: any, id: any): Result
		if not limiter:allow(player) then
			return { ok = false, message = "Demasiado rápido." }
		end
		if type(action) ~= "string" or type(id) ~= "string" or #id > 64 then
			return { ok = false, message = "Petición no válida." }
		end
		local handler = actions[action]
		local profile = PlayerDataService.get(player)
		if not handler or not profile then
			return { ok = false, message = "Petición no válida." }
		end
		return handler(player, profile, id)
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return ShopService
