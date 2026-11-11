--!strict
-- Stamina: how tired each player is. Owned by the SERVER only.
--
-- Big picture:
--   • Every player has a stamina value between 0 and Config.STAMINA.MAX.
--   • Gameplay systems spend it (sprint now; dash, block, attacks later)
--     through Stamina.consume() / Stamina.drain().
--   • After Config.STAMINA.REGEN_DELAY seconds without spending, it refills.
--   • Hitting 0 makes the player "exhausted" until stamina is back to
--     Config.STAMINA.RECOVER_THRESHOLD (no sprint meanwhile).
--   • Full refill on respawn.
--
-- The client only READS two Player attributes, for the HUD and for movement
-- prediction: "Stamina" (whole number) and "Exhausted" (boolean).
-- A client changing its own attributes changes nothing on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local MAX = Config.STAMINA.MAX

type State = {
	value: number, -- exact value (decimals)
	regenAt: number, -- os.clock() time after which regen can start
	exhausted: boolean,
	sentValue: number, -- last whole number written to the attribute
}

local Stamina = {}

local states: { [Player]: State } = {}

-- Writes the attributes only when what the client sees actually changes
-- (whole numbers): avoids sending 60 network updates per second for decimals.
local function publish(player: Player, state: State)
	local rounded = math.floor(state.value + 0.5)
	if rounded ~= state.sentValue then
		state.sentValue = rounded
		player:SetAttribute("Stamina", rounded)
	end
	if player:GetAttribute("Exhausted") ~= state.exhausted then
		player:SetAttribute("Exhausted", state.exhausted)
	end
end

local function refill(player: Player)
	local state = states[player]
	if state then
		state.value = MAX
		state.exhausted = false
		state.regenAt = 0
		publish(player, state)
	end
end

-- Common part of consume() and drain(): removes `amount`, delays regen,
-- and flags exhaustion when empty.
local function spend(player: Player, state: State, amount: number)
	state.value = math.max(0, state.value - amount)
	state.regenAt = os.clock() + Config.STAMINA.REGEN_DELAY
	if state.value <= 0 then
		state.exhausted = true
	end
	publish(player, state)
end

local function assertAmount(amount: number)
	-- `amount == amount` is false only for NaN.
	assert(
		typeof(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge,
		`stamina amount must be a finite number >= 0, got {amount}`
	)
end

------------------------------------------------------------------------------
-- Public API (for other server systems)
------------------------------------------------------------------------------

function Stamina.get(player: Player): number
	local state = states[player]
	return if state then state.value else 0
end

function Stamina.isExhausted(player: Player): boolean
	local state = states[player]
	return if state then state.exhausted else true
end

-- All-or-nothing spend, for actions with a fixed cost (a dash, a heavy attack).
-- Returns false (and spends nothing) if the player doesn't have enough.
function Stamina.consume(player: Player, amount: number): boolean
	assertAmount(amount)
	local state = states[player]
	if state == nil or state.exhausted or state.value < amount then
		return false
	end
	spend(player, state, amount)
	return true
end

-- Continuous spend, for actions that last (sprinting): takes what is left,
-- even if it's less than `amount`. Returns false if the player is now empty.
function Stamina.drain(player: Player, amount: number): boolean
	assertAmount(amount)
	local state = states[player]
	if state == nil then
		return false
	end
	spend(player, state, amount)
	return state.value > 0
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	states[player] = { value = MAX, regenAt = 0, exhausted = false, sentValue = -1 }
	refill(player)
	player.CharacterAdded:Connect(function()
		refill(player)
	end)
end

local function onHeartbeat(dt: number)
	local now = os.clock()
	for player, state in states do
		if state.value < MAX and now >= state.regenAt then
			state.value = math.min(MAX, state.value + Config.STAMINA.REGEN_PER_SECOND * dt)
			if state.exhausted and state.value >= Config.STAMINA.RECOVER_THRESHOLD then
				state.exhausted = false
			end
			publish(player, state)
		end
	end
end

-- Players are tracked from init() (not start()) so that other systems can
-- already call Stamina.get() / consume() in their own start().
function Stamina.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	-- Players who joined before this script ran (happens in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function Stamina.start()
	RunService.Heartbeat:Connect(onHeartbeat)
end

return Stamina
