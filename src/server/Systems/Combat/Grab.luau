--!strict
-- Grab: the kit moves that grab instead of striking (Bouncer: Chokehold,
-- Body Slam, Throw Out...). SERVER-AUTHORITATIVE. The data is a GrabDef
-- (Shared/Kits/KitTypes).
--
-- Life of a grab:
--   1. Moves.use starts the move: his reach clip ("Bouncer_Grab") plays.
--   2. `at` seconds later his hands close: the nearest fighter in the box
--      is caught. The catch goes through Combat's resolveHit (spec.grab):
--      a dash dodges it, it goes through a guard and can't be parried. A
--      hit that stuns him before (attackToken) cancels it: punches beat grabs.
--   3. Caught (and not Awakened: hyper armor shrugs it off): both bodies are
--      held still (anchored) for `duration`, the victim placed in front of
--      him. Every client plays the two hold clips (Remotes.CombatAction).
--      The victim has the "Held" attribute meanwhile (no hit reactions over
--      its clip, see CombatEffectsController).
--   4. The hold's hits land on the held fighter at their times (move id +
--      "_Hold": their own sounds, and quests count the move once). One with
--      knockback / knockdown lets go first (a body can't be thrown while
--      held), laid out on its back for a slam.
--   5. Let go early if he is stunned (someone hits him), either of them
--      dies, is knocked out or leaves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kits = require(ReplicatedStorage.Shared.Kits)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Knockout = require(script.Parent.Parent.Knockout)
local Ragdoll = require(script.Parent.Parent.Ragdoll)
local Hitbox = require(script.Parent.Hitbox)
local State = require(script.Parent.State)

type CombatState = State.CombatState
type HitSpec = State.HitSpec

-- What Grab needs from Combat (given by Moves).
export type Tools = {
	getState: (model: Model) -> CombatState?,
	now: () -> number,
	isAlive: (state: CombatState) -> boolean,
	isAwakened: (state: CombatState) -> boolean,
	setAttribute: (model: Model, name: string, value: any) -> (),
	resolveHit: (attacker: CombatState, victim: CombatState, spec: HitSpec) -> boolean,
	specFor: (hit: Kits.HitDef, zone: Types.HitZone, moveId: string) -> HitSpec,
}

local Grab = {}

-- A stun left on a victim let go early (the hold ended before its time).
local LET_GO_STUN = 0.3

-- Flat (turned around Y only) CFrame of a root part.
local function flat(root: BasePart): CFrame
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 1e-3 then
		forward = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(root.Position, root.Position + forward.Unit)
end

-- After a hold: the body is simulated again by whoever did before (its
-- player, or the server for dummies and limp bodies).
local function giveBack(state: CombatState)
	local root = state.root
	if root.Parent == nil or not root:CanSetNetworkOwnership() then
		return
	end
	if state.player and not Ragdoll.isRagdolled(state.model) then
		root:SetNetworkOwner(state.player)
	else
		root:SetNetworkOwner(nil)
	end
end

-- Room to lay the slammed body down at `lying` (in front of him): no wall
-- between, nothing where it would lie, a floor under it at his feet' level.
local function roomToLay(
	state: CombatState,
	victim: CombatState,
	anchor: CFrame,
	lying: CFrame
): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { state.model, victim.model }
	params.RespectCanCollide = true
	local from = anchor.Position
	local to = Vector3.new(lying.X, from.Y, lying.Z)
	if workspace:Raycast(from, (to - from) + (to - from).Unit * 2.5, params) then
		return false -- a wall in front of him
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { state.model, victim.model }
	overlap.RespectCanCollide = true
	if #workspace:GetPartBoundsInBox(lying, Vector3.new(2.2, 5, 0.8), overlap) > 0 then
		return false
	end
	local floor =
		workspace:Raycast(lying.Position + Vector3.new(0, 1.5, 0), Vector3.new(0, -3, 0), params)
	return floor ~= nil and math.abs(floor.Position.Y - (from.Y - 3)) < 0.8
end

-- Holds `victim` for the grab `grab` of `move` (caught just now).
local function hold(
	tools: Tools,
	state: CombatState,
	victim: CombatState,
	move: Kits.MoveDef,
	grab: Kits.GrabDef,
	token: number
)
	local start = tools.now()
	local ends = start + grab.duration
	local anchor = flat(state.root)
	-- (facing him, or turned away from him: a choke from behind)
	local turn = if grab.facing == "toward" then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	local place = anchor * CFrame.new(0, 0, -grab.distance) * turn

	state.holding = victim
	victim.heldBy = state
	victim.heldUntil = ends
	-- He is busy for the whole hold (no moving, no attacking).
	state.finishingUntil = math.max(state.finishingUntil, ends)
	state.attackingUntil = math.max(state.attackingUntil, ends)
	state.nextAttackAt = math.max(state.nextAttackAt, ends)

	state.root.Anchored = true
	state.root.CFrame = anchor
	victim.root.Anchored = true
	victim.root.CFrame = place
	-- (their hold clips, for the clients to stop if it's cut short)
	tools.setAttribute(victim.model, "Held", grab.victimAnimation)
	tools.setAttribute(state.model, "Holding", grab.animation)
	local duelIds = { state.model:GetAttribute("DuelId"), victim.model:GetAttribute("DuelId") }
	Remotes.CombatAction:FireAllClients(state.model, grab.animation)
	Remotes.CombatAction:FireAllClients(victim.model, grab.victimAnimation)

	local released = false
	local connection: RBXScriptConnection? = nil
	-- Lets go (once). `laid`: the victim is left lying on its back where
	-- its slam clip put it, ready to go limp (Ragdoll) from there.
	local function release(laid: boolean)
		if released then
			return
		end
		released = true
		if connection then
			connection:Disconnect()
		end
		local time = tools.now()
		if state.holding == victim then
			state.holding = nil
		end
		if victim.heldBy == state then
			victim.heldBy = nil
		end
		victim.heldUntil = 0
		if time < ends then
			-- (cut short: both free now, the victim only dazed a moment.
			-- Only what the hold itself set: a duel's freeze stays.)
			if state.finishingUntil == ends then
				state.finishingUntil = time
			end
			if state.attackingUntil == ends then
				state.attackingUntil = time
			end
			if state.nextAttackAt == ends then
				state.nextAttackAt = time
			end
			victim.stunnedUntil = math.min(victim.stunnedUntil, time + LET_GO_STUN)
		end
		tools.setAttribute(victim.model, "Held", nil)
		tools.setAttribute(state.model, "Holding", nil)
		-- (a cinematic finisher may have taken him over meanwhile: it holds him)
		if state.root.Parent and time >= state.cinematicUntil then
			state.root.Anchored = false
			giveBack(state)
		end
		if victim.root.Parent and victim.model:GetAttribute("BeingFinished") ~= true then
			local laidAt = grab.laidAt
			local lying = if laidAt then anchor * laidAt else nil
			if laid and lying and roomToLay(state, victim, anchor, lying) then
				-- On its back where the slam put it (its clip ends in this pose).
				victim.root.CFrame = lying
			end
			victim.root.Anchored = false
			giveBack(victim)
		end
	end

	-- Cut short: he's stunned (hit by someone) or dies, either one is
	-- knocked out, goes limp (a duel round lost), leaves, is taken into a
	-- duel or moved away by another system.
	local function cancelled(): boolean
		return state.attackToken ~= token
			or not tools.isAlive(state)
			or not tools.isAlive(victim)
			or Knockout.isKnockedOut(state.model)
			or Knockout.isKnockedOut(victim.model)
			or Ragdoll.isRagdolled(state.model)
			or Ragdoll.isRagdolled(victim.model)
			or state.model:GetAttribute("DuelId") ~= duelIds[1]
			or victim.model:GetAttribute("DuelId") ~= duelIds[2]
			or (victim.root.Position - place.Position).Magnitude > 3
	end

	connection = RunService.Heartbeat:Connect(function()
		if cancelled() then
			release(false)
		end
	end)

	for _, hit in grab.hits do
		task.delay(hit.at, function()
			if released then
				return
			end
			if cancelled() then
				release(false)
				return
			end
			if hit.knockdown or hit.knockback then
				release(grab.laidAt ~= nil)
			end
			local zone: Types.HitZone = hit.zone or "Torso"
			tools.resolveHit(state, victim, tools.specFor(hit, zone, move.id .. "_Hold"))
			if Knockout.isKnockedOut(victim.model) then
				release(false)
			end
		end)
	end
	-- (a hair after the last hit, which may be at `duration`)
	task.delay(grab.duration + 0.05, function()
		release(grab.laidAt ~= nil)
	end)
end

-- Runs the grab of `move` (just started by Moves.use).
function Grab.run(
	tools: Tools,
	state: CombatState,
	move: Kits.MoveDef,
	grab: Kits.GrabDef,
	token: number
)
	task.delay(grab.at, function()
		if state.attackToken ~= token or not tools.isAlive(state) then
			return -- stunned during the reach (a punch beats a grab)
		end
		-- The nearest fighter in reach who can be caught.
		local box = state.root.CFrame * CFrame.new(0, 0, -grab.forward)
		local victims = Hitbox.query(box, grab.hitbox, state.model)
		local target: CombatState? = nil
		local best = math.huge
		local time = tools.now()
		for _, model in victims do
			local candidate = tools.getState(model)
			if
				candidate
				and tools.isAlive(candidate)
				and not Knockout.isKnockedOut(model)
				and candidate.holding == nil
				and time >= candidate.heldUntil
				and time >= candidate.knockedDownUntil -- (not one lying on the floor)
				and not Ragdoll.isRagdolled(model)
				and time >= candidate.cinematicUntil
				and not Knockout.isProtected(model)
				and model:GetAttribute("DuelId") == state.model:GetAttribute("DuelId")
			then
				local distance = (candidate.root.Position - state.root.Position).Magnitude
				if distance < best then
					target, best = candidate, distance
				end
			end
		end
		if target == nil then
			return
		end
		-- The catch: a little damage, stunned for the whole hold.
		local caught = tools.resolveHit(state, target, {
			damage = grab.damage,
			zone = "Torso",
			stun = grab.duration,
			headStun = false,
			legSlow = false,
			kind = "Hit",
			blockCost = 0,
			bloodChance = {},
			moveId = move.id,
			grab = true,
		})
		if
			not caught
			or state.attackToken ~= token
			or not tools.isAlive(state)
			or Knockout.isKnockedOut(target.model)
			or tools.isAwakened(target) -- (hyper armor: can't be held)
		then
			return
		end
		hold(tools, state, target, move, grab, token)
	end)
end

return table.freeze(Grab)
