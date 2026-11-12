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
--   attributes NpcRole ("Bartender" | "Clerk" | "Patron"), NpcName ("Duffy"...),
--   NpcPose ("Idle" | "WipeCounter" | "LeanBar" | "SitStool" | "ArmsCrossed" | "Phone"),
--   NpcSeed (a number: picks the colours), SeatHeight (sitting poses: seat top above the floor),
--   SeatBack (optional, sitting poses: how far behind the spot the seat's centre is; 1).
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
local HAIRS = {
	Color3.fromRGB(28, 22, 18),
	Color3.fromRGB(70, 46, 30),
	Color3.fromRGB(120, 86, 50),
	Color3.fromRGB(150, 146, 140), -- grey
}

-- Hair cuts (block hair, built in layers: a top, the back, the sides, maybe a fringe).
type HairStyle = "Short" | "Fringe" | "Side" | "Bun" | "Long" | "Buzz"
-- What some wear on the head (instead of showing all their hair).
type Headwear = "Cap" | "Beanie" | "FlatCap" | "Headphones"

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
				CFrame.new(-0.32, 0.29, -0.63),
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
				Vector3.new(0.46, 0.08, 0.4),
				CFrame.new(0, 0.5, 0.55),
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
		Vector3.new(1.3, backHeight, 0.18),
		CFrame.new(0, 0.58 - backHeight / 2, 0.6),
		shade,
		fabric
	)
	-- the sides (sideburns, or long strands)
	for _, side in { -1, 1 } do
		addBlock(
			model,
			head,
			if side < 0 then "HairLeft" else "HairRight",
			Vector3.new(0.12, if long then 0.9 else 0.42, if long then 1.0 else 0.82),
			CFrame.new(side * 0.63, if long then 0.13 else 0.36, if long then 0.1 else 0.18),
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
			CFrame.new(0, 0.46, 0.68),
			darker(color, 0.3)
		)
		-- the shop's logo patch (clerks) or a small white one
		addBlock(
			model,
			head,
			"CapLogo",
			Vector3.new(0.42, 0.18, 0.04),
			CFrame.new(0, 0.6, -0.68),
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
			CFrame.new(0, 0.75, -0.04),
			darker(color, 0.25)
		)
	elseif kind == "Headphones" then
		-- big headphones: the band over the head, two padded cups on the ears
		addBlock(
			model,
			head,
			"PhonesBand",
			Vector3.new(1.46, 0.1, 0.22),
			CFrame.new(0, 0.74, 0.02),
			color
		)
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
				Vector3.new(0.08, 0.42, 0.12),
				CFrame.new(side * 0.7, 0.5, 0.02),
				STEEL,
				Enum.Material.Metal
			)
		end
	end
end

local function addGlasses(model: Model, head: BasePart, kind: "Clear" | "Dark")
	local frame = INK
	local lensColor = if kind == "Dark"
		then Color3.fromRGB(16, 18, 22)
		else Color3.fromRGB(190, 214, 224)
	for _, side in { -1, 1 } do
		-- the frame around each lens (a dark block), the lens just in front of it
		addBlock(
			model,
			head,
			if side < 0 then "FrameL" else "FrameR",
			Vector3.new(0.44, 0.3, 0.04),
			CFrame.new(side * 0.26, 0.12, -0.645),
			frame
		)
		local lens = addBlock(
			model,
			head,
			if side < 0 then "LensL" else "LensR",
			Vector3.new(0.34, 0.2, 0.03),
			CFrame.new(side * 0.26, 0.12, -0.67),
			lensColor,
			Enum.Material.Glass
		)
		lens.Transparency = if kind == "Dark" then 0.05 else 0.55
		lens.Reflectance = 0.15
		-- the arm going back to the ear
		addBlock(
			model,
			head,
			if side < 0 then "TempleL" else "TempleR",
			Vector3.new(0.04, 0.05, 0.64),
			CFrame.new(side * 0.64, 0.18, -0.33),
			frame
		)
	end
	addBlock(
		model,
		head,
		"Bridge",
		Vector3.new(0.12, 0.05, 0.04),
		CFrame.new(0, 0.17, -0.65),
		frame
	)
end

local function addAccessories(model: Model, role: string, look: Look, shopColor: Color3?)
	local head = model:FindFirstChild("Head") :: BasePart?
	local torso = model:FindFirstChild("Torso") :: BasePart?
	local leftArm = model:FindFirstChild("Left Arm") :: BasePart?
	if head == nil or torso == nil then
		return
	end
	-- Head (hair under any hat, the hat, glasses, earrings).
	addHair(model, head, look, look.headwear ~= nil and look.headwear ~= "Headphones")
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

	-- Torso: the torso is 2 wide, 2 tall, 1 deep: its front is 0.5 in front (-Z).
	if look.apron then
		local apron = look.apron
		local strap = darker(apron, 0.3)
		-- the bib (chest), the skirt (waist to knees), a band around the waist
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
			Vector3.new(1.86, 1.35, 0.08),
			CFrame.new(0, -0.62, -0.55),
			apron,
			Enum.Material.Fabric
		)
		addBlock(
			model,
			torso,
			"ApronWaist",
			Vector3.new(2.04, 0.14, 1.04),
			CFrame.new(0, -0.08, 0),
			strap,
			Enum.Material.Fabric
		)
		-- the neck straps, from the bib's corners over the shoulders
		for _, side in { -1, 1 } do
			addBlock(
				model,
				torso,
				if side < 0 then "ApronStrapL" else "ApronStrapR",
				Vector3.new(0.1, 0.1, 1.04),
				CFrame.new(side * 0.42, 1.02, 0),
				strap,
				Enum.Material.Fabric
			)
		end
		-- the front pocket, a pen and a bottle opener sticking out of it
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
			Vector3.new(0.05, 0.22, 0.05),
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
		-- a bar towel folded over the left shoulder, hanging front and back
		local towel = Color3.fromRGB(222, 216, 198)
		addBlock(
			model,
			torso,
			"TowelTop",
			Vector3.new(0.5, 0.08, 1.14),
			CFrame.new(-0.6, 1.04, 0),
			towel,
			Enum.Material.Fabric
		)
		addBlock(
			model,
			torso,
			"TowelFront",
			Vector3.new(0.5, 0.52, 0.06),
			CFrame.new(-0.6, 0.76, -0.58),
			towel,
			Enum.Material.Fabric
		)
		addBlock(
			model,
			torso,
			"TowelBack",
			Vector3.new(0.5, 0.74, 0.06),
			CFrame.new(-0.6, 0.66, 0.58),
			towel,
			Enum.Material.Fabric
		)
		addBlock(
			model,
			torso,
			"TowelStripe",
			Vector3.new(0.52, 0.06, 0.07),
			CFrame.new(-0.6, 0.6, -0.58),
			Color3.fromRGB(150, 46, 40),
			Enum.Material.Fabric
		)
	end
	if role == "Clerk" and shopColor then
		-- the polo: the shop's colour on the collar, and its button placket
		addBlock(
			model,
			torso,
			"Collar",
			Vector3.new(1.4, 0.2, 1.06),
			CFrame.new(0, 0.92, 0),
			shopColor
		)
		addBlock(
			model,
			torso,
			"Placket",
			Vector3.new(0.16, 0.42, 0.03),
			CFrame.new(0, 0.66, -0.515),
			darker(shopColor, 0.2)
		)
	end
	if look.lanyard then
		-- a badge on a lanyard: two straps making a V from the collar, the card, a clip
		local strapColor = shopColor or INK
		for _, side in { -1, 1 } do
			addBlock(
				model,
				torso,
				if side < 0 then "LanyardL" else "LanyardR",
				Vector3.new(0.06, 0.62, 0.03),
				CFrame.new(side * 0.16, 0.5, -0.52) * CFrame.Angles(0, 0, math.rad(side * 14)),
				strapColor
			)
		end
		addBlock(
			model,
			torso,
			"BadgeClip",
			Vector3.new(0.1, 0.1, 0.04),
			CFrame.new(0, 0.18, -0.53),
			STEEL,
			Enum.Material.Metal
		)
		addBlock(
			model,
			torso,
			"Badge",
			Vector3.new(0.38, 0.5, 0.03),
			CFrame.new(0, -0.1, -0.53),
			Color3.fromRGB(240, 238, 230)
		)
		addBlock(
			model,
			torso,
			"BadgeStripe",
			Vector3.new(0.38, 0.12, 0.035),
			CFrame.new(0, 0.08, -0.535),
			strapColor
		)
		addBlock(
			model,
			torso,
			"BadgePhoto",
			Vector3.new(0.14, 0.16, 0.035),
			CFrame.new(-0.09, -0.12, -0.535),
			Color3.fromRGB(120, 124, 132)
		)
	end
	if look.necklace then
		-- a thin gold chain and a pendant
		addBlock(
			model,
			torso,
			"Chain",
			Vector3.new(0.7, 0.04, 0.03),
			CFrame.new(0, 0.84, -0.515),
			GOLD,
			Enum.Material.Metal
		)
		addBlock(
			model,
			torso,
			"Pendant",
			Vector3.new(0.12, 0.14, 0.04),
			CFrame.new(0, 0.74, -0.52),
			GOLD,
			Enum.Material.Metal
		)
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
