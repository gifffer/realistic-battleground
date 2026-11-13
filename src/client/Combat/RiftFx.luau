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

-- Colours.
local STEEL = Color3.fromRGB(96, 98, 102)
local STEEL_DARK = Color3.fromRGB(52, 54, 58)
local BRASS = Color3.fromRGB(138, 112, 64)
local RUST = Color3.fromRGB(104, 62, 40)
local CABLE = Color3.fromRGB(28, 28, 30)
local RIFT_GREEN = Color3.fromRGB(110, 255, 96)
local RIFT_DEEP = Color3.fromRGB(26, 120, 40)
local RIFT_GLOW = Color3.fromRGB(170, 255, 150)
local ACID = Color3.fromRGB(150, 230, 40)
local ACID_DARK = Color3.fromRGB(82, 120, 20)
local FIRE = Color3.fromRGB(255, 140, 40)
local FIRE_HOT = Color3.fromRGB(255, 230, 150)
local SMOKE = Color3.fromRGB(70, 68, 64)
local RAY_CORE = Color3.fromRGB(255, 236, 200)
local RAY_GLOW = Color3.fromRGB(255, 96, 40)
local GLASS = Color3.fromRGB(200, 220, 210)

local SHAKE_RANGE = 45
local random = Random.new()
local shakeCallback: Shake? = nil

-- CombatEffectsController gives us its camera shake.
function RiftFx.setShake(shake: Shake)
	shakeCallback = shake
end

local function shakeNear(position: Vector3, strength: number, seconds: number)
	local camera = workspace.CurrentCamera
	if shakeCallback == nil or camera == nil then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance < SHAKE_RANGE then
		shakeCallback(strength * (1 - distance / SHAKE_RANGE), seconds)
	end
end

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------

-- A part that only shows (no collisions, no hits, no weight).
local function ghost(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Welds `part` to `base` at `offset` (base space) and parents it.
local function stick(base: BasePart, part: BasePart, offset: CFrame, parent: Instance)
	part.CFrame = base.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = parent
end

-- A flat ellipse (a portal's layer): a part with a sphere mesh squashed flat.
local function disc(name: string, color: Color3, transparency: number): Part
	local part = ghost(name, Vector3.new(1, 1, 0.06), color, Enum.Material.Neon)
	part.Transparency = transparency
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Anchored = true
	return part
end

local function attachmentAt(position: Vector3): Attachment
	local point = Instance.new("Attachment")
	point.WorldPosition = position
	point.Parent = workspace.Terrain
	return point
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particles.Rate = 0
	particles.LightEmission = 0
	particles.Speed = NumberRange.new(2, 5)
	particles.Lifetime = NumberRange.new(0.4, 0.8)
	particles.SpreadAngle = Vector2.new(180, 180)
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

local function sparkTexture(particles: ParticleEmitter)
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
end

local function fade(part: BasePart, seconds: number, goal: { [string]: any }?)
	local props: { [string]: any } = goal or {}
	props.Transparency = 1
	TweenService
		:Create(
			part,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			props
		)
		:Play()
	Debris:AddItem(part, seconds + 0.05)
end

local function floorUnder(position: Vector3, ignore: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), params)
end

------------------------------------------------------------------------------
-- His gear (anyone with the Rift kit)
------------------------------------------------------------------------------

local gear: { [Model]: Folder } = setmetatable({}, { __mode = "k" }) :: any

-- The mechanical left arm (Left Arm space: 1 x 2 x 1, the hand at Y = -1).
local function buildArm(arm: BasePart, folder: Folder)
	local function add(part: BasePart, offset: CFrame)
		stick(arm, part, offset, folder)
	end
	-- Shoulder cap: a dented plate, bolted.
	add(
		ghost("Cap", Vector3.new(1.16, 0.5, 1.14), STEEL, Enum.Material.DiamondPlate),
		CFrame.new(0, 0.78, 0)
	)
	add(
		ghost("CapRim", Vector3.new(1.2, 0.08, 1.18), RUST, Enum.Material.CorrodedMetal),
		CFrame.new(0, 0.52, 0)
	)
	-- Upper arm: two side rails and a piston.
	for _, x in { -0.53, 0.53 } do
		add(
			ghost("Rail", Vector3.new(0.1, 0.9, 0.3), STEEL_DARK, Enum.Material.Metal),
			CFrame.new(x, 0.08, 0)
		)
	end
	add(
		ghost(
			"Piston",
			Vector3.new(0.9, 0.12, 0.12),
			BRASS,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		),
		CFrame.new(0, 0.1, -0.54) * CFrame.Angles(0, 0, math.rad(90))
	)
	-- Elbow: a ball joint between two plates.
	add(
		ghost(
			"Elbow",
			Vector3.new(0.62, 0.62, 0.62),
			STEEL_DARK,
			Enum.Material.Metal,
			Enum.PartType.Ball
		),
		CFrame.new(0, -0.38, 0.32)
	)
	-- Forearm: a full casing, a glowing core window, cables.
	add(
		ghost("Forearm", Vector3.new(1.1, 0.78, 1.1), STEEL, Enum.Material.Metal),
		CFrame.new(0, -0.55, 0)
	)
	local core = ghost("Core", Vector3.new(0.34, 0.5, 0.06), RIFT_GREEN, Enum.Material.Neon)
	add(core, CFrame.new(0, -0.55, -0.56))
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 0.8
	light.Range = 5
	light.Parent = core
	for index, x in { -0.3, 0.3 } do
		add(
			ghost("Cable", Vector3.new(0.09, 1.1, 0.09), CABLE, Enum.Material.Rubber),
			CFrame.new(x, -0.1, 0.56) * CFrame.Angles(math.rad(index * 6 - 9), 0, 0)
		)
	end
	-- Wrist ring.
	add(
		ghost(
			"Wrist",
			Vector3.new(0.16, 1.18, 1.18),
			BRASS,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		),
		CFrame.new(0, -0.98, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	-- The glove: a heavy metal hand, three thick fingers, the palm emitter.
	add(
		ghost("Glove", Vector3.new(1.12, 0.36, 1.12), STEEL_DARK, Enum.Material.DiamondPlate),
		CFrame.new(0, -1.16, 0)
	)
	for index = -1, 1 do
		add(
			ghost("Finger", Vector3.new(0.26, 0.34, 0.3), STEEL, Enum.Material.Metal),
			CFrame.new(index * 0.34, -1.48, -0.3)
		)
	end
	add(
		ghost("Thumb", Vector3.new(0.26, 0.3, 0.28), STEEL, Enum.Material.Metal),
		CFrame.new(0.5, -1.3, 0.12)
	)
	local palm = ghost(
		"Palm",
		Vector3.new(0.5, 0.5, 0.06),
		RIFT_GLOW,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	palm.Size = Vector3.new(0.06, 0.5, 0.5)
	add(palm, CFrame.new(0, -1.36, -0.02) * CFrame.Angles(0, 0, math.rad(90)))
	local hum = emitter(palm, {
		Name = "PalmHum",
		Color = ColorSequence.new(RIFT_GLOW, RIFT_GREEN),
		LightEmission = 1,
		Size = NumberSequence.new(0.18, 0),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(0.2, 0.35),
		Speed = NumberRange.new(0.5, 1.5),
		Rate = 6,
	})
	sparkTexture(hum)
end

-- The lens for a right eye (Head space; the face looks at -Z).
local function buildEye(head: BasePart, folder: Folder)
	local size = head.Size
	local eye = CFrame.new(size.X * 0.2, size.Y * 0.1, -size.Z / 2)
	local ring = ghost(
		"LensRing",
		Vector3.new(0.12, 0.42, 0.42),
		BRASS,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	stick(head, ring, eye * CFrame.new(0, 0, -0.04) * CFrame.Angles(0, math.rad(90), 0), folder)
	local lens = ghost(
		"Lens",
		Vector3.new(0.13, 0.28, 0.28),
		RIFT_GREEN,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	stick(head, lens, eye * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, math.rad(90), 0), folder)
	local light = Instance.new("PointLight")
	light.Color = RIFT_GREEN
	light.Brightness = 0.6
	light.Range = 3
	light.Parent = lens
	-- The strap round the head and a plate over the temple.
	stick(
		head,
		ghost(
			"Strap",
			Vector3.new(size.X + 0.04, 0.12, size.Z + 0.04),
			CABLE,
			Enum.Material.Leather
		),
		CFrame.new(0, size.Y * 0.1, 0),
		folder
	)
	stick(
		head,
		ghost("Temple", Vector3.new(0.1, 0.36, 0.42), STEEL, Enum.Material.Metal),
		CFrame.new(size.X / 2 + 0.02, size.Y * 0.1, -0.05),
		folder
	)
end

local function removeGear(model: Model)
	local folder = gear[model]
	gear[model] = nil
	if folder then
		folder:Destroy()
	end
end

local function dress(model: Model)
	removeGear(model)
	local arm = model:FindFirstChild("Left Arm")
	local head = model:FindFirstChild("Head")
	if arm == nil or not arm:IsA("BasePart") or head == nil or not head:IsA("BasePart") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "RiftGear"
	buildArm(arm, folder)
	-- (the eye's parts go under the head: hidden with it if it bursts)
	local eyeFolder = Instance.new("Folder")
	eyeFolder.Name = "RiftEye"
	buildEye(head, eyeFolder)
	eyeFolder.Parent = head
	folder.Parent = model
	gear[model] = folder
	folder.Destroying:Connect(function()
		eyeFolder:Destroy()
	end)
end

------------------------------------------------------------------------------
-- Burning (acid / fire): the "Burning" attribute
------------------------------------------------------------------------------

local burning: { [Model]: { Instance } } = setmetatable({}, { __mode = "k" }) :: any

local function stopBurning(model: Model)
	local items = burning[model]
	burning[model] = nil
	if items == nil then
		return
	end
	for _, item in items do
		if item:IsA("ParticleEmitter") then
			item.Enabled = false
			Debris:AddItem(item, 1.5)
		else
			Debris:AddItem(item, 0)
		end
	end
end

local function startBurning(model: Model, kind: string)
	stopBurning(model)
	local items: { Instance } = {}
	for _, name in { "Torso", "Head", "Right Arm", "Left Arm" } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			if kind == "Fire" then
				local flames = emitter(part, {
					Name = "RiftFlames",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, FIRE_HOT),
						ColorSequenceKeypoint.new(0.4, FIRE),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 30, 10)),
					}),
					LightEmission = 0.8,
					Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.5),
						NumberSequenceKeypoint.new(1, 0.1),
					}),
					Transparency = NumberSequence.new(0.2, 1),
					Lifetime = NumberRange.new(0.3, 0.6),
					Speed = NumberRange.new(2, 4),
					SpreadAngle = Vector2.new(20, 20),
					Acceleration = Vector3.new(0, 6, 0),
					EmissionDirection = Enum.NormalId.Top,
					Rate = if name == "Torso" then 30 else 12,
				})
				table.insert(items, flames)
			else
				-- Acid: it fizzes on the skin, yellow-green fumes.
				local fizz = emitter(part, {
					Name = "RiftFizz",
					Color = ColorSequence.new(ACID, ACID_DARK),
					LightEmission = 0.3,
					Size = NumberSequence.new(0.12, 0.02),
					Transparency = NumberSequence.new(0.1, 1),
					Lifetime = NumberRange.new(0.2, 0.4),
					Speed = NumberRange.new(1, 3),
					Rate = if name == "Torso" then 25 else 10,
				})
				sparkTexture(fizz)
				table.insert(items, fizz)
			end
			local smoke = emitter(part, {
				Name = "RiftBurnSmoke",
				Color = ColorSequence.new(
					if kind == "Fire" then SMOKE else Color3.fromRGB(150, 170, 90)
				),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.4),
					NumberSequenceKeypoint.new(1, 1.6),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.55),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(1, 2),
				SpreadAngle = Vector2.new(25, 25),
				Acceleration = Vector3.new(0, 3, 0),
				EmissionDirection = Enum.NormalId.Top,
				Rate = if name == "Torso" then 10 else 4,
			})
			table.insert(items, smoke)
		end
	end
	local torso = model:FindFirstChild("Torso")
	if kind == "Fire" and torso and torso:IsA("BasePart") then
		local light = Instance.new("PointLight")
		light.Name = "RiftFireLight"
		light.Color = FIRE
		light.Brightness = 1.5
		light.Range = 8
		light.Parent = torso
		table.insert(items, light)
	end
	burning[model] = items
	SoundController.play(if kind == "Fire" then "Burn" else "AcidSizzle", model)
end

local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function RiftFx.watch(model: Model)
	if watched[model] then
		return
	end
	watched[model] = true
	local function refreshGear()
		if model:GetAttribute("Kit") == KIT then
			local current: Folder? = gear[model]
			if current == nil then
				dress(model)
			end
		else
			removeGear(model)
		end
	end
	local function refreshBurn()
		local kind = model:GetAttribute("Burning")
		if typeof(kind) == "string" then
			startBurning(model, kind)
		else
			stopBurning(model)
		end
	end
	model:GetAttributeChangedSignal("Kit"):Connect(refreshGear)
	model:GetAttributeChangedSignal("Burning"):Connect(refreshBurn)
	refreshGear()
	refreshBurn()
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

-- A flask (Right Arm space: in the fist at Y = -1).
local function buildFlask(arm: BasePart, folder: Folder, kind: string)
	local liquid = if kind == "Explosive" then FIRE else ACID
	local hand = CFrame.new(0, -1.15, -0.1)
	local body = ghost(
		"Glass",
		Vector3.new(0.55, 0.55, 0.55),
		GLASS,
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	body.Transparency = 0.45
	stick(arm, body, hand * CFrame.new(0, -0.2, 0), folder)
	local inside = ghost(
		"Liquid",
		Vector3.new(0.42, 0.42, 0.42),
		liquid,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	inside.Transparency = 0.1
	stick(arm, inside, hand * CFrame.new(0, -0.24, 0), folder)
	stick(
		arm,
		ghost(
			"Neck",
			Vector3.new(0.3, 0.16, 0.16),
			GLASS,
			Enum.Material.Glass,
			Enum.PartType.Cylinder
		),
		hand * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		folder
	)
	stick(
		arm,
		ghost(
			"Cork",
			Vector3.new(0.12, 0.18, 0.18),
			Color3.fromRGB(120, 86, 52),
			Enum.Material.Wood,
			Enum.PartType.Cylinder
		),
		hand * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		folder
	)
	local light = Instance.new("PointLight")
	light.Color = liquid
	light.Brightness = 0.8
	light.Range = 4
	light.Parent = inside
end

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
		buildFlask(arm, folder, if kind == "Bomb" then "Explosive" else "Acid")
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
	local folder = gear[model]
	local palm = if folder then folder:FindFirstChild("Palm") else nil
	if palm == nil or not palm:IsA("BasePart") then
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
-- Flasks
------------------------------------------------------------------------------

type Flight = { part: BasePart, connection: RBXScriptConnection }
local flying: { [number]: Flight } = {}

local function flaskModel(kind: string, at: CFrame): BasePart
	local liquid = if kind == "Explosive" then FIRE else ACID
	local body = ghost(
		"Flask",
		Vector3.new(0.55, 0.55, 0.55),
		GLASS,
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	body.Transparency = 0.45
	body.Anchored = true
	body.CFrame = at
	local inside = ghost(
		"Liquid",
		Vector3.new(0.42, 0.42, 0.42),
		liquid,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	inside.Anchored = true
	inside.CFrame = at
	inside.Parent = body
	local trail = emitter(body, {
		Color = ColorSequence.new(liquid),
		LightEmission = 0.6,
		Size = NumberSequence.new(0.12, 0),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.2, 0.35),
		Speed = NumberRange.new(0, 0.5),
		Rate = 40,
	})
	sparkTexture(trail)
	return body
end

local function thrown(data: { [string]: any })
	local id, kind, origin, velocity, gravity =
		data.id, data.kind, data.origin, data.velocity, data.gravity
	if
		typeof(id) ~= "number"
		or typeof(kind) ~= "string"
		or typeof(origin) ~= "Vector3"
		or typeof(velocity) ~= "Vector3"
		or typeof(gravity) ~= "number"
	then
		return
	end
	local by = data.by
	if typeof(by) == "Instance" and by:IsA("Model") then
		removeProp(by) -- (it left the hand)
	end
	local part = flaskModel(kind, CFrame.new(origin))
	part.Parent = workspace
	local position, moving = origin, velocity
	local spin = 0
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		position += moving * dt
		moving -= Vector3.new(0, gravity * dt, 0)
		spin += dt * 14
		local cframe = CFrame.new(position) * CFrame.Angles(spin, spin * 0.6, 0)
		part.CFrame = cframe
		local inside = part:FindFirstChild("Liquid")
		if inside and inside:IsA("BasePart") then
			inside.CFrame = cframe
		end
		if os.clock() - started > 4 then
			local flight = flying[id]
			if flight then
				flying[id] = nil
				flight.connection:Disconnect()
				flight.part:Destroy()
			end
		end
	end)
	flying[id] = { part = part, connection = connection }
end

-- Bits of glass flying out of a burst.
local function shards(position: Vector3, count: number)
	for _ = 1, count do
		local shard = ghost(
			"Shard",
			Vector3.new(0.05, 0.03, random:NextNumber(0.08, 0.2)),
			GLASS,
			Enum.Material.Glass
		)
		shard.Transparency = 0.3
		shard.CanCollide = true
		shard.Massless = false
		shard.CFrame = CFrame.new(position)
			* CFrame.Angles(random:NextNumber(0, 6.3), random:NextNumber(0, 6.3), 0)
		shard.AssemblyLinearVelocity = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(0.2, 1),
			random:NextNumber(-1, 1)
		) * 16
		shard.Parent = workspace
		Debris:AddItem(shard, 5)
	end
end

local function acidBurst(position: Vector3, radius: number)
	local point = attachmentAt(position)
	local splash = emitter(point, {
		Color = ColorSequence.new(ACID, ACID_DARK),
		LightEmission = 0.4,
		Size = NumberSequence.new(0.35, 0.1),
		Transparency = NumberSequence.new(0, 0.6),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(radius * 1.2, radius * 2.6),
		Acceleration = Vector3.new(0, -50, 0),
		Drag = 1,
	})
	splash:Emit(70)
	local fumes = emitter(point, {
		Color = ColorSequence.new(Color3.fromRGB(170, 200, 90)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, radius * 0.9),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(0, 2, 0),
	})
	fumes:Emit(14)
	local light = Instance.new("PointLight")
	light.Color = ACID
	light.Brightness = 2.5
	light.Range = radius * 2
	light.Parent = point
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	Debris:AddItem(point, 2.5)
	SoundController.playAt("FlaskBreak", position)
	SoundController.playAt("AcidSizzle", position)
end

local function explosion(position: Vector3, radius: number)
	-- The fireball: a ball of light that swells and fades, a hot core.
	local ball =
		ghost("Fireball", Vector3.new(1, 1, 1), FIRE, Enum.Material.Neon, Enum.PartType.Ball)
	ball.Anchored = true
	ball.CFrame = CFrame.new(position)
	ball.Transparency = 0.05
	ball.Parent = workspace
	fade(ball, 0.45, { Size = Vector3.one * radius * 1.4, Color = Color3.fromRGB(120, 40, 10) })
	local core =
		ghost("Core", Vector3.new(0.6, 0.6, 0.6), FIRE_HOT, Enum.Material.Neon, Enum.PartType.Ball)
	core.Anchored = true
	core.CFrame = CFrame.new(position)
	core.Parent = workspace
	fade(core, 0.25, { Size = Vector3.one * radius * 0.8 })
	local point = attachmentAt(position)
	local fire = emitter(point, {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, FIRE_HOT),
			ColorSequenceKeypoint.new(0.3, FIRE),
			ColorSequenceKeypoint.new(1, SMOKE),
		}),
		LightEmission = 0.7,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(1, radius * 0.7),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(radius * 1.5, radius * 3),
		Drag = 5,
	})
	fire:Emit(40)
	local smoke = emitter(point, {
		Color = ColorSequence.new(Color3.fromRGB(40, 38, 36)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(1, radius * 1.2),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(2, 6),
		Acceleration = Vector3.new(0, 4, 0),
		Drag = 1,
	})
	smoke:Emit(18)
	local embers = emitter(point, {
		Color = ColorSequence.new(FIRE_HOT, FIRE),
		LightEmission = 1,
		Size = NumberSequence.new(0.12, 0),
		Lifetime = NumberRange.new(0.6, 1.4),
		Speed = NumberRange.new(20, 45),
		Acceleration = Vector3.new(0, -40, 0),
	})
	sparkTexture(embers)
	embers:Emit(60)
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Brightness = 8
	light.Range = radius * 4
	light.Parent = point
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(point, 4)
	-- The shockwave on the floor and a scorch mark.
	local floor = floorUnder(position, {})
	if floor then
		local ring = disc("Shock", FIRE_HOT, 0.3)
		ring.CFrame = CFrame.lookAt(
			floor.Position + Vector3.new(0, 0.1, 0),
			floor.Position + Vector3.new(0, 1, 0)
		)
		ring.Size = Vector3.new(1, 1, 0.06)
		ring.Parent = workspace
		fade(ring, 0.35, { Size = Vector3.new(radius * 2.4, radius * 2.4, 0.06) })
		local scorch = ghost(
			"Scorch",
			Vector3.new(0.05, radius * 1.1, radius * 1.1),
			Color3.fromRGB(22, 20, 18),
			Enum.Material.Slate,
			Enum.PartType.Cylinder
		)
		scorch.Anchored = true
		scorch.CFrame = CFrame.new(floor.Position + Vector3.new(0, 0.03, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		scorch.Transparency = 0.25
		scorch.Parent = workspace
		task.delay(12, function()
			fade(scorch, 3)
		end)
	end
	shakeNear(position, 6, 0.5)
	SoundController.playAt("Explosion", position)
end

local function burst(data: { [string]: any })
	local id, kind, position, radius = data.id, data.kind, data.position, data.radius
	if typeof(kind) ~= "string" or typeof(position) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	if typeof(id) == "number" then
		local flight = flying[id]
		if flight then
			flying[id] = nil
			flight.connection:Disconnect()
			flight.part:Destroy()
		end
	end
	shards(position, 10)
	if kind == "Explosive" then
		explosion(position, radius)
	else
		acidBurst(position, radius)
	end
end

-- The acid on the floor: a bubbling, smoking stain that spreads, then dries.
local function puddle(data: { [string]: any })
	local position, radius, seconds = data.position, data.radius, data.seconds
	if
		typeof(position) ~= "Vector3"
		or typeof(radius) ~= "number"
		or typeof(seconds) ~= "number"
	then
		return
	end
	local stain = disc("AcidPuddle", ACID, 0.25)
	stain.Material = Enum.Material.Glass
	stain.CFrame =
		CFrame.lookAt(position + Vector3.new(0, 0.06, 0), position + Vector3.new(0, 1, 0))
	stain.Size = Vector3.new(0.5, 0.5, 0.06)
	stain.Parent = workspace
	TweenService:Create(stain, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Size = Vector3.new(radius * 2, radius * 1.8, 0.06),
	}):Play()
	local glow = disc("AcidGlow", ACID, 0.6)
	glow.CFrame = stain.CFrame * CFrame.new(0, 0, -0.02)
	glow.Size = Vector3.new(radius * 1.2, radius * 1.1, 0.06)
	glow.Parent = workspace
	local bubbles = emitter(stain, {
		Color = ColorSequence.new(ACID),
		LightEmission = 0.3,
		Size = NumberSequence.new(0.18, 0.05),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(0.5, 2),
		Rate = 30,
		EmissionDirection = Enum.NormalId.Front,
	})
	bubbles.Shape = Enum.ParticleEmitterShape.Disc
	local fumes = emitter(stain, {
		Color = ColorSequence.new(Color3.fromRGB(170, 200, 90)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 2.4),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = Vector3.new(0, 2, 0),
		Rate = 8,
		EmissionDirection = Enum.NormalId.Front,
	})
	fumes.Shape = Enum.ParticleEmitterShape.Disc
	task.delay(seconds, function()
		bubbles.Enabled = false
		fumes.Enabled = false
		fade(stain, 1.2, { Color = ACID_DARK })
		fade(glow, 0.6)
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
	local by = data.by
	local ignore: { Instance } = {}
	if typeof(by) == "Instance" then
		table.insert(ignore, by)
	end
	local floor = floorUnder(position + Vector3.new(0, 1, 0), ignore)
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
	SoundController.playAt("GloveBlast", ground)
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
		thrown(info)
	elseif kind == "FlaskBurst" then
		burst(info)
	elseif kind == "Puddle" then
		puddle(info)
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
			if by == Players.LocalPlayer.Character then
				CharacterAnimationController.stopAction(by, "Rift_Portal")
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
		cut.ring = portal(flat, diameter, diameter, 0.3, -1, 0)
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
	end
end

return table.freeze(RiftFx)
