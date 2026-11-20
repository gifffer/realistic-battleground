--!strict
-- WeaponFx: the things you pick up and throw (Shared/Weapons), on every
-- client. Only the look: the server decides the throw and what it hits.
--
--   • In the hand ("Weapon" attribute on the fighter): the real bone (Z-Anatomy
--     humerus, WoundKit "Gore_Humerus_*") gripped round the shaft near its
--     elbow end, the round head out in front of the fist; or a simple one
--     without the kit. The things from the street (iron bar, bottle, plank)
--     are built from plain parts (Weapons.build), held by their near end.
--   • Thrown (Remotes.WeaponThrown): it flies the same arc the server flies,
--     tumbling end over end.
--   • Landed (Remotes.WeaponBroke): where it hit -
--       the bone snaps in two (the real halves "Gore_HumerusA/B"), the halves
--       bounce off, splinters and a few drops of blood;
--       the plank cracks in two, wood splinters;
--       the bottle bursts: its neck and a spray of glass;
--       the iron bar doesn't break: it clangs off and rolls on the floor.
--     They lie there a while, then go.
--
--   WeaponFx.watch(model)                               what is in the hand
--   WeaponFx.thrown(thrower, id, throwId, origin, velocity)
--   WeaponFx.broke(id, throwId?, position, velocity)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local GoreKit = require(script.Parent.GoreKit)
local Blood = require(script.Parent.Blood)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local WeaponFx = {}

local BONE = Color3.fromRGB(222, 208, 182)
local BONE_BLOODY = Color3.fromRGB(176, 120, 104)
local FLESH = Color3.fromRGB(112, 24, 26)
local TENDON = Color3.fromRGB(210, 196, 178)
local BLOOD = Config.Blood.PALETTE.VENOUS
local BONE_LENGTH = 1.7
local HALF_LIFETIME = 20 -- seconds the two halves stay on the floor
local BAR_LIFETIME = 6 -- seconds the iron bar lies there before it goes
local GLASS = Color3.fromRGB(38, 58, 30) -- (Shared/Weapons: the bottle's glass)
local WOOD_FRESH = Color3.fromRGB(176, 146, 104) -- (the plank's inside)
-- In the fist (Right Arm space): the hand closed round the shaft a third of
-- the way up from the elbow end, the bone carrying on forward from the fist
-- and a little down - with the arm hanging, it points ahead like a club
-- held low; raised for the throw, it points back over the shoulder. Each
-- thing's middle is `grip` studs past the fist (Shared/Weapons).
local GRIP = CFrame.new(0, -0.9, -0.05) * CFrame.Angles(math.rad(-110), 0, 0)

local held: { [Model]: BasePart } = setmetatable({}, { __mode = "k" }) :: any
type Flight = { part: BasePart, connection: RBXScriptConnection }
local flying: { [number]: Flight } = {}

local function paint(layer: string): (Color3, number)
	if layer == "Flesh" then
		return FLESH, 0.15
	elseif layer == "Tendon" then
		return TENDON, 0.1
	end
	return BONE:Lerp(BONE_BLOODY, 0.3), 0.04
end

local function quiet(part: BasePart)
	for _, item in part:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
		end
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
end

-- A piece of the bone ("Humerus", "HumerusA", "HumerusB"), its bone space
-- (middle at the origin, along Y, the head up) at `at`; a simple one
-- without the kit.
local function newPiece(name: string, at: CFrame): BasePart
	local pieces = GoreKit.get()
	local piece = if pieces then pieces[name] else nil
	if piece then
		return GoreKit.spawn(piece, at, paint)
	end
	local length = if name == "Humerus" then BONE_LENGTH else BONE_LENGTH * 0.5
	local centre = if name == "HumerusA"
		then BONE_LENGTH * 0.22
		elseif name == "HumerusB" then -BONE_LENGTH * 0.3
		else 0
	local shaft = Instance.new("Part")
	shaft.Name = "Bone"
	shaft.Size = Vector3.new(0.16, length, 0.16)
	shaft.Material = Enum.Material.SmoothPlastic
	shaft.Color = BONE:Lerp(BONE_BLOODY, 0.3)
	shaft.CFrame = at * CFrame.new(0, centre, 0)
	if name ~= "HumerusB" then
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(0.34, 0.34, 0.34)
		head.Material = Enum.Material.SmoothPlastic
		head.Color = BONE
		local weld = Instance.new("Weld")
		weld.Part0 = shaft
		weld.Part1 = head
		weld.C0 = CFrame.new(-0.05, length / 2, 0)
		weld.Parent = head
		head.Parent = shaft
	end
	return shaft
end

-- The whole thing (the bone, or one built from parts) at `at`, weapon space.
local function newWhole(weapon: Weapons.WeaponDef, at: CFrame): BasePart
	local built = Weapons.build(weapon.id)
	if built then
		Weapons.pivot(built, at)
		return built
	end
	return newPiece("Humerus", at)
end

------------------------------------------------------------------------------
-- In the hand
------------------------------------------------------------------------------

local function remove(model: Model)
	local prop = held[model]
	held[model] = nil
	if prop then
		prop:Destroy()
	end
end

local function show(model: Model, id: string)
	remove(model)
	local weapon = Weapons.get(id)
	local arm = model:FindFirstChild("Right Arm")
	if weapon == nil or arm == nil or not arm:IsA("BasePart") then
		return
	end
	local at = arm.CFrame * GRIP * CFrame.new(0, weapon.grip, 0)
	local bone = newWhole(weapon, at)
	quiet(bone)
	bone.Anchored = false
	local weld = Instance.new("Weld")
	weld.Name = "Held"
	weld.Part0 = arm
	weld.Part1 = bone
	weld.C0 = arm.CFrame:ToObjectSpace(bone.CFrame)
	weld.Parent = bone
	bone.Name = `Held{id}`
	bone.Parent = model
	held[model] = bone
end

function WeaponFx.watch(model: Model)
	local function refresh()
		local id = model:GetAttribute("Weapon")
		if typeof(id) == "string" then
			show(model, id)
		else
			remove(model)
		end
	end
	model:GetAttributeChangedSignal("Weapon"):Connect(refresh)
	refresh()
end

------------------------------------------------------------------------------
-- In the air
------------------------------------------------------------------------------

function WeaponFx.thrown(
	thrower: Model,
	id: string,
	throwId: number,
	origin: Vector3,
	velocity: Vector3
)
	local weapon = Weapons.get(id)
	if weapon == nil then
		return
	end
	remove(thrower) -- (the server clears "Weapon" too; this is just sooner)
	local bone = newWhole(
		weapon,
		CFrame.lookAt(origin, origin + velocity) * CFrame.Angles(-math.pi / 2, 0, 0)
	)
	quiet(bone)
	bone.Anchored = true
	bone.Parent = workspace
	local position, moving = origin, velocity
	local spin = 0
	local start = os.clock()
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		position += moving * dt
		moving += Vector3.new(0, -weapon.gravity * dt, 0)
		spin += dt * 18 -- end over end
		-- (its welded layers follow the main part: anchored, moved by hand)
		bone.CFrame = CFrame.lookAt(position, position + moving)
			* CFrame.Angles(-math.pi / 2 + spin, 0, 0)
		if os.clock() - start > weapon.lifetime + 1 then
			local flight = flying[throwId]
			if flight then
				flying[throwId] = nil
				flight.connection:Disconnect()
				flight.part:Destroy()
			end
		end
	end)
	flying[throwId] = { part = bone, connection = connection }
end

------------------------------------------------------------------------------
-- Broken
------------------------------------------------------------------------------

-- Bits flying off where it broke (bone, wood); `bloody`: and a few drops
-- of what was still on it.
local function splinters(at: Vector3, count: number, color: Color3, bloody: boolean)
	for _ = 1, count do
		local splinter = Instance.new("Part")
		splinter.Name = "Splinter"
		splinter.Size = Vector3.new(0.03, 0.03, math.random() * 0.12 + 0.05)
		splinter.Material = Enum.Material.SmoothPlastic
		splinter.Color = color
		splinter.CanQuery = false
		splinter.CanTouch = false
		splinter.CFrame = CFrame.new(at)
			* CFrame.Angles(math.random() * 6.3, math.random() * 6.3, 0)
		splinter.AssemblyLinearVelocity = Vector3.new(
			math.random() - 0.5,
			math.random() * 0.9,
			math.random() - 0.5
		) * 18
		splinter.Parent = workspace
		Debris:AddItem(splinter, 6)
	end
	if not bloody then
		return
	end
	-- a few drops of what was still on it
	local point = Instance.new("Attachment")
	point.WorldPosition = at
	point.Parent = workspace.Terrain
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = "rbxasset://textures/particles/smoke_main.dds"
	drops.Color = ColorSequence.new(BLOOD)
	drops.LightEmission = 0
	drops.Size = NumberSequence.new(0.08, 0.04)
	drops.Lifetime = NumberRange.new(0.3, 0.6)
	drops.Speed = NumberRange.new(4, 9)
	drops.SpreadAngle = Vector2.new(180, 180)
	drops.Acceleration = Vector3.new(0, -60, 0)
	drops.Rate = 0
	Blood.droplets(drops, "drops")
	drops.Parent = point
	drops:Emit(10)
	Debris:AddItem(point, 1)
	Blood.landings(
		at,
		Vector3.new(0, 1, 0),
		90,
		NumberRange.new(4, 9),
		2,
		NumberRange.new(0.03, 0.06)
	)
end

-- A piece (or the whole thing) let go at its CFrame: falls, bounces and
-- tumbles, collides once clear of whoever is right there, lies there
-- `lifetime` seconds.
local function fling(piece: BasePart, velocity: Vector3, spin: number, lifetime: number)
	local visible: { BasePart } = {}
	for _, item in piece:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = false -- (the root is a tiny invisible pivot: these weigh)
			table.insert(visible, item)
		end
	end
	piece.Massless = #visible > 0
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Anchored = false
	piece.Parent = workspace
	piece.AssemblyLinearVelocity = velocity
	piece.AssemblyAngularVelocity = Vector3.new(
		math.random() - 0.5,
		math.random() - 0.5,
		math.random() - 0.5
	) * spin
	task.delay(0.12, function()
		if piece.Parent then
			for _, part in visible do
				part.CanCollide = true
			end
		end
	end)
	Debris:AddItem(piece, lifetime)
end

-- The bottle bursting: a spray of dark glass, bouncing and skittering.
local function glassBurst(at: Vector3, moving: Vector3, count: number)
	local push = if moving.Magnitude > 1 then -moving.Unit * 4 else Vector3.zero
	for _ = 1, count do
		local shard = Instance.new("WedgePart")
		shard.Name = "Glass"
		local size = math.random() * 0.14 + 0.05
		shard.Size = Vector3.new(0.02, size, size * (0.5 + math.random() * 0.6))
		shard.Material = Enum.Material.Glass
		shard.Color = GLASS
		shard.Transparency = 0.25
		shard.CastShadow = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CFrame = CFrame.new(at)
			* CFrame.Angles(math.random() * 6.3, math.random() * 6.3, math.random() * 6.3)
		shard.AssemblyLinearVelocity = push
			+ Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5) * 22
		shard.AssemblyAngularVelocity = Vector3.new(
			math.random() - 0.5,
			math.random() - 0.5,
			math.random() - 0.5
		) * 30
		shard.Parent = workspace
		Debris:AddItem(shard, 8 + math.random() * 4)
	end
end

-- One built from parts (Weapons.build) landing at `at`: the bar clangs
-- off, the plank cracks in two, the bottle bursts. `flown` = the one that
-- was in the air (taken over or removed).
local function landed(weapon: Weapons.WeaponDef, at: CFrame, flown: BasePart?, velocity: Vector3)
	local position = at.Position
	if flown == nil then
		-- (let go from the hand: falling over, not standing on its end)
		at *= CFrame.Angles(0, math.random() * math.pi * 2, 0) * CFrame.Angles(math.rad(70), 0, 0)
	end
	if weapon.breakSound then
		SoundController.playAt(weapon.breakSound, position)
	end
	local back = if velocity.Magnitude > 1 then -velocity.Unit else Vector3.new(0, 1, 0)
	if not weapon.breaks then
		-- Bounces back off what it hit, heavy, and rolls to a stop.
		local bar = flown or newWhole(weapon, at)
		fling(bar, back * 7 + Vector3.new(0, 6 + math.random() * 3, 0), 10, BAR_LIFETIME)
		return
	end
	if flown then
		flown:Destroy()
	end
	-- The two pieces kicked apart (the bottle: only its neck is left, the
	-- rest bursts into glass).
	for index = 1, if weapon.cuts then 1 else 2 do
		local name: Weapons.Piece = if index == 1 then "A" else "B"
		local piece = Weapons.build(weapon.id, name)
		if piece == nil then
			continue
		end
		Weapons.pivot(piece, at)
		local side = if name == "A" then -1 else 1
		fling(
			piece,
			back * 5 + at.UpVector * side * 6 + Vector3.new(0, 6 + math.random() * 4, 0),
			20,
			HALF_LIFETIME
		)
	end
	if weapon.cuts then
		glassBurst(position, velocity, 16)
	else
		splinters(position, 12, WOOD_FRESH, false)
	end
end

function WeaponFx.broke(id: string, throwId: number?, position: Vector3, velocity: Vector3)
	local weapon = Weapons.get(id)
	if weapon == nil then
		return
	end
	-- Where it was (in the air: its last frame), or where it hit.
	local at = CFrame.new(position)
	local flight = if throwId then flying[throwId] else nil
	if flight then
		flying[throwId :: number] = nil
		flight.connection:Disconnect()
		at = flight.part.CFrame.Rotation + position
	end
	if weapon.build then
		landed(weapon, at, if flight then flight.part else nil, velocity)
		return
	end
	if flight then
		flight.part:Destroy()
	end
	-- Snapped in two: each half carries on a little, kicked apart, spinning.
	local back = if velocity.Magnitude > 1 then -velocity.Unit else Vector3.new(0, 1, 0)
	for _, name in { "HumerusA", "HumerusB" } do
		local half = newPiece(name, at)
		for _, item in half:GetDescendants() do
			if item:IsA("BasePart") then
				item.CanCollide = false
				item.Massless = true
				item.CanQuery = false
				item.CanTouch = false
			end
		end
		half.Anchored = false
		half.CanQuery = false
		half.CanTouch = false
		-- (not into whoever is right there: it collides once clear)
		half.CanCollide = false
		local side = if name == "HumerusA" then 1 else -1
		half.AssemblyLinearVelocity = back * 6
			+ at.UpVector * side * 7
			+ Vector3.new(0, 7 + math.random() * 4, 0)
		half.AssemblyAngularVelocity = Vector3.new(
			math.random() - 0.5,
			math.random() - 0.5,
			math.random() - 0.5
		) * 24
		half.Parent = workspace
		task.delay(0.12, function()
			if half.Parent then
				half.CanCollide = true
			end
		end)
		Debris:AddItem(half, HALF_LIFETIME)
	end
	splinters(position, 9, BONE, true)
end

return table.freeze(WeaponFx)
