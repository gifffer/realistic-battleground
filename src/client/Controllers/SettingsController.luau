--!strict
-- SettingsController: the "SETTINGS" section of the menu.
--
--   CAMERA   first-person / third-person camera
--   DUELS    block duel requests (nobody can challenge you; ranked search
--            still works)
-- Settings are saved on the server (Server/Systems/Settings), so they
-- follow the player everywhere. For "block duel requests" the server also
-- sets the "BlocksDuels" attribute on your Player: the Duel menu shows it
-- to everyone, and the duel code refuses challenges sent to you.
--
-- Flow when the player clicks a toggle:
--   1. we apply it right away (the game feels instant),
--   2. we tell the server (Remotes.UpdateSetting), which saves it,
--   3. the server sends back the save; it should contain the same value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CameraController = require(script.Parent.CameraController)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)
local Button = require(script.Parent.Parent.UI.Button)
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
local blockDuels = false
-- os.clock() of our last change, per setting name ("firstPerson"...).
local lastLocalChange: { [string]: number } = {}
local firstPersonToggle: Toggle? = nil
local blockDuelsToggle: Toggle? = nil

local C = Theme.Colors

-- Short names for keys shown on key caps ("LEFT CTRL", not "LEFTCONTROL").
local KEY_LABELS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.LeftControl] = "LEFT CTRL",
	[Enum.KeyCode.RightControl] = "RIGHT CTRL",
	[Enum.KeyCode.LeftShift] = "LEFT SHIFT",
	[Enum.KeyCode.LeftAlt] = "LEFT ALT",
}

local function keyLabel(key: Enum.KeyCode): string
	return KEY_LABELS[key] or string.upper(key.Name)
end

-- [ OFF ][ ON ]: two real buttons side by side. The chosen one is filled
-- (ON in the accent colour, OFF dark with an accent outline), the other is
-- a faint plate that lights up under the mouse. `onSet(value)` runs when
-- the player picks the side that isn't chosen yet.
local function createToggle(parent: Instance, onSet: (value: boolean) -> ()): Toggle
	local holder = Theme.make("Frame", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -3, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, Button.height("small")),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local chosen: boolean? = nil
	local function option(text: string, value: boolean, order: number): Button.Button
		return Button.new({
			name = text,
			text = text,
			variant = "tab",
			size = "small",
			align = "center",
			width = 56,
			layoutOrder = order,
			parent = holder,
			onActivated = function()
				if chosen ~= value then
					onSet(value)
				end
			end,
		})
	end
	local off = option("OFF", false, 1)
	local on = option("ON", true, 2)

	local function set(value: boolean)
		chosen = value
		on.setVariant(if value then "primary" else "tab")
		on.setSelected(false)
		off.setVariant(if value then "tab" else "secondary")
		off.setSelected(not value)
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

-- Switch camera and save the choice (the toggle, or the camera key).
local function toggleFirstPerson()
	lastLocalChange.firstPerson = os.clock()
	setFirstPerson(not firstPerson)
	Remotes.UpdateSetting:FireServer("firstPerson", firstPerson)
end

local function setBlockDuels(value: boolean)
	blockDuels = value
	if blockDuelsToggle then
		blockDuelsToggle.set(value)
	end
end

-- Block / allow duel requests and save the choice. (A challenge prompt on
-- screen when it turns ON is declined by DuelController, which watches the
-- "BlocksDuels" attribute the server sets.)
local function toggleBlockDuels()
	lastLocalChange.blockDuels = os.clock()
	setBlockDuels(not blockDuels)
	Remotes.UpdateSetting:FireServer("blockDuels", blockDuels)
end

-- A section title ("CAMERA", "DUELS"): small caps, faint.
local function sectionTitle(content: Frame, text: string, y: number)
	Theme.text({
		Name = "Section" .. text,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = 10,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = Theme.track(text, "three"),
		Parent = content,
	})
end

-- A setting row: name, a sentence under it, the OFF / ON buttons on the
-- right and a faint rule at the bottom.
local function settingRow(
	content: Frame,
	name: string,
	y: number,
	title: string,
	description: string,
	onSet: (value: boolean) -> ()
): Toggle
	local row = Theme.make("Frame", {
		Name = name,
		Position = UDim2.fromOffset(0, y),
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
			Text = title,
		}),
		Theme.text({
			Name = "Description",
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.fromOffset(320, 14),
			FontFace = Theme.Fonts.Body,
			TextSize = 12,
			TextColor3 = C.Ink3,
			TextStrokeTransparency = 1,
			Text = description,
		}),
		Theme.make("Frame", {
			Name = "Rule",
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.9,
		}),
	})
	return createToggle(row, onSet)
end

local function buildWindow(content: Frame)
	sectionTitle(content, "CAMERA", 0)
	firstPersonToggle = settingRow(
		content,
		"FirstPersonRow",
		12,
		"First-person camera",
		"See the fight through your character's eyes.",
		function(value)
			if value ~= firstPerson then
				toggleFirstPerson()
			end
		end
	)
	setFirstPerson(firstPerson) -- show the current value

	sectionTitle(content, "DUELS", 86)
	blockDuelsToggle = settingRow(
		content,
		"BlockDuelsRow",
		98,
		"Block duel requests",
		"Nobody can challenge you. Ranked search still works.",
		function(value)
			if value ~= blockDuels then
				toggleBlockDuels()
			end
		end
	)
	setBlockDuels(blockDuels)

	-- Hint: the key that frees the mouse cursor.
	Theme.make("Frame", {
		Name = "Hint",
		Position = UDim2.fromOffset(0, 172),
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
		Theme.keyCap(keyLabel(Config.Controls.FREE_CURSOR), { LayoutOrder = 1 }),
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
	-- Hint: the key that switches the camera (W on AZERTY, Z on QWERTY).
	Theme.make("Frame", {
		Name = "CameraHint",
		Position = UDim2.fromOffset(0, 202),
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
		Theme.keyCap("W / Z", { LayoutOrder = 1 }),
		Theme.text({
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			FontFace = Theme.Fonts.Body,
			TextSize = 12,
			TextColor3 = C.Ink2,
			TextStrokeTransparency = 1,
			Text = "Switch first / third person (W on AZERTY, Z on QWERTY)",
		}),
	})
end

-- Was `name` changed here less than PENDING_SECONDS ago?
local function changedRecently(name: string): boolean
	return os.clock() - (lastLocalChange[name] or -math.huge) < PENDING_SECONDS
end

local function onProfileChanged(snapshot: Types.ProfileSnapshot)
	local settings = snapshot.settings
	if settings == nil then
		return
	end
	if not changedRecently("firstPerson") and settings.firstPerson ~= firstPerson then
		setFirstPerson(settings.firstPerson)
	end
	local blocks = settings.blockDuels == true
	if not changedRecently("blockDuels") and blocks ~= blockDuels then
		setBlockDuels(blocks)
	end
end

function SettingsController.start()
	MenuController.register({
		id = "Settings",
		label = "SETTINGS",
		subtitle = "CAMERA · DUELS · CONTROLS",
		order = 100, -- last button; Kits/Duel/Quests/Shop will come before it
		size = Vector2.new(440, 420), -- taller than the default for the DUELS row
		build = buildWindow,
	})
	PlayerDataController.onChanged(onProfileChanged)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Config.Controls.CAMERA_TOGGLE then
			toggleFirstPerson()
		end
	end)
end

return SettingsController
