--!strict
-- CloneModel: the synthetic clone growing in the lab vat, built from parts (ART_V2 §5).
--
-- Three looks, two changes:
--   MATRIX (0–25 %)  a steel scaffold rod + 3 rings with 5 amber gel lobes clustered on it.
--                    No limbs, no head. The lobes swell from 0.6 to 1.0 of their size.
--   FRAME (25–75 %)  an ADULT-sized R6 lattice of thin white bars (5 boxes × 12 edges, each
--                    box inset so the limbs read apart, 3 ribs per limb, the arms opened 5°,
--                    the head a cage of 3 rings), there at full size at once, filling with
--                    milky gel from the feet up.
--   SHELL (75–100 %) a finished pearl-grey synthetic body: smooth faceless head with a
--                    mould seam, panel seams, a steel chest port with an LED, the stencil
--                    "SYN-04 NO ID". It fades in (transparency 0.6 → 0) across the stage.
-- Held by a spine rod and two cables at the BACK (never straps). It never moves a limb, never
-- breathes, makes no sound: it only drifts a little with the fluid. No face, never small,
-- no blood, no anatomy.
--
-- Space: the clone's root is the vat's centre (VatCore). The clone stands on local Y, faces
-- local -Z (the vat screen side), feet at y = -2.5, head top at y = 2.7 (R6 adult: torso
-- 2×2×1, arms / legs 1×2×1, head ~1.2).
--
--   CloneModel.new(parent)                         → Clone
--   CloneModel.update(clone, stage, t, visible, led, now)
--        stage "MATRIX" | "FRAME" | "SHELL" | "NONE"; t = progress inside the stage (0..1);
--        visible 0..1 (fades for the phase shift); led "growing" | "ready" | "off"
--   CloneModel.place(clone, root)                  moves it (root = VatCore CFrame + drift)
--   CloneModel.destroy(clone)
--   CloneModel.buildShell(rig, parent, cavity)      the SHELL body alone (BenchVisual reuses it)
--   CloneModel.LAYOUT, CloneModel.COLORS           the shared sizes and colours

local Parts = require(script.Parent.Parts)

local CloneModel = {}

export type Stage = "MATRIX" | "FRAME" | "SHELL" | "NONE"
export type Led = "growing" | "ready" | "off"

type Item = { part: BasePart, base: number } -- a part and its designed transparency

export type Clone = {
	model: Model,
	rig: Parts.Rig,
	matrix: { Item },
	lobes: { { part: BasePart, size: Vector3 } },
	frame: { Item },
	fills: { { part: BasePart, box: Box } },
	support: { Item },
	shell: { Item },
	led: BasePart?,
	stencil: TextLabel?,
	-- what was last written (to skip identical writes)
	lastKey: string,
}

export type Box = { name: string, centre: Vector3, size: Vector3 }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

CloneModel.COLORS = table.freeze({
	pearl = rgb(200, 198, 192), -- the shell
	seam = rgb(60, 60, 64), -- (dark enough to draw the body against the pale fluid)
	port = rgb(150, 152, 156),
	stencil = rgb(60, 60, 64),
	wire = rgb(225, 228, 230),
	gel = rgb(232, 234, 228), -- milky gel (FRAME fill, membranes, droplets)
	amber = rgb(210, 140, 50), -- MATRIX lobes
	amberPin = rgb(255, 190, 90),
	steel = rgb(120, 124, 128),
	cable = rgb(30, 30, 32),
	ledGrowing = rgb(255, 170, 70),
	ledReady = rgb(120, 220, 200),
})
local C = CloneModel.COLORS

-- The six R6 boxes, standing, in the clone's space (head as a box for the lattice).
local BOXES: { Box } = {
	{ name = "Torso", centre = Vector3.new(0, 0.5, 0), size = Vector3.new(2, 2, 1) },
	{ name = "LeftArm", centre = Vector3.new(-1.5, 0.5, 0), size = Vector3.new(1, 2, 1) },
	{ name = "RightArm", centre = Vector3.new(1.5, 0.5, 0), size = Vector3.new(1, 2, 1) },
	{ name = "LeftLeg", centre = Vector3.new(-0.5, -1.5, 0), size = Vector3.new(1, 2, 1) },
	{ name = "RightLeg", centre = Vector3.new(0.5, -1.5, 0), size = Vector3.new(1, 2, 1) },
	{ name = "Head", centre = Vector3.new(0, 2.1, 0), size = Vector3.new(1.2, 1.2, 1.2) },
}

CloneModel.LAYOUT = table.freeze({
	FEET = -2.5,
	TOP = 2.7,
	HEIGHT = 5.2,
	BOXES = BOXES,
	HEAD_DIAMETER = 1.15,
})

local WIRE = 0.06
local FRAME_INSET = 0.08 -- studs each FRAME box is shrunk by on every side (gaps between limbs)
local FRAME_ARM_OPEN = 5 -- degrees the FRAME arms are opened away from the torso
local FRAME_RIBS = 3 -- horizontal ribs per FRAME limb

-- Where a FRAME box sits (clone space): its centre, the arms turned out around the shoulder.
local function frameBoxCFrame(box: Box): CFrame
	local side = if box.name == "LeftArm" then -1 elseif box.name == "RightArm" then 1 else 0
	if side == 0 then
		return CFrame.new(box.centre)
	end
	local shoulder =
		Vector3.new(box.centre.X - side * box.size.X / 2, box.centre.Y + box.size.Y / 2, 0)
	return CFrame.new(shoulder)
		* CFrame.Angles(0, 0, math.rad(FRAME_ARM_OPEN * side))
		* CFrame.new(box.centre - shoulder)
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function track(list: { Item }, rig: Parts.Rig, part: BasePart, localCFrame: CFrame)
	Parts.add(rig, part, localCFrame)
	table.insert(list, { part = part, base = part.Transparency })
end

-- The shell body (SHELL look). `cavity` = the torso is open on the chest (the bench version:
-- a hatch hole 1.2 × 1.2, a cavity 0.65 deep) and has no chest port (BenchVisual adds the
-- hatch). Adds the parts to `rig` (standing space) and returns them.
function CloneModel.buildShell(rig: Parts.Rig, parent: Instance, cavity: boolean): { Item }
	local items: { Item } = {}
	local function body(name: string, size: Vector3, at: CFrame, color: Color3?)
		local part = Parts.part({
			Name = name,
			Size = size,
			Color = color or C.pearl,
			Reflectance = 0.15,
			Parent = parent,
		})
		track(items, rig, part, at)
		return part
	end
	local function seam(size: Vector3, at: Vector3)
		local part = Parts.part({
			Name = "Seam",
			Size = size,
			Color = C.seam,
			Parent = parent,
		})
		track(items, rig, part, CFrame.new(at))
	end

	-- Limbs.
	for _, box in BOXES do
		if box.name ~= "Torso" and box.name ~= "Head" then
			body(box.name, box.size, CFrame.new(box.centre))
		end
	end
	-- Torso.
	if cavity then
		-- back slab + 4 walls around the 1.2 × 1.2 opening on the chest (front = -Z)
		body("TorsoBack", Vector3.new(2, 2, 0.35), CFrame.new(0, 0.5, 0.325))
		body("TorsoWallL", Vector3.new(0.4, 2, 0.65), CFrame.new(-0.8, 0.5, -0.175))
		body("TorsoWallR", Vector3.new(0.4, 2, 0.65), CFrame.new(0.8, 0.5, -0.175))
		body("TorsoWallT", Vector3.new(1.2, 0.4, 0.65), CFrame.new(0, 1.3, -0.175))
		body("TorsoWallB", Vector3.new(1.2, 0.4, 0.65), CFrame.new(0, -0.3, -0.175))
	else
		body("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 0.5, 0))
	end
	-- Head: a short vertical cylinder with two flattened domes = the rounded R6 head shape,
	-- smooth, NO face. A vertical mould seam down the front.
	local d = CloneModel.LAYOUT.HEAD_DIAMETER
	local headY = 2.1
	local headPart =
		Parts.disc(d, 0.72, { Name = "Head", Color = C.pearl, Reflectance = 0.15, Parent = parent })
	track(items, rig, headPart, CFrame.new(0, headY, 0) * Parts.UPRIGHT)
	for _, side in { -1, 1 } do
		local dome = Parts.ellipsoid(Vector3.new(d, 0.42, d), {
			Name = "HeadDome",
			Color = C.pearl,
			Reflectance = 0.15,
			Parent = parent,
		})
		track(items, rig, dome, CFrame.new(0, headY + side * 0.36, 0))
	end
	seam(Vector3.new(0.03, 0.95, 0.02), Vector3.new(0, headY, -d / 2 + 0.005))
	-- Neck seam: a dark collar between head and torso.
	local neck = Parts.disc(0.8, 0.08, { Name = "NeckSeam", Color = C.seam, Parent = parent })
	track(items, rig, neck, CFrame.new(0, 1.52, 0) * Parts.UPRIGHT)
	-- Panel seams on the front: shoulders, hips, chest midline (where there is no hole).
	for _, side in { -1, 1 } do
		seam(Vector3.new(0.96, 0.03, 0.02), Vector3.new(side * 1.5, 1.28, -0.505))
		seam(Vector3.new(0.96, 0.03, 0.02), Vector3.new(side * 0.5, -0.52, -0.505))
	end
	if not cavity then
		seam(Vector3.new(0.03, 0.25, 0.02), Vector3.new(0, 1.37, -0.505))
		seam(Vector3.new(0.03, 0.4, 0.02), Vector3.new(0, -0.27, -0.505))
		-- Chest port: a steel plate with 4 screws and the LED (BenchVisual has a hatch instead).
		local plate = Parts.part({
			Name = "ChestPort",
			Size = Vector3.new(0.8, 0.8, 0.05),
			Material = Enum.Material.Metal,
			Color = C.port,
			Reflectance = 0.1,
			Parent = parent,
		})
		track(items, rig, plate, CFrame.new(0, 0.85, -0.52))
		for _, corner in
			{ Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) }
		do
			local screw = Parts.disc(0.07, 0.03, {
				Name = "Screw",
				Material = Enum.Material.Metal,
				Color = rgb(96, 98, 102),
				Parent = parent,
			})
			track(
				items,
				rig,
				screw,
				CFrame.new(corner.X * 0.31, 0.85 + corner.Y * 0.31, -0.55)
					* CFrame.Angles(0, math.rad(90), 0)
			)
		end
	end
	-- Back port (where the cables plug in).
	local back = Parts.part({
		Name = "BackPort",
		Size = Vector3.new(0.6, 0.6, 0.05),
		Material = Enum.Material.Metal,
		Color = C.port,
		Parent = parent,
	})
	track(items, rig, back, CFrame.new(0, 0.9, 0.52))
	-- The stencil "SYN-04 NO ID" (text on a thin see-through plate). Chest under the port, or,
	-- with a cavity, on the wall under the hole.
	-- (on the bench the chest is a hatch: the text runs along the right thigh instead, turned
	-- so it reads left to right with the shell lying down)
	local stencilAt = if cavity
		then CFrame.new(0.5, -1.45, -0.505) * CFrame.Angles(0, 0, math.rad(90))
		else CFrame.new(0, 0.12, -0.505)
	local stencil = Parts.part({
		Name = "Stencil",
		Size = if cavity then Vector3.new(1.5, 0.26, 0.01) else Vector3.new(1.2, 0.32, 0.01),
		Transparency = 1,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "StencilGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 1
	gui.Parent = stencil
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "SYN-04  NO ID"
	label.TextColor3 = C.stencil
	label.TextScaled = true
	label.Font = Enum.Font.RobotoMono
	label.Parent = gui
	track(items, rig, stencil, stencilAt)
	-- (the stencil plate itself must stay invisible whatever the fade)
	items[#items].base = 1
	return items
end

function CloneModel.new(parent: Instance): Clone
	local model = Instance.new("Model")
	model.Name = "VatClone"
	local rig = Parts.newRig()
	local clone: Clone = {
		model = model,
		rig = rig,
		matrix = {},
		lobes = {},
		frame = {},
		fills = {},
		support = {},
		shell = {},
		led = nil,
		stencil = nil,
		lastKey = "",
	}

	-- MATRIX: scaffold rod, 3 rings, 5 gel lobes, a warm pinpoint in the biggest lobe.
	local rod = Parts.disc(0.3, 6, {
		Name = "ScaffoldRod",
		Material = Enum.Material.Metal,
		Color = C.steel,
		Parent = model,
	})
	track(clone.matrix, rig, rod, Parts.UPRIGHT)
	for _, y in { -1.4, 0.2, 1.8 } do
		for _, part in
			Parts.ring(rig, CFrame.new(0, y, 0), 0.8, 0.08, 10, {
				Name = "ScaffoldRing",
				Material = Enum.Material.Metal,
				Color = C.steel,
				Parent = model,
			})
		do
			table.insert(clone.matrix, { part = part, base = 0 })
		end
	end
	local LOBES = {
		{ at = Vector3.new(0.25, -0.55, -0.2), d = 1.6 },
		{ at = Vector3.new(-0.38, 0.35, 0.12), d = 1.3 },
		{ at = Vector3.new(0.22, 0.95, 0.3), d = 1.1 },
		{ at = Vector3.new(-0.22, -1.25, 0.28), d = 1.2 },
		{ at = Vector3.new(0.4, 0.3, -0.42), d = 1.0 },
	}
	for i, lobe in LOBES do
		local size = Vector3.new(lobe.d, lobe.d * 0.86, lobe.d * 0.92)
		local part = Parts.ellipsoid(size, {
			Name = "GelLobe",
			Color = C.amber,
			Transparency = 0.35,
			Reflectance = 0.1,
			Parent = model,
		})
		track(clone.matrix, rig, part, CFrame.new(lobe.at) * CFrame.Angles(0, i * 0.9, i * 0.3))
		table.insert(clone.lobes, { part = part, size = size })
	end
	local pin = Parts.ball(0.08, {
		Name = "MatrixPin",
		Material = Enum.Material.Neon,
		Color = C.amberPin,
		Parent = model,
	})
	track(clone.matrix, rig, pin, CFrame.new(LOBES[1].at))

	-- FRAME: an open lattice per box (each box inset FRAME_INSET so the limbs read apart, the
	-- arms opened FRAME_ARM_OPEN° from the torso), horizontal ribs on the limbs, a cage of 3
	-- rings for the head; plus one gel fill per box (resized every update).
	local function frameBar(size: Vector3, at: CFrame)
		local bar = Parts.part({
			Name = "Lattice",
			Size = size,
			Color = C.wire,
			Reflectance = 0.05,
			Parent = model,
		})
		track(clone.frame, rig, bar, at)
	end
	for _, box in BOXES do
		local pose = frameBoxCFrame(box)
		local isHead = box.name == "Head"
		local inner = box.size - Vector3.one * (FRAME_INSET * 2)
		local h = inner / 2
		if isHead then
			-- the head: 2 vertical rings and 1 horizontal ring (a cage, not a cube)
			local radius = CloneModel.LAYOUT.HEAD_DIAMETER / 2
			for _, turn in
				{
					CFrame.identity,
					CFrame.Angles(math.rad(90), 0, 0),
					CFrame.Angles(0, 0, math.rad(90)),
				}
			do
				for _, part in
					Parts.ring(rig, pose * turn, radius, WIRE, 12, {
						Name = "Lattice",
						Color = C.wire,
						Reflectance = 0.05,
						Parent = model,
					})
				do
					table.insert(clone.frame, { part = part, base = part.Transparency })
				end
			end
		else
			-- 4 edges along each axis
			for _, axis in { "X", "Y", "Z" } do
				for _, a in { -1, 1 } do
					for _, b in { -1, 1 } do
						if axis == "X" then
							frameBar(
								Vector3.new(inner.X + WIRE, WIRE, WIRE),
								pose * CFrame.new(0, a * h.Y, b * h.Z)
							)
						elseif axis == "Y" then
							frameBar(
								Vector3.new(WIRE, inner.Y + WIRE, WIRE),
								pose * CFrame.new(a * h.X, 0, b * h.Z)
							)
						else
							frameBar(
								Vector3.new(WIRE, WIRE, inner.Z + WIRE),
								pose * CFrame.new(a * h.X, b * h.Y, 0)
							)
						end
					end
				end
			end
			-- horizontal ribs on the limbs (a frame, not a glass box)
			if box.name ~= "Torso" then
				for rib = 1, FRAME_RIBS do
					local y = -h.Y + rib * inner.Y / (FRAME_RIBS + 1)
					for _, b in { -1, 1 } do
						frameBar(
							Vector3.new(inner.X + WIRE, WIRE * 0.7, WIRE * 0.7),
							pose * CFrame.new(0, y, b * h.Z)
						)
						frameBar(
							Vector3.new(WIRE * 0.7, WIRE * 0.7, inner.Z + WIRE),
							pose * CFrame.new(b * h.X, y, 0)
						)
					end
				end
			end
		end
		local fillScale = if isHead then 0.62 else 1
		local fill = Parts.part({
			Name = "GelFill",
			Size = Vector3.new(inner.X * fillScale - 0.06, 0.05, inner.Z * fillScale - 0.06),
			Color = C.gel,
			Transparency = 0.35,
			Reflectance = 0.05,
			Parent = model,
		})
		Parts.add(rig, fill, pose)
		table.insert(clone.fills, { part = fill, box = box })
	end

	-- Support (FRAME and SHELL): spine rod behind the back, a bracket, two cables up to the cap.
	local spine, spineCFrame =
		Parts.rod(Vector3.new(0, -1.6, 0.85), Vector3.new(0, 4.4, 0.85), 0.25, {
			Name = "SpineRod",
			Material = Enum.Material.Metal,
			Color = C.steel,
			Parent = model,
		})
	track(clone.support, rig, spine, spineCFrame)
	local bracket, bracketCFrame =
		Parts.rod(Vector3.new(0, 0.9, 0.5), Vector3.new(0, 0.9, 0.85), 0.18, {
			Name = "Bracket",
			Material = Enum.Material.Metal,
			Color = C.steel,
			Parent = model,
		})
	track(clone.support, rig, bracket, bracketCFrame)
	for _, side in { -1, 1 } do
		local cable, cableCFrame = Parts.rod(
			Vector3.new(side * 0.2, 0.95, 0.55),
			Vector3.new(side * 0.75, 4.3, 0.95),
			0.12,
			{ Name = "Cable", Color = C.cable, Parent = model }
		)
		track(clone.support, rig, cable, cableCFrame)
	end

	-- SHELL.
	clone.shell = CloneModel.buildShell(rig, model, false)
	local led = Parts.ball(0.08, {
		Name = "PortLed",
		Material = Enum.Material.Neon,
		Color = C.ledGrowing,
		Parent = model,
	})
	track(clone.shell, rig, led, CFrame.new(0.3, 1.15, -0.56))
	clone.led = led
	local stencilText = model:FindFirstChild("Text", true)
	if stencilText and stencilText:IsA("TextLabel") then
		clone.stencil = stencilText
	end

	model.Parent = parent
	return clone
end

------------------------------------------------------------------------------
-- Updating
------------------------------------------------------------------------------

local function setGroup(items: { Item }, visible: number)
	for _, item in items do
		local value = Parts.fade(item.base, visible)
		if item.part.Transparency ~= value then
			item.part.Transparency = value
		end
	end
end

-- Shows `stage` at progress `t` (0..1 inside the stage), faded by `visible` (0..1).
function CloneModel.update(
	clone: Clone,
	stage: Stage,
	t: number,
	visible: number,
	led: Led,
	now: number
)
	t = math.clamp(t, 0, 1)
	visible = math.clamp(visible, 0, 1)
	-- (rounded key: nothing to write when nothing visible changed)
	local key = string.format("%s|%.3f|%.2f|%s", stage, t, visible, led)
	local ledBlink = stage == "SHELL" and led == "growing"
	if key == clone.lastKey and not ledBlink then
		return
	end
	clone.lastKey = key

	setGroup(clone.matrix, if stage == "MATRIX" then visible else 0)
	setGroup(clone.frame, if stage == "FRAME" then visible else 0)
	setGroup(clone.support, if stage == "FRAME" or stage == "SHELL" then visible else 0)

	-- MATRIX: lobes swell from 0.6 to 1.0.
	if stage == "MATRIX" then
		local scale = 0.6 + 0.4 * t
		for _, lobe in clone.lobes do
			lobe.part.Size = lobe.size * scale
		end
	end

	-- FRAME: each box's gel fill rises to the fill line (from the feet up).
	local fillY = CloneModel.LAYOUT.FEET + t * CloneModel.LAYOUT.HEIGHT
	for _, fill in clone.fills do
		local box = fill.box
		local isHead = box.name == "Head"
		local fillScale = if isHead then 0.62 else 1
		local inner = box.size - Vector3.one * (FRAME_INSET * 2)
		local full = inner.Y * fillScale - 0.06
		local bottom = box.centre.Y - full / 2
		local height = math.min(fillY - bottom, full)
		if stage ~= "FRAME" or height <= 0.01 then
			fill.part.Transparency = 1
		else
			fill.part.Transparency = Parts.fade(0.35, visible)
			fill.part.Size =
				Vector3.new(inner.X * fillScale - 0.06, height, inner.Z * fillScale - 0.06)
			-- (in the box's own space: an opened arm's gel follows the arm)
			Parts.setLocal(
				clone.rig,
				fill.part,
				frameBoxCFrame(box) * CFrame.new(0, -full / 2 + height / 2, 0)
			)
		end
	end

	-- SHELL: fades in from 0.6 transparency to solid across the stage.
	local shellVisible = 0
	if stage == "SHELL" then
		shellVisible = visible * (1 - 0.6 * (1 - t)) -- 0.4 .. 1 opacity across the stage
	end
	setGroup(clone.shell, shellVisible)
	local stencil = clone.stencil
	if stencil then
		-- (a SurfaceGui shows on an invisible part: fade its text by hand)
		stencil.TextTransparency = 1 - shellVisible
	end
	local ledPart = clone.led
	if ledPart and stage == "SHELL" then
		if led == "ready" then
			ledPart.Color = C.ledReady
			ledPart.Transparency = Parts.fade(0, visible)
		elseif led == "growing" then
			ledPart.Color = C.ledGrowing
			-- a slow amber blink while it grows
			local on = math.sin(now * math.pi) > 0
			ledPart.Transparency = Parts.fade(if on then 0 else 0.7, visible)
		else
			ledPart.Transparency = 1
		end
	end
end

function CloneModel.place(clone: Clone, root: CFrame)
	Parts.place(clone.rig, root)
end

function CloneModel.destroy(clone: Clone)
	clone.model:Destroy()
end

return CloneModel
