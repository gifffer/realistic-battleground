--!strict
-- TEMPORARY (FinisherShowcase, for filming; delete with it). Studio only.
--
-- A small panel you can drag around by its title bar, to play the showcase
-- finishers (server: Systems/FinisherShowcase):
--   STREET BRAWLER  the bat (golf swing), the head bursts
--   BOXER           the combo, the liver torn out
--   CAMERA ON/OFF   the cutscene camera watches them, or not
-- (the game keeps the mouse locked: LEFT CTRL frees it to click)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CinematicController = require(script.Parent.CinematicController)

local ShowcasePanelController = {}

local BACKGROUND = Color3.fromRGB(18, 18, 22)
local BAR = Color3.fromRGB(34, 34, 40)
local BUTTON = Color3.fromRGB(52, 52, 60)
local BUTTON_HOVER = Color3.fromRGB(72, 72, 84)
local TEXT = Color3.fromRGB(235, 235, 240)
local DIM = Color3.fromRGB(150, 150, 160)

local function corner(parent: Instance, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.GothamBold
	item.Text = text
	item.TextSize = size
	item.TextColor3 = color
	item.Parent = parent
	return item
end

local function button(parent: Instance, text: string, order: number, onClick: () -> ()): TextButton
	local item = Instance.new("TextButton")
	item.Name = text
	item.LayoutOrder = order
	item.Size = UDim2.new(1, 0, 0, 30)
	item.BackgroundColor3 = BUTTON
	item.AutoButtonColor = false
	item.Font = Enum.Font.GothamBold
	item.TextSize = 13
	item.TextColor3 = TEXT
	item.Text = text
	corner(item, 6)
	item.MouseEnter:Connect(function()
		item.BackgroundColor3 = BUTTON_HOVER
	end)
	item.MouseLeave:Connect(function()
		item.BackgroundColor3 = BUTTON
	end)
	item.Activated:Connect(onClick)
	item.Parent = parent
	return item
end

-- The panel follows the mouse while its title bar is held.
local function makeDraggable(panel: Frame, handle: GuiObject)
	local dragging: InputObject? = nil
	local startMouse = Vector2.zero
	local startPosition = panel.Position
	handle.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = input
			startMouse = Vector2.new(input.Position.X, input.Position.Y)
			startPosition = panel.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging == nil then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - startMouse
			panel.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = nil
		end
	end)
end

function ShowcasePanelController.start()
	if not RunService:IsStudio() then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FinisherShowcase"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200
	gui.IgnoreGuiInset = true

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(200, 196)
	panel.Position = UDim2.new(0, 24, 0.5, -98)
	panel.BackgroundColor3 = BACKGROUND
	panel.BackgroundTransparency = 0.08
	corner(panel, 8)
	panel.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "TitleBar"
	bar.Size = UDim2.new(1, 0, 0, 28)
	bar.BackgroundColor3 = BAR
	bar.Active = true -- (grabs the mouse: drag it from here)
	corner(bar, 8)
	bar.Parent = panel
	local title = label(bar, "FINISHER SHOWCASE", 12, TEXT)
	title.Size = UDim2.fromScale(1, 1)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(10, 36)
	body.Size = UDim2.new(1, -20, 1, -44)
	body.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	local cameraOn = true
	local function play(fighter: string)
		CinematicController.watchShowcase(if cameraOn then fighter else nil)
		Remotes.ShowcaseTrigger:FireServer(fighter)
	end
	button(body, "STREET BRAWLER", 1, function()
		play("Street Brawler")
	end)
	button(body, "BOXER", 2, function()
		play("Boxer")
	end)
	local cameraButton: TextButton
	cameraButton = button(body, "CAMERA: ON", 3, function()
		cameraOn = not cameraOn
		cameraButton.Text = if cameraOn then "CAMERA: ON" else "CAMERA: OFF"
		if not cameraOn then
			CinematicController.watchShowcase(nil)
		end
	end)
	local hint = label(body, "LEFT CTRL: FREE MOUSE", 10, DIM)
	hint.LayoutOrder = 4
	hint.Size = UDim2.new(1, 0, 0, 18)

	makeDraggable(panel, bar)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return ShowcasePanelController
