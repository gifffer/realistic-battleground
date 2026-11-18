--!strict
-- Vfx/Camera: the ONE owner of the gameplay camera's combat offsets.
--
--   Camera.trauma(amount, at?, radius?)  noise shake (amount² so small hits stay subtle)
--   Camera.kick(worldDir, degrees)       a spring "punch" of the view toward a direction
--   Camera.fovPunch(degrees)             field of view narrowed at once, eased back (~0.3 s)
--   Camera.setBaseFov(fov, tweenTime)    the normal field of view (sprint widens it)
--   Camera.dim(amount, opts)             screen darkened + vignette, recovers linearly
--   Camera.impactFrame(kind)             "KO": 1 frame bright / desaturated, 1 frame dark
--   Camera.desaturate(amount, hold, recover)  the world drained of colour (awakenings)
--   Camera.drain(amount, recover)        the colours drain for an instant (we got hit)
--   Camera.involves(...)                 1 if we are one of these fighters, else 0.4 / 0
--
-- How it plays with the other camera code:
--   • CameraController (shoulder camera) runs at RenderPriority.Camera + 1;
--     our springs / grade / field of view run at Camera + 2, after it.
--   • The shake / kick offset is put on LAST (Camera + 11, after the
--     finisher's own jolt at Camera + 10) and taken back off FIRST
--     (Camera - 2, before the finisher's at Camera - 1), before Roblox's
--     camera runs again (it reads the camera's rotation back: an offset
--     left on would slowly shift where you aim). Put on last, taken off
--     first: the two offsets never get mixed up.
--   • Field of view = base + punch, written only while the camera is
--     "Custom". A cinematic (CinematicController) makes it Scriptable or
--     writes the field of view itself AFTER us (Camera + 10): it wins.
--   • The colour grade (dim, impact frames, drain) is our own
--     ColorCorrectionEffect: it adds to the map's grading, never replaces it.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Camera = {}

local player = Players.LocalPlayer

-- Shake (Squirrel Eiserloh's "trauma", GDC 2016)
local TRAUMA_DECAY = 1.8 -- per second
local MAX_ANGLE = math.rad(1.6)
local MAX_ROLL = math.rad(1.2)
local MAX_OFFSET = 0.18 -- studs
local NOISE_SPEED = 25
-- Kick spring (degrees)
local KICK_STIFFNESS = 300
local KICK_DAMPING = 2 * math.sqrt(KICK_STIFFNESS) * 0.55
-- FOV punch recovery (per second, exponential)
local FOV_RECOVER = 12
local SPECTATOR_RANGE = 40
local SPECTATOR_SCALE = 0.4

local trauma = 0
local kickAngle = Vector2.zero -- (pitch, yaw) degrees
local kickSpeed = Vector2.zero
local fovKick = 0
local baseFov = Config.Camera.DEFAULT_FOV
local baseFrom = baseFov
local baseTo = baseFov
local baseTime = 0
local baseDuration = 0
local applied = CFrame.identity -- the offset on the camera now
local wroteFov = false
local seed = Random.new():NextNumber(0, 1000)

-- Grade contributions (each decays on its own)
type Pulse = { amount: number, hold: number, recover: number, t: number }
local dimPulse: Pulse = { amount = 0, hold = 0, recover = 0.3, t = 0 }
local desatPulse: Pulse = { amount = 0, hold = 0, recover = 0.6, t = 0 }
local drainPulse: Pulse = { amount = 0, hold = 0, recover = 0.18, t = 0 }
local impactKind: string? = nil
local impactFrame = 0
local impactRecover = 0

local grade: ColorCorrectionEffect? = nil
local vignette: Frame? = nil

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

-- 1 if the local character is one of `...`, else SPECTATOR_SCALE within
-- 40 studs of the first one, else 0. (Only the two fighters get the push-in,
-- the kick, the dim; spectators near get a lighter shake.)
function Camera.involves(...: Model?): number
	local character = player.Character
	local first: Model? = nil
	for index = 1, select("#", ...) do
		local model = select(index, ...)
		if model ~= nil then
			if model == character then
				return 1
			end
			first = first or model
		end
	end
	local camera = workspace.CurrentCamera
	if first == nil or camera == nil then
		return 0
	end
	local distance = (first:GetPivot().Position - camera.CFrame.Position).Magnitude
	return if distance < SPECTATOR_RANGE then SPECTATOR_SCALE else 0
end

-- Adds shake. With `at`: weaker the farther the camera is (0 at `radius`, default 60).
function Camera.trauma(amount: number, at: Vector3?, radius: number?)
	local scale = 1
	if at then
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local distance = (camera.CFrame.Position - at).Magnitude
		scale = math.clamp(1 - distance / (radius or 60), 0, 1)
	end
	trauma = math.clamp(trauma + amount * scale, 0, 1)
end

-- Punches the view toward `worldDir` by about `degrees`, springing back in ~0.25 s.
function Camera.kick(worldDir: Vector3, degrees: number)
	local camera = workspace.CurrentCamera
	if camera == nil or worldDir.Magnitude < 1e-4 then
		return
	end
	local local_ = camera.CFrame:VectorToObjectSpace(worldDir.Unit)
	-- yaw: right is -Y rotation; pitch: up is +X rotation
	local direction = Vector2.new(local_.Y, -local_.X)
	if direction.Magnitude < 0.2 then
		direction = Vector2.new(0.3, 0) -- (straight ahead: a small nod)
	end
	kickSpeed += direction.Unit * degrees * math.sqrt(KICK_STIFFNESS) * 1.6
end

-- Narrows the field of view by `degrees` at once (a push-in), eased back.
function Camera.fovPunch(degrees: number)
	fovKick = math.min(fovKick, -math.abs(degrees))
end

-- The normal field of view, reached over `tweenTime` seconds (ease-out).
function Camera.setBaseFov(fov: number, tweenTime: number)
	baseFrom = baseFov
	baseTo = fov
	baseTime = 0
	baseDuration = math.max(0, tweenTime)
	if baseDuration == 0 then
		baseFov = fov
	end
end

export type DimOpts = { edge: number?, recover: number?, preFrames: number? }

-- Darkens the screen by `amount` (0.12 = a heavy hit) with a darker edge
-- (vignette), held `preFrames` frames, then back linearly over `recover` s.
-- A pre-dim (2 frames before contact) can be deepened by the contact's dim.
function Camera.dim(amount: number, opts: DimOpts?)
	local o: DimOpts = opts or {}
	if amount >= dimPulse.amount * (1 - dimPulse.t) then
		dimPulse.amount = amount
		dimPulse.t = 0
		dimPulse.hold = (o.preFrames or 0) / 60
		dimPulse.recover = o.recover or 0.3
	end
	if vignette then
		local edge = o.edge or math.clamp(amount * 3.5, 0, 0.6)
		vignette:SetAttribute("Edge", math.max(edge, vignette:GetAttribute("Edge") :: number? or 0))
	end
end

-- "KO": 1 frame bright, desaturated and contrasty, 1 frame dark, back in
-- 0.25 s. "White": one bright white frame, back in 0.2 s. (Gameplay
-- knockouts only; finisher cinematics have their own.)
function Camera.impactFrame(kind: "KO" | "White")
	impactKind = kind
	impactFrame = 0
	impactRecover = 0
end

-- The world loses `amount` of its colour, held `hold` s, back over `recover` s.
function Camera.desaturate(amount: number, hold: number, recover: number)
	desatPulse.amount = math.max(amount, desatPulse.amount * (1 - desatPulse.t))
	desatPulse.t = 0
	desatPulse.hold = hold
	desatPulse.recover = recover
end

-- The colours drain for an instant (we got hit).
function Camera.drain(amount: number, recover: number)
	drainPulse.amount = math.max(amount, drainPulse.amount * (1 - drainPulse.t))
	drainPulse.t = 0
	drainPulse.hold = 0
	drainPulse.recover = recover
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

-- How much of a pulse is left (1 → 0), advancing its clock.
local function advance(pulse: Pulse, dt: number): number
	if pulse.amount <= 0 then
		return 0
	end
	if pulse.hold > 0 then
		pulse.hold -= dt
		return pulse.amount
	end
	pulse.t += dt / math.max(0.01, pulse.recover)
	if pulse.t >= 1 then
		pulse.amount = 0
		pulse.t = 0
		return 0
	end
	return pulse.amount * (1 - pulse.t)
end

local function updateGrade(dt: number)
	local effect = grade
	if effect == nil then
		return
	end
	local dim = advance(dimPulse, dt)
	local desat = advance(desatPulse, dt)
	local drain = advance(drainPulse, dt)
	local brightness = -dim
	local contrast = dim
	local saturation = -dim * 1.6 - desat - drain
	if impactKind then
		impactFrame += 1
		if impactKind == "KO" then
			if impactFrame == 1 then
				brightness, contrast, saturation = 0.35, 0.6, -1
			elseif impactFrame == 2 then
				brightness, contrast, saturation = -0.35, 0.4, -0.8
			else
				impactRecover += dt / 0.25
				local k = math.max(0, 1 - impactRecover)
				brightness += -0.2 * k
				saturation += -0.8 * k
				if k <= 0 then
					impactKind = nil
				end
			end
		else
			if impactFrame == 1 then
				brightness, contrast, saturation = 0.6, 0.2, -1
			else
				impactRecover += dt / 0.2
				local k = math.max(0, 1 - impactRecover)
				brightness += 0.3 * k
				saturation += -0.6 * k
				if k <= 0 then
					impactKind = nil
				end
			end
		end
	end
	effect.Enabled = brightness ~= 0 or contrast ~= 0 or saturation ~= 0
	effect.Brightness = brightness
	effect.Contrast = contrast
	effect.Saturation = math.max(-1, saturation)

	local frame = vignette
	if frame then
		local edge = (frame:GetAttribute("Edge") :: number?) or 0
		if edge > 0 then
			-- (the vignette follows the dim's recovery)
			local share = if dimPulse.amount > 0 then dim / dimPulse.amount else 0
			if share <= 0 then
				frame:SetAttribute("Edge", 0)
			end
			frame.Visible = share > 0
			for _, child in frame:GetChildren() do
				if child:IsA("Frame") then
					child.BackgroundTransparency = 1 - edge * share
				end
			end
		else
			frame.Visible = false
		end
	end
end

-- Before Roblox's camera: take our offset back off.
local function takeOff()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	if applied ~= CFrame.identity then
		if camera.CameraType == Enum.CameraType.Custom then
			camera.CFrame *= applied:Inverse()
		end
		applied = CFrame.identity
	end
end

-- After the camera scripts: springs, grade and field of view.
local function update(dt: number)
	updateGrade(dt)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local step = math.min(dt, 1 / 30)
	-- Base FOV tween (ease-out quad)
	if baseTime < baseDuration then
		baseTime += dt
		local a = math.clamp(baseTime / baseDuration, 0, 1)
		a = 1 - (1 - a) * (1 - a)
		baseFov = baseFrom + (baseTo - baseFrom) * a
	end
	-- Kick spring
	local acceleration = -kickAngle * KICK_STIFFNESS - kickSpeed * KICK_DAMPING
	kickSpeed += acceleration * step
	kickAngle += kickSpeed * step
	if kickAngle.Magnitude < 0.005 and kickSpeed.Magnitude < 0.05 then
		kickAngle, kickSpeed = Vector2.zero, Vector2.zero
	end
	fovKick *= math.exp(-FOV_RECOVER * dt)
	if math.abs(fovKick) < 0.01 then
		fovKick = 0
	end
	trauma = math.max(0, trauma - TRAUMA_DECAY * dt)

	if camera.CameraType ~= Enum.CameraType.Custom then
		wroteFov = false
		return -- a cinematic owns the camera
	end
	-- Field of view: written while it moves, and once more when it settles.
	local fov = baseFov + fovKick
	if fovKick ~= 0 or baseTime < baseDuration + dt or wroteFov then
		camera.FieldOfView = fov
		wroteFov = fovKick ~= 0 or baseTime < baseDuration
	end
end

-- Last of all the camera scripts: put this frame's shake / kick offset on.
local function apply()
	local camera = workspace.CurrentCamera
	if camera == nil or camera.CameraType ~= Enum.CameraType.Custom then
		return -- (a cinematic owns the camera)
	end
	local shake = trauma * trauma
	local offset = CFrame.identity
	if shake > 0 then
		local t = os.clock() * NOISE_SPEED
		local pitch = MAX_ANGLE * shake * math.noise(seed, t)
		local yaw = MAX_ANGLE * shake * math.noise(seed + 10, t)
		local roll = MAX_ROLL * shake * math.noise(seed + 20, t)
		local move = Vector3.new(math.noise(seed + 30, t), math.noise(seed + 40, t), 0)
			* (MAX_OFFSET * shake)
		offset = CFrame.new(move) * CFrame.Angles(pitch, yaw, roll)
	end
	if kickAngle ~= Vector2.zero then
		offset *= CFrame.Angles(math.rad(kickAngle.X), math.rad(kickAngle.Y), 0)
	end
	if offset ~= CFrame.identity then
		camera.CFrame *= offset
		applied = offset
	end
end

local function makeVignette(): Frame?
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if gui == nil then
		return nil
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "VfxVignette"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = -5 -- (under the HUD)
	local root = Instance.new("Frame")
	root.Name = "Edges"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = screen
	-- Four edge bands, black → transparent toward the centre (no texture).
	type Band = { size: UDim2, position: UDim2, rotation: number }
	local bands: { Band } = {
		{ size = UDim2.fromScale(1, 0.32), position = UDim2.fromScale(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, 0.32), position = UDim2.fromScale(0, 0.68), rotation = -90 },
		{ size = UDim2.fromScale(0.28, 1), position = UDim2.fromScale(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(0.28, 1), position = UDim2.fromScale(0.72, 0), rotation = 180 },
	}
	for index, band in bands do
		local frame = Instance.new("Frame")
		frame.Name = `Band{index}`
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 1
		frame.Size = band.size
		frame.Position = band.position
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = band.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		frame.Parent = root
	end
	screen.Parent = gui
	return root
end

local started = false

function Camera.start()
	if started then
		return
	end
	started = true
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "VfxGrade"
	effect.Enabled = false
	effect.Parent = Lighting
	grade = effect
	vignette = makeVignette()
	if vignette == nil then
		-- (PlayerGui not there yet this early: make it once it is)
		task.spawn(function()
			player:WaitForChild("PlayerGui")
			vignette = makeVignette()
		end)
	end
	baseFov = if player:GetAttribute("Sprinting") == true
		then Config.Camera.SPRINT_FOV
		else Config.Camera.DEFAULT_FOV
	baseTo = baseFov
	RunService:BindToRenderStep("VfxCameraOff", Enum.RenderPriority.Camera.Value - 2, takeOff)
	RunService:BindToRenderStep("VfxCamera", Enum.RenderPriority.Camera.Value + 2, update)
	RunService:BindToRenderStep("VfxCameraShake", Enum.RenderPriority.Camera.Value + 11, apply)
end

return Camera
