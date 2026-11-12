--!strict
-- KitLooks: what some kits put on the fighter who wears them (drawn by
-- every client, from the "Kit" attribute the server sets on the fighter):
--   • BULL      a pair of bull horns on the head;
--   • SENTINEL  a short cape on the back, swaying with the speed.
-- Plain parts welded to the body (not accessories: the server keeps only
-- small head accessories). Under the head / torso, so a burst head
-- (HeadBlast) takes the horns with it.
--
--   KitLooks.start()   watch every fighter

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local KitLooks = {}

local HORN = Color3.fromRGB(226, 214, 186) -- ivory
local HORN_BASE = Color3.fromRGB(150, 128, 98)
local HORN_TIP = Color3.fromRGB(70, 60, 52)
local CAPE = Color3.fromRGB(122, 16, 22)
local CAPE_INSIDE = Color3.fromRGB(70, 8, 12)

local function newPart(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	return part
end

local function weld(part: BasePart, to: BasePart, offset: CFrame, parent: Instance)
	part.CFrame = to.CFrame * offset
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = to
	joint.Part1 = part
	joint.Parent = part
	part.Parent = parent
end

-- A bull horn on `head`, out of its `side` (1 = right, -1 = left): tapered
-- pieces along a curve (out to the side, then up, the tip turning in and
-- forward), a ball at each joint so it reads as one smooth horn.
local HORN_CURVE = { -- head space (studs; its centre the origin, -Z its face)
	Vector3.new(0.38, 0.4, -0.04),
	Vector3.new(0.68, 0.47, -0.1),
	Vector3.new(0.94, 0.6, -0.18),
	Vector3.new(1.1, 0.83, -0.27),
	Vector3.new(1.13, 1.06, -0.37),
	Vector3.new(1.05, 1.24, -0.47),
}
local HORN_WIDTH = { 0.27, 0.23, 0.19, 0.14, 0.09 }

local function horn(head: BasePart, side: number, folder: Instance)
	local function point(index: number): Vector3
		local p = HORN_CURVE[index]
		return Vector3.new(p.X * side, p.Y, p.Z)
	end
	for index = 1, #HORN_CURVE - 1 do
		local a, b = point(index), point(index + 1)
		local width = HORN_WIDTH[index]
		local color = if index == 1
			then HORN_BASE
			elseif index == #HORN_WIDTH then HORN_TIP
			else HORN
		-- (a cylinder lies along its X: turned to point from a to b)
		local piece = newPart(
			`Horn{index}`,
			Vector3.new((b - a).Magnitude + 0.02, width, width),
			color,
			Enum.PartType.Cylinder
		)
		weld(piece, head, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), folder)
		local joint = newPart(`HornJoint{index}`, Vector3.one * width, color, Enum.PartType.Ball)
		weld(joint, head, CFrame.new(a), folder)
	end
	local tip = newPart("HornTip", Vector3.one * 0.07, HORN_TIP, Enum.PartType.Ball)
	weld(tip, head, CFrame.new(point(#HORN_CURVE)), folder)
end

local function buildHorns(model: Model): Instance?
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "KitLook"
	horn(head, 1, folder)
	horn(head, -1, folder)
	folder.Parent = head
	return folder
end

-- Capes being drawn: their hinge joints, swung each frame from the speed.
type Cape = { model: Model, root: BasePart, upper: Motor6D, lower: Motor6D }
local capes: { [Model]: Cape } = {}

local function buildCape(model: Model): Instance?
	local torso = model:FindFirstChild("Torso")
	local root = model:FindFirstChild("HumanoidRootPart")
	if torso == nil or not torso:IsA("BasePart") or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "KitLook"
	-- Two panels hinged at the shoulders and in the middle (it bends).
	local upper = newPart("CapeUpper", Vector3.new(1.9, 1.3, 0.06), CAPE)
	upper.Material = Enum.Material.Fabric
	local lower = newPart("CapeLower", Vector3.new(1.75, 1.4, 0.06), CAPE)
	lower.Material = Enum.Material.Fabric
	local lining = newPart("Lining", Vector3.new(1.7, 1.25, 0.02), CAPE_INSIDE)
	lining.Material = Enum.Material.Fabric
	upper.Parent = folder
	lower.Parent = folder
	-- Shoulders, back of the torso.
	local shoulderHinge = Instance.new("Motor6D")
	shoulderHinge.Name = "CapeHinge"
	shoulderHinge.Part0 = torso
	shoulderHinge.Part1 = upper
	shoulderHinge.C0 = CFrame.new(0, 0.95, 0.56)
	shoulderHinge.C1 = CFrame.new(0, 0.62, 0)
	shoulderHinge.Parent = upper
	local middleHinge = Instance.new("Motor6D")
	middleHinge.Name = "CapeBend"
	middleHinge.Part0 = upper
	middleHinge.Part1 = lower
	middleHinge.C0 = CFrame.new(0, -0.62, 0)
	middleHinge.C1 = CFrame.new(0, 0.68, 0)
	middleHinge.Parent = lower
	local liningWeld = Instance.new("Weld")
	liningWeld.Part0 = upper
	liningWeld.Part1 = lining
	liningWeld.C0 = CFrame.new(0, 0, -0.04)
	liningWeld.Parent = lining
	lining.Parent = folder
	-- A small clasp at each shoulder.
	for _, side in { -1, 1 } do
		local clasp = newPart(
			"Clasp",
			Vector3.new(0.16, 0.16, 0.16),
			Color3.fromRGB(196, 160, 72),
			Enum.PartType.Ball
		)
		clasp.Material = Enum.Material.Metal
		weld(clasp, torso, CFrame.new(side * 0.78, 0.92, -0.46), folder)
	end
	folder.Parent = torso
	capes[model] = { model = model, root = root, upper = shoulderHinge, lower = middleHinge }
	return folder
end

local BUILDERS: { [string]: (Model) -> Instance? } = {
	Bull = buildHorns,
	Sentinel = buildCape,
}

local worn: { [Model]: Instance } = {}

local function refresh(model: Model)
	local old = worn[model]
	if old then
		old:Destroy()
		worn[model] = nil
	end
	capes[model] = nil
	local kitId = model:GetAttribute("Kit")
	local build = if typeof(kitId) == "string" then BUILDERS[kitId] else nil
	if build then
		local look = build(model)
		if look then
			worn[model] = look
		end
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Kit"):Connect(function()
		refresh(model)
	end)
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			worn[model] = nil
			capes[model] = nil
		end
	end)
	task.defer(refresh, model) -- (once its body has loaded)
end

-- The capes swing back with the speed, and flutter a little.
local function swayCapes(dt: number)
	local time = os.clock()
	for model, cape in capes do
		if cape.root.Parent == nil or cape.upper.Parent == nil then
			capes[model] = nil
			continue
		end
		local velocity = cape.root.AssemblyLinearVelocity
		local back = cape.root.CFrame.LookVector
		local speed = math.max(0, velocity:Dot(back)) + math.abs(velocity.Y) * 0.4
		local lift = math.clamp(6 + speed * 2.4, 6, 70)
		local flutter = math.sin(time * (6 + speed * 0.3)) * math.min(8, 1 + speed * 0.3)
		-- (smoothed: no snapping when stopping)
		local current = cape.upper.Transform
		local target = CFrame.Angles(math.rad(lift + flutter * 0.4), 0, 0)
		cape.upper.Transform = current:Lerp(target, math.min(1, dt * 8))
		cape.lower.Transform = cape.lower.Transform:Lerp(
			CFrame.Angles(math.rad(lift * 0.35 + flutter), 0, 0),
			math.min(1, dt * 8)
		)
	end
end

function KitLooks.start()
	local tag = Config.Combat.TAG
	CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
	for _, model in CollectionService:GetTagged(tag) do
		watch(model)
	end
	RunService.RenderStepped:Connect(swayCapes)
end

return KitLooks
