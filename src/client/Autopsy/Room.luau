--!strict
-- Room: the kill room of the autopsy video, after the Dexter reference
-- (34.png): cold blue-teal light, clear plastic on every wall and on folding
-- screens round a steel table with crossed legs, one harsh lamp over the
-- body, a whitewashed brick arch at the back with framed photos, a lamp and
-- a tool cart on the right, a stool on the left. Built by the client only
-- (nobody else sees it), closed on all sides so no sun gets in.
--
--   Room.build(origin, parent) -> Room   origin: the middle of its floor

local Make = require(script.Parent.Make)

local Room = {}

export type Room = {
	model: Model,
	frame: CFrame, -- the floor's middle, X across, Z to the back wall
	torso: CFrame, -- where the patient's torso lies (its front up, head +X)
	lamp: Vector3, -- the overhead light
	lampDown: Vector3,
	side: Vector3, -- (the second lamp, by the cart)
	entry: CFrame, -- where you arrive
	stand: CFrame, -- where you stand to operate
	tableTop: BasePart,
	tray: BasePart,
	exitPlate: BasePart,
}

local WIDTH, DEPTH, HEIGHT = 16, 18, 9.5
local TABLE_Y = 2.8 -- the top's middle
local TABLE_SIZE = Vector3.new(7.6, 0.2, 2.6)

local WALL = Color3.fromRGB(40, 48, 52)
local CONCRETE = Color3.fromRGB(70, 72, 75)
local STEEL = Color3.fromRGB(165, 170, 175)
local DARK_STEEL = Color3.fromRGB(70, 74, 80)
local BRICK = Color3.fromRGB(205, 205, 198)

local function steel(props: Make.Props): Part
	props.Material = props.Material or Enum.Material.Metal
	props.Color = props.Color or STEEL
	props.Reflectance = props.Reflectance or 0.2
	props.Ramp = props.Ramp or "steel"
	return Make.part(props)
end

-- The box: floor, ceiling and 4 walls, with plastic hung in front of them.
local function shell(model: Model, frame: CFrame, random: Random)
	Make.part({
		Name = "Floor",
		Size = Vector3.new(WIDTH + 1, 0.4, DEPTH + 1),
		CFrame = frame * CFrame.new(0, -0.2, 0),
		Material = Enum.Material.Concrete,
		Color = CONCRETE,
		Ramp = "concrete",
		Parent = model,
	})
	local ceiling = Make.part({
		Name = "Ceiling",
		Size = Vector3.new(WIDTH + 1, 0.4, DEPTH + 1),
		CFrame = frame * CFrame.new(0, HEIGHT + 0.2, 0),
		Color = WALL,
		Ramp = "wall",
		Parent = model,
	})
	-- (cold blue fill from above)
	for _, z in { -5, 5 } do
		local panel = Make.part({
			Name = "CeilingLight",
			Size = Vector3.new(3, 0.08, 1),
			CFrame = frame * CFrame.new(0, HEIGHT - 0.04, z),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(150, 195, 255),
			Ramp = "neon",
			Parent = ceiling,
		})
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Brightness = 0.5
		light.Range = 14
		light.Angle = 120
		light.Color = Color3.fromRGB(120, 175, 255)
		light.Parent = panel
	end
	local walls: { { Vector3 } } = {
		{ Vector3.new(0, HEIGHT / 2, DEPTH / 2 + 0.2), Vector3.new(WIDTH + 1, HEIGHT, 0.4) },
		{ Vector3.new(0, HEIGHT / 2, -DEPTH / 2 - 0.2), Vector3.new(WIDTH + 1, HEIGHT, 0.4) },
		{ Vector3.new(WIDTH / 2 + 0.2, HEIGHT / 2, 0), Vector3.new(0.4, HEIGHT, DEPTH + 1) },
		{ Vector3.new(-WIDTH / 2 - 0.2, HEIGHT / 2, 0), Vector3.new(0.4, HEIGHT, DEPTH + 1) },
	}
	for _, wall in walls do
		Make.part({
			Name = "Wall",
			Size = wall[2],
			CFrame = frame * CFrame.new(wall[1]),
			Color = WALL,
			Ramp = "wall",
			Parent = model,
		})
	end
	-- plastic sheets on the walls (not over the arch)
	local hang = HEIGHT - 0.3
	Make.plastic(
		frame * CFrame.new(-5.25, hang / 2 + 0.15, DEPTH / 2 - 0.35),
		Vector2.new(WIDTH / 2 - 2.5 - 0.5, hang),
		model,
		random
	)
	Make.plastic(
		frame * CFrame.new(5.25, hang / 2 + 0.15, DEPTH / 2 - 0.35),
		Vector2.new(WIDTH / 2 - 2.5 - 0.5, hang),
		model,
		random
	)
	Make.plastic(
		frame * CFrame.new(0, hang / 2 + 0.15, -DEPTH / 2 + 0.35) * CFrame.Angles(0, math.pi, 0),
		Vector2.new(WIDTH - 0.6, hang),
		model,
		random
	)
	for _, side in { -1, 1 } do
		Make.plastic(
			frame
				* CFrame.new(side * (WIDTH / 2 - 0.35), hang / 2 + 0.15, 0)
				* CFrame.Angles(0, -side * math.pi / 2, 0),
			Vector2.new(DEPTH - 0.6, hang),
			model,
			random
		)
	end
	-- plastic on the floor round the table
	Make.part({
		Name = "FloorPlastic",
		Size = Vector3.new(11, 0.04, 7),
		CFrame = frame * CFrame.new(0, 0.02, 0),
		Color = Make.PLASTIC,
		Transparency = 0.55,
		Reflectance = 0.3,
		Ramp = "plastic",
		Parent = model,
	})
end

-- The whitewashed brick arch at the back, with three small frames.
local function arch(model: Model, frame: CFrame)
	local back = frame * CFrame.new(0, 0, DEPTH / 2 - 0.1)
	Make.part({
		Name = "ArchWall",
		Size = Vector3.new(6, 6.2, 0.3),
		CFrame = back * CFrame.new(0, 3.1, 0),
		Material = Enum.Material.Brick,
		Color = BRICK,
		Ramp = "brick",
		Parent = model,
	})
	Make.part({
		Name = "ArchTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 6, 6),
		CFrame = back * CFrame.new(0, 6.2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Material = Enum.Material.Brick,
		Color = BRICK,
		Ramp = "brick",
		Parent = model,
	})
	-- (the dark rim of the arch)
	for _, x in { -3.15, 3.15 } do
		Make.part({
			Name = "ArchRim",
			Size = Vector3.new(0.3, 6.2, 0.4),
			CFrame = back * CFrame.new(x, 3.1, -0.05),
			Color = Color3.fromRGB(30, 34, 40),
			Ramp = "wall",
			Parent = model,
		})
	end
	for index, at in
		{ Vector3.new(-1.4, 4.6, 0), Vector3.new(0.3, 4.9, 0), Vector3.new(1.6, 4.3, 0) }
	do
		local size = if index == 2 then Vector2.new(0.9, 1.2) else Vector2.new(0.75, 0.95)
		local outer = Make.part({
			Name = "PhotoFrame",
			Size = Vector3.new(size.X, size.Y, 0.08),
			CFrame = back * CFrame.new(at - Vector3.new(0, 0, 0.2)),
			Color = Color3.fromRGB(40, 32, 26),
			Ramp = "wood",
			Parent = model,
		})
		Make.part({
			Name = "Photo",
			Size = Vector3.new(size.X - 0.2, size.Y - 0.2, 0.02),
			CFrame = outer.CFrame * CFrame.new(0, 0, -0.05),
			Color = Color3.fromRGB(70 + index * 25, 60 + index * 15, 55),
			Ramp = "photo",
			Parent = model,
		})
	end
end

-- One folding screen: 3 framed panels of stretched plastic, a little
-- turned to each other.
local function screen(model: Model, frame: CFrame, random: Random)
	local panelWidth, panelHeight = 2.6, 7.5
	local turns = { -0.35, 0, 0.35 }
	local at = frame * CFrame.new(-panelWidth, 0, 0)
	for index = 1, 3 do
		local panel = at * CFrame.Angles(0, turns[index], 0) * CFrame.new(panelWidth / 2, 0, 0)
		local left = panel * CFrame.new(-panelWidth / 2, 0, 0)
		local right = panel * CFrame.new(panelWidth / 2, 0, 0)
		for _, foot in { left, right } do
			Make.rod(foot.Position, (foot * CFrame.new(0, panelHeight, 0)).Position, 0.12, {
				Name = "ScreenFrame",
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(150, 155, 160),
				Ramp = "steel",
				Parent = model,
			})
		end
		Make.rod(
			(left * CFrame.new(0, panelHeight, 0)).Position,
			(right * CFrame.new(0, panelHeight, 0)).Position,
			0.1,
			{
				Name = "ScreenFrame",
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(150, 155, 160),
				Ramp = "steel",
				Parent = model,
			}
		)
		Make.plastic(
			panel * CFrame.new(0, panelHeight / 2 + 0.1, 0),
			Vector2.new(panelWidth - 0.1, panelHeight - 0.4),
			model,
			random,
			0.45
		)
		at = panel * CFrame.new(panelWidth / 2, 0, 0)
	end
end

-- The steel table with crossed legs, plastic over it.
local function steelTable(model: Model, frame: CFrame, random: Random): BasePart
	local top = steel({
		Name = "TableTop",
		Size = TABLE_SIZE,
		CFrame = frame * CFrame.new(0, TABLE_Y, 0),
		Reflectance = 0.25,
		Parent = model,
	})
	local half = TABLE_SIZE / 2
	for _, z in { -half.Z, half.Z } do
		steel({
			Name = "Lip",
			Size = Vector3.new(TABLE_SIZE.X, 0.15, 0.08),
			CFrame = top.CFrame * CFrame.new(0, 0.12, z),
			Parent = model,
		})
	end
	for _, x in { -half.X + 0.5, half.X - 0.5 } do
		local low = TABLE_Y - 0.1
		for _, z in { -1, 1 } do
			Make.rod(
				(frame * CFrame.new(x, 0, z * 1.1)).Position,
				(frame * CFrame.new(x, low, -z * 1.1)).Position,
				0.15,
				{
					Name = "Leg",
					Material = Enum.Material.Metal,
					Color = DARK_STEEL,
					Ramp = "steel",
					Parent = model,
				}
			)
		end
		Make.rod(
			(frame * CFrame.new(x, 0.35, -1.1)).Position,
			(frame * CFrame.new(x, 0.35, 1.1)).Position,
			0.12,
			{
				Name = "Bar",
				Material = Enum.Material.Metal,
				Color = DARK_STEEL,
				Ramp = "steel",
				Parent = model,
			}
		)
	end
	Make.rod(
		(frame * CFrame.new(-half.X + 0.5, 0.35, 0)).Position,
		(frame * CFrame.new(half.X - 0.5, 0.35, 0)).Position,
		0.12,
		{
			Name = "Bar",
			Material = Enum.Material.Metal,
			Color = DARK_STEEL,
			Ramp = "steel",
			Parent = model,
		}
	)
	-- the plastic over the top, hanging down its sides
	Make.part({
		Name = "TablePlastic",
		Size = Vector3.new(TABLE_SIZE.X + 0.2, 0.03, TABLE_SIZE.Z + 0.2),
		CFrame = top.CFrame * CFrame.new(0, 0.12, 0),
		Color = Make.PLASTIC,
		Transparency = 0.55,
		Reflectance = 0.3,
		Ramp = "plastic",
		CanCollide = false,
		Parent = model,
	})
	for _, z in { -1, 1 } do
		Make.plastic(
			top.CFrame
				* CFrame.new(0, -0.2, z * (half.Z + 0.12))
				* CFrame.Angles(0, if z > 0 then 0 else math.pi, 0),
			Vector2.new(TABLE_SIZE.X + 0.2, 0.65),
			model,
			random,
			0.6
		)
	end
	return top
end

-- The harsh lamp over the body, hung from the ceiling.
local function overheadLamp(model: Model, at: Vector3, ceilingY: number)
	local housing = Make.part({
		Name = "LampHousing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, 1.6, 1.6),
		CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(45, 50, 56),
		Ramp = "steel",
		CanCollide = false,
		Parent = model,
	})
	Make.part({
		Name = "LampBulb",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 1.3, 1.3),
		CFrame = CFrame.new(at - Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(230, 240, 255),
		Ramp = "neon",
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	local holder = Make.part({
		Name = "LampLight",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(at - Vector3.new(0, 0.3, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = model,
	})
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Brightness = 5
	spot.Range = 18
	spot.Angle = 70
	spot.Color = Color3.fromRGB(220, 235, 255)
	spot.Shadows = true
	spot.Parent = holder
	for _, x in { -0.6, 0.6 } do
		Make.rod(at + Vector3.new(x, 0.15, 0), Vector3.new(at.X + x, ceilingY, at.Z), 0.04, {
			Name = "Cable",
			Color = Color3.fromRGB(20, 20, 22),
			Ramp = "steel",
			CanCollide = false,
			Parent = housing,
		})
	end
end

-- The tool cart (right of the table, by the head), a tray of tools on it.
local function cart(model: Model, frame: CFrame): BasePart
	local body = steel({
		Name = "Cart",
		Size = Vector3.new(2.4, 0.12, 1.4),
		CFrame = frame * CFrame.new(0, 3, 0),
		Parent = model,
	})
	steel({
		Name = "CartShelf",
		Size = Vector3.new(2.3, 0.08, 1.3),
		CFrame = frame * CFrame.new(0, 1, 0),
		Parent = model,
	})
	for _, x in { -1.1, 1.1 } do
		for _, z in { -0.6, 0.6 } do
			Make.rod(
				(frame * CFrame.new(x, 0.15, z)).Position,
				(frame * CFrame.new(x, 2.95, z)).Position,
				0.09,
				{
					Name = "CartLeg",
					Material = Enum.Material.Metal,
					Color = DARK_STEEL,
					Ramp = "steel",
					Parent = model,
				}
			)
		end
	end
	local tray = steel({
		Name = "Tray",
		Size = Vector3.new(1.8, 0.06, 1.1),
		CFrame = body.CFrame * CFrame.new(0, 0.09, 0),
		Color = Color3.fromRGB(190, 195, 200),
		Reflectance = 0.3,
		Parent = model,
	})
	for _, z in { -0.55, 0.55 } do
		steel({
			Name = "TrayRim",
			Size = Vector3.new(1.8, 0.14, 0.04),
			CFrame = tray.CFrame * CFrame.new(0, 0.07, z),
			Parent = model,
		})
	end
	for _, x in { -0.9, 0.9 } do
		steel({
			Name = "TrayRim",
			Size = Vector3.new(0.04, 0.14, 1.1),
			CFrame = tray.CFrame * CFrame.new(x, 0.07, 0),
			Parent = model,
		})
	end
	-- a few tools lying on the tray (props)
	local top = tray.CFrame * CFrame.new(0, 0.05, 0)
	steel({
		Name = "PropSaw",
		Size = Vector3.new(0.9, 0.03, 0.22),
		CFrame = top * CFrame.new(-0.35, 0, -0.25),
		Parent = model,
	})
	Make.part({
		Name = "PropSawGrip",
		Size = Vector3.new(0.35, 0.08, 0.12),
		CFrame = top * CFrame.new(0.25, 0.03, -0.25),
		Color = Color3.fromRGB(25, 25, 28),
		Ramp = "rubber",
		Parent = model,
	})
	steel({
		Name = "PropForceps",
		Size = Vector3.new(0.6, 0.03, 0.04),
		CFrame = top * CFrame.new(-0.3, 0, 0.1) * CFrame.Angles(0, 0.2, 0),
		Parent = model,
	})
	steel({
		Name = "PropKnife",
		Size = Vector3.new(0.7, 0.03, 0.06),
		CFrame = top * CFrame.new(-0.2, 0, 0.3) * CFrame.Angles(0, -0.15, 0),
		Parent = model,
	})
	return tray
end

-- The articulated lamp by the cart.
local function sideLamp(model: Model, base: CFrame): Vector3
	steel({
		Name = "SideLampFoot",
		Size = Vector3.new(0.9, 0.1, 0.9),
		CFrame = base * CFrame.new(0, 0.05, 0),
		Color = DARK_STEEL,
		Parent = model,
	})
	local knee = (base * CFrame.new(0, 4.2, 0)).Position
	local headAt = (base * CFrame.new(-1.3, 5.4, 0)).Position
	Make.rod((base * CFrame.new(0, 0.1, 0)).Position, knee, 0.1, {
		Name = "SideLampArm",
		Material = Enum.Material.Metal,
		Color = DARK_STEEL,
		Ramp = "steel",
		Parent = model,
	})
	Make.rod(knee, headAt, 0.08, {
		Name = "SideLampArm",
		Material = Enum.Material.Metal,
		Color = DARK_STEEL,
		Ramp = "steel",
		Parent = model,
	})
	Make.part({
		Name = "SideLampHead",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 0.6, 0.6),
		CFrame = CFrame.new(headAt) * CFrame.Angles(0, 0, math.pi / 2),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(210, 240, 255),
		Ramp = "neon",
		CanCollide = false,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 8
	light.Color = Color3.fromRGB(210, 240, 255)
	light.Parent = model:FindFirstChild("SideLampHead")
	return headAt
end

local function stool(model: Model, base: CFrame)
	Make.part({
		Name = "StoolSeat",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 1.3, 1.3),
		CFrame = base * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(30, 30, 34),
		Ramp = "rubber",
		Parent = model,
	})
	for index = 0, 2 do
		local a = index * math.pi * 2 / 3
		Make.rod(
			(base * CFrame.new(math.cos(a) * 0.6, 0, math.sin(a) * 0.6)).Position,
			(base * CFrame.new(math.cos(a) * 0.2, 2, math.sin(a) * 0.2)).Position,
			0.08,
			{
				Name = "StoolLeg",
				Material = Enum.Material.Metal,
				Color = DARK_STEEL,
				Ramp = "steel",
				Parent = model,
			}
		)
	end
end

function Room.build(origin: Vector3, parent: Instance): Room
	local random = Random.new(1993)
	local model = Instance.new("Model")
	model.Name = "KillRoom"
	local frame = CFrame.new(origin)

	shell(model, frame, random)
	arch(model, frame)
	local top = steelTable(model, frame, random)
	-- four folding screens round the table
	screen(model, frame * CFrame.new(-2.2, 0, 4.2) * CFrame.Angles(0, math.rad(-8), 0), random)
	screen(model, frame * CFrame.new(4.6, 0, 3.4) * CFrame.Angles(0, math.rad(-35), 0), random)
	screen(model, frame * CFrame.new(-6.4, 0, -1.2) * CFrame.Angles(0, math.rad(80), 0), random)
	screen(model, frame * CFrame.new(-0.5, 0, -6.2) * CFrame.Angles(0, math.rad(175), 0), random)

	local torsoAt = (frame * CFrame.new(0.4, TABLE_Y + 0.1 + 0.03 + 0.5, 0)).Position
	-- lying face up: its front (-Z) up, its head (+Y) toward +X
	local torso = CFrame.fromMatrix(
		torsoAt,
		Vector3.new(0, 0, -1),
		Vector3.new(1, 0, 0),
		Vector3.new(0, -1, 0)
	)
	local lamp = torsoAt + Vector3.new(0, 5.5 - 0.6, 0)
	overheadLamp(model, lamp, origin.Y + HEIGHT)
	local tray = cart(model, frame * CFrame.new(2.6, 0, -2.6))
	local side = sideLamp(model, frame * CFrame.new(4.8, 0, -1.6))
	stool(model, frame * CFrame.new(-3.6, 0, 2.2))

	local exitPlate = Make.part({
		Name = "ExitDoor",
		Size = Vector3.new(3, 6.5, 0.2),
		CFrame = frame * CFrame.new(-4.5, 3.25, -DEPTH / 2 + 0.55),
		Color = Color3.fromRGB(55, 62, 68),
		Material = Enum.Material.Metal,
		Ramp = "steel",
		Parent = model,
	})

	model.Parent = parent
	return {
		model = model,
		frame = frame,
		torso = torso,
		lamp = lamp - Vector3.new(0, 0.3, 0),
		lampDown = Vector3.new(0, -1, 0),
		side = side,
		entry = frame * CFrame.new(-4.5, 3, -DEPTH / 2 + 2.5) * CFrame.Angles(0, math.pi, 0),
		stand = frame * CFrame.new(0.4, 3, -2.4) * CFrame.Angles(0, math.pi, 0),
		tableTop = top,
		tray = tray,
		exitPlate = exitPlate,
	}
end

return Room
