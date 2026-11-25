--!strict
-- Parts: tiny helpers to build the lab's client-only visuals out of plain parts.
--
-- Every part made here is LOCAL decoration: anchored, no collision, no queries, no touch,
-- no shadow (the lab has one shadow light and these are small), SmoothPlastic by default.
-- Nothing is uploaded: parts, built-in materials, SpecialMesh "Sphere" for ellipsoids only.
--
--   Parts.part(props)                          a Part with the defaults above + `props`
--   Parts.ball(diameter, props)                a round Part (Shape Ball)
--   Parts.ellipsoid(size, props)               a Part with a Sphere SpecialMesh (an egg-free blob)
--   Parts.rod(a, b, diameter, props)           a cylinder from point a to point b (local space)
--   Parts.disc(diameter, height, props)        a flat cylinder lying horizontally (axis = Y)
--   Parts.ring(centre, radius, thick, n, props)  a hoop of n short rods (axis = Y of `centre`)
--
-- Roblox cylinders run along their X axis: rod / disc turn them so the long axis is where
-- you expect. All CFrames here are LOCAL to a model's root: the builders keep a table
-- part → local CFrame and place everything with one BulkMoveTo (see Rig below).

local Parts = {}

export type Props = { [string]: any }

-- part → its CFrame in the rig's own space.
export type Rig = {
	parts: { BasePart },
	locals: { CFrame },
	index: { [BasePart]: number },
}

function Parts.part(props: Props): BasePart
	local part: BasePart = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Locked = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	-- Parent last (faster, and nothing half-built is ever drawn).
	if parent then
		part.Parent = parent
	end
	return part
end

function Parts.ball(diameter: number, props: Props): BasePart
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	return Parts.part(props)
end

-- A smooth blob of any proportions: a Part with a "Sphere" SpecialMesh (built in, no upload).
-- The mesh fills the part's size, so `size` is the blob's real size.
function Parts.ellipsoid(size: Vector3, props: Props): BasePart
	props.Size = size
	local part = Parts.part(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- The CFrame that puts a cylinder's long axis (its X) from `a` to `b`.
function Parts.between(a: Vector3, b: Vector3): CFrame
	local middle = (a + b) * 0.5
	local direction = b - a
	if direction.Magnitude < 1e-6 then
		return CFrame.new(middle)
	end
	local x = direction.Unit
	-- any vector not parallel to x, to build the other two axes
	local helper = if math.abs(x.Y) < 0.95 then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	local z = x:Cross(helper).Unit
	local y = z:Cross(x).Unit
	return CFrame.fromMatrix(middle, x, y, z)
end

-- A cylinder from `a` to `b`. Its CFrame is set from `props.CFrame` if given (rare), else
-- from a / b. Returns the part and its CFrame (handy for rigs).
function Parts.rod(a: Vector3, b: Vector3, diameter: number, props: Props): (BasePart, CFrame)
	local cframe = Parts.between(a, b)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(math.max((b - a).Magnitude, 0.05), diameter, diameter)
	props.CFrame = cframe
	return Parts.part(props), cframe
end

-- A cylinder turned so its axis is Y (a disc / a vertical tube). Put it where you want with
-- `upright * CFrame` (see Parts.UPRIGHT).
Parts.UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
function Parts.disc(diameter: number, height: number, props: Props): BasePart
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	return Parts.part(props)
end

------------------------------------------------------------------------------
-- Rigs: a list of parts with a CFrame each in the rig's space, placed together.
------------------------------------------------------------------------------

function Parts.newRig(): Rig
	return { parts = {}, locals = {}, index = {} }
end

-- Adds `part` to the rig at `localCFrame` (returns the part).
function Parts.add(rig: Rig, part: BasePart, localCFrame: CFrame): BasePart
	local index = rig.index[part]
	if index then
		rig.locals[index] = localCFrame
		return part
	end
	table.insert(rig.parts, part)
	table.insert(rig.locals, localCFrame)
	rig.index[part] = #rig.parts
	return part
end

-- Changes where one part sits in the rig (seen at the next Parts.place).
function Parts.setLocal(rig: Rig, part: BasePart, localCFrame: CFrame)
	local index = rig.index[part]
	if index then
		rig.locals[index] = localCFrame
	end
end

function Parts.getLocal(rig: Rig, part: BasePart): CFrame
	local index = rig.index[part]
	return if index then rig.locals[index] else CFrame.identity
end

-- Moves every part of the rig to `root * local` in one go.
function Parts.place(rig: Rig, root: CFrame)
	local cframes = table.create(#rig.parts)
	for i, localCFrame in rig.locals do
		cframes[i] = root * localCFrame
	end
	workspace:BulkMoveTo(rig.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- A hoop: `count` short rods around the Y axis of `centre` (local space), added to `rig`.
function Parts.ring(
	rig: Rig,
	centre: CFrame,
	radius: number,
	thickness: number,
	count: number,
	props: Props
): { BasePart }
	local made: { BasePart } = {}
	for i = 1, count do
		local a0 = (i - 1) / count * math.pi * 2
		local a1 = i / count * math.pi * 2
		local p0 = centre * Vector3.new(math.cos(a0) * radius, 0, math.sin(a0) * radius)
		local p1 = centre * Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
		-- (a little longer than the chord, so the segments overlap without gaps)
		local direction = (p1 - p0).Unit
		local copy = table.clone(props)
		local part, cframe = Parts.rod(
			p0 - direction * thickness * 0.4,
			p1 + direction * thickness * 0.4,
			thickness,
			copy
		)
		Parts.add(rig, part, cframe)
		table.insert(made, part)
	end
	return made
end

-- Visibility helper: a part's "own" transparency `base`, seen through a fade `visible`
-- (0 = gone, 1 = fully as designed).
function Parts.fade(base: number, visible: number): number
	if visible <= 0 then
		return 1
	end
	return 1 - (1 - base) * math.clamp(visible, 0, 1)
end

return Parts
