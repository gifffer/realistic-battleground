--!strict
-- NameTagController: a small name over every OTHER player's head.
--
--                    31 Vex
--                 BARE KNUCKLE
--                   ┌──────┐
--                   │ head │
--
-- • Their level, small and grey-ish, then their display name. No box, no
--   health bar, no team colour: just type with a soft shadow, like the rest
--   of the HUD.
-- • Never over your own character, and Roblox's own name above heads is
--   turned off (Humanoid.DisplayDistanceType = None).
-- • The further away, the quieter (checked every 0.25 s):
--       up to 25 studs   name fully visible, level a bit faded
--       25 to 50         name a bit faded, level more faded
--       50 to 90         name faded more, no level
--       beyond 90        nothing (BillboardGui.MaxDistance)
--   The size never changes with distance: only the fade does.
-- • Walls hide it (AlwaysOnTop = false).
-- • Hidden while that player is knocked out AND the FINISH prompt is on
--   them (the prompt takes that spot), and while YOU are knocked out.
-- • Hidden on your duel opponent: during a duel the server gives both
--   characters the same "DuelId" attribute, and the opponent is already
--   named at the top of the screen (DuelController).
-- • The level follows the player's "Level" attribute (set by the server).
-- • Their title (bought in the SHOP) sits in small caps under the name,
--   from the player's "Title" attribute (set by the server; nil = no
--   title, no line). It fades with the distance like the level.
--
-- The tags are BillboardGuis in OUR PlayerGui (only we see them), with
-- their Adornee set to the other player's Head.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local C = Theme.Colors

local MAX_DISTANCE = 90 -- studs: beyond this the tag is not drawn at all
local TIER_CHECK = 0.25 -- seconds between two distance checks
local TIER_TWEEN = 0.2
local HIDE_TWEEN = 0.15
local NAME_MAX_WIDTH = 170 -- pixels; longer names end with "…"

-- Distance tiers: up to `distance` studs → these transparencies.
-- `level = nil` means the level is not shown at all.
type Tier = { distance: number, name: number, level: number? }
local TIERS: { Tier } = {
	{ distance = 25, name = 0, level = 0.25 }, -- near
	{ distance = 50, name = 0.25, level = 0.45 }, -- mid
	{ distance = math.huge, name = 0.5, level = nil }, -- far (MaxDistance hides beyond 90)
}

type Tag = {
	owner: Player,
	character: Model,
	gui: BillboardGui,
	levelLabel: TextLabel,
	nameLabel: TextLabel,
	titleLabel: TextLabel,
	tier: number, -- index in TIERS
	hidden: boolean,
	-- Last transparencies we tweened to (so we only tween on a change).
	nameTarget: number,
	levelTarget: number,
	titleTarget: number,
	connections: { RBXScriptConnection },
}

local NameTagController = {}

local playerGui: Instance
local tags: { [Player]: Tag } = {}
-- Per other player: connections watching their current character (head
-- arriving, character coming back into the world).
local watchers: { [Player]: { RBXScriptConnection } } = {}
local sinceTierCheck = 0

local function isKnockedOut(model: Model?): boolean
	return model ~= nil and model:GetAttribute("KnockedOut") == true
end

-- Turns Roblox's own name / health display off for a character.
local function hideDefaultName(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- Is the FINISH prompt (KnockoutController) currently shown on `character`?
local function finishPromptOn(character: Model): boolean
	local prompt = playerGui:FindFirstChild("FinishPrompt")
	if prompt == nil or not prompt:IsA("BillboardGui") or not prompt.Enabled then
		return false
	end
	local adornee: Instance? = prompt.Adornee -- nil when on no one
	return adornee ~= nil and adornee:IsDescendantOf(character)
end

------------------------------------------------------------------------------
-- Building one tag
------------------------------------------------------------------------------

local function buildGui(
	owner: Player,
	head: BasePart
): (BillboardGui, TextLabel, TextLabel, TextLabel)
	-- 20 px for the name row, with 12 px above AND below it: the title line
	-- goes below, and the empty strip above keeps the name exactly where it
	-- was (a BillboardGui is centred on its spot).
	local gui = Theme.make("BillboardGui", {
		Name = "NameTag_" .. owner.Name,
		Adornee = head,
		Size = UDim2.fromOffset(200, 44),
		-- About half a head above the top of the head, whatever its rotation.
		StudsOffsetWorldSpace = Vector3.new(0, 1.7, 0),
		AlwaysOnTop = false, -- walls hide it
		LightInfluence = 0, -- same brightness in the dark and in the sun
		MaxDistance = MAX_DISTANCE,
		ClipsDescendants = false,
		ResetOnSpawn = false, -- we manage it ourselves (see onCharacterAdded)
		Parent = playerGui,
	}) :: BillboardGui
	local row = Theme.make("Frame", {
		Name = "Row",
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local levelLabel = Theme.text({
		Name = "Lv",
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		FontFace = Theme.Fonts.Number,
		TextSize = 10,
		-- Ink (not the grey Ink2): grey vanished on the light floor.
		TextColor3 = C.Ink,
		TextTransparency = 1,
		Text = "",
		-- Starts out of the row: applyLook shows it when the tier wants
		-- it, so a far tag starts with its name centred alone.
		Visible = false,
		Parent = row,
	}, {
		-- 2 px lower: the small number sits on the name's baseline.
		Theme.make("UIPadding", { PaddingTop = UDim.new(0, 2) }),
	}) :: TextLabel
	local nameLabel = Theme.text({
		Name = "Name",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		TextSize = 13,
		TextColor3 = C.Ink,
		TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = owner.DisplayName,
		Parent = row,
	}, {
		-- The name grows with its text but never past NAME_MAX_WIDTH.
		Theme.make("UISizeConstraint", { MaxSize = Vector2.new(NAME_MAX_WIDTH, 20) }),
	}) :: TextLabel
	-- The title: small tracked caps under the name, as quiet as the level.
	local titleLabel = Theme.text({
		Name = "Title",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 11),
		TextSize = 9,
		TextColor3 = C.Ink,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = gui,
	}) :: TextLabel
	return gui, levelLabel, nameLabel, titleLabel
end

------------------------------------------------------------------------------
-- Updating
------------------------------------------------------------------------------

local function levelOf(owner: Player): number?
	local level = owner:GetAttribute("Level")
	return if typeof(level) == "number" then level else nil
end

local function refreshLevel(tag: Tag)
	local level = levelOf(tag.owner)
	tag.levelLabel.Text = if level then tostring(level) else ""
end

-- The title text, or nil when they have none equipped.
local function titleOf(owner: Player): string?
	local title = owner:GetAttribute("Title")
	return if typeof(title) == "string" and title ~= "" then title else nil
end

local function refreshTitle(tag: Tag)
	local title = titleOf(tag.owner)
	tag.titleLabel.Text = if title then Theme.track(title, "three") else ""
end

-- Which tier the tag is in, from the camera's distance to the head.
local function tierFor(tag: Tag): number
	local camera = workspace.CurrentCamera
	local head: Instance? = tag.gui.Adornee
	if camera == nil or head == nil or not head:IsA("BasePart") then
		return #TIERS
	end
	local distance = (head.Position - camera.CFrame.Position).Magnitude
	for index, tier in TIERS do
		if distance <= tier.distance then
			return index
		end
	end
	return #TIERS
end

-- Tweens the labels to what the tier / hidden state / level ask for.
-- `seconds` = how long the fade takes.
local function applyLook(tag: Tag, seconds: number)
	local tier = TIERS[tag.tier]
	local nameTarget = if tag.hidden then 1 else tier.name
	local showLevel = not tag.hidden and tier.level ~= nil and levelOf(tag.owner) ~= nil
	local levelTarget = if showLevel then tier.level :: number else 1
	-- The title fades like the level (and is gone when far, or when none).
	local showTitle = not tag.hidden and tier.level ~= nil and titleOf(tag.owner) ~= nil
	local titleTarget = if showTitle then tier.level :: number else 1

	if nameTarget ~= tag.nameTarget then
		tag.nameTarget = nameTarget
		Theme.tween(
			tag.nameLabel,
			seconds,
			{ TextTransparency = nameTarget },
			Enum.EasingStyle.Linear
		)
	end
	if titleTarget ~= tag.titleTarget then
		tag.titleTarget = titleTarget
		Theme.tween(
			tag.titleLabel,
			seconds,
			{ TextTransparency = titleTarget },
			Enum.EasingStyle.Linear
		)
	end
	if levelTarget ~= tag.levelTarget then
		tag.levelTarget = levelTarget
		local label = tag.levelLabel
		if showLevel then
			label.Visible = true
		end
		local tween =
			Theme.tween(label, seconds, { TextTransparency = levelTarget }, Enum.EasingStyle.Linear)
		if not showLevel then
			-- Once faded out, take it out of the row so the name is centred
			-- alone (unless it has been asked back in the meantime).
			tween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and tag.levelTarget == 1 then
					label.Visible = false
				end
			end)
		end
	end
end

-- Are `model` and our own character in the same duel? (Same "DuelId".)
local function isDuelOpponent(model: Model): boolean
	local mine = player.Character
	local duelId = if mine then mine:GetAttribute("DuelId") else nil
	return duelId ~= nil and model:GetAttribute("DuelId") == duelId
end

local function shouldHide(tag: Tag): boolean
	if isKnockedOut(player.Character) then
		return true
	end
	if isDuelOpponent(tag.character) then
		return true
	end
	return isKnockedOut(tag.character) and finishPromptOn(tag.character)
end

------------------------------------------------------------------------------
-- Players coming and going
------------------------------------------------------------------------------

local function removeTag(owner: Player)
	local tag = tags[owner]
	if tag == nil then
		return
	end
	tags[owner] = nil
	for _, connection in tag.connections do
		connection:Disconnect()
	end
	tag.gui:Destroy()
end

-- Builds the tag for `character` if it can be built right now: the head
-- is in the world and no tag exists for it yet. Never waits, so it can be
-- called again safely each time something changes (head added, character
-- back in the world after streaming...).
local function tryTag(owner: Player, character: Model)
	if owner.Character ~= character or owner.Parent ~= Players then
		return -- they respawned or left in the meantime
	end
	local existing = tags[owner]
	if existing and existing.character == character then
		return -- already has its tag
	end
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") or not head:IsDescendantOf(workspace) then
		return -- no head yet: the watchers call us again when it arrives
	end
	removeTag(owner)

	local gui, levelLabel, nameLabel, titleLabel = buildGui(owner, head)
	local tag: Tag = {
		owner = owner,
		character = character,
		gui = gui,
		levelLabel = levelLabel,
		nameLabel = nameLabel,
		titleLabel = titleLabel,
		tier = 1,
		hidden = false,
		nameTarget = 1, -- built invisible: the first applyLook fades it in
		levelTarget = 1,
		titleTarget = 1,
		connections = {},
	}
	tags[owner] = tag
	tag.tier = tierFor(tag)
	tag.hidden = shouldHide(tag)
	refreshLevel(tag)
	refreshTitle(tag)
	table.insert(
		tag.connections,
		owner:GetAttributeChangedSignal("Title"):Connect(function()
			if titleOf(owner) ~= nil then
				refreshTitle(tag) -- new text first, then it fades in
			end
			applyLook(tag, TIER_TWEEN)
			if titleOf(owner) == nil then
				-- Taken off: fade the old text out, then clear it.
				task.delay(TIER_TWEEN, function()
					if titleOf(owner) == nil then
						refreshTitle(tag)
					end
				end)
			end
		end)
	)
	table.insert(
		tag.connections,
		owner:GetAttributeChangedSignal("Level"):Connect(function()
			refreshLevel(tag)
			applyLook(tag, TIER_TWEEN)
		end)
	)
	table.insert(
		tag.connections,
		owner:GetPropertyChangedSignal("DisplayName"):Connect(function()
			nameLabel.Text = owner.DisplayName
		end)
	)
	-- Head removed (character falling apart, streamed out): drop the tag.
	-- The character watchers rebuild it if the head comes back.
	table.insert(
		tag.connections,
		head.AncestryChanged:Connect(function()
			if not head:IsDescendantOf(workspace) and tags[owner] == tag then
				removeTag(owner)
			end
		end)
	)
	applyLook(tag, TIER_TWEEN)
end

-- Stops watching a player's (old) character.
local function unwatch(owner: Player)
	local list = watchers[owner]
	if list == nil then
		return
	end
	watchers[owner] = nil
	for _, connection in list do
		connection:Disconnect()
	end
end

local function onCharacterAdded(owner: Player, character: Model)
	removeTag(owner)
	unwatch(owner)
	hideDefaultName(character)
	watchers[owner] = {
		character.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				-- The Humanoid may arrive a moment after the model.
				child.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			elseif child.Name == "Head" then
				tryTag(owner, character)
			end
		end),
		-- Back in the world (e.g. streamed in again): tag it again.
		character.AncestryChanged:Connect(function()
			tryTag(owner, character)
		end),
	}
	tryTag(owner, character)
end

local function onPlayerRemoving(owner: Player)
	removeTag(owner)
	unwatch(owner)
end

local function onPlayerAdded(owner: Player)
	-- Our own character: no tag, but still no Roblox name.
	if owner == player then
		owner.CharacterAdded:Connect(hideDefaultName)
		if owner.Character then
			hideDefaultName(owner.Character)
		end
		return
	end
	owner.CharacterAdded:Connect(function(character)
		onCharacterAdded(owner, character)
	end)
	owner.CharacterRemoving:Connect(function(character)
		local tag = tags[owner]
		if tag and tag.character == character then
			removeTag(owner)
		end
		if owner.Character == character or owner.Character == nil then
			unwatch(owner)
		end
	end)
	if owner.Character then
		onCharacterAdded(owner, owner.Character)
	end
end

-- Every frame: the "hidden" check (cheap, tweens only when it changes);
-- every TIER_CHECK seconds: the distance tiers.
local function update(deltaTime: number)
	sinceTierCheck += deltaTime
	local checkTiers = sinceTierCheck >= TIER_CHECK
	if checkTiers then
		sinceTierCheck = 0
	end
	for _, tag in tags do
		local hide = shouldHide(tag)
		if hide ~= tag.hidden then
			tag.hidden = hide
			applyLook(tag, HIDE_TWEEN)
		end
		if checkTiers then
			local tier = tierFor(tag)
			if tier ~= tag.tier then
				tag.tier = tier
				applyLook(tag, TIER_TWEEN)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function NameTagController.start()
	playerGui = player:WaitForChild("PlayerGui")
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, owner in Players:GetPlayers() do
		onPlayerAdded(owner)
	end
	-- Training dummies and other fighters: no Roblox name either.
	CollectionService:GetInstanceAddedSignal(Config.Combat.TAG):Connect(function(instance)
		if instance:IsA("Model") then
			hideDefaultName(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged(Config.Combat.TAG) do
		if instance:IsA("Model") then
			hideDefaultName(instance)
		end
	end
	RunService.Heartbeat:Connect(update)
end

return NameTagController
