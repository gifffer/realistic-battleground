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
				Vector3.new(side * 0.47, 0.86, -0.54),
				Vector3.new(side * 0.32, 1.0, -0.54),
				0.1,
				0.08,
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
