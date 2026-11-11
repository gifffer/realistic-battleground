--!strict
-- SettingsController: the "SETTINGS" window of the side menu.
--
-- For now: first-person / third-person camera. Settings are saved on the
-- server (Server/Systems/Settings), so they follow the player everywhere.
--
-- Flow when the player clicks a toggle:
--   1. we apply it right away (the game feels instant),
--   2. we tell the server (Remotes.UpdateSetting), which saves it,
--   3. the server sends back the save; it should contain the same value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CameraController = require(script.Parent.CameraController)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)
local Theme = require(script.Parent.Parent.UI.Theme)

-- After a click, saves that still hold the OLD value can arrive for a short
-- moment (they were sent before the server got our change). We ignore the
-- server's value of a setting for this many seconds after changing it.
local PENDING_SECONDS = 3

type Toggle = {
	set: (value: boolean) -> (), -- updates the ON/OFF display
}

local SettingsController = {}

local firstPerson = false
local lastLocalChange = -math.huge
local firstPersonToggle: Toggle? = nil

-- A row: description on the left, ON/OFF button on the right.
local function createToggle(
	parent: Instance,
	order: number,
	text: string,
	onClick: () -> ()
): Toggle
	local row = Theme.make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.Colors.PanelLight,
		Parent = parent,
	}, {
		Theme.corner(),
		Theme.make("TextLabel", {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -110, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Regular,
			TextSize = 15,
			TextColor3 = Theme.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = text,
		}),
		Theme.make("TextButton", {
			Name = "Switch",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(80, 28),
			Font = Theme.Fonts.Bold,
			TextSize = 14,
			TextColor3 = Theme.Colors.Text,
			AutoButtonColor = true,
		}, { Theme.corner() }),
	})

	local switch = row.Switch :: TextButton
	switch.Activated:Connect(onClick)

	local function set(value: boolean)
		switch.Text = if value then "ON" else "OFF"
		switch.BackgroundColor3 = if value then Theme.Colors.On else Theme.Colors.Off
	end
	return { set = set }
end

local function setFirstPerson(value: boolean)
	firstPerson = value
	CameraController.setFirstPerson(value)
	if firstPersonToggle then
		firstPersonToggle.set(value)
	end
end

local function buildWindow(content: Frame)
	Theme.make("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})

	firstPersonToggle = createToggle(content, 1, "First-person camera", function()
		lastLocalChange = os.clock()
		setFirstPerson(not firstPerson)
		Remotes.UpdateSetting:FireServer("firstPerson", firstPerson)
	end)
	setFirstPerson(firstPerson) -- show the current value

	Theme.make("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Regular,
		TextSize = 13,
		TextColor3 = Theme.Colors.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = `Tip: press {Config.Controls.FREE_CURSOR.Name} to free or lock the mouse cursor.`,
		Parent = content,
	})
end

local function onProfileChanged(snapshot: Types.ProfileSnapshot)
	if os.clock() - lastLocalChange < PENDING_SECONDS then
		return
	end
	local settings = snapshot.settings
	if settings and settings.firstPerson ~= firstPerson then
		setFirstPerson(settings.firstPerson)
	end
end

function SettingsController.start()
	MenuController.register({
		id = "Settings",
		label = "SETTINGS",
		order = 100, -- last button; Kits/Duel/Quests/Shop will come before it
		build = buildWindow,
	})
	PlayerDataController.onChanged(onProfileChanged)
end

return SettingsController
