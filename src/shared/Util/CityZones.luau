--!strict
-- CityZones: "is this point inside one of the city's invisible zone boxes?"
--
-- The city (Server/Systems/City) places invisible box parts with tags:
--   ParkZone    the hidden park (always sunny, music, no fights)
--   MusicZone   the inside of a place with its own music; attribute Zone =
--               "Bar" | "Threads" | "Rewind" | "Park"
-- A box can be turned (its CFrame), so the test is done in the box's own space.
--
--   CityZones.inPark(position)          true inside any ParkZone box
--   CityZones.musicZoneAt(position)     "Bar" / "Threads" / ... or nil (outside every box)
--   CityZones.inZone(zoneName, position) true inside a MusicZone box of that zone
--
-- Works on the server and on the clients. Cheap: a handful of boxes, no raycast.

local CollectionService = game:GetService("CollectionService")

local CityZones = {}

CityZones.PARK_TAG = "ParkZone"
CityZones.MUSIC_TAG = "MusicZone"

-- Is `position` inside the box part `box` (a block, maybe turned)?
function CityZones.insideBox(box: BasePart, position: Vector3): boolean
	local localPoint = box.CFrame:PointToObjectSpace(position)
	local half = box.Size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

-- The first box with `tag` that contains `position`, or nil.
function CityZones.boxAt(tag: string, position: Vector3): BasePart?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and CityZones.insideBox(instance, position) then
			return instance
		end
	end
	return nil
end

function CityZones.inPark(position: Vector3): boolean
	return CityZones.boxAt(CityZones.PARK_TAG, position) ~= nil
end

-- The name of the music zone around `position` ("Bar"...), or nil.
function CityZones.musicZoneAt(position: Vector3): string?
	local box = CityZones.boxAt(CityZones.MUSIC_TAG, position)
	if box == nil then
		return nil
	end
	local zone = box:GetAttribute("Zone")
	return if typeof(zone) == "string" then zone else nil
end

function CityZones.inZone(zoneName: string, position: Vector3): boolean
	for _, instance in CollectionService:GetTagged(CityZones.MUSIC_TAG) do
		if
			instance:IsA("BasePart")
			and instance:GetAttribute("Zone") == zoneName
			and CityZones.insideBox(instance, position)
		then
			return true
		end
	end
	return false
end

return table.freeze(CityZones)
