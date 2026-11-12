--!strict
-- Combat: M1 combo, blocking, parrying, dashing, stuns. SERVER-AUTHORITATIVE.
--
-- Vocabulary:
--   combatant = a model that can fight: a player's character or a training
--               dummy. Each one has a CombatState (below).
--   stun      = can't attack, block or dash for a moment.
--
-- Life of an M1:
--   1. Client clicks → Remotes.Attack. (Dummies call Combat.tryAttack.)
--   2. tryAttack checks: alive? not stunned? not blocking? not too early?
--      Then the combo advances (hits 1 → 2 → 3 → 4 → 1...).
--   3. After HIT_DELAY (the wind-up) the server puts a hitbox in front of
--      the attacker. If the attacker got stunned meanwhile, the hit is
--      cancelled.
--   4. For each model in the hitbox, resolveHit decides: dodged? parried?
--      blocked? guard broken? or a normal hit (damage + stun, knockback on
--      the 4th hit). Then Remotes.CombatEvent tells every client so they
--      can show effects.
--
-- What clients can see (replicated automatically):
--   • tag Config.Combat.TAG on every combatant model,
--   • attributes on the model: "Blocking" (boolean), "Stunned" (boolean).
--
-- API for other server systems:
--   Combat.register(model, player?)    makes a model able to fight
--   Combat.tryAttack(model, aim?, id?) M1 (used by remotes and dummies);
--                                      near a KO'd fighter it finishes them.
--                                      `id` = the client's number for this M1,
--                                      echoed in CombatEvent (prediction)
--
-- Hit zones: the client sends where it AIMS (a direction, Remotes.Attack).
-- The SERVER casts that ray itself from the attacker's head: the body part
-- it meets on the victim gives the zone (a hat or hair counts as the head);
-- if it meets nothing, it's a torso hit. The zone must also be inside the
-- hitbox. A client can't just claim "head": it has to actually aim there.
-- Damage × Config.Combat.ZONE_DAMAGE, a head hit stuns a bit longer, a
-- leg hit slows down.
--
-- 0 HP is not death: Knockout takes over (KO, finisher, respawn).
--   Combat.setBlocking(model, bool)
--   Combat.onDamaged(callback)         every damage dealt (for kills, step 3)
--   Combat.setKit(model, kitId)        the kit used by keys 1–4 / G (Kits system)
--
-- Kit moves (keys 1–4) and the Awakening (G) are in Combat/Moves.luau. Every
-- hit, M1 or move, is decided by resolveHit below from a HitSpec (State.luau).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local AimRule = require(ReplicatedStorage.Shared.Util.AimRule)
local Bruise = require(ReplicatedStorage.Shared.Util.Bruise)
local Gash = require(ReplicatedStorage.Shared.Util.Gash)
local HitSide = require(ReplicatedStorage.Shared.Util.HitSide)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Finishers = require(ReplicatedStorage.Shared.Finishers)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Knockout = require(script.Parent.Knockout)
local Movement = require(script.Parent.Movement)
local PlayerData = require(script.Parent.PlayerData)
local Ragdoll = require(script.Parent.Ragdoll)
local Stamina = require(script.Parent.Stamina)
local Hitbox = require(script.Hitbox)
local Moves = require(script.Moves)
local State = require(script.State)

local C = Config.Combat
local KC = Config.Kits
local INJ = Config.Injuries

-- Dash animation names a client may send (anything else is ignored).
local DASH_ANIMATIONS = table.freeze({
	DashForward = true,
	DashBack = true,
	DashLeft = true,
	DashRight = true,
})
-- Movement states during which a player can't fight (Server/Systems/Movement).
local BUSY_MOVE_STATES = table.freeze({ Slide = true, Climb = true, Vault = true })
-- Body parts (R6 names) of each hit zone.
local ZONE_PARTS: { [Types.HitZone]: { string } } = {
	Head = { "Head" },
	Torso = { "Torso", "HumanoidRootPart", "Right Arm", "Left Arm" },
	Legs = { "Right Leg", "Left Leg" },
}
-- Body part name (R6) → zone, for the server-side aim ray.
local PART_ZONES: { [string]: Types.HitZone } = {
	Head = "Head",
	Torso = "Torso",
	HumanoidRootPart = "Torso",
	["Right Arm"] = "Torso",
	["Left Arm"] = "Torso",
	["Right Leg"] = "Legs",
	["Left Leg"] = "Legs",
}
local random = Random.new()

type CombatState = State.CombatState
type HitSpec = State.HitSpec

export type DamageInfo = {
	victim: Model,
	attacker: Model,
	amount: number,
}

local Combat = {}

local states: { [Model]: CombatState } = {}
local damaged = Signal.new() :: Signal.Signal<DamageInfo>

-- Every outcome of a hit (landed, blocked, parried...), for other systems
-- (daily quests count parries, head hits, kit moves landed...).
export type CombatEventInfo = {
	kind: Types.CombatEventKind,
	victim: Model,
	attacker: Model,
	zone: Types.HitZone?,
	moveId: string?,
}
local events = Signal.new() :: Signal.Signal<CombatEventInfo>

local function now(): number
	return os.clock()
end

local function isAlive(state: CombatState): boolean
	return state.humanoid.Health > 0 and state.model.Parent ~= nil
end

local function isStunned(state: CombatState): boolean
	return now() < state.stunnedUntil
end

-- Sliding or climbing: hands and legs are busy, no fighting.
local function isBusyMoving(state: CombatState): boolean
	local player = state.player
	return player ~= nil and BUSY_MOVE_STATES[Movement.getMoveState(player)] == true
end

-- Can't fight: knocked out, sliding / climbing, in the middle of a finisher,
-- or held by a grab.
local function isBusy(state: CombatState): boolean
	return Knockout.isKnockedOut(state.model)
		or isBusyMoving(state)
		or now() < state.finishingUntil
		or now() < state.knockedDownUntil
		or now() < state.heldUntil
end

local function setAttribute(model: Model, name: string, value: any)
	if model:GetAttribute(name) ~= value then
		model:SetAttribute(name, value)
	end
end

-- `zone` and `side` are only sent when a hit reached the body (or the guard):
-- every client uses them to play the same reaction on the victim.
-- `attackId` = the number the attacker's client gave this M1 (nil for
-- dummies): its client uses it to match the result with its prediction.
local function fireEvent(
	kind: Types.CombatEventKind,
	victim: Model,
	attacker: Model,
	zone: Types.HitZone?,
	side: Types.HitSide?,
	attackId: number?,
	moveId: string?,
	blood: boolean?,
	skinTearSeed: number?
)
	Remotes.CombatEvent:FireAllClients(
		kind,
		victim,
		attacker,
		zone,
		side,
		attackId,
		moveId,
		blood,
		skinTearSeed
	)
end

local function stopBlocking(state: CombatState)
	if state.blocking then
		state.blocking = false
		state.blockEndedAt = now()
		setAttribute(state.model, "Blocking", false)
	end
end

local function stun(state: CombatState, duration: number)
	state.stunnedUntil = math.max(state.stunnedUntil, now() + duration)
	state.attackToken += 1 -- a stunned fighter's wind-up is cancelled
	state.slipUntil = 0 -- ...and so is a slip
	stopBlocking(state)
	setAttribute(state.model, "Stunned", true)
end

local function isAwakened(state: CombatState): boolean
	return now() < state.awakenedUntil
end

-- Awakening gauge: fills by fighting (not while already awakened).
local function addFury(state: CombatState, amount: number)
	if isAwakened(state) or amount <= 0 then
		return
	end
	state.fury = math.min(KC.FURY_MAX, state.fury + amount)
	-- Whole numbers only: the attribute replicates on every change.
	setAttribute(state.model, "Fury", math.floor(state.fury))
end

-- Damage that would bring the victim to 0 HP knocks them out instead
-- (Knockout), it never kills directly. `attacker` = nil for damage over
-- time whose author is gone (bleeding).
local function dealDamage(victim: CombatState, attacker: CombatState?, amount: number)
	local attackerModel = if attacker then attacker.model else victim.bleedSource
	if attackerModel then
		Knockout.noteHit(victim.model, attackerModel)
	end
	-- (Out-of-combat regeneration waits for this to be old enough.)
	victim.lastDamagedAt = now()
	victim.regenCarry = 0
	if victim.humanoid.Health - amount <= 0 then
		stopBlocking(victim)
		victim.attackToken += 1 -- cancels a punch they were winding up
		victim.slipUntil = 0
		Knockout.knockOut(victim.model, attackerModel)
	else
		victim.humanoid.Health -= amount
	end
	addFury(victim, amount * KC.FURY_PER_DAMAGE_TAKEN)
	if attacker then
		addFury(attacker, amount * KC.FURY_PER_DAMAGE_DEALT)
		damaged.fire({ victim = victim.model, attacker = attacker.model, amount = amount })
	end
end

-- Starts (or strengthens) bleeding: a new cut replaces a weaker one and
-- refreshes a stronger one's time.
local function startBleeding(
	victim: CombatState,
	attacker: CombatState,
	perSecond: number,
	duration: number
)
	local time = now()
	victim.bleedPerSecond =
		math.max(perSecond, if time < victim.bleedUntil then victim.bleedPerSecond else 0)
	victim.bleedUntil = math.max(victim.bleedUntil, time + duration)
	victim.nextBleedTick = math.max(victim.nextBleedTick, time + KC.BLEED_TICK)
	victim.bleedSource = attacker.model
	setAttribute(victim.model, "Bleeding", true)
	-- For the victim's HUD: how much the cut will still take.
	setAttribute(victim.model, "BleedPerSecond", victim.bleedPerSecond)
	setAttribute(
		victim.model,
		"BleedUntil",
		workspace:GetServerTimeNow() + (victim.bleedUntil - time)
	)
end

-- Injuries left by a hit that landed (step 5):
--   • a bruise where it landed (addBruise, "Bruise_<Part>_<n>"),
--   • damage on the legs adds up: past LIMP_LEG_DAMAGE the fighter limps.
-- (addBruise is below skinPoint: declared here, set there.)
local addBruise: (victim: CombatState, attacker: CombatState, partName: string, damage: number) -> ()
local function injure(
	victim: CombatState,
	attacker: CombatState,
	zone: Types.HitZone,
	damage: number,
	side: Types.HitSide,
	mark: boolean -- leave a bruise (glass leaves its cut instead)
)
	local part = "Torso"
	if zone == "Head" then
		part = "Head"
	elseif zone == "Legs" then
		-- The leg on the side the kick came from (from the front: the right one).
		part = if side == "Left" then "Left Leg" else "Right Leg"
		victim.legDamage += damage
		if not victim.limping and victim.legDamage >= INJ.LIMP_LEG_DAMAGE then
			victim.limping = true
			setAttribute(victim.model, "Limping", true)
		end
	end
	if mark then
		addBruise(victim, attacker, part, damage)
	end
end

-- Glass cut ("Gash_<Part>_<n>" attributes, see Shared/Util/Gash). Where:
-- on the side of the part that faces the attacker (a bit to the left or
-- right at random), at a random height of the zone (forehead / temple /
-- cheek, chest / belly / back). Hitting the same spot again
-- with the same glass makes that cut bigger (S -> M -> L) instead of adding
-- one; at most Gash.MAX_PER_PART per part. Realistic: a bottle cuts skin and
-- flesh, it never opens a skull or a rib cage.
local GASH_HEIGHT: { [string]: { number } } = { -- studs from the part's centre
	Head = { -0.12, 0.22 },
	Torso = { -0.6, 0.65 },
}
local HEAD_RADIUS = 0.6 -- the round head you see (the head part is 2x1x1)

-- A point of the skin of `part` (part space) on the side facing the
-- attacker, turned by up to `spread` radians, at a random height of the zone.
local function skinPoint(
	part: BasePart,
	key: string,
	attacker: CombatState,
	spread: number,
	heightRange: { number }? -- (studs from the part's centre; default: GASH_HEIGHT)
): Vector3
	-- Toward the attacker, flat, in the part's space, turned up to `spread`.
	local toward = part.CFrame:VectorToObjectSpace(attacker.root.Position - part.Position)
	local flat = Vector3.new(toward.X, 0, toward.Z)
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	direction = CFrame.Angles(0, random:NextNumber(-spread, spread), 0)
		:VectorToWorldSpace(direction)
	local heights = heightRange or GASH_HEIGHT[key]
	local y = random:NextNumber(heights[1], heights[2])
	local point: Vector3
	if key == "Head" then
		point = direction * HEAD_RADIUS * part.Size.Y + Vector3.new(0, y * part.Size.Y, 0)
	else
		-- Torso: on the chest or the back, never on its sides (the arms
		-- cover them). From the side: near the edge on that side.
		local half = part.Size / 2
		local front = if math.abs(direction.Z) > 0.05
			then math.sign(direction.Z)
			else (if random:NextInteger(0, 1) == 0 then -1 else 1)
		local x = math.clamp(
			direction.X / math.max(math.abs(direction.Z), 0.05) * half.Z,
			-0.8 * half.X,
			0.8 * half.X
		)
		point = Vector3.new(x, y, front * half.Z)
	end
	return point
end

-- Bruises: where on each part a blow lands (heights, studs from the centre:
-- the face from the jaw to the brow, the chest to the belly, the limbs).
local BRUISE_HEIGHT: { [string]: { number } } = {
	Head = { -0.26, 0.24 },
	Torso = { -0.7, 0.6 },
	LeftLeg = { -0.6, 0.5 },
	RightLeg = { -0.6, 0.5 },
	LeftArm = { -0.5, 0.5 },
	RightArm = { -0.5, 0.5 },
}
local BRUISE_MERGE = { Head = 0.24, Torso = 0.38 } -- closer than this: the same bruise
local HEAVY_BLOW = 12 -- damage: a blow this hard bruises two levels at once

-- A bruise where the blow landed, facing the attacker. Hit again near it,
-- the same bruise grows (bigger, darker, swollen); else a new one (at most
-- Bruise.MAX_PER_PART: past that, the nearest grows).
addBruise = function(victim: CombatState, attacker: CombatState, partName: string, damage: number)
	local key = Gash.KEY_OF[partName]
	local part = victim.model:FindFirstChild(partName)
	if key == nil or part == nil or not part:IsA("BasePart") then
		return
	end
	local point = skinPoint(part, key, attacker, 0.45, BRUISE_HEIGHT[key])
	local grow = if damage >= HEAVY_BLOW then 2 else 1
	local nearest, nearestIndex, nearestDistance = nil :: Bruise.Data?, 0, math.huge
	local free = 0
	for index = 1, Bruise.MAX_PER_PART do
		local data = Bruise.decode(victim.model:GetAttribute(Bruise.attribute(key, index)))
		if data then
			local distance = (data.point - point).Magnitude
			if distance < nearestDistance then
				nearest, nearestIndex, nearestDistance = data, index, distance
			end
		elseif free == 0 then
			free = index
		end
	end
	local merge = BRUISE_MERGE[key] or 0.32
	if nearest and (nearestDistance <= merge or free == 0) then
		nearest.level = math.min(Bruise.MAX_LEVEL, nearest.level + grow)
		setAttribute(victim.model, Bruise.attribute(key, nearestIndex), Bruise.encode(nearest))
		return
	end
	setAttribute(
		victim.model,
		Bruise.attribute(key, free),
		Bruise.encode({
			point = point,
			level = math.min(Bruise.MAX_LEVEL, grow),
			born = workspace:GetServerTimeNow(),
			seed = random:NextInteger(1, 2 ^ 30),
		})
	)
end

local function addGash(
	victim: CombatState,
	attacker: CombatState,
	zone: string, -- Types.HitZone
	kind: "Lac" | "Slash"
)
	-- (Glass moves aim at the head or the torso: Moves' AIMABLE_ZONES.)
	if zone ~= "Head" and zone ~= "Torso" then
		return
	end
	local partName = zone
	local part = victim.model:FindFirstChild(partName)
	local key = Gash.KEY_OF[partName]
	if part == nil or not part:IsA("BasePart") or key == nil then
		return
	end
	local point = skinPoint(part, key, attacker, 0.45)
	-- A slash runs across, a bit diagonal; a laceration can point any way.
	local angle = if kind == "Slash"
		then random:NextNumber(12, 45) * (if random:NextInteger(0, 1) == 0 then -1 else 1)
		else random:NextNumber(-90, 90)

	-- Same glass, close to an old cut: that cut grows.
	local free: number? = nil
	local closest: number? = nil
	local closestDistance = math.huge
	for index = 1, Gash.MAX_PER_PART do
		local old = Gash.decode(victim.model:GetAttribute(Gash.attribute(key, index)))
		if old == nil then
			free = free or index
		else
			local distance = (old.point - point).Magnitude
			if
				old.kind == kind
				and distance < INJ.GASH_MERGE_DISTANCE
				and distance < closestDistance
			then
				closest, closestDistance = index, distance
			end
		end
	end
	if closest == nil and free == nil then
		-- No room left: the nearest cut of any kind grows instead.
		for index = 1, Gash.MAX_PER_PART do
			local old = Gash.decode(victim.model:GetAttribute(Gash.attribute(key, index)))
			if old and (old.point - point).Magnitude < closestDistance then
				closest, closestDistance = index, (old.point - point).Magnitude
			end
		end
	end
	if closest then
		local attribute = Gash.attribute(key, closest)
		local old = Gash.decode(victim.model:GetAttribute(attribute))
		if old then
			old.size = Gash.bigger(old.size)
			setAttribute(victim.model, attribute, Gash.encode(old))
		end
	elseif free then
		setAttribute(
			victim.model,
			Gash.attribute(key, free),
			Gash.encode({
				kind = kind,
				size = "S",
				point = point,
				angle = angle,
				seed = random:NextInteger(1, 2 ^ 30),
			})
		)
	end
end

-- Bits of glass stuck in the skin ("Shard_<Part>_<n>", Shared/Util/Gash):
-- a bottle bursting on someone leaves a few, often without a real cut.
local function addShards(victim: CombatState, attacker: CombatState, zone: string, count: number)
	if zone ~= "Head" and zone ~= "Torso" then
		return
	end
	local part = victim.model:FindFirstChild(zone)
	local key = Gash.KEY_OF[zone]
	if part == nil or not part:IsA("BasePart") or key == nil then
		return
	end
	for _ = 1, count do
		local free: number? = nil
		for index = 1, Gash.MAX_SHARDS_PER_PART do
			if victim.model:GetAttribute(Gash.shardAttribute(key, index)) == nil then
				free = index
				break
			end
		end
		if free == nil then
			return -- (full: enough glass in there)
		end
		setAttribute(
			victim.model,
			Gash.shardAttribute(key, free),
			Gash.encodeShard({
				point = skinPoint(part, key, attacker, 0.9),
				yaw = random:NextNumber(0, 360),
				tilt = random:NextNumber(15, 55),
				seed = random:NextInteger(1, 2 ^ 30),
			})
		)
	end
end

-- A kill (or nothing at all, see onKill): every injury is healed.
local function healInjuries(state: CombatState)
	state.legDamage = 0
	state.limping = false
	setAttribute(state.model, "Limping", false)
	-- Cuts and bruises: a new body.
	for name in state.model:GetAttributes() do
		if Gash.isInjuryAttribute(name) or Bruise.isAttribute(name) then
			setAttribute(state.model, name, nil)
		end
	end
	state.bleedUntil = 0 -- update() stops the bleeding on its next frame
end

-- Knocked to the ground (tackle, launch): the body goes limp for `duration`
-- seconds, then gets back up. A KO meanwhile takes over (Knockout).
local function knockDown(victim: CombatState, duration: number, velocity: Vector3)
	if Knockout.isKnockedOut(victim.model) then
		return
	end
	victim.knockdownToken += 1
	local token = victim.knockdownToken
	local time = now()
	victim.knockedDownUntil = time + duration
	stun(victim, duration + KC.KNOCKDOWN_GETUP_STUN)
	Ragdoll.enable(victim.model)
	-- The server owns the limp body now: throw it.
	victim.root.AssemblyLinearVelocity = velocity
	task.delay(duration, function()
		if
			victim.knockdownToken ~= token
			or not isAlive(victim)
			or Knockout.isKnockedOut(victim.model) -- the KO gets them up itself
		then
			return
		end
		victim.knockedDownUntil = 0
		Ragdoll.disable(victim.model, victim.player)
		Remotes.CombatAction:FireAllClients(victim.model, "GetUp")
	end)
end

-- The zone a hit lands on: the one aimed at, if that body part of the
-- victim is inside the hitbox (and a punch can reach it); else the first
-- allowed zone that is (torso first).
local function landingZone(
	requested: Types.HitZone,
	partsInBox: { [string]: boolean },
	allowed: { string }
): Types.HitZone
	local function inBox(zone: Types.HitZone): boolean
		for _, partName in ZONE_PARTS[zone] do
			if partsInBox[partName] then
				return true
			end
		end
		return false
	end
	if table.find(allowed, requested) and inBox(requested) then
		return requested
	end
	if table.find(allowed, "Torso") and inBox("Torso") then
		return "Torso" :: Types.HitZone
	end
	for _, zone in allowed do
		if inBox(zone :: Types.HitZone) then
			return zone :: Types.HitZone
		end
	end
	return "Torso" :: Types.HitZone
end

-- Is `attacker` in front of `victim`? (You can't block a hit in the back.)
local function isInFront(victim: CombatState, attacker: CombatState): boolean
	local offset = attacker.root.Position - victim.root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 1e-3 then
		return true
	end
	local look = victim.root.CFrame.LookVector
	return flat.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) > 0
end

-- Flat direction from the attacker to the victim (where a hit pushes).
local function awayFromAttacker(attacker: CombatState, victim: CombatState): Vector3
	local away = victim.root.Position - attacker.root.Position
	local flat = Vector3.new(away.X, 0, away.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else attacker.root.CFrame.LookVector
end

-- Decides what a hit does to `victim`. The heart of the combat rules.
-- `spec` = what the hit does (an M1 or a kit move, see State.HitSpec).
-- Returns true if the hit LANDED on the body (not dodged, parried, blocked,
-- protected or on someone already knocked out).
local function resolveHit(attacker: CombatState, victim: CombatState, spec: HitSpec): boolean
	local time = now()
	local zone = spec.zone
	-- Which side of the victim the blow arrives from (picks the reaction).
	local side: Types.HitSide = HitSide.compute(victim.root.CFrame, attacker.root.Position)
	-- Blood / torn skin of a hit that lands (decided below, sent with it).
	local blood = false
	local skinTearSeed: number? = nil
	local function event(kind: Types.CombatEventKind, withZone: boolean, withSide: boolean)
		fireEvent(
			kind,
			victim.model,
			attacker.model,
			if withZone then zone :: Types.HitZone else nil,
			if withSide then side else nil,
			spec.attackId,
			spec.moveId,
			if blood then true else nil,
			skinTearSeed
		)
		events.fire({
			kind = kind,
			victim = victim.model,
			attacker = attacker.model,
			zone = if withZone then zone :: Types.HitZone else nil,
			moveId = spec.moveId,
		})
	end
	-- Awakened attackers hit harder.
	local damage = spec.damage
	local awakening = Kits.get(attacker.kitId)
	if isAwakened(attacker) and awakening and awakening.awakening then
		damage *= awakening.awakening.damageMultiplier
	end
	-- A heavy build (Bouncer) takes less from every hit.
	local victimKit = Kits.get(victim.kitId)
	if victimKit and victimKit.damageTaken then
		damage *= victimKit.damageTaken
	end

	-- 0. Not in the same fight: a duel is only between its two fighters
	-- ("DuelId" attribute, nil for everyone in the free arena).
	if victim.model:GetAttribute("DuelId") ~= attacker.model:GetAttribute("DuelId") then
		return false
	end
	-- On the ground (finish them instead), or just spawned (protected).
	if Knockout.isKnockedOut(victim.model) then
		return false
	end
	if Knockout.isProtected(victim.model) then
		event("Protected", false, false)
		return false
	end

	-- 0b. In a cinematic finisher: untouchable (no effect, it's a cutscene).
	if time < victim.cinematicUntil then
		return false
	end

	-- 1. Dash dodge frames: the hit misses.
	if time < victim.invulnerableUntil then
		event("Dodged", false, false)
		return false
	end

	-- 1b. Slip (Boxer): a hit from the front is slipped, and answered. The
	-- attacker's move is cut (its next hits don't land), and the slipper
	-- can't be hit by anyone until the counter lands.
	if
		time < victim.slipUntil
		and isInFront(victim, attacker)
		and not isStunned(victim)
		and not isBusy(victim)
	then
		victim.slipUntil = 0
		attacker.attackToken += 1
		event("Dodged", false, false)
		Moves.counter(victim, attacker)
		return false
	end

	if victim.blocking and spec.grab then
		-- 2a. A grab: hands, not a blow. Nothing to parry, it goes through
		-- the guard (only a hit that stuns him first, or a dash, beats it).
		stopBlocking(victim)
	elseif victim.blocking and isInFront(victim, attacker) then
		-- 2. Parry: block started just before the hit → attacker is stunned.
		if victim.parryReady and time - victim.blockStartedAt <= C.PARRY_WINDOW then
			stun(attacker, C.PARRY_STUN)
			event("Parried", false, false)
			return false
		end

		if spec.unblockable then
			-- 3a. Unblockable (a tackle): the guard is simply run through.
			stopBlocking(victim)
		else
			-- 3b. Block: costs stamina. Not enough → guard break.
			local victimPlayer = victim.player
			if victimPlayer and not Stamina.trySpend(victimPlayer, spec.blockCost) then
				Stamina.drain(victimPlayer, Config.Stamina.MAX) -- empty the bar
				stun(victim, C.GUARD_BREAK_STUN)
				event("GuardBreak", false, true)
				return false
			end
			dealDamage(victim, attacker, damage * (1 - C.BLOCK_REDUCTION))
			-- The guard absorbs the hit but is still shoved back a little.
			if time >= victim.knockbackUntil then
				Push.apply(
					victim.root,
					awayFromAttacker(attacker, victim) * C.BLOCK_PUSH_SPEED,
					C.HIT_PUSH_TIME
				)
			end
			event("Blocked", false, true)
			return false
		end
	end

	-- 4. Normal hit.
	dealDamage(victim, attacker, damage)

	-- Blood: rolled here, so every client shows the same thing. Fists rarely
	-- draw blood; the bottle's moves set their own (high) chance. The 4th M1
	-- on the head may open a cut (then it bleeds, see below).
	local critCut = false
	local bloodChance: number = 0
	local chances = spec.bloodChance
	if chances ~= nil then
		bloodChance = chances[zone] or 0
	elseif spec.moveId ~= nil then
		bloodChance = 0 -- a kit move that doesn't say it cuts: no blood
	elseif spec.kind == "Finisher" and zone == "Head" then
		critCut = random:NextNumber() < INJ.CRIT_BLEED_CHANCE
		bloodChance = if critCut then 1 else 0
	else
		bloodChance = INJ.PUNCH_BLOOD_CHANCE[zone] or 0
	end
	blood = random:NextNumber() < bloodChance
	-- Glass cuts the skin where it really landed (the zone the attacker aimed
	-- at), on the side facing the attacker. Even on the blow that knocks
	-- them out.
	if spec.cuts and INJ.SKIN_TEAR then
		skinTearSeed = random:NextInteger(1, 2 ^ 30)
		if spec.cuts == "Lac" then
			-- A bottle bursting: bits of glass stuck in the skin, and most of
			-- the time a torn cut (sometimes it only grazes).
			addShards(victim, attacker, zone, random:NextInteger(1, 3))
			if random:NextNumber() < INJ.GLASS_GRAZE_CHANCE then
				skinTearSeed = nil -- (no torn skin flying off either)
			else
				addGash(victim, attacker, zone, spec.cuts)
			end
		else
			addGash(victim, attacker, zone, spec.cuts)
			if random:NextNumber() < 0.4 then
				addShards(victim, attacker, zone, 1) -- a sliver of the jagged edge
			end
		end
	end

	if Knockout.isKnockedOut(victim.model) then
		-- That hit knocked them out: no stun or knockback on a limp body.
		event(spec.kind, true, true)
		return true
	end

	-- Lasting effects (even through the Awakening's armor).
	if spec.legSlow and zone == "Legs" then
		victim.legSlowUntil = time + C.LEG_HIT_SLOW_TIME
	end
	local slow = spec.slow
	if slow then
		victim.slowUntil = time + slow.duration
		victim.slowMultiplier = slow.multiplier
	end
	-- Body shot: the breath goes out of them.
	local drain = spec.staminaDrain
	local victimPlayer = victim.player
	if drain and victimPlayer then
		Stamina.drain(victimPlayer, drain)
	end
	local bleed = spec.bleed
	-- The 4th M1 on the head opened a cut (rolled above).
	if bleed == nil and critCut then
		bleed = INJ.CRIT_BLEED
	end
	if bleed then
		startBleeding(victim, attacker, bleed.perSecond, bleed.duration)
		-- Where it bleeds from (the drops fall from there, see KitEffects).
		setAttribute(
			victim.model,
			"BleedPart",
			if zone == "Head" then "Head" elseif zone == "Legs" then "Right Leg" else "Torso"
		)
	end
	-- (Glass leaves its cut instead of a bruise mark: no disc over the cut.)
	injure(victim, attacker, zone :: Types.HitZone, damage, side, spec.cuts == nil)

	-- Awakened fighters have "hyper armor": hits hurt but don't stop them.
	if isAwakened(victim) then
		event(spec.kind, true, true)
		return true
	end

	local away = awayFromAttacker(attacker, victim)
	local extraStun = if spec.headStun and zone == "Head" then C.HEAD_EXTRA_STUN else 0
	local knockdown = spec.knockdown
	local knockback = spec.knockback
	local pull = spec.pull
	if spec.grab or time < victim.heldUntil then
		-- Caught / held (Combat/Grab): no push, the hold places the body.
		stun(victim, spec.stun)
	elseif knockdown then
		-- Thrown to the ground (and away, upward if it's a launch).
		local speed = knockback or 0
		local up = spec.launch or (if speed >= 40 then KC.LAUNCH_UP_SPEED else 4)
		knockDown(victim, knockdown, away * speed + Vector3.new(0, up, 0))
	else
		stun(victim, spec.stun + extraStun)
		if knockback then
			Push.apply(victim.root, away * knockback, C.KNOCKBACK_TIME)
			victim.knockbackUntil = time + C.KNOCKBACK_TIME
		elseif pull then
			-- Grabbed: dragged toward the attacker (stops at arm's length).
			Push.apply(victim.root, -away * pull, C.HIT_PUSH_TIME)
		elseif time >= victim.knockbackUntil then
			-- Small push: the body is moved by the blow (no "punch through it"
			-- look). Not during a knockback (a new push would replace it).
			Push.apply(victim.root, away * C.HIT_PUSH_SPEED, C.HIT_PUSH_TIME)
		end
	end
	event(spec.kind, true, true)
	return true
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

-- Makes `model` able to fight. `player` = nil for dummies.
-- Forgotten automatically when the model is destroyed / removed.
function Combat.register(model: Model, player: Player?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		warn(`[Combat] {model:GetFullName()} has no Humanoid/HumanoidRootPart, not registered`)
		return
	end

	states[model] = {
		model = model,
		humanoid = humanoid,
		root = root,
		player = player,
		combo = 0,
		lastAttackAt = -math.huge,
		nextAttackAt = 0,
		attackingUntil = 0,
		attackToken = 0,
		blocking = false,
		blockStartedAt = -math.huge,
		blockEndedAt = -math.huge,
		parryReady = false,
		stunnedUntil = 0,
		legSlowUntil = 0,
		finishingUntil = 0,
		invulnerableUntil = 0,
		cinematicUntil = 0,
		cinematicToken = 0,
		nextDashAt = 0,
		knockbackUntil = 0,
		kitId = Kits.DEFAULT,
		cooldowns = {},
		fury = 0,
		awakenedUntil = 0,
		bleedPerSecond = 0,
		bleedUntil = 0,
		nextBleedTick = 0,
		bleedSource = nil,
		slowUntil = 0,
		slowMultiplier = 1,
		knockdownToken = 0,
		knockedDownUntil = 0,
		legDamage = 0,
		limping = false,
		lastDamagedAt = -math.huge,
		regenCarry = 0,
		slipUntil = 0,
		slipMoveId = nil,
		heldUntil = 0,
		holding = nil,
		heldBy = nil,
		weapon = nil,
		weaponHits = 0,
	}
	model:SetAttribute("Blocking", false)
	model:SetAttribute("Stunned", false)
	model:SetAttribute("Fury", 0)
	model:SetAttribute("Awakened", false)
	model:SetAttribute("Bleeding", false)
	model:SetAttribute("Limping", false)
	-- A player fights with the kit saved in their profile.
	-- (Only a kit they still own: Kits.owns.)
	local data = if player then PlayerData.getData(player) else nil
	local saved = if data then Kits.get(data.equippedKit) else nil
	local usable = data ~= nil and saved ~= nil and Kits.owns(data, saved)
	Combat.setKit(model, if usable and data then data.equippedKit else Kits.DEFAULT)
	CollectionService:AddTag(model, C.TAG)
	Knockout.register(model, player)

	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			states[model] = nil
		end
	end)
end

-- The bat finisher: the head bursts. Every client shows it (and the neck
-- left open) from this attribute, its value = the seed of the pieces.
local function blowHead(victim: Model)
	setAttribute(victim, "HeadBlown", random:NextInteger(1, 2 ^ 30))
end

-- The Boxer's finisher: the liver torn out under the right ribs. A "Tear"
-- cut (Gashes draws the hole, broken ribs in it, through the clothes).
local function tearLiverOut(victim: Model)
	local index = 1
	for candidate = 1, Gash.MAX_PER_PART do
		if victim:GetAttribute(Gash.attribute("Torso", candidate)) == nil then
			index = candidate
			break
		end
	end
	setAttribute(
		victim,
		Gash.attribute("Torso", index),
		Gash.encode({
			kind = "Tear",
			size = "L",
			point = Vector3.new(0.5, -0.3, -0.5), -- its right, under the ribs, in front
			angle = 0,
			seed = random:NextInteger(1, 2 ^ 30),
		})
	)
end

-- Weapons (Shared/Weapons): one in the right hand ("Weapon" attribute, the
-- clients show it and swing it). Gone when it breaks (every client sees it
-- snap: Remotes.WeaponBroke), or when its holder is knocked out or dies.
local function giveWeapon(state: CombatState, id: string)
	state.weapon = id
	state.weaponHits = 0
	setAttribute(state.model, "Weapon", id)
end

local function dropWeapon(state: CombatState, broke: boolean)
	local id = state.weapon
	if id == nil then
		return
	end
	state.weapon = nil
	state.weaponHits = 0
	setAttribute(state.model, "Weapon", nil)
	if broke then
		Remotes.WeaponBroke:FireAllClients(state.model, id)
	end
end

-- A torn arm lying on the floor: anyone close can pull the bone out of it
-- (a ProximityPrompt; the server checks everything again).
local function offerBone(victim: Model, arm: BasePart)
	local point = Instance.new("Attachment")
	point.Name = "BonePrompt"
	point.Parent = arm
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take the bone"
	prompt.ObjectText = "Torn arm"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local state = if character then states[character] else nil
		if
			state == nil
			or not isAlive(state)
			or isBusy(state)
			or isStunned(state)
			or state.weapon ~= nil
			or state.model:GetAttribute("DuelId") ~= nil -- (no weapons in a duel)
			or victim:GetAttribute("BoneTaken") == true
			or arm.Parent == nil
			or (state.root.Position - arm.Position).Magnitude > 9
		then
			return
		end
		setAttribute(victim, "BoneTaken", true)
		point:Destroy()
		giveWeapon(state, "Bone")
	end)
end

-- The Bouncer's finisher: the right arm torn off at the shoulder. Every
-- client draws the wounds from "ArmTorn" (its value = a seed): the open
-- socket on the torso, the bone sticking out of the arm. The arm stays a
-- part of the body (its sleeve stays on), held in his right fist
-- (Finishers.ARM_GRIP) until he throws it down `throwIn` seconds later.
local function tearArmOff(victim: Model, attacker: Model, anchor: CFrame, throwIn: number?)
	local torso = victim:FindFirstChild("Torso")
	local arm = victim:FindFirstChild("Right Arm")
	local fist = attacker:FindFirstChild("Right Arm")
	if
		not (
			torso
			and torso:IsA("BasePart")
			and arm
			and arm:IsA("BasePart")
			and fist
			and fist:IsA("BasePart")
		)
	then
		return
	end
	-- Off the shoulder: its joint, and the loose one of the ragdoll.
	for _, item in torso:GetChildren() do
		if
			item.Name == "Right Shoulder"
			or item.Name == "Ragdoll_Right Shoulder"
			or item.Name == "Ragdoll_Right Shoulder0"
		then
			item:Destroy()
		end
	end
	local socket = arm:FindFirstChild("Ragdoll_Right Shoulder1")
	if socket then
		socket:Destroy()
	end
	arm.CanCollide = false
	arm.Massless = true
	local grip = Instance.new("Weld")
	grip.Name = "TornArmGrip"
	grip.Part0 = fist
	grip.Part1 = arm
	grip.C0 = Finishers.ARM_GRIP
	grip.Parent = arm
	setAttribute(victim, "ArmTorn", random:NextInteger(1, 2 ^ 30))
	if throwIn == nil then
		return
	end
	task.delay(throwIn, function()
		if grip.Parent == nil or arm.Parent == nil then
			return
		end
		grip:Destroy()
		-- (from where it is in his hand on every screen at that moment)
		arm.CFrame = anchor * Finishers.ARM_THROW_FROM
		arm.Massless = false
		arm.CanCollide = true
		if arm:CanSetNetworkOwnership() then
			arm:SetNetworkOwner(nil)
		end
		arm.AssemblyLinearVelocity = anchor:VectorToWorldSpace(Finishers.ARM_THROW_VELOCITY)
		arm.AssemblyAngularVelocity = anchor:VectorToWorldSpace(Vector3.new(5, 1, -3))
		-- Once it lies there, its bone can be taken.
		task.delay(0.8, function()
			if arm.Parent then
				offerBone(victim, arm)
			end
		end)
	end)
end

-- A cinematic finisher (Shared/Finishers): both fighters are placed and held
-- still (anchored) for the cutscene, the attacker can't be touched, the
-- victim dies at the killing blow. Every client plays the camera / effects
-- from Remotes.FinisherStarted.
local function startCinematic(
	state: CombatState,
	target: Model,
	finisher: Kits.FinisherDef,
	cinematic: Finishers.Cinematic
)
	local root = state.root
	local victimRoot = target:FindFirstChild("HumanoidRootPart")
	local victimHead = target:FindFirstChild("Head")
	if
		not (
			victimRoot
			and victimRoot:IsA("BasePart")
			and victimHead
			and victimHead:IsA("BasePart")
		)
	then
		Knockout.release(target)
		return
	end
	local time = now()
	local token = state.attackToken

	-- Where everyone stands.
	local anchor: CFrame
	local victimPlace: CFrame? = nil
	if cinematic.placement == "head" then
		-- Past the head of the body lying there (the body beyond it, the
		-- camera shots count on it), looking down at it.
		-- No room there (a wall, the edge of the map): his own side of the
		-- head, then the sides; never inside a wall.
		local head = victimHead.Position
		local torso = target:FindFirstChild("Torso")
		local body = if torso and torso:IsA("BasePart") then torso.Position else victimRoot.Position
		local function flat(v: Vector3): Vector3?
			local f = Vector3.new(v.X, 0, v.Z)
			return if f.Magnitude > 0.1 then f.Unit else nil
		end
		local past = flat(head - body)
		local own = flat(root.Position - head) or -root.CFrame.LookVector
		local candidates: { Vector3 } = {}
		if past then
			table.insert(candidates, past)
		end
		table.insert(candidates, own)
		if past then
			table.insert(candidates, past:Cross(Vector3.new(0, 1, 0)))
			table.insert(candidates, -past:Cross(Vector3.new(0, 1, 0)))
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { state.model, target }
		params.RespectCanCollide = true
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { state.model, target }
		overlap.RespectCanCollide = true
		-- Where he'd stand (his feet on the floor there, if there is one).
		local function standingAt(direction: Vector3): Vector3
			local stand = Vector3.new(head.X, root.Position.Y, head.Z)
				+ direction * Finishers.HEAD_DISTANCE
			local floor =
				workspace:Raycast(stand + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), params)
			return if floor then Vector3.new(stand.X, floor.Position.Y + 3, stand.Z) else stand
		end
		-- A floor at the feet' height under `at` (studs, y of the root - 3).
		local function floorAt(at: Vector3, rootY: number): boolean
			local hit =
				workspace:Raycast(Vector3.new(at.X, rootY - 1, at.Z), Vector3.new(0, -3, 0), params)
			return hit ~= nil and math.abs(hit.Position.Y - (rootY - 3)) < 0.8
		end
		-- Room for him there, and for the body laid out beyond the head.
		local function isClear(stand: Vector3): boolean
			local from = Vector3.new(head.X, stand.Y + 1, head.Z)
			if workspace:Raycast(from, stand + Vector3.new(0, 1, 0) - from, params) then
				return false -- a wall between the head and there
			end
			if
				#workspace:GetPartBoundsInBox(
					CFrame.new(stand + Vector3.new(0, -0.2, 0)),
					Vector3.new(1.8, 4.4, 1.2),
					overlap
				) > 0
			then
				return false
			end
			local look = Vector3.new(head.X - stand.X, 0, head.Z - stand.Z)
			if look.Magnitude < 0.1 then
				return false
			end
			look = look.Unit
			local bodyAt = stand + look * 5.75 + Vector3.new(0, -2.4, 0)
			if
				#workspace:GetPartBoundsInBox(
					CFrame.lookAt(bodyAt, bodyAt + look),
					Vector3.new(2.2, 0.8, 5.1),
					overlap
				) > 0
			then
				return false -- (a wall where the body would lie)
			end
			return floorAt(stand, stand.Y)
				and floorAt(stand + look * Finishers.HEAD_DISTANCE, stand.Y)
				and floorAt(stand + look * 7.6, stand.Y)
		end
		local stand: Vector3? = nil
		for _, direction in candidates do
			local at = standingAt(direction)
			if isClear(at) then
				stand = at
				break
			end
		end
		if stand then
			anchor = CFrame.lookAt(stand, Vector3.new(head.X, stand.Y, head.Z))
			-- The victim laid out flat on its back in front of him, head
			-- toward him (lying however it fell, even still standing, the
			-- shots and the bat would miss it): its head at
			-- (0, -2.45, -HEAD_DISTANCE).
			victimPlace = anchor
				* CFrame.new(0, -2.45, -(Finishers.HEAD_DISTANCE + 1.5))
				* CFrame.fromMatrix(
					Vector3.zero,
					Vector3.new(1, 0, 0), -- its right: his right
					Vector3.new(0, 0, 1), -- its head: toward him
					Vector3.new(0, -1, 0) -- its back: on the floor (face up)
				)
		else
			-- Nowhere to lay it out (walls, a ledge): it stays as it lies,
			-- he stands on his own side of the head.
			local fallback = standingAt(own)
			anchor = CFrame.lookAt(fallback, Vector3.new(head.X, fallback.Y, head.Z))
		end
	elseif cinematic.placement == "side" then
		-- The body laid on its back across in front of him, where it lies now
		-- (Finishers.SIDE_VICTIM): he comes to stand by it. Facing it the way
		-- he comes from, else turned a quarter / half way round: the first
		-- spot with a floor under both and no wall.
		local torso = target:FindFirstChild("Torso")
		local body = if torso and torso:IsA("BasePart") then torso.Position else victimRoot.Position
		local toward = Vector3.new(body.X - root.Position.X, 0, body.Z - root.Position.Z)
		toward = if toward.Magnitude > 0.1 then toward.Unit else root.CFrame.LookVector
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { state.model, target }
		params.RespectCanCollide = true
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { state.model, target }
		overlap.RespectCanCollide = true
		-- The floor's height under `at` (y of a root standing there), or nil.
		local function floorUnder(at: Vector3): number?
			local hit = workspace:Raycast(
				Vector3.new(at.X, root.Position.Y + 1, at.Z),
				Vector3.new(0, -8, 0),
				params
			)
			return if hit then hit.Position.Y + 3 else nil
		end
		local laid = Finishers.SIDE_VICTIM
		local function anchorFacing(direction: Vector3): CFrame?
			local look = CFrame.lookAt(Vector3.zero, direction)
			-- (the body stays where it is: he stands so it lies at SIDE_VICTIM)
			local offset = look:VectorToWorldSpace(Vector3.new(laid.X, 0, laid.Z))
			local stand = Vector3.new(body.X, 0, body.Z) - offset
			local y = floorUnder(stand)
			if y == nil then
				return nil
			end
			local candidate = CFrame.lookAt(
				Vector3.new(stand.X, y, stand.Z),
				Vector3.new(stand.X, y, stand.Z) + direction
			)
			-- Room for him, and for the body (along his X, feet to his right).
			if
				#workspace:GetPartBoundsInBox(
						candidate * CFrame.new(0, -0.2, 0),
						Vector3.new(2.2, 4.4, 1.6),
						overlap
					)
					> 0
				or #workspace:GetPartBoundsInBox(
						candidate * CFrame.new(0.8, -2.4, laid.Z),
						Vector3.new(5.6, 0.8, 3.2),
						overlap
					)
					> 0
			then
				return nil
			end
			for _, x in { -1.6, 0.8, 3.2 } do
				local under = floorUnder((candidate * CFrame.new(x, 0, laid.Z)).Position)
				if under == nil or math.abs(under - y) > 0.8 then
					return nil
				end
			end
			return candidate
		end
		local up = Vector3.new(0, 1, 0)
		local found: CFrame? = nil
		for _, direction in { toward, toward:Cross(up), -toward:Cross(up), -toward } do
			found = anchorFacing(direction)
			if found then
				break
			end
		end
		-- (nowhere clear: where he is, facing it, as close as it gets)
		anchor = found or CFrame.lookAt(root.Position, root.Position + toward)
		victimPlace = anchor * laid
	else
		-- Where he is, facing the body; the victim hauled up in front of him.
		local toward = Vector3.new(
			victimRoot.Position.X - root.Position.X,
			0,
			victimRoot.Position.Z - root.Position.Z
		)
		toward = if toward.Magnitude > 0.1 then toward.Unit else root.CFrame.LookVector
		anchor = CFrame.lookAt(root.Position, root.Position + toward)
		victimPlace = anchor
			* CFrame.new(0, 0, -Finishers.HOLD_DISTANCE)
			* CFrame.Angles(0, math.pi, 0)
	end
	root.Anchored = true
	root.CFrame = anchor
	state.cinematicUntil = time + cinematic.duration
	state.cinematicToken += 1
	local cinematicToken = state.cinematicToken
	setAttribute(state.model, "InCinematic", true) -- (the client holds its inputs)
	if victimPlace then
		Ragdoll.disable(target)
		victimRoot.Anchored = true
		victimRoot.CFrame = victimPlace
	end

	Remotes.CombatAction:FireAllClients(state.model, finisher.animation)
	if cinematic.victimAnimation then
		Remotes.CombatAction:FireAllClients(target, cinematic.victimAnimation)
	end
	Remotes.FinisherStarted:FireAllClients(state.model, target, cinematic.id, anchor)

	local connections: { RBXScriptConnection } = {}
	local over = false
	local killed = false
	-- Everything this cinematic holds, let go (once). Before the killing
	-- blow, the victim drops back down, still KO'd (someone can finish them).
	local function finish()
		if over then
			return
		end
		over = true
		for _, connection in connections do
			connection:Disconnect()
		end
		if not killed then
			if victimPlace and victimRoot.Parent then
				victimRoot.Anchored = false
				Ragdoll.enable(target)
			end
			Knockout.release(target)
		end
		-- (only if no newer cinematic took this fighter over)
		if state.cinematicToken == cinematicToken then
			if root.Parent then
				root.Anchored = false
			end
			state.cinematicUntil = 0
			state.finishingUntil = 0
			setAttribute(state.model, "InCinematic", nil)
		end
		Remotes.FinisherEnded:FireAllClients(state.model, target, killed)
	end
	-- Interrupted: the attacker dies or leaves, the victim leaves.
	table.insert(
		connections,
		state.humanoid.Died:Connect(function()
			finish()
		end)
	)
	for _, model in { state.model, target } do
		table.insert(
			connections,
			model.AncestryChanged:Connect(function()
				if model.Parent == nil then
					finish()
				end
			end)
		)
	end

	task.delay(cinematic.kill, function()
		if over then
			return
		end
		if state.attackToken ~= token or not isAlive(state) or target.Parent == nil then
			finish()
			return
		end
		killed = true
		if victimPlace then
			-- Limp: it folds and drops where it stands.
			victimRoot.Anchored = false
			Ragdoll.enable(target)
		end
		Knockout.finish(target, state.model)
		local victimHumanoid = target:FindFirstChildOfClass("Humanoid")
		if victimHumanoid and victimHumanoid.Health <= 0 then -- (a body that really died)
			if cinematic.id == "Bat" then
				blowHead(target)
			elseif cinematic.id == "KnockoutCombo" then
				tearLiverOut(target)
			elseif cinematic.id == "ArmRip" then
				local throwIn: number? = nil
				for _, event in cinematic.events do
					if event.kind == "Throw" then
						throwIn = event.time - cinematic.kill
					end
				end
				tearArmOff(target, state.model, anchor, throwIn)
			end
		end
		-- (the attacker stays held until the end of the cutscene)
	end)
	task.delay(cinematic.duration, finish)
end

-- Is this fighter in a cinematic finisher right now (Duels wait for it)?
function Combat.isInCinematic(model: Model): boolean
	local state = states[model]
	return state ~= nil and now() < state.cinematicUntil
end

-- Finisher on a KO'd fighter: kneel and strike; the victim dies at impact
-- unless the attacker is stunned (or dies) before. Kits can have their own,
-- some of them cinematic (Shared/Finishers).
local function startFinisher(state: CombatState, target: Model): boolean
	if not Knockout.reserve(target, state.model) then
		return false
	end
	local time = now()
	local K = Config.Knockout
	local finisher = Kits.finisher(state.kitId)
	state.nextAttackAt = time + finisher.duration
	state.finishingUntil = time + finisher.duration
	state.attackingUntil = time + finisher.duration
	state.combo = 0
	state.attackToken += 1
	local token = state.attackToken

	local cinematic = Finishers.get(finisher.cinematic)
	if cinematic then
		startCinematic(state, target, finisher, cinematic)
		return true
	end

	Remotes.CombatAction:FireAllClients(state.model, finisher.animation)
	task.delay(finisher.impact, function()
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		local stillThere = targetRoot ~= nil
			and targetRoot:IsA("BasePart")
			and (targetRoot.Position - state.root.Position).Magnitude <= K.FINISH_RANGE + 2
		if state.attackToken ~= token or not isAlive(state) or not stillThere then
			Knockout.release(target) -- interrupted: someone else can finish them
			state.finishingUntil = 0
			return
		end
		Knockout.finish(target, state.model)
	end)
	return true
end

-- The zone the attacker's aim ray meets on `victim`, or nil if it misses.
local function aimZone(attacker: CombatState, victim: Model, direction: Vector3): Types.HitZone?
	local head = attacker.model:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else attacker.root.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { victim }
	local hit = workspace:Raycast(origin, direction * C.AIM_RAY_LENGTH, params)
	if hit == nil then
		return nil
	end
	local part = hit.Instance
	-- Accessories (hats, hair...) are worn on the head.
	if part.Parent and part.Parent:IsA("Accessory") then
		return "Head"
	end
	return PART_ZONES[part.Name]
end

-- Heals one injury of this fighter, a little (the training dummies, left
-- alone): a bruise pales a level, then goes; a bit of glass, then a cut,
-- closes. Returns false when there is nothing left to heal.
function Combat.healOneInjury(model: Model): boolean
	local attributes = model:GetAttributes()
	-- (the oldest-looking first: bruises, then glass, then cuts)
	for name, value in attributes do
		if Bruise.isAttribute(name) then
			local data = Bruise.decode(value)
			if data and data.level > 1 then
				data.level -= 1
				setAttribute(model, name, Bruise.encode(data))
			else
				setAttribute(model, name, nil)
			end
			return true
		end
	end
	for name in attributes do
		if Gash.isInjuryAttribute(name) then
			setAttribute(model, name, nil)
			return true
		end
	end
	return false
end

-- Removes every cut and bruise of this fighter (the training dummies heal
-- completely when left alone).
function Combat.clearCuts(model: Model)
	for name in model:GetAttributes() do
		if Gash.isInjuryAttribute(name) or Bruise.isAttribute(name) then
			setAttribute(model, name, nil)
		end
	end
end

-- M1. Returns true if the attack started. `aim` = the direction the player
-- aims at (validated by onAttack); nil for dummies (random head / torso).
function Combat.tryAttack(model: Model, aim: Vector3?, attackId: number?): boolean
	local state = states[model]
	if state == nil then
		return false
	end
	-- Tells the attacker's client that this M1 is over: every CombatEvent
	-- for it was already sent. A hit it predicted that no event confirmed
	-- didn't happen (punch refused, cancelled or missed): it undoes it.
	local function resolved()
		local owner = state.player
		if owner and attackId then
			Remotes.AttackResolved:FireClient(owner, attackId)
		end
	end
	if not isAlive(state) or isStunned(state) or state.blocking or isBusy(state) then
		resolved()
		return false
	end
	local time = now()
	if time < state.nextAttackAt - C.ATTACK_GRACE then
		resolved()
		return false
	end
	-- (let in a hair early: it counts from when it was due, keeping the pace)
	time = math.max(time, state.nextAttackAt)
	-- Attacking ends the spawn protection.
	Knockout.endProtection(model)
	state.slipUntil = 0 -- punching ends a slip

	-- A KO'd fighter right in front: finish them instead of punching.
	-- (Players only: training dummies never finish anyone.)
	local finishTarget = if state.player then Knockout.findFinishTarget(model) else nil
	if finishTarget and startFinisher(state, finishTarget) then
		resolved() -- a finisher, not this M1
		return true
	end

	-- Dummies don't aim: they pick head or torso at random.
	local dummyZone: Types.HitZone = if random:NextNumber() < 0.5 then "Head" else "Torso"

	-- Advance the combo (or start over if the last M1 was too long ago).
	if time - state.lastAttackAt > C.COMBO_RESET then
		state.combo = 0
	end
	state.combo = state.combo % #C.M1_DAMAGE + 1
	local combo = state.combo
	local isFinisher = combo == #C.M1_DAMAGE

	state.lastAttackAt = time
	state.nextAttackAt = time + (if isFinisher then C.FINISHER_RECOVERY else C.M1_INTERVAL)
	state.attackingUntil = time + C.M1_INTERVAL
	state.attackToken += 1
	local token = state.attackToken
	-- Everyone plays the punch (animation + swing sound).
	Remotes.CombatAction:FireAllClients(model, `Brawler_M1_{combo}`)

	task.delay(C.HIT_DELAY, function()
		-- Cancelled (stunned during the wind-up), dead, or removed?
		if state.attackToken ~= token or not isAlive(state) then
			resolved()
			return
		end
		local boxCFrame = state.root.CFrame * CFrame.new(0, 0, -C.HITBOX_FORWARD)
		local victims, partsByModel = Hitbox.query(boxCFrame, C.HITBOX_SIZE, state.model)
		for _, victimModel in victims do
			local victim = states[victimModel]
			if victim and isAlive(victim) then
				-- Players: where their aim ray lands (no valid aim = torso).
				-- Dummies: random.
				local aimed: Types.HitZone = if aim
					then aimZone(state, victimModel, aim) or "Torso"
					elseif state.player then "Torso"
					else dummyZone
				local landed: Types.HitZone =
					landingZone(aimed, partsByModel[victimModel], C.PUNCH_ZONES)
				-- A weapon in hand (a bone...): heavier blows, more blood.
				local weapon = Weapons.get(state.weapon)
				local hit = resolveHit(state, victim, {
					damage = C.M1_DAMAGE[combo] * C.ZONE_DAMAGE[landed] * (if weapon
						then weapon.damageMultiplier
						else 1),
					bloodChance = if weapon then weapon.bloodChance else nil,
					zone = landed,
					stun = if isFinisher then C.FINISHER_STUN else C.HIT_STUN,
					headStun = true,
					legSlow = true,
					kind = if isFinisher then "Finisher" else "Hit",
					blockCost = if isFinisher
						then C.BLOCK_STAMINA_COST * 2
						else C.BLOCK_STAMINA_COST,
					knockback = if isFinisher then C.KNOCKBACK_SPEED else nil,
					attackId = attackId,
				})
				-- It wears out on what it hits.
				if hit and weapon and state.weapon == weapon.id then
					state.weaponHits += 1
					if state.weaponHits >= weapon.durability then
						dropWeapon(state, true)
					end
				end
			end
		end
		resolved()
	end)
	return true
end

function Combat.setBlocking(model: Model, wantsToBlock: boolean)
	local state = states[model]
	if state == nil then
		return
	end
	if not wantsToBlock then
		stopBlocking(state)
		return
	end
	if state.blocking or not isAlive(state) or isStunned(state) or isBusy(state) then
		return
	end
	local time = now()
	if time < state.attackingUntil then
		return -- can't block in the middle of an attack
	end
	state.blocking = true
	state.blockStartedAt = time
	-- Parry window only if the last block ended long enough ago (no F spam).
	state.parryReady = time - state.blockEndedAt >= C.PARRY_REARM
	setAttribute(model, "Blocking", true)
end

-- Dash: the client already moved; here we only check the rules, spend the
-- stamina and give the dodge frames.
local function tryDash(model: Model, player: Player): boolean
	local state = states[model]
	if
		state == nil
		or not isAlive(state)
		or isStunned(state)
		or state.blocking
		or isBusy(state)
	then
		return false
	end
	local time = now()
	if time < state.nextDashAt or not Stamina.trySpend(player, C.DASH_STAMINA_COST) then
		return false
	end
	state.nextDashAt = time + C.DASH_COOLDOWN
	state.invulnerableUntil = time + C.DASH_INVULNERABLE
	return true
end

function Combat.onEvent(callback: (CombatEventInfo) -> ()): Signal.Connection
	return events.connect(callback)
end

function Combat.onDamaged(callback: (DamageInfo) -> ()): Signal.Connection
	return damaged.connect(callback)
end

-- Puts `model` back to a clean state for a new duel round: full health and
-- stamina, no stun, bleeding, slowdown, limp, wound, cooldown, Awakening or
-- Fury, standing up.
function Combat.resetForRound(model: Model)
	local state = states[model]
	if state == nil then
		return
	end
	if Ragdoll.isRagdolled(model) then
		Ragdoll.disable(model, state.player)
	end
	state.humanoid.Health = state.humanoid.MaxHealth
	local player = state.player
	if player then
		Stamina.refill(player)
	end
	stopBlocking(state)
	if state.cinematicUntil > 0 then
		-- (a cutscene cut short: it lets go of nothing more)
		state.cinematicToken += 1
		state.cinematicUntil = 0
		state.root.Anchored = false
		setAttribute(model, "InCinematic", nil)
	end
	state.stunnedUntil = 0
	state.attackToken += 1
	state.knockdownToken += 1
	state.knockedDownUntil = 0
	state.knockbackUntil = 0
	state.legSlowUntil = 0
	state.slowUntil = 0
	state.slipUntil = 0
	state.bleedPerSecond = 0
	state.bleedUntil = 0
	setAttribute(model, "Bleeding", false)
	healInjuries(state)
	state.fury = 0
	setAttribute(model, "Fury", 0)
	state.awakenedUntil = 0
	setAttribute(model, "Awakened", false)
	for moveId in state.cooldowns do
		setAttribute(model, `CD_{moveId}`, nil)
	end
	table.clear(state.cooldowns)
	state.combo = 0
	state.nextAttackAt = 0
	state.attackingUntil = 0
	state.finishingUntil = 0
end

-- Is `model` free to do something that isn't fighting (an emote)? Not
-- while attacking, recovering, stunned, blocking, knocked down, sliding...
function Combat.isIdle(model: Model): boolean
	local state = states[model]
	if state == nil then
		return false
	end
	local time = now()
	return isAlive(state)
		and not isStunned(state)
		and not state.blocking
		and not isBusy(state)
		and time >= state.nextAttackAt
		and time >= state.attackingUntil
		and not Ragdoll.isRagdolled(model)
end

-- `model` can't move, attack, block or dash for `seconds` (a duel countdown).
function Combat.freeze(model: Model, seconds: number)
	local state = states[model]
	if state == nil then
		return
	end
	local untilTime = now() + seconds
	state.finishingUntil = math.max(state.finishingUntil, untilTime) -- speed 0, busy
	state.nextAttackAt = math.max(state.nextAttackAt, untilTime)
end

-- The kit `model` fights with (keys 1–4, G). Unknown or not yet available
-- kits fall back to the default one. Visible to clients as the "Kit"
-- attribute (the HUD shows that kit's moves).
function Combat.setKit(model: Model, kitId: string)
	local state = states[model]
	if state == nil then
		return
	end
	local kit = Kits.get(kitId)
	state.kitId = if kit and kit.available then kitId else Kits.DEFAULT
	setAttribute(model, "Kit", state.kitId)
end

------------------------------------------------------------------------------
-- Every frame: end stuns, apply slowdowns to players
------------------------------------------------------------------------------

local function update(dt: number)
	local time = now()
	for model, state in states do
		local stunned = time < state.stunnedUntil
		setAttribute(model, "Stunned", stunned)
		setAttribute(model, "Awakened", time < state.awakenedUntil)

		-- Out of combat for a while at low health: health slowly comes back
		-- (up to LOW_HEALTH only: a kill is the real way to heal).
		local humanoid = state.humanoid
		if
			humanoid.Health > 0
			and humanoid.Health < INJ.LOW_HEALTH
			and time - state.lastDamagedAt >= INJ.REGEN_DELAY
			and state.bleedPerSecond == 0
			and not Knockout.isKnockedOut(model)
		then
			state.regenCarry += INJ.REGEN_PER_SECOND * dt
			if state.regenCarry >= 1 then
				local amount = math.floor(state.regenCarry)
				state.regenCarry -= amount
				humanoid.Health = math.min(INJ.LOW_HEALTH, humanoid.Health + amount)
			end
		end

		-- Bleeding: small ticks of damage until the cut closes.
		if state.bleedPerSecond > 0 then
			if time >= state.bleedUntil or not isAlive(state) then
				state.bleedPerSecond = 0
				state.bleedSource = nil
				setAttribute(model, "Bleeding", false)
			elseif
				time >= state.nextBleedTick
				and time >= state.cinematicUntil -- (no bleeding out mid-cutscene)
				and not Knockout.isKnockedOut(model)
			then
				state.nextBleedTick = time + KC.BLEED_TICK
				local source = state.bleedSource
				local attacker = if source then states[source] else nil
				dealDamage(state, attacker, state.bleedPerSecond * KC.BLEED_TICK)
			end
		end

		-- Knocked out or dead: the weapon in hand is gone.
		if state.weapon and (not isAlive(state) or Knockout.isKnockedOut(model)) then
			dropWeapon(state, false)
		end

		local player = state.player
		if player then
			local attacking = time < state.attackingUntil
			Movement.setSpeedModifier(
				player,
				"Stun",
				if stunned then C.SPEED_WHILE_STUNNED else nil
			)
			Movement.setSpeedModifier(
				player,
				"Block",
				if state.blocking then C.SPEED_WHILE_BLOCKING else nil
			)
			Movement.setSpeedModifier(
				player,
				"Attack",
				if attacking then C.SPEED_WHILE_ATTACKING else nil
			)
			Movement.setSpeedModifier(
				player,
				"LegHit",
				if time < state.legSlowUntil then C.LEG_HIT_SLOW else nil
			)
			-- Limping (legs injured): slower, and no sprinting.
			Movement.setSpeedModifier(player, "Limp", if state.limping then INJ.LIMP_SPEED else nil)
			Movement.setSprintLock(player, "Limp", state.limping)
			-- Slowed by a kit move (dirty kick).
			Movement.setSpeedModifier(
				player,
				"MoveSlow",
				if time < state.slowUntil then state.slowMultiplier else nil
			)
			-- A heavy build (Bouncer) moves slower.
			local kit = Kits.get(state.kitId)
			Movement.setSpeedModifier(player, "Kit", if kit then kit.speed else nil)
			-- Kneeling for a finisher: stay in place.
			Movement.setSpeedModifier(
				player,
				"Finishing",
				if time < state.finishingUntil then 0 else nil
			)
			Movement.setSprintLock(player, "Combat", stunned or state.blocking or attacking)
		end
	end
end

------------------------------------------------------------------------------
-- Remote handlers (everything coming from clients is untrusted)
------------------------------------------------------------------------------

-- Generous limits: the real timing checks are in tryAttack / tryDash.
local attackLimiter = RateLimiter.new(6, 5)
local blockLimiter = RateLimiter.new(10, 6)
local dashLimiter = RateLimiter.new(3, 1)
local moveLimiter = RateLimiter.new(4, 2)
local awakenLimiter = RateLimiter.new(2, 0.5)

local function onAttack(player: Player, aim: unknown, attackId: unknown)
	local character = player.Character
	if character == nil or not attackLimiter.allow(player) then
		return
	end
	-- The aim direction: a real, finite, non-zero Vector3, pointing roughly
	-- where the character faces (Shared/Util/AimRule, the same rule the
	-- client uses to predict). Anything else = no aim (a torso hit).
	local state = states[character]
	local direction: Vector3? = if state
		then AimRule.validate(aim, state.root.CFrame.LookVector)
		else nil
	-- The M1's number (only echoed back to the clients, never trusted for
	-- anything else): a whole number, else ignored.
	local id: number? = if typeof(attackId) == "number"
			and attackId == attackId
			and attackId % 1 == 0
			and math.abs(attackId) < 2 ^ 31
		then attackId
		else nil
	Combat.tryAttack(character, direction, id)
end

local function onSetBlocking(player: Player, wantsToBlock: unknown)
	local character = player.Character
	if character == nil or typeof(wantsToBlock) ~= "boolean" then
		return
	end
	-- Releasing the block is always accepted (harmless).
	if wantsToBlock and not blockLimiter.allow(player) then
		return
	end
	Combat.setBlocking(character, wantsToBlock)
end

local function onDash(player: Player, animation: unknown)
	local character = player.Character
	if character == nil or not dashLimiter.allow(player) then
		return
	end
	-- Only the 4 known names (the value is shown to every client).
	if typeof(animation) ~= "string" or not DASH_ANIMATIONS[animation] then
		return
	end
	if tryDash(character, player) then
		Remotes.CombatAction:FireAllClients(character, animation)
	end
end

local function onUseMove(player: Player, slot: unknown, aim: unknown, requestId: unknown)
	local character = player.Character
	if character == nil or not moveLimiter.allow(player) then
		return
	end
	-- A slot is a whole number from 1 to 4. Anything else is ignored.
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > #KC.MOVE_KEYS then
		return
	end
	local state = states[character]
	if state == nil then
		return
	end
	local direction = AimRule.validate(aim, state.root.CFrame.LookVector)
	if not Moves.use(state, slot, direction) then
		-- Echo the client's number for this request (only sent back, never
		-- trusted): it undoes THAT move, not a newer one.
		local id = if typeof(requestId) == "number"
				and requestId == requestId
				and requestId % 1 == 0
				and math.abs(requestId) < 2 ^ 31
			then requestId
			else nil
		Remotes.MoveRefused:FireClient(player, slot, id)
	end
end

local function onAwaken(player: Player)
	local character = player.Character
	if character == nil or not awakenLimiter.allow(player) then
		return
	end
	local state = states[character]
	if state then
		Moves.awaken(state)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function onCharacterAdded(player: Player, character: Model)
	-- Wait until the body is complete.
	if
		character:WaitForChild("Humanoid", 10) and character:WaitForChild("HumanoidRootPart", 10)
	then
		if character.Parent ~= nil then
			Combat.register(character, player)
		end
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

-- Back on their feet after a KO: dazed for a moment, everyone sees the get-up.
local function onGetUp(model: Model)
	local state = states[model]
	if state == nil then
		return
	end
	state.combo = 0
	stopBlocking(state)
	stun(state, Config.Knockout.GETUP_STUN)
	Remotes.CombatAction:FireAllClients(model, "GetUp")
end

function Combat.start()
	-- Kit moves get the tools they need from here (see Combat/Moves.luau).
	Moves.bind({
		getState = function(model: Model): CombatState?
			return states[model]
		end,
		now = now,
		isAlive = isAlive,
		isStunned = isStunned,
		isBusy = isBusy,
		isAwakened = isAwakened,
		setAttribute = setAttribute,
		resolveHit = resolveHit,
		aimZone = aimZone,
		landingZone = landingZone,
		addFury = addFury,
	})
	Knockout.onGetUp(onGetUp)
	Knockout.onKill(function(killer)
		local state = states[killer]
		if state then
			healInjuries(state)
		end
	end)
	Remotes.Attack.OnServerEvent:Connect(onAttack)
	Remotes.SetBlocking.OnServerEvent:Connect(onSetBlocking)
	Remotes.Dash.OnServerEvent:Connect(onDash)
	Remotes.UseMove.OnServerEvent:Connect(onUseMove)
	Remotes.Awaken.OnServerEvent:Connect(onAwaken)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(update)
end

return Combat
