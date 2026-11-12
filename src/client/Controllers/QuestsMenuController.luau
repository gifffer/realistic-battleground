--!strict
-- QuestsMenuController: the QUESTS section of the menu (between DUEL and
-- PROFILE): today's 3 daily quests.
--
--   QUESTS
--   3 A DAY · NEW QUESTS IN 05:12:33
--   ──────────────────────────────────────────────────────────
--   TODAY                                          REWARD
--   Get 5 kills                                  +110 XP · +55
--   3 / 5  ━━━━━━━━━━━━━━━━━━━━━━━━━━────────────────────────
--   Win 2 duels                                         DONE
--   2 / 2  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--   ...
--
-- Everything comes from the save (data.quests, PlayerDataController): the
-- server draws the quests, counts the progress and gives the rewards
-- (Server/Systems/Quests). This screen only shows them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local QuestDefs = require(ReplicatedStorage.Shared.Quests)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)

local C = Theme.Colors

local SECTION_ID = "Quests"
local ROW_HEIGHT = 64

local QuestsMenuController = {}

type Row = {
	frame: Frame,
	text: TextLabel,
	reward: TextLabel,
	count: TextLabel,
	fill: Frame,
}

local rows: { Row } = {}
local resetLabel: TextLabel? = nil
local emptyLabel: TextLabel? = nil

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function caption(text: string, props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		TextSize = 10,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = Theme.track(text, "three"),
	}
	for key, value in props do
		base[key] = value
	end
	return Theme.text(base) :: TextLabel
end

local function buildRow(parent: Instance, index: number): Row
	local frame = Theme.make("Frame", {
		Name = `Quest{index}`,
		Position = UDim2.fromOffset(0, 26 + (index - 1) * ROW_HEIGHT),
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	local text = Theme.text({
		Name = "Text",
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, -160, 0, 18),
		FontFace = Theme.Fonts.Body,
		TextSize = 15,
		TextStrokeTransparency = 1,
		Parent = frame,
	}) :: TextLabel
	local reward = Theme.text({
		Name = "Reward",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 12),
		Size = UDim2.fromOffset(150, 14),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	}) :: TextLabel
	local count = Theme.text({
		Name = "Count",
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.fromOffset(70, 14),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextStrokeTransparency = 1,
		Parent = frame,
	}) :: TextLabel
	local track = Theme.make("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(80, 40),
		Size = UDim2.new(1, -80, 0, 2),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.82,
		Parent = frame,
	})
	local fill = Theme.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Ink,
		Parent = track,
	}) :: Frame
	Theme.make("Frame", {
		Name = "Hairline",
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.93,
		Parent = frame,
	})
	return { frame = frame, text = text, reward = reward, count = count, fill = fill }
end

local function build(content: Frame)
	local head = Theme.make("Frame", {
		Name = "TodayHead",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Parent = content,
	})
	caption("TODAY", { Size = UDim2.new(1, 0, 0, 12), Parent = head })
	caption("REWARD", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 1),
		Size = UDim2.fromOffset(120, 11),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = head,
	})
	Theme.make("Frame", {
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.9,
		Parent = head,
	})
	for index = 1, QuestDefs.PER_DAY do
		table.insert(rows, buildRow(content, index))
	end
	emptyLabel = caption("YOUR QUESTS ARRIVE WHEN YOUR SAVE IS LOADED", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 12),
		Visible = false,
		Parent = content,
	})
	resetLabel = caption("", {
		Position = UDim2.fromOffset(0, 26 + QuestDefs.PER_DAY * ROW_HEIGHT + 14),
		Size = UDim2.new(1, 0, 0, 12),
		Parent = content,
	})
end

------------------------------------------------------------------------------
-- Showing the save
------------------------------------------------------------------------------

local function refresh(animate: boolean)
	if #rows == 0 then
		return
	end
	local data = PlayerDataController.get()
	local quests = if data then data.quests else nil
	local list = if quests and quests.day == QuestDefs.today() then quests.list else {}
	local label = emptyLabel
	if label then
		label.Visible = #list == 0
	end
	for index, row in rows do
		local state = list[index]
		local quest = if state then QuestDefs.get(state.id) else nil
		row.frame.Visible = state ~= nil and quest ~= nil
		if state and quest then
			row.text.Text = QuestDefs.describe(quest, state.goal)
			row.text.TextColor3 = if state.done then C.Ink2 else C.Ink
			local xp, coins = QuestDefs.reward(quest, state.goal)
			row.reward.Text = if state.done
				then Theme.track("DONE", "three")
				else `+{xp} XP · +{coins}`
			row.reward.TextColor3 = if state.done then C.Ink else C.Ink2
			row.count.Text = `{state.progress} / {state.goal}`
			local ratio = if state.goal > 0
				then math.clamp(state.progress / state.goal, 0, 1)
				else 1
			if animate then
				Theme.tween(
					row.fill,
					0.3,
					{ Size = UDim2.fromScale(ratio, 1) },
					Enum.EasingStyle.Quart
				)
			else
				row.fill.Size = UDim2.fromScale(ratio, 1)
			end
		end
	end
end

-- "NEW QUESTS IN 05:12:33" (midnight UTC), updated every second while open.
local lastShown = -1
local function updateCountdown()
	local label = resetLabel
	if label == nil or MenuController.getOpen() ~= SECTION_ID then
		return
	end
	local left = (QuestDefs.today() + 1) * 86400 - os.time()
	if left == lastShown then
		return
	end
	if left > 86399 then
		refresh(false) -- a new day just started
	end
	lastShown = left
	label.Text = Theme.track(
		string.format(
			"NEW QUESTS IN %02d:%02d:%02d",
			math.floor(left / 3600),
			math.floor((left % 3600) / 60),
			left % 60
		),
		"three"
	)
end

function QuestsMenuController.start()
	MenuController.register({
		id = SECTION_ID,
		label = "QUESTS",
		subtitle = "3 A DAY · NEW EVERY DAY AT MIDNIGHT UTC",
		order = 40, -- between DUEL (30) and PROFILE (50)
		size = Vector2.new(560, 400),
		scrimWidth = 1100,
		build = function(content)
			build(content)
			refresh(false)
		end,
	})
	MenuController.onOpenChanged(function(id)
		if id == SECTION_ID then
			refresh(true)
			updateCountdown()
		end
	end)
	PlayerDataController.onChanged(function()
		refresh(MenuController.getOpen() == SECTION_ID)
	end)
	RunService.Heartbeat:Connect(updateCountdown)
end

return QuestsMenuController
