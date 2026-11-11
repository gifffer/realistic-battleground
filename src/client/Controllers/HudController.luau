--!strict
-- HudController: health and stamina bars at the bottom of the screen.
--
-- Display only. Health comes from the Humanoid, stamina from the "Stamina"
-- and "StaminaExhausted" attributes the server sets on the Player
-- (see Server/Systems/Stamina). Later: attack bar, ultimate gauge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local BAR_WIDTH = 320
local BAR_HEIGHT = 14
local FILL_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Bar = {
	title: string, -- "HEALTH", "STAMINA"
	fill: Frame,
	label: TextLabel,
}

local HudController = {}

local healthBar: Bar
local staminaBar: Bar
local humanoidConnections: { RBXScriptConnection } = {}

-- One bar = dark background + colored fill + "TEXT  value" label.
local function createBar(
	name: string,
	title: string,
	color: Color3,
	order: number,
	parent: Instance
): Bar
	local frame = Theme.make("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.25,
		Parent = parent,
	}, {
		Theme.corner(UDim.new(0, 4)),
		Theme.make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
		}, { Theme.corner(UDim.new(0, 4)) }),
		Theme.make("TextLabel", {
			Name = "Label",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Bold,
			TextSize = 11,
			TextColor3 = Theme.Colors.Text,
			TextStrokeTransparency = 0.6,
			Text = title,
			ZIndex = 2,
		}),
	})
	return { title = title, fill = frame.Fill, label = frame.Label }
end

local function setBar(bar: Bar, value: number, max: number)
	local ratio = if max > 0 then math.clamp(value / max, 0, 1) else 0
	TweenService:Create(bar.fill, FILL_TWEEN, { Size = UDim2.fromScale(ratio, 1) }):Play()
	bar.label.Text = `{bar.title}  {math.ceil(value)}`
end

local function refreshStamina()
	local value = player:GetAttribute("Stamina")
	local exhausted = player:GetAttribute("StaminaExhausted") == true
	setBar(staminaBar, if typeof(value) == "number" then value else 0, Config.Stamina.MAX)
	staminaBar.fill.BackgroundColor3 = if exhausted
		then Theme.Colors.Exhausted
		else Theme.Colors.Stamina
end

local function onCharacterAdded(character: Model)
	for _, connection in humanoidConnections do
		connection:Disconnect()
	end
	table.clear(humanoidConnections)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	local function refreshHealth()
		setBar(healthBar, humanoid.Health, humanoid.MaxHealth)
	end
	table.insert(humanoidConnections, humanoid.HealthChanged:Connect(refreshHealth))
	table.insert(
		humanoidConnections,
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refreshHealth)
	)
	refreshHealth()
end

function HudController.init()
	-- Hide Roblox's default health bar: ours replaces it.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	local gui = Theme.make("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local container = Theme.make("Frame", {
		Name = "Bars",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(BAR_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.make("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	healthBar = createBar("Health", "HEALTH", Theme.Colors.Health, 1, container)
	staminaBar = createBar("Stamina", "STAMINA", Theme.Colors.Stamina, 2, container)
end

function HudController.start()
	player:GetAttributeChangedSignal("Stamina"):Connect(refreshStamina)
	player:GetAttributeChangedSignal("StaminaExhausted"):Connect(refreshStamina)
	refreshStamina()

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

return HudController
