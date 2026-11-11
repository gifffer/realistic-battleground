--!strict
-- CameraController: over-the-shoulder third person, or first person.
--
-- Third person ("shoulder" camera, like most battlegrounds games):
--   • the cursor is locked in the middle of the screen, moving the mouse
--     turns the camera,
--   • the character always faces where the camera looks (so attacks go
--     where you aim),
--   • the camera sits a bit to the right of the character (SHOULDER_OFFSET).
-- First person: Roblox's own LockFirstPerson mode.
--
-- Free cursor: to click menus the cursor must be free. It is free when ANY
-- "reason" asks for it: a menu window is open ("menu"), or the player pressed
-- Config.Controls.FREE_CURSOR ("key"). Other controllers call
-- CameraController.setCursorFree(reason, true/false).
--
-- The choice first/third person is saved: SettingsController calls
-- CameraController.setFirstPerson() when the save arrives or the player
-- clicks the toggle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local CameraController = {}

local firstPerson = false
local cursorFreeReasons: { [string]: boolean } = {}
local humanoid: Humanoid? = nil

-- In first person, Roblox keeps the mouse locked UNLESS a visible GuiButton
-- has Modal = true. This invisible button is that "key".
local cursorUnlocker: TextButton

local function isCursorFree(): boolean
	return next(cursorFreeReasons) ~= nil
end

local function applyCameraMode()
	if firstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		-- Min before max: setting a min above the current max would fail.
		player.CameraMinZoomDistance = Config.Camera.MIN_ZOOM
		player.CameraMaxZoomDistance = Config.Camera.MAX_ZOOM
	end
	cursorUnlocker.Visible = isCursorFree()
end

-- Runs every frame, right AFTER Roblox's camera script (priority Camera + 1),
-- so our choices win.
local function updateShoulderCamera()
	local current = humanoid
	if current == nil or current.Health <= 0 then
		return
	end

	if firstPerson then
		current.CameraOffset = Vector3.zero
		current.AutoRotate = true
		return
	end

	current.CameraOffset = Config.Camera.SHOULDER_OFFSET

	-- Cursor free (menu open...) or sitting: behave like a normal Roblox game.
	if isCursorFree() or current.Sit then
		current.AutoRotate = true
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		return
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	current.AutoRotate = false

	-- Turn the character (left/right only) to face where the camera looks.
	local root = current.RootPart
	local camera = workspace.CurrentCamera
	if root and camera then
		local look = camera.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 1e-3 then
			local position = root.Position
			root.CFrame = CFrame.lookAt(position, position + flatLook)
		end
	end
end

local function onCharacterAdded(character: Model)
	humanoid = nil
	local found = character:WaitForChild("Humanoid", 10)
	if found and found:IsA("Humanoid") and character.Parent ~= nil then
		humanoid = found
	end
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

function CameraController.setFirstPerson(enabled: boolean)
	if firstPerson == enabled then
		return
	end
	firstPerson = enabled
	applyCameraMode()
end

function CameraController.isFirstPerson(): boolean
	return firstPerson
end

-- `reason` is a short name ("menu", "key"...). The cursor stays free as long
-- as at least one reason is active.
function CameraController.setCursorFree(reason: string, free: boolean)
	if free then
		cursorFreeReasons[reason] = true
	else
		cursorFreeReasons[reason] = nil
	end
	cursorUnlocker.Visible = isCursorFree()
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function CameraController.init()
	local gui = Theme.make("ScreenGui", {
		Name = "CursorUnlocker",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	}, {
		Theme.make("TextButton", {
			Name = "Unlocker",
			Modal = true,
			Visible = false,
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 0),
		}),
	})
	cursorUnlocker = gui.Unlocker
end

function CameraController.start()
	applyCameraMode()

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Config.Controls.FREE_CURSOR then
			CameraController.setCursorFree("key", cursorFreeReasons.key ~= true)
		end
	end)

	RunService:BindToRenderStep(
		"ShoulderCamera",
		Enum.RenderPriority.Camera.Value + 1,
		updateShoulderCamera
	)
end

return CameraController
