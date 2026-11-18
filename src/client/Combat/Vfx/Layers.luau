--!strict
-- Vfx/Layers: the primitives every impact is built from. Each one is ONE
-- layer of the impact grammar (docs/references/README.md):
--
--   F0      contactFlash  a hot flash that POPS at full size, 1-2 frames, cut
--   F0      light         a point light that lights faces / floor for a frame
--   F0      streaks       1-3 long thin lines out the far side of the victim
--   F0      sparkBurst    thin radial sparks that stop dead (~4 frames)
--   F0→F12  shockRing     a see-through air-pressure ring, growing ease-out
--   F1→F3   specks        moisture droplets thrown out, falling
--   F2→F30  puff          a faint dust / fibre puff off the clothes
--   F0→F48  dustRing      dust shot out along the floor (heavy hits, slams)
--           chips/debris  floor bits (particles) / chunks with weight (parts)
--           crack         a crack on the floor / a wall that stays
--           pressureLines a dark ring of thin lines (killing hits)
--           breath        a small grey puff out of a winded mouth
--
-- Rules: never yield; only pooled emitters / beams / lights (debris and
-- crack parts excepted, capped); every layer does nothing when its point
-- is culled (Vfx/Quality). Positions are world space, `dir` = the strike
-- direction (from the attacker into the victim). Frames = 60 fps frames.

local TweenService = game:GetService("TweenService")

local Floor = require(script.Parent.Floor)
local Palette = require(script.Parent.Palette)
local Pool = require(script.Parent.Pool)
local Quality = require(script.Parent.Quality)

local Layers = {}

local K = NumberSequenceKeypoint.new
local random = Random.new()

-- Can a layer at `point` be drawn? `minimal` layers (flash, light) still
-- show between 70 and 150 studs; the others only up close.
local function visible(point: Vector3, minimal: boolean): boolean
	local detail = Quality.detail(point)
	if detail == "None" then
		return false
	end
	return minimal or detail == "Full"
end

-- A unit vector perpendicular to `dir` (random around it).
local function perpendicular(dir: Vector3): Vector3
	local unit = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.zAxis
	local other = if math.abs(unit.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local a = unit:Cross(other).Unit
	local b = unit:Cross(a).Unit
	local angle = random:NextNumber(0, math.pi * 2)
	return a * math.cos(angle) + b * math.sin(angle)
end
Layers.perpendicular = perpendicular

local function withDelay(frames: number?, fn: () -> ())
	if frames and frames > 0 then
		Pool.afterFrames(frames, fn)
	else
		fn()
	end
end

------------------------------------------------------------------------------
-- Flash and light
------------------------------------------------------------------------------

export type FlashOpts = { color: Color3?, frames: number?, spikes: number?, dir: Vector3? }

-- The contact flash: on frame 0 at full size (never grows from 0), held
-- `frames` frames (1-2), then cut with :Clear(). A few very short spikes
-- give it a jagged edge (never a round ball).
function Layers.contactFlash(point: Vector3, size: number, opts: FlashOpts?)
	if not visible(point, true) then
		return
	end
	local o: FlashOpts = opts or {}
	local color = o.color or Palette.FlashCore
	local frames = math.max(1, o.frames or 1)
	local dir = o.dir or Vector3.zAxis
	local core = Pool.slot("Flash", Pool.aim(point, dir))
	if core then
		local emitter = core.emitter
		emitter.Size = NumberSequence.new(size, size * 1.08)
		emitter.Color = ColorSequence.new(color)
		emitter:Emit(1)
		Pool.afterFrames(frames, function()
			emitter:Clear()
		end)
	end
	local spikes = o.spikes or 6
	if spikes > 0 then
		local slot = Pool.slot("FlashSpikes", Pool.aim(point, dir))
		if slot then
			local emitter = slot.emitter
			emitter.Size = NumberSequence.new(size * 0.2, size * 0.08)
			emitter.Color = ColorSequence.new(color)
			emitter:Emit(spikes)
			Pool.afterFrames(frames + 1, function()
				emitter:Clear()
			end)
		end
	end
end

export type LightOpts = { color: Color3?, holdFrames: number?, fade: number? }

-- A pooled point light (max 6 alive): full for `holdFrames` (1), then
-- b = b0 * (1 - t)² over `fade` seconds (0.08-0.14).
function Layers.light(point: Vector3, brightness: number, range: number, opts: LightOpts?)
	if not visible(point, true) then
		return
	end
	local slot = Pool.light(point)
	if slot == nil then
		return
	end
	local o: LightOpts = opts or {}
	local light = slot.light
	local owner = slot.owner
	light.Color = o.color or Palette.Light
	light.Range = range
	light.Brightness = brightness
	light.Enabled = true
	local hold = o.holdFrames or 1
	local fade = math.max(0.02, o.fade or 0.1)
	local frames = 0
	local t = 0
	Pool.step(function(dt)
		if slot.owner ~= owner then
			return false -- (taken over by a newer light)
		end
		frames += 1
		if frames <= hold then
			return true
		end
		t += dt / fade
		if t >= 1 then
			light.Brightness = 0
			light.Enabled = false
			return false
		end
		light.Brightness = brightness * (1 - t) ^ 2
		return true
	end)
end

------------------------------------------------------------------------------
-- Sparks, streaks, rings
------------------------------------------------------------------------------

export type SparkPalette = "Body" | "Warm" | "Glass" | "Rift"
export type SparkOpts = {
	count: number,
	speed: NumberRange?,
	spread: number?,
	palette: SparkPalette?,
	life: NumberRange?,
	heavy: boolean?,
}

local function sparkColor(palette: SparkPalette?): ColorSequence
	if palette == "Warm" then
		return Palette.SparkWarm
	elseif palette == "Glass" then
		return ColorSequence.new(Palette.GlassGlint, Color3.fromRGB(190, 205, 195))
	elseif palette == "Rift" then
		return ColorSequence.new(Palette.RiftTint, Color3.fromRGB(170, 200, 180))
	end
	return Palette.Moisture
end

-- Thin radial streaks that stop almost at once (~4 frames). On a body:
-- moisture, 70 % thrown sideways / back toward the attacker, 30 % out the
-- far side. Warm only for metal, stone, glass.
function Layers.sparkBurst(point: Vector3, dir: Vector3, opts: SparkOpts)
	if not visible(point, false) then
		return
	end
	local count = Quality.count(opts.count)
	if count <= 0 then
		return
	end
	local heavy = opts.heavy == true
	local spread = opts.spread or 65
	local speed = opts.speed or (if heavy then NumberRange.new(40, 75) else NumberRange.new(28, 55))
	local life = opts.life or NumberRange.new(0.06, 0.11)
	local color = sparkColor(opts.palette)
	local unit = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.zAxis
	local back = math.floor(count * 0.7 + 0.5)
	local function burst(direction: Vector3, n: number, angle: number)
		if n <= 0 then
			return
		end
		local slot = Pool.slot("Sparks", Pool.aim(point, direction))
		if slot == nil then
			return
		end
		local e = slot.emitter
		e.Size = if heavy
			then NumberSequence.new({ K(0, 0.18), K(1, 0.05) })
			else NumberSequence.new({ K(0, 0.14), K(1, 0.04) })
		e.Color = color
		e.Speed = speed
		e.Lifetime = life
		e.SpreadAngle = Vector2.new(angle, angle)
		e:Emit(n)
	end
	-- (back toward the attacker and up a little: off the skin)
	burst(-unit + Vector3.yAxis * 0.35, back, spread)
	burst(unit, count - back, spread * 0.6)
end

export type StreakOpts = { width: number?, frames: number?, backAlong: Vector3? }

local function showBeam(name: string, from: Vector3, to: Vector3, width: number, frames: number)
	local slot = Pool.beam(name)
	if slot == nil then
		return
	end
	local owner = slot.owner
	local beam = slot.beam
	slot.a0.WorldPosition = from
	slot.a1.WorldPosition = to
	beam.Width0 = width
	if name == "Streak" then
		beam.Transparency = NumberSequence.new({ K(0, 0.1), K(0.7, 0.35), K(1, 1) })
	end
	beam.Enabled = true
	-- Last frame: thinner and fainter (it breaks up), then gone.
	Pool.afterFrames(math.max(1, frames - 1), function()
		if slot.owner == owner and name == "Streak" then
			beam.Width0 = width * 0.5
			beam.Transparency = NumberSequence.new({ K(0, 0.5), K(0.7, 0.75), K(1, 1) })
		end
	end)
	Pool.afterFrames(frames, function()
		if slot.owner == owner then
			beam.Enabled = false
		end
	end)
end

-- 1-3 long thin tapered lines along the strike, out the far side of the
-- victim (2-3 frames). `backAlong` (unit, from the contact back up the
-- attacker's arm) adds one streak back along the arm: force going in.
function Layers.streaks(
	point: Vector3,
	dir: Vector3,
	count: number,
	length: number,
	opts: StreakOpts?
)
	if count <= 0 or not visible(point, false) then
		return
	end
	local o: StreakOpts = opts or {}
	local width = o.width or 0.12
	local frames = o.frames or 2
	local unit = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.zAxis
	for index = 1, count do
		local jitter = perpendicular(unit) * random:NextNumber(0, 0.3)
		local reach = length * random:NextNumber(0.75, 1.1) * (if index == 1 then 1 else 0.8)
		showBeam(
			"Streak",
			point - unit * 0.4 + jitter,
			point + unit * reach + jitter * 1.6,
			width,
			frames
		)
	end
	local back = o.backAlong
	if back and back.Magnitude > 1e-4 then
		showBeam("Streak", point, point + back.Unit * 2.5, width * 0.65, frames)
	end
end

-- The dark ring of thin lines behind a killing hit (3 frames), in the
-- plane perpendicular to the strike, from radius/2.7 to `radius`.
function Layers.pressureLines(point: Vector3, dir: Vector3, radius: number)
	if not visible(point, false) then
		return
	end
	local unit = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.zAxis
	local other = if math.abs(unit.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local a = unit:Cross(other).Unit
	local b = unit:Cross(a).Unit
	local lines = 7
	local start = random:NextNumber(0, math.pi * 2)
	for index = 1, lines do
		local angle = start + index * (math.pi * 2 / lines) + random:NextNumber(-0.2, 0.2)
		local out = a * math.cos(angle) + b * math.sin(angle)
		local inner = radius / 2.7 * random:NextNumber(0.85, 1.15)
		local outer = radius * random:NextNumber(0.8, 1.05)
		showBeam(
			"Pressure",
			point + out * inner + unit * 0.2,
			point + out * outer + unit * 0.5,
			0.06,
			3
		)
	end
end

export type RingOpts = {
	from: number,
	to: number,
	life: number,
	delayFrames: number?,
	alpha: number?,
	color: Color3?,
}

-- A see-through air-pressure ring facing `facing`, growing fast then
-- slowing (ease-out). Air coloured, lit by the scene (never neon).
function Layers.shockRing(point: Vector3, facing: Vector3, opts: RingOpts)
	if not visible(point, false) then
		return
	end
	withDelay(opts.delayFrames, function()
		local slot = Pool.slot("Ring", Pool.aim(point, facing))
		if slot == nil then
			return
		end
		local e = slot.emitter
		local from, to = opts.from, opts.to
		local alpha = math.clamp(opts.alpha or 0.25, 0, 0.95)
		e.Size = NumberSequence.new({ K(0, from), K(0.25, from + (to - from) * 0.6), K(1, to) })
		e.Transparency = NumberSequence.new({
			K(0, alpha),
			K(0.4, math.min(0.98, alpha + 0.3), 0.05),
			K(1, 1),
		})
		e.Lifetime = NumberRange.new(opts.life)
		e.Color = ColorSequence.new(opts.color or Palette.Air)
		e:Emit(1)
	end)
end

------------------------------------------------------------------------------
-- Specks, puffs, dust, debris
------------------------------------------------------------------------------

export type SpeckOpts = { color: Color3?, delayFrames: number? }

-- Moisture droplets thrown back off the skin, falling with gravity.
function Layers.specks(point: Vector3, dir: Vector3, count: number, opts: SpeckOpts?)
	local n = Quality.count(count)
	if n <= 0 or not visible(point, false) then
		return
	end
	local o: SpeckOpts = opts or {}
	local unit = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.zAxis
	withDelay(o.delayFrames or 1, function()
		local aim = -unit * 0.6 + Vector3.yAxis * 0.5 + perpendicular(unit) * 0.4
		local slot = Pool.slot("Specks", Pool.aim(point, aim))
		if slot then
			slot.emitter.Color = ColorSequence.new(o.color or Palette.Speck)
			slot.emitter:Emit(n)
		end
	end)
end

export type PuffOpts = { color: Color3?, delayFrames: number?, life: number? }

-- A faint puff of dust / fibre off the clothes, drifting along `dir`,
-- emitted 2 frames after contact by default (the dust comes off after the shock).
function Layers.puff(point: Vector3, dir: Vector3, size: number, count: number, opts: PuffOpts?)
	local n = Quality.count(count)
	if n <= 0 or size <= 0 or not visible(point, false) then
		return
	end
	local o: PuffOpts = opts or {}
	withDelay(o.delayFrames or 2, function()
		local slot = Pool.slot("Puff", Pool.aim(point, dir))
		if slot == nil then
			return
		end
		local e = slot.emitter
		e.Size = NumberSequence.new({
			K(0, size * 0.6),
			K(0.4, size * 1.6, size * 0.1),
			K(1, size * 2.2),
		})
		e.Speed = NumberRange.new(2, 5)
		local life = o.life or 0.5
		e.Lifetime = NumberRange.new(life * 0.7, life * 1.2)
		local color = o.color
		e.Color = if color
			then ColorSequence.new(color, color:Lerp(Palette.DustDark, 0.4))
			else ColorSequence.new(Palette.DustLight, Palette.DustDark)
		e:Emit(n)
	end)
end

export type DustRingOpts = {
	puffs: number,
	speed: number,
	size: number?,
	color: Color3?,
	groundRing: boolean?,
	dir: Vector3?, -- only toward this side (a half ring), e.g. a dash's kick-off
}

-- Dust shot out along the floor in every direction (or a half ring along
-- `dir`), settling in ~0.8 s; plus a flat ground ring if `groundRing`.
-- (Shape Disc / Cylinder don't work under an attachment: N single puffs.)
function Layers.dustRing(floorPoint: Vector3, opts: DustRingOpts)
	if not visible(floorPoint, false) then
		return
	end
	local puffs = if Quality.extras() then Quality.count(opts.puffs) else math.min(2, opts.puffs)
	if puffs <= 0 then
		return
	end
	local size = opts.size or 1
	local color = opts.color or Floor.dustColor(Floor.at(floorPoint, 3))
	local first = Pool.slot("FloorDust", CFrame.new(floorPoint))
	if first == nil then
		return
	end
	local e = first.emitter
	e.Size = NumberSequence.new({ K(0, size), K(0.3, size * 2.4, size * 0.2), K(1, size * 4) })
	e.Speed = NumberRange.new(opts.speed * 0.75, opts.speed)
	e.Lifetime = NumberRange.new(0.6, 1.0)
	e.Color = ColorSequence.new(color, color:Lerp(Palette.DustDark, 0.3))
	local base = floorPoint + Vector3.yAxis * 0.25
	local side = opts.dir
	local flat = if side then Vector3.new(side.X, 0, side.Z) else Vector3.zero
	local start = random:NextNumber(0, math.pi * 2)
	for index = 1, puffs do
		local out: Vector3
		if flat.Magnitude > 1e-3 then
			-- a fan of ±70° around `dir`
			local angle = math.rad(-70 + 140 * (index - 0.5) / puffs + random:NextNumber(-8, 8))
			out = (
				CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(flat.Unit)
				+ Vector3.yAxis * 0.08
			)
		else
			local angle = start + (index / puffs) * math.pi * 2 + random:NextNumber(-0.2, 0.2)
			out = Vector3.new(math.cos(angle), 0.08, math.sin(angle))
		end
		first.attachment.WorldCFrame = Pool.aim(base, out)
		e:Emit(1)
	end
	if opts.groundRing and Quality.extras() then
		Layers.shockRing(floorPoint + Vector3.yAxis * 0.12, Vector3.yAxis, {
			from = size,
			to = 5 * size,
			life = 0.3,
			alpha = 0.5,
			color = color,
		})
	end
end

-- Small floor-coloured bits thrown up that fall (particles, light floor hits).
function Layers.chips(point: Vector3, count: number, color: Color3)
	local n = Quality.count(count)
	if n <= 0 or not visible(point, false) then
		return
	end
	local slot = Pool.slot("Chips", Pool.aim(point, Vector3.yAxis))
	if slot then
		slot.emitter.Color = ColorSequence.new(color)
		slot.emitter:Emit(n)
	end
end

-- Physical chunks (debris) with real weight. Capped; the oldest shrinks
-- out first. They collide with the map, not the fighters ("Debris" group).
local MAX_DEBRIS = 60
local DEBRIS_GROUP = "Debris"
local liveDebris: { BasePart } = {}
local freeDebris: { BasePart } = {}
-- Each time a piece is (re)used it gets a new number: a timer set for its
-- previous life then does nothing (it would retire the reused piece early).
local debrisLife: { [BasePart]: number } = {}
local SHRINK = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function retire(part: BasePart)
	local index = table.find(liveDebris, part)
	if index == nil then
		return
	end
	table.remove(liveDebris, index)
	local tween = TweenService:Create(part, SHRINK, { Size = Vector3.one * 0.05 })
	tween.Completed:Once(function()
		part.Anchored = true
		part.Parent = nil
		table.insert(freeDebris, part)
	end)
	tween:Play()
end

local function takeDebris(): Part
	local part = table.remove(freeDebris)
	if part and part:IsA("Part") then
		return part
	end
	local created = Instance.new("Part")
	created.Name = "VfxDebris"
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = true
	created.TopSurface = Enum.SurfaceType.Smooth
	created.BottomSurface = Enum.SurfaceType.Smooth
	pcall(function()
		created.CollisionGroup = DEBRIS_GROUP
	end)
	return created
end

export type DebrisOpts = {
	size: NumberRange?,
	up: NumberRange?,
	out: NumberRange?,
	stay: number?,
}

function Layers.debris(floorPoint: Vector3, count: number, opts: DebrisOpts?)
	if count <= 0 or not visible(floorPoint, false) then
		return
	end
	local floor = Floor.at(floorPoint, 3)
	if not Quality.extras() then
		Layers.chips(floorPoint, count * 3, Floor.dustColor(floor))
		return
	end
	local o: DebrisOpts = opts or {}
	local size = o.size or NumberRange.new(0.2, 0.6)
	local up = o.up or NumberRange.new(18, 30)
	local out = o.out or NumberRange.new(8, 15)
	local stay = o.stay or random:NextNumber(5, 10)
	local material = if floor then floor.material else Enum.Material.Concrete
	if material == Enum.Material.Grass or material == Enum.Material.LeafyGrass then
		material = Enum.Material.Ground -- (a clod of earth, not a block of grass)
	end
	local color = if floor then floor.color else Palette.DustLight
	local folder = Pool.folder()
	for _ = 1, count do
		if #liveDebris >= MAX_DEBRIS then
			retire(liveDebris[1])
		end
		local part = takeDebris()
		local s = random:NextNumber(size.Min, size.Max)
		part.Size = Vector3.new(s, s * random:NextNumber(0.5, 0.9), s * random:NextNumber(0.7, 1.1))
		part.Material = material
		part.Color = color:Lerp(Palette.DustDark, random:NextNumber(0, 0.25))
		part.Transparency = 0
		part.CanCollide = true
		local angle = random:NextNumber(0, math.pi * 2)
		local flat = Vector3.new(math.cos(angle), 0, math.sin(angle))
		part.CFrame = CFrame.new(floorPoint + flat * 0.4 + Vector3.yAxis * (s + 0.1))
			* CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), 0)
		part.Anchored = false
		part.Parent = folder
		part.AssemblyLinearVelocity = flat * random:NextNumber(out.Min, out.Max)
			+ Vector3.yAxis * random:NextNumber(up.Min, up.Max)
		part.AssemblyAngularVelocity = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1)
		) * random:NextNumber(8, 20)
		table.insert(liveDebris, part)
		local life = (debrisLife[part] or 0) + 1
		debrisLife[part] = life
		Pool.after(stay + random:NextNumber(0, 1.5), function()
			if debrisLife[part] == life then
				retire(part)
			end
		end)
	end
end

-- A crack on a surface (floor or wall) that stays `stay` seconds (6-10),
-- then fades. Drawn with a few thin dark branches + a soft dark smudge.
local MAX_CRACKS = 8
local liveCracks: { Model } = {}
local FADE = TweenInfo.new(1.2, Enum.EasingStyle.Linear)

local function crackPart(parent: Model, size: Vector3, cframe: CFrame, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = "Crack"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Palette.Crack
	part.Transparency = transparency
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

function Layers.crack(point: Vector3, normal: Vector3, size: number, stay: number?)
	if size <= 0 or not visible(point, false) then
		return
	end
	if #liveCracks >= MAX_CRACKS then
		local oldest = table.remove(liveCracks, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local model = Instance.new("Model")
	model.Name = "VfxCrack"
	local n = if normal.Magnitude > 1e-4 then normal.Unit else Vector3.yAxis
	-- The surface's frame: Y = the normal.
	local other = if math.abs(n.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local right = n:Cross(other).Unit
	local forward = right:Cross(n).Unit
	local surface = CFrame.fromMatrix(point + n * 0.03, right, n, -forward)
	-- The smudge: a flat dark disc in the middle.
	crackPart(
		model,
		Vector3.new(0.04, size * 0.45, size * 0.45),
		surface * CFrame.Angles(0, 0, math.rad(90)),
		0.55
	).Shape =
		Enum.PartType.Cylinder
	-- The branches: each 2-3 thin segments, bending a little, thinning out.
	local branches = random:NextInteger(5, 7)
	local start = random:NextNumber(0, math.pi * 2)
	for index = 1, branches do
		local angle = start + index * (math.pi * 2 / branches) + random:NextNumber(-0.3, 0.3)
		local at = Vector3.zero
		local width = 0.1 * math.clamp(size / 4, 0.6, 1.4)
		local reach = size * 0.5 * random:NextNumber(0.6, 1.1)
		local segments = random:NextInteger(2, 3)
		for _ = 1, segments do
			local length = reach / segments
			local heading = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local mid = at + heading * (length / 2)
			crackPart(
				model,
				Vector3.new(width, 0.02, length),
				surface * CFrame.lookAt(mid, mid + heading),
				0.1
			)
			at += heading * length
			angle += random:NextNumber(-0.5, 0.5)
			width *= 0.7
		end
	end
	model.Parent = Pool.folder()
	table.insert(liveCracks, model)
	Pool.after(stay or random:NextNumber(6, 10), function()
		if model.Parent == nil then
			return
		end
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				TweenService:Create(part, FADE, { Transparency = 1 }):Play()
			end
		end
		Pool.after(1.3, function()
			local index = table.find(liveCracks, model)
			if index then
				table.remove(liveCracks, index)
			end
			model:Destroy()
		end)
	end)
end

export type BreathOpts = { size: number?, count: number? }

-- A small grey puff out of the mouth (winded by a liver shot, a choke...).
function Layers.breath(model: Model, opts: BreathOpts?)
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local o: BreathOpts = opts or {}
	local mouth = head.CFrame * CFrame.new(0, -0.25, -0.65)
	Layers.puff(
		mouth.Position,
		head.CFrame.LookVector - Vector3.yAxis * 0.3,
		o.size or 0.35,
		o.count or 2,
		{
			color = Color3.fromRGB(205, 205, 200),
			delayFrames = 0,
			life = 0.7,
		}
	)
end

return Layers
