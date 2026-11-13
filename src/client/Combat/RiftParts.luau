--!strict
-- RiftParts: what Dr. Rift's look is built from (Client/Combat/Rift*):
-- colours, show-only parts, welds, flat discs, particle emitters, fades, the
-- floor under a point, and the camera shake near a point.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local RiftParts = {}

export type Shake = (strength: number, seconds: number) -> ()

-- Colours.
local STEEL = Color3.fromRGB(96, 98, 102)
local STEEL_DARK = Color3.fromRGB(52, 54, 58)
local BRASS = Color3.fromRGB(138, 112, 64)
local RUST = Color3.fromRGB(104, 62, 40)
local CABLE = Color3.fromRGB(28, 28, 30)
local RIFT_GREEN = Color3.fromRGB(110, 255, 96)
local RIFT_DEEP = Color3.fromRGB(26, 120, 40)
local RIFT_GLOW = Color3.fromRGB(170, 255, 150)
local ACID = Color3.fromRGB(150, 230, 40)
local ACID_DARK = Color3.fromRGB(82, 120, 20)
local FIRE = Color3.fromRGB(255, 140, 40)
local FIRE_HOT = Color3.fromRGB(255, 230, 150)
local SMOKE = Color3.fromRGB(70, 68, 64)
local RAY_CORE = Color3.fromRGB(255, 236, 200)
local RAY_GLOW = Color3.fromRGB(255, 96, 40)
local GLASS = Color3.fromRGB(200, 220, 210)

RiftParts.STEEL = STEEL
RiftParts.STEEL_DARK = STEEL_DARK
RiftParts.BRASS = BRASS
RiftParts.RUST = RUST
RiftParts.CABLE = CABLE
RiftParts.RIFT_GREEN = RIFT_GREEN
RiftParts.RIFT_DEEP = RIFT_DEEP
RiftParts.RIFT_GLOW = RIFT_GLOW
RiftParts.ACID = ACID
RiftParts.ACID_DARK = ACID_DARK
RiftParts.FIRE = FIRE
RiftParts.FIRE_HOT = FIRE_HOT
RiftParts.SMOKE = SMOKE
RiftParts.RAY_CORE = RAY_CORE
RiftParts.RAY_GLOW = RAY_GLOW
RiftParts.GLASS = GLASS

local SHAKE_RANGE = 45
local shakeCallback: Shake? = nil

-- CombatEffectsController gives us its camera shake.
function RiftParts.setShake(shake: Shake)
	shakeCallback = shake
end

local function shakeNear(position: Vector3, strength: number, seconds: number)
	local camera = workspace.CurrentCamera
	if shakeCallback == nil or camera == nil then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance < SHAKE_RANGE then
		shakeCallback(strength * (1 - distance / SHAKE_RANGE), seconds)
	end
end

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------

-- A part that only shows (no collisions, no hits, no weight).
local function ghost(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Welds `part` to `base` at `offset` (base space) and parents it.
local function stick(base: BasePart, part: BasePart, offset: CFrame, parent: Instance)
	part.CFrame = base.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = parent
end

-- A flat ellipse (a portal's layer): a part with a sphere mesh squashed flat.
local function disc(name: string, color: Color3, transparency: number): Part
	local part = ghost(name, Vector3.new(1, 1, 0.06), color, Enum.Material.Neon)
	part.Transparency = transparency
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Anchored = true
	return part
end

local function attachmentAt(position: Vector3): Attachment
	local point = Instance.new("Attachment")
	point.WorldPosition = position
	point.Parent = workspace.Terrain
	return point
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particles.Rate = 0
	particles.LightEmission = 0
	particles.Speed = NumberRange.new(2, 5)
	particles.Lifetime = NumberRange.new(0.4, 0.8)
	particles.SpreadAngle = Vector2.new(180, 180)
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

local function sparkTexture(particles: ParticleEmitter)
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
end

local function fade(part: BasePart, seconds: number, goal: { [string]: any }?)
	local props: { [string]: any } = goal or {}
	props.Transparency = 1
	TweenService
		:Create(
			part,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			props
		)
		:Play()
	Debris:AddItem(part, seconds + 0.05)
end

-- The floor under `position` (fighters and loose bits don't count).
local function floorUnder(position: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(Config.Combat.TAG)
	params.RespectCanCollide = true
	return workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), params)
end

RiftParts.ghost = ghost
RiftParts.stick = stick
RiftParts.disc = disc
RiftParts.attachmentAt = attachmentAt
RiftParts.emitter = emitter
RiftParts.sparkTexture = sparkTexture
RiftParts.fade = fade
RiftParts.floorUnder = floorUnder
RiftParts.shakeNear = shakeNear

return table.freeze(RiftParts)
