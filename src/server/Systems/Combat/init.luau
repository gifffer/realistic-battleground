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

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local AimRule = require(ReplicatedStorage.Shared.Util.AimRule)
local HitSide = require(ReplicatedStorage.Shared.Util.HitSide)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Knockout = require(script.Parent.Knockout)
local Movement = require(script.Parent.Movement)
local Stamina = require(script.Parent.Stamina)
local Hitbox = require(script.Hitbox)

local C = Config.Combat

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

type CombatState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	player: Player?, -- nil for dummies

	combo: number, -- last M1 of the combo (0 = none yet)
	lastAttackAt: number,
	nextAttackAt: number, -- can't M1 before this time
	attackingUntil: number, -- slowed while attacking
	attackToken: number, -- +1 cancels the attack that is winding up

	blocking: boolean,
	blockStartedAt: number,
	blockEndedAt: number,
	parryReady: boolean, -- this block got a parry window (anti-spam)

	stunnedUntil: number,
	legSlowUntil: number, -- slowed by a leg hit until then
	finishingUntil: number, -- doing a finisher: can't move until then
	invulnerableUntil: number, -- dash dodge frames
	nextDashAt: number,
	knockbackUntil: number, -- a finisher's knockback is running until then
}

export type DamageInfo = {
	victim: Model,
	attacker: Model,
	amount: number,
}

local Combat = {}

local states: { [Model]: CombatState } = {}
local damaged = Signal.new() :: Signal.Signal<DamageInfo>

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

-- Can't fight: knocked out, sliding / climbing, or in the middle of a finisher.
local function isBusy(state: CombatState): boolean
	return Knockout.isKnockedOut(state.model) or isBusyMoving(state) or now() < state.finishingUntil
end

local function setAttribute(model: Model, name: string, value: boolean)
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
	attackId: number?
)
	Remotes.CombatEvent:FireAllClients(kind, victim, attacker, zone, side, attackId)
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
	stopBlocking(state)
	setAttribute(state.model, "Stunned", true)
end

-- Damage that would bring the victim to 0 HP knocks them out instead
-- (Knockout), it never kills directly.
local function dealDamage(victim: CombatState, attacker: CombatState, amount: number)
	Knockout.noteHit(victim.model, attacker.model)
	if victim.humanoid.Health - amount <= 0 then
		stopBlocking(victim)
		victim.attackToken += 1 -- cancels a punch they were winding up
		Knockout.knockOut(victim.model, attacker.model)
	else
		victim.humanoid.Health -= amount
	end
	damaged.fire({ victim = victim.model, attacker = attacker.model, amount = amount })
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
local function resolveHit(
	attacker: CombatState,
	victim: CombatState,
	combo: number,
	zone: Types.HitZone,
	attackId: number?
)
	local isFinisher = combo == #C.M1_DAMAGE
	local damage = C.M1_DAMAGE[combo] * C.ZONE_DAMAGE[zone]
	local time = now()
	-- Which side of the victim the fist arrives from (picks the reaction).
	local side: Types.HitSide = HitSide.compute(victim.root.CFrame, attacker.root.Position)

	-- 0. On the ground (finish them instead), or just spawned (protected).
	if Knockout.isKnockedOut(victim.model) then
		return
	end
	if Knockout.isProtected(victim.model) then
		fireEvent("Protected", victim.model, attacker.model, nil, nil, attackId)
		return
	end

	-- 1. Dash dodge frames: the hit misses.
	if time < victim.invulnerableUntil then
		fireEvent("Dodged", victim.model, attacker.model, nil, nil, attackId)
		return
	end

	if victim.blocking and isInFront(victim, attacker) then
		-- 2. Parry: block started just before the hit → attacker is stunned.
		if victim.parryReady and time - victim.blockStartedAt <= C.PARRY_WINDOW then
			stun(attacker, C.PARRY_STUN)
			fireEvent("Parried", victim.model, attacker.model, nil, nil, attackId)
			return
		end

		-- 3. Block: costs stamina. Not enough → guard break.
		local cost = if isFinisher then C.BLOCK_STAMINA_COST * 2 else C.BLOCK_STAMINA_COST
		local victimPlayer = victim.player
		if victimPlayer and not Stamina.trySpend(victimPlayer, cost) then
			Stamina.drain(victimPlayer, Config.Stamina.MAX) -- empty the bar
			stun(victim, C.GUARD_BREAK_STUN)
			fireEvent("GuardBreak", victim.model, attacker.model, nil, side, attackId)
			return
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
		fireEvent("Blocked", victim.model, attacker.model, nil, side, attackId)
		return
	end

	-- 4. Normal hit.
	dealDamage(victim, attacker, damage)
	if Knockout.isKnockedOut(victim.model) then
		-- That hit knocked them out: no stun or knockback on a limp body.
		fireEvent(
			if isFinisher then "Finisher" else "Hit",
			victim.model,
			attacker.model,
			zone,
			side,
			attackId
		)
		return
	end
	if zone == "Legs" then
		victim.legSlowUntil = time + C.LEG_HIT_SLOW_TIME
	end
	local extraStun = if zone == "Head" then C.HEAD_EXTRA_STUN else 0
	if isFinisher then
		stun(victim, C.FINISHER_STUN + extraStun)
		local direction = awayFromAttacker(attacker, victim)
		Push.apply(victim.root, direction * C.KNOCKBACK_SPEED, C.KNOCKBACK_TIME)
		victim.knockbackUntil = time + C.KNOCKBACK_TIME
		fireEvent("Finisher", victim.model, attacker.model, zone, side, attackId)
	else
		stun(victim, C.HIT_STUN + extraStun)
		-- Small push: the body is moved by the fist (no "punch through it" look).
		-- Not during a finisher's knockback (a new push replaces the running one).
		if time >= victim.knockbackUntil then
			Push.apply(
				victim.root,
				awayFromAttacker(attacker, victim) * C.HIT_PUSH_SPEED,
				C.HIT_PUSH_TIME
			)
		end
		fireEvent("Hit", victim.model, attacker.model, zone, side, attackId)
	end
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
		nextDashAt = 0,
		knockbackUntil = 0,
	}
	model:SetAttribute("Blocking", false)
	model:SetAttribute("Stunned", false)
	CollectionService:AddTag(model, C.TAG)
	Knockout.register(model, player)

	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			states[model] = nil
		end
	end)
end

-- Finisher on a KO'd fighter: kneel and strike; the victim dies at impact
-- unless the attacker is stunned (or dies) before.
local function startFinisher(state: CombatState, target: Model): boolean
	if not Knockout.reserve(target, state.model) then
		return false
	end
	local time = now()
	local K = Config.Knockout
	state.nextAttackAt = time + K.FINISH_DURATION
	state.finishingUntil = time + K.FINISH_DURATION
	state.attackingUntil = time + K.FINISH_DURATION
	state.combo = 0
	state.attackToken += 1
	local token = state.attackToken
	Remotes.CombatAction:FireAllClients(state.model, "Finisher")

	task.delay(K.FINISH_IMPACT, function()
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
	if time < state.nextAttackAt then
		resolved()
		return false
	end
	-- Attacking ends the spawn protection.
	Knockout.endProtection(model)

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
				resolveHit(state, victim, combo, landed, attackId)
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

function Combat.onDamaged(callback: (DamageInfo) -> ()): Signal.Connection
	return damaged.connect(callback)
end

------------------------------------------------------------------------------
-- Every frame: end stuns, apply slowdowns to players
------------------------------------------------------------------------------

local function update()
	local time = now()
	for model, state in states do
		local stunned = time < state.stunnedUntil
		setAttribute(model, "Stunned", stunned)

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
	Knockout.onGetUp(onGetUp)
	Remotes.Attack.OnServerEvent:Connect(onAttack)
	Remotes.SetBlocking.OnServerEvent:Connect(onSetBlocking)
	Remotes.Dash.OnServerEvent:Connect(onDash)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(update)
end

return Combat
