--!strict
-- CityDoors: the doors of the city's shops.
--
-- Two kinds of doors:
--   • GLASS doors (THREADBARE, REWIND, the bar's back door...): double doors that open by
--     themselves when a player comes near, and close again when nobody is near.
--   • SALOON doors (the main corner entrance of DUFFY'S bar): two waist-high swinging half
--     doors, like in a western. They never block anyone: you just walk through, they swing
--     open AWAY from you, and when you are gone they flap back past the middle a few times
--     before settling (a damped spring).
--
-- How the doors are made (Server/Systems/City builds them from the generated data):
--   every part of a door leaf (frame, glass, push bars, louvres) has the tag "CityDoor" and
--   these attributes:
--     DoorGroup  string  the leaves of one doorway share it ("B1_S_12"...)
--     HingeX     number  world X of the leaf's hinge line (a vertical line)
--     HingeZ     number  world Z of the hinge line
--     OpenAngle  number  degrees to turn about that line when open. Glass doors: +90 or -90,
--                        always INTO the shop, so a door never swings into the street.
--                        Saloon doors: only its size is used (how far they swing, max 80°);
--                        the direction is chosen each time (away from the person).
--     DoorStyle  string  optional: "Saloon" for swinging half doors (anything else = glass)
--
-- GLASS doors, checked every 0.15 seconds:
--   • someone's HumanoidRootPart within OPEN_RANGE studs of the doorway's centre → OPEN:
--     the leaves stop colliding at once (nobody bumps into a moving door), then turn 90°.
--   • nobody within OPEN_RANGE → CLOSE: the leaves turn back, then collide again.
--     A leaf is 4.6 long and its hinge is 4.6 from the centre, so a swinging leaf stays
--     within 6.5 studs of the centre. The range (10) leaves room for a body's width (even a
--     ragdoll's sprawled arms): a closing door never sweeps through a player.
--     The leaves only collide again once closed AND if still nobody is near (a body flung
--     into the doorway during the 0.35 s swing just walks through, then the door reopens).
--   A body flying through a CLOSED glass door in a knockback fight is just stopped by it.
--
-- SALOON doors (never collide):
--   • every 0.1 s: is someone within SALOON_RANGE studs? If the doors are (almost) closed,
--     the side of the doorway the nearest one stands on picks the swing direction: each
--     leaf turns so that its free end moves AWAY from that person. That direction is kept
--     while someone is near (walking through does not flip the doors into you).
--   • every frame while the doors move: a spring pulls the swing angle towards its target
--     (SALOON_OPEN when someone is near, 0 when not). It is under-damped: on its way back to
--     0 it overshoots to the other side, and again, smaller each time, until it rests.
--     A hinge stop holds the leaves at SALOON_STOP degrees (they bounce off it a little).
--   • the parts are moved at most 30 times a second (each move replicates to every player)
--     and not at all once the doors are at rest (closed, or held open).
--
-- SOUNDS (Shared/Sounds: DoorGlassOpen / DoorGlassClose / DoorSaloonOpen / DoorSaloonClose):
--   one sound per DOORWAY (not one per leaf), in 3D at the doorway's centre:
--   • glass doors: when they start to open, and when they start to close;
--   • saloon doors: "open" when someone pushes them from (almost) closed, "close" the first
--     time they swing back through the middle (the slap of the leaves meeting).
--   At most one of each per doorway every SOUND_GAP seconds (no machine-gun doors when a
--   player dances in the doorway). The Sound is made HERE, on the server, in an invisible
--   Attachment at the doorway: a sound the server plays replicates to every player, who hears
--   it from the right place (louder when close).
-- Done on the server: anchored parts moved by the server replicate to every player.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local CityDoors = {}

local TAG = "CityDoor"
local CHECK_EVERY = 0.15 -- seconds between two checks (glass doors)
local OPEN_RANGE = 10 -- studs from the doorway's centre (flat distance)
local HEIGHT_RANGE = 10 -- and at most this far above / below it
local TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Saloon doors.
local SALOON_CHECK_EVERY = 0.1 -- seconds between two "is someone near?" checks
local SALOON_RANGE = 6 -- studs from the doorway's centre (flat distance)
local SALOON_HEIGHT_RANGE = 6
local SALOON_OPEN = 80 -- degrees, the swing while someone is passing
local SALOON_STOP = 86 -- degrees, the hinge stop (never further)
local SALOON_STIFFNESS = 55 -- spring strength: higher = faster swings (period ≈ 2π/√k s)
local SALOON_DAMPING = 3.4 -- friction: lower = more flaps before resting
local SALOON_PUSH = 260 -- degrees per second given at once when pushed open (a shove)
local SALOON_SEND_EVERY = 1 / 30 -- seconds between two moves of the parts
local SALOON_REST_ANGLE = 0.4 -- degrees: below this (and slow), the doors are at rest
local SALOON_REST_SPEED = 3 -- degrees per second

-- Door sounds.
local SOUND_GAP = 0.6 -- seconds: at most one "open" (or one "close") per doorway in this time
local SOUND_MIN_DISTANCE = 8 -- studs: full volume this close
local SOUND_MAX_DISTANCE = 70 -- studs: not heard at all beyond

type Leaf = {
	part: BasePart,
	closed: CFrame, -- where the part is when the door is closed (as built)
	opened: CFrame, -- where it is when the door is open (glass doors)
	collides: boolean, -- its CanCollide when closed
	hingeX: number,
	hingeZ: number,
	-- Saloon: +1 or -1, the way this part turns for the current swing direction.
	sign: number,
}

type Door = {
	leaves: { Leaf },
	centre: Vector3, -- average position of the parts (closed)
	saloon: boolean,
	-- glass doors
	isOpen: boolean,
	passable: boolean, -- closed but not colliding yet (someone was near when it closed)
	version: number, -- changes on every open / close (an old tween's callback is ignored)
	-- saloon doors (degrees, degrees per second)
	angle: number,
	speed: number,
	target: number,
	awake: boolean, -- moving: updated every frame
	sinceSend: number, -- seconds since the parts were last moved
	closeSoundPending: boolean, -- saloon: play "close" when the leaves next pass the middle
	-- sounds
	soundAnchor: Attachment?, -- the invisible point the sounds play from (made on first use)
	lastSound: { [string]: number }, -- slot name → os.clock() of its last play
}

local doors: { [string]: Door } = {}
-- Saloon doors currently swinging (updated every frame).
local awakeSaloons: { [Door]: boolean } = {}

-- The CFrame of a part turned by `angle` degrees about the vertical line (hingeX, hingeZ).
local function turnedCFrame(closed: CFrame, hingeX: number, hingeZ: number, angle: number): CFrame
	local pivot = Vector3.new(hingeX, closed.Position.Y, hingeZ)
	local turn = CFrame.new(pivot) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(-pivot)
	return turn * closed
end

local function recomputeCentre(door: Door)
	local sum = Vector3.zero
	for _, leaf in door.leaves do
		sum += leaf.closed.Position
	end
	if #door.leaves > 0 then
		door.centre = sum / #door.leaves
	end
end

local function addPart(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	local group = part:GetAttribute("DoorGroup")
	local hingeX = part:GetAttribute("HingeX")
	local hingeZ = part:GetAttribute("HingeZ")
	local angle = part:GetAttribute("OpenAngle")
	if typeof(group) ~= "string" or typeof(hingeX) ~= "number" or typeof(hingeZ) ~= "number" then
		warn(`[CityDoors] {part:GetFullName()} is tagged {TAG} but its door attributes are missing`)
		return
	end
	local openAngle = if typeof(angle) == "number" then angle else 90
	local isSaloon = part:GetAttribute("DoorStyle") == "Saloon"
	local door = doors[group]
	if door == nil then
		door = {
			leaves = {},
			centre = part.Position,
			saloon = isSaloon,
			isOpen = false,
			passable = false,
			version = 0,
			angle = 0,
			speed = 0,
			target = 0,
			awake = false,
			sinceSend = 0,
			closeSoundPending = false,
			soundAnchor = nil,
			lastSound = {},
		}
		doors[group] = door
	end
	if isSaloon then
		door.saloon = true
		-- swinging half doors never block anyone (you walk through them)
		part.CanCollide = false
	end
	-- (a part tagged while its door is open would be recorded open: doors start closed, and
	-- the City is built before any player reaches a door, so this does not happen)
	table.insert(door.leaves, {
		part = part,
		closed = part.CFrame,
		opened = turnedCFrame(part.CFrame, hingeX, hingeZ, openAngle),
		collides = part.CanCollide,
		hingeX = hingeX,
		hingeZ = hingeZ,
		sign = 1,
	})
	recomputeCentre(door)
end

local function removePart(instance: Instance)
	for _, door in doors do
		for index, leaf in door.leaves do
			if leaf.part == instance then
				table.remove(door.leaves, index)
				recomputeCentre(door)
				return
			end
		end
	end
end

-- Positions of the players' root parts (alive or ragdolled: both should open a door).
local function rootPositions(): { Vector3 }
	local positions: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

-- The nearest position within (range, heightRange) of the doorway's centre, or nil.
local function nearest(
	door: Door,
	positions: { Vector3 },
	range: number,
	heightRange: number
): Vector3?
	local best: Vector3? = nil
	local bestDistance = range
	for _, position in positions do
		local offset = position - door.centre
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if flat <= bestDistance and math.abs(offset.Y) <= heightRange then
			best, bestDistance = position, flat
		end
	end
	return best
end

local function isSomeoneNear(door: Door, positions: { Vector3 }): boolean
	return nearest(door, positions, OPEN_RANGE, HEIGHT_RANGE) ~= nil
end

------------------------------------------------------------------------------
-- Sounds
------------------------------------------------------------------------------

local soundRandom = Random.new()

-- Plays the sound `slot` (a name in Shared/Sounds) at the doorway, unless it already played
-- there less than SOUND_GAP seconds ago, or it has no id.
local function playDoorSound(door: Door, slot: string)
	local info = Sounds[slot]
	if info == nil or #info.ids == 0 then
		return
	end
	local now = os.clock()
	local last = door.lastSound[slot]
	if last and now - last < SOUND_GAP then
		return
	end
	door.lastSound[slot] = now
	-- One invisible attachment per doorway, in the Terrain (it never moves with the leaves).
	local anchor = door.soundAnchor
	if anchor == nil or anchor.Parent == nil then
		local newAnchor = Instance.new("Attachment")
		newAnchor.Name = "DoorSound"
		-- (the Terrain sits at the world's origin: its Position IS the world position)
		newAnchor.Position = door.centre
		newAnchor.Parent = workspace.Terrain
		door.soundAnchor = newAnchor
		anchor = newAnchor
	end
	local sound = Instance.new("Sound")
	sound.Name = slot
	sound.SoundId = `rbxassetid://{info.ids[soundRandom:NextInteger(1, #info.ids)]}`
	sound.Volume = info.volume
	sound.PlaybackSpeed = info.pitch
		* (1 + soundRandom:NextNumber(-info.pitchVariation, info.pitchVariation))
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = SOUND_MIN_DISTANCE
	sound.RollOffMaxDistance = SOUND_MAX_DISTANCE
	sound.Parent = anchor
	sound:Play()
	-- (a door sound is short: removed after 4 s whatever happens)
	Debris:AddItem(sound, 4)
end

------------------------------------------------------------------------------
-- Glass doors
------------------------------------------------------------------------------

-- Opens or closes one doorway.
local function setOpen(door: Door, open: boolean)
	door.isOpen = open
	door.passable = false
	door.version += 1
	playDoorSound(door, if open then "DoorGlassOpen" else "DoorGlassClose")
	local version = door.version
	for _, leaf in door.leaves do
		if open then
			leaf.part.CanCollide = false -- never push a player with a moving door
		end
		local tween = TweenService:Create(leaf.part, TWEEN_INFO, {
			CFrame = if open then leaf.opened else leaf.closed,
		})
		if not open then
			tween.Completed:Connect(function()
				-- only if the door was not opened again while it was closing
				if door.version ~= version or leaf.part.Parent == nil then
					return
				end
				if isSomeoneNear(door, rootPositions()) then
					-- someone stepped into the doorway during the swing: stay passable (the
					-- next check opens the door again, or restores the collision in check)
					door.passable = true
				else
					leaf.part.CanCollide = leaf.collides
				end
			end)
		end
		tween:Play()
	end
end

local function checkGlass()
	local positions = rootPositions()
	for _, door in doors do
		if door.saloon then
			continue
		end
		local near = isSomeoneNear(door, positions)
		if near and not door.isOpen then
			setOpen(door, true)
		elseif not near and door.isOpen then
			setOpen(door, false)
		elseif not near and door.passable then
			-- closed while someone was in the doorway, and they left: collide again
			door.passable = false
			for _, leaf in door.leaves do
				leaf.part.CanCollide = leaf.collides
			end
		end
	end
end

------------------------------------------------------------------------------
-- Saloon doors
------------------------------------------------------------------------------

-- Picks, for every part, the way it turns so that its leaf's free end moves AWAY from
-- `from` (the person pushing). Turning a point by a small angle +a about a vertical line
-- moves it along (d.Z, 0, -d.X), where d = point - hinge: if that points towards the
-- person, the part must turn the other way (-1).
local function chooseSwingSide(door: Door, from: Vector3)
	local toPerson = from - door.centre
	for _, leaf in door.leaves do
		local d = leaf.closed.Position - Vector3.new(leaf.hingeX, 0, leaf.hingeZ)
		local moves = Vector3.new(d.Z, 0, -d.X)
		leaf.sign = if moves:Dot(toPerson) > 0 then -1 else 1
	end
end

local function wake(door: Door)
	if not door.awake then
		door.awake = true
		door.sinceSend = SALOON_SEND_EVERY -- move the parts on the next frame
		awakeSaloons[door] = true
	end
end

-- Moves the parts of a saloon door to its current angle (one call for all of them).
local partsBuffer: { BasePart } = {}
local cframesBuffer: { CFrame } = {}
local function placeSaloon(door: Door)
	table.clear(partsBuffer)
	table.clear(cframesBuffer)
	for _, leaf in door.leaves do
		if leaf.part.Parent then
			table.insert(partsBuffer, leaf.part)
			table.insert(
				cframesBuffer,
				turnedCFrame(leaf.closed, leaf.hingeX, leaf.hingeZ, leaf.sign * door.angle)
			)
		end
	end
	if #partsBuffer > 0 then
		workspace:BulkMoveTo(partsBuffer, cframesBuffer, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function checkSaloons()
	local positions = rootPositions()
	for _, door in doors do
		if not door.saloon then
			continue
		end
		local who = nearest(door, positions, SALOON_RANGE, SALOON_HEIGHT_RANGE)
		if who then
			if door.target == 0 then
				-- a new push. If the doors are nearly closed, they open away from this person;
				-- if they are still flapping, they keep their direction (no slap in the face)
				if math.abs(door.angle) < 20 then
					-- (all the leaves flip together: if the direction changes, the same
					-- physical angle is the opposite number, so the doors don't jump)
					local first = door.leaves[1]
					local oldSign = if first then first.sign else 1
					chooseSwingSide(door, who)
					if first and first.sign ~= oldSign then
						door.angle = -door.angle
						door.speed = -door.speed
					end
					door.speed = math.max(door.speed, SALOON_PUSH)
					playDoorSound(door, "DoorSaloonOpen")
				end
				door.closeSoundPending = false
				door.target = SALOON_OPEN
				wake(door)
			end
		elseif door.target ~= 0 then
			door.target = 0 -- nobody: let them swing back
			door.closeSoundPending = true -- the slap when they pass the middle
			wake(door)
		end
	end
end

-- One frame of the spring for every swinging saloon door.
local function stepSaloons(dt: number)
	-- (small steps: a long frame must not make the spring explode)
	local steps = math.clamp(math.ceil(dt / (1 / 120)), 1, 8)
	local h = dt / steps
	for door in awakeSaloons do
		local before = door.angle
		for _ = 1, steps do
			local accel = -SALOON_STIFFNESS * (door.angle - door.target)
				- SALOON_DAMPING * door.speed
			door.speed += accel * h
			door.angle += door.speed * h
			-- the hinge stop, on both sides: bounce back a little
			if door.angle > SALOON_STOP then
				door.angle = SALOON_STOP
				door.speed = -math.abs(door.speed) * 0.3
			elseif door.angle < -SALOON_STOP then
				door.angle = -SALOON_STOP
				door.speed = math.abs(door.speed) * 0.3
			end
		end
		-- swinging back: the first time the leaves pass the middle, they slap ("close")
		if door.closeSoundPending and door.target == 0 and (before > 0) ~= (door.angle > 0) then
			door.closeSoundPending = false
			playDoorSound(door, "DoorSaloonClose")
		end
		-- at rest (closed, or held open by someone standing in the doorway): stop updating
		-- until the target changes (checkSaloons wakes it up)
		local resting = math.abs(door.angle - door.target) < SALOON_REST_ANGLE
			and math.abs(door.speed) < SALOON_REST_SPEED
		if resting then
			if door.closeSoundPending and door.target == 0 then
				-- (settled without passing the middle: still the "close")
				door.closeSoundPending = false
				playDoorSound(door, "DoorSaloonClose")
			end
			door.angle = door.target
			door.speed = 0
			door.awake = false
			awakeSaloons[door] = nil
			placeSaloon(door) -- exactly there
			continue
		end
		door.sinceSend += dt
		if door.sinceSend >= SALOON_SEND_EVERY then
			door.sinceSend = 0
			placeSaloon(door)
		end
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function CityDoors.start()
	-- the City builds its parts in the background: take the ones already tagged, then the
	-- ones tagged later
	for _, instance in CollectionService:GetTagged(TAG) do
		addPart(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(addPart)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(removePart)
	RunService.Heartbeat:Connect(stepSaloons)
	task.spawn(function()
		while true do
			task.wait(SALOON_CHECK_EVERY)
			checkSaloons()
		end
	end)
	while true do
		task.wait(CHECK_EVERY)
		checkGlass()
	end
end

return CityDoors
