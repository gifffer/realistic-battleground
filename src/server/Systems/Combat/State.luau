--!strict
-- Types shared by the Combat modules (init.luau and Moves.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

-- Everything the server knows about one fighter (player or training dummy).
-- Times are os.clock() values.
export type CombatState = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	player: Player?, -- nil for dummies

	combo: number, -- last M1 of the combo (0 = none yet)
	lastAttackAt: number,
	nextAttackAt: number, -- can't M1 / use a move before this time
	attackingUntil: number, -- slowed while attacking
	attackToken: number, -- +1 cancels the attack that is winding up

	blocking: boolean,
	blockStartedAt: number,
	blockEndedAt: number,
	parryReady: boolean, -- this block got a parry window (anti-spam)

	stunnedUntil: number,
	legSlowUntil: number, -- slowed by a leg hit until then
	finishingUntil: number, -- doing a finisher: can't move until then
	invulnerableUntil: number, -- dash dodge frames
	cinematicUntil: number, -- in a cinematic finisher: nobody can hit them
	channelUntil: number, -- channelling a beam: rooted until then
	cinematicToken: number, -- changes with each cinematic (stale timers do nothing)
	nextDashAt: number,
	knockbackUntil: number, -- a knockback push is running until then

	-- Kits (step 4).
	kitId: string, -- Shared/Kits id
	cooldowns: { [string]: number }, -- move id → time it can be used again
	fury: number, -- Awakening gauge, 0 → Config.Kits.FURY_MAX
	awakenedUntil: number,
	bleedPerSecond: number, -- 0 = not bleeding
	bleedUntil: number,
	nextBleedTick: number,
	bleedSource: Model?, -- who cut them (gets the credit for the damage)
	slowUntil: number, -- slowed by a move (dirty kick) until then...
	slowMultiplier: number, -- ...by this much
	knockdownToken: number, -- +1 cancels the pending get-up of a knockdown
	knockedDownUntil: number, -- on the ground after a tackle / launch

	-- Injuries (step 5), cleared by a kill or a new life.
	legDamage: number, -- damage taken on the legs
	limping: boolean, -- legDamage reached Config.Injuries.LIMP_LEG_DAMAGE
	lastDamagedAt: number, -- for the out-of-combat regeneration
	regenCarry: number, -- fraction of HP regenerated, not given yet

	-- Slip (Boxer, step 6): dodging the next frontal hit until slipUntil,
	-- then countering with this move's counter.
	slipUntil: number,
	slipMoveId: string?,
}

-- What one hit does. An M1 builds one, every kit move hit builds one
-- (Combat.resolveHit reads it).
export type HitSpec = {
	damage: number, -- before the Awakening multiplier
	zone: Types.HitZone,
	stun: number,
	headStun: boolean, -- add Config.Combat.HEAD_EXTRA_STUN on a head hit
	legSlow: boolean, -- the M1 leg slow (Config.Combat.LEG_HIT_SLOW)
	kind: Types.CombatEventKind, -- "Hit" or "Finisher" (the 4th M1)
	blockCost: number, -- stamina a block of it costs
	knockback: number?, -- studs/s away from the attacker
	knockdown: number?, -- seconds on the ground
	pull: number?, -- studs/s toward the attacker
	bleed: { perSecond: number, duration: number }?,
	slow: { multiplier: number, duration: number }?,
	unblockable: boolean?,
	-- Chance of visible blood per zone (nil: the M1 rules in Config.Injuries).
	bloodChance: { [string]: number }?,
	cuts: ("Lac" | "Slash")?, -- glass: cuts the skin where it lands (Gash)
	launch: number?, -- with knockdown: thrown up at this speed (uppercuts)
	staminaDrain: number?, -- the victim loses this much stamina (body shots)
	attackId: number?, -- M1 number from the client (prediction), nil for moves
	moveId: string?, -- kit move id, nil for an M1
}

return nil
