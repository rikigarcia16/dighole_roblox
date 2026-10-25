--!strict
-- Pure quest evaluation over a profile (see Config/Quests).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Collections = require(Shared.Config.Collections)
local CollectionSets = require(script.Parent.CollectionSets)

local QuestLogic = {}

export type QuestView = {
	id: string,
	title: string,
	hint: string,
	progress: number,
	target: number,
	reward: number,
	index: number,
	total: number,
}

function QuestLogic.progress(quest: Quests.Quest, profile: any): number
	local key = quest.key
	if quest.kind == "stat" then
		return profile.stats[key :: string] or 0
	elseif quest.kind == "depth" then
		return profile.stats.maxDepth or 0
	elseif quest.kind == "collect" then
		return profile.discoveries[key :: string] or 0
	elseif quest.kind == "tool" then
		return if profile.tools[key :: string] then 1 else 0
	elseif quest.kind == "clue" then
		return if profile.clues[key :: string] then 1 else 0
	elseif quest.kind == "fossils" then
		return CollectionSets.fossilCount(profile)
	elseif quest.kind == "counter" then
		return if profile.anomalies.counter[key :: string] == true then 1 else 0
	elseif quest.kind == "core" then
		local core = profile.anomalies.core
		if key == "looped" then
			return if core.loops > 0 then 1 else 0
		end
		return if core[key :: string] == true then 1 else 0
	elseif quest.kind == "stations" then
		return #profile.mobility.stations
	elseif quest.kind == "set" then
		for _, set in Collections do
			if set.id == key then
				local have, total = CollectionSets.progress(set, profile)
				return if total > 0 and have >= total then 1 else 0
			end
		end
	end
	return 0
end

-- Completes every finished quest in order. Returns the list of quests completed now.
-- Mutates profile.quests and profile.coins.
function QuestLogic.advance(profile: any): { Quests.Quest }
	local completed = {}
	while true do
		local quest = Quests[profile.quests.index]
		if not quest or QuestLogic.progress(quest, profile) < quest.target then
			break
		end
		if not profile.quests.completed[quest.id] then
			profile.quests.completed[quest.id] = true
			profile.coins += quest.reward
			profile.stats.coinsEarned += quest.reward
			table.insert(completed, quest)
		end
		profile.quests.index += 1
	end
	return completed
end

function QuestLogic.view(profile: any): QuestView?
	local quest = Quests[profile.quests.index]
	if not quest then
		return nil
	end
	return {
		id = quest.id,
		title = quest.title,
		hint = quest.hint,
		progress = math.min(QuestLogic.progress(quest, profile), quest.target),
		target = quest.target,
		reward = quest.reward,
		index = profile.quests.index,
		total = #Quests,
	}
end

return QuestLogic
