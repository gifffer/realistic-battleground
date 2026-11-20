--!strict
-- PyroFx: how the Pyromaniac's fire looks and sounds (Shared/Kits/Pyromaniac).
-- Look only: the server decided every hit and every burn (Combat/Gadgets).
--   * his flamethrower (Combat/Flamethrower: slung on his back, drawn,
--     pilot, trigger, valves, gauge, heat), on the clips' beats
--     (PyroFx.onAction, called by KitEffects; Animation/PyroClips). Every
--     jet leaves its muzzle and each move has its own shape: a fireball
--     that POPS (Flash Burst), a glob of napalm (Napalm Lob / Mortar, with a
--     crown of burning drips), a sweeping stream (Flame Stream), a cold fan
--     of raw fuel with the pilot out (Fuel Spray); Awakened, a blue-white
--     root on every jet: a lance (Blowtorch), a pillar (the activation), an
--     inferno that rakes the floor, a bow wave ahead of a charge.
--   * Remotes.PyroFx (Gadgets): the globs flying and splatting (a fireball
--     that pops at full size), the fire pools (one small fire per server
--     cell, catching outward and dying out one by one; thick black smoke -
--     petrol burns sooty -, embers, one flickering light, a black scorch
--     that stays), the cones (the streams; they let go of the muzzle as
--     soon as he is stunned, knocked down or starts something else).
--   * on every fighter: soaked in fuel (drips), his burning forearms in his
--     Awakening, the finisher's burning body's roar (and its corpse's).
--   * the finisher "Immolate" (Shared/Finishers), from FinisherStarted: raw
--     fuel poured from the muzzle, the Zippo to the pilot burner, a
--     point-blank full-bore stream, the gun cherry red, the vent.
-- The burns themselves (degrees on the skin, charred clothes, flames on the
-- body, smoke, smouldering): Client/Combat/Burns, from the server's burn
-- attributes, like every other burn in the game.
-- Every flame is built from Combat/FireLook's layers (looping flame
-- clusters, tongues, core glow, soot, embers, fireballs, a burning film on
-- the floor). Sounds: layered cues (Shared/SoundCues, Combat/SoundLayers),
-- each timed to the same beat as its effect (docs/SONS_PYROMANE_FR.md).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Finishers = require(ReplicatedStorage.Shared.Finishers)
local PyroConfig = require(ReplicatedStorage.Shared.PyroConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local FireLook = require(script.Parent.FireLook)
local Flamethrower = require(script.Parent.Flamethrower)
local SoundLayers = require(script.Parent.SoundLayers)

local PyroFx = {}

local random = Random.new()

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

-- Petrol burns yellow-orange with a sooty tip, never blue; its smoke is
-- thick and near black, greying as it thins out.
local FLAME_CORE = Color3.fromRGB(255, 226, 160)
local FLAME = Color3.fromRGB(255, 146, 44)
local FLAME_DEEP = Color3.fromRGB(196, 58, 14)
local SOOT = Color3.fromRGB(26, 23, 21)
local SOOT_THIN = Color3.fromRGB(78, 73, 68)
local PETROL = Color3.fromRGB(196, 168, 96)
local SCORCH = Color3.fromRGB(20, 17, 15)
-- Blue only in two places: the propane pilot light, and the overpressure
-- root of an Awakened jet (and the finisher's) - then petrol orange.
local BLUE_CORE = Color3.fromRGB(200, 225, 255)
local BLUE_WARM = Color3.fromRGB(255, 240, 210)
local FUEL_MIST = Color3.fromRGB(210, 196, 160)

local LIGHT_COLOR = Color3.fromRGB(255, 150, 70)
local POOL_LIGHT = Color3.fromRGB(255, 140, 60)

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local effects: Folder? = nil
local function effectsFolder(): Folder
	local current = effects
	if current and current.Parent == workspace then
		return current
	end
	local folder = Instance.new("Folder")
	folder.Name = "PyroFx"
	folder.Parent = workspace
	effects = folder
	return folder
end

local function numbers(times: { number }, values: { number }): NumberSequence
	local points = {}
	for index, time in times do
		table.insert(points, NumberSequenceKeypoint.new(time, values[index]))
	end
	return NumberSequence.new(points)
end

local function colors(times: { number }, values: { Color3 }): ColorSequence
	local points = {}
	for index, time in times do
		table.insert(points, ColorSequenceKeypoint.new(time, values[index]))
	end
	return ColorSequence.new(points)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

-- A part that is only a look: no physics, no queries.
local function part(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weld(to: BasePart, p: BasePart, offset: CFrame): Weld
	p.CFrame = to.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = to
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	return w
end

-- (a cylinder's axis is its X: turned to Y)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function anchorAt(position: Vector3, look: Vector3?): Attachment
	local a = Instance.new("Attachment")
	a.WorldCFrame = if look and look.Magnitude > 1e-3
		then CFrame.lookAt(position, position + look)
		else CFrame.new(position)
	a.Parent = workspace.Terrain
	return a
end

-- Lights that flicker like a flame (one loop for all of them).
-- (`rise`: seconds it takes to come up, as the flame catches)
type Flicker = {
	light: PointLight,
	brightness: number,
	range: number,
	seed: number,
	born: number,
	rise: number,
}
local flickers: { Flicker } = {}
local function flicker(light: PointLight, brightness: number, range: number, rise: number?)
	table.insert(flickers, {
		light = light,
		brightness = brightness,
		range = range,
		seed = random:NextNumber(0, 100),
		born = os.clock(),
		rise = rise or 0,
	})
end

local function fireLight(
	parent: Instance,
	brightness: number,
	range: number,
	rise: number?
): PointLight
	local light = Instance.new("PointLight")
	light.Color = LIGHT_COLOR
	light.Brightness = if rise and rise > 0 then 0 else brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	flicker(light, brightness, range, rise)
	return light
end

local function flickerOf(light: PointLight): Flicker?
	for _, f in flickers do
		if f.light == light then
			return f
		end
	end
	return nil
end

local function scaled(sequence: NumberSequence, k: number): NumberSequence
	local points = {}
	for _, p in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(points)
end

-- A flame catching: its emitters start small and reach full size in
-- `seconds` (three steps; their particles keep the size they were born at).
local function catch(emitters: { ParticleEmitter }, seconds: number)
	for _, e in emitters do
		local full = e.Size
		e.Size = scaled(full, 0.3)
		task.delay(seconds * 0.5, function()
			if e.Parent then
				e.Size = scaled(full, 0.65)
			end
		end)
		task.delay(seconds, function()
			if e.Parent then
				e.Size = full
			end
		end)
	end
end

-- A spray of hot sparks from an attachment (a flint wheel, an impact).
local function sparks(at: Attachment, count: number, speed: number, spread: number)
	local e = FireLook.layer("spark", at, 1, "PyroSparks")
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(spread, spread)
	e:Emit(count)
	Debris:AddItem(e, 0.6)
end

-- A flash that pops on and dies (the contact frame).
local function flash(position: Vector3, brightness: number, range: number, seconds: number)
	local a = anchorAt(position)
	local light = Instance.new("PointLight")
	light.Color = FLAME_CORE
	light.Brightness = brightness
	light.Range = range
	light.Parent = a
	TweenService:Create(
		light,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	):Play()
	Debris:AddItem(a, seconds + 0.1)
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function bodyPart(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

------------------------------------------------------------------------------
-- Flames (shared looks)
------------------------------------------------------------------------------

-- A small steady flame (the Zippo's wick, a burning drip): a looping
-- flame cluster with tongues licking off it, a thin wisp of soot. Its
-- particles stay where they were born (LockedToPart off): a moving hand
-- leaves a smear of flame. It catches (grows to full size in `grow` s).
type SmallFlame = { flames: { ParticleEmitter }, smoke: ParticleEmitter }
local function smallFlame(at: Attachment, size: number, grow: number?): SmallFlame
	local q = FireLook.quality()
	local body = FireLook.layer("body", at, size * 1.3, "PyroSmallFlame")
	body.Lifetime = NumberRange.new(0.25, 0.4)
	body.SpreadAngle = Vector2.new(6, 6)
	body.Rate = 16 * q
	local tongue = FireLook.layer("tongue", at, size * 1.1, "PyroSmallFlame")
	tongue.Lifetime = NumberRange.new(0.2, 0.32)
	tongue.Rate = 9 * q
	local smoke = FireLook.layer("smoke", at, size * 0.45, "PyroSmallSmoke")
	smoke.Color = ColorSequence.new(SOOT, SOOT_THIN)
	smoke.Transparency = numbers({ 0, 0.3, 1 }, { 0.9, 0.72, 1 })
	smoke.Lifetime = NumberRange.new(0.6, 1)
	smoke.Speed = NumberRange.new(0.5, 1)
	smoke.Rate = 5 * q
	smoke.ZOffset = -0.2
	local flames = { body, tongue }
	if grow and grow > 0 then
		catch(flames, grow)
	end
	return { flames = flames, smoke = smoke }
end

-- Out: the flame snuffs, a last wisp of smoke rises.
local function snuff(flame: SmallFlame)
	for _, e in flame.flames do
		e.Enabled = false
		Debris:AddItem(e, 0.5)
	end
	flame.smoke.Rate = 0
	flame.smoke:Emit(2)
	Debris:AddItem(flame.smoke, 1.2)
end

------------------------------------------------------------------------------
-- Props
------------------------------------------------------------------------------

type Zippo = {
	main: BasePart,
	lid: Weld,
	wick: Attachment,
	setOpen: (open: boolean) -> (),
	setLit: (lit: boolean) -> (),
}

-- Case 0.14 × 0.2 × 0.05 studs (a Zippo 38 × 57 × 13 mm, ×1.3), origin at
-- the bottom half's centre, +Y up to the lid.
local ZIPPO_CHROME = Color3.fromRGB(176, 172, 164)
local LID_CLOSED = CFrame.new(0, 0.1, 0)
local HINGE = CFrame.new(-0.07, 0.07, 0)
local function buildZippo(folder: Instance, holder: BasePart, grip: CFrame): Zippo
	local case = part("ZippoCase", Vector3.new(0.14, 0.14, 0.05), ZIPPO_CHROME, Enum.Material.Metal)
	case.Reflectance = 0.15
	weld(holder, case, grip)
	case.Parent = folder
	local chimney =
		part("ZippoChimney", Vector3.new(0.1, 0.08, 0.04), ZIPPO_CHROME, Enum.Material.DiamondPlate)
	weld(case, chimney, CFrame.new(0.01, 0.11, 0))
	chimney.Parent = folder
	local wheel = part(
		"ZippoWheel",
		Vector3.new(0.025, 0.035, 0.035),
		Color3.fromRGB(90, 88, 84),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	weld(case, wheel, CFrame.new(-0.035, 0.155, 0))
	wheel.Parent = folder
	local lid = part("ZippoLid", Vector3.new(0.14, 0.06, 0.05), ZIPPO_CHROME, Enum.Material.Metal)
	lid.Reflectance = 0.15
	local lidWeld = weld(case, lid, LID_CLOSED)
	lid.Parent = folder
	local wick = Instance.new("Attachment")
	wick.Name = "Wick"
	wick.Position = Vector3.new(0.01, 0.17, 0)
	wick.Parent = case
	local lit: SmallFlame? = nil
	local light: PointLight? = nil
	local zippo: Zippo
	zippo = {
		main = case,
		lid = lidWeld,
		wick = wick,
		setOpen = function(open: boolean)
			-- (turned about the hinge at the back edge)
			lidWeld.C0 = if open
				then HINGE * CFrame.Angles(0, 0, math.rad(115)) * HINGE:Inverse() * LID_CLOSED
				else LID_CLOSED
		end,
		-- Struck: sparks off the wheel, the wick catches (full in 0.08 s).
		-- Out: snuffed, a wisp of smoke.
		setLit = function(on: boolean)
			if on and lit == nil then
				sparks(wick, 8, 8, 30)
				lit = smallFlame(wick, 0.12, 0.08)
				light = fireLight(wick, 1.1, 6, 0.1)
			elseif not on then
				if lit then
					snuff(lit)
					lit = nil
				end
				if light then
					light:Destroy()
					light = nil
				end
			end
		end,
	}
	return zippo
end

-- (the Zippo in the hand: its +Y along the arm's -Z, upright when the arm
-- points forward; the hand at Y = -1)
local HAND_UPRIGHT = CFrame.new(0, -1.1, -0.12) * CFrame.Angles(math.rad(-90), 0, 0)

-- One move playing on a model (its props, its beats).
type Run = { token: number, folder: Folder, zippo: Zippo? }
local runs: { [Model]: Run } = setmetatable({}, { __mode = "k" }) :: any
local runToken = 0

------------------------------------------------------------------------------
-- The jets (shared looks): every one leaves the gun's muzzle
------------------------------------------------------------------------------

-- The gun's muzzle (LookVector = where the jet goes), or a stand-in in
-- front of his chest while the gun isn't built yet.
local function muzzleOf(model: Model): Attachment?
	local at = Flamethrower.muzzle(model)
	if at then
		return at
	end
	local head = bodyPart(model, "Head")
	if head == nil then
		return nil
	end
	local stand = head:FindFirstChild("PyroMuzzle")
	if stand and stand:IsA("Attachment") then
		return stand
	end
	local made = Instance.new("Attachment")
	made.Name = "PyroMuzzle"
	made.Position = Vector3.new(0.4, -1.4, -2.2)
	made.Parent = head
	return made
end

-- An attachment `ahead` studs down the jet, riding with the gun.
local function along(muzzle: Attachment, ahead: number, name: string): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = muzzle.CFrame * CFrame.new(0, 0, -ahead)
	a.Parent = muzzle.Parent
	return a
end

local function isAwake(model: Model): boolean
	return model:GetAttribute("Awakened") == true
end

-- Cut short: stunned, knocked down, dead.
local function cutShort(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return model:GetAttribute("Stunned") == true
		or model:GetAttribute("Ragdolled") == true
		or (humanoid ~= nil and humanoid.Health <= 0)
end

-- A beam of flame from `a0` to `a1` (the flame band texture scrolling).
local function flameBeam(
	a0: Attachment,
	a1: Attachment,
	width0: number,
	width1: number,
	colour: ColorSequence
): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = FireLook.image("flameStrip") or ""
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 3
	b.TextureSpeed = 5
	b.FaceCamera = true
	b.Segments = 12
	b.Width0 = width0
	b.Width1 = width1
	b.LightEmission = 1
	b.Brightness = 3
	b.LightInfluence = 0
	b.Color = colour
	b.Transparency = numbers({ 0, 0.6, 1 }, { 0.15, 0.4, 1 })
	b.Parent = a1
	return b
end

-- The overpressure root of an Awakened jet (and of the finisher's): its
-- first studs burn blue-white before turning petrol orange. Off after
-- `seconds` (or by the returned stop).
local function blueRoot(
	muzzle: Attachment,
	length: number,
	width: number,
	seconds: number
): () -> ()
	local tip = along(muzzle, length, "PyroBlueTip")
	local beam =
		flameBeam(muzzle, tip, width * 0.45, width, ColorSequence.new(BLUE_CORE, BLUE_WARM))
	beam.Brightness = 5
	beam.Transparency = numbers({ 0, 0.7, 1 }, { 0.05, 0.3, 0.9 })
	local glow = FireLook.layer("glow", muzzle, 0.45, "PyroBlueGlow")
	glow.Color = ColorSequence.new(BLUE_CORE)
	glow.EmissionDirection = Enum.NormalId.Front
	glow.Speed = NumberRange.new(length * 6, length * 8)
	glow.Lifetime = NumberRange.new(0.05, 0.08)
	glow.Rate = 40 * FireLook.quality()
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		glow.Enabled = false
		Debris:AddItem(glow, 0.3)
		TweenService:Create(beam, TweenInfo.new(0.08), { Width0 = 0, Width1 = 0 }):Play()
		Debris:AddItem(tip, 0.1)
	end
	task.delay(seconds, stop)
	return stop
end

-- Fuel drooling from the slash-cut tip (`burning`: the pilot licks it:
-- small burning drops). A few for `seconds`.
local function drool(muzzle: Attachment, seconds: number, burning: boolean)
	local e = FireLook.layer("spark", muzzle, if burning then 1.2 else 0.9, "PyroDrool")
	e.Color = if burning
		then colors({ 0, 0.5, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP })
		else ColorSequence.new(PETROL)
	e.LightEmission = if burning then 0.8 else 0.1
	e.Size = numbers({ 0, 1 }, { 0.08, 0.04 })
	e.Speed = NumberRange.new(0.2, 0.8)
	e.SpreadAngle = Vector2.new(20, 20)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Rate = 22
	task.delay(seconds, function()
		e.Enabled = false
		Debris:AddItem(e, 0.7)
	end)
end

-- A short lick of flame out of the tip and soot (after a burst, a
-- sputter), and smoke puffing out of the shroud's holes.
local function lick(model: Model, muzzle: Attachment, size: number, seconds: number)
	local tongue = FireLook.layer("tongue", muzzle, size, "PyroLick")
	tongue.EmissionDirection = Enum.NormalId.Front
	tongue.Speed = NumberRange.new(1, 3)
	tongue.Acceleration = Vector3.new(0, 6, 0)
	tongue.Rate = 26 * FireLook.quality()
	local soot = FireLook.layer("smoke", muzzle, size * 0.5, "PyroLickSmoke")
	soot.Color = ColorSequence.new(SOOT, SOOT_THIN)
	soot.Speed = NumberRange.new(1, 2)
	soot.Acceleration = Vector3.new(0, 4, 0)
	soot.Lifetime = NumberRange.new(0.8, 1.3)
	soot.Rate = 10 * FireLook.quality()
	task.delay(seconds, function()
		tongue.Enabled = false
		soot.Enabled = false
		Debris:AddItem(tongue, 0.6)
		Debris:AddItem(soot, 1.5)
	end)
	Flamethrower.trigger(model, false)
end

-- Tongues of flame spitting out of the shroud's drilled holes (Awakened
-- overpressure), for `seconds`.
local function shroudSpit(model: Model, seconds: number)
	local core = Flamethrower.point(model, "ShroudGlow")
	if core == nil then
		return
	end
	local spit = FireLook.layer("tongue", core, 0.35, "PyroShroudSpit")
	spit.SpreadAngle = Vector2.new(180, 180)
	spit.Speed = NumberRange.new(1.5, 3)
	spit.Lifetime = NumberRange.new(0.12, 0.2)
	spit.Rate = 40 * FireLook.quality()
	task.delay(seconds, function()
		spit.Enabled = false
		Debris:AddItem(spit, 0.4)
	end)
end

------------------------------------------------------------------------------
-- Sustained jets: the stream, the inferno, the charge's wedge, the
-- finisher's full bore
------------------------------------------------------------------------------

type JetLook = {
	range: number, -- studs the stream reaches
	width: number, -- at its far end
	rate: number, -- flame clusters per second
	billow: number, -- the rolling fireball at its far end (size)
	soot: number, -- soot plume over the far half (rate)
	light: number,
	blue: boolean, -- the overpressure root
	rake: number?, -- seconds in: the muzzle pitches down, the end licks the floor
	low: boolean?, -- a short low stream splashing off the floor (the charge)
}

type Jet = { stop: (fast: boolean?) -> (), model: Model }
local jets: { [Model]: Jet } = setmetatable({}, { __mode = "k" }) :: any

-- Where the jet's axis meets the floor (a ray down its length), or nil.
local function floorHit(muzzle: Attachment, range: number, ignore: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local from = muzzle.WorldPosition
	local hit = workspace:Raycast(from, muzzle.WorldCFrame.LookVector * range, params)
	if hit and hit.Normal.Y > 0.6 then
		return hit.Position
	end
	return nil
end

-- Flames licking along the floor where a jet splashes (look only; the
-- server's pool, if any, does the burning).
local function groundLick(at: Vector3, size: number, seconds: number)
	local spot = anchorAt(at + Vector3.new(0, 0.1, 0), Vector3.new(0, 1, 0))
	local ground = FireLook.layer("ground", spot, size, "PyroGroundLick")
	ground.Rate = 10 * FireLook.quality()
	local tongues = FireLook.layer("tongue", spot, size * 0.8, "PyroGroundLick")
	tongues.SpreadAngle = Vector2.new(70, 70)
	tongues.Speed = NumberRange.new(2, 5)
	tongues.Rate = 18 * FireLook.quality()
	task.delay(seconds, function()
		ground.Enabled = false
		tongues.Enabled = false
	end)
	Debris:AddItem(spot, seconds + 1.5)
end

-- A stream of fire out of the muzzle for `seconds`: a continuous core that
-- REACHES out (0.09 s, it extends, it isn't an impact), flame clusters
-- thrown down it that brake and curl up into a rolling billow at its far
-- end, black soot over its far half, the light inside it. It lets go of
-- the muzzle at the end (the tail flies on, thins) or at once when he is
-- stunned, knocked down, killed or starts something else.
local function startJet(model: Model, look: JetLook, seconds: number): Jet?
	local muzzle = muzzleOf(model)
	if muzzle == nil then
		return nil
	end
	local old = jets[model]
	if old then
		old.stop(true)
	end
	local run = runs[model]
	local q = FireLook.quality()
	local range = look.range
	Flamethrower.trigger(model, true)
	-- The start: a puff of fire at the muzzle.
	local puff = FireLook.layer("fireball", muzzle, 0.9, "PyroJetPuff")
	puff.EmissionDirection = Enum.NormalId.Front
	puff.Speed = NumberRange.new(range * 0.4, range * 0.6)
	puff.SpreadAngle = Vector2.new(20, 20)
	puff.Lifetime = NumberRange.new(0.3, 0.45)
	puff:Emit(2)
	Debris:AddItem(puff, 1)
	-- The core, reaching out.
	local tip = along(muzzle, 0.3, "PyroJetTip")
	local core = flameBeam(
		muzzle,
		tip,
		0.25,
		look.width,
		ColorSequence.new(Color3.fromRGB(255, 244, 226), Color3.fromRGB(255, 170, 100))
	)
	core.TextureLength = range * 0.35
	local reach = if look.low then range * 0.55 else range * 0.72
	TweenService
		:Create(tip, TweenInfo.new(0.09), { CFrame = muzzle.CFrame * CFrame.new(0, 0, -reach) })
		:Play()
	-- Flame clusters thrown down it: they brake, sag, curl up.
	local body = FireLook.layer("body", muzzle, 1, "PyroJetBody")
	body.Orientation = Enum.ParticleOrientation.FacingCamera
	body.EmissionDirection = Enum.NormalId.Front
	body.Size = numbers({ 0, 0.25, 1 }, { 0.35, look.width * 0.55, look.width * 1.1 })
	body.Transparency = numbers({ 0, 0.1, 0.75, 1 }, { 0.55, 0.1, 0.45, 1 })
	body.Lifetime = NumberRange.new(0.36, 0.5)
	body.Speed = NumberRange.new(range * 2.2, range * 2.8)
	body.Drag = 2.5
	body.Acceleration = Vector3.new(0, if look.low then 4 else 10, 0)
	body.SpreadAngle = Vector2.new(if look.low then 18 else 6, if look.low then 10 else 5)
	body.Rotation = NumberRange.new(0, 360)
	body.RotSpeed = NumberRange.new(-90, 90)
	body.Rate = look.rate * q
	-- Soot over the far half, the light inside the stream.
	local mid = along(muzzle, range * 0.5, "PyroJetMid")
	local soot = FireLook.layer("smoke", mid, 0.8, "PyroJetSoot")
	soot.Color = ColorSequence.new(SOOT, SOOT_THIN)
	soot.EmissionDirection = Enum.NormalId.Top
	soot.Speed = NumberRange.new(2, 4)
	soot.Lifetime = NumberRange.new(1.2, 1.9)
	soot.Acceleration = Vector3.new(0, 3, 0)
	soot.SpreadAngle = Vector2.new(40, 40)
	soot.Rate = look.soot * q
	local lightAt = along(muzzle, range * 0.4, "PyroJetLight")
	local light = fireLight(lightAt, look.light, range, 0.06)
	local stopBlue = if look.blue then blueRoot(muzzle, 2, 0.7, seconds + 0.1) else nil
	-- The billow at the far end (a fireball every ~0.12 s).
	local billow = FireLook.layer("fireball", tip, look.billow, "PyroJetBillow")
	billow.Speed = NumberRange.new(1, 3)
	billow.SpreadAngle = Vector2.new(50, 50)
	billow.Acceleration = Vector3.new(0, 7, 0)
	billow.Lifetime = NumberRange.new(0.5, 0.8)
	local started = os.clock()
	local nextBillow = started + 0.09
	local nextLick = started + 0.15
	local jet: Jet
	local connection: RBXScriptConnection? = nil
	local done = false
	local function stop(fast: boolean?)
		if done then
			return
		end
		done = true
		if jets[model] == jet then
			jets[model] = nil
		end
		if connection then
			connection:Disconnect()
		end
		body.Enabled = false
		soot.Enabled = false
		light:Destroy()
		if stopBlue then
			stopBlue()
		end
		Debris:AddItem(body, 0.7)
		Debris:AddItem(mid, 2)
		Debris:AddItem(lightAt, 0.1)
		Debris:AddItem(billow, 1)
		-- It lets go of the muzzle: the tail flies on and thins.
		local tail = muzzle.CFrame * CFrame.new(0, 0.4, -range * 0.95)
		TweenService:Create(
			core,
			TweenInfo.new(if fast then 0.08 else 0.15),
			{ Width0 = 0, Width1 = look.width * 0.3 }
		):Play()
		TweenService:Create(tip, TweenInfo.new(if fast then 0.08 else 0.15), { CFrame = tail })
			:Play()
		Debris:AddItem(tip, 0.18)
		if not fast then
			lick(model, muzzle, 0.6, 0.2)
		else
			Flamethrower.trigger(model, false)
		end
	end
	jet = { stop = stop, model = model }
	jets[model] = jet
	connection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if cutShort(model) or muzzle.Parent == nil or (run ~= nil and runs[model] ~= run) then
			stop(true)
			return
		end
		if now >= nextBillow then
			nextBillow = now + 0.12
			billow:Emit(1)
		end
		-- Licking along the floor: the charge's bow wave, the inferno's rake.
		local raking = look.low or (look.rake ~= nil and now - started >= look.rake)
		if raking and now >= nextLick then
			nextLick = now + 0.1
			local at = floorHit(muzzle, range, { model, effectsFolder() })
			if at then
				groundLick(at, if look.low then 1.4 else 1.8, 0.35)
			end
		end
	end)
	task.delay(seconds, function()
		stop(false)
	end)
	return jet
end

local function stopJet(model: Model)
	local jet = jets[model]
	if jet then
		jet.stop(true)
	end
end

------------------------------------------------------------------------------
-- One-shot jets: the burst, the lance, the pillar, the spray
------------------------------------------------------------------------------

-- FLASH BURST: a petrol slug streaks out (0.40), then a round pressurised
-- fireball POPS full size 3-5 studs ahead (0.42): a glow core, a ring of
-- sparks, a flash; it rolls forward with drag and turns to soot.
local function slug(muzzle: Attachment)
	local stream = FireLook.layer("spark", muzzle, 1.4, "PyroSlug")
	stream.Color = ColorSequence.new(PETROL, FLAME)
	stream.LightEmission = 0.5
	stream.Brightness = 1.5
	stream.Speed = NumberRange.new(18, 22)
	stream.Lifetime = NumberRange.new(0.06, 0.09)
	stream.Acceleration = Vector3.zero
	stream.SpreadAngle = Vector2.new(3, 3)
	stream.EmissionDirection = Enum.NormalId.Front
	stream:Emit(10)
	Debris:AddItem(stream, 0.5)
end

local function burstPop(model: Model, muzzle: Attachment)
	local look = muzzle.WorldCFrame.LookVector
	local centre = muzzle.WorldPosition + look * 4
	local at = anchorAt(centre, look)
	local q = FireLook.quality()
	if FireLook.has("fireball") then
		local ball = FireLook.layer("fireball", at, 2.4, "PyroBurst")
		ball.EmissionDirection = Enum.NormalId.Front
		ball.Speed = NumberRange.new(8, 12)
		ball.Drag = 5
		ball.SpreadAngle = Vector2.new(30, 30)
		ball.Lifetime = NumberRange.new(0.4, 0.6)
		ball.Size = numbers({ 0, 1 }, { 3.6, 4.4 })
		ball:Emit(math.floor(3 + 2 * q))
	else
		local burst = emitter(at, {
			Texture = FIRE_TEXTURE,
			Color = colors({ 0, 0.3, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP }),
			LightEmission = 0.8,
			Size = numbers({ 0, 0.2, 1 }, { 2.4, 2.8, 0.6 }),
			Transparency = numbers({ 0, 0.6, 1 }, { 0.1, 0.3, 1 }),
			Lifetime = NumberRange.new(0.3, 0.5),
			Speed = NumberRange.new(8, 12),
			Drag = 4,
			SpreadAngle = Vector2.new(40, 40),
			EmissionDirection = Enum.NormalId.Front,
			Rotation = NumberRange.new(0, 360),
			Rate = 0,
		})
		burst:Emit(22)
	end
	local core = FireLook.layer("glow", at, 2.2, "PyroBurstCore")
	core.Lifetime = NumberRange.new(0.1, 0.14)
	core:Emit(2)
	-- the ring of sparks, radial (4 frames)
	local ring = FireLook.layer("spark", at, 1.3, "PyroBurstRing")
	ring.SpreadAngle = Vector2.new(180, 180)
	ring.Speed = NumberRange.new(14, 22)
	ring.Lifetime = NumberRange.new(0.06, 0.1)
	ring:Emit(10)
	local embers = FireLook.layer("ember", at, 1, "PyroBurstEmbers")
	embers.EmissionDirection = Enum.NormalId.Front
	embers.Speed = NumberRange.new(5, 11)
	embers.Lifetime = NumberRange.new(0.5, 1.1)
	embers:Emit(math.floor(10 * q))
	flash(centre, 3, 14, 0.25)
	task.delay(0.18, function()
		local soot = FireLook.layer("smoke", at, 0.6, "PyroBurstSmoke")
		soot.EmissionDirection = Enum.NormalId.Front
		soot.Speed = NumberRange.new(3, 6)
		soot.Acceleration = Vector3.new(0, 4, 0)
		soot.Lifetime = NumberRange.new(1, 1.6)
		soot:Emit(4)
	end)
	Debris:AddItem(at, 2.5)
	Flamethrower.trigger(model, true)
end

-- BLOWTORCH: a short hard lance (3 studs), blue-white core with an orange
-- fringe, molten slag sparks; it snaps off with a puff. Returns its stop.
local function lance(model: Model, seconds: number): (() -> ())?
	local muzzle = muzzleOf(model)
	if muzzle == nil then
		return nil
	end
	Flamethrower.trigger(model, true)
	local tip = along(muzzle, 3, "PyroLanceTip")
	local fringe = flameBeam(muzzle, tip, 0.5, 0.35, ColorSequence.new(FLAME_CORE, FLAME))
	fringe.Transparency = numbers({ 0, 0.8, 1 }, { 0.3, 0.5, 1 })
	local stopBlue = blueRoot(muzzle, 2.4, 0.3, seconds)
	local slag = FireLook.layer("spark", tip, 1, "PyroSlag")
	slag.Color = colors({ 0, 0.4, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP })
	slag.SpreadAngle = Vector2.new(35, 35)
	slag.EmissionDirection = Enum.NormalId.Front
	slag.Speed = NumberRange.new(6, 12)
	slag.Acceleration = Vector3.new(0, -40, 0)
	slag.Lifetime = NumberRange.new(0.2, 0.4)
	slag.Rate = 45 * FireLook.quality()
	local glowAt = along(muzzle, 1.5, "PyroLanceLight")
	local light = Instance.new("PointLight")
	light.Color = BLUE_CORE
	light.Brightness = 2.5
	light.Range = 8
	light.Parent = glowAt
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		stopBlue()
		slag.Enabled = false
		light:Destroy()
		TweenService:Create(fringe, TweenInfo.new(0.06), { Width0 = 0, Width1 = 0 }):Play()
		Debris:AddItem(tip, 0.6)
		Debris:AddItem(glowAt, 0.1)
		local puff = FireLook.layer("smoke", muzzle, 0.4, "PyroLancePuff")
		puff.EmissionDirection = Enum.NormalId.Front
		puff.Speed = NumberRange.new(1, 2)
		puff:Emit(2)
		Debris:AddItem(puff, 1.5)
		Flamethrower.trigger(model, false)
	end
	task.delay(seconds, stop)
	return stop
end

-- The AWAKENING's pillar: the gun pointed at the sky, a column of fire
-- ~10 studs, blue-white at its root, a flash; dark smoke rising slowly.
local function pillar(model: Model, seconds: number)
	local muzzle = muzzleOf(model)
	if muzzle == nil then
		return
	end
	Flamethrower.trigger(model, true)
	local tip = along(muzzle, 0.5, "PyroPillarTip")
	local core = flameBeam(muzzle, tip, 0.4, 2.6, ColorSequence.new(FLAME_CORE, FLAME))
	core.TextureLength = 4
	TweenService
		:Create(tip, TweenInfo.new(0.08), { CFrame = muzzle.CFrame * CFrame.new(0, 0, -10) })
		:Play()
	blueRoot(muzzle, 2, 0.8, seconds)
	local body = FireLook.layer("body", muzzle, 1.3, "PyroPillar")
	body.EmissionDirection = Enum.NormalId.Front
	body.Speed = NumberRange.new(24, 30)
	body.Drag = 2
	body.SpreadAngle = Vector2.new(8, 8)
	body.Lifetime = NumberRange.new(0.35, 0.5)
	body.Rate = 50 * FireLook.quality()
	local billow = FireLook.layer("fireball", tip, 2.4, "PyroPillarTop")
	billow.SpreadAngle = Vector2.new(70, 70)
	billow.Speed = NumberRange.new(1, 3)
	billow:Emit(3)
	flash(muzzle.WorldPosition + Vector3.new(0, 5, 0), 6, 22, 0.3)
	task.delay(seconds, function()
		body.Enabled = false
		Debris:AddItem(body, 0.7)
		TweenService:Create(core, TweenInfo.new(0.15), { Width0 = 0, Width1 = 0.5 }):Play()
		Debris:AddItem(tip, 0.2)
		local smoke = FireLook.layer("smoke", tip, 1.6, "PyroPillarSmoke")
		smoke.Color = ColorSequence.new(SOOT, SOOT_THIN)
		smoke.Speed = NumberRange.new(1, 3)
		smoke.Acceleration = Vector3.new(0, 2, 0)
		smoke.Lifetime = NumberRange.new(2, 3.5)
		smoke:Emit(8)
		Flamethrower.trigger(model, false)
	end)
end

-- A ray down to the floor: past the fighters (and their bodies) and our effects.
local function floorParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { effectsFolder() }
	for _, tag in { Config.Combat.TAG, Config.Combat.CORPSE_TAG } do
		for _, item in CollectionService:GetTagged(tag) do
			table.insert(ignore, item)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

-- A wet dark mark on the floor (raw fuel), fading over `seconds`.
local function wetMark(at: Vector3, size: number, seconds: number)
	local mark = part(
		"PyroFuelMark",
		Vector3.new(size, 0.03, size * 0.7),
		Color3.fromRGB(40, 33, 24),
		Enum.Material.SmoothPlastic
	)
	mark.Anchored = true
	mark.Reflectance = 0.15
	mark.Transparency = 0.35
	mark.CFrame = CFrame.new(at + Vector3.new(0, 0.02, 0))
		* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.05, 1)
	mesh.Parent = mark
	mark.Parent = effectsFolder()
	TweenService:Create(
		mark,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Transparency = 1 }
	):Play()
	Debris:AddItem(mark, seconds + 0.1)
end

-- FUEL SPRAY: a wide flat fan of raw amber fuel out of the muzzle (no
-- flame: the pilot is out) for `seconds`, swept with his torso; heavy drops
-- land as wet marks.
local function spray(model: Model, seconds: number)
	local muzzle = muzzleOf(model)
	if muzzle == nil then
		return
	end
	Flamethrower.trigger(model, true)
	local fuel = emitter(muzzle, {
		Name = "PyroSpray",
		Color = ColorSequence.new(PETROL),
		LightInfluence = 1,
		Size = numbers({ 0, 1 }, { 0.12, 0.07 }),
		Transparency = numbers({ 0, 0.8, 1 }, { 0.25, 0.4, 1 }),
		Lifetime = NumberRange.new(0.4, 0.65),
		Speed = NumberRange.new(16, 24),
		Drag = 0.6,
		Acceleration = Vector3.new(0, -30, 0),
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(30, 6),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = numbers({ 0, 1 }, { 2, 2 }),
		Rate = 260,
	})
	local mist = emitter(muzzle, {
		Name = "PyroSprayMist",
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(FUEL_MIST),
		LightInfluence = 1,
		Size = numbers({ 0, 1 }, { 0.5, 2.4 }),
		Transparency = numbers({ 0, 1 }, { 0.85, 1 }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(8, 12),
		Drag = 2,
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(34, 8),
		Rate = 30,
	})
	-- the heavy drops landing
	for index = 1, 3 do
		task.delay(seconds * index / 4, function()
			if muzzle.Parent == nil then
				return
			end
			local look = muzzle.WorldCFrame.LookVector
			local from = muzzle.WorldPosition + look * random:NextNumber(3, 8)
			local floor =
				workspace:Raycast(from + Vector3.new(0, 2, 0), Vector3.new(0, -9, 0), floorParams())
			if floor and floor.Normal.Y > 0.6 then
				wetMark(floor.Position, random:NextNumber(1, 1.8), 6)
			end
		end)
	end
	task.delay(seconds, function()
		fuel.Enabled = false
		mist.Enabled = false
		Debris:AddItem(fuel, 0.8)
		Debris:AddItem(mist, 1)
		Flamethrower.trigger(model, false)
		if muzzle.Parent then
			drool(muzzle, 0.25, false)
		end
	end)
end

------------------------------------------------------------------------------
-- Moves: the gun drawn, fired, slung, on the clips' beats
------------------------------------------------------------------------------

-- (`cut`: ended early, the gun drawn: fumbled back onto his back)
local function endRun(model: Model, cut: boolean?)
	local run = runs[model]
	runs[model] = nil
	if run then
		run.folder:Destroy()
		if cut and Flamethrower.isDrawn(model) then
			Flamethrower.fumble(model)
			Flamethrower.setGauge(model, nil)
			Flamethrower.setHeat(model, 0)
		end
	end
end

local function newRun(model: Model, seconds: number): Run
	endRun(model, true)
	stopJet(model)
	runToken += 1
	local folder = Instance.new("Folder")
	folder.Name = "PyroProps"
	folder.Parent = model
	local run: Run = { token = runToken, folder = folder }
	runs[model] = run
	local token = run.token
	task.delay(seconds, function()
		local current = runs[model]
		if current and current.token == token then
			endRun(model, true)
		end
	end)
	return run
end

-- `fn` at `at` seconds, if this run is still going (and he isn't cut short).
local function beat(model: Model, run: Run, at: number, fn: () -> ())
	local token = run.token
	task.delay(at, function()
		local current = runs[model]
		if current and current.token == token and model.Parent and not cutShort(model) then
			fn()
		end
	end)
end

local function zippoIn(model: Model, run: Run, armName: string): Zippo?
	local arm = bodyPart(model, armName)
	if arm == nil then
		return nil
	end
	local zippo = buildZippo(run.folder, arm, HAND_UPRIGHT)
	run.zippo = zippo
	return zippo
end

-- The beats every move shares: the hand at the slung grip (`grip`: the
-- gun swung round under the arm, the fuel sloshing), the pilot lit
-- (`pilot`: a click and a blue "fwip"), slung again (`sling`: the pilot out).
local function gunBeats(model: Model, run: Run, grip: number, pilot: number?, sling: number)
	beat(model, run, grip, function()
		Flamethrower.draw(model)
		SoundLayers.play("GunDraw", model)
	end)
	if pilot then
		beat(model, run, pilot, function()
			Flamethrower.setPilot(model, true)
			SoundLayers.play("PilotLight", model)
		end)
	end
	beat(model, run, sling, function()
		Flamethrower.trigger(model, false)
		Flamethrower.setPilot(model, false)
		Flamethrower.setGauge(model, nil)
		Flamethrower.holster(model)
	end)
end

-- The trigger squeezed: the lever and the cable-pulled valve.
local function squeeze(model: Model)
	Flamethrower.trigger(model, true)
	SoundLayers.play("TriggerClick", model)
end

local CLIP_LENGTHS: { [string]: number } = {
	Pyro_Burst = 0.85,
	Pyro_Napalm = 1,
	Pyro_Stream = 1.3,
	Pyro_Spray = 0.95,
	Pyro_Awaken = 1,
	Pyro_Torch = 0.6,
	Pyro_Mortar = 0.8,
	Pyro_Inferno = 1.5,
	Pyro_TorchCharge = 0.9,
}

-- (set below: the burning forearms of his Awakening)
local armsOnAction: (model: Model, animation: string) -> () = function() end
local awakenStarted: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

function PyroFx.onAction(model: Model, animation: string)
	local length = CLIP_LENGTHS[animation]
	if length == nil then
		-- (anything else he does - a punch, a dash - cuts a jet short; not
		-- his finisher's own clips: onFinisherStarted runs those)
		if runs[model] and string.sub(animation, 1, 5) ~= "Pyro_" then
			stopJet(model)
			endRun(model, true)
		end
		return
	end
	if animation == "Pyro_Awaken" then
		awakenStarted[model] = os.clock()
	end
	armsOnAction(model, animation)
	local run = newRun(model, length)
	if animation == "Pyro_Burst" then
		-- FLASH BURST: coil, a spit of fuel, the blip, the pop (0.42), recoil.
		gunBeats(model, run, 0.15, 0.24, 0.68)
		beat(model, run, 0.31, function()
			local muzzle = muzzleOf(model)
			if muzzle then
				drool(muzzle, 0.08, true)
			end
		end)
		beat(model, run, 0.38, function()
			squeeze(model)
			SoundLayers.play("PressureHiss", model)
		end)
		beat(model, run, 0.4, function()
			local muzzle = muzzleOf(model)
			if muzzle then
				slug(muzzle)
			end
		end)
		beat(model, run, 0.42, function()
			local muzzle = muzzleOf(model)
			if muzzle then
				burstPop(model, muzzle)
			end
			SoundLayers.play("BurstPop", model)
		end)
		beat(model, run, 0.52, function()
			local muzzle = muzzleOf(model)
			if muzzle then
				lick(model, muzzle, 0.45, 0.1)
			end
		end)
	elseif animation == "Pyro_Napalm" then
		-- NAPALM LOB: the valve choked (0.33), the pressure builds, burning
		-- drool; snapped open (0.58); the glob coughed out (0.62, the server).
		gunBeats(model, run, 0.15, 0.27, 0.83)
		beat(model, run, 0.33, function()
			Flamethrower.setValve(model, -1)
			Flamethrower.setGauge(model, 0.95)
			SoundLayers.play("ValveCrank", model)
			SoundLayers.play("PressureHiss", model)
			local muzzle = muzzleOf(model)
			if muzzle then
				drool(muzzle, 0.24, true)
			end
		end)
		beat(model, run, 0.58, function()
			Flamethrower.setValve(model, 1)
			SoundLayers.play("ValveCrank", model)
		end)
		beat(model, run, 0.6, function()
			squeeze(model)
		end)
		beat(model, run, 0.62, function()
			Flamethrower.setGauge(model, 0.15)
			SoundLayers.play("GlobLaunch", model)
		end)
		beat(model, run, 0.64, function()
			local muzzle = muzzleOf(model)
			if muzzle then
				lick(model, muzzle, 0.7, 0.15) -- (the tip sputters, smokes)
			end
		end)
	elseif animation == "Pyro_Stream" then
		-- FLAME STREAM: braced, the regulator hiss rising, the trigger
		-- (0.42); the stream itself is the server's cone (0.45 -> 1.0).
		gunBeats(model, run, 0.15, 0.24, 1.12)
		beat(model, run, 0.3, function()
			SoundLayers.play("PressureHiss", model)
		end)
		beat(model, run, 0.42, function()
			squeeze(model)
		end)
	elseif animation == "Pyro_Spray" then
		-- FUEL SPRAY: the pilot shut (0.27), a cold fan of raw fuel
		-- (0.40 -> 0.62), the pilot relit (0.66): "now I light you".
		gunBeats(model, run, 0.15, 0.2, 0.77)
		beat(model, run, 0.27, function()
			Flamethrower.setPilot(model, false)
			SoundLayers.play("PilotOut", model)
		end)
		beat(model, run, 0.4, function()
			spray(model, 0.22)
			SoundLayers.play("FuelSplash", model)
		end)
		beat(model, run, 0.66, function()
			Flamethrower.setPilot(model, true)
			SoundLayers.play("PilotLight", model)
		end)
	elseif animation == "Pyro_Awaken" then
		-- BURNING MAN: the handwheel cranked wide open, the gun to the sky,
		-- the pillar (0.45), the blowback on his forearms (0.55: they catch,
		-- below), down to the hip; the gun runs hot from now on.
		gunBeats(model, run, 0.08, 0.11, 0.83)
		beat(model, run, 0.14, function()
			Flamethrower.crankValve(model, 0.2)
			SoundLayers.play("ValveCrank", model)
			SoundLayers.play("PressureHiss", model)
		end)
		beat(model, run, 0.45, function()
			pillar(model, 0.1)
			SoundLayers.play("FireBreath", model)
		end)
		beat(model, run, 0.55, function()
			SoundLayers.play("SelfIgnite", model)
		end)
	elseif animation == "Pyro_Torch" then
		-- BLOWTORCH: chambered, the thrust; the lance lit 0.04 s before
		-- contact (0.22), the hit (0.26), it snaps off (0.36).
		gunBeats(model, run, 0.08, 0.1, 0.45)
		SoundController.play("HeavySwing", model)
		beat(model, run, 0.16, function()
			SoundLayers.play("FireSwing", model) -- (the hot muzzle swung in)
		end)
		beat(model, run, 0.22, function()
			lance(model, 0.14)
			SoundLayers.play("TorchLance", model)
		end)
	elseif animation == "Pyro_Mortar" then
		-- NAPALM MORTAR: braced at 45 deg, the shroud spits (overpressure),
		-- the glob (0.45, the server) with a backflash and a big recoil.
		gunBeats(model, run, 0.08, 0.1, 0.64)
		beat(model, run, 0.25, function()
			shroudSpit(model, 0.15)
			Flamethrower.setGauge(model, 1)
			SoundLayers.play("PressureHiss", model)
		end)
		beat(model, run, 0.43, function()
			squeeze(model)
		end)
		beat(model, run, 0.45, function()
			SoundLayers.play("GlobLaunch", model)
			Flamethrower.setGauge(model, 0.1)
			local muzzle = muzzleOf(model)
			if muzzle then
				-- the backflash: a 3-stud tongue out of the tip
				local back = FireLook.layer("fireball", muzzle, 1.1, "PyroBackflash")
				back.EmissionDirection = Enum.NormalId.Front
				back.Speed = NumberRange.new(5, 8)
				back.Drag = 4
				back.Lifetime = NumberRange.new(0.18, 0.28)
				back:Emit(3)
				Debris:AddItem(back, 0.6)
				flash(muzzle.WorldPosition, 3, 12, 0.2)
				lick(model, muzzle, 0.6, 0.15)
			end
		end)
	elseif animation == "Pyro_Inferno" then
		-- INFERNO: the handwheel cranked (0.2), the trigger (0.42); the
		-- stream is the server's cone (0.45 -> 1.25), raked down the floor.
		gunBeats(model, run, 0.08, 0.1, 1.34)
		beat(model, run, 0.2, function()
			Flamethrower.crankValve(model, 0.2)
			SoundLayers.play("ValveCrank", model)
			SoundLayers.play("PressureHiss", model)
		end)
		beat(model, run, 0.42, function()
			squeeze(model)
		end)
	elseif animation == "Pyro_TorchCharge" then
		-- TORCH CHARGE: the dash behind a wedge of fire (the server's cone,
		-- 0.14 -> 0.48), the shroud rammed into them (the charge's hit).
		gunBeats(model, run, 0.08, 0.1, 0.73)
		SoundController.play("Dash", model)
		beat(model, run, 0.13, function()
			squeeze(model)
		end)
	end
end

-- Our move was refused by the server: the gun goes back.
function PyroFx.stopAction(model: Model)
	stopJet(model)
	endRun(model, true)
end

------------------------------------------------------------------------------
-- The globs of napalm in flight
------------------------------------------------------------------------------

type Flight = {
	connection: RBXScriptConnection,
	trail: Attachment,
	folder: Folder,
}
local flights: { [number]: Flight } = {}

local function endFlight(id: number)
	local flight = flights[id]
	if flight == nil then
		return
	end
	flights[id] = nil
	flight.connection:Disconnect()
	flight.folder:Destroy()
	for _, item in flight.trail:GetChildren() do
		if item:IsA("ParticleEmitter") then
			item.Enabled = false
		elseif item:IsA("PointLight") then
			item:Destroy()
		end
	end
	Debris:AddItem(flight.trail, 1.5)
end

-- A glob of jellied fire (1.2 studs; the mortar's 1.8, a white-hot core):
-- rolling, a flame ribbon behind it, shedding burning drips that fall.
local function thrown(data: { [string]: any })
	local id, origin, velocity, gravity = data.id, data.origin, data.velocity, data.gravity
	if
		typeof(id) ~= "number"
		or typeof(origin) ~= "Vector3"
		or typeof(velocity) ~= "Vector3"
		or typeof(gravity) ~= "number"
	then
		return
	end
	local big = typeof(data.size) == "number" and data.size >= 6
	local by = data.by
	if typeof(by) == "Instance" and by:IsA("Model") then
		SoundLayers.play("MolotovThrow", by) -- (the glob's flame licking past)
	end
	local size = if big then 1.8 else 1.2
	endFlight(id)
	local folder = Instance.new("Folder")
	folder.Name = "NapalmGlob"
	folder.Parent = effectsFolder()
	local core = part(
		"GlobCore",
		Vector3.new(1, 1, 1) * size * 0.42,
		if big then FLAME_CORE else FLAME,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	core.Anchored = true
	core.Transparency = 0.15
	core.CFrame = CFrame.new(origin)
	core.Parent = folder
	-- (the flames stay where they were born: a smear of fire behind it)
	local trail = anchorAt(origin)
	local q = FireLook.quality()
	local body = FireLook.layer("body", trail, size * 0.6, "PyroGlobFlames")
	body.Lifetime = NumberRange.new(0.18, 0.3)
	body.Rate = (if big then 70 else 45) * q
	local drips = FireLook.layer("spark", trail, 1.1, "PyroGlobDrips")
	drips.Color = colors({ 0, 0.5, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP })
	drips.Size = numbers({ 0, 1 }, { 0.12, 0.05 })
	drips.Speed = NumberRange.new(0.5, 2)
	drips.SpreadAngle = Vector2.new(180, 180)
	drips.Acceleration = Vector3.new(0, -45, 0)
	drips.Lifetime = NumberRange.new(0.4, 0.7)
	drips.Rate = (if big then 30 else 18) * q
	local soot = FireLook.layer("smoke", trail, size * 0.25, "PyroGlobSmoke")
	soot.Color = ColorSequence.new(SOOT, SOOT_THIN)
	soot.Transparency = numbers({ 0, 0.2, 1 }, { 0.8, 0.6, 1 })
	soot.Lifetime = NumberRange.new(0.7, 1.2)
	soot.Speed = NumberRange.new(0, 0.4)
	soot.Rate = 18 * q
	local light = Instance.new("PointLight")
	light.Color = LIGHT_COLOR
	light.Brightness = if big then 3 else 2
	light.Range = if big then 14 else 10
	light.Parent = trail
	local strip = FireLook.image("flameStrip")
	if strip then
		local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
		top.Position = Vector3.new(0, size * 0.3, 0)
		bottom.Position = Vector3.new(0, -size * 0.3, 0)
		top.Parent = core
		bottom.Parent = core
		local t = Instance.new("Trail")
		t.Attachment0 = top
		t.Attachment1 = bottom
		t.Texture = strip
		t.TextureMode = Enum.TextureMode.Stretch
		t.Lifetime = if big then 0.32 else 0.24
		t.FaceCamera = true
		t.LightEmission = 1
		t.Brightness = 2
		t.LightInfluence = 0
		t.Color = ColorSequence.new(Color3.fromRGB(255, 240, 220), FLAME_DEEP)
		t.Transparency = numbers({ 0, 0.6, 1 }, { 0.15, 0.55, 1 })
		t.WidthScale = numbers({ 0, 1 }, { 1, 0.15 })
		t.Parent = core
	end
	local axis = velocity:Cross(Vector3.new(0, 1, 0))
	axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.new(1, 0, 0)
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local position = origin + velocity * t - Vector3.new(0, 0.5 * gravity * t * t, 0)
		-- rolling, wobbling (a jelly, not a stone)
		local wobble = 1 + math.sin(t * 30) * 0.12
		core.Size = Vector3.new(wobble, 1 / wobble, 1) * size * 0.42
		core.CFrame = CFrame.new(position) * CFrame.fromAxisAngle(axis, -8 * t)
		trail.WorldPosition = position
		if t > 4 then
			endFlight(id)
		end
	end)
	flights[id] = { connection = connection, trail = trail, folder = folder }
end

-- The fireball: the petrol vapour going up all at once. Full size at once
-- (pop, don't grow), a few big rolling balls and smaller ones flung out,
-- rising and turning to soot; embers; the smoke follows (+0.15 s).
local function fireball(position: Vector3, size: number)
	local at = anchorAt(position)
	local q = FireLook.quality()
	if FireLook.has("fireball") then
		local big = FireLook.layer("fireball", at, size, "PyroFireball")
		big.Speed = NumberRange.new(1, 4)
		big.SpreadAngle = Vector2.new(70, 70)
		big:Emit(math.floor(5 + size * 0.8))
		local small = FireLook.layer("fireball", at, size * 0.45, "PyroFireball")
		small.Speed = NumberRange.new(4, 9)
		small.SpreadAngle = Vector2.new(85, 85)
		small.Lifetime = NumberRange.new(0.6, 1)
		small:Emit(math.floor(10 * q))
	else
		local core = FireLook.layer("fireball", at, size, "PyroFireball")
		core.Speed = NumberRange.new(3, 8)
		core.SpreadAngle = Vector2.new(70, 70)
		core.Acceleration = Vector3.new(0, 10, 0)
		core.Drag = 2.5
		core:Emit(math.floor(10 + size * 4))
	end
	local embers = FireLook.layer("ember", at, 1.3, "PyroFireballEmbers")
	embers.Speed = NumberRange.new(6, 13)
	embers.SpreadAngle = Vector2.new(80, 80)
	embers:Emit(math.floor(14 * q))
	task.delay(0.15, function()
		local smoke = FireLook.layer("smoke", at, size * 0.4, "PyroFireballSmoke")
		smoke.Speed = NumberRange.new(2, 5)
		smoke.SpreadAngle = Vector2.new(50, 50)
		smoke.Acceleration = Vector3.new(0, 4, 0)
		smoke.Lifetime = NumberRange.new(1.8, 3)
		smoke:Emit(math.floor((5 + size * 2) * q))
	end)
	flash(position + Vector3.new(0, 1.5, 0), 6, 10 + size * 4, 0.5)
	Debris:AddItem(at, 3.5)
end

-- A glob landing: no glass, a wet amber SPLAT (fuel thrown out low and
-- radially, a dark wet mark), the fireball pops at full size, then the
-- server's pool. The mortar's adds a CROWN: burning drips thrown out in a
-- ring that each burn on the floor for 2 s (look only: the pool burns).
local function splat(position: Vector3, on: Model?, big: boolean)
	local at = anchorAt(position + Vector3.new(0, 0.2, 0), Vector3.new(0, 1, 0))
	local q = FireLook.quality()
	local wet = emitter(at, {
		Color = ColorSequence.new(PETROL),
		LightEmission = 0.1,
		LightInfluence = 1,
		Size = numbers({ 0, 1 }, { 0.13, 0.06 }),
		Transparency = numbers({ 0, 0.7, 1 }, { 0.3, 0.4, 1 }),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(85, 85),
		Acceleration = Vector3.new(0, -60, 0),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = numbers({ 0, 1 }, { 1.5, 1.5 }),
		Rate = 0,
	})
	wet:Emit(if big then 40 else 28)
	local burning = FireLook.layer("spark", at, 2, "PyroBurningDrops")
	burning.Color = colors({ 0, 0.5, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP })
	burning.Size = numbers({ 0, 1 }, { 0.14, 0.05 })
	burning.Speed = NumberRange.new(8, 18)
	burning.SpreadAngle = Vector2.new(80, 80)
	burning.Acceleration = Vector3.new(0, -50, 0)
	burning.Lifetime = NumberRange.new(0.5, 0.8)
	burning:Emit(math.floor((if big then 34 else 22) * q))
	Debris:AddItem(at, 1.5)
	local floor =
		workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -6, 0), floorParams())
	if floor and floor.Normal.Y > 0.6 then
		wetMark(floor.Position, if big then 4 else 3, 8)
	end
	if big then
		local count = math.floor(12 * q)
		for index = 1, count do
			local angle = index / count * math.pi * 2 + random:NextNumber(-0.25, 0.25)
			local reach = random:NextNumber(3, 5.5)
			local spot = position
				+ Vector3.new(math.cos(angle) * reach, 1.5, math.sin(angle) * reach)
			local hit = workspace:Raycast(spot, Vector3.new(0, -6, 0), floorParams())
			if hit and hit.Normal.Y > 0.6 then
				task.delay(random:NextNumber(0.12, 0.3), function()
					local drop =
						anchorAt(hit.Position + Vector3.new(0, 0.05, 0), Vector3.new(0, 1, 0))
					local flame = smallFlame(drop, 0.35, 0.06)
					task.delay(random:NextNumber(1.7, 2.3), function()
						snuff(flame)
						Debris:AddItem(drop, 1.5)
					end)
				end)
			end
		end
	end
	if on then
		local torso = bodyPart(on, "Torso")
		if torso then
			fireball(torso.Position, 2.2)
		end
	end
end

local function burst(data: { [string]: any })
	local id, position = data.id, data.position
	if typeof(position) ~= "Vector3" then
		return
	end
	if typeof(id) == "number" then
		endFlight(id)
	end
	local on = data.on
	local body: Model? = if typeof(on) == "Instance" and on:IsA("Model") then on else nil
	local radius = if typeof(data.radius) == "number" then data.radius else 5
	splat(position, body, radius >= 6)
	fireball(position, math.clamp(radius * 0.6, 2.5, 5))
	SoundLayers.playAt("GlobSplat", position)
	task.delay(0.06, function()
		SoundLayers.playAt("FuelIgnite", position)
	end)
end

-- Fire pools
------------------------------------------------------------------------------
-- Each server cell (p, r, born, dies) burns on its own: a burning film lying
-- flat on the floor (an organic looping flipbook at a random turn, never a
-- disc) and a few big standing flame clusters, each cell its own height. It
-- catches with a lick of flame, breathes with the pool, dies down over
-- DYING s. Per pool: one smoke column, one set of embers, ONE light that
-- sits over the flames still burning and wanders a little (shadows only on
-- the pool nearest the camera). The scorch builds up while it burns: one
-- irregular mark under the pool and a few smaller burnt patches (never a
-- disc per cell), faded after SCORCH_TIME. Rates and light at 15 Hz.

local DYING = 1.2
local POOL_STEP = 1 / 15

type PoolCell = {
	p: Vector3,
	r: number,
	born: number,
	dies: number,
	part: BasePart?,
	film: ParticleEmitter?,
	flames: ParticleEmitter?,
	filmRate: number,
	flameRate: number,
	state: number, -- 0 waiting, 1 burning, 2 out
}
type FirePool = {
	id: number,
	started: number,
	seconds: number,
	cells: { PoolCell },
	centre: BasePart,
	glow: Attachment,
	glowAt: Vector3,
	smoke: ParticleEmitter,
	embers: ParticleEmitter,
	light: PointLight,
	sound: SoundLayers.Loop?,
	marks: { Instance }, -- (faded at the end: decals or the stand-in parts)
	holders: { BasePart },
	floor: number,
	radius: number,
	seed: number,
	over: boolean,
}
local pools: { [number]: FirePool } = {}
local poolClock = 0

-- A burnt mark on the floor: the scorch decal on a flat invisible part, or
-- (not uploaded) a flattened ellipse of dark slate. Fades in to `opacity`
-- over `seconds` (it chars as the fire burns).
local function burntMark(
	pool: FirePool,
	position: Vector3,
	length: number,
	width: number,
	opacity: number,
	seconds: number
)
	local image = FireLook.image("scorch")
	local turn = CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	if image then
		local holder =
			part("Scorch", Vector3.new(width, 0.02, length), SCORCH, Enum.Material.SmoothPlastic)
		holder.Transparency = 1
		holder.Anchored = true
		holder.CFrame = CFrame.new(position) * turn
		local decal = Instance.new("Decal")
		decal.Texture = image
		decal.Face = Enum.NormalId.Top
		decal.Transparency = 1
		decal.Parent = holder
		holder.Parent = effectsFolder()
		TweenService:Create(decal, TweenInfo.new(seconds), { Transparency = 1 - opacity }):Play()
		table.insert(pool.marks, decal)
		table.insert(pool.holders, holder)
		return
	end
	local disc = part("Scorch", Vector3.new(0.03, length, width), SCORCH, Enum.Material.Slate)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Parent = disc
	disc.Transparency = 1
	disc.Anchored = true
	disc.CFrame = CFrame.new(position) * turn * UPRIGHT
	disc.Parent = effectsFolder()
	TweenService:Create(disc, TweenInfo.new(seconds), { Transparency = 1 - opacity * 0.6 }):Play()
	table.insert(pool.marks, disc)
	table.insert(pool.holders, disc)
end

local function cellFire(cell: PoolCell)
	local r = cell.r
	local p =
		part("PoolCell", Vector3.new(r * 1.5, 0.15, r * 1.5), FLAME, Enum.Material.SmoothPlastic)
	p.Transparency = 1
	p.Anchored = true
	p.CFrame = CFrame.new(cell.p + Vector3.new(0, 0.12, 0))
		* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	p.Parent = effectsFolder()
	cell.part = p
	local q = FireLook.quality()
	local film = FireLook.layer("ground", p, r * 1.6, "PoolFilm")
	cell.filmRate = 2.5 * q
	film.Rate = cell.filmRate
	local flames = FireLook.layer("body", p, random:NextNumber(2, 2.9), "PoolFlames")
	flames.Lifetime = NumberRange.new(0.55, 0.9)
	cell.flameRate = random:NextNumber(2.4, 3.4) * q
	flames.Rate = cell.flameRate
	-- catching: a lick of flame at once
	film:Emit(2)
	flames:Emit(3)
	cell.film, cell.flames = film, flames
end

local function cellOut(cell: PoolCell)
	cell.state = 2
	for _, e in { cell.film, cell.flames } do
		if e then
			e.Enabled = false
		end
	end
	if cell.part then
		Debris:AddItem(cell.part, 2.2)
	end
end

local function endPool(pool: FirePool, early: boolean)
	if pool.over then
		return
	end
	pool.over = true
	pools[pool.id] = nil
	if pool.sound then
		pool.sound.stop(if early then 0.4 else 1.5)
	end
	pool.smoke.Enabled = false
	pool.embers.Enabled = false
	for _, cell in pool.cells do
		if cell.state ~= 2 then
			cellOut(cell)
		end
	end
	-- (out of the flicker first, or it keeps the light up over the tween)
	for index = #flickers, 1, -1 do
		if flickers[index].light == pool.light then
			table.remove(flickers, index)
		end
	end
	TweenService:Create(pool.light, TweenInfo.new(1.2), { Brightness = 0 }):Play()
	Debris:AddItem(pool.centre, 8)
	-- The black marks stay a while, then fade.
	local marks, holders = pool.marks, pool.holders
	task.delay(PyroConfig.SCORCH_TIME, function()
		for _, mark in marks do
			if mark.Parent then
				TweenService:Create(mark, TweenInfo.new(3), { Transparency = 1 }):Play()
			end
		end
		for _, holder in holders do
			Debris:AddItem(holder, 3.2)
		end
	end)
end

local function firePool(data: { [string]: any }, quiet: boolean?)
	local id, position, seconds, cells = data.id, data.position, data.seconds, data.cells
	if
		typeof(id) ~= "number"
		or typeof(position) ~= "Vector3"
		or typeof(seconds) ~= "number"
		or typeof(cells) ~= "table"
	then
		return
	end
	local radius = if typeof(data.radius) == "number" then data.radius else 5
	local parsed: { PoolCell } = {}
	local floor, count = 0, 0
	for _, raw in cells :: { any } do
		if
			typeof(raw) == "table"
			and typeof(raw.p) == "Vector3"
			and typeof(raw.r) == "number"
			and typeof(raw.born) == "number"
			and typeof(raw.dies) == "number"
		then
			table.insert(parsed, {
				p = raw.p,
				r = raw.r,
				born = raw.born,
				dies = raw.dies,
				part = nil,
				film = nil,
				flames = nil,
				filmRate = 0,
				flameRate = 0,
				state = 0,
			})
			floor += raw.p.Y
			count += 1
		end
	end
	floor = if count > 0 then floor / count else position.Y
	local centre = part(
		"PoolCentre",
		Vector3.new(radius * 1.2, 0.5, radius * 1.2),
		FLAME,
		Enum.Material.SmoothPlastic
	)
	centre.Transparency = 1
	centre.Anchored = true
	centre.CFrame = CFrame.new(position.X, floor + 1, position.Z)
	centre.Parent = effectsFolder()
	-- One smoke column and one set of embers for the whole pool (the budget).
	local q = FireLook.quality()
	local smoke = FireLook.layer("smoke", centre, 1.6, "PoolSmoke")
	smoke.Speed = NumberRange.new(3, 5)
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Acceleration = Vector3.new(0, 1.5, 0)
	smoke.Drag = 0.4
	smoke.RotSpeed = NumberRange.new(-12, 12)
	smoke.Rate = 8 * q
	local embers = FireLook.layer("ember", centre, 1, "PoolEmbers")
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Rate = 5 * q
	local glow = Instance.new("Attachment")
	glow.Name = "PoolLight"
	glow.Parent = centre
	local light = fireLight(glow, 2.2, math.clamp(radius * 2.5, 12, 24), 0.2)
	light.Color = POOL_LIGHT
	local pool: FirePool = {
		id = id,
		started = os.clock(),
		seconds = seconds,
		cells = parsed,
		centre = centre,
		glow = glow,
		glowAt = Vector3.new(position.X, floor + 1.2, position.Z),
		smoke = smoke,
		embers = embers,
		light = light,
		-- (fades in under the fireball's tail: one sound turning into the other)
		sound = if quiet then nil else SoundLayers.loopOn("PoolFire", centre, 1, 1),
		marks = {},
		holders = {},
		floor = floor,
		radius = radius,
		seed = random:NextNumber(0, 100),
		over = false,
	}
	-- The scorch under it all: it chars in as the pool burns (the first
	-- second it is the petrol's wet dark stain).
	local ground = Vector3.new(position.X, floor + 0.03, position.Z)
	if FireLook.has("scorch") then
		burntMark(pool, ground, radius * 2.6, radius * 2.3, 0.92, math.min(seconds * 0.6, 5))
	else
		for _ = 1, 3 do
			local offset = Vector3.new(
				random:NextNumber(-0.3, 0.3),
				0,
				random:NextNumber(-0.3, 0.3)
			) * radius
			burntMark(
				pool,
				ground + offset + Vector3.new(0, random:NextNumber(0, 0.006), 0),
				radius * random:NextNumber(1.2, 2.1),
				radius * random:NextNumber(0.8, 1.5),
				random:NextNumber(0.55, 0.75),
				math.min(seconds * 0.6, 5)
			)
		end
	end
	local old = pools[id]
	if old then
		endPool(old, true)
	end
	pools[id] = pool
end

local function stepPools(dt: number)
	poolClock += dt
	local tick = poolClock >= POOL_STEP
	if tick then
		poolClock = 0
	end
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local nearest: FirePool? = nil
	local nearestDistance = 70
	for _, pool in pools do
		local age = now - pool.started
		local live = 0
		local sum, weight = Vector3.zero, 0
		local g = FireLook.gust(now, pool.seed)
		for index, cell in pool.cells do
			if cell.state == 0 and age >= cell.born then
				cell.state = 1
				cellFire(cell)
				-- a burnt patch under some of them (not one disc per cell)
				if index % 3 == 1 then
					burntMark(
						pool,
						cell.p + Vector3.new(0, 0.035 + (index % 7) * 0.002, 0),
						cell.r * random:NextNumber(1.6, 2.4),
						cell.r * random:NextNumber(1.1, 1.7),
						0.7,
						2.5
					)
				end
			elseif cell.state == 1 and age >= cell.dies then
				cellOut(cell)
			end
			if cell.state == 1 then
				-- (dying down over its last DYING seconds)
				local k = math.clamp((cell.dies - age) / DYING, 0, 1)
				live += k
				sum += cell.p * k
				weight += k
				if tick then
					local film, flames = cell.film, cell.flames
					if film then
						film.Rate = cell.filmRate * (0.3 + 0.7 * k)
					end
					if flames then
						flames.Rate = cell.flameRate * k * (0.8 + 0.4 * g)
					end
				end
			end
		end
		local share = if #pool.cells > 0 then live / #pool.cells else 0
		if weight > 0 then
			pool.glowAt = sum / weight + Vector3.new(0, 1.2, 0)
		end
		-- the light wanders over the flames: shadows and highlights crawl
		pool.glow.WorldPosition = pool.glowAt
			+ Vector3.new(
				math.noise(now * 1.7, pool.seed),
				0.4 * math.noise(now * 2.3, pool.seed, 1.3),
				math.noise(now * 1.9, pool.seed, 2.9)
			)
		if tick then
			local q = FireLook.quality()
			pool.smoke.Rate = (2 + 10 * share) * q
			pool.embers.Rate = (1 + 6 * share) * q
			if pool.sound then
				pool.sound.setVolume(0.25 + 0.75 * share)
			end
			local f = flickerOf(pool.light)
			if f then
				f.brightness = (0.4 + 2.2 * share) * (0.75 + 0.5 * g)
			end
		end
		if camera then
			local distance = (camera.CFrame.Position - pool.glowAt).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = pool, distance
			end
		end
		if age >= pool.seconds + 0.2 then
			endPool(pool, false)
		end
	end
	-- Shadows from one pool only: the nearest (its fighters cast shadows).
	if tick then
		for _, pool in pools do
			local wanted = pool == nearest
			if pool.light.Shadows ~= wanted then
				pool.light.Shadows = wanted
			end
		end
	end
end

------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Cones: the server's jets (Gadgets), drawn from the gun's muzzle
------------------------------------------------------------------------------

-- Each move's own stream (the server decides who it reaches: these are looks).
local STREAM: JetLook = {
	range = 14,
	width = 2.2,
	rate = 45,
	billow = 1.6,
	soot = 12,
	light = 3,
	blue = false,
}
local INFERNO: JetLook = {
	range = 17,
	width = 3.2,
	rate = 70,
	billow = 2.4,
	soot = 20,
	light = 4,
	blue = true,
	rake = 0.6, -- (1.05 s into the move: the muzzle goes down, the end licks the floor)
}
local WEDGE: JetLook = {
	range = 8,
	width = 2.6,
	rate = 55,
	billow = 1.4,
	soot = 8,
	light = 3,
	blue = true,
	low = true,
}

local function cone(data: { [string]: any })
	local by, kind, range, seconds = data.by, data.kind, data.range, data.seconds
	if
		typeof(by) ~= "Instance"
		or not by:IsA("Model")
		or typeof(range) ~= "number"
		or typeof(seconds) ~= "number"
	then
		return
	end
	local model = by
	if kind ~= "Flame" then
		return -- (the fuel spray is drawn on the clip's beat: PyroFx.onAction)
	end
	local move = data.move
	if move == "Inferno" then
		SoundLayers.play("InfernoBreath", model)
		Flamethrower.setHeat(model, 0.75)
		task.delay(seconds + 0.2, function()
			Flamethrower.setHeat(model, 0)
		end)
		startJet(model, INFERNO, seconds)
		-- (the floor it raked: the server's pool catches there just after)
		task.delay(seconds, function()
			SoundLayers.play("StreamEnd", model)
		end)
	elseif move == "TorchCharge" then
		SoundLayers.play("FireBreath", model)
		startJet(model, WEDGE, seconds)
	else
		SoundLayers.play("FireBreath", model)
		local look = table.clone(STREAM)
		look.range = range
		look.blue = isAwake(model)
		startJet(model, look, seconds)
		task.delay(seconds, function()
			SoundLayers.play("StreamEnd", model)
		end)
	end
end

function PyroFx.onRemote(kind: unknown, data: unknown)
	if typeof(kind) ~= "string" or typeof(data) ~= "table" then
		return
	end
	local payload = data :: { [string]: any }
	if kind == "MolotovThrown" then
		thrown(payload)
	elseif kind == "MolotovBurst" then
		burst(payload)
	elseif kind == "FirePool" then
		firePool(payload)
	elseif kind == "PoolOut" then
		local id = payload.id
		local pool = if typeof(id) == "number" then pools[id] else nil
		if pool then
			endPool(pool, true)
		end
	elseif kind == "Cone" then
		cone(payload)
	end
end

------------------------------------------------------------------------------
-- On bodies: soaked, burning forearms, the burning body
------------------------------------------------------------------------------

-- Soaked in petrol: it drips off them until it dries.
local dripping: { [Model]: ParticleEmitter } = setmetatable({}, { __mode = "k" }) :: any
local function refreshDoused(model: Model)
	local untilTime = model:GetAttribute(PyroConfig.DOUSED_ATTRIBUTE)
	local left = if typeof(untilTime) == "number" then untilTime - serverNow() else 0
	local drip: ParticleEmitter? = dripping[model]
	if left <= 0 then
		if drip then
			drip.Enabled = false
			Debris:AddItem(drip, 1)
			dripping[model] = nil
		end
		return
	end
	if drip == nil then
		local torso = bodyPart(model, "Torso")
		if torso == nil then
			return
		end
		local made = emitter(torso, {
			Name = "PyroDrip",
			Color = ColorSequence.new(PETROL),
			LightInfluence = 1,
			Size = numbers({ 0, 1 }, { 0.07, 0.05 }),
			Transparency = numbers({ 0, 1 }, { 0.3, 0.5 }),
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(0, 0.3),
			Acceleration = Vector3.new(0, -35, 0),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Squash = numbers({ 0, 1 }, { 1.4, 1.4 }),
			Rate = 9,
		})
		dripping[model] = made
	end
	task.delay(left + 0.05, function()
		if model.Parent then
			refreshDoused(model)
		end
	end)
end

-- His forearms alight (Awakening "BURNING MAN"), on the clip's beats: the
-- pillar's blowback rains burning fuel back on them (0.5: drops), the left
-- wrap catches and the fire runs up from the wrist to the elbow (0.55), the
-- right one catches (0.63), the gun swung down to the hip (0.75: a burst of
-- fire off each, the light pops). Then they burn like a burning body (FireLook layers on
-- a forearm-sized block) with ONE light on the chest between them. A swing
-- fans them (more flame for an instant); a landed burning hit flares.
local AWAKEN_SPARKS = 0.5
local AWAKEN_LEFT = 0.55
local AWAKEN_RIGHT = 0.63
local AWAKEN_FLING = 0.75

type ArmFire = { arm: BasePart, block: BasePart, emitters: { ParticleEmitter }, rates: { number } }
type Arms = {
	fires: { ArmFire },
	light: PointLight?,
	lightAt: Attachment?,
	sound: SoundLayers.Loop?,
	boostUntil: number,
	over: boolean,
}
local burningArms: { [Model]: Arms } = setmetatable({}, { __mode = "k" }) :: any

local function armRates(arms: Arms, boost: number)
	for _, fire in arms.fires do
		for index, e in fire.emitters do
			e.Rate = fire.rates[index] * boost
		end
	end
end

-- One forearm catching: the fire block starts at the wrist and grows up to
-- the elbow in 0.15 s.
local function igniteArm(model: Model, arms: Arms, name: string)
	local arm = bodyPart(model, name)
	if arm == nil or arms.over then
		return
	end
	local block = part("PyroArmFire", Vector3.new(1, 0.3, 1), FLAME, Enum.Material.SmoothPlastic)
	block.Transparency = 1
	local w = weld(arm, block, CFrame.new(0, -0.85, 0))
	block.Parent = arm
	TweenService:Create(block, TweenInfo.new(0.15), { Size = Vector3.new(1, 1, 1) }):Play()
	TweenService:Create(w, TweenInfo.new(0.15), { C0 = CFrame.new(0, -0.5, 0) }):Play()
	local q = FireLook.quality()
	local body = FireLook.layer("body", block, 0.6, "PyroArmFlames")
	local tongue = FireLook.layer("tongue", block, 0.6, "PyroArmFlames")
	local glow = FireLook.layer("glow", block, 0.7, "PyroArmFlames")
	local embers = FireLook.layer("ember", block, 1, "PyroArmFlames")
	embers.Speed = NumberRange.new(1, 3)
	embers.SpreadAngle = Vector2.new(60, 60)
	local smoke = FireLook.layer("smoke", block, 0.3, "PyroArmFlames")
	smoke.Color = ColorSequence.new(SOOT, SOOT_THIN)
	smoke.Transparency = numbers({ 0, 0.3, 1 }, { 0.85, 0.65, 1 })
	smoke.Lifetime = NumberRange.new(1, 1.6)
	smoke.Speed = NumberRange.new(1, 2)
	local fire: ArmFire = {
		arm = arm,
		block = block,
		emitters = { body, tongue, glow, embers, smoke },
		rates = { 9 * q, 8 * q, if q >= 0.75 then 4 else 0, 1.5 * q, 3 * q },
	}
	for index, e in fire.emitters do
		e.Rate = fire.rates[index]
	end
	catch({ body, tongue }, 0.15)
	tongue:Emit(3)
	table.insert(arms.fires, fire)
	if arms.sound == nil then
		arms.sound = SoundLayers.loopOn("BodyBurn", arm, 0.35, 0.4)
	end
	if arms.light == nil then
		local torso = bodyPart(model, "Torso")
		if torso then
			local at = Instance.new("Attachment")
			at.Name = "PyroArmLight"
			at.Position = Vector3.new(0, -0.3, -0.7)
			at.Parent = torso
			arms.lightAt = at
			arms.light = fireLight(at, 1.8, 12, 0.15)
		end
	end
end

-- The arms flung out: a burst of fire off each, the light pops.
local function flingBurst(arms: Arms)
	if arms.over then
		return
	end
	for _, fire in arms.fires do
		local at = Instance.new("Attachment")
		at.Position = Vector3.new(0, -0.9, 0)
		at.Parent = fire.arm
		local ball = FireLook.layer("fireball", at, 1.2, "PyroArmBurst")
		ball.Speed = NumberRange.new(2, 5)
		ball.SpreadAngle = Vector2.new(60, 60)
		ball.Lifetime = NumberRange.new(0.5, 0.8)
		ball:Emit(3)
		local embers = FireLook.layer("ember", at, 1.2, "PyroArmBurst")
		embers.Speed = NumberRange.new(5, 10)
		embers.SpreadAngle = Vector2.new(80, 80)
		embers:Emit(math.floor(10 * FireLook.quality()))
		Debris:AddItem(at, 2)
	end
	local lightAt = arms.lightAt
	if lightAt then
		flash(lightAt.WorldPosition, 4, 14, 0.3)
	end
end

local function refreshArms(model: Model)
	local on = model:GetAttribute("Kit") == PyroConfig.KIT_ID
		and model:GetAttribute("Awakened") == true
	local arms = burningArms[model]
	if on and arms == nil then
		local made: Arms =
			{ fires = {}, light = nil, lightAt = nil, sound = nil, boostUntil = 0, over = false }
		burningArms[model] = made
		-- (wait a moment: the clip's start may come just after the attribute)
		task.delay(0.12, function()
			if burningArms[model] ~= made or made.over then
				return
			end
			local since = os.clock() - (awakenStarted[model] or -math.huge)
			if since > 1.2 then
				-- (already burning: we just joined, or came back in range)
				igniteArm(model, made, "Left Arm")
				igniteArm(model, made, "Right Arm")
				return
			end
			local function at(time: number, fn: () -> ())
				task.delay(math.max(0, time - since), function()
					if burningArms[model] == made and not made.over and model.Parent then
						fn()
					end
				end)
			end
			at(AWAKEN_SPARKS, function()
				-- (burning fuel falling back out of the pillar onto his arms)
				for _, name in { "Left Arm", "Right Arm" } do
					local arm = bodyPart(model, name)
					if arm then
						local spot = Instance.new("Attachment")
						spot.Position = Vector3.new(0, 1.2, 0)
						spot.Parent = arm
						local rain = FireLook.layer("spark", spot, 1.2, "PyroBlowback")
						rain.Color = colors({ 0, 0.5, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP })
						rain.EmissionDirection = Enum.NormalId.Bottom
						rain.Speed = NumberRange.new(3, 6)
						rain.SpreadAngle = Vector2.new(25, 25)
						rain.Acceleration = Vector3.new(0, -40, 0)
						rain:Emit(10)
						Debris:AddItem(spot, 0.9)
					end
				end
			end)
			at(AWAKEN_LEFT, function()
				igniteArm(model, made, "Left Arm")
			end)
			at(AWAKEN_RIGHT, function()
				igniteArm(model, made, "Right Arm")
			end)
			at(AWAKEN_FLING, function()
				flingBurst(made)
			end)
		end)
	elseif not on and arms then
		burningArms[model] = nil
		arms.over = true
		if arms.sound then
			arms.sound.stop(0.8)
			SoundLayers.play("Extinguish", model)
		end
		for _, fire in arms.fires do
			for _, e in fire.emitters do
				e.Enabled = false
			end
			Debris:AddItem(fire.block, 1.6)
		end
		if arms.light then
			arms.light:Destroy()
		end
		if arms.lightAt then
			Debris:AddItem(arms.lightAt, 0.1)
		end
	end
end

-- A swing fans the flames: more of them for a moment (a smear of fire
-- along the punch: the particles stay where they were born).
local function fanArms(model: Model, from: number, to: number)
	local arms = burningArms[model]
	if arms == nil then
		return
	end
	task.delay(from, function()
		if burningArms[model] ~= arms or arms.over then
			return
		end
		arms.boostUntil = os.clock() + (to - from)
		armRates(arms, 2.2)
		task.delay(to - from, function()
			if
				burningArms[model] == arms
				and not arms.over
				and os.clock() >= arms.boostUntil - 0.02
			then
				armRates(arms, 1)
			end
		end)
	end)
end

armsOnAction = function(model: Model, animation: string)
	if animation == "Pyro_Torch" then
		fanArms(model, 0.16, 0.36) -- (the thrust)
	elseif animation == "Pyro_TorchCharge" then
		fanArms(model, 0.12, 0.55) -- (the charge)
	end
end

-- The blowtorch / the charge landed: the flame comes off the MUZZLE onto
-- them (a blossom of fire on their body), molten slag sparks (4 frames), a
-- flash (blue-white for the lance).
function PyroFx.onHit(victim: Model, attacker: Model, moveId: string)
	if moveId ~= "Blowtorch" and moveId ~= "TorchCharge" then
		return
	end
	local torso = bodyPart(victim, "Torso")
	if torso == nil then
		return
	end
	local muzzle = Flamethrower.muzzle(attacker)
	local from = if muzzle then muzzle.WorldPosition else torso.Position
	local toward = torso.Position - from
	local at = if toward.Magnitude > 1 then torso.Position - toward.Unit * 0.6 else torso.Position
	local anchor = anchorAt(at, if toward.Magnitude > 1e-3 then toward else nil)
	local ball =
		FireLook.layer("fireball", anchor, if moveId == "TorchCharge" then 2 else 1.4, "PyroImpact")
	ball.EmissionDirection = Enum.NormalId.Front
	ball.Speed = NumberRange.new(2, 5)
	ball.SpreadAngle = Vector2.new(60, 60)
	ball.Lifetime = NumberRange.new(0.4, 0.6)
	ball:Emit(if moveId == "TorchCharge" then 5 else 3)
	sparks(anchor, 14, 14, 80)
	if moveId == "Blowtorch" then
		-- a ring of flame splashing on them (2 studs)
		local ring = FireLook.layer("tongue", anchor, 0.7, "PyroTorchRing")
		ring.SpreadAngle = Vector2.new(90, 90)
		ring.Speed = NumberRange.new(4, 7)
		ring:Emit(10)
		local light = Instance.new("PointLight")
		light.Color = BLUE_CORE
		light.Brightness = 6
		light.Range = 10
		light.Parent = anchor
		task.delay(1 / 30, function()
			light:Destroy()
		end)
	else
		flash(at, 5, 14, 0.25)
	end
	Debris:AddItem(anchor, 1.5)
	SoundLayers.playAt("FireImpact", at, torso)
end

-- A body burning (the finisher): the fire's roar while it burns, over the
-- crackle every burning body has. Its burns, charred clothes, flames, smoke,
-- light and crackle are Client/Combat/Burns (the server's burn attributes, a
-- corpse copy too).
type Pyre = { sound: SoundLayers.Loop, endsAt: number }
local pyres: { [Model]: Pyre } = setmetatable({}, { __mode = "k" }) :: any

local function stopPyre(model: Model)
	local pyre = pyres[model]
	pyres[model] = nil
	if pyre then
		pyre.sound.stop(1.5)
	end
end

-- Burning `burnLeft` more seconds (one already roaring: it goes on till then).
local function startPyre(model: Model, burnLeft: number)
	local torso = bodyPart(model, "Torso")
	if torso == nil or burnLeft <= 0 then
		return
	end
	local endsAt = os.clock() + burnLeft
	local pyre = pyres[model]
	if pyre then
		pyre.endsAt = endsAt
	else
		-- (fades in under the ignition's tail)
		pyres[model] = { sound = SoundLayers.loopOn("PyreRoar", torso, 1, 1.5), endsAt = endsAt }
	end
	task.delay(burnLeft, function()
		local current = pyres[model]
		if current and os.clock() >= current.endsAt - 0.05 then
			stopPyre(model)
		end
	end)
end

local function refreshImmolated(model: Model)
	local caught = model:GetAttribute(PyroConfig.IMMOLATED_ATTRIBUTE)
	if typeof(caught) == "number" then
		startPyre(model, PyroConfig.IMMOLATE_BURN - (serverNow() - caught))
	end
end

local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function watch(instance: Instance)
	if not instance:IsA("Model") or watched[instance] then
		return
	end
	local model = instance
	watched[model] = true
	model:GetAttributeChangedSignal(PyroConfig.DOUSED_ATTRIBUTE):Connect(function()
		refreshDoused(model)
	end)
	model:GetAttributeChangedSignal("Awakened"):Connect(function()
		refreshArms(model)
	end)
	model:GetAttributeChangedSignal("Kit"):Connect(function()
		refreshArms(model)
	end)
	model:GetAttributeChangedSignal(PyroConfig.IMMOLATED_ATTRIBUTE):Connect(function()
		refreshImmolated(model)
	end)
	Flamethrower.watch(model) -- (his flamethrower, slung on his back)
	refreshDoused(model)
	refreshArms(model)
	refreshImmolated(model)
end

------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- The finisher "Immolate"
------------------------------------------------------------------------------

type Show = {
	cancelled: boolean,
	run: Run?,
	pour: { Instance },
	victim: Model,
	pouring: boolean,
	wet: BasePart?,
	jet: Jet?,
	drips: ParticleEmitter?,
}

local poolIds = 0

-- The floor under a body (a ray down, past the fighters).
local function floorUnder(position: Vector3, ignore: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position, Vector3.new(0, -8, 0), params)
	return if hit then hit.Position else nil
end

-- The petrol soaking the floor under the victim: a dark wet stain that
-- spreads while he pours.
local function wetStain(show: Show, attacker: Model)
	local torso = bodyPart(show.victim, "Torso")
	if torso == nil then
		return
	end
	local floor = floorUnder(torso.Position, { show.victim, attacker, effectsFolder() })
	if floor == nil then
		return
	end
	local image = FireLook.image("scorch")
	local stain = part(
		"PyroWet",
		Vector3.new(0.03, 0.6, 0.5),
		Color3.fromRGB(34, 29, 22),
		Enum.Material.SmoothPlastic
	)
	stain.Anchored = true
	stain.Reflectance = 0.12
	stain.CFrame = CFrame.new(floor + Vector3.new(0, 0.025, 0))
		* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		* UPRIGHT
	local grow = Vector3.new(0.03, 4, 3.2)
	if image then
		-- (the scorch picture, dark and glossy: wet petrol)
		stain.Transparency = 1
		stain.Size = Vector3.new(0.6, 0.03, 0.5)
		stain.CFrame = CFrame.new(floor + Vector3.new(0, 0.025, 0))
			* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		grow = Vector3.new(4, 0.03, 3.2)
		local decal = Instance.new("Decal")
		decal.Texture = image
		decal.Face = Enum.NormalId.Top
		decal.Color3 = Color3.fromRGB(150, 128, 92)
		decal.Transparency = 0.45
		decal.Parent = stain
	else
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Cylinder
		mesh.Parent = stain
		stain.Transparency = 0.35
	end
	stain.Parent = effectsFolder()
	TweenService:Create(
		stain,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = grow }
	):Play()
	show.wet = stain
	Debris:AddItem(stain, 20)
end

-- The fire catching on the floor under the burning body: a small pool of
-- 5 cells catching outward in 0.4 s, burning as long as the body (look
-- only: its sound is the body's).
local function floorFire(show: Show, attacker: Model)
	local torso = bodyPart(show.victim, "Torso")
	if torso == nil then
		return
	end
	local floor = floorUnder(torso.Position, { show.victim, attacker, effectsFolder() })
	if floor == nil then
		return
	end
	poolIds -= 1
	local burn = PyroConfig.IMMOLATE_BURN
	local cells = { { p = floor, r = 1.1, born = 0, dies = burn - random:NextNumber(0, 2) } }
	for index = 1, 4 do
		local angle = index * math.pi / 2 + random:NextNumber(-0.4, 0.4)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
			* random:NextNumber(0.9, 1.5)
		table.insert(cells, {
			p = floor + offset,
			r = random:NextNumber(0.7, 1),
			born = 0.1 * index,
			dies = burn - random:NextNumber(0, 3),
		})
	end
	firePool({ id = poolIds, position = floor, seconds = burn, radius = 2.2, cells = cells }, true)
	local wet = show.wet
	if wet then
		-- (the petrol burns off: the scorch takes its place)
		local items: { Instance } = { wet }
		local decal = wet:FindFirstChildOfClass("Decal")
		if decal then
			table.insert(items, decal)
		end
		for _, item in items do
			TweenService:Create(item, TweenInfo.new(3), { Transparency = 1 }):Play()
		end
	end
end
local shows: { [Model]: Show } = setmetatable({}, { __mode = "k" }) :: any

-- The finisher's full bore: point-blank, the flame bending and splashing
-- along the body (the rake from the start: it licks where it lands).
local FULL_BORE: JetLook = {
	range = 4,
	width = 1.8,
	rate = 70,
	billow = 1.8,
	soot = 18,
	light = 4,
	blue = true,
	rake = 0,
}

-- The raw fuel poured on them: a glossy amber stream out of the muzzle (no
-- flame: he killed the pilot), laminar, falling on the body.
local function fuelPour(show: Show, attacker: Model)
	local muzzle = muzzleOf(attacker)
	if muzzle == nil then
		return
	end
	Flamethrower.trigger(attacker, true)
	local stream = emitter(muzzle, {
		Name = "PyroFuelPour",
		Color = ColorSequence.new(PETROL),
		LightInfluence = 1,
		LightEmission = 0.15,
		Size = numbers({ 0, 1 }, { 0.14, 0.1 }),
		Transparency = numbers({ 0, 1 }, { 0.15, 0.4 }),
		Lifetime = NumberRange.new(0.25, 0.35),
		Speed = NumberRange.new(9, 11),
		SpreadAngle = Vector2.new(2, 2),
		EmissionDirection = Enum.NormalId.Front,
		Acceleration = Vector3.new(0, -20, 0),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = numbers({ 0, 1 }, { 3, 3 }),
		Rate = 140,
	})
	table.insert(show.pour, stream)
end

-- His final vent: the relief valve's white-hot hiss straight up, shimmer.
local function finisherEvent(show: Show, kind: string, attacker: Model, victim: Model)
	local run = show.run
	if kind == "ValveOpen" then
		Flamethrower.crankValve(attacker, 0.3)
		SoundLayers.play("ValveCrank", attacker)
		SoundLayers.play("PressureHiss", attacker)
	elseif kind == "PilotOut" then
		-- (he kills the pilot on purpose: what comes out now doesn't burn)
		Flamethrower.setPilot(attacker, false)
		SoundLayers.play("PilotOut", attacker)
	elseif kind == "Douse" then
		SoundLayers.play("FuelSplash", attacker)
		-- It splashes off his head and shoulders all the while it pours,
		-- and soaks the floor under him.
		show.pouring = true
		fuelPour(show, attacker)
		wetStain(show, attacker)
		local head = bodyPart(victim, "Head")
		if head then
			local spot = Instance.new("Attachment")
			spot.Name = "PyroSplash"
			spot.Position = Vector3.new(0, 0.4, 0)
			spot.Parent = head
			local drops = emitter(spot, {
				Name = "PyroSplash",
				Color = ColorSequence.new(PETROL),
				LightInfluence = 1,
				LightEmission = 0.15,
				Size = numbers({ 0, 1 }, { 0.09, 0.05 }),
				Transparency = numbers({ 0, 1 }, { 0.2, 0.6 }),
				Lifetime = NumberRange.new(0.35, 0.6),
				Speed = NumberRange.new(3, 6),
				SpreadAngle = Vector2.new(70, 70),
				Acceleration = Vector3.new(0, -40, 0),
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				Rate = 0,
			})
			task.spawn(function()
				while show.pouring and not show.cancelled and drops.Parent do
					drops:Emit(6)
					task.wait(0.2)
				end
				Debris:AddItem(spot, 1)
			end)
		end
	elseif kind == "DouseEnd" then
		show.pouring = false
		Flamethrower.trigger(attacker, false)
		for _, e in show.pour do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
			Debris:AddItem(e, 0.5)
		end
	elseif kind == "Drip" then
		-- one shake: fuel drips off the slash cut
		local muzzle = muzzleOf(attacker)
		if muzzle then
			drool(muzzle, 0.3, false)
		end
	elseif kind == "Open" then
		if run then
			local zippo = zippoIn(attacker, run, "Left Arm")
			if zippo then
				zippo.setOpen(true)
			end
		end
		SoundLayers.play("ZippoOpen", attacker)
	elseif kind == "Strike" then
		if run and run.zippo then
			run.zippo.setLit(true)
		end
		SoundLayers.play("ZippoStrike", attacker)
	elseif kind == "PilotLit" then
		-- the Zippo's flame to the burner: the blue pilot pops, his face lit
		-- blue and orange
		Flamethrower.setPilot(attacker, true)
		SoundLayers.play("PilotLight", attacker)
		local pilot = Flamethrower.point(attacker, "PilotLight")
		if pilot then
			local light = Instance.new("PointLight")
			light.Color = BLUE_CORE
			light.Brightness = 3
			light.Range = 6
			light.Parent = pilot
			TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
			Debris:AddItem(light, 0.45)
		end
	elseif kind == "Lower" then
		-- the quiet hold, the muzzle down to their face: only the hiss
		SoundLayers.play("PressureHiss", attacker)
	elseif kind == "Ignite" then
		local torso = bodyPart(victim, "Torso")
		if torso then
			SoundLayers.playAt("BodyIgnite", torso.Position, torso)
			fireball(torso.Position + Vector3.new(0, 0.5, 0), 3.2)
			floorFire(show, attacker)
		end
		SoundLayers.play("InfernoBreath", attacker)
		SoundLayers.play("PressureHiss", attacker)
		startPyre(victim, PyroConfig.IMMOLATE_BURN)
		-- Full bore, point-blank: a blue-white root, the flame bending and
		-- splashing along the body; the shroud and the muzzle cherry red,
		-- dripping burning fuel.
		show.jet = startJet(attacker, FULL_BORE, 1.2)
		Flamethrower.setHeat(attacker, 1)
		local muzzle = muzzleOf(attacker)
		if muzzle then
			local drips = FireLook.layer("spark", muzzle, 1.1, "PyroHotDrips")
			drips.Color = colors({ 0, 0.5, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP })
			drips.EmissionDirection = Enum.NormalId.Bottom
			drips.Speed = NumberRange.new(0.2, 1)
			drips.Acceleration = Vector3.new(0, -40, 0)
			drips.Lifetime = NumberRange.new(0.4, 0.7)
			drips.Rate = 14
			show.drips = drips
		end
	elseif kind == "Writhe" then
		SoundLayers.play("BurnScream", victim)
	elseif kind == "StreamEnd" then
		local jet = show.jet
		if jet then
			jet.stop(false)
			show.jet = nil
		end
		SoundLayers.play("StreamEnd", attacker)
		-- a rolling soot cloud over the body
		local torso = bodyPart(victim, "Torso")
		if torso then
			local at = anchorAt(torso.Position + Vector3.new(0, 1, 0))
			local soot = FireLook.layer("smoke", at, 1.6, "PyroSootCloud")
			soot.Color = ColorSequence.new(SOOT, SOOT_THIN)
			soot.Speed = NumberRange.new(1, 3)
			soot.SpreadAngle = Vector2.new(60, 60)
			soot.Acceleration = Vector3.new(0, 2.5, 0)
			soot.Lifetime = NumberRange.new(2, 3.2)
			soot:Emit(math.floor(10 * FireLook.quality()))
			Debris:AddItem(at, 4)
		end
	elseif kind == "Vent" then
		Flamethrower.vent(attacker)
		SoundLayers.play("Vent", attacker)
		local drips = show.drips
		if drips then
			drips.Enabled = false
			Debris:AddItem(drips, 0.8)
			show.drips = nil
		end
	end
end

local function onFinisherStarted(attacker: unknown, victim: unknown, id: unknown)
	if id ~= "Immolate" then
		return
	end
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Model") then
		return
	end
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then
		return
	end
	local cinematic = Finishers.get("Immolate")
	if cinematic == nil then
		return
	end
	local old = shows[attacker]
	if old then
		old.cancelled = true
	end
	local run = newRun(attacker, cinematic.duration)
	local show: Show = {
		cancelled = false,
		run = run,
		pour = {},
		victim = victim,
		pouring = false,
		wet = nil,
		jet = nil,
		drips = nil,
	}
	shows[attacker] = show
	-- The gun on the clip's beats (Animation/PyroClips): drawn, the pilot
	-- lit; stood upright for the Zippo (1.7); back in both hands (2.62);
	-- slung (5.4). Not cut short by the cinematic's own stun.
	local token = run.token
	local function gunAt(time: number, fn: () -> ())
		task.delay(time, function()
			local current = runs[attacker]
			if current and current.token == token and not show.cancelled and attacker.Parent then
				fn()
			end
		end)
	end
	gunAt(0.15, function()
		Flamethrower.draw(attacker)
		SoundLayers.play("GunDraw", attacker)
	end)
	gunAt(0.22, function()
		Flamethrower.setPilot(attacker, true)
	end)
	gunAt(1.7, function()
		Flamethrower.port(attacker, 0.15)
	end)
	gunAt(2.62, function()
		local zippo = run.zippo
		if zippo then
			zippo.setLit(false)
			zippo.setOpen(false)
			SoundLayers.play("ZippoClose", attacker)
			-- (pocketed)
			for _, p in run.folder:GetChildren() do
				if string.sub(p.Name, 1, 5) == "Zippo" then
					p:Destroy()
				end
			end
			run.zippo = nil
		end
		Flamethrower.draw(attacker, 0.15)
	end)
	gunAt(5.4, function()
		Flamethrower.setPilot(attacker, false)
		Flamethrower.holster(attacker)
	end)
	for _, event in cinematic.events do
		task.delay(event.time, function()
			if not show.cancelled and attacker.Parent and victim.Parent then
				finisherEvent(show, event.kind, attacker, victim)
			end
		end)
	end
	task.delay(cinematic.duration, function()
		if shows[attacker] == show then
			shows[attacker] = nil
		end
	end)
end

local function onFinisherEnded(attacker: unknown, victim: unknown, killed: unknown)
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Model") then
		return
	end
	local show = shows[attacker]
	if show == nil or (show.victim :: unknown) ~= victim then
		return
	end
	if killed == true then
		return -- (played on: the body burns)
	end
	show.cancelled = true
	shows[attacker] = nil
	local jet = show.jet
	if jet then
		jet.stop(true)
	end
	if show.drips then
		show.drips.Enabled = false
	end
	Flamethrower.setHeat(attacker, 0)
	endRun(attacker, true)
	stopPyre(show.victim)
end

------------------------------------------------------------------------------

local stepping: RBXScriptConnection? = nil
local function step(dt: number)
	local t = os.clock()
	for index = #flickers, 1, -1 do
		local f = flickers[index]
		if f.light.Parent == nil then
			table.remove(flickers, index)
		else
			local n = math.noise(t * 7, f.seed) * 0.5 + math.noise(t * 17, f.seed + 3) * 0.25
			local up = if f.rise > 0 then math.min(1, (t - f.born) / f.rise) else 1
			f.light.Brightness = math.max(0, f.brightness * up * (1 + n * 0.6))
			f.light.Range = f.range * (1 + n * 0.08)
		end
	end
	stepPools(dt)
end

function PyroFx.start()
	if stepping then
		return
	end
	stepping = RunService.Heartbeat:Connect(step)
	FireLook.preload()
	Remotes.PyroFx.OnClientEvent:Connect(PyroFx.onRemote)
	Remotes.FinisherStarted.OnClientEvent:Connect(onFinisherStarted)
	Remotes.FinisherEnded.OnClientEvent:Connect(onFinisherEnded)
	for _, tag in { Config.Combat.TAG, Config.Combat.CORPSE_TAG } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
		for _, instance in CollectionService:GetTagged(tag) do
			watch(instance)
		end
	end
end

return PyroFx
