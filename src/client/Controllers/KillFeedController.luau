--!strict
-- KillFeedController: the eliminations, top right. Plain lines, no boxes:
--
--   8 gifffer  finished  Dummy  — HOME RUN    0:04  |
--         31 Vex  fled — kill to  17 Rook_77    0:11
--             17 Rook_77  eliminated  12 Mara    0:26
--
-- • A finisher kill names the finisher after the victim ("— LIVER RIP",
--   a short red dash, small caps), sent by the server with the line.
-- • Names in condensed type, verbs lighter and lower-case, the age of the
--   line in small monospaced numbers.
-- • Each player's name has their level just before it, small and grey
--   ("8 gifffer"). It is the level at the moment of the event (sent by the
--   server with the line) and never changes afterwards. No level for a
--   training dummy (it isn't a player).
-- • YOUR name is bold white, and your lines get a thin tick on the right.
-- • Each line sits on a dark band that fades out to the left, so it stays
--   readable on a bright scene and almost invisible on a dark one.
-- • Older lines (third and beyond) are dimmer; each line fades out after
--   FEED_TIME seconds; never more than FEED_LINES lines.
--
-- One line per Remotes.KillFeed message from the server. "You" is told by
-- UserId when the server sends it (two players can share a display name).
--
-- KillFeedController.readDetails(value) checks the line's details table
-- (the death screen reads the same message).
--
-- KillFeedController.setHidden(true / false) hides the whole feed for a
-- moment (the scoreboard does it while Tab is held: the board sits in the
-- same corner).

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
-- Room around the feed inside the fading layer (the dark bands and the
-- tick stick out on the right of the feed; a CanvasGroup cuts what is
-- outside it).
-- (Wide enough on the left for the longest line: two long names + verb.)
local LAYER_MARGIN = 40
local LAYER_EXTRA_LEFT = 380 -- (+ the finisher's name)
local FEED_TOP = 36 -- y of the first line inside the layer

-- What a line is made of, in order: names (with their level) and verbs.
type PartKind = "name" | "you" | "verb" | "finisher"

type Part = {
	text: string,
	kind: PartKind,
	level: number?, -- names only: shown just before the name
}

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
local layer: CanvasGroup? = nil -- the whole feed, fades as one (setHidden)
local feed: Frame
local hidden = false
local rows: { Row } = {} -- newest first
local order = 0

-- One word / name of the line.
local function piece(text: string, kind: PartKind, layout: number): TextLabel
	if kind == "finisher" then
		return Theme.text({
			LayoutOrder = layout,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, ROW_HEIGHT),
			FontFace = Theme.Fonts.LabelBold,
			TextSize = 11,
			TextColor3 = C.Ink2,
			TextTransparency = 1,
			Text = Theme.track(text, "three"),
		}, {
			-- 1 px lower: small caps on the names' baseline.
			Theme.make("UIPadding", { PaddingTop = UDim.new(0, 1) }),
		})
	end
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

-- A name with its level in front: "8 gifffer". The level label is left
-- out when there is no level (a dummy). Returns the group and its labels
-- (so the line can fade them).
local function nameGroup(part: Part, layout: number): (Frame, { TextLabel })
	local group = Theme.make("Frame", {
		Name = "NameGroup",
		LayoutOrder = layout,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, ROW_HEIGHT),
		BackgroundTransparency = 1,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
	local labels: { TextLabel } = {}
	if part.level then
		local level = Theme.text({
			Name = "Lv",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, ROW_HEIGHT),
			FontFace = Theme.Fonts.Number,
			TextSize = 10,
			TextColor3 = C.Ink2,
			TextTransparency = 1,
			Text = tostring(part.level),
			Parent = group,
		}, {
			-- 2 px lower: the small number sits on the name's baseline.
			Theme.make("UIPadding", { PaddingTop = UDim.new(0, 2) }),
		}) :: TextLabel
		table.insert(labels, level)
	end
	local name = piece(part.text, part.kind, 2)
	name.Name = "Name"
	name.Parent = group
	table.insert(labels, name)
	return group, labels
end

-- The parts of a line, in reading order. `victimIsYou` / `killerIsYou`:
-- that name is drawn as ours.
local function phrase(
	kind: Types.KillFeedKind,
	victim: string,
	killer: string?,
	victimLevel: number?,
	killerLevel: number?,
	victimIsYou: boolean,
	killerIsYou: boolean
): { Part }
	local function name(text: string, level: number?, you: boolean): Part
		return {
			text = text,
			kind = if you then "you" else "name",
			level = level,
		}
	end
	local function verb(text: string): Part
		return { text = text, kind = "verb" }
	end
	local victimPart = name(victim, victimLevel, victimIsYou)
	if kind == "Finished" and killer then
		return { name(killer, killerLevel, killerIsYou), verb("finished"), victimPart }
	elseif kind == "Fled" and killer then
		return { victimPart, verb("fled — kill to"), name(killer, killerLevel, killerIsYou) }
	elseif kind == "Fled" then
		return { victimPart, verb("fled") }
	elseif killer then
		return { name(killer, killerLevel, killerIsYou), verb("eliminated"), victimPart }
	end
	return { victimPart, verb("died") }
end

-- A short text from the remote (a name, a kit id), or nil.
local function readString(value: unknown): string?
	if typeof(value) == "string" and #value > 0 and #value <= 40 then
		return value
	end
	return nil
end

-- A UserId from the remote, or nil.
local function readId(value: unknown): number?
	if typeof(value) == "number" and value == value and math.abs(value) ~= math.huge then
		return value
	end
	return nil
end

-- The 6th argument of Remotes.KillFeed, checked field by field (a missing
-- or broken table gives empty details: the line still shows).
function KillFeedController.readDetails(value: unknown): Types.KillFeedDetails
	if typeof(value) ~= "table" then
		return {}
	end
	local raw = value :: { [string]: unknown }
	return {
		finisher = readString(raw.finisher),
		killerKit = readString(raw.killerKit),
		victimId = readId(raw.victimId),
		killerId = readId(raw.killerId),
	}
end

-- A level from the remote: a whole number, or nil (dummy / bad data).
local function readLevel(value: unknown): number?
	-- value == value: not NaN; the math.huge check: not infinite.
	if typeof(value) == "number" and value == value and math.abs(value) ~= math.huge then
		return math.floor(value)
	end
	return nil
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

local function addLine(
	kind: unknown,
	victim: unknown,
	killer: unknown,
	victimLevel: unknown,
	killerLevel: unknown,
	rawDetails: unknown
)
	if typeof(kind) ~= "string" or typeof(victim) ~= "string" then
		return
	end
	local killerName = if typeof(killer) == "string" then killer else nil
	local details = KillFeedController.readDetails(rawDetails)
	-- Ours: by UserId when the server sent one, else by display name.
	local victimIsYou = if details.victimId
		then details.victimId == player.UserId
		else victim == player.DisplayName
	local killerIsYou = if details.killerId
		then details.killerId == player.UserId
		else killerName ~= nil and killerName == player.DisplayName
	local parts = phrase(
		kind :: Types.KillFeedKind,
		victim,
		killerName,
		readLevel(victimLevel),
		if killerName then readLevel(killerLevel) else nil,
		victimIsYou,
		killerIsYou
	)
	local finisher = details.finisher
	-- (only with a killer: "Dummy died — HOME RUN" reads wrong)
	if kind == "Finished" and killerName and finisher then
		table.insert(parts, { text = "—", kind = "verb" })
		table.insert(parts, { text = finisher, kind = "finisher" })
	end
	local mine = victimIsYou or killerIsYou

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
	for index, part in parts do
		if part.kind == "verb" or part.kind == "finisher" then
			local label = piece(part.text, part.kind, index)
			-- (the dash before a finisher's name: blood red, like the
			-- Kits menu's fury versions)
			if part.kind == "verb" and parts[index + 1] and parts[index + 1].kind == "finisher" then
				label.TextColor3 = C.BloodHi
			end
			label.Parent = content
			table.insert(texts, label)
		else
			local group, labels = nameGroup(part, index)
			group.Parent = content
			for _, label in labels do
				table.insert(texts, label)
			end
		end
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

-- Hides (true) or shows again (false) the whole feed, with a short fade.
-- Used by the scoreboard while Tab is held. Lines keep arriving and
-- ageing while hidden; they are simply not drawn.
function KillFeedController.setHidden(value: boolean)
	if hidden == value then
		return
	end
	hidden = value
	if layer == nil then
		return -- not built yet: start() reads `hidden`
	end
	if value then
		Theme.tween(
			layer,
			0.1,
			{ GroupTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
	else
		Theme.tween(layer, 0.1, { GroupTransparency = 0 })
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
	-- The fading layer: the feed's corner plus a margin all around.
	local group = Theme.make("CanvasGroup", {
		Name = "Layer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(
			360 + 40 + LAYER_MARGIN + LAYER_EXTRA_LEFT,
			FEED_TOP + K.FEED_LINES * ROW_HEIGHT + LAYER_MARGIN
		),
		BackgroundTransparency = 1,
		GroupTransparency = if hidden then 1 else 0,
		Parent = gui,
	}) :: CanvasGroup
	layer = group
	-- Smaller on a phone, a little bigger on a large screen (from its corner).
	Theme.autoScale(group, 0.7)
	-- The first line (36 px down, scaled) stays under Roblox's top-bar buttons.
	Theme.onViewportChanged(function(viewport)
		local inset = Theme.topInset("right", viewport)
		local drop = math.max(0, inset + 4 - FEED_TOP * Theme.scaleFor(viewport, 0.7))
		group.Position = UDim2.new(1, 0, 0, drop)
	end)
	feed = Theme.make("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, FEED_TOP),
		Size = UDim2.fromOffset(360, K.FEED_LINES * ROW_HEIGHT),
		BackgroundTransparency = 1,
		Parent = group,
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
