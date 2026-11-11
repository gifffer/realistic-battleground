--!strict
-- CombatEffectsController: everything you SEE during a fight (no gameplay).
--
--   • Outline on every fighter: blue = blocking, yellow = stunned.
--   • Flash when hit: red = hit, blue = blocked, white = parry,
--     orange = guard break.
--   • Floating text: "PARRY!", "GUARD BREAK!", "DODGE".
--   • Small camera shake when YOU hit or get hit.
--   • Your own reaction animations (hit, block hit, stunned...).
--
-- Data comes from the server: the Config.Combat.TAG tag + "Blocking" /
-- "Stunned" attributes on each fighter, and Remotes.CombatEvent.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local AnimationController = require(script.Parent.AnimationController)
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
		-- Our own "stunned" animation.
		if model == player.Character then
			if model:GetAttribute("Stunned") == true then
				AnimationController.play("Stunned", { looped = true })
			else
				AnimationController.stop("Stunned")
			end
		end
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

-- Was `attacker` in front of `victim`? (picks the right hit animation)
local function isInFront(victim: Model, attacker: Model): boolean
	local offset = attacker:GetPivot().Position - victim:GetPivot().Position
	return offset:Dot(victim:GetPivot().LookVector) >= 0
end

local function onCombatEvent(kind: Types.CombatEventKind, victim: Model, attacker: Model)
	if typeof(victim) ~= "Instance" or typeof(attacker) ~= "Instance" then
		return -- a model that doesn't exist on this client (streamed out...)
	end
	local character = player.Character
	local iAmVictim = victim == character
	local iAmAttacker = attacker == character

	if kind == "Hit" or kind == "Finisher" then
		flash(victim, COLORS.Hit)
		local strong = kind == "Finisher"
		if iAmVictim then
			shake(if strong then 1.6 else 0.8, if strong then 0.25 else 0.15)
			AnimationController.play(if isInFront(victim, attacker) then "HitFront" else "HitBack")
		elseif iAmAttacker then
			shake(if strong then 0.8 else 0.35, 0.1)
		end
	elseif kind == "Blocked" then
		flash(victim, COLORS.Blocked)
		if iAmVictim then
			shake(0.3, 0.1)
			AnimationController.play("BlockHit")
		end
	elseif kind == "Parried" then
		flash(attacker, COLORS.Parry)
		floatingText(victim, "PARRY!", COLORS.Parry)
		if iAmVictim then
			AnimationController.play("Parry")
		end
		if iAmVictim or iAmAttacker then
			shake(0.6, 0.15)
		end
	elseif kind == "GuardBreak" then
		flash(victim, COLORS.GuardBreak)
		floatingText(victim, "GUARD BREAK!", COLORS.GuardBreak)
		if iAmVictim then
			shake(1.2, 0.2)
			AnimationController.play("GuardBreak")
		end
	elseif kind == "Dodged" then
		floatingText(victim, "DODGE", Theme.Colors.Text)
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
	RunService:BindToRenderStep("CombatShake", Enum.RenderPriority.Camera.Value + 2, updateShake)
end

return CombatEffectsController
