--!strict
-- Vfx/Moves: every move's VFX spec, merged from the spec files below.
--   Moves.clips[clipName]  what plays while an animation clip runs (swings)
--   Moves.moves[specId]    what plays when a hit of that move lands
-- A name found in two files is a mistake: we warn and keep the first.

local Types = require(script.Parent.Types)

local FILES: { Types.SpecModule } = {
	require(script.Base),
	require(script.Brawler),
	require(script.Boxer),
	require(script.Bouncer),
	require(script.Sentinel),
	require(script.Rift),
	require(script.Cinematics),
	require(script.Weapons),
}

local clips: { [string]: Types.ClipSpec } = {}
local moves: { [string]: Types.MoveSpec } = {}

for _, file in FILES do
	for name, spec in file.clips do
		if clips[name] then
			warn(`[Vfx] clip spec "{name}" is defined twice (Vfx/Moves)`)
		else
			clips[name] = spec
		end
	end
	for id, spec in file.moves do
		if moves[id] then
			warn(`[Vfx] move spec "{id}" is defined twice (Vfx/Moves)`)
		else
			moves[id] = spec
		end
	end
end

return table.freeze({
	clips = clips,
	moves = moves,
})
