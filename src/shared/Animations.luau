--!strict
-- Animation IDs of the game. Empty string = not made yet (the game just skips it).
--
-- How to fill one in: see docs/ANIMATIONS_FR.md.
-- Format: "rbxassetid://123456789"

-- name → animation id
type AnimationList = { [string]: string }

local MOVEMENT: AnimationList = {
	SPRINT = "", -- loop, priority Movement
	CROUCH_IDLE = "", -- loop, priority Movement
	CROUCH_WALK = "", -- loop, priority Movement
}

return table.freeze({
	MOVEMENT = table.freeze(MOVEMENT),
})
