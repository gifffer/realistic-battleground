--!strict
-- SafeZoneController: a small, discreet caption when you walk into the hidden park.
--
--   SAFE ZONE
--   No fighting in the park
--
-- The park is a safe zone (Shared/Util/SafeZone, Config.Park): the server refuses every
-- attack there, and CombatController doesn't even try (no punch is predicted). This caption
-- only tells you WHY your punches do nothing. It fades in at the top of the screen, stays a
-- few seconds and fades away (it is not left on screen: the park is a place to relax).
-- Style: the editorial UI (Client/UI/Theme): off-white condensed caps, a hairline, no box.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SafeZone = require(ReplicatedStorage.Shared.Util.SafeZone)
local Theme = require(script.Parent.Parent.UI.Theme)

local P = Config.Park
local player = Players.LocalPlayer

local SafeZoneController = {}

-- How often we check where we stand (seconds), how long the caption stays.
local CHECK_EVERY = 0.25
local SHOW_TIME = 3.5
local FADE_IN = 0.5
local FADE_OUT = 1.2

local holder: Frame
local title: TextLabel
local subtitle: TextLabel
local line: Frame
local showToken = 0

local function build()
	local gui = Theme.make("ScreenGui", {
		Name = "SafeZone",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2,
		Parent = player:WaitForChild("PlayerGui"),
	})
	holder = Theme.make("Frame", {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.fromOffset(260, 46),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	title = Theme.text({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Theme.track(string.upper(P.CAPTION), "three"),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = holder,
	})
	-- a short hairline between the two lines
	line = Theme.make("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 23),
		Size = UDim2.fromOffset(46, 1),
		BackgroundColor3 = Theme.Colors.Ink,
		BackgroundTransparency = 1,
		Parent = holder,
	})
	subtitle = Theme.text({
		Name = "Subtitle",
		Position = UDim2.fromOffset(0, 27),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Theme.Fonts.LabelRegular,
		TextSize = 12,
		TextColor3 = Theme.Colors.Ink2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = P.CAPTION_SUB,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = holder,
	})
end

-- Fades the caption to `alpha` (0 = hidden, 1 = fully shown) in `seconds`.
local function fade(alpha: number, seconds: number)
	local hidden = 1 - alpha
	Theme.tween(title, seconds, {
		TextTransparency = hidden,
		TextStrokeTransparency = 1 - alpha * (1 - Theme.STROKE_TRANSPARENCY),
	})
	Theme.tween(subtitle, seconds, {
		TextTransparency = hidden,
		TextStrokeTransparency = 1 - alpha * (1 - Theme.STROKE_TRANSPARENCY),
	})
	Theme.tween(line, seconds, { BackgroundTransparency = 1 - alpha * 0.6 })
end

local function show()
	showToken += 1
	local token = showToken
	holder.Visible = true
	fade(1, FADE_IN)
	task.delay(SHOW_TIME, function()
		if token ~= showToken then
			return -- shown again meanwhile: that one hides it
		end
		fade(0, FADE_OUT)
		task.delay(FADE_OUT, function()
			if token == showToken then
				holder.Visible = false
			end
		end)
	end)
end

function SafeZoneController.start()
	if not P.SAFE_ZONE then
		return
	end
	build()
	local wasInside = false
	while true do
		task.wait(CHECK_EVERY)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local inside = root ~= nil and root:IsA("BasePart") and SafeZone.contains(root.Position)
		if inside and not wasInside then
			show()
		end
		wasInside = inside
	end
end

return SafeZoneController
