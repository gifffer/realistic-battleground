--!strict
-- Movement on the client: reads the keys, tells the server, and PREDICTS
-- the result so it feels instant.
--
-- Big picture:
--   • Shift (hold) = sprint, C (toggle) = crouch. Keys live in Shared/Keybinds.
--   • When the keys change, we send the intent to the server
--     (Remotes.SetMovementInput). The server decides the real state.
--   • Meanwhile we apply the SAME rules locally (Shared/MovementRules) so the
--     speed changes on the frame you press the key, not 100 ms later.
--   • If our guess and the server's "MoveState" attribute disagree for more
--     than RECONCILE_DELAY seconds, the server wins.
--   • Plays the movement animations listed in Shared/Animations (if made).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage.Shared.Animations)
local Keybinds = require(ReplicatedStorage.Shared.Keybinds)
local MovementRules = require(ReplicatedStorage.Shared.MovementRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local player = Players.LocalPlayer

-- Longer than a normal round trip to the server, so we don't "fight"
-- the server while its answer is on the way.
local RECONCILE_DELAY = 0.5
-- Speed (studs/s) above which we play the "moving" version of an animation.
local MOVING_SPEED = 1

local MovementController = {}

local wantSprint = false
local wantCrouch = false
local sentSprint: boolean? = nil
local sentCrouch: boolean? = nil

local currentState: Types.MoveState = "Walk"
local mismatchSince: number? = nil

-- Animation tracks of the current character (only the ones that exist).
local tracks: { [string]: AnimationTrack } = {}
local playing: AnimationTrack? = nil

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function getHumanoid(): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- Sends the keys to the server, only when they changed.
local function sendIntent()
	if wantSprint == sentSprint and wantCrouch == sentCrouch then
		return
	end
	sentSprint = wantSprint
	sentCrouch = wantCrouch
	Remotes.SetMovementInput:FireServer(wantSprint, wantCrouch)
end

local function serverState(): Types.MoveState?
	local character = player.Character
	local value = character and character:GetAttribute("MoveState")
	if MovementRules.isMoveState(value) then
		return value :: Types.MoveState
	end
	return nil
end

------------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------------

local function loadTracks(humanoid: Humanoid)
	table.clear(tracks)
	playing = nil
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return
	end
	for name, id in Animations.MOVEMENT do
		if id ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Movement
			track.Looped = true
			tracks[name] = track
		end
	end
end

-- Which animation should play for this state + speed (nil = the default Roblox ones).
local function wantedTrack(state: Types.MoveState, moving: boolean): AnimationTrack?
	if state == "Sprint" and moving then
		return tracks.SPRINT
	elseif state == "Crouch" then
		return if moving then tracks.CROUCH_WALK else tracks.CROUCH_IDLE
	end
	return nil
end

local function updateAnimation(humanoid: Humanoid)
	local root = humanoid.RootPart
	local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
	local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > MOVING_SPEED

	local track = wantedTrack(currentState, moving)
	if track == playing then
		return
	end
	if playing then
		playing:Stop(0.2)
	end
	if track then
		track:Play(0.2)
	end
	playing = track
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function onRenderStep()
	local humanoid = getHumanoid()
	if humanoid == nil then
		return
	end

	-- 1. Prediction: same rules as the server, with the exhaustion flag it sent us.
	local exhausted = player:GetAttribute("Exhausted") == true
	local predicted: Types.MoveState = MovementRules.resolve(wantSprint, wantCrouch, exhausted)

	-- 2. Reconciliation: the server has the last word if we disagree for too long.
	local confirmed = serverState()
	local state: Types.MoveState = predicted
	if confirmed and confirmed ~= predicted then
		local now = os.clock()
		mismatchSince = mismatchSince or now
		if now - (mismatchSince :: number) > RECONCILE_DELAY then
			state = confirmed :: Types.MoveState
		end
	else
		mismatchSince = nil
	end

	currentState = state
	local speed = MovementRules.speedFor(state)
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end

	updateAnimation(humanoid)
end

------------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------------

local function onSprint(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		wantSprint = true
		wantCrouch = false -- sprinting makes you stand up
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		wantSprint = false
	end
	sendIntent()
	return Enum.ContextActionResult.Pass
end

local function onCrouch(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		wantCrouch = not wantCrouch
		sendIntent()
	end
	return Enum.ContextActionResult.Sink
end

local function onCharacterAdded(character: Model)
	-- Fresh body: stand up, re-send the keys (the server reset them too).
	wantCrouch = false
	sentSprint = nil
	sentCrouch = nil
	mismatchSince = nil
	currentState = "Walk"
	sendIntent()

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	loadTracks(humanoid)

	-- Jumping stands you up.
	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Jumping and wantCrouch then
			wantCrouch = false
			sendIntent()
		end
	end)
end

------------------------------------------------------------------------------
-- Public API (for other client controllers, e.g. the camera)
------------------------------------------------------------------------------

-- Current movement state as the player sees it (prediction, corrected by the server).
function MovementController.getState(): Types.MoveState
	return currentState
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function MovementController.start()
	ContextActionService:BindAction("Sprint", onSprint, false, Keybinds.SPRINT)
	ContextActionService:BindAction("Crouch", onCrouch, false, Keybinds.CROUCH)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	RunService.RenderStepped:Connect(onRenderStep)
end

return MovementController
