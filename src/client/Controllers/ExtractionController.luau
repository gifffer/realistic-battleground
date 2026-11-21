--!strict
-- ExtractionController: the extraction mini-game on YOUR screen (client only).
--
-- The server runs the real thing (Server/Systems/Contraband/Extraction): it starts the
-- session (the vat's "Extract" prompt), decides the step, the minimum times, which fibres are
-- the right ones, the score and the grade. It tells us with "ExtractState" (each change) and
-- "ExtractDone" (the grade). We only show the scene and send what the player did with
-- Remotes.ExtractStep(sessionId, step, data) — the server checks everything again.
--
-- What it looks like (ART_V2 §5.3, autopsy gestures on a biotech interior, never red):
--   intro    the shell glides out of the vat onto the bench (2 s), the camera takes a fixed
--            45° shot over the bench (FOV 50), the cursor is freed
--   1 UNLOCK grab a port clamp and turn it a quarter turn; let go on the amber mark
--   2 OPEN   drag the hatch up (cold vapour)
--   3 SPREAD hold and drag sideways: the milky membrane parts; keep inside the two lines
--   4 CUT    swipe across the 4 steady fibres with the scalpel (the 2 flickering ones are
--            decoys); milky droplets
--   5 LIFT   hold the core and pull up slowly; a tension tick shows when you pull too hard;
--            it ends in a soft release
--   6 SEAL   drag the core into the open capsule; the cap closes, frost
--   outro    "SEALED · GRADE B", the camera comes back, the hatch closes and the shell slides
--            into the recycling chute
-- Mouse and touch work the same (one pointer). ESC, Backspace or the STOP button stop it
-- (nothing is lost: the vat stays READY).
--
-- Timing (the roblox-animation skill's "markers", in this game's own system): every sound
-- and effect fires from the LOCAL event it belongs to (the clamp reaching its mark, the hatch
-- let go with its puff, the membrane starting to stretch, the core letting go, the cap
-- shutting), never from the server's reply (which only validates). The outro waits for the
-- seal gesture to finish (the cap never snaps shut mid-swing) and runs its own event table
-- on its own clock (ChuteSlide at 1.4 s). Values the server re-applies on a new step glide
-- to it unless the step jumped (a resync). Camera: BindToRenderStep after the camera
-- scripts, a hard cut to the bench shot with a short push-in (no straight-line flight
-- through the lab's walls), and back to where the player's camera is NOW relative to his
-- body (not to a 25 s old position).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Contraband = script.Parent.Parent.Contraband
local BenchVisual = require(Contraband.BenchVisual)
local ExtractionUI = require(Contraband.ExtractionUI)

local CameraController = require(script.Parent.CameraController)
local LabController = require(script.Parent.LabController)
local SoundController = require(script.Parent.SoundController)

local player = Players.LocalPlayer

local ExtractionController = {}

local INTRO_TIME = 2
local CAMERA_PUSH = 0.35 -- the push-in after the cut to the bench shot
local CAMERA_PUSH_BACK = 0.8 -- studs: where the push-in starts, behind the final shot
local CAMERA_PUSH_FOV = 6 -- degrees wider at the start of the push-in
local CAMERA_OUT = 0.6
local RENDER_NAME = "ExtractionScene"
local SEAL_TIME = 0.6 -- the seal gesture (cap shuts at 0.625 of it)
local SETTLE_RATE = 10 -- 1/s: a re-applied value glides to the server's (~0.3 s to 95 %)
local CHUTE_TIME = 3
local CARD_TIME = 2.5 -- seconds the result card stays before the camera comes back
-- Outro events (seconds from the outro's start), fired when its clock crosses them.
local OUTRO_EVENTS: { { t: number, sound: string } } = {
	{ t = 1.4, sound = "ChuteSlide" },
}
local CUT_GAP = 0.3 -- seconds between two cuts (the server wants ≥ 0.25)
local LIFT_TIME = 1.6 -- the fastest a lift can go (resistance)
-- CUT: a swipe only counts on the OUTER part of a fibre (they all meet at the core: a swipe
-- near the centre would cross decoys by accident). 0.4 = the inner 40 % does not count.
local CUT_FROM = 0.4
local WRONG_HINT_TIME = 1 -- seconds "Wrong fibre: grade down" stays

local STEPS = {
	-- (each hint fits the one-line hint box: keep them under about 50 characters)
	{ name = "UNLOCK", hint = "Turn a clamp a quarter turn. Release on amber." },
	{ name = "OPEN", hint = "Drag the hatch up." },
	{ name = "SPREAD", hint = "Hold and drag sideways. Stay between the lines." },
	{ name = "CUT", hint = "Cut the steady fibres. Skip the flickering." },
	{ name = "LIFT", hint = "Pull up slowly. Keep the tension low." },
	{ name = "SEAL", hint = "Drag the core into the capsule." },
}

type Session = {
	id: number,
	step: number, -- the server's step
	shown: number, -- the step whose gesture we run (0 = intro)
	correct: { number },
	cut: { number },
	clamps: { number },
	startedAt: number, -- os.clock()
	sentStep: number, -- the step we completed and are waiting on (0 = none)
	done: boolean, -- ExtractDone received (outro)
}

-- Current gesture state (reset on every step).
type Gesture = {
	grabbing: boolean,
	start: Vector2,
	-- unlock
	clamp: number,
	lastAngle: number,
	accum: number,
	turns: { number },
	unlocked: { [number]: boolean },
	-- open / spread / lift / seal
	value: number,
	settle: number?, -- animating to this value (released)
	badTime: number,
	heldTime: number,
	-- cut
	lastPoint: Vector2?,
	lastCut: number,
	localCut: { [number]: boolean },
	sealT: number?,
	stretched: boolean, -- the membrane's stretch sound played (once per spread)
}

local session: Session? = nil
local bench: BenchVisual.Bench? = nil
local ui: ExtractionUI.UI? = nil
local gesture: Gesture
local pointer: Vector2 = Vector2.zero
local pressing = false
local wrongHintUntil = 0 -- os.clock(): the "Wrong fibre" hint shows until then
-- The player's camera when we took it: its FOV, and where it was relative to his body (the
-- way back goes to that spot around where the body is NOW).
local savedCamera: { offset: CFrame?, cframe: CFrame, fov: number, kind: Enum.CameraType }? =
	nil
local cameraStart = 0
local cameraOut: { from: CFrame, start: number }? = nil
local outroStart = 0
local outroEvent = 1 -- the next OUTRO_EVENTS entry to fire
local vatRoot: CFrame? = nil
-- ExtractDone came while the seal was still playing: the outro starts when it ends.
local queuedOutro: { grade: string, toCase: boolean, notes: { string }, worth: number }? = nil
-- What the scene shows of the steps the gestures no longer drive (glides, see enterStep).
local hatchShown, hatchTarget = 0, 0
local spreadShown, spreadTarget = 0, 0
local bound = false -- our BindToRenderStep is on
-- Our body's parts, hidden while the camera is over the bench (collected once, not every
-- frame), and the connection that hides parts added meanwhile.
local hiddenParts: { Instance } = {}
local hideConnection: RBXScriptConnection? = nil

local function newGesture(): Gesture
	return {
		grabbing = false,
		start = Vector2.zero,
		clamp = 0,
		lastAngle = 0,
		accum = 0,
		turns = { 0, 0 },
		unlocked = {},
		value = 0,
		settle = nil,
		badTime = 0,
		heldTime = 0,
		lastPoint = nil,
		lastCut = -100,
		localCut = {},
		sealT = nil,
		stretched = false,
	}
end
gesture = newGesture()

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function viewportHeight(): number
	local camera = workspace.CurrentCamera
	return if camera then math.max(camera.ViewportSize.Y, 200) else 720
end

-- World point → viewport pixels (and whether it is in front of the camera).
local function project(world: Vector3): (Vector2, boolean)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return Vector2.zero, false
	end
	local point, onScreen = camera:WorldToViewportPoint(world)
	return Vector2.new(point.X, point.Y), onScreen and point.Z > 0
end

-- Viewport pixels → the point on a plane (through `origin`, normal `normal`).
local function onPlane(at: Vector2, origin: Vector3, normal: Vector3): Vector3?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local ray = camera:ViewportPointToRay(at.X, at.Y)
	local denominator = ray.Direction:Dot(normal)
	if math.abs(denominator) < 1e-4 then
		return nil
	end
	local t = (origin - ray.Origin):Dot(normal) / denominator
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

-- Do segments p1→p2 and q1→q2 cross (2D)?
local function crosses(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2): boolean
	local function side(a: Vector2, b: Vector2, c: Vector2): number
		return (b.X - a.X) * (c.Y - a.Y) - (b.Y - a.Y) * (c.X - a.X)
	end
	local d1 = side(q1, q2, p1)
	local d2 = side(q1, q2, p2)
	local d3 = side(p1, p2, q1)
	local d4 = side(p1, p2, q2)
	return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0))
		and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))
end

local function send(step: number, data: { [string]: any }?)
	local current = session
	if current == nil then
		return
	end
	Remotes.ExtractStep:FireServer(current.id, step, data)
end

------------------------------------------------------------------------------
-- Camera and own character
------------------------------------------------------------------------------

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function takeCamera()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	if savedCamera == nil then
		local root = rootPart()
		savedCamera = {
			offset = if root then root.CFrame:ToObjectSpace(camera.CFrame) else nil,
			cframe = camera.CFrame,
			fov = camera.FieldOfView,
			kind = camera.CameraType,
		}
	end
	cameraStart = os.clock()
	cameraOut = nil
	camera.CameraType = Enum.CameraType.Scriptable
	CameraController.setCursorFree("extract", true)
	CameraController.holdRotation("extract", true)
end

local function giveCameraBack()
	local camera = workspace.CurrentCamera
	local saved = savedCamera
	savedCamera = nil
	cameraOut = nil
	if camera and saved then
		camera.FieldOfView = saved.fov
		camera.CameraType = Enum.CameraType.Custom
	end
	CameraController.setCursorFree("extract", false)
	CameraController.holdRotation("extract", false)
end

-- Your own body hides while the camera is over the bench (it would stand in the shot).
-- The parts are collected once (and those added meanwhile); keepBodyHidden() re-applies the
-- value every frame without walking the character (the default camera scripts may write
-- LocalTransparencyModifier too).
local function hideable(instance: Instance): boolean
	return instance:IsA("BasePart") or instance:IsA("Decal")
end

local function hideOwnBody(hidden: boolean)
	if hideConnection then
		hideConnection:Disconnect()
		hideConnection = nil
	end
	for _, part in hiddenParts do
		if part.Parent then
			(part :: any).LocalTransparencyModifier = 0
		end
	end
	table.clear(hiddenParts)
	local character = player.Character
	if not hidden or character == nil then
		return
	end
	for _, descendant in character:GetDescendants() do
		if hideable(descendant) then
			table.insert(hiddenParts, descendant)
			(descendant :: any).LocalTransparencyModifier = 1
		end
	end
	hideConnection = character.DescendantAdded:Connect(function(descendant)
		if hideable(descendant) then
			table.insert(hiddenParts, descendant)
			(descendant :: any).LocalTransparencyModifier = 1
		end
	end)
end

local function keepBodyHidden()
	for _, part in hiddenParts do
		if (part :: any).LocalTransparencyModifier ~= 1 then
			(part :: any).LocalTransparencyModifier = 1
		end
	end
end

------------------------------------------------------------------------------
-- Session start / end
------------------------------------------------------------------------------

local render: (dt: number) -> () -- defined below (every frame while a session runs)

local function bindRender(on: boolean)
	if on == bound then
		return
	end
	bound = on
	if on then
		-- after the camera scripts (Camera + 1 is CameraController): our shot wins
		RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, render)
	else
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end
end

local function stopLocal()
	local current = bench
	bench = nil
	if current then
		BenchVisual.destroy(current)
	end
	session = nil
	queuedOutro = nil
	pressing = false
	gesture = newGesture()
	bindRender(false)
	if ui then
		ExtractionUI.show(ui, false)
		ExtractionUI.result(ui, nil, nil)
	end
	if savedCamera then
		giveCameraBack()
	end
	hideOwnBody(false)
	LabController.setCloneHidden(false)
end

-- The player stops (ESC / Backspace / STOP): tell the server, end at once here.
local function cancel()
	local current = session
	if current == nil or current.done then
		return
	end
	send(0, nil)
	stopLocal()
end

local function ensureUI(): ExtractionUI.UI
	local current = ui
	if current then
		return current
	end
	local made = ExtractionUI.new(cancel)
	ui = made
	return made
end

local function enterStep(step: number)
	local current = session
	local scene = bench
	if current == nil or scene == nil then
		return
	end
	current.shown = step
	current.sentStep = 0
	-- (a normal step after the one we just did: what the server re-applies glides there;
	-- the first step, a jump or a step back = a resync: it snaps)
	local resync = previous == 0 or step ~= previous + 1
	local keepUnlocked = gesture.unlocked
	local previous = current.shown
	gesture = newGesture()
	pressing = false
	local info = STEPS[step]
	if info then
		ExtractionUI.setStep(ensureUI(), step, info.name, info.hint)
	end
	-- Make the scene match the steps already done (also after a resync).
	for _, clamp in current.clamps do
		BenchVisual.setClampUnlocked(scene, clamp, true)
		gesture.unlocked[clamp] = true
	end
	if step == 1 then
		for clamp in keepUnlocked do
			gesture.unlocked[clamp] = true
		end
	end
	if step >= 2 then
		for clamp = 1, 2 do
			BenchVisual.setClampUnlocked(scene, clamp, true)
		end
	end
	hatchTarget = if step >= 3 then 1 else 0
	spreadTarget = if step >= 4 then 1 else 0
	if resync or math.abs(hatchShown - hatchTarget) > 0.2 then
		hatchShown = hatchTarget
	end
	if resync or math.abs(spreadShown - spreadTarget) > 0.2 then
		spreadShown = spreadTarget
	end
	BenchVisual.setHatch(scene, hatchShown)
	BenchVisual.setSpread(scene, spreadShown)
	BenchVisual.setFibres(scene, current.correct, current.cut, step == 4)
	for _, guide in current.cut do
		gesture.localCut[guide] = true
	end
	BenchVisual.setLift(scene, if step >= 6 then 1 else 0)
end

local function begin(data: Types.ExtractStatePayload)
	local parts = LabController.parts()
	if parts == nil then
		-- (our lab is not streamed in: we cannot draw it, so do not leave the server waiting)
		Remotes.ExtractStep:FireServer(data.sessionId, 0, nil)
		return
	end
	stopLocal()
	session = {
		id = data.sessionId,
		step = data.step,
		shown = 0,
		correct = table.clone(data.correct),
		cut = table.clone(data.cut),
		clamps = table.clone(data.clamps),
		startedAt = os.clock(),
		sentStep = 0,
		done = false,
	}
	local scene = BenchVisual.new(parts.benchAnchor.CFrame, LabController.visuals())
	bench = scene
	hatchShown, hatchTarget, spreadShown, spreadTarget = 0, 0, 0, 0
	vatRoot = parts.vatCore.CFrame
	BenchVisual.place(scene, parts.vatCore.CFrame)
	LabController.setCloneHidden(true)
	local screen = ensureUI()
	ExtractionUI.show(screen, true)
	ExtractionUI.setStep(screen, 1, "PREPARING", "The shell goes onto the bench.")
	takeCamera()
	hideOwnBody(true)
	bindRender(true)
end

local function beginOutro(grade: string, toCase: boolean, notes: { string }, worth: number)
	local current = session
	local scene = bench
	queuedOutro = nil
	if current == nil or scene == nil then
		return
	end
	current.done = true
	outroStart = os.clock()
	outroEvent = 1
	if not scene.capShut then
		-- (no seal gesture shown here, e.g. after a resync: still close it with its sound)
		BenchVisual.seal(scene, 1)
		SoundController.play2D("CapsuleSeal")
	end
	if grade == "A" or grade == "B" or grade == "C" then
		BenchVisual.reveal(scene, grade)
	end
	BenchVisual.showTool(scene, nil, Vector3.zero, CFrame.identity, false)
	local screen = ensureUI()
	ExtractionUI.setStep(screen, 7, "EXTRACTION COMPLETE", "")
	for key in screen.markers do
		ExtractionUI.marker(screen, key, nil, 0)
	end
	ExtractionUI.ring(screen, 1, nil, 0, 0, 0, false)
	ExtractionUI.ring(screen, 2, nil, 0, 0, 0, false)
	ExtractionUI.band(screen, nil, 0, 0, 0, true)
	ExtractionUI.meter(screen, nil, 0, 0)
	local note = if #notes > 0 then table.concat(notes, " · ") else "Clean work"
	if worth > 0 then
		note ..= ` · worth ~{worth} coins`
	end
	ExtractionUI.result(
		screen,
		`SEALED · GRADE {grade}`,
		if toCase then "Stored in the case on the floor." else "Stored on the stash shelf.",
		note
	)
end

-- The server's verdict. If our seal is still playing, the outro waits for its end (the grade
-- is revealed in a SHUT capsule, never over a cap still swinging).
local function startOutro(grade: string, toCase: boolean, notes: { string }, worth: number)
	local current = session
	if current == nil or current.done then
		return
	end
	local sealT = gesture.sealT
	if current.shown == 6 and sealT and sealT < 1 then
		queuedOutro = { grade = grade, toCase = toCase, notes = notes, worth = worth }
		return
	end
	beginOutro(grade, toCase, notes, worth)
end

------------------------------------------------------------------------------
-- Server messages
------------------------------------------------------------------------------

local function onExtractState(data: Types.ExtractStatePayload)
	local current = session
	if not data.active then
		if current and not current.done then
			stopLocal()
		end
		return
	end
	if current == nil or current.id ~= data.sessionId then
		begin(data)
		return
	end
	if current.done then
		return
	end
	current.correct = table.clone(data.correct)
	current.cut = table.clone(data.cut)
	current.clamps = table.clone(data.clamps)
	-- (no sound here: each one played at its own local event; the reply only validates)
	local changed = current.step ~= data.step
	current.step = data.step
	if changed and current.shown > 0 then
		enterStep(data.step)
	elseif bench and current.shown == 4 then
		BenchVisual.setFibres(bench, current.correct, current.cut, true)
	end
end

------------------------------------------------------------------------------
-- Gestures
------------------------------------------------------------------------------

local function nearestClamp(at: Vector2, points: BenchVisual.Points, radius: number): number
	local best, bestDistance = 0, radius
	for index, world in points.clamps do
		if not gesture.unlocked[index] then
			local screen = project(world)
			local distance = (screen - at).Magnitude
			if distance <= bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	return best
end

local function pointerDown(at: Vector2)
	local current = session
	local scene = bench
	if current == nil or scene == nil or current.done or current.shown == 0 then
		return
	end
	if current.sentStep == current.shown then
		return -- (waiting for the server)
	end
	local u = viewportHeight()
	local points = BenchVisual.points(scene)
	local step = current.shown
	pressing = true
	if step == 1 then
		local clamp = nearestClamp(at, points, 0.09 * u)
		if clamp > 0 then
			local centre = project(points.clamps[clamp])
			gesture.grabbing = true
			gesture.clamp = clamp
			gesture.accum = 0
			gesture.lastAngle = math.atan2(at.Y - centre.Y, at.X - centre.X)
		end
	elseif step == 2 then
		local hatch = project(points.hatch)
		local edge = project(points.hatchEdge)
		if math.min((hatch - at).Magnitude, (edge - at).Magnitude) <= 0.14 * u then
			gesture.grabbing = true
			gesture.start = at
			gesture.settle = nil
		end
	elseif step == 3 then
		if (project(points.membrane) - at).Magnitude <= 0.16 * u then
			gesture.grabbing = true
			gesture.start = at
			gesture.settle = nil
		end
	elseif step == 5 then
		if (project(points.core) - at).Magnitude <= 0.11 * u then
			gesture.grabbing = true
			gesture.start = at
		end
	elseif step == 6 then
		if gesture.sealT == nil and (project(points.core) - at).Magnitude <= 0.11 * u then
			gesture.grabbing = true
			gesture.start = at
		end
	end
	gesture.lastPoint = at
end

local function pointerMove(at: Vector2)
	local current = session
	local scene = bench
	if current == nil or scene == nil or current.done then
		return
	end
	local u = viewportHeight()
	local step = current.shown
	if step == 1 and gesture.grabbing then
		local points = BenchVisual.points(scene)
		local centre = project(points.clamps[gesture.clamp])
		local angle = math.atan2(at.Y - centre.Y, at.X - centre.X)
		local delta = angle - gesture.lastAngle
		if delta > math.pi then
			delta -= 2 * math.pi
		elseif delta < -math.pi then
			delta += 2 * math.pi
		end
		gesture.lastAngle = angle
		gesture.accum += delta
		local turn = math.clamp(math.abs(gesture.accum) / (math.pi / 2), 0, 1.4)
		gesture.turns[gesture.clamp] = turn
		BenchVisual.setClamp(scene, gesture.clamp, turn)
	elseif step == 2 and gesture.grabbing then
		gesture.value = math.clamp((gesture.start.Y - at.Y) / (0.18 * u), 0, 1)
	elseif step == 3 and gesture.grabbing then
		gesture.value = math.clamp(math.abs(at.X - gesture.start.X) / (0.2 * u), 0, 1)
	elseif step == 4 and pressing and current.sentStep ~= 4 then
		local last = gesture.lastPoint
		if last and (at - last).Magnitude > 1 and os.clock() - gesture.lastCut >= CUT_GAP then
			local points = BenchVisual.points(scene)
			for index, fibre in points.fibres do
				if not gesture.localCut[index] then
					local a = project(fibre.a:Lerp(fibre.b, CUT_FROM))
					local b = project(fibre.b)
					if crosses(last, at, a, b) then
						gesture.localCut[index] = true
						gesture.lastCut = os.clock()
						local wrong = table.find(current.correct, index) == nil
						BenchVisual.cut(scene, index, false, wrong)
						SoundController.play2D("FibreSnap")
						if wrong then
							wrongHintUntil = os.clock() + WRONG_HINT_TIME
						end
						send(4, { guide = index })
						-- all the right ones cut? then we wait for the server's next step
						local all = true
						for _, needed in current.correct do
							if not gesture.localCut[needed] then
								all = false
							end
						end
						if all then
							current.sentStep = 4
						end
						break
					end
				end
			end
		end
	end
	gesture.lastPoint = at
end

local function pointerUp(at: Vector2)
	local current = session
	local scene = bench
	pressing = false
	if current == nil or scene == nil or current.done then
		return
	end
	local u = viewportHeight()
	local step = current.shown
	if step == 1 and gesture.grabbing then
		gesture.grabbing = false
		local clamp = gesture.clamp
		local degrees = (gesture.turns[clamp] or 0) * 90
		if degrees >= 60 then
			-- unlocked: accuracy 1 within 6° of the mark, 0 at 36° away
			local accuracy = 1 - math.clamp((math.abs(degrees - 90) - 6) / 30, 0, 1)
			gesture.unlocked[clamp] = true
			BenchVisual.setClampUnlocked(scene, clamp, true)
			SoundController.play2D("ClampClunk")
			send(1, { clamp = clamp, accuracy = accuracy })
			if gesture.unlocked[1] and gesture.unlocked[2] then
				current.sentStep = 1
			end
		else
			gesture.turns[clamp] = 0
			-- (let go short of the mark: the spring brings the lever back, it doesn't snap)
			BenchVisual.settleClamp(scene, clamp, 0)
		end
	elseif step == 2 and gesture.grabbing then
		gesture.grabbing = false
		if gesture.value >= 0.8 then
			gesture.settle = 1
			-- the seal breaks: the hiss and the cold puff together
			BenchVisual.puff(scene)
			SoundController.play2D("HatchHiss")
			current.sentStep = 2
			send(2, {})
		else
			gesture.settle = 0
		end
	elseif step == 3 and gesture.grabbing then
		gesture.grabbing = false
		if current.sentStep ~= 3 then
			gesture.settle = 0
		end
	elseif step == 5 and gesture.grabbing then
		gesture.grabbing = false
	elseif step == 6 and gesture.grabbing then
		gesture.grabbing = false
		local points = BenchVisual.points(scene)
		if (project(points.capsule) - at).Magnitude <= 0.09 * u then
			gesture.sealT = 0
			current.sentStep = 6
			send(6, {})
		end
		BenchVisual.setCoreWorld(scene, nil)
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x) * (1 - x)
end

local function updateCamera(now: number)
	local camera = workspace.CurrentCamera
	local scene = bench
	local saved = savedCamera
	if camera == nil or scene == nil or saved == nil then
		return
	end
	local target = BenchVisual.cameraCFrame(scene.anchor)
	local out = cameraOut
	if out then
		-- back to the player's view, where it is NOW around his body (then Custom takes over)
		local root = rootPart()
		local offset = saved.offset
		local goal = if root and offset then root.CFrame * offset else saved.cframe
		local t = smooth((now - out.start) / CAMERA_OUT)
		camera.CFrame = out.from:Lerp(goal, t)
		camera.FieldOfView = BenchVisual.CAMERA_FOV + (saved.fov - BenchVisual.CAMERA_FOV) * t
		if t >= 1 then
			giveCameraBack()
		end
		return
	end
	-- A hard cut to the bench shot, then a short push-in (ease-out): no flight through the
	-- small lab's walls or the vat.
	camera.CameraType = Enum.CameraType.Scriptable
	local push = 1 - easeOut((now - cameraStart) / CAMERA_PUSH)
	camera.CFrame = target * CFrame.new(0, 0, CAMERA_PUSH_BACK * push)
	camera.FieldOfView = BenchVisual.CAMERA_FOV + CAMERA_PUSH_FOV * push
end

-- A value the server re-applied glides to it (frame-rate independent, never pops).
local function glide(value: number, target: number, dt: number): number
	if value == target then
		return value
	end
	local next = value + (target - value) * (1 - math.exp(-dt * SETTLE_RATE))
	return if math.abs(target - next) < 0.002 then target else next
end

local function updateIntro(now: number, scene: BenchVisual.Bench, current: Session)
	local t = (now - current.startedAt) / INTRO_TIME
	local from = vatRoot or scene.root
	local to = BenchVisual.lyingRoot(scene.anchor)
	-- an arc: rise out of the vat, glide over, settle down on the bench
	local s = smooth(t)
	local root = from:Lerp(to, s) + Vector3.new(0, math.sin(s * math.pi) * 1.2, 0)
	BenchVisual.place(scene, root)
	if t >= 1 then
		BenchVisual.place(scene, to)
		enterStep(current.step)
	end
end

local function updateGesture(
	dt: number,
	current: Session,
	scene: BenchVisual.Bench,
	screen: ExtractionUI.UI
)
	local u = viewportHeight()
	local points = BenchVisual.points(scene)
	local camera = workspace.CurrentCamera
	local cameraCFrame = if camera then camera.CFrame else CFrame.identity
	local step = current.shown
	local waiting = current.sentStep == step
	local toolAt = onPlane(pointer, points.plane.Position, points.plane.UpVector)
		or points.plane.Position

	-- What the gestures of the steps done no longer drive glides to the server's state.
	if step >= 3 and hatchShown ~= hatchTarget then
		hatchShown = glide(hatchShown, hatchTarget, dt)
		BenchVisual.setHatch(scene, hatchShown)
	end
	if step >= 4 and spreadShown ~= spreadTarget then
		spreadShown = glide(spreadShown, spreadTarget, dt)
		BenchVisual.setSpread(scene, spreadShown)
	end

	-- markers off by default; each step turns its own on
	local showRings, showBand, showMeter = false, false, false
	local markerCore, markerHatch, markerMembrane, markerCapsule = false, false, false, false

	if step == 1 then
		showRings = true
		for index, world in points.clamps do
			local centre = project(world)
			ExtractionUI.ring(
				screen,
				index,
				centre,
				0.07 * u,
				(gesture.turns[index] or 0) * 90,
				90,
				gesture.unlocked[index] == true
			)
		end
		local grabbed = if gesture.grabbing then points.clamps[gesture.clamp] else nil
		BenchVisual.showTool(scene, "Hand", grabbed or toolAt, cameraCFrame, gesture.grabbing)
	elseif step == 2 then
		local value = gesture.value
		local settle = gesture.settle
		if settle then
			value += (settle - value) * (1 - math.exp(-dt * 10))
			gesture.value = value
		end
		BenchVisual.setHatch(scene, value)
		hatchShown = value
		markerHatch = not gesture.grabbing and not waiting
		BenchVisual.showTool(
			scene,
			"Hand",
			if gesture.grabbing then points.hatchEdge else toolAt,
			cameraCFrame,
			gesture.grabbing
		)
	elseif step == 3 then
		if gesture.grabbing then
			-- steadiness: time spent outside the band (and how far) counts against you
			local band = 0.035 * u
			local deviation = math.abs(pointer.Y - gesture.start.Y) / band
			gesture.heldTime += dt
			gesture.badTime += dt * math.clamp(deviation - 1, 0, 1)
			showBand = true
			ExtractionUI.band(
				screen,
				gesture.start.Y,
				band,
				gesture.start.X - 0.26 * u,
				gesture.start.X + 0.26 * u,
				deviation <= 1
			)
			if gesture.value >= 0.97 and current.sentStep ~= 3 then
				local steadiness = 1 - gesture.badTime / math.max(gesture.heldTime, 0.1)
				current.sentStep = 3
				gesture.grabbing = false
				gesture.settle = 1
				send(3, { steadiness = math.clamp(steadiness, 0, 1) })
			end
		else
			local settle = gesture.settle
			if settle then
				gesture.value += (settle - gesture.value) * (1 - math.exp(-dt * 6))
			end
		end
		-- the membrane starts to give: its stretch sound, once
		if gesture.grabbing and not gesture.stretched and gesture.value > 0.12 then
			gesture.stretched = true
			SoundController.play2D("MembraneStretch")
		end
		BenchVisual.setSpread(scene, gesture.value)
		spreadShown = gesture.value
		markerMembrane = not gesture.grabbing and not waiting
		BenchVisual.showTool(
			scene,
			"Hands",
			points.membrane,
			cameraCFrame,
			gesture.grabbing,
			0.35 + gesture.value * 0.75
		)
	elseif step == 4 then
		local count = 0
		for _, needed in current.correct do
			if gesture.localCut[needed] then
				count += 1
			end
		end
		if os.clock() < wrongHintUntil then
			ExtractionUI.setHint(screen, "Wrong fibre: grade down")
		elseif not waiting then
			ExtractionUI.setHint(
				screen,
				`Cut the steady fibres ({count}/{#current.correct}). Skip the flickering.`
			)
		end
		BenchVisual.showTool(scene, "Scalpel", toolAt, cameraCFrame, pressing)
	elseif step == 5 then
		if gesture.grabbing and not waiting then
			local target = math.clamp((gesture.start.Y - pointer.Y) / (0.22 * u), 0, 1)
			local delta = math.clamp(target - gesture.value, -dt * 1.2, dt / LIFT_TIME)
			gesture.value += delta
			local tension = math.clamp(target - gesture.value, 0, 1)
			gesture.heldTime += dt
			gesture.badTime += dt * math.clamp((tension - 0.25) / 0.5, 0, 1)
			showMeter = true
			local core = project(points.core)
			ExtractionUI.meter(
				screen,
				core + Vector2.new(0.09 * u, 0.07 * u),
				gesture.value,
				tension
			)
			if gesture.value >= 0.995 then
				-- the soft release: the core lets go of its cradle
				gesture.value = 1
				gesture.grabbing = false
				SoundController.play2D("CoreRelease")
				current.sentStep = 5
				local smoothness = 1 - gesture.badTime / math.max(gesture.heldTime, 0.1)
				send(5, { smooth = math.clamp(smoothness, 0, 1) })
			end
		elseif not waiting then
			-- let go too early: it sinks back into the cradle
			gesture.value = math.max(0, gesture.value - dt * 0.6)
		end
		BenchVisual.setLift(scene, gesture.value)
		markerCore = not gesture.grabbing and not waiting
		BenchVisual.showTool(
			scene,
			"Hand",
			if gesture.grabbing then points.core + points.plane.UpVector * 0.15 else toolAt,
			cameraCFrame,
			gesture.grabbing
		)
	elseif step == 6 then
		local sealT = gesture.sealT
		if sealT then
			sealT = math.min(1, sealT + dt / SEAL_TIME)
			gesture.sealT = sealT
			-- (the click and the hiss on the frame the cap shuts: the seal's own "marker")
			if BenchVisual.seal(scene, sealT) then
				SoundController.play2D("CapsuleSeal")
			end
			BenchVisual.showTool(scene, nil, toolAt, cameraCFrame, false)
		elseif gesture.grabbing then
			-- the core follows the pointer at its lifted height
			local height = points.core
			local hit = onPlane(pointer, height, points.plane.UpVector)
			if hit then
				BenchVisual.setCoreWorld(scene, CFrame.new(hit) * scene.root.Rotation)
			end
			markerCapsule = true
			BenchVisual.showTool(
				scene,
				"Hand",
				(hit or height) + points.plane.UpVector * 0.15,
				cameraCFrame,
				true
			)
		else
			markerCore = true
			BenchVisual.showTool(scene, "Hand", toolAt, cameraCFrame, false)
		end
	end

	if not showRings then
		ExtractionUI.ring(screen, 1, nil, 0, 0, 0, false)
		ExtractionUI.ring(screen, 2, nil, 0, 0, 0, false)
	end
	if not showBand then
		ExtractionUI.band(screen, nil, 0, 0, 0, true)
	end
	if not showMeter then
		ExtractionUI.meter(screen, nil, 0, 0)
	end
	ExtractionUI.marker(
		screen,
		"hatch",
		if markerHatch then project(points.hatchEdge) else nil,
		0.05 * u,
		"DRAG UP"
	)
	ExtractionUI.marker(
		screen,
		"membrane",
		if markerMembrane then project(points.membrane) else nil,
		0.06 * u,
		"HOLD · DRAG SIDEWAYS"
	)
	ExtractionUI.marker(
		screen,
		"core",
		if markerCore then project(points.core) else nil,
		0.05 * u,
		if step == 6 then "DRAG" else "HOLD · PULL UP"
	)
	ExtractionUI.marker(
		screen,
		"capsule",
		if markerCapsule then project(points.capsule) else nil,
		0.045 * u,
		"HERE"
	)
	if waiting and step ~= 4 then
		ExtractionUI.setHint(screen, "Hold on…")
	end
end

local function updateOutro(now: number, scene: BenchVisual.Bench, parts: LabController.LabParts?)
	local t = now - outroStart
	-- 0–CARD_TIME s: the result card; then the camera comes back
	if t >= CARD_TIME and cameraOut == nil and savedCamera ~= nil then
		local camera = workspace.CurrentCamera
		cameraOut = { from = if camera then camera.CFrame else CFrame.identity, start = now }
		if ui then
			ExtractionUI.show(ui, false)
		end
		hideOwnBody(false)
	end
	-- Its events, on its own clock (a hitch can't split a sound from its motion).
	while OUTRO_EVENTS[outroEvent] and t >= OUTRO_EVENTS[outroEvent].t do
		SoundController.play2D(OUTRO_EVENTS[outroEvent].sound)
		outroEvent += 1
	end
	-- 0.8–1.2 s: the hatch closes; the capsule goes to its place (the shelf / the case)
	BenchVisual.setHatch(scene, 1 - smooth((t - 0.8) / 0.4))
	if t >= 1.6 then
		local capsule = scene.capsule
		for _, part in capsule:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = math.max(part.Transparency, smooth((t - 1.6) / 0.5))
			end
		end
	end
	-- 1.4–4.4 s: the shell slides into the recycling chute and fades into it
	local chute = if parts then parts.chuteMouth else nil
	if chute and t >= 1.4 then
		local slide = (t - 1.4) / CHUTE_TIME
		BenchVisual.place(scene, BenchVisual.chuteRoot(scene, chute.CFrame, math.min(slide, 1)))
		if slide > 0.8 then
			BenchVisual.fade(scene, 1 - (slide - 0.8) / 0.2)
		end
	elseif t >= 1.4 then
		BenchVisual.fade(scene, 1 - (t - 1.4) / 1)
	end
	if t >= 1.4 + CHUTE_TIME + 0.2 then
		stopLocal()
	end
end

function render(dt: number)
	local current = session
	local scene = bench
	local screen = ui
	if current == nil or scene == nil or screen == nil then
		return
	end
	local now = os.clock()
	local parts = LabController.parts()
	if parts == nil and not current.done then
		-- (the lab is gone: we left it, or it streamed out)
		stopLocal()
		return
	end
	updateCamera(now)
	if savedCamera ~= nil and not current.done then
		keepBodyHidden()
	end
	if current.done then
		updateOutro(now, scene, parts)
	elseif current.shown == 0 then
		updateIntro(now, scene, current)
	else
		BenchVisual.place(scene, BenchVisual.lyingRoot(scene.anchor))
		updateGesture(dt, current, scene, screen)
		-- the verdict came during the seal: the outro starts once the cap is shut
		local queued = queuedOutro
		if queued and (gesture.sealT or 1) >= 1 then
			beginOutro(queued.grade, queued.toCase, queued.notes, queued.worth)
		end
	end
	if bench then
		BenchVisual.step(scene, dt, now)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function viewportPoint(input: InputObject): Vector2
	local inset = GuiService:GetGuiInset()
	return Vector2.new(input.Position.X, input.Position.Y) + inset
end

function ExtractionController.init()
	Remotes.ContrabandEvent.OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "ExtractState" then
			onExtractState(data :: Types.ExtractStatePayload)
		elseif kind == "ExtractDone" then
			local grade = data.grade
			-- (only short strings from the server, at most 4)
			local notes: { string } = {}
			if typeof(data.notes) == "table" then
				for _, line in data.notes do
					if typeof(line) == "string" and #notes < 4 then
						table.insert(notes, string.sub(line, 1, 40))
					end
				end
			end
			local worth = if typeof(data.worth) == "number" then math.floor(data.worth) else 0
			startOutro(
				if typeof(grade) == "string" then grade else "?",
				data.toCase == true,
				notes,
				worth
			)
		end
	end)
end

function ExtractionController.start()
	-- (render is bound with BindToRenderStep while a session runs only: see bindRender)

	-- One pointer: the mouse, or the first finger.
	local touch: any = nil -- (the finger we follow)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if session == nil then
			return
		end
		-- (Backspace while typing in the chat must not stop the extraction)
		if
			input.KeyCode == Enum.KeyCode.Escape
			or (input.KeyCode == Enum.KeyCode.Backspace and not gameProcessed)
		then
			cancel()
			return
		end
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseButton1
			or (kind == Enum.UserInputType.Touch and touch == nil)
		then
			local at = viewportPoint(input)
			if ui and ExtractionUI.isOverStop(ui, at) then
				return
			end
			if kind == Enum.UserInputType.Touch then
				touch = input
			end
			pointer = at
			pointerDown(at)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if session == nil then
			return
		end
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseMovement
			or (kind == Enum.UserInputType.Touch and input == touch)
		then
			pointer = viewportPoint(input)
			pointerMove(pointer)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch and input == touch then
			touch = nil
			pointerUp(viewportPoint(input))
		elseif kind == Enum.UserInputType.MouseButton1 then
			pointerUp(viewportPoint(input))
		end
	end)

	-- Dying / respawning ends it here too (the server aborts on its side).
	player.CharacterRemoving:Connect(function()
		if session then
			stopLocal()
		end
	end)
end

return ExtractionController
