--!strict
-- Sound effects of the game.
--
-- Each sound has a LIST of ids (`ids`): one is picked at random every time
-- (never the same twice in a row), so a fight doesn't sound like a loop.
-- An empty list `{}` → not chosen yet: the game plays nothing for it, or
-- its `fallback` sound if it has one. Fill them in any order.
--
-- How to add one (guide: docs/SOUNDS_FR.md):
--   1. Find or upload the sound (Creator Store → Audio, or Creator Hub → Upload).
--   2. Copy its number into `ids` below (example: ids = { 1234567890 }).
--   3. Rojo syncs, press Play.
--
--   volume          0 → 1 (0.5 = half)
--   pitch           playback speed: 1 = normal, 0.8 = lower and heavier
--   pitchVariation  each play is randomly a bit higher / lower (0.08 = ±8 %)
--   fallback        name of another sound to use while `ids` is empty
--   start           seconds skipped at the beginning of the file (a sound
--                   that starts with a blank), nil = from the start
--   length          seconds: only the start of it is played (a long file
--                   cut short with a quick fade), nil = all of it
--
-- Every sound is played IN 3D on the character who makes it (you hear it
-- louder when close, from the right direction).

export type SoundInfo = {
	ids: { number },
	volume: number,
	pitch: number,
	pitchVariation: number,
	fallback: string?,
	start: number?,
	length: number?,
}

local sounds: { [string]: SoundInfo } = {
	-- Combat ---------------------------------------------------------------
	-- M1 1 to 3: the fist cutting the air.
	Swing = {
		ids = { 106465952871873, 70999983727267, 108317638843283 },
		volume = 0.5,
		pitch = 1,
		pitchVariation = 0.1,
	},
	-- M1 4 (finisher). Until it has its own sounds: the swings, lower and louder.
	HeavySwing = {
		ids = {},
		volume = 0.65,
		pitch = 0.82,
		pitchVariation = 0.06,
		fallback = "Swing",
	},
	-- A punch lands.
	Hit = {
		ids = { 140626490819228, 82947349478563, 70841195817565 },
		volume = 0.75,
		pitch = 1,
		pitchVariation = 0.1,
	},
	-- The finisher lands. Until it has its own sounds: the hits, lower and louder.
	HeavyHit = {
		ids = {},
		volume = 1,
		pitch = 0.8,
		pitchVariation = 0.05,
		fallback = "Hit",
	},
	Block = { ids = {}, volume = 0.6, pitch = 1, pitchVariation = 0.1 }, -- hit on the guard
	Parry = { ids = {}, volume = 0.8, pitch = 1, pitchVariation = 0.05 },
	GuardBreak = { ids = {}, volume = 0.9, pitch = 1, pitchVariation = 0.05 },
	Dash = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.1 },
	Dodge = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.1 }, -- hit dodged by a dash

	-- Kits (Street Brawler) -----------------------------------------------
	-- Until they have their own ids, each one borrows a combat sound with
	-- its own pitch (so it still sounds different).
	BottleBreak = { -- glass shattering on a head
		ids = { 94487606893742 },
		volume = 0.9,
		pitch = 1,
		pitchVariation = 0.06,
		fallback = "Hit",
	},
	Slash = { -- the broken bottle cutting the air
		ids = {},
		volume = 0.55,
		pitch = 1.3,
		pitchVariation = 0.08,
		fallback = "Swing",
	},
	Headbutt = { -- skull on skull, dull and heavy
		ids = {},
		volume = 0.9,
		pitch = 0.7,
		pitchVariation = 0.05,
		fallback = "Hit",
	},
	Tackle = { -- a body slammed into another
		ids = {},
		volume = 1,
		pitch = 0.65,
		pitchVariation = 0.05,
		fallback = "Hit",
	},
	KickLow = { -- a shin kick lands
		ids = {},
		volume = 0.75,
		pitch = 0.9,
		pitchVariation = 0.08,
		fallback = "Hit",
	},
	Awaken = { -- Street Fury starts (a neck crack, a low growl...)
		ids = { 642336941 },
		volume = 0.8,
		pitch = 1,
		pitchVariation = 0.03,
		fallback = "HeavySwing",
	},

	-- Cinematic finishers (Shared/Finishers) ------------------------------
	BatDraw = { -- the bat pulled out from behind the back
		ids = {},
		volume = 0.6,
		pitch = 0.75,
		pitchVariation = 0.05,
		fallback = "Swing",
	},
	BatCrush = { -- the bat bursts the head
		ids = { 123012498248453 },
		volume = 1,
		pitch = 1,
		pitchVariation = 0.03,
		fallback = "HeavyHit",
	},
	BatSwing = { -- the bat coming down
		ids = { 9113305631 },
		volume = 0.9,
		pitch = 1,
		pitchVariation = 0.04,
		fallback = "HeavySwing",
	},
	VictimPlea = { -- what the one on the ground says before the bat comes down
		ids = {}, -- (no voice for now)
		volume = 0.9,
		pitch = 1,
		pitchVariation = 0,
	},
	BodyShot = { -- a hook to the ribs, dull
		ids = {},
		volume = 0.85,
		pitch = 0.8,
		pitchVariation = 0.08,
		fallback = "Hit",
	},
	KnockoutPunch = { -- the Boxer's last blow: the hand into the side
		ids = { 140325083438865 },
		volume = 1,
		pitch = 1,
		pitchVariation = 0.02,
		fallback = "HeavyHit",
	},
	RibCrack = { -- ribs giving way under the fist
		ids = { 121666760679562 },
		volume = 0.9,
		pitch = 1,
		pitchVariation = 0.06,
	},
	FleshTear = { -- the liver torn out, wet
		ids = { 111650608703379 },
		volume = 1,
		pitch = 1,
		pitchVariation = 0.04,
	},
	OrganDrop = { -- a heavy, wet organ hitting the floor
		ids = { 135119591308242 },
		volume = 0.7,
		pitch = 1,
		pitchVariation = 0.05,
	},

	-- Bouncer -------------------------------------------------------------
	Grab = { -- hands closing on a collar, cloth pulled tight
		ids = {},
		volume = 0.7,
		pitch = 1,
		pitchVariation = 0.08,
		fallback = "Hit",
	},
	Choke = { -- a throat squeezed: a choked gasp
		ids = {},
		volume = 0.8,
		pitch = 1,
		pitchVariation = 0.08,
		fallback = "HurtGrunt",
	},
	BodySlam = { -- a whole body driven into the floor
		ids = {},
		volume = 1,
		pitch = 0.9,
		pitchVariation = 0.05,
		fallback = "Tackle",
	},
	Strain = { -- him pulling with everything he has (a grunt)
		ids = {},
		volume = 0.8,
		pitch = 0.85,
		pitchVariation = 0.05,
	},
	ShoulderPop = { -- the shoulder coming out of its socket
		ids = {},
		volume = 0.9,
		pitch = 1,
		pitchVariation = 0.05,
		fallback = "RibCrack",
	},
	ArmTear = { -- the arm torn off at the shoulder, wet
		ids = {},
		volume = 1,
		pitch = 0.9,
		pitchVariation = 0.04,
		fallback = "FleshTear",
	},
	LimbDrop = { -- a heavy arm hitting the floor
		ids = {},
		volume = 0.8,
		pitch = 0.9,
		pitchVariation = 0.05,
		fallback = "OrganDrop",
	},

	-- Dr. Rift --------------------------------------------------------------
	FlaskThrow = { -- a glass flask flung (a light whoosh, liquid sloshing)
		ids = {},
		volume = 0.6,
		pitch = 1.1,
		pitchVariation = 0.08,
		fallback = "Swing",
	},
	FlaskBreak = { -- the flask bursting (thin glass)
		ids = {},
		volume = 0.8,
		pitch = 1.15,
		pitchVariation = 0.06,
		fallback = "BottleBreak",
	},
	AcidSizzle = { -- acid eating into skin / the floor: a hissing fizz
		ids = { 9066038215 },
		volume = 0.7,
		pitch = 1,
		pitchVariation = 0.1,
	},
	Explosion = { -- the explosive flask: a dull, close blast
		ids = { 98182121433648 },
		volume = 1,
		pitch = 0.9,
		pitchVariation = 0.05,
		fallback = "HeavyHit",
	},
	RayGun = { -- the ray gun firing: a short electric crackle
		ids = { 108089086472724 },
		volume = 0.8,
		pitch = 1,
		pitchVariation = 0.06,
	},
	RayGunBig = { -- the overcharged ray: a long, rising discharge
		ids = {},
		volume = 0.9,
		pitch = 0.8,
		pitchVariation = 0.04,
		fallback = "RayGun",
	},
	Burn = { -- skin burning: a sharp hiss
		ids = {},
		volume = 0.6,
		pitch = 1,
		pitchVariation = 0.1,
		fallback = "AcidSizzle",
	},
	GloveBlast = { -- the gravity glove (a magnetic pulse)
		ids = { 15912192112 },
		volume = 0.9,
		pitch = 1,
		pitchVariation = 0.05,
		fallback = "Tackle",
		length = 1.5,
	},
	RiftImpact = { -- a heavy impact of the Awakening (the arms flung out, the gravity slam)
		ids = { 71947288327190 },
		volume = 1,
		pitch = 1,
		pitchVariation = 0.04,
	},
	Teleport = { -- Dr. Rift going through his portal (played from the shot:
		-- it must already be heard when he comes out; raise `start` if the
		-- file begins with a blank)
		ids = { 1013378689 },
		volume = 0.9,
		pitch = 1,
		pitchVariation = 0.03,
		-- (the file starts with about half a second of nothing, and its
		-- whoosh peaks after that: skipped, so the peak lands as he steps
		-- through, 0.78 s into the move)
		start = 0.3,
	},
	PortalShot = { -- the portal gun's shot
		ids = {},
		volume = 0.7,
		pitch = 1,
		pitchVariation = 0.06,
	},
	PortalOpen = { -- a portal tearing open: a wet, rushing whoosh
		ids = { 1013378689 },
		volume = 0.8,
		pitch = 1,
		pitchVariation = 0.06,
	},
	PortalClose = { -- snapping shut
		ids = {},
		volume = 0.8,
		pitch = 1.1,
		pitchVariation = 0.05,
		fallback = "PortalOpen",
	},
	PortalFizzle = { -- the shot that couldn't open: a sputter
		ids = {},
		volume = 0.6,
		pitch = 1.2,
		pitchVariation = 0.08,
	},
	BodyCut = { -- cut in two by the portal closing: a wet, heavy slice
		ids = { 80160249812182 },
		volume = 1,
		pitch = 0.9,
		pitchVariation = 0.04,
		fallback = "FleshTear",
	},

	-- Injuries (step 5) -----------------------------------------------------
	-- Loops heard only by you while your health is low.
	Heartbeat = { ids = { 7237020278 }, volume = 0.6, pitch = 1, pitchVariation = 0 },
	Breathing = { ids = { 6814463121 }, volume = 0.45, pitch = 1, pitchVariation = 0 },
	-- The fighter groans when hit, once their health is at or under
	-- Config.Injuries.HURT_SOUND_HEALTH (70).
	HurtGrunt = {
		ids = { 136844926219636, 135663378635164, 89916929786660 },
		volume = 0.8,
		pitch = 1,
		pitchVariation = 0.06,
	},

	-- Movement -------------------------------------------------------------
	Slide = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.08 },
	Vault = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.1 },
	Mantle = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.1 }, -- grabbing a ledge
}

return table.freeze(sounds)
