--!strict
-- Vfx/Moves/Base: what the base combat LOOKS like, for every kit (PLAN §2.1):
-- the M1 combo (jab, cross, hook, overhand), a hit on the guard, a parry,
-- a guard break, a dodge, the four dashes, the plain "Finisher" clip
-- (FINAL BLOW and the Tackle Slam follow-up swing) and getting back up.
-- Owner: K1 of the VFX overhaul.
--
-- How to read a spec: see Vfx/Types.luau (example at the top) and
-- Vfx/init.luau. Spec files may require ONLY the library's own modules
-- (script.Parent.Parent.Impact / Layers / Limb / Camera / Tiers / Palette /
-- Types / Floor / Pool), never Vfx (init) or Vfx/HitFx (it requires us).
--
-- The rules every effect here follows (docs/references/README.md, video16):
--   • it is tied to one frame of the motion: the swing trail runs only
--     during the fast part of the blow, the impact pops on the contact frame;
--   • a miss shows only the swing trail; a blocked blow only the small warm
--     spark on the guard;
--   • the last blow of the combo (the overhand) is clearly bigger.

local Players = game:GetService("Players")

local Camera = require(script.Parent.Parent.Camera)
local Floor = require(script.Parent.Parent.Floor)
local Impact = require(script.Parent.Parent.Impact)
local Layers = require(script.Parent.Parent.Layers)
local Limb = require(script.Parent.Parent.Limb)
local Pool = require(script.Parent.Parent.Pool)
local Types = require(script.Parent.Parent.Types)

local player = Players.LocalPlayer

-- The M1 contact time (Config.Combat.HIT_DELAY, read through Impact so
-- this file needs no other require). The punch clips keep their contact
-- keyframe exactly there.
local HIT = Impact.HIT_DELAY

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The default impact arguments for a hit (the spec then changes a few).
local function argsFor(ctx: Types.HitContext, tier: Types.Tier): Types.ImpactArgs
	return {
		point = ctx.point,
		dir = ctx.dir,
		tier = tier,
		attacker = ctx.attacker,
		victim = ctx.victim,
		blood = ctx.blood,
	}
end

-- A little floor-coloured dust under `model`'s feet (a weight shift, a
-- foot pushing off). `dir` = which way the dust goes.
local function feetDust(model: Model, dir: Vector3, size: number, count: number)
	local root = rootOf(model)
	if root == nil then
		return
	end
	local floor = Floor.at(root.Position, 4)
	if floor == nil then
		return
	end
	Layers.puff(
		floor.position + Vector3.yAxis * 0.2,
		dir + Vector3.yAxis * 0.3,
		size,
		count,
		{ color = Floor.dustColor(floor), delayFrames = 0, life = 0.45 }
	)
end

-- When each fighter last started the heavy 4th M1 (to make a blocked
-- overhand feel heavier on the guard).
local overhandAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

------------------------------------------------------------------------------
-- Clips (the swings)
------------------------------------------------------------------------------

local clips: { [string]: Types.ClipSpec } = {}

-- M1 1, the jab (lead / left hand): the snappiest blow, a short faint trail
-- only on the fast part (0.095 → 0.18 s).
clips.Brawler_M1_1 = {
	beats = { { at = HIT, limb = "LeftArm", swing = 0.055, after = 0.03, life = 0.1 } },
}

-- M1 2, the cross (rear / right hand): a little longer.
clips.Brawler_M1_2 = {
	beats = { { at = HIT, limb = "RightArm", swing = 0.06, after = 0.035, life = 0.11 } },
}

-- M1 3, the hook (lead hand): a longer, wider-lived trail so the arc reads.
clips.Brawler_M1_3 = {
	beats = {
		{ at = HIT, limb = "LeftArm", swing = 0.065, after = 0.04, life = 0.16, arc = true },
	},
}

-- M1 4, the overhand ender: the weight shifts onto the rear foot first (a
-- scuff of dust), then the arm comes over the top with a smear and, for
-- us, the screen dims 2 frames before the contact (video16: the dim comes
-- BEFORE the heavy hit).
clips.Brawler_M1_4 = {
	beats = {
		{
			at = HIT,
			limb = "RightArm",
			-- (on at 0.09 s: the end of the load, when the arm stops going
			-- back and starts coming over; not during the wind-up)
			swing = 0.06,
			after = 0.04,
			life = 0.14,
			smear = true,
			preDim = true,
		},
	},
	run = function(ctx)
		overhandAt[ctx.model] = os.clock()
		ctx.later(0.04, function()
			local root = rootOf(ctx.model)
			if root then
				feetDust(ctx.model, -root.CFrame.LookVector, 0.45, 1)
			end
		end)
	end,
}

-- The four dashes: a kick of dust thrown back from the feet, one ghost of
-- the body left at the start, short speed lines and the feet scraping.
local DASH_DIRECTION: { [string]: (CFrame) -> Vector3 } = {
	DashForward = function(cframe)
		return cframe.LookVector
	end,
	DashBack = function(cframe)
		return -cframe.LookVector
	end,
	DashLeft = function(cframe)
		return -cframe.RightVector
	end,
	DashRight = function(cframe)
		return cframe.RightVector
	end,
}

local function dash(ctx: Types.ActionContext)
	local root = rootOf(ctx.model)
	local direction = DASH_DIRECTION[ctx.clip]
	if root == nil or direction == nil then
		return
	end
	local going = direction(root.CFrame)
	local floor = Floor.at(root.Position, 4)
	if floor then
		-- (a half ring of dust kicked back, opposite the dash)
		Layers.dustRing(floor.position, {
			puffs = 5,
			speed = 8,
			size = 0.6,
			color = Floor.dustColor(floor),
			dir = -going,
		})
	end
	Limb.afterimage(ctx.model, { count = 1, fade = 0.18 })
	Limb.speedLines(ctx.model, 0.18, { dir = going, rate = 70 })
	Limb.scrape(ctx.model, 0.2)
end

for name in DASH_DIRECTION do
	clips[name] = { run = dash }
end

-- "Finisher": FINAL BLOW (kneel over the knocked-out body and strike) and
-- the swing of Street Fury's Tackle Slam follow-up. The knee drops at 0.15
-- s (a little dust), the fist comes down 0.3 → 0.45 s and hits the body
-- on the floor at 0.45 s: a ground slam there (no server event tells us
-- the moment of FINAL BLOW, so it is timed on the clip).
clips.Finisher = {
	beats = {
		{ at = 0.45, limb = "RightArm", swing = 0.15, after = 0.03, life = 0.14, smear = true },
	},
	run = function(ctx)
		ctx.later(0.15, function()
			local knee = Limb.tip(ctx.model, "RightLeg")
			local floor = if knee then Floor.at(knee, 3) else nil
			if floor then
				Layers.puff(
					floor.position + Vector3.yAxis * 0.15,
					Vector3.yAxis,
					0.5,
					2,
					{ color = Floor.dustColor(floor), delayFrames = 0, life = 0.6 }
				)
			end
		end)
		ctx.later(0.45, function()
			local fist = Limb.tip(ctx.model, "RightArm")
			if fist then
				Impact.groundSlam(fist, "Slam", { attacker = ctx.model, debris = 3, crack = 3 })
			end
		end)
	end,
}

-- Getting back up: a bit of dust where the hands and the knee push on the
-- floor.
clips.GetUp = {
	run = function(ctx)
		ctx.later(0.1, function()
			for _, limb in { "RightArm", "LeftArm", "RightLeg" } :: { Types.Limb } do
				local tip = Limb.tip(ctx.model, limb)
				local floor = if tip then Floor.at(tip + Vector3.yAxis, 3) else nil
				if floor then
					Layers.puff(
						floor.position + Vector3.yAxis * 0.15,
						Vector3.yAxis,
						0.4,
						1,
						{ color = Floor.dustColor(floor), delayFrames = 0, life = 0.6 }
					)
				end
			end
		end)
	end,
}

------------------------------------------------------------------------------
-- Moves (the contacts)
------------------------------------------------------------------------------

local moves: { [string]: Types.MoveSpec } = {}

-- The jab: the Light stack (small flash, one streak, a few specks).
moves.M1_1 = { tier = "Light", limb = "LeftArm" }

-- The cross: Clean, and one streak back along the punching arm (video16:
-- the force going in), drawn with the streaks out the far side.
moves.M1_2 = {
	tier = "Clean",
	limb = "RightArm",
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, "Clean")
		args.skip = { streaks = true }
		Impact.hit(args)
		local root = rootOf(ctx.attacker)
		local back = if root then root.Position + Vector3.yAxis * 0.8 - ctx.point else -ctx.dir
		Layers.streaks(ctx.point, ctx.dir, 2, 4, { width = 0.12, frames = 2, backAlong = back })
	end,
}

-- The hook (left hand): the fist sweeps across, toward the attacker's
-- right. The sparks, the streaks and the air ring follow that sweep, not
-- the straight line between the two fighters.
moves.M1_3 = {
	tier = "Clean",
	limb = "LeftArm",
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, "Clean")
		local root = rootOf(ctx.attacker)
		if root then
			local sweep = (ctx.dir * 0.5 + root.CFrame.RightVector * 0.85).Unit
			args.dir = sweep
			args.ringFacing = sweep
		end
		Impact.hit(args)
	end,
}

-- The overhand ender: the Last stack (dim, FOV punch, two air rings, dust
-- on the floor under the victim). The victim flies 45 studs/s: a short
-- burst of speed lines on him (HitFx watches the landing).
moves.M1_4 = {
	tier = "Last",
	limb = "RightArm",
	onHit = function(ctx)
		Limb.speedLines(ctx.victim, 0.2, { dir = Vector3.new(ctx.dir.X, 0, ctx.dir.Z) })
	end,
}

-- A blow on the guard: the Blocked stack on the guarding forearm (small
-- warm flash, 4 warm sparks, 3 specks) and a faint puff of dust shaken off
-- the sleeve. A blocked overhand also rocks the defender's view a little.
moves.Blocked = {
	tier = "Blocked",
	material = "Guard",
	onHit = function(ctx)
		Layers.puff(ctx.point, ctx.dir, 0.5, 1, { life = 0.4 })
		local started = overhandAt[ctx.attacker]
		if started and os.clock() - started < 0.4 and ctx.victim == player.Character then
			Camera.trauma(0.3)
		end
	end,
}

-- A parry (victim = the one who parried, attacker = the one parried): a
-- Clean pop in warm (guard) colours at the parrying forearm, the ring
-- facing the attacker, both views kicked back 1°, and the parried
-- attacker left off balance (one ghost of him). CombatEffectsController
-- already holds the 0.09 s hit-stop.
moves.Parried = {
	tier = "Clean",
	material = "Guard",
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, "Clean")
		args.material = "Guard"
		args.ringFacing = -ctx.dir
		Impact.hit(args)
		if Camera.involves(ctx.attacker, ctx.victim) >= 1 then
			Camera.kick(if ctx.attacker == player.Character then -ctx.dir else ctx.dir, 1)
		end
		Pool.afterFrames(2, function()
			Limb.afterimage(ctx.attacker, { count = 1, fade = 0.22 })
		end)
	end,
}

-- A guard break: Heavy, but on the guard (warm, no streaks through, no
-- blood specks). Only the one whose guard broke gets the dim and the
-- push-in; dust is knocked off both sleeves, and he gasps 0.15 s later.
moves.GuardBreak = {
	tier = "Heavy",
	material = "Guard",
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, "Heavy")
		args.material = "Guard"
		args.camera = false
		args.floor = false
		args.skip = { streaks = true }
		Impact.hit(args)
		local character = player.Character
		if ctx.victim == character then
			Camera.trauma(0.8)
			Camera.fovPunch(3)
			Camera.dim(0.12)
		elseif ctx.attacker == character then
			Camera.trauma(0.3)
		else
			Camera.trauma(0.3 * Camera.involves(ctx.victim), ctx.point, 40)
		end
		Layers.puff(ctx.point, ctx.dir, 0.8, 2, { life = 0.55 })
		Pool.after(0.15, function()
			if ctx.victim.Parent ~= nil then
				Layers.breath(ctx.victim, { size = 0.35, count = 2 })
			end
		end)
	end,
}

-- A dodge (victim = the one who dodged): no flash (nothing touched), two
-- ghosts of the dodger where the blow went through.
moves.Dodged = {
	noDefault = true,
	onHit = function(ctx)
		Limb.afterimage(ctx.victim, { count = 2, fade = 0.22, spacing = 0.05 })
	end,
}

-- Protected (spawn protection...): nothing at all.
moves.Protected = { noDefault = true }

return { clips = clips, moves = moves } :: Types.SpecModule
