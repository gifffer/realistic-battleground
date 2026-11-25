--!strict
-- Firearms types, in their own module so every gun file (Defs/<Gun>, Models/<Gun>,
-- Timelines/<Gun>) can use them without requiring the registry (same reason as
-- Kits/KitTypes). docs/firearms/ARCHITECTURE.md §4 (data), §5 (model contract), §8
-- (timelines); docs/firearms/CORE.md (what is built).
--
-- Units: studs, seconds, degrees, unless a field says otherwise. Damage is before
-- Config.Firearms.DAMAGE_SCALE.

export type FireMode = "Semi" | "Auto" | "Bolt"
export type Class = "Pistol" | "Shotgun" | "Rifle" | "Sniper" | "Lmg"
export type Feed = "Magazine" | "Tube" | "Belt"
-- Hit zones of a bullet (the melee's Types.HitZone has no "Arms": arms count as
-- the torso there; for guns they have their own multiplier).
export type Zone = "Head" | "Torso" | "Arms" | "Legs"
export type Zones = { Head: number, Torso: number, Arms: number, Legs: number }

-- Spread: half-angle of the cone, degrees.
export type SpreadDef = {
	hip: number, -- not aiming, standing still
	ready: number, -- shouldered / ready stance, not aiming
	ads: number, -- aiming down the sights
	moving: number, -- added at full walk speed (scaled by speed)
	crouch: number, -- multiplier while crouched
	bipod: number?, -- multiplier deployed
	perShot: number, -- bloom added per shot
	max: number, -- cap of the bloom
	recover: number, -- bloom lost per second
	pellets: number?, -- shotgun: pellets per shell...
	pelletCone: number?, -- ...in a cone of this half-angle around the shot's direction
}

export type RecoilDef = {
	-- gameplay (moves the aim, so the next bullets): degrees per shot
	climb: number,
	climbFirst: number, -- multiplier of the first shot of a burst
	yaw: number, -- random ±
	yawBias: number, -- constant drift per shot (+ = right)
	recover: number, -- fraction given back after the burst...
	recoverTime: number, -- ...over this many seconds
	-- the body (visual), springs (Handling, part 2)
	kick: number, -- gun pitch, degrees
	push: number, -- push back, studs
	roll: number, -- degrees, alternating sign each shot
	torso: number, -- Root pitch back, degrees
	frequency: number, -- Hz
	zeta: number, -- damping ratio
	shake: number, -- cosmetic camera shake, degrees
	bipod: number?, -- multipliers
	crouch: number?,
}

export type HandlingDef = {
	massKg: number, -- loaded
	adsTime: number,
	sprintToFire: number,
	raiseTime: number, -- low ready -> ready
	lowerTime: number, -- ready -> low ready
	drawTime: number,
	holsterTime: number,
	sprintIn: number,
	sprintOut: number,
	obstructIn: number,
	obstructOut: number,
	bipodDeploy: number?,
	bipodFold: number?,
	lookLagHz: number,
	lookLagMax: number, -- degrees
	walkSpeed: number, -- multipliers of the kit's speed
	adsWalkSpeed: number,
	canSprint: boolean,
	sprintSpeed: number, -- multiplier of the sprint speed (the LMG carries slower)
	tuckLength: number, -- studs: shoulder pocket -> muzzle (wall check)
	lowReadyAfter: number, -- seconds without firing / aiming before the gun drops to low ready
	fov: number, -- camera FOV while aiming (third person, irons / red dot)
}

-- Spent cases (Client/Firearms/Casings). Directions are along the gun's
-- EjectionPort marker (+X = the mean ejection direction) unless `dir` overrides it.
export type EjectDef = {
	kind: "Brass" | "Steel" | "Hull",
	when: "Shot" | "Cycle", -- on the shot frame, or on the bolt's case_eject event
	speed: { number }, -- {min, max} studs/s
	cone: number, -- degrees of random deviation round the direction
	spin: { number }, -- {min, max} revolutions per second
	drag: number, -- per second (air)
	-- 0..1: share of shots thrown steeply up and back (the pistol's "10 %")
	steepChance: number?,
	-- gun-space direction overriding the port's mean (the LMG throws its cases DOWN)
	dir: Vector3?,
	bottleneck: boolean, -- rolls in an arc round its neck once on the floor
	-- the LMG's links: their own spawn marker (LinkSpawn), speeds and spin
	links: { speed: { number }, spin: { number }, cone: number }?,
}

export type MuzzleDef = {
	flash: number, -- flash size, studs (one rendered frame)
	flashKind: "Star" | "Bloom" | "Brake" | "Hider",
	lightRange: number, -- studs
	lightBrightness: number,
	smoke: number, -- 0..1 density of the puff
	portPuff: boolean, -- a wisp out of the ejection port
	hazeAfter: number?, -- shots in a burst before the barrel hazes
	dustKick: boolean?, -- a floor / sill within 1.5 studs below the muzzle kicks dust
	tracerEvery: number?, -- every Nth round is a tracer (nil: none)
	tracerColor: Color3?,
}

export type SoundDef = {
	shot: string, -- cue prefix in Shared/Firearms/SoundBank (<shot>_Near, _Far, _Tail, _Mech)
	supersonic: boolean, -- a crack when the bullet passes near the listener
	dry: string, -- dry click cue
	caseKind: "Brass" | "Steel" | "Hull" | "Heavy",
	mag: "Polymer" | "Steel" | "Cloth", -- dropped feed impact family
}

export type FeedDropDef = {
	kind: "Mag" | "Pouch" | "None",
	material: "Polymer" | "Steel" | "Cloth",
	-- extra spin given on the drop (rad/s, gun space axis), on top of the hand's motion
	spin: Vector3,
	-- extra push (studs/s, gun space)
	push: Vector3,
	elasticity: number,
	friction: number,
}

export type CarryDef = {
	-- where the gun rides when it is not drawn: a hip holster (pistol) or slung on the back
	kind: "Hip" | "Back",
	-- Torso space CFrame of the gun root (GunModel uses it; HolsterMount / BackMount
	-- marker on it)
	cf: CFrame,
	strap: Color3?, -- the sling's colour (long guns)
}

export type FirearmDef = {
	id: string, -- "Pistol"... = Defs/<id>, Models/<id>, Timelines/<id>
	name: string, -- in-game name (English)
	class: Class,
	caliber: string,
	order: number, -- display / dev-cycle order
	modes: { FireMode },
	rpm: number, -- cyclic; semi is capped at it
	feed: Feed,
	capacity: number, -- mag / tube / belt rounds
	closedBolt: boolean, -- closed bolt: +1 in the chamber
	lockBack: boolean, -- the slide / bolt stays open on the last round
	startReserve: number, -- rounds carried besides the loaded feed (pickup)
	damage: number, -- per bullet / pellet, Torso, at the muzzle
	zones: Zones,
	falloff: { full: number, zero: number, min: number }, -- studs, studs, multiplier
	range: number, -- studs, the ray length
	pierce: number, -- bodies a bullet passes through (0 = stops on the first)
	pierceScale: number, -- damage multiplier after a body
	glass: "Through" | "Stop", -- city glass panes: rifle-class bullets go through (× 0.85)
	velocity: number, -- studs/s (tracer speed, far-sound delay, the sniper's unused projectile)
	spread: SpreadDef,
	recoil: RecoilDef,
	handling: HandlingDef,
	eject: EjectDef,
	muzzle: MuzzleDef,
	sounds: SoundDef,
	feedDrop: FeedDropDef,
	carry: CarryDef,
	optic: { kind: "Irons" | "RedDot" | "Scope" | "Prism", fov: number?, magnification: number? },
	originSlack: number, -- studs: muzzle within this of the head (server check, before speed)
	displayScale: number, -- 1 = real size
}

-- Timelines (generated later by tools/anim/gun_clips.py from the clips; placeholders
-- until then): the server runs reloads / cycles from these numbers, the client plays
-- the clips that produced them.
export type TimelineEvent = { time: number, name: string, snap: boolean? }
export type Timeline = {
	length: number,
	events: { TimelineEvent },
	commitAt: number?, -- the round count is set here (a cancel before it changes nothing more)
	cancelUntil: number?, -- a shot / sprint / ReloadCancel before this stops the action
	loop: boolean?, -- the shotgun's shell loop: repeated while shells are missing
}
export type Timelines = { [string]: Timeline }

-- Generated model data (Models/<Gun>, tools/guns/export_luau.py). Gun space: studs,
-- -Z = muzzle (LookVector), +X = right, +Y = up, origin at the breech face.
export type PartInfo = {
	paint: string,
	group: string, -- "Body" or the moving part (hinge) that carries it
	atlas: string, -- texture atlas key (atlases[...])
	centre: Vector3, -- bounding-box centre (what an imported MeshPart reports)
	size: Vector3,
	fit: number?, -- 1-3: fit the imported model, 4: check it
}
export type HingeInfo = {
	type: string, -- "rotate" (degrees) | "slide" | "detach" (studs) | "show"
	pivot: Vector3,
	axis: Vector3, -- unit, gun space (right-hand rule for rotations)
	rest: number,
	min: number,
	max: number,
	parent: string, -- "Body" or the hinge it rides on
	["then"]: { type: string, axis: Vector3, max: number }?, -- a chained second motion
	detach: boolean?, -- comes free after its motion (mags, the pouch)
	detents: { [string]: number }?,
	lockBack: boolean?,
}
export type PrimDef = {
	name: string, -- the FBX part it stands for
	shape: string, -- "Block" | "Cyl" | "Wedge"
	cf: CFrame, -- gun space
	size: Vector3,
	paint: string,
	group: string,
}
export type HoldInfo = {
	gunInTorso: CFrame?,
	gunInHRP: CFrame?,
	weld: CFrame?, -- the gun in Right Arm space
	pose: { [string]: { number } }, -- joint -> degrees (Root: + x, y, z studs)
	aim: { yaw: number, pitch: number, cant: number },
	owner: string?,
	residuals: { [string]: number },
}
export type AtlasIds = { color: number, normal: number, roughness: number, metalness: number }
export type FeedInfo = {
	part: string, -- "Magazine" / "AmmoPouch"
	members: { string }, -- the parts that drop with it
	centre: Vector3,
	size: Vector3,
	massKg: number,
	massEmptyKg: number,
}
export type GunModelData = {
	id: string,
	massKg: number,
	dims: { [string]: number }, -- metres
	parts: { [string]: PartInfo },
	fit: { { name: string, centre: Vector3 } },
	hinges: { [string]: HingeInfo },
	markers: { [string]: CFrame }, -- LookVector = the marker's +X, UpVector = its +Z
	prims: { PrimDef },
	case: { PrimDef }?, -- separate models: case axis = LookVector, toward the mouth
	round: { PrimDef }?,
	link: { PrimDef }?,
	feed: FeedInfo?,
	atlases: { [string]: AtlasIds },
	holds: { [string]: HoldInfo },
	aimRows: { { pitch: number, stance: string } }?,
}

-- Ammo state of one carried gun (server truth; the client mirrors it to predict).
export type AmmoState = {
	mag: number?, -- rounds in the mag / tube / belt; nil = no mag (or pouch) in
	chambered: boolean,
	reserve: number,
	boltOpen: boolean, -- slide / bolt locked back (or the LMG's open bolt is NOT this)
	needsCycle: boolean, -- bolt-action: the spent case is still in the chamber
	coverOpen: boolean, -- LMG feed cover
}

return nil
