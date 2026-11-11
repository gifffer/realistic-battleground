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
--   Combat.tryAttack(model)            M1 (used by remotes and dummies)
--   Combat.setBlocking(model, bool)
--   Combat.onDamaged(callback)         every damage dealt (for kills, step 3)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Movement = require(script.Parent.Movement)
local Stamina = require(script.Parent.Stamina)
local Hitbox = require(script.Hitbox)

local C = Config.Combat

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
	invulnerableUntil: number, -- dash dodge frames
	nextDashAt: number,
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

local function setAttribute(model: Model, name: string, value: boolean)
	if model:GetAttribute(name) ~= value then
		model:SetAttribute(name, value)
	end
end

local function fireEvent(kind: Types.CombatEventKind, victim: Model, attacker: Model)
	Remotes.CombatEvent:FireAllClients(kind, victim, attacker)
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

local function dealDamage(victim: CombatState, attacker: CombatState, amount: number)
	victim.humanoid:TakeDamage(amount)
	damaged.fire({ victim = victim.model, attacker = attacker.model, amount = amount })
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

-- Decides what a hit does to `victim`. The heart of the combat rules.
local function resolveHit(attacker: CombatState, victim: CombatState, combo: number)
	local isFinisher = combo == #C.M1_DAMAGE
	local damage = C.M1_DAMAGE[combo]
	local time = now()

	-- 1. Dash dodge frames: the hit misses.
	if time < victim.invulnerableUntil then
		fireEvent("Dodged", victim.model, attacker.model)
		return
	end

	if victim.blocking and isInFront(victim, attacker) then
		-- 2. Parry: block started just before the hit → attacker is stunned.
		if victim.parryReady and time - victim.blockStartedAt <= C.PARRY_WINDOW then
			stun(attacker, C.PARRY_STUN)
			fireEvent("Parried", victim.model, attacker.model)
			return
		end

		-- 3. Block: costs stamina. Not enough → guard break.
		local cost = if isFinisher then C.BLOCK_STAMINA_COST * 2 else C.BLOCK_STAMINA_COST
		local victimPlayer = victim.player
		if victimPlayer and not Stamina.trySpend(victimPlayer, cost) then
			Stamina.drain(victimPlayer, Config.Stamina.MAX) -- empty the bar
			stun(victim, C.GUARD_BREAK_STUN)
			fireEvent("GuardBreak", victim.model, attacker.model)
			return
		end
		dealDamage(victim, attacker, damage * (1 - C.BLOCK_REDUCTION))
		fireEvent("Blocked", victim.model, attacker.model)
		return
	end

	-- 4. Normal hit.
	dealDamage(victim, attacker, damage)
	if isFinisher then
		stun(victim, C.FINISHER_STUN)
		local away = victim.root.Position - attacker.root.Position
		local flat = Vector3.new(away.X, 0, away.Z)
		local direction = if flat.Magnitude > 1e-3
			then flat.Unit
			else attacker.root.CFrame.LookVector
		Push.apply(victim.root, direction * C.KNOCKBACK_SPEED, C.KNOCKBACK_TIME)
		fireEvent("Finisher", victim.model, attacker.model)
	else
		stun(victim, C.HIT_STUN)
		fireEvent("Hit", victim.model, attacker.model)
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
		invulnerableUntil = 0,
		nextDashAt = 0,
	}
	model:SetAttribute("Blocking", false)
	model:SetAttribute("Stunned", false)
	CollectionService:AddTag(model, C.TAG)

	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			states[model] = nil
		end
	end)
end

-- M1. Returns true if the attack started.
function Combat.tryAttack(model: Model): boolean
	local state = states[model]
	if state == nil or not isAlive(state) or isStunned(state) or state.blocking then
		return false
	end
	local time = now()
	if time < state.nextAttackAt then
		return false
	end

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

	task.delay(C.HIT_DELAY, function()
		-- Cancelled (stunned during the wind-up), dead, or removed?
		if state.attackToken ~= token or not isAlive(state) then
			return
		end
		local boxCFrame = state.root.CFrame * CFrame.new(0, 0, -C.HITBOX_FORWARD)
		for _, victimModel in Hitbox.query(boxCFrame, C.HITBOX_SIZE, state.model) do
			local victim = states[victimModel]
			if victim and isAlive(victim) then
				resolveHit(state, victim, combo)
			end
		end
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
	if state.blocking or not isAlive(state) or isStunned(state) then
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
	if state == nil or not isAlive(state) or isStunned(state) or state.blocking then
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

local function onAttack(player: Player)
	local character = player.Character
	if character and attackLimiter.allow(player) then
		Combat.tryAttack(character)
	end
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

local function onDash(player: Player)
	local character = player.Character
	if character and dashLimiter.allow(player) then
		tryDash(character, player)
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

function Combat.start()
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
