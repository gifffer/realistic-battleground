--!strict
-- MenuController: the game menu (everything that isn't fighting).
--
-- Closed: a real MENU button on the left edge of the screen (an icon, the
-- word and, on a PC, its key "M"). Until the menu is opened once it sends
-- out a soft accent ring, so new players see it.
-- Open: the world blurs and loses its colour, a numbered list of sections
-- on the left (tab buttons "01 KITS"...; the open one is outlined in the
-- accent colour with a bar), the open section's panel next to it (big
-- light title, a subtitle, a hairline, then its content). CLOSE (or the M
-- key) closes it. The M key also opens it (not while typing in the chat).
--
-- Design rule: keys are for fighting; everything else is in this menu.
-- Each feature ADDS ITS OWN section from its controller:
--
--   MenuController.register({
--       id = "Settings",              -- unique name
--       label = "SETTINGS",           -- name in the list (English, caps)
--       subtitle = "CAMERA · CONTROLS",
--       order = 100,                  -- position in the list (small = top)
--       build = function(content: Frame) ... end, -- fills the panel, once
--       size = Vector2.new(560, 480), -- optional: a bigger panel (default 440 × 280)
--       scrimWidth = 1100,            -- optional: a wider dark backdrop (default 900)
--   })
--
-- While the menu is open the mouse cursor is free
-- (CameraController.setCursorFree("menu", ...)).
--
-- Screen size: the list, the panel and CLOSE sit on one "stage" drawn for
-- 1920 × 1080. On a smaller screen (a phone, a small window) the stage
-- moves up (never under Roblox's top bar) and shrinks just enough for the
-- open section to fit (its own size); on a large screen it grows a little
-- (Theme.scaleFor). It never shrinks under ×0.8 (text stays readable): a
-- section still too tall then scrolls. On a short or narrow screen the list
-- sits closer to the left edge (a narrower left column) so the panel gets
-- the room. Sections build in the stage's pixels and never need to know.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Button = require(script.Parent.Parent.UI.Button)
local CameraController = require(script.Parent.CameraController)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local C = Theme.Colors

local ITEM_GAP = 6 -- between two section buttons
local DEFAULT_SIZE = Vector2.new(440, 280)
local DEFAULT_SCRIM_WIDTH = 900
local PANEL_TOP = 168
local OPEN_TIME = 0.25
local CLOSE_TIME = 0.15
-- What the stage must show: from just above the list (y 160) to under the
-- CLOSE button, from the left edge to the panel's right edge + a margin.
local STAGE_TOP = 160
local STAGE_MARGIN = 8 -- screen pixels kept free at the top and bottom
local MIN_TEXT_SCALE = 0.8 -- under this the 10 px captions can't be read
local MIN_VISIBLE = 120 -- shortest visible panel when it scrolls
-- The panel's scrolling window reaches this far past each side, so the
-- markers drawn just left of a section's content (x -16) aren't cut off.
local GUTTER = 24

-- Where the left column and the panel sit (stage pixels).
type Layout = {
	navX: number,
	navWidth: number,
	dividerX: number,
	panelX: number,
	right: number, -- room kept right of the panel
}
local REGULAR: Layout = { navX = 64, navWidth = 180, dividerX = 268, panelX = 300, right = 40 }
-- Short or narrow screen (a phone held sideways): a narrower left column.
local COMPACT: Layout = { navX = 20, navWidth = 156, dividerX = 188, panelX = 208, right = 16 }
local COMPACT_BELOW = Vector2.new(1000, 540)

export type MenuEntry = {
	id: string,
	label: string,
	subtitle: string?,
	order: number,
	build: (content: Frame) -> (),
	size: Vector2?,
	scrimWidth: number?,
}

type EntryUi = {
	entry: MenuEntry,
	button: Button.Button,
	panel: Frame?, -- created the first time it's opened
}

local MenuController = {}

local gui: ScreenGui
local menuButton: Button.Button
local everOpened = false -- the MENU button pulses until then
local openLayer: CanvasGroup -- everything shown while open (fades as one)
local fadeToken = 0
local nav: Frame
local panels: Frame -- one panel per section, inside panelsView
local panelsView: ScrollingFrame -- scrolls when a section can't fit
local divider: Frame
local scrimFrame: Frame
local closeButton: Button.Button
local stage: Frame -- nav, panels and CLOSE (scaled together)
local stageScale: UIScale
local scrimWidthNow = DEFAULT_SCRIM_WIDTH -- unscaled
local blur: BlurEffect
local grade: ColorCorrectionEffect
local entries: { [string]: EntryUi } = {}
local openId: string? = nil
local lastId: string? = nil
local openChanged = Signal.new() :: Signal.Signal<string?>

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function createPanel(entry: MenuEntry): Frame
	local panel = Theme.make("Frame", {
		Name = `{entry.id}Panel`,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = panels,
	}, {
		Theme.text({
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 44),
			FontFace = Theme.Fonts.Display,
			TextSize = 40,
			TextStrokeTransparency = 1,
			Text = Theme.track(entry.label, "thin"),
		}),
		Theme.text({
			Name = "Subtitle",
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 0, 12),
			TextSize = 10,
			TextColor3 = C.Ink3,
			TextStrokeTransparency = 1,
			Text = Theme.track(entry.subtitle or "", "three"),
		}),
		Theme.make("Frame", {
			Name = "Rule",
			Position = UDim2.fromOffset(0, 90),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.78,
		}),
		Theme.make("Frame", {
			Name = "Content",
			Position = UDim2.fromOffset(0, 116),
			Size = UDim2.new(1, 0, 1, -116),
			BackgroundTransparency = 1,
		}),
	}) :: Frame
	entry.build(panel:FindFirstChild("Content") :: Frame)
	return panel
end

-- Renumbers the list (01, 02...) in display order.
local function renumber()
	local list = {}
	for _, ui in entries do
		table.insert(list, ui)
	end
	table.sort(list, function(a, b)
		return a.entry.order < b.entry.order
	end)
	for position, ui in list do
		local index = ui.button.index
		if index then
			index.Text = string.format("%02d", position)
		end
	end
end

local function setItemActive(ui: EntryUi, active: boolean)
	ui.button.setSelected(active)
	local index = ui.button.index
	if index then
		Theme.tween(index, Theme.FAST, { TextColor3 = if active then C.Accent else C.Ink3 })
	end
end

-- Fits the stage to the screen for a panel of `size` (see the top).
local function layoutStage(size: Vector2)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local viewport = camera.ViewportSize
	local layout = if viewport.X < COMPACT_BELOW.X or viewport.Y < COMPACT_BELOW.Y
		then COMPACT
		else REGULAR
	nav.Position = UDim2.fromOffset(layout.navX, 176)
	nav.Size = UDim2.fromOffset(layout.navWidth, 300)
	divider.Position = UDim2.fromOffset(layout.dividerX, 176)
	panelsView.Position = UDim2.fromOffset(layout.panelX - GUTTER, PANEL_TOP)

	-- Free screen: under Roblox's top bar (its buttons are on the left,
	-- right where the list is), above the bottom margin.
	local topMargin = math.max(STAGE_MARGIN, Theme.topInset("left", viewport) + 8)
	local freeHeight = viewport.Y - topMargin - STAGE_MARGIN
	local freeWidth = viewport.X - 2 * STAGE_MARGIN
	-- Stage pixels above and under the panel: the list's top, CLOSE.
	local closeHeight = closeButton.instance.Size.Y.Offset
	local around = PANEL_TOP - STAGE_TOP + 12 + closeHeight + 12
	local width = layout.panelX + size.X + layout.right
	-- (scaleFor with a floor of 1: never smaller than drawn by itself, only
	-- when the section does not fit; bigger on a large screen)
	local scale =
		math.min(Theme.scaleFor(viewport, 1), freeHeight / (around + size.Y), freeWidth / width)
	-- Readable first: the panel scrolls rather than going under ×0.8 (the
	-- width must still fit: only a tiny screen goes under it).
	scale = math.max(scale, math.min(MIN_TEXT_SCALE, freeWidth / width), 0.4)
	local visible = math.clamp(freeHeight / scale - around, math.min(MIN_VISIBLE, size.Y), size.Y)
	local scrolls = visible < size.Y - 0.5
	panelsView.Size = UDim2.fromOffset(size.X + 2 * GUTTER, visible)
	panelsView.CanvasSize = UDim2.fromOffset(size.X + 2 * GUTTER, size.Y)
	panelsView.ScrollingEnabled = scrolls
	panelsView.ScrollBarImageTransparency = if scrolls then 0.6 else 1
	panels.Size = UDim2.fromOffset(size.X, size.Y)
	closeButton.instance.Position = UDim2.fromOffset(layout.panelX, PANEL_TOP + visible + 12)

	-- Where it was drawn (y 160) if it fits there, else as high as needed.
	local height = around + visible
	local top =
		math.max(topMargin, math.min(STAGE_TOP * scale, viewport.Y - STAGE_MARGIN - height * scale))
	stageScale.Scale = scale
	stage.Position = UDim2.fromOffset(0, top - STAGE_TOP * scale)
	scrimFrame.Size = UDim2.new(0, scrimWidthNow * scale, 1, 0)
end

local function currentSize(): Vector2
	local ui = if openId then entries[openId] else nil
	return if ui and ui.entry.size then ui.entry.size else DEFAULT_SIZE
end

-- Blur + desaturation of the world behind the menu.
local function setWorldDimmed(dimmed: boolean)
	local time = if dimmed then OPEN_TIME else CLOSE_TIME
	Theme.tween(blur, time, { Size = if dimmed then 10 else 0 })
	Theme.tween(grade, time, {
		Saturation = if dimmed then -0.5 else 0,
		Brightness = if dimmed then -0.08 else 0,
	})
end

-- Opens the last section seen (the first of the list the first time).
local function openDefault()
	local target = lastId
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

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

-- Where the closed MENU button's centre sits: this many pixels from the
-- middle of the screen's left edge (DuelController puts its status under it).
MenuController.BUTTON_Y = -30

function MenuController.register(entry: MenuEntry)
	assert(entries[entry.id] == nil, `menu entry "{entry.id}" registered twice`)

	local button = Button.new({
		name = entry.id,
		text = entry.label,
		variant = "tab",
		index = "00",
		layoutOrder = entry.order,
		height = Button.height("medium") + 4,
		fillWidth = true, -- as wide as the list
		parent = nav:FindFirstChild("Items"),
		onActivated = function()
			MenuController.open(entry.id)
		end,
	})

	entries[entry.id] = {
		entry = entry,
		button = button,
		panel = nil,
	}
	renumber()
end

function MenuController.open(id: string)
	local ui = entries[id]
	if ui == nil then
		return
	end
	local wasClosed = openId == nil
	local previousScrim = scrimFrame.Size.X.Offset
	if openId and openId ~= id then
		local previous = entries[openId]
		if previous and previous.panel then
			previous.panel.Visible = false
			setItemActive(previous, false)
		end
	end
	if ui.panel == nil then
		ui.panel = createPanel(ui.entry)
	end
	openId = id
	lastId = id

	-- This section's size: the panel, the backdrop and the CLOSE button
	-- follow (layoutStage), from the top of the section.
	local size = ui.entry.size or DEFAULT_SIZE
	scrimWidthNow = ui.entry.scrimWidth or DEFAULT_SCRIM_WIDTH
	layoutStage(size) -- (sets the backdrop's width at once)
	panelsView.CanvasPosition = Vector2.zero
	if wasClosed then
		fadeToken += 1
		openLayer.Visible = true
		Theme.tween(openLayer, OPEN_TIME, { GroupTransparency = 0 })
		menuButton.instance.Visible = false
		if not everOpened then
			everOpened = true
			menuButton.pulse(false)
		end
		setWorldDimmed(true)
		CameraController.setCursorFree("menu", true)
		-- Slide in from the left (to where layoutStage put them).
		local navTarget = nav.Position
		local panelsTarget = panelsView.Position
		nav.Position = navTarget - UDim2.fromOffset(16, 0)
		panelsView.Position = panelsTarget - UDim2.fromOffset(16, 0)
		Theme.tween(nav, 0.22, { Position = navTarget }, Enum.EasingStyle.Quart)
		task.delay(0.04, function()
			Theme.tween(panelsView, 0.22, { Position = panelsTarget }, Enum.EasingStyle.Quart)
		end)
	else
		-- (from the old width: slides to the new one)
		local target = scrimFrame.Size
		scrimFrame.Size = UDim2.new(0, previousScrim, 1, 0)
		Theme.tween(scrimFrame, 0.2, { Size = target }, Enum.EasingStyle.Quart)
	end
	(ui.panel :: Frame).Visible = true
	setItemActive(ui, true)
	openChanged.fire(id)
end

function MenuController.close()
	local id = openId
	if id == nil then
		return
	end
	local ui = entries[id]
	if ui then
		if ui.panel then
			ui.panel.Visible = false
		end
		setItemActive(ui, false)
	end
	openId = nil
	-- Fade out, then hide (unless it was reopened meanwhile).
	fadeToken += 1
	local token = fadeToken
	Theme.tween(
		openLayer,
		CLOSE_TIME,
		{ GroupTransparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(CLOSE_TIME, function()
		if fadeToken == token then
			openLayer.Visible = false
		end
	end)
	menuButton.instance.Visible = true
	setWorldDimmed(false)
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

-- Id of the open section, or nil.
function MenuController.getOpen(): string?
	return openId
end

-- Fires with the id of the section just opened, or nil when the menu closes.
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

	menuButton = Button.new({
		name = "MenuButton",
		text = "MENU",
		icon = "menu",
		keyHint = Config.Controls.MENU.Name,
		size = "large",
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 16, 0.5, MenuController.BUTTON_Y),
		parent = gui,
		onActivated = openDefault,
	})
	menuButton.pulse(true)

	openLayer = Theme.make("CanvasGroup", {
		Name = "Open",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		-- Dark from the left, fading into the (blurred) world.
		Theme.make("Frame", {
			Name = "Scrim",
			Size = UDim2.new(0, 900, 1, 0),
			BackgroundColor3 = C.Scrim,
		}, { Theme.gradient(0, { { 0, 0.1 }, { 0.38, 0.18 }, { 0.66, 0.55 }, { 1, 1 } }) }),
		Theme.make("Frame", {
			Name = "Divider",
			Position = UDim2.fromOffset(268, 176),
			Size = UDim2.fromOffset(1, 196),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.86,
		}),
	})

	-- The stage (see the top): everything but the backdrop.
	stage = Theme.make("Frame", {
		Name = "Stage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = openLayer,
	})
	stageScale = Theme.make("UIScale", { Name = "StageScale", Parent = stage })
	divider = openLayer:FindFirstChild("Divider") :: Frame
	divider.Parent = stage

	nav = Theme.make("Frame", {
		Name = "Nav",
		Position = UDim2.fromOffset(64, 176),
		Size = UDim2.fromOffset(180, 260),
		BackgroundTransparency = 1,
		Parent = stage,
	}, {
		Theme.text({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 12),
			TextSize = 10,
			TextColor3 = C.Ink3,
			TextStrokeTransparency = 1,
			Text = Theme.track("MENU", "three"),
		}),
		Theme.make("Frame", {
			Name = "Items",
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 1, -34),
			BackgroundTransparency = 1,
		}, {
			Theme.make("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ITEM_GAP),
			}),
		}),
	})

	-- (sized by layoutStage; scrolls only when the section can't fit)
	panelsView = Theme.make("ScrollingFrame", {
		Name = "PanelsView",
		Position = UDim2.fromOffset(REGULAR.panelX - GUTTER, PANEL_TOP),
		Size = UDim2.fromOffset(DEFAULT_SIZE.X + 2 * GUTTER, DEFAULT_SIZE.Y),
		CanvasSize = UDim2.fromOffset(DEFAULT_SIZE.X + 2 * GUTTER, DEFAULT_SIZE.Y),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = false,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = C.Ink,
		ScrollBarImageTransparency = 1,
		Parent = stage,
	}) :: ScrollingFrame
	panels = Theme.make("Frame", {
		Name = "Panels",
		Position = UDim2.fromOffset(GUTTER, 0),
		Size = UDim2.fromOffset(DEFAULT_SIZE.X, DEFAULT_SIZE.Y),
		BackgroundTransparency = 1,
		Parent = panelsView,
	})

	closeButton = Button.new({
		name = "Close",
		text = "CLOSE",
		icon = "close",
		keyHint = Config.Controls.MENU.Name,
		minWidth = 120,
		position = UDim2.fromOffset(300, PANEL_TOP + DEFAULT_SIZE.Y + 12),
		parent = stage,
		onActivated = MenuController.close,
	})
	scrimFrame = openLayer:FindFirstChild("Scrim") :: Frame
	-- The screen changed size (a window resized, a phone turned): refit.
	Theme.onViewportChanged(function()
		layoutStage(currentSize())
	end)
	-- The closed MENU button follows the screen too (from its left edge).
	Theme.autoScale(menuButton.instance, 0.8)

	-- The menu key: opens the menu (last section) or closes it.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.KeyCode ~= Config.Controls.MENU then
			return
		end
		if openId then
			MenuController.close()
		elseif menuButton.instance.Visible then
			openDefault()
		end
	end)

	-- World effects, local to this player (they live in Lighting on the client).
	blur = Theme.make("BlurEffect", { Name = "MenuBlur", Size = 0, Parent = Lighting })
	grade = Theme.make("ColorCorrectionEffect", { Name = "MenuGrade", Parent = Lighting })
end

return MenuController
