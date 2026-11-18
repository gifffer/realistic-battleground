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
--   • under the torso: the real cut through the hips (Z-Anatomy), standing
--     proud of the torso's face: the hip bones and the sacrum in section
--     (a hard white rim round the yellow-red spongy bone), the glutei and
--     the iliopsoas cut (domed, two reds, thin pearly fascia between
--     them), the belly's front packed with loops of small intestine cut
--     across (pink rings, red lining, chyme) in their yellow fat, the
--     bladder and the colon cut across, the arteries and veins as open
--     tubes (an artery's lumen red, a vein's clotted), the sciatic nerves
--     (yellowish cords), the yellow fat under the skin, the skin torn round
--     the edge, blood hanging in drops, two loops of small intestine
--     hanging out on their mesentery;
--   • on each leg's top: a real section of the upper thigh (the femur's
--     shaft - a thick white ring round its marrow - the big thigh muscles,
--     the femoral artery and vein side by side, the sciatic nerve, fat,
--     skin, blood pooling round the artery);
--   • anything drawn flat on those faces (a burn's pictures, a decal) is
--     hidden: the cut is there now;
--   • when it happens in front of us (not a body we only see later): the
--     portal's mark - the cut faces white-hot green at first, their edges
--     glowing, fading to raw flesh (cauterised for a moment), rift energy
--     crackling over them in arcs and sparks, a ring of green energy and
--     blood mist bursting out along the cut plane, green motes drifting
--     off - then a burst of blood both ways, a geyser out of each leg's
--     femoral artery while they stand, the iliac arteries pumping out of the
--     upper body, blood running down the legs, loose coils of intestine
--     (salmon pink, smeared with blood, on their see-through mesentery) and
--     a length of colon falling out
--     on the floor, the torso dripping.
-- Pieces from WoundKit (GoreKit "RiftWaist" / "RiftHipR" / "RiftHipL" /
-- "RiftGut<i>" / "RiftColon"); simpler ones drawn here without them (an older kit).
--
--   WaistCut.apply(model, live)   draws the wounds (once per body)
--   WaistCut.isApplied(model)     whether it has been drawn on this body

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local GoreKit = require(script.Parent.GoreKit)
local Blood = require(script.Parent.Blood)
local BloodGush = require(script.Parent.BloodGush)
local POOLS = Config.Blood.FINISHER_POOLS
local Squish = require(script.Parent.Squish)

local WaistCut = {}

WaistCut.ATTRIBUTE = "CutInHalf"

local BLOOD = Color3.fromRGB(78, 6, 6)
local BLOOD_WET = Color3.fromRGB(124, 8, 10)
local FLESH = Color3.fromRGB(140, 24, 28)
local FLESH_DARK = Color3.fromRGB(64, 6, 10)
local BONE = Color3.fromRGB(242, 236, 218)
-- The inside of the body cut across (gore.py's layers), as it looks, the
-- contrast pushed so it reads from a few studs away in daylight (Roblox
-- lighting washes colours out: pale ones turn white). Wet (shine) except
-- bone, nerve and fascia.
local MUSCLE = Color3.fromRGB(172, 22, 28) -- raw red, a darker one beside it
local MUSCLE_DARK = Color3.fromRGB(118, 12, 20)
local FASCIA = Color3.fromRGB(226, 204, 196) -- the thin pearly sheaths between them
local FAT = Color3.fromRGB(242, 190, 62) -- yellow lobules under the skin
local MARROW = Color3.fromRGB(206, 110, 48) -- the spongy bone inside the rim: yellow-red
local GUT = Color3.fromRGB(212, 118, 108) -- small intestine: salmon pink, wet
local COLON = Color3.fromRGB(176, 112, 92) -- the colon: browner, duller
local MUCOSA = Color3.fromRGB(176, 30, 44) -- the gut's velvety red lining
local LUMEN = Color3.fromRGB(78, 52, 20) -- what was in the colon
local CHYME = Color3.fromRGB(176, 146, 46) -- what was in the small intestine
local URINE = Color3.fromRGB(226, 174, 40)
local MESENTERY = Color3.fromRGB(184, 74, 78) -- the gut's thin sheet: red-pink, see-through
local ARTERY = Color3.fromRGB(232, 184, 172) -- thick pale wall (its open lumen: Blood)
local VEIN = Color3.fromRGB(58, 26, 60) -- thin, dark blue-purple, collapsed
local CLOT = Color3.fromRGB(42, 2, 6)
local NERVE = Color3.fromRGB(236, 212, 128) -- a yellowish cord
local VESSEL = Color3.fromRGB(150, 14, 30) -- the small ones on the gut
-- The portal's mark on the cut (Dr. Rift's rift green, RiftParts).
local RIFT_GREEN = Color3.fromRGB(110, 255, 96)
local RIFT_GLOW = Color3.fromRGB(170, 255, 150)
local HOT = Color3.fromRGB(232, 255, 222) -- white-hot, a little green
local EMBER = Color3.fromRGB(120, 30, 12) -- what the hot rim cools to
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local CAUTERISED = 1.8 -- seconds the cut faces glow
local CRACKLE = 1.5 -- seconds the energy crackles over them (motes a bit longer)
local DRIP_TIME = 10 -- seconds the upper body drips
local GUT_LIFETIME = 25 -- seconds the loose loops of gut stay on the floor
-- Where the cut arteries are (gore.py: the real vessels' section, widened
-- to the R6 parts; the ends of the Vessel stubs in WoundKit). Each leg's
-- femoral artery, in its own space (its top at Y = 1); the upper body's
-- (there is no aorta this low: the two external iliac / femoral arteries,
-- right and left), in the torso's.
local FEMORAL: { [string]: Vector3 } = {
	["Right Leg"] = Vector3.new(-0.25, 1.12, -0.36),
	["Left Leg"] = Vector3.new(0.25, 1.12, -0.36),
}
local ILIAC = { Vector3.new(0.47, -1.14, -0.19), Vector3.new(-0.47, -1.12, -0.19) }
local CUT = CFrame.new(0, -1, 0) -- the torso's cut face (torso space)
-- What falls out of the upper body (GoreKit pieces), in order.
local SPILL = { "RiftGut1", "RiftGut2", "RiftGut3", "RiftColon" }

-- A face of the cut: its part, where it is in the part's space (`at`: its
-- centre, Y out of the cut), its half size (X, Z), the gore drawn on it.
type Face = { part: BasePart, at: CFrame, half: Vector2, gore: Model }

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

-- Each layer's colour and shine (Reflectance: the wet ones shine; kept low,
-- since Reflectance mirrors the sky - much more and gut reads as chrome or
-- plastic, not wet). `skin` = the body's own skin colour.
local LAYERS: { [string]: { Color3 | number } } = {
	Bone = { BONE, 0.04 },
	Marrow = { MARROW, 0.06 },
	FleshDark = { FLESH_DARK, 0.12 },
	Muscle = { MUSCLE, 0.12 },
	MuscleDark = { MUSCLE_DARK, 0.12 },
	Fascia = { FASCIA, 0.1 },
	Fat = { FAT, 0.12 },
	Gut = { GUT, 0.12 },
	Colon = { COLON, 0.1 },
	Mucosa = { MUCOSA, 0.13 },
	Lumen = { LUMEN, 0.12 },
	Chyme = { CHYME, 0.16 },
	Urine = { URINE, 0.18 },
	Mesentery = { MESENTERY, 0.1 },
	Artery = { ARTERY, 0.12 },
	Vein = { VEIN, 0.14 },
	Clot = { CLOT, 0.16 },
	Nerve = { NERVE, 0.06 },
	Vessel = { VESSEL, 0.12 },
	Blood = { BLOOD_WET, 0.2 },
}
-- The see-through layers of a loose length of gut (its thin mesentery).
local SHEER: { [string]: number } = { Mesentery = 0.25 }

local function painter(skin: Color3): (layer: string) -> (Color3, number)
	return function(layer: string): (Color3, number)
		if layer == "Skin" then
			return skin, 0
		end
		local look = LAYERS[layer]
		if look then
			return look[1] :: Color3, look[2] :: number
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

local warnedMissing: { [string]: boolean } = {}

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

-- Whatever is drawn flat on the face the cut went through (a burn's
-- pictures, a decal: on a SurfaceGui, Decal or Texture of that face) is
-- hidden for good: the cut is drawn there now. (What adds them later, a
-- burn still spreading, is caught too.)
local function clearFace(part: BasePart, face: Enum.NormalId)
	local function hide(item: Instance)
		if item:IsA("SurfaceGui") and item.Face == face then
			item.Enabled = false
			-- (a burn turns its pictures on and off with the body's
			-- transparency: kept off)
			item:GetPropertyChangedSignal("Enabled"):Connect(function()
				if item.Enabled then
					item.Enabled = false
				end
			end)
		elseif item:IsA("Decal") and item.Face == face then
			item.Transparency = 1
		end
	end
	for _, item in part:GetDescendants() do
		hide(item)
	end
	-- (the connection goes with the part)
	part.DescendantAdded:Connect(function(item: Instance)
		-- (a SurfaceGui's face is set before or right after it is parented)
		task.defer(hide, item)
	end)
end

-- The kit's piece `name` (in `part`'s own space) on `part`, or simple
-- shapes without it. Returns what was drawn (a Model: the portal's glow
-- lights it all up).
local function dress(part: BasePart, name: string, skin: Color3, random: Random): Model
	local folder = Instance.new("Model")
	folder.Name = "WaistCut"
	local pieces = GoreKit.get()
	local piece = if pieces then pieces[name] else nil
	if piece then
		weldTo(part, GoreKit.spawn(piece, part.CFrame, painter(skin)), folder)
	elseif name == "RiftWaist" then
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
		-- A leg's top: a real cross-section of the thigh, built from parts
		-- (the kit's piece missing). Leg space, the face at Y = top: the
		-- skin rim, the yellow fat under it, the big muscles as separate red
		-- bellies with pale sheaths between them, the femur (white rim,
		-- yellow-red marrow) a little to the outside and back, the femoral
		-- artery (open, pale wall), the vein (dark, collapsed) and the nerve
		-- (a yellow cord) in front and inside, blood pooling over it all.
		if not warnedMissing[name] then
			warnedMissing[name] = true
			warn(
				`[WaistCut] WoundKit has no "{name}" piece: re-import assets/wounds/WoundKit.fbx (docs/WOUNDS_FR.md)`
			)
		end
		local sx, sz = part.Size.X, part.Size.Z
		local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
		local sign = if name == "RiftHipR" then 1 else -1 -- (+X = outside for the right leg)
		local upright = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis (X) up
		local function slab(label: string, size: Vector3, color: Color3, lift: number, at: Vector3?)
			local bit = simplePart(label, Enum.PartType.Block, size, color)
			bit.CFrame = top * CFrame.new((at or Vector3.zero) + Vector3.new(0, lift, 0))
			weldTo(part, bit, folder)
			return bit
		end
		local function disc(
			label: string,
			d: number,
			h: number,
			color: Color3,
			x: number,
			z: number,
			lift: number,
			squash: number?
		)
			local bit = simplePart(label, Enum.PartType.Cylinder, Vector3.new(h, d, d), color)
			bit.CFrame = top * CFrame.new(x, lift, z) * upright
			if squash then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Cylinder
				mesh.Scale = Vector3.new(1, 1, squash)
				mesh.Parent = piece
			end
			weldTo(part, bit, folder)
			return bit
		end
		-- Skin (the rim), the fat under it, the dark deep flesh as a floor.
		slab("Skin", Vector3.new(sx + 0.03, 0.06, sz + 0.03), skin, 0.02)
		slab("Fat", Vector3.new(sx - 0.04, 0.08, sz - 0.04), FAT, 0.03)
		slab("Deep", Vector3.new(sx - 0.16, 0.09, sz - 0.16), FLESH_DARK, 0.035)
		-- The muscle bellies (quadriceps in front, adductors inside,
		-- hamstrings behind, the gluteal side), bulging a little, two reds.
		local bellies = {
			{ x = 0.02, z = -0.24, d = 0.42, c = MUSCLE }, -- rectus / vastus in front
			{ x = 0.25 * sign, z = -0.08, d = 0.36, c = MUSCLE_DARK }, -- vastus lateralis
			{ x = -0.22 * sign, z = -0.02, d = 0.38, c = MUSCLE_DARK }, -- adductors
			{ x = -0.12 * sign, z = 0.24, d = 0.36, c = MUSCLE }, -- hamstrings
			{ x = 0.2 * sign, z = 0.24, d = 0.34, c = MUSCLE_DARK }, -- gluteal / biceps
			{ x = 0.05 * sign, z = 0.06, d = 0.3, c = MUSCLE }, -- vastus intermedius
		}
		for _, belly in bellies do
			local d = belly.d * math.min(sx, sz) + random:NextNumber(-0.02, 0.02)
			-- (a pale sheath round it, then the meat)
			disc("Fascia", d + 0.035, 0.1, FASCIA, belly.x * sx, belly.z * sz, 0.055)
			disc(
				"Muscle",
				d,
				0.12 + random:NextNumber(0, 0.03),
				belly.c,
				belly.x * sx,
				belly.z * sz,
				0.06
			)
		end
		-- The femur: cortical rim, marrow inside, standing proud of the meat.
		local fx, fz = 0.1 * sign * sx, 0.06 * sz
		disc("Bone", 0.24 * sx, 0.18, BONE, fx, fz, 0.08)
		disc("Marrow", 0.15 * sx, 0.185, MARROW, fx, fz, 0.083)
		-- The femoral artery (pale wall, open red lumen), the vein beside it
		-- (dark, flattened), the nerve (yellow) - in front, inside.
		local ax, az = -0.18 * sign * sx, -0.3 * sz
		disc("Artery", 0.11 * sx, 0.22, ARTERY, ax, az, 0.09)
		disc("Lumen", 0.06 * sx, 0.225, BLOOD_WET, ax, az, 0.092)
		disc("Vein", 0.12 * sx, 0.15, VEIN, ax - 0.1 * sign * sx, az + 0.02, 0.07, 0.55)
		disc("Nerve", 0.06 * sx, 0.16, NERVE, ax + 0.09 * sign * sx, az - 0.03, 0.075)
		-- Blood pooling on the face, glossy, and a clot.
		local pool = disc(
			"Blood",
			0.55 * sx,
			0.02,
			BLOOD_WET,
			random:NextNumber(-0.1, 0.1),
			random:NextNumber(-0.1, 0.1),
			0.14,
			0.8
		)
		pool.Transparency = 0.25
		pool.Reflectance = 0.2
		disc("Clot", 0.14 * sx, 0.05, CLOT, -0.05 * sign * sx, 0.2 * sz, 0.12)
		simpleFlaps(part, top, Vector2.new(0.5, 0.5), skin, random, folder)
	end
	folder.Parent = part
	return folder
end

-- `piece` with its tube's wall first (GoreKit.spawn makes the first layer
-- the main part: the one that collides, squashes and is shown by Squish's
-- copy; by size alone it can be the blood smeared on it, a hair bigger).
local function bodyFirst(piece: GoreKit.Piece): GoreKit.Piece
	local layers = table.clone(piece.layers)
	for index, layer in layers do
		if layer.name == "Gut" or layer.name == "Colon" then
			table.remove(layers, index)
			table.insert(layers, 1, layer)
			return { name = piece.name, layers = layers, center = layer.offset.Position }
		end
	end
	return piece
end

-- A loose length of gut (`name`: GoreKit's "RiftGut<i>" / "RiftColon"), falling
-- out of the torso's cut at `at` (world).
local function newGut(name: string, at: CFrame, random: Random): BasePart
	local pieces = GoreKit.get()
	local piece = if pieces then pieces[name] else nil
	local gut: BasePart
	if piece then
		gut = GoreKit.spawn(bodyFirst(piece), at, painter(GUT))
		-- (its mesentery a thin sheet: the light comes through it)
		local layers: { Instance } = gut:GetDescendants()
		table.insert(layers, gut)
		for _, layer in layers do
			local kind = string.match(layer.Name, "_(%a+)$")
			local sheer = if kind then SHEER[kind] else nil
			if sheer and layer:IsA("BasePart") then
				layer.Transparency = sheer
			end
		end
	else
		-- (a sphere mesh, not a cylinder part: it can be squashed)
		local loop = Instance.new("Part")
		loop.Name = "Gut"
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = loop
		local thick = if name == "RiftColon" then 0.3 else 0.2
		loop.Size = Vector3.new(random:NextNumber(0.9, 1.4), thick, thick + 0.02)
		loop.Material = Enum.Material.SmoothPlastic
		loop.Color = if name == "RiftColon" then COLON else GUT
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

-- The coils of small intestine and the colon slipping out of the upper body
-- as it falls: soft and wet, they slap on the floor and stay there a while.
local function spill(torso: BasePart, model: Model, random: Random)
	for index, name in SPILL do
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
			local gut = newGut(name, at, random)
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
			-- (the simple loop gets its surface detail drawn on, first, in
			-- the workspace: then it squashes too. The kit's gut has its
			-- own - vessels, smeared blood - and flat discs stuck on a tube
			-- that thin stick out of it as fins)
			local pieces = GoreKit.get()
			if pieces == nil or pieces[name] == nil then
				Squish.detail(gut, "Liver")
			end
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

-- ---- the portal's mark: the cut faces seared for a moment ----

local function sparkEmitter(parent: Attachment): ParticleEmitter
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "RiftSparks"
	sparks.Texture = SPARKLE
	sparks.Color = ColorSequence.new(HOT, RIFT_GREEN)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.09),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new(0, 0.3)
	sparks.Lifetime = NumberRange.new(0.12, 0.35)
	sparks.Speed = NumberRange.new(2, 7)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -12, 0)
	sparks.Drag = 3
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Rate = 0
	sparks.Parent = parent
	return sparks
end

local function moteEmitter(parent: Attachment): ParticleEmitter
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "RiftMotes"
	motes.Texture = SPARKLE
	motes.Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN)
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(0.3, 0.07),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Lifetime = NumberRange.new(1.2, 2.4)
	motes.Speed = NumberRange.new(0.2, 0.8)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Acceleration = Vector3.new(0, 0.7, 0)
	motes.Drag = 1
	motes.RotSpeed = NumberRange.new(-90, 90)
	motes.Rate = 0
	motes.Parent = parent
	return motes
end

-- The cut face white-hot at first (the portal sears it): the whole face lit
-- green-white, fading to the raw flesh under it, its edge a glowing rim
-- cooling to a dull ember, a green light dying out.
local function cauterise(face: Face)
	local fade = TweenInfo.new(CAUTERISED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local glow = Instance.new("Highlight")
	glow.Name = "Seared"
	glow.FillColor = RIFT_GLOW
	glow.OutlineColor = HOT
	glow.FillTransparency = 0.2
	glow.OutlineTransparency = 0
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = face.gore
	glow.Parent = face.gore
	TweenService:Create(glow, fade, { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(glow, CAUTERISED + 0.1)
	-- the rim: four thin white-hot bars along the edge
	local rim = Instance.new("Folder")
	rim.Name = "SearedRim"
	local hx, hz = face.half.X, face.half.Y
	local bars: { { CFrame | Vector3 } } = {
		{ CFrame.new(0, 0, -hz), Vector3.new(hx * 2 + 0.05, 0.05, 0.05) },
		{ CFrame.new(0, 0, hz), Vector3.new(hx * 2 + 0.05, 0.05, 0.05) },
		{ CFrame.new(-hx, 0, 0), Vector3.new(0.05, 0.05, hz * 2 + 0.05) },
		{ CFrame.new(hx, 0, 0), Vector3.new(0.05, 0.05, hz * 2 + 0.05) },
	}
	for _, bar in bars do
		local size = bar[2] :: Vector3
		local hot = Instance.new("Part")
		hot.Name = "Rim"
		hot.Material = Enum.Material.Neon
		hot.Color = HOT
		hot.Size = size
		hot.CastShadow = false
		hot.CFrame = face.part.CFrame * face.at * (bar[1] :: CFrame)
		weldTo(face.part, hot, rim)
		-- (thinner as it cools)
		local thin = Vector3.new(
			if size.X > 0.1 then size.X else 0.02,
			0.02,
			if size.Z > 0.1 then size.Z else 0.02
		)
		TweenService:Create(hot, fade, { Color = EMBER, Transparency = 1, Size = thin }):Play()
	end
	rim.Parent = face.part
	Debris:AddItem(rim, CAUTERISED + 0.1)
	local point = Instance.new("Attachment")
	point.Name = "SearedLight"
	point.CFrame = face.at * CFrame.new(0, 0.4, 0)
	point.Parent = face.part
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 3
	light.Range = 7
	light.Shadows = false
	light.Parent = point
	TweenService:Create(light, fade, { Brightness = 0 }):Play()
	Debris:AddItem(point, CAUTERISED + 0.1)
end

-- Rift energy left on the cut: short arcs jumping over the face (Beams
-- bowed out of it, redrawn every few frames, thinning out), sparks spat
-- off it, then green motes drifting up off it a little longer.
local function crackle(face: Face, seed: number)
	local random = Random.new(seed)
	local part = face.part
	local arcs: { { a0: Attachment, a1: Attachment, beam: Beam } } = {}
	for _ = 1, 3 do
		local a0 = Instance.new("Attachment")
		a0.Name = "RiftArc"
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Name = "RiftArc"
		a1.Parent = part
		local beam = Instance.new("Beam")
		beam.Name = "RiftArc"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(HOT, RIFT_GREEN)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 10
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 0.4),
		})
		beam.Parent = part
		table.insert(arcs, { a0 = a0, a1 = a1, beam = beam })
	end
	local point = Instance.new("Attachment")
	point.Name = "RiftSparks"
	point.Parent = part
	local sparks = sparkEmitter(point)
	local motes = moteEmitter(point)
	local hx, hz = face.half.X * 0.92, face.half.Y * 0.92
	-- (a point on the face, its X axis out of it: the arcs bow outward)
	local function onFace(x: number, z: number): CFrame
		return face.at * CFrame.new(x, 0.03, z) * CFrame.Angles(0, 0, math.pi / 2)
	end
	task.spawn(function()
		local start = os.clock()
		local stop = start + CRACKLE + 1.2
		while os.clock() < stop and part.Parent ~= nil do
			local left = 1 - (os.clock() - start) / CRACKLE -- (1 -> 0 while it crackles)
			for _, arc in arcs do
				local on = left > 0 and random:NextNumber() < 0.4 + 0.5 * left
				arc.beam.Enabled = on
				if on then
					local x, z = random:NextNumber(-hx, hx), random:NextNumber(-hz, hz)
					local reach = random:NextNumber(0.2, 0.6)
					local turn = random:NextNumber(0, math.pi * 2)
					local x1 = math.clamp(x + math.cos(turn) * reach, -hx, hx)
					local z1 = math.clamp(z + math.sin(turn) * reach, -hz, hz)
					arc.a0.CFrame = onFace(x, z)
					arc.a1.CFrame = onFace(x1, z1)
					local bow = random:NextNumber(0.05, 0.3)
					arc.beam.CurveSize0 = bow
					arc.beam.CurveSize1 = -bow * random:NextNumber(0.5, 1.5)
					local width = random:NextNumber(0.025, 0.07) * (0.3 + 0.7 * left)
					arc.beam.Width0 = width
					arc.beam.Width1 = width * random:NextNumber(0.3, 1)
				end
			end
			point.CFrame = face.at
				* CFrame.new(random:NextNumber(-hx, hx), 0.03, random:NextNumber(-hz, hz))
			if left > 0 then
				sparks:Emit(random:NextInteger(1, 3))
			end
			if random:NextNumber() < 0.6 then
				motes:Emit(1)
			end
			task.wait(random:NextNumber(0.04, 0.09))
		end
		for _, arc in arcs do
			arc.beam:Destroy()
			arc.a0:Destroy()
			arc.a1:Destroy()
		end
		-- (the last motes and sparks still in the air: they go out first)
		Debris:AddItem(point, 2.5)
	end)
end

-- The moment of the cut, out along the cut plane (`plane`: its centre, Y up
-- out of it): a ring of green energy flung out wide and fading (two Beam
-- rings, a white one ahead), sparks and a red mist of blood thrown out flat
-- all round.
local function ringBurst(plane: CFrame, seed: number)
	local random = Random.new(seed)
	local holder = Instance.new("Part")
	holder.Name = "WaistCutRing"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.CFrame = plane
	type Ring = {
		points: { Attachment },
		beams: { Beam },
		reach: number,
		time: number,
		width: number,
	}
	local rings: { Ring } = {}
	for _, look in
		{
			{
				color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
				reach = 5.5,
				time = 0.55,
				width = 0.7,
			},
			{ color = ColorSequence.new(HOT), reach = 7, time = 0.4, width = 0.18 },
		}
	do
		local ring: Ring =
			{ points = {}, beams = {}, reach = look.reach, time = look.time, width = look.width }
		for _ = 1, 4 do
			local point = Instance.new("Attachment")
			point.Parent = holder
			table.insert(ring.points, point)
		end
		for i = 1, 4 do
			local beam = Instance.new("Beam")
			beam.Attachment0 = ring.points[i]
			beam.Attachment1 = ring.points[i % 4 + 1]
			beam.Color = look.color
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.FaceCamera = true
			beam.Segments = 16
			beam.Parent = holder
			table.insert(ring.beams, beam)
		end
		table.insert(rings, ring)
	end
	local center = Instance.new("Attachment")
	center.Parent = holder
	local energy = sparkEmitter(center)
	energy.Color = ColorSequence.new(HOT, RIFT_GREEN)
	energy.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	energy.Speed = NumberRange.new(16, 26)
	energy.Lifetime = NumberRange.new(0.25, 0.55)
	energy.Drag = 5
	energy.SpreadAngle = Vector2.new(4, 4)
	energy.Acceleration = Vector3.zero
	energy.EmissionDirection = Enum.NormalId.Front
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "BloodMist"
	mist.Texture = SMOKE
	mist.Color = ColorSequence.new(BLOOD_WET, BLOOD)
	mist.LightEmission = 0
	mist.LightInfluence = 1
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1.3),
	})
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Lifetime = NumberRange.new(0.6, 1.1)
	mist.Speed = NumberRange.new(7, 13)
	mist.Drag = 4
	mist.SpreadAngle = Vector2.new(6, 6)
	mist.Acceleration = Vector3.new(0, -5, 0)
	mist.RotSpeed = NumberRange.new(-60, 60)
	mist.Rotation = NumberRange.new(0, 360)
	mist.EmissionDirection = Enum.NormalId.Front
	mist.Rate = 0
	mist.Parent = center
	holder.Parent = workspace
	-- flat all round: the emitter turned round the plane's normal between
	-- bursts (each particle keeps the way it was thrown)
	for i = 1, 18 do
		center.CFrame = CFrame.Angles(0, (i + random:NextNumber(-0.4, 0.4)) / 18 * math.pi * 2, 0)
		energy:Emit(2)
		mist:Emit(1)
	end
	local start = os.clock()
	local step: RBXScriptConnection
	step = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - start
		local alive = false
		for _, ring in rings do
			local t = math.clamp(elapsed / ring.time, 0, 1)
			alive = alive or t < 1
			local ease = 1 - (1 - t) ^ 3
			local radius = 0.4 + (ring.reach - 0.4) * ease
			-- (a circle from four Bezier quarters: each point's axis along it)
			for i, point in ring.points do
				local angle = (i - 1) / 4 * math.pi * 2
				local at = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
				local along = Vector3.new(-math.sin(angle), 0, math.cos(angle))
				point.CFrame = CFrame.fromMatrix(at, along, Vector3.yAxis)
			end
			for _, beam in ring.beams do
				beam.CurveSize0 = radius * 0.5523
				beam.CurveSize1 = radius * 0.5523
				beam.Width0 = ring.width * (1 - 0.7 * ease)
				beam.Width1 = beam.Width0
				beam.Transparency = NumberSequence.new(t ^ 1.5)
			end
		end
		if not alive or holder.Parent == nil then
			step:Disconnect()
			for _, ring in rings do
				for _, beam in ring.beams do
					beam.Enabled = false
				end
			end
		end
	end)
	-- (the particles still in the air: then it goes)
	Debris:AddItem(holder, 1.4)
end

-- The portal's mark on every face of the cut, as it happens.
local function sear(faces: { Face }, plane: CFrame, seed: number)
	ringBurst(plane, seed)
	for index, face in faces do
		cauterise(face)
		crackle(face, seed + index * 31)
	end
end

-- Where the big pools pour: the middle of the torso's cut face, the top of
-- a leg (in their own space).
local function torsoEnd(torso: BasePart): Vector3
	return Vector3.new(0, -torso.Size.Y / 2 - 0.05, 0)
end
local function legEnd(leg: BasePart): Vector3
	return Vector3.new(0, leg.Size.Y / 2 + 0.05, 0)
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
			pool = 0, -- (the big pools: BloodGush.stump, below)
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
			pool = 0,
			seed = seed + 3 + index * 11,
			ignore = ignore,
		})
	end
	drip(torso)
	spill(torso, model, random)
	-- the big pools: the upper body's (aorta, vena cava: the most blood)
	-- where it falls and lies, the legs' under them (standing, then folded)
	BloodGush.stump(torso, torsoEnd(torso), POOLS.WAIST_TORSO, seed + 101, { ignore = ignore })
	if legs[1] then
		BloodGush.stump(legs[1], legEnd(legs[1]), POOLS.WAIST_LEGS, seed + 102, { ignore = ignore })
	end
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
	local faces: { Face } = {
		{
			part = torso,
			at = CFrame.new(0, -torso.Size.Y / 2 - 0.07, 0) * CFrame.Angles(math.pi, 0, 0),
			half = Vector2.new(torso.Size.X / 2, torso.Size.Z / 2),
			gore = dress(torso, "RiftWaist", torso.Color, random),
		},
	}
	clearFace(torso, Enum.NormalId.Bottom)
	local legs: { BasePart } = {}
	for _, pair in { { "Right Leg", "RiftHipR" }, { "Left Leg", "RiftHipL" } } do
		local leg = model:FindFirstChild(pair[1])
		if leg and leg:IsA("BasePart") then
			-- (each leg's own skin colour: the cut shows it at the rim)
			table.insert(faces, {
				part = leg,
				at = CFrame.new(0, leg.Size.Y / 2 + 0.05, 0),
				half = Vector2.new(leg.Size.X / 2, leg.Size.Z / 2),
				gore = dress(leg, pair[2], leg.Color, random),
			})
			table.insert(legs, leg)
			clearFace(leg, Enum.NormalId.Top)
		end
	end
	if live then
		-- (the cut plane where it is now: the torso's bottom, still on the legs)
		local plane = CFrame.new((torso.CFrame * CUT).Position) * torso.CFrame.Rotation
		sear(faces, plane, seed)
		bleed(model, torso, legs, seed, random)
	else
		-- (a body we only see now, or its frozen copy: the pools are there)
		BloodGush.lay(torso, torsoEnd(torso), POOLS.WAIST_TORSO, seed + 101)
		if legs[1] then
			BloodGush.lay(legs[1], legEnd(legs[1]), POOLS.WAIST_LEGS, seed + 102)
		end
	end
end

return table.freeze(WaistCut)
