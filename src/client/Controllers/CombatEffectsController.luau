--!strict
-- CombatEffectsController: everything you SEE and HEAR during a fight (no
-- gameplay: the server decides, see Server/Systems/Combat).
--
-- Kept quiet on purpose (no coloured outlines, no big floating texts):
--   • Hit: a quick pale flick on the character. Stunned: it darkens a little.
--     Blocking: nothing (the guard pose says it).
--   • Words beside the shoulder, small spaced caps with a hairline:
--     PARRY, GUARD BREAK, DODGE, PROTECTED — shown only to the two fighters
--     concerned. GUARD BREAK is red when it's YOUR guard.
--   • You get hit: the colours drain for an instant; a head hit blurs.
--   • Small camera shake when you hit or get hit.
--   • Reaction animations + hit-stop + flinch on every fighter, and the
--     sounds; other fighters' punches / dashes (Remotes.CombatAction).
--     The reaction depends on WHERE the hit lands (head or body) and from
--     WHICH SIDE of the victim it comes (front, back, left, right — sent by
--     the server, so every screen shows the same thing). Face hits from the
--     front also depend on the punch (jab, cross, hook). The hit-stop holds
--     the contact frame; the flinch goes the way the fist pushed.
--   • Our OWN punches: the reaction is predicted the instant our fist lands
--     (predictHit, HIT_DELAY after CombatController's attack signal),
--     instead of one network trip later when the fist is already coming
--     back (that looked like the punch went through the body). Each M1 has
--     a number echoed by the server: if the server's result differs
--     (dodged, blocked, another zone...), its version replaces ours.
--     Damage, sound and flash always wait for the server.
--
-- Data: the Config.Combat.TAG tag + "Stunned" attribute on each fighter,
-- Remotes.CombatEvent and Remotes.CombatAction.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local AimRule = require(ReplicatedStorage.Shared.Util.AimRule)
local HitSide = require(ReplicatedStorage.Shared.Util.HitSide)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local CombatController = require(script.Parent.CombatController)
local SoundController = require(script.Parent.SoundController)
local Kits = require(ReplicatedStorage.Shared.Kits)
local HitPrediction = require(script.Parent.Parent.Combat.HitPrediction)
local BouncerFx = require(script.Parent.Parent.Combat.BouncerFx)
local KitEffects = require(script.Parent.Parent.Combat.KitEffects)
local BloodTracks = require(script.Parent.Parent.Combat.BloodTracks)
local WeaponFx = require(script.Parent.Parent.Combat.WeaponFx)
local Wounds = require(script.Parent.Parent.Combat.Wounds)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local C = Theme.Colors
-- Pale flick on a character that gets hit (Highlight fill).
local HIT_FLICK_TRANSPARENCY = 0.82
local HIT_FLICK_TIME = 0.12
-- Stunned: the character darkens slightly.
local STUN_TRANSPARENCY = 0.8

-- FACE hit from the FRONT: the reaction follows the punch thrown.
-- (A jab snaps the head back, a cross throws it to one side, a hook to the other.)
local REACTION_BY_PUNCH: { [string]: string } = {
	Brawler_M1_1 = "HitJab",
	Brawler_M1_2 = "HitCross",
	Brawler_M1_3 = "HitHook",
	Brawler_M1_4 = "HitHeavy",
}
-- FACE hit from another side: the head is thrown AWAY from the fist.
-- (Fist on the victim's left cheek → head thrown to its right = HitCross;
-- on its right cheek → thrown to its left = HitHook.)
local HEAD_REACTION_BY_SIDE: { [string]: string } = {
	Back = "HitBack",
	Left = "HitCross",
	Right = "HitHook",
}
-- BODY hit: one reaction per side (the torso folds around the fist).
local BODY_REACTION_BY_SIDE: { [string]: string } = {
	Front = "HitBodyFront",
	Back = "HitBodyBack",
	Left = "HitBodyLeft",
	Right = "HitBodyRight",
}
-- Flinch direction (in the head's axes: X > 0 head BACK, Y > 0 turns it to
-- its left, Z > 0 tilts it to its left), multiplied by the kick strength.
-- The head always goes the way the fist pushes it.
local HEAD_FLINCH: { [string]: Vector3 } = {
	Front = Vector3.new(1, 0, 0),
	Back = Vector3.new(-1, 0, 0),
	Left = Vector3.new(0.2, -1, -0.5), -- fist from its left → head to its right
	Right = Vector3.new(0.2, 1, 0.5),
}
local BODY_FLINCH: { [string]: Vector3 } = {
	Front = Vector3.new(-0.7, 0, 0), -- folds forward
	Back = Vector3.new(0.6, 0, 0), -- back arches, head thrown back
	Left = Vector3.new(-0.3, -0.3, 0.6), -- crunches over the left ribs
	Right = Vector3.new(-0.3, 0.3, -0.6),
}
-- Our own predicted hits: how long we wait for the server's answer before
-- forgetting the prediction (seconds, plus the round trip).
local PREDICTION_MEMORY = 0.4
-- After a fighter starts a dash, no prediction for its dodge frames plus
-- this margin (the dash reaches us a bit late).
local DASH_MARGIN = 0.15
-- If OUR character has one of these, the server cancels our punch.
local ATTACKER_CANCEL_ATTRIBUTES = table.freeze({ "Stunned", "KnockedOut", "Ragdolled" })
-- Attributes that mean "this punch won't simply hit": no prediction then,
-- we let the server decide (block, parry, KO, spawn protection).
local NO_PREDICTION_ATTRIBUTES =
	table.freeze({ "Blocking", "KnockedOut", "Ragdolled", "Protected" })
-- Hit-stop: both fighters freeze this long when a punch lands (seconds).
local HIT_STOP = 0.055
local HEAVY_HIT_STOP = 0.11
local BLOCK_HIT_STOP = 0.035
local PARRY_HIT_STOP = 0.09
-- Flinch: how hard a hit kicks the head's spring (degrees per second; see
-- CharacterAnimationController.flinch). Sideways part = the hook / the cross.
local FLINCH_KICK = 130
local HEAVY_FLINCH_KICK = 230
local BLOCK_FLINCH_KICK = 45

type Visual = {
	model: Model,
	highlight: Highlight,
	flickUntil: number,
	word: BillboardGui?, -- the word currently shown beside this fighter
}

local CombatEffectsController = {}

local visuals: { [Model]: Visual } = {}

type Prediction = {
	time: number,
	strong: boolean,
	zone: Types.HitZone,
	side: Types.HitSide,
}
-- What we showed for our own M1s: per victim, per M1 number (the server
-- echoes that number with the result, see CombatController.AttackInfo).
local predictions: { [Model]: { [number]: Prediction } } = {}
-- When each fighter last started a dash: it may be in its dodge frames,
-- which only the server knows, so we don't predict hits on it.
local dashedAt: { [Model]: number } = {}
-- Hurt groans: at most one every GRUNT_INTERVAL seconds per fighter (a
-- combo would otherwise stack them).
local GRUNT_INTERVAL = 0.6
local nextGruntAt: { [Model]: number } = {}
local random = Random.new()
local shakeUntil = 0
local shakeStrength = 0

------------------------------------------------------------------------------
-- Outline (blocking / stunned) and flashes
------------------------------------------------------------------------------

-- The lasting state of a fighter: slightly darker while stunned.
local function refreshState(visual: Visual)
	if os.clock() < visual.flickUntil then
		return
	end
	local stunned = visual.model:GetAttribute("Stunned") == true
	local highlight = visual.highlight
	highlight.FillColor = C.Scrim
	Theme.tween(highlight, if stunned then 0.1 else 0.2, {
		FillTransparency = if stunned then STUN_TRANSPARENCY else 1,
	})
end

-- A quick pale flick when a hit lands (not a red flash).
local function flick(model: Model)
	local visual = visuals[model]
	if visual == nil then
		return
	end
	local highlight = visual.highlight
	visual.flickUntil = os.clock() + HIT_FLICK_TIME
	highlight.FillColor = C.Ink
	highlight.FillTransparency = HIT_FLICK_TRANSPARENCY
	Theme.tween(highlight, HIT_FLICK_TIME, { FillTransparency = 1 })
	task.delay(HIT_FLICK_TIME + 0.01, function()
		if visuals[model] == visual then
			refreshState(visual)
		end
	end)
end

local function onCombatantAdded(instance: Instance)
	if not instance:IsA("Model") or visuals[instance] then
		return
	end
	local model = instance
	local highlight = Theme.make("Highlight", {
		Name = "CombatHighlight",
		DepthMode = Enum.HighlightDepthMode.Occluded, -- not visible through walls
		FillColor = C.Scrim,
		FillTransparency = 1,
		OutlineTransparency = 1, -- never an outline
		Parent = model,
	}) :: Highlight

	local visual: Visual = { model = model, highlight = highlight, flickUntil = 0, word = nil }
	visuals[model] = visual
	KitEffects.watch(model) -- bleeding drips, Street Fury
	WeaponFx.watch(model) -- a bone (to throw) in the hand
	Wounds.watch(model) -- bruises and cuts where they were hit
	model:GetAttributeChangedSignal("Stunned"):Connect(function()
		refreshState(visual)
	end)
	refreshState(visual)
	-- A grab's hold (Server/Combat/Grab): "Held" / "Holding" = the hold clip
	-- playing. When it ends (maybe cut short), the clip stops and our own
	-- attacks are free again.
	for _, name in { "Held", "Holding" } do
		local playing = model:GetAttribute(name)
		model:GetAttributeChangedSignal(name):Connect(function()
			local value = model:GetAttribute(name)
			if typeof(playing) == "string" and value == nil then
				CharacterAnimationController.stopAction(model, playing)
				if name == "Held" then
					BouncerFx.onReleased(model) -- (a choked face gets its colour back)
				end
				if model == player.Character then
					CombatController.releaseAttacks()
				end
			end
			playing = value
		end)
	end
end

local function onCombatantRemoved(instance: Instance)
	if instance:IsA("Model") then
		visuals[instance] = nil
		predictions[instance] = nil
		dashedAt[instance] = nil
		nextGruntAt[instance] = nil
	end
end

------------------------------------------------------------------------------
-- Floating text and camera shake
------------------------------------------------------------------------------

-- A word beside the fighter's shoulder: spaced caps + a hairline that draws
-- in, held a moment, then gone (0.8 s). Replaces any word already there.
local function word(model: Model, text: string, color: Color3)
	local visual = visuals[model]
	local root = model:FindFirstChild("HumanoidRootPart")
	if visual == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	if visual.word then
		visual.word:Destroy()
	end
	local billboard = Theme.make("BillboardGui", {
		Name = "CombatWord",
		Size = UDim2.fromOffset(140, 28),
		StudsOffset = Vector3.new(2.2, 1.2, 0), -- beside the right shoulder, never on the face
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 60,
		ResetOnSpawn = false,
		Adornee = root,
		Parent = player:FindFirstChildOfClass("PlayerGui"),
	}) :: BillboardGui
	visual.word = billboard
	local label = Theme.text({
		Name = "Word",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 13,
		TextColor3 = color,
		TextTransparency = 1,
		Text = Theme.track(text, "three"),
		Parent = billboard,
	}) :: TextLabel
	local rule = Theme.make("Frame", {
		Name = "Rule",
		Position = UDim2.fromOffset(0, 19),
		Size = UDim2.fromOffset(0, 1),
		BackgroundColor3 = color,
		Parent = billboard,
	}) :: Frame

	Theme.tween(label, 0.08, { TextTransparency = 0 }, Enum.EasingStyle.Linear)
	Theme.tween(label, 0.12, { Position = UDim2.fromOffset(0, 0) })
	task.defer(function()
		local width = math.max(label.TextBounds.X * 0.75, 24)
		Theme.tween(rule, 0.16, { Size = UDim2.fromOffset(width, 1) }, Enum.EasingStyle.Quart)
	end)
	task.delay(0.53, function()
		if billboard.Parent == nil then
			return
		end
		Theme.tween(
			label,
			0.25,
			{ TextTransparency = 1, Position = UDim2.fromOffset(0, -3) },
			Enum.EasingStyle.Linear
		)
		Theme.tween(rule, 0.25, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
		task.delay(0.26, function()
			if visual.word == billboard then
				visual.word = nil
			end
			billboard:Destroy()
		end)
	end)
end

-- You got hit: the colours drain for an instant.
local hitGrade: ColorCorrectionEffect? = nil
local function drainColour()
	local grade = hitGrade
	if grade == nil then
		local created = Instance.new("ColorCorrectionEffect")
		created.Name = "HitGrade"
		created.Parent = game:GetService("Lighting")
		grade = created
		hitGrade = created
	end
	local effect = grade :: ColorCorrectionEffect
	effect.Saturation = -0.25
	Theme.tween(effect, 0.18, { Saturation = 0 })
end

local function shake(strength: number, duration: number)
	shakeStrength = math.max(if os.clock() < shakeUntil then shakeStrength else 0, strength)
	shakeUntil = os.clock() + duration
end

-- Runs right after the camera scripts: moves the camera a tiny bit sideways
-- / up-down. (Only the POSITION: Roblox's camera reads back its rotation
-- every frame, so a shaking rotation would slowly shift where you aim.)
local function updateShake()
	if os.clock() >= shakeUntil then
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		local s = shakeStrength * 0.1 -- strength 1 = up to 0.1 stud
		local offset = Vector3.new(random:NextNumber(-s, s), random:NextNumber(-s, s), 0)
		camera.CFrame += camera.CFrame:VectorToWorldSpace(offset)
	end
end

------------------------------------------------------------------------------
-- Combat events from the server
------------------------------------------------------------------------------

-- Head hit on us: the vision blurs for an instant.
local HEAD_BLUR_SIZE = 12
local HEAD_BLUR_TIME = 0.45

local function headBlur()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local blur = Instance.new("BlurEffect")
	blur.Name = "HeadHitBlur"
	blur.Size = HEAD_BLUR_SIZE
	blur.Parent = camera
	local fade = TweenService:Create(
		blur,
		TweenInfo.new(HEAD_BLUR_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = 0 }
	)
	fade.Completed:Connect(function()
		blur:Destroy()
	end)
	fade:Play()
end

-- The reaction clip for a hit (see the tables at the top).
local function chooseReaction(
	strong: boolean,
	zone: Types.HitZone,
	side: Types.HitSide,
	attacker: Model
): string
	if strong then
		return if side == "Back" then "HitBack" else "HitHeavy"
	end
	if zone == "Legs" then
		return "HitLeg" -- kicked in the shin: the leg buckles
	end
	if zone == "Head" then
		if side == "Front" then
			local punch = CharacterAnimationController.getLastAction(attacker)
			return (if punch then REACTION_BY_PUNCH[punch] else nil) or "HitJab"
		end
		return HEAD_REACTION_BY_SIDE[side]
	end
	return BODY_REACTION_BY_SIDE[side]
end

-- Flinch for a hit: the direction the fist pushes, plus for a face hit from
-- the front the sideways whip of a cross / hook.
local function flinchKick(
	strong: boolean,
	zone: Types.HitZone,
	side: Types.HitSide,
	attacker: Model
): Vector3
	local kick = if strong then HEAVY_FLINCH_KICK else FLINCH_KICK
	if zone ~= "Head" then
		return BODY_FLINCH[side] * kick
	end
	local direction = HEAD_FLINCH[side]
	if side == "Front" then
		local punch = CharacterAnimationController.getLastAction(attacker)
		if punch == "Brawler_M1_2" then
			direction = Vector3.new(1, -0.6, -0.3) -- right cross → head to the victim's right
		elseif punch == "Brawler_M1_3" then
			direction = Vector3.new(1, 0.6, 0.3) -- left hook → head to its left
		end
	end
	return direction * kick
end

-- Animation side of a landed hit (no sound / flash): reaction clip, flinch,
-- and the hit-stop that holds the contact frame on both fighters.
local function playHitReaction(
	victim: Model,
	attacker: Model,
	strong: boolean,
	zone: Types.HitZone,
	side: Types.HitSide,
	moveId: string?
)
	-- Some kit moves have their own reaction (a liver shot folds the body).
	-- A grab's catch / a held fighter: its hold clip stays (no reaction).
	local special = if moveId then KitEffects.reactionFor(moveId) else nil
	if not KitEffects.keepsPose(moveId, victim) then
		CharacterAnimationController.playAction(
			victim,
			special or chooseReaction(strong, zone, side, attacker)
		)
	end
	CharacterAnimationController.flinch(victim, flinchKick(strong, zone, side, attacker))
	local stop = if strong then HEAVY_HIT_STOP else HIT_STOP
	CharacterAnimationController.hitStop(victim, stop)
	CharacterAnimationController.hitStop(attacker, stop)
end

-- Side sent by the server, or (old server / missing) worked out here.
local function resolveSide(side: unknown, victim: Model, attacker: Model): Types.HitSide
	if HitSide.isValid(side) then
		return side :: Types.HitSide
	end
	return HitSide.compute(victim:GetPivot(), attacker:GetPivot().Position) :: Types.HitSide
end

local function resolveZone(zone: unknown): Types.HitZone
	local result: Types.HitZone = "Torso"
	if zone == "Head" then
		result = "Head"
	elseif zone == "Legs" then
		result = "Legs"
	end
	return result
end

------------------------------------------------------------------------------
-- Prediction of our own hits
------------------------------------------------------------------------------

-- How long a prediction waits for the server's answer: a margin plus the
-- round trip (with a high ping the answer comes later).
local function predictionMemory(): number
	return PREDICTION_MEMORY + player:GetNetworkPing() * 2
end

-- Takes (and forgets) what we predicted for this victim and this M1.
local function takePrediction(victim: Model, attackId: unknown): Prediction?
	local byId = predictions[victim]
	if byId == nil or typeof(attackId) ~= "number" then
		return nil
	end
	local prediction = byId[attackId]
	byId[attackId] = nil
	if next(byId) == nil then
		predictions[victim] = nil
	end
	if prediction and os.clock() - prediction.time < predictionMemory() then
		return prediction
	end
	return nil
end

-- Drops predictions the server never answered (our punch missed on the
-- server, or was cancelled).
local function forgetOldPredictions()
	local limit = os.clock() - predictionMemory()
	for victim, byId in predictions do
		for id, prediction in byId do
			if prediction.time < limit then
				byId[id] = nil
			end
		end
		if next(byId) == nil then
			predictions[victim] = nil
		end
	end
end

local function canPredictHitOn(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	for _, attribute in NO_PREDICTION_ATTRIBUTES do
		if model:GetAttribute(attribute) == true then
			return false
		end
	end
	local dashed = dashedAt[model]
	return dashed == nil or os.clock() - dashed > Config.Combat.DASH_INVULNERABLE + DASH_MARGIN
end

-- Runs Config.Combat.HIT_DELAY after we click, i.e. the moment our fist
-- reaches its target in the punch animation. Same box and same aim rule
-- as the server. Purely visual: the server still decides the hit, the
-- damage and everything else, and corrects us if it disagrees.
local function predictHit(info: CombatController.AttackInfo)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		character == nil
		or humanoid == nil
		or humanoid.Health <= 0
		or root == nil
		or not root:IsA("BasePart")
	then
		return
	end
	-- The server cancels the punch of a stunned / knocked-out attacker.
	for _, attribute in ATTACKER_CANCEL_ATTRIBUTES do
		if character:GetAttribute(attribute) == true then
			return
		end
	end
	forgetOldPredictions()

	-- Same aim rule and same rest-pose bodies as the server (HitPrediction).
	local aim = AimRule.validate(info.aim, root.CFrame.LookVector)
	for model, parts in HitPrediction.findVictims(character, root) do
		if canPredictHitOn(model) then
			local aimed: Types.HitZone = HitPrediction.aimZone(root, model, aim)
			local zone: Types.HitZone = HitPrediction.landingZone(aimed, parts)
			local side: Types.HitSide = HitSide.compute(model:GetPivot(), root.Position)
			local byId = predictions[model]
			if byId == nil then
				byId = {}
				predictions[model] = byId
			end
			byId[info.id] = { time = os.clock(), strong = info.strong, zone = zone, side = side }
			playHitReaction(model, character, info.strong, zone, side)
			-- The thud with the reaction, right away (the server's message
			-- comes a round trip later: then it doesn't play it again).
			SoundController.play(if info.strong then "HeavyHit" else "Hit", model)
		end
	end
end

-- The server finished our M1 number `attackId` (all its CombatEvents came
-- first). A hit we predicted for it that no event confirmed didn't happen:
-- undo it.
local function onAttackResolved(attackId: unknown)
	if typeof(attackId) ~= "number" then
		return
	end
	local character = player.Character
	for victim, byId in predictions do
		if byId[attackId] then
			byId[attackId] = nil
			if next(byId) == nil then
				predictions[victim] = nil
			end
			CharacterAnimationController.cancelReaction(victim)
			if character then
				CharacterAnimationController.clearHitStop(character)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Server events
------------------------------------------------------------------------------

local function onCombatEvent(
	kind: Types.CombatEventKind,
	victim: Model,
	attacker: Model,
	zoneArg: unknown,
	sideArg: unknown,
	attackIdArg: unknown,
	moveIdArg: unknown,
	bloodArg: unknown,
	skinTearSeedArg: unknown
)
	if typeof(victim) ~= "Instance" or typeof(attacker) ~= "Instance" then
		return -- a model that doesn't exist on this client (streamed out...)
	end
	local character = player.Character
	local iAmVictim = victim == character
	local iAmAttacker = attacker == character
	-- What we showed for this M1 when our fist landed (our punches only).
	local prediction = if iAmAttacker then takePrediction(victim, attackIdArg) else nil
	if prediction and kind ~= "Hit" and kind ~= "Finisher" then
		-- We showed a hit, the server says it was dodged / blocked / parried:
		-- undo our reaction (the right effect plays just below).
		CharacterAnimationController.cancelReaction(victim)
		CharacterAnimationController.clearHitStop(attacker)
	end

	-- A kit move (Bottle Smash...) rather than an M1.
	local moveId: string? = if typeof(moveIdArg) == "string" then moveIdArg else nil

	if kind == "Hit" or kind == "Finisher" then
		flick(victim)
		local strong = kind == "Finisher" or (moveId ~= nil and KitEffects.isHeavy(moveId))
		local zone: Types.HitZone = resolveZone(zoneArg)
		local side: Types.HitSide = resolveSide(sideArg, victim, attacker)
		-- Already shown exactly like this by our prediction? Otherwise the
		-- server's version wins (it replaces a wrong guess).
		local alreadyShown = prediction ~= nil
			and prediction.strong == strong
			and prediction.zone == zone
			and prediction.side == side
		if not alreadyShown then
			playHitReaction(victim, attacker, strong, zone, side, moveId)
		end
		if iAmVictim and zone == "Head" then
			headBlur()
		end

		-- Hurt enough: the victim groans (read a moment later, once the
		-- server's new health has reached us).
		task.delay(0.05, function()
			local humanoid = victim:FindFirstChildOfClass("Humanoid")
			local time = os.clock()
			if
				humanoid
				and humanoid.Health > 0
				and humanoid.Health <= Config.Injuries.HURT_SOUND_HEALTH
				and time >= (nextGruntAt[victim] or 0)
			then
				nextGruntAt[victim] = time + GRUNT_INTERVAL
				SoundController.play("HurtGrunt", victim)
			end
		end)
		if moveId then
			KitEffects.onHit(victim, attacker, moveId, zone)
			BouncerFx.onHit(victim, attacker, moveId, shake)
			if iAmAttacker then
				CombatController.notifyMoveLanded(moveId)
			end
		elseif prediction == nil then
			-- (a hit we predicted already made its sound)
			SoundController.play(if strong then "HeavyHit" else "Hit", victim)
		end
		-- Blood and torn skin: decided by the server (same on every screen).
		if bloodArg == true then
			-- (more for the heavy blows and the kits' moves)
			local amount = if strong then 2.6 elseif moveId then 1.7 else 1
			KitEffects.bloodSpray(
				victim,
				attacker,
				zone,
				amount,
				KitEffects.bloodSeed(attackIdArg, victim, zone)
			)
		end
		if typeof(skinTearSeedArg) == "number" then
			KitEffects.skinTear(victim, attacker, skinTearSeedArg, zone)
		end
		if iAmVictim then
			drainColour()
			shake(if strong then 1.6 else 0.8, if strong then 0.25 else 0.15)
		elseif iAmAttacker then
			shake(if strong then 0.8 else 0.35, 0.1)
		end
	elseif kind == "Blocked" then
		flick(victim)
		CharacterAnimationController.playAction(victim, "BlockHit")
		CharacterAnimationController.flinch(victim, Vector3.new(BLOCK_FLINCH_KICK, 0, 0))
		CharacterAnimationController.hitStop(victim, BLOCK_HIT_STOP)
		CharacterAnimationController.hitStop(attacker, BLOCK_HIT_STOP)
		SoundController.play("Block", victim)
		if iAmVictim then
			shake(0.3, 0.1)
		end
	elseif kind == "Parried" then
		if iAmVictim or iAmAttacker then
			word(victim, "PARRY", C.Ink)
		end
		CharacterAnimationController.playAction(victim, "Parry")
		CharacterAnimationController.hitStop(victim, PARRY_HIT_STOP)
		CharacterAnimationController.hitStop(attacker, PARRY_HIT_STOP)
		SoundController.play("Parry", victim)
		if iAmVictim or iAmAttacker then
			shake(0.6, 0.15)
		end
	elseif kind == "GuardBreak" then
		flick(victim)
		if iAmVictim or iAmAttacker then
			word(victim, "GUARD BREAK", if iAmVictim then C.BloodHi else C.Ink)
		end
		CharacterAnimationController.playAction(victim, "GuardBreak")
		SoundController.play("GuardBreak", victim)
		if iAmVictim then
			shake(1.2, 0.2)
		end
	elseif kind == "Dodged" then
		if iAmVictim or iAmAttacker then
			word(victim, "DODGE", C.Ink)
		end
		SoundController.play("Dodge", victim)
	elseif kind == "Protected" then
		if iAmAttacker then
			word(victim, "PROTECTED", C.Ink2)
		end
	end
end

-- Server actions that are NOT predicted by our own client (we must play
-- them on our character too): getting up after a KO.
-- (Street Fury's activation is never predicted: only the server knows the gauge.)
-- (A slip's counter too: only the server knows a hit was slipped.)
local SERVER_ONLY_ACTIONS = table.freeze({
	GetUp = true,
	Boxer_FinisherVictim = true, -- held up by a Boxer's finisher (we're the victim)
	Brawler_FinisherBatVictim = true, -- laid out under a Street Brawler's bat
	-- Cinematic finishers: not predicted, played only when the server starts them.
	Brawler_FinisherBat = true,
	Boxer_FinisherCombo = true,
	Brawler_Awaken = true,
	Boxer_Awaken = true,
	Boxer_SlipCounter = true,
	-- Bouncer: laid out for the arm, and his own cinematic + activation.
	Bouncer_FinisherArmRip = true,
	Bouncer_FinisherArmRipVictim = true,
	Bouncer_Awaken = true,
	-- (a grab's hold clips too: only the server knows it caught someone,
	-- KitEffects.grabOf)
})

-- A fighter started a punch, a dash, a finisher, or got up after a KO.
-- (Our own punches / dashes / finishers already played locally.)
local function onCombatAction(model: Model, action: string)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or typeof(action) ~= "string" then
		return
	end
	local grab = KitEffects.grabOf(action)
	if model == player.Character and KitEffects.isAwakening(action) then
		-- Our Awakening starts: no attack during the activation (as on the server).
		CombatController.holdAttacks(Config.Kits.AWAKEN_TIME)
	elseif model == player.Character and action == "Boxer_SlipCounter" then
		CombatController.holdAttacks(0.55) -- our counter punch
	elseif model == player.Character and grab then
		CombatController.holdAttacks(grab.duration) -- holding someone / held
	end
	-- (Emotes are played by the server's answer, for us too.)
	-- A "Finisher" strike that isn't our KO finisher (Street Fury's
	-- tackle slam follow-up): never predicted, play it from here.
	local kitId = model:GetAttribute("Kit")
	local followUp = action == "Finisher"
		and Kits.finisher(if typeof(kitId) == "string" then kitId else nil).animation
			~= "Finisher"
	if
		model == player.Character
		and not SERVER_ONLY_ACTIONS[action]
		and grab == nil
		and not followUp
		and string.sub(action, 1, 6) ~= "Emote_"
	then
		-- Ours: already played when we clicked, unless the server disagreed.
		CombatController.onServerAction(action)
		return
	end
	if string.sub(action, 1, 4) == "Dash" then
		dashedAt[model] = os.clock()
	end
	CharacterAnimationController.playAction(model, action)
	BouncerFx.onAction(model, action)
	if action == "GetUp" then
		BloodTracks.onGetUp(model) -- (a bloody hand pushing on the ground)
	end
	if
		action == "GetUp"
		or string.sub(action, 1, 6) == "Emote_"
		or (SERVER_ONLY_ACTIONS[action] and string.find(action, "_Finisher"))
	then
		return -- (no swing sound; a cutscene's sounds come with it, CinematicController)
	elseif KitEffects.isMoveAnimation(action) then
		-- Prop in hand + its own sound. Our own Street Fury roar already
		-- played when we pressed G (KitController): don't play it twice.
		local alreadyHeard = model == player.Character and KitEffects.isAwakening(action)
		KitEffects.onAction(model, action, alreadyHeard)
	elseif action == "Finisher" or action == `Brawler_M1_{#Config.Combat.M1_DAMAGE}` then
		SoundController.play("HeavySwing", model) -- the heavy blows
		KitEffects.onSwing(model) -- (a bloody fist flicks blood off)
	elseif string.sub(action, 1, 4) == "Dash" then
		SoundController.play("Dash", model)
	else
		SoundController.play("Swing", model)
		KitEffects.onSwing(model)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

-- A finisher with a kill effect (Shop): debris there, and for the "Impact"
-- effect a shake + colour drain if we're close enough to feel it.
local function onKillEffect(effect: unknown, position: unknown)
	if typeof(effect) ~= "string" or typeof(position) ~= "Vector3" then
		return
	end
	KitEffects.killEffect(effect, position)
	if effect == "Impact" then
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - position).Magnitude < 60 then
			shake(1.4, 0.3)
			drainColour()
		end
	end
end

function CombatEffectsController.start()
	Remotes.KillEffect.OnClientEvent:Connect(onKillEffect)
	-- Something thrown (Shared/Weapons): flying, then broken where it hit.
	Remotes.WeaponThrown.OnClientEvent:Connect(
		function(
			thrower: unknown,
			id: unknown,
			throwId: unknown,
			origin: unknown,
			velocity: unknown
		)
			if
				typeof(thrower) == "Instance"
				and thrower:IsA("Model")
				and typeof(id) == "string"
				and typeof(throwId) == "number"
				and typeof(origin) == "Vector3"
				and typeof(velocity) == "Vector3"
			then
				WeaponFx.thrown(thrower, id, throwId, origin, velocity)
			end
		end
	)
	Remotes.WeaponBroke.OnClientEvent:Connect(
		function(id: unknown, throwId: unknown, position: unknown, velocity: unknown)
			if
				typeof(id) == "string"
				and typeof(position) == "Vector3"
				and typeof(velocity) == "Vector3"
			then
				WeaponFx.broke(
					id,
					if typeof(throwId) == "number" then throwId else nil,
					position,
					velocity
				)
			end
		end
	)
	local tag = Config.Combat.TAG
	CollectionService:GetInstanceAddedSignal(tag):Connect(onCombatantAdded)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(onCombatantRemoved)
	for _, instance in CollectionService:GetTagged(tag) do
		onCombatantAdded(instance)
	end

	Remotes.CombatEvent.OnClientEvent:Connect(onCombatEvent)
	Remotes.CombatAction.OnClientEvent:Connect(onCombatAction)
	Remotes.AttackResolved.OnClientEvent:Connect(onAttackResolved)
	-- Our M1: show the hit the instant the fist lands (HIT_DELAY later).
	CombatController.onAttackStarted(function(info)
		local character = player.Character
		if character then
			KitEffects.onSwing(character) -- (our bloody fist flicks blood off)
		end
		task.delay(Config.Combat.HIT_DELAY, function()
			predictHit(info)
		end)
	end)
	RunService:BindToRenderStep("CombatShake", Enum.RenderPriority.Camera.Value + 2, updateShake)
end

return CombatEffectsController
