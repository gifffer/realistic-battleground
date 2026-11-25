--!strict
-- 9MM COMPACT: a polymer striker-fired 9×19 pistol, 15 + 1. Light, fast, snappy:
-- a sharp high-frequency kick that settles quickly, brass thrown back and right.
-- Owned by the pistol's agent (docs/firearms/CORE.md, "Who owns what"). Numbers:
-- docs/firearms/ARCHITECTURE.md §4.2, §10.2, §12; tune here.

local Carry = require(script.Parent.Parent.Carry)
local Types = require(script.Parent.Parent.Types)

local def: Types.FirearmDef = {
	id = "Pistol",
	name = "9MM COMPACT",
	class = "Pistol",
	caliber = "9×19 mm",
	order = 1,
	modes = { "Semi" },
	rpm = 450, -- cap on how fast the trigger can be worked
	feed = "Magazine",
	capacity = 15,
	closedBolt = true,
	lockBack = true, -- the slide locks open on the last round
	startReserve = 15,
	damage = 28,
	zones = { Head = 3.0, Torso = 1.0, Arms = 0.6, Legs = 0.65 },
	falloff = { full = 50, zero = 160, min = 0.55 },
	range = 400,
	pierce = 0,
	pierceScale = 0,
	glass = "Stop",
	velocity = 1290, -- 360 m/s
	spread = {
		hip = 2.5,
		ready = 1.6,
		ads = 0.35,
		moving = 1.2,
		crouch = 0.8,
		perShot = 0.6,
		max = 3.0,
		recover = 6.0,
	},
	recoil = {
		climb = 1.4,
		climbFirst = 1,
		yaw = 0.4,
		yawBias = 0,
		recover = 0.85,
		recoverTime = 0.25,
		kick = 8,
		push = 0.10,
		roll = 3,
		torso = 1,
		frequency = 7,
		zeta = 0.55,
		shake = 0.4,
		crouch = 0.85,
	},
	handling = {
		massKg = 0.85,
		adsTime = 0.18,
		sprintToFire = 0.15,
		raiseTime = 0.15,
		lowerTime = 0.35,
		drawTime = 0.55,
		holsterTime = 0.45,
		sprintIn = 0.20,
		sprintOut = 0.15,
		obstructIn = 0.20,
		obstructOut = 0.15,
		lookLagHz = 7,
		lookLagMax = 6,
		walkSpeed = 1.0,
		adsWalkSpeed = 0.7,
		canSprint = true,
		sprintSpeed = 1.0,
		tuckLength = 1.9,
		lowReadyAfter = 6,
		fov = 58,
	},
	eject = {
		kind = "Brass",
		when = "Shot",
		speed = { 9, 14 }, -- 2.5–4 m/s
		cone = 12,
		spin = { 20, 40 },
		drag = 0.05,
		steepChance = 0.1, -- now and then one goes steeply up and back
		bottleneck = false,
	},
	muzzle = {
		flash = 0.25,
		flashKind = "Star",
		lightRange = 9,
		lightBrightness = 4,
		smoke = 0.35,
		portPuff = true,
	},
	sounds = {
		shot = "Pistol",
		supersonic = false,
		dry = "DryPistol",
		caseKind = "Brass",
		mag = "Polymer",
	},
	feedDrop = {
		kind = "Mag",
		material = "Polymer",
		spin = Vector3.new(4, 0, 0), -- a small forward tumble
		push = Vector3.new(0, -2, 0),
		elasticity = 0.25,
		friction = 0.6,
	},
	carry = {
		kind = "Hip",
		cf = Carry.hip(Vector3.new(1.08, -1.28, 0.12)),
	},
	optic = { kind = "Irons" },
	originSlack = 3.5,
	displayScale = 1,
}

return table.freeze(def)
