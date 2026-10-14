--!strict
local Format = {}

local suffixes = { "", "K", "M", "B", "T", "Qa" }

-- 1234 -> "1,234"; 1234567 -> "1.23M"
function Format.number(n: number): string
	n = math.floor(n)
	if math.abs(n) < 100000 then
		local s = tostring(math.abs(n))
		local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if formatted:sub(1, 1) == "," then
			formatted = formatted:sub(2)
		end
		return (n < 0 and "-" or "") .. formatted
	end
	local tier = 1
	local value = n
	while math.abs(value) >= 1000 and tier < #suffixes do
		value /= 1000
		tier += 1
	end
	return string.format("%.2f%s", value, suffixes[tier])
end

function Format.depth(meters: number): string
	return string.format("%d m", math.floor(meters))
end

return Format
