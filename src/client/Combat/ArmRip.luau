--!strict
-- ArmRip: the Bouncer's finisher (Shared/Finishers "ArmRip"): the right arm
-- pulled off at the shoulder.
--
-- The server, at the kill: takes the arm off the shoulder (it stays a part
-- of the body, its sleeve on), welds it in his right fist, and sets the
-- attribute "ArmTorn" (= a seed) on the body. Every client then (Gashes
-- watches the attribute):
--   • on the torso's right side: the open socket, the real shoulder blade's
--     cup and the end of the collarbone, the torn rotator cuff and pectoral
--     round it, the fat and skin torn around;
--   • on the arm's top: the real muscles of the upper arm (Z-Anatomy) torn
--     at different heights round the real humerus' head, the yellow fat under
--     the skin, the skin torn over the edges;
--   • when it happens in front of us (not a body we only see later): a burst
--     of blood, the shoulder pumping in spurts, a big pool spreading under
--     it (a litre and more: Config.Blood.FINISHER_POOLS.SHOULDER), the arm
--     dripping in his hand, then a smaller pool of its own where it lies
--     (TORN_ARM); a body we only see later: those pools already there.
-- Pieces from WoundKit (GoreKit "Shoulder" / "ArmEnd"); simpler ones drawn
-- here without them (an older kit).
--
--   ArmRip.apply(model, live)       draws the wounds (once per body)
--   ArmRip.pop(victim)              the shoulder coming out (event "Pop")
--   ArmRip.boneTaken(model)         its bone pulled out ("BoneTaken"): hidden
--   ArmRip.thrown(attacker, anchor) he throws it down (event "Throw"): it
--                                   lands by the body, a wet thud, a splash

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Finishers = require(ReplicatedStorage.Shared.Finishers)
local GoreKit = require(script.Parent.GoreKit)
local Blood = require(script.Parent.Blood)
local BloodGush = require(script.Parent.BloodGush)
local HeadBlast = require(script.Parent.HeadBlast)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local ArmRip = {}

ArmRip.ATTRIBUTE = "ArmTorn"

local BLOOD = Config.Blood.PALETTE.VENOUS
local BLOOD_WET = Config.Blood.PALETTE.ARTERIAL
local FLESH = Color3.fromRGB(122, 28, 30)
local FLESH_DARK = Color3.fromRGB(80, 14, 16)
local BONE = Color3.fromRGB(226, 214, 190)
local TENDON = Color3.fromRGB(214, 200, 182)
-- The real muscles' cut (Z-Anatomy): raw red, a darker one beside it; the fat
-- under the skin: yellow.
local MUSCLE = Color3.fromRGB(150, 32, 34)
local MUSCLE_DARK = Color3.fromRGB(112, 22, 26)
local FAT = Color3.fromRGB(222, 190, 112)
local DRIP_TIME = 10 -- seconds the arm drips
local POOLS = Config.Blood.FINISHER_POOLS
-- (when the arm, thrown down, lies on the floor: the event "Throw" comes
-- 1.27 s after "Tear", then it falls)
local ARM_ON_FLOOR = 1.7
-- The socket, torso space (its right side), facing out (+X).
local SOCKET = CFrame.new(1.05, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0)

local done: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- (gore off in Config: nothing drawn, the arm just comes off)
local function enabled(model: Model): boolean
	return Config.Injuries.SKIN_TEAR and model:GetAttribute(ArmRip.ATTRIBUTE) ~= nil
end

local function emitter(parent: Attachment, rate: number): ParticleEmitter
	local blood = Instance.new("ParticleEmitter")
	blood.Name = "Blood"
	blood.Texture = "rbxasset://textures/particles/smoke_main.dds"
	blood.Color = ColorSequence.new(BLOOD_WET, BLOOD)
	blood.LightEmission = 0
	blood.LightInfluence = 1
	blood.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.85, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	blood.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0.07),
	})
	blood.Lifetime = NumberRange.new(0.4, 0.8)
	blood.Speed = NumberRange.new(3, 8)
	blood.SpreadAngle = Vector2.new(18, 18)
	blood.Acceleration = Vector3.new(0, -60, 0)
	blood.Drag = 0.5
	blood.EmissionDirection = Enum.NormalId.Front
	blood.Rate = rate
	Blood.droplets(blood, "drops") -- (real drops when the picture is uploaded)
	blood.Parent = parent
	return blood
end

-- Each layer's colour and shine. `skin` = the body's own skin colour.
local function painter(skin: Color3): (layer: string) -> (Color3, number)
	return function(layer: string): (Color3, number)
		if layer == "Skin" then
			return skin, 0
		elseif layer == "Bone" then
			return BONE, 0.05
		elseif layer == "Tendon" then
			return TENDON, 0.12
		elseif layer == "FleshDark" then
			return FLESH_DARK, 0.18
		elseif layer == "Muscle" then
			return MUSCLE, 0.16
		elseif layer == "MuscleDark" then
			return MUSCLE_DARK, 0.16
		elseif layer == "Fat" then
			return FAT, 0.08
		end
		return FLESH, 0.14
	end
end

local function weldTo(part: BasePart, piece: BasePart, folder: Instance)
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = folder
end

local function simplePart(name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Reflectance = if color == FLESH then 0.14 else 0
	return part
end

-- The kit's piece `name` (in `part`'s own space) on `part`, or simple
-- shapes without it.
local function dress(part: BasePart, name: string, skin: Color3, random: Random)
	local folder = Instance.new("Folder")
	folder.Name = "ArmRip"
	local pieces = GoreKit.get()
	local piece = if pieces then pieces[name] else nil
	if piece then
		weldTo(part, GoreKit.spawn(piece, part.CFrame, painter(skin)), folder)
	elseif name == "Shoulder" then
		-- A raw round wound on the side, the bone in it, skin torn around.
		local at = part.CFrame * SOCKET
		local wound =
			simplePart("Wound", Enum.PartType.Cylinder, Vector3.new(0.06, 0.88, 0.84), FLESH)
		wound.CFrame = at * CFrame.Angles(0, math.pi / 2, 0)
		weldTo(part, wound, folder)
		local cup = simplePart("Bone", Enum.PartType.Ball, Vector3.new(0.12, 0.32, 0.26), BONE)
		cup.CFrame = at * CFrame.new(0, 0.05, -0.04)
		weldTo(part, cup, folder)
		for index = 1, 8 do
			local angle = index / 8 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
			local flap = simplePart(
				"Flap",
				Enum.PartType.Block,
				Vector3.new(random:NextNumber(0.14, 0.24), random:NextNumber(0.08, 0.14), 0.03),
				skin
			)
			flap.CFrame = at
				* CFrame.Angles(0, 0, angle)
				* CFrame.new(0, 0.46, -0.03)
				* CFrame.Angles(math.rad(random:NextNumber(-60, -25)), 0, 0)
			weldTo(part, flap, folder)
		end
	else
		-- The arm's end: raw on top, the bone's ball out of it.
		local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
		local raw = simplePart("Raw", Enum.PartType.Block, Vector3.new(1.02, 0.12, 1.02), FLESH)
		raw.CFrame = top
		weldTo(part, raw, folder)
		local shaft = simplePart("Bone", Enum.PartType.Cylinder, Vector3.new(0.5, 0.26, 0.26), BONE)
		shaft.CFrame = top * CFrame.new(-0.1, 0.18, 0.03) * CFrame.Angles(0, 0, math.pi / 2)
		weldTo(part, shaft, folder)
		local ball = simplePart("Bone", Enum.PartType.Ball, Vector3.new(0.42, 0.42, 0.42), BONE)
		ball.CFrame = top * CFrame.new(-0.12, 0.36, 0.04)
		weldTo(part, ball, folder)
	end
	folder.Parent = part
end

-- The arm drips from its torn end (in his hand, then on the floor).
local function drip(arm: BasePart)
	local point = Instance.new("Attachment")
	point.Name = "ArmRipDrip"
	point.Position = Vector3.new(0, arm.Size.Y / 2 + 0.05, 0)
	point.Parent = arm
	local drops = emitter(point, 26)
	drops.EmissionDirection = Enum.NormalId.Top
	drops.Speed = NumberRange.new(0.5, 2)
	drops.SpreadAngle = Vector2.new(40, 40)
	Blood.dripEmitter(drops) -- (it only drips: real drops fall slowly)
	-- (and real drops falling from it: they land, they make marks, a pool
	-- where it lies)
	task.spawn(function()
		local random = Random.new()
		local stop = os.clock() + DRIP_TIME
		while os.clock() < stop and point.Parent and arm.Parent do
			Blood.drop(
				point.WorldPosition,
				arm.AssemblyLinearVelocity * 0.5,
				random:NextNumber(0.05, 0.1),
				random,
				Blood.passiveScale(), -- (a drip: it falls slowly, lands round)
				{ passive = true }
			)
			task.wait(random:NextNumber(0.12, 0.3))
		end
	end)
	task.delay(DRIP_TIME, function()
		drops.Rate = 0
		Debris:AddItem(point, 1.5)
	end)
end

-- The arm of `model` is off. `live`: it's happening now, not a body we only
-- see now (streamed in late): then just the wounds.
function ArmRip.apply(model: Model, live: boolean)
	local seed = model:GetAttribute(ArmRip.ATTRIBUTE)
	if typeof(seed) ~= "number" or done[model] or not enabled(model) then
		return
	end
	local torso = model:FindFirstChild("Torso")
	local arm = model:FindFirstChild("Right Arm")
	if torso == nil or not torso:IsA("BasePart") or arm == nil or not arm:IsA("BasePart") then
		return
	end
	done[model] = true
	local random = Random.new(seed)
	local skin = arm.Color
	dress(torso, "Shoulder", skin, random)
	dress(arm, "ArmEnd", skin, random)
	ArmRip.boneTaken(model) -- (seen late: already taken)
	-- the arm's torn end, in its space
	local armEnd = Vector3.new(0, arm.Size.Y / 2 + 0.05, 0)
	if not live then
		-- (a body we only see now, or its frozen copy: the pools are there)
		BloodGush.lay(torso, SOCKET.Position, POOLS.SHOULDER, seed + 101)
		BloodGush.lay(arm, armEnd, POOLS.TORN_ARM, seed + 102)
	end
	if live then
		SoundController.play("ArmTear", model)
		-- the artery under the arm (axillary) torn: spurting out of the
		-- socket, running down the side; the arm's own end spurts in his hand
		BloodGush.torso(model, SOCKET.Position, Vector3.new(1, 0.1, -0.2), seed, 12)
		local top = Vector3.new(0, arm.Size.Y / 2 + 0.05, 0)
		BloodGush.artery(arm, CFrame.lookAt(top, top + Vector3.new(0, 1, 0)), {
			seconds = 2.5,
			beat = 0.4,
			speed = 6,
			size = 0.1,
			pool = 0,
			seed = seed + 3,
			ignore = { model :: Instance },
		})
		drip(arm)
		-- the big pool out of the shoulder, under the body; the arm's own
		-- smaller one once it lies on the floor (in his hand it is moving or
		-- too high: no pool there, its drops fall)
		BloodGush.stump(torso, SOCKET.Position, POOLS.SHOULDER, seed + 101, {
			ignore = { model :: Instance },
		})
		BloodGush.stump(arm, armEnd, POOLS.TORN_ARM, seed + 102, {
			ignore = { model :: Instance },
			delay = ARM_ON_FLOOR,
		})
	end
end

-- Someone pulled the bone out of the arm on the floor ("BoneTaken", the
-- server; Shared/Weapons "Bone"): only the raw end is left, hollow.
function ArmRip.boneTaken(model: Model)
	if model:GetAttribute("BoneTaken") ~= true then
		return
	end
	local arm = model:FindFirstChild("Right Arm")
	local folder = if arm then arm:FindFirstChild("ArmRip") else nil
	if folder == nil then
		return
	end
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") and (item.Name == "Gore_ArmEnd_Bone" or item.Name == "Bone") then
			item.Transparency = 1
		end
	end
end

-- The shoulder comes out of its socket (still attached): a crack, a spit
-- of blood through the skin.
function ArmRip.pop(victim: Model)
	local torso = victim:FindFirstChild("Torso")
	SoundController.play("ShoulderPop", victim)
	if torso == nil or not torso:IsA("BasePart") or not Config.Injuries.SKIN_TEAR then
		return
	end
	local point = Instance.new("Attachment")
	point.CFrame = SOCKET
	point.Parent = torso
	local spit = emitter(point, 0)
	spit.Speed = NumberRange.new(2, 5)
	spit:Emit(14)
	Debris:AddItem(point, 1.5)
	Blood.landings(
		point.WorldPosition,
		point.WorldCFrame.LookVector,
		18,
		NumberRange.new(2, 5),
		2,
		NumberRange.new(0.04, 0.07)
	)
end

-- He throws it down (the server lets go of it from Finishers.ARM_THROW_FROM):
-- when it reaches the floor, a heavy wet thud and a splash.
function ArmRip.thrown(attacker: Model, anchor: CFrame)
	SoundController.play("Swing", attacker)
	local from = (anchor * Finishers.ARM_THROW_FROM).Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker }
	local floor = workspace:Raycast(from, Vector3.new(0, -20, 0), params)
	local landing = if floor then floor.Position else from - Vector3.new(0, 2.5, 0)
	local height = math.max(0, from.Y - landing.Y - 0.5)
	local fall = math.sqrt(2 * height / workspace.Gravity) + 0.05
	task.delay(fall, function()
		SoundController.play("LimbDrop", attacker)
		if Config.Injuries.SKIN_TEAR then
			HeadBlast.splash(landing, 1.6, math.floor(landing.X * 13 + landing.Z * 7))
		end
	end)
end

return table.freeze(ArmRip)
