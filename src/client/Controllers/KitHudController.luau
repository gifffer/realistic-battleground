--!strict
-- KitHudController: your kit, bottom-right (display only). The mirror of
-- the health block (bottom-left): same margins, same width, and the Street
-- Fury line sits on the same horizon as the health line.
--
--   [1] BOTTLE SMASH
--   [2] HEADBUTT                 3.4     ← on cooldown: dimmed, seconds left,
--   ────────────────                       a hairline fills up until ready
--   [3] TACKLE
--   [4] DIRTY KICK       LOW STAMINA
--
--   STREET FURY                  64 %
--   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   the Awakening gauge
--
-- • A bright key = usable. No colours per move: brightness only.
-- • Gauge full: "[G] AWAKEN" appears. While awakened (Street Fury): the
--   gauge turns blood red and counts down, the four names swap to their
--   fury versions, a red rail marks them, and the screen loses a bit of
--   colour with warm dark edges (nothing flashy, nothing in the centre).
-- • Hidden while knocked out or while the menu is open. Fades back when
--   nothing happens for a while (like the health block).
--
-- Everything is read from attributes the server sets on our character
-- ("Kit", "CD_<moveId>", "Fury", "Awakened", "AwakenedUntil") and from
-- the kit's data (Shared/Kits). Design: docs/ui (editorial / film).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Theme = require(script.Parent.Parent.UI.Theme)
local KitController = require(script.Parent.KitController)
local MenuController = require(script.Parent.MenuController)

local player = Players.LocalPlayer
local C = Theme.Colors
local KC = Config.Kits

local SLOT_HEIGHT = 26
local DIM = 0.38 -- text transparency of a slot that can't be used
local UPDATE_EVERY = 0.1 -- seconds between two refreshes of the numbers
local IDLE_FADE_AFTER = 4
local IDLE_TRANSPARENCY = 0.5
-- Street Fury screen: the last seconds fade back to normal.
local FURY_FADE_OUT = 2

type SlotState = "Ready" | "Cooldown" | "LowStamina"

type Slot = {
	index: number,
	button: TextButton,
	keyCap: Frame,
	keyStroke: UIStroke,
	keyText: TextLabel,
	name: TextLabel,
	state: TextLabel,
	cdTrack: Frame,
	cdFill: Frame,
	moveId: string?, -- move shown right now
	current: SlotState?,
	inverted: boolean, -- awakened + ready: filled key cap
	readyAt: number?, -- last cooldown end seen (to flash a new use)
}

local KitHudController = {}

local gui: ScreenGui
local block: Frame
local slots: { Slot } = {}
local furyLabel: TextLabel
local furyNum: TextLabel
local furyUnit: TextLabel
local furyFill: Frame
local furyGo: Frame
local goStroke: UIStroke
local furyRail: Frame
local goPulse: Tween? = nil

-- Street Fury screen treatment.
local furyGrade: ColorCorrectionEffect
local edgeLeft: Frame
local edgeRight: Frame
local shadeLeft: Frame
local shadeRight: Frame
local beat: Frame

local shownFury = -1
local furyState: "Charging" | "Full" | "Active" | nil = nil
local fadingOut = false -- the last seconds of Street Fury
local lastUpdate = 0
local lastChangeAt = 0
local idle = false

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function character(): Model?
	return player.Character
end

local function currentKit(model: Model?): Kits.KitDef?
	local id = if model then model:GetAttribute("Kit") else nil
	return Kits.get(if typeof(id) == "string" then id else nil)
end

local function isAwakened(model: Model?): boolean
	return model ~= nil and model:GetAttribute("Awakened") == true
end

local function touched()
	lastChangeAt = os.clock()
	if idle then
		idle = false
		for _, child in block:GetChildren() do
			if child:IsA("CanvasGroup") then
				Theme.tween(child, 0.1, { GroupTransparency = 0 })
			end
		end
	end
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function keyCap(parent: Instance, text: string, size: Vector2): (Frame, UIStroke, TextLabel)
	local frame = Theme.make("Frame", {
		Name = "KeyCap",
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.65,
		Parent = parent,
	}) :: Frame
	local stroke = Theme.make("UIStroke", {
		Thickness = 1,
		Color = C.Ink,
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	}) :: UIStroke
	local label = Theme.text({
		Name = "KeyText",
		Size = UDim2.fromScale(1, 1),
		TextYAlignment = Enum.TextYAlignment.Center,
		FontFace = Theme.Fonts.NumberMedium,
		TextSize = 10,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
		Parent = frame,
	}) :: TextLabel
	return frame, stroke, label
end

local function buildSlot(index: number, holder: GuiObject): Slot
	local button = Theme.make("TextButton", {
		Name = `Slot{index}`,
		Position = UDim2.fromOffset(2, 2 + (index - 1) * SLOT_HEIGHT),
		Size = UDim2.new(1, -4, 0, SLOT_HEIGHT),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = holder,
	}) :: TextButton
	local cap, stroke, keyText = keyCap(button, tostring(index), Vector2.new(22, 18))
	cap.Position = UDim2.fromOffset(0, 3)
	local name = Theme.text({
		Name = "Name",
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -124, 0, 24),
		TextSize = 11,
		Text = "",
		Parent = button,
	}) :: TextLabel
	local state = Theme.text({
		Name = "State",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(100, 24),
		FontFace = Theme.Fonts.Number,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = button,
	}) :: TextLabel
	local cdTrack = Theme.make("Frame", {
		Name = "CdTrack",
		Position = UDim2.fromOffset(34, 24),
		Size = UDim2.new(1, -34, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.84,
		Visible = false,
		Parent = button,
	}) :: Frame
	local cdFill = Theme.make("Frame", {
		Name = "CdFill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.3,
		Parent = cdTrack,
	}) :: Frame

	local slot: Slot = {
		index = index,
		button = button,
		keyCap = cap,
		keyStroke = stroke,
		keyText = keyText,
		name = name,
		state = state,
		cdTrack = cdTrack,
		cdFill = cdFill,
		moveId = nil,
		current = nil,
		inverted = false,
		readyAt = nil,
	}

	-- Clicking a slot uses it (only possible while the cursor is free).
	button.Activated:Connect(function()
		KitController.use(index)
	end)
	button.MouseEnter:Connect(function()
		if slot.current == "Ready" then
			Theme.tween(name, 0.1, { TextTransparency = 0 })
			Theme.tween(stroke, 0.1, { Transparency = 0.15 })
		end
	end)
	button.MouseLeave:Connect(function()
		if slot.current == "Ready" and not slot.inverted then
			Theme.tween(stroke, 0.1, { Transparency = 0.4 })
		end
	end)
	return slot
end

local function build()
	gui = Theme.make("ScreenGui", {
		Name = "KitHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Street Fury edges (under everything) and the activation beat.
	-- Each side: a dark shade, with a dark red on top (red alone over a
	-- light floor turns pink). Both fade in and out together.
	local function edge(name: string, right: boolean, color: Color3, inner: number): Frame
		return Theme.make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(if right then 1 else 0, 0),
			Position = UDim2.fromScale(if right then 1 else 0, 0),
			Size = UDim2.fromScale(0.12, 1),
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			ZIndex = 0,
			Parent = gui,
		}, { Theme.gradient(if right then 180 else 0, { { 0, inner }, { 1, 1 } }) }) :: Frame
	end
	shadeLeft = edge("FuryShadeL", false, C.Scrim, 0.72)
	shadeRight = edge("FuryShadeR", true, C.Scrim, 0.72)
	edgeLeft = edge("FuryEdgeL", false, C.BloodDeep, 0.76)
	edgeRight = edge("FuryEdgeR", true, C.BloodDeep, 0.76)
	beat = Theme.make("Frame", {
		Name = "FuryBeat",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.BloodDeep,
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = gui,
	})

	block = Theme.make("Frame", {
		Name = "KitBlock",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -48, 1, -44),
		Size = UDim2.fromOffset(240, 190),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = gui,
	})
	-- One CanvasGroup per half so the idle fade dims everything at once.
	-- (A CanvasGroup cuts what sticks out of it, outlines included: each
	-- group has a 2 px margin all around, so positions inside are +2.)
	local movesGroup = Theme.make("CanvasGroup", {
		Name = "Moves",
		Position = UDim2.fromOffset(-2, -2),
		Size = UDim2.new(1, 4, 0, 4 * SLOT_HEIGHT + 6),
		BackgroundTransparency = 1,
		Parent = block,
	}) :: CanvasGroup
	for index = 1, #KC.MOVE_KEYS do
		table.insert(slots, buildSlot(index, movesGroup))
	end

	local furyGroup = Theme.make("CanvasGroup", {
		Name = "Fury",
		Position = UDim2.fromOffset(-16, 0),
		Size = UDim2.new(1, 18, 1, 0),
		BackgroundTransparency = 1,
		Parent = block,
	}) :: CanvasGroup
	-- (The fury group is 16 px wider on the left, for the rail, and 2 px on
	-- the right for the G key's outline: positions below add 16 to the
	-- spec's x, and right-anchored ones are 2 px further in.)
	furyRail = Theme.make("Frame", {
		Name = "FuryRail",
		Position = UDim2.fromOffset(2, 3),
		Size = UDim2.fromOffset(2, 0),
		BackgroundColor3 = C.BloodHi,
		Visible = false,
		Parent = furyGroup,
	})
	furyLabel = Theme.text({
		Name = "FuryLabel",
		Position = UDim2.fromOffset(16, 133), -- same line as HEALTH
		Size = UDim2.fromOffset(150, 12),
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = Theme.track("STREET FURY", "three"),
		Parent = furyGroup,
	})
	furyNum = Theme.text({
		Name = "FuryNum",
		AnchorPoint = Vector2.new(1, 0),
		-- (y 122, not 124: the bigger number keeps its baseline on the "%".)
		Position = UDim2.new(1, -15, 0, 122),
		Size = UDim2.fromOffset(80, 28),
		FontFace = Theme.Fonts.NumberLight,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "0",
		Parent = furyGroup,
	})
	furyUnit = Theme.text({
		Name = "FuryUnit",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 135),
		Size = UDim2.fromOffset(10, 12),
		FontFace = Theme.Fonts.Number,
		TextSize = 10,
		TextColor3 = C.Ink2,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "%",
		Parent = furyGroup,
	})
	local track = Theme.make("Frame", {
		Name = "FuryTrack",
		Position = UDim2.fromOffset(16, 158),
		Size = UDim2.new(1, -18, 0, 2),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.78,
		Parent = furyGroup,
	})
	furyFill = Theme.make("Frame", {
		Name = "FuryFill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Ink,
		Parent = track,
	})
	furyGo = Theme.make("Frame", {
		Name = "FuryGo",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 130),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = furyGroup,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 9),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local goKey, stroke = keyCap(furyGo, "G", Vector2.new(22, 18))
	goKey.LayoutOrder = 1
	stroke.Transparency = 0.1
	goStroke = stroke
	Theme.text({
		Name = "GoWord",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 13,
		Text = Theme.track("AWAKEN", "three"),
		Parent = furyGo,
	})

	furyGrade = Theme.make("ColorCorrectionEffect", {
		Name = "FuryCC",
		Enabled = false,
		TintColor = Color3.fromHex("#F6EEEC"),
		Parent = Lighting,
	})
end

------------------------------------------------------------------------------
-- Move slots
------------------------------------------------------------------------------

-- Seconds left on `moveId`'s cooldown, and its full length.
local function cooldownOf(model: Model, move: Kits.MoveDef): (number, number?)
	local readyAt = model:GetAttribute(`CD_{move.id}`)
	if typeof(readyAt) ~= "number" then
		return 0, nil
	end
	return math.max(0, readyAt - workspace:GetServerTimeNow()), readyAt
end

-- Applies the look of `state` (see the table in the header).
local function styleSlot(slot: Slot, state: SlotState, animate: boolean)
	local ready = state == "Ready"
	-- (Keycaps are never inverted: in Street Fury only the names change.)
	local inverted = false
	local time = if animate then 0.12 else 0
	local textT = if ready then 0 else DIM
	if slot.current ~= state or slot.inverted ~= inverted then
		if slot.current ~= nil and slot.current ~= "Ready" and ready and animate then
			-- Becomes ready: one quiet blink of the key's outline.
			slot.keyStroke.Transparency = 0
			task.delay(0.08, function()
				-- (Read again: it may have changed during the delay.)
				local now: SlotState? = slot.current
				if now == "Ready" and not slot.inverted then
					Theme.tween(
						slot.keyStroke,
						0.3,
						{ Transparency = 0.4 },
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.In
					)
				end
			end)
		elseif not inverted then
			Theme.tween(slot.keyStroke, time, { Transparency = if ready then 0.4 else 0.78 })
		end
		Theme.tween(slot.keyCap, time, {
			BackgroundColor3 = if inverted then C.Ink else C.Scrim,
			BackgroundTransparency = if inverted then 0 elseif ready then 0.65 else 0.8,
		})
		if inverted then
			slot.keyStroke.Transparency = 1
		end
		Theme.tween(slot.keyText, time, {
			TextColor3 = if inverted then C.Scrim else C.Ink,
			TextTransparency = textT,
		})
		Theme.tween(slot.name, time, { TextTransparency = textT })
		if state == "Cooldown" then
			slot.cdTrack.Visible = true
			slot.cdTrack.BackgroundTransparency = 0.84
		elseif slot.cdTrack.Visible then
			Theme.tween(slot.cdTrack, 0.15, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
			task.delay(0.15, function()
				if slot.current ~= "Cooldown" then
					slot.cdTrack.Visible = false
				end
			end)
		end
		if state == "LowStamina" then
			slot.state.FontFace = Theme.Fonts.Label
			slot.state.TextSize = math.floor(9 * Theme.TEXT_SCALE + 0.5)
			slot.state.TextColor3 = C.Ink2
			slot.state.Text = Theme.track("LOW STAMINA", "three")
		elseif state == "Ready" then
			slot.state.Text = ""
		else
			slot.state.FontFace = Theme.Fonts.Number
			slot.state.TextSize = math.floor(11 * Theme.TEXT_SCALE + 0.5)
			slot.state.TextColor3 = C.Ink
		end
		slot.current = state
		slot.inverted = inverted
		touched()
	end
end

-- The move was just used: the key flashes, the cooldown line starts.
local function flashUse(slot: Slot)
	slot.keyCap.BackgroundColor3 = C.Ink
	slot.keyCap.BackgroundTransparency = 0
	slot.keyText.TextColor3 = C.Scrim
	Theme.tween(slot.keyCap, 0.2, { BackgroundColor3 = C.Scrim, BackgroundTransparency = 0.8 })
	Theme.tween(slot.keyText, 0.2, { TextColor3 = C.Ink })
	touched()
end

-- Swaps the name shown on a slot (awakening on / off): the old one lifts
-- away, the new one settles in.
local function swapName(slot: Slot, text: string, delay: number)
	task.delay(delay, function()
		Theme.tween(
			slot.name,
			0.1,
			{ TextTransparency = 1, Position = UDim2.fromOffset(34, -3) },
			Enum.EasingStyle.Linear
		)
		task.delay(0.1, function()
			slot.name.Text = text
			slot.name.Position = UDim2.fromOffset(34, 4)
			Theme.tween(slot.name, 0.16, {
				TextTransparency = if slot.current == "Ready" then 0 else DIM,
				Position = UDim2.fromOffset(34, 0),
			})
		end)
	end)
end

local function updateSlots(model: Model, kit: Kits.KitDef)
	local awakened = isAwakened(model)
	local staminaValue = player:GetAttribute("Stamina")
	local stamina = if typeof(staminaValue) == "number" then staminaValue else math.huge
	for _, slot in slots do
		local move = Kits.move(kit, slot.index, awakened)
		slot.button.Visible = move ~= nil
		if move == nil then
			continue
		end
		-- Another move on this key (awakening on / off, new kit).
		if slot.moveId ~= move.id then
			local first = slot.moveId == nil
			slot.moveId = move.id
			slot.readyAt = nil
			local text = Theme.track(move.name, "four")
			if first then
				slot.name.Text = text
			else
				swapName(slot, text, 0.03 * (slot.index - 1))
			end
		end
		local left, readyAt = cooldownOf(model, move)
		if readyAt and readyAt ~= slot.readyAt then
			if slot.readyAt ~= nil or left > 0 then
				flashUse(slot)
			end
			slot.readyAt = readyAt
		end
		local state: SlotState = if left > 0
			then "Cooldown"
			elseif stamina < move.stamina then "LowStamina"
			else "Ready"
		styleSlot(slot, state, true)
		if state == "Cooldown" then
			slot.state.Text = if left < 10
				then string.format("%.1f", left)
				else string.format("%d", math.floor(left))
			slot.cdFill.Size = UDim2.fromScale(1 - left / move.cooldown, 1)
		end
	end
end

-- Pressed while not usable: the state label blinks red, nothing moves.
local function onDenied(index: number)
	local slot = slots[index]
	if slot == nil then
		return
	end
	local normal = if slot.current == "LowStamina" then C.Ink2 else C.Ink
	slot.state.TextColor3 = C.BloodHi
	Theme.tween(slot.state, 0.4, { TextColor3 = normal })
	touched()
end

------------------------------------------------------------------------------
-- Street Fury gauge and screen
------------------------------------------------------------------------------

local function setScreenFury(on: boolean)
	local time = if on then 0.3 else 0.4
	furyGrade.Enabled = true
	Theme.tween(furyGrade, time, {
		Saturation = if on then -0.25 else 0,
		Contrast = if on then 0.06 else 0,
	})
	for _, frame in { edgeLeft, edgeRight, shadeLeft, shadeRight } do
		Theme.tween(frame, time, { BackgroundTransparency = if on then 0 else 1 })
	end
	if on then
		beat.BackgroundTransparency = 0.8
		Theme.tween(beat, 0.5, { BackgroundTransparency = 1 })
	end
end

local function setFuryState(state: "Charging" | "Full" | "Active")
	if furyState == state then
		return
	end
	local previous = furyState
	furyState = state
	touched()
	if goPulse then
		goPulse:Cancel()
		goPulse = nil
	end

	if state == "Full" then
		Theme.tween(furyNum, 0.12, { TextTransparency = 1 }, Enum.EasingStyle.Linear)
		Theme.tween(furyUnit, 0.12, { TextTransparency = 1 }, Enum.EasingStyle.Linear)
		Theme.tween(furyLabel, 0.2, { TextColor3 = C.Ink })
		furyGo.Visible = true
		furyGo.Position = UDim2.new(1, 6, 0, 130)
		Theme.tween(furyGo, 0.2, { Position = UDim2.new(1, -2, 0, 130) }, Enum.EasingStyle.Quart)
		local pulse = TweenService:Create(
			goStroke,
			TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.5 }
		)
		pulse:Play()
		goPulse = pulse
	elseif state == "Active" then
		furyGo.Visible = false
		furyNum.TextTransparency = 0
		furyUnit.TextTransparency = 0
		furyUnit.Text = "s"
		furyLabel.TextColor3 = C.Ink
		furyFill.BackgroundColor3 = C.BloodHi
		furyFill.Size = UDim2.fromScale(1, 1)
		furyRail.Visible = true
		furyRail.Size = UDim2.fromOffset(2, 0)
		Theme.tween(furyRail, 0.2, { Size = UDim2.fromOffset(2, 96) }, Enum.EasingStyle.Quart)
		fadingOut = false
		setScreenFury(true)
	else -- Charging
		furyGo.Visible = false
		furyNum.TextTransparency = 0
		furyUnit.TextTransparency = 0
		furyUnit.Text = "%"
		Theme.tween(furyLabel, 0.2, { TextColor3 = C.Ink2 })
		fadingOut = false
		if previous == "Active" then
			furyFill.BackgroundColor3 = C.Ink
			furyFill.Size = UDim2.fromScale(0, 1)
			Theme.tween(
				furyRail,
				0.15,
				{ Size = UDim2.fromOffset(2, 0) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			task.delay(0.15, function()
				if furyState ~= "Active" then
					furyRail.Visible = false
				end
			end)
			setScreenFury(false)
		end
	end
end

local function updateFury(model: Model, kit: Kits.KitDef)
	local awakening = kit.awakening
	local furyGroup = block:FindFirstChild("Fury")
	if furyGroup and furyGroup:IsA("GuiObject") then
		furyGroup.Visible = awakening ~= nil
	end
	if awakening == nil then
		return
	end
	furyLabel.Text = Theme.track(awakening.name, "three")
	if isAwakened(model) then
		setFuryState("Active")
		local untilTime = model:GetAttribute("AwakenedUntil")
		local left = if typeof(untilTime) == "number"
			then math.max(0, untilTime - workspace:GetServerTimeNow())
			else 0
		furyNum.Text = string.format("%.1f", left)
		furyFill.Size = UDim2.fromScale(left / awakening.duration, 1)
		-- The last seconds: the screen slowly comes back to normal.
		if left <= FURY_FADE_OUT and not fadingOut then
			fadingOut = true
			local info = TweenInfo.new(left, Enum.EasingStyle.Linear)
			TweenService:Create(furyGrade, info, { Saturation = 0, Contrast = 0 }):Play()
			for _, frame in { edgeLeft, edgeRight, shadeLeft, shadeRight } do
				TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
			end
		end
		return
	end
	local value = model:GetAttribute("Fury")
	local fury = if typeof(value) == "number" then value else 0
	if fury >= KC.FURY_MAX then
		setFuryState("Full")
		furyFill.Size = UDim2.fromScale(1, 1)
	else
		setFuryState("Charging")
		if fury ~= shownFury then
			shownFury = fury
			local ratio = fury / KC.FURY_MAX
			local tween = Theme.tween(furyFill, 0.25, { Size = UDim2.fromScale(ratio, 1) })
			tween.Completed:Once(function()
				furyNum.Text = tostring(math.floor(fury))
			end)
			touched()
		end
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function updateVisibility()
	local model = character()
	local down = model ~= nil and model:GetAttribute("KnockedOut") == true
	gui.Enabled = currentKit(model) ~= nil and not down and MenuController.getOpen() == nil
	-- The KO screen wins over Street Fury's (it's neutral the rest of the time).
	furyGrade.Enabled = not down
end

local function updateIdle()
	if idle or os.clock() - lastChangeAt < IDLE_FADE_AFTER or furyState ~= "Charging" then
		return
	end
	for _, slot in slots do
		if slot.current ~= "Ready" then
			return
		end
	end
	idle = true
	for _, child in block:GetChildren() do
		if child:IsA("CanvasGroup") then
			Theme.tween(
				child,
				0.6,
				{ GroupTransparency = IDLE_TRANSPARENCY },
				Enum.EasingStyle.Linear
			)
		end
	end
end

local function update()
	local time = os.clock()
	if time - lastUpdate < UPDATE_EVERY then
		return
	end
	lastUpdate = time
	local model = character()
	updateVisibility()
	local kit = currentKit(model)
	if model == nil or kit == nil then
		return
	end
	updateSlots(model, kit)
	updateFury(model, kit)
	updateIdle()
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function KitHudController.init()
	build()
end

function KitHudController.start()
	KitController.onDenied(onDenied)
	MenuController.onOpenChanged(updateVisibility)
	RunService.Heartbeat:Connect(update)
	player.CharacterAdded:Connect(function()
		-- New life: the gauge and cooldowns start over (server values).
		shownFury = -1
		for _, slot in slots do
			slot.moveId = nil
			slot.readyAt = nil
		end
		furyState = nil
		fadingOut = false
		setScreenFury(false)
		-- Died during Street Fury: put the gauge back to its normal look.
		furyFill.BackgroundColor3 = C.Ink
		furyFill.Size = UDim2.fromScale(0, 1)
		furyRail.Visible = false
		furyRail.Size = UDim2.fromOffset(2, 0)
		furyLabel.TextColor3 = C.Ink2
		furyNum.Text = "0"
		furyNum.TextTransparency = 0
		furyUnit.Text = "%"
		furyUnit.TextTransparency = 0
		furyGo.Visible = false
		if goPulse then
			goPulse:Cancel()
			goPulse = nil
		end
	end)
end

return KitHudController
