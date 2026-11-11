--!strict
-- Client copy of the local player's save.
--
-- The SERVER owns the real save; this controller only keeps the latest
-- snapshot the server sent, so the UI can display it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local PlayerDataController = {}

local snapshot: Types.ProfileSnapshot? = nil
local changed = Signal.new() :: Signal.Signal<Types.ProfileSnapshot>

-- Latest save received from the server (nil until it arrives).
function PlayerDataController.get(): Types.ProfileSnapshot?
	return snapshot
end

-- Calls `callback(snapshot)` now if the save is already here, and on every change.
function PlayerDataController.onChanged(callback: (Types.ProfileSnapshot) -> ()): Signal.Connection
	if snapshot then
		task.spawn(callback, snapshot)
	end
	return changed.connect(callback)
end

function PlayerDataController.init()
	Remotes.ProfileUpdated.OnClientEvent:Connect(function(data: Types.ProfileSnapshot)
		snapshot = data
		changed.fire(data)
	end)
end

function PlayerDataController.start()
	-- In case the server's first push arrived before we were listening.
	Remotes.RequestProfile:FireServer()
end

return PlayerDataController
