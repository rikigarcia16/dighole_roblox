--!strict
-- Pure quest evaluation over a profile (see Config/Quests).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)

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
