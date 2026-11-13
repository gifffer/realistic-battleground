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
	breaksProp: boolean?, -- the bottle breaks on this hit
	-- Chance (0-1) this hit draws visible blood, per zone it lands on
	-- ({ Head = 1, Torso = 0.5 }). nil / missing zone = no blood.
	bloodChance: { [string]: number }?,
	-- Glass: cuts the skin where the hit lands (head or torso), see
	-- Config.Injuries.SKIN_TEAR. "Lac" = a bottle smashed on them (ragged
	-- laceration), "Slash" = a broken bottle (clean, longer cut).
	cuts: ("Lac" | "Slash")?,
	launch: number?, -- with knockdown: thrown UP at this speed (studs/s): uppercuts
	staminaDrain: number?, -- the victim loses this much stamina (body shots)
	burn: BurnDef?, -- acid / fire on the skin: damage over time (Dr. Rift)
}

-- Acid or fire eating the skin (Dr. Rift): `perSecond` damage for
-- `duration` seconds. One burn at a time: a stronger one replaces a weaker
-- one, any new one refreshes the time. Separate from bleeding.
export type BurnDef = {
	kind: "Acid" | "Fire",
	perSecond: number,
	duration: number,
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
	charge: { speed: number, from: number, to: number, hit: HitDef }?,
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
	-- A grab instead of strikes (see GrabDef). `duration` = a grab that
	-- catches nobody; a catch keeps him busy until the hold ends.
	grab: GrabDef?,
	-- Dr. Rift's gadgets (see GadgetDef).
	gadget: GadgetDef?,
}

-- A flask thrown in an arc (Dr. Rift). It leaves the hand `release`
-- seconds into the move (towards where he aims), the server flies it, and
-- it bursts on the first thing it touches (or after `lifetime`): `hit` on a
-- body it hits directly, `splash` on everyone else within `radius` of the
-- burst (if nothing stands between). Acid leaves a puddle that keeps
-- burning whoever stands in it.
export type FlaskDef = {
	kind: "Acid" | "Explosive",
	release: number,
	speed: number, -- studs/s at release, where he aims
	lift: number, -- studs/s added upward (the arc)
	gravity: number, -- studs/s²
	lifetime: number, -- seconds in the air at most
	hit: HitDef, -- (its hitbox / forward / zone unused: the body part hit decides)
	radius: number,
	splash: HitDef, -- (zone: the torso)
	puddle: { radius: number, seconds: number, burn: BurnDef }?,
}

-- A ray gun (Dr. Rift): `at` seconds into the move, a beam from his hand
-- to where he aims, `range` studs at most. It stops at the first wall; it
-- hits the first body in its way (`width` studs thick), or everyone in
-- line until the wall if `pierce`.
export type RayDef = {
	at: number,
	range: number,
	width: number,
	pierce: boolean,
	hit: HitDef, -- (its hitbox / forward unused)
}

-- The portal gun (Dr. Rift): `at` seconds in, a shot opens a portal where
-- he aims (a floor or a wall within `range` studs, inside the map); `open`
-- seconds in, a second shot opens one in front of him; he steps in and
-- comes out of the first one `travel` seconds in. Aimed higher than
-- `maxPitch` degrees above the horizon, at nothing, at a ceiling, out of
-- the map or where there's no room: the shot fizzles and the gun is back
-- after `failCooldown` seconds instead of the move's cooldown.
export type PortalDef = {
	at: number,
	open: number,
	travel: number,
	range: number,
	maxPitch: number,
	failCooldown: number,
}

-- A shockwave all around him (Dr. Rift's gravity slam): `hit` on everyone
-- within `radius` studs `at` seconds into the move.
export type WaveDef = {
	at: number,
	radius: number,
	hit: HitDef, -- (its hitbox / forward unused)
}

-- The clones (Dr. Rift's Awakening) go through portals to the fighter he
-- aims at (`range` studs at most, or the closest one in front of him) and
-- beat them up: `hits` counted from their arrival `at` seconds in. Clones
-- that were dispelled come back for it.
export type SwarmDef = {
	at: number,
	range: number,
	hits: { HitDef }, -- each clone lands these (hitbox / forward unused)
}

export type GadgetDef = {
	flask: FlaskDef?,
	ray: RayDef?,
	portal: PortalDef?,
	wave: WaveDef?,
	swarm: SwarmDef?,
}

-- Dr. Rift's Awakening: `count` copies of him step out of portals and fight
-- with him (they copy his moves, `damage` × the damage of his). One hit and
-- a clone is gone (back through a portal). They leave when it ends.
export type ClonesDef = {
	count: number,
	damage: number,
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
	clones: ClonesDef?,
}

export type KitDef = {
	id: string,
	name: string,
	description: string,
	order: number, -- position in the Kits menu
	available: boolean, -- false = shown as "coming soon", can't be equipped
	-- To unlock (step 7): reach this level, then buy it for this many coins.
	-- nil = free, everyone has it (the two base kits).
	unlockLevel: number?,
	price: number?,
	moves: { MoveDef },
	awakening: AwakeningDef?,
	finisher: FinisherDef?,
	-- A heavy build (Bouncer): every hit taken deals this much of its
	-- damage (0.85 = 15 % less), and he walks / runs this much slower.
	damageTaken: number?,
	speed: number?,
}

return nil
