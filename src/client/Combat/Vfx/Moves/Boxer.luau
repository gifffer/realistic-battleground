--!strict
-- Vfx/Moves/Boxer: what the Boxer's moves LOOK like (PLAN §2.3): Jab Rush,
-- Uppercut, Slip (+ its counter hook), Liver Shot, the KNOCKOUT MODE
-- activation, and the Knockout Mode moves (Jab Flurry, Rising Uppercut,
-- the longer slip's counter, Knockout Combo). LIVER RIP (the finisher
-- cinematic) is in Moves/Cinematics.
-- Owner: K1 of the VFX overhaul.
--
-- How to read a spec: see Vfx/Types.luau (example at the top) and
-- Vfx/init.luau. Spec files may require ONLY the library's own modules,
-- never Vfx (init) or Vfx/HitFx (it requires us).
--
-- The Boxer is about RHYTHM (video16: clusters of quick hits, then a big
-- one). A flurry is a row of small, short pops; the hit that ends it is
-- clearly bigger. Hooks and body shots sweep across, uppercuts go UP: each
-- impact is aimed the way the fist really travels.

local Floor = require(script.Parent.Parent.Floor)
local Impact = require(script.Parent.Parent.Impact)
local Layers = require(script.Parent.Parent.Layers)
local Limb = require(script.Parent.Parent.Limb)
local Pool = require(script.Parent.Parent.Pool)
local Types = require(script.Parent.Parent.Types)

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

-- A hook sweeps across: the strike direction bent toward the attacker's
-- right (`side` = 1, a LEFT hook) or left (-1, a right hook). The air ring
-- faces the sweep too.
local function hook(args: Types.ImpactArgs, ctx: Types.HitContext, side: number)
	local root = rootOf(ctx.attacker)
	if root then
		local across = (ctx.dir * 0.5 + root.CFrame.RightVector * side * 0.85).Unit
		args.dir = across
		args.ringFacing = across
	end
end

-- An uppercut goes up: the strike direction tilted up, the ring flat
-- (facing the sky), the sparks and the camera kick upward.
local function upward(args: Types.ImpactArgs, ctx: Types.HitContext)
	args.dir = (ctx.dir * 0.6 + Vector3.yAxis).Unit
	args.ringFacing = Vector3.yAxis
end

-- A body shot lands low on the ribs, not at the middle of the torso.
local function low(args: Types.ImpactArgs, ctx: Types.HitContext)
	args.point = ctx.point - Vector3.yAxis * 0.5
end

-- The thrown / launched victim streams speed lines for `seconds`.
local function launched(ctx: Types.HitContext, seconds: number)
	Limb.speedLines(ctx.victim, seconds, { dir = ctx.dir + Vector3.yAxis * 1.5 })
end

-- A little dust under the boxer's feet: the level change / dip before a
-- big punch (the weight drops onto the floor).
local function dipDust(model: Model)
	local root = rootOf(model)
	local floor = if root then Floor.at(root.Position, 4) else nil
	if root == nil or floor == nil then
		return
	end
	Layers.dustRing(floor.position, {
		puffs = 4,
		speed = 5,
		size = 0.5,
		color = Floor.dustColor(floor),
		dir = -root.CFrame.LookVector,
	})
end

-- The winded victim: a short gasp out of the mouth, twice.
local function winded(victim: Model)
	for _, delay in { 0.12, 0.5 } do
		Pool.after(delay, function()
			if victim.Parent ~= nil then
				Layers.breath(victim, { size = 0.35, count = 2 })
			end
		end)
	end
end

-- One quick jab's trail beat: only the fast 3-5 frames before the contact.
local function jabBeat(at: number, limb: Types.Limb): Types.BeatSpec
	return { at = at, limb = limb, swing = 0.05, after = 0.03, life = 0.09 }
end

-- A hook's trail beat (longer-lived so the arc reads).
local function hookBeat(at: number, limb: Types.Limb): Types.BeatSpec
	return { at = at, limb = limb, swing = 0.07, after = 0.03, life = 0.16, arc = true }
end

------------------------------------------------------------------------------
-- Clips (the swings)
------------------------------------------------------------------------------

local clips: { [string]: Types.ClipSpec } = {}

-- Jab Rush: four left jabs (0.12, 0.27, 0.42, 0.57).
clips.Boxer_JabRush = {
	beats = {
		jabBeat(0.12, "LeftArm"),
		jabBeat(0.27, "LeftArm"),
		jabBeat(0.42, "LeftArm"),
		jabBeat(0.57, "LeftArm"),
	},
}

-- Jab Flurry: four left jabs, the right cross (0.58), the left hook (0.72).
clips.Boxer_JabRushPlus = {
	beats = {
		jabBeat(0.1, "LeftArm"),
		jabBeat(0.22, "LeftArm"),
		jabBeat(0.34, "LeftArm"),
		jabBeat(0.46, "LeftArm"),
		{ at = 0.58, limb = "RightArm", swing = 0.06, after = 0.03, life = 0.11 },
		hookBeat(0.72, "LeftArm"),
	},
}

-- Uppercut / Rising Uppercut (contact 0.25): the dip at 0.15 pushes a bit
-- of dust off the floor, then the fist rises (arc trail + smear), and for
-- us the screen dims 2 frames before the contact.
clips.Boxer_Uppercut = {
	beats = {
		{
			at = 0.25,
			limb = "RightArm",
			swing = 0.06,
			after = 0.03,
			life = 0.14,
			arc = true,
			smear = true,
			preDim = true,
		},
	},
	run = function(ctx)
		ctx.later(0.15, function()
			dipDust(ctx.model)
		end)
	end,
}

-- The slip's counter (contact 0.18): the clip starts from the slipped
-- pose, so one ghost of that pose stays behind (the slip worked), then the
-- left hook uncoils.
clips.Boxer_SlipCounter = {
	beats = { hookBeat(0.18, "LeftArm") },
	run = function(ctx)
		Limb.afterimage(ctx.model, { count = 1, fade = 0.2 })
	end,
}

-- Liver Shot (contact 0.28): the level change at 0.13 (dust off the
-- floor), then the left body hook.
clips.Boxer_LiverShot = {
	beats = { hookBeat(0.28, "LeftArm") },
	run = function(ctx)
		ctx.later(0.13, function()
			dipDust(ctx.model)
		end)
	end,
}

-- KNOCKOUT MODE: the gloves touch at 0.40, that's the beat (a tiny warm pop
-- between the gloves, sweat mist off the shoulders, the world drained of
-- colour for an instant). The glow that stays is KitEffects (setFury).
clips.Boxer_Awaken = {
	run = function(ctx)
		ctx.later(0.4, function()
			Impact.awakening(ctx.model, "Boxer", Limb.tip(ctx.model, "BothArms"))
		end)
	end,
}

-- Knockout Combo: left body hook (0.20), right hook (0.50), left hook
-- (0.85), then the big right uppercut (1.25) with a smear and the pre-dim.
clips.Boxer_KnockoutCombo = {
	beats = {
		{ at = 0.2, limb = "LeftArm", swing = 0.06, after = 0.03, life = 0.14, arc = true } :: Types.BeatSpec,
		hookBeat(0.5, "RightArm"),
		hookBeat(0.85, "LeftArm"),
		{
			at = 1.25,
			limb = "RightArm",
			swing = 0.08,
			after = 0.03,
			life = 0.16,
			arc = true,
			smear = true,
			preDim = true,
		},
	},
}

------------------------------------------------------------------------------
-- Moves (the contacts)
------------------------------------------------------------------------------

local moves: { [string]: Types.MoveSpec } = {}

-- Jab Rush: small Light pops ×3, the 4th a Clean one (it gets the ring):
-- you can hear the rhythm in the picture.
moves.JabRush = { tiers = { "Light", "Light", "Light", "Clean" }, limb = "LeftArm" }

-- Jab Flurry: four Light jabs, the right cross as the accent (Clean + one
-- streak back along the arm), then the left hook ends it: the Last stack
-- (dim, push-in, two rings; floor dust only if the floor is right there).
moves.JabRushPlus = {
	tiers = { "Light", "Light", "Light", "Light", "Clean", "Last" },
	limb = { "LeftArm", "LeftArm", "LeftArm", "LeftArm", "RightArm", "LeftArm" },
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, ctx.tier)
		if ctx.index == 5 then
			args.skip = { streaks = true }
			Impact.hit(args)
			local root = rootOf(ctx.attacker)
			local back = if root then root.Position + Vector3.yAxis * 0.8 - ctx.point else -ctx.dir
			Layers.streaks(ctx.point, ctx.dir, 2, 4, { backAlong = back })
			return
		end
		if ctx.index >= 6 then
			hook(args, ctx, 1)
		end
		Impact.hit(args)
	end,
}

-- Uppercut: Heavy, aimed up (flat ring, sparks up); the victim is launched.
moves.Uppercut = {
	tier = "Heavy",
	limb = "RightArm",
	ringFacing = "Up",
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, "Heavy")
		upward(args, ctx)
		Impact.hit(args)
		launched(ctx, 0.3)
	end,
}

-- Rising Uppercut: the same, as the Last stack (dust blown off the floor
-- under the victim as he leaves it).
moves.UppercutPlus = {
	tier = "Last",
	limb = "RightArm",
	ringFacing = "Up",
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, "Last")
		upward(args, ctx)
		Impact.hit(args)
		launched(ctx, 0.35)
	end,
}

-- The slip's counter hook: a punish. Heavy (Last in Knockout Mode), a bit
-- sharper than a normal heavy blow, both views kicked (the tier's kick);
-- no floor dust (it's a hook to the head).
local function counterHook(tier: Types.Tier): Types.MoveSpec
	return {
		tier = tier,
		limb = "LeftArm",
		noDefault = true,
		onHit = function(ctx)
			local args = argsFor(ctx, tier)
			hook(args, ctx, 1)
			args.scale = 1.1
			args.floor = false
			Impact.hit(args)
		end,
	}
end

moves.Slip_Counter = counterHook("Heavy")
moves.SlipPlus_Counter = counterHook("Last")

-- Liver Shot: Clean, low on the victim's right ribs, swept across; dust off
-- the shirt (the tier's puff); the victim is winded (two gasps).
moves.LiverShot = {
	tier = "Clean",
	limb = "LeftArm",
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, "Clean")
		hook(args, ctx, 1)
		low(args, ctx)
		Impact.hit(args)
		winded(ctx.victim)
	end,
}

-- Knockout Combo: it escalates. Clean (left body hook, low), Clean (right
-- hook), Heavy (left hook, no floor dust), Last (the right uppercut: up,
-- dust off the floor, push-in; the victim is launched).
moves.KnockoutCombo = {
	tiers = { "Clean", "Clean", "Heavy", "Last" },
	limb = { "LeftArm", "RightArm", "LeftArm", "RightArm" },
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, ctx.tier)
		if ctx.index <= 1 then
			hook(args, ctx, 1)
			low(args, ctx)
		elseif ctx.index == 2 then
			hook(args, ctx, -1)
		elseif ctx.index == 3 then
			hook(args, ctx, 1)
			args.floor = false
		else
			upward(args, ctx)
		end
		Impact.hit(args)
		if ctx.index >= 4 then
			launched(ctx, 0.35)
		end
	end,
}

return { clips = clips, moves = moves } :: Types.SpecModule
