--!strict
-- Every key of the game in one place. Change a key here, it changes everywhere.
-- (PC first; gamepad / mobile buttons will be added next to these later.)

return table.freeze({
	SPRINT = Enum.KeyCode.LeftShift, -- hold
	CROUCH = Enum.KeyCode.C, -- toggle
	TOGGLE_SHIFT_LOCK = Enum.KeyCode.LeftControl, -- toggle (third person only)
})
