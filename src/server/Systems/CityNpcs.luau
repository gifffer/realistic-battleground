--!strict
-- CityNpcs: the little people of the city — Duffy behind his bar, a few regulars on the
-- stools, the clerks of THREADBARE and REWIND behind their counters.
--
-- They are plain blocky R6 bodies, built by Roblox like a player's (the same rig as the
-- training dummies: Players:CreateHumanoidModelFromDescription), coloured with body colours
-- only (no clothing ids needed), plus block accessories made of small welded parts: layered
-- hair (fringe, bun, long...), caps with a brim and a button, beanies with a fold, flat caps,
-- headphones, glasses with frames and lenses, the bartender's apron (straps, pocket) and towel,
-- the clerks' lanyard badge, watches, earrings, necklaces (see addAccessories).
-- Down the alleys east of the ring there are two more kinds of people, dressed in layers
-- with real clothes' details (see addDealerOutfit / addVagrantOutfit): the DEALER of the
-- black market (a worn biker jacket open on a tee, or a hoodie with the hood up; a gold
-- chain, rings, a gold watch, a cigarette, a sling bag, dark jeans, black boots, a duffel at
-- his feet) and the VAGRANT of the squat (a long dirty coat over a hoodie, a striped scarf,
-- a ribbed beanie, a beard, fingerless gloves, patched and torn trousers, worn-out boots; the
-- client adds his blanket, his sign, his backpack, a book and his paper cup).
-- They never move and can't be hurt:
--   • the HumanoidRootPart is anchored: nobody can push them, gravity does nothing;
--   • no name or health bar above them (Humanoid display distance 0);
--   • they are NOT fighters: they are never registered in Combat (Combat ignores every model
--     it does not know), the Hitbox skips models with the attribute Npc = true, and
--     they don't have the Combatant tag (so no lock-on, no name tag, no prediction);
--   • every body part is CanTouch = false, the limbs and accessories don't collide at all.
--
-- Where they stand: the city data has invisible marker parts named "NpcSpot" (Size 1,
-- Transparency 1). Each marker gives:
--   CFrame position = the floor point between the feet, LookVector = where they face;
--   attributes NpcRole ("Bartender" | "Clerk" | "Patron" | "Dealer" | "Vagrant"),
--   NpcName ("Duffy"...), NpcPose ("Idle" | "WipeCounter" | "LeanBar" | "SitStool" |
--   "ArmsCrossed" | "Phone" | "SitGround"; anything else: "Idle"),
--   NpcSeed (a number: picks the colours), SeatHeight (sitting poses: seat top above the floor;
--   SitGround: 0 = the floor itself), SeatBack (optional, sitting poses: how far behind the
--   spot the seat's centre is; SitStool 1, SitGround 0).
-- SitGround (sitting on the floor, back against a wall, legs stretched out): the spot is the
-- floor point under the hips, facing AWAY from the wall, about 0.8 studs out from the wall's
-- face (the shoulders and the back of the head then rest just off it).
--
-- The server only places each body STANDING on its spot (and copies the marker's
-- attributes onto the model, plus Npc = true). The pose (sitting, leaning, arms crossed...),
-- the breathing, the head turning towards you and the bartender's rag are animated by every
-- player's own computer (Client/Controllers/CityNpcController): the server stays cheap.
--
-- Everything goes into Workspace > City > Npcs.

local Players = game:GetService("Players")

local CityNpcs = {}

local SPOT_NAME = "NpcSpot"
local FOLDER_NAME = "Npcs"
-- An R6 body: the HumanoidRootPart's centre is 3 studs above the floor (legs 2 + half torso).
local ROOT_HEIGHT = 3

-- Skin tones (picked by the seed). Blocky, slightly desaturated: the "LARP R6" look.
local SKINS = {
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(160, 104, 72),
	Color3.fromRGB(124, 82, 58),
	Color3.fromRGB(86, 58, 44),
	Color3.fromRGB(245, 205, 168),
}
-- Shirt / trousers colours of patrons (picked by the seed).
local SHIRTS = {
	Color3.fromRGB(92, 44, 40), -- oxblood
	Color3.fromRGB(46, 62, 84), -- navy
	Color3.fromRGB(76, 86, 56), -- olive
	Color3.fromRGB(120, 112, 98), -- grey sweat
	Color3.fromRGB(150, 98, 46), -- mustard
	Color3.fromRGB(36, 36, 40), -- black hoodie
	Color3.fromRGB(110, 40, 70), -- plum
}
local TROUSERS = {
	Color3.fromRGB(44, 52, 70), -- jeans
	Color3.fromRGB(32, 32, 34), -- black
	Color3.fromRGB(86, 74, 58), -- khaki
	Color3.fromRGB(58, 60, 64), -- charcoal
}
-- The alley people (see makeLook): worn, dark, dirty colours.
local DEALER_LEATHER = {
	Color3.fromRGB(34, 28, 25),
	Color3.fromRGB(46, 34, 28),
	Color3.fromRGB(26, 25, 26),
}
local DEALER_HOODIES = {
	Color3.fromRGB(30, 30, 33),
	Color3.fromRGB(40, 42, 38),
	Color3.fromRGB(42, 38, 46),
}
local DEALER_TROUSERS = {
	Color3.fromRGB(30, 34, 46), -- dark indigo denim
	Color3.fromRGB(28, 28, 31), -- black denim
	Color3.fromRGB(44, 48, 58), -- washed-out denim
}
local VAGRANT_COATS = {
	Color3.fromRGB(74, 64, 48), -- brown
	Color3.fromRGB(62, 66, 50), -- olive drab
	Color3.fromRGB(70, 70, 68), -- grey
	Color3.fromRGB(56, 46, 40), -- dark brown
}
local VAGRANT_HOODIES = {
	Color3.fromRGB(92, 38, 34), -- faded red
	Color3.fromRGB(60, 64, 72), -- faded navy
	Color3.fromRGB(96, 92, 84), -- dirty grey
}
local VAGRANT_TROUSERS = {
	Color3.fromRGB(52, 50, 46),
	Color3.fromRGB(60, 54, 42),
	Color3.fromRGB(44, 48, 56),
}
local VAGRANT_KNITS = {
	Color3.fromRGB(40, 40, 42),
	Color3.fromRGB(78, 42, 36),
	Color3.fromRGB(62, 66, 52),
	Color3.fromRGB(96, 82, 60),
}
local HAIRS = {
	Color3.fromRGB(28, 22, 18),
	Color3.fromRGB(70, 46, 30),
	Color3.fromRGB(120, 86, 50),
	Color3.fromRGB(150, 146, 140), -- grey
}

-- Hair cuts (block hair, built in layers: a top, the back, the sides, maybe a fringe).
type HairStyle = "Short" | "Fringe" | "Side" | "Bun" | "Long" | "Buzz"
-- What some wear on the head (instead of showing all their hair).
type Headwear = "Cap" | "Beanie" | "FlatCap" | "Headphones" | "Hood"
-- An outer layer worn over the shirt (alley people): its details are added on the torso.
type Jacket = "Leather" | "Hoodie" | "Coat"

type Look = {
	skin: Color3,
	shirt: Color3,
	sleeves: Color3, -- arms: the shirt colour (long sleeves) or the skin (T-shirt)
	trousers: Color3,
	hair: Color3?,
	hairStyle: HairStyle,
	headwear: Headwear?,
	headwearColor: Color3,
	apron: Color3?, -- bartender
	towel: boolean, -- bartender: a towel over the shoulder
	lanyard: boolean, -- clerk: a badge on a lanyard
	glasses: "Clear" | "Dark" | nil,
	earrings: boolean,
	watch: boolean,
	necklace: boolean,
	-- (alley people only; nil / false for everyone else)
	jacket: Jacket?,
	undershirt: Color3, -- what shows under an open jacket or coat
	cloth: Enum.Material?, -- the material of the torso and sleeves (leather, worn fabric)
	beard: Color3?,
	gloves: Color3?,
	scar: boolean,
	scarf: Color3?,
	grime: boolean, -- stains on the clothes, dirt on the skin
	detail: number, -- (alley people) a last roll, 0..1, for the small things (rings, patches...)
}

local HAIR_STYLES: { HairStyle } = { "Short", "Fringe", "Side", "Bun", "Long", "Buzz" }
local GOLD = Color3.fromRGB(212, 172, 84)
local STEEL = Color3.fromRGB(186, 188, 192)
local INK = Color3.fromRGB(20, 20, 22)

local function pick<T>(list: { T }, random: Random): T
	return list[random:NextInteger(1, #list)]
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- The colours and accessories of an NPC, from its role and seed (the same every server).
local function makeLook(role: string, seed: number): Look
	local random = Random.new(seed)
	local skin = pick(SKINS, random)
	local look: Look = {
		skin = skin,
		shirt = pick(SHIRTS, random),
		sleeves = skin,
		trousers = pick(TROUSERS, random),
		hair = if random:NextNumber() < 0.85 then pick(HAIRS, random) else nil,
		hairStyle = HAIR_STYLES[random:NextInteger(1, #HAIR_STYLES)],
		headwear = nil,
		headwearColor = pick(SHIRTS, random),
		apron = nil,
		towel = false,
		lanyard = false,
		glasses = nil,
		earrings = random:NextNumber() < 0.2,
		watch = random:NextNumber() < 0.45,
		necklace = random:NextNumber() < 0.2,
		jacket = nil,
		undershirt = INK,
		cloth = nil,
		beard = nil,
		gloves = nil,
		scar = false,
		scarf = nil,
		grime = false,
		detail = 0,
	}
	local glassesRoll = random:NextNumber()
	if glassesRoll < 0.2 then
		look.glasses = "Clear"
	elseif glassesRoll < 0.28 then
		look.glasses = "Dark"
	end
	if random:NextNumber() < 0.5 then
		look.sleeves = look.shirt -- long sleeves
	end
	if role == "Bartender" then
		-- white shirt, black trousers, long dark apron, a towel over the shoulder
		look.shirt = Color3.fromRGB(214, 210, 200)
		look.sleeves = look.shirt
		look.trousers = Color3.fromRGB(30, 30, 32)
		look.apron = Color3.fromRGB(48, 36, 30)
		look.towel = true
		look.necklace = false
		if look.hair == nil then
			look.hair = pick(HAIRS, random)
		end
	elseif role == "Clerk" then
		-- the shop's colour (a polo, see the collar) and a badge on a lanyard; some wear a cap
		look.lanyard = true
		look.necklace = false
		if random:NextNumber() < 0.5 then
			look.headwear = "Cap"
			look.headwearColor = Color3.fromRGB(28, 28, 30)
		end
	elseif role == "Dealer" then
		-- A fence of stolen goods: dark, worn, a bit of gold. A worn biker jacket open on a
		-- dark tee, or a hoodie (the hood up, most of the time). Dark jeans, black boots, a
		-- beanie or a black cap, sometimes a scar across the cheek, stubble. Bare hands (rings,
		-- a gold watch), a gold chain, a cigarette, a sling bag, a duffel at his feet
		-- (see addDealerOutfit).
		-- (These rolls come after the common ones: the other roles keep their looks.)
		if random:NextNumber() < 0.5 then
			look.jacket = "Leather"
			look.shirt = pick(DEALER_LEATHER, random)
			look.cloth = Enum.Material.Leather
			look.headwear = if random:NextNumber() < 0.6 then "Beanie" else "Cap"
		else
			look.jacket = "Hoodie"
			look.shirt = pick(DEALER_HOODIES, random)
			look.cloth = Enum.Material.Fabric
			look.headwear = if random:NextNumber() < 0.7 then "Hood" else "Beanie"
		end
		look.sleeves = look.shirt
		look.undershirt = if random:NextNumber() < 0.6 then INK else Color3.fromRGB(64, 64, 66)
		look.trousers = pick(DEALER_TROUSERS, random)
		look.headwearColor = if look.headwear == "Hood"
			then look.shirt
			else pick({ INK, Color3.fromRGB(38, 38, 40), Color3.fromRGB(46, 42, 38) }, random)
		look.gloves = nil -- (bare hands: the rings and the watch show)
		look.watch = false -- (his own gold one: see addDealerOutfit)
		look.necklace = false -- (his own chain)
		look.earrings = false
		look.glasses = if random:NextNumber() < 0.15 then "Dark" else nil
		look.scar = random:NextNumber() < 0.45
		look.beard = if random:NextNumber() < 0.35 then darker(pick(HAIRS, random), 0.1) else nil
		look.hair = look.hair or pick(HAIRS, random)
		look.detail = random:NextNumber()
	elseif role == "Vagrant" then
		-- A man who sleeps out here: layers of dirty clothes (a long coat over a hoodie, a
		-- scarf), a beanie, knitted gloves, a beard (often grey), stains, grime on the skin.
		look.jacket = "Coat"
		look.shirt = pick(VAGRANT_COATS, random)
		look.sleeves = look.shirt
		look.cloth = Enum.Material.Fabric
		look.undershirt = pick(VAGRANT_HOODIES, random)
		look.trousers = pick(VAGRANT_TROUSERS, random)
		look.headwear = "Beanie"
		look.headwearColor = pick(VAGRANT_KNITS, random)
		look.scarf = pick(VAGRANT_KNITS, random)
		look.gloves = darker(pick(VAGRANT_KNITS, random), 0.25)
		look.hair = if random:NextNumber() < 0.5 then HAIRS[4] else pick(HAIRS, random)
		look.hairStyle = "Long"
		look.beard = look.hair
		look.skin = look.skin:Lerp(Color3.fromRGB(70, 52, 40), 0.15) -- weathered, dirty
		look.grime = true
		look.glasses = nil
		look.earrings = false
		look.watch = false
		look.necklace = false
		look.detail = random:NextNumber()
	else
		local roll = random:NextNumber()
		if roll < 0.2 then
			look.headwear = "Beanie"
		elseif roll < 0.32 then
			look.headwear = "FlatCap"
			look.headwearColor = pick(TROUSERS, random)
		elseif roll < 0.42 then
			look.headwear = "Cap"
		elseif roll < 0.5 then
			look.headwear = "Headphones"
			look.headwearColor = INK
		end
	end
	return look
end

-- A small block welded to a body part (accessories). `offset` is in the body part's space.
local function addBlock(
	model: Model,
	body: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	-- (tiny bits — studs, lenses, buttons — cast no shadow: cleaner and cheaper)
	part.CastShadow = size.X > 0.3 and size.Y > 0.3
	part.CFrame = body.CFrame * offset
	-- A Weld (not a WeldConstraint): it keeps the exact offset from the body part while the
	-- client poses the joints (a WeldConstraint would work too, but its offset is taken from
	-- wherever the parts are when it is made; a Weld's C0 is explicit).
	local weld = Instance.new("Weld")
	weld.Name = "Attach"
	weld.Part0 = body
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = model
	return part
end

-- A flat strip lying on the FRONT of a body part (a strap, a chain), going from point `a`
-- to point `b` (both in the body part's space, same Z): its length runs along a -> b,
-- `width` across, `depth` front-to-back. (Angles on Z turn the strip's Y axis onto a -> b:
-- turning by φ sends Y to (-sin φ, cos φ), so φ = atan2(-dx, dy).)
local function addStrip(
	model: Model,
	body: BasePart,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	depth: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local delta = b - a
	local length = Vector3.new(delta.X, delta.Y, 0).Magnitude
	return addBlock(
		model,
		body,
		name,
		Vector3.new(width, length, depth),
		CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, math.atan2(-delta.X, delta.Y)),
		color,
		material
	)
end

-- Block hair in layers. The R6 head looks about 1.25 studs wide, tall and deep: its top is
-- 0.62 above its centre, its face 0.62 in front (-Z), its sides 0.62 left / right.
-- `covered` = a hat is on (only what shows under it: the back and the sides).
local function addHair(model: Model, head: BasePart, look: Look, covered: boolean)
	local color = look.hair
	if color == nil then
		return
	end
	local style = look.hairStyle
	local shade = darker(color, 0.18) -- the under layer, a touch darker (gives depth)
	local fabric = Enum.Material.Fabric
	if not covered then
		if style == "Buzz" then
			-- a very short cut: a thin shell on the top
			addBlock(
				model,
				head,
				"HairTop",
				Vector3.new(1.28, 0.12, 1.28),
				CFrame.new(0, 0.62, 0.02),
				color,
				fabric
			)
		else
			-- the top, and a second, smaller layer on it (volume)
			addBlock(
				model,
				head,
				"HairTop",
				Vector3.new(1.32, 0.26, 1.32),
				CFrame.new(0, 0.56, 0.03),
				shade,
				fabric
			)
			addBlock(
				model,
				head,
				"HairCrown",
				Vector3.new(1.16, 0.12, 1.12),
				CFrame.new(0.03, 0.73, 0.06),
				color,
				fabric
			)
		end
		if style == "Fringe" then
			-- a fringe falling on the forehead, uneven
			addBlock(
				model,
				head,
				"Fringe",
				Vector3.new(1.3, 0.2, 0.14),
				CFrame.new(0, 0.44, -0.62),
				color,
				fabric
			)
			addBlock(
				model,
				head,
				"FringeTip",
				Vector3.new(0.46, 0.14, 0.12),
				-- (its front 0.005 prouder than the fringe; it ends above the glasses' top bar)
				CFrame.new(-0.32, 0.345, -0.635),
				color,
				fabric
			)
		elseif style == "Side" then
			-- parted on the side: a swoop over one eye-brow
			addBlock(
				model,
				head,
				"Swoop",
				Vector3.new(0.86, 0.18, 0.16),
				CFrame.new(0.2, 0.47, -0.6) * CFrame.Angles(0, 0, math.rad(-8)),
				color,
				fabric
			)
		elseif style == "Bun" then
			addBlock(
				model,
				head,
				"Bun",
				Vector3.new(0.44, 0.38, 0.38),
				CFrame.new(0, 0.66, 0.56),
				color,
				fabric
			)
			addBlock(
				model,
				head,
				"BunTie",
				-- (a hair bigger than the bun all round: no two faces in the same plane)
				Vector3.new(0.46, 0.08, 0.42),
				CFrame.new(0, 0.5, 0.56),
				INK
			)
		end
	end
	if style == "Buzz" then
		return -- (no back / sides to speak of)
	end
	-- the back of the head (long hair goes down to the neck)
	local long = style == "Long"
	local backHeight = if long then 1.05 else 0.6
	addBlock(
		model,
		head,
		"HairBack",
		Vector3.new(1.3, backHeight, 0.2), -- (0.01 behind HairTop's back face: no flicker)
		CFrame.new(0, 0.58 - backHeight / 2, 0.6),
		shade,
		fabric
	)
	-- the sides (sideburns, or long strands). Under a hat they stop below its edge (they
	-- reach 0.69 out: a hair wider than a beanie's body or a cap's crown, they poked through
	-- their sides).
	local sideTop = if covered then 0.34 else (if long then 0.58 else 0.57)
	local sideBottom = if long then -0.32 else 0.15
	for _, side in { -1, 1 } do
		addBlock(
			model,
			head,
			if side < 0 then "HairLeft" else "HairRight",
			Vector3.new(0.12, sideTop - sideBottom, if long then 1.0 else 0.82),
			CFrame.new(side * 0.63, (sideTop + sideBottom) / 2, if long then 0.1 else 0.18),
			shade,
			fabric
		)
	end
end

local function addHeadwear(model: Model, head: BasePart, look: Look, shopColor: Color3?)
	local kind = look.headwear
	local color = look.headwearColor
	local fabric = Enum.Material.Fabric
	if kind == "Cap" then
		-- a baseball cap: crown, a button on top, a curved-down brim, the strap at the back
		addBlock(
			model,
			head,
			"CapCrown",
			Vector3.new(1.34, 0.36, 1.34),
			CFrame.new(0, 0.58, 0.02),
			color,
			fabric
		)
		addBlock(
			model,
			head,
			"CapTop",
			Vector3.new(1.08, 0.08, 1.08),
			CFrame.new(0, 0.79, 0.04),
			color,
			fabric
		)
		addBlock(
			model,
			head,
			"CapButton",
			Vector3.new(0.16, 0.08, 0.16),
			CFrame.new(0, 0.86, 0.04),
			darker(color, 0.25)
		)
		addBlock(
			model,
			head,
			"CapBrim",
			Vector3.new(1.12, 0.07, 0.6),
			CFrame.new(0, 0.43, -0.93) * CFrame.Angles(math.rad(-8), 0, 0),
			darker(color, 0.1)
		)
		addBlock(
			model,
			head,
			"CapStrap",
			Vector3.new(0.5, 0.12, 0.05),
			CFrame.new(0, 0.47, 0.68), -- (its bottom 0.01 above the crown's: no flicker)
			darker(color, 0.3)
		)
		-- the shop's logo patch (clerks) or a small white one
		addBlock(
			model,
			head,
			"CapLogo",
			Vector3.new(0.42, 0.18, 0.04),
			CFrame.new(0, 0.6, -0.665), -- (its back sunk 0.005 in the crown's front at -0.65)
			shopColor or Color3.fromRGB(226, 222, 212)
		)
	elseif kind == "Beanie" then
		-- a knitted beanie: the body, a turned-up fold, a flatter top
		addBlock(
			model,
			head,
			"Beanie",
			Vector3.new(1.36, 0.46, 1.36),
			CFrame.new(0, 0.58, 0),
			color,
			fabric
		)
		addBlock(
			model,
			head,
			"BeanieFold",
			Vector3.new(1.42, 0.2, 1.42),
			CFrame.new(0, 0.36, 0),
			darker(color, 0.15),
			fabric
		)
		addBlock(
			model,
			head,
			"BeanieTop",
			Vector3.new(1.1, 0.12, 1.1),
			CFrame.new(0, 0.86, 0),
			color,
			fabric
		)
		addBlock(
			model,
			head,
			"BeanieTag",
			Vector3.new(0.24, 0.12, 0.04),
			CFrame.new(0.3, 0.36, -0.72),
			Color3.fromRGB(226, 222, 212)
		)
	elseif kind == "FlatCap" then
		-- a flat (newsboy) cap: low, wide crown sloping to a short brim
		addBlock(
			model,
			head,
			"FlatCrown",
			Vector3.new(1.38, 0.24, 1.42),
			CFrame.new(0, 0.62, -0.04) * CFrame.Angles(math.rad(-5), 0, 0),
			color,
			fabric
		)
		addBlock(
			model,
			head,
			"FlatBrim",
			Vector3.new(1.12, 0.06, 0.36),
			CFrame.new(0, 0.52, -0.82) * CFrame.Angles(math.rad(-10), 0, 0),
			darker(color, 0.12),
			fabric
		)
		addBlock(
			model,
			head,
			"FlatSeam",
			Vector3.new(0.06, 0.04, 1.2),
			-- tilted like the crown and half sunk in its top (level, it floated at the front)
			CFrame.new(0, 0.62, -0.04)
				* CFrame.Angles(math.rad(-5), 0, 0)
				* CFrame.new(0, 0.12, 0),
			darker(color, 0.25)
		)
	elseif kind == "Hood" then
		-- a hoodie's hood, up: a shell around the head, open at the face, its top edge
		-- jutting over the forehead (the face stays in its shadow), falling onto the shoulders
		local shade = darker(color, 0.12)
		addBlock(
			model,
			head,
			"HoodTop",
			Vector3.new(1.46, 0.2, 1.4),
			CFrame.new(0, 0.72, 0.06),
			color,
			fabric
		)
		addBlock(
			model,
			head,
			"HoodBack",
			-- (its top 0.02 under HoodTop's, its sides 0.1 inside the side panels: no flicker)
			Vector3.new(1.46, 1.28, 0.22),
			CFrame.new(0, 0.16, 0.66),
			shade,
			fabric
		)
		for _, side in { -1, 1 } do
			addBlock(
				model,
				head,
				if side < 0 then "HoodLeft" else "HoodRight",
				Vector3.new(0.2, 1.24, 1.2),
				CFrame.new(side * 0.73, 0.12, 0.02),
				color,
				fabric
			)
		end
		-- the dark inside of the hood, seen under its edge on the forehead
		addBlock(
			model,
			head,
			"HoodShade",
			Vector3.new(1.2, 0.12, 0.1),
			CFrame.new(0, 0.56, -0.6),
			darker(color, 0.6),
			fabric
		)
	elseif kind == "Headphones" then
		-- big headphones: the band over the head, two padded cups on the ears.
		-- The band RESTS on whatever is on top of the head (it floated 0.07 above a bald
		-- head, and its top was in the same plane as the hair's crown: flicker):
		-- the bare head's top is 0.625 above its centre, buzz hair 0.68, other cuts 0.79.
		local onTop = if look.hair == nil
			then 0.625
			elseif look.hairStyle == "Buzz" then 0.68
			else 0.79
		local bandY = onTop + 0.04 -- (band 0.1 thick: sunk 0.01 into what it rests on)
		addBlock(
			model,
			head,
			"PhonesBand",
			Vector3.new(1.46, 0.1, 0.22),
			CFrame.new(0, bandY, 0.02),
			color
		)
		-- the metal arms, from inside the band's ends down into the cups (top 0.33)
		local armTop = bandY + 0.03
		local armBottom = 0.29
		for _, side in { -1, 1 } do
			addBlock(
				model,
				head,
				if side < 0 then "PhonesLeft" else "PhonesRight",
				Vector3.new(0.18, 0.5, 0.46),
				CFrame.new(side * 0.72, 0.08, 0.02),
				color
			)
			addBlock(
				model,
				head,
				if side < 0 then "PhonesPadL" else "PhonesPadR",
				Vector3.new(0.06, 0.36, 0.34),
				CFrame.new(side * 0.83, 0.08, 0.02),
				darker(color, -0.6)
			)
			addBlock(
				model,
				head,
				if side < 0 then "PhonesArmL" else "PhonesArmR",
				Vector3.new(0.08, armTop - armBottom, 0.12),
				CFrame.new(side * 0.7, (armTop + armBottom) / 2, 0.02),
				STEEL,
				Enum.Material.Metal
			)
		end
	end
end

-- Glasses. The R6 head is ROUND seen from above (a cylinder about 1.25 across: radius
-- 0.625), not a box: away from the middle, its face curves back (at 0.27 to the side, where
-- the eyes are, it is already 0.06 behind the nose; at 0.5, 0.25 behind). So, like real
-- glasses, the front is a flat frame resting on the nose and WIDER than the face: its two
-- end pieces reach the sides of the head (0.645 out), and the temples start right there,
-- touching the end pieces, and run straight back along the sides of the head to the ears
-- (just behind its middle), sloping a little down. (Before, the frame stopped 0.48 out and
-- the temples began 0.64 out: a 0.16 gap, they looked stuck in the air.)
-- Each lens is held by 4 thin bars (no dark block behind it: clear lenses stay clear).
local EYE_Y = 0.12 -- height of the eyes above the head's centre
local GLASSES_Z = -0.65 -- the frame's middle plane (its back touches the nose at -0.625+)
local TEMPLE_X = 0.645 -- the temples, just outside the head's side (0.625)

local function addGlasses(model: Model, head: BasePart, kind: "Clear" | "Dark")
	local frame = INK
	local lensColor = if kind == "Dark"
		then Color3.fromRGB(16, 18, 22)
		else Color3.fromRGB(190, 214, 224)
	for _, side in { -1, 1 } do
		local function name(base: string): string
			return base .. (if side < 0 then "L" else "R")
		end
		-- one lens: 0.44 wide, 0.3 tall outside, centred 0.27 to the side
		local x = side * 0.27
		addBlock(
			model,
			head,
			name("RimTop"),
			Vector3.new(0.44, 0.05, 0.04),
			CFrame.new(x, EYE_Y + 0.125, GLASSES_Z),
			frame
		)
		addBlock(
			model,
			head,
			name("RimBottom"),
			Vector3.new(0.44, 0.04, 0.04),
			CFrame.new(x, EYE_Y - 0.13, GLASSES_Z),
			frame
		)
		for _, edge in { -1, 1 } do
			-- the inner (nose) and outer bars, between the top and bottom bars
			addBlock(
				model,
				head,
				name(if edge * side < 0 then "RimInner" else "RimOuter"),
				Vector3.new(0.04, 0.21, 0.04),
				CFrame.new(x + edge * 0.2, EYE_Y - 0.005, GLASSES_Z),
				frame
			)
		end
		local lens = addBlock(
			model,
			head,
			name("Lens"),
			Vector3.new(0.36, 0.21, 0.02),
			CFrame.new(x, EYE_Y - 0.005, GLASSES_Z),
			lensColor,
			Enum.Material.Glass
		)
		lens.Transparency = if kind == "Dark" then 0.05 else 0.55
		lens.Reflectance = 0.15
		-- the end piece: from the outer bar (0.47 .. 0.49 out) to the temple's outer side
		addBlock(
			model,
			head,
			name("EndPiece"),
			Vector3.new(TEMPLE_X + 0.02 - 0.47, 0.05, 0.036), -- (thinner: its faces are not in the rims' planes)
			CFrame.new(side * (0.47 + TEMPLE_X + 0.02) / 2, EYE_Y + 0.11, GLASSES_Z),
			frame
		)
		-- the temple: starts inside the end piece, ends at the ear, sloping down a little.
		-- CFrame.lookAt(middle, back end): the block's length (its Z) runs along it.
		local front = Vector3.new(side * TEMPLE_X, EYE_Y + 0.11, GLASSES_Z)
		local back = Vector3.new(side * TEMPLE_X, EYE_Y + 0.02, 0.06)
		addBlock(
			model,
			head,
			name("Temple"),
			Vector3.new(0.04, 0.05, (back - front).Magnitude),
			CFrame.lookAt((front + back) / 2, back),
			frame
		)
		-- its tip, bent down behind the ear
		addBlock(
			model,
			head,
			name("TempleTip"),
			Vector3.new(0.04, 0.14, 0.05),
			CFrame.new(side * TEMPLE_X, EYE_Y - 0.03, 0.07),
			frame
		)
	end
	-- the bridge over the nose, between the two inner bars (0.05 .. 0.09 out)
	addBlock(
		model,
		head,
		"Bridge",
		Vector3.new(0.12, 0.05, 0.04),
		CFrame.new(0, EYE_Y + 0.06, GLASSES_Z),
		frame
	)
end

------------------------------------------------------------------------------
-- The alley people's clothes (the dealer of the black market, the vagrant of the squat).
--
-- Built like real clothes, in layers, on the R6 blocks (torso 2 × 2 × 1, arms and legs
-- 1 × 2 × 1, the head a rounded 1.25 block): the body part is the outer garment's colour,
-- then come what shows under it (the tee in an open jacket), the garment's own parts
-- (lapels, collar, zips, cuffs, hems, pockets, seams), what is worn over it (a strap, a
-- scarf), and the wear (rubbed elbows and knees, stains, patches, frayed edges).
-- Same rules as the rest of this file: a flat thing lies with its back ON the cloth, a part
-- over another is 0.005-0.01 prouder or wider (no two visible faces in one plane: no
-- flicker). Bands around a leg are flush with its INNER side (the two legs touch: two bands
-- 0.02 wider on both sides would overlap there) and 0.02 proud on the other three.
------------------------------------------------------------------------------

local FABRIC = Enum.Material.Fabric
local LEATHER = Enum.Material.Leather
local METAL = Enum.Material.Metal

local function bodyPart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- A band around a leg (see above): `height` tall at `y`, 0.02 proud (`grow` more if given).
local function legBand(
	model: Model,
	leg: BasePart,
	side: number,
	name: string,
	y: number,
	height: number,
	color: Color3,
	material: Enum.Material?,
	grow: number?
): BasePart
	local extra = grow or 0.02
	return addBlock(
		model,
		leg,
		name,
		Vector3.new(1 + extra, height, 1 + extra * 2),
		CFrame.new(side * extra / 2, y, 0),
		color,
		material
	)
end

-- A small anchored prop standing on the floor next to an NPC (not welded: it never moves).
local function floorProp(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = size.X > 0.3 and size.Y > 0.3
	part.CFrame = cframe
	part.Parent = model
	return part
end

-- Work boots on both legs (the leg is 1 × 2 × 1, its bottom on the floor at -1): the shaft
-- around the ankle, a toe cap sticking out in front (R6 legs have no feet), the welt, a
-- thick sole with a heel and treads (seen from the front when he sits, legs stretched out),
-- the tongue, the laces through their eyelets, a bow, the pull tab at the back.
-- `worn`: scuffed toes, the right sole coming off at the toe, a strip of tape round the left
-- boot, odd laces.
local function addBoots(model: Model, upper: Color3, sole: Color3, laces: Color3, worn: boolean)
	for _, side in { -1, 1 } do
		local leg = bodyPart(model, if side < 0 then "Left Leg" else "Right Leg")
		if leg == nil then
			continue
		end
		local s = if side < 0 then "L" else "R"
		local x = side * 0.02 -- (flush inside, 0.04 proud outside)
		legBand(model, leg, side, "BootShaft" .. s, -0.6, 0.6, upper, LEATHER)
		addBlock(
			model,
			leg,
			"BootToe" .. s,
			Vector3.new(0.94, 0.3, 0.34),
			CFrame.new(x, -0.74, -0.64),
			upper,
			LEATHER
		)
		addBlock(
			model,
			leg,
			"BootToeTip" .. s,
			Vector3.new(0.8, 0.22, 0.1),
			CFrame.new(x, -0.78, -0.85),
			darker(upper, 0.08),
			LEATHER
		)
		addBlock(
			model,
			leg,
			"BootWelt" .. s,
			Vector3.new(1.045, 0.035, 1.505),
			CFrame.new(x, -0.875, -0.2),
			darker(upper, 0.35),
			LEATHER
		)
		local soleRight = worn and side > 0
		addBlock(
			model,
			leg,
			"BootSole" .. s,
			-- (the right one of a worn pair: only its back part, the front comes off below)
			if soleRight then Vector3.new(1.04, 0.12, 0.98) else Vector3.new(1.04, 0.12, 1.5),
			CFrame.new(x, -0.94, if soleRight then 0.06 else -0.2),
			sole,
			Enum.Material.Rubber
		)
		if soleRight then
			-- the sole's front, come unstuck: hinged at the ball of the foot, gaping open
			-- (the dark gap shows between it and the upper)
			addBlock(
				model,
				leg,
				"SoleFlap",
				Vector3.new(1.04, 0.1, 0.52),
				CFrame.new(x, -0.94, -0.43)
					* CFrame.Angles(math.rad(-10), 0, 0)
					* CFrame.new(0, -0.01, -0.26),
				sole,
				Enum.Material.Rubber
			)
			addBlock(
				model,
				leg,
				"SoleGap",
				Vector3.new(0.96, 0.06, 0.42),
				CFrame.new(x, -0.92, -0.68),
				Color3.fromRGB(12, 10, 9)
			)
		end
		addBlock(
			model,
			leg,
			"BootHeel" .. s,
			Vector3.new(1.0, 0.1, 0.42),
			CFrame.new(x, -0.99, 0.3), -- (0.04 under the sole: a heel seen from the front)
			darker(sole, 0.2),
			Enum.Material.Rubber
		)
		for index, z in { -0.78, -0.56, -0.34 } do
			if soleRight and index < 3 then
				continue -- (on the flap: no treads there)
			end
			addBlock(
				model,
				leg,
				"Tread",
				Vector3.new(0.94, 0.03, 0.07),
				CFrame.new(x, -1.01, z),
				darker(sole, 0.3),
				Enum.Material.Rubber
			)
		end
		-- the tongue over the instep, the laces (four bars) and their eyelets, a bow
		addBlock(
			model,
			leg,
			"BootTongue" .. s,
			Vector3.new(0.34, 0.32, 0.04),
			CFrame.new(side * 0.01, -0.48, -0.53),
			darker(upper, 0.12),
			LEATHER
		)
		local laceColor = if worn and side < 0 then Color3.fromRGB(150, 138, 112) else laces
		for row = 0, 3 do
			local y = -0.37 - row * 0.06
			addBlock(
				model,
				leg,
				"Lace",
				Vector3.new(0.42, 0.03, 0.03),
				CFrame.new(side * 0.01, y, -0.555)
					* CFrame.Angles(0, 0, math.rad(if row % 2 == 0 then 6 else -6)),
				laceColor,
				FABRIC
			)
			for _, edge in { -1, 1 } do
				addBlock(
					model,
					leg,
					"Eyelet",
					Vector3.new(0.05, 0.05, 0.02),
					CFrame.new(side * 0.01 + edge * 0.22, y, -0.53),
					Color3.fromRGB(120, 112, 96),
					METAL
				)
			end
		end
		addBlock(
			model,
			leg,
			"LaceKnot",
			Vector3.new(0.1, 0.07, 0.04),
			CFrame.new(side * 0.01, -0.35, -0.565),
			laceColor,
			FABRIC
		)
		for _, edge in { -1, 1 } do
			addBlock(
				model,
				leg,
				"LaceLoop",
				Vector3.new(0.05, 0.17, 0.025),
				CFrame.new(side * 0.01 + edge * 0.07, -0.43, -0.575)
					* CFrame.Angles(0, 0, math.rad(edge * 28)),
				laceColor,
				FABRIC
			)
		end
		addBlock(
			model,
			leg,
			"PullTab" .. s,
			Vector3.new(0.2, 0.16, 0.03),
			CFrame.new(side * 0.01, -0.26, 0.535),
			darker(upper, 0.25),
			LEATHER
		)
		if worn then
			-- scuffed toe leather (lighter, rubbed), and grey tape round the left boot's ankle
			addBlock(
				model,
				leg,
				"ToeScuff",
				Vector3.new(0.5, 0.01, 0.2),
				CFrame.new(x - side * 0.1, -0.587, -0.68),
				upper:Lerp(Color3.fromRGB(150, 140, 120), 0.35),
				LEATHER
			)
			if side < 0 then
				legBand(
					model,
					leg,
					side,
					"Tape",
					-0.68,
					0.12,
					Color3.fromRGB(128, 128, 124),
					FABRIC,
					0.03
				)
			end
		end
	end
end

-- Bare hands: the bottom 0.42 of the arm in skin (an R6 arm is all the sleeve's colour).
local function addHand(model: Model, arm: BasePart, skin: Color3): BasePart
	return addBlock(model, arm, "Hand", Vector3.new(1.02, 0.42, 1.02), CFrame.new(0, -0.8, 0), skin)
end

-- The curled fingers seen on the end of a fist (the bottom of the arm, 0.01 under it).
local function addKnuckles(model: Model, arm: BasePart, skin: Color3)
	for _, x in { -0.2, 0.02, 0.22 } do
		addBlock(
			model,
			arm,
			"Knuckle",
			Vector3.new(0.015, 0.01, 0.8),
			CFrame.new(x, -1.012, 0.05),
			darker(skin, 0.45)
		)
	end
end

-- A chunky gold curb chain lying on the chest (two strands from the sides of the neck down
-- to a cross), on a surface at depth `surface` (torso space: -0.5 the torso's own front).
local function addChain(model: Model, torso: BasePart, surface: number, top: number, bottom: number)
	for _, side in { -1, 1 } do
		local a = Vector3.new(side * 0.21, top, 0)
		local b = Vector3.new(side * 0.025, bottom, 0)
		local delta = b - a
		local count = math.max(2, math.floor(delta.Magnitude / 0.07))
		local angle = math.atan2(-delta.X, delta.Y)
		for index = 0, count do
			local point = a + delta * (index / count)
			-- links alternate wide-flat and narrow-proud: it reads as a twisted curb chain
			local wide = index % 2 == 0
			local depth = if wide then 0.025 else 0.032
			addBlock(
				model,
				torso,
				"ChainLink",
				Vector3.new(if wide then 0.075 else 0.048, 0.085, depth),
				CFrame.new(point.X, point.Y, surface - depth / 2) * CFrame.Angles(0, 0, angle),
				GOLD,
				METAL
			)
		end
	end
	-- the cross (the crossbar 0.005 prouder than the upright), on a ring
	addBlock(
		model,
		torso,
		"CrossRing",
		Vector3.new(0.05, 0.05, 0.03),
		CFrame.new(0, bottom - 0.02, surface - 0.015),
		GOLD,
		METAL
	)
	addBlock(
		model,
		torso,
		"Cross",
		Vector3.new(0.06, 0.24, 0.03),
		CFrame.new(0, bottom - 0.16, surface - 0.015),
		GOLD,
		METAL
	)
	addBlock(
		model,
		torso,
		"CrossBar",
		Vector3.new(0.16, 0.05, 0.035),
		CFrame.new(0, bottom - 0.11, surface - 0.0175),
		GOLD,
		METAL
	)
end

-- A lit cigarette at the corner of the mouth, pointing down and out: the filter in the lips,
-- the paper, the glowing end (Neon, a faint orange light on the face), the ash, a thin wisp
-- of smoke.
local function addCigarette(model: Model, head: BasePart)
	local lip = Vector3.new(0.16, -0.3, -0.56) -- (inside the round head's face: the lips)
	local tip = Vector3.new(0.38, -0.43, -0.96)
	local direction = (tip - lip).Unit
	local length = (tip - lip).Magnitude
	local function along(from: number, to: number): CFrame
		local middle = lip + direction * ((from + to) / 2)
		return CFrame.lookAt(middle, middle + direction)
	end
	addBlock(
		model,
		head,
		"CigFilter",
		Vector3.new(0.05, 0.05, 0.11),
		along(0, 0.11),
		Color3.fromRGB(196, 142, 84)
	)
	addBlock(
		model,
		head,
		"CigPaper",
		Vector3.new(0.045, 0.045, length - 0.16),
		along(0.11, length - 0.05),
		Color3.fromRGB(232, 228, 216)
	)
	local ember = addBlock(
		model,
		head,
		"CigEmber",
		Vector3.new(0.05, 0.05, 0.025),
		along(length - 0.05, length - 0.025),
		Color3.fromRGB(255, 108, 40),
		Enum.Material.Neon
	)
	local ash = addBlock(
		model,
		head,
		"CigAsh",
		Vector3.new(0.043, 0.043, 0.03),
		along(length - 0.025, length + 0.005),
		Color3.fromRGB(120, 116, 110)
	)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 50)
	glow.Range = 2.2
	glow.Brightness = 0.7
	glow.Shadows = false
	glow.Parent = ember
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "CigSmoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(170, 168, 162))
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.06),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	smoke.Lifetime = NumberRange.new(1.8, 2.8)
	smoke.Rate = 4
	smoke.Speed = NumberRange.new(0.2, 0.45)
	smoke.SpreadAngle = Vector2.new(18, 18)
	smoke.Acceleration = Vector3.new(0, 0.5, 0)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-25, 25)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.LightInfluence = 1
	smoke.Parent = ash
end

-- The dealer (role "Dealer", look from makeLook).
local function addDealerOutfit(model: Model, look: Look)
	local torso = bodyPart(model, "Torso")
	local head = bodyPart(model, "Head")
	if torso == nil or head == nil then
		return
	end
	local base = look.shirt
	local cloth = look.cloth or FABRIC
	local seamColor = darker(base, 0.35)
	-- rubbed-in wear: leather and black cotton go grey-brown where they rub
	local worn = base:Lerp(Color3.fromRGB(112, 104, 94), 0.2)
	local steel = Color3.fromRGB(150, 150, 152)
	local leather = look.jacket == "Leather"
	local hoodUp = look.headwear == "Hood"

	if leather then
		-- A worn biker jacket, open: the tee in the opening (its neckline), the jacket's
		-- front edges with their zips (one pull hanging at the bottom), wide lapels with a
		-- snap at each tip, a collar round the back and sides of the neck, epaulettes with a
		-- stud, a chest zip pocket, two slanted pockets, the waistband, a yoke seam behind.
		local half = 0.25
		addBlock(
			model,
			torso,
			"Undershirt",
			Vector3.new(half * 2, 1.86, 0.02),
			CFrame.new(0, -0.06, -0.51),
			look.undershirt,
			FABRIC
		)
		addBlock(
			model,
			torso,
			"TeeNeck",
			Vector3.new(half * 2 - 0.02, 0.05, 0.012),
			CFrame.new(0, 0.83, -0.524),
			darker(look.undershirt, -0.15),
			FABRIC
		)
		for _, side in { -1, 1 } do
			local s = if side < 0 then "L" else "R"
			addBlock(
				model,
				torso,
				"JacketEdge" .. s,
				Vector3.new(0.07, 1.98, 0.04),
				CFrame.new(side * (half + 0.025), 0, -0.52),
				darker(base, 0.18),
				cloth
			)
			addBlock(
				model,
				torso,
				"Zip" .. s,
				Vector3.new(0.03, 1.84, 0.045),
				CFrame.new(side * half, -0.06, -0.5225),
				steel,
				METAL
			)
			local lapel = CFrame.new(side * 0.47, 0.6, -0.525)
				* CFrame.Angles(0, 0, math.rad(-side * 16))
			addBlock(
				model,
				torso,
				"Lapel" .. s,
				Vector3.new(0.36, 0.62, 0.05),
				lapel,
				darker(base, 0.06),
				cloth
			)
			addBlock(
				model,
				torso,
				"LapelSnap" .. s,
				Vector3.new(0.06, 0.06, 0.02),
				lapel * CFrame.new(-side * 0.09, -0.24, -0.03),
				steel,
				METAL
			)
			addBlock(
				model,
				torso,
				"CollarSide" .. s,
				Vector3.new(0.16, 0.26, 1.0),
				CFrame.new(side * 0.64, 0.99, 0),
				darker(base, 0.1),
				cloth
			)
			addBlock(
				model,
				torso,
				"Epaulette" .. s,
				Vector3.new(0.42, 0.04, 0.2),
				CFrame.new(side * 0.76, 1.02, 0),
				darker(base, 0.1),
				cloth
			)
			addBlock(
				model,
				torso,
				"EpauletteStud" .. s,
				Vector3.new(0.07, 0.03, 0.07),
				CFrame.new(side * 0.6, 1.045, 0),
				steel,
				METAL
			)
			-- slanted hand-warmer pockets: a welt and its zip
			addStrip(
				model,
				torso,
				"Pocket" .. s,
				Vector3.new(side * 0.5, -0.74, -0.515),
				Vector3.new(side * 0.76, -0.34, -0.515),
				0.06,
				0.03,
				seamColor,
				cloth
			)
		end
		addBlock(
			model,
			torso,
			"ZipPull",
			Vector3.new(0.06, 0.13, 0.025),
			CFrame.new(-half, -0.86, -0.5575),
			steel,
			METAL
		)
		addBlock(
			model,
			torso,
			"CollarBack",
			Vector3.new(1.44, 0.26, 0.16),
			CFrame.new(0, 0.99, 0.46),
			darker(base, 0.1),
			cloth
		)
		addBlock(
			model,
			torso,
			"ChestZip",
			Vector3.new(0.36, 0.03, 0.012),
			CFrame.new(-0.66, 0.06, -0.506),
			steel,
			METAL
		)
		addBlock(
			model,
			torso,
			"ChestZipPull",
			Vector3.new(0.04, 0.1, 0.02),
			CFrame.new(-0.49, 0.02, -0.51),
			steel,
			METAL
		)
		addBlock(
			model,
			torso,
			"JacketHem",
			Vector3.new(2.02, 0.16, 1.02),
			CFrame.new(0, -0.92, 0),
			darker(base, 0.15),
			cloth
		)
		addBlock(
			model,
			torso,
			"YokeSeam",
			Vector3.new(2.0, 0.03, 0.012),
			CFrame.new(0, 0.45, 0.506),
			seamColor,
			cloth
		)
		-- rubbed shoulders (the leather goes matt and grey on top)
		for _, side in { -1, 1 } do
			addBlock(
				model,
				torso,
				"ShoulderWear",
				Vector3.new(0.3, 0.012, 0.6),
				CFrame.new(side * 0.42, 1.006, 0.06),
				worn,
				cloth
			)
		end
		-- the belt in the opening (black leather, a steel buckle)
		addBlock(
			model,
			torso,
			"Belt",
			Vector3.new(half * 2, 0.12, 0.02),
			CFrame.new(0, -0.82, -0.525),
			INK,
			LEATHER
		)
		addBlock(
			model,
			torso,
			"Buckle",
			Vector3.new(0.14, 0.12, 0.025),
			CFrame.new(0.02, -0.82, -0.5475),
			steel,
			METAL
		)
		addChain(model, torso, -0.52, 0.86, 0.66)
	else
		-- A heavy black hoodie: the kangaroo pocket (its slanted openings, the seam on top), the
		-- ribbed hem, the drawstrings with metal tips, a faded print on the chest.
		addBlock(
			model,
			torso,
			"HoodiePocket",
			Vector3.new(1.2, 0.5, 0.04),
			CFrame.new(0, -0.6, -0.52),
			darker(base, 0.06),
			FABRIC
		)
		addBlock(
			model,
			torso,
			"PocketSeam",
			Vector3.new(0.86, 0.025, 0.01),
			CFrame.new(0, -0.37, -0.545),
			seamColor,
			FABRIC
		)
		for _, side in { -1, 1 } do
			addStrip(
				model,
				torso,
				"PocketOpening",
				Vector3.new(side * 0.44, -0.37, -0.545),
				Vector3.new(side * 0.58, -0.82, -0.545),
				0.05,
				0.02,
				darker(base, 0.45),
				FABRIC
			)
		end
		addBlock(
			model,
			torso,
			"HoodieHem",
			Vector3.new(2.02, 0.16, 1.02),
			CFrame.new(0, -0.93, 0),
			darker(base, 0.15),
			FABRIC
		)
		addBlock(
			model,
			torso,
			"Print",
			Vector3.new(0.56, 0.2, 0.008),
			CFrame.new(0, 0.04, -0.504),
			base:Lerp(Color3.fromRGB(150, 146, 136), 0.35),
			FABRIC
		)
		addBlock(
			model,
			torso,
			"PrintLine",
			Vector3.new(0.4, 0.04, 0.008),
			CFrame.new(0, -0.12, -0.504),
			base:Lerp(Color3.fromRGB(150, 146, 136), 0.25),
			FABRIC
		)
		addChain(model, torso, -0.5, 0.98, 0.66)
		for _, side in { -1, 1 } do
			addStrip(
				model,
				torso,
				if side < 0 then "DrawstringL" else "DrawstringR",
				Vector3.new(side * 0.16, 0.98, -0.53),
				Vector3.new(side * 0.2, 0.42, -0.53),
				0.05,
				0.03,
				Color3.fromRGB(150, 146, 138),
				FABRIC
			)
			addBlock(
				model,
				torso,
				"Aglet",
				Vector3.new(0.055, 0.09, 0.035),
				CFrame.new(side * 0.2, 0.38, -0.5325),
				steel,
				METAL
			)
		end
		if not hoodUp then
			-- the hood, down, lying on the upper back and over the top of the shoulders
			addBlock(
				model,
				torso,
				"HoodDown",
				Vector3.new(1.24, 0.5, 0.2),
				CFrame.new(0, 0.74, 0.6),
				darker(base, 0.1),
				FABRIC
			)
			addBlock(
				model,
				torso,
				"HoodDownTop",
				Vector3.new(1.24, 0.14, 0.5),
				CFrame.new(0, 1.06, 0.46),
				darker(base, 0.1),
				FABRIC
			)
		end
	end

	-- The cross-body sling bag: its strap from the right shoulder, over everything on the
	-- chest, down to the bag on the left hip; it goes over the shoulder and down the back.
	local bagColor = if look.detail < 0.5
		then Color3.fromRGB(30, 32, 30)
		else Color3.fromRGB(52, 50, 44)
	local strapColor = darker(bagColor, 0.2)
	addStrip(
		model,
		torso,
		"SlingStrap",
		Vector3.new(0.62, 1.0, -0.54),
		Vector3.new(-0.62, -0.4, -0.54),
		0.13,
		0.08,
		strapColor,
		FABRIC
	)
	addStrip(
		model,
		torso,
		"SlingStrapBack",
		Vector3.new(0.62, 1.0, 0.54),
		Vector3.new(-0.7, -0.38, 0.54),
		0.13,
		0.08,
		strapColor,
		FABRIC
	)
	addBlock(
		model,
		torso,
		"SlingStrapTop",
		Vector3.new(0.14, 0.06, 1.16),
		CFrame.new(0.62, 1.02, 0),
		strapColor,
		FABRIC
	)
	addBlock(
		model,
		torso,
		"SlingBuckle",
		Vector3.new(0.17, 0.12, 0.03),
		CFrame.new(0.17, 0.5, -0.59) * CFrame.Angles(0, 0, math.atan2(1.24, -1.4)),
		INK,
		Enum.Material.Plastic
	)
	addBlock(
		model,
		torso,
		"SlingBag",
		Vector3.new(0.8, 0.56, 0.26),
		CFrame.new(-0.56, -0.66, -0.63),
		bagColor,
		FABRIC
	)
	addBlock(
		model,
		torso,
		"SlingFlap",
		Vector3.new(0.82, 0.32, 0.03),
		CFrame.new(-0.56, -0.53, -0.7725),
		darker(bagColor, 0.12),
		FABRIC
	)
	addBlock(
		model,
		torso,
		"SlingClip",
		Vector3.new(0.14, 0.1, 0.03),
		CFrame.new(-0.56, -0.66, -0.7975),
		INK,
		Enum.Material.Plastic
	)
	addBlock(
		model,
		torso,
		"SlingZip",
		Vector3.new(0.7, 0.025, 0.02),
		CFrame.new(-0.56, -0.9, -0.77),
		steel,
		METAL
	)

	-- Arms: a seam round the top of the sleeve, the cuff (leather: a zip on its outer side;
	-- hoodie: a ribbed band), a rubbed elbow, then the bare hand: gold rings, a gold watch on
	-- the left wrist.
	for _, side in { -1, 1 } do
		local arm = bodyPart(model, if side < 0 then "Left Arm" else "Right Arm")
		if arm == nil then
			continue
		end
		addBlock(
			model,
			arm,
			"ShoulderSeam",
			Vector3.new(1.02, 0.035, 1.02),
			CFrame.new(0, 0.78, 0),
			seamColor,
			cloth
		)
		addBlock(
			model,
			arm,
			"Cuff",
			Vector3.new(1.04, if leather then 0.14 else 0.2, 1.04),
			CFrame.new(0, -0.5, 0),
			darker(base, 0.12),
			cloth
		)
		if leather then
			addBlock(
				model,
				arm,
				"CuffZip",
				Vector3.new(0.014, 0.32, 0.03),
				CFrame.new(side * 0.522, -0.38, 0.1),
				steel,
				METAL
			)
		else
			for rib = -2, 2 do
				addBlock(
					model,
					arm,
					"CuffRib",
					Vector3.new(0.025, 0.2, 0.01),
					CFrame.new(rib * 0.18, -0.5, -0.522),
					darker(base, 0.25),
					FABRIC
				)
			end
		end
		addBlock(
			model,
			arm,
			"ElbowWear",
			Vector3.new(0.56, 0.4, 0.012),
			CFrame.new(0, -0.05, 0.506),
			worn,
			cloth
		)
		-- creases bunched in the sleeve above the cuff
		for index, y in { -0.12, -0.24 } do
			addBlock(
				model,
				arm,
				"Crease",
				Vector3.new(1.025, 0.035, 1.025),
				CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(if index == 1 then 5 else -4)),
				darker(base, 0.3),
				cloth
			)
		end
		addHand(model, arm, look.skin)
		addKnuckles(model, arm, look.skin)
		for _, x in { -0.2, 0.02, 0.22 } do
			addBlock(
				model,
				arm,
				"FingerGap",
				Vector3.new(0.015, 0.2, 0.01),
				CFrame.new(x, -0.9, -0.515),
				darker(look.skin, 0.45)
			)
		end
		-- rings across the front of the fingers (their backs sunk 0.005 in the hand)
		local rings: { number } = if side > 0
			then { -0.14, 0.12 }
			else if look.detail > 0.3 then { 0.16 } else {}
		for _, x in rings do
			addBlock(
				model,
				arm,
				"Ring",
				Vector3.new(0.13, 0.06, 0.02),
				CFrame.new(x, -0.88, -0.515),
				GOLD,
				METAL
			)
		end
		if side > 0 then
			-- a signet ring: a flat gold top
			addBlock(
				model,
				arm,
				"Signet",
				Vector3.new(0.12, 0.1, 0.025),
				CFrame.new(-0.14, -0.88, -0.5275),
				darker(GOLD, 0.15),
				METAL
			)
			-- a loose gold curb bracelet, slipped down on the wrist
			addBlock(
				model,
				arm,
				"Bracelet",
				Vector3.new(1.035, 0.08, 1.035),
				CFrame.new(0, -0.62, 0) * CFrame.Angles(math.rad(5), 0, math.rad(-7)),
				GOLD,
				METAL
			)
		else
			-- the gold watch: the bracelet round the wrist, the case and its dark dial on the
			-- back of the wrist (the outer side)
			addBlock(
				model,
				arm,
				"WatchBand",
				Vector3.new(1.03, 0.12, 1.03),
				CFrame.new(0, -0.6, 0),
				GOLD,
				METAL
			)
			addBlock(
				model,
				arm,
				"WatchCase",
				Vector3.new(0.05, 0.28, 0.3),
				CFrame.new(-0.535, -0.6, 0),
				GOLD,
				METAL
			)
			addBlock(
				model,
				arm,
				"WatchDial",
				Vector3.new(0.02, 0.2, 0.22),
				CFrame.new(-0.565, -0.6, 0),
				Color3.fromRGB(16, 18, 22),
				Enum.Material.Glass
			)
		end
	end

	-- Dark jeans: the outer seams, the front pocket openings (a phone in the left one), the
	-- washed-out thighs and knees, the hems stacked on the boots; black boots.
	local denimSeam = look.trousers:Lerp(Color3.fromRGB(150, 130, 96), 0.35)
	local fade = look.trousers:Lerp(Color3.fromRGB(110, 118, 132), 0.12)
	local fadeMore = look.trousers:Lerp(Color3.fromRGB(110, 118, 132), 0.2)
	for _, side in { -1, 1 } do
		local leg = bodyPart(model, if side < 0 then "Left Leg" else "Right Leg")
		if leg == nil then
			continue
		end
		addBlock(
			model,
			leg,
			"OuterSeam",
			Vector3.new(0.012, 1.3, 0.04),
			CFrame.new(side * 0.505, 0.35, 0),
			denimSeam,
			FABRIC
		)
		addStrip(
			model,
			leg,
			"JeansPocket",
			Vector3.new(side * 0.1, 0.98, -0.51),
			Vector3.new(side * 0.47, 0.6, -0.51),
			0.04,
			0.02,
			darker(look.trousers, 0.35),
			FABRIC
		)
		addBlock(
			model,
			leg,
			"ThighFade",
			Vector3.new(0.7, 0.62, 0.008),
			CFrame.new(side * 0.04, 0.36, -0.504) * CFrame.Angles(0, 0, math.rad(side * 5)),
			fade,
			FABRIC
		)
		addBlock(
			model,
			leg,
			"KneeFade",
			Vector3.new(0.44, 0.3, 0.01),
			CFrame.new(-side * 0.04, -0.06, -0.505) * CFrame.Angles(0, 0, math.rad(-side * 8)),
			fadeMore,
			FABRIC
		)
		legBand(model, leg, side, "JeansHem", -0.28, 0.12, darker(look.trousers, 0.1), FABRIC, 0.03)
		if side < 0 then
			-- the phone's top out of the pocket (its back to us, the camera at the corner)
			local phone = CFrame.new(-0.25, 0.8, -0.515) * CFrame.Angles(0, 0, math.rad(-24))
			addBlock(
				model,
				leg,
				"PocketPhone",
				Vector3.new(0.3, 0.32, 0.03),
				phone,
				Color3.fromRGB(26, 26, 30),
				Enum.Material.Glass
			)
			addBlock(
				model,
				leg,
				"PhoneCamera",
				Vector3.new(0.08, 0.08, 0.012),
				phone * CFrame.new(0.07, 0.08, -0.021),
				Color3.fromRGB(70, 72, 80),
				METAL
			)
		end
	end
	addBoots(model, Color3.fromRGB(24, 22, 21), Color3.fromRGB(30, 28, 27), INK, false)

	addCigarette(model, head)

	-- At his feet, by the left boot: a black duffel bag, half unzipped (a white box shows:
	-- what fell off the truck), its handles flopped on top, the shoulder strap on the floor.
	local root = bodyPart(model, "HumanoidRootPart")
	if root then
		local floor = root.CFrame
			* CFrame.new(-2.05, -ROOT_HEIGHT, -0.2)
			* CFrame.Angles(0, math.rad(14), 0)
		local nylon = Color3.fromRGB(30, 32, 30)
		local function prop(
			name: string,
			size: Vector3,
			offset: CFrame,
			color: Color3,
			material: Enum.Material?,
			shape: Enum.PartType?
		)
			floorProp(model, name, size, floor * offset, color, material or FABRIC, shape)
		end
		-- (a Cylinder's axis is its X: the bag lies along X)
		prop(
			"Duffel",
			Vector3.new(1.7, 0.8, 0.8),
			CFrame.new(0, 0.38, 0),
			nylon,
			nil,
			Enum.PartType.Cylinder
		)
		prop(
			"DuffelBottom",
			Vector3.new(1.62, 0.22, 0.66),
			CFrame.new(0, 0.11, 0),
			darker(nylon, 0.1)
		)
		for _, side in { -1, 1 } do
			prop(
				"DuffelEnd",
				Vector3.new(0.06, 0.84, 0.84),
				CFrame.new(side * 0.83, 0.38, 0),
				darker(nylon, 0.2),
				nil,
				Enum.PartType.Cylinder
			)
			prop(
				"DuffelHandle",
				Vector3.new(0.12, 0.05, 0.4),
				CFrame.new(side * 0.28, 0.79, 0.02),
				INK
			)
		end
		prop(
			"DuffelGrip",
			Vector3.new(0.66, 0.09, 0.16),
			CFrame.new(0, 0.82, 0.05) * CFrame.Angles(0, math.rad(8), 0),
			INK
		)
		prop(
			"DuffelZip",
			Vector3.new(1.0, 0.03, 0.045),
			CFrame.new(-0.3, 0.785, -0.1),
			steel,
			METAL
		)
		prop(
			"DuffelGap",
			Vector3.new(0.5, 0.02, 0.12),
			CFrame.new(0.48, 0.782, -0.1),
			Color3.fromRGB(8, 8, 8)
		)
		prop(
			"Shoebox",
			Vector3.new(0.34, 0.16, 0.26),
			CFrame.new(0.48, 0.77, -0.08) * CFrame.Angles(math.rad(-8), math.rad(10), math.rad(6)),
			Color3.fromRGB(226, 222, 212),
			Enum.Material.SmoothPlastic
		)
		prop(
			"DuffelPocket",
			Vector3.new(0.6, 0.36, 0.08),
			CFrame.new(-0.3, 0.36, -0.4),
			darker(nylon, 0.08)
		)
		prop(
			"PocketZip",
			Vector3.new(0.5, 0.025, 0.02),
			CFrame.new(-0.3, 0.5, -0.445),
			steel,
			METAL
		)
		prop(
			"Strap",
			Vector3.new(0.12, 0.025, 0.7),
			CFrame.new(0.95, 0.0125, -0.55) * CFrame.Angles(0, math.rad(32), 0),
			INK
		)
		prop(
			"Strap",
			Vector3.new(0.12, 0.025, 0.55),
			CFrame.new(1.22, 0.0125, -1.05) * CFrame.Angles(0, math.rad(-12), 0),
			INK
		)
		prop("StrapClip", Vector3.new(0.16, 0.04, 0.1), CFrame.new(1.28, 0.02, -1.32), steel, METAL)
	end
end

-- The vagrant (role "Vagrant", look from makeLook). He always sits on the floor against a
-- wall, legs stretched out under a blanket (the client adds the blanket and his things):
-- what shows is the upper body, the shins, the boots' soles.
local function addVagrantOutfit(model: Model, look: Look)
	local torso = bodyPart(model, "Torso")
	local head = bodyPart(model, "Head")
	if torso == nil or head == nil then
		return
	end
	local coat = look.shirt
	local seamColor = darker(coat, 0.35)
	local grime = Color3.fromRGB(40, 34, 28)
	local stained = coat:Lerp(grime, 0.45)
	local thread = coat:Lerp(Color3.fromRGB(170, 160, 136), 0.35) -- frayed ends, pale
	local patch = Color3.fromRGB(86, 66, 48)
	local half = 0.32

	-- Under the open coat: a hoodie (the top of its pocket, one drawstring left).
	addBlock(
		model,
		torso,
		"Undershirt",
		Vector3.new(half * 2, 1.86, 0.02),
		CFrame.new(0, -0.06, -0.51),
		look.undershirt,
		FABRIC
	)
	addBlock(
		model,
		torso,
		"HoodiePocketTop",
		Vector3.new(half * 2 - 0.04, 0.04, 0.015),
		CFrame.new(0, -0.44, -0.525),
		darker(look.undershirt, 0.3),
		FABRIC
	)
	addStrip(
		model,
		torso,
		"Drawstring",
		Vector3.new(0.12, 0.84, -0.53),
		Vector3.new(0.15, 0.36, -0.53),
		0.045,
		0.02,
		look.undershirt:Lerp(Color3.fromRGB(180, 172, 156), 0.5),
		FABRIC
	)
	addBlock(
		model,
		torso,
		"HoodieStain",
		Vector3.new(0.26, 0.2, 0.01),
		CFrame.new(-0.08, -0.12, -0.524),
		look.undershirt:Lerp(grime, 0.4),
		FABRIC
	)
	-- The coat: front edges, wide notched lapels, the collar turned up behind the neck,
	-- buttons on the left (one is missing: its thread), buttonholes on the right, a seam on
	-- each shoulder, stains.
	for _, side in { -1, 1 } do
		local s = if side < 0 then "L" else "R"
		addBlock(
			model,
			torso,
			"CoatEdge" .. s,
			Vector3.new(0.07, 1.98, 0.04),
			CFrame.new(side * (half + 0.025), 0, -0.52),
			darker(coat, 0.18),
			FABRIC
		)
		addBlock(
			model,
			torso,
			"Lapel" .. s,
			Vector3.new(0.34, 0.66, 0.05),
			CFrame.new(side * 0.52, 0.5, -0.525) * CFrame.Angles(0, 0, math.rad(-side * 13)),
			darker(coat, 0.08),
			FABRIC
		)
		addBlock(
			model,
			torso,
			"Notch" .. s,
			Vector3.new(0.16, 0.12, 0.052),
			CFrame.new(side * 0.71, 0.79, -0.525) * CFrame.Angles(0, 0, math.rad(side * 20)),
			darker(coat, 0.14),
			FABRIC
		)
		addBlock(
			model,
			torso,
			"CollarUp" .. s,
			Vector3.new(0.14, 0.34, 0.86),
			CFrame.new(side * 0.66, 1.04, 0.06),
			darker(coat, 0.12),
			FABRIC
		)
	end
	addBlock(
		model,
		torso,
		"CollarUpBack",
		Vector3.new(1.46, 0.36, 0.12),
		CFrame.new(0, 1.05, 0.48),
		darker(coat, 0.12),
		FABRIC
	)
	for index, y in { 0.08, -0.3 } do
		addBlock(
			model,
			torso,
			"Button",
			Vector3.new(0.13, 0.13, 0.03),
			CFrame.new(-0.52, y, -0.515),
			Color3.fromRGB(46, 36, 28),
			Enum.Material.Wood
		)
		addBlock(
			model,
			torso,
			"Buttonhole",
			Vector3.new(0.12, 0.025, 0.01),
			CFrame.new(0.52, y + (if index == 1 then 0.02 else -0.01), -0.505),
			seamColor,
			FABRIC
		)
	end
	-- the third button is gone: a tuft of thread where it was
	addBlock(
		model,
		torso,
		"LostButton",
		Vector3.new(0.03, 0.07, 0.02),
		CFrame.new(-0.52, -0.66, -0.51) * CFrame.Angles(0, 0, math.rad(12)),
		thread,
		FABRIC
	)
	addBlock(
		model,
		torso,
		"CoatStain",
		Vector3.new(0.34, 0.28, 0.012),
		CFrame.new(-0.74, -0.2, -0.506),
		stained,
		FABRIC
	)
	addBlock(
		model,
		torso,
		"CoatStain2",
		Vector3.new(0.22, 0.3, 0.012),
		CFrame.new(0.72, 0.02, -0.506) * CFrame.Angles(0, 0, math.rad(20)),
		stained,
		FABRIC
	)
	-- The scarf: knitted, two turns round the neck (a darker stripe), a knot at the front, two
	-- ends down the chest, frayed into a fringe.
	local scarf = look.scarf or coat
	-- (a faded mustard stripe knitted in: the scarf reads as a scarf, not another dark layer)
	local stripe = scarf:Lerp(Color3.fromRGB(150, 116, 52), 0.55)
	addBlock(
		model,
		torso,
		"ScarfWrap",
		Vector3.new(1.38, 0.22, 1.14),
		CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(2)),
		scarf,
		FABRIC
	)
	addBlock(
		model,
		torso,
		"ScarfStripe",
		Vector3.new(1.39, 0.05, 1.15),
		CFrame.new(0, 0.88, 0) * CFrame.Angles(0, 0, math.rad(2)),
		stripe,
		FABRIC
	)
	addBlock(
		model,
		torso,
		"ScarfWrap2",
		Vector3.new(1.3, 0.2, 1.08),
		CFrame.new(0, 1.06, -0.02) * CFrame.Angles(0, 0, math.rad(-3)),
		darker(scarf, 0.08),
		FABRIC
	)
	addBlock(
		model,
		torso,
		"ScarfKnot",
		Vector3.new(0.3, 0.24, 0.16),
		CFrame.new(0.2, 0.86, -0.6),
		darker(scarf, 0.04),
		FABRIC
	)
	local ends: { { cf: CFrame, size: Vector3 } } = {
		{
			cf = CFrame.new(0.3, 0.38, -0.575) * CFrame.Angles(0, 0, math.rad(-5)),
			size = Vector3.new(0.3, 0.78, 0.07),
		},
		{
			cf = CFrame.new(0.08, 0.5, -0.645) * CFrame.Angles(0, 0, math.rad(9)),
			size = Vector3.new(0.26, 0.5, 0.07),
		},
	}
	for _, scarfEnd in ends do
		local cf, size = scarfEnd.cf, scarfEnd.size
		addBlock(model, torso, "ScarfEnd", size, cf, scarf, FABRIC)
		addBlock(
			model,
			torso,
			"ScarfEndStripe",
			Vector3.new(size.X + 0.01, 0.05, size.Z + 0.01),
			cf * CFrame.new(0, -size.Y / 2 + 0.14, 0),
			stripe,
			FABRIC
		)
		-- the end worn ragged: two uneven tongues of knit
		for index, x in { -0.07, 0.08 } do
			addBlock(
				model,
				torso,
				"ScarfRag",
				Vector3.new(size.X / 2 - 0.02, 0.06 + index * 0.04, size.Z - 0.01),
				cf * CFrame.new(x * size.X / 0.3, -size.Y / 2 - 0.02 - index * 0.02, 0),
				darker(scarf, 0.12),
				FABRIC
			)
		end
	end

	-- Sleeves: a shoulder seam, a frayed turned-back cuff with loose threads, a leather patch
	-- sewn on the elbow; fingerless knitted gloves (the dirty fingers come out, one hole).
	local gloves = look.gloves or INK
	local skin = look.skin
	for _, side in { -1, 1 } do
		local arm = bodyPart(model, if side < 0 then "Left Arm" else "Right Arm")
		if arm == nil then
			continue
		end
		addBlock(
			model,
			arm,
			"ShoulderSeam",
			Vector3.new(1.02, 0.035, 1.02),
			CFrame.new(0, 0.8, 0),
			seamColor,
			FABRIC
		)
		addBlock(
			model,
			arm,
			"Cuff",
			Vector3.new(1.06, 0.16, 1.06),
			CFrame.new(0, -0.48, 0),
			darker(coat, 0.12),
			FABRIC
		)
		for index, x in { -0.28, 0.06, 0.3 } do
			addBlock(
				model,
				arm,
				"Thread",
				Vector3.new(0.05, 0.08 + index * 0.03, 0.02),
				CFrame.new(x, -0.58 - index * 0.015, -0.54)
					* CFrame.Angles(0, 0, math.rad((index - 2) * 14)),
				thread,
				FABRIC
			)
		end
		addBlock(
			model,
			arm,
			"ElbowPatch",
			Vector3.new(0.64, 0.56, 0.02),
			CFrame.new(0, -0.08, 0.51),
			patch,
			LEATHER
		)
		addBlock(
			model,
			arm,
			"Glove",
			Vector3.new(1.04, 0.3, 1.04),
			CFrame.new(0, -0.67, 0),
			gloves,
			FABRIC
		)
		local fingers = addBlock(
			model,
			arm,
			"Fingers",
			Vector3.new(1.02, 0.2, 1.02),
			CFrame.new(0, -0.91, 0),
			skin:Lerp(grime, 0.25)
		)
		fingers.CastShadow = true
		addKnuckles(model, arm, skin)
		for _, x in { -0.2, 0.02, 0.22 } do
			addBlock(
				model,
				arm,
				"FingerGap",
				Vector3.new(0.015, 0.17, 0.01),
				CFrame.new(x, -0.92, -0.515),
				darker(skin, 0.5)
			)
		end
		-- ribs knitted in the glove, a hole on the knuckles (skin shows)
		for _, x in { -0.3, -0.1, 0.1, 0.3 } do
			addBlock(
				model,
				arm,
				"GloveRib",
				Vector3.new(0.025, 0.28, 0.01),
				CFrame.new(x, -0.67, -0.525),
				darker(gloves, 0.25),
				FABRIC
			)
		end
		if side > 0 then
			addBlock(
				model,
				arm,
				"GloveHole",
				Vector3.new(0.13, 0.1, 0.012),
				CFrame.new(0.2, -0.74, -0.526),
				skin
			)
		end
	end

	-- The trousers: worn through at one knee (the long johns show, the edges frayed), a
	-- patch sewn on the other (big cross stitches), frayed hems on the boots. Old brown work boots, worn out (see addBoots).
	local torn = if look.detail < 0.5 then -1 else 1
	for _, side in { -1, 1 } do
		local leg = bodyPart(model, if side < 0 then "Left Leg" else "Right Leg")
		if leg == nil then
			continue
		end
		if side == torn then
			addBlock(
				model,
				leg,
				"KneeHole",
				Vector3.new(0.42, 0.26, 0.012),
				CFrame.new(0.04, -0.1, -0.506),
				Color3.fromRGB(104, 44, 38),
				FABRIC
			)
			for index, offset in
				{
					Vector3.new(-0.2, 0.12, 0),
					Vector3.new(0.1, 0.13, 0),
					Vector3.new(0.24, -0.06, 0),
					Vector3.new(-0.12, -0.13, 0),
				}
			do
				addBlock(
					model,
					leg,
					"Frayed",
					Vector3.new(
						if index % 2 == 0 then 0.03 else 0.1,
						if index % 2 == 0 then 0.1 else 0.03,
						0.01
					),
					CFrame.new(0.04 + offset.X, -0.1 + offset.Y, -0.508),
					look.trousers:Lerp(Color3.fromRGB(176, 166, 144), 0.45),
					FABRIC
				)
			end
		else
			addBlock(
				model,
				leg,
				"KneePatch",
				Vector3.new(0.56, 0.46, 0.015),
				CFrame.new(-side * 0.02, -0.04, -0.5075) * CFrame.Angles(0, 0, math.rad(side * 4)),
				patch:Lerp(Color3.fromRGB(70, 74, 64), 0.5),
				FABRIC
			)
			for _, corner in
				{
					Vector3.new(-0.2, 0.15, 0),
					Vector3.new(0.2, 0.17, 0),
					Vector3.new(-0.18, -0.23, 0),
					Vector3.new(0.21, -0.22, 0),
				}
			do
				for _, angle in { 45, -45 } do
					addBlock(
						model,
						leg,
						"Stitch",
						Vector3.new(0.11, 0.018, 0.01),
						CFrame.new(-side * 0.02 + corner.X, corner.Y, -0.519)
							* CFrame.Angles(0, 0, math.rad(angle)),
						Color3.fromRGB(176, 164, 132),
						FABRIC
					)
				end
			end
		end
		legBand(
			model,
			leg,
			side,
			"FrayedHem",
			-0.27,
			0.14,
			darker(look.trousers, 0.12),
			FABRIC,
			0.035
		)
		for index, x in { -0.25, 0.02, 0.28 } do
			addBlock(
				model,
				leg,
				"HemThread",
				Vector3.new(0.04, 0.08, 0.02),
				CFrame.new(side * 0.0175 + x, -0.37 - (index % 2) * 0.03, -0.54),
				look.trousers:Lerp(Color3.fromRGB(150, 140, 120), 0.3),
				FABRIC
			)
		end
		-- the coat's tails over the thighs (split in the middle, 0.02 wider than the leg
		-- outside; under the blanket when he sits)
		addBlock(
			model,
			leg,
			if side < 0 then "CoatTailL" else "CoatTailR",
			Vector3.new(1.02, 0.9, 1.04),
			CFrame.new(side * 0.02, 0.56, 0),
			coat,
			FABRIC
		)
	end
	addBoots(
		model,
		Color3.fromRGB(72, 52, 36),
		Color3.fromRGB(38, 34, 30),
		Color3.fromRGB(58, 40, 28),
		true
	)

	-- The head: ribs knitted in the beanie's fold, the beard gone wild (tufts under the chin).
	if look.headwear == "Beanie" then
		for rib = -4, 4 do
			addBlock(
				model,
				head,
				"BeanieRib",
				Vector3.new(0.035, 0.2, 0.02),
				CFrame.new(rib * 0.15, 0.36, -0.715),
				darker(look.headwearColor, 0.3),
				FABRIC
			)
		end
	end
	if look.beard then
		addBlock(
			model,
			head,
			"BeardTuft",
			Vector3.new(0.26, 0.18, 0.14),
			CFrame.new(0.1, -0.64, -0.5) * CFrame.Angles(0, 0, math.rad(8)),
			look.beard,
			FABRIC
		)
		addBlock(
			model,
			head,
			"BeardTuft2",
			Vector3.new(0.2, 0.14, 0.12),
			CFrame.new(-0.16, -0.62, -0.48) * CFrame.Angles(0, 0, math.rad(-10)),
			darker(look.beard, 0.15),
			FABRIC
		)
	end
end

local function addAccessories(model: Model, role: string, look: Look, shopColor: Color3?)
	local head = model:FindFirstChild("Head") :: BasePart?
	local torso = model:FindFirstChild("Torso") :: BasePart?
	local leftArm = model:FindFirstChild("Left Arm") :: BasePart?
	if head == nil or torso == nil then
		return
	end
	-- Head (hair under any hat — none shows under a hood —, the hat, glasses, earrings).
	if look.headwear ~= "Hood" then
		addHair(model, head, look, look.headwear ~= nil and look.headwear ~= "Headphones")
	end
	addHeadwear(model, head, look, if role == "Clerk" then shopColor else nil)
	if look.glasses then
		addGlasses(model, head, look.glasses)
	end
	if look.earrings and look.headwear ~= "Headphones" then
		for _, side in { -1, 1 } do
			addBlock(
				model,
				head,
				if side < 0 then "EarringL" else "EarringR",
				Vector3.new(0.06, 0.1, 0.06),
				CFrame.new(side * 0.64, -0.12, 0.02),
				GOLD,
				Enum.Material.Metal
			)
		end
	end

	if look.beard then
		-- A rough beard: a block on the chin, the jaw on both sides, a moustache over the
		-- mouth. (The head is round: the jaw blocks stand a little proud at the front, which
		-- reads as the volume of a beard.)
		local beard = look.beard
		local fabric = Enum.Material.Fabric
		addBlock(
			model,
			head,
			"BeardChin",
			Vector3.new(0.78, 0.36, 0.22),
			CFrame.new(0, -0.44, -0.52),
			beard,
			fabric
		)
		for _, side in { -1, 1 } do
			addBlock(
				model,
				head,
				if side < 0 then "BeardJawL" else "BeardJawR",
				Vector3.new(0.16, 0.5, 0.62),
				CFrame.new(side * 0.53, -0.3, -0.12),
				darker(beard, 0.12),
				fabric
			)
		end
		addBlock(
			model,
			head,
			"Moustache",
			Vector3.new(0.5, 0.09, 0.08),
			CFrame.new(0, -0.2, -0.635),
			beard,
			fabric
		)
	end
	if look.scar then
		-- an old scar across the right cheek, down from the eyebrow (its back sunk in the face)
		addBlock(
			model,
			head,
			"Scar",
			Vector3.new(0.04, 0.34, 0.03),
			CFrame.new(0.26, 0.04, -0.567) * CFrame.Angles(0, 0, math.rad(16)),
			look.skin:Lerp(Color3.fromRGB(122, 58, 56), 0.55)
		)
	end

	-- Torso: the torso is 2 wide, 2 tall, 1 deep: its front is 0.5 in front (-Z), its top 1.0
	-- above its centre. Rule for everything worn on it: flat things lie WITH THEIR BACK ON THE
	-- CLOTH (back face exactly at -0.5 / +0.5 / y 1.0), never a hair in front of it (it would
	-- look stuck in the air), and two parts never have a visible face in the same plane
	-- (flicker): a part laid over another is 0.005-0.01 prouder or wider.
	-- (The head sits ON the torso: its round mesh goes down to 0.875 above the torso's centre,
	-- so anything going "around the neck" disappears under it a little behind the front.)
	if look.apron then
		local apron = look.apron
		local strap = darker(apron, 0.3)
		-- the bib (chest), the skirt (waist to knees, over the top of the legs), a band around
		-- the waist (just wider than the torso: the ties; at the front it is under the apron)
		addBlock(
			model,
			torso,
			"ApronBib",
			Vector3.new(1.1, 0.95, 0.08),
			CFrame.new(0, 0.42, -0.54),
			apron,
			Enum.Material.Fabric
		)
		addBlock(
			model,
			torso,
			"ApronSkirt",
			Vector3.new(1.86, 1.35, 0.09), -- (0.01 prouder than the bib where they overlap)
			CFrame.new(0, -0.62, -0.545),
			apron,
			Enum.Material.Fabric
		)
		addBlock(
			model,
			torso,
			"ApronWaist",
			Vector3.new(2.02, 0.14, 1.02),
			CFrame.new(0, -0.08, 0),
			strap,
			Enum.Material.Fabric
		)
		-- the neck strap: from the bib's top corners up to the sides of the neck, then over
		-- the top of the torso, going back round the neck (under the head)
		for _, side in { -1, 1 } do
			addStrip(
				model,
				torso,
				if side < 0 then "ApronStrapL" else "ApronStrapR",
				-- (0.09 deep: its front 0.01 prouder than the bib's where it starts on it)
				Vector3.new(side * 0.47, 0.86, -0.545),
				Vector3.new(side * 0.32, 1.0, -0.545),
				0.1,
				0.09,
				strap,
				Enum.Material.Fabric
			)
			addBlock(
				model,
				torso,
				if side < 0 then "ApronNeckL" else "ApronNeckR",
				Vector3.new(0.1, 0.06, 0.595),
				CFrame.new(side * 0.32, 1.03, -0.2775),
				strap,
				Enum.Material.Fabric
			)
		end
		-- the front pocket (its back sunk 0.005 in the skirt), a pen and a bottle opener in it:
		-- their fronts are behind the pocket's front, only their tops stick out
		addBlock(
			model,
			torso,
			"ApronPocket",
			Vector3.new(0.8, 0.34, 0.04),
			CFrame.new(0, -0.5, -0.605),
			darker(apron, 0.12),
			Enum.Material.Fabric
		)
		addBlock(
			model,
			torso,
			"Pen",
			Vector3.new(0.04, 0.22, 0.04),
			CFrame.new(0.24, -0.3, -0.6),
			Color3.fromRGB(230, 228, 220)
		)
		addBlock(
			model,
			torso,
			"Opener",
			Vector3.new(0.1, 0.24, 0.03),
			CFrame.new(-0.22, -0.31, -0.6),
			STEEL,
			Enum.Material.Metal
		)
	end
	if look.towel then
		-- a bar towel folded over the left shoulder, hanging front and back, lying on the
		-- shirt next to the apron's bib (the bib ends 0.55 out, the towel starts 0.56 out)
		local towel = Color3.fromRGB(222, 216, 198)
		local towelX = -0.77
		addBlock(
			model,
			torso,
			"TowelTop",
			Vector3.new(0.42, 0.08, 1.12),
			CFrame.new(towelX, 1.04, 0),
			towel,
			Enum.Material.Fabric
		)
		addBlock(
			model,
			torso,
			"TowelFront",
			Vector3.new(0.42, 0.52, 0.06),
			CFrame.new(towelX, 0.74, -0.53),
			towel,
			Enum.Material.Fabric
		)
		addBlock(
			model,
			torso,
			"TowelBack",
			Vector3.new(0.42, 0.74, 0.06),
			CFrame.new(towelX, 0.63, 0.53),
			towel,
			Enum.Material.Fabric
		)
		addBlock(
			model,
			torso,
			"TowelStripe",
			Vector3.new(0.44, 0.06, 0.07),
			CFrame.new(towelX, 0.6, -0.535),
			Color3.fromRGB(150, 46, 40),
			Enum.Material.Fabric
		)
	end
	-- the top of what the lanyard goes over: the polo's collar (clerks of a shop) or the torso
	local neckTop = 1.0
	if role == "Clerk" and shopColor then
		-- the polo: the shop's colour on the collar (a band around the top of the torso),
		-- and its button placket (it stops at the collar, 0.005 prouder than it)
		addBlock(
			model,
			torso,
			"Collar",
			Vector3.new(1.4, 0.2, 1.06),
			CFrame.new(0, 0.92, 0),
			shopColor
		)
		neckTop = 1.02
		addBlock(
			model,
			torso,
			"Placket",
			Vector3.new(0.16, 0.39, 0.035),
			CFrame.new(0, 0.645, -0.5175),
			darker(shopColor, 0.2)
		)
	end
	if look.lanyard then
		-- A badge on a lanyard. The strap goes round the neck (two short bits on top of the
		-- collar, going back under the head), comes down the chest in a V (wide at the neck,
		-- meeting at the clip), and the clip holds the card, which lies flat on the chest.
		-- (Before, the V was upside down, its ends did not reach the clip, and the card hung
		-- 0.015 in front of the shirt: it looked like it floated.)
		local strapColor = shopColor or INK
		local clipY = 0.36
		for _, side in { -1, 1 } do
			addStrip(
				model,
				torso,
				if side < 0 then "LanyardL" else "LanyardR",
				Vector3.new(side * 0.3, neckTop, -0.52),
				Vector3.new(side * 0.035, clipY + 0.02, -0.52),
				0.06,
				0.04,
				strapColor
			)
			addBlock(
				model,
				torso,
				if side < 0 then "LanyardNeckL" else "LanyardNeckR",
				Vector3.new(0.06, 0.04, 0.29),
				CFrame.new(side * 0.3, neckTop + 0.015, -0.395),
				strapColor
			)
		end
		addBlock(
			model,
			torso,
			"BadgeClip",
			Vector3.new(0.12, 0.1, 0.05),
			CFrame.new(0, clipY, -0.525),
			STEEL,
			Enum.Material.Metal
		)
		-- the card: its top tucked 0.01 into the clip, its back on the shirt
		local cardTop = clipY - 0.04
		addBlock(
			model,
			torso,
			"Badge",
			Vector3.new(0.38, 0.5, 0.03),
			CFrame.new(0, cardTop - 0.25, -0.515),
			Color3.fromRGB(240, 238, 230)
		)
		-- printed on it: the shop's stripe, a photo, two lines of name (0.005 proud)
		addBlock(
			model,
			torso,
			"BadgeStripe",
			Vector3.new(0.39, 0.1, 0.035),
			CFrame.new(0, cardTop - 0.08, -0.5175),
			strapColor
		)
		addBlock(
			model,
			torso,
			"BadgePhoto",
			Vector3.new(0.14, 0.16, 0.035),
			CFrame.new(-0.09, cardTop - 0.29, -0.5175),
			Color3.fromRGB(120, 124, 132)
		)
		for line = 0, 1 do
			addBlock(
				model,
				torso,
				"BadgeName",
				Vector3.new(0.13 - line * 0.03, 0.03, 0.035),
				CFrame.new(0.08 - line * 0.015, cardTop - 0.25 - line * 0.07, -0.5175),
				Color3.fromRGB(70, 70, 76)
			)
		end
	end
	if look.necklace then
		-- a thin gold chain (two strands from the sides of the neck, meeting low on the
		-- chest, lying on the shirt) and a pendant hanging from a small ring
		for _, side in { -1, 1 } do
			addStrip(
				model,
				torso,
				if side < 0 then "ChainL" else "ChainR",
				Vector3.new(side * 0.26, 1.0, -0.5125),
				Vector3.new(side * 0.012, 0.64, -0.5125),
				0.035,
				0.025,
				GOLD,
				Enum.Material.Metal
			)
		end
		addBlock(
			model,
			torso,
			"PendantRing",
			Vector3.new(0.05, 0.05, 0.03),
			CFrame.new(0, 0.63, -0.515),
			GOLD,
			Enum.Material.Metal
		)
		addBlock(
			model,
			torso,
			"Pendant",
			Vector3.new(0.12, 0.14, 0.04),
			CFrame.new(0, 0.54, -0.52),
			GOLD,
			Enum.Material.Metal
		)
	end
	-- The alley people wear their own clothes, layer by layer (see addDealerOutfit /
	-- addVagrantOutfit).
	if role == "Dealer" then
		addDealerOutfit(model, look)
		return
	elseif role == "Vagrant" then
		addVagrantOutfit(model, look)
		return
	end
	if look.watch and leftArm then
		-- a wristwatch near the left hand (the arm is 1 × 2 × 1: the wrist is 0.65 below)
		addBlock(
			model,
			leftArm,
			"WatchStrap",
			Vector3.new(1.04, 0.18, 1.04),
			CFrame.new(0, -0.62, 0),
			INK
		)
		addBlock(
			model,
			leftArm,
			"WatchFace",
			Vector3.new(0.04, 0.2, 0.26),
			CFrame.new(-0.53, -0.62, 0),
			STEEL,
			Enum.Material.Metal
		)
	end
end

-- The R6 body, coloured. nil if Roblox could not build it.
local function buildBody(name: string, look: Look): Model?
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.TorsoColor = look.shirt
	description.LeftArmColor = look.sleeves
	description.RightArmColor = look.sleeves
	description.LeftLegColor = look.trousers
	description.RightLegColor = look.trousers
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	description:Destroy()
	if not ok or result == nil then
		warn(`[CityNpcs] could not build {name}: {result}`)
		return nil
	end
	local model = result :: Model
	model.Name = name
	-- worn clothes: the torso and sleeves in leather or rough fabric (alley people)
	local cloth = look.cloth
	if cloth then
		for _, partName in { "Torso", "Left Arm", "Right Arm" } do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.Material = cloth
			end
		end
	end
	-- No scripts (no default Animate), no Animator: the client poses the joints itself.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Animator") then
			descendant:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.DisplayName = ""
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanTouch = false
			-- Torso and head block players (you can't walk through Duffy), the rest doesn't
			-- collide (limbs posed by the client must never shove anyone).
			local solid = descendant.Name == "Torso" or descendant.Name == "Head"
			descendant.CanCollide = solid
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
		end
	end
	return model
end

-- The shop an NPC works in ("Outfit" / "Emote": the ShopCategory of the closest
-- ShopCounter, at most 30 studs away), or nil.
local function shopNear(city: Instance, position: Vector3): string?
	local best: string? = nil
	local bestDistance = 30
	for _, descendant in city:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "ShopCounter" then
			local distance = (descendant.Position - position).Magnitude
			local category = descendant:GetAttribute("ShopCategory")
			if distance < bestDistance and typeof(category) == "string" then
				best = category
				bestDistance = distance
			end
		end
	end
	return best
end

-- The colour of a shop (a clerk's collar).
local SHOP_COLORS: { [string]: Color3 } = {
	Outfit = Color3.fromRGB(70, 120, 110), -- THREADBARE teal
	Emote = Color3.fromRGB(196, 58, 70), -- REWIND red
}

local function spawnNpc(spot: BasePart, folder: Instance, city: Instance, index: number)
	local role = spot:GetAttribute("NpcRole")
	local name = spot:GetAttribute("NpcName")
	local pose = spot:GetAttribute("NpcPose")
	local seed = spot:GetAttribute("NpcSeed")
	local seatHeight = spot:GetAttribute("SeatHeight")
	local roleText = if typeof(role) == "string" then role else "Patron"
	local nameText = if typeof(name) == "string" then name else `Npc{index}`
	local poseText = if typeof(pose) == "string" then pose else "Idle"
	local seedNumber = if typeof(seed) == "number" then seed else index * 7919

	local look = makeLook(roleText, seedNumber)
	local model = buildBody(nameText, look)
	if model == nil then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		model:Destroy()
		return
	end
	model.PrimaryPart = root
	-- Standing on the spot, facing its LookVector (flat).
	local floor = spot.Position
	local look3 = spot.CFrame.LookVector
	local facing = Vector3.new(look3.X, 0, look3.Z)
	if facing.Magnitude < 1e-3 then
		facing = Vector3.new(0, 0, -1)
	end
	local rootPosition = floor + Vector3.new(0, ROOT_HEIGHT, 0)
	model:PivotTo(CFrame.lookAt(rootPosition, rootPosition + facing.Unit))

	local shop = if roleText == "Clerk" then shopNear(city, floor) else nil
	addAccessories(model, roleText, look, if shop then SHOP_COLORS[shop] else nil)
	-- A seated NPC is drawn lower by the client; its standing torso and head
	-- (where the server keeps them) must not stop bodies in the air above him.
	if poseText == "SitGround" or poseText == "SitStool" then
		for _, partName in { "Torso", "Head" } do
			local part = model:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end

	-- What the client needs to pose it.
	model:SetAttribute("Npc", true)
	model:SetAttribute("NpcRole", roleText)
	model:SetAttribute("NpcName", nameText)
	model:SetAttribute("NpcPose", poseText)
	model:SetAttribute("NpcSeed", seedNumber)
	model:SetAttribute("FloorY", floor.Y)
	model:SetAttribute("NpcShop", shop) -- (clerks: what they say to you)
	if typeof(seatHeight) == "number" then
		model:SetAttribute("SeatHeight", seatHeight)
	end
	-- optional: how far behind the spot the seat's centre is (default: 1 stud)
	local seatBack = spot:GetAttribute("SeatBack")
	if typeof(seatBack) == "number" then
		model:SetAttribute("SeatBack", seatBack)
	end
	model.Parent = folder
end

local function waitForCity(): Instance?
	local city = workspace:WaitForChild("City", 60)
	if city == nil then
		return nil
	end
	while city:GetAttribute("Built") ~= true do
		city:GetAttributeChangedSignal("Built"):Wait()
	end
	return city
end

function CityNpcs.start()
	local city = waitForCity()
	if city == nil then
		return -- no city (a test place): no NPCs
	end
	local spots: { BasePart } = {}
	for _, descendant in city:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == SPOT_NAME then
			table.insert(spots, descendant)
		end
	end
	if #spots == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = city
	for index, spot in spots do
		spawnNpc(spot, folder, city, index)
	end
end

return CityNpcs
