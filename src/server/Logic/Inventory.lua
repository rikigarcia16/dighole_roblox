--!strict
-- Pure backpack helpers. The inventory is a map resourceId -> count.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Resources = require(Shared.Config.Resources)

local Inventory = {}

function Inventory.used(inventory: { [string]: number }): number
	local total = 0
	for id, count in inventory do
		local resource = Resources.get(id)
		total += count * (resource and resource.weight or 1)
	end
	return total
end

-- Adds up to `amount` units, limited by `capacity`. Returns how many were actually added.
function Inventory.add(inventory: { [string]: number }, id: string, amount: number, capacity: number): number
	local resource = Resources.get(id)
	if not resource or amount <= 0 then
		return 0
	end
	local fit
	if resource.weight <= 0 then
		fit = amount -- weightless items (hidden finds) always fit
	else
		local free = capacity - Inventory.used(inventory)
		fit = math.clamp(math.floor(free / resource.weight), 0, amount)
	end
	if fit > 0 then
		inventory[id] = (inventory[id] or 0) + fit
	end
	return fit
end

function Inventory.value(inventory: { [string]: number }): number
	local total = 0
	for id, count in inventory do
		local resource = Resources.get(id)
		if resource then
			total += resource.value * count
		end
	end
	return total
end

-- Coins for the first time a resource is ever found. Structure rewards (geodes, the fossil fragment
-- given for a repeated species) already pay through their own structure, so they give none: a
-- repeated fossil must never pay out like a discovery (+225 seen in Studio test 1).
function Inventory.discoveryBonus(resource: { value: number, rewardOnly: boolean? }, isNew: boolean): number
	if not isNew or resource.rewardOnly then
		return 0
	end
	return resource.value * 5
end

return Inventory
