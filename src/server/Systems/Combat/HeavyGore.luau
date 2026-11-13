--!strict
-- HeavyGore: the gore of the very strong hits. SERVER-AUTHORITATIVE: decides
-- what happens, sets the attributes (Shared/Util/HeavyGore); every client
-- draws it (Client/Combat/HeavyGore, Client/Combat/Gashes), late joiners
-- and the bodies left after a finisher (Corpses) too.
--
-- Only in a fight, never from a finisher, and rare (Config.HeavyGore): the
-- server counts the combo each fighter takes (the same attacker's hits that
-- land, close enough together). Once it is big, the attacker's next HEAVY
-- blow may snap the forearm / the shin on the side it hit (an open
-- fracture: a broken leg limps) or, rarer, tear the arm off. The fighter
-- stays alive and playable; the blow that knocks him out has higher odds.
-- Then his combo starts over and nothing more happens to him for a while.
-- Caps per body (MAX_TORN_LIMBS, MAX_FRACTURES). It stays until death (a
-- limb doesn't grow back, an open fracture doesn't close: a kill's healing
-- leaves it), then goes with the body (the torn limb after TORN_LIMB_TIME).
--
-- A torn limb leaves the body (it can't be dragged along when they get up):
-- it flies off in a model of its own (a dead Humanoid in it: the shirt /
-- pants still show on it, the hitboxes skip it), tagged HeavyGoreUtil.TAG,
-- in workspace.TornLimbs (the aim and the finishers' placement leave that
-- folder out). It only collides with the map (the dead bodies' group).
--
--   HeavyGore.landed(victim, attacker, blow) -> brokeLeg   (a hit landed)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HeavyGoreUtil = require(ReplicatedStorage.Shared.Util.HeavyGore)
local Types = require(ReplicatedStorage.Shared.Types)
local Destruction = require(script.Parent.Parent.Destruction)

local G = Config.HeavyGore
local LIMBS = HeavyGoreUtil.LIMBS
local KEYS = HeavyGoreUtil.KEYS

local HeavyGore = {}

-- A hit that landed (Server/Combat resolveHit).
export type Blow = {
	damage: number,
	heavy: boolean, -- HEAVY_DAMAGE or more, the 4th M1, a knockdown / launch
	zone: Types.HitZone,
	side: Types.HitSide,
	from: Vector3, -- where it came from (a torn limb flies away from it)
	knockedOut: boolean, -- this blow knocked him out
}

-- The combo each fighter is taking (weak: gone with the body).
type Combo = {
	attacker: Model?,
	hits: number,
	damage: number,
	lastAt: number,
	quietUntil: number, -- nothing more on him before this
}
local combos: { [Model]: Combo } = setmetatable({}, { __mode = "k" }) :: any

local random = Random.new()

local function enabled(): boolean
	return G.ENABLED and Config.Injuries.SKIN_TEAR
end

local function seed(): number
	return random:NextInteger(1, 2 ^ 30)
end

local function count(victim: Model, attribute: (string) -> string): number
	-- (the Bouncer's torn arm counts as a torn limb)
	local total = if attribute == HeavyGoreUtil.tornAttribute
			and victim:GetAttribute("ArmTorn") ~= nil
		then 1
		else 0
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
	-- (dead: Hitbox.query only takes living ones)
	humanoid.Health = 0
	for _, item in victim:GetChildren() do
		if item:IsA("Clothing") then
			item:Clone().Parent = holder
		elseif item:IsA("Accessory") then
			-- worn on that limb: goes with it (else, still welded to it, it
			-- would pull it back with the body when it gets up)
			local handle = item:FindFirstChild("Handle")
			local weld = if handle then handle:FindFirstChildWhichIsA("JointInstance") else nil
			if weld and (weld.Part0 == part or weld.Part1 == part) then
				item.Parent = holder
			end
		end
	end
	-- (solid on the map, not on fighters: the dead bodies' group)
	part.CollisionGroup = Destruction.DEAD_GROUP
	part.CanCollide = true
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

-- The limb on the side the blow came from: the arm for the body and the
-- head (raised to cover it), the leg for the legs.
local function limbHit(blow: Blow): string
	local right = if blow.side == "Right"
		then true
		elseif blow.side == "Left" then false
		else random:NextNumber() < 0.5
	if blow.zone == "Legs" then
		return if right then "RightLeg" else "LeftLeg"
	end
	return if right then "RightArm" else "LeftArm"
end

-- The other limb of the same kind (the other arm / leg).
local OTHER =
	{ RightArm = "LeftArm", LeftArm = "RightArm", RightLeg = "LeftLeg", LeftLeg = "RightLeg" }

-- `attacker` landed a blow on `victim` (normal combat: not a finisher, not
-- blocked). Counts it in the combo; at the end of a big one, a heavy blow
-- may break him. Returns true if it broke a leg (he limps).
function HeavyGore.landed(victim: Model, attacker: Model, blow: Blow): boolean
	if not enabled() or (not G.IN_DUELS and victim:GetAttribute("DuelId") ~= nil) then
		return false
	end
	local time = os.clock()
	local combo = combos[victim]
	if combo == nil then
		combo = { attacker = nil, hits = 0, damage = 0, lastAt = 0, quietUntil = 0 }
		combos[victim] = combo
	end
	if combo.attacker ~= attacker or time - combo.lastAt > G.COMBO_GAP then
		-- (someone else, or too long since: a new combo)
		combo.attacker = attacker
		combo.hits = 0
		combo.damage = 0
	end
	combo.hits += 1
	combo.damage += blow.damage
	combo.lastAt = time
	local big = combo.hits >= G.COMBO_HITS or combo.damage >= G.COMBO_DAMAGE
	if not (big and blow.heavy) or time < combo.quietUntil then
		return false
	end
	local tear = if blow.knockedOut then G.KO_TEAR_CHANCE else G.TEAR_CHANCE
	local breaks = if blow.knockedOut then G.KO_FRACTURE_CHANCE else G.FRACTURE_CHANCE
	local key = limbHit(blow)
	local roll = random:NextNumber()
	local done = false
	local brokeLeg = false
	if roll < tear and (LIMBS[key].arm or G.TEAR_LEGS) then
		done = tearLimb(victim, key, blow.from)
	end
	if not done and roll < tear + breaks then
		-- (that one already broken or gone: the other one)
		for _, which in { key, OTHER[key] } do
			if fracture(victim, which) then
				done = true
				brokeLeg = not LIMBS[which].arm
				break
			end
		end
	end
	if done then
		-- (his combo starts over, and he is left alone for a while)
		combo.hits = 0
		combo.damage = 0
		combo.quietUntil = time + G.COOLDOWN
	end
	return brokeLeg
end

return table.freeze(HeavyGore)
