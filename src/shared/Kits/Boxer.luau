--!strict
-- BOXER: a clean, technical, fast fighter. Tight guard, short sharp
-- punches thrown with the hips, head movement. Less raw damage than the
-- Street Brawler, more speed and control.
--
-- Pure data, read by Shared/Kits (see KitTypes). `at` values = the impact
-- keyframes of the animations (Client/Animation/CombatClips).

local KitTypes = require(script.Parent.KitTypes)

local JAB = Vector3.new(5, 5, 5.5)
local CLOSE = Vector3.new(5, 5, 5)

-- A jab of the rush: light, short stun that keeps the victim in the flurry.
local function jab(at: number, damage: number?): KitTypes.HitDef
	return {
		at = at,
		damage = damage or 3,
		zone = "Head",
		stun = 0.35,
		hitbox = JAB,
		forward = 3.2,
	}
end

local kit: KitTypes.KitDef = {
	id = "Boxer",
	name = "BOXER",
	description = "Footwork, a tight guard and fast hands.",
	order = 2,
	available = true,

	moves = {
		{
			id = "JabRush",
			name = "JAB RUSH",
			description = "Four quick jabs while stepping in.",
			animation = "Boxer_JabRush",
			duration = 0.75,
			cooldown = 7,
			stamina = 15,
			hits = { jab(0.12), jab(0.27), jab(0.42), jab(0.57) },
		},
		{
			id = "Uppercut",
			name = "UPPERCUT",
			description = "Under the chin. Lifts them off the ground.",
			animation = "Boxer_Uppercut",
			duration = 0.75,
			cooldown = 9,
			stamina = 20,
			hits = {
				{
					at = 0.25,
					damage = 10,
					zone = "Head",
					stun = 0,
					hitbox = CLOSE,
					forward = 2.8,
					knockdown = 1.2,
					knockback = 8,
					launch = 30,
				},
			},
		},
		{
			id = "Slip",
			name = "SLIP",
			description = "Slips a punch, counters with a hook.",
			animation = "Boxer_Slip",
			duration = 0.6,
			cooldown = 8,
			stamina = 15,
			hits = {},
			counter = {
				window = 0.5,
				animation = "Boxer_SlipCounter",
				at = 0.18,
				hit = {
					at = 0,
					damage = 8,
					zone = "Head",
					stun = 0.7,
					hitbox = CLOSE,
					forward = 2.8,
				},
			},
		},
		{
			id = "LiverShot",
			name = "LIVER SHOT",
			description = "Body hook. Empties their stamina.",
			animation = "Boxer_LiverShot",
			duration = 0.8,
			cooldown = 9,
			stamina = 15,
			hits = {
				{
					at = 0.28,
					damage = 8,
					zone = "Torso",
					stun = 0.9,
					hitbox = CLOSE,
					forward = 2.8,
					staminaDrain = 40,
				},
			},
		},
	},

	awakening = {
		name = "KNOCKOUT MODE",
		description = "Locks in. Faster combinations, and key 4 becomes the Knockout Combo.",
		animation = "Boxer_Awaken",
		duration = 10,
		damageMultiplier = 1.15,
		moves = {
			{
				id = "JabRushPlus",
				name = "JAB FLURRY",
				description = "Six punches, one right cross.",
				animation = "Boxer_JabRushPlus",
				duration = 0.9,
				cooldown = 6,
				stamina = 12,
				hits = {
					jab(0.10),
					jab(0.22),
					jab(0.34),
					jab(0.46),
					jab(0.58, 6),
					jab(0.72),
				},
			},
			{
				id = "UppercutPlus",
				name = "RISING UPPERCUT",
				description = "Sends them flying.",
				animation = "Boxer_Uppercut",
				duration = 0.75,
				cooldown = 7,
				stamina = 15,
				hits = {
					{
						at = 0.25,
						damage = 13,
						zone = "Head",
						stun = 0,
						hitbox = CLOSE,
						forward = 2.8,
						knockdown = 1.6,
						knockback = 14,
						launch = 42,
					},
				},
			},
			{
				id = "SlipPlus",
				name = "SLIP & HOOK",
				description = "Longer slip, harder counter.",
				animation = "Boxer_Slip",
				duration = 0.6,
				cooldown = 6,
				stamina = 12,
				hits = {},
				counter = {
					window = 0.6,
					animation = "Boxer_SlipCounter",
					at = 0.18,
					hit = {
						at = 0,
						damage = 11,
						zone = "Head",
						stun = 1.2,
						hitbox = CLOSE,
						forward = 2.8,
					},
				},
			},
			{
				id = "KnockoutCombo",
				name = "KNOCKOUT COMBO",
				description = "Body, head, head, uppercut.",
				animation = "Boxer_KnockoutCombo",
				duration = 1.6,
				cooldown = 12,
				stamina = 25,
				chain = true,
				hits = {
					{
						at = 0.2,
						damage = 6,
						zone = "Torso",
						stun = 0.5,
						hitbox = CLOSE,
						forward = 2.8,
						staminaDrain = 20,
					},
					{
						at = 0.5,
						damage = 6,
						zone = "Head",
						stun = 0.5,
						hitbox = CLOSE,
						forward = 2.8,
					},
					{
						at = 0.85,
						damage = 7,
						zone = "Head",
						stun = 0.6,
						hitbox = CLOSE,
						forward = 2.8,
					},
					{
						at = 1.25,
						damage = 12,
						zone = "Head",
						stun = 0,
						hitbox = CLOSE,
						forward = 2.8,
						knockdown = 2.2,
						knockback = 18,
						launch = 40,
					},
				},
			},
		},
	},
}

return kit
