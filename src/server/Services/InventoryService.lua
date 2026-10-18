--!strict
-- Backpack, discoveries and selling. Coins only ever change on the server.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local Inventory = require(script.Parent.Parent.Logic.Inventory)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

local InventoryService = {}

-- First time a resource is found the player gets a small bonus: discovery is a reward in itself.

local collectedEvent = Remotes.event("Collected")

function InventoryService.capacity(player: Player): number
	local profile = PlayerDataService.get(player)
	return Upgrades.valueAt("backpack", profile and profile.upgrades.backpack or 1)
end

function InventoryService.isFull(player: Player): boolean
	local profile = PlayerDataService.get(player)
	if not profile then
		return true
	end
	return Inventory.used(profile.inventory) >= InventoryService.capacity(player)
end

-- Adds resources to the backpack. Returns the amount that fit. Rewards (chests) pass
-- `ignoreCapacity` so a reward is never lost to a full backpack.
function InventoryService.collect(player: Player, resourceId: string, amount: number, ignoreCapacity: boolean?): number
	local profile = PlayerDataService.get(player)
	local resource = Resources.get(resourceId)
	if not profile or not resource then
		return 0
	end
	local capacity = if ignoreCapacity then math.huge else InventoryService.capacity(player)
	local added = Inventory.add(profile.inventory, resourceId, amount, capacity)
	if added <= 0 then
		return 0
	end
	local isNew = (profile.discoveries[resourceId] or 0) == 0
	profile.discoveries[resourceId] = (profile.discoveries[resourceId] or 0) + added
	local bonus = Inventory.discoveryBonus(resource, isNew)
	if bonus > 0 then
		profile.coins += bonus
		profile.stats.coinsEarned += bonus
		StateService.notify(
			player,
			"discovery",
			string.format("¡Nuevo descubrimiento: %s! +%s monedas", resource.name, Format.number(bonus))
		)
	end
	collectedEvent:FireClient(player, resourceId, added, isNew)
	StateService.push(player)
	return added
end

local function nearSellStation(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, plot in PlotService.all() do
		local points = plot.points
		if points and (points.sell - root.Position).Magnitude <= GameConfig.SellDistance then
			return true
		end
	end
	return false
end

function InventoryService.sellAll(player: Player): number
	local profile = PlayerDataService.get(player)
	if not profile then
		return 0
	end
	if not nearSellStation(player) then
		StateService.notify(player, "error", "Acércate a una estación de venta.", "sell_far")
		return 0
	end
	local kept = Inventory.keptCount(profile.inventory)
	local value = Inventory.takeSellable(profile.inventory)
	if value <= 0 then
		StateService.notify(
			player,
			"info",
			if kept > 0
				then "Solo llevas piezas que se conservan: véndelas una a una desde la mochila o expónlas en casa."
				else "Tu mochila está vacía. ¡A cavar!",
			"sell_empty"
		)
		return 0
	end
	profile.coins += value
	profile.stats.coinsEarned += value
	profile.stats.sales += 1
	StateService.notify(
		player,
		"sell",
		"Vendido por "
			.. Format.number(value)
			.. " monedas"
			.. (if kept > 0 then " · conservas " .. kept .. " pieza(s) para la vitrina" else "")
	)
	StateService.push(player)
	return value
end

-- Sells one unit of a kept piece (a relic): a deliberate choice, made at the sell station.
function InventoryService.sellOne(player: Player, resourceId: string): boolean
	local profile = PlayerDataService.get(player)
	local resource = Resources.get(resourceId)
	if not profile or not resource or not resource.keep then
		return false
	end
	local count = profile.inventory[resourceId] or 0
	if count <= 0 then
		return false
	end
	if not nearSellStation(player) then
		StateService.notify(player, "error", "Acércate a una estación de venta.", "sell_far")
		return false
	end
	profile.inventory[resourceId] = if count > 1 then count - 1 else nil
	profile.coins += resource.value
	profile.stats.coinsEarned += resource.value
	StateService.notify(player, "sell", resource.name .. " vendida por " .. Format.number(resource.value) .. " monedas")
	StateService.push(player)
	return true
end

function InventoryService.start()
	local limiter = RateLimiter.new(GameConfig.RateLimits.Sell.rate, GameConfig.RateLimits.Sell.burst)
	Remotes.event("Sell").OnServerEvent:Connect(function(player)
		if limiter:allow(player) then
			InventoryService.sellAll(player)
		end
	end)
	Remotes.event("SellItem").OnServerEvent:Connect(function(player, resourceId)
		if limiter:allow(player) and type(resourceId) == "string" and #resourceId <= 40 then
			InventoryService.sellOne(player, resourceId)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("Action") == "Sell" and limiter:allow(player) then
			InventoryService.sellAll(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return InventoryService
