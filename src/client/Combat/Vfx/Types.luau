--!strict
-- Vfx/Types: the shared types of the combat VFX library (see Vfx/init.luau).
--
-- A "spec" file (Vfx/Moves/*.luau) describes what a move LOOKS like, as
-- data, with these types. Example: the jab (M1 number 1).
--
--   local Types = require(script.Parent.Parent.Types)
--
--   local clips: { [string]: Types.ClipSpec } = {
--       -- The swing: the left fist's air trail runs from 0.095 s to 0.18 s
--       -- into the "Brawler_M1_1" clip (contact = 0.15 s, Config.Combat.HIT_DELAY).
--       Brawler_M1_1 = {
--           beats = { { at = 0.15, limb = "LeftArm", swing = 0.055, after = 0.03, life = 0.1 } },
--       },
--   }
--   local moves: { [string]: Types.MoveSpec } = {
--       -- The contact: the Light tier stack where the left fist touches.
--       M1_1 = { tier = "Light", limb = "LeftArm" },
--   }
--   return { clips = clips, moves = moves } :: Types.SpecModule
--
-- Clip names are the animation names (CombatClips); move ids are the
-- server's moveId (Shared/Kits ids, plus "_Counter" / "_FollowUp" /
-- "_Hold"), or "M1_1".."M1_4", "Blocked", "Parried", "GuardBreak",
-- "Dodged", "Protected" for the base combat.

local Kits = require(game:GetService("ReplicatedStorage").Shared.Kits)

-- (These "names" are plain strings so spec tables type-check easily; the
-- valid values are listed with each type. An unknown name: Tiers.get
-- falls back to "Clean", an unknown limb draws nothing.)

-- How hard a hit looks. One tier per hit, see Vfx/Tiers.
-- "Blocked" | "Light" | "Clean" | "Heavy" | "Last" | "Slam"
export type Tier = string

-- Which body part (or held prop) does the striking.
-- "RightArm" | "LeftArm" | "RightLeg" | "LeftLeg" | "Head" | "Torso" | "BothArms" | "Prop"
export type Limb = string

-- What gets hit: decides the sparks' colour and which layers are skipped.
--   Body  : skin / clothes (moisture-white sparks, specks, dust puff)
--   Guard : forearms on guard (warm small sparks, no ring)
--   Glass : a bottle breaking (warm + glass glints, no dust puff)
--   Slash : a cut (no ring; one long streak along the cut)
--   Palm  : a shove (no sparks, no streaks; a big air ring + puff)
--   Bone  : a thrown bone (moisture sparks + white splinter chips)
--   Rift  : Dr. Rift's tech (pale green tint on the flash)
-- "Body" | "Guard" | "Glass" | "Slash" | "Palm" | "Bone" | "Rift"
export type Material = string

-- Arguments of Impact.hit (one impact stack).
export type ImpactArgs = {
	point: Vector3, -- world contact point
	dir: Vector3, -- strike direction (unit, from the attacker into the victim)
	tier: Tier,
	material: Material?,
	ringFacing: Vector3?, -- which way the air ring faces (default `dir`; Vector3.yAxis for uppercuts)
	attacker: Model?,
	victim: Model?,
	camera: boolean?, -- default true (false in cinematics: CinematicController owns the camera)
	floor: boolean?, -- floor dust ring: default = the tier's rule (Heavy+ and a floor within 4 studs)
	scale: number?, -- size multiplier (1 = normal)
	blood: boolean?, -- the server rolled blood: fewer moisture specks (blood has its own drops)
	hitstop: boolean?, -- default true when attacker or victim is given
	skip: { [string]: boolean }?, -- layers to leave out: flash, light, streaks, sparks, ring, specks, puff, floor
}

-- What HitFx knows about one landed hit (given to MoveSpec.onHit).
export type HitContext = {
	victim: Model,
	attacker: Model,
	id: string, -- the spec id ("M1_2", "BottleSmash", "Slip_Counter"...)
	kind: string, -- the CombatEvent kind ("Hit", "Finisher", "Blocked"...)
	zone: string, -- "Head" | "Torso" | "Legs"
	side: string, -- "Front" | "Back" | "Left" | "Right"
	index: number, -- which hit of the move (1 = the first)
	count: number, -- how many hits the move has
	tier: Tier,
	point: Vector3,
	dir: Vector3,
	blood: boolean,
	own: boolean, -- we are the attacker or the victim
	predicted: boolean, -- shown by our own prediction (zero latency)
	hit: Kits.HitDef?, -- the Kits hit definition, when known
}

-- What HitFx gives a ClipSpec.run (an action that just started).
export type ActionContext = {
	model: Model,
	clip: string,
	own: boolean, -- our own character
	-- Runs `fn` `seconds` from now, ONLY if this clip is still the
	-- model's current action then (a cut-short move shows nothing more).
	later: (seconds: number, fn: () -> ()) -> (),
}

-- One timed beat of a clip (usually one blow): its swing trail and extras.
export type BeatSpec = {
	at: number, -- contact time in the clip (seconds) = Kits hit.at (or HIT_DELAY for M1s)
	limb: Limb,
	swing: number?, -- the trail turns on this long before `at` (default 0.06)
	after: number?, -- and off this long after `at` (default 0.035)
	life: number?, -- trail lifetime (0.1 light, 0.14 heavy, 0.16 arcs)
	arc: boolean?, -- a hook / round kick: longer trail so the arc reads
	width: number?, -- trail width (studs)
	smear: boolean?, -- ghost limbs on the 2 frames before `at`
	preDim: boolean?, -- our own heavy blows: the screen dims 2 frames before `at`
	glint: boolean?, -- a 1-frame tiny flash on the prop tip just before `at`
}

export type ClipSpec = {
	beats: { BeatSpec }?,
	run: ((ctx: ActionContext) -> ())?,
}

-- "Strike" (default) | "Up" (uppercuts) | "Down" (hammer fists)
export type RingFacing = string

export type MoveSpec = {
	tiers: { Tier }?, -- one per hit index (the last one repeats)
	tier: Tier?, -- or one tier for every hit
	limb: (Limb | { Limb })?, -- the striking limb (per hit index if a list)
	material: Material?,
	ringFacing: RingFacing?,
	scale: number?,
	noDefault: boolean?, -- true: skip the default Impact.hit, onHit does everything
	onHit: ((ctx: HitContext) -> ())?,
}

export type SpecModule = {
	clips: { [string]: ClipSpec },
	moves: { [string]: MoveSpec },
}

-- One row of Vfx/Tiers.
export type TierDef = {
	flash: number, -- contact flash size (studs)
	flashFrames: number, -- frames the flash is held (60 fps)
	warm: boolean, -- warm flash (guard)
	secondFlash: boolean, -- a warm 2nd flash 3 frames later (Last)
	light: number, -- point light brightness
	range: number, -- point light range
	fade: number, -- light fade time (s)
	streaks: number, -- long streaks along the strike line
	armStreak: boolean, -- + one back along the attacker's arm
	sparks: number,
	heavySparks: boolean,
	rings: number, -- air rings (0, 1, 2)
	ringSize: number, -- ring final size (studs)
	torsoRing: boolean, -- + a horizontal ring around the victim's torso
	specks: number,
	puff: number, -- dust puff size (0 = none)
	floor: boolean, -- floor dust ring when a floor is near
	floorPuffs: number,
	floorSpeed: number,
	hitstop: number, -- seconds
	jitter: number, -- victim hit-shake amplitude (studs)
	trauma: number, -- camera shake added (fighters)
	fov: number, -- FOV punch (degrees, fighters)
	kick: number, -- camera kick (degrees, fighters)
	dim: number, -- screen dim (fighters)
}

return nil
