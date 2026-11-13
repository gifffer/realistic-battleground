--!strict
-- RiftGear: Dr. Rift's cyborg parts, on anyone with the "Rift" kit (his
-- clones too): the mechanical left arm ending in the gravity glove, and the
-- ocular implant on his right eye.
--
--   RiftGear.watch(model)     dressed while its "Kit" attribute is "Rift"
--   RiftGear.palmOf(model)    the glove's emitter (where its power comes out)
--
-- The gear is the RiftGear meshes when the place has them (RiftAssets:
-- salvaged plates, servos, pistons, hoses, a power cell, an articulated
-- metal hand); without them (an old place) a simpler version built from
-- parts. The real Left Arm is hidden while he wears the mechanical one (on
-- this client: its Transparency, saved and given back when the kit
-- changes), and so is what lies on its skin (the cuts of Gashes, the bruises
-- of Wounds, blood stuck to it); everything is welded to the arm and the
-- head, so it follows the ragdoll, and what is on the head is hidden with it
-- if it bursts (HeadBlast hides everything under the head; the lights go
-- out with what they belong to).

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
-- The classic head (Server/Systems/Characters: a Head mesh at scale 1.25):
-- a rounded cylinder of radius 0.6. The default face's right eye (the
-- character's right: +X; the face looks at -Z) is at X = 0.175, Y = 0.12.
local CLASSIC_SCALE = 1.25
local HEAD_RADIUS = 0.6
local EYE_X, EYE_Y = 0.175, 0.12
local ALONG_X_TO_Y = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis (X) → Y
local ALONG_X_TO_Z = CFrame.Angles(0, math.rad(90), 0) -- a cylinder's axis (X) → -Z

type Dressed = {
	arm: BasePart,
	head: BasePart,
	armGear: Folder,
	eyeGear: Folder,
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

-- A unit vector round the Y axis: 0° = +X (the torso side of the left
-- arm), 90° = +Z (the back), 270° = -Z (the front).
local function azim(degrees: number): Vector3
	local a = math.rad(degrees)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- A finger of the glove: three segments from its knuckle, opening along
-- `out`, then curling back in round the emitter (as in the meshes).
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
			Vector3.new(0.11, 0.11, 0.11),
			STEEL_DARK,
			Enum.Material.Metal,
			Enum.PartType.Ball
		),
		CFrame.new(at)
	)
	for index, curl in curls do
		local length = lengths[index]
		local c = math.rad(curl)
		local d = (Vector3.new(0, -1, 0) * math.cos(c) + out * math.sin(c)).Unit
		local w = width * (1 - 0.1 * (index - 1))
		local frame = CFrame.fromMatrix(at + d * (length / 2), side, d)
		add(metal("Finger", Vector3.new(w, length, w * 0.9), STEEL), frame)
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
-- shoulder at Y = +1, the glove's end at Y = -1; +X faces the torso).
local function buildArmParts(arm: BasePart, folder: Folder)
	local function add(part: BasePart, offset: CFrame)
		stick(arm, part, offset, folder)
	end
	-- The shoulder: a rounded pauldron on a dark rim, a servo on the side.
	local dome = metal("Pauldron", Vector3.new(1.06, 0.6, 1.06), STEEL)
	local round = Instance.new("SpecialMesh")
	round.MeshType = Enum.MeshType.Sphere
	round.Parent = dome
	-- (nothing past X = +0.48: the torso's side is at +0.5)
	add(dome, CFrame.new(-0.06, 0.72, 0) * CFrame.Angles(0, 0, math.rad(7)))
	add(cylinder("Rim", 0.5, 0.06, STEEL_DARK), CFrame.new(-0.04, 0.62, 0) * ALONG_X_TO_Y)
	add(cylinder("Servo", 0.25, 0.16, STEEL_DARK), CFrame.new(-0.47, 0.42, 0))
	add(cylinder("ServoGear", 0.28, 0.05, BRASS), CFrame.new(-0.45, 0.42, 0))
	add(
		cylinder("Axle", 0.08, 0.34, CHROME, Enum.Material.SmoothPlastic),
		CFrame.new(-0.53, 0.42, 0)
	)
	-- The upper arm: a dark frame, an armour shell, two pistons.
	add(metal("Frame", Vector3.new(0.6, 0.6, 0.54), STEEL_DARK), CFrame.new(0, 0.3, 0))
	add(cylinder("Shell", 0.4, 0.42, STEEL), CFrame.new(0, 0.33, 0) * ALONG_X_TO_Y)
	for _, at in { Vector3.new(-0.08, 0, -0.46), Vector3.new(-0.36, 0, 0.32) } do
		add(
			cylinder("Piston", 0.06, 0.42, STEEL_DARK),
			CFrame.new(at + Vector3.new(0, 0.35, 0)) * ALONG_X_TO_Y
		)
		local rod = cylinder("Rod", 0.032, 0.46, CHROME, Enum.Material.SmoothPlastic)
		rod.Reflectance = 0.3
		add(rod, CFrame.new(at + Vector3.new(0, -0.03, 0)) * ALONG_X_TO_Y)
		add(cylinder("Mount", 0.055, 0.08, BRASS), CFrame.new(at + Vector3.new(0, -0.26, 0)))
	end
	-- The elbow: a big servo across the arm, brass flanges, a chrome axle.
	add(cylinder("Elbow", 0.27, 0.76, STEEL_DARK), CFrame.new(0, 0, 0.04))
	for _, x in { -0.39, 0.39 } do
		add(cylinder("Flange", 0.29, 0.045, BRASS), CFrame.new(x, 0, 0.04))
	end
	local axle = cylinder("ElbowAxle", 0.09, 0.94, CHROME, Enum.Material.SmoothPlastic)
	axle.Reflectance = 0.3
	add(axle, CFrame.new(0, 0, 0.04))
	-- The forearm: a dark core, three plate rings, the glowing power cell.
	add(cylinder("Core", 0.33, 0.62, STEEL_DARK), CFrame.new(0, -0.33, 0) * ALONG_X_TO_Y)
	for index, ring in { { -0.125, 0.405 }, { -0.297, 0.395 }, { -0.467, 0.375 } } do
		local plate = cylinder("Plate" .. index, ring[2], 0.14, STEEL)
		add(plate, CFrame.new(0, ring[1], 0) * ALONG_X_TO_Y)
	end
	local cell = cylinder("Cell", 0.09, 0.4, RIFT_GREEN, Enum.Material.Neon)
	add(cell, CFrame.new(0, -0.3, -0.36) * ALONG_X_TO_Y)
	for _, y in { -0.09, -0.51 } do
		add(cylinder("CellCap", 0.1, 0.05, BRASS), CFrame.new(0, y, -0.36) * ALONG_X_TO_Y)
	end
	-- Hoses down the back.
	for index, x in { -0.15, 0.03, 0.2 } do
		add(
			cylinder("Hose", 0.04, 0.95, CABLE, Enum.Material.Rubber),
			CFrame.new(x, 0.18, 0.46) * CFrame.Angles(math.rad(-6 + index * 2), 0, 0) * ALONG_X_TO_Y
		)
	end
	-- The wrist, the palm housing, the emitter (Palm).
	add(cylinder("Wrist", 0.35, 0.06, BRASS), CFrame.new(0, -0.585, 0) * ALONG_X_TO_Y)
	add(
		cylinder("WristCollar", 0.3, 0.08, CHROME, Enum.Material.SmoothPlastic),
		CFrame.new(0, -0.645, 0) * ALONG_X_TO_Y
	)
	add(cylinder("Housing", 0.35, 0.18, STEEL), CFrame.new(0, -0.77, 0) * ALONG_X_TO_Y)
	add(cylinder("Knuckles", 0.375, 0.05, STEEL_DARK), CFrame.new(0, -0.85, 0) * ALONG_X_TO_Y)
	add(cylinder("EmitterRing", 0.215, 0.04, BRASS), CFrame.new(0, -0.875, 0) * ALONG_X_TO_Y)
	add(
		cylinder("Palm", 0.17, 0.03, RIFT_GLOW, Enum.Material.Neon),
		CFrame.new(0, -0.885, 0) * ALONG_X_TO_Y
	)
	-- Three fingers and a thumb round the emitter.
	for _, a in { 146, 192, 238 } do
		buildFinger(
			add,
			azim(a) * 0.29 + Vector3.new(0, -0.87, 0),
			azim(a),
			{ 16, -8, -34 },
			{ 0.14, 0.12, 0.095 },
			0.125
		)
	end
	buildFinger(
		add,
		azim(15) * 0.29 + Vector3.new(0, -0.85, 0),
		azim(15),
		{ 32, -8 },
		{ 0.12, 0.11 },
		0.135
	)
end

-- A frame on the classic head's front (Head space, for a head mesh scaled by
-- `k`): at (x, y) on the face, `lift` out of the skin, its -Z looking out.
local function onHead(x: number, y: number, lift: number, k: number, offset: Vector3): CFrame
	local angle = math.asin(math.clamp(x / HEAD_RADIUS, -1, 1))
	local r = HEAD_RADIUS + lift
	local position = Vector3.new(r * math.sin(angle), y, -r * math.cos(angle)) * k + offset
	return CFrame.new(position) * CFrame.Angles(0, -angle, 0)
end

-- The implant from parts: a brass bezel round the eye, the lens, a plate on
-- the skin, a module and its antenna on the temple.
local function buildEyeParts(head: BasePart, folder: Folder, k: number, offset: Vector3)
	local function add(part: BasePart, at: CFrame)
		part.Size *= k
		stick(head, part, at, folder)
	end
	local eye = onHead(EYE_X, EYE_Y, 0, k, offset)
	-- (two narrow plates, each turned to the curve of the head: one flat
	-- plate would only touch it in its middle)
	for _, plate in { { 0.05, 0.13, 0.22 }, { 0.17, 0.12, 0.16 } } do
		add(
			metal("Plate", Vector3.new(plate[2], plate[3], 0.015), STEEL),
			onHead(EYE_X + plate[1], EYE_Y, 0.004, k, offset)
		)
	end
	add(cylinder("Bezel", 0.105, 0.045, BRASS), eye * CFrame.new(0, 0, -0.02 * k) * ALONG_X_TO_Z)
	local lens = cylinder("Lens", 0.058, 0.05, RIFT_GREEN, Enum.Material.Neon)
	add(lens, eye * CFrame.new(0, 0, -0.022 * k) * ALONG_X_TO_Z)
	add(
		cylinder("Pupil", 0.016, 0.054, STEEL_DARK),
		eye * CFrame.new(0, 0, -0.024 * k) * ALONG_X_TO_Z
	)
	local temple = onHead(EYE_X + 0.3, EYE_Y + 0.02, 0.02, k, offset)
	add(metal("Module", Vector3.new(0.11, 0.09, 0.05), STEEL_DARK), temple)
	add(
		cylinder("Antenna", 0.008, 0.26, CHROME, Enum.Material.SmoothPlastic),
		-- (+X of the frame goes round the head toward the back)
		temple
			* CFrame.new(0.06 * k, 0.12 * k, 0)
			* CFrame.Angles(0, 0, math.rad(-25))
			* ALONG_X_TO_Y
	)
end

------------------------------------------------------------------------------
-- Dressing
------------------------------------------------------------------------------

-- How big the head is drawn (1 = the classic head at scale 1.25) and where.
local function headMeasure(head: BasePart): (number, Vector3)
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Head then
		return mesh.Scale.Y / CLASSIC_SCALE * head.Size.Y, mesh.Offset
	end
	return head.Size.Y / (HEAD_RADIUS * 2), Vector3.zero -- (not a classic head)
end

-- Welds a spawned piece (placed at `base`'s CFrame times its offset) to `base`.
local function weldTo(base: BasePart, main: BasePart, folder: Folder)
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = main
	weld.C0 = base.CFrame:ToObjectSpace(main.CFrame)
	weld.Parent = main
	main.Parent = folder
end

-- A green light at `at` (a marker of the meshes: the power cell, the lens;
-- or the glowing part itself), out while `shown` is hidden (HeadBlast hides
-- what is on the head with Transparency, a light has none).
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

local function buildArm(arm: BasePart, folder: Folder, connections: { RBXScriptConnection })
	local main = RiftAssets.spawn("Arm", arm.CFrame)
	if main then
		weldTo(arm, main, folder)
		local glow = partNamed(main, "Glow")
		local cell = partNamed(main, "Cell") or glow
		if cell and glow then
			addLight(cell, glow, 5, 0.8, connections)
		end
	else
		buildArmParts(arm, folder)
		local cell = folder:FindFirstChild("Cell")
		if cell and cell:IsA("BasePart") then
			addLight(cell, cell, 5, 0.8, connections)
		end
	end
	local palm = folder:FindFirstChild("Palm", true)
	if palm and palm:IsA("BasePart") then
		local hum = emitter(palm, {
			Name = "PalmHum",
			Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
			LightEmission = 1,
			Size = NumberSequence.new(0.18, 0),
			Transparency = NumberSequence.new(0.3, 1),
			Lifetime = NumberRange.new(0.2, 0.35),
			Speed = NumberRange.new(0.5, 1.5),
			Rate = 6,
		})
		sparkTexture(hum)
	end
end

local function buildEye(head: BasePart, folder: Folder, connections: { RBXScriptConnection })
	local k, offset = headMeasure(head)
	local main = RiftAssets.spawn("Eye", head.CFrame * CFrame.new(offset), nil, k)
	if main then
		weldTo(head, main, folder)
		local glow = partNamed(main, "Glow")
		local lens = partNamed(main, "Lens") or glow
		if lens and glow then
			addLight(lens, glow, 2.5, 0.6, connections)
		end
	else
		buildEyeParts(head, folder, k, offset)
		local lens = folder:FindFirstChild("Lens")
		if lens and lens:IsA("BasePart") then
			addLight(lens, lens, 2.5, 0.6, connections)
		end
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
	dressed.eyeGear:Destroy()
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
	local head = model:FindFirstChild("Head")
	if arm == nil or not arm:IsA("BasePart") or head == nil or not head:IsA("BasePart") then
		return
	end
	local connections: { RBXScriptConnection } = {}
	local armGear = Instance.new("Folder")
	armGear.Name = "RiftGear"
	buildArm(arm, armGear, connections)
	-- (under the head: hidden with it if it bursts)
	local eyeGear = Instance.new("Folder")
	eyeGear.Name = "RiftEye"
	buildEye(head, eyeGear, connections)
	local dressed: Dressed = {
		arm = arm,
		head = head,
		armGear = armGear,
		eyeGear = eyeGear,
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
	eyeGear.Parent = head
	if model == Players.LocalPlayer.Character then
		followModifier(arm, armGear, dressed.connections)
		followModifier(head, eyeGear, dressed.connections)
	end
	gear[model] = dressed
	-- (gone with its part: the arm or the head destroyed)
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
