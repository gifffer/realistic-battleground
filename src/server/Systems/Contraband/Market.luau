--!strict
-- Market: the buyer at the back of the refrigerated van in the Yard ("night intake").
--
-- Built at start, once the city is built (parts only, all Unbreakable, in
-- Workspace > ContrabandSites > Buyer): the van's open rear door with "NIGHT INTAKE" on it, a
-- dark opening with a cold light, one small red bulb above it (the only red of the whole
-- contraband trade), and the buyer NPC "Marlow" (CityNpcs.spawnExtra; if he can't be made, the
-- spot works without him). The "Sell" prompt (SellPrompt) is at the NPC.
--
-- SELLING (everything checked on the server):
--   1. Sell: you hold a case with at least one bio-core, you are alive, standing, idle (not
--      attacking / blocking / stunned...), not in the park, not extracting, close enough, and
--      your trip is clean (TripLog). One try every SELL_COOLDOWN s.
--   2. The case OPENS for OPEN_TIME s (character attribute CaseOpen = true: every client opens
--      the lid): you are vulnerable. A hit, a knockout, death, losing the case or moving more
--      than CANCEL_MOVE studs cancels it ("Interrupted"): nothing is lost.
--   3. The sale itself is one synchronous block: the Ledger sells every core of the case at
--      once, the coins (Grades.price, ×0.5 on a private server) go through PlayerData.addCoins,
--      the trip log and Heat are updated. The case stays in your hand, empty.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Grades = require(ReplicatedStorage.Shared.Contraband.Grades)
local Sites = require(ReplicatedStorage.Shared.Contraband.Sites)
local Types = require(ReplicatedStorage.Shared.Types)
local SafeZone = require(ReplicatedStorage.Shared.Util.SafeZone)
local CityNpcs = require(script.Parent.Parent.CityNpcs)
local Combat = require(script.Parent.Parent.Combat)
local Knockout = require(script.Parent.Parent.Knockout)
local PlayerData = require(script.Parent.Parent.PlayerData)
local Case = require(script.Parent.Case)
local Guard = require(script.Parent.Guard)
local Heat = require(script.Parent.Heat)
local Ledger = require(script.Parent.Ledger)
local TripLog = require(script.Parent.TripLog)

local M = Config.Market

local CHECK_EVERY = 0.1 -- seconds between two "still OK?" checks while the case is open

type Sale = {
	caseId: string,
	startPosition: Vector3,
	endsAt: number, -- os.clock()
	interrupted: boolean,
}

local Market = {}

local sales: { [Player]: Sale } = {}
local lastTryAt: { [Player]: number } = {}

local function isPrivateServer(): boolean
	-- (reserved servers also have a PrivateServerId, but no owner: only real private servers count)
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

local function result(player: Player, payload: Types.SaleResultPayload)
	Guard.sendSaleResult(player, payload)
end

local function endSale(player: Player)
	sales[player] = nil
	local character = player.Character
	if character then
		character:SetAttribute("CaseOpen", nil)
	end
end

local function cancel(player: Player, reason: string)
	if sales[player] == nil then
		return
	end
	endSale(player)
	result(player, { ok = false, coins = 0, sold = {}, reason = reason })
end

-- The actual sale, after the case stayed open long enough. No yield in here.
local function transact(player: Player, sale: Sale)
	local record = Case.held(player)
	if record == nil or record.id ~= sale.caseId then
		cancel(player, "Interrupted")
		return
	end
	if not PlayerData.isLoaded(player) then
		-- (the save is closing: never use up the cores without paying them)
		cancel(player, "Interrupted")
		return
	end
	local grades = Ledger.sell(record.id, player.UserId, os.clock())
	endSale(player)
	if grades == nil or #grades == 0 then
		result(player, { ok = false, coins = 0, sold = {}, reason = "The case is empty." })
		Case.pushState(player)
		return
	end
	local coins = Grades.price(grades, isPrivateServer())
	if coins >= 1 then
		PlayerData.addCoins(player, coins)
	end
	PlayerData.update(player, function(data)
		data.contraband.log.sales += 1
		data.contraband.log.coinsEarned += coins
	end)
	Heat.record(player, "sales")
	Heat.record(player, "coins", coins)
	TripLog.stop(player)
	result(player, { ok = true, coins = coins, sold = grades, reason = nil })
	Case.pushState(player)
	Case.refreshTrip(player)
	Guard.debug(`{player.Name} sold {#grades} core(s) for {coins} coins`)
	if Guard.isDebug() then
		local ok, problem = Ledger.verify()
		if not ok then
			warn(`[Contraband] Ledger check failed after a sale: {problem}`)
		end
	end
end

local function onSell(player: Player, prompt: ProximityPrompt)
	if sales[player] or not Guard.promptAllowed(player, prompt) then
		return
	end
	local now = os.clock()
	if now - (lastTryAt[player] or -math.huge) < M.SELL_COOLDOWN then
		return
	end
	lastTryAt[player] = now
	local record = Case.held(player)
	if record == nil then
		Guard.notice(player, "Bring a case.")
		return
	end
	if Ledger.caseCount(record.id) == 0 then
		Guard.notice(player, "The case is empty.")
		return
	end
	local character, root = Guard.body(player)
	if character == nil or root == nil then
		return
	end
	if not Combat.isIdle(character) then
		Guard.notice(player, "Not while fighting.")
		return
	end
	if SafeZone.containsModel(character) or player:GetAttribute("InLab") == true then
		Guard.notice(player, "The buyer won't deal here.")
		return
	end
	local part = prompt.Parent :: BasePart
	if not Guard.near(player, part.Position, M.SERVER_DISTANCE) then
		return
	end
	local clean, why = TripLog.check(player, root.Position)
	if not clean then
		warn(`[Contraband] sale refused for {player.Name} ({player.UserId}): {why}`)
		Heat.record(player, "tripFlags")
		result(player, { ok = false, coins = 0, sold = {}, reason = "Try again." })
		return
	end

	-- Open the case: vulnerable for OPEN_TIME seconds.
	local sale: Sale = {
		caseId = record.id,
		startPosition = root.Position,
		endsAt = now + M.OPEN_TIME,
		interrupted = false,
	}
	sales[player] = sale
	character:SetAttribute("CaseOpen", true)
	Guard.send(player, "SaleStarted", { endsAt = workspace:GetServerTimeNow() + M.OPEN_TIME })
	task.spawn(function()
		while sales[player] == sale do
			if sale.interrupted then
				cancel(player, "Interrupted")
				return
			end
			local _, currentRoot = Guard.body(player)
			local held = Case.held(player)
			if
				currentRoot == nil
				or player.Character ~= character
				or Knockout.isKnockedOut(character)
				or held == nil
				or held.id ~= sale.caseId
				or (currentRoot.Position - sale.startPosition).Magnitude > M.CANCEL_MOVE
			then
				cancel(player, "Interrupted")
				return
			end
			if os.clock() >= sale.endsAt then
				transact(player, sale)
				return
			end
			task.wait(CHECK_EVERY)
		end
	end)
end

------------------------------------------------------------------------------
-- The buyer spot
------------------------------------------------------------------------------

local function buildSpot(): BasePart
	local site = Sites.BUYER
	local model = Instance.new("Model")
	model.Name = "Buyer"
	model:SetAttribute("Unbreakable", true)

	local function add(
		name: string,
		size: Vector3,
		cframe: CFrame,
		material: Enum.Material,
		color: Color3
	): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = cframe
		part.Anchored = true
		part.Material = material
		part.Color = color
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end

	local rearX = site.vanRearX
	local floorY = site.groundY + 0.85 -- (the van's load floor)
	-- The open rear door: hinged at the north rear corner, swung open 100° (toward the street).
	local hinge = Vector3.new(rearX - 0.12, floorY + 3.6, site.vanZMax)
	local angle = math.rad(100)
	local along = Vector3.new(-math.sin(angle), 0, -math.cos(angle))
	local doorCentre = hinge + along * 1.8
	local door = add(
		"RearDoor",
		Vector3.new(0.2, 7, 3.6),
		CFrame.lookAt(doorCentre, doorCentre + along),
		Enum.Material.Metal,
		Color3.fromRGB(200, 200, 198)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Stencil"
	gui.Face = Enum.NormalId.Right -- (the side that faces the buyer's spot)
	gui.CanvasSize = Vector2.new(360, 120)
	gui.LightInfluence = 1
	gui.Parent = door
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.25)
	label.Position = UDim2.fromScale(0.05, 0.12)
	label.BackgroundTransparency = 1
	label.Text = "NIGHT INTAKE"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(232, 230, 222)
	label.Parent = gui
	-- The dark opening of the van with its cold light.
	local opening = add(
		"Opening",
		Vector3.new(0.06, 6.4, 3.4),
		CFrame.new(rearX - 0.04, floorY + 3.3, (site.vanZMin + site.vanZMax) / 2 + 1.8),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(18, 20, 22)
	)
	opening.CanCollide = false
	local strip = add(
		"ColdStrip",
		Vector3.new(0.08, 0.08, 3.2),
		CFrame.new(rearX - 0.08, floorY + 6.35, (site.vanZMin + site.vanZMax) / 2 + 1.8),
		Enum.Material.Neon,
		Color3.fromRGB(200, 225, 255)
	)
	strip.CanCollide = false
	local cold = Instance.new("PointLight")
	cold.Color = Color3.fromRGB(200, 225, 255)
	cold.Brightness = 0.8
	cold.Range = 10
	cold.Shadows = false
	cold.Parent = strip
	-- The small red bulb above the door.
	local bulb = add(
		"RedBulb",
		Vector3.new(0.3, 0.3, 0.3),
		CFrame.new(rearX - 0.2, floorY + 7.4, (site.vanZMin + site.vanZMax) / 2),
		Enum.Material.Neon,
		Color3.fromRGB(255, 40, 25)
	)
	bulb.Shape = Enum.PartType.Ball
	bulb.CanCollide = false
	local red = Instance.new("PointLight")
	red.Color = Color3.fromRGB(255, 40, 25)
	red.Brightness = 0.6
	red.Range = 6
	red.Shadows = false
	red.Parent = bulb

	model.Parent = Guard.worldFolder("ContrabandSites")
	local promptPart = Guard.marker("SellSpot", CFrame.new(site.promptAt), model)
	local prompt = Guard.makePrompt(
		promptPart,
		"SellPrompt",
		"Sell cores",
		site.label,
		M.PROMPT_HOLD,
		M.PROMPT_DISTANCE,
		false -- (the buyer NPC stands on the prompt: his body would hide it)
	)
	prompt.Triggered:Connect(function(player: Player)
		onSell(player, prompt)
	end)
	return promptPart
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function Market.onLeaving(player: Player)
	sales[player] = nil
	lastTryAt[player] = nil
end

function Market.start()
	Combat.onDamaged(function(info)
		local player = Players:GetPlayerFromCharacter(info.victim)
		local sale = if player then sales[player] else nil
		if sale then
			sale.interrupted = true
		end
	end)
	local city = Guard.waitForCity(180)
	if city == nil then
		warn("[Contraband] no city: the buyer is not set up")
		return
	end
	buildSpot()
	local ok, npc = pcall(CityNpcs.spawnExtra, {
		cframe = Sites.BUYER.npcAt,
		role = "Patron",
		name = "Marlow",
		pose = "ArmsCrossed",
		seed = 4242,
	})
	if not ok or npc == nil then
		warn("[Contraband] the buyer NPC could not be made (the Sell prompt still works)")
	end
end

return Market
