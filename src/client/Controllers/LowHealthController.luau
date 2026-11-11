--!strict
-- LowHealthController: what YOU feel when your health is low (step 5).
--
-- Under Config.Injuries.LOW_HEALTH (25 HP):
--   • the edges of the screen darken and close in a little, and breathe
--     with a slow pulse (faster the lower you are);
--   • the picture loses some colour and gets slightly blurry;
--   • a heartbeat and heavy breathing play (Shared/Sounds: Heartbeat,
--     Breathing — silent until they have ids).
-- Everything scales with how low you are, and fades away when you heal.
-- Turned off while knocked out (the KO screen takes over) or dead.
--
-- Display only: the server owns your health. (Your character's tired
-- posture, visible to everyone, is in CharacterAnimationController.)

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)
local SoundController = require(script.Parent.SoundController)

local player = Players.LocalPlayer
local C = Theme.Colors
local LOW = Config.Injuries.LOW_HEALTH

-- At the lowest health (1 HP):
local MAX_EDGE = 0.55 -- darkness of the edges (0 = none, 1 = black)
local MAX_BLUR = 3 -- BlurEffect size
local MAX_DESATURATION = -0.35
-- Pulse: seconds per beat at LOW health and at 1 HP.
local SLOW_BEAT = 1.1
local FAST_BEAT = 0.65
-- How fast the effects follow the health (per second, exponential).
local FOLLOW = 3

local LowHealthController = {}

local gui: ScreenGui
local edges: { Frame } = {}
local blur: BlurEffect
local grade: ColorCorrectionEffect
local heartbeat: Sound? = nil
local breathing: Sound? = nil

local level = 0 -- 0 = fine, 1 = about to drop (smoothed)
local beatPhase = 0

local function build()
	gui = Theme.make("ScreenGui", {
		Name = "LowHealth",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = -1, -- under the HUD
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Four soft dark edges; each gradient goes from the screen edge inward.
	local sides = {
		{
			name = "Left",
			anchor = Vector2.new(0, 0),
			pos = UDim2.fromScale(0, 0),
			size = UDim2.fromScale(0.3, 1),
			rotation = 0,
		},
		{
			name = "Right",
			anchor = Vector2.new(1, 0),
			pos = UDim2.fromScale(1, 0),
			size = UDim2.fromScale(0.3, 1),
			rotation = 180,
		},
		{
			name = "Top",
			anchor = Vector2.new(0, 0),
			pos = UDim2.fromScale(0, 0),
			size = UDim2.fromScale(1, 0.3),
			rotation = 90,
		},
		{
			name = "Bottom",
			anchor = Vector2.new(0, 1),
			pos = UDim2.fromScale(0, 1),
			size = UDim2.fromScale(1, 0.3),
			rotation = -90,
		},
	}
	for _, side in sides do
		local frame = Theme.make("Frame", {
			Name = `Edge{side.name}`,
			AnchorPoint = side.anchor,
			Position = side.pos,
			Size = side.size,
			BackgroundColor3 = C.Scrim,
			BackgroundTransparency = 1,
			Parent = gui,
		}, { Theme.gradient(side.rotation, { { 0, 0 }, { 0.55, 0.7 }, { 1, 1 } }) }) :: Frame
		table.insert(edges, frame)
	end
	blur = Theme.make("BlurEffect", { Name = "LowHealthBlur", Size = 0, Parent = Lighting })
	grade = Theme.make("ColorCorrectionEffect", { Name = "LowHealthGrade", Parent = Lighting })
	heartbeat = SoundController.loop("Heartbeat")
	breathing = SoundController.loop("Breathing")
end

-- 0 → 1: how bad it is right now (0 at LOW health and above, 1 at 1 HP).
local function targetLevel(): number
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return 0
	end
	if character:GetAttribute("KnockedOut") == true then
		return 0 -- the KO screen has its own look
	end
	if humanoid.Health >= LOW then
		return 0
	end
	return math.clamp(1 - (humanoid.Health - 1) / (LOW - 1), 0, 1) * 0.7 + 0.3
end

local function setSound(sound: Sound?, volume: number, baseVolume: number)
	if sound == nil then
		return
	end
	sound.Volume = baseVolume * volume
	if volume > 0.01 and not sound.IsPlaying then
		sound:Play()
	elseif volume <= 0.01 and sound.IsPlaying then
		sound:Stop()
	end
end

local function update(dt: number)
	local target = targetLevel()
	level += (target - level) * math.min(1, dt * FOLLOW)
	if level < 0.005 and target == 0 then
		level = 0
	end

	-- The pulse: a quick swell then a slow release, like a heartbeat.
	local beat = SLOW_BEAT + (FAST_BEAT - SLOW_BEAT) * level
	beatPhase = (beatPhase + dt / beat) % 1
	local pulse = if beatPhase < 0.15 then beatPhase / 0.15 else 1 - (beatPhase - 0.15) / 0.85
	local darkness = level * MAX_EDGE * (0.8 + 0.2 * pulse)

	for _, edge in edges do
		edge.BackgroundTransparency = 1 - darkness
	end
	blur.Size = level * MAX_BLUR
	grade.Saturation = level * MAX_DESATURATION
	setSound(heartbeat, level, 0.6)
	setSound(breathing, level, 0.45)
end

function LowHealthController.init()
	build()
end

function LowHealthController.start()
	RunService.RenderStepped:Connect(update)
end

return LowHealthController
