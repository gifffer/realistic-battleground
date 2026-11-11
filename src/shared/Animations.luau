--!strict
-- Animation IDs, by name. 0 = not made yet (the game works without it).
--
-- How to fill this: make the animation in Studio, publish it on YOUR account,
-- copy its number and put it here (full guide: docs/ANIMATIONS_FR.md).
-- Example:  Block = 1234567890,
--
-- Names must match docs/ANIMATIONS_FR.md exactly.

return table.freeze({
	-- Common to every kit
	Block = 0,
	BlockHit = 0,
	GuardBreak = 0,
	Parry = 0,
	Stunned = 0,
	DashForward = 0,
	DashBack = 0,
	DashLeft = 0,
	DashRight = 0,
	HitFront = 0,
	HitBack = 0,

	-- Street Brawler (the default kit until the kit system exists, step 4)
	Brawler_M1_1 = 0,
	Brawler_M1_2 = 0,
	Brawler_M1_3 = 0,
	Brawler_M1_4 = 0,
} :: { [string]: number })
