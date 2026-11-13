--!strict
-- BloodGush: how a torn artery bleeds, for the finishers that tear something
-- out (the head under the bat, the liver, the arm). Shared by HeadBlast,
-- LiverRip and ArmRip, on every client.
--
-- What a real one does, and what this draws:
--   • it SPURTS with the heartbeat: a jet on each beat (strong, arcing out
--     a metre or two), a weak flow between beats; the heart races, then
--     slows and weakens as the blood runs out (a few seconds);
--   • each jet is a rope of liquid that breaks into drops (real drops fly
--     with it, with the jet's gravity: they stretch, fall apart, splash);
--     with the beam_stream picture the rope itself is drawn on each beat;
--   • it comes down where its arc meets the floor / a wall: on strong beats
--     a wave of big drops (the artery sweeping by), elongated drops in a
--     line along the way it flew, and the blood gathers into a pool there;
--   • it runs down the body from the wound, in runs that lengthen, and
--     soaks into the clothes;
--   • a pool spreads under it, faster at first, flowing downhill, and
--     keeps creeping outward a while after it stops (BloodPool);
--   • whoever is right there gets it on them (dark spots on his front, his
--     arms).
--
--   BloodGush.artery(part, local, options)   jets out of `local` (in `part`'s
--       space; the jet goes out along its LookVector)
--   BloodGush.runDown(part, local, count, seed)   streaks running down the body
--   BloodGush.splatter(target, toward, count, seed)   spots on someone close
--   BloodGush.neck(model, seed)       the head gone: both carotids, the
--                                     jugular welling, down the chest
--   BloodGush.torso(model, local, outward, seed)   a hole in the body (the
--                                     liver, the shoulder): the artery, the
--                                     streaks running down
--   BloodGush.stump(part, local, wound, seed, options?)   the big pool of a
--                                     finisher's wound (Config.Blood.
--                                     FINISHER_POOLS): the blood pours out
--                                     of `local` (in `part`'s space) onto the
--                                     floor under it, following the part
--   BloodGush.lay(part, local, wound, seed)   that pool already there (a body
--                                     we only see after the finisher)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Blood = require(script.Parent.Blood)
local BloodBody = require(script.Parent.BloodBody)
local BloodPool = require(script.Parent.BloodPool)
local BloodStain = require(script.Parent.BloodStain)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local BloodGush = {}

local PALETTE = Config.Blood.PALETTE
local BLOOD = PALETTE.VENOUS -- dark, once out
local BLOOD_WET = PALETTE.ARTERIAL -- fresh, arterial (brighter)
local GRAVITY = 60 -- studs/s², what the particles use too (they look heavier)
local FINISHER_POOLS = Config.Blood.FINISHER_POOLS
local STUMP_TICK = 0.1 -- seconds between two pours of a stump
-- (where the neck pours, in the torso's space: the top, where the head was)
BloodGush.NECK_POINT = Vector3.new(0, 1.1, 0)

-- One wound of Config.Blood.FINISHER_POOLS (NECK, SHOULDER...).
export type Wound = {
	LITRES: number,
	SECONDS: number,
	PULSE: number,
	BEAT: number,
}

export type StumpOptions = {
	ignore: { Instance }?, -- (what the floor ray goes through: the body, an organ)
	delay: number?, -- seconds before it starts
	drag: boolean?, -- false: no smear while it slides (its module draws one)
}

export type Options = {
	seconds: number, -- how long it keeps pumping
	beat: number, -- seconds between beats at the start (it slows down)
	speed: number, -- studs/s of the first jets
	size: number, -- how thick the jet is (studs)
	pool: number, -- studs across the pool grows to (0: none)
	seed: number,
	ignore: { Instance }?, -- (bodies the jets' landing rays go through)
}

local function jetEmitter(parent: Attachment, size: number): ParticleEmitter
	local jet = Instance.new("ParticleEmitter")
	jet.Name = "Jet"
	jet.Texture = "rbxasset://textures/particles/smoke_main.dds"
	jet.Color = ColorSequence.new(BLOOD_WET, BLOOD)
	jet.LightEmission = 0
	jet.LightInfluence = 1
	jet.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	jet.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, size * 0.6),
	})
	-- stretched along the way they fly: a stream, not dots
	jet.Orientation = Enum.ParticleOrientation.VelocityParallel
	jet.Squash = NumberSequence.new(1.5)
	jet.Lifetime = NumberRange.new(0.5, 0.9)
	jet.Speed = NumberRange.new(8, 12)
	jet.SpreadAngle = Vector2.new(5, 5)
	jet.Acceleration = Vector3.new(0, -GRAVITY, 0)
	jet.Drag = 0.25
	jet.EmissionDirection = Enum.NormalId.Front
	jet.Rate = 0
	if Blood.droplets(jet, "gobs") then
		-- (the picture: blobs and ligaments, a stream breaking into drops;
		-- the jet's own gravity kept, the same as its drops)
		jet.Acceleration = Vector3.new(0, -GRAVITY, 0)
		jet.Size = NumberSequence.new(size * 1.2, size * 0.7)
	end
	jet.Parent = parent
	return jet
end

local function mistEmitter(parent: Attachment): ParticleEmitter
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(PALETTE.ARTERIAL_LIGHT)
	mist.LightEmission = 0
	mist.LightInfluence = 1
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	mist.Lifetime = NumberRange.new(0.3, 0.6)
	mist.Speed = NumberRange.new(2, 5)
	mist.SpreadAngle = Vector2.new(40, 40)
	mist.Acceleration = Vector3.new(0, -8, 0)
	mist.Drag = 2
	mist.EmissionDirection = Enum.NormalId.Front
	mist.Rate = 0
	Blood.droplets(mist, "mist")
	mist.Parent = parent
	return mist
end

-- Where a jet leaving `from` at `velocity` meets something (floor, wall):
-- ballistic, found by rays. Returns the hit, the speed it arrives with and
-- the time it flies.
local function landing(
	from: Vector3,
	velocity: Vector3,
	ignore: { Instance }
): (RaycastResult?, Vector3, number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = table.clone(ignore)
	table.insert(skip, BloodStain.folder)
	params.FilterDescendantsInstances = skip
	local position, moving = from, velocity
	local time = 0
	for _ = 1, 40 do
		local dt = 0.03
		local step = moving * dt
		local hit = workspace:Raycast(position, step, params)
		if hit then
			return hit,
				moving,
				time + dt * (hit.Position - position).Magnitude / math.max(step.Magnitude, 1e-3)
		end
		position += step
		moving += Vector3.new(0, -GRAVITY * dt, 0)
		time += dt
	end
	return nil, moving, time
end

-- One jet's blood coming down: where the bulk lands, a big stain (on the
-- first strong beats the wave of an artery sweeping by), elongated drops
-- strung out along the way it flew; it pools there.
local function rain(
	from: Vector3,
	velocity: Vector3,
	strength: number,
	ignore: { Instance },
	random: Random,
	key: any
): (RaycastResult?, Vector3, number)
	local hit, moving, time = landing(from, velocity, ignore)
	if hit == nil then
		return nil, moving, time
	end
	local at, normal = hit.Position, hit.Normal
	local tangent = moving - normal * moving:Dot(normal)
	local along = if tangent.Magnitude > 0.1
		then tangent.Unit
		else normal:Cross(Vector3.new(1, 0, 0))
	local delay = math.clamp(time, 0.08, 0.8)
	local seed = random:NextInteger(1, 2 ^ 30)
	local big = random:NextNumber() < 0.5 + 0.3 * strength -- (not every beat: the marks are counted)
	local streaks = 1 + math.floor(1.5 * strength)
	local onto = hit.Instance
	task.delay(delay, function()
		if onto.Parent == nil then
			return
		end
		local rand = Random.new(seed)
		if big then
			if strength > 0.55 then
				-- a strong beat: a wave of big drops along the way it swept
				BloodStain.stain(
					"arterialArc",
					at,
					normal,
					along,
					0.35 + 0.35 * strength,
					1 + 1.6 * strength,
					{
						random = rand,
						onto = onto :: BasePart,
						start = BLOOD_WET,
						pinned = true,
						priority = 3,
					}
				)
			else
				Blood.splat(at, normal, 0.3 + 0.4 * strength, moving, onto :: BasePart, rand)
			end
		end
		for index = 1, streaks do
			local offset = along * rand:NextNumber(-0.6, 1.2) * index * 0.35
				+ along:Cross(normal) * rand:NextNumber(-0.12, 0.12)
			Blood.splat(
				at + offset,
				normal,
				rand:NextNumber(0.1, 0.22) * (0.6 + strength),
				moving,
				onto :: BasePart,
				rand
			)
		end
		-- (on the ground it gathers: the pools of each landing merge)
		if normal.Y > 0.7 then
			BloodPool.feed(key, at, 0.5 + 0.8 * strength, 0.6, 1.4)
		end
	end)
	return hit, moving, time
end

-- The liquid rope of a spurt (only with its picture, beam_stream): from the
-- wound to where it lands, curved like the jet's arc.
local function streamBeam(parent: Instance, size: number): (Beam?, Attachment?, Attachment?)
	local id = BloodStain.image("beamStream", nil, 1)
	if id == 0 then
		return nil, nil, nil
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "StreamFrom"
	a0.Parent = workspace.Terrain
	local a1 = Instance.new("Attachment")
	a1.Name = "StreamTo"
	a1.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Name = "Stream"
	beam.Texture = "rbxassetid://" .. id
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 1
	beam.TextureSpeed = 3
	beam.Color = ColorSequence.new(BLOOD_WET, BLOOD)
	beam.LightInfluence = 0.8
	beam.FaceCamera = true
	beam.Segments = 16
	beam.Width0 = size * 0.9
	beam.Width1 = size * 0.35
	beam.Transparency = NumberSequence.new(1)
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Parent = parent
	return beam, a0, a1
end

-- The rope bent along the arc (a ballistic curve as a Bézier: its control
-- points a third of the way along the speeds at both ends).
local function bendBeam(
	beam: Beam,
	a0: Attachment,
	a1: Attachment,
	from: Vector3,
	velocity: Vector3,
	to: Vector3,
	arrival: Vector3,
	time: number
)
	local up = Vector3.new(0, 1, 0)
	local function frame(position: Vector3, direction: Vector3): CFrame
		local d = if direction.Magnitude > 1e-3 then direction.Unit else up
		local other = if math.abs(d.Y) > 0.99 then Vector3.new(1, 0, 0) else up
		-- (an Attachment's Axis is its X: along the speed there)
		return CFrame.fromMatrix(position, d, other:Cross(d).Unit:Cross(d))
	end
	a0.WorldCFrame = frame(from, velocity)
	a1.WorldCFrame = frame(to, arrival)
	beam.CurveSize0 = velocity.Magnitude * time / 3
	beam.CurveSize1 = arrival.Magnitude * time / 3
end

-- Drops of the jet itself: real drops (they fly with the jet's gravity,
-- stretch, break apart and splash where they land).
local function jetDrops(
	hole: Attachment,
	speed: number,
	size: number,
	count: number,
	random: Random
)
	local frame = hole.WorldCFrame
	for _ = 1, count do
		local spread =
			Vector3.new(random:NextNumber(-0.08, 0.08), random:NextNumber(-0.08, 0.08), 0)
		local direction = frame:VectorToWorldSpace((Vector3.new(0, 0, -1) + spread).Unit)
		Blood.drop(
			frame.Position + direction * random:NextNumber(0, 0.25),
			direction * speed * random:NextNumber(0.8, 1.1) + Vector3.new(0, 1.5, 0),
			size * random:NextNumber(0.35, 0.7),
			random,
			GRAVITY / workspace.Gravity
		)
	end
end

-- Blood welling out of the hole between beats and after: it only DRIPS
-- (slow gravity, a round drop where it lands), it is not thrown.
local function oozeDrop(hole: Attachment, size: number, random: Random)
	local frame = hole.WorldCFrame
	Blood.drop(
		frame.Position + frame.LookVector * 0.05,
		frame.LookVector * random:NextNumber(0.3, 1),
		size * random:NextNumber(0.35, 0.55),
		random,
		Blood.passiveScale(),
		{ passive = true }
	)
end

-- An artery torn open at `local` (in `part`'s space; out along its LookVector).
function BloodGush.artery(part: BasePart, localCFrame: CFrame, options: Options)
	if not Config.Blood.ENABLED then
		return
	end
	local random = Random.new(options.seed)
	local hole = Instance.new("Attachment")
	hole.Name = "Artery"
	hole.CFrame = localCFrame
	hole.Parent = part
	local jet = jetEmitter(hole, options.size)
	local mist = mistEmitter(hole)
	local ignore: { Instance } = options.ignore or { part :: Instance }
	local key = { artery = options.seed } -- (its own pool; landings merge into it)
	local beam, from, to = streamBeam(hole, options.size)
	local owner = part:FindFirstAncestorOfClass("Model")
	if options.pool > 0 then
		task.delay(0.3, function()
			if part.Parent then
				BloodPool.spread(
					hole.WorldPosition,
					options.pool,
					options.seconds + 3,
					random:NextInteger(1, 2 ^ 20)
				)
			end
		end)
	end
	task.spawn(function()
		local start = os.clock()
		local beat = options.beat
		-- the first one: the vessel tears, all at once
		mist:Emit(30)
		jet.Speed = NumberRange.new(options.speed * 0.9, options.speed * 1.1)
		jet:Emit(math.floor(60 * options.size / 0.12))
		local first = hole.WorldCFrame.LookVector * options.speed + Vector3.new(0, 2, 0)
		rain(hole.WorldPosition, first, 1, ignore, random, key)
		jetDrops(hole, options.speed, options.size, 8, random)
		while hole.Parent and part.Parent and os.clock() - start < options.seconds do
			local left = 1 - (os.clock() - start) / options.seconds -- (it runs out)
			local strength = left * left * 0.8 + left * 0.2
			-- the jet, on the beat: its own direction wavers (the body moves)
			local wobble =
				CFrame.Angles(random:NextNumber(-0.12, 0.12), random:NextNumber(-0.12, 0.12), 0)
			hole.CFrame = localCFrame * wobble
			local speed = options.speed * (0.35 + 0.65 * strength)
			jet.Speed = NumberRange.new(speed * 0.85, speed * 1.1)
			jet.Rate = 260 * (0.3 + 0.7 * strength)
			mist.Rate = 40 * strength
			local velocity = hole.WorldCFrame.LookVector * speed + Vector3.new(0, 1.5, 0)
			local hit, arrival, time =
				rain(hole.WorldPosition, velocity, strength, ignore, random, key)
			jetDrops(hole, speed, options.size, 3 + math.floor(4 * strength), random)
			if owner and strength > 0.25 then
				SoundController.play("ArterialSpurt", owner)
			end
			if beam and from and to and hit then
				-- the rope of blood from the wound to where it lands...
				bendBeam(beam, from, to, hole.WorldPosition, velocity, hit.Position, arrival, time)
				beam.Width0 = options.size * (0.5 + 0.4 * strength)
				beam.Transparency = NumberSequence.new(0.05, 0.25)
			end
			task.wait(0.11 + 0.05 * (1 - strength))
			if beam then
				-- ...that breaks into drops when the beat ends
				beam.Transparency = NumberSequence.new(0.6, 1)
				jet:Emit(math.floor(10 * strength) + 2)
			end
			-- between beats: it never stops (a real artery pulses in LENGTH,
			-- research): a weaker, shorter stream, and it wells out and drips
			jet.Rate = 260 * (0.3 + 0.7 * strength) * 0.35
			jet.Speed = NumberRange.new(speed * 0.45, speed * 0.6)
			mist.Rate = 0
			oozeDrop(hole, options.size, random)
			task.wait(0.06)
			if beam then
				beam.Transparency = NumberSequence.new(1)
			end
			task.wait(math.max(0.05, beat - 0.19))
			beat = math.min(beat * 1.06, 1.1) -- (the heart slows)
		end
		jet.Rate = 0
		mist.Rate = 0
		-- it keeps oozing a little
		jet.Speed = NumberRange.new(0.3, 1)
		jet.Rate = 6
		for _ = 1, 8 do -- (3 s of slow drips)
			if hole.Parent == nil then
				break
			end
			oozeDrop(hole, options.size * 0.7, random)
			task.wait(0.375)
		end
		jet.Rate = 0
		if from and to then
			from:Destroy()
			to:Destroy()
		end
		Debris:AddItem(hole, 1.5)
	end)
end

-- Blood running down the body from `local` (in `part`'s space): runs on its
-- skin that lengthen downwards, a bead at their tips (Blood.run).
function BloodGush.runDown(part: BasePart, localPoint: Vector3, count: number, seed: number)
	if not Config.Blood.ENABLED then
		return
	end
	local random = Random.new(seed)
	local model = part:FindFirstAncestorOfClass("Model")
	for index = 1, count do
		local delay = random:NextNumber(0, 0.8) + index * 0.1
		local offset = Vector3.new(
			random:NextNumber(-0.18, 0.18),
			random:NextNumber(-0.1, 0.05),
			random:NextNumber(-0.18, 0.18)
		)
		local width = random:NextNumber(0.05, 0.11)
		local length = random:NextNumber(0.6, 1.6)
		local runSeed = random:NextInteger(1, 2 ^ 30)
		task.delay(delay, function()
			if part.Parent == nil then
				return
			end
			local point = part.CFrame * (localPoint + offset)
			local _, _, out = BloodStain.onSkin(part, point)
			Blood.run(point, out, width, {
				onto = part,
				random = Random.new(runSeed),
				length = length,
				owner = model,
				start = if index % 2 == 0 then BLOOD_WET else BLOOD,
			})
			if model then
				BloodBody.soak(model, part, point, 0.5)
			end
		end)
	end
end

-- Spots of blood on `target` (someone right there), on its side facing
-- `toward` (the wound): his front, his arms - each one stretched away from
-- the wound (the way it flew), sticking to the skin (the round head too).
function BloodGush.splatter(target: Model, toward: Vector3, count: number, seed: number)
	if not Config.Blood.ENABLED then
		return
	end
	local random = Random.new(seed)
	local parts: { BasePart } = {}
	for _, name in { "Torso", "Right Arm", "Left Arm", "Head" } do
		local part = target:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	if #parts == 0 then
		return
	end
	for _ = 1, count do
		local part = parts[random:NextInteger(1, #parts)]
		local side = part.CFrame:VectorToObjectSpace(toward - part.Position)
		local half = part.Size / 2
		-- on the face that looks at the wound (the biggest component)
		local ax, ay, az = math.abs(side.X), math.abs(side.Y), math.abs(side.Z)
		local point: Vector3
		if ax >= ay and ax >= az then
			point = Vector3.new(
				math.sign(side.X) * half.X,
				random:NextNumber(-half.Y, half.Y) * 0.9,
				random:NextNumber(-half.Z, half.Z) * 0.9
			)
		elseif az >= ay then
			point = Vector3.new(
				random:NextNumber(-half.X, half.X) * 0.9,
				random:NextNumber(-half.Y, half.Y) * 0.9,
				math.sign(side.Z) * half.Z
			)
		else
			point = Vector3.new(
				random:NextNumber(-half.X, half.X) * 0.9,
				math.sign(side.Y) * half.Y,
				random:NextNumber(-half.Z, half.Z) * 0.9
			)
		end
		local world = part.CFrame * point
		local away = world - toward
		local s = random:NextNumber(0.06, 0.16)
		local stretch = random:NextNumber(1, 2.2)
		BloodStain.stain(
			if stretch > 1.6 then "spatterTail" else "spatterOval",
			world,
			away,
			away,
			s,
			s * stretch,
			{
				onto = part,
				random = random,
				profile = "body",
				start = BLOOD_WET,
				owner = target,
				priority = 2,
			}
		)
	end
	-- (his fists are bloody now: his next swings flick it off)
	for _, name in { "Right Arm", "Left Arm" } do
		local arm = target:FindFirstChild(name)
		if arm and arm:IsA("BasePart") then
			BloodBody.bloodyLimb(target, arm, 0.5)
		end
	end
end

-- The head gone (the bat): the two carotids spurt up and out on each beat,
-- the jugular wells and runs, the blood runs down the chest and back.
function BloodGush.neck(model: Model, seed: number)
	local torso = model:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	SoundController.play("BloodGurgle", model)
	-- (out of the top of the stump, above its cut flesh)
	local top = torso.Size.Y / 2 + 0.3
	for index, x in { -0.17, 0.17 } do
		local from = Vector3.new(x, top + 0.08, -0.12)
		BloodGush.artery(torso, CFrame.lookAt(from, from + Vector3.new(x * 1.5, 1, -0.35)), {
			seconds = 5.5,
			beat = 0.38,
			speed = 15,
			size = 0.13,
			pool = 0, -- (the big pool: BloodGush.stump below)
			seed = seed + index,
			ignore = { model :: Instance },
		})
	end
	local back = Vector3.new(0, top + 0.05, 0.15)
	BloodGush.artery(torso, CFrame.lookAt(back, back + Vector3.new(0, 1, 0.6)), {
		seconds = 6,
		beat = 0.38,
		speed = 4.5,
		size = 0.16,
		pool = 0,
		seed = seed + 7,
		ignore = { model :: Instance },
	})
	BloodGush.runDown(torso, Vector3.new(0, torso.Size.Y / 2, -0.5), 7, seed + 11)
	BloodGush.runDown(torso, Vector3.new(0, torso.Size.Y / 2, 0.5), 5, seed + 13)
	-- the big pool spreading from the neck, where the head was (HeadBlast
	-- lays the same one, seed + 101, for a body we only see later)
	BloodGush.stump(
		torso,
		BloodGush.NECK_POINT,
		FINISHER_POOLS.NECK,
		seed + 101,
		{ ignore = { model :: Instance } }
	)
end

-- A hole torn in the body at `localPoint` (torso space), facing `outward`:
-- the artery behind it spurting, the blood running down from it.
function BloodGush.torso(
	model: Model,
	localPoint: Vector3,
	outward: Vector3,
	seed: number,
	speed: number?
)
	local torso = model:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	BloodGush.artery(
		torso,
		CFrame.lookAt(localPoint, localPoint + outward.Unit + Vector3.new(0, 0.25, 0)),
		{
			seconds = 5.5,
			beat = 0.4,
			speed = speed or 11,
			size = 0.15,
			-- (no pool here: the finisher puts its big one, BloodGush.stump,
			-- where the body ends up)
			pool = 0,
			seed = seed,
			ignore = { model :: Instance },
		}
	)
	BloodGush.runDown(torso, localPoint, 9, seed + 5)
end

------------------------------------------------------------------------------
-- The finishers' big pools
------------------------------------------------------------------------------

-- How big the pool of `wound` gets once it has spread: studs across, the
-- front's radius then, and the area (studs²) to pour for it (BloodPool
-- spreads that area: its front gets there CREEP seconds after the wound
-- stops, its fingers run on beyond it).
local function poolSize(wound: Wound): (number, number, number)
	local size = FINISHER_POOLS.SIZE_PER_LITRE * math.sqrt(math.max(wound.LITRES, 0))
	local radius = size / 2
	return size, radius, math.pi * radius * radius
end

-- How much flows out at each tick (STUMP_TICK) of `wound`, adding up to
-- `area`: the heart pumping it out in spurts (each beat a surge, the beats
-- slowing and weakening as the pressure drops), then a steady ooze, then
-- slower and slower. The same on every client (it doesn't depend on the
-- frame rate).
local function schedule(wound: Wound, area: number): { number }
	local ticks = math.max(1, math.ceil(wound.SECONDS / STUMP_TICK))
	local amounts: { number } = {}
	local total = 0
	local beat = math.max(wound.BEAT, 0.2)
	local sinceBeat = 0
	local oozeTime = math.max(wound.SECONDS - wound.PULSE, 0.5)
	for index = 1, ticks do
		local t = (index - 1) * STUMP_TICK
		local amount: number
		if t < 0.15 then
			amount = 0 -- (it has to get out of the body first)
		elseif t < wound.PULSE then
			-- spurts: a surge on each beat, a weaker flow between
			local pressure = 1 - 0.45 * t / wound.PULSE
			amount = pressure * (0.3 + 1.4 * math.exp(-sinceBeat / beat * 5))
			sinceBeat += STUMP_TICK
			if sinceBeat >= beat then
				sinceBeat -= beat
				beat = math.min(beat * 1.04, 1.1) -- (the heart slows)
			end
		else
			-- then it oozes: steady a while, then slower and slower
			local u = (t - wound.PULSE) / oozeTime
			local level = if wound.PULSE > 0 then 0.42 else 1
			amount = level * (if u < 0.35 then 1 else math.exp(-(u - 0.35) * 4))
		end
		amounts[index] = amount
		total += amount
	end
	if total > 0 then
		for index, amount in amounts do
			amounts[index] = amount / total * area
		end
	end
	return amounts
end

-- The floor under a wound, through bodies, blood and `ignore`.
local function floorParams(ignore: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	local skip: { Instance } = table.clone(BloodStain.ground().FilterDescendantsInstances)
	for _, item in ignore do
		table.insert(skip, item)
	end
	params.FilterDescendantsInstances = skip
	return params
end

-- The big pool of a finisher's wound: the blood pours out of `localPoint`
-- (in `part`'s space) onto the floor under it, the way `wound` says
-- (Config.Blood.FINISHER_POOLS), the same pool on every client (`seed`):
--   • it follows the part as the body falls, rolls, settles (a frozen copy
--     replacing the body: it keeps pouring where the part last was);
--   • moving fast, or up in the air: no pool there (half of that blood is
--     lost on the way, the rest pours out once it stops); sliding on the
--     floor: a smear behind it;
--   • oozing: drops fall from the wound into its pool (they splash in it,
--     ring it with tiny drops: BloodPool.absorb).
function BloodGush.stump(
	part: BasePart,
	localPoint: Vector3,
	wound: Wound,
	seed: number,
	options: StumpOptions?
)
	if not Config.Blood.ENABLED or not FINISHER_POOLS.ENABLED or not BloodPool.claim(seed) then
		return
	end
	local opts: StumpOptions = options or {}
	local _, R, area = poolSize(wound)
	local amounts = schedule(wound, area)
	-- (its pool keeps spreading this long after the first blood reaches it)
	local spreadTime = wound.SECONDS + FINISHER_POOLS.CREEP
	local random = Random.new(seed)
	local key = { stump = seed } -- (its own pool; it merges with those it meets)
	task.spawn(function()
		if opts.delay and opts.delay > 0 then
			task.wait(opts.delay)
		end
		local params = floorParams(opts.ignore or {})
		local paramsAt = os.clock()
		local start = os.clock()
		local last = os.clock()
		local done = 0 -- (ticks poured so far)
		local carried = 0 -- (blood held back while it moved)
		local source = part.CFrame * localPoint
		local nextDrip = 0
		local drags = 0
		local dragFrom: Vector3? = nil
		while done < #amounts do
			task.wait(STUMP_TICK)
			local now = os.clock()
			if now - paramsAt > 1 then
				-- (new fighters joined: the ray goes through them too)
				paramsAt = now
				params = floorParams(opts.ignore or {})
			end
			-- where the wound is now (its body gone: where it was)
			local previous = source
			if part.Parent then
				source = part.CFrame * localPoint
			end
			local dt = math.max(now - last, 1e-3)
			last = now
			local speed = (source - previous).Magnitude / dt
			-- what flowed out since the last tick (a slow frame: a few ticks)
			local due = math.min(#amounts, math.floor((now - start) / STUMP_TICK) + 1)
			local amount = 0
			while done < due do
				done += 1
				amount += amounts[done]
			end
			local hit =
				workspace:Raycast(source + Vector3.new(0, 0.3, 0), Vector3.new(0, -14, 0), params)
			local height = if hit then source.Y - hit.Position.Y else math.huge
			if
				hit == nil
				or height > FINISHER_POOLS.MAX_HEIGHT
				or speed > FINISHER_POOLS.MOVING
			then
				-- in the air / moving: half of it is lost on the way
				carried += amount * 0.5
				if
					hit
					and opts.drag ~= false
					and height < 1.6
					and speed > FINISHER_POOLS.MOVING
					and drags < FINISHER_POOLS.DRAGS
					and now - start > 0.2
				then
					-- sliding on the floor: a smear behind the wound
					local from = dragFrom or hit.Position
					local gap = hit.Position - from
					if gap.Magnitude > 0.6 then
						drags += 1
						BloodStain.stain(
							"drag",
							from + gap / 2,
							hit.Normal,
							gap,
							0.45,
							gap.Magnitude + 0.2,
							{
								random = random,
								profile = "smear",
								category = "stain",
								start = BLOOD,
								material = hit.Material,
								noEdge = true,
								priority = 2,
							}
						)
						dragFrom = hit.Position
					elseif dragFrom == nil then
						dragFrom = hit.Position
					end
				else
					dragFrom = nil
				end
				continue
			end
			dragFrom = nil
			if hit.Material == Enum.Material.Water then
				continue -- (washed away)
			end
			BloodPool.pour(key, hit, amount + carried, R, seed, spreadTime)
			carried = 0
			-- oozing (after the spurts): drops falling off the wound into it
			local t = now - start
			if t > wound.PULSE and height > 0.25 and now >= nextDrip then
				nextDrip = now + random:NextNumber(0.3, 0.7)
				Blood.drop(
					source,
					Vector3.new(random:NextNumber(-0.3, 0.3), 0, random:NextNumber(-0.3, 0.3)),
					random:NextNumber(0.06, 0.1),
					random,
					Blood.passiveScale(),
					{ passive = true }
				)
			end
		end
	end)
end

-- The pool of a finisher's wound already there (a body we only see after
-- the finisher, or its frozen copy): its full size at once, under
-- `localPoint` (in `part`'s space). Once per `seed`: the live one (stump)
-- with the same seed, or an earlier look at this body, wins.
function BloodGush.lay(part: BasePart, localPoint: Vector3, wound: Wound, seed: number)
	local size = poolSize(wound)
	BloodPool.lay(part.CFrame * localPoint, size, seed)
end

return table.freeze(BloodGush)
