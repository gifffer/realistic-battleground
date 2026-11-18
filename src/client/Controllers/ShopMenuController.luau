--!strict
-- ShopMenuController: the SHOP and EMOTES panels (top bar buttons).
-- Cosmetics bought with coins (step 10): nothing here changes a fight.
--
--   TITLES | OUTFITS | KILL EFFECTS                         820 coins
--                          SHOP
--   [ card ][ card ][ card ][ card ]
--   [ card ]
--   BACK ALLEY                                        [ BUY · 250 ]
--   Grew up fighting behind the bar.
--
-- SHOP: tabs above the panel for the categories (titles, outfits, kill
-- effects), a grid of cards for the open one. EMOTES: the same, for the
-- emotes (their own button in the top bar). A card shows the item (the
-- title's words, a figure in the outfit's colours, a burst, the emote's
-- pose), its name in bold, a small caps line for its state, its type top
-- right. Click a card: it is picked (lighter, white outline) and the bar
-- under the grid shows its sentence and a real button (UI/Button) for its
-- state:
--   Locked     level too low        [lock] LEVEL 10        greyed, not clickable
--   Buyable    enough coins         [coin] BUY · 250       main button (two presses: CONFIRM)
--   Short      not enough coins     [coin] NEED 120 MORE   greyed, not clickable
--   Owned      bought (or free)     EQUIP                  main button
--   Equipped   the one you wear     TAKE OFF (titles, outfits, kill effects)
--                                   PLAY (emotes: plays it, like the B key)
-- The card of what you wear has a thin gold outline and "EQUIPPED" in gold.
--
-- Everything is worked out from the save (PlayerDataController: coins, XP →
-- level, ownedCosmetics, equipped). The SERVER checks everything again
-- (Server/Systems/Shop): Remotes.BuyCosmetic(id), Remotes.EquipCosmetic
-- (category, id or "" = take it off), Remotes.Emote (play the equipped
-- emote). The wallet (coins) sits top right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ProgressionCurve = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Button = require(script.Parent.Parent.UI.Button)
local Icons = require(script.Parent.Parent.UI.Icons)
local Panel = require(script.Parent.Parent.UI.Panel)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)
local ProfileMenuController = require(script.Parent.ProfileMenuController)

local player = Players.LocalPlayer
local formatNumber = ProfileMenuController.formatNumber

local C = Theme.Colors

-- Four cards per row, the bar for the picked item under them.
local CARD = Vector2.new(112, 140)
local CARD_GAP = 8
local COLUMNS = 4
local GRID_ROWS = 2
local GRID_SIZE =
	Vector2.new(COLUMNS * CARD.X + (COLUMNS - 1) * CARD_GAP + 8, GRID_ROWS * CARD.Y + CARD_GAP + 4)
local ACTION_BAR = 52
local CONTENT_SIZE = Vector2.new(GRID_SIZE.X, GRID_SIZE.Y + 10 + ACTION_BAR)

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
	label: string, -- tab name
	tag: string, -- small type word top right of a card
	canTakeOff: boolean, -- the equipped one can be taken off ("" = none)
}

local CATEGORIES: { CategoryInfo } = {
	{ id = "Title", label = "TITLES", tag = "TITLE", canTakeOff = true },
	-- (the avatar's own clothes come back next life)
	{ id = "Outfit", label = "OUTFITS", tag = "OUTFIT", canTakeOff = true },
	{ id = "KillEffect", label = "KILL EFFECTS", tag = "EFFECT", canTakeOff = true },
	{ id = "Emote", label = "EMOTES", tag = "EMOTE", canTakeOff = false },
}

-- Each emote's pose on its card (UI/Panel figure).
local EMOTE_POSES: { [string]: Panel.Pose } = {
	EmoteShrug = { leftArm = Vector2.new(25, 45), rightArm = Vector2.new(25, 45) },
	EmoteComeHere = { rightArm = Vector2.new(85, 0), leftArm = Vector2.new(0, 10) },
	EmoteKnuckles = { leftArm = Vector2.new(75, -35), rightArm = Vector2.new(75, -35) },
	EmoteFlex = { leftArm = Vector2.new(60, -60), rightArm = Vector2.new(60, -60) },
}
local SKIN = Color3.fromHex("#2A2A2A")

local ShopMenuController = {}

-- One SHOP / EMOTES panel.
type CardUi = {
	item: Cosmetics.Item,
	card: Panel.Card,
}
type Catalog = {
	categories: { CategoryInfo },
	category: CategoryInfo, -- the open tab
	picked: { [Cosmetics.Category]: string }, -- the picked item per tab
	cards: { CardUi },
	grid: ScrollingFrame,
	name: TextLabel,
	sentence: TextLabel,
	actionHolder: Frame,
	action: CanvasGroup?, -- the picked item's button (fades on a change)
	key: string, -- the state the action was drawn for (see stateKey)
	token: number,
	wallet: ProfileMenuController.Wallet,
	tabs: Panel.Tabs?,
}

local catalogs: { Catalog } = {}
local walletCoins = 0 -- what the wallets show (so they only count on a change)
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

------------------------------------------------------------------------------
-- The actions (right of the bar under the grid)
------------------------------------------------------------------------------

-- Where an action button sits: right of the bar, vertically centred, far
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
		minWidth = 96,
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

-- EQUIP (main button).
local function equipButton(parent: Instance, item: Cosmetics.Item)
	local button: Button.Button
	button = Button.new({
		name = "EquipButton",
		text = "EQUIP",
		variant = "primary",
		size = "small",
		minWidth = 84,
		anchorPoint = ACTION_ANCHOR,
		position = ACTION_POSITION,
		parent = parent,
		onActivated = function()
			button.setEnabled(false) -- one request per button
			requestEquip(item.category, item.id)
		end,
	})
end

-- The item you wear: TAKE OFF (titles, outfits, kill effects), PLAY
-- (emotes: the same as the emote key), or a plain EQUIPPED badge.
local function wornAction(parent: Instance, item: Cosmetics.Item)
	if item.category == "Emote" then
		Button.new({
			name = "PlayButton",
			text = "PLAY",
			variant = "primary",
			size = "small",
			keyHint = EMOTE_KEY,
			minWidth = 84,
			anchorPoint = ACTION_ANCHOR,
			position = ACTION_POSITION,
			parent = parent,
			onActivated = function()
				-- The server checks you can (not mid-fight) and plays it.
				Remotes.Emote:FireServer()
			end,
		})
		return
	end
	if not canTakeOff(item.category) then
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
	local button: Button.Button
	button = Button.new({
		name = "TakeOff",
		text = "TAKE OFF",
		variant = "secondary",
		size = "small",
		minWidth = 84,
		anchorPoint = ACTION_ANCHOR,
		position = ACTION_POSITION,
		parent = parent,
		onActivated = function()
			button.setEnabled(false) -- one request per button
			button.setText("TAKING OFF")
			requestEquip(item.category, "")
		end,
	})
end

------------------------------------------------------------------------------
-- Cards
------------------------------------------------------------------------------

-- The small caps line under a card's name.
local function cardLine(item: Cosmetics.Item): (string, Color3)
	local state = itemState(item)
	if state == "Equipped" then
		return "Equipped", C.Gold
	elseif state == "Owned" then
		return "Owned", C.Ink2
	elseif state == "Locked" then
		return `Level {item.unlockLevel or 1}`, C.Ink3
	elseif state == "Buyable" then
		return if item.price == 0 then "Free" else `{formatNumber(item.price)} coins`, C.Ink2
	end
	return `{formatNumber(item.price)} coins`, C.Ink3
end

-- What a card shows in its middle (the REWARDS track uses it too).
local function fillArt(art: Frame, item: Cosmetics.Item)
	if item.category == "Title" then
		Theme.text({
			Name = "Words",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -16, 1, -8),
			FontFace = Theme.Fonts.Display,
			TextSize = 17,
			TextColor3 = C.Ink,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Text = item.title or item.name,
			Parent = art,
		})
	elseif item.category == "Outfit" then
		Panel.figure(art, {
			pose = { leftArm = Vector2.new(5, 8), rightArm = Vector2.new(5, 8) },
			top = item.top,
			bottom = item.trousers,
			skin = SKIN,
		})
	elseif item.category == "KillEffect" then
		local icon = Icons.draw("effect", art, 46)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		Icons.paint(icon, C.Ink)
	else
		Panel.figure(art, { pose = EMOTE_POSES[item.id] })
	end
end

local function categoryOf(id: Cosmetics.Category): CategoryInfo
	for _, info in CATEGORIES do
		if info.id == id then
			return info
		end
	end
	return CATEGORIES[1]
end

------------------------------------------------------------------------------
-- A catalog (one panel)
------------------------------------------------------------------------------

-- The picked item of the open tab (the equipped one, else the first).
local function pickedItem(catalog: Catalog): Cosmetics.Item?
	local id = catalog.picked[catalog.category.id] or equippedId(catalog.category.id)
	local item = Cosmetics.get(id)
	if item and item.category == catalog.category.id then
		return item
	end
	return itemsOf(catalog.category.id)[1]
end

-- Builds the bar's button for the picked item. `fade`: it fades in.
local function fillAction(catalog: Catalog, fade: boolean)
	local old = catalog.action
	if old then
		old:Destroy()
	end
	catalog.action = nil
	local item = pickedItem(catalog)
	if item == nil then
		catalog.key = ""
		return
	end
	catalog.key = item.id .. stateKey(item)
	local group = Theme.make("CanvasGroup", {
		Name = "Action",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = catalog.actionHolder,
	}) :: CanvasGroup
	catalog.action = group
	local state = itemState(item)
	if state == "Equipped" then
		wornAction(group, item)
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
end

-- Cards (state lines, outlines) and the bar, from the save.
local function paintCatalog(catalog: Catalog, animate: boolean)
	local picked = pickedItem(catalog)
	for _, entry in catalog.cards do
		local state = itemState(entry.item)
		local text, color = cardLine(entry.item)
		entry.card.setSub(text, color)
		entry.card.setEquipped(state == "Equipped")
		entry.card.setSelected(picked ~= nil and entry.item.id == picked.id)
		entry.card.setDim(state == "Locked" or state == "Short")
	end
	catalog.name.Text = if picked then picked.name else ""
	catalog.sentence.Text = if picked then picked.description else ""
	local key = if picked then picked.id .. stateKey(picked) else ""
	if key ~= catalog.key then
		catalog.token += 1
		local token = catalog.token
		local old = catalog.action
		if animate and old then
			Theme.tween(
				old,
				0.1,
				{ GroupTransparency = 1 },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			task.delay(0.1, function()
				if token == catalog.token then
					fillAction(catalog, true)
				end
			end)
		else
			fillAction(catalog, false)
		end
	end
end

-- Fills the grid with the open tab's items.
local function fillGrid(catalog: Catalog)
	for _, entry in catalog.cards do
		entry.card.instance:Destroy()
	end
	table.clear(catalog.cards)
	local info = catalog.category
	for order, item in itemsOf(info.id) do
		local card = Panel.card({
			parent = catalog.grid,
			name = item.name,
			tag = info.tag,
			layoutOrder = order,
			onActivated = function()
				catalog.picked[item.category] = item.id
				paintCatalog(catalog, true)
			end,
		})
		fillArt(card.art, item)
		table.insert(catalog.cards, { item = item, card = card })
	end
	catalog.grid.CanvasPosition = Vector2.zero
	paintCatalog(catalog, false)
end

local function buildCatalog(content: Frame, host: MenuController.Host, categories: { CategoryInfo })
	-- Header (the panel around the content): the wallet top right.
	local wallet = ProfileMenuController.createWallet(content.Parent :: Instance)
	walletCoins = playerCoins()
	wallet.set(walletCoins, false)

	local grid = Panel.grid(
		content,
		CARD,
		CARD_GAP,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(GRID_SIZE.X, GRID_SIZE.Y)
	)
	local barFrame = Theme.make("Frame", {
		Name = "PickedBar",
		Position = UDim2.fromOffset(0, GRID_SIZE.Y + 10),
		Size = UDim2.new(1, 0, 0, ACTION_BAR),
		BackgroundColor3 = C.Card,
		BackgroundTransparency = 0.4,
		Parent = content,
	})
	local name = Theme.text({
		Name = "ItemName",
		Position = UDim2.fromOffset(12, 9),
		Size = UDim2.new(1, -230, 0, 18),
		FontFace = Theme.Fonts.Display,
		TextSize = 15,
		TextColor3 = C.InkHi,
		TextStrokeTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = barFrame,
	}) :: TextLabel
	local sentence = Theme.text({
		Name = "Sentence",
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -230, 0, 15),
		FontFace = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = barFrame,
	}) :: TextLabel
	local actionHolder = Theme.make("Frame", {
		Name = "ActionHolder",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 0),
		Size = UDim2.new(0, 220, 1, 0),
		BackgroundTransparency = 1,
		Parent = barFrame,
	}) :: Frame

	local catalog: Catalog = {
		categories = categories,
		category = categories[1],
		picked = {},
		cards = {},
		grid = grid,
		name = name,
		sentence = sentence,
		actionHolder = actionHolder,
		action = nil,
		key = "",
		token = 0,
		wallet = wallet,
		tabs = host.tabs,
	}
	table.insert(catalogs, catalog)
	local tabs = host.tabs
	if tabs then
		tabs.bind(function(index: number)
			local info = categories[index]
			if info and info ~= catalog.category then
				catalog.category = info
				fillGrid(catalog)
			end
		end)
	end
	fillGrid(catalog)
end

-- A new save arrived (coins, XP, an item bought or equipped...), or the
-- level changed: update the wallets, the cards and the bars.
refreshAll = function(animate: boolean)
	local coins = playerCoins()
	local changed = coins ~= walletCoins
	walletCoins = coins
	for _, catalog in catalogs do
		if changed then
			catalog.wallet.set(coins, animate)
		end
		paintCatalog(catalog, animate)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

ShopMenuController.fillArt = fillArt

-- Opens SHOP (or EMOTES) on `itemId` (the REWARDS track's cards).
function ShopMenuController.show(itemId: string)
	local item = Cosmetics.get(itemId)
	if item == nil then
		return
	end
	local panelId = if item.category == "Emote" then "Emotes" else "Shop"
	MenuController.open(panelId)
	for _, catalog in catalogs do
		for index, info in catalog.categories do
			if info.id == item.category then
				catalog.picked[item.category] = item.id
				local tabs = catalog.tabs
				if catalog.category ~= info and tabs then
					tabs.set(index) -- (its callback fills the grid)
				elseif catalog.category ~= info then
					catalog.category = info
					fillGrid(catalog)
				else
					paintCatalog(catalog, true)
				end
			end
		end
	end
end

function ShopMenuController.start()
	local shopCategories = { CATEGORIES[1], CATEGORIES[2], CATEGORIES[3] }
	local tabLabels = {}
	for _, info in shopCategories do
		table.insert(tabLabels, info.label)
	end
	MenuController.register({
		id = "Shop",
		label = "SHOP",
		icon = "shop",
		hint = "Shop",
		tabs = tabLabels,
		order = 60,
		size = CONTENT_SIZE,
		build = function(content, host)
			buildCatalog(content, host, shopCategories)
		end,
	})
	MenuController.register({
		id = "Emotes",
		label = "EMOTES",
		icon = "emotes",
		hint = "Emotes",
		subtitle = if Theme.isTouch()
			then "Equip one, then tap EMOTE on the screen to play it"
			else `Equip one, then press {EMOTE_KEY} to play it`,
		order = 45,
		size = CONTENT_SIZE,
		build = function(content, host)
			buildCatalog(content, host, { categoryOf("Emote") })
		end,
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
