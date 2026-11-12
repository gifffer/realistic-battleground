--!strict
-- WeaponFx: a weapon in a fighter's right hand (Shared/Weapons), on every
-- client. The server sets "Weapon" (= its id) on the fighter's model while
-- they hold one.
--
--   • "Bone": the real upper arm bone (WoundKit "Gore_Humerus_*", GoreKit),
--     or a simple one without it, held by the elbow end, the round head
--     out like the head of a club, bloody.
--   • When it breaks on a blow (Remotes.WeaponBroke): it snaps in two, the
--     pieces fall, splinters fly.
--
--   WeaponFx.watch(model)          shows / removes the weapon as "Weapon" changes
--   WeaponFx.broke(model, id)      the snap

local Debris = game:GetService("Debris")

local GoreKit = require(script.Parent.GoreKit)

local WeaponFx = {}

local BONE = Color3.fromRGB(222, 208, 182)
local BONE_BLOODY = Color3.fromRGB(176, 120, 104)
local FLESH = Color3.fromRGB(112, 24, 26)
local TENDON = Color3.fromRGB(210, 196, 178)
-- In the fist: the elbow end in the hand, the bone carrying on the line of
-- the arm, tipped 35° the way the knuckles face (a short club: with the arm
-- out in front, it comes down onto the head). The swings in BouncerClips were
-- solved with this grip.
local GRIP = CFrame.new(0, -0.95, 0.05) * CFrame.Angles(math.rad(145), 0, 0)
local BONE_LENGTH = 1.7

local held: { [Model]: Instance } = setmetatable({}, { __mode = "k" }) :: any
-- Where each one was last in the hand (to break it there, even if it's gone).
local lastAt: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function paint(layer: string): (Color3, number)
	if layer == "Flesh" then
		return FLESH, 0.15
	elseif layer == "Tendon" then
		return TENDON, 0.1
	end
	return BONE:Lerp(BONE_BLOODY, 0.35), 0.04
end

-- The bone, its own space at its middle, along Y (the head at +Y): one
-- main part (the others welded to it).
local function newBone(): BasePart
	local pieces = GoreKit.get()
	local piece = if pieces then pieces.Humerus else nil
	if piece then
		return GoreKit.spawn(piece, CFrame.identity, paint)
	end
	-- (along its own Y, like the real one)
	local shaft = Instance.new("Part")
	shaft.Name = "Bone"
	shaft.Size = Vector3.new(0.16, BONE_LENGTH * 0.8, 0.16)
	shaft.Material = Enum.Material.SmoothPlastic
	shaft.Color = BONE:Lerp(BONE_BLOODY, 0.35)
	shaft.CFrame = CFrame.identity
	local function knob(name: string, size: Vector3, at: Vector3, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Size = size
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.CanCollide = false
		part.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = shaft
		weld.Part1 = part
		weld.C0 = CFrame.new(at)
		weld.Parent = part
		part.Parent = shaft
	end
	knob("Head", Vector3.new(0.34, 0.32, 0.32), Vector3.new(-0.05, 0.66, 0), BONE)
	knob("Elbow", Vector3.new(0.4, 0.16, 0.2), Vector3.new(0, -0.72, 0), BONE)
	knob("Flesh", Vector3.new(0.14, 0.12, 0.14), Vector3.new(0.08, 0.55, 0.08), FLESH)
	return shaft
end

local function remove(model: Model)
	local prop = held[model]
	held[model] = nil
	if prop then
		if prop:IsA("BasePart") then
			lastAt[model] = prop.CFrame
		end
		prop:Destroy()
	end
end

local function show(model: Model, id: string)
	remove(model)
	local arm = model:FindFirstChild("Right Arm")
	if id ~= "Bone" or arm == nil or not arm:IsA("BasePart") then
		return
	end
	local bone = newBone()
	for _, part in bone:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	bone.CanCollide = false
	bone.Massless = true
	bone.CanQuery = false
	bone.CanTouch = false
	bone.Anchored = false
	-- (the elbow end in the fist: the bone's middle half its length beyond)
	bone.CFrame = arm.CFrame * GRIP * CFrame.new(0, BONE_LENGTH * 0.42, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "Held"
	weld.Part0 = arm
	weld.Part1 = bone
	weld.Parent = bone
	bone.Name = "WeaponBone"
	bone.Parent = model
	held[model] = bone
end

function WeaponFx.watch(model: Model)
	local function refresh()
		local id = model:GetAttribute("Weapon")
		if typeof(id) == "string" then
			show(model, id)
		else
			remove(model)
		end
	end
	model:GetAttributeChangedSignal("Weapon"):Connect(refresh)
	refresh()
end

-- It snapped on a blow: two halves fall from the hand, splinters fly.
function WeaponFx.broke(model: Model, id: string)
	remove(model)
	local at = lastAt[model] or model:GetPivot()
	if id ~= "Bone" then
		return
	end
	for index = -1, 1, 2 do
		local half = Instance.new("Part")
		half.Name = "BoneHalf"
		half.Shape = Enum.PartType.Cylinder
		half.Size = Vector3.new(0.75, 0.17, 0.17)
		half.Material = Enum.Material.SmoothPlastic
		half.Color = BONE:Lerp(BONE_BLOODY, 0.35)
		half.CanQuery = false
		half.CanTouch = false
		half.CFrame = at * CFrame.new(0, index * 0.42, 0) * CFrame.Angles(0, 0, math.pi / 2)
		half.AssemblyLinearVelocity = at:VectorToWorldSpace(Vector3.new(index * 3, 4, -2))
		half.AssemblyAngularVelocity = Vector3.new(
			math.random() - 0.5,
			math.random() - 0.5,
			math.random() - 0.5
		) * 20
		-- (not into the one holding it: it collides once clear of the hand)
		half.CanCollide = false
		half.Parent = workspace
		task.delay(0.25, function()
			if half.Parent then
				half.CanCollide = true
			end
		end)
		Debris:AddItem(half, 12)
	end
	for _ = 1, 8 do
		local splinter = Instance.new("Part")
		splinter.Name = "Splinter"
		splinter.Size = Vector3.new(0.03, 0.03, math.random() * 0.12 + 0.06)
		splinter.Material = Enum.Material.SmoothPlastic
		splinter.Color = BONE
		splinter.CanQuery = false
		splinter.CanTouch = false
		splinter.CFrame = at * CFrame.Angles(math.random() * 6.3, math.random() * 6.3, 0)
		splinter.AssemblyLinearVelocity = Vector3.new(
			math.random() - 0.5,
			math.random() * 0.8,
			math.random() - 0.5
		) * 16
		splinter.Parent = workspace
		Debris:AddItem(splinter, 5)
	end
end

return table.freeze(WeaponFx)
