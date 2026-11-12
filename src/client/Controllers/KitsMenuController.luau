--!strict
-- KitsMenuController: the KITS section of the menu (01 KITS, above SETTINGS).
--
--   ROSTER              STREET BRAWLER                       EQUIPPED
--   | STREET BRAWLER    Fights dirty and close. Hits hard...
--     EQUIPPED          MOVES                  STAMINA   COOLDOWN
--   BOXER               [1] BOTTLE SMASH            15        8 s
--   NOT AVAILABLE YET       Breaks a bottle...      — BROKEN BOTTLE
--                       ...
--                       AWAKENING                          LASTS
--                     | [G] STREET FURY                     10 s
--
-- Left: every kit (Shared/Kits). Right: the selected kit's moves, read
-- from its data (so the numbers are always the real ones), each with its
-- Street Fury version under the cooldown (the red dash = "fury version").
-- EQUIP asks the server (Remotes.EquipKit); the saved profile says which
-- one is equipped (PlayerDataController).
--
-- Kits you have to earn (KitDef.unlockLevel / price) go through these
-- states, worked out from the save (level from its total XP, coins, owned
-- kits) — the server checks everything again when you buy:
--   Locked     level too low       roster "LOCKED · LEVEL 10"     detail "UNLOCKS AT LEVEL 10"
--   Buyable    enough coins        roster "500 COINS"             detail "— BUY · 500"
--   Short      not enough coins    roster "NEED 160 MORE COINS"   detail "— BUY · 500" (disabled)
--   Owned      bought              roster "AVAILABLE"             detail "— EQUIP"
-- BUY takes two presses (the word turns to CONFIRM for 3 s) and then asks
-- the server (Remotes.BuyKit). The coin count (the wallet) sits top right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kits = require(ReplicatedStorage.Shared.Kits)
local ProgressionCurve = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)
local ProfileMenuController = require(script.Parent.ProfileMenuController)

local player = Players.LocalPlayer
local formatNumber = ProfileMenuController.formatNumber

local C = Theme.Colors
-- The detail column starts at x 200 of the content. Its canvas starts a bit
-- before (16 px left for the red rail, 8 px up for the kit name), with the
-- content inset by the same amount, so nothing gets cut.
local DETAIL_INSET = Vector2.new(16, 8)
local DETAIL_X = 200 - DETAIL_INSET.X
local DETAIL_Y = -DETAIL_INSET.Y

-- Second press on BUY must come within this many seconds of the first.
local CONFIRM_SECONDS = 3
-- No new save showing the kit after this long = the server refused.
local REFUSED_AFTER = 2.5

-- Where a kit stands for this player (see the table at the top).
type KitState = "Unavailable" | "Locked" | "Buyable" | "Short" | "Owned" | "Equipped"

local KitsMenuController = {}

local selectedId: string = Kits.DEFAULT
local equippedId: string = Kits.DEFAULT
local shownState: KitState? = nil -- the state the detail was drawn for
local actionGroup: CanvasGroup? = nil -- the top-right action (fades on a change)
local swapToken = 0
local wallet: ProfileMenuController.Wallet? = nil
local subtitleLabel: TextLabel? = nil

type RosterItem = {
	kit: Kits.KitDef,
	button: TextButton,
	name: TextLabel,
	status: TextLabel,
}

local rosterItems: { RosterItem } = {}
local rosterMarker: Frame
local detail: CanvasGroup -- fades / slides as one when switching kits
local body: Frame -- its content (inset: the canvas cuts what sticks out)
local renderDetail: (animate: boolean) -> ()
local refreshRoster: (animate: boolean?) -> () -- (both defined further down)

------------------------------------------------------------------------------
-- Kit states (from the save)
------------------------------------------------------------------------------

local function playerLevel(): number
	local profile = PlayerDataController.get()
	if profile then
		local level = ProgressionCurve.levelFromXp(profile.xp)
		return level
	end
	local attribute = player:GetAttribute("Level")
	return if typeof(attribute) == "number" then attribute else 1
end

local function playerCoins(): number
	local profile = PlayerDataController.get()
	return if profile then profile.coins else 0
end

local function ownsKit(kit: Kits.KitDef): boolean
	local profile = PlayerDataController.get()
	if profile then
		return Kits.owns(profile, kit)
	end
	-- Save not here yet: only the free kits.
	return kit.price == nil and kit.unlockLevel == nil
end

local function kitState(kit: Kits.KitDef): KitState
	if not kit.available then
		return "Unavailable"
	elseif kit.id == equippedId then
		return "Equipped"
	elseif ownsKit(kit) then
		return "Owned"
	elseif playerLevel() < (kit.unlockLevel or 1) then
		return "Locked"
	elseif playerCoins() >= (kit.price or 0) then
		return "Buyable"
	end
	return "Short"
end

-- The small line under a kit's name in the roster.
local function statusText(kit: Kits.KitDef): string
	local state = kitState(kit)
	if state == "Unavailable" then
		return "NOT AVAILABLE YET"
	elseif state == "Equipped" then
		return "EQUIPPED"
	elseif state == "Owned" then
		return "AVAILABLE"
	elseif state == "Locked" then
		return `LOCKED · LEVEL {kit.unlockLevel or 1}`
	elseif state == "Buyable" then
		return `{formatNumber(kit.price or 0)} COINS`
	end
	return `NEED {formatNumber((kit.price or 0) - playerCoins())} MORE COINS`
end

-- "FIGHTING STYLES · 1 OF 3 AVAILABLE" (kits you can actually equip).
local function subtitle(): string
	local owned = 0
	for _, kit in Kits.list() do
		if kit.available and ownsKit(kit) then
			owned += 1
		end
	end
	return `FIGHTING STYLES · {owned} OF {#Kits.list()} AVAILABLE`
end

------------------------------------------------------------------------------
-- Small pieces
------------------------------------------------------------------------------

local function caption(text: string, props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		TextSize = 10,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = Theme.track(text, "three"),
	}
	for key, value in props do
		base[key] = value
	end
	return Theme.text(base) :: TextLabel
end

local function hairline(parent: Instance, y: UDim, transparency: number)
	Theme.make("Frame", {
		Name = "Hairline",
		Position = UDim2.new(UDim.new(0, 0), y),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = transparency,
		Parent = parent,
	})
end

-- A small outlined (or filled) key: "1", "G". `dim`: a locked kit (one step quieter).
local function keyCap(parent: Instance, text: string, filled: boolean, dim: boolean?): Frame
	local frame = Theme.make("Frame", {
		Name = "KeyCap",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(22, 18),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = if filled then 0 else 1,
		Parent = parent,
	}) :: Frame
	if not filled then
		Theme.make("UIStroke", {
			Thickness = 1,
			Color = C.Ink,
			Transparency = if dim then 0.78 else 0.45,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = frame,
		})
	end
	Theme.text({
		Position = UDim2.fromOffset(-1, 0), -- (the digit sat 1 px right of centre)
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Fonts.NumberMedium,
		TextSize = 10,
		TextColor3 = if filled then C.Scrim elseif dim then C.Ink2 else C.Ink,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
		Parent = frame,
	})
	return frame
end

-- "8 s" right-aligned: the number, then a small unit.
local function seconds(parent: Instance, value: number)
	Theme.text({
		Name = "Seconds",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(40, 13),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = tostring(value),
		Parent = parent,
	})
	Theme.text({
		Name = "Unit",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 8),
		Size = UDim2.fromOffset(8, 11),
		FontFace = Theme.Fonts.Number,
		TextSize = 9,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "s",
		Parent = parent,
	})
end

------------------------------------------------------------------------------
-- Detail (right column)
------------------------------------------------------------------------------

local function moveRow(
	parent: Instance,
	index: number,
	move: Kits.MoveDef,
	fury: Kits.MoveDef?,
	dim: boolean
)
	local row = Theme.make("Frame", {
		Name = `Move{index}`,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	hairline(row, UDim.new(1, -1), 0.93)
	keyCap(row, tostring(index), false, dim)
	Theme.text({
		Name = "Name",
		Position = UDim2.fromOffset(34, 6),
		Size = UDim2.fromOffset(200, 13),
		TextColor3 = if dim then C.Ink2 else C.Ink,
		TextStrokeTransparency = 1,
		Text = Theme.track(move.name, "four"),
		Parent = row,
	})
	local sentence = Theme.text({
		Name = "Sentence",
		Position = UDim2.fromOffset(34, 22),
		Size = UDim2.fromOffset(230, 14),
		FontFace = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		Text = move.description,
		Parent = row,
	}) :: TextLabel
	Theme.text({
		Name = "Stamina",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -82, 0, 6),
		Size = UDim2.fromOffset(64, 13),
		FontFace = Theme.Fonts.Number,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = tostring(move.stamina),
		Parent = row,
	})
	seconds(row, move.cooldown)
	if fury then
		-- "— BROKEN BOTTLE": what this key becomes in Street Fury.
		local furyLine = Theme.make("Frame", {
			Name = "FuryVersion",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 24),
			Size = UDim2.fromOffset(0, 11),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Parent = row,
		}, {
			Theme.make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 7),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Theme.make("Frame", {
				Name = "Dash",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(8, 1),
				BackgroundColor3 = C.BloodHi,
			}),
			caption(fury.name, {
				Name = "Label",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 11),
				TextSize = 9,
				TextColor3 = C.Ink2,
				TextTransparency = 0.2,
			}),
		}) :: Frame
		-- Same line as the sentence: a long sentence (bold, x1.12) would run
		-- under it ("Under the chin. Lifts them off the ground." reaches the
		-- "— RISING UPPERCUT" line by ~18 px), so that sentence alone is
		-- set a size smaller until it ends 8 px before the line.
		local function fitSentence()
			local room = furyLine.AbsolutePosition.X - 8 - sentence.AbsolutePosition.X
			local width = sentence.TextBounds.X
			if room > 0 and width > room and sentence.TextSize > 10 then
				sentence.TextSize = math.max(10, math.floor(sentence.TextSize * room / width))
			end
		end
		furyLine:GetPropertyChangedSignal("AbsolutePosition"):Connect(fitSentence)
		sentence:GetPropertyChangedSignal("TextBounds"):Connect(fitSentence)
		fitSentence()
	end
	return row
end

-- Two column headers on the right of a section head ("COST", "COOLDOWN").
local function sectionHead(parent: Instance, y: number, title: string, columns: { string })
	local head = Theme.make("Frame", {
		Name = `{title}Head`,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	caption(title, { Size = UDim2.new(1, 0, 0, 12), Parent = head })
	local rightEdge = { 0, -82 }
	local widths = { 82, 64 }
	for position, text in columns do
		caption(text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, rightEdge[position], 0, 4),
			Size = UDim2.fromOffset(widths[position], 11),
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = head,
		})
	end
	hairline(head, UDim.new(1, 0), 0.9)
end

-- "UNLOCKS AT LEVEL 10": said in words (no padlock), not a button.
local function lockedLabel(parent: Instance, kit: Kits.KitDef)
	Theme.text({
		Name = "LockedLabel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = Theme.track(`UNLOCKS AT LEVEL {kit.unlockLevel or 1}`, "four"),
		Parent = parent,
	})
end

-- "— BUY · 500": the same "line + word" button as MENU / EQUIP. Two presses:
-- the first turns the word into CONFIRM for a few seconds, the second asks
-- the server (Remotes.BuyKit). `enabled` = false when coins are short.
local function buyButton(parent: Instance, kit: Kits.KitDef, enabled: boolean)
	local idle = if enabled then 0.15 else 0.6
	local button = Theme.make("TextButton", {
		Name = "BuyButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Active = enabled,
		Text = "",
		Parent = parent,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: TextButton
	local line = Theme.make("Frame", {
		Name = "Line",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(18, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = idle,
		Parent = button,
	}) :: Frame
	local group = Theme.make("Frame", {
		Name = "Label",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		BackgroundTransparency = 1,
		Parent = button,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local word = Theme.text({
		Name = "Word",
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		TextTransparency = idle,
		TextStrokeTransparency = 1,
		Text = Theme.track("BUY ·", "four"),
		Parent = group,
	}) :: TextLabel
	local price = Theme.text({
		Name = "Price",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		FontFace = Theme.Fonts.Number,
		TextTransparency = idle,
		TextStrokeTransparency = 1,
		Text = formatNumber(kit.price or 0),
		Parent = group,
	}) :: TextLabel
	if not enabled then
		return -- disabled: no hover, no press
	end

	local hovered = false
	local confirmUntil = 0 -- os.clock() before which a press buys
	local pending = false -- asked the server, waiting for the save

	local function brightness(): number
		return if hovered then 0 else 0.15
	end
	-- Crossfades the word ("BUY ·" ↔ "CONFIRM ·") in 0.1 s.
	local function setWord(text: string)
		Theme.tween(word, 0.05, { TextTransparency = 1 })
		task.delay(0.05, function()
			word.Text = Theme.track(text, "four")
			Theme.tween(word, 0.05, { TextTransparency = brightness() })
		end)
	end

	button.MouseEnter:Connect(function()
		hovered = true
		Theme.tween(line, 0.15, { Size = UDim2.fromOffset(28, 1), BackgroundTransparency = 0 })
		Theme.tween(word, 0.15, { TextTransparency = 0 })
		Theme.tween(price, 0.15, { TextTransparency = 0 })
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		Theme.tween(line, 0.15, { Size = UDim2.fromOffset(18, 1), BackgroundTransparency = 0.15 })
		Theme.tween(word, 0.15, { TextTransparency = 0.15 })
		Theme.tween(price, 0.15, { TextTransparency = 0.15 })
	end)
	button.Activated:Connect(function()
		if pending then
			return
		end
		local now = os.clock()
		if now < confirmUntil then
			-- Second press: buy. The server checks level, price and coins.
			confirmUntil = 0
			pending = true
			Remotes.BuyKit:FireServer(kit.id)
			-- Bought: the new save replaces this button (EQUIP). Still here
			-- after a moment = refused: the price flashes red, back to BUY.
			task.delay(REFUSED_AFTER, function()
				if button.Parent == nil then
					return
				end
				pending = false
				price.TextColor3 = C.BloodHi
				Theme.tween(price, 0.4, { TextColor3 = C.Ink })
				setWord("BUY ·")
			end)
			return
		end
		-- First press: ask to confirm.
		confirmUntil = now + CONFIRM_SECONDS
		local stamp = confirmUntil
		setWord("CONFIRM ·")
		task.delay(CONFIRM_SECONDS, function()
			if confirmUntil == stamp and not pending and button.Parent ~= nil then
				confirmUntil = 0
				setWord("BUY ·")
			end
		end)
	end)
end

-- The EQUIPPED mark (underlined) at the top right.
local function equippedMark(parent: Instance)
	local mark = Theme.text({
		Name = "Equipped",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		TextStrokeTransparency = 1,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = Theme.track("EQUIPPED", "four"),
		Parent = parent,
	}) :: TextLabel
	local underline = Theme.make("Frame", {
		Name = "Underline",
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = C.Ink,
		Parent = mark,
	})
	task.defer(function()
		Theme.tween(
			underline,
			0.18,
			{ Size = UDim2.fromOffset(math.max(mark.TextBounds.X - 3, 10), 2) },
			Enum.EasingStyle.Quart
		)
	end)
end

-- EQUIP: the same "line + word" button as MENU / CLOSE (no boxes).
local function equipButton(parent: Instance, kit: Kits.KitDef)
	local button = Theme.make("TextButton", {
		Name = "EquipButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		Size = UDim2.fromOffset(90, 14),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}) :: TextButton
	local line = Theme.make("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -62, 0.5, 0),
		Size = UDim2.fromOffset(18, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.15,
		Parent = button,
	}) :: Frame
	local word = Theme.text({
		Name = "Label",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 52, 1, 0),
		TextTransparency = 0.15,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = Theme.track("EQUIP", "four"),
		Parent = button,
	}) :: TextLabel
	button.MouseEnter:Connect(function()
		Theme.tween(line, 0.15, { Size = UDim2.fromOffset(28, 1) })
		Theme.tween(word, 0.15, { TextTransparency = 0 })
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(line, 0.15, { Size = UDim2.fromOffset(18, 1) })
		Theme.tween(word, 0.15, { TextTransparency = 0.15 })
	end)
	button.Activated:Connect(function()
		Theme.tween(
			word,
			0.1,
			{ TextTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		Theme.tween(
			line,
			0.1,
			{ Size = UDim2.fromOffset(0, 1) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		Remotes.EquipKit:FireServer(kit.id)
		-- Shown at once; the saved profile confirms it (or puts it back).
		-- If the server doesn't save it (refused, too fast...), the saved
		-- profile wins again after a moment.
		task.delay(2, function()
			local profile = PlayerDataController.get()
			if profile and profile.equippedKit ~= equippedId then
				equippedId = profile.equippedKit
				refreshRoster()
				renderDetail(false)
			end
		end)
		task.delay(0.1, function()
			equippedId = kit.id
			renderDetail(false)
			refreshRoster(true)
		end)
	end)
end

-- The action at the top right of the detail, for this kit's state.
local function actionArea(parent: Instance, kit: Kits.KitDef, state: KitState)
	if state == "Equipped" then
		equippedMark(parent)
	elseif state == "Owned" then
		equipButton(parent, kit)
	elseif state == "Locked" then
		lockedLabel(parent, kit)
	elseif state == "Buyable" or state == "Short" then
		buyButton(parent, kit, state == "Buyable")
	end
	-- "Unavailable": nothing.
end

-- `fadeAction`: the top-right action fades in (its state just changed).
local function fillDetail(kit: Kits.KitDef, fadeAction: boolean?)
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	local state: KitState = kitState(kit)
	shownState = state
	-- A locked kit still shows everything (what you are working towards),
	-- one step quieter: key caps and move names dimmed.
	local dim = state == "Locked"
	Theme.text({
		Name = "KitName",
		Position = UDim2.fromOffset(0, -4),
		Size = UDim2.fromOffset(280, 30),
		FontFace = Theme.Fonts.Display,
		TextSize = 26,
		TextStrokeTransparency = 1,
		Text = Theme.track(kit.name, "thin"),
		Parent = body,
	})
	-- The action lives in its own layer so it can fade on its own.
	local group = Theme.make("CanvasGroup", {
		Name = "Action",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = body,
	}) :: CanvasGroup
	actionGroup = group
	actionArea(group, kit, state)
	if fadeAction then
		group.GroupTransparency = 1
		Theme.tween(group, 0.15, { GroupTransparency = 0 })
	end
	Theme.text({
		Name = "Desc",
		Position = UDim2.fromOffset(0, 36),
		-- Room for a second line (a long description no longer fits on one
		-- at the bigger size, and the canvas would cut it).
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = Theme.Fonts.Body,
		TextSize = 15,
		TextStrokeTransparency = 1,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = kit.description,
		Parent = body,
	})
	if #kit.moves == 0 then
		caption("THIS FIGHTING STYLE IS NOT AVAILABLE YET", {
			Position = UDim2.fromOffset(0, 84),
			Size = UDim2.new(1, 0, 0, 12),
			Parent = body,
		})
		return
	end

	sectionHead(body, 80, "MOVES", { "COOLDOWN", "STAMINA" })
	local list = Theme.make("Frame", {
		Name = "Moves",
		Position = UDim2.fromOffset(0, 99),
		Size = UDim2.new(1, 0, 0, 4 * 42),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Theme.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local awakening = kit.awakening
	for index, move in kit.moves do
		moveRow(list, index, move, if awakening then awakening.moves[index] else nil, dim)
	end

	if awakening then
		sectionHead(body, 291, "AWAKENING", { "LASTS" })
		local row = Theme.make("Frame", {
			Name = "AwakeningRow",
			Position = UDim2.fromOffset(0, 309),
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundTransparency = 1,
			Parent = body,
		})
		Theme.make("Frame", {
			Name = "Rail",
			Position = UDim2.fromOffset(-14, 6),
			Size = UDim2.fromOffset(2, 18),
			BackgroundColor3 = C.BloodHi,
			Parent = row,
		})
		keyCap(row, "G", false, dim) -- the red rail is what marks it
		Theme.text({
			Name = "Name",
			Position = UDim2.fromOffset(34, 6),
			Size = UDim2.fromOffset(200, 13),
			TextColor3 = if dim then C.Ink2 else C.Ink,
			TextStrokeTransparency = 1,
			Text = Theme.track(awakening.name, "four"),
			Parent = row,
		})
		Theme.text({
			Name = "Sentence",
			Position = UDim2.fromOffset(34, 22),
			Size = UDim2.new(1, -34, 0, 40), -- two lines at most (the canvas ends at 380)
			FontFace = Theme.Fonts.Body,
			TextSize = 12,
			TextColor3 = C.Ink2,
			TextStrokeTransparency = 1,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LineHeight = 1.33,
			Text = awakening.description,
			Parent = row,
		})
		seconds(row, awakening.duration)
	end
end

-- Shows the selected kit. `animate`: the old content slides out, the new in.
renderDetail = function(animate: boolean)
	local kit = Kits.get(selectedId)
	if kit == nil then
		return
	end
	swapToken += 1 -- cancels a pending action swap (swapAction)
	local selectedKit: Kits.KitDef = kit
	if not animate then
		fillDetail(selectedKit)
		return
	end
	Theme.tween(
		detail,
		0.1,
		{ GroupTransparency = 1, Position = UDim2.fromOffset(DETAIL_X - 6, DETAIL_Y) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(0.1, function()
		fillDetail(selectedKit)
		detail.Position = UDim2.fromOffset(DETAIL_X + 8, DETAIL_Y)
		Theme.tween(
			detail,
			0.2,
			{ GroupTransparency = 0, Position = UDim2.fromOffset(DETAIL_X, DETAIL_Y) },
			Enum.EasingStyle.Quart
		)
	end)
end

-- The selected kit's state changed (bought, level reached, coins earned...):
-- the old action fades out (0.1 s), the new one fades in (0.15 s).
local function swapAction()
	local kit = Kits.get(selectedId)
	if kit == nil then
		return
	end
	local selectedKit: Kits.KitDef = kit
	swapToken += 1
	local token = swapToken
	local old = actionGroup
	if old then
		Theme.tween(
			old,
			0.1,
			{ GroupTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
	end
	task.delay(if old then 0.1 else 0, function()
		if token == swapToken and selectedId == selectedKit.id then
			fillDetail(selectedKit, true)
		end
	end)
end

------------------------------------------------------------------------------
-- Roster (left column)
------------------------------------------------------------------------------

-- The colours of a roster item right now: name colour, status colour, and
-- transparency. Only "not available yet" is dimmed; locked / short kits use
-- the normal idle colours.
local function rosterStyle(item: RosterItem): (Color3, Color3, number)
	local selected = item.kit.id == selectedId
	local dimmed = if item.kit.available then 0 else 0.4
	return if selected then C.Ink else C.Ink3,
		if selected then C.Ink2 else C.Ink3,
		if selected then 0 else dimmed
end

-- `animate`: a status line whose text changed crossfades (0.15 s).
refreshRoster = function(animate: boolean?)
	for _, item in rosterItems do
		local nameColor, statusColor, transparency = rosterStyle(item)
		Theme.tween(item.name, Theme.FAST, {
			TextColor3 = nameColor,
			TextTransparency = transparency,
		})
		local text = Theme.track(statusText(item.kit), "three")
		local status = item.status
		if animate and status.Text ~= text then
			Theme.tween(status, 0.075, { TextTransparency = 1 })
			task.delay(0.075, function()
				-- Read everything again: the selection or the state may have
				-- changed during the fade.
				local _, newColor, newTransparency = rosterStyle(item)
				status.Text = Theme.track(statusText(item.kit), "three")
				Theme.tween(status, 0.075, {
					TextColor3 = newColor,
					TextTransparency = newTransparency,
				})
			end)
		else
			status.Text = text
			Theme.tween(status, Theme.FAST, {
				TextColor3 = statusColor,
				TextTransparency = transparency,
			})
		end
		if item.kit.id == selectedId then
			rosterMarker.Parent = item.button
			rosterMarker.Position = UDim2.fromOffset(-14, 12)
		end
	end
end

local function selectKit(kitId: string)
	if kitId == selectedId then
		return
	end
	selectedId = kitId
	refreshRoster()
	renderDetail(true)
end

local built = false

local function build(content: Frame)
	-- Header (the panel around the content): the wallet top right, and the
	-- subtitle we keep up to date ("1 OF 3 AVAILABLE").
	local panel = content.Parent :: Instance
	local newWallet = ProfileMenuController.createWallet(panel)
	newWallet.set(playerCoins(), false)
	wallet = newWallet
	local label = panel:FindFirstChild("Subtitle")
	if label and label:IsA("TextLabel") then
		subtitleLabel = label
		label.Text = Theme.track(subtitle(), "three")
	end

	local roster = Theme.make("Frame", {
		Name = "Roster",
		Size = UDim2.fromOffset(150, 200),
		BackgroundTransparency = 1,
		Parent = content,
	})
	caption("ROSTER", { Size = UDim2.new(1, 0, 0, 12), Parent = roster })
	local items = Theme.make("Frame", {
		Name = "Items",
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 1, -16),
		BackgroundTransparency = 1,
		Parent = roster,
	}, {
		Theme.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	rosterMarker = Theme.make("Frame", {
		Name = "RosterMarker",
		Size = UDim2.fromOffset(2, 12),
		BackgroundColor3 = C.Ink,
	})
	for order, kit in Kits.list() do
		local button = Theme.make("TextButton", {
			Name = kit.id,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Parent = items,
		}) :: TextButton
		local name = Theme.text({
			Name = "Name",
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 13,
			TextStrokeTransparency = 1,
			Text = Theme.track(kit.name, "four"),
			Parent = button,
		}) :: TextLabel
		local status = caption(statusText(kit), {
			Name = "Status",
			Position = UDim2.fromOffset(0, 31),
			Size = UDim2.new(1, 0, 0, 11),
			TextSize = 9,
			Parent = button,
		})
		local item: RosterItem = { kit = kit, button = button, name = name, status = status }
		table.insert(rosterItems, item)
		button.MouseEnter:Connect(function()
			if kit.id ~= selectedId then
				Theme.tween(name, 0.1, { TextColor3 = C.Ink2 })
			end
		end)
		button.MouseLeave:Connect(function()
			if kit.id ~= selectedId then
				Theme.tween(name, 0.1, { TextColor3 = C.Ink3 })
			end
		end)
		button.Activated:Connect(function()
			selectKit(kit.id)
		end)
	end

	Theme.make("Frame", {
		Name = "Divider2",
		Position = UDim2.fromOffset(170, 0),
		Size = UDim2.fromOffset(1, 360),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.88,
		Parent = content,
	})
	detail = Theme.make("CanvasGroup", {
		Name = "Detail",
		Position = UDim2.fromOffset(DETAIL_X, DETAIL_Y),
		Size = UDim2.fromOffset(360 + DETAIL_INSET.X + 2, 380 + DETAIL_INSET.Y),
		BackgroundTransparency = 1,
		Parent = content,
	})
	body = Theme.make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(DETAIL_INSET.X, DETAIL_INSET.Y),
		Size = UDim2.fromOffset(360, 380),
		BackgroundTransparency = 1,
		Parent = detail,
	})
	built = true
	refreshRoster()
	renderDetail(false)
end

-- A new save arrived (coins, XP, a kit bought, equipped...): update the
-- wallet, the subtitle, the roster lines and, if its state changed, the
-- selected kit's action.
local function onDataChanged()
	if not built then
		return
	end
	local currentWallet = wallet
	if currentWallet then
		currentWallet.set(playerCoins(), true)
	end
	local label = subtitleLabel
	if label then
		label.Text = Theme.track(subtitle(), "three")
	end
	refreshRoster(true)
	local kit = Kits.get(selectedId)
	if kit and kitState(kit) ~= shownState then
		swapAction()
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function KitsMenuController.start()
	MenuController.register({
		id = "Kits",
		label = "KITS",
		subtitle = subtitle(),
		order = 10, -- first in the list, above PROFILE and SETTINGS
		size = Vector2.new(560, 480),
		scrimWidth = 1100,
		build = build,
	})
	-- The saved profile says which kit is equipped, which kits are owned,
	-- how many coins and how much XP we have.
	PlayerDataController.onChanged(function(profile)
		local id = profile.equippedKit
		if typeof(id) == "string" then
			equippedId = id
		end
		onDataChanged()
	end)
	-- The level can also arrive as the "Level" attribute (before the save).
	player:GetAttributeChangedSignal("Level"):Connect(onDataChanged)
end

return KitsMenuController
