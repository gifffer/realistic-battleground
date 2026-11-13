--!strict
-- GoreKit: the gore pieces of the finishers (the burst head of the bat, the
-- Boxer's liver, the Bouncer's torn arm) in the imported
-- WoundKit model: "Gore_<Piece>_<Layer>" meshes made from real anatomy
-- (tools/wounds/gore.py, Shared/GoreShapes). HeadBlast puts copies of them
-- where they were in the head, then lets them fly.
--
--   GoreKit.get()                  the pieces, or nil (no kit / an old kit:
--                                  HeadBlast then draws simpler ones itself)
--   GoreKit.spawn(piece, at, paint) a copy of a piece, its head space put at
--                                  `at`; one part, the others welded to it

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoreShapes = require(ReplicatedStorage.Shared.GoreShapes)

local GoreKit = {}

export type Layer = {
	source: BasePart,
	name: string, -- "Skin", "Bone", "Brain", "Sclera", "Iris", "Tooth", "Flesh", "Blood"
	offset: CFrame, -- where it sits in head space
	size: Vector3, -- its size in studs
}
export type Piece = {
	name: string,
	layers: { Layer }, -- the biggest first
	center: Vector3, -- head space
}

local pieces: { [string]: Piece }? = nil
local warned = false
-- A kit already looked through and found without the pieces (an old one):
-- not looked through again until something is added to it.
local lacking: Instance? = nil

-- The pieces, once the kit is there with all of them (nil until then: it is
-- looked for again next time, the kit may replicate late).
function GoreKit.get(): { [string]: Piece }?
	if pieces then
		return pieces
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local model = if assets then assets:FindFirstChild("WoundKit", true) else nil
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
	local toUp = up.Position - origin.Position
	local y, z = toUp.Unit, (out.Position - origin.Position).Unit
	local frame = CFrame.fromMatrix(origin.Position, y:Cross(z), y, z)
	local unit = toUp.Magnitude -- 1 kit stud, in studs (the importer may scale)

	local found: { [string]: Piece } = {}
	for _, item in model:GetDescendants() do
		local pieceName, layerName = string.match(item.Name, "^Gore_(%w+)_(%a+)$")
		local slot = if pieceName then GoreShapes.slots[pieceName] else nil
		if item:IsA("BasePart") and pieceName and layerName and slot then
			local relative = frame:ToObjectSpace(item.CFrame)
			local layer: Layer = {
				source = item,
				name = layerName,
				offset = CFrame.new(relative.Position / unit - slot) * relative.Rotation,
				size = item.Size / unit,
			}
			local piece = found[pieceName]
			if piece == nil then
				piece = { name = pieceName, layers = {}, center = Vector3.zero }
				found[pieceName] = piece
			end
			table.insert(piece.layers, layer)
		end
	end
	-- (the torn arm's pieces came later: a kit without them still has the
	-- head's; ArmRip draws simpler ones itself then)
	local optional: { [string]: boolean } = {}
	for _, name in GoreShapes.limb do
		optional[name] = true
	end
	-- (nor Dr. Rift's body cut in two: WaistCut draws simpler ones then)
	for _, name in GoreShapes.cut do
		optional[name] = true
	end
	for name in GoreShapes.slots do
		if found[name] == nil and not optional[name] then
			if not warned and next(found) == nil then
				warned = true
				warn(
					"[HeadBlast] WoundKit has no burst-head pieces (Gore_*): import "
						.. "assets/wounds/WoundKit.fbx again (docs/WOUNDS_FR.md). Simpler pieces meanwhile."
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
		piece.center = piece.layers[1].offset.Position
	end
	pieces = found
	return found
end

-- A copy of `piece`, its head space put at `at` (world). `paint(layer)`
-- gives each layer's colour and shine. Returns the main part (the others
-- are welded to it, under it); not parented yet.
function GoreKit.spawn(
	piece: Piece,
	at: CFrame,
	paint: (layer: string) -> (Color3, number)
): BasePart
	local main: BasePart? = nil
	local mainOffset = CFrame.identity
	for _, layer in piece.layers do
		local part = layer.source:Clone()
		part:ClearAllChildren()
		-- (the importer gives each piece a pivot at the kit's origin: far
		-- away; a copy's pivot is its own centre)
		part.PivotOffset = CFrame.identity
		part.Anchored = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = true
		part.Size = layer.size
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0
		local color, shine = paint(layer.name)
		part.Color = color
		part.Reflectance = shine
		part.CFrame = at * layer.offset
		if main == nil then
			main = part
			mainOffset = layer.offset
		else
			part.CanCollide = false
			part.Massless = true
			local weld = Instance.new("Weld")
			weld.Part0 = main
			weld.Part1 = part
			weld.C0 = mainOffset:Inverse() * layer.offset
			weld.Parent = part
			part.Parent = main
		end
	end
	return main :: BasePart
end

return table.freeze(GoreKit)
