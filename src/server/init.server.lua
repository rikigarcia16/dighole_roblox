--!strict
-- Server bootstrap: starts every service in dependency order.

local Services = script:WaitForChild("Services")

local order = {
	"PlayerDataService", -- must start first: other services subscribe to its events
	"StateService",
	"PlotService",
	"EnergyService",
	"EquipmentService",
	"InventoryService",
	"ExhibitService",
	"ShopService",
	"QuestService",
	"SpecialsService",
	"AnomalyService",
	"MobilityService",
	"GearService",
	"DiggingService",
}

for _, name in order do
	local service = require(Services:WaitForChild(name)) :: any
	if service.start then
		local ok, err = pcall(service.start)
		if not ok then
			warn("[Server] failed to start " .. name .. ": " .. tostring(err))
		end
	end
end

print("[Server] THE HOLE NEVER ENDS started")
