--!strict
-- Ballistics: the pure maths both sides share, so the server recomputes exactly what
-- the shooter's client did (ARCHITECTURE §9.2-9.3). No Roblox services: Lune tests run
-- it (tools/anim/firearms_test.luau).
--
--   Ballistics.seed(salt, shotId)            -> the shot's seed (salt: per life, from the server)
--   Ballistics.offsets(def, seed)            -> { {a, b} } unit-disc offsets: [1] the shot's centre,
--                                               [2..] the pellets' pattern (shotgun)
--   Ballistics.directions(def, dir, seed, spread) -> { Vector3 } the bullet / pellet directions
--   Ballistics.spreadFor(def, stance, speedFraction, crouched, bipod, bloom) -> degrees
--   Ballistics.bloomAfter(def, bloom, dt)    -> the bloom a shot `dt` after the last one starts with
--   Ballistics.matchesShot(def, dir, seed, spreadLo, spreadHi, hitDir, tolerance)
--                                            -> pellet index (1..n) whose direction, for SOME
--                                               spread in [lo, hi], is within `tolerance`
--                                               degrees of hitDir; nil if none
--   Ballistics.falloff(def, distance)        -> damage multiplier
--   Ballistics.zoneOf(partName)              -> "Head" / "Torso" / "Arms" / "Legs" / nil
--   Ballistics.damage(def, zone, distance, scale) -> damage of one bullet / pellet
--   Ballistics.restBoxes(root)               -> R6 rest-pose body boxes round a root CFrame
--   Ballistics.rayRestBody(origin, dir, length, root, slackH, slackV)
--                                            -> t (0..1 of the ray), part name; nil if it misses
--
-- Stances: "Hip" (not shouldered), "Ready", "Aim".

local Types = require(script.Parent.Types)
local BoxMath = require(script.Parent.Parent.Util.BoxMath)

type Def = Types.FirearmDef

local Ballistics = {}

local TWO32 = 4294967296

-- (a * b) mod 2^32 without losing precision (doubles hold 53 bits)
local function mul32(a: number, b: number): number
	local high, low = a // 65536, a % 65536
	return ((high * b) % 65536 * 65536 + low * b) % TWO32
end

local function mix(x: number): number
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x45D9F3B)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x45D9F3B)
	return bit32.bxor(x, bit32.rshift(x, 16))
end

function Ballistics.seed(salt: number, shotId: number): number
	local a = math.floor(math.abs(salt)) % TWO32
	local b = math.floor(math.abs(shotId)) % TWO32
	local s = mix(bit32.bxor(a, mul32(b, 0x9E3779B1)))
	return if s == 0 then 1 else s
end

-- xorshift32 stream from a seed: numbers in [0, 1)
local function stream(seed: number): () -> number
	local x = seed % TWO32
	if x == 0 then
		x = 0x6D2B79F5
	end
	return function(): number
		x = bit32.bxor(x, bit32.lshift(x, 13))
		x = bit32.bxor(x, bit32.rshift(x, 17))
		x = bit32.bxor(x, bit32.lshift(x, 5))
		return x / TWO32
	end
end

-- Points in the unit disc, weighted to the centre (r = u: a real group is denser in
-- the middle than a flat disc).
function Ballistics.offsets(def: Def, seed: number): { { number } }
	local nextNumber = stream(seed)
	local count = 1 + (def.spread.pellets or 0)
	local out = table.create(count)
	for _ = 1, count do
		local r = nextNumber()
		local angle = nextNumber() * 2 * math.pi
		table.insert(out, { r * math.cos(angle), r * math.sin(angle) })
	end
	return out
end

local function basis(dir: Vector3): (Vector3, Vector3)
	local up = if math.abs(dir.Y) < 0.99 then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	local right = dir:Cross(up).Unit
	return right, right:Cross(dir).Unit
end

local function deflect(dir: Vector3, right: Vector3, up: Vector3, a: number, b: number): Vector3
	return (dir + right * math.tan(math.rad(a)) + up * math.tan(math.rad(b))).Unit
end

-- Pellet i's offset (degrees) for a spread s: the shot's centre moves with s, the
-- pellets keep their pattern round it.
local function pelletOffset(def: Def, offsets: { { number } }, i: number, s: number): (number, number)
	local centre = offsets[1]
	if i == 1 and (def.spread.pellets or 0) == 0 then
		return centre[1] * s, centre[2] * s
	end
	local cone = def.spread.pelletCone or 0
	local p = offsets[i]
	return centre[1] * s + p[1] * cone, centre[2] * s + p[2] * cone
end

local function pelletRange(def: Def): (number, number)
	local pellets = def.spread.pellets or 0
	if pellets == 0 then
		return 1, 1
	end
	return 2, 1 + pellets
end

function Ballistics.directions(def: Def, dir: Vector3, seed: number, spread: number): { Vector3 }
	local unit = dir.Unit
	local right, up = basis(unit)
	local offsets = Ballistics.offsets(def, seed)
	local first, last = pelletRange(def)
	local out = {}
	for i = first, last do
		local a, b = pelletOffset(def, offsets, i, spread)
		table.insert(out, deflect(unit, right, up, a, b))
	end
	return out
end

function Ballistics.spreadFor(
	def: Def,
	stance: string,
	speedFraction: number,
	crouched: boolean,
	bipod: boolean,
	bloom: number
): number
	local sp = def.spread
	local base = if stance == "Aim" then sp.ads elseif stance == "Ready" then sp.ready else sp.hip
	base += sp.moving * math.clamp(speedFraction, 0, 1.5)
	if crouched then
		base *= sp.crouch
	end
	if bipod and sp.bipod then
		base *= sp.bipod
	end
	return base + bloom
end

function Ballistics.bloomAfter(def: Def, bloom: number, dt: number): number
	local sp = def.spread
	return math.clamp(bloom - sp.recover * math.max(dt, 0), 0, sp.max)
end

-- Distance (degrees) from point p to the segment a -> b, all in the offset plane.
local function toSegment(px: number, py: number, ax: number, ay: number, bx: number, by: number): number
	local dx, dy = bx - ax, by - ay
	local len2 = dx * dx + dy * dy
	local t = if len2 > 1e-12 then math.clamp(((px - ax) * dx + (py - ay) * dy) / len2, 0, 1) else 0
	local qx, qy = ax + dx * t - px, ay + dy * t - py
	return math.sqrt(qx * qx + qy * qy)
end

function Ballistics.matchesShot(
	def: Def,
	dir: Vector3,
	seed: number,
	spreadLo: number,
	spreadHi: number,
	hitDir: Vector3,
	tolerance: number
): number?
	local unit = dir.Unit
	local hit = hitDir.Unit
	local forward = hit:Dot(unit)
	if forward <= 0 then
		return nil
	end
	local right, up = basis(unit)
	local hx = math.deg(math.atan(hit:Dot(right) / forward))
	local hy = math.deg(math.atan(hit:Dot(up) / forward))
	local offsets = Ballistics.offsets(def, seed)
	local first, last = pelletRange(def)
	for i = first, last do
		local ax, ay = pelletOffset(def, offsets, i, spreadLo)
		local bx, by = pelletOffset(def, offsets, i, spreadHi)
		if toSegment(hx, hy, ax, ay, bx, by) <= tolerance then
			return i - first + 1
		end
	end
	return nil
end

function Ballistics.falloff(def: Def, distance: number): number
	local f = def.falloff
	if distance <= f.full then
		return 1
	end
	if distance >= f.zero then
		return f.min
	end
	local t = (distance - f.full) / (f.zero - f.full)
	return 1 + (f.min - 1) * t
end

local PART_ZONES: { [string]: Types.Zone } = {
	Head = "Head",
	Torso = "Torso",
	HumanoidRootPart = "Torso",
	["Right Arm"] = "Arms",
	["Left Arm"] = "Arms",
	["Right Leg"] = "Legs",
	["Left Leg"] = "Legs",
}

function Ballistics.zoneOf(partName: string): Types.Zone?
	return PART_ZONES[partName]
end

function Ballistics.damage(def: Def, zone: Types.Zone, distance: number, scale: number): number
	return def.damage * def.zones[zone] * Ballistics.falloff(def, distance) * scale
end

-- R6 at rest, round its HumanoidRootPart: the boxes a bullet is tested against
-- (the head is the visible head mesh, not the 2×1×1 part).
local REST = table.freeze({
	{ name = "Head", offset = CFrame.new(0, 1.5, 0), size = Vector3.new(1.25, 1.2, 1.2) },
	{ name = "Torso", offset = CFrame.identity, size = Vector3.new(2, 2, 1) },
	{ name = "Right Arm", offset = CFrame.new(1.5, 0, 0), size = Vector3.new(1, 2, 1) },
	{ name = "Left Arm", offset = CFrame.new(-1.5, 0, 0), size = Vector3.new(1, 2, 1) },
	{ name = "Right Leg", offset = CFrame.new(0.5, -2, 0), size = Vector3.new(1, 2, 1) },
	{ name = "Left Leg", offset = CFrame.new(-0.5, -2, 0), size = Vector3.new(1, 2, 1) },
})

function Ballistics.restBoxes(root: CFrame): { { name: string, cf: CFrame, size: Vector3 } }
	local out = {}
	for _, box in REST do
		table.insert(out, { name = box.name, cf = root * box.offset, size = box.size })
	end
	return out
end

function Ballistics.rayRestBody(
	origin: Vector3,
	dir: Vector3,
	length: number,
	root: CFrame,
	slackH: number,
	slackV: number
): (number?, string?)
	local ray = dir.Unit * length
	local best, bestName = math.huge, nil
	-- the tight boxes first (the zone of a clean hit), then the inflated ones
	for pass = 1, 2 do
		local grow = if pass == 1 then Vector3.zero else Vector3.new(slackH * 2, slackV * 2, slackH * 2)
		for _, box in REST do
			local t = BoxMath.rayHitsBox(origin, ray, root * box.offset, box.size + grow)
			if t and t <= 1 and t < best then
				best, bestName = t, box.name
			end
		end
		if bestName then
			return best, bestName
		end
	end
	return nil, nil
end

return table.freeze(Ballistics)
