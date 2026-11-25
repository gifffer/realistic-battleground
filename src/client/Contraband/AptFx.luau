--!strict
-- AptFx: the small visual effects of the flat (Flat 4B) and its hidden lab, on this screen only.
--
-- Recipes only: Controllers/ApartmentAmbienceController decides WHEN (rooms, timers, culling).
-- Built from the roblox-vfx rules and the art direction (docs/references/README.md):
--   • particles are discreet: a low Rate, the density comes from a long Lifetime; every
--     particle fades IN and OUT (its Transparency starts and ends at 1), never pops;
--   • only the two built-in textures (no upload): sparkles_main (dust motes, drops, sparks)
--     and smoke_main (dust puff, cold vapour, freezer mist, floor haze);
--   • things that live in the room's light have LightInfluence ≥ 0.6 (a mote is lit by the
--     bulb, dark when it dies); only the spark glows by itself (LightEmission 1);
--   • one-shots = Rate 0 + Emit(n); every temporary part is destroyed after its life.
--
-- HOSTS: the server's flat model (LabBuilder) has a folder "Fx" with invisible host parts
-- named like the recipes below. If a host is missing, we make our own invisible client part
-- at the place DESIGN gives (AptFx.HOSTS), so the effect still works.
--
-- API
--   AptFx.HOSTS                       { HostSpec }: name, local position, size, room
--   AptFx.makeHost(spec, origin, parent)  a client host part (when the model has none)
--   AptFx.emitter(name, host)         the ParticleEmitter of a host (nil = none for it)
--   AptFx.splash(position, parent)    a tiny host + the splash emitter of a drip landing
--   AptFx.ring(position, size, parent)  the ripple ring of a drop (a disc that widens, fades)
--   AptFx.sparkFlash(host)            a 0.08 s warm flash light at the spark
--   AptFx.swinger(model, axis)        a hanging thing that can swing (the entry pendant)
--   AptFx.spinner(model)              turns around its pivot's X axis (the box fan)
--   AptFx.sway(instance, seed)        a plastic sheet swaying around its top edge
--   AptFx.curtain(model)              the strip curtain that parts around the player
--   AptFx.moth(parent)                a moth orbiting a bulb
--   AptFx.fly(centre, parent)         a fly wandering near the kitchen sink
--   AptFx.monitor(screen)             the lab CRT's idle culture graph (SurfaceGui)

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AptFx = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

------------------------------------------------------------------------------
-- Hosts (fallback places, flat-local: origin = floor-top centre, +Z into the flat)
------------------------------------------------------------------------------

export type HostSpec = {
	name: string,
	at: Vector3, -- centre, flat-local
	size: Vector3,
	zone: string, -- the room it belongs to (culling)
	landY: number?, -- drips: flat-local height where the drop lands
}

AptFx.HOSTS = {
	-- entrance
	{
		name = "Dust_Threshold",
		at = Vector3.new(-8, 0.2, -23.2),
		size = Vector3.new(4, 0.3, 1),
		zone = "Entry",
	},
	{
		name = "Motes_Entry",
		at = Vector3.new(-8, 6, -19),
		size = Vector3.new(5, 4, 5),
		zone = "Entry",
	},
	-- corridor
	{
		name = "Motes_Corridor",
		at = Vector3.new(-9, 7, -1),
		size = Vector3.new(5, 4, 5),
		zone = "Corridor",
	},
	{
		name = "Drip_Corridor",
		at = Vector3.new(-8.4, 10.4, 5.2),
		size = Vector3.new(0.2, 0.2, 0.2),
		zone = "Corridor",
		landY = 0.8,
	},
	-- (the lab door is in the X = 10 wall: the gap runs along Z)
	{
		name = "Vapour_LabDoor",
		at = Vector3.new(9.6, 0.1, 15),
		size = Vector3.new(0.4, 0.2, 3.6),
		zone = "Corridor",
	},
	{
		name = "Motes_Bend",
		at = Vector3.new(-9, 7, 15),
		size = Vector3.new(4, 3, 4),
		zone = "Corridor",
	},
	{
		name = "Motes_LabDoor",
		at = Vector3.new(7.5, 2, 15),
		size = Vector3.new(3, 2, 3),
		zone = "Corridor",
	},
	-- lab
	{
		name = "Bubbles_Tank",
		at = Vector3.new(25.8, 5.55, 22.6),
		size = Vector3.new(0.6, 0.1, 0.6),
		zone = "Lab",
	},
	{
		name = "Mist_Freezer",
		at = Vector3.new(12.95, 2.95, 21.3),
		size = Vector3.new(0.3, 0.1, 4.2),
		zone = "Lab",
	},
	{
		name = "Motes_Lamp",
		at = Vector3.new(19, 5.5, 11),
		size = Vector3.new(3, 3, 3),
		zone = "Lab",
	},
	{
		name = "Spark_Strip",
		at = Vector3.new(27.45, 1.25, 15),
		size = Vector3.new(0.3, 0.1, 0.3),
		zone = "Lab",
	},
	{
		name = "Drip_Lab",
		at = Vector3.new(25, 2.1, 21),
		size = Vector3.new(0.2, 0.2, 0.2),
		zone = "Lab",
		landY = 0.3,
	},
	{
		name = "Breath_Floor",
		at = Vector3.new(19, 0.15, 12),
		size = Vector3.new(14, 0.2, 18),
		zone = "Lab",
	},
} :: { HostSpec }

-- An invisible, non-colliding client part to hold an emitter or a sound.
local function hostPart(name: string, cframe: CFrame, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

function AptFx.makeHost(spec: HostSpec, origin: CFrame, parent: Instance): BasePart
	local part = hostPart(spec.name, origin * CFrame.new(spec.at), spec.size, parent)
	part:SetAttribute("Zone", spec.zone)
	return part
end

------------------------------------------------------------------------------
-- Emitters
------------------------------------------------------------------------------

-- NumberSequence from { time, value } pairs (times 0 → 1).
local function sequence(points: { { number } }): NumberSequence
	local keypoints = {}
	for _, point in points do
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2], point[3] or 0))
	end
	return NumberSequence.new(keypoints)
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function newEmitter(host: BasePart, texture: string): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AptFx"
	emitter.Texture = texture
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Enabled = false
	emitter.Parent = host
	return emitter
end

-- Dust motes floating in a light (a few, alive for a long time: never a cloud).
local function motes(host: BasePart, color: Color3, rate: number): ParticleEmitter
	local emitter = newEmitter(host, SPARKLE)
	emitter.Color = ColorSequence.new(color)
	emitter.Size = sequence({ { 0, 0 }, { 0.15, 0.05 }, { 0.85, 0.05 }, { 1, 0 } })
	emitter.Transparency = sequence({ { 0, 1 }, { 0.2, 0.45 }, { 0.8, 0.45 }, { 1, 1 } })
	emitter.Lifetime = NumberRange.new(6, 10)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.05, 0.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -0.02, 0)
	emitter.Drag = 1
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.LightEmission = 0.25
	emitter.LightInfluence = 0.6
	emitter:SetAttribute("BaseRate", rate)
	return emitter
end

-- A falling drop (Rate 0: the controller calls Emit(1) on its own timer, so the splash is
-- in sync). Lifetime = the fall time from the host down to `landY`.
local function drop(host: BasePart, color: Color3, fall: number): ParticleEmitter
	local emitter = newEmitter(host, SPARKLE)
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(0.06)
	emitter.Transparency = sequence({ { 0, 0.2 }, { 0.9, 0.2 }, { 1, 1 } })
	emitter.Lifetime = NumberRange.new(fall)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(0)
	emitter.Acceleration = Vector3.new(0, -60, 0)
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.LightEmission = 0.1
	emitter.LightInfluence = 1
	emitter.Enabled = true -- (Rate 0: nothing comes out by itself)
	return emitter
end

-- The fall time (s) of a drop from height `height` (studs) at the drop's -60 gravity.
function AptFx.fallTime(height: number): number
	return math.sqrt(2 * math.max(height, 0.2) / 60)
end

-- The face of `host` that looks most toward the world direction `direction`.
local function faceToward(host: BasePart, direction: Vector3): Enum.NormalId
	local best = Enum.NormalId.Top
	local bestDot = -math.huge
	for _, face in Enum.NormalId:GetEnumItems() do
		local normal = host.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face :: Enum.NormalId))
		local dot = normal:Dot(direction)
		if dot > bestDot then
			bestDot = dot
			best = face :: Enum.NormalId
		end
	end
	return best
end

-- The emitter of the host called `name` (nil if that host has no particle recipe).
-- `fall` = the drop's fall time, for the two drip hosts. If the server gave the host an
-- "Aim" attribute (a world direction), the particles leave by the face that looks that way.
function AptFx.emitter(name: string, host: BasePart, fall: number?): ParticleEmitter?
	local emitter = AptFx.recipe(name, host, fall)
	local aim = host:GetAttribute("Aim")
	if emitter and typeof(aim) == "Vector3" and aim.Magnitude > 1e-3 then
		emitter.EmissionDirection = faceToward(host, aim.Unit)
	end
	return emitter
end

-- The bare recipe (see AptFx.emitter).
function AptFx.recipe(name: string, host: BasePart, fall: number?): ParticleEmitter?
	if name == "Dust_Threshold" then
		-- the front door "opened": a low puff of dust rolling into the flat (+Z)
		local emitter = newEmitter(host, SMOKE)
		emitter.Color = ColorSequence.new(rgb(120, 110, 100))
		emitter.Size = NumberSequence.new(0.6, 1.6)
		emitter.Transparency = sequence({ { 0, 1 }, { 0.15, 0.9 }, { 0.7, 0.93 }, { 1, 1 } })
		emitter.Lifetime = NumberRange.new(1.2, 2)
		emitter.Rate = 0
		emitter.Speed = NumberRange.new(0.8, 1.6)
		emitter.EmissionDirection = Enum.NormalId.Back -- (the Back face looks to +Z)
		emitter.SpreadAngle = Vector2.new(40, 10)
		emitter.Drag = 3
		emitter.Acceleration = Vector3.new(0, 0.15, 0)
		emitter.RotSpeed = NumberRange.new(-15, 15)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.Enabled = true
		return emitter
	elseif name == "Motes_Entry" then
		return motes(host, rgb(255, 224, 178), 4)
	elseif name == "Motes_Corridor" then
		return motes(host, rgb(255, 224, 178), 5)
	elseif name == "Motes_Bend" then
		return motes(host, rgb(240, 226, 200), 2)
	elseif name == "Motes_LabDoor" then
		-- cold specks in the light leaking from the lab: depth toward the end of the corridor
		return motes(host, rgb(200, 236, 230), 2)
	elseif name == "Motes_Lamp" then
		return motes(host, rgb(210, 236, 232), 4)
	elseif name == "Drip_Corridor" then
		return drop(host, rgb(70, 66, 56), fall or 0.57)
	elseif name == "Drip_Lab" then
		return drop(host, rgb(200, 225, 222), fall or 0.25)
	elseif name == "Vapour_LabDoor" then
		-- THE discovery cue: cold vapour creeping out under the lab door, sinking (-X)
		local emitter = newEmitter(host, SMOKE)
		emitter.Color = ColorSequence.new(rgb(170, 212, 205))
		emitter.Size = NumberSequence.new(1, 2.5)
		-- (peaks at 0.86 with a little emission: still faint, but readable on the dark floor)
		emitter.Transparency = sequence({ { 0, 1 }, { 0.3, 0.86 }, { 0.7, 0.9 }, { 1, 1 } })
		emitter.Lifetime = NumberRange.new(3, 5)
		emitter.Rate = 2
		emitter.Speed = NumberRange.new(0.3, 0.5)
		emitter.EmissionDirection = Enum.NormalId.Left -- (the Left face looks to -X)
		emitter.SpreadAngle = Vector2.new(25, 5)
		emitter.Acceleration = Vector3.new(0, -0.05, 0)
		emitter.Drag = 0.5
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-8, 8)
		emitter.LightEmission = 0.25
		emitter.LightInfluence = 0.6
		emitter:SetAttribute("BaseRate", 2)
		return emitter
	elseif name == "Bubbles_Tank" then
		local emitter = newEmitter(host, SPARKLE)
		emitter.Color = ColorSequence.new(rgb(220, 255, 248))
		emitter.Size = NumberSequence.new(0.05, 0.1)
		emitter.Transparency = sequence({ { 0, 0.4 }, { 0.8, 0.4 }, { 1, 1 } })
		emitter.Lifetime = NumberRange.new(0.6, 0.9)
		emitter.Rate = 12
		emitter.Speed = NumberRange.new(1.5, 2.5)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(8, 8)
		emitter.LightEmission = 0.3
		emitter.LightInfluence = 0.8
		emitter:SetAttribute("BaseRate", 12)
		return emitter
	elseif name == "Mist_Freezer" then
		-- cold mist slipping out of the freezer lid's seam and rolling down its side
		local emitter = newEmitter(host, SMOKE)
		emitter.Color = ColorSequence.new(rgb(205, 225, 228))
		emitter.Size = NumberSequence.new(0.8, 2)
		emitter.Transparency = sequence({ { 0, 1 }, { 0.25, 0.94 }, { 1, 1 } })
		emitter.Lifetime = NumberRange.new(2, 3.5)
		emitter.Rate = 1.5
		emitter.Speed = NumberRange.new(0.2)
		emitter.EmissionDirection = Enum.NormalId.Right -- (+X, out of the seam)
		emitter.SpreadAngle = Vector2.new(15, 15)
		emitter.Acceleration = Vector3.new(0, -0.25, 0)
		emitter.Drag = 1
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-10, 10)
		emitter.LightInfluence = 0.8
		emitter:SetAttribute("BaseRate", 1.5)
		return emitter
	elseif name == "Spark_Strip" then
		-- the scorched power strip: a rare burst of 4 sparks on ballistic arcs (one-shot)
		local emitter = newEmitter(host, SPARKLE)
		emitter.Color = ColorSequence.new(rgb(255, 222, 160))
		emitter.Size = sequence({ { 0, 0.08 }, { 1, 0.03 } })
		emitter.Transparency = sequence({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } })
		emitter.Lifetime = NumberRange.new(0.2, 0.4)
		emitter.Rate = 0
		emitter.Speed = NumberRange.new(6, 10)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(50, 50)
		emitter.Acceleration = Vector3.new(0, -40, 0)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Enabled = true
		return emitter
	elseif name == "Breath_Floor" then
		-- a very thin cold haze lying on the lab floor (huge but almost invisible: it is the
		-- first thing dropped on low quality)
		local emitter = newEmitter(host, SMOKE)
		emitter.Color = ColorSequence.new(rgb(190, 215, 212))
		emitter.Size = sequence({ { 0, 4, 1 }, { 1, 4, 1 } })
		emitter.Transparency = sequence({ { 0, 1 }, { 0.3, 0.96 }, { 1, 1 } })
		emitter.Lifetime = NumberRange.new(6, 9)
		emitter.Rate = 1
		emitter.Speed = NumberRange.new(0.05)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.LightInfluence = 1
		emitter:SetAttribute("BaseRate", 1)
		return emitter
	end
	return nil
end

-- The splash of a drop landing: a tiny host part with a Rate-0 emitter (Emit(3) per drop).
function AptFx.splash(position: Vector3, parent: Instance): ParticleEmitter
	local host = hostPart("Splash", CFrame.new(position), Vector3.new(0.1, 0.1, 0.1), parent)
	local emitter = newEmitter(host, SPARKLE)
	emitter.Color = ColorSequence.new(rgb(150, 150, 140))
	emitter.Size = NumberSequence.new(0.04)
	emitter.Transparency = sequence({ { 0, 0.3 }, { 1, 1 } })
	emitter.Lifetime = NumberRange.new(0.2)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(2, 3)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.LightInfluence = 1
	emitter.Enabled = true
	return emitter
end

-- The ripple of a drop: a thin disc that widens and fades in 0.5 s (Quad Out).
function AptFx.ring(position: Vector3, size: number, parent: Instance)
	local ring = Instance.new("Part")
	ring.Name = "DripRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.02, size * 0.2, size * 0.2)
	-- (a cylinder's axis is its X: turned to point up)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Material = Enum.Material.Glass
	ring.Color = rgb(90, 88, 80)
	ring.Transparency = 0.6
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = parent
	TweenService:Create(
		ring,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.02, size, size), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, 0.6)
end

-- A short warm flash at the spark (the contact frame of the art direction: pops, no fade-in).
function AptFx.sparkFlash(host: BasePart)
	local light = Instance.new("PointLight")
	light.Name = "SparkFlash"
	light.Color = rgb(255, 225, 170)
	light.Brightness = 3
	light.Range = 4
	light.Shadows = false
	light.Parent = host
	Debris:AddItem(light, 0.08)
end

------------------------------------------------------------------------------
-- Moving things (client-side CFrames on anchored parts: no physics)
------------------------------------------------------------------------------

-- Turns `instance` by `angle` (radians) around the world `axis` through `point`, starting
-- from its built pivot `base` (we only ever write base × rotation: nothing drifts).
local function rotateFrom(
	instance: PVInstance,
	base: CFrame,
	point: Vector3,
	axis: Vector3,
	angle: number
)
	local turn = CFrame.new(point) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-point)
	instance:PivotTo(turn * base)
end

-- The REAL pivot of a server-built model (the hook, the fan hub, a sheet's top edge). The
-- server writes it in the "Pivot" attribute too: a pivot set by a server script is not sent
-- to the clients (here GetPivot() is the PrimaryPart's centre or the bounding box's). We only
-- read it to know WHERE to turn; the turns themselves are relative (turn × GetPivot()), so
-- they are right whatever the client thinks the pivot is.
local function realPivot(instance: PVInstance): CFrame
	local pivot = instance:GetAttribute("Pivot")
	return if typeof(pivot) == "CFrame" then pivot else instance:GetPivot()
end

export type Rig = {
	update: (deltaTime: number) -> (),
	reset: () -> (), -- back to how it was built
}

-- A hanging thing (the entry pendant): swing() starts a damped swing (±4°, period 3.2 s,
-- the amplitude dies as e^(-t/2.8)) around the world `axis` through its pivot (the hook).
-- Its light is a child, so the shadows of the whole entry swing with it.
export type Swinger = Rig & { swing: () -> () }

function AptFx.swinger(model: Model, axis: Vector3): Swinger
	local base = model:GetPivot()
	local hook = realPivot(model).Position
	local time = math.huge
	local amplitude = math.rad(4)
	local function update(deltaTime: number)
		if time > 9 then
			return
		end
		time += deltaTime
		local angle = amplitude * math.exp(-time / 2.8) * math.sin(2 * math.pi * time / 3.2)
		rotateFrom(model, base, hook, axis, if time > 9 then 0 else angle)
	end
	return {
		update = update,
		swing = function()
			time = 0
		end,
		reset = function()
			time = math.huge
			model:PivotTo(base)
		end,
	}
end

-- The box fan blades: 1.5 turns per second around the pivot's own X axis (into the room).
function AptFx.spinner(model: Model): Rig
	local base = model:GetPivot()
	local hub = realPivot(model)
	local angle = 0
	return {
		update = function(deltaTime: number)
			angle = (angle + deltaTime * 1.5 * 2 * math.pi) % (2 * math.pi)
			rotateFrom(model, base, hub.Position, hub.RightVector, angle)
		end,
		reset = function()
			model:PivotTo(base)
		end,
	}
end

-- A plastic sheet on the lab walls: ±0.6° around its top edge (the fan's draught), a sine of
-- 4 to 6 s. Works on a Model (pivot = the top edge, set by the server) or a single part.
function AptFx.sway(instance: PVInstance, seed: number): Rig
	local base = instance:GetPivot()
	local point: Vector3
	local along: Vector3
	if instance:IsA("BasePart") then
		point = (instance.CFrame * CFrame.new(0, instance.Size.Y / 2, 0)).Position
		along = if instance.Size.X >= instance.Size.Z
			then instance.CFrame.RightVector
			else instance.CFrame.LookVector
	else
		point = realPivot(instance).Position
		local boxCFrame, boxSize = (instance :: Model):GetBoundingBox()
		along = if boxSize.X >= boxSize.Z then boxCFrame.RightVector else boxCFrame.LookVector
	end
	-- (the rotation axis is the top edge: horizontal, along the sheet)
	local flat = Vector3.new(along.X, 0, along.Z)
	local axis = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.xAxis
	local rng = Random.new(seed)
	local period = rng:NextNumber(4, 6)
	local phase = rng:NextNumber(0, 2 * math.pi)
	local time = 0
	return {
		update = function(deltaTime: number)
			time += deltaTime
			rotateFrom(
				instance,
				base,
				point,
				axis,
				math.rad(0.6) * math.sin(2 * math.pi * time / period + phase)
			)
		end,
		reset = function()
			instance:PivotTo(base)
		end,
	}
end

-- The strip curtain behind the lab door. update(deltaTime, root) moves the strips; it
-- returns true on the frame the root CROSSES the curtain (the controller plays the plastic
-- sound once per crossing).
export type Curtain = {
	update: (deltaTime: number, root: Vector3?) -> boolean,
	reset: () -> (),
}

type Strip = {
	part: BasePart,
	base: CFrame,
	top: Vector3,
	axis: Vector3, -- the strip's width (it swings around it)
	sign: number, -- + angle moves its bottom toward the plane normal
	angle: number,
	speed: number,
}

local STRIP_REACH = 2 -- studs: strips this close (along the curtain) to the root move
local STRIP_NEAR = 1.2 -- studs: the root must be this close to the curtain plane
local STRIP_MAX = math.rad(25)
local STRIP_STIFFNESS = 60
local STRIP_DAMPING = 8

function AptFx.curtain(model: Model): Curtain
	local strips: { Strip } = {}
	local centre = Vector3.zero
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Size.Y > 2 then
			local size = child.Size
			local width = if size.X >= size.Z
				then child.CFrame.RightVector
				else child.CFrame.LookVector
			table.insert(strips, {
				part = child,
				base = child.CFrame,
				top = (child.CFrame * CFrame.new(0, size.Y / 2, 0)).Position,
				axis = width,
				sign = 1,
				angle = 0,
				speed = 0,
			})
			centre += child.Position
		end
	end
	local count = #strips
	if count == 0 then
		return {
			update = function()
				return false
			end,
			reset = function() end,
		}
	end
	centre /= count
	-- the plane's normal = across the strips (horizontal, perpendicular to their width)
	local width = strips[1].axis
	local normal = Vector3.new(0, 1, 0):Cross(width)
	normal = if normal.Magnitude > 1e-3 then normal.Unit else Vector3.xAxis
	for _, strip in strips do
		-- which way does a positive turn move the bottom? (so we can push it away from the root)
		local down = (strip.base * CFrame.new(0, -strip.part.Size.Y / 2, 0)).Position
		local moved = (
			CFrame.new(strip.top)
			* CFrame.fromAxisAngle(strip.axis, 0.1)
			* CFrame.new(-strip.top)
		) * down
		strip.sign = if (moved - down):Dot(normal) >= 0 then 1 else -1
	end
	local lastSide = 0

	local function update(deltaTime: number, root: Vector3?): boolean
		local crossed = false
		local side = 0
		local nearPlane = false
		if root then
			local offset = root - centre
			local distance = offset:Dot(normal)
			side = if distance >= 0 then 1 else -1
			nearPlane = math.abs(distance) < STRIP_NEAR
				and math.abs(offset:Dot(width)) < 4
				and math.abs(offset.Y) < 6
			if nearPlane and lastSide ~= 0 and side ~= lastSide then
				crossed = true
			end
			if math.abs(distance) < 3 then
				lastSide = side
			else
				lastSide = 0
			end
		end
		local step = math.min(deltaTime, 1 / 30)
		for _, strip in strips do
			local target = 0
			if root and nearPlane then
				local along = math.abs((root - strip.part.Position):Dot(width))
				if along < STRIP_REACH then
					-- away from the root: the bottom goes to the side the root is NOT on
					target = -side * strip.sign * STRIP_MAX * (1 - along / STRIP_REACH)
				end
			end
			local accel = STRIP_STIFFNESS * (target - strip.angle) - STRIP_DAMPING * strip.speed
			strip.speed += accel * step
			strip.angle += strip.speed * step
			if math.abs(strip.angle) > 1e-3 or math.abs(strip.speed) > 1e-3 then
				local turn = CFrame.new(strip.top)
					* CFrame.fromAxisAngle(strip.axis, strip.angle)
					* CFrame.new(-strip.top)
				strip.part.CFrame = turn * strip.base
			end
		end
		return crossed
	end

	return {
		update = update,
		reset = function()
			for _, strip in strips do
				strip.angle = 0
				strip.speed = 0
				strip.part.CFrame = strip.base
			end
		end,
	}
end

local function bug(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- A moth orbiting a bulb (0.6-stud circle, 1.3 s a turn, bobbing ±0.15 at 0.7 Hz, with small
-- erratic jerks). update(deltaTime, bulbPosition?, visible).
export type Moth = {
	update: (deltaTime: number, bulb: Vector3, visible: boolean) -> (),
	destroy: () -> (),
}

function AptFx.moth(parent: Instance): Moth
	local part = bug("Moth", Vector3.new(0.1, 0.03, 0.08), rgb(50, 46, 40), parent)
	part.Transparency = 1 -- (shown from its first update)
	local rng = Random.new()
	local angle = 0
	local time = 0
	local jitter = Vector3.zero
	local jitterTarget = Vector3.zero
	local nextJerk = 0
	return {
		update = function(deltaTime: number, bulb: Vector3, visible: boolean)
			part.Transparency = if visible then 0 else 1
			if not visible then
				return
			end
			time += deltaTime
			angle += deltaTime * 2 * math.pi / 1.3
			if time >= nextJerk then
				nextJerk = time + rng:NextNumber(0.15, 0.6)
				jitterTarget = Vector3.new(
					rng:NextNumber(-1, 1),
					rng:NextNumber(-1, 1),
					rng:NextNumber(-1, 1)
				) * 0.12
			end
			jitter = jitter:Lerp(jitterTarget, math.min(deltaTime * 12, 1))
			local position = bulb
				+ Vector3.new(
					math.cos(angle) * 0.6,
					0.15 * math.sin(2 * math.pi * 0.7 * time),
					math.sin(angle) * 0.6
				)
				+ jitter
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			part.CFrame = CFrame.lookAt(position, position + tangent)
				* CFrame.Angles(0, 0, math.sin(time * 40) * 0.6) -- (the wings' flutter as a roll)
		end,
		destroy = function()
			part:Destroy()
		end,
	}
end

-- A fly wandering in a 2-stud sphere near `centre` (3 sines per axis); it darts away when
-- the camera comes within 3 studs. update(deltaTime, cameraPosition).
export type Fly = {
	update: (deltaTime: number, camera: Vector3) -> (),
	destroy: () -> (),
}

function AptFx.fly(centre: Vector3, parent: Instance): Fly
	local part = bug("Fly", Vector3.new(0.08, 0.05, 0.08), rgb(16, 16, 14), parent)
	part.CFrame = CFrame.new(centre)
	local rng = Random.new()
	local freq: { number } = {}
	local phase: { number } = {}
	for index = 1, 9 do
		freq[index] = rng:NextNumber(0.7, 2.3)
		phase[index] = rng:NextNumber(0, 2 * math.pi)
	end
	local time = 0
	local flee = Vector3.zero
	local last = centre
	return {
		update = function(deltaTime: number, camera: Vector3)
			time += deltaTime
			local function axis(first: number): number
				local sum = 0
				for index = first, first + 2 do
					sum += math.sin(time * freq[index] * 2 * math.pi + phase[index])
				end
				return sum / 3
			end
			local wander = Vector3.new(axis(1), axis(4) * 0.6, axis(7))
			local away = last - camera
			local target = if away.Magnitude < 3 and away.Magnitude > 1e-3
				then away.Unit * 3
				else Vector3.zero
			flee = flee:Lerp(
				target,
				math.min(deltaTime * (if target.Magnitude > 0 then 8 else 0.6), 1)
			)
			local position = centre + wander + flee
			part.CFrame =
				CFrame.lookAt(position, position + (position - last + Vector3.new(0, 0, 1e-3)))
			last = position
		end,
		destroy = function()
			part:Destroy()
		end,
	}
end

------------------------------------------------------------------------------
-- The lab CRT (MonitorScreen): the idle culture graph
------------------------------------------------------------------------------

export type Monitor = {
	-- stage = the culture stage, progress 0..1 (redraws the graph; call it ~every 1 s)
	draw: (stage: string, progress: number) -> (),
	-- every frame: moves the scanlines, wobbles the brightness (× `wobble`)
	update: (deltaTime: number, wobble: number) -> (),
	destroy: () -> (),
}

local GRAPH_DOTS = 36
local SCREEN_GREEN = rgb(110, 230, 150)

function AptFx.monitor(screen: BasePart): Monitor
	local gui = Instance.new("SurfaceGui")
	gui.Name = "AptMonitor"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	gui.ClipsDescendants = true
	gui.ResetOnSpawn = false

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = rgb(8, 18, 14)
	back.BorderSizePixel = 0
	back.Parent = gui

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0.06, 0.05)
	status.Size = UDim2.fromScale(0.9, 0.18)
	status.Font = Enum.Font.Code
	status.TextScaled = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = SCREEN_GREEN
	status.Text = "EMPTY"
	status.Parent = back

	local footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.fromScale(0.06, 0.86)
	footer.Size = UDim2.fromScale(0.9, 0.1)
	footer.Font = Enum.Font.Code
	footer.TextScaled = true
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.TextColor3 = rgb(70, 150, 100)
	footer.Text = "T 37.0  pH 7.2  O2 OK"
	footer.Parent = back

	-- the graph box: a baseline + dots
	local graph = Instance.new("Frame")
	graph.BackgroundTransparency = 1
	graph.Position = UDim2.fromScale(0.08, 0.28)
	graph.Size = UDim2.fromScale(0.86, 0.52)
	graph.Parent = back
	local baseline = Instance.new("Frame")
	baseline.BackgroundColor3 = rgb(40, 90, 60)
	baseline.BorderSizePixel = 0
	baseline.Position = UDim2.fromScale(0, 1)
	baseline.Size = UDim2.new(1, 0, 0, 1)
	baseline.Parent = graph
	local dots: { Frame } = {}
	for index = 1, GRAPH_DOTS do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromOffset(3, 3)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = SCREEN_GREEN
		dot.Visible = false
		dot.Parent = graph
		dots[index] = dot
	end

	-- two faint scanlines rolling down at 0.3 screen per second
	local lines: { Frame } = {}
	for index = 1, 2 do
		local line = Instance.new("Frame")
		line.BackgroundColor3 = rgb(180, 255, 210)
		line.BackgroundTransparency = 0.92
		line.BorderSizePixel = 0
		line.Size = UDim2.new(1, 0, 0.04, 0)
		line.Position = UDim2.fromScale(0, (index - 1) * 0.5)
		line.Parent = back
		lines[index] = line
	end
	gui.Parent = screen

	local scroll = 0
	local noise = Random.new(4242)
	local wiggle: { number } = {}
	for index = 1, GRAPH_DOTS do
		wiggle[index] = noise:NextNumber(-0.02, 0.02)
	end

	return {
		draw = function(stage: string, progress: number)
			local shown = math.clamp(progress, 0, 1)
			if stage == "Empty" then
				status.Text = "EMPTY"
				shown = 0
			elseif stage == "Growing" then
				status.Text = `CULTURE {math.floor(shown * 100)} %`
			else
				status.Text = "READY"
				shown = 1
			end
			-- (a slow S-shaped growth curve, drawn up to the progress)
			for index, dot in dots do
				local x = (index - 1) / (GRAPH_DOTS - 1)
				if x <= shown + 1e-3 and shown > 0 then
					local y = (0.5 - math.cos(x * math.pi) * 0.5) * 0.9 + 0.05 + wiggle[index]
					dot.Position = UDim2.fromScale(x, 1 - y)
					dot.BackgroundTransparency = if x + 1 / GRAPH_DOTS > shown then 0 else 0.35
					dot.Visible = true
				else
					dot.Visible = false
				end
			end
		end,
		update = function(deltaTime: number, wobble: number)
			scroll = (scroll + deltaTime * 0.3) % 1
			for index, line in lines do
				line.Position = UDim2.fromScale(0, (scroll + (index - 1) * 0.5) % 1)
			end
			gui.Brightness = 1.3 * wobble
		end,
		destroy = function()
			gui:Destroy()
		end,
	}
end

return AptFx
