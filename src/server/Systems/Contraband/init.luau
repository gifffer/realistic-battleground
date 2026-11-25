--!strict
-- Contraband (prototype): private labs, clone cultures, bio-core extraction, the BX-7 courier
-- case and the buyer. SERVER-AUTHORITATIVE: clients only send wishes (3 remotes + prompts).
--
-- The bootstrap only loads the direct children of Systems, so this module loads its own
-- children, in this order (each one only requires the ones before it):
--   Ledger      where every bio-core is (pure, single writer, never replicated)
--   Guard       shared checks and the one way to message a client
--   Heat        silent per-session counters (no effect yet)
--   TripLog     the anti-teleport check of a delivery
--   Case        the courier cases (hold, set down, drop on KO / death / leave, pick up)
--   LabBuilder  builds a lab room from parts
--   Apartments  the lab doors in the city, the labs, going in and out
--   Lab         the vat culture, the stash, the lab prompts
--   Extraction  the extraction: automatic cut, then pick the bio-elements (ExtractAction)
--   Market      the buyer at the van in the Yard
--
-- It also wires the player's save (PlayerData.onLoaded → Lab.load; onLeaving → every module's
-- clean-up, in the right order) and Remotes.ContrabandSync ("send me my state again").
--
-- Remotes (Shared/Remotes): ContrabandEvent (server → ONE client), ContrabandSync,
-- ExtractAction, CaseAction (client → server, all validated and rate-limited).
-- Studio check of the bio-core ledger (command bar, server):
--   require(game.ServerScriptService.Server.Systems.Contraband.Ledger).verify()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Apartments = require(script.Apartments)
local Case = require(script.Case)
local Extraction = require(script.Extraction)
local Heat = require(script.Heat)
local Lab = require(script.Lab)
local Ledger = require(script.Ledger)
local Market = require(script.Market)
local TripLog = require(script.TripLog)

local Contraband = {}

local syncLimiter = RateLimiter.new(3, 0.5)

-- "Send me my state again" (the first pushes can arrive before the client listens).
local function onSync(player: Player)
	if not syncLimiter.allow(player) then
		return
	end
	Lab.push(player)
	Case.pushState(player)
	Extraction.pushState(player)
end

-- The player leaves: everything is settled BEFORE his save is written for the last time.
-- (PlayerData calls this synchronously; nothing in here yields.)
local function onLeaving(player: Player)
	local steps: { { name: string, run: (Player) -> () } } = {
		{ name = "Extraction", run = Extraction.onLeaving }, -- a running extraction ends (picks kept)
		{ name = "Market", run = Market.onLeaving },
		{ name = "Case", run = Case.onLeaving }, -- held case dropped / lab cases → stash
		{ name = "Lab", run = Lab.onLeaving }, -- culture + stash saved
		{ name = "Apartments", run = Apartments.onLeaving }, -- the lab model goes
	}
	for _, step in steps do
		local ok: boolean, problem: any = pcall(step.run, player)
		if not ok then
			warn(`[Contraband] {step.name} clean-up failed for {player.Name}: {problem}`)
		end
	end
	Ledger.forgetOwner(player.UserId)
	TripLog.forget(player)
	Heat.forget(player)
end

function Contraband.init()
	Heat.init()
	Case.init()
	Lab.init()
	Extraction.init()
	PlayerData.onLeaving(onLeaving)
end

function Contraband.start()
	Remotes.ContrabandSync.OnServerEvent:Connect(onSync)
	PlayerData.onLoaded(Lab.load)
	for _, run in
		{ TripLog.start, Case.start, Apartments.start, Lab.start, Extraction.start, Market.start }
	do
		task.spawn(run)
	end
end

return Contraband
