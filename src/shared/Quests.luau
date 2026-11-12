--!strict
-- Daily quests (step 9): the pool every day's 3 quests are drawn from.
-- Shared: the server counts progress, the menu shows the same texts.
--
-- Each quest counts one STAT (what the server measures) up to a goal drawn
-- between `min` and `max`. `text` uses {n} for the goal. Only fights
-- against real players count (no training dummies), like the rest of
-- the progression.
--
--   Quests.get("Kills")   → QuestDef
--   Quests.POOL           → every quest

export type Stat =
	"Kills" -- eliminations of players you get credited with
	| "Finishers" -- kills done with a finisher
	| "DuelWins" -- duels won (challenge or ranked)
	| "RankedWins"
	| "Damage" -- damage dealt to players
	| "Parries" -- perfect blocks
	| "HeadHits" -- hits landed on the head
	| "KitMoves" -- kit moves (keys 1–4) landed on players
	| "Assists"
	| "Minutes" -- minutes played

export type QuestDef = {
	id: string,
	stat: Stat,
	text: string, -- shown in the menu, {n} = the goal
	min: number,
	max: number,
	step: number, -- the goal is a multiple of this
	-- Reward at the goal's minimum and maximum (in between: proportional).
	xp: { number },
	coins: { number },
}

local POOL: { QuestDef } = {
	{
		id = "Kills",
		stat = "Kills",
		text = "Get {n} kills",
		min = 3,
		max = 8,
		step = 1,
		xp = { 60, 150 },
		coins = { 30, 75 },
	},
	{
		id = "Finishers",
		stat = "Finishers",
		text = "Finish {n} knocked-out opponents",
		min = 2,
		max = 5,
		step = 1,
		xp = { 70, 150 },
		coins = { 35, 75 },
	},
	{
		id = "DuelWins",
		stat = "DuelWins",
		text = "Win {n} duels",
		min = 1,
		max = 3,
		step = 1,
		xp = { 60, 150 },
		coins = { 30, 75 },
	},
	{
		id = "RankedWins",
		stat = "RankedWins",
		text = "Win {n} ranked duels",
		min = 1,
		max = 2,
		step = 1,
		xp = { 90, 150 },
		coins = { 45, 75 },
	},
	{
		id = "Damage",
		stat = "Damage",
		text = "Deal {n} damage",
		min = 400,
		max = 1200,
		step = 100,
		xp = { 50, 140 },
		coins = { 25, 70 },
	},
	{
		id = "Parries",
		stat = "Parries",
		text = "Land {n} perfect blocks",
		min = 3,
		max = 8,
		step = 1,
		xp = { 60, 140 },
		coins = { 30, 70 },
	},
	{
		id = "HeadHits",
		stat = "HeadHits",
		text = "Land {n} hits to the head",
		min = 15,
		max = 40,
		step = 5,
		xp = { 50, 120 },
		coins = { 25, 60 },
	},
	{
		id = "KitMoves",
		stat = "KitMoves",
		text = "Land {n} kit moves",
		min = 8,
		max = 20,
		step = 2,
		xp = { 50, 130 },
		coins = { 25, 65 },
	},
	{
		id = "Assists",
		stat = "Assists",
		text = "Get {n} assists",
		min = 2,
		max = 6,
		step = 1,
		xp = { 50, 120 },
		coins = { 25, 60 },
	},
	{
		id = "Minutes",
		stat = "Minutes",
		text = "Play {n} minutes",
		min = 15,
		max = 30,
		step = 5,
		xp = { 50, 100 },
		coins = { 25, 50 },
	},
}

local byId: { [string]: QuestDef } = {}
for _, quest in POOL do
	byId[quest.id] = quest
end

local Quests = {}

Quests.POOL = POOL
Quests.PER_DAY = 3

function Quests.get(id: string): QuestDef?
	return byId[id]
end

-- The text of `quest` with its goal, e.g. "Get 5 kills".
function Quests.describe(quest: QuestDef, goal: number): string
	return (string.gsub(quest.text, "{n}", tostring(goal)))
end

-- The reward for reaching `goal` (proportional between min and max).
function Quests.reward(quest: QuestDef, goal: number): (number, number)
	local t = if quest.max > quest.min then (goal - quest.min) / (quest.max - quest.min) else 1
	local xp = math.floor(quest.xp[1] + (quest.xp[2] - quest.xp[1]) * t + 0.5)
	local coins = math.floor(quest.coins[1] + (quest.coins[2] - quest.coins[1]) * t + 0.5)
	return xp, coins
end

-- The day number (UTC): quests renew when it changes (midnight UTC).
function Quests.today(): number
	return math.floor(os.time() / 86400)
end

return table.freeze(Quests)
