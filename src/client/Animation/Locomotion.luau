--!strict
-- Locomotion: how a fighter stands, walks, jogs, sprints and crouch-walks
-- (every character, on this client). The animations are the player's Unreal
-- ALS ones (Animation/ALSClips, retargeted onto R6 by tools/anim/als_retarget.py).
-- What makes it fluid instead of "moving in blocks" (see also
-- docs/references/video17.md, the rules of the movement feel):
--
--   • ONE phase per character, advanced by the distance walked, never
--     restarted. Every cycle (Walk / Jog / Sprint / CrouchWalk, in 4
--     directions) is cut so its left foot plants at the same phase (7/16)
--     and the right one half a cycle later, so they all blend into each
--     other (turning, strafing, walk → jog → sprint, standing ↔ crouching)
--     without the legs scissoring or the cycle jumping.
--   • Speed picks the gait: walk (slow: blocking, injured...), jog (normal
--     speed), sprint; the cadence follows the speed (part of it: the rest is
--     longer strides).
--   • An AMPLITUDE instead of an on / off switch: slowing down makes the
--     steps smaller until they fade into the standing pose (ALS stance, with
--     breathing). Stopping lets the current swing finish, then settles.
--   • Direction: the move direction relative to where the body FACES (seen,
--     below), followed as an angle (never through zero). Going the other way
--     at once (W → S) dips through a short neutral instead of flipping.
--   • Springs, not lerps (Spring.luau): speed, amplitude, gait, crouch, lean
--     and turn all follow critically damped springs.
--   • The body leans into its acceleration and banks into turns; the head
--     stays level (the neck takes back part of it).
--   • Turning: the root part can snap round (Roblox's AutoRotate, the
--     shoulder camera); the VISIBLE body follows it with a spring instead
--     (a yaw offset on the root joint; very fast while a move plays, so
--     punches still go where they aim). Visual only: hitboxes and the server
--     keep the root part's facing.
--   • Foot contacts are reported (steps) so footstep effects land exactly
--     when a foot hits the floor.
--
--   Locomotion.new() → State
--   Locomotion.update(state, root, active, busy, crouched, dt)   once per frame
--   Locomotion.sample(state, out)                      the pose (joint → CFrame)
--   state.lag (radians, root joint yaw), state.pitch / state.roll (degrees),
--   state.steps (this frame's foot contacts)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ALSClips = require(script.Parent.ALSClips)
local R6Pose = require(script.Parent.R6Pose)
local Spring = require(script.Parent.Spring)

local WALK_SPEED = Config.Character.WALK_SPEED

-- The gaits: their natural cycle (two steps, seconds) and speed (studs/s:
-- the stride measured on the animation / its cycle), from als_retarget.py.
local WALK_CYCLE, WALK_NATURAL = 1.167, 3.1
local JOG_CYCLE, JOG_NATURAL = 0.833, 7.5
local SPRINT_CYCLE, SPRINT_NATURAL = 0.633, 11
local CROUCH_CYCLE, CROUCH_NATURAL = 1.167, 3
-- Gait by speed (studs/s): walk → jog between JOG_FROM and JOG_TO, jog →
-- sprint between SPRINT_FROM and SPRINT_TO (forward only: sprinting back or
-- sideways keeps the jog, with quicker steps).
local JOG_FROM, JOG_TO = 3.5, 7.5
local SPRINT_FROM, SPRINT_TO = 13, 19
-- Away from a gait's natural speed the cadence follows (speed ratio)^CADENCE,
-- the rest is a longer / shorter stride; within these limits.
local CADENCE = 0.6
local CADENCE_MIN, CADENCE_MAX = 0.6, 1.8
-- Moving above / below these raw speeds (studs/s): a gap, so a speed hovering
-- around one value doesn't flicker.
local MOVE_START = 1
local MOVE_STOP = 0.5
-- Amplitude of the steps by speed (studs/s): none below the first, full from
-- the second (smoothstep between).
local AMP_FROM, AMP_TO = 0.3, 2.2
-- The foot contacts and the passings (feet side by side) in the cycle.
local LEFT_CONTACT, RIGHT_CONTACT = 7 / 16, 15 / 16
local PASSING = 3 / 16 -- (and half a cycle later)
-- Breathing while standing: period (s), torso rise (studs), shoulders (deg).
local BREATH_PERIOD = 3.6
local BREATH_RISE = 0.012
local BREATH_SHOULDERS = 1.2
-- Half-lives (seconds) of the springs.
local SPEED_HALFLIFE = 0.1
local AMP_HALFLIFE = 0.06
local GAIT_HALFLIFE = 0.12
local CROUCH_HALFLIFE = 0.1
local DIRECTION_HALFLIFE = 0.08
local VELOCITY_HALFLIFE = 0.08
local LEAN_HALFLIFE = 0.07
-- A quick change of direction wider than SWING_ANGLE (strafe → backpedal,
-- W → S...) never swaps the clips at full size: the steps dip first (to
-- SWING_WIDE_AMP for SWING_ANGLE, down to SWING_REVERSE_AMP for a reversal
-- at REVERSE_ANGLE and more), the direction swings round only once they are
-- that small, then the steps grow again in the new direction (the reference
-- goes through a short neutral). At least SWING_TIME, at most SWING_MAX.
local SWING_ANGLE = math.rad(50)
local REVERSE_ANGLE = math.rad(120)
local SWING_WIDE_AMP = 0.6
local SWING_REVERSE_AMP = 0.12
local SWING_SLACK = 0.06 -- (swings round once the steps are this close to the dip)
local SWING_TIME = 0.12
local SWING_MAX = 0.45
local SWING_HALFLIFE = 0.07
-- (the swing is over this close to the new direction: the rest is followed
-- as usual while the steps grow back)
local SWING_DONE = math.rad(30)
-- Starting: the phase starts here, just before a passing, so the first step
-- swings through.
local START_PHASE = PASSING - 0.06
-- Stopping: the current swing finishes (until the next passing, at most
-- this long), the steps only fade once it is on its way back.
local STOP_MAX = 0.27
local RETURN_FROM = 5 / 16 -- (of a half cycle, from a passing)
-- Lean (degrees): forward per stud/s of speed, per stud/s² of acceleration,
-- bank per degree/s of turning; and their limits.
local LEAN_PER_SPEED = 0.25
local LEAN_PER_ACCEL = 0.25
local BANK_PER_TURN = 0.0375
local MAX_PITCH = 8
local MAX_ROLL = 6
local MAX_BANK = 5
-- Turning (visible body behind the root part): limit, and half-lives
-- moving / standing / during a move (punch...) / not on its feet.
local LAG_MAX = math.rad(100)
local LAG_BUSY_MAX = math.rad(15) -- (during a move: it leaves where it aims)
local LAG_MOVING = 0.05
local LAG_STANDING = 0.07
local LAG_BUSY = 0.035
local LAG_OFF = 0.03
-- Turning on the spot faster than this (degrees/s): small steps go with it
-- (amplitude per degree/s, at most TURN_STEP_AMP).
local TURN_STEP_RATE = 120
local TURN_STEP_PER = 1 / 1800
local TURN_STEP_AMP = 0.3
-- Moved farther than this in one frame: a teleport, nothing to follow.
local TELEPORT = 8
-- Scuffs (a foot dragging the floor): stopping from this speed, turning
-- faster than this (degrees/s) while moving that fast; not more often.
local SCUFF_SPEED = 6
local SCUFF_TURN = 400
local SCUFF_COOLDOWN = 0.3
-- Foot contacts are reported above this amplitude and speed.
local STEP_AMP = 0.3
local STEP_SPEED = 3

local DIRECTIONS = { "Forward", "Back", "Left", "Right" }
-- Each gait's clip per direction (ALSClips).
local WALK = { Forward = "Walk", Back = "WalkBack", Left = "WalkLeft", Right = "WalkRight" }
local JOG = { Forward = "Jog", Back = "JogBack", Left = "JogLeft", Right = "JogRight" }
local CROUCH = {
	Forward = "CrouchWalk",
	Back = "CrouchWalkBack",
	Left = "CrouchWalkLeft",
	Right = "CrouchWalkRight",
}

export type Foot = "Left" | "Right"
export type Step = {
	foot: Foot,
	strength: number, -- about 0.3 (soft) to 1.6 (sprint)
	scuff: boolean, -- a foot dragging (stop, sharp turn), not a plain step
}

export type State = {
	phase: number, -- 0..1 in the cycle
	cycle: number, -- seconds per cycle, last used
	speed: number, -- smoothed horizontal speed, studs/s
	speedV: number,
	amp: number, -- 0 = standing (Idle), 1 = full steps
	ampV: number,
	jog: number, -- 0 = walk, 1 = jog (or sprint)
	jogV: number,
	sprint: number, -- 0 = jog, 1 = sprint
	sprintV: number,
	crouch: number, -- 0 = standing, 1 = crouched
	crouchV: number,
	angle: number, -- move direction relative to the visible facing (radians, 0 = forward, + = right)
	swinging: number, -- seconds into a direction swing's dip (0 = none)
	swingAmp: number, -- that dip's amplitude
	pendingAngle: number,
	moving: boolean,
	stopTime: number,
	stopHold: boolean, -- stopping: the swing under way finishes first
	settled: boolean, -- stopped on a passing: the phase holds
	wasAnchored: boolean,
	idleTime: number,
	lag: number, -- visible body's yaw behind the root part (radians)
	lagV: number,
	lastYaw: number?,
	lastPosition: Vector3?,
	yawRate: number, -- visible body's turn, degrees/s (+ = to its left)
	velocity: Vector3, -- smoothed planar velocity (its speed term = acceleration)
	velocityV: Vector3,
	pitchA: number, -- lean springs (two in a row each: an S-curve)
	pitchAV: number,
	pitch: number, -- forward lean, degrees (+ = forward)
	pitchV: number,
	rollA: number,
	rollAV: number,
	roll: number, -- side lean, degrees (+ = top to its left)
	rollV: number,
	scuffCooldown: number,
	weights: { [string]: number },
	steps: { Step },
}

local Locomotion = {}

local function wrapAngle(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function smoothstep(from: number, to: number, x: number): number
	local t = math.clamp((x - from) / (to - from), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Did going from phase a to b (b may pass 1) cross `mark`?
local function crossed(a: number, b: number, mark: number): boolean
	return math.floor(b - mark) > math.floor(a - mark)
end

function Locomotion.new(): State
	return {
		phase = 0,
		cycle = WALK_CYCLE,
		speed = 0,
		speedV = 0,
		amp = 0,
		ampV = 0,
		jog = 0,
		jogV = 0,
		sprint = 0,
		sprintV = 0,
		crouch = 0,
		crouchV = 0,
		angle = 0,
		swinging = 0,
		swingAmp = 1,
		pendingAngle = 0,
		moving = false,
		stopTime = 0,
		stopHold = false,
		settled = true,
		wasAnchored = false,
		-- (each fighter breathes at its own moment)
		idleTime = math.random() * 4,
		lag = 0,
		lagV = 0,
		lastYaw = nil,
		lastPosition = nil,
		yawRate = 0,
		velocity = Vector3.zero,
		velocityV = Vector3.zero,
		pitchA = 0,
		pitchAV = 0,
		pitch = 0,
		pitchV = 0,
		rollA = 0,
		rollAV = 0,
		roll = 0,
		rollV = 0,
		scuffCooldown = 0,
		weights = { Forward = 1, Back = 0, Left = 0, Right = 0 },
		steps = {},
	}
end

local function updateWeights(state: State)
	local c, s = math.cos(state.angle), math.sin(state.angle)
	local weights = state.weights
	-- (4th power: the main direction wins fast; a diagonal is mostly the
	-- forward / back clip, as in the reference)
	weights.Forward = math.max(c, 0) ^ 4
	weights.Back = math.max(-c, 0) ^ 4
	weights.Right = math.max(s, 0) ^ 4
	weights.Left = math.max(-s, 0) ^ 4
	local total = weights.Forward + weights.Back + weights.Right + weights.Left
	for _, name in DIRECTIONS do
		weights[name] /= total
	end
end

local function addStep(state: State, foot: Foot, strength: number, scuff: boolean)
	table.insert(state.steps, { foot = foot, strength = strength, scuff = scuff })
end

-- Advances everything by `dt`. `active`: the character is on its feet and
-- our locomotion shows (not in the air, climbing, ragdolled...). `busy`: a
-- move (punch, dash, reaction) is playing. `crouched`: crouching.
function Locomotion.update(
	state: State,
	root: BasePart,
	active: boolean,
	busy: boolean,
	crouched: boolean,
	dt: number
)
	local hitch = dt > 0.1
	dt = math.clamp(dt, 1e-4, 0.1)
	table.clear(state.steps)
	state.idleTime += dt
	state.scuffCooldown = math.max(state.scuffCooldown - dt, 0)

	local cframe = root.CFrame
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local raw = flat.Magnitude

	-- Turning: the visible body follows the root part's facing with a spring.
	local look = cframe.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local position = cframe.Position
	local lastPosition = state.lastPosition
	-- (an anchored root is placed by the server - a grab, a finisher -, and
	-- so is the frame it lets go: a placement, not a turn to follow)
	local anchored = root.Anchored
	local placed = anchored or state.wasAnchored
	state.wasAnchored = anchored
	local jumped = placed
		or (lastPosition ~= nil and (position - lastPosition).Magnitude > TELEPORT)
	local turned = if state.lastYaw and not jumped then wrapAngle(yaw - state.lastYaw) else 0
	local lagPrevious = state.lag
	if jumped then
		state.lag, state.lagV = 0, 0
	elseif active then
		local limit = if busy then LAG_BUSY_MAX else LAG_MAX
		state.lag = math.clamp(state.lag - turned, -limit, limit)
	end
	local halflife = if not active
		then LAG_OFF
		elseif busy then LAG_BUSY
		elseif state.moving then LAG_MOVING
		else LAG_STANDING
	state.lag, state.lagV = Spring.step(state.lag, state.lagV, 0, halflife, dt)
	-- (the visible body's turn this frame: the root's turn plus the change of lag)
	state.yawRate = if jumped
			or hitch
			or state.lastYaw == nil
		then 0
		else math.deg(turned + state.lag - lagPrevious) / dt
	state.lastYaw, state.lastPosition = yaw, position
	local facing = CFrame.Angles(0, yaw + state.lag, 0)

	-- Speed, moving or not, walk / run.
	state.speed, state.speedV = Spring.step(state.speed, state.speedV, raw, SPEED_HALFLIFE, dt)
	state.speed = math.max(state.speed, 0)
	local moving = if state.moving then raw > MOVE_STOP else raw > MOVE_START
	if moving and not state.moving then
		if state.amp < 0.05 then
			state.phase = START_PHASE
		end
	elseif not moving and state.moving and state.speed > SCUFF_SPEED then
		-- (a hard stop: the feet drag)
		addStep(state, if (state.phase - PASSING) % 1 < 0.5 then "Right" else "Left", 1, true)
	end
	state.moving = moving
	-- Gait (walk / jog / sprint) and crouch, by speed.
	state.jog, state.jogV = Spring.step(
		state.jog,
		state.jogV,
		smoothstep(JOG_FROM, JOG_TO, state.speed),
		GAIT_HALFLIFE,
		dt
	)
	state.jog = math.clamp(state.jog, 0, 1)
	state.sprint, state.sprintV = Spring.step(
		state.sprint,
		state.sprintV,
		smoothstep(SPRINT_FROM, SPRINT_TO, state.speed),
		GAIT_HALFLIFE,
		dt
	)
	state.sprint = math.clamp(state.sprint, 0, 1)
	state.crouch, state.crouchV =
		Spring.step(state.crouch, state.crouchV, if crouched then 1 else 0, CROUCH_HALFLIFE, dt)
	state.crouch = math.clamp(state.crouch, 0, 1)

	-- Direction, relative to where the body is SEEN facing.
	if raw > 1.5 then
		local relative = facing:VectorToObjectSpace(flat)
		local angle = math.atan2(relative.X, -relative.Z)
		local delta = wrapAngle(angle - state.angle)
		if state.swinging > 0 then
			state.pendingAngle = angle
		elseif state.amp < 0.05 then
			state.angle = angle -- (starting: no swing round)
		elseif math.abs(delta) > SWING_ANGLE and state.amp > 0.3 then
			state.swinging = 1e-3
			state.pendingAngle = angle
			local wideness =
				math.clamp((math.abs(delta) - SWING_ANGLE) / (REVERSE_ANGLE - SWING_ANGLE), 0, 1)
			state.swingAmp = SWING_WIDE_AMP + (SWING_REVERSE_AMP - SWING_WIDE_AMP) * wideness
		else
			state.angle = wrapAngle(state.angle + delta * (1 - Spring.keep(DIRECTION_HALFLIFE, dt)))
		end
	end
	if state.swinging > 0 then
		state.swinging += dt
		local delta = wrapAngle(state.pendingAngle - state.angle)
		if state.amp <= state.swingAmp + SWING_SLACK or state.swinging > SWING_MAX then
			state.angle = wrapAngle(state.angle + delta * (1 - Spring.keep(SWING_HALFLIFE, dt)))
		end
		if
			(state.swinging >= SWING_TIME and math.abs(delta) < SWING_DONE)
			or state.swinging > SWING_MAX + 0.25
		then
			state.swinging = 0
		end
	end
	updateWeights(state)

	-- Amplitude and phase (with the start / stop rules in the header).
	local ampTarget = if moving then smoothstep(AMP_FROM, AMP_TO, state.speed) else 0
	if state.swinging > 0 then
		ampTarget = math.min(ampTarget, state.swingAmp)
	end
	-- Turning on the spot: small steps with the turn.
	local turning = active and not moving and math.abs(state.yawRate) > TURN_STEP_RATE
	if turning then
		ampTarget = math.min(math.abs(state.yawRate) * TURN_STEP_PER, TURN_STEP_AMP)
		-- (the steps of a turn go forward, whatever the last move was)
		state.swinging = 0
		if state.amp < 0.05 then
			state.angle = 0
		else
			state.angle = wrapAngle(state.angle * Spring.keep(DIRECTION_HALFLIFE, dt))
		end
		updateWeights(state)
	end
	-- (the natural cycle and speed of the gaits showing, blended; sprinting
	-- only forward)
	local sprintShare = state.sprint * state.weights.Forward
	local walkW, jogW = 1 - state.jog, state.jog * (1 - sprintShare)
	local sprintW = state.jog * sprintShare
	local standing = 1 - state.crouch
	local natural = standing
			* (walkW * WALK_NATURAL + jogW * JOG_NATURAL + sprintW * SPRINT_NATURAL)
		+ state.crouch * CROUCH_NATURAL
	local naturalCycle = standing * (walkW * WALK_CYCLE + jogW * JOG_CYCLE + sprintW * SPRINT_CYCLE)
		+ state.crouch * CROUCH_CYCLE
	local cycle = naturalCycle
		/ math.clamp((math.max(state.speed, 0.1) / natural) ^ CADENCE, CADENCE_MIN, CADENCE_MAX)
	local advance = 0
	if moving then
		state.cycle = cycle
		state.stopTime = 0
		state.settled = false
		advance = dt / cycle
	elseif turning then
		state.cycle = WALK_CYCLE
		state.stopTime = 0
		state.settled = false
		advance = dt / WALK_CYCLE
	elseif state.amp > 0.01 and not state.settled then
		-- (phases counted from a passing)
		local before = (state.phase - PASSING) % 1
		if state.stopTime == 0 then
			-- (only a swing already under way finishes, never the next one)
			local into = before % 0.5
			state.stopHold = into >= 2 / 16 and into < RETURN_FROM
		end
		state.stopTime += dt
		local after = before + dt / state.cycle
		local passing = (math.floor(before * 2) + 1) / 2 -- the next one (0.5 or 1)
		if after >= passing or state.stopTime > STOP_MAX then
			state.settled = true
			after = math.min(after, passing)
		end
		advance = after - before
		if state.stopHold and (before % 0.5) < RETURN_FROM and not state.settled then
			ampTarget = state.amp -- (the swing goes on until it comes back)
		end
	end
	if advance > 0 and state.amp > STEP_AMP and state.speed > STEP_SPEED then
		local strength = state.amp * (1 + 0.6 * state.sprint) * (1 - 0.4 * state.crouch)
		local before, after = state.phase, state.phase + advance
		if crossed(before, after, LEFT_CONTACT) then
			addStep(state, "Left", strength, false)
		end
		if crossed(before, after, RIGHT_CONTACT) then
			addStep(state, "Right", strength, false)
		end
	end
	state.phase = (state.phase + advance) % 1
	state.amp, state.ampV = Spring.step(state.amp, state.ampV, ampTarget, AMP_HALFLIFE, dt)
	state.amp = math.clamp(state.amp, 0, 1)

	-- Sharp turn at speed: a scuff.
	if
		active
		and moving
		and state.speed > SCUFF_SPEED
		and math.abs(state.yawRate) > SCUFF_TURN
		and state.scuffCooldown <= 0
	then
		state.scuffCooldown = SCUFF_COOLDOWN
		addStep(state, if state.yawRate > 0 then "Right" else "Left", 0.8, true)
	end

	-- Lean into the acceleration, bank into the turn (degrees).
	state.velocity, state.velocityV =
		Spring.step3(state.velocity, state.velocityV, flat, VELOCITY_HALFLIFE, dt)
	local pitchTarget, rollTarget = 0, 0
	if active then
		local relative = facing:VectorToObjectSpace(state.velocity)
		local accel = facing:VectorToObjectSpace(state.velocityV)
		local forward = math.clamp(-relative.Z, -WALK_SPEED, WALK_SPEED)
		pitchTarget =
			math.clamp(LEAN_PER_SPEED * forward - LEAN_PER_ACCEL * accel.Z, -MAX_PITCH, MAX_PITCH)
		local bank = math.clamp(
			BANK_PER_TURN * state.yawRate * math.min(state.speed / WALK_SPEED, 1),
			-MAX_BANK,
			MAX_BANK
		)
		rollTarget = math.clamp(bank - LEAN_PER_ACCEL * accel.X, -MAX_ROLL, MAX_ROLL)
	end
	state.pitchA, state.pitchAV =
		Spring.step(state.pitchA, state.pitchAV, pitchTarget, LEAN_HALFLIFE, dt)
	state.pitch, state.pitchV =
		Spring.step(state.pitch, state.pitchV, state.pitchA, LEAN_HALFLIFE, dt)
	state.rollA, state.rollAV =
		Spring.step(state.rollA, state.rollAV, rollTarget, LEAN_HALFLIFE, dt)
	state.roll, state.rollV = Spring.step(state.roll, state.rollV, state.rollA, LEAN_HALFLIFE, dt)
end

-- Reused every frame (no table created per frame).
local poses: { [string]: { [string]: CFrame } } = {}
local function scratch(name: string): { [string]: CFrame }
	local pose = poses[name]
	if pose == nil then
		pose = {}
		poses[name] = pose
	end
	return pose
end
local mix: { [string]: CFrame } = {}
local mixSum = 0

-- Adds one clip at the shared phase to the running weighted average.
local function addClip(name: string, weight: number, phase: number)
	if weight <= 0.005 then
		return
	end
	local pose = scratch(name)
	R6Pose.sample((ALSClips :: any)[name] :: R6Pose.Clip, phase, pose)
	mixSum += weight
	for joint, cframe in pose do
		local before = mix[joint]
		-- (this clip's share of what's been mixed so far)
		mix[joint] = if before then before:Lerp(cframe, weight / mixSum) else cframe
	end
end

-- This frame's pose (joint → CFrame in parent space, as R6Pose.sample)
-- written into `out`: the gaits' clips at the shared phase mixed by
-- direction, gait and crouch, scaled from the standing pose by the amplitude.
function Locomotion.sample(state: State, out: { [string]: CFrame })
	table.clear(out)
	-- Standing (or crouched), breathing.
	local stand = scratch("Stand")
	R6Pose.sample(ALSClips.Stand, 0, stand)
	local crouch = state.crouch
	if crouch > 0.005 then
		local low = scratch("Crouch")
		R6Pose.sample(ALSClips.Crouch, 0, low)
		for joint, cframe in stand do
			local crouched = low[joint]
			if crouched then
				stand[joint] = cframe:Lerp(crouched, crouch)
			end
		end
	end
	local breath = (1 - math.cos(state.idleTime * 2 * math.pi / BREATH_PERIOD)) / 2
	local rise = CFrame.new(0, breath * BREATH_RISE, 0)
	local open = math.rad(breath * BREATH_SHOULDERS)
	if stand.Root then
		stand.Root = rise * stand.Root
	end
	if stand.RightShoulder then
		stand.RightShoulder = CFrame.Angles(0, 0, open) * stand.RightShoulder
	end
	if stand.LeftShoulder then
		stand.LeftShoulder = CFrame.Angles(0, 0, -open) * stand.LeftShoulder
	end
	local amp = state.amp
	if amp <= 1e-3 then
		for joint, cframe in stand do
			out[joint] = cframe
		end
		return
	end
	table.clear(mix)
	mixSum = 0
	local phase = state.phase
	local standing = 1 - crouch
	local sprintShare = state.sprint * state.weights.Forward
	for _, direction in DIRECTIONS do
		local weight = state.weights[direction]
		if weight > 0.005 then
			addClip(WALK[direction], weight * standing * (1 - state.jog), phase)
			-- (sprinting only forward: the other directions keep the jog)
			local jogShare = if direction == "Forward" then 1 - sprintShare else 1
			addClip(JOG[direction], weight * standing * state.jog * jogShare, phase)
			if direction == "Forward" then
				addClip("Sprint", weight * standing * state.jog * sprintShare, phase)
			end
			addClip(CROUCH[direction], weight * crouch, phase)
		end
	end
	for joint, still in stand do
		local moving = mix[joint]
		out[joint] = if moving then still:Lerp(moving, amp) else still
	end
end

return Locomotion
