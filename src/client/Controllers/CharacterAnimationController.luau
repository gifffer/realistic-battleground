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
--   2. stance    block, stunned               (loops, upper body)
--   3. action    punch, dash, hit reaction... (plays once)
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
}
-- One-shot actions: fast in (a punch must start NOW), smooth out.
local ACTION_FADE_IN = 0.05
local ACTION_FADE_OUT = 0.12
-- "Climb" and "Vault" clips are written with times from 0 to 1 and stretched
-- to the real duration. For OTHER players we don't know the exact duration
-- of a mantle (it depends on the ledge's height): we use the average.
local AVERAGE_MANTLE_DURATION = (Config.Climb.MANTLE_MIN_DURATION + Config.Climb.MAX_DURATION) / 2
-- Speed (studs/s) above which a character counts as moving.
local MOVING_SPEED = 1
-- Crouch idle ↔ walk switch with a gap ("hysteresis"), so a speed hovering
-- around one value doesn't flicker between the two clips.
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
		table.insert(channel, newLayer(name, clip, FADE_IN[name] or DEFAULT_FADE, DEFAULT_FADE))
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
local function movementClip(entry: Tracked, state: string?): string?
	if state == "Crouch" then
		local current = entry.movement[#entry.movement]
		local walking = current ~= nil and current.target == 1 and current.name == "CrouchWalk"
		local threshold = if walking then CROUCH_WALK_STOP else CROUCH_WALK_START
		return if horizontalSpeed(entry.root) > threshold then "CrouchWalk" else "CrouchIdle"
	elseif state == "Slide" or state == "Climb" or state == "Vault" then
		return state
	end
	return nil
end

-- Stance clip from the fighter's attributes. Stunned wins over blocking.
local function stanceClip(entry: Tracked): string?
	local model = entry.model
	if model:GetAttribute("Stunned") == true then
		return "Stunned"
	end
	if model:GetAttribute("Blocking") == true or (isLocal(entry) and predictedBlock) then
		return "Block"
	end
	return nil
end

-- Playback speed of a clip.
local function playbackRate(entry: Tracked, name: string): number
	if name == "CrouchWalk" then
		-- The legs follow the real walking speed (no foot sliding).
		return math.clamp(horizontalSpeed(entry.root) / Config.Character.CROUCH_SPEED, 0.6, 1.8)
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
	result: CFrame
): (CFrame, boolean)
	local touched = false
	for _, layer in channel do
		local localPose = layer.pose[joint]
		if localPose and layer.weight > 0 then
			result = result:Lerp(R6Pose.toTransform(motor, localPose), layer.weight)
			touched = true
		end
	end
	return result, touched
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
		result, touched = blendChannel(entry.movement, motor, joint, result)
		any = any or touched
		if sprint > 0 and sprintPose[joint] then
			local lean = R6Pose.toTransform(motor, sprintPose[joint])
			-- Partial lean: blend from "no rotation" (CFrame.new()) to the full lean.
			result = result * CFrame.new():Lerp(lean, sprint)
			any = true
		end
		result, touched = blendChannel(entry.stance, motor, joint, result)
		any = any or touched
		result, touched = blendChannel(entry.action, motor, joint, result)
		any = any or touched

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
	if sprinting and horizontalSpeed(entry.root) > MOVING_SPEED then
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
		if (entry.root.Position - cameraPosition).Magnitude > MAX_DISTANCE then
			continue
		end
		local state = movementState(entry)
		setChannelClip(entry.movement, movementClip(entry, state))
		setChannelClip(entry.stance, stanceClip(entry))
		advanceChannel(entry, entry.movement, dt, false)
		advanceChannel(entry, entry.stance, dt, false)
		advanceChannel(entry, entry.action, dt, true)
		updateSprintWeight(entry, state, dt)

		local busy = #entry.movement > 0 or #entry.stance > 0 or #entry.action > 0
		if busy or entry.sprintWeight > 0 or next(entry.lastWritten) ~= nil then
			compose(entry)
		end
	end
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

-- Plays a one-shot clip (punch, dash, hit reaction...) on `model`, replacing
-- the action playing on it. Unknown clip or model: does nothing.
function CharacterAnimationController.playAction(model: Model, name: string)
	local entry = tracked[model]
	local clip = findClip(name)
	if entry == nil or clip == nil then
		return
	end
	for _, layer in entry.action do
		layer.target = 0
		layer.fadeOut = ACTION_FADE_IN -- cut the old one fast
	end
	table.insert(entry.action, newLayer(name, clip, ACTION_FADE_IN, ACTION_FADE_OUT))
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
