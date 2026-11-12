--!strict
-- CityDoors: the glass double doors of the city's shops (the bar, THREADBARE, REWIND...)
-- open by themselves when a player comes near, and close again when nobody is near.
--
-- How the doors are made (Server/Systems/City builds them from the generated data):
--   every part of a door leaf (frame, glass, push bars) has the tag "CityDoor" and these
--   attributes:
--     DoorGroup  string  the two leaves of one doorway share it ("B1_S_12"...)
--     HingeX     number  world X of the leaf's hinge line (a vertical line)
--     HingeZ     number  world Z of the hinge line
--     OpenAngle  number  degrees to turn about that line when open (+90 or -90: always INTO
--                        the shop, so a door never swings into the street)
--
-- What this system does, every 0.15 seconds, for each doorway:
--   • someone's HumanoidRootPart within OPEN_RANGE studs of the doorway's centre → OPEN:
--     the leaves stop colliding at once (nobody bumps into a moving door), then turn 90°.
--   • nobody within OPEN_RANGE → CLOSE: the leaves turn back, then collide again.
--     A leaf is 4.6 long and its hinge is 4.6 from the centre, so a swinging leaf stays
--     within 6.5 studs of the centre. The range (10) leaves room for a body's width (even a
--     ragdoll's sprawled arms): a closing door never sweeps through a player.
--     The leaves only collide again once closed AND if still nobody is near (a body flung
--     into the doorway during the 0.35 s swing just walks through, then the door reopens).
-- A body flying through a CLOSED door in a knockback fight is just stopped by it (it collides).
-- No sound: Shared/Sounds has no door sound yet (add one there and play it in setOpen).
-- Done on the server: anchored parts moved by the server replicate to every player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CityDoors = {}

local TAG = "CityDoor"
local CHECK_EVERY = 0.15 -- seconds between two checks
local OPEN_RANGE = 10 -- studs from the doorway's centre (flat distance)
local HEIGHT_RANGE = 10 -- and at most this far above / below it
local TWEEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Leaf = {
	part: BasePart,
	closed: CFrame, -- where the part is when the door is closed (as built)
	opened: CFrame, -- where it is when the door is open
	collides: boolean, -- its CanCollide when closed
}

type Door = {
	leaves: { Leaf },
	centre: Vector3, -- average position of the parts (closed)
	isOpen: boolean,
	passable: boolean, -- closed but not colliding yet (someone was near when it closed)
	version: number, -- changes on every open / close (an old tween's callback is ignored)
}

local doors: { [string]: Door } = {}

-- The open CFrame of a part: turned by `angle` degrees about the vertical line (hingeX, hingeZ).
local function openedCFrame(closed: CFrame, hingeX: number, hingeZ: number, angle: number): CFrame
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
	local door = doors[group]
	if door == nil then
		door =
			{ leaves = {}, centre = part.Position, isOpen = false, passable = false, version = 0 }
		doors[group] = door
	end
	-- (a part tagged while its door is open would be recorded open: doors start closed, and
	-- the City is built before any player reaches a door, so this does not happen)
	table.insert(door.leaves, {
		part = part,
		closed = part.CFrame,
		opened = openedCFrame(part.CFrame, hingeX, hingeZ, openAngle),
		collides = part.CanCollide,
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

local function isSomeoneNear(door: Door, positions: { Vector3 }): boolean
	for _, position in positions do
		local offset = position - door.centre
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude <= OPEN_RANGE and math.abs(offset.Y) <= HEIGHT_RANGE then
			return true
		end
	end
	return false
end

-- Opens or closes one doorway.
local function setOpen(door: Door, open: boolean)
	door.isOpen = open
	door.passable = false
	door.version += 1
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

local function check()
	local positions = rootPositions()
	for _, door in doors do
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

function CityDoors.start()
	-- the City builds its parts in the background: take the ones already tagged, then the
	-- ones tagged later
	for _, instance in CollectionService:GetTagged(TAG) do
		addPart(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(addPart)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(removePart)
	while true do
		task.wait(CHECK_EVERY)
		check()
	end
end

return CityDoors
