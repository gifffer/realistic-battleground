--!strict
-- BenchHand: the player's gloved hand and the instruments of the extraction (client only,
-- parts only, built-in materials).
--
-- THE GLOVE: a blue-grey nitrile glove (it matches the steel scalpel and trays) with a palm,
-- 4 fingers in 2 segments and a 2-segment thumb, so it can curl; a rolled cuff and a dark
-- sleeve stub that runs out of the frame toward the screen's right edge: it reads as YOUR arm.
-- The R6 body is hidden during the scene, so there is no AnimationTrack here: the hand is a
-- part rig moved every frame by the scene's own clock (roblox-animation skill: springs for
-- the pointer, authored timelines for the beats, nothing snaps).
--
-- POSES (finger curls per segment, blended over POSE_BLEND s, never snapped):
--   Open   relaxed, fingers a little spread        Pen    the scalpel in a pen grip
--   Grip   closed around an element                Press  flat, pushing a panel
--   Clip   a pinch on a retractor clip's rings
--
-- HAND SPACE: the origin is the GRIP POINT (where a held thing sits), the fingers point -Z,
-- the back of the hand is +Y, the wrist and sleeve run toward +Z. A right hand: the thumb is
-- on -X.
--
--   BenchHand.new(folder) → Hand          BenchHand.setPose(hand, pose)
--   BenchHand.place(hand, gripCFrame)     BenchHand.step(hand, dt, camera?)   BenchHand.show(hand, on)
--   BenchHand.frame(at, along, camera, pitch)  a grip CFrame at `at`, the arm coming from the
--                                              screen's bottom-right
--   BenchHand.newTool(folder, pieces) → Tool   (BenchLayout.SCALPEL / BenchLayout.CLIP)
--   BenchHand.placeTool(tool, cframe)          BenchHand.showTool(tool, on)
--   BenchHand.PEN_FROM_TIP / CLIP_FROM_TOOL    where the grip point sits on a held tool

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BenchLayout = require(ReplicatedStorage.Shared.Contraband.BenchLayout)
local Parts = require(script.Parent.Parts)

local BenchHand = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local GLOVE = rgb(70, 98, 124) -- blue-grey nitrile
local GLOVE_DARK = rgb(58, 82, 104)
local SLEEVE = rgb(78, 84, 92) -- a mid-grey sleeve (a dark one read as a black beam)
local SCALE = 0.6 -- the whole hand (as in v2: a real hand next to a 2-stud-wide torso)
local POSE_BLEND = 0.12 -- s (half-life of the curl spring)
local SLEEVE_SOLID = 1.3 -- studs of solid forearm after the cuff (then it fades out)
local SLEEVE_FADE = 0.45 -- studs of each of the two fading rings

export type PoseName = "Open" | "Pen" | "Grip" | "Press" | "Clip"

-- Per finger { curl of segment 1, curl of segment 2 } (degrees), index → little, then the
-- thumb { swing toward the palm, curl }.
type Pose = { fingers: { { number } }, thumb: { number }, spread: number }

local POSES: { [string]: Pose } = {
	Open = { fingers = { { 6, 5 }, { 6, 5 }, { 8, 6 }, { 10, 8 } }, thumb = { -30, 5 }, spread = 4 },
	Pen = {
		fingers = { { 22, 18 }, { 40, 38 }, { 70, 70 }, { 72, 72 } },
		thumb = { 2, 22 },
		spread = 1,
	},
	Grip = {
		fingers = { { 55, 65 }, { 58, 66 }, { 58, 66 }, { 60, 68 } },
		thumb = { 14, 40 },
		spread = 2,
	},
	Press = {
		fingers = { { 8, 4 }, { 8, 4 }, { 10, 5 }, { 10, 5 } },
		thumb = { -24, 6 },
		spread = 3,
	},
	Clip = {
		fingers = { { 32, 30 }, { 34, 30 }, { 52, 50 }, { 55, 52 } },
		thumb = { 4, 28 },
		spread = 1,
	},
}

-- Finger roots (hand units, before SCALE): x across the knuckles, lengths of the 2 segments.
local FINGERS = {
	{ x = -0.17, l1 = 0.17, l2 = 0.15 }, -- index (next to the thumb)
	{ x = -0.055, l1 = 0.18, l2 = 0.16 },
	{ x = 0.06, l1 = 0.17, l2 = 0.15 },
	{ x = 0.17, l1 = 0.13, l2 = 0.12 }, -- little
}
local KNUCKLE_Y = 0.16
local KNUCKLE_Z = -0.02
local PALM_CENTRE = Vector3.new(0, 0.16, 0.25)

export type Hand = {
	rig: Parts.Rig,
	parts: { BasePart },
	segments: { { a: BasePart, b: BasePart, x: number, l1: number, l2: number } },
	thumbA: BasePart,
	thumbB: BasePart,
	forearm: { { part: BasePart, at: CFrame } },
	curls: { number }, -- current: 4 × 2 finger curls, then thumb swing, thumb curl, spread
	target: { number },
	shown: boolean,
	cframe: CFrame,
}

export type Tool = {
	rig: Parts.Rig,
	parts: { BasePart },
	shown: boolean,
}

-- Where the grip point sits on a held scalpel (scalpel space: tip at the origin, handle +Z):
-- the pinch is a little behind the blade, on the handle. BenchHand.place(hand,
-- scalpel * PEN_FROM_TIP) puts the hand on it (the hand's -Z toward the tip).
BenchHand.PEN_FROM_TIP = CFrame.new(-0.04, 0.03, 0.36) -- (the blade well ahead of the fingertips)
	* CFrame.Angles(math.rad(-12), 0, math.rad(80))
-- On a held clip (clip space: hooks at the origin, rings at +Z): the pinch at the rings.
BenchHand.CLIP_FROM_TOOL = CFrame.new(0, 0.05, 0.32)
-- How far under the grip point a held element hangs (its centre).
BenchHand.HOLD_DROP = 0.04

local function flatten(pose: Pose): { number }
	local list = {}
	for _, finger in pose.fingers do
		table.insert(list, finger[1])
		table.insert(list, finger[2])
	end
	table.insert(list, pose.thumb[1])
	table.insert(list, pose.thumb[2])
	table.insert(list, pose.spread)
	return list
end

local function piece(
	folder: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	return Parts.part({
		Name = name,
		Size = size * SCALE,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Reflectance = if material == Enum.Material.Fabric then 0 else 0.06,
		Transparency = 1,
		Parent = folder,
	})
end

function BenchHand.new(folder: Instance): Hand
	local rig = Parts.newRig()
	local list: { BasePart } = {}
	local function fixed(part: BasePart, at: CFrame)
		Parts.add(rig, part, CFrame.new(at.Position * SCALE) * at.Rotation)
		table.insert(list, part)
	end
	fixed(piece(folder, "Palm", Vector3.new(0.46, 0.15, 0.48), GLOVE), CFrame.new(PALM_CENTRE))
	-- (the heel of the hand, a little thicker, toward the wrist)
	fixed(
		piece(folder, "Heel", Vector3.new(0.42, 0.17, 0.16), GLOVE_DARK),
		CFrame.new(0, 0.16, 0.48)
	)
	-- the forearm (cuff, rolled edge, sleeve): placed every frame from the wrist (step)
	local forearm: { { part: BasePart, at: CFrame } } = {}
	local function arm(part: BasePart, z: number)
		Parts.add(rig, part, CFrame.identity)
		table.insert(list, part)
		table.insert(forearm, { part = part, at = CFrame.new(0, 0, z * SCALE) })
	end
	arm(piece(folder, "Cuff", Vector3.new(0.48, 0.3, 0.14), GLOVE), 0.04)
	arm(piece(folder, "CuffRoll", Vector3.new(0.52, 0.34, 0.06), GLOVE_DARK), 0.12)
	-- (a SHORT round sleeve: a cylinder along its X, turned along the arm in step, then two
	-- short see-through rings that fade it out. A sleeve running all the way out of the frame
	-- crossed the whole shot over the work, as a plank; a box read as a plank too)
	for k, name in { "Sleeve", "SleeveFade", "SleeveFadeEnd" } do
		local sleeve =
			piece(folder, name, Vector3.new(3.2, 0.44, 0.44), SLEEVE, Enum.Material.Fabric)
		if sleeve:IsA("Part") then
			sleeve.Shape = Enum.PartType.Cylinder
		end
		sleeve:SetAttribute("Fade", ({ 0, 0.45, 0.8 })[k])
		arm(sleeve, 1.75)
	end
	local segments = {}
	for _, finger in FINGERS do
		local a = piece(folder, "Finger", Vector3.new(0.1, 0.09, finger.l1 + 0.02), GLOVE)
		local b = piece(folder, "FingerTip", Vector3.new(0.09, 0.08, finger.l2 + 0.02), GLOVE)
		Parts.add(rig, a, CFrame.identity)
		Parts.add(rig, b, CFrame.identity)
		table.insert(list, a)
		table.insert(list, b)
		table.insert(segments, { a = a, b = b, x = finger.x, l1 = finger.l1, l2 = finger.l2 })
	end
	local thumbA = piece(folder, "Thumb", Vector3.new(0.11, 0.1, 0.16), GLOVE)
	local thumbB = piece(folder, "ThumbTip", Vector3.new(0.1, 0.09, 0.14), GLOVE)
	Parts.add(rig, thumbA, CFrame.identity)
	Parts.add(rig, thumbB, CFrame.identity)
	table.insert(list, thumbA)
	table.insert(list, thumbB)
	local open = flatten(POSES.Open)
	local hand: Hand = {
		rig = rig,
		parts = list,
		segments = segments,
		thumbA = thumbA,
		thumbB = thumbB,
		forearm = forearm,
		curls = table.clone(open),
		target = open,
		shown = false,
		cframe = CFrame.identity,
	}
	return hand
end

function BenchHand.setPose(hand: Hand, pose: PoseName)
	hand.target = flatten(POSES[pose])
end

function BenchHand.place(hand: Hand, grip: CFrame)
	hand.cframe = grip
end

function BenchHand.show(hand: Hand, on: boolean)
	if hand.shown == on then
		return
	end
	hand.shown = on
	for _, part in hand.parts do
		local fade = part:GetAttribute("Fade")
		part.Transparency = if not on then 1 elseif typeof(fade) == "number" then fade else 0
	end
end

-- Rebuilds the finger locals from the (blended) curls and moves the rig.
function BenchHand.step(hand: Hand, dt: number, camera: CFrame?, fov: number?)
	local k = 1 - 2 ^ (-dt / POSE_BLEND)
	for i, wanted in hand.target do
		hand.curls[i] += (wanted - hand.curls[i]) * k
	end
	local c = hand.curls
	local spread = math.rad(c[11])
	for i, segment in hand.segments do
		local yaw = spread * (i - 2.5) * -1
		local knuckle = CFrame.new(segment.x * SCALE, KNUCKLE_Y * SCALE, KNUCKLE_Z * SCALE)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(-math.rad(c[i * 2 - 1]), 0, 0)
		Parts.setLocal(hand.rig, segment.a, knuckle * CFrame.new(0, 0, -segment.l1 * SCALE / 2))
		local joint = knuckle
			* CFrame.new(0, 0, -segment.l1 * SCALE)
			* CFrame.Angles(-math.rad(c[i * 2]), 0, 0)
		Parts.setLocal(hand.rig, segment.b, joint * CFrame.new(0, 0, -segment.l2 * SCALE / 2))
	end
	-- the thumb: from the palm's side, swinging under the palm (opposition) and curling
	local swing = math.rad(c[9])
	local base = CFrame.new(-0.24 * SCALE, 0.1 * SCALE, 0.2 * SCALE)
		* CFrame.Angles(0, math.rad(40) - swing * 0.6, 0)
		* CFrame.Angles(-math.rad(25) - swing * 0.5, 0, 0)
	Parts.setLocal(hand.rig, hand.thumbA, base * CFrame.new(0, 0, -0.08 * SCALE))
	local tip = base * CFrame.new(0, 0, -0.16 * SCALE) * CFrame.Angles(-math.rad(c[10]), 0, 0)
	Parts.setLocal(hand.rig, hand.thumbB, tip * CFrame.new(0, 0, -0.07 * SCALE))
	-- the forearm runs from the wrist to YOUR shoulder, just out of the frame at the bottom
	-- right (first person: it always leaves the screen, it never floats); without a camera,
	-- almost level (rising 8°) away from the fingers
	local grip = hand.cframe
	local wrist = grip * (Vector3.new(0, 0.17, 0.55) * SCALE)
	local direction: Vector3
	local length = 3.2 * SCALE
	if camera then
		-- First person: the forearm points from the wrist toward the BOTTOM edge of the screen,
		-- right of centre (toward your own body). That point is taken closer to the camera
		-- than the wrist (3/4 of its depth), so the sleeve rises toward you, foreshortened.
		-- Only 1.3 studs of it are solid, then it fades out over 0.9: it never runs across the
		-- whole frame over the work (a long beam to a far shoulder hid the trays).
		local depth = math.max((wrist - camera.Position):Dot(camera.LookVector), 0.5)
		local exitDepth = depth * 0.75
		local tanV = math.tan(math.rad((fov or 40) / 2))
		local exit = camera.Position
			+ camera.LookVector * exitDepth
			+ camera.RightVector * (exitDepth * tanV * 0.8)
			- camera.UpVector * (exitDepth * tanV * 1.25)
		local reach = exit - wrist
		direction = reach.Unit
		length = math.clamp(reach.Magnitude + 0.3, 0.8, 4)
	else
		local back = -grip.LookVector
		local flat = Vector3.new(back.X, 0, back.Z)
		direction = ((if flat.Magnitude > 1e-3 then flat.Unit else back) + Vector3.yAxis * 0.14).Unit
	end
	-- (only the first stretch is drawn solid: see the sleeve pieces in new)
	length = math.min(length, SLEEVE_SOLID)
	local frame = CFrame.lookAt(wrist, wrist - direction)
	local inverse = grip:Inverse()
	for _, item in hand.forearm do
		local at = item.at
		local name = item.part.Name
		if name == "Sleeve" or name == "SleeveFade" or name == "SleeveFadeEnd" then
			-- the solid sleeve, then the two fading rings after it, end to end
			local size = if name == "Sleeve" then length else SLEEVE_FADE
			local from = 0.16 * SCALE
				+ (
					if name == "Sleeve"
						then 0
						elseif name == "SleeveFade" then length
						else length + SLEEVE_FADE
				)
			if math.abs(item.part.Size.X - size) > 0.01 then
				item.part.Size = Vector3.new(size, item.part.Size.Y, item.part.Size.Z)
			end
			-- (the cylinder's axis is its X: turned to run along the arm, +Z)
			at = CFrame.new(0, 0, from + size / 2) * CFrame.Angles(0, math.rad(90), 0)
		end
		Parts.setLocal(hand.rig, item.part, inverse * frame * at)
	end
	Parts.place(hand.rig, grip)
end

-- A grip CFrame at `at` (world) for a hand whose arm comes in from the bottom-right of the
-- screen (about 48° to the side, never covering what it works on), the fingers pitched down
-- by `pitch` degrees.
function BenchHand.frame(at: Vector3, camera: CFrame, pitch: number, up: Vector3?): CFrame
	local worldUp = up or Vector3.yAxis
	local toCamera = camera.Position - at
	toCamera -= worldUp * toCamera:Dot(worldUp)
	local back = if toCamera.Magnitude > 1e-3 then toCamera.Unit else -camera.LookVector
	local side = camera.RightVector - worldUp * camera.RightVector:Dot(worldUp)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	local angle = math.rad(48) -- (about the way the sleeve runs to your shoulder: see step)
	local arm = (back * math.cos(angle) + side * math.sin(angle)).Unit -- fingers → wrist
	return CFrame.lookAt(at, at - arm, worldUp) * CFrame.Angles(-math.rad(pitch), 0, 0)
end

-- The arm's direction (fingers → wrist, flat) for that same frame.
function BenchHand.armDirection(at: Vector3, camera: CFrame): Vector3
	local frame = BenchHand.frame(at, camera, 0)
	return frame.LookVector * -1
end

------------------------------------------------------------------------------
-- Instruments
------------------------------------------------------------------------------

function BenchHand.newTool(folder: Instance, pieces: { BenchLayout.Piece }): Tool
	local rig = Parts.newRig()
	local list: { BasePart } = {}
	for _, item in pieces do
		local part: BasePart
		if item.shape == "Wedge" then
			part = Instance.new("WedgePart")
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Locked = true
		else
			part = Parts.part({})
			if item.shape == "Cylinder" then
				(part :: Part).Shape = Enum.PartType.Cylinder
			end
		end
		part.Name = item.name
		part.Size = item.size
		part.Color = item.color
		part.Material = item.material
		part.Reflectance = item.reflectance
		part.Transparency = 1
		part.Parent = folder
		Parts.add(rig, part, item.at)
		table.insert(list, part)
	end
	return { rig = rig, parts = list, shown = false }
end

function BenchHand.placeTool(tool: Tool, cframe: CFrame)
	Parts.place(tool.rig, cframe)
end

function BenchHand.showTool(tool: Tool, on: boolean)
	if tool.shown == on then
		return
	end
	tool.shown = on
	for _, part in tool.parts do
		part.Transparency = if on then 0 else 1
	end
end

return BenchHand
