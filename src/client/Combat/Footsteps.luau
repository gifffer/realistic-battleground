--!strict
-- Footsteps: what a foot does to the floor, at the exact moment it lands
-- (Animation/Locomotion reports the contacts of its clips). Realistic and
-- discreet, never cartoon:
--   • STEP: on loose ground (sand, dirt, mud, snow, gravel...) a low puff of
--     dust in the floor's own colour, kicked back from the foot; nothing on
--     clean hard floors. Running kicks up more.
--   • SCUFF (a hard stop, a sharp turn at speed, the side-hop's push): the
--     sole drags, a flat spray of grit along the floor on any rough floor
--     (concrete, asphalt, brick, wood, metal...).
--   • SOUND: every landing plays a footstep sound picked by the floor's
--     material (concrete / dirt / wood / metal / grass: Shared/Sounds
--     Foot*), from the leg, louder when running. Within 45 studs. Roblox's
--     own footstep loop is muted (DeathSoundController).
-- Only within 70 studs of the camera. One pooled emitter, particles only
-- (Emit): nothing is created per step.
--
--   Footsteps.step(model, foot, strength, scuff)

local Workspace = game:GetService("Workspace")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Footsteps = {}

local RANGE = 70 -- studs from the camera
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
-- Floors that give dust on a plain step (and how much: 1 = full).
local LOOSE: { [Enum.Material]: number } = {
	[Enum.Material.Sand] = 1,
	[Enum.Material.Ground] = 0.9,
	[Enum.Material.Mud] = 0.5,
	[Enum.Material.Snow] = 0.8,
	[Enum.Material.Salt] = 0.8,
	[Enum.Material.Sandstone] = 0.5,
	[Enum.Material.Limestone] = 0.4,
	[Enum.Material.Slate] = 0.4,
	[Enum.Material.Pebble] = 0.6,
	[Enum.Material.Rock] = 0.4,
	[Enum.Material.LeafyGrass] = 0.3,
}
-- Floors rough enough for a scuff to throw grit (loose ones too).
local ROUGH: { [Enum.Material]: number } = {
	[Enum.Material.Concrete] = 0.6,
	[Enum.Material.Pavement] = 0.6,
	[Enum.Material.Asphalt] = 0.6,
	[Enum.Material.Cobblestone] = 0.5,
	[Enum.Material.Brick] = 0.5,
	[Enum.Material.Basalt] = 0.5,
	[Enum.Material.CrackedLava] = 0.5,
	[Enum.Material.Wood] = 0.3,
	[Enum.Material.WoodPlanks] = 0.3,
	[Enum.Material.CorrodedMetal] = 0.4,
	[Enum.Material.DiamondPlate] = 0.3,
	[Enum.Material.Granite] = 0.4,
	[Enum.Material.Marble] = 0.2,
	[Enum.Material.Plastic] = 0.25,
	[Enum.Material.SmoothPlastic] = 0.15,
}
local DOWN = Vector3.new(0, -3, 0)

-- SOUND of a step: which Shared/Sounds slot each floor material uses. A
-- material not listed (Plastic, SmoothPlastic, Glass, Neon, Ice...) sounds
-- like a hard floor: FootConcrete. Fabric (rugs, carpets) is muffled: the
-- dirt sound, quieter (FABRIC_VOLUME).
local STEP_SOUND: { [Enum.Material]: string } = {
	[Enum.Material.Ground] = "FootDirt",
	[Enum.Material.Sand] = "FootDirt",
	[Enum.Material.Mud] = "FootDirt",
	[Enum.Material.Snow] = "FootDirt",
	[Enum.Material.Salt] = "FootDirt",
	[Enum.Material.Pebble] = "FootDirt",
	[Enum.Material.Fabric] = "FootDirt",
	[Enum.Material.Grass] = "FootGrass",
	[Enum.Material.LeafyGrass] = "FootGrass",
	[Enum.Material.Wood] = "FootWood",
	[Enum.Material.WoodPlanks] = "FootWood",
	[Enum.Material.Cardboard] = "FootWood",
	[Enum.Material.Metal] = "FootMetal",
	[Enum.Material.CorrodedMetal] = "FootMetal",
	[Enum.Material.DiamondPlate] = "FootMetal",
	[Enum.Material.Foil] = "FootMetal",
}
local DEFAULT_STEP_SOUND = "FootConcrete"
local FABRIC_VOLUME = 0.45
-- Steps are quiet: beyond this (studs) they can't be heard.
local STEP_HEARING = 45
-- Never two step sounds from the same leg closer than this (seconds): a scuff
-- and a landing reported in the same instant make one sound, not two.
local STEP_GAP = 0.12
local lastStep: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Plays the step sound from the leg that landed (3D: it follows the leg).
-- `strength` (about 0.3 a light step → 1.6 a hard sprint stride) sets the volume.
local function playStep(leg: BasePart, material: Enum.Material, strength: number, now: number)
	local last = lastStep[leg]
	if last and now - last < STEP_GAP then
		return
	end
	lastStep[leg] = now
	local sound = SoundController.playAt(
		STEP_SOUND[material] or DEFAULT_STEP_SOUND,
		leg.Position,
		STEP_HEARING,
		leg
	)
	if sound then
		local scale = math.clamp(0.55 + 0.45 * strength, 0.6, 1.3)
		if material == Enum.Material.Fabric then
			scale *= FABRIC_VOLUME
		end
		sound.Volume *= scale
		sound.RollOffMinDistance = 6
	end
end

-- A few emitter sets, reused: a set is taken by one burst and stays busy
-- until its particles are gone (an emitter's colour can't change under live
-- particles, and a burst is placed where its attachment is at the end of the
-- frame). All busy: that step makes no dust (never noticeable).
type FxSet = {
	attachment: Attachment,
	dust: ParticleEmitter,
	grit: ParticleEmitter,
	busyUntil: number,
}
local POOL_MAX = 12
local DUST_LIFE = 0.75 -- (seconds: the longest a particle lives, plus a margin)
local pool: { FxSet } = {}

local function newSet(): FxSet
	local attachment = Instance.new("Attachment")
	attachment.Name = "FootstepFx"
	-- Dust: a low, slow puff that hangs a moment and settles.
	local puff = Instance.new("ParticleEmitter")
	puff.Name = "Dust"
	puff.Texture = DUST_TEXTURE
	puff.Enabled = false
	puff.LightEmission = 0
	puff.LightInfluence = 1
	puff.Lifetime = NumberRange.new(0.4, 0.7)
	puff.Speed = NumberRange.new(1, 2.5)
	puff.SpreadAngle = Vector2.new(70, 70)
	puff.Drag = 5
	puff.Acceleration = Vector3.new(0, -0.5, 0)
	puff.Rotation = NumberRange.new(0, 360)
	puff.RotSpeed = NumberRange.new(-40, 40)
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1.1),
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.3, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	puff.Parent = attachment
	-- Grit: small, fast, flat specks thrown along the floor, dropping at once.
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Grit"
	spray.Texture = DUST_TEXTURE
	spray.Enabled = false
	spray.LightEmission = 0
	spray.LightInfluence = 1
	spray.Lifetime = NumberRange.new(0.25, 0.45)
	spray.Speed = NumberRange.new(4, 8)
	spray.SpreadAngle = Vector2.new(25, 8)
	spray.Drag = 6
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 0.06),
	})
	spray.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	spray.Parent = attachment
	attachment.Parent = Workspace.Terrain
	return { attachment = attachment, dust = puff, grit = spray, busyUntil = 0 }
end

-- A set free for a burst now (busy until its particles are gone), or nil.
local function takeSet(now: number): FxSet?
	for _, set in pool do
		if now >= set.busyUntil and set.attachment.Parent then
			set.busyUntil = now + DUST_LIFE
			return set
		end
	end
	if #pool >= POOL_MAX then
		return nil
	end
	local set = newSet()
	set.busyUntil = now + DUST_LIFE
	table.insert(pool, set)
	return set
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

-- The floor's colour, a bit darker and greyer (dust is never saturated).
local function dustColor(result: RaycastResult): Color3
	local hit = result.Instance
	local color = if hit:IsA("Terrain")
		then hit:GetMaterialColor(result.Material)
		elseif hit:IsA("BasePart") then hit.Color
		else Color3.fromRGB(120, 112, 100)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s * 0.45, math.clamp(v * 0.8, 0.18, 0.75))
end

-- A foot of `model` lands (or drags: `scuff`). `strength` about 0.3 to 1.6.
function Footsteps.step(model: Model, foot: string, strength: number, scuff: boolean)
	local camera = Workspace.CurrentCamera
	local leg = model:FindFirstChild(if foot == "Left" then "Left Leg" else "Right Leg")
	local root = model:FindFirstChild("HumanoidRootPart")
	if
		camera == nil
		or leg == nil
		or not leg:IsA("BasePart")
		or root == nil
		or not root:IsA("BasePart")
	then
		return
	end
	local sole = (leg.CFrame * CFrame.new(0, -0.8, 0)).Position
	if (sole - camera.CFrame.Position).Magnitude > RANGE then
		return
	end
	params.FilterDescendantsInstances = { model }
	local result = Workspace:Raycast(sole + Vector3.new(0, 1, 0), DOWN, params)
	if result == nil then
		return
	end
	local now = os.clock()
	-- The sound first (every floor makes one), within hearing range only.
	if (sole - camera.CFrame.Position).Magnitude <= STEP_HEARING then
		playStep(leg, result.Material, strength, now)
	end
	local loose = LOOSE[result.Material]
	local amount = if scuff then loose or ROUGH[result.Material] else loose
	if amount == nil then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	-- (thrown back from the foot, against the way it goes)
	local back = if flat.Magnitude > 0.5 then -flat.Unit else -root.CFrame.LookVector
	local normal = result.Normal
	local color = ColorSequence.new(dustColor(result))
	if scuff then
		-- Grit sprayed low along the floor, the way the body was going.
		local set = takeSet(now)
		if set then
			local along = if flat.Magnitude > 0.5 then flat.Unit else root.CFrame.LookVector
			set.attachment.WorldCFrame = CFrame.lookAt(result.Position, result.Position + along)
				* CFrame.Angles(-math.rad(80), 0, 0)
			set.grit.Color = color
			set.grit:Emit(math.max(1, math.round(10 * amount * strength)))
		end
	end
	-- Dust: up from the floor, leaning back from the foot.
	local set = takeSet(now)
	if set == nil then
		return
	end
	set.attachment.WorldCFrame = CFrame.lookAt(
		result.Position,
		result.Position + normal + back * 0.8
	) * CFrame.Angles(-math.rad(90), 0, 0)
	set.dust.Color = color
	set.dust:Emit(math.max(1, math.round(4 * amount * strength)))
end

return Footsteps
