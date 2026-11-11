--!strict
-- Animation IDs of the game (R6). Empty string = not made yet: the game just
-- skips it (the default Roblox animations play instead).
--
-- How to make one and get its ID: docs/ANIMATIONS_FR.md.
-- Format: "rbxassetid://123456789"

-- name → animation id
type AnimationList = { [string]: string }

-- Movement animations, played by Client/Controllers/ParkourController.
local MOVEMENT: AnimationList = {
	CrouchIdle = "", -- loop, priority Movement
	CrouchWalk = "", -- loop, priority Movement
	Slide = "", -- loop, priority Action
	Climb = "", -- NOT looped, priority Action, about 0.5 s
}

return table.freeze({
	MOVEMENT = table.freeze(MOVEMENT),
})
