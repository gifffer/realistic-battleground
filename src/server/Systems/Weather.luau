--!strict
-- Weather: random events over the city, decided by the server so everyone sees the same.
--
--   RAIN       2 to 4 min. Darker sky, thicker air, puddles everywhere and shining, drips,
--              gutters spouting. A bit likelier at night.
--   THUNDERSTORM  half of the rains: a black sky, much heavier rain blown by the wind (clients),
--              a louder rain sound, and lightning every 9 to 24 s (a bolt in the sky, the screen
--              flashes, the thunder rolls).
--   FOG        2 to 3 min of dense haze: about 90 studs of visibility, lamps turn to orbs.
--   POWER CUT  night only, at most once a night: every lamp, neon and window flickers for 3.5 s,
--              then the district goes dark for 40 s (only the red exit lights and the things
--              on their own power stay on), then the power comes back as a wave from the
--              substation, the street lamps warming up from red to orange.
--
-- Rules: never two events at once, and a calm gap of several minutes after each one
-- (numbers in Shared/Config.luau, section Weather).
--
-- What the server changes itself (Lighting, puddles, lamps...) goes through
-- Server/Systems/Ambience, which applies the weather ON TOP of the day / night look.
-- What each client draws (rain particles, the thunder flash, sounds, the notice) follows these
-- attributes on Workspace:
--   Weather           "Clear" | "Rain" | "Fog" | "PowerCut"
--   Storm             true during a THUNDERSTORM (Weather is then "Rain" too, so anything that
--                     only checks for rain still works)
--   WeatherStartedAt  server time (workspace:GetServerTimeNow()) the event started
--   WeatherEndsAt     server time it ends
--   ThunderAt         server time of the last thunder flash (clients flash at that moment)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ambience = require(script.Parent.Ambience)

local W = Config.Weather

local Weather = {}

local random = Random.new()
-- Studio test mode: short waits (see Config.Weather.STUDIO_FAST).
local fast = RunService:IsStudio() and W.STUDIO_FAST
-- The last night that had a power cut (one per night at most).
local lastPowerCutNight = -1
-- An event asked for from the Studio command bar, run as soon as possible.
local forced: string? = nil

local function between(range: NumberRange): number
	return random:NextNumber(range.Min, range.Max)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Publishes the current event for the clients.
local function publish(kind: string, duration: number, storm: boolean)
	workspace:SetAttribute("Storm", storm)
	workspace:SetAttribute("WeatherStartedAt", now())
	workspace:SetAttribute("WeatherEndsAt", now() + duration)
	workspace:SetAttribute("Weather", kind)
end

-- Waits `seconds`, but stops early if an event is forced from Studio.
local function calmWait(seconds: number)
	local deadline = os.clock() + seconds
	while os.clock() < deadline and forced == nil do
		task.wait(1)
	end
end

------------------------------------------------------------------------------
-- The events (each one yields until it is over)
------------------------------------------------------------------------------

local function runRain(storm: boolean)
	local duration = between(W.RAIN_DURATION)
	local endsAt = os.clock() + duration
	publish("Rain", duration, storm)
	Ambience.setWeather(if storm then "Storm" else "Rain", W.RAIN_RAMP_IN)
	if storm then
		-- Thunder: the clients flash at ThunderAt (a little in the future, so the message
		-- reaches everyone before the moment comes and they all flash together).
		task.spawn(function()
			while true do
				task.wait(between(W.THUNDER_GAP))
				if os.clock() > endsAt - W.RAIN_RAMP_OUT then
					break
				end
				workspace:SetAttribute("ThunderAt", now() + 0.4)
			end
		end)
	end
	task.wait(duration - W.RAIN_RAMP_OUT)
	-- The rain fades out: the sky clears while the last drops fall.
	Ambience.setWeather("Clear", W.RAIN_RAMP_OUT)
	task.wait(W.RAIN_RAMP_OUT)
	publish("Clear", 0, false)
end

local function runFog()
	local duration = between(W.FOG_DURATION)
	publish("Fog", duration, false)
	Ambience.setWeather("Fog", W.FOG_RAMP)
	task.wait(duration - W.FOG_RAMP)
	Ambience.setWeather("Clear", W.FOG_RAMP)
	task.wait(W.FOG_RAMP)
	publish("Clear", 0, false)
end

local function runPowerCut()
	lastPowerCutNight = Ambience.getNightNumber()
	local total = W.POWER_FLICKER + W.POWER_DARK + W.POWER_WARMUP
	publish("PowerCut", total, false)
	Ambience.powerFlicker(W.POWER_FLICKER)
	Ambience.cutPower()
	task.wait(W.POWER_DARK)
	Ambience.restorePower(W.SUBSTATION, W.POWER_WAVE_SPEED, W.POWER_WARMUP)
	publish("Clear", 0, false)
end

local function run(kind: string)
	if kind == "Rain" then
		runRain(random:NextNumber() < W.STORM_CHANCE)
	elseif kind == "Storm" then
		runRain(true)
	elseif kind == "Fog" then
		runFog()
	elseif kind == "PowerCut" then
		runPowerCut()
	end
end

------------------------------------------------------------------------------
-- The director: rolls the dice, runs one event, waits, again
------------------------------------------------------------------------------

-- Can a power cut happen right now? (Night, enough night left, none yet tonight.)
local function powerCutAllowed(): boolean
	local phase, left = Ambience.getPhase()
	return phase == "Night"
		and left >= W.POWER_MIN_NIGHT_LEFT
		and lastPowerCutNight ~= Ambience.getNightNumber()
end

-- Picks "Rain", "Fog", "PowerCut" or "Nothing" with the weights of Config.
local function pick(): string
	local phase = Ambience.getPhase()
	local night = phase == "Night"
	local weights: { [string]: number } = if night
		then W.WEIGHTS_NIGHT :: any
		else W.WEIGHTS_DAY :: any
	local total = 0
	local choices: { { kind: string, weight: number } } = {}
	for kind, weight in weights do
		local choice = { kind = kind, weight = weight }
		if kind ~= "PowerCut" or powerCutAllowed() then
			total += weight
			table.insert(choices, choice)
		end
	end
	local roll = random:NextNumber(0, total)
	for _, choice in choices do
		roll -= choice.weight
		if roll <= 0 then
			return choice.kind
		end
	end
	return "Nothing"
end

local function director()
	calmWait(if fast then 20 else between(W.FIRST_EVENT))
	while true do
		local kind = forced or pick()
		forced = nil
		if kind == "Nothing" then
			calmWait(W.RETRY)
		else
			run(kind)
			calmWait(if fast then 45 else between(W.GAP))
		end
	end
end

function Weather.start()
	publish("Clear", 0, false)
	task.spawn(director)
	-- Studio only: workspace:SetAttribute("WeatherForce", "Rain") in the command bar starts
	-- that event as soon as the current one (if any) is over.
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("WeatherForce"):Connect(function()
			local kind = workspace:GetAttribute("WeatherForce")
			if typeof(kind) == "string" and kind ~= "" then
				forced = kind
				workspace:SetAttribute("WeatherForce", nil)
			end
		end)
	end
end

return Weather
