--!strict
-- MenuController: the top bar buttons and their panels (everything that
-- isn't fighting).
--
-- Top bar: copies Roblox's own bar (docs/UI_ROBLOX_STYLE.md), right of
-- its buttons: 44 px black pills at 0.3 transparency, white 22 px line
-- icons. A section with a word ("Kits") gets its own pill; the icon-only
-- sections share ONE pill, like Roblox's menu / chat / mic pill. Under the
-- mouse a faint round light shows behind the icon; an open section keeps a
-- pale round mark. A small white count = something to look at.
-- One button per section. A button opens its OWN panel; the same button,
-- Escape, or a click / tap outside the panel closes it. One panel at a
-- time (opening another one swaps them). The menu key (M) opens the last
-- panel seen and closes the open one (not while typing in the chat).
--
-- Panel: one near-black plate with 12 px corners (Roblox's dark menus)
-- under the top bar, centred: optional small tabs above it on the left, a
-- bold centred title, a faint divider, then the section's content.
--
-- Each feature ADDS ITS OWN section from its controller:
--
--   MenuController.register({
--       id = "Settings",               -- unique name
--       label = "SETTINGS",            -- the panel's title (English, caps)
--       icon = "settings",             -- UI/Icons name
--       buttonText = "Kits",           -- optional: a word next to the icon
--       hint = "Settings",             -- the word shown under the button on hover
--       subtitle = "Camera and controls", -- optional, one plain line under the title
--       tabs = { "A", "B" },           -- optional: small tabs above the panel
--       order = 100,                   -- position in the bar (small = left)
--       size = Vector2.new(440, 300),  -- the content's size (pixels)
--       build = function(content: Frame, host: Host) ... end, -- fills it, once
--   })
--   host.tabs: the tabs (UI/Panel.tabs), when `tabs` was given.
--   host.header: the title row, outside the scrolling content (put the wallet there).
--   MenuController.setBadge("Rewards", 2)  -- the white count on the button (0 hides it)
--
-- While a panel is open the mouse cursor is free
-- (CameraController.setCursorFree("menu", ...)).
--
-- Screen size: the bar sits in Roblox's top bar (GuiService.TopbarInset:
-- right of Roblox's buttons, same height). When it can't fit (a phone),
-- it scrolls sideways. A panel is drawn for 1920 × 1080; on a smaller screen
-- it shrinks (UIScale) to fit under the bar, never under ×0.75 (text stays
-- readable): a panel still too tall then scrolls.
--
-- A controller can pick the panel M opens for a while:
-- MenuController.setDefaultOverride(function() return "Duel" end).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local CameraController = require(script.Parent.CameraController)
local Icons = require(script.Parent.Parent.UI.Icons)
local Panel = require(script.Parent.Parent.UI.Panel)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local C = Theme.Colors

-- Top bar (Roblox's own sizes: 44 px pills, 22 px icons, 36 px hover light).
local PILL = 44
local PILL_GAP = 8 -- between pills
local PILL_TRANSPARENCY = 0.3 -- black at 0.3, like Roblox's
local SLOT = 42 -- one icon's room in the shared pill
local SLOT_EDGE = 2 -- the shared pill's padding at both ends
local SPOT = 36 -- the round light behind an icon
local ICON = 22
local LABEL_SIZE = 16
-- Panels.
local PAD = 16 -- inside the plate
local TITLE_H = 30
local SUBTITLE_H = 16
local TAB_GAP = 4 -- between the tabs and the plate
local SCREEN_GAP = 10 -- between the bar and the panel, and at the bottom
local MIN_SCALE = 0.75
local OPEN_TIME = 0.18

export type Host = {
	tabs: Panel.Tabs?,
	-- The title row's frame, outside the scrolling content (the wallet goes here).
	header: Frame,
}

export type MenuEntry = {
	id: string,
	label: string,
	icon: Icons.IconName,
	buttonText: string?,
	hint: string?,
	subtitle: string?,
	tabs: { string }?,
	order: number,
	size: Vector2,
	build: (content: Frame, host: Host) -> (),
}

type EntryUi = {
	entry: MenuEntry,
	button: TextButton,
	spot: Frame, -- the light behind the icon (hover / open)
	icon: Frame,
	text: TextLabel?,
	badge: Frame,
	count: TextLabel,
	panel: Frame?, -- created the first time it's opened
	plate: Frame?,
	view: ScrollingFrame?,
	scale: UIScale?,
	host: Host?,
}

local MenuController = {}

local gui: ScreenGui
local bar: Frame -- the row of pills
local barScale: UIScale -- follows Roblox's bar height (36 px on the old one)
local group: Frame -- the shared pill of the icon-only buttons
local tooltip: TextLabel
local panelLayer: Frame
local entries: { [string]: EntryUi } = {}
local openId: string? = nil
local lastId: string? = nil
local openChanged = Signal.new() :: Signal.Signal<string?>
local defaultOverride: (() -> string?)? = nil
local hiddenReasons: { [string]: boolean } = {}

------------------------------------------------------------------------------
-- Top bar
------------------------------------------------------------------------------

-- Smallest free part of Roblox's bar we accept to sit in (else: under it).
local MIN_BAR_HEIGHT = 24
-- Height assumed for Roblox's bar when nothing says how tall it is (the
-- new style, the tallest: our row then never ends up under its buttons).
local FALLBACK_LEFT = 216
local FALLBACK_TOP = 10

-- Where Roblox leaves room for us: (left x, top y, height, right x) in screen pixels.
-- In Roblox's bar, right of its buttons, when TopbarInset gives a usable
-- free area. Otherwise (not reported yet, hidden, too small, odd values):
-- our own row top left, UNDER Roblox's bar, never behind its buttons
-- (CoreGui is always drawn above every PlayerGui).
local function barArea(viewport: Vector2): (number, number, number, number)
	local inset = GuiService.TopbarInset
	local usable = inset.Height >= MIN_BAR_HEIGHT
		and inset.Max.Y <= viewport.Y * 0.5
		and inset.Min.X >= 0
		and inset.Max.X <= viewport.X + 1
		and inset.Max.X - inset.Min.X >= PILL + 12
	if usable then
		local height = math.min(PILL, inset.Height - 4)
		local top = math.max(0, inset.Min.Y + inset.Height - height - 2)
		return inset.Min.X + 4, top, height, inset.Max.X - 8
	end
	-- (Roblox doesn't say where its bar is: right of its usual buttons, on
	-- the same line - its logo and menu pills end about 210 px in)
	return FALLBACK_LEFT, FALLBACK_TOP, PILL, viewport.X - 12
end

-- Roblox's states: hover = white at 0.9 behind the icon; open = a pale
-- mark (a little stronger under the mouse). The icon stays white.
local function paintButton(ui: EntryUi, hovered: boolean)
	local open = openId == ui.entry.id
	ui.spot.BackgroundColor3 = if open then C.Spot else C.InkHi
	local transparency = if open then (if hovered then 0.72 else 0.78) elseif hovered then 0.9 else 1
	Theme.tween(ui.spot, Theme.FAST, { BackgroundTransparency = transparency })
end

local function layoutBar()
	local left, top, height = barArea(Theme.viewport())
	-- A shorter Roblox bar (old style, 36 px): our pills shrink to match.
	barScale.Scale = height / PILL
	-- (6 px of room above for the badges, which stick out)
	bar.Position = UDim2.fromOffset(left, top - 6 * barScale.Scale)
	-- The shared pill sits where its first section would.
	local first: number? = nil
	for _, ui in entries do
		if ui.entry.buttonText == nil and (first == nil or ui.entry.order < first) then
			first = ui.entry.order
		end
	end
	group.LayoutOrder = first or 0
	group.Visible = first ~= nil
end

-- One look, a few seconds in: a bar with no size, outside the screen or
-- with no buttons says so in Output (it used to vanish silently).
local function checkBarOnce()
	if next(hiddenReasons) ~= nil then
		return
	end
	local viewport = Theme.viewport()
	local position = bar.AbsolutePosition
	local size = bar.AbsoluteSize
	local problem: string? = nil
	if next(entries) == nil then
		problem = "no button registered"
	elseif size.X < 1 or size.Y < 1 then
		problem = "zero size"
	elseif
		position.X + size.X <= 0
		or position.Y + size.Y <= 0
		or position.X >= viewport.X
		or position.Y >= viewport.Y
	then
		problem = "off screen"
	elseif not gui.Enabled or gui.Parent == nil or not bar.Visible then
		problem = "hidden"
	end
	if problem then
		warn(
			`[Menu] top bar not visible ({problem}): position {position}, size {size}, `
				.. `viewport {viewport}, TopbarInset {GuiService.TopbarInset}, `
				.. `GuiInset {GuiService:GetGuiInset()}, pills {#bar:GetChildren() - 3}`
		)
	end
end

-- The round light behind an icon (Roblox's hover / open mark).
local function makeSpot(parent: Instance, size: UDim2): Frame
	return Theme.make("Frame", {
		Name = "Spot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = C.InkHi,
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
end

local function buildButton(entry: MenuEntry): EntryUi
	local word = entry.buttonText
	local button: TextButton
	local spot: Frame
	local icon: Frame
	local text: TextLabel? = nil
	if word then
		-- Its own pill: icon, then the word (like Roblox's labelled pills).
		local wordWidth = TextService:GetTextSize(
			word,
			LABEL_SIZE,
			Enum.Font.BuilderSansBold,
			Vector2.new(1000, 100)
		).X + 1
		button = Theme.make("TextButton", {
			Name = entry.id,
			LayoutOrder = entry.order,
			Size = UDim2.fromOffset(12 + ICON + 6 + wordWidth + 16, PILL),
			BackgroundColor3 = C.Pill,
			BackgroundTransparency = PILL_TRANSPARENCY,
			AutoButtonColor = false,
			Text = "",
			Parent = bar,
		}, {
			Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}) :: TextButton
		spot = makeSpot(button, UDim2.new(1, -8, 1, -8))
		icon = Icons.draw(entry.icon, button, ICON)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 12, 0.5, 0)
		text = Theme.text({
			Name = "Word",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12 + ICON + 6, 0.5, 0),
			Size = UDim2.fromOffset(wordWidth, 20),
			FontFace = Theme.Fonts.Display,
			TextSize = LABEL_SIZE,
			TextColor3 = C.InkHi,
			TextStrokeTransparency = 1,
			Text = word,
			Parent = button,
		}) :: TextLabel
	else
		-- A slot in the shared pill.
		button = Theme.make("TextButton", {
			Name = entry.id,
			LayoutOrder = entry.order,
			Size = UDim2.fromOffset(SLOT, PILL),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Parent = group,
		}) :: TextButton
		spot = makeSpot(button, UDim2.fromOffset(SPOT, SPOT))
		icon = Icons.draw(entry.icon, button, ICON)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
	end
	-- Top right of the icon, a little over the pill's edge (like Roblox's).
	local badgeAt = if word then UDim2.new(1, -8, 0, 9) else UDim2.new(0.5, 13, 0, 9)
	local badge, count = Panel.badge(button, badgeAt, 20)

	local ui: EntryUi = {
		entry = entry,
		button = button,
		spot = spot,
		icon = icon,
		text = text,
		badge = badge,
		count = count,
		panel = nil,
		plate = nil,
		view = nil,
		scale = nil,
		host = nil,
	}
	button.MouseEnter:Connect(function()
		paintButton(ui, true)
		if word == nil and not Theme.isTouch() then
			tooltip.Text = entry.hint or entry.label
			local position = button.AbsolutePosition
			local size = button.AbsoluteSize
			tooltip.Position = UDim2.fromOffset(position.X + size.X / 2, position.Y + size.Y + 6)
			tooltip.Visible = true
		end
	end)
	button.MouseLeave:Connect(function()
		paintButton(ui, false)
		tooltip.Visible = false
	end)
	button.Activated:Connect(function()
		tooltip.Visible = false
		MenuController.toggle(entry.id)
	end)
	return ui
end

------------------------------------------------------------------------------
-- Panels
------------------------------------------------------------------------------

local function headerHeight(entry: MenuEntry): number
	return TITLE_H + (if entry.subtitle then SUBTITLE_H else 0) + 8
end

local function tabsHeight(entry: MenuEntry): number
	return if entry.tabs then Panel.TAB_HEIGHT + TAB_GAP else 0
end

local function createPanel(ui: EntryUi)
	local entry = ui.entry
	local size = entry.size
	local header = headerHeight(entry)
	local tabsH = tabsHeight(entry)
	local plateWidth = size.X + 2 * PAD
	local panel = Theme.make("Frame", {
		Name = `{entry.id}Panel`,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(plateWidth, tabsH + size.Y + header + 2 * PAD),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = panelLayer,
	}) :: Frame
	local scale = Theme.make("UIScale", { Parent = panel }) :: UIScale
	local tabs: Panel.Tabs? = nil
	if entry.tabs then
		tabs = Panel.tabs(panel, entry.tabs)
	end
	local plate = Theme.make("Frame", {
		Name = "Plate",
		Position = UDim2.fromOffset(0, tabsH),
		Size = UDim2.new(1, 0, 1, -tabsH),
		BackgroundColor3 = C.Surface,
		BackgroundTransparency = Theme.SURFACE_TRANSPARENCY,
		Active = true, -- (clicks on the plate don't reach the game)
		Parent = panel,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS_LARGE) }),
	}) :: Frame
	-- The inner frame: the header on top (sections put their wallet there).
	local inner = Theme.make("Frame", {
		Name = "Inner",
		Position = UDim2.fromOffset(PAD, PAD - 4),
		Size = UDim2.new(1, -2 * PAD, 1, -2 * PAD + 4),
		BackgroundTransparency = 1,
		Parent = plate,
	}) :: Frame
	local host: Host = { tabs = tabs, header = inner }
	Theme.text({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, TITLE_H),
		FontFace = Theme.Fonts.Display,
		TextSize = 22,
		TextColor3 = C.InkHi,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = entry.label,
		Parent = inner,
	})
	if entry.subtitle then
		Theme.text({
			Name = "Subtitle",
			Position = UDim2.fromOffset(0, TITLE_H - 2),
			Size = UDim2.new(1, 0, 0, SUBTITLE_H),
			FontFace = Theme.Fonts.Label,
			TextSize = 13,
			TextColor3 = C.Muted,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = entry.subtitle,
			Parent = inner,
		})
	end
	-- A faint divider between the title and the content.
	Theme.make("Frame", {
		Name = "Divider",
		Position = UDim2.fromOffset(0, header - 5),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.InkHi,
		BackgroundTransparency = Theme.DIVIDER_TRANSPARENCY,
		Parent = inner,
	})
	-- The content scrolls when the screen is too short for it (layoutPanel).
	local view = Theme.make("ScrollingFrame", {
		Name = "View",
		Position = UDim2.fromOffset(-8, header),
		Size = UDim2.new(1, 16, 1, -header),
		CanvasSize = UDim2.fromOffset(size.X + 16, size.Y),
		BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = false,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Ink,
		ScrollBarImageTransparency = 1,
		Parent = inner,
	}) :: ScrollingFrame
	local content = Theme.make("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Parent = view,
	}) :: Frame
	ui.panel = panel
	ui.plate = plate
	ui.view = view
	ui.scale = scale
	ui.host = host
	entry.build(content, host)
end

-- Fits the open panel under the bar (see the top).
local function layoutPanel(ui: EntryUi)
	local panel = ui.panel
	local view = ui.view
	local scale = ui.scale
	if panel == nil or view == nil or scale == nil then
		return
	end
	local viewport = Theme.viewport()
	local entry = ui.entry
	local _, barTop, barHeight = barArea(viewport)
	local top = barTop + barHeight + SCREEN_GAP
	local freeHeight = viewport.Y - top - SCREEN_GAP
	local freeWidth = viewport.X - 2 * SCREEN_GAP
	local fixed = tabsHeight(entry) + headerHeight(entry) + 2 * PAD
	local width = entry.size.X + 2 * PAD
	local height = fixed + entry.size.Y
	local fit = math.min(Theme.scaleFor(viewport, 1), freeWidth / width, freeHeight / height)
	-- Readable first: the content scrolls rather than going under MIN_SCALE.
	local value = math.max(fit, math.min(MIN_SCALE, freeWidth / width))
	local visible =
		math.clamp(freeHeight / value - fixed, math.min(120, entry.size.Y), entry.size.Y)
	local scrolls = visible < entry.size.Y - 0.5
	scale.Scale = value
	panel.Size = UDim2.fromOffset(width, fixed + visible)
	panel.Position = UDim2.new(0.5, 0, 0, top)
	view.ScrollingEnabled = scrolls
	view.ScrollBarImageTransparency = if scrolls then 0.5 else 1
end

local function isInside(guiObject: GuiObject, point: Vector2): boolean
	local position = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return point.X >= position.X
		and point.Y >= position.Y
		and point.X <= position.X + size.X
		and point.Y <= position.Y + size.Y
end

-- Opens the panel a controller asked for (setDefaultOverride), else the
-- last one seen (the first of the bar the first time).
local function openDefault()
	local override = defaultOverride
	local wanted = if override then override() else nil
	local target = if wanted and entries[wanted] then wanted else lastId
	if target == nil then
		local best: EntryUi? = nil
		for _, ui in entries do
			if best == nil or ui.entry.order < best.entry.order then
				best = ui
			end
		end
		target = if best then best.entry.id else nil
	end
	if target then
		MenuController.open(target)
	end
end

local function refreshBarVisible()
	bar.Visible = next(hiddenReasons) == nil
	if not bar.Visible then
		tooltip.Visible = false
	end
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

function MenuController.register(entry: MenuEntry)
	assert(entries[entry.id] == nil, `menu entry "{entry.id}" registered twice`)
	entries[entry.id] = buildButton(entry)
	layoutBar()
end

function MenuController.open(id: string)
	local ui = entries[id]
	if ui == nil then
		return
	end
	local wasClosed = openId == nil
	if openId and openId ~= id then
		local previous = entries[openId]
		openId = id
		if previous then
			if previous.panel then
				previous.panel.Visible = false
			end
			paintButton(previous, false)
		end
	end
	if ui.panel == nil then
		createPanel(ui)
	end
	openId = id
	lastId = id
	local panel = ui.panel :: Frame
	local view = ui.view :: ScrollingFrame
	layoutPanel(ui)
	view.CanvasPosition = Vector2.zero
	panel.Visible = true
	-- A short drop from just above.
	local target = panel.Position
	panel.Position = target - UDim2.fromOffset(0, 8)
	Theme.tween(panel, OPEN_TIME, { Position = target }, Enum.EasingStyle.Quart)
	paintButton(ui, false)
	if wasClosed then
		CameraController.setCursorFree("menu", true)
	end
	openChanged.fire(id)
end

function MenuController.close()
	local id = openId
	if id == nil then
		return
	end
	openId = nil
	local ui = entries[id]
	if ui then
		if ui.panel then
			ui.panel.Visible = false
		end
		paintButton(ui, false)
	end
	CameraController.setCursorFree("menu", false)
	openChanged.fire(nil)
end

function MenuController.toggle(id: string)
	if openId == id then
		MenuController.close()
	else
		MenuController.open(id)
	end
end

-- Id of the open panel, or nil.
function MenuController.getOpen(): string?
	return openId
end

-- The white count on a section's button (0 hides it).
function MenuController.setBadge(id: string, count: number)
	local ui = entries[id]
	if ui then
		ui.badge.Visible = count > 0
		ui.count.Text = if count > 99 then "99+" else tostring(count)
	end
end

-- Hides the bar (and closes the panel) while any reason is set:
-- MenuController.setBarHidden("duelResult", true).
function MenuController.setBarHidden(reason: string, hidden: boolean)
	if hidden then
		hiddenReasons[reason] = true
	else
		hiddenReasons[reason] = nil
	end
	if hidden then
		MenuController.close()
	end
	refreshBarVisible()
end

-- Screen pixels just under the bar's left end (DuelController puts its
-- "Searching" line there).
function MenuController.underBar(): Vector2
	local viewport = Theme.viewport()
	local left, top, height = barArea(viewport)
	return Vector2.new(left + 4, top + height + 8)
end

-- While `pick` is set, the M key opens the panel it returns (nil: the
-- usual one). DuelController: the DUEL panel while searching.
function MenuController.setDefaultOverride(pick: (() -> string?)?)
	defaultOverride = pick
end

-- Fires with the id of the panel just opened, or nil when it closes.
function MenuController.onOpenChanged(callback: (string?) -> ()): Signal.Connection
	return openChanged.connect(callback)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

-- Built in init() so other controllers can register() from their own start().
function MenuController.init()
	gui = Theme.make("ScreenGui", {
		Name = "Menu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- (a plain row that grows with its pills: nothing clips them)
	bar = Theme.make("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Parent = gui,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, PILL_GAP),
		}),
		Theme.make("UIPadding", {
			PaddingLeft = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
	}) :: Frame
	barScale = Theme.make("UIScale", { Parent = bar }) :: UIScale
	group = Theme.make("Frame", {
		Name = "Group",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, PILL),
		BackgroundColor3 = C.Pill,
		BackgroundTransparency = PILL_TRANSPARENCY,
		Visible = false,
		Parent = bar,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Theme.make("UIPadding", {
			PaddingLeft = UDim.new(0, SLOT_EDGE),
			PaddingRight = UDim.new(0, SLOT_EDGE),
		}),
	}) :: Frame
	tooltip = Theme.text({
		Name = "Tooltip",
		AnchorPoint = Vector2.new(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundColor3 = C.Surface,
		BackgroundTransparency = Theme.SURFACE_TRANSPARENCY,
		FontFace = Theme.Fonts.Label,
		TextSize = 14,
		TextColor3 = C.InkHi,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS) }),
		Theme.make("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
	}) :: TextLabel
	panelLayer = Theme.make("Frame", {
		Name = "Panels",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	-- The screen or Roblox's bar changed (a window resized, a phone turned).
	Theme.onViewportChanged(function()
		layoutBar()
		local ui = if openId then entries[openId] else nil
		if ui then
			layoutPanel(ui)
		end
	end)

	-- Roblox can report its bar late (TopbarInset still empty at init): lay
	-- out again once everything has registered and once CoreGui settled,
	-- in case the change signal came before us or never comes.
	task.defer(layoutBar)
	task.delay(1, layoutBar)
	task.delay(3, function()
		layoutBar()
		task.defer(checkBarOnce)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Escape closes (even when Roblox's own menu takes the key).
		if input.KeyCode == Enum.KeyCode.Escape then
			MenuController.close()
			return
		end
		-- A click / tap outside the open panel and the bar closes it.
		local kind = input.UserInputType
		if
			openId and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch)
		then
			local ui = entries[openId]
			local panel = if ui then ui.panel else nil
			-- (InputObject positions start under Roblox's bar; ours don't)
			local inset = GuiService:GetGuiInset()
			local point = Vector2.new(input.Position.X, input.Position.Y) + inset
			if panel and not isInside(panel, point) and not isInside(bar, point) then
				-- (after every other listener: CombatController still sees the
				-- panel open, so the click that closes it is not a punch)
				task.defer(MenuController.close)
			end
			return
		end
		-- The menu key: opens the last panel, or closes the open one.
		if gameProcessed or input.KeyCode ~= Config.Controls.MENU then
			return
		end
		if openId then
			MenuController.close()
		elseif bar.Visible then
			openDefault()
		end
	end)
	-- Roblox's own menu opened: ours steps aside.
	GuiService.MenuOpened:Connect(function()
		MenuController.close()
	end)
end

return MenuController
