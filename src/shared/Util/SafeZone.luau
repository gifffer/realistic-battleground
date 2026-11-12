--!strict
-- SafeZone: the hidden park is a place where NOBODY FIGHTS.
--
-- The city puts invisible box parts tagged "ParkZone" over the whole park (see
-- Shared/Util/CityZones). This module answers one question, very often and very cheaply:
--
--   SafeZone.contains(position)   true if `position` is inside the park (a safe zone)
--
-- Used by the server (Combat refuses punches / moves / finishers there, and hits on someone
-- standing in it) and by the client (no predicted punch, the "SAFE ZONE" caption).
--
-- Why a cache: CollectionService:GetTagged() builds a NEW table each call. Combat asks this
-- for every punch and every victim, so the boxes are kept in a list instead, updated when
-- a box is tagged or untagged (the city is built in the background: boxes can arrive late).
-- The test itself is CityZones.insideBox (works for turned boxes too).
-- Config.Park.SAFE_ZONE = false turns the whole rule off.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CityZones = require(script.Parent.CityZones)
local Config = require(ReplicatedStorage.Shared.Config)

local SafeZone = {}

-- The ParkZone boxes known right now.
local boxes: { BasePart } = {}
local listening = false

local function addBox(instance: Instance)
	if instance:IsA("BasePart") and not table.find(boxes, instance) then
		table.insert(boxes, instance)
	end
end

local function removeBox(instance: Instance)
	local index = table.find(boxes, instance :: any)
	if index then
		table.remove(boxes, index)
	end
end

-- Starts following the tag the first time we are asked (no init() needed by the callers).
local function listen()
	if listening then
		return
	end
	listening = true
	CollectionService:GetInstanceAddedSignal(CityZones.PARK_TAG):Connect(addBox)
	CollectionService:GetInstanceRemovedSignal(CityZones.PARK_TAG):Connect(removeBox)
	for _, instance in CollectionService:GetTagged(CityZones.PARK_TAG) do
		addBox(instance)
	end
end

function SafeZone.contains(position: Vector3): boolean
	if not Config.Park.SAFE_ZONE then
		return false
	end
	listen()
	for _, box in boxes do
		if CityZones.insideBox(box, position) then
			return true
		end
	end
	return false
end

-- Is this character (its HumanoidRootPart) in the safe zone?
function SafeZone.containsModel(model: Model): boolean
	local root = model:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and SafeZone.contains(root.Position)
end

return table.freeze(SafeZone)
