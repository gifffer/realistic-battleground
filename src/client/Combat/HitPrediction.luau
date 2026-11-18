--!strict
-- HitPrediction: guesses, on the ATTACKER's client, what the server will
-- decide for one of our M1 — who is hit and on which zone — so the victim's
-- reaction can start the instant our fist lands (CombatEffectsController).
-- Purely visual: the server always has the last word.
--
-- Why not just ask Roblox which parts are in the box? Because on the SERVER
-- nobody is animated: our code-made animations (CharacterAnimationController)
-- only exist on each client. The server sees every R6 body in its rest pose,
-- glued to its HumanoidRootPart. If we tested the animated bodies (head
-- thrown back by the previous hit...), we would often guess another zone
-- than the server, and the reaction would be played twice.
-- So we rebuild each body in its REST pose with simple boxes, and do the
-- same tests as the server on those boxes:
--   • the aim ray (Combat aimZone): which body part it meets first,
--   • the hitbox (Combat Hitbox.query): which body parts overlap it,
--   • the landing zone (Combat landingZone): aimed zone if a punch can reach
--     it and it's in the box, else the torso, else the head.
-- We test the others where WE see them; the server tests them there too
-- (it rewinds them by our ping, Server/Systems/Combat/Rewind), so both
-- agree even on a runner. The box maths are shared (Shared/Util/BoxMath).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BoxMath = require(ReplicatedStorage.Shared.Util.BoxMath)
local Types = require(ReplicatedStorage.Shared.Types)

local C = Config.Combat

type RestPart = {
	name: string,
	zone: Types.HitZone,
	offset: CFrame, -- from the HumanoidRootPart, in the rest pose
	size: Vector3,
}

-- An R6 body at rest (standard R6 sizes and joint positions).
local REST_PARTS: { RestPart } = {
	{ name = "Head", zone = "Head", offset = CFrame.new(0, 1.5, 0), size = Vector3.new(2, 1, 1) },
	{ name = "Torso", zone = "Torso", offset = CFrame.new(), size = Vector3.new(2, 2, 1) },
	{
		name = "Right Arm",
		zone = "Torso",
		offset = CFrame.new(1.5, 0, 0),
		size = Vector3.new(1, 2, 1),
	},
	{
		name = "Left Arm",
		zone = "Torso",
		offset = CFrame.new(-1.5, 0, 0),
		size = Vector3.new(1, 2, 1),
	},
	{
		name = "Right Leg",
		zone = "Legs",
		offset = CFrame.new(0.5, -2, 0),
		size = Vector3.new(1, 2, 1),
	},
	{
		name = "Left Leg",
		zone = "Legs",
		offset = CFrame.new(-0.5, -2, 0),
		size = Vector3.new(1, 2, 1),
	},
}
-- A hat / hair sits around the top of the head: the server counts an
-- accessory hit as a head hit. Rough box for it (only if the body wears one).
local HAT: RestPart = {
	name = "Accessory",
	zone = "Head",
	offset = CFrame.new(0, 2.2, 0),
	size = Vector3.new(2.2, 1.6, 2.2),
}
-- Body parts of each zone a punch can land on (same as the server).
local ZONE_PARTS: { [string]: { string } } = {
	Head = { "Head" },
	Torso = { "Torso", "Right Arm", "Left Arm" },
}
-- Fighters farther than this from us can't be in the hitbox: skipped.
local SEARCH_RADIUS = 12
-- Rest-pose head of a body, from its HumanoidRootPart (aim ray origin).
local HEAD_OFFSET = Vector3.new(0, 1.5, 0)

local HitPrediction = {}

local function wearsAccessory(model: Model): boolean
	return model:FindFirstChildWhichIsA("Accessory") ~= nil
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

-- Every fighter whose rest-pose body overlaps the hitbox in front of
-- `attackerRoot`, with the names of its body parts inside the box.
function HitPrediction.findVictims(
	attacker: Model,
	attackerRoot: BasePart
): { [Model]: { [string]: boolean } }
	local box = attackerRoot.CFrame * CFrame.new(0, 0, -C.HITBOX_FORWARD)
	local result: { [Model]: { [string]: boolean } } = {}
	for _, instance in CollectionService:GetTagged(C.TAG) do
		if instance == attacker or not instance:IsA("Model") then
			continue
		end
		local root = instance:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		if (root.Position - attackerRoot.Position).Magnitude > SEARCH_RADIUS then
			continue
		end
		local parts: { [string]: boolean } = {}
		local touched = false
		for _, part in REST_PARTS do
			if BoxMath.boxesOverlap(box, C.HITBOX_SIZE, root.CFrame * part.offset, part.size) then
				parts[part.name] = true
				touched = true
			end
		end
		if touched then
			result[instance] = parts
		end
	end
	return result
end

-- The zone the aim ray meets first on `victim` (rest pose), like the
-- server's aimZone. `aim` must already be validated (Shared/Util/AimRule).
-- No aim, or the ray misses: the torso.
function HitPrediction.aimZone(attackerRoot: BasePart, victim: Model, aim: Vector3?): Types.HitZone
	local zone: Types.HitZone = "Torso"
	local victimRoot = victim:FindFirstChild("HumanoidRootPart")
	if aim == nil or victimRoot == nil or not victimRoot:IsA("BasePart") then
		return zone
	end
	local origin = attackerRoot.CFrame:PointToWorldSpace(HEAD_OFFSET)
	local direction = aim * C.AIM_RAY_LENGTH
	local closest = math.huge
	local function test(part: RestPart)
		local t = BoxMath.rayHitsBox(origin, direction, victimRoot.CFrame * part.offset, part.size)
		if t and t <= 1 and t < closest then
			closest = t
			zone = part.zone
		end
	end
	for _, part in REST_PARTS do
		test(part)
	end
	if wearsAccessory(victim) then
		test(HAT)
	end
	return zone
end

-- Where the punch lands, like the server's landingZone with
-- Config.Combat.PUNCH_ZONES (head or torso).
function HitPrediction.landingZone(
	aimed: Types.HitZone,
	parts: { [string]: boolean }
): Types.HitZone
	local function inBox(zone: string): boolean
		for _, name in ZONE_PARTS[zone] do
			if parts[name] then
				return true
			end
		end
		return false
	end
	local zone: Types.HitZone = "Torso"
	if (aimed == "Head" or aimed == "Torso") and inBox(aimed) then
		zone = aimed
	elseif not inBox("Torso") and inBox("Head") then
		zone = "Head"
	end
	return zone
end

return table.freeze(HitPrediction)
