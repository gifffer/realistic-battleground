--!strict
-- Vfx/Pool: the reusable pieces every layer draws with, and the ONE frame
-- scheduler of the library.
--
-- Why pools: a ParticleEmitter created (or just parented) on the hit
-- frame often emits nothing the first time (its texture isn't loaded
-- yet), and creating / destroying instances on every hit costs frames
-- with 16 players. So everything is made ONCE at start and reused:
--   • emitter "slots": a Terrain Attachment + its ParticleEmitter, always
--     parented, Rate 0. A layer moves the attachment and calls :Emit().
--     Particles stay where they were born (LockedToPart false), so the same
--     slot can serve several hits. Each kind of layer has a few slots used
--     in turn (round robin), because Size / Colour / Transparency of an
--     emitter apply to its LIVING particles too: two different hits on
--     one slot would change each other.
--   • 6 PointLights (contact lights), 14 Beams (streaks, pressure lines).
--   • a token per fighter: bumped when a new action starts, so the delayed
--     beats of a move that was cut short don't play (see HitFx).
--
-- Timing: 1-2 frame effects can't use task.wait (it resolves at Heartbeat
-- steps). Pool runs one RenderStepped loop that calls:
--   Pool.afterFrames(n, fn)  fn in n rendered frames
--   Pool.after(seconds, fn)  fn once `seconds` have passed
--   Pool.step(fn)            fn(dt) every frame until it returns false

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local Palette = require(script.Parent.Palette)

local Pool = {}

-- Folder for the parts the library creates (ghost limbs, debris, cracks).
local folder = Instance.new("Folder")
folder.Name = "CombatVfx"

function Pool.folder(): Folder
	if folder.Parent == nil then
		folder.Parent = workspace
	end
	return folder
end

------------------------------------------------------------------------------
-- The frame scheduler
------------------------------------------------------------------------------

type Timed = { frame: number, time: number, fn: () -> () }

local frame = 0
local timed: { Timed } = {}
local steppers: { (dt: number) -> boolean } = {}

-- Runs `fn` `frames` rendered frames from now (0 or less: right away).
function Pool.afterFrames(frames: number, fn: () -> ())
	if frames <= 0 then
		fn()
		return
	end
	table.insert(timed, { frame = frame + math.floor(frames + 0.5), time = 0, fn = fn })
end

-- Runs `fn` once `seconds` have passed (0 or less: right away).
function Pool.after(seconds: number, fn: () -> ())
	if seconds <= 0 then
		fn()
		return
	end
	table.insert(timed, { frame = 0, time = os.clock() + seconds, fn = fn })
end

-- Calls `fn(dt)` every rendered frame until it returns false.
function Pool.step(fn: (dt: number) -> boolean)
	table.insert(steppers, fn)
end

local function onRender(dt: number)
	frame += 1
	local now = os.clock()
	-- (backwards: entries can be removed, and fn may add new ones at the end)
	for index = #timed, 1, -1 do
		local entry = timed[index]
		if
			entry
			and (
				(entry.frame > 0 and frame >= entry.frame)
				or (entry.frame == 0 and now >= entry.time)
			)
		then
			table.remove(timed, index)
			local ok, err = pcall(entry.fn :: any)
			if not ok then
				warn("[Vfx] ", err)
			end
		end
	end
	for index = #steppers, 1, -1 do
		local fn = steppers[index]
		local ok, keep = pcall(fn :: any, dt)
		if not ok then
			warn("[Vfx] ", keep)
		end
		if not ok or keep ~= true then
			-- (find it again: earlier ones may have been removed meanwhile)
			local at = table.find(steppers, fn)
			if at then
				table.remove(steppers, at)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Tokens (a move cut short shows nothing more)
------------------------------------------------------------------------------

local tokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

function Pool.token(model: Model): number
	return tokens[model] or 0
end

function Pool.bump(model: Model): number
	local value = (tokens[model] or 0) + 1
	tokens[model] = value
	return value
end

------------------------------------------------------------------------------
-- Emitter slots
------------------------------------------------------------------------------

export type Slot = { attachment: Attachment, emitter: ParticleEmitter }
type SlotGroup = { slots: { Slot }, next: number }

local groups: { [string]: SlotGroup } = {}
local preload: { Instance } = {}

local function newAttachment(name: string): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = workspace.Terrain
	return attachment
end

-- Creates `count` slots for layer `name`, each emitter set up by `setup`.
function Pool.define(name: string, count: number, setup: (ParticleEmitter) -> ())
	local group: SlotGroup = { slots = {}, next = 1 }
	for index = 1, count do
		local attachment = newAttachment(`Vfx_{name}_{index}`)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = name
		emitter.Rate = 0
		emitter.Enabled = true
		emitter.LockedToPart = false
		emitter.EmissionDirection = Enum.NormalId.Front
		setup(emitter)
		emitter.Parent = attachment
		table.insert(group.slots, { attachment = attachment, emitter = emitter })
		if index == 1 then
			table.insert(preload, emitter)
		end
	end
	groups[name] = group
end

-- The next slot of layer `name` (round robin), its attachment placed at
-- `cframe` (the emitter shoots along the CFrame's LookVector).
function Pool.slot(name: string, cframe: CFrame): Slot?
	local group = groups[name]
	if group == nil then
		return nil
	end
	local slot = group.slots[group.next]
	group.next = group.next % #group.slots + 1
	slot.attachment.WorldCFrame = cframe
	return slot
end

-- A CFrame at `position` looking along `direction` (any direction, even up).
function Pool.aim(position: Vector3, direction: Vector3): CFrame
	local unit = if direction.Magnitude > 1e-4 then direction.Unit else Vector3.yAxis
	local up = if math.abs(unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(position, position + unit, up)
end

------------------------------------------------------------------------------
-- Lights and beams
------------------------------------------------------------------------------

export type LightSlot = { attachment: Attachment, light: PointLight, owner: number }
local lights: { LightSlot } = {}
local nextLight = 1
local LIGHT_COUNT = 6

-- The next of the 6 pooled point lights (the oldest one is taken over).
-- `owner` changes each time: a fade still running on it stops.
function Pool.light(position: Vector3): LightSlot?
	local slot = lights[nextLight]
	if slot == nil then
		return nil -- (before start)
	end
	nextLight = nextLight % LIGHT_COUNT + 1
	slot.owner += 1
	slot.attachment.WorldPosition = position
	return slot
end

export type BeamSlot = { a0: Attachment, a1: Attachment, beam: Beam, owner: number }
type BeamGroup = { beams: { BeamSlot }, next: number }
local beamGroups: { [string]: BeamGroup } = {}

local function defineBeams(name: string, count: number, setup: (Beam) -> ())
	local group: BeamGroup = { beams = {}, next = 1 }
	for index = 1, count do
		local a0 = newAttachment(`Vfx_{name}_{index}_0`)
		local a1 = newAttachment(`Vfx_{name}_{index}_1`)
		local beam = Instance.new("Beam")
		beam.Name = name
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Enabled = false
		beam.FaceCamera = true
		beam.Segments = 1
		beam.CurveSize0 = 0
		beam.CurveSize1 = 0
		setup(beam)
		beam.Parent = a0
		table.insert(group.beams, { a0 = a0, a1 = a1, beam = beam, owner = 0 })
	end
	beamGroups[name] = group
end

-- The next beam of group "Streak" or "Pressure" (round robin).
function Pool.beam(name: string): BeamSlot?
	local group = beamGroups[name]
	if group == nil then
		return nil
	end
	local slot = group.beams[group.next]
	group.next = group.next % #group.beams + 1
	slot.owner += 1
	return slot
end

------------------------------------------------------------------------------
-- The layers' emitters (exact recipes: scratchpad TECHNIQUES.md §2-§10)
------------------------------------------------------------------------------

local K = NumberSequenceKeypoint.new
local T = Palette.TEXTURES

local function defineAll()
	-- Contact flash core: one particle that POPS at full size; HitFx cuts
	-- it after 1-2 frames with :Clear() (an exact cut, never a fade-in).
	Pool.define("Flash", 8, function(e)
		e.Texture = T.flash
		e.Lifetime = NumberRange.new(0.12)
		e.Speed = NumberRange.new(0)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Brightness = 2.5
		e.ZOffset = 0.6
		e.Rotation = NumberRange.new(0, 360)
		e.Transparency = NumberSequence.new({ K(0, 0), K(0.5, 0.15), K(1, 1) })
	end)
	-- The flash's jagged edge: very short thin spikes from the centre, so
	-- the flash is never a round ball.
	Pool.define("FlashSpikes", 8, function(e)
		e.Texture = T.spark
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Lifetime = NumberRange.new(0.05, 0.08)
		e.Speed = NumberRange.new(30, 46)
		e.Drag = 20
		e.SpreadAngle = Vector2.new(180, 180)
		e.Squash = NumberSequence.new(-2.6)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Brightness = 2
		e.ZOffset = 0.55
		e.Transparency = NumberSequence.new({ K(0, 0), K(1, 0.6) })
	end)
	-- Radial sparks: thin fast streaks that stop dead (Drag), ~4 frames.
	Pool.define("Sparks", 6, function(e)
		e.Texture = T.spark
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new({ K(0, -2.2), K(1, -1.2) })
		e.Transparency = NumberSequence.new({ K(0, 0), K(0.6, 0.2), K(1, 1) })
		e.Drag = 14
		e.Acceleration = Vector3.new(0, -30, 0)
		e.LightEmission = 0.6
		e.LightInfluence = 0.3
		e.Brightness = 2
		e.ZOffset = 0.4
	end)
	-- Air-pressure ring: one flat particle facing the strike (it lies
	-- perpendicular to its tiny velocity), growing ease-out.
	Pool.define("Ring", 6, function(e)
		e.Texture = T.ring
		e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		e.Speed = NumberRange.new(0.05)
		e.SpreadAngle = Vector2.zero
		e.Rotation = NumberRange.new(0, 360)
		e.LightEmission = 0.25
		e.LightInfluence = 0.6
		e.ZOffset = 0.2
	end)
	-- Specks: sweat / moisture droplets that FALL (weight).
	Pool.define("Specks", 4, function(e)
		e.Texture = T.spark
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(-0.8)
		e.Size = NumberSequence.new({ K(0, 0.1), K(1, 0.04) })
		e.Transparency = NumberSequence.new({ K(0, 0.1), K(0.7, 0.3), K(1, 1) })
		e.Speed = NumberRange.new(10, 22)
		e.Drag = 2.5
		e.Acceleration = Vector3.new(0, -55, 0)
		e.Lifetime = NumberRange.new(0.25, 0.45)
		e.SpreadAngle = Vector2.new(50, 50)
		e.LightEmission = 0.2
		e.LightInfluence = 0.8
	end)
	-- A faint dust / fibre puff off the clothes, eroding (envelopes).
	Pool.define("Puff", 6, function(e)
		e.Texture = T.smoke
		e.Transparency = NumberSequence.new({ K(0, 0.65), K(0.35, 0.72, 0.08), K(1, 1) })
		e.Drag = 6
		e.Acceleration = Vector3.new(0, 1.2, 0)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.Rotation = NumberRange.new(0, 360)
		e.SpreadAngle = Vector2.new(35, 35)
		e.LightEmission = 0
		e.LightInfluence = 1
	end)
	-- Floor dust: puffs shot out along the floor that settle (~0.8 s).
	Pool.define("FloorDust", 4, function(e)
		e.Texture = T.smoke
		e.Transparency = NumberSequence.new({ K(0, 0.45), K(0.5, 0.65, 0.1), K(1, 1) })
		e.Drag = 5
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.SpreadAngle = Vector2.new(8, 8)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Rotation = NumberRange.new(0, 360)
		e.LightEmission = 0
		e.LightInfluence = 1
	end)
	-- Chips: small floor-coloured bits that fall (light floor hits).
	Pool.define("Chips", 3, function(e)
		e.Texture = T.spark
		e.Size = NumberSequence.new({ K(0, 0.15), K(1, 0.1) })
		e.Transparency = NumberSequence.new({ K(0, 0), K(0.8, 0.1), K(1, 1) })
		e.Speed = NumberRange.new(10, 20)
		e.Acceleration = Vector3.new(0, -70, 0)
		e.Lifetime = NumberRange.new(0.5, 0.8)
		e.SpreadAngle = Vector2.new(40, 40)
		e.RotSpeed = NumberRange.new(-200, 200)
		e.LightEmission = 0
		e.LightInfluence = 1
	end)
	-- Speed lines: thin lines streaming past a fast body (dash, launch).
	Pool.define("SpeedLines", 4, function(e)
		e.Texture = T.spark
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(-3)
		e.Size = NumberSequence.new(0.06)
		e.Transparency = NumberSequence.new({ K(0, 0.6), K(0.3, 0.45), K(1, 1) })
		e.Speed = NumberRange.new(55, 80)
		e.Lifetime = NumberRange.new(0.08, 0.14)
		e.SpreadAngle = Vector2.new(3, 3)
		e.Color = ColorSequence.new(Palette.Trail)
		e.LightEmission = 0.2
		e.LightInfluence = 0.6
	end)

	-- Long tapered streaks along the strike line (Width1 = 0: a point).
	defineBeams("Streak", 8, function(beam)
		beam.Texture = T.streak
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureLength = 1
		beam.Color = ColorSequence.new(Palette.Streak)
		beam.LightEmission = 0.8
		beam.LightInfluence = 0
		beam.Brightness = 2
		beam.ZOffset = 0.5
		beam.Width1 = 0
	end)
	-- The dark ring of pressure lines (killing hits).
	defineBeams("Pressure", 8, function(beam)
		beam.Color = ColorSequence.new(Palette.Pressure)
		beam.LightEmission = 0
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new(0.35)
		beam.Width0 = 0.06
		beam.Width1 = 0
	end)

	for index = 1, LIGHT_COUNT do
		local attachment = newAttachment(`Vfx_Light_{index}`)
		local light = Instance.new("PointLight")
		light.Name = "ContactLight"
		light.Shadows = false
		light.Brightness = 0
		light.Enabled = false
		light.Color = Palette.Light
		light.Parent = attachment
		table.insert(lights, { attachment = attachment, light = light, owner = 0 })
	end
end

local started = false

function Pool.start()
	if started then
		return
	end
	started = true
	Pool.folder()
	defineAll()
	RunService.RenderStepped:Connect(onRender)
	-- Load the textures now, not on the first hit (PreloadAsync yields).
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(preload)
		end)
	end)
end

return Pool
