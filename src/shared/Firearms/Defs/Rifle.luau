--!strict
-- 7.62 RIFLE: an AK-type 7.62×39 with wooden furniture, 30 + 1, semi / auto. A
-- springy rhythmic shove with a steady climb up and to the right, steel cases
-- flung far forward-right. The mag rocks out about its front lug.
-- Owned by the rifle's agent (docs/firearms/CORE.md). Numbers: ARCHITECTURE §4.2.

local Carry = require(script.Parent.Parent.Carry)
local Types = require(script.Parent.Parent.Types)

local def: Types.FirearmDef = {
	id = "Rifle",
	name = "7.62 RIFLE",
	class = "Rifle",
	caliber = "7.62×39 mm",
	order = 3,
	modes = { "Auto", "Semi" },
	rpm = 600,
	feed = "Magazine",
	capacity = 30,
	closedBolt = true,
	lockBack = false, -- no hold-open: empty = charging handle
	startReserve = 60,
	damage = 38,
	zones = { Head = 3.0, Torso = 1.0, Arms = 0.6, Legs = 0.7 },
	falloff = { full = 180, zero = 540, min = 0.75 },
	range = 1000,
	pierce = 0,
	pierceScale = 0,
	glass = "Through",
	velocity = 2540, -- 715 m/s
	spread = {
		hip = 3.0,
		ready = 2.0,
		ads = 0.25,
		moving = 1.6,
		crouch = 0.8,
		perShot = 0.35,
		max = 2.5,
		recover = 3.0,
	},
	recoil = {
		climb = 0.9,
		climbFirst = 2,
		yaw = 0.35,
		yawBias = 0.25, -- the classic up-and-right walk
		recover = 0.65,
		recoverTime = 0.30,
		kick = 4,
		push = 0.05,
		roll = 1.5,
		torso = 1.5,
		frequency = 5,
		zeta = 0.5,
		shake = 0.3,
		crouch = 0.85,
	},
	handling = {
		massKg = 3.9,
		adsTime = 0.25,
		sprintToFire = 0.25,
		raiseTime = 0.20,
		lowerTime = 0.40,
		drawTime = 0.95,
		holsterTime = 0.75,
		sprintIn = 0.28,
		sprintOut = 0.25,
		obstructIn = 0.20,
		obstructOut = 0.15,
		lookLagHz = 5,
		lookLagMax = 6,
		walkSpeed = 0.95,
		adsWalkSpeed = 0.6,
		canSprint = true,
		sprintSpeed = 0.97,
		tuckLength = 3.3,
		lowReadyAfter = 4,
		fov = 58,
	},
	eject = {
		kind = "Steel",
		when = "Shot",
		speed = { 18, 25 }, -- 5–7 m/s: they land 5–6 m away
		cone = 10,
		spin = { 15, 30 },
		drag = 0.05,
		bottleneck = true,
	},
	muzzle = {
		flash = 0.75,
		flashKind = "Brake", -- the slant brake throws it up and right
		lightRange = 12,
		lightBrightness = 5,
		smoke = 0.5,
		portPuff = true,
		hazeAfter = 10,
	},
	sounds = {
		shot = "Rifle",
		supersonic = true,
		dry = "DryLong",
		caseKind = "Steel",
		mag = "Steel",
	},
	feedDrop = {
		kind = "Mag",
		material = "Steel",
		spin = Vector3.new(-5, 0, 0), -- rocked forward-out: a forward tumble
		push = Vector3.new(0, -1.5, -1),
		elasticity = 0.15,
		friction = 0.55,
	},
	carry = {
		kind = "Back",
		-- muzzle up over the left shoulder
		cf = Carry.back(Vector3.new(0, 0.1, 0.64), 38, true),
		strap = Color3.fromRGB(58, 50, 38),
	},
	optic = { kind = "Irons" },
	originSlack = 4.5,
	displayScale = 1,
}

return table.freeze(def)
