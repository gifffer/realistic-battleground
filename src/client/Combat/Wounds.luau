--!strict
-- Wounds: small visible marks on a fighter's body where they took hits
-- (step 5). The server counts them per body part ("Wound_Head",
-- "Wound_Torso", "Wound_Left Leg"... attributes, at most
-- Config.Injuries.MAX_WOUNDS_PER_PART) and clears them on a kill or a new
-- life; every client draws them the same way.
--
-- A mark = a thin, flat, dark disc lying on the surface of the part
-- (bruise or dried cut), welded to it so it follows the animations.
-- Discreet on purpose: no gore. Same positions on every client (they come
-- from a fixed list, not from random numbers).
--
--   Wounds.watch(model)   start drawing the marks of this fighter

local Wounds = {}

local BRUISE = Color3.fromRGB(58, 30, 38) -- dark purple-red
local CUT = Color3.fromRGB(86, 14, 12) -- dried blood

-- Where the marks go on each part: the face of the part (its normal, in
-- the part's space), a position on that face (fractions of the size, -0.5
-- to 0.5), a size in studs and the kind of mark. In this order: 1st mark,
-- 2nd mark, 3rd mark.
type Spot = { normal: Vector3, at: Vector2, size: number, color: Color3 }

local FRONT = Vector3.new(0, 0, -1)
local SPOTS: { [string]: { Spot } } = {
	Head = {
		{ normal = FRONT, at = Vector2.new(0.28, 0.22), size = 0.22, color = CUT }, -- eyebrow
		{ normal = FRONT, at = Vector2.new(-0.25, -0.12), size = 0.3, color = BRUISE }, -- cheek
		{ normal = Vector3.new(1, 0, 0), at = Vector2.new(0.1, 0.05), size = 0.28, color = BRUISE }, -- temple
	},
	Torso = {
		{ normal = FRONT, at = Vector2.new(0.3, -0.15), size = 0.45, color = BRUISE }, -- ribs
		{ normal = FRONT, at = Vector2.new(-0.2, 0.25), size = 0.35, color = BRUISE },
		{ normal = Vector3.new(-1, 0, 0), at = Vector2.new(0, -0.1), size = 0.4, color = BRUISE },
	},
	["Right Leg"] = {
		{ normal = FRONT, at = Vector2.new(0, -0.15), size = 0.35, color = BRUISE }, -- shin
		{ normal = FRONT, at = Vector2.new(0.1, 0.2), size = 0.3, color = BRUISE },
		{ normal = Vector3.new(1, 0, 0), at = Vector2.new(0, 0), size = 0.3, color = BRUISE },
	},
	["Left Leg"] = {
		{ normal = FRONT, at = Vector2.new(0, -0.15), size = 0.35, color = BRUISE },
		{ normal = FRONT, at = Vector2.new(-0.1, 0.2), size = 0.3, color = BRUISE },
		{ normal = Vector3.new(-1, 0, 0), at = Vector2.new(0, 0), size = 0.3, color = BRUISE },
	},
}

-- The mark's CFrame relative to its part: on the face given by `normal`,
-- lying flat (a cylinder's axis is its X: turned to point along the normal).
local function markOffset(part: BasePart, spot: Spot): CFrame
	-- The R6 head part is a 2×1×1 box, but what you SEE is its rounded
	-- mesh, about 1.2 studs each way: use that.
	local size = if part.Name == "Head" then Vector3.new(1.2, 1.2, 1.2) else part.Size
	local half = size / 2
	local normal = spot.normal
	-- Two directions along the face (v points up on the front and the sides).
	local u = if math.abs(normal.X) > 0.5 then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
	local v = u:Cross(normal)
	if v.Y < 0 then
		v = -v
	end
	local position = normal * (half * normal):Dot(normal) / normal.Magnitude
		+ u * (spot.at.X * 2 * math.abs((half * u):Dot(u)))
		+ v * (spot.at.Y * 2 * math.abs((half * v):Dot(v)))
	local lift = normal * 0.01 -- just above the surface, so it doesn't flicker
	return CFrame.fromMatrix(position + lift, normal, u)
end

local function refresh(model: Model, partName: string)
	local part = model:FindFirstChild(partName)
	local spots = SPOTS[partName]
	if part == nil or not part:IsA("BasePart") or spots == nil then
		return
	end
	local value = model:GetAttribute(`Wound_{partName}`)
	local count = if typeof(value) == "number" then math.clamp(value, 0, #spots) else 0
	local folder = part:FindFirstChild("Wounds")
	-- Remove the extra marks (healed), add the missing ones.
	local existing = if folder then folder:GetChildren() else {}
	if count == 0 then
		if folder then
			folder:Destroy()
		end
		return
	end
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = "Wounds"
		created.Parent = part
		folder = created
	end
	for index = #existing, count + 1, -1 do
		existing[index]:Destroy()
	end
	for index = #existing + 1, count do
		local spot = spots[index]
		local mark = Instance.new("Part")
		mark.Name = `Mark{index}`
		mark.Shape = Enum.PartType.Cylinder
		mark.Size = Vector3.new(0.02, spot.size, spot.size * 0.75)
		mark.Material = Enum.Material.SmoothPlastic
		mark.Color = spot.color
		mark.Transparency = 0.25
		mark.CanCollide = false
		mark.CanQuery = false
		mark.CanTouch = false
		mark.CastShadow = false
		mark.Massless = true
		mark.CFrame = part.CFrame * markOffset(part, spot)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = mark
		weld.Parent = mark
		mark.Parent = folder
	end
end

function Wounds.watch(model: Model)
	for partName in SPOTS do
		local attribute = `Wound_{partName}`
		model:GetAttributeChangedSignal(attribute):Connect(function()
			refresh(model, partName)
		end)
		refresh(model, partName)
	end
end

return table.freeze(Wounds)
