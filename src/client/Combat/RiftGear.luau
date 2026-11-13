--!strict
-- RiftGear: Dr. Rift's cyborg arm, on anyone with the "Rift" kit (his clones
-- too): the mechanical left arm ending in the gravity glove.
--
--   RiftGear.watch(model)     dressed while its "Kit" attribute is "Rift"
--   RiftGear.palmOf(model)    the glove's emitter (where its power comes out)
--
-- The arm is an R6 arm of metal built from parts: the real arm's own block
-- (its size, so it can't be misplaced), plated, with a glowing power cell
-- and the glove's emitter under it. No fingers, no meshes.
-- The real Left Arm is hidden while he wears the mechanical one (on this
-- client: its Transparency, saved and given back when the kit changes), and
-- so is what lies on its skin (the cuts of Gashes, the bruises of Wounds,
-- blood stuck to it); everything is welded to the arm, so it follows the
-- animations and the ragdoll.

local Players = game:GetService("Players")

local RiftGear = {}

local KIT = "Rift"
local P = require(script.Parent.RiftParts)
local STEEL = P.STEEL
local STEEL_DARK = P.STEEL_DARK
local BRASS = P.BRASS
local CABLE = P.CABLE
local RIFT_GREEN = P.RIFT_GREEN
local RIFT_GLOW = P.RIFT_GLOW
local ghost = P.ghost
local emitter = P.emitter
local sparkTexture = P.sparkTexture

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

------------------------------------------------------------------------------
-- Dressing
------------------------------------------------------------------------------

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

-- The mechanical arm: an R6 arm of metal (the same block as the real one,
-- 1 x 2 x 1 at the default size, a hair bigger so it covers it), plated:
-- a shoulder cap, an elbow and a wrist band, a green power cell in front,
-- vents on the outside, the gravity glove's emitter under the "hand" (the
-- bottom face). No fingers. Welded to the real arm (hidden): it moves with it.
local function buildArm(arm: BasePart, folder: Folder, connections: { RBXScriptConnection })
	local size = arm.Size
	local w, h, d = size.X, size.Y, size.Z
	local u = h / 2 -- (1 at the default size)
	local function add(part: BasePart, offset: CFrame)
		part.CFrame = arm.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
		part.Parent = folder
	end
	-- The casing (the arm's own block).
	add(metal("Casing", Vector3.new(w + 0.04, h + 0.02, d + 0.04), STEEL_DARK), CFrame.new())
	-- Shoulder cap: a thicker plate over the top, bolted.
	add(
		metal("Shoulder", Vector3.new(w + 0.12, 0.55 * u, d + 0.12), STEEL),
		CFrame.new(0, h / 2 - 0.27 * u, 0)
	)
	add(
		metal("ShoulderRim", Vector3.new(w + 0.14, 0.06 * u, d + 0.14), BRASS),
		CFrame.new(0, h / 2 - 0.55 * u, 0)
	)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			add(
				metal("Bolt", Vector3.new(0.09, 0.09, 0.09) * u, BRASS, Enum.PartType.Ball),
				CFrame.new(x * (w / 2 + 0.06), h / 2 - 0.27 * u, z * (d / 2 + 0.02))
			)
		end
	end
	-- Elbow and wrist bands.
	add(metal("Elbow", Vector3.new(w + 0.1, 0.14 * u, d + 0.1), BRASS), CFrame.new(0, -0.05 * u, 0))
	add(metal("Wrist", Vector3.new(w + 0.1, 0.1 * u, d + 0.1), BRASS), CFrame.new(0, -0.68 * u, 0))
	-- The "hand": a heavier block at the end.
	add(
		metal("Hand", Vector3.new(w + 0.08, 0.3 * u, d + 0.08), STEEL),
		CFrame.new(0, -h / 2 + 0.14 * u, 0)
	)
	-- The power cell, behind a frame, in front of the forearm.
	add(
		metal("CellFrame", Vector3.new(0.34 * u, 0.46 * u, 0.04), STEEL),
		CFrame.new(0, -0.37 * u, -d / 2 - 0.03)
	)
	local cell =
		ghost("Cell", Vector3.new(0.22 * u, 0.34 * u, 0.04), RIFT_GREEN, Enum.Material.Neon)
	add(cell, CFrame.new(0, -0.37 * u, -d / 2 - 0.05))
	addLight(cell, cell, 5 * u, 0.8, connections)
	-- Vents on the outside of the upper arm.
	for index = 0, 2 do
		add(
			metal("Vent", Vector3.new(0.03, 0.05 * u, d * 0.6), CABLE),
			CFrame.new(-w / 2 - 0.03, 0.32 * u - index * 0.12 * u, 0)
		)
	end
	-- A hose down the back.
	add(
		cylinder("Hose", 0.05 * u, 1.1 * u, CABLE, Enum.Material.Rubber),
		CFrame.new(0, 0.05 * u, d / 2 + 0.06) * CFrame.Angles(0, 0, math.rad(90))
	)
	-- The glove's emitter, under the hand (where its power comes out).
	local palm = cylinder("Palm", 0.3 * u, 0.04, RIFT_GLOW, Enum.Material.Neon)
	add(palm, CFrame.new(0, -h / 2 - 0.025, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local hum = emitter(palm, {
		Name = "PalmHum",
		Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.18 * u, 0),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(0.2, 0.35),
		Speed = NumberRange.new(0.5 * u, 1.5 * u),
		Rate = 6,
	})
	sparkTexture(hum)
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
