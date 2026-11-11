--!strict
-- SettingsController: the "SETTINGS" section of the menu.
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
	set: (value: boolean) -> (), -- updates the OFF / ON display
}

local SettingsController = {}

local firstPerson = false
local lastLocalChange = -math.huge
local firstPersonToggle: Toggle? = nil

local C = Theme.Colors

-- "OFF   ON" in text, the chosen one bright and underlined (no pill, no switch).
local function createToggle(parent: Instance, onClick: () -> ()): Toggle
	local holder = Theme.make("Frame", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(70, 22),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local function option(text: string, x: number): TextButton
		return Theme.text({
			ClassName = "TextButton",
			Name = text,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(26, 18),
			TextSize = 12,
			TextColor3 = C.Ink3,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			AutoButtonColor = false,
			Text = Theme.track(text, "four"),
			Parent = holder,
		}) :: TextButton
	end
	local off = option("OFF", 4)
	local on = option("ON", 44)
	local underline = Theme.make("Frame", {
		Name = "Underline",
		Position = UDim2.fromOffset(44, 20),
		Size = UDim2.fromOffset(20, 2),
		BackgroundColor3 = C.Ink,
		Parent = holder,
	})
	off.Activated:Connect(onClick)
	on.Activated:Connect(onClick)

	local function set(value: boolean)
		local chosen = if value then on else off
		Theme.tween(on, Theme.FAST, { TextColor3 = if value then C.Ink else C.Ink3 })
		Theme.tween(off, Theme.FAST, { TextColor3 = if value then C.Ink3 else C.Ink })
		Theme.tween(underline, 0.18, {
			Position = UDim2.fromOffset(chosen.Position.X.Offset + 3, 20),
			Size = UDim2.fromOffset(chosen.Size.X.Offset - 6, 2),
		}, Enum.EasingStyle.Quart)
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
	Theme.text({
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = 10,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = Theme.track("CAMERA", "three"),
		Parent = content,
	})
	local row = Theme.make("Frame", {
		Name = "FirstPersonRow",
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		Theme.text({
			Name = "Name",
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.fromOffset(320, 18),
			FontFace = Theme.Fonts.Body,
			TextSize = 15,
			TextStrokeTransparency = 1,
			Text = "First-person camera",
		}),
		Theme.text({
			Name = "Description",
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.fromOffset(320, 14),
			FontFace = Theme.Fonts.Body,
			TextSize = 12,
			TextColor3 = C.Ink3,
			TextStrokeTransparency = 1,
			Text = "See the fight through your character's eyes.",
		}),
		Theme.make("Frame", {
			Name = "Rule",
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.9,
		}),
	})
	firstPersonToggle = createToggle(row, function()
		lastLocalChange = os.clock()
		setFirstPerson(not firstPerson)
		Remotes.UpdateSetting:FireServer("firstPerson", firstPerson)
	end)
	setFirstPerson(firstPerson) -- show the current value

	-- Hint: the key that frees the mouse cursor.
	Theme.make("Frame", {
		Name = "Hint",
		Position = UDim2.fromOffset(0, 85),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Theme.keyCap(Theme.track(string.upper(Config.Controls.FREE_CURSOR.Name), "thin"), {
			LayoutOrder = 1,
		}),
		Theme.text({
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			FontFace = Theme.Fonts.Body,
			TextSize = 12,
			TextColor3 = C.Ink2,
			TextStrokeTransparency = 1,
			Text = `Press {Config.Controls.FREE_CURSOR.Name} to free or lock the cursor`,
		}),
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
		subtitle = "CAMERA · CONTROLS",
		order = 100, -- last button; Kits/Duel/Quests/Shop will come before it
		build = buildWindow,
	})
	PlayerDataController.onChanged(onProfileChanged)
end

return SettingsController
