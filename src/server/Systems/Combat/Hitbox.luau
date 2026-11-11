--!strict
-- Hitbox: "who is inside this box?" — done by the SERVER, never the client.
--
-- We ask Roblox for every part touching an invisible box placed in front of
-- the attacker (workspace:GetPartBoundsInBox), then keep each character
-- only once (a box touches several body parts of the same character).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)

local SHOW_DEBUG = Config.Combat.DEBUG_HITBOXES and RunService:IsStudio()

local Hitbox = {}

-- Red see-through box for 0.15 s (Studio only), to check hitboxes visually.
local function showDebugBox(cframe: CFrame, size: Vector3)
	local part = Instance.new("Part")
	part.Name = "DebugHitbox"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.ForceField
	part.Color = Color3.fromRGB(255, 40, 40)
	part.Transparency = 0.4
	part.CFrame = cframe
	part.Size = size
	part.Parent = workspace
	Debris:AddItem(part, 0.15)
end

-- Returns the models (with a living Humanoid) inside the box, and for each
-- one the names of its body parts that are inside ("Head", "Torso"...),
-- used to decide where the hit lands. `ignore` = the attacker's own model.
function Hitbox.query(
	cframe: CFrame,
	size: Vector3,
	ignore: Model
): ({ Model }, { [Model]: { [string]: boolean } })
	if SHOW_DEBUG then
		showDebugBox(cframe, size)
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }

	local result: { Model } = {}
	local partsByModel: { [Model]: { [string]: boolean } } = {}
	for _, part in workspace:GetPartBoundsInBox(cframe, size, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model then
			local parts = partsByModel[model]
			if parts == nil then
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					parts = {}
					partsByModel[model] = parts
					table.insert(result, model)
				end
			end
			if parts then
				parts[part.Name] = true
			end
		end
	end
	return result, partsByModel
end

return table.freeze(Hitbox)
