--!strict
-- Validate: the firearm shot checks of ARCHITECTURE §9.3 that need no Roblox world,
-- written as functions of plain inputs so Lune tests can feed them fake shots
-- (tools/anim/firearms_test.luau). The world checks (raycasts, rewound bodies) are
-- in Firearms/init and use these for their decisions.
--
--   Validate.shot(args...)        types and ranges of a FireShot -> Shot | (nil, reason)
--   Validate.newBucket(def)        a per-weapon token bucket
--   Validate.rate(bucket, def, now) -> ok, reason: the weapon's own rate (rpm × margin,
--                                  and a minimum interval between accepted shots)
--   Validate.time(shotTime, now, rewindMax) -> age (seconds back) or nil
--   Validate.origin(head, origin, speed, slack) -> ok
--   Validate.aim(direction, aimPitch?, rootLook) -> ok, reason
--   Validate.spreadRange(def, stance, speedFraction, crouched, bipod, bloom) -> lo, hi
--   Validate.claimedHits(def, origin, direction, seed, lo, hi, hits) -> { HitClaim } (each with
--                                  its pellet and distance; impossible ones dropped)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ballistics = require(ReplicatedStorage.Shared.Firearms.Ballistics)
local Types = require(ReplicatedStorage.Shared.Firearms.Types)

type Def = Types.FirearmDef

local FC = Config.Firearms

local Validate = {}

local R6_PARTS = table.freeze({
	Head = true,
	Torso = true,
	HumanoidRootPart = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
	["Right Leg"] = true,
	["Left Leg"] = true,
})

export type HitClaim = {
	model: Model,
	part: string,
	at: Vector3,
	pellet: number,
	distance: number,
}

export type Shot = {
	shotId: number,
	weaponId: string,
	shotTime: number,
	origin: Vector3,
	direction: Vector3,
	hits: { HitClaim },
}

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function finiteVector(v: unknown): boolean
	if typeof(v) ~= "Vector3" then
		return false
	end
	local vec = v :: Vector3
	return finite(vec.X) and finite(vec.Y) and finite(vec.Z)
end

-- Types and ranges. `lastShotId`: shot ids must increase.
function Validate.shot(
	shotId: unknown,
	weaponId: unknown,
	shotTime: unknown,
	origin: unknown,
	direction: unknown,
	hits: unknown,
	lastShotId: number
): (Shot?, string?)
	if typeof(shotId) ~= "number" or not finite(shotId) or shotId % 1 ~= 0 then
		return nil, "shotId"
	end
	if shotId <= lastShotId or shotId > lastShotId + 10000 then
		return nil, "shotId"
	end
	if typeof(weaponId) ~= "string" or #weaponId > 32 then
		return nil, "weapon"
	end
	if typeof(shotTime) ~= "number" or not finite(shotTime) then
		return nil, "time"
	end
	if not finiteVector(origin) or not finiteVector(direction) then
		return nil, "vector"
	end
	local dir = direction :: Vector3
	if math.abs(dir.Magnitude - 1) > 0.02 then
		return nil, "direction"
	end
	local list: { HitClaim } = {}
	if hits ~= nil then
		if typeof(hits) ~= "table" then
			return nil, "hits"
		end
		local raw = hits :: { any }
		if #raw > FC.MAX_HITS then
			return nil, "hits"
		end
		for _, item in raw do
			if typeof(item) ~= "table" then
				return nil, "hits"
			end
			local model, part, at, pellet = item.model, item.part, item.at, item.pellet
			if typeof(model) ~= "Instance" or not (model :: Instance):IsA("Model") then
				return nil, "hits"
			end
			if typeof(part) ~= "string" or not R6_PARTS[part] then
				return nil, "hits"
			end
			if not finiteVector(at) or typeof(pellet) ~= "number" or not finite(pellet) then
				return nil, "hits"
			end
			table.insert(list, {
				model = model :: Model,
				part = part :: string,
				at = at :: Vector3,
				pellet = pellet :: number,
				distance = 0,
			})
		end
	end
	return {
		shotId = shotId :: number,
		weaponId = weaponId :: string,
		shotTime = shotTime :: number,
		origin = origin :: Vector3,
		direction = dir.Unit,
		hits = list,
	},
		nil
end

export type Bucket = { tokens: number, at: number, lastShot: number }

function Validate.newBucket(): Bucket
	return { tokens = FC.RATE_BURST, at = -math.huge, lastShot = -math.huge }
end

function Validate.rate(bucket: Bucket, def: Def, now: number): (boolean, string?)
	local interval = 60 / def.rpm
	if now - bucket.lastShot < interval * FC.MIN_INTERVAL then
		return false, "rate"
	end
	local refill = def.rpm / 60 * FC.RATE_MARGIN
	if bucket.at > -math.huge then
		bucket.tokens = math.min(FC.RATE_BURST, bucket.tokens + (now - bucket.at) * refill)
	end
	bucket.at = now
	if bucket.tokens < 1 then
		return false, "rate"
	end
	bucket.tokens -= 1
	bucket.lastShot = now
	return true, nil
end

-- How far back the shooter saw the world, or nil if the time is impossible.
function Validate.time(shotTime: number, now: number, rewindMax: number): number?
	if shotTime > now + FC.FUTURE_SLACK or shotTime < now - rewindMax - 0.1 then
		return nil
	end
	return math.clamp(now - shotTime, 0, rewindMax)
end

function Validate.origin(head: Vector3, origin: Vector3, speed: number, slack: number): boolean
	return (origin - head).Magnitude <= slack + speed * FC.ORIGIN_SPEED_SLACK
end

-- The shot's direction against what the server knows of the aim: the stream's pitch
-- (when recent) and the body's facing.
function Validate.aim(direction: Vector3, aimPitch: number?, rootLook: Vector3): (boolean, string?)
	local pitch = math.deg(math.asin(math.clamp(direction.Y, -1, 1)))
	if aimPitch and math.abs(pitch - aimPitch) > FC.AIM_TOLERANCE then
		return false, "pitch"
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local look = Vector3.new(rootLook.X, 0, rootLook.Z)
	if flat.Magnitude > 0.2 and look.Magnitude > 0.2 then
		local yaw = math.deg(math.acos(math.clamp(flat.Unit:Dot(look.Unit), -1, 1)))
		if yaw > FC.YAW_TOLERANCE then
			return false, "yaw"
		end
	end
	return true, nil
end

function Validate.spreadRange(
	def: Def,
	stance: string,
	speedFraction: number,
	crouched: boolean,
	bipod: boolean,
	bloom: number
): (number, number)
	local expected = Ballistics.spreadFor(def, stance, speedFraction, crouched, bipod, bloom)
	-- the lowest any stance could give (the client may be a frame ahead of the stream)
	local floor = Ballistics.spreadFor(def, "Aim", 0, true, bipod, 0)
	local lo = math.min(expected * FC.SPREAD_LOW, floor)
	local hi = expected * FC.SPREAD_HIGH + 0.3
	return lo, hi
end

-- The claimed hits that a bullet / pellet of this shot could have made, each tagged
-- with its pellet (1..n) and distance; within range; one body per pellet plus the
-- gun's pierce. (Walls and bodies are checked by the caller.)
function Validate.claimedHits(
	def: Def,
	origin: Vector3,
	direction: Vector3,
	seed: number,
	lo: number,
	hi: number,
	hits: { HitClaim }
): { HitClaim }
	local matched: { HitClaim } = {}
	for _, hit in hits do
		local offset = hit.at - origin
		local distance = offset.Magnitude
		if distance > 0.05 and distance <= def.range then
			local pellet = Ballistics.matchesShot(
				def,
				direction,
				seed,
				lo,
				hi,
				offset / distance,
				FC.PELLET_TOLERANCE
			)
			if pellet then
				hit.pellet = pellet
				hit.distance = distance
				table.insert(matched, hit)
			end
		end
	end
	-- the nearest body takes each bullet (pierce: the next ones too); a shotgun's
	-- pellets each hit once, a body can take several pellets
	table.sort(matched, function(a, b)
		return a.distance < b.distance
	end)
	local out: { HitClaim } = {}
	local perPellet: { [number]: number } = {}
	for _, hit in matched do
		local count = perPellet[hit.pellet] or 0
		if count <= def.pierce then
			perPellet[hit.pellet] = count + 1
			table.insert(out, hit)
		end
	end
	return out
end

return table.freeze(Validate)
