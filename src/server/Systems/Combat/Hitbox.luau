--!strict
-- Hitbox: "who is inside this box?" — done by the SERVER, never the client.
--
-- We ask Roblox for every part touching an invisible box placed in front of
-- the attacker (workspace:GetPartBoundsInBox), then keep each character
-- only once (a box touches several body parts of the same character).
--
-- Lag compensation (Combat/Rewind): given a `rewind` (seconds), the
-- fighters are ALSO tested where they were that long ago, i.e. where the
-- attacker saw them when he struck (give or take REWIND_TOLERANCE, for
-- the ping's jitter). Inside the box now OR then = inside. The body is
-- moved back as a whole (each part keeps its place on the root).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local BoxMath = require(ReplicatedStorage.Shared.Util.BoxMath)
local Rewind = require(script.Parent.Rewind)

local C = Config.Combat
local SHOW_DEBUG = C.DEBUG_HITBOXES and RunService:IsStudio()
local HITBOX_COLOR = Color3.fromRGB(255, 40, 40)
local REWOUND_COLOR = Color3.fromRGB(40, 120, 255)

-- R6 body parts tested in a rewound body (the ones the zones are made of).
local BODY_PARTS = table.freeze({
	"Head",
	"Torso",
	"HumanoidRootPart",
	"Right Arm",
	"Left Arm",
	"Right Leg",
	"Left Leg",
})
-- A body farther than this (studs) from the box now can't have been in it
-- within REWIND_MAX + REWIND_TOLERANCE seconds (nobody moves faster than
-- a knockback, 45 studs/s): not rewound.
local REWIND_SEARCH = 25
-- Rewound times tested, around the attacker's view (× REWIND_TOLERANCE).
local SPREAD = table.freeze({ 0, -1, 1 })

local Hitbox = {}

-- See-through box for 0.15 s (Studio only), to check hitboxes visually:
-- red = the hitbox, blue = a torso put back where the attacker saw it.
local function showDebugBox(cframe: CFrame, size: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Name = "DebugHitbox"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.ForceField
	part.Color = color
	part.Transparency = 0.4
	part.CFrame = cframe
	part.Size = size
	part.Parent = workspace
	Debris:AddItem(part, 0.15)
end

local function isAlive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- `model`'s body parts inside the box when its root is at `rootAt` (each
-- part keeps where it is on the root now). nil if none is.
local function partsInBoxAt(
	model: Model,
	liveRoot: BasePart,
	rootAt: CFrame,
	box: CFrame,
	size: Vector3
): { [string]: boolean }?
	-- (moves a part from where it is now to where it was)
	local shift = rootAt * liveRoot.CFrame:Inverse()
	local parts: { [string]: boolean }? = nil
	for _, name in BODY_PARTS do
		local part = model:FindFirstChild(name)
		if
			part
			and part:IsA("BasePart")
			and BoxMath.boxesOverlap(box, size, shift * part.CFrame, part.Size)
		then
			local inside = parts or {}
			inside[name] = true
			parts = inside
		end
	end
	return parts
end

-- Returns the models (with a living Humanoid) inside the box, and for each
-- one the names of its body parts that are inside ("Head", "Torso"...),
-- used to decide where the hit lands. `ignore` = the attacker's own model.
-- `rewind` (seconds, from Combat/Rewind.amount): also test the fighters
-- where they were that long ago. Third result: for the ones found that
-- way, the root CFrame they were found at (the aim ray is then cast at
-- that same body, see rayAt).
function Hitbox.query(
	cframe: CFrame,
	size: Vector3,
	ignore: Model,
	rewind: number?
): ({ Model }, { [Model]: { [string]: boolean } }, { [Model]: CFrame })
	if SHOW_DEBUG then
		showDebugBox(cframe, size, HITBOX_COLOR)
	end

	local result: { Model } = {}
	local partsByModel: { [Model]: { [string]: boolean } } = {}
	local rootByModel: { [Model]: CFrame } = {}

	-- Where the attacker saw them (tested first: it picks the zone).
	if rewind and rewind > 0 then
		local reach = size.Magnitude / 2 + REWIND_SEARCH
		for model, liveRoot in Rewind.each() do
			if
				model == ignore
				or model.Parent == nil
				or (liveRoot.Position - cframe.Position).Magnitude > reach
				or not isAlive(model)
			then
				continue
			end
			for _, step in SPREAD do
				local rootAt = Rewind.rootAt(model, math.max(rewind + step * C.REWIND_TOLERANCE, 0))
				local parts = if rootAt
					then partsInBoxAt(model, liveRoot, rootAt, cframe, size)
					else nil
				if rootAt and parts then
					table.insert(result, model)
					partsByModel[model] = parts
					rootByModel[model] = rootAt
					local torso = if SHOW_DEBUG then model:FindFirstChild("Torso") else nil
					if torso and torso:IsA("BasePart") then
						local shift = rootAt * liveRoot.CFrame:Inverse()
						showDebugBox(shift * torso.CFrame, torso.Size, REWOUND_COLOR)
					end
					break
				end
			end
		end
	end

	-- Where they are now (someone stepping into the punch is hit too).
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	for _, part in workspace:GetPartBoundsInBox(cframe, size, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not rootByModel[model] then
			local parts = partsByModel[model]
			if parts == nil and isAlive(model) then
				parts = {}
				partsByModel[model] = parts
				table.insert(result, model)
			end
			if parts then
				parts[part.Name] = true
			end
		end
	end
	return result, partsByModel, rootByModel
end

-- The first part of `model` (a body part or a worn accessory's handle)
-- met by the ray from `origin` along `ray`, with the root put at `rootAt`
-- (a rewound body, see query). nil if it meets none.
function Hitbox.rayAt(model: Model, origin: Vector3, ray: Vector3, rootAt: CFrame): BasePart?
	local liveRoot = model:FindFirstChild("HumanoidRootPart")
	if liveRoot == nil or not liveRoot:IsA("BasePart") then
		return nil
	end
	local shift = rootAt * liveRoot.CFrame:Inverse()
	local closest = math.huge
	local hit: BasePart? = nil
	for _, child in model:GetChildren() do
		local part = if child:IsA("Accessory") then child:FindFirstChild("Handle") else child
		if part and part:IsA("BasePart") then
			local t = BoxMath.rayHitsBox(origin, ray, shift * part.CFrame, part.Size)
			if t and t <= 1 and t < closest then
				closest, hit = t, part
			end
		end
	end
	return hit
end

return table.freeze(Hitbox)
