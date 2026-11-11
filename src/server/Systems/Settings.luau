--!strict
-- Settings: saves the choices made in the Settings window (camera mode...).
--
-- The client sends Remotes.UpdateSetting(name, value). Untrusted input, so:
--   • the name must be in VALIDATORS (unknown names are ignored),
--   • the value must pass that setting's check,
--   • the remote is rate-limited.
--
-- To add a setting: add it to Types.PlayerSettings, to the save template
-- (PlayerData/Template.luau), and a validator here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

local function isBoolean(value: unknown): boolean
	return typeof(value) == "boolean"
end

-- Setting name → function that says if a value is acceptable.
local VALIDATORS: { [string]: (value: unknown) -> boolean } = {
	firstPerson = isBoolean,
}

local Settings = {}

-- Burst of 5, then 2 per second.
local limiter = RateLimiter.new(5, 2)

local function onUpdateSetting(player: Player, name: unknown, value: unknown)
	if typeof(name) ~= "string" then
		return
	end
	local validate = VALIDATORS[name]
	if validate == nil or not validate(value) then
		return
	end
	if not limiter.allow(player) then
		return
	end

	PlayerData.update(player, function(data)
		-- `name` was checked against VALIDATORS just above.
		(data.settings :: any)[name] = value
	end)
end

function Settings.start()
	Remotes.UpdateSetting.OnServerEvent:Connect(onUpdateSetting)
end

return Settings
