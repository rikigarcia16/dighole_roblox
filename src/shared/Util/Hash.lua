--!strict
-- Deterministic integer hashing used for reproducible ore generation.
-- Same seed + same cell always produces the same result on every server.

local Hash = {}

local TWO32 = 4294967296

-- 32-bit multiply without losing precision in doubles.
local function mul32(a: number, b: number): number
	local aLo = a % 65536
	local aHi = (a - aLo) / 65536
	local bLo = b % 65536
	local bHi = (b - bLo) / 65536
	local cross = (aHi * bLo + aLo * bHi) % 65536
	return (cross * 65536 + aLo * bLo) % TWO32
end

-- murmur3 finaliser
local function fmix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end

local function combine(h: number, v: number): number
	v = math.floor(v) % TWO32
	return fmix((bit32.bxor(h, v) + 0x9E3779B9) % TWO32)
end

-- Returns an unsigned 32-bit hash of the seed and coordinates.
function Hash.int(seed: number, x: number, y: number, z: number, salt: number?): number
	local h = fmix(math.floor(seed) % TWO32)
	h = combine(h, x)
	h = combine(h, y)
	h = combine(h, z)
	h = combine(h, salt or 0)
	return h
end

-- Returns a float in [0, 1).
function Hash.unit(seed: number, x: number, y: number, z: number, salt: number?): number
	return Hash.int(seed, x, y, z, salt) / TWO32
end

return Hash
