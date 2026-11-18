--!strict
-- MapBounds: may a fighter be put HERE (Dr. Rift's portal)? The map has no
-- bounds data yet, so the rules are:
--   • in a duel ("DuelId" attribute): inside the duel room he is in (its
--     walls, under their top);
--   • in the free arena: inside one of the Parts of Workspace > MapBounds if
--     that exists (a builder draws the playable area with invisible boxes);
--     without it: anywhere with a floor under it that isn't in or near a
--     duel room;
--   • and never into a wall or into something solid (room for a body).
--
--   MapBounds.allows(model, position)   position = where the root goes

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBounds = {}

local BODY = Vector3.new(2.2, 4.6, 1.6) -- room a standing R6 body needs
local ROOM_MARGIN = 4 -- studs kept away from a duel room from outside
local FLOOR_SEARCH = 60 -- a floor this far under it at most

local function fighters(): { Instance }
	return CollectionService:GetTagged(Config.Combat.TAG)
end

-- The bounding box of a model, as (CFrame, size).
local function boxOf(model: Model): (CFrame, Vector3)
	return model:GetBoundingBox()
end

local function inside(cframe: CFrame, size: Vector3, point: Vector3, margin: number): boolean
	local p = cframe:PointToObjectSpace(point)
	local half = size / 2 + Vector3.new(margin, margin, margin)
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

-- The duel room `point` is in (its model), if any.
local function roomAt(point: Vector3, margin: number): Model?
	local folder = workspace:FindFirstChild("DuelArenas")
	if folder == nil then
		return nil
	end
	for _, room in folder:GetChildren() do
		if room:IsA("Model") then
			local cframe, size = boxOf(room)
			-- (the box of the walls, and well above them: no ceiling)
			if inside(cframe, size + Vector3.new(0, 40, 0), point, margin) then
				return room
			end
		end
	end
	return nil
end

-- Nothing solid where the body would stand (the fighters don't count).
function MapBounds.hasRoom(position: Vector3, ignore: { Instance }?): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = table.clone(fighters())
	if ignore then
		for _, item in ignore do
			table.insert(skip, item)
		end
	end
	params.FilterDescendantsInstances = skip
	params.RespectCanCollide = true
	return #workspace:GetPartBoundsInBox(CFrame.new(position), BODY, params) == 0
end

function MapBounds.allows(model: Model, position: Vector3): boolean
	if position ~= position or position.Y < workspace.FallenPartsDestroyHeight + 50 then
		return false
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	if model:GetAttribute("DuelId") ~= nil then
		-- Only inside the room the duel is in, under the top of its walls.
		local room = roomAt(root.Position, 0)
		if room == nil then
			return false
		end
		local cframe, size = boxOf(room)
		if not inside(cframe, size, position, -1.5) then
			return false
		end
	else
		local bounds = workspace:FindFirstChild("MapBounds")
		if bounds then
			local ok = false
			local boxes: { Instance } = if bounds:IsA("BasePart")
				then { bounds }
				else bounds:GetDescendants()
			for _, box in boxes do
				if box:IsA("BasePart") and inside(box.CFrame, box.Size, position, 0) then
					ok = true
					break
				end
			end
			if not ok then
				return false
			end
		end
		-- Never into (or onto the walls of) a duel room.
		if roomAt(position, ROOM_MARGIN) then
			return false
		end
	end
	-- A floor under it: not out over the void past the edge of the map.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = fighters()
	params.RespectCanCollide = true
	if workspace:Raycast(position, Vector3.new(0, -FLOOR_SEARCH, 0), params) == nil then
		return false
	end
	return MapBounds.hasRoom(position)
end

return table.freeze(MapBounds)
