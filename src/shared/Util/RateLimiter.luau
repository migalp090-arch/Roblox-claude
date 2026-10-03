--!strict
-- Limitador por jugador (cubo de fichas): permite `count` usos cada `per` segundos.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, last: number }

export type RateLimiter = typeof(setmetatable(
	{} :: { _count: number, _per: number, _buckets: { [Player]: Bucket } },
	RateLimiter
))

function RateLimiter.new(count: number, per: number): RateLimiter
	return setmetatable({ _count = count, _per = per, _buckets = {} }, RateLimiter)
end

function RateLimiter.Check(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self._buckets[player]
	if not bucket then
		bucket = { tokens = self._count, last = now }
		self._buckets[player] = bucket
	end

	local refill = (now - bucket.last) * (self._count / self._per)
	bucket.tokens = math.min(self._count, bucket.tokens + refill)
	bucket.last = now

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.Remove(self: RateLimiter, player: Player)
	self._buckets[player] = nil
end

return RateLimiter
