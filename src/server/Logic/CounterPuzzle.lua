--!strict
-- The Counter's ring puzzle (pure; tested offline).
--
-- Three rings, six glyphs each. The solution comes from the plot seed (every plot has its own) and
-- is shown on the tablet in the room. A ring that reaches its glyph locks with a knock and can no
-- longer turn, so the player always makes progress and never undoes a correct ring.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hash = require(Shared.Util.Hash)
local Anomalies = require(Shared.Config.Anomalies)

local CounterPuzzle = {}

local GLYPHS = #Anomalies.Glyphs
local SALT = 811

export type State = { rings: { number }, solved: boolean }

function CounterPuzzle.solution(seed: number): { number }
	local result = {}
	for ring = 1, Anomalies.Rings do
		result[ring] = 1 + Hash.int(seed, ring, 0, 0, SALT) % GLYPHS
	end
	-- avoid three identical glyphs: the tablet should read as a sequence
	if result[1] == result[2] and result[2] == result[3] then
		result[3] = result[3] % GLYPHS + 1
	end
	return result
end

-- Starting positions: never already on the solution.
function CounterPuzzle.initial(seed: number): State
	local solution = CounterPuzzle.solution(seed)
	local rings = {}
	for ring = 1, Anomalies.Rings do
		local offset = 1 + Hash.int(seed, ring, 1, 0, SALT) % (GLYPHS - 1) -- 1..5
		rings[ring] = (solution[ring] - 1 + offset) % GLYPHS + 1
	end
	return { rings = rings, solved = false }
end

function CounterPuzzle.isLocked(seed: number, state: State, ring: number): boolean
	return state.rings[ring] == CounterPuzzle.solution(seed)[ring]
end

-- Turns one ring a step. Returns (changed, lockedNow, solvedNow).
function CounterPuzzle.rotate(seed: number, state: State, ring: number): (boolean, boolean, boolean)
	if state.solved or ring < 1 or ring > Anomalies.Rings or ring ~= math.floor(ring) then
		return false, false, false
	end
	if CounterPuzzle.isLocked(seed, state, ring) then
		return false, false, false
	end
	state.rings[ring] = state.rings[ring] % GLYPHS + 1
	local lockedNow = CounterPuzzle.isLocked(seed, state, ring)
	local solvedNow = true
	for r = 1, Anomalies.Rings do
		if not CounterPuzzle.isLocked(seed, state, r) then
			solvedNow = false
		end
	end
	if solvedNow then
		state.solved = true
	end
	return true, lockedNow, solvedNow
end

-- Repairs a stored state (wrong length, out-of-range values) without ever un-solving it.
function CounterPuzzle.sanitize(seed: number, stored: any): State
	local fresh = CounterPuzzle.initial(seed)
	if type(stored) ~= "table" then
		return fresh
	end
	if stored.solved == true then
		return { rings = CounterPuzzle.solution(seed), solved = true }
	end
	if type(stored.rings) == "table" then
		for ring = 1, Anomalies.Rings do
			local v = stored.rings[ring]
			if type(v) == "number" and v == math.floor(v) and v >= 1 and v <= GLYPHS then
				fresh.rings[ring] = v
			end
		end
	end
	return fresh
end

return CounterPuzzle
