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
--     on each blow; on some (the bat through the head) it holds still a
--     beat, pushed in, the picture hit pale and harsh, then eases back
--     slowly: the blow feels slowed down. The player can't move during it
--     (the server holds both characters); the normal camera comes back at
--     the end.
--
-- The server can cut it short before the killing blow (the attacker dies,
-- someone leaves: Remotes.FinisherEnded with killed = false): everything
-- stops at once and the camera comes back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Finishers = require(ReplicatedStorage.Shared.Finishers)
local Gash = require(ReplicatedStorage.Shared.Util.Gash)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Config = require(ReplicatedStorage.Shared.Config)
local ArmRip = require(script.Parent.Parent.Combat.ArmRip)
local BloodGush = require(script.Parent.Parent.Combat.BloodGush)
local KitEffects = require(script.Parent.Parent.Combat.KitEffects)
local KitVFX = require(script.Parent.Parent.Combat.KitVFX)
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
-- field of view). Optional: `freeze` seconds the camera holds still on it,
-- pushed in (a held frame: the blow feels slowed down), `decay` how fast the
-- push-in dies out (7 by default, as the shake; lower = a slow return,
-- the shot drifting back out), `flash` a colour hit on
-- the screen (the picture goes harsh and pale, then comes back).
type Shake = {
	at: number,
	strength: number,
	punch: number,
	freeze: number?,
	decay: number?,
	flash: boolean?,
}
local DEFAULT_DECAY = 7
local SHAKES: { [string]: Shake } = {
	Body = { at = 0, strength = 1.2, punch = 2 },
	Face = { at = 0, strength = 2, punch = 3 },
	Kill = { at = 0, strength = 4.5, punch = 9 },
	Gut = { at = 0, strength = 4, punch = 8 }, -- the hand into the side
	Dig = { at = 0, strength = 1.2, punch = 1 },
	Rip = { at = 0, strength = 2.5, punch = 4 },
	-- (the Bouncer's arm)
	Grab = { at = 0, strength = 0.8, punch = 1 },
	Stomp = { at = 0, strength = 2, punch = 3 },
	Strain = { at = 0, strength = 1.2, punch = 1.5 },
	Pop = { at = 0, strength = 3, punch = 5 },
	Tear = { at = 0, strength = 4.5, punch = 9 },
	-- (the Sentinel's)
	Beam = { at = 0, strength = 1.5, punch = 3 },
	Burnt = { at = 0, strength = 3, punch = 6 },
}
-- The Sentinel's and the Bull's finishers: all their effects are KitVFX's
-- (by cinematic: other finishers have events with the same names).
local KIT_CINEMATICS = table.freeze({ Incinerate = true, Gore = true })
-- (event names other finishers use too, shaken differently in these;
-- a negative push-in widens the view: the Bull's charge)
local KIT_SHAKES: { [string]: { [string]: Shake } } = {
	-- (the Street Brawler's: the taps, the bat coming down widening the view,
	-- then the held frame on the head bursting, a slow way back)
	Bat = {
		Tap = { at = 0, strength = 0.5, punch = 1.2 },
		Swing = { at = 0, strength = 0.6, punch = -3 },
		Kill = { at = 0, strength = 6, punch = 13, freeze = 0.16, decay = 2.8, flash = true },
	},
	Incinerate = {
		Grab = { at = 0, strength = 1, punch = 1 },
		Beam = { at = 0, strength = 2, punch = 4 }, -- point blank into the chest
		Ribs = { at = 0, strength = 1.2, punch = 1.5 }, -- through the ribs
		Heart = { at = 0, strength = 2.2, punch = 3 }, -- through the heart
		Burnt = { at = 0, strength = 0.8, punch = 1.5 }, -- the beam stops
		Toss = { at = 0, strength = 0.6, punch = 0 },
		Thud = { at = 0, strength = 2, punch = 2.5 }, -- the body hits the floor
	},
	Gore = {
		Scrape = { at = 0, strength = 0.5, punch = 0.5 },
		Rush = { at = 0, strength = 1.2, punch = -5 },
		Impact = { at = 0, strength = 5, punch = 10 }, -- the horns into the ribcage
		Jump = { at = 0, strength = 1.5, punch = 2 },
		Rip = { at = 0, strength = 6, punch = 12 }, -- torn in two
		Land = { at = 0, strength = 4, punch = 6 },
		Huff = { at = 0, strength = 0.6, punch = 0.5 },
	},
}

-- (the colour hit: pale and a little warm, like an overexposed frame)
local FLASH_TINT = Color3.fromRGB(255, 222, 214)

local bars: { top: Frame, bottom: Frame }? = nil

-- One cinematic playing (key: its attacker).
type Run = {
	cinematic: Finishers.Cinematic,
	victim: Model,
	cancelled: boolean,
	started: number, -- os.clock()
	stopCamera: (() -> ())?, -- ours (we're one of the two fighters)
}

-- Every finisher clip (cut short: stopped).
local ATTACKER_CLIPS = {
	"Brawler_FinisherBat",
	"Boxer_FinisherCombo",
	"Bouncer_FinisherArmRip",
	"Sentinel_Finisher",
	"Bull_Finisher",
}
local VICTIM_CLIPS = {
	"Boxer_FinisherVictim",
	"Bouncer_FinisherArmRipVictim",
	"Sentinel_FinisherVictim",
	"Bull_FinisherVictim",
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
	local lastIndex = 0
	local stopped = false
	-- (the colour hits of the blows: one grade on our camera, made on the
	-- first, gone with the cutscene)
	local grade: ColorCorrectionEffect? = nil
	for _, shake in shakes do
		if shake.flash then
			task.delay(shake.at, function()
				if stopped or cameraGeneration ~= generation then
					return
				end
				if grade == nil then
					local made = Instance.new("ColorCorrectionEffect")
					made.Name = "FinisherFlash"
					made.Parent = camera
					grade = made
				end
				local effect = grade :: ColorCorrectionEffect
				effect.Brightness = 0.22
				effect.Contrast = 0.45
				effect.Saturation = -0.6
				effect.TintColor = FLASH_TINT
				TweenService:Create(
					effect,
					TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Brightness = 0,
						Contrast = 0,
						Saturation = 0,
						TintColor = Color3.new(1, 1, 1),
					}
				):Play()
			end)
		end
	end

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
			if index ~= lastIndex then
				lastIndex = index
				lastLook = nil -- (a cut: the new shot frames its target at once)
			end
			-- Shakes and push-ins from the blows, dying out; a blow that holds
			-- the frame stops the shot moving meanwhile (`held`: how long it
			-- has been held in this shot).
			local kick, punch, held = 0, 0, 0
			for _, shake in shakes do
				local age = t - shake.at
				if age >= 0 then
					local freeze = shake.freeze or 0
					local decay = shake.decay or DEFAULT_DECAY
					local inShot = shake.at >= shot.time
					if age < freeze then
						punch += shake.punch -- (still, pushed in)
						if inShot then
							held += age
						end
					else
						local after = age - freeze
						if inShot then
							held += freeze
						end
						-- (the shake always dies out fast; the push-in at its pace)
						if after < 0.6 then
							kick += shake.strength * math.exp(-after * DEFAULT_DECAY)
						end
						if after < 4.2 / decay then
							punch += shake.punch * math.exp(-after * decay)
						end
					end
				end
			end
			local ends = if shots[index + 1] then shots[index + 1].time else cinematic.duration
			local alpha = smooth((t - held - shot.time) / math.max(ends - shot.time, 1e-3))
			local position = anchor * shot.from:Lerp(shot.to, alpha)
			local look: Vector3
			if shot.look == "victim" or shot.look == "heart" then
				local target = anchor.Position
				if shot.look == "heart" then
					-- (the Sentinel's bore, on the front of the chest)
					local torso = victim:FindFirstChild("Torso")
					if torso and torso:IsA("BasePart") then
						target = torso.CFrame * Gash.HEART
					end
				else
					local head = victim:FindFirstChild("Head")
					if head and head:IsA("BasePart") then
						target = head.Position
					end
				end
				-- follow it smoothly (it tumbles)
				lastLook = if lastLook
					then lastLook:Lerp(target, 1 - math.exp(-10 * dt))
					else target
				look = lastLook :: Vector3
			else
				look = anchor * (shot.look :: Vector3)
				lastLook = nil
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

	local function stop()
		if stopped then
			return
		end
		stopped = true
		if grade then
			grade:Destroy()
			grade = nil
		end
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
	victim: Model,
	anchor: CFrame
)
	local kind = event.kind
	if KIT_CINEMATICS[cinematic.id] then
		KitVFX.finisherEvent(kind, attacker, victim, anchor)
		return
	end
	if kind == "Prop" then
		local away = cinematic.duration
		for _, other in cinematic.events do
			if other.kind == "PropAway" then
				away = other.time
			end
		end
		-- (the bat turns in his fist with his clip's "Grip": the wrists
		-- cocking and releasing through the swing)
		local clip = CharacterAnimationController.getLastAction(attacker)
		KitEffects.showBat(attacker, away - event.time, function(): CFrame?
			return if clip
				then CharacterAnimationController.getActionPose(attacker, clip, "Grip")
				else nil
		end)
		SoundController.play("BatDraw", attacker)
	elseif kind == "Plea" then
		SoundController.play("VictimPlea", victim)
	elseif kind == "Tap" then
		SoundController.play("BatTap", victim)
	elseif kind == "Taunt" then
		SoundController.play("BrawlerTaunt", attacker)
	elseif kind == "Swing" then
		SoundController.play(if cinematic.id == "Bat" then "BatSwing" else "HeavySwing", attacker)
	elseif kind == "Body" or kind == "Dig" or kind == "Stomp" then
		SoundController.play("BodyShot", victim)
	elseif kind == "Face" then
		SoundController.play("HeavyHit", victim)
		KitEffects.bloodSpray(victim, attacker, "Head", 3)
	elseif kind == "Kill" then
		-- (the burst itself: HeadBlast, from the server's "HeadBlown")
		SoundController.play("BatCrush", victim)
		SoundController.play("BatImpact", victim)
		-- it goes all over him, his face too, and the bat comes out red
		local head = victim:FindFirstChild("Head")
		local from = if head and head:IsA("BasePart")
			then head.Position
			else victim:GetPivot().Position
		BloodGush.splatter(attacker, from, 26, math.floor(event.time * 1000))
		KitEffects.bloodyBat(attacker)
	elseif kind == "Gut" then
		SoundController.play("KnockoutPunch", victim)
		LiverRip.gut(victim, attacker)
	elseif kind == "Rip" then
		LiverRip.rip(victim, attacker)
	elseif kind == "Drop" then
		LiverRip.drop(attacker)
	elseif kind == "Grab" then
		SoundController.play("Grab", victim)
	elseif kind == "Strain" then
		SoundController.play("Strain", attacker)
	elseif kind == "Pop" then
		ArmRip.pop(victim)
	elseif kind == "Tear" then
		-- (the arm off itself: ArmRip, from the server's "ArmTorn"): the first
		-- jet hits him full on
		local torso = victim:FindFirstChild("Torso")
		local from = if torso and torso:IsA("BasePart")
			then torso.Position
			else victim:GetPivot().Position
		BloodGush.splatter(attacker, from, 22, math.floor(event.time * 1000))
	elseif kind == "Throw" then
		-- (the arm off itself: ArmRip, from the server's "ArmTorn")
		ArmRip.thrown(attacker, anchor)
	end
end

local function onStarted(
	attacker: unknown,
	victim: unknown,
	id: unknown,
	anchor: unknown,
	short: unknown
)
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
		local overrides = KIT_SHAKES[cinematic.id]
		local shake = (overrides and overrides[event.kind]) or SHAKES[event.kind]
		if shake then
			table.insert(shakes, {
				at = event.time,
				strength = shake.strength,
				punch = shake.punch,
				freeze = shake.freeze,
				decay = shake.decay,
				flash = shake.flash,
			})
		end
	end
	local old = runs[attacker]
	if old then
		old.cancelled = true
	end
	local run: Run = {
		cinematic = cinematic,
		victim = victim,
		cancelled = false,
		started = os.clock(),
	}
	runs[attacker] = run
	if cinematic.placement == "charge" then
		-- His body runs along the path, his root already where he ends
		-- (Shared/Finishers CHARGE).
		local studs = if typeof(short) == "number"
			then math.clamp(short, 0, Finishers.CHARGE.short)
			else 0
		local duration = cinematic.duration
		local frame: CFrame = anchor
		CharacterAnimationController.pinRoot(attacker, function(): Vector3?
			local t = os.clock() - run.started
			if run.cancelled or t >= duration then
				return nil
			end
			return frame * Finishers.chargeRoot(t, studs)
		end)
	end
	local character = player.Character
	if character ~= nil and (character == attacker or character == victim) then
		run.stopCamera = playCamera(cinematic, anchor, victim, shakes)
		if character == attacker then
			CombatController.holdAttacks(cinematic.duration)
		end
	end

	for _, event in cinematic.events do
		task.delay(event.time, function()
			-- (throwing the liver / the arm down needs only him there)
			local victimThere = victim.Parent ~= nil
				or event.kind == "Drop"
				or event.kind == "Throw"
			if not run.cancelled and attacker.Parent and victimThere then
				playEvent(cinematic, event, attacker, victim, anchor)
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
-- (Ended early although killed - someone left or he died: the camera and
-- the hold on attacks end now; the Bull's run stops there too, his root is
-- put where his body is. Other finishers' last beats still play.)
local function onEnded(attacker: unknown, victim: unknown, killed: unknown)
	if typeof(attacker) ~= "Instance" or not attacker:IsA("Model") then
		return
	end
	local run = runs[attacker]
	if run == nil or (run.victim :: unknown) ~= victim then
		return
	end
	runs[attacker] = nil
	local charge = run.cinematic.placement == "charge"
	local early = os.clock() - run.started < run.cinematic.duration - 0.25
	if charge then
		CharacterAnimationController.pinRoot(attacker, nil)
	end
	if killed == true then
		if not early then
			return -- (played to the end: everything stops on its own)
		end
		-- (after the kill, but the server let him go already: our camera and
		-- the hold on our attacks end now; the wounds stay)
		if charge then
			-- (the rest of the run, the toss and the landing: not played)
			run.cancelled = true
			KitVFX.cancelFinisher(attacker)
			CharacterAnimationController.stopAction(attacker, "Bull_Finisher")
		end
		if run.stopCamera then
			run.stopCamera()
		end
		if attacker == player.Character then
			CombatController.releaseAttacks()
		end
		return
	end
	run.cancelled = true
	KitEffects.stopAction(attacker) -- the bat
	LiverRip.cancel(attacker)
	KitVFX.cancelFinisher(attacker)
	for _, clip in ATTACKER_CLIPS do
		CharacterAnimationController.stopAction(attacker, clip)
	end
	for _, clip in VICTIM_CLIPS do
		CharacterAnimationController.stopAction(run.victim, clip)
	end
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
