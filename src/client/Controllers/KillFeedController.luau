--!strict
-- KillFeedController: the eliminations, top right. Plain lines, no boxes:
--
--        gifffer  finished  Dummy    0:04  |
--   Vex  fled — kill to  Rook_77         0:11
--          Rook_77  eliminated  Mara     0:26
--
-- • Names in condensed type, verbs lighter and lower-case, the age of the
--   line in small monospaced numbers.
-- • YOUR name is bold white, and your lines get a thin tick on the right.
-- • Each line sits on a dark band that fades out to the left, so it stays
--   readable on a bright scene and almost invisible on a dark one.
-- • Older lines (third and beyond) are dimmer; each line fades out after
--   FEED_TIME seconds; never more than FEED_LINES lines.
--
-- One line per Remotes.KillFeed message from the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)

local player = Players.LocalPlayer
local K = Config.Knockout
local C = Theme.Colors

local ROW_HEIGHT = 22
local OLD_ROW_TRANSPARENCY = 0.28

type Row = {
	frame: Frame,
	texts: { TextLabel },
	age: TextLabel,
	createdAt: number,
	order: number,
	fading: boolean, -- leaving: restyle() must not bring it back
}

local KillFeedController = {}

local gui: ScreenGui
local feed: Frame
local rows: { Row } = {} -- newest first
local order = 0

-- One word / name of the line.
local function piece(text: string, kind: "name" | "you" | "verb", layout: number): TextLabel
	return Theme.text({
		LayoutOrder = layout,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ROW_HEIGHT),
		FontFace = if kind == "you"
			then Theme.Fonts.LabelBold
			elseif kind == "verb" then Theme.Fonts.LabelRegular
			else Theme.Fonts.Label,
		TextSize = 13,
		TextColor3 = if kind == "you" then C.InkHi elseif kind == "verb" then C.InkVerb else C.Ink,
		TextTransparency = 1,
		Text = text,
	})
end

-- The pieces of a line: { {text, kind}, ... }
local function phrase(kind: Types.KillFeedKind, victim: string, killer: string?): { { string } }
	local function name(text: string): { string }
		return { text, if text == player.DisplayName then "you" else "name" }
	end
	if kind == "Finished" and killer then
		return { name(killer), { "finished", "verb" }, name(victim) }
	elseif kind == "Fled" and killer then
		return { name(victim), { "fled — kill to", "verb" }, name(killer) }
	elseif kind == "Fled" then
		return { name(victim), { "fled", "verb" } }
	elseif killer then
		return { name(killer), { "eliminated", "verb" }, name(victim) }
	end
	return { name(victim), { "died", "verb" } }
end

local function formatAge(seconds: number): string
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function restyle()
	for index, row in rows do
		if row.fading then
			continue
		end
		local target = if index >= 3 then OLD_ROW_TRANSPARENCY else 0
		for _, text in row.texts do
			Theme.tween(text, 0.18, { TextTransparency = target })
		end
	end
end

local function removeRow(row: Row)
	local index = table.find(rows, row)
	if index then
		table.remove(rows, index)
	end
	row.frame:Destroy()
end

local function addLine(kind: unknown, victim: unknown, killer: unknown)
	if typeof(kind) ~= "string" or typeof(victim) ~= "string" then
		return
	end
	local killerName = if typeof(killer) == "string" then killer else nil
	local pieces = phrase(kind :: Types.KillFeedKind, victim, killerName)
	local mine = victim == player.DisplayName or killerName == player.DisplayName

	order -= 1
	local frame = Theme.make("Frame", {
		Name = "Row",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		Parent = feed,
	}) :: Frame
	-- Dark band behind the text, fading to nothing on the left.
	Theme.make("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 16, 0, 1),
		Size = UDim2.new(0.85, 0, 1, -2),
		BackgroundColor3 = C.Scrim,
		ZIndex = 0,
		Parent = frame,
	}, { Theme.gradient(0, { { 0, 1 }, { 0.55, 0.62 }, { 1, 0.45 } }) })
	local content = Theme.make("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(12, 0), -- slides in from the right
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = frame,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local texts: { TextLabel } = {}
	for index, part in pieces do
		local label = piece(part[1], part[2] :: any, index)
		label.Parent = content
		table.insert(texts, label)
	end
	local age = Theme.text({
		Name = "Age",
		LayoutOrder = 100,
		Size = UDim2.fromOffset(40, ROW_HEIGHT),
		FontFace = Theme.Fonts.Number,
		TextSize = 10,
		TextColor3 = C.Ink2,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0:00",
		Parent = content,
	}) :: TextLabel
	table.insert(texts, age)
	if mine then
		Theme.make("Frame", {
			Name = "Tick",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1, 10, 0.5, 0),
			Size = UDim2.fromOffset(2, 12),
			BackgroundColor3 = C.Ink,
			Parent = frame,
		})
	end

	local row: Row = {
		frame = frame,
		texts = texts,
		age = age,
		createdAt = os.clock(),
		order = order,
		fading = false,
	}
	table.insert(rows, 1, row)
	Theme.tween(content, 0.18, { Position = UDim2.fromOffset(0, 0) })
	restyle()

	-- Too many lines: drop the oldest.
	while #rows > K.FEED_LINES do
		removeRow(rows[#rows])
	end

	task.delay(K.FEED_TIME, function()
		if row.frame.Parent == nil then
			return
		end
		row.fading = true
		for _, text in row.texts do
			Theme.tween(text, 0.6, { TextTransparency = 1 }, Enum.EasingStyle.Linear)
		end
		local band = row.frame:FindFirstChild("Band")
		if band then
			Theme.tween(band :: Frame, 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
		end
		task.delay(0.6, function()
			if row.frame.Parent then
				removeRow(row)
			end
		end)
	end)
end

-- Ages ("0:04") are updated once a second.
local lastAgeUpdate = 0
local function updateAges()
	local now = os.clock()
	if now - lastAgeUpdate < 1 then
		return
	end
	lastAgeUpdate = now
	for _, row in rows do
		row.age.Text = formatAge(now - row.createdAt)
	end
end

function KillFeedController.start()
	gui = Theme.make("ScreenGui", {
		Name = "KillFeed",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})
	feed = Theme.make("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 36),
		Size = UDim2.fromOffset(360, K.FEED_LINES * ROW_HEIGHT),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})
	Remotes.KillFeed.OnClientEvent:Connect(addLine)
	RunService.Heartbeat:Connect(updateAges)
	-- Hidden while the menu is open.
	MenuController.onOpenChanged(function(id)
		gui.Enabled = id == nil
	end)
end

return KillFeedController
