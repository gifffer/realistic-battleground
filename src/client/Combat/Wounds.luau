--!strict
-- Wounds: small visible marks on a fighter's body where they took hits
-- (step 5). The server counts them per body part ("Wound_Head",
-- "Wound_Torso", "Wound_LeftLeg"... attributes, at most
-- Config.Injuries.MAX_WOUNDS_PER_PART) and clears them on a kill or a new
-- life; every client draws them the same way.
--
-- A mark = a thin, flat, dark disc lying on the surface of the part
-- (bruise or dried cut), welded to it so it follows the animations.
-- Discreet on purpose. Same positions on every client (they come from a
-- fixed list, not from random numbers).
--
-- Glass on the head tears it open on that side, in 3 levels (raw muscle,
-- then the skull, then the bone broken open / the jaw): see below.
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
		{ normal = Vector3.new(0, 0, 1), at = Vector2.new(0.2, 0.1), size = 0.4, color = BRUISE }, -- back
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
	local normal = spot.normal
	-- Two directions along the face (u horizontal, v up).
	local u = if math.abs(normal.X) > 0.5 then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
	if part.Name == "Head" then
		-- The R6 head part is a 2×1×1 box, but what you SEE is its rounded
		-- mesh (about a 1.2-stud round shape): put the mark ON that curve,
		-- facing out from the centre, so it never floats in front of it.
		local radius = 0.6
		local side = math.clamp(spot.at.X * 2 * radius, -radius * 0.85, radius * 0.85)
		local around = normal * math.sqrt(radius * radius - side * side) + u * side
		local position = around + Vector3.new(0, spot.at.Y * 2 * radius * 0.8, 0)
		local outward = around.Unit
		return CFrame.fromMatrix(position + outward * 0.01, outward, Vector3.yAxis:Cross(outward))
	end
	local half = part.Size / 2
	local v = u:Cross(normal)
	if v.Y < 0 then
		v = -v
	end
	local position = normal * math.abs((half * normal):Dot(normal))
		+ u * (spot.at.X * 2 * math.abs((half * u):Dot(u)))
		+ v * (spot.at.Y * 2 * math.abs((half * v):Dot(v)))
	local lift = normal * 0.01 -- just above the surface, so it doesn't flicker
	return CFrame.fromMatrix(position + lift, normal, u)
end

-- Same name as the server's (no spaces allowed): "Right Leg" → "Wound_RightLeg".
local function attributeOf(partName: string): string
	return "Wound_" .. string.gsub(partName, " ", "")
end

local function refresh(model: Model, partName: string)
	local part = model:FindFirstChild(partName)
	local spots = SPOTS[partName]
	if part == nil or not part:IsA("BasePart") or spots == nil then
		return
	end
	local value = model:GetAttribute(attributeOf(partName))
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

------------------------------------------------------------------------------
-- Head torn open by glass ("HeadTorn_Front" / "HeadTorn_Left" /
-- "HeadTorn_Right" attributes, level 1 to Config.Injuries.HEAD_TEAR_MAX)
------------------------------------------------------------------------------
-- Each bottle that lands on the head (where it was aimed, not from behind)
-- opens that side a bit more:
--   1  the skin is torn away: raw muscle, ragged flaps of skin peeling off;
--   2  the hole widens and the SKULL shows through (pale bone);
--   3  the bone is broken open (a dark hole); on the face, the cheek is gone
--      and the jaw and TEETH show.
-- What you see of an R6 head is round (~1.2 studs): every piece is placed ON
-- that curve (several small pieces, not one big flat one that would float).
-- Fixed shapes and positions: the same on every client.

local MUSCLE = Color3.fromRGB(118, 20, 22)
local DEEP = Color3.fromRGB(64, 8, 9) -- dried blood, the deep edge of the wound
local BONE = Color3.fromRGB(222, 210, 184)
local CAVITY = Color3.fromRGB(24, 5, 5)
local TOOTH = Color3.fromRGB(236, 230, 214)

local HEAD_SIDES: { [string]: Vector3 } = {
	Front = FRONT,
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
}
-- Where each side's wound is centred (fractions, see markOffset): on the
-- face, toward a cheek; on a side of the head, toward the face (temple).
local CENTER: { [string]: Vector2 } = {
	Front = Vector2.new(-0.12, -0.02),
	Left = Vector2.new(-0.14, 0.04),
	Right = Vector2.new(-0.14, 0.04),
}

-- Overall size of the opened area (1 = the sizes below). Big enough to SEE a
-- part of the head open; each piece stays small enough to follow the curve.
local TEAR_SCALE = 1.45

type Piece = { at: Vector2, w: number, h: number, color: Color3, lift: number, wet: boolean? }
-- What each level ADDS (level 2 shows the pieces of levels 1 and 2...).
-- `lift` stacks the layers: deep edge, then flesh, then bone, then the hole.
local LEVEL_PIECES: { { Piece } } = {
	{ -- 1: skin torn away, raw muscle
		{ at = Vector2.new(0, 0), w = 0.36, h = 0.28, color = DEEP, lift = 0.004 },
		{ at = Vector2.new(0, 0), w = 0.3, h = 0.22, color = MUSCLE, lift = 0.012, wet = true },
		{
			at = Vector2.new(0.09, 0.06),
			w = 0.2,
			h = 0.16,
			color = MUSCLE,
			lift = 0.012,
			wet = true,
		},
	},
	{ -- 2: wider, the skull shows
		{ at = Vector2.new(-0.1, -0.06), w = 0.3, h = 0.24, color = DEEP, lift = 0.004 },
		{ at = Vector2.new(0.14, 0.02), w = 0.28, h = 0.22, color = DEEP, lift = 0.004 },
		{
			at = Vector2.new(-0.1, -0.06),
			w = 0.24,
			h = 0.18,
			color = MUSCLE,
			lift = 0.012,
			wet = true,
		},
		{
			at = Vector2.new(0.14, 0.02),
			w = 0.22,
			h = 0.16,
			color = MUSCLE,
			lift = 0.012,
			wet = true,
		},
		{ at = Vector2.new(0.03, 0.04), w = 0.2, h = 0.15, color = BONE, lift = 0.02 },
	},
	{ -- 3: the bone broken open, deeper
		{ at = Vector2.new(0.02, -0.16), w = 0.34, h = 0.22, color = DEEP, lift = 0.004 },
		{
			at = Vector2.new(0.02, -0.16),
			w = 0.28,
			h = 0.17,
			color = MUSCLE,
			lift = 0.012,
			wet = true,
		},
		{ at = Vector2.new(0.08, 0.07), w = 0.16, h = 0.12, color = BONE, lift = 0.022 },
		{ at = Vector2.new(0.03, 0.04), w = 0.09, h = 0.07, color = CAVITY, lift = 0.026 },
	},
}
-- Ragged flaps of skin peeling off at the edge of the wound (per level).
local FLAPS: { { Vector2 } } = {
	{ Vector2.new(0.16, 0.1), Vector2.new(-0.15, -0.05), Vector2.new(0.02, -0.14) },
	{ Vector2.new(0.28, 0.1), Vector2.new(-0.24, -0.12) },
	{ Vector2.new(0.1, -0.3), Vector2.new(-0.2, -0.24) },
}

local function weldTo(head: BasePart, part: BasePart, parent: Instance)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
end

-- The CFrame (relative to the head) of a point of the head's surface.
local function onHead(head: BasePart, normal: Vector3, at: Vector2, lift: number): CFrame
	local spot: Spot = { normal = normal, at = at, size = 0, color = DEEP }
	return markOffset(head, spot) * CFrame.new(lift, 0, 0)
end

-- A flat ellipse lying on the head: a thin block shaped by a sphere mesh.
local function patch(
	head: BasePart,
	offset: CFrame,
	w: number,
	h: number,
	color: Color3,
	parent: Instance
)
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.03, w, h)
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.CFrame = head.CFrame * offset
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	weldTo(head, part, parent)
	return part
end

local function drawHeadTear(head: BasePart, sideName: string, level: number, parent: Instance)
	local normal = HEAD_SIDES[sideName]
	local center = CENTER[sideName]
	for current = 1, level do
		for _, piece in LEVEL_PIECES[current] do
			local part = patch(
				head,
				onHead(head, normal, center + piece.at * TEAR_SCALE, piece.lift),
				piece.w * TEAR_SCALE,
				piece.h * TEAR_SCALE,
				piece.color,
				parent
			)
			if piece.wet then
				part.Reflectance = 0.15
			end
		end
		-- Flaps of torn skin, peeling outward from the edge.
		for index, at in FLAPS[current] do
			local flap = Instance.new("Part")
			flap.Size = Vector3.new(0.025, 0.13, 0.09)
			flap.Material = Enum.Material.SmoothPlastic
			flap.Color = head.Color
			local peel = CFrame.Angles(math.rad(index * 47), math.rad(-38), 0)
			flap.CFrame = head.CFrame * onHead(head, normal, center + at * TEAR_SCALE, 0.03) * peel
			weldTo(head, flap, parent)
		end
	end
	-- The cheek gone: the jaw and the teeth show.
	if level >= 3 and sideName == "Front" then
		for index = -2, 2 do
			local tooth = Instance.new("Part")
			tooth.Size = Vector3.new(0.04, 0.065, 0.08)
			tooth.Material = Enum.Material.SmoothPlastic
			tooth.Color = TOOTH
			local at = center + Vector2.new(0.02 + index * 0.05, -0.17) * TEAR_SCALE
			tooth.CFrame = head.CFrame * onHead(head, normal, at, 0.03)
			weldTo(head, tooth, parent)
		end
	end
end

local function refreshHeadTear(model: Model, sideName: string)
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local value = model:GetAttribute("HeadTorn_" .. sideName)
	local level = if typeof(value) == "number" then math.clamp(value, 0, #LEVEL_PIECES) else 0
	local folderName = "HeadTorn_" .. sideName
	local old = head:FindFirstChild(folderName)
	if old then
		old:Destroy() -- rebuilt from scratch: a few parts, only when it changes
	end
	if level == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = folderName
	drawHeadTear(head, sideName, level, folder)
	folder.Parent = head
end

function Wounds.watch(model: Model)
	for sideName in HEAD_SIDES do
		model:GetAttributeChangedSignal("HeadTorn_" .. sideName):Connect(function()
			refreshHeadTear(model, sideName)
		end)
		refreshHeadTear(model, sideName)
	end
	for partName in SPOTS do
		local attribute = attributeOf(partName)
		model:GetAttributeChangedSignal(attribute):Connect(function()
			refresh(model, partName)
		end)
		refresh(model, partName)
	end
end

return table.freeze(Wounds)
