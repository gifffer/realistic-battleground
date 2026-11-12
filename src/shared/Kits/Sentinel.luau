--!strict
-- SENTINEL: not quite human. Heat vision, a thunderclap, a leap that comes
-- down like a meteor, a punch that sends people flying. A short cape (Client/
-- Combat/KitLooks); his eyes glow red when he looks to burn.
--
-- Heat vision is strong but not instant: the eyes charge for a second
-- (everyone sees it coming), the beam goes straight ahead of him (it doesn't
-- follow the aim), he can't move while it charges and fires, and it only
-- starts burning someone who stays in it (Shared/Kits/KitTypes: beam).
--
-- Heavy: he walks a little slower than the others and can't sprint.
--
-- Pure data, read by Shared/Kits (see KitTypes). `at` values = the impact
-- keyframes of the animations (Client/Animation/CombatClips).

local KitTypes = require(script.Parent.KitTypes)

local kit: KitTypes.KitDef = {
	id = "Sentinel",
	name = "SENTINEL",
	description = "Not quite human. Heat vision, thunderclaps, and fists like meteors.",
	order = 3,
	available = true,
	walkSpeed = 0.9,
	noSprint = true,

	-- Cinematic kill (Shared/Finishers "Incinerate").
	finisher = {
		animation = "Sentinel_Finisher",
		impact = 2.9,
		duration = 4.2,
		cinematic = "Incinerate",
	},

	moves = {
		{
			id = "HeatVision",
			name = "HEAT VISION",
			description = "Eyes glow, then burn straight ahead. Only hurts those who stay in it.",
			animation = "Sentinel_HeatVision",
			duration = 3.15,
			cooldown = 12,
			stamina = 25,
			hits = {},
			beam = {
				from = 1, -- (the eyes charge first: a warning)
				to = 3,
				range = 45,
				radius = 1.1,
				warmup = 0.55, -- seconds in the beam before it burns
				tick = 0.25,
				hit = {
					at = 0,
					damage = 3.5,
					stun = 0.12,
					hitbox = Vector3.zero, -- (the beam has its own)
					blockCost = 3, -- (per tick: blocking the whole beam ≈ 18 stamina)
					forward = 0,
					bloodChance = {},
				},
			},
		},
		{
			id = "ThunderClap",
			name = "THUNDERCLAP",
			description = "Claps his hands. The shockwave knocks everyone in front down.",
			animation = "Sentinel_ThunderClap",
			duration = 0.85,
			cooldown = 9,
			stamina = 20,
			hits = {
				{
					at = 0.34,
					damage = 8,
					zone = "Torso",
					stun = 0,
					hitbox = Vector3.new(11, 7, 12),
					forward = 6.5,
					bloodChance = { Head = 0.7, Torso = 0.5 },
					breaks = 6, -- (the blast smashes the walls ahead)
					knockdown = 0.9,
					knockback = 46,
					launch = 12,
				},
			},
		},
		{
			id = "Skyfall",
			name = "SKYFALL",
			description = "Leaps high and comes down fist first. Everyone around falls.",
			animation = "Sentinel_Skyfall",
			duration = 1.25,
			cooldown = 11,
			stamina = 25,
			leap = { at = 0.18, up = 62, forward = 24, time = 0.6 },
			hits = {
				{
					at = 0.84,
					damage = 11,
					zone = "Torso",
					stun = 0,
					hitbox = Vector3.new(15, 8, 15),
					forward = 0,
					bloodChance = { Head = 0.9, Torso = 0.8, Legs = 0.5 },
					breaks = 9, -- (the landing craters the walls around)
					knockdown = 1.1,
					knockback = 22,
					launch = 22,
					unblockable = true,
				},
			},
		},
		{
			id = "Haymaker",
			name = "HAYMAKER",
			description = "Winds up, then a punch that sends them flying.",
			animation = "Sentinel_Haymaker",
			duration = 1.05,
			cooldown = 10,
			stamina = 20,
			hits = {
				{
					at = 0.55,
					damage = 14,
					zone = "Torso",
					stun = 0,
					hitbox = Vector3.new(5, 5, 6),
					forward = 3.2,
					breaks = 4.5,
					knockdown = 1.5,
					knockback = 78,
					launch = 26,
					bloodChance = { Head = 1, Torso = 0.9 },
				},
			},
		},
	},
}

return table.freeze(kit)
