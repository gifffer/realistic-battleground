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
-- Three channels, blended in this order (later ones win on the joints they use):
--   1. movement  crouch, slide, climb...      (+ the sprint lean, added on top)
--   2. stance    guard, block, stunned        (loops, upper body)
--   3. action    punch, dash, hit reaction... (plays once)
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
-- Each frame, right after Roblox's Animator has posed the body (the default
-- walk / idle / jump animations), we blend our pose on top of it:
--   final = robloxPose:Lerp(ourPose, weight)
-- Weights fade in and out, so switching animations never snaps. Joints a
-- clip doesn't list keep what's below (e.g. legs keep walking while you block).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CombatClips = require(script.Parent.Parent.Animation.CombatClips)
local MovementClips = require(script.Parent.Parent.Animation.MovementClips)
local R6Pose = require(script.Parent.Parent.Animation.R6Pose)
local ParkourController = require(script.Parent.ParkourController)

local player = Players.LocalPlayer

-- Seconds to fade a clip in / out, per clip (default otherwise).
local DEFAULT_FADE = 0.2
local FADE_IN: { [string]: number } = {
	Climb = 0.06,
	Vault = 0.06,
	Slide = 0.12,
	Block = 0.08,
	Stunned = 0.12,
	Guard = 0.12,
	-- Injuries: the tired posture settles in slowly.
	HurtGuard = 0.3,
	HurtIdle = 0.4,
	LimpWalk = 0.2,
	LimpIdle = 0.3,
	Walk = 0.15,
	Run = 0.15,
}
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
-- Walk / run (studs per second): below WALK_MIN_SPEED we stand (Roblox's
-- idle); above RUN_START_SPEED we run, back to walking under RUN_STOP_SPEED.
local WALK_MIN_SPEED = 1
local RUN_START_SPEED = 14
local RUN_STOP_SPEED = 12
local CROUCH_WALK_START = 1.5
local CROUCH_WALK_STOP = 0.5
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
}

-- One channel = a list of layers (the newest is the one playing; older ones
-- are fading out).
type Channel = { Layer }

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
	-- Combat feel (see the header).
	combatUntil: number, -- os.clock() until which the guard stays up
	freezeUntil: number, -- hit-stop: the action clip is paused until then
	lastAction: string?, -- last one-shot clip played (which punch was thrown)
	flinch: Vector3, -- spring position: extra head rotation, degrees
	flinchSpeed: Vector3, -- spring speed, degrees per second
	-- To know if Roblox's Animator rewrote a joint this frame (see compose()).
	lastWritten: { [Motor6D]: CFrame },
	lastBase: { [Motor6D]: CFrame },
}

local CharacterAnimationController = {}

local tracked: { [Model]: Tracked } = {}
-- We pressed block: show it before the server's "Blocking" attribute arrives.
local predictedBlock = false
-- Reused every frame (no table created per frame).
local sprintPose: { [string]: CFrame } = {}

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
	return (MovementClips :: any)[name] or (CombatClips :: any)[name]
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

-- Movement clip for this state ("Crouch" splits into idle / walk), nil = none.
-- A limping fighter (legs injured) walks and stands on its good leg.
local function movementClip(entry: Tracked, state: string?): string?
	-- (Only on the ground: jumping, falling, swimming, climbing a ladder or
	-- sitting keep Roblox's own animations.)
	local humanoidState = entry.humanoid:GetState()
	local onGround = humanoidState == Enum.HumanoidStateType.Running
		or humanoidState == Enum.HumanoidStateType.RunningNoPhysics
	if
		(state == nil or state == "Walk")
		and onGround
		and entry.model:GetAttribute("Limping") == true
	then
		local current = entry.movement[#entry.movement]
		local walking = current ~= nil and current.target == 1 and current.name == "LimpWalk"
		local threshold = if walking then CROUCH_WALK_STOP else CROUCH_WALK_START
		return if horizontalSpeed(entry.root) > threshold then "LimpWalk" else "LimpIdle"
	end
	if state == "Crouch" then
		local current = entry.movement[#entry.movement]
		local walking = current ~= nil and current.target == 1 and current.name == "CrouchWalk"
		local threshold = if walking then CROUCH_WALK_STOP else CROUCH_WALK_START
		return if horizontalSpeed(entry.root) > threshold then "CrouchWalk" else "CrouchIdle"
	elseif state == "Slide" or state == "Climb" or state == "Vault" then
		return state
	elseif state == nil then
		-- Standing up: our own walk / run instead of Roblox's. Nothing in the
		-- air (Roblox's jump / fall animation plays) or when standing still.
		local airborne = entry.humanoid:GetState() == Enum.HumanoidStateType.Freefall
			or entry.humanoid:GetState() == Enum.HumanoidStateType.Jumping
		local speed = horizontalSpeed(entry.root)
		if airborne or speed < WALK_MIN_SPEED then
			return nil
		end
		-- Walk ↔ run with a gap between the two speeds ("hysteresis"), so a
		-- speed hovering around one value doesn't flicker between the clips.
		local current = entry.movement[#entry.movement]
		local running = current ~= nil and current.target == 1 and current.name == "Run"
		return if speed > (if running then RUN_STOP_SPEED else RUN_START_SPEED)
			then "Run"
			else "Walk"
	end
	return nil
end

-- Moves that use the arms (and during which nobody can fight): no stance
-- on top of them, or the guard would keep the fists up while climbing.
local ARM_MOVES = table.freeze({ Slide = true, Climb = true, Vault = true })

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
	if name == "LimpWalk" then
		-- Authored for 12 studs/s (walking speed × the limp's slowdown).
		return math.clamp(horizontalSpeed(entry.root) / 12, 0.6, 1.6)
	elseif name == "CrouchWalk" then
		-- The legs follow the real walking speed (no foot sliding).
		return math.clamp(horizontalSpeed(entry.root) / Config.Character.CROUCH_SPEED, 0.6, 1.8)
	elseif name == "Walk" then
		-- Faster walk = faster steps (about 3 steps per second at full walking speed).
		return math.clamp(horizontalSpeed(entry.root) / Config.Character.WALK_SPEED * 1.5, 0.7, 1.6)
	elseif name == "Run" then
		-- About 4.5 steps per second at full sprint.
		return math.clamp(
			horizontalSpeed(entry.root) / Config.Character.SPRINT_SPEED * 1.35,
			0.8,
			1.5
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
		layer.time += dt * playbackRate(entry, layer.name)

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

local function blendChannel(
	channel: Channel,
	motor: Motor6D,
	joint: string,
	result: CFrame,
	keepHeight: Vector3? -- Root only: the crouch's drop, for upper-body clips
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
			result = result:Lerp(target, layer.weight)
			touched = true
		end
	end
	return result, touched
end

-- A limp clip is playing (or fading in) on the movement channel.
isLimping = function(entry: Tracked): boolean
	local current = entry.movement[#entry.movement]
	return current ~= nil
		and current.target == 1
		and (current.name == "LimpWalk" or current.name == "LimpIdle")
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

local function compose(entry: Tracked)
	sampleChannel(entry.movement)
	sampleChannel(entry.stance)
	sampleChannel(entry.action)
	local sprint = entry.sprintWeight
	if sprint > 0 then
		R6Pose.sample(MovementClips.SprintLean, 0, sprintPose)
	end

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
		-- (the crouch's drop, worked out afresh each frame from the movement
		-- clips alone: never from what was written before, or it piles up)
		local keepHeight: Vector3? = nil
		if joint == "Root" then
			keepHeight = (blendChannel(entry.movement, motor, joint, CFrame.identity)).Position
		end
		result, touched = blendChannel(entry.movement, motor, joint, result)
		any = any or touched
		if sprint > 0 and sprintPose[joint] then
			local lean = R6Pose.toTransform(motor, sprintPose[joint])
			-- Partial lean: blend from "no rotation" (CFrame.new()) to the full lean.
			result = result * CFrame.new():Lerp(lean, sprint)
			any = true
		end
		-- While limping, the limp owns the pelvis (Root): its weight shift
		-- must stay under the guard / hurt posture, or the legs no longer
		-- line up with the body.
		if not (joint == "Root" and isLimping(entry)) then
			result, touched = blendChannel(entry.stance, motor, joint, result, keepHeight)
			any = any or touched
		end
		result, touched = blendChannel(entry.action, motor, joint, result, keepHeight)
		any = any or touched
		-- Flinch: added on top of everything, on the head and (less) the torso.
		if entry.flinch ~= Vector3.zero and (joint == "Neck" or joint == "Root") then
			local share = if joint == "Neck" then 1 else FLINCH_TORSO_SHARE
			result = result * R6Pose.toTransform(motor, flinchRotation(entry.flinch, share))
			any = true
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
	end
end

local function updateSprintWeight(entry: Tracked, state: string?, dt: number)
	local target = 0
	local owner = entry.player
	local sprinting = if owner == nil
		then false
		elseif owner == player then owner:GetAttribute("Sprinting") == true and state == nil
		else state == "Sprint"
	-- Our Run clip already leans the body: no extra lean on top of it.
	local current = entry.movement[#entry.movement]
	local ownRun = current ~= nil and current.name == "Run"
	if sprinting and not ownRun and horizontalSpeed(entry.root) > MOVING_SPEED then
		target = math.clamp(horizontalSpeed(entry.root) / Config.Character.SPRINT_SPEED, 0, 1)
	end
	local step = dt / DEFAULT_FADE
	entry.sprintWeight += math.clamp(target - entry.sprintWeight, -step, step)
end

local function onPreSimulation(dt: number)
	local camera = workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero

	for model, entry in tracked do
		if entry.humanoid.Health <= 0 or model.Parent == nil then
			continue
		end
		-- Limp (knocked out): physics moves the body, not us. Forget what we
		-- were playing so nothing resumes when it gets up (GetUp plays then).
		if model:GetAttribute("Ragdolled") == true then
			-- Give every joint we posed back its last Roblox pose first:
			-- a pose left in Transform would stay stuck (the root joint
			-- stays on during the ragdoll, and all of them after it).
			for motor, written in entry.lastWritten do
				if motor.Transform == written then
					motor.Transform = entry.lastBase[motor] or CFrame.new()
				end
			end
			entry.flinch = Vector3.zero
			entry.flinchSpeed = Vector3.zero
			entry.sprintWeight = 0
			entry.freezeUntil = 0
			table.clear(entry.movement)
			table.clear(entry.stance)
			table.clear(entry.action)
			table.clear(entry.lastWritten)
			table.clear(entry.lastBase)
			continue
		end
		if (entry.root.Position - cameraPosition).Magnitude > MAX_DISTANCE then
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
		setChannelClip(entry.movement, movementClip(entry, state))
		setChannelClip(entry.stance, stanceClip(entry, state))
		advanceChannel(entry, entry.movement, dt, false)
		advanceChannel(entry, entry.stance, dt, false)
		advanceChannel(entry, entry.action, dt, true)
		updateSprintWeight(entry, state, dt)
		updateFlinch(entry, dt)

		local busy = #entry.movement > 0 or #entry.stance > 0 or #entry.action > 0
		local extras = entry.sprintWeight > 0 or entry.flinch ~= Vector3.zero
		if busy or extras or next(entry.lastWritten) ~= nil then
			compose(entry)
		end
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
	table.insert(entry.action, newLayer(name, clip, fadeIn, ACTION_FADE_OUT))
	entry.lastAction = name
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

-- The last one-shot clip played on `model` (e.g. which punch it just threw),
-- or nil. Used to pick the matching hit reaction.
function CharacterAnimationController.getLastAction(model: Model): string?
	local entry = tracked[model]
	return if entry then entry.lastAction else nil
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
		combatUntil = 0,
		freezeUntil = 0,
		lastAction = nil,
		flinch = Vector3.zero,
		flinchSpeed = Vector3.zero,
		lastWritten = {},
		lastBase = {},
	}
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			tracked[model] = nil
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
