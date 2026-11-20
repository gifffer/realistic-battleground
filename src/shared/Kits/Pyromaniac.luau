--!strict
-- THE PYROMANIAC: a firebug in a stained work jacket, with a home-made
-- flamethrower slung across his back (a fuel-pump nozzle for a grip, a
-- conduit loop for a stock, an olive gas bottle on its right flank, a
-- drilled exhaust-tube shroud, a copper pilot burner) and a brass Zippo.
-- He doesn't hit hard: he sets people on fire and keeps them burning.
--
-- One gun, four jets, each its own shape: a ball of fire that pops in
-- their face, a glob of burning napalm coughed in an arc, a long stream
-- he sweeps, a cold fan of raw fuel (fire burns them far worse after it,
-- Shared/PyroConfig). Awakened, the gun runs hot (a blue-white root on
-- every jet): a blowtorch lance, a napalm mortar, an inferno that lights
-- the floor, a charge behind a wedge of fire. Every burn goes through the
-- server's burn slot (Combat startBurning: "Fire") and the burn system
-- (Server Combat/Burns, Client Combat/Burns).
--
-- Pure data, read by Shared/Kits (see KitTypes). `at` / `release` / `from`
-- values = the keyframes of the clips (Client/Animation/PyroClips, made by
-- tools/anim/pyro_clips.py with the gun in his hands). The globs and the
-- cones are run by Server/Systems/Combat/Gadgets; their look is
-- Client/Combat/PyroFx (the gun: Client/Combat/Flamethrower), their sounds
-- Shared/SoundCues.

local KitTypes = require(script.Parent.KitTypes)

-- (A gadget's hit doesn't use a hitbox: the bottle or the cone decides who.)
local NONE = Vector3.zero

-- Fire on the skin (damage per second, seconds). A soaked target burns
-- harder and longer, and goes up all over (PyroConfig.DOUSED_*). Where it
-- burns and how deep: Server Combat/Burns (`dose` per hit: a cone hits
-- every tick, so a small one; `where`: a splash off the floor, the legs).
local FLARE: KitTypes.BurnDef = { kind = "Fire", perSecond = 3, duration = 2.5, dose = 1.1 }
local IGNITE: KitTypes.BurnDef = { kind = "Fire", perSecond = 4, duration = 4, dose = 1.4 }
local SPLASHED: KitTypes.BurnDef =
	{ kind = "Fire", perSecond = 3, duration = 3, dose = 0.8, where = "Legs" }
-- (a pool: dosed by the time stood in it, Burns.expose with no zone)
local POOL: KitTypes.BurnDef = { kind = "Fire", perSecond = 4, duration = 1.5 }
local BREATH: KitTypes.BurnDef = { kind = "Fire", perSecond = 3, duration = 3, dose = 0.35 }
local FIST: KitTypes.BurnDef = { kind = "Fire", perSecond = 3, duration = 2.5, dose = 0.7 }
local BIG_POOL: KitTypes.BurnDef = { kind = "Fire", perSecond = 5, duration = 1.5 }
local INFERNO: KitTypes.BurnDef = { kind = "Fire", perSecond = 4, duration = 3.5, dose = 0.3 }
-- (the blowtorch's lance: a focused, deep scar where it lands)
local TORCH: KitTypes.BurnDef =
	{ kind = "Fire", perSecond = 3, duration = 2.5, dose = 1, spot = true }
-- (the bow wave ahead of his charge: a lick of fire each tick)
local WEDGE: KitTypes.BurnDef = { kind = "Fire", perSecond = 3, duration = 2, dose = 0.25 }

local kit: KitTypes.KitDef = {
	id = "Pyromaniac",
	name = "PYROMANIAC",
	description = "A firebug with a home-made flamethrower and a Zippo. Everything burns.",
	order = 6,
	available = true,
	unlockLevel = 6,
	price = 650,

	moves = {
		{
			id = "FlashBurst",
			name = "FLASH BURST",
			description = "Swings the gun up and blips the trigger: a ball of fire bursts in their face.",
			animation = "Pyro_Burst",
			duration = 0.85,
			cooldown = 6,
			stamina = 12,
			hits = {
				{
					at = 0.42,
					damage = 6,
					zone = "Head",
					stun = 0.6, -- (blinded a moment)
					hitbox = Vector3.new(5, 5, 7),
					forward = 4.5, -- (1 to 8 studs: the gun's reach, point-blank too)
					burn = FLARE,
				},
			},
		},
		{
			id = "NapalmLob",
			name = "NAPALM LOB",
			description = "Chokes the valve and coughs a glob of burning napalm in an arc. It burns on the floor.",
			animation = "Pyro_Napalm",
			duration = 1,
			cooldown = 11,
			stamina = 20,
			hits = {},
			gadget = {
				flask = {
					kind = "Napalm",
					release = 0.62,
					speed = 58,
					lift = 18,
					gravity = 75,
					lifetime = 2.4,
					-- (the muzzle at the release, 35 deg up: tools/anim/pyro_clips.py --check)
					origin = Vector3.new(0.84, 2.7, -3),
					-- (on a body: it splats on them, they're soaked and alight)
					hit = {
						at = 0,
						damage = 6,
						stun = 0.5,
						hitbox = NONE,
						forward = 0,
						burn = IGNITE,
					},
					radius = 5,
					splash = {
						at = 0,
						damage = 3,
						stun = 0.3,
						hitbox = NONE,
						forward = 0,
						burn = SPLASHED,
					},
					fire = { radius = 6, seconds = 8, cells = 12, burn = POOL },
				},
			},
		},
		{
			id = "FlameStream",
			name = "FLAME STREAM",
			description = "Plants his feet and hoses them down: a long stream of fire he can sweep.",
			animation = "Pyro_Stream",
			duration = 1.3,
			cooldown = 10,
			stamina = 20,
			hits = {},
			gadget = {
				cone = {
					kind = "Flame",
					from = 0.45,
					to = 1,
					tick = 0.15,
					range = 14,
					angle = 22,
					hit = {
						at = 0,
						damage = 2,
						stun = 0.3,
						hitbox = NONE,
						forward = 0,
						burn = BREATH,
					},
				},
			},
		},
		{
			id = "FuelSpray",
			name = "FUEL SPRAY",
			description = "Kills the pilot and sprays them with raw fuel. Fire burns them far worse for a while.",
			animation = "Pyro_Spray",
			duration = 0.95,
			cooldown = 9,
			stamina = 15,
			hits = {},
			gadget = {
				cone = {
					kind = "Fuel",
					from = 0.45,
					to = 0.45,
					tick = 1,
					range = 10,
					angle = 34,
					douse = 8,
					hit = {
						at = 0,
						damage = 2,
						stun = 0.5, -- (fuel in the eyes)
						hitbox = NONE,
						forward = 0,
						slow = { multiplier = 0.8, duration = 2 },
					},
				},
			},
		},
	},

	awakening = {
		name = "BURNING MAN",
		description = "Opens the gas wide and torches the sky. The blowback sets his forearms alight; the gun runs hot.",
		animation = "Pyro_Awaken",
		duration = 12,
		damageMultiplier = 1.15,
		moves = {
			{
				id = "Blowtorch",
				name = "BLOWTORCH",
				description = "Rams the hot muzzle into them and lights a cutting flame point-blank.",
				animation = "Pyro_Torch",
				duration = 0.6,
				cooldown = 3,
				stamina = 10,
				hits = {
					{
						at = 0.26,
						damage = 8,
						stun = 0.6,
						hitbox = Vector3.new(5, 5, 6),
						forward = 3.5,
						knockback = 12,
						burn = TORCH,
					},
				},
			},
			{
				id = "NapalmMortar",
				name = "NAPALM MORTAR",
				description = "Braces the gun like a mortar and yanks the valve: a huge glob that splashes a crown of fire.",
				animation = "Pyro_Mortar",
				duration = 0.8,
				cooldown = 7,
				stamina = 15,
				hits = {},
				gadget = {
					flask = {
						kind = "Napalm",
						release = 0.45,
						speed = 60,
						lift = 24,
						gravity = 75,
						lifetime = 2.6,
						-- (the muzzle at the release, 45 deg up)
						origin = Vector3.new(0.78, 3.2, -2.4),
						hit = {
							at = 0,
							damage = 8,
							stun = 0.6,
							hitbox = NONE,
							forward = 0,
							burn = IGNITE,
						},
						radius = 6,
						splash = {
							at = 0,
							damage = 4,
							stun = 0.35,
							hitbox = NONE,
							forward = 0,
							burn = SPLASHED,
						},
						fire = { radius = 8, seconds = 10, cells = 16, burn = BIG_POOL },
					},
				},
			},
			{
				id = "Inferno",
				name = "INFERNO",
				description = "Cranks the gas wide open: a huge stream that rakes the floor and leaves it burning.",
				animation = "Pyro_Inferno",
				duration = 1.5,
				cooldown = 7,
				stamina = 15,
				hits = {},
				gadget = {
					cone = {
						kind = "Flame",
						from = 0.45,
						to = 1.25,
						tick = 0.15,
						range = 17,
						angle = 28,
						hit = {
							at = 0,
							damage = 2.5,
							stun = 0.35,
							hitbox = NONE,
							forward = 0,
							burn = INFERNO,
						},
						-- (the floor it raked catches: a small pool 9 studs ahead)
						scorch = {
							at = 9,
							fire = { radius = 5, seconds = 4, cells = 7, burn = POOL },
						},
					},
				},
			},
			{
				id = "TorchCharge",
				name = "TORCH CHARGE",
				description = "Charges behind a wedge of fire and rams them down with the gun.",
				animation = "Pyro_TorchCharge",
				duration = 0.9,
				cooldown = 8,
				stamina = 20,
				hits = {},
				charge = {
					speed = 44,
					from = 0.14,
					to = 0.55,
					hit = {
						at = 0.1,
						damage = 8,
						zone = "Torso",
						stun = 0,
						hitbox = Vector3.new(6, 6, 5),
						forward = 2,
						knockdown = 1.3,
						knockback = 32,
						unblockable = true,
						burn = FIST,
					},
				},
				gadget = {
					-- (the bow wave of fire ahead of him: blockable, no stun, so it
					-- never breaks the charge's contact)
					cone = {
						kind = "Flame",
						from = 0.14,
						to = 0.48,
						tick = 0.12,
						range = 8,
						angle = 30,
						hit = {
							at = 0,
							damage = 1,
							stun = 0,
							hitbox = NONE,
							forward = 0,
							burn = WEDGE,
						},
					},
				},
			},
		},
	},

	-- Cinematic kill (Shared/Finishers "Immolate").
	finisher = {
		name = "IMMOLATION",
		description = "Soaks them with raw fuel, lights the pilot with his Zippo, then hoses them down point-blank.",
		animation = "Pyro_FinisherImmolate",
		impact = 4.6,
		duration = 5.8,
		cinematic = "Immolate",
	},
}

return table.freeze(kit)
