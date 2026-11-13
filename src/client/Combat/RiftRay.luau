--!strict
-- RiftRay: Dr. Rift's ray gun and overcharged ray, on this client (look
-- only; Server/Combat/Gadgets traced it): the beam from his gun to where it
-- stopped, the muzzle flash, the impact.
--
--   RiftRay.ray(data, muzzleOf)    Remotes.RiftFx "Ray" { by, from, to, width, big }
--
-- The event arrives at the shot. Timeline (seconds after it):
--   0 - CHARGE        the muzzle flares (white core, orange glow, light)
--   CHARGE + EXTEND   the beam shoots out to `to` (layered Beams: white-hot
--                     core, orange glow, wavering heat haze; the big one
--                     also two energy strands spiralling round it)
--   then              impact: flash, sparks, molten droplets, a scorch mark
--                     that cools yellow -> red -> black and smokes, a heat
--                     shimmer; the big one blows up on every body it pierces
--   fade              the glow goes first, the core thins to a line, a dull
--                     red afterglow and smoke stay along the path a moment.
-- One RenderStepped connection per shot drives the beam (widths, wobble,
-- flicker, lights); everything else is tweens + Debris.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local P = require(script.Parent.RiftParts)

local RiftRay = {}

local RAY_CORE = P.RAY_CORE
local RAY_GLOW = P.RAY_GLOW
local FIRE = P.FIRE
local FIRE_HOT = P.FIRE_HOT
local SMOKE = P.SMOKE
local ghost = P.ghost
local emitter = P.emitter
local sparkTexture = P.sparkTexture
local fade = P.fade
local shakeNear = P.shakeNear

local WHITE = Color3.new(1, 1, 1)
local HAZE = Color3.fromRGB(255, 70, 25)
local EMBER = Color3.fromRGB(200, 45, 15)
local CHAR = Color3.fromRGB(26, 21, 19)
local COOLED = Color3.fromRGB(38, 14, 9)
local SHIMMER = Color3.fromRGB(255, 130, 70)

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local CHARGE = 0.05 -- the muzzle flare before the beam
local ARC = 0.5523 -- cubic Bezier handle for a quarter circle (x radius)
local MAX_SCORCHES = 20
local MAX_BLASTS = 8 -- body explosions per overcharged shot

local random = Random.new()

-- Scorch marks still on the world, oldest first (capped): the marks' folder
-- and the smoke vent over it (which lives on Terrain).
local scorches: { { folder: Instance, vent: Instance? } } = {}

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

local function around(value: number, spread: number): number
	return value * (1 + random:NextNumber(-spread, spread))
end

-- Smooth noise in about -1..1.
local function wobble(t: number, seed: number): number
	return math.clamp(math.noise(t, seed, 0.37) * 2, -1, 1)
end

-- 1 until `fadeAt`, then down to 0 at `fadeEnd` (fast at first).
local function envelope(t: number, fadeAt: number, fadeEnd: number): number
	if t <= fadeAt then
		return 1
	end
	local u = math.clamp((t - fadeAt) / (fadeEnd - fadeAt), 0, 1)
	return (1 - u) * (1 - u)
end

-- A frame at `position` whose Y axis is `up` (particles emit along Top).
local function upFrame(position: Vector3, up: Vector3): CFrame
	local u = up.Unit
	local side = if math.abs(u.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local right = side:Cross(u).Unit
	return CFrame.fromMatrix(position, right, u)
end

-- An attachment left in the world (Terrain), removed after `seconds`.
local function pointAt(frame: CFrame, seconds: number): Attachment
	local point = Instance.new("Attachment")
	point.Parent = workspace.Terrain
	point.WorldCFrame = frame
	Debris:AddItem(point, seconds)
	return point
end

local function sequence(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function colors(points: { { any } }): ColorSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, ColorSequenceKeypoint.new(p[1] :: number, p[2] :: Color3))
	end
	return ColorSequence.new(keys)
end

local function newBeam(
	parent: Instance,
	a0: Attachment,
	a1: Attachment,
	props: { [string]: any }
): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.LightInfluence = 0
	beam.LightEmission = 1
	beam.Segments = 12
	for key, value in props do
		(beam :: any)[key] = value
	end
	beam.Parent = parent
	return beam
end

-- An anchored, invisible part to hang attachments and beams on.
local function rig(name: string, frame: CFrame, seconds: number): Part
	local part = ghost(name, Vector3.new(0.2, 0.2, 0.2), WHITE, Enum.Material.SmoothPlastic)
	part.Transparency = 1
	part.Anchored = true
	part.CFrame = frame
	part.Parent = workspace
	Debris:AddItem(part, seconds)
	return part
end

local function ball(
	position: Vector3,
	size: number,
	color: Color3,
	transparency: number,
	material: Enum.Material?
): Part
	local part = ghost(
		"RayBall",
		Vector3.one * size,
		color,
		material or Enum.Material.Neon,
		Enum.PartType.Ball
	)
	part.Anchored = true
	part.Transparency = transparency
	part.CFrame = CFrame.new(position)
	part.Parent = workspace
	return part
end

-- A ball that pops out to `size` in `grow` seconds, then shrinks / fades.
local function pop(
	position: Vector3,
	size: number,
	color: Color3,
	transparency: number,
	grow: number,
	decay: number
)
	local part = ball(position, size * 0.25, color, transparency)
	Debris:AddItem(part, grow + decay + 0.3)
	TweenService:Create(
		part,
		TweenInfo.new(grow, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * size }
	):Play()
	task.delay(grow, function()
		if part.Parent then
			fade(part, decay, { Size = Vector3.one * size * 1.35 })
		end
	end)
end

-- A shimmering shell (ForceField material reads as heat haze / distortion).
-- (a Ball part: its size stays uniform, so it grows from `from` to `to`
-- studs across and any rise is in its position)
local function shimmer(
	position: Vector3,
	from: number,
	to: number,
	rise: Vector3,
	transparency: number,
	seconds: number
)
	local part = ghost(
		"RayShimmer",
		Vector3.one * from,
		SHIMMER,
		Enum.Material.ForceField,
		Enum.PartType.Ball
	)
	part.Anchored = true
	part.Transparency = transparency
	part.CFrame = CFrame.new(position)
	part.Parent = workspace
	TweenService
		:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Size = Vector3.one * to,
			CFrame = CFrame.new(position + rise),
			Transparency = 1,
		})
		:Play()
	Debris:AddItem(part, seconds + 0.05)
end

local function flashLight(
	parent: Instance,
	color: Color3,
	brightness: number,
	range: number,
	seconds: number
): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	TweenService:Create(
		light,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	):Play()
	return light
end

------------------------------------------------------------------------------
-- Particles
------------------------------------------------------------------------------

-- Hot streaks flying off along the point's up axis.
local function sparks(
	point: Attachment,
	spread: number,
	speed: number,
	size: number
): ParticleEmitter
	local particles = emitter(point, {
		Color = colors({ { 0, WHITE }, { 0.25, FIRE_HOT }, { 1, RAY_GLOW } }),
		LightEmission = 1,
		LightInfluence = 0,
		Size = sequence({ { 0, size }, { 0.6, size * 0.7 }, { 1, 0 } }),
		Squash = NumberSequence.new(2.2),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Lifetime = NumberRange.new(0.12, 0.45),
		Speed = NumberRange.new(speed * 0.45, speed),
		SpreadAngle = Vector2.new(spread, spread),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 3,
		Acceleration = Vector3.new(0, -55, 0),
		ZOffset = 0.3,
	})
	sparkTexture(particles)
	return particles
end

-- Molten droplets: heavier, slower, cooling as they fall.
local function droplets(
	point: Attachment,
	spread: number,
	speed: number,
	size: number
): ParticleEmitter
	local particles = emitter(point, {
		Color = colors({ { 0, FIRE_HOT }, { 0.3, FIRE }, { 0.7, EMBER }, { 1, COOLED } }),
		Transparency = sequence({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
		LightEmission = 0.7,
		LightInfluence = 0,
		Size = sequence({ { 0, size }, { 1, size * 0.5 } }),
		Squash = NumberSequence.new(0.9),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Lifetime = NumberRange.new(0.5, 1.1),
		Speed = NumberRange.new(speed * 0.4, speed),
		SpreadAngle = Vector2.new(spread, spread),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 0.8,
		Acceleration = Vector3.new(0, -75, 0),
	})
	sparkTexture(particles)
	return particles
end

-- A ball of flame (fire texture), for the bursts on bodies.
local function fireball(point: Attachment, size: number): ParticleEmitter
	return emitter(point, {
		Texture = FIRE_TEXTURE,
		Color = colors({ { 0, FIRE_HOT }, { 0.25, FIRE }, { 0.6, RAY_GLOW }, { 1, EMBER } }),
		Transparency = sequence({ { 0, 0.05 }, { 0.6, 0.35 }, { 1, 1 } }),
		LightEmission = 1,
		LightInfluence = 0,
		Size = sequence({ { 0, size * 0.4 }, { 0.4, size }, { 1, size * 1.3 } }),
		Lifetime = NumberRange.new(0.22, 0.5),
		Speed = NumberRange.new(size * 1.5, size * 4.5),
		Drag = 5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
		ZOffset = 0.5,
	})
end

-- Grey smoke, lit by the scene.
local function smoke(
	point: Attachment,
	size: number,
	life: number,
	opacity: number
): ParticleEmitter
	return emitter(point, {
		Texture = SMOKE_TEXTURE,
		Color = colors({ { 0, Color3.fromRGB(40, 36, 33) }, { 1, SMOKE } }),
		Transparency = sequence({
			{ 0, 1 },
			{ 0.12, 1 - opacity },
			{ 0.6, 1 - opacity * 0.6 },
			{ 1, 1 },
		}),
		LightEmission = 0,
		LightInfluence = 1,
		Size = sequence({ { 0, size * 0.35 }, { 1, size } }),
		Lifetime = NumberRange.new(life * 0.6, life),
		Speed = NumberRange.new(0.8, 2.5),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 3.5, 0),
		Drag = 0.8,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-35, 35),
	})
end

------------------------------------------------------------------------------
-- Shockwave ring (four Beams bent into a circle, opening out)
------------------------------------------------------------------------------

local function ring(
	center: Vector3,
	normal: Vector3,
	r0: number,
	r1: number,
	seconds: number,
	color: Color3,
	width: number
)
	local holder = rig("RayRing", upFrame(center, normal), seconds + 0.5)
	local points: { Attachment } = {}
	local radials: { Vector3 } = {}
	local tangents: { Vector3 } = {}
	local roll = random:NextNumber(0, math.pi / 2)
	for i = 1, 4 do
		local angle = roll + (i - 1) * math.pi / 2
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		radials[i] = radial
		tangents[i] = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local point = Instance.new("Attachment")
		point.Parent = holder
		points[i] = point
	end
	local beams: { Beam } = {}
	local tint = colors({ { 0, WHITE }, { 0.5, color }, { 1, WHITE } })
	for i = 1, 4 do
		beams[i] = newBeam(holder, points[i], points[i % 4 + 1], {
			Color = tint,
			Transparency = NumberSequence.new(0.15),
			Segments = 10,
			ZOffset = 0.2,
		})
	end
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		local p = math.min(elapsed / seconds, 1)
		if p >= 1 or holder.Parent == nil then
			connection:Disconnect()
			holder:Destroy()
			return
		end
		local eased = 1 - (1 - p) ^ 3
		local radius = r0 + (r1 - r0) * eased
		local w = width * (1 - p) ^ 1.5
		for i = 1, 4 do
			points[i].CFrame = CFrame.fromMatrix(radials[i] * radius, tangents[i], radials[i])
			local beam = beams[i]
			beam.CurveSize0 = ARC * radius
			beam.CurveSize1 = ARC * radius
			beam.Width0 = w
			beam.Width1 = w
		end
	end)
end

------------------------------------------------------------------------------
-- Impacts
------------------------------------------------------------------------------

local function worldParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(Config.Combat.TAG)
	params.RespectCanCollide = true
	return params
end

-- A flat ellipse lying on a surface (`frame` Z = the surface normal).
local function mark(
	name: string,
	frame: CFrame,
	size: Vector2,
	color: Color3,
	material: Enum.Material,
	transparency: number
): Part
	local part = ghost(name, Vector3.new(size.X, size.Y, 0.04), color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Anchored = true
	part.Transparency = transparency
	part.CFrame = frame
	return part
end

-- Colour changes one after another (each tween started when the last ends).
local function tweenColor(part: BasePart, stops: { { any } })
	local delay = 0
	for _, stop in stops do
		local color, seconds = stop[1] :: Color3, stop[2] :: number
		task.delay(delay, function()
			if part.Parent then
				TweenService:Create(
					part,
					TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Color = color }
				):Play()
			end
		end)
		delay += seconds
	end
end

-- The glowing melt / scorch where the ray burnt the wall or the floor: it
-- cools from white-yellow to red to a black char, smokes, then goes.
local function scorch(position: Vector3, normal: Vector3, dir: Vector3, big: boolean, hold: number)
	local radius = if big then around(1.6, 0.15) else around(0.6, 0.15)
	-- Stretched along the beam when it grazes the surface.
	local along = dir - normal * dir:Dot(normal)
	local stretch = 1
	if along.Magnitude > 0.05 then
		stretch = math.clamp(1 / math.max(math.abs(dir:Dot(normal)), 0.35), 1, 2.6)
		along = along.Unit
	else
		along = upFrame(position, normal).XVector
	end
	local side = along:Cross(normal)
	-- X = across, Y = along the beam, Z = out of the surface.
	local base = CFrame.fromMatrix(position, side, along, normal)
		* CFrame.Angles(0, 0, random:NextNumber(-0.25, 0.25))
	local cool = if big then 3.2 else 2.2
	local life = hold + cool + (if big then 5 else 3)

	local folder = Instance.new("Folder")
	folder.Name = "RayScorch"
	folder.Parent = workspace
	Debris:AddItem(folder, life + 2)
	local record: { folder: Instance, vent: Instance? } = { folder = folder, vent = nil }
	table.insert(scorches, record)
	while #scorches > MAX_SCORCHES do
		local oldest = table.remove(scorches, 1)
		if oldest then
			oldest.folder:Destroy()
			if oldest.vent then
				oldest.vent:Destroy()
			end
		end
	end
	-- (gone from the list once Debris takes it)
	folder.Destroying:Connect(function()
		local index = table.find(scorches, record)
		if index then
			table.remove(scorches, index)
		end
	end)

	-- Char (dark, matte), the melt (Neon, cooling), the white-hot core.
	local char = mark(
		"Char",
		base * CFrame.new(0, 0, 0.03),
		Vector2.new(radius * 1.1, radius * 1.1 * stretch),
		CHAR,
		Enum.Material.Slate,
		0.15
	)
	char.Parent = folder
	TweenService
		:Create(char, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(radius * 2.4, radius * 2.4 * stretch, 0.04),
		})
		:Play()
	local melt = mark(
		"Melt",
		base * CFrame.new(0, 0, 0.05),
		Vector2.new(radius * 1.4, radius * 1.4 * stretch),
		FIRE_HOT,
		Enum.Material.Neon,
		0
	)
	melt.Parent = folder
	tweenColor(melt, {
		{ FIRE_HOT, hold + 0.05 },
		{ FIRE, cool * 0.2 },
		{ EMBER, cool * 0.35 },
		{ COOLED, cool * 0.45 },
	})
	local core = mark(
		"Core",
		base * CFrame.new(0, 0, 0.07),
		Vector2.new(radius * 0.7, radius * 0.7 * stretch),
		WHITE,
		Enum.Material.Neon,
		0
	)
	core.Parent = folder
	TweenService:Create(
		core,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, hold),
		{
			Transparency = 1,
			Color = FIRE_HOT,
			Size = Vector3.new(radius * 0.3, radius * 0.3 * stretch, 0.04),
		}
	):Play()
	-- Splashes of molten metal round the big one.
	if big then
		for _ = 1, random:NextInteger(3, 5) do
			local angle = random:NextNumber(0, math.pi * 2)
			local reach = radius * random:NextNumber(1.1, 1.9)
			local size = radius * random:NextNumber(0.2, 0.4)
			local splash = mark(
				"Splash",
				base
					* CFrame.new(math.cos(angle) * reach, math.sin(angle) * reach * stretch, 0.05)
					* CFrame.Angles(0, 0, angle),
				Vector2.new(size * 1.8, size),
				FIRE_HOT,
				Enum.Material.Neon,
				0
			)
			splash.Parent = folder
			tweenColor(
				splash,
				{ { FIRE, hold + 0.3 }, { EMBER, cool * 0.3 }, { COOLED, cool * 0.4 } }
			)
		end
	end
	-- Its glow on the surroundings, dying as it cools.
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Brightness = if big then 4 else 2.5
	light.Range = if big then 14 else 8
	light.Shadows = false
	light.Parent = melt
	TweenService:Create(
		light,
		TweenInfo.new(cool, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, hold),
		{ Brightness = 0, Color = EMBER }
	):Play()

	-- Smoke rising off it, thinning as it cools.
	local vent = pointAt(upFrame(position + normal * 0.15, normal), life)
	record.vent = vent
	local fumes = smoke(vent, if big then 4.5 else 2.4, if big then 2.8 else 2, 0.55)
	fumes:Emit(if big then 6 else 3)
	fumes.Rate = if big then 16 else 9
	task.delay(hold + cool * 0.4, function()
		fumes.Rate = if big then 6 else 3
	end)
	task.delay(hold + cool, function()
		fumes.Rate = 0
	end)
	-- Rising heat shimmer.
	local s = radius * 2.2
	shimmer(position + normal * 0.4, s, s * 1.7, Vector3.new(0, s * 1.2, 0), 0.55, hold + 1.3)

	-- Then everything fades (the char last).
	task.delay(hold + cool, function()
		if folder.Parent == nil then
			return
		end
		for _, part in { melt, core } do
			if part.Parent then
				fade(part, 1.2)
			end
		end
		task.delay(life - hold - cool - 1.6, function()
			if char.Parent then
				fade(char, 1.5)
			end
		end)
	end)
end

-- The beam striking a wall / the floor.
local function wallImpact(
	position: Vector3,
	normal: Vector3,
	dir: Vector3,
	big: boolean,
	hold: number
)
	local scale = if big then 1.8 else 1
	-- Flash: a white pop inside an orange one.
	pop(position, around(1.3 * scale, 0.15), WHITE, 0, 0.04, 0.12)
	pop(position, around(3 * scale, 0.15), RAY_GLOW, 0.45, 0.06, 0.22)
	-- Sprays off the surface, between the bounce and the normal.
	local bounce = dir - normal * 2 * dir:Dot(normal)
	local spray = (bounce + normal * 1.4).Unit
	local point = pointAt(upFrame(position + normal * 0.1, spray), hold + 1.6)
	local streaks = sparks(point, 55, 45 * scale, 0.16 * scale)
	streaks:Emit(math.floor(around(28 * scale, 0.2)))
	-- (and keep spraying while the beam is on)
	streaks.Rate = 90 * scale
	local drops = droplets(point, 50, 20 * scale, 0.2 * scale)
	drops:Emit(math.floor(around(12 * scale, 0.25)))
	drops.Rate = 20 * scale
	task.delay(hold, function()
		streaks.Rate = 0
		drops.Rate = 0
	end)
	flashLight(point, FIRE, 7 * scale, 16 * scale, hold + 0.4)
	scorch(position, normal, dir, big, hold)
	if big then
		ring(position + normal * 0.2, normal, 0.6, 7, 0.45, FIRE, 0.7)
		local blast = pointAt(upFrame(position + normal * 0.3, normal), 2)
		fireball(blast, 2.4):Emit(10)
	end
	local sizzle = SoundController.playAt("Burn", position)
	if sizzle then
		sizzle.Volume *= 0.55
	end
	shakeNear(position, if big then 1.6 else 0.8, if big then 0.3 else 0.2)
end

-- The beam burning into / through a body. `position` is on the beam's line
-- at the middle of the body: the flash is where it goes in (the shooter's
-- side), the blast comes out of the back.
local function bodyImpact(position: Vector3, dir: Vector3, big: boolean, hold: number)
	local scale = if big then 1.6 else 0.8
	local entry = position - dir * 0.8
	pop(entry, around(1.6 * scale, 0.15), WHITE, 0, 0.04, 0.1)
	pop(entry, around(3.6 * scale, 0.15), FIRE, 0.4, 0.06, 0.25)
	-- Sparks spat back towards the gun from where it burns in.
	local front = pointAt(upFrame(entry, -dir), hold + 1.2)
	sparks(front, 50, 30 * scale, 0.12 * scale):Emit(math.floor(around(14 * scale, 0.2)))
	flashLight(front, FIRE, 6 * scale, 12 * scale, hold + 0.3)
	-- Out the back (the way the ray goes) and round about.
	local exit = pointAt(upFrame(position + dir * 0.6, dir), hold + 1.6)
	sparks(exit, 40, 50 * scale, 0.15 * scale):Emit(math.floor(around(26 * scale, 0.2)))
	droplets(exit, 70, 16 * scale, 0.16 * scale):Emit(math.floor(around(8 * scale, 0.3)))
	local burst = fireball(exit, 2 * scale)
	burst:Emit(math.floor(around(12 * scale, 0.2)))
	local puff = smoke(exit, 3.5 * scale, 1.6, 0.5)
	puff.SpreadAngle = Vector2.new(180, 180)
	puff:Emit(math.floor(4 * scale))
	flashLight(exit, FIRE, 8 * scale, 14 * scale, hold + 0.35)
	if big then
		ring(position, dir, 0.8, 5.5, 0.35, FIRE_HOT, 0.5)
		shimmer(position, 2, 8, Vector3.new(0, 1, 0), 0.5, 0.45)
	end
	shakeNear(position, if big then 1.2 else 0.7, 0.18)
end

-- Ran out of range in the air: the beam frays out.
local function airImpact(position: Vector3, dir: Vector3, big: boolean, hold: number)
	local scale = if big then 1.5 else 1
	pop(position, around(1.4 * scale, 0.15), RAY_GLOW, 0.3, 0.05, 0.2)
	local point = pointAt(upFrame(position, dir), hold + 1)
	sparks(point, 70, 20 * scale, 0.12 * scale):Emit(math.floor(around(14 * scale, 0.2)))
	flashLight(point, RAY_GLOW, 3 * scale, 10 * scale, hold + 0.2)
end

-- The fighters the beam goes through (the closest point of the beam to each,
-- 0..1 along it): the same reach the server uses, roughly.
local function bodiesAlong(
	start: Vector3,
	to: Vector3,
	width: number,
	by: Instance?
): { { at: Vector3, t: number } }
	local found: { { at: Vector3, t: number } } = {}
	local ab = to - start
	local length2 = ab:Dot(ab)
	if length2 < 1e-6 then
		return found
	end
	local reach = width / 2 + 1.3
	for _, model in CollectionService:GetTagged(Config.Combat.TAG) do
		if model ~= by and model:IsA("Model") then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local body = root.Position
				local raw = (body - start):Dot(ab) / length2
				local t = math.clamp(raw, 0, 1)
				local onLine = start + ab * t
				local offset = body - onLine
				-- (not behind the gun, not past where it stopped)
				local inRange = raw * math.sqrt(length2) > -0.5
					and (raw - 1) * math.sqrt(length2) < 1.5
				if
					inRange
					and Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach
					and math.abs(offset.Y) <= 3.5
				then
					table.insert(found, { at = onLine, t = t })
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return a.t < b.t
	end)
	return found
end

------------------------------------------------------------------------------
-- Rays
------------------------------------------------------------------------------

type Layer = {
	beam: Beam,
	width: number,
	flare: number, -- Width1 / Width0 (spreads at the far end)
	amp: number, -- curve wobble, studs
	freq: number,
	seed: number,
	fadeAt: number,
	fadeEnd: number,
	speed: number, -- TextureSpeed (kept steady: the scroll follows the clock)
	flicker: number, -- width jitter
}

type Tip = { point: Attachment, roll: CFrame }

function RiftRay.ray(data: { [string]: any }, muzzleOf: (model: Model) -> Vector3?)
	local from, to, width, big = data.from, data.to, data.width, data.big == true
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or typeof(width) ~= "number" then
		return
	end
	local by = data.by
	local start = from
	local shooter: Instance? = nil
	if typeof(by) == "Instance" then
		shooter = by
		if by:IsA("Model") then
			start = muzzleOf(by) or from
		end
	end
	local length = (to - start).Magnitude
	if length < 0.1 then
		return
	end
	local dir = (to - start).Unit
	width = math.clamp(width, 0.2, 4)

	-- Timings (seconds after the charge).
	local extend = if big then 0.06 else 0.035
	local hold = if big then 0.42 else 0.1 -- full power
	local fadeEnd = hold + (if big then 0.24 else 0.14)
	local afterEnd = fadeEnd + (if big then 0.6 else 0.4)
	local total = CHARGE + afterEnd + 0.05

	-- The rig: Z axis along the beam (it spins round it).
	local base = CFrame.lookAt(start, to)
	local holder = rig("RayBeam", base, total + 1)
	local layers: { Layer } = {}
	local tips: { Tip } = {}

	local function addLayer(props: { [string]: any }, spec: { [string]: number }): Layer
		local roll = CFrame.Angles(0, 0, random:NextNumber(0, math.pi))
		local a0 = Instance.new("Attachment")
		a0.CFrame = roll
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.CFrame = roll
		a1.Parent = holder
		table.insert(tips, { point = a1, roll = roll })
		props.Enabled = false
		props.Width0 = 0
		props.Width1 = 0
		local layer: Layer = {
			beam = newBeam(holder, a0, a1, props),
			width = spec.width,
			flare = spec.flare or 1,
			amp = spec.amp or 0,
			freq = spec.freq or 8,
			seed = random:NextNumber(0, 1000),
			fadeAt = spec.fadeAt or hold,
			fadeEnd = spec.fadeEnd or fadeEnd,
			speed = spec.speed or 0,
			flicker = spec.flicker or 0.1,
		}
		table.insert(layers, layer)
		return layer
	end

	-- Outer heat haze: wide, faint, smoky, wavering.
	addLayer({
		Color = colors({ { 0, FIRE }, { 0.2, HAZE }, { 1, EMBER } }),
		Transparency = sequence({ { 0, 0.9 }, { 0.15, 0.72 }, { 0.85, 0.75 }, { 1, 0.85 } }),
		Texture = SMOKE_TEXTURE,
		TextureMode = Enum.TextureMode.Wrap,
		TextureLength = 7,
		LightEmission = 0.6,
		ZOffset = -0.1,
	}, {
		width = width * (if big then 4.2 else 3),
		flare = 1.5,
		amp = width * (if big then 1.4 else 0.9),
		freq = 3,
		speed = -around(1.2, 0.3),
		flicker = 0.2,
		fadeAt = hold * 0.8,
		fadeEnd = fadeEnd + 0.08,
	})
	if big then
		-- A second, wilder haze for the overcharged one.
		addLayer({
			Color = colors({ { 0, FIRE_HOT }, { 0.3, RAY_GLOW }, { 1, HAZE } }),
			Transparency = sequence({ { 0, 0.85 }, { 0.2, 0.7 }, { 1, 0.8 } }),
			Texture = FIRE_TEXTURE,
			TextureMode = Enum.TextureMode.Wrap,
			TextureLength = 5,
			LightEmission = 0.8,
			ZOffset = -0.05,
		}, {
			width = width * 2.8,
			flare = 1.3,
			amp = width * 0.9,
			freq = 5,
			speed = around(3, 0.2),
			flicker = 0.28,
		})
	end
	-- Orange glow: fire texture streaming down the beam, crackling.
	addLayer({
		Color = colors({ { 0, FIRE_HOT }, { 0.12, FIRE }, { 0.4, RAY_GLOW }, { 1, RAY_GLOW } }),
		Transparency = sequence({ { 0, 0.15 }, { 1, 0.3 } }),
		Texture = FIRE_TEXTURE,
		TextureMode = Enum.TextureMode.Wrap,
		TextureLength = 3.5,
		ZOffset = 0,
	}, {
		width = width * (if big then 1.9 else 1.5),
		flare = 1.15,
		amp = width * 0.25,
		freq = 11,
		speed = around(6, 0.2),
		flicker = 0.26,
		fadeAt = hold,
		fadeEnd = fadeEnd - 0.03,
	})
	-- White-hot core: solid, nearly straight, the last to go (thins to a line).
	addLayer({
		Color = colors({ { 0, WHITE }, { 0.5, RAY_CORE }, { 1, WHITE } }),
		Transparency = NumberSequence.new(0),
		Segments = 8,
		ZOffset = 0.1,
	}, {
		width = width * (if big then 0.55 else 0.4),
		amp = width * 0.06,
		freq = 14,
		flicker = 0.12,
		fadeAt = hold + 0.02,
		fadeEnd = fadeEnd,
	})
	-- A dull red afterglow that lingers and curls once the rest is gone.
	addLayer({
		Color = colors({ { 0, EMBER }, { 1, Color3.fromRGB(120, 30, 12) } }),
		Transparency = sequence({ { 0, 0.55 }, { 0.5, 0.45 }, { 1, 0.6 } }),
		LightEmission = 0.5,
		ZOffset = -0.02,
	}, {
		width = width * 0.3,
		amp = width * 0.6,
		freq = 1.5,
		flicker = 0.05,
		fadeAt = fadeEnd,
		fadeEnd = afterEnd,
	})

	-- Overcharged: two energy strands spiralling round the beam (a helix of
	-- Beams, one per quarter turn); the rig spins, so they run along it.
	local strands: { Beam } = {}
	local strandWidth = width * 0.16
	if big then
		local pitch = math.clamp(length / 9, 4, 9)
		local quarters = math.clamp(math.floor(length / pitch * 4), 4, 32)
		local step = length / quarters
		local radius = width * 0.95
		local tint = colors({ { 0, WHITE }, { 0.5, FIRE_HOT }, { 1, FIRE } })
		for strand = 0, 1 do
			local phase = strand * math.pi + random:NextNumber(-0.3, 0.3)
			local previous: Attachment? = nil
			local previousCurve = 0
			for i = 0, quarters do
				local theta = phase + i * math.pi / 2
				local d = i * step
				-- (tight at the muzzle, opening out)
				local r = radius * (0.35 + 0.65 * math.min(1, d / 4))
				local radial = Vector3.new(math.cos(theta), math.sin(theta), 0)
				local handle = Vector3.new(-math.sin(theta), math.cos(theta), 0) * (ARC * r)
					+ Vector3.new(0, 0, -step / 3)
				local point = Instance.new("Attachment")
				point.CFrame =
					CFrame.fromMatrix(radial * r + Vector3.new(0, 0, -d), handle.Unit, radial)
				point.Parent = holder
				if previous then
					table.insert(
						strands,
						newBeam(holder, previous, point, {
							Color = tint,
							Transparency = NumberSequence.new(0.1),
							Segments = 6,
							CurveSize0 = previousCurve,
							CurveSize1 = handle.Magnitude,
							Width0 = 0,
							Width1 = 0,
							Enabled = false,
							ZOffset = 0.15,
						})
					)
				end
				previous = point
				previousCurve = handle.Magnitude
			end
		end
	end

	-- Light along the beam (a few lights spread on it) and at the muzzle.
	local lights: { PointLight } = {}
	local lightCount = math.clamp(math.floor(length / 14), 1, if big then 4 else 3)
	for i = 1, lightCount do
		local point = Instance.new("Attachment")
		point.CFrame = CFrame.new(0, 0, -length * (i - 0.5) / lightCount)
		point.Parent = holder
		local light = Instance.new("PointLight")
		light.Color = RAY_GLOW
		light.Brightness = 0
		light.Range = if big then 16 else 10
		light.Shadows = false
		light.Parent = point
		table.insert(lights, light)
	end
	local muzzlePoint = Instance.new("Attachment")
	muzzlePoint.Parent = holder
	local muzzleLight = Instance.new("PointLight")
	muzzleLight.Color = FIRE
	muzzleLight.Brightness = 0
	muzzleLight.Range = if big then 20 else 12
	muzzleLight.Shadows = false
	muzzleLight.Parent = muzzlePoint

	-- The muzzle flare: a white core in an orange glow.
	local flareCore = ball(start, 0.1, WHITE, 0)
	flareCore.Parent = holder
	local flareGlow = ball(start, 0.1, FIRE, 0.45)
	flareGlow.Parent = holder
	-- (capped: the big one must not swallow the shooter)
	local corePeak = math.min(width * (if big then 2.6 else 1.7), 1.4)
	local glowPeak = math.min(width * (if big then 5.5 else 3.4), 3.2)

	-- A shimmering heat sheath round the whole beam.
	task.delay(CHARGE, function()
		if holder.Parent == nil then
			return
		end
		-- (starts a little in front of the gun, so it doesn't wrap him)
		local gap = math.min(if big then 2 else 1.2, length * 0.3)
		local sheathLength = length - gap
		if sheathLength < 0.5 then
			return
		end
		local d = math.min(width * (if big then 3.4 else 2.2), if big then 2.4 else 1.5)
		local sheath = ghost(
			"RaySheath",
			Vector3.new(sheathLength, d, d),
			SHIMMER,
			Enum.Material.ForceField,
			Enum.PartType.Cylinder
		)
		sheath.Anchored = true
		sheath.Transparency = if big then 0.45 else 0.65
		local middle = start + dir * (gap + sheathLength / 2)
		sheath.CFrame = CFrame.lookAt(middle, to) * CFrame.Angles(0, math.rad(90), 0)
		sheath.Parent = holder
		fade(sheath, fadeEnd + 0.15, { Size = Vector3.new(sheathLength, d * 1.4, d * 1.4) })
	end)

	-- Muzzle: sparks forward, and for the big one a shockwave and a kick.
	task.delay(CHARGE, function()
		local point = pointAt(upFrame(start, dir), 2)
		sparks(point, if big then 35 else 25, if big then 40 else 26, width * 0.25):Emit(
			if big then 26 else 10
		)
		local puff = smoke(point, width * (if big then 6 else 3), 1.2, 0.35)
		puff.SpreadAngle = Vector2.new(60, 60)
		puff:Emit(if big then 6 else 2)
		if big then
			ring(start + dir * 0.6, dir, 0.4, 5, 0.4, FIRE_HOT, 0.8)
			task.delay(0.05, function()
				ring(start + dir * 1.5, dir, 0.3, 3.5, 0.35, RAY_GLOW, 0.45)
			end)
			shimmer(start + dir * 2.5, 1.5, 6, Vector3.zero, 0.4, 0.4)
			shakeNear(start, 2.4, 0.4)
		end
	end)

	-- Impacts: bodies as the beam reaches them, then its end.
	-- (the small one stops on the first body: `to` is then in it; the big one
	-- goes through them all and ends on a wall or in the air)
	local bodies = bodiesAlong(start, to, width, shooter)
	local endsOnBody = false
	if not big then
		local last = bodies[#bodies]
		endsOnBody = last ~= nil and last.t > 0.9
	else
		for index, body in bodies do
			if index > MAX_BLASTS then
				break
			end
			task.delay(CHARGE + extend * body.t, function()
				bodyImpact(body.at, dir, true, hold)
			end)
		end
	end
	task.delay(CHARGE + extend, function()
		if endsOnBody then
			bodyImpact(to, dir, big, hold)
			return
		end
		local surface = workspace:Raycast(to - dir * 1, dir * 2.5, worldParams())
		if surface and (surface.Position - to).Magnitude < 2 then
			wallImpact(surface.Position, surface.Normal, dir, big, hold)
		else
			airImpact(to, dir, big, hold)
		end
	end)

	-- Smoke left hanging along the path as the beam dies.
	task.delay(CHARGE + hold, function()
		local count = math.clamp(math.floor(length / 10), 1, 6)
		for i = 1, count do
			local at = start + dir * (length * (i - random:NextNumber(0.2, 0.8)) / count)
			local wisp =
				smoke(pointAt(CFrame.new(at), 3), width * (if big then 4 else 2.5), 1.6, 0.25)
			wisp.SpreadAngle = Vector2.new(180, 180)
			wisp:Emit(if big then 3 else 1)
		end
	end)

	-- Per frame: grow out, wobble, flicker, fade.
	-- (the strands' angle grows with the distance down the beam, so turning
	-- the rig the negative way runs them towards the target)
	local spin = if big then -25 else random:NextNumber(-5, 5)
	local elapsed = 0
	local extended = false
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= total or holder.Parent == nil then
			connection:Disconnect()
			holder:Destroy()
			return
		end
		holder.CFrame = base * CFrame.Angles(0, 0, spin * elapsed)
		-- The charge: the muzzle flares up before the beam.
		if elapsed < CHARGE then
			local c = elapsed / CHARGE
			flareCore.Size = Vector3.one * (corePeak * 0.6 * c * c)
			flareGlow.Size = Vector3.one * (glowPeak * 0.5 * c)
			muzzleLight.Brightness = 6 * c
			return
		end
		local t = elapsed - CHARGE
		-- Out to the end, then held.
		if not extended then
			local reach = math.min(t / extend, 1)
			for _, tip in tips do
				tip.point.CFrame = CFrame.new(0, 0, -length * reach) * tip.roll
			end
			for _, layer in layers do
				layer.beam.Enabled = true
			end
			if reach >= 1 then
				extended = true
				for _, beam in strands do
					beam.Enabled = true
				end
			end
		end
		-- The impact frame: fat and bright right as it lands, then settles.
		local punch = if t < extend then 1.15 else 1 + 0.55 * math.max(0, 1 - (t - extend) / 0.09)
		for _, layer in layers do
			local env = envelope(t, layer.fadeAt, layer.fadeEnd)
			local beam = layer.beam
			if env <= 0 then
				beam.Enabled = false
			else
				local w = layer.width
					* env
					* punch
					* (1 + layer.flicker * wobble(t * 30, layer.seed + 3))
				beam.Width0 = w
				beam.Width1 = w * layer.flare
				beam.CurveSize0 = layer.amp * wobble(t * layer.freq, layer.seed)
				beam.CurveSize1 = layer.amp * wobble(t * layer.freq, layer.seed + 11)
			end
		end
		local glow = envelope(t, hold, fadeEnd)
		if #strands > 0 then
			local w = strandWidth * glow * punch * (1 + 0.25 * wobble(t * 30, 71))
			for _, beam in strands do
				beam.Width0 = w
				beam.Width1 = w
			end
		end
		local flick = 1 + 0.2 * wobble(t * 24, 37)
		for _, light in lights do
			light.Brightness = (if big then 4 else 2.5) * glow * punch * flick
		end
		muzzleLight.Brightness = (if big then 7 else 4.5) * glow * flick
		-- Muzzle: snaps from the charge peak down to a flickering hold.
		local settle = math.max(0, 1 - t / 0.08)
		local core = corePeak * (0.55 + 0.45 * settle) * glow * (1 + 0.15 * wobble(t * 30, 53))
		local outer = glowPeak * (0.5 + 0.5 * settle) * glow * (1 + 0.15 * wobble(t * 26, 61))
		flareCore.Size = Vector3.one * math.max(core, 0.01)
		flareGlow.Size = Vector3.one * math.max(outer, 0.01)
		flareCore.Transparency = if glow <= 0 then 1 else 0
		flareGlow.Transparency = if glow <= 0 then 1 else 0.45
	end)
	-- (its sound plays from the move's start, at the shot: RiftFx.onAction;
	-- the impacts shake the camera as they land)
end

return RiftRay
