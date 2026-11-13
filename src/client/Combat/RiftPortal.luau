--!strict
-- RiftPortal: Dr. Rift's portals, on this client (look only): a portal (a
-- flat disc or a standing door) opening and closing, the green flash, the
-- portal gun's bolt, the two portals of the portal gun (and moving our own
-- character through, see `portals`), clones stepping in / out.
--
--   RiftPortal.portal(cframe, width, height, openTime, stay, closeTime)
--   RiftPortal.door(cframe, stay)       a standing 3.6 x 6 one
--   RiftPortal.flash(position, size)    RiftPortal.bolt(from, to)
--   RiftPortal.portals(data)  RiftPortal.cloneIn(data)  RiftPortal.cloneOut(data)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local P = require(script.Parent.RiftParts)
local RiftGear = require(script.Parent.RiftGear)
local RiftBurn = require(script.Parent.RiftBurn)

local RiftPortal = {}

local RIFT_GREEN = P.RIFT_GREEN
local RIFT_DEEP = P.RIFT_DEEP
local RIFT_GLOW = P.RIFT_GLOW
local ghost = P.ghost
local disc = P.disc
local attachmentAt = P.attachmentAt
local emitter = P.emitter
local sparkTexture = P.sparkTexture

------------------------------------------------------------------------------
-- Portals
------------------------------------------------------------------------------

export type Portal = { parts: { BasePart }, sizes: { Vector3 }, folder: Folder, light: PointLight }

-- A portal at `cframe` (its face = LookVector), `width` x `height` studs.
-- Opens over `openTime`, stays `stay` seconds, then closes over `closeTime`.
local function portal(
	cframe: CFrame,
	width: number,
	height: number,
	openTime: number,
	stay: number,
	closeTime: number
): Portal
	local folder = Instance.new("Folder")
	folder.Name = "RiftPortal"
	local layers = {
		{ name = "Glow", color = RIFT_GLOW, transparency = 0.65, scale = 1.18 },
		{ name = "Rim", color = RIFT_GREEN, transparency = 0.05, scale = 1 },
		{ name = "Swirl", color = Color3.fromRGB(70, 200, 60), transparency = 0.1, scale = 0.86 },
		{ name = "Core", color = RIFT_DEEP, transparency = 0.15, scale = 0.62 },
	}
	local parts: { BasePart } = {}
	local sizes: { Vector3 } = {}
	for index, layer in layers do
		local part = disc(layer.name, layer.color, layer.transparency)
		-- (each layer a hair in front of the last, both ways visible)
		part.CFrame = cframe * CFrame.new(0, 0, -0.012 * index)
		local size = Vector3.new(width * layer.scale, height * layer.scale, 0.06)
		part.Size = Vector3.new(0.05, 0.05, 0.06)
		part.Parent = folder
		table.insert(parts, part)
		table.insert(sizes, size)
	end
	-- Swirling sparks on its face, and its light.
	local swirl = parts[3]
	local sparks = emitter(swirl, {
		Name = "Sparks",
		Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.2, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(1, 3),
		Rate = 50,
		EmissionDirection = Enum.NormalId.Front,
	})
	sparkTexture(sparks)
	sparks.Shape = Enum.ParticleEmitterShape.Disc
	sparks.RotSpeed = NumberRange.new(-200, 200)
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 0
	light.Range = math.max(width, height) * 2.5
	light.Parent = parts[2]
	folder.Parent = workspace
	local info = TweenInfo.new(openTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for index, part in parts do
		TweenService:Create(part, info, { Size = sizes[index] }):Play()
	end
	TweenService:Create(light, TweenInfo.new(openTime), { Brightness = 2.5 }):Play()
	-- The swirl turns.
	local spin = 0
	local base = swirl.CFrame
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		spin += dt * 2.5
		if swirl.Parent then
			swirl.CFrame = base * CFrame.Angles(0, 0, spin)
		end
	end)
	folder.Destroying:Connect(function()
		connection:Disconnect()
	end)
	local made: Portal = { parts = parts, sizes = sizes, folder = folder, light = light }
	if stay >= 0 then
		task.delay(openTime + stay, function()
			if folder.Parent == nil then
				return
			end
			local close = TweenInfo.new(closeTime, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			for _, part in parts do
				TweenService:Create(part, close, { Size = Vector3.new(0.05, 0.05, 0.06) }):Play()
			end
			TweenService:Create(light, TweenInfo.new(closeTime), { Brightness = 0 }):Play()
			sparks.Enabled = false
			Debris:AddItem(folder, closeTime + 0.05)
		end)
	end
	return made
end

-- A standing portal (a door): 3.6 x 6 studs.
local function door(cframe: CFrame, stay: number): Portal
	return portal(cframe, 3.6, 6, 0.22, stay, 0.25)
end

-- A burst of green light and sparks (a shot arriving, a portal snapping).
local function flash(position: Vector3, size: number)
	local point = attachmentAt(position)
	local sparks = emitter(point, {
		Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.3 * size, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.2, 0.5),
		Speed = NumberRange.new(6 * size, 14 * size),
		Drag = 4,
	})
	sparkTexture(sparks)
	sparks:Emit(math.floor(30 * size))
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 4
	light.Range = 10 * size
	light.Parent = point
	TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
	Debris:AddItem(point, 0.7)
end

-- A green bolt flying from `from` to `to` (the portal gun's shot).
local function bolt(from: Vector3, to: Vector3)
	local blob = ghost(
		"PortalShot",
		Vector3.new(0.5, 0.5, 0.5),
		RIFT_GLOW,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	blob.Anchored = true
	blob.CFrame = CFrame.new(from)
	blob.Parent = workspace
	local trail = emitter(blob, {
		Color = ColorSequence.new(RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.35, 0),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.15, 0.25),
		Speed = NumberRange.new(0, 1),
		Rate = 120,
	})
	sparkTexture(trail)
	local seconds = math.clamp((to - from).Magnitude / 160, 0.06, 0.3)
	local tween = TweenService:Create(
		blob,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(to) }
	)
	tween:Play()
	tween.Completed:Connect(function()
		trail.Enabled = false
		blob.Transparency = 1
		Debris:AddItem(blob, 0.3)
		flash(to, 1)
	end)
end

------------------------------------------------------------------------------
-- Clones
------------------------------------------------------------------------------

local function cloneIn(data: { [string]: any })
	local clone, at = data.clone, data.at
	if typeof(at) ~= "CFrame" then
		return
	end
	-- A door opening behind where it appears, it walks out of it.
	door(at * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, math.pi, 0), 0.35)
	flash(at.Position, 0.8)
	SoundController.playAt("PortalOpen", at.Position)
	if typeof(clone) == "Instance" and clone:IsA("Model") then
		RiftGear.watch(clone)
		RiftBurn.watch(clone) -- (dressed even before CombatEffects sees it)
	end
end

local function cloneOut(data: { [string]: any })
	local at = data.at
	if typeof(at) ~= "CFrame" then
		return
	end
	door(at * CFrame.new(0, 0, -0.4), 0.2)
	flash(at.Position, 0.8)
	SoundController.playAt("PortalClose", at.Position)
end

------------------------------------------------------------------------------

local function portals(data: { [string]: any })
	local entry, exit, seconds = data.entry, data.exit, data.seconds
	if typeof(entry) ~= "CFrame" or typeof(exit) ~= "CFrame" or typeof(seconds) ~= "number" then
		return
	end
	door(entry, seconds)
	-- Our own character: we simulate it, so we move it ourselves, at the
	-- moment the server does (else it stays put until the server's move
	-- reaches us).
	local by, land, travelIn = data.by, data.land, data.travelIn
	if
		typeof(by) == "Instance"
		and by == Players.LocalPlayer.Character
		and typeof(land) == "CFrame"
		and typeof(travelIn) == "number"
	then
		local character = by :: Model
		task.delay(math.max(0, travelIn), function()
			local root = character:FindFirstChild("HumanoidRootPart")
			if character.Parent and root and root:IsA("BasePart") then
				character:PivotTo(land)
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end)
	end
	-- On the floor: a flat round one; on a wall: a door.
	if math.abs(exit.LookVector.Y) > 0.7 then
		portal(exit, 4.4, 4.4, 0.22, seconds, 0.25)
	else
		door(exit * CFrame.new(0, 0, 0), seconds)
	end
	-- (one sound for the whole teleport: "Teleport", from the move's start;
	-- the portals closing make none)
end

RiftPortal.portal = portal
RiftPortal.door = door
RiftPortal.flash = flash
RiftPortal.bolt = bolt
RiftPortal.portals = portals
RiftPortal.cloneIn = cloneIn
RiftPortal.cloneOut = cloneOut

return RiftPortal
