--!strict
-- 12-GAUGE TACTICAL: a semi-automatic 12-gauge, tube 7 + 1, red dot. A heavy,
-- slow shove into the shoulder (low-frequency spring), 8 pellets per shell, hulls
-- tossed lazily to the right. Reloaded shell by shell (Timelines/Shotgun).
-- Owned by the shotgun's agent (docs/firearms/CORE.md). Numbers: ARCHITECTURE §4.2.

local Carry = require(script.Parent.Parent.Carry)
local Types = require(script.Parent.Parent.Types)

local def: Types.FirearmDef = {
	id = "Shotgun",
	name = "12-GAUGE TACTICAL",
	class = "Shotgun",
	caliber = "12 gauge 70 mm",
	order = 2,
	modes = { "Semi" },
	rpm = 300,
	feed = "Tube",
	capacity = 7,
	closedBolt = true,
	lockBack = true, -- the bolt locks back on the last shell: port load first
	startReserve = 14,
	damage = 11, -- per pellet
	zones = { Head = 2.5, Torso = 1.0, Arms = 0.6, Legs = 0.65 },
	falloff = { full = 30, zero = 110, min = 0.25 },
	range = 160,
	pierce = 0,
	pierceScale = 0,
	glass = "Stop",
	velocity = 1430, -- 400 m/s
	spread = {
		hip = 2.0,
		ready = 1.4,
		ads = 0.5,
		moving = 1.0,
		crouch = 0.85,
		perShot = 0.8,
		max = 2.0,
		recover = 3.5,
		pellets = 8,
		pelletCone = 1.6,
	},
	recoil = {
		climb = 4.5,
		climbFirst = 1,
		yaw = 1.0,
		yawBias = 0,
		recover = 0.70,
		recoverTime = 0.45,
		kick = 11,
		push = 0.18,
		roll = 4,
		torso = 4,
		frequency = 3.5,
		zeta = 0.6,
		shake = 1.2,
		crouch = 0.85,
	},
	handling = {
		massKg = 3.6,
		adsTime = 0.30,
		sprintToFire = 0.28,
		raiseTime = 0.22,
		lowerTime = 0.45,
		drawTime = 1.0,
		holsterTime = 0.8,
		sprintIn = 0.30,
		sprintOut = 0.28,
		obstructIn = 0.22,
		obstructOut = 0.18,
		lookLagHz = 5,
		lookLagMax = 6,
		walkSpeed = 0.95,
		adsWalkSpeed = 0.6,
		canSprint = true,
		sprintSpeed = 0.97,
		tuckLength = 3.6,
		lowReadyAfter = 4,
		fov = 54,
	},
	eject = {
		kind = "Hull",
		when = "Shot",
		speed = { 5, 11 }, -- 1.5–3 m/s, a plastic hull tumbling end over end
		cone = 14,
		spin = { 6, 12 },
		drag = 0.8,
		bottleneck = false,
	},
	muzzle = {
		flash = 0.8,
		flashKind = "Bloom",
		lightRange = 14,
		lightBrightness = 6,
		smoke = 0.8,
		portPuff = true,
	},
	sounds = {
		shot = "Shotgun",
		supersonic = false,
		dry = "DryLong",
		caseKind = "Hull",
		mag = "Polymer",
	},
	feedDrop = {
		kind = "None",
		material = "Polymer",
		spin = Vector3.zero,
		push = Vector3.zero,
		elasticity = 0.2,
		friction = 0.6,
	},
	carry = {
		kind = "Back",
		-- muzzle down behind the right hip, butt over the left shoulder
		cf = Carry.back(Vector3.new(0.05, -0.05, 0.66), 150, true),
		strap = Color3.fromRGB(34, 34, 32),
	},
	optic = { kind = "RedDot" },
	originSlack = 4.5,
	displayScale = 1,
}

return table.freeze(def)
