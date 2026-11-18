--!strict
-- SpezColaController: everything about the SpezCola machines on THIS screen
-- (the machines and the cans themselves are handled by Server/Systems/SpezCola).
--
--   • SOUNDS: every machine HUMS (a quiet loop, Shared/Sounds "SpezColaHum", in 3D on its
--     "Hum" part, heard only when you're close, like a real fridge); a can dropping out of
--     the tray plays "SpezColaDrop" in 3D where it appears.
--   • THE POCKET (a 1-slot inventory): when the server says we carry a can (our player's
--     "SpezCola" attribute), a small slot shows bottom-right, just above the kit moves:
--
--       POCKET ────────────────────────
--       ▮ SPEZCOLA              [R] DRINK
--
--     Pressing Config.Controls.USE_ITEM (R), or clicking the slot, asks the server to drink
--     it (Remotes.UseItem). When we can't drink right now the key is dimmed and the word
--     says why (NOT IN A DUEL, IN COMBAT, HANDS FULL).
--   • ONE CAN AT MOST: the prompts' text changes on our screen only (a prompt's ActionText
--     set by a client stays on that client): the machine says "YOU HAVE ONE" while we carry
--     one, "TAKE YOUR CAN" while ours still lies on the floor; a can on the floor says
--     "POCKET FULL". Using one anyway: the server refuses, and a short line near the slot
--     says why.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)
local SoundController = require(script.Parent.SoundController)

local SpezColaController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

local MACHINE_TAG = "SpezColaMachine"
local FOLDER_NAME = "SpezColaCans"
local CARRY_ATTRIBUTE = "SpezCola" -- set by the server on our Player
-- The prompts the server makes (Server/Systems/SpezCola), and their normal text.
local MACHINE_PROMPT = "ColaPrompt"
local MACHINE_TEXT = "GET A SPEZCOLA"
local CAN_PROMPT = "PickUpPrompt"
local CAN_TEXT = "PICK UP"
-- The hum: full volume within HUM_NEAR studs, silent beyond HUM_FAR.
local HUM_NEAR = 3
local HUM_FAR = 26
-- The can falling: heard up to this far.
local DROP_RANGE = 45

-- The pocket slot: same right margin and width as the kit block (KitHudController: 240 px
-- wide, 48 px from the right, 44 px from the bottom, 190 px tall), and 18 px above it.
local SLOT_WIDTH = 240
local SLOT_HEIGHT = 44
local KIT_BLOCK_HEIGHT = 190
local GAP_ABOVE_KIT = 18
local DIM = 0.6 -- text transparency of the key and word when we can't drink now
local NOTE_TIME = 2 -- seconds the "why not" line stays
local UPDATE_EVERY = 0.15

local humming: { [Model]: Sound } = {}
local folder: Instance? = nil

-- HUD pieces (built in init)
local gui: ScreenGui
local block: Frame
local slot: CanvasGroup
local keyStroke: UIStroke
local keyText: TextLabel
local word: TextLabel
local note: TextLabel
local carrying = false
local noteToken = 0
local lastUpdate = 0
local shownWord = ""

------------------------------------------------------------------------------
-- Sounds
------------------------------------------------------------------------------

local function startHum(instance: Instance)
	if not instance:IsA("Model") or humming[instance] then
		return
	end
	local model = instance :: Model
	local info = Sounds.SpezColaHum
	if info == nil or #info.ids == 0 then
		return
	end
	local hum = model:WaitForChild("Hum", 15)
	if hum == nil or not hum:IsA("BasePart") or humming[model] then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "SpezColaHum"
	sound.SoundId = `rbxassetid://{info.ids[1]}`
	sound.Volume = info.volume
	sound.PlaybackSpeed = info.pitch
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = HUM_NEAR
	sound.RollOffMaxDistance = HUM_FAR
	-- (each machine starts at a different point of the loop: three machines never hum in sync)
	sound.TimePosition = math.random() * 2
	sound.Parent = hum
	sound:Play()
	humming[model] = sound
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			humming[model] = nil
		end
	end)
end

local function onCanAdded(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	-- (a can taken out of someone's pocket to drink appears in their hand: it doesn't fall)
	if instance:GetAttribute("FromPocket") == true then
		return
	end
	local body = instance:WaitForChild("Body", 5)
	if body and body:IsA("BasePart") then
		SoundController.playAt("SpezColaDrop", body.Position, DROP_RANGE)
	end
end

------------------------------------------------------------------------------
-- One can at most: the prompts' text on our screen
------------------------------------------------------------------------------

-- Is the last can a machine gave us still lying on the floor? (The server sets "OwnerId"
-- on such a can, and removes the can when someone picks it up.)
local function ourCanIsWaiting(): boolean
	if folder == nil then
		return false
	end
	for _, child in folder:GetChildren() do
		if child:GetAttribute("OwnerId") == player.UserId then
			local body = child:FindFirstChild("Body")
			local prompt = body and body:FindFirstChild(CAN_PROMPT)
			if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
				return true
			end
		end
	end
	return false
end

-- The text one SpezCola prompt should show us right now.
local function textFor(prompt: ProximityPrompt): string?
	if prompt.Name == MACHINE_PROMPT then
		if carrying then
			return "YOU HAVE ONE"
		elseif ourCanIsWaiting() then
			return "TAKE YOUR CAN"
		end
		return MACHINE_TEXT
	elseif prompt.Name == CAN_PROMPT then
		return if carrying then "POCKET FULL" else CAN_TEXT
	end
	return nil
end

local function refreshPrompt(prompt: ProximityPrompt)
	local text = textFor(prompt)
	if text and prompt.ActionText ~= text then
		prompt.ActionText = text
	end
end

-- Every SpezCola prompt in the world (3 machines, a few cans: cheap).
local function refreshAllPrompts()
	for _, machine in CollectionService:GetTagged(MACHINE_TAG) do
		local prompt = machine:FindFirstChild(MACHINE_PROMPT, true)
		if prompt and prompt:IsA("ProximityPrompt") then
			refreshPrompt(prompt)
		end
	end
	if folder then
		for _, can in folder:GetChildren() do
			local prompt = can:FindFirstChild(CAN_PROMPT, true)
			if prompt and prompt:IsA("ProximityPrompt") then
				refreshPrompt(prompt)
			end
		end
	end
end

------------------------------------------------------------------------------
-- The pocket slot (HUD)
------------------------------------------------------------------------------

-- A tiny can drawn with frames (14 x 22 px): silver lid, red body, white band, silver base.
local function buildCanIcon(parent: Instance): Frame
	local icon = Theme.make("Frame", {
		Name = "CanIcon",
		Size = UDim2.fromOffset(14, 22),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	local function piece(name: string, x: number, y: number, w: number, h: number, color: Color3)
		Theme.make("Frame", {
			Name = name,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = color,
			Parent = icon,
		})
	end
	piece("Lid", 2, 0, 10, 2, C.Ink2) -- the narrower top (the neck)
	piece("Body", 0, 2, 14, 18, C.Blood)
	piece("Shine", 3, 4, 1, 12, C.Ink) -- a thin highlight down the side
	piece("Band", 0, 15, 14, 2, C.Ink) -- the white ring
	piece("Base", 1, 20, 12, 2, C.Ink2)
	return icon
end

local function build()
	gui = Theme.make("ScreenGui", {
		Name = "PocketHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	block = Theme.make("Frame", {
		Name = "Pocket",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -48, 1, -44),
		Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	-- The "why not" line ("ALREADY CARRYING ONE"...), right-aligned. Outside the slot so it
	-- also shows when the pocket is empty.
	note = Theme.text({
		Name = "Note",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 16),
		Size = UDim2.fromOffset(SLOT_WIDTH, 24),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
		Parent = block,
	}) :: TextLabel

	-- The slot itself. (A CanvasGroup fades everything at once; it cuts what sticks out, so
	-- 2 px of margin all around for the key cap's outline: positions inside are +2.)
	slot = Theme.make("CanvasGroup", {
		Name = "Slot",
		Position = UDim2.fromOffset(-2, -2),
		Size = UDim2.new(1, 4, 1, 4),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = block,
	}) :: CanvasGroup

	-- "POCKET ──────": the line + word header.
	local header = Theme.text({
		Name = "Header",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(0, 12),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = Theme.track("POCKET", "three"),
		Parent = slot,
	}) :: TextLabel
	local hairline = Theme.make("Frame", {
		Name = "Hairline",
		Position = UDim2.fromOffset(52, 8),
		Size = UDim2.new(1, -56, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.84,
		Parent = slot,
	}) :: Frame
	-- (the line starts just after the word, whatever its real width)
	header:GetPropertyChangedSignal("TextBounds"):Connect(function()
		local x = 2 + header.TextBounds.X + 8
		hairline.Position = UDim2.fromOffset(x, 8)
		hairline.Size = UDim2.new(1, -(x + 2), 0, 1)
	end)

	-- The item row: a button, so clicking it (cursor freed) drinks too.
	local row = Theme.make("TextButton", {
		Name = "Item",
		Position = UDim2.fromOffset(2, 20),
		Size = UDim2.new(1, -4, 0, 24),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = slot,
	}) :: TextButton
	local icon = buildCanIcon(row)
	icon.Position = UDim2.fromOffset(4, 1)
	Theme.text({
		Name = "Name",
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -130, 0, 24),
		TextSize = 11,
		Text = Theme.track("SPEZCOLA", "three"),
		Parent = row,
	})

	-- "[R] DRINK", right-aligned (the same key cap as the kit moves).
	local action = Theme.make("Frame", {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 3),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = row,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 9),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local cap = Theme.make("Frame", {
		Name = "KeyCap",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(22, 18),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.65,
		Parent = action,
	}) :: Frame
	keyStroke = Theme.make("UIStroke", {
		Thickness = 1,
		Color = C.Ink,
		Transparency = 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = cap,
	}) :: UIStroke
	keyText = Theme.text({
		Name = "KeyText",
		Position = UDim2.fromOffset(-1, 0), -- (like the kit caps: 1 px left looks centred)
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Fonts.NumberMedium,
		TextSize = 10,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = string.upper(Config.Controls.USE_ITEM.Name),
		Parent = cap,
	}) :: TextLabel
	word = Theme.text({
		Name = "Word",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 12,
		Text = Theme.track("DRINK", "three"),
		Parent = action,
	}) :: TextLabel

	row.Activated:Connect(function()
		SpezColaController.drink()
	end)
end

-- Why we can't drink right now ("" = we can). Only a hint: the server decides.
local function blockedReason(): string
	local model = player.Character
	if model == nil then
		return "LATER"
	end
	if player:GetAttribute("InDuel") == true or model:GetAttribute("DuelId") ~= nil then
		return "NOT IN A DUEL"
	end
	if model:GetAttribute("Weapon") ~= nil then
		return "HANDS FULL"
	end
	local combatUntil = player:GetAttribute("CombatUntil")
	if typeof(combatUntil) == "number" and combatUntil > workspace:GetServerTimeNow() then
		return "IN COMBAT"
	end
	return ""
end

-- A short line near the slot, gone after NOTE_TIME seconds.
local function showNote(text: string)
	noteToken += 1
	local token = noteToken
	-- (above the slot when it shows, in its place when the pocket is empty)
	note.Position = UDim2.new(1, 0, 0, if carrying then -22 else 16)
	note.Text = Theme.track(text, "three")
	note.TextTransparency = 0
	note.TextStrokeTransparency = Theme.STROKE_TRANSPARENCY
	task.delay(NOTE_TIME, function()
		if noteToken == token then
			Theme.tween(note, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

local function setCarrying(value: boolean)
	if value == carrying then
		return
	end
	carrying = value
	if value then
		shownWord = "" -- (the next update writes the word again)
		slot.Visible = true
		Theme.tween(slot, Theme.NORMAL, { GroupTransparency = 0 })
		-- the key lights up once, to say "it's usable now"
		keyStroke.Transparency = 0
		Theme.tween(keyStroke, 0.6, { Transparency = 0.25 })
	else
		local tween = Theme.tween(slot, Theme.FAST, { GroupTransparency = 1 })
		tween.Completed:Once(function()
			if not carrying then
				slot.Visible = false
			end
		end)
	end
	refreshAllPrompts()
end

local function update()
	local time = os.clock()
	if time - lastUpdate < UPDATE_EVERY then
		return
	end
	lastUpdate = time
	local model = player.Character
	local down = model ~= nil and model:GetAttribute("KnockedOut") == true
	gui.Enabled = not down and MenuController.getOpen() == nil
	-- Above the kit moves when they show (you have a kit), else in their place.
	local kitId = if model then model:GetAttribute("Kit") else nil
	local hasKit = Kits.get(if typeof(kitId) == "string" then kitId else nil) ~= nil
	local bottom = if hasKit then 44 + KIT_BLOCK_HEIGHT + GAP_ABOVE_KIT else 44
	block.Position = UDim2.new(1, -48, 1, -bottom)
	if not carrying then
		return
	end
	local reason = blockedReason()
	local text = if reason == "" then "DRINK" else reason
	if text ~= shownWord then
		shownWord = text
		word.Text = Theme.track(text, "three")
		local alpha = if reason == "" then 0 else DIM
		word.TextTransparency = alpha
		keyText.TextTransparency = alpha
		keyStroke.Transparency = if reason == "" then 0.25 else 0.7
	end
end

------------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------------

-- Drink the can in the pocket (the key or a click on the slot).
function SpezColaController.drink()
	-- (a menu is open: the slot is hidden, the key does nothing)
	if not carrying or MenuController.getOpen() ~= nil then
		return
	end
	local reason = blockedReason()
	if reason ~= "" then
		showNote(reason)
		return
	end
	Remotes.UseItem:FireServer()
end

function SpezColaController.init()
	build()
end

function SpezColaController.start()
	CollectionService:GetInstanceAddedSignal(MACHINE_TAG):Connect(function(instance)
		task.spawn(startHum, instance)
	end)
	for _, instance in CollectionService:GetTagged(MACHINE_TAG) do
		task.spawn(startHum, instance)
	end

	-- The pocket.
	setCarrying(player:GetAttribute(CARRY_ATTRIBUTE) == true)
	player:GetAttributeChangedSignal(CARRY_ATTRIBUTE):Connect(function()
		setCarrying(player:GetAttribute(CARRY_ATTRIBUTE) == true)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Config.Controls.USE_ITEM then
			SpezColaController.drink()
		end
	end)
	RunService.Heartbeat:Connect(update)

	-- A prompt coming on screen gets our text (a new can, a machine streamed in...).
	ProximityPromptService.PromptShown:Connect(function(prompt)
		refreshPrompt(prompt)
	end)
	-- Used anyway while it can't work: say why (the server refuses it, silently).
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		if prompt.Name == MACHINE_PROMPT then
			if carrying then
				showNote("ALREADY CARRYING ONE")
			elseif ourCanIsWaiting() then
				showNote("YOUR CAN IS ON THE FLOOR")
			end
		elseif prompt.Name == CAN_PROMPT and carrying then
			showNote("ALREADY CARRYING ONE")
		end
	end)

	task.spawn(function()
		folder = workspace:WaitForChild(FOLDER_NAME, 60)
		local cans = folder
		if cans == nil then
			return
		end
		-- (cans already there when we join fell long ago: no sound for them)
		cans.ChildAdded:Connect(function(child)
			task.spawn(onCanAdded, child)
			-- (its prompt arrives with it; "TAKE YOUR CAN" on the machines if it's ours)
			task.defer(refreshAllPrompts)
		end)
		cans.ChildRemoved:Connect(function()
			refreshAllPrompts()
		end)
		refreshAllPrompts()
	end)
end

return SpezColaController
