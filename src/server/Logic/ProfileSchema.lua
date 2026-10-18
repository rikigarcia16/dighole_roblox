--!strict
-- Player profile layout, defaults and migrations. Bump CURRENT_VERSION and add a migration step
-- whenever the layout changes; old saves are upgraded on load.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)
local Upgrades = require(Shared.Config.Upgrades)
local Resources = require(Shared.Config.Resources)
local Quests = require(Shared.Config.Quests)
local Story = require(Shared.Config.Story)
local Fossils = require(Shared.Config.Fossils)
local Mobility = require(Shared.Config.Mobility)
local Gear = require(Shared.Config.Gear)
local CellSet = require(Shared.Util.CellSet)

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = 4

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
	collection: {
		fossils: { [string]: { count: number, firstDepth: number } },
		-- kept pieces shown in the house display case: resourceId -> true. Added without a version
		-- bump: older saves simply have none (reconcile fills the default).
		exhibit: { [string]: boolean },
	},
	anomalies: {
		counter: { found: boolean, solved: boolean, rings: { number }, solvedCount: number, solvedAt: number },
		-- E.'s workshop (Ancient Caverns). Added without a version bump: older saves get the default.
		workshop: { found: boolean, hung: boolean, hungCount: number, hungAt: number, toolId: string },
	},
	mobility: {
		ropes: number, -- ropes carried
		placedRopes: { { cx: number, d: number, cz: number, length: number } },
		stations: { { id: string, cx: number, d: number, cz: number } },
		rescues: number,
	},
	quests: { index: number, completed: { [string]: boolean } },
	-- player preferences (added without a version bump: older saves get the defaults)
	settings: { effects: number, shake: boolean, tutorialDone: boolean },
	gear: { [string]: boolean }, -- special equipment owned (Config/Gear); additive like settings
	stats: {
		cellsDug: number,
		maxDepth: number,
		coinsEarned: number,
		sales: number,
		cavesFound: number,
		chestsOpened: number,
		findsFound: number,
		geodesOpened: number,
		fossilsExtracted: number,
	},
	plot: {
		seed: number,
		dug: { number }, -- CellSet encoded keys of excavated cells
		openedChests: { string }, -- ids of chests and geodes already opened in this plot
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
		collection = { fossils = {}, exhibit = {} },
		anomalies = {
			counter = { found = false, solved = false, rings = {}, solvedCount = 0, solvedAt = 0 },
			workshop = { found = false, hung = false, hungCount = 0, hungAt = 0, toolId = "" },
		},
		mobility = { ropes = 0, placedRopes = {}, stations = {}, rescues = 0 },
		quests = { index = 1, completed = {} },
		settings = { effects = 0, shake = true, tutorialDone = false },
		gear = {},
		stats = {
			cellsDug = 0,
			maxDepth = 0,
			coinsEarned = 0,
			sales = 0,
			cavesFound = 0,
			chestsOpened = 0,
			findsFound = 0,
			geodesOpened = 0,
			fossilsExtracted = 0,
		},
		plot = { seed = seed, dug = {}, openedChests = {} },
	}
end

local migrations: { [number]: (any) -> () } = {
	-- v1 -> v2: quests, clues and chests were added. Their defaults come from reconcile; nothing to
	-- convert. Kept as the template for future migrations.
	[1] = function(_data) end,
	-- v2 -> v3: fossil collection added; the old "Fósil raro" find item became "Fragmento fósil"
	-- (same id, still sellable), so inventories keep their items.
	[2] = function(_data) end,
	-- v3 -> v4: anomalies (the Counter) and mobility (ropes, lift stations, rescues). Players who
	-- had already read the stone tablet keep the clue; its location simply moved into the room.
	[3] = function(_data) end,
}

-- Settings arrive from the client (SaveSettings) and from saves: only known keys and valid values.
-- effects: 0 = automatic, 1..3 = low / medium / high.
function ProfileSchema.applySettings(target: any, input: any)
	if type(input) ~= "table" then
		return
	end
	local effects = input.effects
	if type(effects) == "number" and effects == math.floor(effects) and effects >= 0 and effects <= 3 then
		target.effects = effects
	end
	if type(input.shake) == "boolean" then
		target.shake = input.shake
	end
	if input.tutorialDone == true then
		target.tutorialDone = true -- one way: the tutorial never comes back once finished
	end
end

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
			local n = math.floor(finiteNonNegative(count, 0))
			if Resources.get(id) and n > 0 then
				profile.inventory[id] = n
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

	if type(data.collection) == "table" and type(data.collection.fossils) == "table" then
		for id, entry in data.collection.fossils do
			if Fossils.get(id) and type(entry) == "table" then
				profile.collection.fossils[id] = {
					count = math.max(1, math.floor(finiteNonNegative(entry.count, 1))),
					firstDepth = math.floor(finiteNonNegative(entry.firstDepth, 0)),
				}
			end
		end
	end

	if type(data.collection) == "table" and type(data.collection.exhibit) == "table" then
		for id, shown in data.collection.exhibit do
			local resource = type(id) == "string" and Resources.get(id)
			if shown == true and resource and resource.keep then
				profile.collection.exhibit[id] = true
			end
		end
	end

	if type(data.anomalies) == "table" and type(data.anomalies.counter) == "table" then
		local c = data.anomalies.counter
		local counter = profile.anomalies.counter
		counter.found = c.found == true
		counter.solved = c.solved == true
		counter.solvedCount = math.floor(finiteNonNegative(c.solvedCount, 0))
		counter.solvedAt = math.floor(finiteNonNegative(c.solvedAt, 0))
		if type(c.rings) == "table" then
			for i = 1, 3 do
				local v = c.rings[i]
				if type(v) == "number" and v >= 1 and v <= 6 and v == math.floor(v) then
					counter.rings[i] = v
				else
					table.clear(counter.rings) -- incomplete: AnomalyService restarts from the seed
					break
				end
			end
		end
	end
	if type(data.anomalies) == "table" and type(data.anomalies.workshop) == "table" then
		local w = data.anomalies.workshop
		local workshop = profile.anomalies.workshop
		workshop.found = w.found == true or w.hung == true
		workshop.hung = w.hung == true
		workshop.hungCount = math.floor(finiteNonNegative(w.hungCount, 0))
		workshop.hungAt = math.floor(finiteNonNegative(w.hungAt, 0))
		workshop.toolId = if type(w.toolId) == "string" and Tools.get(w.toolId) then w.toolId else ""
	end

	if type(data.mobility) == "table" then
		local m = data.mobility
		local mobility = profile.mobility
		mobility.ropes = math.clamp(math.floor(finiteNonNegative(m.ropes, 0)), 0, 99)
		mobility.rescues = math.floor(finiteNonNegative(m.rescues, 0))
		local function finite(v: any): boolean
			return type(v) == "number" and v == v and math.abs(v) < 1e7
		end
		local function cell(entry: any): boolean
			return type(entry) == "table" and finite(entry.cx) and finite(entry.d) and finite(entry.cz)
		end
		if type(m.placedRopes) == "table" then
			for _, rope in m.placedRopes do
				if
					cell(rope)
					and finite(rope.length)
					and rope.length > 0
					and rope.length <= Mobility.Rope.maxLength
					and #mobility.placedRopes < 24
				then
					table.insert(mobility.placedRopes, { cx = rope.cx, d = rope.d, cz = rope.cz, length = rope.length })
				end
			end
		end
		if type(m.stations) == "table" then
			local seen = {}
			for _, station in m.stations do
				-- unknown ids are dropped (a rollback to an older build must not crash on newer stations)
				if
					cell(station)
					and type(station.id) == "string"
					and Mobility.StationById[station.id]
					and not seen[station.id]
				then
					seen[station.id] = true
					table.insert(
						mobility.stations,
						{ id = station.id, cx = station.cx, d = station.d, cz = station.cz }
					)
				end
			end
		end
	end

	if type(data.gear) == "table" then
		for id, owned in data.gear do
			if owned == true and type(id) == "string" and Gear.ById[id] then
				profile.gear[id] = true
			end
		end
	end

	if type(data.settings) == "table" then
		ProfileSchema.applySettings(profile.settings, data.settings)
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
		local seed = data.plot.seed
		if type(seed) == "number" and seed == seed and math.abs(seed) < 2 ^ 31 then
			profile.plot.seed = seed
		end
		if type(data.plot.dug) == "table" then
			-- run-length pairs of finite integers; stop at the first bad pair (CellSet also guards)
			local clean = {}
			local raw = data.plot.dug
			for i = 1, #raw - 1, 2 do
				local gap, run = raw[i], raw[i + 1]
				if
					type(gap) ~= "number"
					or type(run) ~= "number"
					or gap ~= math.floor(gap)
					or run ~= math.floor(run)
					or gap < 0
					or gap > CellSet.MaxKey
					or run < 1
					or run > CellSet.MaxRun
				then
					break
				end
				table.insert(clean, gap)
				table.insert(clean, run)
			end
			profile.plot.dug = clean
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
