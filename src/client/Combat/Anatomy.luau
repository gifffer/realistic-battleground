--!strict
-- Anatomy: what is INSIDE a fighter's body, shown where glass tore the skin.
--
-- Each R6 body part can be "opened": the real block is hidden and replaced by
--   • a SKIN shell (small tiles made here, with the fighter's skin colour and
--     their shirt / pants / face drawn on them, so nothing changes from far),
--   • under it, the anatomy models imported from Z-Anatomy (muscles, then
--     skull / ribs / leg and arm bones, brain, teeth, eyes, organs...).
-- A wound removes the skin tiles around the hit point; a deeper wound also
-- removes the muscle pieces there, then the piece of skull (the brain shows).
--
-- The server says how deep each wound is with the attributes
-- "Torn_<Part>_<Side>" = 1..Config.Injuries.SKIN_TEAR_MAX
-- (e.g. "Torn_Head_Front", "Torn_Torso_Left", "Torn_RightLeg_Back").
-- Everything here is visual and local: every client builds the same thing.
--
-- The models are imported in Studio (docs/ANATOMY_FR.md) into
-- ReplicatedStorage > Assets > Anatomy > Anatomy_Head, Anatomy_Torso...
-- Without them, nothing happens here (Wounds draws its simple version).
--
--   Anatomy.available(partName)   are the models of this part imported?
--   Anatomy.watch(model)          follow the "Torn_" attributes of a fighter

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Anatomy = {}

-- R6 part name -> name used in the models and the attributes.
local KEYS: { [string]: string } = {
	Head = "Head",
	Torso = "Torso",
	["Right Arm"] = "RightArm",
	["Left Arm"] = "LeftArm",
	["Right Leg"] = "RightLeg",
	["Left Leg"] = "LeftLeg",
}
local PART_OF: { [string]: string } = {}
for partName, key in KEYS do
	PART_OF[key] = partName
end

-- Size (studs) of the block each model was built for (tools/anatomy).
local HEAD_SIZE = 1.2 -- the round head you see, not the 2x1x1 head box
local MODEL_SIZE: { [string]: Vector3 } = {
	Head = Vector3.new(HEAD_SIZE, HEAD_SIZE, HEAD_SIZE),
	Torso = Vector3.new(2, 2, 1),
	RightArm = Vector3.new(1, 2, 1),
	LeftArm = Vector3.new(1, 2, 1),
	RightLeg = Vector3.new(1, 2, 1),
	LeftLeg = Vector3.new(1, 2, 1),
}

-- Look of each layer (the first word of a piece's name: "Muscle_FrontLeft").
type Look = { color: Color3, reflectance: number }
local LOOKS: { [string]: Look } = {
	Skull = { color = Color3.fromRGB(222, 210, 184), reflectance = 0.02 },
	Bone = { color = Color3.fromRGB(222, 210, 184), reflectance = 0.02 },
	Teeth = { color = Color3.fromRGB(236, 230, 214), reflectance = 0.05 },
	Brain = { color = Color3.fromRGB(205, 140, 140), reflectance = 0.1 },
	Eyes = { color = Color3.fromRGB(238, 236, 228), reflectance = 0.2 },
	Muscle = { color = Color3.fromRGB(128, 22, 22), reflectance = 0.12 }, -- wet
	Lungs = { color = Color3.fromRGB(196, 108, 108), reflectance = 0.08 },
	Heart = { color = Color3.fromRGB(110, 14, 16), reflectance = 0.1 },
	Liver = { color = Color3.fromRGB(88, 20, 16), reflectance = 0.1 },
	Guts = { color = Color3.fromRGB(202, 138, 112), reflectance = 0.1 },
	Cavity = { color = Color3.fromRGB(40, 6, 6), reflectance = 0 },
}

-- Wound sizes per level (studs, for a 1-stud wide part; bigger parts get
-- bigger wounds): skin gone, then muscle gone, then bone gone.
local SKIN_RADIUS = { 0.3, 0.5, 0.72 }
local MUSCLE_RADIUS = { 0, 0.45, 0.7 }
local BONE_RADIUS = { 0, 0, 0.35 }
local SIZE_FACTOR: { [string]: number } = {
	Head = 1,
	Torso = 1.4,
	RightArm = 1,
	LeftArm = 1,
	RightLeg = 1,
	LeftLeg = 1,
}

local SIDES: { [string]: Vector3 } = {
	Front = Vector3.new(0, 0, -1),
	Back = Vector3.new(0, 0, 1),
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
}
-- Height of the wound on the part (fraction of the half height): the face /
-- the chest / the thigh rather than the very middle.
local WOUND_HEIGHT: { [string]: number } = {
	Head = 0.1,
	Torso = 0.25,
	RightArm = 0.3,
	LeftArm = 0.3,
	RightLeg = 0.35,
	LeftLeg = 0.35,
}

local SKIN_THICKNESS = 0.05
local TILE = 0.5 -- skin tile size on the blocks (studs)

-- Clothing templates (585 x 559 pixels): where each face of each part is,
-- {x, y, width, height} in pixels. Same layout for shirts and pants.
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
local FACES: { { name: string, normal: Vector3, up: Vector3 } } = {
	{ name = "Front", normal = Vector3.new(0, 0, -1), up = Vector3.yAxis },
	{ name = "Back", normal = Vector3.new(0, 0, 1), up = Vector3.yAxis },
	{ name = "Left", normal = Vector3.new(-1, 0, 0), up = Vector3.yAxis },
	{ name = "Right", normal = Vector3.new(1, 0, 0), up = Vector3.yAxis },
	{ name = "Top", normal = Vector3.yAxis, up = Vector3.new(0, 0, 1) },
	{ name = "Bottom", normal = -Vector3.yAxis, up = Vector3.new(0, 0, -1) },
}

------------------------------------------------------------------------------
local function templateOf(key: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("Anatomy") else nil
	local model = if folder then folder:FindFirstChild("Anatomy_" .. key) else nil
	return if model and model:IsA("Model") then model else nil
end

function Anatomy.available(partName: string): boolean
	local key = KEYS[partName]
	return key ~= nil and templateOf(key) ~= nil
end

local function findPart(model: Instance, name: string): BasePart?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- Where the model's block is, turned and scaled like the importer left it:
-- found with the markers (top center, front center). Returns the block's
-- frame (Y up, looking toward -Z) and how many studs one model stud is.
local function modelFrame(template: Model, key: string): (CFrame?, number)
	local bounds = findPart(template, "Bounds")
	local up = findPart(template, "MarkUp")
	local front = findPart(template, "MarkFront")
	if bounds == nil or up == nil or front == nil then
		warn(
			`[Anatomy] Anatomy_{key}: Bounds / MarkUp / MarkFront missing (see docs/ANATOMY_FR.md)`
		)
		return nil, 1
	end
	local center = bounds.Position
	local toUp = up.Position - center
	local toFront = front.Position - center
	local y = toUp.Unit
	local z = -toFront.Unit
	return CFrame.fromMatrix(center, y:Cross(z), y, z), toUp.Magnitude / (MODEL_SIZE[key].Y / 2)
end

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

-- The size of the part as you see it (the head: its round mesh).
local function visibleSize(part: BasePart, key: string): Vector3
	if key == "Head" then
		return Vector3.one * HEAD_SIZE * part.Size.Y
	end
	return part.Size
end

------------------------------------------------------------------------------
-- Inside: clones of the imported pieces, fitted to this fighter's part.
type Piece = { part: BasePart, layer: string, center: Vector3 }

local function buildInside(
	part: BasePart,
	key: string,
	parent: Instance,
	pieces: { Piece }
): boolean
	local template = templateOf(key)
	if template == nil then
		return false
	end
	local frame, unit = modelFrame(template, key)
	if frame == nil then
		return false
	end
	local factor = visibleSize(part, key) / MODEL_SIZE[key] -- per axis, ~1
	for _, item in template:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local layer = string.match(item.Name, "^(%a+)") or ""
		local look = LOOKS[layer]
		if look == nil then
			continue -- Bounds, MarkUp, MarkFront
		end
		local relative = frame:ToObjectSpace(item.CFrame)
		local position = relative.Position / unit * factor
		local piece = item:Clone()
		piece:ClearAllChildren()
		-- The piece's own axes in the part: scale each by the part's factor.
		local rotation = relative.Rotation
		local function along(axis: Vector3): number
			local a = Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z))
			return a:Dot(factor)
		end
		piece.Size = item.Size
			/ unit
			* Vector3.new(along(rotation.XVector), along(rotation.YVector), along(rotation.ZVector))
		piece.CFrame = part.CFrame * CFrame.new(position) * rotation
		piece.Color = look.color
		piece.Reflectance = look.reflectance
		piece.Material = Enum.Material.SmoothPlastic
		piece.Name = item.Name
		setUp(piece, part, parent)
		table.insert(pieces, { part = piece, layer = layer, center = position })
	end
	return true
end

------------------------------------------------------------------------------
-- Skin: tiles over the part, with its colour and the clothes / face on them.
type Tile = { part: BasePart, center: Vector3 }

-- Picture `image` (a clothing template region, or a whole picture when
-- `region` is nil) on the outer face of a tile. The tile shows the piece of
-- the face from `a0` (studs from the left as you look at the face) and `b0`
-- (studs from the top). A Texture's pattern starts at its offset: a negative
-- offset slides the wanted spot of the picture onto the tile.
local function dress(
	tile: BasePart,
	image: string,
	region: { number }?,
	faceW: number,
	faceH: number,
	a0: number,
	b0: number,
	zIndex: number
)
	local texture = Instance.new("Texture")
	texture.Texture = image
	texture.Face = Enum.NormalId.Front
	texture.ZIndex = zIndex
	if region then
		local studsU = faceW * TEMPLATE_W / region[3]
		local studsV = faceH * TEMPLATE_H / region[4]
		texture.StudsPerTileU = studsU
		texture.StudsPerTileV = studsV
		texture.OffsetStudsU = -(region[1] / TEMPLATE_W * studsU + a0)
		texture.OffsetStudsV = -(region[2] / TEMPLATE_H * studsV + b0)
	else
		texture.StudsPerTileU = faceW
		texture.StudsPerTileV = faceH
		texture.OffsetStudsU = -a0
		texture.OffsetStudsV = -b0
	end
	texture.Parent = tile
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
	return tile
end

-- The clothes images that cover this part: { image, template region set }.
local function clothesOf(model: Model, key: string): { { image: string, regions: string } }
	local list = {}
	local pants = model:FindFirstChildOfClass("Pants")
	local shirt = model:FindFirstChildOfClass("Shirt")
	local isLeg = string.find(key, "Leg") ~= nil
	local isArm = string.find(key, "Arm") ~= nil
	local side = if string.sub(key, 1, 4) == "Left" then "Left" else "Right"
	if pants and pants.PantsTemplate ~= "" and (isLeg or key == "Torso") then
		table.insert(
			list,
			{ image = pants.PantsTemplate, regions = if isLeg then side else "Torso" }
		)
	end
	if shirt and shirt.ShirtTemplate ~= "" and (isArm or key == "Torso") then
		table.insert(
			list,
			{ image = shirt.ShirtTemplate, regions = if isArm then side else "Torso" }
		)
	end
	return list
end

local function buildBoxSkin(
	model: Model,
	part: BasePart,
	key: string,
	parent: Instance,
	tiles: { Tile }
)
	local half = part.Size / 2
	local clothes = clothesOf(model, key)
	local graphic = model:FindFirstChildOfClass("ShirtGraphic")
	for _, face in FACES do
		local normal, up = face.normal, face.up
		local right = (-normal):Cross(up) -- your right as you look at this face
		local faceW = math.abs(right:Dot(part.Size))
		local faceH = math.abs(up:Dot(part.Size))
		local depth = math.abs(normal:Dot(half))
		local countU = math.max(1, math.round(faceW / TILE))
		local countV = math.max(1, math.round(faceH / TILE))
		local w, h = faceW / countU, faceH / countV
		for iu = 0, countU - 1 do
			for iv = 0, countV - 1 do
				local a0, b0 = iu * w, iv * h -- from the face's top-left corner
				local center = normal * (depth + SKIN_THICKNESS / 2 - 0.02)
					+ right * (a0 + w / 2 - faceW / 2)
					+ up * (faceH / 2 - b0 - h / 2)
				-- The tile's front (-Z) faces out; its Y is the picture's up.
				local offset = CFrame.fromMatrix(center, up:Cross(-normal), up, -normal)
				local tile =
					newTile(part, Vector3.new(w + 0.01, h + 0.01, SKIN_THICKNESS), offset, parent)
				for index, cloth in clothes do
					local region = REGIONS[cloth.regions][face.name]
					dress(tile, cloth.image, region, faceW, faceH, a0, b0, index)
				end
				if
					graphic
					and graphic.Graphic ~= ""
					and key == "Torso"
					and face.name == "Front"
				then
					dress(tile, graphic.Graphic, nil, faceW, faceH, a0, b0, 3)
				end
				table.insert(tiles, { part = tile, center = center })
			end
		end
	end
end

-- The round R6 head: a ring of tiles, a rounded rim and a cap on top and below.
local HEAD_AROUND = 16
local function buildHeadSkin(part: BasePart, parent: Instance, tiles: { Tile })
	local s = part.Size.Y
	local radius = HEAD_SIZE / 2 * s
	local face = part:FindFirstChildOfClass("Decal")
	local faceImage = if face then face.Texture else ""
	local width = 2 * math.pi * radius / HEAD_AROUND + 0.01
	local function addFace(tile: BasePart, at: Vector3, angle: number, h: number)
		-- the face picture covers the front of the head (seen from the front)
		if faceImage == "" or math.cos(angle) < 0.15 then
			return
		end
		local leftEdge = at.X + width / 2 * math.cos(angle) -- your left = its +X
		dress(
			tile,
			faceImage,
			nil,
			2 * radius,
			2 * radius,
			radius - leftEdge,
			radius - (at.Y + h / 2),
			1
		)
	end
	for index = 0, HEAD_AROUND - 1 do
		local angle = (index + 0.5) / HEAD_AROUND * 2 * math.pi -- 0 = the face, + = its right
		local out = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		-- 3 bands on the side
		for band = -1, 1 do
			local h = 0.3 * s
			local at = out * (radius - SKIN_THICKNESS / 2 + 0.01) + Vector3.new(0, band * h, 0)
			local offset = CFrame.fromMatrix(at, Vector3.yAxis:Cross(-out), Vector3.yAxis, -out)
			local tile = newTile(part, Vector3.new(width, h + 0.01, SKIN_THICKNESS), offset, parent)
			addFace(tile, at, angle, h)
			table.insert(tiles, { part = tile, center = at })
		end
		-- the rounded rims, leaning 45°, above and below
		for _, sign in { 1, -1 } do
			local normal = (out + Vector3.new(0, sign, 0)).Unit
			local at = out * (radius * 0.86) + Vector3.new(0, sign * radius * 0.82, 0)
			local up = normal:Cross(Vector3.yAxis:Cross(out)).Unit * -1
			if up.Y < 0 then
				up = -up
			end
			local offset = CFrame.fromMatrix(at, up:Cross(-normal), up, -normal)
			local tile =
				newTile(part, Vector3.new(width * 0.9, 0.24 * s, SKIN_THICKNESS), offset, parent)
			table.insert(tiles, { part = tile, center = at })
		end
	end
	-- caps: 4 squares on top and 4 below
	for _, sign in { 1, -1 } do
		for qx = -1, 1, 2 do
			for qz = -1, 1, 2 do
				local q = radius * 0.34
				local at = Vector3.new(qx * q, sign * (radius - SKIN_THICKNESS / 2 + 0.02), qz * q)
				local tile = newTile(
					part,
					Vector3.new(radius * 0.7, SKIN_THICKNESS, radius * 0.7),
					CFrame.new(at),
					parent
				)
				table.insert(tiles, { part = tile, center = at })
			end
		end
	end
end

------------------------------------------------------------------------------
type Opened = {
	folder: Folder,
	tiles: { Tile },
	pieces: { Piece },
	partTransparency: number,
	faceTransparency: number?,
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
	local face = part:FindFirstChildOfClass("Decal")
	if face and state.faceTransparency then
		face.Transparency = state.faceTransparency
	end
end

local function open(model: Model, part: BasePart, key: string): Opened?
	local existing = opened[part]
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Anatomy"
	local pieces: { Piece } = {}
	if not buildInside(part, key, folder, pieces) then
		folder:Destroy()
		return nil
	end
	local tiles: { Tile } = {}
	if key == "Head" then
		buildHeadSkin(part, folder, tiles)
	else
		buildBoxSkin(model, part, key, folder, tiles)
	end
	local face = part:FindFirstChildOfClass("Decal")
	local state: Opened = {
		folder = folder,
		tiles = tiles,
		pieces = pieces,
		partTransparency = part.Transparency,
		faceTransparency = if face then face.Transparency else nil,
		connection = nil,
	}
	part.Transparency = 1
	if face then
		face.Transparency = 1
	end
	-- Your own head in first person: the camera hides the head with
	-- LocalTransparencyModifier; hide what replaces it the same way.
	if model == Players.LocalPlayer.Character then
		local function follow()
			for _, item in folder:GetChildren() do
				if item:IsA("BasePart") then
					item.LocalTransparencyModifier = part.LocalTransparencyModifier
				end
			end
		end
		state.connection = part:GetPropertyChangedSignal("LocalTransparencyModifier")
			:Connect(follow)
		follow()
	end
	folder.Parent = part
	opened[part] = state
	part.Destroying:Once(function()
		local s = opened[part]
		if s and s.connection then
			s.connection:Disconnect()
		end
		opened[part] = nil
	end)
	return state
end

-- The wounds of this part, from its attributes: { point (part space), level }.
type Wound = { point: Vector3, level: number }
local function woundsOf(model: Model, part: BasePart, key: string): { Wound }
	local list = {}
	local size = visibleSize(part, key)
	for side, direction in SIDES do
		local value = model:GetAttribute(`Torn_{key}_{side}`)
		if typeof(value) == "number" and value > 0 then
			local onSurface = direction * math.abs(direction:Dot(size / 2))
			local height = Vector3.new(0, size.Y / 2 * WOUND_HEIGHT[key], 0)
			table.insert(
				list,
				{ point = onSurface + height, level = math.clamp(math.floor(value), 1, 3) }
			)
		end
	end
	return list
end

local function refresh(model: Model, partName: string)
	local key = KEYS[partName]
	local part = model:FindFirstChild(partName)
	if key == nil or part == nil or not part:IsA("BasePart") then
		return
	end
	local wounds = woundsOf(model, part, key)
	if #wounds == 0 then
		close(part)
		return
	end
	local state = open(model, part, key)
	if state == nil then
		return
	end
	local grow = SIZE_FACTOR[key]
	-- Is `center` inside one of the wounds, with these radii per level?
	local function inside(center: Vector3, radii: { number }): boolean
		for _, wound in wounds do
			local radius = radii[wound.level] * grow
			if radius > 0 and (center - wound.point).Magnitude < radius then
				return true
			end
		end
		return false
	end
	for _, tile in state.tiles do
		tile.part.Transparency = if inside(tile.center, SKIN_RADIUS) then 1 else 0
	end
	for _, piece in state.pieces do
		local gone = false
		if piece.layer == "Muscle" then
			gone = inside(piece.center, MUSCLE_RADIUS)
		elseif piece.layer == "Skull" then
			gone = inside(piece.center, BONE_RADIUS)
		end
		piece.part.Transparency = if gone then 1 else 0
	end
end

function Anatomy.watch(model: Model)
	model.AttributeChanged:Connect(function(name: string)
		local key = string.match(name, "^Torn_(%a+)_%a+$")
		local partName = if key then PART_OF[key] else nil
		if partName then
			refresh(model, partName)
		end
	end)
	for partName in KEYS do
		refresh(model, partName)
	end
end

return table.freeze(Anatomy)
