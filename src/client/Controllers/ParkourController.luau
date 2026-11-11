--!strict
-- ParkourController: crouch, slide and ledge climb (client side).
--
-- Controls (keys in Config.Controls):
--   • C               → crouch / stand up.
--   • C while sprinting → slide: a burst of speed that fades, you end crouched.
--   • Jump in front of a wall you can reach → climb onto it (Shared/Ledge).
--   • Jump while crouched → stand up.  Jump during a slide → stop the slide.
--
-- Who decides what (see Server/Systems/Movement):
--   • Crouch: we only send the wish (Remotes.SetCrouching). The server sets
--     the speed.
--   • Slide / climb: the body has to move NOW, not after a network round
--     trip, so we move our own character right away (Roblox lets each client
--     move its own character) and ask the server at the same time
--     (Remotes.RequestMoveAction). The server checks it (stamina, cooldown,
--     real ledge) and confirms it by setting the "MoveState" attribute.
--     No confirmation after CONFIRM_TIMEOUT → we stop the move.
--     Before asking, we check the SAME rules locally, so a refusal is rare.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Animations = require(ReplicatedStorage.Shared.Animations)
local Config = require(ReplicatedStorage.Shared.Config)
local Ledge = require(ReplicatedStorage.Shared.Ledge)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer

-- Longer than a normal round trip to the server.
local CONFIRM_TIMEOUT = 0.4
-- After this long, a slide that is barely moving has hit a wall → stop it.
local WALL_CHECK_DELAY = 0.15
-- Speed (studs/s) above which "crouch walk" plays instead of "crouch idle".
local MOVING_SPEED = 1
-- Small push forward when a climb ends, so you don't stand on the very edge.
local CLIMB_EXIT_SPEED = 4

type Action = "Slide" | "Climb"

type ActionState = {
	kind: Action,
	startedAt: number,
	confirmed: boolean,
	-- Slide
	direction: Vector3,
	velocity: LinearVelocity?,
	attachment: Attachment?,
	-- Climb
	from: Vector3,
	control: Vector3,
	to: Vector3,
}

local ParkourController = {}

local crouched = false
local action: ActionState? = nil
local lastSlideAt = -math.huge
local lastClimbAt = -math.huge

local humanoid: Humanoid? = nil
local root: BasePart? = nil
local tracks: { [string]: AnimationTrack } = {}
local loopTrack: AnimationTrack? = nil -- crouch idle / walk currently playing

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function isAlive(): boolean
	return humanoid ~= nil and (humanoid :: Humanoid).Health > 0 and root ~= nil
end

local function horizontalVelocity(part: BasePart): Vector3
	local velocity = part.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z)
end

local function staminaAtLeast(cost: number): boolean
	local stamina = player:GetAttribute("Stamina")
	return typeof(stamina) == "number" and stamina >= cost
end

-- No jumping while crouched or during a climb (jump = stand up instead).
local function updateJumpAllowed()
	local current = humanoid
	if current then
		local allowed = not crouched and not (action and action.kind == "Climb")
		current:SetStateEnabled(Enum.HumanoidStateType.Jumping, allowed)
	end
end

local function setCrouched(value: boolean, tellServer: boolean)
	crouched = value
	updateJumpAllowed()
	if tellServer then
		Remotes.SetCrouching:FireServer(value)
	end
end

local function playTrack(name: string, fade: number)
	local track = tracks[name]
	if track then
		track:Play(fade)
	end
end

local function stopTrack(name: string, fade: number)
	local track = tracks[name]
	if track and track.IsPlaying then
		track:Stop(fade)
	end
end

------------------------------------------------------------------------------
-- Ending an action
------------------------------------------------------------------------------

-- `standUp` = true: end standing (jump out of a slide, refused move).
-- Otherwise a slide ends crouched (like on the server).
local function endAction(standUp: boolean)
	local current = action
	if current == nil then
		return
	end
	action = nil

	if current.velocity then
		current.velocity:Destroy()
	end
	if current.attachment then
		current.attachment:Destroy()
	end
	CameraController.holdRotation("parkour", false)

	if current.kind == "Slide" then
		stopTrack("Slide", 0.25)
		-- The server makes us crouch when its slide timer ends; we match it.
		-- (Server ignores crouch changes during the slide, so no need to send.)
		setCrouched(not standUp, false)
		if standUp then
			Remotes.RequestMoveAction:FireServer("Cancel")
			Remotes.SetCrouching:FireServer(false)
		end
	else
		stopTrack("Climb", 0.15)
		updateJumpAllowed()
		local part = root
		if part and not standUp then
			part.AssemblyLinearVelocity = current.direction * CLIMB_EXIT_SPEED
		end
	end
end

------------------------------------------------------------------------------
-- Slide
------------------------------------------------------------------------------

local function canSlide(now: number): boolean
	local current, part = humanoid, root
	if current == nil or part == nil or action ~= nil then
		return false
	end
	return player:GetAttribute("Sprinting") == true
		and current.FloorMaterial ~= Enum.Material.Air
		and horizontalVelocity(part).Magnitude >= Config.Slide.MIN_SPEED
		and now - lastSlideAt >= Config.Slide.COOLDOWN
		and staminaAtLeast(Config.Slide.STAMINA_COST)
end

local function startSlide(now: number)
	local part = root :: BasePart
	-- Slide where we were RUNNING (not where the camera looks).
	local direction = horizontalVelocity(part).Unit

	-- LinearVelocity in "Plane" mode: pushes the body horizontally only,
	-- gravity still works (slide down a slope, off a ledge...).
	local attachment = Instance.new("Attachment")
	attachment.Name = "SlideAttachment"
	attachment.Parent = part
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "SlideVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.MaxForce = 1e5
	velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * Config.Slide.START_SPEED
	velocity.Parent = part

	part.CFrame = CFrame.lookAt(part.Position, part.Position + direction)
	CameraController.holdRotation("parkour", true)
	crouched = false
	updateJumpAllowed()

	action = {
		kind = "Slide",
		startedAt = now,
		confirmed = false,
		direction = direction,
		velocity = velocity,
		attachment = attachment,
		from = part.Position,
		control = part.Position,
		to = part.Position,
	}
	lastSlideAt = now
	playTrack("Slide", 0.1)
	Remotes.RequestMoveAction:FireServer("Slide")
end

local function updateSlide(current: ActionState, elapsed: number)
	local part = root :: BasePart
	local slide = Config.Slide
	if elapsed >= slide.DURATION then
		endAction(false)
		return
	end
	-- Hit a wall: almost no speed left while we're pushing forward.
	if
		elapsed > WALL_CHECK_DELAY
		and horizontalVelocity(part).Magnitude < slide.END_SPEED * 0.5
	then
		endAction(false)
		return
	end

	-- Speed fades from START_SPEED to END_SPEED, fast at first ("ease out").
	local t = elapsed / slide.DURATION
	local eased = 1 - (1 - t) * (1 - t)
	local speed = slide.START_SPEED + (slide.END_SPEED - slide.START_SPEED) * eased
	local velocity = current.velocity :: LinearVelocity
	velocity.PlaneVelocity = Vector2.new(current.direction.X, current.direction.Z) * speed
end

------------------------------------------------------------------------------
-- Climb
------------------------------------------------------------------------------

local function tryStartClimb(now: number)
	local character = player.Character
	local part = root
	if character == nil or part == nil or action ~= nil then
		return
	end
	if
		now - lastClimbAt < Config.Climb.COOLDOWN or not staminaAtLeast(Config.Climb.STAMINA_COST)
	then
		return
	end
	local ledge = Ledge.find(character, 0)
	if ledge == nil then
		return
	end

	local from = part.Position
	-- Curve: go UP first (above the ledge), then forward onto it.
	local control = Vector3.new(from.X, ledge.target.Y + 0.5, from.Z)

	CameraController.holdRotation("parkour", true)
	crouched = false
	action = {
		kind = "Climb",
		startedAt = now,
		confirmed = false,
		direction = ledge.facing,
		velocity = nil,
		attachment = nil,
		from = from,
		control = control,
		to = ledge.target,
	}
	updateJumpAllowed()
	lastClimbAt = now
	playTrack("Climb", 0.05)
	Remotes.RequestMoveAction:FireServer("Climb")
end

-- Runs just BEFORE each physics step, so physics starts from our position.
local function updateClimb(current: ActionState, elapsed: number)
	local part = root :: BasePart
	local t = math.clamp(elapsed / Config.Climb.DURATION, 0, 1)
	local eased = t * t * (3 - 2 * t) -- "smoothstep": slow start, slow end

	-- Quadratic Bézier curve from → control → to.
	local a = current.from:Lerp(current.control, eased)
	local b = current.control:Lerp(current.to, eased)
	local position = a:Lerp(b, eased)

	part.CFrame = CFrame.lookAt(position, position + current.direction)
	part.AssemblyLinearVelocity = Vector3.zero -- cancel gravity for this step

	if t >= 1 then
		endAction(false)
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function onPreSimulation()
	local current = action
	if current == nil then
		return
	end
	if not isAlive() then
		endAction(true)
		return
	end

	local elapsed = os.clock() - current.startedAt
	if player:GetAttribute("MoveState") == current.kind then
		current.confirmed = true
	elseif not current.confirmed and elapsed > CONFIRM_TIMEOUT then
		-- The server refused (or never answered): stop right here.
		endAction(true)
		return
	end

	if current.kind == "Slide" then
		updateSlide(current, elapsed)
	else
		updateClimb(current, elapsed)
	end
end

-- Crouch animations (idle / walk) follow the crouch state and the speed.
local function onRenderStep()
	local part = root
	local wanted: AnimationTrack? = nil
	if crouched and action == nil and part and isAlive() then
		local moving = horizontalVelocity(part).Magnitude > MOVING_SPEED
		wanted = if moving then tracks.CrouchWalk else tracks.CrouchIdle
	end
	if wanted == loopTrack then
		return
	end
	if loopTrack then
		loopTrack:Stop(0.2)
	end
	if wanted then
		wanted:Play(0.2)
	end
	loopTrack = wanted
end

------------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------------

local function onCrouchKey()
	if not isAlive() or (action and action.kind == "Climb") then
		return
	end
	local now = os.clock()
	if canSlide(now) then
		startSlide(now)
	elseif action == nil then
		setCrouched(not crouched, true)
	end
end

local function onJumpRequest()
	if not isAlive() then
		return
	end
	if action and action.kind == "Slide" then
		endAction(true) -- jump out of the slide (the jump itself still happens)
	elseif crouched then
		setCrouched(false, true)
	elseif action == nil then
		tryStartClimb(os.clock())
	end
end

------------------------------------------------------------------------------
-- Character
------------------------------------------------------------------------------

local function loadTracks(animator: Animator)
	table.clear(tracks)
	loopTrack = nil
	for name, id in Animations.MOVEMENT do
		if id ~= "" then
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local track = animator:LoadAnimation(animation)
			local isMovementLoop = name == "CrouchIdle" or name == "CrouchWalk"
			track.Priority = if isMovementLoop
				then Enum.AnimationPriority.Movement
				else Enum.AnimationPriority.Action
			track.Looped = name ~= "Climb"
			tracks[name] = track
		end
	end
end

local function onCharacterAdded(character: Model)
	-- Forget everything about the previous life.
	endAction(true)
	humanoid = nil
	root = nil
	crouched = false
	table.clear(tracks)
	loopTrack = nil

	local foundHumanoid = character:WaitForChild("Humanoid", 10)
	local foundRoot = character:WaitForChild("HumanoidRootPart", 10)
	if
		foundHumanoid == nil
		or not foundHumanoid:IsA("Humanoid")
		or foundRoot == nil
		or not foundRoot:IsA("BasePart")
		or character.Parent == nil -- already respawned meanwhile
	then
		return
	end
	humanoid = foundHumanoid
	root = foundRoot
	updateJumpAllowed()

	local animator = foundHumanoid:WaitForChild("Animator", 10)
	if animator and animator:IsA("Animator") and humanoid == foundHumanoid then
		loadTracks(animator)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function ParkourController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return -- typing in the chat, clicking a menu...
		end
		if input.KeyCode == Config.Controls.CROUCH then
			onCrouchKey()
		elseif input.KeyCode == Config.Controls.SPRINT and crouched and action == nil then
			setCrouched(false, true) -- sprinting makes you stand up
		end
	end)
	UserInputService.JumpRequest:Connect(onJumpRequest)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	RunService.PreSimulation:Connect(onPreSimulation)
	RunService.RenderStepped:Connect(onRenderStep)
end

return ParkourController
