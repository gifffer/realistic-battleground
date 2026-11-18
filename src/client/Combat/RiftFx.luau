--!strict
-- RiftFx: what Dr. Rift LOOKS like, on this client (the server decided
-- everything; Server/Systems/Combat/Gadgets, Clones).
--
--   • His gear, on anyone with the "Rift" kit (his clones too): a
--     mechanical left arm ending in the gravity glove (plates, pistons,
--     cables, a glowing palm), and a lens for a right eye.
--   • In his hand during a move: the flask (until it leaves the hand), the
--     ray gun (orange core) or the portal gun (green core). The guns hum
--     while held: the ray gun's core pulses orange to white-hot, hot air
--     shimmers and rises off its muzzle; the portal gun's bulb swirls green,
--     motes drawn into it, a white-hot core.
--   • Remotes.RiftFx: a flask flying and bursting (acid: green splash, a
--     smoking puddle; explosive: a fireball, smoke, debris, a shockwave), a
--     ray, portals opening and closing, a shot that fizzles, the gravity
--     glove's shockwave, clones stepping in / out of portals.
--   • "Burning" attribute (acid / fire on someone): smoke, fizz or flames.
--   • The PortalCut finisher (CinematicController):
--       Lift: the glove's field closes round the victim (a shimmering shell,
--         a green outline, a light), arcs crackle from the glove to the
--         body, rubble and dust float up off the floor under their feet.
--       PortalOpen: the shot, the portal flat round the waist; the field
--         drains into it; a cocoon of energy round the hips, tongues of
--         green fire licking up and down the body, the ring humming and
--         wobbling (a white-hot line, a halo).
--       PortalClose: the ring contracts, a white-hot belt tightens round
--         the hips, sparks drawn in, the light builds, the shake builds.
--       Cut: a blinding flat flash, shockwaves racing out along the cut
--         plane, the air bending, sparks and mist sprayed sideways, a hard
--         shake; then the rubble drops, and green embers and thin smoke
--         rise off the cut (on the legs and under the torso) for a while.
--         (The wounds and the blood are WaistCut's: nothing here stays
--         over the cut long enough to hide them.)
--
--   RiftFx.watch(model)                    gear + burning visuals + aura
--   RiftFx.onAction(model, animation)      a move started (props)
--   RiftFx.stopAction(model)               refused / cut short: props away
--   RiftFx.onRemote(kind, data)            Remotes.RiftFx
--   RiftFx.onHit(victim, attacker, moveId) a Rift move landed
--   RiftFx.cinematic(kind, attacker, victim, anchor)   PortalCut events
--   RiftFx.cancelCinematic(attacker)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Finishers = require(ReplicatedStorage.Shared.Finishers)
local Kits = require(ReplicatedStorage.Shared.Kits)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local CharacterAnimationController =
	require(script.Parent.Parent.Controllers.CharacterAnimationController)

local RiftFx = {}

export type Shake = (strength: number, seconds: number) -> ()

local KIT = "Rift"

local P = require(script.Parent.RiftParts)
local STEEL = P.STEEL
local BRASS = P.BRASS
local CABLE = P.CABLE
local RIFT_GREEN = P.RIFT_GREEN
local RIFT_DEEP = P.RIFT_DEEP
local RIFT_GLOW = P.RIFT_GLOW
local SMOKE = P.SMOKE
local FIRE_HOT = P.FIRE_HOT
local RAY_CORE = P.RAY_CORE
local RAY_GLOW = P.RAY_GLOW
local ghost = P.ghost
local stick = P.stick
local disc = P.disc
local attachmentAt = P.attachmentAt
local emitter = P.emitter
local sparkTexture = P.sparkTexture
local fade = P.fade
local floorUnder = P.floorUnder
local shakeNear = P.shakeNear

local RiftGear = require(script.Parent.RiftGear)
local RiftBurn = require(script.Parent.RiftBurn)
local RiftFlask = require(script.Parent.RiftFlask)
local RiftPortal = require(script.Parent.RiftPortal)
local RiftRay = require(script.Parent.RiftRay)
local RiftGlove = require(script.Parent.RiftGlove)
local flash = RiftPortal.flash
local bolt = RiftPortal.bolt
local chargeGlove = RiftGlove.charge

local onOwnFizzle: (() -> ())? = nil

-- Our own portal shot fizzled: the move is over sooner (KitController's
-- hold on our attacks is released, CombatEffectsController sets it).
function RiftFx.setOnOwnFizzle(callback: () -> ())
	onOwnFizzle = callback
end

-- CombatEffectsController gives us its camera shake.
RiftFx.setShake = P.setShake

function RiftFx.watch(model: Model)
	RiftGear.watch(model)
	RiftBurn.watch(model)
	RiftGlove.watch(model)
end

------------------------------------------------------------------------------
-- Shared bits: colours, beams, one RenderStepped for the humming guns and
-- the finisher (kept tiny: a few property writes per thing per frame)
------------------------------------------------------------------------------

-- White-hot (a touch of green), green-grey smoke.
local HOT = Color3.fromRGB(232, 255, 214)
local FUME = Color3.fromRGB(46, 66, 48)
local HEAT = Color3.fromRGB(255, 186, 120) -- hot air off the ray gun
local RUBBLE = Color3.fromRGB(88, 84, 78)

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local TAU = math.pi * 2
-- (a circle from four Bezier quarters: control length)
local KAPPA = 0.5523
-- Further than this from the camera nothing here is animated.
local FAR = 220
-- Past this many finishers at once, a new one only gets the plain look.
local MAX_CUTS = 4

local random = Random.new()

local function newPoint(parent: Instance, cframe: CFrame?): Attachment
	local point = Instance.new("Attachment")
	if cframe then
		point.CFrame = cframe
	end
	point.Parent = parent
	return point
end

local function newBeam(a0: Attachment, a1: Attachment, parent: Instance): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Width0 = 0.1
	beam.Width1 = 0.1
	beam.Parent = parent
	return beam
end

-- An invisible anchored part things hang on.
local function holderAt(name: string, cframe: CFrame, size: number?): Part
	local holder = ghost(name, Vector3.one * (size or 0.1), RIFT_GREEN, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CFrame = cframe
	return holder
end

-- A flat ellipsoid / ellipsoid (a part with a sphere mesh).
local function blob(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = ghost(name, size, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?,
	delay: number?
)
	TweenService:Create(
		instance,
		TweenInfo.new(
			seconds,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out,
			0,
			false,
			delay or 0
		),
		goal
	):Play()
end

-- A ring of light: four beams (Bezier quarters) round its holder's Z axis.
-- (look: the transparency last written to the beams)
type BeamRing = { points: { Attachment }, beams: { Beam }, look: number }

local function beamRing(
	parent: Instance,
	color: ColorSequence,
	width: number,
	transparency: number
): BeamRing
	local ring: BeamRing = { points = {}, beams = {}, look = transparency }
	for _ = 1, 4 do
		table.insert(ring.points, newPoint(parent))
	end
	for i = 1, 4 do
		local beam = newBeam(ring.points[i], ring.points[i % 4 + 1], parent)
		beam.Color = color
		beam.Width0 = width
		beam.Width1 = width
		beam.Transparency = NumberSequence.new(transparency)
		beam.Segments = 10
		table.insert(ring.beams, beam)
	end
	return ring
end

-- Lays the ring out as a circle of radius `r` in its holder's XY plane;
-- `tilt` lifts the quarter points off the plane (sin / cos of `phase`: the
-- ring rocks like a coin spinning down).
local function placeBeamRing(ring: BeamRing, r: number, tilt: number, phase: number)
	local s, c = math.sin(phase) * tilt, math.cos(phase) * tilt
	local points = ring.points
	points[1].CFrame = CFrame.fromMatrix(Vector3.new(r, 0, s), Vector3.yAxis, Vector3.zAxis)
	points[2].CFrame = CFrame.fromMatrix(Vector3.new(0, r, c), -Vector3.xAxis, Vector3.zAxis)
	points[3].CFrame = CFrame.fromMatrix(Vector3.new(-r, 0, -s), -Vector3.yAxis, Vector3.zAxis)
	points[4].CFrame = CFrame.fromMatrix(Vector3.new(0, -r, -c), Vector3.xAxis, Vector3.zAxis)
	local curve = KAPPA * r
	for _, beam in ring.beams do
		beam.CurveSize0 = curve
		beam.CurveSize1 = curve
	end
end

local function setRingLook(ring: BeamRing, width: number, transparency: number)
	local clamped = math.clamp(transparency, 0, 1)
	-- (a new NumberSequence only when the look has really changed)
	local look: NumberSequence? = nil
	if
		math.abs(clamped - ring.look) >= 0.02
		or (clamped ~= ring.look and (clamped == 0 or clamped == 1))
	then
		ring.look = clamped
		look = NumberSequence.new(clamped)
	end
	for _, beam in ring.beams do
		beam.Width0 = width
		beam.Width1 = width
		if look then
			beam.Transparency = look
		end
	end
end

-- A ring of light racing out across the plane of `cframe` (its XY plane:
-- for a flat one, CFrame.lookAt(at, at + up)); cleans itself up.
local function shockwave(
	cframe: CFrame,
	from: number,
	to: number,
	seconds: number,
	width: number,
	color: Color3
)
	local holder = holderAt("RiftShock", cframe)
	local ring = beamRing(holder, ColorSequence.new(HOT, color), width, 0)
	placeBeamRing(ring, from, 0, 0)
	holder.Parent = workspace
	Debris:AddItem(holder, seconds + 0.5)
	local start = os.clock()
	local tilt = random:NextNumber(0.01, 0.035) * to
	local phase = random:NextNumber(0, TAU)
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - start) / seconds, 0, 1)
		if holder.Parent == nil or u >= 1 then
			connection:Disconnect()
			holder:Destroy()
			return
		end
		local ease = 1 - (1 - u) ^ 3
		placeBeamRing(ring, from + (to - from) * ease, tilt * ease, phase)
		setRingLook(ring, width * (1 - u) + 0.03, u ^ 1.3)
	end)
end

------------------------------------------------------------------------------
-- The held guns humming
------------------------------------------------------------------------------

type Gun = {
	folder: Folder,
	portal: boolean,
	tip: BasePart?,
	glows: { BasePart },
	base: Color3,
	hot: Color3,
	light: PointLight?,
	core: BasePart?,
	shimmer: BasePart?,
	swirl: { Attachment }, -- two rings of two points (the portal gun)
	phase: number,
	spike: number,
}
local guns: { Gun } = {}
local gunOf: { [Folder]: Gun } = setmetatable({}, { __mode = "k" }) :: any

-- The bulb's swirl: two little rings of light turning round it, each tipped
-- its own way and rocking.
local SWIRL_R = 0.3
local SWIRL_TIPS = { CFrame.Angles(0.6, 0, 0.3), CFrame.Angles(-0.5, 1.4, -0.7) }

local function updateGun(gun: Gun, now: number, dt: number)
	local speed = if gun.portal then 5.2 else 7.6
	local wave = 0.5 + 0.5 * math.sin(now * speed + gun.phase)
	-- (a second, faster wobble: an uneven hum, not a metronome)
	local hum = 0.5 + 0.5 * math.sin(now * speed * 2.7 + gun.phase * 1.3)
	local heat =
		math.clamp(0.15 + wave * 0.45 + hum * 0.15 + random:NextNumber(0, 0.12) + gun.spike, 0, 1)
	gun.spike = math.max(0, gun.spike - dt * 2.5)
	local color = gun.base:Lerp(gun.hot, heat)
	for _, part in gun.glows do
		part.Color = color
	end
	local light = gun.light
	if light then
		light.Brightness = 0.9 + 1.8 * heat
		light.Range = 5 + 3 * heat
	end
	local core = gun.core
	if core then
		core.Transparency = 0.45 - 0.45 * heat
	end
	local shimmer = gun.shimmer
	if shimmer then
		shimmer.Transparency = 0.6 - 0.3 * heat
	end
	local swirl = gun.swirl
	if #swirl == 4 then
		for ring = 1, 2 do
			local tipped = SWIRL_TIPS[ring] * CFrame.Angles(0.35 * math.sin(now * 1.3 + ring), 0, 0)
			local angle = now * (if ring == 1 then 7 else -9) + gun.phase
			local r = SWIRL_R * (0.9 + 0.2 * hum)
			for side = 0, 1 do
				local a = angle + side * math.pi
				local at =
					tipped:VectorToWorldSpace(Vector3.new(r * math.cos(a), 0, r * math.sin(a)))
				local along = tipped:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))
				swirl[(ring - 1) * 2 + side + 1].CFrame =
					CFrame.fromMatrix(at, along, tipped.UpVector)
			end
		end
	end
end

-- What makes a gun hum: its glowing parts (the neon ones) pulse, a core
-- and a shimmer of distorted air at the muzzle, and per gun: hot air rising
-- and embers (ray gun), motes drawn in and a swirl (portal gun).
local function dressGun(folder: Folder, tip: BasePart?, portal: boolean)
	local glows: { BasePart } = {}
	local light: PointLight? = nil
	for _, child in folder:GetDescendants() do
		if
			child:IsA("BasePart")
			and child.Material == Enum.Material.Neon
			and child.Transparency < 1
		then
			table.insert(glows, child)
		elseif child:IsA("PointLight") and light == nil then
			light = child
		end
	end
	local base = if portal then RIFT_GREEN else RAY_GLOW
	local gun: Gun = {
		folder = folder,
		portal = portal,
		tip = tip,
		glows = glows,
		base = if #glows > 0 then glows[1].Color else base,
		hot = if portal then HOT else FIRE_HOT,
		light = light,
		core = nil,
		shimmer = nil,
		swirl = {},
		phase = random:NextNumber(0, TAU),
		spike = 0,
	}
	if tip then
		if light == nil then
			local made = Instance.new("PointLight")
			made.Color = base
			made.Brightness = 1.2
			made.Range = 6
			made.Parent = tip
			gun.light = made
		end
		local core = ghost(
			"Core",
			-- (the ray gun's core wraps its tip, else an opaque neon tip hides it)
			Vector3.one
				* (
					if portal
						then 0.17
						else math.clamp(
							math.min(tip.Size.X, tip.Size.Y, tip.Size.Z) + 0.04,
							0.13,
							0.4
						)
				),
			if portal then HOT else RAY_CORE,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		stick(tip, core, CFrame.identity, folder)
		gun.core = core
		local shimmer = ghost(
			"Shimmer",
			Vector3.one * (if portal then 0.62 else 0.55),
			base,
			Enum.Material.ForceField,
			Enum.PartType.Ball
		)
		stick(tip, shimmer, CFrame.identity, folder)
		gun.shimmer = shimmer
		local mouth = newPoint(tip)
		if portal then
			-- Motes drawn into the bulb from all round it.
			local field = ghost(
				"MoteField",
				Vector3.one * 1.1,
				RIFT_GREEN,
				Enum.Material.SmoothPlastic,
				Enum.PartType.Ball
			)
			field.Transparency = 1
			stick(tip, field, CFrame.identity, folder)
			local motes = emitter(field, {
				Name = "Motes",
				Color = ColorSequence.new(RIFT_GLOW, HOT),
				LightEmission = 1,
				Size = NumberSequence.new(0.07, 0),
				Transparency = NumberSequence.new(0.1, 0.6),
				Lifetime = NumberRange.new(0.2, 0.3),
				Speed = NumberRange.new(1.6, 2.4),
				Rate = 16,
				-- (no spread: straight in along the sphere's normal)
				SpreadAngle = Vector2.zero,
			})
			sparkTexture(motes)
			motes.Shape = Enum.ParticleEmitterShape.Sphere
			motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
			for _ = 1, 4 do
				table.insert(gun.swirl, newPoint(tip))
			end
			for ring = 0, 1 do
				local a, b = gun.swirl[ring * 2 + 1], gun.swirl[ring * 2 + 2]
				for half = 0, 1 do
					local beam =
						newBeam(if half == 0 then a else b, if half == 0 then b else a, folder)
					beam.Color = ColorSequence.new(HOT, RIFT_GREEN)
					-- (a comet: bright at its head, gone at its tail)
					beam.Transparency = NumberSequence.new(0.15, 0.95)
					beam.Width0 = 0.05
					beam.Width1 = 0.02
					beam.Segments = 8
					beam.CurveSize0 = SWIRL_R * 4 / 3
					beam.CurveSize1 = SWIRL_R * 4 / 3
				end
			end
		else
			-- Hot air shimmering up off the muzzle, now and then an ember.
			local haze = emitter(mouth, {
				Name = "Heat",
				Texture = SMOKE_TEXTURE,
				Color = ColorSequence.new(HEAT, SMOKE),
				LightEmission = 0.35,
				Size = NumberSequence.new(0.18, 0.7),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.2, 0.86),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(0.45, 0.8),
				Speed = NumberRange.new(0.2, 0.6),
				Acceleration = Vector3.new(0, 2.4, 0),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-60, 60),
				Rate = 9,
			})
			haze.Drag = 1
			local embers = emitter(mouth, {
				Name = "Embers",
				Color = ColorSequence.new(FIRE_HOT, RAY_GLOW),
				LightEmission = 1,
				Size = NumberSequence.new(0.06, 0),
				Lifetime = NumberRange.new(0.3, 0.6),
				Speed = NumberRange.new(0.5, 1.5),
				Acceleration = Vector3.new(0, 3, 0),
				Rate = 5,
			})
			sparkTexture(embers)
		end
	end
	gunOf[folder] = gun
	table.insert(guns, gun)
end

-- A spike of light in the gun in his hand (a shot).
local function flareGun(folder: Folder?)
	local gun = if folder then gunOf[folder] else nil
	if gun then
		gun.spike = 1
	end
end

------------------------------------------------------------------------------
-- The finisher's state (one per Dr. Rift playing it)
------------------------------------------------------------------------------

type Portal = RiftPortal.Portal
type Spark = { point: Attachment, sparks: ParticleEmitter }
type Arc = { from: Attachment, offset: CFrame, beam: Beam }
type Rock = {
	part: BasePart,
	base: Vector3,
	rise: number,
	spin: Vector3,
	phase: number,
	delay: number,
}
type Tongue = {
	a0: Attachment,
	a1: Attachment,
	beam: Beam,
	born: number,
	life: number,
	width: number,
}
type Cut = {
	victim: Model,
	anchor: CFrame,
	center: Vector3, -- where the cut is (the ring's centre)
	folder: Folder, -- our own bits in the world
	extras: { Instance }, -- our bits on the bodies (attachments, emitters)
	ring: Portal?,
	started: number,
	done: boolean,
	rich: boolean,
	-- Lift
	arcs: { Arc },
	ends: { Spark },
	nextArc: number,
	shell: BasePart?,
	shellWeld: Weld?,
	haze: BasePart?,
	outline: Highlight?,
	fieldLight: PointLight?,
	rocks: { Rock },
	dust: BasePart?,
	-- the ring open
	opened: number?,
	closing: number?,
	hum: { BeamRing },
	tongues: { Tongue },
	licks: { ParticleEmitter },
	cocoon: BasePart?,
	ringLight: PointLight?,
}
local cuts: { [Model]: Cut } = setmetatable({}, { __mode = "k" }) :: any
local active: { Cut } = {}

local HUM_R = Finishers.PORTAL_RADIUS * 0.93
-- Round the hips (victim space: X across, Z through): where the tongues lick.
local HIP_X, HIP_Z = 1.08, 0.62

local function rerollArcs(cut: Cut, now: number)
	cut.nextArc = now + random:NextNumber(0.045, 0.1)
	local ends = cut.ends
	if #ends == 0 then
		return
	end
	for _, arc in cut.arcs do
		if random:NextNumber() < 0.3 then
			arc.beam.Enabled = false
		else
			local target = ends[random:NextInteger(1, #ends)]
			local beam = arc.beam
			beam.Enabled = true
			beam.Attachment1 = target.point
			-- (the curve bends along each end's X axis: turned at random)
			arc.from.CFrame = arc.offset
				* CFrame.Angles(
					random:NextNumber(0, TAU),
					random:NextNumber(0, TAU),
					random:NextNumber(0, TAU)
				)
			target.point.Orientation = Vector3.new(
				random:NextNumber(0, 360),
				random:NextNumber(0, 360),
				random:NextNumber(0, 360)
			)
			beam.CurveSize0 = random:NextNumber(-3, 3)
			beam.CurveSize1 = random:NextNumber(-2.5, 2.5)
			beam.Width0 = random:NextNumber(0.1, 0.24)
			beam.Width1 = random:NextNumber(0.03, 0.08)
			beam.TextureLength = random:NextNumber(0.8, 1.6)
			target.sparks:Emit(random:NextInteger(1, 3))
		end
	end
end

local function rerollTongue(tongue: Tongue, now: number, shrink: number)
	local angle = random:NextNumber(0, TAU)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local p0 = Vector3.new(HIP_X * out.X, random:NextNumber(-0.08, 0.08), HIP_Z * out.Z)
	local up = if random:NextNumber() < 0.55 then 1 else -1
	local length = random:NextNumber(0.6, 1.7) * shrink
	local p1 = p0 * random:NextNumber(0.75, 0.95) + Vector3.new(0, up * length, 0)
	-- (X = out of the body: the curve bows the tongue off the skin)
	tongue.a0.CFrame = CFrame.fromMatrix(p0, out, Vector3.yAxis)
	tongue.a1.CFrame = CFrame.fromMatrix(p1, out, Vector3.yAxis)
	-- (control points: a0 + X * CurveSize0 and a1 - X * CurveSize1, so
	-- CurveSize0 > 0 and CurveSize1 < 0 keep both off the skin)
	tongue.beam.CurveSize0 = random:NextNumber(0.15, 0.55)
	tongue.beam.CurveSize1 = -random:NextNumber(0, 0.35)
	tongue.born = now
	tongue.life = random:NextNumber(0.07, 0.16)
	tongue.width = random:NextNumber(0.18, 0.42) * (0.6 + 0.4 * shrink)
end

local function updateCut(cut: Cut, now: number)
	local t = now - cut.started
	if now >= cut.nextArc then
		rerollArcs(cut, now)
	end
	local shell = cut.shell
	if shell then
		shell.Transparency = 0.32 + 0.14 * math.sin(t * 9) + random:NextNumber(0, 0.08)
	end
	local light = cut.fieldLight
	if light then
		light.Brightness = 1.4 + 0.6 * math.sin(t * 13) + random:NextNumber(0, 0.6)
	end
	local outline = cut.outline
	if outline then
		outline.OutlineTransparency = 0.25 + random:NextNumber(0, 0.35)
	end
	for _, rock in cut.rocks do
		local u = math.clamp((t - rock.delay) / 0.9, 0, 1)
		local ease = 1 - (1 - u) ^ 3
		local bob = 0.12 * math.sin(t * 1.8 + rock.phase)
		local spin = rock.spin * t
		rock.part.CFrame = CFrame.new(rock.base + Vector3.new(0, (rock.rise + bob) * ease, 0))
			* CFrame.fromEulerAnglesXYZ(spin.X, spin.Y, spin.Z)
	end
	local opened = cut.opened
	if opened == nil then
		return
	end
	-- The ring: humming (its radius trembling), rocking; closing, it
	-- contracts onto the body and burns white.
	local closing = cut.closing
	local squeeze = if closing then math.clamp((now - closing) / 0.2, 0, 1) ^ 3 else 0
	local open = math.clamp((now - opened) / 0.25, 0, 1)
	local r = HUM_R
		* (0.6 + 0.4 * open)
		* (1 + 0.022 * math.sin(t * 31) + random:NextNumber(-0.012, 0.012))
		* (1 - 0.45 * squeeze)
	local tilt = 0.07 * (1 - squeeze)
	local phase = t * 6.5
	for index, ring in cut.hum do
		placeBeamRing(ring, r * (if index == 1 then 1 else 1.04), tilt, phase)
		if index == 1 then
			setRingLook(ring, 0.06 + 0.22 * squeeze + 0.02 * math.sin(t * 40), 0)
		else
			setRingLook(
				ring,
				0.4 + 0.3 * squeeze,
				0.62 - 0.3 * squeeze + random:NextNumber(0, 0.12)
			)
		end
	end
	local cocoon = cut.cocoon
	if cocoon and closing == nil then
		cocoon.Transparency = 0.4 + 0.15 * math.sin(t * 11) + random:NextNumber(0, 0.06)
	end
	local ringLight = cut.ringLight
	if ringLight and closing == nil then
		ringLight.Brightness = 1.6 + random:NextNumber(0, 1.4)
	end
	local shrink = 1 - 0.7 * squeeze
	for _, tongue in cut.tongues do
		local age = now - tongue.born
		if age >= tongue.life then
			rerollTongue(tongue, now, shrink)
			age = 0
		end
		local left = 1 - age / tongue.life
		tongue.beam.Width0 = tongue.width * (0.35 + 0.65 * left)
		tongue.beam.Width1 = 0.02
	end
end

local stepConnection: RBXScriptConnection? = nil

local function step(dt: number)
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for index = #guns, 1, -1 do
		local gun = guns[index]
		if gun.folder.Parent == nil then
			table.remove(guns, index)
		else
			local tip = gun.tip
			if tip == nil or (tip.Position - eye).Magnitude < FAR then
				updateGun(gun, now, dt)
			end
		end
	end
	for index = #active, 1, -1 do
		local cut = active[index]
		if cut.done then
			table.remove(active, index)
		elseif (cut.center - eye).Magnitude < FAR then
			updateCut(cut, now)
		end
	end
	if #guns == 0 and #active == 0 and stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
end

local function wake()
	if stepConnection == nil then
		stepConnection = RunService.RenderStepped:Connect(step)
	end
end

------------------------------------------------------------------------------
-- Props in his right hand
------------------------------------------------------------------------------

local props: { [Model]: { folder: Folder, token: number } } = setmetatable({}, { __mode = "k" }) :: any
local propToken = 0

local function removeProp(model: Model)
	local prop = props[model]
	props[model] = nil
	if prop then
		prop.folder:Destroy()
	end
end

RiftFlask.onReleased(removeProp) -- (the flask left his hand)

-- A gun (ray gun: orange core; portal gun: green core). Its barrel goes
-- along the arm's -Y (with the arm raised, where he aims).
-- The RiftGear meshes when the place has them (Combat/RiftAssets: grip,
-- trigger guard, coils, a glass tube of glowing fluid, the dish or the glass
-- bulb), else a simpler gun from parts. Either way the muzzle is a part
-- named "Tip" or "Bulb" right in `folder` (muzzleOf looks there), and the
-- gun hums while held (dressGun).
local function buildGun(arm: BasePart, folder: Folder, portal: boolean)
	local glow = if portal then RIFT_GREEN else RAY_GLOW
	local RiftAssets = require(script.Parent.RiftAssets)
	local main = RiftAssets.spawn(if portal then "PortalGun" else "RayGun", arm.CFrame)
	if main then
		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = main
		weld.C0 = arm.CFrame:ToObjectSpace(main.CFrame)
		weld.Parent = main
		main.Parent = folder
		local tip = main:FindFirstChild("Tip")
		local muzzle: BasePart? = nil
		if tip and tip:IsA("BasePart") then
			tip.Parent = folder -- (its weld goes with it)
			local light = Instance.new("PointLight")
			light.Color = glow
			light.Brightness = 1.2
			light.Range = 6
			light.Parent = tip
			muzzle = tip
		end
		dressGun(folder, muzzle, portal)
		wake()
		return
	end
	local hand = CFrame.new(0, -1.05, 0)
	local along = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis (X) → the arm's Y
	stick(
		arm,
		ghost("Grip", Vector3.new(0.26, 0.5, 0.3), CABLE, Enum.Material.Rubber),
		hand * CFrame.new(0, 0, 0.1),
		folder
	)
	stick(
		arm,
		ghost(
			"Body",
			Vector3.new(1.1, 0.46, 0.46),
			STEEL,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		),
		hand * CFrame.new(0, -0.45, -0.32) * along,
		folder
	)
	local tube =
		ghost("Tube", Vector3.new(0.8, 0.2, 0.2), glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	tube.Transparency = 0.1
	stick(arm, tube, hand * CFrame.new(0, -0.4, -0.62) * along, folder)
	for index = 1, 3 do
		stick(
			arm,
			ghost(
				"Coil",
				Vector3.new(0.08, 0.56, 0.56),
				BRASS,
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			),
			hand * CFrame.new(0, -0.2 - index * 0.17, -0.32) * along,
			folder
		)
	end
	-- The muzzle: a dish (ray) or a glass bulb (portal).
	local muzzle: BasePart
	if portal then
		local bulb = ghost(
			"Bulb",
			Vector3.new(0.42, 0.42, 0.42),
			RIFT_GREEN,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		bulb.Transparency = 0.2
		stick(arm, bulb, hand * CFrame.new(0, -1.08, -0.32), folder)
		local light = Instance.new("PointLight")
		light.Color = RIFT_GREEN
		light.Brightness = 1.2
		light.Range = 6
		light.Parent = bulb
		muzzle = bulb
	else
		stick(
			arm,
			ghost(
				"Dish",
				Vector3.new(0.1, 0.7, 0.7),
				BRASS,
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			),
			hand * CFrame.new(0, -1.02, -0.32) * along,
			folder
		)
		local tip = ghost(
			"Tip",
			Vector3.new(0.18, 0.18, 0.18),
			RAY_GLOW,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		stick(arm, tip, hand * CFrame.new(0, -1.12, -0.32), folder)
		muzzle = tip
	end
	dressGun(folder, muzzle, portal)
	wake()
end

-- `kind` = "Flask" / "Bomb" / "Ray" / "Portal", held for `seconds`.
local function holdProp(model: Model, kind: string, seconds: number)
	removeProp(model)
	local arm = model:FindFirstChild("Right Arm")
	if arm == nil or not arm:IsA("BasePart") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "RiftProp"
	if kind == "Flask" or kind == "Bomb" then
		RiftFlask.buildHeld(arm, folder, if kind == "Bomb" then "Explosive" else "Acid")
	else
		buildGun(arm, folder, kind == "Portal")
	end
	folder.Parent = model
	propToken += 1
	local token = propToken
	props[model] = { folder = folder, token = token }
	task.delay(seconds, function()
		local prop = props[model]
		if prop and prop.token == token then
			removeProp(model)
		end
	end)
end

-- Which prop a clip holds, and for how long.
local function propOf(animation: string): (string?, number)
	local kit = Kits.get(KIT)
	if kit == nil then
		return nil, 0
	end
	local lists = { kit.moves }
	if kit.awakening then
		table.insert(lists, kit.awakening.moves)
	end
	for _, list in lists do
		for _, move in list do
			if move.animation == animation and move.gadget then
				local gadget = move.gadget
				if gadget.flask then
					return if gadget.flask.kind == "Explosive" then "Bomb" else "Flask",
						gadget.flask.release
				elseif gadget.ray then
					return "Ray", move.duration
				elseif gadget.portal then
					return "Portal", move.duration
				end
			end
		end
	end
	return nil, 0
end

-- The muzzle of the gun in his hand (or his hand).
local function muzzleOf(model: Model): Vector3?
	local prop = props[model]
	if prop then
		local tip = prop.folder:FindFirstChild("Tip") or prop.folder:FindFirstChild("Bulb")
		if tip and tip:IsA("BasePart") then
			return tip.Position
		end
	end
	local arm = model:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		return (arm.CFrame * CFrame.new(0, -1.2, 0)).Position
	end
	return nil
end

-- The teleport sound playing for each Dr. Rift (stopped on a fizzle).
local teleportSounds: { [Model]: Sound? } = setmetatable({}, { __mode = "k" }) :: any

function RiftFx.onAction(model: Model, animation: string)
	local kind, seconds = propOf(animation)
	if kind then
		holdProp(model, kind, seconds)
		if kind == "Flask" or kind == "Bomb" then
			task.delay(math.max(0, seconds - 0.12), function()
				if model.Parent then
					SoundController.play("FlaskThrow", model)
				end
			end)
		end
	end
	if animation == "Rift_Portal" then
		-- The teleport sound from the start of the move (0.78 s before he
		-- steps through): the file takes a moment to get going, so it is
		-- heard as he comes out. Cut if the shot fizzles.
		teleportSounds[model] = SoundController.play("Teleport", model)
	elseif animation == "Rift_Glove" then
		-- The blast, timed on the clip (the palm out at 0.36 s), not on the
		-- server's answer, which comes later.
		task.delay(0.3, function()
			if model.Parent then
				SoundController.play("GloveBlast", model)
			end
		end)
	elseif animation == "Rift_RayGun" or animation == "Rift_MegaRay" then
		-- The shot, timed on the clip (0.32 / 0.45 s).
		local big = animation == "Rift_MegaRay"
		task.delay(if big then 0.45 else 0.32, function()
			if model.Parent then
				SoundController.play(if big then "RayGunBig" else "RayGun", model)
			end
		end)
	end
	if animation == "Rift_Glove" or animation == "Rift_Slam" then
		chargeGlove(model, if animation == "Rift_Slam" then 0.55 else 0.36)
	elseif animation == "Rift_Awaken" then
		chargeGlove(model, 0.9)
		RiftGlove.onAwaken(model)
	end
end

local function stopTeleportSound(model: Model)
	local sound = teleportSounds[model]
	teleportSounds[model] = nil
	if sound then
		sound:Destroy()
	end
end

function RiftFx.stopAction(model: Model)
	removeProp(model)
	stopTeleportSound(model)
end

function RiftFx.onRemote(kind: unknown, data: unknown)
	if typeof(kind) ~= "string" or typeof(data) ~= "table" then
		return
	end
	local info = data :: { [string]: any }
	if kind == "FlaskThrown" then
		RiftFlask.thrown(info)
	elseif kind == "FlaskBurst" then
		RiftFlask.burst(info)
	elseif kind == "Puddle" then
		RiftFlask.puddle(info)
	elseif kind == "Ray" then
		RiftRay.ray(info, muzzleOf)
	elseif kind == "PortalShot" then
		local by, to = info.by, info.to
		if typeof(by) == "Instance" and by:IsA("Model") and typeof(to) == "Vector3" then
			local from = muzzleOf(by)
			if from then
				bolt(from, to)
			end
			SoundController.play("PortalShot", by)
		end
	elseif kind == "Portals" then
		RiftPortal.portals(info)
	elseif kind == "PortalFizzle" then
		local by, at = info.by, info.at
		local where: Vector3? = if typeof(at) == "Vector3" then at else nil
		if typeof(by) == "Instance" and by:IsA("Model") then
			where = where or muzzleOf(by)
			SoundController.play("PortalFizzle", by)
			stopTeleportSound(by)
			-- (our own portal move: the step through won't happen)
			-- (the step through won't happen: everyone stops his clip)
			CharacterAnimationController.stopAction(by, "Rift_Portal")
			if by == Players.LocalPlayer.Character and onOwnFizzle then
				onOwnFizzle()
			end
			removeProp(by)
		end
		if where then
			flash(where, 0.5)
		end
	elseif kind == "Wave" then
		RiftGlove.wave(info)
	elseif kind == "CloneIn" then
		RiftPortal.cloneIn(info)
	elseif kind == "CloneOut" then
		RiftPortal.cloneOut(info)
	end
end

------------------------------------------------------------------------------
-- PortalCut (the finisher's timeline, CinematicController)
------------------------------------------------------------------------------

-- Everything of a finisher goes (cancelled, or the cut has come).
local function endCut(cut: Cut)
	if cut.done then
		return
	end
	cut.done = true
	local ring = cut.ring
	cut.ring = nil
	if ring then
		ring.folder:Destroy()
	end
	cut.folder:Destroy()
	for _, thing in cut.extras do
		thing:Destroy()
	end
	table.clear(cut.extras)
end

local function newCut(attacker: Model, victim: Model, anchor: CFrame): Cut
	local old = cuts[attacker]
	if old then
		endCut(old)
	end
	local folder = Instance.new("Folder")
	folder.Name = "RiftCut"
	folder.Parent = workspace
	local cut: Cut = {
		victim = victim,
		anchor = anchor,
		center = (anchor * Finishers.PORTAL_RING).Position,
		folder = folder,
		extras = {},
		ring = nil,
		started = os.clock(),
		done = false,
		rich = #active < MAX_CUTS,
		arcs = {},
		ends = {},
		nextArc = 0,
		shell = nil,
		shellWeld = nil,
		haze = nil,
		outline = nil,
		fieldLight = nil,
		rocks = {},
		dust = nil,
		opened = nil,
		closing = nil,
		hum = {},
		tongues = {},
		licks = {},
		cocoon = nil,
		ringLight = nil,
	}
	cuts[attacker] = cut
	table.insert(active, cut)
	wake()
	-- (never left on if the cut doesn't come: someone left)
	task.delay(3.4, function()
		if not cut.done then
			endCut(cut)
			if cuts[attacker] == cut then
				cuts[attacker] = nil
			end
		end
	end)
	return cut
end

-- The finisher of `attacker` on `victim` (a new one if an event comes
-- without its Lift: joined late).
local function cutOf(attacker: Model, victim: Model, anchor: CFrame): Cut
	local cut = cuts[attacker]
	if cut and not cut.done and cut.victim == victim then
		return cut
	end
	return newCut(attacker, victim, anchor)
end

-- Body points the glove's arcs land on (part, offset).
local ARC_ENDS: { { part: string, offset: Vector3 } } = {
	{ part = "Torso", offset = Vector3.new(0.5, 0.5, 0) },
	{ part = "Torso", offset = Vector3.new(-0.55, -0.45, 0) },
	{ part = "Torso", offset = Vector3.new(0, 0, 0.3) },
	{ part = "Head", offset = Vector3.new(0, 0.2, 0) },
	{ part = "Left Arm", offset = Vector3.new(0, -0.7, 0) },
	{ part = "Right Arm", offset = Vector3.new(0, -0.7, 0) },
	{ part = "Left Leg", offset = Vector3.new(0, -0.5, 0) },
	{ part = "Right Leg", offset = Vector3.new(0, -0.5, 0) },
}

-- Lift: the glove's field closes round the victim and holds them up.
local function lift(cut: Cut, attacker: Model, victim: Model, anchor: CFrame)
	local torso = victim:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		-- Green sparks crawling over them.
		local crawl = emitter(torso, {
			Name = "RiftHold",
			Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
			LightEmission = 1,
			Size = NumberSequence.new(0.15, 0),
			Lifetime = NumberRange.new(0.2, 0.4),
			Speed = NumberRange.new(0.5, 2),
			Rate = 40,
		})
		sparkTexture(crawl)
		crawl.Shape = Enum.ParticleEmitterShape.Box
		table.insert(cut.extras, crawl)
		if not cut.rich then
			return
		end
		-- The field: a shimmering shell round the whole body springing shut
		-- on them (welded to the torso: it follows the lift), a faint green
		-- haze inside, a light, a green outline.
		local hold = CFrame.new(0, -0.6, 0)
		for index, look in
			{
				{
					name = "RiftField",
					material = Enum.Material.ForceField,
					size = Vector3.new(3.7, 6.5, 2.9),
					t = 0.3,
				},
				{
					name = "RiftHaze",
					material = Enum.Material.Neon,
					size = Vector3.new(3.3, 6.1, 2.5),
					t = 0.95,
				},
			}
		do
			local part = blob(look.name, look.size * 1.8, RIFT_GREEN, look.material)
			part.Transparency = 1
			part.CFrame = torso.CFrame * hold
			local weld = Instance.new("Weld")
			weld.Part0 = torso
			weld.Part1 = part
			weld.C0 = hold
			weld.Parent = part
			part.Parent = cut.folder
			-- (in from wider: the field closing on them)
			tween(part, 0.32, { Size = look.size }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			if index == 1 then
				part.Transparency = 0.3
				cut.shell = part
				cut.shellWeld = weld
				local light = Instance.new("PointLight")
				light.Color = RIFT_GREEN
				light.Brightness = 0
				light.Range = 11
				light.Parent = part
				cut.fieldLight = light
			else
				tween(part, 0.3, { Transparency = look.t })
				cut.haze = part
			end
		end
		local outline = Instance.new("Highlight")
		outline.Name = "RiftOutline"
		outline.Adornee = victim
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.FillColor = RIFT_GREEN
		outline.FillTransparency = 1
		outline.OutlineColor = RIFT_GLOW
		outline.OutlineTransparency = 0.4
		outline.Parent = cut.folder
		tween(outline, 0.25, { FillTransparency = 0.84 })
		cut.outline = outline
	end
	if not cut.rich then
		return
	end
	-- Arcs from the glove to the body (they jump about: rerollArcs).
	for _, spec in ARC_ENDS do
		local part = victim:FindFirstChild(spec.part)
		if part and part:IsA("BasePart") then
			local point = newPoint(part, CFrame.new(spec.offset))
			table.insert(cut.extras, point)
			local sparks = emitter(point, {
				Name = "ArcSparks",
				Color = ColorSequence.new(HOT, RIFT_GREEN),
				LightEmission = 1,
				Size = NumberSequence.new(0.12, 0),
				Lifetime = NumberRange.new(0.12, 0.3),
				Speed = NumberRange.new(3, 8),
				Drag = 5,
				Acceleration = Vector3.new(0, -10, 0),
			})
			sparkTexture(sparks)
			table.insert(cut.ends, { point = point, sparks = sparks })
		end
	end
	local palm: BasePart? = RiftGear.palmOf(attacker)
	local palmOffset = CFrame.identity
	if palm == nil then
		local arm = attacker:FindFirstChild("Left Arm")
		if arm and arm:IsA("BasePart") then
			palm = arm
			palmOffset = CFrame.new(0, -1.1, 0)
		end
	end
	if palm and #cut.ends > 0 then
		for _ = 1, 3 do
			local from = newPoint(palm, palmOffset)
			table.insert(cut.extras, from)
			local beam = newBeam(from, cut.ends[1].point, cut.folder)
			beam.Color = ColorSequence.new(HOT, RIFT_GREEN)
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.8, 0.2),
				NumberSequenceKeypoint.new(1, 0.6),
			})
			beam.Texture = SPARK_TEXTURE
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureSpeed = 4
			beam.Segments = 14
			table.insert(cut.arcs, { from = from, offset = palmOffset, beam = beam })
		end
		-- The field itself: a wide misty tether from the palm to the chest.
		-- (its own end: the arc ends are turned at random, which would make
		-- the tether's curve jump every reroll)
		local chest = cut.ends[1].point
		if torso and torso:IsA("BasePart") then
			chest = newPoint(torso, CFrame.new(ARC_ENDS[1].offset))
			table.insert(cut.extras, chest)
		end
		local from = newPoint(palm, palmOffset)
		table.insert(cut.extras, from)
		local tether = newBeam(from, chest, cut.folder)
		tether.Color = ColorSequence.new(RIFT_GLOW, RIFT_DEEP)
		tether.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.75),
			NumberSequenceKeypoint.new(1, 0.9),
		})
		tether.Texture = SMOKE_TEXTURE
		tether.TextureMode = Enum.TextureMode.Wrap
		tether.TextureLength = 2.5
		tether.TextureSpeed = 1.6
		tether.LightEmission = 0.7
		tether.Width0 = 0.5
		tether.Width1 = 2.2
		tether.CurveSize0 = random:NextNumber(-0.8, 0.8)
		tether.CurveSize1 = random:NextNumber(-0.8, 0.8)
	end
	-- Under their feet: rubble and dust floating up off the floor, a ring
	-- of distorted air racing out.
	local feet = (anchor * CFrame.new(0, -2.4, -Finishers.PORTAL_DISTANCE)).Position
	local floor = floorUnder(feet)
	local ground = if floor then floor.Position else feet - Vector3.new(0, 0.6, 0)
	local material = Enum.Material.Slate
	local color = RUBBLE
	if floor and not floor.Instance:IsA("Terrain") then
		material = floor.Instance.Material
		color = floor.Instance.Color
	end
	for _ = 1, random:NextInteger(6, 9) do
		local size = Vector3.new(
			random:NextNumber(0.14, 0.45),
			random:NextNumber(0.1, 0.32),
			random:NextNumber(0.14, 0.42)
		)
		local rock = ghost("Rubble", size, color:Lerp(RUBBLE, random:NextNumber(0, 0.4)), material)
		rock.Anchored = true
		rock.CastShadow = true
		local angle = random:NextNumber(0, TAU)
		local far = random:NextNumber(0.5, 2.4)
		local base = ground + Vector3.new(far * math.cos(angle), size.Y / 2, far * math.sin(angle))
		rock.CFrame = CFrame.new(base)
		rock.Parent = cut.folder
		local entry: Rock = {
			part = rock,
			base = base,
			rise = random:NextNumber(0.4, 2.8),
			spin = Vector3.new(
				random:NextNumber(-2, 2),
				random:NextNumber(-2, 2),
				random:NextNumber(-2, 2)
			),
			phase = random:NextNumber(0, TAU),
			delay = random:NextNumber(0, 0.35),
		}
		table.insert(cut.rocks, entry)
	end
	local dust = holderAt("RiftDust", CFrame.new(ground + Vector3.new(0, 0.1, 0)), 1)
	dust.Size = Vector3.new(4.6, 0.2, 4.6)
	dust.Parent = cut.folder
	cut.dust = dust
	local puff = emitter(dust, {
		Name = "Dust",
		Color = ColorSequence.new((if floor then color else SMOKE):Lerp(SMOKE, 0.5)),
		LightInfluence = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 2.2),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(0.4, 1.4),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 0.7, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 12,
	})
	puff.Shape = Enum.ParticleEmitterShape.Box
	puff.Drag = 1
	puff:Emit(14)
	local motes = emitter(dust, {
		Name = "Motes",
		Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.09, 0),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(1, 2.6),
		SpreadAngle = Vector2.new(15, 15),
		EmissionDirection = Enum.NormalId.Top,
		RotSpeed = NumberRange.new(-120, 120),
		Rate = 10,
	})
	sparkTexture(motes)
	motes.Shape = Enum.ParticleEmitterShape.Box
	local flat = CFrame.lookAt(ground + Vector3.new(0, 0.1, 0), ground + Vector3.new(0, 1, 0))
	shockwave(flat, 0.5, 3.6, 0.4, 0.4, RIFT_GLOW)
	local warp = disc("RiftWarp", RIFT_GLOW, 0)
	warp.Material = Enum.Material.ForceField
	warp.CFrame = flat
	warp.Size = Vector3.new(1, 1, 0.05)
	warp.Parent = workspace
	fade(warp, 0.45, { Size = Vector3.new(8, 8, 0.05) })
	shakeNear(ground, 1.5, 0.3)
end

-- PortalOpen (0.25 s on, the ring wide open): the field drains into the
-- ring; it hums; energy licks up and down the body.
local function openRing(cut: Cut, at: CFrame, flat: CFrame)
	cut.opened = os.clock()
	-- The body's field drains down into the ring.
	local shell, weld = cut.shell, cut.shellWeld
	cut.shell = nil
	if shell and weld then
		local down = CFrame.new(0, -1, 0)
		local drain = 0.35
		tween(
			shell,
			drain,
			{ Size = Vector3.new(2.6, 0.3, 1.8), Transparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		tween(weld, drain, { C0 = down }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	local light = cut.fieldLight
	cut.fieldLight = nil
	if light then
		tween(light, 0.35, { Brightness = 0 })
	end
	local haze = cut.haze
	cut.haze = nil
	if haze then
		tween(haze, 0.3, { Transparency = 1 })
	end
	if not cut.rich then
		return
	end
	-- The hum: a white-hot line just inside the rim and a soft halo.
	local humHolder = holderAt("RiftHum", flat)
	humHolder.Parent = cut.folder
	cut.hum = {
		beamRing(humHolder, ColorSequence.new(HOT), 0.06, 0),
		beamRing(humHolder, ColorSequence.new(RIFT_GLOW, RIFT_GREEN), 0.4, 0.6),
	}
	-- Round the hips (victim space): a cocoon of energy, a light, tongues.
	local body = holderAt("RiftLick", at)
	body.Parent = cut.folder
	local cocoon =
		blob("RiftCocoon", Vector3.new(2, 0.4, 1.4), RIFT_GREEN, Enum.Material.ForceField)
	cocoon.Anchored = true
	cocoon.CFrame = at
	cocoon.Transparency = 0.4
	cocoon.Parent = cut.folder
	tween(
		cocoon,
		0.3,
		{ Size = Vector3.new(3.1, 2.9, 2.3) },
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)
	cut.cocoon = cocoon
	local ringLight = Instance.new("PointLight")
	ringLight.Color = RIFT_GREEN
	ringLight.Brightness = 0
	ringLight.Range = 9
	ringLight.Parent = body
	cut.ringLight = ringLight
	local now = os.clock()
	for _ = 1, 6 do
		local a0, a1 = newPoint(body), newPoint(body)
		local beam = newBeam(a0, a1, body)
		beam.Color = ColorSequence.new(HOT, RIFT_GREEN)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.6, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Texture = FIRE_TEXTURE
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureSpeed = 2.5
		beam.Segments = 10
		local tongue: Tongue = { a0 = a0, a1 = a1, beam = beam, born = 0, life = 0, width = 0 }
		rerollTongue(tongue, now, 1)
		tongue.born = now - random:NextNumber(0, tongue.life) -- (out of step)
		table.insert(cut.tongues, tongue)
	end
	-- Green flames licking off the ring, half up the body, half down it.
	local count = 8
	for i = 1, count do
		local angle = (i - 1) / count * TAU + random:NextNumber(-0.2, 0.2)
		local p = Vector3.new(HIP_X * math.cos(angle), 0, HIP_Z * math.sin(angle))
		local point = newPoint(
			body,
			CFrame.new(p) * (if i % 2 == 0 then CFrame.Angles(math.pi, 0, 0) else CFrame.identity)
		)
		local licks = emitter(point, {
			Name = "Licks",
			Texture = FIRE_TEXTURE,
			Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
			LightEmission = 1,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 0.08),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.2, 0.35),
			Speed = NumberRange.new(2.5, 5),
			SpreadAngle = Vector2.new(12, 12),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-180, 180),
			EmissionDirection = Enum.NormalId.Top,
			Rate = 10,
		})
		licks.Drag = 2
		licks.ZOffset = 0.4 -- (drawn over the body they lick)
		table.insert(cut.licks, licks)
	end
end

-- PortalClose: the ring contracts onto the hips, a white-hot belt tightens,
-- the light builds, sparks are drawn in.
local function closeRing(cut: Cut, at: CFrame)
	cut.closing = os.clock()
	local close = 0.2
	if cut.rich then
		local belt = blob("RiftBelt", Vector3.new(4.2, 0.12, 4.2), HOT, Enum.Material.Neon)
		belt.Anchored = true
		belt.CFrame = at
		belt.Transparency = 0.85
		belt.Parent = cut.folder
		tween(
			belt,
			close,
			{ Size = Vector3.new(2.45, 0.42, 1.45), Transparency = 0.05 },
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.In
		)
		local cocoon = cut.cocoon
		if cocoon then
			tween(
				cocoon,
				close,
				{ Size = Vector3.new(2.5, 0.8, 1.6), Transparency = 0.1 },
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			)
		end
		local light = cut.ringLight
		if light then
			tween(
				light,
				close,
				{ Color = HOT, Brightness = 8, Range = 15 },
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.In
			)
		end
		for _, licks in cut.licks do
			licks.Color = ColorSequence.new(HOT, RIFT_GLOW)
			licks.Rate = 26
		end
		-- Sparks drawn in from all round.
		local field = holderAt("RiftDraw", at, 6)
		field.Shape = Enum.PartType.Ball
		field.Parent = cut.folder
		local draw = emitter(field, {
			Name = "Draw",
			Color = ColorSequence.new(HOT, RIFT_GREEN),
			LightEmission = 1,
			Size = NumberSequence.new(0.06, 0.16),
			Transparency = NumberSequence.new(0.6, 0),
			Lifetime = NumberRange.new(0.11, 0.14),
			Speed = NumberRange.new(20, 26),
			-- (no spread: straight in along the sphere's normal)
			SpreadAngle = Vector2.zero,
		})
		sparkTexture(draw)
		draw.Shape = Enum.ParticleEmitterShape.Sphere
		draw.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		draw.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		draw:Emit(36)
		draw.Rate = 150
	end
	-- (the shake builds)
	shakeNear(at.Position, 0.9, 0.12)
	task.delay(0.1, function()
		shakeNear(at.Position, 1.8, 0.12)
	end)
end

-- What hangs on after the cut, on a part of the body: green embers and
-- thin smoke rising off it.
local function smoulder(part: Instance?, offset: CFrame, seconds: number)
	if part == nil or not part:IsA("BasePart") then
		return
	end
	local point = newPoint(part, offset)
	local embers = emitter(point, {
		Name = "Embers",
		Color = ColorSequence.new(HOT, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.6, 0.07),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0.05, 1),
		Lifetime = NumberRange.new(0.9, 1.8),
		Speed = NumberRange.new(0.4, 1.8),
		SpreadAngle = Vector2.new(50, 50),
		Acceleration = Vector3.new(0, 2.2, 0),
		RotSpeed = NumberRange.new(-150, 150),
		Rate = 9,
	})
	sparkTexture(embers)
	embers.Drag = 1.2
	embers.Shape = Enum.ParticleEmitterShape.Box
	local smoke = emitter(point, {
		Name = "Smoke",
		Color = ColorSequence.new(RIFT_DEEP, FUME),
		LightEmission = 0.15,
		LightInfluence = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 2),
		}),
		-- (thin: the wounds must show through)
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1.4, 2.4),
		Speed = NumberRange.new(0.5, 1.4),
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = Vector3.new(0, 1.4, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		Rate = 4,
	})
	smoke.Drag = 0.8
	-- (the emitters point up the world, whatever way the part lies)
	point.WorldCFrame = CFrame.new(point.WorldPosition)
	task.delay(seconds, function()
		embers.Enabled = false
		smoke.Enabled = false
	end)
	Debris:AddItem(point, seconds + 2.6)
end

-- Cut: a blinding flat flash, shockwaves along the cut plane, the air
-- bending, sparks and mist sprayed sideways, a light dying, then embers and
-- smoke rising off the cut.
local function cutBlast(cut: Cut, at: CFrame, flat: CFrame, victim: Model)
	local position = at.Position
	-- The rubble drops, the dust settles.
	for _, rock in cut.rocks do
		local part = rock.part
		part.Parent = workspace
		local fall = random:NextNumber(0.25, 0.4)
		tween(part, fall, { Position = rock.base }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		fade(part, random:NextNumber(1, 1.4), nil) -- (Quad Out: it lands, then goes)
	end
	table.clear(cut.rocks)
	local dust = cut.dust
	cut.dust = nil
	if dust then
		dust.Parent = workspace
		for _, child in dust:GetChildren() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
		Debris:AddItem(dust, 2.2)
	end
	-- Flat, wide, blinding, gone in a fifth of a second (the wounds show
	-- right after).
	local blind = blob("RiftBlind", Vector3.new(1, 0.25, 1), HOT, Enum.Material.Neon)
	blind.Anchored = true
	blind.CFrame = at * CFrame.Angles(0, random:NextNumber(0, TAU), 0)
	blind.Parent = workspace
	tween(blind, 0.06, { Size = Vector3.new(9, 2.2, 9) })
	tween(blind, 0.17, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.04)
	Debris:AddItem(blind, 0.3)
	local point = attachmentAt(position)
	local light = Instance.new("PointLight")
	light.Color = HOT
	light.Brightness = 14
	light.Range = 40
	light.Shadows = true
	light.Parent = point
	tween(light, 0.7, { Brightness = 0, Color = RIFT_GREEN })
	-- The shockwaves along the cut plane, the air bending.
	shockwave(flat, 1.6, random:NextNumber(9, 11), 0.32, 0.6, RIFT_GLOW)
	shockwave(flat, 1.2, random:NextNumber(13, 16), 0.6, 1.2, RIFT_GREEN)
	local warp = disc("RiftWarp", RIFT_GLOW, 0)
	warp.Material = Enum.Material.ForceField
	warp.CFrame = flat
	warp.Size = Vector3.new(3, 3, 0.05)
	warp.Parent = workspace
	fade(warp, 0.45, { Size = Vector3.new(19, 19, 0.05) })
	-- Sparks and mist sprayed sideways, flat along the plane: the emitters
	-- shoot along the point's Y, turned to lie flat and round the circle.
	local sparks = emitter(point, {
		Name = "Spray",
		Color = ColorSequence.new(HOT, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Squash = NumberSequence.new(1.6),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Lifetime = NumberRange.new(0.25, 0.6),
		Speed = NumberRange.new(22, 44),
		SpreadAngle = Vector2.new(6, 6),
		Drag = 5,
		Acceleration = Vector3.new(0, -22, 0),
		EmissionDirection = Enum.NormalId.Top,
	})
	sparkTexture(sparks)
	local mist = emitter(point, {
		Name = "Mist",
		Color = ColorSequence.new(RIFT_GLOW, FUME),
		LightEmission = 0.4,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 3),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(7, 12),
		SpreadAngle = Vector2.new(8, 8),
		Drag = 3.5,
		Rotation = NumberRange.new(0, 360),
		EmissionDirection = Enum.NormalId.Top,
	})
	local start = random:NextNumber(0, TAU)
	local steps = 26
	for i = 1, steps do
		local angle = start + i / steps * TAU + random:NextNumber(-0.08, 0.08)
		-- (Y laid flat (onto X), then turned round the vertical)
		point.WorldCFrame = CFrame.new(position)
			* CFrame.Angles(0, angle, 0)
			* CFrame.Angles(0, 0, -math.pi / 2)
		sparks:Emit(random:NextInteger(1, 3))
		if i % 2 == 0 then
			mist:Emit(1)
		end
	end
	-- What hangs after: motes hanging in the air, a green glow dying.
	local motes = emitter(point, {
		Name = "Motes",
		Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.1, 0),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(0.5, 2.5),
		Drag = 1.5,
		Acceleration = Vector3.new(0, 0.8, 0),
		RotSpeed = NumberRange.new(-120, 120),
	})
	sparkTexture(motes)
	motes:Emit(random:NextInteger(14, 20))
	local ember = Instance.new("PointLight")
	ember.Color = RIFT_GREEN
	ember.Brightness = 0
	ember.Range = 9
	ember.Parent = point
	tween(ember, 0.4, { Brightness = 2.2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.3)
	tween(ember, 1.6, { Brightness = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.7)
	Debris:AddItem(point, 2.6)
	-- Embers and smoke rising off the cut: the legs' tops (they stand, then
	-- fold), under the torso (it falls back).
	smoulder(victim:FindFirstChild("Right Leg"), CFrame.new(0, 0.95, 0), 2.4)
	smoulder(victim:FindFirstChild("Left Leg"), CFrame.new(0, 0.95, 0), 2.4)
	smoulder(victim:FindFirstChild("Torso"), CFrame.new(0, -0.95, 0), 2)
end

function RiftFx.cinematic(kind: string, attacker: Model, victim: Model, anchor: CFrame)
	local at = anchor * Finishers.PORTAL_RING
	-- Flat round their waist, its face up.
	local flat = CFrame.lookAt(at.Position, at.Position + Vector3.new(0, 1, 0))
	if kind == "Lift" then
		local cut = newCut(attacker, victim, anchor)
		chargeGlove(attacker, 0.9)
		SoundController.play("GloveBlast", attacker)
		lift(cut, attacker, victim, anchor)
	elseif kind == "Aim" then
		holdProp(attacker, "Portal", 3.4)
	elseif kind == "PortalOpen" then
		local cut = cutOf(attacker, victim, anchor)
		local from = muzzleOf(attacker)
		if from then
			bolt(from, at.Position)
		end
		local prop = props[attacker]
		flareGun(if prop then prop.folder else nil)
		local diameter = Finishers.PORTAL_RADIUS * 2
		local ring = RiftPortal.portal(flat, diameter, diameter, 0.3, -1, 0)
		cut.ring = ring
		-- (never left open if the cut doesn't come: someone left)
		task.delay(2, function()
			if ring.folder.Parent then
				ring.folder:Destroy()
			end
			if cut.ring == ring then
				cut.ring = nil
			end
		end)
		task.delay(0.22, function()
			if not cut.done then
				openRing(cut, at, flat)
			end
		end)
		shakeNear(at.Position, 1.2, 0.2)
		SoundController.play("PortalShot", attacker)
		task.delay(0.1, function()
			SoundController.playAt("PortalOpen", at.Position)
		end)
	elseif kind == "PortalClose" then
		-- It snaps shut, fast, round the waist.
		local cut = cutOf(attacker, victim, anchor)
		local ring = cut.ring
		if ring then
			local close = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			for _, part in ring.parts do
				TweenService:Create(part, close, { Size = Vector3.new(0.05, 0.05, 0.06) }):Play()
			end
			TweenService:Create(ring.light, close, { Brightness = 6 }):Play()
		end
		closeRing(cut, at)
		SoundController.playAt("PortalClose", at.Position)
	elseif kind == "Cut" then
		local cut = cuts[attacker]
		cuts[attacker] = nil
		if cut then
			if cut.rich then
				cutBlast(cut, at, flat, victim)
			end
			endCut(cut)
		end
		flash(at.Position, 1.8)
		-- A hard jolt, then a rumble.
		shakeNear(at.Position, 5.5, 0.14)
		task.delay(0.13, function()
			shakeNear(at.Position, 2.6, 0.45)
		end)
		SoundController.play("BodyCut", victim)
	end
end

function RiftFx.cancelCinematic(attacker: Model)
	local cut = cuts[attacker]
	cuts[attacker] = nil
	removeProp(attacker)
	if cut then
		endCut(cut)
	end
end

RiftFx.onHit = RiftGlove.onHit
RiftFx.onAwaken = RiftGlove.onAwaken

return table.freeze(RiftFx)
