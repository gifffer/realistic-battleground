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
--      cancelled. The victims are tested where they are AND where the
--      attacker saw them (his ping ago, bounded: lag compensation, see
--      Combat/Rewind.luau).
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
local WoundShapes = require(ReplicatedStorage.Shared.WoundShapes)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Corpses = require(script.Parent.Corpses)
local Knockout = require(script.Parent.Knockout)
local Movement = require(script.Parent.Movement)
local PlayerData = require(script.Parent.PlayerData)
local Ragdoll = require(script.Parent.Ragdoll)
local Stamina = require(script.Parent.Stamina)
local Clones = require(script.Clones)
local Gadgets = require(script.Gadgets)
local Hitbox = require(script.Hitbox)
local Moves = require(script.Moves)
local Rewind = require(script.Rewind)
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
local function dealDamage(
	victim: CombatState,
	attacker: CombatState?,
	amount: number,
	source: Model?
)
	local attackerModel = if attacker then attacker.model else (source or victim.bleedSource)
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

-- Starts (or strengthens) a burn (acid / fire): like bleeding, its own slot.
local function startBurning(
	victim: CombatState,
	attacker: CombatState,
	kind: string,
	perSecond: number,
	duration: number
)
	local time = now()
	local burning = time < victim.burnUntil
	victim.burnPerSecond = math.max(perSecond, if burning then victim.burnPerSecond else 0)
	victim.burnUntil = math.max(victim.burnUntil, time + duration)
	if not burning then
		-- (an ongoing burn keeps its ticks: refreshing it, standing in a
		-- puddle, must not push them back forever)
		victim.nextBurnTick = time + KC.BLEED_TICK
	end
	victim.burnSource = attacker.model
	victim.burnKind = kind
	-- (clients: smoke, bubbling skin, the burn marks; Client/Combat/RiftFx)
	setAttribute(victim.model, "Burning", kind)
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
		if part == "Left Leg" then
			victim.leftLegDamage += damage
		end
		if victim.legDamage >= INJ.LIMP_LEG_DAMAGE then
			-- The limp favours the leg that took the most ("LimpLeg": which
			-- one hurts, for the walk every client draws). Checked on every leg
			-- hit, so it moves to the other leg if that one overtakes.
			local left = victim.leftLegDamage * 2 > victim.legDamage
			setAttribute(victim.model, "LimpLeg", if left then "Left" else "Right")
			if not victim.limping then
				victim.limping = true
				setAttribute(victim.model, "Limping", true)
			end
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

-- Heat vision burning through the skin of `partName` where it touches
-- (`world`): a "Burn" (Gashes draws the hole: charred edge, the skull or
-- cooked muscle under it). The beam staying on the same spot makes that
-- burn grow (S, M, L); a part full of wounds: the nearest burn grows.
local BURN_MERGE = 0.35 -- studs
local function addBurn(victim: Model, partName: string, world: Vector3): (string?, any)
	if not INJ.SKIN_TEAR then
		return nil, nil
	end
	local part = victim:FindFirstChild(partName)
	local key = Gash.KEY_OF[partName]
	if part == nil or not part:IsA("BasePart") or key == nil then
		return nil, nil
	end
	-- On the skin: the round head's surface, or the side face it's on.
	local p = part.CFrame:PointToObjectSpace(world)
	local point: Vector3
	if partName == "Head" then
		-- (the head part is a 2-wide box, the head you see 1.2 across: a
		-- point beside it never touched the skin)
		if math.abs(p.X) > 0.62 then
			return nil, nil
		end
		local flat = Vector3.new(p.X, 0, p.Z)
		flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
		point = flat * 0.6 + Vector3.new(0, math.clamp(p.Y, -0.25, 0.25), 0)
	else
		local half = part.Size / 2
		if math.abs(p.X) / half.X > math.abs(p.Z) / half.Z then
			point = Vector3.new(math.sign(p.X) * half.X, math.clamp(p.Y, -half.Y, half.Y), p.Z)
		else
			point = Vector3.new(p.X, math.clamp(p.Y, -half.Y, half.Y), math.sign(p.Z) * half.Z)
		end
	end
	-- the nearest burn there grows; else a free slot; else (full) the
	-- nearest wound of any kind turns into a burn
	local free: number? = nil
	local burnAt: number? = nil
	local burnDistance = math.huge
	local anyAt: number? = nil
	local anyDistance = math.huge
	for index = 1, Gash.MAX_PER_PART do
		local old = Gash.decode(victim:GetAttribute(Gash.attribute(key, index)))
		if old == nil then
			free = free or index
		else
			local distance = (old.point - point).Magnitude
			if old.kind == "Burn" and distance < burnDistance then
				burnAt, burnDistance = index, distance
			end
			if distance < anyDistance then
				anyAt, anyDistance = index, distance
			end
		end
	end
	local attribute: string
	local data: Gash.Data
	local target = if burnAt and burnDistance < BURN_MERGE
		then burnAt
		elseif free then nil
		else anyAt
	if target then
		attribute = Gash.attribute(key, target)
		local old = Gash.decode(victim:GetAttribute(attribute))
		if old == nil or (old.kind == "Burn" and old.size == "L") then
			return nil, nil -- (as deep as it gets)
		end
		data = old
		data.size = if old.kind == "Burn" then Gash.bigger(old.size) else old.size
		data.kind = "Burn"
	elseif free then
		attribute = Gash.attribute(key, free)
		data = {
			kind = "Burn",
			size = "S",
			point = point,
			angle = random:NextNumber(-90, 90),
			seed = random:NextInteger(1, 2 ^ 30),
		}
	else
		return nil, nil
	end
	local previous = victim:GetAttribute(attribute)
	setAttribute(victim, attribute, Gash.encode(data))
	return attribute, previous
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
	state.leftLegDamage = 0
	state.limping = false
	setAttribute(state.model, "Limping", false)
	setAttribute(state.model, "LimpLeg", nil)
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

-- Is `point` in front of `victim`? (You can't block a hit in the back.)
local function isInFrontOf(victim: CombatState, point: Vector3): boolean
	local offset = point - victim.root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 1e-3 then
		return true
	end
	local look = victim.root.CFrame.LookVector
	return flat.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) > 0
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
	-- (a thrown thing hits from where it is, not from its thrower)
	local from = spec.from or attacker.root.Position
	local side: Types.HitSide = HitSide.compute(victim.root.CFrame, from)
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
	-- A clone hits for a share of its owner.
	damage *= Clones.damageScale(attacker)
	-- A heavy build (Bouncer) takes less from every hit.
	local victimKit = Kits.get(victim.kitId)
	if victimKit and victimKit.damageTaken then
		damage *= victimKit.damageTaken
	end

	-- 0a. Dr. Rift's clones (Combat/Clones): never against their own side.
	-- Their hits are dealt in their owner's name (the KO, the Fury).
	local side0 = attacker.owner or attacker
	if (victim.owner or victim) == side0 then
		return false
	end
	local credit = if attacker.owner and isAlive(attacker.owner) then attacker.owner else attacker

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

	-- 0c. One of Dr. Rift's clones: the first blow that reaches it sends it
	-- back through a portal (no damage, no dodge, no guard).
	if victim.owner then
		event(spec.kind, true, true)
		Clones.dispel(victim)
		return true
	end

	-- 1. Dash dodge frames: the hit misses. (Caught where he was a moment
	-- ago: dodge frames at any time since then count, see HitSpec.rewound.)
	if time - (spec.rewound or 0) < victim.invulnerableUntil then
		event("Dodged", false, false)
		return false
	end

	-- 1b. Slip (Boxer): a hit from the front is slipped, and answered. The
	-- attacker's move is cut (its next hits don't land), and the slipper
	-- can't be hit by anyone until the counter lands.
	if
		not spec.from -- (a thrown thing can't be slipped and countered)
		and time < victim.slipUntil
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
	elseif victim.blocking and isInFrontOf(victim, from) then
		-- 2. Parry: block started just before the hit → attacker is stunned.
		if
			not spec.from
			and victim.parryReady
			and time - victim.blockStartedAt <= C.PARRY_WINDOW
		then
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
			dealDamage(victim, credit, damage * (1 - C.BLOCK_REDUCTION))
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
	dealDamage(victim, credit, damage)

	-- Blood: rolled here, so every client shows the same thing. Fists rarely
	-- draw blood; the bottle's moves set their own (high) chance. The 4th M1
	-- on the head may open a cut (then it bleeds, see below).
	local critCut = false
	local bloodChance: number = 0
	local chances = spec.bloodChance
	if chances ~= nil then
		bloodChance = math.min(1, (chances[zone] or 0) * INJ.BLOOD_CHANCE_SCALE)
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
		startBleeding(victim, credit, bleed.perSecond, bleed.duration)
		-- Where it bleeds from (the drops fall from there, see KitEffects).
		setAttribute(
			victim.model,
			"BleedPart",
			if zone == "Head" then "Head" elseif zone == "Legs" then "Right Leg" else "Torso"
		)
	end
	local burn = spec.burn
	if burn then
		startBurning(victim, credit, burn.kind, burn.perSecond, burn.duration)
	end
	-- (Glass leaves its cut instead of a bruise mark: no disc over the cut.)
	injure(
		victim,
		attacker,
		zone :: Types.HitZone,
		damage,
		side,
		spec.cuts == nil and not spec.burns
	)

	-- Awakened fighters have "hyper armor": hits hurt but don't stop them.
	if isAwakened(victim) then
		event(spec.kind, true, true)
		return true
	end

	local away = awayFromAttacker(attacker, victim)
	local blast = spec.pushFrom
	if blast then
		local offset = victim.root.Position - blast
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > 1e-3 then
			away = flat.Unit
		end
	end
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
		channelUntil = 0,
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
		leftLegDamage = 0,
		limping = false,
		lastDamagedAt = -math.huge,
		regenCarry = 0,
		slipUntil = 0,
		slipMoveId = nil,
		heldUntil = 0,
		holding = nil,
		heldBy = nil,
		weapon = nil,
		burnPerSecond = 0,
		burnUntil = 0,
		nextBurnTick = 0,
		burnSource = nil,
		burnKind = nil,
		owner = nil,
	}
	model:SetAttribute("Blocking", false)
	model:SetAttribute("Stunned", false)
	model:SetAttribute("Fury", 0)
	model:SetAttribute("Awakened", false)
	model:SetAttribute("Bleeding", false)
	model:SetAttribute("Limping", false)
	model:SetAttribute("LimpLeg", nil)
	-- A player fights with the kit saved in their profile.
	-- (Only a kit they still own: Kits.owns.)
	local data = if player then PlayerData.getData(player) else nil
	local saved = if data then Kits.get(data.equippedKit) else nil
	local usable = data ~= nil and saved ~= nil and Kits.owns(data, saved)
	Combat.setKit(model, if usable and data then data.equippedKit else Kits.DEFAULT)
	CollectionService:AddTag(model, C.TAG)
	Knockout.register(model, player)
	-- Where it stands, frame by frame (lag compensation, Combat/Rewind).
	Rewind.track(model, root)

	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			states[model] = nil
			Rewind.untrack(model)
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

-- The Bull's finisher: his horns go into the ribcage. One big "Tear" (two
-- side by side don't fit on the torso's front: they'd overlap); a free
-- slot, else over the first cut (like the liver). The cut's old value (or
-- false) is written in `before` once, to be put back if the finisher is cut
-- short before the kill.
local function goreWounds(victim: Model, before: { [string]: any })
	local index = 1
	for candidate = 1, Gash.MAX_PER_PART do
		if victim:GetAttribute(Gash.attribute("Torso", candidate)) == nil then
			index = candidate
			break
		end
	end
	local name = Gash.attribute("Torso", index)
	if before[name] == nil then
		local old = victim:GetAttribute(name)
		before[name] = if old == nil then false else old
	end
	setAttribute(
		victim,
		name,
		Gash.encode({
			kind = "Tear",
			size = "L",
			point = Vector3.new(0, 0.3, -0.5), -- the ribcage, in front
			angle = random:NextNumber(-20, 20), -- (degrees)
			seed = random:NextInteger(1, 2 ^ 30),
		})
	)
end

-- The Sentinel's finisher: the beam burning into the heart. One "Bore" on
-- the torso at Gash.HEART (the wound kit's bore inserts are made for that
-- spot, angle 0), deeper each time (S, M, L). Nothing bleeds: no blood, no
-- injury, cauterized. The cuts already over that spot go (the bore takes
-- their place); a full torso gives up the cut nearest the heart. Every
-- attribute changed is written in `before` (its old value, or false) once,
-- to be put back if the finisher is cut short. Returns the bore's attribute.
local function boreFootprint(data: Gash.Data): Vector2
	local shape = WoundShapes.shapes[data.kind .. data.size]
	local extent = if shape then shape.extent else Vector2.new(0.3, 0.3)
	local c, s = math.abs(math.cos(math.rad(data.angle))), math.abs(math.sin(math.rad(data.angle)))
	return Vector2.new(c * extent.X + s * extent.Y, s * extent.X + c * extent.Y)
end

local function boreHeart(
	victim: Model,
	size: Gash.Size,
	attribute: string?,
	before: { [string]: any }
): string?
	local torso = victim:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return nil
	end
	local function remember(name: string)
		if before[name] == nil then
			local old = victim:GetAttribute(name)
			before[name] = if old == nil then false else old
		end
	end
	if attribute == nil then
		local half = torso.Size / 2
		local bore = boreFootprint({
			kind = "Bore",
			size = "L",
			point = Gash.HEART,
			angle = 0,
			seed = 0,
		})
		local free: number? = nil
		local nearest: number? = nil
		local nearestDistance = math.huge
		for index = 1, Gash.MAX_PER_PART do
			local name = Gash.attribute("Torso", index)
			local old = Gash.decode(victim:GetAttribute(name))
			if old == nil then
				free = free or index
				continue
			end
			local p = old.point
			local delta = p - Gash.HEART
			-- On the front face too (the side faces' cuts never reach it),
			-- and their outlines would cross: it goes.
			local front = -p.Z / half.Z >= math.abs(p.X) / half.X
			local footprint = boreFootprint(old)
			if
				front
				and math.abs(delta.X) < bore.X + footprint.X
				and math.abs(delta.Y) < bore.Y + footprint.Y
			then
				remember(name)
				setAttribute(victim, name, nil)
				free = free or index
			elseif delta.Magnitude < nearestDistance then
				nearest, nearestDistance = index, delta.Magnitude
			end
		end
		local index = free or nearest
		if index == nil then
			return nil
		end
		attribute = Gash.attribute("Torso", index)
	end
	local name = attribute :: string
	local old = Gash.decode(victim:GetAttribute(name))
	remember(name)
	setAttribute(
		victim,
		name,
		Gash.encode({
			kind = "Bore",
			size = size,
			point = Gash.HEART,
			angle = 0,
			seed = if old and old.kind == "Bore" then old.seed else random:NextInteger(1, 2 ^ 30),
		})
	)
	return name
end

-- When the bore goes deeper, after the beam starts (seconds).
local BORE_STEPS: { { after: number, size: Gash.Size } } = {
	{ after = 0.3, size = "S" },
	{ after = 0.7, size = "M" },
	{ after = 1.1, size = "L" },
}

-- Where the victim's body is in the last frame of its clip (anchor space of
-- the victim's root): the ragdoll starts from there, not from standing.
local KILL_POSE: { [string]: CFrame } = {
	Incinerate = CFrame.new(-0.5, -2.46, 1.8) * CFrame.Angles(math.rad(88), 0, 0), -- thrown down on its back
	Gore = Finishers.CHARGE.rip, -- thrown back high over his head
}

-- Thrown things (Shared/Weapons): one in the right hand ("Weapon"
-- attribute: the clients show it). A left click throws it (throwWeapon); it
-- breaks in two on what it hits first (Remotes.WeaponBroke: every client
-- shows the two halves there). Knocked out or dead: dropped, it breaks at
-- their feet.
local throwSeq = 0

local function giveWeapon(state: CombatState, id: string)
	state.weapon = id
	setAttribute(state.model, "Weapon", id)
end

local function dropWeapon(state: CombatState, breakIt: boolean)
	local id = state.weapon
	if id == nil then
		return
	end
	state.weapon = nil
	-- (the break first: the clients still have it in the hand to take it from)
	if breakIt then
		local hand = state.model:FindFirstChild("Right Arm")
		local at = if hand and hand:IsA("BasePart") then hand.Position else state.root.Position
		Remotes.WeaponBroke:FireAllClients(id, nil, at, Vector3.new(0, -4, 0))
	end
	setAttribute(state.model, "Weapon", nil)
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

-- A body's frozen copy (Corpses, at the respawn) still shows its torn arm
-- on the floor with the bone in it: the bone can still be taken, from the
-- copy (its own "BoneTaken"). Only an arm that was lying there, offered
-- (its "BonePrompt" kept by the copy, the prompt itself removed).
local function offerCopiedBone(copy: Model)
	if
		copy.Parent == nil
		or copy:GetAttribute("ArmTorn") == nil
		or copy:GetAttribute("BoneTaken") == true
	then
		return
	end
	local arm = copy:FindFirstChild("Right Arm")
	if not (arm and arm:IsA("BasePart")) then
		return
	end
	local old = arm:FindFirstChild("BonePrompt")
	if not (old and old:IsA("Attachment")) then
		return
	end
	old:Destroy()
	offerBone(copy, arm)
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

-- The Bull's finisher: the body torn in two at the waist, in the air (just
-- after the kill, the ragdoll on). The legs come off the torso: their
-- joints and the loose ones of the ragdoll go (the ragdoll's NoCollide
-- ones stay: the two halves never knock into each other as they part);
-- they are welded to each other, straight side by side (one piece: "the
-- legs"; the clients draw the hips on them so). The top half is thrown on
-- and up, turning over; the legs drop back. Every client draws the rest
-- from "Bisected" (= a seed): Client/Combat/Bisect (the torn ends, the
-- guts trailing from one half to the other, the blood).
local function bisect(victim: Model, anchor: CFrame)
	local torso = victim:FindFirstChild("Torso")
	local root = victim:FindFirstChild("HumanoidRootPart")
	local right = victim:FindFirstChild("Right Leg")
	local left = victim:FindFirstChild("Left Leg")
	if
		not (
			torso
			and torso:IsA("BasePart")
			and root
			and root:IsA("BasePart")
			and right
			and right:IsA("BasePart")
			and left
			and left:IsA("BasePart")
		)
	then
		return
	end
	local function isHipJoint(name: string): boolean
		for _, side in { "Right Hip", "Left Hip" } do
			if
				name == side
				or name == "Ragdoll_" .. side
				or name == "Ragdoll_" .. side .. "0"
				or name == "Ragdoll_" .. side .. "1"
			then
				return true
			end
		end
		return false
	end
	for _, part in { torso, right, left } do
		for _, item in part:GetChildren() do
			if isHipJoint(item.Name) then
				item:Destroy()
			end
		end
	end
	left.CFrame = right.CFrame * CFrame.new(-1, 0, 0)
	local legs = Instance.new("WeldConstraint")
	legs.Name = "BisectLegs"
	legs.Part0 = right
	legs.Part1 = left
	legs.Parent = right
	-- (two bodies now: the server moves both, same for everyone)
	for _, part in { root, right } do
		if part:CanSetNetworkOwnership() then
			part:SetNetworkOwner(nil)
		end
	end
	local sway = random:NextNumber(-1.5, 1.5)
	root.AssemblyLinearVelocity = anchor:VectorToWorldSpace(Vector3.new(sway, 15, -14))
	root.AssemblyAngularVelocity =
		anchor:VectorToWorldSpace(Vector3.new(-6, sway * 0.8, random:NextNumber(-1.5, 1.5)))
	-- The head and the arms hang on the torso by the ragdoll's loose joints
	-- only (each its own body): thrown with it, the same way, or the torso
	-- alone went (they stayed behind, at rest, owned by whoever), and they
	-- never knock into the legs (the halves part freely).
	local linear, angular = root.AssemblyLinearVelocity, root.AssemblyAngularVelocity
	local center = root.AssemblyCenterOfMass
	for _, name in { "Head", "Right Arm", "Left Arm" } do
		local limb = victim:FindFirstChild(name)
		local base = if limb and limb:IsA("BasePart") then limb.AssemblyRootPart else nil
		if limb == nil or not limb:IsA("BasePart") or base == nil or base == root then
			continue -- (gone, or still rigid on the torso)
		elseif not base:IsDescendantOf(victim) then
			continue -- (held by someone: not ours to throw)
		end
		if limb:CanSetNetworkOwnership() then
			limb:SetNetworkOwner(nil)
		end
		limb.AssemblyLinearVelocity = linear + angular:Cross(limb.Position - center)
		limb.AssemblyAngularVelocity = angular
		for _, leg in { right, left } do
			local apart = Instance.new("NoCollisionConstraint")
			apart.Name = "BisectApart"
			apart.Part0 = limb
			apart.Part1 = leg
			apart.Parent = limb
		end
	end
	right.AssemblyLinearVelocity = anchor:VectorToWorldSpace(Vector3.new(-sway * 0.4, -6, 7))
	right.AssemblyAngularVelocity = anchor:VectorToWorldSpace(Vector3.new(4, 0, sway))
	setAttribute(victim, "Bisected", random:NextInteger(1, 2 ^ 30))
end

-- "charge" (the Bull's "Gore", Finishers.CHARGE): where he starts from (the
-- anchor) and how much shorter his run is. The victim will stand
-- CHARGE.victim studs in front, then the leap, the top half flying on, so
-- a clear lane with a floor all along: the way he faces the victim first,
-- else turned, then the same with a shorter run. Nowhere: nil (no charge,
-- never through a wall or off a ledge).
local CHARGE_TURNS = { 0, 45, -45, 90, -90, 135, -135, 180 } -- degrees
local LANE_END = -24 -- anchor Z where the top half may land, at most

local function chargePlacement(attacker: Model, victim: Model, root: BasePart): (CFrame?, number)
	local RUN = Finishers.CHARGE
	local victimRoot = victim:FindFirstChild("HumanoidRootPart")
	local at = if victimRoot and victimRoot:IsA("BasePart")
		then victimRoot.Position
		else root.Position + root.CFrame.LookVector
	local toward = Vector3.new(at.X - root.Position.X, 0, at.Z - root.Position.Z)
	toward = if toward.Magnitude > 0.1
		then toward.Unit
		else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker, victim }
	params.RespectCanCollide = true
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { attacker, victim }
	overlap.RespectCanCollide = true
	-- (someone standing in the way doesn't count: only the map)
	local function onBody(part: BasePart): boolean
		local model = part:FindFirstAncestorOfClass("Model")
		return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
	end
	local function clear(anchor: CFrame, short: number): boolean
		local feet = anchor.Position.Y - 3
		for _, z in { -short, -5.5, -RUN.victim, -13.5, RUN.ends.Z, -19, LANE_END + 1.5 } do
			local from = (anchor * CFrame.new(0, 1, z)).Position
			local hit = workspace:Raycast(from, Vector3.new(0, -8, 0), params)
			if hit == nil or math.abs(hit.Position.Y - feet) > 1.25 then
				return false
			end
		end
		local near = -short + 1.2
		local length = near - LANE_END
		for _, part in
			workspace:GetPartBoundsInBox(
				anchor * CFrame.new(0, 2.4, near - length / 2),
				Vector3.new(3.4, 9.6, length),
				overlap
			)
		do
			if not onBody(part) then
				return false
			end
		end
		return true
	end
	-- (standing height over the floor under him: in the air, a jump, the
	-- lane is still checked from the ground)
	local start = root.Position
	local floor = workspace:Raycast(start, Vector3.new(0, -12, 0), params)
	if floor then
		start = Vector3.new(start.X, floor.Position.Y + 3, start.Z)
	end
	for _, short in { 0, RUN.short } do
		for _, turn in CHARGE_TURNS do
			local direction = CFrame.Angles(0, math.rad(turn), 0):VectorToWorldSpace(toward)
			-- (the anchor: where a full run would start, behind him if shorter)
			local anchor = CFrame.lookAt(start, start + direction) * CFrame.new(0, 0, short)
			if clear(anchor, short) then
				return anchor, short
			end
		end
	end
	return nil, 0
end

-- A cinematic finisher (Shared/Finishers): both fighters are placed and held
-- still (anchored) for the cutscene, the attacker can't be touched, the
-- victim dies at the killing blow. Every client plays the camera / effects
-- from Remotes.FinisherStarted.
-- PortalCut (Dr. Rift): the portal closed round their waist. The body is
-- cut in two at the bottom of the torso: the upper body (torso, head,
-- arms) falls back off the legs; the legs stay standing (welded to the
-- anchored root) for `foldIn` seconds, then fold. Every part stays in the
-- body's model (its clothes keep showing). "CutInHalf" = the seed of the
-- gore every client draws (Client/Combat/WaistCut).
local function cutInHalf(victim: Model, anchor: CFrame, foldIn: number)
	local root = victim:FindFirstChild("HumanoidRootPart")
	local torso = victim:FindFirstChild("Torso")
	if not (root and root:IsA("BasePart") and torso and torso:IsA("BasePart")) then
		return
	end
	-- The legs, held where they stand: welded to the (anchored) root.
	local legs: { BasePart } = {}
	for _, name in { "Right Leg", "Left Leg" } do
		local leg = victim:FindFirstChild(name)
		if leg and leg:IsA("BasePart") then
			table.insert(legs, leg)
			local weld = Instance.new("Weld")
			weld.Name = "CutLegHold"
			weld.Part0 = root
			weld.Part1 = leg
			weld.C0 = root.CFrame:ToObjectSpace(leg.CFrame)
			weld.Parent = root
		end
	end
	Ragdoll.enable(victim) -- (arms and head on their sockets: limp)
	-- Off the torso: the hip joints and their ragdoll sockets...
	for _, name in { "Right Hip", "Left Hip" } do
		for _, childName in { name, "Ragdoll_" .. name, "Ragdoll_" .. name .. "0" } do
			local child = torso:FindFirstChild(childName)
			if child then
				child:Destroy()
			end
		end
	end
	for _, leg in legs do
		for _, child in leg:GetChildren() do
			if string.match(child.Name, "^Ragdoll_.- Hip1$") then
				child:Destroy()
			end
		end
		leg.CanCollide = true
		leg.Massless = false
	end
	-- ...and off the root: the upper body is free.
	local rootJoint = root:FindFirstChild("RootJoint")
	if rootJoint then
		rootJoint:Destroy()
	end
	root.Anchored = true
	victim:SetAttribute("CutInHalf", random:NextInteger(1, 2 ^ 30))
	if torso:CanSetNetworkOwnership() then
		torso:SetNetworkOwner(nil)
	end
	-- It falls back, away from him, turning over.
	local away = (anchor.LookVector * Vector3.new(1, 0, 1)).Unit
	torso.AssemblyLinearVelocity = away * 9 + Vector3.new(0, 7, 0)
	torso.AssemblyAngularVelocity = anchor.RightVector * -5
	-- Then the legs give way.
	task.delay(foldIn, function()
		if root.Parent == nil then
			return
		end
		root.Anchored = false
		if root:CanSetNetworkOwnership() then
			root:SetNetworkOwner(nil)
		end
		root.AssemblyLinearVelocity = away * 2
		root.AssemblyAngularVelocity = anchor.RightVector * -2.5
	end)
end

local function startCinematic(
	state: CombatState,
	target: Model,
	finisher: Kits.FinisherDef,
	cinematic: Finishers.Cinematic,
	charge: CFrame?, -- ("charge": chargePlacement's anchor and short run)
	short: number
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
	local chargeShort = 0 -- ("charge": studs less of a run)
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
	elseif cinematic.placement == "charge" then
		-- The victim stood up groggy far in front of him, facing him.
		-- (startFinisher found the lane; none, no charge at all)
		if charge == nil then
			Knockout.release(target)
			return
		end
		anchor, chargeShort = charge, short
		victimPlace = anchor
			* CFrame.new(0, 0, -Finishers.CHARGE.victim)
			* CFrame.Angles(0, math.pi, 0)
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
			* CFrame.new(0, 0, -(cinematic.distance or Finishers.HOLD_DISTANCE))
			* CFrame.Angles(0, math.pi, 0)
	end
	-- ("charge": his root waits where he will end; every client shows his
	-- body along the run meanwhile, Finishers.CHARGE)
	local charging = cinematic.placement == "charge"
	root.Anchored = true
	root.CFrame = if charging then anchor * CFrame.new(Finishers.CHARGE.ends) else anchor
	-- Where his body is now (his root goes there if the cutscene is cut short).
	local function attackerPlace(): CFrame
		if not charging then
			return anchor
		end
		local at = Finishers.chargeRoot(now() - time, chargeShort)
		-- (crouched: his root at standing height, not into the floor)
		return anchor * CFrame.new(at.X, math.max(at.Y, 0), at.Z)
	end
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
	Remotes.FinisherStarted:FireAllClients(state.model, target, cinematic.id, anchor, chargeShort)

	local connections: { RBXScriptConnection } = {}
	local over = false
	local killed = false
	-- (the Bull's horns, the Sentinel's bore: every cut they changed, with
	-- its old value, put back if cut short)
	local woundsBefore: { [string]: any } = {}
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
			if target.Parent then
				for attribute, previous in woundsBefore do
					setAttribute(target, attribute, if previous == false then nil else previous)
				end
			end
			if victimPlace and victimRoot.Parent then
				victimRoot.Anchored = false
				Ragdoll.enable(target)
			end
			Knockout.release(target)
		end
		-- (only if no newer cinematic took this fighter over)
		if state.cinematicToken == cinematicToken then
			if root.Parent then
				-- ("charge" cut short: where his body is, not where he'd end)
				if charging and now() < state.cinematicUntil then
					root.CFrame = attackerPlace()
				end
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

	if cinematic.id == "Incinerate" then
		-- the beam point blank into the heart (Shared/Finishers "Incinerate":
		-- from "Beam"): the hole goes deeper as it burns, S -> M -> L
		local beamAt = 0
		for _, event in cinematic.events do
			if event.kind == "Beam" then
				beamAt = event.time
			end
		end
		local boreAttribute: string? = nil
		for _, step in BORE_STEPS do
			task.delay(beamAt + step.after, function()
				if not over and target.Parent and state.attackToken == token and isAlive(state) then
					boreAttribute = boreHeart(target, step.size, boreAttribute, woundsBefore)
				end
			end)
		end
	end
	if cinematic.id == "Gore" then
		-- the horns going into the ribcage (Shared/Finishers "Gore": "Impact")
		local impact = Finishers.CHARGE.impact
		for _, event in cinematic.events do
			if event.kind == "Impact" then
				impact = event.time
			end
		end
		task.delay(impact, function()
			if not over and target.Parent and state.attackToken == token and isAlive(state) then
				goreWounds(target, woundsBefore)
			end
		end)
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
		local cut = cinematic.id == "PortalCut" and victimPlace ~= nil
		if victimPlace and not cut then
			-- Limp: it folds and drops where it stands (where its clip left
			-- it: held up, slammed down...).
			local pose = KILL_POSE[cinematic.id]
			if pose then
				victimRoot.CFrame = victimPlace * pose
			end
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
			elseif cinematic.id == "Incinerate" then
				-- (every client lets the hole smoke and cool down, from when
				-- the beam stopped: KitVFX, bodies seen later too)
				local burntAt = cinematic.kill
				for _, event in cinematic.events do
					if event.kind == "Burnt" then
						burntAt = event.time
					end
				end
				setAttribute(
					target,
					Finishers.BORED_ATTRIBUTE,
					workspace:GetServerTimeNow() - (cinematic.kill - burntAt)
				)
			elseif cinematic.id == "ArmRip" then
				local throwIn: number? = nil
				for _, event in cinematic.events do
					if event.kind == "Throw" then
						throwIn = event.time - cinematic.kill
					end
				end
				tearArmOff(target, state.model, anchor, throwIn)
			elseif cut then
				local foldIn: number? = nil
				for _, event in cinematic.events do
					if event.kind == "Fold" then
						foldIn = event.time - cinematic.kill
					end
				end
				cutInHalf(target, anchor, foldIn or 0.8)
			elseif cinematic.id == "Gore" then
				-- (dead first: never a living body torn in two)
				bisect(target, anchor)
			end
		elseif cut and victimRoot.Parent then
			-- (not dead after all: no cut, it just drops)
			victimRoot.Anchored = false
			Ragdoll.enable(target)
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
	local cinematic = Finishers.get(finisher.cinematic)
	-- "charge" (the Bull's run): no clear lane with a floor here (walls, a
	-- ledge), the plain finisher instead; nobody is moved.
	local charge: CFrame? = nil
	local short = 0
	if cinematic and cinematic.placement == "charge" then
		charge, short = chargePlacement(state.model, target, state.root)
		if charge == nil then
			finisher = Kits.finisher(nil)
			cinematic = nil
		end
	end
	state.nextAttackAt = time + finisher.duration
	state.finishingUntil = time + finisher.duration
	state.attackingUntil = time + finisher.duration
	state.combo = 0
	state.attackToken += 1
	local token = state.attackToken

	if cinematic then
		startCinematic(state, target, finisher, cinematic, charge, short)
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
-- `rootAt`: the victim was found in the hitbox there (rewound to where
-- the attacker saw it, Combat/Rewind): the ray is cast at that body.
local function aimZone(
	attacker: CombatState,
	victim: Model,
	direction: Vector3,
	rootAt: CFrame?
): Types.HitZone?
	local head = attacker.model:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else attacker.root.Position
	local ray = direction * C.AIM_RAY_LENGTH
	local part: BasePart? = nil
	if rootAt then
		part = Hitbox.rayAt(victim, origin, ray, rootAt)
	else
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { victim }
		local hit = workspace:Raycast(origin, ray, params)
		part = if hit then hit.Instance :: BasePart else nil
	end
	if part == nil then
		return nil
	end
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

	-- When the fist lands (the attacker's screen showed it HIT_DELAY after
	-- his click, which reached us one trip later).
	local dueAt = now() + C.HIT_DELAY
	task.delay(C.HIT_DELAY, function()
		-- Cancelled (stunned during the wind-up), dead, or removed?
		if state.attackToken ~= token or not isAlive(state) then
			resolved()
			return
		end
		-- The victims are also tested where the attacker saw them (lag
		-- compensation, Combat/Rewind). The attacker's own body is where
		-- his client had it then already: we receive it one trip late too.
		local rewind = Rewind.amount(state.player, now() - dueAt)
		local boxCFrame = state.root.CFrame * CFrame.new(0, 0, -C.HITBOX_FORWARD)
		local victims, partsByModel, rootByModel, ageByModel =
			Hitbox.query(boxCFrame, C.HITBOX_SIZE, state.model, rewind)
		for _, victimModel in victims do
			local victim = states[victimModel]
			if victim and isAlive(victim) then
				-- Players: where their aim ray lands (no valid aim = torso).
				-- Dummies: random.
				local aimed: Types.HitZone = if aim
					then aimZone(state, victimModel, aim, rootByModel[victimModel]) or "Torso"
					elseif state.player then "Torso"
					else dummyZone
				local landed: Types.HitZone =
					landingZone(aimed, partsByModel[victimModel], C.PUNCH_ZONES)
				resolveHit(state, victim, {
					damage = C.M1_DAMAGE[combo] * C.ZONE_DAMAGE[landed],
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
					rewound = ageByModel[victimModel],
				})
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
		or now() < state.channelUntil -- (rooted by the beam)
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
	dropWeapon(state, false) -- (no weapons in a duel)
	Clones.dismissAll(model) -- (Dr. Rift's clones go with the Awakening)
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
	state.channelUntil = 0
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
	state.burnPerSecond = 0
	state.burnUntil = 0
	state.burnKind = nil
	setAttribute(model, "Burning", nil)
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

		-- Burning (acid / fire): the same small ticks, its own slot.
		if state.burnPerSecond > 0 then
			if time >= state.burnUntil or not isAlive(state) then
				state.burnPerSecond = 0
				state.burnSource = nil
				state.burnKind = nil
				setAttribute(model, "Burning", nil)
			elseif
				time >= state.nextBurnTick
				and time >= state.cinematicUntil
				and not Knockout.isKnockedOut(model)
			then
				state.nextBurnTick = time + KC.BLEED_TICK
				local source = state.burnSource
				local attacker = if source then states[source] else nil
				dealDamage(state, attacker, state.burnPerSecond * KC.BLEED_TICK, source)
			end
		end

		-- Knocked out or dead: the weapon in hand is gone.
		if state.weapon and (not isAlive(state) or Knockout.isKnockedOut(model)) then
			dropWeapon(state, true)
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
			-- Channelling a beam (heat vision): rooted.
			Movement.setSpeedModifier(
				player,
				"Channel",
				if time < state.channelUntil then 0.08 else nil
			)
			-- The kit's own pace (a heavy build slower, the Bull faster) and
			-- whether it can sprint.
			local kit = Kits.get(state.kitId)
			Movement.setSpeedModifier(player, "Kit", if kit then kit.speed else nil)
			Movement.setSprintLock(player, "Kit", kit ~= nil and kit.noSprint == true)
			-- (clients don't predict a dash the server would refuse)
			setAttribute(state.model, "Channeling", time < state.channelUntil)
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

-- The thing in `state`'s hand leaves it towards `direction` (an arc): the
-- server flies it frame by frame; the first thing it touches - someone, a
-- wall, the floor - is where it breaks (and a body takes the blow).
local function throwWeapon(state: CombatState, direction: Vector3)
	local weapon = Weapons.get(state.weapon)
	if
		weapon == nil
		or not isAlive(state)
		or isStunned(state)
		or isBusy(state)
		or state.blocking
		or now() < state.nextAttackAt - C.ATTACK_GRACE
	then
		return
	end
	local time = now()
	Knockout.endProtection(state.model)
	state.combo = 0
	state.lastAttackAt = time
	state.nextAttackAt = time + weapon.recovery
	state.attackingUntil = time + weapon.release
	state.attackToken += 1
	local token = state.attackToken
	Remotes.CombatAction:FireAllClients(state.model, "Bone_Throw")
	task.delay(weapon.release, function()
		if state.attackToken ~= token or not isAlive(state) or state.weapon ~= weapon.id then
			return -- (stunned during the wind-up: he still holds it)
		end
		state.weapon = nil
		setAttribute(state.model, "Weapon", nil)
		throwSeq += 1
		local throwId = throwSeq
		-- From his right hand, up by his head, towards the aim.
		local root = state.root
		local origin = (root.CFrame * CFrame.new(0.9, 1.4, -0.6)).Position
		local position = origin
		local velocity = direction.Unit * weapon.speed + Vector3.new(0, weapon.lift, 0)
		Remotes.WeaponThrown:FireAllClients(state.model, weapon.id, throwId, origin, velocity)
		local ignore: { Instance } = { state.model }
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		params.RespectCanCollide = false
		local started = now()
		local connection: RBXScriptConnection? = nil
		local function broke(at: Vector3, moving: Vector3)
			if connection then
				connection:Disconnect()
			end
			Remotes.WeaponBroke:FireAllClients(weapon.id, throwId, at, moving)
		end
		-- What the bone meets going from `a` along `step`: passes through
		-- hats / accessories and see-through decoration (cast again past
		-- them); stops on a body part (a hit) or anything solid.
		local function fly(a: Vector3, step: Vector3): boolean
			for _ = 1, 6 do
				local hit = workspace:Raycast(a, step, params)
				if hit == nil then
					return false
				end
				local part = hit.Instance
				local model = part:FindFirstAncestorOfClass("Model")
				local victim = if model then states[model] else nil
				local bodyPart = victim ~= nil and victim ~= state and PART_ZONES[part.Name] ~= nil
				if not bodyPart and (part.CanCollide == false or (victim and victim ~= state)) then
					table.insert(ignore, part)
					params.FilterDescendantsInstances = ignore
					step -= hit.Position - a
					a = hit.Position
				else
					if victim and bodyPart and isAlive(victim) then
						local zone: Types.HitZone = PART_ZONES[part.Name] or "Torso"
						resolveHit(state, victim, {
							damage = weapon.damage * C.ZONE_DAMAGE[zone],
							zone = zone,
							stun = weapon.stun,
							headStun = true,
							legSlow = true,
							kind = "Hit",
							blockCost = C.BLOCK_STAMINA_COST * 2,
							knockback = 14,
							bloodChance = weapon.bloodChance,
							moveId = "BoneThrow",
							from = a,
						})
					end
					broke(hit.Position, velocity)
					return true
				end
			end
			return false
		end
		-- (from his body to his hand first: not through a wall he stands at,
		-- nor past someone right against him)
		if fly(root.Position, origin - root.Position) then
			return
		end
		connection = RunService.Heartbeat:Connect(function(dt: number)
			local step = velocity * dt
			if fly(position, step) then
				return
			end
			position += step
			velocity += Vector3.new(0, -weapon.gravity * dt, 0)
			if now() - started > weapon.lifetime then
				broke(position, velocity)
			end
		end)
	end)
end

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
	Rewind.start()
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
		addBurn = addBurn,
	})
	Gadgets.bind({
		getState = function(model: Model): CombatState?
			return states[model]
		end,
		allStates = function(): { [Model]: CombatState }
			return states
		end,
		now = now,
		isAlive = isAlive,
		resolveHit = resolveHit,
		burn = function(attacker: CombatState, victim: CombatState, burn: Kits.BurnDef)
			if
				(victim.owner or victim) == (attacker.owner or attacker)
				or victim.model:GetAttribute("DuelId") ~= attacker.model:GetAttribute("DuelId")
				or Knockout.isKnockedOut(victim.model)
				or Knockout.isProtected(victim.model)
				or now() < victim.cinematicUntil
				or victim.owner ~= nil -- (a clone just goes)
			then
				return
			end
			startBurning(victim, attacker, burn.kind, burn.perSecond, burn.duration)
		end,
		specFor = Moves.specFor,
	})
	Clones.bind({
		register = Combat.register,
		setKit = Combat.setKit,
		getState = function(model: Model): CombatState?
			return states[model]
		end,
		allStates = function(): { [Model]: CombatState }
			return states
		end,
		tryAttack = function(model: Model): boolean
			return Combat.tryAttack(model)
		end,
		now = now,
		isAlive = isAlive,
		isAwakened = isAwakened,
		isStunned = isStunned,
		isBusy = isBusy,
		resolveHit = resolveHit,
		specFor = Moves.specFor,
	})
	Knockout.onGetUp(onGetUp)
	Corpses.onCopy(offerCopiedBone)
	Knockout.onKill(function(killer)
		local state = states[killer]
		if state then
			healInjuries(state)
		end
	end)
	Remotes.Attack.OnServerEvent:Connect(onAttack)
	Remotes.ThrowWeapon.OnServerEvent:Connect(function(player: Player, aim: unknown)
		local character = player.Character
		local state = if character then states[character] else nil
		if state == nil or not attackLimiter.allow(player) then
			return
		end
		local direction = AimRule.validate(aim, state.root.CFrame.LookVector)
		throwWeapon(state, direction or state.root.CFrame.LookVector)
	end)
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
