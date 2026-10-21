--!strict
-- Feats (Config/Feats): follows each player's descent (Logic/Descent) and grants a feat once, the
-- first time it happens. The descent lives only in memory: leaving the game ends it.
--
-- Inputs, all server side: the character's depth every half second, PlotService teleports (lift
-- rides, the beacon and respawns make a descent "assisted") and SpecialsService for geodes.
-- Earned feats are saved in profile.feats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Feats = require(ReplicatedStorage.Shared.Config.Feats)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Grid = require(ReplicatedStorage.Shared.Util.Grid)
local Descent = require(script.Parent.Parent.Logic.Descent)
local Inventory = require(script.Parent.Parent.Logic.Inventory)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local FxService = require(script.Parent.FxService)

local FeatService = {}

local POLL_SECONDS = 0.5

local descents: { [Player]: Descent.State } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function grant(player: Player, earned: { string })
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	for _, id in earned do
		local feat = Feats.ById[id]
		if feat and not profile.feats[id] then
			profile.feats[id] = true
			local root = rootOf(player)
			if root then
				FxService.personal(player, root.Position, "feat")
			end
			StateService.notify(player, "discovery", string.format("Hazaña: «%s». %s", feat.name, feat.reward))
			StateService.push(player)
		end
	end
end

-- A geode opened by `player` (SpecialsService).
function FeatService.geodeOpened(player: Player)
	local state = descents[player]
	if state then
		grant(player, Descent.geode(state))
	end
end

function FeatService.start()
	PlotService.onTeleport(function(player: Player)
		local state = descents[player]
		if state then
			Descent.assist(state)
		end
	end)

	local function watch(player: Player)
		-- joining or respawning never starts an unaided descent; walking out of the house does
		player.CharacterAdded:Connect(function()
			descents[player] = Descent.new(true)
		end)
		if player.Character then
			descents[player] = Descent.new(true)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		descents[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			for player, state in descents do
				local root = rootOf(player)
				local profile = PlayerDataService.get(player)
				if root and profile then
					local depth = Grid.depthMetersFromY(root.Position.Y - 3)
					local capacity = Upgrades.valueAt("backpack", profile.upgrades.backpack)
					local fill = if capacity > 0 then Inventory.used(profile.inventory) / capacity else 0
					local earned = Descent.step(state, depth, fill)
					if #earned > 0 then
						grant(player, earned)
					end
				end
			end
		end
	end)
end

return FeatService
