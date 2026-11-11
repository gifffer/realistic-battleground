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
-- Crouching / sliding lowers the camera (Config.Camera.CROUCH_DROP), read
-- from the "MoveState" attribute the server sets.
--
-- Rotation hold: during a slide or a climb the body must keep its direction,
-- so ParkourController calls CameraController.holdRotation(reason, true) and
-- the character stops turning with the camera.
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
local rotationHoldReasons: { [string]: boolean } = {}
local humanoid: Humanoid? = nil
-- Current camera drop (studs), smoothed toward the target every frame.
local currentDrop = 0

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
		-- Coming back from first person, Roblox would leave the camera at the
		-- closest zoom (too close). Trick: lock the zoom to DEFAULT_ZOOM for
		-- one frame (the camera jumps there), then allow the normal range again.
		player.CameraMaxZoomDistance = Config.Camera.DEFAULT_ZOOM
		player.CameraMinZoomDistance = Config.Camera.DEFAULT_ZOOM
		task.delay(0.1, function()
			if not firstPerson then
				player.CameraMinZoomDistance = Config.Camera.MIN_ZOOM
				player.CameraMaxZoomDistance = Config.Camera.MAX_ZOOM
			end
		end)
	end
	cursorUnlocker.Visible = isCursorFree()
end

-- Runs every frame, right AFTER Roblox's camera script (priority Camera + 1),
-- so our choices win.
-- Frame-rate independent smoothing: same feel at 30 or 240 FPS.
local DROP_SMOOTHING = 12

local function updateCrouchDrop(dt: number): Vector3
	local moveState = player:GetAttribute("MoveState")
	local target = if moveState == "Slide"
		then Config.Camera.SLIDE_DROP
		elseif moveState == "Crouch" then Config.Camera.CROUCH_DROP
		else 0
	currentDrop += (target - currentDrop) * (1 - math.exp(-DROP_SMOOTHING * dt))
	return Vector3.new(0, -currentDrop, 0)
end

local function updateShoulderCamera(dt: number)
	local current = humanoid
	if current == nil or current.Health <= 0 then
		return
	end

	local drop = updateCrouchDrop(dt)
	local rotationHeld = next(rotationHoldReasons) ~= nil

	-- Lying limp (knocked out): the offset is relative to the root part,
	-- which tumbles with the body; it could push the camera into the floor.
	local character = player.Character
	if character and character:GetAttribute("Ragdolled") == true then
		current.CameraOffset = Vector3.zero
		current.AutoRotate = false
		return
	end

	if firstPerson then
		current.CameraOffset = drop
		current.AutoRotate = not rotationHeld
		return
	end

	current.CameraOffset = Config.Camera.SHOULDER_OFFSET + drop

	-- Slide / climb in progress: ParkourController steers the body.
	if rotationHeld then
		current.AutoRotate = false
		if not isCursorFree() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		return
	end

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

-- `reason` is a short name ("slide", "climb"...). The character stops
-- turning with the camera as long as at least one reason is active.
function CameraController.holdRotation(reason: string, hold: boolean)
	if hold then
		rotationHoldReasons[reason] = true
	else
		rotationHoldReasons[reason] = nil
	end
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
