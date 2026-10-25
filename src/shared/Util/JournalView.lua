--!strict
-- Composes the visible journal entries from the player's state snapshot (pure; tested offline).

local Journal = require(script.Parent.Parent.Config.Journal)
local Anomalies = require(script.Parent.Parent.Config.Anomalies)

local JournalView = {}

export type Visible = { id: string, title: string, body: string }

local function holds(requires: { [string]: any }?, state: any): boolean
	if not requires then
		return true
	end
	local counter = state.anomalies and state.anomalies.counter or {}
	local workshop = state.anomalies and state.anomalies.workshop or {}
	local core = state.anomalies and state.anomalies.core or {}
	for key, value in requires do
		if key == "coreFound" then
			if (core.found == true) ~= value then
				return false
			end
		elseif key == "coreEngraved" then
			if (core.engraved == true) ~= value then
				return false
			end
		elseif key == "coreLoops" then
			-- 0 means "never broken"; n > 0 means "broken at least n times"
			local loops = core.loops or 0
			if (value == 0 and loops ~= 0) or (value > 0 and loops < value) then
				return false
			end
		elseif key == "workshopFound" then
			if (workshop.found == true) ~= value then
				return false
			end
		elseif key == "workshopHung" then
			if (workshop.hung == true) ~= value then
				return false
			end
		elseif key == "workshopBeyondE" then
			local beyond = workshop.hung == true and (workshop.hungCount or 0) > Anomalies.WorkshopEBlocks
			if beyond ~= value then
				return false
			end
		elseif key == "counterFound" then
			if (counter.found == true) ~= value then
				return false
			end
		elseif key == "counterSolved" then
			if (counter.solved == true) ~= value then
				return false
			end
		elseif key == "fossil" then
			local fossils = state.collection and state.collection.fossils or {}
			if not fossils[value] then
				return false
			end
		elseif key == "zone" then
			if not (state.zonesReached and state.zonesReached[value]) then
				return false
			end
		elseif key == "clue" then
			if not (state.clues and state.clues[value]) then
				return false
			end
		elseif key == "feat" or key == "noFeat" then
			local earned = state.feats ~= nil and state.feats[value] == true
			if earned ~= (key == "feat") then
				return false
			end
		elseif key == "geodes" then
			local stats = state.stats or {}
			if (stats.geodesOpened or 0) < value then
				return false
			end
		elseif key == "stations" then
			local stations = state.mobility and state.mobility.stations or {}
			if #stations < value then
				return false
			end
		elseif key == "set" or key == "anySet" then
			local found = false
			for _, set in state.sets or {} do
				if set.done and (key == "anySet" or set.id == value) then
					found = true
				end
			end
			if found ~= (if key == "anySet" then value else true) then
				return false
			end
		else
			return false -- unknown condition: hide rather than show something wrong
		end
	end
	return true
end
JournalView.holds = holds

local function fill(text: string, state: any): string
	local counter = state.anomalies and state.anomalies.counter or {}
	local workshop = state.anomalies and state.anomalies.workshop or {}
	local core = state.anomalies and state.anomalies.core or {}
	local stats = state.stats or {}
	return (
		text:gsub("{(%w+)}", function(name: string): string
			if name == "solvedCount" then
				return tostring(counter.solvedCount or 0)
			elseif name == "hungCount" then
				return tostring(workshop.hungCount or 0)
			elseif name == "workshopShort" then
				return tostring(math.max(0, Anomalies.WorkshopEBlocks - (workshop.hungCount or 0)))
			elseif name == "cellsDug" then
				return tostring(stats.cellsDug or 0)
			elseif name == "engravedCount" then
				return tostring(core.engravedCount or 0)
			elseif name == "loops" then
				return tostring(core.loops or 0)
			end
			return "{" .. name .. "}"
		end)
	)
end

function JournalView.entries(state: any): { Visible }
	local list = {}
	for _, entry in Journal do
		if holds(entry.requires, state) then
			local parts = {}
			for _, paragraph in entry.paragraphs do
				if holds(paragraph.requires, state) then
					table.insert(parts, fill(paragraph.text, state))
				end
			end
			table.insert(list, { id = entry.id, title = entry.title, body = table.concat(parts, "\n\n") })
		end
	end
	return list
end

return JournalView
