--!strict
-- KitsMenuController: the KITS section of the menu (01 KITS, above SETTINGS).
--
--   ROSTER              STREET BRAWLER                       EQUIPPED
--   | STREET BRAWLER    Fights dirty and close. Hits hard...
--     EQUIPPED          MOVES                  STAMINA   COOLDOWN
--   BOXER               [1] BOTTLE SMASH            15        8 s
--   NOT AVAILABLE YET       Breaks a bottle...      — BROKEN BOTTLE
--                       ...
--                       AWAKENING                          LASTS
--                     | [G] STREET FURY                     10 s
--
-- Left: every kit (Shared/Kits). Right: the selected kit's moves, read
-- from its data (so the numbers are always the real ones), each with its
-- Street Fury version under the cooldown (the red dash = "fury version").
-- EQUIP asks the server (Remotes.EquipKit); the saved profile says which
-- one is equipped (PlayerDataController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kits = require(ReplicatedStorage.Shared.Kits)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)

local C = Theme.Colors
-- The detail column starts at x 200 of the content. Its canvas starts a bit
-- before (16 px left for the red rail, 8 px up for the kit name), with the
-- content inset by the same amount, so nothing gets cut.
local DETAIL_INSET = Vector2.new(16, 8)
local DETAIL_X = 200 - DETAIL_INSET.X
local DETAIL_Y = -DETAIL_INSET.Y

local KitsMenuController = {}

local selectedId: string = Kits.DEFAULT
local equippedId: string = Kits.DEFAULT

type RosterItem = {
	kit: Kits.KitDef,
	button: TextButton,
	name: TextLabel,
	status: TextLabel,
}

local rosterItems: { RosterItem } = {}
local rosterMarker: Frame
local detail: CanvasGroup -- fades / slides as one when switching kits
local body: Frame -- its content (inset: the canvas cuts what sticks out)
local renderDetail: (animate: boolean) -> ()

------------------------------------------------------------------------------
-- Small pieces
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

local function hairline(parent: Instance, y: UDim, transparency: number)
	Theme.make("Frame", {
		Name = "Hairline",
		Position = UDim2.new(UDim.new(0, 0), y),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = transparency,
		Parent = parent,
	})
end

-- A small outlined (or filled) key: "1", "G".
local function keyCap(parent: Instance, text: string, filled: boolean): Frame
	local frame = Theme.make("Frame", {
		Name = "KeyCap",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(22, 18),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = if filled then 0 else 1,
		Parent = parent,
	}) :: Frame
	if not filled then
		Theme.make("UIStroke", {
			Thickness = 1,
			Color = C.Ink,
			Transparency = 0.45,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = frame,
		})
	end
	Theme.text({
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Fonts.NumberMedium,
		TextSize = 10,
		TextColor3 = if filled then C.Scrim else C.Ink,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
		Parent = frame,
	})
	return frame
end

-- "8 s" right-aligned: the number, then a small unit.
local function seconds(parent: Instance, value: number)
	Theme.text({
		Name = "Seconds",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(40, 13),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = tostring(value),
		Parent = parent,
	})
	Theme.text({
		Name = "Unit",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 8),
		Size = UDim2.fromOffset(8, 11),
		FontFace = Theme.Fonts.Number,
		TextSize = 9,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "s",
		Parent = parent,
	})
end

------------------------------------------------------------------------------
-- Detail (right column)
------------------------------------------------------------------------------

local function moveRow(parent: Instance, index: number, move: Kits.MoveDef, fury: Kits.MoveDef?)
	local row = Theme.make("Frame", {
		Name = `Move{index}`,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	hairline(row, UDim.new(1, -1), 0.93)
	keyCap(row, tostring(index), false)
	Theme.text({
		Name = "Name",
		Position = UDim2.fromOffset(34, 6),
		Size = UDim2.fromOffset(200, 13),
		TextStrokeTransparency = 1,
		Text = Theme.track(move.name, "four"),
		Parent = row,
	})
	Theme.text({
		Name = "Sentence",
		Position = UDim2.fromOffset(34, 22),
		Size = UDim2.fromOffset(230, 14),
		FontFace = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		Text = move.description,
		Parent = row,
	})
	Theme.text({
		Name = "Stamina",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -82, 0, 6),
		Size = UDim2.fromOffset(64, 13),
		FontFace = Theme.Fonts.Number,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = tostring(move.stamina),
		Parent = row,
	})
	seconds(row, move.cooldown)
	if fury then
		-- "— BROKEN BOTTLE": what this key becomes in Street Fury.
		Theme.make("Frame", {
			Name = "FuryVersion",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 24),
			Size = UDim2.fromOffset(0, 11),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Parent = row,
		}, {
			Theme.make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 7),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Theme.make("Frame", {
				Name = "Dash",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(8, 1),
				BackgroundColor3 = C.BloodHi,
			}),
			caption(fury.name, {
				Name = "Label",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 11),
				TextSize = 9,
				TextColor3 = C.Ink2,
				TextTransparency = 0.2,
			}),
		})
	end
	return row
end

-- Two column headers on the right of a section head ("COST", "COOLDOWN").
local function sectionHead(parent: Instance, y: number, title: string, columns: { string })
	local head = Theme.make("Frame", {
		Name = `{title}Head`,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	caption(title, { Size = UDim2.new(1, 0, 0, 12), Parent = head })
	local rightEdge = { 0, -82 }
	local widths = { 82, 64 }
	for position, text in columns do
		caption(text, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, rightEdge[position], 0, 4),
			Size = UDim2.fromOffset(widths[position], 11),
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = head,
		})
	end
	hairline(head, UDim.new(1, 0), 0.9)
end

-- The EQUIP button, or the EQUIPPED mark, at the top right.
local function equipArea(parent: Instance, kit: Kits.KitDef)
	if not kit.available then
		return
	end
	if kit.id == equippedId then
		local mark = Theme.text({
			Name = "Equipped",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 4),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			TextStrokeTransparency = 1,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = Theme.track("EQUIPPED", "four"),
			Parent = parent,
		}) :: TextLabel
		local underline = Theme.make("Frame", {
			Name = "Underline",
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.fromOffset(0, 2),
			BackgroundColor3 = C.Ink,
			Parent = mark,
		})
		task.defer(function()
			Theme.tween(
				underline,
				0.18,
				{ Size = UDim2.fromOffset(math.max(mark.TextBounds.X - 3, 10), 2) },
				Enum.EasingStyle.Quart
			)
		end)
		return
	end
	-- EQUIP: the same "line + word" button as MENU / CLOSE (no boxes).
	local button = Theme.make("TextButton", {
		Name = "EquipButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		Size = UDim2.fromOffset(90, 14),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}) :: TextButton
	local line = Theme.make("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -62, 0.5, 0),
		Size = UDim2.fromOffset(18, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.15,
		Parent = button,
	}) :: Frame
	local word = Theme.text({
		Name = "Label",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 52, 1, 0),
		TextTransparency = 0.15,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = Theme.track("EQUIP", "four"),
		Parent = button,
	}) :: TextLabel
	button.MouseEnter:Connect(function()
		Theme.tween(line, 0.15, { Size = UDim2.fromOffset(28, 1) })
		Theme.tween(word, 0.15, { TextTransparency = 0 })
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(line, 0.15, { Size = UDim2.fromOffset(18, 1) })
		Theme.tween(word, 0.15, { TextTransparency = 0.15 })
	end)
	button.Activated:Connect(function()
		Theme.tween(
			word,
			0.1,
			{ TextTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		Theme.tween(
			line,
			0.1,
			{ Size = UDim2.fromOffset(0, 1) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		Remotes.EquipKit:FireServer(kit.id)
		-- Shown at once; the saved profile confirms it (or puts it back).
		task.delay(0.1, function()
			equippedId = kit.id
			renderDetail(false)
			for _, item in rosterItems do
				item.status.Text = Theme.track(
					if not item.kit.available
						then "NOT AVAILABLE YET"
						elseif item.kit.id == equippedId then "EQUIPPED"
						else "AVAILABLE",
					"three"
				)
			end
		end)
	end)
end

local function fillDetail(kit: Kits.KitDef)
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	Theme.text({
		Name = "KitName",
		Position = UDim2.fromOffset(0, -4),
		Size = UDim2.fromOffset(280, 30),
		FontFace = Theme.Fonts.Display,
		TextSize = 26,
		TextStrokeTransparency = 1,
		Text = Theme.track(kit.name, "thin"),
		Parent = body,
	})
	equipArea(body, kit)
	Theme.text({
		Name = "Desc",
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = Theme.Fonts.Body,
		TextSize = 15,
		TextStrokeTransparency = 1,
		Text = kit.description,
		Parent = body,
	})
	if #kit.moves == 0 then
		caption("THIS FIGHTING STYLE IS NOT AVAILABLE YET", {
			Position = UDim2.fromOffset(0, 84),
			Size = UDim2.new(1, 0, 0, 12),
			Parent = body,
		})
		return
	end

	sectionHead(body, 80, "MOVES", { "COOLDOWN", "STAMINA" })
	local list = Theme.make("Frame", {
		Name = "Moves",
		Position = UDim2.fromOffset(0, 99),
		Size = UDim2.new(1, 0, 0, 4 * 42),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Theme.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local awakening = kit.awakening
	for index, move in kit.moves do
		moveRow(list, index, move, if awakening then awakening.moves[index] else nil)
	end

	if awakening then
		sectionHead(body, 291, "AWAKENING", { "LASTS" })
		local row = Theme.make("Frame", {
			Name = "AwakeningRow",
			Position = UDim2.fromOffset(0, 309),
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundTransparency = 1,
			Parent = body,
		})
		Theme.make("Frame", {
			Name = "Rail",
			Position = UDim2.fromOffset(-14, 6),
			Size = UDim2.fromOffset(2, 18),
			BackgroundColor3 = C.BloodHi,
			Parent = row,
		})
		keyCap(row, "G", false) -- the red rail is what marks it
		Theme.text({
			Name = "Name",
			Position = UDim2.fromOffset(34, 6),
			Size = UDim2.fromOffset(200, 13),
			TextStrokeTransparency = 1,
			Text = Theme.track(awakening.name, "four"),
			Parent = row,
		})
		Theme.text({
			Name = "Sentence",
			Position = UDim2.fromOffset(34, 22),
			Size = UDim2.fromOffset(260, 32),
			FontFace = Theme.Fonts.Body,
			TextSize = 12,
			TextColor3 = C.Ink2,
			TextStrokeTransparency = 1,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LineHeight = 1.33,
			Text = awakening.description,
			Parent = row,
		})
		seconds(row, awakening.duration)
	end
end

-- Shows the selected kit. `animate`: the old content slides out, the new in.
renderDetail = function(animate: boolean)
	local kit = Kits.get(selectedId)
	if kit == nil then
		return
	end
	local selectedKit: Kits.KitDef = kit
	if not animate then
		fillDetail(selectedKit)
		return
	end
	Theme.tween(
		detail,
		0.1,
		{ GroupTransparency = 1, Position = UDim2.fromOffset(DETAIL_X - 6, DETAIL_Y) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(0.1, function()
		fillDetail(selectedKit)
		detail.Position = UDim2.fromOffset(DETAIL_X + 8, DETAIL_Y)
		Theme.tween(
			detail,
			0.2,
			{ GroupTransparency = 0, Position = UDim2.fromOffset(DETAIL_X, DETAIL_Y) },
			Enum.EasingStyle.Quart
		)
	end)
end

------------------------------------------------------------------------------
-- Roster (left column)
------------------------------------------------------------------------------

local function statusText(kit: Kits.KitDef): string
	return if not kit.available
		then "NOT AVAILABLE YET"
		elseif kit.id == equippedId then "EQUIPPED"
		else "AVAILABLE"
end

local function refreshRoster()
	for _, item in rosterItems do
		local selected = item.kit.id == selectedId
		local dimmed = if item.kit.available then 0 else 0.4
		Theme.tween(item.name, Theme.FAST, {
			TextColor3 = if selected then C.Ink else C.Ink3,
			TextTransparency = if selected then 0 else dimmed,
		})
		Theme.tween(item.status, Theme.FAST, {
			TextColor3 = if selected then C.Ink2 else C.Ink3,
			TextTransparency = if selected then 0 else dimmed,
		})
		item.status.Text = Theme.track(statusText(item.kit), "three")
		if selected then
			rosterMarker.Parent = item.button
			rosterMarker.Position = UDim2.fromOffset(-14, 12)
		end
	end
end

local function select(kitId: string)
	if kitId == selectedId then
		return
	end
	selectedId = kitId
	refreshRoster()
	renderDetail(true)
end

local function build(content: Frame)
	local roster = Theme.make("Frame", {
		Name = "Roster",
		Size = UDim2.fromOffset(150, 200),
		BackgroundTransparency = 1,
		Parent = content,
	})
	caption("ROSTER", { Size = UDim2.new(1, 0, 0, 12), Parent = roster })
	local items = Theme.make("Frame", {
		Name = "Items",
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 1, -16),
		BackgroundTransparency = 1,
		Parent = roster,
	}, {
		Theme.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	rosterMarker = Theme.make("Frame", {
		Name = "RosterMarker",
		Size = UDim2.fromOffset(2, 12),
		BackgroundColor3 = C.Ink,
	})
	for order, kit in Kits.list() do
		local button = Theme.make("TextButton", {
			Name = kit.id,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 50),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Parent = items,
		}) :: TextButton
		local name = Theme.text({
			Name = "Name",
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 13,
			TextStrokeTransparency = 1,
			Text = Theme.track(kit.name, "four"),
			Parent = button,
		}) :: TextLabel
		local status = caption(statusText(kit), {
			Name = "Status",
			Position = UDim2.fromOffset(0, 31),
			Size = UDim2.new(1, 0, 0, 11),
			TextSize = 9,
			Parent = button,
		})
		local item: RosterItem = { kit = kit, button = button, name = name, status = status }
		table.insert(rosterItems, item)
		button.MouseEnter:Connect(function()
			if kit.id ~= selectedId then
				Theme.tween(name, 0.1, { TextColor3 = C.Ink2 })
			end
		end)
		button.MouseLeave:Connect(function()
			if kit.id ~= selectedId then
				Theme.tween(name, 0.1, { TextColor3 = C.Ink3 })
			end
		end)
		button.Activated:Connect(function()
			select(kit.id)
		end)
	end

	Theme.make("Frame", {
		Name = "Divider2",
		Position = UDim2.fromOffset(170, 0),
		Size = UDim2.fromOffset(1, 360),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.88,
		Parent = content,
	})
	detail = Theme.make("CanvasGroup", {
		Name = "Detail",
		Position = UDim2.fromOffset(DETAIL_X, DETAIL_Y),
		Size = UDim2.fromOffset(360 + DETAIL_INSET.X + 2, 380 + DETAIL_INSET.Y),
		BackgroundTransparency = 1,
		Parent = content,
	})
	body = Theme.make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(DETAIL_INSET.X, DETAIL_INSET.Y),
		Size = UDim2.fromOffset(360, 380),
		BackgroundTransparency = 1,
		Parent = detail,
	})
	refreshRoster()
	renderDetail(false)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function subtitle(): string
	local available = 0
	for _, kit in Kits.list() do
		if kit.available then
			available += 1
		end
	end
	return `FIGHTING STYLES · {available} OF {#Kits.list()} AVAILABLE`
end

function KitsMenuController.start()
	MenuController.register({
		id = "Kits",
		label = "KITS",
		subtitle = subtitle(),
		order = 10, -- first in the list, above SETTINGS
		size = Vector2.new(560, 480),
		scrimWidth = 1100,
		build = build,
	})
	-- The saved profile says which kit is equipped.
	PlayerDataController.onChanged(function(profile)
		local id = profile.equippedKit
		if typeof(id) == "string" and id ~= equippedId then
			equippedId = id
			if detail then
				refreshRoster()
				renderDetail(false)
			end
		end
	end)
end

return KitsMenuController
