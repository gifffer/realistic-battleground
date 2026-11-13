--!strict
-- KitVFX: the visual effects (and timed sounds) of the Sentinel's and the
-- Bull's moves, shown by every client from the moves' animations
-- (KitEffects.onAction) and hits (KitEffects.onHit).
--
-- A small toolbox, reused by every move (and meant for the next kits):
--   flash / light            bursts of light
--   shockSphere              an expanding energy shell
--   ring / groundRing        hollow shockwave rings (in the air / on the floor)
--   emit / dustRing          one-shot particles, dust rolling outward
--   eruption                 slabs of the floor torn up around a crater
--   cracks                   jagged (glowing) cracks running out on the floor
--   rocks                    debris thrown up, the floor's colour / material
--   streaks                  air / speed lines
--   lightning                crackling bolts
--   gather                   energy sucked in toward a part (charging)
--   trail                    a streak behind a moving part
--   burn                     a charred mark on a body (heat vision)
--   shake / punch            camera shake / colour punch when close
-- Every animated piece goes through one RenderStepped loop (animate), and
-- everything is client-side and short-lived.
--
--   KitVFX.onAction(model, animation, move)   a move starts
--   KitVFX.onHit(victim, attacker, moveId)    one of its hits lands
--   KitVFX.stop(model)                        the move was refused / cut

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local HeatBeam = require(ReplicatedStorage.Shared.Util.HeatBeam)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local KitLooks = require(script.Parent.KitLooks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local KitVFX = {}

local TEX = {
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	shock = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	core = "rbxasset://textures/particles/explosion01_core_main.dds",
	implode = "rbxasset://textures/particles/explosion01_implosion_main.dds",
}

local WHITE = Color3.new(1, 1, 1)
local LASER_CORE = Color3.fromRGB(255, 244, 232)
local LASER = Color3.fromRGB(255, 30, 18)
local LASER_DEEP = Color3.fromRGB(150, 0, 6)
local EMBER = Color3.fromRGB(255, 130, 40)
local ENERGY = Color3.fromRGB(176, 214, 255)
local ENERGY_DEEP = Color3.fromRGB(70, 130, 255)
local DUST = Color3.fromRGB(160, 146, 124)
local STEAM = Color3.fromRGB(236, 236, 240)
local CHAR = Color3.fromRGB(24, 18, 16)
local RAGE = Color3.fromRGB(255, 40, 20)

local random = Random.new()
-- Thrown debris bounce on the map but go through fighters (registered by
-- Server/Systems/Destruction).
local DEBRIS_GROUP = "Debris"

local fx = Instance.new("Folder")
fx.Name = "KitVFX"
fx.Parent = workspace

-- Each move started on a model gets a number: its delayed effects check it
-- (refused / cut short: they don't play).
local tokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

------------------------------------------------------------------------------
-- Animation loop
------------------------------------------------------------------------------

type Anim = { start: number, finish: number, step: (alpha: number) -> (), done: (() -> ())? }
local anims: { Anim } = {}

-- Calls `step(alpha)` every frame for `duration` seconds (alpha 0 → 1),
-- then `done()`.
local function animate(duration: number, step: (alpha: number) -> (), done: (() -> ())?)
	local now = os.clock()
	table.insert(
		anims,
		{ start = now, finish = now + math.max(duration, 1e-3), step = step, done = done }
	)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local index = 1
	while index <= #anims do
		local anim = anims[index]
		local alpha = math.clamp((now - anim.start) / (anim.finish - anim.start), 0, 1)
		local ok = pcall(anim.step, alpha)
		if alpha >= 1 or not ok then
			if anim.done then
				pcall(anim.done)
			end
			anims[index] = anims[#anims]
			anims[#anims] = nil
		else
			index += 1
		end
	end
end)

local function outQuart(t: number): number
	return 1 - (1 - t) ^ 4
end
local function outQuad(t: number): number
	return 1 - (1 - t) * (1 - t)
end
local function outBack(t: number): number
	local c = 1.9
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------

local function newPart(
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	return part
end

local function tween(
	instance: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
)
	TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	):Play()
end

-- A frame at `position` whose look vector is `direction`.
local function facing(position: Vector3, direction: Vector3): CFrame
	local unit = if direction.Magnitude > 1e-6 then direction.Unit else Vector3.new(0, 0, -1)
	local up = if math.abs(unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(position, position + unit, up)
end

-- A frame at `position` whose UP vector is `axis`.
local function axisFrame(position: Vector3, axis: Vector3): CFrame
	return facing(position, axis) * CFrame.Angles(-math.pi / 2, 0, 0)
end

local function flat(vector: Vector3): Vector3
	local v = Vector3.new(vector.X, 0, vector.Z)
	return if v.Magnitude > 1e-4 then v.Unit else Vector3.new(0, 0, -1)
end

type Floor = { position: Vector3, normal: Vector3, color: Color3, material: Enum.Material }

-- The floor under `position` (through every fighter and effect), or nil.
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
floorParams.RespectCanCollide = true
floorParams.IgnoreWater = true
local function floorAt(position: Vector3): Floor?
	local ignore: { Instance } = CollectionService:GetTagged(Config.Combat.TAG)
	table.insert(ignore, fx)
	floorParams.FilterDescendantsInstances = ignore
	local hit =
		workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -16, 0), floorParams)
	if hit == nil then
		return nil
	end
	local instance = hit.Instance
	local color = if instance:IsA("BasePart") then instance.Color else DUST
	local material = hit.Material
	if instance:IsA("Terrain") then
		if material == Enum.Material.Air or material == Enum.Material.Water then
			material = Enum.Material.Grass
		end
		color = workspace.Terrain:GetMaterialColor(material)
	end
	return { position = hit.Position, normal = hit.Normal, color = color, material = material }
end

-- Dust tinted like the floor it comes from.
local function dustColor(floor: Floor?): Color3
	return if floor then DUST:Lerp(floor.color, 0.45) else DUST
end

local function light(
	position: Vector3,
	color: Color3,
	brightness: number,
	range: number,
	time: number
)
	local point = Instance.new("Attachment")
	point.WorldPosition = position
	point.Parent = workspace.Terrain
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Brightness = brightness
	glow.Range = range
	glow.Shadows = false
	glow.Parent = point
	tween(glow, time, { Brightness = 0 })
	Debris:AddItem(point, time + 0.1)
end

-- A burst of light: a glowing ball that swells and fades, and its light.
local function flash(position: Vector3, color: Color3, size: number, time: number)
	light(position, color, 10, size * 6, time * 1.4)
	local core = newPart(Vector3.one * size * 0.35, WHITE, Enum.Material.Neon, Enum.PartType.Ball)
	core.CFrame = CFrame.new(position)
	core.Parent = fx
	local halo = newPart(Vector3.one * size * 0.6, color, Enum.Material.Neon, Enum.PartType.Ball)
	halo.Transparency = 0.35
	halo.CFrame = CFrame.new(position)
	halo.Parent = fx
	animate(time, function(alpha)
		local e = outQuart(alpha)
		core.Size = Vector3.one * size * (0.35 + 0.5 * e)
		core.Transparency = alpha ^ 0.6
		halo.Size = Vector3.one * size * (0.6 + 1.2 * e)
		halo.Transparency = 0.35 + 0.65 * alpha ^ 0.8
	end, function()
		core:Destroy()
		halo:Destroy()
	end)
end

-- An expanding shell of energy (radius `from` → `to`).
local function shockSphere(position: Vector3, from: number, to: number, time: number, color: Color3)
	local shell =
		newPart(Vector3.one * from * 2, color, Enum.Material.ForceField, Enum.PartType.Ball)
	shell.CFrame = CFrame.new(position)
	shell.Parent = fx
	local inner = newPart(Vector3.one * from * 2, color, Enum.Material.Neon, Enum.PartType.Ball)
	inner.Transparency = 0.6
	inner.CFrame = CFrame.new(position)
	inner.Parent = fx
	animate(time, function(alpha)
		local r = from + (to - from) * outQuart(alpha)
		shell.Size = Vector3.one * r * 2
		shell.Transparency = alpha ^ 1.5
		inner.Size = Vector3.one * r * 1.6
		inner.Transparency = 0.6 + 0.4 * math.min(1, alpha * 2.5)
	end, function()
		shell:Destroy()
		inner:Destroy()
	end)
end

type RingOptions = {
	width: number?, -- radial thickness
	height: number?, -- along the axis
	neon: boolean?,
	segments: number?,
	transparency: number?,
	material: Enum.Material?,
}

-- A hollow shockwave ring, centred on `frame`, lying in its XZ plane (its
-- axis is frame.UpVector), growing from radius `from` to `to`.
local function ring(
	frame: CFrame,
	from: number,
	to: number,
	time: number,
	color: Color3,
	options: RingOptions?
)
	local o: RingOptions = options or {}
	local count = o.segments or 30
	local width = o.width or 0.3
	local height = o.height or 0.25
	local start = o.transparency or (if o.neon then 0.1 else 0.3)
	local material = o.material
		or (if o.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	for _ = 1, count do
		local part = newPart(Vector3.new(0.1, height, width), color, material)
		part.Transparency = start
		part.Parent = fx
		table.insert(parts, part)
		table.insert(frames, frame)
	end
	animate(time, function(alpha)
		local r = from + (to - from) * outQuart(alpha)
		local arc = 2 * math.pi * r / count * 1.12
		local transparency = start + (1 - start) * alpha ^ 1.4
		local h = height * (1 - 0.6 * alpha)
		for index, part in parts do
			local angle = (index - 1) / count * math.pi * 2
			frames[index] = frame * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -r)
			part.Size = Vector3.new(arc, h, width * (1 - 0.4 * alpha))
			part.Transparency = transparency
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end, function()
		for _, part in parts do
			part:Destroy()
		end
	end)
end

-- A ring flat on the floor under `position`.
local function groundRing(
	position: Vector3,
	from: number,
	to: number,
	time: number,
	color: Color3,
	options: RingOptions?
)
	local floor = floorAt(position)
	local at = if floor then floor.position + floor.normal * 0.08 else position
	ring(
		axisFrame(at, if floor then floor.normal else Vector3.yAxis),
		from,
		to,
		time,
		color,
		options
	)
end

type EmitOptions = {
	texture: string,
	color: Color3,
	color2: Color3?, -- (fades to this colour)
	size: { number }, -- sizes over the lifetime (evenly spaced keypoints)
	transparency: { number }?,
	speed: NumberRange,
	lifetime: NumberRange,
	spread: number?,
	direction: Vector3?,
	acceleration: Vector3?,
	drag: number?,
	glow: number?, -- light emission (0..1)
	count: number,
	zOffset: number?,
}

local function sequence(values: { number }): NumberSequence
	if #values == 1 then
		return NumberSequence.new(values[1])
	end
	local keys = {}
	for index, value in values do
		table.insert(keys, NumberSequenceKeypoint.new((index - 1) / (#values - 1), value))
	end
	return NumberSequence.new(keys)
end

local function configure(emitter: ParticleEmitter, o: EmitOptions)
	emitter.Texture = o.texture
	emitter.Color = if o.color2
		then ColorSequence.new(o.color, o.color2)
		else ColorSequence.new(o.color)
	emitter.Size = sequence(o.size)
	emitter.Transparency = sequence(o.transparency or { 0.2, 1 })
	emitter.Speed = o.speed
	emitter.Lifetime = o.lifetime
	emitter.SpreadAngle = Vector2.new(o.spread or 30, o.spread or 30)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Acceleration = o.acceleration or Vector3.zero
	emitter.Drag = o.drag or 2
	emitter.LightEmission = o.glow or 0
	emitter.LightInfluence = if (o.glow or 0) > 0 then 0 else 1
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.ZOffset = o.zOffset or 0
	emitter.Rate = 0
end

-- One-shot particles from `position`, along `o.direction` (up by default).
local function emit(position: Vector3, o: EmitOptions)
	local point = Instance.new("Attachment")
	point.WorldCFrame = facing(position, o.direction or Vector3.yAxis)
	point.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	configure(emitter, o)
	emitter.Parent = point
	emitter:Emit(o.count)
	Debris:AddItem(point, o.lifetime.Max + 0.3)
end

-- Continuous particles on `parent` (an attachment) until destroyed.
local function stream(parent: Attachment, o: EmitOptions, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	configure(emitter, o)
	emitter.Rate = rate
	emitter.Parent = parent
	return emitter
end

local function smokePuff(
	position: Vector3,
	count: number,
	size: number,
	color: Color3,
	direction: Vector3?,
	speed: number?
)
	emit(position, {
		texture = TEX.smoke,
		color = color,
		size = { size, size * 2.6, size * 3.4 },
		transparency = { 0.3, 0.55, 1 },
		speed = NumberRange.new((speed or 10) * 0.5, speed or 10),
		lifetime = NumberRange.new(0.7, 1.6),
		spread = 70,
		direction = direction,
		acceleration = Vector3.new(0, 2, 0),
		drag = 3,
		count = count,
	})
end

local function sparks(
	position: Vector3,
	count: number,
	color: Color3,
	direction: Vector3?,
	speed: number?,
	spread: number?
)
	emit(position, {
		texture = TEX.sparks,
		color = WHITE,
		color2 = color,
		size = { 0.35, 0.2, 0 },
		transparency = { 0, 0.2, 1 },
		speed = NumberRange.new((speed or 30) * 0.4, speed or 30),
		lifetime = NumberRange.new(0.25, 0.6),
		spread = spread or 80,
		direction = direction,
		acceleration = Vector3.new(0, -60, 0),
		drag = 1.5,
		glow = 1,
		count = count,
	})
end

-- Dust rolling outward all around `position` (a ground impact).
local function dustRing(position: Vector3, radius: number, strength: number, color: Color3)
	for index = 1, 10 do
		local angle = index / 10 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local out = Vector3.new(math.cos(angle), 0.12, math.sin(angle))
		emit(position + out * radius * 0.3 + Vector3.new(0, 0.6, 0), {
			texture = TEX.smoke,
			color = color,
			size = { 1.2 * strength, 3.5 * strength, 5 * strength },
			transparency = { 0.25, 0.5, 1 },
			speed = NumberRange.new(14 * strength, 26 * strength),
			lifetime = NumberRange.new(1, 2.2),
			spread = 18,
			direction = out,
			acceleration = Vector3.new(0, 1.5, 0),
			drag = 3.2,
			count = 3,
		})
	end
end

-- Slabs of the floor torn up and tilted out around a crater; they sink
-- back after `life` seconds.
local function eruption(position: Vector3, radius: number, count: number, life: number)
	local floor = floorAt(position)
	if floor == nil then
		return
	end
	local material = if floor.material == Enum.Material.Air
		then Enum.Material.Slate
		else floor.material
	if material == Enum.Material.Plastic or material == Enum.Material.SmoothPlastic then
		material = Enum.Material.Slate
	end
	local up = floor.normal
	local centre = floor.position
	for index = 1, count do
		local angle = index / count * math.pi * 2 + random:NextNumber(-0.25, 0.25)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local size = Vector3.new(
			random:NextNumber(0.9, 1.8),
			random:NextNumber(0.5, 1.1),
			random:NextNumber(1, 2)
		)
		size *= radius / 5
		local slab = newPart(
			size,
			floor.color:Lerp(Color3.new(0, 0, 0), random:NextNumber(0, 0.25)),
			material
		)
		slab.CastShadow = true
		slab.Parent = fx
		local at = centre + out * radius * random:NextNumber(0.75, 1.1)
		-- (tilted outward, like the ground was pushed up from the middle)
		local tilt = math.rad(random:NextNumber(20, 55))
		local rest = CFrame.lookAt(at, at + out, up)
			* CFrame.Angles(tilt, random:NextNumber(-0.3, 0.3), 0)
			* CFrame.new(0, size.Y * 0.2, 0)
		local buried = rest - up * (size.Y + 0.6)
		slab.CFrame = buried
		local delay = random:NextNumber(0, 0.05)
		task.delay(delay, function()
			animate(0.16, function(alpha)
				slab.CFrame = buried:Lerp(rest, math.min(1, outBack(alpha)))
			end)
		end)
		task.delay(life + delay, function()
			animate(0.8, function(alpha)
				slab.CFrame = rest:Lerp(buried, alpha * alpha)
				slab.Transparency = alpha ^ 3
			end, function()
				slab:Destroy()
			end)
		end)
	end
end

-- Jagged cracks running out on the floor (with a glowing core if `glow`).
local function cracks(position: Vector3, count: number, length: number, life: number, glow: Color3?)
	local floor = floorAt(position)
	if floor == nil then
		return
	end
	local up = floor.normal
	local ground = floor.color
	-- A crack: a narrow dark gap, chipped lighter edges on both sides (the
	-- broken top of the floor catching the light), tapering to nothing.
	local gap = Color3.new(ground.R * 0.12, ground.G * 0.12, ground.B * 0.12)
	local chipped = ground:Lerp(Color3.new(1, 1, 1), 0.18)
	local pieces: { BasePart } = {}
	local glows: { BasePart } = {}
	-- (each point put back on the floor: cracks follow bumps and dips)
	local function snap(point: Vector3): RaycastResult?
		return workspace:Raycast(point + up * 2, -up * 4, floorParams)
	end
	local function segment(a: Vector3, b: Vector3, width: number, normal: Vector3)
		local span = (b - a).Magnitude
		if span < 1e-3 then
			return
		end
		local frame = CFrame.lookAt((a + b) / 2, b, normal)
		local edge = newPart(Vector3.new(width * 1.9, 0.02, span + width), chipped)
		edge.Transparency = 0.55
		edge.Material = floor.material
		edge.CFrame = frame + normal * 0.012
		edge.Parent = fx
		table.insert(pieces, edge)
		local crack = newPart(Vector3.new(width, 0.025, span + width * 0.6), gap)
		crack.CFrame = frame + normal * 0.02
		crack.Parent = fx
		table.insert(pieces, crack)
		if glow then
			local core = newPart(Vector3.new(width * 0.4, 0.028, span), glow, Enum.Material.Neon)
			core.CFrame = frame + normal * 0.024
			core.Parent = fx
			table.insert(glows, core)
		end
	end
	-- A jagged line from `from` along `direction`: many short kinks, width
	-- shrinking to a hairline; branches fork off the main ones.
	local tips: { { Vector3 } } = {}
	local function line(
		from: Vector3,
		direction: Vector3,
		reach: number,
		width: number,
		depth: number
	)
		local steps = math.clamp(math.floor(reach / 0.45), 3, 12)
		local point = from
		local dir = direction
		local points = { from }
		for step = 1, steps do
			local side = dir:Cross(up).Unit
			dir = (dir + side * random:NextNumber(-0.55, 0.55)).Unit
			local landed = snap(point + dir * reach / steps * random:NextNumber(0.75, 1.25))
			if landed == nil then
				break -- (off an edge)
			end
			local nextPoint = landed.Position + landed.Normal * 0.02
			local t = (step - 1) / steps
			segment(point, nextPoint, math.max(0.025, width * (1 - t) ^ 1.3), landed.Normal)
			table.insert(points, nextPoint)
			-- forks: thinner, shorter, at a sharp angle
			if
				depth < 2
				and step > 1
				and step < steps
				and random:NextNumber() < 0.28 - depth * 0.1
			then
				local sign = if random:NextNumber() < 0.5 then 1 else -1
				local fork = (dir + side * sign * random:NextNumber(0.6, 1.2)).Unit
				line(
					nextPoint,
					fork,
					reach * (1 - t) * random:NextNumber(0.35, 0.6),
					width * (1 - t) * 0.6,
					depth + 1
				)
			end
			point = nextPoint
		end
		if depth == 0 then
			table.insert(tips, points)
		end
	end
	local origin = floor.position + up * 0.02
	for index = 1, count do
		local angle = (index / count + random:NextNumber(-0.05, 0.05)) * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		direction = (direction - up * direction:Dot(up)).Unit
		line(
			origin + direction * length * 0.06,
			direction,
			length * random:NextNumber(0.65, 1.15),
			math.min(0.22, 0.05 + length * 0.025),
			0
		)
	end
	-- The spider web: short cross cracks joining neighbouring lines, as
	-- the floor around the centre gives way in rings.
	if count >= 5 then
		for index, points in tips do
			local other = tips[index % #tips + 1]
			for _, band in { 0.3, 0.55 } do
				local a = points[math.max(2, math.floor(#points * band))]
				local b = other[math.max(2, math.floor(#other * band))]
				if a and b and random:NextNumber() < 0.75 and (b - a).Magnitude < length * 0.9 then
					local mid = (a + b) / 2 + (a + b - origin * 2).Unit * random:NextNumber(0, 0.2)
					segment(a, mid, 0.05, up)
					segment(mid, b, 0.04, up)
				end
			end
		end
		-- The middle crushed: broken floor tiles pushed down and tilted.
		local floorMaterial = if floor.material == Enum.Material.Air
			then Enum.Material.Slate
			else floor.material
		for _ = 1, math.floor(count * 1.2) do
			local spot = origin
				+ Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
					* length
					* 0.16
			local size = random:NextNumber(0.35, 0.8) * length / 6
			local shard = newPart(
				Vector3.new(size, 0.12, size * random:NextNumber(0.6, 1.1)),
				ground:Lerp(gap, random:NextNumber(0.1, 0.4)),
				floorMaterial
			)
			local spin = random:NextUnitVector()
			spin -= up * spin:Dot(up)
			spin = if spin.Magnitude > 1e-3 then spin.Unit else up:Cross(Vector3.xAxis).Unit
			shard.CFrame = CFrame.lookAt(spot, spot + spin, up)
				* CFrame.Angles(random:NextNumber(-0.25, 0.25), 0, random:NextNumber(-0.25, 0.25))
			shard.Parent = fx
			table.insert(pieces, shard)
		end
		-- a dark hollow under the tiles
		local hollow = newPart(
			Vector3.new(0.02, length * 0.32, length * 0.32),
			gap,
			nil,
			Enum.PartType.Cylinder
		)
		hollow.Transparency = 0.45
		hollow.CFrame = facing(origin + up * 0.008, up) * CFrame.Angles(0, math.rad(90), 0)
		hollow.Parent = fx
		table.insert(pieces, hollow)
	end
	if #glows > 0 then
		local hot = glow :: Color3
		animate(life * 0.45, function(alpha)
			local color = hot:Lerp(Color3.fromRGB(60, 20, 10), alpha)
			for _, core in glows do
				core.Color = color
				core.Transparency = alpha ^ 2
			end
		end, function()
			for _, core in glows do
				core:Destroy()
			end
		end)
	end
	local start: { [BasePart]: number } = {}
	for _, piece in pieces do
		start[piece] = piece.Transparency
	end
	task.delay(life * 0.75, function()
		animate(life * 0.25, function(alpha)
			for _, piece in pieces do
				piece.Transparency = start[piece] + (1 - start[piece]) * alpha
			end
		end, function()
			for _, piece in pieces do
				piece:Destroy()
			end
		end)
	end)
end

-- Rocks thrown up out of the floor (its colour and material). Feather-
-- light: one landing on a fighter doesn't shove them.
local function rocks(position: Vector3, count: number, power: number)
	local floor = floorAt(position)
	local at = if floor then floor.position else position
	local color = if floor then floor.color else Color3.fromRGB(96, 92, 88)
	local material = Enum.Material.Slate
	for index = 1, count do
		local size = random:NextNumber(0.25, 0.75)
		local rock = newPart(
			Vector3.new(size, size * random:NextNumber(0.5, 1), size * random:NextNumber(0.7, 1.2)),
			color,
			material
		)
		rock.Anchored = false
		rock.CanCollide = true
		rock.CastShadow = true
		rock.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0.5, 0.2)
		rock.CollisionGroup = DEBRIS_GROUP
		local angle = random:NextNumber(0, math.pi * 2)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		rock.CFrame = CFrame.new(at + out * random:NextNumber(1, 2.5) + Vector3.new(0, 0.5, 0))
			* CFrame.Angles(random:NextNumber(0, 6.3), random:NextNumber(0, 6.3), 0)
		rock.AssemblyLinearVelocity = out * random:NextNumber(4, 14) * power
			+ Vector3.new(0, random:NextNumber(20, 38) * power, 0)
		rock.AssemblyAngularVelocity = random:NextUnitVector() * 14
		rock.Parent = fx
		-- some trail a little dust
		if index % 3 == 0 then
			local point = Instance.new("Attachment")
			point.Parent = rock
			stream(point, {
				texture = TEX.smoke,
				color = dustColor(floor),
				size = { 0.3, 0.9 },
				transparency = { 0.4, 1 },
				speed = NumberRange.new(0),
				lifetime = NumberRange.new(0.3, 0.5),
				count = 0,
			}, 30)
		end
		Debris:AddItem(rock, 4)
		task.delay(3.2, function()
			if rock.Parent then
				tween(rock, 0.7, { Transparency = 1 })
			end
		end)
	end
end

-- Air / speed lines flying along `direction` from around `origin`.
local function streaks(
	origin: Vector3,
	direction: Vector3,
	count: number,
	spread: number,
	length: number,
	speed: number,
	color: Color3,
	time: number
)
	local d = direction.Unit
	local base = facing(origin, d)
	for _ = 1, count do
		local offset = base.RightVector * random:NextNumber(-spread, spread)
			+ base.UpVector * random:NextNumber(-spread, spread)
		local start = origin + offset
		local line = newPart(Vector3.new(0.06, 0.06, length), color, Enum.Material.Neon)
		line.Transparency = 0.2
		line.Parent = fx
		local delay = random:NextNumber(0, time * 0.3)
		local travel = speed * random:NextNumber(0.7, 1.2)
		animate(time + delay, function(alpha)
			local t = math.max(0, alpha * (time + delay) - delay) / time
			local stretch = length * (0.4 + 1.2 * outQuad(t))
			local at = start + d * (travel * time * outQuad(t))
			line.CFrame = facing(at + d * stretch / 2, d)
			line.Size = Vector3.new(0.06 * (1 - t * 0.6), 0.06 * (1 - t * 0.6), stretch)
			line.Transparency = if t <= 0 then 1 else 0.2 + 0.8 * t
		end, function()
			line:Destroy()
		end)
	end
end

-- A crackling bolt from `a` to `b` (re-jagged a few times, then gone).
local function lightning(a: Vector3, b: Vector3, color: Color3, width: number, time: number)
	local segments = math.clamp(math.floor((b - a).Magnitude / 0.8), 3, 14)
	local cores: { BasePart } = {}
	local halos: { BasePart } = {}
	for _ = 1, segments do
		local core = newPart(Vector3.new(width, width, 1), WHITE, Enum.Material.Neon)
		core.Parent = fx
		table.insert(cores, core)
		local halo = newPart(Vector3.new(width * 3, width * 3, 1), color, Enum.Material.Neon)
		halo.Transparency = 0.6
		halo.Parent = fx
		table.insert(halos, halo)
	end
	local frames: { CFrame } = {}
	local both: { BasePart } = {}
	local lastShape = -1
	local axis = facing(a, b - a)
	local length = (b - a).Magnitude
	animate(time, function(alpha)
		local shape = math.floor(alpha * 4)
		if shape ~= lastShape then
			lastShape = shape
			table.clear(frames)
			table.clear(both)
			local points: { Vector3 } = {}
			for index = 0, segments do
				local t = index / segments
				local wobble = math.sin(t * math.pi) * length * 0.13
				local offset = axis.RightVector * random:NextNumber(-wobble, wobble)
					+ axis.UpVector * random:NextNumber(-wobble, wobble)
				table.insert(points, a + (b - a) * t + offset)
			end
			for index = 1, segments do
				local p, q = points[index], points[index + 1]
				local mid = facing((p + q) / 2, q - p)
				local span = (q - p).Magnitude + width
				cores[index].Size = Vector3.new(width, width, span)
				halos[index].Size = Vector3.new(width * 3, width * 3, span)
				table.insert(both, cores[index])
				table.insert(frames, mid)
				table.insert(both, halos[index])
				table.insert(frames, mid)
			end
			workspace:BulkMoveTo(both, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		for index = 1, segments do
			cores[index].Transparency = alpha ^ 2
			halos[index].Transparency = 0.6 + 0.4 * alpha
		end
	end, function()
		for index = 1, segments do
			cores[index]:Destroy()
			halos[index]:Destroy()
		end
	end)
end

-- A few short bolts crackling around `position`.
local function crackle(position: Vector3, radius: number, count: number, color: Color3)
	for _ = 1, count do
		local from = position + random:NextUnitVector() * radius * 0.3
		local to = position + random:NextUnitVector() * radius
		lightning(from, to, color, 0.05, random:NextNumber(0.08, 0.16))
	end
end

-- Energy sucked in toward `part` (+ `offset`) for `time` seconds: particles
-- from a sphere of `radius` flowing inward (a charge building up).
local function gather(
	part: BasePart,
	offset: Vector3,
	radius: number,
	time: number,
	color: Color3,
	rate: number,
	cut: (() -> boolean)? -- (true once the move is cut short: it stops)
)
	local shell = newPart(Vector3.one * radius * 2, color, nil, Enum.PartType.Ball)
	shell.Transparency = 1
	shell.Anchored = false
	shell.Massless = true
	shell.CFrame = part.CFrame * CFrame.new(offset)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = part
	joint.Part1 = shell
	joint.Parent = shell
	shell.Parent = fx
	local emitter = Instance.new("ParticleEmitter")
	configure(emitter, {
		texture = TEX.sparkle,
		color = WHITE,
		color2 = color,
		size = { 0.12, 0.3, 0 },
		transparency = { 0.6, 0, 0.2 },
		speed = NumberRange.new(radius / 0.4),
		lifetime = NumberRange.new(0.38, 0.4),
		spread = 0,
		glow = 1,
		count = 0,
	})
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	emitter.LockedToPart = true
	emitter.Rate = rate
	emitter.Parent = shell
	animate(time, function()
		if cut and cut() then
			emitter.Rate = 0
		end
	end, function()
		emitter.Rate = 0
	end)
	Debris:AddItem(shell, time + 0.5)
end

-- A glowing streak trailing behind `part` for `time` seconds.
local function trail(
	part: BasePart,
	color: Color3,
	time: number,
	width: number,
	lifetime: number?,
	offset: Vector3?
)
	local at = offset or Vector3.zero
	local a = Instance.new("Attachment")
	a.Position = at + Vector3.new(0, width / 2, 0)
	a.Parent = part
	local b = Instance.new("Attachment")
	b.Position = at - Vector3.new(0, width / 2, 0)
	b.Parent = part
	local streak = Instance.new("Trail")
	streak.Attachment0 = a
	streak.Attachment1 = b
	streak.Color = ColorSequence.new(WHITE, color)
	streak.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.4, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	streak.WidthScale = NumberSequence.new(1, 0.1)
	streak.Lifetime = lifetime or 0.25
	streak.LightEmission = 0.8
	streak.LightInfluence = 0
	streak.FaceCamera = true
	streak.Parent = part
	task.delay(time, function()
		streak.Enabled = false
	end)
	Debris:AddItem(a, time + (lifetime or 0.25) + 0.1)
	Debris:AddItem(b, time + (lifetime or 0.25) + 0.1)
	Debris:AddItem(streak, time + (lifetime or 0.25) + 0.1)
end

-- Camera shake (position only: a rotating shake would shift the aim) for
-- us if we're close to `position`, stronger closer.
local shakeUntil, shakeStrength, shakeSeed = 0, 0, 0
local function shake(position: Vector3, strength: number, radius: number, time: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance > radius then
		return
	end
	local amount = strength * (1 - distance / radius)
	shakeStrength = math.max(if os.clock() < shakeUntil then shakeStrength else 0, amount)
	shakeUntil = math.max(shakeUntil, os.clock() + time)
	shakeSeed = random:NextNumber(0, 100)
end
RunService:BindToRenderStep("KitVFXShake", Enum.RenderPriority.Camera.Value + 2, function()
	local left = shakeUntil - os.clock()
	local camera = workspace.CurrentCamera
	if left <= 0 or camera == nil then
		return
	end
	local t = os.clock() * 28
	local power = shakeStrength * 0.12 * math.min(1, left * 5)
	local offset = Vector3.new(math.noise(t, shakeSeed), math.noise(shakeSeed, t), 0) * 2 * power
	camera.CFrame += camera.CFrame:VectorToWorldSpace(offset)
end)

-- A colour punch on our screen if we're close to a big impact.
local function punch(position: Vector3, radius: number, tint: Color3, strength: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance > radius then
		return
	end
	local s = strength * (1 - distance / radius)
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "KitVFXPunch"
	correction.Brightness = 0.18 * s
	correction.Contrast = 0.35 * s
	correction.Saturation = -0.2 * s
	correction.TintColor = WHITE:Lerp(tint, 0.5 * s)
	correction.Parent = Lighting
	tween(correction, 0.4, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE })
	Debris:AddItem(correction, 0.45)
end

-- Everything a big ground impact does.
type ImpactOptions = {
	size: number, -- 1 = a stomp, 1.6 = a crater
	glow: Color3?, -- energy colour (cracks glow, energy rings)
	flashColor: Color3?,
}
local function groundImpact(position: Vector3, o: ImpactOptions)
	local s = o.size
	local floor = floorAt(position)
	local at = if floor then floor.position else position
	local dust = dustColor(floor)
	flash(
		at + Vector3.new(0, 0.8, 0),
		o.flashColor or o.glow or Color3.fromRGB(255, 220, 180),
		4 * s,
		0.35
	)
	if o.glow then
		shockSphere(at, 1, 9 * s, 0.45, o.glow)
		groundRing(at, 1.5, 17 * s, 0.55, o.glow, { neon = true, width = 0.5, height = 0.35 })
	end
	groundRing(
		at,
		2,
		22 * s,
		0.75,
		dust,
		{ width = 1.2 * s, height = 1.4 * s, transparency = 0.25 }
	)
	task.delay(0.06, function()
		groundRing(
			at,
			1,
			12 * s,
			0.6,
			WHITE,
			{ neon = true, width = 0.18, height = 0.12, transparency = 0.3 }
		)
	end)
	dustRing(at, 3 * s, s, dust)
	smokePuff(at + Vector3.new(0, 1, 0), math.floor(12 * s), 1.5 * s, dust, Vector3.yAxis, 16 * s)
	eruption(at, 4.2 * s, math.floor(10 * s), 5)
	cracks(at, math.floor(6 * s) + 2, 6.5 * s, 9, o.glow)
	rocks(at, math.floor(10 * s), 0.7 + 0.3 * s)
	sparks(
		at + Vector3.new(0, 0.5, 0),
		math.floor(16 * s),
		o.glow or EMBER,
		Vector3.yAxis,
		36 * s,
		70
	)
	shake(at, 3 * s, 55 * s, 0.55)
	punch(at, 30 * s, o.glow or Color3.fromRGB(255, 220, 190), math.min(1, 0.5 * s))
	KitLooks.gust(at, 60 * s, 30 * s)
end

local function part(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- Where the fist of `arm` is (its lower end).
local function fist(model: Model, arm: string): Vector3?
	local limb = part(model, arm)
	return if limb then (limb.CFrame * CFrame.new(0, -1, 0)).Position else nil
end

local function feet(model: Model): Vector3?
	local root = part(model, "HumanoidRootPart")
	return if root then root.Position - Vector3.new(0, 3, 0) else nil
end

local function forwardOf(model: Model): Vector3
	local root = part(model, "HumanoidRootPart")
	return if root then flat(root.CFrame.LookVector) else Vector3.new(0, 0, -1)
end

-- Runs `fn` `delay` seconds later, if the move on `model` is still the same.
local function later(model: Model, token: number, delay: number, fn: () -> ())
	task.delay(delay, function()
		if tokens[model] == token and model.Parent then
			fn()
		end
	end)
end

local function alive(model: Model, token: number): boolean
	return tokens[model] == token and model.Parent ~= nil
end

-- Glowing eyes on `head` for `time` seconds (the Bull's rage).
local function rageEyes(head: BasePart, time: number): { BasePart }
	local made: { BasePart } = {}
	for _, side in { -1, 1 } do
		local eye = newPart(Vector3.new(0.14, 0.08, 0.04), RAGE, Enum.Material.Neon)
		eye.Anchored = false
		eye.Massless = true
		eye.CFrame = head.CFrame * CFrame.new(side * 0.18, 0.12, -0.6)
		local joint = Instance.new("WeldConstraint")
		joint.Part0 = head
		joint.Part1 = eye
		joint.Parent = eye
		eye.Parent = fx
		local point = Instance.new("Attachment")
		point.Parent = eye
		stream(point, {
			texture = TEX.glow,
			color = RAGE,
			size = { 0.5, 0.2 },
			transparency = { 0.5, 1 },
			speed = NumberRange.new(0),
			lifetime = NumberRange.new(0.15, 0.25),
			glow = 1,
			count = 0,
		}, 25)
		task.delay(time, function()
			tween(eye, 0.3, { Transparency = 1 })
		end)
		Debris:AddItem(eye, time + 0.35)
		table.insert(made, eye)
	end
	return made
end

------------------------------------------------------------------------------
-- Burns (heat vision): the skin chars where the beam touches a body
------------------------------------------------------------------------------
-- (see `burn` below: a brief glow and smoke where the beam touches; the
-- burn wound itself comes from the server)

-- The skin of a body part at `p` (part space): where, and which way is out.
-- `margin`: room kept from a flat face's edges (the burn's radius).
local function onSkin(limb: BasePart, p: Vector3, margin: number?): (Vector3, Vector3)
	if limb.Name == "Head" then
		-- (the round classic head: radius 0.6, straight from -0.3 to 0.3)
		local flatP = Vector3.new(p.X, 0, p.Z)
		local out = if flatP.Magnitude > 1e-3 then flatP.Unit else Vector3.new(0, 0, -1)
		local y = math.clamp(p.Y, -0.36, 0.36)
		local over = math.max(0, math.abs(y) - 0.3)
		local radius = 0.3 + math.sqrt(math.max(0, 0.09 - over * over))
		return out * radius + Vector3.new(0, y, 0), out
	end
	-- a block: the side face the point is on (not the top / bottom)
	local half = limb.Size / 2
	local m = margin or 0
	local hx = math.max(0, math.min(half.X * 0.8, half.X - m))
	local hy = math.max(0, math.min(half.Y * 0.85, half.Y - m))
	local hz = math.max(0, math.min(half.Z * 0.7, half.Z - m))
	local x, z = p.X / half.X, p.Z / half.Z
	if math.abs(x) > math.abs(z) then
		local side = if x >= 0 then 1 else -1
		return Vector3.new(side * half.X, math.clamp(p.Y, -hy, hy), math.clamp(p.Z, -hz, hz)),
			Vector3.new(side, 0, 0)
	end
	local side = if z >= 0 then 1 else -1
	return Vector3.new(math.clamp(p.X, -hx, hx), math.clamp(p.Y, -hy, hy), side * half.Z),
		Vector3.new(0, 0, side)
end

-- Thin smoke rising off a fresh burn for a few seconds.
local function smoulder(limb: BasePart, at: Vector3, out: Vector3, time: number)
	local point = Instance.new("Attachment")
	point.CFrame = facing(at, out)
	point.Parent = limb
	local wisps = stream(point, {
		texture = TEX.smoke,
		color = Color3.fromRGB(96, 90, 86),
		size = { 0.12, 0.5, 0.9 },
		transparency = { 0.55, 0.75, 1 },
		speed = NumberRange.new(0.6, 1.4),
		lifetime = NumberRange.new(0.9, 1.5),
		spread = 12,
		acceleration = Vector3.new(0, 2.5, 0),
		drag = 1.5,
		count = 0,
	}, 6)
	animate(time, function(alpha)
		wisps.Rate = 6 * (1 - alpha)
	end, function()
		wisps.Rate = 0
		Debris:AddItem(point, 1.6)
	end)
end

-- A flat oval on the skin of `limb` at `at` (part space), facing `out`,
-- its length along `along` (a flattened sphere mesh: a true oval).
local function skinOval(
	limb: BasePart,
	folder: Instance,
	at: Vector3,
	out: Vector3,
	along: Vector3,
	width: number,
	length: number,
	color: Color3,
	transparency: number,
	material: Enum.Material?
): Part
	local forward = along - out * along:Dot(out)
	if forward.Magnitude < 1e-3 then
		forward = out:Cross(Vector3.new(0.3, 0.9, 0.3))
	end
	forward = forward.Unit
	local piece = newPart(Vector3.new(0.008, width, length), color, material)
	local oval = Instance.new("SpecialMesh")
	oval.MeshType = Enum.MeshType.Sphere
	oval.Parent = piece
	piece.Name = "Burn"
	piece.Transparency = transparency
	piece.Anchored = false
	piece.Massless = true
	-- (X out of the skin, Z along: Y = along × out)
	piece.CFrame = limb.CFrame * CFrame.fromMatrix(at, out, forward:Cross(out))
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = limb
	joint.Part1 = piece
	joint.Parent = piece
	piece.Parent = folder
	return piece
end

-- Where the beam touches a body: the skin glowing hot for a moment, smoke
-- rising off it. (The burn itself - the skin burnt through, the skull or
-- cooked muscle showing - is a "Burn" wound from the server, drawn by
-- Gashes: the same for everyone, and it stays.)
local lastGlow: { [Model]: number } = {}
local function burn(body: Model, limb: BasePart, position: Vector3, force: boolean?)
	local now = os.clock()
	if not force and now - (lastGlow[body] or 0) < 0.1 then
		return
	end
	if lastGlow[body] == nil then
		body.Destroying:Once(function()
			lastGlow[body] = nil
		end)
	end
	lastGlow[body] = now
	local p, o = onSkin(limb, limb.CFrame:PointToObjectSpace(position), 0.06)
	local glow = skinOval(
		limb,
		limb,
		p + o * 0.01,
		o,
		Vector3.yAxis,
		0.22,
		0.24,
		EMBER,
		0.1,
		Enum.Material.Neon
	)
	animate(0.5, function(alpha)
		glow.Color = EMBER:Lerp(LASER_DEEP, alpha)
		glow.Transparency = 0.1 + 0.9 * alpha
	end, function()
		glow:Destroy()
	end)
	smoulder(limb, p + o * 0.03, o, 1.5)
	emit(limb.CFrame * p, {
		texture = TEX.smoke,
		color = Color3.fromRGB(70, 64, 60),
		size = { 0.2, 0.7, 1.1 },
		transparency = { 0.4, 0.65, 1 },
		speed = NumberRange.new(1, 2.5),
		lifetime = NumberRange.new(0.7, 1.2),
		spread = 25,
		direction = limb.CFrame:VectorToWorldSpace(o),
		acceleration = Vector3.new(0, 3, 0),
		count = 2,
	})
end

------------------------------------------------------------------------------
-- SENTINEL
------------------------------------------------------------------------------

local BEAM_LAYERS = {
	{ color = LASER_CORE, width = 0.1, transparency = 0 },
	{ color = LASER, width = 0.26, transparency = 0.25 },
	{ color = LASER_DEEP, width = 0.7, transparency = 0.8 },
}

-- Heat vision: the eyes charge up (energy sucked in, red light, sparks),
-- then two beams burn straight ahead the way he faced when it started.
-- Like the server (Shared/Util/HeatBeam), it ends on the first thing in its
-- way: a head burns (after a moment in it: glowing skin, smoke), any other
-- body part just blocks it (sparks glancing off, no burn); a wall gets a
-- scorched, molten trail.
local function heatVision(model: Model, move: Kits.MoveDef, token: number)
	local beam = move.beam
	local head = part(model, "Head")
	if beam == nil or head == nil then
		return
	end
	local direction = forwardOf(model)
	local folder = Instance.new("Folder")
	folder.Name = "HeatVision"
	folder.Parent = fx

	-- The eyes light up only for this (fading in with the charge).
	local eyes: { BasePart } = {}
	do
		for _, side in { -1, 1 } do
			local eye = newPart(Vector3.new(0.13, 0.08, 0.04), LASER, Enum.Material.Neon)
			eye.Transparency = 1
			eye.Anchored = false
			eye.Massless = true
			eye.CFrame = head.CFrame * CFrame.new(side * 0.17, 0.11, -0.6)
			local joint = Instance.new("WeldConstraint")
			joint.Part0 = head
			joint.Part1 = eye
			joint.Parent = eye
			eye.Parent = folder
			table.insert(eyes, eye)
		end
	end
	-- a flare in front of each eye, growing with the charge
	local flares: { BasePart } = {}
	for _ = 1, #eyes do
		local flare = newPart(Vector3.one * 0.05, LASER, Enum.Material.Neon, Enum.PartType.Ball)
		flare.Transparency = 0.3
		flare.Parent = folder
		table.insert(flares, flare)
	end
	local glow = Instance.new("PointLight")
	glow.Color = LASER
	glow.Brightness = 0
	glow.Range = 10
	glow.Shadows = false
	glow.Parent = head

	local charge = SoundController.play("LaserCharge", model)
	gather(head, Vector3.new(0, 0.1, -0.5), 2.6, beam.from, LASER, 70, function()
		return not alive(model, token)
	end)
	-- heat haze around the head while charging
	local haze = Instance.new("Attachment")
	haze.Position = Vector3.new(0, 0.1, -0.6)
	haze.Parent = head
	local hazeEmitter = stream(haze, {
		texture = TEX.glow,
		color = EMBER,
		color2 = LASER,
		size = { 0.4, 1.1, 0 },
		transparency = { 0.85, 0.7, 1 },
		speed = NumberRange.new(0.5, 1.5),
		lifetime = NumberRange.new(0.3, 0.5),
		spread = 180,
		glow = 1,
		count = 0,
	}, 30)

	-- The beams: a white-hot core, a red body, a wide faint glow (per eye).
	type Layer = { part: Part, width: number }
	local beams: { { Layer } } = {}
	for _ = 1, #eyes do
		local layers: { Layer } = {}
		for _, spec in BEAM_LAYERS do
			local layer =
				newPart(Vector3.new(spec.width, spec.width, 1), spec.color, Enum.Material.Neon)
			layer.Transparency = spec.transparency
			table.insert(layers, { part = layer, width = spec.width })
		end
		table.insert(beams, layers)
	end
	-- the hot spot where it lands
	local impact = Instance.new("Attachment")
	impact.Parent = workspace.Terrain
	local fountain = stream(impact, {
		texture = TEX.sparks,
		color = WHITE,
		color2 = EMBER,
		size = { 0.4, 0.2, 0 },
		transparency = { 0, 0.3, 1 },
		speed = NumberRange.new(10, 26),
		lifetime = NumberRange.new(0.25, 0.6),
		spread = 60,
		acceleration = Vector3.new(0, -70, 0),
		drag = 1,
		glow = 1,
		count = 0,
	}, 0)
	local smoke = stream(impact, {
		texture = TEX.smoke,
		color = Color3.fromRGB(64, 58, 56),
		size = { 0.6, 2, 3 },
		transparency = { 0.45, 0.7, 1 },
		speed = NumberRange.new(2, 5),
		lifetime = NumberRange.new(0.9, 1.6),
		spread = 25,
		acceleration = Vector3.new(0, 4, 0),
		count = 0,
	}, 0)
	local molten = newPart(Vector3.one * 0.7, EMBER, Enum.Material.Neon, Enum.PartType.Ball)
	molten.Transparency = 1
	molten.Parent = folder
	local heat = Instance.new("PointLight")
	heat.Color = EMBER
	heat.Brightness = 0
	heat.Range = 12
	heat.Shadows = false
	heat.Parent = impact

	local trace = HeatBeam.tracer(model, { fx :: Instance })
	local startedAt = os.clock()
	local lastScorch, lastBurn, lastGlance = 0, 0, 0
	-- (the server's warm-up, mirrored: heat per head, on the same tick grid)
	local contact: { [Model]: number? } = {}
	local nextTick = startedAt + beam.from
	local firing = false
	local loop: Sound? = nil
	local connection: RBXScriptConnection? = nil
	local finished = false

	local function finish()
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if loop then
			loop:Stop()
		end
		if charge then
			charge:Stop()
		end
		fountain.Rate = 0
		smoke.Rate = 0
		hazeEmitter.Rate = 0
		Debris:AddItem(haze, 0.6)
		tween(heat, 0.3, { Brightness = 0 })
		tween(glow, 0.6, { Brightness = 0 })
		tween(molten, 0.3, { Transparency = 1 })
		for _, layers in beams do
			for _, layer in layers do
				tween(layer.part, 0.12, { Transparency = 1 })
			end
		end
		for _, flare in flares do
			tween(flare, 0.4, { Transparency = 1 })
		end
		-- the eyes cool down, steaming a little
		for _, eye in eyes do
			tween(eye, 0.5, { Transparency = 1 })
			emit(eye.Position, {
				texture = TEX.smoke,
				color = Color3.fromRGB(120, 110, 108),
				size = { 0.15, 0.6 },
				transparency = { 0.5, 1 },
				speed = NumberRange.new(0.5, 1.5),
				lifetime = NumberRange.new(0.6, 1),
				spread = 20,
				acceleration = Vector3.new(0, 2, 0),
				count = 3,
			})
		end
		task.delay(0.65, function()
			glow:Destroy()
		end)
		Debris:AddItem(folder, 0.7)
		Debris:AddItem(impact, 1.8)
	end

	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local elapsed = now - startedAt
		if not alive(model, token) or head.Parent == nil or elapsed > beam.to then
			finish()
			return
		end
		local charged = math.clamp(elapsed / beam.from, 0, 1)
		for index, flare in flares do
			local eye = eyes[index]
			local size = if firing then 0.32 + math.random() * 0.08 else 0.05 + 0.28 * charged ^ 2
			flare.Size = Vector3.one * size
			flare.CFrame = eye.CFrame * CFrame.new(0, 0, -0.03)
		end
		if not firing then
			glow.Brightness = 7 * charged ^ 2
			for _, eye in eyes do
				eye.Transparency = 1 - charged
			end
			-- crackling just before it fires
			if charged > 0.6 and math.random() < 0.18 then
				crackle(eyes[1].Position, 0.8, 1, LASER)
			end
			if elapsed < beam.from then
				return
			end
			firing = true
			if charge then
				charge:Stop()
			end
			loop = SoundController.play("LaserBeam", model)
			if loop then
				loop.Looped = true
			end
			hazeEmitter.Rate = 10
			flash(head.Position + direction * 0.8, LASER, 3, 0.3)
			ring(
				axisFrame(head.Position + direction * 1, direction),
				0.3,
				3.5,
				0.35,
				LASER,
				{ neon = true, width = 0.12, height = 0.08 }
			)
			shake(head.Position, 1, 30, 0.25)
			for _, layers in beams do
				for _, layer in layers do
					layer.part.Parent = folder
				end
			end
			fountain.Rate = 140
			smoke.Rate = 22
			heat.Brightness = 6
			glow.Brightness = 9
		end

		-- Where it goes: stopped by a wall or by the first body in its way
		-- (the same rule as the server).
		local origin = head.Position + direction * 0.5
		local hit = trace(origin, direction, beam.range)
		local target = hit.position
		local normal = hit.normal
		local onWall = normal ~= nil and hit.fighter == nil
		local pulse = 0.85 + math.sin(now * 40) * 0.08 + math.random() * 0.12
		for index, layers in beams do
			local from = eyes[index].Position
			local length = (target - from).Magnitude
			local frame = CFrame.lookAt(from + (target - from) / 2, target)
			for _, layer in layers do
				layer.part.CFrame = frame
				layer.part.Size = Vector3.new(layer.width * pulse, layer.width * pulse, length)
			end
		end
		impact.WorldCFrame = if normal then facing(target, normal) else CFrame.new(target)
		-- (sparks off a wall; fewer off a head; a body only gets a glance)
		fountain.Rate = if onWall then 140 elseif hit.head then 60 else 0
		molten.CFrame = CFrame.new(target)
		molten.Transparency = if onWall then 0.15 else 1
		molten.Size = Vector3.one * (0.6 + math.random() * 0.25)

		-- Molten, then charred, trail on the floor / wall.
		if onWall and normal and now - lastScorch > 0.05 then
			lastScorch = now
			local size = random:NextNumber(0.6, 0.95)
			local scorch = newPart(
				Vector3.new(0.02, size, size),
				EMBER,
				Enum.Material.Neon,
				Enum.PartType.Cylinder
			)
			scorch.CFrame = facing(target + normal * 0.02, normal)
				* CFrame.Angles(0, math.rad(90), 0)
			scorch.Parent = fx
			animate(1.4, function(alpha)
				if alpha < 0.5 then
					scorch.Color = EMBER:Lerp(LASER_DEEP, alpha * 2)
				else
					scorch.Material = Enum.Material.Slate
					scorch.Color = LASER_DEEP:Lerp(CHAR, (alpha - 0.5) * 2)
				end
			end)
			task.delay(7, function()
				animate(2.5, function(alpha)
					scorch.Transparency = alpha
				end, function()
					scorch:Destroy()
				end)
			end)
		end

		-- (only a living head that isn't knocked out burns, like the server)
		local victim = if hit.head then hit.fighter else nil
		if victim then
			local humanoid = victim:FindFirstChildOfClass("Humanoid")
			if
				humanoid == nil
				or humanoid.Health <= 0
				or victim:GetAttribute("KnockedOut") == true
			then
				victim = nil
			end
		end
		-- An arm, the chest, a leg in the way: it doesn't burn, it glances
		-- off (a few sparks thrown back), no mark.
		if hit.fighter and not hit.head and normal and now - lastGlance > 0.07 then
			lastGlance = now
			local bounce = direction - normal * 2 * direction:Dot(normal)
			sparks(target, 4, EMBER, bounce, 12, 55)
		end

		-- The head heats up while it's in the beam, cools down twice as fast
		-- out of it (the server's warm-up, on the same tick grid).
		if now >= nextTick then
			nextTick = math.max(nextTick + beam.tick, now - beam.tick)
			for owner, value in contact do
				if owner ~= victim then
					local cooled = (value or 0) - beam.tick * 2
					contact[owner] = if cooled > 0 then cooled else nil
				end
			end
			if victim then
				contact[victim] = (contact[victim] or 0) + beam.tick
			end
		end
		-- Charred skin where it touches the head (once warmed up), smoke
		-- rising off it. (The burn wound itself comes from the server.)
		local face = hit.part
		local at = hit.burnAt
		if
			victim
			and face
			and at
			and (contact[victim] or 0) >= beam.warmup
			and now - lastBurn > 0.12
		then
			lastBurn = now
			burn(victim, face, at)
			sparks(at, 6, EMBER, normal, 14, 50)
		end
	end)
end

local function thunderClap(model: Model, token: number)
	-- the hands crackle as the arms open
	for step = 1, 4 do
		later(model, token, 0.05 + step * 0.06, function()
			for _, arm in { "Right Arm", "Left Arm" } do
				local hand = fist(model, arm)
				if hand then
					crackle(hand, 1, 1, ENERGY)
				end
			end
		end)
	end
	later(model, token, 0.34, function()
		local right, left = fist(model, "Right Arm"), fist(model, "Left Arm")
		if right == nil or left == nil then
			return
		end
		local hands = (right + left) / 2
		local forward = forwardOf(model)
		SoundController.play("ThunderClap", model)
		flash(hands, ENERGY, 5, 0.35)
		shockSphere(hands, 0.5, 6, 0.35, ENERGY)
		-- the blast: rings in a cone, air lines, lightning, dust pushed ahead
		for index = 0, 3 do
			task.delay(index * 0.04, function()
				local at = hands + forward * (1 + index * 2.4)
				ring(
					axisFrame(at, forward),
					0.5 + index * 0.5,
					4 + index * 2.6,
					0.45,
					if index % 2 == 0 then WHITE else ENERGY,
					{
						neon = true,
						width = 0.22,
						height = 0.14,
					}
				)
			end)
		end
		streaks(hands + forward, forward, 16, 2.2, 3, 45, WHITE, 0.4)
		for _ = 1, 4 do
			local reach = forward * random:NextNumber(7, 12)
				+ Vector3.new(
					random:NextNumber(-3, 3),
					random:NextNumber(-1, 2),
					random:NextNumber(-3, 3)
				)
			lightning(hands, hands + reach, ENERGY_DEEP, 0.08, 0.22)
		end
		local ground = feet(model)
		if ground then
			local floor = floorAt(ground)
			for step = 1, 5 do
				smokePuff(
					ground + forward * step * 2.4 + Vector3.new(0, 0.6, 0),
					4,
					1,
					dustColor(floor),
					forward,
					20
				)
			end
			groundRing(
				ground + forward * 2,
				1,
				9,
				0.5,
				dustColor(floor),
				{ width = 0.8, height = 0.6 }
			)
		end
		shake(hands, 1.8, 35, 0.35)
		punch(hands, 22, ENERGY, 0.6)
		KitLooks.gust(hands - forward * 2, 70, 30)
	end)
end

local function skyfall(model: Model, move: Kits.MoveDef, token: number)
	local leap = move.leap
	local jumpAt = if leap then leap.at else 0.18
	local hitAt = if move.hits[1] then move.hits[1].at else 0.84
	-- crouching: the floor starts to shake, pebbles lift
	local ground = feet(model)
	if ground then
		emit(ground + Vector3.new(0, 0.3, 0), {
			texture = TEX.smoke,
			color = dustColor(floorAt(ground)),
			size = { 0.6, 1.6 },
			transparency = { 0.5, 1 },
			speed = NumberRange.new(2, 5),
			lifetime = NumberRange.new(0.4, 0.8),
			spread = 80,
			count = 8,
		})
	end
	later(model, token, jumpAt, function()
		local spot = feet(model)
		local torso = part(model, "Torso")
		SoundController.play("SkyfallJump", model)
		if spot then
			groundImpact(spot, { size = 1, glow = ENERGY })
		end
		if torso then
			trail(torso, ENERGY, hitAt - jumpAt, 1.8, 0.35)
			local wind = Instance.new("Attachment")
			wind.Parent = torso
			stream(wind, {
				texture = TEX.sparkle,
				color = WHITE,
				color2 = ENERGY,
				size = { 0.2, 0 },
				transparency = { 0.3, 1 },
				speed = NumberRange.new(2, 6),
				lifetime = NumberRange.new(0.2, 0.4),
				spread = 180,
				glow = 1,
				count = 0,
			}, 40)
			Debris:AddItem(wind, hitAt - jumpAt)
		end
	end)
	-- coming down: the fist glows, speed lines
	later(model, token, hitAt - 0.22, function()
		local arm = part(model, "Right Arm")
		local root = part(model, "HumanoidRootPart")
		if arm then
			gather(arm, Vector3.new(0, -1, 0), 1.6, 0.22, ENERGY, 60, function()
				return not alive(model, token)
			end)
			trail(arm, ENERGY, 0.25, 0.8, 0.2, Vector3.new(0, -1, 0))
		end
		if root then
			streaks(
				root.Position + Vector3.new(0, 4, 0),
				Vector3.new(0, 1, 0),
				10,
				1.6,
				4,
				30,
				WHITE,
				0.35
			)
		end
	end)
	later(model, token, hitAt, function()
		local spot = feet(model)
		if spot == nil then
			return
		end
		SoundController.play("Slam", model)
		groundImpact(spot + forwardOf(model) * 1, { size = 1.7, glow = ENERGY })
	end)
end

local function haymaker(model: Model, token: number)
	local impactAt = 0.55
	local arm = part(model, "Right Arm")
	if arm then
		-- the fist charges up during the wind-up
		local charge = newPart(Vector3.one * 0.3, ENERGY, Enum.Material.Neon, Enum.PartType.Ball)
		charge.Transparency = 0.4
		charge.Anchored = false
		charge.Massless = true
		charge.CFrame = arm.CFrame * CFrame.new(0, -1.05, 0)
		local joint = Instance.new("WeldConstraint")
		joint.Part0 = arm
		joint.Part1 = charge
		joint.Parent = charge
		local glow = Instance.new("PointLight")
		glow.Color = ENERGY
		glow.Brightness = 0
		glow.Range = 8
		glow.Shadows = false
		glow.Parent = charge
		charge.Parent = fx
		tween(charge, impactAt, { Size = Vector3.one * 1.2, Transparency = 0.1 })
		tween(glow, impactAt, { Brightness = 6 })
		gather(arm, Vector3.new(0, -1, 0), 2.4, impactAt, ENERGY, 80, function()
			return not alive(model, token)
		end)
		for step = 1, 5 do
			later(model, token, step * 0.09, function()
				local hand = fist(model, "Right Arm")
				if hand then
					crackle(hand, 1.2, 2, ENERGY)
				end
			end)
		end
		later(model, token, impactAt, function()
			tween(charge, 0.15, { Transparency = 1, Size = Vector3.one * 2.5 })
			tween(glow, 0.2, { Brightness = 0 })
		end)
		Debris:AddItem(charge, impactAt + 0.4)
		later(model, token, impactAt - 0.15, function()
			trail(arm, ENERGY, 0.3, 0.9, 0.2, Vector3.new(0, -0.8, 0))
		end)
	end
	local ground = feet(model)
	if ground then
		-- the stance digs in: dust swirling at the feet
		groundRing(ground, 0.5, 4, 0.5, dustColor(floorAt(ground)), { width = 0.5, height = 0.4 })
	end
	later(model, token, impactAt, function()
		local hand = fist(model, "Right Arm")
		if hand == nil then
			return
		end
		local forward = forwardOf(model)
		SoundController.play("Haymaker", model)
		flash(hand + forward * 0.5, ENERGY, 4, 0.3)
		shockSphere(hand + forward, 0.3, 3.5, 0.3, ENERGY)
		-- the air blast: rings along the punch, air lines, sparks
		for index = 0, 3 do
			task.delay(index * 0.035, function()
				local at = hand + forward * (1 + index * 1.8)
				ring(
					axisFrame(at, forward),
					0.4 + index * 0.3,
					2.5 + index * 1.6,
					0.4,
					if index == 0 then WHITE else ENERGY,
					{
						neon = true,
						width = 0.18,
						height = 0.12,
					}
				)
			end)
		end
		streaks(hand + forward, forward, 14, 1.4, 2.5, 50, WHITE, 0.35)
		sparks(hand + forward, 18, ENERGY, forward, 40, 45)
		local spot = feet(model)
		if spot then
			smokePuff(
				spot + forward * 3 + Vector3.new(0, 0.5, 0),
				8,
				1,
				dustColor(floorAt(spot)),
				forward,
				22
			)
		end
		shake(hand, 2, 32, 0.3)
		punch(hand, 18, ENERGY, 0.5)
		KitLooks.gust(hand - forward, 50, 22)
	end)
end

------------------------------------------------------------------------------
-- BULL
------------------------------------------------------------------------------

-- Steam snorted out of the nose.
local function snort(model: Model, strength: number)
	local head = part(model, "Head")
	if head == nil then
		return
	end
	SoundController.play("BullSnort", model)
	for _, side in { -0.1, 0.1 } do
		local at = (head.CFrame * CFrame.new(side, -0.14, -0.62)).Position
		local out = (head.CFrame.LookVector - head.CFrame.UpVector * 0.6).Unit
		emit(at, {
			texture = TEX.smoke,
			color = STEAM,
			size = { 0.2 * strength, 1.2 * strength, 1.8 * strength },
			transparency = { 0.35, 0.6, 1 },
			speed = NumberRange.new(4 * strength, 8 * strength),
			lifetime = NumberRange.new(0.5, 0.9),
			spread = 12,
			direction = out,
			acceleration = Vector3.new(0, 2, 0),
			drag = 3,
			count = math.floor(6 * strength),
		})
	end
end

-- The horn tips leave streaks for `time` seconds.
local function hornTrails(model: Model, time: number)
	for _, tip in KitLooks.hornTips(model) do
		trail(tip, Color3.fromRGB(255, 236, 210), time, 0.35, 0.22)
	end
end

local function goreCharge(model: Model, move: Kits.MoveDef, token: number)
	snort(model, 1.4)
	-- The charge's roar: only as long as the move (the file is longer),
	-- faded out at its end or when it's cut.
	local roar = SoundController.play("BullCharge", model)
	if roar then
		local sound = roar
		local volume = sound.Volume
		local cut = false
		animate(move.duration, function(alpha)
			if cut then
				return
			end
			if not alive(model, token) then
				cut = true
				tween(sound, 0.15, { Volume = 0 })
				task.delay(0.15, function()
					sound:Stop()
				end)
				return
			end
			local left = (1 - alpha) * move.duration
			if left < 0.2 then
				sound.Volume = math.min(sound.Volume, volume * left / 0.2)
			end
		end, function()
			sound:Stop()
			sound:Destroy()
		end)
	end
	local head = part(model, "Head")
	local charge = move.charge
	if head then
		rageEyes(head, if charge then charge.to else 1)
	end
	-- pawing the ground before the rush
	for _, at in { 0.04, 0.14 } do
		later(model, token, at, function()
			local spot = feet(model)
			if spot then
				local floor = floorAt(spot)
				smokePuff(
					spot + Vector3.new(0, 0.3, 0),
					6,
					0.7,
					dustColor(floor),
					-forwardOf(model) + Vector3.yAxis,
					10
				)
				groundRing(spot, 0.5, 3, 0.3, dustColor(floor), { width = 0.4, height = 0.3 })
			end
		end)
	end
	if charge == nil then
		return
	end
	later(model, token, charge.from, function()
		local root = part(model, "HumanoidRootPart")
		if root == nil then
			return
		end
		local floor = floorAt(root.Position - Vector3.new(0, 3, 0))
		-- a cloud of dust kicked up behind, debris from the hooves
		local kick = Instance.new("Attachment")
		kick.CFrame = CFrame.new(0, -2.7, 0.8) * CFrame.Angles(math.rad(150), 0, 0)
		kick.Parent = root
		local back = Instance.new("Attachment")
		back.CFrame = CFrame.new(0, -2.7, 0.8) * CFrame.Angles(math.rad(160), 0, 0)
		back.Parent = root
		stream(back, {
			texture = TEX.smoke,
			color = dustColor(floor),
			size = { 1, 3, 4.5 },
			transparency = { 0.3, 0.6, 1 },
			speed = NumberRange.new(3, 8),
			lifetime = NumberRange.new(0.7, 1.3),
			spread = 35,
			acceleration = Vector3.new(0, 2, 0),
			drag = 2.5,
			count = 0,
		}, 70)
		stream(kick, {
			texture = TEX.sparkle,
			color = Color3.fromRGB(120, 100, 80),
			size = { 0.2, 0.15 },
			transparency = { 0, 1 },
			speed = NumberRange.new(8, 16),
			lifetime = NumberRange.new(0.3, 0.6),
			spread = 30,
			acceleration = Vector3.new(0, -60, 0),
			count = 0,
		}, 40)
		local length = charge.to - charge.from
		Debris:AddItem(kick, length + 0.05)
		Debris:AddItem(back, length + 0.05)
		hornTrails(model, length)
		trail(head or root, Color3.fromRGB(255, 220, 200), length, 1.6, 0.3)
		-- hoofprints cracking the floor, the air pushed ahead
		local steps = math.floor(length / 0.14)
		for step = 0, steps do
			later(model, token, step * 0.14, function()
				local spot = feet(model)
				if spot then
					local side = if step % 2 == 0 then 0.5 else -0.5
					local root2 = part(model, "HumanoidRootPart")
					local offset = if root2 then root2.CFrame.RightVector * side else Vector3.zero
					cracks(spot + offset, 3, 1.2, 4)
					groundRing(
						spot + offset,
						0.3,
						2.2,
						0.25,
						dustColor(floor),
						{ width = 0.3, height = 0.25, segments = 16 }
					)
				end
			end)
		end
		for step = 0, 3 do
			later(model, token, step * (length / 4), function()
				local front = part(model, "Head")
				if front then
					local forward = forwardOf(model)
					ring(axisFrame(front.Position + forward * 1.5, forward), 1, 3.5, 0.3, WHITE, {
						neon = true,
						width = 0.1,
						height = 0.06,
						transparency = 0.5,
					})
					streaks(front.Position + forward * 2, -forward, 4, 1.5, 3, 20, WHITE, 0.3)
				end
			end)
		end
	end)
	-- skidding to a stop
	later(model, token, charge.to, function()
		local spot = feet(model)
		if spot then
			smokePuff(
				spot + Vector3.new(0, 0.4, 0),
				10,
				1,
				dustColor(floorAt(spot)),
				forwardOf(model),
				14
			)
		end
	end)
end

local function hornHook(model: Model, token: number)
	snort(model, 1)
	local ground = feet(model)
	if ground then
		smokePuff(
			ground + Vector3.new(0, 0.3, 0),
			6,
			0.8,
			dustColor(floorAt(ground)),
			Vector3.yAxis,
			8
		)
	end
	later(model, token, 0.16, function()
		hornTrails(model, 0.3)
	end)
	later(model, token, 0.32, function()
		local root = part(model, "HumanoidRootPart")
		if root == nil then
			return
		end
		local forward = forwardOf(model)
		local at = root.Position + forward * 2.5
		-- the upward toss: a vertical air ring, a column of dust, lines going up
		ring(
			axisFrame(at + Vector3.new(0, 0.5, 0), Vector3.yAxis),
			0.8,
			5,
			0.4,
			WHITE,
			{ neon = true, width = 0.16, height = 0.1 }
		)
		ring(
			axisFrame(at + Vector3.new(0, 1.5, 0), (forward + Vector3.yAxis * 2).Unit),
			0.6,
			3.5,
			0.35,
			Color3.fromRGB(255, 236, 210),
			{
				neon = true,
				width = 0.12,
				height = 0.08,
			}
		)
		streaks(at, Vector3.yAxis, 12, 1.2, 3, 40, WHITE, 0.4)
		local spot = feet(model)
		if spot then
			local floor = floorAt(spot)
			smokePuff(
				spot + forward * 2.5 + Vector3.new(0, 0.5, 0),
				14,
				1,
				dustColor(floor),
				Vector3.yAxis,
				24
			)
			groundRing(
				spot + forward * 2.5,
				1,
				7,
				0.45,
				dustColor(floor),
				{ width = 0.8, height = 0.6 }
			)
			rocks(spot + forward * 2.5, 5, 0.7)
		end
		shake(at, 1.6, 30, 0.3)
		KitLooks.gust(at, 40, 20)
	end)
end

local function stampede(model: Model, token: number)
	snort(model, 1.6)
	local head = part(model, "Head")
	if head then
		rageEyes(head, 0.8)
	end
	-- rearing up: pebbles start to float, dust swirls
	later(model, token, 0.15, function()
		local spot = feet(model)
		if spot == nil then
			return
		end
		local floor = floorAt(spot)
		emit(spot + Vector3.new(0, 0.2, 0), {
			texture = TEX.sparkle,
			color = if floor then floor.color else DUST,
			size = { 0.25, 0.2 },
			transparency = { 0, 0.2, 1 },
			speed = NumberRange.new(1, 3),
			lifetime = NumberRange.new(0.35, 0.5),
			spread = 70,
			acceleration = Vector3.new(0, 4, 0),
			count = 20,
		})
		groundRing(
			spot,
			3,
			0.5,
			0.35,
			dustColor(floor),
			{ width = 0.4, height = 0.3, transparency = 0.5 }
		)
	end)
	later(model, token, 0.5, function()
		local spot = feet(model)
		if spot == nil then
			return
		end
		SoundController.play("Stomp", model)
		groundImpact(
			spot + forwardOf(model) * 1,
			{ size = 1.5, flashColor = Color3.fromRGB(255, 200, 150) }
		)
	end)
end

local function bullToss(model: Model, token: number)
	snort(model, 1)
	later(model, token, 0.22, function()
		SoundController.play("BullToss", model)
		local spot = feet(model)
		local forward = forwardOf(model)
		if spot then
			local floor = floorAt(spot)
			smokePuff(
				spot + forward * 2 + Vector3.new(0, 0.4, 0),
				10,
				0.9,
				dustColor(floor),
				Vector3.yAxis,
				10
			)
			groundRing(
				spot + forward * 1.5,
				0.6,
				5,
				0.4,
				dustColor(floor),
				{ width = 0.6, height = 0.5 }
			)
		end
		local hand = fist(model, "Right Arm")
		if hand then
			flash(hand, Color3.fromRGB(255, 230, 200), 1.5, 0.2)
		end
	end)
	later(model, token, 0.5, function()
		hornTrails(model, 0.3)
		local torso = part(model, "Torso")
		if torso then
			trail(torso, Color3.fromRGB(255, 236, 210), 0.3, 1.8, 0.25)
		end
	end)
	later(model, token, 0.7, function()
		local root = part(model, "HumanoidRootPart")
		if root == nil then
			return
		end
		SoundController.play("BullToss", model)
		local at = root.Position + Vector3.new(0, 2.5, 0)
		ring(
			axisFrame(at, Vector3.yAxis),
			1,
			7,
			0.45,
			WHITE,
			{ neon = true, width = 0.18, height = 0.1 }
		)
		streaks(root.Position, Vector3.yAxis, 14, 1.5, 3.5, 45, WHITE, 0.45)
		local spot = feet(model)
		if spot then
			local floor = floorAt(spot)
			dustRing(spot, 2, 0.8, dustColor(floor))
			groundRing(spot, 1, 9, 0.5, dustColor(floor), { width = 1, height = 0.8 })
		end
		shake(at, 1.8, 30, 0.35)
		KitLooks.gust(at, 45, 22)
	end)
end

------------------------------------------------------------------------------

local STARTS: { [string]: (Model, Kits.MoveDef, number) -> () } = {
	Sentinel_HeatVision = heatVision,
	Sentinel_ThunderClap = function(model, _move, token)
		thunderClap(model, token)
	end,
	Sentinel_Skyfall = skyfall,
	Sentinel_Haymaker = function(model, _move, token)
		haymaker(model, token)
	end,
	Bull_GoreCharge = goreCharge,
	Bull_HornHook = function(model, _move, token)
		hornHook(model, token)
	end,
	Bull_Stampede = function(model, _move, token)
		stampede(model, token)
	end,
	Bull_Toss = function(model, _move, token)
		bullToss(model, token)
	end,
}

function KitVFX.onAction(model: Model, animation: string, move: Kits.MoveDef?)
	local start = STARTS[animation]
	if start == nil or move == nil then
		return
	end
	local token = (tokens[model] or 0) + 1
	tokens[model] = token
	start(model, move, token)
end

-- Extra effects where some of these moves land.
function KitVFX.onHit(victim: Model, attacker: Model, moveId: string)
	local torso = part(victim, "Torso")
	if torso == nil then
		return
	end
	local from = part(attacker, "HumanoidRootPart")
	local direction = if from then flat(torso.Position - from.Position) else Vector3.yAxis
	if moveId == "GoreCharge" or moveId == "HornHook" or moveId == "BullToss" then
		flash(torso.Position, Color3.fromRGB(255, 225, 190), 2.2, 0.22)
		smokePuff(torso.Position, 8, 0.8, DUST, direction, 12)
		ring(
			axisFrame(torso.Position, direction),
			0.5,
			4,
			0.3,
			WHITE,
			{ neon = true, width = 0.14, height = 0.08 }
		)
		shake(torso.Position, 1.2, 25, 0.25)
	elseif moveId == "Haymaker" or moveId == "ThunderClap" or moveId == "Skyfall" then
		flash(torso.Position, ENERGY, 2.5, 0.25)
		sparks(torso.Position, 14, ENERGY, direction, 30, 50)
		ring(
			axisFrame(torso.Position, direction),
			0.5,
			4.5,
			0.3,
			ENERGY,
			{ neon = true, width = 0.14, height = 0.08 }
		)
	elseif moveId == "Stampede" then
		smokePuff(torso.Position - Vector3.new(0, 2, 0), 6, 0.8, DUST, Vector3.yAxis, 8)
	end
	-- (heat vision: no hit effect here, the beam chars them where it touches)
end

-- The move was refused / cut short: its pending effects don't play.
function KitVFX.stop(model: Model)
	tokens[model] = (tokens[model] or 0) + 1
end

------------------------------------------------------------------------------
-- Smashed walls (Server Destruction → Remotes.WallBroken)
------------------------------------------------------------------------------

local MAX_CHUNKS = 90 -- debris pieces per smash, at most

type BrokenPiece = { cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material }

-- Every broken piece bursts into chunks of itself (its colour, material),
-- thrown away from `point` and along `push`; dust where it stood.
local function wallDebris(pieces: { BrokenPiece }, point: Vector3, push: Vector3)
	if #pieces == 0 then
		return
	end
	local budget = math.max(1, math.floor(MAX_CHUNKS / #pieces))
	local made = 0
	for index, piece in pieces do
		local size = piece.size
		local nx = math.clamp(math.ceil(size.X / 1.8), 1, 3)
		local ny = math.clamp(math.ceil(size.Y / 1.8), 1, 3)
		local nz = math.clamp(math.ceil(size.Z / 1.8), 1, 3)
		local cell = Vector3.new(size.X / nx, size.Y / ny, size.Z / nz)
		local cells: { Vector3 } = {}
		for ix = 1, nx do
			for iy = 1, ny do
				for iz = 1, nz do
					table.insert(
						cells,
						Vector3.new((ix - 0.5) * cell.X, (iy - 0.5) * cell.Y, (iz - 0.5) * cell.Z)
							- size / 2
					)
				end
			end
		end
		for k = 1, math.min(#cells, budget) do
			if made >= MAX_CHUNKS then
				break
			end
			made += 1
			local offset = cells[random:NextInteger(1, #cells)]
			local chunk = newPart(cell * random:NextNumber(0.6, 0.95), piece.color, piece.material)
			chunk.Anchored = false
			chunk.CanCollide = true
			chunk.CastShadow = true
			chunk.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.6, 0.2)
			chunk.CollisionGroup = DEBRIS_GROUP
			chunk.CFrame = piece.cframe
				* CFrame.new(offset)
				* CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(-0.3, 0.3), 0)
			local away = chunk.Position - point
			away = if away.Magnitude > 0.1 then away.Unit else random:NextUnitVector()
			chunk.AssemblyLinearVelocity = away * random:NextNumber(12, 30)
				+ push * random:NextNumber(0.4, 1)
				+ Vector3.new(0, random:NextNumber(4, 16), 0)
			chunk.AssemblyAngularVelocity = random:NextUnitVector() * random:NextNumber(5, 15)
			chunk.Parent = fx
			local life = random:NextNumber(5, 7)
			task.delay(life - 1, function()
				if chunk.Parent then
					tween(chunk, 1, { Transparency = 1 })
				end
			end)
			Debris:AddItem(chunk, life)
			if k == 1 and index <= 8 then
				smokePuff(piece.cframe.Position, 4, 1.2, DUST:Lerp(piece.color, 0.5), away, 8)
			end
		end
	end
	sparks(
		point,
		10,
		Color3.fromRGB(255, 220, 170),
		if push.Magnitude > 0 then push.Unit else Vector3.yAxis,
		30,
		60
	)
	shake(point, 1.6, 45, 0.3)
end

------------------------------------------------------------------------------
-- The Bull sprinting: the ground shakes under each stride
------------------------------------------------------------------------------

local BULL_STRIDE = 0.3 -- seconds between two hoofs at full sprint
local nextStride: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local strideSide: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local nextSnort: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function bullStrides()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for _, instance in CollectionService:GetTagged(Config.Combat.TAG) do
		if not instance:IsA("Model") or instance:GetAttribute("Kit") ~= "Bull" then
			continue
		end
		local model = instance
		if model:GetAttribute("Ragdolled") == true or model:GetAttribute("KnockedOut") == true then
			continue
		end
		local owner = Players:GetPlayerFromCharacter(model)
		if owner and owner:GetAttribute("MoveState") ~= "Sprint" then
			continue -- (walking, sliding, crouching...)
		end
		local root = part(model, "HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if root == nil or humanoid == nil or humanoid.FloorMaterial == Enum.Material.Air then
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		-- (sprinting: the BullRun clip is on)
		-- (above a sprint: a charge or a knockback, not strides)
		local sprint = Config.Character.SPRINT_SPEED * 1.15
		if speed < 14 or speed > sprint * 1.35 or (root.Position - eye).Magnitude > 120 then
			continue
		end
		if now < (nextStride[model] or 0) then
			continue
		end
		-- (the BullRun clip's own cadence: CharacterAnimationController plays
		-- it at this rate, two hoofs per 0.6 s loop)
		local rate = math.clamp(speed / sprint * 1.35, 0.8, 1.6)
		nextStride[model] = now + BULL_STRIDE / rate
		local side = -(strideSide[model] or 1)
		strideSide[model] = side
		local spot = root.Position - Vector3.new(0, 3, 0) + root.CFrame.RightVector * side * 0.5
		local floor = floorAt(spot)
		if floor == nil then
			continue
		end
		local dust = dustColor(floor)
		emit(floor.position + Vector3.new(0, 0.3, 0), {
			texture = TEX.smoke,
			color = dust,
			size = { 0.6, 1.8, 2.6 },
			transparency = { 0.35, 0.6, 1 },
			speed = NumberRange.new(3, 7),
			lifetime = NumberRange.new(0.6, 1.1),
			spread = 50,
			direction = (-flat(root.CFrame.LookVector) + Vector3.yAxis).Unit,
			acceleration = Vector3.new(0, 2, 0),
			drag = 3,
			count = 4,
		})
		groundRing(
			floor.position,
			0.3,
			2.6,
			0.3,
			dust,
			{ width = 0.35, height = 0.3, segments = 16, transparency = 0.4 }
		)
		cracks(floor.position, 3, 1.3, 3.5)
		if side > 0 then
			rocks(floor.position, 2, 0.45)
		end
		if model ~= Players.LocalPlayer.Character then
			shake(floor.position, 0.5, 18, 0.12)
		end
		if now >= (nextSnort[model] or 0) then
			nextSnort[model] = now + random:NextNumber(1.2, 2)
			snort(model, 0.8)
		end
	end
end

------------------------------------------------------------------------------
-- Finishers (Shared/Finishers "Incinerate" / "Gore"), from CinematicController
------------------------------------------------------------------------------

local finisherTokens: { [Model]: number } = {}

-- Glowing eyes on `head` for `time` seconds, fading in (the charge).
local function chargeEyes(head: BasePart, time: number, fadeIn: number): { BasePart }
	local eyes: { BasePart } = {}
	for _, side in { -1, 1 } do
		local eye = newPart(Vector3.new(0.13, 0.08, 0.04), LASER, Enum.Material.Neon)
		eye.Transparency = 1
		eye.Anchored = false
		eye.Massless = true
		eye.CFrame = head.CFrame * CFrame.new(side * 0.17, 0.11, -0.6)
		local joint = Instance.new("WeldConstraint")
		joint.Part0 = head
		joint.Part1 = eye
		joint.Parent = eye
		eye.Parent = fx
		tween(eye, fadeIn, { Transparency = 0 })
		task.delay(time, function()
			tween(eye, 0.4, { Transparency = 1 })
		end)
		Debris:AddItem(eye, time + 0.5)
		table.insert(eyes, eye)
	end
	return eyes
end

-- The heat vision point blank into the victim's face until `time` runs out:
-- the face chars where it lands, smoke and sparks pour off it.
local function pointBlank(attacker: Model, victim: Model, time: number, token: number)
	local head = part(attacker, "Head")
	local face = part(victim, "Head")
	if head == nil or face == nil then
		return
	end
	local eyes = chargeEyes(head, time, 0.05)
	local loop = SoundController.play("LaserBeam", attacker)
	if loop then
		loop.Looped = true
	end
	local beams: { { part: Part, width: number } } = {}
	for _ = 1, #eyes do
		for _, spec in BEAM_LAYERS do
			local layer =
				newPart(Vector3.new(spec.width, spec.width, 1), spec.color, Enum.Material.Neon)
			layer.Transparency = spec.transparency
			layer.Parent = fx
			table.insert(beams, { part = layer, width = spec.width })
		end
	end
	local hot = Instance.new("Attachment")
	hot.Parent = workspace.Terrain
	local fountain = stream(hot, {
		texture = TEX.sparks,
		color = WHITE,
		color2 = EMBER,
		size = { 0.35, 0.18, 0 },
		transparency = { 0, 0.3, 1 },
		speed = NumberRange.new(6, 18),
		lifetime = NumberRange.new(0.25, 0.5),
		spread = 70,
		acceleration = Vector3.new(0, -60, 0),
		glow = 1,
		count = 0,
	}, 120)
	local smoke = stream(hot, {
		texture = TEX.smoke,
		color = Color3.fromRGB(60, 56, 54),
		size = { 0.5, 1.8, 2.6 },
		transparency = { 0.4, 0.65, 1 },
		speed = NumberRange.new(1.5, 4),
		lifetime = NumberRange.new(0.9, 1.6),
		spread = 30,
		acceleration = Vector3.new(0, 4, 0),
		count = 0,
	}, 30)
	local glow = Instance.new("PointLight")
	glow.Color = EMBER
	glow.Brightness = 6
	glow.Range = 12
	glow.Parent = hot
	local started = os.clock()
	local lastBurn = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if
			now - started > time
			or finisherTokens[attacker] ~= token
			or face.Parent == nil
			or head.Parent == nil
		then
			if connection then
				connection:Disconnect()
			end
			if loop then
				loop:Stop()
			end
			fountain.Rate = 0
			smoke.Rate = 0
			tween(glow, 0.4, { Brightness = 0 })
			for _, beam in beams do
				tween(beam.part, 0.15, { Transparency = 1 })
				Debris:AddItem(beam.part, 0.2)
			end
			for _, eye in eyes do
				tween(eye, 0.15, { Transparency = 1 })
				Debris:AddItem(eye, 0.2)
			end
			Debris:AddItem(hot, 1.8)
			return
		end
		-- (into the face: its front, toward him)
		local target = (face.CFrame * CFrame.new(0, 0.05, -0.55)).Position
		local pulse = 0.85 + math.sin(now * 40) * 0.08 + math.random() * 0.12
		local index = 0
		for _, eye in eyes do
			local from = eye.Position
			local frame = CFrame.lookAt((from + target) / 2, target)
			local length = (target - from).Magnitude
			for _ = 1, #BEAM_LAYERS do
				index += 1
				local beam = beams[index]
				beam.part.CFrame = frame
				beam.part.Size = Vector3.new(beam.width * pulse, beam.width * pulse, length)
			end
		end
		hot.WorldCFrame = facing(target, (head.Position - target))
		if now - lastBurn > 0.09 then
			lastBurn = now
			local spot = face.CFrame
				* CFrame.new(random:NextNumber(-0.35, 0.35), random:NextNumber(-0.3, 0.35), -0.6)
			burn(victim, face, spot.Position, true)
		end
	end)
end

-- The head burnt black (the Sentinel's finisher; the server's
-- "Incinerated"): charred skin with glowing cracks cooling down, the hair
-- burnt off, smoke rising for a while.
local charred: { [Model]: boolean } = {}
local function incinerate(model: Model, live: boolean)
	if charred[model] then
		return
	end
	local head = part(model, "Head")
	if head == nil then
		return
	end
	charred[model] = true
	model.Destroying:Once(function()
		charred[model] = nil
	end)
	local CHARRED = Color3.fromRGB(34, 27, 25)
	-- (the classic head is a mesh: no material texture shows on it; Neon
	-- does: it glows hot, then cools to dull char)
	if live then
		head.Material = Enum.Material.Neon
		head.Color = Color3.fromRGB(200, 70, 20)
		TweenService:Create(head, TweenInfo.new(1.8), { Color = Color3.fromRGB(96, 34, 20) }):Play()
		task.delay(1.8, function()
			if head.Parent then
				head.Material = Enum.Material.SmoothPlastic
				TweenService:Create(head, TweenInfo.new(2), { Color = CHARRED }):Play()
			end
		end)
	else
		head.Material = Enum.Material.SmoothPlastic
		head.Color = CHARRED
	end
	for _, item in head:GetChildren() do
		if item:IsA("Decal") then
			if live then
				TweenService:Create(item, TweenInfo.new(0.6), { Transparency = 0.85 }):Play()
			else
				item.Transparency = 0.85
			end
		end
	end
	-- the hair / hat (what's worn on the head) burns away in a puff
	for _, accessory in model:GetChildren() do
		local handle = if accessory:IsA("Accessory")
			then accessory:FindFirstChild("Handle")
			else nil
		if
			handle
			and handle:IsA("BasePart")
			and (handle.Position - head.Position).Magnitude < 2.2
		then
			if not live then
				handle.Transparency = 1
				continue
			end
			emit(handle.Position, {
				texture = TEX.fire,
				color = EMBER,
				color2 = LASER_DEEP,
				size = { 0.5, 0.2, 0 },
				transparency = { 0.1, 1 },
				speed = NumberRange.new(2, 5),
				lifetime = NumberRange.new(0.3, 0.6),
				spread = 80,
				glow = 1,
				count = 14,
			})
			TweenService:Create(handle, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end
	if not live then
		return -- (a body seen later: already cold)
	end
	for _ = 1, 10 do
		local spot = head.CFrame * CFrame.new(random:NextUnitVector() * 0.6)
		burn(model, head, spot.Position, true)
	end
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.5, 0)
	top.Parent = head
	local smoke = stream(top, {
		texture = TEX.smoke,
		color = Color3.fromRGB(58, 54, 52),
		size = { 0.4, 1.6, 2.8 },
		transparency = { 0.45, 0.7, 1 },
		speed = NumberRange.new(1, 3),
		lifetime = NumberRange.new(1.2, 2.2),
		spread = 25,
		acceleration = Vector3.new(0, 3, 0),
		count = 0,
	}, 16)
	local embers = stream(top, {
		texture = TEX.sparkle,
		color = EMBER,
		size = { 0.12, 0 },
		transparency = { 0, 1 },
		speed = NumberRange.new(1, 3),
		lifetime = NumberRange.new(0.6, 1.2),
		spread = 60,
		acceleration = Vector3.new(0, 2, 0),
		glow = 1,
		count = 0,
	}, 12)
	animate(9, function(alpha)
		smoke.Rate = 16 * (1 - alpha)
		embers.Rate = if alpha < 0.35 then 12 * (1 - alpha / 0.35) else 0
	end, function()
		smoke.Rate = 0
		embers.Rate = 0
	end)
end

-- One moment of a Sentinel / Bull finisher (CinematicController; the
-- blood of the gore is its, through KitEffects).
function KitVFX.finisherEvent(kind: string, attacker: Model, victim: Model)
	local token = finisherTokens[attacker] or 0
	if kind == "Grab" then
		token += 1
		finisherTokens[attacker] = token
		SoundController.play("HeavyHit", victim)
		local neck = part(victim, "Head")
		if neck then
			flash(neck.Position - Vector3.new(0, 0.5, 0), WHITE, 1.2, 0.15)
		end
	elseif kind == "Charge" then
		local head = part(attacker, "Head")
		if head then
			local charge = SoundController.play("LaserCharge", attacker)
			local eyes = chargeEyes(head, 0.6, 0.5)
			gather(head, Vector3.new(0, 0.1, -0.5), 2.4, 0.55, LASER, 80, function()
				if finisherTokens[attacker] == token then
					return false
				end
				-- (cut short: the charge stops)
				if charge then
					charge:Stop()
				end
				for _, eye in eyes do
					eye.Transparency = 1
				end
				return true
			end)
			for step = 1, 4 do
				task.delay(0.25 + step * 0.07, function()
					if finisherTokens[attacker] == token then
						crackle(head.Position + head.CFrame.LookVector * 0.6, 0.8, 1, LASER)
					end
				end)
			end
		end
	elseif kind == "Beam" then
		pointBlank(attacker, victim, 1.35, token)
	elseif kind == "Burnt" then
		local face = part(victim, "Head")
		if face then
			flash(face.Position, EMBER, 2.5, 0.3)
			shockSphere(face.Position, 0.4, 2.5, 0.3, EMBER)
		end
	elseif kind == "Snort" then
		token += 1
		finisherTokens[attacker] = token
		snort(attacker, 2)
		local head = part(attacker, "Head")
		if head then
			local eyes = rageEyes(head, 3.6)
			animate(3.6, function()
				if finisherTokens[attacker] ~= token then
					for _, eye in eyes do
						eye.Transparency = 1
					end
				end
			end)
		end
		local spot = feet(attacker)
		if spot then
			smokePuff(
				spot + Vector3.new(0, 0.3, 0),
				8,
				0.8,
				dustColor(floorAt(spot)),
				-forwardOf(attacker) + Vector3.yAxis,
				10
			)
		end
	elseif kind == "Gore" then
		SoundController.play("FleshTear", victim)
		SoundController.play("HeavyHit", victim)
		hornTrails(attacker, 0.2)
		local torso = part(victim, "Torso")
		if torso then
			local toward = forwardOf(attacker)
			flash(torso.Position, Color3.fromRGB(255, 220, 200), 2, 0.2)
			ring(
				axisFrame(torso.Position, toward),
				0.6,
				4.5,
				0.35,
				WHITE,
				{ neon = true, width = 0.14, height = 0.08 }
			)
		end
		shake(attacker:GetPivot().Position, 2.2, 35, 0.35)
	elseif kind == "Shake" then
		local torso = part(victim, "Torso")
		if torso then
			streaks(torso.Position, Vector3.yAxis, 6, 1, 2.5, 25, WHITE, 0.3)
		end
		snort(attacker, 0.8)
		shake(attacker:GetPivot().Position, 1, 25, 0.2)
	elseif kind == "Slam" then
		SoundController.play("Slam", attacker)
		local torso = part(victim, "Torso")
		local spot = if torso
			then torso.Position
			else (feet(attacker) or attacker:GetPivot().Position)
		groundImpact(spot, { size = 1.5, flashColor = Color3.fromRGB(255, 200, 150) })
	elseif kind == "Stomp" then
		SoundController.play("Stomp", attacker)
		local spot = feet(attacker)
		if spot then
			groundRing(spot, 0.5, 6, 0.45, dustColor(floorAt(spot)), { width = 0.7, height = 0.5 })
			cracks(spot, 4, 2, 6)
		end
		snort(attacker, 1.6)
	end
end

-- The finisher was cut short: its pending effects stop.
function KitVFX.cancelFinisher(attacker: Model)
	finisherTokens[attacker] = (finisherTokens[attacker] or 0) + 1
end

-- Listen to the server's smashes, follow the Bulls' strides.
function KitVFX.start()
	Remotes.WallBroken.OnClientEvent:Connect(
		function(pieces: unknown, point: unknown, push: unknown)
			if
				typeof(pieces) == "table"
				and typeof(point) == "Vector3"
				and typeof(push) == "Vector3"
			then
				wallDebris(pieces :: { BrokenPiece }, point, push)
			end
		end
	)
	RunService.Heartbeat:Connect(bullStrides)
	-- the Sentinel's finisher: heads burnt black (also on bodies seen later)
	local function watchBody(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		if instance:GetAttribute("Incinerated") == true then
			incinerate(instance, false)
		end
		instance:GetAttributeChangedSignal("Incinerated"):Connect(function()
			if instance:GetAttribute("Incinerated") == true then
				incinerate(instance, true)
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal(Config.Combat.TAG):Connect(watchBody)
	for _, model in CollectionService:GetTagged(Config.Combat.TAG) do
		watchBody(model)
	end
end

return table.freeze(KitVFX)
