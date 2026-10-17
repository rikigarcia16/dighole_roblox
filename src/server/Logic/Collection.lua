--!strict
-- Fossil collection rules (pure; tested offline). The profile keeps, per species, how many were
-- extracted and the depth of the first one, so the journal can say where it was found.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Fossils = require(Shared.Config.Fossils)

local Collection = {}

export type Entry = { count: number, firstDepth: number }

export type Result = {
	isNew: boolean,
	reward: number, -- coins for a first registration
	fragment: boolean, -- repeats give a sellable fossil fragment instead
}

-- Registers one extracted fossil. Mutates profile.collection and profile.coins.
function Collection.registerFossil(profile: any, speciesId: string, depth: number): Result?
	local species = Fossils.get(speciesId)
	if not species then
		return nil
	end
	local fossils = profile.collection.fossils
	local entry = fossils[speciesId]
	if entry then
		entry.count += 1
		return { isNew = false, reward = 0, fragment = true }
	end
	fossils[speciesId] = { count = 1, firstDepth = math.floor(depth) }
	profile.coins += species.reward
	profile.stats.coinsEarned += species.reward
	return { isNew = true, reward = species.reward, fragment = false }
end

function Collection.progress(profile: any): (number, number)
	local found = 0
	for _, species in Fossils.List do
		if profile.collection.fossils[species.id] then
			found += 1
		end
	end
	return found, #Fossils.List
end

return Collection
