--!strict
-- The rifle's action timelines (seconds). PLACEHOLDER from ARCHITECTURE §8.2:
-- tools/anim/gun_clips.py --write will regenerate this file from the clips. Owned by
-- the rifle's agent. No hold-open: an empty reload ends on the charging handle.

local Types = require(script.Parent.Parent.Types)

local timelines: Types.Timelines = {
	Draw = {
		length = 0.95,
		events = { { time = 0.28, name = "draw_grip" }, { time = 0.66, name = "support_grip" } },
	},
	Holster = {
		length = 0.75,
		events = { { time = 0.62, name = "holster_seat", snap = true } },
	},
	ReloadTactical = {
		length = 2.6,
		events = {
			{ time = 0.75, name = "mag_grab" },
			{ time = 1.12, name = "mag_release" },
			{ time = 1.15, name = "mag_drop" },
			{ time = 1.62, name = "mag_insert", snap = true },
		},
		commitAt = 1.62,
		cancelUntil = 1.55,
	},
	ReloadEmpty = {
		length = 3.2,
		events = {
			{ time = 0.75, name = "mag_grab" },
			{ time = 1.12, name = "mag_release" },
			{ time = 1.15, name = "mag_drop" },
			{ time = 1.62, name = "mag_insert", snap = true },
			{ time = 2.10, name = "charge_back" },
			{ time = 2.18, name = "charge_release", snap = true },
		},
		commitAt = 1.62,
		cancelUntil = 1.55,
	},
	ReloadInsert = {
		length = 1.9,
		events = {
			{ time = 0.55, name = "mag_grab" },
			{ time = 1.0, name = "mag_insert", snap = true },
			{ time = 1.45, name = "charge_back" },
			{ time = 1.52, name = "charge_release", snap = true },
		},
		commitAt = 1.0,
		cancelUntil = 0.95,
	},
	Charge = {
		length = 0.8,
		events = {
			{ time = 0.30, name = "charge_back" },
			{ time = 0.38, name = "charge_release", snap = true },
		},
		commitAt = 0.38,
		cancelUntil = 0.25,
	},
}

return table.freeze(timelines)
