--!strict
-- ZoneLookController: a LOCAL lighting look chosen by the SERVER for you.
--
-- The server sets the attribute "ZoneLook" on your Player (a string, or nothing). While it
-- names a look of LOOKS below, this controller lays that look over the city's lighting on
-- YOUR screen only, blended in over BLEND_TIME seconds, and takes it off the same way when
-- the attribute is cleared. An unknown name = no look.
--   "Lab"  your private contraband lab (Server/Systems/Contraband/Apartments sets it when you
--          go in, clears it when you come out or respawn): clean cold air, see ART_V2 §3.2.
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
--   ZoneLookController.current()  the look being shown (or blending out), nil = none
--   ZoneLookController.blend()    0 (city look) → 1 (full zone look), eased

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

-- One object to change (found by `find`: it can be created late or replaced by the server)
-- and the target value of each property.
type Layer = {
	find: () -> Instance?,
	props: { [string]: any },
}

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

local LOOKS: { [string]: { Layer } } = {
	-- The lab: clean, cold, a little clinical. No smog inside.
	Lab = {
		{
			find = findLighting,
			props = {
				Ambient = rgb(36, 40, 44), -- (lifted: the room's corners stayed black)
				OutdoorAmbient = rgb(40, 44, 48),
				Brightness = 0.4,
				ExposureCompensation = 0.1,
				EnvironmentDiffuseScale = 0.2,
				EnvironmentSpecularScale = 0.8,
			},
		},
		{
			find = findAtmosphere,
			props = {
				Density = 0.08,
				Offset = 0,
				Haze = 0.3,
				Color = rgb(120, 130, 140),
				Decay = rgb(90, 100, 110),
				Glare = 0,
			},
		},
		{
			find = findGrade,
			props = {
				Contrast = 0.12,
				Saturation = -0.1,
				TintColor = rgb(235, 245, 255),
				Brightness = 0,
			},
		},
		{
			find = findBloom,
			props = { Intensity = 0.5, Size = 24, Threshold = 1.2 },
		},
	},
}

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

local function lerpValue(from: any, to: any, alpha: number): any
	if typeof(from) == "number" and typeof(to) == "number" then
		return from + (to - from) * alpha
	elseif typeof(from) == "Color3" and typeof(to) == "Color3" then
		return from:Lerp(to, alpha)
	end
	return if alpha >= 0.5 then to else from
end

-- Writes the blended look on one object.
local function applyLayer(layer: Layer, alpha: number)
	local instance = layer.find()
	if instance == nil then
		return
	end
	local mem = memory[instance]
	if mem == nil then
		mem = { server = {}, written = {} }
		memory[instance] = mem
	end
	for name, lookValue in layer.props do
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
	if typeof(value) == "string" and LOOKS[value] ~= nil then
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

local function update(deltaTime: number)
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
	local layers = if shownLook then LOOKS[shownLook] else nil
	if layers == nil then
		return
	end
	active = true
	-- smoothstep: eases in and out
	local alpha = blendValue * blendValue * (3 - 2 * blendValue)
	for _, layer in layers do
		applyLayer(layer, alpha)
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
