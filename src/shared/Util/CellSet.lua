--!strict
-- Compact persistence for a set of integer cell keys using run-length encoding.
-- Encoded form: { start1, length1, start2, length2, ... } with starts delta-encoded.

local CellSet = {}

function CellSet.encode(set: { [number]: boolean }): { number }
	local keys = {}
	for key in set do
		table.insert(keys, key)
	end
	table.sort(keys)
	local out = {}
	local i = 1
	local previousEnd = 0
	while i <= #keys do
		local start = keys[i]
		local length = 1
		while keys[i + length] == start + length do
			length += 1
		end
		table.insert(out, start - previousEnd)
		table.insert(out, length)
		previousEnd = start + length
		i += length
	end
	return out
end

CellSet.MaxKey = 2 ^ 40 -- far above any Grid.key
CellSet.MaxRun = 1000000 -- longest run of consecutive cells accepted when decoding

function CellSet.decode(encoded: { number }?): { [number]: boolean }
	local set = {}
	if type(encoded) ~= "table" then
		return set
	end
	local cursor = 0
	for i = 1, #encoded - 1, 2 do
		local gap, length = encoded[i], encoded[i + 1]
		if type(gap) ~= "number" or type(length) ~= "number" then
			break
		end
		local start = cursor + gap
		-- a corrupted save must never make this loop run forever (inf / NaN / absurd runs)
		if start ~= start or math.abs(start) > CellSet.MaxKey or not (length >= 1 and length <= CellSet.MaxRun) then
			break
		end
		for key = start, start + length - 1 do
			set[key] = true
		end
		cursor = start + length
	end
	return set
end

return CellSet
