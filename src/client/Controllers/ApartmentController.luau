--!strict
-- ApartmentController: the client side of YOUR hidden-lab flat ("Flat 4B", built by the server's
-- LabBuilder). Everything here is local and cosmetic (no remote, the server never waits on it):
--
--   • ROOMS: 10 times a second, which room of the flat you stand in (the invisible boxes of the
--     model's "Rooms" folder: Entry, Living, Corridor, Bath, Bed2, Lab). A doorway between two
--     boxes keeps the room you came from. Each change picks the room look on screen:
--     ZoneLookController.setRoomLook("Lab") in the lab, "Flat" everywhere else.
--   • DOORS (the model's "Doors" folder; LabBuilder sets their attributes):
--       Auto    swings open (0.45 s, Quad Out) when you come within TriggerDistance (default
--               4.5 studs) of its doorway, and stays open. The server never blocks these.
--       Prompt  a local "Open" / "Close" prompt (the kitchen fridge).
--       Locked  a local "Try" prompt: the leaf rattles and "Locked." shows for 1.5 s.
--     Doors are turned with PivotTo(ClosedPivot * angle) around their hinge, on this screen only.
--     Leaving the flat puts every door back the way it was built.
--   • SIGNALS for the ambience (sounds, VFX) and the extraction (Shared/Util/Signal, `.connect`):
--       ApartmentController.model()                 my flat once it is streamed in (nil outside)
--       ApartmentController.room()                  "Entry" | "Living" | "Corridor" | "Bath" |
--                                                   "Bed2" | "Lab" | nil
--       ApartmentController.roomChanged : Signal<string?>
--       ApartmentController.arrived     : Signal<Model>  (I entered the flat; during the door cut)
--       ApartmentController.left        : Signal<nil>
--       ApartmentController.doorOpened  : Signal<Model>  (a Door_* started opening)
--       ApartmentController.doorClosed  : Signal<Model>  (only the fridge closes)
--       ApartmentController.doorTried   : Signal<Model>  (a Locked door was tried)
--       ApartmentController.doorAngle(door) -> number    (the door's angle now, degrees)
--
-- "In the flat" = the player attribute InLab is true (Apartments sets it) AND the model
-- Workspace > Labs > Lab_<UserId> is here with its Rooms folder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Theme = require(script.Parent.Parent.UI.Theme)
local ZoneLookController = require(script.Parent.ZoneLookController)

local ApartmentController = {}

ApartmentController.roomChanged = Signal.new() :: Signal.Signal<string?>
ApartmentController.arrived = Signal.new() :: Signal.Signal<Model>
ApartmentController.left = Signal.new() :: Signal.Signal<nil>
ApartmentController.doorOpened = Signal.new() :: Signal.Signal<Model>
ApartmentController.doorClosed = Signal.new() :: Signal.Signal<Model>
ApartmentController.doorTried = Signal.new() :: Signal.Signal<Model>

local CHECK_EVERY = 0.1 -- seconds between room / door checks (10 Hz)
local DOOR_TIME = 0.45 -- seconds for a door to swing
local DEFAULT_TRIGGER = 4.5 -- studs from the doorway for an Auto door
local PROMPT_DISTANCE = 6 -- studs (the fridge, the locked doors)
local NOTICE_TIME = 1.5 -- seconds "Locked." stays
local RATTLE_TIME = 0.3 -- seconds a locked leaf rattles
local RATTLE_DEGREES = 0.7

local player = Players.LocalPlayer

type DoorState = {
	model: Model,
	mode: string,
	closed: CFrame, -- the hinge at angle 0
	rest: number, -- the angle it was built at
	openAngle: number,
	trigger: number,
	doorway: Vector3, -- the middle of the doorway, on the floor
	angle: number, -- shown now
	from: number,
	to: number,
	startedAt: number,
	open: boolean,
	rattleAt: number?, -- os.clock() of the last "Try"
	prompt: ProximityPrompt?,
}

local flat: Model? = nil
local currentRoom: string? = nil
local roomBoxes: { { name: string, cframe: CFrame, half: Vector3 } } = {}
local doors: { [Model]: DoorState } = {}
local stepConnection: RBXScriptConnection? = nil
local noticeLabel: TextLabel? = nil
local noticeToken = 0

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function numberAttribute(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

-- Quad Out: fast start, soft landing (a door pushed open).
local function quadOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function pose(state: DoorState, angle: number)
	state.angle = angle
	state.model:PivotTo(state.closed * CFrame.Angles(0, math.rad(angle), 0))
end

------------------------------------------------------------------------------
-- "Locked." notice (same style as the contraband HUD's toasts)
------------------------------------------------------------------------------

local function showNotice(text: string)
	local label = noticeLabel
	if label == nil or label.Parent == nil then
		local gui = Instance.new("ScreenGui")
		gui.Name = "ApartmentNotice"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 20
		local made = Theme.text({
			Name = "Notice",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.72),
			Size = UDim2.fromOffset(240, 22),
			FontFace = Theme.Fonts.LabelBold,
			TextSize = 15,
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Text = "",
			Parent = gui,
		}) :: TextLabel
		gui.Parent = player:WaitForChild("PlayerGui")
		noticeLabel = made
		label = made
	end
	local shown = label :: TextLabel
	noticeToken += 1
	local token = noticeToken
	shown.Text = text
	Theme.tween(shown, Theme.FAST, {
		TextTransparency = 0,
		TextStrokeTransparency = Theme.STROKE_TRANSPARENCY,
	})
	task.delay(NOTICE_TIME, function()
		if token ~= noticeToken or shown.Parent == nil then
			return
		end
		Theme.tween(
			shown,
			0.4,
			{ TextTransparency = 1, TextStrokeTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
	end)
end

------------------------------------------------------------------------------
-- Doors
------------------------------------------------------------------------------

local function swing(state: DoorState, target: number)
	state.from = state.angle
	state.to = target
	state.startedAt = os.clock()
end

local function openDoor(state: DoorState)
	if state.open then
		return
	end
	state.open = true
	swing(state, state.openAngle)
	ApartmentController.doorOpened.fire(state.model)
end

local function closeDoor(state: DoorState)
	if not state.open then
		return
	end
	state.open = false
	swing(state, state.rest)
	ApartmentController.doorClosed.fire(state.model)
end

local function setUpDoor(model: Model)
	local closed = model:GetAttribute("ClosedPivot")
	local leaf = model.PrimaryPart
	if typeof(closed) ~= "CFrame" or leaf == nil then
		return
	end
	local rest = numberAttribute(model, "RestAngle", 0)
	local state: DoorState = {
		model = model,
		mode = tostring(model:GetAttribute("Mode") or "Locked"),
		closed = closed,
		rest = rest,
		openAngle = numberAttribute(model, "OpenAngle", 0),
		trigger = numberAttribute(model, "TriggerDistance", DEFAULT_TRIGGER),
		-- (the leaf is 4.4 long from the hinge: its middle at angle 0 is the doorway's middle)
		doorway = (closed * CFrame.new(2.2, 0, 0)).Position,
		angle = rest,
		from = rest,
		to = rest,
		startedAt = 0,
		open = false,
		rattleAt = nil,
		prompt = nil,
	}
	pose(state, rest)
	local label = tostring(model:GetAttribute("Label") or "Door")
	if state.mode == "Prompt" then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DoorPrompt"
		prompt.ActionText = "Open"
		prompt.ObjectText = label
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Triggered:Connect(function()
			if state.open then
				closeDoor(state)
				prompt.ActionText = "Open"
			else
				openDoor(state)
				prompt.ActionText = "Close"
			end
		end)
		prompt.Parent = leaf
		state.prompt = prompt
	elseif state.mode == "Locked" then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DoorPrompt"
		prompt.ActionText = "Try"
		prompt.ObjectText = label
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Triggered:Connect(function()
			state.rattleAt = os.clock()
			ApartmentController.doorTried.fire(model)
			showNotice("Locked.")
		end)
		prompt.Parent = leaf
		state.prompt = prompt
	end
	doors[model] = state
end

-- Every frame while in the flat: moves the swinging / rattling doors.
local function stepDoors()
	local now = os.clock()
	for _, state in doors do
		if state.angle ~= state.to then
			local t = math.clamp((now - state.startedAt) / DOOR_TIME, 0, 1)
			pose(state, state.from + (state.to - state.from) * quadOut(t))
		end
		local rattleAt = state.rattleAt
		if rattleAt then
			local t = (now - rattleAt) / RATTLE_TIME
			if t >= 1 then
				state.rattleAt = nil
				pose(state, state.angle)
			else
				-- a few fast small shakes, dying out (the leaf hits its lock)
				local shake = math.sin(t * math.pi * 6) * RATTLE_DEGREES * (1 - t)
				state.model:PivotTo(
					state.closed * CFrame.Angles(0, math.rad(state.angle + shake), 0)
				)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Rooms
------------------------------------------------------------------------------

local function findRoom(position: Vector3): string?
	for _, box in roomBoxes do
		local offset = box.cframe:PointToObjectSpace(position)
		if
			math.abs(offset.X) <= box.half.X
			and math.abs(offset.Y) <= box.half.Y + 2
			and math.abs(offset.Z) <= box.half.Z
		then
			return box.name
		end
	end
	return nil
end

local function setRoom(name: string?)
	if name == currentRoom then
		return
	end
	currentRoom = name
	ZoneLookController.setRoomLook(if name == "Lab" then "Lab" elseif name then "Flat" else nil)
	ApartmentController.roomChanged.fire(name)
end

------------------------------------------------------------------------------
-- Arriving / leaving
------------------------------------------------------------------------------

local function myFlat(): Model?
	local labs = workspace:FindFirstChild("Labs")
	local model = if labs then labs:FindFirstChild(`Lab_{player.UserId}`) else nil
	if model and model:IsA("Model") and model:FindFirstChild("Rooms") then
		return model
	end
	return nil
end

local function arrive(model: Model)
	flat = model
	table.clear(roomBoxes)
	local rooms = model:FindFirstChild("Rooms")
	if rooms then
		for _, box in rooms:GetChildren() do
			if box:IsA("BasePart") then
				table.insert(
					roomBoxes,
					{ name = box.Name, cframe = box.CFrame, half = box.Size / 2 }
				)
			end
		end
	end
	local doorFolder = model:FindFirstChild("Doors")
	if doorFolder then
		for _, child in doorFolder:GetChildren() do
			if child:IsA("Model") then
				setUpDoor(child)
			end
		end
	end
	stepConnection = RunService.RenderStepped:Connect(stepDoors)
	ApartmentController.arrived.fire(model)
end

local function leave()
	if stepConnection then
		stepConnection:Disconnect()
		stepConnection = nil
	end
	for _, state in doors do
		if state.prompt then
			state.prompt:Destroy()
		end
		if state.model.Parent ~= nil then
			pose(state, state.rest)
		end
	end
	table.clear(doors)
	table.clear(roomBoxes)
	flat = nil
	setRoom(nil)
	ApartmentController.left.fire(nil)
end

-- 10 times a second: in or out, which room, which Auto door to open.
local function check()
	local inside = player:GetAttribute("InLab") == true
	local model = if inside then myFlat() else nil
	if flat and (model ~= flat or (flat :: Model).Parent == nil) then
		leave()
	end
	if flat == nil and model then
		arrive(model)
	end
	if flat == nil then
		return
	end
	local position = rootPosition()
	if position == nil then
		return
	end
	local found = findRoom(position)
	if found then
		setRoom(found)
	end
	for _, state in doors do
		if state.mode == "Auto" and not state.open then
			local offset = position - state.doorway
			if Vector2.new(offset.X, offset.Z).Magnitude <= state.trigger then
				openDoor(state)
			end
		end
	end
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------

-- My flat once it is streamed in, nil outside.
function ApartmentController.model(): Model?
	return flat
end

-- The room I stand in ("Entry", "Living", "Corridor", "Bath", "Bed2", "Lab"), nil outside.
function ApartmentController.room(): string?
	return currentRoom
end

-- A door's angle now, in degrees (0 = closed; its RestAngle if it is not tracked).
function ApartmentController.doorAngle(door: Model): number
	local state = doors[door]
	if state then
		return state.angle
	end
	return numberAttribute(door, "RestAngle", 0)
end

function ApartmentController.start()
	task.spawn(function()
		while true do
			local ok: boolean, problem: any = pcall(check)
			if not ok then
				warn(`[ApartmentController] {problem}`)
			end
			task.wait(CHECK_EVERY)
		end
	end)
end

return ApartmentController
