--!strict
-- BOUNCER: a nightclub doorman. Huge, slow and patient: he doesn't trade
-- punches, he grabs. Shoves people out of his way, chokes them, picks them
-- up and slams them into the floor. Takes hits better than anyone, moves
-- slower than anyone.
--
-- Pure data, read by Shared/Kits (see KitTypes). `at` values = the impact
-- keyframes of the animations (Client/Animation/CombatClips); a grab's hits
-- are counted from the catch (the hold clips start then).

local KitTypes = require(script.Parent.KitTypes)

local WIDE = Vector3.new(6, 5, 5.5)
local HEAD = Vector3.new(5, 6, 5.5)
local GRAB = Vector3.new(4.5, 5, 4.5) -- arm's length, straight ahead

-- Where a slammed body is left (relative to his root, Client/Animation/
-- BouncerClips ends there): across in front of him on its back, head to his
-- left (Body Slam); along, head away from him, legs on his shoulders
-- (Powerbomb).
local SLAM_LAID = CFrame.new(0.2, -2.5, -2.4, 0, -1, 0, 0, 0, -1, 1, 0, 0)
local POWERBOMB_LAID = CFrame.new(0, -2.5, -2.5, -1, 0, 0, 0, 0, -1, 0, -1, 0)

-- One squeeze of a choke: little damage, the breath goes out of them.
local function squeeze(at: number, damage: number): KitTypes.HitDef
	return {
		at = at,
		damage = damage,
		zone = "Head",
		stun = 0.5,
		hitbox = GRAB,
		forward = 2,
		staminaDrain = 12,
	}
end

local kit: KitTypes.KitDef = {
	id = "Bouncer",
	name = "BOUNCER",
	description = "Huge and slow. He doesn't trade punches, he grabs.",
	order = 3,
	available = true,
	unlockLevel = 5,
	price = 500,
	damageTaken = 0.85,
	speed = 0.9,

	moves = {
		{
			id = "Shove",
			name = "SHOVE",
			description = "Both hands to the chest. Out of his way.",
			animation = "Bouncer_Shove",
			duration = 0.65,
			cooldown = 6,
			stamina = 10,
			hits = {
				{
					at = 0.22,
					damage = 6,
					zone = "Torso",
					stun = 0.6,
					hitbox = WIDE,
					forward = 3,
					knockback = 40,
				},
			},
		},
		{
			id = "Chokehold",
			name = "CHOKEHOLD",
			description = "Grabs them from behind and squeezes. Goes through a guard.",
			animation = "Bouncer_Grab",
			duration = 0.7,
			cooldown = 13,
			stamina = 20,
			hits = {},
			grab = {
				at = 0.28,
				hitbox = GRAB,
				forward = 2.4,
				damage = 2,
				duration = 1.9,
				distance = 1.3,
				facing = "away",
				animation = "Bouncer_Choke",
				victimAnimation = "Bouncer_ChokeVictim",
				hits = {
					squeeze(0.45, 4),
					squeeze(0.85, 4),
					squeeze(1.25, 4),
					-- Let go: they stagger away gasping, out of breath.
					{
						at = 1.9,
						damage = 3,
						zone = "Head",
						stun = 1.0,
						hitbox = GRAB,
						forward = 2,
						staminaDrain = 25,
					},
				},
			},
		},
		{
			id = "BodySlam",
			name = "BODY SLAM",
			description = "Lifts them up and slams them into the floor.",
			animation = "Bouncer_Grab",
			duration = 0.7,
			cooldown = 12,
			stamina = 25,
			hits = {},
			grab = {
				at = 0.28,
				hitbox = GRAB,
				forward = 2.4,
				damage = 2,
				duration = 1.0,
				distance = 1.5,
				facing = "toward",
				animation = "Bouncer_Slam",
				victimAnimation = "Bouncer_SlamVictim",
				laidAt = SLAM_LAID,
				hits = {
					{
						at = 1.0,
						damage = 14,
						zone = "Torso",
						stun = 0,
						hitbox = GRAB,
						forward = 2,
						knockdown = 1.6,
						knockback = 3,
						launch = 2,
					},
				},
			},
		},
		{
			id = "HammerFist",
			name = "HAMMER FIST",
			description = "Both fists down on the top of the head.",
			animation = "Bouncer_HammerFist",
			duration = 0.85,
			cooldown = 8,
			stamina = 15,
			hits = {
				{
					at = 0.4,
					damage = 11,
					zone = "Head",
					stun = 1.1,
					hitbox = HEAD,
					forward = 3,
				},
			},
		},
	},

	-- Cinematic kill (Shared/Finishers "ArmRip"): his foot on their chest,
	-- he pulls their right arm until it comes off at the shoulder.
	finisher = {
		animation = "Bouncer_FinisherArmRip",
		impact = 2.35,
		duration = 4.6,
		cinematic = "ArmRip",
	},

	awakening = {
		name = "LAST CALL",
		description = "Closing time. Harder grabs, longer holds, and key 1 throws them out.",
		animation = "Bouncer_Awaken",
		duration = 10,
		damageMultiplier = 1.2,
		moves = {
			{
				id = "ThrowOut",
				name = "THROW OUT",
				description = "By the collar and the belt, thrown across the room.",
				animation = "Bouncer_Grab",
				duration = 0.7,
				cooldown = 7,
				stamina = 15,
				hits = {},
				grab = {
					at = 0.28,
					hitbox = GRAB,
					forward = 2.4,
					damage = 2,
					duration = 0.6,
					distance = 1.5,
					facing = "toward",
					animation = "Bouncer_ThrowOut",
					victimAnimation = "Bouncer_ThrowVictim",
					hits = {
						{
							at = 0.6,
							damage = 10,
							zone = "Torso",
							stun = 0,
							hitbox = GRAB,
							forward = 2,
							knockdown = 1.6,
							knockback = 55,
							launch = 16,
						},
					},
				},
			},
			{
				id = "SleeperHold",
				name = "SLEEPER HOLD",
				description = "A longer choke. They pass out.",
				animation = "Bouncer_Grab",
				duration = 0.7,
				cooldown = 11,
				stamina = 20,
				hits = {},
				grab = {
					at = 0.28,
					hitbox = GRAB,
					forward = 2.4,
					damage = 2,
					duration = 2.6,
					distance = 1.3,
					facing = "away",
					animation = "Bouncer_Sleeper",
					victimAnimation = "Bouncer_SleeperVictim",
					hits = {
						squeeze(0.45, 5),
						squeeze(0.85, 5),
						squeeze(1.25, 5),
						squeeze(1.65, 5),
						-- They go limp: dropped to the floor, out for a moment.
						{
							at = 2.6,
							damage = 4,
							zone = "Head",
							stun = 0,
							hitbox = GRAB,
							forward = 2,
							knockdown = 2,
							knockback = 2,
							launch = 1,
							staminaDrain = 30,
						},
					},
				},
			},
			{
				id = "Powerbomb",
				name = "POWERBOMB",
				description = "Head between his legs, up on his shoulders, then down on their back.",
				animation = "Bouncer_Grab",
				duration = 0.7,
				cooldown = 10,
				stamina = 20,
				hits = {},
				grab = {
					at = 0.28,
					hitbox = GRAB,
					forward = 2.4,
					damage = 2,
					duration = 1.15,
					distance = 1.3,
					facing = "toward",
					animation = "Bouncer_Powerbomb",
					victimAnimation = "Bouncer_PowerbombVictim",
					laidAt = POWERBOMB_LAID,
					hits = {
						{
							at = 1.15,
							damage = 18,
							zone = "Torso",
							stun = 0,
							hitbox = GRAB,
							forward = 2,
							knockdown = 2.2,
							knockback = 3,
							launch = 2,
						},
					},
				},
			},
			{
				id = "DoubleHammer",
				name = "DOUBLE HAMMER",
				description = "Two hammer fists. The second one puts them down.",
				animation = "Bouncer_DoubleHammer",
				duration = 1.3,
				cooldown = 9,
				stamina = 20,
				chain = true,
				hits = {
					{
						at = 0.4,
						damage = 10,
						zone = "Head",
						stun = 0.9,
						hitbox = HEAD,
						forward = 3,
					},
					{
						at = 0.95,
						damage = 12,
						zone = "Head",
						stun = 0,
						hitbox = HEAD,
						forward = 3,
						knockdown = 1.4,
						knockback = 6,
					},
				},
			},
		},
	},
}

return kit
