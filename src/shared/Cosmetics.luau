--!strict
-- Cosmetics sold in the SHOP (step 10). Coins only, no fight advantage.
-- Shared: the server checks the purchases, the menu shows the catalog.
--
--   Title       a title under your name (name tags, scoreboard)
--   Outfit      the colour of your top and trousers (realistic, no skins)
--   KillEffect  a short effect when you finish someone
--   Emote       a gesture you play with the emote key (B)
--
-- One of each category can be equipped. `unlockLevel` (optional) must be
-- reached before buying. To add an item: add a line below, nothing else.

export type Category = "Title" | "Outfit" | "KillEffect" | "Emote"

export type Item = {
	id: string,
	category: Category,
	name: string, -- shown in the shop (English)
	description: string,
	price: number, -- coins (0 = free)
	unlockLevel: number?,
	-- Per category:
	title: string?, -- Title: the text shown
	top: Color3?, -- Outfit
	trousers: Color3?, -- Outfit
	effect: string?, -- KillEffect: "Dust" | "Glass" | "Blood" | "Impact"
	animation: string?, -- Emote: clip in Client/Animation/CombatClips
}

local ITEMS: { Item } = {
	-- Titles
	{
		id = "TitleRookie",
		category = "Title",
		name = "ROOKIE",
		description = "Everybody starts somewhere.",
		price = 0,
		title = "ROOKIE",
	},
	{
		id = "TitleBareKnuckle",
		category = "Title",
		name = "BARE KNUCKLE",
		description = "No gloves, no rules.",
		price = 150,
		title = "BARE KNUCKLE",
	},
	{
		id = "TitleBackAlley",
		category = "Title",
		name = "BACK ALLEY",
		description = "Grew up fighting behind the bar.",
		price = 250,
		title = "BACK ALLEY",
	},
	{
		id = "TitleHeavyHands",
		category = "Title",
		name = "HEAVY HANDS",
		description = "One clean shot is enough.",
		price = 400,
		unlockLevel = 10,
		title = "HEAVY HANDS",
	},
	{
		id = "TitleStreetKing",
		category = "Title",
		name = "STREET KING",
		description = "The block knows your name.",
		price = 1000,
		unlockLevel = 25,
		title = "STREET KING",
	},
	-- Outfits
	{
		id = "OutfitGrey",
		category = "Outfit",
		name = "GREY SWEATS",
		description = "Grey top, grey trousers.",
		price = 100,
		top = Color3.fromRGB(120, 120, 124),
		trousers = Color3.fromRGB(96, 96, 100),
	},
	{
		id = "OutfitBlack",
		category = "Outfit",
		name = "ALL BLACK",
		description = "Black top, black trousers.",
		price = 200,
		top = Color3.fromRGB(30, 30, 32),
		trousers = Color3.fromRGB(24, 24, 26),
	},
	{
		id = "OutfitWhite",
		category = "Outfit",
		name = "WHITE TEE",
		description = "White tee, dark jeans.",
		price = 200,
		top = Color3.fromRGB(226, 224, 218),
		trousers = Color3.fromRGB(44, 58, 82),
	},
	{
		id = "OutfitOlive",
		category = "Outfit",
		name = "OLIVE",
		description = "Olive top, black trousers.",
		price = 300,
		top = Color3.fromRGB(86, 92, 58),
		trousers = Color3.fromRGB(28, 28, 30),
	},
	{
		id = "OutfitBlood",
		category = "Outfit",
		name = "BLOOD RED",
		description = "Dark red top, black trousers.",
		price = 600,
		unlockLevel = 15,
		top = Color3.fromRGB(110, 26, 22),
		trousers = Color3.fromRGB(26, 26, 28),
	},
	-- Kill effects
	{
		id = "KillDust",
		category = "KillEffect",
		name = "DUST",
		description = "A puff of dust from the floor.",
		price = 200,
		effect = "Dust",
	},
	{
		id = "KillGlass",
		category = "KillEffect",
		name = "BROKEN GLASS",
		description = "Glass bursts on the last blow.",
		price = 400,
		effect = "Glass",
	},
	{
		id = "KillImpact",
		category = "KillEffect",
		name = "HEAVY IMPACT",
		description = "The camera shakes, the colour drains.",
		price = 600,
		unlockLevel = 10,
		effect = "Impact",
	},
	-- Emotes
	{
		id = "EmoteShrug",
		category = "Emote",
		name = "SHRUG",
		description = "Is that all?",
		price = 0,
		animation = "Emote_Shrug",
	},
	{
		id = "EmoteComeHere",
		category = "Emote",
		name = "COME HERE",
		description = "Beckon them in.",
		price = 250,
		animation = "Emote_ComeHere",
	},
	{
		id = "EmoteKnuckles",
		category = "Emote",
		name = "KNUCKLE CRACK",
		description = "Crack the knuckles, roll the neck.",
		price = 350,
		animation = "Emote_KnuckleCrack",
	},
	{
		id = "EmoteFlex",
		category = "Emote",
		name = "CHEST POUND",
		description = "Two pounds on the chest.",
		price = 500,
		unlockLevel = 8,
		animation = "Emote_Flex",
	},
}

local byId: { [string]: Item } = {}
for _, item in ITEMS do
	byId[item.id] = item
end

local Cosmetics = {}

Cosmetics.ITEMS = ITEMS
Cosmetics.CATEGORIES = table.freeze({ "Title", "Outfit", "KillEffect", "Emote" })

function Cosmetics.get(id: string?): Item?
	return if id then byId[id] else nil
end

-- Does this save own `item`? Free items belong to everyone.
function Cosmetics.owns(data: { ownedCosmetics: { [string]: boolean } }, item: Item): boolean
	if item.price == 0 and item.unlockLevel == nil then
		return true
	end
	return data.ownedCosmetics[item.id] == true
end

return table.freeze(Cosmetics)
