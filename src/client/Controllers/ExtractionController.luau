--!strict
-- ExtractionController: the extraction on YOUR screen (client only), v3: BY HAND.
--
-- The server runs the real thing (Server/Systems/Contraband/Extraction): it opens the session
-- (the vat's "Extract" prompt), rolls the culture's bio-elements, decides every score and
-- grade, checks the ORDER of the steps and the least time between them, and tells us with
-- "ExtractState" (step, elements and where each one is), "ExtractPicked" (a capsule's grade)
-- and "ExtractDone" (the end). We draw the scene and report finished steps and choices with
-- Remotes.ExtractAction(sessionId, action, arg?). No accuracy, speed or position is sent.
--
-- THE FLOW (the autopsy video's manual feel; never red, never an organ):
--   0  INTRO     hard cut to the trolley; the shell glides from the vat onto it; the gloved
--                hand comes in from the screen's right and hovers over the instrument tray.
--   1  SCALPEL   click it: the hand closes into a pen grip, lifts it, turns the blade down.
--   2  CUT       drag along the seam guide: it opens ONLY where the blade passes (12 cells).
--                Pass 1 = the skin (a dark split, cold teal light, milky beads); pass 2 = the
--                membrane (wet edges, a cold breath per cell). Off the guide = a scratch, no
--                cut; too fast = the blade skids; held still = one layer deeper there. When
--                11 of 12 cells are through, the rest zips open by itself. After the membrane:
--                the seam pops, the full cold breath, the hand lays the scalpel back (the only
--                automatic beat, short).
--   3  SPREAD    drag each panel outward against an elastic pull (it trembles, it gets
--                harder); let go before 60 % = it springs back; past 60 % = it opens fully and
--                the hand snaps a retractor clip on its rim. Touch: a two-finger pinch-out
--                opens both. Both open: the elements light up one by one; the cooling bar.
--   4  PULL      press on an element and drag away: it resists, trembles, 3 milky strands
--                stretch; after 0.5 s of pull (or a long pull) it comes free softly (the
--                strands thin, sag and retract; a milky drop falls back and stays). Let go
--                early: it settles back. A husk has no tension at all (a warning).
--   5  CARRY     it hangs in the glove (lag + pendulum tilt). Let go over the steel specimen
--                tray: it settles, drains into the channel, the CRT reads it. Over the
--                trolley: it is set down there. Over the open chest: back in its nest.
--                Elsewhere: the hand keeps it.
--   6  TRANSFER  pick it up from the tray, bring it to the pass-box: the lid opens by itself,
--                cold mist rolls out; let go over the grate: the grate parts, it drops into
--                an open capsule seen through the window, the cap seals, frost, the grade LED
--                (amber until the server answers), the carousel turns it into the cold well,
--                the grate and lid close, the strip display counts it. Never a vanish.
--   7  OUTRO     all capsules sealed / DONE / cooling over / Stop after a seal: the camera
--                looks into the well, the inner shutter closes in shot, "2/2 STORED", the
--                result card, the shell slides down the chute, the camera comes back.
--
-- TIMING (roblox-animation skill): the pointer drives springs (frame-rate independent:
-- x += (goal - x) * (1 - 2^(-dt / halfLife))); authored beats (taking the scalpel, laying it
-- back, the clip, setting down, the transfer) are timelines on the scene's own clock; every
-- sound plays on the local frame of its gesture, never on a server reply, except the grade
-- LED, which IS the server's answer. Messages go out through a small queue that keeps them in
-- order and never earlier than the server's least times (Config.Extraction.MIN).
--
-- Controls: mouse (press / drag / release), touch (one finger; two-finger pinch-out spreads),
-- gamepad (left stick = a virtual cursor, A = press, X = DONE, B = STOP). Backspace / STOP
-- stops it (not Esc: Esc opens the Roblox menu); before any seal the vat stays READY with the
-- SAME elements. H hides the hint.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local BenchLayout = require(ReplicatedStorage.Shared.Contraband.BenchLayout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Contraband = script.Parent.Parent.Contraband
local BenchHand = require(Contraband.BenchHand)
local BenchVisual = require(Contraband.BenchVisual)
local ExtractionUI = require(Contraband.ExtractionUI)
local PassBox = require(Contraband.PassBox)

local CameraController = require(script.Parent.CameraController)
local LabController = require(script.Parent.LabController)
local SoundController = require(script.Parent.SoundController)

local E = Config.Extraction
local MIN = E.MIN
local player = Players.LocalPlayer

local ExtractionController = {}

local RENDER_NAME = "ExtractionScene"
local SLIDE_TIME = 0.9 -- the shell from the vat to the trolley
local INTRO_TIME = 1.2 -- then the scalpel can be taken
local STAGGER = 0.08 -- elements light up one by one
local LAG = 0.08 -- s of slack added to the server's least times (network jitter)
local PICK_RADIUS = 0.07 -- of the viewport height: how close the pointer must be to a thing
local TOOL_RADIUS = 44 -- px: the scalpel / clip hit area is never smaller (touch)
local LOW_TIME = 5 -- the last seconds of the cooling bar
local CARRY_HEIGHT = 0.75 -- the carry plane above the trolley top (anchor space)
local PANEL_REACH = 0.25 -- studs from the seam a panel can be grabbed
local GLIDE = 0.18 -- s: the camera's half-life between framings
local CARD_AT = 1.4 -- outro: the result card
local CHUTE_START = 1.8
local CHUTE_TIME = 3
local CAMERA_OUT_AT = 4.4
local CAMERA_OUT = 0.6

type Framing = { position: Vector3, look: Vector3, fov: number }
-- The three authored shots (anchor space). WORK covers the instrument tray (screen right),
-- the chest and the specimen tray (screen left); TRANSFER the tray, the pass-box grate from
-- above and its window; WELL looks into the window. (Checked in Blender renders.)
local FRAMINGS: { [string]: Framing } = {
	Work = {
		position = Vector3.new(0.1, 4.3, -2.5),
		look = Vector3.new(-0.15, 0.35, -0.25),
		fov = 40,
	},
	Transfer = {
		position = Vector3.new(2.4, 3.3, -3.4),
		look = Vector3.new(3.4, -0.25, -0.6),
		fov = 40,
	},
	Well = {
		position = Vector3.new(4.05, -0.55, -3.5),
		look = Vector3.new(4.2, -1.05, -0.6),
		fov = 34,
	},
}

local KIND_NAMES: { [string]: string } = {
	Cluster = "CLUSTER",
	Pod = "POD",
	Coil = "COIL",
	Husk = "NO SIGNAL",
}

local HINTS = {
	Tool = "Pick up the scalpel.",
	Skin = "Drag along the seam.",
	Membrane = "Again, through the membrane.",
	Spread = "Pull the panels open.",
	Grab = "Grab an element and pull it free.",
	ToTray = "Set it in the steel tray.",
	ToBox = "Lift it into the cold box.",
	Next = "Next element, or DONE.",
}

-- A scripted beat of the hand (timelines on the scene's clock).
type Beat = {
	name: string,
	start: number,
	duration: number,
	from: CFrame, -- the hand's grip at the start
	data: { [string]: any },
}

type Pull = {
	index: number,
	grab: Vector3,
	tension: number,
	freed: boolean,
	shakeAt: number,
	shake: Vector3,
}

type Session = {
	id: number,
	slots: number,
	elements: { Types.ExtractElement },
	states: { Types.ElementState }, -- the local mirror
	startedAt: number,
	step: "Intro" | "Tool" | "Incise" | "Spread" | "Harvest",
	layer: number, -- seam layers done (0..2)
	zip: { layer: number, next: number, at: number }?,
	stroke: number,
	cellStroke: { number }, -- the last stroke that cut each cell (one layer per cell per stroke)
	strokeCells: number, -- cells cut in this stroke (a slice sound every 3)
	cutFrom: { s: number, e: number, world: Vector3, t: number }?,
	stillSince: number,
	stillAt: Vector3?,
	speed: number,
	scratchFrom: Vector3?,
	skidAt: number,
	squeakAt: number,
	spread: { boolean },
	panelDrag: { side: number, startE: number, open: number }?,
	pinch: { d0: number }?,
	panelAnim: { side: number, from: number, to: number, start: number, back: boolean }?,
	clips: { CFrame? }, -- each clip's world pose once on its panel (nil = on the tray)
	coolEnds: number?, -- os.clock()
	pull: Pull?,
	held: number?,
	heldFromTray: boolean,
	carry: { position: Vector3, velocity: Vector3, tilt: Vector3, lower: number, beadAt: number }?,
	settle: { index: number, from: CFrame, to: CFrame, start: number }?,
	letBack: { index: number, from: Vector3, start: number }?,
	trayOf: { [number]: number }, -- element → tray place (1..2)
	looseAt: { [number]: CFrame },
	sealed: number,
	hovered: number?,
	hoverSince: number,
	scanned: number?,
	litCount: number,
	litStart: number?,
	beat: Beat?,
	lastLowTick: number,
	dripAt: number,
	endSent: boolean,
	done: Types.ExtractDonePayload?,
	outroStart: number?,
	outroEvents: { [string]: boolean },
	framing: string,
	pushIn: number,
	swayOffUntil: number,
}

type Queued = { action: string, arg: number?, at: number }

local session: Session? = nil
local bench: BenchVisual.Bench? = nil
local hand: BenchHand.Hand? = nil
local scalpel: BenchHand.Tool? = nil
local scalpelModel: Model? = nil
local clips: { BenchHand.Tool } = {}
local passBox: PassBox.Box? = nil
local sceneFolder: Folder? = nil
local ui: ExtractionUI.UI? = nil
local pointer: Vector2 = Vector2.zero
local pressing = false
local touches: { [InputObject]: Vector2 } = {}
local stick = Vector2.zero
local strainLoop: Sound? = nil
local stretchLoop: Sound? = nil
local queue: { Queued } = {}
local projected: { [string]: number } = {}
local sent = 0
local savedCamera: { offset: CFrame?, cframe: CFrame, fov: number }? = nil
local cameraNow: { position: Vector3, look: Vector3, fov: number }? = nil
local cameraOut: { from: CFrame, fov: number, start: number }? = nil
local vatRoot: CFrame? = nil
local bound = false
local hiddenParts: { Instance } = {}
local hideConnection: RBXScriptConnection? = nil
local screenGui: SurfaceGui? = nil
local screenLines: { TextLabel } = {}

-- (the hand's grip point and the scalpel tip, smoothed)
local handGrip: CFrame = CFrame.identity
local tipNow: Vector3? = nil

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

-- Frame-rate independent spring step: how much of the way to go this frame.
local function follow(dt: number, halfLife: number): number
	return 1 - 2 ^ (-dt / math.max(halfLife, 1e-3))
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

local function stopLoop(sound: Sound?)
	if sound then
		sound:Stop()
		sound:Destroy()
	end
end

local function play(name: string, pitch: number?): Sound?
	local sound = SoundController.play2D(name)
	if sound and pitch then
		sound.PlaybackSpeed *= pitch
	end
	return sound
end

local function hint(text: string)
	if ui then
		ExtractionUI.setHint(ui, text)
	end
end

local function status(text: string)
	if ui then
		ExtractionUI.status(ui, text)
	end
end

------------------------------------------------------------------------------
-- Messages to the server (in order, never before its least times)
------------------------------------------------------------------------------

-- Queues `action` (`arg`), at the earliest `gap` s after the projected send of `after` (the
-- server measures the same gap on its own clock).
type Rule = { ref: string, gap: number }

local function queueSend(action: string, arg: number?, after: { Rule }?)
	local now = os.clock()
	local at = now
	local last = queue[#queue]
	if last then
		at = math.max(at, last.at)
	end
	if after then
		for _, rule in after do
			local ref = projected[rule.ref]
			if ref then
				at = math.max(at, ref + rule.gap + LAG)
			end
		end
	end
	table.insert(queue, { action = action, arg = arg, at = at })
	projected[action] = at
	if arg ~= nil then
		projected.Hand = at -- (every element message: the server's "last hand action")
	end
end

local function flushQueue(now: number)
	local current = session
	while queue[1] and queue[1].at <= now do
		local item = table.remove(queue, 1) :: Queued
		if current then
			Remotes.ExtractAction:FireServer(current.id, item.action, item.arg)
			sent += 1
		end
	end
end

-- Stop / Done go out at once (after whatever is queued, so the order holds).
local function sendNow(action: string)
	local current = session
	if current == nil then
		return
	end
	for _, item in queue do
		Remotes.ExtractAction:FireServer(current.id, item.action, item.arg)
		sent += 1
	end
	table.clear(queue)
	Remotes.ExtractAction:FireServer(current.id, action, nil)
	sent += 1
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
	cameraNow = nil
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
	cameraNow = nil
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
-- The CRT (ScanScreen) and the work lamp
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
	gui.Brightness = 1
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
		line.Position = UDim2.new(0.08, 0, 0.1 + (k - 1) * 0.28, 0)
		line.Size = UDim2.new(0.84, 0, 0.22, 0)
		line.Font = Enum.Font.RobotoMono
		line.TextScaled = true
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = SCREEN_TEXT
		line.Text = ""
		line.Parent = back
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 34
		limit.Parent = line
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

local function readOut(element: Types.ExtractElement)
	local husk = element.kind == "Husk"
	screenText(
		KIND_NAMES[element.kind] or "?",
		if husk then "--" else string.upper(element.condition),
		if husk then "..." else barText(element.viability)
	)
end

-- The work lamp over the trolley is dimmed a little during the close-up (the pale shell
-- would clip to white under it), and put back after.
local LAMP_EXTRACT_BRIGHTNESS = 1.0
local dimmedLamp: { light: SpotLight, brightness: number }? = nil

local function setLampDimmed(dim: boolean)
	if dim then
		local parts = LabController.parts()
		local head = if parts then parts.model:FindFirstChild("LampHead", true) else nil
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
	if passBox then
		PassBox.destroy(passBox)
		passBox = nil
	end
	local current = bench
	bench = nil
	if current then
		BenchVisual.destroy(current)
	end
	if sceneFolder then
		sceneFolder:Destroy()
		sceneFolder = nil
	end
	hand = nil
	scalpel = nil
	scalpelModel = nil
	table.clear(clips)
	session = nil
	pressing = false
	table.clear(queue)
	table.clear(projected)
	stopLoop(strainLoop)
	strainLoop = nil
	stopLoop(stretchLoop)
	stretchLoop = nil
	bindRender(false)
	if ui then
		ExtractionUI.show(ui, false)
	end
	if savedCamera then
		giveCameraBack()
	end
	hideOwnBody(false)
	LabController.setCloneHidden(false)
	setLampDimmed(false)
	UserInputService.MouseIconEnabled = true
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

-- STOP / Backspace: before any seal it ends at once (the vat stays READY, same elements);
-- after a seal the server ends it and the outro shows what was stored.
local function cancel()
	local current = session
	if current == nil or current.done or current.endSent then
		return
	end
	SoundController.play2D("UiCancel")
	if current.sealed == 0 then
		sendNow("Stop")
		stopLocal()
		return
	end
	current.endSent = true
	sendNow("Stop")
end

local function finishNow()
	local current = session
	if current == nil or current.done or current.endSent then
		return
	end
	if current.sealed == 0 or (passBox and PassBox.busy(passBox)) then
		SoundController.play2D("UiError")
		return
	end
	SoundController.play2D("UiConfirm")
	current.endSent = true
	sendNow("Done")
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

local STATES: { [string]: boolean } =
	{ Nest = true, Pulling = true, Held = true, Loose = true, OnTray = true, Sealed = true }

local function stateOf(value: any): Types.ElementState
	if typeof(value) == "string" and STATES[value] then
		return value :: any
	end
	return "Nest"
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
				state = stateOf(item.state),
			})
		end
	end
	return out
end

-- The static bench kit of our lab (BenchLayout.buildStatic), if the lab has one.
local function findKit(parts: any): Model?
	local found = parts.model:FindFirstChild("BenchKit", true)
	return if found and found:IsA("Model") then found else nil
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
	local slots = math.clamp(math.floor(tonumber(data.slots) or 1), 1, E.CAPSULES)
	local states: { Types.ElementState } = {}
	for index, element in elements do
		states[index] = element.state or "Nest"
	end
	session = {
		id = data.sessionId,
		slots = slots,
		elements = elements,
		states = states,
		startedAt = now,
		step = "Intro",
		layer = 0,
		zip = nil,
		stroke = 0,
		cellStroke = table.create(BenchVisual.CELLS, 0),
		strokeCells = 0,
		cutFrom = nil,
		stillSince = now,
		stillAt = nil,
		speed = 0,
		scratchFrom = nil,
		skidAt = 0,
		squeakAt = 0,
		spread = { false, false },
		panelDrag = nil,
		pinch = nil,
		panelAnim = nil,
		clips = { nil, nil },
		coolEnds = nil,
		pull = nil,
		held = nil,
		heldFromTray = false,
		carry = nil,
		settle = nil,
		letBack = nil,
		trayOf = {},
		looseAt = {},
		sealed = 0,
		hovered = nil,
		hoverSince = 0,
		scanned = nil,
		litCount = 0,
		litStart = nil,
		beat = nil,
		lastLowTick = 0,
		dripAt = 0,
		endSent = false,
		done = nil,
		outroStart = nil,
		outroEvents = {},
		framing = "Work",
		pushIn = 0,
		swayOffUntil = 0,
	}
	sent = 0
	table.clear(queue)
	table.clear(projected)
	projected.Start = now
	local anchor = parts.benchAnchor.CFrame
	local folder = Instance.new("Folder")
	folder.Name = "ExtractionScene"
	folder.Parent = LabController.visuals()
	sceneFolder = folder
	local kit = findKit(parts)
	local scene = BenchVisual.new(anchor, folder, elements, kit == nil)
	bench = scene
	local box = PassBox.new(kit or scene.kit, anchor, folder, slots)
	passBox = box
	-- the hand and the instruments (the static rest copies are hidden while we play ours)
	hand = BenchHand.new(folder)
	local model = Instance.new("Model")
	model.Name = "Scalpel"
	model.Parent = folder
	scalpelModel = model
	local tool = BenchHand.newTool(model, BenchLayout.SCALPEL :: any)
	BenchHand.placeTool(tool, anchor * BenchLayout.SCALPEL_REST)
	BenchHand.showTool(tool, true)
	scalpel = tool
	for k, rest in BenchLayout.CLIP_RESTS do
		local clip = BenchHand.newTool(folder, BenchLayout.CLIP :: any)
		BenchHand.placeTool(clip, anchor * rest)
		BenchHand.showTool(clip, true)
		clips[k] = clip
	end
	handGrip = BenchHand.frame(anchor * Vector3.new(-3.6, 1.6, -2.4), anchor, 20)
	tipNow = nil
	vatRoot = parts.vatCore.CFrame
	LabController.setCloneHidden(true)
	setLampDimmed(true)
	buildScreen(parts.scanScreen)
	screenText("SCAN", "--", "")
	local screen = ensureUI()
	ExtractionUI.show(screen, true)
	ExtractionUI.setHint(screen, "")
	ExtractionUI.setCooling(screen, nil, false)
	ExtractionUI.setDone(screen, false, false)
	takeCamera()
	hideOwnBody(true)
	bindRender(true)
end

------------------------------------------------------------------------------
-- Server messages
------------------------------------------------------------------------------

-- The server's state for our session: the cooling bar, and a resync when it disagrees with
-- what we show (it refused something). Only when it has handled every message we sent: a
-- state sent before our last messages arrived would be out of date.
local function resync(current: Session, data: Types.ExtractStatePayload)
	if typeof(data.coolEnds) == "number" then
		current.coolEnds = os.clock() + (data.coolEnds - workspace:GetServerTimeNow())
	end
	if typeof(data.acked) ~= "number" or data.acked < sent or #queue > 0 then
		return
	end
	local scene = bench
	if scene == nil then
		return
	end
	-- steps the server is missing (a refused step message): send them again, in order
	local step = data.step
	if step == "Intro" and current.step ~= "Intro" and current.step ~= "Tool" then
		queueSend("Tool", nil, { { ref = "Start", gap = MIN.Tool } })
	end
	local layer = if typeof(data.layer) == "number" then data.layer else 0
	for missing = layer + 1, current.layer do
		queueSend(
			"Layer",
			missing,
			{ { ref = "Tool", gap = MIN.Layer1 }, { ref = "Layer", gap = MIN.Layer2 } }
		)
	end
	local spread = if typeof(data.spread) == "table" then data.spread else {}
	for side = 1, 2 do
		if current.spread[side] and spread[side] ~= true then
			queueSend(
				"Spread",
				side,
				{ { ref = "Layer", gap = MIN.Spread }, { ref = "Spread", gap = MIN.SpreadGap } }
			)
		end
	end
	-- elements the server holds somewhere else: snap ours to its state
	local list = readElements(data.elements)
	for index, element in list do
		local server: Types.ElementState = element.state or "Nest"
		local mine = current.states[index]
		if mine == nil or mine == server or mine == "Sealed" then
			continue
		end
		if current.held == index then
			current.held = nil
			current.carry = nil
		end
		if current.pull and current.pull.index == index then
			current.pull = nil
			stopLoop(strainLoop)
			strainLoop = nil
		end
		if server == "Held" or server == "Pulling" then
			-- (the server thinks it is in our hand: give it back to the nest there too)
			queueSend("Let", index, nil)
			server = "Nest"
		end
		current.states[index] = server
		if server == "Nest" then
			BenchVisual.setPull(scene, index, Vector3.zero)
		elseif server == "OnTray" then
			local place = current.trayOf[index] or 1
			current.trayOf[index] = place
			local st = BenchLayout.SPECIMEN_TRAY
			local at = scene.anchor
				* CFrame.new(
					st.centre.X - 0.22 + (place - 1) * 0.42,
					BenchLayout.MAT_TOP + BenchVisual.halfHeight(scene, index),
					st.centre.Z
				)
				* CFrame.Angles(0, 0, math.rad(90))
			BenchVisual.setFree(scene, index, at)
		elseif server == "Loose" then
			local at = current.looseAt[index]
				or scene.anchor
					* CFrame.new(2.9, BenchVisual.halfHeight(scene, index), -0.6)
					* CFrame.Angles(0, 0, math.rad(90))
			current.looseAt[index] = at
			BenchVisual.setFree(scene, index, at)
		end
	end
	status("")
end

local function onExtractState(data: Types.ExtractStatePayload)
	local current = session
	if not data.active then
		-- (the server ended it with no seal: Stop, time out, left the lab...)
		if current and current.done == nil then
			stopLocal()
		end
		return
	end
	if current == nil or current.id ~= data.sessionId then
		begin(data)
		return
	end
	resync(current, data)
end

local function onPicked(data: any)
	local current = session
	local box = passBox
	if current == nil or box == nil or typeof(data.slot) ~= "number" then
		return
	end
	local grade = data.grade
	PassBox.answer(
		box,
		data.slot,
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
-- Picking things on screen
------------------------------------------------------------------------------

local function near(world: Vector3, radius: number?): (boolean, number)
	local at, visible = project(world)
	local distance = (at - pointer).Magnitude
	local limit = radius or math.max(PICK_RADIUS * viewportHeight(), TOOL_RADIUS)
	return visible and distance <= limit, distance
end

-- The element under the pointer that can be grabbed / lifted now, or nil.
local function elementAt(current: Session, scene: BenchVisual.Bench): number?
	local best: number? = nil
	local bestDistance = math.huge
	for index = 1, BenchVisual.elementCount(scene) do
		local state = current.states[index]
		if state == "Nest" or state == "OnTray" or state == "Loose" then
			local ok, distance = near(
				BenchVisual.elementCFrame(scene, index).Position,
				PICK_RADIUS * viewportHeight()
			)
			if ok and distance < bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	return best
end

local function countState(current: Session, state: Types.ElementState): number
	local n = 0
	for _, value in current.states do
		if value == state then
			n += 1
		end
	end
	return n
end

local function camera(): CFrame
	local cam = workspace.CurrentCamera
	return if cam then cam.CFrame else CFrame.identity
end

------------------------------------------------------------------------------
-- Beats (authored timelines of the hand)
------------------------------------------------------------------------------

local function startBeat(current: Session, name: string, duration: number, data: { [string]: any }?)
	current.beat =
		{ name = name, start = os.clock(), duration = duration, from = handGrip, data = data or {} }
end

-- An arc from a to b (t 0..1, smoothed) that lifts `height` at mid-path.
local function arc(a: CFrame, b: CFrame, t: number, height: number): CFrame
	local s = smooth(t)
	return a:Lerp(b, s) + Vector3.new(0, math.sin(s * math.pi) * height, 0)
end

-- The scalpel in the pen grip, its tip at `tip` (world), leaning back toward the arm (35°),
-- the edge down.
local function scalpelPose(tip: Vector3, scene: BenchVisual.Bench, extraLean: number?): CFrame
	local up = scene.anchor.UpVector
	local arm = BenchHand.armDirection(tip, camera())
	local lean = math.rad(35 + (extraLean or 0))
	local handle = (arm * math.cos(lean) + up * math.sin(lean)).Unit
	local down = (-up - handle * (-up):Dot(handle)).Unit
	local y = handle:Cross(down)
	return CFrame.fromMatrix(tip, down, y, handle)
end

-- Where the hand's grip sits for a scalpel at `pose`.
local function handOnScalpel(pose: CFrame): CFrame
	return pose * BenchHand.PEN_FROM_TIP
end

local function handOnClip(pose: CFrame): CFrame
	return pose * BenchHand.CLIP_FROM_TOOL * CFrame.Angles(0, math.pi, 0)
end

------------------------------------------------------------------------------
-- Steps
------------------------------------------------------------------------------

local function lightElements(current: Session, now: number)
	current.litStart = now
end

local function enterHarvest(current: Session)
	current.step = "Harvest"
	hint(HINTS.Grab)
	play("PanelsOpen")
	lightElements(current, os.clock())
	screenText("SCAN", "HOVER", "")
	-- (the server starts the cooling bar on the second panel; until its state arrives, ours)
	current.coolEnds = os.clock() + E.COOL_TIME
end

-- A seam layer is through (all 12 cells): tell the server; after the membrane, the release.
local function layerDone(current: Session, scene: BenchVisual.Bench, layer: number)
	current.layer = layer
	if layer == 1 then
		queueSend("Layer", 1, { { ref = "Tool", gap = MIN.Layer1 } })
		hint(HINTS.Membrane)
		status("Skin open — again through the membrane.")
		play("ScalpelPress", 0.9)
		return
	end
	queueSend("Layer", 2, { { ref = "Layer", gap = MIN.Layer2 } })
	-- the panels give a little, the seam pops, the full cold breath spills out
	BenchVisual.setPanel(scene, 1, 0.012, 0)
	BenchVisual.setPanel(scene, 2, 0.012, 0)
	BenchVisual.breath(scene, 10)
	play("SeamPop")
	play("ColdBreath")
	-- the hand lays the scalpel back on its tray (the only automatic beat)
	startBeat(current, "ScalpelBack", 0.75)
	current.step = "Spread"
end

-- The cut, every frame while the scalpel is pressed on the chest.
local function updateCut(
	current: Session,
	scene: BenchVisual.Bench,
	now: number,
	dt: number,
	tip: Vector3
)
	local s, e = BenchVisual.toSeam(scene, tip)
	local from = current.cutFrom
	if from == nil then
		current.cutFrom = { s = s, e = e, world = tip, t = now }
		return
	end
	local moved = (tip - from.world).Magnitude
	current.speed += (moved / math.max(dt, 1e-3) - current.speed) * follow(dt, 0.05)
	local target = current.layer + 1
	if math.abs(e) > E.SEAM_TOLERANCE then
		-- off the guide: a pale scratch, a squeak, no cut
		local start = current.scratchFrom or from.world
		current.scratchFrom = start
		if (tip - start).Magnitude > 0.1 then
			if BenchVisual.scratch(scene, start, tip) and now - current.squeakAt > 0.33 then
				current.squeakAt = now
				play("ScalpelSkid", 1.2)
				status("Stay on the seam.")
			end
			current.scratchFrom = tip
		end
	elseif current.speed > E.SKID_SPEED and moved > 0.002 then
		-- too fast: the blade skids (no cut), the hand chatters
		current.scratchFrom = nil
		if now - current.skidAt > 0.33 then
			current.skidAt = now
			play("ScalpelSkid")
			status("Too fast — the blade skids.")
		end
	else
		current.scratchFrom = nil
		-- every cell crossed since the last frame gets one layer deeper (once per stroke)
		local a = math.clamp(math.floor(math.min(from.s, s)) + 1, 1, BenchVisual.CELLS)
		local b = math.clamp(math.floor(math.max(from.s, s)) + 1, 1, BenchVisual.CELLS)
		if s >= 0 and s <= BenchVisual.CELLS or from.s >= 0 and from.s <= BenchVisual.CELLS then
			for k = a, b do
				if current.cellStroke[k] ~= current.stroke then
					local depth = BenchVisual.cellDepth(scene, k)
					if depth < target and BenchVisual.cutCell(scene, k, depth + 1) then
						current.cellStroke[k] = current.stroke
						current.strokeCells += 1
						if target == 1 and current.strokeCells % 3 == 1 then
							play("ScalpelSkin", if current.strokeCells % 2 == 0 then 1.06 else 0.94)
						elseif target == 2 then
							play("ScalpelMembrane", if k % 2 == 0 then 1.06 else 0.94)
							BenchVisual.breath(
								scene,
								1,
								BenchVisual.seamPoint(scene, k - 0.5, 0, 0.05),
								0.08
							)
						end
					end
				end
			end
		end
		-- held still on the seam: one layer deeper right there
		local still = current.stillAt
		if still == nil or (tip - still).Magnitude > 0.03 then
			current.stillAt = tip
			current.stillSince = now
		elseif now - current.stillSince >= E.DEEPEN_HOLD then
			current.stillSince = now
			local k = math.clamp(math.floor(s) + 1, 1, BenchVisual.CELLS)
			local depth = BenchVisual.cellDepth(scene, k)
			if
				s >= 0
				and s <= BenchVisual.CELLS
				and depth < target
				and BenchVisual.cutCell(scene, k, depth + 1)
			then
				play("ScalpelPress")
			end
		end
	end
	current.cutFrom = { s = s, e = e, world = tip, t = now }
	-- the layer: 11 of 12 cells through = the rest zips open by itself
	if current.zip == nil then
		local through = 0
		for k = 1, BenchVisual.CELLS do
			if BenchVisual.cellDepth(scene, k) >= target then
				through += 1
			end
		end
		if through >= BenchVisual.CELLS - 1 then
			current.zip = { layer = target, next = 1, at = now }
		end
	end
end

-- The zip: the last cells open one by one (60 ms each), then the layer is done.
local function updateZip(current: Session, scene: BenchVisual.Bench, now: number)
	local zip = current.zip
	if zip == nil then
		return
	end
	while zip.next <= BenchVisual.CELLS and now >= zip.at do
		local k = zip.next
		zip.next += 1
		if BenchVisual.cellDepth(scene, k) < zip.layer then
			BenchVisual.cutCell(scene, k, zip.layer)
			zip.at = now + 0.06
			if zip.layer == 2 then
				BenchVisual.breath(scene, 1, BenchVisual.seamPoint(scene, k - 0.5, 0, 0.05), 0.08)
			end
			break
		end
	end
	if zip.next > BenchVisual.CELLS and now >= zip.at then
		current.zip = nil
		layerDone(current, scene, zip.layer)
	end
end

------------------------------------------------------------------------------
-- Pointer events
------------------------------------------------------------------------------

local function pointerDown()
	local current = session
	local scene = bench
	if current == nil or scene == nil or current.done or current.endSent or current.outroStart then
		return
	end
	pressing = true
	if current.beat or current.settle then
		return
	end
	local now = os.clock()
	if current.step == "Tool" then
		-- (the hit area: the scalpel's middle, at least 44 px around it)
		if
			scalpel
			and near((scene.anchor * BenchLayout.SCALPEL_REST * CFrame.new(0, 0, 0.35)).Position)
		then
			startBeat(current, "ScalpelPick", 0.5)
			current.step = "Incise"
			hint("")
		end
		return
	end
	if current.step == "Incise" then
		current.stroke += 1
		current.strokeCells = 0
		current.cutFrom = nil
		current.scratchFrom = nil
		current.stillSince = now
		current.speed = 0
		return
	end
	if current.step == "Spread" then
		local origin, normal = BenchVisual.chestPlane(scene)
		local hit = onPlane(pointer, origin, normal)
		local side = if hit then BenchVisual.panelAt(scene, hit, PANEL_REACH) else nil
		if hit and side and not current.spread[side] and current.panelAnim == nil then
			local _, e = BenchVisual.toSeam(scene, hit)
			current.panelDrag = { side = side, startE = e, open = 0 }
			stopLoop(stretchLoop)
			stretchLoop = SoundController.loop("PanelStretch")
			if stretchLoop then
				stretchLoop:Play()
			end
		end
		return
	end
	if current.step ~= "Harvest" or current.held or current.pull then
		return
	end
	local index = elementAt(current, scene)
	if index == nil then
		return
	end
	local state = current.states[index]
	local element = current.elements[index]
	if state == "Nest" then
		local busy = current.sealed + countState(current, "OnTray")
		if busy >= current.slots then
			status("No capsule left.")
			play("UiError")
			return
		end
		current.states[index] = "Pulling"
		current.pull = {
			index = index,
			grab = BenchVisual.nestCFrame(scene, index).Position,
			tension = 0,
			freed = false,
			shakeAt = 0,
			shake = Vector3.zero,
		}
		queueSend("Grab", index, { { ref = "Hand", gap = MIN.Grab } })
		BenchVisual.grab(scene, index)
		play("CorePickup")
		if element.kind ~= "Husk" then
			stopLoop(strainLoop)
			strainLoop = SoundController.loop("ElementStrain")
			if strainLoop then
				strainLoop:Play()
			end
		end
	else
		-- lift it again (from the tray or the trolley): no tension now
		current.heldFromTray = state == "OnTray"
		current.trayOf[index] = nil
		current.looseAt[index] = nil
		current.states[index] = "Held"
		current.held = index
		local at = BenchVisual.elementCFrame(scene, index)
		current.carry = {
			position = at.Position,
			velocity = Vector3.zero,
			tilt = Vector3.zero,
			lower = 0,
			beadAt = now,
		}
		queueSend("Lift", index, { { ref = "Hand", gap = MIN.Lift } })
		play("CorePickup")
		readOut(element)
		hint(if current.heldFromTray then HINTS.ToBox else HINTS.ToTray)
	end
end

-- Where a set-down element rests (anchor space → world), or nil if it can't go there.
local function dropTarget(
	current: Session,
	scene: BenchVisual.Bench,
	index: number,
	at: Vector3
): (string?, CFrame?, number?)
	local p = scene.anchor:PointToObjectSpace(at)
	local half = BenchVisual.halfHeight(scene, index)
	local lying = CFrame.Angles(0, 0, math.rad(90))
	-- the specimen tray (two places)
	local st = BenchLayout.SPECIMEN_TRAY
	if
		math.abs(p.X - st.centre.X) <= st.size.X / 2 + 0.05
		and math.abs(p.Z - st.centre.Z) <= st.size.Z / 2 + 0.08
	then
		if countState(current, "OnTray") >= 2 then
			return "Full", nil, nil
		end
		local place = 1
		for _, used in current.trayOf do
			if used == 1 then
				place = 2
			end
		end
		local x = st.centre.X - 0.22 + (place - 1) * 0.42
		return "Tray",
			scene.anchor * CFrame.new(x, BenchLayout.MAT_TOP + half, st.centre.Z) * lying,
			place
	end
	-- the pass-box grate
	local grate = BenchLayout.GRATE_CENTRE
	if Vector2.new(p.X - grate.X, p.Z - grate.Z).Magnitude <= BenchLayout.GRATE_RADIUS + 0.1 then
		return "Grate",
			scene.anchor * CFrame.new(grate.X, grate.Y + 0.01 + half, grate.Z) * lying,
			nil
	end
	-- over the open chest: back in its nest
	if BenchVisual.overOpening(scene, at) then
		return "Nest", nil, nil
	end
	-- the trolley top, away from the shell and the instrument tray
	local top = BenchLayout.TOP
	local inside = p.X > top.x0 + 0.2
		and p.X < top.x1 - 0.2
		and p.Z > top.z0 + 0.15
		and p.Z < top.z1 - 0.15
	local onShell = (
		p.X > -3.1
		and p.X < 1.1
		and math.abs(p.Z) < 2.05
		and (math.abs(p.Z) < 1.05 or p.X > -1.1)
	) or (p.X >= 1.0 and p.X < 2.3 and math.abs(p.Z) < 0.7)
	local it = BenchLayout.INSTRUMENT_TRAY
	local onInstruments = math.abs(p.X - it.centre.X) < it.size.X / 2 + 0.15
		and math.abs(p.Z - it.centre.Z) < it.size.Z / 2 + 0.15
	if inside and not onShell and not onInstruments then
		return "Loose", scene.anchor * CFrame.new(p.X, half + 0.002, p.Z) * lying, nil
	end
	return nil, nil, nil
end

local function pointerUp()
	pressing = false
	local current = session
	local scene = bench
	if current == nil or scene == nil then
		return
	end
	stopLoop(stretchLoop)
	stretchLoop = nil
	current.cutFrom = nil
	-- a panel let go: springs back (< 60 %) or finishes and gets a clip
	local drag = current.panelDrag
	if drag then
		current.panelDrag = nil
		if drag.open >= E.PANEL_LATCH then
			current.panelAnim = {
				side = drag.side,
				from = drag.open * 0.7,
				to = 1,
				start = os.clock(),
				back = false,
			}
		else
			current.panelAnim = {
				side = drag.side,
				from = drag.open * 0.7,
				to = 0,
				start = os.clock(),
				back = true,
			}
		end
		return
	end
	-- an element pulled but not free yet: it settles back into its nest
	local pull = current.pull
	if pull and not pull.freed then
		current.pull = nil
		current.states[pull.index] = "Nest"
		current.letBack = {
			index = pull.index,
			from = BenchVisual.elementCFrame(scene, pull.index).Position
				- BenchVisual.nestCFrame(scene, pull.index).Position,
			start = os.clock(),
		}
		queueSend("Let", pull.index, nil)
		BenchVisual.releaseStrands(scene, pull.index, false)
		stopLoop(strainLoop)
		strainLoop = nil
		return
	end
	-- an element in the hand: set it down where it is over
	local index = current.held
	local carry = current.carry
	if index == nil or carry == nil or current.beat then
		return
	end
	local kind, rest, place = dropTarget(current, scene, index, carry.position)
	if kind == "Tray" and rest then
		current.held = nil
		current.carry = nil
		current.states[index] = "OnTray"
		current.trayOf[index] = place or 1
		current.settle = {
			index = index,
			from = BenchVisual.elementCFrame(scene, index),
			to = rest,
			start = os.clock(),
		}
		queueSend("Tray", index, { { ref = "Hand", gap = MIN.Tray } })
		hint(if current.sealed > 0 then HINTS.Next else HINTS.ToBox)
	elseif kind == "Full" then
		status("The tray is full.")
		play("UiError")
	elseif kind == "Grate" and rest then
		if not current.heldFromTray then
			status("Set it in the steel tray first.")
			play("ToolTraySetDown", 0.6)
			return
		end
		local box = passBox
		if box == nil or PassBox.busy(box) or current.sealed >= current.slots then
			status("No capsule left.")
			play("UiError")
			return
		end
		current.held = nil
		current.carry = nil
		startBeat(
			current,
			"Transfer",
			0.15,
			{ index = index, from = BenchVisual.elementCFrame(scene, index), to = rest }
		)
	elseif kind == "Nest" then
		current.held = nil
		current.carry = nil
		current.states[index] = "Nest"
		current.letBack = {
			index = index,
			from = BenchVisual.elementCFrame(scene, index).Position
				- BenchVisual.nestCFrame(scene, index).Position,
			start = os.clock(),
		}
		queueSend("Let", index, nil)
		hint(HINTS.Grab)
	elseif kind == "Loose" and rest then
		current.held = nil
		current.carry = nil
		current.states[index] = "Loose"
		current.looseAt[index] = rest
		current.settle = {
			index = index,
			from = BenchVisual.elementCFrame(scene, index),
			to = rest,
			start = os.clock(),
		}
		queueSend("Drop", index, { { ref = "Hand", gap = MIN.Drop } })
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function updateCamera(now: number, dt: number, scene: BenchVisual.Bench, current: Session)
	local cam = workspace.CurrentCamera
	local saved = savedCamera
	if cam == nil or saved == nil then
		return
	end
	local out = cameraOut
	if out then
		-- back to the player's view, where it is NOW around his body (then Custom takes over)
		local root = rootPart()
		local offset = saved.offset
		local goal = if root and offset then root.CFrame * offset else saved.cframe
		local t = smooth((now - out.start) / CAMERA_OUT)
		cam.CFrame = out.from:Lerp(goal, t)
		cam.FieldOfView = out.fov + (saved.fov - out.fov) * t
		if t >= 1 then
			giveCameraBack()
		end
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	local framing = FRAMINGS[current.framing] or FRAMINGS.Work
	local anchor = scene.anchor
	local position = anchor * framing.position
	local look = anchor * framing.look
	-- the push-in during the pull (toward the element), released on the soft release
	local pull = current.pull
	if pull and current.pushIn > 0 then
		local toward = (BenchVisual.elementCFrame(scene, pull.index).Position - position).Unit
		position += toward * 0.15 * current.pushIn
	end
	local state = cameraNow
	if state == nil then
		-- the hard cut: start 0.3 further back, then a 0.5 s push-in (the glide does it)
		state = {
			position = position - (look - position).Unit * 0.3,
			look = look,
			fov = framing.fov + 4,
		}
		cameraNow = state
	end
	local s = state :: { position: Vector3, look: Vector3, fov: number }
	local k = follow(dt, GLIDE)
	s.position = s.position:Lerp(position, k)
	s.look = s.look:Lerp(look, k)
	s.fov += (framing.fov - s.fov) * k
	-- the breathing sway (two slow sines, as in the autopsy), off during the release beat
	local sway = if now < current.swayOffUntil
		then Vector3.zero
		else Vector3.new(
			math.sin(now * 0.5 * math.pi) * 0.06,
			math.sin(now * 0.37 * math.pi + 1.3) * 0.036,
			0
		)
	local base = CFrame.lookAt(s.position, s.look, anchor.UpVector)
	cam.CFrame = base * CFrame.new(sway)
	cam.FieldOfView = s.fov
end

-- The hand's grip goal this frame and its pose, from the step / beat / what it holds.
local function updateHand(current: Session, scene: BenchVisual.Bench, now: number, dt: number)
	local h = hand
	local tool = scalpel
	if h == nil or tool == nil then
		return
	end
	local cam = camera()
	local anchor = scene.anchor
	local up = anchor.UpVector
	local goal: CFrame
	local pose: BenchHand.PoseName = "Open"
	local snap = false -- (beats and held tools drive the hand exactly)
	local scalpelAt: CFrame? = nil
	local hoverPlane = anchor * Vector3.new(0, CARRY_HEIGHT, 0)
	local pointed = onPlane(pointer, hoverPlane, up) or hoverPlane
	local beat = current.beat
	local restScalpel = anchor * BenchLayout.SCALPEL_REST

	if beat then
		local t = (now - beat.start) / beat.duration
		local name = beat.name
		if name == "ScalpelPick" then
			-- reach the handle (0.15), close into the pen grip (0.12), lift and turn (0.23)
			local overHandle = restScalpel * CFrame.new(0, 0.02, 0.3)
			local grabbed = BenchHand.frame(overHandle.Position, cam, 30)
			local tipUp = restScalpel.Position + up * 0.3
			local held = scalpelPose(tipUp, scene)
			local tt = t * beat.duration
			if tt < 0.15 then
				goal = beat.from:Lerp(grabbed, smooth(tt / 0.15))
			elseif tt < 0.27 then
				goal = grabbed
				pose = "Pen"
				if tt >= 0.18 and beat.data.clink == nil then
					beat.data.clink = true
					play("ScalpelPickup")
				end
			else
				local u = smooth((tt - 0.27) / 0.23)
				local pose2 = restScalpel:Lerp(held, u) + up * math.sin(u * math.pi) * 0.05
				scalpelAt = pose2
				goal = grabbed:Lerp(handOnScalpel(held), u)
				pose = "Pen"
			end
			snap = true
			if t >= 1 then
				current.beat = nil
				tipNow = tipUp
				queueSend("Tool", nil, { { ref = "Start", gap = MIN.Tool } })
				hint(HINTS.Skin)
				for _, cell in scene.cells do
					cell.guide.Transparency = 0.3 -- (the guide brightens a little)
				end
			end
		elseif name == "ScalpelBack" then
			-- an arc back to the tray (0.45), the hand opens and rises (0.3)
			local fromTip = tipNow or (restScalpel.Position + up * 0.3)
			local fromPose = scalpelPose(fromTip, scene)
			local tt = t * beat.duration
			if tt < 0.45 then
				local pose2 = arc(fromPose, restScalpel, tt / 0.45, 0.25)
				scalpelAt = pose2
				goal = handOnScalpel(pose2)
				pose = "Pen"
			else
				scalpelAt = restScalpel
				if beat.data.set == nil then
					beat.data.set = true
					play("ToolTraySetDown")
				end
				goal = handOnScalpel(restScalpel):Lerp(
					BenchHand.frame(restScalpel.Position + up * 0.6, cam, 20),
					smooth((tt - 0.45) / 0.3)
				)
			end
			snap = true
			if t >= 1 then
				current.beat = nil
				tipNow = nil
				hint(HINTS.Spread)
			end
		elseif name == "ClipOn" then
			-- to the tray (0.18), pinch a clip (0.08), arc to the rim (0.2), snap (0.1), back
			local side = beat.data.side :: number
			local clip = clips[side]
			local rest = anchor * BenchLayout.CLIP_RESTS[side]
			local rim = BenchVisual.clipFrame(scene, side)
			local snapped = rim * CFrame.Angles(math.rad(-20), 0, 0)
			local tt = t * beat.duration
			local clipAt: CFrame
			if tt < 0.18 then
				goal = beat.from:Lerp(handOnClip(rest), smooth(tt / 0.18))
				clipAt = rest
			elseif tt < 0.26 then
				goal = handOnClip(rest)
				pose = "Clip"
				clipAt = rest
			elseif tt < 0.46 then
				clipAt = arc(rest, rim, (tt - 0.26) / 0.2, 0.3)
				goal = handOnClip(clipAt)
				pose = "Clip"
			elseif tt < 0.56 then
				clipAt = rim:Lerp(snapped, smooth((tt - 0.46) / 0.1))
				goal = handOnClip(clipAt)
				pose = "Clip"
				if beat.data.click == nil then
					beat.data.click = true
					play("RetractorClick")
				end
			else
				clipAt = snapped
				goal = handOnClip(snapped):Lerp(
					BenchHand.frame(pointed, cam, 20),
					smooth((tt - 0.56) / 0.2)
				)
			end
			if clip then
				BenchHand.placeTool(clip, clipAt)
			end
			snap = true
			if t >= 1 then
				current.beat = nil
				current.clips[side] = snapped
				current.spread[side] = true
				queueSend(
					"Spread",
					side,
					{ { ref = "Layer", gap = MIN.Spread }, { ref = "Spread", gap = MIN.SpreadGap } }
				)
				if current.spread[1] and current.spread[2] then
					enterHarvest(current)
				end
			end
		elseif name == "Transfer" then
			-- lower the element onto the grate (0.15), let go: the pass-box takes over
			local index = beat.data.index :: number
			local from = beat.data.from :: CFrame
			local to = beat.data.to :: CFrame
			local at = from:Lerp(to, smooth(t))
			BenchVisual.setFree(scene, index, at)
			goal = BenchHand.frame(at.Position + up * BenchHand.HOLD_DROP, cam, 35)
			pose = "Grip"
			snap = true
			if t >= 1 then
				current.beat = nil
				local box = passBox
				local model = BenchVisual.takeModel(scene, index)
				if box and model then
					PassBox.transfer(
						box,
						model,
						current.elements[index].kind,
						BenchVisual.ELEMENT_SCALE
					)
				end
				current.states[index] = "Sealed"
				current.sealed += 1
				queueSend("Transfer", index, {
					{ ref = "Hand", gap = MIN.Transfer },
					{ ref = "Transfer", gap = MIN.TransferGap },
				})
				hint(if current.sealed >= current.slots then "" else HINTS.Next)
			end
		elseif name == "Withdraw" then
			goal = beat.from + (cam.RightVector * 1.6 - cam.UpVector * 1.2) * smooth(t)
			snap = true
			if t >= 1 then
				current.beat = nil
				BenchHand.show(h, false)
			end
		else
			current.beat = nil
			goal = handGrip
		end
	elseif current.step == "Intro" or current.step == "Tool" then
		-- in from the screen's right, then hovering open over the instrument tray
		local over =
			BenchHand.frame(restScalpel.Position + up * 0.55 + anchor.LookVector * -0.1, cam, 20)
		local t = (now - current.startedAt - 0.85) / 0.35
		if t < 0 then
			goal = over + (cam.RightVector * 1.6 - cam.UpVector * 0.8)
			snap = true
		elseif t < 1 then
			goal = (over + (cam.RightVector * 1.6 - cam.UpVector * 0.8)):Lerp(over, easeOut(t))
			snap = true
		else
			-- (it follows the pointer a little, staying near the tray)
			local toward = pointed - over.Position
			goal = over + toward * 0.15
		end
	elseif current.step == "Incise" then
		-- the scalpel's tip follows the pointer: on the chest while pressed, hovering above
		local origin, normal = BenchVisual.chestPlane(scene)
		local hit = onPlane(pointer, origin, normal) or origin
		local s, e = BenchVisual.toSeam(scene, hit)
		local depth = if pressing
			then BenchVisual.cellDepth(scene, math.clamp(math.floor(s) + 1, 1, 12))
			else 0
		local onChest = math.abs(e) < 1.0 and s > -1 and s < BenchVisual.CELLS + 1
		local lift = if pressing and onChest then -0.015 * depth else 0.12
		local wanted = hit + normal * lift
		local previous = tipNow or wanted
		local tip = previous:Lerp(wanted, follow(dt, if pressing then 0.02 else 0.05))
		-- (skidding: the hand chatters)
		if pressing and current.speed > E.SKID_SPEED then
			tip += Vector3.new(math.noise(now * 40, 1), 0, math.noise(1, now * 40)) * 0.015
		end
		tipNow = tip
		local pose2 = scalpelPose(tip, scene, if pressing then 4 else 0)
		scalpelAt = pose2
		goal = handOnScalpel(pose2)
		pose = "Pen"
		snap = true
		if pressing and onChest and current.zip == nil and current.beat == nil then
			updateCut(current, scene, now, dt, tip)
		end
	elseif current.step == "Spread" then
		local drag = current.panelDrag
		if drag then
			local origin, normal = BenchVisual.chestPlane(scene)
			local hit = onPlane(pointer, origin, normal) or origin
			local _, e = BenchVisual.toSeam(scene, hit)
			local outward = if drag.side == 1 then drag.startE - e else e - drag.startE
			local open = 1 - math.exp(-math.max(outward, 0) / 0.55)
			drag.open = open
			local tremble = if open > 0.4 then math.sin(now * 25 * math.pi * 2) * 0.01 * open else 0
			BenchVisual.setPanel(scene, drag.side, open * 0.7, tremble)
			local loop = stretchLoop
			if loop then
				loop.PlaybackSpeed = 0.8 * (0.9 + 0.3 * open)
			end
			local rim = BenchVisual.clipFrame(scene, drag.side)
			goal = BenchHand.frame(rim.Position + up * 0.05, cam, 15)
			pose = "Press"
		else
			goal = BenchHand.frame(pointed, cam, 20)
			pose = "Open"
		end
	else
		-- Harvest: the hand with what it holds, else open over the pointer
		local pull = current.pull
		local carry = current.carry
		if pull then
			local at = BenchVisual.elementCFrame(scene, pull.index).Position
			goal = BenchHand.frame(at + up * BenchHand.HOLD_DROP, cam, 35)
			pose = "Grip"
		elseif carry then
			goal = BenchHand.frame(carry.position + up * BenchHand.HOLD_DROP, cam, 30)
			pose = "Grip"
		else
			goal = BenchHand.frame(pointed, cam, 20)
		end
	end

	-- the hand: exact on a beat or a held tool, else a spring (half-life 0.06 s)
	if snap then
		handGrip = goal
	else
		handGrip = handGrip:Lerp(goal, follow(dt, 0.06))
	end
	BenchHand.setPose(h, pose)
	BenchHand.place(h, handGrip)
	BenchHand.show(h, current.outroStart == nil or current.beat ~= nil)
	BenchHand.step(h, dt, cam)
	if scalpelAt then
		BenchHand.placeTool(tool, scalpelAt)
	end
	-- the mouse cursor hides while the glove is the cursor (cutting, spreading, holding)
	UserInputService.MouseIconEnabled = not (
		current.step == "Incise"
		or current.panelDrag ~= nil
		or current.pull ~= nil
		or current.held ~= nil
	)
end

-- The pull, the carry, settling, letting back (Harvest).
local function updateElements(current: Session, scene: BenchVisual.Bench, now: number, dt: number)
	local anchor = scene.anchor
	local up = anchor.UpVector
	local cam = camera()
	-- the pull: it follows only a little and trembles more and more; free after 0.5 s of
	-- tension (or a long pull); a husk comes up at once
	local pull = current.pull
	if pull then
		local element = current.elements[pull.index]
		local plane = pull.grab + up * 0.45
		local facing = cam.Position - plane
		facing -= up * facing:Dot(up)
		local normal = if facing.Magnitude > 1e-3 then facing.Unit else -anchor.LookVector
		local target = onPlane(pointer, plane, normal) or plane
		local pulled = target - pull.grab
		local d = pulled.Magnitude
		local husk = element.kind == "Husk"
		if d > E.PULL_START then
			pull.tension += dt
		else
			pull.tension = math.max(0, pull.tension - dt)
		end
		if now - pull.shakeAt > 1 / 30 then
			pull.shakeAt = now
			local k = 0.035 * math.min(1, d) * math.min(1, pull.tension / E.PULL_FREE_TIME + 0.3)
			pull.shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
				* 2
				* k
		end
		local give = if d > 1e-3 then pulled.Unit * math.min(d * 0.28, 0.35) else Vector3.zero
		local offset = give + pull.shake + up * 0.06
		BenchVisual.setPull(scene, pull.index, offset)
		local stretch = math.clamp(pull.tension / E.PULL_FREE_TIME, 0, 1)
		BenchVisual.setStretch(scene, math.max(stretch, math.min(d / E.PULL_FREE_DIST, 1)))
		current.pushIn = stretch
		local loop = strainLoop
		if loop then
			loop.PlaybackSpeed = 0.9 + 0.35 * stretch
		end
		if husk or pull.tension >= E.PULL_FREE_TIME or d >= E.PULL_FREE_DIST then
			-- free: soft release (never a tear)
			pull.freed = true
			current.pull = nil
			current.pushIn = 0
			current.swayOffUntil = now + 0.15
			stopLoop(strainLoop)
			strainLoop = nil
			current.states[pull.index] = "Held"
			current.held = pull.index
			current.heldFromTray = false
			local at = BenchVisual.elementCFrame(scene, pull.index)
			current.carry = {
				position = at.Position,
				velocity = Vector3.zero,
				tilt = Vector3.zero,
				lower = 0,
				beadAt = now,
			}
			BenchVisual.setFree(scene, pull.index, at)
			queueSend(
				"Free",
				pull.index,
				{ { ref = "Hand", gap = if husk then MIN.FreeHusk else MIN.Free } }
			)
			if not husk then
				BenchVisual.releaseStrands(scene, pull.index, true)
				play("ElementRelease")
				BenchVisual.breath(
					scene,
					4,
					BenchVisual.nestCFrame(scene, pull.index).Position,
					0.12
				)
			end
			hint(HINTS.ToTray)
			readOut(element)
		end
	else
		current.pushIn = math.max(0, current.pushIn - dt * 4)
	end

	-- the carry: the element hangs in the glove, a little lag, a pendulum tilt
	local index = current.held
	local carry = current.carry
	if index and carry and current.beat == nil then
		local plane = anchor * Vector3.new(0, CARRY_HEIGHT, 0)
		local target = onPlane(pointer, plane, up) or plane
		-- over the trays and the grate, the plane comes down to just above them
		local kind = dropTarget(current, scene, index, target)
		local lowGoal = if kind == "Tray" or kind == "Grate" or kind == "Loose" then 1 else 0
		carry.lower += (lowGoal - carry.lower) * follow(dt, 0.15)
		local p = anchor:PointToObjectSpace(target)
		local floorY = if kind == "Grate" then BenchLayout.GRATE_CENTRE.Y else 0
		local height = CARRY_HEIGHT
			+ (floorY + 0.3 + BenchVisual.halfHeight(scene, index) - CARRY_HEIGHT) * carry.lower
		local goal = anchor * Vector3.new(p.X, height, p.Z)
		local before = carry.position
		carry.position = before:Lerp(goal, follow(dt, 0.06))
		carry.velocity = (carry.position - before) / math.max(dt, 1e-3)
		local local_ = anchor:VectorToObjectSpace(carry.velocity)
		local tiltGoal = Vector3.new(
			math.clamp(local_.Z * 0.05, -math.rad(12), math.rad(12)),
			0,
			math.clamp(-local_.X * 0.05, -math.rad(12), math.rad(12))
		)
		carry.tilt = carry.tilt:Lerp(tiltGoal, follow(dt, 0.12))
		local cframe = CFrame.new(carry.position)
			* anchor.Rotation
			* CFrame.Angles(carry.tilt.X, 0, carry.tilt.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		BenchVisual.setFree(scene, index, cframe)
		-- a ruptured one drips milky beads on its way (they land and stay)
		if current.elements[index].condition == "Ruptured" and now - carry.beadAt > 0.25 then
			carry.beadAt = now
			BenchVisual.bead(scene, carry.position - up * BenchVisual.halfHeight(scene, index))
		end
		-- the pass-box lid opens by itself when the hand brings a tray element near the grate
		local box = passBox
		if box and not PassBox.busy(box) then
			local grate = anchor * BenchLayout.GRATE_CENTRE
			local close = (carry.position - grate).Magnitude < 1.2
			PassBox.wantLid(box, close and current.heldFromTray)
		end
		if current.framing ~= "Transfer" and current.heldFromTray then
			current.framing = "Transfer"
		end
	end

	-- settling on the tray / the trolley: lower 0.15, open the hand, squash, a small wobble
	local settle = current.settle
	if settle then
		local t = now - settle.start
		local at: CFrame
		if t < 0.15 then
			at = settle.from:Lerp(settle.to, smooth(t / 0.15))
		else
			local u = t - 0.25
			local squash = if u > 0 and u < 0.18 then math.sin(u / 0.18 * math.pi) * 0.04 else 0
			local wobble = if u > 0.18 and u < 0.58
				then math.sin((u - 0.18) / 0.4 * math.pi * 4) * 0.03 * (1 - (u - 0.18) / 0.4)
				else 0
			at = settle.to * CFrame.new(0, -squash, 0) * CFrame.Angles(wobble, 0, 0)
		end
		BenchVisual.setFree(scene, settle.index, at)
		if t >= 0.15 and settle.from ~= settle.to then
			settle.from = settle.to
			play("TraySet")
			if current.states[settle.index] == "OnTray" then
				BenchVisual.runoff(scene, settle.index)
				readOut(current.elements[settle.index])
				play("ScanLock")
			end
		end
		if t >= 0.6 then
			BenchVisual.setFree(scene, settle.index, settle.to)
			current.settle = nil
		end
	end

	-- let back into the nest (0.2 s)
	local back = current.letBack
	if back then
		local t = (now - back.start) / 0.2
		BenchVisual.setPull(scene, back.index, back.from * (1 - smooth(t)))
		if t >= 1 then
			current.letBack = nil
		end
	end

	-- the camera back to WORK when nothing goes to the box
	local box = passBox
	if
		current.held == nil
		and current.beat == nil
		and box
		and not PassBox.busy(box)
		and current.framing == "Transfer"
	then
		current.framing = "Work"
	end
end

-- Hover: one outline, and the CRT reads the element after SCAN_TIME.
local function updateHover(current: Session, scene: BenchVisual.Bench, now: number)
	local target: Instance? = nil
	if current.step == "Tool" and current.beat == nil then
		target = scalpelModel
	elseif current.step == "Harvest" and current.held == nil and current.pull == nil then
		local index = elementAt(current, scene)
		if index ~= current.hovered then
			current.hovered = index
			current.hoverSince = now
			current.scanned = nil
			if index then
				play("UiSelect")
			end
		end
		if index then
			target = BenchVisual.elementModel(scene, index)
			if now - current.hoverSince >= E.SCAN_TIME and current.scanned ~= index then
				current.scanned = index
				play("ScanLock")
				readOut(current.elements[index])
			elseif current.scanned ~= index then
				screenText(
					"SCANNING",
					string.rep(if math.noise(now * 20, 1) > 0 then "#" else "-", 6),
					""
				)
			end
		end
	end
	BenchVisual.outline(scene, target)
end

local function updateTimer(current: Session, now: number, screen: ExtractionUI.UI)
	local ends = current.coolEnds
	if ends == nil then
		ExtractionUI.setCooling(screen, nil, false)
		return
	end
	local left = ends - now
	local low = left <= LOW_TIME
	ExtractionUI.setCooling(screen, left / E.COOL_TIME, low)
	if low and left > 0 and now - current.lastLowTick >= 1 then
		current.lastLowTick = now
		play("TimerLow")
	end
	-- the bar ran out: whatever is sealed is kept (nothing sealed: the vat stays READY)
	local box = passBox
	if
		left <= 0
		and not current.endSent
		and current.beat == nil
		and (box == nil or not PassBox.busy(box))
	then
		if current.sealed == 0 then
			sendNow("Stop")
			stopLocal()
			return
		end
		current.endSent = true
		sendNow("Done")
	end
end

local function beginOutro(current: Session, done: Types.ExtractDonePayload)
	current.outroStart = os.clock()
	current.framing = "Well"
	stopLoop(strainLoop)
	strainLoop = nil
	stopLoop(stretchLoop)
	stretchLoop = nil
	startBeat(current, "Withdraw", 0.3)
	local screen = ensureUI()
	ExtractionUI.setCooling(screen, nil, false)
	ExtractionUI.setDone(screen, false, false)
	ExtractionUI.setHint(screen, "")
	screenText("SEALED", `{#done.cores} CORE(S)`, "")
end

local function updateOutro(now: number, scene: BenchVisual.Bench, current: Session)
	local start = current.outroStart :: number
	local done = current.done :: Types.ExtractDonePayload
	local t = now - start
	local events = current.outroEvents
	local box = passBox
	BenchVisual.closePanels(scene, math.clamp((t - CARD_AT) / 0.4, 0, 1), { 1, 1 })
	-- the well's inner shutter closes in shot, the strip display counts what is stored
	if t >= 0.5 and not events.shutter and box then
		events.shutter = true
		PassBox.closeWell(box)
		play("GrateSlide", 0.7)
	end
	if t >= 0.9 and not events.stored and box then
		events.stored = true
		PassBox.setDisplay(box, `{current.sealed}/{current.slots} STORED`)
		play("UiConfirm")
	end
	if t >= CARD_AT and not events.card then
		events.card = true
		current.framing = "Work"
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
			elseif done.toCase then "Loaded in the case on the floor."
			else "Stored in the freezer stash."
		if ui then
			ExtractionUI.result(ui, `SEALED {#done.cores + done.inert}/{current.slots}`, lines, sub)
		end
	end
	if t >= CHUTE_START and not events.chute then
		events.chute = true
		play("ChuteSlide")
	end
	-- the shell slides into the chute (the trolley's leftovers fade with it)
	local parts = LabController.parts()
	local chute = if parts then parts.chuteMouth else nil
	if t >= CHUTE_START then
		local slide = (t - CHUTE_START) / CHUTE_TIME
		if chute then
			BenchVisual.place(scene, BenchVisual.chuteRoot(scene, chute.CFrame, math.min(slide, 1)))
		end
		if slide > 0.8 or chute == nil then
			BenchVisual.fade(scene, 1 - smooth((slide - 0.8) / 0.2))
		end
	else
		BenchVisual.place(scene, BenchVisual.lyingRoot(scene.anchor))
	end
	if t >= CAMERA_OUT_AT and cameraOut == nil and savedCamera ~= nil then
		local cam = workspace.CurrentCamera
		cameraOut = {
			from = if cam then cam.CFrame else CFrame.identity,
			fov = if cam then cam.FieldOfView else 40,
			start = now,
		}
		if ui then
			ExtractionUI.show(ui, false)
		end
		hideOwnBody(false)
	end
	if t >= CHUTE_START + CHUTE_TIME + 0.2 then
		stopLocal()
	end
end

local function updatePanels(current: Session, scene: BenchVisual.Bench, now: number)
	local anim = current.panelAnim
	if anim == nil then
		return
	end
	local t = (now - anim.start) / 0.25
	local value: number
	if anim.back then
		-- a small Back Out: it springs home, overshoots a hair, settles
		local s = math.clamp(t, 0, 1)
		local c = 1.2
		local back = 1 + (c + 1) * (s - 1) ^ 3 + c * (s - 1) ^ 2
		value = anim.from * (1 - back)
	else
		value = anim.from + (anim.to - anim.from) * easeOut(t)
	end
	BenchVisual.setPanel(scene, anim.side, value, 0)
	if t >= 1 then
		current.panelAnim = nil
		if not anim.back then
			play("PanelsOpen", 1.1)
			startBeat(current, "ClipOn", 0.76, { side = anim.side })
		end
	end
end

-- Clips already on a panel ride its rim.
local function updateClips(current: Session, scene: BenchVisual.Bench)
	for side = 1, 2 do
		local clip = clips[side]
		local beat = current.beat
		local moving = beat ~= nil and beat.name == "ClipOn" and beat.data.side == side
		if clip and current.clips[side] and not moving then
			BenchHand.placeTool(
				clip,
				BenchVisual.clipFrame(scene, side) * CFrame.Angles(math.rad(-20), 0, 0)
			)
		end
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
	if parts == nil and current.outroStart == nil then
		-- (the lab is gone: we left it, or it streamed out)
		stopLocal()
		return
	end
	flushQueue(now)
	-- gamepad: the left stick moves the cursor (slower over the shell)
	if stick.Magnitude > 0.15 then
		local speed = if current.step == "Incise" then 260 else 600
		local cam = workspace.CurrentCamera
		local size = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		pointer = Vector2.new(
			math.clamp(pointer.X + stick.X * speed * dt, 0, size.X),
			math.clamp(pointer.Y + stick.Y * speed * dt, 0, size.Y)
		)
	end
	-- touch pinch (Spread): two fingers apart open both panels at once
	if current.step == "Spread" and current.beat == nil then
		local points: { Vector2 } = {}
		for _, at in touches do
			table.insert(points, at)
		end
		if #points >= 2 then
			local origin, normal = BenchVisual.chestPlane(scene)
			local a = onPlane(points[1], origin, normal)
			local b = onPlane(points[2], origin, normal)
			if a and b then
				local _, ea = BenchVisual.toSeam(scene, a)
				local _, eb = BenchVisual.toSeam(scene, b)
				local d = math.abs(ea - eb)
				local pinch = current.pinch
				if pinch == nil then
					current.pinch = { d0 = d }
					current.panelDrag = nil
				else
					local open = 1 - math.exp(-math.max(d - pinch.d0, 0) / 2 / 0.55)
					for side = 1, 2 do
						if not current.spread[side] then
							BenchVisual.setPanel(scene, side, open * 0.7, 0)
						end
					end
					if open >= E.PANEL_LATCH then
						current.pinch = nil
						touches = {}
						pressing = false
						-- each panel finishes and gets its clip, one after the other
						for side = 1, 2 do
							if not current.spread[side] then
								current.panelAnim = {
									side = side,
									from = open * 0.7,
									to = 1,
									start = now,
									back = false,
								}
								break
							end
						end
					end
				end
			end
		else
			current.pinch = nil
		end
	end
	-- the step machine
	if current.outroStart == nil then
		local t = now - current.startedAt
		if current.step == "Intro" then
			-- the shell: out of the vat in an arc, onto the trolley; it settles with a bounce
			local lying = BenchVisual.lyingRoot(scene.anchor)
			if t < SLIDE_TIME then
				local s = smooth(t / SLIDE_TIME)
				local from = vatRoot or lying
				BenchVisual.place(
					scene,
					from:Lerp(lying, s) + Vector3.new(0, math.sin(s * math.pi) * 1.2, 0)
				)
			else
				local u = t - SLIDE_TIME
				local bounce = if u < 0.2 then math.sin(u / 0.2 * math.pi) * 0.03 else 0
				BenchVisual.place(scene, lying + Vector3.new(0, bounce, 0))
				if not current.outroEvents.settled then
					current.outroEvents.settled = true
					play("ToolTraySetDown", 0.8)
				end
			end
			if t >= INTRO_TIME then
				current.step = "Tool"
				hint(HINTS.Tool)
			end
		else
			BenchVisual.place(scene, BenchVisual.lyingRoot(scene.anchor))
		end
		updateZip(current, scene, now)
		updatePanels(current, scene, now)
		updateHand(current, scene, now, dt)
		updateClips(current, scene)
		if current.step == "Harvest" then
			-- the elements light up one by one (80 ms apart)
			local litStart = current.litStart
			if litStart then
				local lit = math.min(#current.elements, math.floor((now - litStart) / STAGGER) + 1)
				while current.litCount < lit do
					current.litCount += 1
					BenchVisual.lightUp(scene, current.litCount)
				end
			end
			updateElements(current, scene, now, dt)
			updateTimer(current, now, screen)
		end
		if session == current then
			updateHover(current, scene, now)
			ExtractionUI.setDone(
				screen,
				current.sealed > 0,
				not current.endSent and current.held == nil and current.pull == nil
			)
			-- the server's end: the outro once the last transfer has played out
			local done = current.done
			local box = passBox
			if
				done
				and current.beat == nil
				and current.settle == nil
				and (box == nil or not PassBox.busy(box))
			then
				beginOutro(current, done)
			end
		end
	else
		updateHand(current, scene, now, dt)
		updateClips(current, scene)
		updateOutro(now, scene, current)
	end
	if session ~= current then
		return
	end
	updateCamera(now, dt, scene, current)
	if savedCamera ~= nil and cameraOut == nil then
		keepBodyHidden()
	end
	-- the pass-box and its sounds (on the frame they happen)
	local box = passBox
	if box then
		PassBox.step(box, dt, now)
		for _, event in PassBox.takeEvents(box) do
			if event == "HatchOpen" then
				play("HatchOpen")
			elseif event == "GrateOpen" then
				play("GrateSlide")
			elseif event == "GrateClose" then
				play("GrateSlide", 0.9)
			elseif event == "CapsuleDrop" then
				play("CapsuleDrop")
			elseif event == "CapClose" then
				play("CapsuleSeal")
				play("CapsuleHiss")
			elseif event == "Frost" then
				play("SealFrost")
			elseif event == "CarouselTurn" then
				play("CarouselTurn")
			elseif event == "HatchClose" then
				play("HatchClose")
			elseif event == "Count" then
				play("UiConfirm", 0.9)
			end
		end
	end
	if bench then
		BenchVisual.step(scene, dt, now)
		local drips = BenchVisual.takeLanded(scene)
		if drips > 0 and now - current.dripAt > 0.25 then
			current.dripAt = now
			play("MilkDrip")
		end
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
		elseif kind == "ExtractPicked" then
			onPicked(data)
		elseif kind == "ExtractDone" then
			onDone(data)
		end
	end)
end

function ExtractionController.start()
	-- (render is bound with BindToRenderStep while a session runs only: see bindRender)
	local touch: InputObject? = nil -- (the finger the pointer follows)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if session == nil then
			return
		end
		-- (Backspace while typing in the chat must not stop the extraction; Esc is left to the
		-- Roblox menu)
		if
			(input.KeyCode == Enum.KeyCode.Backspace and not gameProcessed)
			or input.KeyCode == Enum.KeyCode.ButtonB
		then
			cancel()
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonX then
			finishNow()
			return
		end
		if input.KeyCode == Enum.KeyCode.H and not gameProcessed then
			if ui then
				ExtractionUI.toggleHint(ui)
			end
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonA then
			pointerDown()
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			local at = viewportPoint(input)
			if ui and ExtractionUI.isOverButtons(ui, at) then
				return
			end
			if kind == Enum.UserInputType.Touch then
				touches[input] = at
				if touch ~= nil then
					return -- (a second finger: the pinch, not a new press)
				end
				touch = input
			end
			pointer = at
			pointerDown()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if session == nil then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement then
			pointer = viewportPoint(input)
		elseif kind == Enum.UserInputType.Touch then
			if touches[input] then
				touches[input] = viewportPoint(input)
			end
			if input == touch then
				pointer = viewportPoint(input)
			end
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stick = Vector2.new(input.Position.X, -input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch then
			touches[input] = nil
			if input == touch then
				touch = nil
				pointerUp()
			end
		elseif kind == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonA then
			pointerUp()
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stick = Vector2.zero
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
