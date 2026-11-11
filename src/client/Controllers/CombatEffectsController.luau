--!strict
-- CombatEffectsController: everything you SEE during a fight (no gameplay).
--
--   • Outline on every fighter: blue = blocking, yellow = stunned.
--   • Flash when hit: red = hit, blue = blocked, white = parry,
--     orange = guard break.
--   • Floating text: "PARRY!", "GUARD BREAK!", "DODGE".
--   • Small camera shake when YOU hit or get hit.
--   • Reaction animations and sounds on EVERY fighter. The reaction depends
--     on WHERE the hit lands (head or body) and from WHICH SIDE of the
--     victim it comes (front, back, left, right — sent by the server, so
--     every screen shows the same thing). Face hits from the front also
--     depend on the punch (jab, cross, hook). Then a hit-stop (both fighters
--     freeze on the contact frame) and a physical flinch in the direction
--     the fist pushed.
--   • Our OWN punches: the reaction is predicted the instant our fist lands
--     (CombatEffectsController.predictHit), instead of one network trip
--     later when the fist is already coming back (that looked like the
--     punch went through the body). Damage, sound and flash still wait for
--     the server.
--   • Other fighters' punches and dashes (Remotes.CombatAction): animation
--     + sound. Ours already played when we pressed the key.
--
-- Data comes from the server: the Config.Combat.TAG tag + "Blocking" /
-- "Stunned" attributes on each fighter (the block / stunned animations
-- follow them, see CharacterAnimationController), Remotes.CombatEvent and
-- Remotes.CombatAction.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local HitSide = require(ReplicatedStorage.Shared.Util.HitSide)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local COLORS = table.freeze({
	Blocking = Color3.fromRGB(80, 160, 255),
	Stunned = Color3.fromRGB(255, 215, 60),
	Hit = Color3.fromRGB(255, 40, 40),
	Blocked = Color3.fromRGB(80, 160, 255),
	Parry = Color3.fromRGB(255, 255, 255),
	GuardBreak = Color3.fromRGB(255, 140, 30),
})

local FLASH_TIME = 0.15

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
-- forgetting the prediction (seconds).
local PREDICTION_MEMORY = 0.6
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
	flashUntil: number,
}

local CombatEffectsController = {}

local visuals: { [Model]: Visual } = {}
local random = Random.new()
local shakeUntil = 0
local shakeStrength = 0

------------------------------------------------------------------------------
-- Outline (blocking / stunned) and flashes
------------------------------------------------------------------------------

-- Shows the lasting state of a fighter (unless a flash is playing).
local function refreshOutline(visual: Visual)
	if os.clock() < visual.flashUntil then
		return
	end
	local highlight = visual.highlight
	highlight.FillTransparency = 1
	if visual.model:GetAttribute("Stunned") == true then
		highlight.OutlineColor = COLORS.Stunned
		highlight.Enabled = true
	elseif visual.model:GetAttribute("Blocking") == true then
		highlight.OutlineColor = COLORS.Blocking
		highlight.Enabled = true
	else
		highlight.Enabled = false
	end
end

local function flash(model: Model, color: Color3)
	local visual = visuals[model]
	if visual == nil then
		return
	end
	local highlight = visual.highlight
	visual.flashUntil = os.clock() + FLASH_TIME
	highlight.Enabled = true
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.3
	TweenService:Create(highlight, TweenInfo.new(FLASH_TIME), { FillTransparency = 1 }):Play()
	task.delay(FLASH_TIME + 0.01, function()
		if visuals[model] == visual then
			refreshOutline(visual)
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
		FillTransparency = 1,
		OutlineTransparency = 0,
		Enabled = false,
		Parent = model,
	}) :: Highlight

	local visual: Visual = { model = model, highlight = highlight, flashUntil = 0 }
	visuals[model] = visual
	model:GetAttributeChangedSignal("Blocking"):Connect(function()
		refreshOutline(visual)
	end)
	model:GetAttributeChangedSignal("Stunned"):Connect(function()
		refreshOutline(visual)
	end)
	refreshOutline(visual)
end

local function onCombatantRemoved(instance: Instance)
	if instance:IsA("Model") then
		visuals[instance] = nil
	end
end

------------------------------------------------------------------------------
-- Floating text and camera shake
------------------------------------------------------------------------------

local function floatingText(model: Model, text: string, color: Color3)
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local billboard = Theme.make("BillboardGui", {
		Name = "CombatText",
		Size = UDim2.fromOffset(220, 40),
		StudsOffset = Vector3.new(0, 2.5, 0),
		AlwaysOnTop = true,
		MaxDistance = 80,
		Adornee = head,
		Parent = head,
	}, {
		Theme.make("TextLabel", {
			Name = "Label",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Title,
			TextSize = 26,
			TextColor3 = color,
			TextStrokeTransparency = 0.3,
			Text = text,
		}),
	}) :: BillboardGui

	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService
		:Create(
			(billboard :: any).Label,
			info,
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		:Play()
	Debris:AddItem(billboard, 0.75)
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
	side: Types.HitSide
)
	CharacterAnimationController.playAction(victim, chooseReaction(strong, zone, side, attacker))
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

-- When each fighter last got a predicted reaction from one of OUR punches.
local predictedAt: { [Model]: number } = {}

-- Takes a recent prediction for `victim` (true = we already showed it).
local function consumePrediction(victim: Model): boolean
	local time = predictedAt[victim]
	predictedAt[victim] = nil
	return time ~= nil and os.clock() - time < PREDICTION_MEMORY
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
	return true
end

-- Body parts of each zone (same as the server's Combat ZONE_PARTS).
local ZONE_PARTS: { [string]: { string } } = {
	Head = { "Head" },
	Torso = { "Torso", "HumanoidRootPart", "Right Arm", "Left Arm" },
}

local function zoneInBox(zone: string, parts: { [string]: boolean }): boolean
	for _, name in ZONE_PARTS[zone] do
		if parts[name] then
			return true
		end
	end
	return false
end

-- Same rule as the server's landingZone (punches reach the head or the torso).
local function predictZone(aimed: Types.HitZone, parts: { [string]: boolean }): Types.HitZone
	local zone: Types.HitZone = "Torso"
	if (aimed == "Head" or aimed == "Torso") and zoneInBox(aimed, parts) then
		zone = aimed
	elseif not zoneInBox("Torso", parts) and zoneInBox("Head", parts) then
		zone = "Head"
	end
	return zone
end

-- Called by CombatController Config.Combat.HIT_DELAY after we click, i.e.
-- the moment our fist reaches its target in the punch animation. Uses the
-- SAME box as the server. Purely visual: the server still decides the hit,
-- the damage and everything else.
function CombatEffectsController.predictHit(strong: boolean, aimed: Types.HitZone)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	-- A stunned attacker's punch is cancelled by the server.
	if character:GetAttribute("Stunned") == true then
		return
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local box = root.CFrame * CFrame.new(0, 0, -Config.Combat.HITBOX_FORWARD)

	local partsByModel: { [Model]: { [string]: boolean } } = {}
	for _, part in workspace:GetPartBoundsInBox(box, Config.Combat.HITBOX_SIZE, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and CollectionService:HasTag(model, Config.Combat.TAG) then
			local parts = partsByModel[model]
			if parts == nil then
				parts = {}
				partsByModel[model] = parts
			end
			parts[part.Name] = true
		end
	end

	for model, parts in partsByModel do
		if canPredictHitOn(model) then
			local side: Types.HitSide = HitSide.compute(model:GetPivot(), root.Position)
			predictedAt[model] = os.clock()
			playHitReaction(model, character, strong, predictZone(aimed, parts), side)
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
	sideArg: unknown
)
	if typeof(victim) ~= "Instance" or typeof(attacker) ~= "Instance" then
		return -- a model that doesn't exist on this client (streamed out...)
	end
	local character = player.Character
	local iAmVictim = victim == character
	local iAmAttacker = attacker == character
	-- Did we already show this hit (our own punch, predicted)?
	local alreadyShown = iAmAttacker and consumePrediction(victim)

	if kind == "Hit" or kind == "Finisher" then
		flash(victim, COLORS.Hit)
		local strong = kind == "Finisher"
		local zone: Types.HitZone = resolveZone(zoneArg)
		if not alreadyShown then
			playHitReaction(victim, attacker, strong, zone, resolveSide(sideArg, victim, attacker))
		end
		if iAmVictim and zone == "Head" then
			headBlur()
		end

		SoundController.play(if strong then "HeavyHit" else "Hit", victim)
		if iAmVictim then
			shake(if strong then 1.6 else 0.8, if strong then 0.25 else 0.15)
		elseif iAmAttacker then
			shake(if strong then 0.8 else 0.35, 0.1)
		end
	elseif kind == "Blocked" then
		flash(victim, COLORS.Blocked)
		CharacterAnimationController.playAction(victim, "BlockHit")
		CharacterAnimationController.flinch(victim, Vector3.new(BLOCK_FLINCH_KICK, 0, 0))
		CharacterAnimationController.hitStop(victim, BLOCK_HIT_STOP)
		CharacterAnimationController.hitStop(attacker, BLOCK_HIT_STOP)
		SoundController.play("Block", victim)
		if iAmVictim then
			shake(0.3, 0.1)
		end
	elseif kind == "Parried" then
		flash(attacker, COLORS.Parry)
		floatingText(victim, "PARRY!", COLORS.Parry)
		CharacterAnimationController.playAction(victim, "Parry")
		CharacterAnimationController.hitStop(victim, PARRY_HIT_STOP)
		CharacterAnimationController.hitStop(attacker, PARRY_HIT_STOP)
		SoundController.play("Parry", victim)
		if iAmVictim or iAmAttacker then
			shake(0.6, 0.15)
		end
	elseif kind == "GuardBreak" then
		flash(victim, COLORS.GuardBreak)
		floatingText(victim, "GUARD BREAK!", COLORS.GuardBreak)
		CharacterAnimationController.playAction(victim, "GuardBreak")
		SoundController.play("GuardBreak", victim)
		if iAmVictim then
			shake(1.2, 0.2)
		end
	elseif kind == "Dodged" then
		floatingText(victim, "DODGE", Theme.Colors.Text)
		SoundController.play("Dodge", victim)
	elseif kind == "Protected" then
		floatingText(victim, "PROTECTED", Theme.Colors.TextDim)
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
		return
	end
	CharacterAnimationController.playAction(model, action)
	if action == "GetUp" then
		return
	elseif action == "Finisher" then
		SoundController.play("HeavySwing", model)
	elseif action == `Brawler_M1_{#Config.Combat.M1_DAMAGE}` then
		SoundController.play("HeavySwing", model)
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
