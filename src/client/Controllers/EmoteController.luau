--!strict
-- EmoteController: the emote key (B, Config.Controls.EMOTE). Plays the
-- emote equipped in the SHOP. The server checks you can (not mid-fight,
-- you own it) and tells everyone to play it (Remotes.CombatAction), so
-- there's nothing to predict here.
--
-- Touch screens have no B key: an EMOTE button sits just above the MENU
-- button while an emote is equipped. It shows and hides with the MENU
-- button (menu open, duel result...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Button = require(script.Parent.Parent.UI.Button)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)

local player = Players.LocalPlayer

local EmoteController = {}

-- The EMOTE button for touch screens.
local function buildTouchButton()
	local playerGui = player:WaitForChild("PlayerGui")
	local menuGui = playerGui:WaitForChild("Menu", 10)
	local menuButton = if menuGui then menuGui:FindFirstChild("MenuButton") else nil
	local gui = Theme.make("ScreenGui", {
		Name = "EmoteButton",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Parent = playerGui,
	})
	local button = Button.new({
		name = "Emote",
		text = "EMOTE",
		anchorPoint = Vector2.new(0, 0.5),
		-- (just above the MENU button: its centre minus its height and a gap)
		position = UDim2.new(0, 16, 0.5, MenuController.BUTTON_Y - Button.height("large") - 4),
		visible = false,
		parent = gui,
		onActivated = function()
			Remotes.Emote:FireServer()
		end,
	})
	Theme.autoScale(button.instance, 0.8)

	local function refresh()
		local profile = PlayerDataController.get()
		local emote = if profile then profile.equipped.Emote else nil
		local equipped = typeof(emote) == "string" and emote ~= ""
		local menuShown = if menuButton and menuButton:IsA("GuiObject")
			then menuButton.Visible
			else MenuController.getOpen() == nil
		button.instance.Visible = equipped and menuShown
	end
	PlayerDataController.onChanged(refresh)
	MenuController.onOpenChanged(refresh)
	if menuButton then
		menuButton:GetPropertyChangedSignal("Visible"):Connect(refresh)
	end
	refresh()
end

function EmoteController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Config.Controls.EMOTE then
			Remotes.Emote:FireServer()
		end
	end)
	if Theme.isTouch() then
		buildTouchButton()
	end
end

return EmoteController
