--!strict
-- RiftFx: what Dr. Rift LOOKS like, on this client (the server decided
-- everything; Server/Systems/Combat/Gadgets, Clones).
--
--   • His gear, on anyone with the "Rift" kit (his clones too): a
--     mechanical left arm ending in the gravity glove (plates, pistons,
--     cables, a glowing palm), and a lens for a right eye.
--   • In his hand during a move: the flask (until it leaves the hand), the
--     ray gun (orange core) or the portal gun (green core).
--   • Remotes.RiftFx: a flask flying and bursting (acid: green splash, a
--     smoking puddle; explosive: a fireball, smoke, debris, a shockwave), a
--     ray, portals opening and closing, a shot that fizzles, the gravity
--     glove's shockwave, clones stepping in / out of portals.
--   • "Burning" attribute (acid / fire on someone): smoke, fizz or flames.
--   • The PortalCut finisher's portal round the waist (CinematicController).
--
--   RiftFx.watch(model)                    gear + burning visuals
--   RiftFx.onAction(model, animation)      a move started (props)
--   RiftFx.stopAction(model)               refused / cut short: props away
--   RiftFx.onRemote(kind, data)            Remotes.RiftFx
--   RiftFx.onHit(victim, attacker, moveId) a Rift move landed
--   RiftFx.cinematic(kind, attacker, victim, anchor)   PortalCut events
--   RiftFx.cancelCinematic(attacker)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Finishers = require(ReplicatedStorage.Shared.Finishers)
local Kits = require(ReplicatedStorage.Shared.Kits)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local CharacterAnimationController =
	require(script.Parent.Parent.Controllers.CharacterAnimationController)

local RiftFx = {}

export type Shake = (strength: number, seconds: number) -> ()

local KIT = "Rift"

local P = require(script.Parent.RiftParts)
local STEEL = P.STEEL
local BRASS = P.BRASS
local CABLE = P.CABLE
local RIFT_GREEN = P.RIFT_GREEN
local RIFT_DEEP = P.RIFT_DEEP
local RIFT_GLOW = P.RIFT_GLOW
local SMOKE = P.SMOKE
local RAY_CORE = P.RAY_CORE
local RAY_GLOW = P.RAY_GLOW
local ghost = P.ghost
local stick = P.stick
local disc = P.disc
local attachmentAt = P.attachmentAt
local emitter = P.emitter
local sparkTexture = P.sparkTexture
local fade = P.fade
local floorUnder = P.floorUnder
local shakeNear = P.shakeNear

local RiftGear = require(script.Parent.RiftGear)
local RiftBurn = require(script.Parent.RiftBurn)
local RiftFlask = require(script.Parent.RiftFlask)

local onOwnFizzle: (() -> ())? = nil

-- Our own portal shot fizzled: the move is over sooner (KitController's
-- hold on our attacks is released, CombatEffectsController sets it).
function RiftFx.setOnOwnFizzle(callback: () -> ())
	onOwnFizzle = callback
end

-- CombatEffectsController gives us its camera shake.
RiftFx.setShake = P.setShake

function RiftFx.watch(model: Model)
	RiftGear.watch(model)
	RiftBurn.watch(model)
end
------------------------------------------------------------------------------
-- Props in his right hand
------------------------------------------------------------------------------

local props: { [Model]: { folder: Folder, token: number } } = setmetatable({}, { __mode = "k" }) :: any
local propToken = 0

local function removeProp(model: Model)
	local prop = props[model]
	props[model] = nil
	if prop then
		prop.folder:Destroy()
	end
end

RiftFlask.onReleased(removeProp) -- (the flask left his hand)

-- A gun (ray gun: orange core; portal gun: green core). Its barrel goes
-- along the arm's -Y (with the arm raised, where he aims).
local function buildGun(arm: BasePart, folder: Folder, portal: boolean)
	local glow = if portal then RIFT_GREEN else RAY_GLOW
	local hand = CFrame.new(0, -1.05, 0)
	local along = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis (X) → the arm's Y
	stick(
		arm,
		ghost("Grip", Vector3.new(0.26, 0.5, 0.3), CABLE, Enum.Material.Rubber),
		hand * CFrame.new(0, 0, 0.1),
		folder
	)
	stick(
		arm,
		ghost(
			"Body",
			Vector3.new(1.1, 0.46, 0.46),
			STEEL,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		),
		hand * CFrame.new(0, -0.45, -0.32) * along,
		folder
	)
	local tube =
		ghost("Tube", Vector3.new(0.8, 0.2, 0.2), glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	tube.Transparency = 0.1
	stick(arm, tube, hand * CFrame.new(0, -0.4, -0.62) * along, folder)
	for index = 1, 3 do
		stick(
			arm,
			ghost(
				"Coil",
				Vector3.new(0.08, 0.56, 0.56),
				BRASS,
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			),
			hand * CFrame.new(0, -0.2 - index * 0.17, -0.32) * along,
			folder
		)
	end
	-- The muzzle: a dish (ray) or a glass bulb (portal).
	if portal then
		local bulb = ghost(
			"Bulb",
			Vector3.new(0.42, 0.42, 0.42),
			RIFT_GREEN,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		bulb.Transparency = 0.2
		stick(arm, bulb, hand * CFrame.new(0, -1.08, -0.32), folder)
		local light = Instance.new("PointLight")
		light.Color = RIFT_GREEN
		light.Brightness = 1.2
		light.Range = 6
		light.Parent = bulb
	else
		stick(
			arm,
			ghost(
				"Dish",
				Vector3.new(0.1, 0.7, 0.7),
				BRASS,
				Enum.Material.Metal,
				Enum.PartType.Cylinder
			),
			hand * CFrame.new(0, -1.02, -0.32) * along,
			folder
		)
		local tip = ghost(
			"Tip",
			Vector3.new(0.18, 0.18, 0.18),
			RAY_GLOW,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		stick(arm, tip, hand * CFrame.new(0, -1.12, -0.32), folder)
	end
end

-- `kind` = "Flask" / "Bomb" / "Ray" / "Portal", held for `seconds`.
local function holdProp(model: Model, kind: string, seconds: number)
	removeProp(model)
	local arm = model:FindFirstChild("Right Arm")
	if arm == nil or not arm:IsA("BasePart") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "RiftProp"
	if kind == "Flask" or kind == "Bomb" then
		RiftFlask.buildHeld(arm, folder, if kind == "Bomb" then "Explosive" else "Acid")
	else
		buildGun(arm, folder, kind == "Portal")
	end
	folder.Parent = model
	propToken += 1
	local token = propToken
	props[model] = { folder = folder, token = token }
	task.delay(seconds, function()
		local prop = props[model]
		if prop and prop.token == token then
			removeProp(model)
		end
	end)
end

-- Which prop a clip holds, and for how long.
local function propOf(animation: string): (string?, number)
	local kit = Kits.get(KIT)
	if kit == nil then
		return nil, 0
	end
	local lists = { kit.moves }
	if kit.awakening then
		table.insert(lists, kit.awakening.moves)
	end
	for _, list in lists do
		for _, move in list do
			if move.animation == animation and move.gadget then
				local gadget = move.gadget
				if gadget.flask then
					return if gadget.flask.kind == "Explosive" then "Bomb" else "Flask",
						gadget.flask.release
				elseif gadget.ray then
					return "Ray", move.duration
				elseif gadget.portal then
					return "Portal", move.duration
				end
			end
		end
	end
	return nil, 0
end

-- The muzzle of the gun in his hand (or his hand).
local function muzzleOf(model: Model): Vector3?
	local prop = props[model]
	if prop then
		local tip = prop.folder:FindFirstChild("Tip") or prop.folder:FindFirstChild("Bulb")
		if tip and tip:IsA("BasePart") then
			return tip.Position
		end
	end
	local arm = model:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		return (arm.CFrame * CFrame.new(0, -1.2, 0)).Position
	end
	return nil
end

-- The glove gathering power (the glove moves, the awakening).
local function chargeGlove(model: Model, seconds: number)
	local palm = RiftGear.palmOf(model)
	if palm == nil then
		return
	end
	local pull = emitter(palm, {
		Name = "GloveCharge",
		Color = ColorSequence.new(RIFT_GLOW),
		LightEmission = 1,
		Size = NumberSequence.new(0.25, 0),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.25, 0.4),
		Speed = NumberRange.new(-8, -5), -- (drawn in)
		Rate = 0,
	})
	sparkTexture(pull)
	pull.Shape = Enum.ParticleEmitterShape.Sphere
	pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pull:Emit(30)
	pull.Rate = 60
	task.delay(seconds, function()
		pull.Enabled = false
		Debris:AddItem(pull, 0.5)
	end)
end

function RiftFx.onAction(model: Model, animation: string)
	local kind, seconds = propOf(animation)
	if kind then
		holdProp(model, kind, seconds)
		if kind == "Flask" or kind == "Bomb" then
			task.delay(math.max(0, seconds - 0.12), function()
				if model.Parent then
					SoundController.play("FlaskThrow", model)
				end
			end)
		end
	end
	if animation == "Rift_Glove" or animation == "Rift_Slam" then
		chargeGlove(model, if animation == "Rift_Slam" then 0.55 else 0.36)
	elseif animation == "Rift_Awaken" then
		chargeGlove(model, 0.9)
		RiftFx.onAwaken(model)
	end
end

function RiftFx.stopAction(model: Model)
	removeProp(model)
end

------------------------------------------------------------------------------
-- Portals
------------------------------------------------------------------------------

type Portal = { parts: { BasePart }, sizes: { Vector3 }, folder: Folder, light: PointLight }

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
-- Rays
------------------------------------------------------------------------------

local function ray(data: { [string]: any })
	local from, to, width, big = data.from, data.to, data.width, data.big
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or typeof(width) ~= "number" then
		return
	end
	local by = data.by
	local start = from
	if typeof(by) == "Instance" and by:IsA("Model") then
		start = muzzleOf(by) or from
	end
	local length = (to - start).Magnitude
	if length < 0.1 then
		return
	end
	local along = CFrame.lookAt((start + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
	local seconds = if big == true then 0.45 else 0.22
	-- Core, glow, and (the big one) a wider haze.
	local layers = {
		{ color = RAY_CORE, scale = 0.35, transparency = 0 },
		{ color = RAY_GLOW, scale = 1, transparency = 0.35 },
	}
	if big == true then
		table.insert(
			layers,
			{ color = Color3.fromRGB(255, 60, 20), scale = 1.8, transparency = 0.7 }
		)
	end
	for _, layer in layers do
		local beam = ghost(
			"Ray",
			Vector3.new(length, width * layer.scale, width * layer.scale),
			layer.color,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		beam.Anchored = true
		beam.Transparency = layer.transparency
		beam.CFrame = along
		beam.Parent = workspace
		fade(beam, seconds, { Size = Vector3.new(length, 0.02, 0.02) })
	end
	-- Muzzle flash and the impact: sparks, a glowing scorch.
	for _, position in { start, to } do
		local point = attachmentAt(position)
		local sparks = emitter(point, {
			Color = ColorSequence.new(RAY_CORE, RAY_GLOW),
			LightEmission = 1,
			Size = NumberSequence.new(0.18, 0),
			Lifetime = NumberRange.new(0.15, 0.4),
			Speed = NumberRange.new(8, 20),
			Acceleration = Vector3.new(0, -30, 0),
		})
		sparkTexture(sparks)
		sparks:Emit(if position == to then 30 else 12)
		local light = Instance.new("PointLight")
		light.Color = RAY_GLOW
		light.Brightness = 4
		light.Range = 10
		light.Parent = point
		TweenService:Create(light, TweenInfo.new(seconds + 0.1), { Brightness = 0 }):Play()
		Debris:AddItem(point, 1)
	end
	if typeof(by) == "Instance" and by:IsA("Model") then
		SoundController.play(if big == true then "RayGunBig" else "RayGun", by)
	end
	shakeNear(to, if big == true then 2.5 else 0.8, 0.2)
end

------------------------------------------------------------------------------
-- Shockwave (gravity slam)
------------------------------------------------------------------------------

local function wave(data: { [string]: any })
	local position, radius = data.position, data.radius
	if typeof(position) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	local floor = floorUnder(position + Vector3.new(0, 1, 0))
	local ground = if floor then floor.Position else position
	local up = CFrame.lookAt(ground + Vector3.new(0, 0.12, 0), ground + Vector3.new(0, 1, 0))
	-- A ring of distorted air racing out, a flash in the middle.
	for index, layer in { { color = RIFT_GLOW, t = 0.2 }, { color = RIFT_GREEN, t = 0.55 } } do
		local ring = disc("Wave", layer.color, layer.t)
		ring.CFrame = up * CFrame.new(0, 0, -0.02 * index)
		ring.Size = Vector3.new(1, 1, 0.06)
		ring.Parent = workspace
		fade(ring, 0.4 + index * 0.08, { Size = Vector3.new(radius * 2, radius * 2, 0.06) })
	end
	local point = attachmentAt(ground + Vector3.new(0, 0.3, 0))
	local dust = emitter(point, {
		Color = ColorSequence.new(if floor then floor.Instance.Color:Lerp(SMOKE, 0.5) else SMOKE),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 3),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(radius * 2, radius * 3),
		SpreadAngle = Vector2.new(5, 180),
		Drag = 3,
		EmissionDirection = Enum.NormalId.Right,
	})
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust:Emit(50)
	Debris:AddItem(point, 2)
	flash(ground + Vector3.new(0, 0.5, 0), 1.6)
	shakeNear(ground, 5, 0.45)
	SoundController.playAt("RiftImpact", ground)
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
		RiftFx.watch(clone) -- (dressed even before CombatEffects sees it)
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
	-- On the floor: a flat round one; on a wall: a door.
	if math.abs(exit.LookVector.Y) > 0.7 then
		portal(exit, 4.4, 4.4, 0.22, seconds, 0.25)
	else
		door(exit * CFrame.new(0, 0, 0), seconds)
	end
	SoundController.playAt("PortalOpen", entry.Position)
	SoundController.playAt("PortalOpen", exit.Position)
	task.delay(seconds, function()
		SoundController.playAt("PortalClose", exit.Position)
	end)
end

function RiftFx.onRemote(kind: unknown, data: unknown)
	if typeof(kind) ~= "string" or typeof(data) ~= "table" then
		return
	end
	local info = data :: { [string]: any }
	if kind == "FlaskThrown" then
		RiftFlask.thrown(info)
	elseif kind == "FlaskBurst" then
		RiftFlask.burst(info)
	elseif kind == "Puddle" then
		RiftFlask.puddle(info)
	elseif kind == "Ray" then
		ray(info)
	elseif kind == "PortalShot" then
		local by, to = info.by, info.to
		if typeof(by) == "Instance" and by:IsA("Model") and typeof(to) == "Vector3" then
			local from = muzzleOf(by)
			if from then
				bolt(from, to)
			end
			SoundController.play("PortalShot", by)
		end
	elseif kind == "Portals" then
		portals(info)
	elseif kind == "PortalFizzle" then
		local by, at = info.by, info.at
		local where: Vector3? = if typeof(at) == "Vector3" then at else nil
		if typeof(by) == "Instance" and by:IsA("Model") then
			where = where or muzzleOf(by)
			SoundController.play("PortalFizzle", by)
			-- (our own portal move: the step through won't happen)
			-- (the step through won't happen: everyone stops his clip)
			CharacterAnimationController.stopAction(by, "Rift_Portal")
			if by == Players.LocalPlayer.Character and onOwnFizzle then
				onOwnFizzle()
			end
			removeProp(by)
		end
		if where then
			flash(where, 0.5)
		end
	elseif kind == "Wave" then
		wave(info)
	elseif kind == "CloneIn" then
		cloneIn(info)
	elseif kind == "CloneOut" then
		cloneOut(info)
	end
end

-- A Rift move landed on `victim`: what it does to the body (the burn
-- itself comes from the "Burning" attribute).
function RiftFx.onHit(victim: Model, _attacker: Model, moveId: string)
	if moveId == "GravityGlove" then
		local torso = victim:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			flash(torso.Position, 0.7)
			shakeNear(torso.Position, 3, 0.3)
		end
		SoundController.play("GloveBlast", victim)
	end
end

------------------------------------------------------------------------------
-- PortalCut (the finisher's timeline, CinematicController)
------------------------------------------------------------------------------

type Cut = { ring: Portal?, held: Instance? }
local cuts: { [Model]: Cut } = setmetatable({}, { __mode = "k" }) :: any

function RiftFx.cinematic(kind: string, attacker: Model, victim: Model, anchor: CFrame)
	local cut: Cut = cuts[attacker] or { ring = nil, held = nil }
	cuts[attacker] = cut
	if kind == "Lift" then
		chargeGlove(attacker, 0.9)
		SoundController.play("GloveBlast", attacker)
		local torso = victim:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			-- Held up by the glove: green sparks crawling over them.
			local crawl = emitter(torso, {
				Name = "RiftHold",
				Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
				LightEmission = 1,
				Size = NumberSequence.new(0.15, 0),
				Lifetime = NumberRange.new(0.2, 0.4),
				Speed = NumberRange.new(0.5, 2),
				Rate = 40,
			})
			sparkTexture(crawl)
			crawl.Shape = Enum.ParticleEmitterShape.Box
			cut.held = crawl
			task.delay(2.5, function()
				crawl.Enabled = false
				Debris:AddItem(crawl, 0.5)
			end)
		end
	elseif kind == "Aim" then
		holdProp(attacker, "Portal", 3.4)
	elseif kind == "PortalOpen" then
		-- Flat round their waist: it opens wide, its face up.
		local at = anchor * Finishers.PORTAL_RING
		local flat = CFrame.lookAt(at.Position, at.Position + Vector3.new(0, 1, 0))
		local from = muzzleOf(attacker)
		if from then
			bolt(from, at.Position)
		end
		local diameter = Finishers.PORTAL_RADIUS * 2
		local ring = portal(flat, diameter, diameter, 0.3, -1, 0)
		cut.ring = ring
		-- (never left open if the cut doesn't come: someone left)
		task.delay(2, function()
			if ring.folder.Parent then
				ring.folder:Destroy()
			end
			if cut.ring == ring then
				cut.ring = nil
			end
		end)
		SoundController.play("PortalShot", attacker)
		task.delay(0.1, function()
			SoundController.playAt("PortalOpen", at.Position)
		end)
	elseif kind == "PortalClose" then
		-- It snaps shut, fast, round the waist.
		local ring = cut.ring
		if ring then
			local close = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			for _, part in ring.parts do
				TweenService:Create(part, close, { Size = Vector3.new(0.05, 0.05, 0.06) }):Play()
			end
			TweenService:Create(ring.light, close, { Brightness = 6 }):Play()
		end
		SoundController.playAt("PortalClose", (anchor * Finishers.PORTAL_RING).Position)
	elseif kind == "Cut" then
		local ring = cut.ring
		cut.ring = nil
		if ring then
			ring.folder:Destroy()
		end
		flash((anchor * Finishers.PORTAL_RING).Position, 1.8)
		shakeNear((anchor * Finishers.PORTAL_RING).Position, 4, 0.5)
		SoundController.play("BodyCut", victim)
	end
end

function RiftFx.cancelCinematic(attacker: Model)
	local cut = cuts[attacker]
	cuts[attacker] = nil
	removeProp(attacker)
	if cut then
		if cut.ring then
			cut.ring.folder:Destroy()
		end
		if cut.held then
			cut.held:Destroy()
		end
	end
end

-- (the Awakening: a portal tears open behind him as it starts)
function RiftFx.onAwaken(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		door(root.CFrame * CFrame.new(0, 0, 2.2), 0.8)
		flash(root.Position, 1.2)
		SoundController.play("PortalOpen", model)
		-- (the arms flung out, 0.75 s into Rift_Awaken: the impact)
		task.delay(0.72, function()
			if model.Parent then
				SoundController.play("RiftImpact", model)
			end
		end)
	end
end

return table.freeze(RiftFx)
