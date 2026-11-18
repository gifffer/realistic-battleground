--!strict
-- Sfx: the sounds of the autopsy video, local only. Every id is a public
-- Creator Store audio checked with the toolbox API (type 3 = Audio).
--
--   Sfx.play(name, at?)     one sound (at a part or a point; else 2D)
--   Sfx.loop(name)          a looping sound (stopped by the caller)
--   Sfx.setRetro(on)        the pixel mode's old-school filter on / off

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

type Info = {
	ids: { number },
	volume: number,
	pitch: number?,
	vary: number?, -- pitch variation (+-)
	slice: number?, -- play only this many seconds (from a random start)
}

local SOUNDS: { [string]: Info } = {
	-- "scalpel cut"; "DI_Knife_Standard_Slash_Flesh_01/02/03"
	Cut = {
		ids = { 138772034497598, 72475389234606, 100089328974443, 132661033625159 },
		volume = 0.7,
		vary = 0.08,
	},
	-- "Knife Slicing Flesh Stabbing Many Rapid Chop" (a deep cut)
	DeepCut = { ids = { 9125619646 }, volume = 0.6, vary = 0.05, slice = 0.8 },
	-- "Web Release Wet Smack Sticky 1/2"; "gloopy oil splat, slippery squelch"
	Spread = { ids = { 9120627864, 9120627902, 71972357334329 }, volume = 0.7, vary = 0.1 },
	-- "universfield wet squelch impact"
	Squelch = { ids = { 94238955194144 }, volume = 0.6, vary = 0.1 },
	-- "Gmod Flesh Sound" (the game's FleshTear); "Small rip"
	Tear = { ids = { 111650608703379, 93104442035829 }, volume = 0.9, vary = 0.08 },
	-- "Stomach Guts SFX"
	Guts = { ids = { 102880398452107 }, volume = 0.8, vary = 0.05, slice = 2 },
	-- "flesh hit sound 2" (the game's OrganDrop); "The Meat Slap"
	Drop = { ids = { 135119591308242, 2053476174 }, volume = 0.8, vary = 0.1 },
	-- "sfx_hit_bone_break02" (RibCrack); "Squishy Bone Cracks 10"
	Crack = { ids = { 121666760679562, 9119560180 }, volume = 1, vary = 0.05 },
	-- "sawing through bones in medical emergency"
	Saw = { ids = { 120267343553145 }, volume = 0.8 },
	-- "Blood Drips 1/2/4"
	Drip = { ids = { 9113464190, 9113464198, 9113463758 }, volume = 0.25, vary = 0.1 },
	-- "Fluorescent Light Hum (LOOPS)"
	Hum = { ids = { 4227579935 }, volume = 0.25 },
	-- "Bubble Wrap Light Crinkling Plastic 1/2" (a short random slice)
	Plastic = { ids = { 9113606679, 9113606680 }, volume = 0.45, slice = 1.5 },
	-- "Metal Tray 1/2"
	Tray = { ids = { 9116902317, 9116902704 }, volume = 0.5, vary = 0.06 },
}

local Sfx = {}

local random = Random.new()

local group = Instance.new("SoundGroup")
group.Name = "AutopsySfx"
group.Volume = 1
group.Parent = SoundService
-- (the pixel mode's old-school sound: a bit lower, duller)
local pitchFx = Instance.new("PitchShiftSoundEffect")
pitchFx.Octave = 0.95
pitchFx.Enabled = false
pitchFx.Parent = group
local eqFx = Instance.new("EqualizerSoundEffect")
eqFx.HighGain = -6
eqFx.MidGain = 1
eqFx.LowGain = 1
eqFx.Enabled = false
eqFx.Parent = group

local function make(name: string): (Sound?, Info?)
	local info = SOUNDS[name]
	if info == nil then
		warn(`[Autopsy] unknown sound {name}`)
		return nil, nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Autopsy" .. name
	sound.SoundId = `rbxassetid://{info.ids[random:NextInteger(1, #info.ids)]}`
	sound.Volume = info.volume
	local vary = info.vary or 0
	sound.PlaybackSpeed = (info.pitch or 1) * (1 + random:NextNumber(-vary, vary))
	sound.SoundGroup = group
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 60
	return sound, info
end

-- One sound, at a part or a point (heard from the camera), else 2D.
function Sfx.play(name: string, at: (BasePart | Vector3)?): Sound?
	local sound, info = make(name)
	if sound == nil or info == nil then
		return nil
	end
	local holder: Instance = SoundService
	if typeof(at) == "Instance" then
		holder = at
	elseif typeof(at) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.Parent = workspace.Terrain
		attachment.WorldPosition = at
		Debris:AddItem(attachment, 8)
		holder = attachment
	end
	sound.Parent = holder
	if info.slice then
		-- (a random slice of a long file, once its length is known)
		local length = sound.TimeLength
		if length > info.slice * 1.5 then
			sound.TimePosition = random:NextNumber(0, length - info.slice)
		end
		task.delay(info.slice, function()
			if sound.Parent then
				sound:Stop()
				sound:Destroy()
			end
		end)
	end
	sound:Play()
	Debris:AddItem(sound, 8)
	return sound
end

-- A looping sound, playing, 2D; the caller stops / destroys it.
function Sfx.loop(name: string): Sound?
	local sound = make(name)
	if sound == nil then
		return nil
	end
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
	return sound
end

function Sfx.setRetro(on: boolean)
	pitchFx.Enabled = on
	eqFx.Enabled = on
end

return Sfx
