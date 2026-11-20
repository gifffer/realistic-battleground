--!strict
-- Lab: the culture in each player's vat, his stash (the bench), and the prompts of his lab.
--
-- CULTURE (one vat per player, saved in contraband.culture = { active, grown }):
--   Empty → "Plant culture" → Growing: `grown` += 1 per second while the owner is ON THE SERVER
--   (in his lab or not; offline = paused) → Ready once grown ≥ total → "Extract" (Extraction)
--   → Extracting → Empty again when the bio-core is out (or back to Ready if stopped).
--   total = Config.Lab.CULTURE_TIME (480 s); in Studio with CULTURE_FAST_IN_STUDIO the workspace
--   attribute CultureFast = true is set and CULTURE_FAST_TIME (45 s) is used (set it to false in
--   Studio to test the real time). Saved on every stage change, every SAVE_EVERY s while
--   growing, and when the player leaves.
--
-- STASH: the bio-cores on the bench (Ledger "Bench" location, at most STASH_MAX). Saved to
-- contraband.stash (no ids) after every change, TOGETHER with the cores in the cases lying in the
-- lab (and in the case held inside the lab): a crash or a shutdown loses none of them. Loaded
-- from the save when the player joins (all on the bench; never more than keepMax()).
-- When a culture becomes Ready the owner gets a notice, wherever he is.
--
-- PROMPTS of a lab (made when Apartments builds it; all re-checked here, owner only):
--   VatPrompt     on VatCore     "Plant culture" (Empty) / "Extract" (Ready); off otherwise
--   RackPrompt    on RackSpot    "Take case" (a new empty courier case in hand)
--   LoadPrompt    on BenchAnchor "Load cores": stash cores → free cradles of the case you hold
--                 (shown only while you hold a case with a free cradle and the stash has cores)
--   UnloadPrompt  on BenchAnchor "Unload cores" (key T): cores of the case you hold → stash
--                 (shown only while the case you hold has cores)
--
-- LabState (ContrabandEvent, to the owner only, never with ids) is sent when he joins, enters /
-- leaves his lab, on any change, every RESYNC_EVERY s while he is in the lab, and on request.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local PlayerData = require(script.Parent.Parent.PlayerData)
local Apartments = require(script.Parent.Apartments)
local Case = require(script.Parent.Case)
local Guard = require(script.Parent.Guard)
local Ledger = require(script.Parent.Ledger)

local L = Config.Lab

local SAVE_EVERY = 30 -- seconds between two saves of a growing culture

type Culture = {
	stage: Types.CultureStage,
	grown: number,
	sinceSave: number,
	sinceResync: number,
}

local Lab = {}

local cultures: { [Player]: Culture } = {}
local extractHandler: ((Player) -> ())? = nil

-- Seconds a culture needs (fast in Studio tests).
function Lab.totalTime(): number
	if RunService:IsStudio() and workspace:GetAttribute("CultureFast") == true then
		return L.CULTURE_FAST_TIME
	end
	return L.CULTURE_TIME
end

function Lab.stage(player: Player): Types.CultureStage
	local culture = cultures[player]
	return if culture then culture.stage else "Empty"
end

-- Extraction registers the function the "Extract" prompt calls.
function Lab.setExtractHandler(handler: (Player) -> ())
	extractHandler = handler
end

------------------------------------------------------------------------------
-- State to the owner, saves
------------------------------------------------------------------------------

local function updateVatPrompt(player: Player)
	local culture = cultures[player]
	local core = Apartments.labPart(player, "VatCore")
	local prompt = if core then core:FindFirstChild("VatPrompt") else nil
	if prompt == nil or not prompt:IsA("ProximityPrompt") or culture == nil then
		return
	end
	if culture.stage == "Empty" then
		prompt.ActionText = "Plant culture"
		prompt.Enabled = true
	elseif culture.stage == "Ready" then
		prompt.ActionText = "Extract"
		prompt.Enabled = true
	else
		prompt.Enabled = false
	end
end

local updateBenchPrompts: (Player) -> () -- (defined below, with the other prompts)

-- Sends "LabState" to the player.
function Lab.push(player: Player)
	local culture = cultures[player]
	if culture == nil then
		return
	end
	local payload: Types.LabStatePayload = {
		inLab = player:GetAttribute("InLab") == true,
		stage = culture.stage,
		grown = culture.grown,
		total = Lab.totalTime(),
		at = workspace:GetServerTimeNow(),
		running = culture.stage == "Growing",
		bench = Ledger.benchGrades(player.UserId),
		stashMax = Ledger.stashMax(),
	}
	Guard.sendLabState(player, payload)
	updateVatPrompt(player)
	updateBenchPrompts(player)
end

local function saveCulture(player: Player)
	local culture = cultures[player]
	if culture == nil then
		return
	end
	culture.sinceSave = 0
	local active = culture.stage ~= "Empty"
	-- (an extraction under way is saved as a ready culture: nothing is lost if the server dies)
	local grown = if culture.stage == "Extracting" or culture.stage == "Ready"
		then math.max(culture.grown, Lab.totalTime())
		elseif active then culture.grown
		else 0
	PlayerData.update(player, function(data)
		data.contraband.culture.active = active
		data.contraband.culture.grown = grown
	end)
end

-- Most cores a save may bring back: the shelf, plus full cases in the lab and in hand.
local function keepMax(): number
	local most = 0
	for _, cradles in Config.Case.CRADLES do
		if typeof(cradles) == "number" then
			most = math.max(most, cradles)
		end
	end
	return L.STASH_MAX + (Config.Case.MAX_ISSUED_LIVE + 1) * most
end

-- Writes the stash to the save: the bench + the cores in cases kept in the lab (no ids).
local function saveStash(player: Player)
	local stash = Ledger.stashOf(player.UserId)
	for _, core in Case.labStash(player) do
		table.insert(stash, core)
	end
	PlayerData.update(player, function(data)
		data.contraband.stash = stash
	end)
end

-- Shows the bench prompts only when they can do something (never two at once for nothing).
function updateBenchPrompts(player: Player)
	local anchor = Apartments.labPart(player, "BenchAnchor")
	if anchor == nil then
		return
	end
	local record = Case.held(player)
	local owner = player.UserId
	local load = anchor:FindFirstChild("LoadPrompt")
	if load and load:IsA("ProximityPrompt") then
		load.Enabled = record ~= nil
			and Ledger.benchCount(owner) > 0
			and Ledger.freeSlot(record.id) ~= nil
	end
	local unload = anchor:FindFirstChild("UnloadPrompt")
	if unload and unload:IsA("ProximityPrompt") then
		unload.Enabled = record ~= nil and Ledger.caseCount(record.id) > 0
	end
end

-- Saves the stash (bench + lab cases) and tells the owner.
function Lab.benchChanged(player: Player)
	saveStash(player)
	Lab.push(player)
end

-- Extraction moves the culture between Ready and Extracting.
function Lab.setStage(player: Player, stage: Types.CultureStage)
	local culture = cultures[player]
	if culture == nil then
		return
	end
	culture.stage = stage
	if stage == "Empty" then
		culture.grown = 0
	end
	saveCulture(player)
	Lab.push(player)
end

------------------------------------------------------------------------------
-- Prompts
------------------------------------------------------------------------------

-- The common checks of a prompt inside a lab: it is the player's own lab and he is in it.
local function ownLabPrompt(player: Player, prompt: ProximityPrompt, owner: number): boolean
	if player.UserId ~= owner or not Guard.promptAllowed(player, prompt) then
		return false
	end
	return Apartments.isInOwnLab(player) and cultures[player] ~= nil
end

local function onVat(player: Player)
	local culture = cultures[player]
	if culture == nil then
		return
	end
	if culture.stage == "Empty" then
		if L.PLANT_COST > 0 and not PlayerData.spendCoins(player, L.PLANT_COST) then
			Guard.notice(player, "Not enough coins.")
			return
		end
		culture.stage = "Growing"
		culture.grown = 0
		saveCulture(player)
		Lab.push(player)
	elseif culture.stage == "Ready" then
		if extractHandler then
			extractHandler(player)
		end
	end
end

local function onRack(player: Player)
	Case.issue(player)
end

-- Bench cores → the free cradles of the held case, in order.
local function onLoad(player: Player)
	local record = Case.held(player)
	if record == nil then
		Guard.notice(player, "Take a case first.")
		return
	end
	local owner = player.UserId
	local moved = 0
	for _, id in Ledger.benchIds(owner) do
		local slot = Ledger.freeSlot(record.id)
		if slot == nil then
			break
		end
		if Ledger.move(id, Ledger.bench(owner), Ledger.inCase(record.id, slot)) then
			moved += 1
		end
	end
	if moved == 0 then
		Guard.notice(
			player,
			if Ledger.benchCount(owner) == 0 then "The stash is empty." else "The case is full."
		)
		return
	end
	Lab.benchChanged(player)
	Case.pushState(player)
end

-- Cores of the held case → the bench (as many as fit).
local function onUnload(player: Player)
	local record = Case.held(player)
	if record == nil then
		return
	end
	local owner = player.UserId
	local moved = 0
	for slot = 1, record.cradles do
		local id = Ledger.caseSlots(record.id)[slot]
		if id and Ledger.move(id, Ledger.inCase(record.id, slot), Ledger.bench(owner)) then
			moved += 1
		end
	end
	if moved == 0 then
		Guard.notice(
			player,
			if Ledger.caseCount(record.id) == 0 then "The case is empty." else "The stash is full."
		)
		return
	end
	Lab.benchChanged(player)
	Case.pushState(player)
end

-- Adds the lab's prompts (Apartments calls this right after building a lab).
local function attach(player: Player, model: Model)
	local owner = player.UserId
	local function prompt(
		partName: string,
		name: string,
		action: string,
		object: string,
		hold: number,
		handler: (Player) -> (),
		key: Enum.KeyCode?
	)
		local part = model:FindFirstChild(partName)
		if part == nil or not part:IsA("BasePart") then
			warn(`[Contraband] lab part {partName} missing`)
			return
		end
		local made = Guard.makePrompt(part, name, action, object, hold, L.PROMPT_DISTANCE, false)
		if key then
			made.KeyboardKeyCode = key
		end
		made.Triggered:Connect(function(who: Player)
			if ownLabPrompt(who, made, owner) then
				handler(who)
			end
		end)
	end
	prompt("VatCore", "VatPrompt", "Plant culture", "Vat", 0.6, onVat, nil)
	prompt("RackSpot", "RackPrompt", "Take case", "Case rack", 0.4, onRack, nil)
	prompt("BenchAnchor", "LoadPrompt", "Load cores", "Bench", 0.4, onLoad, nil)
	-- (Load and Unload sit on the same part: two different keys, so one press never fires both)
	prompt("BenchAnchor", "UnloadPrompt", "Unload cores", "Bench", 0.4, onUnload, Enum.KeyCode.T)
	updateVatPrompt(player)
	updateBenchPrompts(player)
end

------------------------------------------------------------------------------
-- Joining, leaving, growing
------------------------------------------------------------------------------

-- The player's save is loaded: his culture and his stash.
function Lab.load(player: Player)
	local data = PlayerData.getData(player)
	if data == nil or cultures[player] then
		return
	end
	local saved = data.contraband
	local grown = saved.culture.grown
	if typeof(grown) ~= "number" or grown ~= grown or grown < 0 then
		grown = 0
	end
	local stage: Types.CultureStage = "Empty"
	if saved.culture.active == true then
		stage = if grown >= Lab.totalTime() then "Ready" else "Growing"
	end
	cultures[player] = {
		stage = stage,
		grown = if stage == "Empty" then 0 else grown,
		sinceSave = 0,
		sinceResync = 0,
	}
	Ledger.loadStash(
		player.UserId,
		if typeof(saved.stash) == "table" then saved.stash else {},
		keepMax()
	)
	Lab.push(player)
end

-- The player leaves (after Case.onLeaving moved the cores of his cases to the bench).
function Lab.onLeaving(player: Player)
	if cultures[player] then
		saveCulture(player)
		saveStash(player)
	end
	cultures[player] = nil
end

local function tick(dt: number)
	local total = Lab.totalTime()
	for player, culture in cultures do
		if player.Parent == nil then
			continue
		end
		if culture.stage == "Growing" then
			culture.grown += dt
			culture.sinceSave += dt
			if culture.grown >= total then
				culture.grown = total
				culture.stage = "Ready"
				saveCulture(player)
				Lab.push(player)
				Guard.notice(
					player,
					if player:GetAttribute("InLab") == true
						then "Culture ready. Extract at the vat."
						else "Culture ready. Back to your lab."
				)
			elseif culture.sinceSave >= SAVE_EVERY then
				saveCulture(player)
			end
		end
		if player:GetAttribute("InLab") == true then
			culture.sinceResync += dt
			if culture.sinceResync >= L.RESYNC_EVERY then
				culture.sinceResync = 0
				Lab.push(player)
			end
		end
	end
end

function Lab.init()
	if
		RunService:IsStudio()
		and L.CULTURE_FAST_IN_STUDIO
		and workspace:GetAttribute("CultureFast") == nil
	then
		workspace:SetAttribute("CultureFast", true)
	end
	Apartments.onLabBuilt(attach)
	-- (going in / out changes which held case counts as "in the lab": save again)
	Apartments.onMoved(function(player: Player)
		if cultures[player] then
			Lab.benchChanged(player)
		end
	end)
	Case.onLabCoresChanged(function(player: Player)
		if cultures[player] then
			Lab.benchChanged(player)
		end
	end)
	Case.onHeldChanged(updateBenchPrompts)
end

function Lab.start()
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			cultures[player] = nil -- (safety net: Lab.onLeaving normally did it)
		end)
	end)
	local last = os.clock()
	while true do
		task.wait(L.TICK)
		local now = os.clock()
		-- (a long server hitch does not grow more than a few seconds at once)
		tick(math.min(now - last, L.TICK * 5))
		last = now
	end
end

return Lab
