--!strict
-- KnockoutController: what you SEE around knock-outs (no gameplay: the
-- server decides everything, see Server/Systems/Knockout).
--
--   • You are KO: the screen darkens, "KNOCKED OUT" with a bar and the time
--     left before you get back up. Your camera stops turning your body.
--   • An opponent is KO close in front of you: "FINISH [M1]" floats above
--     them (click to finish them).
--
-- Reads the attributes the server sets on each fighter: "KnockedOut" and
-- "KOEndsAt" (server time: compared with workspace:GetServerTimeNow()).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer
local K = Config.Knockout

local FINISH_COLOR = Color3.fromRGB(235, 60, 60)

local KnockoutController = {}

local overlay: Frame
local barFill: Frame
local timeLabel: TextLabel
local finishPrompt: BillboardGui
local wasKnockedOut = false

local function isKnockedOut(model: Model?): boolean
	return model ~= nil and model:GetAttribute("KnockedOut") == true
end

local function buildUi()
	local gui = Theme.make("ScreenGui", {
		Name = "Knockout",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
		Parent = player:WaitForChild("PlayerGui"),
	}, {
		Theme.make("Frame", {
			Name = "Overlay",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Visible = false,
		}, {
			Theme.make("TextLabel", {
				Name = "Title",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.62),
				Size = UDim2.fromOffset(500, 50),
				BackgroundTransparency = 1,
				Font = Theme.Fonts.Title,
				TextSize = 40,
				TextColor3 = FINISH_COLOR,
				TextStrokeTransparency = 0.4,
				Text = "KNOCKED OUT",
			}),
			Theme.make("Frame", {
				Name = "Bar",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.68),
				Size = UDim2.fromOffset(260, 8),
				BackgroundColor3 = Theme.Colors.Background,
				BackgroundTransparency = 0.2,
			}, {
				Theme.corner(UDim.new(1, 0)),
				Theme.make("Frame", {
					Name = "Fill",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.Colors.Text,
				}, { Theme.corner(UDim.new(1, 0)) }),
			}),
			Theme.make("TextLabel", {
				Name = "Time",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.72),
				Size = UDim2.fromOffset(300, 24),
				BackgroundTransparency = 1,
				Font = Theme.Fonts.Bold,
				TextSize = 18,
				TextColor3 = Theme.Colors.TextDim,
				Text = "",
			}),
		}),
	})
	overlay = gui.Overlay
	barFill = gui.Overlay.Bar.Fill
	timeLabel = gui.Overlay.Time

	finishPrompt = Theme.make("BillboardGui", {
		Name = "FinishPrompt",
		Size = UDim2.fromOffset(160, 36),
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
		AlwaysOnTop = true,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	}, {
		Theme.make("TextLabel", {
			Name = "Label",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.Background,
			BackgroundTransparency = 0.3,
			Font = Theme.Fonts.Title,
			TextSize = 18,
			TextColor3 = FINISH_COLOR,
			Text = "FINISH [M1]",
		}, { Theme.corner() }),
	})
end

-- Our own KO screen.
local function updateSelf(character: Model?)
	local knockedOut = isKnockedOut(character)
	if knockedOut ~= wasKnockedOut then
		wasKnockedOut = knockedOut
		CameraController.holdRotation("knockout", knockedOut)
		overlay.Visible = true
		TweenService:Create(
			overlay,
			TweenInfo.new(0.35),
			{ BackgroundTransparency = if knockedOut then 0.55 else 1 }
		):Play()
		if not knockedOut then
			task.delay(0.36, function()
				if not wasKnockedOut then
					overlay.Visible = false
				end
			end)
		end
	end
	if knockedOut and character then
		local endsAt = character:GetAttribute("KOEndsAt")
		local left = if typeof(endsAt) == "number"
			then math.max(0, endsAt - workspace:GetServerTimeNow())
			else 0
		barFill.Size = UDim2.fromScale(math.clamp(left / K.DURATION, 0, 1), 1)
		timeLabel.Text = if left > 0
			then `Getting up in {string.format("%.1f", left)}s`
			else "Getting up..."
	end
end

-- "FINISH [M1]" above the closest KO'd opponent in front of us.
local function updatePrompt(character: Model?)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local cannotAct = humanoid == nil
		or humanoid.Health <= 0
		or isKnockedOut(character)
		or (character :: Model):GetAttribute("Ragdolled") == true
	if root == nil or not root:IsA("BasePart") or cannotAct then
		finishPrompt.Enabled = false
		return
	end
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local best: BasePart? = nil
	local bestDistance = K.FINISH_RANGE
	for _, instance in CollectionService:GetTagged(Config.Combat.TAG) do
		local available = instance:IsA("Model")
			and instance ~= character
			and isKnockedOut(instance)
			and instance:GetAttribute("BeingFinished") ~= true
		if available then
			local torso = instance:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				local offset = torso.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local distance = flat.Magnitude
				-- Same rule as the finisher itself (CombatController / server).
				local inFront = distance < 1.5 or flat.Unit:Dot(forward) > 0.35
				if distance <= bestDistance and inFront and math.abs(offset.Y) < 6 then
					best, bestDistance = torso, distance
				end
			end
		end
	end
	finishPrompt.Adornee = best :: any
	finishPrompt.Enabled = best ~= nil
end

function KnockoutController.start()
	buildUi()
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		updateSelf(character)
		updatePrompt(character)
	end)
end

return KnockoutController
