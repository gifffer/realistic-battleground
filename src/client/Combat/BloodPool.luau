--!strict
-- BloodPool: blood POOLING on the ground under someone bleeding (client-side).
--
-- What a real pool does, and what this draws:
--   • it GROWS while it is fed (a bleeder standing still or lying down, a
--     torn artery): fast at first, then slower (it spreads thinner);
--   • it is never a disc: a few lobes, a darker thick middle, a thin edge,
--     and a dark ring forms at its edge as it clots (BloodAge);
--   • it FLOWS DOWNHILL: on a slope new lobes go down the slope; on flat
--     ground they go any way;
--   • it STOPS at a curb, a wall, a step up (a ray finds the obstacle) and
--     RUNS OVER a drop (blood running down the side of the curb);
--   • two pools that meet become one (a new feed close to a pool feeds it);
--   • it is WET (shiny) for a while, then dulls, darkens, crusts; its wet
--     film shrinks toward the thick middle, the thin edges (lobes) dry first,
--     and an old one weeps a pale ring of serum around it (BloodStain).
--   • someone dripping into it from above: each drop throws tiny drops
--     around it, and after a dozen drops a "starburst" of dots rings it.
--   • under a body lying on a slope it starts on the LOW side (blood runs
--     out of the body downhill before it pools).
--
--   BloodPool.feed(key, position, area, seconds, maxRadius?)
--       feeds the pool of `key` (a character, an artery...) at `position`:
--       `area` studs² a second, for `seconds` (call again to keep it going)
--   BloodPool.spread(position, size, seconds, seed)   a pool growing to
--       `size` studs across in `seconds` (the finishers' arteries)
--   BloodPool.wetAt(position)  0 (dry ground) → 1 (fresh wet blood): feet
--       stepping in it get bloody (BloodTracks)
--   BloodPool.addWet(record, position, radius)  a big splat counts as wet
--   BloodPool.absorb(position, random?, height?)  is this point in a fresh
--       pool? (a drop falling into it splashes into it instead of making a
--       new stain; with `random`, a drop that fell `height` studs may ring
--       the pool with a starburst of tiny drops)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BloodAge = require(script.Parent.BloodAge)
local BloodStain = require(script.Parent.BloodStain)

local BloodPool = {}

local PALETTE = Config.Blood.PALETTE
local START_RADIUS = 0.22 -- studs: a new pool's first size
local LOBE_EVERY = 0.4 -- seconds between new lobes while it is fed
local MAX_LOBES = 5
local STEP_HEIGHT = 0.1 -- a bump higher than this stops it (curb, step, body)
local LOBE_DRYING = 1.4 -- the thin lobes dry this much faster than the middle
local LOW_SIDE = 0.6 -- studs: a lying body's pool starts this far downhill

type Lobe = {
	record: BloodAge.Record,
	madeAt: number, -- the pool's radius when it was made
}

type Pool = {
	key: any,
	center: Vector3,
	normal: Vector3,
	radius: number,
	area: number,
	maxRadius: number,
	capRadius: number, -- (an edge found: the round part stops there)
	capped: boolean,
	record: BloodAge.Record?,
	lobes: { Lobe },
	blocked: { [number]: boolean }, -- 8 directions around it
	rate: number,
	feedUntil: number,
	nextLobe: number,
	nextEdgeCheck: number,
	random: Random,
	lastAbsorb: number,
	drips: number, -- drops fallen into it
	extras: { BloodAge.Record }, -- (starbursts: they go with the pool)
}

local pools: { Pool } = {}

type Wet = { record: BloodAge.Record, position: Vector3, radius: number }
local wetSpots: { Wet } = {}
local MAX_WET_SPOTS = 64

local UP = Vector3.new(0, 1, 0)

-- The ground under `position` (through bodies and blood).
local function groundUnder(position: Vector3): RaycastResult?
	return workspace:Raycast(position + UP * 1, Vector3.new(0, -14, 0), BloodStain.ground())
end

-- The direction of one of the 8 slots around a pool, on its ground.
local function slotDirection(slot: number, normal: Vector3): Vector3
	local angle = (slot - 1) / 8 * math.pi * 2
	local flat = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local onGround = flat - normal * flat:Dot(normal)
	return if onGround.Magnitude > 1e-3 then onGround.Unit else flat
end

local function slotOf(direction: Vector3): number
	local angle = math.atan2(direction.Z, direction.X)
	return (math.floor(angle / (math.pi * 2) * 8 + 0.5) % 8) + 1
end

-- Can the pool go `direction` from its edge? "flat" (yes), "blocked" (a
-- wall, a step up, nothing under), or "drop" (the ground falls away: it
-- runs over), with the ground point found.
local function probe(pool: Pool, direction: Vector3, distance: number): (string, Vector3?)
	local from = pool.center + pool.normal * 0.05
	local wall = workspace:Raycast(from, direction * distance, BloodStain.ground())
	if wall and math.abs(wall.Normal:Dot(pool.normal)) < 0.5 then
		return "blocked", nil
	end
	local point = pool.center + direction * distance
	local hit =
		workspace:Raycast(point + pool.normal * 0.6, -pool.normal * 1.2, BloodStain.ground())
	if hit == nil then
		return "drop", point
	end
	local height = (hit.Position - pool.center):Dot(pool.normal)
	if height > STEP_HEIGHT then
		return "blocked", nil
	elseif height < -STEP_HEIGHT then
		return "drop", point
	end
	return "flat", hit.Position
end

local function makePool(key: any, hit: RaycastResult, maxRadius: number, random: Random): Pool?
	-- too many pools: the oldest one stops growing (it stays, it ages)
	local cap = BloodAge.cap("POOLS")
	while #pools >= cap do
		-- (its starbursts stay with its record until it ages out)
		table.remove(pools, 1)
	end
	local along = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
	local aspect = random:NextNumber(0.7, 1)
	local record = BloodStain.place(
		"pool",
		hit.Position,
		hit.Normal,
		along,
		START_RADIUS * 2 * aspect,
		START_RADIUS * 2,
		{
			random = random,
			profile = "pool",
			start = PALETTE.VENOUS,
			gloss = 0.75,
			pinned = true,
			noEdge = true,
			material = hit.Material,
			priority = 3,
		}
	)
	if record == nil then
		return nil
	end
	local pool: Pool = {
		key = key,
		center = hit.Position,
		normal = hit.Normal,
		radius = START_RADIUS,
		area = math.pi * START_RADIUS * START_RADIUS,
		maxRadius = maxRadius,
		capRadius = maxRadius,
		capped = false,
		record = record,
		lobes = {},
		blocked = {},
		rate = 0,
		feedUntil = 0,
		nextLobe = os.clock() + LOBE_EVERY,
		nextEdgeCheck = 0,
		random = random,
		lastAbsorb = 0,
		drips = 0,
		extras = {},
	}
	table.insert(pools, pool)
	return pool
end

-- Feeds the pool of `key` at `position`: `area` studs² a second, for
-- `seconds`. A pool already close by (its own or another's) takes it.
function BloodPool.feed(
	key: any,
	position: Vector3,
	area: number,
	seconds: number,
	maxRadius: number?
)
	if not Config.Blood.ENABLED or area <= 0 then
		return
	end
	local hit = groundUnder(position)
	if hit == nil or hit.Material == Enum.Material.Water then
		return
	end
	if typeof(key) == "Instance" and key:IsA("Model") then
		-- a body lying on a slope: the blood leaves it on its low side
		local down = key:GetAttribute("KnockedOut") == true or key:GetAttribute("Ragdolled") == true
		local g = Vector3.new(0, -1, 0)
		local downhill = g - hit.Normal * g:Dot(hit.Normal)
		if down and downhill.Magnitude > 0.05 then
			local low = groundUnder(hit.Position + downhill.Unit * LOW_SIDE)
			if low and low.Material ~= Enum.Material.Water then
				hit = low
			end
		end
	end
	local target: Pool? = nil
	for _, pool in pools do
		local record = pool.record
		if record and not record.dead then
			local gap = hit.Position - pool.center
			if math.abs(gap:Dot(pool.normal)) < 0.6 then
				local reach = pool.radius * 0.7 + 0.3
				if gap.Magnitude < reach and (target == nil or pool.key == key) then
					target = pool
				end
			end
		end
	end
	if target == nil then
		local seed = math.floor(hit.Position.X * 7 + hit.Position.Z * 13)
		target = makePool(key, hit, maxRadius or 1.8, Random.new(seed))
	end
	if target then
		target.rate = math.max(target.rate, area)
		target.feedUntil = math.max(target.feedUntil, os.clock() + seconds)
		target.maxRadius = math.max(target.maxRadius, maxRadius or 1.8)
		if not target.capped then
			target.capRadius = target.maxRadius
		end
	end
end

-- A pool spreading to `size` studs across over `seconds` (same on every
-- client: `seed`).
function BloodPool.spread(position: Vector3, size: number, seconds: number, seed: number)
	local radius = size / 2
	local area = math.pi * radius * radius
	BloodPool.feed({ seed = seed }, position, area / math.max(seconds, 0.2) * 1.4, seconds, radius)
end

-- A lobe of blood pushing out of the pool's edge `direction` (downhill).
local function addLobe(pool: Pool, direction: Vector3, at: Vector3)
	local random = pool.random
	local r = pool.radius
	local record = BloodStain.place(
		"poolLobe",
		at - direction * r * 0.15,
		pool.normal,
		direction,
		r * random:NextNumber(0.5, 0.75),
		r * random:NextNumber(0.6, 0.9),
		{
			random = random,
			profile = "pool",
			start = PALETTE.VENOUS,
			pinned = true,
			noEdge = true,
			priority = 3,
		}
	)
	if record then
		-- (a lobe is the thin edge of a pool: it dries first)
		record.speed *= LOBE_DRYING
		table.insert(pool.lobes, { record = record, madeAt = r })
	end
end

-- Which way does it flow: down the slope, or (flat) a free side.
local function flowDirection(pool: Pool): (Vector3?, number)
	local g = Vector3.new(0, -1, 0)
	local downhill = g - pool.normal * g:Dot(pool.normal)
	if downhill.Magnitude > 0.05 then
		local slot = slotOf(downhill.Unit)
		if not pool.blocked[slot] then
			return downhill.Unit, slot
		end
		-- (blocked downhill: along the obstacle, either side)
		for _, turn in { 1, -1, 2, -2 } do
			local other = ((slot - 1 + turn) % 8) + 1
			if not pool.blocked[other] then
				return slotDirection(other, pool.normal), other
			end
		end
		return nil, 0
	end
	for _ = 1, 4 do
		local slot = pool.random:NextInteger(1, 8)
		if not pool.blocked[slot] then
			return slotDirection(slot, pool.normal), slot
		end
	end
	return nil, 0
end

local function grow(pool: Pool, dt: number, now: number)
	local record = pool.record
	if record == nil or record.dead then
		return
	end
	pool.area += pool.rate * dt
	-- (spreading thinner and thinner: fast at first, slower after)
	local plain = math.sqrt(pool.area / math.pi)
	local R = pool.maxRadius
	local radius = math.min(pool.capRadius, R * (1 - math.exp(-plain / R)))
	radius = math.max(radius, pool.radius)
	BloodAge.touch(record)
	-- its edge: ledges / walls in the 8 directions (the round part stops there)
	if now >= pool.nextEdgeCheck then
		pool.nextEdgeCheck = now + 0.5
		for slot = 1, 8 do
			if not pool.blocked[slot] then
				local direction = slotDirection(slot, pool.normal)
				local result, point = probe(pool, direction, radius * 1.05 + 0.05)
				if result ~= "flat" then
					pool.blocked[slot] = true
					pool.capped = true
					pool.capRadius = math.min(pool.capRadius, math.max(pool.radius, radius * 0.95))
					if result == "drop" and point then
						-- over the edge: it runs down the side
						BloodStain.overLedge(point, direction, math.min(0.14, radius * 0.25))
					end
				end
			end
		end
		radius = math.min(radius, pool.capRadius)
	end
	if radius > pool.radius + 0.005 then
		pool.radius = radius
		local k = radius / START_RADIUS
		BloodStain.rescale(record, k, k)
		for _, lobe in pool.lobes do
			if not lobe.record.dead then
				local kl = math.min(1.6, radius / lobe.madeAt)
				BloodStain.rescale(lobe.record, kl, kl)
				BloodAge.touch(lobe.record)
			end
		end
	end
	-- the overflow: a new lobe out of its edge, downhill
	if now >= pool.nextLobe and #pool.lobes < MAX_LOBES and pool.radius > 0.3 then
		pool.nextLobe = now + LOBE_EVERY * pool.random:NextNumber(0.8, 1.5)
		local direction, slot = flowDirection(pool)
		if direction then
			local result, point = probe(pool, direction, pool.radius * 1.1)
			if result == "flat" and point then
				addLobe(pool, direction, point)
			else
				pool.blocked[slot] = true
				if result == "drop" and point then
					BloodStain.overLedge(point, direction, math.min(0.14, pool.radius * 0.25))
				end
			end
		end
	end
end

-- Is `position` in fresh blood? 0 (no) → 1 (just spilled).
function BloodPool.wetAt(position: Vector3): number
	local best = 0
	for _, pool in pools do
		local record = pool.record
		if record and not record.dead then
			local gap = position - pool.center
			local flat = gap - pool.normal * gap:Dot(pool.normal)
			if math.abs(gap:Dot(pool.normal)) < 1 and flat.Magnitude < pool.radius * 1.1 + 0.15 then
				best = math.max(best, BloodAge.wetness(record))
			end
		end
	end
	for _, spot in wetSpots do
		if not spot.record.dead then
			local gap = position - spot.position
			if math.abs(gap.Y) < 1 and Vector3.new(gap.X, 0, gap.Z).Magnitude < spot.radius then
				best = math.max(best, BloodAge.wetness(spot.record) * 0.8)
			end
		end
	end
	return best
end

-- A big splat on the floor: wet enough to step in.
function BloodPool.addWet(record: BloodAge.Record, position: Vector3, radius: number)
	table.insert(wetSpots, { record = record, position = position, radius = radius })
	if #wetSpots > MAX_WET_SPOTS then
		table.remove(wetSpots, 1)
	end
end

-- Drop after drop into the same pool: the tiny drops each one throws pile up
-- around it into a ring of dots (a "starburst"), one picture every 3 drops
-- or so, at most WORLD.STARBURSTS_PER_POOL. They go with the pool.
local function starburst(pool: Pool, position: Vector3, height: number, random: Random)
	pool.drips += 1
	if
		#pool.extras >= Config.Blood.WORLD.STARBURSTS_PER_POOL
		or pool.drips < 3
		or pool.random:NextNumber() > 0.34
	then
		return
	end
	-- (higher falls throw them further; never wider than a few studs)
	local across = math.min(pool.radius * 2 * random:NextNumber(1.5, 2.5) * math.clamp(0.6 + height * 0.1, 0.6, 1.2), 3.5)
	if BloodStain.resolve("starburst") ~= "starburst" then
		across = math.min(across, 1.2) -- (its stand-in, a fan of dots: smaller)
	end
	local a = random:NextNumber(0, math.pi * 2)
	local record = BloodStain.place(
		"starburst",
		position,
		pool.normal,
		Vector3.new(math.cos(a), 0, math.sin(a)),
		across,
		across,
		{
			random = random,
			profile = "pool",
			start = PALETTE.ARTERIAL_LIGHT,
			alpha = 0.2,
			pinned = true,
			noEdge = true,
			priority = 1,
		}
	)
	if record then
		table.insert(pool.extras, record)
	end
end

-- A drop falling at `position`: into a fresh pool? Then it splashes into it
-- (true: the caller draws a small drip-into-drip splash at most every 0.5 s,
-- `splash` true) and feeds it a little. With `random` (a real drop, not a
-- splash's tiny one): it counts toward the pool's starburst.
function BloodPool.absorb(position: Vector3, random: Random?, height: number?): (boolean, boolean)
	local now = os.clock()
	for _, pool in pools do
		local record = pool.record
		if record and not record.dead then
			local gap = position - pool.center
			local flat = gap - pool.normal * gap:Dot(pool.normal)
			if math.abs(gap:Dot(pool.normal)) < 0.4 and flat.Magnitude < pool.radius * 0.85 then
				if BloodAge.wetness(record) < 0.3 then
					return false, false -- (dry: a fresh drop shows on top)
				end
				pool.area += 0.01
				BloodAge.touch(record)
				if random then
					starburst(pool, position, height or 1, random)
				end
				local splash = now - pool.lastAbsorb > 0.5
				if splash then
					pool.lastAbsorb = now
				end
				return true, splash
			end
		end
	end
	return false, false
end

-- A pool gone (aged out, evicted): its starbursts go with it.
local function dropExtras(pool: Pool)
	for _, extra in pool.extras do
		if not extra.dead then
			BloodAge.remove(extra)
		end
	end
	table.clear(pool.extras)
end

local accumulated = 0
RunService.Heartbeat:Connect(function(dt: number)
	accumulated += dt
	if accumulated < 0.1 then
		return -- (10 times a second is plenty for a pool)
	end
	debug.profilebegin("BloodPool")
	local step = accumulated
	accumulated = 0
	local now = os.clock()
	local index = 1
	while index <= #pools do
		local pool = pools[index]
		local record = pool.record
		if record == nil or record.dead then
			dropExtras(pool)
			table.remove(pools, index)
			continue
		end
		if now < pool.feedUntil then
			grow(pool, step, now)
		end
		index += 1
	end
	debug.profileend()
end)

return table.freeze(BloodPool)
