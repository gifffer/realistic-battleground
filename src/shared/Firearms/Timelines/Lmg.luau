--!strict
-- The LMG's action timelines (seconds). PLACEHOLDER from ARCHITECTURE §8.2:
-- tools/anim/gun_clips.py --write will regenerate this file from the clips. Owned by
-- the LMG's agent. A cancelled belt reload leaves the gun where it got to (cover open,
-- no pouch): ReloadResume finishes it.

local Types = require(script.Parent.Parent.Types)

local timelines: Types.Timelines = {
	Draw = {
		length = 1.3,
		events = { { time = 0.40, name = "draw_grip" }, { time = 0.95, name = "support_grip" } },
	},
	Holster = {
		length = 1.1,
		events = { { time = 0.92, name = "holster_seat", snap = true } },
	},
	Reload = {
		length = 7.0,
		events = {
			{ time = 0.60, name = "charge_back" },
			{ time = 0.90, name = "charge_release", snap = true },
			{ time = 1.30, name = "cover_open" },
			{ time = 1.70, name = "belt_clear" },
			{ time = 2.00, name = "pouch_release" },
			{ time = 2.20, name = "pouch_drop" },
			{ time = 3.40, name = "pouch_grab" },
			{ time = 4.20, name = "pouch_attach", snap = true },
			{ time = 5.30, name = "belt_lay" },
			{ time = 5.50, name = "cover_close", snap = true },
		},
		commitAt = 5.30,
		cancelUntil = 5.20,
	},
	-- the cover is already open and the old pouch gone (a cancelled reload)
	ReloadResume = {
		length = 4.6,
		events = {
			{ time = 1.00, name = "pouch_grab" },
			{ time = 1.80, name = "pouch_attach", snap = true },
			{ time = 2.90, name = "belt_lay" },
			{ time = 3.10, name = "cover_close", snap = true },
		},
		commitAt = 2.90,
		cancelUntil = 2.80,
	},
	-- the bolt rode home on an empty belt and there is no spare pouch: rack it
	Charge = {
		length = 0.9,
		events = {
			{ time = 0.35, name = "charge_back" },
			{ time = 0.55, name = "charge_release", snap = true },
		},
		commitAt = 0.55,
		cancelUntil = 0.3,
	},
	BipodDeploy = { length = 0.50, events = { { time = 0.32, name = "bipod_deploy", snap = true } } },
	BipodFold = { length = 0.45, events = { { time = 0.15, name = "bipod_fold" } } },
}

return table.freeze(timelines)
