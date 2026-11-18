--!strict
-- Breakable: which parts of the map a heavy move can smash (walls, crates,
-- pillars...), the same rule on the server (which breaks them) and on the
-- client (which lets its own charge go through without waiting for it).
--
-- Breakable: an anchored, solid, visible part that stands above the floor
-- the attacker stands on (not the ground, not a floor / roof slab), not
-- part of a fighter, at most MAX_SIZE studs, not marked "Unbreakable".
--   • To protect something (a lobby, an arena, the map's outer walls): give
--     it, or any of its parents, the CollectionService tag "Unbreakable" or
--     the attribute Unbreakable = true.
--   • A plain block wall is cut into pieces (only the ones hit go); any other
--     part (mesh, union, decorated) breaks whole if small enough.
--
--   Breakable.check(part, feetY) → "pieces" | "whole" | nil
--   Breakable.ground(cframe, size, feetY) → true if level with the feet
--   Breakable.support(root, exclude) → the part the attacker stands on
--       (never broken: he'd fall through)

local Breakable = {}

Breakable.MAX_SIZE = 80 -- studs: bigger than this never breaks
Breakable.WHOLE_MAX = 14 -- studs: a part breaking in one go
Breakable.PIECE = 3.5 -- studs: size of the pieces a wall is cut into

-- Is a box (`cframe`, `size`) level with / under the attacker's feet? The
-- ground, a step, a curb: not broken.
function Breakable.ground(cframe: CFrame, size: Vector3, feetY: number): boolean
	local half = size / 2
	local top = cframe.Position.Y
		+ math.abs(cframe.RightVector.Y) * half.X
		+ math.abs(cframe.UpVector.Y) * half.Y
		+ math.abs(cframe.LookVector.Y) * half.Z
	return top <= feetY + 1.2
end

local downParams = RaycastParams.new()
downParams.FilterType = Enum.RaycastFilterType.Exclude
downParams.RespectCanCollide = true

-- The part under the attacker (a ramp, a plank, a crate he's on), or nil.
function Breakable.support(root: BasePart, exclude: { Instance }): BasePart?
	downParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), downParams)
	local found = if hit then hit.Instance else nil
	return if found and found:IsA("BasePart") then found else nil
end

local function protected(part: Instance): boolean
	local node: Instance? = part
	while node and node ~= workspace do
		if node:HasTag("Unbreakable") or node:GetAttribute("Unbreakable") == true then
			return true
		end
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return true -- a fighter (or anything alive)
		end
		node = node.Parent
	end
	return false
end

local function decorated(part: BasePart): boolean
	for _, child in part:GetChildren() do
		if child:IsA("Decal") or child:IsA("SurfaceGui") then
			return true -- (Texture is a Decal)
		end
	end
	return false
end

-- How `part` breaks ("pieces" / "whole"), or nil if it doesn't. `feetY`:
-- the height of the attacker's feet.
function Breakable.check(part: BasePart, feetY: number): string?
	if
		not part.Anchored
		or not part.CanCollide
		or part.Transparency >= 0.9
		or part:IsA("Terrain")
		or part:IsA("SpawnLocation")
		or part:GetAttribute("Broken") == true
	then
		return nil
	end
	local size = part.Size
	local biggest = math.max(size.X, size.Y, size.Z)
	if biggest > Breakable.MAX_SIZE then
		return nil
	end
	-- The ground and what is level with it (a curb, a step): not broken.
	local frame = part.CFrame
	if Breakable.ground(frame, size, feetY) then
		return nil
	end
	local upX, upY, upZ =
		math.abs(frame.RightVector.Y), math.abs(frame.UpVector.Y), math.abs(frame.LookVector.Y)
	-- A floor / roof slab (its thin side facing up, wide both ways).
	local dims = { size.X, size.Y, size.Z }
	local ups = { upX, upY, upZ }
	local axis = 1
	if ups[2] > ups[axis] then
		axis = 2
	end
	if ups[3] > ups[axis] then
		axis = 3
	end
	local wide = math.min(dims[axis % 3 + 1], dims[(axis + 1) % 3 + 1])
	if dims[axis] < wide and wide >= 6 then
		return nil
	end
	if protected(part) then
		return nil
	end
	if
		part.ClassName == "Part"
		and (part :: Part).Shape == Enum.PartType.Block
		and not decorated(part)
	then
		return if biggest > Breakable.PIECE * 1.5 then "pieces" else "whole"
	end
	return if biggest <= Breakable.WHOLE_MAX then "whole" else nil
end

return table.freeze(Breakable)
