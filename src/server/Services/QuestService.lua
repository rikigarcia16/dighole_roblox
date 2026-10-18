--!strict
-- Main quest chain (Config/Quests). Progress is derived from the profile every time the player's
-- state changes, so quests react to anything the server records and can never pay twice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local QuestLogic = require(script.Parent.Parent.Logic.QuestLogic)
local CollectionSets = require(script.Parent.Parent.Logic.CollectionSets)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateService = require(script.Parent.StateService)

local QuestService = {}

function QuestService.start()
	StateService.beforePush(function(player)
		local profile = PlayerDataService.get(player)
		if not profile then
			return
		end
		for _, quest in QuestLogic.advance(profile) do
			local text = "Misión completada: " .. quest.title
			if quest.reward > 0 then
				text ..= " · +" .. Format.number(quest.reward) .. " monedas"
			end
			StateService.notify(player, "quest", text)
		end
		for _, set in CollectionSets.advance(profile) do
			StateService.notify(
				player,
				"discovery",
				"Colección completada: " .. set.name .. " · +" .. Format.number(set.reward) .. " monedas"
			)
		end
	end)
	StateService.addSnapshotProvider(function(_player, profile, snapshot)
		snapshot.quest = QuestLogic.view(profile)
		snapshot.sets = CollectionSets.view(profile)
	end)
end

return QuestService
