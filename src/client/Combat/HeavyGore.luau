--!strict
-- HeavyGore: the gore of the very strong hits (Shared/Util/HeavyGore; the
-- server decides, Server/Combat/HeavyGore), drawn here on every client:
--   • a limb torn off ("LimbTorn_<Limb>"): the open socket on the torso
--     (the real shoulder blade / hip bone, torn muscles, skin), and on the
--     limb lying there (its own model, tag HeavyGore.TAG) its torn end (the
--     real muscles' cut, the bone's head out of it);
--   • an open fracture ("Fracture_<Limb>"): the real forearm / shin bones
--     snapped, out through the torn skin of the forearm / shin;
--   • teeth knocked out ("TeethOut"): they fly out of the mouth with blood
--     (when it happens in front of us only);
--   • a broken jaw ("JawBroken"): the mouth torn open, crooked, teeth
--     missing, blood over the chin.
-- Pieces from WoundKit (GoreKit); simpler ones drawn here without them (an
-- older kit). Everything is welded to the body's parts: it goes with them.
--
--   HeavyGore.watch(model)   follow a fighter's (or a body's) attributes
--   HeavyGore.start()        draw the torn limbs lying around

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GoreShapes = require(ReplicatedStorage.Shared.GoreShapes)
local HeavyGoreUtil = require(ReplicatedStorage.Shared.Util.HeavyGore)
local Blood = require(script.Parent.Blood)
local BloodGush = require(script.Parent.BloodGush)
local GoreKit = require(script.Parent.GoreKit)
local HeadBlast = require(script.Parent.HeadBlast)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local HeavyGore = {}

local BLOOD = Color3.fromRGB(78, 6, 6)
local BLOOD_WET = Color3.fromRGB(104, 8, 8)
local FLESH = Color3.fromRGB(122, 28, 30)
local FLESH_DARK = Color3.fromRGB(70, 10, 12)
local BONE = Color3.fromRGB(226, 214, 190)
local TENDON = Color3.fromRGB(214, 200, 182)
local MUSCLE = Color3.fromRGB(150, 32, 34)
local MUSCLE_DARK = Color3.fromRGB(112, 22, 26)
local FAT = Color3.fromRGB(222, 190, 112)
local TOOTH = Color3.fromRGB(236, 228, 206)
local LIVE_TIME = 1.5 -- seconds: a torn limb this new is happening now
local DRIP_TIME = 8

-- Where each torso socket is (torso space), facing out of it.
local SOCKETS: { [string]: CFrame } = {
	RightArm = CFrame.lookAt(Vector3.new(1.02, 0.5, 0), Vector3.new(2, 0.5, 0)),
	LeftArm = CFrame.lookAt(Vector3.new(-1.02, 0.5, 0), Vector3.new(-2, 0.5, 0)),
	RightLeg = CFrame.lookAt(Vector3.new(0.5, -1.02, 0), Vector3.new(0.5, -2, 0), Vector3.zAxis),
	LeftLeg = CFrame.lookAt(Vector3.new(-0.5, -1.02, 0), Vector3.new(-0.5, -2, 0), Vector3.zAxis),
}
-- An open fracture (limb space): where the bone comes out of the front.
local FRACTURE_AT = { arm = Vector3.new(0, -0.35, -0.5), leg = Vector3.new(0, -0.4, -0.5) }

local function enabled(): boolean
	return Config.Injuries.SKIN_TEAR and Config.HeavyGore.ENABLED
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
			return FLESH_DARK, 0.2
		elseif layer == "Muscle" then
			return MUSCLE, 0.16
		elseif layer == "MuscleDark" then
			return MUSCLE_DARK, 0.16
		elseif layer == "Fat" then
			return FAT, 0.08
		elseif layer == "Blood" then
			return BLOOD, 0.25
		elseif layer == "Tooth" then
			return TOOTH, 0.12
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
	part.Reflectance = if color == BONE or color == TOOTH then 0.05 else 0.15
	return part
end

-- A raw round wound at `at` (part space, facing out along its LookVector),
-- a bone sticking out of it: drawn without the kit.
local function simpleWound(
	part: BasePart,
	at: CFrame,
	radius: number,
	bone: Vector3,
	folder: Instance
)
	local world = part.CFrame * at
	local raw =
		simplePart("Raw", Enum.PartType.Cylinder, Vector3.new(0.05, radius * 2, radius * 2), FLESH)
	raw.CFrame = world * CFrame.Angles(0, math.pi / 2, 0)
	weldTo(part, raw, folder)
	local dark = simplePart(
		"Raw",
		Enum.PartType.Cylinder,
		Vector3.new(0.06, radius * 1.3, radius * 1.3),
		FLESH_DARK
	)
	dark.CFrame = world * CFrame.Angles(0, math.pi / 2, 0)
	weldTo(part, dark, folder)
	local shaft = simplePart("Bone", Enum.PartType.Block, bone, BONE)
	shaft.CFrame = world * CFrame.new(0, 0, -bone.Z / 2 + 0.05) * CFrame.Angles(math.rad(-25), 0, 0)
	weldTo(part, shaft, folder)
end

-- The kit's piece `name` (in `part`'s own space) on `part`, or `fallback`
-- without it. Once: the folder `tag` on the part says it's there.
local function dress(
	part: BasePart,
	name: string,
	tag: string,
	skin: Color3,
	fallback: (Instance) -> ()
)
	if part:FindFirstChild(tag) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = tag
	local pieces = GoreKit.get()
	local piece = if pieces then pieces[name] else nil
	if piece then
		weldTo(part, GoreKit.spawn(piece, part.CFrame, painter(skin)), folder)
	else
		fallback(folder)
	end
	folder.Parent = part
end

-- Blood dripping from `local` (part space) for a while.
local function drip(part: BasePart, at: Vector3)
	local point = Instance.new("Attachment")
	point.Name = "HeavyGoreDrip"
	point.Position = at
	point.Parent = part
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = "rbxasset://textures/particles/smoke_main.dds"
	drops.Color = ColorSequence.new(BLOOD_WET, BLOOD)
	drops.LightEmission = 0
	drops.LightInfluence = 1
	drops.Size = NumberSequence.new(0.1, 0.05)
	drops.Lifetime = NumberRange.new(0.4, 0.8)
	drops.Speed = NumberRange.new(0.5, 2)
	drops.SpreadAngle = Vector2.new(40, 40)
	drops.Acceleration = Vector3.new(0, -60, 0)
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.Rate = 22
	drops.Parent = point
	task.delay(DRIP_TIME, function()
		drops.Rate = 0
		Debris:AddItem(point, 1.5)
	end)
end

------------------------------------------------------------------------------
-- A limb torn off: the socket on the torso
------------------------------------------------------------------------------

local function tornLimb(model: Model, key: string, seed: number, live: boolean)
	local limb = HeavyGoreUtil.LIMBS[key]
	local torso = model:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	local socket = SOCKETS[key]
	local tag = "HeavyGore_" .. limb.stump
	local fresh = torso:FindFirstChild(tag) == nil
	dress(torso, limb.stump, tag, torso.Color, function(folder: Instance)
		simpleWound(torso, socket, 0.45, Vector3.new(0.2, 0.2, 0.25), folder)
	end)
	if live and fresh then
		SoundController.play("ArmTear", model)
		-- the artery of the arm / the thigh torn: spurting, running down
		local direction = socket.LookVector + Vector3.new(0, if limb.arm then 0.1 else 0.3, -0.2)
		BloodGush.torso(model, socket.Position, direction, seed, if limb.arm then 11 else 7)
	end
end

------------------------------------------------------------------------------
-- An open fracture
------------------------------------------------------------------------------

local function fracture(model: Model, key: string, seed: number, live: boolean)
	local limb = HeavyGoreUtil.LIMBS[key]
	local part = model:FindFirstChild(limb.part)
	if part == nil or not part:IsA("BasePart") then
		return
	end
	local tag = "HeavyGore_" .. limb.fracture
	local fresh = part:FindFirstChild(tag) == nil
	local at = if limb.arm then FRACTURE_AT.arm else FRACTURE_AT.leg
	dress(part, limb.fracture, tag, part.Color, function(folder: Instance)
		simpleWound(
			part,
			CFrame.lookAt(at, at - Vector3.zAxis),
			0.18,
			Vector3.new(0.14, 0.14, 0.35),
			folder
		)
	end)
	if live and fresh then
		SoundController.play("RibCrack", model)
		local out = CFrame.lookAt(at, at + Vector3.new(0, -0.4, -1))
		BloodGush.artery(part, out, {
			seconds = 2,
			beat = 0.45,
			speed = 4,
			size = 0.07,
			pool = 1.2,
			seed = seed,
			ignore = { model :: Instance },
		})
		BloodGush.runDown(part, at, 4, seed + 7)
	end
end

------------------------------------------------------------------------------
-- Teeth, the jaw
------------------------------------------------------------------------------

local function hasFace(model: Model): BasePart?
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") or HeadBlast.isBlown(model) then
		return nil
	end
	return head
end

-- Teeth fly out of the mouth (only seen live), with blood.
local function teeth(model: Model, seed: number)
	local head = hasFace(model)
	if head == nil then
		return
	end
	local random = Random.new(seed)
	local mouth = head.CFrame * Vector3.new(0, -0.3, -0.55)
	local forward = head.CFrame.LookVector
	Blood.spray(mouth, forward + Vector3.new(0, 0.3, 0), 1.2, model)
	local pieces = GoreKit.get()
	local range = Config.HeavyGore.TEETH_COUNT
	local count = random:NextInteger(range[1], range[2])
	local names = table.clone(GoreShapes.tooth)
	for index = 1, math.min(count, #names) do
		local pick = random:NextInteger(index, #names)
		names[index], names[pick] = names[pick], names[index]
		local piece = if pieces then pieces[names[index]] else nil
		local tooth: BasePart
		if piece then
			tooth = GoreKit.spawn(piece, head.CFrame, painter(head.Color))
		else
			tooth = simplePart("Tooth", Enum.PartType.Block, Vector3.new(0.07, 0.1, 0.06), TOOTH)
			tooth.CFrame = CFrame.new(mouth)
		end
		tooth.CanCollide = false
		tooth.CanQuery = false
		tooth.CanTouch = false
		local direction = (
			forward
			+ Vector3.new(0, random:NextNumber(0.2, 0.9), 0)
			+ random:NextUnitVector() * 0.45
		).Unit
		tooth.AssemblyLinearVelocity = direction * random:NextNumber(10, 20)
		tooth.AssemblyAngularVelocity = random:NextUnitVector() * random:NextNumber(10, 30)
		tooth.Parent = workspace
		-- (solid once out of the head: they bounce on the floor)
		task.delay(0.12, function()
			if tooth.Parent then
				tooth.CanCollide = true
			end
		end)
		Debris:AddItem(tooth, Config.HeavyGore.TEETH_TIME)
	end
end

local function jaw(model: Model, seed: number, live: boolean)
	local head = hasFace(model)
	if head == nil then
		return
	end
	local fresh = head:FindFirstChild("HeavyGore_Jaw") == nil
	dress(head, "JawBroken", "HeavyGore_Jaw", head.Color, function(folder: Instance)
		-- the mouth torn open: dark, raw, a few teeth
		local raw = simplePart("Raw", Enum.PartType.Block, Vector3.new(0.5, 0.18, 0.04), FLESH_DARK)
		raw.CFrame = head.CFrame * CFrame.new(0.03, -0.27, -0.6) * CFrame.Angles(0, 0, math.rad(-8))
		weldTo(head, raw, folder)
		for index = -2, 2 do
			if index ~= 0 then
				local tooth =
					simplePart("Tooth", Enum.PartType.Block, Vector3.new(0.06, 0.07, 0.03), TOOTH)
				tooth.CFrame = head.CFrame * CFrame.new(index * 0.08, -0.22, -0.62)
				weldTo(head, tooth, folder)
			end
		end
	end)
	if live and fresh then
		BloodGush.runDown(head, Vector3.new(0, -0.38, -0.55), 5, seed)
	end
end

------------------------------------------------------------------------------
-- What to draw for one attribute
------------------------------------------------------------------------------

local function apply(model: Model, name: string, live: boolean)
	if not enabled() then
		return
	end
	local value = model:GetAttribute(name)
	if typeof(value) ~= "number" then
		return
	end
	if name == HeavyGoreUtil.TEETH then
		if live then
			teeth(model, value)
		end
		return
	elseif name == HeavyGoreUtil.JAW then
		jaw(model, value, live)
		return
	end
	local kind, key = HeavyGoreUtil.parse(name)
	if kind == "Torn" and key then
		tornLimb(model, key, value, live)
	elseif kind == "Fracture" and key then
		fracture(model, key, value, live)
	end
end

local function applyAll(model: Model)
	for name in model:GetAttributes() do
		apply(model, name, false)
	end
end

function HeavyGore.watch(model: Model)
	model.AttributeChanged:Connect(function(name: string)
		apply(model, name, true)
	end)
	-- (back in the game after streaming out: drawn again where it's gone)
	model.AncestryChanged:Connect(function()
		if model:IsDescendantOf(workspace) then
			applyAll(model)
		end
	end)
	applyAll(model)
end

------------------------------------------------------------------------------
-- The torn limbs lying around
------------------------------------------------------------------------------

local function onLimb(instance: Instance)
	if not instance:IsA("Model") or not enabled() then
		return
	end
	local key = instance:GetAttribute("Limb")
	local seed = instance:GetAttribute("Seed")
	local limb = if typeof(key) == "string" then HeavyGoreUtil.LIMBS[key] else nil
	local part = if limb then instance:FindFirstChild(limb.part) else nil
	if limb == nil or typeof(seed) ~= "number" or part == nil or not part:IsA("BasePart") then
		return
	end
	local tag = "HeavyGore_" .. limb.limbEnd
	if part:FindFirstChild(tag) then
		return
	end
	local top = Vector3.new(0, part.Size.Y / 2, 0)
	dress(part, limb.limbEnd, tag, part.Color, function(folder: Instance)
		simpleWound(
			part,
			CFrame.lookAt(top, top + Vector3.yAxis, Vector3.zAxis),
			0.45,
			Vector3.new(0.22, 0.22, 0.3),
			folder
		)
	end)
	local tornAt = instance:GetAttribute("TornAt")
	if typeof(tornAt) == "number" and workspace:GetServerTimeNow() - tornAt < LIVE_TIME then
		BloodGush.artery(part, CFrame.lookAt(top, top + Vector3.yAxis), {
			seconds = 2.5,
			beat = 0.4,
			speed = 6,
			size = 0.1,
			pool = 1.5,
			seed = seed + 3,
			ignore = { instance :: Instance },
		})
		drip(part, top + Vector3.new(0, 0.05, 0))
	end
end

local started = false
function HeavyGore.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(HeavyGoreUtil.TAG):Connect(onLimb)
	for _, instance in CollectionService:GetTagged(HeavyGoreUtil.TAG) do
		onLimb(instance)
	end
end

return table.freeze(HeavyGore)
