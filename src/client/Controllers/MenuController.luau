--!strict
-- MenuController: the side menu (buttons on the left of the screen) and the
-- windows they open.
--
-- Design rule: keys are for fighting; everything else is a button that opens
-- a window. Each feature ADDS ITS OWN entry from its controller:
--
--   MenuController.register({
--       id = "Settings",          -- unique name
--       label = "SETTINGS",       -- text on the button (English)
--       order = 100,              -- position in the menu (small = top)
--       build = function(content: Frame) ... end, -- fills the window, once
--   })
--
-- Only one window is open at a time. While a window is open the mouse
-- cursor is free (CameraController.setCursorFree("menu", ...)).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local CameraController = require(script.Parent.CameraController)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local BUTTON_SIZE = Vector2.new(96, 40)
local WINDOW_SIZE = Vector2.new(460, 340)
local TITLE_HEIGHT = 44

export type MenuEntry = {
	id: string,
	label: string,
	order: number,
	build: (content: Frame) -> (),
}

type EntryUi = {
	entry: MenuEntry,
	button: TextButton,
	window: Frame?, -- created the first time it's opened
}

local MenuController = {}

local gui: ScreenGui
local sideBar: Frame
local entries: { [string]: EntryUi } = {}
local openId: string? = nil
local openChanged = Signal.new() :: Signal.Signal<string?>

local function createWindow(entry: MenuEntry): Frame
	local window = Theme.make("Frame", {
		Name = `{entry.id}Window`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		Parent = gui,
	}, {
		Theme.corner(),
		Theme.make("UIStroke", { Color = Theme.Colors.PanelLight, Thickness = 1 }),
		Theme.make("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -72, 0, TITLE_HEIGHT),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Title,
			TextSize = 20,
			TextColor3 = Theme.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = entry.label,
		}),
		Theme.make("TextButton", {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = Theme.Colors.PanelLight,
			Font = Theme.Fonts.Bold,
			TextSize = 16,
			TextColor3 = Theme.Colors.Text,
			Text = "X",
			AutoButtonColor = true,
		}, { Theme.corner() }),
		Theme.make("Frame", {
			Name = "Content",
			Position = UDim2.fromOffset(0, TITLE_HEIGHT),
			Size = UDim2.new(1, 0, 1, -TITLE_HEIGHT),
			BackgroundTransparency = 1,
		}, { Theme.padding(16) }),
	})

	window.Close.Activated:Connect(function()
		MenuController.close()
	end)
	entry.build(window.Content)
	return window
end

local function setButtonActive(ui: EntryUi, active: boolean)
	ui.button.BackgroundColor3 = if active then Theme.Colors.Accent else Theme.Colors.Panel
	ui.button.TextColor3 = if active then Theme.Colors.Background else Theme.Colors.Text
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

function MenuController.register(entry: MenuEntry)
	assert(entries[entry.id] == nil, `menu entry "{entry.id}" registered twice`)

	local button = Theme.make("TextButton", {
		Name = entry.id,
		LayoutOrder = entry.order,
		Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.1,
		Font = Theme.Fonts.Bold,
		TextSize = 13,
		TextColor3 = Theme.Colors.Text,
		Text = entry.label,
		AutoButtonColor = true,
		Parent = sideBar,
	}, { Theme.corner() }) :: TextButton

	entries[entry.id] = { entry = entry, button = button, window = nil }

	button.Activated:Connect(function()
		MenuController.toggle(entry.id)
	end)
end

function MenuController.open(id: string)
	local ui = entries[id]
	if ui == nil then
		return
	end
	if openId and openId ~= id then
		MenuController.close()
	end
	if ui.window == nil then
		ui.window = createWindow(ui.entry)
	end
	(ui.window :: Frame).Visible = true
	setButtonActive(ui, true)
	openId = id
	CameraController.setCursorFree("menu", true)
	openChanged.fire(id)
end

function MenuController.close()
	local id = openId
	if id == nil then
		return
	end
	local ui = entries[id]
	if ui and ui.window then
		ui.window.Visible = false
		setButtonActive(ui, false)
	end
	openId = nil
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

-- Id of the open window, or nil.
function MenuController.getOpen(): string?
	return openId
end

-- Fires with the id of the window just opened, or nil when it closes.
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
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
	sideBar = Theme.make("Frame", {
		Name = "SideBar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(BUTTON_SIZE.X, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.make("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

return MenuController
