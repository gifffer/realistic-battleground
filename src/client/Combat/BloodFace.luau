--!strict
-- BloodFace: the wounds of the FACE, the way a real fight marks it (client).
--
-- Look at photos of boxers and street fights:
--   • a NOSEBLEED runs from a nostril, pauses on the upper lip, splits
--     around the mouth and hangs from the chin, a drop falling every second
--     or so, slower and slower as it stops (a broken nose: both nostrils).
--   • a SPLIT LIP: a film of blood along the lip, a short run from the
--     corner of the mouth to the jaw.
--   • the EYEBROW CUT (THE boxing cut): the skin splits on the brow bone, the
--     blood runs over the eyelid, down the cheek and drips off the jaw. It
--     REOPENS on later head hits. Cheekbone cuts do the same, shorter.
--   • between blows the fighter SPITS blood, BLOWS his nose, WIPES his face
--     with the back of his hand (the smear, then the blood wells up again).
--   • late in a fight sweat thins the blood: it runs further, lighter.
--   • old runs dry into a dark crust that stays (BloodRivulet does it).
--   • knocked out: the runs turn sideways and a pool grows under the head.
--
-- Every client opens the same wounds (the hit's seeded Random); the idle
-- spit / wipe can differ between screens (they're only details).
--
--   BloodFace.hit(model, attacker, info, random)   a head hit that drew blood
--   BloodFace.openWounds(model)    how many face wounds bleed now
--   BloodFace.isFresh(model)       true: no bloody hit yet, no bruise (an intact face)
--   BloodFace.noteAction(model)    the fighter did something (not idle)
--   BloodFace.onGetUp(model)       back on his feet: a wipe, a graze
--   BloodFace.watch(model)         knock-outs (sideways runs, the halo pool)
--   BloodFace.setHandHook(fn)      (BloodBody: the wiping hand gets bloody)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Bruise = require(ReplicatedStorage.Shared.Util.Bruise)
local Blood = require(script.Parent.Blood)
local BloodAge = require(script.Parent.BloodAge)
local BloodPool = require(script.Parent.BloodPool)
local BloodRivulet = require(script.Parent.BloodRivulet)
local BloodStain = require(script.Parent.BloodStain)

local BloodFace = {}

local BLOOD = Config.Blood :: any
local PALETTE = Config.Blood.PALETTE
local EXTRA = BLOOD.PALETTE :: any
-- (new colours of the v2 palette, with the same values if it isn't there)
local SALIVA: Color3 = EXTRA.SALIVA or Color3.fromRGB(168, 38, 36) -- blood + saliva
local RAW: Color3 = EXTRA.RAW or Color3.fromRGB(190, 80, 72) -- scraped skin
local FACE = BLOOD.FACE or {}
local CUTS: boolean = if FACE.CUTS == false then false else true
local SWEAT_AFTER: number = FACE.SWEAT_AFTER or 6
local UP = Vector3.new(0, 1, 0)

-- Where things are on the classic R6 head, in the head's own space (its
-- front is -Z, +X is the fighter's RIGHT, the centre is 0,0,0). Estimated:
-- check them once on a dummy in Studio and tune here if a run starts off
-- the nostril. `x` = the right side; the left side is (-x, y, z).
local NOSTRIL = Vector3.new(0.05, -0.12, -0.62)
local UPPER_LIP = Vector3.new(0, -0.2, -0.6)
local MOUTH_CORNER = Vector3.new(0.14, -0.27, -0.58)
local MOUTH_SPLIT = Vector3.new(0.1, -0.26, -0.59) -- (a nose run going round the mouth)
local LOWER_LIP = Vector3.new(0, -0.31, -0.57)
local CHIN = Vector3.new(0, -0.4, -0.52)
local EYE = Vector3.new(0.17, 0.07, -0.6)
local BROW = Vector3.new(0.2, 0.2, -0.58)
local CHEEK_RUN = Vector3.new(0.25, -0.15, -0.55)
local CHEEKBONE = Vector3.new(0.3, -0.02, -0.5)
local JAW = Vector3.new(0.32, -0.4, -0.4)
local JAW_EDGE = Vector3.new(0.16, -0.4, -0.5)

-- (left side of the face: the same spot, mirrored)
local function side(v: Vector3, sign: number): Vector3
	return Vector3.new(v.X * sign, v.Y, v.Z)
end

-- The picture to draw: `wanted` once uploaded, else a close uploaded one.
local function kind(wanted: string, fallback: string): string
	return if BloodStain.hasImage(wanted) then wanted else fallback
end
local function profile(wanted: string, fallback: string): string
	return if (Config.Blood.PROFILES :: any)[wanted] then wanted else fallback
end
local CUT_PROFILE = profile("cut", "wound")
local CRUST_PROFILE = profile("crust", "wound")

------------------------------------------------------------------------------
-- State per fighter
------------------------------------------------------------------------------

type Wound = {
	name: string, -- "nose", "mouth", "browL", "browR", "cheekL", "cheekR"
	sign: number, -- +1 the right side, -1 the left
	opened: number, -- when it (re)started bleeding
	activeUntil: number,
	broken: boolean, -- (the nose)
	cut: BloodAge.Record?, -- the split skin (cuts)
	runs: { BloodRivulet.Rivulet },
	start: number, -- interval of its drops at first (seconds)...
	finish: number, -- ...and at the end
}

type State = {
	model: Model,
	wounds: { [string]: Wound },
	bloodyHits: number,
	lastAction: number,
	lastHit: number,
	nextIdle: number,
	haloKey: { any },
	haloAt: number,
	grazes: number,
	getUps: number,
}

local states: { [Model]: State } = {}

local function stateOf(model: Model): State
	local state = states[model]
	if state then
		return state
	end
	local now = os.clock()
	local made: State = {
		model = model,
		wounds = {},
		bloodyHits = 0,
		lastAction = now,
		lastHit = now,
		nextIdle = now + 4,
		haloKey = {},
		haloAt = 0,
		grazes = 0,
		getUps = 0,
	}
	states[model] = made
	model.AncestryChanged:Connect(function()
		if model.Parent == nil and states[model] == made then
			states[model] = nil
		end
	end)
	return made
end

local function headOf(model: Model): BasePart?
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	return nil
end

local function isActive(wound: Wound?, now: number): boolean
	return wound ~= nil and now < wound.activeUntil
end

-- How many face wounds bleed now (a second blow on an open wound sprays more).
function BloodFace.openWounds(model: Model): number
	local state = states[model]
	if state == nil then
		return 0
	end
	local now = os.clock()
	local count = 0
	for _, wound in state.wounds do
		if isActive(wound, now) then
			count += 1
		end
	end
	return count
end

-- The worst bruise on the head (1..4; 0 none): softened skin cuts easier.
local function headBruise(model: Model): number
	local worst = 0
	for index = 1, Bruise.MAX_PER_PART do
		local data = Bruise.decode(model:GetAttribute(Bruise.attribute("Head", index)))
		if data then
			worst = math.max(worst, data.level)
		end
	end
	return worst
end

-- An intact face: no bloody hit yet and no bruise. The first punch on it
-- sprays much less (KitEffects) and opens a small nose trickle at most.
function BloodFace.isFresh(model: Model): boolean
	local state = states[model]
	return (state == nil or state.bloodyHits == 0) and headBruise(model) == 0
end

local handHook: ((Model, BasePart, number) -> ())? = nil

function BloodFace.setHandHook(hook: (Model, BasePart, number) -> ())
	handHook = hook
end

------------------------------------------------------------------------------
-- Runs from a wound
------------------------------------------------------------------------------

-- The drip interval of a wound now: fast at first, slower as it stops.
local function intervalOf(wound: Wound, random: Random): () -> number
	return function(): number
		local now = os.clock()
		local span = math.max(wound.activeUntil - wound.opened, 1)
		local t = math.clamp((now - wound.opened) / span, 0, 1)
		return (wound.start + (wound.finish - wound.start) * t * t) * random:NextNumber(0.85, 1.15)
	end
end

type RunSpec = {
	from: Vector3, -- head-local
	guides: { BloodRivulet.Guide },
	width: number,
	volume: number,
	start: Color3,
	source: any,
	onGuide: ((BloodRivulet.Rivulet, number) -> ())?,
}

local function startRun(state: State, wound: Wound, spec: RunSpec, random: Random)
	local head = headOf(state.model)
	if head == nil then
		return
	end
	local now = os.clock()
	local sweat = state.bloodyHits >= SWEAT_AFTER
	-- (sweat late in the fight: thinner blood, it runs further and lighter)
	local run = BloodRivulet.start(state.model, head, head.CFrame * spec.from, {
		width = spec.width * (if sweat then 1.2 else 1),
		volume = spec.volume * (if sweat then 1.3 else 1),
		start = if sweat then PALETTE.ARTERIAL_LIGHT else spec.start,
		alpha = if sweat then 0.1 else nil,
		guides = spec.guides,
		feed = math.max(0, wound.activeUntil - now),
		random = Random.new(random:NextInteger(1, 2 ^ 30)),
		source = spec.source,
		interval = intervalOf(wound, Random.new(random:NextInteger(1, 2 ^ 30))),
		crust = true,
		onGuide = spec.onGuide,
		onPool = function()
			BloodFace.halo(state.model)
		end,
	})
	if run then
		table.insert(wound.runs, run)
	end
end

local function woundOf(state: State, name: string, sign: number, seconds: number): Wound
	local now = os.clock()
	local wound = state.wounds[name]
	if wound == nil then
		local made: Wound = {
			name = name,
			sign = sign,
			opened = now,
			activeUntil = now + seconds,
			broken = false,
			cut = nil,
			runs = {},
			start = 1,
			finish = 3.5,
		}
		state.wounds[name] = made
		return made
	end
	if now >= wound.activeUntil then
		wound.opened = now
	end
	wound.activeUntil = math.max(wound.activeUntil, now)
		+ (if now < wound.activeUntil then seconds * 0.4 else seconds)
	return wound
end

-- Its runs: more blood, drips longer. Returns how many it still has.
local function feedRuns(wound: Wound, volume: number): number
	local now = os.clock()
	local keep: { BloodRivulet.Rivulet } = {}
	for _, run in wound.runs do
		if BloodRivulet.tip(run) then
			BloodRivulet.refeed(run, volume, math.max(0, wound.activeUntil - now))
			table.insert(keep, run)
		end
	end
	wound.runs = keep
	return #keep
end

------------------------------------------------------------------------------
-- The wounds
------------------------------------------------------------------------------

-- `light`: the first blow on an intact face. Real noses rarely pour on the
-- first punch: at most a short trickle from one nostril that stops quickly.
-- After that, each bloody hit makes the next nosebleed last a bit longer
-- (the vessels are already broken), up to ×1.5.
local function nose(state: State, random: Random, broken: boolean, light: boolean?)
	local escalate = math.min(1 + 0.1 * (state.bloodyHits - 1), 1.5)
	local seconds = if light
		then random:NextNumber(6, 12)
		else random:NextNumber(15, 40) * escalate + (if broken then 20 else 0)
	local wasActive = isActive(state.wounds.nose, os.clock())
	local wound = woundOf(state, "nose", 1, seconds)
	wound.start, wound.finish = random:NextNumber(0.8, 1.2), random:NextNumber(3, 4)
	if wasActive and not broken and feedRuns(wound, 0.2) > 0 then
		return -- (already bleeding: it bleeds more, the runs go on)
	end
	wound.broken = wound.broken or broken
	local signs: { number } = if broken
		then { -1, 1 }
		else { if random:NextNumber() < 0.5 then -1 else 1 }
	for _, sign in signs do
		local spec: RunSpec = {
			from = side(NOSTRIL, sign),
			guides = {
				{ point = UPPER_LIP + side(Vector3.new(0.02, 0, 0), sign), hold = 0.3 },
				{ point = side(MOUTH_SPLIT, sign) },
				{ point = CHIN + side(Vector3.new(0.03, 0, 0), sign) },
			},
			width = 0.045 * (if broken then 1.5 else 1),
			volume = if light then 0.2 else 0.45,
			start = PALETTE.ARTERIAL,
			-- (a later nosebleed rides this one's wet track)
			source = `{state.model:GetFullName()}|nose|{sign}`,
			onGuide = nil,
		}
		local splitRandom = Random.new(random:NextInteger(1, 2 ^ 30))
		spec.onGuide = function(run: BloodRivulet.Rivulet, index: number)
			-- on the upper lip it may split: a thinner run round the other side
			if light or index ~= 1 or splitRandom:NextNumber() > 0.35 then
				return
			end
			local head = headOf(state.model)
			local tip = BloodRivulet.tip(run)
			if head == nil or tip == nil then
				return
			end
			local now = os.clock()
			local fork = BloodRivulet.start(state.model, head, tip, {
				width = spec.width * 0.7,
				volume = 0.25,
				start = spec.start,
				guides = {
					{ point = side(MOUTH_SPLIT, -sign) },
					{ point = CHIN + side(Vector3.new(0.03, 0, 0), -sign) },
				},
				feed = math.max(0, wound.activeUntil - now) * 0.6,
				random = Random.new(splitRandom:NextInteger(1, 2 ^ 30)),
				interval = intervalOf(wound, Random.new(splitRandom:NextInteger(1, 2 ^ 30))),
				crust = true,
				noWell = true,
				noFork = true,
			})
			if fork then
				table.insert(wound.runs, fork)
			end
		end
		startRun(state, wound, spec, random)
	end
end

local function lipFilm(state: State, random: Random)
	local head = headOf(state.model)
	if head == nil then
		return
	end
	local cf = head.CFrame
	local record = BloodStain.place(
		kind("lipFilm", "skinSmear"),
		cf * LOWER_LIP,
		-cf.LookVector,
		cf.RightVector,
		0.07,
		0.24,
		{
			onto = head,
			random = random,
			profile = "smear",
			start = SALIVA:Lerp(PALETTE.ARTERIAL, 0.5),
			alpha = 0.25,
			owner = state.model,
			priority = 3,
		}
	)
	if record then
		BloodRivulet.addMark(state.model, record, false, true)
	end
end

local function mouth(state: State, random: Random)
	local now = os.clock()
	local wasActive = isActive(state.wounds.mouth, now)
	local wound = woundOf(state, "mouth", 1, random:NextNumber(10, 25))
	wound.start, wound.finish = random:NextNumber(1.5, 2), random:NextNumber(2.5, 3)
	if wasActive and feedRuns(wound, 0.1) > 0 then
		return
	end
	local sign = if random:NextNumber() < 0.5 then -1 else 1
	wound.sign = sign
	lipFilm(state, random)
	startRun(state, wound, {
		from = side(MOUTH_CORNER, sign),
		guides = { { point = side(JAW_EDGE, sign) } },
		width = 0.04,
		volume = 0.2,
		start = SALIVA:Lerp(PALETTE.ARTERIAL, 0.5),
		source = `{state.model:GetFullName()}|mouth`,
	}, random)
end

-- A cut on the brow ("brow") or the cheekbone ("cheek"), `sign` the side.
local function cut(state: State, where: string, sign: number, random: Random)
	local head = headOf(state.model)
	if head == nil or not CUTS then
		return
	end
	local name = where .. (if sign > 0 then "R" else "L")
	local now = os.clock()
	local isBrow = where == "brow"
	local wound = woundOf(
		state,
		name,
		sign,
		if isBrow then random:NextNumber(25, 60) else random:NextNumber(20, 45)
	)
	wound.start = if isBrow then random:NextNumber(0.6, 0.9) else random:NextNumber(1, 1.4)
	wound.finish = if isBrow then random:NextNumber(1.2, 1.5) else random:NextNumber(1.6, 2)
	local spot = side(if isBrow then BROW else CHEEKBONE, sign)
	if wound.cut == nil then
		-- the split skin itself (stays until respawn: a dark slit, then crust)
		local cf = head.CFrame
		local tilt = math.rad(random:NextNumber(-10, 10))
		local along = cf:VectorToWorldSpace(Vector3.new(math.cos(tilt), math.sin(tilt) * sign, 0))
		local record = BloodStain.place(
			kind(if isBrow then "browCut" else "cheekCut", "skinSmear"),
			cf * spot,
			cf:VectorToWorldSpace(Vector3.new(sign * 0.35, 0.1, -0.93).Unit),
			along,
			0.07,
			if isBrow then 0.16 else 0.14,
			{
				onto = head,
				random = random,
				profile = CUT_PROFILE,
				start = PALETTE.ARTERIAL,
				owner = state.model,
				pinned = true,
				life = math.huge,
				priority = 3,
			}
		)
		if record then
			wound.cut = record
			BloodRivulet.addMark(state.model, record, true, true)
		end
	else
		BloodAge.touch(wound.cut :: BloodAge.Record) -- (open again: wet)
	end
	wound.opened = now
	local eyeRandom = Random.new(random:NextInteger(1, 2 ^ 30))
	local guides: { BloodRivulet.Guide } = if isBrow
		then {
			{ point = side(EYE, sign), hold = 0.6 }, -- (over the eyelid)
			{ point = side(CHEEK_RUN, sign) },
			{ point = side(JAW, sign) },
		}
		else { { point = side(JAW, sign) } }
	startRun(state, wound, {
		from = spot + Vector3.new(0, -0.04, 0),
		guides = guides,
		width = if isBrow then 0.05 else 0.045,
		volume = if isBrow then 0.8 else 0.5,
		start = PALETTE.ARTERIAL,
		source = `{state.model:GetFullName()}|{name}`,
		onGuide = if isBrow
			then function(_run: BloodRivulet.Rivulet, index: number)
				if index ~= 1 then
					return
				end
				-- blood in the eye: a thin film over the lid
				local h = headOf(state.model)
				if h == nil then
					return
				end
				local record = BloodStain.place(
					"skinSmear",
					h.CFrame * side(EYE, sign),
					-h.CFrame.LookVector,
					h.CFrame.RightVector,
					0.08,
					0.12,
					{
						onto = h,
						random = eyeRandom,
						profile = "smear",
						start = PALETTE.ARTERIAL_LIGHT,
						alpha = 0.2,
						owner = state.model,
					}
				)
				if record then
					BloodRivulet.addMark(state.model, record, false, true)
				end
			end
			else nil,
	}, random)
end

------------------------------------------------------------------------------
-- A head hit that drew blood
------------------------------------------------------------------------------

export type HitInfo = {
	strong: boolean?, -- a heavy blow (a finisher, a kit's heavy move)
	moveId: string?,
	side: string?, -- "Front" / "Back" / "Left" / "Right" (seen from the victim)
}

local UPPISH: { [string]: boolean } = {
	Uppercut = true,
	UppercutPlus = true,
	Headbutt = true,
	DoubleHeadbutt = true,
}
local GLASS: { [string]: boolean } = { BottleSmash = true, BrokenBottle = true }

-- Rolls on the hit's seeded `random`: the same wounds on every screen.
function BloodFace.hit(model: Model, attacker: Model?, info: HitInfo?, random: Random)
	if not Config.Blood.ENABLED or headOf(model) == nil then
		return
	end
	local hitInfo: HitInfo = info or {}
	local state = stateOf(model)
	local now = os.clock()
	state.bloodyHits += 1
	state.lastHit = now
	local heavy = hitInfo.strong == true
	local moveId = hitInfo.moveId
	local hitSide = hitInfo.side or "Front"
	local uppish = moveId ~= nil and UPPISH[moveId] == true
	local glass = moveId ~= nil and GLASS[moveId] == true
	local bruise = headBruise(model)
	local softened = bruise >= 2
	-- the FIRST bloody punch on an intact face (no bruise, no glass, not a
	-- heavy blow): little blood - a light nose trickle at most
	local fresh = state.bloodyHits == 1 and not heavy and not glass and bruise == 0
	local hitSign = if hitSide == "Right" then 1 elseif hitSide == "Left" then -1 else 0
	-- cuts already open: a new blow reopens them (always on that side)
	for _, wound in state.wounds do
		if wound.cut ~= nil then
			local chance = if wound.sign == hitSign then 1 else 0.6
			if random:NextNumber() < chance then
				local where = string.sub(wound.name, 1, #wound.name - 1)
				cut(state, where, wound.sign, random)
			end
		end
	end
	-- the nose or the mouth
	local roll = random:NextNumber()
	if fresh then
		if hitSide == "Front" and roll < 0.4 then
			nose(state, random, false, true)
		end
	elseif hitSide == "Front" then
		if roll < (if uppish then 0.8 else 0.55) then
			local broken = heavy and isActive(state.wounds.nose, now) and random:NextNumber() < 0.25
			nose(state, random, broken)
		elseif roll < (if uppish then 0.9 else 0.8) then
			mouth(state, random)
		end
	elseif hitSide == "Left" or hitSide == "Right" then
		if roll < 0.45 then
			mouth(state, random)
		elseif roll < 0.7 then
			nose(state, random, false)
		end
		if softened and random:NextNumber() < 0.12 then
			cut(state, "cheek", hitSign, random)
		end
	end
	-- a cut on the brow: heavy blows, uppercuts, headbutts, glass; a normal
	-- punch only late in a fight (a bruised, swollen face)
	local browChance = if heavy
			or uppish
			or glass
		then (if softened then 0.35 else 0.1)
		else (if softened then 0.05 else 0)
	if random:NextNumber() < browChance then
		local sign = if hitSign ~= 0 then hitSign elseif random:NextNumber() < 0.5 then -1 else 1
		local name = "brow" .. (if sign > 0 then "R" else "L")
		if state.wounds[name] == nil then
			cut(state, "brow", sign, random)
		end
	end
	-- a heavy blow on a bleeding mouth: a spit of blood toward the blow's way
	if heavy and attacker and isActive(state.wounds.mouth, now) then
		BloodFace.spit(model, random, attacker)
	end
end

------------------------------------------------------------------------------
-- Spit, blow-out, wipe
------------------------------------------------------------------------------

-- A small puff of frothy blood (saliva, nose) at `at` going `direction`.
local function puff(at: Vector3, direction: Vector3, count: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldCFrame = CFrame.lookAt(at, at + direction)
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	local id = BloodStain.image("froth4x4", nil, 1)
	if id ~= 0 then
		emitter.Texture = "rbxassetid://" .. id
		emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		emitter.FlipbookMode = Enum.ParticleFlipbookMode.Random
	elseif not Blood.droplets(emitter, "mist") then
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	end
	emitter.Color = ColorSequence.new(SALIVA)
	emitter.LightInfluence = 0.8
	emitter.Size = NumberSequence.new(0.08, 0.15)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Lifetime = NumberRange.new(0.25, 0.35)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Drag = 6
	emitter.Acceleration = Vector3.new(0, -4, 0)
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(attachment, 1)
end

-- Spits blood: a stringy strand, a gob and a few droplets, a frothy puff.
function BloodFace.spit(model: Model, random: Random?, attacker: Model?)
	local head = headOf(model)
	if head == nil or not Config.Blood.ENABLED then
		return
	end
	local rand = random or Random.new()
	local cf = head.CFrame
	local forward = cf.LookVector
	if attacker then
		-- (a blow turns the head: away from the attacker)
		local toward = head.Position - attacker:GetPivot().Position
		local flat = Vector3.new(toward.X, 0, toward.Z)
		if flat.Magnitude > 1e-3 then
			forward = flat.Unit
		end
	end
	local mouthAt = cf * Vector3.new(0, -0.27, -0.64)
	local out = (forward - UP * 0.35).Unit
	Blood.strand(mouthAt, out * rand:NextNumber(3, 6), 0.04, model, rand)
	Blood.ballistic(
		mouthAt,
		out * rand:NextNumber(4, 7),
		rand:NextNumber(0.05, 0.07),
		{ ignore = { model :: Instance }, random = rand }
	)
	local sideways = forward:Cross(UP)
	for _ = 1, rand:NextInteger(3, 6) do
		Blood.ballistic(
			mouthAt,
			(out + sideways * rand:NextNumber(-0.4, 0.4) + UP * rand:NextNumber(0, 0.3)).Unit
				* rand:NextNumber(4, 9),
			rand:NextNumber(0.015, 0.03),
			{ ignore = { model :: Instance }, random = rand }
		)
	end
	puff(mouthAt, out, rand:NextInteger(3, 4))
end

-- Blows blood out of the nose: droplets forward-down, the nose re-wells.
local function blowOut(state: State, random: Random)
	local head = headOf(state.model)
	local wound = state.wounds.nose
	if head == nil or wound == nil then
		return
	end
	local cf = head.CFrame
	local at = cf * Vector3.new(0, -0.13, -0.66)
	local out = (cf.LookVector - UP * 0.6).Unit
	for _ = 1, random:NextInteger(6, 12) do
		local spread = cf.RightVector * random:NextNumber(-0.3, 0.3)
		Blood.ballistic(
			at,
			(out + spread).Unit * random:NextNumber(4, 7),
			random:NextNumber(0.015, 0.035),
			{ ignore = { state.model :: Instance }, random = random }
		)
	end
	puff(at, out, 3)
	for _, run in wound.runs do
		BloodRivulet.shorten(run, 0.4)
	end
	task.delay(1, function()
		feedRuns(wound, 0.15)
	end)
end

-- Wipes the face with the back of the hand: a smear across the lip (or the
-- brow cut), the runs under it wiped short; the blood wells up again.
local function wipe(state: State, random: Random)
	local head = headOf(state.model)
	if head == nil then
		return
	end
	local now = os.clock()
	local sign = if random:NextNumber() < 0.5 then -1 else 1 -- (the wiping arm)
	local browName = if random:NextNumber() < 0.5 then "browL" else "browR"
	local brow = state.wounds[browName]
	local onBrow = isActive(brow, now) and random:NextNumber() < 0.5
	local centre = if onBrow and brow
		then side(BROW + Vector3.new(0, -0.03, 0), brow.sign)
		else Vector3.new(0, -0.17, -0.6)
	local cf = head.CFrame
	-- across the face, tilted down toward the wiping arm
	local tilt = math.rad(random:NextNumber(10, 30))
	local across = Vector3.new(sign * math.cos(tilt), -math.sin(tilt), 0)
	for piece = -1, 1, 2 do
		local record = BloodStain.place(
			kind("wipeSmear", "skinSmear"),
			cf * (centre + across * (piece * 0.1)),
			-cf.LookVector,
			cf:VectorToWorldSpace(across),
			0.1,
			0.22,
			{
				onto = head,
				random = random,
				profile = "smear",
				start = PALETTE.ARTERIAL_LIGHT,
				alpha = 0.3,
				owner = state.model,
			}
		)
		if record then
			BloodRivulet.addMark(state.model, record, false, true)
		end
	end
	-- the runs under it: wiped short, then the wound wells up again
	for _, wound in state.wounds do
		if isActive(wound, now) then
			for _, run in wound.runs do
				BloodRivulet.shorten(run, 0.3)
			end
			task.delay(random:NextNumber(1, 3), function()
				feedRuns(wound, 0.15)
			end)
		end
	end
	local arm = state.model:FindFirstChild(if sign > 0 then "Right Arm" else "Left Arm")
	local hook = handHook
	if hook and arm and arm:IsA("BasePart") then
		hook(state.model, arm, 0.25) -- (the back of the hand: bloody)
	end
end

-- The fighter did something (a swing, a move): he isn't standing idle.
function BloodFace.noteAction(model: Model)
	local state = states[model]
	if state then
		state.lastAction = os.clock()
	end
end

------------------------------------------------------------------------------
-- Knocked out: the pool under the head (the "halo"); getting up
------------------------------------------------------------------------------

local function headLow(model: Model, head: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, BloodStain.folder }
	local hit = workspace:Raycast(head.Position, Vector3.new(0, -3, 0), params)
	return hit ~= nil and head.Position.Y - hit.Position.Y < 1.2
end

-- A pool grows under the bleeding head of a fighter lying there.
function BloodFace.halo(model: Model)
	local state = states[model]
	local head = headOf(model)
	if state == nil or head == nil then
		return
	end
	local down = model:GetAttribute("KnockedOut") == true or model:GetAttribute("Ragdolled") == true
	local now = os.clock()
	if not down or now - state.haloAt < 8 then
		return
	end
	state.haloAt = now
	local random = Random.new(Blood.seed(model.Name, "Halo", state.getUps))
	task.delay(1, function()
		if head.Parent and headLow(model, head) then
			BloodPool.feed(state.haloKey, head.Position, 0.25, random:NextNumber(10, 20), 1.2)
		end
	end)
end

local function anyActive(state: State, now: number): boolean
	for _, wound in state.wounds do
		if isActive(wound, now) then
			return true
		end
	end
	return false
end

local function onDown(model: Model)
	local state = states[model]
	local now = os.clock()
	local headBleeds = model:GetAttribute("Bleeding") == true
		and model:GetAttribute("BleedPart") == "Head"
	if state == nil and not headBleeds then
		return
	end
	local mine = stateOf(model)
	if not anyActive(mine, now) and not headBleeds then
		return
	end
	-- the runs still wet move again (now sideways / toward the back)
	for _, wound in mine.wounds do
		if isActive(wound, now) then
			feedRuns(wound, 0.15)
		end
	end
	BloodFace.halo(model)
end

local watchedModels: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function BloodFace.watch(model: Model)
	if watchedModels[model] then
		return
	end
	watchedModels[model] = true
	for _, name in { "KnockedOut", "Ragdolled" } do
		model:GetAttributeChangedSignal(name):Connect(function()
			if model:GetAttribute(name) == true and Config.Blood.ENABLED then
				onDown(model)
			end
		end)
	end
end

local HARD_GROUND: { [Enum.Material]: boolean } = {
	[Enum.Material.Concrete] = true,
	[Enum.Material.Asphalt] = true,
	[Enum.Material.Pavement] = true,
	[Enum.Material.Cobblestone] = true,
	[Enum.Material.Brick] = true,
	[Enum.Material.Slate] = true,
}

-- A graze (road rash) on the cheek after lying on a hard floor.
local function graze(state: State, random: Random)
	local head = headOf(state.model)
	if head == nil or state.grazes >= 2 or not CUTS then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { state.model, BloodStain.folder }
	local hit = workspace:Raycast(head.Position, Vector3.new(0, -8, 0), params)
	if hit == nil or not HARD_GROUND[hit.Material] then
		return
	end
	state.grazes += 1
	local sign = if random:NextNumber() < 0.5 then -1 else 1
	local cf = head.CFrame
	local record = BloodStain.place(
		kind("abrasion", "skinSmear"),
		cf * side(CHEEKBONE + Vector3.new(0.02, -0.06, 0.04), sign),
		cf:VectorToWorldSpace(Vector3.new(sign * 0.6, 0, -0.8).Unit),
		cf:VectorToWorldSpace(Vector3.new(sign * 0.3, -1, 0).Unit),
		0.16,
		0.2,
		{
			onto = head,
			random = random,
			profile = CRUST_PROFILE,
			start = RAW,
			dryColor = PALETTE.DRYING,
			alpha = 0.2,
			owner = state.model,
			life = math.huge,
			priority = 3,
		}
	)
	if record then
		BloodRivulet.addMark(state.model, record, true, true)
	end
end

-- Back on his feet: often wipes his face; sometimes a graze from the floor.
function BloodFace.onGetUp(model: Model)
	if not Config.Blood.ENABLED then
		return
	end
	local state = stateOf(model)
	state.getUps += 1
	state.lastAction = os.clock()
	local random = Random.new(Blood.seed(model.Name, "GetUp", state.getUps))
	if anyActive(state, os.clock()) and random:NextNumber() < 0.6 then
		task.delay(random:NextNumber(0.6, 1.2), function()
			if model.Parent then
				wipe(state, random)
			end
		end)
	end
	if random:NextNumber() < 0.3 then
		graze(state, random)
	end
end

------------------------------------------------------------------------------
-- Idle: spit, blow the nose, wipe (4 checks a second)
------------------------------------------------------------------------------

local idleRandom = Random.new()
local accumulated = 0
RunService.Heartbeat:Connect(function(dt: number)
	accumulated += dt
	if accumulated < 0.25 then
		return
	end
	accumulated = 0
	local now = os.clock()
	for model, state in states do
		if model.Parent == nil or now < state.nextIdle then
			continue
		end
		if now - state.lastAction < 2.5 or now - state.lastHit < 2.5 then
			continue
		end
		if model:GetAttribute("KnockedOut") == true or model:GetAttribute("Ragdolled") == true then
			continue
		end
		local noseOn = isActive(state.wounds.nose, now)
		local mouthOn = isActive(state.wounds.mouth, now)
		if not anyActive(state, now) then
			continue
		end
		state.nextIdle = now + idleRandom:NextNumber(6, 15)
		if idleRandom:NextNumber() >= 0.4 then
			continue
		end
		local choice = idleRandom:NextNumber()
		if mouthOn and choice < 0.4 then
			BloodFace.spit(model, idleRandom, nil)
		elseif noseOn and choice < 0.7 then
			blowOut(state, idleRandom)
		else
			wipe(state, idleRandom)
		end
	end
end)

return table.freeze(BloodFace)
