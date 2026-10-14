--!strict
-- Player profile layout, defaults and migrations. Bump CURRENT_VERSION and add a migration step
-- whenever the layout changes; old saves are upgraded on load.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)
local Upgrades = require(Shared.Config.Upgrades)
local Resources = require(Shared.Config.Resources)
local Quests = require(Shared.Config.Quests)
local Story = require(Shared.Config.Story)

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = 2

export type Profile = {
	version: number,
	coins: number,
	tools: { [string]: boolean },
	equippedTool: string,
	upgrades: { [string]: number },
	inventory: { [string]: number },
	discoveries: { [string]: number }, -- resourceId -> total ever collected
	zonesReached: { [string]: boolean },
	clues: { [string]: boolean }, -- story notes read
	quests: { index: number, completed: { [string]: boolean } },
	stats: {
		cellsDug: number,
		maxDepth: number,
		coinsEarned: number,
		sales: number,
		cavesFound: number,
		chestsOpened: number,
		findsFound: number,
	},
	plot: {
		seed: number,
		dug: { number }, -- CellSet encoded keys of excavated cells
		openedChests: { string }, -- cave keys whose chest was already opened
	},
}

function ProfileSchema.default(seed: number): Profile
	local upgrades = {}
	for _, track in Upgrades.List do
		upgrades[track.id] = 1
	end
	return {
		version = ProfileSchema.CURRENT_VERSION,
		coins = 0,
		tools = { [Tools.DefaultToolId] = true },
		equippedTool = Tools.DefaultToolId,
		upgrades = upgrades,
		inventory = {},
		discoveries = {},
		zonesReached = { garden = true },
		clues = {},
		quests = { index = 1, completed = {} },
		stats = {
			cellsDug = 0,
			maxDepth = 0,
			coinsEarned = 0,
			sales = 0,
			cavesFound = 0,
			chestsOpened = 0,
			findsFound = 0,
		},
		plot = { seed = seed, dug = {}, openedChests = {} },
	}
end

local migrations: { [number]: (any) -> () } = {
	-- v1 -> v2: quests, clues and chests were added. Their defaults come from reconcile; nothing to
	-- convert. Kept as the template for future migrations.
	[1] = function(_data) end,
}

local function finiteNonNegative(value: any, fallback: number): number
	if type(value) == "number" and value == value and value >= 0 and value < math.huge then
		return value
	end
	return fallback
end

-- Upgrades and sanitises stored data. Unknown ids are dropped, missing fields get defaults.
function ProfileSchema.reconcile(data: any, seed: number): Profile
	local profile = ProfileSchema.default(seed)
	if type(data) ~= "table" then
		return profile
	end

	local version = type(data.version) == "number" and data.version or 1
	while version < ProfileSchema.CURRENT_VERSION do
		local step = migrations[version]
		if step then
			step(data)
		end
		version += 1
	end

	profile.coins = math.floor(finiteNonNegative(data.coins, 0))

	if type(data.tools) == "table" then
		for id, owned in data.tools do
			if owned == true and Tools.get(id) then
				profile.tools[id] = true
			end
		end
	end
	if type(data.equippedTool) == "string" and profile.tools[data.equippedTool] then
		profile.equippedTool = data.equippedTool
	end

	if type(data.upgrades) == "table" then
		for _, track in Upgrades.List do
			local level = data.upgrades[track.id]
			if type(level) == "number" then
				profile.upgrades[track.id] = math.clamp(math.floor(level), 1, #track.levels)
			end
		end
	end

	if type(data.inventory) == "table" then
		for id, count in data.inventory do
			if Resources.get(id) and type(count) == "number" and count > 0 then
				profile.inventory[id] = math.floor(count)
			end
		end
	end

	if type(data.discoveries) == "table" then
		for id, count in data.discoveries do
			if Resources.get(id) then
				profile.discoveries[id] = math.floor(finiteNonNegative(count, 1))
			end
		end
	end

	if type(data.zonesReached) == "table" then
		for id, reached in data.zonesReached do
			if reached == true and type(id) == "string" then
				profile.zonesReached[id] = true
			end
		end
	end

	if type(data.clues) == "table" then
		for id, read in data.clues do
			if read == true and Story.Notes[id] then
				profile.clues[id] = true
			end
		end
	end

	if type(data.quests) == "table" then
		if type(data.quests.index) == "number" then
			profile.quests.index = math.clamp(math.floor(data.quests.index), 1, #Quests + 1)
		end
		if type(data.quests.completed) == "table" then
			for id, done in data.quests.completed do
				if done == true and type(id) == "string" then
					profile.quests.completed[id] = true
				end
			end
		end
	end

	if type(data.stats) == "table" then
		for key, default in profile.stats do
			profile.stats[key] = finiteNonNegative(data.stats[key], default)
		end
	end

	if type(data.plot) == "table" then
		if type(data.plot.seed) == "number" then
			profile.plot.seed = data.plot.seed
		end
		if type(data.plot.dug) == "table" then
			profile.plot.dug = data.plot.dug
		end
		if type(data.plot.openedChests) == "table" then
			for _, key in data.plot.openedChests do
				if type(key) == "string" and #key <= 32 then
					table.insert(profile.plot.openedChests, key)
				end
			end
		end
	end

	profile.version = ProfileSchema.CURRENT_VERSION
	return profile
end

return ProfileSchema
