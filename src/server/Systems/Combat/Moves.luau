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
--   5. A grab (Bouncer) catches the nearest fighter in reach and holds them
--      while its hits land (Combat/Grab.luau).
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
local Destruction = require(script.Parent.Parent.Destruction)
local Knockout = require(script.Parent.Parent.Knockout)
local Stamina = require(script.Parent.Parent.Stamina)
local Grab = require(script.Parent.Grab)
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
	resolveHit: (attacker: CombatState, victim: CombatState, spec: HitSpec) -> boolean,
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
		blockCost = hit.blockCost or C.BLOCK_STAMINA_COST * 1.5, -- moves are heavier than an M1
		knockback = hit.knockback,
		knockdown = hit.knockdown,
		pull = hit.pull,
		bleed = hit.bleed,
		slow = hit.slow,
		unblockable = hit.unblockable,
		bloodChance = hit.bloodChance or {}, -- a move without it never bleeds visibly
		cuts = hit.cuts,
		launch = hit.launch,
		staminaDrain = hit.staminaDrain,
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
-- everyone inside. Returns the fighters it really LANDED on (not the ones
-- who dodged, parried, blocked, were protected or already knocked out).
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
	if hit.breaks then
		-- a heavy blow: the walls around go too
		local push = state.root.CFrame.LookVector * 35 + Vector3.new(0, 18, 0)
		Destruction.blast(boxCFrame.Position, hit.breaks, push, state.model)
	end
	local reached = {}
	for _, victimModel in victims do
		local victim = c.getState(victimModel)
		-- (A knocked-out body on the floor is not a target: walk over it.)
		if victim and c.isAlive(victim) and not Knockout.isKnockedOut(victimModel) then
			local zone: Types.HitZone =
				zoneFor(state, hit, victimModel, partsByModel[victimModel], aim)
			if c.resolveHit(state, victim, specFor(hit, zone, moveId)) then
				table.insert(reached, victim)
			end
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
	-- Only on someone the tackle really put on the ground.
	local function victimDown(): boolean
		return c.isAlive(victim)
			and c.now() < victim.knockedDownUntil
			and not Knockout.isKnockedOut(victim.model)
	end
	if not victimDown() then
		return
	end
	task.delay(follow.delay, function()
		if state.attackToken ~= token or not c.isAlive(state) or not victimDown() then
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
			if state.attackToken ~= token or not c.isAlive(state) or not victimDown() then
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
		local breaks = charge.breaks
		if breaks then
			-- through the walls in the way
			local look = state.root.CFrame.LookVector
			Destruction.blast(
				state.root.Position + look * 2.5,
				breaks,
				look * 55 + Vector3.new(0, 12, 0),
				state.model
			)
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

-- Beam (heat vision): straight out of the eyes, the way the fighter faced
-- when it started (locked: it doesn't follow the aim), stopped by walls.
-- Someone in it heats up; only after `warmup` seconds in it do the hits
-- land, one every `tick`. Out of it, they cool down twice as fast.
local function runBeam(state: CombatState, move: Kits.MoveDef, token: number)
	local c = context()
	local beam = move.beam
	if beam == nil then
		return
	end
	local startedAt = c.now()
	state.channelUntil = startedAt + beam.to
	local look = state.root.CFrame.LookVector
	local direction = Vector3.new(look.X, 0, look.Z)
	direction = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.new(0, 0, -1)
	local heat: { [CombatState]: number? } = {}
	-- (ticks on a fixed grid: the damage doesn't depend on the frame rate)
	local nextTick = startedAt + beam.from
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local time = c.now()
		local elapsed = time - startedAt
		if state.attackToken ~= token or not c.isAlive(state) or elapsed > beam.to then
			if connection then
				connection:Disconnect()
			end
			if state.attackToken ~= token or not c.isAlive(state) then
				state.channelUntil = 0 -- (cut short: free to move)
			end
			return
		end
		if time < nextTick then
			return
		end
		nextTick = math.max(nextTick + beam.tick, time - beam.tick)
		local head = state.model:FindFirstChild("Head")
		local origin = if head and head:IsA("BasePart")
			then head.Position + direction * 0.5
			else state.root.Position + Vector3.new(0, 1.5, 0)
		-- Walls stop it (fighters don't: they're in the box below, so the
		-- ray goes on through them).
		local skipped: { Instance } = { state.model }
		local length = beam.range
		for _ = 1, 8 do
			params.FilterDescendantsInstances = skipped
			local wall = workspace:Raycast(origin, direction * beam.range, params)
			if wall == nil then
				break
			end
			local owner = wall.Instance:FindFirstAncestorOfClass("Model")
			if owner and owner:FindFirstChildOfClass("Humanoid") then
				table.insert(skipped, owner)
			else
				length = wall.Distance
				break
			end
		end
		local box = CFrame.lookAt(origin + direction * (length / 2), origin + direction * length)
		local victims, partsByModel =
			Hitbox.query(box, Vector3.new(beam.radius * 2, beam.radius * 2, length), state.model)
		local touched: { [CombatState]: boolean } = {}
		for _, victimModel in victims do
			local victim = c.getState(victimModel)
			if victim and c.isAlive(victim) and not Knockout.isKnockedOut(victimModel) then
				touched[victim] = true
				local warmed = (heat[victim] or 0) + beam.tick
				heat[victim] = warmed
				if warmed >= beam.warmup then
					local zone: Types.HitZone =
						zoneFor(state, beam.hit, victimModel, partsByModel[victimModel], direction)
					c.resolveHit(state, victim, specFor(beam.hit, zone, move.id))
				end
			end
		end
		for victim, value in heat do
			if not touched[victim] then
				local cooled = (value or 0) - beam.tick * 2
				heat[victim] = if cooled > 0 then cooled else nil
			end
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
	local grace = Config.Combat.ATTACK_GRACE -- (see Config: the network's few ms)
	if time < state.nextAttackAt - grace or time < (state.cooldowns[move.id] or 0) - grace then
		return false
	end
	local player = state.player
	if player and not Stamina.trySpend(player, move.stamina) then
		return false
	end
	-- Using a move ends the spawn protection (like attacking).
	Knockout.endProtection(state.model)
	state.slipUntil = 0 -- a new move ends the previous slip

	state.cooldowns[move.id] = time + move.cooldown
	c.setAttribute(state.model, `CD_{move.id}`, serverTime(move.cooldown))
	state.combo = 0 -- a move breaks the M1 combo
	state.lastAttackAt = time
	state.nextAttackAt = time + move.duration
	state.attackingUntil = time + move.duration
	state.attackToken += 1
	local token = state.attackToken
	Remotes.CombatAction:FireAllClients(state.model, move.animation)

	-- Slip: dodge the next frontal hit during the window (Combat checks
	-- slipUntil in resolveHit and calls Moves.counter).
	local counter = move.counter
	if counter then
		-- (Never longer than the move itself.)
		state.slipUntil = time + math.min(counter.window, move.duration)
		state.slipMoveId = move.id
	end

	-- A chained combo: the hits after the first land on whoever the first
	-- one reached (if still close and standing), they can't miss halfway.
	local chained: { CombatState }? = nil
	for index, hit in move.hits do
		task.delay(hit.at, function()
			-- Cancelled (stunned meanwhile), dead or removed?
			if state.attackToken ~= token or not c.isAlive(state) then
				return
			end
			if not move.chain or index == 1 then
				local reached = strike(state, hit, move.id, aim)
				if move.chain then
					chained = reached
				end
				return
			end
			local targets: { CombatState } = chained or {}
			for _, victim in targets do
				local distance = (victim.root.Position - state.root.Position).Magnitude
				if
					c.isAlive(victim)
					and not Knockout.isKnockedOut(victim.model)
					and distance <= KC.FOLLOW_UP_RANGE
				then
					local zone: Types.HitZone = hit.zone or "Head"
					c.resolveHit(state, victim, specFor(hit, zone, move.id))
				end
			end
		end)
	end
	runCharge(state, move, token)
	runBeam(state, move, token)
	local grab = move.grab
	if grab then
		Grab.run({
			getState = c.getState,
			now = c.now,
			isAlive = c.isAlive,
			isAwakened = c.isAwakened,
			setAttribute = c.setAttribute,
			resolveHit = c.resolveHit,
			specFor = specFor,
		}, state, move, grab, token)
	end
	return true
end

-- A slip worked: `state` dodged `attacker`'s hit. Answer with the slip
-- move's counter (its animation for everyone, the hit `at` seconds later
-- if the attacker is still in reach).
function Moves.counter(state: CombatState, attacker: CombatState)
	local c = context()
	local kit = Kits.get(state.kitId)
	local slipMoveId = state.slipMoveId
	state.slipMoveId = nil
	if
		kit == nil
		or slipMoveId == nil
		or not c.isAlive(state)
		or c.isStunned(state)
		or c.isBusy(state)
	then
		return
	end
	local move: Kits.MoveDef? = nil
	local lists = { kit.moves }
	local awakening = kit.awakening
	if awakening then
		table.insert(lists, awakening.moves)
	end
	for _, list in lists do
		for _, candidate in list do
			if candidate.id == slipMoveId then
				move = candidate
			end
		end
	end
	local counter = if move then move.counter else nil
	if move == nil or counter == nil then
		return
	end
	local time = c.now()
	local busy = counter.at + 0.37 -- the counter animation
	state.nextAttackAt = time + busy
	state.attackingUntil = time + busy
	state.attackToken += 1
	local token = state.attackToken
	state.invulnerableUntil = math.max(state.invulnerableUntil, time + counter.at)
	Remotes.CombatAction:FireAllClients(state.model, counter.animation)
	task.delay(counter.at, function()
		if state.attackToken ~= token or not c.isAlive(state) or not c.isAlive(attacker) then
			return
		end
		local distance = (attacker.root.Position - state.root.Position).Magnitude
		if distance > KC.FOLLOW_UP_RANGE then
			return -- they backed off
		end
		local zone: Types.HitZone = counter.hit.zone or "Head"
		c.resolveHit(state, attacker, specFor(counter.hit, zone, move.id .. "_Counter"))
	end)
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
	local activation = KC.AWAKEN_TIME
	state.combo = 0
	state.nextAttackAt = time + activation
	state.attackingUntil = time + activation
	state.attackToken += 1
	Remotes.CombatAction:FireAllClients(state.model, awakening.animation)
	return true
end

return Moves
