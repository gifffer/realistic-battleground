--!strict
-- The level curve, shared by the server (who gives XP) and the clients
-- (who draw the XP bar). Numbers: Config.Progression.
--
--   Progression.levelFromXp(xp)  → level, xp into that level, xp needed for the next
--   Progression.xpToNext(level)  → xp needed to go from `level` to `level + 1`

local Config = require(script.Parent.Config)

local P = Config.Progression

local Progression = {}

function Progression.xpToNext(level: number): number
	return math.floor(P.LEVEL_BASE_XP * level ^ P.LEVEL_EXPONENT + 0.5)
end

-- Total XP → (level, XP earned inside that level, XP that level needs).
-- At MAX_LEVEL the bar stays full.
function Progression.levelFromXp(xp: number): (number, number, number)
	local level = 1
	local rest = math.max(0, xp)
	while level < P.MAX_LEVEL do
		local need = Progression.xpToNext(level)
		if rest < need then
			return level, rest, need
		end
		rest -= need
		level += 1
	end
	local need = Progression.xpToNext(P.MAX_LEVEL)
	return level, need, need
end

return table.freeze(Progression)
