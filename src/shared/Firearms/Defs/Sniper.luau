--!strict
-- .338 BOLT RIFLE: a bolt-action .338 with a thumbhole stock, an 8× scope and a
-- bipod, 5 + 1. One deliberate shot: a big slow heave of the whole upper body, then
-- the bolt worked by hand (the case flips out on the pull). Passes through one body.
-- Owned by the sniper's agent (docs/firearms/CORE.md). Numbers: ARCHITECTURE §4.2.

local Carry = require(script.Parent.Parent.Carry)
local Types = require(script.Parent.Parent.Types)

local def: Types.FirearmDef = {
	id = "Sniper",
	name = ".338 BOLT RIFLE",
	class = "Sniper",
	caliber = ".338 magnum",
	order = 4,
	modes = { "Bolt" },
	rpm = 60, -- the bolt cycle (1.0 s) is the real limit
	feed = "Magazine",
	capacity = 5,
	closedBolt = true,
	lockBack = false,
	startReserve = 10,
	damage = 95,
	zones = { Head = 3.0, Torso = 1.0, Arms = 0.7, Legs = 0.8 },
	falloff = { full = 1000, zero = 4000, min = 0.95 },
	range = 2000,
	pierce = 1,
	pierceScale = 0.6,
	glass = "Through",
	velocity = 3200, -- 900 m/s
	spread = {
		hip = 5.0,
		ready = 3.5,
		ads = 0.03,
		moving = 3.0,
		crouch = 0.8,
		bipod = 0.5,
		perShot = 0,
		max = 0,
		recover = 1,
	},
	recoil = {
		climb = 6.0,
		climbFirst = 1,
		yaw = 0.8,
		yawBias = 0,
		recover = 0.80,
		recoverTime = 0.60,
		kick = 8,
		push = 0.21,
		roll = 2,
		torso = 5,
		frequency = 2.5,
		zeta = 0.65,
		shake = 1.0,
		bipod = 0.3,
		crouch = 0.85,
	},
	handling = {
		massKg = 7.5,
		adsTime = 0.40,
		sprintToFire = 0.42,
		raiseTime = 0.30,
		lowerTime = 0.55,
		drawTime = 1.1,
		holsterTime = 0.9,
		sprintIn = 0.35,
		sprintOut = 0.42,
		obstructIn = 0.25,
		obstructOut = 0.20,
		bipodDeploy = 0.45,
		bipodFold = 0.40,
		lookLagHz = 3,
		lookLagMax = 6,
		walkSpeed = 0.88,
		adsWalkSpeed = 0.5,
		canSprint = true,
		sprintSpeed = 0.92,
		tuckLength = 4.6,
		lowReadyAfter = 4,
		fov = 9,
	},
	eject = {
		kind = "Brass",
		when = "Cycle", -- on the bolt pull (case_eject), not the shot
		speed = { 3.5, 9 }, -- 1–2.5 m/s × how hard the bolt is pulled
		cone = 10,
		spin = { 5, 10 },
		drag = 0.05,
		bottleneck = true,
	},
	muzzle = {
		flash = 0.45,
		flashKind = "Brake", -- side jets out of the brake ports
		lightRange = 12,
		lightBrightness = 5,
		smoke = 0.7,
		portPuff = false,
		dustKick = true,
	},
	sounds = {
		shot = "Sniper",
		supersonic = true,
		dry = "DryLong",
		caseKind = "Heavy",
		mag = "Steel",
	},
	feedDrop = {
		kind = "Mag",
		material = "Steel",
		spin = Vector3.new(1.5, 0, 0),
		push = Vector3.new(0, -2.5, 0), -- straight down out of the well
		elasticity = 0.15,
		friction = 0.6,
	},
	carry = {
		kind = "Back",
		-- muzzle up over the left shoulder, steeper than the AK, scope against the back
		cf = Carry.back(Vector3.new(0.05, 0.2, 0.84), 30, true),
		strap = Color3.fromRGB(28, 28, 26),
	},
	optic = { kind = "Scope", fov = 9, magnification = 8 },
	originSlack = 4.5,
	displayScale = 1,
}

return table.freeze(def)
