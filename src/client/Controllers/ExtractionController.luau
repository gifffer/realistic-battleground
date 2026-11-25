--!strict
-- ExtractionController: the extraction on YOUR screen (client only).
--
-- The server runs the real thing (Server/Systems/Contraband/Extraction): it opens the session
-- (the vat's "Extract" prompt), rolls the culture's bio-elements, decides every score and
-- grade, and tells us with "ExtractState" (the elements as you can see them), "ExtractPicked"
-- (a capsule's grade) and "ExtractDone" (the end). We only show the scene and send CHOICES
-- with Remotes.ExtractAction(sessionId, "Pick" | "Done" | "Stop", index?) — the server checks
-- everything again. No accuracy, time or position is ever sent.
--
-- The flow (DESIGN §6.1, autopsy-style direct manipulation, never red, never an organ):
--   0–0.9 s   INTRO  hard cut to the trolley shot; the shell glides from the vat onto the
--                    trolley; the gloved hand takes the CUTTER from its charger (the charger
--                    LED goes off), the wire heats up (0.6 s)
--   0.9–2.5   CUT    the cutter draws the chest seam by itself, neck → waist (ease-in-out);
--                    amber behind the tip, cooling to a dark scorched line; thin wisps
--   2.5       OPEN   the seam pops, the panels unfold, a heavy cold breath spills out, the
--                    elements light up one by one (80 ms apart); the cutter goes back home
--   SELECT           hover an element: soft outline + "UiSelect"; after 0.5 s the monitor
--                    beside the trolley (ScanScreen) and a small tag lock its reading
--                    ("POD" + viability bars, or "NO SIGNAL"). Hold on it 0.45 s: it rises
--                    against milky strands, then lets go (soft pop), glides into the next
--                    capsule, the cap drops; the server's answer lights the grade + frost.
--                    The cooling bar runs out after 18 s (stutter in the last 4 s).
--   OUTRO            all capsules filled / DONE / time out / Stop after a pick: the panels
--                    fold, the leftovers dim and sink, the result card, the shell slides into
--                    the recycling chute, the camera comes back behind you.
-- Mouse and touch: one pointer (touch = press-and-hold on the element). Gamepad: the left
-- stick snaps between elements, A held = lift, X = DONE, B = Stop. ESC / Backspace / STOP
-- stop it: before any pick the vat stays READY with the SAME elements.
--
-- Timing (roblox-animation skill "markers", in this game's own system): the intro / cut run
-- from ONE timeline table on the scene's own clock (CutterPickup 0.35, WireHot 0.6, SeamStart
-- 0.9, SeamEnd 2.5, PanelsOpen 2.55, ColdBreath 2.6, CutterDocked 3.1); every pick sound
-- fires on its local gesture frame (hold start, release, cap down); BenchVisual's own events
-- ("Sealed", "Crumble", "Frost") come out on the frame they happen. Never on a server reply,
-- except the grade light, which IS the server's answer.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Contraband = script.Parent.Parent.Contraband
local BenchVisual = require(Contraband.BenchVisual)
local ExtractionUI = require(Contraband.ExtractionUI)

local CameraController = require(script.Parent.CameraController)
local LabController = require(script.Parent.LabController)
local SoundController = require(script.Parent.SoundController)

local E = Config.Extraction
local player = Players.LocalPlayer

local ExtractionController = {}

local RENDER_NAME = "ExtractionScene"
local SLIDE_TIME = 0.9 -- the shell from the vat to the trolley
local REACH_END = 0.35 -- the hand reaches the charger
local CUT_START = 0.9
local CUT_END = 2.5
local PANELS_TIME = 0.35
local DOCK_BACK = 0.6 -- the cutter going back to its charger after the cut
local STAGGER = 0.08 -- elements light up one by one
local WISP_EVERY = 0.1
local CAMERA_PUSH = 0.6
local CAMERA_PUSH_BACK = 0.8
local CAMERA_PUSH_FOV = 6
local CAMERA_SWAY = 0.06 -- studs: the very slow breathing of the shot
local CAMERA_OUT = 0.6
local CARD_TIME = 2.8 -- seconds the card stays before the camera comes back
local CHUTE_START = 1.4
local CHUTE_TIME = 3
local PICK_RADIUS = 0.085 -- of the viewport height: how close the pointer must be to an element
local HOLD_SLIP = 0.16 -- of the viewport height: dragging further away lets go
local LOW_TIME = 4 -- the last seconds of the cooling bar

-- The intro / cut timeline (seconds from the start): its events fire when the clock crosses them.
local TIMELINE: { { t: number, name: string } } = {
	{ t = REACH_END, name = "CutterPickup" },
	{ t = 0.6, name = "WireHot" },
	{ t = CUT_START, name = "SeamStart" },
	{ t = CUT_END, name = "SeamEnd" },
	{ t = CUT_END + 0.05, name = "PanelsOpen" },
	{ t = CUT_END + 0.1, name = "ColdBreath" },
	{ t = CUT_END + DOCK_BACK, name = "CutterDocked" },
}

local KIND_NAMES: { [string]: string } = {
	Cluster = "CLUSTER",
	Pod = "POD",
	Coil = "COIL",
	Husk = "NO SIGNAL",
}

type Session = {
	id: number,
	slots: number,
	elements: { Types.ExtractElement },
	startedAt: number, -- os.clock()
	revealLocal: number, -- os.clock(): picks allowed (panels open)
	endsLocal: number, -- os.clock(): the cooling bar runs out
	nextEvent: number, -- the next TIMELINE entry to fire
	lastWisp: number,
	slotOf: { [number]: number }, -- element index → capsule slot (local)
	used: number, -- capsules used locally
	lastPickAt: number,
	holding: number?, -- element being lifted
	holdTime: number,
	hovered: number?,
	hoverSince: number,
	scanned: number?, -- the element whose reading is locked
	lastLowTick: number,
	endSent: boolean, -- Done / Stop sent (waiting for the server)
	done: Types.ExtractDonePayload?, -- the server's end (outro once everything is sealed)
	outroStart: number?,
	chuteEvent: boolean,
	litCount: number,
}

local session: Session? = nil
local bench: BenchVisual.Bench? = nil
local ui: ExtractionUI.UI? = nil
local pointer: Vector2 = Vector2.zero
local pressing = false
local burnLoop: Sound? = nil
local strainLoop: Sound? = nil
local savedCamera: { offset: CFrame?, cframe: CFrame, fov: number }? = nil
local cameraStart = 0
local cameraOut: { from: CFrame, start: number }? = nil
local vatRoot: CFrame? = nil
local bound = false
local hiddenParts: { Instance } = {}
local hideConnection: RBXScriptConnection? = nil
-- The monitor beside the trolley (ScanScreen) and the charger LED, while a session runs.
local screenGui: SurfaceGui? = nil
local screenLines: { TextLabel } = {}
local charger: { part: BasePart, color: Color3, material: Enum.Material }? = nil

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
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

local function send(action: string, index: number?)
	local current = session
	if current then
		Remotes.ExtractAction:FireServer(current.id, action, index)
	end
end

local function stopLoop(sound: Sound?)
	if sound then
		sound:Stop()
		sound:Destroy()
	end
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

-- Your own body hides while the camera is over the trolley (it would stand in the shot).
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
			local part: any = descendant
			table.insert(hiddenParts, part)
			part.LocalTransparencyModifier = 1
		end
	end
	hideConnection = character.DescendantAdded:Connect(function(descendant)
		if hideable(descendant) then
			local part: any = descendant
			table.insert(hiddenParts, part)
			part.LocalTransparencyModifier = 1
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
-- The monitor (ScanScreen) and the charger LED
------------------------------------------------------------------------------

local SCREEN_TEXT = Color3.fromRGB(150, 236, 214)

local function buildScreen(part: BasePart?)
	if part == nil then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ExtractScan"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 160
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.ClipsDescendants = true
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(8, 16, 14)
	back.BorderSizePixel = 0
	back.Parent = gui
	table.clear(screenLines)
	for k = 1, 3 do
		local line = Instance.new("TextLabel")
		line.BackgroundTransparency = 1
		line.Position = UDim2.new(0.08, 0, 0.1 + (k - 1) * 0.27, 0)
		line.Size = UDim2.new(0.84, 0, 0.24, 0)
		line.Font = Enum.Font.RobotoMono
		line.TextScaled = true
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = SCREEN_TEXT
		line.Text = ""
		line.Parent = back
		table.insert(screenLines, line)
	end
	gui.Parent = part
	screenGui = gui
end

local function screenText(a: string, b: string, c: string)
	if screenGui == nil then
		return
	end
	local texts = { a, b, c }
	for k, line in screenLines do
		if line.Text ~= texts[k] then
			line.Text = texts[k]
		end
	end
end

-- Bars as text the monitor's mono font always has ("|||" lit, "." dark).
local function barText(bars: number): string
	return string.rep("|", bars) .. string.rep(".", 3 - bars)
end

-- The work lamp over the trolley is dimmed a little during the close-up (the pale shell
-- would clip to white under it), and put back after.
local LAMP_EXTRACT_BRIGHTNESS = 1.0
local dimmedLamp: { light: SpotLight, brightness: number }? = nil

local function setLampDimmed(dim: boolean)
	if dim then
		local parts = LabController.parts()
		local head = if parts then parts.model:FindFirstChild("LampHead") else nil
		local light = if head then head:FindFirstChildOfClass("SpotLight") else nil
		if light and dimmedLamp == nil then
			dimmedLamp = { light = light, brightness = light.Brightness }
			light.Brightness = math.min(light.Brightness, LAMP_EXTRACT_BRIGHTNESS)
		end
		return
	end
	local saved = dimmedLamp
	dimmedLamp = nil
	if saved and saved.light.Parent then
		saved.light.Brightness = saved.brightness
	end
end

local function setChargerBusy(busy: boolean)
	setLampDimmed(busy)
	local parts = LabController.parts()
	local led = if parts then parts.chargerLed else nil
	if busy then
		if led and charger == nil then
			charger = { part = led, color = led.Color, material = led.Material }
			led:SetAttribute("Busy", true)
		end
		return
	end
	local saved = charger
	charger = nil
	if saved and saved.part.Parent then
		saved.part.Color = saved.color
		saved.part.Material = saved.material
		saved.part:SetAttribute("Busy", false)
	end
end

------------------------------------------------------------------------------
-- Session start / end
------------------------------------------------------------------------------

local render: (dt: number) -> () -- defined below

local function bindRender(on: boolean)
	if on == bound then
		return
	end
	bound = on
	if on then
		-- (after the camera scripts (Camera + 1 is CameraController): our shot wins)
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
	pressing = false
	stopLoop(burnLoop)
	burnLoop = nil
	stopLoop(strainLoop)
	strainLoop = nil
	bindRender(false)
	if ui then
		ExtractionUI.show(ui, false)
	end
	if savedCamera then
		giveCameraBack()
	end
	hideOwnBody(false)
	LabController.setCloneHidden(false)
	setChargerBusy(false)
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

-- Esc / STOP: before any pick it ends at once (the vat stays READY, same elements); after a
-- pick the server ends it and the outro shows what was sealed.
local function cancel()
	local current = session
	if current == nil or current.done or current.endSent then
		return
	end
	SoundController.play2D("UiCancel")
	if current.used == 0 then
		send("Stop", nil)
		stopLocal()
		return
	end
	current.endSent = true
	send("Stop", nil)
end

local function finishNow()
	local current = session
	if current == nil or current.done or current.endSent then
		return
	end
	if current.used == 0 then
		SoundController.play2D("UiError")
		return
	end
	SoundController.play2D("UiConfirm")
	current.endSent = true
	send("Done", nil)
end

local function ensureUI(): ExtractionUI.UI
	local current = ui
	if current then
		return current
	end
	local made = ExtractionUI.new(cancel, finishNow)
	ui = made
	return made
end

-- Only well-formed elements from the server (it is our own server, but never trust a shape).
local function readElements(list: any): { Types.ExtractElement }
	local out: { Types.ExtractElement } = {}
	if typeof(list) ~= "table" then
		return out
	end
	for _, item in list do
		if typeof(item) == "table" and #out < 8 then
			local kind = item.kind
			local condition = item.condition
			table.insert(out, {
				kind = if kind == "Pod"
						or kind == "Coil"
						or kind == "Husk"
					then kind
					else "Cluster",
				condition = if condition == "Bruised" or condition == "Ruptured"
					then condition
					else "Intact",
				viability = if typeof(item.viability) == "number"
					then math.clamp(math.floor(item.viability), 0, 3)
					else 0,
			})
		end
	end
	return out
end

local function begin(data: Types.ExtractStatePayload)
	local parts = LabController.parts()
	local elements = readElements(data.elements)
	if parts == nil or #elements == 0 then
		-- (our lab is not streamed in: we cannot draw it, so do not leave the server waiting)
		Remotes.ExtractAction:FireServer(data.sessionId, "Stop", nil)
		return
	end
	stopLocal()
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local slots = math.clamp(math.floor(tonumber(data.slots) or 1), 1, E.CAPSULES)
	session = {
		id = data.sessionId,
		slots = slots,
		elements = elements,
		startedAt = now,
		revealLocal = math.max(now + CUT_END, now + (data.revealAt - serverNow)),
		endsLocal = now + math.max(CUT_END + 2, data.endsAt - serverNow),
		nextEvent = 1,
		lastWisp = 0,
		slotOf = {},
		used = 0,
		lastPickAt = -math.huge,
		holding = nil,
		holdTime = 0,
		hovered = nil,
		hoverSince = 0,
		scanned = nil,
		lastLowTick = 0,
		endSent = false,
		done = nil,
		outroStart = nil,
		chuteEvent = false,
		litCount = 0,
	}
	local dock = if parts.cutterDock then parts.cutterDock.CFrame else nil
	bench =
		BenchVisual.new(parts.benchAnchor.CFrame, LabController.visuals(), elements, slots, dock)
	vatRoot = parts.vatCore.CFrame
	LabController.setCloneHidden(true)
	buildScreen(parts.scanScreen)
	screenText("SEAM CUTTER", "ARMING", "")
	local screen = ensureUI()
	ExtractionUI.show(screen, true)
	ExtractionUI.setTitle(screen, `EXTRACT · CHOOSE {slots}`)
	ExtractionUI.setHint(screen, "Opening the seam…")
	ExtractionUI.setCooling(screen, nil, false)
	ExtractionUI.setDone(screen, false, false)
	takeCamera()
	hideOwnBody(true)
	bindRender(true)
end

------------------------------------------------------------------------------
-- Server messages
------------------------------------------------------------------------------

local function onExtractState(data: Types.ExtractStatePayload)
	local current = session
	if not data.active then
		-- (the server ended it with no pick: Stop, time out, left the lab...)
		if current and current.done == nil then
			stopLocal()
		end
		return
	end
	if current == nil or current.id ~= data.sessionId then
		begin(data)
	end
	-- (the same session again: nothing to redo, picks are shown by their own events)
end

local function onPicked(data: any)
	local current = session
	local scene = bench
	if current == nil or scene == nil or typeof(data.index) ~= "number" then
		return
	end
	local slot = current.slotOf[data.index]
		or (if typeof(data.slot) == "number" then data.slot else 0)
	local grade = data.grade
	BenchVisual.seal(
		scene,
		slot,
		if grade == "A" or grade == "B" or grade == "C" then grade else nil,
		data.inert == true
	)
end

local function onDone(data: any)
	local current = session
	if current == nil or current.done then
		return
	end
	local cores: { { kind: Types.ElementKind, grade: Types.CoreGrade, worth: number } } = {}
	if typeof(data.cores) == "table" then
		for _, core in data.cores do
			if typeof(core) == "table" and #cores < 4 then
				local grade = core.grade
				local kind = core.kind
				if grade == "A" or grade == "B" or grade == "C" then
					table.insert(cores, {
						kind = if kind == "Pod" or kind == "Coil" then kind else "Cluster",
						grade = grade,
						worth = if typeof(core.worth) == "number"
							then math.floor(core.worth)
							else 0,
					})
				end
			end
		end
	end
	current.done = {
		cores = cores,
		inert = if typeof(data.inert) == "number"
			then math.clamp(math.floor(data.inert), 0, 4)
			else 0,
		toCase = data.toCase == true,
	}
end

------------------------------------------------------------------------------
-- Picking
------------------------------------------------------------------------------

-- The free element nearest the pointer (within PICK_RADIUS of the viewport height), or nil.
local function elementAt(scene: BenchVisual.Bench, at: Vector2): number?
	local best: number? = nil
	local bestDistance = PICK_RADIUS * viewportHeight()
	for index = 1, BenchVisual.elementCount(scene) do
		if BenchVisual.isFree(scene, index) then
			local screen, visible = project(BenchVisual.elementPoint(scene, index))
			local distance = (screen - at).Magnitude
			if visible and distance <= bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	return best
end

local function canPick(current: Session, scene: BenchVisual.Bench, now: number): boolean
	return current.done == nil
		and not current.endSent
		and now >= current.revealLocal
		and now < current.endsLocal
		and current.used < current.slots
		and now - current.lastPickAt >= E.PICK_MIN_GAP + 0.05
		and BenchVisual.isSettled(scene)
end

local function pointerDown(at: Vector2)
	local current = session
	local scene = bench
	if current == nil or scene == nil or current.done then
		return
	end
	pressing = true
	local now = os.clock()
	if now < current.revealLocal then
		return
	end
	local index = elementAt(scene, at)
	if index == nil then
		return
	end
	if not canPick(current, scene, now) then
		SoundController.play2D("UiError")
		return
	end
	current.holding = index
	current.holdTime = 0
	SoundController.play2D("CorePickup")
	if current.elements[index].kind ~= "Husk" then
		stopLoop(strainLoop)
		strainLoop = SoundController.loop("ElementStrain")
		if strainLoop then
			strainLoop:Play()
		end
	end
end

local function letGo()
	local current = session
	local scene = bench
	if current and scene and current.holding then
		BenchVisual.letGo(scene, current.holding)
		current.holding = nil
		current.holdTime = 0
	end
	stopLoop(strainLoop)
	strainLoop = nil
end

local function pointerUp()
	pressing = false
	local current = session
	if current and current.holding then
		letGo() -- (let go before the release: it sinks back, nothing is sent)
	end
end

-- The hold reached HOLD_TIME: release it, send the choice, glide it into the next capsule.
local function releaseHeld(current: Session, scene: BenchVisual.Bench, now: number)
	local index = current.holding
	if index == nil then
		return
	end
	current.holding = nil
	current.holdTime = 0
	stopLoop(strainLoop)
	strainLoop = nil
	current.used += 1
	local slot = current.used
	current.slotOf[index] = slot
	current.lastPickAt = now
	if current.elements[index].kind ~= "Husk" then
		SoundController.play2D("ElementRelease")
	end
	BenchVisual.release(scene, index, slot)
	send("Pick", index)
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

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
	-- A hard cut to the trolley shot, a short push-in (ease-out), then a very slow breathing
	-- sway (two slow sines): readable, cinematic, never a free camera.
	camera.CameraType = Enum.CameraType.Scriptable
	local push = 1 - easeOut((now - cameraStart) / CAMERA_PUSH)
	local sway = Vector3.new(
		math.sin(now * 0.7) * CAMERA_SWAY,
		math.sin(now * 0.53 + 1.3) * CAMERA_SWAY * 0.6,
		0
	)
	camera.CFrame = target * CFrame.new(sway + Vector3.new(0, 0, CAMERA_PUSH_BACK * push))
	camera.FieldOfView = BenchVisual.CAMERA_FOV + CAMERA_PUSH_FOV * push
end

local function fire(name: string, scene: BenchVisual.Bench)
	if name == "CutterPickup" then
		setChargerBusy(true)
		local led = charger
		if led then
			led.part.Material = Enum.Material.SmoothPlastic
			led.part.Color = Color3.fromRGB(40, 40, 40)
		end
		SoundController.play2D("CutterPickup")
	elseif name == "WireHot" then
		SoundController.play2D("CutterArm")
		screenText("SEAM CUTTER", "HOT", "")
	elseif name == "SeamStart" then
		stopLoop(burnLoop)
		burnLoop = SoundController.loop("CutterBurn")
		if burnLoop then
			burnLoop:Play()
		end
	elseif name == "SeamEnd" then
		stopLoop(burnLoop)
		burnLoop = nil
		SoundController.play2D("SeamPop")
	elseif name == "PanelsOpen" then
		SoundController.play2D("PanelsOpen")
	elseif name == "ColdBreath" then
		BenchVisual.breath(scene)
		SoundController.play2D("ColdBreath")
		screenText("CAVITY OPEN", "HOVER TO SCAN", "")
	elseif name == "CutterDocked" then
		SoundController.play2D("ToolTraySetDown")
	end
end

-- 0 .. CUT_END + DOCK_BACK: the shell's slide, the hand, the cutter, the seam, the panels.
local function updateIntro(now: number, scene: BenchVisual.Bench, current: Session, camera: CFrame)
	local t = now - current.startedAt
	while TIMELINE[current.nextEvent] and t >= TIMELINE[current.nextEvent].t do
		fire(TIMELINE[current.nextEvent].name, scene)
		current.nextEvent += 1
	end
	-- the shell: out of the vat in an arc, onto the trolley
	local lying = BenchVisual.lyingRoot(scene.anchor)
	if t < SLIDE_TIME then
		local s = smooth(t / SLIDE_TIME)
		local from = vatRoot or lying
		BenchVisual.place(
			scene,
			from:Lerp(lying, s) + Vector3.new(0, math.sin(s * math.pi) * 1.2, 0)
		)
	else
		BenchVisual.place(scene, lying)
	end
	-- the cutter and the hand
	local dockAt = BenchVisual.dockCFrame(scene)
	local seamStart = BenchVisual.cutterPose(scene, 0, camera)
	if t < REACH_END then
		-- the hand comes in from below the shot to the charger
		local s = smooth(t / REACH_END)
		local from = BenchVisual.handOnCutter(dockAt)
			+ camera.RightVector * 1.2
			- camera.UpVector * 1.4
		BenchVisual.setCutter(scene, nil)
		BenchVisual.setHand(scene, from:Lerp(BenchVisual.handOnCutter(dockAt), s), false)
	elseif t < CUT_START then
		-- lifted off the charger, carried over the seam's neck end (a small arc)
		local s = smooth((t - REACH_END) / (CUT_START - REACH_END))
		local pose = dockAt:Lerp(seamStart, s) + Vector3.new(0, math.sin(s * math.pi) * 0.4, 0)
		BenchVisual.setCutter(scene, pose)
		BenchVisual.setHand(scene, BenchVisual.handOnCutter(pose), false)
	elseif t < CUT_END then
		-- the cut: neck → waist, ease-in-out, the wire hot
		local raw = (t - CUT_START) / (CUT_END - CUT_START)
		local s = smooth(raw)
		BenchVisual.cut(scene, s)
		local pose = BenchVisual.cutterPose(scene, s, camera)
		BenchVisual.setCutter(scene, pose)
		BenchVisual.setHand(scene, BenchVisual.handOnCutter(pose), false)
		if now - current.lastWisp >= WISP_EVERY then
			current.lastWisp = now
			BenchVisual.wisp(scene)
		end
		local loop = burnLoop
		if loop then
			-- the sizzle follows the tip's speed (fastest mid-seam)
			loop.PlaybackSpeed = 1 + 0.2 * (6 * raw * (1 - raw)) / 1.5
		end
	elseif t < CUT_END + DOCK_BACK then
		-- the cutter back to its charger, cooling
		local s = smooth((t - CUT_END) / DOCK_BACK)
		BenchVisual.cut(scene, 1)
		local seamEnd = BenchVisual.cutterPose(scene, 1, camera)
		local pose = seamEnd:Lerp(dockAt, s) + Vector3.new(0, math.sin(s * math.pi) * 0.35, 0)
		BenchVisual.setCutter(scene, pose)
		BenchVisual.setHand(scene, BenchVisual.handOnCutter(pose), false)
	end
	-- the wire: heats from 0.6 s (0.25 s fade-in), cools after the cut
	local heat = if t < 0.6
		then 0
		elseif t < CUT_END then math.clamp((t - 0.6) / 0.25, 0, 1)
		else 1 - math.clamp((t - CUT_END) / 0.5, 0, 1)
	BenchVisual.setWire(scene, heat)
	-- the panels unfold (Quad Out), the elements light up one by one
	if t >= CUT_END then
		BenchVisual.openPanels(scene, easeOut((t - CUT_END) / PANELS_TIME))
		local lit = math.min(#current.elements, math.floor((t - CUT_END) / STAGGER) + 1)
		while current.litCount < lit do
			current.litCount += 1
			BenchVisual.lightUp(scene, current.litCount)
		end
	end
end

local function updateSelect(
	dt: number,
	now: number,
	scene: BenchVisual.Bench,
	current: Session,
	screen: ExtractionUI.UI,
	camera: CFrame
)
	local u = viewportHeight()
	-- hover (none while holding: the held one stays the hovered one)
	local hovered = current.holding or elementAt(scene, pointer)
	if hovered ~= current.hovered then
		current.hovered = hovered
		current.hoverSince = now
		current.scanned = nil
		if hovered then
			SoundController.play2D("UiSelect")
		end
	end
	BenchVisual.hover(scene, hovered)
	-- the scan: locked after SCAN_TIME on the same element (monitor + tag)
	if hovered then
		local element = current.elements[hovered]
		local locked = now - current.hoverSince >= E.SCAN_TIME
		if locked and current.scanned ~= hovered then
			current.scanned = hovered
			SoundController.play2D("ScanLock")
		end
		local name = KIND_NAMES[element.kind] or "?"
		local husk = element.kind == "Husk"
		if locked then
			screenText(
				name,
				if husk then "--" else string.upper(element.condition),
				if husk then "VIABILITY ..." else `VIABILITY {barText(element.viability)}`
			)
		else
			local noise = string.rep(if math.noise(now * 20, 1) > 0 then "#" else "-", 6)
			screenText("SCANNING", noise, "")
		end
		local at, visible = project(BenchVisual.elementPoint(scene, hovered))
		ExtractionUI.tag(screen, if visible then at else nil, name, element.viability, not locked)
	else
		ExtractionUI.tag(screen, nil, "", 0, false)
	end

	-- the hold: rises against the strands, then lets go at HOLD_TIME
	local holding = current.holding
	if holding then
		local at = project(BenchVisual.elementPoint(scene, holding))
		if not pressing or (at - pointer).Magnitude > HOLD_SLIP * u then
			letGo()
		else
			current.holdTime += dt
			local t = current.holdTime / E.HOLD_TIME
			BenchVisual.lift(scene, holding, t)
			ExtractionUI.holdRing(screen, pointer, t)
			if t >= 1 then
				releaseHeld(current, scene, now)
			end
		end
	end
	if current.holding == nil then
		ExtractionUI.holdRing(screen, nil, 0)
	end

	-- the hand: over the element it holds, or following the pointer over the cavity (once
	-- it has put the cutter back on its charger)
	if now - current.startedAt >= CUT_END + DOCK_BACK then
		local plane = scene.root * Vector3.new(0, 0.5, -0.6)
		local up = scene.anchor.UpVector
		local target: Vector3
		local heldNow = current.holding
		if heldNow then
			target = BenchVisual.elementPoint(scene, heldNow)
		else
			target = onPlane(pointer, plane, up) or plane
		end
		BenchVisual.setHand(
			scene,
			BenchVisual.handAt(scene, target, camera, heldNow ~= nil),
			heldNow ~= nil
		)
	end

	-- the cooling bar, its last seconds
	local left = current.endsLocal - now
	local low = left <= LOW_TIME
	ExtractionUI.setCooling(screen, left / E.SELECT_TIME, low)
	if low and left > 0 and now - current.lastLowTick >= 1 then
		current.lastLowTick = now
		SoundController.play2D("TimerLow")
	end
	ExtractionUI.setDone(screen, current.used > 0, not current.endSent and current.holding == nil)
	if current.endSent then
		ExtractionUI.setHint(screen, "Sealing…")
	elseif current.used >= current.slots then
		ExtractionUI.setHint(screen, "All capsules sealed.")
	elseif current.used > 0 then
		ExtractionUI.setHint(
			screen,
			`Hold on an element to lift it out. {current.slots - current.used} capsule left.`
		)
	else
		ExtractionUI.setHint(screen, "Hold on an element to lift it out.")
	end
	-- the bar ran out: whatever is sealed is kept (nothing sealed: the vat stays READY)
	if left <= 0 and current.holding == nil and not current.endSent then
		if current.used == 0 then
			send("Stop", nil)
			stopLocal()
			return
		end
		current.endSent = true
		send("Done", nil)
	end
end

local function updateOutro(now: number, scene: BenchVisual.Bench, current: Session)
	local start = current.outroStart :: number
	local t = now - start
	BenchVisual.closePanels(scene, t / 0.4)
	BenchVisual.setHand(scene, nil, false)
	-- 0–CARD_TIME s: the result card; then the camera comes back
	if t >= CARD_TIME and cameraOut == nil and savedCamera ~= nil then
		local camera = workspace.CurrentCamera
		cameraOut = { from = if camera then camera.CFrame else CFrame.identity, start = now }
		if ui then
			ExtractionUI.show(ui, false)
		end
		hideOwnBody(false)
	end
	if not current.chuteEvent and t >= CHUTE_START then
		current.chuteEvent = true
		SoundController.play2D("ChuteSlide")
	end
	-- the shell slides into the recycling chute; the capsules go with the scene at the end
	local parts = LabController.parts()
	local chute = if parts then parts.chuteMouth else nil
	if t >= CHUTE_START then
		local slide = (t - CHUTE_START) / CHUTE_TIME
		if chute then
			BenchVisual.place(scene, BenchVisual.chuteRoot(scene, chute.CFrame, math.min(slide, 1)))
		else
			BenchVisual.place(scene, BenchVisual.lyingRoot(scene.anchor))
		end
		if slide > 0.8 then
			BenchVisual.fade(scene, 1 - smooth((slide - 0.8) / 0.2))
		end
	else
		BenchVisual.place(scene, BenchVisual.lyingRoot(scene.anchor))
	end
	if t >= CHUTE_START + CHUTE_TIME + 0.2 then
		stopLocal()
	end
end

local function beginOutro(current: Session, done: Types.ExtractDonePayload)
	current.outroStart = os.clock()
	letGo()
	local screen = ensureUI()
	ExtractionUI.setCooling(screen, nil, false)
	ExtractionUI.setDone(screen, false, false)
	ExtractionUI.holdRing(screen, nil, 0)
	ExtractionUI.tag(screen, nil, "", 0, false)
	ExtractionUI.setHint(screen, "")
	screenText("SEALED", `{#done.cores} CORE(S)`, "")
	local lines: { string } = {}
	for _, core in done.cores do
		table.insert(
			lines,
			`{KIND_NAMES[core.kind] or "CORE"} · GRADE {core.grade} · {core.worth}`
		)
	end
	for _ = 1, done.inert do
		table.insert(lines, "HUSK · INERT")
	end
	local sub = if #done.cores == 0
		then "Nothing worth keeping."
		elseif done.toCase then "Stored in the case on the floor."
		else "Stored in the freezer stash."
	ExtractionUI.result(screen, `SEALED {#done.cores + done.inert}/{current.slots}`, lines, sub)
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
	if parts == nil and current.outroStart == nil then
		-- (the lab is gone: we left it, or it streamed out)
		stopLocal()
		return
	end
	updateCamera(now)
	if savedCamera ~= nil and cameraOut == nil then
		keepBodyHidden()
	end
	local camera = workspace.CurrentCamera
	local cameraCFrame = if camera then camera.CFrame else scene.anchor
	-- BenchVisual's own events, on the frame they happen
	for _, event in BenchVisual.takeEvents(scene) do
		if event.name == "Sealed" then
			SoundController.play2D("CapsuleSeal")
			SoundController.play2D("CapsuleHiss")
		elseif event.name == "Crumble" then
			SoundController.play2D("ElementCrumble")
		elseif event.name == "Frost" then
			SoundController.play2D("SealFrost")
		end
	end
	if current.outroStart then
		updateOutro(now, scene, current)
	else
		local t = now - current.startedAt
		if t < CUT_END + DOCK_BACK then
			updateIntro(now, scene, current, cameraCFrame)
		else
			BenchVisual.place(scene, BenchVisual.lyingRoot(scene.anchor))
			if scene.cutterAt ~= nil then
				-- (once: the cutter is home, cold)
				BenchVisual.setCutter(scene, nil)
				BenchVisual.setWire(scene, 0)
			end
		end
		if now >= current.revealLocal and session == current then
			updateSelect(dt, now, scene, current, screen, cameraCFrame)
		end
		-- the server's end: the outro once every capsule that was used is shut
		local done = current.done
		if
			done
			and session == current
			and current.holding == nil
			and BenchVisual.isSettled(scene)
		then
			beginOutro(current, done)
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

-- Gamepad: the stick snaps the "pointer" to the next element in its direction.
local function snapTo(direction: Vector2)
	local current = session
	local scene = bench
	if current == nil or scene == nil or current.holding then
		return
	end
	local from = pointer
	local best: Vector2? = nil
	local bestScore = math.huge
	for index = 1, BenchVisual.elementCount(scene) do
		if BenchVisual.isFree(scene, index) then
			local at = project(BenchVisual.elementPoint(scene, index))
			local offset = at - from
			if offset.Magnitude > 4 then
				local along = offset.Unit:Dot(direction.Unit)
				if along > 0.3 then
					local score = offset.Magnitude * (2 - along)
					if score < bestScore then
						best, bestScore = at, score
					end
				end
			end
		end
	end
	if best == nil and current.hovered == nil then
		-- (nothing in that direction yet: start on the first free element)
		for index = 1, BenchVisual.elementCount(scene) do
			if BenchVisual.isFree(scene, index) then
				best = project(BenchVisual.elementPoint(scene, index))
				break
			end
		end
	end
	if best then
		pointer = best
	end
end

function ExtractionController.init()
	Remotes.ContrabandEvent.OnClientEvent:Connect(function(kind: string, data: any)
		if typeof(data) ~= "table" then
			return
		end
		if kind == "ExtractState" then
			onExtractState(data :: Types.ExtractStatePayload)
		elseif kind == "ExtractPicked" then
			onPicked(data)
		elseif kind == "ExtractDone" then
			onDone(data)
		end
	end)
end

function ExtractionController.start()
	-- (render is bound with BindToRenderStep while a session runs only: see bindRender)
	local touch: any = nil -- (the finger we follow)
	local stickReady = true
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if session == nil then
			return
		end
		-- (Backspace while typing in the chat must not stop the extraction)
		if
			input.KeyCode == Enum.KeyCode.Escape
			or (input.KeyCode == Enum.KeyCode.Backspace and not gameProcessed)
			or input.KeyCode == Enum.KeyCode.ButtonB
		then
			cancel()
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonX then
			finishNow()
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonA then
			pointerDown(pointer)
			return
		end
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseButton1
			or (kind == Enum.UserInputType.Touch and touch == nil)
		then
			local at = viewportPoint(input)
			if ui and ExtractionUI.isOverButtons(ui, at) then
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
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local stick = Vector2.new(input.Position.X, -input.Position.Y)
			if stick.Magnitude > 0.6 and stickReady then
				stickReady = false
				snapTo(stick)
			elseif stick.Magnitude < 0.3 then
				stickReady = true
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch and input == touch then
			touch = nil
			pointerUp()
		elseif kind == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonA then
			pointerUp()
		end
	end)

	-- Dying / respawning ends it here too (the server ends it on its side).
	player.CharacterRemoving:Connect(function()
		if session then
			stopLocal()
		end
	end)
end

return ExtractionController
