--!strict
-- The shotgun's action timelines (seconds). PLACEHOLDER from ARCHITECTURE §8.2:
-- tools/anim/gun_clips.py --write will regenerate this file from the clips. Owned by
-- the shotgun's agent.
--
-- Tube reload: ShellStart, then ShellLoop once per missing shell (shell_insert = +1
-- from the reserve), then ShellEnd. Cancel after any shell_insert. Empty with the
-- bolt locked back: PortLoad first (a shell dropped in the port, bolt released).

local Types = require(script.Parent.Parent.Types)

local timelines: Types.Timelines = {
	Draw = {
		length = 1.0,
		events = { { time = 0.3, name = "draw_grip" }, { time = 0.7, name = "support_grip" } },
	},
	Holster = {
		length = 0.8,
		events = { { time = 0.65, name = "holster_seat", snap = true } },
	},
	ShellStart = {
		length = 0.40,
		events = {},
		cancelUntil = 0.40,
	},
	ShellLoop = {
		length = 0.50,
		events = {
			{ time = 0.10, name = "shell_grab" },
			{ time = 0.38, name = "shell_insert", snap = true },
		},
		commitAt = 0.38,
		cancelUntil = 0.50,
		loop = true,
	},
	ShellEnd = {
		length = 0.35,
		events = {},
	},
	PortLoad = {
		length = 0.9,
		events = {
			{ time = 0.20, name = "shell_grab" },
			{ time = 0.55, name = "port_load", snap = true },
			{ time = 0.70, name = "bolt_release_press", snap = true },
		},
		commitAt = 0.70,
		cancelUntil = 0.50,
	},
}

return table.freeze(timelines)
