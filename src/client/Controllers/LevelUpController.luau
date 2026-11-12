--!strict
-- LevelUpController: the short "NEW LEVEL" beat when your level goes up.
--
--                 NEW LEVEL
--              L E V E L   1 0
--          ─────────────────────        a hairline that draws itself
--          UNLOCKED · MMA FIGHTER       only when a kit unlocks at that level
--
-- Sober on purpose: no burst, no colour, no scale-up. A line of type in the
-- upper third of the screen (the fight stays clear), on a soft dark band so
-- white type reads on the light floor, plus a slight contrast bump. Gone
-- after 2.6 s.
--
-- • The level comes from the "Level" attribute the server sets on your
--   Player (Server/Systems/Progression). When it goes UP, the beat plays
--   (the first value, when the save loads, plays nothing).
-- • Knocked out, menu open or in a duel: the beat waits until that ends.
--   "In a duel" = the "InDuel" attribute the server sets on your Player
--   (Server/Systems/Duels): true from the match start until you are back
--   in the free arena, so it covers the rounds AND the VICTORY / DEFEAT
--   screen. The level-up then plays once you're back.
-- • Two level-ups in a row: the second only swaps the title and restarts
--   the hold.
-- • The XP line in the vitals animates on its own (HudController).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kits = require(ReplicatedStorage.Shared.Kits)
local Theme = require(script.Parent.Parent.UI.Theme)
local HudController = require(script.Parent.HudController)
local MenuController = require(script.Parent.MenuController)

local player = Players.LocalPlayer
local C = Theme.Colors

local BLOCK_Y = 120 -- top of the type, in pixels from the top of the screen
local TITLE_Y = 22
local RULE_WIDTH = 200
local RULE_TRANSPARENCY = 0.3
local HOLD = 2.2 -- seconds before everything fades out
local FADE_OUT = 0.4

local LevelUpController = {}

local band: Frame
local block: Frame
local eyebrow: TextLabel
local title: TextLabel
local rule: Frame
local unlock: TextLabel
local grade: ColorCorrectionEffect

-- "idle" = nothing on screen, "showing" = in or holding, "leaving" = fading out.
local phase = "idle"
local beatLevel: number? = nil -- the level the current beat shows
local beatToken = 0 -- bumped by every new beat (stops the old timeline)
local fadeToken = 0 -- bumped when the hold restarts (stops the old fade-out)
local lastLevel: number? = nil
local pendingLevel: number? = nil -- waiting for the KO / menu to end
local fadeTweens: { Tween } = {} -- the fade-out in progress (stopped by a new beat)

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function build()
	local gui = HudController.getGui()
	band = Theme.make("Frame", {
		Name = "LuBand",
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 1, -- the gradient below does the shape
		ZIndex = 3,
		Visible = false,
		Parent = gui,
	}, { Theme.gradient(90, { { 0, 1 }, { 0.5, 0.58 }, { 1, 1 } }) })
	block = Theme.make("Frame", {
		Name = "LuBlock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, BLOCK_Y),
		Size = UDim2.fromOffset(500, 110),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Visible = false,
		Parent = gui,
	})
	-- Centred tracked text gets one trailing space, so the extra letter
	-- spacing doesn't push it off centre (same as the KO title).
	eyebrow = Theme.text({
		Name = "Eyebrow",
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = 10,
		TextColor3 = C.Ink2,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 3,
		Text = Theme.track("NEW LEVEL", "three") .. " ",
		Parent = block,
	}) :: TextLabel
	title = Theme.text({
		Name = "Title",
		Position = UDim2.fromOffset(0, TITLE_Y),
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = Theme.Fonts.Display,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 3,
		Parent = block,
	}) :: TextLabel
	rule = Theme.make("Frame", {
		Name = "Rule",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = RULE_TRANSPARENCY,
		ZIndex = 3,
		Parent = block,
	})
	unlock = Theme.text({
		Name = "Unlock",
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = 10,
		TextColor3 = C.Ink, -- ink, not red: an unlock is not danger
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 3,
		Visible = false,
		Parent = block,
	}) :: TextLabel
	-- Our own colour correction (never shared with the KO / menu / Fury ones).
	grade = Theme.make("ColorCorrectionEffect", { Name = "LevelCC", Parent = Lighting })
end

------------------------------------------------------------------------------
-- The beat
------------------------------------------------------------------------------

-- The kit that unlocks exactly at `level` (nil for most levels).
local function kitUnlockedAt(level: number): Kits.KitDef?
	for _, kit in Kits.list() do
		if kit.unlockLevel == level then
			return kit
		end
	end
	return nil
end

local function titleText(level: number): string
	return Theme.track("LEVEL " .. tostring(level), "en") .. " "
end

-- Sets the optional "UNLOCKED · ..." line for `level`; true if shown.
local function setUnlock(level: number): boolean
	local kit = kitUnlockedAt(level)
	unlock.Visible = kit ~= nil
	if kit then
		unlock.Text = Theme.track("UNLOCKED · " .. string.upper(kit.name), "three") .. " "
	end
	return kit ~= nil
end

-- Runs `callback` after `seconds`, unless a newer beat started meanwhile.
local function later(seconds: number, token: number, callback: () -> ())
	task.delay(seconds, function()
		if beatToken == token then
			callback()
		end
	end)
end

-- Fades everything out `seconds` from now (unless the hold restarts).
local function scheduleFadeOut(seconds: number)
	fadeToken += 1
	local token = fadeToken
	task.delay(seconds, function()
		if fadeToken ~= token then
			return
		end
		phase = "leaving"
		local linear = Enum.EasingStyle.Linear
		table.clear(fadeTweens)
		table.insert(
			fadeTweens,
			Theme.tween(band, FADE_OUT, { BackgroundTransparency = 1 }, linear)
		)
		table.insert(
			fadeTweens,
			Theme.tween(block, FADE_OUT, { Position = UDim2.new(0.5, 0, 0, BLOCK_Y - 3) }, linear)
		)
		for _, text in { eyebrow, title, unlock } do
			table.insert(fadeTweens, Theme.tween(text, FADE_OUT, { TextTransparency = 1 }, linear))
		end
		table.insert(
			fadeTweens,
			Theme.tween(rule, FADE_OUT, { BackgroundTransparency = 1 }, linear)
		)
		task.delay(FADE_OUT, function()
			if fadeToken == token then
				phase = "idle"
				band.Visible = false
				block.Visible = false
			end
		end)
	end)
end

-- A second level-up while the first is still on screen: swap the title only.
local function swapTitle(level: number)
	title.TextTransparency = 1
	title.Text = titleText(level)
	Theme.tween(title, 0.15, { TextTransparency = 0 })
	unlock.TextTransparency = 1
	if setUnlock(level) then
		Theme.tween(unlock, 0.15, { TextTransparency = 0 })
	end
	scheduleFadeOut(HOLD - 0.1) -- restart the hold
end

local function playBeat(level: number)
	beatLevel = level
	if phase == "showing" then
		swapTitle(level)
		return
	end
	beatToken += 1
	local token = beatToken
	phase = "showing"

	-- Start state (also cleans up a beat that was still fading out: its
	-- tweens are stopped first, or they would keep writing over the new
	-- values, e.g. leave the rule invisible and the block 3 px too high).
	for _, tween in fadeTweens do
		tween:Cancel()
	end
	table.clear(fadeTweens)
	band.BackgroundTransparency = 1
	band.Visible = true
	block.Position = UDim2.new(0.5, 0, 0, BLOCK_Y)
	block.Visible = true
	eyebrow.TextTransparency = 1
	title.Text = titleText(level)
	title.TextTransparency = 1
	title.Position = UDim2.fromOffset(0, TITLE_Y + 6)
	rule.Size = UDim2.fromOffset(0, 1)
	rule.BackgroundTransparency = RULE_TRANSPARENCY
	unlock.TextTransparency = 1
	local hasUnlock = setUnlock(level)

	-- 0 s: the band and the contrast bump.
	Theme.tween(band, 0.3, { BackgroundTransparency = 0 })
	Theme.tween(grade, 0.2, { Contrast = 0.08, Saturation = -0.15 })
	later(0.05, token, function()
		Theme.tween(eyebrow, 0.25, { TextTransparency = 0 })
	end)
	later(0.1, token, function()
		Theme.tween(title, 0.4, {
			TextTransparency = 0,
			Position = UDim2.fromOffset(0, TITLE_Y),
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	end)
	-- The rule draws itself from its centre (AnchorPoint 0.5).
	later(0.15, token, function()
		Theme.tween(
			rule,
			0.5,
			{ Size = UDim2.fromOffset(RULE_WIDTH, 1) },
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out
		)
	end)
	if hasUnlock then
		later(0.4, token, function()
			if unlock.Visible then
				Theme.tween(unlock, 0.3, { TextTransparency = 0 })
			end
		end)
	end
	later(1, token, function()
		Theme.tween(
			grade,
			1.2,
			{ Contrast = 0, Saturation = 0 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.InOut
		)
	end)
	scheduleFadeOut(HOLD)
	-- No sound yet: Shared/Sounds has no "level up" note (a low, dry one,
	-- no fanfare) and SoundController only plays sounds placed in the world.
end

------------------------------------------------------------------------------
-- Waiting for the right moment
------------------------------------------------------------------------------

-- Knocked out, a menu open or in a duel (rounds + result): not the moment.
local function blocked(): boolean
	local character = player.Character
	local down = character ~= nil and character:GetAttribute("KnockedOut") == true
	local inDuel = player:GetAttribute("InDuel") == true
	return down or inDuel or MenuController.getOpen() ~= nil
end

local function requestBeat(level: number)
	if not blocked() then
		playBeat(level)
		return
	end
	-- Several level-ups while waiting → one beat, for the highest level.
	local alreadyWaiting = pendingLevel ~= nil
	pendingLevel = math.max(pendingLevel or 0, level)
	if alreadyWaiting then
		return
	end
	task.spawn(function()
		while blocked() do
			task.wait(0.1)
		end
		local waiting = pendingLevel
		pendingLevel = nil
		if waiting then
			playBeat(waiting)
		end
	end)
end

-- A beat on screen when the menu opens or the player is knocked out: it
-- stops (the HUD is hidden anyway) and plays again once that's over.
local function interruptIfBlocked()
	if phase == "idle" or not blocked() then
		return
	end
	beatToken += 1
	fadeToken += 1
	for _, tween in fadeTweens do
		tween:Cancel()
	end
	table.clear(fadeTweens)
	band.Visible = false
	block.Visible = false
	grade.Contrast = 0
	grade.Saturation = 0
	phase = "idle"
	local level = beatLevel
	if level then
		requestBeat(level)
	end
end

local function onLevelChanged()
	local value = player:GetAttribute("Level")
	if typeof(value) ~= "number" then
		return
	end
	local previous = lastLevel
	lastLevel = value
	-- First value (the save just loaded) or no rise: nothing to celebrate.
	if previous ~= nil and value > previous then
		requestBeat(value)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function LevelUpController.start()
	build()
	local value = player:GetAttribute("Level")
	lastLevel = if typeof(value) == "number" then value else nil
	player:GetAttributeChangedSignal("Level"):Connect(onLevelChanged)
	MenuController.onOpenChanged(interruptIfBlocked)
	game:GetService("RunService").Heartbeat:Connect(interruptIfBlocked) -- (KO, duel)
end

return LevelUpController
