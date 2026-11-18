--!strict
-- Vfx/Moves/Weapons: the things picked up and thrown (Shared/Weapons:
-- the bone) (PLAN §2.7). Owner: K2 of the VFX overhaul.
--
--   • The throw: the arm's trail as it whips forward (release 0.24 s in
--     "Bone_Throw", Shared/Weapons). The bone's own trail in flight is
--     drawn by Combat/WeaponFx.
--   • The hit ("BoneThrow"): a Heavy stack, material "Bone" (moisture
--     sparks + white splinter chips), on top of WeaponFx's broken halves,
--     splinters and blood. The thrower is far away: only the victim
--     freezes, and the hit's direction is the bone's flight (from him).
--
-- How to write a spec: see Vfx/Types.luau and Vfx/init.luau. Spec files
-- may require ONLY the library's own modules.

local Impact = require(script.Parent.Parent.Impact)
local Tiers = require(script.Parent.Parent.Tiers)
local Types = require(script.Parent.Parent.Types)

local clips: { [string]: Types.ClipSpec } = {
	Bone_Throw = {
		beats = { { at = 0.24, limb = "RightArm", swing = 0.1, after = 0.04, life = 0.14 } },
	},
}

local moves: { [string]: Types.MoveSpec } = {
	BoneThrow = {
		noDefault = true,
		tier = "Heavy",
		material = "Bone",
		onHit = function(ctx)
			Impact.hit({
				point = ctx.point,
				dir = ctx.dir,
				tier = ctx.tier,
				material = "Bone",
				attacker = ctx.attacker, -- (the camera push-in for the thrower too)
				victim = ctx.victim,
				blood = ctx.blood,
				hitstop = false, -- (he's far away: only the victim freezes, below)
				floor = false,
			})
			local def = Tiers.get(ctx.tier)
			Impact.hitstop(nil, ctx.victim, def.hitstop, ctx.dir, def.jitter)
		end,
	},
}

return { clips = clips, moves = moves } :: Types.SpecModule
