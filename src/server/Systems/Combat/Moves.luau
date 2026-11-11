--!strict
-- Moves: the kit moves (keys 1–4) and the Awakening (G). SERVER-AUTHORITATIVE.
--
-- A move is DATA (Shared/Kits/<Kit>.luau): its hits, their timings and
-- their effects. This module runs it:
--   1. Remotes.UseMove(slot, aim) → Moves.use() checks: alive, not stunned,
--      not blocking, not busy, not mid-attack, off cooldown, enough stamina.
--      Refused → Remotes.MoveRefused (the client stops its animation).
--   2. Accepted → cooldown starts ("CD_<moveId>" attribute on the model =
--      server time when it's ready again, for the HUD) and every client
--      plays the animation (Remotes.CombatAction).
--   3. Each hit of the move checks its own hitbox at its own time (`at`,
--      the impact keyframe of the animation) and goes through
--      Combat's resolveHit, like an M1: block, parry, dodge all work.
--   4. A charge (tackle) instead checks a hitbox around the attacker every
--      frame while they rush forward; the first fighter touched is hit.
--
-- The attacker's own client moves its character during a charge (like a
-- dash: instant feel). The server only decides who gets hit.
--
-- Awakening: when the "Fury" gauge is full, G → Moves.awaken(): for a few
-- seconds the 4 moves are replaced by stronger ones, every hit deals more,
-- and hits don't stun the awakened fighter ("hyper armor", in Combat).
--
-- Combat.start() gives this module the tools it needs (Moves.bind): the two
-- modules share the fighters' states without requiring each other.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Knockout = require(script.Parent.Parent.Knockout)
local Stamina = require(script.Parent.Parent.Stamina)
local Hitbox = require(script.Parent.Hitbox)
local State = require(script.Parent.State)

type CombatState = State.CombatState
type HitSpec = State.HitSpec

local KC = Config.Kits
local C = Config.Combat

-- Zones a move without its own zone can land on (where the attacker aims).
local AIMABLE_ZONES = { "Head", "Torso" }

export type Context = {
	getState: (model: Model) -> CombatState?,
	now: () -> number,
	isAlive: (state: CombatState) -> boolean,
	isStunned: (state: CombatState) -> boolean,
	isBusy: (state: CombatState) -> boolean,
	isAwakened: (state: CombatState) -> boolean,
	setAttribute: (model: Model, name: string, value: any) -> (),
	resolveHit: (attacker: CombatState, victim: CombatState, spec: HitSpec) -> (),
	aimZone: (attacker: CombatState, victim: Model, direction: Vector3) -> Types.HitZone?,
	landingZone: (
		requested: Types.HitZone,
		partsInBox: { [string]: boolean },
		allowed: { string }
	) -> Types.HitZone,
	addFury: (state: CombatState, amount: number) -> (),
}

local Moves = {}

local ctx: Context? = nil

function Moves.bind(context: Context)
	ctx = context
end

local function context(): Context
	assert(ctx, "[Moves] Combat.start() must call Moves.bind() first")
	return ctx
end

-- Server clock → shared clock, for attributes the clients read
-- (workspace:GetServerTimeNow() is the same on the server and every client).
local function serverTime(fromNow: number): number
	return workspace:GetServerTimeNow() + fromNow
end

-- The HitSpec of one hit of a move (zone already decided).
local function specFor(hit: Kits.HitDef, zone: Types.HitZone, moveId: string): HitSpec
	return {
		damage = hit.damage,
		zone = zone,
		stun = hit.stun,
		headStun = false, -- a move's stun is already tuned per hit
		legSlow = false,
		kind = "Hit",
		blockCost = C.BLOCK_STAMINA_COST * 1.5, -- moves are heavier than an M1
		knockback = hit.knockback,
		knockdown = hit.knockdown,
		pull = hit.pull,
		bleed = hit.bleed,
		slow = hit.slow,
		unblockable = hit.unblockable,
		attackId = nil,
		moveId = moveId,
	}
end

-- The zone `hit` lands on for `victimModel`: its own zone, or where the
-- attacker aims (head or torso, like an M1).
local function zoneFor(
	state: CombatState,
	hit: Kits.HitDef,
	victimModel: Model,
	parts: { [string]: boolean },
	aim: Vector3?
): Types.HitZone
	local fixed = hit.zone
	if fixed then
		-- (The cast keeps the type checker from widening the zone to `string`.)
		return fixed :: Types.HitZone
	end
	local c = context()
	local aimed: Types.HitZone = if aim
		then c.aimZone(state, victimModel, aim) or "Torso"
		else "Torso"
	return c.landingZone(aimed, parts, AIMABLE_ZONES)
end

-- Checks the hitbox of `hit` in front of the attacker and resolves it on
-- everyone inside. Returns the fighters it reached.
local function strike(
	state: CombatState,
	hit: Kits.HitDef,
	moveId: string,
	aim: Vector3?,
	cframe: CFrame?
): { CombatState }
	local c = context()
	local boxCFrame = cframe or state.root.CFrame * CFrame.new(0, 0, -hit.forward)
	local victims, partsByModel = Hitbox.query(boxCFrame, hit.hitbox, state.model)
	local reached = {}
	for _, victimModel in victims do
		local victim = c.getState(victimModel)
		if victim and c.isAlive(victim) then
			local zone: Types.HitZone =
				zoneFor(state, hit, victimModel, partsByModel[victimModel], aim)
			c.resolveHit(state, victim, specFor(hit, zone, moveId))
			table.insert(reached, victim)
		end
	end
	return reached
end

-- Ground strike after a tackle connects (Awakened tackle): the attacker
-- kneels on the fallen victim and hammers down.
local function followUp(state: CombatState, move: Kits.MoveDef, victim: CombatState, token: number)
	local c = context()
	local follow = move.followUp
	if follow == nil then
		return
	end
	task.delay(follow.delay, function()
		if state.attackToken ~= token or not c.isAlive(state) or not c.isAlive(victim) then
			return
		end
		local time = c.now()
		-- Locked in place for the strike (like a KO finisher).
		local busy = follow.at + 0.4
		state.finishingUntil = time + busy
		state.attackingUntil = math.max(state.attackingUntil, time + busy)
		state.nextAttackAt = math.max(state.nextAttackAt, time + busy)
		Remotes.CombatAction:FireAllClients(state.model, follow.animation)
		task.delay(follow.at, function()
			if state.attackToken ~= token or not c.isAlive(state) or not c.isAlive(victim) then
				return
			end
			local distance = (victim.root.Position - state.root.Position).Magnitude
			if distance > KC.FOLLOW_UP_RANGE then
				return -- they rolled away
			end
			c.resolveHit(state, victim, {
				damage = follow.damage,
				zone = "Torso",
				stun = 0,
				headStun = false,
				legSlow = false,
				kind = "Hit",
				blockCost = 0,
				unblockable = true,
				moveId = move.id .. "_FollowUp",
			})
		end)
	end)
end

-- Tackle: from `charge.from` to `charge.to` seconds, every frame, a hitbox
-- around the rushing attacker. The first fighter touched takes the hit.
local function runCharge(state: CombatState, move: Kits.MoveDef, token: number)
	local c = context()
	local charge = move.charge
	if charge == nil then
		return
	end
	local startedAt = c.now()
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = c.now() - startedAt
		local cancelled = state.attackToken ~= token or not c.isAlive(state)
		if cancelled or elapsed > charge.to then
			if connection then
				connection:Disconnect()
			end
			return
		end
		if elapsed < charge.from then
			return
		end
		local reached = strike(state, charge.hit, move.id, nil)
		if #reached > 0 then
			if connection then
				connection:Disconnect()
			end
			-- The first one touched takes the follow-up (Awakened tackle).
			followUp(state, move, reached[1], token)
		end
	end)
end

-- Kit move on key `slot` (1–4). Returns true if it started.
function Moves.use(state: CombatState, slot: number, aim: Vector3?): boolean
	local c = context()
	local kit = Kits.get(state.kitId)
	if kit == nil then
		return false
	end
	local move = Kits.move(kit, slot, c.isAwakened(state))
	if move == nil then
		return false
	end
	if not c.isAlive(state) or c.isStunned(state) or state.blocking or c.isBusy(state) then
		return false
	end
	local time = c.now()
	if time < state.nextAttackAt or time < (state.cooldowns[move.id] or 0) then
		return false
	end
	local player = state.player
	if player and not Stamina.trySpend(player, move.stamina) then
		return false
	end
	-- Using a move ends the spawn protection (like attacking).
	Knockout.endProtection(state.model)

	state.cooldowns[move.id] = time + move.cooldown
	c.setAttribute(state.model, `CD_{move.id}`, serverTime(move.cooldown))
	state.combo = 0 -- a move breaks the M1 combo
	state.lastAttackAt = time
	state.nextAttackAt = time + move.duration
	state.attackingUntil = time + move.duration
	state.attackToken += 1
	local token = state.attackToken
	Remotes.CombatAction:FireAllClients(state.model, move.animation)

	for _, hit in move.hits do
		task.delay(hit.at, function()
			-- Cancelled (stunned meanwhile), dead or removed?
			if state.attackToken ~= token or not c.isAlive(state) then
				return
			end
			strike(state, hit, move.id, aim)
		end)
	end
	runCharge(state, move, token)
	return true
end

-- G: awaken if the gauge is full. Returns true if it started.
function Moves.awaken(state: CombatState): boolean
	local c = context()
	local kit = Kits.get(state.kitId)
	local awakening = if kit then kit.awakening else nil
	if awakening == nil then
		return false
	end
	if
		state.fury < KC.FURY_MAX
		or c.isAwakened(state)
		or not c.isAlive(state)
		or c.isStunned(state)
		or state.blocking
		or c.isBusy(state)
	then
		return false
	end
	local time = c.now()
	if time < state.nextAttackAt then
		return false
	end
	state.fury = 0
	c.setAttribute(state.model, "Fury", 0)
	state.awakenedUntil = time + awakening.duration
	c.setAttribute(state.model, "Awakened", true)
	c.setAttribute(state.model, "AwakenedUntil", serverTime(awakening.duration))
	-- The activation is a short animation: no attacking during it.
	local activation = 1.0
	state.combo = 0
	state.nextAttackAt = time + activation
	state.attackingUntil = time + activation
	state.attackToken += 1
	Remotes.CombatAction:FireAllClients(state.model, awakening.animation)
	return true
end

return Moves
