--!strict
-- RiftGlove: Dr. Rift's gravity glove and Awakening, on this client (look
-- only): the glove gathering power, its blast, the gravity slam's
-- shockwave, the blast landing on someone, the Awakening, and the aura he
-- wears while Awakened.
--
--   RiftGlove.charge(model, seconds)    RiftGlove.wave(data)
--   RiftGlove.onHit(victim, attacker, moveId)    RiftGlove.onAwaken(model)
--   RiftGlove.watch(model)    the Awakened aura (while "Awakened" and the
--                             "Rift" kit): motes, arcs, a faint green light
--
-- The rift's energy: a sickly green with white-hot cores, real light, and
-- crackling arcs (chains of thin neon parts, gone in a tenth of a second).
-- Air pushed by gravity: ForceField parts (they shimmer like heat haze).
-- Every effect is built, then thrown away (Debris / Destroy); counts are
-- capped so a crowded fight can't pile parts up.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local P = require(script.Parent.RiftParts)
local RiftGear = require(script.Parent.RiftGear)
local RiftPortal = require(script.Parent.RiftPortal)

local RiftGlove = {}

local KIT = "Rift"

local RIFT_GREEN = P.RIFT_GREEN
local RIFT_DEEP = P.RIFT_DEEP
local RIFT_GLOW = P.RIFT_GLOW
local SMOKE = P.SMOKE
local WHITE_HOT = Color3.fromRGB(236, 255, 226)
local CRACK_DARK = Color3.fromRGB(14, 13, 12)
local ghost = P.ghost
local stick = P.stick
local disc = P.disc
local attachmentAt = P.attachmentAt
local emitter = P.emitter
local sparkTexture = P.sparkTexture
local fade = P.fade
local floorUnder = P.floorUnder
local shakeNear = P.shakeNear

local TAU = math.pi * 2
local rng = Random.new()

-- Caps (16 fighters, clones, everyone slamming at once).
local MAX_ARC_PARTS = 220
local MAX_GROUND_PARTS = 260
-- (CombatHighlight is on every combatant already and Roblox draws ~31
-- Highlights at most: keep our own few)
local MAX_CRUSH_OUTLINES = 4

local arcParts = 0
local groundParts = 0
local crushOutlines = 0

------------------------------------------------------------------------------
-- Little tools
------------------------------------------------------------------------------

local function rand(low: number, high: number): number
	return rng:NextNumber(low, high)
end

local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	-- (no DelayTime here: a delayed tween on a property already tweening
	-- would cancel the running one the moment it is played)
	local made = TweenService:Create(
		instance,
		TweenInfo.new(
			seconds,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		),
		goal
	)
	made:Play()
	return made
end

-- Is `position` close enough to our camera to bother with the small stuff?
local function nearCamera(position: Vector3, range: number): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < range
end

-- Two directions along a surface whose normal is `normal`.
local function along(normal: Vector3): (Vector3, Vector3)
	local first = normal:Cross(
		if math.abs(normal.Y) > 0.9 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	).Unit
	return first, normal:Cross(first).Unit
end

-- A frame on a surface: its Y the surface's normal.
local function surfaceFrame(position: Vector3, normal: Vector3): CFrame
	local first = along(normal)
	return CFrame.fromMatrix(position, first, normal)
end

local function anyTurn(): CFrame
	return CFrame.Angles(rand(0, TAU), rand(0, TAU), rand(0, TAU))
end

-- An anchored ball (Neon light, or ForceField heat haze).
local function ball(
	name: string,
	size: number,
	color: Color3,
	material: Enum.Material,
	transparency: number
): Part
	local part = ghost(name, Vector3.one * size, color, material, Enum.PartType.Ball)
	part.Transparency = transparency
	part.Anchored = true
	return part
end

-- A light at `position` that dies over `seconds`.
local function lightAt(position: Vector3, brightness: number, range: number, seconds: number)
	local point = attachmentAt(position)
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = brightness
	light.Range = math.min(range, 60)
	light.Shadows = false
	light.Parent = point
	tween(light, seconds, { Brightness = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(point, seconds + 0.05)
end

-- The impact frame: a white-hot ball for a couple of frames, then a green
-- one swelling and gone.
local function impactFrame(position: Vector3, size: number)
	local core = ball("RiftImpactCore", size * 0.55, WHITE_HOT, Enum.Material.Neon, 0)
	core.CFrame = CFrame.new(position)
	core.Parent = workspace
	Debris:AddItem(core, 0.06)
	local glow = ball("RiftImpactGlow", size, RIFT_GREEN, Enum.Material.Neon, 0.35)
	glow.CFrame = CFrame.new(position)
	glow.Parent = workspace
	fade(glow, 0.2, { Size = Vector3.one * size * 1.7 })
end

------------------------------------------------------------------------------
-- Arcs (crackling electricity: a jagged chain of thin neon sticks)
------------------------------------------------------------------------------

-- An arc from `a` to `b`, gone after `life`. `thick` 0.03 (a spark on the
-- skin) .. 0.1 (a bolt); thick ones get a green glow around the white core.
local function arc(a: Vector3, b: Vector3, thick: number, life: number?)
	local distance = (b - a).Magnitude
	if distance < 0.1 or arcParts >= MAX_ARC_PARTS then
		return
	end
	local direction = (b - a).Unit
	local side, other = along(direction)
	local count = math.clamp(math.floor(distance / 0.55) + 2, 3, 9)
	local jitter = math.min(distance * 0.2, 0.8)
	local points = { a }
	for index = 1, count - 1 do
		local t = index / count
		local sway = math.sin(t * math.pi) -- (the ends stay on their points)
		table.insert(
			points,
			a
				+ direction * distance * (t + rand(-0.06, 0.06))
				+ (side * rand(-1, 1) + other * rand(-1, 1)) * jitter * sway
		)
	end
	table.insert(points, b)
	local glow = thick >= 0.06
	local folder = Instance.new("Folder")
	folder.Name = "RiftArc"
	local made = 0
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		local length = (to - from).Magnitude
		if length > 0.01 then
			local frame = CFrame.lookAt((from + to) / 2, to)
			local core = ghost(
				"Core",
				Vector3.new(thick, thick, length + thick),
				WHITE_HOT,
				Enum.Material.Neon
			)
			core.Anchored = true
			core.CFrame = frame
			core.Parent = folder
			made += 1
			if glow then
				local halo = ghost(
					"Glow",
					Vector3.new(thick * 3.2, thick * 3.2, length + thick * 2),
					RIFT_GREEN,
					Enum.Material.Neon
				)
				halo.Anchored = true
				halo.Transparency = 0.72
				halo.CFrame = frame
				halo.Parent = folder
				made += 1
			end
		end
	end
	-- A small fork off the middle now and then.
	if count >= 4 and rng:NextNumber() < 0.4 then
		local from = points[math.floor(#points / 2)]
		local to = from
			+ (direction + (side * rand(-1, 1) + other * rand(-1, 1))).Unit
				* distance
				* rand(0.15, 0.3)
		local length = (to - from).Magnitude
		local fork = ghost(
			"Fork",
			Vector3.new(thick * 0.6, thick * 0.6, length),
			WHITE_HOT,
			Enum.Material.Neon
		)
		fork.Anchored = true
		fork.CFrame = CFrame.lookAt((from + to) / 2, to)
		fork.Parent = folder
		made += 1
	end
	arcParts += made
	folder.Parent = workspace
	local seconds = life or rand(0.05, 0.1)
	-- (a flicker: dimmed half way, then gone)
	task.delay(seconds * 0.5, function()
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") and part.Name == "Core" then
				part.Transparency = 0.35
			end
		end
	end)
	task.delay(seconds, function()
		arcParts -= made
		folder:Destroy()
	end)
end

-- A random point on the skin of a body part.
local function onSkin(part: BasePart): Vector3
	local size = part.Size
	local face = rng:NextInteger(1, 3)
	local x, y, z = rand(-0.5, 0.5), rand(-0.5, 0.5), rand(-0.5, 0.5)
	local sign = if rng:NextNumber() < 0.5 then -0.52 else 0.52
	if face == 1 then
		x = sign
	elseif face == 2 then
		z = sign
	else
		y = sign * 0.9
	end
	return part.CFrame * Vector3.new(x * size.X, y * size.Y, z * size.Z)
end

local LIMBS = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function limbsOf(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, name in LIMBS do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	return parts
end

-- An arc crawling over a body, between two of its limbs (or across one).
local function bodyArc(limbs: { BasePart }, thick: number)
	if #limbs == 0 then
		return
	end
	local first = limbs[rng:NextInteger(1, #limbs)]
	local second = limbs[rng:NextInteger(1, #limbs)]
	arc(onSkin(first), onSkin(second), thick)
end

------------------------------------------------------------------------------
-- Shockwaves
------------------------------------------------------------------------------

-- A ring racing out from r0 to r1 round `frame`'s Y axis, after `lag` seconds:
-- `count` sticks round the circle, each growing as the ring does, so its
-- edge stays crisp (a disc would read as a pancake). Neon (energy) or
-- ForceField (shimmering air).
local function ringOut(
	frame: CFrame,
	r0: number,
	r1: number,
	seconds: number,
	count: number,
	color: Color3,
	material: Enum.Material,
	thick: number,
	height: number,
	transparency: number,
	lag: number?
)
	local function build()
		local folder = Instance.new("Folder")
		folder.Name = "RiftRing"
		local info = TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		local spin = rand(0, TAU)
		for index = 1, count do
			local angle = spin + (index - 1) / count * TAU
			local c, s = math.cos(angle), math.sin(angle)
			-- (its Z along the circle, its X pointing out of it)
			local turn = CFrame.Angles(0, math.pi - angle, 0)
			local part =
				ghost("Shock", Vector3.new(thick, height, TAU * r0 / count * 1.15), color, material)
			part.Anchored = true
			part.Transparency = transparency
			part.CFrame = frame * CFrame.new(c * r0, 0, s * r0) * turn
			part.Parent = folder
			TweenService:Create(part, info, {
				CFrame = frame * CFrame.new(c * r1, 0, s * r1) * turn,
				Size = Vector3.new(thick * 0.35, height * 0.4, TAU * r1 / count * 1.15),
				Transparency = 1,
			}):Play()
		end
		folder.Parent = workspace
		Debris:AddItem(folder, seconds + 0.05)
	end
	if lag and lag > 0 then
		task.delay(lag, build)
	else
		build()
	end
end

-- Particles thrown out all round `frame`'s Y axis (dust racing over the
-- floor): one emitter per direction, so the spread is easy to trust.
local function radialBurst(
	frame: CFrame,
	props: { [string]: any },
	amount: number,
	directions: number,
	tilt: number,
	life: number,
	spark: boolean?
)
	local per = math.max(1, math.floor(amount / directions))
	local spin = rand(0, TAU)
	for index = 1, directions do
		local angle = spin + (index - 1) / directions * TAU
		local out = frame:VectorToWorldSpace(
			Vector3.new(math.cos(angle), math.tan(math.rad(tilt)), math.sin(angle))
		)
		local point = attachmentAt(frame.Position)
		point.WorldCFrame = CFrame.lookAt(frame.Position, frame.Position + out)
		local particles = emitter(point, props)
		particles.EmissionDirection = Enum.NormalId.Front
		if spark then
			sparkTexture(particles)
		end
		particles:Emit(per)
		Debris:AddItem(point, life)
	end
end

-- The colour and material of what was hit (a part, or terrain).
local function floorLook(floor: RaycastResult): (Color3, Enum.Material)
	local hit = floor.Instance
	local material = floor.Material
	local color = if hit:IsA("BasePart") then hit.Color else SMOKE
	if hit:IsA("Terrain") then
		local terrain = hit :: Terrain
		local ok, terrainColor = pcall(function()
			return terrain:GetMaterialColor(material)
		end)
		color = if ok then terrainColor else SMOKE
	end
	if material == Enum.Material.Water or material == Enum.Material.Air then
		material = Enum.Material.Slate
	end
	return color, material
end

-- Cracks in the floor radiating from `ground` (dark jagged lines, glowing
-- green inside while fresh), gone after `linger` seconds.
local function cracks(
	ground: Vector3,
	normal: Vector3,
	color: Color3,
	count: number,
	reach: number,
	linger: number
)
	if groundParts >= MAX_GROUND_PARTS then
		return
	end
	local first, second = along(normal)
	local dark = color:Lerp(CRACK_DARK, 0.8)
	local folder = Instance.new("Folder")
	folder.Name = "RiftCracks"
	local made = 0
	local spin = rand(0, TAU)
	for index = 1, count do
		local heading = spin + (index - 1) / count * TAU + rand(-0.25, 0.25)
		local length = reach * rand(0.45, 1)
		local width = rand(0.2, 0.34)
		local at = ground
			+ (first * math.cos(heading) + second * math.sin(heading)) * rand(0.4, 0.9)
		local travelled, step = 0, 0
		while travelled < length and step < 6 and groundParts + made + 2 <= MAX_GROUND_PARTS do
			step += 1
			heading += rand(-0.45, 0.45)
			local stride = rand(0.7, 1.6)
			local way = first * math.cos(heading) + second * math.sin(heading)
			local nextAt = at + way * stride
			local middle = (at + nextAt) / 2 + normal * 0.035
			local wide = width * (1 - travelled / length * 0.7)
			local frame = CFrame.lookAt(middle, middle + way, normal)
			local crack = ghost(
				"Crack",
				Vector3.new(wide, 0.06, stride + wide * 0.6),
				dark,
				Enum.Material.SmoothPlastic
			)
			crack.Anchored = true
			crack.CFrame = frame
			crack.Parent = folder
			made += 1
			-- (fresh: the energy still glowing in the seam)
			if step <= 3 then
				local seam = ghost(
					"Seam",
					Vector3.new(wide * 0.4, 0.07, stride),
					RIFT_GLOW,
					Enum.Material.Neon
				)
				seam.Anchored = true
				seam.CFrame = frame * CFrame.new(0, 0.006, 0)
				seam.Parent = folder
				made += 1
				tween(
					seam,
					rand(0.9, 1.7),
					{ Transparency = 1, Color = RIFT_DEEP },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
			end
			at = nextAt
			travelled += stride
		end
	end
	groundParts += made
	folder.Parent = workspace
	task.delay(linger, function()
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") then
				tween(part, 1.2, { Transparency = 1 })
			end
		end
	end)
	task.delay(linger + 1.25, function()
		groundParts -= made
		folder:Destroy()
	end)
end

-- Chunks of the floor torn up, thrown out and falling back.
local function chunks(
	ground: Vector3,
	normal: Vector3,
	color: Color3,
	material: Enum.Material,
	count: number,
	reach: number
)
	if groundParts >= MAX_GROUND_PARTS then
		return
	end
	local first, second = along(normal)
	groundParts += count
	for _ = 1, count do
		local heading = rand(0, TAU)
		local way = first * math.cos(heading) + second * math.sin(heading)
		local size = rand(0.25, 0.8)
		local rock = ghost(
			"Chunk",
			Vector3.new(size * rand(0.8, 1.4), size * rand(0.45, 0.85), size * rand(0.8, 1.3)),
			color:Lerp(CRACK_DARK, rand(0, 0.3)),
			material
		)
		rock.Anchored = true
		local from = ground + way * rand(0.8, math.max(1, reach * 0.45)) + normal * size * 0.2
		local throw = way * rand(1, 3.5)
		local apex = from + throw * 0.5 + normal * rand(1.5, 4.5)
		local land = from + throw + normal * size * 0.22
		rock.CFrame = CFrame.new(from) * anyTurn()
		rock.Parent = workspace
		local up = rand(0.22, 0.38)
		tween(
			rock,
			up,
			{ CFrame = CFrame.new(apex) * anyTurn() },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
		task.delay(up, function()
			if rock.Parent then
				tween(
					rock,
					up * 0.9,
					{ CFrame = CFrame.new(land) * anyTurn() },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
			end
		end)
		local rest = up * 1.9 + rand(1.6, 2.8)
		task.delay(rest, function()
			if rock.Parent then
				tween(rock, 0.8, { Transparency = 1, Size = rock.Size * 0.6 })
			end
		end)
		task.delay(rest + 0.85, function()
			groundParts -= 1
			rock:Destroy()
		end)
	end
end

-- Dust thrown out over the floor, and the haze it leaves.
local function dustOut(frame: CFrame, color: Color3, radius: number, amount: number)
	local dust = color:Lerp(SMOKE, 0.45)
	radialBurst(frame, {
		Color = ColorSequence.new(dust, dust:Lerp(Color3.new(1, 1, 1), 0.15)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(1, 3.6),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.08, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.7, 1.5),
		Speed = NumberRange.new(radius * 2.2, radius * 3.4),
		SpreadAngle = Vector2.new(22, 22),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		Acceleration = Vector3.new(0, 1.5, 0),
	}, amount, 8, 6, 2)
	-- The haze settling where it was.
	local point = attachmentAt(frame.Position + frame.UpVector * 0.6)
	local haze = emitter(point, {
		Color = ColorSequence.new(dust),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2.5),
			NumberSequenceKeypoint.new(1, radius * 0.9 + 3),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(2.2, 3.4),
		Speed = NumberRange.new(1, radius * 0.6),
		Drag = 1.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-12, 12),
	})
	haze:Emit(8)
	-- Grit flung up, falling back.
	local grit = emitter(point, {
		Color = ColorSequence.new(color:Lerp(CRACK_DARK, 0.4)),
		Size = NumberSequence.new(0.14, 0.08),
		Transparency = NumberSequence.new(0, 0.2),
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(14, 24),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -70, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
	})
	grit:Emit(math.floor(amount * 0.5))
	Debris:AddItem(point, 3.6)
end

------------------------------------------------------------------------------
-- The glove gathering power, and letting it go
------------------------------------------------------------------------------

type Charge = { folder: Folder, alive: boolean }
local charges: { [Model]: Charge } = setmetatable({}, { __mode = "k" }) :: any

-- The palm thrust out (Rift_Glove): air punched forward in rings, a cone of
-- sparks, a flash, dust off the floor.
local function blast(model: Model, palm: BasePart)
	local position = palm.Position
	local forward = -palm.CFrame.RightVector -- (out of the palm)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local look = root.CFrame.LookVector
		if forward:Dot(look) < 0.3 then
			forward = look
		end
	end
	local start = position + forward * 0.5
	impactFrame(start, 1.6)
	lightAt(start, 7, 20, 0.35)
	-- Rings of punched air (ForceField: shimmering, like heat haze), and a
	-- crisp ring of energy.
	for index = 0, 2 do
		local part = disc("GloveAir", RIFT_GLOW, 0.15 + index * 0.15)
		part.Material = Enum.Material.ForceField
		part.Size = Vector3.new(0.8, 0.8, 0.3)
		part.CFrame = CFrame.lookAt(start + forward * index * 0.5, start + forward * (index + 1))
		part.Transparency = 1
		part.Parent = workspace
		local lag = index * 0.035
		local reach = 2.6 + index * 2.2 + rand(-0.3, 0.3)
		local width = 3.4 + index * 1.6 + rand(-0.3, 0.3)
		task.delay(lag, function()
			part.Transparency = 0.1 + index * 0.15
			tween(part, 0.22 + index * 0.06, {
				CFrame = CFrame.lookAt(start + forward * reach, start + forward * (reach + 1)),
				Size = Vector3.new(width, width, 0.3),
				Transparency = 1,
			}, Enum.EasingStyle.Quart)
		end)
		Debris:AddItem(part, lag + 0.4)
	end
	local first = along(forward)
	ringOut(
		CFrame.fromMatrix(start + forward * 0.6, first, forward),
		0.35,
		2.6,
		0.22,
		12,
		RIFT_GLOW,
		Enum.Material.Neon,
		0.16,
		0.08,
		0.1
	)
	-- The cone of sparks and air.
	local point = attachmentAt(start)
	point.WorldCFrame = CFrame.lookAt(start, start + forward)
	local sparks = emitter(point, {
		Color = ColorSequence.new(WHITE_HOT, RIFT_GREEN),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new(0.2, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.15, 0.35),
		Speed = NumberRange.new(35, 60),
		SpreadAngle = Vector2.new(16, 16),
		Drag = 5,
		EmissionDirection = Enum.NormalId.Front,
	})
	sparkTexture(sparks)
	sparks:Emit(rng:NextInteger(22, 30))
	local air = emitter(point, {
		Color = ColorSequence.new(SMOKE:Lerp(Color3.new(1, 1, 1), 0.35)),
		Size = NumberSequence.new(0.8, 3.5),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(16, 28),
		SpreadAngle = Vector2.new(12, 12),
		Drag = 6,
		Rotation = NumberRange.new(0, 360),
		EmissionDirection = Enum.NormalId.Front,
	})
	air:Emit(7)
	Debris:AddItem(point, 0.8)
	-- Dust kicked off the floor under the blast.
	local floor = floorUnder(start + forward * 2)
	if floor and (start - floor.Position).Magnitude < 5 then
		local color = floorLook(floor)
		local dust = color:Lerp(SMOKE, 0.45)
		local below = attachmentAt(floor.Position + floor.Normal * 0.3)
		local flat = (forward - floor.Normal * forward:Dot(floor.Normal))
		local way = if flat.Magnitude > 0.1 then flat.Unit else forward
		below.WorldCFrame =
			CFrame.lookAt(below.WorldPosition, below.WorldPosition + way + floor.Normal * 0.2)
		local kicked = emitter(below, {
			Color = ColorSequence.new(dust),
			Size = NumberSequence.new(0.8, 2.8),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.1, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(10, 20),
			SpreadAngle = Vector2.new(30, 30),
			Drag = 4,
			Rotation = NumberRange.new(0, 360),
			EmissionDirection = Enum.NormalId.Front,
		})
		kicked:Emit(12)
		Debris:AddItem(below, 1.2)
	end
	shakeNear(start, 2.5, 0.22)
end

-- A longer charge let go (the Awakening, the finisher's lift, the slam's
-- downswing: their own effects do the rest): a pulse at the palm.
local function pulse(palm: BasePart)
	local position = palm.CFrame * Vector3.new(-0.3, 0, 0)
	impactFrame(position, 1)
	RiftPortal.flash(position, 0.6)
end

-- The glove gathering power (the glove moves, the awakening, the
-- finisher's lift): energy spiralling into the palm, arcs between the palm
-- and the arm, a growing light; it collapses a hair before the end
-- (anticipation), then the release.
function RiftGlove.charge(model: Model, seconds: number)
	local palm = RiftGear.palmOf(model)
	if palm == nil then
		return
	end
	local old = charges[model]
	if old then
		old.alive = false
		old.folder:Destroy()
	end
	seconds = math.max(seconds, 0.12)
	local arm = model:FindFirstChild("Left Arm")
	local armPart: BasePart? = if arm and arm:IsA("BasePart") then arm else nil
	local u = if armPart then armPart.Size.Y / 2 else 1

	local folder = Instance.new("Folder")
	folder.Name = "RiftGloveCharge"
	local state: Charge = { folder = folder, alive = true }
	charges[model] = state

	-- A sphere in front of the palm (invisible) that spins: the motes on its
	-- surface fall inward while locked to it, so they spiral into the palm.
	local front = CFrame.new(-0.35 * u, 0, 0) -- (the palm's -X: out of it)
	local gather = ghost("Gather", Vector3.one * 2.8 * u, RIFT_GLOW, Enum.Material.SmoothPlastic)
	gather.Transparency = 1
	gather.CFrame = palm.CFrame * front
	local weld = Instance.new("Weld")
	weld.Part0 = palm
	weld.Part1 = gather
	weld.C0 = front
	weld.Parent = gather
	gather.Parent = folder
	local motes = emitter(gather, {
		Name = "GloveCharge",
		Color = ColorSequence.new(RIFT_GREEN, WHITE_HOT),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.04 * u),
			NumberSequenceKeypoint.new(0.4, 0.16 * u),
			NumberSequenceKeypoint.new(1, 0.02 * u),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.1),
			NumberSequenceKeypoint.new(1, 0.3),
		}),
		Lifetime = NumberRange.new(0.27, 0.3),
		Speed = NumberRange.new(4.3 * u, 4.8 * u),
		LockedToPart = true,
		Rate = 0,
		ZOffset = 0.3,
	})
	sparkTexture(motes)
	motes.Shape = Enum.ParticleEmitterShape.Sphere
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	motes:Emit(16)
	motes.Rate = 70

	-- Streaks of energy drawn into the palm (beams curving in).
	local palmPoint = Instance.new("Attachment")
	palmPoint.Position = Vector3.new(0.3 * u, 0, 0) -- (the palm's face, in the sphere's space)
	palmPoint.Parent = gather
	local streaks: { { point: Attachment, beam: Beam } } = {}
	for _ = 1, if seconds > 0.6 then 4 else 3 do
		local point = Instance.new("Attachment")
		point.Position = rng:NextUnitVector() * 1.3 * u
		point.Parent = gather
		local beam = Instance.new("Beam")
		beam.Attachment0 = point
		beam.Attachment1 = palmPoint
		beam.Color = ColorSequence.new(RIFT_GREEN, WHITE_HOT)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 0.05),
		})
		beam.Width0 = 0.03
		beam.Width1 = 0.14 * u
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 14
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureSpeed = 4
		beam.TextureLength = 1.2
		beam.CurveSize0 = rand(-1.2, 1.2) * u
		beam.CurveSize1 = rand(-0.6, 0.6) * u
		beam.Parent = gather
		table.insert(streaks, { point = point, beam = beam })
	end

	-- The glow at the palm: a white-hot core in green, a shimmer of bent air
	-- round it, its light; growing, then sucked in just before the release.
	local nearPalm = CFrame.new(-0.12 * u, 0, 0)
	local glow =
		ghost("Glow", Vector3.one * 0.2 * u, RIFT_GREEN, Enum.Material.Neon, Enum.PartType.Ball)
	glow.Transparency = 0.55
	stick(palm, glow, nearPalm, folder)
	local core =
		ghost("Core", Vector3.one * 0.08 * u, WHITE_HOT, Enum.Material.Neon, Enum.PartType.Ball)
	stick(palm, core, nearPalm, folder)
	local haze = ghost(
		"Haze",
		Vector3.one * 0.6 * u,
		RIFT_GLOW,
		Enum.Material.ForceField,
		Enum.PartType.Ball
	)
	haze.Transparency = 0.35
	stick(palm, haze, nearPalm, folder)
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 0.5
	light.Range = 6
	light.Shadows = false
	light.Parent = glow
	folder.Parent = workspace

	local grow = seconds - 0.08
	tween(
		glow,
		grow,
		{ Size = Vector3.one * 0.8 * u, Transparency = 0.25 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	tween(
		core,
		grow,
		{ Size = Vector3.one * 0.38 * u },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	tween(
		haze,
		grow,
		{ Size = Vector3.one * 2.2 * u },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	tween(light, grow, { Range = 13 })
	-- (the anticipation: everything pulled in to a point, once the grow
	-- is done - started later so it does not cancel the grow tweens)
	task.delay(grow, function()
		if not state.alive then
			return
		end
		tween(
			glow,
			0.08,
			{ Size = Vector3.one * 0.25 * u },
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		)
		tween(
			core,
			0.08,
			{ Size = Vector3.one * 0.15 * u },
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		)
		tween(
			haze,
			0.08,
			{ Size = Vector3.one * 0.4 * u },
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		)
	end)

	local connection: RBXScriptConnection? = nil
	local function finish()
		state.alive = false
		if charges[model] == state then
			charges[model] = nil
		end
		if connection then
			connection:Disconnect()
			connection = nil
		end
		folder:Destroy()
	end

	local elapsed, spin = 0, rand(0, TAU)
	local nextArc, nextStreak = rand(0.04, 0.1), 0.12
	local close = nearCamera(palm.Position, 140)
	connection = RunService.RenderStepped:Connect(function(dt: number)
		if not state.alive or palm.Parent == nil or folder.Parent == nil then
			finish()
			return
		end
		elapsed += dt
		local k = math.min(elapsed / seconds, 1)
		spin += dt * (5 + 12 * k)
		weld.C0 = front * CFrame.Angles(spin, 0, 0)
		light.Brightness = (0.6 + 3.4 * k) * rand(0.75, 1.15)
		nextStreak -= dt
		if nextStreak <= 0 then
			nextStreak = rand(0.09, 0.15)
			local streak = streaks[rng:NextInteger(1, #streaks)]
			streak.point.Position = rng:NextUnitVector() * 1.3 * u
			streak.beam.CurveSize0 = rand(-1.2, 1.2) * u
			streak.beam.CurveSize1 = rand(-0.6, 0.6) * u
		end
		nextArc -= dt
		if nextArc <= 0 and close then
			nextArc = (0.15 - 0.1 * k) * rand(0.7, 1.3)
			local from = palm.CFrame
				* Vector3.new(-0.05, rand(-0.25, 0.25) * u, rand(-0.25, 0.25) * u)
			if armPart and rng:NextNumber() < 0.6 then
				-- (palm to arm)
				local size = armPart.Size
				local sign = if rng:NextNumber() < 0.5 then -0.53 else 0.53
				local to = armPart.CFrame
					* Vector3.new(
						rand(-0.5, 0.5) * size.X,
						rand(-0.45, 0.3) * size.Y,
						sign * size.Z
					)
				arc(from, to, 0.05 + 0.03 * k)
			else
				-- (into the air round it)
				arc(from, from + rng:NextUnitVector() * rand(0.8, 1.7) * u, 0.04 + 0.03 * k)
			end
		end
	end)

	task.delay(seconds, function()
		if not state.alive then
			return
		end
		finish()
		if palm.Parent == nil or model.Parent == nil then
			return
		end
		if seconds <= 0.45 then
			blast(model, palm)
		else
			pulse(palm)
		end
	end)
end

------------------------------------------------------------------------------
-- Shockwave (gravity slam)
------------------------------------------------------------------------------

function RiftGlove.wave(data: { [string]: any })
	local position, radius = data.position, data.radius
	if typeof(position) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	radius = math.clamp(radius, 2, 40)
	local floor = floorUnder(position + Vector3.new(0, 1, 0))
	local ground = if floor then floor.Position else position
	local normal = if floor then floor.Normal else Vector3.new(0, 1, 0)
	local frame = surfaceFrame(ground + normal * 0.12, normal)
	local color: Color3, material: Enum.Material = SMOKE, Enum.Material.Slate
	if floor then
		color, material = floorLook(floor)
	end
	local close = nearCamera(ground, 220)

	-- The impact frame, the light.
	impactFrame(ground + normal * 0.6, 3)
	lightAt(ground + normal * 1.5, 9, radius * 3, 0.7)
	-- The dome of green energy, and the bent air round it.
	local dome = ball("SlamDome", 1.5, RIFT_GREEN, Enum.Material.Neon, 0.45)
	dome.CFrame = CFrame.new(ground)
	dome.Parent = workspace
	fade(dome, 0.32, { Size = Vector3.one * radius * 1.2 })
	local air = ball("SlamAir", 2, RIFT_GLOW, Enum.Material.ForceField, 0)
	air.CFrame = CFrame.new(ground)
	air.Parent = workspace
	fade(air, 0.5, { Size = Vector3.one * radius * 2.1 })
	-- The double shockwave: a ring of energy, then the air behind it.
	ringOut(frame, 0.8, radius, 0.38, 20, RIFT_GLOW, Enum.Material.Neon, 0.3, 0.12, 0.05)
	ringOut(
		frame,
		0.8,
		radius * 1.15,
		0.55,
		16,
		RIFT_GLOW,
		Enum.Material.ForceField,
		1.4,
		0.9,
		0,
		0.1
	)
	local flat = disc("SlamFlat", RIFT_GREEN, 0.55)
	flat.CFrame = frame * CFrame.Angles(math.rad(90), 0, 0)
	flat.Size = Vector3.new(1, 1, 0.06)
	flat.Parent = workspace
	fade(flat, 0.45, { Size = Vector3.new(radius * 1.6, radius * 1.6, 0.06) })
	-- Dust racing out, grit thrown up, the haze left.
	dustOut(frame, color, radius, 48)
	-- Sparks thrown up.
	RiftPortal.flash(ground + normal * 0.5, 1.6)
	if floor and close then
		cracks(ground, normal, color, rng:NextInteger(9, 12), math.min(radius * 0.6, 9), 5)
		chunks(ground, normal, color, material, rng:NextInteger(8, 11), radius)
		-- What lingers: green sparks rising out of the cracks.
		local point = attachmentAt(ground + normal * 0.2)
		local rising = emitter(point, {
			Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new(0.12, 0),
			Transparency = NumberSequence.new(0.1, 1),
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, 3, 0),
			Rate = 26,
			EmissionDirection = Enum.NormalId.Top,
		})
		sparkTexture(rising)
		task.delay(1.4, function()
			rising.Enabled = false
		end)
		Debris:AddItem(point, 2.8)
	end
	shakeNear(ground, 7, 0.55)
	SoundController.playAt("RiftImpact", ground)
end

------------------------------------------------------------------------------
-- The blast landing
------------------------------------------------------------------------------

local crushOutline: { [Model]: Highlight } = setmetatable({}, { __mode = "k" }) :: any

-- A Rift move landed on `victim`: what it does to the body (the burn
-- itself comes from the "Burning" attribute).
function RiftGlove.onHit(victim: Model, attacker: Model, moveId: string)
	if moveId ~= "GravityGlove" then
		return
	end
	local torso = victim:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return
	end
	local position = torso.Position
	local push = Vector3.new(0, 0, -1)
	local from = attacker:FindFirstChild("HumanoidRootPart")
	if from and from:IsA("BasePart") and (position - from.Position).Magnitude > 0.1 then
		push = (position - from.Position).Unit
	end
	-- Their body outlined green a moment (crushed by gravity).
	local old = crushOutline[victim]
	if old then
		old:Destroy()
	end
	if crushOutlines < MAX_CRUSH_OUTLINES then
		crushOutlines += 1
		local outline = Instance.new("Highlight")
		outline.Name = "RiftCrush"
		outline.FillColor = RIFT_GREEN
		outline.FillTransparency = 0.55
		outline.OutlineColor = RIFT_GLOW
		outline.OutlineTransparency = 0
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = victim
		crushOutline[victim] = outline
		tween(
			outline,
			0.5,
			{ FillTransparency = 1, OutlineTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		Debris:AddItem(outline, 0.55)
		task.delay(0.55, function()
			crushOutlines -= 1
		end)
	end
	-- The crush: the air round the torso caving in, then bursting.
	local folder = Instance.new("Folder")
	folder.Name = "RiftCrush"
	local ripple =
		ghost("Ripple", Vector3.one * 5, RIFT_GLOW, Enum.Material.ForceField, Enum.PartType.Ball)
	ripple.Transparency = 0.2
	stick(torso, ripple, CFrame.identity, folder)
	folder.Parent = workspace
	tween(
		ripple,
		0.09,
		{ Size = Vector3.one * 1.4 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(0.09, function()
		if ripple.Parent then
			tween(
				ripple,
				0.3,
				{ Size = Vector3.one * 6.5, Transparency = 1 },
				Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out
			)
		end
	end)
	Debris:AddItem(folder, 0.45)
	-- Rings of bent air through them, along the blast.
	local first = along(push)
	for index = 0, 1 do
		local ring = disc("CrushAir", RIFT_GLOW, 0.1)
		ring.Material = Enum.Material.ForceField
		ring.CFrame = CFrame.lookAt(position, position + push)
		ring.Size = Vector3.new(1, 1, 0.3)
		ring.Parent = workspace
		local size = 4.5 + index * 2
		fade(ring, 0.25 + index * 0.08, {
			Size = Vector3.new(size, size, 0.3),
			CFrame = CFrame.lookAt(
				position + push * (1 + index * 1.5),
				position + push * (2 + index * 1.5)
			),
		})
	end
	ringOut(
		CFrame.fromMatrix(position, first, push),
		0.5,
		3.2,
		0.25,
		12,
		RIFT_GLOW,
		Enum.Material.Neon,
		0.12,
		0.06,
		0.1
	)
	-- Sparks crawling over the torso, arcs over the body.
	local crawl = emitter(torso, {
		Name = "RiftCrushSparks",
		Color = ColorSequence.new(WHITE_HOT, RIFT_GREEN),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new(0.16, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(0.5, 2.5),
		LockedToPart = true,
	})
	sparkTexture(crawl)
	crawl.Shape = Enum.ParticleEmitterShape.Box
	crawl.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	crawl:Emit(22)
	Debris:AddItem(crawl, 0.4)
	if nearCamera(position, 140) then
		local limbs = limbsOf(victim)
		for index = 0, 3 do
			task.delay(index * 0.06 + rand(0, 0.03), function()
				if victim.Parent then
					bodyArc(limbs, 0.06)
				end
			end)
		end
	end
	impactFrame(position, 1.2)
	RiftPortal.flash(position, 0.7)
	shakeNear(position, 3, 0.3)
end

------------------------------------------------------------------------------
-- The Awakening (Rift_Awaken, 1.0 s: gathers with the glove raised, both
-- arms flung out at 0.75 s)
------------------------------------------------------------------------------

local AWAKEN_BURST = 0.75

function RiftGlove.onAwaken(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local rootFrame = root.CFrame
	local floor = floorUnder(rootFrame.Position)
	local ground = if floor then floor.Position else rootFrame.Position - Vector3.new(0, 3, 0)
	local normal = Vector3.new(0, 1, 0)
	local frame = surfaceFrame(ground + Vector3.new(0, 0.1, 0), normal)
	local color: Color3 = if floor then (floorLook(floor)) else SMOKE

	-- A portal tears open behind him.
	RiftPortal.door(rootFrame * CFrame.new(0, 0, 2.2), 0.8)
	RiftPortal.flash(rootFrame.Position, 1.2)
	SoundController.play("PortalOpen", model)

	local folder = Instance.new("Folder")
	folder.Name = "RiftAwaken"
	-- The column of energy: a white-hot thread in a green shaft, bent air
	-- round it, shooting up from the floor.
	local height = 18
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder's axis is its X)
	local layers = {
		{
			name = "Thread",
			color = WHITE_HOT,
			material = Enum.Material.Neon,
			width = 0.35,
			transparency = 0,
		},
		{
			name = "Shaft",
			color = RIFT_GREEN,
			material = Enum.Material.Neon,
			width = 1.6,
			transparency = 0.55,
		},
		{
			name = "Bent",
			color = RIFT_GLOW,
			material = Enum.Material.ForceField,
			width = 3.6,
			transparency = 0.1,
		},
	}
	local column: { { part: Part, width: number } } = {}
	for _, layer in layers do
		local part = ghost(
			layer.name,
			Vector3.new(0.2, layer.width * 0.4, layer.width * 0.4),
			layer.color,
			layer.material,
			Enum.PartType.Cylinder
		)
		part.Anchored = true
		part.Transparency = layer.transparency
		part.CFrame = CFrame.new(ground) * upright
		part.Parent = folder
		tween(part, 0.3, {
			Size = Vector3.new(height, layer.width, layer.width),
			CFrame = CFrame.new(ground + Vector3.new(0, height / 2, 0)) * upright,
		}, Enum.EasingStyle.Quart)
		table.insert(column, { part = part, width = layer.width })
	end
	-- The glow on the floor round his feet.
	local sigil = disc("Sigil", RIFT_GREEN, 0.6)
	sigil.CFrame = frame * CFrame.Angles(math.rad(90), 0, 0)
	sigil.Size = Vector3.new(0.5, 0.5, 0.06)
	sigil.Parent = folder
	tween(
		sigil,
		AWAKEN_BURST,
		{ Size = Vector3.new(8, 8, 0.06), Transparency = 0.35 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	-- The updraft: motes and dust drawn up round him.
	local base = ghost("Updraft", Vector3.new(5, 0.2, 5), RIFT_GREEN, Enum.Material.SmoothPlastic)
	base.Transparency = 1
	base.Anchored = true
	base.CFrame = frame
	base.Parent = folder
	local motes = emitter(base, {
		Color = ColorSequence.new(WHITE_HOT, RIFT_GREEN),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.18),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(8, 8),
		Acceleration = Vector3.new(0, 10, 0),
		Rate = 80,
		EmissionDirection = Enum.NormalId.Top,
	})
	sparkTexture(motes)
	motes.Shape = Enum.ParticleEmitterShape.Box
	local lifted = emitter(base, {
		Color = ColorSequence.new(color:Lerp(SMOKE, 0.45)),
		Size = NumberSequence.new(1, 3),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.9, 1.4),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(25, 25),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		Rate = 16,
		EmissionDirection = Enum.NormalId.Top,
	})
	lifted.Shape = Enum.ParticleEmitterShape.Box
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 1
	light.Range = 16
	light.Shadows = false
	light.Parent = column[1].part
	folder.Parent = workspace
	Debris:AddItem(folder, AWAKEN_BURST + 1.5)

	-- Crackling round him while it builds; the column trembling.
	local limbs = limbsOf(model)
	local close = nearCamera(rootFrame.Position, 160)
	local elapsed, nextArc = 0, 0.05
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= AWAKEN_BURST or folder.Parent == nil then
			connection:Disconnect()
			return
		end
		local k = elapsed / AWAKEN_BURST
		light.Brightness = (1 + 3 * k) * rand(0.7, 1.2)
		if elapsed > 0.3 then
			local thread = column[1]
			local wobble = thread.width * rand(0.7, 1.4)
			thread.part.Size = Vector3.new(height, wobble, wobble)
		end
		nextArc -= dt
		if nextArc <= 0 and close then
			nextArc = (0.1 - 0.05 * k) * rand(0.6, 1.4)
			local centre = root.Position
			local roll = rng:NextNumber()
			if roll < 0.45 and #limbs > 0 then
				-- (body to the air round him)
				local heading = rand(0, TAU)
				local out = centre
					+ Vector3.new(math.cos(heading), 0, math.sin(heading)) * rand(1.6, 3.2)
					+ Vector3.new(0, rand(-2.5, 3.5), 0)
				arc(onSkin(limbs[rng:NextInteger(1, #limbs)]), out, 0.07)
			elseif roll < 0.75 then
				-- (the column to the floor)
				local heading = rand(0, TAU)
				local top = ground + Vector3.new(0, rand(1, 6), 0)
				arc(
					top,
					ground
						+ Vector3.new(math.cos(heading), 0.05, math.sin(heading))
							* rand(1.5, 3.5),
					0.08
				)
			else
				bodyArc(limbs, 0.05)
			end
		end
	end)

	-- (the arms flung out, 0.75 s into Rift_Awaken: the impact)
	task.delay(AWAKEN_BURST - 0.03, function()
		if model.Parent then
			SoundController.play("RiftImpact", model)
		end
	end)
	task.delay(AWAKEN_BURST, function()
		motes.Enabled = false
		lifted.Enabled = false
		-- The palm charge RiftFx started (0.9 s) ends here, in the burst:
		-- no late anticipation, no second flash after it.
		local charging = charges[model]
		if charging then
			charging.alive = false
			charging.folder:Destroy()
		end
		if model.Parent == nil or folder.Parent == nil then
			return
		end
		local chest = root.Position + Vector3.new(0, 0.5, 0)
		-- The column flares out and is gone.
		for _, layer in column do
			local wide = layer.width * 4
			tween(layer.part, 0.4, {
				Size = Vector3.new(height * 1.15, wide, wide),
				Transparency = 1,
			}, Enum.EasingStyle.Quart)
		end
		tween(sigil, 0.5, { Size = Vector3.new(14, 14, 0.06), Transparency = 1 })
		tween(light, 0.6, { Brightness = 0 })
		impactFrame(chest, 3.2)
		lightAt(chest, 10, 36, 0.8)
		local air = ball("AwakenAir", 2, RIFT_GLOW, Enum.Material.ForceField, 0)
		air.CFrame = CFrame.new(chest)
		air.Parent = workspace
		fade(air, 0.55, { Size = Vector3.one * 18 })
		ringOut(frame, 1, 11, 0.45, 20, RIFT_GLOW, Enum.Material.Neon, 0.3, 0.12, 0.05)
		ringOut(frame, 1, 13, 0.6, 16, RIFT_GLOW, Enum.Material.ForceField, 1.4, 1, 0, 0.08)
		RiftPortal.flash(chest, 2)
		dustOut(frame, color, 6, 32)
		if floor and nearCamera(ground, 220) then
			cracks(ground, normal, color, rng:NextInteger(6, 8), 5, 4)
		end
		if close then
			for _ = 1, 5 do
				local heading = rand(0, TAU)
				arc(
					chest,
					chest
						+ Vector3.new(math.cos(heading), rand(-0.6, 0.8), math.sin(heading))
							* rand(3, 5),
					0.09,
					rand(0.08, 0.13)
				)
			end
		end
		shakeNear(chest, 6, 0.5)
	end)
end

------------------------------------------------------------------------------
-- The Awakened aura (while "Awakened" and the "Rift" kit, his clones too)
------------------------------------------------------------------------------

type Aura = {
	alive: boolean,
	emitters: { ParticleEmitter },
	light: PointLight?,
}

local auras: { [Model]: Aura } = setmetatable({}, { __mode = "k" }) :: any
local auraWatched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Motes drifting off each limb (the glove arm most).
local AURA_RATES: { [string]: number } = {
	Torso = 7,
	["Left Arm"] = 6,
	["Right Arm"] = 2,
	["Left Leg"] = 2,
	["Right Leg"] = 2,
}

local function stopAura(model: Model)
	local aura = auras[model]
	if aura == nil then
		return
	end
	auras[model] = nil
	aura.alive = false
	for _, particles in aura.emitters do
		particles.Enabled = false
		Debris:AddItem(particles, 2.2)
	end
	local light = aura.light
	if light then
		tween(light, 0.4, { Brightness = 0 })
		Debris:AddItem(light, 0.45)
	end
end

local function startAura(model: Model)
	local torso = model:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return
	end
	local aura: Aura = { alive = true, emitters = {}, light = nil }
	auras[model] = aura
	for name, rate in AURA_RATES do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local motes = emitter(part, {
				Name = "RiftAura",
				Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
				LightEmission = 1,
				LightInfluence = 0,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.25, 0.12),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.2, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(1.1, 1.9),
				Speed = NumberRange.new(0.2, 0.8),
				Drag = 0.6,
				Acceleration = Vector3.new(0, 1.4, 0),
				RotSpeed = NumberRange.new(-90, 90),
				Rate = rate,
			})
			sparkTexture(motes)
			motes.Shape = Enum.ParticleEmitterShape.Box
			motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			table.insert(aura.emitters, motes)
		end
	end
	local light = Instance.new("PointLight")
	light.Name = "RiftAura"
	light.Color = RIFT_GREEN
	light.Brightness = 0
	light.Range = 9
	light.Shadows = false
	light.Parent = torso
	tween(light, 0.4, { Brightness = 0.8 })
	aura.light = light
	-- Now and then a small arc crackling over him, the light jumping with
	-- it (no outline: the CombatHighlight on him owns that slot).
	task.spawn(function()
		local limbs = limbsOf(model)
		while aura.alive do
			task.wait(rand(0.3, 0.9))
			if not aura.alive or model.Parent == nil or torso.Parent == nil then
				break
			end
			if nearCamera(torso.Position, 80) then
				bodyArc(limbs, 0.035)
				if rng:NextNumber() < 0.35 then
					task.delay(0.05, bodyArc, limbs, 0.03)
				end
				light.Brightness = 2
				tween(light, 0.25, { Brightness = 0.8 })
			end
		end
	end)
end

-- Wears the aura while `model` is Awakened with the "Rift" kit.
function RiftGlove.watch(model: Model)
	if auraWatched[model] then
		return
	end
	auraWatched[model] = true
	local function refresh()
		local on = model.Parent ~= nil
			and model:GetAttribute("Awakened") == true
			and model:GetAttribute("Kit") == KIT
		if on and auras[model] == nil then
			startAura(model)
		elseif not on then
			stopAura(model)
		end
	end
	model:GetAttributeChangedSignal("Awakened"):Connect(refresh)
	model:GetAttributeChangedSignal("Kit"):Connect(refresh)
	model.AncestryChanged:Connect(refresh)
	refresh()
end

return RiftGlove
