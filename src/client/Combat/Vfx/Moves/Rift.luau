--!strict
-- Vfx/Moves/Rift: what Dr. Rift's moves (PLAN §2.6) LOOK like where they
-- hit a body. Owner: K2 of the VFX overhaul.
--
-- Dr. Rift's green gadget tech is his identity: the flasks, rays, portals
-- and the glove keep their own art (Combat/Rift*). The shared impact
-- grammar is added only where something actually STRIKES a body:
--   • the Gravity Glove's blast: a hot contact flash with a pale green
--     tint, sparks, hit-stop and the camera push-in (Heavy). Its air rings
--     stay RiftGlove's (we skip ours so they don't pile up).
--   • the clones' punches (Rift Swarm): small Light punches (×0.8, green
--     tint); the last one is a Clean that knocks them down.
--   • the rays: just a green-white light on the body and a short hit-stop.
--   • flasks, the portal shot, the gravity wave: their own bursts are the
--     impact; at most a hit-stop on the victim.
--
-- How to write a spec: see Vfx/Types.luau and Vfx/init.luau. Spec files
-- may require ONLY the library's own modules.

local Impact = require(script.Parent.Parent.Impact)
local Layers = require(script.Parent.Parent.Layers)
local Limb = require(script.Parent.Parent.Limb)
local Palette = require(script.Parent.Parent.Palette)
local Tiers = require(script.Parent.Parent.Tiers)
local Types = require(script.Parent.Parent.Types)

type HitContext = Types.HitContext

-- Only the victim freezes (the attacker is far away: a gun, a flask).
local function victimStop(ctx: HitContext, tier: Types.Tier)
	local def = Tiers.get(tier)
	Impact.hitstop(nil, ctx.victim, def.hitstop, ctx.dir, def.jitter)
end

-- A ray burning into a body: a green-white light on it, a short stop.
local function rayHit(tier: Types.Tier): Types.MoveSpec
	return {
		noDefault = true,
		tier = tier, -- (CombatEffectsController's hit-stop reads it)
		onHit = function(ctx)
			Layers.light(ctx.point, 4, 8, { color = Palette.RiftTint, fade = 0.1 })
			victimStop(ctx, tier)
		end,
	}
end

-- The clones' punches: which one of the swarm this is, per victim (each
-- clone's punch is a new action, so HitFx can't count them for us).
local SWARM_GAP = 1.2 -- seconds: a longer pause = a new swarm
local SWARM_HITS = 3
type SwarmCount = { at: number, count: number }
local swarmCount: { [Model]: SwarmCount } = setmetatable({}, { __mode = "k" }) :: any

local function swarmIndex(victim: Model): number
	local now = os.clock()
	local entry = swarmCount[victim]
	if entry == nil or now - entry.at > SWARM_GAP or entry.count >= SWARM_HITS then
		entry = { at = now, count = 0 }
		swarmCount[victim] = entry
	end
	entry.count += 1
	entry.at = now
	return entry.count
end

local clips: { [string]: Types.ClipSpec } = {
	-- A clone's punch is sent with its hit (no wind-up to see): the right
	-- fist's trail right at the start of the clip, as it lands.
	Rift_ClonePunch = {
		beats = { { at = 0.05, limb = "RightArm", swing = 0.05, after = 0.04, life = 0.1 } },
	},
}

local moves: { [string]: Types.MoveSpec } = {
	GravityGlove = {
		noDefault = true,
		tier = "Heavy",
		material = "Rift",
		onHit = function(ctx)
			Impact.hit({
				point = ctx.point,
				dir = ctx.dir,
				tier = ctx.tier,
				material = "Rift",
				attacker = ctx.attacker,
				victim = ctx.victim,
				blood = ctx.blood,
				-- (RiftGlove draws its own rings of bent air through them)
				skip = { ring = true },
			})
		end,
	},

	RiftSwarm = {
		noDefault = true,
		tier = "Light",
		material = "Rift",
		limb = "RightArm",
		onHit = function(ctx)
			local index = swarmIndex(ctx.victim)
			-- the last of the three knocks them down: a Clean one
			local last = index >= SWARM_HITS or (ctx.hit ~= nil and ctx.hit.knockdown ~= nil)
			Impact.hit({
				point = ctx.point,
				dir = ctx.dir,
				tier = if last then "Clean" else "Light",
				material = "Rift",
				attacker = ctx.attacker,
				victim = ctx.victim,
				blood = ctx.blood,
				scale = 0.8,
			})
			if last then
				Limb.speedLines(ctx.victim, 0.25, { dir = ctx.dir })
				-- (HitFx can't tell this is the knockdown one: we watch the landing)
				Impact.landing(ctx.victim, 1)
			end
		end,
	},

	RayGun = rayHit("Light"),
	OverchargedRay = rayHit("Clean"),

	-- (their own bursts are the impact; the tier only sets the hit-stop)
	AcidFlask = { noDefault = true, tier = "Light" },
	PortalGun = { noDefault = true, tier = "Light" },
	ExplosiveFlask = {
		noDefault = true,
		tier = "Heavy",
		onHit = function(ctx)
			victimStop(ctx, "Heavy")
		end,
	},
	GravitySlam = {
		noDefault = true,
		tier = "Clean",
		onHit = function(ctx)
			victimStop(ctx, "Clean")
		end,
	},
}

return { clips = clips, moves = moves } :: Types.SpecModule
