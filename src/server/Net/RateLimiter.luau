--!strict
-- RateLimiter (NETWORKING section 3.1): every remote has a rate limit, so a
-- client cannot flood the server. A sliding window per sender: the sends
-- inside the last period are counted, and the oldest ones fall out of it.
--
-- The clock is injected so the limiter can be driven deterministically in a
-- test and runs on the server's clock in the game.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_limit: number,
		_period: number,
		_hits: { [string]: { number } },
		_clock: () -> number,
	},
	RateLimiter
))

function RateLimiter.new(limit: number, periodSeconds: number, clock: () -> number): RateLimiter
	return setmetatable({
		_limit = limit,
		_period = periodSeconds,
		_hits = {},
		_clock = clock,
	}, RateLimiter)
end

-- True when the sender may send again; false when it is over the limit.
function RateLimiter.allow(self: RateLimiter, key: string): boolean
	local now = self._clock()
	local kept: { number } = {}
	local hits: { number } = self._hits[key] or {}
	for _, stamp in hits do
		if now - stamp < self._period then
			table.insert(kept, stamp)
		end
	end
	if #kept >= self._limit then
		self._hits[key] = kept
		return false
	end
	table.insert(kept, now)
	self._hits[key] = kept
	return true
end

-- Forgets what a sender did (a client that leaves does not keep its slot).
function RateLimiter.forget(self: RateLimiter, key: string)
	self._hits[key] = nil
end

return RateLimiter
