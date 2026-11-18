--!strict
-- ShopMenuController: the SHOP section of the menu (between PROFILE and
-- SETTINGS). Cosmetics bought with coins (step 10): nothing here changes a
-- fight.
--
--   SHOP                                                       820
--   COSMETICS · 4 OF 17 OWNED                                COINS
--   ──────────────────────────────────────────────────────────────
--   CATEGORY            TITLES
--   ┌──────────────┐    Shown under your name, on your name tag.
--   │TITLES        │    CATALOG
--   │ROOKIE        │    ROOKIE                       [✓ EQUIPPED]
--   └──────────────┘    Everybody starts somewhere.
--   ┌──────────────┐    BARE KNUCKLE                    [ EQUIP ]
--   │OUTFITS       │    No gloves, no rules.
--   │NONE EQUIPPED │    BACK ALLEY                  [o BUY · 250]
--   └──────────────┘    Grew up fighting behind the bar.
--   ...                 HEAVY HANDS                  [# LEVEL 10]
--                       One clean shot is enough.
--
-- Left: the 4 categories as cards (like the KITS roster: the selected one
-- outlined in the accent colour, the equipped item's name under each).
-- Right: every item of the category (Shared/Cosmetics), one row each, with
-- a real button (UI/Button) on the right for its state:
--   Locked     level too low        [lock] LEVEL 10        greyed, not clickable
--   Buyable    enough coins         [coin] BUY · 250       accent (two presses: CONFIRM)
--   Short      not enough coins     [coin] NEED 120 MORE   greyed, not clickable
--   Owned      bought (or free)     EQUIP                  accent
--   Equipped   the one you wear     [check] EQUIPPED       accent outline. On a title,
--              an outfit or a kill effect it takes the item off: on a PC
--              the mouse over it reads TAKE OFF; on a phone the first tap
--              asks TAKE OFF? and the second one does it. Emotes: a badge.
-- Outfit rows show two small colour squares (top above, trousers below).
-- Emote rows add a hint under the text ("PRESS B", or the EMOTE button on
-- a phone).
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
local Button = require(script.Parent.Parent.UI.Button)
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
-- One item: 50 px, taller on touch so its button fits (the text moves down
-- by half the difference to stay centred on it).
local ROW_HEIGHT = math.max(50, Button.height("small") + 8)
local ROW_TEXT_Y = (ROW_HEIGHT - 50) // 2
local ROWS_TOP = 99 -- first row, under the CATALOG head
local MAX_ROWS = 5 -- the biggest category
local DETAIL_SIZE = Vector2.new(360, ROWS_TOP + MAX_ROWS * ROW_HEIGHT + 8)
local CARD_HEIGHT = if Theme.isTouch() then 58 else 52
local CARD_GAP = 6
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
-- How to play an emote on this device.
local EMOTE_HINT = if Theme.isTouch() then "TAP EMOTE ON THE SCREEN" else `PRESS {EMOTE_KEY}`

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
		description = if Theme.isTouch()
			then "A gesture between fights. Tap EMOTE to play it."
			else `A gesture between fights. Press {EMOTE_KEY} to play it.`,
		canTakeOff = false,
	},
}

local ShopMenuController = {}

-- One item row on the right.
type Row = {
	item: Cosmetics.Item,
	frame: Frame,
	name: TextLabel,
	hint: TextLabel?, -- "PRESS B" / "TAP EMOTE..." (emotes only)
	action: CanvasGroup?, -- the state on the right (fades on a change)
	key: string, -- the state the action was drawn for (see stateKey)
	token: number, -- cancels an action swap that is no longer wanted
}

-- One category card on the left.
type RosterItem = {
	info: CategoryInfo,
	button: Button.Button,
}

local selected: CategoryInfo = CATEGORIES[1]
local rows: { Row } = {}
local rosterItems: { RosterItem } = {}
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

-- Where an action button sits: right of the row, vertically centred, far
-- enough from the layer's edge that it can grow under the mouse uncut.
local ACTION_ANCHOR = Vector2.new(1, 0.5)
local ACTION_POSITION = UDim2.new(1, -7, 0.5, 0)

-- Locked / not enough coins: a greyed button that says why (not clickable).
local function blockedButton(parent: Instance, icon: Button.IconName, text: string)
	local button = Button.new({
		name = "Blocked",
		text = text,
		icon = icon,
		size = "small",
		anchorPoint = ACTION_ANCHOR,
		position = ACTION_POSITION,
		parent = parent,
	})
	button.setEnabled(false)
end

-- BUY · 250 (accent). Two presses: the first turns it into CONFIRM for a
-- few seconds, the second asks the server (Remotes.BuyCosmetic).
local function buyButton(parent: Instance, item: Cosmetics.Item)
	-- (A free item that needs a level first reads "BUY · FREE".)
	local priceText = if item.price == 0 then "FREE" else formatNumber(item.price)
	local confirmUntil = 0 -- os.clock() before which a press buys
	local pending = false -- asked the server, waiting for the save
	local button: Button.Button
	button = Button.new({
		name = "BuyButton",
		text = `BUY · {priceText}`,
		variant = "primary",
		icon = "coin",
		size = "small",
		minWidth = 110,
		anchorPoint = ACTION_ANCHOR,
		position = ACTION_POSITION,
		parent = parent,
		onActivated = function()
			if pending then
				return
			end
			local now = os.clock()
			if now < confirmUntil then
				-- Second press: buy. The server checks level, price and coins.
				confirmUntil = 0
				pending = true
				button.setEnabled(false)
				button.setText("BUYING…")
				Remotes.BuyCosmetic:FireServer(item.id)
				-- Bought: the new save replaces this button (EQUIP). Still
				-- here after a moment = refused: red outline, back to BUY.
				task.delay(REFUSED_AFTER, function()
					if button.instance.Parent == nil then
						return
					end
					pending = false
					button.setEnabled(true)
					button.setText(`BUY · {priceText}`)
					button.flash()
				end)
				return
			end
			-- First press: ask to confirm.
			confirmUntil = now + CONFIRM_SECONDS
			local stamp = confirmUntil
			button.setText(`CONFIRM · {priceText}`)
			task.delay(CONFIRM_SECONDS, function()
				if confirmUntil == stamp and not pending and button.instance.Parent ~= nil then
					confirmUntil = 0
					button.setText(`BUY · {priceText}`)
				end
			end)
		end,
	})
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

-- EQUIP (accent).
local function equipButton(parent: Instance, item: Cosmetics.Item)
	local button: Button.Button
	button = Button.new({
		name = "EquipButton",
		text = "EQUIP",
		variant = "primary",
		size = "small",
		minWidth = 90,
		anchorPoint = ACTION_ANCHOR,
		position = ACTION_POSITION,
		parent = parent,
		onActivated = function()
			button.setEnabled(false) -- one request per button
			requestEquip(item.category, item.id)
		end,
	})
end

-- EQUIPPED. `clickable`: it also takes the item off (see the top).
local function equippedMark(parent: Instance, item: Cosmetics.Item, clickable: boolean)
	if not clickable then
		Button.badge({
			name = "Equipped",
			text = "EQUIPPED",
			icon = "check",
			size = "small",
			anchorPoint = ACTION_ANCHOR,
			position = ACTION_POSITION,
			parent = parent,
		})
		return
	end
	local confirmUntil = 0 -- touch: os.clock() before which a tap takes it off
	local button: Button.Button
	button = Button.new({
		name = "Equipped",
		text = "EQUIPPED",
		icon = "check",
		size = "small",
		-- A fixed width: "TAKE OFF" is narrower than "EQUIPPED", and a
		-- button that shrank under the mouse would flicker.
		width = 120,
		anchorPoint = ACTION_ANCHOR,
		position = ACTION_POSITION,
		parent = parent,
		onActivated = function()
			if Theme.isTouch() and os.clock() >= confirmUntil then
				-- First tap on a phone: ask.
				confirmUntil = os.clock() + CONFIRM_SECONDS
				local stamp = confirmUntil
				button.setText("TAKE OFF?")
				task.delay(CONFIRM_SECONDS, function()
					if confirmUntil == stamp and button.instance.Parent ~= nil then
						button.setText("EQUIPPED")
					end
				end)
				return
			end
			button.setEnabled(false) -- one request per button
			button.setText("TAKING OFF")
			requestEquip(item.category, "")
		end,
	})
	button.setSelected(true) -- accent outline: it is the one you wear
	button.instance.MouseEnter:Connect(function()
		if button.isEnabled() and not Theme.isTouch() then
			button.setText("TAKE OFF")
		end
	end)
	button.instance.MouseLeave:Connect(function()
		if button.isEnabled() then
			button.setText("EQUIPPED")
		end
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
		Size = UDim2.new(0, 190, 1, -1),
		BackgroundTransparency = 1,
		Parent = row.frame,
	}) :: CanvasGroup
	row.action = group
	if state == "Equipped" then
		equippedMark(group, item, canTakeOff(item.category))
	elseif state == "Owned" then
		equipButton(group, item)
	elseif state == "Locked" then
		blockedButton(group, "lock", `LEVEL {item.unlockLevel or 1}`)
	elseif state == "Buyable" then
		buyButton(group, item)
	else
		blockedButton(group, "coin", `NEED {formatNumber(item.price - playerCoins())} MORE`)
	end
	if fade then
		group.GroupTransparency = 1
		Theme.tween(group, 0.15, { GroupTransparency = 0 })
	end
	-- A locked item is one step quieter (like a locked kit).
	row.name.TextColor3 = if state == "Locked" then C.Ink2 else C.Ink
	local hint = row.hint
	if hint then
		hint.TextColor3 = if state == "Equipped" then C.Accent else C.Ink3
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
		swatch(frame, "Top", item.top or C.Ink3, 10 + ROW_TEXT_Y)
		swatch(frame, "Trousers", item.trousers or C.Ink3, 24 + ROW_TEXT_Y)
	end
	local name = Theme.text({
		Name = "Name",
		Position = UDim2.fromOffset(
			indent,
			ROW_TEXT_Y + (if item.category == "Emote" then 3 else 8)
		),
		Size = UDim2.fromOffset(200, 13),
		TextStrokeTransparency = 1,
		Text = Theme.track(item.name, "four"),
		Parent = frame,
	}) :: TextLabel
	Theme.text({
		Name = "Sentence",
		Position = UDim2.fromOffset(
			indent,
			ROW_TEXT_Y + (if item.category == "Emote" then 19 else 25)
		),
		-- Stops before the action button; a long one ends with "…".
		Size = UDim2.new(1, -indent - 154, 0, 14),
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
		-- Under the sentence: how to play it.
		hint = caption(EMOTE_HINT, {
			Name = "Hint",
			Position = UDim2.fromOffset(indent, 36 + ROW_TEXT_Y),
			Size = UDim2.new(1, -indent - 154, 0, 11),
			TextSize = 9,
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

-- Updates every card (selected outline, what is equipped). `animate`: a
-- status line whose text changed fades in again.
local function refreshRoster(animate: boolean)
	for _, entry in rosterItems do
		entry.button.setSelected(entry.info == selected)
		local sub = entry.button.sub
		local status = rosterStatus(entry.info)
		local changed = sub ~= nil and sub.Text ~= Theme.track(status, "three")
		local wearing = status ~= "NONE EQUIPPED"
		entry.button.setSubtext(status, if wearing then C.Accent else C.Ink3)
		if animate and changed and sub then
			sub.TextTransparency = 1
			Theme.tween(sub, 0.15, { TextTransparency = 0 })
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
		Size = UDim2.fromOffset(156, 20 + #CATEGORIES * (CARD_HEIGHT + CARD_GAP)),
		BackgroundTransparency = 1,
		Parent = content,
	})
	caption("CATEGORY", { Size = UDim2.new(1, 0, 0, 12), Parent = roster })
	local list = Theme.make("Frame", {
		Name = "Items",
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 1, -20),
		BackgroundTransparency = 1,
		Parent = roster,
	}, {
		Theme.make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, CARD_GAP),
		}),
	})
	for order, info in CATEGORIES do
		local button = Button.new({
			name = info.id,
			text = info.label,
			subtext = rosterStatus(info),
			variant = "tab",
			height = CARD_HEIGHT,
			fillWidth = true,
			layoutOrder = order,
			parent = list,
			onActivated = function()
				selectCategory(info)
			end,
		})
		table.insert(rosterItems, { info = info, button = button })
	end

	Theme.make("Frame", {
		Name = "Divider2",
		Position = UDim2.fromOffset(170, 0),
		Size = UDim2.fromOffset(1, DETAIL_SIZE.Y - 8),
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
		size = Vector2.new(560, 116 + DETAIL_SIZE.Y),
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
