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
--
-- Data: the Config.Combat.TAG tag + "Stunned" attribute on each fighter,
-- Remotes.CombatEvent and Remotes.CombatAction.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local CombatController = require(script.Parent.CombatController)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local C = Theme.Colors
-- Pale flick on a character that gets hit (Highlight fill).
local HIT_FLICK_TRANSPARENCY = 0.82
local HIT_FLICK_TIME = 0.12
-- Stunned: the character darkens slightly.
local STUN_TRANSPARENCY = 0.8

-- Which reaction the victim plays, from the punch the attacker threw.
-- (A jab snaps the head back, a cross throws it to one side, a hook to the other.)
local REACTION_BY_PUNCH: { [string]: string } = {
	Brawler_M1_1 = "HitJab",
	Brawler_M1_2 = "HitCross",
	Brawler_M1_3 = "HitHook",
	Brawler_M1_4 = "HitHeavy",
}
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
	model:GetAttributeChangedSignal("Stunned"):Connect(function()
		refreshState(visual)
	end)
	refreshState(visual)
end

local function onCombatantRemoved(instance: Instance)
	if instance:IsA("Model") then
		visuals[instance] = nil
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

-- Was `attacker` in front of `victim`? (picks the right hit animation)
local function isInFront(victim: Model, attacker: Model): boolean
	local offset = attacker:GetPivot().Position - victim:GetPivot().Position
	return offset:Dot(victim:GetPivot().LookVector) >= 0
end

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

local function onCombatEvent(
	kind: Types.CombatEventKind,
	victim: Model,
	attacker: Model,
	zone: Types.HitZone?
)
	if typeof(victim) ~= "Instance" or typeof(attacker) ~= "Instance" then
		return -- a model that doesn't exist on this client (streamed out...)
	end
	local character = player.Character
	local iAmVictim = victim == character
	local iAmAttacker = attacker == character

	if kind == "Hit" or kind == "Finisher" then
		flick(victim)
		local strong = kind == "Finisher"
		local fromFront = isInFront(victim, attacker)
		local punch = CharacterAnimationController.getLastAction(attacker)

		local toBody = zone == "Torso" or zone == "Legs"

		-- The reaction matches where it landed and the punch thrown:
		-- body shot → folds forward; to the face → head snapped the way the
		-- punch came from; from behind → thrown forward; finisher → heavy.
		local reaction = "HitBack"
		if fromFront then
			if strong then
				reaction = "HitHeavy"
			elseif toBody then
				reaction = "HitBody"
			else
				reaction = (if punch then REACTION_BY_PUNCH[punch] else nil) or "HitJab"
			end
		end
		CharacterAnimationController.playAction(victim, reaction)

		-- Physical kick on top: the head back (face) or the body folding
		-- (body shot), plus sideways for the punches that come from the side.
		local kick = if strong then HEAVY_FLINCH_KICK else FLINCH_KICK
		local side = if toBody
			then 0
			elseif
				punch == "Brawler_M1_2"
			then -0.6 -- right cross → the head goes to the victim's right
			elseif punch == "Brawler_M1_3" then 0.6 -- left hook → to its left
			else 0
		local pitch = if not fromFront then -1 elseif toBody then -0.7 else 1
		if iAmVictim and zone == "Head" then
			headBlur()
		end
		CharacterAnimationController.flinch(
			victim,
			Vector3.new(kick * pitch, kick * side, kick * side * 0.5)
		)

		-- Hit-stop on both fighters: the instant of contact is held.
		local stop = if strong then HEAVY_HIT_STOP else HIT_STOP
		CharacterAnimationController.hitStop(victim, stop)
		CharacterAnimationController.hitStop(attacker, stop)

		SoundController.play(if strong then "HeavyHit" else "Hit", victim)
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
local SERVER_ONLY_ACTIONS = table.freeze({ GetUp = true })

-- A fighter started a punch, a dash, a finisher, or got up after a KO.
-- (Our own punches / dashes / finishers already played locally.)
local function onCombatAction(model: Model, action: string)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or typeof(action) ~= "string" then
		return
	end
	if model == player.Character and not SERVER_ONLY_ACTIONS[action] then
		-- Ours: already played when we clicked, unless the server disagreed.
		CombatController.onServerAction(action)
		return
	end
	CharacterAnimationController.playAction(model, action)
	if action == "GetUp" then
		return
	elseif action == "Finisher" or action == `Brawler_M1_{#Config.Combat.M1_DAMAGE}` then
		SoundController.play("HeavySwing", model) -- the heavy blows
	elseif string.sub(action, 1, 4) == "Dash" then
		SoundController.play("Dash", model)
	else
		SoundController.play("Swing", model)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function CombatEffectsController.start()
	local tag = Config.Combat.TAG
	CollectionService:GetInstanceAddedSignal(tag):Connect(onCombatantAdded)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(onCombatantRemoved)
	for _, instance in CollectionService:GetTagged(tag) do
		onCombatantAdded(instance)
	end

	Remotes.CombatEvent.OnClientEvent:Connect(onCombatEvent)
	Remotes.CombatAction.OnClientEvent:Connect(onCombatAction)
	RunService:BindToRenderStep("CombatShake", Enum.RenderPriority.Camera.Value + 2, updateShake)
end

return CombatEffectsController
