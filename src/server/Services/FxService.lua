--!strict
-- Sends hit / discovery feedback to the players close enough to see it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FxService = {}

local FX_RADIUS = 220
local digFx = Remotes.event("DigFx")

-- (actor, position, resourceId, broke, toolId?, highlightResourceId?)
function FxService.broadcast(
	actor: Player,
	position: Vector3,
	resourceId: string,
	broke: boolean,
	toolId: string?,
	bestId: string?
)
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if other == actor or (root and (root.Position - position).Magnitude <= FX_RADIUS) then
			digFx:FireClient(other, actor, position, resourceId, broke, toolId, bestId)
		end
	end
end

return FxService
