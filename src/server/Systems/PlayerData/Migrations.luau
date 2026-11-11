--!strict
-- Save format versioning.
--
-- Saves live forever, but our code keeps changing. Every save stores a
-- `version` number. When we change the SHAPE of saved data (rename, move or
-- change the type of a field), we bump CURRENT_VERSION and add a step that
-- upgrades old saves. Players with old saves get upgraded when they join.
--
-- Just ADDING a new field doesn't need a migration: add it to Template.luau
-- and Profile:Reconcile() fills it in for old saves automatically.
--
-- Example — renaming `coins` to `cash` in version 2:
--   1. Migrations.CURRENT_VERSION = 2
--   2. In STEPS:  [1] = function(data) data.cash = data.coins; data.coins = nil end,
--      ([1] means "upgrades a version 1 save to version 2")
--   3. Update Template.luau and Shared/Types.luau to the new shape.
-- Never edit or delete an old step once it has shipped.

local Migrations = {}

Migrations.CURRENT_VERSION = 1

-- Each step receives the raw save table and edits it in place.
local STEPS: { [number]: (data: { [string]: any }) -> () } = {
	-- [1] = function(data) ... end,
}

export type Result = "ok" | "newer" | "failed"

-- Upgrades `data` (in place) to CURRENT_VERSION.
-- "newer"  = the save comes from a newer version of the game than this server.
-- "failed" = a step is missing or errored; `data` may be half-upgraded, so the
--            caller must throw it away (that's why PlayerData migrates a copy).
function Migrations.run(data: { [string]: any }): (Result, string?)
	-- Saves made before versioning existed have no number: treat them as v1.
	local version = if typeof(data.version) == "number" then data.version else 1

	if version > Migrations.CURRENT_VERSION then
		return "newer",
			`save is version {version}, this server knows up to {Migrations.CURRENT_VERSION}`
	end

	while version < Migrations.CURRENT_VERSION do
		local step = STEPS[version]
		if step == nil then
			return "failed", `no migration step from version {version}`
		end
		local ok, err = pcall(step, data)
		if not ok then
			return "failed", `migration step {version} errored: {err}`
		end
		version += 1
	end

	data.version = version
	return "ok", nil
end

return Migrations
