--!strict
-- RiftPortal: Dr. Rift's portals, on this client (look only): a portal (a
-- flat disc or a standing door) opening and closing, the green flash, the
-- portal gun's bolt, the two portals of the portal gun (and moving our own
-- character through, see `portals`), clones stepping in / out.
--
--   RiftPortal.portal(cframe, width, height, openTime, stay, closeTime)
--   RiftPortal.door(cframe, stay)       a standing 3.6 x 6 one
--   RiftPortal.flash(position, size)    RiftPortal.bolt(from, to)
--   RiftPortal.portals(data)  RiftPortal.cloneIn(data)  RiftPortal.cloneOut(data)
--
-- A portal, from the outside in: a soft green halo, the green rim, a thin
-- white-hot lip, a green band falling into a deep green ring, then a dark
-- void (another dimension); a shimmering ForceField skin over all of it.
-- On top (on the side the camera is on, so the void never hides them):
-- spiral arms of two layers turning against each other, rings sinking
-- into the dark (depth), arcs crackling off the rim, motes sucked in from
-- the rim, sparks and haze torn off it, a flickering green light.
-- Opening: a white-hot slit tears, the layers spring open one after the
-- other, a ripple and a ring of sparks burst out. Closing: it sucks in,
-- collapses, then snaps: a white pop, a shock ring, a puff of green smoke.
--
-- Everything animated runs from one RenderStepped for all portals, and
-- follows the rim's size: RiftFx's finisher ring (the portal round the
-- waist) is closed by tweening `parts` Size to tiny, and the arms, arcs and
-- particles shrink and go out with it.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local P = require(script.Parent.RiftParts)
local RiftGear = require(script.Parent.RiftGear)
local RiftBurn = require(script.Parent.RiftBurn)

local RiftPortal = {}

local RIFT_GREEN = P.RIFT_GREEN
local RIFT_DEEP = P.RIFT_DEEP
local RIFT_GLOW = P.RIFT_GLOW
local ghost = P.ghost
local disc = P.disc
local attachmentAt = P.attachmentAt
local emitter = P.emitter
local sparkTexture = P.sparkTexture
local fade = P.fade
local shakeNear = P.shakeNear

-- White-hot (a touch of green), the band under the lip, the deep ring, the
-- void, a green-grey smoke.
local HOT = Color3.fromRGB(232, 255, 214)
local SWIRL = Color3.fromRGB(70, 200, 60)
local DEPTH = Color3.fromRGB(16, 74, 28)
local VOID = Color3.fromRGB(4, 15, 8)
local FUME = Color3.fromRGB(46, 66, 48)

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local TINY = Vector3.new(0.05, 0.05, 0.06)
local TAU = math.pi * 2
-- (a circle / ellipse from four Bezier quarters: control length)
local KAPPA = 0.5523
-- Past this many portals at once the new ones are plain (layers + light).
local MAX_RICH = 20
-- Further than this from the camera a portal isn't animated.
local FAR = 260
local MAX_AFTERIMAGE_PARTS = 26

local random = Random.new()

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

-- A point on the ellipse of half-axes a, b (portal space: X right, Y up).
local function ellipse(a: number, b: number, angle: number): Vector3
	return Vector3.new(a * math.cos(angle), b * math.sin(angle), 0)
end

-- Along the ellipse, the way the angle grows.
local function tangentAt(a: number, b: number, angle: number): Vector3
	local along = Vector3.new(-a * math.sin(angle), b * math.cos(angle), 0)
	if along.Magnitude < 1e-4 then
		return Vector3.yAxis
	end
	return along.Unit
end

-- Out of the ellipse, square to it.
local function normalAt(a: number, b: number, angle: number): Vector3
	local out = Vector3.new(b * math.cos(angle), a * math.sin(angle), 0)
	if out.Magnitude < 1e-4 then
		return Vector3.xAxis
	end
	return out.Unit
end

local function planar(angle: number): Vector3
	return Vector3.new(math.cos(angle), math.sin(angle), 0)
end

-- How far off the portal's plane (towards the camera) something drawn on
-- its face sits, `rho` = 0 at the centre, 1 at the rim: just over the
-- bulge of the layers.
local function lift(rho: number): number
	return 0.035 + 0.15 * math.max(0, 1 - rho * rho)
end

local function newBeam(
	parent: Instance,
	a0: Attachment,
	a1: Attachment,
	color: ColorSequence,
	transparency: NumberSequence
): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = color
	beam.Transparency = transparency
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Width0 = 0.1
	beam.Width1 = 0.1
	beam.Parent = parent
	return beam
end

local function newPoint(parent: Instance): Attachment
	local point = Instance.new("Attachment")
	point.Parent = parent
	return point
end

-- An invisible anchored part things hang on.
local function holderAt(name: string, cframe: CFrame): Part
	local holder = ghost(name, Vector3.new(0.1, 0.1, 0.1), RIFT_GREEN, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CFrame = cframe
	return holder
end

type Ring = { points: { Attachment }, beams: { Beam }, offset: number }

local function newRing(parent: Instance, color: ColorSequence): Ring
	local ring: Ring = { points = {}, beams = {}, offset = 0 }
	for _ = 1, 4 do
		table.insert(ring.points, newPoint(parent))
	end
	for i = 1, 4 do
		local beam =
			newBeam(parent, ring.points[i], ring.points[i % 4 + 1], color, NumberSequence.new(0))
		beam.Segments = 10
		table.insert(ring.beams, beam)
	end
	return ring
end

-- Lays the ring out as an ellipse of half-axes a, b at height z.
local function placeRing(ring: Ring, a: number, b: number, z: number)
	local points = ring.points
	points[1].CFrame = CFrame.fromMatrix(Vector3.new(a, 0, z), Vector3.yAxis, Vector3.zAxis)
	points[2].CFrame = CFrame.fromMatrix(Vector3.new(0, b, z), -Vector3.xAxis, Vector3.zAxis)
	points[3].CFrame = CFrame.fromMatrix(Vector3.new(-a, 0, z), -Vector3.yAxis, Vector3.zAxis)
	points[4].CFrame = CFrame.fromMatrix(Vector3.new(0, -b, z), Vector3.xAxis, Vector3.zAxis)
	for i, beam in ring.beams do
		local along = if i % 2 == 1 then b else a
		local across = if i % 2 == 1 then a else b
		beam.CurveSize0 = KAPPA * along
		beam.CurveSize1 = KAPPA * across
	end
end

------------------------------------------------------------------------------
-- One-off pieces (flashes, rings, smoke): each cleans itself up
------------------------------------------------------------------------------

-- A ring of light racing out (or in) across the plane of `cframe`.
local function shockRing(
	cframe: CFrame,
	a: number,
	b: number,
	from: number,
	to: number,
	seconds: number,
	width: number,
	color: Color3
)
	local holder = holderAt("RiftShock", cframe)
	local ring = newRing(holder, ColorSequence.new(HOT, color))
	placeRing(ring, a * from, b * from, 0)
	holder.Parent = workspace
	Debris:AddItem(holder, seconds + 0.5)
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - start) / seconds, 0, 1)
		if holder.Parent == nil or u >= 1 then
			connection:Disconnect()
			holder:Destroy()
			return
		end
		local ease = 1 - (1 - u) ^ 3
		local f = from + (to - from) * ease
		placeRing(ring, a * f, b * f, 0)
		local w = width * (1 - u) + 0.02
		local look = NumberSequence.new(u ^ 1.4)
		for _, beam in ring.beams do
			beam.Width0 = w
			beam.Width1 = w
			beam.Transparency = look
		end
	end)
end

-- A shimmering ForceField skin swelling (or shrinking) and fading: the air
-- bending round the portal.
local function warp(cframe: CFrame, a: number, b: number, from: number, to: number, seconds: number)
	local skin = disc("RiftWarp", RIFT_GLOW, 0)
	skin.Material = Enum.Material.ForceField
	skin.CFrame = cframe
	skin.Size = Vector3.new(a * 2 * from, b * 2 * from, 0.05)
	skin.Parent = workspace
	fade(skin, seconds, { Size = Vector3.new(a * 2 * to, b * 2 * to, 0.05) })
end

-- A white-hot ball popping and fading (an impact frame).
local function pop(position: Vector3, size: number, seconds: number)
	local ball =
		ghost("RiftPop", Vector3.new(0.2, 0.2, 0.2), HOT, Enum.Material.Neon, Enum.PartType.Ball)
	ball.Anchored = true
	ball.CFrame = CFrame.new(position)
	ball.Parent = workspace
	TweenService:Create(
		ball,
		TweenInfo.new(seconds * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * size }
	):Play()
	TweenService:Create(
		ball,
		TweenInfo.new(
			seconds * 0.75,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In,
			0,
			false,
			seconds * 0.25
		),
		{ Transparency = 1 }
	):Play()
	Debris:AddItem(ball, seconds + 0.1)
end

-- What hangs in the air after: slow green motes and a little smoke.
local function residue(position: Vector3, k: number)
	local point = attachmentAt(position)
	local motes = emitter(point, {
		Name = "Motes",
		Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12 * k),
			NumberSequenceKeypoint.new(0.5, 0.08 * k),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(0.3, 1.4 * k),
		Drag = 1.5,
		Acceleration = Vector3.new(0, 0.9, 0),
		RotSpeed = NumberRange.new(-120, 120),
	})
	sparkTexture(motes)
	motes:Emit(math.floor(7 * k + random:NextInteger(0, 4)))
	local fumes = emitter(point, {
		Name = "Fumes",
		Color = ColorSequence.new(RIFT_DEEP, FUME),
		LightEmission = 0.2,
		LightInfluence = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5 * k),
			NumberSequenceKeypoint.new(1, 1.9 * k),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.62),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.9, 1.7),
		Speed = NumberRange.new(0.4, 1.6),
		Drag = 1,
		Acceleration = Vector3.new(0, 1.3, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
	fumes:Emit(random:NextInteger(3, 5))
	Debris:AddItem(point, 1.9)
end

-- A burst of green light and sparks (a shot arriving, a portal snapping):
-- a white-hot pop, a green glow swelling, sparks thrown out, a few motes
-- that hang, a hard green light dying out.
local function flash(position: Vector3, size: number)
	local point = attachmentAt(position)
	pop(position, 1.2 * size, 0.2)
	local glow = ghost(
		"RiftGlow",
		Vector3.one * 0.6 * size,
		RIFT_GREEN,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	glow.Anchored = true
	glow.Transparency = 0.55
	glow.CFrame = CFrame.new(position)
	glow.Parent = workspace
	fade(glow, 0.3, { Size = Vector3.one * 2 * size })
	local sparks = emitter(point, {
		Name = "Sparks",
		Color = ColorSequence.new(HOT, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.3 * size, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.2, 0.5),
		Speed = NumberRange.new(6 * size, 15 * size),
		Drag = 4,
		Acceleration = Vector3.new(0, -14, 0),
	})
	sparkTexture(sparks)
	sparks:Emit(math.floor(30 * size * random:NextNumber(0.8, 1.2)))
	local motes = emitter(point, {
		Name = "Motes",
		Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.12 * size, 0),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(1, 3 * size),
		Drag = 3,
		Acceleration = Vector3.new(0, 1, 0),
	})
	sparkTexture(motes)
	motes:Emit(math.floor(8 * size) + random:NextInteger(0, 3))
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 6
	light.Range = math.min(12 * size, 50)
	light.Parent = point
	TweenService:Create(
		light,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	):Play()
	Debris:AddItem(point, 1.4)
end

-- The portal snapping shut: a white pop, a shock ring, the air bending,
-- sparks, a shake, and what hangs after.
local function snap(cframe: CFrame, a: number, b: number, r: number, k: number)
	local position = cframe.Position
	pop(position, r * 0.9, 0.22)
	shockRing(cframe, a, b, 0.2, 1.55, 0.32, 0.2 * r, RIFT_GLOW)
	warp(cframe, a, b, 0.4, 1.4, 0.3)
	flash(position, math.clamp(r / 2.4, 0.6, 1.5))
	shakeNear(position, 1.6 * k, 0.25)
	residue(position, k)
end

------------------------------------------------------------------------------
-- Portals
------------------------------------------------------------------------------

export type Portal = { parts: { BasePart }, sizes: { Vector3 }, folder: Folder, light: PointLight }

type Arm = { a0: Attachment, a1: Attachment, beam: Beam, offset: number, twist: number }
type Arc = { points: { Attachment }, beams: { Beam }, crackle: ParticleEmitter }
type RimPoint = {
	point: Attachment,
	motes: ParticleEmitter,
	tongues: ParticleEmitter,
	haze: ParticleEmitter,
}

type Live = {
	folder: Folder,
	cframe: CFrame,
	rim: BasePart,
	halo: BasePart,
	fullX: number,
	a: number,
	b: number,
	r: number,
	k: number,
	seed: number,
	spin: number,
	flicker: PointLight,
	armsA: { Arm },
	armsB: { Arm },
	rings: { Ring },
	arcs: { Arc },
	rimPoints: { RimPoint },
	beams: { Beam },
	burst: Attachment,
	burstSparks: ParticleEmitter,
	phaseA: number,
	phaseB: number,
	rimPhase: number,
	nextArc: number,
	spike: number,
	opened: boolean,
	closing: boolean,
	shown: boolean,
	peak: number,
	lastS: number,
}

local live: { Live } = {}
local stepConnection: RBXScriptConnection? = nil

-- The layers, outside in (`thick` makes the inner ones bulge out on both
-- faces, so the look is the same from the front and the back).
local LAYERS = {
	{
		name = "Halo",
		color = RIFT_GLOW,
		transparency = 0.86,
		scale = 1.3,
		thick = 0.04,
		field = false,
	},
	{ name = "Rim", color = RIFT_GREEN, transparency = 0, scale = 1, thick = 0.06, field = false },
	{ name = "Lip", color = HOT, transparency = 0, scale = 0.93, thick = 0.085, field = false },
	{ name = "Swirl", color = SWIRL, transparency = 0, scale = 0.86, thick = 0.14, field = false },
	{ name = "Depth", color = DEPTH, transparency = 0, scale = 0.78, thick = 0.2, field = false },
	{ name = "Void", color = VOID, transparency = 0, scale = 0.64, thick = 0.28, field = false },
	{
		name = "Shimmer",
		color = RIFT_GREEN,
		transparency = 0,
		scale = 0.97,
		thick = 0.36,
		field = true,
	},
}
local HALO, RIM = 1, 2

-- A spiral arm from the rim down into the void; `lead` = which way round
-- its inner end is ahead.
local function placeArm(
	arm: Arm,
	phase: number,
	a: number,
	b: number,
	r: number,
	lead: number,
	side: number
)
	local angle = phase + arm.offset
	local outer = ellipse(a * 0.95, b * 0.95, angle)
	local inward = if outer.Magnitude > 1e-4 then -outer.Unit else -Vector3.xAxis
	local axis0 = (tangentAt(a, b, angle) * lead * 0.75 + inward * 0.66).Unit
	local innerAngle = angle + arm.twist * lead
	local inner = ellipse(a * 0.12, b * 0.12, innerAngle)
	local inwardIn = if inner.Magnitude > 1e-4 then -inner.Unit else -Vector3.xAxis
	local axis1 = (tangentAt(a, b, innerAngle) * lead + inwardIn * 0.35).Unit
	arm.a0.CFrame =
		CFrame.fromMatrix(outer + Vector3.new(0, 0, side * lift(0.95)), axis0, Vector3.zAxis)
	arm.a1.CFrame =
		CFrame.fromMatrix(inner + Vector3.new(0, 0, side * lift(0.12)), axis1, Vector3.zAxis)
	arm.beam.CurveSize0 = r * 0.7
	arm.beam.CurveSize1 = r * 0.25
end

-- New random arcs along the rim (a crackle).
local function rerollArcs(st: Live, a: number, b: number, r: number, side: number, now: number)
	local closing = st.closing
	for _, arc in st.arcs do
		local on = random:NextNumber() < (if closing then 0.95 else 0.7)
		for _, beam in arc.beams do
			beam.Enabled = on
		end
		if on then
			local angle = random:NextNumber(0, TAU)
			local span = random:NextNumber(0.25, 0.75)
			local middle = angle + span * random:NextNumber(0.3, 0.7)
			local reach = if closing
				then random:NextNumber(1.05, 1.32)
				else random:NextNumber(1.02, 1.2)
			local spots = {
				ellipse(a, b, angle) * random:NextNumber(0.95, 1.03),
				ellipse(a, b, middle) * reach,
				ellipse(a, b, angle + span) * random:NextNumber(0.95, 1.03),
			}
			for i, point in arc.points do
				local z = side * (0.04 + random:NextNumber(0, 0.1))
				point.CFrame = CFrame.fromMatrix(
					spots[i] + Vector3.new(0, 0, z),
					planar(random:NextNumber(0, TAU)),
					Vector3.zAxis
				)
			end
			local width = random:NextNumber(0.03, 0.08) * st.k * (if closing then 1.8 else 1)
			local look = NumberSequence.new(random:NextNumber(0, 0.35))
			for i, beam in arc.beams do
				beam.CurveSize0 = random:NextNumber(-1, 1) * r * span * 0.35
				beam.CurveSize1 = random:NextNumber(-1, 1) * r * span * 0.35
				beam.Width0 = if i == 1 then width else width * 0.6
				beam.Width1 = if i == 1 then width * 0.6 else width * 0.15
				beam.Transparency = look
			end
			if random:NextNumber() < 0.45 then
				arc.crackle:Emit(2)
			end
		end
	end
	st.nextArc = now
		+ (if closing then random:NextNumber(0.015, 0.035) else random:NextNumber(0.03, 0.075))
end

-- Closing (ours or the finisher's): everything near the rim is sucked in.
local function suck(st: Live)
	local r = st.r * math.max(st.rim.Size.X / st.fullX, 0.3)
	local speed = NumberRange.new(r * 3, r * 3.6)
	local life = NumberRange.new(0.22, 0.28)
	for _, rim in st.rimPoints do
		rim.motes.Speed = speed
		rim.motes.Lifetime = life
		rim.motes:Emit(math.ceil(4 * st.k))
	end
	st.spike += 2.5
	st.nextArc = 0
end

local function setShown(st: Live, shown: boolean)
	st.shown = shown
	for _, beam in st.beams do
		beam.Enabled = shown
	end
	for _, rim in st.rimPoints do
		rim.motes.Enabled = shown
		rim.tongues.Enabled = shown
		rim.haze.Enabled = shown
	end
end

local function update(st: Live, dt: number, now: number, eye: Vector3)
	local s = math.max(st.rim.Size.X / st.fullX, 0)
	if st.opened then
		if s > st.peak then
			st.peak = s
		elseif not st.closing and s < st.peak * 0.85 then
			-- (RiftFx closing the finisher's ring)
			st.closing = true
			suck(st)
		end
	end
	local visible = s > 0.06
	if visible ~= st.shown then
		setShown(st, visible)
	end
	if not visible then
		st.flicker.Brightness = 0
		return
	end
	local a, b, r = st.a * s, st.b * s, st.r * s
	local side = if st.cframe:PointToObjectSpace(eye).Z >= 0 then 1 else -1
	-- Light: a flicker on the steady one, and the spikes (opening, closing).
	st.spike *= math.exp(-dt * 8)
	local noise = math.noise(now * 9, st.seed)
	st.flicker.Brightness = s * (1.6 + noise * 1.8) + st.spike
	st.flicker.Range = math.min(st.r * 3.4 * math.max(s, 0.3) + st.spike, 60)
	st.halo.Transparency = 0.84 + 0.07 * math.sin(now * 6 + st.seed)
	-- Spiral arms, both layers drawing in (each turns against the way its
	-- inner end leads), against each other.
	local hurry = if st.closing then 2.5 else 1
	st.phaseA += dt * 2.4 * st.spin * hurry
	st.phaseB -= dt * 1.5 * st.spin * hurry
	for _, arm in st.armsA do
		placeArm(arm, st.phaseA, a, b, r, -st.spin, side)
	end
	for _, arm in st.armsB do
		placeArm(arm, st.phaseB, a, b, r, st.spin, side)
	end
	if math.abs(s - st.lastS) > 0.01 then
		st.lastS = s
		for _, arm in st.armsA do
			arm.beam.Width0 = 0.16 * r
			arm.beam.Width1 = 0.04 * r
		end
		for _, arm in st.armsB do
			arm.beam.Width0 = 0.5 * r
			arm.beam.Width1 = 0.14 * r
		end
		-- (the motes reach the centre whatever the size; the close sets
		-- its own, faster)
		if not st.closing then
			local speed = NumberRange.new(r * 1.4, r * 1.8)
			for _, rim in st.rimPoints do
				rim.motes.Speed = speed
			end
		end
	end
	-- Rings sinking into the void.
	for _, ring in st.rings do
		local t = (now * 0.8 + ring.offset) % 1
		local f = 0.72 * (1 - t) ^ 1.6 + 0.04
		placeRing(ring, a * f, b * f, side * lift(f))
		local alpha = math.min(t * 6, 1) * (1 - t)
		local look = NumberSequence.new(1 - 0.65 * alpha)
		local w = 0.07 * r * (1 - 0.7 * t)
		for _, beam in ring.beams do
			beam.Transparency = look
			beam.Width0 = w
			beam.Width1 = w
		end
	end
	-- The rim: points turning slowly, throwing motes in, sparks and haze out.
	st.rimPhase += dt * 0.7 * st.spin
	local count = #st.rimPoints
	local tilt = 0.35
	for i, rim in st.rimPoints do
		local angle = st.rimPhase + (i - 1) / count * TAU
		local along = tangentAt(a, b, angle) * st.spin
		local out = normalAt(a, b, angle)
		local x = along * math.cos(tilt) + out * math.sin(tilt)
		local y = out * math.cos(tilt) - along * math.sin(tilt)
		rim.point.CFrame = CFrame.fromMatrix(
			-- (above the layers' bulge, so the motes stay in sight all the
			-- way in)
			ellipse(a * 0.98, b * 0.98, angle) + Vector3.new(0, 0, side * (lift(0.98) + 0.15)),
			x,
			y
		)
	end
	if now >= st.nextArc then
		rerollArcs(st, a, b, r, side, now)
	end
end

local function step(dt: number)
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for index = #live, 1, -1 do
		local st = live[index]
		if st.folder.Parent == nil then
			table.remove(live, index)
		elseif (st.cframe.Position - eye).Magnitude < FAR then
			update(st, dt, now, eye)
		end
	end
	if #live == 0 and stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
end

-- The animated dressing of a portal (arms, rings, arcs, rim, lights).
local function dress(
	folder: Folder,
	cframe: CFrame,
	a: number,
	b: number,
	parts: { BasePart },
	sizes: { Vector3 }
): Live
	local r = math.max(a, b)
	local k = math.clamp(r / 2.2, 0.5, 2)
	local hub = holderAt("Hub", cframe)
	hub.Parent = folder
	local flicker = Instance.new("PointLight")
	flicker.Name = "Flicker"
	flicker.Color = RIFT_GREEN
	flicker.Brightness = 0
	flicker.Range = r * 3
	flicker.Parent = hub
	local spin = if random:NextNumber() < 0.5 then 1 else -1
	local st: Live = {
		folder = folder,
		cframe = cframe,
		rim = parts[RIM],
		halo = parts[HALO],
		fullX = sizes[RIM].X,
		a = a,
		b = b,
		r = r,
		k = k,
		seed = random:NextNumber(0, 100),
		spin = spin,
		flicker = flicker,
		armsA = {},
		armsB = {},
		rings = {},
		arcs = {},
		rimPoints = {},
		beams = {},
		burst = newPoint(hub),
		burstSparks = nil :: any,
		phaseA = random:NextNumber(0, TAU),
		phaseB = random:NextNumber(0, TAU),
		rimPhase = random:NextNumber(0, TAU),
		nextArc = 0,
		spike = 0,
		opened = false,
		closing = false,
		shown = true,
		peak = 0,
		lastS = -1,
	}
	-- Arms: three bright thin ones (sparkles flowing in), three wide misty
	-- ones (smoke flowing in) turning the other way.
	local armLook = {
		{
			list = st.armsA,
			color = ColorSequence.new(HOT, RIFT_GREEN),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(0.6, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
			texture = SPARK_TEXTURE,
			speed = 2.5,
			twist = 2.3,
			emission = 1,
		},
		{
			list = st.armsB,
			color = ColorSequence.new(RIFT_GREEN, RIFT_DEEP),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
			texture = SMOKE_TEXTURE,
			speed = 1.3,
			twist = 2,
			emission = 0.8,
		},
	}
	for _, look in armLook do
		for i = 1, 3 do
			local a0, a1 = newPoint(hub), newPoint(hub)
			local beam = newBeam(hub, a0, a1, look.color, look.transparency)
			beam.Texture = look.texture
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = 1.5 * k
			beam.TextureSpeed = look.speed
			beam.LightEmission = look.emission
			beam.Segments = 14
			table.insert(st.beams, beam)
			table.insert(look.list, {
				a0 = a0,
				a1 = a1,
				beam = beam,
				offset = (i - 1) / 3 * TAU + random:NextNumber(-0.25, 0.25),
				twist = look.twist + random:NextNumber(-0.3, 0.3),
			})
		end
	end
	-- Rings sinking into the void (depth).
	for i = 1, 2 do
		local ring = newRing(hub, ColorSequence.new(RIFT_GREEN, SWIRL))
		ring.offset = (i - 1) * 0.5
		for _, beam in ring.beams do
			table.insert(st.beams, beam)
		end
		table.insert(st.rings, ring)
	end
	-- Arcs crackling off the rim: two short kinked bits each (few segments,
	-- so they bend at hard angles).
	for _ = 1, if r < 2 then 3 else 4 do
		local arc: Arc = { points = {}, beams = {}, crackle = nil :: any }
		for _ = 1, 3 do
			table.insert(arc.points, newPoint(hub))
		end
		for i = 1, 2 do
			local beam = newBeam(
				hub,
				arc.points[i],
				arc.points[i + 1],
				ColorSequence.new(HOT, RIFT_GLOW),
				NumberSequence.new(0)
			)
			beam.Segments = 5
			table.insert(arc.beams, beam)
			table.insert(st.beams, beam)
		end
		local crackle = emitter(arc.points[2], {
			Name = "Crackle",
			Color = ColorSequence.new(HOT, RIFT_GREEN),
			LightEmission = 1,
			Size = NumberSequence.new(0.1 * k, 0),
			Transparency = NumberSequence.new(0, 1),
			Lifetime = NumberRange.new(0.1, 0.25),
			Speed = NumberRange.new(2, 6),
			Drag = 2,
			Acceleration = Vector3.new(0, -20, 0),
		})
		sparkTexture(crackle)
		arc.crackle = crackle
		table.insert(st.arcs, arc)
	end
	-- The rim's points: motes drawn in, sparks and haze torn off.
	for _ = 1, 5 do
		local point = newPoint(hub)
		local motes = emitter(point, {
			Name = "Motes",
			Color = ColorSequence.new(HOT, RIFT_GREEN),
			LightEmission = 1,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.07 * k),
				NumberSequenceKeypoint.new(0.3, 0.16 * k),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.1),
				NumberSequenceKeypoint.new(0.75, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
			-- (speed x lifetime <= 0.95 r: they die at the centre)
			Lifetime = NumberRange.new(0.4, 0.52),
			Speed = NumberRange.new(r * 1.4, r * 1.8),
			SpreadAngle = Vector2.new(10, 10),
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = math.clamp(10 * k, 5, 18),
		})
		sparkTexture(motes)
		local tongues = emitter(point, {
			Name = "Tongues",
			Color = ColorSequence.new(HOT, RIFT_GREEN),
			LightEmission = 1,
			Size = NumberSequence.new(0.13 * k, 0),
			Transparency = NumberSequence.new(0, 1),
			Lifetime = NumberRange.new(0.12, 0.3),
			Speed = NumberRange.new(1.5, 3.5),
			SpreadAngle = Vector2.new(35, 35),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -14, 0),
			Rate = 9,
		})
		sparkTexture(tongues)
		local haze = emitter(point, {
			Name = "Haze",
			Color = ColorSequence.new(RIFT_GREEN, RIFT_DEEP),
			LightEmission = 0.6,
			Size = NumberSequence.new(0.3 * k, 0.85 * k),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0.74),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.35, 0.6),
			Speed = NumberRange.new(0.4, 1.2),
			SpreadAngle = Vector2.new(40, 40),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			Rate = 5,
		})
		table.insert(st.rimPoints, { point = point, motes = motes, tongues = tongues, haze = haze })
	end
	-- (the opening's ring of sparks, thrown out flat across the plane)
	local burstSparks = emitter(st.burst, {
		Name = "Burst",
		Color = ColorSequence.new(HOT, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.22 * k, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.2, 0.45),
		Speed = NumberRange.new(10 * k, 20 * k),
		Drag = 5,
		SpreadAngle = Vector2.new(5, 5),
		EmissionDirection = Enum.NormalId.Top,
	})
	sparkTexture(burstSparks)
	st.burstSparks = burstSparks
	return st
end

-- The moment it bursts open: a ripple, the air bending, a flat ring of
-- sparks, a light spike, a little shake.
local function burstOpen(st: Live)
	local cframe = st.cframe
	shockRing(cframe, st.a, st.b, 1, 1.9, 0.45, 0.28 * st.r, RIFT_GREEN)
	warp(cframe, st.a, st.b, 1, 1.7, 0.45)
	-- (one short-lived point per direction, placed before it is parented:
	-- moving one point between Emit calls in the same frame may not take)
	local hub = st.burst.Parent
	if hub then
		local steps = 10
		local start = random:NextNumber(0, TAU)
		for i = 1, steps do
			local angle = start + i / steps * TAU + random:NextNumber(-0.1, 0.1)
			local point = Instance.new("Attachment")
			-- (Y along the plane, the way the sparks go: Top)
			point.CFrame = CFrame.Angles(0, 0, angle)
			point.Parent = hub
			local sparks = st.burstSparks:Clone()
			sparks.SpreadAngle = Vector2.new(14, 14)
			sparks.Parent = point
			sparks:Emit(2)
			Debris:AddItem(point, 0.6)
		end
	end
	st.spike += 5
	shakeNear(cframe.Position, 1.1 * st.k, 0.25)
end

-- A portal at `cframe` (its face = LookVector), `width` x `height` studs.
-- Opens over `openTime`, stays `stay` seconds, then closes over `closeTime`
-- (`stay` < 0: stays until someone destroys `folder`).
local function portal(
	cframe: CFrame,
	width: number,
	height: number,
	openTime: number,
	stay: number,
	closeTime: number
): Portal
	local a, b = math.max(width, 0.2) / 2, math.max(height, 0.2) / 2
	local r = math.max(a, b)
	local k = math.clamp(r / 2.2, 0.5, 2)
	local folder = Instance.new("Folder")
	folder.Name = "RiftPortal"
	local parts: { BasePart } = {}
	local sizes: { Vector3 } = {}
	for _, layer in LAYERS do
		local part = disc(layer.name, layer.color, layer.transparency)
		if layer.field then
			part.Material = Enum.Material.ForceField
		end
		part.CFrame = cframe
		part.Size = TINY
		part.Parent = folder
		table.insert(parts, part)
		table.insert(sizes, Vector3.new(width * layer.scale, height * layer.scale, layer.thick))
	end
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 0
	light.Range = math.min(r * 5, 60)
	light.Shadows = #live < 8
	light.Parent = parts[RIM]
	-- The tear: a white-hot slit, the portal springs open from it.
	local tall = height >= width * 1.2
	local slit = disc("Tear", HOT, 0)
	slit.CFrame = cframe
		* CFrame.Angles(
			0,
			0,
			if tall then random:NextNumber(-0.15, 0.15) else random:NextNumber(0, math.pi)
		)
	slit.Size = TINY
	slit.Parent = folder
	local st: Live? = nil
	if #live < MAX_RICH then
		st = dress(folder, cframe, a, b, parts, sizes)
	end
	folder.Parent = workspace
	local reach = (if tall then height else math.max(width, height)) * 0.9
	local rip = math.min(0.06, openTime * 0.3)
	TweenService:Create(
		slit,
		TweenInfo.new(rip, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.16 * k, reach, 0.05) }
	):Play()
	TweenService:Create(
		slit,
		TweenInfo.new(openTime * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, rip),
		{ Transparency = 1 }
	):Play()
	Debris:AddItem(slit, rip + openTime + 0.1)
	-- The layers spring open, the outer ones first (Back: past and back).
	for index, part in parts do
		local lag = math.min(0.012 * (index - 1), openTime * 0.3)
		local info =
			TweenInfo.new(openTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, lag)
		TweenService:Create(part, info, { Size = sizes[index] }):Play()
	end
	TweenService:Create(light, TweenInfo.new(openTime), { Brightness = 2.2 }):Play()
	if st then
		local dressed = st
		dressed.spike = 3
		table.insert(live, dressed)
		if stepConnection == nil then
			stepConnection = RunService.RenderStepped:Connect(step)
		end
		task.delay(openTime * 0.5, function()
			if folder.Parent then
				burstOpen(dressed)
			end
		end)
		task.delay(openTime + 0.12, function()
			dressed.opened = true
		end)
	end
	local made: Portal = { parts = parts, sizes = sizes, folder = folder, light = light }
	if stay >= 0 then
		task.delay(openTime + stay, function()
			if folder.Parent == nil then
				return
			end
			if st then
				st.closing = true
				suck(st)
			end
			-- Back In: it swells a hair, then collapses.
			local close = TweenInfo.new(closeTime, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			for _, part in parts do
				TweenService:Create(part, close, { Size = TINY }):Play()
			end
			TweenService:Create(light, TweenInfo.new(closeTime), { Brightness = 0 }):Play()
			task.delay(closeTime * 0.8, function()
				if not folder.Parent then
					return
				end
				snap(cframe, a, b, r, k)
			end)
			Debris:AddItem(folder, closeTime + 0.05)
		end)
	end
	return made
end

-- A standing portal (a door): 3.6 x 6 studs.
local function door(cframe: CFrame, stay: number): Portal
	return portal(cframe, 3.6, 6, 0.22, stay, 0.25)
end

------------------------------------------------------------------------------
-- The portal gun's bolt
------------------------------------------------------------------------------

-- The muzzle: a small white pop, a light, a cone of sparks forward.
local function muzzle(from: Vector3, direction: Vector3)
	pop(from, 0.7, 0.12)
	local point = attachmentAt(from)
	point.WorldCFrame = CFrame.lookAt(from, from + direction)
	local sparks = emitter(point, {
		Name = "Muzzle",
		Color = ColorSequence.new(HOT, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.14, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.08, 0.2),
		Speed = NumberRange.new(8, 18),
		Drag = 6,
		SpreadAngle = Vector2.new(22, 22),
		EmissionDirection = Enum.NormalId.Front,
	})
	sparkTexture(sparks)
	sparks:Emit(random:NextInteger(8, 12))
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 4
	light.Range = 8
	light.Parent = point
	TweenService:Create(light, TweenInfo.new(0.15), { Brightness = 0 }):Play()
	Debris:AddItem(point, 0.4)
end

-- Where it lands: the flash, a ripple across the way it came, green
-- droplets thrown back and falling, a glow that lingers.
local function splash(at: Vector3, direction: Vector3)
	flash(at, 1)
	local face = CFrame.lookAt(at, at - direction)
	shockRing(face, 1, 1, 0.3, 2.2, 0.3, 0.3, RIFT_GREEN)
	local point = attachmentAt(at)
	point.WorldCFrame = face
	local drops = emitter(point, {
		Name = "Drops",
		Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.14, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(8, 18),
		Drag = 1.5,
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -40, 0),
		EmissionDirection = Enum.NormalId.Front,
	})
	sparkTexture(drops)
	drops:Emit(random:NextInteger(16, 24))
	local glow = Instance.new("PointLight")
	glow.Color = RIFT_GREEN
	glow.Brightness = 1.2
	glow.Range = 7
	glow.Parent = point
	TweenService:Create(glow, TweenInfo.new(0.9), { Brightness = 0 }):Play()
	Debris:AddItem(point, 1)
	residue(at, 0.6)
	shakeNear(at, 0.6, 0.15)
end

-- A green bolt flying from `from` to `to` (the portal gun's shot): a
-- white-hot core in a green glow, a ribbon trail, sparks shed behind,
-- little arcs crackling round it.
local function bolt(from: Vector3, to: Vector3)
	local delta = to - from
	local distance = delta.Magnitude
	if distance < 0.05 then
		flash(to, 1)
		return
	end
	local direction = delta.Unit
	local seconds = math.clamp(distance / 160, 0.06, 0.3)
	muzzle(from, direction)
	local folder = Instance.new("Folder")
	folder.Name = "PortalShot"
	local glow = ghost(
		"PortalShot",
		Vector3.new(0.8, 0.8, 0.8),
		RIFT_GREEN,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	glow.Anchored = true
	glow.Transparency = 0.45
	glow.CFrame = CFrame.lookAt(from, to)
	glow.Parent = folder
	local core =
		ghost("Core", Vector3.new(0.34, 0.34, 0.34), HOT, Enum.Material.Neon, Enum.PartType.Ball)
	core.Anchored = true
	core.CFrame = glow.CFrame
	core.Parent = folder
	local top, bottom = newPoint(glow), newPoint(glow)
	top.Position = Vector3.new(0, 0.2, 0)
	bottom.Position = Vector3.new(0, -0.2, 0)
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.FaceCamera = true
	trail.Lifetime = 0.16
	trail.MinLength = 0
	trail.Color = ColorSequence.new(HOT, RIFT_GREEN)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0.15)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Parent = glow
	local wideTop, wideBottom = newPoint(glow), newPoint(glow)
	wideTop.Position = Vector3.new(0, 0.55, 0)
	wideBottom.Position = Vector3.new(0, -0.55, 0)
	local haze = Instance.new("Trail")
	haze.Attachment0 = wideTop
	haze.Attachment1 = wideBottom
	haze.FaceCamera = true
	haze.Lifetime = 0.1
	haze.MinLength = 0
	haze.Color = ColorSequence.new(RIFT_GREEN)
	haze.Transparency = NumberSequence.new(0.6, 1)
	haze.WidthScale = NumberSequence.new(1, 0.3)
	haze.LightEmission = 1
	haze.LightInfluence = 0
	haze.Parent = glow
	local shed = emitter(glow, {
		Name = "Shed",
		Color = ColorSequence.new(HOT, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.18, 0),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(0.12, 0.3),
		Speed = NumberRange.new(1, 4),
		Drag = 3,
		Acceleration = Vector3.new(0, -10, 0),
		Rate = 180,
	})
	sparkTexture(shed)
	-- (little arcs: from its nose to a random point round it, behind)
	local nose = newPoint(glow)
	nose.Position = Vector3.new(0, 0, -0.15)
	local tails: { Attachment } = {}
	local arcs: { Beam } = {}
	for _ = 1, 2 do
		local tail = newPoint(glow)
		local beam = newBeam(
			glow,
			nose,
			tail,
			ColorSequence.new(HOT, RIFT_GLOW),
			NumberSequence.new(0.1, 0.8)
		)
		beam.Segments = 5
		beam.Width0 = 0.07
		beam.Width1 = 0.02
		table.insert(tails, tail)
		table.insert(arcs, beam)
	end
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 4
	light.Range = 10
	light.Parent = glow
	folder.Parent = workspace
	Debris:AddItem(folder, seconds + 1)
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if folder.Parent == nil then
			connection:Disconnect()
			return
		end
		local t = math.clamp((os.clock() - start) / seconds, 0, 1)
		local at = CFrame.lookAt(from + delta * t, to + direction)
		glow.CFrame = at
		core.CFrame = at
		core.Size = Vector3.one * random:NextNumber(0.28, 0.4)
		light.Brightness = random:NextNumber(3, 5)
		for i, tail in tails do
			local angle = random:NextNumber(0, TAU)
			tail.Position = Vector3.new(
				math.cos(angle) * random:NextNumber(0.2, 0.45),
				math.sin(angle) * random:NextNumber(0.2, 0.45),
				random:NextNumber(0.5, 1.2)
			)
			tail.Axis = planar(random:NextNumber(0, TAU))
			arcs[i].CurveSize0 = random:NextNumber(-0.3, 0.3)
			arcs[i].CurveSize1 = random:NextNumber(-0.3, 0.3)
			arcs[i].Enabled = random:NextNumber() < 0.8
		end
		if t >= 1 then
			connection:Disconnect()
			shed.Enabled = false
			glow.Transparency = 1
			core.Transparency = 1
			light.Enabled = false
			for _, beam in arcs do
				beam.Enabled = false
			end
			Debris:AddItem(folder, 0.35)
			splash(to, direction)
		end
	end)
end

------------------------------------------------------------------------------
-- Going through: afterimages, motes, a green outline
------------------------------------------------------------------------------

local function usable(part: BasePart): boolean
	if
		part.Name == "HumanoidRootPart"
		or part.Transparency >= 0.9
		or part.Size.Magnitude < 0.15
	then
		return false
	end
	local name = part.Name
	return string.sub(name, 1, 8) ~= "RiftBurn" and name ~= "Afterimage"
end

-- A shimmering copy of one part (the shape only).
local function silhouette(source: BasePart): (BasePart?, SpecialMesh?)
	local copy: BasePart
	local fileMesh: SpecialMesh? = nil
	if source:IsA("MeshPart") then
		-- (Clone gives nothing back for a part that isn't Archivable)
		if not source.Archivable then
			return nil, nil
		end
		local made = source:Clone()
		made:ClearAllChildren()
		for _, tag in made:GetTags() do
			made:RemoveTag(tag)
		end
		for name in made:GetAttributes() do
			made:SetAttribute(name, nil)
		end
		pcall(function()
			made.TextureID = ""
		end)
		copy = made
	else
		local part = Instance.new("Part")
		if source:IsA("Part") then
			part.Shape = source.Shape
		end
		local mesh = source:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			if mesh.Archivable then
				local shape = mesh:Clone()
				shape.TextureId = ""
				shape.Parent = part
				-- (a file mesh draws at its Scale, not the part's Size)
				if shape.MeshType == Enum.MeshType.FileMesh then
					fileMesh = shape
				end
			end
		end
		copy = part
	end
	copy.Name = "Afterimage"
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.CastShadow = false
	copy.Massless = true
	copy.Material = Enum.Material.ForceField
	copy.Color = RIFT_GLOW
	copy.Transparency = 0
	copy.Size = source.Size
	copy.CFrame = source.CFrame
	return copy, fileMesh
end

-- A ghost of `model` as it stands now, in shimmering green with a green
-- outline, fading over `seconds`: pulled into `toward` (going in), or
-- coming from `from` to where it is (stepping out).
local function afterimage(model: Model, seconds: number, toward: Vector3?, from: Vector3?)
	local sources: { BasePart } = {}
	for _, child in model:GetChildren() do
		if #sources >= MAX_AFTERIMAGE_PARTS then
			break
		end
		if child:IsA("BasePart") and usable(child) then
			table.insert(sources, child)
		end
	end
	for _, item in model:GetDescendants() do
		if #sources >= MAX_AFTERIMAGE_PARTS then
			break
		end
		if item:IsA("BasePart") and item.Parent ~= model and usable(item) then
			table.insert(sources, item)
		end
	end
	if #sources == 0 then
		return
	end
	local holder = Instance.new("Model")
	holder.Name = "RiftAfterimage"
	local pivot = model:GetPivot().Position
	local shift = if from then (from - pivot) * 0.6 else Vector3.zero
	local info = TweenInfo.new(
		seconds,
		Enum.EasingStyle.Quad,
		if toward then Enum.EasingDirection.In else Enum.EasingDirection.Out
	)
	for _, source in sources do
		local copy, fileMesh = silhouette(source)
		if copy then
			local rest = source.CFrame
			copy.CFrame = rest + shift
			copy.Size = source.Size * 1.04
			copy.Parent = holder
			local goal: { [string]: any } = { Transparency = 1 }
			if toward then
				goal.CFrame = CFrame.new(rest.Position:Lerp(toward, 0.75)) * rest.Rotation
				goal.Size = source.Size * 0.4
				if fileMesh then
					TweenService:Create(fileMesh, info, { Scale = fileMesh.Scale * 0.4 }):Play()
				end
			elseif from then
				goal.CFrame = rest
			end
			TweenService:Create(copy, info, goal):Play()
		end
	end
	local outline = Instance.new("Highlight")
	outline.FillColor = RIFT_GREEN
	outline.FillTransparency = 0.7
	outline.OutlineColor = RIFT_GLOW
	outline.OutlineTransparency = 0.1
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = holder
	outline.Parent = holder
	holder.Parent = workspace
	TweenService:Create(
		outline,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1, OutlineTransparency = 1 }
	):Play()
	Debris:AddItem(holder, seconds + 0.1)
end

-- A green energy outline on `model`, fading (`rising`: brightening
-- instead, the portal swallowing it).
local function outlineOn(model: Model, seconds: number, rising: boolean)
	local glow = Instance.new("Highlight")
	glow.Name = "RiftOutline"
	glow.FillColor = RIFT_GLOW
	glow.OutlineColor = HOT
	glow.FillTransparency = if rising then 1 else 0.3
	glow.OutlineTransparency = if rising then 1 else 0
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = model
	glow.Parent = model
	TweenService:Create(
		glow,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		if rising
			then { FillTransparency = 0.25, OutlineTransparency = 0 }
			else { FillTransparency = 1, OutlineTransparency = 1 }
	):Play()
	Debris:AddItem(glow, seconds + 0.1)
end

-- Green motes bursting out of a body-sized box standing at `position`.
local function motesBurst(position: Vector3, count: number)
	local box = holderAt("RiftMotes", CFrame.new(position))
	box.Size = Vector3.new(2.2, 4.6, 1.4)
	local motes = emitter(box, {
		Name = "Motes",
		Color = ColorSequence.new(HOT, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.16),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.4, 0.9),
		Speed = NumberRange.new(1.5, 5),
		Drag = 2.5,
		Acceleration = Vector3.new(0, 2, 0),
	})
	sparkTexture(motes)
	motes.Shape = Enum.ParticleEmitterShape.Box
	box.Parent = workspace
	motes:Emit(count)
	Debris:AddItem(box, 1.2)
end

------------------------------------------------------------------------------
-- Clones
------------------------------------------------------------------------------

local function cloneIn(data: { [string]: any })
	local clone, at = data.clone, data.at
	if typeof(at) ~= "CFrame" then
		return
	end
	-- A door opening behind where it appears, it walks out of it.
	local behind = at * CFrame.new(0, 0, 0.6)
	door(behind * CFrame.Angles(0, math.pi, 0), 0.35)
	flash(at.Position, 0.8)
	motesBurst(at.Position, 28)
	SoundController.playAt("PortalOpen", at.Position)
	if typeof(clone) == "Instance" and clone:IsA("Model") then
		RiftGear.watch(clone)
		RiftBurn.watch(clone) -- (dressed even before CombatEffects sees it)
		-- (from 2.5 studs back: with the 0.6 pull it starts 1.5 back, in
		-- the door, and slides out)
		afterimage(clone, 0.35, nil, (at * CFrame.new(0, 0, 2.5)).Position)
		outlineOn(clone, 0.9, false)
	end
end

local function cloneOut(data: { [string]: any })
	local clone, at = data.clone, data.at
	if typeof(at) ~= "CFrame" then
		return
	end
	local front = at * CFrame.new(0, 0, -0.4)
	door(front, 0.2)
	flash(at.Position, 0.8)
	motesBurst(at.Position, 22)
	SoundController.playAt("PortalClose", at.Position)
	if typeof(clone) == "Instance" and clone:IsA("Model") then
		afterimage(clone, 0.4, front.Position, nil)
		outlineOn(clone, 0.3, true)
	end
end

------------------------------------------------------------------------------

local function portals(data: { [string]: any })
	local entry, exit, seconds = data.entry, data.exit, data.seconds
	if typeof(entry) ~= "CFrame" or typeof(exit) ~= "CFrame" or typeof(seconds) ~= "number" then
		return
	end
	door(entry, seconds)
	local by, land, travelIn = data.by, data.land, data.travelIn
	if
		typeof(by) == "Instance"
		and by:IsA("Model")
		and typeof(land) == "CFrame"
		and typeof(travelIn) == "number"
	then
		local character = by :: Model
		-- Our own character: we simulate it, so we move it ourselves, at
		-- the moment the server does (else it stays put until the server's
		-- move reaches us).
		local own = character == Players.LocalPlayer.Character
		task.delay(math.max(0, travelIn), function()
			if character.Parent == nil then
				return
			end
			-- Going in: a ghost of him pulled into the door; coming out:
			-- motes, a small flash, a green outline on him.
			-- (someone else: the server's move reaches us about when this
			-- timer runs out; if he already stands at the exit, a ghost
			-- would streak back across the map, so none)
			local pivot = character:GetPivot().Position
			if own or (pivot - entry.Position).Magnitude < 10 then
				afterimage(character, 0.42, entry.Position, nil)
			end
			if own then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					character:PivotTo(land)
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
			motesBurst(land.Position, 30)
			flash(land.Position, 0.6)
			-- (someone else: the server's move reaches us a little later)
			task.delay(if own then 0 else 0.12, function()
				if character.Parent then
					outlineOn(character, 0.6, false)
				end
			end)
		end)
	end
	-- On the floor: a flat round one; on a wall: a door.
	if math.abs(exit.LookVector.Y) > 0.7 then
		portal(exit, 4.4, 4.4, 0.22, seconds, 0.25)
	else
		door(exit, seconds)
	end
	-- (one sound for the whole teleport: "Teleport", from the move's start;
	-- the portals closing make none)
end

RiftPortal.portal = portal
RiftPortal.door = door
RiftPortal.flash = flash
RiftPortal.bolt = bolt
RiftPortal.portals = portals
RiftPortal.cloneIn = cloneIn
RiftPortal.cloneOut = cloneOut

return RiftPortal
