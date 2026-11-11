--!strict
-- CharacterAnimationController: plays our code-made movement animations
-- (Client/Animation/MovementClips) on EVERY character, on this client.
--
-- Why every client animates every character: a Motor6D.Transform written by
-- a script is NOT sent over the network. So each client poses all characters
-- itself, from information that IS shared: the "MoveState" attribute the
-- server sets on each Player (Server/Systems/Movement).
--   • Other players: "MoveState" (arrives after the network delay, fine).
--   • Our own character: ParkourController.getVisualState(), instant.
--
-- Each frame, right after Roblox's Animator has posed the body (the default
-- walk / idle / jump animations), we blend our pose on top of it:
--   final = robloxPose:Lerp(ourPose, weight)
-- The weight fades in and out, so switching animations never snaps.
-- Joints a clip doesn't list keep Roblox's animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MovementClips = require(script.Parent.Parent.Animation.MovementClips)
local R6Pose = require(script.Parent.Parent.Animation.R6Pose)
local ParkourController = require(script.Parent.ParkourController)

local player = Players.LocalPlayer

-- Seconds to fade a clip in / out, per clip (default otherwise).
local DEFAULT_FADE = 0.2
local FADE_IN: { [string]: number } = { Climb = 0.06, Slide = 0.1 }
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
	fade: number,
}

type Tracked = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	motors: { [string]: Motor6D },
	layers: { Layer },
	sprintWeight: number,
	-- To know if Roblox's Animator rewrote a joint this frame (see compose()).
	lastWritten: { [Motor6D]: CFrame },
	lastBase: { [Motor6D]: CFrame },
}

local CharacterAnimationController = {}

local tracked: { [Model]: Tracked } = {}
-- Reused every frame (no table created per frame).
local sampled: { [string]: CFrame } = {}
local layerPoses: { { [string]: CFrame } } = {}

------------------------------------------------------------------------------
-- Choosing the clip
------------------------------------------------------------------------------

local function horizontalSpeed(root: BasePart): number
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- Which movement state to show for this character.
local function visualState(entry: Tracked): string?
	if entry.player == player then
		return ParkourController.getVisualState()
	end
	local state = entry.player:GetAttribute("MoveState")
	return if typeof(state) == "string" then state else nil
end

-- Clip name for this state ("Crouch" splits into idle / walk), nil = none.
local function wantedClip(entry: Tracked, state: string?): string?
	if state == "Crouch" then
		local current = entry.layers[#entry.layers]
		local walking = current ~= nil and current.target == 1 and current.name == "CrouchWalk"
		local threshold = if walking then CROUCH_WALK_STOP else CROUCH_WALK_START
		return if horizontalSpeed(entry.root) > threshold then "CrouchWalk" else "CrouchIdle"
	elseif state == "Slide" or state == "Climb" then
		return state
	end
	return nil
end

-- Playback speed of a clip (crouch walk follows the real walking speed).
local function playbackRate(entry: Tracked, name: string): number
	if name == "CrouchWalk" then
		return math.clamp(horizontalSpeed(entry.root) / Config.Character.CROUCH_SPEED, 0.6, 1.8)
	end
	return 1
end

------------------------------------------------------------------------------
-- Layers (fade in / out)
------------------------------------------------------------------------------

local function setActiveClip(entry: Tracked, name: string?)
	local current = entry.layers[#entry.layers]
	if current and current.target == 1 and current.name == name then
		return -- already playing
	end
	-- Fade out whatever is playing.
	for _, layer in entry.layers do
		layer.target = 0
	end
	if name then
		local clip = (MovementClips :: any)[name] :: R6Pose.Clip
		table.insert(entry.layers, {
			name = name,
			clip = clip,
			time = 0,
			weight = 0,
			target = 1,
			fade = FADE_IN[name] or DEFAULT_FADE,
		})
	end
end

local function advanceLayers(entry: Tracked, dt: number)
	for index = #entry.layers, 1, -1 do
		local layer = entry.layers[index]
		layer.time += dt * playbackRate(entry, layer.name)
		local step = dt / (if layer.target == 1 then layer.fade else DEFAULT_FADE)
		if layer.weight < layer.target then
			layer.weight = math.min(layer.target, layer.weight + step)
		else
			layer.weight = math.max(layer.target, layer.weight - step)
		end
		if layer.target == 0 and layer.weight <= 0 then
			table.remove(entry.layers, index)
		end
	end
end

------------------------------------------------------------------------------
-- Writing the joints
------------------------------------------------------------------------------

local function compose(entry: Tracked)
	-- Sample each layer once.
	for index, layer in entry.layers do
		local pose = layerPoses[index]
		if pose == nil then
			pose = {}
			layerPoses[index] = pose
		end
		R6Pose.sample(layer.clip, layer.time, pose)
	end
	local sprint = entry.sprintWeight
	if sprint > 0 then
		R6Pose.sample(MovementClips.SprintLean, 0, sampled)
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
		local touched = false
		for index, layer in entry.layers do
			local localPose = layerPoses[index][joint]
			if localPose and layer.weight > 0 then
				result = result:Lerp(R6Pose.toTransform(motor, localPose), layer.weight)
				touched = true
			end
		end
		if sprint > 0 and sampled[joint] then
			local lean = R6Pose.toTransform(motor, sampled[joint])
			result = result * CFrame.identity:Lerp(lean, sprint)
			touched = true
		end

		if touched then
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
	local sprinting = if entry.player == player
		then player:GetAttribute("Sprinting") == true and state == nil
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

	for character, entry in tracked do
		if entry.humanoid.Health <= 0 or character.Parent == nil then
			continue
		end
		if (entry.root.Position - cameraPosition).Magnitude > MAX_DISTANCE then
			continue
		end
		local state = visualState(entry)
		setActiveClip(entry, wantedClip(entry, state))
		advanceLayers(entry, dt)
		updateSprintWeight(entry, state, dt)
		if #entry.layers > 0 or entry.sprintWeight > 0 or next(entry.lastWritten) ~= nil then
			compose(entry)
		end
	end
end

------------------------------------------------------------------------------
-- Tracking characters
------------------------------------------------------------------------------

local function track(owner: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	-- Joints are created with the parts; wait for the last one we need.
	local torso = character:WaitForChild("Torso", 10)
	if torso then
		torso:WaitForChild("Left Hip", 10)
	end
	if
		humanoid == nil
		or not humanoid:IsA("Humanoid")
		or root == nil
		or not root:IsA("BasePart")
		or character.Parent == nil
	then
		return
	end
	local motors = R6Pose.findMotors(character)
	if motors == nil then
		return -- not an R6 character: leave it to Roblox
	end

	tracked[character] = {
		player = owner,
		character = character,
		humanoid = humanoid,
		root = root,
		motors = motors,
		layers = {},
		sprintWeight = 0,
		lastWritten = {},
		lastBase = {},
	}
	character.Destroying:Connect(function()
		tracked[character] = nil
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			tracked[character] = nil
		end
	end)
end

local function onPlayerAdded(owner: Player)
	owner.CharacterAdded:Connect(function(character)
		track(owner, character)
	end)
	if owner.Character then
		task.spawn(track, owner, owner.Character)
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
	RunService.PreSimulation:Connect(onPreSimulation)
end

return CharacterAnimationController
