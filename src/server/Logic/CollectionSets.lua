--!strict
-- Pure collection-set progress and rewards (Config/Collections). A set pays once: the completion is
-- stored as profile.quests.completed["set_" .. id], which the profile already saves and sanitises.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Collections = require(Shared.Config.Collections)
local Fossils = require(Shared.Config.Fossils)

local CollectionSets = {}

export type SetView = { id: string, name: string, have: number, total: number, done: boolean, reward: number }

local function fossilCount(profile: any): number
	local n = 0
	for _, species in Fossils.List do
		if profile.collection.fossils[species.id] then
			n += 1
		end
	end
	return n
end
CollectionSets.fossilCount = fossilCount

function CollectionSets.progress(set: Collections.Set, profile: any): (number, number)
	if set.kind == "fossils" then
		return fossilCount(profile), #Fossils.List
	end
	local items = set.items or {}
	local have = 0
	for _, id in items do
		local got = if set.kind == "exhibit"
			then profile.collection.exhibit[id] == true
			else (profile.discoveries[id] or 0) > 0
		if got then
			have += 1
		end
	end
	return have, #items
end

function CollectionSets.isComplete(id: string, profile: any): boolean
	return profile.quests.completed["set_" .. id] == true
end

-- Pays every newly completed set. Returns the sets completed now. Mutates coins and quests.
function CollectionSets.advance(profile: any): { Collections.Set }
	local completed = {}
	for _, set in Collections do
		local key = "set_" .. set.id
		if not profile.quests.completed[key] then
			local have, total = CollectionSets.progress(set, profile)
			if total > 0 and have >= total then
				profile.quests.completed[key] = true
				profile.coins += set.reward
				profile.stats.coinsEarned += set.reward
				table.insert(completed, set)
			end
		end
	end
	return completed
end

function CollectionSets.view(profile: any): { SetView }
	local views = {}
	for _, set in Collections do
		local have, total = CollectionSets.progress(set, profile)
		table.insert(views, {
			id = set.id,
			name = set.name,
			have = have,
			total = total,
			done = CollectionSets.isComplete(set.id, profile),
			reward = set.reward,
		})
	end
	return views
end

return CollectionSets
