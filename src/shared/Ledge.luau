--!strict
-- Ledge: "is there a ledge I can climb in front of this character?"
--
-- Used by BOTH sides with the same code:
--   • the client, to start the climb instantly when you jump at a wall,
--   • the server, to check the client isn't lying (with a small tolerance,
--     because the server's copy of your position is a little behind).
--
-- How it works (seen from the side):
--
--        ↓ 2. ray down from above → finds the TOP of the wall
--     ┌──────
--  →→→│ 1. rays forward at several heights → finds the FACE of the wall
--     │
--   ──┘ feet
--
--   3. the top must be flat and between MIN_HEIGHT and MAX_HEIGHT above the feet,
--   4. there must be room for the body on top, and nothing above our head on the way up.
--
-- The climb direction is the wall's own direction (straight into it), not
-- where the character happens to look: running at a wall at an angle still
-- gives a clean, squared-up climb.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CLIMB = Config.Climb
local ROOT_TO_FEET = Config.Character.ROOT_TO_FEET

-- Heights (above the feet) of the forward rays looking for the wall's face.
local FACE_RAY_HEIGHTS = { 0.6, 1.8, 3.0, 4.2 }
-- How far past the wall's face we look for its top (works for thin walls too).
local TOP_INSET = 0.4
-- After the climb, the character stands this far past the wall's face.
local STAND_INSET = 1.2
-- R6 body size used for the "is there room?" check (a bit smaller than the
-- real 4 x 5 x 1, so brushing a wall doesn't block the climb).
local BODY_SIZE = Vector3.new(3, 4.6, 1.6)
-- A surface counts as a "top" if it's this flat (1 = perfectly flat)...
local MIN_TOP_FLATNESS = 0.75
-- ...and as a "face" if it's this vertical (0 = perfectly vertical).
local MAX_FACE_FLATNESS = 0.4
-- We must be roughly facing the wall: 0.5 = within 60° of straight at it.
local MIN_FACING_DOT = 0.5

export type Result = {
	-- Where the HumanoidRootPart ends up, standing on the ledge.
	target: Vector3,
	-- Direction of the climb: straight into the wall (flat, length 1).
	facing: Vector3,
	-- The point of the ledge's edge right in front of the character
	-- (on the wall's face, at the height of its top).
	edge: Vector3,
	-- Height of the ledge above the character's feet (studs).
	height: number,
}

local Ledge = {}

-- Anything that belongs to a character (players, NPCs) can't be climbed.
local function isCharacterPart(instance: Instance): boolean
	local model = instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Raycast that ignores characters (retries past them, a few times at most).
local function cast(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
	local ignored = table.clone(params.FilterDescendantsInstances)
	for _ = 1, 4 do
		local result = workspace:Raycast(origin, direction, params)
		if result == nil or not isCharacterPart(result.Instance) then
			return result
		end
		table.insert(ignored, result.Instance)
		params.FilterDescendantsInstances = ignored
	end
	return nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- `tolerance` (studs) makes the check more forgiving: 0 on the client,
-- Config.Climb.SERVER_TOLERANCE on the server.
function Ledge.find(character: Model, tolerance: number): Result?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	local look = flat(root.CFrame.LookVector)
	if look.Magnitude < 1e-3 then
		return nil
	end
	look = look.Unit

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local feet = root.Position - Vector3.new(0, ROOT_TO_FEET, 0)
	local reach = CLIMB.REACH + tolerance

	-- 1. Find the wall's face: closest vertical surface in front of us.
	local faceHit: RaycastResult? = nil
	local faceDistance = math.huge
	for _, height in FACE_RAY_HEIGHTS do
		local origin = feet + Vector3.new(0, height, 0)
		local hit = cast(origin, look * reach, params)
		if hit and math.abs(hit.Normal.Y) <= MAX_FACE_FLATNESS then
			local distance = (hit.Position - origin).Magnitude
			if distance < faceDistance then
				faceDistance = distance
				faceHit = hit
			end
		end
	end
	if faceHit == nil then
		return nil
	end

	-- Climb straight INTO the wall (opposite of the face's normal).
	local into = flat(-faceHit.Normal)
	if into.Magnitude < 1e-3 then
		return nil
	end
	local facing = into.Unit
	if facing:Dot(look) < MIN_FACING_DOT then
		return nil -- the wall is beside us, not in front
	end
	-- Distance to the face, measured along that direction.
	local toFace = flat(faceHit.Position - root.Position):Dot(facing)

	-- 2. Find the top: ray going down, just past the face.
	local maxHeight = CLIMB.MAX_HEIGHT + tolerance
	local minHeight = CLIMB.MIN_HEIGHT - tolerance
	local above = feet + facing * (toFace + TOP_INSET) + Vector3.new(0, maxHeight + 0.5, 0)
	local top = cast(above, Vector3.new(0, -(maxHeight + 0.5 - minHeight), 0), params)
	if top == nil or top.Normal.Y < MIN_TOP_FLATNESS then
		return nil
	end

	-- 3. Height check (the ray's length already limits it; this rejects a
	-- top found right at the ray's start, i.e. inside a part).
	local height = top.Position.Y - feet.Y
	if height < minHeight or height > maxHeight then
		return nil
	end

	-- 4a. Nothing above our head on the way up (ceiling, overhang).
	local headroom = (top.Position.Y + ROOT_TO_FEET + 1) - root.Position.Y
	if headroom > 0 and cast(root.Position, Vector3.new(0, headroom, 0), params) then
		return nil
	end

	-- 4b. Room for the whole body standing on top.
	local edge = Vector3.new(feet.X + facing.X * toFace, top.Position.Y, feet.Z + facing.Z * toFace)
	local target = edge + facing * STAND_INSET + Vector3.new(0, ROOT_TO_FEET, 0)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	-- Box centered on the body, lifted a little so it doesn't touch the floor.
	local box = CFrame.lookAt(target, target + facing) + Vector3.new(0, 0.6, 0)
	for _, part in workspace:GetPartBoundsInBox(box, BODY_SIZE, overlap) do
		if part.CanCollide and not isCharacterPart(part) then
			return nil
		end
	end

	return { target = target, facing = facing, edge = edge, height = height }
end

-- Low obstacle = vault (fast, over it); higher = mantle (hang, pull up).
function Ledge.isVault(result: Result): boolean
	return result.height <= CLIMB.VAULT_MAX_HEIGHT
end

-- How long the move takes (seconds): higher ledges take longer to pull up.
function Ledge.duration(result: Result): number
	if Ledge.isVault(result) then
		return CLIMB.VAULT_DURATION
	end
	local extra = (result.height - CLIMB.VAULT_MAX_HEIGHT) * CLIMB.MANTLE_SECONDS_PER_STUD
	return math.min(CLIMB.MANTLE_MIN_DURATION + extra, CLIMB.MAX_DURATION)
end

return table.freeze(Ledge)
