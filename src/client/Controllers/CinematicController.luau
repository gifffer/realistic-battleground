--!strict
-- CinematicController: the cutscene of a cinematic finisher (Shared/Finishers).
--
-- When the server says a cinematic finisher starts (Remotes.FinisherStarted):
--   • every client plays its effects at the right times: the bat in the
--     hand, the whoosh, the punches, the blood, the crushed skull;
--   • the two fighters' clients also play its CAMERA: black bars top and
--     bottom, a few shots cut together (behind the attacker, from the
--     ground, close on the impact, wide), the camera shaking and pushing in
--     on each blow. The player can't move during it (the server holds both
--     characters); the normal camera comes back at the end.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Finishers = require(ReplicatedStorage.Shared.Finishers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local KitEffects = require(script.Parent.Parent.Combat.KitEffects)
local CameraController = require(script.Parent.CameraController)
local SoundController = require(script.Parent.SoundController)

local player = Players.LocalPlayer

local CinematicController = {}

local BAR_HEIGHT = 0.11 -- of the screen, top and bottom
local BAR_TIME = 0.35

-- Camera shake: a kick that dies out fast (strength in degrees, push-in in
-- field of view).
type Shake = { at: number, strength: number, punch: number }
local SHAKES: { [string]: Shake } = {
	Body = { at = 0, strength = 1.2, punch = 2 },
	Face = { at = 0, strength = 2, punch = 3 },
	Kill = { at = 0, strength = 4.5, punch = 9 },
}

local bars: { top: Frame, bottom: Frame }? = nil
local playing = false

local function makeBars()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Cinematic"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false
	local function bar(name: string, anchorY: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0, anchorY)
		frame.Position = UDim2.fromScale(0, anchorY)
		frame.Size = UDim2.fromScale(1, 0)
		frame.Parent = gui
		return frame
	end
	bars = { top = bar("Top", 0), bottom = bar("Bottom", 1) }
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function showBars(visible: boolean)
	if bars == nil then
		return
	end
	local info = TweenInfo.new(BAR_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local size = UDim2.fromScale(1, if visible then BAR_HEIGHT else 0)
	TweenService:Create(bars.top, info, { Size = size }):Play()
	TweenService:Create(bars.bottom, info, { Size = size }):Play()
end

local function smooth(alpha: number): number
	local a = math.clamp(alpha, 0, 1)
	return a * a * (3 - 2 * a)
end

-- The camera of the cutscene, for the two fighters.
local function playCamera(
	cinematic: Finishers.Cinematic,
	anchor: CFrame,
	victim: Model,
	shakes: { Shake }
)
	local camera = workspace.CurrentCamera
	if camera == nil or playing then
		return
	end
	playing = true
	local oldType = camera.CameraType
	local oldFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	CameraController.holdRotation("cinematic", true)
	showBars(true)
	local start = os.clock()
	local random = Random.new()
	local lastLook: Vector3? = nil

	RunService:BindToRenderStep(
		"FinisherCamera",
		Enum.RenderPriority.Camera.Value + 10,
		function(dt: number)
			local t = os.clock() - start
			if t >= cinematic.duration then
				return
			end
			-- The shot running now, and when the next one starts.
			local shots = cinematic.shots
			local index = 1
			for i, shot in shots do
				if shot.time <= t then
					index = i
				end
			end
			local shot = shots[index]
			local ends = if shots[index + 1] then shots[index + 1].time else cinematic.duration
			local alpha = smooth((t - shot.time) / math.max(ends - shot.time, 1e-3))
			local position = anchor * shot.from:Lerp(shot.to, alpha)
			local look: Vector3
			if shot.look == "victim" then
				local head = victim:FindFirstChild("Head")
				local target = if head and head:IsA("BasePart")
					then head.Position
					else anchor.Position
				-- follow it smoothly (it tumbles)
				lastLook = if lastLook
					then lastLook:Lerp(target, 1 - math.exp(-10 * dt))
					else target
				look = lastLook :: Vector3
			else
				look = anchor * (shot.look :: Vector3)
				lastLook = nil
			end
			-- Shakes and push-ins from the blows, dying out.
			local kick, punch = 0, 0
			for _, shake in shakes do
				local age = t - shake.at
				if age >= 0 and age < 0.6 then
					local fade = math.exp(-age * 7)
					kick += shake.strength * fade
					punch += shake.punch * fade
				end
			end
			local wobble = CFrame.Angles(
				math.rad(random:NextNumber(-kick, kick)),
				math.rad(random:NextNumber(-kick, kick)),
				math.rad(random:NextNumber(-kick, kick) * 0.5)
			)
			camera.CFrame = CFrame.lookAt(position, look) * wobble
			camera.FieldOfView = shot.fov - punch
		end
	)

	task.delay(cinematic.duration, function()
		RunService:UnbindFromRenderStep("FinisherCamera")
		showBars(false)
		camera.FieldOfView = oldFov
		camera.CameraType = if oldType == Enum.CameraType.Scriptable
			then Enum.CameraType.Custom
			else oldType
		CameraController.holdRotation("cinematic", false)
		playing = false
	end)
end

-- The effects of one moment of the timeline (every client).
local function playEvent(
	cinematic: Finishers.Cinematic,
	event: Finishers.Event,
	attacker: Model,
	victim: Model,
	seed: number
)
	local kind = event.kind
	if kind == "Prop" then
		local away = cinematic.duration
		for _, other in cinematic.events do
			if other.kind == "PropAway" then
				away = other.time
			end
		end
		KitEffects.showBat(attacker, away - event.time)
		SoundController.play("BatDraw", attacker)
	elseif kind == "Swing" then
		SoundController.play("HeavySwing", attacker)
	elseif kind == "Body" then
		SoundController.play("BodyShot", victim)
	elseif kind == "Face" then
		SoundController.play("HeavyHit", victim)
		KitEffects.bloodSpray(victim, attacker, "Head")
	elseif kind == "Kill" then
		if cinematic.id == "Bat" then
			SoundController.play("BatCrush", victim)
			KitEffects.crush(victim, attacker, seed)
		else
			SoundController.play("KnockoutPunch", victim)
			KitEffects.bloodSpray(victim, attacker, "Head")
		end
	end
end

local function onStarted(attacker: unknown, victim: unknown, id: unknown, anchor: unknown)
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Model") then
		return
	end
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then
		return
	end
	if typeof(id) ~= "string" or typeof(anchor) ~= "CFrame" then
		return
	end
	local cinematic = Finishers.get(id)
	if cinematic == nil then
		return
	end
	-- (the same random bits on every client: from where it happens)
	local seed = math.floor(anchor.Position.X * 7 + anchor.Position.Z * 13) % 100000

	-- The camera's shakes, at the blows' times.
	local shakes: { Shake } = {}
	for _, event in cinematic.events do
		local shake = SHAKES[event.kind]
		if shake then
			table.insert(
				shakes,
				{ at = event.time, strength = shake.strength, punch = shake.punch }
			)
		end
	end
	local character = player.Character
	if character ~= nil and (character == attacker or character == victim) then
		playCamera(cinematic, anchor, victim, shakes)
	end

	for _, event in cinematic.events do
		task.delay(event.time, function()
			if attacker.Parent and victim.Parent then
				playEvent(cinematic, event, attacker, victim, seed)
			end
		end)
	end
end

function CinematicController.start()
	makeBars()
	Remotes.FinisherStarted.OnClientEvent:Connect(onStarted)
end

return CinematicController
