--!strict
-- RiftAssets: Dr. Rift's gear as real meshes, in the imported RiftGear model
-- (assets/rift/RiftGear.fbx, made by tools/rift/build_rift_gear.py; see
-- docs/RIFT_FR.md): his cyborg left arm with the gravity glove, the ocular
-- implant, the ray gun, the portal gun, the potion flask. Each piece is a few
-- "<Piece>_<Layer>" meshes, one per material; a "<Piece>_Pivot" marker gives
-- its own origin, other markers ("Tip", "PalmPoint", "Cell", "Lens") points
-- on it (a muzzle, the glove's emitter, where a light goes).
--
--   RiftAssets.get()                     the pieces, or nil (no kit: an old
--                                        place; the callers build their gear
--                                        from parts then)
--   RiftAssets.spawn(name, at, paint?, scale?)
--                                        a copy of a piece, its own origin put
--                                        at `at`: the main part (the others
--                                        welded to it, under it, named after
--                                        their layer: "Glow", "Liquid"...), or
--                                        nil without the kit. Not parented.
--
-- The pieces' spaces (studs, Roblox axes):
--   Arm        Left Arm space (shoulder at Y = +1, the glove's end at Y = -1)
--   Eye        Head space, for the classic head mesh at scale 1.25
--   RayGun / PortalGun   Right Arm space (the fist at Y = -1, barrel along -Y)
--   Flask      its own centre

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local P = require(script.Parent.RiftParts)

local RiftAssets = {}

export type Layer = {
	source: BasePart,
	name: string, -- "Steel", "SteelDark", "Chrome", "Brass", "Rubber", "Glow", "Palm", "Glass", "Liquid", "Cork"
	offset: CFrame, -- where it sits in the piece's space
	size: Vector3, -- its size in studs
}
export type Piece = {
	name: string,
	layers: { Layer }, -- the biggest first (the main part)
	points: { [string]: CFrame }, -- the markers ("Tip", "PalmPoint", "Cell", "Lens"), piece space
}
export type Paint = (layer: string) -> (Color3, Enum.Material, number)

-- Every piece the kit must have (one missing: an old or half-arrived kit).
local NAMES = { "Arm", "Eye", "RayGun", "PortalGun", "Flask" }
-- Markers that are not drawn.
local MARKERS: { [string]: boolean } =
	{ Pivot = true, Tip = true, PalmPoint = true, Cell = true, Lens = true }

-- How each layer looks unless the caller paints it: colour, material, shine,
-- see-through.
type Look = { color: Color3, material: Enum.Material, shine: number, clear: number }
local LOOKS: { [string]: Look } = {
	Steel = {
		color = Color3.fromRGB(112, 114, 118),
		material = Enum.Material.Metal,
		shine = 0.06,
		clear = 0,
	},
	SteelDark = {
		color = Color3.fromRGB(44, 46, 50),
		material = Enum.Material.Metal,
		shine = 0.02,
		clear = 0,
	},
	Chrome = {
		color = Color3.fromRGB(198, 202, 208),
		material = Enum.Material.SmoothPlastic,
		shine = 0.35,
		clear = 0,
	},
	Brass = { color = P.BRASS, material = Enum.Material.Metal, shine = 0.1, clear = 0 },
	Rubber = { color = P.CABLE, material = Enum.Material.Rubber, shine = 0, clear = 0 },
	Glow = { color = P.RIFT_GREEN, material = Enum.Material.Neon, shine = 0, clear = 0 },
	Palm = { color = P.RIFT_GLOW, material = Enum.Material.Neon, shine = 0, clear = 0 },
	Glass = { color = P.GLASS, material = Enum.Material.Glass, shine = 0.15, clear = 0.6 },
	-- (opaque: Roblox draws nothing see-through behind a Glass-material part,
	-- and the flask's glass may well be painted Glass)
	Liquid = { color = P.ACID, material = Enum.Material.SmoothPlastic, shine = 0, clear = 0 },
	Cork = {
		color = Color3.fromRGB(150, 108, 66),
		material = Enum.Material.Wood,
		shine = 0,
		clear = 0,
	},
}
local DEFAULT_LOOK: Look = LOOKS.Steel
-- (the ray gun's glow is orange-red, the rest of his gear green)
local GLOWS: { [string]: Color3 } = { RayGun = P.RAY_GLOW }

local pieces: { [string]: Piece }? = nil
local warned = false
-- A kit already looked through and found lacking: not looked through again
-- until something is added to it.
local lacking: Instance? = nil

local function scaled(offset: CFrame, scale: number): CFrame
	return if scale == 1 then offset else CFrame.new(offset.Position * scale) * offset.Rotation
end

-- The pieces, once the kit is there with all of them (nil until then: it is
-- looked for again next time, the kit may arrive late).
function RiftAssets.get(): { [string]: Piece }?
	if pieces then
		return pieces
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local model = if assets then assets:FindFirstChild("RiftGear", true) else nil
	if model == nil or model == lacking then
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
		return nil
	end
	-- (how the importer turned and scaled the file)
	local toUp = up.Position - origin.Position
	local y, z = toUp.Unit, (out.Position - origin.Position).Unit
	local frame = CFrame.fromMatrix(origin.Position, y:Cross(z), y, z)
	local unit = toUp.Magnitude -- 1 kit stud, in studs

	-- First the pivots, then everything relative to its piece's pivot.
	type Found = { piece: string, layer: string, part: BasePart, relative: CFrame }
	local items: { Found } = {}
	local pivots: { [string]: Vector3 } = {}
	for _, item in model:GetDescendants() do
		local pieceName, layerName = string.match(item.Name, "^(%a+)_(%a+)$")
		if item:IsA("BasePart") and pieceName and layerName and pieceName ~= "Kit" then
			local relative = frame:ToObjectSpace(item.CFrame)
			if layerName == "Pivot" then
				pivots[pieceName] = relative.Position
			else
				table.insert(
					items,
					{ piece = pieceName, layer = layerName, part = item, relative = relative }
				)
			end
		end
	end
	local found: { [string]: Piece } = {}
	for _, item in items do
		local pivot = pivots[item.piece]
		if pivot then
			local piece = found[item.piece]
			if piece == nil then
				piece = { name = item.piece, layers = {}, points = {} }
				found[item.piece] = piece
			end
			local offset = CFrame.new((item.relative.Position - pivot) / unit)
				* item.relative.Rotation
			if MARKERS[item.layer] then
				piece.points[item.layer] = CFrame.new(offset.Position)
			else
				table.insert(piece.layers, {
					source = item.part,
					name = item.layer,
					offset = offset,
					size = item.part.Size / unit,
				})
			end
		end
	end
	for _, name in NAMES do
		local piece = found[name]
		if piece == nil or #piece.layers == 0 then
			if not warned and next(found) == nil then
				warned = true
				warn(
					"[RiftAssets] RiftGear has no pieces: import assets/rift/RiftGear.fbx "
						.. "again (docs/RIFT_FR.md). Simpler gear meanwhile."
				)
			end
			-- (an old kit, or one still arriving: look again once it changes)
			lacking = model
			model.DescendantAdded:Once(function()
				if lacking == model then
					lacking = nil
				end
			end)
			return nil
		end
	end
	for _, piece in found do
		table.sort(piece.layers, function(a: Layer, b: Layer)
			return a.size.Magnitude > b.size.Magnitude
		end)
	end
	pieces = found
	return found
end

-- The default look of a layer of a piece.
local function defaultPaint(piece: string, layer: string): (Color3, Enum.Material, number)
	local look = LOOKS[layer] or DEFAULT_LOOK
	local color = if layer == "Glow" then GLOWS[piece] or look.color else look.color
	return color, look.material, look.shine
end

-- A part that only shows (no collisions, no hits, no weight), welded to `main`.
local function attach(main: BasePart, part: BasePart, offset: CFrame)
	part.CanCollide = false
	part.Massless = true
	local weld = Instance.new("Weld")
	weld.Part0 = main
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = main
end

-- A copy of the piece `name`, its own origin put at `at` (world). `paint`
-- (optional) gives each layer's colour, material and shine; `scale` makes it
-- bigger or smaller (1 by default). The main part is returned (the others
-- are welded to it, under it, each named after its layer; the markers are
-- invisible little parts named "Tip", "PalmPoint", "Cell", "Lens"); not
-- parented yet. Nil without the kit.
function RiftAssets.spawn(name: string, at: CFrame, paint: Paint?, scale: number?): BasePart?
	local all = RiftAssets.get()
	local piece = if all then all[name] else nil
	if piece == nil then
		return nil
	end
	local k = scale or 1
	local pieceName = piece.name
	local paintLayer: Paint = paint
		or function(layerName: string): (Color3, Enum.Material, number)
			return defaultPaint(pieceName, layerName)
		end
	local main: BasePart? = nil
	local mainOffset = CFrame.identity
	for _, layer in piece.layers do
		local part = layer.source:Clone()
		part:ClearAllChildren()
		part.Name = layer.name
		-- (the importer gives each mesh a pivot at the kit's origin: far away;
		-- a copy's pivot is its own centre)
		part.PivotOffset = CFrame.identity
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = layer.name ~= "Glow" and layer.name ~= "Palm" and layer.name ~= "Glass"
		part.Size = layer.size * k
		local color, material, shine = paintLayer(layer.name)
		part.Color = color
		part.Material = material
		part.Reflectance = shine
		part.Transparency = (LOOKS[layer.name] or DEFAULT_LOOK).clear
		local offset = scaled(layer.offset, k)
		part.CFrame = at * offset
		if main == nil then
			main = part
			mainOffset = offset
		else
			attach(main :: BasePart, part, mainOffset:Inverse() * offset)
		end
	end
	local root = main :: BasePart
	for pointName, point in piece.points do
		if pointName ~= "Pivot" then
			local marker = Instance.new("Part")
			marker.Name = pointName
			marker.Size = Vector3.new(0.05, 0.05, 0.05)
			marker.Transparency = 1
			marker.CanQuery = false
			marker.CanTouch = false
			marker.CastShadow = false
			local offset = scaled(point, k)
			marker.CFrame = at * offset
			attach(root, marker, mainOffset:Inverse() * offset)
		end
	end
	return root
end

-- The default look of a layer (for parts built by hand that should match).
function RiftAssets.look(piece: string, layer: string): (Color3, Enum.Material, number)
	return defaultPaint(piece, layer)
end

return table.freeze(RiftAssets)
