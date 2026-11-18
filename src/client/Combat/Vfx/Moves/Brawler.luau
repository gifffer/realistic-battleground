--!strict
-- Vfx/Moves/Brawler: what the Street Brawler's moves LOOK like (PLAN §2.2):
-- Bottle Smash, Headbutt, Tackle, Dirty Kick, the STREET FURY activation,
-- and the Street Fury moves (Broken Bottle, Double Headbutt, Tackle Slam,
-- Kick Combo). HOME RUN (the finisher cinematic) is in Moves/Cinematics.
-- Owner: K1 of the VFX overhaul.
--
-- How to read a spec: see Vfx/Types.luau (example at the top) and
-- Vfx/init.luau. Spec files may require ONLY the library's own modules,
-- never Vfx (init) or Vfx/HitFx (it requires us).
--
-- The Brawler fights dirty and heavy: bottles, heads, shoulders, shins.
-- Each contact is ONE impact stack of the right tier, aimed the way the
-- limb (or the bottle) actually travels; the glass, beer and dust are the
-- realistic "extras" of that one hit, never a second explosion.
-- (The glass shards themselves are physical pieces in Combat/KitEffects.)

local Players = game:GetService("Players")

local Floor = require(script.Parent.Parent.Floor)
local Impact = require(script.Parent.Parent.Impact)
local Layers = require(script.Parent.Parent.Layers)
local Limb = require(script.Parent.Parent.Limb)
local Palette = require(script.Parent.Parent.Palette)
local Tiers = require(script.Parent.Parent.Tiers)
local Types = require(script.Parent.Parent.Types)

local player = Players.LocalPlayer

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

-- The strike direction bent toward the attacker's right (`side` = 1) or
-- left (-1): a hook, a round kick, a slash sweeps across, it doesn't go
-- straight in.
local function sweep(ctx: Types.HitContext, side: number): Vector3
	local root = rootOf(ctx.attacker)
	if root == nil then
		return ctx.dir
	end
	return (ctx.dir * 0.5 + root.CFrame.RightVector * side * 0.85).Unit
end

-- The thrown body streams speed lines for `seconds` (flat, along the blow).
local function thrown(ctx: Types.HitContext, seconds: number)
	Limb.speedLines(ctx.victim, seconds, { dir = Vector3.new(ctx.dir.X, 0, ctx.dir.Z) })
end

-- Dust thrown along the floor at `point` (a low kick scuffing the ground).
local function lowDust(point: Vector3, dir: Vector3, count: number)
	local floor = Floor.at(point + Vector3.yAxis, 4)
	if floor == nil then
		return
	end
	Layers.puff(
		floor.position + Vector3.yAxis * 0.25,
		Vector3.new(dir.X, 0.25, dir.Z),
		0.55,
		count,
		{ color = Floor.dustColor(floor), delayFrames = 1, life = 0.5 }
	)
end

-- Light / smear of the head for the headbutts (no trail: a trail on the
-- head would be drawn from under the chin).
local function headSmear(ctx: Types.ActionContext, at: number)
	Limb.track(ctx.model, true)
	ctx.later(at, function()
		Limb.smear(ctx.model, "Head", { ghosts = 2 })
	end)
end

------------------------------------------------------------------------------
-- Clips (the swings)
------------------------------------------------------------------------------

local clips: { [string]: Types.ClipSpec } = {}

-- Bottle Smash (contact 0.32): the bottle's arc over the top, a glint of
-- light on the glass on its fastest frame (0.27).
clips.Brawler_Bottle = {
	beats = { { at = 0.32, limb = "Prop", swing = 0.08, after = 0.03, life = 0.12 } },
	run = function(ctx)
		ctx.later(0.27, function()
			Limb.glint(ctx.model, "Prop")
		end)
	end,
}

-- Headbutt (contact 0.22): the head snaps forward (a 2-ghost smear).
clips.Brawler_Headbutt = {
	run = function(ctx)
		headSmear(ctx, 0.22)
	end,
}

-- Tackle / Tackle Slam (charge 0.10 → 0.55): the rear foot drives off at
-- 0.10 (dust kicked back), speed lines and the feet scraping during the
-- charge, a skid of dust when it stops at 0.55.
clips.Brawler_Tackle = {
	run = function(ctx)
		ctx.later(0.1, function()
			local root = rootOf(ctx.model)
			if root == nil then
				return
			end
			local floor = Floor.at(root.Position, 4)
			if floor then
				Layers.dustRing(floor.position, {
					puffs = 5,
					speed = 9,
					size = 0.6,
					color = Floor.dustColor(floor),
					dir = -root.CFrame.LookVector,
				})
			end
			Limb.speedLines(ctx.model, 0.45, { dir = root.CFrame.LookVector, rate = 80 })
			Limb.scrape(ctx.model, 0.45)
		end)
		ctx.later(0.55, function()
			local root = rootOf(ctx.model)
			if root then
				lowDust(root.Position - Vector3.yAxis * 2.5, root.CFrame.LookVector, 3)
			end
		end)
	end,
}

-- Dirty Kick (contact 0.20): a short trail on the kicking foot.
clips.Brawler_DirtyKick = {
	beats = { { at = 0.2, limb = "RightLeg", swing = 0.06, after = 0.03, life = 0.1 } },
}

-- STREET FURY: the neck cracks one way (0.29), then the other (0.46):
-- that second crack is the moment the fury "turns on" (a short warm pop,
-- the world drained of colour, dust pushed out along the floor, a breath
-- of steam). The red glow that stays is Combat/KitEffects (setFury).
clips.Brawler_Awaken = {
	run = function(ctx)
		ctx.later(0.46, function()
			Impact.awakening(ctx.model, "Street")
		end)
	end,
}

-- Broken Bottle (contacts 0.20 forehand, 0.45 backhand): the jagged glass
-- leaves a thin trail on each slash and glints just before it cuts.
clips.Brawler_BrokenBottle = {
	beats = {
		{ at = 0.2, limb = "Prop", swing = 0.06, after = 0.02, life = 0.12 },
		{ at = 0.45, limb = "Prop", swing = 0.07, after = 0.02, life = 0.12 },
	},
	run = function(ctx)
		for _, at in { 0.16, 0.41 } do
			ctx.later(at, function()
				Limb.glint(ctx.model, "Prop")
			end)
		end
	end,
}

-- Double Headbutt (contacts 0.22, 0.52): a head smear on both.
clips.Brawler_DoubleHeadbutt = {
	run = function(ctx)
		headSmear(ctx, 0.22)
		headSmear(ctx, 0.52)
	end,
}

-- Kick Combo: a low kick (0.20), then the high round kick (0.50) with a
-- longer arcing trail and a smear on the leg.
clips.Brawler_KickCombo = {
	beats = {
		{ at = 0.2, limb = "RightLeg", swing = 0.06, after = 0.03, life = 0.1 },
		{
			at = 0.5,
			limb = "RightLeg",
			swing = 0.08,
			after = 0.04,
			life = 0.16,
			arc = true,
			smear = true,
		},
	},
}

------------------------------------------------------------------------------
-- Moves (the contacts)
------------------------------------------------------------------------------

local moves: { [string]: Types.MoveSpec } = {}

-- Bottle Smash: Heavy, but it is GLASS that breaks: a warm-white pop a bit
-- smaller than a heavy punch, warm sparks + glass glints, a spray of beer
-- (falling droplets), an air ring the size of a clean blow, no dust puff.
local function bottleBurst(ctx: Types.HitContext)
	local args = argsFor(ctx, "Heavy")
	args.material = "Glass"
	args.scale = 0.85
	args.floor = false
	args.skip = { ring = true }
	Impact.hit(args)
	local clean = Tiers.get("Clean")
	Layers.shockRing(ctx.point + ctx.dir * 0.3, ctx.dir, {
		from = clean.ringSize * 0.18,
		to = clean.ringSize,
		life = 0.18,
	})
	Layers.specks(ctx.point, ctx.dir, 12, { color = Palette.Beer, delayFrames = 0 })
end

moves.BottleSmash = {
	tier = "Heavy",
	limb = "Prop",
	material = "Glass",
	noDefault = true,
	onHit = bottleBurst,
}

-- Blocked: the bottle still bursts on the forearms: the small blocked pop,
-- in glass (warm sparks + glints), nothing more.
moves.BottleSmash_Blocked = { tier = "Blocked", limb = "Prop", material = "Glass" }

-- Headbutt: Heavy on the face (no floor dust: it's at head height). Without
-- blood, a few droplets go up from the nose.
moves.Headbutt = {
	tier = "Heavy",
	limb = "Head",
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, "Heavy")
		args.floor = false
		Impact.hit(args)
		if not ctx.blood then
			Layers.specks(ctx.point, -ctx.dir + Vector3.yAxis * 1.5, 3, { delayFrames = 1 })
		end
	end,
}

-- Tackle (and Tackle Slam's charge): the shoulder into the chest. Heavy,
-- but a shove more than a punch: no streaks through the body, a big puff
-- off the shirt, the ring facing the charge; the victim flies (speed
-- lines; HitFx watches where he lands).
local function tackleHit(ctx: Types.HitContext)
	local args = argsFor(ctx, "Heavy")
	args.floor = false
	args.skip = { streaks = true, puff = true }
	Impact.hit(args)
	Layers.puff(ctx.point, ctx.dir, Tiers.get("Heavy").puff * 1.5, 3)
	thrown(ctx, 0.25)
end

moves.Tackle = { tier = "Heavy", limb = "Torso", noDefault = true, onHit = tackleHit }
moves.TackleSlam = { tier = "Heavy", limb = "Torso", noDefault = true, onHit = tackleHit }

-- Tackle Slam's ground strike (the "Finisher" clip, contact 0.45): the
-- clip already drives the fist into the floor (Base: groundSlam with its
-- dust ring, debris and crack). The server's hit adds the pop on the BODY
-- only: no second floor ring, no second air ring, and no second flash /
-- light either (the clip's slam flashed on this very spot a moment ago:
-- two pops would read as a double hit). The attacker's camera already
-- moved with the clip's slam; the victim's moves here.
moves.TackleSlam_FollowUp = {
	tier = "Slam",
	limb = "RightArm",
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, "Slam")
		args.dir = (ctx.dir * 0.4 - Vector3.yAxis).Unit
		args.camera = ctx.attacker ~= player.Character
		args.floor = false
		args.skip = { ring = true, flash = true, light = true }
		Impact.hit(args)
	end,
}

-- A low kick on the shin: Clean, swept sideways (a round kick goes across,
-- toward the kicker's left), plus dust scuffed off the floor at the foot.
local function lowKick(ctx: Types.HitContext)
	local args = argsFor(ctx, "Clean")
	local across = sweep(ctx, -1)
	args.dir = across
	args.ringFacing = across
	Impact.hit(args)
	lowDust(ctx.point, across, 4)
end

moves.DirtyKick = { tier = "Clean", limb = "RightLeg", noDefault = true, onHit = lowKick }

-- Kick Combo: the low kick (as Dirty Kick), then the high kick to the head:
-- the Last stack (dim, push-in, two rings, dust under the victim), swept
-- across; the victim is thrown (speed lines).
moves.KickCombo = {
	tiers = { "Clean", "Last" },
	limb = "RightLeg",
	noDefault = true,
	onHit = function(ctx)
		if ctx.index < 2 then
			lowKick(ctx)
			return
		end
		local args = argsFor(ctx, "Last")
		local across = sweep(ctx, -1)
		args.dir = across
		args.ringFacing = across
		Impact.hit(args)
		thrown(ctx, 0.3)
	end,
}

-- Broken Bottle: two cuts. A cut is not a punch: no air ring, one long thin
-- streak ALONG the slash (forehand goes to the attacker's left, backhand
-- to his right), glass glints. The second cut is a bit bigger. (The blood
-- of the cut is the blood stack.)
moves.BrokenBottle = {
	tiers = { "Clean", "Clean" },
	limb = "Prop",
	material = "Slash",
	noDefault = true,
	onHit = function(ctx)
		local args = argsFor(ctx, "Clean")
		args.material = "Slash"
		local scale = if ctx.index >= 2 then 1.2 else 1
		args.scale = scale
		args.skip = { streaks = true }
		Impact.hit(args)
		local along = sweep(ctx, if ctx.index >= 2 then 1 else -1)
		Layers.streaks(ctx.point - along * 1.6, along, 1, 4 * scale, {
			width = 0.08,
			frames = 3,
		})
		Layers.sparkBurst(ctx.point, along, { count = 6, palette = "Glass", spread = 70 })
	end,
}

-- Blocked: the glass scrapes the forearm: warm sparks on glass.
moves.BrokenBottle_Blocked = { tier = "Blocked", limb = "Prop", material = "Glass" }

-- Double Headbutt: the first a Clean pop, the second the Last stack
-- (dim, push-in, two rings).
moves.DoubleHeadbutt = {
	tiers = { "Clean", "Last" },
	limb = "Head",
	onHit = function(ctx)
		if ctx.index >= 2 and not ctx.blood then
			Layers.specks(ctx.point, -ctx.dir + Vector3.yAxis * 1.5, 3, { delayFrames = 1 })
		end
	end,
}

return { clips = clips, moves = moves } :: Types.SpecModule
