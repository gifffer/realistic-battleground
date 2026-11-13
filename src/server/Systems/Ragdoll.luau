--!strict
-- Ragdoll: makes an R6 body go limp (knocked out, dead) and stand back up.
--
-- How it works:
--   • The 5 joints that hold the head, arms and legs to the torso (Motor6D)
--     are switched OFF, and each one is replaced by a "ball socket": a loose
--     joint that lets the limb swing freely, with angle limits so it
--     doesn't bend in impossible ways.
--   • The limbs get collisions (normally off) so they rest on the floor.
--   • The Humanoid stops standing the body up: Physics state (the only state
--     in which Roblox lets R6 arms and legs collide with the floor) + PlatformStand.
--   • RequiresNeck is turned off: otherwise Roblox KILLS a humanoid whose
--     neck joint is switched off (a KO would become an instant death).
--   • The SERVER simulates the body while it's limp (SetNetworkOwner(nil)):
--     every player sees the same fall, and a cheater can't move their own
--     knocked-out body. EVERY piece of it: with its joints off, each limb is
--     a body of its own (an "assembly"), and Roblox would hand those to a
--     player's computer by itself (its own player, or whoever stands
--     closest). That computer still has the limb where ITS animation last
--     drew it (a finisher clip can carry the whole body metres away), so
--     it sent that spot to everyone: the arms and legs flew off across the
--     map, then the loose joint dragged them back little by little.
--
--   Ragdoll.enable(model)
--   Ragdoll.disable(model, owner?)   -- `owner` = the player to give the body back to
--
-- The model gets the attribute "Ragdolled" = true while limp (clients stop
-- animating it).

local Ragdoll = {}

-- Motor6D name (in the Torso) → angle limits of the ball socket that replaces it.
type Limit = { upper: number, twist: number }
local JOINTS: { [string]: Limit } = {
	Neck = { upper = 40, twist = 30 },
	["Right Shoulder"] = { upper = 110, twist = 60 },
	["Left Shoulder"] = { upper = 110, twist = 60 },
	["Right Hip"] = { upper = 80, twist = 30 },
	["Left Hip"] = { upper = 80, twist = 30 },
}
-- Limbs that collide while limp (R6 names).
local LIMBS = { "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
-- Name prefix of everything we create (to remove it cleanly).
local TAG = "Ragdoll_"

-- The server simulates every loose piece of `model` (see the header).
-- Pieces held by something outside it (an arm in a killer's fist) and
-- anchored ones are left alone.
local function serverOwnsAll(model: Model)
	local done: { [BasePart]: boolean } = {}
	for _, item in model:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local base: BasePart? = item.AssemblyRootPart -- (nil out of the world)
		if base == nil or done[base] or not base:IsDescendantOf(model) then
			continue
		end
		done[base] = true
		if item:CanSetNetworkOwnership() then
			item:SetNetworkOwner(nil)
		end
	end
end

-- An attachment on `part` at the joint position given by `cframe` (C0 / C1).
local function attach(part: BasePart, name: string, cframe: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = TAG .. name
	attachment.CFrame = cframe
	attachment.Parent = part
	return attachment
end

function Ragdoll.isRagdolled(model: Model): boolean
	return model:GetAttribute("Ragdolled") == true
end

function Ragdoll.enable(model: Model)
	if Ragdoll.isRagdolled(model) then
		return
	end
	local torso = model:FindFirstChild("Torso")
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if torso == nil or not torso:IsA("BasePart") or humanoid == nil then
		return
	end
	model:SetAttribute("Ragdolled", true)
	-- Must be off BEFORE the neck motor is disabled (see the header).
	humanoid.RequiresNeck = false

	for motorName, limit in JOINTS do
		local motor = torso:FindFirstChild(motorName)
		if motor and motor:IsA("Motor6D") and motor.Part1 then
			local limb = motor.Part1 :: BasePart
			-- Ball socket exactly where the motor was.
			local a0 = attach(torso, motorName .. "0", motor.C0)
			local a1 = attach(limb, motorName .. "1", motor.C1)
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = TAG .. motorName
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = limit.upper
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -limit.twist
			socket.TwistUpperAngle = limit.twist
			socket.Parent = torso
			-- The limb must not fight the torso it's attached to.
			local noCollide = Instance.new("NoCollisionConstraint")
			noCollide.Name = TAG .. motorName .. "_NoCollide"
			noCollide.Part0 = torso
			noCollide.Part1 = limb
			noCollide.Parent = torso
			motor.Enabled = false
		end
	end
	for _, limbName in LIMBS do
		local limb = model:FindFirstChild(limbName)
		if limb and limb:IsA("BasePart") then
			limb.CanCollide = true
		end
	end

	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	-- The server simulates the fall, limbs included (same for everyone,
	-- can't be cheated).
	serverOwnsAll(model)
	if root and root:IsA("BasePart") then
		root.CanCollide = false
		-- Now that the server owns the body, its state change takes effect:
		-- Physics = limbs keep their collisions, nothing stands it up.
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		-- A small push so the body doesn't just fold in place.
		root.AssemblyLinearVelocity += root.CFrame.LookVector * -6 + Vector3.new(0, 4, 0)
	end
end

function Ragdoll.disable(model: Model, owner: Player?)
	if not Ragdoll.isRagdolled(model) then
		return
	end
	-- Torn in two (the Bull's finisher, Combat): its hip joints are gone, it
	-- never stands up again.
	if model:GetAttribute("Bisected") ~= nil then
		return
	end
	local torso = model:FindFirstChild("Torso")
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if torso == nil or humanoid == nil then
		return
	end

	-- Remove everything we added, turn the motors back on.
	for _, part in model:GetChildren() do
		for _, child in part:GetChildren() do
			if string.sub(child.Name, 1, #TAG) == TAG then
				child:Destroy()
			end
		end
	end
	for motorName in JOINTS do
		local motor = torso:FindFirstChild(motorName)
		if motor and motor:IsA("Motor6D") then
			motor.Enabled = true
		end
	end
	for _, limbName in LIMBS do
		local limb = model:FindFirstChild(limbName)
		if limb and limb:IsA("BasePart") then
			limb.CanCollide = false
		end
	end

	if root and root:IsA("BasePart") then
		-- Stand the body up where it lies, facing the same way (flat).
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then
			flat = Vector3.new(0, 0, -1)
		end
		local position = root.Position + Vector3.new(0, 2, 0)
		model:PivotTo(CFrame.lookAt(position, position + flat))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CanCollide = true
	end
	-- Stand up while the server still owns the body (its state change counts),
	-- THEN give the body back to its player's computer.
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	-- (the joints are back on: one body again, its root's owner is the
	-- owner of all of it; a piece still apart stays the server's)
	if owner and root and root:IsA("BasePart") and root:CanSetNetworkOwnership() then
		root:SetNetworkOwner(owner)
	end
	model:SetAttribute("Ragdolled", false)
end

return table.freeze(Ragdoll)
