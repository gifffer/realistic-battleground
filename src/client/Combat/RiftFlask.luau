--!strict
-- RiftFlask: Dr. Rift's flasks (acid / explosive): the one in his hand, the
-- flight (the same arc as the server's), the burst (acid splash or
-- explosion) and the acid puddle. Look only (Server/Combat/Gadgets decides).
--
--   RiftFlask.buildHeld(arm, folder, kind)    in his fist ("Acid"/"Explosive")
--   RiftFlask.thrown(data) / burst(data) / puddle(data)   Remotes.RiftFx
--   RiftFlask.onReleased(callback)            (RiftFx takes the held one away)

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local RiftFlask = {}
local P = require(script.Parent.RiftParts)
local ACID = P.ACID
local ACID_DARK = P.ACID_DARK
local FIRE = P.FIRE
local FIRE_HOT = P.FIRE_HOT
local SMOKE = P.SMOKE
local GLASS = P.GLASS
local ghost = P.ghost
local stick = P.stick
local disc = P.disc
local attachmentAt = P.attachmentAt
local emitter = P.emitter
local sparkTexture = P.sparkTexture
local fade = P.fade
local floorUnder = P.floorUnder
local shakeNear = P.shakeNear
local random = Random.new()

local releasedCallback: ((model: Model) -> ())? = nil

function RiftFlask.onReleased(callback: (model: Model) -> ())
	releasedCallback = callback
end

function RiftFlask.released(model: Model)
	if releasedCallback then
		releasedCallback(model)
	end
end

-- A flask (Right Arm space: in the fist at Y = -1).
function RiftFlask.buildHeld(arm: BasePart, folder: Folder, kind: string)
	local liquid = if kind == "Explosive" then FIRE else ACID
	local hand = CFrame.new(0, -1.15, -0.1)
	local body = ghost(
		"Glass",
		Vector3.new(0.55, 0.55, 0.55),
		GLASS,
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	body.Transparency = 0.45
	stick(arm, body, hand * CFrame.new(0, -0.2, 0), folder)
	local inside = ghost(
		"Liquid",
		Vector3.new(0.42, 0.42, 0.42),
		liquid,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	inside.Transparency = 0.1
	stick(arm, inside, hand * CFrame.new(0, -0.24, 0), folder)
	stick(
		arm,
		ghost(
			"Neck",
			Vector3.new(0.3, 0.16, 0.16),
			GLASS,
			Enum.Material.Glass,
			Enum.PartType.Cylinder
		),
		hand * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		folder
	)
	stick(
		arm,
		ghost(
			"Cork",
			Vector3.new(0.12, 0.18, 0.18),
			Color3.fromRGB(120, 86, 52),
			Enum.Material.Wood,
			Enum.PartType.Cylinder
		),
		hand * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		folder
	)
	local light = Instance.new("PointLight")
	light.Color = liquid
	light.Brightness = 0.8
	light.Range = 4
	light.Parent = inside
end

------------------------------------------------------------------------------
-- Flasks
------------------------------------------------------------------------------

type Flight = { part: BasePart, connection: RBXScriptConnection }
local flying: { [number]: Flight } = {}

local function flaskModel(kind: string, at: CFrame): BasePart
	local liquid = if kind == "Explosive" then FIRE else ACID
	local body = ghost(
		"Flask",
		Vector3.new(0.55, 0.55, 0.55),
		GLASS,
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	body.Transparency = 0.45
	body.Anchored = true
	body.CFrame = at
	local inside = ghost(
		"Liquid",
		Vector3.new(0.42, 0.42, 0.42),
		liquid,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	inside.Anchored = true
	inside.CFrame = at
	inside.Parent = body
	local trail = emitter(body, {
		Color = ColorSequence.new(liquid),
		LightEmission = 0.6,
		Size = NumberSequence.new(0.12, 0),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.2, 0.35),
		Speed = NumberRange.new(0, 0.5),
		Rate = 40,
	})
	sparkTexture(trail)
	return body
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
	local part = flaskModel(kind, CFrame.new(origin))
	part.Parent = workspace
	local position, moving = origin, velocity
	local spin = 0
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		position += moving * dt
		moving -= Vector3.new(0, gravity * dt, 0)
		spin += dt * 14
		local cframe = CFrame.new(position) * CFrame.Angles(spin, spin * 0.6, 0)
		part.CFrame = cframe
		local inside = part:FindFirstChild("Liquid")
		if inside and inside:IsA("BasePart") then
			inside.CFrame = cframe
		end
		if os.clock() - started > 4 then
			local flight = flying[id]
			if flight then
				flying[id] = nil
				flight.connection:Disconnect()
				flight.part:Destroy()
			end
		end
	end)
	flying[id] = { part = part, connection = connection }
end

-- Bits of glass flying out of a burst.
local function shards(position: Vector3, count: number)
	for _ = 1, count do
		local shard = ghost(
			"Shard",
			Vector3.new(0.05, 0.03, random:NextNumber(0.08, 0.2)),
			GLASS,
			Enum.Material.Glass
		)
		shard.Transparency = 0.3
		shard.CanCollide = true
		shard.Massless = false
		shard.CFrame = CFrame.new(position)
			* CFrame.Angles(random:NextNumber(0, 6.3), random:NextNumber(0, 6.3), 0)
		shard.AssemblyLinearVelocity = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(0.2, 1),
			random:NextNumber(-1, 1)
		) * 16
		shard.Parent = workspace
		Debris:AddItem(shard, 5)
	end
end

local function acidBurst(position: Vector3, radius: number)
	local point = attachmentAt(position)
	local splash = emitter(point, {
		Color = ColorSequence.new(ACID, ACID_DARK),
		LightEmission = 0.4,
		Size = NumberSequence.new(0.35, 0.1),
		Transparency = NumberSequence.new(0, 0.6),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(radius * 1.2, radius * 2.6),
		Acceleration = Vector3.new(0, -50, 0),
		Drag = 1,
	})
	splash:Emit(70)
	local fumes = emitter(point, {
		Color = ColorSequence.new(Color3.fromRGB(170, 200, 90)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, radius * 0.9),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(0, 2, 0),
	})
	fumes:Emit(14)
	local light = Instance.new("PointLight")
	light.Color = ACID
	light.Brightness = 2.5
	light.Range = radius * 2
	light.Parent = point
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	Debris:AddItem(point, 2.5)
	SoundController.playAt("FlaskBreak", position)
	SoundController.playAt("AcidSizzle", position)
end

local function explosion(position: Vector3, radius: number)
	-- The fireball: a ball of light that swells and fades, a hot core.
	local ball =
		ghost("Fireball", Vector3.new(1, 1, 1), FIRE, Enum.Material.Neon, Enum.PartType.Ball)
	ball.Anchored = true
	ball.CFrame = CFrame.new(position)
	ball.Transparency = 0.05
	ball.Parent = workspace
	fade(ball, 0.45, { Size = Vector3.one * radius * 1.4, Color = Color3.fromRGB(120, 40, 10) })
	local core =
		ghost("Core", Vector3.new(0.6, 0.6, 0.6), FIRE_HOT, Enum.Material.Neon, Enum.PartType.Ball)
	core.Anchored = true
	core.CFrame = CFrame.new(position)
	core.Parent = workspace
	fade(core, 0.25, { Size = Vector3.one * radius * 0.8 })
	local point = attachmentAt(position)
	local fire = emitter(point, {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, FIRE_HOT),
			ColorSequenceKeypoint.new(0.3, FIRE),
			ColorSequenceKeypoint.new(1, SMOKE),
		}),
		LightEmission = 0.7,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(1, radius * 0.7),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(radius * 1.5, radius * 3),
		Drag = 5,
	})
	fire:Emit(40)
	local smoke = emitter(point, {
		Color = ColorSequence.new(Color3.fromRGB(40, 38, 36)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(1, radius * 1.2),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(2, 6),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 1,
	})
	smoke:Emit(18)
	local embers = emitter(point, {
		Color = ColorSequence.new(FIRE_HOT, FIRE),
		LightEmission = 1,
		Size = NumberSequence.new(0.12, 0),
		Lifetime = NumberRange.new(0.6, 1.4),
		Speed = NumberRange.new(20, 45),
		Acceleration = Vector3.new(0, -40, 0),
	})
	sparkTexture(embers)
	embers:Emit(60)
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Brightness = 8
	light.Range = radius * 4
	light.Parent = point
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(point, 4)
	-- The shockwave on the floor and a scorch mark.
	local floor = floorUnder(position)
	if floor then
		local ring = disc("Shock", FIRE_HOT, 0.3)
		ring.CFrame = CFrame.lookAt(
			floor.Position + Vector3.new(0, 0.1, 0),
			floor.Position + Vector3.new(0, 1, 0)
		)
		ring.Size = Vector3.new(1, 1, 0.06)
		ring.Parent = workspace
		fade(ring, 0.35, { Size = Vector3.new(radius * 2.4, radius * 2.4, 0.06) })
		local scorch = ghost(
			"Scorch",
			Vector3.new(0.05, radius * 1.1, radius * 1.1),
			Color3.fromRGB(22, 20, 18),
			Enum.Material.Slate,
			Enum.PartType.Cylinder
		)
		scorch.Anchored = true
		scorch.CFrame = CFrame.new(floor.Position + Vector3.new(0, 0.03, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		scorch.Transparency = 0.25
		scorch.Parent = workspace
		task.delay(12, function()
			fade(scorch, 3)
		end)
	end
	shakeNear(position, 6, 0.5)
	SoundController.playAt("Explosion", position)
end

local function burst(data: { [string]: any })
	local id, kind, position, radius = data.id, data.kind, data.position, data.radius
	if typeof(kind) ~= "string" or typeof(position) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	if typeof(id) == "number" then
		local flight = flying[id]
		if flight then
			flying[id] = nil
			flight.connection:Disconnect()
			flight.part:Destroy()
		end
	end
	shards(position, 10)
	if kind == "Explosive" then
		explosion(position, radius)
	else
		acidBurst(position, radius)
	end
end

-- The acid on the floor: a bubbling, smoking stain that spreads, then dries.
local function puddle(data: { [string]: any })
	local position, radius, seconds = data.position, data.radius, data.seconds
	if
		typeof(position) ~= "Vector3"
		or typeof(radius) ~= "number"
		or typeof(seconds) ~= "number"
	then
		return
	end
	local stain = disc("AcidPuddle", ACID, 0.25)
	stain.Material = Enum.Material.Glass
	stain.CFrame =
		CFrame.lookAt(position + Vector3.new(0, 0.06, 0), position + Vector3.new(0, 1, 0))
	stain.Size = Vector3.new(0.5, 0.5, 0.06)
	stain.Parent = workspace
	TweenService:Create(stain, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Size = Vector3.new(radius * 2, radius * 1.8, 0.06),
	}):Play()
	local glow = disc("AcidGlow", ACID, 0.6)
	glow.CFrame = stain.CFrame * CFrame.new(0, 0, -0.02)
	glow.Size = Vector3.new(radius * 1.2, radius * 1.1, 0.06)
	glow.Parent = workspace
	local bubbles = emitter(stain, {
		Color = ColorSequence.new(ACID),
		LightEmission = 0.3,
		Size = NumberSequence.new(0.18, 0.05),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(0.5, 2),
		Rate = 30,
		EmissionDirection = Enum.NormalId.Front,
	})
	bubbles.Shape = Enum.ParticleEmitterShape.Disc
	local fumes = emitter(stain, {
		Color = ColorSequence.new(Color3.fromRGB(170, 200, 90)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 2.4),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = Vector3.new(0, 2, 0),
		Rate = 8,
		EmissionDirection = Enum.NormalId.Front,
	})
	fumes.Shape = Enum.ParticleEmitterShape.Disc
	task.delay(seconds, function()
		bubbles.Enabled = false
		fumes.Enabled = false
		fade(stain, 1.2, { Color = ACID_DARK })
		fade(glow, 0.6)
	end)
end

RiftFlask.thrown = thrown
RiftFlask.burst = burst
RiftFlask.puddle = puddle

return RiftFlask
