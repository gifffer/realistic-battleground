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
local RIFT_GLOW = P.RIFT_GLOW
local RAY_GLOW = P.RAY_GLOW
local ghost = P.ghost
local stick = P.stick
local emitter = P.emitter
local sparkTexture = P.sparkTexture
local shakeNear = P.shakeNear

local RiftGear = require(script.Parent.RiftGear)
local RiftBurn = require(script.Parent.RiftBurn)
local RiftFlask = require(script.Parent.RiftFlask)
local RiftPortal = require(script.Parent.RiftPortal)
local RiftRay = require(script.Parent.RiftRay)
local RiftGlove = require(script.Parent.RiftGlove)
local flash = RiftPortal.flash
local bolt = RiftPortal.bolt
local chargeGlove = RiftGlove.charge

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
-- The RiftGear meshes when the place has them (Combat/RiftAssets: grip,
-- trigger guard, coils, a glass tube of glowing fluid, the dish or the glass
-- bulb), else a simpler gun from parts. Either way the muzzle is a part
-- named "Tip" or "Bulb" right in `folder` (muzzleOf looks there).
local function buildGun(arm: BasePart, folder: Folder, portal: boolean)
	local glow = if portal then RIFT_GREEN else RAY_GLOW
	local RiftAssets = require(script.Parent.RiftAssets)
	local main = RiftAssets.spawn(if portal then "PortalGun" else "RayGun", arm.CFrame)
	if main then
		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = main
		weld.C0 = arm.CFrame:ToObjectSpace(main.CFrame)
		weld.Parent = main
		main.Parent = folder
		local tip = main:FindFirstChild("Tip")
		if tip then
			tip.Parent = folder -- (its weld goes with it)
			local light = Instance.new("PointLight")
			light.Color = glow
			light.Brightness = 1.2
			light.Range = 6
			light.Parent = tip
		end
		return
	end
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

-- The teleport sound playing for each Dr. Rift (stopped on a fizzle).
local teleportSounds: { [Model]: Sound? } = setmetatable({}, { __mode = "k" }) :: any

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
	if animation == "Rift_Portal" then
		-- The teleport sound from the start of the move (0.78 s before he
		-- steps through): the file takes a moment to get going, so it is
		-- heard as he comes out. Cut if the shot fizzles.
		teleportSounds[model] = SoundController.play("Teleport", model)
	elseif animation == "Rift_Glove" then
		-- The blast, timed on the clip (the palm out at 0.36 s), not on the
		-- server's answer, which comes later.
		task.delay(0.3, function()
			if model.Parent then
				SoundController.play("GloveBlast", model)
			end
		end)
	elseif animation == "Rift_RayGun" or animation == "Rift_MegaRay" then
		-- The shot, timed on the clip (0.32 / 0.45 s).
		local big = animation == "Rift_MegaRay"
		task.delay(if big then 0.45 else 0.32, function()
			if model.Parent then
				SoundController.play(if big then "RayGunBig" else "RayGun", model)
			end
		end)
	end
	if animation == "Rift_Glove" or animation == "Rift_Slam" then
		chargeGlove(model, if animation == "Rift_Slam" then 0.55 else 0.36)
	elseif animation == "Rift_Awaken" then
		chargeGlove(model, 0.9)
		RiftGlove.onAwaken(model)
	end
end

local function stopTeleportSound(model: Model)
	local sound = teleportSounds[model]
	teleportSounds[model] = nil
	if sound then
		sound:Destroy()
	end
end

function RiftFx.stopAction(model: Model)
	removeProp(model)
	stopTeleportSound(model)
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
		RiftRay.ray(info, muzzleOf)
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
		RiftPortal.portals(info)
	elseif kind == "PortalFizzle" then
		local by, at = info.by, info.at
		local where: Vector3? = if typeof(at) == "Vector3" then at else nil
		if typeof(by) == "Instance" and by:IsA("Model") then
			where = where or muzzleOf(by)
			SoundController.play("PortalFizzle", by)
			stopTeleportSound(by)
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
		RiftGlove.wave(info)
	elseif kind == "CloneIn" then
		RiftPortal.cloneIn(info)
	elseif kind == "CloneOut" then
		RiftPortal.cloneOut(info)
	end
end

------------------------------------------------------------------------------
-- PortalCut (the finisher's timeline, CinematicController)
------------------------------------------------------------------------------

type Portal = RiftPortal.Portal
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
		local ring = RiftPortal.portal(flat, diameter, diameter, 0.3, -1, 0)
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

RiftFx.onHit = RiftGlove.onHit
RiftFx.onAwaken = RiftGlove.onAwaken

return table.freeze(RiftFx)
