--!strict
-- Sends hit / discovery feedback to the players close enough to see it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FxService = {}

local FX_RADIUS = 220
local digFx = Remotes.event("DigFx")
local specialFx = Remotes.event("SpecialFx")

local function nearby(actor: Player, position: Vector3): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if other == actor or (root and (root.Position - position).Magnitude <= FX_RADIUS) then
			table.insert(list, other)
		end
	end
	return list
end

-- A dig hit. `progress` is the damage fraction of the target cell after the hit (1 = broke,
-- -1 = the tool bounced off a material that is too hard), used by the hardness indicator.
function FxService.broadcast(
	actor: Player,
	position: Vector3,
	resourceId: string,
	broke: boolean,
	toolId: string?,
	bestId: string?,
	progress: number?
)
	for _, other in nearby(actor, position) do
		digFx:FireClient(other, actor, position, resourceId, broke, toolId, bestId, progress)
	end
end

-- A special moment: "geode", "fossil", "chest", "cave", "landmark". `resourceId` tints the effect.
function FxService.special(actor: Player, position: Vector3, kind: string, resourceId: string?)
	for _, other in nearby(actor, position) do
		specialFx:FireClient(other, actor, position, kind, resourceId)
	end
end

return FxService
