--!strict
-- Movement rules shared by the server AND the client.
--
-- Why shared? The server decides the real movement state, but the client
-- applies the same rules instantly ("prediction") so sprinting feels
-- responsive instead of waiting for a server round trip. Same function on
-- both sides = they agree almost all the time.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local MovementRules = {}

-- What the player WANTS (keys held) + whether they are exhausted
-- → the movement state they actually get.
function MovementRules.resolve(
	wantSprint: boolean,
	wantCrouch: boolean,
	exhausted: boolean
): Types.MoveState
	-- (`:: Types.MoveState` tells the type checker these strings are valid states.)
	if wantSprint and not exhausted then
		return "Sprint" :: Types.MoveState
	elseif wantCrouch then
		return "Crouch" :: Types.MoveState
	end
	return "Walk" :: Types.MoveState
end

local SPEEDS: { [Types.MoveState]: number } = {
	Walk = Config.MOVEMENT.WALK_SPEED,
	Sprint = Config.MOVEMENT.SPRINT_SPEED,
	Crouch = Config.MOVEMENT.CROUCH_SPEED,
}

function MovementRules.speedFor(state: Types.MoveState): number
	return SPEEDS[state]
end

-- Accepts only the exact strings of Types.MoveState (used when reading attributes).
function MovementRules.isMoveState(value: unknown): boolean
	return value == "Walk" or value == "Sprint" or value == "Crouch"
end

return table.freeze(MovementRules)
