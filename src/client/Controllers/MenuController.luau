--!strict
-- MenuController: the game menu (everything that isn't fighting).
--
-- Closed: a discreet "— MENU" on the left edge of the screen.
-- Open: the world blurs and loses its colour, a numbered list of sections
-- on the left ("01 SETTINGS"...), the open section's panel next to it (big
-- light title, a subtitle, a hairline, then its content). "— CLOSE" (or the
-- MENU button again) closes it.
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
-- moves up and shrinks just enough for the open section to fit (its own
-- size); on a large screen it grows a little (Theme.scaleFor). Sections
-- build in the stage's pixels and never need to know.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local CameraController = require(script.Parent.CameraController)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local C = Theme.Colors

local ITEM_HEIGHT = 34
local DEFAULT_SIZE = Vector2.new(440, 280)
local DEFAULT_SCRIM_WIDTH = 900
local PANEL_TOP = 168
local OPEN_TIME = 0.25
local CLOSE_TIME = 0.15
-- What the stage must show: from just above the list (y 160) to under the
-- CLOSE button, from the left edge to the panel's right edge + a margin.
local STAGE_TOP = 160
local STAGE_MARGIN = 8 -- screen pixels kept free at the top and bottom

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
	item: TextButton,
	index: TextLabel,
	name: TextLabel,
	panel: Frame?, -- created the first time it's opened
}

local MenuController = {}

local gui: ScreenGui
local menuButton: TextButton
local openLayer: CanvasGroup -- everything shown while open (fades as one)
local fadeToken = 0
local nav: Frame
local marker: Frame
local panels: Frame
local scrimFrame: Frame
local closeButton: TextButton
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

-- A "— LABEL" text button with a hairline that grows on hover.
local function lineButton(text: string, props: { [string]: any }): TextButton
	props.BackgroundTransparency = 1
	props.Text = ""
	props.AutoButtonColor = false
	local button = Theme.make("TextButton", props, {
		Theme.make("Frame", {
			Name = "Line",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(18, 1),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.15,
		}),
		Theme.text({
			Name = "Label",
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(1, -28, 1, 0),
			TextTransparency = 0.15,
			Text = Theme.track(text, "four"),
		}),
	}) :: TextButton
	local line = button:FindFirstChild("Line") :: Frame
	local label = button:FindFirstChild("Label") :: TextLabel
	button.MouseEnter:Connect(function()
		Theme.tween(line, 0.15, { Size = UDim2.fromOffset(28, 1) })
		Theme.tween(label, 0.15, { Position = UDim2.fromOffset(38, 0), TextTransparency = 0 })
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(line, 0.15, { Size = UDim2.fromOffset(18, 1) })
		Theme.tween(label, 0.15, { Position = UDim2.fromOffset(28, 0), TextTransparency = 0.15 })
	end)
	return button
end

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
		ui.index.Text = string.format("%02d", position)
	end
end

local function setItemActive(ui: EntryUi, active: boolean)
	Theme.tween(ui.name, Theme.FAST, { TextColor3 = if active then C.Ink else C.Ink3 })
	Theme.tween(ui.index, Theme.FAST, { TextColor3 = if active then C.Ink2 else C.Ink3 })
	if active then
		marker.Visible = true
		Theme.tween(marker, 0.18, {
			Position = UDim2.fromOffset(
				-16,
				Theme.unscaled(nav, ui.item.AbsolutePosition.Y - nav.AbsolutePosition.Y) + 11
			),
		}, Enum.EasingStyle.Quart)
	end
end

-- Fits the stage to the screen for a panel of `size` (see the top).
local function layoutStage(size: Vector2)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local viewport = camera.ViewportSize
	local bottom = PANEL_TOP + size.Y + 12 + 16 + 12 -- under CLOSE
	local height = bottom - STAGE_TOP
	local width = 300 + size.X + 40
	-- (scaleFor with a floor of 1: never smaller than drawn by itself, only
	-- when the section does not fit; bigger on a large screen)
	local scale = math.min(
		Theme.scaleFor(viewport, 1),
		(viewport.Y - 2 * STAGE_MARGIN) / height,
		(viewport.X - 2 * STAGE_MARGIN) / width
	)
	scale = math.max(scale, 0.4)
	-- Where it was drawn (y 160) if it fits there, else as high as needed.
	local top = math.max(
		STAGE_MARGIN,
		math.min(STAGE_TOP * scale, viewport.Y - STAGE_MARGIN - height * scale)
	)
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

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

function MenuController.register(entry: MenuEntry)
	assert(entries[entry.id] == nil, `menu entry "{entry.id}" registered twice`)

	local item = Theme.make("TextButton", {
		Name = entry.id,
		LayoutOrder = entry.order,
		Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = nav:FindFirstChild("Items"),
	}, {
		Theme.text({
			Name = "Index",
			Size = UDim2.new(0, 18, 1, 0),
			FontFace = Theme.Fonts.Number,
			TextSize = 10,
			TextColor3 = C.Ink3,
			TextStrokeTransparency = 1,
			Text = "00",
		}),
		Theme.text({
			Name = "Name",
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -30, 1, 0),
			TextSize = 13,
			TextColor3 = C.Ink3,
			TextStrokeTransparency = 1,
			Text = Theme.track(entry.label, "four"),
		}),
	}) :: TextButton

	local ui: EntryUi = {
		entry = entry,
		item = item,
		index = item:FindFirstChild("Index") :: TextLabel,
		name = item:FindFirstChild("Name") :: TextLabel,
		panel = nil,
	}
	entries[entry.id] = ui
	renumber()

	item.MouseEnter:Connect(function()
		if openId ~= entry.id then
			Theme.tween(ui.name, 0.1, { TextColor3 = C.Ink2 })
		end
	end)
	item.MouseLeave:Connect(function()
		if openId ~= entry.id then
			Theme.tween(ui.name, 0.1, { TextColor3 = C.Ink3 })
		end
	end)
	item.Activated:Connect(function()
		MenuController.open(entry.id)
	end)
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

	if wasClosed then
		fadeToken += 1
		openLayer.Visible = true
		Theme.tween(openLayer, OPEN_TIME, { GroupTransparency = 0 })
		menuButton.Visible = false
		setWorldDimmed(true)
		CameraController.setCursorFree("menu", true)
		-- Slide in from the left.
		nav.Position = UDim2.fromOffset(48, 176)
		panels.Position = UDim2.fromOffset(284, 168)
		Theme.tween(nav, 0.22, { Position = UDim2.fromOffset(64, 176) }, Enum.EasingStyle.Quart)
		task.delay(0.04, function()
			Theme.tween(
				panels,
				0.22,
				{ Position = UDim2.fromOffset(300, 168) },
				Enum.EasingStyle.Quart
			)
		end)
	end
	-- This section's size: the panel, the backdrop and the CLOSE button follow.
	local size = ui.entry.size or DEFAULT_SIZE
	panels.Size = UDim2.fromOffset(size.X, size.Y)
	closeButton.Position = UDim2.fromOffset(300, PANEL_TOP + size.Y + 12)
	local scrimWidth = ui.entry.scrimWidth or DEFAULT_SCRIM_WIDTH
	scrimWidthNow = scrimWidth
	layoutStage(size) -- (sets the backdrop's width at once)
	if not wasClosed then
		-- (from the old width: slides to the new one)
		local target = scrimFrame.Size
		scrimFrame.Size = UDim2.new(0, previousScrim, 1, 0)
		Theme.tween(scrimFrame, 0.2, { Size = target }, Enum.EasingStyle.Quart)
	end
	(ui.panel :: Frame).Visible = true
	-- Wait a frame so the item has its position before moving the marker.
	task.defer(setItemActive, ui, true)
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
	menuButton.Visible = true
	marker.Visible = false
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

	menuButton = lineButton("MENU", {
		Name = "MenuButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, -24),
		Size = UDim2.fromOffset(120, 16),
		Parent = gui,
	})
	menuButton.Activated:Connect(function()
		local target = lastId
		if target == nil then
			-- First time: the first section of the list.
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
	end)

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
	local divider = openLayer:FindFirstChild("Divider")
	if divider then
		divider.Parent = stage
	end

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
			Theme.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		}),
	})
	marker = Theme.make("Frame", {
		Name = "Marker",
		Size = UDim2.fromOffset(2, 12),
		BackgroundColor3 = C.Ink,
		Visible = false,
		Parent = nav,
	})

	panels = Theme.make("Frame", {
		Name = "Panels",
		Position = UDim2.fromOffset(300, 168),
		Size = UDim2.fromOffset(440, 280),
		BackgroundTransparency = 1,
		Parent = stage,
	})

	closeButton = lineButton("CLOSE", {
		Name = "Close",
		Position = UDim2.fromOffset(300, PANEL_TOP + DEFAULT_SIZE.Y + 12),
		Size = UDim2.fromOffset(120, 16),
		Parent = stage,
	})
	closeButton.Activated:Connect(MenuController.close)
	scrimFrame = openLayer:FindFirstChild("Scrim") :: Frame
	-- The screen changed size (a window resized, a phone turned): refit.
	Theme.onViewportChanged(function()
		layoutStage(currentSize())
	end)
	-- The closed "— MENU" button follows the screen too (from its left edge).
	Theme.autoScale(menuButton, 0.8)

	-- World effects, local to this player (they live in Lighting on the client).
	blur = Theme.make("BlurEffect", { Name = "MenuBlur", Size = 0, Parent = Lighting })
	grade = Theme.make("ColorCorrectionEffect", { Name = "MenuGrade", Parent = Lighting })
end

return MenuController
