--!strict
-- PixelWorker: one band of rows of the pixel screen, drawn in PARALLEL
-- (PixelScreen clones this script into several Actors). For each pixel it
-- casts a ray into the scene and shades what it hits with a few colours
-- from a limited palette (ramps from dark navy to pale yellow, like the
-- old-school pixel art reference 35.png), with a 4x4 Bayer dither, see-
-- through plastic as a dither pattern and dark outlines round objects.
-- The original (not in an Actor) does nothing.

local actor = script:GetActor()
if actor == nil then
	return
end

------------------------------------------------------------------------------
-- Palette and ramps (dark -> light)
------------------------------------------------------------------------------

local function pack(r: number, g: number, b: number): number
	return r + g * 256 + b * 65536 + 255 * 16777216
end

local NAVY = pack(45, 47, 77)
local HIGHLIGHT = pack(223, 246, 179)

local RAMPS: { [string]: { number } } = {
	skin = { NAVY, pack(184, 106, 80), pack(232, 160, 122), pack(246, 208, 168) },
	raw = { NAVY, pack(136, 28, 43), pack(208, 96, 90), pack(240, 160, 144) },
	fat = { pack(136, 28, 43), pack(240, 111, 38), pack(252, 179, 76), HIGHLIGHT },
	muscle = { NAVY, pack(90, 20, 32), pack(136, 28, 43), pack(249, 4, 3) },
	blood = { NAVY, pack(90, 20, 32), pack(136, 28, 43), pack(249, 4, 3) },
	organ = { pack(136, 28, 43), pack(208, 96, 90), pack(240, 160, 144), HIGHLIGHT },
	liver = { NAVY, pack(90, 20, 32), pack(136, 28, 43), pack(192, 64, 64) },
	bone = { NAVY, pack(150, 140, 112), pack(225, 215, 190), HIGHLIGHT },
	steel = { NAVY, pack(74, 112, 125), pack(168, 184, 184), HIGHLIGHT },
	plastic = { pack(48, 69, 90), pack(74, 132, 139), pack(132, 166, 102), pack(202, 223, 126) },
	wall = { NAVY, pack(48, 69, 90), pack(74, 112, 125) },
	concrete = { NAVY, pack(48, 69, 90), pack(74, 112, 125), pack(132, 166, 102) },
	brick = { pack(48, 69, 90), pack(74, 112, 125), pack(202, 223, 126), HIGHLIGHT },
	neon = { HIGHLIGHT },
	glove = { NAVY, pack(40, 60, 120), pack(70, 110, 190), pack(140, 180, 230) },
	rubber = { NAVY, pack(40, 40, 50), pack(110, 30, 40) },
	wood = { NAVY, pack(60, 40, 30), pack(110, 70, 40) },
	photo = { NAVY, pack(110, 90, 70), pack(170, 140, 100) },
}

-- A ramp for a part without one: from its own colour, its shadow pulled
-- toward teal and its light toward pale yellow (hue-shifted, like pixel art).
local autoRamps: { [number]: { number } } = {}
local function autoRamp(color: Color3): { number }
	local r, g, b = math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)
	local key = r + g * 256 + b * 65536
	local known = autoRamps[key]
	if known then
		return known
	end
	local function mix(t: number, tr: number, tg: number, tb: number, k: number): number
		return pack(
			math.clamp(math.floor((r * k) * (1 - t) + tr * t), 0, 255),
			math.clamp(math.floor((g * k) * (1 - t) + tg * t), 0, 255),
			math.clamp(math.floor((b * k) * (1 - t) + tb * t), 0, 255)
		)
	end
	local ramp = { NAVY, mix(0.35, 48, 69, 90, 0.55), pack(r, g, b), mix(0.3, 223, 246, 179, 1.15) }
	autoRamps[key] = ramp
	return ramp
end

local BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }
for index, value in BAYER do
	BAYER[index] = (value + 0.5) / 16
end

------------------------------------------------------------------------------
-- What a ray hit: cached per part
------------------------------------------------------------------------------

local SOLID, GLASS, DECAL, ELLIPSOID, SKIP, GLOW = 1, 2, 3, 4, 5, 6

type Info = {
	kind: number,
	ramp: { number },
	shine: number,
	alpha: number,
	half: Vector3,
	id: number,
	stamp: number,
}

local infos: { [Instance]: Info } = setmetatable({}, { __mode = "k" }) :: any
local nextId = 0
local frameNumber = 0

-- One number per object (a layer welded under its organ: the organ's).
local groupIds: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local function idOf(part: BasePart): number
	local owner: Instance = part
	local parent = part.Parent
	if parent and parent:IsA("BasePart") then
		owner = parent
	end
	local id = groupIds[owner]
	if id == nil then
		nextId += 1
		id = nextId
		groupIds[owner] = id
	end
	return id
end

local function infoOf(part: BasePart): Info
	local info = infos[part]
	if info and frameNumber - info.stamp < 20 then
		return info
	end
	local id = idOf(part)
	local rampName = part:GetAttribute("PixRamp")
	local ramp = if typeof(rampName) == "string" and RAMPS[rampName]
		then RAMPS[rampName]
		else autoRamp(part.Color)
	local kind = SOLID
	local alpha = 1
	local half = part.Size / 2
	local ellipsoid = part:GetAttribute("PixEllipsoid")
	if part.Transparency >= 0.95 then
		local decal = part:FindFirstChildOfClass("Decal")
		if decal and decal.Transparency < 0.6 then
			kind = DECAL
			ramp = RAMPS.blood
		else
			kind = SKIP
		end
	elseif part.Transparency > 0.05 then
		kind = GLASS
		alpha = (1 - part.Transparency) * 0.7
	elseif rampName == "neon" or part.Material == Enum.Material.Neon then
		kind = GLOW
		ramp = RAMPS.neon
	elseif typeof(ellipsoid) == "Vector3" then
		kind = ELLIPSOID
		half = ellipsoid
	else
		local mesh = part:FindFirstChildOfClass("SpecialMesh")
		if mesh and mesh.MeshType == Enum.MeshType.Sphere then
			kind = ELLIPSOID
			half = part.Size / 2 * mesh.Scale
		end
	end
	if part.Name == "Blood" or part.Name == "BloodStrand" or part.Name == "BloodDrop" then
		ramp = RAMPS.blood
	end
	local made: Info = {
		kind = kind,
		ramp = ramp,
		shine = part.Reflectance,
		alpha = alpha,
		half = half,
		id = id,
		stamp = frameNumber,
	}
	infos[part] = made
	return made
end

-- The ray o + d·t against the ellipsoid of `half` sizes in `frame`:
-- the distance along it and the normal (world), or nil.
local function hitEllipsoid(
	frame: CFrame,
	half: Vector3,
	origin: Vector3,
	direction: Vector3
): (number?, Vector3?)
	local o = frame:PointToObjectSpace(origin) / half
	local d = frame:VectorToObjectSpace(direction) / half
	local a = d:Dot(d)
	local b = 2 * o:Dot(d)
	local c = o:Dot(o) - 1
	local disc = b * b - 4 * a * c
	if disc < 0 or a < 1e-12 then
		return nil, nil
	end
	local t = (-b - math.sqrt(disc)) / (2 * a)
	if t < 0 then
		return nil, nil
	end
	local p = (o + d * t) * half
	local n = frame:VectorToWorldSpace(p / (half * half))
	return t, n.Unit
end

------------------------------------------------------------------------------
-- The band
------------------------------------------------------------------------------

local W, H = 0, 0
local row0, row1 = 0, -1
local band = 0
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.IgnoreWater = true
local done: BindableEvent? = nil
local lamp, lampDown, side = Vector3.zero, Vector3.new(0, -1, 0), Vector3.zero
local COS_INNER, COS_OUTER = math.cos(math.rad(22)), math.cos(math.rad(48))
local MAX_DISTANCE = 70

local dirs: { Vector3 } = {}
local dirsTan = -1
local colours: { number } = {}
local ids: { number } = {}
local depths: { number } = {}
local out: buffer = buffer.create(4)

local function makeDirections(tanY: number)
	dirsTan = tanY
	local tanX = tanY * W / H
	local index = 0
	for row = row0, row1 do
		for column = 0, W - 1 do
			index += 1
			local u = ((column + 0.5) / W * 2 - 1) * tanX
			local v = (1 - (row + 0.5) / H * 2) * tanY
			dirs[index] = Vector3.new(u, v, -1).Unit
		end
	end
end

local function shade(
	info: Info,
	position: Vector3,
	normal: Vector3,
	direction: Vector3,
	dither: number
): number
	local ramp = info.ramp
	local count = #ramp
	if info.kind == GLOW or count == 1 then
		return ramp[count]
	end
	local toLamp = lamp - position
	local distance = toLamp.Magnitude
	toLamp /= distance
	local ndl = normal:Dot(toLamp)
	if ndl < 0 then
		ndl = 0
	end
	local cosAngle = -toLamp:Dot(lampDown)
	local spot = math.clamp((cosAngle - COS_OUTER) / (COS_INNER - COS_OUTER), 0, 1)
	spot = spot * spot * (3 - 2 * spot)
	local light = 0.26
		+ 0.1 * math.max(0, normal.Y)
		+ 1.0 * ndl * spot / (1 + 0.006 * distance * distance)
	local toSide = side - position
	local sideDistance = toSide.Magnitude
	local sideLight = normal:Dot(toSide / sideDistance)
	if sideLight > 0 then
		light += 0.3 * sideLight / (1 + 0.04 * sideDistance * sideDistance)
	end
	-- a wet glint: one pale pixel
	if info.shine > 0.1 and spot > 0.2 then
		local halfway = (toLamp - direction).Unit
		if normal:Dot(halfway) > 0.985 then
			return HIGHLIGHT
		end
	end
	local step = math.floor(light * (count - 1) + (dither - 0.5) * 0.6 + 0.3)
	return ramp[math.clamp(step + 1, 1, count)]
end

-- One pixel: its colour, the object it shows and how far it is.
local function trace(origin: Vector3, direction: Vector3, dither: number): (number, number, number)
	local from = origin
	local travelled = 0
	for _ = 1, 6 do
		local result = workspace:Raycast(from, direction * (MAX_DISTANCE - travelled), params)
		if result == nil then
			return NAVY, 0, MAX_DISTANCE
		end
		local part = result.Instance :: BasePart
		local info = infoOf(part)
		local distance = travelled + (result.Position - from).Magnitude
		local kind = info.kind
		local position, normal = result.Position, result.Normal
		local pass = false
		if kind == SKIP then
			pass = true
		elseif kind == ELLIPSOID then
			local t, n = hitEllipsoid(part.CFrame, info.half, from, direction)
			if t and n and t <= MAX_DISTANCE - travelled then
				position = from + direction * t
				normal = n
				distance = travelled + t
			else
				pass = true
			end
		elseif kind == DECAL then
			-- (a blood stain: its picture is round, not its square part)
			local l = part.CFrame:PointToObjectSpace(position)
			local h = info.half
			local ex, ez = l.X / h.X, l.Z / h.Z
			if ex * ex + ez * ez > 0.85 then
				pass = true
			end
		elseif kind == GLASS then
			-- see-through: a dither pattern of plastic over what's behind
			if dither < info.alpha then
				return shade(info, position, normal, direction, dither), info.id, distance
			end
			pass = true
		end
		if not pass then
			return shade(info, position, normal, direction, dither), info.id, distance
		end
		travelled = distance + 0.01
		from = origin + direction * travelled
		if travelled >= MAX_DISTANCE then
			break
		end
	end
	return NAVY, 0, MAX_DISTANCE
end

local function render(camera: CFrame, tanY: number, parity: number)
	frameNumber += 1
	if tanY ~= dirsTan then
		makeDirections(tanY)
	end
	local origin = camera.Position
	local index = 0
	for row = row0, row1 do
		local rowBayer = (row % 4) * 4
		if row % 2 ~= parity then
			index += W
			continue
		end
		for column = 0, W - 1 do
			index += 1
			local direction = camera:VectorToWorldSpace(dirs[index])
			local colour, id, depth = trace(origin, direction, BAYER[rowBayer + column % 4 + 1])
			colours[index] = colour
			ids[index] = id
			depths[index] = depth
		end
	end
	-- outlines: the farther pixel of two neighbours on different objects at
	-- different depths turns navy
	local rows = row1 - row0 + 1
	for r = 0, rows - 1 do
		local base = r * W
		for column = 0, W - 1 do
			local i = base + column + 1
			local colour = colours[i]
			local id = ids[i]
			local depth = depths[i]
			if id ~= 0 then
				local threshold = 0.1 + depth * 0.015
				if column < W - 1 then
					local j = i + 1
					if ids[j] ~= id and depths[j] < depth - threshold then
						colour = NAVY
					end
				end
				if column > 0 then
					local j = i - 1
					if ids[j] ~= id and depths[j] < depth - threshold then
						colour = NAVY
					end
				end
				if r < rows - 1 then
					local j = i + W
					if ids[j] ~= id and depths[j] < depth - threshold then
						colour = NAVY
					end
				end
				if r > 0 then
					local j = i - W
					if ids[j] ~= id and depths[j] < depth - threshold then
						colour = NAVY
					end
				end
			end
			buffer.writeu32(out, (i - 1) * 4, colour)
		end
	end
end

actor:BindToMessageParallel("Setup", function(config: any)
	W, H = config.width, config.height
	row0, row1 = config.row0, config.row1
	band = config.band
	params.FilterDescendantsInstances = config.include
	lamp, lampDown, side = config.lamp, config.lampDown, config.side
	done = config.done
	local count = W * (row1 - row0 + 1)
	out = buffer.create(count * 4)
	colours = table.create(count, NAVY)
	ids = table.create(count, 0)
	depths = table.create(count, MAX_DISTANCE)
	dirsTan = -1
end)

actor:BindToMessageParallel("Frame", function(camera: CFrame, tanY: number, parity: number)
	if done == nil or W == 0 then
		return
	end
	render(camera, tanY, parity)
	task.synchronize()
	local event = done
	if event then
		event:Fire(band, out)
	end
end)
