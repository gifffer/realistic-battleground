--!strict
-- HudController: your health and stamina, bottom-left (display only),
-- plus your level, XP line and the rewards you just earned above them.
--
--   FINISHER  +75 XP · +15 COINS      rewards (newest at the bottom, max 3)
--   LV 8      ────────────────────    level + XP hairline (1 px, faint)
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
-- • XP: when you earn XP the line grows and the bit you just earned shows
--   bright for a moment; on a level up it fills to the end, the level
--   number changes and it starts again from 0 (the big "LEVEL 10" title is
--   LevelUpController's job).
-- • Rewards ("KILL +50 XP · +10 COINS"): slide in from the left, older
--   lines dim and move up, each fades out after a few seconds.
--
-- Health comes from the Humanoid, stamina from the "Stamina" /
-- "StaminaExhausted" attributes the server sets (Server/Systems/Stamina).
-- XP comes from the save (PlayerDataController: total XP, the level is
-- worked out with Shared/Progression), rewards from Remotes.Progress.
--
-- Other controllers can use:
--   HudController.getGui()                 the HUD ScreenGui (to add layers)
--   HudController.setRewardsHidden(true)   hide the reward lines (scoreboard held)
--   HudController.setHidden(true)          hide the whole HUD (duel result screen),
--                                          like it hides itself on a KO
--
-- Duel rewards (DuelWin / DuelLoss / RankedWin / RankedLoss) add NO line to
-- the reward stack: the duel result screen lists them (DuelController). The
-- XP line still grows, since it follows the save.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ProgressionCurve = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)

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

-- Level + XP line --------------------------------------------------------
local MAX_LEVEL = Config.Progression.MAX_LEVEL
local XP_FILL_TRANSPARENCY = 0.5 -- one step under the stamina fill
-- Same idle rule as the other fills: halfway to invisible.
local XP_FILL_IDLE = XP_FILL_TRANSPARENCY + (1 - XP_FILL_TRANSPARENCY) * IDLE_TRANSPARENCY

local levelRow: Frame
local lvNum: TextLabel
local xpFill: Frame
local xpGain: Frame -- the bright segment you just earned
local gainFade: Tween? = nil
local shownXp: number? = nil -- total XP the line shows (nil = save not here yet)
local xpToken = 0 -- bumped on every change, so an old animation step stops

-- Rewards ----------------------------------------------------------------
local REWARD_MAX_ROWS = 3
local REWARD_GAP = 2 -- pixels between two lines
local REWARD_OLD_TRANSPARENCY = 0.35 -- every line but the newest
local REWARD_LIFE_MAJOR = 4 -- KILL / FINISHER / ASSIST, seconds
local REWARD_LIFE_MINOR = 2.5 -- DAMAGE / PLAYTIME
local FINISHER_MIN_XP = Config.Progression.KILL_XP -- a Kill above this = finisher

type RewardRow = {
	frame: Frame,
	labels: { TextLabel },
	kind: Types.RewardKind,
	height: number,
	xp: number,
	coins: number,
	xpNum: TextLabel,
	coinParts: { TextLabel }, -- the dot, the number and "COINS"
	coinNum: TextLabel,
	token: number, -- bumped when its life restarts
	leaving: boolean,
}

local rewardsFrame: Frame
local rewardRows: { RewardRow } = {} -- oldest first, newest last
local hiddenByOther = false -- HudController.setHidden (duel result screen)
local rewardsHidden = false

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
		-- 66 × 34: "100" in this font (bold, ×1.12) is ≈ 63 × 34 px.
		Size = UDim2.fromOffset(66, 34),
		FontFace = Theme.Fonts.NumberLight,
		TextSize = 30,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "100",
	})
	hpLabel = label({
		Name = "HpLabel",
		-- y 18: sits on the numeral's baseline.
		Position = UDim2.fromOffset(56, 18),
		Size = UDim2.fromOffset(120, 12),
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = Theme.track("HEALTH", "three"),
	})
	-- HEALTH follows the numeral: never closer than 6 px to its last digit.
	local function placeHpLabel()
		hpLabel.Position = UDim2.fromOffset(math.max(56, hpNum.TextBounds.X + 6), 18)
	end
	hpNum:GetPropertyChangedSignal("TextBounds"):Connect(placeHpLabel)
	placeHpLabel()
	label({
		Name = "HpMax",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 18),
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

	-- Level row, 22 px above the HP numeral: "LV 8 ──────".
	levelRow = Theme.make("Frame", {
		Name = "LevelRow",
		Position = UDim2.fromOffset(0, -22),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Visible = false, -- shown once the save has arrived
		Parent = vitals,
	})
	local lvKey = Theme.text({
		Name = "LvKey",
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.fromOffset(16, 11),
		TextSize = 9,
		TextColor3 = C.Ink2,
		Text = Theme.track("LV", "three"),
		Parent = levelRow,
	}) :: TextLabel
	table.insert(texts, lvKey)
	lvNum = Theme.text({
		Name = "LvNum",
		Position = UDim2.fromOffset(19, 0),
		Size = UDim2.fromOffset(48, 12),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		Text = "1",
		Parent = levelRow,
	}) :: TextLabel
	table.insert(texts, lvNum)
	-- The line starts at x 72, right under the reward numbers.
	local xpTrack = Theme.make("Frame", {
		Name = "XpTrack",
		Position = UDim2.fromOffset(72, 6),
		Size = UDim2.new(1, -72, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.88,
		Parent = levelRow,
	})
	xpFill = Theme.make("Frame", {
		Name = "XpFill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = XP_FILL_TRANSPARENCY,
		Parent = xpTrack,
	})
	xpGain = Theme.make("Frame", {
		Name = "XpGain",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0,
		ZIndex = 2,
		Visible = false,
		Parent = xpTrack,
	})

	-- Rewards: their bottom edge 34 px above the HP numeral (12 px above
	-- the XP line). Lines are placed by code so they can slide.
	rewardsFrame = Theme.make("Frame", {
		Name = "Rewards",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(0, -34),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		Parent = vitals,
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
		Theme.tween(xpFill, 0.1, { BackgroundTransparency = XP_FILL_TRANSPARENCY })
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
	Theme.tween(xpFill, 0.6, { BackgroundTransparency = XP_FILL_IDLE }, Enum.EasingStyle.Linear)
	-- The red damage ghost sits under the bar: hide it, or it would show
	-- through the faded bar and tint a healthy bar red.
	Theme.tween(hpGhost, 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
end

------------------------------------------------------------------------------
-- Level + XP line
------------------------------------------------------------------------------

-- Plays a gain: the bright segment over [from, to] (0–1 of the level), the
-- fill grows to `to` in `seconds`, and the segment fades out after 0.5 s.
local function playGain(from: number, to: number, seconds: number, token: number)
	if gainFade then
		gainFade:Cancel()
		gainFade = nil
	end
	xpGain.Position = UDim2.fromScale(from, 0)
	xpGain.Size = UDim2.fromScale(math.max(0, to - from), 1)
	xpGain.BackgroundTransparency = 0
	xpGain.Visible = true
	Theme.tween(
		xpFill,
		seconds,
		{ Size = UDim2.fromScale(to, 1) },
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out
	)
	task.delay(0.5, function()
		if xpToken ~= token then
			return -- a newer gain took over
		end
		local fade =
			Theme.tween(xpGain, 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
		gainFade = fade
		fade.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and xpToken == token then
				xpGain.Visible = false
			end
		end)
	end)
end

-- Shows `total` XP (from the save). Animated when it went up.
local function showXp(total: number)
	local level, into, need = ProgressionCurve.levelFromXp(total)
	local ratio = if need > 0 then math.clamp(into / need, 0, 1) else 1
	local previous = shownXp
	shownXp = total
	levelRow.Visible = true
	xpToken += 1
	local token = xpToken

	-- First value, no change, or XP went down (should not happen): no animation.
	if previous == nil or total <= previous then
		if gainFade then
			gainFade:Cancel()
			gainFade = nil
		end
		lvNum.Text = tostring(level)
		xpGain.Visible = false
		xpFill.Size = UDim2.fromScale(ratio, 1)
		return
	end
	touched() -- a gain brings the faded vitals back

	local oldLevel, oldInto, oldNeed = ProgressionCurve.levelFromXp(previous)
	if oldLevel >= MAX_LEVEL then
		-- Level 100: the line stays full and never animates.
		lvNum.Text = tostring(level)
		xpFill.Size = UDim2.fromScale(1, 1)
		return
	end
	if level == oldLevel then
		-- Also set here: a level-up animation cut short by this change
		-- never got to write the new number.
		lvNum.Text = tostring(level)
		playGain(math.clamp(oldInto / oldNeed, 0, 1), ratio, 0.5, token)
		return
	end

	-- Level up: fill to the end, then the number changes and the line
	-- starts again from 0 up to what is left over.
	xpGain.Visible = false
	Theme.tween(
		xpFill,
		0.25,
		{ Size = UDim2.fromScale(1, 1) },
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out
	)
	task.delay(0.25, function()
		if xpToken ~= token then
			return
		end
		lvNum.Text = tostring(level)
		if level >= MAX_LEVEL then
			xpFill.Size = UDim2.fromScale(1, 1)
			return
		end
		xpFill.Size = UDim2.fromScale(0, 1)
		playGain(0, ratio, 0.4, token)
	end)
end

------------------------------------------------------------------------------
-- Rewards ("KILL  +50 XP · +10 COINS")
------------------------------------------------------------------------------

-- 1382 → "1 382" (thin space between thousands, never a comma).
local function formatNumber(value: number): string
	local digits = tostring(math.floor(value))
	local out = digits
	while true do
		local replaced, count = string.gsub(out, "^(%d+)(%d%d%d)", "%1\u{2009}%2")
		out = replaced
		if count == 0 then
			break
		end
	end
	return out
end

local function isMajor(kind: Types.RewardKind): boolean
	return kind == "Kill" or kind == "Assist" or kind == "Quest"
end

local function reasonWord(kind: Types.RewardKind, xp: number): string
	if kind == "Kill" then
		return if xp > FINISHER_MIN_XP then "FINISHER" else "KILL"
	elseif kind == "Assist" then
		return "ASSIST"
	elseif kind == "Damage" then
		return "DAMAGE"
	elseif kind == "Quest" then
		return "QUEST"
	end
	return "PLAYTIME"
end

-- Puts every line at its place: newest at the bottom, the others above it,
-- dimmed. `skip` = a line that is entering (it animates itself).
local function layoutRewards(skip: RewardRow?)
	local offset = 0
	local count = #rewardRows
	for index = count, 1, -1 do
		local row = rewardRows[index]
		if row ~= skip then
			Theme.tween(row.frame, 0.15, { Position = UDim2.new(0, 0, 1, -offset) })
			if not row.leaving then
				local goal = if index == count then 0 else REWARD_OLD_TRANSPARENCY
				for _, text in row.labels do
					Theme.tween(text, 0.15, { TextTransparency = goal })
				end
			end
		end
		offset += row.height + REWARD_GAP
	end
end

local function removeReward(row: RewardRow)
	local index = table.find(rewardRows, row)
	if index then
		table.remove(rewardRows, index)
	end
	row.frame:Destroy()
end

-- Starts (or restarts) a line's life; at the end it fades out and goes.
local function scheduleExit(row: RewardRow)
	row.token += 1
	local token = row.token
	local life = if isMajor(row.kind) then REWARD_LIFE_MAJOR else REWARD_LIFE_MINOR
	task.delay(life, function()
		if row.token ~= token or table.find(rewardRows, row) == nil then
			return
		end
		row.leaving = true
		for _, text in row.labels do
			Theme.tween(text, 0.4, { TextTransparency = 1 }, Enum.EasingStyle.Linear)
		end
		task.delay(0.4, function()
			if table.find(rewardRows, row) then -- not already pushed out
				removeReward(row)
				layoutRewards() -- the lines above slide down
			end
		end)
	end)
end

local function setRewardNumbers(row: RewardRow)
	row.xpNum.Text = "+" .. formatNumber(row.xp)
	row.coinNum.Text = "+" .. formatNumber(row.coins)
	for _, part in row.coinParts do
		part.Visible = row.coins > 0
	end
end

local function buildRewardRow(kind: Types.RewardKind, xp: number, coins: number): RewardRow
	local major = isMajor(kind)
	local height = if major then 16 else 14
	local numberSize = if major then 11 else 10
	local frame = Theme.make("Frame", {
		Name = "Reward",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -8, 1, 0),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
	}) :: Frame
	local labels: { TextLabel } = {}

	-- Every part has the line's full height and sits on the bottom, so the
	-- small units share the numbers' baseline.
	local function part(
		order: number,
		props: { [string]: any },
		padLeft: number?,
		padRight: number?
	): TextLabel
		props.LayoutOrder = order
		props.Size = props.Size or UDim2.fromScale(0, 1)
		props.AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.X
		props.TextYAlignment = Enum.TextYAlignment.Bottom
		props.TextTransparency = 1 -- fades in
		props.Parent = frame
		local children: { Instance } = {}
		if padLeft or padRight then
			table.insert(
				children,
				Theme.make("UIPadding", {
					PaddingLeft = UDim.new(0, padLeft or 0),
					PaddingRight = UDim.new(0, padRight or 0),
				})
			)
		end
		local text = Theme.text(props, children) :: TextLabel
		table.insert(labels, text)
		return text
	end

	part(1, {
		Name = "Why",
		Size = UDim2.new(0, 72, 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		TextSize = if major then 10 else 9,
		TextColor3 = if major then C.Ink else C.Ink2,
		Text = Theme.track(reasonWord(kind, xp), "three"),
	})
	local xpNum = part(2, {
		Name = "XpNum",
		FontFace = Theme.Fonts.Number,
		TextSize = numberSize,
		TextColor3 = if major then C.Ink else C.Ink2,
	})
	part(3, {
		Name = "XpUnit",
		FontFace = Theme.Fonts.Number,
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = "XP",
	}, 4)
	local dot = part(4, {
		Name = "Dot",
		FontFace = Theme.Fonts.LabelRegular,
		TextSize = 11,
		TextColor3 = C.Ink2,
		Text = "·",
	}, 7, 7)
	local coinNum = part(5, {
		Name = "CoinNum",
		FontFace = Theme.Fonts.Number,
		TextSize = numberSize,
		TextColor3 = C.Ink2,
	})
	local coinUnit = part(6, {
		Name = "CoinUnit",
		FontFace = Theme.Fonts.Number,
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = "COINS",
	}, 4)

	local row: RewardRow = {
		frame = frame,
		labels = labels,
		kind = kind,
		height = height,
		xp = xp,
		coins = coins,
		xpNum = xpNum,
		coinParts = { dot, coinNum, coinUnit },
		coinNum = coinNum,
		token = 0,
		leaving = false,
	}
	setRewardNumbers(row)
	return row
end

local pendingQuests: { { xp: number, coins: number } } = {}

local function showReward(kind: Types.RewardKind, xp: number, coins: number)
	touched() -- a reward brings the faded vitals back
	-- Nothing new while the HUD is hidden (knocked out, menu) or the
	-- scoreboard is held: those rewards are not replayed later (the XP line
	-- still updates from the save).
	if not gui.Enabled or rewardsHidden then
		-- A completed daily quest is worth showing later: kept until the
		-- HUD is back (see flushPendingQuests).
		if kind == "Quest" then
			table.insert(pendingQuests, { xp = xp, coins = coins })
		end
		return
	end

	-- DAMAGE / PLAYTIME already on screen: add to that line, restart its life.
	if not isMajor(kind) then
		for _, row in rewardRows do
			if row.kind == kind and not row.leaving then
				row.xp += xp
				row.coins += coins
				setRewardNumbers(row)
				scheduleExit(row)
				return
			end
		end
	end

	local row = buildRewardRow(kind, xp, coins)
	table.insert(rewardRows, row)
	-- A 4th line removes the oldest at once.
	while #rewardRows > REWARD_MAX_ROWS do
		removeReward(rewardRows[1])
	end
	row.frame.Parent = rewardsFrame
	-- Enters from the left (the kill feed enters from the right).
	Theme.tween(row.frame, 0.18, { Position = UDim2.new(0, 0, 1, 0) })
	for _, text in row.labels do
		Theme.tween(text, 0.18, { TextTransparency = 0 })
	end
	layoutRewards(row)
	scheduleExit(row)
end

-- Quest completions that happened while the HUD was hidden, shown now.
local function flushPendingQuests()
	if #pendingQuests == 0 or not gui.Enabled or rewardsHidden then
		return
	end
	local list = pendingQuests
	pendingQuests = {}
	for _, reward in list do
		showReward("Quest", reward.xp, reward.coins)
	end
end

local function onProgress(kind: unknown, xp: unknown, coins: unknown)
	-- Only these kinds get a line (+ "Quest": a daily quest completed). Duel rewards ("DuelWin", "DuelLoss",
	-- "RankedWin", "RankedLoss") are left out on purpose: the duel result
	-- screen shows them.
	if
		(
			kind ~= "Kill"
			and kind ~= "Assist"
			and kind ~= "Damage"
			and kind ~= "Playtime"
			and kind ~= "Quest"
		)
		or typeof(xp) ~= "number"
		or typeof(coins) ~= "number"
		or xp ~= xp -- NaN
		or coins ~= coins
	then
		return
	end
	if kind == "Damage" and xp <= 0 then
		return
	end
	showReward(kind :: Types.RewardKind, xp, coins)
end

-- Hidden while knocked out, while a menu is open, or when another
-- controller asks (setHidden: the duel result screen).
local function updateVisibility()
	local character = player.Character
	local down = character ~= nil and character:GetAttribute("KnockedOut") == true
	gui.Enabled = not down and not hiddenByOther and MenuController.getOpen() == nil
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
		if #pendingQuests > 0 then
			flushPendingQuests()
		end
	end)

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	refreshStamina()

	-- Level + XP line follows the save; rewards come one by one.
	PlayerDataController.onChanged(function(data)
		if data.xp ~= shownXp then
			showXp(data.xp)
		end
	end)
	Remotes.Progress.OnClientEvent:Connect(onProgress)
end

-- The HUD ScreenGui (LevelUpController puts its layer in it).
function HudController.getGui(): ScreenGui
	return gui
end

-- Hides / shows the reward lines (e.g. while the scoreboard is held).
-- Rewards that arrive while hidden are not replayed.
function HudController.setRewardsHidden(hidden: boolean)
	rewardsHidden = hidden
	rewardsFrame.Visible = not hidden
end

-- Hides / shows the whole HUD, the way it hides itself while you are
-- knocked out (used by the duel's VICTORY / DEFEAT screen).
function HudController.setHidden(hidden: boolean)
	hiddenByOther = hidden
	updateVisibility()
end

return HudController
