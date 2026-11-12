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
	moves: { MoveDef },
	awakening: AwakeningDef?,
}

return nil
