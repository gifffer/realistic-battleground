--!strict
-- Vfx/Quality: how much VFX this client can afford.
--   • The player's graphics level (Roblox menu, 1-10; "Automatic" = high),
--     read the same way WeatherController / BloodAge do: low levels get
--     fewer particles and no ghosts / trails on other players.
--   • Distance and screen culling: far or off-screen impacts are skipped
--     (or reduced to their flash + light).
--   • A cap per frame: at most MAX_IMPACTS_PER_FRAME full impact stacks
--     start in one frame (16 players in a brawl); the extra ones get only
--     their flash + light.

local RunService = game:GetService("RunService")

local Quality = {}

local FAR = 150 -- beyond: nothing
local MID = 70 -- beyond: flash + light only
local NEAR_OFFSCREEN = 20 -- off-screen beyond this: nothing
local MAX_IMPACTS_PER_FRAME = 4

export type Level = "Low" | "Medium" | "High"
export type Detail = "Full" | "Minimal" | "None"

local level: Level = "High"
local impactsThisFrame = 0

local function readLevel()
	local ok, value = pcall(function(): number
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	-- ("Automatic" = 0, or unreadable: counts as high)
	local readable = ok and value ~= 0
	if readable and value <= 3 then
		level = "Low"
	elseif readable and value <= 6 then
		level = "Medium"
	else
		level = "High"
	end
end

-- "Low" | "Medium" | "High"
function Quality.level(): Level
	return level
end

-- A particle count scaled for the quality level (never below 1 if it was ≥ 1).
function Quality.count(n: number): number
	if n <= 0 then
		return 0
	end
	local factor = if level == "Low" then 0.5 elseif level == "Medium" then 0.75 else 1
	return math.max(1, math.floor(n * factor + 0.5))
end

-- Ghost limbs, afterimages, floor dust rings, physical debris: not on Low.
function Quality.extras(): boolean
	return level ~= "Low"
end

-- How much of an effect at `point` to show: "Full", "Minimal" (flash +
-- light only) or "None".
function Quality.detail(point: Vector3): Detail
	local camera = workspace.CurrentCamera
	if camera == nil then
		return "None"
	end
	local distance = (camera.CFrame.Position - point).Magnitude
	if distance > FAR then
		return "None"
	end
	if distance > NEAR_OFFSCREEN then
		local _, onScreen = camera:WorldToViewportPoint(point)
		if not onScreen then
			return "None"
		end
	end
	if distance > MID then
		return "Minimal"
	end
	return "Full"
end

-- Takes one "full impact" slot for this frame. false = the cap is reached
-- (show the flash + light only).
function Quality.takeImpact(): boolean
	if impactsThisFrame >= MAX_IMPACTS_PER_FRAME then
		return false
	end
	impactsThisFrame += 1
	return true
end

function Quality.start()
	readLevel()
	pcall(function()
		UserSettings()
			:GetService("UserGameSettings")
			:GetPropertyChangedSignal("SavedQualityLevel")
			:Connect(readLevel)
	end)
	RunService.RenderStepped:Connect(function()
		impactsThisFrame = 0
	end)
end

return Quality
