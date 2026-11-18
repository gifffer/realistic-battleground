--!strict
-- Vfx/Tiers: how hard each kind of hit LOOKS. Every hit picks ONE tier and
-- shows only that tier's layers (the "killing hit" overlay is added on top
-- by HitFx, see Impact.knockoutOverlay). Numbers are starting points from
-- the reference videos (docs/references/README.md, video16.md), at 60 fps:
-- tune them in Studio.
--
--   Blocked  a blow on the guard: a small warm spark, nothing else
--   Light    jabs, flurry hits
--   Clean    cross, hook, kicks
--   Heavy    uppercut, hammer fist, counters: dim + push-in + 2 rings
--   Last     the last hit of a chain: everything + floor dust
--   Slam     a body / fist driven into the floor

local Types = require(script.Parent.Types)

type TierDef = Types.TierDef

local function tier(def: TierDef): TierDef
	return table.freeze(def)
end

local Tiers: { [string]: TierDef } = {
	Blocked = tier({
		flash = 0.8,
		flashFrames = 1,
		warm = true,
		secondFlash = false,
		light = 3,
		range = 6,
		fade = 0.06,
		streaks = 0,
		armStreak = false,
		sparks = 4,
		heavySparks = false,
		rings = 0,
		ringSize = 0,
		torsoRing = false,
		specks = 3,
		puff = 0,
		floor = false,
		floorPuffs = 0,
		floorSpeed = 0,
		hitstop = 0.035,
		jitter = 0.03,
		trauma = 0.15,
		fov = 0,
		kick = 0,
		dim = 0,
	}),
	Light = tier({
		flash = 1.2,
		flashFrames = 1,
		warm = false,
		secondFlash = false,
		light = 5,
		range = 8,
		fade = 0.08,
		streaks = 1,
		armStreak = false,
		sparks = 6,
		heavySparks = false,
		rings = 0,
		ringSize = 0,
		torsoRing = false,
		specks = 4,
		puff = 0.7,
		floor = false,
		floorPuffs = 0,
		floorSpeed = 0,
		hitstop = 0.05,
		jitter = 0.05,
		trauma = 0.25,
		fov = 0,
		kick = 0,
		dim = 0,
	}),
	Clean = tier({
		flash = 1.8,
		flashFrames = 2,
		warm = false,
		secondFlash = false,
		light = 7,
		range = 11,
		fade = 0.1,
		streaks = 2,
		armStreak = false,
		sparks = 10,
		heavySparks = false,
		rings = 1,
		ringSize = 2.5,
		torsoRing = false,
		specks = 6,
		puff = 1,
		floor = false,
		floorPuffs = 0,
		floorSpeed = 0,
		hitstop = 0.066,
		jitter = 0.06,
		trauma = 0.45,
		fov = 1.5,
		kick = 0,
		dim = 0,
	}),
	Heavy = tier({
		flash = 2.4,
		flashFrames = 2,
		warm = false,
		secondFlash = false,
		light = 9,
		range = 14,
		fade = 0.12,
		streaks = 3,
		armStreak = true,
		sparks = 14,
		heavySparks = true,
		rings = 2,
		ringSize = 3.5,
		torsoRing = false,
		specks = 8,
		puff = 1.4,
		floor = true,
		floorPuffs = 6,
		floorSpeed = 12,
		hitstop = 0.11,
		jitter = 0.1,
		trauma = 0.8,
		fov = 4,
		kick = 1,
		dim = 0.12,
	}),
	Last = tier({
		flash = 2.5,
		flashFrames = 2,
		warm = false,
		secondFlash = true,
		light = 11,
		range = 16,
		fade = 0.14,
		streaks = 3,
		armStreak = true,
		sparks = 18,
		heavySparks = true,
		rings = 2,
		ringSize = 3.8,
		torsoRing = true,
		specks = 8,
		puff = 1.5,
		floor = true,
		floorPuffs = 8,
		floorSpeed = 16,
		hitstop = 0.14,
		jitter = 0.11,
		trauma = 0.9,
		fov = 5,
		kick = 1.2,
		dim = 0.15,
	}),
	Slam = tier({
		flash = 2.6,
		flashFrames = 2,
		warm = false,
		secondFlash = false,
		light = 11,
		range = 18,
		fade = 0.15,
		streaks = 0,
		armStreak = false,
		sparks = 10,
		heavySparks = true,
		rings = 1,
		ringSize = 5,
		torsoRing = false,
		specks = 4,
		puff = 1.6,
		floor = true,
		floorPuffs = 12,
		floorSpeed = 24,
		hitstop = 0.12,
		jitter = 0.1,
		trauma = 1,
		fov = 5,
		kick = 1,
		dim = 0.14,
	}),
}

-- The killing-hit overlay (added 2-3 frames after a hit that knocks out).
export type KnockoutDef = {
	flash: number,
	light: number,
	range: number,
	sparks: number,
	ringFrom: number,
	ringTo: number,
	hitstop: number, -- the hit-stop is extended up to this
	fov: number,
	kick: number,
	trauma: number,
}
local KNOCKOUT: KnockoutDef = table.freeze({
	flash = 2.2,
	light = 13,
	range = 18,
	sparks = 6,
	ringFrom = 1.5,
	ringTo = 5,
	hitstop = 0.17,
	fov = 6,
	kick = 1.5,
	trauma = 1,
})

local ORDER: { [string]: number } = {
	Blocked = 0,
	Light = 1,
	Clean = 2,
	Heavy = 3,
	Last = 4,
	Slam = 5,
}

return table.freeze({
	-- The tier's numbers ("Clean" for an unknown name).
	get = function(name: Types.Tier): TierDef
		return Tiers[name] or Tiers["Clean"]
	end,
	-- Is `a` at least as strong as `b`?
	atLeast = function(a: Types.Tier, b: Types.Tier): boolean
		return (ORDER[a] or 0) >= (ORDER[b] or 0)
	end,
	KNOCKOUT = KNOCKOUT,
})
