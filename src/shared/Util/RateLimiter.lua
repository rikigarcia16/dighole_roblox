--!strict
-- Token bucket rate limiter keyed by player (or any key).

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: { rate: number, burst: number, buckets: { [any]: { tokens: number, last: number } }, clock: () -> number },
	RateLimiter
))

function RateLimiter.new(rate: number, burst: number, clock: (() -> number)?): RateLimiter
	return setmetatable({ rate = rate, burst = burst, buckets = {}, clock = clock or os.clock }, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, key: any): boolean
	local now = self.clock()
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = self.burst, last = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.burst, bucket.tokens + (now - bucket.last) * self.rate)
	bucket.last = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
