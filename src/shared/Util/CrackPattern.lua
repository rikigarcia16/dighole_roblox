--!strict
-- Cracks on a damaged cell (drawn only on the client, DigController): a few thin lines radiating
-- from the last hit point, more and longer as the cell weakens. Pure and deterministic per cell, so
-- the pattern grows hit after hit instead of reshuffling, and it can be tested offline.

local Hash = require(script.Parent.Hash)

local CrackPattern = {}

CrackPattern.MaxLines = 7

export type Line = {
	angle: number, -- radians, in the plane of the surface
	length: number, -- studs
	start: number, -- studs from the hit point where the line begins
}

function CrackPattern.count(fraction: number): number
	if fraction ~= fraction or fraction <= 0 then
		return 0
	end
	return math.clamp(math.ceil(math.min(fraction, 1) * CrackPattern.MaxLines), 1, CrackPattern.MaxLines)
end

-- `seed` identifies the cell (any integer); `fraction` is the damage 0..1.
function CrackPattern.lines(seed: number, fraction: number): { Line }
	local count = CrackPattern.count(fraction)
	local grow = 0.55 + 0.45 * math.clamp(fraction, 0, 1)
	local lines = table.create(count)
	for i = 1, count do
		local spread = Hash.unit(seed, i, 0, 0, 11)
		local reach = Hash.unit(seed, i, 0, 0, 12)
		local offset = Hash.unit(seed, i, 0, 0, 13)
		lines[i] = {
			angle = (i - 1) * (2 * math.pi / CrackPattern.MaxLines) + (spread - 0.5) * 0.7,
			length = (0.7 + 1.1 * reach) * grow,
			start = 0.05 + 0.2 * offset,
		}
	end
	return lines
end

return CrackPattern
