--!strict
-- PlayerData: loads, keeps and saves every player's profile (their save).
--
-- Big picture:
--   • A player joins → we open a "session" on their save with ProfileStore.
--     Only ONE server at a time can hold a session (session locking). That's
--     what stops item duplication when someone hops between servers.
--   • While they play, gameplay code changes the save IN MEMORY through
--     PlayerData.update() (or the currency helpers). ProfileStore autosaves
--     in the background every Config.AUTOSAVE_INTERVAL seconds.
--   • The player leaves, or the server shuts down → final save, lock released.
--     (ProfileStore handles game:BindToClose for us.)
--   • If anything goes wrong while loading, the player is KICKED before they
--     can play: playing on a blank save would overwrite their real one.
--
-- Rule: no other script ever touches DataStoreService for player data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Migrations = require(script.Migrations)
local Template = require(script.Template)

-- ProfileStore is installed by Wally (`wally install`) into ServerPackages.
local packages = ServerScriptService:FindFirstChild("ServerPackages")
local profileStoreModule = packages and packages:FindFirstChild("ProfileStore")
assert(
	profileStoreModule and profileStoreModule:IsA("ModuleScript"),
	"[PlayerData] ProfileStore not found. Run `wally install` in the project folder, "
		.. "then restart `rojo serve` (see docs/SETUP_FR.md)."
)
local ProfileStore = require(profileStoreModule :: ModuleScript) :: any

-- DataStore name. Changing it = every player starts from zero. Don't.
local STORE_NAME = "PlayerData"

-- In Studio: true = playtests never touch real saves (data resets every
-- playtest). false = Studio uses the real DataStore, if "Enable Studio Access
-- to API Services" is ON in Game Settings > Security.
local USE_MOCK_IN_STUDIO = false

local KICK_LOAD_FAILED =
	"We couldn't load your save. Nothing was lost — please rejoin in a moment."
local KICK_NEWER_SAVE =
	"Your save comes from a newer version of the game. Please rejoin to get the update."
local KICK_SESSION_ENDED = "Your save was opened on another server. Please rejoin."

-- Only the parts of ProfileStore's Profile object that we use.
type Profile = {
	Data: Types.PlayerProfile,
	IsActive: (self: Profile) -> boolean,
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
	OnSessionEnd: { Connect: (self: any, listener: () -> ()) -> any },
}

local PlayerData = {}

local store: any = nil
local profiles: { [Player]: Profile } = {}
local pushQueued: { [Player]: boolean } = {}
local loaded = Signal.new() :: Signal.Signal<Player>

local function profileKey(player: Player): string
	return `Player_{player.UserId}`
end

local function isInGame(player: Player): boolean
	return player.Parent == Players
end

-- Sends the player's save to their client, at most once per frame
-- (ten changes in the same frame = one network message).
local function queuePush(player: Player)
	if pushQueued[player] then
		return
	end
	pushQueued[player] = true
	task.defer(function()
		pushQueued[player] = nil
		local profile = profiles[player]
		if profile and isInGame(player) then
			Remotes.ProfileUpdated:FireClient(player, profile.Data)
		end
	end)
end

-- Upgrades and repairs a freshly loaded save. Works on a COPY: if a migration
-- fails halfway, the real save stays untouched.
local function prepareData(profile: Profile): (Migrations.Result, string?)
	local copy = TableUtil.deepCopy(profile.Data) :: any
	local result, problem = Migrations.run(copy)
	if result ~= "ok" then
		-- The `~= "ok"` check makes the checker forget the exact type: restore it.
		return result :: Migrations.Result, problem
	end
	profile.Data = copy
	profile:Reconcile() -- adds fields that were added to Template since the last visit
	return "ok" :: Migrations.Result, nil
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(profileKey(player), {
		-- Stop retrying if the player leaves while we're still loading.
		Cancel = function()
			return not isInGame(player)
		end,
	}) :: Profile?

	if profile == nil then
		-- The player left during loading, or the DataStore is unreachable.
		if isInGame(player) then
			player:Kick(KICK_LOAD_FAILED)
		end
		return
	end

	local result, problem = prepareData(profile)
	if result ~= "ok" then
		warn(`[PlayerData] {player.Name} ({player.UserId}) not loaded: {problem}`)
		profile:EndSession() -- releases the lock; the save itself was not modified
		if isInGame(player) then
			player:Kick(if result == "newer" then KICK_NEWER_SAVE else KICK_LOAD_FAILED)
		end
		return
	end

	-- Links the save to the player's account (lets Roblox handle GDPR
	-- "delete my data" requests).
	profile:AddUserId(player.UserId)

	-- The session can end without us asking: another server took the save
	-- (player joined elsewhere), or this server is shutting down.
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		pushQueued[player] = nil
		if isInGame(player) and not ProfileStore.IsClosing then
			player:Kick(KICK_SESSION_ENDED)
		end
	end)

	if not isInGame(player) then
		-- Left right as loading finished: release immediately.
		profile:EndSession()
		return
	end

	profiles[player] = profile
	player:SetAttribute("DataLoaded", true)
	loaded.fire(player)
	queuePush(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	pushQueued[player] = nil
	if profile then
		profile:EndSession() -- final save + release the lock
	end
end

------------------------------------------------------------------------------
-- Public API (for other server systems)
------------------------------------------------------------------------------

-- The player's save, or nil if it isn't loaded (yet / anymore).
-- READ ONLY: to change something, use PlayerData.update().
function PlayerData.getData(player: Player): Types.PlayerProfile?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerData.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Changes a player's save, then sends the new version to their client.
-- `mutate` must NOT yield (no task.wait, no WaitForChild...), otherwise the
-- session could end in the middle and the change would be lost.
-- Returns false if the save isn't loaded.
function PlayerData.update(player: Player, mutate: (data: Types.PlayerProfile) -> ()): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	mutate(profile.Data)
	queuePush(player)
	return true
end

local function assertAmount(amount: number)
	assert(
		typeof(amount) == "number" and amount > 0 and amount % 1 == 0 and amount < math.huge,
		`amount must be a positive whole number, got {amount}`
	)
end

-- Gives coins (rewards). Returns false if the save isn't loaded.
-- ⚠️ Anything bought with Robux will go through a dedicated purchase handler
-- (MarketplaceService.ProcessReceipt) that also waits for the save to be written.
function PlayerData.addCoins(player: Player, amount: number): boolean
	assertAmount(amount)
	return PlayerData.update(player, function(data)
		data.coins += amount
	end)
end

-- Spends coins. Returns false (and changes nothing) if the player can't afford it.
function PlayerData.spendCoins(player: Player, amount: number): boolean
	assertAmount(amount)
	local data = PlayerData.getData(player)
	if data == nil or data.coins < amount then
		return false
	end
	return PlayerData.update(player, function(current)
		current.coins -= amount
	end)
end

-- Calls `callback(player)` for every player whose save is loaded, now and later.
function PlayerData.onLoaded(callback: (Player) -> ()): Signal.Connection
	for player in profiles do
		task.spawn(callback, player)
	end
	return loaded.connect(callback)
end

------------------------------------------------------------------------------
-- Remote handlers (everything coming from clients is untrusted)
------------------------------------------------------------------------------

local requestLimiter = RateLimiter.new(3, 0.5)

local function onRequestProfile(player: Player)
	if requestLimiter.allow(player) and profiles[player] then
		queuePush(player)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function PlayerData.init()
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Config.AUTOSAVE_INTERVAL)
	ProfileStore.OnError:Connect(function(message: string, storeName: string, key: string)
		warn(`[PlayerData] DataStore error ({storeName}/{key}): {message}`)
	end)

	store = ProfileStore.New(STORE_NAME, Template)
	if RunService:IsStudio() and USE_MOCK_IN_STUDIO then
		store = store.Mock
	end
end

function PlayerData.start()
	Remotes.RequestProfile.OnServerEvent:Connect(onRequestProfile)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Players who joined before this script ran (happens in Studio).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerData
