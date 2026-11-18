--!strict
-- Vfx/Limb: effects that follow a fighter's limbs or body.
--
--   Limb.part(model, limb)         the BasePart that strikes ("Prop" = the held prop)
--   Limb.tip(model, limb)          fist / foot / forehead / prop tip (this client's pose)
--   Limb.trailOn / trailOff        a faint air trail on the fist / foot (the swing)
--   Limb.trailWindow(model, limb, fromNow, toNow, opts)  on → off, scheduled
--   Limb.smear(model, limb, opts)  ghost limbs at the poses 1 and 2 frames ago
--   Limb.afterimage(model, opts)   a fading ghost of the whole body (slip, dodge, dash)
--   Limb.speedLines(model, seconds, opts)  thin lines streaming past the body
--   Limb.scrape(model, seconds)    floor dust off the feet while sliding
--   Limb.glint(model, limb)        a 1-frame tiny flash on a prop's tip
--   Limb.track(model, on)          record the limbs' CFrames (needed by smear)
--
-- Trails are always :Clear()ed before they turn on (otherwise a streak is
-- drawn from where the fist was last time) and only run on the FAST part
-- of a blow, never the wind-up.

local Players = game:GetService("Players")

local Floor = require(script.Parent.Floor)
local Layers = require(script.Parent.Layers)
local Palette = require(script.Parent.Palette)
local Pool = require(script.Parent.Pool)
local Quality = require(script.Parent.Quality)
local Types = require(script.Parent.Types)

type Limb = Types.Limb

local Limb = {}

local K = NumberSequenceKeypoint.new
local random = Random.new()
local player = Players.LocalPlayer

local PART_OF: { [string]: string } = {
	RightArm = "Right Arm",
	LeftArm = "Left Arm",
	RightLeg = "Right Leg",
	LeftLeg = "Left Leg",
	Head = "Head",
	Torso = "Torso",
	BothArms = "Right Arm",
}
local PROPS = { "Bottle", "BrokenBottle", "Bat", "Bone" }
local BODY_PARTS = { "Head", "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

local function basePart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- The held prop's model (Bottle, BrokenBottle, Bat, Bone), if any.
local function propModel(model: Model): Model?
	for _, name in PROPS do
		local prop = model:FindFirstChild(name)
		if prop and prop:IsA("Model") then
			return prop
		end
	end
	return nil
end

-- The prop's part farthest from the right hand (its tip).
local function propTip(model: Model): BasePart?
	local prop = propModel(model)
	local hand = basePart(model, "Right Arm")
	if prop == nil then
		return nil
	end
	local grip = if hand
		then (hand.CFrame * CFrame.new(0, -1, 0)).Position
		else prop:GetPivot().Position
	local best: BasePart? = nil
	local bestDistance = -1
	for _, child in prop:GetDescendants() do
		if child:IsA("BasePart") then
			local distance = (child.Position - grip).Magnitude
			if distance > bestDistance then
				best, bestDistance = child, distance
			end
		end
	end
	return best
end

function Limb.part(model: Model, limb: Limb): BasePart?
	if limb == "Prop" then
		return propTip(model)
	end
	local name = PART_OF[limb]
	return if name then basePart(model, name) else nil
end

-- Where the limb strikes from, on the pose drawn on THIS client.
function Limb.tip(model: Model, limb: Limb): Vector3?
	if limb == "BothArms" then
		local right = basePart(model, "Right Arm")
		local left = basePart(model, "Left Arm")
		if right and left then
			return (
				(right.CFrame * CFrame.new(0, -1, 0)).Position
				+ (left.CFrame * CFrame.new(0, -1, 0)).Position
			) / 2
		end
	end
	local part = Limb.part(model, limb)
	if part == nil then
		return nil
	end
	if limb == "Head" or limb == "Torso" then
		return (part.CFrame * CFrame.new(0, 0, -part.Size.Z / 2)).Position -- (forehead / chest)
	elseif limb == "Prop" then
		return part.Position
	end
	return (part.CFrame * CFrame.new(0, -0.95, 0)).Position -- (fist / foot)
end

------------------------------------------------------------------------------
-- Trails
------------------------------------------------------------------------------

type TrailEntry = { trail: Trail, part: BasePart }
-- Per model, per part name: its trail (made once, kept on the part).
local trails: { [Model]: { [string]: TrailEntry } } = setmetatable({}, { __mode = "k" }) :: any

local function trailFor(model: Model, part: BasePart, isProp: boolean): Trail
	local byPart = trails[model]
	if byPart == nil then
		byPart = {}
		trails[model] = byPart
	end
	local key = if isProp then "Prop:" .. part:GetFullName() else part.Name
	local entry = byPart[key]
	if entry and entry.trail.Parent ~= nil and entry.part == part then
		return entry.trail
	end
	-- Two attachments across the fist / foot: the width is the gap between them.
	local a0 = Instance.new("Attachment")
	a0.Name = "VfxTrail0"
	local a1 = Instance.new("Attachment")
	a1.Name = "VfxTrail1"
	if isProp then
		a0.Position = Vector3.new(part.Size.X * 0.3, 0, 0)
		a1.Position = Vector3.new(-part.Size.X * 0.3, 0, 0)
	else
		a0.Position = Vector3.new(0, -0.85, 0.22)
		a1.Position = Vector3.new(0, -0.85, -0.22)
	end
	a0.Parent = part
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "VfxTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Enabled = false
	trail.MinLength = 0.05
	trail.MaxLength = 0
	trail.FaceCamera = false
	trail.Texture = Palette.TEXTURES.trail
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.TextureLength = 1
	trail.Color = ColorSequence.new(Palette.Trail)
	trail.LightEmission = 0.15
	trail.LightInfluence = 0.7
	trail.Brightness = 1
	trail.WidthScale = NumberSequence.new({ K(0, 1), K(1, 0.15) })
	trail.Transparency = NumberSequence.new({ K(0, 0.55), K(0.5, 0.8), K(1, 1) })
	trail.Parent = part
	byPart[key] = { trail = trail, part = part }
	return trail
end

local function limbParts(model: Model, limb: Limb): { BasePart }
	if limb == "BothArms" then
		local list = {}
		for _, name in { "Right Arm", "Left Arm" } do
			local part = basePart(model, name)
			if part then
				table.insert(list, part)
			end
		end
		return list
	end
	local part = Limb.part(model, limb)
	return if part then { part } else {}
end

export type TrailOpts = { life: number?, arc: boolean?, width: number? }

-- Is this model worth a trail on this client? (Low quality: our own only.)
local function wantsTrail(model: Model): boolean
	if not Quality.extras() and model ~= player.Character then
		return false
	end
	local root = basePart(model, "HumanoidRootPart")
	return root ~= nil and Quality.detail(root.Position) == "Full"
end

function Limb.trailOn(model: Model, limb: Limb, opts: TrailOpts?)
	if not wantsTrail(model) then
		return
	end
	local o: TrailOpts = opts or {}
	local life = o.life or (if o.arc then 0.16 else 0.1)
	for _, part in limbParts(model, limb) do
		local trail = trailFor(model, part, limb == "Prop")
		trail.Lifetime = life
		-- (set every time: a width given once must not stay for the next swing)
		trail.WidthScale = NumberSequence.new({ K(0, (o.width or 0.44) / 0.44), K(1, 0.15) })
		if limb == "Prop" then
			trail.Transparency = NumberSequence.new({ K(0, 0.4), K(1, 1) })
		end
		trail:Clear()
		trail.Enabled = true
	end
end

function Limb.trailOff(model: Model, limb: Limb)
	local byPart = trails[model]
	if byPart == nil then
		return
	end
	for _, part in limbParts(model, limb) do
		local key = if limb == "Prop" then "Prop:" .. part:GetFullName() else part.Name
		local entry = byPart[key]
		if entry then
			entry.trail.Enabled = false
		end
	end
end

-- Per model, per limb: the number of the last trail window turned on.
local windows: { [Model]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function bumpWindow(model: Model, limb: Limb): number
	local byLimb = windows[model]
	if byLimb == nil then
		byLimb = {}
		windows[model] = byLimb
	end
	local value = (byLimb[limb] or 0) + 1
	byLimb[limb] = value
	return value
end

-- The trail on from `fromNow` to `toNow` seconds from now. If the model
-- starts another action meanwhile (Pool.bump), it doesn't turn on (but
-- always turns off).
function Limb.trailWindow(
	model: Model,
	limb: Limb,
	fromNow: number,
	toNow: number,
	opts: TrailOpts?
)
	local token = Pool.token(model)
	local mine = 0 -- (this window's number, once its trail is on)
	Pool.after(fromNow, function()
		if Pool.token(model) == token then
			Limb.trailOn(model, limb, opts)
			mine = bumpWindow(model, limb)
		end
	end)
	Pool.after(math.max(toNow, fromNow + 1 / 60), function()
		-- (only if we turned it on, and no newer window turned this limb's
		-- trail on meanwhile: a quick next blow must not lose its trail)
		local byLimb = windows[model]
		if mine ~= 0 and byLimb ~= nil and byLimb[limb] == mine then
			Limb.trailOff(model, limb)
		end
	end)
end

------------------------------------------------------------------------------
-- Pose history (for the smear)
------------------------------------------------------------------------------

local HISTORY = 6
type History = { frames: { { [string]: CFrame } }, until_: number }
local histories: { [Model]: History } = setmetatable({}, { __mode = "k" }) :: any
local recording = false

local function record()
	if recording then
		return
	end
	recording = true
	Pool.step(function()
		local now = os.clock()
		local any = false
		for model, history in histories do
			if now > history.until_ or model.Parent == nil then
				histories[model] = nil
				continue
			end
			any = true
			local snapshot: { [string]: CFrame } = {}
			for _, name in BODY_PARTS do
				local part = basePart(model, name)
				if part then
					snapshot[name] = part.CFrame
				end
			end
			local tip = propTip(model)
			if tip then
				snapshot.Prop = tip.CFrame
			end
			table.insert(history.frames, 1, snapshot)
			if #history.frames > HISTORY then
				table.remove(history.frames)
			end
		end
		if not any then
			recording = false
		end
		return any
	end)
end

-- Record (or stop recording) the model's limb CFrames every frame (ring
-- buffer of 6 frames). Recording stops by itself 2 s after the last `on`.
function Limb.track(model: Model, on: boolean)
	if on then
		local history = histories[model]
		if history then
			history.until_ = os.clock() + 2
		else
			histories[model] = { frames = {}, until_ = os.clock() + 2 }
		end
		record()
	else
		histories[model] = nil
	end
end

------------------------------------------------------------------------------
-- Ghosts (smear, afterimage)
------------------------------------------------------------------------------

local ghostPool: { Part } = {}
local MAX_GHOSTS = 36
local ghostCount = 0

local function takeGhost(): Part?
	local ghost = table.remove(ghostPool)
	if ghost then
		return ghost
	end
	if ghostCount >= MAX_GHOSTS then
		return nil
	end
	ghostCount += 1
	local part = Instance.new("Part")
	part.Name = "VfxGhost"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function releaseGhost(part: Part)
	part.Parent = nil
	table.insert(ghostPool, part)
end

-- Shows ghost parts copying `sources` at `cframes`, fading from `from` to
-- 1 over `seconds` (or `frames` frames).
local function fadeGhosts(
	sources: { BasePart },
	cframes: { CFrame },
	from: number,
	seconds: number,
	stretch: number?
)
	local folder = Pool.folder()
	local ghosts: { Part } = {}
	for index, source in sources do
		local ghost = takeGhost()
		if ghost == nil then
			break
		end
		ghost.Size = source.Size * Vector3.new(1, stretch or 1, 1)
		ghost.Color = source.Color:Lerp(Palette.Ghost, 0.4)
		ghost.Transparency = from
		ghost.CFrame = cframes[index]
		ghost.Parent = folder
		table.insert(ghosts, ghost)
	end
	if #ghosts == 0 then
		return
	end
	local t = 0
	Pool.step(function(dt)
		t += dt / seconds
		if t >= 1 then
			for _, ghost in ghosts do
				releaseGhost(ghost)
			end
			return false
		end
		for _, ghost in ghosts do
			ghost.Transparency = from + (1 - from) * t
		end
		return true
	end)
end

export type SmearOpts = { ghosts: number?, frames: number? }

-- Ghost copies of the striking limb where it was 1 and 2 frames ago (a
-- realistic "smear frame": motion blur on the fast part of a blow).
-- Needs Limb.track(model, true) a few frames before.
function Limb.smear(model: Model, limb: Limb, opts: SmearOpts?)
	if not Quality.extras() then
		return
	end
	local history = histories[model]
	if history == nil or #history.frames < 2 then
		return
	end
	local o: SmearOpts = opts or {}
	local count = math.clamp(o.ghosts or 2, 1, 3)
	local seconds = (o.frames or 3) / 60
	local names: { string } = if limb == "BothArms"
		then { "Right Arm", "Left Arm" }
		elseif limb == "Prop" then { "Prop" }
		else { PART_OF[limb] }
	for ago = 1, count do
		local frame = history.frames[ago + 1] -- (index 1 = this frame)
		if frame == nil then
			break
		end
		local sources: { BasePart } = {}
		local cframes: { CFrame } = {}
		for _, name in names do
			local source = if name == "Prop" then propTip(model) else basePart(model, name)
			local cframe = frame[name]
			if source and cframe then
				table.insert(sources, source)
				table.insert(cframes, cframe)
			end
		end
		fadeGhosts(sources, cframes, 0.7 + 0.1 * (ago - 1), seconds, 1.12)
	end
end

export type AfterimageOpts = { count: number?, fade: number?, spacing: number? }

local afterimageSets: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

-- A ghost of the whole body where it stands now, fading out (0.2 s).
-- `count` > 1 leaves more ghosts, `spacing` seconds apart. Max 2 alive
-- per character.
function Limb.afterimage(model: Model, opts: AfterimageOpts?)
	if not Quality.extras() then
		return
	end
	local root = basePart(model, "HumanoidRootPart")
	if root == nil or Quality.detail(root.Position) ~= "Full" then
		return
	end
	local o: AfterimageOpts = opts or {}
	local fade = o.fade or 0.2
	local count = math.clamp(o.count or 1, 1, 2)
	for index = 1, count do
		Pool.after((index - 1) * (o.spacing or 0.05), function()
			if (afterimageSets[model] or 0) >= 2 or model.Parent == nil then
				return
			end
			afterimageSets[model] = (afterimageSets[model] or 0) + 1
			local sources: { BasePart } = {}
			local cframes: { CFrame } = {}
			for _, name in BODY_PARTS do
				local part = basePart(model, name)
				if part and part.Transparency < 1 then
					table.insert(sources, part)
					table.insert(cframes, part.CFrame)
				end
			end
			fadeGhosts(sources, cframes, 0.65, fade)
			Pool.after(fade, function()
				afterimageSets[model] = math.max(0, (afterimageSets[model] or 1) - 1)
			end)
		end)
	end
end

------------------------------------------------------------------------------
-- Speed lines, scrape, glint
------------------------------------------------------------------------------

export type SpeedOpts = { dir: Vector3?, rate: number? }

-- Thin lines streaming past the body for `seconds` (a burst of speed:
-- dash, tackle, a launched victim). `dir` = where the body goes (default:
-- its velocity, else its facing). The lines go the other way.
function Limb.speedLines(model: Model, seconds: number, opts: SpeedOpts?)
	local root = basePart(model, "HumanoidRootPart")
	if root == nil or Quality.detail(root.Position) ~= "Full" then
		return
	end
	local o: SpeedOpts = opts or {}
	local rate = (o.rate or 90) * (if Quality.level() == "Low" then 0.5 else 1)
	local elapsed = 0
	local owed = 12 -- (a first burst)
	Pool.step(function(dt)
		elapsed += dt
		if elapsed > seconds or root.Parent == nil then
			return false
		end
		local velocity = root.AssemblyLinearVelocity
		local going = o.dir or (if velocity.Magnitude > 4 then velocity else root.CFrame.LookVector)
		owed += rate * dt
		local n = math.floor(owed)
		if n <= 0 then
			return true
		end
		owed -= n
		-- (one emit per few lines, each from a random spot in the body's box)
		for _ = 1, math.min(n, 4) do
			local offset = Vector3.new(
				random:NextNumber(-1.4, 1.4),
				random:NextNumber(-2.4, 2.2),
				random:NextNumber(-1, 1)
			)
			local slot =
				Pool.slot("SpeedLines", Pool.aim(root.CFrame:PointToWorldSpace(offset), -going))
			if slot then
				slot.emitter:Emit(math.max(1, math.floor(n / 4)))
			end
		end
		return true
	end)
end

-- Floor-coloured dust off the feet every 2 frames for `seconds` (a dash's
-- slide, a knockback skid).
function Limb.scrape(model: Model, seconds: number)
	local root = basePart(model, "HumanoidRootPart")
	if root == nil or Quality.detail(root.Position) ~= "Full" then
		return
	end
	local elapsed = 0
	local frame = 0
	Pool.step(function(dt)
		elapsed += dt
		frame += 1
		if elapsed > seconds or root.Parent == nil then
			return false
		end
		if frame % 2 == 0 then
			local floor = Floor.at(root.Position, 4)
			if floor then
				local velocity = root.AssemblyLinearVelocity
				local back = if velocity.Magnitude > 2 then -velocity else -root.CFrame.LookVector
				Layers.puff(
					floor.position + Vector3.yAxis * 0.2,
					back + Vector3.yAxis * 0.4,
					0.5,
					1,
					{
						color = Floor.dustColor(floor),
						delayFrames = 0,
						life = 0.5,
					}
				)
			end
		end
		return true
	end)
end

-- A 1-frame tiny flash on the prop's tip (the fastest frame of a swing).
function Limb.glint(model: Model, limb: Limb)
	local tip = Limb.tip(model, limb)
	if tip then
		Layers.contactFlash(tip, 0.5, { frames = 1, spikes = 0, color = Palette.GlassGlint })
	end
end

return Limb
