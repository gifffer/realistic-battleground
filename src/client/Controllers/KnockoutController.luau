--!strict
-- KnockoutController: what you SEE around knock-outs (no gameplay: the
-- server decides everything, see Server/Systems/Knockout).
--
-- You are knocked out (6 s): the picture drains of colour and darkens,
-- black bars slide in like a film, faint red at the edges, and in the
-- middle, quietly:
--
--                     Y O U   A R E   D O W N
--                   K N O C K E D   O U T
--               ─────────|─────|─────|────────   (one tick per second)
--               GETTING UP                  3.7
--
--   and in the bottom bar: "DROPPED BY  Rook_77". Your camera stops turning
--   your body.
--
-- An opponent is knocked out close in front of you: an outlined [M1] key
-- and FINISH float above them, with a thin hairline pointing down at the
-- body and a line showing how long is left to finish them.
--
-- Reads the attributes the server sets on each fighter: "KnockedOut",
-- "KOEndsAt" (server time, compared with workspace:GetServerTimeNow()),
-- "BeingFinished", "KOBy".

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer
local K = Config.Knockout
local C = Theme.Colors

local BAR_HEIGHT = 64 -- letterbox bars
local COUNTDOWN_WIDTH = 280

local KnockoutController = {}

local screen: ScreenGui
local letterTop: Frame
local letterBottom: Frame
local overlay: CanvasGroup -- vignette, red edges, text (fades as one group)
local eyebrow: TextLabel
local title: TextLabel
local cdFill: Frame
local cdLabel: TextLabel
local cdNum: TextLabel
local byLabel: TextLabel
local byName: TextLabel
local grade: ColorCorrectionEffect

local finishGui: BillboardGui
local finishWord: TextLabel
local finishKey: TextLabel
local finishTimeFill: Frame
local finishTick: Frame
local finishPulse: Tween? = nil

local wasKnockedOut = false

local function isKnockedOut(model: Model?): boolean
	return model ~= nil and model:GetAttribute("KnockedOut") == true
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

-- A dark (or red) frame whose transparency gradient hides its edges.
local function shade(
	name: string,
	props: { [string]: any },
	rotation: number,
	points: { { number } },
	color: Color3?
)
	props.Name = name
	props.BackgroundColor3 = color or C.Scrim
	props.Parent = overlay
	return Theme.make("Frame", props, { Theme.gradient(rotation, points) })
end

local function buildScreen()
	screen = Theme.make("ScreenGui", {
		Name = "Knockout",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	overlay = Theme.make("CanvasGroup", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = screen,
	})
	-- Vignette top and bottom, faint red at the sides, a band behind the text.
	shade("VignetteTop", { Size = UDim2.fromScale(1, 0.3) }, 90, { { 0, 0.3 }, { 1, 1 } })
	shade("VignetteBottom", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.3),
	}, -90, { { 0, 0.3 }, { 1, 1 } })
	shade(
		"EdgeLeft",
		{ Size = UDim2.fromScale(0.18, 1) },
		0,
		{ { 0, 0.68 }, { 1, 1 } },
		C.BloodDeep
	)
	shade("EdgeRight", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.18, 1),
	}, 180, { { 0, 0.68 }, { 1, 1 } }, C.BloodDeep)
	shade("TextBand", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 150),
		Size = UDim2.new(1, 0, 0, 200),
	}, 90, { { 0, 1 }, { 0.5, 0.45 }, { 1, 1 } })

	local block = Theme.make("Frame", {
		Name = "Block",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 92),
		Size = UDim2.fromOffset(400, 130),
		BackgroundTransparency = 1,
		Parent = overlay,
	})
	eyebrow = Theme.text({
		Name = "Eyebrow",
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = 10,
		TextColor3 = C.Ink2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Theme.track("YOU ARE DOWN", "three") .. " ",
		Parent = block,
	})
	title = Theme.text({
		Name = "Title",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = Theme.Fonts.Display,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Theme.track("KNOCKED OUT", "en") .. " ",
		Parent = block,
	})
	local track = Theme.make("Frame", {
		Name = "CountdownTrack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(COUNTDOWN_WIDTH, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.82,
		Parent = block,
	})
	cdFill = Theme.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		Parent = track,
	})
	-- One small tick per second.
	for second = 1, math.floor(K.DURATION) - 1 do
		Theme.make("Frame", {
			Name = "Tick",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(second / K.DURATION, 0.5),
			Size = UDim2.fromOffset(1, 5),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.6,
			Parent = track,
		})
	end
	cdLabel = Theme.text({
		Name = "Label",
		Position = UDim2.fromOffset(60, 102),
		Size = UDim2.fromOffset(140, 12),
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = Theme.track("GETTING UP", "three"),
		Parent = block,
	})
	cdNum = Theme.text({
		Name = "Seconds",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -60, 0, 102),
		Size = UDim2.fromOffset(60, 12),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = block,
	})

	-- Film bars, with "DROPPED BY name" in the bottom one.
	letterTop = Theme.make("Frame", {
		Name = "BarTop",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.Scrim,
		Parent = screen,
	})
	letterBottom = Theme.make("Frame", {
		Name = "BarBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.Scrim,
		ClipsDescendants = true,
		Parent = screen,
	})
	local attribution = Theme.make("Frame", {
		Name = "Attribution",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, BAR_HEIGHT / 2),
		Size = UDim2.fromOffset(400, 14),
		BackgroundTransparency = 1,
		Parent = letterBottom,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	byLabel = Theme.text({
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		TextSize = 10,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = Theme.track("DROPPED BY", "three"),
		Parent = attribution,
	})
	byName = Theme.text({
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		TextSize = 12,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		Text = "",
		Parent = attribution,
	})

	-- Picture: desaturated and darker (local to this player).
	grade = Theme.make("ColorCorrectionEffect", { Name = "KnockoutGrade", Parent = Lighting })
end

local function buildFinishPrompt()
	finishGui = Theme.make("BillboardGui", {
		Name = "FinishPrompt",
		Size = UDim2.fromOffset(130, 52),
		StudsOffset = Vector3.new(0, 1.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		-- Built once: must survive our respawns (Roblox clears PlayerGui).
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	finishKey = Theme.keyCap("M1", {
		Name = "Key",
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromOffset(24, 20),
		Parent = finishGui,
	})
	finishWord = Theme.text({
		Name = "Word",
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.fromOffset(96, 20),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 13,
		Text = Theme.track("FINISH", "three"),
		Parent = finishGui,
	})
	-- Time left to finish them: a hairline that shrinks.
	local timeTrack = Theme.make("Frame", {
		Name = "TimeLeft",
		Position = UDim2.fromOffset(34, 22),
		Size = UDim2.fromOffset(60, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.8,
		Parent = finishGui,
	})
	finishTimeFill = Theme.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		Parent = timeTrack,
	})
	-- A fading hairline pointing down at the body.
	finishTick = Theme.make("Frame", {
		Name = "Tick",
		Position = UDim2.fromOffset(12, 24),
		Size = UDim2.fromOffset(1, 18),
		BackgroundColor3 = C.Ink,
		Parent = finishGui,
	}, { Theme.gradient(90, { { 0, 0.3 }, { 1, 1 } }) })
end

------------------------------------------------------------------------------
-- Our own knock-out screen
------------------------------------------------------------------------------

local function setDown(down: boolean, character: Model?)
	CameraController.holdRotation("knockout", down)
	if down then
		screen.Enabled = true
		local by = if character then character:GetAttribute("KOBy") else nil
		byName.Text = if typeof(by) == "string" then by else ""
		byLabel.Visible = typeof(by) == "string"
		eyebrow.TextTransparency = 1
		title.TextTransparency = 1
		local barSize = UDim2.new(1, 0, 0, BAR_HEIGHT)
		Theme.tween(letterTop, 0.35, { Size = barSize }, Enum.EasingStyle.Quart)
		Theme.tween(letterBottom, 0.35, { Size = barSize }, Enum.EasingStyle.Quart)
		Theme.tween(overlay, 0.35, { GroupTransparency = 0 })
		Theme.tween(grade, 0.4, {
			Saturation = -0.85,
			Brightness = -0.25,
			Contrast = 0.15,
			TintColor = Color3.fromHex("#F2E4E2"),
		})
		task.delay(0.15, function()
			Theme.tween(eyebrow, 0.3, { TextTransparency = 0 })
		end)
		task.delay(0.2, function()
			Theme.tween(title, 0.6, { TextTransparency = 0 })
		end)
	else
		local closed = UDim2.new(1, 0, 0, 0)
		local quadIn = Enum.EasingDirection.In
		Theme.tween(letterTop, 0.3, { Size = closed }, Enum.EasingStyle.Quad, quadIn)
		Theme.tween(letterBottom, 0.3, { Size = closed }, Enum.EasingStyle.Quad, quadIn)
		Theme.tween(overlay, 0.2, { GroupTransparency = 1 })
		Theme.tween(grade, 0.5, {
			Saturation = 0,
			Brightness = 0,
			Contrast = 0,
			TintColor = Color3.new(1, 1, 1),
		})
		task.delay(0.32, function()
			if not wasKnockedOut then
				screen.Enabled = false
			end
		end)
	end
end

local function updateSelf(character: Model?)
	local down = isKnockedOut(character)
	if down ~= wasKnockedOut then
		wasKnockedOut = down
		setDown(down, character)
	end
	if down and character then
		local endsAt = character:GetAttribute("KOEndsAt")
		local left = if typeof(endsAt) == "number"
			then math.max(0, endsAt - workspace:GetServerTimeNow())
			else 0
		cdFill.Size = UDim2.fromScale(math.clamp(left / K.DURATION, 0, 1), 1)
		cdNum.Text = string.format("%.1f", left)
		local finishing = character:GetAttribute("BeingFinished") == true
		cdLabel.Text = Theme.track(if finishing then "FINISHED" else "GETTING UP", "three")
		cdLabel.TextColor3 = if finishing then C.BloodHi else C.Ink2
	end
end

------------------------------------------------------------------------------
-- FINISH prompt above a knocked-out opponent
------------------------------------------------------------------------------

local function setPromptVisible(visible: boolean)
	if finishGui.Enabled == visible then
		return
	end
	finishGui.Enabled = visible
	if finishPulse then
		finishPulse:Cancel()
		finishPulse = nil
	end
	if visible then
		-- Appear: the word fades in, the hairline grows down to the body.
		finishWord.TextColor3 = C.Ink
		finishWord.TextTransparency = 1
		finishTick.Size = UDim2.fromOffset(1, 0)
		Theme.tween(finishWord, 0.15, { TextTransparency = 0 })
		Theme.tween(finishTick, 0.2, { Size = UDim2.fromOffset(1, 18) }, Enum.EasingStyle.Quart)
		local outline = finishKey:FindFirstChild("Outline")
		if outline == nil or not outline:IsA("UIStroke") then
			return
		end
		outline.Transparency = 0.1
		-- Slow "breathing" of the key's outline: it invites the click.
		local pulse = TweenService:Create(
			outline,
			TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.5 }
		)
		pulse:Play()
		finishPulse = pulse
	end
end

-- We clicked to finish: the word flashes red, the prompt fades away.
function KnockoutController.onFinishStarted()
	if not finishGui.Enabled then
		return
	end
	finishWord.TextColor3 = C.BloodHi
	Theme.tween(finishWord, 0.15, { TextTransparency = 1 }, Enum.EasingStyle.Linear)
end

local function updatePrompt(character: Model?)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local cannotAct = humanoid == nil
		or humanoid.Health <= 0
		or isKnockedOut(character)
		or (character :: Model):GetAttribute("Ragdolled") == true
	if root == nil or not root:IsA("BasePart") or cannotAct then
		setPromptVisible(false)
		return
	end
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local best: Model? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = K.FINISH_RANGE
	for _, instance in CollectionService:GetTagged(Config.Combat.TAG) do
		local available = instance:IsA("Model")
			and instance ~= character
			and isKnockedOut(instance)
			and instance:GetAttribute("BeingFinished") ~= true
		if available then
			local torso = instance:FindFirstChild("Torso")
			local targetRoot = instance:FindFirstChild("HumanoidRootPart")
			if torso and torso:IsA("BasePart") and targetRoot and targetRoot:IsA("BasePart") then
				local offset = torso.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local distance = flat.Magnitude
				-- Same rule as the finisher itself (CombatController / server).
				local inFront = distance < 1.5 or flat.Unit:Dot(forward) > 0.35
				if distance <= bestDistance and inFront and math.abs(offset.Y) < 6 then
					best, bestRoot, bestDistance = instance :: Model, targetRoot, distance
				end
			end
		end
	end
	finishGui.Adornee = bestRoot :: any
	setPromptVisible(best ~= nil)
	if best then
		local endsAt = best:GetAttribute("KOEndsAt")
		local left = if typeof(endsAt) == "number"
			then math.max(0, endsAt - workspace:GetServerTimeNow())
			else 0
		finishTimeFill.Size = UDim2.fromScale(math.clamp(left / K.DURATION, 0, 1), 1)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function KnockoutController.start()
	buildScreen()
	buildFinishPrompt()
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		updateSelf(character)
		updatePrompt(character)
	end)
end

return KnockoutController
