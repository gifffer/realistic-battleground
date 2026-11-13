--!strict
-- BloodRivulet: blood RUNNING on the skin the way it really does (client).
--
-- Watch a real cut bleed: the blood does not slide down smoothly. A bead
-- of blood swells at the front, sticks... then suddenly jumps a little
-- further, sticks again ("stick-slip"). The trail behind it goes dark and
-- dull first; the bead at the front stays glossy the longest. Where the
-- skin turns under (the chin, the bottom of the torso), a drop HANGS, swells,
-- stretches into a neck and falls; a smaller one hangs on and grows again.
-- A second flow from the same wound runs fast along the old wet channel.
--
-- What is drawn:
--   • the trail: a chain of flat pictures ("rivuletStrip", or the v1 "run"
--     picture until it is uploaded), each one lengthened as the front moves.
--     A new piece starts when the way turns (the head is round, the fighter
--     falls...), so the chain follows the skin.
--   • the bead: ONE small glossy 3D drop at the front (a decal can't shine).
--   • the hanging drop (pendant) at a drip point, or a thin pouring stream
--     when the wound bleeds very fast.
--
-- Gravity is relative to the BODY: a fighter knocked out on his side gets
-- runs going sideways across his face; lying on his back, the blood pools.
--
--   BloodRivulet.start(model, part, worldPoint, options) -> Rivulet?
--   BloodRivulet.tip(rivulet)                 where its blood is now (world)
--   BloodRivulet.dripPoint(rivulet)           its drip point (world) if it hangs there
--   BloodRivulet.handlesDrops(rivulet)        true: it drops by itself (pendant / stream)
--   BloodRivulet.refeed(rivulet, volume, seconds)   more blood (a reopened wound)
--   BloodRivulet.shorten(rivulet, keep)       a wipe: keeps `keep` (0..1) of it
--   BloodRivulet.stopAll(model)               every run of `model` stops
--   BloodRivulet.addMark(model, record, isCut, onHead)   counts a face mark (cap)
--   BloodRivulet.passiveScale()               slow gravity of a passive drop

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Blood = require(script.Parent.Blood)
local BloodAge = require(script.Parent.BloodAge)
local BloodStain = require(script.Parent.BloodStain)

local BloodRivulet = {}

-- (read through `any`: some of these keys come with the v2 Config; every
-- one has a default here, so the game works with or without them)
local BLOOD = Config.Blood :: any
local PALETTE = Config.Blood.PALETTE
local FACE = BLOOD.FACE or {}
local TICK: number = FACE.TICK or 1 / 15 -- seconds between two updates
local RANGE: number = FACE.RANGE or 60 -- studs from the camera: farther = no animation
local MAX_ACTIVE_PER_CHARACTER: number = FACE.MAX_ACTIVE_RUNS or 4
local MAX_HEAD_MARKS: number = FACE.MAX_MARKS or 14
local MAX_BODY_MARKS = 12 -- (runs on the torso, arms, legs)
local PENDANTS_PER_CHARACTER = 3
local MAX_SEGMENTS = 8 -- pieces in one run's chain (after that: it goes straight)
local HOLDER = 0.1 -- the real size of a bead / pendant part (its mesh does the rest)
local DOWN = Vector3.new(0, -1, 0)
local COS_TURN = math.cos(math.rad(15)) -- a turn sharper than this: a new piece

-- A profile of Config.Blood.PROFILES if it exists, else another one.
local function profile(wanted: string, fallback: string): string
	return if (Config.Blood.PROFILES :: any)[wanted] then wanted else fallback
end
local STRIP_PROFILE = profile("rivulet", "run")
local BEAD_PROFILE = profile("bead", "wound")
local CRUST_PROFILE = profile("crust", "wound")

-- A cap of Config.Blood.CAPS at this client's quality (`default` while the
-- Config doesn't have it).
local function cap(name: string, default: number): number
	if (Config.Blood.CAPS :: any)[name] then
		return BloodAge.cap(name)
	end
	return math.max(1, math.floor(default * BloodAge.scale()))
end

-- The picture to draw: `wanted` once it is uploaded, else `fallback` (an
-- uploaded one that looks close enough).
local function kind(wanted: string, fallback: string): string
	return if BloodStain.hasImage(wanted) then wanted else fallback
end

-- A passive drop (dripping, not thrown) falls with Config.Blood.PASSIVE_GRAVITY
-- (45 studs/s²) instead of workspace.Gravity (196): real drops fall slower at
-- a character's scale. Returns the multiplier Blood.drop takes.
function BloodRivulet.passiveScale(): number
	local gravity: number = BLOOD.PASSIVE_GRAVITY or 45
	return gravity / math.max(workspace.Gravity, 1)
end

------------------------------------------------------------------------------
-- Types
------------------------------------------------------------------------------

export type Guide = {
	point: Vector3, -- head-local point the run heads for (while standing)
	hold: number?, -- seconds it pauses there (the upper lip, the eye)
}

export type Options = {
	width: number?, -- studs (0.04-0.08)
	volume: number?, -- studs it can run before it stops (when not fed)
	start: Color3?, -- its colour fresh
	guides: { Guide }?, -- the face's contours to follow (head only)
	feed: number?, -- seconds the wound keeps feeding it (drops form at its end)
	random: Random?,
	source: any?, -- a later run with the same source RIDES this one's track
	interval: (() -> number)?, -- seconds to grow each hanging drop
	fast: number?, -- > 1: a heavy bleed (shorter stops, longer jumps)
	angle: number?, -- turned this much from straight down (radians): forks
	alpha: number?, -- more transparent (sweat-thinned blood)
	crust: boolean?, -- turns into a dry cracked crust once it stopped (face)
	noFork: boolean?,
	noWell: boolean?, -- (starts running at once: no swelling at the wound)
	stream: boolean?, -- so much blood it pours (no hanging drop)
	onGuide: ((Rivulet, number) -> ())?, -- reached guide number n
	onPool: ((Rivulet) -> ())?, -- the skin faces up here: blood pools
}

type Segment = {
	record: BloodAge.Record,
	origin: Vector3, -- part-local start of the piece
	dir: Vector3, -- part-local direction (unit)
	normal: Vector3, -- part-local skin normal
	length: number,
}

type Pendant = {
	part: Part,
	mesh: SpecialMesh,
	weld: Weld,
	born: number, -- this drop started growing
	period: number, -- seconds to grow
	base: number, -- size it starts from (what stayed after the last one fell)
	size: number, -- size it falls at
	snapUntil: number, -- (wobbling back after a drop fell)
	last: number, -- its size now
	stretch: number, -- its neck (1 = round)
}

export type Rivulet = {
	model: Model,
	part: BasePart,
	isHead: boolean,
	width: number,
	volume: number,
	start: Color3,
	random: Random,
	opts: Options,
	segments: { Segment },
	tip: Vector3, -- part-local
	normal: Vector3, -- part-local skin normal at the tip
	state: string, -- "well" | "hold" | "slip" | "drip" | "done"
	stateEnd: number,
	slipLeft: number,
	slipSpeed: number,
	guideIndex: number,
	feedUntil: number,
	angle: number,
	newPiece: boolean, -- (the next move starts a new piece: wrapped over an edge)
	bead: Part?,
	beadMesh: SpecialMesh?,
	beadWeld: Weld?,
	beadRecord: BloodAge.Record?,
	beadScale: number,
	pendant: Pendant?,
	stream: Part?,
	streamWeld: Weld?,
	nextDrop: number,
	ride: { Vector3 }?, -- an old wet track to travel first (part-local points)
	rideIndex: number,
	path: { Vector3 },
	forked: boolean,
	pooled: boolean,
	doneAt: number?,
	crusted: boolean,
	dead: boolean,
}

type Mark = { record: BloodAge.Record, cut: boolean }

type ModelState = {
	rivulets: { Rivulet },
	headMarks: { Mark },
	bodyMarks: { Mark },
	pendants: number,
}

local active: { Rivulet } = {} -- moving or dripping
local resting: { Rivulet } = {} -- stopped (waiting to crust)
local byModel: { [Model]: ModelState } = {}
local bySource: { [any]: Rivulet } = setmetatable({}, { __mode = "k" }) :: any
local pendantCount = 0

local function modelState(model: Model): ModelState
	local state = byModel[model]
	if state then
		return state
	end
	local made: ModelState = { rivulets = {}, headMarks = {}, bodyMarks = {}, pendants = 0 }
	byModel[model] = made
	model.AncestryChanged:Connect(function()
		if model.Parent == nil and byModel[model] == made then
			byModel[model] = nil
			BloodRivulet.stopAll(model)
		end
	end)
	return made
end

------------------------------------------------------------------------------
-- Face marks cap (FACE.MAX_MARKS per character)
------------------------------------------------------------------------------

-- Counts a mark on `model` (a run piece, a cut, crust...). Over the cap the
-- oldest DRY run piece goes first (never a cut: it stays until respawn).
function BloodRivulet.addMark(
	model: Model,
	record: BloodAge.Record,
	isCut: boolean,
	onHead: boolean
)
	local state = modelState(model)
	local list: { Mark } = if onHead then state.headMarks else state.bodyMarks
	local most = if onHead then MAX_HEAD_MARKS else MAX_BODY_MARKS
	table.insert(list, { record = record, cut = isCut })
	local index = 1
	while index <= #list do
		if list[index].record.dead then
			table.remove(list, index)
		else
			index += 1
		end
	end
	if #list <= most then
		return
	end
	local victim: number? = nil
	for i, mark in list do
		if not mark.cut and BloodAge.wetness(mark.record) < 0.05 then
			victim = i
			break
		end
	end
	if victim == nil then
		for i, mark in list do
			if not mark.cut then
				victim = i
				break
			end
		end
	end
	if victim then
		BloodAge.remove(list[victim].record)
		table.remove(list, victim)
	end
end

------------------------------------------------------------------------------
-- 3D pieces: the bead, the hanging drop, the stream
------------------------------------------------------------------------------

local function holderOf(part: BasePart): Instance
	local holder = part:FindFirstChild("BloodSplats")
	if holder == nil or not holder:IsA("Folder") then
		local made = Instance.new("Folder")
		made.Name = "BloodSplats"
		made.Archivable = false
		made.Parent = part
		holder = made
	end
	return holder :: Instance
end

-- A small glossy ball (welded to `part`, weightless, touches nothing).
local function newBall(name: string): (Part, SpecialMesh, Weld)
	local ball = Instance.new("Part")
	ball.Name = name
	ball.Size = Vector3.one * HOLDER
	ball.Material = Enum.Material.SmoothPlastic
	ball.Color = PALETTE.VENOUS
	ball.Reflectance = 0.2 -- (wet: more turns it pink)
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Massless = true
	ball.Anchored = false
	ball.Archivable = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = ball
	local weld = Instance.new("Weld")
	weld.Part1 = ball
	weld.Parent = ball
	return ball, mesh, weld
end

local freePendants: { Pendant } = {}

local function takePendant(r: Rivulet): Pendant?
	local state = modelState(r.model)
	if state.pendants >= PENDANTS_PER_CHARACTER or pendantCount >= cap("PENDANTS", 24) then
		return nil
	end
	local pendant = table.remove(freePendants)
	if pendant == nil then
		local ball, mesh, weld = newBall("BloodPendant")
		pendant = {
			part = ball,
			mesh = mesh,
			weld = weld,
			born = 0,
			period = 1,
			base = 0.02,
			size = 0.06,
			snapUntil = 0,
			last = 0.02,
			stretch = 1,
		}
	end
	assert(pendant, "no pendant drop in the pool")
	state.pendants += 1
	pendantCount += 1
	pendant.weld.Part0 = r.part
	pendant.part.Parent = holderOf(r.part)
	pendant.born = os.clock()
	pendant.base = 0.02
	pendant.size = r.random:NextNumber(0.055, 0.08)
	pendant.snapUntil = 0
	pendant.mesh.Scale = Vector3.one * (0.02 / HOLDER)
	return pendant
end

local function givePendant(r: Rivulet)
	local pendant = r.pendant
	if pendant == nil then
		return
	end
	r.pendant = nil
	pendantCount -= 1
	local state = byModel[r.model]
	if state then
		state.pendants -= 1
	end
	pendant.weld.Part0 = nil
	if #freePendants < 32 and pendant.part.Parent ~= nil then
		pendant.part.Parent = nil
		table.insert(freePendants, pendant)
	else
		pendant.part:Destroy()
	end
end

local function removeStream(r: Rivulet)
	local stream = r.stream
	if stream then
		stream:Destroy()
		r.stream = nil
		r.streamWeld = nil
	end
end

------------------------------------------------------------------------------
-- Geometry on the part
------------------------------------------------------------------------------

-- Down (gravity) in the part's own space: the body may be lying down.
local function localDown(part: BasePart): Vector3
	return part.CFrame:VectorToObjectSpace(DOWN)
end

local function upright(part: BasePart): boolean
	return part.CFrame.UpVector.Y > 0.6
end

local function cameraDistance(part: BasePart): number
	local camera = workspace.CurrentCamera
	if camera == nil then
		return 0
	end
	return (camera.CFrame.Position - part.Position).Magnitude
end

-- `v` turned by `a` radians around `n` (v lies on the skin, n is its normal).
local function turnAround(v: Vector3, n: Vector3, a: number): Vector3
	return v * math.cos(a) + n:Cross(v) * math.sin(a)
end

-- One component of a vector (1 = X, 2 = Y, 3 = Z).
local function component(v: Vector3, axis: number): number
	return if axis == 1 then v.X elseif axis == 2 then v.Y else v.Z
end

local function withComponent(v: Vector3, axis: number, value: number): Vector3
	if axis == 1 then
		return Vector3.new(value, v.Y, v.Z)
	elseif axis == 2 then
		return Vector3.new(v.X, value, v.Z)
	end
	return Vector3.new(v.X, v.Y, value)
end

local function axisOf(normal: Vector3): number
	local ax, ay, az = math.abs(normal.X), math.abs(normal.Y), math.abs(normal.Z)
	if ax >= ay and ax >= az then
		return 1
	elseif ay >= az then
		return 2
	end
	return 3
end

------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------

local function placeBead(r: Rivulet)
	local bead, mesh, weld = r.bead, r.beadMesh, r.beadWeld
	if bead == nil or mesh == nil or weld == nil then
		return
	end
	local current = r.segments[#r.segments]
	local along = if current then current.dir else localDown(r.part)
	along = along - r.normal * along:Dot(r.normal)
	if along.Magnitude < 1e-3 then
		along = r.normal:Cross(Vector3.new(0.37, 0.71, 0.6))
	end
	along = along.Unit
	local w = r.width * r.beadScale
	-- X along the run, Y out of the skin, Z across
	weld.C0 = CFrame.fromMatrix(r.tip + r.normal * (r.width * 0.12), along, r.normal)
	mesh.Scale = Vector3.new(w * 1.3, r.width * 0.5, w * 1.5) / HOLDER
end

local function makeBead(r: Rivulet)
	if r.bead then
		return
	end
	local bead, mesh, weld = newBall("BloodBead")
	weld.Part0 = r.part
	r.bead, r.beadMesh, r.beadWeld = bead, mesh, weld
	placeBead(r)
	bead.Parent = holderOf(r.part)
	-- (it ages like the rest, but keeps its shine the longest)
	r.beadRecord = BloodAge.track(bead, BEAD_PROFILE, PALETTE.VENOUS, 0.3)
end

local function removeBead(r: Rivulet)
	local record = r.beadRecord
	if record then
		BloodAge.remove(record)
	elseif r.bead then
		(r.bead :: Part):Destroy()
	end
	r.bead, r.beadMesh, r.beadWeld, r.beadRecord = nil, nil, nil, nil
end

-- A new piece of the trail from the tip, going `dir` (part-local).
local function newSegment(r: Rivulet, dir: Vector3): Segment?
	if #r.segments >= MAX_SEGMENTS then
		return nil
	end
	local cf = r.part.CFrame
	local record = BloodStain.place(
		kind("rivuletStrip", "run"),
		cf * r.tip,
		cf:VectorToWorldSpace(r.normal),
		cf:VectorToWorldSpace(dir),
		r.width,
		0.04,
		{
			onto = r.part,
			random = r.random,
			profile = STRIP_PROFILE,
			start = r.start,
			owner = r.model,
			upright = true,
			turn = math.pi, -- (the picture's top where it starts)
			noEdge = true,
			alpha = r.opts.alpha,
			priority = 3,
		}
	)
	if record == nil then
		return nil
	end
	-- (BloodStain may nudge it to stay on the skin: read where it really is)
	local origin, along = r.tip, dir
	local shape = BloodStain.shapeOf(record)
	if shape and shape.stuck == r.part then
		origin = shape.frame.Position
		along = shape.frame.XVector
	end
	local segment: Segment = {
		record = record,
		origin = origin,
		dir = along,
		normal = r.normal,
		length = 0.04,
	}
	table.insert(r.segments, segment)
	BloodRivulet.addMark(r.model, record, false, r.isHead)
	return segment
end

local function lengthen(segment: Segment, tip: Vector3)
	local length = math.max(0.04, (tip - segment.origin):Dot(segment.dir))
	if math.abs(length - segment.length) < 0.003 then
		return
	end
	segment.length = length
	BloodStain.movePiece(segment.record, 1, length / 2, 0, length)
end

------------------------------------------------------------------------------
-- States
------------------------------------------------------------------------------

local function fed(r: Rivulet, now: number): boolean
	return now < r.feedUntil
end

local function nextInterval(r: Rivulet): number
	local interval = r.opts.interval
	if interval then
		return math.max(0.25, interval())
	end
	return r.random:NextNumber(0.8, 1.4)
end

local function deactivate(r: Rivulet)
	local index = table.find(active, r)
	if index then
		active[index] = active[#active]
		active[#active] = nil
	end
end

local function finishRun(r: Rivulet, now: number)
	givePendant(r)
	removeStream(r)
	r.state = "done"
	r.doneAt = now
	deactivate(r)
	if not table.find(resting, r) then
		table.insert(resting, r)
	end
end

local function enterHold(r: Rivulet, now: number, seconds: number?)
	r.state = "hold"
	local riding = r.ride ~= nil
	local fast = r.opts.fast or 1
	local hold = seconds or r.random:NextNumber(0.2, 1.2) * (if riding then 0.3 else 1) / fast
	r.stateEnd = now + hold
	-- (now and then a run splits in two at a stop: a thinner one leaves sideways)
	if
		not r.forked
		and not r.opts.noFork
		and r.volume > 0.3
		and #r.segments > 0
		and r.random:NextNumber() < 0.2
	then
		r.forked = true
		local side = if r.random:NextNumber() < 0.5 then 1 else -1
		BloodRivulet.start(r.model, r.part, r.part.CFrame * r.tip, {
			width = r.width * 0.6,
			volume = r.volume * 0.4,
			start = r.start,
			random = Random.new(r.random:NextInteger(1, 2 ^ 30)),
			angle = side * math.rad(25),
			alpha = r.opts.alpha,
			crust = r.opts.crust,
			noFork = true,
			noWell = true,
		})
	end
end

-- The tip reached a point where blood can't stay on the skin (the chin, the
-- bottom of the torso, skin facing down): it hangs there and drips while
-- the wound feeds it.
local function reachDripPoint(r: Rivulet, now: number)
	r.slipLeft = 0
	if not fed(r, now) then
		finishRun(r, now)
		return
	end
	r.state = "drip"
	r.nextDrop = now + nextInterval(r) * 0.6
	if r.opts.stream and r.stream == nil and cameraDistance(r.part) <= RANGE then
		-- (a heavy cut: a thin stream pours off the edge)
		local stream, _, weld = newBall("BloodStream")
		weld.Part0 = r.part
		stream.Parent = holderOf(r.part)
		r.stream, r.streamWeld = stream, weld
	end
end

-- Moves the front `distance` studs along the skin (one small step).
local function advance(r: Rivulet, distance: number, now: number)
	local part = r.part
	-- 1. riding an old wet track: follow its points first (fast)
	local ride = r.ride
	if ride then
		local target: Vector3? = ride[r.rideIndex]
		if target == nil then
			r.ride = nil
		else
			local gap = target - r.tip
			if gap.Magnitude <= distance then
				r.tip = target
				r.rideIndex += 1
			else
				r.tip += gap.Unit * distance
			end
			local _, _, out = BloodStain.onSkin(part, part.CFrame * r.tip)
			r.normal = part.CFrame:VectorToObjectSpace(out)
			placeBead(r)
			return
		end
	end
	-- 2. which way is down here (gravity on the skin, relative to the body)?
	local g = localDown(part)
	local n = r.normal
	local ng = n:Dot(g)
	if r.isHead and upright(part) and r.tip.Y < -0.38 then
		reachDripPoint(r, now) -- (the chin / the jaw line)
		return
	end
	if ng > 0.6 then
		reachDripPoint(r, now) -- (the skin faces down: it hangs from it)
		return
	end
	local d = g - n * ng
	if d.Magnitude < 0.25 then
		-- the skin faces up (lying on the back): it pools at the tip
		r.slipLeft = 0
		if not r.pooled then
			r.pooled = true
			local onPool = r.opts.onPool
			if onPool then
				onPool(r)
			end
		end
		return
	end
	r.pooled = false
	d = d.Unit
	-- 3. the face's contours (nose → lip → chin...) while standing
	local guides = r.opts.guides
	if guides and r.isHead and upright(part) then
		local guide = guides[r.guideIndex]
		if guide then
			local toward = guide.point - r.tip
			toward -= n * toward:Dot(n)
			if toward.Magnitude < 0.035 then
				r.guideIndex += 1
				local onGuide = r.opts.onGuide
				if onGuide then
					onGuide(r, r.guideIndex - 1)
				end
				if guide.hold then
					r.slipLeft = 0
					enterHold(r, now, guide.hold)
					return
				end
			else
				d = (d + toward.Unit * 0.6).Unit
			end
		end
	end
	-- 4. its own little wander (and a fork leaves at an angle)
	if r.angle ~= 0 then
		d = turnAround(d, n, r.angle)
	end
	-- 5. a new piece of the trail when the way turns
	local current = r.segments[#r.segments]
	local maxLength = if r.isHead then 0.12 else 0.5
	if
		r.newPiece
		or current == nil
		or current.dir:Dot(d) < COS_TURN
		or (current.length >= maxLength and #r.segments < MAX_SEGMENTS)
	then
		r.newPiece = false
		current = newSegment(r, d) or current
	end
	if current == nil then
		finishRun(r, now) -- (no room for blood: nothing drawn)
		return
	end
	-- (once the chain is full it goes on straight)
	local step = if #r.segments >= MAX_SEGMENTS then current.dir else d
	local nextTip = r.tip + step * distance
	if r.isHead then
		local skin, at, out = BloodStain.onSkin(part, part.CFrame * nextTip)
		if skin == nil then
			reachDripPoint(r, now) -- (under the chin / off the side)
			return
		end
		r.tip = part.CFrame:PointToObjectSpace(at)
		r.normal = part.CFrame:VectorToObjectSpace(out)
	else
		-- a block: over an edge, it wraps onto the next face or hangs
		r.tip = nextTip
		local half = part.Size / 2
		local own = axisOf(n)
		for axis = 1, 3 do
			if axis ~= own then
				local value = component(r.tip, axis)
				local limit = component(half, axis) - 0.015
				if math.abs(value) > limit then
					local sign = if value > 0 then 1 else -1
					r.tip = withComponent(r.tip, axis, sign * limit)
					local nextNormal = withComponent(Vector3.zero, axis, sign)
					lengthen(current, r.tip)
					if nextNormal:Dot(g) > 0.3 then
						reachDripPoint(r, now) -- (the face below faces down)
						return
					end
					-- onto the side face, just past the edge
					local ownSign = if component(n, own) > 0 then 1 else -1
					r.tip = withComponent(
						withComponent(r.tip, axis, sign * component(half, axis)),
						own,
						ownSign * (component(half, own) - 0.02)
					)
					r.normal = nextNormal
					r.newPiece = true
					placeBead(r)
					return
				end
			end
		end
	end
	lengthen(current, r.tip)
	local last: Vector3? = r.path[#r.path]
	if last == nil or (r.tip - last).Magnitude > 0.04 then
		table.insert(r.path, r.tip)
	end
	r.volume -= distance
	if r.volume <= 0 then
		if fed(r, now) then
			r.volume = 0.05 -- (still fed: it keeps going)
		else
			r.slipLeft = 0
			finishRun(r, now)
			return
		end
	end
	placeBead(r)
end

-- Lets one drop fall from the drip point.
local function releaseDrop(r: Rivulet, at: Vector3, size: number, velocity: Vector3)
	Blood.drop(at, velocity, size, r.random, BloodRivulet.passiveScale())
	if r.random:NextNumber() < 0.4 then
		-- (a tiny satellite drop follows: the neck breaking)
		local small = size / 4
		local rng = Random.new(r.random:NextInteger(1, 2 ^ 30))
		task.delay(0.04, function()
			Blood.drop(at, velocity * 0.8, math.max(small, 0.015), rng, BloodRivulet.passiveScale())
		end)
	end
end

-- The drip point: a hanging drop swells, stretches, falls; or a stream.
local function stepDrip(r: Rivulet, now: number, far: boolean)
	if not fed(r, now) then
		finishRun(r, now)
		return
	end
	local part = r.part
	local g = localDown(part)
	local velocity = part.AssemblyLinearVelocity
	-- a stream: pours, drops every 0.12 s
	local stream, streamWeld = r.stream, r.streamWeld
	if stream and streamWeld then
		local length = r.random:NextNumber(0.2, 0.35)
		local right = g:Cross(Vector3.new(0.37, 0.71, 0.6))
		if right.Magnitude < 1e-3 then
			right = Vector3.new(1, 0, 0)
		end
		streamWeld.C0 = CFrame.fromMatrix(r.tip + g * (length / 2), right.Unit, -g)
		local mesh = stream:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			mesh.Scale = Vector3.new(0.035, length, 0.035) / HOLDER
		end
		if now >= r.nextDrop then
			r.nextDrop = now + 0.12
			releaseDrop(
				r,
				part.CFrame * (r.tip + g * length),
				r.random:NextNumber(0.035, 0.055),
				velocity * 0.5 + Vector3.new(0, -2, 0)
			)
		end
		return
	end
	-- far away (or too many hanging drops): plain drops off the tip
	local pendant = r.pendant
	if pendant == nil and not far then
		pendant = takePendant(r)
		if pendant then
			pendant.period = nextInterval(r)
			r.pendant = pendant
		end
	end
	if pendant == nil then
		if now >= r.nextDrop then
			r.nextDrop = now + nextInterval(r)
			releaseDrop(
				r,
				part.CFrame * (r.tip + g * 0.03),
				r.random:NextNumber(0.05, 0.075),
				velocity * 0.5 + Vector3.new(0, -0.5, 0)
			)
		end
		return
	end
	local t = math.clamp((now - pendant.born) / pendant.period, 0, 1)
	local size: number
	local stretch = 1
	if now < pendant.snapUntil then
		-- (the drop just fell: what stays wobbles 0.35 → 0.45 → 0.35)
		local w = 1 - math.abs((pendant.snapUntil - now) / 0.1 * 2 - 1)
		size = pendant.base * (1 + 0.28 * w)
	else
		-- swells (fast, then slower), the last quarter it stretches: the neck
		size = pendant.base + (pendant.size - pendant.base) * (1 - (1 - t) ^ 2)
		if t > 0.75 then
			stretch = 1 + 0.6 * (t - 0.75) / 0.25
		end
	end
	pendant.last, pendant.stretch = size, stretch
	local right = g:Cross(Vector3.new(0.37, 0.71, 0.6))
	if right.Magnitude < 1e-3 then
		right = Vector3.new(1, 0, 0)
	end
	local centre = r.tip + g * (size * stretch * 0.45)
	pendant.weld.C0 = CFrame.fromMatrix(centre, right.Unit, -g)
	pendant.mesh.Scale = Vector3.new(size, size * stretch, size) / HOLDER
	-- shaken off: the part moves fast (a punch thrown, a hit taken)
	local shaken = velocity.Magnitude > 10 and t > 0.5
	if t >= 1 or shaken then
		local throw = if shaken then velocity else velocity * 0.5 + Vector3.new(0, -0.5, 0)
		releaseDrop(r, part.CFrame * (r.tip + g * (size * stretch * 0.6)), size, throw)
		pendant.base = size * 0.35
		pendant.born = now + 0.1
		pendant.snapUntil = now + 0.1
		pendant.period = nextInterval(r)
		pendant.size = r.random:NextNumber(0.055, 0.08)
	end
end

------------------------------------------------------------------------------
-- Crust: a run stopped 30 s ago dries into a cracked crust (until respawn)
------------------------------------------------------------------------------

local function crust(r: Rivulet)
	r.crusted = true
	local part = r.part
	if part.Parent == nil then
		return
	end
	if BloodStain.hasImage("crustStrip") then
		for _, segment in r.segments do
			if not segment.record.dead then
				local cf = part.CFrame
				local record = BloodStain.place(
					"crustStrip",
					cf * segment.origin,
					cf:VectorToWorldSpace(segment.normal),
					cf:VectorToWorldSpace(segment.dir),
					r.width,
					0.04,
					{
						onto = part,
						random = r.random,
						profile = CRUST_PROFILE,
						start = PALETTE.DRY,
						dryColor = PALETTE.OLD,
						owner = r.model,
						upright = true,
						turn = math.pi,
						noEdge = true,
						alpha = 0.1,
						priority = 3,
					}
				)
				if record then
					BloodStain.movePiece(record, 1, segment.length / 2, 0, segment.length)
					BloodAge.remove(segment.record)
					segment.record = record
					BloodRivulet.addMark(r.model, record, false, r.isHead)
				end
			end
		end
	end
	if r.bead and BloodStain.hasImage("crustPatch") then
		-- the bead dries into a small dark dot
		local cf = part.CFrame
		local w = r.width * 1.4
		local record = BloodStain.place(
			"crustPatch",
			cf * r.tip,
			cf:VectorToWorldSpace(r.normal),
			cf:VectorToWorldSpace(localDown(part)),
			w,
			w * 1.2,
			{
				onto = part,
				random = r.random,
				profile = CRUST_PROFILE,
				start = PALETTE.DRY,
				dryColor = PALETTE.OLD,
				owner = r.model,
				priority = 3,
			}
		)
		if record then
			removeBead(r)
			BloodRivulet.addMark(r.model, record, false, r.isHead)
		end
	end
end

------------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------------

local function kill(r: Rivulet)
	if r.dead then
		return
	end
	r.dead = true
	givePendant(r)
	removeStream(r)
	deactivate(r)
	-- (forget it as its wound's last run: a string key is never let go by
	-- the weak table, it would keep the old body in memory after a respawn)
	local source = r.opts.source
	if source ~= nil and bySource[source] == r then
		bySource[source] = nil
	end
	local index = table.find(resting, r)
	if index then
		table.remove(resting, index)
	end
	local state = byModel[r.model]
	if state then
		local mine = table.find(state.rivulets, r)
		if mine then
			table.remove(state.rivulets, mine)
		end
	end
end

-- Blood starts running from `worldPoint` on `part` of `model`.
function BloodRivulet.start(
	model: Model,
	part: BasePart,
	worldPoint: Vector3,
	options: Options?
): Rivulet?
	if not Config.Blood.ENABLED or #active >= cap("RIVULETS", 40) then
		return nil
	end
	local opts: Options = options or {}
	local skin, at, out = BloodStain.onSkin(part, worldPoint)
	if skin == nil then
		return nil
	end
	local state = modelState(model)
	local moving = 0
	for _, other in state.rivulets do
		if other.state ~= "done" then
			moving += 1
		end
	end
	if moving >= MAX_ACTIVE_PER_CHARACTER then
		return nil
	end
	local now = os.clock()
	local random = opts.random or Random.new()
	local cf = skin.CFrame
	local tip = cf:PointToObjectSpace(at)
	local normal = cf:VectorToObjectSpace(out)
	-- (it breaks over the LOWEST point of the wound's lip)
	local g = localDown(skin)
	local slide = g - normal * g:Dot(normal)
	if slide.Magnitude > 0.25 then
		tip += slide.Unit * 0.03
	end
	local r: Rivulet = {
		model = model,
		part = skin,
		isHead = skin.Name == "Head",
		width = math.clamp(opts.width or 0.05, 0.04, 0.09),
		volume = opts.volume or 0.4,
		start = opts.start or PALETTE.VENOUS,
		random = random,
		opts = opts,
		segments = {},
		tip = tip,
		normal = normal,
		state = "well",
		stateEnd = now + (if opts.noWell then 0 else random:NextNumber(0.3, 0.8)),
		slipLeft = 0,
		slipSpeed = 0,
		guideIndex = 1,
		feedUntil = now + (opts.feed or 0),
		angle = opts.angle or math.rad(random:NextNumber(-12, 12)),
		newPiece = false,
		bead = nil,
		beadMesh = nil,
		beadWeld = nil,
		beadRecord = nil,
		beadScale = 0.4,
		pendant = nil,
		stream = nil,
		streamWeld = nil,
		nextDrop = 0,
		ride = nil,
		rideIndex = 1,
		path = { tip },
		forked = false,
		pooled = false,
		doneAt = nil,
		crusted = false,
		dead = false,
	}
	-- a second flow from the same wound, while the first is still wet: it
	-- runs along the old channel (fast) instead of making a new one
	local source = opts.source
	if source ~= nil then
		local old = bySource[source]
		local first = if old then old.segments[1] else nil
		if
			old
			and first
			and not old.dead
			and old.part == skin
			and not first.record.dead
			and BloodAge.wetness(first.record) > 0.2
		then
			r.segments = old.segments
			old.segments = {}
			r.ride = table.clone(old.path)
			r.path = table.clone(old.path)
			r.tip = old.path[1] or tip
			r.guideIndex = old.guideIndex
			for _, segment in r.segments do
				BloodAge.touch(segment.record) -- (wet and bright again)
			end
			removeBead(old)
			kill(old)
		end
		bySource[source] = r
	end
	makeBead(r)
	table.insert(state.rivulets, r)
	table.insert(active, r)
	if cameraDistance(skin) > RANGE then
		BloodRivulet.settle(r)
	end
	return r
end

-- Lays a run to its end at once (far from the camera: nobody sees it move).
function BloodRivulet.settle(r: Rivulet)
	local now = os.clock()
	for _ = 1, 60 do
		if r.dead or r.state == "done" or r.state == "drip" or r.pooled then
			break
		end
		r.state = "slip"
		advance(r, 0.06, now)
	end
	if r.state == "slip" or r.state == "well" then
		enterHold(r, now)
	end
end

function BloodRivulet.tip(r: Rivulet): Vector3?
	if r.dead or r.part.Parent == nil then
		return nil
	end
	return r.part.CFrame * r.tip
end

-- Its drip point (world) while blood hangs / pours there, else nil.
function BloodRivulet.dripPoint(r: Rivulet): Vector3?
	if r.dead or r.state ~= "drip" then
		return nil
	end
	return r.part.CFrame * (r.tip + localDown(r.part) * 0.04)
end

-- Does it make its drops itself (hanging at a drip point)?
function BloodRivulet.handlesDrops(r: Rivulet): boolean
	return not r.dead and r.state == "drip"
end

-- Has it stopped (ran out of blood, or gone)? A run pooling on skin facing
-- up has NOT stopped: its blood gathers there.
function BloodRivulet.stopped(r: Rivulet): boolean
	return r.dead or r.state == "done"
end

-- More blood from the wound: it runs further / drips longer, wet again.
function BloodRivulet.refeed(r: Rivulet, volume: number, seconds: number)
	if r.dead then
		return
	end
	local now = os.clock()
	r.volume += volume
	r.feedUntil = math.max(r.feedUntil, now + seconds)
	if r.state == "done" then
		r.state = "hold"
		r.stateEnd = now + r.random:NextNumber(0.2, 0.6)
		r.doneAt = nil
		r.pooled = false
		local index = table.find(resting, r)
		if index then
			table.remove(resting, index)
		end
		if not table.find(active, r) then
			table.insert(active, r)
		end
		if r.bead == nil then
			makeBead(r)
		end
	end
	local record = r.beadRecord
	if record then
		BloodAge.touch(record)
	end
	for _, segment in r.segments do
		if not segment.record.dead then
			BloodAge.touch(segment.record)
		end
	end
end

-- A wipe: only `keep` (0..1) of its length stays; the front goes back there.
function BloodRivulet.shorten(r: Rivulet, keep: number)
	if r.dead then
		return
	end
	local total = 0
	for _, segment in r.segments do
		total += segment.length
	end
	local left = total * math.clamp(keep, 0, 1)
	local kept: { Segment } = {}
	for _, segment in r.segments do
		if left <= 0.02 then
			BloodAge.remove(segment.record)
		else
			if segment.length > left then
				segment.length = left
				BloodStain.movePiece(segment.record, 1, left / 2, 0, left)
			end
			left -= segment.length
			table.insert(kept, segment)
			r.tip = segment.origin + segment.dir * segment.length
			r.normal = segment.normal
		end
	end
	r.segments = kept
	if #kept == 0 then
		r.tip = r.path[1] or r.tip
	end
	r.path = { r.tip }
	r.ride = nil
	givePendant(r)
	removeStream(r)
	local now = os.clock()
	if r.state ~= "done" then
		enterHold(r, now, r.random:NextNumber(0.5, 1))
	end
	r.beadScale = 0.6
	placeBead(r)
end

-- Every run of `model` stops (what is drawn stays and ages).
function BloodRivulet.stopAll(model: Model)
	for _, r in table.clone(active) do
		if r.model == model then
			kill(r)
		end
	end
	for _, r in table.clone(resting) do
		if r.model == model then
			kill(r)
		end
	end
end

-- The runs of `model` still there (moving or stopped, not crusted).
function BloodRivulet.of(model: Model): { Rivulet }
	local state = byModel[model]
	return if state then state.rivulets else {}
end

------------------------------------------------------------------------------
-- The update (15 times a second, only near the camera)
------------------------------------------------------------------------------

local function step(r: Rivulet, now: number, dt: number)
	local part = r.part
	if part.Parent == nil or r.model.Parent == nil then
		kill(r)
		return
	end
	local far = cameraDistance(part) > RANGE
	local state = r.state
	if state == "drip" then
		stepDrip(r, now, far)
		placeBead(r)
		return
	end
	if far then
		BloodRivulet.settle(r)
		return
	end
	if state == "well" then
		-- the wound wells up before it runs over
		r.beadScale = 0.4 + 0.6 * math.clamp(1 - (r.stateEnd - now) / 0.5, 0, 1)
		placeBead(r)
		if now >= r.stateEnd then
			enterHold(r, now, 0.05)
		end
	elseif state == "hold" then
		-- stuck: the bead swells (more where it pools)
		local target = if r.pooled then 1.8 else 1.35
		r.beadScale = math.min(target, r.beadScale + dt * 0.8)
		placeBead(r)
		if r.pooled then
			if not fed(r, now) and now >= r.stateEnd then
				finishRun(r, now)
			elseif now >= r.stateEnd then
				-- (still lying there? try again a bit later: it may have turned)
				r.pooled = false
				r.state = "slip"
				r.slipLeft = 0.01
				r.slipSpeed = 0.2
			end
			return
		end
		if now >= r.stateEnd then
			local riding = r.ride ~= nil
			local fast = r.opts.fast or 1
			r.slipLeft = r.random:NextNumber(0.03, 0.1) * (if riding then 2.5 else 1) * fast
			r.slipSpeed = r.slipLeft / r.random:NextNumber(0.08, 0.15)
			r.state = "slip"
		end
	elseif state == "slip" then
		-- it jumps: the bead shrinks back as it moves
		local distance = math.min(r.slipLeft, r.slipSpeed * dt)
		r.slipLeft -= distance
		r.beadScale = math.max(1, r.beadScale - dt * 4)
		advance(r, distance, now)
		if r.state == "slip" and (r.slipLeft <= 1e-4 or r.pooled) then
			enterHold(r, now, if r.pooled then 1.2 else nil)
		end
	end
end

local accumulated = 0
local nextRestCheck = 0
RunService.Heartbeat:Connect(function(dt: number)
	accumulated += dt
	if accumulated < TICK then
		return
	end
	local stepTime = math.min(accumulated, 0.25)
	accumulated = 0
	if #active == 0 and #resting == 0 then
		return
	end
	debug.profilebegin("BloodRivulet")
	local now = os.clock()
	for _, r in table.clone(active) do
		if not r.dead and r.state ~= "done" then
			step(r, now, stepTime)
		end
	end
	if now >= nextRestCheck then
		-- stopped runs: crust after 30 s (the face's ones), forget them later
		nextRestCheck = now + 1
		local index = 1
		while index <= #resting do
			local r = resting[index]
			local doneAt = r.doneAt or now
			if r.dead then
				table.remove(resting, index) -- (kill already done: just forget it)
				continue
			end
			if r.part.Parent == nil then
				kill(r)
				continue
			end
			if r.opts.crust and not r.crusted and now - doneAt > 30 then
				crust(r)
			end
			if now - doneAt > 120 then
				-- (stays drawn and ageing; just no longer a "run")
				kill(r)
				continue
			end
			index += 1
		end
	end
	debug.profileend()
end)

return table.freeze(BloodRivulet)
