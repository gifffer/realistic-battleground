--!strict
-- WaistCut: Dr. Rift's finisher (Shared/Finishers "PortalCut"): a portal
-- closes round the victim's waist and cuts the body in two.
--
-- The server, at the cut (Systems/Combat cutInHalf): takes the hip joints
-- off, keeps the legs standing (welded to the anchored root), lets the upper
-- body (torso, head, arms) fall back, and sets the attribute "CutInHalf"
-- (= a seed) on the body; a moment later the legs fold. Every part stays in
-- the body (its clothes keep showing). Every client then (Gashes watches the
-- attribute):
--   • under the torso: the real cut through the hips (Z-Anatomy): the
--     pelvis and the sacrum in section, the femoral heads, the glutei, the
--     iliopsoas and the thigh muscles cut, the bladder and the colon, the
--     cut arteries, the yellow fat under the skin, the skin torn round the
--     edge, loops of small intestine hanging out;
--   • on each leg's top: the other face of it (the femur's head in its
--     socket, the muscles, the femoral artery and vein, fat, skin);
--   • when it happens in front of us (not a body we only see later): a
--     burst of blood both ways, a geyser out of each leg's femoral artery
--     while they stand, the iliac arteries pumping out of the upper body, blood
--     running down the legs, loose loops of intestine falling out on the
--     floor, the torso dripping.
-- Pieces from WoundKit (GoreKit "Waist" / "HipR" / "HipL" / "Gut<i>");
-- simpler ones drawn here without them (an older kit).
--
--   WaistCut.apply(model, live)   draws the wounds (once per body)
--   WaistCut.isApplied(model)     whether it has been drawn on this body

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GoreKit = require(script.Parent.GoreKit)
local Blood = require(script.Parent.Blood)
local BloodGush = require(script.Parent.BloodGush)
local Squish = require(script.Parent.Squish)

local WaistCut = {}

WaistCut.ATTRIBUTE = "CutInHalf"

local BLOOD = Color3.fromRGB(78, 6, 6)
local BLOOD_WET = Color3.fromRGB(104, 8, 8)
local FLESH = Color3.fromRGB(122, 28, 30)
local FLESH_DARK = Color3.fromRGB(70, 10, 12)
local BONE = Color3.fromRGB(226, 214, 190)
-- The real muscles' cut (Z-Anatomy): raw red, a darker one beside it; the fat
-- under the skin: yellow; the gut: wet pinkish grey; the vessels: dark.
local MUSCLE = Color3.fromRGB(150, 32, 34)
local MUSCLE_DARK = Color3.fromRGB(112, 22, 26)
local FAT = Color3.fromRGB(222, 190, 112)
local GUT = Color3.fromRGB(196, 140, 128)
local VESSEL = Color3.fromRGB(88, 14, 32)
local DRIP_TIME = 10 -- seconds the upper body drips
local GUT_LIFETIME = 25 -- seconds the loose loops of gut stay on the floor
-- Where the cut arteries are (gore.py: the real vessels' section, widened
-- to the R6 parts; the ends of the Vessel stubs in WoundKit). Each leg's
-- femoral artery, in its own space (its top at Y = 1); the upper body's
-- (there is no aorta this low: the two external iliac / femoral arteries,
-- right and left), in the torso's.
local FEMORAL: { [string]: Vector3 } = {
	["Right Leg"] = Vector3.new(-0.28, 1.12, -0.16),
	["Left Leg"] = Vector3.new(0.28, 1.12, -0.16),
}
local ILIAC = { Vector3.new(0.48, -1.15, -0.25), Vector3.new(-0.48, -1.15, -0.25) }
local CUT = CFrame.new(0, -1, 0) -- the torso's cut face (torso space)

local done: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- (gore off in Config: nothing drawn, the body just comes apart)
local function enabled(model: Model): boolean
	return Config.Injuries.SKIN_TEAR and model:GetAttribute(WaistCut.ATTRIBUTE) ~= nil
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
		elseif layer == "FleshDark" then
			return FLESH_DARK, 0.2
		elseif layer == "Muscle" then
			return MUSCLE, 0.16
		elseif layer == "MuscleDark" then
			return MUSCLE_DARK, 0.16
		elseif layer == "Fat" then
			return FAT, 0.08
		elseif layer == "Gut" then
			return GUT, 0.2
		elseif layer == "Vessel" then
			return VESSEL, 0.18
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
	part.Reflectance = if color == FLESH or color == GUT then 0.14 else 0
	return part
end

-- Torn skin round the edge of a cut face (`at`: the face's centre, Y out of
-- it; `half`: its half size in X, Z).
local function simpleFlaps(
	part: BasePart,
	at: CFrame,
	half: Vector2,
	skin: Color3,
	random: Random,
	folder: Instance
)
	for index = 1, 10 do
		local angle = index / 10 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local x, z = math.cos(angle), math.sin(angle)
		local edge =
			math.min(half.X / math.max(math.abs(x), 1e-3), half.Y / math.max(math.abs(z), 1e-3))
		local flap = simplePart(
			"Flap",
			Enum.PartType.Block,
			Vector3.new(random:NextNumber(0.16, 0.3), 0.03, random:NextNumber(0.08, 0.16)),
			skin
		)
		flap.CFrame = at
			* CFrame.new(x * edge, 0, z * edge)
			* CFrame.Angles(0, -angle + math.pi / 2, 0)
			* CFrame.Angles(math.rad(random:NextNumber(-70, -30)), 0, 0)
		weldTo(part, flap, folder)
	end
end

-- The kit's piece `name` (in `part`'s own space) on `part`, or simple
-- shapes without it.
local function dress(part: BasePart, name: string, skin: Color3, random: Random)
	local folder = Instance.new("Folder")
	folder.Name = "WaistCut"
	local pieces = GoreKit.get()
	local piece = if pieces then pieces[name] else nil
	if piece then
		weldTo(part, GoreKit.spawn(piece, part.CFrame, painter(skin)), folder)
	elseif name == "Waist" then
		-- The raw face under the torso, the two femoral heads and the
		-- sacrum in it, the skin torn round it, gut hanging.
		local face = part.CFrame * CUT
		local raw = simplePart("Raw", Enum.PartType.Block, Vector3.new(2.02, 0.1, 1.02), FLESH)
		raw.CFrame = face * CFrame.new(0, -0.04, 0)
		weldTo(part, raw, folder)
		for _, x in { -0.5, 0.5 } do
			local head = simplePart("Bone", Enum.PartType.Ball, Vector3.new(0.3, 0.2, 0.3), BONE)
			head.CFrame = face * CFrame.new(x, -0.08, 0)
			weldTo(part, head, folder)
		end
		local sacrum = simplePart("Bone", Enum.PartType.Block, Vector3.new(0.4, 0.06, 0.18), BONE)
		sacrum.CFrame = face * CFrame.new(0, -0.08, 0.36)
		weldTo(part, sacrum, folder)
		for index = 1, 3 do
			local loop = simplePart(
				"Gut",
				Enum.PartType.Cylinder,
				Vector3.new(random:NextNumber(0.4, 0.8), 0.14, 0.14),
				GUT
			)
			loop.CFrame = face
				* CFrame.new(random:NextNumber(-0.5, 0.5), -0.3, -0.2 + index * 0.06)
				* CFrame.Angles(
					0,
					random:NextNumber(0, math.pi),
					math.rad(random:NextNumber(60, 90))
				)
			weldTo(part, loop, folder)
		end
		simpleFlaps(
			part,
			face * CFrame.Angles(math.pi, 0, 0),
			Vector2.new(1, 0.5),
			skin,
			random,
			folder
		)
	else
		-- A leg's top: raw, the femur's head in it, the artery's end.
		local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
		local raw = simplePart("Raw", Enum.PartType.Block, Vector3.new(1.02, 0.1, 1.02), FLESH)
		raw.CFrame = top * CFrame.new(0, 0.03, 0)
		weldTo(part, raw, folder)
		local sign = if name == "HipR" then 1 else -1
		local head = simplePart("Bone", Enum.PartType.Cylinder, Vector3.new(0.1, 0.32, 0.32), BONE)
		head.CFrame = top * CFrame.new(0.05 * sign, 0.06, 0.02) * CFrame.Angles(0, 0, math.pi / 2)
		weldTo(part, head, folder)
		local artery =
			simplePart("Vessel", Enum.PartType.Cylinder, Vector3.new(0.16, 0.08, 0.08), VESSEL)
		artery.CFrame = top
			* CFrame.new(-0.27 * sign, 0.08, -0.16)
			* CFrame.Angles(0, 0, math.pi / 2)
		weldTo(part, artery, folder)
		simpleFlaps(part, top, Vector2.new(0.5, 0.5), skin, random, folder)
	end
	folder.Parent = part
end

-- A loose loop of gut, falling out of the torso's cut at `at` (world).
local function newGut(index: number, at: CFrame, random: Random): BasePart
	local pieces = GoreKit.get()
	local piece = if pieces then pieces["Gut" .. index] else nil
	local gut: BasePart
	if piece then
		gut = GoreKit.spawn(piece, at, painter(GUT))
	else
		-- (a sphere mesh, not a cylinder part: it can be squashed)
		local loop = Instance.new("Part")
		loop.Name = "Gut"
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = loop
		loop.Size = Vector3.new(random:NextNumber(0.9, 1.4), 0.2, 0.22)
		loop.Material = Enum.Material.SmoothPlastic
		loop.Color = GUT
		loop.Reflectance = 0.2
		loop.CFrame = at
		gut = loop
	end
	gut.Name = "LooseGut"
	gut.Anchored = false
	gut.CanCollide = true
	gut.CanQuery = false
	gut.CanTouch = false
	gut.Massless = false
	return gut
end

-- The loops of small intestine slipping out of the upper body as it falls:
-- soft and wet, they slap on the floor and stay there a while.
local function spill(torso: BasePart, model: Model, random: Random)
	for index = 1, 3 do
		task.delay(0.15 + index * random:NextNumber(0.12, 0.3), function()
			if torso.Parent == nil or not model:IsDescendantOf(workspace) then
				return
			end
			-- (out of the cut face, lying along it: turned round the torso's
			-- axis, only a little tilted)
			local at = torso.CFrame
				* CFrame.new(random:NextNumber(-0.4, 0.4), -1.6, random:NextNumber(-0.2, 0.05))
				* CFrame.Angles(
					random:NextNumber(-0.35, 0.35),
					random:NextNumber(0, math.pi * 2),
					random:NextNumber(-0.35, 0.35)
				)
			local gut = newGut(index, at, random)
			-- (the body's parts, the server's, can't shove it away while it
			-- slips out of them: no collision with them for a moment)
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") then
					local free = Instance.new("NoCollisionConstraint")
					free.Part0 = gut
					free.Part1 = part
					free.Parent = gut
					Debris:AddItem(free, 0.6)
				end
			end
			gut.Parent = workspace
			gut.AssemblyLinearVelocity = torso.AssemblyLinearVelocity * 0.6
				+ torso.CFrame.UpVector * -random:NextNumber(3, 6)
				+ Vector3.new(random:NextNumber(-2, 2), 0, random:NextNumber(-2, 2))
			gut.AssemblyAngularVelocity = random:NextUnitVector() * random:NextNumber(2, 6)
			-- (its surface detail first, in the workspace: then it squashes too)
			Squish.detail(gut, "Brain")
			Squish.soft(
				gut,
				{ softness = 0.5, sag = 0.25, stiffness = 170, lifetime = GUT_LIFETIME }
			)
			Blood.drop(at.Position, gut.AssemblyLinearVelocity, random:NextNumber(0.07, 0.11))
			Debris:AddItem(gut, GUT_LIFETIME)
		end)
	end
end

-- The upper body drips from its cut face.
local function drip(torso: BasePart)
	local point = Instance.new("Attachment")
	point.Name = "WaistCutDrip"
	point.Position = Vector3.new(0, -torso.Size.Y / 2 - 0.05, 0)
	point.Parent = torso
	local drops = emitter(point, 30)
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.Speed = NumberRange.new(0.5, 2)
	drops.SpreadAngle = Vector2.new(50, 50)
	task.delay(DRIP_TIME, function()
		drops.Rate = 0
		Debris:AddItem(point, 1.5)
	end)
end

-- The burst of the cut, the arteries pumping, the gut falling out.
local function bleed(
	model: Model,
	torso: BasePart,
	legs: { BasePart },
	seed: number,
	random: Random
)
	-- (no sound here: RiftFx plays "BodyCut" on the cinematic's "Cut" event,
	-- the only thing that sets the attribute)
	local ignore = { model :: Instance }
	-- the cut: blood thrown both ways out of it, a red haze
	local plane = (torso.CFrame * CUT).Position
	Blood.spray(plane, Vector3.new(0, 1, 0), 6, model)
	Blood.spray(plane, -torso.CFrame.UpVector + Vector3.new(0, 0.3, 0), 4, model, true)
	Blood.mist(plane, Vector3.new(0, 1, 0), 2.5)
	-- each leg, still standing: the femoral artery a geyser straight up
	for index, leg in legs do
		local femoral = FEMORAL[leg.Name] or Vector3.new(0, leg.Size.Y / 2 + 0.05, 0)
		local out = if femoral.X < 0 then 1 else -1 -- (away from the other leg)
		BloodGush.artery(leg, CFrame.lookAt(femoral, femoral + Vector3.new(0.18 * out, 1, -0.12)), {
			seconds = 4,
			beat = 0.35,
			speed = random:NextNumber(16, 20),
			size = 0.14,
			pool = if index == 1 then 3 else 0,
			seed = seed + index * 7,
			ignore = ignore,
		})
		BloodGush.runDown(
			leg,
			Vector3.new(0.42 * out, leg.Size.Y / 2 - 0.05, -0.3),
			5,
			seed + index * 13
		)
		BloodGush.runDown(
			leg,
			Vector3.new(-0.3 * out, leg.Size.Y / 2 - 0.05, 0.42),
			3,
			seed + index * 17
		)
	end
	-- the upper body: its two cut iliac arteries pumping out of it (down,
	-- then sideways once it lies on its back)
	for index, iliac in ILIAC do
		local out = if iliac.X > 0 then 0.15 else -0.15
		BloodGush.artery(torso, CFrame.lookAt(iliac, iliac + Vector3.new(out, -1, 0.1)), {
			seconds = 5,
			beat = 0.38,
			speed = random:NextNumber(11, 13),
			size = 0.15,
			pool = if index == 1 then 4 else 0,
			seed = seed + 3 + index * 11,
			ignore = ignore,
		})
	end
	drip(torso)
	spill(torso, model, random)
end

function WaistCut.isApplied(model: Model): boolean
	return done[model] == true
end

-- `model` was cut in two. `live`: it's happening now, not a body we only
-- see now (streamed in late): then just the wounds.
function WaistCut.apply(model: Model, live: boolean)
	local seed = model:GetAttribute(WaistCut.ATTRIBUTE)
	if typeof(seed) ~= "number" or done[model] or not enabled(model) then
		return
	end
	local torso = model:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	done[model] = true
	local random = Random.new(seed)
	dress(torso, "Waist", torso.Color, random)
	local legs: { BasePart } = {}
	for _, pair in { { "Right Leg", "HipR" }, { "Left Leg", "HipL" } } do
		local leg = model:FindFirstChild(pair[1])
		if leg and leg:IsA("BasePart") then
			-- (each leg's own skin colour: the cut shows it at the rim)
			dress(leg, pair[2], leg.Color, random)
			table.insert(legs, leg)
		end
	end
	if live then
		bleed(model, torso, legs, seed, random)
	end
end

return table.freeze(WaistCut)
