-- Progression simulation: a bot digs a 4x4 shaft straight down through the real generated
-- terrain, sells when the backpack is full (digging uses no energy), and buys the cheapest
-- available improvement. Prints when key milestones happen so the economy targets in
-- docs/BALANCE.md can be checked after any config change.
--
-- Model assumptions (deliberately conservative):
--   * hits on a cell = ceil(hardness / power); a radius>0 tool damages several shaft cells per hit
--     (EFFECTIVE_CELLS below accounts for cells outside the shaft or already dug)
--   * each surface trip costs TRIP_SECONDS (teleport up, walk to the cart, walk back, drop down)
--   * the player is never idle and never makes mistakes; real players will be ~1.5-2x slower

local H = loadfile("tests/harness.lua")()
H.mount("ReplicatedStorage", "Shared", "src/shared")
H.mount("ServerScriptService", "Server", "src/server")

local Resources = H.module("ReplicatedStorage", "Shared", "Config", "Resources")
local Tools = H.module("ReplicatedStorage", "Shared", "Config", "Tools")
local Upgrades = H.module("ReplicatedStorage", "Shared", "Config", "Upgrades")
local Quests = H.module("ReplicatedStorage", "Shared", "Config", "Quests")
local OreGeneration = H.module("ServerScriptService", "Server", "Logic", "OreGeneration")
local Grid = H.module("ReplicatedStorage", "Shared", "Util", "Grid")

local TRIP_SECONDS = 14
local SHAFT = 4
local REAL_PLAYER_FACTOR = 1.7
local function effectiveCells(radius)
	if radius <= 0 then
		return 1
	end
	-- a narrow shaft caps how many fresh cells a big radius can reach per hit
	return math.clamp(#Grid.sphereOffsets(radius) * 0.45, 1, 6)
end

local function simulate(seed, maxMinutes)
	local t = 0
	local coins = 0
	local inventory, used = {}, 0
	local tools = { [Tools.DefaultToolId] = true }
	local tool = Tools.get(Tools.DefaultToolId)
	local levels = { backpack = 1, battery = 1 }
	local energy = Upgrades.valueAt("battery", 1)
	local depth, cellInLayer = 1, 0
	local discovered = {}
	local events = {}
	local function event(name)
		if not events[name] then
			events[name] = t
		end
	end
	-- quest rewards the bot can earn by itself (depth, tools, finds); the rest needs a player
	local paid = {}
	local function questRewards(kind, key, value)
		for _, q in Quests do
			if not paid[q.id] and q.kind == kind and (q.key == nil or q.key == key) and value >= q.target then
				paid[q.id] = true
				coins += q.reward
			end
		end
	end

	local function sell()
		t += TRIP_SECONDS
		local value = 0
		for id, n in inventory do
			value += Resources.get(id).value * n
		end
		if value > 0 then
			event("first sale")
		end
		coins += value
		inventory, used = {}, 0
		energy = Upgrades.valueAt("battery", levels.battery)
		-- shopping: repeatedly buy the cheapest affordable improvement
		while true do
			local bestCost, bestAction = math.huge, nil
			for _, candidate in Tools.List do
				if
					candidate.purchasable
					and not tools[candidate.id]
					and candidate.power > tool.power
					and candidate.price < bestCost
				then
					bestCost, bestAction =
						candidate.price, function()
							tools[candidate.id] = true
							tool = candidate
							event("tool: " .. candidate.name)
							questRewards("tool", candidate.id, 1)
						end
				end
			end
			for _, track in Upgrades.List do
				local nextLevel = not track.hidden and track.levels[(levels[track.id] or 1) + 1]
				if nextLevel and nextLevel.price < bestCost then
					bestCost, bestAction =
						nextLevel.price, function()
							levels[track.id] = (levels[track.id] or 1) + 1
							event(track.name .. " nivel " .. levels[track.id])
						end
				end
			end
			if not bestAction or bestCost > coins then
				break
			end
			coins -= bestCost
			bestAction()
			event("first purchase")
		end
		energy = Upgrades.valueAt("battery", levels.battery)
	end

	while t < maxMinutes * 60 do
		local x, z = cellInLayer % SHAFT + 6, cellInLayer // SHAFT + 6
		local id = OreGeneration.resourceAt(seed, x, depth, z)
		local r = Resources.get(id)
		if not r then
			-- natural air (cave / landmark pocket): nothing to dig
		elseif r.requiredPower > tool.power then
			-- cannot break it: skip the cell (the player digs around it)
			if r.isOre == false then
				-- the whole layer is base rock we cannot dig: we are blocked until we buy something
				event("blocked by " .. r.name .. " at " .. depth .. " m")
				sell()
				if r.requiredPower > tool.power and coins < 1 then
					t += 1
				end
			end
		else
			local hits = math.ceil(r.hardness / tool.power) / effectiveCells(tool.radius)
			t += hits * tool.cooldown
			if used < Upgrades.valueAt("backpack", levels.backpack) then
				inventory[id] = (inventory[id] or 0) + 1
				used += 1
			end
			if not discovered[id] then
				discovered[id] = true
				coins += r.value * 5
				questRewards("collect", id, 1)
			end
			local findId = not r.isOre and OreGeneration.findAt(seed, x, depth, z)
			if findId then
				inventory[findId] = (inventory[findId] or 0) + 1
				event("first find: " .. Resources.get(findId).name)
				questRewards("collect", findId, 1)
			end
			if used >= Upgrades.valueAt("backpack", levels.backpack) then
				sell()
			end
		end
		cellInLayer += 1
		if cellInLayer >= SHAFT * SHAFT then
			cellInLayer = 0
			depth += 1
			questRewards("depth", nil, depth)
			if depth == 25 then
				event("25 m")
			end
			if depth == 50 then
				event("ZONA 2 (50 m)")
			end
			if depth == 150 then
				event("ZONA 3 (150 m)")
			end
			if depth == 350 then
				event("ZONA 4 (350 m)")
			end
			if depth == 650 then
				event("ZONA 5 (650 m)")
			end
			if depth == 1000 then
				event("ZONA 6 (1000 m)")
			end
			if depth == 1500 then
				event("ZONA 7 (1500 m)")
			end
		end
	end
	return events, depth, coins
end

local seeds = { 11, 222, 3333 }
local merged = {}
for _, seed in seeds do
	local events = simulate(seed, 600)
	for name, time in events do
		merged[name] = merged[name] or {}
		table.insert(merged[name], time)
	end
end
local rows = {}
for name, times in merged do
	table.sort(times)
	table.insert(rows, { name = name, median = times[math.ceil(#times / 2)], n = #times })
end
table.sort(rows, function(a, b)
	return a.median < b.median
end)
print(string.format("%-34s %12s %16s", "milestone", "bot (min)", "est. player (min)"))
for _, row in rows do
	if not row.name:find("^blocked") or row.n > 0 then
		print(
			string.format(
				"%-34s %12.1f %16.1f%s",
				row.name,
				row.median / 60,
				row.median / 60 * REAL_PLAYER_FACTOR,
				row.n < #seeds and string.format("  (%d/%d seeds)", row.n, #seeds) or ""
			)
		)
	end
end
