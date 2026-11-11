--!strict
-- Movement: walking, sprinting, crouching, sliding and ledge climbing.
-- The SERVER decides every player's movement state and speed.
--
-- How it works:
--   1. The client sends WISHES: Shift held (SetSprinting), crouch toggled
--      (SetCrouching), "I start a slide / a climb" (RequestMoveAction).
--   2. Every frame, for each player, the server checks: alive? moving?
--      enough stamina? cooldown? Then it picks the real state, drains
--      stamina and sets Humanoid.WalkSpeed.
--   3. The state is published as Player attributes, read by the client:
--        "MoveState"  — Types.MoveState ("Walk", "Sprint", "Crouch", "Slide", "Climb", "Vault")
--        "Sprinting"  — true/false (camera FOV effect)
--
-- Slide and climb are short "actions". The client starts them instantly
-- (otherwise they'd feel late by the network delay) and moves its own
-- character; the server checks the request and confirms it by setting
-- "MoveState". If the server refuses, the client sees no confirmation and
-- stops. Server rules always win.
--
-- Security note: Roblox lets each client move its own character, so a cheater
-- could still fake the motion itself. What's guaranteed here: stamina,
-- cooldowns and the official state (used by combat later) are server-decided.
-- A server-side speed / teleport check will come in its own anti-cheat system.
--
-- Speed modifiers: other systems (injuries, slows, stuns...) change the speed
-- through Movement.setSpeedModifier(), never by setting WalkSpeed themselves.
-- Final speed = base speed × every modifier.
--
--   Movement.setSpeedModifier(player, "Limp", 0.75)  -- 25 % slower
--   Movement.setSpeedModifier(player, "Limp", nil)   -- remove it

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ledge = require(ReplicatedStorage.Shared.Ledge)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Stamina = require(script.Parent.Stamina)

type Action = "Slide" | "Climb" | "Vault"

type State = {
	wantsToSprint: boolean,
	crouching: boolean,
	modifiers: { [string]: number },
	-- Current short action (nil = none) and when it ends (os.clock()).
	action: Action?,
	actionEndsAt: number,
	-- os.clock() of the last accepted slide / climb (cooldowns).
	lastSlideAt: number,
	lastClimbAt: number,
	-- Was the player really sprinting last frame? (a slide needs it)
	wasSprinting: boolean,
}

local Movement = {}

local states: { [Player]: State } = {}

local function getState(player: Player): State
	local state = states[player]
	if state == nil then
		state = {
			wantsToSprint = false,
			crouching = false,
			modifiers = {},
			action = nil,
			actionEndsAt = 0,
			lastSlideAt = -math.huge,
			lastClimbAt = -math.huge,
			wasSprinting = false,
		}
		states[player] = state
	end
	return state
end

local function getAliveHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function horizontalSpeed(humanoid: Humanoid): number
	local root = humanoid.RootPart
	if root == nil then
		return 0
	end
	local velocity = root.AssemblyLinearVelocity
	-- Horizontal only: falling or jumping in place isn't "moving".
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function isOnGround(humanoid: Humanoid): boolean
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

local function setAttributeIfChanged(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function updatePlayer(player: Player, state: State, now: number, dt: number)
	local humanoid = getAliveHumanoid(player)
	local moveState: Types.MoveState = "Walk"
	local sprinting = false

	if humanoid then
		-- An action that just finished: a slide always ends crouched.
		if state.action and now >= state.actionEndsAt then
			if state.action == "Slide" then
				state.crouching = true
			end
			state.action = nil
		end

		if state.action then
			moveState = state.action :: Types.MoveState
		elseif state.crouching then
			moveState = "Crouch"
		elseif
			state.wantsToSprint
			and not Stamina.isExhausted(player)
			and horizontalSpeed(humanoid) > Config.Character.MOVING_THRESHOLD
		then
			sprinting = Stamina.drain(player, Config.Stamina.SPRINT_DRAIN_PER_SECOND * dt)
			if sprinting then
				moveState = "Sprint"
			end
		end

		-- During a slide / climb the CLIENT moves the body directly, so
		-- WalkSpeed doesn't matter; we keep the walk speed for when it ends.
		local speed = if moveState == "Sprint"
			then Config.Character.SPRINT_SPEED
			elseif moveState == "Crouch" then Config.Character.CROUCH_SPEED
			else Config.Character.WALK_SPEED
		for _, multiplier in state.modifiers do
			speed *= multiplier
		end
		if humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
	end

	state.wasSprinting = sprinting
	setAttributeIfChanged(player, "Sprinting", sprinting)
	setAttributeIfChanged(player, "MoveState", moveState)
end

local function update(dt: number)
	local now = os.clock()
	for player, state in states do
		updatePlayer(player, state, now, dt)
	end
end

------------------------------------------------------------------------------
-- Actions (slide / climb): checked here, then confirmed via "MoveState"
------------------------------------------------------------------------------

local function tryStartSlide(player: Player, state: State, humanoid: Humanoid, now: number)
	local slide = Config.Slide
	if
		not state.wasSprinting
		or not isOnGround(humanoid)
		or horizontalSpeed(humanoid) < slide.MIN_SPEED
		or now - state.lastSlideAt < slide.COOLDOWN
	then
		return
	end
	if not Stamina.trySpend(player, slide.STAMINA_COST) then
		return
	end
	state.action = "Slide"
	state.actionEndsAt = now + slide.DURATION
	state.lastSlideAt = now
	state.crouching = false
end

-- `kind`: "Climb" (mantle) or "Vault". The client picks it from the ledge's
-- height; it only changes which animation the other players see, so we
-- accept its choice. What we DO check: cooldown, stamina, and that a
-- climbable ledge really is in front of the character.
local function tryStartClimb(player: Player, state: State, kind: Action, now: number)
	local climb = Config.Climb
	local character = player.Character
	if character == nil or now - state.lastClimbAt < climb.COOLDOWN then
		return
	end
	-- The server looks for the ledge ITSELF (with a tolerance for lag).
	if Ledge.find(character, climb.SERVER_TOLERANCE) == nil then
		return
	end
	if not Stamina.trySpend(player, climb.STAMINA_COST) then
		return
	end
	state.action = kind
	-- Longest it can last. The client says "Cancel" when it's really done
	-- (a low ledge takes less time).
	state.actionEndsAt = now
		+ (if kind == "Vault" then climb.VAULT_DURATION else climb.MAX_DURATION)
	state.lastClimbAt = now
	state.crouching = false
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

-- `multiplier` = nil removes the modifier. Must be a number between 0 and 2.
function Movement.setSpeedModifier(player: Player, key: string, multiplier: number?)
	local modifiers = getState(player).modifiers
	if multiplier == nil then
		modifiers[key] = nil
		return
	end
	assert(
		multiplier >= 0 and multiplier <= 2,
		`speed multiplier must be between 0 and 2, got {multiplier}`
	)
	modifiers[key] = multiplier
end

-- The player's current movement state (combat will use it: e.g. no
-- blocking while climbing).
function Movement.getMoveState(player: Player): Types.MoveState
	local value = player:GetAttribute("MoveState")
	return if typeof(value) == "string" then value :: Types.MoveState else "Walk"
end

------------------------------------------------------------------------------
-- Remote handlers (everything coming from clients is untrusted)
------------------------------------------------------------------------------

-- Burst of 10, then 5 per second: far more than a human tapping a key.
local sprintLimiter = RateLimiter.new(10, 5)
local crouchLimiter = RateLimiter.new(10, 5)
local actionLimiter = RateLimiter.new(6, 3)

local function onSetSprinting(player: Player, wantsToSprint: unknown)
	if typeof(wantsToSprint) ~= "boolean" then
		return
	end
	-- Stopping is always accepted (harmless). Rate-limiting a "stop" could
	-- leave a player stuck sprinting.
	if wantsToSprint and not sprintLimiter.allow(player) then
		return
	end
	-- states[player] (not getState): never re-create a player who already left.
	local state = states[player]
	if state then
		state.wantsToSprint = wantsToSprint
	end
end

local function onSetCrouching(player: Player, crouching: unknown)
	if typeof(crouching) ~= "boolean" or not crouchLimiter.allow(player) then
		return
	end
	local state = states[player]
	if state == nil then
		return
	end
	-- Can't change stance in the middle of a slide / climb.
	if state.action == nil then
		state.crouching = crouching
	end
end

local function onRequestMoveAction(player: Player, action: unknown)
	if not actionLimiter.allow(player) then
		return
	end
	local humanoid = getAliveHumanoid(player)
	local state = states[player]
	if humanoid == nil or state == nil then
		return
	end
	local now = os.clock()

	if action == "Cancel" then
		-- The client's move is over: jumped out of a slide (stand up), or
		-- finished a climb. Ending early is always harmless: stamina and
		-- cooldown were already paid when it started.
		state.action = nil
		state.crouching = false
		return
	end

	if state.action ~= nil then
		return -- one action at a time
	end
	if action == "Slide" then
		tryStartSlide(player, state, humanoid, now)
	elseif action == "Climb" or action == "Vault" then
		tryStartClimb(player, state, action :: Action, now)
	end
	-- Anything else (wrong type, unknown name) is ignored.
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local state = getState(player)
	-- Every new life starts standing, with no action going on.
	player.CharacterAdded:Connect(function()
		state.crouching = false
		state.action = nil
		state.wasSprinting = false
	end)
end

function Movement.start()
	Remotes.SetSprinting.OnServerEvent:Connect(onSetSprinting)
	Remotes.SetCrouching.OnServerEvent:Connect(onSetCrouching)
	Remotes.RequestMoveAction.OnServerEvent:Connect(onRequestMoveAction)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(update)
end

return Movement
