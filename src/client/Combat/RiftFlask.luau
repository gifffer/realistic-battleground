--!strict
-- RiftFlask: Dr. Rift's flasks (acid / explosive): the one in his hand, the
-- flight (the same arc as the server's), the burst (acid splash or
-- explosion) and the acid puddle. Look only (Server/Combat/Gadgets decides).
--
--   RiftFlask.buildHeld(arm, folder, kind)    in his fist ("Acid"/"Explosive")
--   RiftFlask.thrown(data) / burst(data) / puddle(data)   Remotes.RiftFx
--   RiftFlask.onReleased(callback)            (RiftFx takes the held one away)
--
-- What it should look like, and how it is drawn:
--   • THE FLASK: a round-bottomed glass flask (a neck, a lip, a cork), the
--     liquid filling its bottom (a flattened ball: its top is the liquid's
--     surface), glints on the glass. The explosive one has a lit fuse in its
--     cork (sparks, a little flame). From RiftAssets when it has a "Flask"
--     model, else built here from parts.
--   • IN FLIGHT: it tumbles end over end, the liquid sloshing inside; the
--     acid leaves a thin trail of green vapour (a rare drip), the
--     explosive one a trail of smoke from its fuse.
--   • THE ACID BURST: the glass shatters (thin shards that fly, bounce and
--     lie glinting on the floor a few seconds); the acid splashes out as
--     real drops (they fly in arcs and land as small spots that fizz and
--     eat in, darkening), a thin crown of liquid opens a split second,
--     corrosive fumes rise.
--   • THE PUDDLE: an irregular puddle (a main blot, lobes, runs, splashes
--     around it) that spreads out in half a second, glossy; bubbles grow
--     and pop on it, fumes rise, its edges fizz; then it dries into a dark
--     stain that fades.
--   • THE EXPLOSION: a white flash, a fireball of rolling flames (fire
--     particles over a body of fiery smoke) that rises and darkens into a
--     column of black smoke that lingers; a shockwave (a shimmer of air, a
--     ring of dust thrown along the floor), burning debris trailing smoke,
--     sparks and floating embers, glass, an irregular scorch mark with
--     radial streaks and glowing embers, small flames licking the floor,
--     a light that flickers and dies, the camera shaking near it.
--
-- Everything simulated here (drops, shards, debris) is moved by one
-- Heartbeat step (only while there is something to move), in bulk, with
-- caps; one-off particles come from a few shared emitters moved to where
-- they are needed (an emitter's particles stay where they were emitted).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GoreShapes = require(ReplicatedStorage.Shared.GoreShapes)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local Blood = require(script.Parent.Blood)
local GoreKit = require(script.Parent.GoreKit)
local P = require(script.Parent.RiftParts)
local RiftAssets = require(script.Parent.RiftAssets)

local RiftFlask = {}

local ghost = P.ghost
local stick = P.stick
local attachmentAt = P.attachmentAt
local emitter = P.emitter
local fade = P.fade
local floorUnder = P.floorUnder
local shakeNear = P.shakeNear

-- Colours.
local GLASS = Color3.fromRGB(214, 234, 228) -- clear lab glass, a hair green
local SHARD = Color3.fromRGB(200, 226, 218)
local CORK = Color3.fromRGB(150, 110, 70)
local WICK = Color3.fromRGB(58, 48, 38)
local ACID_WET = Color3.fromRGB(150, 225, 35) -- the liquid: yellow-green
local ACID_LIGHT = Color3.fromRGB(196, 248, 100) -- its bubbles, its shine
local ACID_DEEP = Color3.fromRGB(88, 150, 18) -- thick drops, a burst's crown
local ACID_EDGE = Color3.fromRGB(60, 105, 15) -- a puddle's thin wet edge
local ACID_BURNT = Color3.fromRGB(66, 64, 28) -- what it leaves: a dark stain
local ACID_FUME = Color3.fromRGB(206, 222, 160)
local NITRO = Color3.fromRGB(255, 128, 26) -- the explosive liquid
local FIRE_WHITE = Color3.fromRGB(255, 246, 220)
local FIRE_YELLOW = Color3.fromRGB(255, 196, 90)
local FIRE_ORANGE = Color3.fromRGB(255, 112, 30)
local FIRE_RED = Color3.fromRGB(150, 40, 14)
local SOOT = Color3.fromRGB(24, 21, 19)
local SMOKE_DARK = Color3.fromRGB(36, 33, 31)
local SMOKE_GREY = Color3.fromRGB(70, 67, 64)
local DUST = Color3.fromRGB(132, 118, 98)

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

-- Caps (16 players can throw at once).
local MAX_DROPS = 170 -- acid drops flying at once
local MAX_BITS = 90 -- glass shards and debris flying / lying at once
local MAX_SPOTS = 200 -- acid spots on floors and bodies at once
local MAX_NEW_PER_FRAME = 60 -- new spots a frame, at most
local MAX_FIZZ_PER_FRAME = 10 -- spots that fizz a frame (the rest just land)

local DROP_GRAVITY = 90 -- (a little less than the world's: visible arcs)
local SHARD_GRAVITY = 80
local CHUNK_GRAVITY = 60

local random = Random.new()

local effects = Instance.new("Folder")
effects.Name = "RiftFlask"
effects.Parent = workspace

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { effects }
params.IgnoreWater = true

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

local function numbers(times: { number }, values: { number }): NumberSequence
	local keys = {}
	for index, time in times do
		table.insert(keys, NumberSequenceKeypoint.new(time, values[index]))
	end
	return NumberSequence.new(keys)
end

local function colors(times: { number }, values: { Color3 }): ColorSequence
	local keys = {}
	for index, time in times do
		table.insert(keys, ColorSequenceKeypoint.new(time, values[index]))
	end
	return ColorSequence.new(keys)
end

-- Two directions across `normal` (a flat frame on a surface).
local function across(normal: Vector3): (Vector3, Vector3)
	local side = normal:Cross(if math.abs(normal.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis)
	side = side.Unit
	return side, normal:Cross(side)
end

-- A frame at `at` whose +Y is `up` (an emitter there throws along `up`).
local function facing(at: Vector3, up: Vector3): CFrame
	local side = across(up)
	return CFrame.fromMatrix(at, side, up)
end

local function isBody(instance: Instance): boolean
	local model = instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- A flat ellipse (a flattened sphere mesh) lying on a surface: X along the
-- normal (its thickness), Y across, Z along `along`.
local function ellipse(
	name: string,
	at: Vector3,
	normal: Vector3,
	along: Vector3,
	width: number,
	length: number,
	color: Color3,
	material: Enum.Material
): Part
	local forward = along - normal * along:Dot(normal)
	if forward.Magnitude < 1e-3 then
		forward = across(normal)
	end
	forward = forward.Unit
	local part = ghost(name, Vector3.new(0.01, width, length), color, material)
	part.Archivable = false
	part.Anchored = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.CFrame = CFrame.fromMatrix(at, normal, normal:Cross(forward))
	return part
end

------------------------------------------------------------------------------
-- Shared emitters: one-off particles anywhere
------------------------------------------------------------------------------

local SHARED: { [string]: { [string]: any } } = {
	-- tiny bubbles where an acid drop eats in
	fizz = {
		Color = ColorSequence.new(ACID_LIGHT),
		LightInfluence = 0.6,
		Size = numbers({ 0, 0.6, 1 }, { 0.05, 0.09, 0 }),
		Transparency = numbers({ 0, 1 }, { 0.15, 1 }),
		Lifetime = NumberRange.new(0.25, 0.6),
		Speed = NumberRange.new(0.6, 2.2),
		SpreadAngle = Vector2.new(50, 50),
		Acceleration = Vector3.new(0, 1.5, 0),
		Drag = 3,
	},
	-- a thin wisp of corrosive vapour
	wisp = {
		Color = ColorSequence.new(ACID_FUME),
		Size = numbers({ 0, 1 }, { 0.25, 1.5 }),
		Transparency = numbers({ 0, 0.2, 1 }, { 1, 0.62, 1 }),
		Lifetime = NumberRange.new(0.9, 1.6),
		Speed = NumberRange.new(0.6, 1.6),
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = Vector3.new(0, 2, 0),
		Drag = 1.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	},
	-- a bubble popping: fine droplets
	pop = {
		Color = ColorSequence.new(ACID_WET),
		LightInfluence = 0.7,
		Size = numbers({ 0, 1 }, { 0.06, 0.02 }),
		Transparency = numbers({ 0, 1 }, { 0, 0.8 }),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(2.5, 5),
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, -30, 0),
	},
	-- the burst: streaks of acid flung fast (stretched along their speed)
	spray = {
		Color = ColorSequence.new(ACID_WET, ACID_DEEP),
		LightInfluence = 0.8,
		Size = numbers({ 0, 1 }, { 0.14, 0.04 }),
		Squash = numbers({ 0, 1 }, { 2, 1 }),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Transparency = numbers({ 0, 0.7, 1 }, { 0.05, 0.3, 1 }),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(18, 34),
		SpreadAngle = Vector2.new(75, 75),
		Acceleration = Vector3.new(0, -70, 0),
		Drag = 2.5,
	},
	-- the burst: a puff of fine acid mist
	mist = {
		Color = ColorSequence.new(ACID_LIGHT, ACID_FUME),
		LightInfluence = 0.8,
		Size = numbers({ 0, 1 }, { 0.6, 3.2 }),
		Transparency = numbers({ 0, 0.15, 1 }, { 0.75, 0.45, 1 }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(5, 12),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 6,
		ZOffset = 2,
		Rotation = NumberRange.new(0, 360),
	},
	-- light catching a piece of glass
	glint = {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		LightEmission = 1,
		LightInfluence = 0,
		Size = numbers({ 0, 0.4, 1 }, { 0, 0.3, 0 }),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 90),
	},
	-- the explosion's dust, thrown along the floor
	dust = {
		Color = ColorSequence.new(DUST),
		Size = numbers({ 0, 1 }, { 0.9, 4.2 }),
		Transparency = numbers({ 0, 0.1, 1 }, { 1, 0.45, 1 }),
		Lifetime = NumberRange.new(0.7, 1.3),
		Speed = NumberRange.new(34, 52),
		SpreadAngle = Vector2.new(6, 6),
		ZOffset = 2,
		Acceleration = Vector3.new(0, 3, 0),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	},
	-- flames licking the scorched floor
	floorFire = {
		Texture = FIRE_TEXTURE,
		Color = colors({ 0, 0.4, 1 }, { FIRE_YELLOW, FIRE_ORANGE, FIRE_RED }),
		LightEmission = 1,
		LightInfluence = 0,
		Size = numbers({ 0, 0.35, 1 }, { 0.5, 1.4, 0.2 }),
		Transparency = numbers({ 0, 0.7, 1 }, { 0.15, 0.35, 1 }),
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(2, 4.5),
		SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 6, 0),
		Rotation = NumberRange.new(-20, 20),
	},
}

local shared: { [string]: ParticleEmitter } = {}

local function sharedEmitter(name: string): ParticleEmitter
	local existing = shared[name]
	if existing and existing.Parent then
		return existing
	end
	local point = Instance.new("Attachment")
	point.Name = "RiftFlask_" .. name
	point.Parent = workspace.Terrain
	local made = emitter(point, SHARED[name])
	shared[name] = made
	return made
end

-- `count` particles of the shared emitter `name` at `at` (its +Y: where
-- they go).
local function emitAt(name: string, at: CFrame, count: number)
	local particles = sharedEmitter(name)
	local point = particles.Parent
	if point and point:IsA("Attachment") then
		point.WorldCFrame = at
		particles:Emit(count)
	end
end

------------------------------------------------------------------------------
-- Acid spots (where a drop lands)
------------------------------------------------------------------------------

local spots: { BasePart } = {}
local madeThisFrame = 0
local fizzThisFrame = 0
local layer = 0 -- each spot a hair higher: no flicker where they overlap

local function keepSpot(spot: BasePart, life: number)
	table.insert(spots, spot)
	if #spots > MAX_SPOTS then
		-- (first forget the ones already gone, then fade the oldest left)
		local kept = 0
		for index = 1, #spots do
			local each = spots[index]
			if each.Parent then
				kept += 1
				spots[kept] = each
			end
		end
		for index = #spots, kept + 1, -1 do
			spots[index] = nil
		end
		while #spots > MAX_SPOTS do
			local oldest = table.remove(spots, 1)
			if oldest and oldest.Parent then
				fade(oldest, 0.3)
			end
		end
	end
	-- eating in: from wet bright green to a dull dark stain
	TweenService:Create(spot, TweenInfo.new(3.5, Enum.EasingStyle.Sine), {
		Color = ACID_BURNT,
		Reflectance = 0,
	}):Play()
	task.delay(life * 0.65, function()
		if spot.Parent then
			TweenService:Create(spot, TweenInfo.new(life * 0.35), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(spot, life)
end

-- A spot of acid on `onto` at `position` (a body: on its skin, stuck to it).
local function acidSpot(
	position: Vector3,
	normal: Vector3,
	size: number,
	velocity: Vector3,
	onto: Instance
)
	if madeThisFrame >= MAX_NEW_PER_FRAME then
		return
	end
	local stuck: BasePart? = nil
	if onto:IsA("BasePart") and isBody(onto) then
		local skin, point, out = Blood.onSkin(onto, position)
		if skin == nil then
			return
		end
		stuck, position, normal = skin, point, out
		size = math.min(size, 0.4)
	elseif onto:IsA("BasePart") and not onto.Anchored then
		stuck = onto
	end
	layer = (layer + 1) % 40
	local lift = if stuck then 0.006 else 0.016 + layer * 0.0006
	-- (every part counts in this frame's cap, the little ones too)
	local function piece(at: Vector3, along: Vector3, width: number, length: number)
		if madeThisFrame >= MAX_NEW_PER_FRAME then
			return
		end
		madeThisFrame += 1
		local spot = ellipse(
			"AcidSpot",
			at + normal * lift,
			normal,
			along,
			width,
			length,
			ACID_WET,
			if stuck then Enum.Material.SmoothPlastic else Enum.Material.Glass
		)
		spot.Transparency = if stuck then 0.15 else 0.08
		spot.Reflectance = 0.18
		if stuck then
			spot.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = stuck
			weld.Part1 = spot
			weld.Parent = spot
			spot.Parent = stuck
		else
			spot.Parent = effects
		end
		keepSpot(spot, if stuck then 7 else 11)
	end
	local slide = velocity - normal * velocity:Dot(normal)
	local along = if slide.Magnitude > 1e-3 then slide.Unit else across(normal)
	local stretch = 1 + math.clamp(slide.Magnitude / 25, 0, 1.2)
	piece(position, along, size, size * stretch)
	-- (a bigger one throws a couple of tiny ones ahead of it)
	if size > 0.18 and not stuck then
		for _ = 1, random:NextInteger(1, 3) do
			local side = across(normal)
			local dir = (along * random:NextNumber(0.4, 1.4) + side * random:NextNumber(-0.8, 0.8)).Unit
			local d = size * random:NextNumber(0.12, 0.25)
			piece(position + dir * size * random:NextNumber(0.7, 1.5), dir, d, d * 1.4)
		end
	end
	-- it fizzes as it eats in
	if fizzThisFrame < MAX_FIZZ_PER_FRAME then
		fizzThisFrame += 1
		local up = facing(position + normal * 0.03, normal)
		emitAt("fizz", up, random:NextInteger(2, 4))
		if random:NextNumber() < 0.4 then
			emitAt("wisp", up, 1)
		end
	end
end

------------------------------------------------------------------------------
-- Flying things: acid drops, glass shards, debris
------------------------------------------------------------------------------

type Drop = {
	part: Part,
	mesh: SpecialMesh,
	position: Vector3,
	velocity: Vector3,
	size: number,
	born: number,
}
type Bit = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	rotation: CFrame,
	axis: Vector3,
	spin: number,
	gravity: number,
	born: number,
	bounces: number,
	thin: number, -- its thickness (X): lying flat, X is along the floor's normal
	life: number, -- seconds it lies there before fading
	glass: boolean,
	smoke: ParticleEmitter?,
	fire: ParticleEmitter?,
}

local drops: { Drop } = {}
local bits: { Bit } = {}
local lying = 0 -- bits lying on the floor (they count in MAX_BITS)
local moved: { BasePart } = {}
local frames: { CFrame } = {}
local stepping: RBXScriptConnection? = nil
local step: (dt: number) -> ()

local function startStepping()
	if stepping == nil then
		stepping = RunService.Heartbeat:Connect(function(dt: number)
			step(dt)
		end)
	end
end

local function newDrop(position: Vector3, velocity: Vector3, size: number)
	if #drops >= MAX_DROPS then
		return
	end
	local part = ghost("AcidDrop", Vector3.one * size, ACID_WET, Enum.Material.SmoothPlastic)
	part.Anchored = true
	part.Reflectance = 0.2
	part.Transparency = 0.08
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.CFrame = CFrame.new(position)
	part.Parent = effects
	table.insert(drops, {
		part = part,
		mesh = mesh,
		position = position,
		velocity = velocity,
		size = size,
		born = os.clock(),
	})
	startStepping()
end

local function newBit(
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	gravity: number,
	life: number,
	glass: boolean
): Bit?
	if #bits + lying >= MAX_BITS then
		part:Destroy()
		return nil
	end
	local axis = random:NextUnitVector()
	local bit: Bit = {
		part = part,
		position = position,
		velocity = velocity,
		rotation = CFrame.fromAxisAngle(random:NextUnitVector(), random:NextNumber(0, math.pi)),
		axis = axis,
		spin = random:NextNumber(8, 22),
		gravity = gravity,
		born = os.clock(),
		bounces = 0,
		thin = part.Size.X,
		life = life,
		glass = glass,
	}
	part.Anchored = true
	part.CFrame = CFrame.new(position) * bit.rotation
	part.Parent = effects
	table.insert(bits, bit)
	startStepping()
	return bit
end

-- A bit comes to rest flat on the floor: it lies there, then fades.
local function rest(bit: Bit, at: Vector3, normal: Vector3)
	local side = across(normal)
	local turn = random:NextNumber(0, math.pi * 2)
	side = (CFrame.fromAxisAngle(normal, turn) * side).Unit
	bit.part.CFrame = CFrame.fromMatrix(at + normal * (bit.thin * 0.5 + 0.01), normal, side)
	if bit.glass and random:NextNumber() < 0.5 then
		emitAt("glint", CFrame.new(at + normal * 0.05), 1)
	end
	local smoke, fire = bit.smoke, bit.fire
	if smoke then
		smoke.Rate = 3 -- (smouldering)
	end
	if fire then
		fire.Enabled = false
	end
	lying += 1
	local part = bit.part
	task.delay(bit.life, function()
		lying -= 1
		if smoke then
			smoke.Enabled = false
		end
		if part.Parent then
			fade(part, 0.8)
		end
	end)
end

local function landDrop(drop: Drop, hit: RaycastResult)
	-- (a bigger, faster drop spreads wider)
	local speed = drop.velocity.Magnitude
	local size = drop.size * (1.9 + math.min(speed, 30) * 0.045)
	acidSpot(hit.Position, hit.Normal, size, drop.velocity, hit.Instance)
end

-- Moves every drop and bit; lands the ones that hit something.
step = function(dt: number)
	madeThisFrame = 0
	fizzThisFrame = 0
	table.clear(moved)
	table.clear(frames)
	local now = os.clock()
	local index = 1
	while index <= #drops do
		local drop = drops[index]
		local drag = if drop.size > 0.14 then 0.35 else 1.1 -- (tiny drops slow in the air)
		drop.velocity += (Vector3.new(0, -DROP_GRAVITY, 0) - drop.velocity * drag) * dt
		local travel = drop.velocity * dt
		local hit = if travel.Magnitude > 1e-4
			then workspace:Raycast(drop.position, travel, params)
			else nil
		if hit or now - drop.born > 3 or drop.part.Parent == nil then
			if hit then
				landDrop(drop, hit)
			end
			drop.part:Destroy()
			drops[index] = drops[#drops]
			drops[#drops] = nil
			continue
		end
		drop.position += travel
		-- stretched along its speed (a fast drop is a streak)
		local speed = drop.velocity.Magnitude
		local stretch = 1 + math.min(speed * 0.05, 2.4)
		drop.mesh.Scale = Vector3.new(1 / math.sqrt(stretch), 1 / math.sqrt(stretch), stretch)
		table.insert(moved, drop.part)
		table.insert(
			frames,
			if speed > 0.1
				then CFrame.lookAt(
					drop.position,
					drop.position + drop.velocity,
					if math.abs(drop.velocity.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
				)
				else CFrame.new(drop.position)
		)
		index += 1
	end
	index = 1
	while index <= #bits do
		local bit = bits[index]
		local done = false
		if bit.part.Parent == nil or now - bit.born > 5 then
			if bit.part.Parent then
				fade(bit.part, 0.3)
			end
			done = true
		else
			bit.velocity += Vector3.new(0, -bit.gravity, 0) * dt - bit.velocity * (0.15 * dt)
			bit.rotation = CFrame.fromAxisAngle(bit.axis, bit.spin * dt) * bit.rotation
			local travel = bit.velocity * dt
			local hit = if travel.Magnitude > 1e-4
				then workspace:Raycast(bit.position, travel, params)
				else nil
			if hit then
				local normal = hit.Normal
				local onBody = isBody(hit.Instance)
				local speed = bit.velocity.Magnitude
				if not onBody and normal.Y > 0.55 and (bit.bounces >= 2 or speed < 9) then
					rest(bit, hit.Position, normal)
					done = true
				else
					-- a bounce: it loses most of its speed, spins slower
					local into = bit.velocity:Dot(normal)
					local slide = bit.velocity - normal * into
					bit.velocity = slide * 0.5 - normal * into * 0.3
					bit.position = hit.Position + normal * 0.05
					bit.bounces += 1
					bit.spin *= 0.6
					if bit.glass and random:NextNumber() < 0.3 then
						emitAt("glint", CFrame.new(hit.Position + normal * 0.05), 1)
					end
				end
			else
				bit.position += travel
			end
		end
		if done then
			bits[index] = bits[#bits]
			bits[#bits] = nil
			continue
		end
		table.insert(moved, bit.part)
		table.insert(frames, CFrame.new(bit.position) * bit.rotation)
		index += 1
	end
	if #moved > 0 then
		workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if #drops == 0 and #bits == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

-- Thin shards of glass flung out of `position` (mostly away from `normal`'s
-- other side).
local function shatter(
	position: Vector3,
	normal: Vector3,
	count: number,
	speed: number,
	tint: Color3
)
	for _ = 1, count do
		local shard = Instance.new("WedgePart")
		shard.Name = "Shard"
		local long = random:NextNumber(0.06, 0.24)
		shard.Size = Vector3.new(0.018, long, long * random:NextNumber(0.35, 0.8))
		shard.Color = tint
		shard.Material = Enum.Material.Glass
		shard.Transparency = 0.42
		shard.Reflectance = 0.35
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.Archivable = false
		local dir = random:NextUnitVector()
		if dir:Dot(normal) < 0 then
			dir -= normal * dir:Dot(normal) * 1.6 -- (not into the wall it broke on)
		end
		dir = (dir + normal * 0.4 + Vector3.new(0, 0.35, 0)).Unit
		newBit(
			shard,
			position + normal * 0.15,
			dir * speed * random:NextNumber(0.35, 1),
			SHARD_GRAVITY,
			random:NextNumber(3.5, 6),
			true
		)
	end
end

------------------------------------------------------------------------------
-- The flask itself
------------------------------------------------------------------------------

type Flask = {
	main: BasePart,
	liquidWeld: Weld?,
	liquidBase: CFrame,
	bulb: CFrame, -- the bulb's centre, in the main part's space (the liquid sloshes around it)
	fromBulb: CFrame, -- the main part, in the bulb's space
	tip: Attachment?, -- the fuse's end (explosive)
}

-- How far the cork's top is over the bulb's centre (studs): the flask built
-- here, the RiftAssets one (tools/rift/build_rift_gear.py: bulb radius 0.2,
-- cork top at 0.43, the piece's origin halfway between bottom and top).
local BUILT_CORK_TOP = 0.62
local ASSET_CORK_TOP = 0.43
local ASSET_PIVOT_OVER_BULB = 0.115

local function liquidColor(kind: string): Color3
	return if kind == "Explosive" then NITRO else ACID_WET
end

local function quiet(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
end

local function weldOn(main: BasePart, part: BasePart, offset: CFrame): Weld
	part.CFrame = main.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = main
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = main
	return weld
end

-- The lit fuse at `tip`: sparks spitting out, a tiny flame, a flickering
-- light (all on the attachment: they go with it).
local function litFuse(tip: Attachment)
	local sparks = emitter(tip, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(FIRE_WHITE, FIRE_ORANGE),
		LightEmission = 1,
		LightInfluence = 0,
		Size = numbers({ 0, 1 }, { 0.09, 0 }),
		Lifetime = NumberRange.new(0.15, 0.35),
		Speed = NumberRange.new(3, 7),
		Acceleration = Vector3.new(0, -14, 0),
		Rate = 55,
	})
	sparks.Name = "FuseSparks"
	local flame = emitter(tip, {
		Texture = FIRE_TEXTURE,
		Color = colors({ 0, 0.5, 1 }, { FIRE_WHITE, FIRE_YELLOW, FIRE_ORANGE }),
		LightEmission = 1,
		LightInfluence = 0,
		Size = numbers({ 0, 1 }, { 0.22, 0.04 }),
		Transparency = numbers({ 0, 1 }, { 0.1, 1 }),
		Lifetime = NumberRange.new(0.12, 0.22),
		Speed = NumberRange.new(0.5, 1.2),
		SpreadAngle = Vector2.new(10, 10),
		Rate = 40,
	})
	flame.Name = "FuseFlame"
	local light = Instance.new("PointLight")
	light.Name = "FuseLight"
	light.Color = FIRE_ORANGE
	light.Brightness = 1.4
	light.Range = 5
	light.Parent = tip
end

-- What both flasks get (the built one, the RiftAssets one): the explosive
-- one's fuse out of the cork (`corkTop`: over the bulb's centre), the acid's
-- faint glow, light catching the glass now and then. Returns the fuse's end.
local function dress(
	kind: string,
	main: BasePart,
	bulb: CFrame,
	corkTop: number,
	liquid: BasePart?
): Attachment?
	local tip: Attachment? = nil
	if kind == "Explosive" then
		-- a short fuse out of the cork's middle, leaning (a cylinder lies
		-- along X: turned 70 degrees up; its base at the cork's top)
		local wick = ghost(
			"Wick",
			Vector3.new(0.16, 0.035, 0.035),
			WICK,
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
		weldOn(
			main,
			wick,
			bulb * CFrame.new(0.027, corkTop + 0.065, 0) * CFrame.Angles(0, 0, math.rad(70))
		)
		local point = Instance.new("Attachment")
		point.Name = "FuseTip"
		point.Position = Vector3.new(0.08, 0, 0)
		point.Parent = wick
		tip = point
	else
		-- (a faint glow in the acid, light through it)
		local light = Instance.new("PointLight")
		light.Color = ACID_WET
		light.Brightness = 0.6
		light.Range = 3.5
		light.Parent = liquid or main
	end
	local glints = emitter(main, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		LightEmission = 1,
		LightInfluence = 0,
		Size = numbers({ 0, 0.5, 1 }, { 0, 0.22, 0 }),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(0, 0),
		Rate = 2.5,
		LockedToPart = true,
	})
	glints.Name = "Glints"
	return tip
end

-- A flask built from parts, its bulb's centre at `at` (Y: up the neck).
local function buildFlask(kind: string, at: CFrame): Flask
	local main = ghost("Flask", Vector3.one * 0.54, GLASS, Enum.Material.Glass, Enum.PartType.Ball)
	main.Transparency = 0.6
	main.Reflectance = 0.3
	main.CFrame = at
	-- the liquid: a ball flattened into the bottom (its top is the surface)
	local liquid =
		ghost("Liquid", Vector3.one * 0.5, liquidColor(kind), Enum.Material.SmoothPlastic)
	liquid.Transparency = 0.06
	liquid.Reflectance = 0.15
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.92, 0.6, 0.92)
	mesh.Parent = liquid
	local liquidBase = CFrame.new(0, -0.1, 0)
	local liquidWeld = weldOn(main, liquid, liquidBase)
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder lies along X)
	local neck = ghost(
		"Neck",
		Vector3.new(0.3, 0.13, 0.13),
		GLASS,
		Enum.Material.Glass,
		Enum.PartType.Cylinder
	)
	neck.Transparency = 0.5
	neck.Reflectance = 0.3
	weldOn(main, neck, CFrame.new(0, 0.36, 0) * upright)
	local lip = ghost(
		"Lip",
		Vector3.new(0.05, 0.17, 0.17),
		GLASS,
		Enum.Material.Glass,
		Enum.PartType.Cylinder
	)
	lip.Transparency = 0.4
	lip.Reflectance = 0.3
	weldOn(main, lip, CFrame.new(0, 0.5, 0) * upright)
	local cork = ghost(
		"Cork",
		Vector3.new(0.14, 0.125, 0.125),
		CORK,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	weldOn(main, cork, CFrame.new(0, 0.55, 0) * upright)
	local tip = dress(kind, main, CFrame.identity, BUILT_CORK_TOP, liquid)
	return {
		main = main,
		liquidWeld = liquidWeld,
		liquidBase = liquidBase,
		bulb = CFrame.identity,
		fromBulb = CFrame.identity,
		tip = tip,
	}
end

-- The flask from RiftAssets (its "Flask" model, when the kit is there),
-- else built here; its bulb's centre at `at` either way.
local function makeFlask(kind: string, at: CFrame): Flask
	local paint: RiftAssets.Paint = function(layerName: string): (Color3, Enum.Material, number)
		if layerName == "Liquid" then
			return liquidColor(kind), Enum.Material.SmoothPlastic, 0.15
		elseif layerName == "Cork" then
			return CORK, Enum.Material.Wood, 0
		end
		return GLASS, Enum.Material.Glass, 0.3
	end
	-- (the model's origin is over the bulb's centre)
	local ok, part =
		pcall(RiftAssets.spawn, "Flask", at * CFrame.new(0, ASSET_PIVOT_OVER_BULB, 0), paint)
	if not ok or part == nil then
		return buildFlask(kind, at)
	end
	local main = part :: BasePart
	quiet(main)
	local liquidWeld: Weld? = nil
	local liquidBase = CFrame.identity
	local liquid: BasePart? = nil
	for _, item in main:GetDescendants() do
		if item:IsA("BasePart") then
			quiet(item)
			item.Anchored = false
			if item.Name == "Liquid" then
				liquid = item
			end
		elseif item:IsA("Weld") and item.Part1 and item.Part1.Name == "Liquid" then
			liquidWeld = item
			liquidBase = item.C0
		end
	end
	-- (the main part is its biggest layer, the glass: not centred on the
	-- bulb; where the bulb is, from where it was put)
	local bulb = main.CFrame:ToObjectSpace(at)
	local tip = dress(kind, main, bulb, ASSET_CORK_TOP, liquid)
	return {
		main = main,
		liquidWeld = liquidWeld,
		liquidBase = liquidBase,
		bulb = bulb,
		fromBulb = bulb:Inverse(),
		tip = tip,
	}
end

------------------------------------------------------------------------------
-- In his hand
------------------------------------------------------------------------------

local releasedCallback: ((model: Model) -> ())? = nil

function RiftFlask.onReleased(callback: (model: Model) -> ())
	releasedCallback = callback
end

function RiftFlask.released(model: Model)
	if releasedCallback then
		releasedCallback(model)
	end
end

-- Where the bulb's centre sits, Right Arm space (the arm ends at Y = -1, its
-- front is -Z): just under the fist, cupped in the palm, the neck pointing
-- forward out past the knuckles and a little up (turned -75 degrees around
-- X: the flask's Y goes to (0, 0.26, -0.97)). Everything above the bulb
-- (neck, cork, the lit fuse) is then out in front of the hand, in view.
local HELD_BULB = CFrame.new(0, -1.22, 0.05) * CFrame.Angles(math.rad(-75), 0, 0)

-- A flask in his fist. The explosive one's fuse is already lit.
function RiftFlask.buildHeld(arm: BasePart, folder: Folder, kind: string)
	local flask = makeFlask(kind, arm.CFrame * HELD_BULB)
	-- (the bigger built flask sits a little lower: its bulb just touches
	-- the fist too)
	local bulbAt = if flask.bulb == CFrame.identity
		then HELD_BULB * CFrame.new(0, -0.05, 0)
		else HELD_BULB
	flask.main.Anchored = false
	stick(arm, flask.main, bulbAt * flask.fromBulb, folder)
	-- (the liquid stays level, at the bottom of the tilted bulb: turned back
	-- around the bulb's centre)
	local weld = flask.liquidWeld
	if weld then
		weld.C0 = flask.bulb * CFrame.Angles(math.rad(75), 0, 0) * flask.fromBulb * flask.liquidBase
	end
	if flask.tip then
		litFuse(flask.tip)
	end
end

------------------------------------------------------------------------------
-- In flight
------------------------------------------------------------------------------

type Flight = {
	part: BasePart,
	connection: RBXScriptConnection,
	velocity: Vector3,
	trail: Attachment, -- (its own: the trail stays when the flask is gone)
	trailLife: number,
}
local flying: { [number]: Flight } = {}

local function endFlight(id: number)
	local flight = flying[id]
	if flight == nil then
		return
	end
	flying[id] = nil
	flight.connection:Disconnect()
	flight.part:Destroy()
	-- the trail stops; what it left fades on its own
	for _, item in flight.trail:GetChildren() do
		if item:IsA("ParticleEmitter") then
			item.Enabled = false
		elseif item:IsA("PointLight") then
			item:Destroy()
		end
	end
	Debris:AddItem(flight.trail, flight.trailLife)
end

local function thrown(data: { [string]: any })
	local id, kind, origin, velocity, gravity =
		data.id, data.kind, data.origin, data.velocity, data.gravity
	if
		typeof(id) ~= "number"
		or typeof(kind) ~= "string"
		or typeof(origin) ~= "Vector3"
		or typeof(velocity) ~= "Vector3"
		or typeof(gravity) ~= "number"
	then
		return
	end
	local by = data.by
	if typeof(by) == "Instance" and by:IsA("Model") then
		RiftFlask.released(by) -- (it left the hand)
	end
	endFlight(id)
	local explosive = kind == "Explosive"
	local flask = makeFlask(kind, CFrame.new(origin))
	local part = flask.main
	part.Anchored = true
	part.Parent = effects
	-- The trail, on an attachment of its own that follows the flask (acid:
	-- green vapour; explosive: smoke from the fuse, its sparks and flame).
	local trail = attachmentAt(origin)
	trail.Name = "FlaskTrail"
	local trailLife = 1.3
	if explosive then
		emitter(trail, {
			Color = ColorSequence.new(SMOKE_GREY, SMOKE_DARK),
			Size = numbers({ 0, 1 }, { 0.2, 1.3 }),
			Transparency = numbers({ 0, 0.15, 1 }, { 0.8, 0.5, 1 }),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(0, 0.5),
			Acceleration = Vector3.new(0, 2, 0),
			Drag = 2,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
			Rate = 50,
		})
		litFuse(trail)
	else
		emitter(trail, {
			Color = ColorSequence.new(ACID_LIGHT, ACID_FUME),
			LightEmission = 0.15,
			Size = numbers({ 0, 1 }, { 0.15, 0.9 }),
			Transparency = numbers({ 0, 0.2, 1 }, { 0.85, 0.6, 1 }),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(0, 0.4),
			Acceleration = Vector3.new(0, 1.5, 0),
			Drag = 2,
			Rotation = NumberRange.new(0, 360),
			Rate = 35,
		})
	end
	-- Tumbling end over end (around the axis across its flight), with a
	-- slower wobble.
	local axis = velocity:Cross(Vector3.yAxis)
	axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis
	local wobbleAxis = random:NextUnitVector()
	local spin = random:NextNumber(11, 15)
	local tilt = CFrame.fromAxisAngle(random:NextUnitVector(), random:NextNumber(0, 0.6))
	local started = os.clock()
	local nextDrip = random:NextNumber(0.15, 0.3)
	local drips = 0
	local flight: Flight
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local position = origin + velocity * t - Vector3.new(0, 0.5 * gravity * t * t, 0)
		local moving = velocity - Vector3.new(0, gravity * t, 0)
		flight.velocity = moving
		local cframe = CFrame.new(position)
			* CFrame.fromAxisAngle(axis, -spin * t)
			* CFrame.fromAxisAngle(wobbleAxis, math.sin(t * 5) * 0.3)
			* tilt
		part.CFrame = cframe
		-- the liquid sloshing (it lags the spin, swings and tilts): turned
		-- around the bulb's centre (it stays inside the round glass), a hair
		-- of a shift
		local weld = flask.liquidWeld
		if weld then
			weld.C0 = flask.bulb
				* CFrame.new(math.sin(t * 17) * 0.008, 0, math.cos(t * 19) * 0.008)
				* CFrame.Angles(math.sin(t * 11) * 0.15, 0, math.cos(t * 13) * 0.15)
				* flask.fromBulb
				* flask.liquidBase
		end
		local tip = flask.tip
		if tip then
			trail.WorldPosition = tip.WorldPosition
			local light = trail:FindFirstChild("FuseLight")
			if light and light:IsA("PointLight") then
				light.Brightness = 1.2 + math.noise(t * 9, 0.5) * 1.2
			end
		else
			trail.WorldPosition = cframe * Vector3.new(0, 0.5, 0)
		end
		-- (acid: a rare drip, wet glass round the cork; a few at most)
		if not explosive and t >= nextDrip and drips < 3 then
			drips += 1
			nextDrip = t + random:NextNumber(0.25, 0.5)
			newDrop(
				cframe * (flask.bulb * Vector3.new(0, 0.3, 0)),
				moving * 0.9 + random:NextUnitVector() * 1.5,
				random:NextNumber(0.035, 0.06)
			)
		end
		if t > 4 then
			endFlight(id)
		end
	end)
	flight = {
		part = part,
		connection = connection,
		velocity = velocity,
		trail = trail,
		trailLife = trailLife,
	}
	flying[id] = flight
end

------------------------------------------------------------------------------
-- The acid burst
------------------------------------------------------------------------------

local function acidBurst(position: Vector3, normal: Vector3, incoming: Vector3?, radius: number)
	local scale = radius / 7
	-- 1. the glass shatters
	shatter(position, normal, 22, 22, SHARD)
	-- 2. the acid flies out as drops: along the surface it broke on and
	-- off it (and on with its flight), many small, a few big and slow
	local side, side2 = across(normal)
	local onward = Vector3.zero
	if incoming and incoming.Magnitude > 1e-3 then
		local dir = incoming.Unit
		onward = (dir - normal * dir:Dot(normal) * 2) * 0.5 -- (it bounces on)
	end
	for index = 1, 78 do
		local angle = random:NextNumber(0, math.pi * 2)
		local flat = side * math.cos(angle) + side2 * math.sin(angle)
		local big = index <= 8
		local dir = (
			flat * random:NextNumber(0.5, 1.6)
			+ normal * random:NextNumber(0.25, 1.1)
			+ onward
		).Unit
		local speed = (if big then random:NextNumber(4, 8) else random:NextNumber(6, 17)) * scale
		newDrop(
			position + normal * 0.15,
			dir * speed,
			if big then random:NextNumber(0.2, 0.32) else random:NextNumber(0.05, 0.16)
		)
	end
	-- 3. the crown: thin sheets of liquid opening out a split second
	for index = 1, 10 do
		local angle = (index / 10 + random:NextNumber(-0.03, 0.03)) * math.pi * 2
		local flat = side * math.cos(angle) + side2 * math.sin(angle)
		local out = (flat + normal * 0.8).Unit
		local sheet =
			ghost("AcidSheet", Vector3.new(0.03, 0.2, 0.25), ACID_WET, Enum.Material.SmoothPlastic)
		sheet.Anchored = true
		sheet.Reflectance = 0.25
		sheet.Transparency = 0.15
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = sheet
		-- (X: its thin side faces outward; Z: up along the crown)
		local tangent = normal:Cross(flat).Unit
		sheet.CFrame = CFrame.fromMatrix(position + out * 0.2, flat, tangent)
		sheet.Parent = effects
		local reach = random:NextNumber(0.8, 1.4) * scale
		fade(sheet, random:NextNumber(0.16, 0.24), {
			Size = Vector3.new(0.02, random:NextNumber(0.35, 0.6), reach * 1.2),
			CFrame = CFrame.fromMatrix(position + out * reach, flat, tangent),
		})
	end
	local up = facing(position + normal * 0.1, normal)
	emitAt("spray", up, 45)
	-- (the mist and the fumes start well off the surface: big soft puffs
	-- right on it would cut a hard line into it)
	emitAt("mist", facing(position + normal * 0.6, normal), 12)
	-- 4. corrosive fumes rising (they fade in, swell, drift up)
	local point = attachmentAt(position + normal * 0.9)
	point.WorldCFrame = facing(position + normal * 0.9, normal)
	local fumes = emitter(point, {
		Color = ColorSequence.new(ACID_FUME, Color3.fromRGB(170, 180, 150)),
		Size = numbers({ 0, 1 }, { 1.2, radius * 0.75 }),
		Transparency = numbers({ 0, 0.15, 0.6, 1 }, { 1, 0.5, 0.7, 1 }),
		Lifetime = NumberRange.new(1.8, 3.2),
		Speed = NumberRange.new(1.5, 4.5),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, 2.5, 0),
		Drag = 1.2,
		ZOffset = 2,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
		Rate = 8,
	})
	fumes:Emit(10)
	task.delay(1.4, function()
		fumes.Enabled = false
	end)
	-- 5. a sickly green light, a moment
	local light = Instance.new("PointLight")
	light.Color = ACID_WET
	light.Brightness = 3
	light.Range = radius * 1.6
	light.Parent = point
	TweenService:Create(light, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	Debris:AddItem(point, 5)
	SoundController.playAt("FlaskBreak", position)
	SoundController.playAt("AcidSizzle", position)
end

------------------------------------------------------------------------------
-- The explosion
------------------------------------------------------------------------------

-- A blot from the gore kit (Splat / Pool, an organic outline) lying on a
-- surface, `size` studs across; nil without the kit.
local function kitBlot(kind: { string }, at: Vector3, normal: Vector3, size: number): BasePart?
	local pieces = GoreKit.get()
	if pieces == nil or #kind == 0 then
		return nil
	end
	local piece = pieces[kind[random:NextInteger(1, #kind)]]
	if piece == nil then
		return nil
	end
	local source = piece.layers[1]
	local part = source.source:Clone()
	part:ClearAllChildren()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Archivable = false
	part.Reflectance = 0
	-- (laid flat in X-Z in the kit: its widest side is `size`)
	local widest = math.max(source.size.X, source.size.Z)
	local scaled = source.size * (size / widest)
	part.Size = Vector3.new(scaled.X, math.min(scaled.Y, 0.05), scaled.Z) -- (thin: a film)
	local turn = CFrame.fromAxisAngle(normal, random:NextNumber(0, math.pi * 2))
	local right = (turn * across(normal)).Unit
	part.CFrame = CFrame.fromMatrix(at, right, normal) * source.offset.Rotation
	return part
end

-- The scorch mark: soot (an irregular blot), streaks thrown out from the
-- middle, a faint dark halo, glowing embers in the middle that die.
local function scorch(at: Vector3, normal: Vector3, size: number)
	local holder = Instance.new("Folder")
	holder.Name = "Scorch"
	holder.Parent = effects
	local side, side2 = across(normal)
	local lift = 0.03
	local function lay(part: BasePart)
		lift += 0.002
		part.CFrame += normal * lift
		part.Parent = holder
	end
	local function flatDir(angle: number): Vector3
		return side * math.cos(angle) + side2 * math.sin(angle)
	end
	-- the halo: soot thinning out (a few wide, faint layers: a soft edge)
	for _, ring in { { 2.4, 0.86 }, { 2, 0.8 }, { 1.6, 0.72 } } do
		local wide = size * ring[1]
		local halo = ellipse(
			"Halo",
			at + flatDir(random:NextNumber(0, math.pi * 2)) * size * random:NextNumber(0, 0.1),
			normal,
			flatDir(random:NextNumber(0, math.pi * 2)),
			wide * random:NextNumber(0.9, 1),
			wide,
			SOOT,
			Enum.Material.SmoothPlastic
		)
		halo.Transparency = ring[2]
		lay(halo)
	end
	-- the streaks thrown out from the middle (thin, faint, uneven)
	for _ = 1, 16 do
		local dir = flatDir(random:NextNumber(0, math.pi * 2))
		local length = size * random:NextNumber(0.5, 1)
		local streak = ellipse(
			"Streak",
			at + dir * (size * 0.4 + length * 0.4),
			normal,
			dir,
			size * random:NextNumber(0.04, 0.1),
			length,
			SOOT,
			Enum.Material.SmoothPlastic
		)
		streak.Transparency = random:NextNumber(0.45, 0.7)
		lay(streak)
	end
	-- the soot: black in the middle, an uneven outline
	local blot = kitBlot(GoreShapes.splat, at, normal, size * 1.5)
	if blot then
		blot.Color = SOOT
		blot.Material = Enum.Material.SmoothPlastic
		blot.Transparency = 0.12
		lay(blot)
	else
		local core = ellipse(
			"Soot",
			at,
			normal,
			flatDir(random:NextNumber(0, math.pi * 2)),
			size,
			size * 1.1,
			SOOT,
			Enum.Material.SmoothPlastic
		)
		core.Transparency = 0.12
		lay(core)
		for index = 1, 9 do
			local angle = (index / 9 + random:NextNumber(-0.05, 0.05)) * math.pi * 2
			local d = size * random:NextNumber(0.3, 0.55)
			local lobe = ellipse(
				"Soot",
				at + flatDir(angle) * size * random:NextNumber(0.3, 0.55),
				normal,
				flatDir(random:NextNumber(0, math.pi * 2)),
				d * random:NextNumber(0.6, 1),
				d * random:NextNumber(1, 1.6),
				SOOT,
				Enum.Material.SmoothPlastic
			)
			lobe.Transparency = 0.15
			lay(lobe)
		end
	end
	-- the embers: glowing in the middle, cooling to soot
	for _ = 1, 9 do
		local offset = (side * random:NextNumber(-1, 1) + side2 * random:NextNumber(-1, 1))
			* size
			* 0.3
		local d = size * random:NextNumber(0.04, 0.12)
		local ember = ellipse(
			"Ember",
			at + offset,
			normal,
			random:NextUnitVector(),
			d,
			d * random:NextNumber(1, 1.6),
			FIRE_ORANGE,
			Enum.Material.Neon
		)
		ember.Transparency = 0.15
		lay(ember)
		TweenService:Create(
			ember,
			TweenInfo.new(random:NextNumber(2.5, 4), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Color = FIRE_RED, Transparency = 1 }
		):Play()
	end
	task.delay(14, function()
		for _, part in holder:GetChildren() do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(3), { Transparency = 1 }):Play()
			end
		end
	end)
	Debris:AddItem(holder, 17.2)
end

-- A chunk of floor / debris thrown out, burning or smoking.
local function chunk(from: Vector3, normal: Vector3, color: Color3, burning: boolean)
	local part = ghost(
		"Debris",
		Vector3.new(
			random:NextNumber(0.1, 0.2),
			random:NextNumber(0.15, 0.35),
			random:NextNumber(0.15, 0.4)
		),
		color,
		Enum.Material.Slate
	)
	part.Archivable = false
	local dir = (random:NextUnitVector() + normal * 1.3).Unit
	local bit = newBit(
		part,
		from + normal * 0.3,
		dir * random:NextNumber(18, 36),
		CHUNK_GRAVITY,
		random:NextNumber(2.5, 4),
		false
	)
	if bit == nil then
		return
	end
	bit.smoke = emitter(part, {
		Color = ColorSequence.new(SMOKE_GREY, SMOKE_DARK),
		Size = numbers({ 0, 1 }, { 0.25, 1.4 }),
		Transparency = numbers({ 0, 1 }, { 0.35, 1 }),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(0, 0.3),
		Acceleration = Vector3.new(0, 2, 0),
		Rotation = NumberRange.new(0, 360),
		Rate = 30,
	})
	if burning then
		bit.fire = emitter(part, {
			Texture = FIRE_TEXTURE,
			Color = colors({ 0, 0.5, 1 }, { FIRE_YELLOW, FIRE_ORANGE, FIRE_RED }),
			LightEmission = 1,
			LightInfluence = 0,
			Size = numbers({ 0, 1 }, { 0.45, 0.1 }),
			Transparency = numbers({ 0, 1 }, { 0.1, 1 }),
			Lifetime = NumberRange.new(0.18, 0.32),
			Speed = NumberRange.new(0, 0.5),
			Rate = 30,
		})
	end
end

local function explosion(position: Vector3, normal: Vector3, radius: number)
	-- (the fireball's middle well off the surface, facing out of it: the
	-- fire and sparks fly out in a dome, not half into the floor, where a
	-- big flat particle would cut a hard straight edge)
	local center = attachmentAt(position + normal * math.max(0.6, radius * 0.2))
	center.WorldCFrame = facing(center.WorldPosition, normal)
	-- 1. the flash: a white-hot ball, there and gone
	local flash = ghost(
		"Flash",
		Vector3.one * radius * 0.35,
		FIRE_WHITE,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	flash.Anchored = true
	flash.CFrame = CFrame.new(center.WorldPosition)
	flash.Parent = effects
	fade(flash, 0.13, { Size = Vector3.one * radius * 1.05 })
	-- 2. the fireball: rolling flames over a body of fiery smoke, both
	-- slowing fast and rising (hot air), going from white to orange to a
	-- dark red that turns into smoke
	local fire = emitter(center, {
		Texture = FIRE_TEXTURE,
		Color = colors(
			{ 0, 0.15, 0.45, 0.75, 1 },
			{ FIRE_WHITE, FIRE_YELLOW, FIRE_ORANGE, FIRE_RED, SMOKE_DARK }
		),
		LightEmission = 1,
		LightInfluence = 0,
		Size = numbers({ 0, 0.25, 1 }, { 1.5, radius * 0.55, radius * 0.4 }),
		Transparency = numbers({ 0, 0.6, 1 }, { 0, 0.25, 1 }),
		Lifetime = NumberRange.new(0.5, 0.95),
		Speed = NumberRange.new(radius * 1.8, radius * 3.4),
		SpreadAngle = Vector2.new(75, 75),
		Drag = 7,
		Acceleration = Vector3.new(0, 14, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
		ZOffset = 3,
	})
	fire:Emit(36)
	local billow = emitter(center, {
		Color = colors(
			{ 0, 0.25, 0.55, 1 },
			{ Color3.fromRGB(255, 205, 120), FIRE_ORANGE, Color3.fromRGB(100, 38, 20), SMOKE_DARK }
		),
		-- (little light of its own: lit by the flash, it can turn into dark
		-- soot; much more would add up into a washed-out glow)
		LightEmission = 0.12,
		LightInfluence = 0.5,
		Size = numbers({ 0, 0.4, 1 }, { 2, radius * 0.75, radius * 0.9 }),
		Transparency = numbers({ 0, 0.5, 1 }, { 0.05, 0.3, 1 }),
		Lifetime = NumberRange.new(0.9, 1.5),
		Speed = NumberRange.new(radius * 1.4, radius * 2.6),
		SpreadAngle = Vector2.new(80, 80),
		ZOffset = 2,
		Drag = 6,
		Acceleration = Vector3.new(0, 10, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-50, 50),
	})
	billow:Emit(22)
	-- (a moment later, flames rolling up out of it into the smoke)
	local rising = emitter(center, {
		Texture = FIRE_TEXTURE,
		Color = colors({ 0, 0.4, 0.8, 1 }, { FIRE_YELLOW, FIRE_ORANGE, FIRE_RED, SMOKE_DARK }),
		LightEmission = 1,
		LightInfluence = 0,
		Size = numbers({ 0, 0.3, 1 }, { radius * 0.25, radius * 0.45, radius * 0.2 }),
		Transparency = numbers({ 0, 0.6, 1 }, { 0.1, 0.3, 1 }),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(3, 9),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, 22, 0),
		Drag = 2,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		ZOffset = 3,
	})
	task.delay(0.08, function()
		if rising.Parent then
			rising:Emit(14)
		end
	end)
	-- 3. thick black smoke: out of the fireball, rising in a column and
	-- lingering (it fades in: no smoke popping out of nowhere)
	local smoke = emitter(center, {
		Color = colors({ 0, 0.25, 1 }, { Color3.fromRGB(80, 48, 32), SMOKE_DARK, SMOKE_GREY }),
		Size = numbers({ 0, 1 }, { 3, radius * 1.5 }),
		Transparency = numbers({ 0, 0.1, 0.55, 1 }, { 1, 0.2, 0.45, 1 }),
		Lifetime = NumberRange.new(3.5, 6),
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, 2.5, 0),
		Drag = 0.8,
		ZOffset = 2,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Rate = 0,
	})
	task.delay(0.12, function()
		if smoke.Parent then
			smoke:Emit(12)
			smoke.Rate = 14
		end
	end)
	task.delay(1.4, function()
		smoke.Enabled = false
	end)
	-- 4. sparks (fast streaks falling) and embers (slow, floating up)
	local sparks = emitter(center, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(FIRE_WHITE, FIRE_ORANGE),
		LightEmission = 1,
		LightInfluence = 0,
		Size = numbers({ 0, 1 }, { 0.18, 0 }),
		Squash = numbers({ 0, 1 }, { 1.5, 0.5 }),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Lifetime = NumberRange.new(0.7, 1.6),
		Speed = NumberRange.new(22, 45),
		SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, -35, 0),
		Drag = 1.5,
	})
	sparks:Emit(55)
	local embers = emitter(center, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(FIRE_YELLOW, FIRE_RED),
		LightEmission = 1,
		LightInfluence = 0,
		Size = numbers({ 0, 0.5, 1 }, { 0.1, 0.08, 0 }),
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(3, 9),
		SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, 2.5, 0),
		Drag = 0.6,
	})
	task.delay(0.15, function()
		if embers.Parent then
			embers:Emit(26)
		end
	end)
	-- 5. the shockwave: a shimmer of air swelling fast, a flatter one along
	-- the floor
	local shock = ghost(
		"Shock",
		Vector3.one * 2,
		Color3.fromRGB(255, 225, 180),
		Enum.Material.ForceField,
		Enum.PartType.Ball
	)
	shock.Anchored = true
	shock.CFrame = CFrame.new(center.WorldPosition)
	shock.Parent = effects
	fade(shock, 0.22, { Size = Vector3.one * radius * 2.6 })
	-- 6. glass, and the light: blinding, then the fire's orange, flickering
	-- and dying
	shatter(position, normal, 14, 40, Color3.fromRGB(230, 200, 160))
	local light = Instance.new("PointLight")
	light.Color = FIRE_WHITE
	light.Brightness = 14
	light.Range = math.min(60, radius * 5)
	light.Shadows = true
	light.Parent = center
	-- 7. on the floor: the dust ring, burning debris, the scorch, flames
	local floor = floorUnder(position + normal * 0.5)
	local ground: Vector3? = nil
	local up = Vector3.yAxis
	if floor and (floor.Position - position).Magnitude < radius * 0.7 then
		ground = floor.Position
		up = floor.Normal
		local closeness = 1 - (floor.Position - position).Magnitude / (radius * 0.7)
		local side, side2 = across(up)
		for index = 1, 28 do
			local angle = (index / 28) * math.pi * 2
			local dir = (side * math.cos(angle) + side2 * math.sin(angle) + up * 0.12).Unit
			emitAt("dust", CFrame.fromMatrix(floor.Position + up * 1.2, up:Cross(dir).Unit, dir), 2)
		end
		local flat = ghost(
			"GroundShock",
			Vector3.one * 2,
			Color3.fromRGB(255, 235, 200),
			Enum.Material.ForceField
		)
		flat.Anchored = true
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 0.15, 1)
		mesh.Parent = flat
		flat.CFrame = facing(floor.Position + up * 0.2, up)
		flat.Parent = effects
		fade(flat, 0.35, { Size = Vector3.one * radius * 2.8 })
		local surface = floor.Instance
		local color = if surface:IsA("BasePart") then surface.Color:Lerp(SOOT, 0.45) else SMOKE_GREY
		for index = 1, 9 do
			chunk(floor.Position, up, color, index % 2 == 0)
		end
		if closeness > 0.2 then
			scorch(floor.Position, up, radius * 0.42 * math.max(closeness, 0.5))
		end
	else
		for index = 1, 6 do
			chunk(position, normal, SMOKE_GREY, index % 2 == 0)
		end
	end
	-- the light dying (and flames licking the scorch meanwhile)
	local started = os.clock()
	local seed = random:NextNumber(0, 100)
	local fireClock = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		local t = os.clock() - started
		if t > 2.4 or light.Parent == nil then
			if connection then
				connection:Disconnect()
			end
			light:Destroy()
			return
		end
		local flicker = 0.7 + math.noise(seed, t * 12) * 0.6
		if t < 0.08 then
			light.Brightness = 14
		else
			local k = (t - 0.08) / 2.3
			light.Brightness = 8 * (1 - k) ^ 2 * flicker
			light.Color = FIRE_YELLOW:Lerp(FIRE_ORANGE, math.min(1, t * 2)):Lerp(FIRE_RED, k)
			light.Range = math.min(60, radius * (5 - 2.5 * k))
		end
		if ground and t < 2 then
			fireClock += dt * 26 * (1 - t / 2)
			local side, side2 = across(up)
			while fireClock >= 1 do
				fireClock -= 1
				local spot = ground
					+ (side * random:NextNumber(-1, 1) + side2 * random:NextNumber(-1, 1))
						* radius
						* 0.2
				emitAt("floorFire", facing(spot + up * 0.1, up), 1)
			end
		end
	end)
	Debris:AddItem(center, 8)
	shakeNear(position, 9, 0.7)
	SoundController.playAt("Explosion", position)
	SoundController.playAt("FlaskBreak", position)
end

local function burst(data: { [string]: any })
	local id, kind, position, radius = data.id, data.kind, data.position, data.radius
	if typeof(kind) ~= "string" or typeof(position) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	-- Which way did it come, what did it hit (the surface's normal; a
	-- body or nothing: back the way it came)?
	local incoming: Vector3? = nil
	if typeof(id) == "number" then
		local flight = flying[id]
		if flight then
			incoming = flight.velocity
		end
		endFlight(id)
	end
	local normal = Vector3.yAxis
	if incoming and incoming.Magnitude > 1e-3 then
		local dir = incoming.Unit
		local hit = workspace:Raycast(position - dir * 1.5, dir * 3, params)
		normal = if hit and not isBody(hit.Instance) then hit.Normal else -dir
	else
		local floor = floorUnder(position)
		if floor and (floor.Position - position).Magnitude < 1 then
			normal = floor.Normal
		end
	end
	if kind == "Explosive" then
		explosion(position, normal, radius)
	else
		acidBurst(position, normal, incoming, radius)
	end
end

------------------------------------------------------------------------------
-- The acid puddle
------------------------------------------------------------------------------

-- One ellipse of the puddle's outline (puddle space: x, y on the floor);
-- `shade`: how much deeper its green is (0: the plain wet acid).
type Blob = {
	x: number,
	y: number,
	width: number,
	length: number,
	angle: number,
	shade: number,
}
-- A piece of the puddle growing from the middle to where it belongs.
type Growing = { part: BasePart, final: CFrame, size: Vector3, grow: Vector3, delay: number }
type Bubble = {
	part: Part,
	at: Vector3,
	size: number,
	grow: number,
	t: number,
	wait: number,
	dead: boolean,
}

-- The outline: a few big, flat lobes overlapping (a soft, irregular
-- edge, not a scalloped cloud), the main blot over them, a few runs (it ran
-- along the floor), little splashes around. Then the cores: smaller blots
-- off-centre, each a little deeper green (the liquid is thicker in the
-- middle, thin and bright at its edges). Returns the body (lobes, then the
-- main blot), the runs, the splashes, the cores.
local function outline(radius: number, rng: Random): ({ Blob }, { Blob }, { Blob }, { Blob })
	local body: { Blob } = {}
	local runs: { Blob } = {}
	local splashes: { Blob } = {}
	local cores: { Blob } = {}
	local lobes = 6
	for index = 1, lobes do
		local angle = (index / lobes + rng:NextNumber(-0.08, 0.08)) * math.pi * 2
		local distance = radius * rng:NextNumber(0.3, 0.5)
		table.insert(body, {
			x = math.cos(angle) * distance,
			y = math.sin(angle) * distance,
			width = radius * rng:NextNumber(0.65, 0.95),
			length = radius * rng:NextNumber(0.9, 1.25),
			angle = angle + rng:NextNumber(-0.5, 0.5),
			shade = rng:NextNumber(0, 0.06),
		})
	end
	table.insert(body, {
		x = radius * rng:NextNumber(-0.08, 0.08),
		y = radius * rng:NextNumber(-0.08, 0.08),
		width = radius * rng:NextNumber(1.15, 1.3),
		length = radius * rng:NextNumber(1.3, 1.5),
		angle = rng:NextNumber(0, math.pi),
		shade = 0,
	})
	for _ = 1, 2 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local length = radius * rng:NextNumber(0.4, 0.6)
		local distance = radius * 0.62 + length * 0.3
		table.insert(runs, {
			x = math.cos(angle) * distance,
			y = math.sin(angle) * distance,
			width = radius * rng:NextNumber(0.12, 0.2),
			length = length,
			angle = angle,
			shade = 0,
		})
	end
	for _ = 1, 6 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = radius * rng:NextNumber(0.85, 1.05)
		local d = radius * rng:NextNumber(0.05, 0.11)
		table.insert(splashes, {
			x = math.cos(angle) * distance,
			y = math.sin(angle) * distance,
			width = d,
			length = d * rng:NextNumber(1, 1.6),
			angle = angle,
			shade = 0,
		})
	end
	for index = 1, 3 do
		local k = 1 - index * 0.2
		table.insert(cores, {
			x = radius * rng:NextNumber(-0.12, 0.12),
			y = radius * rng:NextNumber(-0.12, 0.12),
			width = radius * 1.1 * k * rng:NextNumber(0.85, 1.1),
			length = radius * 1.3 * k * rng:NextNumber(0.85, 1.1),
			angle = rng:NextNumber(0, math.pi),
			shade = index * 0.07,
		})
	end
	return body, runs, splashes, cores
end

-- A random point inside `blob` (`edge` near 1: on its edge).
local function pointIn(blob: Blob, edge: number?): (number, number)
	local angle = random:NextNumber(0, math.pi * 2)
	local u = edge or math.sqrt(random:NextNumber()) * 0.75
	local lx = math.cos(angle) * u * blob.length * 0.5
	local ly = math.sin(angle) * u * blob.width * 0.5
	local c, s = math.cos(blob.angle), math.sin(blob.angle)
	return blob.x + lx * c - ly * s, blob.y + lx * s + ly * c
end

local function puddle(data: { [string]: any })
	local position, radius, seconds = data.position, data.radius, data.seconds
	if
		typeof(position) ~= "Vector3"
		or typeof(radius) ~= "number"
		or typeof(seconds) ~= "number"
	then
		return
	end
	local floor = floorUnder(position + Vector3.new(0, 0.2, 0))
	local normal = if floor then floor.Normal else Vector3.yAxis
	local at = if floor then floor.Position else position
	local side, side2 = across(normal)
	local function world(x: number, y: number): Vector3
		return at + side * x + side2 * y
	end
	local holder = Instance.new("Folder")
	holder.Name = "AcidPuddle"
	holder.Parent = effects
	local rng = Random.new(random:NextInteger(1, 1e6))
	local body, runs, splashes, cores = outline(radius, rng)
	local growing: { Growing } = {}
	local tops: { BasePart } = {}
	local rims: { BasePart } = {}
	local lift = 0.04
	-- Three layers, each wider than the one over it: the floor around it
	-- darkened and eaten (the halo), the wet edge (the rim, darker: the
	-- floor shows through the thin liquid), the glossy liquid on top.
	local surface = if floor then floor.Instance else nil
	local floorColor = if surface and surface:IsA("BasePart") then surface.Color else SMOKE_GREY
	local LAYERS = {
		{
			name = "AcidHalo",
			grow = 1.2,
			color = floorColor:Lerp(ACID_BURNT, 0.45),
			transparency = 0.1,
		},
		{
			name = "AcidRim",
			grow = 1.1,
			color = floorColor:Lerp(ACID_EDGE, 0.7),
			transparency = 0.05,
		},
		{ name = "Acid", grow = 1, color = ACID_WET, transparency = 0.08 },
	}
	-- (it waits for the burst's drops to land before it spreads)
	local SPREAD_DELAY = 0.2
	local function lay(blob: Blob, level: number, delay: number)
		lift += 0.0015
		local dir = side * math.cos(blob.angle) + side2 * math.sin(blob.angle)
		local look = LAYERS[level]
		local top = level == 3
		local part = ellipse(
			look.name,
			world(blob.x, blob.y) + normal * lift,
			normal,
			dir,
			blob.width * look.grow,
			blob.length * look.grow,
			if top then look.color:Lerp(ACID_DEEP, blob.shade) else look.color,
			if top then Enum.Material.Glass else Enum.Material.SmoothPlastic
		)
		part.Transparency = look.transparency
		part.Reflectance = if top then 0.22 else 0
		part.Parent = holder
		table.insert(if top then tops else rims, part)
		table.insert(growing, {
			part = part :: BasePart,
			final = part.CFrame,
			size = part.Size,
			grow = Vector3.new(1, 0.12, 0.12),
			delay = delay,
		})
	end
	-- the body: a pool from the kit when there (an organic outline), else
	-- the blots; the runs and splashes either way
	local pool = kitBlot(GoreShapes.pool, at + normal * 0.035, normal, radius * 1.9)
	if pool then
		local made: { BasePart } = {}
		for level = 1, 2 do
			local under = pool:Clone()
			local look = LAYERS[level]
			under.Size = pool.Size * Vector3.new(look.grow, 1, look.grow)
			under.Color = look.color
			under.Material = Enum.Material.SmoothPlastic
			under.Transparency = look.transparency
			under.CFrame += normal * (level * 0.002)
			under.Parent = holder
			table.insert(rims, under)
			table.insert(made, under)
		end
		pool.Color = ACID_WET
		pool.Material = Enum.Material.Glass
		pool.Transparency = 0.08
		pool.Reflectance = 0.22
		pool.CFrame += normal * 0.006
		pool.Parent = holder
		table.insert(tops, pool)
		table.insert(made, pool)
		for _, part in made do
			table.insert(growing, {
				part = part,
				final = part.CFrame,
				size = part.Size,
				grow = Vector3.new(0.12, 1, 0.12),
				delay = 0,
			})
		end
		-- (the runs from the blots, over it)
		for _, blob in runs do
			for level = 1, 3 do
				lay(blob, level, 0.1)
			end
		end
		-- (bubbles in its middle)
		body = {
			{ x = 0, y = 0, width = radius * 1.1, length = radius * 1.1, angle = 0, shade = 0 },
		}
	else
		for level = 1, 3 do
			for _, blob in body do
				lay(blob, level, 0)
			end
			for _, blob in runs do
				lay(blob, level, 0.1)
			end
		end
		for _, blob in cores do
			lay(blob, 3, 0.05)
		end
	end
	for _, blob in splashes do
		lay(blob, 3, rng:NextNumber(0.05, 0.3))
	end
	-- Spreading out from the middle in about half a second.
	for _, piece in growing do
		local part = piece.part
		local offset = piece.final.Position - at
		part.CFrame = piece.final - offset * 0.85
		part.Size = piece.size * piece.grow
		TweenService:Create(
			part,
			TweenInfo.new(
				0.55,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out,
				0,
				false,
				SPREAD_DELAY + piece.delay
			),
			{ CFrame = piece.final, Size = piece.size }
		):Play()
	end
	-- a faint toxic glow over it
	local glowPoint = attachmentAt(at + normal * 0.6)
	glowPoint.Parent = workspace.Terrain
	local glow = Instance.new("PointLight")
	glow.Color = ACID_WET
	glow.Brightness = 0.7
	glow.Range = radius * 1.4
	glow.Parent = glowPoint
	-- Bubbles: they grow on it (half sunk), pop (fine droplets, a wisp),
	-- and others grow somewhere else.
	local bubbles: { Bubble } = {}
	local function place(bubble: Bubble)
		local x, y = pointIn(body[random:NextInteger(1, #body)])
		bubble.at = world(x, y) + normal * lift
		bubble.size = random:NextNumber(0.08, 0.3)
		bubble.grow = random:NextNumber(0.35, 0.9)
		bubble.t = 0
		bubble.wait = random:NextNumber(0, 0.4)
		bubble.part.Size = Vector3.one * 0.01
	end
	for _ = 1, math.clamp(math.floor(radius * 2.4), 6, 14) do
		local part = ghost(
			"Bubble",
			Vector3.one * 0.01,
			ACID_LIGHT,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		part.Anchored = true
		part.Transparency = 0.2
		part.Reflectance = 0.35
		part.CFrame = CFrame.new(at)
		part.Parent = holder
		local bubble: Bubble = {
			part = part,
			at = at,
			size = 0.1,
			grow = 0.5,
			t = 0,
			wait = 0,
			dead = false,
		}
		place(bubble)
		bubble.wait += SPREAD_DELAY + 0.35 -- (once it has spread)
		table.insert(bubbles, bubble)
	end
	local bubbleParts: { BasePart } = {}
	local bubbleFrames: { CFrame } = {}
	local elapsed = 0
	local fumeClock = 0
	local fizzClock = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if holder.Parent == nil or elapsed > seconds + 2.5 then
			if connection then
				connection:Disconnect()
			end
			return
		end
		local alive = elapsed < seconds
		table.clear(bubbleParts)
		table.clear(bubbleFrames)
		for _, bubble in bubbles do
			if bubble.dead then
				continue
			end
			if bubble.wait > 0 then
				bubble.wait -= dt
				continue
			end
			bubble.t += dt
			local k = bubble.t / bubble.grow
			if k >= 1 then
				local up = facing(bubble.at, normal)
				emitAt("pop", up, 3)
				if random:NextNumber() < 0.3 then
					emitAt("wisp", up, 1)
				end
				if alive then
					place(bubble)
				else
					bubble.dead = true
					bubble.part.Transparency = 1
				end
				continue
			end
			local size = bubble.size * k ^ 0.6
			bubble.part.Size = Vector3.one * size
			table.insert(bubbleParts, bubble.part)
			table.insert(bubbleFrames, CFrame.new(bubble.at + normal * (size * 0.15)))
		end
		if #bubbleParts > 0 then
			workspace:BulkMoveTo(bubbleParts, bubbleFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		-- fumes rising off it (fewer as it dries), its edges fizzing
		fumeClock += if elapsed < SPREAD_DELAY then 0 else dt * (if alive then 7 else 2)
		while fumeClock >= 1 do
			fumeClock -= 1
			local x, y = pointIn(body[random:NextInteger(1, #body)])
			emitAt("wisp", facing(world(x, y) + normal * 0.1, normal), 1)
		end
		if alive and elapsed > SPREAD_DELAY + 0.3 then
			fizzClock += dt * 18
			while fizzClock >= 1 do
				fizzClock -= 1
				local x, y = pointIn(body[random:NextInteger(1, #body)], 0.95)
				emitAt("fizz", facing(world(x, y) + normal * 0.05, normal), 2)
			end
		end
	end)
	-- Then it dries into a dark stain that fades.
	task.delay(seconds, function()
		local drying = TweenInfo.new(2.5, Enum.EasingStyle.Sine)
		for _, part in tops do
			if part.Parent then
				TweenService:Create(part, drying, {
					Color = ACID_BURNT,
					Reflectance = 0,
					Transparency = 0.25,
				}):Play()
			end
		end
		for _, part in rims do
			if part.Parent then
				TweenService:Create(part, drying, {
					Color = part.Color:Lerp(SOOT, 0.35),
				}):Play()
			end
		end
		TweenService:Create(glow, drying, { Brightness = 0 }):Play()
	end)
	task.delay(seconds + 7, function()
		for _, part in holder:GetChildren() do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(3), { Transparency = 1 }):Play()
			end
		end
	end)
	Debris:AddItem(holder, seconds + 10.2)
	Debris:AddItem(glowPoint, seconds + 3)
end

RiftFlask.thrown = thrown
RiftFlask.burst = burst
RiftFlask.puddle = puddle

return RiftFlask
