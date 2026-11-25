--!strict
-- The sniper's action timelines (seconds). PLACEHOLDER from ARCHITECTURE §8.2:
-- tools/anim/gun_clips.py --write will regenerate this file from the clips. Owned by
-- the sniper's agent. Cycle = the bolt worked after each shot (the case flies out at
-- case_eject; bolt_forward chambers the next round).

local Types = require(script.Parent.Parent.Types)

local timelines: Types.Timelines = {
	Draw = {
		length = 1.1,
		events = { { time = 0.32, name = "draw_grip" }, { time = 0.78, name = "support_grip" } },
	},
	Holster = {
		length = 0.9,
		events = { { time = 0.75, name = "holster_seat", snap = true } },
	},
	Cycle = {
		length = 1.0,
		events = {
			{ time = 0.15, name = "bolt_lift" },
			{ time = 0.27, name = "bolt_back" },
			{ time = 0.43, name = "case_eject" },
			{ time = 0.45, name = "bolt_forward" },
			{ time = 0.63, name = "bolt_lock", snap = true },
		},
		commitAt = 0.63,
		cancelUntil = 0.15,
	},
	ReloadTactical = {
		length = 3.3,
		events = {
			{ time = 0.55, name = "mag_release" },
			{ time = 0.60, name = "mag_drop" },
			{ time = 1.30, name = "mag_grab" },
			{ time = 2.20, name = "mag_insert", snap = true },
		},
		commitAt = 2.20,
		cancelUntil = 2.10,
	},
	ReloadEmpty = {
		length = 3.9,
		events = {
			{ time = 0.55, name = "mag_release" },
			{ time = 0.60, name = "mag_drop" },
			{ time = 1.30, name = "mag_grab" },
			{ time = 2.20, name = "mag_insert", snap = true },
			{ time = 2.60, name = "bolt_back" },
			{ time = 2.72, name = "case_eject" },
			{ time = 2.90, name = "bolt_forward" },
			{ time = 3.00, name = "bolt_lock", snap = true },
		},
		commitAt = 2.20,
		cancelUntil = 2.10,
	},
	ReloadInsert = {
		length = 2.4,
		events = {
			{ time = 0.50, name = "mag_grab" },
			{ time = 1.30, name = "mag_insert", snap = true },
			{ time = 1.70, name = "bolt_back" },
			{ time = 1.82, name = "case_eject" },
			{ time = 2.00, name = "bolt_forward" },
			{ time = 2.10, name = "bolt_lock", snap = true },
		},
		commitAt = 1.30,
		cancelUntil = 1.20,
	},
	BipodDeploy = { length = 0.45, events = { { time = 0.30, name = "bipod_deploy", snap = true } } },
	BipodFold = { length = 0.40, events = { { time = 0.15, name = "bipod_fold" } } },
}

return table.freeze(timelines)
