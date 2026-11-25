--!strict
-- ZoneLookController: a LOCAL lighting look chosen by the SERVER for you.
--
-- The server sets the attribute "ZoneLook" on your Player (a string, or nothing). While it
-- names a look of LOOKS below, this controller lays that look over the city's lighting on
-- YOUR screen only, blended in over BLEND_TIME seconds, and takes it off the same way when
-- the attribute is cleared. An unknown name = no look.
--   "Lab"  your private flat with its hidden lab (Server/Systems/Contraband/Apartments sets it
--          when you go in, clears it when you come out or respawn). The server keeps this ONE
--          value for the whole flat; the ROOM look is chosen here on the client:
--          ApartmentController calls setRoomLook("Flat" / "Lab") as you walk from room to room,
--          and the two looks cross-blend over ROOM_BLEND seconds (DESIGN §7).
--
-- It works exactly like ParkAtmosphereController (read its header): every frame while a look
-- is on, it writes the blended values itself; a value different from what it wrote last frame
-- means the SERVER changed it meanwhile (Ambience tweens, the weather), and that new value is
-- remembered as the "server value" the blend starts from. Back at 0, it writes the server
-- values one last time and stops touching anything.
-- (The park is NOT handled here: it keeps its own controller. A lab and the park never
-- overlap, and the park writes after us in the frame anyway.)
--
-- A CUT (the server's ContrabandEvent "DoorCut": a lab door teleport is coming): the screen
-- fades to black (0.15 s, Sine In), stays black until the body has moved (or 0.7 s), then
-- fades back (0.25 s, Sine Out). A look that changes during a cut SNAPS (no 0.6 s blend of
-- the street's fog inside the lab: a blend is for walking across a border, not for a cut).
--
--   ZoneLookController.current()  the SERVER look being shown (or blending out), nil = none
--   ZoneLookController.blend()    0 (city look) → 1 (full zone look), eased
--   ZoneLookController.setRoomLook(look)  the room look to show while the server look is on
--                                 ("Flat" / "Lab"; nil = the server look's default, "Flat")
--   ZoneLookController.shown()    the ROOM look on screen ("Flat" / "Lab"), nil = none

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ZoneLookController = {}

-- Seconds to blend in / out (short: a look changes on a teleport, behind a door).
local BLEND_TIME = 0.6

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function findLighting(): Instance?
	return Lighting
end
local function findAtmosphere(): Instance?
	return Lighting:FindFirstChildOfClass("Atmosphere")
end
local function findGrade(): Instance?
	-- (the server's grade; the weather's own grade is handled by WeatherController)
	return Lighting:FindFirstChild("AmbienceGrade")
end
local function findBloom(): Instance?
	return Lighting:FindFirstChildOfClass("BloomEffect")
end

-- The objects every look touches, in this order (each look below lists one props table per
-- object, in the same order).
local FINDS: { () -> Instance? } = { findLighting, findAtmosphere, findGrade, findBloom }

-- ROOM LOOKS: what each room of the flat looks like (DESIGN §7). Warm, dusty, poor flat
-- ("Flat") and the gloomy cold-teal back room ("Lab"; replaces the old clean, clinical look).
local ROOM_LOOKS: { [string]: { { [string]: any } } } = {
	Flat = {
		{ -- Lighting
			Ambient = rgb(22, 19, 16),
			OutdoorAmbient = rgb(24, 21, 18),
			Brightness = 0.1,
			ExposureCompensation = 0,
			EnvironmentDiffuseScale = 0.15,
			EnvironmentSpecularScale = 0.6,
		},
		{ -- Atmosphere: a warm, dusty haze
			Density = 0.12,
			Offset = 0,
			Haze = 0.6,
			Color = rgb(96, 84, 72),
			Decay = rgb(60, 50, 44),
			Glare = 0,
		},
		{ -- AmbienceGrade
			Brightness = -0.02,
			Contrast = 0.2,
			Saturation = -0.32,
			TintColor = rgb(255, 234, 212),
		},
		{ Intensity = 0.6, Size = 20, Threshold = 1.15 }, -- Bloom
	},
	Lab = {
		{
			Ambient = rgb(20, 26, 26),
			OutdoorAmbient = rgb(22, 28, 28),
			Brightness = 0.1,
			ExposureCompensation = 0,
			EnvironmentDiffuseScale = 0.15,
			EnvironmentSpecularScale = 0.8,
		},
		{ -- a thin cold haze (the vat, the freezer)
			Density = 0.1,
			Offset = 0,
			Haze = 0.4,
			Color = rgb(100, 120, 118),
			Decay = rgb(60, 76, 74),
			Glare = 0,
		},
		{
			Brightness = -0.02,
			Contrast = 0.22,
			Saturation = -0.22,
			TintColor = rgb(226, 246, 240),
		},
		{ Intensity = 0.8, Size = 18, Threshold = 1.0 }, -- (a halo on the vat and the tube)
	},
}

-- SERVER LOOKS: the values the server may put in the "ZoneLook" attribute, and the room look
-- shown when no room was chosen yet. "Lab" = you are in your flat (Apartments sets it).
local SERVER_LOOKS: { [string]: string } = {
	Lab = "Flat",
}

-- Seconds to cross-blend from one room look to the next (walking through a door).
local ROOM_BLEND = 0.7

-- For each object: the server's value of each property, and what we wrote last.
-- (A normal table, NOT weak-keyed: see ParkAtmosphereController's v6 fixes.)
type Memory = { server: { [string]: any }, written: { [string]: any } }
local memory: { [Instance]: Memory } = {}

local player = Players.LocalPlayer
local blendValue = 0
-- The look shown now (kept while blending out, so the old look fades away).
local shownLook: string? = nil
-- True while we are writing (blend > 0, or the one last restoring write).
local active = false

-- The room look: the one asked for (setRoomLook), the one we blend toward, the values we
-- blend FROM (a snapshot taken when the room changed) and how far the cross-blend is (0..1).
local requestedRoom: string? = nil
local roomTo = "Flat"
local roomFrom: { { [string]: any } }? = nil
local roomAlpha = 1

local function lerpValue(from: any, to: any, alpha: number): any
	if typeof(from) == "number" and typeof(to) == "number" then
		return from + (to - from) * alpha
	elseif typeof(from) == "Color3" and typeof(to) == "Color3" then
		return from:Lerp(to, alpha)
	end
	return if alpha >= 0.5 then to else from
end

-- Writes the blended look on one object (`props` = the look's target values).
local function applyLayer(find: () -> Instance?, props: { [string]: any }, alpha: number)
	local instance = find()
	if instance == nil then
		return
	end
	local mem = memory[instance]
	if mem == nil then
		mem = { server = {}, written = {} }
		memory[instance] = mem
	end
	for name, lookValue in props do
		local current = (instance :: any)[name]
		-- Not what we wrote (or never written): the server's value.
		if mem.written[name] == nil or current ~= mem.written[name] then
			mem.server[name] = current
		end
		local value = lerpValue(mem.server[name], lookValue, alpha)
		if current ~= value then
			(instance :: any)[name] = value
		end
		-- (read back: the engine may round what we write)
		mem.written[name] = (instance :: any)[name]
	end
end

-- Stops overriding: puts the server's values back and forgets them.
local function restore()
	for instance, mem in memory do
		for name, value in mem.server do
			if (instance :: any)[name] == mem.written[name] then
				(instance :: any)[name] = value
			end
		end
	end
	table.clear(memory)
end

-- The look the server wants for us now (nil = none, or an unknown name).
local function wantedLook(): string?
	local value = player:GetAttribute("ZoneLook")
	if typeof(value) == "string" and SERVER_LOOKS[value] ~= nil then
		return value
	end
	return nil
end

------------------------------------------------------------------------------
-- Cuts (lab doors): a black fade around the teleport, the look snaps meanwhile
------------------------------------------------------------------------------

local CUT_OUT = 0.15 -- to black
local CUT_IN = 0.25 -- back
local CUT_HOLD_MAX = 0.7 -- the longest it stays black waiting for the teleport
local CUT_MOVED = 20 -- studs: the body has been teleported
local cutting = false -- a cut is on: any look change snaps
local cutToken = 0
local cutTween: Tween? = nil
local cutFrame: Frame? = nil

local function blackFrame(): Frame
	local existing = cutFrame
	if existing and existing.Parent then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "DoorCut"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	cutFrame = frame
	return frame
end

local function fadeTo(
	frame: Frame,
	transparency: number,
	seconds: number,
	direction: Enum.EasingDirection
): Tween
	if cutTween then
		cutTween:Cancel()
	end
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, direction),
		{ BackgroundTransparency = transparency }
	)
	cutTween = tween
	tween:Play()
	return tween
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function startCut()
	cutToken += 1
	local token = cutToken
	cutting = true
	local frame = blackFrame()
	local from = rootPosition()
	fadeTo(frame, 0, CUT_OUT, Enum.EasingDirection.In)
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < CUT_HOLD_MAX do
			task.wait()
			if token ~= cutToken then
				return
			end
			local now = rootPosition()
			if
				from
				and now
				and (now - from).Magnitude > CUT_MOVED
				and os.clock() - started >= CUT_OUT
			then
				break
			end
		end
		task.wait(0.05) -- (a frame or two for the look / streaming to land behind the black)
		if token ~= cutToken then
			return
		end
		local tween = fadeTo(frame, 1, CUT_IN, Enum.EasingDirection.Out)
		tween.Completed:Wait()
		if token == cutToken then
			cutting = false
		end
	end)
end

-- The room look we want now: the requested one, else the server look's default.
local function wantedRoom(): string
	local requested = requestedRoom
	if requested and ROOM_LOOKS[requested] then
		return requested
	end
	local server = wantedLook()
	return if server then SERVER_LOOKS[server] else "Flat"
end

-- The target values for object `index`: the room look, cross-blended from the snapshot.
local function roomTargets(index: number): { [string]: any }
	local to = ROOM_LOOKS[roomTo][index]
	local from = roomFrom
	if from == nil or roomAlpha >= 1 then
		return to
	end
	local eased = math.sin(roomAlpha * math.pi / 2) ^ 2 -- (Sine InOut)
	local mixed = {}
	for name, value in to do
		local start = from[index][name]
		mixed[name] = if start == nil then value else lerpValue(start, value, eased)
	end
	return mixed
end

-- Starts blending toward room look `name` from whatever is shown now.
local function goToRoom(name: string, snap: boolean)
	if name == roomTo and roomFrom == nil then
		return
	end
	if snap then
		roomFrom = nil
		roomAlpha = 1
	else
		local snapshot = {}
		for index in FINDS do
			snapshot[index] = roomTargets(index)
		end
		roomFrom = snapshot
		roomAlpha = 0
	end
	roomTo = name
end

local function update(deltaTime: number)
	local room = wantedRoom()
	if room ~= roomTo then
		-- (not on screen yet, or a cut: snap; else a cross-blend)
		goToRoom(room, cutting or blendValue <= 0)
	end
	local wanted = wantedLook()
	local target = 0
	if wanted ~= nil then
		if shownLook == nil or shownLook == wanted or cutting then
			shownLook = wanted
			target = 1
		end
		-- (another look is still shown: blend it out first, then blend the new one in)
	end
	if cutting and blendValue ~= target then
		-- a cut: no blend across it
		blendValue = target
	elseif blendValue ~= target then
		local step = deltaTime / BLEND_TIME
		blendValue = if target > blendValue
			then math.min(target, blendValue + step)
			else math.max(target, blendValue - step)
	end
	if blendValue <= 0 then
		shownLook = wanted
		if active then
			active = false
			restore()
		end
		return
	end
	if shownLook == nil then
		return
	end
	active = true
	-- the room cross-blend moves on (snaps during a cut)
	if roomAlpha < 1 then
		roomAlpha = if cutting then 1 else math.min(1, roomAlpha + deltaTime / ROOM_BLEND)
	end
	-- smoothstep: eases in and out
	local alpha = blendValue * blendValue * (3 - 2 * blendValue)
	for index, find in FINDS do
		applyLayer(find, roomTargets(index), alpha)
	end
end

-- The look being shown (or blending out); nil = none.
function ZoneLookController.current(): string?
	return if blendValue > 0 then shownLook else nil
end

-- 0 (city look) → 1 (full zone look), eased.
function ZoneLookController.blend(): number
	return blendValue * blendValue * (3 - 2 * blendValue)
end

-- The room look to show while the server look is on ("Flat" / "Lab"; nil = the default).
-- ApartmentController calls it on every room change.
function ZoneLookController.setRoomLook(look: string?)
	requestedRoom = look
end

-- The room look on screen ("Flat" / "Lab"), nil when no zone look is shown.
function ZoneLookController.shown(): string?
	return if blendValue > 0 and shownLook ~= nil then roomTo else nil
end

function ZoneLookController.start()
	-- Just before ParkAtmosphereController (Last): after everything else that touches Lighting.
	RunService:BindToRenderStep("ZoneLook", Enum.RenderPriority.Last.Value - 1, update)
	Remotes.ContrabandEvent.OnClientEvent:Connect(function(kind: string)
		if kind == "DoorCut" then
			startCut()
		end
	end)
end

return ZoneLookController
