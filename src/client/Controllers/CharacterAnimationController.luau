--!strict
-- CharacterAnimationController: plays our code-made animations
-- (Client/Animation/MovementClips and CombatClips) on EVERY fighter
-- (players and training dummies), on this client.
--
-- Why every client animates every character: a Motor6D.Transform written by
-- a script is NOT sent over the network. So each client poses all characters
-- itself, from information that IS shared:
--   • the "MoveState" attribute the server sets on each Player (crouch,
--     slide, climb...) — for our own character: ParkourController, instant;
--   • the "Blocking" / "Stunned" attributes on each fighter's model;
--   • one-shot actions (punches, dashes, hit reactions) that controllers
--     start with CharacterAnimationController.playAction().
--
-- Standing, walking (4 directions) and running are Animation/Locomotion:
-- one phase per character driven by the distance walked, the clips blended
-- on it by direction and speed, steps that grow / shrink with the speed,
-- springs for the lean, the bank into turns and the body's turn itself (see
-- its header). It is the base layer whenever the character is on its feet,
-- so Roblox's own walk / idle never show through.
--
-- Then three channels, blended in this order (later ones win on the joints
-- they use):
--   1. movement  crouch, limp, slide, climb, the Bull's run...
--   2. stance    guard, block, stunned        (loops, upper body)
--   3. action    punch, dash, hit reaction... (plays once)
--
-- Transitions: switching what the BODY does (on its feet ↔ in the air, walk
-- ↔ crouch / slide / climb...) is "inertialized": the new pose starts at
-- once, and the difference with what was shown (and its motion) melts away
-- with a spring in a few hundredths of a second. No pose is ever shown
-- half-mixed with another, nothing pops. Stances fade with an ease in / out.
--
-- What makes the fights feel fluid and heavy:
--   • Clips are sampled with a spline (R6Pose): motion flows through keyframes.
--   • Combat guard: after a punch or a hit, the fighter keeps its fists up for
--     a few seconds, so punches start from and return to a fighting stance
--     instead of arms hanging down.
--   • Hit-stop: when a punch lands, attacker and victim freeze for a few
--     hundredths of a second. That tiny pause is what sells the impact.
--   • Flinch spring: a hit also kicks a small physical spring on the head and
--     torso, added on top of the animation, so no two hits look identical.
--
-- Each frame, right after Roblox's Animator has posed the body (its jump /
-- fall / swim / climb animations still play in the air), we write ours: on
-- its feet the locomotion replaces Roblox's pose entirely, then each channel
-- is blended on top (final = below:Lerp(clip, weight)). Joints a clip
-- doesn't list keep what's below (e.g. legs keep walking while you block).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ALSClips = require(script.Parent.Parent.Animation.ALSClips)
local CarryClips = require(script.Parent.Parent.Animation.CarryClips)
local CombatClips = require(script.Parent.Parent.Animation.CombatClips)
local Locomotion = require(script.Parent.Parent.Animation.Locomotion)
local MovementClips = require(script.Parent.Parent.Animation.MovementClips)
local R6Pose = require(script.Parent.Parent.Animation.R6Pose)
local Footsteps = require(script.Parent.Parent.Combat.Footsteps)
local ParkourController = require(script.Parent.ParkourController)

local player = Players.LocalPlayer

-- Seconds to fade a stance clip in / out, per clip (default otherwise).
local DEFAULT_FADE = 0.2
local FADE_IN: { [string]: number } = {
	Block = 0.08,
	Stunned = 0.12,
	Guard = 0.12,
	-- Injuries: the tired posture settles in slowly.
	HurtGuard = 0.3,
	HurtIdle = 0.4,
}
-- Inertialization (see the header): half-life (seconds) of the difference
-- melting away when the movement switches to this clip (default otherwise);
-- and when the body gets on / off its feet.
local DEFAULT_INERTIA = 0.1
local INERTIA: { [string]: number } = {
	Climb = 0.05,
	Vault = 0.05,
	Slide = 0.08,
	LimpWalk = 0.12,
	LimpWalkLeft = 0.12,
	LimpIdle = 0.15,
	LimpIdleLeft = 0.15,
}
local FEET_INERTIA = 0.08
-- (an inertialized difference is dropped below these: degrees, studs)
local INERTIA_DONE_ANGLE = math.rad(0.2)
local INERTIA_DONE_MOVE = 0.005
-- The difference's starting speed is the old pose's own, at most this
-- (degrees / studs per second): a reasonable push, never a fling.
local INERTIA_MAX_TURN = math.rad(600)
local INERTIA_MAX_MOVE = 6
-- Seconds to fade a looping clip out (default otherwise): the guard is
-- lowered slowly when the fight is over.
local FADE_OUT: { [string]: number } = { Guard = 0.5 }
-- A fighter keeps its guard up this long after its last punch / hit taken.
local COMBAT_STANCE_TIME = 3.5
-- Flinch spring (see the header): stiffness and damping. Higher stiffness =
-- faster wobble; higher damping = it dies out sooner.
local FLINCH_STIFFNESS = 190
local FLINCH_DAMPING = 15
-- How much of the head's flinch the torso takes.
local FLINCH_TORSO_SHARE = 0.35
-- Physics step is capped so a lag spike can't make the spring explode.
local MAX_SPRING_STEP = 1 / 30
-- One-shot actions: fast in (a punch must start NOW), smooth out.
local ACTION_FADE_IN = 0.05
-- Hit reactions start a bit softer: the body goes from a high guard to the
-- reaction pose, too far to jump there in 3 frames without a visible pop.
local REACTION_FADE_IN = 0.08
local REACTIONS = table.freeze({
	HitJab = true,
	HitCross = true,
	HitHook = true,
	HitBody = true,
	HitBodyFront = true,
	HitBodyBack = true,
	HitBodyLeft = true,
	HitBodyRight = true,
	HitHeavy = true,
	HitBack = true,
	HitLeg = true,
	HitLiver = true,
	GetUp = true,
})
local ACTION_FADE_OUT = 0.12
-- "Climb" and "Vault" clips are written with times from 0 to 1 and stretched
-- to the real duration. For OTHER players we don't know the exact duration
-- of a mantle (it depends on the ledge's height): we use the average.
local AVERAGE_MANTLE_DURATION = (Config.Climb.MANTLE_MIN_DURATION + Config.Climb.MAX_DURATION) / 2
-- Speed (studs/s) above which a character counts as moving.
local MOVING_SPEED = 1
-- Crouch idle ↔ walk switch with a gap ("hysteresis"), so a speed hovering
-- around one value doesn't flicker between the two clips.
-- The Bull's run (studs per second): from RUN_START_SPEED, back to the
-- normal locomotion under RUN_STOP_SPEED.
local RUN_START_SPEED = 14
local RUN_STOP_SPEED = 12
local CROUCH_WALK_START = 1.5
local CROUCH_WALK_STOP = 0.5
-- In the air: falling faster than this (studs/s, down) flails (FallFast),
-- back to the plain fall loop above FALL_FAST_STOP.
local FALL_FAST_START = -55
local FALL_FAST_STOP = -45
-- Landing (ALSClips): falling this much faster (studs/s) than a plain jump
-- comes down, a light / heavy landing plays; only when landing (nearly) on
-- the spot (moving on, the steps just carry on), and not over a guard, a
-- block, a stun or a crouch.
local LAND_LIGHT_MARGIN = 15
local LAND_HEAVY_MARGIN = 35
local LAND_MAX_RUN = 6
local LANDINGS = table.freeze({ LandLight = true, LandHeavy = true })
-- Limp clips, by the hurt leg (the "LimpLeg" attribute; written for the
-- right one, mirrored for the left).
local LIMP_WALK: { [string]: string } = table.freeze({ Right = "LimpWalk", Left = "LimpWalkLeft" })
local LIMP_IDLE: { [string]: string } = table.freeze({ Right = "LimpIdle", Left = "LimpIdleLeft" })
local LIMP_CLIPS: { [string]: boolean } = table.freeze({
	LimpWalk = true,
	LimpWalkLeft = true,
	LimpIdle = true,
	LimpIdleLeft = true,
})
-- The limp walk is authored for this speed (studs/s): walking, slowed by the limp.
local LIMP_WALK_SPEED = Config.Character.WALK_SPEED * Config.Injuries.LIMP_SPEED
-- The head takes back this much of the locomotion's lean (it stays level).
local HEAD_STEADY = 0.6
-- Characters farther than this from the camera aren't animated by us
-- (too far to see the difference, saves work with 16 players).
local MAX_DISTANCE = 200

type Layer = {
	name: string,
	clip: R6Pose.Clip,
	time: number,
	weight: number,
	target: number, -- 1 = fading in / playing, 0 = fading out
	fadeIn: number,
	fadeOut: number,
	pose: { [string]: CFrame }, -- sampled each frame (reused table)
	warp: Warp?, -- a re-timed clip (the right cross thrown for a left punch, see playAction)
}

-- A clip re-timed around its impact ("marker"): real time 0..impactReal plays clip time
-- 0..impactClip, then impactReal..endReal plays the rest of the clip. So the fist lands on
-- the server's hit time AND the recovery ends when the next click may come, instead of one
-- speed-up compressing the whole clip, recovery included.
type Warp = { impactClip: number, impactReal: number, endReal: number, elapsed: number }

-- One channel = a list of layers (the newest is the one playing; older ones
-- are fading out).
type Channel = { Layer }

-- A difference melting away on one joint (inertialization): rotation as an
-- axis × angle vector (radians) and position (studs), their speeds, since when.
type Inertia = {
	turn: Vector3,
	turnSpeed: Vector3,
	move: Vector3,
	moveSpeed: Vector3,
	time: number,
	halflife: number,
}

type Tracked = {
	player: Player?, -- nil for training dummies
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	motors: { [string]: Motor6D },
	movement: Channel,
	stance: Channel,
	action: Channel,
	sprintWeight: number,
	-- Standing / walking / running (Animation/Locomotion), and whether it
	-- shows (on its feet) this frame.
	loco: Locomotion.State,
	locoActive: boolean,
	locoPose: { [string]: CFrame }, -- sampled each frame (reused table)
	-- Inertialization (see the header): per joint, what was written the two
	-- last frames, the difference still melting away, and a switch waiting
	-- for this frame's compose (its half-life).
	inertia: { [Motor6D]: Inertia },
	prevOut: { [Motor6D]: CFrame },
	prevPrevOut: { [Motor6D]: CFrame },
	pendingInertia: number?,
	lastDt: number,
	freefallSince: number?, -- os.clock() when its current free fall began
	fallSpeed: number, -- fastest downward speed of the current time in the air (studs/s, < 0)
	-- Combat feel (see the header).
	combatUntil: number, -- os.clock() until which the guard stays up
	freezeUntil: number, -- hit-stop: the action clip is paused until then
	lastAction: string?, -- last one-shot clip asked for (which punch of the combo)
	lastShown: string?, -- the clip it really showed (a left punch thrown as a right cross)
	flinch: Vector3, -- spring position: extra head rotation, degrees
	flinchSpeed: Vector3, -- spring speed, degrees per second
	-- To know if Roblox's Animator rewrote a joint this frame (see compose()).
	lastWritten: { [Motor6D]: CFrame },
	lastBase: { [Motor6D]: CFrame },
}

local CharacterAnimationController = {}

-- A hold pose (setHoldPose): something held in a hand that keeps an arm in place whatever
-- the body does (the BX-7 case in the left hand). Poses are R6Pose poses (parent space).
--   leftShoulder  REPLACES the Left Shoulder's pose (on top of the locomotion, guard,
--                 punches...), weighted by `weight`;
--   root          is ADDED on top of the Root joint (a small tilt), weighted too.
export type HoldPose = { leftShoulder: CFrame?, root: CFrame?, weight: number }
-- Called once per frame per character while set: (frame time, its locomotion state, on its
-- feet or not) → the pose, or nil for nothing this frame.
export type HoldProvider = (dt: number, loco: Locomotion.State, onFeet: boolean) -> HoldPose?

local tracked: { [Model]: Tracked } = {}
-- We pressed block: show it before the server's "Blocking" attribute arrives.
local predictedBlock = false
-- Reused every frame (no table created per frame).
local sprintPose: { [string]: CFrame } = {}
-- Bodies held at a place of their own (pinRoot): where the torso's centre
-- is this frame (world), or nil once it's over.
local pins: { [Model]: () -> Vector3? } = setmetatable({}, { __mode = "k" }) :: any
-- Left-hand punches (clip name → combo hit) and the right-hand one used instead while the
-- left hand holds something.
local LEFT_HAND_PUNCHES: { [string]: number } = { Brawler_M1_1 = 1, Brawler_M1_3 = 3 }
local RIGHT_HAND_PUNCH = "Brawler_M1_2"
-- Hold poses (setHoldPose), per model.
local holds: { [Model]: HoldProvider } = setmetatable({}, { __mode = "k" }) :: any

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local isLimping: (entry: Tracked) -> boolean -- defined below (compose)

local function horizontalSpeed(root: BasePart): number
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function isLocal(entry: Tracked): boolean
	return entry.player ~= nil and entry.player == player
end

local function findClip(name: string): R6Pose.Clip?
	return (MovementClips :: any)[name]
		or (CombatClips :: any)[name]
		or (ALSClips :: any)[name]
		or (CarryClips :: any)[name]
end

local function newLayer(name: string, clip: R6Pose.Clip, fadeIn: number, fadeOut: number): Layer
	return {
		name = name,
		clip = clip,
		time = 0,
		weight = 0,
		target = 1,
		fadeIn = fadeIn,
		fadeOut = fadeOut,
		pose = {},
	}
end

-- Makes `name` the clip playing on a looping channel (nil = none).
local function setChannelClip(channel: Channel, name: string?)
	local current = channel[#channel]
	if current and current.target == 1 and current.name == name then
		return -- already playing
	end
	for _, layer in channel do
		layer.target = 0 -- fade out whatever is playing
	end
	local clip = if name then findClip(name) else nil
	if name and clip then
		local fadeIn = FADE_IN[name] or DEFAULT_FADE
		local fadeOut = FADE_OUT[name] or DEFAULT_FADE
		table.insert(channel, newLayer(name, clip, fadeIn, fadeOut))
	end
end

-- Asks for an inertialized switch on this character this frame (see the
-- header); the fastest asked wins.
local function requestInertia(entry: Tracked, halflife: number)
	local pending = entry.pendingInertia
	entry.pendingInertia = if pending then math.min(pending, halflife) else halflife
end

-- Makes `name` the movement clip (nil = none: the locomotion shows). The new
-- one is at full weight at once and the switch is inertialized.
local function setMovementClip(entry: Tracked, name: string?)
	local channel = entry.movement
	local current = channel[#channel]
	if (current and current.name) == name then
		return -- already playing
	end
	local clip = if name then findClip(name) else nil
	if name ~= nil and clip == nil then
		return
	end
	table.clear(channel)
	if name and clip then
		local layer = newLayer(name, clip, DEFAULT_FADE, DEFAULT_FADE)
		layer.weight = 1
		table.insert(channel, layer)
	end
	requestInertia(entry, if name then INERTIA[name] or DEFAULT_INERTIA else DEFAULT_INERTIA)
end

------------------------------------------------------------------------------
-- Choosing the clips
------------------------------------------------------------------------------

-- Which movement state to show for this character.
local function movementState(entry: Tracked): string?
	local owner = entry.player
	if owner == nil then
		return nil -- dummies don't crouch or climb
	end
	if owner == player then
		return ParkourController.getVisualState()
	end
	local state = owner:GetAttribute("MoveState")
	return if typeof(state) == "string" then state else nil
end

-- Moves that use the arms (and during which nobody can fight): no stance
-- on top of them, or the guard would keep the fists up while climbing.
local ARM_MOVES = table.freeze({ Slide = true, Climb = true, Vault = true })

-- Movement clip for this state, nil = none (the locomotion shows: standing,
-- walking, running, crouching). A limping fighter (legs injured) walks and
-- stands on its good leg. In the air: the ALS jump / fall loops.
local function movementClip(entry: Tracked, state: string?, feet: boolean): string?
	-- (swimming, climbing a ladder or sitting keep Roblox's own animations)
	local humanoidState = entry.humanoid:GetState()
	if
		not feet
		and not (state and ARM_MOVES[state])
		and (
			humanoidState == Enum.HumanoidStateType.Jumping
			or humanoidState == Enum.HumanoidStateType.Freefall
		)
	then
		local current = entry.movement[#entry.movement]
		local fall = entry.root.AssemblyLinearVelocity.Y
		if humanoidState == Enum.HumanoidStateType.Jumping or fall > 0 then
			return "JumpLoop"
		end
		-- (falling fast: the flailing loop, with a gap so it doesn't flicker)
		local fast = current ~= nil and current.name == "FallFast"
		return if fall < (if fast then FALL_FAST_STOP else FALL_FAST_START)
			then "FallFast"
			else "FallLoop"
	end
	local onGround = humanoidState == Enum.HumanoidStateType.Running
		or humanoidState == Enum.HumanoidStateType.RunningNoPhysics
	if
		(state == nil or state == "Walk")
		and onGround
		and entry.model:GetAttribute("Limping") == true
	then
		local side = if entry.model:GetAttribute("LimpLeg") == "Left" then "Left" else "Right"
		local walkClip = LIMP_WALK[side]
		local current = entry.movement[#entry.movement]
		local walking = current ~= nil and current.target == 1 and current.name == walkClip
		local threshold = if walking then CROUCH_WALK_STOP else CROUCH_WALK_START
		return if horizontalSpeed(entry.root) > threshold then walkClip else LIMP_IDLE[side]
	end
	if state == "Crouch" then
		return nil -- (the locomotion crouches)
	elseif state == "Slide" or state == "Climb" or state == "Vault" then
		return state
	elseif state == nil or state == "Walk" or state == "Sprint" then
		-- Standing up (our own state is nil, the others' "Walk" / "Sprint"
		-- from the server): the locomotion (stand / walk / run) shows,
		-- except the Bull's sprint (head down, horns first), on the ground,
		-- with a gap between the two speeds ("hysteresis") so a speed
		-- hovering around one value doesn't flicker between the two.
		if entry.model:GetAttribute("Kit") ~= "Bull" or not onGround then
			return nil
		end
		local current = entry.movement[#entry.movement]
		local running = current ~= nil and current.name == "BullRun"
		local speed = horizontalSpeed(entry.root)
		return if speed > (if running then RUN_STOP_SPEED else RUN_START_SPEED)
			then "BullRun"
			else nil
	end
	return nil
end

-- Stance clip from the fighter's attributes. Stunned wins over blocking.
local function stanceClip(entry: Tracked, state: string?): string?
	if state and ARM_MOVES[state] then
		-- Climbing / sliding ends the fighting posture: it doesn't come back
		-- when the move is over.
		entry.combatUntil = 0
		return nil
	end
	local model = entry.model
	if model:GetAttribute("Stunned") == true then
		return "Stunned"
	end
	if model:GetAttribute("Blocking") == true or (isLocal(entry) and predictedBlock) then
		return "Block"
	end
	-- Low health (step 5): a tired, lower guard in a fight, a hunched,
	-- hurting posture otherwise.
	local health = entry.humanoid.Health
	local hurt = health > 0
		and health < Config.Injuries.LOW_HEALTH
		and model:GetAttribute("KnockedOut") ~= true
	if os.clock() < entry.combatUntil then
		-- Still in a fight: fists up.
		return if hurt then "HurtGuard" else "Guard"
	end
	return if hurt then "HurtIdle" else nil
end

-- Playback speed of a clip.
local function playbackRate(entry: Tracked, name: string): number
	if name == "LimpWalk" or name == "LimpWalkLeft" then
		-- The steps follow the real speed, down to a crawl (limping while
		-- blocking or stunned is 2-4 studs/s): a high floor would make the
		-- feet slide.
		return math.clamp(horizontalSpeed(entry.root) / LIMP_WALK_SPEED, 0.3, 1.5)
	elseif name == "CrouchWalk" then
		-- The legs follow the real walking speed (no foot sliding).
		return math.clamp(horizontalSpeed(entry.root) / Config.Character.CROUCH_SPEED, 0.6, 1.8)
	elseif name == "BullRun" then
		-- (authored for the Bull's sprint: faster than everyone's)
		return math.clamp(
			horizontalSpeed(entry.root) / (Config.Character.SPRINT_SPEED * 1.15) * 1.35,
			0.8,
			1.6
		)
	elseif name == "Vault" then
		return 1 / Config.Climb.VAULT_DURATION
	elseif name == "Climb" then
		return 1 / AVERAGE_MANTLE_DURATION
	end
	return 1
end

------------------------------------------------------------------------------
-- Layers (time + fade in / out)
------------------------------------------------------------------------------

local function advanceChannel(entry: Tracked, channel: Channel, dt: number, oneShot: boolean)
	-- Hit-stop: one-shot clips (the punch, the reaction) pause for an instant.
	-- EVERYTHING pauses, blending included: a reaction that just started
	-- stays at weight 0, so during the stop the victim is still in the pose
	-- it had when the fist touched it (the "contact frame"), and only THEN
	-- reacts. Without this the body would already slide away from the fist
	-- during the stop, which looks like a dodge.
	local frozen = oneShot and os.clock() < entry.freezeUntil
	if frozen then
		return
	end
	for index = #channel, 1, -1 do
		local layer = channel[index]
		local warp = layer.warp
		if warp then
			warp.elapsed += dt
			local real = warp.elapsed
			if real <= warp.impactReal then
				layer.time = real * warp.impactClip / warp.impactReal
			else
				local after = (layer.clip.length - warp.impactClip)
					/ (warp.endReal - warp.impactReal)
				layer.time = warp.impactClip + (real - warp.impactReal) * after
			end
		else
			layer.time += dt * playbackRate(entry, layer.name)
		end

		-- Our own climb / vault: follow the body's real progress exactly.
		if layer.target == 1 and isLocal(entry) then
			local progress = ParkourController.getClimbProgress()
			if progress and (layer.name == "Climb" or layer.name == "Vault") then
				layer.time = progress
			end
		end
		-- A one-shot clip starts fading out just before its end.
		if oneShot and layer.time >= layer.clip.length - layer.fadeOut then
			layer.target = 0
		end

		local step = dt / (if layer.target == 1 then layer.fadeIn else layer.fadeOut)
		if layer.weight < layer.target then
			layer.weight = math.min(layer.target, layer.weight + step)
		else
			layer.weight = math.max(layer.target, layer.weight - step)
		end
		if layer.target == 0 and layer.weight <= 0 then
			table.remove(channel, index)
		end
	end
end

------------------------------------------------------------------------------
-- Writing the joints
------------------------------------------------------------------------------

local function sampleChannel(channel: Channel)
	for _, layer in channel do
		R6Pose.sample(layer.clip, layer.time, layer.pose)
	end
end

-- Ease in / out of a fade (no sudden start or stop of the blend).
local function eased(weight: number): number
	return weight * weight * (3 - 2 * weight)
end

local function blendChannel(
	channel: Channel,
	motor: Motor6D,
	joint: string,
	result: CFrame,
	keepHeight: Vector3?, -- Root only: the crouch's drop, for upper-body clips
	smooth: boolean? -- ease the fades in / out
): (CFrame, boolean)
	local touched = false
	for _, layer in channel do
		local localPose = layer.pose[joint]
		if localPose and layer.weight > 0 then
			local target = R6Pose.toTransform(motor, localPose)
			-- An upper-body clip (guard, block, hit reaction: a Root but no
			-- legs) keeps the height below it: crouched, the pelvis stays down
			-- (the legs under it stay bent to match). Otherwise the pelvis
			-- went back up while the legs stayed folded: feet in the air.
			local legs = layer.pose :: { [string]: CFrame? }
			if keepHeight and legs.RightHip == nil and legs.LeftHip == nil then
				target += keepHeight
			end
			result = result:Lerp(target, if smooth then eased(layer.weight) else layer.weight)
			touched = true
		end
	end
	return result, touched
end

-- A limp clip is playing (or fading in) on the movement channel.
isLimping = function(entry: Tracked): boolean
	local current = entry.movement[#entry.movement]
	return current ~= nil and current.target == 1 and LIMP_CLIPS[current.name] == true
end

-- Damped spring pulling the flinch back to zero (the head wobbles and settles).
local function updateFlinch(entry: Tracked, dt: number)
	if entry.flinch.Magnitude < 0.02 and entry.flinchSpeed.Magnitude < 0.5 then
		entry.flinch = Vector3.zero
		entry.flinchSpeed = Vector3.zero
		return
	end
	local step = math.min(dt, MAX_SPRING_STEP)
	local acceleration = entry.flinch * -FLINCH_STIFFNESS - entry.flinchSpeed * FLINCH_DAMPING
	entry.flinchSpeed += acceleration * step
	entry.flinch += entry.flinchSpeed * step
end

local function flinchRotation(flinch: Vector3, share: number): CFrame
	return CFrame.Angles(
		math.rad(flinch.X * share),
		math.rad(flinch.Y * share),
		math.rad(flinch.Z * share)
	)
end

-- Inertialization helpers: a rotation as an axis × angle vector and back.
local function turnVector(rotation: CFrame): Vector3
	local axis, angle = rotation:ToAxisAngle()
	if angle > math.pi then
		angle -= 2 * math.pi
	end
	if angle ~= angle or axis.Magnitude < 1e-6 then
		return Vector3.zero
	end
	return axis.Unit * angle
end

local function turnFrom(vector: Vector3): CFrame
	local angle = vector.Magnitude
	if angle < 1e-7 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(vector / angle, angle)
end

local function capped(vector: Vector3, limit: number): Vector3
	local size = vector.Magnitude
	return if size > limit then vector * (limit / size) else vector
end

-- A switch on this joint: the difference between what was shown last frame
-- and the new pose (`result`), and the old pose's motion, to melt away.
local function startInertia(entry: Tracked, motor: Motor6D, result: CFrame, halflife: number)
	local previous: CFrame? = entry.prevOut[motor]
	if not previous then
		return
	end
	local offset = previous * result:Inverse() -- (previous = offset · result)
	local turnSpeed, moveSpeed = Vector3.zero, Vector3.zero
	local older: CFrame? = entry.prevPrevOut[motor]
	if older and entry.lastDt > 0 then
		local step = previous * older:Inverse()
		turnSpeed = capped(turnVector(step.Rotation) / entry.lastDt, INERTIA_MAX_TURN)
		moveSpeed = capped(step.Position / entry.lastDt, INERTIA_MAX_MOVE)
	end
	entry.inertia[motor] = {
		turn = turnVector(offset.Rotation),
		turnSpeed = turnSpeed,
		move = offset.Position,
		moveSpeed = moveSpeed,
		time = 0,
		halflife = halflife,
	}
end

-- The difference left on `result` this frame (a critically damped spring
-- from the difference and its speed to nothing), or nil once it's gone.
local function applyInertia(inertia: Inertia, result: CFrame, dt: number): CFrame?
	inertia.time += dt
	local t = inertia.time
	local y = 2 * math.log(2) / inertia.halflife
	local decay = math.exp(-y * t)
	local turn = (inertia.turn + (inertia.turnSpeed + inertia.turn * y) * t) * decay
	local move = (inertia.move + (inertia.moveSpeed + inertia.move * y) * t) * decay
	if
		t > inertia.halflife
		and turn.Magnitude < INERTIA_DONE_ANGLE
		and move.Magnitude < INERTIA_DONE_MOVE
	then
		return nil
	end
	return CFrame.new(move) * turnFrom(turn) * result
end

local function compose(entry: Tracked, dt: number)
	sampleChannel(entry.movement)
	sampleChannel(entry.stance)
	sampleChannel(entry.action)
	local loco = entry.loco
	local feet = entry.locoActive
	if feet then
		Locomotion.sample(loco, entry.locoPose)
	end
	-- (the locomotion's own lean only shows when it's what the legs do, not
	-- under a crouch / limp / slide clip)
	local lean = feet and #entry.movement == 0
	local sprint = entry.sprintWeight
	if sprint > 0 then
		R6Pose.sample(MovementClips.SprintLean, 0, sprintPose)
	end
	local pending = entry.pendingInertia
	entry.pendingInertia = nil
	-- Something held in a hand (setHoldPose): asked once per frame.
	local holdProvider = holds[entry.model]
	local hold = if holdProvider then holdProvider(dt, loco, feet) else nil

	for joint, motor in entry.motors do
		-- What Roblox's Animator wants this frame. If the joint still holds
		-- exactly what WE wrote last frame, the Animator didn't touch it:
		-- reuse the base we had, otherwise our pose would pile up frame after frame.
		local current = motor.Transform
		local written = entry.lastWritten[motor]
		local base = if written and current == written
			then entry.lastBase[motor] or current
			else current

		local result = base
		local touched, any = false, false
		-- On its feet: the locomotion is the base (Roblox's walk / idle never show).
		local locoPose = if feet then entry.locoPose[joint] else nil
		if locoPose then
			result = R6Pose.toTransform(motor, locoPose)
			any = true
		end
		-- (the crouch's drop / the steps' bob, worked out afresh each frame
		-- from the legs' clips alone: never from what was written before, or
		-- it piles up)
		local keepHeight: Vector3? = nil
		if joint == "Root" then
			local legs = if locoPose then result else CFrame.identity
			keepHeight = (blendChannel(entry.movement, motor, joint, legs)).Position
		end
		result, touched = blendChannel(entry.movement, motor, joint, result)
		any = any or touched
		if sprint > 0 and sprintPose[joint] then
			local sprintLean = R6Pose.toTransform(motor, sprintPose[joint])
			-- Partial lean: blend from "no rotation" (CFrame.new()) to the full lean.
			result = result * CFrame.new():Lerp(sprintLean, sprint)
			any = true
		end
		-- While limping, the limp owns the pelvis (Root): its weight shift
		-- must stay under the guard / hurt posture, or the legs no longer
		-- line up with the body.
		if not (joint == "Root" and isLimping(entry)) then
			result, touched = blendChannel(entry.stance, motor, joint, result, keepHeight, true)
			any = any or touched
		end
		-- Walking / running: the body leans into its acceleration and banks
		-- into turns, on top of the clip and of the guard (so it still shows
		-- while guarding); the head takes most of it back (stays level).
		if lean and (joint == "Root" or joint == "Neck") then
			local pitch, roll = loco.pitch, loco.roll
			if joint == "Neck" then
				pitch, roll = -HEAD_STEADY * pitch, -HEAD_STEADY * roll
			end
			if math.abs(pitch) + math.abs(roll) > 0.01 then
				result = result
					* R6Pose.toTransform(motor, CFrame.Angles(math.rad(-pitch), 0, math.rad(roll)))
				any = true
			end
		end
		result, touched = blendChannel(entry.action, motor, joint, result, keepHeight)
		any = any or touched
		-- Held in a hand: the Left Shoulder takes the hold pose (over the action: a left
		-- punch stays a hold), the Root gets its small tilt on top.
		if hold and hold.weight > 0 then
			local weight = math.min(hold.weight, 1)
			if joint == "LeftShoulder" and hold.leftShoulder then
				result = result:Lerp(R6Pose.toTransform(motor, hold.leftShoulder), weight)
				any = true
			elseif joint == "Root" and hold.root then
				result = result * CFrame.identity:Lerp(R6Pose.toTransform(motor, hold.root), weight)
				any = true
			end
		end
		-- Flinch: added on top of everything, on the head and (less) the torso.
		if entry.flinch ~= Vector3.zero and (joint == "Neck" or joint == "Root") then
			local share = if joint == "Neck" then 1 else FLINCH_TORSO_SHARE
			result = result * R6Pose.toTransform(motor, flinchRotation(entry.flinch, share))
			any = true
		end
		-- The visible body turning behind the root part (Locomotion: a spring
		-- instead of the root's snap), around the vertical.
		if joint == "Root" and math.abs(loco.lag) > 1e-4 then
			result = R6Pose.toTransform(motor, CFrame.Angles(0, loco.lag, 0)) * result
			any = true
		end
		-- Pinned (pinRoot): the torso's centre put where it must be, whatever
		-- the root part does; the clip's own turn kept.
		-- (torso = root · C0 · Transform · C1⁻¹, solved for Transform's position)
		local pin = if joint == "Root" then pins[entry.model] else nil
		if pin then
			local at = pin()
			if at then
				local joint0 = entry.root.CFrame * motor.C0
				local turn = result.Rotation
				local tail = (turn * motor.C1:Inverse()).Position
				result = CFrame.new(joint0:PointToObjectSpace(at) - tail) * turn
				any = true
			else
				pins[entry.model] = nil
			end
		end
		-- A switch (see the header): what was shown melts into the new pose.
		if pending then
			startInertia(entry, motor, if any then result else base, pending)
		end
		local inertia = entry.inertia[motor]
		if inertia then
			local melted = applyInertia(inertia, if any then result else base, dt)
			if melted then
				result = melted
				any = true
			else
				entry.inertia[motor] = nil
			end
		end

		if any then
			motor.Transform = result
			entry.lastWritten[motor] = result
			entry.lastBase[motor] = base
		elseif written then
			-- Our animation just ended on this joint: give it back to Roblox.
			motor.Transform = base
			entry.lastWritten[motor] = nil
			entry.lastBase[motor] = nil
		end
		-- (what this joint shows now: the starting point of the next switch)
		entry.prevPrevOut[motor] = entry.prevOut[motor]
		entry.prevOut[motor] = if any then result else base
	end
	entry.lastDt = dt
end

local function updateSprintWeight(entry: Tracked, state: string?, dt: number)
	local target = 0
	local owner = entry.player
	local sprinting = if owner == nil
		then false
		elseif owner == player then owner:GetAttribute("Sprinting") == true and state == nil
		else state == "Sprint"
	-- Our own run (the locomotion, the Bull's) already leans the body: no
	-- extra lean on top of it.
	local current = entry.movement[#entry.movement]
	local ownRun = entry.locoActive or (current ~= nil and current.name == "BullRun")
	if sprinting and not ownRun and horizontalSpeed(entry.root) > MOVING_SPEED then
		target = math.clamp(horizontalSpeed(entry.root) / Config.Character.SPRINT_SPEED, 0, 1)
	end
	local step = dt / DEFAULT_FADE
	entry.sprintWeight += math.clamp(target - entry.sprintWeight, -step, step)
end

-- Farther than this (studs) from its loose joint (Server/Ragdoll), a limb
-- of a limp body is out of place: no ball socket stretches that far.
local LOOSE_LIMB_GAP = 3
-- Name prefix of the loose joints the server adds (Server/Ragdoll).
local RAGDOLL_TAG = "Ragdoll_"

-- A limp body's limbs, put back on their loose joints if they are far off.
-- (The joints let go while our clip still drew the limb somewhere else: a
-- finisher can carry the whole body metres away. The server moves the
-- limb and every client follows it soon, but meanwhile it would hang far
-- off the body.) Torn-off limbs have no socket left: never touched.
local function snapLooseLimbs(model: Model)
	local torso = model:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	for _, socket in torso:GetChildren() do
		-- (only the ragdoll's own sockets, Server/Ragdoll)
		if
			not socket:IsA("BallSocketConstraint")
			or not socket.Enabled
			or string.sub(socket.Name, 1, #RAGDOLL_TAG) ~= RAGDOLL_TAG
		then
			continue
		end
		local a0, a1 = socket.Attachment0, socket.Attachment1
		local limb = if a1 then a1.Parent else nil
		if
			a0 == nil
			or a1 == nil
			or a0.Parent ~= torso
			or limb == nil
			or not limb:IsA("BasePart")
			or limb.Anchored
			or not limb:IsDescendantOf(model)
		then
			continue
		end
		if (a0.WorldPosition - a1.WorldPosition).Magnitude > LOOSE_LIMB_GAP then
			limb.CFrame = a0.WorldCFrame * a1.CFrame:Inverse()
			limb.AssemblyLinearVelocity = torso.AssemblyLinearVelocity
			limb.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- Back on its feet after a fall: a landing to match how hard it was (only
-- landing about on the spot; never over a move already playing).
local function jumpSpeed(humanoid: Humanoid): number
	if humanoid.UseJumpPower then
		return humanoid.JumpPower
	end
	return math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)
end

local function landed(entry: Tracked)
	local fall = entry.fallSpeed
	entry.fallSpeed = 0
	if #entry.action > 0 or horizontalSpeed(entry.root) > LAND_MAX_RUN then
		return
	end
	local plain = -jumpSpeed(entry.humanoid)
	local name = if fall < plain - LAND_HEAVY_MARGIN
		then "LandHeavy"
		elseif fall < plain - LAND_LIGHT_MARGIN then "LandLight"
		else nil
	local clip = if name then findClip(name) else nil
	if name and clip then
		table.insert(entry.action, newLayer(name, clip, ACTION_FADE_IN, ACTION_FADE_OUT))
	end
end

-- Humanoid states in which the body is NOT standing on its feet (Roblox's
-- jump / fall / swim / climb / sit animations, or physics, play then).
local NOT_ON_FEET: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Dead] = true,
}

-- A step down (stairs, a curb) is a few frames of free fall: still drawn on
-- its feet for this long, unless it falls faster than this (studs/s).
local FREEFALL_GRACE = 0.15
local FREEFALL_FAST = -12

-- The locomotion shows: standing on its feet, not climbing / sliding /
-- vaulting (ParkourController steers the body then).
local function onItsFeet(entry: Tracked, state: string?): boolean
	local humanoid = entry.humanoid
	if humanoid.Sit or humanoid.PlatformStand then
		return false
	end
	local humanoidState = humanoid:GetState()
	if humanoidState == Enum.HumanoidStateType.Freefall then
		local now = os.clock()
		local since = entry.freefallSince or now
		entry.freefallSince = since
		if
			not entry.locoActive -- (already off its feet: a jump's fall...)
			or now - since > FREEFALL_GRACE
			or entry.root.AssemblyLinearVelocity.Y < FREEFALL_FAST
		then
			return false
		end
	else
		entry.freefallSince = nil
		if NOT_ON_FEET[humanoidState] then
			return false
		end
	end
	return not (state and ARM_MOVES[state])
end

local function onPreSimulation(dt: number)
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero

	for model, entry in tracked do
		if model.Parent == nil then
			continue
		end
		-- Limp (knocked out) or dead: physics moves the body, not us. Forget
		-- what we were playing so nothing resumes when it gets up (GetUp
		-- plays then). (Dead too: a finisher's clip moved its root part to
		-- where the clip had put the body - a pose left on top would count
		-- twice.)
		if entry.humanoid.Health <= 0 or model:GetAttribute("Ragdolled") == true then
			-- Give every joint we posed back its last Roblox pose first:
			-- a pose left in Transform would stay stuck (the root joint
			-- stays on during the ragdoll, and all of them after it).
			for motor, written in entry.lastWritten do
				if motor.Transform == written then
					motor.Transform = entry.lastBase[motor] or CFrame.new()
				end
			end
			-- The root joint above all: a finisher clip leaves its root
			-- offset in it (the server has already moved the root there),
			-- and the torso would be drawn that far away again (under the
			-- floor, up in the air, beside its limbs).
			local rootJoint = entry.root:FindFirstChild("RootJoint")
			if rootJoint and rootJoint:IsA("Motor6D") then
				rootJoint.Transform = CFrame.identity
			end
			snapLooseLimbs(model)
			entry.flinch = Vector3.zero
			entry.flinchSpeed = Vector3.zero
			entry.sprintWeight = 0
			entry.freezeUntil = 0
			table.clear(entry.movement)
			table.clear(entry.stance)
			table.clear(entry.action)
			table.clear(entry.lastWritten)
			table.clear(entry.lastBase)
			entry.loco = Locomotion.new()
			entry.locoActive = false
			table.clear(entry.inertia)
			table.clear(entry.prevOut)
			table.clear(entry.prevPrevOut)
			entry.pendingInertia = nil
			entry.fallSpeed = 0
			continue
		end
		if (entry.root.Position - cameraPosition).Magnitude > MAX_DISTANCE then
			-- (what it showed and how it faced are out of date by the time it
			-- comes back: nothing to melt or to follow then)
			table.clear(entry.prevOut)
			table.clear(entry.prevPrevOut)
			table.clear(entry.inertia)
			entry.pendingInertia = nil
			entry.fallSpeed = 0
			entry.loco.lastYaw = nil
			entry.loco.lastPosition = nil
			entry.loco.lag = 0
			entry.loco.lagV = 0
			continue
		end
		local state = movementState(entry)
		if state and ARM_MOVES[state] then
			-- A punch still finishing when the climb / slide starts: fade it
			-- out so the arms belong to the move.
			for _, layer in entry.action do
				layer.target = 0
			end
		end
		-- On its feet or not (the locomotion shows): a switch is inertialized.
		local feet = onItsFeet(entry, state)
		if feet ~= entry.locoActive then
			entry.locoActive = feet
			requestInertia(entry, FEET_INERTIA)
			if feet then
				landed(entry)
			end
		end
		if not feet then
			local airState = entry.humanoid:GetState()
			if
				(
					airState == Enum.HumanoidStateType.Freefall
					or airState == Enum.HumanoidStateType.Jumping
				) and not (state and ARM_MOVES[state])
			then
				entry.fallSpeed = math.min(entry.fallSpeed, entry.root.AssemblyLinearVelocity.Y)
			else
				-- (a seat, a swim, a ladder, a climb: not a fall to land from)
				entry.fallSpeed = 0
			end
		end
		setMovementClip(entry, movementClip(entry, state, feet))
		local stance = stanceClip(entry, state)
		setChannelClip(entry.stance, stance)
		local acting = false
		for _, layer in entry.action do
			-- (a landing gives way as soon as it walks off: no sliding feet)
			if
				LANDINGS[layer.name]
				and (
					horizontalSpeed(entry.root) > LAND_MAX_RUN
					or stance ~= nil
					or state == "Crouch"
				)
			then
				layer.target = 0
			end
			if layer.target == 1 then
				acting = true
			end
		end
		Locomotion.update(entry.loco, entry.root, feet, acting, state == "Crouch", dt)
		-- Footsteps exactly when a foot lands (only when the locomotion is
		-- what the legs do: a crouch / limp clip has its own rhythm).
		if feet and #entry.movement == 0 then
			for _, step in entry.loco.steps do
				Footsteps.step(model, step.foot, step.strength, step.scuff)
			end
		end
		advanceChannel(entry, entry.movement, dt, false)
		advanceChannel(entry, entry.stance, dt, false)
		advanceChannel(entry, entry.action, dt, true)
		updateSprintWeight(entry, state, dt)
		updateFlinch(entry, dt)

		-- (every frame: the locomotion, the body's turn and the switches need
		-- what was shown each frame)
		compose(entry, dt)
	end
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

-- A clip name that doesn't exist plays nothing. In Studio we say it once per
-- name, so a typo is found right away instead of silently doing nothing.
local warnedClips: { [string]: boolean } = {}
local function warnMissingClip(name: string)
	if RunService:IsStudio() and not warnedClips[name] then
		warnedClips[name] = true
		warn(`[CharacterAnimationController] no clip named "{name}" (CombatClips / MovementClips)`)
	end
end

-- Plays a one-shot clip (punch, dash, hit reaction...) on `model`, replacing
-- the action playing on it. Unknown clip or model: does nothing.
function CharacterAnimationController.playAction(model: Model, name: string)
	local entry = tracked[model]
	local clip = findClip(name)
	-- Holding something in the LEFT hand (the case): the left-hand punches (hits 1 and 3) are
	-- thrown with the right-hand one (hit 2), re-timed around its impact (Warp): the fist
	-- lands on the server's hit (Config.Combat.M1_HIT_DELAY) and the recovery fills the time
	-- until the next click (M1_INTERVAL). The layer keeps the asked name (the combo checks),
	-- lastShown says what was really thrown (the victim's reaction follows THAT fist).
	local warp: Warp? = nil
	if holds[model] and LEFT_HAND_PUNCHES[name] then
		local right = findClip(RIGHT_HAND_PUNCH)
		local hit = LEFT_HAND_PUNCHES[name]
		local delays = Config.Combat.M1_HIT_DELAY
		local own = delays[hit]
		local interval = Config.Combat.M1_INTERVAL[hit]
		if right and own and own > 0 and interval and interval > own then
			clip = right
			warp = { impactClip = delays[2], impactReal = own, endReal = interval, elapsed = 0 }
		end
	end
	if clip == nil then
		warnMissingClip(name)
		return
	end
	if entry == nil then
		return
	end
	-- A punch / dash started during a hit-stop ends it: only a REACTION
	-- keeps the contact frame (it is followed by hitStop()). Otherwise a dash
	-- would slide away frozen in the punch pose.
	if not REACTIONS[name] then
		entry.freezeUntil = 0
	end
	for _, layer in entry.action do
		layer.target = 0
		layer.fadeOut = ACTION_FADE_IN -- cut the old one fast
	end
	local fadeIn = if REACTIONS[name] then REACTION_FADE_IN else ACTION_FADE_IN
	local layer = newLayer(name, clip :: R6Pose.Clip, fadeIn, ACTION_FADE_OUT)
	layer.warp = warp
	table.insert(entry.action, layer)
	entry.lastAction = name
	entry.lastShown = if warp then RIGHT_HAND_PUNCH else name
	-- (An emote is not a fight: no fists up after it.)
	if string.sub(name, 1, 6) ~= "Emote_" then
		entry.combatUntil = os.clock() + COMBAT_STANCE_TIME
	end
end

-- Stops the action `name` on `model` (our move, refused by the server).
-- Anything else playing (a hit reaction that came meanwhile) is kept.
function CharacterAnimationController.stopAction(model: Model, name: string)
	local entry = tracked[model]
	if entry == nil then
		return
	end
	for _, layer in entry.action do
		if layer.name == name then
			layer.target = 0
			layer.fadeOut = ACTION_FADE_OUT
		end
	end
end

-- Holds the body of `model` at a place of its own while its clips play:
-- `at()` gives where its torso's centre is this frame (world), nil once
-- over (then the body is back on its root part). nil `at`: let go now.
-- (The Bull's finisher: his root waits where he ends, his body runs there.)
function CharacterAnimationController.pinRoot(model: Model, at: (() -> Vector3?)?)
	if at then
		pins[model] = at
	else
		pins[model] = nil
	end
end

-- Sets (or with nil, removes) the hold pose of `model`: see HoldPose above. The switch is
-- inertialized like the others (nothing pops); the provider's own weight can fade it too.
-- Forgotten when the model is removed.
function CharacterAnimationController.setHoldPose(model: Model, provider: HoldProvider?)
	if holds[model] == provider then
		return
	end
	if provider then
		holds[model] = provider
	else
		holds[model] = nil
	end
	local entry = tracked[model]
	if entry then
		requestInertia(entry, DEFAULT_INERTIA)
	end
end

-- The last one-shot clip played on `model` (e.g. which punch it just threw),
-- or nil. Used to pick the matching hit reaction.
function CharacterAnimationController.getLastAction(model: Model): string?
	local entry = tracked[model]
	return if entry then entry.lastAction else nil
end

-- The clip `model` really showed for its last one-shot (differs from getLastAction when a
-- left punch was thrown as a right cross because the left hand holds the case). Use it for
-- anything that follows the motion seen (the victim's reaction, the flinch's direction).
function CharacterAnimationController.getLastShownClip(model: Model): string?
	local entry = tracked[model]
	return if entry then entry.lastShown or entry.lastAction else nil
end

-- Is `model` blocking (the server's "Blocking", or our own block before it arrives)?
function CharacterAnimationController.isBlocking(model: Model): boolean
	if model:GetAttribute("Blocking") == true then
		return true
	end
	local entry = tracked[model]
	return predictedBlock and entry ~= nil and isLocal(entry)
end

-- What the body of `model` is busy with: "Reaction" (a hit reaction plays), "Action" (any
-- other one-shot: a punch, a dash...), "Guard" (none, but the fists are still up after a
-- fight), or nil. An overlay (setHoldPose) yields to these.
function CharacterAnimationController.actionState(model: Model): string?
	local entry = tracked[model]
	if entry == nil then
		return nil
	end
	for index = #entry.action, 1, -1 do
		local layer = entry.action[index]
		if layer.target == 1 then
			return if REACTIONS[layer.name] then "Reaction" else "Action"
		end
	end
	return if os.clock() < entry.combatUntil then "Guard" else nil
end

-- This frame's value of `joint` in the action clip `name` playing on
-- `model` (a clip can hold extra tracks that are not body joints, e.g. the
-- bat's "Grip"), or nil when that clip is not playing.
function CharacterAnimationController.getActionPose(
	model: Model,
	name: string,
	joint: string
): CFrame?
	local entry = tracked[model]
	if entry == nil then
		return nil
	end
	for index = #entry.action, 1, -1 do
		local layer = entry.action[index]
		if layer.name == name then
			return layer.pose[joint]
		end
	end
	return nil
end

-- Undoes a reaction shown too early (our prediction, when the server says
-- the hit was dodged): fades the action out, ends the hit-stop and the flinch.
function CharacterAnimationController.cancelReaction(model: Model)
	local entry = tracked[model]
	if entry == nil then
		return
	end
	for _, layer in entry.action do
		if REACTIONS[layer.name] then
			layer.target = 0
			layer.fadeOut = ACTION_FADE_OUT
		end
	end
	entry.freezeUntil = 0
	entry.flinch = Vector3.zero
	entry.flinchSpeed = Vector3.zero
end

-- Ends the hit-stop of `model` right away (e.g. our own punch, frozen by a
-- predicted hit that the server says didn't land).
function CharacterAnimationController.clearHitStop(model: Model)
	local entry = tracked[model]
	if entry then
		entry.freezeUntil = 0
	end
end

-- Hit-stop: pauses the model's punch / reaction clip for `duration` seconds.
function CharacterAnimationController.hitStop(model: Model, duration: number)
	local entry = tracked[model]
	if entry then
		entry.freezeUntil = math.max(entry.freezeUntil, os.clock() + duration)
	end
end

-- Kicks the flinch spring of `model`. `kick` = degrees per second, in the
-- head's own axes: X > 0 throws the head BACK, Y > 0 turns it to its left,
-- Z > 0 tilts it to its left. (A kick of 150 peaks at roughly 8 degrees.)
function CharacterAnimationController.flinch(model: Model, kick: Vector3)
	local entry = tracked[model]
	if entry then
		entry.flinchSpeed += kick
		entry.combatUntil = os.clock() + COMBAT_STANCE_TIME
	end
end

-- Our block key: show the guard right away (the server confirms with the
-- "Blocking" attribute, or not: then CombatController turns this off).
function CharacterAnimationController.setPredictedBlock(blocking: boolean)
	predictedBlock = blocking
end

------------------------------------------------------------------------------
-- Tracking characters
------------------------------------------------------------------------------

local function track(model: Model, owner: Player?)
	if tracked[model] then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 10)
	local root = model:WaitForChild("HumanoidRootPart", 10)
	-- Joints are created with the parts; wait for the last one we need.
	local torso = model:WaitForChild("Torso", 10)
	if torso then
		torso:WaitForChild("Left Hip", 10)
	end
	if
		humanoid == nil
		or not humanoid:IsA("Humanoid")
		or root == nil
		or not root:IsA("BasePart")
		or model.Parent == nil
		or tracked[model]
	then
		return
	end
	local motors = R6Pose.findMotors(model)
	if motors == nil then
		return -- not an R6 character: leave it to Roblox
	end

	tracked[model] = {
		player = owner,
		model = model,
		humanoid = humanoid,
		root = root,
		motors = motors,
		movement = {},
		stance = {},
		action = {},
		sprintWeight = 0,
		loco = Locomotion.new(),
		locoActive = false,
		locoPose = {},
		inertia = {},
		prevOut = {},
		prevPrevOut = {},
		pendingInertia = nil,
		lastDt = 1 / 60,
		freefallSince = nil,
		fallSpeed = 0,
		combatUntil = 0,
		freezeUntil = 0,
		lastAction = nil,
		lastShown = nil,
		flinch = Vector3.zero,
		flinchSpeed = Vector3.zero,
		lastWritten = {},
		lastBase = {},
	}
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			tracked[model] = nil
			holds[model] = nil
		end
	end)
end

local function onPlayerAdded(owner: Player)
	owner.CharacterAdded:Connect(function(character)
		track(character, owner)
	end)
	if owner.Character then
		task.spawn(track, owner.Character, owner)
	end
end

-- Fighters that aren't players (training dummies) come with the combat tag.
local function onCombatantAdded(instance: Instance)
	if instance:IsA("Model") and Players:GetPlayerFromCharacter(instance) == nil then
		task.spawn(track, instance, nil)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function CharacterAnimationController.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, owner in Players:GetPlayers() do
		onPlayerAdded(owner)
	end
	local tag = Config.Combat.TAG
	CollectionService:GetInstanceAddedSignal(tag):Connect(onCombatantAdded)
	for _, instance in CollectionService:GetTagged(tag) do
		onCombatantAdded(instance)
	end

	RunService.PreSimulation:Connect(onPreSimulation)
end

return CharacterAnimationController
