--!strict
-- TrainGore: what is left of someone the train hit.
--
-- The SERVER (Server/Systems/Train) kills the victim and tears the body apart itself: it
-- removes the joints of the head, the arms and the legs and throws every piece with the
-- train (the server simulates the pieces, so every player sees them land at the same place).
-- Then it sends Remotes.TrainHit(victim, impact, velocity, seed) and every client calls
--
--   TrainGore.play(victim, impact, velocity, seed)
--
-- which adds what only the screen needs (the same on every client: random numbers from `seed`):
--   • a spray of blood at the impact, thrown with the train;
--   • torn ends: a raw red cap with the white of the bone on every torn limb, and on the
--     torso where each limb was;
--   • blood spurting from every torn end for a few seconds, weaker and weaker;
--   • blood on the floor: a big splash where it hit, a pool spreading under the torso, a
--     smaller splash under each limb once it lands.
-- Everything is stuck to the body parts, so it goes away with the body when the player
-- respawns. Gore switched off in Config (Injuries.SKIN_TEAR = false): no blood, the limbs
-- still come off.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HeadBlast = require(script.Parent.HeadBlast)

local TrainGore = {}

local BLOOD = Color3.fromRGB(78, 6, 6)
local BLOOD_WET = Color3.fromRGB(110, 8, 8)
local FLESH = Color3.fromRGB(128, 26, 28)
local BONE = Color3.fromRGB(226, 216, 196)
local SPURT_TIME = 3.5 -- seconds the torn ends keep bleeding
local CAP_THICKNESS = 0.12

-- Where a torn end is on a body part, in that part's own space: the centre of the face and
-- the direction it faces (`axis`), and the size of the cap.
type Wound = { position: Vector3, axis: Vector3, size: number }

-- The torn end of each R6 limb (where it was joined to the torso).
local LIMB_WOUNDS: { [string]: Wound } = {
	Head = { position = Vector3.new(0, -0.5, 0), axis = Vector3.new(0, -1, 0), size = 0.75 },
	["Right Arm"] = { position = Vector3.new(0, 1, 0), axis = Vector3.new(0, 1, 0), size = 0.9 },
	["Left Arm"] = { position = Vector3.new(0, 1, 0), axis = Vector3.new(0, 1, 0), size = 0.9 },
	["Right Leg"] = { position = Vector3.new(0, 1, 0), axis = Vector3.new(0, 1, 0), size = 0.9 },
	["Left Leg"] = { position = Vector3.new(0, 1, 0), axis = Vector3.new(0, 1, 0), size = 0.9 },
}
-- The holes on the torso (2 x 2 x 1), keyed by the limb that was there.
local TORSO_WOUNDS: { [string]: Wound } = {
	Head = { position = Vector3.new(0, 1, 0), axis = Vector3.new(0, 1, 0), size = 0.7 },
	["Right Arm"] = { position = Vector3.new(1, 0.5, 0), axis = Vector3.new(1, 0, 0), size = 0.85 },
	["Left Arm"] = { position = Vector3.new(-1, 0.5, 0), axis = Vector3.new(-1, 0, 0), size = 0.85 },
	["Right Leg"] = {
		position = Vector3.new(0.5, -1, 0),
		axis = Vector3.new(0, -1, 0),
		size = 0.85,
	},
	["Left Leg"] = {
		position = Vector3.new(-0.5, -1, 0),
		axis = Vector3.new(0, -1, 0),
		size = 0.85,
	},
}

-- A small part stuck (welded) to `body`, at `offset` in its space, that never collides.
local function stuck(body: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0.08 -- wet
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = body.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = body
end

-- The torn end on `body`: a raw cap and the bone in the middle (a cylinder's length is its X
-- axis: turned so X points along the wound's axis). Returns the attachment the blood comes
-- out of.
local function tornEnd(body: BasePart, wound: Wound, random: Random): Attachment
	local axis = wound.axis
	-- a frame whose X axis is `axis`
	local helper = if math.abs(axis.Y) > 0.9 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local frame = CFrame.fromMatrix(wound.position, axis, axis:Cross(helper).Unit)
	local jag = random:NextNumber(0.9, 1.05)
	stuck(
		body,
		"TornFlesh",
		Vector3.new(CAP_THICKNESS, wound.size * jag, wound.size * jag),
		FLESH,
		frame * CFrame.new(CAP_THICKNESS / 2 - 0.02, 0, 0)
	)
	stuck(
		body,
		"TornBone",
		Vector3.new(0.22, wound.size * 0.32, wound.size * 0.32),
		BONE,
		frame * CFrame.new(0.1, random:NextNumber(-0.05, 0.05), random:NextNumber(-0.05, 0.05))
	)
	local mouth = Instance.new("Attachment")
	mouth.Name = "TornBlood"
	mouth.CFrame = CFrame.lookAt(wound.position, wound.position + axis)
		* CFrame.Angles(math.rad(-90), 0, 0) -- (an emitter shoots along the attachment's +Y)
	mouth.Parent = body
	return mouth
end

-- Blood spurting out of `mouth` for SPURT_TIME seconds, weaker and weaker.
local function bleed(mouth: Attachment, strength: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Blood"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(BLOOD_WET, BLOOD)
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.85, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new(0.16, 0.08)
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(4, 8)
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.Acceleration = Vector3.new(0, -60, 0)
	emitter.Drag = 0.6
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = mouth
	task.spawn(function()
		local start = os.clock()
		while mouth.Parent and os.clock() - start < SPURT_TIME do
			local fade = 1 - (os.clock() - start) / SPURT_TIME
			emitter.Rate = 110 * fade * strength -- a spurt
			task.wait(0.12)
			emitter.Rate = 12 * fade * strength -- between two
			task.wait(0.38)
		end
		emitter.Rate = 0
	end)
end

-- The spray at the impact: a burst of blood thrown with the train.
local function spray(impact: Vector3, velocity: Vector3, random: Random)
	local attachment = Instance.new("Attachment")
	attachment.Name = "TrainBloodSpray"
	local direction = if velocity.Magnitude > 1 then velocity.Unit else Vector3.new(0, 1, 0)
	attachment.CFrame = CFrame.lookAt(impact, impact + direction)
		* CFrame.Angles(math.rad(-90), 0, 0)
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(BLOOD_WET, BLOOD)
	emitter.LightInfluence = 1
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Size = NumberSequence.new(0.35, 0.15)
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(14, 34)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Acceleration = Vector3.new(0, -70, 0)
	emitter.Drag = 1.2
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(random:NextInteger(70, 100))
	Debris:AddItem(attachment, 2)
end

function TrainGore.play(victim: Model, impact: Vector3, velocity: Vector3, seed: number)
	if not Config.Injuries.SKIN_TEAR then
		return -- gore switched off
	end
	local random = Random.new(seed)
	spray(impact, velocity, random)
	HeadBlast.splash(impact, 3.4, seed)

	local torso = victim:FindFirstChild("Torso")
	for limbName, wound in LIMB_WOUNDS do
		local limb = victim:FindFirstChild(limbName)
		if limb and limb:IsA("BasePart") then
			bleed(tornEnd(limb, wound, random), 0.6)
			-- a smaller splash where the limb lands
			local splashSeed = random:NextInteger(1, 1_000_000)
			task.delay(random:NextNumber(1.2, 1.8), function()
				if limb.Parent then
					HeadBlast.splash(limb.Position, random:NextNumber(0.9, 1.4), splashSeed)
				end
			end)
		end
		if torso and torso:IsA("BasePart") then
			bleed(tornEnd(torso, TORSO_WOUNDS[limbName], random), 1)
		end
	end
	-- the pool under the torso, once it has landed
	if torso and torso:IsA("BasePart") then
		task.delay(1.6, function()
			if torso.Parent then
				HeadBlast.pool(torso.Position, 4.5, 5, seed + 1)
			end
		end)
	end
end

return table.freeze(TrainGore)
