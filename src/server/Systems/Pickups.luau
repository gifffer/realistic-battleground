--!strict
-- Pickups: things lying in the street that anyone can pick up and throw
-- (Shared/Weapons: the iron bar, the plank). Like the bone
-- pulled out of a torn arm, but they come back.
--
-- Where they lie: invisible marker parts tagged "WeaponSpawn" (put by the city
-- builders, at the edges of the map and in the alleys; markers added later
-- count too). Each marker gives:
--   CFrame position = the floor point it lies on, LookVector = along its length;
--   attribute Weapon = "IronBar" | "Plank", or "Random" (one of
--   the three, picked again each time it comes back).
--
-- On each marker the server lays the thing on the floor (plain parts built by
-- Weapons.build, anchored, colliding with nothing) with a ProximityPrompt
-- "Take the <name>". Taking it: the server checks it all again (alive, free,
-- nothing in the hand already, not in a duel: Combat.takeWeapon; close
-- enough), the thing goes into the hand ("Weapon" attribute) and leaves the
-- floor. A new one lies there again RESPAWN_MIN..RESPAWN_MAX seconds later.
--
-- Everything goes into Workspace > City > Pickups (one Model per thing,
-- streamed whole).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Combat = require(script.Parent.Combat)

local Pickups = {}

local TAG = "WeaponSpawn"
local FOLDER_NAME = "Pickups"
local RESPAWN_MIN = 45 -- seconds after it was taken
local RESPAWN_MAX = 60
local PROMPT_DISTANCE = 7
local TAKE_DISTANCE = 9 -- (checked again by the server: a little slack for lag)
local HOLD_DURATION = 0.5

-- What the prompt says it is (its ObjectText).
local OBJECT_TEXT: { [string]: string } = {
	IronBar = "Rusty pipe",
	Plank = "Old board",
}

local random = Random.new()
local folder: Instance? = nil
-- The thing lying on each marker (nil: taken, coming back).
local lying: { [BasePart]: Model } = {}
-- Markers that are known (a marker removed from the tag stops coming back).
local markers: { [BasePart]: boolean } = {}

-- The weapon id a marker gives this time (nil: not a known one).
local function pickId(marker: BasePart): string?
	local wanted = marker:GetAttribute("Weapon")
	if wanted == "Random" then
		return Weapons.STREET[random:NextInteger(1, #Weapons.STREET)]
	end
	local weapon = Weapons.get(wanted)
	-- (only one built from parts: the bone only comes from a torn arm)
	return if weapon and weapon.build then weapon.id else nil
end

-- Lying flat on the floor point of `marker`, along its LookVector.
local function restingCFrame(marker: BasePart): CFrame
	local along = marker.CFrame.LookVector * Vector3.new(1, 0, 1)
	if along.Magnitude < 0.01 then
		along = Vector3.new(0, 0, -1)
	end
	along = along.Unit
	-- Weapon space: its length along Y; its front (-Z: the plank's nail
	-- point) up, the way a board with a nail lies in a yard.
	local back = Vector3.new(0, -1, 0)
	return CFrame.fromMatrix(marker.Position, along:Cross(back), along, back)
end

-- The lowest point of all the parts of `root` (world Y).
local function bottomOf(root: BasePart): number
	local lowest = math.huge
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			local size = item.Size / 2
			local cframe = item.CFrame
			-- (how far the box reaches down: each axis' share of world up)
			local reach = math.abs(cframe.RightVector.Y) * size.X
				+ math.abs(cframe.UpVector.Y) * size.Y
				+ math.abs(cframe.LookVector.Y) * size.Z
			lowest = math.min(lowest, cframe.Position.Y - reach)
		end
	end
	return lowest
end

local spawnOn: (marker: BasePart) -> ()

local function respawnLater(marker: BasePart)
	task.delay(random:NextNumber(RESPAWN_MIN, RESPAWN_MAX), function()
		if markers[marker] and marker.Parent ~= nil and not lying[marker] then
			spawnOn(marker)
		end
	end)
end

function spawnOn(marker: BasePart)
	local id = pickId(marker)
	local weapon = Weapons.get(id)
	local root = if id then Weapons.build(id) else nil
	if id == nil or weapon == nil or root == nil or folder == nil then
		warn(`[Pickups] {marker:GetFullName()}: unknown Weapon "{marker:GetAttribute("Weapon")}"`)
		return
	end
	-- Placed, then raised so its lowest part just touches the floor.
	local at = restingCFrame(marker)
	Weapons.pivot(root, at)
	Weapons.pivot(root, at + Vector3.new(0, marker.Position.Y - bottomOf(root), 0))
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
		end
	end
	root.Anchored = true

	local model = Instance.new("Model")
	model.Name = id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Weapon", id)
	root.Parent = model
	model.PrimaryPart = root

	local point = Instance.new("Attachment")
	point.Name = "PickupPrompt"
	point.Parent = root
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Take the {string.lower(weapon.name)}`
	prompt.ObjectText = OBJECT_TEXT[id] or ""
	prompt.HoldDuration = HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local body = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if
			character == nil
			or body == nil
			or not body:IsA("BasePart")
			or lying[marker] ~= model
			or (body.Position - root.Position).Magnitude > TAKE_DISTANCE
			or not Combat.takeWeapon(character, id)
		then
			return
		end
		lying[marker] = nil
		model:Destroy()
		respawnLater(marker)
	end)

	lying[marker] = model
	model.Parent = folder
end

local function addMarker(instance: Instance)
	if not instance:IsA("BasePart") or markers[instance] then
		return
	end
	markers[instance] = true
	spawnOn(instance)
end

local function removeMarker(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	markers[instance] = nil
	local model = lying[instance]
	lying[instance] = nil
	if model then
		model:Destroy()
	end
end

local function waitForCity(): Instance?
	local city = workspace:WaitForChild("City", 60)
	if city == nil then
		return nil
	end
	while city:GetAttribute("Built") ~= true do
		city:GetAttributeChangedSignal("Built"):Wait()
	end
	return city
end

function Pickups.start()
	local city = waitForCity()
	if city == nil then
		return -- no city (a test place): nothing lying about
	end
	local holder = Instance.new("Folder")
	holder.Name = FOLDER_NAME
	holder.Parent = city
	folder = holder
	CollectionService:GetInstanceAddedSignal(TAG):Connect(addMarker)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeMarker)
	for _, instance in CollectionService:GetTagged(TAG) do
		addMarker(instance)
	end
end

return Pickups
