--!strict
-- Grades: how good a bio-core is, and what the buyer pays for it.
-- Pure functions (no Instance, no service), used by the server (Contraband) and the
-- client (the HUD shows the grades and the price).
--
--   score 0..100 (the extraction score)  →  grade "A" (≥ GRADE_A), "B" (≥ GRADE_B), else "C"
--   price of one core = round(BASE_PRICE × GRADE_MULT[grade]), × PRIVATE_SERVER_MULT on a
--   private server (rounded again, never under 1 coin).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type CoreGrade = Types.CoreGrade

local Grades = {}

-- Is `value` one of the three grades? (Saves and remotes are checked with it.)
function Grades.isGrade(value: any): boolean
	return value == "A" or value == "B" or value == "C"
end

-- The grade for an extraction score (NaN counts as 0).
function Grades.fromScore(score: number): CoreGrade
	if score ~= score then
		score = 0
	end
	if score >= Config.Extraction.GRADE_A then
		return "A"
	elseif score >= Config.Extraction.GRADE_B then
		return "B"
	end
	return "C"
end

-- The price multiplier of a grade (A 1.2, B 1.0, C 0.8).
function Grades.multiplier(grade: CoreGrade): number
	local value = Config.Market.GRADE_MULT[grade]
	return if typeof(value) == "number" then value else 1
end

-- Coins for ONE core of this grade (a whole number, at least 1).
function Grades.priceOf(grade: CoreGrade, privateServer: boolean): number
	local coins = math.round(Config.Market.BASE_PRICE * Grades.multiplier(grade))
	if privateServer then
		coins = math.round(coins * Config.Market.PRIVATE_SERVER_MULT)
	end
	return math.max(1, coins)
end

-- Coins for a whole sale (the sum of every core's price). 0 for an empty list.
function Grades.price(grades: { CoreGrade }, privateServer: boolean): number
	local total = 0
	for _, grade in grades do
		total += Grades.priceOf(grade :: CoreGrade, privateServer)
	end
	return total
end

-- Quick checks of the rules above (Studio command bar or a test harness).
-- Returns (true, nil) or (false, what failed).
function Grades.selfTest(): (boolean, string?)
	local A, B = Config.Extraction.GRADE_A, Config.Extraction.GRADE_B
	if Grades.fromScore(A) ~= "A" or Grades.fromScore(A - 1) ~= "B" then
		return false, "grade A boundary"
	end
	if Grades.fromScore(B) ~= "B" or Grades.fromScore(B - 1) ~= "C" then
		return false, "grade B boundary"
	end
	if Grades.fromScore(0 / 0) ~= "C" then
		return false, "NaN score"
	end
	local base = Config.Market.BASE_PRICE
	local expected = math.round(base * Grades.multiplier("A"))
		+ math.round(base * Grades.multiplier("B"))
	if Grades.price({ "A", "B" }, false) ~= expected then
		return false, "price of A + B"
	end
	if Grades.priceOf("C", true) < 1 then
		return false, "private server price under 1"
	end
	if Grades.price({}, false) ~= 0 then
		return false, "price of nothing"
	end
	return true, nil
end

return Grades
