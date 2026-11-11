--!strict
-- STREET BRAWLER: a dirty, scrappy bar-fight brawler. Not a martial
-- artist: heavy, opportunistic, uses whatever is at hand.
--
-- Pure data, read by Shared/Kits (see the types there). To rebalance the
-- kit, change the numbers here: the server and the HUD both follow.
--
-- `at` values = the impact keyframe of each animation (Client/Animation/
-- CombatClips): change one only together with its clip.

local KitTypes = require(script.Parent.KitTypes)

local HEAD = Vector3.new(5, 5, 5.5)
local WIDE = Vector3.new(7, 5, 6)

local kit: KitTypes.KitDef = {
	id = "StreetBrawler",
	name = "STREET BRAWLER",
	description = "Bar fights, broken bottles and no rules. Hits hard, fights dirty.",
	order = 1,
	available = true,

	moves = {
		{
			id = "BottleSmash",
			name = "BOTTLE SMASH",
			description = "Smashes a bottle over the head. The cut keeps bleeding.",
			animation = "Brawler_Bottle",
			duration = 0.9,
			cooldown = 8,
			stamina = 15,
			prop = "Bottle",
			hits = {
				{
					at = 0.32,
					damage = 9,
					zone = "Head",
					stun = 0.7,
					hitbox = HEAD,
					forward = 3,
					bleed = { perSecond = 2, duration = 4 },
					breaksProp = true,
				},
			},
		},
		{
			id = "Headbutt",
			name = "HEADBUTT",
			description = "Grabs the collar and drives the forehead in. Long stun.",
			animation = "Brawler_Headbutt",
			duration = 0.7,
			cooldown = 6,
			stamina = 10,
			hits = {
				{ at = 0.22, damage = 7, zone = "Head", stun = 1.0, hitbox = HEAD, forward = 2.8 },
			},
		},
		{
			id = "Tackle",
			name = "TACKLE",
			description = "A low shoulder charge that takes the opponent off his feet.",
			animation = "Brawler_Tackle",
			duration = 0.9,
			cooldown = 10,
			stamina = 20,
			hits = {},
			charge = {
				speed = 40,
				from = 0.1,
				to = 0.55,
				hit = {
					at = 0.1,
					damage = 8,
					zone = "Torso",
					stun = 0,
					hitbox = WIDE,
					forward = 2,
					knockdown = 1.4,
					knockback = 30,
					unblockable = true,
				},
			},
		},
		{
			id = "DirtyKick",
			name = "DIRTY KICK",
			description = "A mean kick to the shin. Slows the opponent down.",
			animation = "Brawler_DirtyKick",
			duration = 0.6,
			cooldown = 7,
			stamina = 10,
			hits = {
				{
					at = 0.2,
					damage = 6,
					zone = "Legs",
					stun = 0.4,
					hitbox = HEAD,
					forward = 3,
					slow = { multiplier = 0.6, duration = 3 },
				},
			},
		},
	},

	awakening = {
		name = "STREET FURY",
		description = "Snaps. For a few seconds every move turns nastier and nothing stops him.",
		animation = "Brawler_Awaken",
		duration = 10,
		damageMultiplier = 1.2,
		moves = {
			{
				id = "BrokenBottle",
				name = "BROKEN BOTTLE",
				description = "Two slashes with the broken neck. Deep bleeding.",
				animation = "Brawler_BrokenBottle",
				duration = 1.0,
				cooldown = 6,
				stamina = 10,
				prop = "BrokenBottle",
				hits = {
					{ at = 0.2, damage = 6, zone = "Head", stun = 0.5, hitbox = WIDE, forward = 3 },
					{
						at = 0.45,
						damage = 8,
						zone = "Head",
						stun = 0.7,
						hitbox = WIDE,
						forward = 3,
						bleed = { perSecond = 4, duration = 5 },
					},
				},
			},
			{
				id = "DoubleHeadbutt",
				name = "DOUBLE HEADBUTT",
				description = "Holds the collar and headbutts twice.",
				animation = "Brawler_DoubleHeadbutt",
				duration = 1.0,
				cooldown = 5,
				stamina = 10,
				hits = {
					{
						at = 0.22,
						damage = 6,
						zone = "Head",
						stun = 0.6,
						hitbox = HEAD,
						forward = 2.8,
						pull = 12,
					},
					{
						at = 0.52,
						damage = 9,
						zone = "Head",
						stun = 1.6,
						hitbox = HEAD,
						forward = 2.8,
					},
				},
			},
			{
				id = "TackleSlam",
				name = "TACKLE SLAM",
				description = "Tackles, then hammers the opponent on the ground.",
				animation = "Brawler_Tackle",
				duration = 0.9,
				cooldown = 8,
				stamina = 15,
				hits = {},
				charge = {
					speed = 44,
					from = 0.1,
					to = 0.55,
					hit = {
						at = 0.1,
						damage = 8,
						zone = "Torso",
						stun = 0,
						hitbox = WIDE,
						forward = 2,
						knockdown = 2.2,
						knockback = 20,
						unblockable = true,
					},
				},
				-- The ground strike reuses the Finisher clip (impact at 0.45 s).
				followUp = { animation = "Finisher", delay = 0.35, at = 0.45, damage = 10 },
			},
			{
				id = "KickCombo",
				name = "KICK COMBO",
				description = "A low kick to the shin, then a high kick that launches.",
				animation = "Brawler_KickCombo",
				duration = 0.95,
				cooldown = 6,
				stamina = 12,
				hits = {
					{
						at = 0.2,
						damage = 5,
						zone = "Legs",
						stun = 0.5,
						hitbox = HEAD,
						forward = 3,
						slow = { multiplier = 0.6, duration = 2 },
					},
					{
						at = 0.5,
						damage = 9,
						zone = "Head",
						stun = 0,
						hitbox = HEAD,
						forward = 3,
						knockback = 50,
						knockdown = 1.2,
					},
				},
			},
		},
	},
}

return kit
