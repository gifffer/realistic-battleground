--!strict
-- KitVFX: the visual effects of the Sentinel's and the Bull's moves (heat
-- vision, thunderclap, skyfall, haymaker; gore charge, horn hook, stampede,
-- bull toss), shown by every client from the moves' animations
-- (KitEffects.onAction) and hits (KitEffects.onHit).
--
-- Building blocks: flashes of light, shockwave rings, dust, sparks, flying
-- rocks, cracks in the ground, trails, and a camera shake for whoever is
-- close. Everything is client-side and short-lived (Debris).
--
--   KitVFX.onAction(model, animation, move)   a move starts
--   KitVFX.onHit(victim, attacker, moveId)    one of its hits lands
--   KitVFX.stop(model)                        the move was refused / cut

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local KitVFX = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKS = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local LASER_CORE = Color3.fromRGB(255, 236, 220)
local LASER = Color3.fromRGB(255, 34, 22)
local ENERGY = Color3.fromRGB(200, 226, 255)
local DUST = Color3.fromRGB(150, 138, 118)
local ROCK = Color3.fromRGB(96, 92, 88)
local CRACK = Color3.fromRGB(28, 26, 24)

-- Each move started on a model gets a number: its delayed effects check it
-- (refused / interrupted: they don't play).
local tokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------

local function newPart(size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
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

-- The floor under `position` (through every fighter), or nil.
local function floorAt(position: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(Config.Combat.TAG)
	params.RespectCanCollide = true
	return workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
end

-- A burst of light that fades.
local function flash(
	position: Vector3,
	color: Color3,
	brightness: number,
	range: number,
	time: number
)
	local point = Instance.new("Attachment")
	point.WorldPosition = position
	point.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = point
	tween(light, time, { Brightness = 0 })
	local glow = newPart(Vector3.one * range * 0.12, color, Enum.Material.Neon)
	glow.Shape = Enum.PartType.Ball
	glow.Transparency = 0.25
	glow.CFrame = CFrame.new(position)
	glow.Parent = workspace
	tween(glow, time * 0.6, { Transparency = 1, Size = Vector3.one * range * 0.3 })
	Debris:AddItem(point, time + 0.1)
	Debris:AddItem(glow, time)
end

-- A shockwave ring: a disc facing along `facing` (its look vector),
-- growing from `from` to `to` studs across, fading out.
local function ring(
	cframe: CFrame,
	from: number,
	to: number,
	time: number,
	color: Color3,
	neon: boolean,
	thick: number?
)
	local disc = newPart(
		Vector3.new(thick or 0.15, from, from),
		color,
		if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = if neon then 0.15 else 0.35
	-- (a cylinder's axis is its X: turned to point along the look vector)
	disc.CFrame = cframe * CFrame.Angles(0, math.rad(90), 0)
	disc.Parent = workspace
	tween(
		disc,
		time,
		{ Size = Vector3.new(thick or 0.15, to, to), Transparency = 1 },
		Enum.EasingStyle.Quart
	)
	Debris:AddItem(disc, time + 0.05)
end

-- A flat ring lying on the floor under `position` (a ground shockwave).
local function groundRing(
	position: Vector3,
	from: number,
	to: number,
	time: number,
	color: Color3,
	neon: boolean
)
	local floor = floorAt(position)
	local at = if floor then floor.Position + floor.Normal * 0.06 else position
	local up = if floor then floor.Normal else Vector3.new(0, 1, 0)
	ring(CFrame.lookAt(at, at + up), from, to, time, color, neon, 0.12)
end

-- One-shot particles (smoke, sparks...) from `position`.
local function burst(
	position: Vector3,
	count: number,
	texture: string,
	color: Color3,
	size: NumberRange,
	speed: NumberRange,
	lifetime: NumberRange,
	spread: number,
	direction: Enum.NormalId?,
	acceleration: Vector3?,
	lightEmission: number?
)
	local point = Instance.new("Attachment")
	point.WorldPosition = position
	point.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size.Min),
		NumberSequenceKeypoint.new(1, size.Max),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Speed = speed
	emitter.Lifetime = lifetime
	emitter.SpreadAngle = Vector2.new(spread, spread)
	emitter.EmissionDirection = direction or Enum.NormalId.Top
	emitter.Acceleration = acceleration or Vector3.zero
	emitter.Drag = 2
	emitter.LightEmission = lightEmission or 0
	emitter.LightInfluence = if lightEmission and lightEmission > 0 then 0 else 1
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Rate = 0
	emitter.Parent = point
	emitter:Emit(count)
	Debris:AddItem(point, lifetime.Max + 0.2)
end

local function dust(position: Vector3, count: number, spread: number, size: number)
	burst(
		position,
		count,
		SMOKE,
		DUST,
		NumberRange.new(size, size * 3),
		NumberRange.new(6, 16),
		NumberRange.new(0.6, 1.4),
		spread,
		Enum.NormalId.Top,
		Vector3.new(0, -4, 0)
	)
end

-- Rocks thrown up out of the floor.
local function rocks(position: Vector3, count: number, power: number)
	local floor = floorAt(position)
	local at = if floor then floor.Position else position
	local color = if floor then floor.Instance.Color else ROCK
	local random = Random.new()
	for _ = 1, count do
		local size = random:NextNumber(0.25, 0.7)
		local rock = newPart(
			Vector3.new(size, size * random:NextNumber(0.5, 1), size),
			color,
			Enum.Material.Slate
		)
		rock.Anchored = false
		rock.CanCollide = true
		rock.CFrame = CFrame.new(
			at + Vector3.new(random:NextNumber(-1.5, 1.5), 0.4, random:NextNumber(-1.5, 1.5))
		) * CFrame.Angles(random:NextNumber(0, 6.3), random:NextNumber(0, 6.3), 0)
		local angle = random:NextNumber(0, math.pi * 2)
		rock.AssemblyLinearVelocity = Vector3.new(math.cos(angle), 0, math.sin(angle))
				* random:NextNumber(4, 12)
				* power
			+ Vector3.new(0, random:NextNumber(18, 34) * power, 0)
		rock.AssemblyAngularVelocity = random:NextUnitVector() * 12
		rock.Parent = workspace
		Debris:AddItem(rock, 4)
	end
end

-- Dark cracks running out along the floor from `position`.
local function cracks(position: Vector3, count: number, length: number, lifetime: number)
	local floor = floorAt(position)
	if floor == nil then
		return
	end
	local random = Random.new()
	local up = floor.Normal
	for index = 1, count do
		local angle = (index / count + random:NextNumber(-0.04, 0.04)) * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from = floor.Position + up * 0.03
		local reach = length * random:NextNumber(0.6, 1.1)
		-- (two segments with a kink: cracks are never straight)
		local kink = from
			+ direction * reach * 0.5
			+ direction:Cross(up) * random:NextNumber(-0.4, 0.4)
		for _, segment in { { from, kink }, { kink, from + direction * reach } } do
			local a, b = segment[1], segment[2]
			local crack =
				newPart(Vector3.new(random:NextNumber(0.1, 0.22), 0.02, (b - a).Magnitude), CRACK)
			crack.CFrame = CFrame.lookAt((a + b) / 2, b, up)
			crack.Transparency = 0.1
			crack.Parent = workspace
			task.delay(lifetime * 0.7, function()
				if crack.Parent then
					tween(crack, lifetime * 0.3, { Transparency = 1 })
				end
			end)
			Debris:AddItem(crack, lifetime)
		end
	end
	-- the crater in the middle
	local crater = newPart(Vector3.new(0.02, length * 0.5, length * 0.5), CRACK)
	crater.Shape = Enum.PartType.Cylinder
	crater.Transparency = 0.35
	crater.CFrame = CFrame.lookAt(floor.Position + up * 0.025, floor.Position + up)
		* CFrame.Angles(0, math.rad(90), 0)
	crater.Parent = workspace
	task.delay(lifetime * 0.7, function()
		if crater.Parent then
			tween(crater, lifetime * 0.3, { Transparency = 1 })
		end
	end)
	Debris:AddItem(crater, lifetime)
end

-- A short white streak trailing behind `part` (a swing, a leap).
local function trail(part: BasePart, color: Color3, time: number, width: number)
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, width / 2, 0)
	a.Parent = part
	local b = Instance.new("Attachment")
	b.Position = Vector3.new(0, -width / 2, 0)
	b.Parent = part
	local streak = Instance.new("Trail")
	streak.Attachment0 = a
	streak.Attachment1 = b
	streak.Color = ColorSequence.new(color)
	streak.Transparency = NumberSequence.new(0.3, 1)
	streak.Lifetime = 0.25
	streak.LightEmission = 0.6
	streak.FaceCamera = true
	streak.Parent = part
	Debris:AddItem(a, time + 0.3)
	Debris:AddItem(b, time + 0.3)
	Debris:AddItem(streak, time + 0.3)
end

-- Camera shake for us if we're close to `position` (stronger closer).
local shakeUntil, shakeStrength = 0, 0
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
end
RunService:BindToRenderStep("KitVFXShake", Enum.RenderPriority.Camera.Value + 2, function()
	local left = shakeUntil - os.clock()
	local camera = workspace.CurrentCamera
	if left <= 0 or camera == nil then
		return
	end
	local power = shakeStrength * math.min(1, left * 4)
	local random = Random.new()
	camera.CFrame = camera.CFrame
		* CFrame.Angles(
			math.rad(random:NextNumber(-power, power)),
			math.rad(random:NextNumber(-power, power)),
			math.rad(random:NextNumber(-power, power) * 0.5)
		)
end)

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

-- Runs `fn` `delay` seconds later, if the move on `model` is still the same.
local function later(model: Model, token: number, delay: number, fn: () -> ())
	task.delay(delay, function()
		if tokens[model] == token and model.Parent then
			fn()
		end
	end)
end

------------------------------------------------------------------------------
-- SENTINEL
------------------------------------------------------------------------------

-- Heat vision: the eyes glow red, then two beams burn straight ahead (the
-- way he faced when it started) until `beam.to`.
local function heatVision(model: Model, move: Kits.MoveDef, token: number)
	local beam = move.beam
	local head = part(model, "Head")
	local root = part(model, "HumanoidRootPart")
	if beam == nil or head == nil or root == nil then
		return
	end
	local look = root.CFrame.LookVector
	local direction = Vector3.new(look.X, 0, look.Z)
	direction = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.new(0, 0, -1)
	local folder = Instance.new("Folder")
	folder.Name = "HeatVision"
	folder.Parent = workspace

	-- The eyes: two glowing points on the face, a red light.
	local eyes: { BasePart } = {}
	for _, side in { -1, 1 } do
		local eye = newPart(Vector3.one * 0.14, LASER, Enum.Material.Neon)
		eye.Shape = Enum.PartType.Ball
		eye.Anchored = false
		eye.Massless = true
		eye.CFrame = head.CFrame * CFrame.new(side * 0.17, 0.12, -0.58)
		local joint = Instance.new("WeldConstraint")
		joint.Part0 = head
		joint.Part1 = eye
		joint.Parent = eye
		eye.Parent = folder
		table.insert(eyes, eye)
	end
	local glow = Instance.new("PointLight")
	glow.Color = LASER
	glow.Brightness = 0
	glow.Range = 8
	glow.Parent = eyes[1]
	tween(glow, beam.from, { Brightness = 6 })
	SoundController.play("LaserCharge", model)

	-- The beams (core + glow, per eye) and what they hit.
	local beams: { { core: Part, outer: Part } } = {}
	for _ = 1, 2 do
		local outer = newPart(Vector3.new(0.34, 0.34, 1), LASER, Enum.Material.Neon)
		outer.Transparency = 0.55
		local core = newPart(Vector3.new(0.1, 0.1, 1), LASER_CORE, Enum.Material.Neon)
		table.insert(beams, { core = core, outer = outer })
	end
	local impact = Instance.new("Attachment")
	impact.Parent = workspace.Terrain
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARKS
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), LASER)
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Speed = NumberRange.new(8, 20)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Lifetime = NumberRange.new(0.2, 0.5)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.LightEmission = 1
	sparks.Rate = 0
	sparks.Parent = impact
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 66, 64))
	smoke.Size = NumberSequence.new(0.6, 2.4)
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Speed = NumberRange.new(1.5, 4)
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Rate = 0
	smoke.Parent = impact
	local heat = Instance.new("PointLight")
	heat.Color = Color3.fromRGB(255, 120, 40)
	heat.Brightness = 0
	heat.Range = 10
	heat.Parent = impact

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, folder }
	local startedAt = os.clock()
	local lastScorch = 0
	local firing = false
	local loop: Sound? = nil
	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if loop then
			loop:Stop()
		end
		sparks.Rate = 0
		smoke.Rate = 0
		tween(heat, 0.3, { Brightness = 0 })
		for _, pair in beams do
			tween(pair.core, 0.15, { Transparency = 1 })
			tween(pair.outer, 0.15, { Transparency = 1 })
		end
		tween(glow, 0.4, { Brightness = 0 })
		for _, eye in eyes do
			tween(eye, 0.4, { Transparency = 1 })
		end
		Debris:AddItem(folder, 0.6)
		Debris:AddItem(impact, 1.6)
	end
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startedAt
		if tokens[model] ~= token or head.Parent == nil or elapsed > beam.to then
			finish()
			return
		end
		if elapsed < beam.from then
			return
		end
		if not firing then
			firing = true
			loop = SoundController.play("LaserBeam", model)
			flash(head.Position + direction, LASER, 8, 10, 0.3)
			for _, pair in beams do
				pair.outer.Parent = folder
				pair.core.Parent = folder
			end
			sparks.Rate = 160
			smoke.Rate = 25
			heat.Brightness = 5
		end
		-- (one hit point for both eyes: they converge on it)
		local origin = head.Position + direction * 0.5
		local hit = workspace:Raycast(origin, direction * beam.range, params)
		local target = if hit then hit.Position else origin + direction * beam.range
		local flicker = 0.85 + math.random() * 0.3
		for index, pair in beams do
			local from = eyes[index].Position
			local length = (target - from).Magnitude
			local frame = CFrame.lookAt(from + (target - from) / 2, target)
			pair.core.CFrame = frame
			pair.core.Size = Vector3.new(0.1 * flicker, 0.1 * flicker, length)
			pair.outer.CFrame = frame
			pair.outer.Size = Vector3.new(0.34 * flicker, 0.34 * flicker, length)
		end
		impact.WorldPosition = target
		if hit then
			impact.WorldCFrame = CFrame.lookAt(target, target + hit.Normal)
				* CFrame.Angles(math.rad(-90), 0, 0)
			-- Scorch marks where it burns the ground / a wall.
			local owner = hit.Instance:FindFirstAncestorOfClass("Model")
			local onBody = owner ~= nil and owner:FindFirstChildOfClass("Humanoid") ~= nil
			if not onBody and os.clock() - lastScorch > 0.08 then
				lastScorch = os.clock()
				local scorch = newPart(Vector3.new(0.02, 0.9, 0.9), Color3.fromRGB(26, 20, 18))
				scorch.Shape = Enum.PartType.Cylinder
				scorch.Transparency = 0.25
				scorch.CFrame = CFrame.lookAt(target + hit.Normal * 0.02, target + hit.Normal)
					* CFrame.Angles(0, math.rad(90), 0)
				scorch.Parent = workspace
				local ember = newPart(
					Vector3.new(0.025, 0.45, 0.45),
					Color3.fromRGB(255, 120, 40),
					Enum.Material.Neon
				)
				ember.Shape = Enum.PartType.Cylinder
				ember.CFrame = scorch.CFrame * CFrame.new(0.005, 0, 0)
				ember.Parent = workspace
				tween(ember, 1.2, { Transparency = 1 })
				task.delay(6, function()
					if scorch.Parent then
						tween(scorch, 3, { Transparency = 1 })
					end
				end)
				Debris:AddItem(scorch, 9.2)
				Debris:AddItem(ember, 1.3)
			end
		end
	end)
end

local function thunderClap(model: Model, token: number)
	later(model, token, 0.34, function()
		local root = part(model, "HumanoidRootPart")
		local right, left = fist(model, "Right Arm"), fist(model, "Left Arm")
		if root == nil or right == nil or left == nil then
			return
		end
		local hands = (right + left) / 2
		local forward = root.CFrame.LookVector
		SoundController.play("ThunderClap", model)
		flash(hands, ENERGY, 10, 16, 0.35)
		for index = 0, 2 do
			local at = hands + forward * (1 + index * 2.2)
			task.delay(index * 0.05, function()
				ring(CFrame.lookAt(at, at + forward), 1, 9 + index * 3, 0.45, ENERGY, true, 0.18)
			end)
		end
		-- the air pushes the dust ahead
		local ground = feet(model)
		if ground then
			for step = 1, 4 do
				dust(ground + forward * step * 2.2, 6, 25, 0.8)
			end
		end
		shake(hands, 1.4, 30, 0.3)
	end)
end

local function skyfall(model: Model, move: Kits.MoveDef, token: number)
	local leap = move.leap
	local hitAt = if move.hits[1] then move.hits[1].at else 0.84
	later(model, token, if leap then leap.at else 0.18, function()
		local ground = feet(model)
		local torso = part(model, "Torso")
		if ground then
			groundRing(ground, 2, 10, 0.4, DUST, false)
			dust(ground, 18, 60, 1)
			rocks(ground, 5, 0.6)
		end
		if torso then
			trail(torso, ENERGY, hitAt - (if leap then leap.at else 0.18), 1.6)
		end
	end)
	later(model, token, hitAt, function()
		local ground = feet(model)
		if ground == nil then
			return
		end
		SoundController.play("Slam", model)
		flash(ground + Vector3.new(0, 1, 0), ENERGY, 12, 22, 0.45)
		groundRing(ground, 2, 26, 0.55, ENERGY, true)
		task.delay(0.06, function()
			groundRing(ground, 2, 20, 0.7, DUST, false)
		end)
		dust(ground, 40, 80, 1.4)
		rocks(ground, 16, 1)
		cracks(ground, 9, 6, 8)
		shake(ground, 3, 50, 0.5)
	end)
end

local function haymaker(model: Model, token: number)
	local arm = part(model, "Right Arm")
	if arm then
		-- the fist charges up during the wind-up
		local charge = newPart(Vector3.one * 0.3, ENERGY, Enum.Material.Neon)
		charge.Shape = Enum.PartType.Ball
		charge.Transparency = 0.4
		charge.Anchored = false
		charge.Massless = true
		charge.CFrame = arm.CFrame * CFrame.new(0, -1.05, 0)
		local joint = Instance.new("WeldConstraint")
		joint.Part0 = arm
		joint.Part1 = charge
		joint.Parent = charge
		local light = Instance.new("PointLight")
		light.Color = ENERGY
		light.Brightness = 0
		light.Range = 7
		light.Parent = charge
		charge.Parent = workspace
		tween(charge, 0.5, { Size = Vector3.one * 1.1, Transparency = 0.15 })
		tween(light, 0.5, { Brightness = 5 })
		later(model, token, 0.56, function()
			tween(charge, 0.15, { Transparency = 1, Size = Vector3.one * 2 })
			tween(light, 0.2, { Brightness = 0 })
		end)
		Debris:AddItem(charge, 1)
		trail(arm, ENERGY, 0.65, 0.8)
	end
	local ground = feet(model)
	if ground then
		dust(ground, 8, 40, 0.6)
	end
	later(model, token, 0.55, function()
		local root = part(model, "HumanoidRootPart")
		local hand = fist(model, "Right Arm")
		if root == nil or hand == nil then
			return
		end
		local forward = root.CFrame.LookVector
		flash(hand + forward, ENERGY, 12, 16, 0.3)
		ring(CFrame.lookAt(hand + forward, hand + forward * 2), 1, 8, 0.35, ENERGY, true, 0.2)
		task.delay(0.05, function()
			ring(
				CFrame.lookAt(hand + forward * 3, hand + forward * 4),
				1,
				12,
				0.45,
				Color3.new(1, 1, 1),
				true,
				0.12
			)
		end)
		shake(hand, 1.8, 30, 0.3)
	end)
end

------------------------------------------------------------------------------
-- BULL
------------------------------------------------------------------------------

-- Steam snorted out of the nose.
local function snort(model: Model)
	local head = part(model, "Head")
	if head == nil then
		return
	end
	SoundController.play("BullSnort", model)
	for _, side in { -0.12, 0.12 } do
		local at = (head.CFrame * CFrame.new(side, -0.15, -0.6)).Position
		burst(
			at,
			6,
			SMOKE,
			Color3.fromRGB(220, 220, 225),
			NumberRange.new(0.3, 1.4),
			NumberRange.new(3, 6),
			NumberRange.new(0.5, 0.9),
			15,
			Enum.NormalId.Bottom,
			Vector3.new(0, 1, 0)
		)
	end
end

local function goreCharge(model: Model, move: Kits.MoveDef, token: number)
	snort(model)
	local charge = move.charge
	local ground = feet(model)
	if ground then
		dust(ground, 10, 50, 0.8)
	end
	if charge == nil then
		return
	end
	-- dust kicked up all along the charge, the hooves pounding
	later(model, token, charge.from, function()
		local root = part(model, "HumanoidRootPart")
		if root == nil then
			return
		end
		local kick = Instance.new("Attachment")
		kick.Position = Vector3.new(0, -2.8, 0.6)
		kick.Parent = root
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SMOKE
		emitter.Color = ColorSequence.new(DUST)
		emitter.Size = NumberSequence.new(0.8, 2.6)
		emitter.Transparency = NumberSequence.new(0.35, 1)
		emitter.Speed = NumberRange.new(2, 6)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Rate = 60
		emitter.Parent = kick
		Debris:AddItem(kick, charge.to - charge.from + 0.05)
		local head = part(model, "Head")
		if head then
			trail(head, Color3.fromRGB(255, 255, 255), charge.to - charge.from, 1.2)
		end
		for step = 0, 3 do
			later(model, token, step * 0.18, function()
				local spot = feet(model)
				if spot then
					groundRing(spot, 1, 4, 0.3, DUST, false)
				end
			end)
		end
	end)
end

local function hornHook(model: Model, token: number)
	local ground = feet(model)
	if ground then
		dust(ground, 8, 40, 0.7)
	end
	local head = part(model, "Head")
	if head then
		later(model, token, 0.18, function()
			trail(head, Color3.fromRGB(255, 240, 220), 0.3, 1.4)
		end)
	end
	later(model, token, 0.32, function()
		local root = part(model, "HumanoidRootPart")
		if root == nil then
			return
		end
		local at = root.Position + root.CFrame.LookVector * 2.5
		dust(at - Vector3.new(0, 2.6, 0), 14, 30, 0.9)
		ring(
			CFrame.lookAt(at, at + Vector3.new(0, 1, 0)),
			1,
			7,
			0.35,
			Color3.fromRGB(255, 240, 220),
			true,
			0.12
		)
		shake(at, 1.2, 25, 0.25)
	end)
end

local function stampede(model: Model, token: number)
	snort(model)
	local ground = feet(model)
	if ground then
		dust(ground, 8, 40, 0.7)
	end
	later(model, token, 0.5, function()
		local spot = feet(model)
		local root = part(model, "HumanoidRootPart")
		if spot == nil or root == nil then
			return
		end
		spot += root.CFrame.LookVector * 1
		SoundController.play("Stomp", model)
		flash(spot + Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 210, 160), 6, 16, 0.35)
		groundRing(spot, 2, 26, 0.6, DUST, false)
		task.delay(0.08, function()
			groundRing(spot, 2, 18, 0.5, Color3.fromRGB(255, 220, 180), true)
		end)
		dust(spot, 46, 85, 1.5)
		rocks(spot, 18, 0.9)
		cracks(spot, 10, 7, 8)
		shake(spot, 3.2, 50, 0.55)
	end)
end

local function bullToss(model: Model, token: number)
	later(model, token, 0.22, function()
		local ground = feet(model)
		if ground then
			dust(ground, 10, 40, 0.8)
		end
	end)
	later(model, token, 0.55, function()
		local torso = part(model, "Torso")
		if torso then
			trail(torso, Color3.fromRGB(255, 240, 220), 0.3, 1.8)
		end
	end)
	later(model, token, 0.7, function()
		local root = part(model, "HumanoidRootPart")
		if root == nil then
			return
		end
		local at = root.Position + Vector3.new(0, 1.5, 0)
		ring(
			CFrame.lookAt(at, at + root.CFrame.LookVector),
			1,
			9,
			0.4,
			Color3.fromRGB(255, 240, 220),
			true,
			0.14
		)
		local ground = feet(model)
		if ground then
			dust(ground, 16, 60, 1)
		end
		shake(at, 1.5, 30, 0.3)
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
function KitVFX.onHit(victim: Model, _attacker: Model, moveId: string)
	local torso = part(victim, "Torso")
	if torso == nil then
		return
	end
	if moveId == "HeatVision" then
		-- burnt: a glow and smoke where it burns
		burst(
			torso.Position,
			6,
			SMOKE,
			Color3.fromRGB(60, 56, 54),
			NumberRange.new(0.4, 1.6),
			NumberRange.new(2, 5),
			NumberRange.new(0.6, 1.1),
			30
		)
		burst(
			torso.Position,
			10,
			FIRE,
			Color3.fromRGB(255, 140, 60),
			NumberRange.new(0.3, 0),
			NumberRange.new(3, 7),
			NumberRange.new(0.2, 0.4),
			50,
			nil,
			nil,
			1
		)
	elseif moveId == "GoreCharge" or moveId == "HornHook" or moveId == "BullToss" then
		dust(torso.Position - Vector3.new(0, 2, 0), 10, 50, 0.8)
		flash(torso.Position, Color3.fromRGB(255, 230, 200), 5, 10, 0.2)
	elseif moveId == "Haymaker" or moveId == "ThunderClap" then
		flash(torso.Position, ENERGY, 8, 12, 0.25)
	end
end

-- The move was refused / cut short: its pending effects don't play.
function KitVFX.stop(model: Model)
	tokens[model] = (tokens[model] or 0) + 1
end

return table.freeze(KitVFX)
