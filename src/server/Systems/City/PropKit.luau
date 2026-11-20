--!strict
-- PropKit: swaps the city's primitive props for the real meshes of the city prop kit.
--
-- The kit is the model "CityProps" imported from assets/cityprops/CityProps.fbx (made by
-- tools/city/kit/build_city_kit.py; see docs/PROPS_FR.md) into ReplicatedStorage > Assets.
-- Each piece is a few MeshParts, one per material layer, named "<Piece>_<Layer>"
-- ("TrafficCone_Plastic", "TrafficCone_Reflective", ...), plus small marker cubes:
-- "<Piece>_Pivot" (the piece's own origin), optional "<Piece>_Light" / "<Piece>_Fx" (where its
-- light / particles go) and "Kit_Origin" / "Kit_Up" / "Kit_Out" (1 stud apart: they tell how
-- the importer turned and scaled the file, so any import setting works).
--
-- The city data (tools/city/meshprop.py) marks each prop with an invisible part named
-- "MeshProp": its CFrame = the piece's origin, attributes Piece (string), Tint (optional:
-- a Color3, or the string "r,g,b") and Scale (optional number). The prop's old primitive parts
-- are parented UNDER that marker. PropKit.apply(city), called by City/init once the city is
-- built, does for every marker whose piece is in the kit:
--   * clones the piece's layers there (anchored, no collision / touch / query: pure visuals),
--     each coloured from LOOKS below (a tintable layer takes the marker's Tint), sized by
--     Scale;
--   * the old parts that collide or are queried (CanCollide / CanQuery) become invisible
--     collision proxies, so collisions, raycasts and hit detection do not change;
--   * THE LIVE BULB: when the piece has a Glow layer (a lamp's bulb / lens, a fire's embers,
--     a stove's flame ring) and the old parts have a light part (a part tagged CityLamp,
--     CityBulkhead, CityFireEmbers, CityShopLight, CityNeon, CityEmergency, or else one with a
--     child Light), that part HANDS OVER to the mesh's Glow part: its tags, its attributes
--     (Dead, Flicker, Faulty, FaultySeed, Built*...), its colour, its material and its Light
--     move onto the Glow MeshPart. So the mesh's own lens IS the bulb for every system:
--     Ambience switches it (Neon by night, grey glass by day, power cuts, Dead, Flicker, the
--     burn barrel's fire), Client/FaultyLightController dims it with its light. A spot light
--     keeps pointing the same way. A piece with a Light marker but no light part in the data
--     (an unlit stove, a lamp placed without its light) shows its Glow layer unlit (glass);
--     a Glow layer of a piece with no Light marker (a radio's LED) just glows;
--   * the old parts that carry something else alive (tags, attributes, lights, particles,
--     prompts, sounds...) become invisible but stay; when the piece has a Light / Fx marker and
--     the part is not a collision proxy, it is moved there (lights to Light; particles and the
--     CityGutter / CitySteam / CityDrip parts to Fx, even an already invisible one) so the glow
--     / smoke / spout comes from the mesh. Their decals, textures and SurfaceGuis (the old
--     look's stencils and labels) are hidden: they would float on the old faces;
--   * the rest (pure decoration) is removed;
--   * other already-invisible parts (gameplay markers: NPC spots, spawns...) are left alone.
-- Without the kit (not imported yet) or for a piece the kit does not have, nothing changes:
-- the old parts show. Server only (clones replicate like any part).
--
--   PropKit.apply(city)   swaps every marker under `city` (yields now and then); returns how
--                         many props got their mesh
--   PropKit.has(piece)    true when the kit is there and has that piece

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PropKit = {}

local MARKER_NAME = "MeshProp"
-- Markers handled before letting the server breathe.
local PER_CHUNK = 60
-- Pieces at least this big (studs: about their size once scaled) cast shadows; smaller
-- clutter does not (cheaper, and tiny shadows only add noise).
local SHADOW_SIZE = 1.2

-- How each layer looks: colour (sRGB), material, shine (Reflectance), whether the marker's
-- Tint replaces the colour, whether it is a thin sheet seen from both sides, whether it may
-- cast a shadow. Dark, wet, dirty city: nothing saturated. The meshes' vertex colours (the
-- wear: grime, scuffs, ambient occlusion) multiply these. Keep in step with
-- tools/city/kit/kitlib.py LAYERS (the previews).
type Look = {
	color: Color3,
	material: Enum.Material,
	shine: number,
	tint: boolean,
	double: boolean,
	shadow: boolean,
}
local function look(
	r: number,
	g: number,
	b: number,
	material: Enum.Material,
	shine: number?,
	tint: boolean?,
	double: boolean?,
	shadow: boolean?
): Look
	return {
		color = Color3.fromRGB(r, g, b),
		material = material,
		shine = shine or 0,
		tint = tint == true,
		double = double == true,
		shadow = shadow ~= false,
	}
end
local LOOKS: { [string]: Look } = {
	Plastic = look(150, 120, 96, Enum.Material.Plastic, 0, true),
	PlasticDark = look(38, 38, 40, Enum.Material.Plastic),
	Rubber = look(30, 30, 31, Enum.Material.Rubber),
	RubberWorn = look(80, 75, 70, Enum.Material.Rubber), -- (old tyres: sun-greyed sidewalls)
	Reflective = look(208, 210, 206, Enum.Material.SmoothPlastic, 0.06),
	Metal = look(128, 130, 132, Enum.Material.Metal, 0.02),
	MetalPainted = look(84, 92, 88, Enum.Material.Plastic, 0, true),
	Rust = look(98, 58, 36, Enum.Material.CorrodedMetal),
	Wood = look(118, 92, 64, Enum.Material.Wood),
	WoodDark = look(66, 50, 38, Enum.Material.Wood),
	Fabric = look(96, 92, 84, Enum.Material.Fabric, 0, true),
	FabricDark = look(42, 40, 40, Enum.Material.Fabric),
	Leather = look(58, 40, 30, Enum.Material.Leather),
	LeatherBlack = look(30, 29, 29, Enum.Material.Leather),
	Foam = look(176, 164, 132, Enum.Material.Fabric),
	Cardboard = look(140, 110, 76, Enum.Material.Cardboard),
	Paper = look(196, 190, 174, Enum.Material.SmoothPlastic),
	Concrete = look(128, 126, 120, Enum.Material.Concrete),
	Brick = look(112, 64, 50, Enum.Material.Brick),
	Tarp = look(52, 70, 98, Enum.Material.Plastic, 0, true, true),
	Glass = look(60, 72, 74, Enum.Material.Glass, 0.12, false, false, false),
	Screen = look(14, 16, 18, Enum.Material.SmoothPlastic, 0.08),
	Chrome = look(200, 202, 206, Enum.Material.SmoothPlastic, 0.3),
	Black = look(16, 16, 17, Enum.Material.SmoothPlastic),
	Glow = look(255, 200, 140, Enum.Material.Neon, 0, false, false, false),
	Soil = look(66, 54, 42, Enum.Material.Ground),
}
local DEFAULT_LOOK: Look = LOOKS.Plastic
-- The Glow layer of a lamp whose light is not there (no light part in the data): dirty glass.
local UNLIT_GLOW: Look = look(90, 90, 86, Enum.Material.Glass, 0.05, false, false, false)
-- Tags of the light parts Ambience drives (the live bulb, see the top of this file).
local LIGHT_TAGS: { [string]: boolean } = {
	CityLamp = true,
	CityBulkhead = true,
	CityFireEmbers = true,
	CityShopLight = true,
	CityNeon = true,
	CityEmergency = true,
}
-- Tags of the parts that spout / smoke (Ambience adds their particles): they go to the Fx marker.
local FX_TAGS: { [string]: boolean } = { CityGutter = true, CitySteam = true, CityDrip = true }
-- Marker cubes of a piece (never drawn).
local POINTS: { [string]: boolean } = { Pivot = true, Light = true, Fx = true }

type Layer = {
	source: BasePart,
	name: string, -- "Plastic", "Rubber"...
	offset: CFrame, -- where it sits in the piece's space (studs)
	size: Vector3, -- its size in studs
}
type Piece = {
	name: string,
	layers: { Layer },
	points: { [string]: CFrame }, -- "Light", "Fx" (piece space)
	extent: number, -- how far it reaches from its pivot (studs)
}

local pieces: { [string]: Piece }? = nil
local looked = false
local warned = false

-- The kit's pieces (nil without the kit). Read once: the kit is part of the place.
local function load(): { [string]: Piece }?
	if looked then
		return pieces
	end
	looked = true
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local model = if assets then assets:FindFirstChild("CityProps", true) else nil
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
		warn(
			"[PropKit] CityProps has no Kit_Origin / Kit_Up / Kit_Out: import it again (docs/PROPS_FR.md)"
		)
		return nil
	end
	-- (how the importer turned and scaled the file)
	local toUp = up.Position - origin.Position
	local y, z = toUp.Unit, (out.Position - origin.Position).Unit
	local frame = CFrame.fromMatrix(origin.Position, y:Cross(z), y, z)
	local unit = toUp.Magnitude -- 1 kit stud, in studs

	type Found = { piece: string, layer: string, part: BasePart, relative: CFrame }
	local items: { Found } = {}
	local pivots: { [string]: Vector3 } = {}
	for _, item in model:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local pieceName, layerName = string.match(item.Name, "^(%w+)_(%a+)$")
		if pieceName and layerName and pieceName ~= "Kit" then
			local relative = frame:ToObjectSpace(item.CFrame)
			if layerName == "Pivot" then
				pivots[pieceName] = relative.Position
			elseif POINTS[layerName] or LOOKS[layerName] then
				table.insert(
					items,
					{ piece = pieceName, layer = layerName, part = item, relative = relative }
				)
			end
		end
	end
	local found: { [string]: Piece } = {}
	for _, item in items do
		local pivot: Vector3? = pivots[item.piece]
		if pivot == nil then
			continue
		end
		local piece = found[item.piece]
		if piece == nil then
			piece = { name = item.piece, layers = {}, points = {}, extent = 0 }
			found[item.piece] = piece
		end
		local offset = CFrame.new((item.relative.Position - pivot) / unit) * item.relative.Rotation
		if POINTS[item.layer] then
			piece.points[item.layer] = CFrame.new(offset.Position)
		else
			local size = item.part.Size / unit
			table.insert(
				piece.layers,
				{ source = item.part, name = item.layer, offset = offset, size = size }
			)
			-- (the piece's extent: the far corner of each layer from the pivot, both ways)
			local reach = offset.Position.Magnitude + size.Magnitude / 2
			piece.extent = math.max(piece.extent, reach)
		end
	end
	for name, piece in found do
		if #piece.layers == 0 then
			found[name] = nil
		end
	end
	if next(found) == nil then
		warn(
			"[PropKit] CityProps has no pieces: import assets/cityprops/CityProps.fbx again (docs/PROPS_FR.md)"
		)
		return nil
	end
	pieces = found
	return found
end

-- True when the kit is there and has `piece`.
function PropKit.has(piece: string): boolean
	local all = load()
	return all ~= nil and all[piece] ~= nil
end

local function scaled(offset: CFrame, scale: number): CFrame
	return if scale == 1 then offset else CFrame.new(offset.Position * scale) * offset.Rotation
end

-- The marker's Tint attribute: a Color3, or the string "r,g,b" (0..255) the data writes.
local function readTint(marker: Instance): Color3?
	local value = marker:GetAttribute("Tint")
	if typeof(value) == "Color3" then
		return value
	elseif typeof(value) == "string" then
		local r, g, b = string.match(value, "^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
		if r and g and b then
			return Color3.fromRGB(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
		end
	end
	return nil
end

-- Does this old part carry something that must keep working (a tag another system looks
-- for, attributes, a light, particles, a sign, a prompt, a sound...)? Also: has it a light,
-- and does it smoke / spout (particles, or a tag whose particles Ambience adds)?
local function isAlive(part: BasePart): (boolean, boolean, boolean)
	local alive = next(part:GetAttributes()) ~= nil
	local lit, smokes = false, false
	for _, tag in part:GetTags() do
		alive = true
		if FX_TAGS[tag] then
			smokes = true
		end
	end
	for _, child in part:GetChildren() do
		if child:IsA("Light") then
			lit = true
		elseif child:IsA("ParticleEmitter") or child:IsA("Fire") or child:IsA("Smoke") then
			smokes = true
		elseif not child:IsA("BasePart") then
			alive = true -- (SurfaceGui, ProximityPrompt, Sound, Attachment, Weld...)
		end
	end
	return alive or lit or smokes, lit, smokes
end

-- Hides what an invisible part would still draw: decals, textures, surface signs (the old
-- look's stencils and labels would float on faces the mesh no longer has).
local function hideSkin(part: BasePart)
	for _, child in part:GetChildren() do
		if child:IsA("Decal") then -- (Texture is a Decal)
			child.Transparency = 1
		elseif child:IsA("SurfaceGui") then
			child.Enabled = false
		end
	end
end

-- The old part that is the piece's light (see "THE LIVE BULB" at the top): a part with a tag
-- of LIGHT_TAGS first, else one with a child Light. Nil when there is none.
local function findBulb(marker: BasePart, meshes: { [Instance]: boolean }): BasePart?
	local withLight: BasePart? = nil
	for _, item in marker:GetDescendants() do
		if not item:IsA("BasePart") or meshes[item] then
			continue
		end
		for _, tag in item:GetTags() do
			if LIGHT_TAGS[tag] then
				return item
			end
		end
		if withLight == nil and item:FindFirstChildWhichIsA("Light") then
			withLight = item
		end
	end
	return withLight
end

-- The face of `to` that points closest to `direction` (world).
local function nearestFace(to: BasePart, direction: Vector3): Enum.NormalId
	local localDirection = to.CFrame:VectorToObjectSpace(direction)
	local best, bestDot = Enum.NormalId.Front, -math.huge
	for _, face in Enum.NormalId:GetEnumItems() do
		local dot = Vector3.FromNormalId(face):Dot(localDirection)
		if dot > bestDot then
			best, bestDot = face, dot
		end
	end
	return best
end

-- The old light part hands its role over to the mesh's Glow part: tags, attributes, colour,
-- material and lights (a spot keeps its world direction). Tags go last, so the systems that
-- watch them (Ambience, Client/FaultyLightController) find a complete part.
local function handOver(bulb: BasePart, glow: BasePart)
	glow.Color = bulb.Color
	glow.Material = bulb.Material
	glow.Reflectance = bulb.Reflectance
	for name, value in bulb:GetAttributes() do
		glow:SetAttribute(name, value)
		bulb:SetAttribute(name, nil)
	end
	for _, child in bulb:GetChildren() do
		if child:IsA("SpotLight") then
			child.Face =
				nearestFace(glow, bulb.CFrame:VectorToWorldSpace(Vector3.FromNormalId(child.Face)))
			child.Parent = glow
		elseif child:IsA("SurfaceLight") then
			local surface = child :: SurfaceLight
			surface.Face = nearestFace(
				glow,
				bulb.CFrame:VectorToWorldSpace(Vector3.FromNormalId(surface.Face))
			)
			surface.Parent = glow
		elseif child:IsA("Light") then
			child.Parent = glow
		end
	end
	for _, tag in bulb:GetTags() do
		bulb:RemoveTag(tag)
		glow:AddTag(tag)
	end
end

-- Turns the marker's old parts into invisible proxies / keeps what is alive / removes the
-- rest (see the top of this file). `meshes` are the new mesh parts (left alone).
local function retire(
	marker: BasePart,
	piece: Piece,
	pivot: CFrame,
	scale: number,
	meshes: { [Instance]: boolean }
)
	local doomed: { BasePart } = {}
	for _, item in marker:GetDescendants() do
		if not item:IsA("BasePart") or meshes[item] then
			continue
		end
		local proxy = item.CanCollide or item.CanQuery
		local alive, lit, smokes = isAlive(item)
		if item.Transparency >= 1 then
			-- (an invisible gameplay marker: not ours to touch, except an fx emitter that can
			-- go to the mesh's vent)
			if smokes and not proxy and piece.points.Fx then
				item.CFrame = CFrame.new((pivot * scaled(piece.points.Fx, scale)).Position)
					* item.CFrame.Rotation
			end
			continue
		end
		if proxy or alive then
			item.Transparency = 1
			item.CastShadow = false
			hideSkin(item)
			if not proxy then
				-- (only a part nothing collides with may move: lights to the mesh's lamp,
				-- particles to its vent)
				local point = if lit
					then piece.points.Light
					elseif smokes then piece.points.Fx
					else nil
				if point then
					item.CFrame = CFrame.new((pivot * scaled(point, scale)).Position)
						* item.CFrame.Rotation
				end
			end
		else
			table.insert(doomed, item)
		end
	end
	for _, part in doomed do
		-- (its own children that survive go up to the marker first)
		for _, child in part:GetChildren() do
			if child:IsA("BasePart") and child.Parent == part then
				child.Parent = marker
			end
		end
		part:Destroy()
	end
end

-- Puts the piece's mesh on one marker. False if the marker's piece is not in the kit.
local function swap(marker: BasePart, all: { [string]: Piece }): boolean
	local pieceName = marker:GetAttribute("Piece")
	if typeof(pieceName) ~= "string" or marker:GetAttribute("MeshApplied") == true then
		return false
	end
	local piece = all[pieceName]
	if piece == nil then
		return false
	end
	local scaleValue = marker:GetAttribute("Scale")
	local scale = if typeof(scaleValue) == "number" and scaleValue > 0 then scaleValue else 1
	local tint = readTint(marker)
	local pivot = marker.CFrame
	local shadows = piece.extent * scale >= SHADOW_SIZE
	local meshes: { [Instance]: boolean } = {}
	local glow: BasePart? = nil
	for _, layer in piece.layers do
		local part = layer.source:Clone()
		part:ClearAllChildren()
		for _, tag in part:GetTags() do
			part:RemoveTag(tag)
		end
		local style = LOOKS[layer.name] or DEFAULT_LOOK
		part.Name = `{piece.name}_{layer.name}`
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = shadows and style.shadow
		part.Transparency = 0
		part.Size = layer.size * scale
		part.Color = if style.tint and tint then tint else style.color
		part.Material = style.material
		part.Reflectance = style.shine
		if part:IsA("MeshPart") and style.double then
			-- (not writable from scripts on every engine version: the kit's sheets are
			-- modelled with two sides anyway)
			pcall(function()
				(part :: any).DoubleSided = true
			end)
		end
		-- (the importer gives each mesh its pivot at the kit's origin, far away)
		part.PivotOffset = CFrame.identity
		part.CFrame = pivot * scaled(layer.offset, scale)
		meshes[part] = true
		if layer.name == "Glow" then
			glow = part
		end
	end
	-- The live bulb (see the top of this file), before the meshes go in: they enter the place
	-- with their tags already on.
	if glow and piece.points.Light then
		local bulb = findBulb(marker, meshes)
		if bulb then
			handOver(bulb, glow)
		else
			glow.Color = UNLIT_GLOW.color
			glow.Material = UNLIT_GLOW.material
			glow.Reflectance = UNLIT_GLOW.shine
		end
	end
	for part in meshes do
		(part :: BasePart).Parent = marker
	end
	retire(marker, piece, pivot, scale, meshes)
	marker:SetAttribute("MeshApplied", true)
	return true
end

-- Swaps every "MeshProp" marker under `city` for its mesh (see the top of this file).
-- Returns how many got their mesh. Yields between chunks.
function PropKit.apply(city: Instance): number
	if not RunService:IsServer() then
		return 0
	end
	local markers: { BasePart } = {}
	for _, item in city:GetDescendants() do
		if item.Name == MARKER_NAME and item:IsA("BasePart") then
			table.insert(markers, item)
		end
	end
	if #markers == 0 then
		return 0
	end
	local all = load()
	if all == nil then
		if not warned then
			warned = true
			warn(
				`[PropKit] {#markers} props wait for the city prop kit: import `
					.. "assets/cityprops/CityProps.fbx (docs/PROPS_FR.md). Simple parts meanwhile."
			)
		end
		return 0
	end
	local done = 0
	for index, marker in markers do
		if marker.Parent ~= nil and swap(marker, all) then
			done += 1
		end
		if index % PER_CHUNK == 0 then
			task.wait()
		end
	end
	return done
end

return table.freeze(PropKit)
