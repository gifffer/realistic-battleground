--!strict
-- Gashes: glass cuts in a fighter's skin, drawn for real.
--
-- The server stores each cut as a "Gash_<Part>_<n>" attribute (where, how
-- big, which glass: Shared/Util/Gash). For a body part with cuts:
--   1. the real part is hidden and replaced by a SKIN SHELL made of flat
--      tiles, with the fighter's skin colour and their face / shirt /
--      pants drawn on them (from far, nothing changes),
--   2. the tiles are left out where the cut is (the hole follows the cut's
--      outline, cell by cell),
--   3. in the hole sits a WOUND INSERT, a small 3D model made in Blender
--      (tools/wounds): the skin edge, the pink cut edge, the red flesh, yellow
--      fat on the body, blood in it and running down. Deep slashes show the
--      muscle (body) or the skull at the bottom (head).
-- Everything here is visual and local: every client builds the same thing.
--
-- The wound models are imported in Studio once (docs/WOUNDS_FR.md):
-- ReplicatedStorage > Assets > Wounds > WoundKit. Without them, cuts are not
-- drawn (the blood effects still play).
--
--   Gashes.watch(model)   follow the cuts of this fighter

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gash = require(ReplicatedStorage.Shared.Util.Gash)
local WoundShapes = require(ReplicatedStorage.Shared.WoundShapes)

local Gashes = {}

------------------------------------------------------------------------------
-- Look of the insert layers (first word after the insert name: "LacM_Fat").
type Look = { color: Color3?, reflectance: number, material: Enum.Material }
local LOOKS: { [string]: Look } = {
	Lip = { color = nil, reflectance = 0, material = Enum.Material.SmoothPlastic }, -- skin colour
	Dermis = {
		color = Color3.fromRGB(196, 112, 104),
		reflectance = 0.08,
		material = Enum.Material.SmoothPlastic,
	},
	Flesh = {
		color = Color3.fromRGB(112, 14, 14),
		reflectance = 0.14,
		material = Enum.Material.SmoothPlastic,
	},
	Fat = {
		color = Color3.fromRGB(222, 188, 98),
		reflectance = 0.1,
		material = Enum.Material.SmoothPlastic,
	},
	Muscle = {
		color = Color3.fromRGB(86, 9, 11),
		reflectance = 0.12,
		material = Enum.Material.SmoothPlastic,
	},
	Bone = {
		color = Color3.fromRGB(222, 210, 186),
		reflectance = 0.05,
		material = Enum.Material.SmoothPlastic,
	},
	Blood = {
		color = Color3.fromRGB(62, 2, 2),
		reflectance = 0.3,
		material = Enum.Material.SmoothPlastic,
	},
}

local BACKING_COLOR = Color3.fromRGB(46, 4, 4) -- deep inside a cut
local BACKING_DEPTH = 0.14 -- under the skin, below the deepest insert (0.115)

-- Skin shell.
local THICKNESS = 0.04
local LIFT = 0.004 -- the shell's outer face sits this far above the real part
local CELL = 0.035 -- size of the cells the hole is cut from (studs)
-- Cells this close OUTSIDE the hole go too: the steps of the cells then
-- lie under the insert's skin edge, which covers them.
local HIDE_MARGIN = 0.02
-- The round R6 head, as drawn here: a cylinder with rounded top and bottom.
local HEAD_RADIUS = WoundShapes.headRadius - LIFT -- the head you see (~0.6)
local HEAD_BEVEL = 0.22 -- radius of the rounded top / bottom edge
local HEAD_SECTORS = 24
local HEAD_COLUMN = 0.045 -- column width near a cut (studs of arc)
-- Head inserts are bent around the head for a level cut: turning them more
-- than this would sink their ends into the skin.
local HEAD_MAX_TURN = 8
local PAD = 0.004 -- tiles are this much bigger than their cell (no cracks)

-- Clothing templates (585 x 559 pixels): where each face of a part is,
-- {x, y, width, height} in pixels (the official R6 template).
local TEMPLATE_W, TEMPLATE_H = 585, 559
local REGIONS: { [string]: { [string]: { number } } } = {
	Torso = {
		Front = { 231, 74, 128, 128 },
		Back = { 427, 74, 128, 128 },
		Left = { 361, 74, 64, 128 },
		Right = { 165, 74, 64, 128 },
		Top = { 231, 8, 128, 64 },
		Bottom = { 231, 204, 128, 64 },
	},
	Right = { -- right arm (shirt) / right leg (pants)
		Front = { 217, 355, 64, 128 },
		Back = { 85, 355, 64, 128 },
		Left = { 19, 355, 64, 128 },
		Right = { 151, 355, 64, 128 },
		Top = { 217, 289, 64, 64 },
		Bottom = { 217, 485, 64, 64 },
	},
	Left = { -- left arm / left leg
		Front = { 308, 355, 64, 128 },
		Back = { 440, 355, 64, 128 },
		Left = { 374, 355, 64, 128 },
		Right = { 506, 355, 64, 128 },
		Top = { 308, 289, 64, 64 },
		Bottom = { 308, 485, 64, 64 },
	},
}

-- The 6 faces of a block: outward normal and the "up" of a picture on it.
type Face = { name: string, normal: Vector3, up: Vector3 }
local FACES: { Face } = {
	{ name = "Front", normal = Vector3.new(0, 0, -1), up = Vector3.new(0, 1, 0) },
	{ name = "Back", normal = Vector3.new(0, 0, 1), up = Vector3.new(0, 1, 0) },
	{ name = "Left", normal = Vector3.new(-1, 0, 0), up = Vector3.new(0, 1, 0) },
	{ name = "Right", normal = Vector3.new(1, 0, 0), up = Vector3.new(0, 1, 0) },
	-- (the clothing template folds Up above Front and Down below it)
	{ name = "Top", normal = Vector3.new(0, 1, 0), up = Vector3.new(0, 0, 1) },
	{ name = "Bottom", normal = Vector3.new(0, -1, 0), up = Vector3.new(0, 0, -1) },
}

------------------------------------------------------------------------------
-- The wound kit (imported model) and where its inserts are.
type Kit = { frame: CFrame, unit: number, pieces: { [string]: { BasePart } } }
local kit: Kit? = nil
local warnedMarkers = false

-- The kit, once it is there and complete (nil until then: it is looked for
-- again on the next call, so a kit that replicates late still works).
local function findKit(): Kit?
	if kit then
		return kit
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local model = if assets then assets:FindFirstChild("WoundKit", true) else nil
	if model == nil then
		return nil
	end
	local origin = model:FindFirstChild("Kit_Origin", true)
	local up = model:FindFirstChild("Kit_Up", true)
	local out = model:FindFirstChild("Kit_Out", true)
	if
		not (
			origin
			and up
			and out
			and origin:IsA("BasePart")
			and up:IsA("BasePart")
			and out:IsA("BasePart")
		)
	then
		if not warnedMarkers then
			warnedMarkers = true
			warn("[Gashes] WoundKit: Kit_Origin / Kit_Up / Kit_Out missing (see docs/WOUNDS_FR.md)")
		end
		return nil
	end
	local toUp = up.Position - origin.Position
	local toOut = out.Position - origin.Position
	local y, z = toUp.Unit, toOut.Unit
	local found: Kit = {
		frame = CFrame.fromMatrix(origin.Position, y:Cross(z), y, z),
		unit = toUp.Magnitude, -- 1 kit stud, in studs (the importer may scale)
		pieces = {},
	}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local insert = string.match(item.Name, "^(.+)_%a+$")
			if insert and WoundShapes.shapes[insert] then
				local list = found.pieces[insert] or {}
				table.insert(list, item)
				found.pieces[insert] = list
			end
		end
	end
	-- Every insert must be there (the kit replicates piece by piece).
	for name in WoundShapes.shapes do
		if found.pieces[name] == nil then
			return nil
		end
	end
	kit = found
	return found
end

------------------------------------------------------------------------------
-- Geometry helpers.

-- Is the 2D point inside the outline, or less than `margin` outside it?
local function inOutline(points: { Vector2 }, p: Vector2, margin: number): boolean
	local inside = false
	local count = #points
	local j = count
	local nearest = math.huge
	for i = 1, count do
		local a, b = points[i], points[j]
		if (a.Y > p.Y) ~= (b.Y > p.Y) and p.X < (b.X - a.X) * (p.Y - a.Y) / (b.Y - a.Y) + a.X then
			inside = not inside
		end
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-9), 0, 1)
		nearest = math.min(nearest, (a + ab * t - p).Magnitude)
		j = i
	end
	return inside or nearest < margin
end

-- A cut placed on the part: its frame (part space; X along the cut's skin,
-- Y up, Z out of the skin) and how to test points of the skin against it.
type Placed = {
	data: Gash.Data,
	shapeName: string,
	shape: WoundShapes.Shape,
	frame: CFrame,
	face: string?, -- box parts: which face
	center: Vector2, -- box: (u, v) from the face's top-left; head: (angle, y)
}

local function shapeFor(data: Gash.Data, head: boolean): (string, WoundShapes.Shape?)
	local name = data.kind .. data.size .. (if head then "_Head" else "")
	return name, WoundShapes.shapes[name]
end

-- Half size of the cut once turned by `angle` (degrees), on the skin.
local function turnedExtent(extent: Vector2, angle: number): Vector2
	local c, s = math.abs(math.cos(math.rad(angle))), math.abs(math.sin(math.rad(angle)))
	return Vector2.new(c * extent.X + s * extent.Y, s * extent.X + c * extent.Y)
end

local function placeOnBox(part: BasePart, data: Gash.Data): Placed?
	local name, shape = shapeFor(data, false)
	if shape == nil then
		return nil
	end
	local half = part.Size / 2
	local p = data.point
	-- The side face the point is on (cuts are never on top / bottom).
	local face = FACES[1]
	local best = -math.huge
	for index = 1, 4 do
		local f = FACES[index]
		local along = p:Dot(f.normal) / math.abs(f.normal:Dot(half))
		if along > best then
			best, face = along, f
		end
	end
	local right = (-face.normal):Cross(face.up) -- your right, looking at the face
	local faceW = math.abs(right:Dot(part.Size))
	local faceH = math.abs(face.up:Dot(part.Size))
	-- Keep the whole cut (with its skin edge) on this face.
	local ext = turnedExtent(shape.extent, data.angle)
	local x = math.clamp(p:Dot(right), -(faceW / 2 - ext.X), faceW / 2 - ext.X)
	local y = math.clamp(p:Dot(face.up), -(faceH / 2 - ext.Y), faceH / 2 - ext.Y)
	if faceW / 2 < ext.X then
		x = 0
	end
	if faceH / 2 < ext.Y then
		y = 0
	end
	local depth = math.abs(face.normal:Dot(half)) + LIFT
	local origin = face.normal * depth + right * x + face.up * y
	local z = face.normal
	local yAxis = face.up
	local frame = CFrame.fromMatrix(origin, yAxis:Cross(z), yAxis, z)
		* CFrame.Angles(0, 0, math.rad(data.angle))
	return {
		data = data,
		shapeName = name,
		shape = shape,
		frame = frame,
		face = face.name,
		center = Vector2.new(x + faceW / 2, faceH / 2 - y),
	}
end

local function placeOnHead(_part: BasePart, data: Gash.Data): Placed?
	local name, shape = shapeFor(data, true)
	if shape == nil then
		return nil
	end
	-- (The R6 head has one size: its round shape is ~1.2 studs.)
	local p = data.point
	local angle = math.atan2(p.X, -p.Z) -- 0 = the face, + = toward its right (+X)
	-- Head cuts lie almost level (the insert is bent around the head).
	local turn = math.clamp(data.angle, -HEAD_MAX_TURN, HEAD_MAX_TURN)
	local ext = turnedExtent(shape.extent, turn)
	local band = 0.6 - HEAD_BEVEL
	local y = math.clamp(p.Y, -(band - ext.Y), band - ext.Y)
	local out = Vector3.new(math.sin(angle), 0, -math.cos(angle))
	local yAxis = Vector3.new(0, 1, 0)
	local origin = out * WoundShapes.headRadius + Vector3.new(0, y, 0)
	local frame = CFrame.fromMatrix(origin, yAxis:Cross(out), yAxis, out)
		* CFrame.Angles(0, 0, math.rad(turn))
	return {
		data = data,
		shapeName = name,
		shape = shape,
		frame = frame,
		face = nil,
		center = Vector2.new(angle, y),
	}
end

-- Is this point of the skin inside a cut? `at` is in part space, on the skin.
-- (Head: the arc length around the head is the cut's X, like the bent insert.)
local function cutAt(cuts: { Placed }, at: Vector3, head: boolean): boolean
	for _, cut in cuts do
		local x: number, y: number
		if head then
			local angle = math.atan2(at.X, -at.Z)
			local delta = (angle - cut.center.X + math.pi) % (2 * math.pi) - math.pi
			-- the insert's X runs toward decreasing angle (see placeOnHead)
			local local2 = Vector2.new(-delta * WoundShapes.headRadius, at.Y - cut.center.Y)
			local turn = math.rad(math.clamp(cut.data.angle, -HEAD_MAX_TURN, HEAD_MAX_TURN))
			local c, s = math.cos(-turn), math.sin(-turn)
			x, y = local2.X * c - local2.Y * s, local2.X * s + local2.Y * c
		else
			local rel = cut.frame:PointToObjectSpace(at)
			if math.abs(rel.Z) > 0.2 then
				continue -- another face
			end
			x, y = rel.X, rel.Y
		end
		local ext = cut.shape.extent
		if math.abs(x) <= ext.X and math.abs(y) <= ext.Y then
			if inOutline(cut.shape.points, Vector2.new(x, y), HIDE_MARGIN) then
				return true
			end
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Pictures (face, clothes) on the tiles: a SurfaceGui with the image placed
-- so the right part of it lands on this tile. Positions are fractions of the
-- tile, so the image's resolution doesn't matter.
type Picture = { image: string, region: { number }? }

local function paint(
	tile: BasePart,
	pictures: { Picture },
	faceW: number,
	faceH: number,
	a0: number,
	b0: number,
	w: number,
	h: number
)
	if #pictures == 0 then
		return
	end
	-- The SurfaceGui covers the whole tile, a hair bigger than its cell.
	a0, b0, w, h = a0 - PAD / 2, b0 - PAD / 2, w + PAD, h + PAD
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.ClipsDescendants = true
	for index, picture in pictures do
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.Image = picture.image
		label.ZIndex = index
		-- The whole image, measured in studs of this face:
		local imageW, imageH, left, top
		local region = picture.region
		if region then
			imageW = faceW * TEMPLATE_W / region[3]
			imageH = faceH * TEMPLATE_H / region[4]
			left = region[1] / TEMPLATE_W * imageW
			top = region[2] / TEMPLATE_H * imageH
		else
			imageW, imageH, left, top = faceW, faceH, 0, 0
		end
		label.Size = UDim2.fromScale(imageW / w, imageH / h)
		label.Position = UDim2.fromScale(-(left + a0) / w, -(top + b0) / h)
		label.Parent = gui
	end
	gui.Parent = tile
end

-- What is drawn on each face of a block part.
local function picturesFor(model: Model, key: string, faceName: string): { Picture }
	local list: { Picture } = {}
	local pants = model:FindFirstChildOfClass("Pants")
	local shirt = model:FindFirstChildOfClass("Shirt")
	local isLeg = string.find(key, "Leg") ~= nil
	local isArm = string.find(key, "Arm") ~= nil
	local side = if string.sub(key, 1, 4) == "Left" then "Left" else "Right"
	if pants and pants.PantsTemplate ~= "" and (isLeg or key == "Torso") then
		table.insert(list, {
			image = pants.PantsTemplate,
			region = REGIONS[if isLeg then side else "Torso"][faceName],
		})
	end
	if shirt and shirt.ShirtTemplate ~= "" and (isArm or key == "Torso") then
		table.insert(list, {
			image = shirt.ShirtTemplate,
			region = REGIONS[if isArm then side else "Torso"][faceName],
		})
	end
	local graphic = model:FindFirstChildOfClass("ShirtGraphic")
	if graphic and graphic.Graphic ~= "" and key == "Torso" and faceName == "Front" then
		table.insert(list, { image = graphic.Graphic, region = nil })
	end
	return list
end

------------------------------------------------------------------------------
-- Building.
local function setUp(piece: BasePart, part: BasePart, parent: Instance)
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = parent
end

local function newTile(part: BasePart, size: Vector3, offset: CFrame, parent: Instance): BasePart
	local tile = Instance.new("Part")
	tile.Name = "Skin"
	tile.Size = size
	tile.Color = part.Color
	tile.Material = Enum.Material.SmoothPlastic
	tile.TopSurface = Enum.SurfaceType.Smooth
	tile.BottomSurface = Enum.SurfaceType.Smooth
	tile.CFrame = part.CFrame * offset
	setUp(tile, part, parent)
	tile.CastShadow = true -- the body keeps its shadow
	return tile
end

-- Greedy cover of the kept cells of a grid by rectangles (few tiles).
-- keep[i][j]: column i (left to right), row j (top to bottom).
type Rect = { i: number, j: number, w: number, h: number }
local function rectangles(keep: { { boolean } }, columns: number, rows: number): { Rect }
	local used: { { boolean } } = {}
	for i = 1, columns do
		used[i] = {}
	end
	local out: { Rect } = {}
	for j = 1, rows do
		for i = 1, columns do
			if keep[i][j] and not used[i][j] then
				local w = 1
				while i + w <= columns and keep[i + w][j] and not used[i + w][j] do
					w += 1
				end
				local h = 1
				local grow = true
				while grow and j + h <= rows do
					for k = i, i + w - 1 do
						if not keep[k][j + h] or used[k][j + h] then
							grow = false
							break
						end
					end
					if grow then
						h += 1
					end
				end
				for a = i, i + w - 1 do
					for b = j, j + h - 1 do
						used[a][b] = true
					end
				end
				table.insert(out, { i = i, j = j, w = w, h = h })
			end
		end
	end
	return out
end

local function buildBoxSkin(
	model: Model,
	part: BasePart,
	key: string,
	cuts: { Placed },
	parent: Instance
)
	local half = part.Size / 2
	for _, face in FACES do
		local normal, up = face.normal, face.up
		local right = (-normal):Cross(up)
		local faceW = math.abs(right:Dot(part.Size))
		local faceH = math.abs(up:Dot(part.Size))
		local depth = math.abs(normal:Dot(half))
		local pictures = picturesFor(model, key, face.name)
		local mine = {}
		for _, cut in cuts do
			if cut.face == face.name then
				table.insert(mine, cut)
			end
		end
		local columns = if #mine > 0 then math.max(1, math.round(faceW / CELL)) else 1
		local rows = if #mine > 0 then math.max(1, math.round(faceH / CELL)) else 1
		local cw, ch = faceW / columns, faceH / rows
		local keep: { { boolean } } = {}
		for i = 1, columns do
			keep[i] = {}
			for j = 1, rows do
				local a, b = (i - 0.5) * cw, (j - 0.5) * ch -- from the top-left
				local at = normal * (depth + LIFT) + right * (a - faceW / 2) + up * (faceH / 2 - b)
				keep[i][j] = #mine == 0 or not cutAt(mine, at, false)
			end
		end
		for _, rect in rectangles(keep, columns, rows) do
			local a0, b0 = (rect.i - 1) * cw, (rect.j - 1) * ch
			local w, h = rect.w * cw, rect.h * ch
			local center = normal * (depth + LIFT - THICKNESS / 2)
				+ right * (a0 + w / 2 - faceW / 2)
				+ up * (faceH / 2 - b0 - h / 2)
			-- The tile's front (-Z) faces out; its Y is the picture's up.
			local offset = CFrame.fromMatrix(center, up:Cross(-normal), up, -normal)
			-- (a hair bigger: no cracks between tiles)
			local tile = newTile(part, Vector3.new(w + PAD, h + PAD, THICKNESS), offset, parent)
			paint(tile, pictures, faceW, faceH, a0, b0, w, h)
		end
	end
end

-- The round head: columns around it (thin where a cut is), rounded rims, caps.
local function buildHeadSkin(part: BasePart, cuts: { Placed }, parent: Instance)
	local s = 1 -- the R6 head has one size (see placeOnHead)
	local radius = HEAD_RADIUS * s
	local outer = radius + LIFT
	local band = (0.6 - HEAD_BEVEL) * s -- half height of the straight side
	local face = part:FindFirstChildOfClass("Decal")
	local faceImage = if face then face.Texture else ""
	local sector = 2 * math.pi / HEAD_SECTORS
	local rows = math.max(1, math.round(2 * band / CELL))
	local rowH = 2 * band / rows

	local function addColumn(angle: number, width: number)
		-- width in radians; cells from the top down
		local out = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local keep: { { boolean } } = { {} }
		local hasCut = false
		for j = 1, rows do
			local y = band - (j - 0.5) * rowH
			local cut = #cuts > 0 and cutAt(cuts, out * outer + Vector3.new(0, y, 0), true)
			keep[1][j] = not cut
			hasCut = hasCut or cut
		end
		local arc = width * outer
		local rects: { Rect } = if hasCut
			then rectangles(keep, 1, rows)
			else { { i = 1, j = 1, w = 1, h = rows } }
		for _, rect in rects do
			local top = band - (rect.j - 1) * rowH
			local h = rect.h * rowH
			local center = out * (outer - THICKNESS / 2) + Vector3.new(0, top - h / 2, 0)
			local up = Vector3.new(0, 1, 0)
			local offset = CFrame.fromMatrix(center, up:Cross(-out), up, -out)
			local tileW, tileH = arc + 0.012, h + PAD
			local tile = newTile(part, Vector3.new(tileW, tileH, THICKNESS), offset, parent)
			-- The face picture covers the front of the head, seen from the
			-- front: this column shows a slice of it (narrower near the sides).
			if faceImage ~= "" and math.cos(angle) > 0.2 then
				local projected = tileW * math.cos(angle)
				local tileTop = top + PAD / 2
				local leftEdge = outer * math.sin(angle) + projected / 2 -- your left = the head's +X
				local span = 2 * outer
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Front
				gui.LightInfluence = 1
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 100
				gui.ClipsDescendants = true
				local label = Instance.new("ImageLabel")
				label.BackgroundTransparency = 1
				label.Image = faceImage
				label.Size = UDim2.fromScale(span / projected, span / tileH)
				label.Position = UDim2.fromScale(
					-(outer - leftEdge) / projected,
					-(outer - tileTop) / tileH -- the picture's top = the top of the head
				)
				label.Parent = gui
				gui.Parent = tile
			end
		end
	end

	for index = 0, HEAD_SECTORS - 1 do
		local from = index * sector
		local mid = from + sector / 2
		-- Is a cut near this sector? Then thin columns, to cut it finely.
		local near = false
		for _, cut in cuts do
			local reach = (cut.shape.extent.Magnitude + 0.06) / outer
			local delta = math.abs((mid - cut.center.X + math.pi) % (2 * math.pi) - math.pi)
			if delta < reach + sector / 2 then
				near = true
			end
		end
		local count = if near then math.max(1, math.round(sector * outer / HEAD_COLUMN)) else 1
		for k = 0, count - 1 do
			addColumn(from + (k + 0.5) * sector / count, sector / count)
		end
	end

	-- Rounded rims (3 rings above, 3 below) and flat caps.
	for _, sign in { 1, -1 } do
		for _, tilt in { math.rad(15), math.rad(45), math.rad(75) } do
			local radial = radius
				- HEAD_BEVEL * s
				+ HEAD_BEVEL * s * math.cos(tilt)
				+ LIFT * math.cos(tilt)
			local y = sign * (band + HEAD_BEVEL * s * math.sin(tilt) + LIFT * math.sin(tilt))
			local height = HEAD_BEVEL * s * math.rad(30) + 0.01
			for index = 0, HEAD_SECTORS - 1 do
				local angle = (index + 0.5) * sector
				local out = Vector3.new(math.sin(angle), 0, -math.cos(angle))
				local normal = (out * math.cos(tilt) + Vector3.new(0, sign * math.sin(tilt), 0)).Unit
				local along = Vector3.new(0, 1, 0):Cross(out) -- around the head
				local up = normal:Cross(along).Unit
				if up.Y < 0 then
					up = -up
				end
				local center = out * radial + Vector3.new(0, y, 0) - normal * THICKNESS / 2
				local offset = CFrame.fromMatrix(center, up:Cross(-normal), up, -normal)
				newTile(
					part,
					Vector3.new(2 * math.pi * radial / HEAD_SECTORS + 0.012, height, THICKNESS),
					offset,
					parent
				)
			end
		end
		-- the cap: a disc (a cylinder part lies along its X axis: turn it up)
		local cap = Instance.new("Part")
		cap.Shape = Enum.PartType.Cylinder
		cap.Name = "Skin"
		cap.Size = Vector3.new(
			THICKNESS,
			2 * (radius - HEAD_BEVEL * s) + 0.02,
			2 * (radius - HEAD_BEVEL * s) + 0.02
		)
		cap.Color = part.Color
		cap.Material = Enum.Material.SmoothPlastic
		cap.CFrame = part.CFrame
			* CFrame.new(0, sign * (0.6 * s + LIFT - THICKNESS / 2), 0)
			* CFrame.Angles(0, 0, math.rad(90))
		setUp(cap, part, parent)
		cap.CastShadow = true
	end
end

-- The 3D wound model of one cut, from the kit, fitted on the part.
local function buildInsert(part: BasePart, cut: Placed, found: Kit, parent: Instance)
	local pieces = found.pieces[cut.shapeName]
	if pieces == nil then
		return
	end
	local origin = Vector3.new(cut.shape.index * WoundShapes.spacing, WoundShapes.markerDrop, 0)
	for _, item in pieces do
		local layer = string.match(item.Name, "_(%a+)$") or ""
		local look = LOOKS[layer]
		if look == nil then
			continue
		end
		local relative = found.frame:ToObjectSpace(item.CFrame)
		local position = relative.Position / found.unit - origin
		local piece = item:Clone()
		piece:ClearAllChildren()
		piece.Size = item.Size / found.unit
		piece.CFrame = part.CFrame * cut.frame * CFrame.new(position) * relative.Rotation
		piece.Color = look.color or part.Color
		piece.Reflectance = look.reflectance
		piece.Material = look.material
		setUp(piece, part, parent)
	end
	-- Dark flesh deep behind the cut: wherever the steps of the hole in the
	-- skin reach past the insert, you see deep red instead of through the body.
	local reachX, reachY = 0, 0
	for _, point in cut.shape.points do
		reachX, reachY = math.max(reachX, math.abs(point.X)), math.max(reachY, math.abs(point.Y))
	end
	local width = 2 * reachX + 0.06
	-- On a block: one flat plate. On the head: a few plates following its
	-- curve (a flat one would cross the ends of a long cut).
	local plates = if cut.face == nil then 5 else 1
	for k = 1, plates do
		local backing = Instance.new("Part")
		backing.Name = "Backing"
		backing.Size = Vector3.new(width / plates + 0.01, 2 * reachY + 0.06, 0.02)
		backing.Color = BACKING_COLOR
		backing.Material = Enum.Material.SmoothPlastic
		if cut.face == nil then
			local radius = WoundShapes.headRadius
			local along = (k - (plates + 1) / 2) * width / plates -- arc length
			-- turn around the head's axis (radius behind the skin point)
			backing.CFrame = part.CFrame
				* cut.frame
				* CFrame.new(0, 0, -radius)
				* CFrame.Angles(0, along / radius, 0)
				* CFrame.new(0, 0, radius - BACKING_DEPTH)
		else
			backing.CFrame = part.CFrame * cut.frame * CFrame.new(0, 0, -BACKING_DEPTH)
		end
		setUp(backing, part, parent)
	end
end

------------------------------------------------------------------------------
type Opened = {
	folder: Folder,
	partTransparency: number,
	face: Decal?, -- the face picture we hid, and its own transparency
	faceTransparency: number,
	connection: RBXScriptConnection?,
}
local opened: { [BasePart]: Opened } = {}

local function close(part: BasePart)
	local state = opened[part]
	if state == nil then
		return
	end
	opened[part] = nil
	if state.connection then
		state.connection:Disconnect()
	end
	state.folder:Destroy()
	part.Transparency = state.partTransparency
	if state.face then
		state.face.Transparency = state.faceTransparency
	end
end

local function refresh(model: Model, partName: string)
	local key = Gash.KEY_OF[partName]
	local part = model:FindFirstChild(partName)
	if key == nil or part == nil or not part:IsA("BasePart") then
		return
	end
	local found = findKit()
	local isHead = key == "Head"
	local cuts: { Placed } = {}
	if found then
		for index = 1, Gash.MAX_PER_PART do
			local data = Gash.decode(model:GetAttribute(Gash.attribute(key, index)))
			if data then
				local placed = if isHead then placeOnHead(part, data) else placeOnBox(part, data)
				-- (no insert for it in this kit: no hole either)
				if placed and found.pieces[placed.shapeName] then
					table.insert(cuts, placed)
				end
			end
		end
	end
	-- Rebuilt from scratch on each change (rare: a few times per fight).
	local previous = opened[part]
	local partTransparency = if previous then previous.partTransparency else part.Transparency
	local face = part:FindFirstChildOfClass("Decal")
	-- (the same face as before: we hid it, its real value is the saved one)
	local faceTransparency = if previous and previous.face == face
		then previous.faceTransparency
		else (if face then face.Transparency else 0)
	close(part)
	if #cuts == 0 or found == nil then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Gashes"
	if isHead then
		buildHeadSkin(part, cuts, folder)
	else
		buildBoxSkin(model, part, key, cuts, folder)
	end
	for _, cut in cuts do
		buildInsert(part, cut, found, folder)
	end
	local state: Opened = {
		folder = folder,
		partTransparency = partTransparency,
		face = face,
		faceTransparency = faceTransparency,
		connection = nil,
	}
	part.Transparency = 1
	if face then
		face.Transparency = 1 -- (a decal still shows on an invisible part)
	end
	-- Your own character: the camera hides parts in first person with
	-- LocalTransparencyModifier; hide what replaces them the same way.
	if model == Players.LocalPlayer.Character then
		local function follow()
			for _, item in folder:GetDescendants() do
				if item:IsA("BasePart") then
					item.LocalTransparencyModifier = part.LocalTransparencyModifier
				elseif item:IsA("SurfaceGui") then
					-- pictures don't follow the modifier: fade them with their part
					item.Enabled = part.LocalTransparencyModifier < 0.99
				elseif item:IsA("ImageLabel") then
					item.ImageTransparency = part.LocalTransparencyModifier
				end
			end
		end
		state.connection = part:GetPropertyChangedSignal("LocalTransparencyModifier")
			:Connect(follow)
		follow()
	end
	folder.Parent = part
	opened[part] = state
end

-- Fighters followed, to draw their cuts again if the kit arrives late.
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local waiting = false

local function refreshAll(model: Model)
	for partName in Gash.KEY_OF do
		refresh(model, partName)
	end
end

-- No kit yet: wait for it once (in the background), then draw everyone.
local function waitForKit()
	if waiting or findKit() then
		return
	end
	waiting = true
	task.spawn(function()
		while findKit() == nil do
			ReplicatedStorage.DescendantAdded:Wait()
		end
		for model in watched do
			if model.Parent then
				refreshAll(model)
			end
		end
	end)
end

function Gashes.watch(model: Model)
	watched[model] = true
	waitForKit()
	model.AttributeChanged:Connect(function(name: string)
		local key = string.match(name, "^" .. Gash.PREFIX .. "(%a+)_%d+$")
		local partName = if key then Gash.PART_OF[key] else nil
		if partName then
			refresh(model, partName)
		end
	end)
	-- Gone (destroyed, or just taken out of the game): forget its parts.
	local function forget()
		watched[model] = nil
		for partName in Gash.KEY_OF do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				close(part)
			end
		end
	end
	model.Destroying:Once(forget)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(game) then
			forget()
		elseif not watched[model] then
			watched[model] = true -- back in the game (streaming)
			refreshAll(model)
		end
	end)
	-- The clothes may load a moment after the character: draw again then.
	model.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Clothing") or child:IsA("ShirtGraphic") then
			refreshAll(model)
		end
	end)
	refreshAll(model)
end

return table.freeze(Gashes)
