--!strict
-- MenuController: the top bar buttons and their panels (everything that
-- isn't fighting).
--
-- Top bar: a row of dark round buttons right next to Roblox's own (menu,
-- chat...), the same height and look: an icon, a short word on some
-- ("Kits"), a small white count when there is something to look at.
-- One button per section. A button opens its OWN panel; the same button,
-- Escape, or a click / tap outside the panel closes it. One panel at a
-- time (opening another one swaps them). The menu key (M) opens the last
-- panel seen and closes the open one (not while typing in the chat).
--
-- Panel: one black see-through plate (no border) under the top bar,
-- centred: optional small tabs above it on the left, a bold centred title
-- (and a grey line under it), then the section's content.
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

-- Top bar buttons (like Roblox's own: 44 px round plates).
local PILL = 44
local PILL_GAP = 8
local ICON = 22
local LABEL_SIZE = 17
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
	baseWidth: number, -- the button's width at the full 44 px height
	button: TextButton,
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
local bar: ScrollingFrame -- the row of buttons
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

-- Where Roblox leaves room for us: (left x, top y, height, right x) in screen pixels.
local function barArea(viewport: Vector2): (number, number, number, number)
	local inset = GuiService.TopbarInset
	if inset.Height <= 0 then
		-- No Roblox bar reported (hidden, old client): our own row top left.
		return 12, 12, PILL, viewport.X - 12
	end
	local height = math.min(PILL, inset.Height - 4)
	local top = math.max(0, inset.Height - height - 2)
	return inset.Min.X + 4, top, height, inset.Max.X - 8
end

local function paintButton(ui: EntryUi, hovered: boolean)
	local open = openId == ui.entry.id
	ui.button.BackgroundColor3 = if open then C.InkHi else C.Pill
	ui.button.BackgroundTransparency = if open then 0.05 elseif hovered then 0.12 else 0.3
	local ink = if open then C.Scrim else C.InkHi
	Icons.paint(ui.icon, ink)
	local text = ui.text
	if text then
		text.TextColor3 = ink
	end
end

local function layoutBar()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local viewport = camera.ViewportSize
	local left, top, height, right = barArea(viewport)
	-- A shorter Roblox bar (old style, 36 px): our buttons shrink to match.
	local scale = height / PILL
	local width = 0
	local count = 0
	for _, ui in entries do
		local holder = ui.button.Parent :: Frame
		holder.Size = UDim2.fromOffset(math.floor(ui.baseWidth * scale + 0.5), height)
		width += holder.Size.X.Offset
		count += 1
	end
	width += math.max(count - 1, 0) * PILL_GAP
	local room = math.max(height, right - left)
	-- (6 px of room above and right for the badges, which stick out)
	bar.Position = UDim2.fromOffset(left, top - 6)
	bar.Size = UDim2.fromOffset(math.min(width + 12, room), height + 12)
	bar.CanvasSize = UDim2.new(0, width + 12, 1, 0)
	bar.ScrollingEnabled = width + 12 > room
end

local function buildButton(entry: MenuEntry): EntryUi
	local word = entry.buttonText
	local wordWidth = if word
		then TextService:GetTextSize(
			word,
			LABEL_SIZE,
			Enum.Font.BuilderSansMedium,
			Vector2.new(1000, 100)
		).X + 2
		else 0
	local width = if word then 14 + ICON + 8 + wordWidth + 16 else PILL
	local holder = Theme.make("Frame", {
		Name = entry.id,
		LayoutOrder = entry.order,
		Size = UDim2.fromOffset(width, PILL),
		BackgroundTransparency = 1,
		Parent = bar,
	}) :: Frame
	local button = Theme.make("TextButton", {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Pill,
		BackgroundTransparency = 0.3,
		AutoButtonColor = false,
		Text = "",
		Parent = holder,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: TextButton
	local icon = Icons.draw(entry.icon, button, ICON)
	icon.AnchorPoint = Vector2.new(if word then 0 else 0.5, 0.5)
	icon.Position = if word then UDim2.new(0, 14, 0.5, 0) else UDim2.fromScale(0.5, 0.5)
	local text: TextLabel? = nil
	if word then
		text = Theme.text({
			Name = "Word",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14 + ICON + 8, 0.5, 0),
			Size = UDim2.fromOffset(wordWidth, 20),
			FontFace = Theme.Fonts.Label,
			TextSize = LABEL_SIZE,
			TextColor3 = C.InkHi,
			TextStrokeTransparency = 1,
			Text = word,
			Parent = button,
		}) :: TextLabel
	end
	local badge, count = Panel.badge(button, UDim2.new(1, -4, 0, 4), 20)

	local ui: EntryUi = {
		entry = entry,
		baseWidth = width,
		button = button,
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
	local host: Host = {}
	if entry.tabs then
		host.tabs = Panel.tabs(panel, entry.tabs)
	end
	local plate = Theme.make("Frame", {
		Name = "Plate",
		Position = UDim2.fromOffset(0, tabsH),
		Size = UDim2.new(1, 0, 1, -tabsH),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = Theme.PANEL_TRANSPARENCY,
		Active = true, -- (clicks on the plate don't reach the game)
		Parent = panel,
	}) :: Frame
	-- The inner frame: the header on top (sections put their wallet there).
	local inner = Theme.make("Frame", {
		Name = "Inner",
		Position = UDim2.fromOffset(PAD, PAD - 4),
		Size = UDim2.new(1, -2 * PAD, 1, -2 * PAD + 4),
		BackgroundTransparency = 1,
		Parent = plate,
	}) :: Frame
	Theme.text({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, TITLE_H),
		FontFace = Theme.Fonts.Display,
		TextSize = 24,
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
			TextColor3 = C.Ink2,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = entry.subtitle,
			Parent = inner,
		})
	end
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
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local viewport = camera.ViewportSize
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
	hiddenReasons[reason] = if hidden then true else nil
	if hidden then
		MenuController.close()
	end
	refreshBarVisible()
end

-- Screen pixels just under the bar's left end (DuelController puts its
-- "Searching" line there).
function MenuController.underBar(): Vector2
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
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
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
	bar = Theme.make("ScrollingFrame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollingEnabled = false,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		ElasticBehavior = Enum.ElasticBehavior.Never,
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
	}) :: ScrollingFrame
	tooltip = Theme.text({
		Name = "Tooltip",
		AnchorPoint = Vector2.new(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = C.Pill,
		BackgroundTransparency = 0.2,
		FontFace = Theme.Fonts.Label,
		TextSize = 13,
		TextColor3 = C.InkHi,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Theme.make("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
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
