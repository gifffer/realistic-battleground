--!strict
-- DeathScreenController: a short screen after you are eliminated, until you
-- respawn. Low in the middle, the body stays visible above it:
--
--                        FINISHED BY
--                         Rook_77
--                  17   BOXER  — LIVER RIP
--             ─────────────────────────────────   drains until the respawn
--             RESPAWN                       3.2
--
-- • "ELIMINATED BY" for a normal kill, "FINISHED BY" for a finisher (its
--   name after a red dash), "YOU DIED" when nobody gets the kill.
-- • The killer's level and kit (their kit's name) under their name.
-- • A finisher's cutscene plays first: the screen waits for its end
--   (CinematicController.watchingUntil), then shows the time left.
-- • The world loses its colour a little; everything goes on respawn.
--
-- Comes from the same server message as the kill feed (Remotes.KillFeed,
-- details.victimId = our UserId). Duels have their own result screen (the
-- server sends no kill feed line there).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)
local CinematicController = require(script.Parent.CinematicController)
local KillFeedController = require(script.Parent.KillFeedController)

local player = Players.LocalPlayer
local C = Theme.Colors
local RESPAWN_TIME = Config.Knockout.RESPAWN_TIME

local WIDTH = 360
-- Less than this left before the respawn: not worth showing.
local MIN_SHOWN = 0.6

local DeathScreenController = {}

local gui: ScreenGui
local group: CanvasGroup
local eyebrow: TextLabel
local title: TextLabel
local levelLabel: TextLabel
local kitLabel: TextLabel
local dash: TextLabel
local finisherLabel: TextLabel
local fill: Frame
local countNum: TextLabel
local grade: ColorCorrectionEffect

local token = 0 -- +1 on every death / respawn: older delays do nothing
local respawnAt = 0 -- os.clock()
local stepConnection: RBXScriptConnection? = nil

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function build()
	gui = Theme.make("ScreenGui", {
		Name = "DeathScreen",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 7, -- over the HUD and the kill feed, under the menu
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- A dark band low on the screen, no visible edge.
	Theme.make("Frame", {
		Name = "Scrim",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0,
		Parent = gui,
	}, { Theme.gradient(-90, { { 0, 0.35 }, { 0.5, 0.7 }, { 1, 1 } }) })

	group = Theme.make("CanvasGroup", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -72),
		Size = UDim2.fromOffset(WIDTH, 132),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = gui,
	}) :: CanvasGroup
	Theme.autoScale(group, 0.75)

	eyebrow = Theme.text({
		Name = "Eyebrow",
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = 10,
		TextColor3 = C.Ink2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Parent = group,
	}) :: TextLabel
	title = Theme.text({
		Name = "Title",
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = Theme.Fonts.Display,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = group,
	}) :: TextLabel

	-- "17  BOXER  — LIVER RIP", centred as one line.
	local line = Theme.make("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = group,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function part(name: string, order: number, props: { [string]: any }): TextLabel
		props.Name = name
		props.LayoutOrder = order
		props.AutomaticSize = Enum.AutomaticSize.X
		props.Size = UDim2.fromOffset(0, 14)
		props.Parent = line
		return Theme.text(props) :: TextLabel
	end
	levelLabel = part("Level", 1, {
		FontFace = Theme.Fonts.Number,
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = "",
	})
	kitLabel = part("Kit", 2, { TextSize = 11, TextColor3 = C.Ink, Text = "" })
	dash = part("Dash", 3, { TextSize = 11, TextColor3 = C.BloodHi, Text = "—" })
	finisherLabel = part("Finisher", 4, {
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 11,
		TextColor3 = C.Ink2,
		Text = "",
	})

	-- Respawn countdown: a hairline that drains, the seconds on the right.
	local track = Theme.make("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.8,
		Parent = group,
	})
	fill = Theme.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink,
		Parent = track,
	}) :: Frame
	Theme.text({
		Name = "RespawnLabel",
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.fromOffset(160, 12),
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = Theme.track("RESPAWN", "three"),
		Parent = group,
	})
	countNum = Theme.text({
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 102),
		Size = UDim2.fromOffset(60, 14),
		FontFace = Theme.Fonts.Number,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = group,
	}) :: TextLabel

	grade = Theme.make("ColorCorrectionEffect", {
		Name = "DeathGrade",
		Enabled = false,
		Parent = Lighting,
	}) :: ColorCorrectionEffect
end

------------------------------------------------------------------------------
-- Showing
------------------------------------------------------------------------------

local function stopStepping()
	if stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
end

local function step()
	local left = math.max(0, respawnAt - os.clock())
	fill.Size = UDim2.fromScale(math.clamp(left / RESPAWN_TIME, 0, 1), 1)
	countNum.Text = string.format("%.1f", left)
end

local function hide()
	token += 1
	stopStepping()
	if not gui.Enabled then
		return
	end
	local current = token
	Theme.tween(group, 0.2, { GroupTransparency = 1 })
	Theme.tween(grade, 0.4, { Saturation = 0, Brightness = 0 })
	task.delay(0.4, function()
		if token == current then
			gui.Enabled = false
			grade.Enabled = false
		end
	end)
end

local function show(current: number)
	if token ~= current or respawnAt - os.clock() < MIN_SHOWN then
		return
	end
	gui.Enabled = true
	grade.Enabled = true
	step()
	stopStepping()
	stepConnection = RunService.RenderStepped:Connect(step)
	group.GroupTransparency = 1
	group.Position = UDim2.new(0.5, 0, 1, -60)
	Theme.tween(group, 0.35, {
		GroupTransparency = 0,
		Position = UDim2.new(0.5, 0, 1, -72),
	}, Enum.EasingStyle.Quart)
	Theme.tween(grade, 0.6, { Saturation = -0.6, Brightness = -0.06 })
end

local function onKillFeed(
	kind: unknown,
	_victim: unknown,
	killer: unknown,
	_victimLevel: unknown,
	killerLevel: unknown,
	rawDetails: unknown
)
	local details = KillFeedController.readDetails(rawDetails)
	if details.victimId ~= player.UserId or kind == "Fled" then
		return
	end
	token += 1
	local current = token
	respawnAt = os.clock() + RESPAWN_TIME

	local killerName = if typeof(killer) == "string" then killer else nil
	local finished = kind == "Finished"
	if killerName then
		eyebrow.Text = Theme.track(if finished then "FINISHED BY" else "ELIMINATED BY", "three")
		title.Text = killerName
	else
		eyebrow.Text = Theme.track("ELIMINATED", "three")
		title.Text = Theme.track("YOU DIED", "thin")
	end
	local level = if typeof(killerLevel) == "number" and killerName then killerLevel else nil
	levelLabel.Text = if level then `LV {math.floor(level)}` else ""
	levelLabel.Visible = level ~= nil
	local kit = Kits.get(details.killerKit)
	kitLabel.Text = if kit and killerName then Theme.track(kit.name, "three") else ""
	kitLabel.Visible = kitLabel.Text ~= ""
	local finisher = if finished then details.finisher else nil
	finisherLabel.Text = if finisher then Theme.track(finisher, "three") else ""
	finisherLabel.Visible = finisher ~= nil
	dash.Visible = finisher ~= nil and kitLabel.Visible

	-- A finisher's cutscene first (our camera is in it).
	local cutsceneLeft = math.max(0, CinematicController.watchingUntil() - os.clock())
	if cutsceneLeft > 0 then
		task.delay(cutsceneLeft, show, current)
	else
		show(current)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function DeathScreenController.start()
	build()
	Remotes.KillFeed.OnClientEvent:Connect(onKillFeed)
	player.CharacterAdded:Connect(hide)
end

return DeathScreenController
