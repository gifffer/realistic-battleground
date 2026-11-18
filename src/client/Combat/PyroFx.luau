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
--     Awakening, the finisher's burning body (and its corpse, later).
--   • the finisher "Immolate" (Shared/Finishers), from FinisherStarted.
-- The body's own burning skin and flames: Client/Combat/RiftBurn ("Burning").
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
local EMBER = Color3.fromRGB(255, 132, 40)
local PETROL = Color3.fromRGB(196, 168, 96)
local GLASS = Color3.fromRGB(46, 72, 40) -- a green wine bottle
local SCORCH = Color3.fromRGB(20, 17, 15)
local CHARRED_CLOTH = Color3.fromRGB(58, 48, 42)

local LIGHT_COLOR = Color3.fromRGB(255, 150, 70)

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
type Flicker = { light: PointLight, brightness: number, range: number, seed: number }
local flickers: { Flicker } = {}
local function flicker(light: PointLight, brightness: number, range: number)
	table.insert(flickers, {
		light = light,
		brightness = brightness,
		range = range,
		seed = random:NextNumber(0, 100),
	})
end

local function fireLight(parent: Instance, brightness: number, range: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = LIGHT_COLOR
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	flicker(light, brightness, range)
	return light
end

-- A flash that pops on and dies (the contact frame).
local function flash(position: Vector3, brightness: number, range: number, seconds: number)
	local a = anchorAt(position)
	local light = Instance.new("PointLight")
	light.Color = FLAME_CORE
	light.Brightness = brightness
	light.Range = range
	light.Parent = a
	TweenService:Create(light, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { Brightness = 0 })
		:Play()
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

-- A small steady flame (the lighter's wick, the bottle's rag).
local function smallFlame(at: Attachment, size: number): { ParticleEmitter }
	local flame = emitter(at, {
		Name = "PyroSmallFlame",
		Texture = FIRE_TEXTURE,
		Color = colors({ 0, 0.4, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP }),
		LightEmission = 0.7,
		Size = numbers({ 0, 0.4, 1 }, { size * 0.6, size, size * 0.2 }),
		Transparency = numbers({ 0, 0.2, 1 }, { 0.5, 0.15, 1 }),
		Lifetime = NumberRange.new(0.16, 0.3),
		Speed = NumberRange.new(0.3, 0.8),
		Acceleration = Vector3.new(0, 4 * size / 0.15, 0),
		SpreadAngle = Vector2.new(8, 8),
		Rotation = NumberRange.new(-20, 20),
		Rate = 36,
		ZOffset = 0.1,
	})
	local smoke = emitter(at, {
		Name = "PyroSmallSmoke",
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(SOOT, SOOT_THIN),
		LightInfluence = 1,
		Size = numbers({ 0, 1 }, { size * 0.5, size * 3 }),
		Transparency = numbers({ 0, 0.3, 1 }, { 0.85, 0.7, 1 }),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(0.5, 1),
		Acceleration = Vector3.new(0, 2, 0),
		Drag = 1,
		Rotation = NumberRange.new(0, 360),
		Rate = 6,
		ZOffset = -0.2,
	})
	return { flame, smoke }
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
	local lit: { ParticleEmitter } = {}
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
		setLit = function(on: boolean)
			if on and #lit == 0 then
				lit = smallFlame(wick, 0.12)
				light = fireLight(wick, 1.1, 6)
			elseif not on then
				for _, e in lit do
					e:Destroy()
				end
				lit = {}
				if light then
					light:Destroy()
					light = nil
				end
			end
		end,
	}
	return zippo
end

type Bottle = { main: BasePart, rag: Attachment, light: (on: boolean) -> () }

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
	local lit = false
	return {
		main = body,
		rag = rag,
		light = function(on: boolean)
			if on and not lit then
				lit = true
				smallFlame(rag, 0.22)
				fireLight(rag, 1.4, 8)
			end
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

-- The flare: fluid squirted through the flame, a short burst of fire forward.
local function flare(model: Model, zippo: Zippo)
	local root = bodyPart(model, "HumanoidRootPart")
	local from = zippo.wick.WorldPosition
	local look = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	local at = anchorAt(from, look)
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
	burst:Emit(26)
	flash(from + look * 2, 3, 12, 0.35)
	Debris:AddItem(at, 1)
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

function PyroFx.onAction(model: Model, animation: string)
	local length = CLIP_LENGTHS[animation]
	if length == nil then
		return
	end
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

type Flight = { bottle: Bottle, connection: RBXScriptConnection, trail: Attachment, folder: Folder }
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
	local trail = anchorAt(origin)
	emitter(trail, {
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(SOOT, SOOT_THIN),
		LightInfluence = 1,
		Size = numbers({ 0, 1 }, { 0.2, 1.2 }),
		Transparency = numbers({ 0, 0.2, 1 }, { 0.75, 0.55, 1 }),
		Lifetime = NumberRange.new(0.7, 1.2),
		Speed = NumberRange.new(0, 0.4),
		Acceleration = Vector3.new(0, 2, 0),
		Drag = 2,
		Rotation = NumberRange.new(0, 360),
		Rate = 40,
	})
	-- Tumbling end over end, slowly (a heavy bottle), the rag flame dragged behind.
	local axis = velocity:Cross(Vector3.new(0, 1, 0))
	axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.new(1, 0, 0)
	local spin = random:NextNumber(7, 10)
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local position = origin + velocity * t - Vector3.new(0, 0.5 * gravity * t * t, 0)
		bottle.main.CFrame = CFrame.new(position) * CFrame.fromAxisAngle(axis, -spin * t) * UPRIGHT
		trail.WorldPosition = bottle.rag.WorldPosition
		if t > 4 then
			endFlight(id)
		end
	end)
	flights[id] = { bottle = bottle, connection = connection, trail = trail, folder = folder }
end

-- The fireball: the petrol vapour going up all at once. Full size at once
-- (pop, don't grow), rising, breaking up into black smoke.
local function fireball(position: Vector3, size: number)
	local at = anchorAt(position)
	local core = emitter(at, {
		Texture = FIRE_TEXTURE,
		Color = colors({ 0, 0.25, 0.6, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP, SOOT }),
		LightEmission = 0.75,
		Size = numbers({ 0, 0.15, 1 }, { size * 0.9, size, size * 0.5 }),
		Transparency = numbers({ 0, 0.7, 1 }, { 0.05, 0.35, 1 }),
		Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, 10, 0),
		Drag = 2.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		Rate = 0,
		ZOffset = 0.2,
	})
	core:Emit(math.floor(10 + size * 4))
	local smoke = emitter(at, {
		Texture = SMOKE_TEXTURE,
		Color = ColorSequence.new(SOOT, SOOT_THIN),
		LightInfluence = 1,
		Size = numbers({ 0, 1 }, { size * 0.8, size * 2.2 }),
		Transparency = numbers({ 0, 0.25, 1 }, { 0.4, 0.3, 1 }),
		Lifetime = NumberRange.new(1.6, 2.8),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(50, 50),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 1.2,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Rate = 0,
		ZOffset = -0.3,
	})
	smoke:Emit(math.floor(6 + size * 2))
	flash(position + Vector3.new(0, 1.5, 0), 6, 10 + size * 4, 0.7)
	Debris:AddItem(at, 3.2)
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
	-- The petrol: a splash of drops flung out and down.
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
	splash:Emit(45)
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

type PoolCell = {
	p: Vector3,
	r: number,
	born: number,
	dies: number,
	part: BasePart?,
	scorch: BasePart?,
	emitters: { ParticleEmitter },
	state: number, -- 0 waiting, 1 burning, 2 out
}
type FirePool = {
	id: number,
	started: number,
	seconds: number,
	cells: { PoolCell },
	centre: BasePart,
	smoke: ParticleEmitter,
	embers: ParticleEmitter,
	light: PointLight,
	sound: SoundLayers.Loop,
	scorches: { BasePart },
	over: boolean,
}
local pools: { [number]: FirePool } = {}

local function cellFire(cell: PoolCell)
	local r = cell.r
	local p =
		part("PoolCell", Vector3.new(r * 1.6, 0.3, r * 1.6), FLAME, Enum.Material.SmoothPlastic)
	p.Transparency = 1
	p.Anchored = true
	p.CFrame = CFrame.new(cell.p + Vector3.new(0, 0.2, 0))
	p.Parent = effectsFolder()
	cell.part = p
	-- low licking flames over the area, and fewer tall tongues
	table.insert(
		cell.emitters,
		emitter(p, {
			Texture = FIRE_TEXTURE,
			Color = colors({ 0, 0.3, 0.75, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP, SOOT }),
			LightEmission = 0.6,
			Size = numbers({ 0, 0.3, 1 }, { 0.9, 1.5, 0.5 }),
			Transparency = numbers({ 0, 0.2, 0.8, 1 }, { 0.6, 0.2, 0.5, 1 }),
			Lifetime = NumberRange.new(0.45, 0.8),
			Speed = NumberRange.new(1, 2.5),
			Acceleration = Vector3.new(0, 5, 0),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(10, 10),
			Rotation = NumberRange.new(-25, 25),
			RotSpeed = NumberRange.new(-30, 30),
			Rate = 7,
			ZOffset = 0.1,
		})
	)
	table.insert(
		cell.emitters,
		emitter(p, {
			Texture = FIRE_TEXTURE,
			Color = colors({ 0, 0.25, 0.7, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP, SOOT }),
			LightEmission = 0.7,
			Size = numbers({ 0, 0.25, 1 }, { 0.7, 1.4, 0.3 }),
			Squash = numbers({ 0, 1 }, { 1.2, 0.6 }),
			Transparency = numbers({ 0, 0.25, 1 }, { 0.5, 0.15, 1 }),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(2.5, 4.5),
			Acceleration = Vector3.new(0, 7, 0),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(-10, 10),
			Rate = 3,
			ZOffset = 0.15,
		})
	)
end

local function cellScorch(pool: FirePool, cell: PoolCell, index: number)
	local disc = part(
		"Scorch",
		Vector3.new(0.04, cell.r * 2.3, cell.r * 2.3),
		SCORCH,
		Enum.Material.Slate,
		Enum.PartType.Cylinder
	)
	disc.Transparency = 0.3
	disc.Anchored = true
	disc.CFrame = CFrame.new(cell.p + Vector3.new(0, 0.03 + index * 0.002, 0))
		* CFrame.Angles(0, random:NextNumber(0, 6.28), 0)
		* UPRIGHT
	disc.Parent = effectsFolder()
	cell.scorch = disc
	table.insert(pool.scorches, disc)
end

local function endPool(pool: FirePool, early: boolean)
	if pool.over then
		return
	end
	pool.over = true
	pools[pool.id] = nil
	pool.sound.stop(if early then 0.4 else 1.5)
	pool.smoke.Enabled = false
	pool.embers.Enabled = false
	for _, cell in pool.cells do
		for _, e in cell.emitters do
			e.Enabled = false
		end
		if cell.part then
			Debris:AddItem(cell.part, 1.5)
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
	-- The black mark stays a while, then fades.
	local scorches = pool.scorches
	task.delay(PyroConfig.SCORCH_TIME, function()
		for _, disc in scorches do
			TweenService:Create(disc, TweenInfo.new(3), { Transparency = 1 }):Play()
			Debris:AddItem(disc, 3.2)
		end
	end)
end

local function firePool(data: { [string]: any })
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
	local centre = part(
		"PoolCentre",
		Vector3.new(radius * 1.4, 0.5, radius * 1.4),
		FLAME,
		Enum.Material.SmoothPlastic
	)
	centre.Transparency = 1
	centre.Anchored = true
	centre.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
	centre.Parent = effectsFolder()
	-- One smoke column and one set of embers for the whole pool (the budget).
	local smoke = emitter(centre, {
		Texture = SMOKE_TEXTURE,
		Color = colors({ 0, 0.5, 1 }, { SOOT, SOOT, SOOT_THIN }),
		LightInfluence = 1,
		Size = numbers({ 0, 0.4, 1 }, { 2, 4.5, 8 }),
		Transparency = numbers({ 0, 0.15, 0.7, 1 }, { 0.6, 0.25, 0.55, 1 }),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(3, 5),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 1.5, 0),
		Drag = 0.4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-12, 12),
		Rate = 8,
		ZOffset = -0.5,
	})
	local embers = emitter(centre, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(EMBER),
		LightEmission = 1,
		Size = numbers({ 0, 1 }, { 0.09, 0.03 }),
		Transparency = numbers({ 0, 0.8, 1 }, { 0, 0.3, 1 }),
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(2, 5),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 3, 0),
		Drag = 0.8,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rate = 5,
		ZOffset = 0.3,
	})
	local light = fireLight(centre, 2.2, math.clamp(radius * 3, 14, 26))
	local pool: FirePool = {
		id = id,
		started = os.clock(),
		seconds = seconds,
		cells = {},
		centre = centre,
		smoke = smoke,
		embers = embers,
		light = light,
		sound = SoundLayers.loopOn("PoolFire", centre),
		scorches = {},
		over = false,
	}
	for _, raw in cells :: { any } do
		if
			typeof(raw) == "table"
			and typeof(raw.p) == "Vector3"
			and typeof(raw.r) == "number"
			and typeof(raw.born) == "number"
			and typeof(raw.dies) == "number"
		then
			table.insert(pool.cells, {
				p = raw.p,
				r = raw.r,
				born = raw.born,
				dies = raw.dies,
				part = nil,
				scorch = nil,
				emitters = {},
				state = 0,
			})
		end
	end
	local old = pools[id]
	if old then
		endPool(old, true)
	end
	pools[id] = pool
end

local function stepPools()
	for _, pool in pools do
		local age = os.clock() - pool.started
		local live = 0
		for index, cell in pool.cells do
			if cell.state == 0 and age >= cell.born then
				cell.state = 1
				cellFire(cell)
				cellScorch(pool, cell, index)
			elseif cell.state == 1 and age >= cell.dies then
				cell.state = 2
				for _, e in cell.emitters do
					e.Enabled = false
				end
				if cell.part then
					Debris:AddItem(cell.part, 1.2)
				end
			end
			if cell.state == 1 then
				live += 1
			end
		end
		local share = if #pool.cells > 0 then live / #pool.cells else 0
		pool.smoke.Rate = 2 + 10 * share
		pool.embers.Rate = 1 + 6 * share
		pool.sound.setVolume(0.25 + 0.75 * share)
		for _, f in flickers do
			if f.light == pool.light then
				f.brightness = 0.4 + 2.2 * share
			end
		end
		if age >= pool.seconds + 0.2 then
			endPool(pool, false)
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
		local mouth = Instance.new("Attachment")
		mouth.Name = "PyroBreath"
		mouth.CFrame = CFrame.new(0, -0.25, -0.65)
		mouth.Parent = head
		local jet = emitter(mouth, {
			Texture = FIRE_TEXTURE,
			Color = colors({ 0, 0.15, 0.55, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP, SOOT }),
			LightEmission = 0.7,
			Size = numbers({ 0, 0.2, 0.7, 1 }, { 0.4, 1.6, 3, 2 }),
			Transparency = numbers({ 0, 0.15, 0.8, 1 }, { 0.5, 0.1, 0.5, 1 }),
			Lifetime = NumberRange.new(0.38, 0.52),
			Speed = NumberRange.new(range * 2.2, range * 2.8),
			Drag = 2,
			Acceleration = Vector3.new(0, 6, 0),
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(angle * 0.5, angle * 0.35),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			Rate = 90,
			ZOffset = 0.2,
		})
		local smoke = emitter(mouth, {
			Texture = SMOKE_TEXTURE,
			Color = ColorSequence.new(SOOT, SOOT_THIN),
			LightInfluence = 1,
			Size = numbers({ 0, 1 }, { 1, 4 }),
			Transparency = numbers({ 0, 0.3, 1 }, { 0.9, 0.55, 1 }),
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(range * 0.8, range * 1.2),
			Drag = 1.5,
			Acceleration = Vector3.new(0, 4, 0),
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(angle * 0.6, angle * 0.4),
			Rotation = NumberRange.new(0, 360),
			Rate = 14,
			ZOffset = -0.3,
		})
		local light = fireLight(mouth, 3, range)
		task.delay(seconds, function()
			jet.Enabled = false
			smoke.Enabled = false
			light:Destroy()
			Debris:AddItem(mouth, 1.8)
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

-- His forearms alight (Awakening "BURNING MAN").
type Arms = { emitters: { Instance }, sound: SoundLayers.Loop }
local burningArms: { [Model]: Arms } = setmetatable({}, { __mode = "k" }) :: any
local function refreshArms(model: Model)
	local on = model:GetAttribute("Kit") == PyroConfig.KIT_ID
		and model:GetAttribute("Awakened") == true
	local arms = burningArms[model]
	if on and arms == nil then
		local made: { Instance } = {}
		local soundPart: BasePart? = nil
		for _, name in { "Right Arm", "Left Arm" } do
			local arm = bodyPart(model, name)
			if arm then
				soundPart = soundPart or arm
				local at = Instance.new("Attachment")
				at.Name = "PyroArmFire"
				at.Position = Vector3.new(0, -0.55, 0)
				at.Parent = arm
				table.insert(made, at)
				emitter(at, {
					Texture = FIRE_TEXTURE,
					Color = colors({ 0, 0.3, 0.8, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP, SOOT }),
					LightEmission = 0.65,
					Size = numbers({ 0, 0.3, 1 }, { 0.35, 0.8, 0.2 }),
					Transparency = numbers({ 0, 0.2, 1 }, { 0.5, 0.15, 1 }),
					Lifetime = NumberRange.new(0.3, 0.55),
					Speed = NumberRange.new(0.5, 1.5),
					Acceleration = Vector3.new(0, 7, 0),
					SpreadAngle = Vector2.new(40, 40),
					Rotation = NumberRange.new(-30, 30),
					Rate = 26,
					ZOffset = 0.1,
				})
				emitter(at, {
					Texture = SMOKE_TEXTURE,
					Color = ColorSequence.new(SOOT, SOOT_THIN),
					LightInfluence = 1,
					Size = numbers({ 0, 1 }, { 0.4, 2 }),
					Transparency = numbers({ 0, 0.3, 1 }, { 0.85, 0.65, 1 }),
					Lifetime = NumberRange.new(1, 1.6),
					Speed = NumberRange.new(1, 2),
					Acceleration = Vector3.new(0, 3, 0),
					Drag = 1,
					Rotation = NumberRange.new(0, 360),
					Rate = 5,
					ZOffset = -0.2,
				})
				emitter(at, {
					Texture = SPARK_TEXTURE,
					Color = ColorSequence.new(EMBER),
					LightEmission = 1,
					Size = numbers({ 0, 1 }, { 0.07, 0.02 }),
					Lifetime = NumberRange.new(0.6, 1.2),
					Speed = NumberRange.new(1, 3),
					SpreadAngle = Vector2.new(60, 60),
					Acceleration = Vector3.new(0, 4, 0),
					Rate = 3,
				})
				if name == "Right Arm" then
					fireLight(at, 1.6, 10)
				end
			end
		end
		if soundPart == nil then
			return
		end
		burningArms[model] = {
			emitters = made,
			sound = SoundLayers.loopOn("BodyBurn", soundPart, 0.35),
		}
	elseif not on and arms then
		burningArms[model] = nil
		arms.sound.stop(0.5)
		for _, item in arms.emitters do
			for _, child in item:GetChildren() do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				elseif child:IsA("PointLight") then
					child:Destroy()
				end
			end
			Debris:AddItem(item, 1.6)
		end
	end
end

-- A body burning (the finisher): thick black smoke going up, the fire's
-- sound; on a corpse copy (no RiftBurn there) flames too. Then it smoulders.
type Pyre = { items: { Instance }, sound: SoundLayers.Loop?, stage: number }
local pyres: { [Model]: Pyre } = setmetatable({}, { __mode = "k" }) :: any

local clothesBefore: { [Instance]: Color3 } = setmetatable({}, { __mode = "k" }) :: any
local function charClothes(model: Model, seconds: number)
	for _, item in model:GetChildren() do
		if item:IsA("Clothing") then
			local saved: Color3? = clothesBefore[item]
			if saved == nil then
				clothesBefore[item] = item.Color3
			end
			if seconds <= 0 then
				item.Color3 = CHARRED_CLOTH
			else
				TweenService
					:Create(item :: Instance, TweenInfo.new(seconds), { Color3 = CHARRED_CLOTH })
					:Play()
			end
		end
	end
end

local function uncharClothes(model: Model)
	for _, item in model:GetChildren() do
		local before: Color3? = clothesBefore[item]
		if before and item:IsA("Clothing") then
			item.Color3 = before
			clothesBefore[item] = nil
		end
	end
end

local function stopPyre(model: Model)
	local pyre = pyres[model]
	pyres[model] = nil
	if pyre == nil then
		return
	end
	if pyre.sound then
		pyre.sound.stop(1.2)
	end
	for _, item in pyre.items do
		for _, child in item:GetChildren() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			elseif child:IsA("PointLight") then
				child:Destroy()
			end
		end
		Debris:AddItem(item, 5)
	end
end

local function smokeColumn(at: Attachment, heavy: boolean)
	emitter(at, {
		Texture = SMOKE_TEXTURE,
		Color = colors({ 0, 0.6, 1 }, { SOOT, SOOT, SOOT_THIN }),
		LightInfluence = 1,
		Size = numbers({ 0, 0.4, 1 }, { 1.2, 3, if heavy then 7 else 4 }),
		Transparency = numbers({ 0, 0.15, 0.7, 1 }, { 0.7, if heavy then 0.3 else 0.65, 0.7, 1 }),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(0, 1.2, 0),
		Drag = 0.4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-10, 10),
		Rate = if heavy then 7 else 2.5,
		ZOffset = -0.5,
	})
end

-- stage 1: burning (until `burnLeft` s), 2: smouldering (`smoulderLeft` s).
local function startPyre(model: Model, burnLeft: number, smoulderLeft: number)
	local torso = bodyPart(model, "Torso")
	if torso == nil then
		return
	end
	stopPyre(model)
	local items: { Instance } = {}
	local pyre: Pyre = { items = items, sound = nil, stage = 0 }
	pyres[model] = pyre
	if burnLeft > 0 then
		pyre.stage = 1
		local at = Instance.new("Attachment")
		at.Name = "PyroPyre"
		-- (the smoke column from the body up: world up, whichever way it lies)
		at.Parent = torso
		table.insert(items, at)
		smokeColumn(at, true)
		pyre.sound = SoundLayers.loopOn("BodyBurn", torso)
		if CollectionService:HasTag(model, Config.Combat.CORPSE_TAG) then
			-- a corpse copy: its own flames (RiftBurn only draws fighters)
			for _, name in { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
				local limb = bodyPart(model, name)
				if limb then
					local flames = emitter(limb, {
						Name = "PyroPyreFlames",
						Texture = FIRE_TEXTURE,
						Color = colors({ 0, 0.3, 0.8, 1 }, { FLAME_CORE, FLAME, FLAME_DEEP, SOOT }),
						LightEmission = 0.6,
						Size = numbers({ 0, 0.3, 1 }, { 0.6, 1.3, 0.3 }),
						Transparency = numbers({ 0, 0.2, 1 }, { 0.5, 0.2, 1 }),
						Lifetime = NumberRange.new(0.4, 0.8),
						Speed = NumberRange.new(0.5, 1.5),
						Acceleration = Vector3.new(0, 6, 0),
						Rate = if name == "Torso" then 16 else 7,
						ZOffset = 0.1,
					})
					table.insert(items, flames)
				end
			end
			fireLight(at, 2, 16)
		end
		task.delay(burnLeft, function()
			if pyres[model] == pyre and model.Parent then
				stopPyre(model)
				startPyre(model, 0, smoulderLeft)
			end
		end)
	elseif smoulderLeft > 0 then
		pyre.stage = 2
		local at = Instance.new("Attachment")
		at.Name = "PyroSmoulder"
		at.Parent = torso
		table.insert(items, at)
		smokeColumn(at, false)
		task.delay(smoulderLeft, function()
			if pyres[model] == pyre then
				stopPyre(model)
			end
		end)
	end
end

local function refreshImmolated(model: Model)
	local caught = model:GetAttribute(PyroConfig.IMMOLATED_ATTRIBUTE)
	if typeof(caught) ~= "number" then
		return
	end
	charClothes(model, 0)
	local age = serverNow() - caught
	local burnLeft = PyroConfig.IMMOLATE_BURN - age
	local smoulderLeft = PyroConfig.IMMOLATE_SMOULDER - math.max(0, -burnLeft)
	local pyre = pyres[model]
	if burnLeft > 0 then
		if pyre == nil or pyre.stage ~= 1 then
			startPyre(model, burnLeft, PyroConfig.IMMOLATE_SMOULDER)
		end
	elseif smoulderLeft > 0 and (pyre == nil or pyre.stage ~= 2) then
		startPyre(model, 0, smoulderLeft)
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

type Show = { cancelled: boolean, run: Run?, pour: { ParticleEmitter }, victim: Model }
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
		end
		charClothes(victim, 2.5)
		startPyre(victim, PyroConfig.IMMOLATE_BURN, PyroConfig.IMMOLATE_SMOULDER)
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
	local show: Show = { cancelled = false, run = run, pour = {}, victim = victim }
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
	uncharClothes(show.victim)
end

------------------------------------------------------------------------------

local stepping: RBXScriptConnection? = nil
local function step()
	local t = os.clock()
	for index = #flickers, 1, -1 do
		local f = flickers[index]
		if f.light.Parent == nil then
			table.remove(flickers, index)
		else
			local n = math.noise(t * 7, f.seed) * 0.5 + math.noise(t * 17, f.seed + 3) * 0.25
			f.light.Brightness = math.max(0, f.brightness * (1 + n * 0.6))
			f.light.Range = f.range * (1 + n * 0.08)
		end
	end
	stepPools()
end

function PyroFx.start()
	if stepping then
		return
	end
	stepping = RunService.Heartbeat:Connect(step)
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
