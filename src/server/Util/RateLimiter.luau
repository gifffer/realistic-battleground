--!strict
-- Per-player rate limiter ("token bucket") for remote handlers.
--
-- Each player has a bucket of `capacity` tokens. Every call costs 1 token;
-- tokens refill at `refillPerSecond`. When the bucket is empty, calls are
-- refused. Normal players never notice; a hacked client spamming a remote
-- 1000 times per second gets ignored instead of lagging the server.
--
--   local limiter = RateLimiter.new(5, 1) -- burst of 5, then 1 per second
--   if not limiter.allow(player) then return end

local Players = game:GetService("Players")

export type RateLimiter = {
	allow: (player: Player) -> boolean,
}

type Bucket = { tokens: number, updatedAt: number }

local RateLimiter = {}

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	local buckets: { [Player]: Bucket } = {}

	-- Forget players who left (otherwise the table keeps growing).
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)

	local function allow(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if bucket == nil then
			bucket = { tokens = capacity, updatedAt = now }
			buckets[player] = bucket
		end

		bucket.tokens =
			math.min(capacity, bucket.tokens + (now - bucket.updatedAt) * refillPerSecond)
		bucket.updatedAt = now

		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end

	return { allow = allow }
end

return table.freeze(RateLimiter)
