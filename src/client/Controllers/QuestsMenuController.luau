--!strict
-- QuestsMenuController: the QUESTS section of the menu (between DUEL and
-- PROFILE): today's 3 daily quests.
--
--   QUESTS
--   Get 5 kills                                  +110 XP · +55
--   3 / 5  ━━━━━━━━━━━━━━━━━━━━━━━━━━────────────────────────
--   Win 2 duels                                         Done
--   2 / 2  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--   ...
--   New quests in 05:12:33
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
local ROW_HEIGHT = 52

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
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.SMALL,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = text,
	}
	for key, value in props do
		base[key] = value
	end
	return Theme.text(base) :: TextLabel
end

local function buildRow(parent: Instance, index: number): Row
	local frame = Theme.make("Frame", {
		Name = `Quest{index}`,
		Position = UDim2.fromOffset(0, (index - 1) * ROW_HEIGHT),
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	local text = Theme.text({
		Name = "Text",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, -160, 0, 16),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TEXT,
		TextStrokeTransparency = 1,
		Parent = frame,
	}) :: TextLabel
	local reward = Theme.text({
		Name = "Reward",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 9),
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
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.fromOffset(70, 14),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextStrokeTransparency = 1,
		Parent = frame,
	}) :: TextLabel
	local track = Theme.make("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(64, 34),
		Size = UDim2.new(1, -64, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.85,
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
	for index = 1, QuestDefs.PER_DAY do
		table.insert(rows, buildRow(content, index))
	end
	emptyLabel = caption("Your quests arrive when your save is loaded.", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 12),
		Visible = false,
		Parent = content,
	})
	resetLabel = caption("", {
		Position = UDim2.fromOffset(0, QuestDefs.PER_DAY * ROW_HEIGHT + 12),
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
	-- (The server's list as it is: the client's own clock may be off.)
	local list = if quests then quests.list else {}
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
			row.reward.Text = if state.done then "Done" else `+{xp} XP · +{coins}`
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

-- "New quests in 05:12:33" (midnight UTC), updated every second while open.
local lastShown = -1
local function updateCountdown()
	local label = resetLabel
	if label == nil or MenuController.getOpen() ~= SECTION_ID then
		return
	end
	-- Server time (the same clock for everyone), not this computer's.
	local now = math.floor(workspace:GetServerTimeNow())
	local left = (math.floor(now / 86400) + 1) * 86400 - now
	if left == lastShown then
		return
	end
	lastShown = left
	label.Text = string.format(
		"New quests in %02d:%02d:%02d",
		math.floor(left / 3600),
		math.floor((left % 3600) / 60),
		left % 60
	)
end

function QuestsMenuController.start()
	MenuController.register({
		id = SECTION_ID,
		label = "QUESTS",
		order = 40, -- between DUEL (30) and PROFILE (50)
		size = Vector2.new(480, 304), -- 3 rows and the countdown
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
