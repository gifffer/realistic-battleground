--!strict
-- BULL: a fighter who fights like one. Horns on his head (Client/Combat/
-- KitLooks), all weight and rage: he charges, gores, stamps the ground and
-- tosses people over. Walks faster than the others. Finisher: gored on
-- his horns, lifted, shaken, slammed down.
--
-- Pure data, read by Shared/Kits (see KitTypes). `at` values = the impact
-- keyframes of the animations (Client/Animation/CombatClips).

local KitTypes = require(script.Parent.KitTypes)

local CLOSE = Vector3.new(5, 6, 5)

local kit: KitTypes.KitDef = {
	id = "Bull",
	name = "BULL",
	description = "Horns, weight and rage. Charges, gores and tramples.",
	order = 6,
	available = true,
	speed = 1.15, -- (a bull: walks faster than the others)

	-- Cinematic kill (Shared/Finishers "Gore").
	finisher = {
		animation = "Bull_Finisher",
		impact = 3.4,
		duration = 4.4,
		cinematic = "Gore",
	},

	moves = {
		{
			id = "GoreCharge",
			name = "GORE CHARGE",
			description = "Head down, horns first: charges and throws the first one he hits.",
			animation = "Bull_GoreCharge",
			duration = 1.2,
			cooldown = 10,
			stamina = 25,
			hits = {},
			charge = {
				speed = 46,
				breaks = 4, -- (goes through walls)
				from = 0.22,
				to = 1.0,
				hit = {
					at = 0,
					damage = 12,
					zone = "Torso",
					stun = 0,
					hitbox = Vector3.new(5, 6, 5),
					forward = 2,
					knockdown = 1.2,
					knockback = 52,
					launch = 18,
					bleed = { perSecond = 1.5, duration = 4 },
					bloodChance = { Head = 1, Torso = 1 },
				},
			},
		},
		{
			id = "HornHook",
			name = "HORN HOOK",
			description = "Drops low, then hooks them up into the air with his horns.",
			animation = "Bull_HornHook",
			duration = 0.8,
			cooldown = 8,
			stamina = 20,
			hits = {
				{
					at = 0.32,
					damage = 10,
					zone = "Torso",
					stun = 0,
					hitbox = CLOSE,
					forward = 2.8,
					breaks = 3.5,
					knockdown = 1.2,
					knockback = 10,
					launch = 40,
					bloodChance = { Head = 1, Torso = 1 },
				},
			},
		},
		{
			id = "Stampede",
			name = "STAMPEDE",
			description = "Rears up and stamps the ground: everyone close falls and is slowed.",
			animation = "Bull_Stampede",
			duration = 1.0,
			cooldown = 11,
			stamina = 25,
			hits = {
				{
					at = 0.5,
					damage = 8,
					zone = "Legs",
					stun = 0,
					hitbox = Vector3.new(14, 6, 14),
					forward = 1,
					bloodChance = { Legs = 0.7, Torso = 0.6 },
					breaks = 8,
					knockdown = 0.8,
					knockback = 18,
					launch = 10,
					slow = { multiplier = 0.6, duration = 2.5 },
					unblockable = true,
				},
			},
		},
		{
			id = "BullToss",
			name = "BULL TOSS",
			description = "Grabs them by the waist and throws them over his head.",
			animation = "Bull_Toss",
			duration = 1.15,
			cooldown = 10,
			stamina = 20,
			chain = true,
			hits = {
				{
					at = 0.22,
					damage = 2,
					zone = "Torso",
					stun = 0.8,
					hitbox = CLOSE,
					forward = 2.8,
					pull = 14,
				},
				{
					at = 0.7,
					damage = 12,
					zone = "Torso",
					stun = 0,
					hitbox = CLOSE,
					forward = 2.8,
					knockdown = 1.5,
					knockback = 24,
					launch = 46,
					unblockable = true,
					bloodChance = { Torso = 0.8, Head = 0.8 },
				},
			},
		},
	},
}

return table.freeze(kit)
