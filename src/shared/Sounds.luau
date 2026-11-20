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
--   looped          (optional) a seamless LOOP (ambience beds, the train, a humming machine)
--   music           (optional) a MUSIC slot: a PLAYLIST. Its `ids` are played one after the
--                   other, in order, then again from the first (not at random). Music is not
--                   preloaded at startup (big files) and follows the MUSIC setting.
--                   Played by Client/Controllers/CityAudioController.
--   trackVolumes    (optional, music) a volume multiplier for ONE track of the playlist that
--                   is louder / quieter than the others: { [id] = 0.6 }
--   start           seconds skipped at the beginning of the file (a sound
--                   that starts with a blank), nil = from the start
--   length          seconds: only the start of it is played (a long file
--                   cut short with a quick fade), nil = all of it
--   fadeOut         (optional) seconds of that fade at `length` (default 0.15)
--   volumeVariation (optional) each play is randomly a bit louder / quieter (dB, 1.5 = ±1.5 dB)
--   trims           (optional) per id: { [id] = { start = s, gain = g } }, its own start
--                   (instead of `start`) and a volume multiplier, so variants recorded at
--                   different levels or with different blanks sound alike
--
-- Every sound is played IN 3D on the character who makes it (you hear it
-- louder when close, from the right direction), unless its section says otherwise.

export type SoundInfo = {
	ids: { number },
	volume: number,
	pitch: number,
	pitchVariation: number,
	fallback: string?,
	looped: boolean?,
	music: boolean?,
	trackVolumes: { [number]: number }?,
	start: number?,
	length: number?,
	fadeOut: number?,
	volumeVariation: number?,
	trims: { [number]: { start: number?, gain: number? } }?,
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
	BatImpact = { -- a deep boom under the crush (the beat the camera holds)
		ids = {},
		volume = 0.85,
		pitch = 0.55,
		pitchVariation = 0.02,
		fallback = "Slam",
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
	DeathFall = { ids = { 121870043011805 }, volume = 1, pitch = 1, pitchVariation = 0.05 }, -- the one killed hits the floor
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
	BurnCry = { -- the one burnt by acid or fire reacting (a cry of pain)
		ids = { 9116454961 },
		volume = 0.9,
		pitch = 1,
		pitchVariation = 0.06,
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
		start = 0.1,
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

	-- Blood (Combat/Blood*: silent until they have ids) ----------------------
	BloodDrip = { ids = {}, volume = 0.25, pitch = 1, pitchVariation = 0.15 }, -- a drop patting the floor
	BloodSplat = { ids = {}, volume = 0.6, pitch = 1, pitchVariation = 0.1 }, -- a wet slap of blood landing
	ArterialSpurt = { ids = {}, volume = 0.55, pitch = 1, pitchVariation = 0.08 }, -- an artery's jet, each beat
	BloodGurgle = { ids = {}, volume = 0.6, pitch = 1, pitchVariation = 0.05 }, -- blood in an open throat

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

	-- Sentinel / Bull ---------------------------------------------------------
	LaserCharge = { -- the eyes charging (heat vision). The file lasts 3 s: played 3× faster (1 s)
		ids = { 129456040607483 },
		volume = 0.8,
		pitch = 3,
		pitchVariation = 0,
	},
	LaserBeam = { ids = { 139620337204036 }, volume = 0.8, pitch = 1, pitchVariation = 0 }, -- (looped while it fires)
	LaserStop = { ids = { 76801901356843 }, volume = 0.8, pitch = 1, pitchVariation = 0 }, -- the beam cut off
	Sizzle = { -- flesh searing under the beam (finisher; looped). No file yet: the beam, higher
		ids = {},
		volume = 0.55,
		pitch = 1.8,
		pitchVariation = 0.04,
		fallback = "LaserBeam",
	},
	ThunderClap = { ids = { 139210252225248 }, volume = 1, pitch = 1, pitchVariation = 0.04 },
	SkyfallJump = { ids = { 74149238738530 }, volume = 1, pitch = 1, pitchVariation = 0.04 }, -- the take-off impact
	Slam = { ids = { 91288569991875 }, volume = 1, pitch = 1, pitchVariation = 0.04 }, -- the skyfall landing
	Haymaker = { ids = { 104231707453256 }, volume = 1, pitch = 1, pitchVariation = 0.04 },
	BullSnort = { ids = {}, volume = 0.6, pitch = 1, pitchVariation = 0.08 },
	BullCharge = { ids = { 129959965821462 }, volume = 1, pitch = 1, pitchVariation = 0.04 },
	Stomp = { ids = { 74149238738530 }, volume = 1, pitch = 0.9, pitchVariation = 0.04 }, -- stampede
	BullToss = { ids = { 138432031406888 }, volume = 1, pitch = 1, pitchVariation = 0.05 }, -- grab and throw

	-- Movement -------------------------------------------------------------
	Slide = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.08 },
	Vault = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.1 },
	Mantle = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.1 }, -- grabbing a ledge
	-- Footsteps: one sound each time a foot lands, chosen by the floor's material
	-- (Combat/Footsteps decides which material uses which slot). `volume` is a
	-- normal walk: running plays louder, a light step quieter. These replace
	-- Roblox's default footstep loop (muted by DeathSoundController).
	FootConcrete = { -- concrete, asphalt, brick, stone, plastic (the default)
		ids = { 129317472269932, 135085025171496, 116023211662573, 106215312789093, 86545332952989 },
		volume = 0.35,
		pitch = 1,
		pitchVariation = 0.08,
	},
	FootDirt = { -- dirt, sand, mud, gravel, snow
		ids = { 138750508569819, 140165597842270 },
		volume = 0.35,
		pitch = 1,
		pitchVariation = 0.1,
	},
	FootWood = { -- wooden floors and planks
		ids = { 139561410113584, 139575423158758, 103047430053521 },
		volume = 0.35,
		pitch = 1,
		pitchVariation = 0.08,
	},
	FootMetal = { -- metal plates, grates, rusty metal
		ids = { 136452594795744, 98915841855850, 118543527545797 },
		volume = 0.3,
		pitch = 1,
		pitchVariation = 0.08,
	},
	FootGrass = { -- grass and leafy grass
		ids = { 127407887796066, 137782073700276, 138157417086550 },
		volume = 0.35,
		pitch = 1,
		pitchVariation = 0.1,
	},

	-- Weather (played by Client/Controllers/CityAudioController and WeatherController) --------
	-- Not in 3D: heard by you wherever you are. Empty = silent, the game still works.
	-- The rain LOOP, MIXED on top of the outdoor music (it never replaces it). Its volume follows
	-- the rain (fades in / out), lower under a roof and inside the bar / shops, silent in the park.
	Rain = { ids = { 88290426489497 }, volume = 0.45, pitch = 1, pitchVariation = 0, looped = true },
	-- The THUNDERSTORM loop: the same recording, louder and a little lower (heavier rain).
	Storm = {
		ids = { 88290426489497 },
		volume = 0.8,
		pitch = 0.92,
		pitchVariation = 0,
		looped = true,
	},
	-- A thunder clap / rumble (one shot, 2D), heard 1 to 4 s after a far flash (at 60 to 100 %
	-- of this volume, a little lower or higher each time) and 0.15 to 0.5 s after a close one
	-- (louder). You can add 1 or 2 more ids: a random one plays each time.
	Thunder = { ids = { 139319051979882 }, volume = 0.85, pitch = 1, pitchVariation = 0.08 },

	-- Music and city ambience (Client/Controllers/CityAudioController) ---------------------
	-- The OUTDOOR beds: 2D, heard everywhere outside, crossfaded with the day / night cycle,
	-- quieter when you are inside the bar or a shop, silent in the park.
	MusicOutsideDay = {
		ids = { 9112758265 },
		volume = 0.32,
		pitch = 1,
		pitchVariation = 0,
		looped = true,
		music = true,
	},
	MusicOutsideNight = {
		ids = { 9112759731 },
		volume = 0.32,
		pitch = 1,
		pitchVariation = 0,
		looped = true,
		music = true,
	},
	-- The places: played IN 3D from the speakers inside (parts tagged "Speaker" with the
	-- attribute Zone). You start to hear them about 50 studs away, muffled through the walls,
	-- and clear once inside. Every player hears the same song at the same moment.
	MusicBar = { -- Duffy's
		ids = { 1847867511, 116586402120871, 1840730332, 1840684529 },
		volume = 0.55,
		pitch = 1,
		pitchVariation = 0,
		music = true,
	},
	MusicThreads = { -- the clothes shop (THREADBARE)
		ids = { 9043887091, 1845764031 },
		volume = 0.45,
		pitch = 1,
		pitchVariation = 0,
		music = true,
		trackVolumes = { [1845764031] = 0.45 }, -- this one is mastered much louder
	},
	MusicRewind = { -- the emote shop (REWIND)
		ids = { 1840684529, 1841647093 },
		volume = 0.45,
		pitch = 1,
		pitchVariation = 0,
		music = true,
	},
	MusicPark = { -- the hidden park (always sunny, no fights)
		ids = { 9118752742, 1846088038 },
		volume = 0.5,
		pitch = 1,
		pitchVariation = 0,
		music = true,
	},

	-- Train (Server/Systems/Train, played by Client/Controllers/TrainController) -------------
	-- In 3D, from the tunnel portal the train comes out of, then from the train itself.
	-- Empty = silent, the train still runs (and still kills).
	-- A loud diesel horn (one shot): heard when the signals start blinking, and again when the
	-- locomotive comes out of the tunnel onto the deck.
	TrainHorn = { ids = { 138837778626202 }, volume = 1, pitch = 1, pitchVariation = 0.03 },
	-- The heavy rolling / clattering LOOP while the train is out, louder the closer you are.
	TrainMoving = {
		ids = { 18940522285 },
		volume = 0.9,
		pitch = 1,
		pitchVariation = 0,
		looped = true,
	},
	-- Someone is hit by the train (one shot, in 3D at the impact).
	TrainCrash = { ids = { 7340406550 }, volume = 1, pitch = 1, pitchVariation = 0.04 },
	-- The victim screaming in pain, on their body, right after the hit (before they respawn).
	TrainScream = { ids = { 91948204995130 }, volume = 1, pitch = 1, pitchVariation = 0.04 },

	-- Doors (Server/Systems/CityDoors) ----------------------------------------------------
	-- In 3D at the doorway, once per doorway (not per leaf). Empty = silent doors.
	-- The shops' automatic glass doors sliding / swinging open, and closing again.
	DoorGlassOpen = { ids = { 70931033029641 }, volume = 0.6, pitch = 1, pitchVariation = 0.04 },
	DoorGlassClose = { ids = { 87017895257466 }, volume = 0.6, pitch = 1, pitchVariation = 0.04 },
	-- Duffy's swinging saloon doors: pushed open, and flapping back shut.
	DoorSaloonOpen = { ids = { 114086045710843 }, volume = 0.7, pitch = 1, pitchVariation = 0.06 },
	DoorSaloonClose = { ids = { 102044262944412 }, volume = 0.6, pitch = 1, pitchVariation = 0.06 },

	-- Power cut (Client/Controllers/WeatherFxController) ----------------------------------
	-- In 3D at the substation when the power goes: a transformer blowing (a sharp bang + an
	-- electric crackle). Empty = only the sparks and the flash.
	TransformerBlow = {
		ids = { 140278004623742 },
		volume = 1,
		pitch = 1,
		pitchVariation = 0.05,
	},
	-- 2D, while the lights stutter just before the cut: an electric buzz / crackle of the
	-- struggling grid (cut short when the transformer blows). Also, very quiet and short, in
	-- 3D at a stuttering street lamp near you when it cuts out. Empty = only the flickering.
	PowerBuzz = { ids = { 115768564143330 }, volume = 0.4, pitch = 1, pitchVariation = 0.05 },

	-- SpezCola machines (the free cola machines of the city) -------------------------------
	-- The machine humming (LOOP, in 3D at the machine).
	SpezColaHum = {
		ids = { 171186876 },
		volume = 0.35,
		pitch = 1,
		pitchVariation = 0,
		looped = true,
	},
	-- The can dropping into the tray (one shot, in 3D at the machine).
	SpezColaDrop = { ids = { 124906885034839 }, volume = 0.8, pitch = 1, pitchVariation = 0.05 },

	-- >>> Pyromaniac sounds (generated)
	-- Pyromaniac (Shared/Kits/Pyromaniac) --------------------------------------------------
	-- A kit sound is a cue of up to FIVE layers played together (Shared/SoundCues: when each
	-- starts): _Transient, _Mechanism, _Body, _Sub, _Tail. A layer with ids = {} is silent.
	-- The ids are free Pro Sound Effects sounds, picked and levelled by measurement
	-- (docs/SONS_PYROMANE_FR.md): `trims` cuts each file's blank and evens out its level.
	-- Generated by tools/sounds/pyro_sounds.py (edit STOCK there, then --write; ids typed
	-- here in a layer that is not in STOCK are kept).
	-- ZippoOpen: a brass Zippo-style lighter lid being flicked open with the thumb
	ZippoOpen_Transient = { ids = {}, volume = 0.63, pitch = 1, pitchVariation = 0.06 },
	ZippoOpen_Mechanism = { ids = {}, volume = 0.45, pitch = 1, pitchVariation = 0.06 },
	ZippoOpen_Body = {
		ids = { 9121005566 },
		volume = 1.33,
		pitch = 1,
		pitchVariation = 0.07,
		volumeVariation = 1.5,
		trims = {
			[9121005566] = { start = 0.03 },
		},
	},
	ZippoOpen_Sub = { ids = {}, volume = 0.1, pitch = 1, pitchVariation = 0.03 },
	ZippoOpen_Tail = { ids = {}, volume = 0.13, pitch = 1, pitchVariation = 0.06 },
	-- ZippoStrike: a Zippo lighter's flint wheel being struck and the wick catching fire
	ZippoStrike_Transient = { ids = {}, volume = 0.63, pitch = 1, pitchVariation = 0.06 },
	ZippoStrike_Mechanism = { ids = {}, volume = 0.4, pitch = 1, pitchVariation = 0.06 },
	ZippoStrike_Body = {
		ids = { 9121005779 },
		volume = 2.21,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9121005779] = { start = 0.02 },
		},
	},
	ZippoStrike_Sub = { ids = {}, volume = 0.13, pitch = 1, pitchVariation = 0.03 },
	ZippoStrike_Tail = {
		ids = { 9114446183, 9114445526 },
		volume = 0.79,
		pitch = 1,
		pitchVariation = 0.08,
		volumeVariation = 1.5,
		trims = {
			[9114446183] = { start = 0.15, gain = 1.26 },
			[9114445526] = { start = 0.05, gain = 0.79 },
		},
	},
	-- ZippoClose: a Zippo lighter lid snapping shut and smothering the flame
	ZippoClose_Transient = { ids = {}, volume = 0.56, pitch = 1, pitchVariation = 0.06 },
	ZippoClose_Mechanism = { ids = {}, volume = 0.32, pitch = 1, pitchVariation = 0.06 },
	ZippoClose_Body = {
		ids = { 9121005783 },
		volume = 0.75,
		pitch = 1,
		pitchVariation = 0.07,
		volumeVariation = 1.5,
		trims = {
			[9121005783] = { start = 0.07 },
		},
	},
	ZippoClose_Sub = { ids = {}, volume = 0.07, pitch = 1, pitchVariation = 0.03 },
	ZippoClose_Tail = { ids = {}, volume = 0.14, pitch = 1, pitchVariation = 0.06 },
	-- MolotovThrow: a lit Molotov cocktail bottle being thrown overhand and flying past
	MolotovThrow_Transient = { ids = {}, volume = 0.45, pitch = 1, pitchVariation = 0.06 },
	MolotovThrow_Mechanism = { ids = {}, volume = 0.25, pitch = 1, pitchVariation = 0.06 },
	MolotovThrow_Body = {
		ids = { 9114463219, 9114463410, 9114463208, 9114463016 },
		volume = 0.69,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1.4,
		fadeOut = 0.3,
		trims = {
			[9114463219] = { start = 0.19 },
			[9114463410] = { start = 0.19, gain = 0.96 },
			[9114463208] = { start = 0.2, gain = 0.99 },
			[9114463016] = { start = 0.19, gain = 1.06 },
		},
	},
	MolotovThrow_Sub = { ids = {}, volume = 0.11, pitch = 1, pitchVariation = 0.03 },
	MolotovThrow_Tail = { ids = {}, volume = 0.18, pitch = 1, pitchVariation = 0.06 },
	-- FuelIgnite: spilled petrol on the ground igniting into a fireball
	FuelIgnite_Transient = { ids = {}, volume = 0.79, pitch = 1, pitchVariation = 0.06 },
	FuelIgnite_Mechanism = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.06 },
	FuelIgnite_Body = {
		ids = { 9114429507, 9114429835, 9114429958, 9114429740 },
		volume = 0.68,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 2.2,
		fadeOut = 1,
		trims = {
			[9114429507] = { start = 0.05, gain = 1.03 },
			[9114429835] = { start = 0.15, gain = 0.97 },
			[9114429958] = { start = 0.24, gain = 1.02 },
			[9114429740] = { start = 0.25, gain = 0.97 },
		},
	},
	FuelIgnite_Sub = {
		ids = { 9114554567 },
		volume = 0.24,
		pitch = 0.8,
		pitchVariation = 0.03,
		volumeVariation = 1.5,
		length = 1.5,
		fadeOut = 0.5,
	},
	FuelIgnite_Tail = { ids = {}, volume = 0.4, pitch = 1, pitchVariation = 0.06 },
	-- PoolFire: a pool of burning petrol on a street floor (seamless loop)
	PoolFire_Transient = { ids = {}, volume = 0.28, pitch = 1, pitchVariation = 0, looped = true },
	PoolFire_Mechanism = {
		ids = { 9112780462 },
		volume = 3.67,
		pitch = 1,
		pitchVariation = 0,
		looped = true,
	},
	PoolFire_Body = {
		ids = { 9112780561 },
		volume = 2.07,
		pitch = 1,
		pitchVariation = 0,
		looped = true,
	},
	PoolFire_Sub = { ids = {}, volume = 0.22, pitch = 1, pitchVariation = 0, looped = true },
	PoolFire_Tail = { ids = {}, volume = 0.14, pitch = 1, pitchVariation = 0, looped = true },
	-- FireBreath: a fire breather spitting atomised fuel through a lighter flame into a roaring jet of fire
	FireBreath_Transient = {
		ids = { 9114446277, 9114441555 },
		volume = 0.95,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9114446277] = { start = 0.23, gain = 1.14 },
			[9114441555] = { start = 0.72, gain = 0.88 },
		},
	},
	FireBreath_Mechanism = { ids = {}, volume = 0.4, pitch = 1, pitchVariation = 0.06 },
	FireBreath_Body = {
		ids = { 9117984812, 9117985848, 9117985933 },
		volume = 1.37,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 0.75,
		fadeOut = 0.3,
		trims = {
			[9117984812] = { start = 0.22, gain = 0.59 },
			[9117985848] = { start = 0.25, gain = 1.27 },
			[9117985933] = { start = 0.22, gain = 1.33 },
		},
	},
	FireBreath_Sub = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.03 },
	FireBreath_Tail = {
		ids = { 9114445526 },
		volume = 0.99,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1,
		fadeOut = 0.3,
		trims = {
			[9114445526] = { start = 0.05 },
		},
	},
	-- FuelSplash: raw fuel sprayed out of a flamethrower nozzle onto a person
	FuelSplash_Transient = { ids = {}, volume = 0.56, pitch = 1, pitchVariation = 0.06 },
	FuelSplash_Mechanism = {
		ids = { 9126173160 },
		volume = 0.88,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1,
		fadeOut = 0.3,
		trims = {
			[9126173160] = { start = 0.14 },
		},
	},
	FuelSplash_Body = {
		ids = { 9125702439, 9125702803 },
		volume = 3.69,
		pitch = 1,
		pitchVariation = 0.08,
		volumeVariation = 1.5,
		trims = {
			[9125702439] = { gain = 0.91 },
			[9125702803] = { gain = 1.1 },
		},
	},
	FuelSplash_Sub = { ids = {}, volume = 0.2, pitch = 1, pitchVariation = 0.03 },
	FuelSplash_Tail = { ids = {}, volume = 0.16, pitch = 1, pitchVariation = 0.06 },
	-- BodyBurn: a human body and its clothes burning (seamless loop)
	BodyBurn_Transient = { ids = {}, volume = 0.22, pitch = 1, pitchVariation = 0, looped = true },
	BodyBurn_Mechanism = { ids = {}, volume = 0.28, pitch = 1, pitchVariation = 0, looped = true },
	BodyBurn_Body = {
		ids = { 9112780438, 9112780212, 9112780193 },
		volume = 4.35,
		pitch = 1,
		pitchVariation = 0,
		trims = {
			[9112780438] = { gain = 0.87 },
			[9112780212] = { gain = 1.09 },
			[9112780193] = { gain = 1.05 },
		},
		looped = true,
	},
	BodyBurn_Sub = { ids = {}, volume = 0.18, pitch = 1, pitchVariation = 0, looped = true },
	BodyBurn_Tail = { ids = {}, volume = 0.14, pitch = 1, pitchVariation = 0, looped = true },
	-- SelfIgnite: petrol-soaked forearm wraps being lit with a lighter and flaring up along both arms
	SelfIgnite_Transient = { ids = {}, volume = 0.5, pitch = 1, pitchVariation = 0.06 },
	SelfIgnite_Mechanism = {
		ids = { 9114446277, 9114441555 },
		volume = 0.8,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9114446277] = { start = 0.21, gain = 1.2 },
			[9114441555] = { start = 0.7, gain = 0.84 },
		},
	},
	SelfIgnite_Body = {
		ids = { 9117983605, 9117983322, 9117986652 },
		volume = 1.12,
		pitch = 1,
		pitchVariation = 0.04,
		volumeVariation = 1.5,
		trims = {
			[9117983605] = { start = 0.22, gain = 0.98 },
			[9117983322] = { start = 0.21, gain = 1.19 },
			[9117986652] = { start = 0.37, gain = 0.86 },
		},
	},
	SelfIgnite_Sub = { ids = {}, volume = 0.4, pitch = 1, pitchVariation = 0.03 },
	SelfIgnite_Tail = { ids = {}, volume = 0.32, pitch = 1, pitchVariation = 0.06 },
	-- BodyIgnite: a petrol-soaked person on the ground going up in flames
	BodyIgnite_Transient = { ids = {}, volume = 0.79, pitch = 1, pitchVariation = 0.06 },
	BodyIgnite_Mechanism = { ids = {}, volume = 0.56, pitch = 1, pitchVariation = 0.06 },
	BodyIgnite_Body = {
		ids = { 9114429835, 9114429507 },
		volume = 0.74,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 3,
		fadeOut = 1.2,
		trims = {
			[9114429835] = { start = 0.19, gain = 0.97 },
			[9114429507] = { start = 0.1, gain = 1.04 },
		},
	},
	BodyIgnite_Sub = {
		ids = { 9114554567 },
		volume = 0.27,
		pitch = 0.8,
		pitchVariation = 0.03,
		volumeVariation = 1.5,
		length = 1.5,
		fadeOut = 0.5,
	},
	BodyIgnite_Tail = {
		ids = { 9119165650, 9119166424 },
		volume = 0.58,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9119165650] = { start = 0.18, gain = 1.41 },
			[9119166424] = { start = 0.16, gain = 0.71 },
		},
	},
	-- BurnScream: a man screaming in agony while burning, his voice breaking and cut short
	BurnScream_Transient = { ids = {}, volume = 0.56, pitch = 1, pitchVariation = 0.06 },
	BurnScream_Mechanism = { ids = {}, volume = 0.35, pitch = 1, pitchVariation = 0.06 },
	BurnScream_Body = {
		ids = { 9116454870, 9125652466, 9125652432 },
		volume = 1.34,
		pitch = 1,
		pitchVariation = 0.04,
		volumeVariation = 1.5,
		length = 1.4,
		fadeOut = 0.15,
		trims = {
			[9116454870] = { start = 0.11, gain = 2.01 },
			[9125652466] = { start = 0.06, gain = 0.88 },
			[9125652432] = { start = 0.07, gain = 0.57 },
		},
	},
	BurnScream_Sub = { ids = {}, volume = 0.18, pitch = 1, pitchVariation = 0.03 },
	BurnScream_Tail = { ids = {}, volume = 0.35, pitch = 1, pitchVariation = 0.06 },
	-- InfernoBreath: the Inferno's longer jet of fire
	InfernoBreath_Transient = {
		ids = { 9114446277, 9114441555 },
		volume = 1.07,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9114446277] = { start = 0.23, gain = 1.14 },
			[9114441555] = { start = 0.72, gain = 0.88 },
		},
	},
	InfernoBreath_Body = {
		ids = { 9117984812, 9117985848, 9117985933 },
		volume = 1.54,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 0.95,
		fadeOut = 0.35,
		trims = {
			[9117984812] = { start = 0.22, gain = 0.59 },
			[9117985848] = { start = 0.25, gain = 1.27 },
			[9117985933] = { start = 0.22, gain = 1.33 },
		},
	},
	InfernoBreath_Tail = {
		ids = { 9114445526 },
		volume = 1.11,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1,
		fadeOut = 0.3,
		trims = {
			[9114445526] = { start = 0.05 },
		},
	},
	-- FireSwing: a burning fist swung past like a torch
	FireSwing_Body = {
		ids = { 9114462915, 9114462930, 9114463010, 9114463022 },
		volume = 0.92,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1,
		fadeOut = 0.3,
		trims = {
			[9114462915] = { start = 0.45, gain = 1.05 },
			[9114462930] = { start = 0.4, gain = 1.01 },
			[9114463010] = { start = 0.25, gain = 1.03 },
			[9114463022] = { start = 0.49, gain = 0.92 },
		},
	},
	-- FireImpact: a burning fist landing: a puff of flame and searing skin
	FireImpact_Body = {
		ids = { 9114443884, 9114444052 },
		volume = 2.1,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 0.8,
		fadeOut = 0.2,
		trims = {
			[9114443884] = { start = 0.27, gain = 0.93 },
			[9114444052] = { start = 0.25, gain = 1.08 },
		},
	},
	FireImpact_Tail = {
		ids = { 9119166424, 9119166217, 9119165644, 9119166425 },
		volume = 0.47,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1.2,
		fadeOut = 0.3,
		trims = {
			[9119166424] = { start = 0.16, gain = 0.88 },
			[9119166217] = { start = 0.1, gain = 0.97 },
			[9119165644] = { start = 0.07, gain = 0.97 },
			[9119166425] = { start = 0.07, gain = 1.22 },
		},
	},
	-- CatchFire: someone catching fire: a whoosh of flame wrapping round them, a sizzle
	CatchFire_Body = {
		ids = { 9114446183, 9114445526, 9114462912 },
		volume = 1.93,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9114446183] = { start = 0.15, gain = 1.81 },
			[9114445526] = { start = 0.05, gain = 1.14 },
			[9114462912] = { start = 0.18, gain = 0.48 },
		},
	},
	CatchFire_Tail = {
		ids = { 9119165912, 9119165930 },
		volume = 0.23,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9119165912] = { start = 0.06, gain = 0.96 },
			[9119165930] = { start = 0.03, gain = 1.04 },
		},
	},
	-- Extinguish: the last flames on a body going out: a sizzle that dies down
	Extinguish_Body = {
		ids = { 9119166199, 9119165933 },
		volume = 0.23,
		pitch = 0.9,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1.2,
		fadeOut = 0.4,
		trims = {
			[9119166199] = { start = 0.08, gain = 0.88 },
			[9119165933] = { start = 0.11, gain = 1.14 },
		},
	},
	-- PyreRoar: the roar of a whole body burning (loop)
	PyreRoar_Body = {
		ids = { 9112780691 },
		volume = 1.82,
		pitch = 1,
		pitchVariation = 0,
		looped = true,
	},
	-- GunDraw: the flamethrower swung off his back, the fuel sloshing in the bottle
	GunDraw_Body = {
		ids = { 9114190682 },
		volume = 3.55,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 0.4,
		fadeOut = 0.15,
		trims = {
			[9114190682] = { start = 0.07 },
		},
	},
	-- PilotLight: the pilot burner lit: a lever click and a soft blue fwip
	PilotLight_Body = {
		ids = { 9121005783 },
		volume = 0.42,
		pitch = 1.3,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9121005783] = { start = 0.07 },
		},
	},
	PilotLight_Tail = {
		ids = { 9114446183 },
		volume = 0.88,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9114446183] = { start = 0.15 },
		},
	},
	-- PilotOut: the pilot flame shut off: a short high sizzle
	PilotOut_Body = {
		ids = { 9119166199 },
		volume = 0.16,
		pitch = 1.2,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 0.4,
		fadeOut = 0.15,
		trims = {
			[9119166199] = { start = 0.08 },
		},
	},
	-- TriggerClick: the flamethrower's trigger squeezed: a dull metal click
	TriggerClick_Body = {
		ids = { 9121005566 },
		volume = 0.84,
		pitch = 0.8,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9121005566] = { start = 0.03 },
		},
	},
	-- BurstPop: a pressurised ball of fire popping out of a flamethrower, crackling drops
	BurstPop_Body = {
		ids = { 9114442751, 9114444052, 9114443884, 9114444008 },
		volume = 1.7,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1,
		fadeOut = 0.3,
		trims = {
			[9114442751] = { start = 0.25, gain = 0.38 },
			[9114444052] = { start = 0.24, gain = 1.88 },
			[9114443884] = { start = 0.26, gain = 1.62 },
			[9114444008] = { start = 0.62, gain = 0.86 },
		},
	},
	BurstPop_Tail = {
		ids = { 9119166424, 9119166217, 9119165644, 9119166425 },
		volume = 0.42,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1.2,
		fadeOut = 0.3,
		trims = {
			[9119166424] = { start = 0.16, gain = 0.88 },
			[9119166217] = { start = 0.1, gain = 0.97 },
			[9119165644] = { start = 0.07, gain = 0.97 },
			[9119166425] = { start = 0.07, gain = 1.22 },
		},
	},
	-- GlobLaunch: a glob of napalm coughed out of the muzzle: a short burst of fire
	GlobLaunch_Transient = {
		ids = { 9114446277, 9114441555 },
		volume = 0.89,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 0.4,
		fadeOut = 0.15,
		trims = {
			[9114446277] = { start = 0.26, gain = 1.14 },
			[9114441555] = { start = 0.75, gain = 0.88 },
		},
	},
	GlobLaunch_Body = {
		ids = { 9114429507, 9114429835 },
		volume = 0.43,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 0.5,
		fadeOut = 0.2,
		trims = {
			[9114429507] = { start = 0.05, gain = 1.03 },
			[9114429835] = { start = 0.15, gain = 0.97 },
		},
	},
	-- GlobSplat: a glob of burning napalm splatting on the floor (no glass)
	GlobSplat_Body = {
		ids = { 9125702439, 9125702803 },
		volume = 4.65,
		pitch = 1,
		pitchVariation = 0.08,
		volumeVariation = 1.5,
		trims = {
			[9125702439] = { gain = 0.91 },
			[9125702803] = { gain = 1.1 },
		},
	},
	-- StreamEnd: the jet let go: the tail of the flame whooshing away
	StreamEnd_Tail = {
		ids = { 9114445526 },
		volume = 1.11,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1,
		fadeOut = 0.4,
		trims = {
			[9114445526] = { start = 0.05 },
		},
	},
	-- PressureHiss: the regulator's pressurised gas hiss rising
	PressureHiss_Body = {
		ids = { 9126173160 },
		volume = 0.35,
		pitch = 1.4,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 0.8,
		fadeOut = 0.3,
		trims = {
			[9126173160] = { start = 0.14 },
		},
	},
	-- ValveCrank: the ball valve slapped shut or the bottle's handwheel cranked: a metal clack
	ValveCrank_Body = {
		ids = { 9121005783 },
		volume = 0.75,
		pitch = 0.6,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		trims = {
			[9121005783] = { start = 0.07 },
		},
	},
	-- TorchLance: a short hard blowtorch lance lighting
	TorchLance_Body = {
		ids = { 9114446277, 9114441555 },
		volume = 1.12,
		pitch = 1.25,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 0.25,
		fadeOut = 0.1,
		trims = {
			[9114446277] = { start = 0.26, gain = 1.14 },
			[9114441555] = { start = 0.75, gain = 0.88 },
		},
	},
	-- Vent: the overheated gun's relief valve venting: a white-hot hiss
	Vent_Body = {
		ids = { 9119166199, 9119165933 },
		volume = 0.37,
		pitch = 0.8,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1.5,
		fadeOut = 0.5,
		trims = {
			[9119166199] = { start = 0.08, gain = 0.88 },
			[9119165933] = { start = 0.11, gain = 1.14 },
		},
	},
	Vent_Tail = {
		ids = { 9114445526 },
		volume = 0.88,
		pitch = 1,
		pitchVariation = 0.06,
		volumeVariation = 1.5,
		length = 1.5,
		fadeOut = 0.5,
		trims = {
			[9114445526] = { start = 0.05 },
		},
	},
	-- <<< Pyromaniac sounds (generated)
}

return table.freeze(sounds)
