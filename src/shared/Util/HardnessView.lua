--!strict
-- What the hardness indicator shows for the aimed cell: pure, so it is unit-tested.
--
-- `progress` is the damage fraction the server reported for that cell (0 when unknown).

local DigFeel = require(script.Parent.Parent.Config.DigFeel)

export type View = {
	locked: boolean, -- the tool cannot damage this material at all
	requiredPower: number,
	totalHits: number, -- hits a fresh cell needs with this tool
	hitsLeft: number,
	fraction: number, -- 0..1 damage already done
	segments: number, -- segments to draw (capped)
	filled: number, -- segments already broken
	label: string,
}

local HardnessView = {}

function HardnessView.compute(
	resource: { hardness: number, requiredPower: number, name: string },
	toolPower: number,
	progress: number?
): View
	local fraction = math.clamp(progress or 0, 0, 1)
	if toolPower < resource.requiredPower then
		return {
			locked = true,
			requiredPower = resource.requiredPower,
			totalHits = math.huge,
			hitsLeft = math.huge,
			fraction = 0,
			segments = 0,
			filled = 0,
			label = string.format("%s · necesitas potencia %d", resource.name, resource.requiredPower),
		}
	end
	local totalHits = DigFeel.hitsLeft(resource.hardness, toolPower, 0)
	local damage = fraction * resource.hardness
	local hitsLeft = DigFeel.hitsLeft(resource.hardness, toolPower, damage)
	local segments = math.min(totalHits, DigFeel.MaxHardnessSegments)
	local filled = if totalHits <= DigFeel.MaxHardnessSegments
		then totalHits - hitsLeft
		else math.floor(fraction * segments + 1e-6)
	local label = if hitsLeft <= 1 then resource.name else string.format("%s · %d golpes", resource.name, hitsLeft)
	return {
		locked = false,
		requiredPower = resource.requiredPower,
		totalHits = totalHits,
		hitsLeft = hitsLeft,
		fraction = fraction,
		segments = segments,
		filled = filled,
		label = label,
	}
end

return HardnessView
