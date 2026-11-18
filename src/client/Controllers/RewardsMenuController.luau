--!strict
-- RewardsMenuController: the REWARDS panel (the gift button in the top bar).
--
--   REWARDS | CHALLENGES (2)
--                         REWARDS
--   +-------+  92 / 100 XP                       8 XP to Bouncer
--   | LEVEL |  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━──
--   |   4   |
--   +-------+
--   [5  KIT ][8  KIT ][8 EMOTE][10 TITLE][10 EFFECT] ...
--
-- REWARDS: your level and the XP bar on top (like a season pass), then a
-- track of cards: everything a level unlocks (kits and cosmetics with an
-- unlock level), in level order. The level is top left of each card, the
-- type top right. Reached = "UNLOCKED" in gold; the next one is picked
-- (lighter, white outline). Click a card: its KITS / SHOP / EMOTES panel
-- opens on it (that's where it is bought).
-- CHALLENGES: today's 3 daily quests as cards (the sentence, a bar, the
-- count, the reward; done = gold), and when they renew.
--
-- The count on the top bar button (and on the CHALLENGES tab): quests
-- finished and levels unlocked since you last looked.
--
-- Everything comes from the save (PlayerDataController): the server draws
-- the quests, counts the progress and gives the rewards
-- (Server/Systems/Quests), the XP and the level. This panel only shows them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Kits = require(ReplicatedStorage.Shared.Kits)
local ProgressionCurve = require(ReplicatedStorage.Shared.Progression)
local QuestDefs = require(ReplicatedStorage.Shared.Quests)
local Panel = require(script.Parent.Parent.UI.Panel)
local Theme = require(script.Parent.Parent.UI.Theme)
local KitsMenuController = require(script.Parent.KitsMenuController)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)
local ProfileMenuController = require(script.Parent.ProfileMenuController)
local ShopMenuController = require(script.Parent.ShopMenuController)

local player = Players.LocalPlayer
local formatNumber = ProfileMenuController.formatNumber
local C = Theme.Colors

local SECTION_ID = "Rewards"
local WIDTH = 624
local HEIGHT = 286
local LEVEL_BOX = 84
local TRACK_Y = 104
local TRACK_CARD = Vector2.new(112, 150)
local QUEST_CARD = Vector2.new((WIDTH - 16) / 3, 210)
local MAX_LEVEL: number = Config.Progression.MAX_LEVEL

local RewardsMenuController = {}

-- One thing a level unlocks.
type Unlock = {
	level: number,
	name: string,
	tag: string,
	kit: Kits.KitDef?,
	item: Cosmetics.Item?,
}

type QuestCard = {
	card: Panel.Card,
	text: TextLabel,
	fill: Frame,
}

local unlocks: { Unlock } = {}
local built = false
local tabs: Panel.Tabs? = nil
local pages: { Frame } = {}
local trackCards: { Panel.Card } = {}
local questCards: { QuestCard } = {}
local levelNumber: TextLabel
local xpText: TextLabel
local nextText: TextLabel
local xpFill: Frame
local resetLabel: TextLabel
local emptyLabel: TextLabel
local track: ScrollingFrame

-- What the player has already seen (the counts on the button).
local seenQuests: { [string]: boolean } = {}
local seenLevel: number? = nil
local questsPrimed = false
local unseenQuests = 0
local unseenUnlocks = 0

------------------------------------------------------------------------------
-- From the save
------------------------------------------------------------------------------

local function levelInfo(): (number, number, number)
	local data = PlayerDataController.get()
	if data then
		return ProgressionCurve.levelFromXp(data.xp)
	end
	local attribute = player:GetAttribute("Level")
	local level = if typeof(attribute) == "number"
		then math.clamp(math.floor(attribute), 1, MAX_LEVEL)
		else 1
	return level, 0, ProgressionCurve.xpToNext(level)
end

type QuestStateLike = { id: string, goal: number, progress: number, done: boolean }

local function questList(): { QuestStateLike }
	local data = PlayerDataController.get()
	local quests = if data then data.quests else nil
	-- (The server's list as it is: the client's own clock may be off.)
	return if quests then quests.list else {}
end

local function questKey(state: QuestStateLike): string
	local data = PlayerDataController.get()
	local day = if data then data.quests.day else 0
	return `{day}:{state.id}:{state.goal}`
end

-- Every unlock, in level order (kits first on the same level).
local function collectUnlocks()
	for _, kit in Kits.list() do
		if kit.unlockLevel and kit.available then
			table.insert(
				unlocks,
				{ level = kit.unlockLevel, name = kit.name, tag = "KIT", kit = kit }
			)
		end
	end
	local tags: { [string]: string } = {
		Title = "TITLE",
		Outfit = "OUTFIT",
		KillEffect = "EFFECT",
		Emote = "EMOTE",
	}
	for _, item in Cosmetics.ITEMS do
		if item.unlockLevel then
			table.insert(unlocks, {
				level = item.unlockLevel,
				name = item.name,
				tag = tags[item.category] or "ITEM",
				item = item,
			})
		end
	end
	table.sort(unlocks, function(a, b)
		if a.level ~= b.level then
			return a.level < b.level
		end
		if (a.kit ~= nil) ~= (b.kit ~= nil) then
			return a.kit ~= nil
		end
		return a.name < b.name
	end)
end

------------------------------------------------------------------------------
-- Badges
------------------------------------------------------------------------------

local function isShowing(page: number): boolean
	local current = tabs
	return built
		and MenuController.getOpen() == SECTION_ID
		and current ~= nil
		and current.get() == page
end

local function updateBadges()
	local level = levelInfo()
	if seenLevel == nil and PlayerDataController.get() then
		seenLevel = level -- (what you had when you joined counts as seen)
	end
	-- Looking at the page: everything on it is seen.
	if isShowing(1) then
		seenLevel = level
	end
	local list = questList()
	-- Looking at the challenges, or the first save (quests done before this
	-- session): the finished ones are seen.
	local firstSave = not questsPrimed and PlayerDataController.get() ~= nil
	if firstSave or isShowing(2) then
		questsPrimed = questsPrimed or firstSave
		for _, state in list do
			if state.done then
				seenQuests[questKey(state)] = true
			end
		end
	end
	unseenQuests = 0
	for _, state in list do
		if state.done and not seenQuests[questKey(state)] then
			unseenQuests += 1
		end
	end
	unseenUnlocks = 0
	local seen = seenLevel or level
	for _, unlock in unlocks do
		if unlock.level > seen and unlock.level <= level then
			unseenUnlocks += 1
		end
	end
	MenuController.setBadge(SECTION_ID, unseenQuests + unseenUnlocks)
	local current = tabs
	if current then
		current.setBadge(1, unseenUnlocks)
		current.setBadge(2, unseenQuests)
	end
end

------------------------------------------------------------------------------
-- REWARDS page
------------------------------------------------------------------------------

local function buildRewards(page: Frame)
	-- The level box.
	local box = Theme.make("Frame", {
		Name = "LevelBox",
		Size = UDim2.fromOffset(LEVEL_BOX, LEVEL_BOX),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.2,
		Parent = page,
	})
	Theme.text({
		Name = "Caption",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Theme.Fonts.Display,
		TextSize = 14,
		TextColor3 = C.InkHi,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "LEVEL",
		Parent = box,
	})
	levelNumber = Theme.text({
		Name = "Level",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 48),
		FontFace = Theme.Fonts.Display,
		TextSize = 44,
		TextColor3 = C.InkHi,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = box,
	}) :: TextLabel
	-- XP: "92 / 100 XP" on the left, what's next on the right, the bar under.
	xpText = Theme.text({
		Name = "Xp",
		Position = UDim2.fromOffset(LEVEL_BOX + 18, 6),
		Size = UDim2.fromOffset(260, 28),
		FontFace = Theme.Fonts.Display,
		TextSize = 22,
		TextColor3 = C.InkHi,
		TextStrokeTransparency = 1,
		RichText = true,
		Parent = page,
	}) :: TextLabel
	nextText = Theme.text({
		Name = "Next",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 12),
		Size = UDim2.fromOffset(300, 18),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 14,
		TextColor3 = C.InkHi,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = page,
	}) :: TextLabel
	local _, fill = Panel.bar(page, {
		Name = "XpBar",
		Position = UDim2.fromOffset(LEVEL_BOX + 18, 42),
		Size = UDim2.new(1, -(LEVEL_BOX + 18), 0, 10),
	})
	xpFill = fill
	Theme.text({
		Name = "Hint",
		Position = UDim2.fromOffset(LEVEL_BOX + 18, 60),
		Size = UDim2.new(1, -(LEVEL_BOX + 18), 0, 16),
		FontFace = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		Text = "Fights, duels and challenges give XP. Each level unlocks something below.",
		Parent = page,
	})

	-- The track: one card per unlock, scrolls sideways.
	track = Theme.make("ScrollingFrame", {
		Name = "Track",
		Position = UDim2.fromOffset(0, TRACK_Y),
		Size = UDim2.new(1, 0, 0, TRACK_CARD.Y + 12),
		BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Ink,
		ScrollBarImageTransparency = 0.5,
		HorizontalScrollBarInset = Enum.ScrollBarInset.Always,
		Parent = page,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Theme.make("UIPadding", { PaddingLeft = UDim.new(0, 1), PaddingTop = UDim.new(0, 1) }),
	}) :: ScrollingFrame
	for order, unlock in unlocks do
		local card = Panel.card({
			parent = track,
			name = unlock.name,
			tag = unlock.tag,
			number = tostring(unlock.level),
			size = TRACK_CARD,
			layoutOrder = order,
			onActivated = function()
				local kit = unlock.kit
				local item = unlock.item
				if kit then
					KitsMenuController.show(kit.id)
				elseif item then
					ShopMenuController.show(item.id)
				end
			end,
		})
		local kit = unlock.kit
		local item = unlock.item
		if kit then
			Panel.figure(card.art, { pose = KitsMenuController.poseOf(kit.id) })
		elseif item then
			ShopMenuController.fillArt(card.art, item)
		end
		table.insert(trackCards, card)
	end
end

local function refreshRewards(animate: boolean)
	local level, xp, needed = levelInfo()
	levelNumber.Text = tostring(level)
	local atMax = level >= MAX_LEVEL
	xpText.Text = if atMax
		then "MAX LEVEL"
		else `{formatNumber(xp)} <font size="16" color="#9A9A9A">/ {formatNumber(needed)} XP</font>`
	local ratio = if atMax or needed <= 0 then 1 else math.clamp(xp / needed, 0, 1)
	if animate then
		Theme.tween(xpFill, 0.35, { Size = UDim2.fromScale(ratio, 1) }, Enum.EasingStyle.Quart)
	else
		xpFill.Size = UDim2.fromScale(ratio, 1)
	end
	-- The next unlock: picked, and named on the right.
	local nextIndex: number? = nil
	for index, unlock in unlocks do
		if unlock.level > level then
			nextIndex = index
			break
		end
	end
	for index, card in trackCards do
		local unlock = unlocks[index]
		local reached = unlock.level <= level
		card.setSub(
			if reached then "Unlocked" else `Level {unlock.level}`,
			if reached then C.Gold else C.Ink2
		)
		card.setNumber(tostring(unlock.level), if reached then C.Gold else C.InkHi)
		card.setSelected(index == nextIndex)
		card.setDim(not reached and index ~= nextIndex)
	end
	if nextIndex then
		local unlock = unlocks[nextIndex]
		nextText.Text = `Level {unlock.level}: {unlock.name}`
	else
		nextText.Text = if atMax then "" else "Everything is unlocked"
	end
end

------------------------------------------------------------------------------
-- CHALLENGES page
------------------------------------------------------------------------------

local function buildChallenges(page: Frame)
	local row = Theme.make("Frame", {
		Name = "Quests",
		Size = UDim2.new(1, 0, 0, QUEST_CARD.Y),
		BackgroundTransparency = 1,
		Parent = page,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	for index = 1, QuestDefs.PER_DAY do
		local card = Panel.card({
			parent = row,
			name = "",
			tag = "DAILY",
			number = tostring(index),
			size = QUEST_CARD,
			layoutOrder = index,
		})
		card.instance.Active = false
		card.instance.AutoButtonColor = false
		local text = Theme.text({
			Name = "Quest",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.new(1, -24, 0, 60),
			FontFace = Theme.Fonts.Display,
			TextSize = 18,
			TextColor3 = C.InkHi,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Parent = card.art,
		}) :: TextLabel
		local _, fill = Panel.bar(card.art, {
			Name = "Progress",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -24, 0, 6),
		})
		table.insert(questCards, { card = card, text = text, fill = fill })
	end
	emptyLabel = Theme.text({
		Name = "Empty",
		Position = UDim2.fromOffset(0, QUEST_CARD.Y / 2 - 8),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Theme.Fonts.Body,
		TextSize = 13,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Your challenges arrive when your save is loaded.",
		Visible = false,
		Parent = page,
	}) :: TextLabel
	resetLabel = Theme.text({
		Name = "Reset",
		Position = UDim2.fromOffset(0, QUEST_CARD.Y + 14),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 13,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = page,
	}) :: TextLabel
end

local function refreshChallenges(animate: boolean)
	local list = questList()
	emptyLabel.Visible = #list == 0
	for index, entry in questCards do
		local state = list[index]
		local quest = if state then QuestDefs.get(state.id) else nil
		entry.card.instance.Visible = state ~= nil and quest ~= nil
		if state and quest then
			entry.text.Text = QuestDefs.describe(quest, state.goal)
			entry.text.TextColor3 = if state.done then C.Ink2 else C.InkHi
			local xp, coins = QuestDefs.reward(quest, state.goal)
			entry.card.setName(`+{xp} XP · +{coins} coins`)
			entry.card.setSub(
				if state.done then "Done" else `{state.progress} / {state.goal}`,
				if state.done then C.Gold else C.Ink2
			)
			entry.card.setEquipped(state.done)
			local ratio = if state.goal > 0
				then math.clamp(state.progress / state.goal, 0, 1)
				else 1
			if animate then
				Theme.tween(
					entry.fill,
					0.3,
					{ Size = UDim2.fromScale(ratio, 1) },
					Enum.EasingStyle.Quart
				)
			else
				entry.fill.Size = UDim2.fromScale(ratio, 1)
			end
		end
	end
end

-- "New challenges in 05:12:33" (midnight UTC), every second while shown.
local lastShown = -1
local function updateCountdown()
	if not isShowing(2) then
		return
	end
	-- Server time (the same clock for everyone), not this computer's.
	local now = math.floor(workspace:GetServerTimeNow())
	local left = (math.floor(now / 86400) + 1) * 86400 - now
	if left == lastShown then
		return
	end
	lastShown = left
	resetLabel.Text = string.format(
		"New challenges in %02d:%02d:%02d",
		math.floor(left / 3600),
		math.floor((left % 3600) / 60),
		left % 60
	)
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function refresh(animate: boolean)
	if built then
		refreshRewards(animate)
		refreshChallenges(animate)
	end
	updateBadges()
end

local function showPage(index: number)
	for page, frame in pages do
		frame.Visible = page == index
	end
	lastShown = -1
	updateCountdown()
	updateBadges()
end

local function build(content: Frame, host: MenuController.Host)
	for index = 1, 2 do
		table.insert(
			pages,
			Theme.make("Frame", {
				Name = if index == 1 then "RewardsPage" else "ChallengesPage",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = index == 1,
				Parent = content,
			}) :: Frame
		)
	end
	buildRewards(pages[1])
	buildChallenges(pages[2])
	tabs = host.tabs
	local current = tabs
	if current then
		current.bind(showPage)
	end
	built = true
	refresh(false)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function RewardsMenuController.start()
	collectUnlocks()
	MenuController.register({
		id = SECTION_ID,
		label = "REWARDS",
		icon = "rewards",
		hint = "Rewards",
		tabs = { "REWARDS", "CHALLENGES" },
		order = 40,
		size = Vector2.new(WIDTH, HEIGHT),
		build = build,
	})
	MenuController.onOpenChanged(function(id)
		if id == SECTION_ID then
			-- Unseen challenges first: open on their page.
			local current = tabs
			if current and unseenQuests > 0 and unseenUnlocks == 0 then
				current.set(2)
			end
			refresh(true)
			lastShown = -1
			updateCountdown()
		end
	end)
	PlayerDataController.onChanged(function()
		refresh(MenuController.getOpen() == SECTION_ID)
	end)
	player:GetAttributeChangedSignal("Level"):Connect(function()
		refresh(MenuController.getOpen() == SECTION_ID)
	end)
	RunService.Heartbeat:Connect(updateCountdown)
end

return RewardsMenuController
