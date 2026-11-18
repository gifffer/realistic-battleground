--!strict
-- Vfx/Floor: what is under a point (for floor dust, debris, cracks).
--
--   Floor.at(position, depth?)  → { position, normal, material, color }?
--   Floor.dustColor(floor?)     → the floor's colour pulled toward dust
--   Floor.ray(origin, vector)   → a RaycastResult that ignores fighters / VFX

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(script.Parent.Palette)
local Pool = require(script.Parent.Pool)

local Floor = {}

export type Hit = {
	position: Vector3,
	normal: Vector3,
	material: Enum.Material,
	color: Color3,
	instance: Instance,
}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

-- Fighters, corpses, our own VFX parts and the ragdoll / gore bits are
-- not "the floor".
local function refreshIgnore()
	local ignore: { Instance } = CollectionService:GetTagged(Config.Combat.TAG)
	for _, corpse in CollectionService:GetTagged(Config.Combat.CORPSE_TAG) do
		table.insert(ignore, corpse)
	end
	table.insert(ignore, Pool.folder())
	params.FilterDescendantsInstances = ignore
end

local function describe(result: RaycastResult): Hit
	local instance = result.Instance
	local material = result.Material
	local color = if instance:IsA("BasePart") then instance.Color else Palette.DustLight
	if instance:IsA("Terrain") then
		if material == Enum.Material.Air or material == Enum.Material.Water then
			material = Enum.Material.Grass
		end
		color = workspace.Terrain:GetMaterialColor(material)
	end
	return {
		position = result.Position,
		normal = result.Normal,
		material = material,
		color = color,
		instance = instance,
	}
end

-- The surface along `vector` from `origin` (walls too), ignoring fighters.
function Floor.ray(origin: Vector3, vector: Vector3): Hit?
	refreshIgnore()
	local result = workspace:Raycast(origin, vector, params)
	return if result then describe(result) else nil
end

-- The floor under `position`, at most `depth` studs below it (default 8).
-- (Starts 1 stud above, so a point ON the floor still finds it.)
function Floor.at(position: Vector3, depth: number?): Hit?
	refreshIgnore()
	local reach = (depth or 8) + 1
	local result = workspace:Raycast(position + Vector3.yAxis, Vector3.new(0, -reach, 0), params)
	if result == nil or result.Normal.Y < 0.5 then
		return nil -- nothing, or a steep wall
	end
	return describe(result)
end

-- Dust tinted like the floor it comes from (half way to a dusty grey).
function Floor.dustColor(floor: Hit?): Color3
	if floor == nil then
		return Palette.DustLight
	end
	return floor.color:Lerp(Palette.DustBase, 0.5)
end

return Floor
