--!strict
-- ShopMenuController: the SHOP section of the menu (between PROFILE and
-- SETTINGS). Cosmetics bought with coins (step 10): nothing here changes a
-- fight.
--
--   SHOP                                                       820
--   COSMETICS · 4 OF 17 OWNED                                COINS
--   ──────────────────────────────────────────────────────────────
--   CATEGORY            TITLES
--   | TITLES            Shown under your name, on your name tag.
--     ROOKIE            CATALOG
--   OUTFITS             ROOKIE                           EQUIPPED
--   NONE EQUIPPED       Everybody starts somewhere.      ‾‾‾‾‾‾‾‾
--   KILL EFFECTS        BARE KNUCKLE                       — EQUIP
--   ...                 No gloves, no rules.
--                       BACK ALLEY                    — BUY · 250
--                       Grew up fighting behind the bar.
--                       HEAVY HANDS                      LEVEL 10
--                       One clean shot is enough.
--
-- Left: the 4 categories (like the KITS roster: a small marker on the
-- selected one, the equipped item's name under each). Right: every item of
-- the category (Shared/Cosmetics), one row each, with its state on the right:
--   Locked     level too low        "LEVEL 10"           (words, no padlock)
--   Buyable    enough coins         "— BUY · 250"        (two presses: CONFIRM)
--   Short      not enough coins     "NEED 120 MORE"
--   Owned      bought (or free)     "— EQUIP"
--   Equipped   the one you wear     "EQUIPPED" underlined. On a title or a
--              kill effect, clicking it takes it off (hover reads TAKE OFF).
-- Outfit rows show two small colour squares (top above, trousers below).
-- Emote rows add a hint with the emote key ("PRESS B").
--
-- Everything is worked out from the save (PlayerDataController: coins, XP →
-- level, ownedCosmetics, equipped). The SERVER checks everything again
-- (Server/Systems/Shop): Remotes.BuyCosmetic(id), Remotes.EquipCosmetic
-- (category, id or "" = take it off). The wallet (coins) sits top right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ProgressionCurve = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)
local ProfileMenuController = require(script.Parent.ProfileMenuController)

local player = Players.LocalPlayer
local formatNumber = ProfileMenuController.formatNumber

local C = Theme.Colors

-- Same columns as the KITS section: the detail starts at x 200 of the
-- content; its canvas starts a bit before (and the content is inset by the
-- same amount) so nothing sticking out gets cut.
local DETAIL_INSET = Vector2.new(16, 8)
local DETAIL_X = 200 - DETAIL_INSET.X
local DETAIL_Y = -DETAIL_INSET.Y
local DETAIL_SIZE = Vector2.new(360, 380)

local ROW_HEIGHT = 42 -- one item (like a kit's move row)
local ROWS_TOP = 99 -- first row, under the CATALOG head
local OUTFIT_INDENT = 26 -- outfit rows: room for the two colour squares

-- Second press on BUY must come within this many seconds of the first.
local CONFIRM_SECONDS = 3
-- No new save showing the item after this long = the server refused.
local REFUSED_AFTER = 2.5
-- After EQUIP / TAKE OFF we show the change at once; if the save still
-- says otherwise after this long, the save wins again (refused, too fast...).
local EQUIP_SETTLE = 2

-- The emote key, written as on the keyboard ("B").
local EMOTE_KEY: string = Config.Controls.EMOTE.Name

-- Where an item stands for this player (see the table at the top).
type ItemState = "Locked" | "Buyable" | "Short" | "Owned" | "Equipped"

type CategoryInfo = {
	id: Cosmetics.Category,
	label: string, -- roster name and detail title
	description: string, -- one line under the title (≤ 50 characters)
	canTakeOff: boolean, -- clicking EQUIPPED takes it off ("" = none)
}

local CATEGORIES: { CategoryInfo } = {
	{
		id = "Title",
		label = "TITLES",
		description = "Shown under your name, on your name tag.",
		canTakeOff = true,
	},
	{
		id = "Outfit",
		label = "OUTFITS",
		description = "The colour of your top and trousers.",
		canTakeOff = true, -- (the avatar's own clothes come back next life)
	},
	{
		id = "KillEffect",
		label = "KILL EFFECTS",
		description = "A short effect when you finish someone.",
		canTakeOff = true,
	},
	{
		id = "Emote",
		label = "EMOTES",
		description = `A gesture between fights. Press {EMOTE_KEY} to play it.`,
		canTakeOff = false,
	},
}

local ShopMenuController = {}

-- One item row on the right.
type Row = {
	item: Cosmetics.Item,
	frame: Frame,
	name: TextLabel,
	hint: TextLabel?, -- "PRESS B" (emotes only)
	action: CanvasGroup?, -- the state on the right (fades on a change)
	key: string, -- the state the action was drawn for (see stateKey)
	token: number, -- cancels an action swap that is no longer wanted
}

-- One category on the left.
type RosterItem = {
	info: CategoryInfo,
	button: TextButton,
	name: TextLabel,
	status: TextLabel,
}

local selected: CategoryInfo = CATEGORIES[1]
local rows: { Row } = {}
local rosterItems: { RosterItem } = {}
local rosterMarker: Frame
local detail: CanvasGroup -- fades / slides as one when switching category
local body: Frame -- its content (inset: the canvas cuts what sticks out)
local wallet: ProfileMenuController.Wallet? = nil
local walletCoins = 0 -- what the wallet shows (so it only counts on a change)
local subtitleLabel: TextLabel? = nil
local built = false
local refreshAll: (animate: boolean) -> () -- (defined further down)

-- What we just asked the server to equip, per category: shown at once,
-- until `untilTime` (os.clock) — then the save is the truth again.
local pendingEquip: { [Cosmetics.Category]: { id: string, untilTime: number } } = {}

------------------------------------------------------------------------------
-- Item states (from the save)
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

-- The id saved as equipped in `category` ("" = none).
local function savedEquipped(profile: Types.ProfileSnapshot, category: Cosmetics.Category): string
	local equipped = profile.equipped
	local id = if category == "Title"
		then equipped.Title
		elseif category == "Outfit" then equipped.Outfit
		elseif category == "KillEffect" then equipped.KillEffect
		else equipped.Emote
	return id or ""
end

-- The id equipped in `category` as we show it (our own request first).
local function equippedId(category: Cosmetics.Category): string
	local pending = pendingEquip[category]
	if pending and os.clock() < pending.untilTime then
		return pending.id
	end
	local profile = PlayerDataController.get()
	return if profile then savedEquipped(profile, category) else ""
end

local function owns(item: Cosmetics.Item): boolean
	local profile = PlayerDataController.get()
	if profile then
		return Cosmetics.owns(profile, item)
	end
	-- Save not here yet: only the free items.
	return item.price == 0 and item.unlockLevel == nil
end

local function itemState(item: Cosmetics.Item): ItemState
	if owns(item) then
		return if equippedId(item.category) == item.id then "Equipped" else "Owned"
	elseif playerLevel() < (item.unlockLevel or 1) then
		return "Locked"
	elseif playerCoins() >= item.price then
		return "Buyable"
	end
	return "Short"
end

-- The state plus the number it shows: when this text changes, the action
-- on the right is redrawn ("NEED 120 MORE" → "NEED 40 MORE" too).
local function stateKey(item: Cosmetics.Item): string
	local state = itemState(item)
	if state == "Short" then
		return `Short{item.price - playerCoins()}`
	end
	return state
end

-- Can the item equipped in `category` be taken off (EQUIPPED is a button)?
local function canTakeOff(category: Cosmetics.Category): boolean
	for _, info in CATEGORIES do
		if info.id == category then
			return info.canTakeOff
		end
	end
	return false
end

-- The items of one category, in catalog order.
local function itemsOf(category: Cosmetics.Category): { Cosmetics.Item }
	local list = {}
	for _, item in Cosmetics.ITEMS do
		if item.category == category then
			table.insert(list, item)
		end
	end
	return list
end

-- The small line under a category in the roster: what is equipped.
local function rosterStatus(info: CategoryInfo): string
	local item = Cosmetics.get(equippedId(info.id))
	if item and item.category == info.id and owns(item) then
		return item.name
	end
	return "NONE EQUIPPED"
end

-- "COSMETICS · 4 OF 17 OWNED".
local function subtitle(): string
	local owned = 0
	for _, item in Cosmetics.ITEMS do
		if owns(item) then
			owned += 1
		end
	end
	return `COSMETICS · {owned} OF {#Cosmetics.ITEMS} OWNED`
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

-- A section head: label on the left, a faint hairline under it.
local function sectionHead(parent: Instance, y: number, title: string)
	local head = Theme.make("Frame", {
		Name = `{title}Head`,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	caption(title, { Size = UDim2.new(1, 0, 0, 12), Parent = head })
	hairline(head, UDim.new(1, 0), 0.9)
end

-- A small square of colour (outfit rows), with a faint outline so a black
-- top still shows on the dark backdrop. Square corners, like everything.
local function swatch(parent: Instance, name: string, color: Color3, y: number)
	Theme.make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = color,
		Parent = parent,
	}, {
		Theme.make("UIStroke", {
			Thickness = 1,
			Color = C.Ink,
			Transparency = 0.78,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

------------------------------------------------------------------------------
-- The actions (right side of a row)
------------------------------------------------------------------------------

-- "LEVEL 10" / "NEED 120 MORE": said in words, not a button.
local function stateLabel(parent: Instance, text: string)
	Theme.text({
		Name = "StateLabel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = Theme.track(text, "four"),
		Parent = parent,
	})
end

-- "— BUY · 250": the same "line + word" button as MENU / EQUIP. Two presses:
-- the first turns the word into CONFIRM for a few seconds, the second asks
-- the server (Remotes.BuyCosmetic).
local function buyButton(parent: Instance, item: Cosmetics.Item)
	local button = Theme.make("TextButton", {
		Name = "BuyButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
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
		BackgroundTransparency = 0.15,
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
		TextTransparency = 0.15,
		TextStrokeTransparency = 1,
		Text = Theme.track("BUY ·", "four"),
		Parent = group,
	}) :: TextLabel
	local price = Theme.text({
		Name = "Price",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		-- (A free item that needs a level first reads "BUY · FREE".)
		FontFace = if item.price == 0 then Theme.Fonts.Label else Theme.Fonts.Number,
		TextTransparency = 0.15,
		TextStrokeTransparency = 1,
		Text = if item.price == 0 then Theme.track("FREE", "four") else formatNumber(item.price),
		Parent = group,
	}) :: TextLabel

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
			Remotes.BuyCosmetic:FireServer(item.id)
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

-- Asks the server to equip `itemId` in `category` ("" = take it off) and
-- shows it at once. If the save doesn't follow, it wins again after
-- EQUIP_SETTLE seconds.
local function requestEquip(category: Cosmetics.Category, itemId: string)
	pendingEquip[category] = { id = itemId, untilTime = os.clock() + EQUIP_SETTLE }
	Remotes.EquipCosmetic:FireServer(category, itemId)
	task.delay(0.1, refreshAll, true)
	task.delay(EQUIP_SETTLE + 0.05, refreshAll, true)
end

-- EQUIP: the same "line + word" button as MENU / CLOSE (no boxes).
local function equipButton(parent: Instance, item: Cosmetics.Item)
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
	local pressed = false -- one request per button
	button.Activated:Connect(function()
		if pressed then
			return
		end
		pressed = true
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
		requestEquip(item.category, item.id)
	end)
end

-- The EQUIPPED mark (underlined). `clickable`: it is also a button —
-- hover reads TAKE OFF, a click takes the item off.
local function equippedMark(parent: Instance, item: Cosmetics.Item, clickable: boolean)
	-- A TextButton when clickable, else a TextLabel (both show text the same).
	local instance = Theme.text({
		ClassName = if clickable then "TextButton" else "TextLabel",
		Name = "Equipped",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		-- A fixed width (not sized to the text): "TAKE OFF" is narrower than
		-- "EQUIPPED", and a button that shrank under the mouse would get a
		-- MouseLeave, grow back, get a MouseEnter... and flicker.
		Size = UDim2.fromOffset(90, 22),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = Theme.track("EQUIPPED", "four"),
		Parent = parent,
	})
	local mark = instance :: TextLabel
	local underline = Theme.make("Frame", {
		Name = "Underline",
		-- Anchored on the right, like the (right-aligned) word.
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 20),
		Size = UDim2.fromOffset(0, 2),
		BackgroundColor3 = C.Ink,
		Parent = mark,
	}) :: Frame
	-- The underline grows to the word's width (and follows it when the
	-- word changes to TAKE OFF and back).
	local function fitUnderline()
		Theme.tween(
			underline,
			0.18,
			{
				Size = UDim2.fromOffset(
					math.max(Theme.unscaled(mark, mark.TextBounds.X) - 3, 10),
					2
				),
			},
			Enum.EasingStyle.Quart
		)
	end
	mark:GetPropertyChangedSignal("TextBounds"):Connect(fitUnderline)
	task.defer(fitUnderline)
	if not clickable then
		return
	end
	local button = instance :: TextButton
	button.AutoButtonColor = false
	local pressed = false -- one request per button
	-- Crossfades the word in 0.1 s.
	local function setWord(text: string)
		if pressed then
			return
		end
		Theme.tween(button, 0.05, { TextTransparency = 1 })
		task.delay(0.05, function()
			if pressed then
				return
			end
			button.Text = Theme.track(text, "four")
			Theme.tween(button, 0.05, { TextTransparency = 0 })
		end)
	end
	button.MouseEnter:Connect(function()
		setWord("TAKE OFF")
	end)
	button.MouseLeave:Connect(function()
		setWord("EQUIPPED")
	end)
	button.Activated:Connect(function()
		if pressed then
			return
		end
		pressed = true
		Theme.tween(
			button,
			0.1,
			{ TextTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		Theme.tween(
			underline,
			0.1,
			{ Size = UDim2.fromOffset(0, 2) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		requestEquip(item.category, "")
	end)
end

-- Builds the action of a row for its current state. `fade`: it fades in
-- (its state just changed).
local function fillAction(row: Row, fade: boolean)
	local old = row.action
	if old then
		old:Destroy()
	end
	local item = row.item
	local state = itemState(item)
	row.key = stateKey(item)
	-- Its own layer (right part of the row) so it can fade on its own.
	local group = Theme.make("CanvasGroup", {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(170, 28),
		BackgroundTransparency = 1,
		Parent = row.frame,
	}) :: CanvasGroup
	row.action = group
	if state == "Equipped" then
		equippedMark(group, item, canTakeOff(item.category))
	elseif state == "Owned" then
		equipButton(group, item)
	elseif state == "Locked" then
		stateLabel(group, `LEVEL {item.unlockLevel or 1}`)
	elseif state == "Buyable" then
		buyButton(group, item)
	else
		stateLabel(group, `NEED {formatNumber(item.price - playerCoins())} MORE`)
	end
	if fade then
		group.GroupTransparency = 1
		Theme.tween(group, 0.15, { GroupTransparency = 0 })
	end
	-- A locked item is one step quieter (like a locked kit).
	row.name.TextColor3 = if state == "Locked" then C.Ink2 else C.Ink
	local hint = row.hint
	if hint then
		hint.TextColor3 = if state == "Equipped" then C.Ink2 else C.Ink3
	end
end

-- The row's state changed: the old action fades out (0.1 s), the new one
-- fades in (0.15 s).
local function swapAction(row: Row)
	row.token += 1
	local token = row.token
	local old = row.action
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
		if token == row.token and row.frame.Parent ~= nil then
			fillAction(row, true)
		end
	end)
end

------------------------------------------------------------------------------
-- Detail (right column)
------------------------------------------------------------------------------

local function itemRow(parent: Instance, order: number, item: Cosmetics.Item): Row
	local frame = Theme.make("Frame", {
		Name = item.id,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	hairline(frame, UDim.new(1, -1), 0.93)
	local indent = 0
	if item.category == "Outfit" then
		-- Top above, trousers below: a tiny outfit.
		indent = OUTFIT_INDENT
		swatch(frame, "Top", item.top or C.Ink3, 7)
		swatch(frame, "Trousers", item.trousers or C.Ink3, 21)
	end
	local name = Theme.text({
		Name = "Name",
		Position = UDim2.fromOffset(indent, 6),
		Size = UDim2.fromOffset(200, 13),
		TextStrokeTransparency = 1,
		Text = Theme.track(item.name, "four"),
		Parent = frame,
	}) :: TextLabel
	Theme.text({
		Name = "Sentence",
		Position = UDim2.fromOffset(indent, 22),
		-- Stops before the action column; a long one ends with "…".
		Size = UDim2.new(1, -indent - 120, 0, 14),
		FontFace = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = item.description,
		Parent = frame,
	})
	local hint: TextLabel? = nil
	if item.category == "Emote" then
		-- Under the action (below the EQUIPPED underline): how to play it.
		hint = caption(`PRESS {EMOTE_KEY}`, {
			Name = "Hint",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 28),
			Size = UDim2.fromOffset(100, 11),
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = frame,
		})
	end
	local row: Row = {
		item = item,
		frame = frame,
		name = name,
		hint = hint,
		action = nil,
		key = "",
		token = 0,
	}
	fillAction(row, false)
	return row
end

local function fillDetail(info: CategoryInfo)
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	table.clear(rows)
	Theme.text({
		Name = "CategoryName",
		Position = UDim2.fromOffset(0, -4),
		Size = UDim2.fromOffset(280, 30),
		FontFace = Theme.Fonts.Display,
		TextSize = 26,
		TextStrokeTransparency = 1,
		Text = Theme.track(info.label, "thin"),
		Parent = body,
	})
	Theme.text({
		Name = "Desc",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = Theme.Fonts.Body,
		TextSize = 15,
		TextStrokeTransparency = 1,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = info.description,
		Parent = body,
	})
	sectionHead(body, 80, "CATALOG")
	local items = itemsOf(info.id)
	local list = Theme.make("Frame", {
		Name = "Items",
		Position = UDim2.fromOffset(0, ROWS_TOP),
		Size = UDim2.new(1, 0, 0, #items * ROW_HEIGHT),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Theme.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for order, item in items do
		table.insert(rows, itemRow(list, order, item))
	end
end

-- Shows the selected category. `animate`: the old content slides out, the
-- new one in (like switching kits).
local function renderDetail(animate: boolean)
	local info = selected
	if not animate then
		fillDetail(info)
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
		if selected ~= info then
			return -- another category was picked meanwhile: its own call draws it
		end
		fillDetail(info)
		detail.Position = UDim2.fromOffset(DETAIL_X + 8, DETAIL_Y)
		Theme.tween(
			detail,
			0.2,
			{ GroupTransparency = 0, Position = UDim2.fromOffset(DETAIL_X, DETAIL_Y) },
			Enum.EasingStyle.Quart
		)
	end)
end

------------------------------------------------------------------------------
-- Roster (left column)
------------------------------------------------------------------------------

-- `animate`: a status line whose text changed crossfades (0.15 s).
local function refreshRoster(animate: boolean)
	for _, entry in rosterItems do
		local isSelected = entry.info == selected
		Theme.tween(entry.name, Theme.FAST, { TextColor3 = if isSelected then C.Ink else C.Ink3 })
		local statusColor = if isSelected then C.Ink2 else C.Ink3
		local text = Theme.track(rosterStatus(entry.info), "three")
		local status = entry.status
		if animate and status.Text ~= text then
			Theme.tween(status, 0.075, { TextTransparency = 1 })
			task.delay(0.075, function()
				-- Read again: the selection or the save may have changed.
				status.Text = Theme.track(rosterStatus(entry.info), "three")
				Theme.tween(status, 0.075, {
					TextColor3 = if entry.info == selected then C.Ink2 else C.Ink3,
					TextTransparency = 0,
				})
			end)
		else
			status.Text = text
			Theme.tween(status, Theme.FAST, { TextColor3 = statusColor })
		end
		if isSelected then
			rosterMarker.Parent = entry.button
			rosterMarker.Position = UDim2.fromOffset(-14, 12)
		end
	end
end

local function selectCategory(info: CategoryInfo)
	if info == selected then
		return
	end
	selected = info
	refreshRoster(false)
	renderDetail(true)
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function build(content: Frame)
	-- Header (the panel around the content): the wallet top right, and the
	-- subtitle we keep up to date ("4 OF 17 OWNED").
	local panel = content.Parent :: Instance
	local newWallet = ProfileMenuController.createWallet(panel)
	walletCoins = playerCoins()
	newWallet.set(walletCoins, false)
	wallet = newWallet
	local label = panel:FindFirstChild("Subtitle")
	if label and label:IsA("TextLabel") then
		subtitleLabel = label
		label.Text = Theme.track(subtitle(), "three")
	end

	local roster = Theme.make("Frame", {
		Name = "Roster",
		Size = UDim2.fromOffset(150, 16 + #CATEGORIES * 50),
		BackgroundTransparency = 1,
		Parent = content,
	})
	caption("CATEGORY", { Size = UDim2.new(1, 0, 0, 12), Parent = roster })
	local list = Theme.make("Frame", {
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
	for order, info in CATEGORIES do
		local button = Theme.make("TextButton", {
			Name = info.id,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Parent = list,
		}) :: TextButton
		local name = Theme.text({
			Name = "Name",
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 13,
			TextColor3 = C.Ink3,
			TextStrokeTransparency = 1,
			Text = Theme.track(info.label, "four"),
			Parent = button,
		}) :: TextLabel
		local status = caption(rosterStatus(info), {
			Name = "Status",
			Position = UDim2.fromOffset(0, 31),
			Size = UDim2.new(1, 0, 0, 11),
			TextSize = 9,
			Parent = button,
		})
		table.insert(rosterItems, { info = info, button = button, name = name, status = status })
		button.MouseEnter:Connect(function()
			if info ~= selected then
				Theme.tween(name, 0.1, { TextColor3 = C.Ink2 })
			end
		end)
		button.MouseLeave:Connect(function()
			if info ~= selected then
				Theme.tween(name, 0.1, { TextColor3 = C.Ink3 })
			end
		end)
		button.Activated:Connect(function()
			selectCategory(info)
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
		Size = UDim2.fromOffset(DETAIL_SIZE.X + DETAIL_INSET.X + 2, DETAIL_SIZE.Y + DETAIL_INSET.Y),
		BackgroundTransparency = 1,
		Parent = content,
	})
	body = Theme.make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(DETAIL_INSET.X, DETAIL_INSET.Y),
		Size = UDim2.fromOffset(DETAIL_SIZE.X, DETAIL_SIZE.Y),
		BackgroundTransparency = 1,
		Parent = detail,
	})
	built = true
	refreshRoster(false)
	renderDetail(false)
end

-- A new save arrived (coins, XP, an item bought or equipped...), or the
-- level changed: update the wallet, the subtitle, the roster lines and
-- every row whose state changed.
refreshAll = function(animate: boolean)
	if not built then
		return
	end
	local currentWallet = wallet
	local coins = playerCoins()
	if currentWallet and coins ~= walletCoins then
		currentWallet.set(coins, animate)
		walletCoins = coins
	end
	local label = subtitleLabel
	if label then
		label.Text = Theme.track(subtitle(), "three")
	end
	refreshRoster(animate)
	for _, row in rows do
		if stateKey(row.item) ~= row.key then
			if animate then
				swapAction(row)
			else
				row.token += 1
				fillAction(row, false)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function ShopMenuController.start()
	MenuController.register({
		id = "Shop",
		label = "SHOP",
		subtitle = subtitle(),
		order = 60, -- between PROFILE (50) and SETTINGS (100)
		size = Vector2.new(560, 480),
		scrimWidth = 1100,
		build = build,
	})
	PlayerDataController.onChanged(function(profile)
		-- The save caught up with what we asked: no need to keep our copy.
		for _, info in CATEGORIES do
			local pending = pendingEquip[info.id]
			if pending and savedEquipped(profile, info.id) == pending.id then
				pendingEquip[info.id] = nil
			end
		end
		refreshAll(true)
	end)
	-- The level can also arrive as the "Level" attribute (before the save).
	player:GetAttributeChangedSignal("Level"):Connect(function()
		refreshAll(true)
	end)
end

return ShopMenuController
