--!strict
-- Shop: cosmetics bought with coins (step 10). SERVER-AUTHORITATIVE.
-- Nothing sold here changes a fight (titles, outfit colours, kill
-- effects, emotes). Catalog: Shared/Cosmetics.
--
--   Remotes.BuyCosmetic(id)              level + coins checked, saved
--   Remotes.EquipCosmetic(category, id)  only what you own ("" = none)
--   Remotes.Emote()                      plays your emote (not mid-fight)
--
-- What others see:
--   • "Title" attribute on the Player (name tags, scoreboard),
--   • the outfit colours on the character (top = Torso, trousers = legs;
--     the avatar's own Shirt / Pants are taken off while one is equipped),
--   • Remotes.KillEffect when you finish someone,
--   • the emote through Remotes.CombatAction (like any action).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ProgressionCurve = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Combat = require(script.Parent.Combat)
local Knockout = require(script.Parent.Knockout)
local PlayerData = require(script.Parent.PlayerData)

local Shop = {}

local buyLimiter = RateLimiter.new(3, 0.5)
local equipLimiter = RateLimiter.new(6, 2)
local emoteLimiter = RateLimiter.new(2, 0.5)

-- No emote this soon after being hit or hitting someone (seconds).
local EMOTE_COMBAT_GAP = 3

local function equippedItem(player: Player, category: Cosmetics.Category): Cosmetics.Item?
	local data = PlayerData.getData(player)
	if data == nil then
		return nil
	end
	local item = Cosmetics.get(data.equipped[category])
	-- Only if still owned and of the right category.
	if item and item.category == category and Cosmetics.owns(data, item) then
		return item
	end
	return nil
end

local function applyTitle(player: Player)
	local item = equippedItem(player, "Title")
	player:SetAttribute("Title", if item then item.title else nil)
end

local function applyOutfit(player: Player)
	local character = player.Character
	local item = equippedItem(player, "Outfit")
	if character == nil or item == nil then
		return
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	if colors == nil then
		local created = Instance.new("BodyColors")
		created.Parent = character
		colors = created
	end
	local bodyColors = colors :: BodyColors
	-- The avatar's own clothes would cover the colours: off while equipped.
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	if item.top then
		bodyColors.TorsoColor3 = item.top
	end
	if item.trousers then
		bodyColors.LeftLegColor3 = item.trousers
		bodyColors.RightLegColor3 = item.trousers
	end
end

local function onBuy(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" or not buyLimiter.allow(player) then
		return
	end
	local item = Cosmetics.get(itemId)
	local data = PlayerData.getData(player)
	if item == nil or data == nil or Cosmetics.owns(data, item) then
		return
	end
	if ProgressionCurve.levelFromXp(data.xp) < (item.unlockLevel or 1) then
		return
	end
	if item.price > 0 and not PlayerData.spendCoins(player, item.price) then
		return
	end
	PlayerData.update(player, function(current)
		current.ownedCosmetics[item.id] = true
	end)
end

local function onEquip(player: Player, category: unknown, itemId: unknown)
	if
		typeof(category) ~= "string"
		or typeof(itemId) ~= "string"
		or not equipLimiter.allow(player)
	then
		return
	end
	if not table.find(Cosmetics.CATEGORIES, category) then
		return
	end
	local data = PlayerData.getData(player)
	if data == nil then
		return
	end
	if itemId ~= "" then
		local item = Cosmetics.get(itemId)
		if item == nil or item.category ~= category or not Cosmetics.owns(data, item) then
			return
		end
	end
	PlayerData.update(player, function(current)
		(current.equipped :: any)[category] = itemId
	end)
	if category == "Title" then
		applyTitle(player)
	elseif category == "Outfit" then
		applyOutfit(player) -- (taking an outfit off shows on the next life)
	end
end

local function onEmote(player: Player)
	if not emoteLimiter.allow(player) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local item = equippedItem(player, "Emote")
	if character == nil or humanoid == nil or humanoid.Health <= 0 or item == nil then
		return
	end
	-- Not mid-fight: no emote to dodge a hit or show off between punches.
	if
		os.clock() - Knockout.lastHitAt(character) < EMOTE_COMBAT_GAP
		or character:GetAttribute("Stunned") == true
		or character:GetAttribute("Blocking") == true
		or Knockout.isKnockedOut(character)
		or not Combat.isIdle(character) -- mid-attack, sliding, frozen...
	then
		return
	end
	local combatUntil = player:GetAttribute("CombatUntil")
	if typeof(combatUntil) == "number" and combatUntil > workspace:GetServerTimeNow() then
		return
	end
	Remotes.CombatAction:FireAllClients(character, item.animation)
end

local function onEliminated(elimination: Knockout.Elimination)
	local killer = elimination.killerPlayer
	if elimination.kind ~= "Finished" or killer == nil then
		return
	end
	local item = equippedItem(killer, "KillEffect")
	local root = elimination.victim:FindFirstChild("HumanoidRootPart")
	if item and item.effect and root and root:IsA("BasePart") then
		Remotes.KillEffect:FireAllClients(item.effect, root.Position)
	end
end

local function onLoaded(player: Player)
	applyTitle(player)
	applyOutfit(player)
end

function Shop.start()
	Remotes.BuyCosmetic.OnServerEvent:Connect(onBuy)
	Remotes.EquipCosmetic.OnServerEvent:Connect(onEquip)
	Remotes.Emote.OnServerEvent:Connect(onEmote)
	Knockout.onEliminated(onEliminated)
	PlayerData.onLoaded(onLoaded)
	local function watch(player: Player)
		-- Once Roblox has dressed the avatar (its clothes and colours would
		-- otherwise cover ours), and again if clothes are added later.
		player.CharacterAppearanceLoaded:Connect(function(character)
			if player.Character ~= character then
				return
			end
			applyOutfit(player)
			character.ChildAdded:Connect(function(child)
				local isClothes = child:IsA("Shirt")
					or child:IsA("Pants")
					or child:IsA("ShirtGraphic")
				if (isClothes or child:IsA("BodyColors")) and equippedItem(player, "Outfit") then
					task.defer(applyOutfit, player)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Shop
