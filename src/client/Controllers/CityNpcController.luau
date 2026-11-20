--!strict
-- CityNpcController: brings the city's NPCs to life on YOUR screen (Server/Systems/CityNpcs
-- only puts them, standing, on their spots: Workspace > City > Npcs).
--
-- For each NPC (a blocky R6 body with the attribute Npc = true) this controller:
--   • holds its POSE (attribute NpcPose) with a small looping clip, written into the 6
--     joints of the R6 rig every frame, with the same code-made animation system as the
--     players (Client/Animation/R6Pose):
--        Idle         standing, breathing, shifting a little
--        WipeCounter  leaning over the counter, the right hand wiping in circles with a rag
--        LeanBar      both forearms on the bar, leaning forward
--        SitStool     sitting on a stool (attributes SeatHeight, SeatBack)
--        ArmsCrossed  standing, arms crossed, weight on one leg
--        Phone        looking down at a phone held in front of the face
--        SitGround    sitting on the floor, back against a wall, legs stretched out under a
--                     blanket, the hands on it at the knees (or the right hand held out with a
--                     paper cup of coins: SitGroundCup), breathing slowly, on a flattened
--                     cardboard box (the vagrant of the alleys: his things around him, see
--                     addSquat)
--     (an unknown pose name gets Idle);
--   • turns the HEAD towards the closest player within HEAD_RANGE studs (smoothly, never
--     further than HEAD_MAX_YAW), and now and then looks around when nobody is there;
--   • says ONE line in a chat bubble when you walk up to a clerk, the bartender, the dealer
--     or the vagrant of the alleys (and sometimes a patron), then not again for a while.
--     The dealer keeps glancing around, more often than the others.
-- Only the NPCs near your camera are animated (ANIMATE_RANGE): the others freeze where they
-- are. Nothing here is sent to the server.
--
-- The rag, the phone, the paper cup, the cardboard, the blanket and the vagrant's things
-- (his sign, backpack, book, coins) are small parts created here, on your screen only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local R6Pose = require(script.Parent.Parent.Animation.R6Pose)

local CityNpcController = {}

local ANIMATE_RANGE = 140 -- studs from the camera
local HEAD_RANGE = 12 -- studs: closer players get looked at
local HEAD_MAX_YAW = 55 -- degrees, left or right
local HEAD_TURN_SPEED = 4 -- how fast the head follows (higher = snappier)
local GREET_RANGE = 8 -- studs: you get a line when you come this close...
local GREET_RESET_RANGE = 14 -- ...and only again after going this far away
local GREET_COOLDOWN = 40 -- and this many seconds later at the earliest
local PATRON_TALK_CHANCE = 0.35 -- patrons don't always bother

-- What they say (English, in-game). Clerks by the shop they work in.
local LINES: { [string]: { string } } = {
	Bartender = {
		"What'll it be?",
		"Bar's open. Keep the fists outside.",
		"Wipe your feet, champ.",
	},
	ClerkOutfit = { "Fresh threads, cheap.", "Looking for something?", "Mirror's in the back." },
	ClerkEmote = {
		"Got moves? Pick one.",
		"Looking for something?",
		"Tapes on the left, moves on the right.",
	},
	Clerk = { "Looking for something?" },
	Patron = { "...", "You lost, pal?", "Mind your business.", "Seen a train come through yet?" },
	-- the black market's fence (stolen goods)
	Dealer = {
		"Not here. Over there.",
		"Cash only.",
		"You didn't see me.",
		"Buying or looking? Looking costs.",
		"Fell off a truck. Don't ask.",
		"Keep your voice down.",
	},
	-- the man of the squat
	Vagrant = {
		"Spare some change...?",
		"Got a smoke, pal?",
		"Anything helps... anything.",
		"...cold one tonight...",
		"Don't touch my stuff.",
		"Trains don't stop here no more...",
	},
}

local player = Players.LocalPlayer

------------------------------------------------------------------------------
-- The poses (degrees, in the parent part's space, see Client/Animation/MovementClips):
--   rot.X > 0 swings an arm / leg FORWARD, and tilts the torso / head BACK.
--   Right arm: rot.Z < 0 brings it towards the body's middle; left arm: rot.Z > 0.
--   Root.pos moves the whole body (Y = up, Z = backwards).
------------------------------------------------------------------------------

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- SitGroundCup: how far forward the right arm is swung (degrees), holding out the cup.
local CUP_ARM = 64

local CLIPS: { [string]: R6Pose.Clip } = {
	Idle = {
		length = 4.2,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = v(0, 0, 0), pos = v(0, 0, 0) },
					Neck = { rot = v(-2, 0, 0) },
					RightShoulder = { rot = v(2, 0, 5) },
					LeftShoulder = { rot = v(2, 0, -5) },
					RightHip = { rot = v(0, 0, 2) },
					LeftHip = { rot = v(0, 0, -2) },
				},
			},
			{
				time = 2.1,
				pose = {
					Root = { rot = v(1, 0, 1.5), pos = v(0, 0.04, 0) },
					Neck = { rot = v(-3, 0, -1) },
					RightShoulder = { rot = v(-2, 0, 6) },
					LeftShoulder = { rot = v(4, 0, -6) },
					RightHip = { rot = v(0, 0, 3.5) },
					LeftHip = { rot = v(0, 0, -0.5) },
				},
			},
		},
	},

	WipeCounter = {
		length = 1.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = v(-9, 0, 0), pos = v(0, -0.05, 0) },
					Neck = { rot = v(-12, 0, 0) },
					RightShoulder = { rot = v(62, 0, -10) },
					LeftShoulder = { rot = v(52, 0, 12) },
					RightHip = { rot = v(8, 0, 3) },
					LeftHip = { rot = v(8, 0, -3) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = v(-10, 3, 0), pos = v(0, -0.06, 0) },
					Neck = { rot = v(-13, -3, 0) },
					RightShoulder = { rot = v(68, 0, -26) },
					LeftShoulder = { rot = v(52, 0, 12) },
					RightHip = { rot = v(8, 0, 3) },
					LeftHip = { rot = v(8, 0, -3) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = v(-9, 0, 0), pos = v(0, -0.05, 0) },
					Neck = { rot = v(-12, 0, 0) },
					RightShoulder = { rot = v(58, 0, -14) },
					LeftShoulder = { rot = v(52, 0, 12) },
					RightHip = { rot = v(8, 0, 3) },
					LeftHip = { rot = v(8, 0, -3) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = { rot = v(-8, -3, 0), pos = v(0, -0.04, 0) },
					Neck = { rot = v(-11, 3, 0) },
					RightShoulder = { rot = v(64, 0, 4) },
					LeftShoulder = { rot = v(52, 0, 12) },
					RightHip = { rot = v(8, 0, 3) },
					LeftHip = { rot = v(8, 0, -3) },
				},
			},
		},
	},

	LeanBar = {
		length = 5,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = v(-14, 0, 0), pos = v(0, -0.1, -0.2) },
					Neck = { rot = v(10, 0, 0) },
					RightShoulder = { rot = v(80, 0, -28) },
					LeftShoulder = { rot = v(76, 0, 30) },
					RightHip = { rot = v(12, 0, 3) },
					LeftHip = { rot = v(8, 0, -6) },
				},
			},
			{
				time = 2.5,
				pose = {
					Root = { rot = v(-15, 0, 1), pos = v(0, -0.12, -0.2) },
					Neck = { rot = v(9, 0, 2) },
					RightShoulder = { rot = v(81, 0, -29) },
					LeftShoulder = { rot = v(77, 0, 31) },
					RightHip = { rot = v(12, 0, 3) },
					LeftHip = { rot = v(8, 0, -6) },
				},
			},
		},
	},

	-- (Root.pos is set per NPC from its seat: see sitOffset)
	SitStool = {
		length = 4.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = v(-6, 0, 0) },
					Neck = { rot = v(2, 0, 0) },
					RightShoulder = { rot = v(34, 0, -12) },
					LeftShoulder = { rot = v(30, 0, 12) },
					RightHip = { rot = v(76, 0, 4) },
					LeftHip = { rot = v(72, 0, -6) },
				},
			},
			{
				time = 2.3,
				pose = {
					Root = { rot = v(-7, 0, 0) },
					Neck = { rot = v(0, 0, 0) },
					RightShoulder = { rot = v(36, 0, -12) },
					LeftShoulder = { rot = v(31, 0, 13) },
					RightHip = { rot = v(76, 0, 4) },
					LeftHip = { rot = v(70, 0, -6) },
				},
			},
		},
	},

	ArmsCrossed = {
		length = 4.4,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = v(1, 0, 3), pos = v(0, 0, 0) },
					Neck = { rot = v(4, 0, -3) },
					RightShoulder = { rot = v(86, 0, -62) },
					LeftShoulder = { rot = v(78, 0, 66) },
					RightHip = { rot = v(0, 0, 7) },
					LeftHip = { rot = v(4, 0, -1) },
				},
			},
			{
				time = 2.2,
				pose = {
					Root = { rot = v(2, 0, 3), pos = v(0, 0.04, 0) },
					Neck = { rot = v(5, 0, -2) },
					RightShoulder = { rot = v(87, 0, -62) },
					LeftShoulder = { rot = v(79, 0, 66) },
					RightHip = { rot = v(0, 0, 7) },
					LeftHip = { rot = v(4, 0, -1) },
				},
			},
		},
	},

	-- On the floor, back against the wall (Root.pos is set per NPC: see groundOffset).
	-- The torso leans back 10°, the hips swing the legs 80° more: 90° from the vertical in
	-- all, the legs lie flat, stretched forward (a little apart). Slow, heavy breathing: the
	-- chest leans back on the in-breath and the hips / shoulders give the same angle back,
	-- so the legs stay on the floor and the hands on the knees (the head droops forward).
	SitGround = {
		length = 5.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = v(10, 0, 0) },
					Neck = { rot = v(-14, 0, 0) },
					RightShoulder = { rot = v(40, 0, -30) },
					LeftShoulder = { rot = v(40, 0, 30) },
					RightHip = { rot = v(80, 0, 5) },
					LeftHip = { rot = v(78, 0, -6) },
				},
			},
			{
				time = 2.6,
				pose = {
					Root = { rot = v(11.2, 0, 0.4) },
					Neck = { rot = v(-15.4, 0, 1) },
					RightShoulder = { rot = v(38.8, 0, -30) },
					LeftShoulder = { rot = v(38.8, 0, 30.5) },
					RightHip = { rot = v(78.8, 0, 5) },
					LeftHip = { rot = v(76.8, 0, -6) },
				},
			},
		},
	},

	-- The same, the right forearm held out over the knee, a paper cup of coins in the hand
	-- (resting on the blanket: see addCup); the left hand stays on the blanket.
	SitGroundCup = {
		length = 5.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = v(10, 0, 0) },
					Neck = { rot = v(-12, 0, 0) },
					RightShoulder = { rot = v(CUP_ARM, 0, -6) },
					LeftShoulder = { rot = v(40, 0, 30) },
					RightHip = { rot = v(80, 0, 5) },
					LeftHip = { rot = v(78, 0, -6) },
				},
			},
			{
				time = 2.6,
				pose = {
					Root = { rot = v(11.2, 0, 0.4) },
					Neck = { rot = v(-13.4, 0, 1) },
					RightShoulder = { rot = v(CUP_ARM - 1.2, 0, -6) },
					LeftShoulder = { rot = v(38.8, 0, 30.5) },
					RightHip = { rot = v(78.8, 0, 5) },
					LeftHip = { rot = v(76.8, 0, -6) },
				},
			},
		},
	},

	Phone = {
		length = 3.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = v(-2, 0, 0) },
					Neck = { rot = v(-16, 0, 0) },
					RightShoulder = { rot = v(118, 0, -36) },
					LeftShoulder = { rot = v(6, 0, -4) },
					RightHip = { rot = v(0, 0, 3) },
					LeftHip = { rot = v(0, 0, -3) },
				},
			},
			{
				time = 1.8,
				pose = {
					Root = { rot = v(-2, 0, 0), pos = v(0, 0.03, 0) },
					Neck = { rot = v(-18, 2, 0) },
					RightShoulder = { rot = v(121, 0, -37) },
					LeftShoulder = { rot = v(7, 0, -5) },
					RightHip = { rot = v(0, 0, 3) },
					LeftHip = { rot = v(0, 0, -3) },
				},
			},
		},
	},
}

------------------------------------------------------------------------------
-- NPC records
------------------------------------------------------------------------------

type Npc = {
	model: Model,
	root: BasePart,
	head: BasePart,
	motors: { [string]: Motor6D },
	clip: R6Pose.Clip,
	timeOffset: number, -- each NPC is at its own point of its clip (not all in sync)
	rootOffset: CFrame?, -- sitting: the whole body down / back onto the seat
	role: string,
	lines: { string },
	headYaw: number, -- degrees, current (smoothed)
	glanceYaw: number, -- degrees, where it looks when nobody is near
	nextGlanceAt: number,
	greeted: boolean,
	lastGreetAt: number,
}

local npcs: { [Model]: Npc } = {}
local pose: { [string]: CFrame } = {} -- reused every frame
local random = Random.new()

-- A small prop held in a hand (the rag, the phone), on this screen only.
local function holdProp(
	model: Model,
	size: Vector3,
	color: Color3,
	offset: CFrame,
	name: string,
	material: Enum.Material?
): BasePart?
	local arm = model:FindFirstChild("Right Arm")
	if arm == nil or not arm:IsA("BasePart") then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = arm.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = arm
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = model
	return part
end

-- The whole body's shift for a sitting pose (in the HumanoidRootPart's space: Y up,
-- Z backwards). Standing, the torso's centre is 3 above the floor; sitting, the bottom of
-- the thighs rests on the seat: torso centre = seat + 1.5.
local function sitOffset(model: Model): CFrame
	local seat = model:GetAttribute("SeatHeight")
	local back = model:GetAttribute("SeatBack")
	local seatHeight = if typeof(seat) == "number" then seat else 1.8
	local seatBack = if typeof(back) == "number" then back else 1
	return CFrame.new(0, seatHeight + 1.5 - 3, seatBack)
end

-- Sitting on the floor (SitGround). The hips are the R6 hip joints, at the bottom of the
-- torso: with the legs flat (90°), the legs' centre line is at the joints' height, so they
-- would float half a leg (0.5) above what he sits on. We put the joints 0.25 above it
-- instead: the legs sink a quarter of their thickness (the thighs squashed on the ground,
-- the bottom of the torso 0.2 off it, hidden by the coat and the wall). The torso leans back
-- 10°: its hip joints are cos(10°) = 0.985 under its centre. So: torso centre = seat + 1.235.
-- SeatHeight = what he sits on above the floor (default 0: the floor; the cardboard adds
-- GROUND_PAD), SeatBack = how far behind the spot his hips are (default 0).
local GROUND_PAD = 0.08 -- the flattened cardboard box under him
local function groundOffset(model: Model): CFrame
	local seat = model:GetAttribute("SeatHeight")
	local back = model:GetAttribute("SeatBack")
	local seatHeight = (if typeof(seat) == "number" then seat else 0) + GROUND_PAD
	local seatBack = if typeof(back) == "number" then back else 0
	return CFrame.new(0, seatHeight + 0.25 + math.cos(math.rad(10)) - 3, seatBack)
end

-- A part made here (props), never touched, queried or collided with.
local function newPart(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = size.X > 0.25 and size.Y > 0.25
	part.Parent = model
	return part
end

-- A prop lying on the floor (anchored: it never moves).
local function floorPart(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = newPart(model, name, size, color, material, shape)
	part.Anchored = true
	part.CFrame = cframe
	return part
end

-- A Cylinder part stands upright with this turn (its axis is its X).
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- The floor point under someone sitting on the ground (SitGround): under the hips, Y up,
-- facing where he faces (-Z), in the world. His legs reach 2.2 in front of it (-Z), the wall
-- is about 0.8 behind it (+Z).
local function groundFrame(model: Model, root: BasePart): CFrame
	local seat = model:GetAttribute("SeatHeight")
	local back = model:GetAttribute("SeatBack")
	local floor = -3 + (if typeof(seat) == "number" then seat else 0)
	local seatBack = if typeof(back) == "number" then back else 0
	return root.CFrame * CFrame.new(0, floor, seatBack)
end

-- A flattened cardboard box on the floor under someone sitting there: from just behind the
-- hips to past the heels, a little crooked, damaged: a crease where it was folded, a strip of
-- old packing tape, a wet stain, a torn flap at the front bent up off the floor.
local function addCardboard(model: Model, root: BasePart)
	local base = groundFrame(model, root)
	local color = Color3.fromRGB(122, 96, 66)
	local sheet = base * CFrame.new(0.05, GROUND_PAD / 2, -0.75) * CFrame.Angles(0, math.rad(4), 0)
	floorPart(
		model,
		"Cardboard",
		Vector3.new(2.5, GROUND_PAD, 2.7),
		sheet,
		color,
		Enum.Material.Cardboard
	)
	floorPart(
		model,
		"CardboardCrease",
		Vector3.new(2.5, GROUND_PAD + 0.006, 0.05),
		sheet * CFrame.new(0, 0, 0.45),
		darker(color, 0.25),
		Enum.Material.Cardboard
	)
	floorPart(
		model,
		"CardboardTape",
		Vector3.new(0.22, GROUND_PAD + 0.008, 1.2),
		sheet * CFrame.new(-0.85, 0, -0.3) * CFrame.Angles(0, math.rad(3), 0),
		Color3.fromRGB(176, 150, 104),
		Enum.Material.SmoothPlastic
	).Transparency =
		0.25
	floorPart(
		model,
		"CardboardStain",
		Vector3.new(0.9, GROUND_PAD + 0.004, 0.7),
		sheet * CFrame.new(0.6, 0, -1.0) * CFrame.Angles(0, math.rad(20), 0),
		darker(color, 0.35),
		Enum.Material.Cardboard
	)
	floorPart(
		model,
		"CardboardFlap",
		Vector3.new(0.9, 0.05, 0.62),
		sheet
			* CFrame.new(-0.7, 0, -1.35)
			* CFrame.Angles(math.rad(12), 0, 0)
			* CFrame.new(0, 0.01, -0.3),
		darker(color, 0.08),
		Enum.Material.Cardboard
	)
end

-- A paper coffee cup with a few coins in it, built around `cframe` (its middle, upright):
-- the cup, its cardboard sleeve, the rim, the dark inside, the coins on top. `attach`
-- (optional) = the body part it is welded to; otherwise it stands anchored.
local function addCup(model: Model, cframe: CFrame, attach: BasePart?)
	local function piece(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?
	)
		local part = newPart(model, name, size, color, material, Enum.PartType.Cylinder)
		local world = cframe * offset * UPRIGHT
		part.CFrame = world
		if attach then
			part.Massless = true
			local weld = Instance.new("Weld")
			weld.Part0 = attach
			weld.Part1 = part
			weld.C0 = attach.CFrame:ToObjectSpace(world)
			weld.Parent = part
		else
			part.Anchored = true
		end
	end
	piece("Cup", Vector3.new(0.56, 0.44, 0.44), CFrame.identity, Color3.fromRGB(222, 214, 198))
	piece(
		"CupSleeve",
		Vector3.new(0.2, 0.46, 0.46),
		CFrame.new(0, -0.03, 0),
		Color3.fromRGB(146, 108, 68),
		Enum.Material.Cardboard
	)
	piece(
		"CupRim",
		Vector3.new(0.05, 0.47, 0.47),
		CFrame.new(0, 0.27, 0),
		Color3.fromRGB(232, 226, 212)
	)
	piece(
		"CupInside",
		Vector3.new(0.012, 0.38, 0.38),
		CFrame.new(0, 0.284, 0),
		Color3.fromRGB(42, 34, 28)
	)
	local coins: { { at: CFrame, color: Color3 } } = {
		{
			at = CFrame.new(-0.06, 0.296, 0.04) * CFrame.Angles(0, 0, math.rad(8)),
			color = Color3.fromRGB(176, 176, 172),
		},
		{
			at = CFrame.new(0.07, 0.3, -0.04) * CFrame.Angles(math.rad(14), 0, 0),
			color = Color3.fromRGB(168, 104, 64),
		},
		{
			at = CFrame.new(0.0, 0.31, 0.08) * CFrame.Angles(math.rad(-10), 0, math.rad(6)),
			color = Color3.fromRGB(196, 168, 92),
		},
	}
	for _, coin in coins do
		piece("Coin", Vector3.new(0.03, 0.15, 0.15), coin.at, coin.color, Enum.Material.Metal)
	end
end

-- A coin lying on the floor (or on the cardboard).
local function addCoin(model: Model, cframe: CFrame, color: Color3)
	floorPart(
		model,
		"Coin",
		Vector3.new(0.025, 0.15, 0.15),
		cframe * UPRIGHT,
		color,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
end

-- SitGroundCup: the cup in the right hand. The hand is tilted by the torso and the shoulder:
-- the opposite tilt (from the clip's first key) keeps the cup upright, its middle a little
-- below and in front of the fist, its bottom on the blanket over the knee.
local CUP_IN_FIST = CFrame.new(0, -0.06, -0.3)
local function addCupInHand(model: Model)
	local arm = model:FindFirstChild("Right Arm")
	if arm == nil or not arm:IsA("BasePart") then
		return
	end
	local first = CLIPS.SitGroundCup.keyframes[1].pose
	local function angles(rot: Vector3): CFrame
		return CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	end
	local upright = (angles(first.Root.rot) * angles(first.RightShoulder.rot)):Inverse()
	-- (in the arm's space: the bottom of the hand, then upright, then the cup's offset)
	local grip = CFrame.new(0, -0.95, 0) * upright * CUP_IN_FIST
	addCup(model, arm.CFrame * grip, arm)
end

-- The blanket over his legs (SitGround): a grey wool blanket pulled over the thighs, tucked
-- against his belly, two dark stripes near its end, a crumpled fold on top, its end rolled
-- over above the knees (the hands rest there), its sides falling to the floor. The legs
-- (1 thick) lie with their tops 0.75 above the seat (see groundOffset): the blanket lies on
-- them, from the hips to just before the knees (the knees and the boots show).
local function addBlanket(model: Model, root: BasePart, seed: number)
	local base = groundFrame(model, root)
	local seat = GROUND_PAD
	local wool = if seed % 2 == 0 then Color3.fromRGB(92, 86, 76) else Color3.fromRGB(70, 76, 82)
	local stripe = Color3.fromRGB(96, 38, 34)
	local fabric = Enum.Material.Fabric
	local main = base * CFrame.new(0.03, seat + 0.81, -0.78) * CFrame.Angles(0, math.rad(2), 0)
	floorPart(model, "Blanket", Vector3.new(2.5, 0.1, 0.86), main, wool, fabric)
	for _, z in { -0.2, -0.29 } do
		floorPart(
			model,
			"BlanketStripe",
			Vector3.new(2.51, 0.104, 0.05),
			main * CFrame.new(0, 0, z),
			stripe,
			fabric
		)
	end
	floorPart(
		model,
		"BlanketFold",
		Vector3.new(1.2, 0.08, 0.5),
		main * CFrame.new(-0.42, 0.07, 0.08) * CFrame.Angles(0, math.rad(-12), math.rad(2)),
		wool:Lerp(Color3.fromRGB(150, 140, 124), 0.12),
		fabric
	)
	floorPart(
		model,
		"BlanketRoll",
		Vector3.new(2.44, 0.24, 0.24),
		main * CFrame.new(0, -0.02, -0.47),
		darker(wool, 0.08),
		fabric,
		Enum.PartType.Cylinder
	)
	for _, side in { -1, 1 } do
		floorPart(
			model,
			"BlanketSide",
			Vector3.new(0.08, 0.86, 0.9),
			base
				* CFrame.new(side * 1.29, seat + 0.38, -0.8)
				* CFrame.Angles(0, math.rad(2), math.rad(side * 6)),
			darker(wool, 0.12),
			fabric
		)
	end
end

-- The vagrant's things around him (role Vagrant, sitting on the ground):
--   • a cardboard sign leaning against the wall on his left, "ANYTHING HELPS / GOD BLESS"
--     in black marker, a crease where it was folded, the bottom gone dark with wet;
--   • his backpack against the wall on his right: a front pocket, the lid with two straps
--     and buckles, a sewn-on patch, a sleeping roll strapped on top, dirt at the bottom;
--   • a dog-eared paperback on the floor by his left hip (a corner folded, a bookmark);
--   • a few coins on the cardboard by his right knee, and the paper cup on the floor when he
--     does not hold it out.
local function addSquat(model: Model, root: BasePart, cupInHand: boolean)
	local base = groundFrame(model, root)

	-- the sign
	local sign = base
		* CFrame.new(-2.45, 0, 0.42)
		* CFrame.Angles(0, math.rad(-6), 0)
		* CFrame.Angles(math.rad(14), 0, 0)
		* CFrame.new(0, 0.575, 0)
	local cardboard = Color3.fromRGB(150, 116, 78)
	local board = floorPart(
		model,
		"Sign",
		Vector3.new(1.7, 1.15, 0.06),
		sign,
		cardboard,
		Enum.Material.Cardboard
	)
	floorPart(
		model,
		"SignCrease",
		Vector3.new(1.7, 0.025, 0.064),
		sign * CFrame.new(0, 0.03, 0),
		darker(cardboard, 0.2),
		Enum.Material.Cardboard
	)
	floorPart(
		model,
		"SignWet",
		Vector3.new(1.704, 0.16, 0.064),
		sign * CFrame.new(0, -0.5, 0),
		darker(cardboard, 0.35),
		Enum.Material.Cardboard
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignText"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 90
	gui.LightInfluence = 1
	gui.Adornee = board
	gui.Parent = board
	local lines = {
		{ text = "ANYTHING\nHELPS", y = 0.06, height = 0.6, rotation = -3 },
		{ text = "GOD BLESS", y = 0.68, height = 0.18, rotation = -1 },
	}
	for _, line in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.06, line.y)
		label.Size = UDim2.fromScale(0.88, line.height)
		label.Rotation = line.rotation
		label.Font = Enum.Font.PermanentMarker
		label.Text = line.text
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(24, 20, 18)
		label.TextTransparency = 0.08
		label.Parent = gui
	end

	-- the backpack
	local olive = Color3.fromRGB(64, 68, 52)
	local pack = base
		* CFrame.new(2.65, 0, 0.3)
		* CFrame.Angles(0, math.rad(-10), 0)
		* CFrame.Angles(math.rad(5), 0, 0)
	local fabric = Enum.Material.Fabric
	local function packPart(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	)
		floorPart(model, name, size, pack * offset, color, material or fabric, shape)
	end
	packPart("Backpack", Vector3.new(1.2, 1.4, 0.62), CFrame.new(0, 0.7, 0), olive)
	packPart(
		"PackDirt",
		Vector3.new(1.21, 0.22, 0.63),
		CFrame.new(0, 0.11, 0),
		olive:Lerp(Color3.fromRGB(40, 34, 28), 0.5)
	)
	packPart(
		"PackPocket",
		Vector3.new(0.86, 0.62, 0.16),
		CFrame.new(0, 0.45, -0.38),
		darker(olive, 0.08)
	)
	packPart(
		"PackPocketZip",
		Vector3.new(0.7, 0.03, 0.012),
		CFrame.new(0, 0.68, -0.464),
		Color3.fromRGB(30, 30, 30)
	)
	packPart("PackLid", Vector3.new(1.24, 0.22, 0.66), CFrame.new(0, 1.42, 0), darker(olive, 0.12))
	packPart(
		"PackPatch",
		Vector3.new(0.26, 0.16, 0.012),
		CFrame.new(0.3, 1.42, -0.336),
		Color3.fromRGB(150, 60, 50)
	)
	for _, side in { -1, 1 } do
		packPart(
			"PackStrap",
			Vector3.new(0.1, 0.5, 0.03),
			CFrame.new(side * 0.32, 1.2, -0.325),
			darker(olive, 0.4)
		)
		packPart(
			"PackBuckle",
			Vector3.new(0.14, 0.1, 0.03),
			CFrame.new(side * 0.32, 0.98, -0.345),
			Color3.fromRGB(26, 26, 26),
			Enum.Material.Plastic
		)
		packPart(
			"PackSide",
			Vector3.new(0.14, 0.5, 0.42),
			CFrame.new(side * 0.67, 0.42, 0),
			darker(olive, 0.15)
		)
		packPart(
			"RollStrap",
			Vector3.new(0.08, 0.43, 0.43),
			CFrame.new(side * 0.42, 1.73, 0.02),
			Color3.fromRGB(26, 26, 26),
			nil,
			Enum.PartType.Cylinder
		)
	end
	packPart(
		"SleepingRoll",
		Vector3.new(1.5, 0.4, 0.4),
		CFrame.new(0, 1.73, 0.02),
		Color3.fromRGB(58, 72, 92),
		nil,
		Enum.PartType.Cylinder
	)

	-- the paperback
	local book = base * CFrame.new(-1.55, 0, -0.1) * CFrame.Angles(0, math.rad(25), 0)
	local cover = Color3.fromRGB(52, 66, 54)
	floorPart(
		model,
		"BookBack",
		Vector3.new(0.56, 0.03, 0.78),
		book * CFrame.new(0, 0.015, 0),
		cover
	)
	floorPart(
		model,
		"BookPages",
		Vector3.new(0.52, 0.08, 0.74),
		book * CFrame.new(0.02, 0.07, 0),
		Color3.fromRGB(214, 202, 170)
	)
	floorPart(
		model,
		"BookCover",
		Vector3.new(0.56, 0.03, 0.78),
		book * CFrame.new(0, 0.125, 0),
		cover
	)
	floorPart(
		model,
		"BookSpine",
		Vector3.new(0.05, 0.15, 0.78),
		book * CFrame.new(-0.285, 0.075, 0),
		darker(cover, 0.25)
	)
	floorPart(
		model,
		"DogEar",
		Vector3.new(0.11, 0.012, 0.11),
		book * CFrame.new(0.2, 0.146, -0.31) * CFrame.Angles(0, math.rad(45), 0),
		Color3.fromRGB(196, 186, 160)
	)
	floorPart(
		model,
		"BookTitle",
		Vector3.new(0.3, 0.006, 0.06),
		book * CFrame.new(0, 0.143, -0.15),
		Color3.fromRGB(170, 146, 90)
	)
	floorPart(
		model,
		"Bookmark",
		Vector3.new(0.04, 0.01, 0.2),
		book * CFrame.new(0.1, 0.1, -0.45),
		Color3.fromRGB(150, 40, 36)
	)

	-- the coins, and the cup on the floor if he is not holding it out
	local seat = GROUND_PAD + 0.0125
	addCoin(
		model,
		base * CFrame.new(1.22, seat, -1.62) * CFrame.Angles(0, 0.4, 0),
		Color3.fromRGB(176, 176, 172)
	)
	addCoin(model, base * CFrame.new(1.13, seat, -1.84), Color3.fromRGB(168, 104, 64))
	if not cupInHand then
		addCup(model, base * CFrame.new(1.6, 0.28, -1.25))
	end
end

local function linesFor(model: Model, role: string): { string }
	if role == "Clerk" then
		local shop = model:GetAttribute("NpcShop")
		local key = if typeof(shop) == "string" then `Clerk{shop}` else "Clerk"
		return LINES[key] or LINES.Clerk
	end
	return LINES[role] or LINES.Patron
end

local function addNpc(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance :: Model
	if npcs[model] or model:GetAttribute("Npc") ~= true then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 10)
	local head = model:WaitForChild("Head", 10)
	if root == nil or head == nil or not root:IsA("BasePart") or not head:IsA("BasePart") then
		return
	end
	-- (the parts and joints arrive one by one: wait for the last joint)
	local motors: { [string]: Motor6D }? = nil
	for _ = 1, 50 do
		motors = R6Pose.findMotors(model)
		if motors then
			break
		end
		task.wait(0.1)
	end
	if motors == nil or model.Parent == nil then
		return
	end
	local poseName = model:GetAttribute("NpcPose")
	local role = model:GetAttribute("NpcRole")
	local roleText = if typeof(role) == "string" then role else "Patron"
	local seed = model:GetAttribute("NpcSeed")
	local seedNumber = if typeof(seed) == "number" then seed else 0
	local poseText = if typeof(poseName) == "string" then poseName else "Idle"
	-- (SitGroundCup is a variant of SitGround, picked by the seed: two out of three hold out
	-- the paper cup)
	local cupInHand = poseText == "SitGround" and seedNumber % 3 ~= 0
	if cupInHand then
		poseText = "SitGroundCup"
	end
	local clip = CLIPS[poseText] or CLIPS.Idle
	local onGround = clip == CLIPS.SitGround or clip == CLIPS.SitGroundCup

	if clip == CLIPS.WipeCounter then
		-- an off-white rag under the right hand
		holdProp(
			model,
			Vector3.new(0.9, 0.14, 0.8),
			Color3.fromRGB(214, 208, 190),
			CFrame.new(0, -1.08, 0),
			"Rag"
		)
	elseif clip == CLIPS.Phone then
		-- a phone in the right hand, its screen towards the face
		holdProp(
			model,
			Vector3.new(0.5, 0.86, 0.12),
			Color3.fromRGB(22, 22, 26),
			CFrame.new(0, -1.15, -0.3) * CFrame.Angles(math.rad(-70), 0, 0),
			"Phone"
		)
	elseif clip == CLIPS.SitGroundCup then
		addCupInHand(model)
	end
	if onGround then
		addCardboard(model, root)
		addBlanket(model, root, seedNumber)
		if roleText == "Vagrant" then
			addSquat(model, root, cupInHand)
		end
	end

	npcs[model] = {
		model = model,
		root = root,
		head = head,
		motors = motors,
		clip = clip,
		timeOffset = (seedNumber * 0.618) % clip.length,
		rootOffset = if clip == CLIPS.SitStool
			then sitOffset(model)
			elseif onGround then groundOffset(model)
			else nil,
		role = roleText,
		lines = linesFor(model, roleText),
		headYaw = 0,
		glanceYaw = 0,
		nextGlanceAt = os.clock() + random:NextNumber(2, 6),
		greeted = false,
		lastGreetAt = -math.huge,
	}
end

local function removeNpc(instance: Instance)
	if instance:IsA("Model") then
		npcs[instance :: Model] = nil
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

-- Roots of the players' characters (to look at).
local roots: { BasePart } = {}
local function collectRoots()
	table.clear(roots)
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(roots, root)
		end
	end
end

-- A chat bubble above the NPC's head (only on this screen).
local function say(npc: Npc, text: string)
	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			TextChatService:DisplayBubble(npc.head, text)
		else
			game:GetService("Chat"):Chat(npc.head, text, Enum.ChatColor.White)
		end
	end)
end

local function updateGreeting(npc: Npc, myRoot: BasePart?)
	if myRoot == nil then
		return
	end
	local distance = (myRoot.Position - npc.root.Position).Magnitude
	if distance > GREET_RESET_RANGE then
		npc.greeted = false
	elseif distance <= GREET_RANGE and not npc.greeted then
		npc.greeted = true
		local now = os.clock()
		if now - npc.lastGreetAt < GREET_COOLDOWN then
			return
		end
		if npc.role == "Patron" and random:NextNumber() > PATRON_TALK_CHANCE then
			return
		end
		npc.lastGreetAt = now
		say(npc, npc.lines[random:NextInteger(1, #npc.lines)])
	end
end

-- The head's turn (degrees, + = to its left) towards the closest player in range, or a
-- slow look around when nobody is there.
local function wantedYaw(npc: Npc, now: number): number
	local rootCFrame = npc.root.CFrame
	local best: BasePart? = nil
	local bestDistance = HEAD_RANGE
	for _, root in roots do
		local distance = (root.Position - rootCFrame.Position).Magnitude
		if distance < bestDistance then
			best, bestDistance = root, distance
		end
	end
	if best then
		local offset = rootCFrame:PointToObjectSpace(best.Position)
		local yaw = math.deg(math.atan2(-offset.X, -offset.Z))
		if math.abs(yaw) <= 110 then -- (not someone right behind: no owl heads)
			return math.clamp(yaw, -HEAD_MAX_YAW, HEAD_MAX_YAW)
		end
	end
	if now >= npc.nextGlanceAt then
		-- (the dealer keeps an eye on both ends of the alley: quicker, wider glances)
		local wary = npc.role == "Dealer"
		local span = if wary then 50 else 35
		npc.glanceYaw = if npc.glanceYaw ~= 0 then 0 else random:NextNumber(-span, span)
		npc.nextGlanceAt = now
			+ if wary then random:NextNumber(1.2, 3.5) else random:NextNumber(2.5, 7)
	end
	return npc.glanceYaw
end

local function animate(npc: Npc, now: number, dt: number)
	R6Pose.sample(npc.clip, now + npc.timeOffset, pose)
	-- the sitting shift goes under the clip's own root pose
	local rootOffset = npc.rootOffset
	if rootOffset then
		pose.Root = rootOffset * (pose.Root or CFrame.identity)
	end
	-- the head turn goes on top of the clip's neck pose
	local target = wantedYaw(npc, now)
	npc.headYaw += (target - npc.headYaw) * math.min(1, dt * HEAD_TURN_SPEED)
	pose.Neck = CFrame.Angles(0, math.rad(npc.headYaw), 0) * (pose.Neck or CFrame.identity)
	for joint, motor in npc.motors do
		local localCFrame = pose[joint]
		if localCFrame then
			motor.Transform = R6Pose.toTransform(motor, localCFrame)
		end
	end
end

local function onPreSimulation(dt: number)
	local camera = workspace.CurrentCamera
	if camera == nil or next(npcs) == nil then
		return
	end
	collectRoots()
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	local mine: BasePart? = if myRoot and myRoot:IsA("BasePart") then myRoot else nil
	local cameraPosition = camera.CFrame.Position
	local now = os.clock()
	for model, npc in npcs do
		if model.Parent == nil then
			npcs[model] = nil
			continue
		end
		if (npc.root.Position - cameraPosition).Magnitude <= ANIMATE_RANGE then
			animate(npc, now, dt)
			updateGreeting(npc, mine)
		end
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function CityNpcController.start()
	local city = workspace:WaitForChild("City", 120)
	if city == nil then
		return
	end
	local folder = city:WaitForChild("Npcs", 600) -- (made once the city is built)
	if folder == nil then
		return
	end
	folder.ChildAdded:Connect(function(child)
		task.spawn(addNpc, child)
	end)
	folder.ChildRemoved:Connect(removeNpc)
	for _, child in folder:GetChildren() do
		task.spawn(addNpc, child)
	end
	RunService.PreSimulation:Connect(onPreSimulation)
end

return CityNpcController
