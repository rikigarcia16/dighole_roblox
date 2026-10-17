--!strict
-- Composes the visible journal entries from the player's state snapshot (pure; tested offline).

local Journal = require(script.Parent.Parent.Config.Journal)

local JournalView = {}

export type Visible = { id: string, title: string, body: string }

local function holds(requires: { [string]: any }?, state: any): boolean
	if not requires then
		return true
	end
	local counter = state.anomalies and state.anomalies.counter or {}
	for key, value in requires do
		if key == "counterFound" then
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
		else
			return false -- unknown condition: hide rather than show something wrong
		end
	end
	return true
end
JournalView.holds = holds

local function fill(text: string, state: any): string
	local counter = state.anomalies and state.anomalies.counter or {}
	local stats = state.stats or {}
	return (
		text:gsub("{(%w+)}", function(name: string): string
			if name == "solvedCount" then
				return tostring(counter.solvedCount or 0)
			elseif name == "cellsDug" then
				return tostring(stats.cellsDug or 0)
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
