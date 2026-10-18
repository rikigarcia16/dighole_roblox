--!strict
-- Battery for special equipment (Config/Gear: lamp, detector). Digging never uses it. Energy is
-- runtime-only (not saved): it refills at the surface and next to an owned lift station.
-- Replicated through player attributes "Energy" / "MaxEnergy" (cheap, frequent updates).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Anomalies = require(ReplicatedStorage.Shared.Config.Anomalies)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EnergyService = {}

local energy: { [Player]: number } = {}

function EnergyService.max(player: Player): number
	local profile = PlayerDataService.get(player)
	local base = Upgrades.valueAt("battery", profile and profile.upgrades.battery or 1)
	-- E.'s battery: hanging your shovel in the workshop (WorkshopService) adds half as much again
	if profile and profile.anomalies.workshop.hung then
		return math.floor(base * (1 + Anomalies.WorkshopBatteryBonus))
	end
	return base
end

function EnergyService.get(player: Player): number
	return energy[player] or 0
end

local function publish(player: Player)
	player:SetAttribute("Energy", math.floor((energy[player] or 0) * 10) / 10)
	player:SetAttribute("MaxEnergy", EnergyService.max(player))
end

function EnergyService.consume(player: Player, amount: number): boolean
	local current = energy[player] or 0
	if current + 1e-6 < amount then
		return false
	end
	energy[player] = current - amount
	publish(player)
	return true
end

function EnergyService.refill(player: Player)
	energy[player] = EnergyService.max(player)
	publish(player)
end

-- Called after a battery upgrade so the new capacity is usable immediately.
function EnergyService.refresh(player: Player)
	EnergyService.refill(player)
end

-- Other places that recharge the battery (MobilityService: next to an owned lift station).
local rechargeSources: { (Player) -> boolean } = {}
function EnergyService.addRechargeSource(check: (Player) -> boolean)
	table.insert(rechargeSources, check)
end

local function isAtSurface(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return Grid.depthMetersFromY(root.Position.Y - 3) <= GameConfig.SurfaceRechargeDepth
end

function EnergyService.start()
	PlayerDataService.onLoaded(function(player)
		EnergyService.refill(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		energy[player] = nil
	end)

	task.spawn(function()
		local dt = GameConfig.EnergyTickSeconds
		while true do
			task.wait(dt)
			for player, current in energy do
				local max = EnergyService.max(player)
				local charging = isAtSurface(player)
				for _, check in rechargeSources do
					charging = charging or check(player)
				end
				if current < max and charging then
					energy[player] = math.min(max, current + max * Upgrades.SurfaceRechargePerSecond * dt)
					publish(player)
				end
			end
		end
	end)
end

return EnergyService
