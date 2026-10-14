--!strict
-- Gives the character a physical Tool built from the equipped tool's recipe and keeps it in hand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolModels = require(ReplicatedStorage.Shared.Util.ToolModels)
local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EquipmentService = {}

local function removeTools(player: Player)
	local containers: { Instance? } = { player.Character, player:FindFirstChildOfClass("Backpack") }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ToolId") then
					child:Destroy()
				end
			end
		end
	end
end

-- Returns the tool id the character currently holds (nil if none).
function EquipmentService.heldToolId(player: Player): string?
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("ToolId") :: string?
end

function EquipmentService.equip(player: Player)
	local profile = PlayerDataService.get(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local toolId = profile.equippedTool
	if not Tools.get(toolId) then
		toolId = Tools.DefaultToolId
	end
	removeTools(player)
	local tool = ToolModels.buildTool(toolId)
	tool.Parent = player:FindFirstChildOfClass("Backpack")
	humanoid:EquipTool(tool)

	-- Keep the tool in hand: the backpack hotbar is hidden, but number keys could still unequip.
	tool.AncestryChanged:Connect(function()
		if tool.Parent and tool.Parent:IsA("Backpack") then
			task.defer(function()
				if tool.Parent and tool.Parent:IsA("Backpack") and humanoid.Parent and humanoid.Health > 0 then
					humanoid:EquipTool(tool)
				end
			end)
		end
	end)
end

function EquipmentService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			if not character.Parent then
				character.AncestryChanged:Wait()
			end
			character:WaitForChild("Humanoid", 10)
			if PlayerDataService.get(player) then
				EquipmentService.equip(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	PlayerDataService.onLoaded(function(player)
		if player.Character then
			EquipmentService.equip(player)
		end
	end)
end

return EquipmentService
