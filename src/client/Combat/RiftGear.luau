--!strict
-- RiftGear: Dr. Rift's cyborg arm, on anyone with the "Rift" kit (his clones
-- too): the mechanical left arm ending in the gravity glove.
--
--   RiftGear.watch(model)     dressed while its "Kit" attribute is "Rift"
--   RiftGear.palmOf(model)    the glove's emitter (where its power comes out)
--
-- The gear is the RiftGear meshes when the place has them (RiftAssets:
-- salvaged plates, servos, pistons, hoses, a power cell, an articulated
-- metal hand); without them (an old place) a simpler version built from
-- parts. Either way it is measured once built and fitted on the real Left
-- Arm (fitArm: scaled and moved so its shoulder pad sits on the top of the
-- arm, its glove at the hand, flush with the torso), so an import that
-- scaled or moved the meshes, or a bigger character, cannot misplace it.
-- The real Left Arm is hidden while he wears the mechanical one (on this
-- client: its Transparency, saved and given back when the kit changes), and
-- so is what lies on its skin (the cuts of Gashes, the bruises of Wounds,
-- blood stuck to it); everything is welded to the arm, so it follows the
-- animations and the ragdoll.

local Players = game:GetService("Players")

local RiftGear = {}

local KIT = "Rift"
local P = require(script.Parent.RiftParts)
local RiftAssets = require(script.Parent.RiftAssets)
local STEEL = P.STEEL
local STEEL_DARK = P.STEEL_DARK
local BRASS = P.BRASS
local CABLE = P.CABLE
local RIFT_GREEN = P.RIFT_GREEN
local RIFT_GLOW = P.RIFT_GLOW
local ghost = P.ghost
local stick = P.stick
local emitter = P.emitter
local sparkTexture = P.sparkTexture

local CHROME = Color3.fromRGB(198, 202, 208)
local ALONG_X_TO_Y = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis (X) → Y

-- How the mechanical arm sits on the real one, in fractions of the Left
-- Arm's size (tools/rift/build_rift_gear.py, fit_arm, draws its pictures the
-- same way):
local ARM_LENGTH = 1.1 -- its height (2.2 studs on a 2-stud arm: the glove a bit past the hand)
local SHOULDER_CAP = 0.025 -- how far its shoulder pad rises over the arm's top
local INNER = 0.48 -- nothing past this toward the torso (+X: the torso's side is at 0.5)
local MAX_WIDTH = 1.25 -- the widest it may be (X: the shoulder servo sticks out, outside)
local MAX_DEPTH = 1.12 -- the deepest (Z)

type Dressed = {
	arm: BasePart,
	armGear: Folder,
	armTransparency: number, -- the real arm's, given back when undressed
	-- what we hid on the arm's skin, and what to give back: a Transparency
	-- (a part, a decal) or a Visible (a picture of a SurfaceGui)
	hidden: { [Instance]: number | boolean },
	hiddenCount: number, -- (entries since the gone ones were last dropped)
	connections: { RBXScriptConnection },
}

local gear: { [Model]: Dressed } = setmetatable({}, { __mode = "k" }) :: any

------------------------------------------------------------------------------
-- Shapes from parts (no RiftGear meshes)
------------------------------------------------------------------------------

local function metal(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	return ghost(name, size, color, Enum.Material.Metal, shape)
end

-- A cylinder of radius r and length h (its axis along X).
local function cylinder(
	name: string,
	r: number,
	h: number,
	color: Color3,
	material: Enum.Material?
): Part
	return ghost(
		name,
		Vector3.new(h, r * 2, r * 2),
		color,
		material or Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
end
-- A finger of the glove: segments from its knuckle, hanging down and
-- curling, a little more at each joint, toward `out` (the palm's side), as
-- in the meshes.
local function buildFinger(
	add: (BasePart, CFrame) -> (),
	base: Vector3,
	out: Vector3,
	curls: { number },
	lengths: { number },
	width: number
)
	local side = out:Cross(Vector3.new(0, -1, 0)).Unit -- the joints' axis
	local at = base
	add(
		ghost(
			"Knuckle",
			Vector3.new(width, width, width),
			STEEL_DARK,
			Enum.Material.Metal,
			Enum.PartType.Ball
		),
		CFrame.new(at)
	)
	local total = 0
	for index, curl in curls do
		local length = lengths[index]
		total += math.rad(curl)
		local d = (Vector3.new(0, -1, 0) * math.cos(total) + out * math.sin(total)).Unit
		local w = width * (1 - 0.08 * (index - 1))
		local frame = CFrame.fromMatrix(at + d * (length / 2), side, d)
		add(metal("Finger", Vector3.new(w, length, w * 1.05), STEEL), frame)
		at += d * length
		if index < #curls then
			add(
				ghost(
					"Joint",
					Vector3.new(w * 0.85, w * 0.85, w * 0.85),
					STEEL_DARK,
					Enum.Material.Metal,
					Enum.PartType.Ball
				),
				CFrame.new(at)
			)
		end
	end
	add(
		ghost(
			"Fingertip",
			Vector3.new(width * 0.8, width * 0.8, width * 0.8),
			STEEL_DARK,
			Enum.Material.Metal,
			Enum.PartType.Ball
		),
		CFrame.new(at)
	)
end

-- The mechanical left arm from parts (Left Arm space: 1 x 2 x 1, the
-- shoulder at Y = +1, the hand's end at Y = -1; +X faces the torso, -Z is
-- the front). The same arm as the meshes: a pauldron, a narrower upper arm,
-- the elbow servo, a forearm tapering to the wrist, a hand hanging with its
-- palm (the emitter) toward the body, its fingers together, the thumb in
-- front. fitArm then puts it at its place.
local function buildArmParts(arm: BasePart, folder: Folder)
	local function add(part: BasePart, offset: CFrame)
		stick(arm, part, offset, folder)
	end
	local cx = -0.03 -- the arm's own axis
	-- The shoulder: a rounded pauldron, a lame under its outer edge, the
	-- dark joint inside.
	local dome = metal("Pauldron", Vector3.new(1.04, 0.5, 1.02), STEEL)
	local round = Instance.new("SpecialMesh")
	round.MeshType = Enum.MeshType.Sphere
	round.Parent = dome
	add(dome, CFrame.new(cx - 0.05, 0.74, 0) * CFrame.Angles(0, 0, math.rad(8)))
	add(
		metal("Lame", Vector3.new(0.07, 0.17, 0.78), STEEL),
		CFrame.new(cx - 0.5, 0.6, 0) * CFrame.Angles(0, 0, math.rad(-14))
	)
	add(cylinder("ShoulderRing", 0.42, 0.04, BRASS), CFrame.new(cx, 0.62, 0) * ALONG_X_TO_Y)
	-- The upper arm: a dark core, an armour shell, two pistons (front, back).
	add(cylinder("UpperArm", 0.37, 0.5, STEEL_DARK), CFrame.new(cx, 0.37, 0) * ALONG_X_TO_Y)
	add(cylinder("Shell", 0.42, 0.3, STEEL), CFrame.new(cx, 0.33, 0) * ALONG_X_TO_Y)
	for _, z in { -0.47, 0.45 } do
		add(cylinder("Piston", 0.06, 0.36, STEEL_DARK), CFrame.new(cx, 0.32, z) * ALONG_X_TO_Y)
		local rod = cylinder("Rod", 0.032, 0.4, CHROME, Enum.Material.SmoothPlastic)
		rod.Reflectance = 0.3
		add(rod, CFrame.new(cx, -0.02, z * 0.95) * ALONG_X_TO_Y)
		add(cylinder("Mount", 0.055, 0.08, BRASS), CFrame.new(cx, -0.2, z * 0.92))
	end
	-- The elbow: a thin link, a servo across it, brass flanges, a chrome axle.
	add(cylinder("ElbowLink", 0.23, 0.3, STEEL_DARK), CFrame.new(cx, 0, 0) * ALONG_X_TO_Y)
	add(cylinder("Elbow", 0.22, 0.75, STEEL_DARK), CFrame.new(cx, 0, 0.03))
	for _, x in { cx - 0.39, cx + 0.39 } do
		add(cylinder("Flange", 0.24, 0.045, BRASS), CFrame.new(x, 0, 0.03))
	end
	local axle = cylinder("ElbowAxle", 0.07, 0.92, CHROME, Enum.Material.SmoothPlastic)
	axle.Reflectance = 0.3
	add(axle, CFrame.new(cx, 0, 0.03))
	-- The forearm: a dark core, three plate rings narrowing to the wrist,
	-- the glowing power cell in front.
	add(cylinder("Core", 0.3, 0.5, STEEL_DARK), CFrame.new(cx, -0.37, 0) * ALONG_X_TO_Y)
	for index, ring in { { -0.195, 0.45 }, { -0.36, 0.4 }, { -0.52, 0.35 } } do
		local plate = cylinder("Plate" .. index, ring[2], 0.14, STEEL)
		add(plate, CFrame.new(cx, ring[1], 0) * ALONG_X_TO_Y)
	end
	local cell = cylinder("Cell", 0.07, 0.36, RIFT_GREEN, Enum.Material.Neon)
	add(cell, CFrame.new(cx, -0.36, -0.42) * ALONG_X_TO_Y)
	for _, y in { -0.17, -0.55 } do
		add(cylinder("CellCap", 0.085, 0.04, BRASS), CFrame.new(cx, y, -0.42) * ALONG_X_TO_Y)
	end
	-- Hoses down the back.
	for _, x in { cx + 0.15, cx - 0.2 } do
		add(
			cylinder("Hose", 0.04, 0.8, CABLE, Enum.Material.Rubber),
			CFrame.new(x, 0.2, 0.43) * ALONG_X_TO_Y
		)
	end
	-- The wrist: narrow, a brass ring, a chrome collar.
	add(cylinder("Wrist", 0.31, 0.04, BRASS), CFrame.new(cx, -0.61, 0) * ALONG_X_TO_Y)
	add(
		cylinder("WristCollar", 0.25, 0.08, CHROME, Enum.Material.SmoothPlastic),
		CFrame.new(cx, -0.67, 0) * ALONG_X_TO_Y
	)
	-- The hand: flat, an armour plate on its back (outside), the emitter
	-- (Palm) in its palm (toward the body).
	add(metal("Hand", Vector3.new(0.33, 0.31, 0.59), STEEL_DARK), CFrame.new(cx, -0.87, 0))
	add(metal("BackOfHand", Vector3.new(0.07, 0.3, 0.63), STEEL), CFrame.new(cx - 0.19, -0.87, 0))
	add(cylinder("EmitterRing", 0.15, 0.025, BRASS), CFrame.new(cx + 0.175, -0.87, 0))
	add(
		cylinder("Palm", 0.12, 0.03, RIFT_GLOW, Enum.Material.Neon),
		CFrame.new(cx + 0.185, -0.87, 0)
	)
	add(
		cylinder("Knuckles", 0.09, 0.62, STEEL_DARK),
		CFrame.new(cx, -1.02, 0) * CFrame.Angles(0, math.rad(90), 0)
	)
	-- Four fingers side by side (front to back), the thumb in front.
	local toPalm = Vector3.new(1, 0, 0)
	for _, finger in
		{
			{ -0.225, 0.12, 0.095, 0.07 },
			{ -0.075, 0.13, 0.1, 0.075 },
			{ 0.075, 0.12, 0.095, 0.07 },
			{ 0.225, 0.1, 0.08, 0.065 },
		}
	do
		buildFinger(
			add,
			Vector3.new(cx, -1.035, finger[1]),
			toPalm,
			{ 6, 20, 28 },
			{ finger[2], finger[3], finger[4] },
			0.135
		)
	end
	buildFinger(
		add,
		Vector3.new(cx + 0.09, -0.83, -0.33),
		Vector3.new(0.55, 0, -0.35).Unit,
		{ 22, 16, 16 },
		{ 0.1, 0.08, 0.065 },
		0.145
	)
end

------------------------------------------------------------------------------
-- Dressing
------------------------------------------------------------------------------

-- Welds a spawned piece (placed at `base`'s CFrame times its offset) to `base`.
local function weldTo(base: BasePart, main: BasePart, folder: Folder)
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = main
	weld.C0 = base.CFrame:ToObjectSpace(main.CFrame)
	weld.Parent = main
	main.Parent = folder
end

-- A green light at `at` (a marker of the meshes: the power cell; or the
-- glowing part itself), out while `shown` is hidden (a light has no
-- Transparency to hide it with).
local function addLight(
	at: BasePart,
	shown: BasePart,
	range: number,
	brightness: number,
	connections: { RBXScriptConnection }
)
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = at
	local function follow()
		light.Enabled = shown.Transparency < 1
	end
	table.insert(connections, shown:GetPropertyChangedSignal("Transparency"):Connect(follow))
	follow()
end

-- A part of a spawned piece: a marker or a layer, by name.
local function partNamed(main: BasePart, name: string): BasePart?
	local found = if main.Name == name then main else main:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- Fits the built arm (every part in `folder`, welded to the arm or to each
-- other) on the real arm: measures the box round what it draws, in Left Arm
-- space, then scales it (uniformly, about the arm's centre) and moves it so
-- it is ARM_LENGTH arms tall, its top SHOULDER_CAP over the arm's top,
-- centred in Z, centred in X but never past INNER toward the torso; and
-- welds everything again where it now is. Whatever the meshes' import did
-- (another scale, another origin) and however big the character is, the
-- arm ends up the same on the shoulder. Done before the folder is parented
-- (its welds do nothing yet).
local function fitArm(arm: BasePart, folder: Folder)
	local space = arm.CFrame
	local parts: { BasePart } = {}
	local lo = Vector3.one * math.huge
	local hi = -lo
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, item)
			-- (the markers are invisible: not part of its shape)
			if item.Transparency < 1 then
				local at = space:ToObjectSpace(item.CFrame)
				local half = item.Size / 2
				local r, u, b = at.RightVector, at.UpVector, at.LookVector
				local reach = Vector3.new(
					math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(b.X) * half.Z,
					math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(b.Y) * half.Z,
					math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(b.Z) * half.Z
				)
				lo = lo:Min(at.Position - reach)
				hi = hi:Max(at.Position + reach)
			end
		end
	end
	local extent = hi - lo
	if extent.X <= 0 or extent.Y <= 0 or extent.Z <= 0 then
		return
	end
	local size = arm.Size
	local k = math.min(
		size.Y * ARM_LENGTH / extent.Y,
		size.X * MAX_WIDTH / extent.X,
		size.Z * MAX_DEPTH / extent.Z
	)
	local x = -(lo.X + hi.X) / 2 * k
	if hi.X * k + x > size.X * INNER then
		x = size.X * INNER - hi.X * k
	end
	local top = size.Y / 2 + size.Y * SHOULDER_CAP
	local shift = Vector3.new(x, top - hi.Y * k, -(lo.Z + hi.Z) / 2 * k)
	for _, part in parts do
		local at = space:ToObjectSpace(part.CFrame)
		part.Size *= k
		part.CFrame = space * CFrame.new(at.Position * k + shift) * at.Rotation
	end
	-- (each weld: Part1.CFrame = Part0.CFrame * C0 * C1:Inverse())
	for _, item in folder:GetDescendants() do
		if item:IsA("Weld") and item.Part0 and item.Part1 then
			item.C0 = item.Part0.CFrame:ToObjectSpace(item.Part1.CFrame) * item.C1
		end
	end
end

local function buildArm(arm: BasePart, folder: Folder, connections: { RBXScriptConnection })
	-- (how big the character is: 1 for a 2-stud arm. Its glow and sparks
	-- grow with it; not with fitArm's scale, which also undoes the import's)
	local scale = arm.Size.Y / 2
	local main = RiftAssets.spawn("Arm", arm.CFrame)
	if main then
		weldTo(arm, main, folder)
	else
		buildArmParts(arm, folder)
	end
	fitArm(arm, folder)
	if main then
		local glow = partNamed(main, "Glow")
		local cell = partNamed(main, "Cell") or glow
		if cell and glow then
			addLight(cell, glow, 5 * scale, 0.8, connections)
		end
	else
		local cell = folder:FindFirstChild("Cell")
		if cell and cell:IsA("BasePart") then
			addLight(cell, cell, 5 * scale, 0.8, connections)
		end
	end
	local palm = folder:FindFirstChild("Palm", true)
	if palm and palm:IsA("BasePart") then
		local hum = emitter(palm, {
			Name = "PalmHum",
			Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
			LightEmission = 1,
			Size = NumberSequence.new(0.18 * scale, 0),
			Transparency = NumberSequence.new(0.3, 1),
			Lifetime = NumberRange.new(0.2, 0.35),
			Speed = NumberRange.new(0.5 * scale, 1.5 * scale),
			Rate = 6,
		})
		sparkTexture(hum)
	end
end

-- What other modules put on the real arm's skin, in folders under it: the
-- cut skin of Gashes, the bruises of Wounds, blood stuck to it (Blood).
-- Skin marks on a robot arm make no sense, and they would float inside it.
local SKIN_FOLDERS: { [string]: boolean } = { Gashes = true, Wounds = true, BloodSplats = true }

local function onSkin(arm: BasePart, item: Instance): boolean
	local at: Instance? = item
	while at and at.Parent ~= arm do
		at = at.Parent
	end
	return at ~= nil and at ~= item and SKIN_FOLDERS[at.Name] == true
end

-- Hides one of them, keeping what to give back.
local function hideSkin(dressed: Dressed, item: Instance)
	if dressed.hidden[item] ~= nil then
		return
	end
	-- (bruises and blood come and go: forget the ones already destroyed)
	dressed.hiddenCount += 1
	if dressed.hiddenCount > 64 then
		dressed.hiddenCount = 0
		for old in dressed.hidden do
			if old.Parent == nil then
				dressed.hidden[old] = nil
			end
		end
	end
	if item:IsA("BasePart") or item:IsA("Decal") then
		-- (a decal still shows on an invisible part)
		local shape: any = item
		dressed.hidden[item] = shape.Transparency
		shape.Transparency = 1
	elseif item:IsA("GuiObject") then
		-- (Visible: the others turn their SurfaceGuis on and off themselves)
		dressed.hidden[item] = item.Visible
		item.Visible = false
	end
end

-- Gives them back (those still there; a part someone else hid since, or
-- faded out, is left as it is).
local function showSkin(dressed: Dressed)
	for item, was in dressed.hidden do
		if item.Parent ~= nil then
			if typeof(was) == "number" and (item:IsA("BasePart") or item:IsA("Decal")) then
				if (item :: any).Transparency >= 1 then
					(item :: any).Transparency = was
				end
			elseif typeof(was) == "boolean" and item:IsA("GuiObject") then
				item.Visible = was
			end
		end
	end
	table.clear(dressed.hidden)
	dressed.hiddenCount = 0
end

local function removeGear(model: Model)
	local dressed = gear[model]
	gear[model] = nil
	if dressed == nil then
		return
	end
	for _, connection in dressed.connections do
		connection:Disconnect()
	end
	dressed.armGear:Destroy()
	showSkin(dressed)
	-- (a cut arm stays hidden: Gashes draws it with its own skin)
	local cut = dressed.arm:FindFirstChild("Gashes")
	if dressed.arm.Transparency >= 1 and (cut == nil or #cut:GetChildren() == 0) then
		dressed.arm.Transparency = dressed.armTransparency
	end
end

-- Your own character: the camera hides it in first person with
-- LocalTransparencyModifier; the gear follows its part.
local function followModifier(part: BasePart, folder: Folder, connections: { RBXScriptConnection })
	local function follow()
		for _, item in folder:GetDescendants() do
			if item:IsA("BasePart") then
				item.LocalTransparencyModifier = part.LocalTransparencyModifier
			end
		end
	end
	table.insert(
		connections,
		part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(follow)
	)
	follow()
end

local function dress(model: Model)
	removeGear(model)
	local arm = model:FindFirstChild("Left Arm")
	if arm == nil or not arm:IsA("BasePart") then
		return
	end
	local connections: { RBXScriptConnection } = {}
	local armGear = Instance.new("Folder")
	armGear.Name = "RiftGear"
	buildArm(arm, armGear, connections)
	local dressed: Dressed = {
		arm = arm,
		armGear = armGear,
		armTransparency = if arm.Transparency < 1 then arm.Transparency else 0,
		hidden = {},
		hiddenCount = 0,
		connections = connections,
	}
	-- The real arm out of sight while the mechanical one is on (and kept so:
	-- Gashes gives it its transparency back when it closes its cuts).
	arm.Transparency = 1
	table.insert(
		dressed.connections,
		arm:GetPropertyChangedSignal("Transparency"):Connect(function()
			if arm.Transparency < 1 then
				dressed.armTransparency = arm.Transparency
				arm.Transparency = 1
			end
		end)
	)
	for _, child in arm:GetChildren() do
		if SKIN_FOLDERS[child.Name] then
			for _, item in child:GetDescendants() do
				hideSkin(dressed, item)
			end
		end
	end
	table.insert(
		dressed.connections,
		arm.DescendantAdded:Connect(function(item: Instance)
			if onSkin(arm, item) then
				hideSkin(dressed, item)
			end
		end)
	)
	armGear.Parent = arm
	if model == Players.LocalPlayer.Character then
		followModifier(arm, armGear, dressed.connections)
	end
	gear[model] = dressed
	-- (the arm resized: a character scaled with Model:ScaleTo, or by hand;
	-- fitted again on its new size)
	table.insert(
		dressed.connections,
		arm:GetPropertyChangedSignal("Size"):Connect(function()
			task.defer(function()
				if gear[model] == dressed and model:GetAttribute("Kit") == KIT then
					dress(model)
				end
			end)
		end)
	)
	-- (gone with its part: the arm destroyed)
	table.insert(
		dressed.connections,
		armGear.Destroying:Connect(function()
			if gear[model] == dressed then
				removeGear(model)
			end
		end)
	)
end

local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function RiftGear.watch(model: Model)
	if watched[model] then
		return
	end
	watched[model] = true
	local function refresh()
		if model:GetAttribute("Kit") == KIT then
			if gear[model] == nil then
				dress(model)
			end
		else
			removeGear(model)
		end
	end
	model:GetAttributeChangedSignal("Kit"):Connect(refresh)
	refresh()
end

function RiftGear.palmOf(model: Model): BasePart?
	local dressed = gear[model]
	local palm = if dressed then dressed.armGear:FindFirstChild("Palm", true) else nil
	return if palm and palm:IsA("BasePart") then palm else nil
end

return RiftGear
