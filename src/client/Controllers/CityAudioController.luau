--!strict
-- CityAudioController: the sound of the city, mixed like a real street.
--
-- THREE LAYERS, all on this screen only (each player hears from where THEIR camera is):
--
--   1. THE OUTDOOR BED (2D, everywhere outside): a day track and a night track
--      (Shared/Sounds: MusicOutsideDay / MusicOutsideNight), crossfaded with the server's
--      day / night cycle (Lighting.ClockTime as the server has it, see
--      ParkAtmosphereController.serverClockTime). Ducked when you are inside the bar or a
--      shop, silent in the park and in a duel.
--
--   2. THE RAIN (2D), MIXED ON TOP of the outdoor bed, never instead of it: Rain, or the
--      louder Storm loop in a thunderstorm. Its volume follows the rain as WeatherController
--      sees it (fades in / out with the event), lower under a roof and inside, silent in the
--      park (always sunny there).
--
--   3. THE PLACES' MUSIC (3D): every part tagged "Speaker" (the speaker boxes on the walls of
--      Duffy's bar, THREADBARE, REWIND, and in the hidden park) gets a Sound. All the speakers
--      of a place play the same playlist (MusicBar, MusicThreads, MusicRewind, MusicPark), in
--      sync: the song and the moment in it come from the server's clock
--      (workspace:GetServerTimeNow()), so every player hears the same song at the same moment
--      and a player who walks in later joins it where it is.
--        • You start to hear a place 40 to 70 studs away, louder as you come closer.
--        • From OUTSIDE its zone (the invisible box tagged "MusicZone" with the same Zone
--          name) it is MUFFLED: an equalizer cuts the highs, like music through a wall.
--          Inside, it is clear.
--        • Far from a place (out of earshot) its speakers are stopped: nothing plays for
--          nothing.
--
-- FOG: while it lasts, the outdoor bed and the rain are slightly MUFFLED (an equalizer cuts
-- some highs, like sound swallowed by the damp air), following WeatherController.fogIntensity().
--
-- The MUSIC setting (Settings window, SOUND) turns the music (layers 1 and 3) off; the rain,
-- the train and the fights are not music and are never cut.
--
-- How a playlist is kept in sync: the length of each track is only known once its file is
-- loaded (Sound.TimeLength). Each length is measured once, then (total = sum of the lengths)
-- position = (server time + the zone's offset) % total gives the track and the moment in it.
-- Every 0.5 s each audible place is checked: wrong track → switch; more than 1.5 s off → jump
-- to the right moment. When a track ends the next check starts the next one.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local CityZones = require(ReplicatedStorage.Shared.Util.CityZones)
local ParkAtmosphereController = require(script.Parent.ParkAtmosphereController)
local WeatherController = require(script.Parent.WeatherController)

local CityAudioController = {}

local player = Players.LocalPlayer

------------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------------

local SPEAKER_TAG = "Speaker"

-- Each place: its playlist (a slot of Shared/Sounds), how far it carries (studs: full volume
-- up to `near`, nothing beyond `far`), and a shift of its playlist clock (so two places
-- sharing a song don't play it at the same moment).
type ZoneInfo = { slot: string, near: number, far: number, clockShift: number }
local ZONES: { [string]: ZoneInfo } = {
	Bar = { slot = "MusicBar", near = 9, far = 60, clockShift = 0 },
	Threads = { slot = "MusicThreads", near = 7, far = 46, clockShift = 1000 },
	Rewind = { slot = "MusicRewind", near = 7, far = 46, clockShift = 2000 },
	Park = { slot = "MusicPark", near = 14, far = 70, clockShift = 3000 },
}

-- Heard from outside the place: a bit quieter, and muffled (equalizer gains, in dB).
local OUTSIDE_GAIN = 0.8
local MUFFLED_HIGH = -32
local MUFFLED_MID = -9
local MUFFLED_LOW = 2
-- A place with several speakers: each one a bit quieter (they add up inside).
local MULTI_SPEAKER_GAIN = 0.75

-- The outdoor bed and the rain, inside the bar / a shop (× their volume).
local INDOOR_BED = 0.3
local INDOOR_RAIN = 0.3
-- Rain under a roof outside (an awning, the viaduct).
local COVERED_RAIN = 0.6

-- Fog: equalizer gains (dB) at full fog on the outdoor bed and the rain.
local FOG_HIGH = -12
local FOG_MID = -3

-- How fast the volumes follow (seconds to go all the way).
local FADE_TIME = 1.2
-- Seconds between two playlist checks, and the drift allowed before jumping.
local SYNC_EVERY = 0.5
local MAX_DRIFT = 1.5
-- Seconds between two "where is the camera" tests.
local ZONE_CHECK_EVERY = 0.2
-- A track whose length could not be measured (did not load in time) counts as this long.
local FALLBACK_LENGTH = 150
local LOAD_TIMEOUT = 25

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

type Speaker = {
	part: BasePart,
	sound: Sound,
	eq: EqualizerSoundEffect,
}
type Zone = {
	name: string,
	info: ZoneInfo,
	slot: Sounds.SoundInfo,
	speakers: { Speaker },
	inside: number, -- 0 (outside its box) → 1 (inside), smoothed
	audible: boolean,
	trackId: number?,
}

local zones: { [string]: Zone } = {}
local speakerOf: { [BasePart]: Speaker } = {}

-- Track lengths (seconds) by id, once measured.
local lengths: { [number]: number } = {}
local measuring: { [number]: boolean } = {}

local dayBed: Sound? = nil
local nightBed: Sound? = nil
local rainLoop: Sound? = nil

-- Music volume (the MUSIC setting): 0 = off, 1 = on. Faded.
local musicTarget = 1
local musicLevel = 1
-- Smoothed: 1 while the camera is inside the bar / a shop (not the park).
local indoorLevel = 0
-- The zone the camera is in ("Bar"... or nil).
local cameraZone: string? = nil
local nextZoneCheck = 0
local nextSync = 0

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function assetUrl(id: number): string
	return `rbxassetid://{id}`
end

-- Moves `current` toward `target` by at most `deltaTime / FADE_TIME`.
local function approach(current: number, target: number, deltaTime: number): number
	local step = deltaTime / FADE_TIME
	if current < target then
		return math.min(target, current + step)
	end
	return math.max(target, current - step)
end

-- A looping 2D sound from a slot (nil if it has no id yet).
local function bed(slotName: string): Sound?
	local info = Sounds[slotName]
	if info == nil or #info.ids == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = slotName
	sound.SoundId = assetUrl(info.ids[1])
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = info.pitch
	-- (an equalizer, flat by default: the fog muffles it)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "Fog"
	eq.HighGain = 0
	eq.MidGain = 0
	eq.LowGain = 0
	eq.Parent = sound
	sound.Parent = SoundService
	return sound
end

-- The fog muffling last applied to the beds (0 = none).
local appliedFog = 0

-- The fog's muffling on one 2D bed (0 = clear → 1 = full fog).
local function setFogMuffle(sound: Sound?, fog: number)
	local eq = if sound then sound:FindFirstChild("Fog") else nil
	if eq and eq:IsA("EqualizerSoundEffect") then
		eq.HighGain = FOG_HIGH * fog
		eq.MidGain = FOG_MID * fog
	end
end

-- Plays `sound` at `volume`, and stops it when it is silent (saves a voice).
local function setBedVolume(sound: Sound?, volume: number)
	if sound == nil then
		return
	end
	sound.Volume = volume
	if volume > 0.002 then
		if not sound.IsPlaying then
			sound:Play()
		end
	elseif sound.IsPlaying then
		sound:Stop()
	end
end

-- Measures how long track `id` is (once, in the background).
local function measure(id: number)
	if lengths[id] or measuring[id] then
		return
	end
	measuring[id] = true
	task.spawn(function()
		local probe = Instance.new("Sound")
		probe.Name = "MusicLengthProbe"
		probe.SoundId = assetUrl(id)
		probe.Volume = 0
		probe.Parent = SoundService
		local deadline = os.clock() + LOAD_TIMEOUT
		while not probe.IsLoaded and os.clock() < deadline do
			task.wait(0.25)
		end
		lengths[id] = if probe.IsLoaded and probe.TimeLength > 1
			then probe.TimeLength
			else FALLBACK_LENGTH
		probe:Destroy()
	end)
end

-- The track of `zone` playing now and the moment in it, or nil while lengths are unknown.
local function playlistNow(zone: Zone): (number?, number)
	local ids = zone.slot.ids
	local total = 0
	for _, id in ids do
		local length = lengths[id]
		if length == nil then
			measure(id)
			return nil, 0
		end
		total += length
	end
	if total <= 0 then
		return nil, 0
	end
	local position = (workspace:GetServerTimeNow() + zone.info.clockShift) % total
	for _, id in ids do
		local length = lengths[id] :: number
		if position < length then
			return id, position
		end
		position -= length
	end
	return ids[1], 0
end

------------------------------------------------------------------------------
-- Speakers
------------------------------------------------------------------------------

local function zoneNamed(name: string): Zone?
	local existing = zones[name]
	if existing then
		return existing
	end
	local info = ZONES[name]
	local slot = if info then Sounds[info.slot] else nil
	if info == nil or slot == nil or #slot.ids == 0 then
		return nil
	end
	local zone: Zone = {
		name = name,
		info = info,
		slot = slot,
		speakers = {},
		inside = 0,
		audible = false,
		trackId = nil,
	}
	zones[name] = zone
	return zone
end

local function addSpeaker(instance: Instance)
	if not instance:IsA("BasePart") or speakerOf[instance] then
		return
	end
	local zoneName = instance:GetAttribute("Zone")
	local zone = if typeof(zoneName) == "string" then zoneNamed(zoneName) else nil
	if zone == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "ZoneMusic"
	sound.Volume = 0
	sound.Looped = false
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = zone.info.near
	sound.RollOffMaxDistance = zone.info.far
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "Walls"
	eq.HighGain = MUFFLED_HIGH
	eq.MidGain = MUFFLED_MID
	eq.LowGain = MUFFLED_LOW
	eq.Parent = sound
	sound.Parent = instance
	local speaker: Speaker = { part = instance, sound = sound, eq = eq }
	speakerOf[instance] = speaker
	table.insert(zone.speakers, speaker)
	-- (preparing: the lengths of its playlist)
	for _, id in zone.slot.ids do
		measure(id)
	end
end

local function removeSpeaker(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local speaker = speakerOf[instance]
	if speaker == nil then
		return
	end
	speakerOf[instance] = nil
	speaker.sound:Destroy()
	for _, zone in zones do
		local index = table.find(zone.speakers, speaker)
		if index then
			table.remove(zone.speakers, index)
		end
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

-- Can the camera hear `zone` at all (inside it, or close to one of its speakers)?
local function canHear(zone: Zone, listener: Vector3): boolean
	if cameraZone == zone.name then
		return true
	end
	local reach = zone.info.far + 10
	for _, speaker in zone.speakers do
		if (speaker.part.Position - listener).Magnitude < reach then
			return true
		end
	end
	return false
end

-- Every SYNC_EVERY: the right track at the right moment on every audible speaker.
local function syncZone(zone: Zone, listener: Vector3)
	zone.audible = #zone.speakers > 0 and canHear(zone, listener) and musicTarget > 0
	if not zone.audible then
		for _, speaker in zone.speakers do
			if speaker.sound.IsPlaying then
				speaker.sound:Stop()
			end
		end
		return
	end
	local id, position = playlistNow(zone)
	if id == nil then
		return -- lengths still being measured
	end
	zone.trackId = id
	local url = assetUrl(id)
	for _, speaker in zone.speakers do
		local sound = speaker.sound
		if sound.SoundId ~= url then
			sound.SoundId = url
			sound.TimePosition = position
			sound:Play()
		elseif not sound.IsPlaying then
			sound.TimePosition = position
			sound:Play()
		elseif sound.IsLoaded and math.abs(sound.TimePosition - position) > MAX_DRIFT then
			sound.TimePosition = position
		end
	end
end

-- Every frame: the volumes and the muffling of one place.
local function mixZone(zone: Zone, deltaTime: number)
	local target = if cameraZone == zone.name then 1 else 0
	-- the park's box is a ParkZone (its MusicZone may be missing): count it too
	if zone.name == "Park" and ParkAtmosphereController.inPark() then
		target = 1
	end
	zone.inside = approach(zone.inside, target, deltaTime * 1.5)
	if not zone.audible then
		return
	end
	local trackGain = 1
	local perTrack = zone.slot.trackVolumes
	if perTrack and zone.trackId then
		trackGain = perTrack[zone.trackId] or 1
	end
	local spread = if #zone.speakers > 1 then MULTI_SPEAKER_GAIN else 1
	local inside = zone.inside
	local volume = zone.slot.volume
		* trackGain
		* spread
		* musicLevel
		* (OUTSIDE_GAIN + (1 - OUTSIDE_GAIN) * inside)
	for _, speaker in zone.speakers do
		speaker.sound.Volume = volume
		speaker.eq.HighGain = MUFFLED_HIGH * (1 - inside)
		speaker.eq.MidGain = MUFFLED_MID * (1 - inside)
		speaker.eq.LowGain = MUFFLED_LOW * (1 - inside)
	end
end

-- 0 (afternoon) → 1 (night), from the server's clock (the sun moves during dusk / dawn).
local function nightness(): number
	local clock = ParkAtmosphereController.serverClockTime()
	if clock < 6 then
		return 1
	end
	return math.clamp((clock - 17.6) / (21 - 17.6), 0, 1)
end

local function update(deltaTime: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local listener = camera.CFrame.Position
	local now = os.clock()
	if now >= nextZoneCheck then
		nextZoneCheck = now + ZONE_CHECK_EVERY
		cameraZone = CityZones.musicZoneAt(listener)
	end
	musicLevel = approach(musicLevel, musicTarget, deltaTime)
	local inside = cameraZone ~= nil and cameraZone ~= "Park"
	indoorLevel = approach(indoorLevel, if inside then 1 else 0, deltaTime)
	local park = ParkAtmosphereController.blend()
	local inDuel = player:GetAttribute("InDuel") == true

	-- 1. the outdoor bed
	local night = nightness()
	local bedGain = musicLevel
		* (1 - (1 - INDOOR_BED) * indoorLevel)
		* (1 - park)
		* (if inDuel then 0 else 1)
	setBedVolume(dayBed, Sounds.MusicOutsideDay.volume * (1 - night) * bedGain)
	setBedVolume(nightBed, Sounds.MusicOutsideNight.volume * night * bedGain)

	-- 2. the rain, on top
	local intensity, storm, covered, underCeiling = WeatherController.rainState()
	local rainSlot = if storm then Sounds.Storm else Sounds.Rain
	local shelter = if inside or underCeiling
		then INDOOR_RAIN
		elseif covered then COVERED_RAIN
		else 1
	shelter = math.min(shelter, 1 - (1 - INDOOR_RAIN) * indoorLevel)
	local rain = rainLoop
	if rain then
		-- (Rain and Storm share one recording today; if they ever differ, switch the file)
		local rainUrl = if #rainSlot.ids > 0 then assetUrl(rainSlot.ids[1]) else rain.SoundId
		if rain.SoundId ~= rainUrl then
			rain.SoundId = rainUrl
		end
		rain.PlaybackSpeed = rainSlot.pitch
		setBedVolume(
			rain,
			rainSlot.volume * intensity * shelter * (1 - park) * (if inDuel then 0 else 1)
		)
	end

	-- the fog muffles the outdoor bed and the rain (not in the park: always sunny there)
	-- (only when it changed: no lookups every frame on a clear day)
	local fog = WeatherController.fogIntensity() * (1 - park)
	if math.abs(fog - appliedFog) > 0.005 or (fog == 0 and appliedFog ~= 0) then
		appliedFog = fog
		setFogMuffle(dayBed, fog)
		setFogMuffle(nightBed, fog)
		setFogMuffle(rainLoop, fog)
	end

	-- 3. the places
	if now >= nextSync then
		nextSync = now + SYNC_EVERY
		for _, zone in zones do
			syncZone(zone, listener)
		end
	end
	for _, zone in zones do
		mixZone(zone, deltaTime)
	end
end

------------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------------

-- The MUSIC setting: false = no music (the outdoor beds and the places), faded out.
function CityAudioController.setMusicEnabled(enabled: boolean)
	musicTarget = if enabled then 1 else 0
end

function CityAudioController.isMusicEnabled(): boolean
	return musicTarget > 0
end

function CityAudioController.start()
	dayBed = bed("MusicOutsideDay")
	nightBed = bed("MusicOutsideNight")
	-- (one rain loop: the Rain and Storm slots share the recording; volume / pitch switch)
	rainLoop = bed("Rain")

	CollectionService:GetInstanceAddedSignal(SPEAKER_TAG):Connect(addSpeaker)
	CollectionService:GetInstanceRemovedSignal(SPEAKER_TAG):Connect(removeSpeaker)
	for _, instance in CollectionService:GetTagged(SPEAKER_TAG) do
		addSpeaker(instance)
	end
	RunService.Heartbeat:Connect(update)
end

return CityAudioController
