--!strict
-- THE PYROMANIAC: a firebug in a stained work jacket. A brass Zippo, a few
-- wine bottles of petrol with rags stuffed in their necks, a red jerrycan.
-- He doesn't hit hard: he sets people on fire and keeps them burning.
--
-- Fire is real here: it doesn't burst into a magic blaze, it catches. A
-- Molotov breaks and the petrol burns on the floor for a few seconds, dying
-- out patch by patch; a lighter flare scorches a face; fuel he splashes on
-- someone makes the next fire on them far worse (Shared/PyroConfig). Every
-- burn goes through the server's burn slot (Combat startBurning: "Fire")
-- and the burn system (Server Combat/Burns, Client Combat/Burns): degrees
-- that deepen where it touched, clothes charring, flames, smoke.
--
-- Pure data, read by Shared/Kits (see KitTypes). `at` / `release` / `from`
-- values = the keyframes of the clips (Client/Animation/PyroClips). The
-- Molotov and the cones are run by Server/Systems/Combat/Gadgets; their look
-- is Client/Combat/PyroFx, their sounds Shared/SoundCues.

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

local kit: KitTypes.KitDef = {
	id = "Pyromaniac",
	name = "PYROMANIAC",
	description = "A firebug with a Zippo, a jerrycan and a crate of Molotovs. Everything burns.",
	order = 6,
	available = true,
	unlockLevel = 6,
	price = 650,

	moves = {
		{
			id = "ZippoFlare",
			name = "ZIPPO FLARE",
			description = "Flicks his lighter open and squirts fluid through the flame, into their face.",
			animation = "Pyro_Zippo",
			duration = 0.8,
			cooldown = 6,
			stamina = 12,
			hits = {
				{
					at = 0.42,
					damage = 6,
					zone = "Head",
					stun = 0.6, -- (blinded a moment)
					hitbox = Vector3.new(5, 5, 6),
					forward = 3.5,
					burn = FLARE,
				},
			},
		},
		{
			id = "Molotov",
			name = "MOLOTOV",
			description = "Lights the rag and lobs the bottle. The petrol burns on the floor.",
			animation = "Pyro_Molotov",
			duration = 1,
			cooldown = 11,
			stamina = 20,
			hits = {},
			gadget = {
				flask = {
					kind = "Molotov",
					release = 0.68,
					speed = 62,
					lift = 14,
					gravity = 75,
					lifetime = 2.4,
					-- (on a body: the bottle breaks on them, they're soaked
					-- and alight)
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
			id = "FireBreath",
			name = "FIRE BREATH",
			description = "A mouthful of fuel spat through his lighter: a cone of fire in front of him.",
			animation = "Pyro_Breath",
			duration = 1.35,
			cooldown = 10,
			stamina = 20,
			hits = {},
			gadget = {
				cone = {
					kind = "Flame",
					from = 0.55,
					to = 1,
					tick = 0.15,
					range = 13,
					angle = 24,
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
			id = "Douse",
			name = "DOUSE",
			description = "Swings the jerrycan: petrol all over them. Fire burns them far worse for a while.",
			animation = "Pyro_Douse",
			duration = 0.9,
			cooldown = 9,
			stamina = 15,
			hits = {},
			gadget = {
				cone = {
					kind = "Fuel",
					from = 0.42,
					to = 0.42,
					tick = 1,
					range = 10,
					angle = 32,
					douse = 8,
					hit = {
						at = 0,
						damage = 2,
						stun = 0.5, -- (petrol in the eyes)
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
		description = "Pours petrol on his own forearms and lights them. His fists burn.",
		animation = "Pyro_Awaken",
		duration = 12,
		damageMultiplier = 1.15,
		moves = {
			{
				id = "BurningFist",
				name = "BURNING FIST",
				description = "A hook with a blazing fist. It sets them alight.",
				animation = "Pyro_FirePunch",
				duration = 0.6,
				cooldown = 3,
				stamina = 10,
				hits = {
					{
						at = 0.24,
						damage = 8,
						stun = 0.6,
						hitbox = Vector3.new(5, 5, 5.5),
						forward = 3,
						knockback = 10,
						burn = FIST,
					},
				},
			},
			{
				id = "Firebomb",
				name = "FIREBOMB",
				description = "A bigger bottle, lit off his own fist. A wider, longer fire.",
				animation = "Pyro_Firebomb",
				duration = 0.75,
				cooldown = 7,
				stamina = 15,
				hits = {},
				gadget = {
					flask = {
						kind = "Molotov",
						release = 0.42,
						speed = 66,
						lift = 14,
						gravity = 75,
						lifetime = 2.4,
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
				id = "InfernoBreath",
				name = "INFERNO BREATH",
				description = "A longer, wider gout of fire.",
				animation = "Pyro_BreathBig",
				duration = 1.4,
				cooldown = 7,
				stamina = 15,
				hits = {},
				gadget = {
					cone = {
						kind = "Flame",
						from = 0.55,
						to = 1.15,
						tick = 0.15,
						range = 17,
						angle = 30,
						hit = {
							at = 0,
							damage = 2.5,
							stun = 0.35,
							hitbox = NONE,
							forward = 0,
							burn = INFERNO,
						},
					},
				},
			},
			{
				id = "BurningRush",
				name = "BURNING RUSH",
				description = "Charges in arms first and takes them down, alight.",
				animation = "Pyro_Rush",
				duration = 0.9,
				cooldown = 8,
				stamina = 20,
				hits = {},
				charge = {
					speed = 44,
					from = 0.1,
					to = 0.55,
					hit = {
						at = 0.1,
						damage = 9,
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
			},
		},
	},

	-- Cinematic kill (Shared/Finishers "Immolate").
	finisher = {
		name = "IMMOLATION",
		description = "Petrol over the body, the lighter dropped on it. Nobody gets up.",
		animation = "Pyro_FinisherImmolate",
		impact = 4.6,
		duration = 5.8,
		cinematic = "Immolate",
	},
}

return table.freeze(kit)
