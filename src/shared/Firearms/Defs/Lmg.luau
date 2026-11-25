--!strict
-- 5.56 LMG: a belt-fed 5.56 with a 200-round pouch, a 4× prism and a bipod. Heavy and
-- slow to move, but a low, buzzing, controllable recoil (a light round in a 10 kg
-- gun); open bolt (no round in the chamber), cases thrown DOWN and links out to the
-- right, a tracer every fourth round. Owned by the LMG's agent (docs/firearms/CORE.md).
-- Numbers: ARCHITECTURE §4.2.

local Carry = require(script.Parent.Parent.Carry)
local Types = require(script.Parent.Parent.Types)

local def: Types.FirearmDef = {
	id = "Lmg",
	name = "5.56 LMG",
	class = "Lmg",
	caliber = "5.56×45 mm",
	order = 5,
	modes = { "Auto" },
	rpm = 800,
	feed = "Belt",
	capacity = 200,
	closedBolt = false, -- open bolt: nothing in the chamber
	lockBack = false,
	startReserve = 200, -- one spare pouch on the belt
	damage = 32,
	zones = { Head = 3.0, Torso = 1.0, Arms = 0.6, Legs = 0.7 },
	falloff = { full = 180, zero = 540, min = 0.7 },
	range = 1000,
	pierce = 0,
	pierceScale = 0,
	glass = "Through",
	velocity = 3270, -- 915 m/s
	spread = {
		hip = 4.0,
		ready = 2.8,
		ads = 0.6,
		moving = 2.2,
		crouch = 0.8,
		bipod = 0.4,
		perShot = 0.25,
		max = 3.0,
		recover = 2.5,
	},
	recoil = {
		climb = 0.55,
		climbFirst = 1.5,
		yaw = 0.4,
		yawBias = 0.1,
		recover = 0.70,
		recoverTime = 0.35,
		kick = 2.2,
		push = 0.035,
		roll = 1,
		torso = 1,
		frequency = 4,
		zeta = 0.45,
		shake = 0.25,
		bipod = 0.3,
		crouch = 0.85,
	},
	handling = {
		massKg = 10.1,
		adsTime = 0.45,
		sprintToFire = 0.45,
		raiseTime = 0.32,
		lowerTime = 0.60,
		drawTime = 1.3,
		holsterTime = 1.1,
		sprintIn = 0.40,
		sprintOut = 0.45,
		obstructIn = 0.25,
		obstructOut = 0.20,
		bipodDeploy = 0.50,
		bipodFold = 0.45,
		lookLagHz = 3,
		lookLagMax = 6,
		walkSpeed = 0.85,
		adsWalkSpeed = 0.5,
		canSprint = true,
		sprintSpeed = 0.85, -- a slower carry
		tuckLength = 3.4,
		lowReadyAfter = 4,
		fov = 20,
	},
	eject = {
		kind = "Brass",
		when = "Shot",
		speed = { 3.5, 7 }, -- 1–2 m/s, straight down out of the port
		cone = 12,
		spin = { 10, 20 },
		drag = 0.05,
		dir = Vector3.new(0.17, -0.98, -0.1), -- down, a little forward and right
		bottleneck = true,
		links = { speed = { 3.5, 7 }, spin = { 5, 10 }, cone = 15 },
	},
	muzzle = {
		flash = 0.4,
		flashKind = "Hider",
		lightRange = 11,
		lightBrightness = 4,
		smoke = 0.4,
		portPuff = true,
		hazeAfter = 12,
		dustKick = true,
		tracerEvery = 4,
		tracerColor = Color3.fromRGB(255, 120, 60),
	},
	sounds = {
		shot = "Lmg",
		supersonic = true,
		dry = "DryLong",
		caseKind = "Brass",
		mag = "Cloth",
	},
	feedDrop = {
		kind = "Pouch",
		material = "Cloth",
		spin = Vector3.new(0, 0, 0.8),
		push = Vector3.new(0, -1, 0),
		elasticity = 0,
		friction = 0.9,
	},
	carry = {
		kind = "Back",
		-- muzzle down behind the left hip (too heavy to sling muzzle up), optic against the back
		cf = Carry.back(Vector3.new(-0.05, 0.05, 0.98), -150, true),
		strap = Color3.fromRGB(120, 100, 70), -- tan
	},
	optic = { kind = "Prism", fov = 20, magnification = 4 },
	originSlack = 4.5,
	displayScale = 1,
}

return table.freeze(def)
