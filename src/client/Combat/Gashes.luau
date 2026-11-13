--!strict
-- Gashes: glass cuts in a fighter's skin, drawn for real.
--
-- The server stores each cut as a "Gash_<Part>_<n>" attribute (where, how
-- big, which glass: Shared/Util/Gash). For a body part with cuts:
--   1. the real part is hidden and replaced by an exact copy of it, the
--      SKIN SHELL (Roblox can't cut a hole in a part): same shape, colour
--      and material, the face / shirt / pants drawn on it. The torso: flat
--      tiles. The head: smooth pieces of the classic round head (made in
--      Blender, exact measures), so it doesn't change shape at all,
--   2. the tiles are left out where the cut is (the hole follows the cut's
--      outline, cell by cell),
--   3. in the hole sits a WOUND INSERT, a small 3D model made in Blender
--      (tools/wounds): the skin edge, the pink cut edge, the red flesh, yellow
--      fat on the body, blood in it and running down. Deep slashes show the
--      muscle (body) or the skull at the bottom (head).
-- The Sentinel's finisher ("Bore") is a deep hole burnt over the heart: its
-- insert is a closed cup (the ribs cut, the lung's edge, the heart burnt
-- through), so the inside of the torso shell is opened around it.
-- Everything here is visual and local: every client builds the same thing.
--
-- The wound models are imported in Studio once (docs/WOUNDS_FR.md):
-- ReplicatedStorage > Assets > Wounds > WoundKit. Without them, cuts are not
-- drawn (the blood effects still play).
--
--   Gashes.watch(model)   follow the cuts of this fighter
--   Gashes.hasBore()      the kit has the Sentinel's bore inserts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gash = require(ReplicatedStorage.Shared.Util.Gash)
local WoundShapes = require(ReplicatedStorage.Shared.WoundShapes)
local ArmRip = require(script.Parent.ArmRip)
local Bisect = require(script.Parent.Bisect)
local BloodGush = require(script.Parent.BloodGush)
local HeadBlast = require(script.Parent.HeadBlast)

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

-- A burn ("Burn": the Sentinel's heat vision): the skin burnt clean away,
-- like a deep friction / thermal wound - a thin raw red rim where the skin
-- stops, and in the hole the pale, moist tissue under it: cream fascia with
-- the whitish-yellow tendons showing, a little yellow fat, the skull on the
-- head. Barely any blood (cauterized), no black crust.
local CHARRED = Color3.fromRGB(26, 19, 16) -- (the bore's crust still uses it)
local RAW_RIM = Color3.fromRGB(150, 36, 34)
local RAW_WALL = Color3.fromRGB(186, 82, 74)
local BURN_LOOKS: { [string]: Look } = {
	-- (the burn inserts: BurnS / M / L, made for it)
	Char = { color = RAW_RIM, reflectance = 0.1, material = Enum.Material.SmoothPlastic },
	Eschar = { color = RAW_WALL, reflectance = 0.1, material = Enum.Material.SmoothPlastic },
	-- (an older kit without them: the laceration's insert)
	Lip = { color = RAW_RIM, reflectance = 0.1, material = Enum.Material.SmoothPlastic },
	Dermis = { color = RAW_WALL, reflectance = 0.1, material = Enum.Material.SmoothPlastic },
	Fat = {
		color = Color3.fromRGB(226, 200, 140),
		reflectance = 0.14,
		material = Enum.Material.SmoothPlastic,
	},
	Flesh = { -- the fascia: pale cream, a pink tinge
		color = Color3.fromRGB(226, 204, 182),
		reflectance = 0.12,
		material = Enum.Material.SmoothPlastic,
	},
	Muscle = { -- the floor with its ridges: whitish-yellow tendons
		color = Color3.fromRGB(236, 222, 186),
		reflectance = 0.16,
		material = Enum.Material.SmoothPlastic,
	},
	Bone = {
		color = Color3.fromRGB(226, 214, 186),
		reflectance = 0.06,
		material = Enum.Material.SmoothPlastic,
	},
}
-- (the bottom of a burn on the head: the skull)
local SKULL = Color3.fromRGB(214, 200, 172)
local BURN_BACKING = Color3.fromRGB(196, 150, 128)

-- The Sentinel's bore ("Bore": BoreS / M / L): the beam went into the chest
-- over the heart, so hot that nothing bled. Everything it touched is seared:
-- the crust black, the cut skin cooked brown, the fat rendered, the muscle
-- grey-brown; the ribs' bone off-white, their cartilage blue-white and
-- glossy, the lung's edge pink-grey, the heart's muscle dark red, the inside
-- of its chamber darker still. No blood layer at all.
local BORE_LOOKS: { [string]: Look } = {
	Char = { color = CHARRED, reflectance = 0, material = Enum.Material.Slate },
	Eschar = {
		color = Color3.fromRGB(122, 80, 50),
		reflectance = 0.04,
		material = Enum.Material.SmoothPlastic,
	},
	Fat = {
		color = Color3.fromRGB(188, 138, 62),
		reflectance = 0.16,
		material = Enum.Material.SmoothPlastic,
	},
	Muscle = {
		color = Color3.fromRGB(104, 46, 36),
		reflectance = 0.06,
		material = Enum.Material.SmoothPlastic,
	},
	Bone = {
		color = Color3.fromRGB(226, 214, 190),
		reflectance = 0.05,
		material = Enum.Material.SmoothPlastic,
	},
	Cartilage = {
		color = Color3.fromRGB(198, 212, 220),
		reflectance = 0.14,
		material = Enum.Material.SmoothPlastic,
	},
	Lung = {
		color = Color3.fromRGB(178, 134, 138),
		reflectance = 0.03,
		material = Enum.Material.SmoothPlastic,
	},
	Heart = {
		color = Color3.fromRGB(92, 16, 18),
		reflectance = 0.1,
		material = Enum.Material.SmoothPlastic,
	},
	HeartDark = {
		color = Color3.fromRGB(38, 7, 8),
		reflectance = 0.02,
		material = Enum.Material.SmoothPlastic,
	},
}
-- Behind the bore's cup (never seen: the cup is closed; only if a crack
-- showed between its rim and the skin's cells).
local BORE_BACKING = Color3.fromRGB(30, 8, 6)

local BACKING_COLOR = Color3.fromRGB(46, 4, 4) -- deep inside a cut
local BACKING_DEPTH = 0.14 -- under the skin, below the deepest insert (0.115)

-- Skin shell: its outer surface is exactly the real part's.
local THICKNESS = 0.04
local CELL = 0.035 -- size of the cells the hole is cut from (studs)
-- Cells this close OUTSIDE the hole go too: the steps of the cells then
-- lie under the insert's skin edge, which covers them.
local HIDE_MARGIN = 0.02
-- The classic R6 head (measured from Roblox's head.mesh): radius 0.6, a
-- straight part 0.6 high, edges rounded by 0.3, flat caps.
local HEAD_RADIUS = WoundShapes.headRadius
local HEAD_BAND = WoundShapes.headBand -- half height of the straight part
local HEAD_SECTORS = 24 -- Shell_Band24 / Shell_Bevel24 pieces around the head
local HEAD_FINE = 8 -- a sector with a cut in it: 8 thin columns (Shell_Band192)
-- Head inserts are bent around the head for a level cut: turning them more
-- than this would sink their ends into the skin.
local HEAD_MAX_TURN = 8
local SHELL_PIECES = { "Shell_Band24", "Shell_Band192", "Shell_Bevel24", "Shell_Cap" }
-- The face picture's pieces, one set per front sector (see the kit).
local function isFrontSector(index: number): boolean
	return math.cos((index + 0.5) * 2 * math.pi / HEAD_SECTORS) > 0
end
for index = 0, HEAD_SECTORS - 1 do
	if isFrontSector(index) then
		for _, piece in { "Band", "Top", "Bottom" } do
			table.insert(SHELL_PIECES, `Shell_Face{piece}_{index}`)
		end
	end
end
-- Pictures on meshes (face, clothes on the bevels): Roblox lets their
-- transparent pixels show what is under them only if the part is a hair
-- transparent itself.
local SEE_THROUGH = 0.02
-- Torso tiles overlap their neighbours by this much: no crack at T-joints
-- (the overlaps are identical skin and picture, nothing flickers).
local PAD = 0.002

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
type Kit = {
	frame: CFrame,
	unit: number,
	pieces: { [string]: { BasePart } }, -- inserts
	shell: { [string]: BasePart }, -- head shell pieces
	shellComplete: boolean, -- false: an old WoundKit (no head cuts then)
	framesComplete: boolean, -- false: an old WoundKit (no torso cuts then)
}
local kit: Kit? = nil
-- A kit found without some of its later inserts (an old kit, or one still
-- replicating): used as it is until something is added to it, then looked
-- through again (and the fighters drawn again: Gashes.watch).
local partial: Kit? = nil
local partialFrom: Instance? = nil
local onKitChanged: (() -> ())? = nil
local warnedMarkers = false
local warnedOldKit = false
local warnedNoBurn = false

-- The kit, once it is there and complete (nil until then: it is looked for
-- again on the next call, so a kit that replicates late still works).
-- Does the kit have the burn inserts (made after the first kits)?
local burnInKit = false
-- ...and the Sentinel's bore over the heart (BoreS / M / L, later still)?
local boreInKit = false

-- The WoundKit to use. A place may hold more than one (an older import
-- left beside the new one): the one with the most inserts is used, never
-- just the first found (an old one has no burn / bore inserts: burns and
-- the bore were then drawn with the small laceration's insert).
local function bestKitModel(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil
	end
	local best: Instance? = nil
	local bestCount = -1
	for _, item in assets:GetDescendants() do
		if item.Name ~= "WoundKit" or item:IsA("BasePart") then
			continue
		end
		local inserts: { [string]: boolean } = {}
		local count = 0
		for _, piece in item:GetDescendants() do
			if piece:IsA("BasePart") then
				local insert = string.match(piece.Name, "^(.+)_%a+$")
				if insert and WoundShapes.shapes[insert] and not inserts[insert] then
					inserts[insert] = true
					count += 1
				end
			end
		end
		if count > bestCount then
			best, bestCount = item, count
		end
	end
	return best
end

local function findKit(): Kit?
	if kit then
		return kit
	end
	if partial and partialFrom and partialFrom:IsDescendantOf(ReplicatedStorage) then
		return partial
	end
	local model = bestKitModel()
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
		shell = {},
		shellComplete = true,
		framesComplete = true,
	}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and string.sub(item.Name, 1, 6) == "Shell_" then
			found.shell[item.Name] = item
		elseif item:IsA("BasePart") then
			local insert = string.match(item.Name, "^(.+)_%a+$")
			if insert and WoundShapes.shapes[insert] then
				local list = found.pieces[insert] or {}
				table.insert(list, item)
				found.pieces[insert] = list
			end
		end
	end
	-- Every glass insert must be there (the kit replicates piece by piece).
	-- The finishers' own ("Tear") may be missing from an older kit: only
	-- that cut is skipped then.
	local tearMissing = false
	for name, shape in WoundShapes.shapes do
		if found.pieces[name] == nil then
			if shape.kind == "Burn" then
				continue -- (an older kit: burns use the laceration's insert)
			end
			if shape.kind == "Bore" then
				continue -- (an older kit: no bore, see Gashes.hasBore)
			end
			if shape.kind ~= "Tear" then
				return nil
			end
			tearMissing = true
		end
	end
	burnInKit = found.pieces.BurnS ~= nil and found.pieces.BurnL_Head ~= nil
	boreInKit = found.pieces.BoreS ~= nil
		and found.pieces.BoreM ~= nil
		and found.pieces.BoreL ~= nil
	if not (burnInKit and boreInKit) and not warnedNoBurn then
		-- (said only if still so a moment later: not while it replicates)
		warnedNoBurn = true
		task.delay(10, function()
			local again = findKit()
			if again and not (burnInKit and boreInKit) then
				warn(
					"[Gashes] WoundKit is out of date (no "
						.. (if burnInKit then "" else "Burn* ")
						.. (if boreInKit then "" else "Bore* ")
						.. "inserts): the heat vision's burns and the Sentinel's bore are "
						.. "drawn with smaller stand-ins. Delete it and import "
						.. "assets/wounds/WoundKit.fbx again (docs/WOUNDS_FR.md)."
				)
			end
		end)
	end
	if tearMissing and not warnedOldKit then
		warnedOldKit = true
		warn(
			"[Gashes] WoundKit is out of date (no TearL: the Boxer finisher's wound is off). "
				.. "Delete it and import assets/wounds/WoundKit.fbx again (docs/WOUNDS_FR.md)."
		)
	end
	for _, name in SHELL_PIECES do
		local piece: BasePart? = found.shell[name]
		if piece == nil then
			found.shellComplete = false
		end
	end
	for name in WoundShapes.frames do
		local piece: BasePart? = found.shell[name]
		if piece == nil then
			found.framesComplete = false
		end
	end
	if not (found.shellComplete and found.framesComplete) and not warnedOldKit then
		warnedOldKit = true
		warn(
			"[Gashes] WoundKit is out of date (Shell_ pieces missing): "
				.. (if found.shellComplete then "" else "head cuts are off. ")
				.. (if found.framesComplete then "" else "torso cuts are off. ")
				.. "Delete it and import assets/wounds/WoundKit.fbx again (docs/WOUNDS_FR.md)."
		)
	end
	local complete = not tearMissing
		and burnInKit
		and boreInKit
		and found.shellComplete
		and found.framesComplete
	if complete then
		kit = found
		partial = nil
		partialFrom = nil
	else
		-- (not kept for good: the missing inserts may still arrive, in this
		-- kit or in another one arriving later)
		partial = found
		partialFrom = model
		local watchedFrom = ReplicatedStorage:FindFirstChild("Assets") or model
		watchedFrom.DescendantAdded:Once(function()
			if partial == found then
				partial = nil
				if onKitChanged then
					onKitChanged()
				end
			end
		end)
	end
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

-- The insert drawn for a cut: its own, or (a kit without it) the nearest
-- one this kit has. Looked up in the kit used for this drawing (never in
-- what an earlier look at a kit still arriving had found).
local function shapeFor(data: Gash.Data, head: boolean, found: Kit): (string, WoundShapes.Shape?)
	local suffix = if head then "_Head" else ""
	local function has(name: string): boolean
		return found.pieces[name] ~= nil and WoundShapes.shapes[name] ~= nil
	end
	local kind, size = data.kind, data.size
	if kind == "Bore" and (head or not has("Bore" .. size)) then
		-- (an older kit without the bore: a big burn there instead)
		kind, size = "Burn", if size == "S" then "M" else "L"
	end
	-- (a burn: its own insert; an older kit without it: the laceration's)
	if kind == "Burn" and not has("Burn" .. size .. suffix) then
		kind = "Lac"
	end
	local name = kind .. size .. suffix
	return name, WoundShapes.shapes[name]
end

-- Half size of the cut once turned by `angle` (degrees), on the skin.
local function turnedExtent(extent: Vector2, angle: number): Vector2
	local c, s = math.abs(math.cos(math.rad(angle))), math.abs(math.sin(math.rad(angle)))
	return Vector2.new(c * extent.X + s * extent.Y, s * extent.X + c * extent.Y)
end

local function placeOnBox(part: BasePart, data: Gash.Data, found: Kit): Placed?
	local name, shape = shapeFor(data, false, found)
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
	-- (inside the flat part of the face: not on its bevelled edges)
	local ext = turnedExtent(shape.extent, data.angle)
	local roomX = faceW / 2 - WoundShapes.chamfer - ext.X
	local roomY = faceH / 2 - WoundShapes.chamfer - ext.Y
	local x = if roomX > 0 then math.clamp(p:Dot(right), -roomX, roomX) else 0
	local y = if roomY > 0 then math.clamp(p:Dot(face.up), -roomY, roomY) else 0
	local depth = math.abs(face.normal:Dot(half))
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

local function placeOnHead(_part: BasePart, data: Gash.Data, found: Kit): Placed?
	local name, shape = shapeFor(data, true, found)
	if shape == nil then
		return nil
	end
	-- (The R6 head has one size: its round shape is ~1.2 studs.)
	local p = data.point
	local angle = math.atan2(p.X, -p.Z) -- 0 = the face, + = toward its right (+X)
	-- Head cuts lie almost level (the insert is bent around the head).
	local turn = math.clamp(data.angle, -HEAD_MAX_TURN, HEAD_MAX_TURN)
	-- The whole cut (its blood drips too) stays on the straight part.
	local low, high = -HEAD_BAND + shape.low, HEAD_BAND - shape.high
	local y = if low <= high then math.clamp(p.Y, low, high) else (low + high) / 2
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
			-- The template's region covers the face up to the middle of its
			-- bevelled edges (WoundShapes.inset in from each side).
			local inset = WoundShapes.inset
			imageW = (faceW - 2 * inset) * TEMPLATE_W / region[3]
			imageH = (faceH - 2 * inset) * TEMPLATE_H / region[4]
			left = region[1] / TEMPLATE_W * imageW - inset
			top = region[2] / TEMPLATE_H * imageH - inset
		else
			-- a T-shirt picture covers the front like a template region does
			local inset = WoundShapes.inset
			imageW, imageH, left, top = faceW - 2 * inset, faceH - 2 * inset, -inset, -inset
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
-- (a Weld with its offset written in, not a WeldConstraint: that one takes
-- the offset the parts have when it comes on, and on a body posed by its
-- clips (Motor6D.Transform) that can be another pose than the one the piece
-- was placed for: the skin then sat beside the body, or far from it)
local function setUp(piece: BasePart, part: BasePart, parent: Instance)
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Massless = true
	local weld = Instance.new("Weld")
	weld.Part0 = part
	weld.Part1 = piece
	weld.C0 = part.CFrame:ToObjectSpace(piece.CFrame)
	weld.Parent = piece
	piece.Parent = parent
end

-- Roblox draws a character's body with the clothes painted on it, without
-- the grain of the "Plastic" material: its copy uses SmoothPlastic then.
local function skinMaterial(part: BasePart): Enum.Material
	return if part.Material == Enum.Material.Plastic
		then Enum.Material.SmoothPlastic
		else part.Material
end

local function newTile(part: BasePart, size: Vector3, offset: CFrame, parent: Instance): BasePart
	local tile = Instance.new("Part")
	tile.Name = "Skin"
	tile.Size = size
	tile.Color = part.Color
	tile.Material = skinMaterial(part) -- looks exactly like the real part
	tile.Reflectance = part.Reflectance
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

-- One piece of the head shell from the kit, put on the head: turned to
-- `angle` around it (0 = the face), its middle at height `y`, `height` tall
-- (band pieces are 1 stud high in the kit), `widthScale` times as wide
-- (thinner columns next to a cut), turned over for the bottom.
local function shellPiece(
	part: BasePart,
	found: Kit,
	name: string,
	home: Vector3, -- where the piece sits in the kit (WoundShapes.headOrigin...)
	angle: number,
	y: number,
	height: number,
	widthScale: number,
	bottom: boolean,
	parent: Instance,
	grow: number? -- a hair bigger, all round (layers over the skin)
): BasePart
	local item = found.shell[name]
	local relative = found.frame:ToObjectSpace(item.CFrame)
	local origin = home + Vector3.new(0, WoundShapes.markerDrop, 0)
	local position = relative.Position / found.unit - origin
	local rotation = relative.Rotation
	-- Stretch the piece's own axes: the one running up the head (kit Y) to
	-- `height`, the one running around it (kit X) by `widthScale`.
	local function stretch(axis: Vector3): number
		local upness, around = math.abs(axis.Y), math.abs(axis.X)
		return upness * height + around * widthScale + (1 - upness - around)
	end
	local piece = item:Clone()
	piece:ClearAllChildren()
	local scale = grow or 1
	piece.Size = item.Size
		/ found.unit
		* Vector3.new(
			stretch(rotation.XVector),
			stretch(rotation.YVector),
			stretch(rotation.ZVector)
		)
		* scale
	local out = Vector3.new(math.sin(angle), 0, -math.cos(angle))
	local up = Vector3.new(0, 1, 0)
	local around = CFrame.fromMatrix(Vector3.zero, up:Cross(out), up, out)
	local flip = if bottom then CFrame.Angles(0, 0, math.pi) else CFrame.identity
	local placed = around
		* flip
		* CFrame.new(position.X * widthScale, position.Y * height + y, position.Z)
		* rotation
	piece.CFrame = part.CFrame * CFrame.new(placed.Position * scale) * placed.Rotation
	piece.Color = part.Color
	piece.Material = skinMaterial(part) -- looks exactly like the real head
	piece.Reflectance = part.Reflectance
	piece.Name = "Skin"
	setUp(piece, part, parent)
	piece.CastShadow = true
	return piece
end

-- The face picture on a thin column of the straight part next to a cut (the
-- face pieces of the kit can't have a hole): an invisible card just over
-- the skin carries it. The picture covers the front of the head (1.2 x 1.2,
-- its top at the top of the head) as seen from the front; the card shows the
-- bit in front of it. A thin column is almost flat, so it fits well.
local function faceCard(
	part: BasePart,
	image: string,
	angle: number,
	width: number, -- radians
	top: number,
	height: number,
	parent: Instance
)
	local out = Vector3.new(math.sin(angle), 0, -math.cos(angle))
	local up = Vector3.new(0, 1, 0)
	local chord = 2 * HEAD_RADIUS * math.sin(width / 2)
	local card = Instance.new("Part")
	card.Name = "FaceCard"
	card.Transparency = 1
	card.Size = Vector3.new(chord, height, 0.01)
	card.CFrame = part.CFrame
		* CFrame.fromMatrix(
			out * (HEAD_RADIUS + 0.0015) + Vector3.new(0, top - height / 2, 0),
			up:Cross(-out),
			up,
			-out
		)
	setUp(card, part, parent)
	local projected = chord * math.cos(angle) -- its width seen from the front
	local leftEdge = HEAD_RADIUS * math.sin(angle) + projected / 2 -- your left = the head's +X
	local span = 2 * HEAD_RADIUS
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 400 -- as sharp as the real face
	gui.ClipsDescendants = true
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = image
	label.Size = UDim2.fromScale(span / projected, span / height)
	label.Position =
		UDim2.fromScale(-(HEAD_RADIUS - leftEdge) / projected, -(HEAD_RADIUS - top) / height)
	label.Parent = gui
	gui.Parent = card
end

-- The round head rebuilt from the kit's smooth pieces: the straight part in
-- 24 columns (8 thin ones where a cut is, with the hole left out), the
-- rounded edges and the caps. Same shape as the real head, no seams.
local function buildHeadSkin(part: BasePart, cuts: { Placed }, found: Kit, parent: Instance)
	local face = part:FindFirstChildOfClass("Decal")
	local faceImage = if face then face.Texture else ""
	local sector = 2 * math.pi / HEAD_SECTORS

	-- Which cells of a column are cut (true = keep the skin), from the top.
	local function cells(angle: number, rows: number): ({ { boolean } }, boolean)
		local out = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local rowH = 2 * HEAD_BAND / rows
		local keep: { { boolean } } = { {} }
		local hasCut = false
		for j = 1, rows do
			local y = HEAD_BAND - (j - 0.5) * rowH
			local cut = #cuts > 0 and cutAt(cuts, out * HEAD_RADIUS + Vector3.new(0, y, 0), true)
			keep[1][j] = not cut
			hasCut = hasCut or cut
		end
		return keep, hasCut
	end

	local function column(
		angle: number,
		name: string,
		widthScale: number,
		keep: { { boolean } }?,
		rows: number,
		withFace: boolean -- draw the face on it (a thin column next to a cut)
	)
		local rowH = 2 * HEAD_BAND / rows
		local runs: { Rect } = if keep
			then rectangles(keep, 1, rows)
			else { { i = 1, j = 1, w = 1, h = rows } }
		for _, run in runs do
			local top = HEAD_BAND - (run.j - 1) * rowH
			local height = run.h * rowH
			if withFace then
				faceCard(
					part,
					faceImage,
					angle,
					2 * math.pi / HEAD_SECTORS / HEAD_FINE,
					top,
					height,
					parent
				)
			end
			shellPiece(
				part,
				found,
				name,
				WoundShapes.headOrigin,
				angle,
				top - height / 2,
				height,
				widthScale,
				false,
				parent
			)
		end
	end

	local rows = math.max(1, math.round(2 * HEAD_BAND / CELL))
	for index = 0, HEAD_SECTORS - 1 do
		local mid = (index + 0.5) * sector
		-- Is a cut near this sector? Then thin columns and rows, to cut finely
		-- (only if a cell really is cut: otherwise one whole column).
		local near = false
		for _, cut in cuts do
			local reach = (cut.shape.extent.X + 0.06) / HEAD_RADIUS
			local delta = math.abs((mid - cut.center.X + math.pi) % (2 * math.pi) - math.pi)
			if delta < reach + sector / 2 then
				near = true
			end
		end
		local fine = {}
		local anyCut = false
		if near then
			for k = 0, HEAD_FINE - 1 do
				local angle = index * sector + (k + 0.5) * sector / HEAD_FINE
				local keep, hasCut = cells(angle, rows * 2)
				table.insert(fine, { angle = angle, keep = keep, hasCut = hasCut })
				anyCut = anyCut or hasCut
			end
		end
		if anyCut then
			for _, column_ in fine do
				-- Shell_Band192 (1.875 deg), a hair wider: the columns overlap
				-- (identical skin), no crack between them
				column(
					column_.angle,
					"Shell_Band192",
					1.03,
					if column_.hasCut then column_.keep else nil,
					rows * 2,
					faceImage ~= "" and isFrontSector(index)
				)
			end
		else
			column(mid, "Shell_Band24", 1, nil, rows, false)
		end
		-- the rounded edges above and below
		shellPiece(
			part,
			found,
			"Shell_Bevel24",
			WoundShapes.headOrigin,
			mid,
			0,
			1,
			1,
			false,
			parent
		)
		shellPiece(part, found, "Shell_Bevel24", WoundShapes.headOrigin, mid, 0, 1, 1, true, parent)
		-- The face, from the kit's pieces (built at their place: angle 0),
		-- a hair outside the skin; next to a cut, cards on the columns instead
		-- of the straight piece (the hole stays free of the picture).
		if faceImage ~= "" and isFrontSector(index) then
			local pieces = { "Top", "Bottom" }
			if not anyCut then
				table.insert(pieces, "Band")
			end
			for _, piece in pieces do
				local layer = shellPiece(
					part,
					found,
					`Shell_Face{piece}_{index}`,
					WoundShapes.headOrigin,
					0,
					0,
					1,
					1,
					false,
					parent,
					1.0025
				)
				layer.Name = "Face"
				layer.Color = Color3.new(1, 1, 1) -- (never tint the picture)
				layer.CastShadow = false
				if layer:IsA("MeshPart") then
					layer.TextureID = faceImage
				end
				-- A mesh shows its picture's transparent pixels only when the
				-- part itself is a little transparent (the skin shows there).
				layer.Transparency = SEE_THROUGH
			end
		end
	end
	shellPiece(part, found, "Shell_Cap", WoundShapes.headOrigin, 0, 0, 1, 1, false, parent)
	shellPiece(part, found, "Shell_Cap", WoundShapes.headOrigin, 0, 0, 1, 1, true, parent)
end

-- The bevelled frame of a block part (see the kit), or nil.
local FRAME_OF: { [string]: string } = {
	Torso = "Shell_FrameTorso",
	RightArm = "Shell_FrameRight",
	RightLeg = "Shell_FrameRight",
	LeftArm = "Shell_FrameLeft",
	LeftLeg = "Shell_FrameLeft",
}

-- One coordinate of a vector (1 = X, 2 = Y, 3 = Z).
local function axisOf(v: Vector3, axis: number): number
	return if axis == 1 then v.X elseif axis == 2 then v.Y else v.Z
end

-- The two axes across `axis`, in order (X: Y Z, Y: X Z, Z: X Y).
local function across(axis: number): (number, number)
	if axis == 1 then
		return 2, 3
	elseif axis == 2 then
		return 1, 3
	end
	return 1, 2
end

-- A vector from its coordinate along `axis` and along the two across it.
local function fromAxes(axis: number, along: number, u: number, v: number): Vector3
	if axis == 1 then
		return Vector3.new(along, u, v)
	elseif axis == 2 then
		return Vector3.new(u, along, v)
	end
	return Vector3.new(u, v, along)
end

-- How far under the skin the core starts (see buildBoxSkin): a cut deeper
-- than this needs a hole in the core.
local CORE_INSET = 0.16
local CORE_MARGIN = 0.03 -- room left around a deep cut

-- The core of a box part (size `core`, centred), with a tunnel through it
-- where each deep cut is (the bore: on the torso's front). Several boxes
-- then, merged into few.
local function buildCore(part: BasePart, core: Vector3, cuts: { Placed }, parent: Instance)
	local axis: number? = nil
	local holes: { { number } } = {} -- {u0, u1, v0, v1} across `axis`
	for _, cut in cuts do
		local depth = cut.shape.depth
		if depth == nil or depth <= CORE_INSET then
			continue
		end
		local normal = cut.frame.ZVector
		local cutAxis = if math.abs(normal.X) > 0.9
			then 1
			elseif math.abs(normal.Y) > 0.9 then 2
			else 3
		if axis ~= nil and axis ~= cutAxis then
			continue -- (deep cuts on crossing faces: only the first one's axis)
		end
		axis = cutAxis
		-- the face's width runs along X (front / back) or Z (sides), its
		-- height along Y (cuts are never on the top / bottom)
		local ext = turnedExtent(cut.shape.extent, cut.data.angle)
		local a, b = across(cutAxis)
		local halfA = if a == 2 then ext.Y else ext.X
		local halfB = if b == 2 then ext.Y else ext.X
		local center = cut.frame.Position
		local ca, cb = axisOf(center, a), axisOf(center, b)
		table.insert(holes, {
			ca - halfA - CORE_MARGIN,
			ca + halfA + CORE_MARGIN,
			cb - halfB - CORE_MARGIN,
			cb + halfB + CORE_MARGIN,
		})
	end
	if axis == nil then
		newTile(part, core, CFrame.identity, parent).Name = "Core"
		return
	end
	local a, b = across(axis)
	local halfU, halfV = axisOf(core, a) / 2, axisOf(core, b) / 2
	local length = axisOf(core, axis)
	-- The grid: the core's edges and the holes' edges inside it.
	local function edges(half: number, first: number): { number }
		local list = { -half, half }
		for _, hole in holes do
			for k = first, first + 1 do
				if hole[k] > -half and hole[k] < half then
					table.insert(list, hole[k])
				end
			end
		end
		table.sort(list)
		return list
	end
	local us, vs = edges(halfU, 1), edges(halfV, 3)
	local columns, rows = #us - 1, #vs - 1
	local keep: { { boolean } } = {}
	for i = 1, columns do
		keep[i] = {}
		local u = (us[i] + us[i + 1]) / 2
		for j = 1, rows do
			local v = (vs[j] + vs[j + 1]) / 2
			-- (a cell of no width: two edges at the same place)
			local cut = us[i + 1] - us[i] < 1e-3 or vs[j + 1] - vs[j] < 1e-3
			for _, hole in holes do
				if u > hole[1] and u < hole[2] and v > hole[3] and v < hole[4] then
					cut = true
				end
			end
			keep[i][j] = not cut
		end
	end
	for _, rect in rectangles(keep, columns, rows) do
		local u0, u1 = us[rect.i], us[rect.i + rect.w]
		local v0, v1 = vs[rect.j], vs[rect.j + rect.h]
		local size = fromAxes(axis, length, u1 - u0, v1 - v0)
		local center = fromAxes(axis, 0, (u0 + u1) / 2, (v0 + v1) / 2)
		newTile(part, size, CFrame.new(center), parent).Name = "Core"
	end
end

-- A torso (or a limb) rebuilt like Roblox draws it: a box with bevelled
-- edges. The bevelled frame comes from the kit, with the shirt / pants
-- painted on it; the inside of each face is flat tiles (with the hole of a
-- cut, the clothes drawn on them).
local function buildBoxSkin(
	model: Model,
	part: BasePart,
	key: string,
	cuts: { Placed },
	found: Kit,
	parent: Instance
)
	local half = part.Size / 2
	local frameName = FRAME_OF[key]
	local frameHome = if frameName then WoundShapes.frames[frameName] else nil
	local framePiece: BasePart? = if frameName then found.shell[frameName] else nil
	local hasFrame = frameHome ~= nil and framePiece ~= nil
	local bevel = if hasFrame then WoundShapes.chamfer else 0
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
		-- the flat inside of the face: from `bevel` to faceW - bevel
		local innerW, innerH = faceW - 2 * bevel, faceH - 2 * bevel
		local columns = if #mine > 0 then math.max(1, math.round(innerW / CELL)) else 1
		local rows = if #mine > 0 then math.max(1, math.round(innerH / CELL)) else 1
		local cw, ch = innerW / columns, innerH / rows
		local keep: { { boolean } } = {}
		for i = 1, columns do
			keep[i] = {}
			for j = 1, rows do
				local a, b = bevel + (i - 0.5) * cw, bevel + (j - 0.5) * ch -- from the top-left
				local at = normal * depth + right * (a - faceW / 2) + up * (faceH / 2 - b)
				keep[i][j] = #mine == 0 or not cutAt(mine, at, false)
			end
		end
		for _, rect in rectangles(keep, columns, rows) do
			local a0, b0 = bevel + (rect.i - 1) * cw, bevel + (rect.j - 1) * ch
			local w, h = rect.w * cw, rect.h * ch
			local center = normal * (depth - THICKNESS / 2)
				+ right * (a0 + w / 2 - faceW / 2)
				+ up * (faceH / 2 - b0 - h / 2)
			-- The tile's front (-Z) faces out; its Y is the picture's up.
			local offset = CFrame.fromMatrix(center, up:Cross(-normal), up, -normal)
			local tile = newTile(part, Vector3.new(w + PAD, h + PAD, THICKNESS), offset, parent)
			paint(tile, pictures, faceW, faceH, a0, b0, w, h)
		end
	end
	if hasFrame and frameName and frameHome then
		-- The bevels: skin, and over it a hair bigger the clothes (their
		-- transparent pixels show the skin). One layer only: two see-through
		-- layers at the same place are drawn in no sure order. The shirt if
		-- there is one (torso, arms), else the pants.
		shellPiece(part, found, frameName, frameHome, 0, 0, 1, 1, false, parent)
		local shirt = model:FindFirstChildOfClass("Shirt")
		local pants = model:FindFirstChildOfClass("Pants")
		local isLeg = string.find(key, "Leg") ~= nil
		local isArm = string.find(key, "Arm") ~= nil
		local layers: { string } = {}
		if (isArm or key == "Torso") and shirt and shirt.ShirtTemplate ~= "" then
			table.insert(layers, shirt.ShirtTemplate)
		elseif (isLeg or key == "Torso") and pants and pants.PantsTemplate ~= "" then
			table.insert(layers, pants.PantsTemplate)
		end
		for index, image in layers do
			local layer = shellPiece(
				part,
				found,
				frameName,
				frameHome,
				0,
				0,
				1,
				1,
				false,
				parent,
				1 + 0.0015 * index
			)
			layer.Name = "Clothes"
			layer.Color = Color3.new(1, 1, 1)
			if layer:IsA("MeshPart") then
				layer.TextureID = image
			end
			layer.Transparency = SEE_THROUGH
		end
	end
	-- A skin-coloured core deep inside: a hairline gap between two tiles
	-- shows skin, never the sky through the body. A deep cut (the bore)
	-- would end inside it: the core is left out around it (a tunnel through
	-- it, in boxes; the cut's own insert is a closed cup).
	local core = part.Size - Vector3.new(2 * CORE_INSET, 2 * CORE_INSET, 2 * CORE_INSET)
	if core.X > 0.05 and core.Y > 0.05 and core.Z > 0.05 then
		buildCore(part, core, cuts, parent)
	end
end

-- The 3D wound model of one cut, from the kit, fitted on the part.
local function buildInsert(part: BasePart, cut: Placed, found: Kit, parent: Instance)
	local pieces = found.pieces[cut.shapeName]
	if pieces == nil then
		return
	end
	local origin = Vector3.new(cut.shape.index * WoundShapes.spacing, WoundShapes.markerDrop, 0)
	-- (a bore drawn with a burn's insert, in an older kit: burnt too)
	local bored = cut.shape.kind == "Bore"
	local burnt = cut.data.kind == "Burn" or cut.data.kind == "Bore"
	local onHead = cut.face == nil
	for _, item in pieces do
		local layer = string.match(item.Name, "_(%a+)$") or ""
		local look = if bored
			then BORE_LOOKS[layer]
			elseif burnt then BURN_LOOKS[layer]
			else LOOKS[layer]
		if look == nil then
			continue -- (a burn: no blood in it)
		end
		if burnt and onHead and layer == "Flesh" then
			-- (on the head the skin is thin: under it, the skull)
			look = { color = SKULL, reflectance = 0.04, material = Enum.Material.SmoothPlastic }
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
	if bored then
		-- (the bore's cup is closed and goes far deeper than the usual
		-- plate, which would cut through it: the plate goes behind its
		-- bottom, in case a crack shows past its rim)
		local depth = (cut.shape.depth or BACKING_DEPTH) + 0.04
		local thickness = math.abs(cut.frame.ZVector:Dot(part.Size))
		local backing = Instance.new("Part")
		backing.Name = "Backing"
		backing.Size = Vector3.new(width, 2 * reachY + 0.06, 0.02)
		backing.Color = BORE_BACKING
		backing.Material = Enum.Material.SmoothPlastic
		backing.CFrame = part.CFrame
			* cut.frame
			* CFrame.new(0, 0, -math.min(depth, thickness - 0.12))
		setUp(backing, part, parent)
		return
	end
	-- On a block: one flat plate. On the head: a few plates following its
	-- curve (a flat one would cross the ends of a long cut).
	local plates = if cut.face == nil then 5 else 1
	for k = 1, plates do
		local backing = Instance.new("Part")
		backing.Name = "Backing"
		backing.Size = Vector3.new(width / plates + 0.01, 2 * reachY + 0.06, 0.02)
		backing.Color = if burnt
			then (if onHead then SKULL:Lerp(RAW_WALL, 0.15) else BURN_BACKING)
			else BACKING_COLOR
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
	cuts: { Placed },
	partTransparency: number,
	face: Decal?, -- the face picture we hid, and its own transparency
	faceTransparency: number,
	connection: RBXScriptConnection?,
	tint: { RBXScriptConnection }, -- the skin follows the part's colour
}
local opened: { [BasePart]: Opened } = {}

-- The bruise / cut marks of Wounds (discs on the skin) hide where they
-- would cover a cut.
local function hideMarks(part: BasePart)
	local marks = part:FindFirstChild("Wounds")
	if marks == nil then
		return
	end
	local state = opened[part]
	for _, mark in marks:GetChildren() do
		if mark:IsA("BasePart") then
			local covered = false
			if state then
				local at = part.CFrame:PointToObjectSpace(mark.Position)
				local radius = math.max(mark.Size.Y, mark.Size.Z) / 2
				for _, cut in state.cuts do
					if
						(at - cut.frame.Position).Magnitude
						< cut.shape.extent.Magnitude + radius
					then
						covered = true
					end
				end
			end
			mark.LocalTransparencyModifier = if covered then 1 else 0
		end
	end
end

local function close(part: BasePart)
	local state = opened[part]
	if state == nil then
		return
	end
	opened[part] = nil
	for _, link in state.tint do
		link:Disconnect()
	end
	if state.connection then
		state.connection:Disconnect()
	end
	state.folder:Destroy()
	part.Transparency = state.partTransparency
	if state.face then
		state.face.Transparency = state.faceTransparency
	end
	hideMarks(part) -- (shows them all again)
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
				local placed = if isHead
					then placeOnHead(part, data, found)
					else placeOnBox(part, data, found)
				-- (no insert for it in this kit, or an old kit without the head
				-- pieces: no hole either)
				if
					placed
					and found.pieces[placed.shapeName]
					and (if isHead then found.shellComplete else found.framesComplete)
				then
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
	if isHead and HeadBlast.isBlown(model) then
		-- Burst by the bat (HeadBlast): no head left, nor its cuts.
		part.Transparency = 1
		if face then
			face.Transparency = 1
		end
		return
	end
	if #cuts == 0 or found == nil then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Gashes"
	-- (built out of the game, then the part hidden: if anything goes wrong
	-- on the way, the part stays as it is, whole, never invisible)
	local ok, problem = pcall(function()
		if isHead then
			buildHeadSkin(part, cuts, found, folder)
		else
			buildBoxSkin(model, part, key, cuts, found, folder)
		end
		for _, cut in cuts do
			buildInsert(part, cut, found, folder)
		end
	end)
	if not ok then
		folder:Destroy()
		warn(`[Gashes] could not draw the cuts of {part:GetFullName()}: {problem}`)
		return
	end
	local state: Opened = {
		folder = folder,
		cuts = cuts,
		partTransparency = partTransparency,
		face = face,
		faceTransparency = faceTransparency,
		connection = nil,
		tint = {},
	}
	-- The skin repainted with the part (if something recolours the real part)
	local function retint()
		for _, item in folder:GetDescendants() do
			if item:IsA("BasePart") and item.Name == "Skin" then
				item.Color = part.Color
				item.Material = skinMaterial(part)
				item.Reflectance = part.Reflectance
			end
		end
	end
	for _, property in { "Color", "Material", "Reflectance" } do
		table.insert(state.tint, part:GetPropertyChangedSignal(property):Connect(retint))
	end
	-- (known first: close() always gives the part back its own looks)
	folder.Parent = part
	opened[part] = state
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
	hideMarks(part)
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

-- The kit changed after it was found incomplete: everyone drawn again a
-- moment later (once, however many pieces arrive meanwhile).
local redrawing = false
onKitChanged = function()
	if redrawing then
		return
	end
	redrawing = true
	task.delay(0.5, function()
		redrawing = false
		for model in watched do
			if model.Parent then
				refreshAll(model)
			end
		end
	end)
end

-- Does the wound kit (once found) have the bore inserts (BoreS / M / L)?
-- An older kit has not: nothing is drawn for a bore then.
function Gashes.hasBore(): boolean
	return findKit() ~= nil and boreInKit
end

function Gashes.watch(model: Model)
	watched[model] = true
	waitForKit()
	model.AttributeChanged:Connect(function(name: string)
		local key = string.match(name, "^" .. Gash.PREFIX .. "(%a+)_%d+$")
		local partName = if key then Gash.PART_OF[key] else nil
		if partName then
			refresh(model, partName)
		elseif name == HeadBlast.ATTRIBUTE then
			refresh(model, "Head")
			local fresh = not HeadBlast.isApplied(model)
			HeadBlast.apply(model, true)
			local seed = model:GetAttribute(HeadBlast.ATTRIBUTE)
			if fresh and HeadBlast.isApplied(model) and typeof(seed) == "number" then
				BloodGush.neck(model, seed)
			end
		elseif name == ArmRip.ATTRIBUTE then
			ArmRip.apply(model, true)
		elseif name == "BoneTaken" then
			ArmRip.boneTaken(model)
		elseif name == Bisect.ATTRIBUTE then
			Bisect.apply(model, true)
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
			Bisect.apply(model, false)
		end
	end)
	-- A new bruise mark (Wounds) over a cut: hidden.
	model.DescendantAdded:Connect(function(item: Instance)
		local folder = item.Parent
		local part = if folder and folder.Name == "Wounds" then folder.Parent else nil
		if item:IsA("BasePart") and part and part:IsA("BasePart") then
			hideMarks(part)
		end
	end)
	-- The clothes may load a moment after the character: draw again then.
	model.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Clothing") or child:IsA("ShirtGraphic") then
			refreshAll(model)
		end
	end)
	refreshAll(model)
	HeadBlast.apply(model, false) -- (a body whose head burst before we saw it)
	ArmRip.apply(model, false) -- (or whose arm was torn off)
	Bisect.apply(model, false) -- (or that was torn in two)
end

return table.freeze(Gashes)
