--!strict
-- HeadBlast: the head that bursts under the bat (Street Brawler finisher).
--
-- The server sets the attribute "HeadBlown" (= a seed) on the body when the
-- bat lands. Every client then:
--   • hides the head, its face and the head accessories (Gashes hides the
--     head itself, so its cuts never come back over it);
--   • leaves the neck open: torn skin, the flesh, the top of the spine, and
--     blood pumping out of it for a few seconds;
--   • when it happens in front of us (not a body we only see later): the
--     burst itself — pieces of skull, scalp and brain, a cloud and a rain of
--     blood, the hair / hat sent flying, big stains on the floor. The same
--     pieces on every client (the seed).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local KitEffects = require(script.Parent.KitEffects)

local HeadBlast = {}

HeadBlast.ATTRIBUTE = "HeadBlown"

local BLOOD = Color3.fromRGB(92, 12, 10)
local BLOOD_BRIGHT = Color3.fromRGB(128, 16, 14)
local FLESH = Color3.fromRGB(122, 28, 30)
local BONE = Color3.fromRGB(226, 214, 190)
local BRAIN = Color3.fromRGB(190, 124, 124)
local PIECE_LIFETIME = 10 -- seconds the pieces stay on the floor
local PUMP_TIME = 4 -- seconds the neck keeps pumping blood

local done: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- (gore off in Config: no burst, the head stays)
function HeadBlast.isBlown(model: Model): boolean
	return Config.Injuries.SKIN_TEAR and model:GetAttribute(HeadBlast.ATTRIBUTE) ~= nil
end

-- Out of sight for good (Transparency, not LocalTransparencyModifier: the
-- bruise marks of Wounds reset that one).
local function hide(item: Instance)
	if item:IsA("BasePart") or item:IsA("Decal") then
		(item :: any).Transparency = 1
	elseif item:IsA("SurfaceGui") then
		item.Enabled = false
	end
end

-- The head accessories, and everything stuck on the head (bruise marks,
-- glass shards), even what comes later.
local function hideAll(model: Model, head: BasePart)
	for _, accessory in model:GetChildren() do
		if accessory:IsA("Accessory") then
			for _, item in accessory:GetDescendants() do
				hide(item)
			end
		end
	end
	for _, item in head:GetDescendants() do
		hide(item)
	end
	head.DescendantAdded:Connect(hide)
end

local function welded(part: BasePart, to: BasePart, cframe: CFrame, parent: Instance)
	part.CFrame = cframe
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
end

-- What's left on top of the torso. Returns the point the blood comes out of.
local function buildStump(torso: BasePart, skin: Color3, random: Random): Attachment
	local folder = Instance.new("Folder")
	folder.Name = "HeadBlast"
	local top = torso.CFrame * CFrame.new(0, torso.Size.Y / 2, 0)
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis along Y

	-- The open neck: skin around, wet flesh inside.
	local neck = Instance.new("Part")
	neck.Name = "Neck"
	neck.Shape = Enum.PartType.Cylinder
	neck.Size = Vector3.new(0.3, 1.0, 1.0)
	neck.Material = Enum.Material.SmoothPlastic
	neck.Color = skin
	welded(neck, torso, top * CFrame.new(0, 0.1, 0) * upright, folder)
	local flesh = Instance.new("Part")
	flesh.Name = "Flesh"
	flesh.Shape = Enum.PartType.Cylinder
	flesh.Size = Vector3.new(0.32, 0.8, 0.8)
	flesh.Material = Enum.Material.SmoothPlastic
	flesh.Color = FLESH
	flesh.Reflectance = 0.12 -- wet
	welded(flesh, torso, top * CFrame.new(0, 0.12, 0) * upright, folder)
	-- The top of the spine, a bit toward the back.
	local spine = Instance.new("Part")
	spine.Name = "Spine"
	spine.Shape = Enum.PartType.Cylinder
	spine.Size = Vector3.new(0.42, 0.24, 0.24)
	spine.Material = Enum.Material.SmoothPlastic
	spine.Color = BONE
	welded(spine, torso, top * CFrame.new(0, 0.3, 0.16) * upright, folder)
	-- Torn skin all around the edge, and shreds of flesh on top.
	for index = 1, 9 do
		local angle = index / 9 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local flap = Instance.new("Part")
		flap.Name = "Flap"
		flap.Size = Vector3.new(random:NextNumber(0.2, 0.32), random:NextNumber(0.14, 0.3), 0.04)
		flap.Material = Enum.Material.SmoothPlastic
		flap.Color = if index % 3 == 0 then FLESH else skin
		local around = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -0.47)
		welded(
			flap,
			torso,
			top
				* CFrame.new(0, 0.28, 0)
				* around
				* CFrame.Angles(math.rad(random:NextNumber(-35, -10)), 0, 0),
			folder
		)
	end
	for _ = 1, 6 do
		local shred = Instance.new("Part")
		shred.Name = "Shred"
		shred.Size = Vector3.new(
			random:NextNumber(0.08, 0.18),
			random:NextNumber(0.05, 0.12),
			random:NextNumber(0.08, 0.18)
		)
		shred.Material = Enum.Material.SmoothPlastic
		shred.Color = if random:NextNumber() < 0.5 then FLESH else BLOOD
		shred.Reflectance = 0.1
		welded(
			shred,
			torso,
			top
				* CFrame.new(random:NextNumber(-0.3, 0.3), 0.3, random:NextNumber(-0.3, 0.3))
				* CFrame.Angles(random:NextNumber(0, 6.3), random:NextNumber(0, 6.3), 0),
			folder
		)
	end
	folder.Parent = torso

	local mouth = Instance.new("Attachment")
	mouth.Name = "HeadBlastBlood"
	mouth.Position = Vector3.new(0, torso.Size.Y / 2 + 0.3, 0)
	mouth.Parent = torso
	return mouth
end

local function bloodEmitter(parent: Attachment): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Blood"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(BLOOD_BRIGHT, BLOOD)
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	emitter.Lifetime = NumberRange.new(0.45, 0.8)
	emitter.Speed = NumberRange.new(5, 9)
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.Acceleration = Vector3.new(0, -45, 0) -- it falls (studs/s²)
	emitter.Drag = 1
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

-- The neck pumps blood (the heart still beats a few times), then drips.
local function pump(model: Model, mouth: Attachment)
	local emitter = bloodEmitter(mouth)
	task.spawn(function()
		local start = os.clock()
		while mouth.Parent and os.clock() - start < PUMP_TIME do
			local fade = 1 - (os.clock() - start) / PUMP_TIME
			emitter.Rate = 90 * fade
			task.wait(0.22)
			emitter.Rate = 18 * fade
			task.wait(0.38)
			-- where it lands
			if model.Parent then
				KitEffects.stain(
					mouth.WorldPosition + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5),
					0.5 + fade * 0.7
				)
			end
		end
		emitter.Rate = 0
		Debris:AddItem(emitter, 1)
	end)
end

-- One flying piece (collides with the floor, gone after a while).
local function chunk(
	at: Vector3,
	size: Vector3,
	color: Color3,
	velocity: Vector3,
	random: Random,
	shape: Enum.PartType?
)
	local piece = Instance.new("Part")
	piece.Name = "Debris"
	if shape then
		piece.Shape = shape
	end
	piece.Size = size
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Reflectance = if color == BRAIN or color == FLESH then 0.1 else 0
	piece.CanCollide = true
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CFrame = CFrame.new(at)
		* CFrame.Angles(random:NextNumber(0, 6.3), random:NextNumber(0, 6.3), 0)
	piece.AssemblyLinearVelocity = velocity
	piece.AssemblyAngularVelocity = random:NextUnitVector() * random:NextNumber(8, 25)
	piece.Parent = workspace
	Debris:AddItem(piece, PIECE_LIFETIME)
end

-- Outward (mostly sideways, a bit up: the bat came from above).
local function outward(random: Random, up: number, speed: number): Vector3
	local angle = random:NextNumber(0, math.pi * 2)
	local flat = Vector3.new(math.cos(angle), 0, math.sin(angle))
	return (flat + Vector3.new(0, random:NextNumber(up * 0.4, up), 0)).Unit
		* speed
		* random:NextNumber(0.45, 1)
end

local function burst(model: Model, head: BasePart, random: Random)
	local at = head.Position
	local skin = head.Color
	-- Skull: scalp outside, bone inside.
	for index = 1, 16 do
		local size = random:NextNumber(0.16, 0.34)
		chunk(
			at,
			Vector3.new(size, size * random:NextNumber(0.3, 0.6), size * random:NextNumber(0.6, 1)),
			if index % 3 == 0 then BONE else skin,
			outward(random, 1.4, 22),
			random
		)
	end
	-- Brain.
	for _ = 1, 12 do
		local size = random:NextNumber(0.12, 0.26)
		chunk(
			at,
			Vector3.new(size, size * 0.8, size),
			BRAIN,
			outward(random, 1.1, 16),
			random,
			if random:NextNumber() < 0.5 then Enum.PartType.Ball else nil
		)
	end
	-- Drops of blood, fast.
	for _ = 1, 36 do
		local size = random:NextNumber(0.07, 0.14)
		chunk(
			at,
			Vector3.new(size, size, size),
			if random:NextNumber() < 0.5 then BLOOD else BLOOD_BRIGHT,
			outward(random, 1.6, 30),
			random,
			Enum.PartType.Ball
		)
	end
	-- The hair / hat: sent flying.
	for _, accessory in model:GetChildren() do
		local handle = if accessory:IsA("Accessory")
			then accessory:FindFirstChild("Handle")
			else nil
		if handle and handle:IsA("BasePart") then
			local copy = handle:Clone()
			for _, item in copy:GetDescendants() do
				if
					item:IsA("JointInstance")
					or item:IsA("WeldConstraint")
					or item:IsA("Attachment")
				then
					item:Destroy()
				end
			end
			copy.Anchored = false
			copy.CanCollide = true
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Massless = false
			copy.CFrame = handle.CFrame
			copy.AssemblyLinearVelocity = outward(random, 2.2, 18)
			copy.AssemblyAngularVelocity = random:NextUnitVector() * 12
			copy.Parent = workspace
			Debris:AddItem(copy, PIECE_LIFETIME)
		end
	end
	-- A red cloud for a moment.
	local point = Instance.new("Attachment")
	point.WorldPosition = at
	point.Parent = workspace.Terrain
	local cloud = bloodEmitter(point)
	cloud.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1.8),
	})
	cloud.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	cloud.Speed = NumberRange.new(4, 12)
	cloud.SpreadAngle = Vector2.new(180, 180)
	cloud.Acceleration = Vector3.new(0, -20, 0)
	cloud.Drag = 4
	cloud.Lifetime = NumberRange.new(0.4, 0.9)
	cloud:Emit(45)
	Debris:AddItem(point, 1.5)
	-- The floor around it.
	KitEffects.stain(at, 3.4)
	for _ = 1, 7 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(1.2, 3.2)
		KitEffects.stain(
			at + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance),
			random:NextNumber(0.5, 1.2)
		)
	end
end

-- The head of `model` is gone. `live`: it's happening now (the burst), not
-- a body we only see now (streamed in late): then just what's left.
function HeadBlast.apply(model: Model, live: boolean)
	local seed = model:GetAttribute(HeadBlast.ATTRIBUTE)
	if typeof(seed) ~= "number" or done[model] or not HeadBlast.isBlown(model) then
		return
	end
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("Torso")
	if head == nil or not head:IsA("BasePart") or torso == nil or not torso:IsA("BasePart") then
		return
	end
	done[model] = true
	local random = Random.new(seed)
	if live then
		burst(model, head, random)
	end
	hideAll(model, head)
	local mouth = buildStump(torso, head.Color, random)
	if live then
		pump(model, mouth)
	end
end

return table.freeze(HeadBlast)
