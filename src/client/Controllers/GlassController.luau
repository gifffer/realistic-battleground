--!strict
-- GlassController: the city's window glass, on this screen.
--
-- Server/Systems/CityGlass already made the panes glass for everyone (tag "CityGlass",
-- attribute GlassKind "Clear" / "Dark"). This adds what depends on each player:
--   • DIRT: a faint film of dust, dried water marks and a darker rim on the panes near you
--     (a Decal stretched over the face: glass_dirt_wide / glass_dirt_tall).
--   • RAIN ON THE GLASS: while it rains (WeatherController.rainState), the nearest panes
--     that are open to the sky get wet: beads appear little by little (glass_rain_beads) and
--     drops run down slowly (glass_rain_runs, a Texture scrolled down). It follows the rain
--     event: wet over WET_TIME once the rain starts, runs only while it falls, dries over
--     DRY_TIME after. A pane under an awning or a roof stays dry. On a see-through pane the
--     beads are drawn on both faces, so you see them from inside too.
--   • PLAIN FALLBACK for see-through panes: on low graphics quality (Glass nearly vanishes
--     there), and while the camera is inside (on high quality Roblox draws no rain, beams
--     or signs behind Glass, so the street would look dry and dark through the shop window).
-- All of it is local (nothing new on the server) and every overlay is tagged
-- "GlassOverlay" (Shared/Util/Breakable ignores it, so breaking still works the same).
-- Images: Config.Glass.IMAGES (0 = not uploaded: that layer is not drawn).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local CityZones = require(ReplicatedStorage.Shared.Util.CityZones)
local WeatherController = require(script.Parent.WeatherController)

local G = Config.Glass

local GlassController = {}

local TAG = "CityGlass"
local OVERLAY_TAG = "GlassOverlay"
local REASSIGN_EVERY = 0.5 -- s: which panes get dirt / rain
local PROBES_PER_PASS = 24 -- panes whose sides we look at, per pass
local FRAME_EVERY = 1 / 30 -- s: the running drops move at 30 Hz

type Side = {
	face: Enum.NormalId,
	open: boolean, -- not against a wall
	rain: boolean, -- open to the sky: gets wet
}

type Pane = {
	part: BasePart,
	kind: string,
	vertical: boolean,
	aspect: number, -- width / height of the big face
	seed: number,
	sides: { Side }?, -- nil until probed
	rainFaces: { Enum.NormalId },
	dirt: { Decal },
	beads: { Texture },
	runs: { Texture },
	plain: boolean?, -- nil: not applied yet
}

local panes: { [BasePart]: Pane } = {}
local list: { Pane } = {}
local tier = "medium"
local wet = 0 -- 0 dry → 1 soaked (all panes share it)
local runFlow = 0 -- 0 → 1: how much water runs down right now
local runOffset = 0
local inside = false

------------------------------------------------------------------------------
-- Faces
------------------------------------------------------------------------------

local function image(id: number): string?
	return if id ~= 0 then `rbxassetid://{id}` else nil
end

-- The two big faces of a thin pane, and its width / height seen face on.
local function faces(part: BasePart): ({ Enum.NormalId }, number, number, boolean)
	local size = part.Size
	if size.X <= size.Y and size.X <= size.Z then
		local vertical = math.abs(part.CFrame.RightVector.Y) < 0.5
		return { Enum.NormalId.Right, Enum.NormalId.Left }, size.Z, size.Y, vertical
	elseif size.Z <= size.Y then
		local vertical = math.abs(part.CFrame.LookVector.Y) < 0.5
		return { Enum.NormalId.Front, Enum.NormalId.Back }, size.X, size.Y, vertical
	end
	local vertical = math.abs(part.CFrame.UpVector.Y) < 0.5
	return { Enum.NormalId.Top, Enum.NormalId.Bottom }, size.X, size.Z, vertical
end

local probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Exclude
probeParams.RespectCanCollide = true
probeParams.IgnoreWater = true

-- Looks at both sides of the pane once: which one has a wall right behind it, which one
-- the sky can rain on.
local function probe(pane: Pane)
	local part = pane.part
	local exclude: { Instance } = { part }
	for _, fighter in CollectionService:GetTagged(Config.Combat.TAG) do
		table.insert(exclude, fighter)
	end
	probeParams.FilterDescendantsInstances = exclude
	local list2, _, height = faces(part)
	local sides: { Side } = {}
	local thin = math.min(part.Size.X, part.Size.Y, part.Size.Z)
	for _, face in list2 do
		local normal = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face))
		local from = part.Position + normal * (thin / 2 + 0.02)
		local hit = workspace:Raycast(from, normal * 14, probeParams)
		local distance = if hit then hit.Distance else 14
		local open = distance > 1
		local rain = false
		if open then
			if pane.vertical then
				-- the sky above the street in front of the pane
				local above = part.Position + normal * 1.2 + Vector3.new(0, height / 2 + 0.2, 0)
				rain = distance >= 4
					and workspace:Raycast(above, Vector3.new(0, 80, 0), probeParams) == nil
			else
				rain = normal.Y > 0.5
					and workspace:Raycast(from, Vector3.new(0, 80, 0), probeParams) == nil
			end
		end
		table.insert(sides, { face = face, open = open, rain = rain })
	end
	pane.sides = sides
	-- Where the rain shows: the wet faces, plus the other open face of a see-through pane
	-- (seen from inside).
	local wetSomewhere = false
	for _, side in sides do
		if side.rain then
			wetSomewhere = true
		end
	end
	table.clear(pane.rainFaces)
	if wetSomewhere then
		for _, side in sides do
			if side.rain or (pane.kind == "Clear" and side.open) then
				table.insert(pane.rainFaces, side.face)
			end
		end
	end
end

local function broken(part: BasePart): boolean
	return part:GetAttribute("Broken") == true or part.Transparency >= 0.99
end

local function overlay(className: string, part: BasePart, face: Enum.NormalId): Instance
	local instance = Instance.new(className)
	CollectionService:AddTag(instance, OVERLAY_TAG);
	(instance :: any).Face = face;
	(instance :: any).Transparency = 1
	instance.Parent = part
	return instance
end

local function clear(items: { any })
	for _, item in items do
		item:Destroy()
	end
	table.clear(items)
end

------------------------------------------------------------------------------
-- Layers
------------------------------------------------------------------------------

local function setDirt(pane: Pane, on: boolean)
	local wide = pane.aspect >= 1.2
	local texture = image(if wide then G.IMAGES.dirtWide else G.IMAGES.dirtTall)
	-- (very long strips would stretch the picture: no dirt on them)
	local fits = pane.aspect <= 3.5 and pane.aspect >= 0.3
	if not on or texture == nil or not fits or pane.sides == nil or broken(pane.part) then
		clear(pane.dirt)
		return
	end
	if #pane.dirt > 0 then
		return
	end
	for _, side in pane.sides :: { Side } do
		if side.open then
			local decal = overlay("Decal", pane.part, side.face) :: Decal
			decal.Texture = texture :: string
			decal.Transparency = G.DIRT_TRANSPARENCY
			table.insert(pane.dirt, decal)
		end
	end
end

local function setRain(pane: Pane, on: boolean)
	local beadsImage = image(G.IMAGES.rainBeads)
	local runsImage = image(G.IMAGES.rainRuns)
	if not on or #pane.rainFaces == 0 or broken(pane.part) then
		clear(pane.beads)
		clear(pane.runs)
		return
	end
	if #pane.beads > 0 or #pane.runs > 0 then
		return
	end
	local random = Random.new(pane.seed)
	for _, face in pane.rainFaces do
		if beadsImage then
			local beads = overlay("Texture", pane.part, face) :: Texture
			beads.Texture = beadsImage
			beads.StudsPerTileU = G.BEADS_TILE
			beads.StudsPerTileV = G.BEADS_TILE
			beads.OffsetStudsU = random:NextNumber(0, G.BEADS_TILE)
			beads.OffsetStudsV = random:NextNumber(0, G.BEADS_TILE)
			table.insert(pane.beads, beads)
		end
		-- (water doesn't run down a flat skylight)
		if runsImage and pane.vertical then
			local runs = overlay("Texture", pane.part, face) :: Texture
			runs.Texture = runsImage
			runs.StudsPerTileU = G.RUNS_TILE.X
			runs.StudsPerTileV = G.RUNS_TILE.Y
			runs.OffsetStudsU = random:NextNumber(0, G.RUNS_TILE.X)
			runs:SetAttribute("Shift", random:NextNumber(0, G.RUNS_TILE.Y))
			table.insert(pane.runs, runs)
		end
	end
end

-- See-through panes: the engine's Glass, or the plain look (low quality / seen from inside).
local function setPlain(pane: Pane, plain: boolean)
	if pane.kind ~= "Clear" or pane.plain == plain or broken(pane.part) then
		return
	end
	pane.plain = plain
	local part = pane.part
	if plain then
		part.Material = Enum.Material.SmoothPlastic
		part.Color = G.PLAIN_COLOR
		part.Transparency = G.PLAIN_TRANSPARENCY
		part.Reflectance = G.PLAIN_REFLECTANCE
	else
		part.Material = Enum.Material.Glass
		part.Color = G.CLEAR_COLOR
		part.Transparency = G.CLEAR_TRANSPARENCY
		part.Reflectance = G.CLEAR_REFLECTANCE
	end
end

------------------------------------------------------------------------------
-- Panes coming and going (StreamingEnabled may stream them)
------------------------------------------------------------------------------

local function add(instance: Instance)
	if not instance:IsA("BasePart") or panes[instance] then
		return
	end
	local kind = instance:GetAttribute("GlassKind")
	if typeof(kind) ~= "string" then
		return
	end
	local _, width, height, vertical = faces(instance)
	local position = instance.Position
	local pane: Pane = {
		part = instance,
		kind = kind,
		vertical = vertical,
		aspect = width / math.max(height, 0.01),
		seed = math.floor(position.X * 7 + position.Y * 131 + position.Z * 1031),
		sides = nil,
		rainFaces = {},
		dirt = {},
		beads = {},
		runs = {},
		plain = nil,
	}
	panes[instance] = pane
	table.insert(list, pane)
	-- Broken (Server/Systems/Destruction hides it) or back: drop the layers, the next pass
	-- puts them back, and the plain look is applied again.
	instance:GetAttributeChangedSignal("Broken"):Connect(function()
		clear(pane.dirt)
		clear(pane.beads)
		clear(pane.runs)
		pane.plain = nil
	end)
end

local function remove(instance: Instance)
	local pane = if instance:IsA("BasePart") then panes[instance] else nil
	if pane == nil then
		return
	end
	panes[instance :: BasePart] = nil
	local index = table.find(list, pane)
	if index then
		list[index] = list[#list]
		list[#list] = nil
	end
	clear(pane.dirt)
	clear(pane.beads)
	clear(pane.runs)
end

------------------------------------------------------------------------------
-- Every half second: which panes get what
------------------------------------------------------------------------------

local function readQuality()
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	local value = if ok then level.Value else 0
	-- (Automatic can't be read by a game: counted as medium)
	if value >= 1 and value <= 3 then
		tier = "low"
	elseif value >= 8 then
		tier = "high"
	else
		tier = "medium"
	end
	if
		tier == "high"
		and UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
	then
		tier = "medium" -- phones and tablets
	end
end

local function cameraInside(position: Vector3): boolean
	local _, _, _, indoors = WeatherController.rainState()
	if indoors then
		return true
	end
	local zone = CityZones.musicZoneAt(position)
	return zone ~= nil and zone ~= "Park"
end

local byDistance: { { pane: Pane, distance: number } } = {}

local function reassign()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local eye = camera.CFrame.Position
	inside = cameraInside(eye)
	local plain = tier == "low" or inside
	local dirtRange = G.DIRT_RANGE[tier] or 0
	local rainRange = G.RAIN_RANGE[tier] or 0
	local maxRain = G.RAIN_PANES[tier] or 0
	local raining = wet > 0.001
	local probes = 0
	table.clear(byDistance)
	for _, pane in list do
		if pane.part.Parent == nil then
			continue
		end
		local distance = (pane.part.Position - eye).Magnitude
		if
			pane.sides == nil
			and distance <= math.max(dirtRange, rainRange) + 20
			and probes < PROBES_PER_PASS
		then
			probes += 1
			probe(pane)
		end
		setPlain(pane, plain)
		setDirt(pane, distance <= dirtRange)
		if raining and distance <= rainRange and #pane.rainFaces > 0 then
			table.insert(byDistance, { pane = pane, distance = distance })
		else
			setRain(pane, false)
		end
	end
	table.sort(byDistance, function(a, b)
		return a.distance < b.distance
	end)
	for index, entry in byDistance do
		setRain(entry.pane, index <= maxRain)
	end
end

------------------------------------------------------------------------------
-- Every frame (30 Hz): the water on the glass
------------------------------------------------------------------------------

local sinceFrame = 0
local sinceAssign = 0

local function update(deltaTime: number)
	sinceAssign += deltaTime
	if sinceAssign >= REASSIGN_EVERY then
		sinceAssign = 0
		reassign()
	end
	sinceFrame += deltaTime
	if sinceFrame < FRAME_EVERY then
		return
	end
	local dt = sinceFrame
	sinceFrame = 0
	local intensity, storm = WeatherController.rainState()
	-- The glass gets wet slowly, and dries slowly once the rain stops.
	if intensity > wet then
		wet = math.min(intensity, wet + dt / G.WET_TIME)
	else
		wet = math.max(intensity, wet - dt / G.DRY_TIME)
	end
	-- Drops only run while it really rains (they stop soon after).
	local flowTarget = math.min(1, intensity * 1.5) * wet
	runFlow += (flowTarget - runFlow) * math.min(1, dt * 0.5)
	if wet <= 0.001 and runFlow <= 0.001 then
		return
	end
	local speed = G.RUN_SPEED * (if storm then G.STORM_RUN else 1) * (0.4 + 0.6 * intensity)
	runOffset = (runOffset + speed * dt * G.RUN_DIRECTION) % G.RUNS_TILE.Y
	local beadsTransparency = 1 - 0.92 * wet ^ 0.7
	local runsTransparency = 1 - 0.8 * runFlow
	for _, entry in byDistance do
		local pane = entry.pane
		for _, beads in pane.beads do
			beads.Transparency = beadsTransparency
		end
		for _, runs in pane.runs do
			runs.Transparency = runsTransparency
			if tier ~= "low" then
				local shift = runs:GetAttribute("Shift")
				runs.OffsetStudsV = runOffset + (if typeof(shift) == "number" then shift else 0)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function GlassController.start()
	readQuality()
	task.spawn(function()
		while true do
			task.wait(5)
			readQuality()
		end
	end)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, instance in CollectionService:GetTagged(TAG) do
		add(instance)
	end
	RunService.Heartbeat:Connect(update)
end

return GlassController
