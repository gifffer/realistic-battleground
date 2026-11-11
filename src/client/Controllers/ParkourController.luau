--!strict
-- ParkourController: crouch, slide and ledge climb (client side).
--
-- Controls (keys in Config.Controls):
--   • C               → crouch / stand up.
--   • C while sprinting → slide: a burst of speed that fades, you end crouched.
--   • Jump in front of a wall you can reach (Shared/Ledge):
--       low obstacle → VAULT: hand on top, swing over, keep your speed;
--       high ledge   → MANTLE: grab the edge, hang, pull up, step onto it.
--   • Jump while crouched → stand up.  Jump during a slide → stop the slide.
--
-- The body poses (crouch, slide, climb) are animated by
-- CharacterAnimationController, which asks us getVisualState().
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

local Config = require(ReplicatedStorage.Shared.Config)
local Ledge = require(ReplicatedStorage.Shared.Ledge)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer

-- Longer than a normal round trip to the server.
local CONFIRM_TIMEOUT = 0.4
-- After this long, a slide that is barely moving has hit a wall → stop it.
local WALL_CHECK_DELAY = 0.15
-- Speed (studs/s) you leave a mantle with, so you don't stand on the very edge.
local MANTLE_EXIT_SPEED = 3

-- Mantle phases, as fractions of its duration. MUST match the keyframe
-- times of the "Climb" clip in Client/Animation/MovementClips.
local MANTLE_CATCH_END = 0.22 -- start → hands on the ledge
local MANTLE_HANG_END = 0.36 -- hanging, legs swinging
local MANTLE_PULL_END = 0.62 -- pulled up: waist at the ledge
-- Hanging: the root is this far from the wall, and this far under the ledge.
-- (Checked against the "Climb" clip: with these values the hands of the
-- hanging pose land on the ledge, and the hands of the "pulled up" pose
-- press on it. Change the clip's arm angles → re-tune these.)
local HANG_DISTANCE = 0.7
local HANG_DEPTH = 1.7
-- End of the pull: the root is this high above the ledge (waist on it).
local WAIST_HEIGHT = 0.65

type Action = "Slide" | "Climb" | "Vault"

type ActionState = {
	kind: Action,
	startedAt: number,
	confirmed: boolean,
	-- Slide
	direction: Vector3,
	velocity: LinearVelocity?,
	attachment: Attachment?,
	-- Climb / vault
	duration: number,
	from: Vector3, -- root position at the start
	fromLook: Vector3, -- where the body was facing at the start
	hang: Vector3, -- mantle: root position while hanging
	waist: Vector3, -- mantle: root position at the end of the pull
	control: Vector3, -- vault: top of the arc
	to: Vector3, -- root position at the end, standing on the ledge
	exitSpeed: number,
}

local ParkourController = {}

local crouched = false
local action: ActionState? = nil
local lastSlideAt = -math.huge
local lastClimbAt = -math.huge

local humanoid: Humanoid? = nil
local root: BasePart? = nil

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

-- Blocking or stunned (combat): no slide, no climb (same rule as the server).
local function isFightLocked(): boolean
	local character = player.Character
	return character ~= nil
		and (
			character:GetAttribute("Stunned") == true
			or character:GetAttribute("Blocking") == true
		)
end

local function staminaAtLeast(cost: number): boolean
	local stamina = player:GetAttribute("Stamina")
	return typeof(stamina) == "number" and stamina >= cost
end

-- No jumping while crouched or during a climb (jump = stand up instead).
local function updateJumpAllowed()
	local current = humanoid
	if current then
		local allowed = not crouched and not (action and action.kind ~= "Slide")
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
		-- The server makes us crouch when its slide timer ends; we match it.
		-- (Server ignores crouch changes during the slide, so no need to send.)
		setCrouched(not standUp, false)
		if standUp then
			Remotes.RequestMoveAction:FireServer("Cancel")
			Remotes.SetCrouching:FireServer(false)
		end
	else
		updateJumpAllowed()
		local part = root
		if part and not standUp then
			-- Finished normally: leave with some speed, and tell the server
			-- (its timer is the LONGEST a climb can take).
			part.AssemblyLinearVelocity = current.direction * current.exitSpeed
			Remotes.RequestMoveAction:FireServer("Cancel")
		end
	end
end

------------------------------------------------------------------------------
-- Slide
------------------------------------------------------------------------------

local function canSlide(now: number): boolean
	local current, part = humanoid, root
	if current == nil or part == nil or action ~= nil or isFightLocked() then
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
		duration = Config.Slide.DURATION,
		from = part.Position,
		fromLook = direction,
		hang = part.Position,
		waist = part.Position,
		control = part.Position,
		to = part.Position,
		exitSpeed = 0,
	}
	lastSlideAt = now
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
	if character == nil or part == nil or action ~= nil or isFightLocked() then
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
	local edge = ledge.edge
	local vault = Ledge.isVault(ledge)
	local kind: Action = if vault then "Vault" else "Climb"

	-- Mantle key positions (see the phases at the top of this file).
	local wallSide = edge - ledge.facing * HANG_DISTANCE
	local waist = Vector3.new(wallSide.X, edge.Y + WAIST_HEIGHT, wallSide.Z)
	-- Hang under the ledge — but never go DOWN to get there (low ledge, or
	-- grabbed at the top of a jump): then we hang from where we are.
	local hangY = math.min(math.max(edge.Y - HANG_DEPTH, from.Y), waist.Y)
	local hang = Vector3.new(wallSide.X, hangY, wallSide.Z)

	-- Vault: one smooth arc passing just above the obstacle.
	local control = edge + Vector3.new(0, Config.Character.ROOT_TO_FEET, 0)
	local entrySpeed = horizontalVelocity(part).Magnitude

	CameraController.holdRotation("parkour", true)
	crouched = false
	action = {
		kind = kind,
		startedAt = now,
		confirmed = false,
		direction = ledge.facing,
		velocity = nil,
		attachment = nil,
		duration = Ledge.duration(ledge),
		from = from,
		fromLook = part.CFrame.LookVector,
		hang = hang,
		waist = waist,
		control = control,
		to = ledge.target,
		-- A vault keeps your momentum; a mantle ends almost still.
		exitSpeed = if vault
			then math.max(entrySpeed, Config.Character.WALK_SPEED)
			else MANTLE_EXIT_SPEED,
	}
	updateJumpAllowed()
	lastClimbAt = now
	Remotes.RequestMoveAction:FireServer(kind)
end

local function smoothstep(k: number): number
	return k * k * (3 - 2 * k) -- slow start, slow end
end

-- How far we are inside a phase: 0 at `from`, 1 at `to`.
local function phase(u: number, from: number, to: number): number
	return math.clamp((u - from) / (to - from), 0, 1)
end

-- Root position of a mantle at progress u (0 → 1).
local function mantlePosition(current: ActionState, u: number): Vector3
	if u < MANTLE_CATCH_END then
		-- Catch: fast at first, settling on the ledge ("ease out").
		local k = phase(u, 0, MANTLE_CATCH_END)
		return current.from:Lerp(current.hang, 1 - (1 - k) * (1 - k))
	elseif u < MANTLE_HANG_END then
		return current.hang -- hanging: only the legs move (animation)
	elseif u < MANTLE_PULL_END then
		local k = smoothstep(phase(u, MANTLE_HANG_END, MANTLE_PULL_END))
		return current.hang:Lerp(current.waist, k)
	end
	-- Step up: rise first, then move forward onto the ledge (Bézier curve).
	local k = smoothstep(phase(u, MANTLE_PULL_END, 1))
	local corner = Vector3.new(current.waist.X, current.to.Y + 0.3, current.waist.Z)
	local a = current.waist:Lerp(corner, k)
	local b = corner:Lerp(current.to, k)
	return a:Lerp(b, k)
end

-- Root position of a vault at progress u: one arc from → control → to.
local function vaultPosition(current: ActionState, u: number): Vector3
	local a = current.from:Lerp(current.control, u)
	local b = current.control:Lerp(current.to, u)
	return a:Lerp(b, u)
end

-- Runs just BEFORE each physics step, so physics starts from our position.
local function updateClimb(current: ActionState, elapsed: number)
	local part = root :: BasePart
	local u = math.clamp(elapsed / current.duration, 0, 1)

	local position = if current.kind == "Vault"
		then vaultPosition(current, u)
		else mantlePosition(current, u)

	-- Turn to face the wall during the first moments (no instant snap).
	local turn = smoothstep(phase(u, 0, 0.15))
	local look = current.fromLook:Lerp(current.direction, turn)
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 1e-3 then
		look = current.direction
	end

	part.CFrame = CFrame.lookAt(position, position + look)
	part.AssemblyLinearVelocity = Vector3.zero -- cancel gravity for this step

	if u >= 1 then
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

------------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------------

local function onCrouchKey()
	if not isAlive() or (action and action.kind ~= "Slide") then
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

local function onCharacterAdded(character: Model)
	-- Forget everything about the previous life.
	endAction(true)
	humanoid = nil
	root = nil
	crouched = false

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
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

-- What OUR character is doing right now, as we predict it (no network delay):
-- "Slide", "Climb", "Vault", "Crouch", or nil (standing: walk / sprint).
-- Used by CharacterAnimationController to animate our own character.
function ParkourController.getVisualState(): Types.MoveState?
	if action then
		return action.kind
	elseif crouched then
		return "Crouch"
	end
	return nil
end

-- Progress (0 → 1) of our current climb / vault, nil otherwise. Lets the
-- animation follow the body's movement exactly.
function ParkourController.getClimbProgress(): number?
	local current = action
	if current and current.kind ~= "Slide" then
		return math.clamp((os.clock() - current.startedAt) / current.duration, 0, 1)
	end
	return nil
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
end

return ParkourController
