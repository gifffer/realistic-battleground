--!strict
-- CinematicController: the cutscene of a cinematic finisher (Shared/Finishers).
--
-- When the server says a cinematic finisher starts (Remotes.FinisherStarted):
--   • every client plays its effects at the right times: the bat in the
--     hand, the whoosh, the punches, the blood (the head bursting under
--     the bat is HeadBlast's, from the server's "HeadBlown");
--   • the two fighters' clients also play its CAMERA: black bars top and
--     bottom, a few shots cut together (behind the attacker, from the
--     ground, close on the impact, wide), the camera shaking and pushing in
--     on each blow. The player can't move during it (the server holds both
--     characters); the normal camera comes back at the end.
--
-- The server can cut it short before the killing blow (the attacker dies,
-- someone leaves: Remotes.FinisherEnded with killed = false): everything
-- stops at once and the camera comes back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Finishers = require(ReplicatedStorage.Shared.Finishers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config)
local KitEffects = require(script.Parent.Parent.Combat.KitEffects)
local LiverRip = require(script.Parent.Parent.Combat.LiverRip)
local CameraController = require(script.Parent.CameraController)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local CombatController = require(script.Parent.CombatController)
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
	Gut = { at = 0, strength = 4, punch = 8 }, -- the hand into the side
	Dig = { at = 0, strength = 1.2, punch = 1 },
	Rip = { at = 0, strength = 2.5, punch = 4 },
}

local bars: { top: Frame, bottom: Frame }? = nil

-- One cinematic playing (key: its attacker).
type Run = {
	cinematic: Finishers.Cinematic,
	victim: Model,
	cancelled: boolean,
	stopCamera: (() -> ())?, -- ours (we're one of the two fighters)
}
local runs: { [Model]: Run } = {}
-- Which camera is ours now (a new cinematic takes the camera over; the old
-- one's end then does nothing).
local cameraGeneration = 0

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

-- The normal field of view (sprinting or not: like SprintController).
local function normalFov(): number
	return if player:GetAttribute("Sprinting") == true
		then Config.Camera.SPRINT_FOV
		else Config.Camera.DEFAULT_FOV
end

-- In first person our own body is hidden; show it during the cutscene.
local function showOwnBody(character: Model)
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = 0 -- (its decals, the face, follow it)
		end
	end
end

-- The camera of the cutscene, for the two fighters. Returns what stops it
-- (and gives the normal camera back).
local function playCamera(
	cinematic: Finishers.Cinematic,
	anchor: CFrame,
	victim: Model,
	shakes: { Shake }
): (() -> ())?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	cameraGeneration += 1
	local generation = cameraGeneration
	camera.CameraType = Enum.CameraType.Scriptable
	CameraController.holdRotation("cinematic", true)
	showBars(true)
	local start = os.clock()
	local random = Random.new()
	local lastLook: Vector3? = nil

	RunService:UnbindFromRenderStep("FinisherCamera") -- (an older one)
	RunService:BindToRenderStep(
		"FinisherCamera",
		Enum.RenderPriority.Camera.Value + 10,
		function(dt: number)
			local t = os.clock() - start
			if t >= cinematic.duration then
				return
			end
			local character = player.Character
			if character and CameraController.isFirstPerson() then
				showOwnBody(character)
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

	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if cameraGeneration ~= generation then
			return -- (a newer cutscene has the camera)
		end
		RunService:UnbindFromRenderStep("FinisherCamera")
		showBars(false)
		camera.FieldOfView = normalFov()
		camera.CameraType = Enum.CameraType.Custom
		CameraController.holdRotation("cinematic", false)
	end
	task.delay(cinematic.duration, stop)
	return stop
end

-- The effects of one moment of the timeline (every client).
local function playEvent(
	cinematic: Finishers.Cinematic,
	event: Finishers.Event,
	attacker: Model,
	victim: Model
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
	elseif kind == "Plea" then
		SoundController.play("VictimPlea", victim)
	elseif kind == "Swing" then
		SoundController.play(if cinematic.id == "Bat" then "BatSwing" else "HeavySwing", attacker)
	elseif kind == "Body" or kind == "Dig" then
		SoundController.play("BodyShot", victim)
	elseif kind == "Face" then
		SoundController.play("HeavyHit", victim)
		KitEffects.bloodSpray(victim, attacker, "Head")
	elseif kind == "Kill" then
		-- (the burst itself: HeadBlast, from the server's "HeadBlown")
		SoundController.play("BatCrush", victim)
	elseif kind == "Gut" then
		SoundController.play("KnockoutPunch", victim)
		LiverRip.gut(victim, attacker)
	elseif kind == "Rip" then
		LiverRip.rip(victim, attacker)
	elseif kind == "Drop" then
		LiverRip.drop(attacker)
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
	local old = runs[attacker]
	if old then
		old.cancelled = true
	end
	local run: Run = { cinematic = cinematic, victim = victim, cancelled = false }
	runs[attacker] = run
	local character = player.Character
	if character ~= nil and (character == attacker or character == victim) then
		run.stopCamera = playCamera(cinematic, anchor, victim, shakes)
		if character == attacker then
			CombatController.holdAttacks(cinematic.duration)
		end
	end

	for _, event in cinematic.events do
		task.delay(event.time, function()
			-- (throwing the liver down needs only him there)
			local victimThere = victim.Parent ~= nil or event.kind == "Drop"
			if not run.cancelled and attacker.Parent and victimThere then
				playEvent(cinematic, event, attacker, victim)
			end
		end)
	end
	task.delay(cinematic.duration, function()
		if runs[attacker] == run then
			runs[attacker] = nil
		end
	end)
end

-- The server ended a cinematic. Cut short (not killed): stop it all now.
local function onEnded(attacker: unknown, victim: unknown, killed: unknown)
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Model") then
		return
	end
	local run = runs[attacker]
	if run == nil or (run.victim :: unknown) ~= victim then
		return
	end
	runs[attacker] = nil
	if killed == true then
		return -- (played to the end: everything stops on its own)
	end
	run.cancelled = true
	KitEffects.stopAction(attacker) -- the bat
	LiverRip.cancel(attacker)
	for _, clip in { "Brawler_FinisherBat", "Boxer_FinisherCombo" } do
		CharacterAnimationController.stopAction(attacker, clip)
	end
	CharacterAnimationController.stopAction(run.victim, "Boxer_FinisherVictim")
	if run.stopCamera then
		run.stopCamera()
	end
	if attacker == player.Character then
		CombatController.releaseAttacks()
	end
end

function CinematicController.start()
	makeBars()
	Remotes.FinisherStarted.OnClientEvent:Connect(onStarted)
	Remotes.FinisherEnded.OnClientEvent:Connect(onEnded)
end

return CinematicController
