--!strict
-- BloodPool: blood POOLING on the ground under someone bleeding (client-side).
--
-- A pool is ONE puddle of blood: one picture (pool_1..3, its clotting ring
-- and its pale serum ring on top of it) that grows from the middle (a
-- bleeder's small pool also gets a faint wet shiny film in its middle). No
-- separate blobs: the whole pool is one shape, one colour, and it ages all
-- at once. What it does:
--   • it SPREADS: it starts tiny (0.3 stud) where the blood lands and its
--     edge moves outward while blood pours in, fast at first, then slower
--     and slower, and it keeps CREEPING a little after the wound stops (thick
--     blood spreads slowly). It never jumps: its size always eases toward
--     where the blood poured so far would reach;
--   • it FLOWS DOWNHILL: on a slope its middle slides a little down the slope
--     and it stretches that way (still one shape), and on a real slope one
--     short run of blood leaves it downhill (joined to it: it starts under it);
--   • it STOPS at a curb, a wall, a step up: rays all around check the ground
--     ahead of its edge; the pool is pushed away from what stops it (it
--     spreads on its free side) and stays smaller if it still doesn't fit -
--     never through a wall, never hanging over a ledge;
--   • it RUNS OVER a ledge (blood running down the side of the curb);
--   • two pools that meet become ONE: the bigger one takes the other's blood
--     (it grows over it and moves toward the middle of both), the other one
--     shrinks under it and goes once it is hidden;
--   • it is WET (shiny) for a while, then dulls, darkens, crusts, its dark
--     clotting ring shows at its edge, and an old pool weeps a pale ring of
--     serum around it (BloodStain / BloodAge);
--   • someone dripping into it from above: each drop throws tiny drops
--     around it, and after a dozen drops a "starburst" of dots rings it;
--   • under a body lying on a slope it starts on the LOW side (blood runs
--     out of the body downhill before it pools).
--
-- Everything random about a pool (its picture, its turn as it grows) is
-- picked from its seed when it is made, and the ground is checked at fixed
-- distances: the same pool on every client.
--
--   BloodPool.feed(key, position, area, seconds, maxRadius?)
--       feeds the pool of `key` (a character, an artery...) at `position`:
--       `area` studs² a second, for `seconds` (call again to keep it going)
--   BloodPool.spread(position, size, seconds, seed)   a pool growing to
--       `size` studs across in `seconds` (the finishers' arteries)
--   BloodPool.pour(key, hit, area, maxRadius, seed, spreadTime?)   `area`
--       studs² of blood poured at once on the ground `hit` (a finisher's
--       stump bleeding, BloodGush.stump): a BIG pool that spreads for
--       `spreadTime` seconds, kept before the small ones when there are too
--       many, the same shape on every client (`seed`)
--   BloodPool.claim(seed)   true the first time a finisher pool's `seed` is
--       asked for (a body seen again, its frozen copy: no second pool)
--   BloodPool.lay(position, size, seed)   a finisher's pool already there
--       (a body we only see after the finisher): fully spread at once
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
local FINISHER_POOLS = Config.Blood.FINISHER_POOLS
local START_RADIUS = 0.3 -- studs: a new pool's first size
local STEP_HEIGHT = 0.1 -- a bump higher than this stops it (curb, step)
local WALL_HEIGHT = 0.08 -- (the "wall" ray: this high above the ground)
local UNEVEN = 0.4 -- studs: the ground this far ABOVE the pool's plane stops it
-- (and this far BELOW it: the picture is flat, on the pool's plane - a pool
-- going on over ground falling away would float above it)
local DIP = 0.15
local PROBE_STEP = 0.35 -- studs: a ray checks the ground ahead this often
local GROW_TIME = 0.9 -- seconds: the edge eases toward where the blood reaches (no jump)
local MAX_SPEED = 1.6 -- studs/s: the edge never moves faster
-- A finisher's pool, while its wound still pours, is this much (of its size
-- then) behind where its blood would reach; it catches up as it creeps on.
local CREEP_SHARE = 0.3
local LOW_SIDE = 0.6 -- studs: a lying body's pool starts this far downhill
-- On a slope: the full effect from this slope on (the sine of its angle:
-- 0.2 ≈ 11.5°), the middle sliding this × its radius downhill, the pool
-- stretched this much down the slope (1 + this: its length / its width²)...
local SLOPE_FULL = 0.2
local SLOPE_DRIFT = 0.35
local SLOPE_STRETCH = 0.8
-- ...and from this much of the full effect on (≈ 3.5°), a short run of blood
-- leaves a finisher's pool downhill: up to this × the pool's radius beyond
-- its edge, this fast (studs/s), once the pool is this × its full size.
local RUN_FROM = 0.3
local RUN_REACH = 0.6
local RUN_SPEED = 0.2
local RUN_START = 0.5
local MERGE_OVERLAP = 0.85 -- two pools closer than this × (r1 + r2) become one
-- (the one taken in hides under the other: gone once its blob is inside this
-- × the other's radius - a pool picture's blob is not round)
local COVERED = 0.8
-- The wet shiny film on a bleeder's small pool: this × the blob across, this
-- transparent (at most: 1 = invisible). Small and faint, so it stays a sheen
-- ON the pool. A finisher's big pool has none: the film is a hard-edged
-- shiny disc, and on a big pool it showed as a second, lighter blob in it -
-- the big pool is ONE uniform puddle (it still looks wet: it is fresh red,
-- then darkens as it dries, BloodAge).
local GLOSS_SIZE = 0.5
local GLOSS_ALPHA = 0.7
-- seconds a finisher pool's seed stays claimed: as long as the body (or its
-- frozen copy) can still be seen, a little more
local CLAIM_TIME = Config.Knockout.FINISHER_BODY_TIME + 5

-- The pictures are not filled to their edges (measured on assets/blood):
-- pool_1..3: the blood is a blob about this fraction of the picture across
-- (area-equivalent), its middle shifted this much (× the picture) along it;
-- pool_lobe (the run downhill): the blob goes from -0.48 to +0.25 of its
-- length (its rounded tip at +X, the way it flows) and 0.4 of its width.
-- Without pictures the plain shapes fill the whole size.
local POOL_COVER = { 0.465, 0.39, 0.42 }
local POOL_SHIFT = { -0.01, -0.06, -0.07 }
-- (and its blob is not round: its longest side, × that diameter)
local POOL_EXTENT = { 1.33, 1.08, 1.26 }
local LOBE_FROM, LOBE_TO, LOBE_WIDE = -0.48, 0.25, 0.4
local _, lobeImage = BloodStain.resolve("poolLobe")
local LOBE_PICTURE = lobeImage ~= 0

-- How a kind of pool spreads.
type Spec = {
	rays: number, -- rays checking the ground all around it (High quality)
	visible: number, -- its full size: this × the radius it is given
	tail: number, -- seconds it keeps moving after the last feed
}

-- A finisher's big pool (a torn limb, a burst head, a body cut in two).
-- What it costs: one picture (with its clotting ring and serum ring), maybe
-- one run downhill: 2-3 instances. Its rays are only
-- raycasts, a few per update while it grows, 10 updates a second.
local BIG: Spec = { rays = 12, visible = 1, tail = 2 }

-- A bleeder's pool (a fighter bleeding where he stands, a spurt landing).
local SMALL: Spec = { rays = 8, visible = 0.65, tail = 3 }

-- A ray from the pool's middle checking the ground ahead of its edge.
type Ray = {
	dir: Vector3,
	probed: number, -- the ground checked up to here
	lastH: number, -- (the ground's height there, off the pool's plane)
	stop: number?, -- something stops it there
	stopKind: string?, -- "wall", "step", "drop", "uneven"
	ran: boolean, -- (blood ran over its ledge)
}

-- The short run of blood leaving a pool downhill (a stretched pool_lobe
-- picture, joined to the pool: it starts under it).
type Run = {
	ray: Ray,
	record: BloodAge.Record?,
	l0: number, -- (its picture's size when made: rescaled from there)
	w0: number,
	length: number, -- studs beyond the pool's edge
	reach: number, -- (at most)
	drawn: number,
}

type Pool = {
	key: any,
	center: Vector3, -- where its blood landed (its rays start here)
	normal: Vector3,
	forward: Vector3, -- (its picture's direction when made)
	twist: number, -- (radians: its picture turns this much as it grows - an uneven spread)
	slopeDir: Vector3, -- (down the slope, a unit vector; zero if flat)
	slope: number, -- 0 flat → 1 a real slope (SLOPE_FULL)
	stretch: number, -- (its length / its width², down the slope)
	radius: number, -- its edge (area-equivalent radius, studs) as drawn now
	target: number, -- (where its edge is going)
	full: number, -- its full size (radius)
	area: number, -- studs² poured into it
	fedArea: number, -- (the area when last drawn: more since = fed, wet again)
	maxRadius: number,
	rate: number,
	feedUntil: number,
	born: number,
	spreadTime: number, -- (a big one: seconds from its first blood to fully spread)
	sources: { [any]: boolean },
	record: BloodAge.Record?,
	cover: number,
	shift: number,
	extent: number,
	offset: Vector3, -- (its middle: slid downhill, pushed away from a wall close by)
	drawnR: number, -- (as drawn last: redrawn only when it changed)
	drawnAt: Vector3,
	core0: number, -- (its picture's size when made)
	rays: { Ray },
	run: Run?,
	into: Pool?, -- (taken in by this bigger pool: it shrinks under it, then goes)
	layer: number,
	random: Random,
	lastAbsorb: number,
	drips: number, -- drops fallen into it
	extras: { BloodAge.Record }, -- (starbursts: they go with the pool)
	-- 1 a bleeder's pool, 2 a finisher's (kept first when there are too many)
	priority: number,
	life: number?, -- (a finisher's: its own lifetime, s)
	spec: Spec,
}

local pools: { Pool } = {}

type Wet = { record: BloodAge.Record, position: Vector3, radius: number }
local wetSpots: { Wet } = {}
local MAX_WET_SPOTS = 64

local UP = Vector3.new(0, 1, 0)
local DOWN = Vector3.new(0, -1, 0)

-- The ground under `position` (through bodies and blood).
local function groundUnder(position: Vector3): RaycastResult?
	return workspace:Raycast(position + UP * 1, Vector3.new(0, -14, 0), BloodStain.ground())
end

-- A ray for the pool's checks: it goes through loose things (unanchored: a
-- torn arm, a dropped organ, a body part, debris) - blood runs under them -
-- but not through the map (walls, curbs, floors are anchored).
local function cast(from: Vector3, direction: Vector3): RaycastResult?
	local params = BloodStain.ground()
	local start, left = from, direction
	for _ = 1, 4 do
		local hit = workspace:Raycast(start, left, params)
		if hit == nil then
			return nil
		end
		local part = hit.Instance
		if not part:IsA("BasePart") or part.Anchored or part:IsA("Terrain") then
			return hit
		end
		-- (a loose thing: on through it)
		local gone = (hit.Position - start):Dot(left.Unit) + 0.02
		if gone >= left.Magnitude then
			return nil
		end
		start += left.Unit * gone
		left = left.Unit * (left.Magnitude - gone)
	end
	return nil
end

-- The ground's height at `point`, off the plane through `origin` (nil: none).
local function heightAt(origin: Vector3, normal: Vector3, point: Vector3): number?
	local hit = cast(point + normal * 0.6, -normal * 1.2)
	if hit == nil then
		return nil
	end
	return (hit.Position - origin):Dot(normal)
end

-- Can blood go from `from` to `to` studs along `dir` (from `origin`, on its
-- plane `normal`, the ground at `lastH` there)? Returns what is there:
--   "flat" (yes: the ground's height at `to`),
--   "wall" (something stands in the way), "step" (a curb, a step up),
--   "uneven" (the ground leaves the pool's plane: rises, or falls away
--   little by little - a bump, a curved floor), or "drop" (a ledge),
-- and the distance where it stops. A crack between two floor parts is not
-- a drop (the ground goes on just after it).
local function probe(
	origin: Vector3,
	normal: Vector3,
	dir: Vector3,
	from: number,
	to: number,
	lastH: number
): (string, number, number)
	local start = origin + dir * from + normal * (lastH + WALL_HEIGHT)
	local wall = cast(start, dir * (to - from + 0.05))
	if wall and math.abs(wall.Normal:Dot(normal)) < 0.5 then
		-- (it goes a hair under the wall: no gap at its foot)
		return "wall", from + (wall.Position - start):Dot(dir) + 0.05, lastH
	end
	local point = origin + dir * to
	local h = heightAt(origin, normal, point)
	if h then
		if h - lastH > STEP_HEIGHT then
			return "step", to, lastH
		elseif lastH - h <= STEP_HEIGHT then
			if h > UNEVEN or h < -DIP then
				return "uneven", from, lastH
			end
			return "flat", to, h
		end
	end
	-- no ground there, or lower: a crack? (the ground goes on just after)
	for _, gap in { 0.2, 0.4 } do
		local after = heightAt(origin, normal, point + dir * gap)
		if after and math.abs(after - lastH) <= STEP_HEIGHT then
			return "flat", to, lastH
		end
	end
	return "drop", from, lastH
end

-- A ray checks the ground ahead, a step at a time, up to `upTo` studs from
-- the pool's middle.
local function probeRay(pool: Pool, ray: Ray, upTo: number)
	while ray.stop == nil and ray.probed < upTo do
		local to = ray.probed + PROBE_STEP
		local kind, at, h = probe(pool.center, pool.normal, ray.dir, ray.probed, to, ray.lastH)
		if kind == "flat" then
			ray.probed, ray.lastH = to, h
		else
			ray.stop, ray.stopKind = math.max(at, 0), kind
		end
	end
end

local function newRay(dir: Vector3): Ray
	return { dir = dir, probed = 0, lastH = 0, stop = nil, stopKind = nil, ran = false }
end

-- How far the pool's blob reaches going `dir` from its middle, its radius
-- being `r` (its longest side all around, stretched down a slope).
local function reachIn(pool: Pool, dir: Vector3, r: number): number
	local k = 1
	if pool.stretch > 1 then
		local along = math.sqrt(pool.stretch)
		local c = dir:Dot(pool.slopeDir)
		local s2 = math.max(0, 1 - c * c)
		k = 1 / math.sqrt(c * c / (along * along) + s2 * along * along)
	end
	return r * pool.extent * k
end

-- How many rays check the ground around it: fewer at a lower quality.
local function rayCount(spec: Spec): number
	local scale = BloodAge.scale()
	local k = if scale >= 1 then 1 elseif scale >= 0.7 then 0.8 else 0.6
	return math.max(6, math.floor(spec.rays * k + 0.5))
end

-- The height (0-11 above the ground) of a new pool's picture: below the
-- pools of its kind already close by (one taken in by another hides UNDER
-- it; two at the same height would flicker where they overlap).
local function layerFor(position: Vector3, radius: number, big: boolean, look: number): number
	-- (a finisher's pool: 9-11; a bleeder's: 5-7, under a finisher's)
	local layer = if big then 11 else 7 - look % 2
	for _ = 1, 3 do
		local taken = false
		for _, pool in pools do
			local record = pool.record
			if
				record
				and not record.dead
				and pool.layer == layer
				and (pool.center - position).Magnitude < (pool.full + radius) * 1.3
			then
				taken = true
				break
			end
		end
		if not taken then
			break
		end
		layer -= 1
	end
	return layer
end

local function makePool(
	key: any,
	hit: RaycastResult,
	maxRadius: number,
	random: Random,
	priority: number?
): Pool?
	local rank = priority or 1
	local big = rank >= 2
	local life = if big then FINISHER_POOLS.LIFE else nil
	local spec = if big then BIG else SMALL
	-- too many pools: the oldest one stops growing (it stays, it ages). A
	-- bleeder's small pool goes before a finisher's big one; a small new
	-- pool never stops a finisher's from growing (it just isn't made).
	local cap = BloodAge.cap("POOLS")
	while #pools >= cap do
		local oldest: number? = nil
		local now = os.clock()
		for index, pool in pools do
			-- (a finisher's pool still pouring is never stopped: else the
			-- next pour would make a new one on top of it, again and again)
			local pouring = pool.priority >= 2 and now < pool.feedUntil
			if
				pool.priority <= rank
				and not pouring
				and pool.into == nil
				and (oldest == nil or pool.priority < pools[oldest].priority)
			then
				oldest = index
			end
		end
		if oldest == nil then
			return nil
		end
		-- (its starbursts stay with its record until it ages out)
		table.remove(pools, oldest)
	end
	local normal = hit.Normal
	-- down the slope (its length: the sine of the slope's angle; 0 flat)
	local downhill = DOWN - normal * DOWN:Dot(normal)
	local slope = math.clamp(downhill.Magnitude / SLOPE_FULL, 0, 1)
	local slopeDir = if downhill.Magnitude > 0.01 then downhill.Unit else Vector3.zero
	local forward: Vector3
	if slope > 0.15 then
		-- (on a slope: its picture's long side down the slope)
		forward = slopeDir
	else
		local along = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
		forward = along - normal * along:Dot(normal)
		forward = if forward.Magnitude > 1e-3
			then forward.Unit
			else normal:Cross(Vector3.new(1, 0, 0)).Unit
	end
	local twist = if slope > 0.15 then 0 else random:NextNumber(-0.3, 0.3)
	local aspect = random:NextNumber(0.88, 1)
	local index = random:NextInteger(1, #POOL_COVER)
	local look = random:NextInteger(0, 9999)
	local picture = BloodStain.image("pool", nil, index) ~= 0
	local cover = if picture then POOL_COVER[index] else 1
	local size0 = START_RADIUS * 2 / cover
	local layer = layerFor(hit.Position, maxRadius * spec.visible, big, look)
	local record = BloodStain.place("pool", hit.Position, normal, forward, size0 * aspect, size0, {
		random = random,
		profile = "pool",
		start = PALETTE.VENOUS,
		-- (the wet film, a small pool only: over the thick middle of the blob -
		-- not over the empty picture around it, and well inside its edge)
		gloss = if big then nil else cover * GLOSS_SIZE,
		pinned = true,
		noEdge = true,
		material = hit.Material,
		priority = 3,
		life = life,
		index = index,
		layer = layer,
	})
	if record == nil then
		return nil
	end
	-- (a faint film: the pool reads as ONE puddle, the film only a wet sheen on it)
	if record.gloss then
		record.glossAlpha = GLOSS_ALPHA
		BloodAge.paint(record)
	end
	-- (its wet film over the blob's middle, not the picture's: the blob is
	-- not in the middle of its picture - else the film would stick out of it)
	local shape = BloodStain.shapeOf(record)
	local shift = if picture then POOL_SHIFT[index] else 0
	if shape then
		for _, piece in shape.pieces do
			if piece.inst == record.gloss then
				piece.cx = shift * size0
			end
		end
	end
	local pool: Pool = {
		key = key,
		center = hit.Position,
		normal = normal,
		forward = forward,
		twist = twist,
		slopeDir = slopeDir,
		slope = slope,
		stretch = 1 + SLOPE_STRETCH * slope,
		radius = START_RADIUS,
		target = START_RADIUS,
		full = maxRadius * spec.visible,
		area = 0,
		fedArea = 0,
		maxRadius = maxRadius,
		rate = 0,
		feedUntil = 0,
		born = os.clock(),
		spreadTime = 0,
		sources = { [key] = true },
		record = record,
		cover = cover,
		shift = shift,
		extent = if picture then POOL_EXTENT[index] else 1.06,
		offset = Vector3.zero,
		drawnR = START_RADIUS,
		drawnAt = Vector3.zero,
		core0 = size0,
		rays = {},
		run = nil,
		into = nil,
		layer = layer,
		random = random,
		lastAbsorb = 0,
		drips = 0,
		extras = {},
		priority = rank,
		life = life,
		spec = spec,
	}
	-- its rays all around (evenly spaced, turned by its seed)
	local count = rayCount(spec)
	local turn = random:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local angle = turn + (i - 1) / count * math.pi * 2
		local flat = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local dir = flat - normal * flat:Dot(normal)
		table.insert(pool.rays, newRay(if dir.Magnitude > 1e-3 then dir.Unit else forward))
	end
	-- a finisher's pool on a real slope: its run downhill
	if big and slope >= RUN_FROM then
		pool.run = {
			ray = newRay(slopeDir),
			record = nil,
			l0 = 1,
			w0 = 1,
			length = 0,
			reach = maxRadius * RUN_REACH * slope,
			drawn = 0,
		}
	end
	table.insert(pools, pool)
	return pool
end

-- The pool that takes blood landing at `hit`: the one of `key` close by
-- first, else one already close by (two pools that meet become one), else a
-- new one. A big (finisher) pour only joins a big pool.
local function poolAt(
	key: any,
	hit: RaycastResult,
	maxRadius: number,
	seed: number?,
	priority: number?
): Pool?
	local rank = priority or 1
	local target: Pool? = nil
	for _, pool in pools do
		local record = pool.record
		if record and not record.dead and pool.into == nil then
			local mine = pool.sources[key] == true
			if pool.priority >= rank or mine then
				-- (its own wound's blood: anywhere in it, even off its middle; a
				-- pool that took another one in slides to its new middle)
				local gap = hit.Position - (pool.center + pool.offset)
				local toMiddle = hit.Position - pool.center
				if mine and toMiddle.Magnitude < gap.Magnitude then
					gap = toMiddle
				end
				if math.abs(gap:Dot(pool.normal)) < 0.6 then
					local reach = if mine then pool.radius + 0.3 else pool.radius * 0.7 + 0.3
					if gap.Magnitude < reach and (target == nil or mine) then
						target = pool
					end
				end
			end
		end
	end
	if target == nil then
		-- (its shape: from `seed`, the same on every client; else from where it is)
		local shapeSeed = seed or math.floor(hit.Position.X * 7 + hit.Position.Z * 13)
		target = makePool(key, hit, maxRadius, Random.new(shapeSeed), rank)
	end
	return target
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
		local downhill = DOWN - hit.Normal * DOWN:Dot(hit.Normal)
		if down and downhill.Magnitude > 0.05 then
			local low = groundUnder(hit.Position + downhill.Unit * LOW_SIDE)
			if low and low.Material ~= Enum.Material.Water then
				hit = low
			end
		end
	end
	local target = poolAt(key, hit, maxRadius or 1.8)
	if target then
		target.sources[key] = true
		target.rate = math.max(target.rate, area)
		target.feedUntil = math.max(target.feedUntil, os.clock() + seconds)
		target.maxRadius = math.max(target.maxRadius, maxRadius or 1.8)
		target.full = math.max(target.full, target.maxRadius * target.spec.visible)
	end
end

-- A pool spreading to `size` studs across over `seconds` (same on every
-- client: `seed`).
function BloodPool.spread(position: Vector3, size: number, seconds: number, seed: number)
	local radius = size / 2
	local area = math.pi * radius * radius
	BloodPool.feed({ seed = seed }, position, area / math.max(seconds, 0.2) * 1.4, seconds, radius)
end

-- Finisher pools already made, by seed (when): a body seen again, or its
-- frozen copy (Server/Systems/Corpses, same attributes), makes no second one.
local claimed: { [number]: number } = {}

-- true the first time `seed` is asked for (then false for CLAIM_TIME s).
function BloodPool.claim(seed: number): boolean
	local now = os.clock()
	for old, at in claimed do
		if now - at > CLAIM_TIME then
			claimed[old] = nil
		end
	end
	if claimed[seed] then
		return false
	end
	claimed[seed] = now
	return true
end

-- `area` studs² of blood poured now on the ground `hit` (a finisher's stump,
-- BloodGush.stump, calls it 10 times a second: pulsing, then oozing, then
-- slowing). A big pool whose edge gets to `maxRadius` studs (when all its
-- blood is out) and keeps creeping until `spreadTime` seconds after its
-- first blood; the same shape on every client (`seed`); kept before the
-- bleeders' pools.
function BloodPool.pour(
	key: any,
	hit: RaycastResult,
	area: number,
	maxRadius: number,
	seed: number,
	spreadTime: number?
): Pool?
	if not Config.Blood.ENABLED or area <= 0 or hit.Material == Enum.Material.Water then
		return nil
	end
	local target = poolAt(key, hit, maxRadius, seed, 2)
	if target == nil then
		return nil
	end
	local now = os.clock()
	target.area += area
	target.feedUntil = math.max(target.feedUntil, now + 0.6)
	target.maxRadius = math.max(target.maxRadius, maxRadius)
	target.full = math.max(target.full, target.maxRadius * target.spec.visible)
	local spread = spreadTime or (20 + FINISHER_POOLS.CREEP)
	if target.spreadTime == 0 then
		target.spreadTime = spread
	elseif not target.sources[key] then
		-- (a second wound pouring into it: it spreads for longer)
		target.spreadTime = math.max(target.spreadTime, now - target.born + spread)
	end
	target.sources[key] = true
	return target
end

------------------------------------------------------------------------------
-- Spreading
------------------------------------------------------------------------------

-- Where its edge is going now: where the blood poured so far reaches
-- (its area, spread thinner and thinner).
local function goal(pool: Pool, now: number): number
	local plain = math.sqrt(pool.area / math.pi)
	if pool.priority >= 2 then
		-- a finisher's: a little behind while it pours, catching up as it
		-- creeps on, all there at `spreadTime` (an ease-out: slower and slower)
		local c = math.clamp((now - pool.born) / math.max(pool.spreadTime, 1), 0, 1)
		local creep = 1 - CREEP_SHARE * (1 - c) * (1 - c)
		return math.max(math.min(plain, pool.maxRadius * 1.15) * creep, START_RADIUS)
	end
	-- (a bleeder's: up to its maxRadius, fast at first, slower after)
	local R = pool.maxRadius
	return math.max(R * (1 - math.exp(-plain / R)) * pool.spec.visible, START_RADIUS)
end

-- Its middle and its size where it fits: slid downhill, pushed away from a
-- wall or a ledge close by (it spreads on its free side), smaller if it still
-- doesn't fit. Returns the offset of its middle and the radius drawn.
local function fit(pool: Pool, r: number): (Vector3, number)
	local drift = pool.slopeDir * r * SLOPE_DRIFT * pool.slope
	for _, ray in pool.rays do
		probeRay(pool, ray, drift:Dot(ray.dir) + reachIn(pool, ray.dir, r) + 0.3)
	end
	local offset = drift
	local limit = math.max(r * 0.6, drift.Magnitude)
	for _ = 1, 3 do
		for _, ray in pool.rays do
			local stop = ray.stop
			if stop then
				local over = offset:Dot(ray.dir) + reachIn(pool, ray.dir, r) - stop
				if over > 0 then
					offset -= ray.dir * over
				end
			end
		end
		if offset.Magnitude > limit then
			offset = offset.Unit * limit
		end
	end
	local k = 1
	for _, ray in pool.rays do
		local stop = ray.stop
		if stop then
			local room = math.max(stop - offset:Dot(ray.dir), 0)
			k = math.min(k, room / reachIn(pool, ray.dir, r))
		end
	end
	return offset, math.max(r * k, math.min(START_RADIUS, r))
end

-- Blood reaching a ledge runs down its side (once per ray).
local function runOver(pool: Pool)
	for _, ray in pool.rays do
		local stop = ray.stop
		if stop and ray.stopKind == "drop" and not ray.ran then
			local edge = pool.offset:Dot(ray.dir) + reachIn(pool, ray.dir, pool.radius)
			if edge >= stop - 0.15 then
				ray.ran = true
				local at = pool.center + ray.dir * stop + pool.normal * ray.lastH
				BloodStain.overLedge(at, ray.dir, math.min(0.16, pool.radius * 0.25))
			end
		end
	end
end

-- One step of a pool spreading (`dt` seconds; `instant`: straight to where
-- it is going - a pool laid already spread).
local function step(pool: Pool, dt: number, now: number, instant: boolean?)
	local into = pool.into
	if into then
		-- taken in by a bigger pool: it shrinks under it (only the part the
		-- other doesn't cover yet), and goes once it is hidden
		local gap = (pool.center + pool.offset) - (into.center + into.offset)
		local hidden = math.max(0, into.radius * COVERED - gap.Magnitude) / pool.extent
		local record, intoRecord = pool.record, into.record
		if record and intoRecord then
			record.born = intoRecord.born -- (the same blood: it ages with it)
		end
		local r = pool.radius + (hidden - pool.radius) * (1 - math.exp(-dt / 1.2))
		pool.radius = math.min(pool.radius, r)
		if instant or pool.radius <= hidden + 0.02 or pool.radius < 0.15 then
			if record and not record.dead then
				BloodAge.remove(record)
			end
			local run = pool.run
			if run and run.record and not run.record.dead then
				BloodAge.remove(run.record)
			end
		end
		return
	end
	if now < pool.feedUntil and pool.rate > 0 then
		pool.area += pool.rate * dt
	end
	pool.target = goal(pool, now)
	-- its edge eases toward it (never jumps, never shrinks)
	local r = pool.target
	if not instant then
		local move = (pool.target - pool.radius) * (1 - math.exp(-dt / GROW_TIME))
		r = pool.radius + math.min(move, MAX_SPEED * dt)
	end
	local offset, fitted = fit(pool, math.max(r, pool.radius))
	pool.offset = if instant then offset else pool.offset:Lerp(offset, math.min(1, dt * 2))
	pool.radius = math.max(pool.radius, math.min(r, fitted))
	if fitted < pool.radius then
		pool.radius = fitted -- (against a wall: it stays as big as fits)
	end
	runOver(pool)
	-- its run downhill: once the pool is big enough, a little further each
	-- step (faster down a steeper slope), never past what stops it
	local run = pool.run
	if run and pool.radius >= pool.full * RUN_START then
		local grow = RUN_SPEED * (0.5 + pool.slope) * dt
		run.length = if instant then run.reach else math.min(run.length + grow, run.reach)
		local ray = run.ray
		local edge = pool.offset:Dot(ray.dir) + reachIn(pool, ray.dir, pool.radius)
		probeRay(pool, ray, edge + run.length + 0.1)
		local stop = ray.stop
		if stop then
			run.length = math.max(0, math.min(run.length, stop - edge - 0.05))
		end
	end
end

-- Two pools that meet become one: `pool` takes `other` in (its blood, its
-- wounds); its middle moves toward the middle of both (it slides there, no
-- jump) and it grows to hold both, `other` shrinks under it.
local function merge(pool: Pool, other: Pool, now: number)
	local a, b = math.max(pool.area, 1e-3), math.max(other.area, 1e-3)
	local was = pool.center + pool.offset
	local between = (pool.center * a + other.center * b) / (a + b)
	local hit = groundUnder(between)
	if hit and math.abs((hit.Position - pool.center):Dot(pool.normal)) < 0.3 then
		-- (its rays start again from its new middle; drawn where it was)
		pool.center = hit.Position
		pool.offset = was - pool.center
		for _, ray in pool.rays do
			ray.probed, ray.lastH, ray.stop, ray.stopKind = 0, 0, nil, nil
		end
		local run = pool.run
		if run then
			local ray = run.ray
			ray.probed, ray.lastH, ray.stop, ray.stopKind = 0, 0, nil, nil
		end
	end
	pool.area += other.area
	pool.maxRadius = math.sqrt(pool.maxRadius ^ 2 + other.maxRadius ^ 2)
	pool.full = math.sqrt(pool.full ^ 2 + other.full ^ 2)
	pool.rate = math.max(pool.rate, other.rate)
	pool.feedUntil = math.max(pool.feedUntil, other.feedUntil)
	if other.spreadTime > 0 then
		pool.spreadTime = math.max(pool.spreadTime, other.born + other.spreadTime - pool.born)
	end
	for key in other.sources do
		pool.sources[key] = true
	end
	for _, extra in other.extras do
		table.insert(pool.extras, extra)
	end
	table.clear(other.extras)
	other.into = pool
	other.rate = 0
	other.feedUntil = 0
	-- (the same blood now: the same age, the same colour)
	local record, otherRecord = pool.record, other.record
	if record and otherRecord then
		local born = math.max(record.born, otherRecord.born)
		record.born, otherRecord.born = born, born
		BloodAge.touch(record)
		BloodAge.touch(otherRecord)
	end
	pool.born = math.min(pool.born, now)
end

-- Pools of the same kind overlapping a lot: one takes the other in (the one
-- drawn on top - the older, bigger one - takes the one under it).
local function mergeAll(now: number, only: Pool?)
	for i, pool in pools do
		for j = i + 1, #pools do
			local other = pools[j]
			if
				(only == nil or pool == only or other == only)
				and pool.into == nil
				and other.into == nil
				and pool.priority == other.priority
				and pool.record
				and other.record
				and not (pool.record :: BloodAge.Record).dead
				and not (other.record :: BloodAge.Record).dead
				and math.abs((other.center - pool.center):Dot(pool.normal)) < 0.5
				and pool.normal:Dot(other.normal) > 0.95
			then
				local gap = (pool.center + pool.offset) - (other.center + other.offset)
				if gap.Magnitude < (pool.radius + other.radius) * MERGE_OVERLAP then
					local first = pool.layer > other.layer
						or (pool.layer == other.layer and pool.area >= other.area)
					if first then
						merge(pool, other, now)
					else
						merge(other, pool, now)
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------

-- A stretched pool_lobe picture covering from `a` to `b` studs along `dir`
-- from `origin`, `width` studs wide. Made the first time, moved and grown after.
local function drawRun(pool: Pool, run: Run, origin: Vector3, a: number, b: number, width: number)
	local dir = run.ray.dir
	local length = if LOBE_PICTURE then (b - a) / (LOBE_TO - LOBE_FROM) else b - a
	local wide = if LOBE_PICTURE then width / LOBE_WIDE else width
	local middle = if LOBE_PICTURE then a - LOBE_FROM * length else (a + b) / 2
	local at = origin + dir * middle
	local record = run.record
	if record == nil then
		local main = pool.record
		local made = BloodStain.place("poolLobe", at, pool.normal, dir, wide, length, {
			random = Random.new(pool.layer * 131 + 7919),
			profile = "pool",
			start = PALETTE.VENOUS, -- (the same blood as the pool: the same colour)
			pinned = true,
			noEdge = true,
			priority = 3,
			life = pool.life,
			-- (under the pool: its start hides under it, no seam)
			layer = pool.layer - 1,
		})
		if made then
			if main then
				made.born, made.speed, made.soakIn = main.born, main.speed, main.soakIn
			end
			for _, layer in made.layers do
				layer.gel = 0.1 -- (it clots as dark as the pool)
			end
			BloodAge.paint(made)
		end
		run.record, run.l0, run.w0 = made, length, wide
		return
	end
	BloodStain.fit(record, at, dir, length / run.l0, wide / run.w0)
end

local function draw(pool: Pool, fresh: boolean)
	local record = pool.record
	if record == nil or record.dead then
		return
	end
	local offset = pool.offset
	local changed = math.abs(pool.radius - pool.drawnR) > 0.01
		or (offset - pool.drawnAt).Magnitude > 0.01
	if changed then
		pool.drawnR = pool.radius
		pool.drawnAt = offset
		-- (it turns a little as it grows: it spreads more one way than another)
		local grown = math.clamp(pool.radius / math.max(pool.full, 0.1), 0, 1)
		local forward = CFrame.fromAxisAngle(pool.normal, pool.twist * grown)
			:VectorToWorldSpace(pool.forward)
		local size = pool.radius * 2 / pool.cover
		local k = size / pool.core0
		-- (stretched down a slope: longer that way, narrower across)
		local along, across = k, k
		if pool.stretch > 1 then
			local s = math.sqrt(pool.stretch)
			local c = math.abs(forward:Dot(pool.slopeDir))
			along *= 1 + (s - 1) * c
			across /= 1 + (s - 1) * c
		end
		local at = pool.center + offset - forward * pool.shift * size * (along / k)
		BloodStain.fit(record, at, forward, along, across)
	end
	local run = pool.run
	if run and run.length > 0.05 and pool.into == nil then
		local dir = run.ray.dir
		local edge = reachIn(pool, dir, pool.radius)
		local b = edge + run.length
		if changed or b - run.drawn > 0.01 then
			run.drawn = b
			drawRun(pool, run, pool.center + offset, edge * 0.4, b, pool.radius * 0.5)
		end
	end
	if fresh then
		BloodAge.touch(record)
		local runRecord = if run then run.record else nil
		if runRecord and not runRecord.dead then
			BloodAge.touch(runRecord)
		end
	end
end

-- Is it still spreading?
local function moving(pool: Pool, now: number): boolean
	if pool.into then
		return true
	end
	if now < pool.feedUntil + pool.spec.tail then
		return true
	end
	if pool.priority >= 2 and now < pool.born + pool.spreadTime + 2 then
		return true
	end
	if pool.target - pool.radius > 0.01 then
		return true
	end
	local run = pool.run
	return run ~= nil and run.length < run.reach - 0.01 and now < pool.born + pool.spreadTime + 20
end

-- A finisher's pool already there (a body we only see after it happened):
-- `size` studs across, fully spread at once (the same shape as the live
-- one: it merges with one already there just the same). Once per `seed`
-- (BloodPool.claim).
function BloodPool.lay(position: Vector3, size: number, seed: number)
	if not Config.Blood.ENABLED or not FINISHER_POOLS.ENABLED or not BloodPool.claim(seed) then
		return
	end
	local hit = groundUnder(position)
	if hit == nil then
		return
	end
	local radius = size / 2
	local spreadTime = 20 + FINISHER_POOLS.CREEP
	local key = { seed = seed }
	local pool = BloodPool.pour(key, hit, math.pi * radius * radius, radius, seed, spreadTime)
	if pool == nil or pool.key ~= key then
		-- (none, or its blood went into a pool already there - maybe one
		-- still spreading live: that one just gets bigger, as it goes)
		return
	end
	-- (as if it had been spreading all this time: straight to its end)
	local now = os.clock()
	pool.born = math.min(pool.born, now - spreadTime - 1)
	pool.feedUntil = 0
	for _ = 1, 4 do
		step(pool, 0.5, now, true)
	end
	-- (another finisher pool laid here already, overlapping: one pool)
	mergeAll(now, pool)
	for _, other in pools do
		if other.into and (other == pool or other.into == pool) then
			step(other, 0.5, now, true)
		end
	end
	local into = pool.into
	local final = if into then into else pool
	for _ = 1, 4 do
		step(final, 0.5, now, true)
	end
	pool.fedArea = pool.area
	final.fedArea = final.area
	draw(final, false)
end

------------------------------------------------------------------------------
-- Wet, drops falling in it
------------------------------------------------------------------------------

-- Is `position` in fresh blood? 0 (no) → 1 (just spilled).
function BloodPool.wetAt(position: Vector3): number
	local best = 0
	for _, pool in pools do
		local record = pool.record
		if record and not record.dead then
			local gap = position - (pool.center + pool.offset)
			local flat = gap - pool.normal * gap:Dot(pool.normal)
			if
				math.abs(gap:Dot(pool.normal)) < 1
				and flat.Magnitude < pool.radius * 1.05 + 0.15
			then
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
	local across = math.min(
		pool.radius * 2 * random:NextNumber(1.5, 2.5) * math.clamp(0.6 + height * 0.1, 0.6, 1.2),
		3.5
	)
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
		if record and not record.dead and pool.into == nil then
			local gap = position - (pool.center + pool.offset)
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

-- A pool gone (aged out, evicted, taken in by another): its starbursts and
-- its run go with it.
local function dropExtras(pool: Pool)
	for _, extra in pool.extras do
		if not extra.dead then
			BloodAge.remove(extra)
		end
	end
	table.clear(pool.extras)
	local run = pool.run
	if run and run.record and not run.record.dead then
		BloodAge.remove(run.record)
	end
end

local accumulated = 0
RunService.Heartbeat:Connect(function(dt: number)
	accumulated += dt
	if accumulated < 0.1 then
		return -- (10 times a second is plenty for a pool)
	end
	debug.profilebegin("BloodPool")
	local stepTime = math.min(accumulated, 0.5) -- (a long hitch: no big jump)
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
		if moving(pool, now) then
			step(pool, stepTime, now)
			-- (blood came in since last time: it is wet and red again)
			local fed = pool.area > pool.fedArea + 1e-4
			pool.fedArea = pool.area
			draw(pool, fed)
		end
		index += 1
	end
	mergeAll(now)
	debug.profileend()
end)

return table.freeze(BloodPool)
