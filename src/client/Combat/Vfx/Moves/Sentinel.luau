--!strict
-- Vfx/Moves/Sentinel: what the Sentinel's moves (PLAN §2.5) LOOK like
-- where they hit a body. Owner: K2 of the VFX overhaul.
--
-- The Sentinel is strong, not magic: his moves are HEAT and AIR PRESSURE
-- (hot warm-white light, dust, a shock of air), never blue energy. The
-- big set pieces of each move (the clap's blast, the Skyfall crater, the
-- Haymaker's air blast, the heat-vision beam) are drawn by Combat/KitVFX
-- at the move's own times; here is only what shows on the one HIT:
--   • ThunderClap: the blast of air reaches them = a "Palm" impact (no
--     sparks: a big air ring, dust off the clothes), thrown back.
--   • Skyfall: the fist / shockwave of the landing: a Heavy stack on the
--     body, no 2nd floor ring (KitVFX's crater is already there).
--   • Haymaker: the biggest punch of the kit: "Last", ×1.3.
--   • HeatVision: the beam ticks show nothing here (KitVFX burns them).
--
-- How to write a spec: see Vfx/Types.luau and Vfx/init.luau. Spec files
-- may require ONLY the library's own modules.

local Impact = require(script.Parent.Parent.Impact)
local Limb = require(script.Parent.Parent.Limb)
local Types = require(script.Parent.Parent.Types)

local clips: { [string]: Types.ClipSpec } = {
	-- the hands come together at 0.34: a short trail on both
	Sentinel_ThunderClap = {
		beats = { { at = 0.34, limb = "BothArms", swing = 0.07, after = 0.02, life = 0.1 } },
	},
	-- the wind-up is long (0.55): the fist's trail only on the way in,
	-- a smear, and our own screen dims 2 frames before it lands
	Sentinel_Haymaker = {
		beats = {
			{
				at = 0.55,
				limb = "RightArm",
				swing = 0.1,
				after = 0.04,
				life = 0.16,
				arc = true,
				smear = true,
				preDim = true,
			},
		},
	},
}

local moves: { [string]: Types.MoveSpec } = {
	-- (the beam's ticks: KitVFX chars the skin where it touches)
	HeatVision = { noDefault = true },

	ThunderClap = {
		tier = "Clean",
		material = "Palm",
		scale = 1.2,
		onHit = function(ctx)
			Limb.speedLines(ctx.victim, 0.25, { dir = ctx.dir })
		end,
	},

	Skyfall = {
		noDefault = true,
		tier = "Heavy",
		onHit = function(ctx)
			Impact.hit({
				point = ctx.point,
				dir = ctx.dir,
				tier = ctx.tier,
				attacker = ctx.attacker,
				victim = ctx.victim,
				blood = ctx.blood,
				floor = false, -- (the crater's dust is already there)
				skip = { streaks = true },
			})
		end,
	},

	Haymaker = {
		tier = "Last",
		limb = "RightArm",
		scale = 1.3,
		onHit = function(ctx)
			-- knockback 78: the body is sent flying
			Limb.speedLines(ctx.victim, 0.35, { dir = ctx.dir })
		end,
	},
}

return { clips = clips, moves = moves } :: Types.SpecModule
