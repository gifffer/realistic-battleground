--!strict
-- LabBuilder: builds one private lab room from plain parts (no uploaded asset), on the server.
--
-- Labs live in a row far from the city: slot n has its floor centre at
-- Config.Lab.ORIGIN + (n - 1) × SPACING on X. Every lab is a Model "Lab_<userId>" in
-- Workspace > Labs, with the attributes Owner (userId) and Unbreakable (heavy moves don't smash
-- it). All parts are anchored. ~60 parts, ONE light with shadows (the tube light), no windows.
--
-- Local frame: origin = the top of the floor, at its centre; +Z = from the door into the room.
-- Inside: 28 (X) × 11 (Y) × 20 (Z) studs.
--
-- NAMED PARTS (a contract with the client controllers: do not rename):
--   Floor         the PrimaryPart
--   VatCore       invisible, the centre of the vat (the client builds the fluid and the clone
--                 around it; the vat prompt is on it)
--   VatScreen     the little screen under the vat (faces -Z; the client writes on it)
--   BenchAnchor   invisible, on the bench top: the shell lies along +X, chest up (Load / Unload)
--   ChuteMouth    invisible, the mouth of the recycling chute in the +X wall (LookVector = in)
--   RackSpot      invisible, on the case rack (Take case)
--   StashShelf    invisible, the stash shelf (the client lines the capsules up along Z)
--   ExitDoor      the door you leave by (Leave)
--   Spawn         invisible, where the owner arrives (LookVector = +Z, into the room)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local LabBuilder = {}

-- Half sizes of the room's box (outer walls included), for "is someone inside?" checks.
LabBuilder.HALF_SIZE = Vector3.new(15, 6, 11)
LabBuilder.CENTRE_HEIGHT = 5.5 -- the box centre is this far above the floor top

local WALL_COLOR = Color3.fromRGB(168, 174, 172)

-- The CFrame of the floor-top centre of lab slot `slot` (1, 2, 3...).
function LabBuilder.origin(slot: number): CFrame
	return CFrame.new(Config.Lab.ORIGIN + Vector3.new((slot - 1) * Config.Lab.SPACING, 0, 0))
end

type PartOptions = {
	material: Enum.Material?,
	color: Color3?,
	transparency: number?,
	reflectance: number?,
	collide: boolean?,
	shape: Enum.PartType?,
	shadow: boolean?,
}

function LabBuilder.build(slot: number, owner: number): Model
	local origin = LabBuilder.origin(slot)
	local model = Instance.new("Model")
	model.Name = `Lab_{owner}`
	model:SetAttribute("Owner", owner)
	model:SetAttribute("Unbreakable", true)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- One anchored part. `at` is a CFrame in the lab's local frame.
	local function add(name: string, size: Vector3, at: CFrame, options: PartOptions?): Part
		local opts: PartOptions = options or {}
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = opts.shape or Enum.PartType.Block
		part.Size = size
		part.CFrame = origin * at
		part.Anchored = true
		part.Material = opts.material or Enum.Material.SmoothPlastic
		part.Color = opts.color or WALL_COLOR
		part.Transparency = opts.transparency or 0
		part.Reflectance = opts.reflectance or 0
		local collide = opts.collide ~= false
		part.CanCollide = collide
		part.CanQuery = collide
		part.CanTouch = false
		part.CastShadow = opts.shadow ~= false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end

	-- A standing cylinder (Roblox cylinders lie along X: turned 90° to stand up).
	local function cylinder(
		name: string,
		diameter: number,
		height: number,
		centre: Vector3,
		options: PartOptions?
	): Part
		local opts: PartOptions = options or {}
		opts.shape = Enum.PartType.Cylinder
		return add(
			name,
			Vector3.new(height, diameter, diameter),
			CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90)),
			opts
		)
	end

	-- An invisible marker (no collisions, no queries).
	local function marker(name: string, at: CFrame): Part
		local part = add(name, Vector3.one, at, { collide = false, shadow = false })
		part.Transparency = 1
		return part
	end

	local metal = Enum.Material.Metal

	-- Floor, walls, ceiling --------------------------------------------------
	local floor = add(
		"Floor",
		Vector3.new(30, 1, 22),
		CFrame.new(0, -0.5, 0),
		{ material = Enum.Material.Concrete, color = Color3.fromRGB(52, 54, 56) }
	)
	model.PrimaryPart = floor
	add("Wall", Vector3.new(30, 11, 1), CFrame.new(0, 5.5, 10.5)) -- back (+Z)
	add("Wall", Vector3.new(1, 11, 20), CFrame.new(14.5, 5.5, 0)) -- +X (the chute side)
	add("Wall", Vector3.new(1, 11, 20), CFrame.new(-14.5, 5.5, 0)) -- -X (rack, stash)
	-- the door wall (-Z), with a hole 4 wide and 7.5 high in the middle
	add("Wall", Vector3.new(13, 11, 1), CFrame.new(-8.5, 5.5, -10.5))
	add("Wall", Vector3.new(13, 11, 1), CFrame.new(8.5, 5.5, -10.5))
	add("Wall", Vector3.new(4, 3.5, 1), CFrame.new(0, 9.25, -10.5))
	add(
		"Ceiling",
		Vector3.new(30, 1, 22),
		CFrame.new(0, 11.5, 0),
		{ color = Color3.fromRGB(40, 42, 44) }
	) -- (also stops the rain rays)

	-- The one light with shadows: a cold tube on the ceiling.
	local tube = add(
		"TubeLight",
		Vector3.new(6, 0.2, 0.4),
		CFrame.new(6, 10.8, 3),
		{ material = Enum.Material.Neon, color = Color3.fromRGB(220, 235, 255), shadow = false }
	)
	local tubeLight = Instance.new("SurfaceLight")
	tubeLight.Face = Enum.NormalId.Bottom
	tubeLight.Brightness = 1.6
	tubeLight.Range = 14
	tubeLight.Angle = 120
	tubeLight.Color = Color3.fromRGB(220, 235, 255)
	tubeLight.Shadows = true
	tubeLight.Parent = tube
	-- A soft fill for the corners (no shadows, it only lifts the black).
	local fillPart = add(
		"FillLight",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(-4, 9.5, -2),
		{ transparency = 1, shadow = false, collide = false }
	)
	local fill = Instance.new("PointLight")
	fill.Brightness = 0.35
	fill.Range = 22
	fill.Color = Color3.fromRGB(205, 215, 225)
	fill.Shadows = false
	fill.Parent = fillPart

	-- The vat ------------------------------------------------------------------
	cylinder(
		"VatBase",
		5,
		1,
		Vector3.new(8, 0.5, 4),
		{ material = metal, color = Color3.fromRGB(90, 94, 98) }
	)
	local glass = cylinder("VatGlass", 4.4, 8, Vector3.new(8, 5, 4), {
		material = Enum.Material.Glass,
		-- (a little darker and cooler than the pearl shell and the clear fluid, so the body
		-- inside does not wash out into one grey slab)
		color = Color3.fromRGB(150, 176, 192),
		transparency = 0.6,
		shadow = false,
	})
	glass.CanQuery = false -- (prompts and clicks reach the vat's contents through it)
	local cap = cylinder(
		"VatCap",
		5,
		0.8,
		Vector3.new(8, 9.4, 4),
		{ material = metal, color = Color3.fromRGB(70, 72, 76) }
	)
	-- A weak cold light from the cap down into the vat: a rim on the clone's head and
	-- shoulders (no shadows).
	local rim = Instance.new("SpotLight")
	rim.Name = "VatRimLight"
	rim.Face = Enum.NormalId.Left -- (the cylinder is turned: its -X face looks down)
	rim.Brightness = 0.6
	rim.Range = 9
	rim.Angle = 50
	rim.Color = Color3.fromRGB(200, 225, 245)
	rim.Shadows = false
	rim.Parent = cap
	for _, offset in { -1.2, 1.2 } do
		cylinder(
			"VatPipe",
			0.4,
			1.4,
			Vector3.new(8 + offset, 10.5, 4),
			{ material = metal, color = Color3.fromRGB(80, 82, 86) }
		)
	end
	marker("VatCore", CFrame.new(8, 5, 4))
	add(
		"VatScreen",
		Vector3.new(1.6, 1, 0.1),
		CFrame.new(8, 2.4, 1.55),
		{ color = Color3.fromRGB(20, 22, 24), shadow = false }
	)

	-- The bench + its surgical lamp -------------------------------------------------
	local benchColor = Color3.fromRGB(150, 154, 158)
	add(
		"BenchTop",
		Vector3.new(7, 0.3, 3),
		CFrame.new(-3, 3.2, 3),
		{ material = metal, color = benchColor }
	)
	for _, x in { -6.2, 0.2 } do
		for _, z in { 1.8, 4.2 } do
			cylinder(
				"BenchLeg",
				0.3,
				3.05,
				Vector3.new(x, 1.525, z),
				{ material = metal, color = benchColor }
			)
		end
	end
	cylinder(
		"LampArm",
		0.15,
		2.6,
		Vector3.new(-3, 9.7, 3),
		{ material = metal, color = Color3.fromRGB(90, 92, 96) }
	)
	local lampHead = cylinder(
		"LampHead",
		1.4,
		0.4,
		Vector3.new(-3, 8.2, 3),
		{ material = metal, color = Color3.fromRGB(200, 202, 206), collide = false }
	)
	local lampLight = Instance.new("SpotLight")
	lampLight.Face = Enum.NormalId.Left -- (the head is a turned cylinder: its -X side faces down)
	lampLight.Brightness = 2
	lampLight.Range = 12
	lampLight.Angle = 50
	lampLight.Color = Color3.fromRGB(235, 245, 255)
	lampLight.Shadows = false
	lampLight.Parent = lampHead
	marker("BenchAnchor", CFrame.new(-3, 3.35, 3))

	-- The recycling chute in the +X wall --------------------------------------------
	add(
		"ChuteFrame",
		Vector3.new(0.6, 3.4, 3.4),
		CFrame.new(13.7, 2.5, -2),
		{ material = metal, color = Color3.fromRGB(60, 60, 62) }
	)
	add(
		"ChuteDark",
		Vector3.new(0.65, 3, 3),
		CFrame.new(13.68, 2.5, -2),
		{ color = Color3.new(0, 0, 0), collide = false, shadow = false }
	)
	marker("ChuteMouth", CFrame.lookAt(Vector3.new(13.4, 2.5, -2), Vector3.new(14.4, 2.5, -2)))

	-- The case rack on the -X wall ----------------------------------------------------
	local rackColor = Color3.fromRGB(80, 82, 86)
	add(
		"Rack",
		Vector3.new(1.2, 0.2, 3),
		CFrame.new(-13.4, 3, 6),
		{ material = metal, color = rackColor }
	)
	for _, z in { 4.8, 7.2 } do
		add(
			"RackBracket",
			Vector3.new(1, 0.6, 0.15),
			CFrame.new(-13.5, 2.6, z),
			{ material = metal, color = rackColor }
		)
	end
	local stencil = add(
		"RackStencil",
		Vector3.new(0.05, 0.6, 1.6),
		CFrame.new(-13.97, 4.6, 6),
		{ color = WALL_COLOR, collide = false, shadow = false }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Stencil"
	gui.Face = Enum.NormalId.Right -- (+X: into the room)
	gui.CanvasSize = Vector2.new(160, 60)
	gui.LightInfluence = 1
	gui.Parent = stencil
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BX-7"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(230, 120, 40)
	label.Parent = gui
	marker("RackSpot", CFrame.new(-13, 3.3, 6))

	-- The stash cabinet (open front) on the -X wall --------------------------------
	local cabinetColor = Color3.fromRGB(72, 74, 78)
	add(
		"Cabinet",
		Vector3.new(0.1, 5, 2),
		CFrame.new(-13.85, 2.5, -2),
		{ material = metal, color = cabinetColor }
	)
	for _, z in { -2.95, -1.05 } do
		add(
			"Cabinet",
			Vector3.new(1.4, 5, 0.1),
			CFrame.new(-13.2, 2.5, z),
			{ material = metal, color = cabinetColor }
		)
	end
	for _, y in { 0.05, 3.1, 4.95 } do
		add(
			"Cabinet",
			Vector3.new(1.3, 0.1, 1.8),
			CFrame.new(-13.2, y, -2),
			{ material = metal, color = cabinetColor }
		)
	end
	add("ColdStrip", Vector3.new(0.05, 0.05, 1.8), CFrame.new(-12.55, 3.18, -2), {
		material = Enum.Material.Neon,
		color = Color3.fromRGB(200, 225, 255),
		collide = false,
		shadow = false,
	})
	marker("StashShelf", CFrame.new(-12.8, 3.2, -2))

	-- The way out ------------------------------------------------------------------------
	add(
		"ExitDoor",
		Vector3.new(4, 7.5, 0.3),
		CFrame.new(0, 3.75, -10.2),
		{ material = Enum.Material.Wood, color = Color3.fromRGB(60, 48, 40) }
	)
	marker("Spawn", CFrame.lookAt(Vector3.new(0, 3, -7), Vector3.new(0, 3, 0)))

	return model
end

-- Is `position` inside the box of the lab at `slot` (grown by `margin` studs)?
function LabBuilder.contains(slot: number, position: Vector3, margin: number): boolean
	local centre = LabBuilder.origin(slot).Position + Vector3.new(0, LabBuilder.CENTRE_HEIGHT, 0)
	local offset = position - centre
	local half = LabBuilder.HALF_SIZE + Vector3.one * margin
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Y) <= half.Y
		and math.abs(offset.Z) <= half.Z
end

return table.freeze(LabBuilder)
