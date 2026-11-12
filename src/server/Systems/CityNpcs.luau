--!strict
-- CityNpcs: the little people of the city — Duffy behind his bar, a few regulars on the
-- stools, the clerks of THREADBARE and REWIND behind their counters.
--
-- They are plain blocky R6 bodies, built by Roblox like a player's (the same rig as the
-- training dummies: Players:CreateHumanoidModelFromDescription), coloured with body colours
-- only (no clothing ids needed), plus a few block accessories (cap, apron, rag, phone...).
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

type Look = {
	skin: Color3,
	shirt: Color3,
	sleeves: Color3, -- arms: the shirt colour (long sleeves) or the skin (T-shirt)
	trousers: Color3,
	hair: Color3?,
	cap: Color3?,
	apron: Color3?,
	beanie: Color3?,
	badge: boolean,
	glasses: boolean,
}

local function pick<T>(list: { T }, random: Random): T
	return list[random:NextInteger(1, #list)]
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
		hair = if random:NextNumber() < 0.75 then pick(HAIRS, random) else nil,
		cap = nil,
		apron = nil,
		beanie = nil,
		badge = false,
		glasses = random:NextNumber() < 0.25,
	}
	if random:NextNumber() < 0.5 then
		look.sleeves = look.shirt -- long sleeves
	end
	if role == "Bartender" then
		-- white shirt, black trousers, long dark apron, a towel on the shoulder (client rag)
		look.shirt = Color3.fromRGB(214, 210, 200)
		look.sleeves = look.shirt
		look.trousers = Color3.fromRGB(30, 30, 32)
		look.apron = Color3.fromRGB(48, 36, 30)
	elseif role == "Clerk" then
		-- the shop's colour (a polo) and a name badge; some wear a cap
		look.badge = true
		if random:NextNumber() < 0.5 then
			look.cap = Color3.fromRGB(28, 28, 30)
		end
	elseif random:NextNumber() < 0.35 then
		look.beanie = pick(SHIRTS, random)
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
	part.CastShadow = true
	part.CFrame = body.CFrame * offset
	-- A Weld (not a WeldConstraint): it keeps following the body part when the client poses
	-- the joints.
	local weld = Instance.new("Weld")
	weld.Name = "Attach"
	weld.Part0 = body
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = model
	return part
end

local function addAccessories(model: Model, role: string, look: Look, shopColor: Color3?)
	local head = model:FindFirstChild("Head") :: BasePart?
	local torso = model:FindFirstChild("Torso") :: BasePart?
	if head == nil or torso == nil then
		return
	end
	-- (the R6 head looks about 1.25 studs wide and tall: its top is 0.62 above its centre)
	if look.hair and look.cap == nil and look.beanie == nil then
		addBlock(
			model,
			head,
			"Hair",
			Vector3.new(1.32, 0.42, 1.32),
			CFrame.new(0, 0.5, 0.04),
			look.hair,
			Enum.Material.Fabric
		)
	end
	if look.cap then
		addBlock(
			model,
			head,
			"Cap",
			Vector3.new(1.34, 0.42, 1.34),
			CFrame.new(0, 0.52, 0),
			look.cap
		)
		addBlock(
			model,
			head,
			"CapBrim",
			Vector3.new(1.1, 0.12, 0.6),
			CFrame.new(0, 0.36, -0.86),
			look.cap
		)
	end
	if look.beanie then
		addBlock(
			model,
			head,
			"Beanie",
			Vector3.new(1.36, 0.55, 1.36),
			CFrame.new(0, 0.5, 0),
			look.beanie,
			Enum.Material.Fabric
		)
	end
	if look.glasses then
		addBlock(
			model,
			head,
			"Glasses",
			Vector3.new(1.0, 0.22, 0.1),
			CFrame.new(0, 0.12, -0.64),
			Color3.fromRGB(20, 20, 22)
		)
	end
	if look.apron then
		-- from the chest down to the knees, on the front of the torso
		addBlock(
			model,
			torso,
			"Apron",
			Vector3.new(1.7, 2.2, 0.12),
			CFrame.new(0, -0.55, -0.56),
			look.apron,
			Enum.Material.Fabric
		)
	end
	if look.badge then
		addBlock(
			model,
			torso,
			"Badge",
			Vector3.new(0.42, 0.24, 0.06),
			CFrame.new(-0.5, 0.45, -0.53),
			Color3.fromRGB(236, 232, 220)
		)
	end
	if role == "Clerk" and shopColor then
		-- the shop's colour on the polo's collar
		addBlock(
			model,
			torso,
			"Collar",
			Vector3.new(1.4, 0.2, 1.06),
			CFrame.new(0, 0.92, 0),
			shopColor
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
