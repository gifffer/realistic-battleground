--!strict
-- The shape of a kit's data (see Shared/Kits/init.luau for what a kit is).
-- In its own file so each kit file can use these types without requiring
-- Shared/Kits itself (which requires every kit: a loop).

local Types = require(script.Parent.Parent.Types)

-- One hit of a move (a move can have several: a double headbutt...).
export type HitDef = {
	at: number, -- seconds after the move starts = the impact keyframe of its animation
	damage: number,
	-- Where it lands. nil = where the attacker aims (head or torso); "Legs"
	-- for kicks to the shin.
	zone: Types.HitZone?,
	stun: number, -- seconds the victim can't act
	hitbox: Vector3, -- box size (studs), in front of the attacker
	forward: number, -- box centre, studs in front of the attacker
	knockback: number?, -- push the victim away (studs/s, for KNOCKBACK_TIME)
	knockdown: number?, -- the victim falls (ragdoll) for this long, then gets up
	pull: number?, -- pull the victim toward the attacker (studs/s): grabs
	bleed: { perSecond: number, duration: number }?,
	slow: { multiplier: number, duration: number }?,
	unblockable: boolean?, -- goes through a block (still parried / dodged)
	blockCost: number?, -- stamina a block of it costs (default: 1.5 × an M1's)
	breaksProp: boolean?, -- the bottle breaks on this hit
	-- Chance (0-1) this hit draws visible blood, per zone it lands on
	-- ({ Head = 1, Torso = 0.5 }). nil / missing zone = no blood.
	bloodChance: { [string]: number }?,
	-- Glass: cuts the skin where the hit lands (head or torso), see
	-- Config.Injuries.SKIN_TEAR. "Lac" = a bottle smashed on them (ragged
	-- laceration), "Slash" = a broken bottle (clean, longer cut).
	cuts: ("Lac" | "Slash")?,
	burns: boolean?, -- heat vision: burns through the skin (a "Burn" wound), no bruise
	launch: number?, -- with knockdown: thrown UP at this speed (studs/s): uppercuts
	breaks: number?, -- smashes the map (walls...) within this radius of the hitbox centre (Server Destruction)
	staminaDrain: number?, -- the victim loses this much stamina (body shots)
}

-- A grab (Bouncer): the hands close `at` seconds into the move on the first
-- fighter in the box. It goes through a guard (and can't be parried: there
-- is no blow to parry), but a hit that stuns the grabber first cancels it,
-- and a dash dodges it. Caught: both fighters are held in place for
-- `duration` seconds, the victim `distance` studs in front of him (facing him,
-- or turned away: a choke from behind), each playing its clip, while
-- `hits` land on the held fighter (their `at` counted from the catch).
-- A hit with knockback / knockdown lets go of them first. An Awakened
-- fighter can't be held (the catch only hurts).
export type GrabDef = {
	at: number,
	hitbox: Vector3,
	forward: number,
	damage: number, -- of the catch itself
	duration: number,
	distance: number,
	facing: "toward" | "away",
	animation: string, -- his clip while holding (Client/Animation/CombatClips)
	victimAnimation: string, -- theirs
	hits: { HitDef },
	-- A slam: released lying on their back, their root put here (relative
	-- to his root): where their clip ends on the floor.
	laidAt: CFrame?,
}

export type MoveDef = {
	id: string,
	name: string, -- shown in the move bar and the Kits menu (English)
	description: string, -- one sentence for the Kits menu
	animation: string, -- clip in Client/Animation/CombatClips
	duration: number, -- can't do anything else until then
	cooldown: number, -- seconds before it can be used again
	stamina: number,
	hits: { HitDef },
	-- Charge (tackle): the attacker rushes forward from `from` to `to`
	-- seconds; the hit lands on the first fighter touched on the way.
	-- (breaks: smashes the walls it runs into, within this radius ahead)
	charge: { speed: number, from: number, to: number, hit: HitDef, breaks: number? }?,
	-- After a charge connects: a follow-up strike on the fallen victim.
	followUp: { animation: string, delay: number, at: number, damage: number }?,
	prop: string?, -- object held during the move ("Bottle", "BrokenBottle")
	-- Slip (Boxer): for `window` seconds the fighter dodges the first hit
	-- coming from the front and answers with `hit` (its animation plays,
	-- the hit lands `at` seconds later on the one who missed).
	counter: { window: number, animation: string, at: number, hit: HitDef }?,
	-- Combo: only the FIRST hit checks a hitbox; the next ones land on the
	-- fighters the first one reached, if they are still close (cinematic
	-- combos that can't "miss" halfway).
	chain: boolean?,
	-- Beam (heat vision): from `from` to `to` seconds a beam goes straight
	-- out of the eyes, the way the fighter faced when it started (it does
	-- NOT follow the aim), `range` studs (stopped by walls), `radius` thick.
	-- The fighter is rooted meanwhile. Someone in it heats up: only after
	-- `warmup` seconds in the beam does `hit` land, every `tick` seconds
	-- (blockable); stepping out cools them down again.
	beam: {
		from: number,
		to: number,
		range: number,
		radius: number,
		warmup: number,
		tick: number,
		hit: HitDef,
	}?,
	-- Leap (skyfall): the fighter's own client throws him up (`up`
	-- studs/s) and forward (`forward` studs/s) at `at` seconds; the hits
	-- come down where he lands (a hitbox around him, forward = 0).
	leap: { at: number, up: number, forward: number, time: number }?,
	-- A grab instead of strikes (see GrabDef). `duration` = a grab that
	-- catches nobody; a catch keeps him busy until the hold ends.
	grab: GrabDef?,
}

-- The kit's own way to finish a knocked-out opponent (M1 on them). Kits
-- without one use the default finisher (Config.Knockout).
export type FinisherDef = {
	animation: string,
	impact: number, -- seconds from the click to the killing blow
	duration: number, -- can't do anything else until then
	-- A cinematic kill (Shared/Finishers: placement, camera, effects).
	-- Its `kill` and `duration` must match impact / duration here.
	cinematic: string?,
}

export type AwakeningDef = {
	name: string,
	description: string,
	animation: string, -- the activation
	duration: number, -- seconds
	damageMultiplier: number, -- every hit deals this much more meanwhile
	moves: { MoveDef }, -- replace the 4 normal moves meanwhile
}

export type KitDef = {
	id: string,
	name: string,
	description: string,
	order: number, -- position in the Kits menu
	available: boolean, -- false = shown as "coming soon", can't be equipped
	noSprint: boolean?, -- true = can't sprint with it
	-- To unlock (step 7): reach this level, then buy it for this many coins.
	-- nil = free, everyone has it (the two base kits).
	unlockLevel: number?,
	price: number?,
	moves: { MoveDef },
	awakening: AwakeningDef?,
	finisher: FinisherDef?,
	-- A heavy build (Bouncer): every hit taken deals this much of its
	-- damage (0.85 = 15 % less).
	damageTaken: number?,
	-- Walk / run speed times this (0.9 = 10 % slower, 1.15 = 15 % faster).
	speed: number?,
}

return nil
