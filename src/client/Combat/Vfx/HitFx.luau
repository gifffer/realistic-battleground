--!strict
-- Vfx/HitFx: turns fights into VFX. It is the dispatcher between the
-- combat events and the move specs (Vfx/Moves):
--
--   HitFx.onAction(model, clip)   an action clip just started on a fighter
--       (from CharacterAnimationController.onActionPlayed: our own moves,
--       other players' moves, follow-ups, reactions). Plays the clip spec's
--       beats (swing trails, smears, pre-dim, glints) at their times. A new
--       action, a stun or a KO cancels what is still pending.
--   HitFx.onPredictedHit(victim, attacker, combo, zone, side)
--       our own M1 at the very frame our fist lands (zero latency).
--   HitFx.onCombatEvent(kind, victim, attacker, zone, side, moveId, alreadyShown, blood)
--       the server's verdict. Runs the move spec's impact (unless our
--       prediction already showed it), then checks whether the hit knocked
--       the victim out → the knockout overlay (the last hit looks different).
--   HitFx.stop(model)             cancel pending beats, trails off
--   HitFx.bloodDelay(predictedAt) when to start the blood (≈0.1 s after the flash)
--   HitFx.tierFor(kind, attacker, moveId) the tier a hit will get (for the hit-stop)
--
-- Which spec a hit uses (its "spec id"):
--   • the server's moveId if there is one ("BottleSmash", "Slip_Counter",
--     "TackleSlam_FollowUp", "BodySlam_Hold", "RiftSwarm"...);
--   • a plain M1: "M1_1".."M1_4" (kind "Finisher" = the 4th M1);
--   • "Blocked" / "Parried" / "GuardBreak" / "Dodged" / "Protected"; a
--     blocked kit move first looks for "<moveId>_Blocked".
-- A spec id with no spec gets a sensible default (tier from the Kits hit:
-- knockdown / launch / big knockback → Heavy, else Clean).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kits = require(ReplicatedStorage.Shared.Kits)
local Config = require(ReplicatedStorage.Shared.Config)
local CharacterAnimationController =
	require(script.Parent.Parent.Parent.Controllers.CharacterAnimationController)

local Camera = require(script.Parent.Camera)
local Impact = require(script.Parent.Impact)
local Limb = require(script.Parent.Limb)
local Moves = require(script.Parent.Moves)
local Pool = require(script.Parent.Pool)
local Types = require(script.Parent.Types)

type Tier = Types.Tier
type MoveSpec = Types.MoveSpec
type ClipSpec = Types.ClipSpec
type HitContext = Types.HitContext

local HitFx = {}

local player = Players.LocalPlayer
local HIT_DELAY = Config.Combat.HIT_DELAY
local BLOOD_AFTER_FLASH = 0.1 -- seconds (README: blood ≈ 2 frames at 15 fps after the flash)

------------------------------------------------------------------------------
-- Built-in defaults (the plain M1 combo and the base events). A spec file
-- (Vfx/Moves/Base.luau) with the same name replaces them.
------------------------------------------------------------------------------

local DEFAULT_CLIPS: { [string]: ClipSpec } = {
	-- jab (lead hand): the snappiest
	Brawler_M1_1 = {
		beats = { { at = HIT_DELAY, limb = "LeftArm", swing = 0.055, after = 0.03, life = 0.1 } },
	},
	-- cross (rear hand)
	Brawler_M1_2 = {
		beats = { { at = HIT_DELAY, limb = "RightArm", swing = 0.06, after = 0.035, life = 0.11 } },
	},
	-- hook (lead hand): a longer trail so the arc reads
	Brawler_M1_3 = {
		beats = {
			{
				at = HIT_DELAY,
				limb = "LeftArm",
				swing = 0.065,
				after = 0.04,
				life = 0.16,
				arc = true,
			},
		},
	},
	-- overhand ender: smear + the screen dims 2 frames before contact (ours)
	Brawler_M1_4 = {
		beats = {
			{
				at = HIT_DELAY,
				limb = "RightArm",
				swing = 0.065,
				after = 0.04,
				life = 0.14,
				smear = true,
				preDim = true,
			},
		},
	},
}

local DEFAULT_MOVES: { [string]: MoveSpec } = {
	M1_1 = { tier = "Light", limb = "LeftArm" },
	M1_2 = { tier = "Clean", limb = "RightArm" },
	M1_3 = { tier = "Clean", limb = "LeftArm" },
	M1_4 = { tier = "Last", limb = "RightArm" },
	Blocked = { tier = "Blocked", material = "Guard" },
	Parried = { tier = "Clean", material = "Guard" },
	GuardBreak = { tier = "Heavy", material = "Guard" },
	Dodged = { noDefault = true },
	Protected = { noDefault = true },
}

------------------------------------------------------------------------------
-- Kits lookups: the hit definitions of a move id
------------------------------------------------------------------------------

type MoveInfo = { hits: { Kits.HitDef }, animation: string? }
local moveInfo: { [string]: MoveInfo } = {}

local function addMove(move: Kits.MoveDef)
	local function put(id: string, hits: { Kits.HitDef }, animation: string?)
		if #hits > 0 and moveInfo[id] == nil then
			moveInfo[id] = { hits = hits, animation = animation }
		end
	end
	local hits = table.clone(move.hits)
	if move.charge then
		table.insert(hits, 1, move.charge.hit)
	end
	if move.beam then
		table.insert(hits, move.beam.hit)
	end
	local gadget = move.gadget
	if gadget then
		if gadget.flask then
			table.insert(hits, gadget.flask.hit)
		end
		if gadget.ray then
			table.insert(hits, gadget.ray.hit)
		end
		if gadget.wave then
			table.insert(hits, gadget.wave.hit)
		end
		if gadget.swarm then
			for _, hit in gadget.swarm.hits do
				table.insert(hits, hit)
			end
		end
	end
	put(move.id, hits, move.animation)
	if move.counter then
		put(move.id .. "_Counter", { move.counter.hit }, move.counter.animation)
	end
	if move.grab then
		put(move.id .. "_Hold", move.grab.hits, move.grab.animation)
	end
end

for _, kit in Kits.list() do
	for _, move in kit.moves do
		addMove(move)
	end
	if kit.awakening then
		for _, move in kit.awakening.moves do
			addMove(move)
		end
	end
end

-- A "big" hit: it throws the victim (knockdown, launch, big knockback).
local function isBig(hit: Kits.HitDef?): boolean
	return hit ~= nil and (hit.knockdown ~= nil or hit.launch ~= nil or (hit.knockback or 0) >= 40)
end

------------------------------------------------------------------------------
-- Per-fighter state
------------------------------------------------------------------------------

local actionStart: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local actionClip: { [Model]: string } = setmetatable({}, { __mode = "k" }) :: any
-- Fallback hit counter per attacker and spec id (reset by a new action).
local hitCounts: { [Model]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- When each fighter was last knocked out (its "KnockedOut" attribute).
local downAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local ALL_LIMBS: { Types.Limb } = { "RightArm", "LeftArm", "RightLeg", "LeftLeg", "Head", "Prop" }

function HitFx.stop(model: Model)
	Pool.bump(model)
	for _, limb in ALL_LIMBS do
		Limb.trailOff(model, limb)
	end
end

-- Stun / KO / ragdoll cancel a fighter's pending beats. (CEC calls this
-- for every fighter.)
function HitFx.watch(model: Model)
	if watched[model] then
		return
	end
	watched[model] = true
	for _, attribute in { "Stunned", "KnockedOut", "Ragdolled" } do
		model:GetAttributeChangedSignal(attribute):Connect(function()
			if model:GetAttribute(attribute) == true then
				HitFx.stop(model)
				if attribute == "KnockedOut" then
					downAt[model] = os.clock()
				end
			end
		end)
	end
end

------------------------------------------------------------------------------
-- Actions (swings)
------------------------------------------------------------------------------

function HitFx.onAction(model: Model, clip: string)
	local token = Pool.bump(model)
	actionStart[model] = os.clock()
	actionClip[model] = clip
	hitCounts[model] = nil
	local spec = Moves.clips[clip] or DEFAULT_CLIPS[clip]
	if spec == nil then
		return
	end
	local own = model == player.Character
	local function alive(): boolean
		return Pool.token(model) == token
			and CharacterAnimationController.getLastAction(model) == clip
	end
	local function later(seconds: number, fn: () -> ())
		Pool.after(seconds, function()
			if alive() then
				fn()
			end
		end)
	end
	local beats: { Types.BeatSpec } = spec.beats or {}
	for _, beat in beats do
		local at = beat.at
		local on = math.max(0, at - (beat.swing or 0.06))
		local off = at + (beat.after or 0.035)
		Limb.trailWindow(
			model,
			beat.limb,
			on,
			off,
			{ life = beat.life, arc = beat.arc, width = beat.width }
		)
		if beat.smear then
			Limb.track(model, true)
			later(at, function()
				Limb.smear(model, beat.limb)
			end)
		end
		if beat.preDim and own then
			later(math.max(0, at - 2 / 60), function()
				Camera.dim(0.06, { preFrames = 2, recover = 0.15 })
			end)
		end
		if beat.glint then
			later(math.max(0, at - 1 / 60), function()
				Limb.glint(model, beat.limb)
			end)
		end
	end
	local run = spec.run
	if run then
		local ok, err = pcall(run :: any, { model = model, clip = clip, own = own, later = later })
		if not ok then
			warn(`[Vfx] clip spec "{clip}": {err}`)
		end
	end
end

------------------------------------------------------------------------------
-- Hits
------------------------------------------------------------------------------

-- The spec id of a combat event (see the header).
local function specId(kind: string, attacker: Model, moveId: string?): string?
	if kind == "Hit" or kind == "Finisher" then
		if moveId then
			return moveId
		end
		if kind == "Finisher" then
			return `M1_{#Config.Combat.M1_DAMAGE}`
		end
		local last = CharacterAnimationController.getLastAction(attacker)
		local n = if last then string.match(last, "^Brawler_M1_(%d+)$") else nil
		return `M1_{n or 1}`
	end
	if kind == "Blocked" and moveId and Moves.moves[moveId .. "_Blocked"] then
		return moveId .. "_Blocked"
	end
	return kind
end

local function specFor(id: string): MoveSpec?
	return Moves.moves[id] or DEFAULT_MOVES[id]
end

-- Which hit of the move this is (1 = first), and how many it has.
local function hitIndex(attacker: Model, id: string): (number, number, Kits.HitDef?)
	local info = moveInfo[id]
	local counts = hitCounts[attacker]
	if counts == nil then
		counts = {}
		hitCounts[attacker] = counts
	end
	local counted = (counts[id] or 0) + 1
	counts[id] = counted
	if info == nil then
		return counted, counted, nil
	end
	local hits = info.hits
	if #hits == 1 then
		return 1, 1, hits[1]
	end
	-- The hit whose `at` is nearest to the time since the move's clip started.
	local start = actionStart[attacker]
	if start and info.animation and actionClip[attacker] == info.animation then
		local elapsed = os.clock() - start
		if attacker == player.Character then
			-- Our own move started HERE, but its hits come back from the
			-- server a round trip later: without this, at 150 ms of ping a
			-- jab rush's 1st jab would read as the 2nd (wrong tier).
			elapsed -= player:GetNetworkPing() * 2
		end
		local best, bestGap = 1, math.huge
		for index, hit in hits do
			local gap = math.abs(hit.at - elapsed)
			if gap < bestGap then
				best, bestGap = index, gap
			end
		end
		return best, #hits, hits[best]
	end
	local index = math.min(counted, #hits)
	return index, #hits, hits[index]
end

local function defaultTier(kind: string, hit: Kits.HitDef?): Tier
	if kind == "Finisher" then
		return "Last"
	end
	return if isBig(hit) then "Heavy" else "Clean"
end

local function tierOf(spec: MoveSpec?, kind: string, index: number, hit: Kits.HitDef?): Tier
	if spec then
		local list = spec.tiers
		if list and #list > 0 then
			return list[math.min(index, #list)]
		end
		if spec.tier then
			return spec.tier
		end
	end
	return defaultTier(kind, hit)
end

-- The tier a hit will get (CEC uses it for the hit-stop of its reactions).
function HitFx.tierFor(kind: string, attacker: Model, moveId: string?): Tier
	local id = specId(kind, attacker, moveId)
	local spec = if id then specFor(id) else nil
	local info = if id then moveInfo[id] else nil
	local hit = if info and #info.hits == 1 then info.hits[1] else nil
	return tierOf(spec, kind, 1, hit)
end

local function limbOf(spec: MoveSpec?, index: number, attacker: Model, victim: Model): Types.Limb?
	local limb = if spec then spec.limb else nil
	if typeof(limb) == "table" then
		local list = limb :: { Types.Limb }
		return list[math.min(index, #list)]
	elseif limb ~= nil then
		return limb :: Types.Limb
	end
	-- Guess: the fist / foot nearest the victim.
	local target = victim:GetPivot().Position
	local best: Types.Limb? = nil
	local bestDistance = math.huge
	for _, candidate in { "RightArm", "LeftArm", "RightLeg", "LeftLeg" } :: { Types.Limb } do
		local tip = Limb.tip(attacker, candidate)
		if tip and (tip - target).Magnitude < bestDistance then
			best, bestDistance = candidate, (tip - target).Magnitude
		end
	end
	return best
end

local RING_FACING: { [string]: Vector3 } = { Up = Vector3.yAxis, Down = -Vector3.yAxis }

-- Did THIS hit knock the victim out? (The server knocks out before it
-- sends the hit, so the attribute can arrive just before or just after
-- the event: a knockout within KO_WINDOW seconds of the hit counts.)
local KO_WINDOW = 0.35
local function knockedOutBy(victim: Model, hitAt: number): boolean
	if victim:GetAttribute("KnockedOut") ~= true then
		local humanoid = victim:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil and humanoid.Health <= 0 and downAt[victim] == nil
	end
	local at = downAt[victim]
	return at ~= nil and math.abs(at - hitAt) <= KO_WINDOW
end

-- Runs spec `id` for one hit (the default impact, then its onHit).
local function runHit(
	kind: string,
	id: string,
	victim: Model,
	attacker: Model,
	zone: string,
	side: string,
	blood: boolean,
	predicted: boolean
)
	local spec = specFor(id)
	local index, count, hit = hitIndex(attacker, id)
	local tier = tierOf(spec, kind, index, hit)
	local limb = limbOf(spec, index, attacker, victim)
	local contactZone = if kind == "Blocked" or kind == "Parried" then "Guard" else zone
	local point, dir = Impact.contactPoint(victim, attacker, limb, contactZone)
	local character = player.Character
	local ctx: HitContext = {
		victim = victim,
		attacker = attacker,
		id = id,
		kind = kind,
		zone = zone,
		side = side,
		index = index,
		count = count,
		tier = tier,
		point = point,
		dir = dir,
		blood = blood,
		own = victim == character or attacker == character,
		predicted = predicted,
		hit = hit,
	}
	if spec == nil or spec.noDefault ~= true then
		local facing = if spec and spec.ringFacing then RING_FACING[spec.ringFacing] else nil
		Impact.hit({
			point = point,
			dir = dir,
			tier = tier,
			material = if spec then spec.material else nil,
			ringFacing = facing,
			attacker = attacker,
			victim = victim,
			scale = if spec then spec.scale else nil,
			blood = blood,
		})
	end
	if spec and spec.onHit then
		local ok, err = pcall(spec.onHit :: any, ctx)
		if not ok then
			warn(`[Vfx] move spec "{id}": {err}`)
		end
	end
	-- A body thrown by the hit: dust / a crack where it lands.
	if (kind == "Hit" or kind == "Finisher") and (isBig(hit) or id == "M1_4") then
		local strength = if hit and hit.knockdown then 1 elseif hit and hit.launch then 1.1 else 0.7
		Impact.landing(victim, strength)
	end
	return point, dir, tier
end

-- The killing hit looks different: 3 frames after the hit, if it knocked
-- the victim out, the knockout overlay.
local function checkKnockout(
	victim: Model,
	attacker: Model,
	point: Vector3,
	dir: Vector3,
	tier: Tier,
	spec: MoveSpec?
)
	if tier == "Blocked" then
		return
	end
	-- A spec that draws no impact at all (a choke's squeeze, a beam's
	-- tick): its knockout gets the camera beat only, no flash in the scene.
	local quiet = spec ~= nil and spec.noDefault == true and spec.onHit == nil
	local hitAt = os.clock()
	Pool.afterFrames(3, function()
		if victim.Parent ~= nil and knockedOutBy(victim, hitAt) then
			Impact.knockoutOverlay({
				point = point,
				dir = dir,
				tier = tier,
				attacker = attacker,
				victim = victim,
				skip = if quiet then { flash = true } else nil,
			})
		end
	end)
end

-- Our own M1, the frame our fist lands (before the server answers).
local predictedAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

function HitFx.onPredictedHit(
	victim: Model,
	attacker: Model,
	combo: number,
	zone: string,
	side: string
)
	predictedAt[victim] = os.clock()
	runHit(
		if combo >= #Config.Combat.M1_DAMAGE then "Finisher" else "Hit",
		`M1_{combo}`,
		victim,
		attacker,
		zone,
		side,
		false,
		true
	)
end

-- The server's verdict for one hit (every fighter, every client).
function HitFx.onCombatEvent(
	kind: string,
	victim: Model,
	attacker: Model,
	zone: string,
	side: string,
	moveId: string?,
	alreadyShown: boolean,
	blood: boolean
)
	local id = specId(kind, attacker, moveId)
	if id == nil then
		return
	end
	if alreadyShown then
		-- (our prediction drew it: only the knockout check is left)
		if kind == "Hit" or kind == "Finisher" then
			local point, dir = Impact.contactPoint(victim, attacker, nil, zone)
			local spec = specFor(id)
			checkKnockout(victim, attacker, point, dir, tierOf(spec, kind, 1, nil), spec)
		end
		return
	end
	local point, dir, tier = runHit(kind, id, victim, attacker, zone, side, blood, false)
	if kind == "Hit" or kind == "Finisher" then
		checkKnockout(victim, attacker, point, dir, tier, specFor(id))
	end
end

-- Seconds to wait before starting the blood of a hit so it comes ≈0.1 s
-- after the flash. `predictedAt` = when our prediction flashed (nil: the
-- flash is now).
function HitFx.bloodDelay(predictedAt_: number?): number
	if predictedAt_ == nil then
		return BLOOD_AFTER_FLASH
	end
	return math.max(0, BLOOD_AFTER_FLASH - (os.clock() - predictedAt_))
end

return HitFx
