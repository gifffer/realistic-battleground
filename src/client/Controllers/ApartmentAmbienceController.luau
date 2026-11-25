--!strict
-- ApartmentAmbienceController: the MOOD of your flat (Flat 4B) and its hidden lab: sounds,
-- dust, vapour, drips, flickering bulbs, swaying plastic. Client only, cosmetic only (no
-- remote, the server never waits on it).
--
-- It wakes up when ApartmentController says you ARRIVED in your flat and stops everything
-- when you LEFT (nothing runs, nothing is left behind, its Heartbeat is disconnected).
--
--   Sounds   Contraband/AptAudio: 2D beds crossfaded by room, 3D loops on the model's "Sfx"
--            host parts (fridges, the tube buzz, the vat, the pumps, the neighbours behind the
--            wall), 3D one-shots (doors, drips, creaks, the spark), wall muffling, reverb.
--   VFX      Contraband/AptFx: particle emitters on the model's "Fx" host parts, the swinging
--            entry pendant + its moth, the box fan, the swaying sheets, the strip curtain, a
--            fly by the sink, the lab CRT's culture graph, the charger LED's idle colour.
--   Lights   the "Flicker" attribute of the model's "Fixtures": "Bulb" (the corridor bulb),
--            "Tube" (the lab tube: short stutters only, never while you extract), "Rare" (the
--            bathroom), "Toggle" (the light under Bed 3's door). Seeded per player, sampled at
--            30 Hz; never more than 3 flashes per second (photosensitivity).
--
-- CULLING (roblox-vfx): only the effects of your room and its neighbours run (ACTIVE below);
-- the others are disabled and cleared. ≤ 6 continuous emitters enabled at once. Low graphics
-- quality: half the dust motes, no floor haze.
--
-- If the server model lacks a host part (Fx / Sfx), an invisible client part is made at the
-- place written in AptFx.HOSTS / SFX_HOSTS below, so nothing is silent by accident.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Contraband = script.Parent.Parent.Contraband
local AptAudio = require(Contraband.AptAudio)
local AptFx = require(Contraband.AptFx)
local ApartmentController = require(script.Parent.ApartmentController)
local LabController = require(script.Parent.LabController)

local ApartmentAmbienceController = {}

local player = Players.LocalPlayer

------------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------------

-- Which rooms' effects run while you stand in a room (your room + the ones you can see into).
local ACTIVE: { [string]: { [string]: boolean } } = {
	Entry = { Entry = true, Living = true, Corridor = true },
	Living = { Living = true, Entry = true },
	Corridor = { Corridor = true, Entry = true, Bath = true, Bed2 = true },
	Bath = { Bath = true, Corridor = true },
	Bed2 = { Bed2 = true, Corridor = true },
	Lab = { Lab = true, Corridor = true },
}
local MAX_EMITTERS = 6 -- continuous emitters enabled at once
-- Emitters that keep running first when the budget is full (most visible first).
local PRIORITY = {
	"Vapour_LabDoor",
	"Motes_Corridor",
	"Motes_Entry",
	"Bubbles_Tank",
	"Mist_Freezer",
	"Motes_Lamp",
	"Motes_LabDoor",
	"Motes_Bend",
	"Breath_Floor",
}
local MOTES = {
	Motes_Entry = true,
	Motes_Corridor = true,
	Motes_Bend = true,
	Motes_LabDoor = true,
	Motes_Lamp = true,
}

-- The 3D sound hosts (DESIGN §5.3). The server model's "Sfx/<name>" part is used when it is
-- there (its attributes Slot / Zone / Min / Max win); otherwise a client part at `at`.
type SfxSpec = {
	name: string,
	slot: string,
	zone: string,
	at: Vector3, -- flat-local
	min: number,
	max: number,
	volume: number,
	pitch: number,
	loop: boolean,
}
local SFX_HOSTS: { SfxSpec } = {
	-- (the neighbours' party, heard through the entry's east wall: always muffled)
	{
		name = "Neighbours",
		slot = "AptNeighbours",
		zone = "Neighbour",
		at = Vector3.new(0, 5, -19),
		min = 4,
		max = 30,
		volume = 1,
		pitch = 1,
		loop = true,
	},
	{
		name = "KitchenFridge",
		slot = "LabFridgeHum",
		zone = "Living",
		at = Vector3.new(-17.5, 1, -6.4),
		min = 3,
		max = 18,
		volume = 0.8,
		pitch = 1,
		loop = true,
	},
	{
		name = "CorridorBulb",
		slot = "LabFluoBuzz",
		zone = "Corridor",
		at = Vector3.new(-9, 10.2, -1),
		min = 2,
		max = 12,
		volume = 0.35,
		pitch = 1,
		loop = true,
	},
	-- (the vat: heard from far, muffled, from the corridor's bend: a breadcrumb)
	{
		name = "VatHum",
		slot = "VatHum",
		zone = "Lab",
		at = Vector3.new(20, 1, 19.5),
		min = 5,
		max = 40,
		volume = 1,
		pitch = 1,
		loop = true,
	},
	{
		name = "TubeBuzz",
		slot = "LabFluoBuzz",
		zone = "Lab",
		at = Vector3.new(18, 9.8, 13),
		min = 3,
		max = 16,
		volume = 1,
		pitch = 1,
		loop = true,
	},
	{
		name = "LabFridge",
		slot = "LabFridgeHum",
		zone = "Lab",
		at = Vector3.new(14.5, 1, 22.8),
		min = 3,
		max = 18,
		volume = 1,
		pitch = 1,
		loop = true,
	},
	{
		name = "FreezerHum",
		slot = "LabFridgeHum",
		zone = "Lab",
		at = Vector3.new(11.8, 0.8, 21.3),
		min = 3,
		max = 14,
		volume = 0.7,
		pitch = 0.85,
		loop = true,
	},
	{
		name = "Pumps",
		slot = "LabPumpBubble",
		zone = "Lab",
		at = Vector3.new(25.8, 3.6, 22.6),
		min = 3,
		max = 18,
		volume = 1,
		pitch = 1,
		loop = true,
	},
	-- one-shot places
	{
		name = "BathTap",
		slot = "LabDrip",
		zone = "Bath",
		at = Vector3.new(-15, 3, 3.5),
		min = 2,
		max = 14,
		volume = 0.6,
		pitch = 1,
		loop = false,
	},
	{
		name = "CorridorDrip",
		slot = "LabDrip",
		zone = "Corridor",
		at = Vector3.new(-8.4, 0.8, 5.2),
		min = 2,
		max = 16,
		volume = 1,
		pitch = 1,
		loop = false,
	},
	{
		name = "LabDripPan",
		slot = "LabDrip",
		zone = "Lab",
		at = Vector3.new(25, 0.3, 21),
		min = 2,
		max = 14,
		volume = 0.7,
		pitch = 1,
		loop = false,
	},
	{
		name = "Spark",
		slot = "LabSpark",
		zone = "Lab",
		at = Vector3.new(27.45, 1.25, 15),
		min = 2,
		max = 16,
		volume = 1,
		pitch = 1,
		loop = false,
	},
	{
		name = "MonitorBeep",
		slot = "VatReadyChime",
		zone = "Lab",
		at = Vector3.new(26.9, 4.55, 17),
		min = 3,
		max = 20,
		volume = 1,
		pitch = 1,
		loop = false,
	},
}

-- The room of a fixture that has no "Zone" attribute.
local FIXTURE_ZONE: { [string]: string } = {
	CorridorBulb = "Corridor",
	BendBulb = "Corridor",
	BathMirror = "Bath",
	BathSpill = "Bath",
	TubeLight = "Lab",
	Bed3DoorLine = "Bed3",
	FridgeLight = "Living",
	LabDoorGlow = "Corridor",
	MonitorGlow = "Lab",
}
-- Fixtures that copy another one's flicker.
local FOLLOWS: { [string]: string } = { BathSpill = "BathMirror" }
-- Which 3D loop's volume follows which light (a dying bulb stops buzzing).
local BUZZ_OF: { [string]: string } = { CorridorBulb = "CorridorBulb", TubeLight = "TubeBuzz" }

local FLICKER_RATE = 1 / 30 -- seconds between two flicker samples
local MIN_FLASH_GAP = 0.34 -- seconds between two dips of one light (≤ 3 per second)
local DOOR_OPEN = 60 -- degrees: the lab door counts as open past this
local REVEAL_GAP = 300 -- seconds: the lab reveal drone never plays twice within this
local CHARGER_IDLE = Color3.fromRGB(72, 132, 72) -- (120, 220, 120) at 60 % brightness

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

type Segment = { at: number, duration: number, level: number }

type Fixture = {
	name: string,
	instance: Instance,
	mode: string,
	zone: string,
	position: Vector3,
	lights: { { light: Light, brightness: number } },
	parts: { { part: BasePart, color: Color3, material: Enum.Material, transparency: number } },
	level: number, -- the multiplier shown now (1 = as built)
	applied: number, -- the last level written to the instances
	segments: { Segment }, -- the current flicker event
	nextEvent: number,
	toggleOn: boolean,
}

type Emitter = {
	name: string,
	emitter: ParticleEmitter,
	zone: string,
	continuous: boolean,
	baseRate: number,
}

type Drip = {
	drop: ParticleEmitter,
	splash: ParticleEmitter,
	land: Vector3,
	fall: number,
	zone: string,
	soundHost: string,
	ringSize: number,
	gap: NumberRange,
	nextAt: number,
}

local active = false
local flat: Model? = nil
local origin = CFrame.identity
local now = 0 -- seconds since arrival (our own clock)
local rng = Random.new()
local folder: Folder? = nil
local room: string? = nil
local extracting = false
local labDoorOpen = false
local lowQuality = false
local fridgeOpen = false
local heartbeat: RBXScriptConnection? = nil
local watchers: { RBXScriptConnection } = {}

local emitters: { [string]: Emitter } = {}
local madeEmitters: { ParticleEmitter } = {}
local hosts: { [string]: BasePart } = {}
local sfxHosts: { [string]: { part: BasePart, spec: SfxSpec } } = {}
local fixtures: { [string]: Fixture } = {}
local drips: { Drip } = {}

local pendant: AptFx.Swinger? = nil
local pendantBulb: BasePart? = nil
local moth: AptFx.Moth? = nil
local fan: AptFx.Rig? = nil
local sheets: { AptFx.Rig } = {}
local curtain: AptFx.Curtain? = nil
local curtainAt: Vector3? = nil
local fly: AptFx.Fly? = nil
local monitor: AptFx.Monitor? = nil
local monitorGlow = 1
local charger: BasePart? = nil
local chargerColor: Color3? = nil
local labDoor: Model? = nil

local flickerTimer = 0
local slowTimer = 0
local monitorTimer = 0
local nextSpark = 0
local nextBathTap = 0
local nextCreak = 0
local lastCreakAt = -math.huge
local walked = 0
local walkNeed = 3
local lastRoot: Vector3? = nil
local revealPlayed = false
local lastRevealAt = -math.huge -- os.clock()
local lastStage: string? = nil
local lastProgress = 0
local lastStashKey: string? = nil
local averageFrame = 1 / 60 -- seconds per frame, smoothed (for the Automatic quality)

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function zoneActive(zone: string): boolean
	local set = if room then ACTIVE[room] else nil
	if set == nil then
		return zone == "Entry" -- (before the first room is known: we just arrived)
	end
	return set[zone] == true
end

local function local3(at: Vector3): Vector3
	return (origin * CFrame.new(at)).Position
end

local function findPart(parent: Instance?, name: string): BasePart?
	local found = if parent then parent:FindFirstChild(name) else nil
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local function stringAttribute(instance: Instance, name: string, default: string): string
	local value = instance:GetAttribute(name)
	return if typeof(value) == "string" then value else default
end

local function numberAttribute(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function sfxPart(name: string): BasePart?
	local entry = sfxHosts[name]
	return if entry then entry.part else nil
end

-- A 3D one-shot at an Sfx host (its zone / distances / volume from its spec).
local function playHost(name: string, volumeScale: number?, pitchScale: number?)
	local entry = sfxHosts[name]
	if entry == nil then
		return
	end
	local spec = entry.spec
	AptAudio.playAt(
		stringAttribute(entry.part, "Slot", spec.slot),
		entry.part,
		stringAttribute(entry.part, "Zone", spec.zone),
		numberAttribute(entry.part, "Min", spec.min),
		numberAttribute(entry.part, "Max", spec.max),
		numberAttribute(entry.part, "Volume", spec.volume) * (volumeScale or 1),
		numberAttribute(entry.part, "Pitch", spec.pitch) * (pitchScale or 1)
	)
end

------------------------------------------------------------------------------
-- Emitters and culling
------------------------------------------------------------------------------

-- Enables the emitters of the active rooms (within the budget), disables + clears the others.
local function refreshEmitters()
	local enabled = 0
	for _, name in PRIORITY do
		local entry = emitters[name]
		if entry == nil or not entry.continuous then
			continue
		end
		-- (no draught under an open door, no specks in the extraction close-up, no floor haze
		-- on low quality, and never more than the budget)
		local blocked = (name == "Vapour_LabDoor" and labDoorOpen)
			or (name == "Motes_Lamp" and extracting)
			or (name == "Breath_Floor" and lowQuality)
		local want = zoneActive(entry.zone) and not blocked and enabled < MAX_EMITTERS
		if want then
			enabled += 1
			local rate = entry.baseRate * (if lowQuality and MOTES[name] then 0.5 else 1)
			entry.emitter.Rate = rate
			if not entry.emitter.Enabled then
				entry.emitter.Enabled = true
			end
		elseif entry.emitter.Enabled then
			entry.emitter.Enabled = false
			entry.emitter:Clear()
		end
	end
end

local function buildEmitters(model: Model, parent: Folder)
	local fxFolder = model:FindFirstChild("Fx")
	for _, spec in AptFx.HOSTS do
		local host = findPart(fxFolder, spec.name) or AptFx.makeHost(spec, origin, parent)
		hosts[spec.name] = host
		local zone = stringAttribute(host, "Zone", spec.zone)
		local fall: number? = nil
		local land: Vector3? = nil
		if spec.landY then
			-- (the server's "LandAt" attribute = where the drop lands, else our own height)
			local landAt = host:GetAttribute("LandAt")
			local landing = if typeof(landAt) == "Vector3"
				then landAt
				else Vector3.new(
					host.Position.X,
					origin.Position.Y + spec.landY,
					host.Position.Z
				)
			land = landing
			fall = AptFx.fallTime(host.Position.Y - landing.Y)
		end
		local emitter = AptFx.emitter(spec.name, host, fall)
		if emitter == nil then
			continue
		end
		table.insert(madeEmitters, emitter)
		local rate = numberAttribute(emitter, "BaseRate", 0)
		emitters[spec.name] = {
			name = spec.name,
			emitter = emitter,
			zone = zone,
			continuous = rate > 0,
			baseRate = rate,
		}
		if land and fall then
			local corridor = spec.name == "Drip_Corridor"
			table.insert(drips, {
				drop = emitter,
				splash = AptFx.splash(land, parent),
				land = land,
				fall = fall,
				zone = zone,
				soundHost = if corridor then "CorridorDrip" else "LabDripPan",
				ringSize = if corridor then 0.9 else 0.6,
				gap = if corridor then NumberRange.new(3, 9) else NumberRange.new(7, 14),
				nextAt = rng:NextNumber(1, 4),
			})
		end
	end
end

------------------------------------------------------------------------------
-- Lights: flicker
------------------------------------------------------------------------------

local function newFixture(name: string, instance: Instance): Fixture
	local lights = {}
	local parts = {}
	local function addPart(part: BasePart)
		if part.Material == Enum.Material.Neon or part.Transparency > 0.5 then
			table.insert(parts, {
				part = part,
				color = part.Color,
				material = part.Material,
				transparency = part.Transparency,
			})
		end
	end
	if instance:IsA("BasePart") then
		addPart(instance)
	end
	for _, child in instance:GetDescendants() do
		if child:IsA("Light") then
			table.insert(lights, { light = child, brightness = child.Brightness })
		elseif child:IsA("BasePart") then
			addPart(child)
		end
	end
	local position = if instance:IsA("BasePart")
		then instance.Position
		elseif instance:IsA("Model") then instance:GetPivot().Position
		else origin.Position
	return {
		name = name,
		instance = instance,
		mode = stringAttribute(instance, "Flicker", "None"),
		zone = stringAttribute(instance, "Zone", FIXTURE_ZONE[name] or "Fixture"),
		position = position,
		lights = lights,
		parts = parts,
		level = 1,
		applied = 1,
		segments = {},
		nextEvent = 0,
		toggleOn = true,
	}
end

-- Writes `level` (0..1+) to the fixture's lights and glowing parts (only when it changed).
local function applyLevel(fixture: Fixture, level: number)
	if math.abs(level - fixture.applied) < 0.01 then
		return
	end
	fixture.applied = level
	for _, entry in fixture.lights do
		entry.light.Brightness = entry.brightness * level
		entry.light.Enabled = level > 0.001
	end
	for _, entry in fixture.parts do
		if entry.transparency > 0.5 then
			-- a see-through light wedge: fades out
			entry.part.Transparency = entry.transparency
				+ (1 - entry.transparency) * (1 - math.clamp(level, 0, 1))
		elseif level < 0.3 then
			-- a dead bulb is a dull grey glass, not a glowing ball
			entry.part.Material = Enum.Material.SmoothPlastic
			entry.part.Color = entry.color:Lerp(Color3.new(0, 0, 0), 0.65)
		else
			entry.part.Material = entry.material
			entry.part.Color = entry.color
		end
	end
end

local function restoreFixture(fixture: Fixture)
	fixture.applied = -1
	applyLevel(fixture, 1)
end

-- Plans the next flicker event of `fixture` (a list of dips), starting at `start`.
local function planEvent(fixture: Fixture, start: number, flickerRng: Random)
	local segments: { Segment } = {}
	local at = start
	if fixture.mode == "Bulb" then
		if flickerRng:NextInteger(1, 4) == 1 then
			-- a full cut, then a 2-tick restart
			local off = flickerRng:NextNumber(0.3, 1.2)
			table.insert(segments, { at = at, duration = off, level = 0 })
			at += off + 0.08
			table.insert(segments, { at = at, duration = 0.3, level = 0 })
			at += 0.38
			table.insert(segments, { at = at, duration = 0.3, level = 0.15 })
		else
			for _ = 1, flickerRng:NextInteger(2, 5) do
				table.insert(segments, {
					at = at,
					duration = flickerRng:NextNumber(0.04, 0.12),
					level = flickerRng:NextNumber(0.1, 0.4),
				})
				at += flickerRng:NextNumber(MIN_FLASH_GAP, 0.6)
			end
		end
	elseif fixture.mode == "Tube" then
		for _ = 1, flickerRng:NextInteger(2, 3) do
			table.insert(segments, {
				at = at,
				duration = flickerRng:NextNumber(0.06, 0.09),
				level = flickerRng:NextNumber(0.25, 0.5),
			})
			at += flickerRng:NextNumber(MIN_FLASH_GAP, 0.5)
		end
	elseif fixture.mode == "Rare" then
		for _ = 1, 2 do
			table.insert(
				segments,
				{ at = at, duration = flickerRng:NextNumber(0.05, 0.1), level = 0.3 }
			)
			at += flickerRng:NextNumber(MIN_FLASH_GAP, 0.5)
		end
	end
	fixture.segments = segments
	local last = segments[#segments]
	local finish = if last then last.at + last.duration else start
	local wait = if fixture.mode == "Bulb"
		then flickerRng:NextNumber(8, 25)
		elseif fixture.mode == "Tube" then flickerRng:NextNumber(45, 120)
		else flickerRng:NextNumber(50, 90)
	fixture.nextEvent = finish + wait
end

local flickerRng = Random.new()

-- One flicker sample (30 Hz) of every fixture.
local function stepLights()
	for name, fixture in fixtures do
		local level = 1
		local mode = fixture.mode
		if FOLLOWS[name] then
			local leader = fixtures[FOLLOWS[name]]
			level = if leader then leader.level else 1
		elseif name == "LabDoorGlow" then
			-- the cold line under the lab door fades out as the door opens (14° → 60°)
			local angle = if labDoor then math.abs(ApartmentController.doorAngle(labDoor)) else 14
			level = 1 - math.clamp((angle - 14) / (DOOR_OPEN - 14), 0, 1)
		elseif name == "FridgeLight" then
			level = if fridgeOpen then 1 else 0
		elseif name == "MonitorGlow" then
			level = monitorGlow
		elseif mode == "Toggle" then
			if now >= fixture.nextEvent then
				fixture.toggleOn = not fixture.toggleOn
				fixture.nextEvent = now
					+ (
						if fixture.toggleOn
							then flickerRng:NextNumber(20, 60)
							else flickerRng:NextNumber(10, 40)
					)
				AptAudio.playAt("LightSwitch", fixture.position, fixture.zone, 2, 14)
			end
			level = if fixture.toggleOn then 1 else 0
		elseif mode == "Bulb" or mode == "Tube" or mode == "Rare" then
			if now >= fixture.nextEvent then
				if mode == "Tube" and extracting then
					fixture.nextEvent = now + 5 -- (the work light stays steady while you extract)
				else
					planEvent(fixture, now, flickerRng)
				end
			end
			for _, segment in fixture.segments do
				if now >= segment.at and now < segment.at + segment.duration then
					level = segment.level
					break
				end
			end
			if mode == "Tube" and extracting then
				level = 1 -- (an event already started when you began: cut short)
			end
			-- a dip just started: the tick of the stuttering light (warm bulbs quieter)
			if level < 0.5 and fixture.level >= 0.5 then
				AptAudio.playAt(
					"LabFluoFlicker",
					fixture.position,
					fixture.zone,
					2,
					16,
					if mode == "Tube" then 1 else 0.6
				)
			end
			if mode == "Bulb" then
				-- mains noise: ±4 % at about 8 Hz
				level *= 1 + 0.04 * (0.6 * math.sin(now * 50.3) + 0.4 * math.sin(now * 33.1))
			end
		else
			continue
		end
		fixture.level = level
		applyLevel(fixture, level)
		local buzz = BUZZ_OF[name]
		if buzz then
			AptAudio.setLoopScale(buzz, math.clamp(level, 0, 1))
		end
	end
	-- the corridor's dust motes live in the bulb's light: they vanish when it dies
	local bulb = fixtures.CorridorBulb
	local motesEntry = emitters.Motes_Corridor
	if bulb and motesEntry and motesEntry.emitter.Enabled then
		local rate = motesEntry.baseRate
			* (if lowQuality then 0.5 else 1)
			* math.clamp(bulb.level, 0, 1)
		if math.abs(motesEntry.emitter.Rate - rate) > 0.05 then
			motesEntry.emitter.Rate = rate
		end
	end
end

local function buildFixtures(model: Model)
	local function add(name: string, instance: Instance?)
		if instance == nil or fixtures[name] then
			return
		end
		local fixture = newFixture(name, instance)
		local follows = instance:GetAttribute("Follows")
		if typeof(follows) == "string" then
			FOLLOWS[name] = follows
		end
		local special = FOLLOWS[name] ~= nil
			or name == "LabDoorGlow"
			or name == "FridgeLight"
			or name == "MonitorGlow"
		if fixture.mode == "None" and not special then
			return
		end
		-- (the first event of each light comes at a different moment)
		fixture.nextEvent = if fixture.mode == "Toggle"
			then flickerRng:NextNumber(5, 20)
			else flickerRng:NextNumber(3, 12)
		fixtures[name] = fixture
	end
	local folderOfFixtures = model:FindFirstChild("Fixtures")
	if folderOfFixtures then
		for _, child in folderOfFixtures:GetChildren() do
			add(child.Name, child)
		end
	end
	add("TubeLight", model:FindFirstChild("TubeLight"))
	-- (the monitor's glow is a SurfaceLight on the CRT glass: it wobbles with the screen)
	add("MonitorGlow", model:FindFirstChild("MonitorScreen"))
	if fixtures.FridgeLight then
		applyLevel(fixtures.FridgeLight, 0)
	end
end

------------------------------------------------------------------------------
-- Sounds
------------------------------------------------------------------------------

local function buildSounds(model: Model, parent: Folder)
	local sfxFolder = model:FindFirstChild("Sfx")
	for _, spec in SFX_HOSTS do
		local part = findPart(sfxFolder, spec.name)
		if part == nil then
			local made = Instance.new("Part")
			made.Name = spec.name
			made.Size = Vector3.new(0.2, 0.2, 0.2)
			made.CFrame = CFrame.new(local3(spec.at))
			made.Anchored = true
			made.CanCollide = false
			made.CanQuery = false
			made.CanTouch = false
			made.CastShadow = false
			made.Transparency = 1
			made.Parent = parent
			part = made
		end
		local host = part :: BasePart
		sfxHosts[spec.name] = { part = host, spec = spec }
		if spec.loop then
			AptAudio.addLoop(spec.name, host, {
				slot = stringAttribute(host, "Slot", spec.slot),
				zone = stringAttribute(host, "Zone", spec.zone),
				minDistance = numberAttribute(host, "Min", spec.min),
				maxDistance = numberAttribute(host, "Max", spec.max),
				volume = numberAttribute(host, "Volume", spec.volume),
				pitch = numberAttribute(host, "Pitch", spec.pitch),
			})
		end
	end
end

-- A per-door pitch (0.92 to 1.08), the same every time for one door.
local function doorPitch(door: Model): number
	local seed = player.UserId
	for index = 1, #door.Name do
		seed = (seed * 31 + string.byte(door.Name, index)) % 2147483647
	end
	return Random.new(seed):NextNumber(0.92, 1.08)
end

local function doorPoint(door: Model): Vector3
	return door:GetPivot().Position + Vector3.new(0, 3.5, 0)
end

local function onDoorOpened(door: Model)
	if not active then
		return
	end
	if door.Name == "Door_Fridge" then
		fridgeOpen = true
		AptAudio.playAt("FridgeOpen", doorPoint(door), room or "Living", 2, 16)
	else
		AptAudio.playAt(
			"AptDoorOpen",
			doorPoint(door),
			room or "Corridor",
			2,
			22,
			1,
			doorPitch(door)
		)
	end
end

local function onDoorClosed(door: Model)
	if not active then
		return
	end
	if door.Name == "Door_Fridge" then
		fridgeOpen = false
		AptAudio.playAt("FridgeClose", doorPoint(door), room or "Living", 2, 16)
	else
		AptAudio.playAt(
			"AptDoorClose",
			doorPoint(door),
			room or "Corridor",
			2,
			22,
			1,
			doorPitch(door)
		)
	end
end

local function onDoorTried(door: Model)
	if active then
		AptAudio.playAt(
			"AptDoorLocked",
			doorPoint(door),
			room or "Corridor",
			2,
			18,
			1,
			doorPitch(door)
		)
	end
end

------------------------------------------------------------------------------
-- Rooms
------------------------------------------------------------------------------

local function onRoom(newRoom: string?)
	if not active or newRoom == nil or newRoom == room then
		return
	end
	room = newRoom
	AptAudio.setRoom(newRoom)
	refreshEmitters()
	if newRoom == "Lab" and not revealPlayed and os.clock() - lastRevealAt >= REVEAL_GAP then
		revealPlayed = true
		lastRevealAt = os.clock()
		AptAudio.play2D("LabRevealDrone")
	end
end

------------------------------------------------------------------------------
-- The lab's state (stash changes, culture stages)
------------------------------------------------------------------------------

local function watchLab()
	local state = LabController.state()
	if state == nil then
		return
	end
	local kinds = if typeof(state.kinds) == "table" then state.kinds else {}
	local key = `{#state.bench}|` .. table.concat(kinds, ",")
	if lastStashKey ~= nil and key ~= lastStashKey and room == "Lab" then
		-- a capsule went in / out of the freezer: a burst of cold mist + the lid
		local mist = emitters.Mist_Freezer
		if mist then
			mist.emitter:Emit(15)
		end
		local freezer = sfxPart("FreezerHum") or hosts.Mist_Freezer
		if freezer then
			AptAudio.playAt("FreezerLidOpen", freezer, "Lab", 2, 16)
			task.delay(0.8, function()
				if active then
					AptAudio.playAt("FreezerLidClose", freezer, "Lab", 2, 16)
				end
			end)
		end
	end
	lastStashKey = key

	local stage = state.stage
	local progress = LabController.progress()
	if lastStage ~= nil then
		local surge = (lastStage == "Empty" and stage == "Growing")
			or (
				stage == "Growing"
				and lastStage == "Growing"
				and (
					(lastProgress < 0.25 and progress >= 0.25)
					or (lastProgress < 0.75 and progress >= 0.75)
				)
			)
		if surge then
			local vat = sfxPart("VatHum")
			if vat then
				AptAudio.playAt("VatBubbleSurge", vat, "Lab", 3, 24)
			end
		end
		if lastStage == "Growing" and stage == "Ready" then
			-- the culture is ready: two beeps at the CRT
			playHost("MonitorBeep")
			task.delay(0.25, function()
				if active then
					playHost("MonitorBeep")
				end
			end)
		end
	end
	lastStage = stage
	lastProgress = progress
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function checkQuality()
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	local low = false
	if ok and typeof(level) == "EnumItem" then
		if level == Enum.SavedQualitySetting.Automatic then
			low = averageFrame > 0.025 -- (Automatic: slower than 40 frames per second)
		else
			low = level.Value <= 3
		end
	end
	if low ~= lowQuality then
		lowQuality = low
		refreshEmitters()
	end
end

local function step(deltaTime: number)
	if not active then
		return
	end
	if ApartmentController.model() ~= flat then
		ApartmentAmbienceController.stopAll()
		return
	end
	now += deltaTime
	averageFrame += (deltaTime - averageFrame) * 0.05
	local root = rootPosition()
	local camera = workspace.CurrentCamera

	-- the lab door: open past 60° = no vapour, the lab heard almost clearly from the corridor
	local doorModel = labDoor
	local open = doorModel ~= nil and math.abs(ApartmentController.doorAngle(doorModel)) > DOOR_OPEN
	if open ~= labDoorOpen then
		labDoorOpen = open
		AptAudio.setLabDoorOpen(open)
		refreshEmitters()
	end

	-- lights (30 Hz)
	flickerTimer += deltaTime
	if flickerTimer >= FLICKER_RATE then
		flickerTimer = 0
		monitorGlow = 1 + 0.05 * math.sin(now * 2 * math.pi * 8)
		stepLights()
	end

	-- slow checks (4 Hz): the lab state, the graphics quality
	slowTimer += deltaTime
	if slowTimer >= 0.25 then
		slowTimer = 0
		watchLab()
		if math.floor(now / 2) ~= math.floor((now - 0.25) / 2) then
			checkQuality()
		end
	end

	-- drips: the drop falls, and lands (splash + ring + sound) exactly when it arrives
	for _, drip in drips do
		if now >= drip.nextAt then
			drip.nextAt = now + rng:NextNumber(drip.gap.Min, drip.gap.Max)
			if zoneActive(drip.zone) then
				drip.drop:Emit(1)
			end
			task.delay(drip.fall, function()
				if not active then
					return
				end
				if zoneActive(drip.zone) then
					drip.splash:Emit(3)
					local parent = folder
					if parent then
						AptFx.ring(drip.land, drip.ringSize, parent)
					end
				end
				playHost(drip.soundHost)
			end)
		end
	end

	-- the bathroom tap
	if now >= nextBathTap then
		nextBathTap = now + rng:NextNumber(4, 10)
		playHost("BathTap")
	end

	-- the rare spark of the scorched strip (never while you extract)
	if now >= nextSpark then
		if zoneActive("Lab") and not extracting then
			nextSpark = now + flickerRng:NextNumber(45, 120)
			local spark = emitters.Spark_Strip
			local host = hosts.Spark_Strip
			if spark and host then
				spark.emitter:Emit(4)
				AptFx.sparkFlash(host)
				playHost("Spark")
			end
		else
			nextSpark = now + rng:NextNumber(10, 30)
		end
	end

	-- building creaks somewhere in the ceiling (never twice within 10 s)
	if now >= nextCreak then
		nextCreak = now + rng:NextNumber(20, 45)
		if root and AptAudio.randomReady("AptBuildingCreak", 10) then
			for _ = 1, 10 do
				local point =
					local3(Vector3.new(rng:NextNumber(-28, 28), 10.5, rng:NextNumber(-24, 24)))
				if (point - root).Magnitude >= 8 then
					AptAudio.playAt("AptBuildingCreak", point, "Ceiling", 4, 40)
					break
				end
			end
		end
	end

	-- loose floorboards under your feet (corridor, cook's room, living room)
	if root then
		local previous = lastRoot
		if previous and (room == "Corridor" or room == "Bed2" or room == "Living") then
			local moved = Vector3.new(root.X - previous.X, 0, root.Z - previous.Z).Magnitude
			if moved < 5 then
				walked += moved
			end
			if walked >= walkNeed then
				walked = 0
				walkNeed = rng:NextNumber(2.5, 5)
				if rng:NextNumber() < 0.3 and now - lastCreakAt >= 2.5 then
					lastCreakAt = now
					AptAudio.playAt(
						"FloorCreak",
						Vector3.new(root.X, origin.Position.Y + 0.1, root.Z),
						room or "Corridor",
						2,
						20
					)
				end
			end
		end
		lastRoot = root
	end

	-- moving things (only in the active rooms)
	if pendant and zoneActive("Entry") then
		pendant.update(deltaTime)
	end
	local bulb = pendantBulb
	if moth and bulb then
		moth.update(deltaTime, bulb.Position, zoneActive("Entry"))
	end
	if zoneActive("Lab") then
		if fan then
			fan.update(deltaTime)
		end
		for _, sheet in sheets do
			sheet.update(deltaTime)
		end
		local monitorNow = monitor
		if monitorNow then
			monitorNow.update(deltaTime, monitorGlow)
			monitorTimer += deltaTime
			if monitorTimer >= 1 then
				monitorTimer = 0
				local state = LabController.state()
				monitorNow.draw(if state then state.stage else "Empty", LabController.progress())
			end
		end
	end
	local curtainNow = curtain
	if curtainNow and (zoneActive("Lab") or room == "Corridor") then
		local crossed = curtainNow.update(deltaTime, root)
		local at = curtainAt
		if crossed and at then
			AptAudio.playAt("PlasticSheetBrush", at, room or "Lab", 2, 16)
		end
	end
	if fly and camera and zoneActive("Living") then
		fly.update(deltaTime, camera.CFrame.Position)
	end

	AptAudio.update(deltaTime)
end

------------------------------------------------------------------------------
-- Arrive / leave
------------------------------------------------------------------------------

local function setChargerIdle()
	local led = charger
	if led and led:GetAttribute("Busy") ~= true then
		led.Color = CHARGER_IDLE
		led.Material = Enum.Material.Neon
	end
end

local function startAll(model: Model)
	if active then
		ApartmentAmbienceController.stopAll()
	end
	active = true
	flat = model
	now = 0
	room = nil
	revealPlayed = false
	lastStage = nil
	lastStashKey = nil
	fridgeOpen = false
	labDoorOpen = false
	extracting = player:GetAttribute("Extracting") == true
	rng = Random.new(player.UserId)
	flickerRng = Random.new(player.UserId + 7)
	nextSpark = flickerRng:NextNumber(30, 90)
	nextBathTap = rng:NextNumber(2, 6)
	nextCreak = rng:NextNumber(10, 25)

	-- the flat's frame: the floor-top centre (Floor is the PrimaryPart, its top at Y 0)
	local floor = model.PrimaryPart or findPart(model, "Floor")
	origin = if floor
		then CFrame.new(floor.Position + Vector3.new(0, floor.Size.Y / 2, 0))
		else CFrame.new(model:GetPivot().Position)

	local made = Instance.new("Folder")
	made.Name = "AptAmbience"
	made.Parent = workspace
	folder = made

	AptAudio.start()
	AptAudio.setExtracting(extracting)
	buildSounds(model, made)
	buildEmitters(model, made)
	buildFixtures(model)

	-- moving things (Anim folder, pivots set by the server builder)
	local anim = model:FindFirstChild("Anim")
	-- (in Anim as agreed; else anywhere in the model, by name)
	local function animModel(name: string): Instance?
		return (if anim then anim:FindFirstChild(name) else nil) or model:FindFirstChild(name, true)
	end
	local pendantModel = animModel("Pendant")
	if pendantModel and pendantModel:IsA("Model") then
		pendant = AptFx.swinger(pendantModel, Vector3.new(1, 0, 0))
		pendantBulb = findPart(pendantModel, "Bulb")
			or pendantModel:FindFirstChildWhichIsA("BasePart", true)
		moth = AptFx.moth(made)
	end
	local fanModel = animModel("FanBlades")
	if fanModel and fanModel:IsA("Model") then
		fan = AptFx.spinner(fanModel)
	end
	if anim then
		for index = 1, 8 do
			local sheet = anim:FindFirstChild(`Sheet_{index}`)
			if sheet and sheet:IsA("PVInstance") then
				table.insert(sheets, AptFx.sway(sheet, player.UserId + index * 13))
			end
		end
	end
	local curtainModel = animModel("Curtain")
	if curtainModel and curtainModel:IsA("Model") then
		curtain = AptFx.curtain(curtainModel)
		curtainAt = curtainModel:GetBoundingBox().Position
	end
	fly = AptFx.fly(local3(Vector3.new(-24, 4.5, -7.5)), made)

	local screen = findPart(model, "MonitorScreen")
	if screen then
		monitor = AptFx.monitor(screen)
	end
	charger = findPart(model, "ChargerLed")
	if charger then
		chargerColor = charger.Color
		setChargerIdle()
		table.insert(
			watchers,
			charger:GetAttributeChangedSignal("Busy"):Connect(function()
				task.defer(setChargerIdle) -- (after the extraction put its own colour back)
			end)
		)
	end
	local doors = model:FindFirstChild("Doors")
	local door = if doors then doors:FindFirstChild("Door_Lab") else nil
	labDoor = if door and door:IsA("Model") then door else nil

	table.insert(
		watchers,
		player:GetAttributeChangedSignal("Extracting"):Connect(function()
			extracting = player:GetAttribute("Extracting") == true
			AptAudio.setExtracting(extracting)
			refreshEmitters()
		end)
	)

	checkQuality()
	onRoom(ApartmentController.room())
	refreshEmitters()
	heartbeat = RunService.Heartbeat:Connect(step)

	-- the arrival beat: the key turns, the door shuts behind you, dust rolls in, the pendant
	-- swings and its shadows sway over the entry
	local exitDoor = findPart(model, "ExitDoor")
	if exitDoor then
		AptAudio.playAt("AptDoorUnlock", exitDoor, "Entry", 2, 20)
		task.delay(0.45, function()
			if active and flat == model then
				AptAudio.playAt("AptDoorClose", exitDoor, "Entry", 2, 22)
			end
		end)
	end
	task.delay(0.1, function()
		local dust = emitters.Dust_Threshold
		if active and flat == model and dust then
			dust.emitter:Emit(8)
		end
	end)
	if pendant then
		pendant.swing()
	end
end

-- Stops and removes everything (also called when the model disappears).
function ApartmentAmbienceController.stopAll()
	if not active then
		return
	end
	active = false
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	for _, connection in watchers do
		connection:Disconnect()
	end
	table.clear(watchers)
	for _, emitter in madeEmitters do
		emitter.Enabled = false
		emitter:Clear()
		emitter:Destroy()
	end
	table.clear(madeEmitters)
	table.clear(emitters)
	table.clear(hosts)
	table.clear(sfxHosts)
	table.clear(drips)
	for _, fixture in fixtures do
		restoreFixture(fixture)
	end
	table.clear(fixtures)
	if pendant then
		pendant.reset()
	end
	if fan then
		fan.reset()
	end
	for _, sheet in sheets do
		sheet.reset()
	end
	table.clear(sheets)
	if curtain then
		curtain.reset()
	end
	if moth then
		moth.destroy()
	end
	if fly then
		fly.destroy()
	end
	if monitor then
		monitor.destroy()
	end
	if charger and chargerColor and charger:GetAttribute("Busy") ~= true then
		charger.Color = chargerColor
	end
	pendant, pendantBulb, moth, fan, curtain, curtainAt, fly, monitor =
		nil, nil, nil, nil, nil, nil, nil, nil
	charger, chargerColor, labDoor = nil, nil, nil
	AptAudio.stop()
	if folder then
		folder:Destroy()
		folder = nil
	end
	flat = nil
	room = nil
	lastRoot = nil
end

function ApartmentAmbienceController.start()
	ApartmentController.arrived.connect(function(model: Model)
		startAll(model)
	end)
	ApartmentController.left.connect(function()
		ApartmentAmbienceController.stopAll()
	end)
	ApartmentController.roomChanged.connect(onRoom)
	ApartmentController.doorOpened.connect(onDoorOpened)
	ApartmentController.doorClosed.connect(onDoorClosed)
	ApartmentController.doorTried.connect(onDoorTried)
	-- (already in the flat when this starts: a respawn inside it)
	local model = ApartmentController.model()
	if model then
		startAll(model)
	end
end

return ApartmentAmbienceController
