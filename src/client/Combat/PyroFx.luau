--!strict
-- PyroFx: how the Pyromaniac's fire looks and sounds (Shared/Kits/Pyromaniac).
-- Look only: the server decided every hit and every burn (Combat/Gadgets).
--
--   • his props, from the clips (PyroFx.onAction, called by KitEffects): a
--     brass Zippo (lid, wheel, flame), a wine bottle of petrol with a rag in
--     its neck, a red jerrycan, a steel hip flask. Built from parts at real
--     size (1 stud ≈ 36 cm; the lighter a little bigger to be seen).
--   • Remotes.PyroFx (Gadgets): the Molotov flying, breaking (glass, the
--     petrol splash, a fireball that pops at full size), the fire pool (one
--     small fire per server cell, catching outward and dying out one by one;
--     thick black smoke - petrol burns sooty -, embers, one flickering light,
--     a black scorch that stays), the cones (spat flame, flung petrol).
--   • on every fighter: soaked in petrol (drips), his burning forearms in his
--     Awakening, the finisher's burning body's roar (and its corpse's).
--   • the finisher "Immolate" (Shared/Finishers), from FinisherStarted.
-- The burns themselves (degrees on the skin, charred clothes, flames on the
-- body, smoke, smouldering): Client/Combat/Burns, from the server's burn
-- attributes, like every other burn in the game.
-- Every flame is built from Combat/FireLook's layers (looping flame
-- clusters, tongues, core glow, soot, embers, fireballs, a burning film on
-- the floor), each beat on the clip's keyframe (Animation/PyroClips).
-- Sounds: layered cues (Shared/SoundCues, Combat/SoundLayers), silent until
-- their ids are filled in.

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
local SoundLayers = require(script.Parent.SoundLayers)

local PyroFx = {}

local random = Random.new()

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- Petrol burns yellow-orange with a sooty tip, never blue; its smoke is
-- thick and near black, greying as it thins out.
local FLAME_CORE = Color3.fromRGB(255, 226, 160)
local FLAME = Color3.fromRGB(255, 146, 44)
local FLAME_DEEP = Color3.fromRGB(196, 58, 14)
local SOOT = Color3.fromRGB(26, 23, 21)
local SOOT_THIN = Color3.fromRGB(78, 73, 68)
local PETROL = Color3.fromRGB(196, 168, 96)
local GLASS = Color3.fromRGB(46, 72, 40) -- a green wine bottle
local SCORCH = Color3.fromRGB(20, 17, 15)

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

-- A small steady flame (the lighter's wick, the bottle's rag): a looping
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

type Bottle = {
	main: BasePart,
	rag: Attachment,
	light: (on: boolean) -> (),
	flame: () -> SmallFlame?,
}

-- A 75 cl wine bottle (30 cm: 0.85 studs, 7.5 cm across: 0.21), two thirds
-- full of petrol, a torn rag stuffed in the neck. Origin = its body's centre,
-- +Y to the neck.
local function buildBottle(folder: Instance, holder: BasePart?, at: CFrame): Bottle
	local body = part(
		"BottleBody",
		Vector3.new(0.5, 0.21, 0.21),
		GLASS,
		Enum.Material.Glass,
		Enum.PartType.Cylinder
	)
	body.Transparency = 0.45
	if holder then
		weld(holder, body, at * UPRIGHT)
	else
		body.CFrame = at * UPRIGHT
		body.Anchored = true
	end
	body.Parent = folder
	local function add(
		name: string,
		size: Vector3,
		color: Color3,
		material: Enum.Material,
		offset: CFrame,
		shape: Enum.PartType?,
		transparency: number?
	)
		local p = part(name, size, color, material, shape)
		p.Transparency = transparency or 0
		weld(body, p, offset)
		p.Parent = folder
	end
	-- (in the body's space: its X is the bottle's axis, toward the neck)
	add(
		"BottleShoulder",
		Vector3.new(0.1, 0.17, 0.17),
		GLASS,
		Enum.Material.Glass,
		CFrame.new(0.29, 0, 0),
		Enum.PartType.Cylinder,
		0.45
	)
	add(
		"BottleNeck",
		Vector3.new(0.24, 0.085, 0.085),
		GLASS,
		Enum.Material.Glass,
		CFrame.new(0.45, 0, 0),
		Enum.PartType.Cylinder,
		0.4
	)
	add(
		"Petrol",
		Vector3.new(0.34, 0.18, 0.18),
		PETROL,
		Enum.Material.Glass,
		CFrame.new(-0.07, 0, 0),
		Enum.PartType.Cylinder,
		0.35
	)
	add(
		"RagWad",
		Vector3.new(0.12, 0.1, 0.11),
		Color3.fromRGB(176, 166, 146),
		Enum.Material.Fabric,
		CFrame.new(0.6, 0.01, 0) * CFrame.Angles(0.3, 0.2, 0.4)
	)
	add(
		"RagTail",
		Vector3.new(0.24, 0.05, 0.09),
		Color3.fromRGB(150, 138, 118),
		Enum.Material.Fabric,
		CFrame.new(0.48, 0.07, 0.02) * CFrame.Angles(0, 0, math.rad(-20))
	)
	local rag = Instance.new("Attachment")
	rag.Name = "Rag"
	rag.CFrame = CFrame.new(0.66, 0, 0) * CFrame.Angles(0, 0, math.rad(-90))
	rag.Parent = body
	local lit: SmallFlame? = nil
	return {
		main = body,
		rag = rag,
		-- The petrol-soaked rag catches: sparks, the flame grows in 0.25 s.
		light = function(on: boolean)
			if on and lit == nil then
				sparks(rag, 6, 5, 50)
				lit = smallFlame(rag, 0.22, 0.25)
				fireLight(rag, 1.4, 8, 0.25)
			end
		end,
		flame = function(): SmallFlame?
			return lit
		end,
	}
end

-- A 20 l jerrycan (47 × 34 × 17 cm: 1.3 × 0.94 × 0.47 studs), red, held by
-- its top handle. Origin = the handle; the can hangs below it (-Y).
local CAN_RED = Color3.fromRGB(138, 26, 20)
local function buildCan(folder: Instance, holder: BasePart, grip: CFrame): Attachment
	local handle = part(
		"CanHandle",
		Vector3.new(0.07, 0.07, 0.42),
		Color3.fromRGB(30, 28, 26),
		Enum.Material.Metal
	)
	weld(holder, handle, grip)
	handle.Parent = folder
	local body = part("CanBody", Vector3.new(0.47, 1.3, 0.94), CAN_RED, Enum.Material.Metal)
	weld(handle, body, CFrame.new(0, -0.72, 0.05))
	body.Parent = folder
	for _, z in { -0.18, 0.18 } do
		local post = part("CanPost", Vector3.new(0.06, 0.12, 0.06), CAN_RED, Enum.Material.Metal)
		weld(handle, post, CFrame.new(0, -0.05, z))
		post.Parent = folder
	end
	-- the pressed X on its sides
	for _, angle in { 34, -34 } do
		local rib = part(
			"CanRib",
			Vector3.new(0.49, 0.06, 1.2),
			Color3.fromRGB(118, 20, 16),
			Enum.Material.Metal
		)
		weld(body, rib, CFrame.Angles(math.rad(angle), 0, 0))
		rib.Parent = folder
	end
	local cap = part(
		"CanSpout",
		Vector3.new(0.14, 0.12, 0.12),
		Color3.fromRGB(40, 38, 34),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	weld(body, cap, CFrame.new(0, 0.66, -0.38) * UPRIGHT)
	cap.Parent = folder
	local spout = Instance.new("Attachment")
	spout.Name = "Spout"
	spout.Position = Vector3.new(0, 0.74, -0.4)
	spout.Parent = body
	return spout
end

local function buildFlask(folder: Instance, holder: BasePart, grip: CFrame)
	local flask = part(
		"HipFlask",
		Vector3.new(0.3, 0.42, 0.08),
		Color3.fromRGB(150, 150, 146),
		Enum.Material.Metal
	)
	flask.Reflectance = 0.2
	weld(holder, flask, grip)
	flask.Parent = folder
	local cap = part(
		"HipFlaskCap",
		Vector3.new(0.06, 0.07, 0.07),
		Color3.fromRGB(120, 118, 112),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	weld(flask, cap, CFrame.new(0, 0.24, 0) * UPRIGHT)
	cap.Parent = folder
end

-- Grips, in the arm's space (the hand at Y = -1, its front -Z): the prop's
-- +Y goes along the arm's -Z (upright when the arm points forward).
local HAND_UPRIGHT = CFrame.new(0, -1.1, -0.12) * CFrame.Angles(math.rad(-90), 0, 0)
local HAND_HANG = CFrame.new(0, -1.08, 0)

------------------------------------------------------------------------------
-- Moves: props and sounds on the clips' beats
------------------------------------------------------------------------------

type Run = { token: number, folder: Folder, zippo: Zippo?, bottle: Bottle?, spout: Attachment? }
local runs: { [Model]: Run } = setmetatable({}, { __mode = "k" }) :: any
local runToken = 0

local function endRun(model: Model)
	local run = runs[model]
	runs[model] = nil
	if run then
		run.folder:Destroy()
	end
end

local function newRun(model: Model, seconds: number): Run
	endRun(model)
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
			endRun(model)
		end
	end)
	return run
end

-- `fn` at `at` seconds, if this run is still going.
local function beat(model: Model, run: Run, at: number, fn: () -> ())
	local token = run.token
	task.delay(at, function()
		local current = runs[model]
		if current and current.token == token and model.Parent then
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

-- The flare: lighter fluid squirted through the flame. A thin jet of
-- fluid, then (+0.02 s) a burst of fire forward, full size at once (pop,
-- don't grow), rolling up into soot (+0.1 s), embers; one flash.
local function flare(model: Model, zippo: Zippo)
	local root = bodyPart(model, "HumanoidRootPart")
	local from = zippo.wick.WorldPosition
	local look = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	local at = anchorAt(from, look)
	local stream = FireLook.layer("spark", at, 1.4, "PyroFluid")
	stream.Color = ColorSequence.new(PETROL, FLAME)
	stream.LightEmission = 0.5
	stream.Brightness = 1.5
	stream.Speed = NumberRange.new(18, 22)
	stream.Lifetime = NumberRange.new(0.08, 0.12)
	stream.Acceleration = Vector3.zero
	stream.SpreadAngle = Vector2.new(4, 4)
	stream.EmissionDirection = Enum.NormalId.Front
	stream:Emit(10)
	flash(from + look * 1.5, 3, 12, 0.25)
	task.delay(0.02, function()
		if FireLook.has("fireball") then
			local ball = FireLook.layer("fireball", at, 1.7, "PyroFlare")
			ball.EmissionDirection = Enum.NormalId.Front
			ball.Speed = NumberRange.new(8, 12)
			ball.Drag = 6
			ball.SpreadAngle = Vector2.new(12, 12)
			ball.Lifetime = NumberRange.new(0.35, 0.5)
			ball.Size = numbers({ 0, 1 }, { 1.2, 2.2 })
			ball:Emit(5)
		else
			local burst = emitter(at, {
				Texture = FIRE_TEXTURE,
				Color = colors({ 0, 0.3, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP }),
				LightEmission = 0.8,
				Size = numbers({ 0, 0.2, 1 }, { 0.6, 1.4, 0.4 }),
				Transparency = numbers({ 0, 0.6, 1 }, { 0.1, 0.3, 1 }),
				Lifetime = NumberRange.new(0.18, 0.32),
				Speed = NumberRange.new(10, 16),
				Drag = 3,
				SpreadAngle = Vector2.new(14, 14),
				EmissionDirection = Enum.NormalId.Front,
				Rotation = NumberRange.new(0, 360),
				Rate = 0,
			})
			burst:Emit(22)
		end
		local embers = FireLook.layer("ember", at, 1, "PyroFlareEmbers")
		embers.EmissionDirection = Enum.NormalId.Front
		embers.Speed = NumberRange.new(6, 12)
		embers.Lifetime = NumberRange.new(0.5, 1.1)
		embers:Emit(8)
	end)
	task.delay(0.1, function()
		local soot = FireLook.layer("smoke", at, 0.45, "PyroFlareSmoke")
		soot.EmissionDirection = Enum.NormalId.Front
		soot.Speed = NumberRange.new(3, 5)
		soot.Lifetime = NumberRange.new(1, 1.6)
		soot:Emit(3)
	end)
	Debris:AddItem(at, 2.5)
end

local CLIP_LENGTHS: { [string]: number } = {
	Pyro_Zippo = 0.8,
	Pyro_Molotov = 1,
	Pyro_Firebomb = 0.75,
	Pyro_Breath = 1.4,
	Pyro_BreathBig = 1.4,
	Pyro_Douse = 0.9,
	Pyro_Awaken = 1,
	Pyro_FirePunch = 0.6,
	Pyro_Rush = 0.9,
}

-- (set below: the burning forearms of his Awakening)
local armsOnAction: (model: Model, animation: string) -> () = function() end
local awakenStarted: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

function PyroFx.onAction(model: Model, animation: string)
	local length = CLIP_LENGTHS[animation]
	if length == nil then
		return
	end
	if animation == "Pyro_Awaken" then
		awakenStarted[model] = os.clock()
	end
	armsOnAction(model, animation)
	local run = newRun(model, length)
	if animation == "Pyro_Zippo" then
		local zippo = zippoIn(model, run, "Right Arm")
		beat(model, run, 0.15, function()
			if zippo then
				zippo.setOpen(true)
			end
			SoundLayers.play("ZippoOpen", model)
		end)
		beat(model, run, 0.27, function()
			if zippo then
				zippo.setLit(true)
			end
			SoundLayers.play("ZippoStrike", model)
		end)
		beat(model, run, 0.4, function()
			if zippo then
				flare(model, zippo)
			end
			SoundLayers.play("FlameFlare", model)
		end)
		beat(model, run, 0.68, function()
			if zippo then
				zippo.setLit(false)
				zippo.setOpen(false)
			end
			SoundLayers.play("ZippoClose", model)
		end)
	elseif animation == "Pyro_Molotov" or animation == "Pyro_Firebomb" then
		local big = animation == "Pyro_Firebomb"
		local arm = bodyPart(model, "Right Arm")
		local bottle = if arm then buildBottle(run.folder, arm, HAND_UPRIGHT) else nil
		run.bottle = bottle
		if big then
			-- (lit off his own burning fist)
			beat(model, run, 0.12, function()
				if bottle then
					bottle.light(true)
				end
				SoundLayers.play("MolotovLight", model)
			end)
		else
			local zippo = zippoIn(model, run, "Left Arm")
			if zippo then
				zippo.setOpen(true)
			end
			beat(model, run, 0.05, function()
				SoundLayers.play("ZippoOpen", model)
			end)
			beat(model, run, 0.18, function()
				if zippo then
					zippo.setLit(true)
				end
				SoundLayers.play("ZippoStrike", model)
			end)
			beat(model, run, 0.3, function()
				if bottle then
					bottle.light(true)
				end
				SoundLayers.play("MolotovLight", model)
			end)
			beat(model, run, 0.46, function()
				if zippo then
					-- (pocketed)
					zippo.setLit(false)
					for _, p in run.folder:GetChildren() do
						if string.sub(p.Name, 1, 5) == "Zippo" then
							p:Destroy()
						end
					end
				end
			end)
		end
		beat(model, run, if big then 0.36 else 0.62, function()
			SoundLayers.play("MolotovThrow", model)
		end)
	elseif animation == "Pyro_Breath" or animation == "Pyro_BreathBig" then
		local left = bodyPart(model, "Left Arm")
		if left then
			buildFlask(run.folder, left, HAND_UPRIGHT)
		end
		SoundLayers.play("FuelSwig", model)
		beat(model, run, 0.4, function()
			for _, p in run.folder:GetChildren() do
				if string.sub(p.Name, 1, 8) == "HipFlask" then
					p:Destroy()
				end
			end
		end)
		local zippo: Zippo? = nil
		beat(model, run, 0.25, function()
			zippo = zippoIn(model, run, "Right Arm")
			if zippo then
				zippo.setOpen(true)
			end
			SoundLayers.play("ZippoOpen", model)
		end)
		beat(model, run, 0.38, function()
			if zippo then
				zippo.setLit(true)
			end
			SoundLayers.play("ZippoStrike", model)
		end)
		beat(model, run, 1.25, function()
			if zippo then
				zippo.setLit(false)
				zippo.setOpen(false)
			end
			SoundLayers.play("ZippoClose", model)
		end)
	elseif animation == "Pyro_Douse" then
		local arm = bodyPart(model, "Right Arm")
		if arm then
			run.spout = buildCan(run.folder, arm, HAND_HANG)
		end
	elseif animation == "Pyro_Awaken" then
		local zippo = zippoIn(model, run, "Right Arm")
		beat(model, run, 0.15, function()
			if zippo then
				zippo.setOpen(true)
			end
			SoundLayers.play("ZippoOpen", model)
		end)
		beat(model, run, 0.35, function()
			if zippo then
				zippo.setLit(true)
			end
			SoundLayers.play("ZippoStrike", model)
		end)
		beat(model, run, 0.55, function()
			SoundLayers.play("SelfIgnite", model)
		end)
	elseif animation == "Pyro_FirePunch" then
		SoundController.play("HeavySwing", model)
	elseif animation == "Pyro_Rush" then
		SoundController.play("Dash", model)
	end
end

-- Our move was refused by the server: the props go.
function PyroFx.stopAction(model: Model)
	endRun(model)
end

------------------------------------------------------------------------------
-- The Molotov in flight, breaking
------------------------------------------------------------------------------

type Flight = {
	bottle: Bottle,
	connection: RBXScriptConnection,
	trail: Attachment,
	ribbon: { Attachment },
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
	for _, a in flight.ribbon do
		for _, item in a:GetChildren() do
			if item:IsA("Trail") then
				item.Enabled = false
			end
		end
		Debris:AddItem(a, 0.4)
	end
end

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
	local by = data.by
	if typeof(by) == "Instance" and by:IsA("Model") then
		local run = runs[by]
		if run and run.bottle then
			run.bottle.main.Parent = nil -- (it left the hand)
			for _, p in run.folder:GetChildren() do
				if
					string.sub(p.Name, 1, 6) == "Bottle"
					or p.Name == "Petrol"
					or string.sub(p.Name, 1, 3) == "Rag"
				then
					p:Destroy()
				end
			end
			run.bottle = nil
		end
	end
	endFlight(id)
	local folder = Instance.new("Folder")
	folder.Name = "Molotov"
	folder.Parent = effectsFolder()
	local bottle = buildBottle(folder, nil, CFrame.new(origin))
	bottle.light(true)
	-- (welded parts follow the anchored body)
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") and p ~= bottle.main then
			p.Anchored = false
		end
	end
	-- In the air the rag's flame streams out behind it: its flames come
	-- thicker (born where the bottle was: a ribbon of fire), a thin trail of
	-- soot, and (uploaded) a flame ribbon on two points that follow the rag.
	local lit = bottle.flame()
	if lit then
		for _, e in lit.flames do
			e.Rate *= 3
		end
	end
	local trail = anchorAt(origin)
	local soot = FireLook.layer("smoke", trail, 0.22, "PyroTrailSmoke")
	soot.Color = ColorSequence.new(SOOT, SOOT_THIN)
	soot.Transparency = numbers({ 0, 0.2, 1 }, { 0.8, 0.6, 1 })
	soot.Lifetime = NumberRange.new(0.7, 1.2)
	soot.Speed = NumberRange.new(0, 0.4)
	soot.Drag = 2
	soot.Rate = 20 * FireLook.quality()
	local ribbon: { Attachment } = {}
	local strip = FireLook.image("flameStrip")
	if strip then
		local top, bottom = anchorAt(origin), anchorAt(origin)
		ribbon = { top, bottom }
		local t = Instance.new("Trail")
		t.Attachment0 = top
		t.Attachment1 = bottom
		t.Texture = strip
		t.TextureMode = Enum.TextureMode.Stretch
		t.Lifetime = 0.25
		t.FaceCamera = true
		t.LightEmission = 1
		t.Brightness = 2
		t.LightInfluence = 0
		t.Color = ColorSequence.new(Color3.fromRGB(255, 240, 220), FLAME_DEEP)
		t.Transparency = numbers({ 0, 0.6, 1 }, { 0.15, 0.55, 1 })
		t.WidthScale = numbers({ 0, 1 }, { 1, 0.1 })
		t.Parent = top
	end
	-- Tumbling end over end, slowly (a heavy bottle), the rag flame dragged behind.
	local axis = velocity:Cross(Vector3.new(0, 1, 0))
	axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.new(1, 0, 0)
	local spin = random:NextNumber(7, 10)
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local position = origin + velocity * t - Vector3.new(0, 0.5 * gravity * t * t, 0)
		bottle.main.CFrame = CFrame.new(position) * CFrame.fromAxisAngle(axis, -spin * t) * UPRIGHT
		local rag = bottle.rag.WorldPosition
		trail.WorldPosition = rag
		if ribbon[1] then
			ribbon[1].WorldPosition = rag + Vector3.new(0, 0.2, 0)
			ribbon[2].WorldPosition = rag - Vector3.new(0, 0.12, 0)
		end
		if t > 4 then
			endFlight(id)
		end
	end)
	flights[id] = {
		bottle = bottle,
		connection = connection,
		trail = trail,
		ribbon = ribbon,
		folder = folder,
	}
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

local function shatter(position: Vector3, on: Model?)
	-- Glass: a few real pieces that bounce and stay a while, glitter.
	for _ = 1, 8 do
		local size = random:NextNumber(0.05, 0.16)
		local shard = Instance.new("WedgePart")
		shard.Size = Vector3.new(0.02, size, size * random:NextNumber(0.6, 1.4))
		shard.Color = GLASS
		shard.Material = Enum.Material.Glass
		shard.Transparency = 0.35
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0))
			* CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), 0)
		shard.AssemblyLinearVelocity = Vector3.new(
			random:NextNumber(-12, 12),
			random:NextNumber(4, 12),
			random:NextNumber(-12, 12)
		)
		shard.AssemblyAngularVelocity = random:NextUnitVector() * 20
		shard.Parent = effectsFolder()
		Debris:AddItem(shard, 12)
	end
	local at = anchorAt(position + Vector3.new(0, 0.2, 0), Vector3.new(0, 1, 0))
	local glitter = emitter(at, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(Color3.fromRGB(200, 230, 200)),
		LightEmission = 0.4,
		Size = numbers({ 0, 1 }, { 0.12, 0.04 }),
		Transparency = numbers({ 0, 1 }, { 0.2, 1 }),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, -60, 0),
		Rate = 0,
	})
	glitter:Emit(30)
	-- The petrol: drops flung out and down, half of them already burning
	-- (bright arcs of fire falling round the burst).
	local burning = FireLook.layer("spark", at, 2, "PyroBurningDrops")
	burning.Color = colors({ 0, 0.5, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP })
	burning.Size = numbers({ 0, 1 }, { 0.14, 0.05 })
	burning.Speed = NumberRange.new(8, 18)
	burning.SpreadAngle = Vector2.new(75, 75)
	burning.Acceleration = Vector3.new(0, -50, 0)
	burning.Lifetime = NumberRange.new(0.5, 0.8)
	burning:Emit(math.floor(25 * FireLook.quality()))
	local splash = emitter(at, {
		Color = ColorSequence.new(PETROL),
		LightEmission = 0.1,
		LightInfluence = 1,
		Size = numbers({ 0, 1 }, { 0.12, 0.06 }),
		Transparency = numbers({ 0, 0.7, 1 }, { 0.3, 0.4, 1 }),
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(8, 20),
		SpreadAngle = Vector2.new(75, 75),
		Acceleration = Vector3.new(0, -50, 0),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = numbers({ 0, 1 }, { 1.5, 1.5 }),
		Rate = 0,
	})
	splash:Emit(25)
	Debris:AddItem(at, 1.5)
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
	shatter(position, body)
	fireball(
		position,
		if typeof(data.radius) == "number" then math.clamp(data.radius * 0.6, 2.5, 5) else 3
	)
	SoundLayers.playAt("MolotovShatter", position)
	task.delay(0.06, function()
		SoundLayers.playAt("FuelIgnite", position)
	end)
end

------------------------------------------------------------------------------
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
		sound = if quiet then nil else SoundLayers.loopOn("PoolFire", centre),
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
-- Cones: spat flame, flung petrol
------------------------------------------------------------------------------

local function cone(data: { [string]: any })
	local by, kind, range, angle, seconds = data.by, data.kind, data.range, data.angle, data.seconds
	if
		typeof(by) ~= "Instance"
		or not by:IsA("Model")
		or typeof(range) ~= "number"
		or typeof(angle) ~= "number"
		or typeof(seconds) ~= "number"
	then
		return
	end
	local model = by
	local head = bodyPart(model, "Head")
	local root = bodyPart(model, "HumanoidRootPart")
	if head == nil or root == nil then
		return
	end
	if kind == "Flame" then
		SoundLayers.play("FireBreath", model)
		-- (in the head's space: its front is -Z)
		local mouthAt = Vector3.new(0, -0.25, -0.65)
		local mouth = Instance.new("Attachment")
		mouth.Name = "PyroBreath"
		mouth.Position = mouthAt
		mouth.Parent = head
		local q = FireLook.quality()
		-- It starts with a puff of fire at the lips and a spit of fuel.
		local puff = FireLook.layer("fireball", mouth, 1.1, "PyroBreathPuff")
		puff.EmissionDirection = Enum.NormalId.Front
		puff.Speed = NumberRange.new(range * 0.4, range * 0.6)
		puff.SpreadAngle = Vector2.new(25, 25)
		puff.Lifetime = NumberRange.new(0.4, 0.6)
		puff:Emit(3)
		-- The body of the gout: big flame clusters thrown forward, braking,
		-- curling up at the far end.
		local jet = FireLook.layer("body", mouth, 1, "PyroBreathJet")
		jet.Orientation = Enum.ParticleOrientation.FacingCamera
		jet.EmissionDirection = Enum.NormalId.Front
		jet.Size = numbers({ 0, 0.25, 1 }, { 0.4, range * 0.12, range * 0.22 })
		jet.Transparency = numbers({ 0, 0.1, 0.75, 1 }, { 0.6, 0.1, 0.45, 1 })
		jet.Lifetime = NumberRange.new(0.38, 0.52)
		jet.Speed = NumberRange.new(range * 2.2, range * 2.8)
		jet.Drag = 2.5
		jet.Acceleration = Vector3.new(0, 10, 0)
		jet.SpreadAngle = Vector2.new(angle * 0.5, angle * 0.35)
		jet.Rotation = NumberRange.new(0, 360)
		jet.RotSpeed = NumberRange.new(-90, 90)
		jet.Rate = 45 * q
		local smoke = FireLook.layer("smoke", mouth, 0.7, "PyroBreathSmoke")
		smoke.EmissionDirection = Enum.NormalId.Front
		smoke.Color = ColorSequence.new(SOOT, SOOT_THIN)
		smoke.Speed = NumberRange.new(range * 0.8, range * 1.2)
		smoke.Lifetime = NumberRange.new(1, 1.6)
		smoke.Drag = 1.5
		smoke.Acceleration = Vector3.new(0, 4, 0)
		smoke.SpreadAngle = Vector2.new(angle * 0.6, angle * 0.4)
		smoke.Rate = 12 * q
		-- The light sits inside the gout, not at the mouth.
		local lightAt = Instance.new("Attachment")
		lightAt.Name = "PyroBreathLight"
		lightAt.Position = mouthAt + Vector3.new(0, 0, -range * 0.4)
		lightAt.Parent = head
		local light = fireLight(lightAt, 3, range, 0.06)
		-- Uploaded: a continuous jet core (a scrolling flame band on a Beam)
		-- shooting out to its length in 0.08 s, pulled back at the end.
		local beam: Beam? = nil
		local tip: Attachment? = nil
		local strip = FireLook.image("flameStrip")
		if strip then
			local made = Instance.new("Attachment")
			made.Name = "PyroBreathTip"
			made.Position = mouthAt
			made.Parent = head
			tip = made
			local b = Instance.new("Beam")
			b.Attachment0 = mouth
			b.Attachment1 = made
			b.Texture = strip
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = range * 0.35
			b.TextureSpeed = 5
			b.FaceCamera = true
			b.Segments = 12
			b.Width0 = 0.25
			b.Width1 = range * 0.18
			b.LightEmission = 1
			b.Brightness = 3
			b.LightInfluence = 0
			b.Color =
				ColorSequence.new(Color3.fromRGB(255, 244, 226), Color3.fromRGB(255, 176, 110))
			b.Transparency = numbers({ 0, 0.6, 1 }, { 0.15, 0.4, 1 })
			b.Parent = made
			beam = b
			TweenService:Create(
				made,
				TweenInfo.new(0.08),
				{ Position = mouthAt + Vector3.new(0, 0, -range * 0.7) }
			):Play()
		end
		task.delay(seconds, function()
			jet.Enabled = false
			smoke.Enabled = false
			light:Destroy()
			Debris:AddItem(mouth, 1.8)
			Debris:AddItem(lightAt, 0.1)
			if beam and tip then
				-- (the gout lets go of the lips and thins out)
				TweenService:Create(beam, TweenInfo.new(0.1), { Width0 = 0, Width1 = range * 0.05 })
					:Play()
				TweenService:Create(
					tip,
					TweenInfo.new(0.1),
					{ Position = mouthAt + Vector3.new(0, 0.4, -range * 0.85) }
				):Play()
				Debris:AddItem(tip, 0.12)
			end
		end)
	elseif kind == "Fuel" then
		SoundLayers.play("FuelSplash", model)
		local run = runs[model]
		local from = if run and run.spout
			then run.spout.WorldPosition
			else head.Position - Vector3.new(0, 0.8, 0)
		local look = root.CFrame.LookVector
		local at = anchorAt(from, (look + Vector3.new(0, 0.35, 0)).Unit)
		local fuel = emitter(at, {
			Color = ColorSequence.new(PETROL),
			LightInfluence = 1,
			Size = numbers({ 0, 1 }, { 0.14, 0.08 }),
			Transparency = numbers({ 0, 0.8, 1 }, { 0.25, 0.4, 1 }),
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(range * 1.4, range * 2.2),
			Drag = 0.6,
			Acceleration = Vector3.new(0, -40, 0),
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(angle * 0.5, angle * 0.25),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Squash = numbers({ 0, 1 }, { 2, 2 }),
			Rate = 0,
		})
		fuel:Emit(70)
		local mist = emitter(at, {
			Texture = SMOKE_TEXTURE,
			Color = ColorSequence.new(Color3.fromRGB(210, 196, 160)),
			LightInfluence = 1,
			Size = numbers({ 0, 1 }, { 0.6, 2.2 }),
			Transparency = numbers({ 0, 1 }, { 0.85, 1 }),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(range * 0.8, range * 1.2),
			Drag = 2,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(angle * 0.6, angle * 0.3),
			Rate = 0,
		})
		mist:Emit(10)
		Debris:AddItem(at, 1.5)
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
-- Zippo touches the left forearm (0.4: sparks), the left wrap catches and
-- the fire runs up from the wrist to the elbow (0.55), the right one
-- catches (0.63), the arms are flung out (0.75: a burst of fire off each,
-- the light pops). Then they burn like a burning body (FireLook layers on
-- a forearm-sized block) with ONE light on the chest between them. A swing
-- fans them (more flame for an instant); a landed burning hit flares.
local AWAKEN_SPARKS = 0.4
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
		arms.sound = SoundLayers.loopOn("BodyBurn", arm, 0.35)
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
				local arm = bodyPart(model, "Left Arm")
				if arm then
					local spot = Instance.new("Attachment")
					spot.Position = Vector3.new(0, -0.8, -0.3)
					spot.Parent = arm
					sparks(spot, 10, 6, 60)
					Debris:AddItem(spot, 0.7)
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
			arms.sound.stop(0.5)
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
	if animation == "Pyro_FirePunch" then
		fanArms(model, 0.1, 0.25)
	elseif animation == "Pyro_Rush" then
		fanArms(model, 0.1, 0.55)
	end
end

-- A burning fist / rush landed: a flare of fire off the fist that hit, a
-- radial burst of sparks (4 frames), a short flash.
function PyroFx.onHit(victim: Model, attacker: Model, moveId: string)
	if moveId ~= "BurningFist" and moveId ~= "BurningRush" then
		return
	end
	local torso = bodyPart(victim, "Torso")
	if torso == nil then
		return
	end
	local fist: Vector3? = nil
	local best = math.huge
	for _, name in { "Right Arm", "Left Arm" } do
		local arm = bodyPart(attacker, name)
		if arm then
			local position = (arm.CFrame * CFrame.new(0, -1, 0)).Position
			local distance = (position - torso.Position).Magnitude
			if distance < best then
				fist, best = position, distance
			end
		end
	end
	local at = fist or torso.Position
	local anchor = anchorAt(at, torso.Position - at)
	local ball = FireLook.layer("fireball", anchor, 1.5, "PyroImpact")
	ball.EmissionDirection = Enum.NormalId.Front
	ball.Speed = NumberRange.new(2, 5)
	ball.SpreadAngle = Vector2.new(50, 50)
	ball.Lifetime = NumberRange.new(0.4, 0.6)
	ball:Emit(3)
	sparks(anchor, 12, 14, 80)
	flash(at, 4, 10, 0.2)
	Debris:AddItem(anchor, 1.5)
end

-- A body burning (the finisher): the fire's roar while it burns. Its burns,
-- charred clothes, flames, smoke and light are Client/Combat/Burns (the
-- server's burn attributes, a corpse copy too).
type Pyre = { sound: SoundLayers.Loop, endsAt: number }
local pyres: { [Model]: Pyre } = setmetatable({}, { __mode = "k" }) :: any

local function stopPyre(model: Model)
	local pyre = pyres[model]
	pyres[model] = nil
	if pyre then
		pyre.sound.stop(1.2)
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
		pyres[model] = { sound = SoundLayers.loopOn("BodyBurn", torso), endsAt = endsAt }
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
	refreshDoused(model)
	refreshArms(model)
	refreshImmolated(model)
end

------------------------------------------------------------------------------
-- The finisher "Immolate"
------------------------------------------------------------------------------

type Show = {
	cancelled: boolean,
	run: Run?,
	pour: { ParticleEmitter },
	victim: Model,
	pouring: boolean,
	wet: BasePart?,
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

-- The lit Zippo tossed from his hand onto their chest (an arc, 0.25 s).
local function tossZippo(zippo: Zippo, victim: Model)
	local torso = bodyPart(victim, "Torso")
	local main = zippo.main
	local from = main.CFrame
	local to = if torso then torso.CFrame * CFrame.new(0, 0, -0.55) else from - Vector3.new(0, 2, 0)
	-- (free of the hand: every part of it follows the case)
	for _, w in main:GetChildren() do
		if w:IsA("Weld") then
			w:Destroy()
		end
	end
	main.Anchored = true
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local u = math.min(1, (os.clock() - started) / 0.25)
		local position = from.Position:Lerp(to.Position, u)
			+ Vector3.new(0, math.sin(u * math.pi) * 0.4, 0)
		main.CFrame = CFrame.new(position) * from.Rotation:Lerp(to.Rotation, u)
		if u >= 1 and connection then
			connection:Disconnect()
		end
	end)
end

local function finisherEvent(show: Show, kind: string, attacker: Model, victim: Model)
	local run = show.run
	if kind == "Uncap" then
		SoundLayers.play("FuelPour", attacker)
	elseif kind == "Douse" then
		-- It splashes off his head and shoulders all the while it pours,
		-- and soaks the floor under him.
		show.pouring = true
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
		local spout = if run then run.spout else nil
		if spout then
			local stream = emitter(spout, {
				Color = ColorSequence.new(PETROL),
				LightInfluence = 1,
				Size = numbers({ 0, 1 }, { 0.1, 0.07 }),
				Transparency = numbers({ 0, 1 }, { 0.25, 0.45 }),
				Lifetime = NumberRange.new(0.45, 0.6),
				Speed = NumberRange.new(2, 3.5),
				SpreadAngle = Vector2.new(6, 6),
				EmissionDirection = Enum.NormalId.Front,
				Acceleration = Vector3.new(0, -30, 0),
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				Squash = numbers({ 0, 1 }, { 2.5, 2.5 }),
				Rate = 90,
			})
			table.insert(show.pour, stream)
		end
	elseif kind == "DouseEnd" then
		show.pouring = false
		for _, e in show.pour do
			e.Enabled = false
		end
	elseif kind == "CanAway" then
		SoundLayers.play("CanThrow", attacker)
		if run then
			-- the can thrown out to his right: loose, it tumbles and stays
			local root = bodyPart(attacker, "HumanoidRootPart")
			local push = if root
				then root.CFrame.RightVector * 14 + Vector3.new(0, 8, 0)
				else Vector3.new(0, 8, 0)
			local handle: BasePart? = nil
			for _, p in run.folder:GetChildren() do
				if p:IsA("BasePart") and string.sub(p.Name, 1, 3) == "Can" then
					if p.Name == "CanHandle" then
						handle = p
						local w = p:FindFirstChildOfClass("Weld")
						if w then
							w:Destroy() -- (off his hand; the rest stays welded to it)
						end
					end
					p.Massless = false
					p.CanCollide = p.Name == "CanBody"
					p.Parent = effectsFolder()
					Debris:AddItem(p, 15)
				end
			end
			if handle then
				handle.AssemblyLinearVelocity = push
				handle.AssemblyAngularVelocity = Vector3.new(0, 0, 6)
			end
			run.spout = nil
		end
	elseif kind == "Open" then
		if run then
			local zippo = zippoIn(attacker, run, "Right Arm")
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
	elseif kind == "Release" then
		SoundLayers.play("ZippoDrop", victim)
		if run and run.zippo then
			tossZippo(run.zippo, victim)
		end
	elseif kind == "Ignite" then
		local torso = bodyPart(victim, "Torso")
		if torso then
			SoundLayers.playAt("BodyIgnite", torso.Position, torso)
			fireball(torso.Position + Vector3.new(0, 0.5, 0), 3.2)
			floorFire(show, attacker)
		end
		startPyre(victim, PyroConfig.IMMOLATE_BURN)
		if run and run.zippo then
			run.zippo.setLit(false) -- (it's in the fire now)
		end
	elseif kind == "Writhe" then
		SoundLayers.play("BurnScream", victim)
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
	local arm = bodyPart(attacker, "Right Arm")
	if arm then
		run.spout = buildCan(run.folder, arm, HAND_HANG)
	end
	local show: Show =
		{ cancelled = false, run = run, pour = {}, victim = victim, pouring = false, wet = nil }
	shows[attacker] = show
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
	endRun(attacker)
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
