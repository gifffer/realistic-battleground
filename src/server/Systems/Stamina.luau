--!strict
-- Stamina: every player's energy bar. The SERVER owns the real value.
--
-- Sprinting (Movement system) drains it; later, dashing and blocking will
-- spend it too. It refills after Config.Stamina.REGEN_DELAY seconds without
-- spending anything.
--
-- The client only DISPLAYS stamina. It reads two attributes that the server
-- sets on the Player object (attributes replicate automatically):
--   "Stamina"          number, rounded to a whole number
--   "StaminaExhausted" boolean, true after hitting 0 (until it recovers)
--
-- API for other server systems:
--   Stamina.get(player)            → current value
--   Stamina.isExhausted(player)    → true = can't sprint yet
--   Stamina.trySpend(player, cost) → all-or-nothing (future: dash costs 25)
--   Stamina.drain(player, amount)  → takes what's left (sprinting each frame)
--   Stamina.refill(player)         → back to full (respawn, duel round...)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local MAX = Config.Stamina.MAX

type State = {
	value: number,
	lastSpentAt: number, -- os.clock() of the last spending
	exhausted: boolean,
}

local Stamina = {}

local states: { [Player]: State } = {}

-- Copies the state to the player's attributes, only when the DISPLAYED value
-- changes (avoids sending a network update every frame for nothing).
local function publish(player: Player, state: State)
	local shown = math.round(state.value)
	if player:GetAttribute("Stamina") ~= shown then
		player:SetAttribute("Stamina", shown)
	end
	if player:GetAttribute("StaminaExhausted") ~= state.exhausted then
		player:SetAttribute("StaminaExhausted", state.exhausted)
	end
end

local function spend(player: Player, state: State, amount: number)
	state.value = math.max(0, state.value - amount)
	state.lastSpentAt = os.clock()
	if state.value <= 0 then
		state.exhausted = true
	end
	publish(player, state)
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

function Stamina.get(player: Player): number
	local state = states[player]
	return if state then state.value else 0
end

function Stamina.isExhausted(player: Player): boolean
	local state = states[player]
	return state == nil or state.exhausted
end

-- Spends `cost` only if the player has enough. Returns true if spent.
function Stamina.trySpend(player: Player, cost: number): boolean
	local state = states[player]
	if state == nil or state.value < cost then
		return false
	end
	spend(player, state, cost)
	return true
end

-- Spends up to `amount` (whatever is left). Returns false if there was
-- nothing left to spend.
function Stamina.drain(player: Player, amount: number): boolean
	local state = states[player]
	if state == nil or state.value <= 0 then
		return false
	end
	spend(player, state, amount)
	return true
end

function Stamina.refill(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	state.value = MAX
	state.exhausted = false
	publish(player, state)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function regenerate(dt: number)
	local now = os.clock()
	for player, state in states do
		if state.value < MAX and now - state.lastSpentAt >= Config.Stamina.REGEN_DELAY then
			state.value = math.min(MAX, state.value + Config.Stamina.REGEN_PER_SECOND * dt)
			if state.exhausted and state.value >= Config.Stamina.EXHAUSTED_RECOVER_AT then
				state.exhausted = false
			end
			publish(player, state)
		end
	end
end

local function onPlayerAdded(player: Player)
	local state: State = { value = MAX, lastSpentAt = 0, exhausted = false }
	states[player] = state
	publish(player, state)

	-- Every new life starts with full stamina.
	player.CharacterAdded:Connect(function()
		Stamina.refill(player)
	end)
end

function Stamina.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if states[player] == nil then
			onPlayerAdded(player)
		end
	end

	RunService.Heartbeat:Connect(regenerate)
end

return Stamina
