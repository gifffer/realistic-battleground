--!strict
-- RiftGear: Dr. Rift's cyborg parts, on anyone with the "Rift" kit (his
-- clones too): the mechanical left arm with the gravity glove, the lens eye.
--
--   RiftGear.watch(model)     dressed while its "Kit" attribute is "Rift"
--   RiftGear.palmOf(model)    the glove's palm (where its power comes out)

local RiftGear = {}

local KIT = "Rift"
local P = require(script.Parent.RiftParts)
local STEEL = P.STEEL
local STEEL_DARK = P.STEEL_DARK
local BRASS = P.BRASS
local RUST = P.RUST
local CABLE = P.CABLE
local RIFT_GREEN = P.RIFT_GREEN
local RIFT_GLOW = P.RIFT_GLOW
local ghost = P.ghost
local stick = P.stick
local emitter = P.emitter
local sparkTexture = P.sparkTexture

------------------------------------------------------------------------------
-- His gear (anyone with the Rift kit)
------------------------------------------------------------------------------

local gear: { [Model]: Folder } = setmetatable({}, { __mode = "k" }) :: any

-- The mechanical left arm (Left Arm space: 1 x 2 x 1, the hand at Y = -1).
local function buildArm(arm: BasePart, folder: Folder)
	local function add(part: BasePart, offset: CFrame)
		stick(arm, part, offset, folder)
	end
	-- Shoulder cap: a dented plate, bolted.
	add(
		ghost("Cap", Vector3.new(1.16, 0.5, 1.14), STEEL, Enum.Material.DiamondPlate),
		CFrame.new(0, 0.78, 0)
	)
	add(
		ghost("CapRim", Vector3.new(1.2, 0.08, 1.18), RUST, Enum.Material.CorrodedMetal),
		CFrame.new(0, 0.52, 0)
	)
	-- Upper arm: two side rails and a piston.
	for _, x in { -0.53, 0.53 } do
		add(
			ghost("Rail", Vector3.new(0.1, 0.9, 0.3), STEEL_DARK, Enum.Material.Metal),
			CFrame.new(x, 0.08, 0)
		)
	end
	add(
		ghost(
			"Piston",
			Vector3.new(0.9, 0.12, 0.12),
			BRASS,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		),
		CFrame.new(0, 0.1, -0.54) * CFrame.Angles(0, 0, math.rad(90))
	)
	-- Elbow: a ball joint between two plates.
	add(
		ghost(
			"Elbow",
			Vector3.new(0.62, 0.62, 0.62),
			STEEL_DARK,
			Enum.Material.Metal,
			Enum.PartType.Ball
		),
		CFrame.new(0, -0.38, 0.32)
	)
	-- Forearm: a full casing, a glowing core window, cables.
	add(
		ghost("Forearm", Vector3.new(1.1, 0.78, 1.1), STEEL, Enum.Material.Metal),
		CFrame.new(0, -0.55, 0)
	)
	local core = ghost("Core", Vector3.new(0.34, 0.5, 0.06), RIFT_GREEN, Enum.Material.Neon)
	add(core, CFrame.new(0, -0.55, -0.56))
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 0.8
	light.Range = 5
	light.Parent = core
	for index, x in { -0.3, 0.3 } do
		add(
			ghost("Cable", Vector3.new(0.09, 1.1, 0.09), CABLE, Enum.Material.Rubber),
			CFrame.new(x, -0.1, 0.56) * CFrame.Angles(math.rad(index * 6 - 9), 0, 0)
		)
	end
	-- Wrist ring.
	add(
		ghost(
			"Wrist",
			Vector3.new(0.16, 1.18, 1.18),
			BRASS,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		),
		CFrame.new(0, -0.98, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	-- The glove: a heavy metal hand, three thick fingers, the palm emitter.
	add(
		ghost("Glove", Vector3.new(1.12, 0.36, 1.12), STEEL_DARK, Enum.Material.DiamondPlate),
		CFrame.new(0, -1.16, 0)
	)
	for index = -1, 1 do
		add(
			ghost("Finger", Vector3.new(0.26, 0.34, 0.3), STEEL, Enum.Material.Metal),
			CFrame.new(index * 0.34, -1.48, -0.3)
		)
	end
	add(
		ghost("Thumb", Vector3.new(0.26, 0.3, 0.28), STEEL, Enum.Material.Metal),
		CFrame.new(0.5, -1.3, 0.12)
	)
	local palm = ghost(
		"Palm",
		Vector3.new(0.5, 0.5, 0.06),
		RIFT_GLOW,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	palm.Size = Vector3.new(0.06, 0.5, 0.5)
	add(palm, CFrame.new(0, -1.36, -0.02) * CFrame.Angles(0, 0, math.rad(90)))
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

-- The lens for a right eye (Head space; the face looks at -Z).
local function buildEye(head: BasePart, folder: Folder)
	local size = head.Size
	local eye = CFrame.new(size.X * 0.2, size.Y * 0.1, -size.Z / 2)
	local ring = ghost(
		"LensRing",
		Vector3.new(0.12, 0.42, 0.42),
		BRASS,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	stick(head, ring, eye * CFrame.new(0, 0, -0.04) * CFrame.Angles(0, math.rad(90), 0), folder)
	local lens = ghost(
		"Lens",
		Vector3.new(0.13, 0.28, 0.28),
		RIFT_GREEN,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	stick(head, lens, eye * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, math.rad(90), 0), folder)
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 0.6
	light.Range = 3
	light.Parent = lens
	-- The strap round the head and a plate over the temple.
	stick(
		head,
		ghost(
			"Strap",
			Vector3.new(size.X + 0.04, 0.12, size.Z + 0.04),
			CABLE,
			Enum.Material.Leather
		),
		CFrame.new(0, size.Y * 0.1, 0),
		folder
	)
	stick(
		head,
		ghost("Temple", Vector3.new(0.1, 0.36, 0.42), STEEL, Enum.Material.Metal),
		CFrame.new(size.X / 2 + 0.02, size.Y * 0.1, -0.05),
		folder
	)
end

local function removeGear(model: Model)
	local folder = gear[model]
	gear[model] = nil
	if folder then
		folder:Destroy()
	end
end

local function dress(model: Model)
	removeGear(model)
	local arm = model:FindFirstChild("Left Arm")
	local head = model:FindFirstChild("Head")
	if arm == nil or not arm:IsA("BasePart") or head == nil or not head:IsA("BasePart") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "RiftGear"
	buildArm(arm, folder)
	-- (the eye's parts go under the head: hidden with it if it bursts)
	local eyeFolder = Instance.new("Folder")
	eyeFolder.Name = "RiftEye"
	buildEye(head, eyeFolder)
	eyeFolder.Parent = head
	folder.Parent = model
	gear[model] = folder
	folder.Destroying:Connect(function()
		eyeFolder:Destroy()
	end)
end

local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function RiftGear.watch(model: Model)
	if watched[model] then
		return
	end
	watched[model] = true
	local function refresh()
		if model:GetAttribute("Kit") == KIT then
			local current: Folder? = gear[model]
			if current == nil then
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
	local folder = gear[model]
	local palm = if folder then folder:FindFirstChild("Palm", true) else nil
	return if palm and palm:IsA("BasePart") then palm else nil
end

return RiftGear
