--!strict
-- Resonance detector reading (pure; tested offline): the nearest hidden thing within range, its
-- direction and a rough distance band. The detector never gives exact positions: it gives a
-- direction and "close / medium / far" so the player still has to look.

local Resonance = {}

export type Target = { kind: string, position: Vector3 }
export type Reading = { kind: string, band: string, direction: Vector3, distance: number }

Resonance.Bands = {
	{ upTo = 30, name = "muy cerca" },
	{ upTo = 70, name = "cerca" },
	{ upTo = math.huge, name = "lejos" },
}

function Resonance.read(targets: { Target }, from: Vector3, range: number): Reading?
	local best: Target? = nil
	local bestDistance = math.huge
	for _, target in targets do
		local d = (target.position - from).Magnitude
		if d <= range and d < bestDistance then
			best, bestDistance = target, d
		end
	end
	if not best then
		return nil
	end
	local band = "lejos"
	for _, b in Resonance.Bands do
		if bestDistance <= b.upTo then
			band = b.name
			break
		end
	end
	local delta = best.position - from
	return {
		kind = best.kind,
		band = band,
		direction = if delta.Magnitude > 1e-6 then delta.Unit else Vector3.new(0, -1, 0),
		distance = bestDistance,
	}
end

return Resonance
