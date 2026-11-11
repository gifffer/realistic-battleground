--!strict
-- SprintController: Shift → asks the server to sprint, plus the camera
-- "speed" effect (wider field of view while sprinting).
--
-- The client NEVER sets its own speed: it only tells the server what the
-- player wants (Remotes.SetSprinting). The server checks stamina and sets
-- the speed, then sets the "Sprinting" attribute that we read here for the
-- visual effect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local FOV_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local SprintController = {}

local wantsToSprint = false

-- Only sends when the wish actually changes (no spam when a key repeats).
local function setWantsToSprint(value: boolean)
	if wantsToSprint == value then
		return
	end
	wantsToSprint = value
	Remotes.SetSprinting:FireServer(value)
end

local function updateFieldOfView()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local sprinting = player:GetAttribute("Sprinting") == true
	local target = if sprinting then Config.Camera.SPRINT_FOV else Config.Camera.DEFAULT_FOV
	TweenService:Create(camera, FOV_TWEEN, { FieldOfView = target }):Play()
end

function SprintController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- gameProcessed = the key was used by something else (typing in chat...).
		if not gameProcessed and input.KeyCode == Config.Controls.SPRINT then
			setWantsToSprint(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Config.Controls.SPRINT then
			setWantsToSprint(false)
		end
	end)
	-- Alt-Tab while holding Shift: Roblox never sees the key being released.
	UserInputService.WindowFocusReleased:Connect(function()
		setWantsToSprint(false)
	end)

	player:GetAttributeChangedSignal("Sprinting"):Connect(updateFieldOfView)
	updateFieldOfView()
end

return SprintController
