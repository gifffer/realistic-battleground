--!strict
-- HudController: your health and stamina, bottom-left (display only).
--
--   82  HEALTH                /100
--   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   health: 2 px hairline (+ a red "ghost"
--   ─────────────────────────────     that drains after a hit)
--   STAMINA                           stamina: 1 px hairline
--
-- • Damage: the bar drops at once, a red sliver shows what you just lost and
--   drains away a moment later; the number flashes red.
-- • Low health (≤ 30): the bar and the number stay red.
-- • Out of stamina: the stamina line turns red and pulses, its label reads
--   WINDED. While blocking it reads GUARD, while limping LIMPING.
-- • Full health and stamina for a few seconds: the whole block fades back,
--   any change brings it back.
-- • Bleeding (a bottle cut...): the label reads BLEEDING, the part of
--   the bar the cut will still take is drawn red and shrinks with each tick,
--   and the left edge of the screen darkens a little at each tick.
-- • Soft dark gradients at the screen edges keep text readable on bright
--   scenes. Everything hides while you're knocked out or a menu is open.
--
-- Health comes from the Humanoid, stamina from the "Stamina" /
-- "StaminaExhausted" attributes the server sets (Server/Systems/Stamina).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)

local player = Players.LocalPlayer
local C = Theme.Colors

local LOW_HEALTH = 30
local GHOST_DELAY = 0.35 -- the red sliver waits, then drains
local IDLE_FADE_AFTER = 4 -- seconds at full health and stamina
local IDLE_TRANSPARENCY = 0.5

local HudController = {}

local gui: ScreenGui
local vitals: Frame
local hpNum: TextLabel
local hpFill: Frame
local hpGhost: Frame
local stFill: Frame
local stLabel: TextLabel
local hpLabel: TextLabel
local bleedSeg: Frame
local bleedEdge: Frame
local bleedShade: Frame
local bleeding = false
local bleedTweenUntil = 0 -- the per-tick shrink is playing until then
local texts: { TextLabel } = {} -- every text of the block (for the idle fade)

local humanoidConnections: { RBXScriptConnection } = {}
local shownHealth = -1
local ghostToken = 0
local exhaustedPulse: Tween? = nil
local lastChangeAt = 0
local idle = false

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function scrim(
	name: string,
	props: { [string]: any },
	rotation: number,
	points: { { number } }
)
	props.Name = name
	props.BackgroundColor3 = C.Scrim
	props.BackgroundTransparency = 0
	props.ZIndex = 0
	props.Parent = gui
	return Theme.make("Frame", props, { Theme.gradient(rotation, points) })
end

local function label(props: { [string]: any }): TextLabel
	props.Parent = vitals
	local text = Theme.text(props) :: TextLabel
	table.insert(texts, text)
	return text
end

local function build()
	gui = Theme.make("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Legibility layer: gradients with no visible edge.
	scrim(
		"ScrimTop",
		{ Size = UDim2.new(1, 0, 0, 190) },
		90,
		{ { 0, 0.38 }, { 0.45, 0.62 }, { 1, 1 } }
	)
	scrim("ScrimBottom", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 200),
	}, -90, { { 0, 0.42 }, { 0.45, 0.72 }, { 1, 1 } })
	scrim("ScrimLeft", { Size = UDim2.new(0, 260, 1, 0) }, 0, { { 0, 0.68 }, { 1, 1 } })

	vitals = Theme.make("Frame", {
		Name = "Vitals",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 48, 1, -44),
		Size = UDim2.fromOffset(240, 72),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	hpNum = label({
		Name = "HpNum",
		Size = UDim2.fromOffset(52, 30),
		FontFace = Theme.Fonts.NumberLight,
		TextSize = 30,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "100",
	})
	hpLabel = label({
		Name = "HpLabel",
		Position = UDim2.fromOffset(56, 15),
		Size = UDim2.fromOffset(120, 12),
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = Theme.track("HEALTH", "three"),
	})
	label({
		Name = "HpMax",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 15),
		Size = UDim2.fromOffset(40, 12),
		FontFace = Theme.Fonts.Number,
		TextSize = 10,
		TextColor3 = C.Ink2,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = `/{Config.Character.MAX_HEALTH}`,
	})
	local hpTrack = Theme.make("Frame", {
		Name = "HpTrack",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.78,
		Parent = vitals,
	})
	hpGhost = Theme.make("Frame", {
		Name = "HpGhost",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.BloodHi,
		BackgroundTransparency = 0.15,
		ZIndex = 2,
		Parent = hpTrack,
	})
	hpFill = Theme.make("Frame", {
		Name = "HpFill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		ZIndex = 3,
		Parent = hpTrack,
	})
	-- Bleeding: the health the cut will still take, over the end of the bar.
	bleedSeg = Theme.make("Frame", {
		Name = "BleedSeg",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.BloodHi,
		ZIndex = 4,
		Visible = false,
		Parent = hpTrack,
	})
	-- Left edge while bleeding: a dark shade with a dark red on top.
	bleedShade = Theme.make("Frame", {
		Name = "BleedShade",
		Size = UDim2.new(0, 220, 1, 0),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = gui,
	}, { Theme.gradient(0, { { 0, 0.72 }, { 1, 1 } }) })
	bleedEdge = Theme.make("Frame", {
		Name = "BleedEdge",
		Size = UDim2.new(0, 220, 1, 0),
		BackgroundColor3 = C.BloodDeep,
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = gui,
	}, { Theme.gradient(0, { { 0, 0.72 }, { 1, 1 } }) })
	local stTrack = Theme.make("Frame", {
		Name = "StTrack",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.78,
		Parent = vitals,
	})
	stFill = Theme.make("Frame", {
		Name = "StFill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink2,
		ZIndex = 2,
		Parent = stTrack,
	})
	stLabel = label({
		Name = "StLabel",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.fromOffset(120, 11),
		TextSize = 9,
		TextColor3 = C.Ink2,
		Text = Theme.track("STAMINA", "three"),
	})
end

------------------------------------------------------------------------------
-- Updating
------------------------------------------------------------------------------

local function touched()
	lastChangeAt = os.clock()
	if idle then
		idle = false
		for _, text in texts do
			Theme.tween(text, 0.1, { TextTransparency = 0 })
		end
		Theme.tween(hpFill, 0.1, { BackgroundTransparency = 0 })
		Theme.tween(stFill, 0.1, { BackgroundTransparency = 0 })
		Theme.tween(hpGhost, 0.1, { BackgroundTransparency = 0.15 })
	end
end

local function setHealth(health: number, maxHealth: number)
	local ratio = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
	local low = health <= LOW_HEALTH
	local previous = shownHealth
	shownHealth = health
	hpNum.Text = tostring(math.ceil(health))
	touched()

	if previous >= 0 and health < previous then
		-- Damage: drop now, flash the number, drain the red ghost a bit later.
		Theme.tween(hpFill, 0.08, { Size = UDim2.fromScale(ratio, 1) })
		hpNum.TextColor3 = C.BloodHi
		if not low then
			Theme.tween(hpNum, 0.4, { TextColor3 = C.Ink })
		end
		ghostToken += 1
		local token = ghostToken
		task.delay(GHOST_DELAY, function()
			if ghostToken == token then
				Theme.tween(
					hpGhost,
					0.45,
					{ Size = UDim2.fromScale(ratio, 1) },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.InOut
				)
			end
		end)
	else
		-- Heal (or first value): the ghost snaps, the bar grows.
		ghostToken += 1
		hpGhost.Size = UDim2.fromScale(ratio, 1)
		Theme.tween(hpFill, 0.3, { Size = UDim2.fromScale(ratio, 1) })
		if not low then
			Theme.tween(hpNum, 0.2, { TextColor3 = C.Ink })
		end
	end
	Theme.tween(hpFill, 0.2, { BackgroundColor3 = if low then C.BloodHi else C.Ink })
	if low then
		hpNum.TextColor3 = C.BloodHi
	end
end

-- Bleeding: label, red segment and edge. Called every frame (cheap) and
-- after each health change.
local function updateBleeding(tick: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local now = character ~= nil and character:GetAttribute("Bleeding") == true
	if now ~= bleeding then
		bleeding = now
		touched()
		if now then
			-- Brighter, not red (small red caps don't read on a light floor):
			-- the red is in the bar and at the edge.
			hpLabel.Text = Theme.track("BLEEDING", "three")
			hpLabel.TextColor3 = C.Ink
			bleedSeg.Visible = true
			bleedEdge.BackgroundTransparency = 0.15
			Theme.tween(bleedShade, 0.2, { BackgroundTransparency = 0 })
		else
			hpLabel.Text = Theme.track("HEALTH", "three")
			Theme.tween(hpLabel, 0.3, { TextColor3 = C.Ink2 })
			bleedSeg.Visible = false
			task.delay(0.4, function()
				if not bleeding then
					Theme.tween(bleedEdge, 0.4, { BackgroundTransparency = 1 })
					Theme.tween(bleedShade, 0.4, { BackgroundTransparency = 1 })
				end
			end)
		end
	end
	if not now or character == nil or humanoid == nil or humanoid.MaxHealth <= 0 then
		return
	end
	local perSecond = character:GetAttribute("BleedPerSecond")
	local untilTime = character:GetAttribute("BleedUntil")
	local left = if typeof(untilTime) == "number"
		then math.max(0, untilTime - workspace:GetServerTimeNow())
		else 0
	local remaining = if typeof(perSecond) == "number"
		then math.min(humanoid.Health, perSecond * left)
		else 0
	local maxHealth = humanoid.MaxHealth
	local goal = {
		Position = UDim2.fromScale((humanoid.Health - remaining) / maxHealth, 0),
		Size = UDim2.fromScale(remaining / maxHealth, 1),
	}
	if tick then
		bleedTweenUntil = os.clock() + 0.12
		Theme.tween(bleedSeg, 0.12, goal)
		-- The edge breathes once per tick.
		Theme.tween(bleedEdge, 0.12, { BackgroundTransparency = 0 })
		task.delay(0.12, function()
			if bleeding then
				Theme.tween(
					bleedEdge,
					0.6,
					{ BackgroundTransparency = 0.15 },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
			end
		end)
	elseif os.clock() >= bleedTweenUntil then
		bleedSeg.Position = goal.Position
		bleedSeg.Size = goal.Size
	end
end

local function refreshStamina()
	local value = player:GetAttribute("Stamina")
	local stamina = if typeof(value) == "number" then value else 0
	local exhausted = player:GetAttribute("StaminaExhausted") == true
	local character = player.Character
	local blocking = character ~= nil and character:GetAttribute("Blocking") == true
	touched()

	Theme.tween(stFill, 0.12, {
		Size = UDim2.fromScale(math.clamp(stamina / Config.Stamina.MAX, 0, 1), 1),
	}, Enum.EasingStyle.Linear)

	if exhausted and exhaustedPulse == nil then
		stFill.BackgroundColor3 = C.Blood
		stLabel.TextColor3 = C.BloodHi
		local pulse = TweenService:Create(
			stFill,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.5 }
		)
		pulse:Play()
		exhaustedPulse = pulse
	elseif not exhausted and exhaustedPulse then
		exhaustedPulse:Cancel()
		exhaustedPulse = nil
		stFill.BackgroundTransparency = 0
		Theme.tween(stFill, 0.15, { BackgroundColor3 = C.Ink2 })
		stLabel.TextColor3 = C.Ink2
	end
	local limping = character ~= nil and character:GetAttribute("Limping") == true
	stLabel.Text = Theme.track(
		if exhausted
			then "WINDED"
			elseif blocking then "GUARD"
			elseif limping then "LIMPING" -- legs injured: slower, no sprint
			else "STAMINA",
		"three"
	)
end

-- Fades the block back after a while at full health and stamina.
local function updateIdle()
	if idle or os.clock() - lastChangeAt < IDLE_FADE_AFTER then
		return
	end
	local stamina = player:GetAttribute("Stamina")
	local full = shownHealth >= Config.Character.MAX_HEALTH
		and typeof(stamina) == "number"
		and stamina >= Config.Stamina.MAX
	if not full then
		return
	end
	idle = true
	for _, text in texts do
		Theme.tween(text, 0.6, { TextTransparency = IDLE_TRANSPARENCY }, Enum.EasingStyle.Linear)
	end
	Theme.tween(
		hpFill,
		0.6,
		{ BackgroundTransparency = IDLE_TRANSPARENCY },
		Enum.EasingStyle.Linear
	)
	Theme.tween(
		stFill,
		0.6,
		{ BackgroundTransparency = IDLE_TRANSPARENCY },
		Enum.EasingStyle.Linear
	)
	-- The red damage ghost sits under the bar: hide it, or it would show
	-- through the faded bar and tint a healthy bar red.
	Theme.tween(hpGhost, 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
end

-- Hidden while knocked out or while a menu is open.
local function updateVisibility()
	local character = player.Character
	local down = character ~= nil and character:GetAttribute("KnockedOut") == true
	gui.Enabled = not down and MenuController.getOpen() == nil
end

local function onCharacterAdded(character: Model)
	for _, connection in humanoidConnections do
		connection:Disconnect()
	end
	table.clear(humanoidConnections)
	shownHealth = -1

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	local function refreshHealth()
		local dropped = shownHealth >= 0 and humanoid.Health < shownHealth
		setHealth(humanoid.Health, humanoid.MaxHealth)
		updateBleeding(dropped)
	end
	table.insert(humanoidConnections, humanoid.HealthChanged:Connect(refreshHealth))
	table.insert(
		humanoidConnections,
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refreshHealth)
	)
	table.insert(
		humanoidConnections,
		character:GetAttributeChangedSignal("Blocking"):Connect(refreshStamina)
	)
	table.insert(
		humanoidConnections,
		character:GetAttributeChangedSignal("Limping"):Connect(refreshStamina)
	)
	table.insert(
		humanoidConnections,
		character:GetAttributeChangedSignal("KnockedOut"):Connect(updateVisibility)
	)
	table.insert(
		humanoidConnections,
		character:GetAttributeChangedSignal("Bleeding"):Connect(function()
			updateBleeding(false)
		end)
	)
	refreshHealth()
	refreshStamina()
	updateVisibility()
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function HudController.init()
	-- Hide Roblox's default health bar: ours replaces it.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	build()
end

function HudController.start()
	player:GetAttributeChangedSignal("Stamina"):Connect(refreshStamina)
	player:GetAttributeChangedSignal("StaminaExhausted"):Connect(refreshStamina)
	MenuController.onOpenChanged(updateVisibility)
	RunService.Heartbeat:Connect(function()
		updateIdle()
		if bleeding then
			updateBleeding(false)
		end
	end)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	refreshStamina()
end

return HudController
