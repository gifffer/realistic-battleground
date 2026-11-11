--!strict
-- Sound effects of the game. id = 0 → not chosen yet: the game simply plays
-- nothing for it, so you can fill these in any order.
--
-- How to fill one in (guide: docs/SOUNDS_FR.md):
--   1. Find or upload the sound (Creator Store → Audio, or Creator Hub → Upload).
--   2. Copy its number and put it as `id` below (example: id = 1234567890).
--   3. Rojo syncs, press Play.
--
--   volume          0 → 1 (0.5 = half)
--   pitchVariation  each play is randomly a bit higher / lower (0.08 = ±8 %),
--                   so the same punch never sounds exactly the same twice.
--
-- Every sound is played IN 3D on the character who makes it (you hear it
-- louder when close, from the right direction).

export type SoundInfo = {
	id: number,
	volume: number,
	pitchVariation: number,
}

local sounds: { [string]: SoundInfo } = {
	-- Combat ---------------------------------------------------------------
	Swing = { id = 0, volume = 0.5, pitchVariation = 0.1 }, -- M1 1 to 3 (whoosh)
	HeavySwing = { id = 0, volume = 0.6, pitchVariation = 0.08 }, -- M1 4 (finisher)
	Hit = { id = 0, volume = 0.7, pitchVariation = 0.1 }, -- punch lands
	HeavyHit = { id = 0, volume = 0.9, pitchVariation = 0.06 }, -- finisher lands
	Block = { id = 0, volume = 0.6, pitchVariation = 0.1 }, -- hit on the guard
	Parry = { id = 0, volume = 0.8, pitchVariation = 0.05 },
	GuardBreak = { id = 0, volume = 0.9, pitchVariation = 0.05 },
	Dash = { id = 0, volume = 0.5, pitchVariation = 0.1 },
	Dodge = { id = 0, volume = 0.5, pitchVariation = 0.1 }, -- hit dodged by a dash

	-- Movement -------------------------------------------------------------
	Slide = { id = 0, volume = 0.5, pitchVariation = 0.08 },
	Vault = { id = 0, volume = 0.5, pitchVariation = 0.1 },
	Mantle = { id = 0, volume = 0.5, pitchVariation = 0.1 }, -- grabbing a ledge
}

return table.freeze(sounds)
