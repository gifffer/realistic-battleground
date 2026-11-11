--!strict
-- Movement: sprinting and walk speed. The SERVER decides every player's speed.
--
-- How sprinting works:
--   1. The client presses / releases Shift → Remotes.SetSprinting(true/false).
--      That's only a WISH ("I want to sprint").
--   2. Every frame, for each player who wishes to sprint, the server checks:
--      alive? actually moving? not exhausted? Then it drains stamina and
--      sets Humanoid.WalkSpeed to the sprint speed. Otherwise: walk speed.
--   3. The "Sprinting" attribute on the Player tells the client it's really
--      sprinting (used for the camera FOV effect).
--
-- Speed modifiers: other systems (injuries, slows, stuns...) will change the
-- speed through Movement.setSpeedModifier(), never by setting WalkSpeed
-- themselves. Final speed = base speed × every modifier.
--
--   Movement.setSpeedModifier(player, "Limp", 0.75)  -- 25 % slower
--   Movement.setSpeedModifier(player, "Limp", nil)   -- remove it
--
-- Sprint locks: some actions forbid sprinting (blocking, attacking, being
-- stunned). Same idea, by name:
--   Movement.setSprintLock(player, "Block", true)   -- can't sprint
--   Movement.setSprintLock(player, "Block", false)  -- lock removed

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Stamina = require(script.Parent.Stamina)

type State = {
	wantsToSprint: boolean,
	modifiers: { [string]: number },
	sprintLocks: { [string]: boolean },
}

local Movement = {}

local states: { [Player]: State } = {}

local function getState(player: Player): State
	local state = states[player]
	if state == nil then
		state = { wantsToSprint = false, modifiers = {}, sprintLocks = {} }
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

local function isMoving(humanoid: Humanoid): boolean
	local root = humanoid.RootPart
	if root == nil then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	-- Horizontal speed only: falling or jumping in place isn't "moving".
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	return horizontalSpeed > Config.Character.MOVING_THRESHOLD
end

local function update(dt: number)
	for player, state in states do
		local humanoid = getAliveHumanoid(player)
		local sprinting = false

		if humanoid then
			if
				state.wantsToSprint
				and next(state.sprintLocks) == nil
				and not Stamina.isExhausted(player)
				and isMoving(humanoid)
			then
				sprinting = Stamina.drain(player, Config.Stamina.SPRINT_DRAIN_PER_SECOND * dt)
			end

			local speed = if sprinting
				then Config.Character.SPRINT_SPEED
				else Config.Character.WALK_SPEED
			for _, multiplier in state.modifiers do
				speed *= multiplier
			end
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
		end

		if player:GetAttribute("Sprinting") ~= sprinting then
			player:SetAttribute("Sprinting", sprinting)
		end
	end
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

function Movement.setSprintLock(player: Player, key: string, locked: boolean)
	local locks = getState(player).sprintLocks
	if locked then
		locks[key] = true
	else
		locks[key] = nil
	end
end

------------------------------------------------------------------------------
-- Remote handlers (everything coming from clients is untrusted)
------------------------------------------------------------------------------

-- Burst of 10, then 5 per second: far more than a human tapping Shift.
local sprintLimiter = RateLimiter.new(10, 5)

local function onSetSprinting(player: Player, wantsToSprint: unknown)
	if typeof(wantsToSprint) ~= "boolean" then
		return
	end
	-- Stopping is always accepted (harmless). Rate-limiting a "stop" could
	-- leave a player stuck sprinting.
	if wantsToSprint and not sprintLimiter.allow(player) then
		return
	end
	getState(player).wantsToSprint = wantsToSprint
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function Movement.start()
	Remotes.SetSprinting.OnServerEvent:Connect(onSetSprinting)

	Players.PlayerAdded:Connect(getState)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		getState(player)
	end

	RunService.Heartbeat:Connect(update)
end

return Movement
