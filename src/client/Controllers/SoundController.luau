--!strict
-- SoundController: plays the sound effects listed in Shared/Sounds.luau.
--
--   SoundController.play("Hit", someModel)
--
-- • Sounds are played in 3D on the model's HumanoidRootPart.
-- • A sound with several ids picks one at random, never the same twice in a
--   row; pitch and volume come from Shared/Sounds, with each id's own trim
--   (start, gain) and a little random pitch / volume.
-- • A sound with no id yet uses its `fallback` (with its OWN pitch / volume),
--   or is silently skipped: the game works before sounds are chosen.
-- • All ids are preloaded when the game starts, so the first punch isn't
--   silent while its sound downloads.
--
-- Movement sounds (slide, vault, mantle) are started here, for every player,
-- from the "MoveState" attribute the server sets. Combat sounds are started
-- by CombatController (yours, instantly) and CombatEffectsController
-- (everyone else, from the server's messages).

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

-- Beyond this distance (studs) a sound can't be heard at all.
local MAX_HEARING_DISTANCE = 90
-- A finished sound is removed after this long at least (seconds).
local MIN_LIFETIME = 3
-- Movement state → sound played when a player enters it.
local MOVE_STATE_SOUNDS: { [string]: string } = {
	Slide = "Slide",
	Vault = "Vault",
	Climb = "Mantle",
}

local SoundController = {}

local random = Random.new()
-- Last id played for each sound name (to avoid repeating it).
local lastPlayed: { [string]: number } = {}

local function assetUrl(id: number): string
	return `rbxassetid://{id}`
end

-- The ids to use for `name`: its own, or its fallback's while it has none.
local function resolveIds(name: string): { number }
	-- (a fallback can have its own fallback: followed, a few steps at most)
	local info: Sounds.SoundInfo? = Sounds[name]
	for _ = 1, 4 do
		if info == nil then
			return {}
		end
		if #info.ids > 0 then
			return info.ids
		end
		info = if info.fallback then Sounds[info.fallback] else nil
	end
	return {}
end

-- Random id, different from the last one played (when there's a choice).
local function pickId(name: string, ids: { number }): number
	local count = #ids
	local id = ids[random:NextInteger(1, count)]
	if count > 1 and id == lastPlayed[name] then
		id = ids[(table.find(ids, id) :: number) % count + 1]
	end
	lastPlayed[name] = id
	return id
end

-- Where `id` starts and how loud it plays: its own trim (Shared/Sounds
-- `trims`: its blank cut, its level matched to the other variants) and a
-- random ±`volumeVariation` dB. Capped at 10 (Roblox's maximum).
local function startAndVolume(info: Sounds.SoundInfo, id: number, scale: number): (number, number)
	local trim = if info.trims then info.trims[id] else nil
	local start = (if trim then trim.start else nil) or info.start or 0
	local gain = (if trim then trim.gain else nil) or 1
	local spread = info.volumeVariation or 0
	if spread > 0 then
		gain *= 10 ^ (random:NextNumber(-spread, spread) / 20)
	end
	return start, math.min(info.volume * gain * scale, 10)
end

-- A sound with a `length` (Shared/Sounds): faded out (over `fadeOut`) and stopped there.
local function cutShort(sound: Sound, length: number?, fade: number?)
	if length == nil then
		return
	end
	local time = fade or 0.15
	local steps = math.max(6, math.ceil(time / 0.03))
	task.delay(math.max(0, length - time * 0.5), function()
		if sound.Parent == nil then
			return
		end
		local start = sound.Volume
		for step = 1, steps do
			sound.Volume = start * (1 - step / steps) ^ 2
			task.wait(time / steps)
		end
		sound:Stop()
		sound:Destroy()
	end)
end

-- Returns the Sound (to stop it early), or nil if nothing played.
function SoundController.play(name: string, model: Model?): Sound?
	local info = Sounds[name]
	if info == nil then
		warn(`[SoundController] unknown sound "{name}" (see Shared/Sounds.luau)`)
		return nil
	end
	local ids = resolveIds(name)
	if #ids == 0 or model == nil then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	local id = pickId(name, ids)
	local start, volume = startAndVolume(info, id, 1)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = assetUrl(id)
	sound.Volume = volume
	sound.PlaybackSpeed = info.pitch
		* (1 + random:NextNumber(-info.pitchVariation, info.pitchVariation))
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = MAX_HEARING_DISTANCE
	sound.Parent = root
	sound.TimePosition = start
	sound:Play()
	cutShort(sound, info.length, info.fadeOut)
	-- Removed once finished (TimeLength is 0 until the file is loaded, hence
	-- the safe minimum).
	Debris:AddItem(sound, math.max(sound.TimeLength / sound.PlaybackSpeed, MIN_LIFETIME) + 0.5)
	return sound
end

-- A looping sound heard only by this player, not placed in the world (the
-- heartbeat when you're hurt...). Returns it stopped, volume from Sounds;
-- nil if the sound has no id yet. The caller plays / stops / fades it.
function SoundController.loop(name: string): Sound?
	local info = Sounds[name]
	if info == nil then
		warn(`[SoundController] unknown sound "{name}" (see Shared/Sounds.luau)`)
		return nil
	end
	local ids = resolveIds(name)
	if #ids == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = assetUrl(ids[1])
	sound.Volume = info.volume
	sound.PlaybackSpeed = info.pitch
	sound.Looped = true
	sound.Parent = game:GetService("SoundService")
	return sound
end

-- A one-shot sound heard by this player only, not placed in the world (thunder...).
-- `volumeScale` multiplies the volume from Sounds (default 1). Returns the Sound, or nil
-- if the sound has no id yet.
function SoundController.play2D(name: string, volumeScale: number?): Sound?
	local info = Sounds[name]
	if info == nil then
		warn(`[SoundController] unknown sound "{name}" (see Shared/Sounds.luau)`)
		return nil
	end
	local ids = resolveIds(name)
	if #ids == 0 then
		return nil
	end
	local id = pickId(name, ids)
	local start, volume = startAndVolume(info, id, volumeScale or 1)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = assetUrl(id)
	sound.Volume = volume
	sound.PlaybackSpeed = info.pitch
		* (1 + random:NextNumber(-info.pitchVariation, info.pitchVariation))
	sound.Parent = game:GetService("SoundService")
	sound.TimePosition = start
	sound:Play()
	cutShort(sound, info.length, info.fadeOut)
	Debris:AddItem(sound, math.max(sound.TimeLength / sound.PlaybackSpeed, 12) + 0.5)
	return sound
end

-- A one-shot sound IN 3D at a point of the world (not on a character): a flask bursting,
-- a portal, the train hitting someone, a can falling... `parent` = a part to play it from instead (it then follows that
-- part: a body flying away). `maxDistance` = beyond this it can't be heard (default 90).
-- Returns the Sound, or nil if the sound has no id yet.
function SoundController.playAt(
	name: string,
	position: Vector3,
	maxDistance: number?,
	parent: BasePart?
): Sound?
	local info = Sounds[name]
	if info == nil then
		warn(`[SoundController] unknown sound "{name}" (see Shared/Sounds.luau)`)
		return nil
	end
	local ids = resolveIds(name)
	if #ids == 0 then
		return nil
	end
	-- Without a part: an invisible attachment of the terrain, at that point.
	local holder: Instance
	local anchor: Attachment? = nil
	if parent then
		holder = parent
	else
		local attachment = Instance.new("Attachment")
		attachment.Name = name .. "_At"
		attachment.WorldPosition = position
		attachment.Parent = workspace.Terrain
		holder = attachment
		anchor = attachment
	end
	local id = pickId(name, ids)
	local start, volume = startAndVolume(info, id, 1)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = assetUrl(id)
	sound.Volume = volume
	sound.PlaybackSpeed = info.pitch
		* (1 + random:NextNumber(-info.pitchVariation, info.pitchVariation))
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = maxDistance or MAX_HEARING_DISTANCE
	sound.Parent = holder
	sound.TimePosition = start
	sound:Play()
	cutShort(sound, info.length, info.fadeOut)
	local lifetime = math.max(sound.TimeLength / sound.PlaybackSpeed, 8) + 0.5
	Debris:AddItem(anchor or sound, lifetime)
	return sound
end

-- Downloads every sound in the background at startup.
local function preloadAll()
	local urls: { any } = {}
	for _, info in Sounds do
		-- (music is long: it downloads when it starts, not all at once at startup)
		if info.music == true then
			continue
		end
		for _, id in info.ids do
			table.insert(urls, assetUrl(id))
		end
	end
	if #urls > 0 then
		-- pcall: a deleted / private sound must not stop the others.
		pcall(function()
			ContentProvider:PreloadAsync(urls)
		end)
	end
end

local function watchPlayer(owner: Player)
	owner:GetAttributeChangedSignal("MoveState"):Connect(function()
		local state = owner:GetAttribute("MoveState")
		local soundName = if typeof(state) == "string" then MOVE_STATE_SOUNDS[state] else nil
		if soundName then
			SoundController.play(soundName, owner.Character)
		end
	end)
end

function SoundController.start()
	task.spawn(preloadAll)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, owner in Players:GetPlayers() do
		watchPlayer(owner)
	end
end

return SoundController
