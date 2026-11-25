--!strict
-- The pistol's action timelines (seconds). PLACEHOLDER from ARCHITECTURE §8.2 /
-- §8.3: tools/anim/gun_clips.py --write will regenerate this file from the clips
-- (the clip and the server then share these exact times). Owned by the pistol's agent.
--
-- The server runs reloads from these events (Shared/Firearms/Ammo.applyEvent): at
-- mag_drop the old mag's rounds are gone, at mag_insert (commitAt) the new mag is in,
-- at slide_release a round is chambered. A cancel before cancelUntil stops it there.

local Types = require(script.Parent.Parent.Types)

local timelines: Types.Timelines = {
	Draw = {
		length = 0.55,
		events = { { time = 0.12, name = "draw_grip" }, { time = 0.35, name = "support_grip" } },
	},
	Holster = {
		length = 0.45,
		events = { { time = 0.36, name = "holster_seat", snap = true } },
	},
	ReloadTactical = {
		length = 1.6,
		events = {
			{ time = 0.18, name = "mag_release" },
			{ time = 0.22, name = "mag_drop" },
			{ time = 0.55, name = "mag_grab" },
			{ time = 0.98, name = "mag_insert", snap = true },
		},
		commitAt = 0.98,
		cancelUntil = 0.95,
	},
	ReloadEmpty = {
		length = 2.0,
		events = {
			{ time = 0.18, name = "mag_release" },
			{ time = 0.22, name = "mag_drop" },
			{ time = 0.55, name = "mag_grab" },
			{ time = 0.98, name = "mag_insert", snap = true },
			{ time = 1.32, name = "slide_back" },
			{ time = 1.40, name = "slide_release", snap = true },
		},
		commitAt = 0.98,
		cancelUntil = 0.95,
	},
	-- a full mag in, nothing chambered (a reload cancelled after the insert): rack it
	Charge = {
		length = 0.7,
		events = {
			{ time = 0.30, name = "slide_back" },
			{ time = 0.38, name = "slide_release", snap = true },
		},
		commitAt = 0.38,
		cancelUntil = 0.25,
	},
	-- a mag already out (a reload cancelled after the drop): insert + release only
	ReloadInsert = {
		length = 1.3,
		events = {
			{ time = 0.25, name = "mag_grab" },
			{ time = 0.68, name = "mag_insert", snap = true },
			{ time = 0.95, name = "slide_release", snap = true },
		},
		commitAt = 0.68,
		cancelUntil = 0.65,
	},
}

return table.freeze(timelines)
