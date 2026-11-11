--!strict
-- Camera: first / third person, over-the-shoulder shift-lock, sprint FOV.
--
-- Big picture:
--   • We keep Roblox's default camera (zoom, wall collision, mobile support)
--     and only ADD to it, after it updates each frame.
--   • Mouse wheel zoom: all the way in = first person (native Roblox).
--   • Left Ctrl toggles our shift-lock (third person only): mouse locked in
--     the center, character faces where you look, camera over the shoulder.
--     (Roblox's own shift-lock is disabled by Server/Systems/Movement because
--     it uses Shift, our sprint key.)
--   • First person shows your own arms and legs (Config.CAMERA.FIRST_PERSON_SHOW_BODY).
--   • Sprinting widens the field of view a little; crouching lowers the camera.
--   • A small dot in the center of the screen when aiming (shift-lock / first person).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Keybinds = require(ReplicatedStorage.Shared.Keybinds)
local MovementController = require(script.Parent.MovementController)

local CAMERA = Config.CAMERA
local player = Players.LocalPlayer
local userGameSettings = UserSettings():GetService("UserGameSettings")

-- Under this distance between the camera and what it looks at, we're in first person.
local FIRST_PERSON_DISTANCE = 1
-- Body parts never shown in first person (they'd block the view).
local HIDDEN_IN_FIRST_PERSON = { Head = true }

local CameraController = {}

local shiftLockOn = false
local wasShiftLocked = false
local firstPerson = false
local crosshair: Frame? = nil

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function getHumanoid(): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- Frame-rate independent smoothing: same feel at 30 or 240 FPS.
local function smoothAlpha(dt: number): number
	return 1 - math.exp(-CAMERA.SMOOTHING * dt)
end

local function isFirstPerson(camera: Camera): boolean
	return (camera.CFrame.Position - camera.Focus.Position).Magnitude < FIRST_PERSON_DISTANCE
end

local function isMoving(humanoid: Humanoid): boolean
	return humanoid.MoveDirection.Magnitude > 0.1
end

local function createCrosshair()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BackgroundTransparency = 0.2
	dot.BorderSizePixel = 0
	dot.Visible = false
	dot.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.5
	stroke.Parent = dot

	gui.Parent = player:WaitForChild("PlayerGui")
	crosshair = dot
end

-- Body parts shown in first person, cached per character (calling
-- GetDescendants() every frame would create a new table 60 times per second).
local bodyParts: { BasePart } = {}

local function isShownInFirstPerson(part: BasePart): boolean
	local isAccessory = part.Parent ~= nil and part.Parent:IsA("Accessory")
	return not isAccessory and not HIDDEN_IN_FIRST_PERSON[part.Name]
end

local function cacheBodyParts(character: Model)
	table.clear(bodyParts)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and isShownInFirstPerson(descendant) then
			table.insert(bodyParts, descendant)
		end
	end
end

-- First person: Roblox hides the whole character locally. We show the body
-- back (except the head and hats), so you can see your arms when you fight.
local function showBodyInFirstPerson()
	for _, part in bodyParts do
		part.LocalTransparencyModifier = 0
	end
end

local function onCharacterAdded(character: Model)
	cacheBodyParts(character)
	-- Limbs can load a bit after the character (and accessories at any time).
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			task.defer(cacheBodyParts, character) -- defer: wait until it's parented
		end
	end)
	character.DescendantRemoving:Connect(function(descendant)
		local index = if descendant:IsA("BasePart") then table.find(bodyParts, descendant) else nil
		if index then
			table.remove(bodyParts, index)
		end
	end)
end

------------------------------------------------------------------------------
-- Every frame, right AFTER Roblox's camera
------------------------------------------------------------------------------

local function onCameraUpdate(dt: number)
	local camera = workspace.CurrentCamera
	local humanoid = getHumanoid()
	if camera == nil or humanoid == nil then
		return
	end

	firstPerson = isFirstPerson(camera)
	local state = MovementController.getState()
	local locked = shiftLockOn and not firstPerson

	-- 1. Shift-lock: what Roblox's own shift-lock does, re-applied every
	-- frame because the default camera resets these values each update.
	if locked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		userGameSettings.RotationType = Enum.RotationType.CameraRelative
	elseif wasShiftLocked and not firstPerson then
		-- Just turned off: give the mouse back (first person manages it itself).
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		userGameSettings.RotationType = Enum.RotationType.MovementRelative
	end
	wasShiftLocked = locked

	-- 2. Camera offset (relative to the character): shoulder, crouch, first person.
	local target = Vector3.zero
	if locked then
		target += CAMERA.SHOULDER_OFFSET
	end
	if firstPerson then
		target += Vector3.new(0, 0, -CAMERA.FIRST_PERSON_FORWARD) -- -Z = forward
	end
	if state == "Crouch" then
		target -= Vector3.new(0, CAMERA.CROUCH_DROP, 0)
	end
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(target, smoothAlpha(dt))

	-- 3. Field of view: wider when sprinting.
	local sprinting = state == "Sprint" and isMoving(humanoid)
	local targetFov = if sprinting then CAMERA.SPRINT_FOV else CAMERA.BASE_FOV
	camera.FieldOfView += (targetFov - camera.FieldOfView) * smoothAlpha(dt)

	-- 4. First-person body + crosshair.
	if firstPerson and CAMERA.FIRST_PERSON_SHOW_BODY then
		showBodyInFirstPerson()
	end
	if crosshair then
		crosshair.Visible = locked or firstPerson
	end
end

------------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------------

local function onToggleShiftLock(
	_: string,
	inputState: Enum.UserInputState
): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		shiftLockOn = not shiftLockOn
	end
	return Enum.ContextActionResult.Sink
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function CameraController.init()
	player.CameraMinZoomDistance = CAMERA.MIN_ZOOM
	player.CameraMaxZoomDistance = CAMERA.MAX_ZOOM
end

function CameraController.start()
	createCrosshair()

	-- Start at a comfortable third-person distance.
	local function resetZoom()
		local camera = workspace.CurrentCamera
		if camera then
			camera.FieldOfView = CAMERA.BASE_FOV
		end
		-- Briefly clamping min = max forces the zoom distance, then we free it.
		player.CameraMinZoomDistance = CAMERA.DEFAULT_ZOOM
		player.CameraMaxZoomDistance = CAMERA.DEFAULT_ZOOM
		-- Wait a few frames so the camera actually applies it.
		task.delay(0.2, function()
			player.CameraMinZoomDistance = CAMERA.MIN_ZOOM
			player.CameraMaxZoomDistance = CAMERA.MAX_ZOOM
		end)
	end
	resetZoom()

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end

	ContextActionService:BindAction(
		"ToggleShiftLock",
		onToggleShiftLock,
		false,
		Keybinds.TOGGLE_SHIFT_LOCK
	)

	-- Priority Camera + 1 = runs just after Roblox's camera script each frame.
	RunService:BindToRenderStep(
		"RealisticCamera",
		Enum.RenderPriority.Camera.Value + 1,
		onCameraUpdate
	)
end

-- For other controllers (combat aiming later).
function CameraController.isFirstPerson(): boolean
	return firstPerson
end

function CameraController.isShiftLocked(): boolean
	return shiftLockOn and not firstPerson
end

return CameraController
