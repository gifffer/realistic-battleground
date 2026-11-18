--!strict
-- Autopsy: a small mini-game made only to record a VIDEO (18+, Studio only,
-- to be removed afterwards; Controllers/AutopsyController is its gate).
-- A Dexter-style kill room floats high above the spawn; an R6 body lies on
-- the steel table wrapped in film; you cut the skin with a scalpel, spread
-- the wound with your hands, cut the chest plate free with shears and pull
-- the organs (Z-Anatomy) out. During the operation the screen turns into
-- old-school pixel art (PixelScreen).
--
-- Everything is local (built by this client, nobody else sees it).
-- Controls during the operation (docs/AUTOPSY_FR.md):
--   1 Scalpel  2 Hands  3 Shears   LMB use   RMB drag orbit   wheel zoom /
--   lift   R reset   P pixel on/off   H hide the hints   F or Backspace exit

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Blood = require(script.Parent.Combat.Blood)
local BloodStain = require(script.Parent.Combat.BloodStain)
local CameraController = require(script.Parent.Controllers.CameraController)
local Make = require(script.Make)
local Organs = require(script.Organs)
local Patient = require(script.Patient)
local PixelScreen = require(script.PixelScreen)
local Room = require(script.Room)
local Sfx = require(script.Sfx)
local Skin = require(script.Skin)
local Tools = require(script.Tools)

local Autopsy = {}

local player = Players.LocalPlayer
local UP = Vector3.new(0, 1, 0)
local ROOM_HEIGHT = 300 -- studs above the spawn
local TOOLS = { "Scalpel", "Hands", "Shears" }
local HINT = "1 SCALPEL   2 HANDS   3 SHEARS   R RESET   P PIXEL   H HIDE   F EXIT"
local CRACK_TIME = 1.2 -- seconds of shears on the chest plate

local root: Folder
local room: Room.Room
local patient: Patient.Patient
local organs: Organs.Set
local tools: Tools.Tools
local fx: Folder

local inRoom = false
local operating = false
local pixelWanted = true
local tool = "Scalpel"

-- the input of the operation
local leftDown = false
local rightDown = false
local stroke = 0
local lastCut: Vector2? = nil
local strokeDeepest = 0 -- (how deep this stroke went)
local lastCutMove = 0
local cutTravel = 0
local lastDrop = 0
local spreading: Vector2? = nil
local lastSpreadSound = 0
local shearing = 0
local lift = 1.1

-- the camera
local yaw, pitch, zoom = 0, 0, 6.4
local enterStart = 0
local enterFrom = CFrame.identity
local savedFov = 70

-- what is put back on exit
local savedGuis: { [ScreenGui]: boolean } = {}
local savedCore: { [Enum.CoreGuiType]: boolean } = {}
local savedLighting: { [string]: any } = {}
local hud: ScreenGui? = nil
local hintLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local hum: Sound? = nil
local grade: ColorCorrectionEffect? = nil
local queryHooks: { RBXScriptConnection } = {}
local pixelTurn = 0 -- (counts the setPixel calls: a slow start can be overtaken)
local madeQueryable: { BasePart } = {}
local statusUntil = 0

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

local function status(text: string)
	local labelNow = statusLabel
	if labelNow then
		labelNow.Text = text
		labelNow.Visible = text ~= ""
		statusUntil = os.clock() + 2.5
	end
end

local function mouseRay(): Ray?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local mouse = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouse.X, mouse.Y)
end

local pickParams = RaycastParams.new()
pickParams.FilterType = Enum.RaycastFilterType.Include

local function pick(ray: Ray): RaycastResult?
	pickParams.FilterDescendantsInstances = { patient.model, organs.folder }
	return workspace:Raycast(ray.Origin, ray.Direction * 40, pickParams)
end

local function character(): (Model?, BasePart?)
	local model = player.Character
	local hrp = if model then model:FindFirstChild("HumanoidRootPart") else nil
	if model and hrp and hrp:IsA("BasePart") then
		return model, hrp
	end
	return nil, nil
end

------------------------------------------------------------------------------
-- Blood on the cut
------------------------------------------------------------------------------

-- A bead of blood welling up in the cut; a third run over the side.
local function bead(at: Vector2)
	local skin = patient.skin
	local world = Skin.toWorld(skin, at, -0.51)
	local drop = Make.part({
		Name = "Bead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.02, 0.02, 0.02),
		CFrame = CFrame.new(world),
		Color = Color3.fromRGB(176, 21, 21),
		Reflectance = 0.14,
		CanCollide = false,
		CastShadow = false,
		Ramp = "blood",
		Parent = fx,
	})
	local size = 0.05 + math.random() * 0.05
	TweenService:Create(
		drop,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad),
		{ Size = Vector3.new(size, size, size) }
	):Play()
	task.delay(0.8, function()
		if math.random() > 0.85 or drop.Parent == nil then
			return
		end
		-- it overflows toward the nearer side of the torso and drips off
		local sign = if at.X >= 0 then 1 else -1
		local frame = skin.frame
		local sideAt = frame:PointToWorldSpace(Vector3.new(sign * 1.0, at.Y, -0.42))
		local out = frame:VectorToWorldSpace(Vector3.new(sign, 0, 0))
		local sideTile = skin.sides[sign]
		Blood.run(
			sideAt + out * 0.02,
			out,
			0.06 + math.random() * 0.04,
			{ onto = sideTile, length = 0.9 }
		)
		task.delay(0.9, function()
			local under = sideAt + out * 0.08 - UP * 0.9
			Blood.drop(under, out * 0.3, 0.07, nil, Blood.passiveScale(), { passive = true })
			Blood.splat(
				Vector3.new(under.X, room.tableTop.Position.Y + 0.13, under.Z) + out * 0.25,
				UP,
				0.3 + math.random() * 0.5,
				nil,
				nil
			)
		end)
	end)
end

local function bleedCells(cells: { Vector2 })
	for _, at in cells do
		strokeDeepest = math.max(strokeDeepest, Skin.depthAt(patient.skin, at))
		cutTravel += 0.0625
		if cutTravel >= 0.07 then
			cutTravel = 0
			bead(at)
		end
	end
	local now = os.clock()
	if #cells > 0 and now - lastDrop > 0.15 then
		lastDrop = now
		local at = cells[#cells]
		-- (the knife opens small vessels: it spits as it goes)
		Blood.spray(Skin.toWorld(patient.skin, at, -0.52), UP, 0.9)
		Blood.drop(
			Skin.toWorld(patient.skin, at, -0.52),
			UP * 0.6,
			0.06,
			nil,
			Blood.passiveScale(),
			{ passive = true }
		)
	end
end

------------------------------------------------------------------------------
-- Scene: build / reset
------------------------------------------------------------------------------

local function buildPatient()
	patient = Patient.build(room.torso, root)
	organs = Organs.build(room.torso, root, patient.anchor)
	fx = Instance.new("Folder")
	fx.Name = "Fx"
	fx.Parent = root
	if not organs.kit then
		warn(
			"[Autopsy] the WoundKit has no autopsy pieces: simple organs instead (import assets/wounds/WoundKit.fbx)"
		)
		status(
			"No autopsy pieces in the WoundKit: simple organs (import assets/wounds/WoundKit.fbx)"
		)
	end
end

local function resetPatient()
	Organs.release(organs)
	Organs.destroy(organs)
	Patient.destroy(patient)
	fx:Destroy()
	buildPatient()
	stroke, lastCut, spreading, shearing = 0, nil, nil, 0
	Sfx.play("Plastic", room.tableTop)
	status("New patient")
end

------------------------------------------------------------------------------
-- Pixel mode
------------------------------------------------------------------------------

-- The pixel screen only sees parts it can query: blood (and Squish's
-- copies) are made queryable while it runs, then put back.
local function queryable(item: Instance)
	if item:IsA("BasePart") and not item.CanQuery then
		if item.Transparency < 0.95 or item:FindFirstChildOfClass("Decal") then
			item.CanQuery = true
			table.insert(madeQueryable, item)
		end
	end
end

local function setPixel(on: boolean)
	pixelTurn += 1
	local turn = pixelTurn
	if on then
		local ok = PixelScreen.start({
			include = { root, BloodStain.folder },
			lamp = room.lamp,
			lampDown = room.lampDown,
			side = room.side,
		})
		if not ok then
			pixelWanted = false
			status("Pixel screen unavailable (allow Mesh / Image APIs in Game Settings > Security)")
			return
		end
		-- (the first start waits for its workers: the player may have left,
		-- or pressed P, meanwhile)
		if not operating or not pixelWanted then
			PixelScreen.stop()
			return
		end
		if turn ~= pixelTurn then
			return -- (a newer call turned it on and hooked everything)
		end
		for _, folder in { BloodStain.folder, root } :: { Instance } do
			for _, item in folder:GetDescendants() do
				queryable(item)
			end
			table.insert(
				queryHooks,
				folder.DescendantAdded:Connect(function(item)
					task.defer(queryable, item)
				end)
			)
		end
		UserInputService.MouseIconEnabled = false
	else
		PixelScreen.stop()
		for _, hook in queryHooks do
			hook:Disconnect()
		end
		table.clear(queryHooks)
		for _, part in madeQueryable do
			if part.Parent and part:IsDescendantOf(BloodStain.folder) then
				part.CanQuery = false
			end
		end
		table.clear(madeQueryable)
		UserInputService.MouseIconEnabled = true
	end
	Sfx.setRetro(on)
end

------------------------------------------------------------------------------
-- The camera over the body
------------------------------------------------------------------------------

local function cameraFrame(now: number): CFrame
	local frame = patient.frame
	local head = frame.UpVector -- (toward the head)
	local target = frame.Position + head * 0.1
	local base = (UP * 6 - head * 1.6).Unit
	local right = base:Cross(head).Unit
	local turned = CFrame.fromAxisAngle(UP, yaw) * CFrame.fromAxisAngle(right, pitch)
	local offset = turned:VectorToWorldSpace(base) * zoom
	local sway = Vector3.new(math.sin(now * math.pi * 0.5), 0, math.cos(now * math.pi * 0.37)) * 0.1
	return CFrame.lookAt(target + offset + sway, target, head)
end

local function updateCamera()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = os.clock()
	local goal = cameraFrame(now)
	local t = math.clamp((now - enterStart) / 0.6, 0, 1)
	t = 1 - (1 - t) ^ 3
	camera.CFrame = enterFrom:Lerp(goal, t)
	camera.FieldOfView = 42
	-- (our own body out of the shot)
	local model = player.Character
	if model then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
	end
end

------------------------------------------------------------------------------
-- The tools, every frame
------------------------------------------------------------------------------

local function frontPoint(ray: Ray): Vector2?
	return Skin.onFront(patient.skin, ray.Origin, ray.Direction)
end

local function heldTarget(ray: Ray): Vector3
	local y = patient.frame.Position.Y + 0.5 + lift
	local d = ray.Direction
	if math.abs(d.Y) < 1e-3 then
		return ray.Origin + d.Unit * 6
	end
	local t = (y - ray.Origin.Y) / d.Y
	return ray.Origin + d * math.max(t, 0)
end

local function useTools(dt: number)
	local ray = mouseRay()
	local camera = workspace.CurrentCamera
	if ray == nil or camera == nil then
		return
	end
	local now = os.clock()
	local hit = pick(ray)
	local front = frontPoint(ray)
	local point = if hit
		then hit.Position
		elseif front then Skin.toWorld(patient.skin, front)
		else ray.Origin + ray.Direction.Unit * 6
	Skin.update(patient.skin)

	if tool == "Scalpel" then
		if front == nil then
			lastCut = nil -- (off the chest: the next cut starts anew)
		end
		if leftDown and front then
			local previous = lastCut
			if previous == nil then
				lastCut = front
				lastCutMove = now
				bleedCells(Skin.cut(patient.skin, front, front, stroke))
			elseif (front - previous).Magnitude >= 0.03 then
				local cells = Skin.cut(patient.skin, previous, front, stroke)
				bleedCells(cells)
				if #cells > 0 and math.random() < 0.12 then
					Sfx.play("Cut", point)
				end
				lastCut = front
				lastCutMove = now
			elseif now - lastCutMove > 0.35 then
				-- held still: deeper
				lastCutMove = now
				local cells = Skin.deepen(patient.skin, front)
				if #cells > 0 then
					bleedCells(cells)
					Sfx.play("DeepCut", point)
				end
			end
		end
		Tools.show(tools, "Scalpel", point, camera.CFrame, leftDown)
	elseif tool == "Hands" then
		if organs.held then
			local target = heldTarget(ray)
			Organs.drag(organs, target, dt)
			Tools.show(tools, "Hands", target + UP * 0.05, camera.CFrame, true)
		else
			local from = spreading
			if leftDown and from and front then
				local moved = (front - from).Magnitude
				if moved > 0.01 then
					Skin.spread(patient.skin, front, moved / 0.0625 * 0.9)
					spreading = front
					if now - lastSpreadSound > 0.35 then
						lastSpreadSound = now
						Sfx.play("Spread", point)
					end
				end
			end
			Tools.show(tools, "Hands", point, camera.CFrame, leftDown)
		end
	elseif tool == "Shears" then
		if leftDown and hit then
			local organ = Organs.find(organs, hit.Instance)
			if organ and organ.locked then
				if shearing == 0 then
					Sfx.play("Saw", point)
				end
				shearing += dt
				if math.random() < 0.15 then
					Blood.drop(point + UP * 0.05, UP * 1.2, 0.04)
				end
				if shearing >= CRACK_TIME then
					shearing = -1000 -- (done for this press)
					Organs.crack(organ)
					status("Chest plate free: take it with the hands (2)")
				end
			end
		end
		Tools.show(tools, "Shears", point, camera.CFrame, leftDown)
	end
	if statusLabel and statusLabel.Visible and now > statusUntil then
		statusLabel.Visible = false
	end
end

local function press()
	local ray = mouseRay()
	if ray == nil then
		return
	end
	if tool == "Scalpel" then
		stroke += 1
		lastCut = nil
		strokeDeepest = 0
		cutTravel = 0.15 -- (a bead right where the blade goes in)
		if frontPoint(ray) then
			Sfx.play("Cut", Skin.toWorld(patient.skin, frontPoint(ray) :: Vector2))
		end
	elseif tool == "Hands" then
		local hit = pick(ray)
		local organ = if hit then Organs.find(organs, hit.Instance) else nil
		if hit and organ and not organ.static then
			local why = Organs.grab(organs, organ, hit.Position)
			if why then
				status(why)
			else
				status(organ.label)
			end
			return
		end
		local front = frontPoint(ray)
		if front and Skin.nearCut(patient.skin, front, 3) then
			spreading = front
		elseif front then
			status("Cut the skin first (1 Scalpel)")
		end
	elseif tool == "Shears" then
		shearing = 0
		local hit = pick(ray)
		local organ = if hit then Organs.find(organs, hit.Instance) else nil
		if organ == nil or not organ.locked then
			status(
				if organ
					then "Shears: only the chest plate"
					else "Open the chest, then hold on the chest plate"
			)
		end
	end
end

local function unpress()
	if tool == "Scalpel" and lastCut and operating then
		if strokeDeepest == 1 then
			status("Skin cut: cut along it again for the fat")
		elseif strokeDeepest == 2 then
			status("Once more along the cut: through the muscle")
		elseif strokeDeepest == 3 then
			status("Open: spread it with the hands (2)")
		end
	end
	lastCut = nil
	spreading = nil
	shearing = 0
	if organs.held then
		Organs.release(organs)
	end
end

------------------------------------------------------------------------------
-- Operation mode
------------------------------------------------------------------------------

local exitOperation: () -> ()

local function onAction(
	name: string,
	state: Enum.UserInputState,
	_input: InputObject
): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if name == "AutopsyTool1" or name == "AutopsyTool2" or name == "AutopsyTool3" then
		unpress()
		tool = TOOLS[tonumber(string.sub(name, -1)) :: number]
		Sfx.play("Tray")
		status(tool)
	elseif name == "AutopsyReset" then
		resetPatient()
	elseif name == "AutopsyPixel" then
		pixelWanted = not pixelWanted
		setPixel(pixelWanted)
	elseif name == "AutopsyHide" then
		if hintLabel then
			hintLabel.Visible = not hintLabel.Visible
		end
	elseif name == "AutopsyExit" then
		exitOperation()
	end
	return Enum.ContextActionResult.Sink
end

local function makeHud(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "AutopsyHud"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	-- (catches the clicks: no punch, and frees the mouse in first person)
	local sink = Instance.new("TextButton")
	sink.Name = "Sink"
	sink.Text = ""
	sink.BackgroundTransparency = 1
	sink.Size = UDim2.fromScale(1, 1)
	sink.AutoButtonColor = false
	sink.Modal = true
	sink.Parent = gui
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Text = HINT
	hint.Font = Enum.Font.Arcade
	hint.TextSize = 18
	hint.TextColor3 = Color3.fromRGB(223, 246, 179)
	hint.TextStrokeColor3 = Color3.fromRGB(45, 47, 77)
	hint.TextStrokeTransparency = 0
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -12)
	hint.Size = UDim2.new(1, -24, 0, 22)
	hint.Parent = gui
	hintLabel = hint
	local line = hint:Clone()
	line.Name = "Status"
	line.Text = ""
	line.TextColor3 = Color3.fromRGB(249, 60, 50)
	line.Position = UDim2.new(0.5, 0, 1, -40)
	line.Visible = false
	line.Parent = gui
	statusLabel = line
	return gui
end

-- The overhead lamp (housing, bulb, cables) sits between the camera and
-- the body: hidden (and out of the pixel rays) while operating; its light
-- stays.
local operatePrompt: ProximityPrompt? = nil
local function showLamp(visible: boolean)
	local model = room and room.model
	if model == nil then
		return
	end
	for _, item in model:GetDescendants() do
		if
			item:IsA("BasePart")
			and (item.Name == "LampHousing" or item.Name == "LampBulb" or item.Name == "Cable")
		then
			if not visible and item:GetAttribute("LampTransparency") == nil then
				item:SetAttribute("LampTransparency", item.Transparency)
			end
			local saved = item:GetAttribute("LampTransparency")
			item.Transparency = if visible
				then (if typeof(saved) == "number" then saved else 0)
				else 1
			item.CanQuery = visible
		end
	end
end

local function enterOperation()
	if operating or not inRoom then
		return
	end
	local model, hrp = character()
	if model == nil or hrp == nil then
		return
	end
	operating = true
	if operatePrompt then
		operatePrompt.Enabled = false
	end
	showLamp(false)
	hrp.CFrame = room.stand
	hrp.Anchored = true
	CameraController.setCursorFree("Autopsy", true)
	CameraController.holdRotation("Autopsy", true)
	local camera = workspace.CurrentCamera
	if camera then
		savedFov = camera.FieldOfView
		enterFrom = camera.CFrame
		camera.CameraType = Enum.CameraType.Scriptable
	end
	enterStart = os.clock()
	yaw, pitch, zoom, lift = 0, 0, 6.4, 1.1
	-- only our screen: other HUDs and Roblox's own off
	table.clear(savedGuis)
	for _, gui in player:WaitForChild("PlayerGui"):GetChildren() do
		if gui:IsA("ScreenGui") and gui.Name ~= "AutopsyPixels" and gui.Name ~= "AutopsyHud" then
			savedGuis[gui] = gui.Enabled
			gui.Enabled = false
		end
	end
	table.clear(savedCore)
	for _, kind in Enum.CoreGuiType:GetEnumItems() do
		if kind ~= Enum.CoreGuiType.All then
			savedCore[kind] = StarterGui:GetCoreGuiEnabled(kind)
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	if hud == nil then
		hud = makeHud()
	end
	local gui = hud :: ScreenGui
	gui.Parent = player:WaitForChild("PlayerGui")
	gui.Enabled = true
	tool = "Scalpel"
	RunService:BindToRenderStep("AutopsyCamera", Enum.RenderPriority.Camera.Value + 5, updateCamera)
	local actions: { [string]: { Enum.KeyCode } } = {
		AutopsyTool1 = { Enum.KeyCode.One, Enum.KeyCode.KeypadOne },
		AutopsyTool2 = { Enum.KeyCode.Two, Enum.KeyCode.KeypadTwo },
		AutopsyTool3 = { Enum.KeyCode.Three, Enum.KeyCode.KeypadThree },
		AutopsyReset = { Enum.KeyCode.R },
		AutopsyPixel = { Enum.KeyCode.P },
		AutopsyHide = { Enum.KeyCode.H },
		AutopsyExit = { Enum.KeyCode.F, Enum.KeyCode.Backspace },
	}
	for name, keys in actions do
		ContextActionService:BindActionAtPriority(name, onAction, false, 3000, table.unpack(keys))
	end
	-- (WASD, space: the body stays put)
	ContextActionService:BindActionAtPriority(
		"AutopsyFreeze",
		function()
			return Enum.ContextActionResult.Sink
		end,
		false,
		3000,
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.Space,
		Enum.KeyCode.Q,
		Enum.KeyCode.E
	)
	Sfx.play("Plastic", room.tableTop)
	if pixelWanted then
		-- (the hard cut in: a navy frame first, then the pixels)
		task.delay(0.05, function()
			if operating then
				setPixel(true)
			end
		end)
	end
	status("Scalpel: drag on the chest to cut")
end

exitOperation = function()
	if not operating then
		return
	end
	operating = false
	if operatePrompt then
		operatePrompt.Enabled = true
	end
	showLamp(true)
	unpress()
	leftDown, rightDown = false, false
	setPixel(false)
	Tools.show(tools, nil, Vector3.zero, CFrame.identity, false)
	RunService:UnbindFromRenderStep("AutopsyCamera")
	for _, name in
		{
			"AutopsyTool1",
			"AutopsyTool2",
			"AutopsyTool3",
			"AutopsyReset",
			"AutopsyPixel",
			"AutopsyHide",
			"AutopsyExit",
			"AutopsyFreeze",
		}
	do
		ContextActionService:UnbindAction(name)
	end
	if hud then
		hud.Enabled = false
	end
	for gui, enabled in savedGuis do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	for kind, enabled in savedCore do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(kind, enabled)
		end)
	end
	UserInputService.MouseIconEnabled = true
	CameraController.setCursorFree("Autopsy", false)
	CameraController.holdRotation("Autopsy", false)
	local camera = workspace.CurrentCamera
	local model, hrp = character()
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = savedFov
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	if model and hrp then
		hrp.Anchored = false
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 0
			end
		end
	end
end

------------------------------------------------------------------------------
-- The room: going in / out (local light, ambience)
------------------------------------------------------------------------------

local function enterRoom()
	local _, hrp = character()
	if hrp == nil or inRoom then
		return
	end
	inRoom = true
	hrp.CFrame = room.entry
	hrp.AssemblyLinearVelocity = Vector3.zero
	savedLighting = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		ExposureCompensation = Lighting.ExposureCompensation,
	}
	Lighting.Ambient = Color3.fromRGB(30, 40, 48)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 25, 30)
	Lighting.Brightness = 1
	Lighting.ExposureCompensation = 0
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "AutopsyGrade"
	effect.Saturation = -0.25
	effect.Contrast = 0.15
	effect.TintColor = Color3.fromRGB(225, 240, 255)
	effect.Parent = Lighting
	grade = effect
	hum = Sfx.loop("Hum")
	Sfx.play("Plastic", hrp)
end

-- Out of the room's mood (light, grade, hum), without moving the body.
local function restoreRoom()
	if not inRoom then
		return
	end
	exitOperation()
	inRoom = false
	for key, value in savedLighting do
		(Lighting :: any)[key] = value
	end
	if grade then
		grade:Destroy()
		grade = nil
	end
	if hum then
		hum:Destroy()
		hum = nil
	end
end

local function leaveRoom(to: CFrame)
	if not inRoom then
		return
	end
	restoreRoom()
	local _, hrp = character()
	if hrp then
		hrp.CFrame = to
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
end

------------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------------

local function prompt(
	parent: BasePart,
	action: string,
	object: string,
	key: Enum.KeyCode
): ProximityPrompt
	local made = Instance.new("ProximityPrompt")
	made.ActionText = action
	made.ObjectText = object
	made.KeyboardKeyCode = key
	made.HoldDuration = 0
	made.MaxActivationDistance = 10
	made.RequiresLineOfSight = false
	made.Parent = parent
	return made
end

function Autopsy.start()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = if spawn and spawn:IsA("BasePart") then spawn.Position else Vector3.new(0, 5, 0)
	root = Instance.new("Folder")
	root.Name = "AutopsyVideo"
	root.Parent = workspace
	room = Room.build(base + Vector3.new(0, ROOM_HEIGHT, 0), root)
	tools = Tools.build(root)
	buildPatient()

	-- the way in: a pad next to the spawn (or F8)
	local padAt = base + Vector3.new(8, 0, 0)
	local ground = workspace:Raycast(padAt + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0))
	if ground then
		padAt = ground.Position
	end
	local pad = Make.part({
		Name = "AutopsyPad",
		Size = Vector3.new(3, 0.2, 3),
		CFrame = CFrame.new(padAt + Vector3.new(0, 0.1, 0)),
		Color = Color3.fromRGB(120, 10, 14),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = root,
	})
	local back = CFrame.new(pad.Position + Vector3.new(0, 3, 3))
	prompt(pad, "Enter (video)", "Kill room", Enum.KeyCode.E).Triggered:Connect(enterRoom)
	operatePrompt = prompt(room.tableTop, "Operate", "Patient", Enum.KeyCode.E)
	operatePrompt.Triggered:Connect(enterOperation)
	prompt(room.exitPlate, "Leave", "Kill room", Enum.KeyCode.E).Triggered:Connect(function()
		leaveRoom(back)
	end)

	-- dead or reset in the room: everything back to normal (the new body
	-- spawns down at the spawn)
	local function watch(model: Model)
		local humanoid = model:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Once(restoreRoom)
		end
	end
	player.CharacterAdded:Connect(function(model)
		restoreRoom()
		watch(model)
	end)
	if player.Character then
		task.spawn(watch, player.Character)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == Enum.KeyCode.F8 and not processed then
			if inRoom then
				leaveRoom(back)
			else
				enterRoom()
			end
			return
		end
		if not operating then
			return
		end
		-- (our full-screen button marks the clicks as processed: taken anyway)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			leftDown = true
			press()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightDown = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			leftDown = false
			if operating then
				unpress()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightDown = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not operating then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local wheel = input.Position.Z
			if organs.held then
				lift = math.clamp(lift + wheel * 0.25, 0.4, 3)
			else
				zoom = math.clamp(zoom - wheel * 0.5, 3.5, 9)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and rightDown then
			yaw = math.clamp(yaw - input.Delta.X * 0.006, -math.rad(35), math.rad(35))
			pitch = math.clamp(pitch - input.Delta.Y * 0.004, -math.rad(10), math.rad(10))
		end
	end)

	-- the operation, every frame (after the camera)
	RunService.Heartbeat:Connect(function(dt)
		if operating then
			useTools(dt)
		end
	end)
	-- (quiet drips now and then, in the room)
	task.spawn(function()
		while true do
			task.wait(1.5 + math.random() * 2.5)
			if inRoom and patient.anchor.Parent then
				Sfx.play("Drip", patient.anchor)
			end
		end
	end)
	print("[Autopsy] video mini-game on (Studio only): the red pad next to the spawn, or F8")
end

return Autopsy
