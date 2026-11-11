--!strict
-- Movement: decides how fast each character moves (walk / sprint / crouch).
--
-- Big picture:
--   • The client sends which keys it holds (Remotes.SetMovementInput).
--     That's only an INTENT.
--   • Every frame, the server turns that intent into the real state with
--     MovementRules.resolve() (the same rules the client predicts with),
--     drains stamina while sprinting, and sets Humanoid.WalkSpeed.
--   • The real state is published as the character attribute "MoveState",
--     so every client can play the right animations, and the owner can
--     correct its prediction.
--
-- Security note: Roblox lets each client simulate its own character, so an
-- exploiter CAN still change their WalkSpeed locally. What this system
-- guarantees is that the official state (used later by combat: "can't
-- attack while sprinting", stamina...) is server-decided. A server-side
-- speed check (anti-cheat) will come in its own system.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local MovementRules = require(ReplicatedStorage.Shared.MovementRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Stamina = require(script.Parent.Stamina)

type Intent = { sprint: boolean, crouch: boolean }

local Movement = {}

local intents: { [Player]: Intent } = {}
-- Last state applied to each player's CURRENT character (nil = apply on next frame).
local applied: { [Player]: Types.MoveState? } = {}

-- Generous: a player mashing keys sends maybe 10 messages per second.
local inputLimiter = RateLimiter.new(20, 15)

local function getIntent(player: Player): Intent
	local intent = intents[player]
	if intent == nil then
		intent = { sprint = false, crouch = false }
		intents[player] = intent
	end
	return intent
end

-- The live Humanoid + root part of a player, or nil if dead / not spawned.
local function getBody(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

local function isMoving(root: BasePart): boolean
	local velocity = root.AssemblyLinearVelocity
	-- Horizontal speed only: falling straight down isn't "running".
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	return horizontal > Config.MOVEMENT.MOVING_SPEED_THRESHOLD
end

local function updatePlayer(player: Player, dt: number)
	local humanoid, root = getBody(player)
	if humanoid == nil or root == nil then
		return
	end

	local intent = getIntent(player)
	local state: Types.MoveState =
		MovementRules.resolve(intent.sprint, intent.crouch, Stamina.isExhausted(player))

	-- Sprinting only tires you when you actually move.
	if state == "Sprint" and isMoving(root) then
		local stillHasStamina = Stamina.drain(player, Config.MOVEMENT.SPRINT_DRAIN_PER_SECOND * dt)
		if not stillHasStamina then
			-- Just ran out: exhausted now, so resolve() gives the fallback state.
			state = MovementRules.resolve(false, intent.crouch, true)
		end
	end

	if applied[player] ~= state then
		applied[player] = state
		humanoid.WalkSpeed = MovementRules.speedFor(state)
		local character = player.Character :: Model
		character:SetAttribute("MoveState", state)
	end
end

------------------------------------------------------------------------------
-- Remote handlers (everything coming from clients is untrusted)
------------------------------------------------------------------------------

local function onSetMovementInput(player: Player, wantSprint: unknown, wantCrouch: unknown)
	if not inputLimiter.allow(player) then
		return
	end
	if typeof(wantSprint) ~= "boolean" or typeof(wantCrouch) ~= "boolean" then
		return
	end
	local intent = getIntent(player)
	intent.sprint = wantSprint
	intent.crouch = wantCrouch
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	-- Roblox's built-in shift-lock uses Shift, which is our sprint key.
	-- We have our own shift-lock (Client/Controllers/CameraController).
	player.DevEnableMouseLock = false

	player.CharacterAdded:Connect(function()
		-- New body: forget the old state so the next frame applies it.
		-- Keys are reset too (the client re-sends them on respawn).
		applied[player] = nil
		intents[player] = nil
	end)
end

function Movement.init()
	-- Same reason as DevEnableMouseLock above, for players joining later.
	StarterPlayer.EnableMouseLockOption = false
	StarterPlayer.CharacterWalkSpeed = Config.MOVEMENT.WALK_SPEED
end

function Movement.start()
	Remotes.SetMovementInput.OnServerEvent:Connect(onSetMovementInput)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		intents[player] = nil
		applied[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	RunService.Heartbeat:Connect(function(dt)
		for _, player in Players:GetPlayers() do
			updatePlayer(player, dt)
		end
	end)
end

return Movement
