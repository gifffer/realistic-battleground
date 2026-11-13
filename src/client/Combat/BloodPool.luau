--!strict
-- BloodPool: blood POOLING on the ground under someone bleeding (client-side).
--
-- What a real pool does, and what this draws:
--   • it SPREADS: its edge (the "front") keeps moving outward while blood
--     pours in, fast at first, then slower and slower (it gets thinner),
--     and it keeps CREEPING a while after the wound stops (thick blood
--     spreads slowly: the edge of a real pool goes like t^(1/8));
--   • its edge is never round: it is made of TONGUES of blood all around
--     (one picture each, pushing out of the middle at their own speed), and
--     a few of them run on as long, narrow FINGERS (rivulets) that follow
--     the smallest slope, a gutter, a gap between two things;
--   • it FLOWS DOWNHILL: on a slope the tongues and fingers going down the
--     slope go further and faster, the ones going up barely move;
--   • it STOPS at a curb, a wall, a step up - only on that side: the blood
--     that can't go there pushes the tongues next to it further (it slides
--     along the wall); it flows around a small thing lying on the floor;
--   • it RUNS OVER a ledge (blood running down the side of the curb), and a
--     big pool keeps going on the lower ground (a finger past the step);
--     a crack between two floor parts doesn't stop it;
--   • two pools that meet become one (a new feed close to a pool feeds it;
--     a tongue reaching another pool stops there and wets it again);
--   • it is WET (shiny) for a while, then dulls, darkens, crusts: the middle
--     first (it stops being fed), the moving front stays bright and glossy
--     as long as it moves; the thin tongues dry first, and an old pool weeps
--     a pale ring of serum around it (BloodStain / BloodAge);
--   • someone dripping into it from above: each drop throws tiny drops
--     around it, and after a dozen drops a "starburst" of dots rings it;
--   • under a body lying on a slope it starts on the LOW side (blood runs
--     out of the body downhill before it pools).
--
-- Everything random about a pool (the tongues' directions, their speeds, the
-- fingers) is picked from its seed when it is made, and the ground is
-- checked at fixed distances: the same pool on every client.
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
local START_RADIUS = 0.22 -- studs: a new pool's first size
local STEP_HEIGHT = 0.1 -- a bump higher than this stops it (curb, step)
local WALL_HEIGHT = 0.08 -- (the "wall" ray: this high above the ground)
local UNEVEN = 0.4 -- studs: the ground this far ABOVE the pool's plane stops a tongue
-- (and this far BELOW it: the pictures are flat, on the pool's plane - a
-- tongue going on over ground falling away would float above it)
local DIP = 0.15
local SPILL_HEIGHT = 1.6 -- studs: a big pool goes on below a drop this high (a curb)
local PROBE_STEP = 0.35 -- studs: a tongue checks the ground ahead this often
local FINGER_STEP = 0.3 -- (a finger: this often)
local MAX_SPEED = 3 -- studs/s: a tongue never moves faster (never jumps)
local LOBE_DRYING = 1.4 -- the thin tongues dry this much faster than the middle
local FINGER_DRYING = 1.6 -- (the fingers, thinner still)
local LOW_SIDE = 0.6 -- studs: a lying body's pool starts this far downhill
local SLOPE_GAIN = 5 -- how much a slope speeds up (or holds back) a tongue
local CREEP_POWER = 0.25 -- the front's slowing down (theory 1/8; 1/4 reads better)
local FINGER_TURN = math.rad(55) -- a finger stopped by something turns this much
local GUTTER_TURN = math.rad(30) -- a finger looks for lower ground this far to its sides
local GUTTER_EVERY = 1 -- studs: a finger looks for lower ground this often
local MAX_FINGER_PARTS = 3 -- pieces of one finger at most (it turned twice)
local CORE_LAYER = 11 -- (the middle on top: the tongues' backs hide under it)
-- seconds a finisher pool's seed stays claimed: as long as the body (or its
-- frozen copy) can still be seen, a little more
local CLAIM_TIME = Config.Knockout.FINISHER_BODY_TIME + 5

-- The pictures are not filled to their edges (measured on assets/blood):
-- pool_1..3: the blood is a blob about this fraction of the picture across
-- (area-equivalent), its middle shifted this much (× the picture) along it;
-- pool_lobe: the blob goes from -0.48 to +0.25 of its length (its rounded
-- tip at +X, the way it flows) and 0.4 of its width. Without pictures the
-- plain shapes fill the whole size.
local POOL_COVER = { 0.465, 0.39, 0.42 }
local POOL_SHIFT = { -0.01, -0.06, -0.07 }
-- (and its blob is not round: its longest side, × that diameter)
local POOL_EXTENT = { 1.33, 1.08, 1.26 }
local LOBE_FROM, LOBE_TO, LOBE_WIDE = -0.48, 0.25, 0.4
local _, lobeImage = BloodStain.resolve("poolLobe")
local LOBE_PICTURE = lobeImage ~= 0

-- How a kind of pool spreads.
type Spec = {
	tongues: number, -- tongues of blood around it (High quality)
	fingers: number, -- of them running on as fingers
	parts: number, -- pieces of fingers at most (a finger turning makes a new one)
	glossy: number, -- tongues with their own wet sheen
	fMin: number, -- each tongue reaches this × the front...
	fMax: number,
	lagMin: number, -- ...this many seconds behind it (slow ones, fast ones)
	lagMax: number,
	wideMin: number, -- (how much the tongues overlap their neighbours)
	wideMax: number,
	core: number, -- the middle picture: this × the front
	visible: number, -- the front: this × the radius the volume gives
	fingerStart: number, -- fingers start once the front is this × its full size
	extraMin: number, -- a finger runs this × the pool's size beyond the front...
	extraMax: number,
	speedMin: number, -- ...at this many studs/s (slowing down as it goes)
	speedMax: number,
	widthMin: number, -- studs: a finger's width
	widthMax: number,
	tail: number, -- seconds it keeps moving after the last feed
}

-- A finisher's big pool (a torn limb, a burst head, a body cut in two).
-- What it costs, at most (High quality, with the pictures): its middle (a
-- part, 3 decals, a wet film) + 10 tongues (a part and a decal each) + 3
-- tongues' wet films + 6 finger pieces (a part and a decal) = 40 instances,
-- all made once and then only moved / grown, updated 10 times a second.
local BIG: Spec = {
	tongues = FINISHER_POOLS.TONGUES,
	fingers = FINISHER_POOLS.FINGERS,
	parts = 6,
	glossy = 3,
	fMin = 0.8,
	fMax = 1.22,
	lagMin = 0.6,
	lagMax = 2.4,
	wideMin = 1.15,
	wideMax = 1.6,
	core = 0.78,
	visible = 1,
	fingerStart = 0.6,
	extraMin = 0.2,
	extraMax = 0.45,
	speedMin = 0.2,
	speedMax = 0.45,
	widthMin = 0.3,
	widthMax = 0.75,
	tail = 2,
}

-- A bleeder's pool (a fighter bleeding where he stands, a spurt landing).
local SMALL: Spec = {
	tongues = 4,
	fingers = 1,
	parts = 1,
	glossy = 0,
	fMin = 0.85,
	fMax = 1.2,
	lagMin = 0.5,
	lagMax = 1.3,
	wideMin = 1.2,
	wideMax = 1.6,
	core = 0.8,
	visible = 0.65,
	fingerStart = 0.5,
	extraMin = 0.25,
	extraMax = 0.5,
	speedMin = 0.2,
	speedMax = 0.35,
	widthMin = 0.15,
	widthMax = 0.3,
	tail = 3,
}

-- One straight piece of a finger (a picture stretched from `base` along
-- `dir`). The first piece of a tongue's finger starts at its tongue's tip
-- (`attached`: it moves out with it); a finger that turns or goes down a
-- step starts a new piece where it was.
type Part = {
	record: BloodAge.Record?,
	l0: number, -- (its picture's size when made: rescaled from there)
	w0: number,
	layer: number,
	attached: boolean,
	base: Vector3, -- (not attached: where it starts, on its ground)
	normal: Vector3,
	dir: Vector3,
	tip: number, -- attached: distance of its tip from the pool's middle; else its length
	probed: number, -- (not attached: ground checked up to here)
	lastH: number,
	nextGutter: number,
	drawn: number,
}

type Finger = {
	parent: Tongue?,
	parts: { Part },
	extra: number, -- studs it runs in all
	speed: number,
	width: number,
	side: number, -- (±1: which way it turns first)
	grown: number,
	done: boolean,
}

-- One tongue of blood pushing out of the pool, `dir` from its middle.
type Tongue = {
	dir: Vector3,
	f: number,
	lag: number,
	wide: number,
	layer: number,
	glossy: boolean,
	reach: number, -- its tip, studs from the pool's middle
	probed: number, -- the ground checked up to here
	lastH: number, -- (the ground's height there, off the pool's plane)
	slope: number,
	stop: number?, -- something stops it there
	stopKind: string?, -- "wall", "step", "drop", "uneven", "merged"
	low: RaycastResult?, -- (a drop: the ground below)
	spilled: boolean,
	ran: boolean, -- (it ran over its ledge)
	natural: number,
	boost: number,
	record: BloodAge.Record?,
	l0: number,
	w0: number,
	drawn: number,
	finger: Finger?,
}

type Pool = {
	key: any,
	center: Vector3,
	normal: Vector3,
	forward: Vector3, -- (the middle picture's direction)
	downhill: Vector3, -- (down the slope, its length the slope: 0 flat)
	radius: number, -- the middle's radius (drops splash into it)
	front: number, -- the front's mean radius (feet get wet in it)
	full: number, -- the front's full size (radius)
	area: number,
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
	coreOffset: Vector3, -- (the middle pushed away from a wall / a ledge close by)
	coreAt: Vector3, -- (its offset when last drawn)
	core0: number, -- (the middle picture's size when made)
	coreDrawn: number,
	tongues: { Tongue },
	fingers: { Finger },
	partsLeft: number,
	random: Random,
	lastAbsorb: number,
	drips: number, -- drops fallen into it
	extras: { BloodAge.Record }, -- (starbursts: they go with the pool)
	-- 1 a bleeder's pool, 2 a finisher's (kept first when there are too many)
	priority: number,
	life: number?, -- (a finisher's: its own lifetime, s)
	spec: Spec,
	look: number, -- (from its seed: its pictures' looks, its tongues' heights)
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

-- `dir` turned by `angle` (radians) around `normal`.
local function turned(dir: Vector3, normal: Vector3, angle: number): Vector3
	return CFrame.fromAxisAngle(normal, angle):VectorToWorldSpace(dir)
end

-- The ground's height at `point`, off the plane through `origin` (nil: none).
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
--   little by little - a bump, a curved floor), or "drop" (a ledge: the
--   ground below, if any, within SPILL_HEIGHT),
-- and the distance where it stops. A crack between two floor parts is not
-- a drop (the ground goes on just after it).
local function probe(
	origin: Vector3,
	normal: Vector3,
	dir: Vector3,
	from: number,
	to: number,
	lastH: number
): (string, number, number, RaycastResult?)
	local start = origin + dir * from + normal * (lastH + WALL_HEIGHT)
	local wall = cast(start, dir * (to - from + 0.05))
	if wall and math.abs(wall.Normal:Dot(normal)) < 0.5 then
		-- (it goes a hair under the wall: no gap at its foot)
		return "wall", from + (wall.Position - start):Dot(dir) + 0.05, lastH, nil
	end
	local point = origin + dir * to
	local h = heightAt(origin, normal, point)
	if h then
		if h - lastH > STEP_HEIGHT then
			return "step", to, lastH, nil
		elseif lastH - h <= STEP_HEIGHT then
			if h > UNEVEN or h < -DIP then
				return "uneven", from, lastH, nil
			end
			return "flat", to, h, nil
		end
	end
	-- no ground there, or lower: a crack? (the ground goes on just after)
	for _, gap in { 0.2, 0.4 } do
		local after = heightAt(origin, normal, point + dir * gap)
		if after and math.abs(after - lastH) <= STEP_HEIGHT then
			return "flat", to, lastH, nil
		end
	end
	-- a real ledge: the ground below it (blood can run on down there)
	local low = cast(point + dir * 0.2 + normal * (lastH + 0.3), -normal * (SPILL_HEIGHT + 0.5))
	return "drop", from, lastH, low
end

-- The pool (other than `pool`) whose middle `point` is in, if any: one at
-- least as big, not one lying under this one's own middle (a fighter bled
-- there before his finisher: the big pool just covers it).
local function poolUnder(pool: Pool, point: Vector3): Pool?
	for _, other in pools do
		local record = other.record
		if
			other ~= pool
			and record
			and not record.dead
			and other.priority >= pool.priority
			and (other.center - pool.center).Magnitude > pool.full * 0.5 + other.radius
		then
			local gap = point - other.center
			local up = gap:Dot(other.normal)
			if math.abs(up) < 0.6 and (gap - other.normal * up).Magnitude < other.radius * 0.9 then
				return other
			end
		end
	end
	return nil
end

-- How many tongues / fingers / finger pieces / glossy tongues this pool
-- gets: fewer at a lower quality, without the pictures (plain shapes cost
-- more), and when several big pools are spreading at once.
local function budget(spec: Spec, big: boolean): (number, number, number, number)
	local scale = BloodAge.scale()
	local k = if scale >= 1 then 1 elseif scale >= 0.7 then 0.8 else 0.6
	local tongues = math.max(3, math.floor(spec.tongues * k + 0.5))
	local fingers = if scale >= 1 then spec.fingers else math.floor(spec.fingers * k)
	local parts = math.floor(spec.parts * k + 0.5)
	local glossy = if scale >= 0.7 then math.floor(spec.glossy * k) else 0
	if not LOBE_PICTURE then
		tongues = math.min(tongues, 7)
		parts = math.min(parts, 3)
	end
	if big then
		local spreading = 0
		local now = os.clock()
		for _, pool in pools do
			if pool.priority >= 2 and now < pool.born + pool.spreadTime then
				spreading += 1
			end
		end
		if spreading >= 3 then
			tongues = math.max(5, math.floor(tongues * 0.6))
			fingers = math.max(0, fingers - 1)
			parts = math.floor(parts / 2)
		end
	end
	return tongues, math.min(fingers, tongues), parts, glossy
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
	local along = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
	local forward = along - normal * along:Dot(normal)
	forward = if forward.Magnitude > 1e-3
		then forward.Unit
		else normal:Cross(Vector3.new(1, 0, 0)).Unit
	local aspect = random:NextNumber(0.85, 1)
	local index = random:NextInteger(1, #POOL_COVER)
	local picture = BloodStain.image("pool", nil, index) ~= 0
	local cover = if picture then POOL_COVER[index] else 1
	local size0 = START_RADIUS * 2 / cover
	local record = BloodStain.place("pool", hit.Position, normal, forward, size0 * aspect, size0, {
		random = random,
		profile = "pool",
		start = PALETTE.VENOUS,
		-- (the wet film: over the blob only, not over the empty picture around it)
		gloss = cover * 0.75,
		pinned = true,
		noEdge = true,
		material = hit.Material,
		priority = 3,
		life = life,
		index = index,
		layer = CORE_LAYER,
	})
	if record == nil then
		return nil
	end
	local downhill = DOWN - normal * DOWN:Dot(normal)
	local pool: Pool = {
		key = key,
		center = hit.Position,
		normal = normal,
		forward = forward,
		downhill = downhill,
		radius = START_RADIUS,
		front = START_RADIUS,
		full = maxRadius * spec.visible,
		area = math.pi * START_RADIUS * START_RADIUS,
		fedArea = 0,
		maxRadius = maxRadius,
		rate = 0,
		feedUntil = 0,
		born = os.clock(),
		spreadTime = 0,
		sources = { [key] = true },
		record = record,
		cover = cover,
		shift = if picture then POOL_SHIFT[index] else 0,
		extent = if picture then POOL_EXTENT[index] else 1.06,
		coreOffset = Vector3.zero,
		coreAt = Vector3.zero,
		core0 = size0,
		coreDrawn = START_RADIUS,
		tongues = {},
		fingers = {},
		partsLeft = 0,
		random = random,
		lastAbsorb = 0,
		drips = 0,
		extras = {},
		priority = rank,
		life = life,
		spec = spec,
		look = 0,
	}
	-- its tongues, all picked now from its seed (the same on every client)
	local count, fingers, parts, glossy = budget(spec, big)
	pool.partsLeft = parts
	local turn = random:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local angle = turn + (i - 1 + random:NextNumber(-0.35, 0.35)) / count * math.pi * 2
		local flat = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local dir = flat - normal * flat:Dot(normal)
		dir = if dir.Magnitude > 1e-3 then dir.Unit else forward
		table.insert(pool.tongues, {
			dir = dir,
			f = random:NextNumber(spec.fMin, spec.fMax),
			lag = random:NextNumber(spec.lagMin, spec.lagMax),
			wide = random:NextNumber(spec.wideMin, spec.wideMax),
			layer = (i - 1) % 10,
			-- (every few tongues one with its own wet sheen, `glossy` at most)
			glossy = glossy > 0 and (i - 1) % math.max(1, math.floor(count / glossy)) == 0,
			reach = 0,
			probed = 0,
			lastH = 0,
			slope = 0,
			stop = nil,
			stopKind = nil,
			low = nil,
			spilled = false,
			ran = false,
			natural = 0,
			boost = 0,
			record = nil,
			l0 = 1,
			w0 = 1,
			drawn = 0,
			finger = nil,
		})
	end
	local glossLeft = glossy
	for _, tongue in pool.tongues do
		if tongue.glossy then
			tongue.glossy = glossLeft > 0
			glossLeft -= 1
		end
	end
	-- its fingers: on a slope the tongues going down it, else any
	if fingers > 0 and (big or maxRadius >= 1.5) then
		local order: { Tongue } = table.clone(pool.tongues)
		if downhill.Magnitude > 0.03 then
			table.sort(order, function(a, b)
				return a.dir:Dot(downhill) > b.dir:Dot(downhill)
			end)
		else
			for i = #order, 2, -1 do
				local j = random:NextInteger(1, i)
				order[i], order[j] = order[j], order[i]
			end
		end
		local scale = math.clamp(maxRadius * 2 / 8, 0.5, 1.2)
		for i = 1, fingers do
			local finger: Finger = {
				parent = order[i],
				parts = {},
				extra = math.min(
					maxRadius * 2 * random:NextNumber(spec.extraMin, spec.extraMax),
					FINISHER_POOLS.FINGER_REACH
				),
				speed = random:NextNumber(spec.speedMin, spec.speedMax) * scale,
				width = random:NextNumber(spec.widthMin, spec.widthMax) * math.clamp(scale, 0.6, 1),
				side = if random:NextNumber() < 0.5 then -1 else 1,
				grown = 0,
				done = false,
			}
			order[i].finger = finger
			table.insert(pool.fingers, finger)
		end
	end
	-- (its own looks and heights: two pools that overlap don't draw the same
	-- tongue pictures at the same heights - no copies, no flicker)
	pool.look = random:NextInteger(0, 9999)
	for i, tongue in pool.tongues do
		tongue.layer = (i - 1 + pool.look) % 10
	end
	table.insert(pools, pool)
	return pool
end

-- The pool that takes blood landing at `hit`: one already close by (its own,
-- `key`, first: two pools that meet become one), else a new one. A big
-- (finisher) pour only joins a big pool.
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
		if record and not record.dead and (pool.priority >= rank or pool.key == key) then
			local gap = hit.Position - pool.center
			if math.abs(gap:Dot(pool.normal)) < 0.6 then
				local reach = pool.front * 0.7 + 0.3
				if gap.Magnitude < reach and (target == nil or pool.key == key) then
					target = pool
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
-- BloodGush.stump, calls it a few times a second: pulsing, then oozing,
-- then slowing). A big pool whose front spreads to about `maxRadius` studs
-- (when all its blood is out) and keeps creeping until `spreadTime` seconds
-- after its first blood; the same shape on every client (`seed`); kept
-- before the bleeders' pools.
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
		target.sources[key] = true
		target.spreadTime = math.max(target.spreadTime, now - target.born + spread)
	end
	return target
end

------------------------------------------------------------------------------
-- Spreading
------------------------------------------------------------------------------

-- A tongue checks the ground ahead of it, a step at a time, up to `upTo`
-- studs from the pool's middle (its own tip, or its finger's).
local function probeTongue(pool: Pool, tongue: Tongue, upTo: number)
	while tongue.stop == nil and tongue.probed < upTo do
		local to = tongue.probed + PROBE_STEP
		local kind, at, h, low =
			probe(pool.center, pool.normal, tongue.dir, tongue.probed, to, tongue.lastH)
		if kind == "flat" then
			local point = pool.center + tongue.dir * to
			local other = poolUnder(pool, point)
			if other and other.record then
				-- it ran into another pool: they are one now
				tongue.stop, tongue.stopKind = to, "merged"
				BloodAge.touch(other.record)
				break
			end
			tongue.probed, tongue.lastH = to, h
			-- (the ground going down ahead of it: a tiny slope it follows)
			tongue.slope = math.clamp(-h / math.max(to, 1), -0.2, 0.2)
		else
			tongue.stop, tongue.stopKind = math.max(at, 0), kind
			if kind == "drop" then
				tongue.low = low
			end
		end
	end
end

-- How much a slope helps (> 1, downhill) or holds back (< 1) going `dir`.
local function slopeFactor(
	pool: Pool,
	dir: Vector3,
	slope: number,
	low: number,
	high: number
): number
	return math.clamp(1 + SLOPE_GAIN * (dir:Dot(pool.downhill) + slope), low, high)
end

-- A new straight piece of `finger`, from `base` (on the ground `normal`)
-- going `dir`.
local function newPart(pool: Pool, finger: Finger, base: Vector3, normal: Vector3, dir: Vector3)
	pool.partsLeft -= 1
	local parent = finger.parent
	table.insert(finger.parts, {
		record = nil,
		l0 = 1,
		w0 = 1,
		layer = if parent then (parent.layer + 5) % 10 else 10,
		attached = false,
		base = base,
		normal = normal,
		dir = dir,
		tip = 0,
		probed = 0,
		lastH = 0,
		nextGutter = GUTTER_EVERY,
		drawn = 0,
	})
end

-- A finger stopped at `tip` (on the plane through `origin`, `normal`): it
-- runs down the step (`kind` "drop", the ground `low` below), or turns to
-- whichever side is free (the lower one first), or ends.
local function goOn(
	pool: Pool,
	finger: Finger,
	tip: Vector3,
	origin: Vector3,
	normal: Vector3,
	dir: Vector3,
	kind: string?,
	low: RaycastResult?
)
	if pool.partsLeft <= 0 or #finger.parts >= MAX_FINGER_PARTS or kind == "merged" then
		finger.done = true
		return
	end
	if kind == "drop" then
		if low then
			-- down the step, and on along the lower ground
			newPart(pool, finger, low.Position + dir * 0.1, low.Normal, dir)
		else
			finger.done = true
		end
		return
	end
	if kind == "uneven" then
		-- the ground falls away from its plane little by little (a gentle
		-- slope, a hump): a new straight piece laid on the ground just ahead,
		-- going on the same way (it follows the ground down instead of
		-- floating over it; it never climbs)
		local ahead = cast(tip + dir * 0.15 + normal * 0.6, -normal * 1.2)
		if ahead and ahead.Normal.Y > 0.7 and (ahead.Position - tip):Dot(normal) < 0 then
			local flat = dir - ahead.Normal * dir:Dot(ahead.Normal)
			if flat.Magnitude > 1e-3 then
				newPart(pool, finger, ahead.Position, ahead.Normal, flat.Unit)
				return
			end
		end
		finger.done = true
		return
	end
	local h0 = (tip - origin):Dot(normal)
	local best: Vector3? = nil
	local bestH = math.huge
	for _, side in { finger.side, -finger.side } do
		local d = turned(dir, normal, side * FINGER_TURN)
		local result, _, h = probe(tip - normal * h0, normal, d, 0, 0.45, h0)
		if result == "flat" and h < bestH - 0.01 then
			best, bestH = d, h
		end
	end
	if best then
		newPart(pool, finger, tip, normal, best)
	else
		finger.done = true
	end
end

-- Is the ground lower a little to one side ahead (a gutter, a slope)? The
-- direction to go then.
local function lowerSide(origin: Vector3, normal: Vector3, at: Vector3, dir: Vector3): Vector3?
	local ahead = heightAt(origin, normal, at + dir * 0.6)
	if ahead == nil then
		return nil
	end
	local best: Vector3? = nil
	local bestH = ahead - 0.03
	for _, side in { 1, -1 } do
		local d = turned(dir, normal, side * GUTTER_TURN)
		local h = heightAt(origin, normal, at + d * 0.6)
		if h and h < bestH then
			best, bestH = d, h
		end
	end
	return best
end

-- A finger running on, `grow` studs more.
local function growFinger(pool: Pool, finger: Finger, grow: number)
	if #finger.parts == 0 then
		local parent = finger.parent
		if parent == nil then
			finger.done = true
			return
		end
		-- its first piece: out of its tongue's tip
		pool.partsLeft -= 1
		table.insert(finger.parts, {
			record = nil,
			l0 = 1,
			w0 = 1,
			layer = (parent.layer + 5) % 10,
			attached = true,
			base = pool.center,
			normal = pool.normal,
			dir = parent.dir,
			tip = parent.reach,
			probed = 0,
			lastH = 0,
			nextGutter = parent.reach + GUTTER_EVERY,
			drawn = 0,
		})
	end
	local part = finger.parts[#finger.parts]
	local parent = finger.parent
	finger.grown += grow
	if part.attached and parent then
		-- (it goes on straight out of its tongue, along the same line)
		local tip = math.max(part.tip, parent.reach) + grow
		probeTongue(pool, parent, tip)
		local stop = parent.stop
		if stop and tip >= stop - 0.01 then
			part.tip = math.max(stop - 0.05, parent.reach)
			local at = pool.center + parent.dir * part.tip + pool.normal * parent.lastH
			if parent.stopKind == "drop" and not parent.ran then
				-- (the finger got to the ledge before its tongue: it runs over)
				parent.ran = true
				BloodStain.overLedge(at, parent.dir, math.min(0.12, finger.width * 0.4))
			end
			goOn(
				pool,
				finger,
				at,
				pool.center,
				pool.normal,
				parent.dir,
				parent.stopKind,
				parent.low
			)
			return
		end
		part.tip = tip
		if tip >= part.nextGutter then
			part.nextGutter = tip + GUTTER_EVERY
			local at = pool.center + parent.dir * tip + pool.normal * parent.lastH
			local side = lowerSide(pool.center, pool.normal, at, parent.dir)
			if side and pool.partsLeft > 0 and #finger.parts < MAX_FINGER_PARTS then
				newPart(pool, finger, at, pool.normal, side)
			end
		end
		return
	end
	-- a piece of its own: it checks the ground ahead itself
	local target = part.tip + grow
	while part.probed < target do
		local to = part.probed + FINGER_STEP
		local kind, at, h, low =
			probe(part.base, part.normal, part.dir, part.probed, to, part.lastH)
		if kind == "flat" and poolUnder(pool, part.base + part.dir * to) then
			kind = "merged"
		end
		if kind ~= "flat" then
			part.tip = math.max(math.min(at, target), part.tip)
			local point = part.base + part.dir * part.tip + part.normal * part.lastH
			if kind == "drop" then
				BloodStain.overLedge(point, part.dir, math.min(0.12, finger.width * 0.4))
			end
			goOn(pool, finger, point, part.base, part.normal, part.dir, kind, low)
			return
		end
		part.probed, part.lastH = to, h
		if to >= part.nextGutter then
			part.nextGutter = to + GUTTER_EVERY
			local point = part.base + part.dir * to + part.normal * h
			local side = lowerSide(part.base, part.normal, point, part.dir)
			if side and pool.partsLeft > 0 and #finger.parts < MAX_FINGER_PARTS then
				part.tip = to
				newPart(pool, finger, point, part.normal, side)
				return
			end
		end
	end
	part.tip = target
end

-- One step of a pool spreading (`dt` seconds).
local function step(pool: Pool, dt: number, now: number)
	local spec = pool.spec
	local big = pool.priority >= 2
	if now < pool.feedUntil and pool.rate > 0 then
		pool.area += pool.rate * dt
	end
	-- the front: where the blood poured so far gets to...
	local plain = math.sqrt(pool.area / math.pi)
	local front: number
	if big then
		-- ...thinner and thinner as it goes on spreading (its edge slows
		-- down, it never jumps), until `spreadTime`
		local age = now - pool.born
		local creep = math.min(1, ((age + 1) / (pool.spreadTime + 1)) ^ CREEP_POWER)
		front = math.min(plain, pool.maxRadius * 1.3) * creep
	else
		-- (a bleeder's: up to its maxRadius, fast at first, slower after)
		local R = pool.maxRadius
		front = R * (1 - math.exp(-plain / R)) * spec.visible
	end
	pool.front = math.max(pool.front, front, START_RADIUS)
	-- the middle: never past a wall or a ledge (through a thin wall, floating
	-- in the air). The tongues check the ground a little beyond it first;
	-- the ones stopped close by push it the other way (a pool against a
	-- wall spreads on its free side), and it shrinks if it still doesn't fit.
	local core = pool.front * spec.core
	local reachOut = core * pool.extent
	for _, tongue in pool.tongues do
		probeTongue(pool, tongue, math.max(tongue.reach, reachOut + 0.3))
	end
	local offset = Vector3.zero
	for _ = 1, 3 do
		for _, tongue in pool.tongues do
			local stop = tongue.stop
			if stop then
				local over = offset:Dot(tongue.dir) + reachOut - stop
				if over > 0 then
					offset -= tongue.dir * over
				end
			end
		end
		if offset.Magnitude > core * 0.6 then
			offset = offset.Unit * core * 0.6
		end
	end
	-- (it only ever moves a little at a time: no jump)
	pool.coreOffset = pool.coreOffset:Lerp(offset, math.min(1, dt * 2))
	for _, tongue in pool.tongues do
		local stop = tongue.stop
		if stop then
			reachOut = math.min(reachOut, math.max(stop - pool.coreOffset:Dot(tongue.dir), 0))
		end
	end
	pool.radius = math.max(reachOut / pool.extent, math.min(START_RADIUS, pool.front))
	-- each tongue: how far it would go (slopes), and the blood that can't go
	-- where a tongue is stopped goes to the ones beside it (along a wall)
	local tongues = pool.tongues
	local count = #tongues
	for _, tongue in tongues do
		tongue.natural = pool.front
			* tongue.f
			* slopeFactor(pool, tongue.dir, tongue.slope, 0.4, 2.2)
		tongue.boost = 0
	end
	for i, tongue in tongues do
		local stop = tongue.stop
		if stop and tongue.natural > stop then
			local lost = (tongue.natural - stop) * 0.5
			for _, pair in { { 1, 0.35 }, { -1, 0.35 }, { 2, 0.15 }, { -2, 0.15 } } do
				local other = tongues[((i - 1 + pair[1]) % count) + 1]
				if other ~= tongue and other.stop == nil then
					other.boost += lost * pair[2]
				end
			end
		end
	end
	for _, tongue in tongues do
		local target = tongue.natural + math.min(tongue.boost, pool.front * 0.8)
		if tongue.stop then
			target = math.min(target, tongue.stop :: number)
		end
		if target > tongue.reach then
			local move = (target - tongue.reach) * (1 - math.exp(-dt / tongue.lag))
			tongue.reach += math.min(move, MAX_SPEED * dt)
		end
		probeTongue(pool, tongue, tongue.reach)
		if tongue.stop then
			tongue.reach = math.min(tongue.reach, tongue.stop :: number)
		end
		if
			tongue.stopKind == "drop"
			and not tongue.ran
			and tongue.reach >= (tongue.stop :: number) - 0.1
		then
			-- at the edge: it runs over, down the side
			tongue.ran = true
			local edge = pool.center + tongue.dir * tongue.reach + pool.normal * tongue.lastH
			BloodStain.overLedge(edge, tongue.dir, math.min(0.16, pool.front * 0.25))
		end
		-- a big pool reaching a step down goes on below it
		if
			big
			and tongue.stopKind == "drop"
			and not tongue.spilled
			and tongue.finger == nil
			and tongue.low
			and pool.partsLeft > 0
			and tongue.reach >= (tongue.stop :: number) - 0.05
		then
			tongue.spilled = true
			local low = tongue.low :: RaycastResult
			local finger: Finger = {
				parent = nil,
				parts = {},
				extra = math.min(pool.full * 0.4, FINISHER_POOLS.FINGER_REACH * 0.5),
				speed = 0.25,
				width = math.clamp(pool.full * 0.12, 0.3, 0.7),
				side = if tongue.layer % 2 == 0 then 1 else -1,
				grown = 0,
				done = false,
			}
			newPart(pool, finger, low.Position + tongue.dir * 0.1, low.Normal, tongue.dir)
			table.insert(pool.fingers, finger)
		end
	end
	-- the fingers: once the pool is big enough, a few tongues run on
	if pool.front >= spec.fingerStart * pool.full then
		for _, finger in pool.fingers do
			if not finger.done then
				local dir = if #finger.parts > 0
					then finger.parts[#finger.parts].dir
					else (finger.parent :: Tongue).dir
				local downhill = slopeFactor(pool, dir, 0, 0.3, 2.5)
				local grow = finger.speed
					* dt
					* downhill
					* math.max(0.35, 1 - finger.grown / finger.extra)
				growFinger(pool, finger, grow)
				if finger.grown >= finger.extra then
					finger.done = true
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------

-- A stretched tongue picture covering from `a` to `b` studs along `dir` from
-- `origin`, `width` studs wide. Made the first time, moved and grown after.
local function drawLobe(
	pool: Pool,
	record: BloodAge.Record?,
	l0: number,
	w0: number,
	origin: Vector3,
	normal: Vector3,
	dir: Vector3,
	a: number,
	b: number,
	width: number,
	layer: number,
	glossy: boolean,
	drying: number
): (BloodAge.Record?, number, number)
	local length = if LOBE_PICTURE then (b - a) / (LOBE_TO - LOBE_FROM) else b - a
	local wide = if LOBE_PICTURE then width / LOBE_WIDE else width
	local middle = if LOBE_PICTURE then a - LOBE_FROM * length else (a + b) / 2
	local at = origin + dir * middle
	if record == nil then
		-- (its look picked from the pool's seed and where it is in the pool)
		local made = BloodStain.place("poolLobe", at, normal, dir, wide, length, {
			random = Random.new(pool.look * 131 + layer * 7919 + #pool.tongues),
			profile = "pool",
			start = PALETTE.ARTERIAL, -- (the moving front: fresh, brighter)
			gloss = if glossy then (if LOBE_PICTURE then 0.3 else 0.6) else nil,
			pinned = true,
			noEdge = true,
			priority = 3,
			life = pool.life,
			layer = layer,
		})
		if made then
			-- (a tongue is the thin edge of a pool: it dries first)
			made.speed *= drying
		end
		return made, length, wide
	end
	BloodStain.fit(record, at, dir, length / l0, wide / w0)
	return record, l0, w0
end

local function draw(pool: Pool, fresh: boolean)
	local record = pool.record
	if record == nil or record.dead then
		return
	end
	-- the middle
	local offset = pool.coreOffset
	if math.abs(pool.radius - pool.coreDrawn) > 0.01 or (offset - pool.coreAt).Magnitude > 0.01 then
		pool.coreDrawn = pool.radius
		pool.coreAt = offset
		local size = pool.radius * 2 / pool.cover
		local k = size / pool.core0
		BloodStain.fit(record, pool.center + offset - pool.forward * pool.shift * size, nil, k, k)
	end
	if fresh then
		BloodAge.touch(record)
	end
	local count = #pool.tongues
	local spread = math.sin(math.pi / math.max(count, 3)) * 2
	for _, tongue in pool.tongues do
		local a = pool.radius * 0.55
		local b = tongue.reach
		if b - a > 0.12 and b - tongue.drawn > 0.01 then
			local moved = b - tongue.drawn > 0.02
			tongue.drawn = b
			local width = math.min(b * spread * tongue.wide, b * 1.1)
			tongue.record, tongue.l0, tongue.w0 = drawLobe(
				pool,
				tongue.record,
				tongue.l0,
				tongue.w0,
				pool.center,
				pool.normal,
				tongue.dir,
				a,
				b,
				width,
				tongue.layer,
				tongue.glossy,
				LOBE_DRYING
			)
			local made = tongue.record
			if made and moved and not made.dead then
				BloodAge.touch(made) -- (its moving front: wet and bright)
			end
		end
	end
	for _, finger in pool.fingers do
		local parent = finger.parent
		for _, part in finger.parts do
			local origin, a, b
			if part.attached and parent then
				origin = pool.center
				a = math.max(parent.reach - 0.4, 0)
				b = math.max(part.tip, parent.reach)
			else
				origin = part.base
				a = -0.15
				b = part.tip
			end
			if b - a > 0.2 and b - part.drawn > 0.01 then
				local moved = b - part.drawn > 0.02
				part.drawn = b
				local width = finger.width * (0.6 + 0.4 * math.min(1, (b - a) / 1.5))
				part.record, part.l0, part.w0 = drawLobe(
					pool,
					part.record,
					part.l0,
					part.w0,
					origin,
					part.normal,
					part.dir,
					a,
					b,
					width,
					part.layer,
					false,
					FINGER_DRYING
				)
				local made = part.record
				if made and moved and not made.dead then
					BloodAge.touch(made)
				end
			end
		end
	end
end

-- Is it still spreading?
local function moving(pool: Pool, now: number): boolean
	if now < pool.feedUntil + pool.spec.tail then
		return true
	end
	if pool.priority >= 2 and now < pool.born + pool.spreadTime + 2 then
		return true
	end
	-- (fingers still creeping, a little longer at most)
	if now < pool.born + pool.spreadTime + 20 then
		for _, finger in pool.fingers do
			if not finger.done then
				return true
			end
		end
	end
	return false
end

-- A finisher's pool already there (a body we only see after it happened):
-- `size` studs across, fully spread at once (its tongues and fingers run
-- their whole course now, the same as the live one). Once per `seed`
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
	-- (as if it had been spreading all this time: run it to its end now,
	-- half a second at a time, and draw it once)
	local now = os.clock()
	pool.born = math.min(pool.born, now - spreadTime - 1)
	pool.feedUntil = 0
	for _ = 1, 160 do
		step(pool, 0.5, now)
		if not moving(pool, now) then
			break
		end
		local still = true
		for _, tongue in pool.tongues do
			local target = tongue.natural + tongue.boost
			if tongue.stop == nil and target - tongue.reach > 0.02 then
				still = false
				break
			end
		end
		if still then
			local fingersDone = true
			for _, finger in pool.fingers do
				fingersDone = fingersDone and finger.done
			end
			if fingersDone then
				break
			end
		end
	end
	for _, finger in pool.fingers do
		finger.done = true
	end
	pool.fedArea = pool.area
	draw(pool, false)
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
			local gap = position - pool.center
			local flat = gap - pool.normal * gap:Dot(pool.normal)
			if math.abs(gap:Dot(pool.normal)) < 1 and flat.Magnitude < pool.front * 1.05 + 0.15 then
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
			-- (blood came in since last time: its middle is wet and red again)
			local fed = pool.area > pool.fedArea + 1e-4
			pool.fedArea = pool.area
			draw(pool, fed)
		end
		index += 1
	end
	debug.profileend()
end)

return table.freeze(BloodPool)
