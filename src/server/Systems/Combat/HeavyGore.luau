--!strict
-- HeavyGore: the gore of the very strong hits. SERVER-AUTHORITATIVE: decides
-- what happens, sets the attributes (Shared/Util/HeavyGore); every client
-- draws it (Client/Combat/HeavyGore), late joiners and the bodies left
-- after a finisher (Corpses) too. Rare (Config.HeavyGore):
--   • a heavy blow that KNOCKS OUT: to the head, teeth knocked out; to the
--     body / legs, the arm / leg on that side torn off (legs: off by
--     default, they may get up) or an open fracture;
--   • the plain finisher's killing blow: a limb torn off, a fracture, the
--     jaw broken;
--   • the Boxer's finisher: teeth out on its last punch to the face, maybe
--     the jaw broken on the kill.
-- Caps per body (MAX_TORN_LIMBS, MAX_FRACTURES); everything goes with the
-- body (the torn limb after TORN_LIMB_TIME).
--
-- A torn limb leaves the body (it can't be dragged along when they get up,
-- nor hit): it flies off in a model of its own (a Humanoid in it: the
-- shirt / pants still show on it), tagged HeavyGoreUtil.TAG.
--
--   HeavyGore.knockoutBlow(victim, from, zone, side) -> brokeLeg
--   HeavyGore.finisherKill(victim, from)
--   HeavyGore.teeth(victim)
--   HeavyGore.jaw(victim)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HeavyGoreUtil = require(ReplicatedStorage.Shared.Util.HeavyGore)
local Types = require(ReplicatedStorage.Shared.Types)

local G = Config.HeavyGore
local LIMBS = HeavyGoreUtil.LIMBS
local KEYS = HeavyGoreUtil.KEYS

local HeavyGore = {}

local random = Random.new()

local function enabled(): boolean
	return G.ENABLED and Config.Injuries.SKIN_TEAR
end

local function seed(): number
	return random:NextInteger(1, 2 ^ 30)
end

local function count(victim: Model, attribute: (string) -> string): number
	local total = 0
	for _, key in KEYS do
		if victim:GetAttribute(attribute(key)) ~= nil then
			total += 1
		end
	end
	return total
end

local function isTorn(victim: Model, key: string): boolean
	-- (the Bouncer's finisher tears the right arm its own way: "ArmTorn")
	return victim:GetAttribute(HeavyGoreUtil.tornAttribute(key)) ~= nil
		or (key == "RightArm" and victim:GetAttribute("ArmTorn") ~= nil)
		or victim:FindFirstChild(LIMBS[key].part) == nil
end

local function limbFolder(): Instance
	local found = workspace:FindFirstChild(HeavyGoreUtil.FOLDER)
	if found then
		return found
	end
	local created = Instance.new("Folder")
	created.Name = HeavyGoreUtil.FOLDER
	created.Parent = workspace
	return created
end

-- Tears `key` off `victim` and throws it away from `from`. false if it
-- can't be (already gone, the cap reached, not an R6 body).
local function tearLimb(victim: Model, key: string, from: Vector3): boolean
	local limb = LIMBS[key]
	local torso = victim:FindFirstChild("Torso")
	local part = victim:FindFirstChild(limb.part)
	if
		isTorn(victim, key)
		or count(victim, HeavyGoreUtil.tornAttribute) >= G.MAX_TORN_LIMBS
		or not (torso and torso:IsA("BasePart") and part and part:IsA("BasePart"))
	then
		return false
	end
	-- Off the torso: its joint, and the loose one of the ragdoll with its
	-- attachments (its no-collide kept: it doesn't knock the body away as
	-- it leaves).
	local ragdoll = "Ragdoll_" .. limb.joint
	for _, item in torso:GetChildren() do
		if
			item.Name == limb.joint
			or (
				string.sub(item.Name, 1, #ragdoll) == ragdoll
				and not item:IsA("NoCollisionConstraint")
			)
		then
			item:Destroy()
		end
	end
	for _, item in part:GetChildren() do
		if string.sub(item.Name, 1, 8) == "Ragdoll_" or item:IsA("JointInstance") then
			item:Destroy()
		end
	end
	local value = seed()

	-- Its own model: an inert Humanoid and the clothes (R6 clothing shows on
	-- a part named like a limb in a model with a Humanoid).
	local holder = Instance.new("Model")
	holder.Name = victim.Name .. " " .. limb.part
	holder.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	holder:SetAttribute("Limb", key)
	holder:SetAttribute("Seed", value)
	holder:SetAttribute("TornAt", workspace:GetServerTimeNow())
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.EvaluateStateMachine = false
	humanoid.Parent = holder
	for _, item in victim:GetChildren() do
		if item:IsA("Clothing") then
			item:Clone().Parent = holder
		end
	end
	part.CanCollide = true
	part.CanQuery = false -- (out of the hitboxes and the aim)
	part.CanTouch = false
	part.Massless = false
	part.Anchored = false
	part.Parent = holder
	holder.PrimaryPart = part
	holder:AddTag(HeavyGoreUtil.TAG)
	holder.Parent = limbFolder()
	if part:CanSetNetworkOwnership() then
		part:SetNetworkOwner(nil)
	end
	local away = part.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 1e-3 then away.Unit else random:NextUnitVector()
	part.AssemblyLinearVelocity = away * G.LIMB_FLING_SPEED * random:NextNumber(0.7, 1)
		+ Vector3.new(0, G.LIMB_FLING_UP * random:NextNumber(0.7, 1), 0)
	part.AssemblyAngularVelocity = random:NextUnitVector() * random:NextNumber(6, 14)
	Debris:AddItem(holder, G.TORN_LIMB_TIME)
	victim:SetAttribute(HeavyGoreUtil.tornAttribute(key), value)
	return true
end

local function fracture(victim: Model, key: string): boolean
	local attribute = HeavyGoreUtil.fractureAttribute(key)
	if
		isTorn(victim, key)
		or victim:GetAttribute(attribute) ~= nil
		or count(victim, HeavyGoreUtil.fractureAttribute) >= G.MAX_FRACTURES
	then
		return false
	end
	victim:SetAttribute(attribute, seed())
	return true
end

-- (a burst head has no teeth or jaw left to break)
local function hasFace(victim: Model): boolean
	return victim:GetAttribute("HeadBlown") == nil and victim:FindFirstChild("Head") ~= nil
end

-- Teeth knocked out of `victim` (once per body: set again, nothing new).
function HeavyGore.teeth(victim: Model)
	if enabled() and hasFace(victim) and victim:GetAttribute(HeavyGoreUtil.TEETH) == nil then
		victim:SetAttribute(HeavyGoreUtil.TEETH, seed())
	end
end

-- The jaw broken (teeth out with it).
function HeavyGore.jaw(victim: Model)
	if enabled() and hasFace(victim) and victim:GetAttribute(HeavyGoreUtil.JAW) == nil then
		HeavyGore.teeth(victim)
		victim:SetAttribute(HeavyGoreUtil.JAW, seed())
	end
end

-- A heavy blow just knocked `victim` out (`from`: where it came from).
-- Returns true if it broke a leg (they limp if they get up).
function HeavyGore.knockoutBlow(
	victim: Model,
	from: Vector3,
	zone: Types.HitZone,
	side: Types.HitSide
): boolean
	if not enabled() then
		return false
	end
	if zone == "Head" then
		if random:NextNumber() < G.KO_TEETH_CHANCE then
			HeavyGore.teeth(victim)
		end
		return false
	end
	-- The arm / leg on the side it came from (from the front or the back:
	-- either).
	local isArm = zone ~= "Legs"
	local right = if side == "Right"
		then true
		elseif side == "Left" then false
		else random:NextNumber() < 0.5
	local key = if isArm
		then (if right then "RightArm" else "LeftArm")
		else (if right then "RightLeg" else "LeftLeg")
	local roll = random:NextNumber()
	if roll < G.KO_TEAR_CHANCE and (isArm or G.KO_TEAR_LEGS) then
		if tearLimb(victim, key, from) then
			return false
		end
	end
	if roll < G.KO_TEAR_CHANCE + G.KO_FRACTURE_CHANCE then
		return fracture(victim, key) and not isArm
	end
	return false
end

-- The plain finisher's killing blow (the body is dead).
function HeavyGore.finisherKill(victim: Model, from: Vector3)
	if not enabled() then
		return
	end
	local start = random:NextInteger(1, #KEYS)
	local torn: string? = nil
	if random:NextNumber() < G.FINISHER_TEAR_CHANCE then
		for offset = 0, #KEYS - 1 do
			local key = KEYS[(start + offset - 1) % #KEYS + 1]
			if tearLimb(victim, key, from) then
				torn = key
				break
			end
		end
	end
	if random:NextNumber() < G.FINISHER_FRACTURE_CHANCE then
		for offset = 1, #KEYS do
			local key = KEYS[(start + offset - 1) % #KEYS + 1]
			if key ~= torn and fracture(victim, key) then
				break
			end
		end
	end
	if random:NextNumber() < G.FINISHER_JAW_CHANCE then
		HeavyGore.jaw(victim)
	end
end

return table.freeze(HeavyGore)
