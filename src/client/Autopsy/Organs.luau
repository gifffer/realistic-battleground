--!strict
-- Organs: the inside of the patient's torso, from Z-Anatomy. The pieces are
-- the "Aut*" ones of the WoundKit (GoreShapes.autopsy, tools/wounds/gore.py),
-- already in R6 torso space; without them (an old kit) simple blobs stand
-- in. Every organ but the lining and the back can be grabbed: it is held
-- in place at first (pulled, it stretches and resists), then TEARS free
-- with a gush of blood, and dangles from the hand (physics). Let go, it
-- falls soft and wet (Combat/Squish).
--
--   Organs.build(torso, parent, anchor) -> Set
--   Organs.find(set, part) -> Organ?          the organ a part belongs to
--   Organs.grab(set, organ, at) -> string?    nil, or why it can't be taken
--   Organs.drag(set, target, dt)              where the hand is now
--   Organs.release(set)
--   Organs.crack(organ)                       the chest plate cut free (shears)
--   Organs.destroy(set)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blood = require(script.Parent.Parent.Combat.Blood)
local BloodGush = require(script.Parent.Parent.Combat.BloodGush)
local GoreKit = require(script.Parent.Parent.Combat.GoreKit)
local Squish = require(script.Parent.Parent.Combat.Squish)
local GoreShapes = require(ReplicatedStorage.Shared.GoreShapes)
local Make = require(script.Parent.Make)
local PixelScreen = require(script.Parent.PixelScreen)
local Sfx = require(script.Parent.Sfx)

local Organs = {}

export type Organ = {
	name: string,
	label: string,
	root: BasePart,
	home: CFrame, -- world
	static: boolean, -- never taken (the lining, the back)
	locked: boolean, -- the chest plate, until the shears cut it
	torn: boolean,
	soft: boolean,
	big: boolean, -- tears with an artery
}

export type Set = {
	folder: Model,
	torso: CFrame,
	anchor: BasePart,
	list: { Organ },
	held: Organ?,
	grabPoint: Vector3, -- (world, where it was grabbed, at home)
	attachment: Attachment?,
	align: AlignPosition?,
	damper: AngularVelocity?,
	pulling: number, -- seconds pulled hard
	lastDrip: number,
	lastStrand: number,
	pool: BasePart,
	level: number,
	kit: boolean,
}

local UP = Vector3.new(0, 1, 0)

-- English names (shown in the hint line) and which ones tear an artery.
local LABELS: { [string]: string } = {
	AutDiaphragm = "Diaphragm",
	AutKidneyR = "Right kidney",
	AutKidneyL = "Left kidney",
	AutPancreas = "Pancreas",
	AutSpleen = "Spleen",
	AutStomach = "Stomach",
	AutLiver = "Liver",
	AutColon = "Colon",
	AutGut = "Small intestine",
	AutOmentum = "Omentum",
	AutLungR = "Right lung",
	AutLungL = "Left lung",
	AutHeart = "Heart",
	AutChest = "Chest plate",
}
local BIG: { [string]: boolean } =
	{ AutHeart = true, AutLiver = true, AutKidneyR = true, AutKidneyL = true }
local STATIC: { [string]: boolean } = { AutCavity = true, AutBack = true }

-- Colour and shine of each layer (the kit's layer names).
local LOOKS: { [string]: { any } } = {
	Heart = { Color3.fromRGB(120, 20, 25), 0.18 },
	HeartDark = { Color3.fromRGB(70, 10, 16), 0.18 },
	Lung = { Color3.fromRGB(215, 120, 125), 0.14 },
	Liver = { Color3.fromRGB(95, 18, 24), 0.2 },
	Gallbladder = { Color3.fromRGB(70, 110, 50), 0.2 },
	Stomach = { Color3.fromRGB(205, 130, 115), 0.16 },
	Gut = { Color3.fromRGB(220, 150, 135), 0.2 },
	GutDark = { Color3.fromRGB(150, 80, 78), 0.16 },
	Colon = { Color3.fromRGB(190, 120, 100), 0.16 },
	Kidney = { Color3.fromRGB(110, 30, 35), 0.18 },
	Spleen = { Color3.fromRGB(100, 25, 45), 0.18 },
	Pancreas = { Color3.fromRGB(225, 180, 130), 0.12 },
	Bone = { Color3.fromRGB(225, 215, 190), 0.05 },
	Cartilage = { Color3.fromRGB(200, 215, 220), 0.1 },
	Fat = { Color3.fromRGB(222, 188, 98), 0.12 },
	Muscle = { Color3.fromRGB(130, 20, 20), 0.14 },
	FleshDark = { Color3.fromRGB(60, 8, 8), 0.12 },
	Blood = { Color3.fromRGB(90, 5, 8), 0.2 },
	Artery = { Color3.fromRGB(190, 70, 70), 0.15 },
	Vein = { Color3.fromRGB(60, 30, 80), 0.15 },
	Vessel = { Color3.fromRGB(100, 20, 40), 0.15 },
}
local RAMPS: { [string]: string } = {
	Heart = "liver",
	HeartDark = "liver",
	Liver = "liver",
	Kidney = "liver",
	Spleen = "liver",
	Lung = "organ",
	Gut = "organ",
	GutDark = "organ",
	Stomach = "organ",
	Colon = "organ",
	Pancreas = "fat",
	Fat = "fat",
	Bone = "bone",
	Cartilage = "bone",
	Blood = "blood",
	FleshDark = "blood",
	Muscle = "muscle",
}

local function paint(layer: string): (Color3, number)
	local look = LOOKS[layer]
	if look then
		return look[1] :: Color3, look[2] :: number
	end
	return Color3.fromRGB(140, 40, 40), 0.15
end

-- Every part of an organ: queryable (picked by the mouse, seen by the
-- pixel screen), anchored at home, not colliding yet.
local function prepare(root: BasePart)
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanQuery = true
			item.CanTouch = false
			local layer = string.match(item.Name, "_(%a+)$")
			if layer and RAMPS[layer] then
				item:SetAttribute("PixRamp", RAMPS[layer])
			end
		end
	end
	local layer = string.match(root.Name, "_(%a+)$")
	if layer and RAMPS[layer] then
		root:SetAttribute("PixRamp", RAMPS[layer])
	end
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = true
	root.CanTouch = false
end

-- Simple blobs when the kit has no autopsy pieces (torso space).
type Blob = { name: string, at: Vector3, size: Vector3, layer: string, box: boolean? }
local BLOBS: { Blob } = {
	{
		name = "AutKidneyR",
		at = Vector3.new(0.5, -0.35, 0.22),
		size = Vector3.new(0.26, 0.42, 0.2),
		layer = "Kidney",
	},
	{
		name = "AutKidneyL",
		at = Vector3.new(-0.5, -0.35, 0.22),
		size = Vector3.new(0.26, 0.42, 0.2),
		layer = "Kidney",
	},
	{
		name = "AutLungR",
		at = Vector3.new(0.45, 0.45, 0),
		size = Vector3.new(0.62, 0.95, 0.62),
		layer = "Lung",
	},
	{
		name = "AutLungL",
		at = Vector3.new(-0.45, 0.45, 0),
		size = Vector3.new(0.55, 0.95, 0.62),
		layer = "Lung",
	},
	{
		name = "AutHeart",
		at = Vector3.new(-0.1, 0.32, -0.12),
		size = Vector3.new(0.5, 0.55, 0.45),
		layer = "Heart",
	},
	{
		name = "AutLiver",
		at = Vector3.new(0.35, -0.12, -0.08),
		size = Vector3.new(0.95, 0.45, 0.5),
		layer = "Liver",
	},
	{
		name = "AutStomach",
		at = Vector3.new(-0.35, -0.12, -0.1),
		size = Vector3.new(0.6, 0.45, 0.42),
		layer = "Stomach",
	},
	{
		name = "AutGut",
		at = Vector3.new(0, -0.62, -0.1),
		size = Vector3.new(1.25, 0.62, 0.45),
		layer = "Gut",
	},
	{
		name = "AutChest",
		at = Vector3.new(0, 0.42, -0.36),
		size = Vector3.new(1.5, 1, 0.07),
		layer = "Bone",
		box = true,
	},
}

local function blob(spec: Blob, torso: CFrame): BasePart
	local look, shine = paint(spec.layer)
	local part = Make.part({
		Name = `{spec.name}_{spec.layer}`,
		Size = spec.size,
		CFrame = torso * CFrame.new(spec.at),
		Color = look,
		Reflectance = shine,
	})
	if not spec.box then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		part:SetAttribute("PixEllipsoid", spec.size / 2)
	end
	return part
end

-- The dark lining of the cavity (without the kit's).
local function lining(folder: Model, torso: CFrame)
	local walls = {
		{ Vector3.new(0, 0, 0.43), Vector3.new(1.9, 1.9, 0.04) },
		{ Vector3.new(0.94, 0, 0), Vector3.new(0.04, 1.9, 0.86) },
		{ Vector3.new(-0.94, 0, 0), Vector3.new(0.04, 1.9, 0.86) },
		{ Vector3.new(0, 0.94, 0), Vector3.new(1.9, 0.04, 0.86) },
		{ Vector3.new(0, -0.94, 0), Vector3.new(1.9, 0.04, 0.86) },
	}
	for _, wall in walls do
		Make.part({
			Name = "Lining",
			Size = wall[2],
			CFrame = torso * CFrame.new(wall[1]),
			Color = Color3.fromRGB(46, 4, 4),
			Reflectance = 0.1,
			Ramp = "blood",
			CanCollide = false,
			Parent = folder,
		})
	end
end

function Organs.build(torso: CFrame, parent: Instance, anchor: BasePart): Set
	local folder = Instance.new("Model")
	folder.Name = "Organs"
	folder.Parent = parent
	local list: { Organ } = {}
	local pieces = GoreKit.get()
	local kit = pieces ~= nil and pieces.AutChest ~= nil
	local function add(name: string, root: BasePart)
		prepare(root) -- (reads its layer from its kit name first)
		root.Name = name
		root.Parent = folder
		table.insert(list, {
			name = name,
			label = LABELS[name] or name,
			root = root,
			home = root.CFrame,
			static = STATIC[name] == true,
			locked = name == "AutChest",
			torn = false,
			soft = false,
			big = BIG[name] == true,
		})
	end
	if pieces and kit then
		for _, name in GoreShapes.autopsy do
			local piece = pieces[name]
			if piece then
				add(name, GoreKit.spawn(piece, torso, paint))
			end
		end
	else
		lining(folder, torso)
		for _, spec in BLOBS do
			add(spec.name, blob(spec, torso))
		end
	end
	-- the blood pooling in the cavity (rises as organs come out)
	local pool = Make.part({
		Name = "CavityBlood",
		Size = Vector3.new(1.84, 1.84, 0.02),
		CFrame = torso * CFrame.new(0, 0, 0.4),
		Color = Color3.fromRGB(88, 4, 8),
		Reflectance = 0.18,
		CanCollide = false,
		Ramp = "blood",
		Parent = folder,
	})
	return {
		folder = folder,
		torso = torso,
		anchor = anchor,
		list = list,
		held = nil,
		grabPoint = Vector3.zero,
		attachment = nil,
		align = nil,
		damper = nil,
		pulling = 0,
		lastDrip = 0,
		lastStrand = 0,
		pool = pool,
		level = 0,
		kit = kit,
	}
end

function Organs.find(set: Set, part: Instance): Organ?
	for _, organ in set.list do
		if part == organ.root or part:IsDescendantOf(organ.root) then
			return organ
		end
	end
	return nil
end

function Organs.grab(set: Set, organ: Organ, at: Vector3): string?
	if organ.static then
		return nil
	end
	if organ.locked then
		return "Cut the chest plate free first (3 Shears)"
	end
	local root = organ.root
	root.Anchored = false
	root.CanCollide = false
	local attachment = Instance.new("Attachment")
	attachment.Name = "Hand"
	attachment.Parent = root
	attachment.WorldPosition = at
	local mass = math.max(root.AssemblyMass, 0.05)
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxForce = mass * workspace.Gravity * 12 + 400
	align.Responsiveness = 40
	align.Position = at
	align.Parent = root
	local damper = Instance.new("AngularVelocity")
	damper.Attachment0 = attachment
	damper.AngularVelocity = Vector3.zero
	damper.MaxTorque = mass * 30 + 5
	damper.RelativeTo = Enum.ActuatorRelativeTo.World
	damper.Parent = root
	set.held = organ
	set.grabPoint = at
	set.attachment = attachment
	set.align = align
	set.damper = damper
	set.pulling = 0
	Sfx.play("Squelch", at)
	return nil
end

-- The pixel screen only sees parts, not the artery's particles and beam:
-- there the jet is drawn with strands too, on the same beats.
local function pixelJet(
	set: Set,
	from: Vector3,
	direction: Vector3,
	seconds: number,
	firstBeat: number
)
	task.spawn(function()
		local start = os.clock()
		local beat = firstBeat
		while set.anchor.Parent and PixelScreen.isOn() and os.clock() - start < seconds do
			local left = 1 - (os.clock() - start) / seconds
			local strength = left * left * 0.8 + left * 0.2
			for _ = 1, 1 + math.floor(2 * strength) do
				local spread = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.6
				Blood.strand(
					from,
					(direction + spread) * (5 * (0.35 + 0.65 * strength)) + UP * 1.5,
					0.05 + 0.03 * strength
				)
			end
			task.wait(beat)
			beat = math.min(beat * 1.06, 1.1)
		end
	end)
end

-- The organ comes free: a gush, a tear, the cavity fills a little more.
local function tear(set: Set, organ: Organ)
	organ.torn = true
	local at = set.grabPoint
	Sfx.play("Tear", at)
	if organ.name == "AutGut" or organ.name == "AutColon" then
		Sfx.play("Guts", at)
	end
	Blood.spray(at, UP, 5)
	Blood.spray(at, UP * 0.4 + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5), 3)
	for _ = 1, 8 do
		Blood.strand(
			at,
			UP * math.random(3, 6) + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 3,
			0.06
		)
	end
	do
		local big = organ.big == true
		local localAt = set.anchor.CFrame:PointToObjectSpace(at)
		local ignore: { Instance } = { set.folder }
		if set.anchor.Parent then
			table.insert(ignore, set.anchor.Parent)
		end
		BloodGush.artery(set.anchor, CFrame.lookAt(localAt, localAt + Vector3.new(0, 0, -1)), {
			seconds = if big then 7 else 3,
			beat = 0.5,
			speed = if big then 7.5 else 4.5,
			size = if big then 0.12 else 0.08,
			pool = if big then 2.8 else 1.6,
			seed = math.random(1, 2 ^ 20),
			ignore = ignore,
		})
		if PixelScreen.isOn() then
			pixelJet(
				set,
				at,
				set.anchor.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -1)),
				3.5,
				0.55
			)
		end
	end
	set.level = math.min(set.level + 0.05, 0.62)
	set.pool.CFrame = set.torso * CFrame.new(0, 0, 0.4 - set.level)
end

function Organs.drag(set: Set, target: Vector3, dt: number)
	local organ = set.held
	local align = set.align
	if organ == nil or align == nil then
		return
	end
	local now = os.clock()
	if not organ.torn then
		-- still attached: it follows a little, stretching, then rips
		local pull = target - set.grabPoint
		local distance = pull.Magnitude
		if distance > 0.9 then
			set.pulling += dt
		else
			set.pulling = math.max(0, set.pulling - dt)
		end
		if distance > 2.2 or set.pulling > 0.55 then
			tear(set, organ)
			align.Position = target
		else
			local give = math.min(distance * 0.28, 0.4)
			local shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
				* 0.04
				* math.min(1, distance)
			align.Position = set.grabPoint
				+ (if distance > 1e-3 then pull.Unit * give else Vector3.zero)
				+ shake
			-- (strings of blood between it and its place)
			if distance > 0.5 and now - set.lastStrand > 0.25 then
				set.lastStrand = now
				Blood.strand(set.grabPoint, pull.Unit * 2 + UP, 0.045)
			end
		end
	else
		align.Position = target
	end
	-- it drips while held
	if now - set.lastDrip > 0.03 + math.random() * 0.05 then
		set.lastDrip = now
		local root = organ.root
		Blood.drop(
			root.Position - Vector3.new(0, root.Size.Y * 0.3, 0),
			Vector3.new(math.random() - 0.5, -0.5, math.random() - 0.5) * 0.6,
			0.07 + math.random() * 0.06,
			nil,
			Blood.passiveScale(),
			{ passive = true }
		)
		if math.random() < 0.08 then
			Sfx.play("Drip", root)
		end
	end
end

function Organs.release(set: Set)
	local organ = set.held
	set.held = nil
	for _, item in { set.align, set.damper, set.attachment } :: { Instance? } do
		if item then
			item:Destroy()
		end
	end
	set.align, set.damper, set.attachment = nil, nil, nil
	if organ == nil then
		return
	end
	local root = organ.root
	if not organ.torn then
		-- let go before it tore: it goes back in place
		root.Anchored = true
		root.CFrame = organ.home
		return
	end
	root.CanCollide = true
	if not organ.soft then
		organ.soft = true
		Squish.soft(
			root,
			{ softness = 0.45, sag = 0.2, stiffness = 200, lifetime = 90, bleeds = true }
		)
		-- (Squish shows a copy and hides the part: the copy is what the
		-- mouse and the pixel screen see)
		root.CanQuery = false
		local look = root:FindFirstChild(root.Name .. "Look")
		if look and look:IsA("BasePart") then
			look.CanQuery = true
		end
	end
	-- the slap when it lands
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < 3 and root.Parent do
			task.wait(0.05)
			if root.AssemblyLinearVelocity.Y > -1 and os.clock() - start > 0.15 then
				Sfx.play("Drop", root.Position)
				return
			end
		end
	end)
end

-- The shears cut through the ribs: the chest plate can be lifted.
function Organs.crack(organ: Organ)
	if not organ.locked then
		return
	end
	organ.locked = false
	local at = organ.root.Position
	Sfx.play("Crack", at)
	Blood.spray(at, UP, 3.5)
end

function Organs.destroy(set: Set)
	Organs.release(set)
	set.folder:Destroy()
end

return Organs
