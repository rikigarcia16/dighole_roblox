--!strict
-- One descent: from leaving the surface to coming back to it (Config/Feats). Pure rules, fed by
-- FeatService with the player's depth every half second and with events (lift, beacon, respawn,
-- geode). Returns the feats a step earns; the caller skips those already owned.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Feats = require(Shared.Config.Feats)

export type State = {
	underground: boolean, -- left the surface since the last reset
	assisted: boolean, -- a lift ride, the beacon or a respawn happened in this descent
	geodes: number,
	deepest: number, -- metres
}

local Descent = {}

-- `assisted`: a descent that did not start on foot from the surface (joining, respawning).
function Descent.new(assisted: boolean): State
	return { underground = false, assisted = assisted, geodes = 0, deepest = 0 }
end

function Descent.assist(state: State)
	state.assisted = true
end

-- A geode opened during this descent.
function Descent.geode(state: State): { string }
	state.geodes += 1
	return if state.geodes >= Feats.Geodes then { "three_geodes" } else {}
end

-- The player is at `depth` metres with the backpack `fill` full (0..1). May reset `state` in place
-- when the player is back at the surface.
function Descent.step(state: State, depth: number, fill: number): { string }
	local earned = {}
	if depth > Feats.SurfaceDepth then
		state.underground = true
		state.deepest = math.max(state.deepest, depth)
		if not state.assisted and depth >= Feats.BareDescentDepth then
			table.insert(earned, "bare_descent")
		end
		return earned
	end
	-- at the surface: a descent ends here
	if state.underground and not state.assisted and state.deepest >= Feats.ClimbDepth and fill >= Feats.ClimbFill then
		table.insert(earned, "unaided_climb")
	end
	state.underground = false
	state.assisted = false
	state.geodes = 0
	state.deepest = 0
	return earned
end

return Descent
