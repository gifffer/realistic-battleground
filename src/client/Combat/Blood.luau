--!strict
-- Blood: how blood looks when it leaves a body - every client, client-side.
--
-- What real blood does, and how it is drawn here:
--   • DROPS: thrown out of a wound, many small and a few big ones. They fly
--     (gravity, a little air drag), STRETCH along their speed (a fast drop
--     is a streak, not a ball) and splash wherever they land: the floor, a
--     wall, a body (someone's clothes, the attacker's fist).
--   • STRANDS: blood is thick. A heavy blow pulls strings of it out, a gob
--     at the front dragging a thinning thread behind it, that stretches
--     until it snaps into drops.
--   • SPLATS (BloodStain draws them): their shape tells how the drop
--     arrived, like in forensics. Straight down: round with a scalloped
--     edge. Slanted: an oval, then a "!" whose tail points where it was
--     going, and a grazing drop a long streak (length = width / sin(angle)).
--     A fast one throws a fan of tiny satellite drops. On a wall it RUNS
--     down slowly, a bead at its tip. A big one on the floor stays a small
--     wet pool (and feet step in it, BloodTracks).
--   • It is WET at first (glossy, red) and DRIES (darker, a dark clotting
--     edge, then matte brown-black) - BloodAge, one system for all of it.
--   • A fine red MIST hangs a moment in the air on hard blows.
--   • (v2) A drop that DRIPS (falls from a wound, not thrown) falls slowly
--     (Config.Blood.PASSIVE_GRAVITY: real drops are light) and lands as a
--     round crenellated "drip"; the higher it fell, the more tiny satellite
--     drops ring it (a "starburst" past ~1 m). A big drop falling far on a
--     hard or wet floor splashes a CROWN (fingers rising, breaking into
--     droplets). A drop falling into a wet pool makes a RIPPLE ring and
--     throws tiny drops around the pool, where they pile up.
--
--   Blood.spray(point, direction, amount, source, noMist?, random?)  a wound
--       opening: drops (and strands if amount >= 1) out of `point` along
--       `direction`; `amount` 1 = a punch that cuts, 2-3 = a heavy blow, 5+ =
--       gore. `random`: a seeded Random, the same spray on every client.
--   Blood.splat(position, normal, size, velocity?, onto?, random?, info?)  a
--       splash on a surface (`onto`: the part hit; a body part keeps it).
--       `info` (SplatInfo below): how far it fell, a drip or thrown, its colour...
--   Blood.drop(position, velocity, size, random?, gravity?, info?)  one drop.
--       A wound dripping: gravity = Blood.passiveScale(), info = {passive = true}.
--   Blood.passiveScale()  the `gravity` multiplier of a drop that drips
--   Blood.dripEmitter(emitter)  a dripping emitter: slow fall, hanging drops
--   Blood.ballistic(origin, velocity, size, options?)  a drop whose landing
--       is computed once (no part flying): for particle bursts, so what flies
--       also lands. Returns where it lands.
--   Blood.landings(origin, direction, spread, speeds, count, sizes, random, ignore?)
--       a few of those for a burst of particles (the marks it leaves).
--   Blood.run(at, normal, width, options?)  blood running down (a wall, the
--       skin); returns the run (its tip: where it drips from).
--   Blood.smear(position, normal, velocity, width, onto?)  a wet swipe.
--   Blood.mist(point, direction, amount)
--   Blood.strand(point, velocity, thickness)  one string of thick blood.
--   Blood.droplets(emitter, kind)  dresses a ParticleEmitter as drops of
--       blood if the pictures are uploaded (else it keeps its own look).
--   Blood.seed(...)  a number from the event (same on every client).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local BloodAge = require(script.Parent.BloodAge)
local BloodPool = require(script.Parent.BloodPool)
local BloodStain = require(script.Parent.BloodStain)

local Blood = {}

local PALETTE = Config.Blood.PALETTE
Blood.PALETTE = PALETTE
Blood.FRESH = PALETTE.ARTERIAL -- bright, just out (oxygenated)
Blood.DARK = PALETTE.VENOUS -- a few seconds later
Blood.DRY = PALETTE.DRY -- dried

local WORLD = Config.Blood.WORLD
local MAX_STRANDS = 24
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local UP = Vector3.new(0, 1, 0)
local DOWN = Vector3.new(0, -1, 0)
local X_AXIS = Vector3.new(1, 0, 0)

local random = Random.new()

local folder = BloodStain.folder

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { folder }
params.IgnoreWater = false

local isBody = BloodStain.isBody
Blood.onSkin = BloodStain.onSkin

function Blood.enabled(): boolean
	return Config.Blood.ENABLED
end

-- How a splash came to be (all optional). Filled in by the drops themselves
-- when they land; a caller can force its colour / kind / ageing.
export type SplatInfo = {
	height: number?, -- how far it fell (studs): satellites / crown grow with it
	passive: boolean?, -- a drip (not thrown): a round "drip" stain when it lands straight
	start: Color3?, -- its colour fresh (spit: PALETTE.SALIVA)
	kind: string?, -- force the stain's kind ("spit")
	profile: string?, -- force its ageing ("saliva")
	dropSize: number?, -- (the drop's own size, studs: big ones splash a crown)
	material: Enum.Material?, -- (the ground it hit)
	micro: boolean?, -- (a tiny drop thrown by a splash: no crown, no ripple)
}

-- Options of Blood.ballistic (a drop whose landing is computed at once).
export type BallisticOptions = {
	ignore: { Instance }?, -- (bodies its path goes through: the wound's own)
	random: Random?,
	delay: number?, -- (seconds before it leaves)
	gravity: number?, -- studs/s² (default workspace.Gravity; a drip: Config.Blood.PASSIVE_GRAVITY)
	info: SplatInfo?, -- given to its splash (its colour, kind...)
}

-- The `gravity` multiplier (× workspace.Gravity) of a drop that only DRIPS:
-- Config.Blood.PASSIVE_GRAVITY studs/s². Read each time: a place can change
-- its gravity.
function Blood.passiveScale(): number
	return Config.Blood.PASSIVE_GRAVITY / math.max(workspace.Gravity, 1)
end

-- Is this camera close enough to `point` for the small details (crowns,
-- ripples)? And is it looking steeply down (a crown sprite would read as a
-- flat card from above)?
local function closeDetail(point: Vector3): (boolean, boolean)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return false, false
	end
	local close = (camera.CFrame.Position - point).Magnitude <= WORLD.CROWN_RANGE
	return close, camera.CFrame.LookVector.Y < -0.87 -- (steeper than 60°)
end

-- A whole number from the event's values (an attack id, a name...): the
-- same on every client, so everyone sees the same blood.
function Blood.seed(...: any): number
	local hash = 5381
	for index = 1, select("#", ...) do
		local text = tostring((select(index, ...)))
		for k = 1, #text do
			hash = (hash * 33 + string.byte(text, k)) % 2147483647
		end
		hash = (hash * 31 + 7) % 2147483647
	end
	return hash
end

-- Can blood land on what a ray hit? Not on an invisible part (a map's
-- invisible wall, a hitbox): the blood would hang in the air. A body's
-- invisible root still counts (BloodStain moves it onto the torso).
local function solid(hit: RaycastResult): boolean
	local instance = hit.Instance
	if instance:IsA("Terrain") or not instance:IsA("BasePart") then
		return true
	end
	return instance.Transparency < 0.95 or isBody(instance) ~= nil
end

local function newPiece(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0.12
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

------------------------------------------------------------------------------
-- Runs: blood running down a wall / the skin (one updater for all of them)
------------------------------------------------------------------------------

export type Run = {
	record: BloodAge.Record,
	length: number, -- how far it will run
	reach: number, -- how far it has run
	started: number,
	time: number, -- seconds to get there
	image: boolean,
}

local runs: { Run } = {}

export type RunOptions = {
	onto: BasePart?, -- a body part: it runs down its skin
	random: Random?,
	length: number?, -- (else from its width: more blood runs further)
	start: Color3?,
	owner: Model?,
	alpha: number?,
	fork: boolean?, -- (false: never splits in two)
}

-- How far `down` can go from `at` on a body part's face before its edge.
local function roomOnFace(part: BasePart, at: Vector3, down: Vector3): number
	if part.Name == "Head" then
		return 0.35
	end
	local l = part.CFrame:PointToObjectSpace(at)
	local d = part.CFrame:VectorToObjectSpace(down)
	local h = part.Size / 2
	local room = math.huge
	for _, axis in { "X", "Y", "Z" } do
		local dv = (d :: any)[axis] :: number
		if math.abs(dv) > 1e-3 then
			local lv = (l :: any)[axis] :: number
			local hv = (h :: any)[axis] :: number
			local limit = if dv > 0 then (hv - 0.03 - lv) / dv else (-hv + 0.03 - lv) / dv
			room = math.min(room, math.max(0, limit))
		end
	end
	return room
end

-- Blood running down from `at` (on a surface facing `normal`): a trail
-- growing down slowly (fast at first, then slowing as it thins), a bead at
-- its tip; sometimes it splits in two. Returns the run (nil: nowhere).
function Blood.run(at: Vector3, normal: Vector3, width: number, options: RunOptions?): Run?
	if not Config.Blood.ENABLED or #runs >= BloodAge.cap("RUNS") then
		return nil
	end
	local opts: RunOptions = options or {}
	local rng = opts.random or random
	local onto = opts.onto
	local body = if onto then isBody(onto) else nil
	if onto and body then
		local skin, point, out = BloodStain.onSkin(onto, at)
		if skin == nil then
			return nil
		end
		onto, at, normal = skin, point, out
	end
	local down = DOWN - normal * DOWN:Dot(normal)
	if down.Magnitude < 0.3 then
		return nil -- (not steep enough to run)
	end
	down = down.Unit
	local length = opts.length or rng:NextNumber(0.3, 1.6) * math.clamp(width * 4, 0.6, 2.5)
	if onto and body then
		length = math.min(length, roomOnFace(onto, at, down))
		if length < 0.08 then
			return nil
		end
	end
	local record = BloodStain.place("run", at, normal, down, width, 0.05, {
		random = rng,
		onto = onto,
		profile = "run",
		start = opts.start or PALETTE.VENOUS,
		owner = opts.owner or body,
		upright = true,
		turn = math.pi, -- (the picture's top where it starts)
		alpha = opts.alpha,
		noEdge = true,
	})
	if record == nil then
		return nil
	end
	local run: Run = {
		record = record,
		length = length,
		reach = 0.05,
		started = os.clock(),
		time = length * rng:NextNumber(1.5, 3),
		image = BloodStain.hasImage("run"),
	}
	table.insert(runs, run)
	-- (a quarter of them split: a thinner one going off a little sideways)
	if opts.fork ~= false and rng:NextNumber() < 0.25 and length > 0.4 then
		local side = down:Cross(normal) * (if rng:NextNumber() < 0.5 then 1 else -1)
		task.delay(run.time * 0.3, function()
			Blood.run(at + down * length * 0.3 + side * width * 0.4, normal, width * 0.6, {
				onto = onto,
				random = rng,
				length = length * 0.5,
				start = opts.start,
				owner = opts.owner,
				fork = false,
				alpha = opts.alpha,
			})
		end)
	end
	return run
end

-- Where a run's blood is now (its bead: where it drips from).
function Blood.runTip(run: Run): Vector3?
	if run.record.dead then
		return nil
	end
	return BloodStain.worldPoint(run.record, run.reach, 0)
end

local function stepRuns(now: number)
	local index = 1
	while index <= #runs do
		local run = runs[index]
		local t = math.min(1, (now - run.started) / run.time)
		if run.record.dead or t >= 1 then
			runs[index] = runs[#runs]
			runs[#runs] = nil
			continue
		end
		-- (fast at first, then slowing as it thins: viscous)
		run.reach = math.max(0.05, run.length * (1 - (1 - t) ^ 2))
		if run.image then
			BloodStain.movePiece(run.record, 1, run.reach / 2, 0, run.reach)
		else
			BloodStain.movePiece(run.record, 1, run.reach / 2, 0, run.reach)
			BloodStain.movePiece(run.record, 2, run.reach, 0)
		end
		index += 1
	end
end

-- (BloodStain / BloodPool: blood flowing over a ledge runs down its side)
BloodStain.setRunHook(function(at: Vector3, normal: Vector3, width: number)
	Blood.run(at, normal, math.max(width, 0.04))
end)

------------------------------------------------------------------------------
-- Splash details (v2): crowns, ripples, tiny drops. Only near the camera.
------------------------------------------------------------------------------

-- Soft ground swallows a drop: no crown (grass, sand, mud, cloth...).
local SOFT: { [Enum.Material]: boolean } = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Fabric] = true,
	[Enum.Material.Carpet] = true,
	[Enum.Material.Snow] = true,
}

-- A few "splashers" made once and reused (never one per drop): an
-- Attachment on the Terrain with two emitters - the crown picture (a drop
-- flattening, its fingers rising and breaking into droplets, side view) and
-- a couple of specks jumping up.
type Splasher = {
	attachment: Attachment,
	crown: ParticleEmitter?,
	specks: ParticleEmitter?,
	busyUntil: number,
}
local splashers: { Splasher } = {}

local function newSplasher(): Splasher
	local attachment = Instance.new("Attachment")
	attachment.Name = "BloodSplash"
	attachment.Parent = workspace.Terrain
	local crownId = BloodStain.image("crown4x4", nil, 1)
	local crownEmitter: ParticleEmitter? = nil
	if crownId ~= 0 then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Crown"
		e.Texture = "rbxassetid://" .. crownId
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot -- (16 frames once, over its life)
		e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp -- (stays upright)
		e.Lifetime = NumberRange.new(0.22)
		e.Speed = NumberRange.new(0)
		e.Rotation = NumberRange.new(0)
		e.RotSpeed = NumberRange.new(0)
		e.Acceleration = Vector3.zero
		e.Drag = 0
		e.LightInfluence = 0.8
		e.Transparency = NumberSequence.new(0)
		e.Rate = 0
		e.Parent = attachment
		crownEmitter = e
	end
	local speckId = BloodStain.image("pDrop", nil, 1)
	local specksEmitter: ParticleEmitter? = nil
	if speckId ~= 0 then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Specks"
		e.Texture = "rbxassetid://" .. speckId
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(25, 25)
		e.Speed = NumberRange.new(2, 4)
		e.Lifetime = NumberRange.new(0.15, 0.22)
		e.Acceleration = Vector3.new(0, -60, 0)
		e.Size = NumberSequence.new(0.035, 0.02)
		e.LightInfluence = 0.8
		e.Color = ColorSequence.new(PALETTE.ARTERIAL)
		e.Rate = 0
		e.Parent = attachment
		specksEmitter = e
	end
	return { attachment = attachment, crown = crownEmitter, specks = specksEmitter, busyUntil = 0 }
end

-- A splasher free now (at most CAPS.CROWNS at once), or nil.
local function freeSplasher(now: number): Splasher?
	for _, splasher in splashers do
		if now >= splasher.busyUntil and splasher.attachment.Parent then
			return splasher
		end
	end
	if #splashers < BloodAge.cap("CROWNS") then
		local made = newSplasher()
		table.insert(splashers, made)
		return made
	end
	return nil
end

-- (Blood.drop and Blood.ballistic are made further down, with the drops in
-- flight; these two names are filled in there. A function can only call
-- what already exists when it RUNS, and these run long after the module
-- has loaded.)
local dropLater: (Vector3, Vector3, number, Random?, number?, SplatInfo?) -> ()
local ballisticLater: (Vector3, Vector3, number, BallisticOptions?) -> Vector3?

-- A big drop hitting a hard (or wet) floor after a long fall: a crown of
-- fingers rising and breaking into droplets (0.22 s), plus 2-5 real tiny
-- drops thrown out of its rim, on the side it was going (a slanted drop
-- throws them ahead). `width`: its stain's width.
local function crown(
	position: Vector3,
	normal: Vector3,
	width: number,
	color: Color3,
	velocity: Vector3,
	material: Enum.Material?,
	rand: Random
)
	local close, steep = closeDetail(position)
	if not close then
		return
	end
	local wet = BloodPool.wetAt(position) > 0.3
	if material and SOFT[material] and not wet then
		return -- (soaked up by soft ground)
	end
	local now = os.clock()
	local splasher = freeSplasher(now)
	local sprite = if splasher then splasher.crown else nil
	if splasher and sprite and not steep then
		splasher.busyUntil = now + 0.25
		local size = math.clamp(width * 2.2, 0.15, 1.2)
		-- (the bottom of each picture is the ground: its middle half a size up)
		splasher.attachment.WorldPosition = position + normal * (size * 0.45)
		sprite.Size = NumberSequence.new(size)
		sprite.Color = ColorSequence.new(color)
		sprite:Emit(1)
	end
	-- the droplets the crown throws out (real drops: they land too)
	local tangent = velocity - normal * velocity:Dot(normal)
	local ahead = if tangent.Magnitude > 1 then tangent.Unit else nil
	for _ = 1, rand:NextInteger(2, 5) do
		local a = rand:NextNumber(0, math.pi * 2)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		if ahead then
			out = (out + ahead * 1.5).Unit -- (mostly ahead: a slanted drop's wave)
		end
		dropLater(
			position + normal * 0.04,
			out * rand:NextNumber(2, 4) + normal * rand:NextNumber(3, 6),
			rand:NextNumber(0.015, 0.025),
			rand,
			nil,
			{ micro = true }
		)
	end
end

-- Ripple rings on pools: a few carriers reused (CAPS.RIPPLES at once).
type Ripple = { part: Part, decal: Decal, busyUntil: number }
local ripples: { Ripple } = {}
local RIPPLE_GROW = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function freeRipple(now: number): Ripple?
	for _, ripple in ripples do
		if now >= ripple.busyUntil and ripple.part.Parent then
			return ripple
		end
	end
	if #ripples >= BloodAge.cap("RIPPLES") then
		return nil
	end
	local id = BloodStain.image("rippleRing", nil, 1)
	if id == 0 then
		return nil -- (not uploaded yet: no ripple)
	end
	local part = Instance.new("Part")
	part.Name = "BloodRipple"
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Archivable = false
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = "rbxassetid://" .. id
	decal.Color3 = PALETTE.ARTERIAL_LIGHT -- (a thin bright crest)
	decal.Transparency = 1
	decal.Parent = part
	part.Parent = folder
	local made: Ripple = { part = part, decal = decal, busyUntil = 0 }
	table.insert(ripples, made)
	return made
end

local function ripple(position: Vector3, normal: Vector3)
	local now = os.clock()
	local ring = freeRipple(now)
	if ring == nil then
		return
	end
	ring.busyUntil = now + 0.37
	local side = normal:Cross(X_AXIS)
	if side.Magnitude < 1e-3 then
		side = normal:Cross(Vector3.new(0, 0, 1))
	end
	-- (its Top face along `normal`, just over the pool's wet film)
	ring.part.CFrame = CFrame.fromMatrix(position + normal * 0.07, side.Unit, normal)
	ring.part.Size = Vector3.new(0.08, 0.01, 0.08)
	ring.decal.Transparency = 0.25
	TweenService:Create(ring.part, RIPPLE_GROW, { Size = Vector3.new(0.45, 0.01, 0.45) }):Play()
	TweenService:Create(ring.decal, RIPPLE_GROW, { Transparency = 1 }):Play()
end

-- A drop falling into a wet pool: a ring spreads on it, two specks jump up,
-- and a few tiny drops are thrown out radially; they land around the pool
-- (the faster from higher), where they pile up (with BloodPool's
-- "starburst": the classic pattern under someone bleeding standing still).
local function intoPool(
	position: Vector3,
	normal: Vector3,
	size: number,
	height: number,
	rand: Random
)
	local close = closeDetail(position)
	if not close then
		return
	end
	ripple(position, normal)
	local splasher = freeSplasher(os.clock())
	local specks = if splasher then splasher.specks else nil
	if splasher and specks then
		splasher.attachment.WorldPosition = position + normal * 0.03
		specks:Emit(2)
	end
	local speed = math.clamp(4 + 2.2 * math.sqrt(math.max(height, 0)), 4, 10)
	for _ = 1, rand:NextInteger(2, if size > 0.15 then 5 else 3) do
		local a = rand:NextNumber(0, math.pi * 2)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local tiny: SplatInfo = { micro = true, start = PALETTE.ARTERIAL_LIGHT }
		local options: BallisticOptions = { random = rand, info = tiny }
		ballisticLater(
			position + normal * 0.05,
			(out * rand:NextNumber(0.7, 1.1) + normal * rand:NextNumber(0.8, 1.3)).Unit
				* speed
				* rand:NextNumber(0.7, 1.1),
			rand:NextNumber(0.012, 0.02),
			options
		)
	end
end

------------------------------------------------------------------------------
-- Splats
------------------------------------------------------------------------------

-- The kind of stain a drop leaves for its impact angle (degrees).
local function spatterKind(angle: number): string
	if angle >= 70 then
		return "spatterRound"
	elseif angle >= 40 then
		return "spatterOval"
	elseif angle >= 15 then
		return "spatterTail"
	end
	return "spatterStreak"
end

-- A splash where blood lands. `velocity`: how it arrived (its angle gives
-- the shape, its way the direction of the tail); `onto`: the part hit.
function Blood.splat(
	position: Vector3,
	normal: Vector3,
	size: number,
	velocity: Vector3?,
	onto: BasePart?,
	rng: Random?,
	info: SplatInfo?
)
	if not Config.Blood.ENABLED then
		return
	end
	local rand = rng or random
	local inf: SplatInfo = info or {}
	local body = if onto then isBody(onto) else nil
	local v = velocity or Vector3.zero
	local speed = v.Magnitude
	-- on a body: it soaks in (clothes) / stays as a film (skin)
	if onto and body then
		local skin, point, out = BloodStain.onSkin(onto, position)
		if skin == nil then
			return
		end
		size = math.min(size, if skin.Name == "Head" then 0.32 else 0.6)
		local tangent = v - out * v:Dot(out)
		local along = if tangent.Magnitude > 0.5 then tangent.Unit else DOWN
		local w = size * rand:NextNumber(0.6, 0.85)
		local slant = if speed > 1 then math.abs(v.Unit:Dot(out)) else 1
		BloodStain.stain(
			inf.kind or (if slant > 0.9 then "spatterRound" else "spatterOval"),
			point,
			out,
			along,
			w,
			w / math.max(slant, 0.5),
			{
				random = rand,
				onto = skin,
				profile = inf.profile or "body",
				alpha = 0.12,
				priority = 2,
				start = inf.start,
			}
		)
		return
	end
	local floor = normal.Y > 0.7
	local passive = inf.passive == true
	local height = inf.height or 0
	-- the impact angle (90 = straight in), from the speed against the surface
	local sinAngle = if speed > 1 then math.clamp(math.abs(v:Dot(normal)) / speed, 0, 1) else 1
	local angle = math.deg(math.asin(sinAngle))
	local tangent = v - normal * v:Dot(normal)
	local wall = math.abs(normal.Y) < 0.75
	local along: Vector3
	if tangent.Magnitude > 0.5 then
		along = tangent.Unit
	else
		local a = rand:NextNumber(0, math.pi * 2)
		local flat = Vector3.new(math.cos(a), 0, math.sin(a))
		along = flat - normal * flat:Dot(normal)
		if along.Magnitude < 1e-3 then
			along = normal:Cross(X_AXIS)
		end
		along = along.Unit
	end
	if wall then
		-- (on a wall it also sags down as it lands)
		local sag = DOWN - normal * DOWN:Dot(normal)
		if sag.Magnitude > 1e-3 then
			along = (along * math.max(tangent.Magnitude, 1) + sag.Unit * 2).Unit
		end
	end
	-- a drop falling into a fresh pool splashes into it (no new stain)
	if floor and size < 0.35 then
		local inPool, splash = BloodPool.absorb(position, if inf.micro then nil else rand, height)
		if inPool then
			if inf.micro then
				return -- (a tiny splash drop falling back in: lost in the pool)
			end
			-- a ring on the pool, tiny drops thrown around it
			intoPool(position, normal, size, height, rand)
			if splash then
				BloodStain.stain("dripPool", position, normal, along, size * 1.4, size * 1.4, {
					random = rand,
					start = PALETTE.VENOUS,
					priority = 1,
					onto = onto,
				})
			end
			return
		end
	end
	-- a drip falling only a little way: smaller, no satellites (research:
	-- the stain of a drop grows with the height it fell from)
	local drip = passive and floor and angle >= 70
	if drip and height < 1 then
		size *= 0.9
	end
	local width = size * rand:NextNumber(0.72, 0.92)
	local length = math.min(width / math.max(sinAngle, 0.22), width * 4.5)
	local kind = inf.kind or (if drip then "drip" else spatterKind(angle))
	local start = inf.start
		or if passive
			then PALETTE.VENOUS:Lerp(PALETTE.ARTERIAL, rand:NextNumber(0, 0.4))
			else PALETTE.ARTERIAL:Lerp(PALETTE.VENOUS, rand:NextNumber(0, 0.35))
	-- (the parent drop sits 35 % along the picture: its tail ahead)
	local round = kind == "spatterRound" or kind == "drip"
	local centre = if round then position else position + along * length * 0.15
	BloodStain.stain(kind, centre, normal, along, width, length, {
		random = rand,
		onto = onto,
		start = start,
		profile = inf.profile,
		priority = if size > 0.2 then 3 else 2,
	})
	if drip and height > 3.5 then
		-- fallen more than ~1 m: a ring of tiny satellite drops around it
		-- (on rough ground only the satellites grow with height, research)
		local radius = math.min(size * (1 + 0.25 * height), size * 3)
		local drawn = BloodStain.resolve("starburst")
		if drawn ~= "starburst" then
			radius = math.min(radius, size * 1.25) -- (the stand-in: a smaller fan)
		end
		local a = rand:NextNumber(0, math.pi * 2)
		BloodStain.stain(
			"starburst",
			position,
			normal,
			Vector3.new(math.cos(a), 0, math.sin(a)),
			radius * 2,
			radius * 2,
			{
				random = rand,
				onto = onto,
				start = PALETTE.ARTERIAL_LIGHT,
				alpha = 0.25,
				priority = 1,
				noEdge = true,
			}
		)
	end
	-- a big drop falling far onto a hard / wet floor: a splash crown
	if floor and not inf.micro and height >= WORLD.CROWN_MIN_HEIGHT then
		local dropSize = inf.dropSize or size / 2.6
		if dropSize >= WORLD.CROWN_MIN_SIZE then
			crown(position, normal, width, start, v, inf.material, rand)
		end
	end
	-- fast and big: a fan of tiny satellite drops thrown ahead of it
	if not passive and speed > 14 and size > 0.15 then
		BloodStain.stain(
			"satellites",
			position + along * size * 0.9,
			normal,
			along,
			size * rand:NextNumber(1.5, 2.5),
			size * rand:NextNumber(1.8, 2.8),
			{
				random = rand,
				onto = onto,
				start = PALETTE.ARTERIAL_LIGHT,
				alpha = 0.15,
				priority = 1,
			}
		)
	end
	-- a big one on the floor: thick and wet in the middle (a small pool)
	if not wall and size > (if passive then 0.3 else 0.22) and floor and inf.kind == nil then
		local core = size * rand:NextNumber(0.5, 0.65)
		local record = BloodStain.place(
			"pool",
			position,
			normal,
			along,
			core,
			core * rand:NextNumber(1, 1.2),
			{
				random = rand,
				onto = onto,
				profile = "pool",
				start = PALETTE.VENOUS,
				gloss = 0.7,
				noEdge = true,
			}
		)
		if record then
			BloodPool.addWet(record, position, core * 0.6 + 0.1)
		end
	end
	-- on a wall, it runs down
	if wall and size > 0.12 and (onto == nil or onto.Anchored) then
		for _ = 1, rand:NextInteger(1, if size > 0.3 then 2 else 1) do
			local across = along:Cross(normal)
			local from = position + across * rand:NextNumber(-0.3, 0.3) * size
			Blood.run(
				from,
				normal,
				size * rand:NextNumber(0.22, 0.35),
				{ random = rand, start = start }
			)
		end
	end
end

-- A wet swipe of blood (something bloody sliding, a body dragged): along
-- `velocity`, `width` across.
function Blood.smear(
	position: Vector3,
	normal: Vector3,
	velocity: Vector3,
	width: number,
	onto: BasePart?
)
	if not Config.Blood.ENABLED or velocity.Magnitude < 1e-3 then
		return -- (not moving: no direction to smear along)
	end
	local length = math.clamp(velocity.Magnitude * 0.12, width * 1.2, width * 4)
	BloodStain.stain(
		"smear",
		position - velocity.Unit * length * 0.4,
		normal,
		velocity,
		width,
		length,
		{
			onto = onto,
			profile = "smear",
			start = PALETTE.VENOUS,
			alpha = 0.1,
			priority = 2,
		}
	)
end

------------------------------------------------------------------------------
-- Drops and strands in flight
------------------------------------------------------------------------------

type Drop = {
	part: Part,
	shape: SpecialMesh,
	position: Vector3,
	velocity: Vector3,
	size: number,
	born: number,
	source: Model?,
	seed: number,
	gravity: number, -- (× workspace.Gravity)
	drag: number?, -- (nil: by its size)
	y0: number, -- the height it left from (how far it fell, when it lands)
	info: SplatInfo?,
}
type Strand = {
	head: Drop,
	tail: Vector3,
	tailVelocity: Vector3,
	thread: Part,
	thickness: number,
	rest: number,
}

local drops: { Drop } = {}
local strands: { Strand } = {}
local moved: { BasePart } = {}
local frames: { CFrame } = {}

local function newDrop(
	position: Vector3,
	velocity: Vector3,
	size: number,
	source: Model?,
	rng: Random?,
	gravity: number?,
	info: SplatInfo?
): Drop?
	if not Config.Blood.ENABLED or #drops >= BloodAge.cap("DROPS") then
		return nil
	end
	local rand = rng or random
	local part = newPiece(
		"BloodDrop",
		Vector3.one * size,
		PALETTE.ARTERIAL:Lerp(PALETTE.VENOUS, rand:NextNumber(0, 0.4))
	)
	local shape = Instance.new("SpecialMesh")
	shape.MeshType = Enum.MeshType.Sphere
	shape.Parent = part
	part.CFrame = CFrame.new(position)
	part.Parent = folder
	local drop: Drop = {
		part = part,
		shape = shape,
		position = position,
		velocity = velocity,
		size = size,
		born = os.clock(),
		source = source,
		seed = rand:NextInteger(1, 2 ^ 30),
		gravity = gravity or 1,
		drag = if gravity then 0.25 else nil,
		y0 = position.Y,
		info = info,
	}
	table.insert(drops, drop)
	return drop
end

-- `gravity`: × workspace.Gravity (an artery's jet uses a lighter one, like
-- its particles; it then also keeps a heavy liquid's low drag). A drop that
-- drips: Blood.passiveScale(). `info`: given to its splash when it lands.
function Blood.drop(
	position: Vector3,
	velocity: Vector3,
	size: number,
	rng: Random?,
	gravity: number?,
	info: SplatInfo?
)
	newDrop(position, velocity, size, nil, rng, gravity, info)
end
dropLater = Blood.drop

function Blood.strand(
	point: Vector3,
	velocity: Vector3,
	thickness: number,
	source: Model?,
	rng: Random?
)
	if #strands >= MAX_STRANDS then
		return
	end
	local rand = rng or random
	local head = newDrop(point, velocity, thickness * 1.9, source, rand)
	if head == nil then
		return
	end
	local thread =
		newPiece("BloodStrand", Vector3.new(0.05, thickness, thickness), PALETTE.ARTERIAL)
	thread.Shape = Enum.PartType.Cylinder
	thread.Parent = folder
	table.insert(strands, {
		head = head,
		tail = point,
		tailVelocity = velocity * 0.35,
		thread = thread,
		thickness = thickness,
		rest = rand:NextNumber(0.25, 0.6),
	})
end

-- How wide a drop of `size` splashes: a bigger, faster drop splashes wider;
-- a drip on rough ground soaks in at once (its stain no wider for a higher
-- fall, research: AAFS 2005).
local function splashSize(
	size: number,
	speed: number,
	passive: boolean,
	material: Enum.Material?
): number
	if passive and BloodStain.porous(material) then
		return size * 2.6
	end
	return size * (2.2 + math.min(speed, 40) * 0.05)
end

-- What a landing drop tells its splash (a copy: never the caller's table).
local function landingInfo(
	given: SplatInfo?,
	height: number,
	passive: boolean,
	size: number,
	material: Enum.Material
): SplatInfo
	local g: SplatInfo = given or {}
	return {
		height = math.max(height, 0),
		passive = passive or g.passive == true,
		start = g.start,
		kind = g.kind,
		profile = g.profile,
		dropSize = size,
		material = material,
		micro = g.micro,
	}
end

local function land(drop: Drop, hit: RaycastResult)
	local speed = drop.velocity.Magnitude
	-- (a drop made with the drips' slow gravity is a drip, even if its maker
	-- didn't say so)
	local passive = (drop.info ~= nil and drop.info.passive == true)
		or math.abs(drop.gravity - Blood.passiveScale()) < 1e-3
	Blood.splat(
		hit.Position,
		hit.Normal,
		splashSize(drop.size, speed, passive, hit.Material),
		drop.velocity,
		hit.Instance :: BasePart,
		Random.new(drop.seed),
		landingInfo(drop.info, drop.y0 - hit.Position.Y, passive, drop.size, hit.Material)
	)
end

-- Moves every drop, lands the ones that hit something.
local function step(dt: number)
	debug.profilebegin("BloodDrops")
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	local now = os.clock()
	stepRuns(now)
	table.clear(moved)
	table.clear(frames)
	local index = 1
	while index <= #drops do
		local drop = drops[index]
		local drag = drop.drag or (if drop.size > 0.12 then 0.35 else 1.1) -- (tiny drops slow in the air)
		drop.velocity += (gravity * drop.gravity - drop.velocity * drag) * dt
		local travel = drop.velocity * dt
		local hit = nil
		if travel.Magnitude > 1e-4 then
			hit = workspace:Raycast(drop.position, travel, params)
			-- (leaving the wound: not on the body it comes out of)
			if
				hit
				and drop.source
				and now - drop.born < 0.08
				and hit.Instance:IsDescendantOf(drop.source)
			then
				hit = nil
			end
			if hit and not solid(hit) then
				hit = nil -- (through an invisible wall: the drop flies on)
			end
		end
		if hit or now - drop.born > 4 or drop.part.Parent == nil then
			if hit then
				land(drop, hit)
			end
			drop.part:Destroy()
			drops[index] = drops[#drops]
			drops[#drops] = nil
			continue
		end
		drop.position += travel
		-- stretched along its speed (a fast drop is a streak)
		local speed = drop.velocity.Magnitude
		local stretch = 1 + math.min(speed * 0.045, 2.6)
		drop.shape.Scale = Vector3.new(1 / math.sqrt(stretch), 1 / math.sqrt(stretch), stretch)
		table.insert(moved, drop.part)
		table.insert(
			frames,
			if speed > 0.1
				then CFrame.lookAt(
					drop.position,
					drop.position + drop.velocity,
					if math.abs(drop.velocity.Unit.Y) > 0.99 then X_AXIS else UP
				)
				else CFrame.new(drop.position)
		)
		index += 1
	end
	-- Strands: the tail is dragged behind the gob, the thread thins as it
	-- stretches, and snaps.
	index = 1
	while index <= #strands do
		local strand = strands[index]
		local head = strand.head
		local alive = table.find(drops, head) ~= nil
		local gap = head.position - strand.tail
		local length = gap.Magnitude
		if not alive or length > strand.rest * 5 then
			-- snapped (or its gob landed): the thread falls as drops
			local count = math.clamp(math.floor(length / 0.25), 1, 5)
			for k = 1, count do
				local at = strand.tail + gap * (k / (count + 1))
				newDrop(
					at,
					strand.tailVelocity * 0.8 + Vector3.new(0, -2, 0),
					strand.thickness * 1.2,
					nil
				)
			end
			strand.thread:Destroy()
			strands[index] = strands[#strands]
			strands[#strands] = nil
			continue
		end
		-- (pulled toward the gob like a stretched spring, gravity on it too)
		local pull = if length > strand.rest
			then gap.Unit * (length - strand.rest) * 60
			else Vector3.zero
		strand.tailVelocity += (gravity + pull - strand.tailVelocity * 2.5) * dt
		strand.tail += strand.tailVelocity * dt
		local mid = (strand.tail + head.position) / 2
		local thin = math.clamp(strand.rest / math.max(length, 1e-3), 0.25, 1)
		strand.thread.Size =
			Vector3.new(math.max(length, 0.02), strand.thickness * thin, strand.thickness * thin)
		table.insert(moved, strand.thread)
		table.insert(
			frames,
			if length > 1e-3
				then CFrame.lookAt(mid, head.position) * CFrame.Angles(0, math.rad(90), 0)
				else CFrame.new(mid)
		)
		index += 1
	end
	if #moved > 0 then
		workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	debug.profileend()
end
RunService.Heartbeat:Connect(step)

------------------------------------------------------------------------------
-- Drops landing where they are computed to land (no part flying)
------------------------------------------------------------------------------

local pending = 0

-- A drop leaving `origin` at `velocity`: where it lands is found now (a few
-- rays along its arc), its mark appears there when it gets there.
function Blood.ballistic(
	origin: Vector3,
	velocity: Vector3,
	size: number,
	options: BallisticOptions?
): Vector3?
	if not Config.Blood.ENABLED or pending >= BloodAge.cap("PENDING_LANDINGS") then
		return nil
	end
	local opts: BallisticOptions = options or {}
	local ignore: { Instance } = { folder }
	local extra: { Instance } = opts.ignore or {}
	for _, item in extra do
		table.insert(ignore, item)
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore
	local fall = opts.gravity or workspace.Gravity
	local gravity = Vector3.new(0, -fall, 0)
	local passive = math.abs(fall - Config.Blood.PASSIVE_GRAVITY) < 1e-3
	local drag = if size > 0.12 then 0.35 else 1.1
	local position, moving = origin, velocity
	local flight = 0
	local dt = 0.04
	for _ = 1, 25 do
		moving += (gravity - moving * drag) * dt
		local travel = moving * dt
		local hit = workspace:Raycast(position, travel, rayParams)
		if hit and not solid(hit) then
			hit = nil -- (an invisible part: it flies on through it)
		end
		if hit then
			flight += dt * ((hit.Position - position).Magnitude / math.max(travel.Magnitude, 1e-3))
			local seed = if opts.random
				then opts.random:NextInteger(1, 2 ^ 30)
				else random:NextInteger(1, 2 ^ 30)
			local arrival = moving
			pending += 1
			task.delay(flight + (opts.delay or 0), function()
				pending -= 1
				local instance = hit.Instance
				if instance.Parent == nil then
					return
				end
				local splash = splashSize(size, arrival.Magnitude, passive, hit.Material)
				Blood.splat(
					hit.Position,
					hit.Normal,
					splash,
					arrival,
					instance :: BasePart,
					Random.new(seed),
					landingInfo(opts.info, origin.Y - hit.Position.Y, passive, size, hit.Material)
				)
			end)
			return hit.Position
		end
		position += travel
		flight += dt
	end
	return nil
end

ballisticLater = Blood.ballistic

-- A burst of particles: `count` of its drops really land (the marks it leaves
-- match what flew), from the same speeds and spread.
function Blood.landings(
	origin: Vector3,
	direction: Vector3,
	spread: number,
	speeds: NumberRange,
	count: number,
	sizes: NumberRange,
	rng: Random?,
	ignore: { Instance }?
)
	local rand = rng or random
	for _ = 1, math.clamp(math.floor(count), 0, 14) do
		local a = math.rad(spread) * math.sqrt(rand:NextNumber())
		local b = rand:NextNumber(0, math.pi * 2)
		local d = if direction.Magnitude > 1e-3 then direction.Unit else UP
		local up = if math.abs(d.Y) > 0.99 then X_AXIS else UP
		local frame = CFrame.lookAt(Vector3.zero, d, up)
		local out = frame:VectorToWorldSpace(
			Vector3.new(math.sin(a) * math.cos(b), math.sin(a) * math.sin(b), -math.cos(a))
		)
		Blood.ballistic(
			origin,
			out * rand:NextNumber(speeds.Min, speeds.Max),
			rand:NextNumber(sizes.Min, sizes.Max),
			{ random = rand, ignore = ignore }
		)
	end
end

------------------------------------------------------------------------------
-- Particles: drops of blood rather than red smoke (when the pictures exist)
------------------------------------------------------------------------------

-- Dresses `emitter` as blood: "drops" (falling drops), "gobs" (a stream
-- breaking into blobs) or "mist" (a fine spray). Without its picture it
-- keeps its own (smoke) look and returns false.
function Blood.droplets(emitter: ParticleEmitter, kind: string): boolean
	local key = if kind == "gobs"
		then "pGobs4x4"
		elseif kind == "mist" then "pMist8x8"
		else "pDrops4x4"
	local id = BloodStain.image(key, nil, 1)
	if id == 0 then
		return false
	end
	emitter.Texture = "rbxassetid://" .. id
	emitter.FlipbookLayout = if kind == "mist"
		then Enum.ParticleFlipbookLayout.Grid8x8
		else Enum.ParticleFlipbookLayout.Grid4x4
	emitter.FlipbookMode = if kind == "gobs"
		then Enum.ParticleFlipbookMode.Random
		else Enum.ParticleFlipbookMode.OneShot
	emitter.LightInfluence = 0.8
	emitter.Brightness = 1
	if kind ~= "mist" then
		-- (stretched along the way they fly; a heavy liquid: little drag)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Squash = NumberSequence.new(-0.6)
		emitter.Drag = math.min(emitter.Drag, 0.3)
		emitter.Acceleration = Vector3.new(0, -workspace.Gravity * 0.9, 0)
		emitter.RotSpeed = NumberRange.new(0)
		emitter.Rotation = NumberRange.new(0)
	end
	return true
end

-- An emitter of blood that only DRIPS (a stump, a torn organ): its particles
-- fall with the drips' slow gravity (Config.Blood.PASSIVE_GRAVITY), and with
-- the "hanging drop" picture (a drop swelling, necking, letting go) once it
-- is uploaded. Call it after Blood.droplets.
function Blood.dripEmitter(emitter: ParticleEmitter)
	emitter.Acceleration = Vector3.new(0, -Config.Blood.PASSIVE_GRAVITY, 0)
	local id = BloodStain.image("pendant2x2", nil, 1)
	if id ~= 0 then
		emitter.Texture = "rbxassetid://" .. id
		emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		emitter.Squash = NumberSequence.new(0)
	end
end

------------------------------------------------------------------------------
-- Sprays
------------------------------------------------------------------------------

function Blood.mist(point: Vector3, direction: Vector3, amount: number)
	if not Config.Blood.ENABLED then
		return
	end
	local k = math.sqrt(math.min(amount, 2.5)) -- (a fine haze, never a red cloud)
	local attachment = Instance.new("Attachment")
	local d = if direction.Magnitude > 1e-3 then direction.Unit else UP
	local up = if math.abs(d.Y) > 0.99 then X_AXIS else UP
	attachment.WorldCFrame = CFrame.lookAt(point, point + d, up)
	attachment.Parent = workspace.Terrain
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = SMOKE
	mist.Color = ColorSequence.new(PALETTE.ARTERIAL_LIGHT, PALETTE.VENOUS)
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.3, 0.45 * k),
		NumberSequenceKeypoint.new(1, 0.8 * k),
	})
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.4, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Speed = NumberRange.new(3, 10)
	mist.SpreadAngle = Vector2.new(35, 35)
	mist.Lifetime = NumberRange.new(0.4, 0.9)
	mist.Drag = 5
	mist.Acceleration = Vector3.new(0, -3, 0)
	mist.EmissionDirection = Enum.NormalId.Front
	mist.RotSpeed = NumberRange.new(-60, 60)
	mist.Rotation = NumberRange.new(0, 360)
	mist.LightInfluence = 0.8
	mist.Rate = 0
	if Blood.droplets(mist, "mist") then
		-- (the picture: a spray breaking into specks, short-lived)
		mist.Lifetime = NumberRange.new(0.25, 0.5)
		mist.Transparency = NumberSequence.new(0.5, 1)
	end
	mist.Parent = attachment
	mist:Emit(math.min(math.floor(4 + 3 * amount), 14))
	Debris:AddItem(attachment, 1.2)
end

-- A cone of directions around `d` (spread in degrees).
local function cone(d: Vector3, spread: number, rand: Random): Vector3
	local base = if d.Magnitude > 1e-3 then d.Unit else UP
	local up = if math.abs(base.Y) > 0.99 then X_AXIS else UP
	local frame = CFrame.lookAt(Vector3.zero, base, up)
	local a = math.rad(spread) * math.sqrt(rand:NextNumber())
	local b = rand:NextNumber(0, math.pi * 2)
	return frame:VectorToWorldSpace(
		Vector3.new(math.sin(a) * math.cos(b), math.sin(a) * math.sin(b), -math.cos(a))
	)
end

function Blood.spray(
	point: Vector3,
	direction: Vector3,
	amount: number,
	source: Model?,
	noMist: boolean?,
	rng: Random?
)
	if not Config.Blood.ENABLED then
		return
	end
	local rand = rng or random
	local d = if direction.Magnitude > 1e-3 then direction.Unit else UP
	-- many small drops, a few big gobs (fewer than before: they're real
	-- drops, each one lands and leaves its mark)
	local count = math.floor(5 + 9 * amount)
	for _ = 1, count do
		local big = rand:NextNumber() < 0.18
		local size = if big then rand:NextNumber(0.1, 0.17) else rand:NextNumber(0.035, 0.08)
		local speed = rand:NextNumber(6, 18)
			* (if big then 0.7 else 1)
			* (0.8 + 0.2 * math.min(amount, 3))
		local velocity = cone(d, if big then 30 else 45, rand) * speed
			+ Vector3.new(0, rand:NextNumber(1, 5), 0)
		newDrop(point + d * 0.1, velocity, size, source, rand)
	end
	-- thick strings pulled out of the wound
	if amount >= 1 then
		for _ = 1, math.clamp(math.floor(amount * 1.5), 1, 6) do
			local velocity = cone(d, 30, rand) * rand:NextNumber(5, 11)
				+ Vector3.new(0, rand:NextNumber(1, 4), 0)
			Blood.strand(point + d * 0.05, velocity, rand:NextNumber(0.045, 0.08), source, rand)
		end
	end
	if amount >= 1.5 and not noMist then
		Blood.mist(point, d, amount)
	end
end

return table.freeze(Blood)
