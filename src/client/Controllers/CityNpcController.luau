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
--        SitGround    sitting on the floor, back against a wall, legs stretched out, hands on
--                     the knees (or one hand on a bottle in a paper bag), breathing slowly,
--                     on a flattened cardboard box (the vagrant of the alleys)
--     (an unknown pose name gets Idle);
--   • turns the HEAD towards the closest player within HEAD_RANGE studs (smoothly, never
--     further than HEAD_MAX_YAW), and now and then looks around when nobody is there;
--   • says ONE line in a chat bubble when you walk up to a clerk, the bartender, the dealer
--     or the vagrant of the alleys (and sometimes a patron), then not again for a while.
--     The dealer keeps glancing around, more often than the others.
-- Only the NPCs near your camera are animated (ANIMATE_RANGE): the others freeze where they
-- are. Nothing here is sent to the server.
--
-- The rag, the phone, the bottle and the cardboard are small parts created here, on your
-- screen only.

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

	-- The same, the right hand down by the hip holding a bottle in a paper bag by its neck
	-- (the bag stands on the floor: see addBottle).
	SitGroundBottle = {
		length = 5.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = v(10, 0, 0) },
					Neck = { rot = v(-14, 0, 0) },
					RightShoulder = { rot = v(35, 0, 4) },
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
					RightShoulder = { rot = v(33.8, 0, 4) },
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

-- A small prop held in a hand (the rag, the phone, the bottle), on this screen only.
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

-- A flattened cardboard box on the floor under someone sitting there: from just behind the
-- hips to near the heels (the legs reach 2.2 in front of them), a little crooked.
local function addCardboard(model: Model, root: BasePart)
	local seat = model:GetAttribute("SeatHeight")
	local back = model:GetAttribute("SeatBack")
	local floor = -3 + (if typeof(seat) == "number" then seat else 0)
	local seatBack = if typeof(back) == "number" then back else 0
	local part = Instance.new("Part")
	part.Name = "Cardboard"
	part.Size = Vector3.new(2.5, GROUND_PAD, 2.7)
	part.Color = Color3.fromRGB(122, 96, 66)
	part.Material = Enum.Material.Cardboard
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = root.CFrame
		* CFrame.new(0.05, floor + GROUND_PAD / 2, seatBack - 0.75)
		* CFrame.Angles(0, math.rad(4), 0)
	part.Parent = model
end

-- The bottle of SitGroundBottle: a brown paper bag standing upright on the floor by the right
-- hip, the green glass neck sticking out of it in the fist. The props are welded to the arm,
-- which is tilted by the torso and the shoulder: the opposite tilt (from the clip's first
-- key) keeps them upright.
local function addBottle(model: Model)
	local first = CLIPS.SitGroundBottle.keyframes[1].pose
	local function angles(rot: Vector3): CFrame
		return CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	end
	local upright = (angles(first.Root.rot) * angles(first.RightShoulder.rot)):Inverse()
	local grip = CFrame.new(0, -0.8, 0) * upright -- in the fist, upright
	holdProp(
		model,
		Vector3.new(0.16, 0.34, 0.16),
		Color3.fromRGB(46, 70, 42),
		grip,
		"BottleNeck",
		Enum.Material.Glass
	)
	holdProp(
		model,
		Vector3.new(0.44, 0.72, 0.4),
		Color3.fromRGB(138, 108, 74),
		grip * CFrame.new(0, -0.17 - 0.36, 0) * CFrame.Angles(0, math.rad(12), 0),
		"PaperBag",
		Enum.Material.Cardboard
	)
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
	-- (SitGroundBottle is a variant of SitGround, picked by the seed: two out of three hold
	-- a bottle)
	if poseText == "SitGround" and seedNumber % 3 ~= 0 then
		poseText = "SitGroundBottle"
	end
	local clip = CLIPS[poseText] or CLIPS.Idle
	local onGround = clip == CLIPS.SitGround or clip == CLIPS.SitGroundBottle

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
	elseif clip == CLIPS.SitGroundBottle then
		addBottle(model)
	end
	if onGround then
		addCardboard(model, root)
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
