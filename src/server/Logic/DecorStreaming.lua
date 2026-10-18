--!strict
-- Which decorated sectors keep their decoration loaded (pure; tested offline).
--
-- Decoration (supports, lanterns, scenes) is rebuilt deterministically from the seed, so a sector
-- far from every player can drop it and build it again when someone comes back. Chests, geodes,
-- fossils and the Counter room are NOT decoration: they keep state and are never unloaded.

local DecorStreaming = {}

-- Sectors within KEEP of an active sector stay loaded (a sector is 32 m: 2 = 64 m each way).
DecorStreaming.Keep = 2

-- decorated: sectors that have been generated and decorated at least once
-- loaded:    sectors whose decoration currently exists
-- active:    sector indexes where players are right now
function DecorStreaming.plan(
	decorated: { [number]: boolean },
	loaded: { [number]: boolean },
	active: { number },
	keep: number?
): ({ number }, { number })
	local radius = keep or DecorStreaming.Keep
	local function wanted(index: number): boolean
		for _, a in active do
			if math.abs(index - a) <= radius then
				return true
			end
		end
		return false
	end
	local toLoad, toUnload = {}, {}
	for index in decorated do
		local want = wanted(index)
		if want and not loaded[index] then
			table.insert(toLoad, index)
		elseif not want and loaded[index] then
			table.insert(toUnload, index)
		end
	end
	table.sort(toLoad)
	table.sort(toUnload)
	return toLoad, toUnload
end

return DecorStreaming
