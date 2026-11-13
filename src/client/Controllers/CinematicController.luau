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
--     on each blow (the hardest ones freeze it a beat - a hit-stop, the
--     clips hold the same beat - and flash the screen; shots can follow a
--     moving target: the victim's head, the Boxer's fist). The player can't
--     move during it (the server holds both characters); the normal camera
--     comes back at the end.
--   • a cinematic with `ownCamera` (the Boxer's) takes no camera: the two
--     fighters keep their own, third or first person as they had it, only
--     shaken (lighter) on the blows and held still through each hit-stop;
--     in first person the attacker sees his own arms.
--
-- The server can cut it short before the killing blow (the attacker dies,
-- someone leaves: Remotes.FinisherEnded with killed = false): everything
-- stops at once and the camera comes back.

local Lighting = game:GetService("Lighting")
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
local RiftFx = require(script.Parent.Parent.Combat.RiftFx)
local CameraController = require(script.Parent.CameraController)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local CombatController = require(script.Parent.CombatController)
local SoundController = require(script.Parent.SoundController)

local player = Players.LocalPlayer

local CinematicController = {}

local WHITE = Color3.new(1, 1, 1)
local BAR_HEIGHT = 0.11 -- of the screen, top and bottom
local BAR_TIME = 0.35

-- Camera shake: a kick that dies out fast (strength in degrees, push-in in
-- field of view). `stop`: a hit-stop, seconds the camera freezes on the
-- blow (the shot's motion and the shake held, the push-in kept) before it
-- dies out. `flash`: how hard the screen flinches (brighter, harder, a red
-- cast; 1 = the most).
type Shake = { at: number, strength: number, punch: number, stop: number?, flash: number? }
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
	-- (Dr. Rift's portal)
	Lift = { at = 0, strength = 1.5, punch = 2 },
	PortalOpen = { at = 0, strength = 1, punch = 2 },
	Cut = { at = 0, strength = 5, punch = 10 },
	Fold = { at = 0, strength = 1.5, punch = 2 },
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
	-- (the Boxer's, on the fighters' own cameras, lighter - OWN_SHAKE: every
	-- blow freezes the jolt a beat - both clips hold the same beat; the coil
	-- before the last one pulls the view out a little. The wrench
	-- and the rip don't freeze: the hand keeps turning, and the victim goes
	-- limp on the rip - the server ragdolls it there)
	KnockoutCombo = {
		Grab = { at = 0, strength = 0.8, punch = 1 },
		Body = { at = 0, strength = 1.8, punch = 3, stop = 0.05 },
		Face = { at = 0, strength = 2.6, punch = 4, stop = 0.05, flash = 0.25 },
		Wind = { at = 0, strength = 0.3, punch = -4 },
		Gut = { at = 0, strength = 5.5, punch = 12, stop = 0.06, flash = 1 },
		Dig = { at = 0, strength = 1.4, punch = 1.5 },
		Wrench = { at = 0, strength = 2.2, punch = 3, flash = 0.3 },
		Rip = { at = 0, strength = 3.5, punch = 6, flash = 0.6 },
		Squeeze = { at = 0, strength = 0.5, punch = 1.5 },
	},
}
-- The screen's flinch at full strength (Shake.flash).
local FLASH_BRIGHTNESS = 0.12
local FLASH_CONTRAST = 0.4
local FLASH_SATURATION = -0.25
local FLASH_TINT = Color3.fromRGB(255, 150, 140)
-- On the fighters' own cameras (Finishers ownCamera): how much of the shake
-- and of the push-in (a normal camera is shaken lighter than a cutscene).
local OWN_SHAKE = 0.45
local OWN_PUNCH = 0.4
-- (in first person: shown during it)
local ARMS = { "Left Arm", "Right Arm" }

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
	"Rift_FinisherPortalCut",
}
local VICTIM_CLIPS = {
	"Boxer_FinisherVictim",
	"Bouncer_FinisherArmRipVictim",
	"Sentinel_FinisherVictim",
	"Bull_FinisherVictim",
	"Rift_FinisherPortalCutVictim",
}
local runs: { [Model]: Run } = {}
-- What stops the camera of the cinematic we're in now (a new one ends it
-- first, then takes the camera over).
local currentStop: (() -> ())? = nil

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

-- The blows `t` seconds in: the camera's kick (degrees), its push-in (field
-- of view), the screen's flash (0 to 1), and whether a hit-stop holds now.
-- Each dies out fast, held full through its hit-stop.
local function shakeAt(shakes: { Shake }, t: number): (number, number, number, boolean)
	local kick, punch, flash, holding = 0, 0, 0, false
	for _, shake in shakes do
		local age = t - shake.at
		local hold = shake.stop or 0
		if age >= 0 and age < hold then
			holding = true
		end
		if age >= 0 and age < hold + 0.6 then
			local fade = if age < hold then 1 else math.exp(-(age - hold) * 7)
			kick += shake.strength * fade
			punch += shake.punch * fade
			flash += (shake.flash or 0) * fade
		end
	end
	return kick, punch, math.min(flash, 1), holding
end

-- A random jolt of the camera, up to `kick` degrees.
local function jolt(random: Random, kick: number): CFrame
	return CFrame.Angles(
		math.rad(random:NextNumber(-kick, kick)),
		math.rad(random:NextNumber(-kick, kick)),
		math.rad(random:NextNumber(-kick, kick) * 0.5)
	)
end

-- The screen's flinch on the hardest blows (only if this one has any).
local function makeGrade(shakes: { Shake }): ColorCorrectionEffect?
	for _, shake in shakes do
		if shake.flash then
			local effect = Instance.new("ColorCorrectionEffect")
			effect.Name = "FinisherFlash"
			effect.Parent = Lighting
			return effect
		end
	end
	return nil
end

-- The flinch at `flash` (0 to 1) after `last`; returns the new last
-- (it is only written while it changes).
local function showFlash(grade: ColorCorrectionEffect?, flash: number, last: number): number
	if grade == nil or (flash <= 0.002 and last <= 0) then
		return last
	end
	local amount = if flash > 0.002 then flash else 0
	grade.Brightness = FLASH_BRIGHTNESS * amount
	grade.Contrast = FLASH_CONTRAST * amount
	grade.Saturation = FLASH_SATURATION * amount
	grade.TintColor = WHITE:Lerp(FLASH_TINT, amount)
	return amount
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
	if currentStop then
		currentStop() -- (an older one)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	CameraController.holdRotation("cinematic", true)
	showBars(true)
	local start = os.clock()
	local random = Random.new()
	local lastLook: Vector3? = nil
	local lastIndex = 0
	local wobble = CFrame.identity
	local wasHolding = false
	local grade = makeGrade(shakes)
	local lastFlash = 0

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
			local ends = if shots[index + 1] then shots[index + 1].time else cinematic.duration
			local kick, punch, flash, holding = shakeAt(shakes, t)
			-- Hit-stops: the shot's motion holds still while one runs (and
			-- still ends where it should: the held time is taken off its length).
			local frozen, held = 0, 0
			for _, shake in shakes do
				local length = shake.stop
				if length then
					local from = math.max(shake.at, shot.time)
					local to = math.min(shake.at + length, t)
					if to > from then
						frozen += to - from
					end
					local upTo = math.min(shake.at + length, ends)
					if upTo > from then
						held += upTo - from
					end
				end
			end
			local alpha = smooth((t - shot.time - frozen) / math.max(ends - shot.time - held, 1e-3))
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
				-- follow it smoothly (it tumbles); held on a hit-stop
				if lastLook == nil then
					lastLook = target
				elseif not holding then
					lastLook = (lastLook :: Vector3):Lerp(target, 1 - math.exp(-10 * dt))
				end
				look = lastLook :: Vector3
			else
				look = anchor * (shot.look :: Vector3)
				lastLook = nil
			end
			-- Shakes and push-ins from the blows (frozen on a hit-stop: its
			-- full jolt, taken once and held).
			if not holding or not wasHolding then
				wobble = jolt(random, kick)
			end
			wasHolding = holding
			camera.CFrame = CFrame.lookAt(position, look) * wobble
			local fov = shot.fov + ((shot.fovTo or shot.fov) - shot.fov) * alpha
			camera.FieldOfView = math.clamp(fov - punch, 20, 100)
			lastFlash = showFlash(grade, flash, lastFlash)
		end
	)

	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if currentStop == stop then
			currentStop = nil
		end
		if grade then
			grade:Destroy()
		end
		RunService:UnbindFromRenderStep("FinisherCamera")
		showBars(false)
		camera.FieldOfView = normalFov()
		camera.CameraType = Enum.CameraType.Custom
		CameraController.holdRotation("cinematic", false)
	end
	currentStop = stop
	task.delay(cinematic.duration, stop)
	return stop
end

-- In first person (his whole body hidden), his arms shown: the punches, the
-- liver in his fist. Not an arm the camera is in (it would fill the
-- screen). Leaves them as they are in third person.
local function showArms(character: Model, cameraAt: Vector3): boolean
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") or head.LocalTransparencyModifier < 0.99 then
		return false
	end
	for _, name in ARMS do
		local arm = character:FindFirstChild(name)
		if arm and arm:IsA("BasePart") then
			local at = arm.CFrame:PointToObjectSpace(cameraAt)
			local half = arm.Size / 2 + Vector3.new(0.35, 0.35, 0.35)
			local inside = math.abs(at.X) < half.X
				and math.abs(at.Y) < half.Y
				and math.abs(at.Z) < half.Z
			arm.LocalTransparencyModifier = if inside then 1 else 0
		end
	end
	return true
end

-- Hidden again like the rest of the body (Roblox only sets it again when
-- the zoom changes).
local function hideArms(character: Model)
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	for _, name in ARMS do
		local arm = character:FindFirstChild(name)
		if arm and arm:IsA("BasePart") then
			arm.LocalTransparencyModifier = head.LocalTransparencyModifier
		end
	end
end

-- A cinematic that leaves the fighters their own camera (Finishers
-- ownCamera): no shots, no bars, the normal camera (third or first person,
-- turning with the mouse) only shaken on the blows, lighter, the jolt held
-- through each hit-stop, a light push-in and the screen's flinch. The jolt
-- is put on after Roblox's camera and taken off before it runs again (it
-- starts from where the camera looks: it would drift). Returns what stops it.
local function playOwnCamera(
	cinematic: Finishers.Cinematic,
	attacker: Model,
	shakes: { Shake }
): (() -> ())?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	if currentStop then
		currentStop() -- (an older one)
	end
	local character = player.Character
	local body = if character == attacker then character else nil
	CameraController.holdRotation("cinematic", true) -- (held still by the server)
	local start = os.clock()
	local random = Random.new()
	local wobble = CFrame.identity
	local applied = CFrame.identity -- (the jolt on the camera now)
	local wasHolding = false
	local pushed = false -- (our push-in on the field of view)
	local armsShown = false
	local grade = makeGrade(shakes)
	local lastFlash = 0

	local function takeOff()
		if applied ~= CFrame.identity then
			if camera.CameraType ~= Enum.CameraType.Scriptable then
				camera.CFrame *= applied:Inverse()
			end
			applied = CFrame.identity
		end
	end
	RunService:BindToRenderStep("FinisherShakeOff", Enum.RenderPriority.Camera.Value - 1, takeOff)
	RunService:BindToRenderStep("FinisherShake", Enum.RenderPriority.Camera.Value + 10, function()
		local t = os.clock() - start
		if t >= cinematic.duration then
			return
		end
		local kick, punch, flash, holding = shakeAt(shakes, t)
		if not holding or not wasHolding then
			wobble = jolt(random, kick * OWN_SHAKE)
		end
		wasHolding = holding
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CFrame *= wobble
			applied = wobble
		end
		if math.abs(punch) > 0.02 then
			camera.FieldOfView = normalFov() - punch * OWN_PUNCH
			pushed = true
		elseif pushed then
			camera.FieldOfView = normalFov()
			pushed = false
		end
		lastFlash = showFlash(grade, flash, lastFlash)
		if body and body.Parent then
			armsShown = showArms(body, camera.CFrame.Position) or armsShown
		end
	end)

	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if currentStop == stop then
			currentStop = nil
		end
		RunService:UnbindFromRenderStep("FinisherShake")
		RunService:UnbindFromRenderStep("FinisherShakeOff")
		takeOff()
		if pushed then
			camera.FieldOfView = normalFov()
		end
		if grade then
			grade:Destroy()
		end
		if body and armsShown then
			hideArms(body)
		end
		CameraController.holdRotation("cinematic", false)
	end
	currentStop = stop
	task.delay(cinematic.duration, stop)
	return stop
end

-- How the camera shakes on `kind` in this cinematic (its own, or the usual).
local function shakeOf(cinematic: Finishers.Cinematic, kind: string): Shake?
	local overrides = KIT_SHAKES[cinematic.id]
	return (overrides and overrides[kind]) or SHAKES[kind]
end

-- The victim's head / body thrown by a blow (on top of the clip): once its
-- hit-stop is over, when it has one (frozen with the rest till then).
local function flinchAfterStop(
	cinematic: Finishers.Cinematic,
	kind: string,
	victim: Model,
	kick: Vector3
)
	local shake = shakeOf(cinematic, kind)
	local stop = if shake then shake.stop else nil
	if stop then
		task.delay(stop, CharacterAnimationController.flinch, victim, kick)
	else
		CharacterAnimationController.flinch(victim, kick)
	end
end

-- A punch landing on the victim's `partName`: the air and sweat knocked off
-- it, on the side he hits from (KitVFX.fistImpact).
local function impact(attacker: Model, victim: Model, partName: string, strength: number)
	local part = victim:FindFirstChild(partName)
	local from = attacker:FindFirstChild("Torso")
	if part == nil or not part:IsA("BasePart") or from == nil or not from:IsA("BasePart") then
		return
	end
	local along = part.Position - from.Position
	if along.Magnitude < 0.1 then
		return
	end
	along = along.Unit
	KitVFX.fistImpact(part.Position - along * 0.55, along, strength)
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
		KitEffects.showBat(attacker, away - event.time)
		SoundController.play("BatDraw", attacker)
	elseif kind == "Plea" then
		SoundController.play("VictimPlea", victim)
	elseif kind == "Swing" then
		SoundController.play(if cinematic.id == "Bat" then "BatSwing" else "HeavySwing", attacker)
	elseif kind == "Body" or kind == "Stomp" then
		SoundController.play("BodyShot", victim)
		if kind == "Body" then
			impact(attacker, victim, "Torso", 1)
		end
		if event.kick then
			flinchAfterStop(cinematic, kind, victim, event.kick)
		end
	elseif kind == "Face" then
		SoundController.play("HeavyHit", victim)
		KitEffects.bloodSpray(
			victim,
			attacker,
			"Head",
			3,
			KitEffects.bloodSeed(math.floor(event.time * 1000), victim, "Head")
		)
		impact(attacker, victim, "Head", 1.5)
		if event.kick then
			flinchAfterStop(cinematic, kind, victim, event.kick)
		end
	elseif kind == "Dig" or kind == "Wrench" then
		LiverRip.dig(victim, attacker, kind == "Wrench")
	elseif kind == "Squeeze" then
		LiverRip.squeeze(attacker)
	elseif kind == "Kill" then
		-- (the burst itself: HeadBlast, from the server's "HeadBlown")
		SoundController.play("BatCrush", victim)
		-- it goes all over him (and his bat)
		BloodGush.splatter(attacker, victim:GetPivot().Position, 14, math.floor(event.time * 1000))
	elseif kind == "Gut" then
		SoundController.play("KnockoutPunch", victim)
		impact(attacker, victim, "Torso", 2)
		LiverRip.gut(victim, attacker)
	elseif kind == "Rip" then
		LiverRip.rip(victim, attacker)
	elseif kind == "Drop" then
		LiverRip.drop(attacker)
	elseif kind == "Grab" then
		SoundController.play("Grab", victim)
	elseif kind == "Strain" then
		-- (pulling with all he has)
		SoundController.play("Strain", attacker)
	elseif kind == "Wind" then
		-- (the Boxer coiled for the last blow: a low grunt of effort)
		local grunt = SoundController.play("HurtGrunt", attacker)
		if grunt then
			grunt.Volume *= 0.6
			grunt.PlaybackSpeed *= 0.82
		end
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
	elseif
		kind == "Lift"
		or kind == "Aim"
		or kind == "PortalOpen"
		or kind == "PortalClose"
		or kind == "Cut"
	then
		-- (the body in two itself: WaistCut, from the server's "CutInHalf")
		RiftFx.cinematic(kind, attacker, victim, anchor)
		if kind == "Cut" then
			local torso = victim:FindFirstChild("Torso")
			local from = if torso and torso:IsA("BasePart")
				then torso.Position
				else victim:GetPivot().Position
			BloodGush.splatter(attacker, from, 10, math.floor(event.time * 1000))
		end
	elseif kind == "Fold" then
		SoundController.play("LimbDrop", victim)
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
		local shake = shakeOf(cinematic, event.kind)
		if shake then
			table.insert(shakes, {
				at = event.time,
				strength = shake.strength,
				punch = shake.punch,
				stop = shake.stop,
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
		run.stopCamera = if cinematic.ownCamera
			then playOwnCamera(cinematic, attacker, shakes)
			else playCamera(cinematic, anchor, victim, shakes)
		if character == attacker then
			CombatController.holdAttacks(cinematic.duration)
		end
	end

	for _, event in cinematic.events do
		task.delay(event.time, function()
			-- (squeezing / throwing the liver, the arm down needs only him there)
			local victimThere = victim.Parent ~= nil
				or event.kind == "Squeeze"
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
	RiftFx.cancelCinematic(attacker)
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
