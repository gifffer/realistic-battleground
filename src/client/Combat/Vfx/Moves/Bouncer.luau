--!strict
-- Vfx/Moves/Bouncer: what the Bouncer's moves (PLAN §2.4) LOOK like.
-- Owner: K2 of the VFX overhaul.
--
-- The Bouncer doesn't trade punches: he shoves, grabs, hammers and slams.
-- So his look is AIR and FLOOR more than sparks:
--   • Shove: two palms on the chest = no sparks, a big air ring and a puff
--     of dust off the shirt (material "Palm").
--   • Hammer fists: hit from ABOVE, so the air ring lies flat (ringFacing
--     "Down"). The 2nd of the Double Hammer drives them into the floor.
--   • Grabs: the catch is a hand closing on cloth (a small puff, a nudge
--     of the camera), not a punch. The squeezes of a choke show nothing
--     here (BouncerFx turns the face red / violet).
--   • Slams: a whole body into the floor = Impact.groundSlam (flash AT the
--     floor, flat ring, dust shot out, debris that stays, a crack). The
--     Powerbomb is the biggest hit of the game.
-- The victim's body gets a faint trail while it is lifted / thrown (its
-- own clip, "Bouncer_*Victim"), and speed lines when it flies away.
--
-- How to write a spec: see Vfx/Types.luau (example at the top) and
-- Vfx/init.luau. Spec files may require ONLY the library's own modules,
-- never Vfx (init) or Vfx/HitFx (it requires us).

local Camera = require(script.Parent.Parent.Camera)
local Impact = require(script.Parent.Parent.Impact)
local Layers = require(script.Parent.Parent.Layers)
local Limb = require(script.Parent.Parent.Limb)
local Types = require(script.Parent.Parent.Types)

type HitContext = Types.HitContext

local function torsoOf(model: Model): BasePart?
	local torso = model:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then torso else nil
end

-- The default tier stack of `ctx`, with a few things changed (`extra`).
local function hit(ctx: HitContext, extra: { [string]: any }?)
	local args: Types.ImpactArgs = {
		point = ctx.point,
		dir = ctx.dir,
		tier = ctx.tier,
		attacker = ctx.attacker,
		victim = ctx.victim,
		blood = ctx.blood,
	}
	if extra then
		for key, value in extra do
			(args :: any)[key] = value
		end
	end
	Impact.hit(args)
end

-- A grab's catch: a fist closing on the collar. No flash (nothing hits
-- hard): a little puff of dust out of the cloth, a nudge of the camera.
local function catch(ctx: HitContext)
	local torso = torsoOf(ctx.victim)
	if torso then
		local collar = (torso.CFrame * CFrame.new(0, 0.9, 0)).Position
		Layers.puff(collar - ctx.dir * 0.3, -ctx.dir, 0.5, 1, { delayFrames = 0, life = 0.5 })
	end
	Camera.trauma(0.2 * Camera.involves(ctx.attacker, ctx.victim))
end

-- The victim's body flying away: speed lines along the throw.
local function thrown(ctx: HitContext, seconds: number)
	Limb.speedLines(ctx.victim, seconds, { dir = ctx.dir })
end

-- A held body driven into the floor (Body Slam / Powerbomb).
local function slam(ctx: HitContext, debris: number, crack: number, scale: number): Vector3
	local torso = torsoOf(ctx.victim)
	local at = if torso then torso.Position else ctx.point
	Impact.groundSlam(at, "Slam", {
		attacker = ctx.attacker,
		victim = ctx.victim,
		debris = debris,
		crack = crack,
		scale = scale,
	})
	return at
end

------------------------------------------------------------------------------
-- Swings (clip specs: the trails while the animation plays)
------------------------------------------------------------------------------

local clips: { [string]: Types.ClipSpec } = {
	-- both palms out to the chest (contact 0.22)
	Bouncer_Shove = {
		beats = { { at = 0.22, limb = "BothArms", swing = 0.06, after = 0.03, life = 0.1 } },
	},
	-- the reach of every grab (the hands close at 0.28)
	Bouncer_Grab = {
		beats = { { at = 0.28, limb = "BothArms", swing = 0.08, after = 0.02, life = 0.1 } },
	},
	-- both fists down on the head (0.40): heavy, so a smear and a pre-dim
	Bouncer_HammerFist = {
		beats = {
			{
				at = 0.4,
				limb = "BothArms",
				swing = 0.08,
				after = 0.03,
				life = 0.14,
				smear = true,
				preDim = true,
			},
		},
	},
	-- two hammer fists; the 2nd (0.95) is the one that floors them
	Bouncer_DoubleHammer = {
		beats = {
			{ at = 0.4, limb = "BothArms", swing = 0.08, after = 0.03, life = 0.14 },
			{
				at = 0.95,
				limb = "BothArms",
				swing = 0.09,
				after = 0.03,
				life = 0.14,
				smear = true,
				preDim = true,
			},
		},
	},
	-- The held one's clips: their body cuts the air on the way down / out.
	Bouncer_SlamVictim = {
		run = function(ctx)
			Limb.trailWindow(ctx.model, "Torso", 0.6, 1.0, { life = 0.18, width = 0.9 })
		end,
	},
	Bouncer_PowerbombVictim = {
		run = function(ctx)
			Limb.trailWindow(ctx.model, "Torso", 0.8, 1.15, { life = 0.2, width = 1 })
		end,
	},
	Bouncer_ThrowVictim = {
		run = function(ctx)
			Limb.trailWindow(ctx.model, "Torso", 0.35, 0.65, { life = 0.18, width = 0.9 })
		end,
	},
	-- CLOSING TIME: he squares up and stamps at 0.62 (crack, chips, a big
	-- dust ring, the world drained of colour a moment). His breath steaming
	-- stays in BouncerFx.
	Bouncer_Awaken = {
		run = function(ctx)
			ctx.later(0.62, function()
				Impact.awakening(ctx.model, "Bouncer")
			end)
		end,
	},
}

------------------------------------------------------------------------------
-- Contacts (move specs: when the server says it landed)
------------------------------------------------------------------------------

local moves: { [string]: Types.MoveSpec } = {
	-- Two palms: air and dust, no sparks. The body flies back 40 studs/s.
	-- (BouncerFx still scrapes the victim's feet.)
	Shove = {
		tier = "Clean",
		material = "Palm",
		limb = "BothArms",
		onHit = function(ctx)
			thrown(ctx, 0.25)
		end,
	},
	-- On the guard: the guard spark, and the air still moves.
	Shove_Blocked = {
		tier = "Blocked",
		material = "Guard",
		limb = "BothArms",
		onHit = function(ctx)
			Layers.shockRing(
				ctx.point + ctx.dir * 0.3,
				ctx.dir,
				{ from = 0.5, to = 2.5, life = 0.2 }
			)
		end,
	},

	-- The catches (the move id itself: "Hit" with the grab's 2 damage).
	Chokehold = { noDefault = true, onHit = catch },
	SleeperHold = { noDefault = true, onHit = catch },
	BodySlam = { noDefault = true, onHit = catch },
	ThrowOut = { noDefault = true, onHit = catch },
	Powerbomb = { noDefault = true, onHit = catch },

	-- The squeezes: nothing flashes (BouncerFx: the face, the spit, the
	-- vignette). The Sleeper's last "hit" drops the limp body: its dust is
	-- Impact.landing's (HitFx starts it for every knockdown).
	Chokehold_Hold = { noDefault = true },
	SleeperHold_Hold = { noDefault = true },

	-- Lifted and slammed on the back.
	BodySlam_Hold = {
		noDefault = true,
		onHit = function(ctx)
			slam(ctx, 4, 4, 1)
		end,
	},
	-- Up on his shoulders, then down: the biggest hit of the game. The dark
	-- ring of pressure lines even when it doesn't knock out (no KO impact
	-- frame unless it does: HitFx adds that). The dust cloud that hangs
	-- after it is BouncerFx's (its slam haze), so none is added here.
	Powerbomb_Hold = {
		noDefault = true,
		onHit = function(ctx)
			local at = slam(ctx, 7, 6, 1.25)
			Layers.pressureLines(at + Vector3.yAxis * 0.4, Vector3.yAxis, 4)
		end,
	},
	-- Thrown across the room: the release pushes like a shove; speed lines
	-- while the body flies (Impact.landing does the wall / floor it meets).
	ThrowOut_Hold = {
		tier = "Clean",
		material = "Palm",
		onHit = function(ctx)
			thrown(ctx, 0.4)
		end,
	},

	-- Both fists down on the head: the air ring lies flat under them. No
	-- floor dust (it's a blow to the head, not the floor).
	HammerFist = {
		noDefault = true,
		limb = "BothArms",
		tier = "Heavy",
		onHit = function(ctx)
			-- (BouncerFx throws the spit and sweat off the head: no specks here)
			hit(ctx, { ringFacing = -Vector3.yAxis, floor = false, skip = { specks = true } })
		end,
	},
	-- Twice; the 2nd is the "Last" one and drives them into the floor (a
	-- small slam under the victim: crack, debris, no 2nd camera hit).
	DoubleHammer = {
		noDefault = true,
		limb = "BothArms",
		tiers = { "Heavy", "Last" },
		onHit = function(ctx)
			local last = ctx.index >= 2
			-- (no floor dust ring from the hit itself: the small slam below
			-- already throws the dust out from under the victim; the spit and
			-- sweat are BouncerFx's)
			hit(ctx, { ringFacing = -Vector3.yAxis, floor = false, skip = { specks = true } })
			if last then
				local root = ctx.victim:FindFirstChild("HumanoidRootPart")
				local under = if root and root:IsA("BasePart") then root.Position else ctx.point
				Impact.groundSlam(
					under,
					"Heavy",
					{ debris = 2, crack = 2.5, camera = false, scale = 0.7 }
				)
			end
		end,
	},
}

return { clips = clips, moves = moves } :: Types.SpecModule
