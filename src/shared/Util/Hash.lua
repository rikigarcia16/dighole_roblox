--!strict
-- Deterministic integer hashing used for reproducible world generation.
-- Same seed + same cell always produces the same result on every server.
--
-- Performance matters: generation calls this several times per terrain cell. Luau numbers are
-- doubles, so multiplications are kept below 2^53 (21-bit multipliers on 32-bit values) and stay
-- exact without emulating 64-bit arithmetic. Quality is checked by tests (uniformity and
-- independence between neighbouring cells and between salts).

local Hash = {}

local TWO32 = 4294967296
local M1 = 0x1C69B3 -- odd, < 2^21
local M2 = 0x16A09B -- odd, < 2^21

local bxor, rshift = bit32.bxor, bit32.rshift

local function fmix(h: number): number
	h = bxor(h, rshift(h, 16))
	h = (h * M1) % TWO32
	h = bxor(h, rshift(h, 13))
	h = (h * M2) % TWO32
	h = bxor(h, rshift(h, 16))
	h = (h * M1) % TWO32
	return bxor(h, rshift(h, 15))
end

-- Returns an unsigned 32-bit hash of the seed and coordinates.
function Hash.int(seed: number, x: number, y: number, z: number, salt: number?): number
	local h = bxor(
		seed % TWO32,
		(x * 73856093) % TWO32,
		(y * 19349663) % TWO32,
		(z * 83492791) % TWO32,
		((salt or 0) * 2654435761) % TWO32
	)
	return fmix(fmix(h) + (seed % 65521))
end

-- Returns a float in [0, 1).
function Hash.unit(seed: number, x: number, y: number, z: number, salt: number?): number
	return Hash.int(seed, x, y, z, salt) / TWO32
end

return Hash
