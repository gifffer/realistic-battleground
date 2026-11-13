--!strict
-- DR. RIFT: an old mad scientist, half of him rebuilt with scrap (a
-- mechanical left arm with a gravity glove, a lens for a right eye). He
-- doesn't box: he throws acid, burns people with a ray gun, blows them away
-- with the glove and goes where he wants through portals. Fragile (he takes
-- a bit more from every hit), but always somewhere else.
--
-- Pure data, read by Shared/Kits (see KitTypes). `at` / `release` values =
-- the keyframes of the animations (Client/Animation/RiftClips). The gadgets
-- (flasks, rays, portals, the shockwave, the clones) are run by
-- Server/Systems/Combat/Gadgets and Clones; their look is Client/Combat/RiftFx.

local KitTypes = require(script.Parent.KitTypes)

-- (A gadget's hit doesn't use a hitbox: the flask, ray or wave decides who.)
local NONE = Vector3.zero

local ACID: KitTypes.BurnDef = { kind = "Acid", perSecond = 4, duration = 4 }
local ACID_PUDDLE: KitTypes.BurnDef = { kind = "Acid", perSecond = 3, duration = 1.5 }
local BURN: KitTypes.BurnDef = { kind = "Fire", perSecond = 3, duration = 3 }
local BIG_BURN: KitTypes.BurnDef = { kind = "Fire", perSecond = 4, duration = 3 }
local BLAST_BURN: KitTypes.BurnDef = { kind = "Fire", perSecond = 2, duration = 2 }

local kit: KitTypes.KitDef = {
	id = "Rift",
	name = "DR. RIFT",
	description = "A cyborg mad scientist: acid, a ray gun, a gravity glove and a portal gun.",
	order = 4,
	available = true,
	unlockLevel = 8,
	price = 800,
	damageTaken = 1.05, -- an old man: every hit hurts him a bit more

	moves = {
		{
			id = "AcidFlask",
			name = "ACID FLASK",
			description = "Throws a flask of acid. It burns, and the puddle keeps burning.",
			animation = "Rift_Flask",
			duration = 0.75,
			cooldown = 7,
			stamina = 15,
			hits = {},
			gadget = {
				flask = {
					kind = "Acid",
					release = 0.34,
					speed = 70,
					lift = 12,
					gravity = 75,
					lifetime = 2.2,
					hit = {
						at = 0,
						damage = 6,
						stun = 0.5,
						hitbox = NONE,
						forward = 0,
						burn = ACID,
						slow = { multiplier = 0.75, duration = 2 },
					},
					radius = 7,
					splash = {
						at = 0,
						damage = 4,
						stun = 0.35,
						hitbox = NONE,
						forward = 0,
						burn = ACID,
						slow = { multiplier = 0.75, duration = 2 },
					},
					puddle = { radius = 5, seconds = 5, burn = ACID_PUDDLE },
				},
			},
		},
		{
			id = "RayGun",
			name = "RAY GUN",
			description = "A burning ray, straight where he aims.",
			animation = "Rift_RayGun",
			duration = 0.7,
			cooldown = 6,
			stamina = 15,
			hits = {},
			gadget = {
				ray = {
					at = 0.32,
					range = 60,
					width = 0.6,
					pierce = false,
					hit = {
						at = 0,
						damage = 10,
						stun = 0.45,
						hitbox = NONE,
						forward = 0,
						knockback = 12,
						burn = BURN,
					},
				},
			},
		},
		{
			id = "GravityGlove",
			name = "GRAVITY GLOVE",
			description = "His metal hand pushes the air. Sends them flying, through a guard.",
			animation = "Rift_Glove",
			duration = 0.8,
			cooldown = 9,
			stamina = 20,
			hits = {
				{
					at = 0.36,
					damage = 8,
					zone = "Torso",
					stun = 0.8,
					hitbox = Vector3.new(9, 6, 11),
					forward = 5.5,
					knockback = 75,
					knockdown = 1.1,
					launch = 12,
					unblockable = true,
				},
			},
		},
		{
			id = "PortalGun",
			name = "PORTAL GUN",
			description = "One portal where he aims, one in front of him: he steps through.",
			animation = "Rift_Portal",
			duration = 1.1,
			cooldown = 10,
			stamina = 20,
			hits = {},
			gadget = {
				portal = {
					at = 0.28,
					open = 0.52,
					travel = 0.78,
					range = 80,
					maxPitch = 25,
					failCooldown = 2.5,
				},
			},
		},
	},

	awakening = {
		name = "DIMENSION RIFT",
		description = "Two of him step out of portals and fight with him.",
		animation = "Rift_Awaken",
		duration = 12,
		damageMultiplier = 1.15,
		clones = { count = 2, damage = 0.5 },
		moves = {
			{
				id = "ExplosiveFlask",
				name = "EXPLOSIVE FLASK",
				description = "A flask that blows up. Everyone around goes flying.",
				animation = "Rift_FlaskBomb",
				duration = 0.8,
				cooldown = 6,
				stamina = 15,
				hits = {},
				gadget = {
					flask = {
						kind = "Explosive",
						release = 0.36,
						speed = 70,
						lift = 14,
						gravity = 75,
						lifetime = 2.2,
						hit = {
							at = 0,
							damage = 8,
							stun = 0.6,
							hitbox = NONE,
							forward = 0,
						},
						radius = 10,
						splash = {
							at = 0,
							damage = 14,
							stun = 0.8,
							hitbox = NONE,
							forward = 0,
							knockdown = 1.3,
							knockback = 55,
							launch = 24,
							burn = BLAST_BURN,
						},
					},
				},
			},
			{
				id = "OverchargedRay",
				name = "OVERCHARGED RAY",
				description = "A huge ray that goes through everyone in line.",
				animation = "Rift_MegaRay",
				duration = 1,
				cooldown = 6,
				stamina = 15,
				hits = {},
				gadget = {
					ray = {
						at = 0.45,
						range = 70,
						width = 1.4,
						pierce = true,
						hit = {
							at = 0,
							damage = 15,
							stun = 0.6,
							hitbox = NONE,
							forward = 0,
							knockback = 30,
							burn = BIG_BURN,
						},
					},
				},
			},
			{
				id = "RiftSwarm",
				name = "RIFT SWARM",
				description = "His clones go through portals to the one he points at and beat them up.",
				animation = "Rift_Swarm",
				duration = 0.9,
				cooldown = 10,
				stamina = 15,
				hits = {},
				gadget = {
					swarm = {
						at = 0.35,
						range = 35,
						hits = {
							{ at = 0.3, damage = 5, stun = 0.6, hitbox = NONE, forward = 0 },
							{ at = 0.6, damage = 5, stun = 0.6, hitbox = NONE, forward = 0 },
							{
								at = 0.95,
								damage = 7,
								stun = 0.8,
								hitbox = NONE,
								forward = 0,
								knockdown = 1,
								knockback = 35,
								launch = 20,
							},
						},
					},
				},
			},
			{
				id = "GravitySlam",
				name = "GRAVITY SLAM",
				description = "The glove hits the floor: a shockwave all around him.",
				animation = "Rift_Slam",
				duration = 1,
				cooldown = 8,
				stamina = 20,
				hits = {},
				gadget = {
					wave = {
						at = 0.55,
						radius = 13,
						hit = {
							at = 0,
							damage = 12,
							zone = "Torso",
							stun = 0.8,
							hitbox = NONE,
							forward = 0,
							knockdown = 1.4,
							knockback = 45,
							launch = 30,
							unblockable = true,
						},
					},
				},
			},
		},
	},

	-- A portal opened around their waist, then closed: cut in two.
	finisher = {
		animation = "Rift_FinisherPortalCut",
		impact = 2.55,
		duration = 4.6,
		cinematic = "PortalCut",
	},
}

return kit
