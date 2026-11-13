--!strict
-- RiftBurn: someone burning ("Burning" attribute: "Acid" / "Fire", set by
-- the server while Dr. Rift's acid, ray or explosive flask burns them).
--
--   RiftBurn.watch(model)
--
-- FIRE: real flames licking up the body. On every body part two layers of
-- flame (a small bright core close to the skin, a bigger orange tongue
-- around it, both flickering), embers floating up, thin black smoke rising
-- above the shoulders and the head, a faint pale haze over them (the heat
-- shimmer, faked), and an orange light that flickers on everything around.
-- The skin goes dark (the torso most, the legs least) and the body
-- (clothes included) gets black charred patches with glowing specks in
-- them, spreading while it burns. When it stops: the flames die down, the
-- body smoulders (grey smoke) for 2 s, the specks cool to black and the
-- char fades away slowly. Burnt again before it has faded: the same
-- patches come back (and a few more), no new set somewhere else.
--
-- ACID: the skin corroding. Clusters of pale yellow-green foam bubbles grow
-- and pop in a little puff on the skin (always somewhere new), it froths
-- and fizzes, caustic vapour rises, raw red blotches ringed with
-- yellow-green appear and the skin turns a little raw, and drops of acid
-- fall from the body and fizz on the floor.
--
-- The patches and bubbles are built only when they show, a few parts a
-- frame for everybody (an explosion setting many fighters on fire at once
-- doesn't hitch).
--
-- The skin colour: the body parts are tinted, and the pieces drawn over
-- them that wear the skin colour (Gashes' "Skin", "Core", "*_Lip", Wounds'
-- "Swelling", the gore's skin: any piece under the part of its colour),
-- from their real colour, saved first. The real colour comes back exactly
-- once the tint has faded. It is also kept as an attribute on the part
-- ("RiftBurnSkin"), so a copy of a burning body (a clone) can get it back
-- and other effects can read the real skin. A choked head (BouncerFx turns
-- it red) is left alone while it is choked.
--
-- Everything the burn adds is in a "RiftBurn" folder in the model (the
-- patches, bubbles) or named "RiftBurn..." under its parts (particles,
-- light); all of it is removed when it ends, when the model dies, leaves the
-- game or is destroyed. One Heartbeat drives every burning model (and stops
-- when nobody burns).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local HeadBlast = require(script.Parent.HeadBlast)

local RiftBurn = {}
local P = require(script.Parent.RiftParts)
local ACID = P.ACID
local ACID_DARK = P.ACID_DARK
local emitter = P.emitter
local ghost = P.ghost
local stick = P.stick
local floorUnder = P.floorUnder

local random = Random.new()

------------------------------------------------------------------------------
-- Look
------------------------------------------------------------------------------

-- Fire colours: white-yellow at the root of a flame, orange, then dark red
-- where it dies; soot and char.
local FLAME_WHITE = Color3.fromRGB(255, 244, 200)
local FLAME_YELLOW = Color3.fromRGB(255, 196, 84)
local FLAME_ORANGE = Color3.fromRGB(255, 118, 30)
local FLAME_RED = Color3.fromRGB(170, 40, 10)
local EMBER = Color3.fromRGB(255, 150, 50)
local SOOT = Color3.fromRGB(38, 35, 32)
local SMOKE_GREY = Color3.fromRGB(84, 80, 76)
local CHAR = Color3.fromRGB(22, 17, 14) -- burnt black
local SCORCH = Color3.fromRGB(78, 46, 26) -- singed brown edge
local GLOW = Color3.fromRGB(255, 92, 20) -- a glowing speck in the char
local FIRE_LIGHT = Color3.fromRGB(255, 128, 48)

-- Acid colours.
local FOAM = Color3.fromRGB(204, 236, 96)
local FROTH = Color3.fromRGB(226, 240, 168)
local VAPOUR = Color3.fromRGB(186, 212, 116)
local RAW = Color3.fromRGB(150, 38, 34) -- eaten skin: raw red flesh
local CORRODED = Color3.fromRGB(170, 176, 58) -- yellow-green ring around it
local BLISTER = Color3.fromRGB(214, 198, 116)

-- What the whole skin shifts toward (how far: CHAR_MAX / RAW_MAX).
local SKIN_CHAR = Color3.fromRGB(40, 28, 22)
local SKIN_RAW = Color3.fromRGB(184, 96, 80)
local CHAR_MAX = 0.55
local RAW_MAX = 0.38
-- How fast (share of the full tint per second): on while it burns, off
-- after (slower: the char stays a while).
local CHAR_ON = 0.32
local CHAR_OFF = 0.11
local RAW_ON = 0.3
local RAW_OFF = 0.12

local MARK_FADE_FIRE = 7 -- seconds for the char patches to fade after
local MARK_FADE_ACID = 5
local SMOULDER = 2 -- seconds of smoke once the fire is out
local MARK_SPREAD = 2.2 -- the patches appear one by one over this time

local HEAD_RADIUS = 0.6 -- the classic head: a rounded cylinder this wide
local HEAD_HALF = 0.32 -- and this high (half), where patches can go

local BODY = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

-- How much of the burn each part gets (flame rates, patches, bubbles).
local SHARE: { [string]: number } = {
	Torso = 1,
	Head = 0.55,
	["Right Arm"] = 0.5,
	["Left Arm"] = 0.5,
	["Right Leg"] = 0.3,
	["Left Leg"] = 0.3,
}
local MARKS: { [string]: number } = {
	Torso = 4,
	Head = 2,
	["Right Arm"] = 2,
	["Left Arm"] = 2,
	["Right Leg"] = 1,
	["Left Leg"] = 1,
}
-- Foam clusters (three bubbles each) per part.
local BUBBLES: { [string]: number } = {
	Torso = 3,
	Head = 1,
	["Right Arm"] = 2,
	["Left Arm"] = 2,
	["Right Leg"] = 1,
	["Left Leg"] = 1,
}

-- The patches and bubbles are built when they first show, at most this many
-- parts a frame for everybody (an explosion sets many fighters on fire at
-- once: no hitch).
local BUILD_PER_FRAME = 20
local CLUSTER = 3 -- bubbles in a foam cluster

-- How hard each part's skin is tinted (the torso, in the middle of the
-- flames, the most; the legs, under them, the least).
local function tintWeight(name: string): number
	return 0.4 + 0.6 * (SHARE[name] or 0.3)
end

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

-- One blob of a patch, planned first (built when the patch shows): its size
-- (share of the patch), place on the skin (dx, dy: share of its size),
-- stretch and turn, look, and how far it stands out of the skin.
type LayerPlan = {
	scale: number,
	dx: number,
	dy: number,
	stretch: number,
	spin: number,
	color: Color3,
	material: Enum.Material,
	alpha: number, -- its transparency
	lift: number,
	glow: boolean, -- a glowing speck (cools down to char when it ends)
}

-- A built blob.
type Layer = { part: BasePart, mesh: SpecialMesh, alpha: number }

-- A patch on the skin (char or acid blotch): grows from a dot when it shows.
type Mark = {
	base: BasePart,
	offset: CFrame, -- its centre on the skin (base space, Z out)
	fit: number, -- its radius
	thick: number,
	wet: boolean,
	plans: { LayerPlan },
	layers: { Layer }, -- (empty until it shows)
	showAt: number, -- (os.clock)
	startedAt: number, -- when it really showed (building can wait a frame)
	grow: number, -- seconds to full size
	shown: boolean,
	done: boolean,
}

-- A foam cluster (a few bubbles together): grows on the skin, pops, comes
-- back somewhere else.
type Bubble = {
	base: BasePart,
	parts: { BasePart },
	meshes: { SpecialMesh },
	welds: { Weld },
	lags: { number }, -- each bubble starts swelling a little later
	at: CFrame, -- the cluster's centre (base space)
	born: number,
	life: number, -- seconds growing before it pops
	popAt: number,
	nextAt: number,
}

-- A flickering particle layer: its normal rate, and a noise seed.
type Flicker = { emitter: ParticleEmitter, rate: number, seed: number, speed: number }

-- One burn of one kind on one model (a new one when the kind changes).
type Session = {
	model: Model,
	kind: string,
	folder: Folder,
	emitters: { Instance }, -- particles (and their attachments)
	flickers: { Flicker },
	headEmitters: { ParticleEmitter }, -- on the head (gone if it bursts)
	viewEmitters: { ParticleEmitter }, -- hidden in our own first person
	light: PointLight?,
	marks: { Mark },
	glows: { BasePart }, -- the glowing specks in the char
	bubbles: { Bubble },
	pop: ParticleEmitter?, -- the fizz of a bubble popping (moved to it)
	popPoint: Attachment?,
	nextDrip: number,
	seed: number,
	headGone: boolean, -- the head burst (HeadBlast): nothing left on it
}

-- The patches of an ended burn, fading on the body (taken back if the same
-- burn starts again before they are gone).
type Fade = {
	model: Model,
	kind: string,
	folder: Folder,
	marks: { Mark },
	glows: { BasePart },
	tweens: { Tween },
	token: number, -- changes when taken back (the delayed steps then skip)
}

-- The skin tint of a model: its real colours and how far it is charred /
-- raw (0..1 of CHAR_MAX / RAW_MAX), and where each is going.
type Tint = {
	originals: { [BasePart]: Color3 },
	weights: { [BasePart]: number },
	written: { [BasePart]: Color3 }, -- the last colour put on each part
	copies: { [BasePart]: { BasePart } }, -- skin pieces drawn over each part
	scanned: number, -- when the copies were last looked for
	char: number,
	raw: number,
	charGoal: number,
	rawGoal: number,
	applied: number, -- last time the colours were written
	headFreeUntil: number, -- the head is someone else's until then (choked)
}

local sessions: { [Model]: Session } = {}
local tints: { [Model]: Tint } = {}
-- Ended burns still fading on the body (char patches): removed later.
local fading: { [Folder]: Fade } = {}
local heartbeat: RBXScriptConnection? = nil
-- Parts that may still be built this frame (BUILD_PER_FRAME).
local budget = BUILD_PER_FRAME

local ORIGINAL_ATTRIBUTE = "RiftBurnSkin"

------------------------------------------------------------------------------
-- Skin tint
------------------------------------------------------------------------------

-- Two colours the same (to a hair: Color3 values go through 8 bits).
local function sameColor(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.006
		and math.abs(a.G - b.G) < 0.006
		and math.abs(a.B - b.B) < 0.006
end

-- The pieces drawn over a body part that wear its skin colour: Gashes'
-- copies of the skin ("Skin", "Core", "*_Lip"), Wounds' "Swelling", and
-- the skin pieces of the gore (WaistCut, ArmRip, HeadBlast: they take the
-- part's colour when they are made, the real one or the tinted one).
local function findCopies(part: BasePart, original: Color3, written: Color3?): { BasePart }
	local found = {}
	for _, piece in part:GetDescendants() do
		if not piece:IsA("BasePart") or string.sub(piece.Name, 1, 8) == "RiftBurn" then
			continue
		end
		local name = piece.Name
		local color = piece.Color
		if
			name == "Skin"
			or name == "Core"
			or name == "Swelling"
			or string.sub(name, -4) == "_Lip"
			or sameColor(color, original)
			or (written ~= nil and sameColor(color, written))
		then
			table.insert(found, piece)
		end
	end
	return found
end

local function rescan(tint: Tint)
	for part, original in tint.originals do
		tint.copies[part] = findCopies(part, original, tint.written[part])
	end
end

-- The head is being choked (BouncerFx turns it red, then back over 4 s):
-- leave it alone meanwhile.
local function headIsBusy(model: Model, tint: Tint, now: number): boolean
	if model:GetAttribute("Held") ~= nil then
		tint.headFreeUntil = now + 4.3
		return true
	end
	return now < tint.headFreeUntil
end

local function paint(tint: Tint, part: BasePart, color: Color3)
	part.Color = color
	tint.written[part] = color
	local copies = tint.copies[part]
	if copies then
		for _, piece in copies do
			if piece.Parent then
				piece.Color = color
			end
		end
	end
end

local function applyTint(model: Model, tint: Tint, now: number)
	local headBusy = headIsBusy(model, tint, now)
	for part, original in tint.originals do
		if part.Parent == nil or (headBusy and part.Name == "Head") then
			continue
		end
		local weight = tint.weights[part] or 1
		local char = tint.char * CHAR_MAX * weight
		local raw = tint.raw * RAW_MAX * weight
		paint(tint, part, original:Lerp(SKIN_RAW, raw):Lerp(SKIN_CHAR, char))
	end
end

-- Back to the real colours, exactly.
local function restoreTint(model: Model)
	local tint = tints[model]
	tints[model] = nil
	if tint == nil then
		return
	end
	rescan(tint) -- (pieces made since the last look)
	for part, original in tint.originals do
		paint(tint, part, original)
		part:SetAttribute(ORIGINAL_ATTRIBUTE, nil)
	end
end

local BODY_COLORS: { [string]: string } = {
	Head = "HeadColor3",
	Torso = "TorsoColor3",
	["Right Arm"] = "RightArmColor3",
	["Left Arm"] = "LeftArmColor3",
	["Right Leg"] = "RightLegColor3",
	["Left Leg"] = "LeftLegColor3",
}

local function tintOf(model: Model): Tint
	local tint = tints[model]
	if tint then
		return tint
	end
	local held = model:GetAttribute("Held") ~= nil
	local colors = model:FindFirstChildOfClass("BodyColors")
	local originals: { [BasePart]: Color3 } = {}
	local weights: { [BasePart]: number } = {}
	for _, name in BODY do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			-- (a copy of a body that was tinted: its saved real colour; a
			-- choked head is red now: its real colour is in BodyColors)
			local saved = part:GetAttribute(ORIGINAL_ATTRIBUTE)
			local original = part.Color
			if typeof(saved) == "Color3" then
				original = saved
			elseif held and name == "Head" and colors then
				original = (colors :: any)[BODY_COLORS[name]] :: Color3
			end
			originals[part] = original
			weights[part] = tintWeight(name)
			-- (before any tint: the others can read the real colour here)
			part:SetAttribute(ORIGINAL_ATTRIBUTE, original)
		end
	end
	local created: Tint = {
		originals = originals,
		weights = weights,
		written = {},
		copies = {},
		scanned = os.clock(),
		char = 0,
		raw = 0,
		charGoal = 0,
		rawGoal = 0,
		applied = 0,
		headFreeUntil = 0,
	}
	rescan(created)
	tints[model] = created
	return created
end

------------------------------------------------------------------------------
-- Points on the skin
------------------------------------------------------------------------------

-- A frame on the skin at `position` (part space) facing out along `normal`
-- (its Z), turned by `spin` around it.
local function frameOn(position: Vector3, normal: Vector3, spin: number): CFrame
	return CFrame.fromMatrix(position, Vector3.yAxis:Cross(normal), Vector3.yAxis)
		* CFrame.Angles(0, 0, spin)
end

-- A random spot on the sides of a body part (not its top or bottom, hidden
-- by the body) with room for something `radius` wide: its frame (part
-- space, Z out of the skin) and the radius that fits. `low`: the lower half
-- (where drops form).
local function skinSpot(part: BasePart, radius: number, low: boolean?): (CFrame, number)
	local spin = random:NextNumber(0, math.pi * 2)
	if part.Name == "Head" then
		local fit = math.min(radius, 0.22)
		local angle = random:NextNumber(0, math.pi * 2)
		local top = HEAD_HALF - fit * 0.5
		local height = random:NextNumber(-top, if low then 0 else top)
		local normal = Vector3.new(math.sin(angle), 0, math.cos(angle))
		return frameOn(normal * HEAD_RADIUS + Vector3.new(0, height, 0), normal, spin), fit
	end
	local size = part.Size
	-- Front / back (width X) or the sides (width Z), by their area.
	local frontArea = size.X * size.Y
	local sideArea = size.Z * size.Y
	local onFront = random:NextNumber(0, frontArea + sideArea) < frontArea
	local sign = if random:NextNumber() < 0.5 then -1 else 1
	local across = if onFront then Vector3.xAxis else Vector3.zAxis
	local normal = if onFront then Vector3.zAxis * sign else Vector3.xAxis * sign
	local halfWidth = (if onFront then size.X else size.Z) * 0.5
	local halfDepth = (if onFront then size.Z else size.X) * 0.5
	local halfHeight = size.Y * 0.5
	local fit = math.min(radius, halfWidth * 0.9, halfHeight * 0.9)
	local roomX = math.max(halfWidth - fit, 0)
	local roomY = math.max(halfHeight - fit, 0)
	local x = random:NextNumber(-roomX, roomX)
	local y = random:NextNumber(-roomY, if low then 0 else roomY)
	return frameOn(normal * halfDepth + across * x + Vector3.yAxis * y, normal, spin), fit
end

-- An ellipsoid stuck on the skin (a patch layer, a bubble): a part shown as
-- a sphere stretched to its size, welded on.
local function blob(
	name: string,
	base: BasePart,
	offset: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	parent: Instance
): (BasePart, SpecialMesh, Weld)
	local part = ghost(name, size, color, material)
	part.Transparency = transparency
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.05, 0.05, 1)
	mesh.Parent = part
	stick(base, part, offset, parent)
	local weld = part:FindFirstChildOfClass("Weld") :: Weld
	return part, mesh, weld
end

------------------------------------------------------------------------------
-- Patches (char / acid blotches)
------------------------------------------------------------------------------

-- The patches of a burn, each with its moment to show (spread over the
-- first seconds: the char creeps over the body). Only planned here: the
-- parts are built when a patch shows (stepMarks). `share`: of the usual
-- count (a burn starting again adds only a few).
local function addMarks(session: Session, ownHead: boolean, share: number)
	local now = os.clock()
	local isFire = session.kind == "Fire"
	for _, name in BODY do
		local base = session.model:FindFirstChild(name)
		if not (base and base:IsA("BasePart")) or (name == "Head" and ownHead) then
			continue
		end
		local wanted = (MARKS[name] or 0) * share
		local count = math.floor(wanted) + (if random:NextNumber() < wanted % 1 then 1 else 0)
		for index = 1, count do
			local radius = if name == "Torso"
				then random:NextNumber(0.28, 0.55)
				else random:NextNumber(0.22, 0.42)
			local offset, fit = skinSpot(base, radius)
			local plans: { LayerPlan } = {}
			-- One blob of the patch (a patch is a few of them overlapping: a
			-- ragged shape, never rings).
			local function layer(
				scale: number,
				dx: number,
				dy: number,
				color: Color3,
				material: Enum.Material,
				alpha: number,
				lift: number,
				glow: boolean?
			)
				table.insert(plans, {
					scale = scale,
					dx = dx,
					dy = dy,
					stretch = random:NextNumber(0.5, 1),
					spin = random:NextNumber(0, math.pi * 2),
					color = color,
					material = material,
					alpha = alpha,
					lift = lift,
					glow = glow == true,
				})
			end
			local function jitter(): number
				return random:NextNumber(-0.32, 0.32)
			end
			if isFire then
				-- A singed brown halo (two blobs), black char inside (two
				-- blobs off centre), maybe a glowing speck in it.
				layer(0.9, jitter() * 0.3, jitter() * 0.3, SCORCH, Enum.Material.Sand, 0.45, 0)
				layer(0.7, jitter(), jitter(), SCORCH, Enum.Material.Sand, 0.5, 0.004)
				local coreX, coreY = 0, 0
				for _ = 1, 2 do
					coreX, coreY = jitter(), jitter()
					layer(
						random:NextNumber(0.38, 0.62),
						coreX,
						coreY,
						CHAR,
						Enum.Material.Slate,
						random:NextNumber(0.05, 0.2),
						0.03
					)
				end
				if random:NextNumber() < 0.55 then
					layer(
						random:NextNumber(0.1, 0.2),
						coreX,
						coreY,
						GLOW,
						Enum.Material.Neon,
						0.15,
						0.05,
						true
					)
				end
			else
				-- Yellow-green corroded skin around, raw red flesh where it
				-- ate through (or a pale blister).
				layer(
					0.9,
					jitter() * 0.3,
					jitter() * 0.3,
					CORRODED,
					Enum.Material.SmoothPlastic,
					0.35,
					0
				)
				layer(0.65, jitter(), jitter(), CORRODED, Enum.Material.SmoothPlastic, 0.3, 0.004)
				for _ = 1, random:NextInteger(1, 2) do
					layer(
						random:NextNumber(0.4, 0.65),
						jitter(),
						jitter(),
						RAW,
						Enum.Material.SmoothPlastic,
						0.05,
						0.03
					)
				end
				if random:NextNumber() < 0.4 then
					layer(
						random:NextNumber(0.15, 0.25),
						jitter(),
						jitter(),
						BLISTER,
						Enum.Material.SmoothPlastic,
						0.1,
						0.05
					)
				end
			end
			local first = share >= 1 and name == "Torso" and index == 1
			table.insert(session.marks, {
				base = base,
				offset = offset,
				fit = fit,
				thick = if name == "Head" then 0.1 else 0.07,
				wet = not isFire,
				plans = plans,
				layers = {},
				showAt = now + (if first then 0 else random:NextNumber(0, MARK_SPREAD)),
				startedAt = 0,
				grow = random:NextNumber(0.7, 1.3),
				shown = false,
				done = false,
			})
		end
	end
end

-- The parts of a patch, now (a dot, growing in stepMarks).
local function buildMark(session: Session, mark: Mark)
	for _, plan in mark.plans do
		local width = mark.fit * 2 * plan.scale
		local size = Vector3.new(width, width * plan.stretch, mark.thick + plan.lift)
		-- (the bulge of the ellipsoid pokes a hair out of the skin)
		local at = mark.offset
			* CFrame.new(plan.dx * mark.fit, plan.dy * mark.fit, mark.thick * 0.18)
			* CFrame.Angles(0, 0, plan.spin)
		local part, mesh = blob(
			"RiftBurnMark",
			mark.base,
			at,
			size,
			plan.color,
			plan.material,
			plan.alpha,
			session.folder
		)
		part.Reflectance = if mark.wet then 0.14 else 0 -- (acid: wet)
		table.insert(mark.layers, { part = part, mesh = mesh, alpha = plan.alpha })
		if plan.glow then
			table.insert(session.glows, part)
		end
	end
end

local function stepMarks(session: Session, now: number)
	for _, mark in session.marks do
		if mark.done or now < mark.showAt then
			continue
		end
		if not mark.shown then
			-- (no room left this frame: next frame)
			if budget < #mark.plans or mark.base.Parent == nil then
				continue
			end
			budget -= #mark.plans
			buildMark(session, mark)
			mark.shown = true
			mark.startedAt = now
		end
		local t = math.min((now - mark.startedAt) / mark.grow, 1)
		local eased = 1 - (1 - t) * (1 - t) -- quick, then slower
		local scale = 0.15 + 0.85 * eased
		for _, item in mark.layers do
			item.mesh.Scale = Vector3.new(scale, scale, 1)
		end
		mark.done = t >= 1
	end
end

------------------------------------------------------------------------------
-- Acid foam and drops
------------------------------------------------------------------------------

-- The cluster somewhere new on its part: a bubble and two smaller ones
-- against it, tiny, growing.
local function placeBubble(bubble: Bubble, now: number)
	local offset, fit = skinSpot(bubble.base, 0.16)
	local main = math.min(fit, random:NextNumber(0.07, 0.14)) * 2
	bubble.at = offset
	local turn = random:NextNumber(0, math.pi * 2)
	for index, part in bubble.parts do
		local size = if index == 1 then main else main * random:NextNumber(0.45, 0.7)
		local x, y = 0, 0
		if index > 1 then
			-- (round it, touching it)
			local angle = turn + (index - 2) * random:NextNumber(1.6, 2.6)
			local reach = (main + size) * 0.42
			x, y = math.cos(angle) * reach, math.sin(angle) * reach
		end
		-- (half sunk in the skin, like foam sitting on it)
		bubble.welds[index].C0 = offset * CFrame.new(x, y, size * 0.15)
		part.Size = Vector3.new(size, size, size)
		part.Transparency = random:NextNumber(0.35, 0.55)
		bubble.meshes[index].Scale = Vector3.new(0.1, 0.1, 0.1)
		bubble.lags[index] = if index == 1 then 0 else random:NextNumber(0, 0.35)
	end
	bubble.born = now
	bubble.life = random:NextNumber(0.4, 1)
	bubble.popAt = now + bubble.life
	bubble.nextAt = math.huge
end

-- The clusters, planned (their parts are built the first time they show).
local function addBubbles(session: Session, ownHead: boolean)
	local now = os.clock()
	for _, name in BODY do
		local base = session.model:FindFirstChild(name)
		if not (base and base:IsA("BasePart")) or (name == "Head" and ownHead) then
			continue
		end
		for _ = 1, BUBBLES[name] or 0 do
			table.insert(session.bubbles, {
				base = base,
				parts = {},
				meshes = {},
				welds = {},
				lags = {},
				at = CFrame.identity,
				born = now,
				life = 1,
				popAt = math.huge,
				nextAt = now + random:NextNumber(0, 0.7), -- (not all at once)
			})
		end
	end
end

local function buildBubble(session: Session, bubble: Bubble)
	for _ = 1, CLUSTER do
		local part, mesh, weld = blob(
			"RiftBurnBubble",
			bubble.base,
			CFrame.identity,
			Vector3.new(0.2, 0.2, 0.2),
			FROTH,
			Enum.Material.SmoothPlastic,
			1,
			session.folder
		)
		part.Reflectance = 0.5 -- (a wet film catching the light)
		table.insert(bubble.parts, part)
		table.insert(bubble.meshes, mesh)
		table.insert(bubble.welds, weld)
		table.insert(bubble.lags, 0)
	end
end

-- A bubble pops: a little puff of froth and spatter where it was.
local function popAt(session: Session, bubble: Bubble)
	local point = session.popPoint
	local pop = session.pop
	if point == nil or pop == nil or bubble.base.Parent == nil then
		return
	end
	point.WorldPosition = (bubble.base.CFrame * bubble.at * CFrame.new(0, 0, 0.05)).Position
	pop:Emit(random:NextInteger(2, 3))
end

local function stepBubbles(session: Session, now: number)
	for _, bubble in session.bubbles do
		local parts = bubble.parts
		if #parts == 0 then
			if now < bubble.nextAt or budget < CLUSTER or bubble.base.Parent == nil then
				continue
			end
			budget -= CLUSTER
			buildBubble(session, bubble)
		end
		if parts[1].Parent == nil then
			continue -- (its head burst)
		elseif now >= bubble.nextAt then
			placeBubble(bubble, now)
		elseif now < bubble.popAt then
			-- Swelling (fast at first, then slowly, with a slight wobble).
			local t = (now - bubble.born) / bubble.life
			for index, mesh in bubble.meshes do
				local lag = bubble.lags[index]
				local own = math.clamp((t - lag) / (1 - lag), 0, 1)
				local k = 0.1 + 0.9 * math.sqrt(own)
				local wobble = 1 + 0.07 * math.sin(now * 23 + index * 2.1 + bubble.life * 40)
				mesh.Scale = Vector3.new(k * wobble, k / wobble, k)
			end
		elseif bubble.nextAt == math.huge then
			-- Pop: gone in a puff, a moment of bare skin, then a new one.
			for _, part in parts do
				part.Transparency = 1
			end
			popAt(session, bubble)
			bubble.nextAt = now + random:NextNumber(0.05, 0.35)
		end
	end
end

-- A drop of acid running off the body, falling, fizzing on the floor.
local function drip(session: Session)
	local names = { "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg", "Torso" }
	local base = session.model:FindFirstChild(names[random:NextInteger(1, #names)])
	if not (base and base:IsA("BasePart")) then
		return
	end
	local offset = skinSpot(base, 0.05, true)
	local start = (base.CFrame * offset * CFrame.new(0, 0, 0.06)).Position
	local hit = floorUnder(start)
	local floor = if hit then hit.Position else start - Vector3.new(0, 6, 0)
	local height = math.max(start.Y - floor.Y, 0.05)
	local fall = math.sqrt(2 * height / math.max(workspace.Gravity, 1))

	local drop =
		ghost("RiftBurnDrop", Vector3.new(0.08, 0.15, 0.08), ACID, Enum.Material.SmoothPlastic)
	drop.Reflectance = 0.35
	drop.Transparency = 0.1
	drop.Anchored = true
	local shape = Instance.new("SpecialMesh")
	shape.MeshType = Enum.MeshType.Sphere
	shape.Parent = drop
	drop.CFrame = CFrame.new(start)
	drop.Parent = workspace
	-- Free fall: accelerating (Quad In is the shape of a fall).
	TweenService:Create(
		drop,
		TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(floor + Vector3.new(0, 0.05, 0)) }
	):Play()
	Debris:AddItem(drop, fall + 0.02)
	if hit == nil then
		return
	end
	task.delay(fall, function()
		-- The splash: a small spreading stain that fades, a fizz of green
		-- specks and a puff of vapour.
		local stain = P.disc("RiftBurnStain", ACID_DARK, 0.3)
		stain.Material = Enum.Material.SmoothPlastic
		stain.Reflectance = 0.2
		local width = random:NextNumber(0.25, 0.45)
		stain.Size = Vector3.new(width * 0.4, width * 0.4, 0.03)
		stain.CFrame = CFrame.lookAt(hit.Position, hit.Position + hit.Normal)
			* CFrame.new(0, 0, 0.02)
		stain.Parent = workspace
		TweenService:Create(
			stain,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(width, width * random:NextNumber(0.7, 1), 0.03) }
		):Play()
		task.delay(0.6, function()
			if stain.Parent then
				P.fade(stain, 1.2, { Color = Color3.fromRGB(60, 70, 30) })
			end
		end)
		Debris:AddItem(stain, 2.2)
		local point = P.attachmentAt(hit.Position + hit.Normal * 0.05)
		local fizz = emitter(point, {
			Name = "RiftBurnFloorFizz",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(ACID, ACID_DARK),
			LightEmission = 0.4,
			Size = NumberSequence.new(0.07, 0.01),
			Transparency = NumberSequence.new(0.1, 1),
			Lifetime = NumberRange.new(0.15, 0.4),
			Speed = NumberRange.new(1, 2.5),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, -8, 0),
			EmissionDirection = Enum.NormalId.Top,
		})
		fizz:Emit(random:NextInteger(4, 7))
		local puff = emitter(point, {
			Name = "RiftBurnFloorVapour",
			Color = ColorSequence.new(VAPOUR),
			Size = NumberSequence.new(0.2, 0.9),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(0.4, 1),
			SpreadAngle = Vector2.new(20, 20),
			Acceleration = Vector3.new(0, 1.5, 0),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-30, 30),
		})
		puff:Emit(1)
		Debris:AddItem(point, 1.3)
	end)
end

------------------------------------------------------------------------------
-- Particles
------------------------------------------------------------------------------

-- What flames come from on the head: the classic head is drawn smaller
-- than its part (2 x 1 x 1), a hidden part its real size instead.
local function headHost(session: Session, head: BasePart): BasePart
	local host = ghost(
		"RiftBurnHeadHost",
		Vector3.new(1.1, 1.05, 1.1),
		FLAME_ORANGE,
		Enum.Material.SmoothPlastic
	)
	host.Transparency = 1
	stick(head, host, CFrame.identity, session.folder)
	return host
end

local function addEmitter(
	session: Session,
	parent: Instance,
	props: { [string]: any },
	flicker: number?,
	isHead: boolean,
	inView: boolean? -- (true: hidden in our own first person, head or not)
)
	local particles = emitter(parent, props)
	table.insert(session.emitters, particles)
	if flicker then
		table.insert(session.flickers, {
			emitter = particles,
			rate = particles.Rate,
			seed = random:NextNumber(0, 100),
			speed = flicker,
		})
	end
	if isHead then
		table.insert(session.headEmitters, particles)
	end
	if inView then
		table.insert(session.viewEmitters, particles)
	end
	return particles
end

local function lightFire(session: Session, ownHead: boolean)
	local model = session.model
	for _, name in BODY do
		local part = model:FindFirstChild(name)
		if not (part and part:IsA("BasePart")) then
			continue
		end
		local share = SHARE[name] or 0.3
		local isHead = name == "Head"
		local host = if isHead then headHost(session, part) else part
		-- Bright core: short tongues close to the skin, white-yellow.
		local core = addEmitter(session, host, {
			Name = "RiftBurnCore",
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, FLAME_WHITE),
				ColorSequenceKeypoint.new(0.35, FLAME_YELLOW),
				ColorSequenceKeypoint.new(1, FLAME_ORANGE),
			}),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(0.3, 0.55),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
			Squash = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 0.6), -- (stretched up: a tongue)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.15, 0.1),
				NumberSequenceKeypoint.new(0.7, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.22, 0.42),
			Speed = NumberRange.new(0.8, 2),
			SpreadAngle = Vector2.new(15, 15),
			Acceleration = Vector3.new(0, 9, 0),
			Drag = 1.5,
			Rotation = NumberRange.new(-20, 20),
			RotSpeed = NumberRange.new(-60, 60),
			EmissionDirection = Enum.NormalId.Top,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ZOffset = 0.35,
			Rate = 44 * share,
		}, 9, isHead, ownHead and isHead)
		-- Orange outer flames: bigger, longer, licking higher, going dark red.
		local outer = addEmitter(session, host, {
			Name = "RiftBurnFlames",
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, FLAME_YELLOW),
				ColorSequenceKeypoint.new(0.4, FLAME_ORANGE),
				ColorSequenceKeypoint.new(1, FLAME_RED),
			}),
			LightEmission = 0.75,
			LightInfluence = 0,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(0.35, 0.95),
				NumberSequenceKeypoint.new(1, 0.35),
			}),
			Squash = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 0.8),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(0.2, 0.3),
				NumberSequenceKeypoint.new(0.75, 0.65),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.4, 0.75),
			Speed = NumberRange.new(1, 2.6),
			SpreadAngle = Vector2.new(22, 22),
			Acceleration = Vector3.new(0, 7, 0),
			Drag = 1,
			Rotation = NumberRange.new(-25, 25),
			RotSpeed = NumberRange.new(-45, 45),
			EmissionDirection = Enum.NormalId.Top,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ZOffset = 0.25,
			Rate = 30 * share,
		}, 5, isHead, ownHead and isHead)
		-- (it catches all at once: a first burst)
		core:Emit(math.ceil(10 * share))
		outer:Emit(math.ceil(8 * share))
		-- Embers floating up from the burning clothes.
		if name ~= "Right Leg" and name ~= "Left Leg" then
			addEmitter(session, host, {
				Name = "RiftBurnEmbers",
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(FLAME_YELLOW, EMBER),
				LightEmission = 1,
				LightInfluence = 0,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.09),
					NumberSequenceKeypoint.new(1, 0.02),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.7, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(1, 2),
				Speed = NumberRange.new(1.5, 3.5),
				SpreadAngle = Vector2.new(35, 35),
				Acceleration = Vector3.new(0, 2.5, 0),
				Drag = 1.2,
				EmissionDirection = Enum.NormalId.Top,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				Rate = 9 * share,
			}, 3, isHead, ownHead and isHead)
		end
		-- Thin black smoke rising above the shoulders and the head, and a
		-- faint pale haze through it (the air trembling over the fire).
		-- (our own: both rise through the camera in first person, hidden
		-- then)
		if name == "Torso" or isHead then
			local top = Instance.new("Attachment")
			top.Name = "RiftBurnTop"
			top.Position = Vector3.new(0, if isHead then 0.6 else 0.9, 0)
			top.Parent = host
			table.insert(session.emitters, top) -- (cleaned with them)
			addEmitter(session, top, {
				Name = "RiftBurnSmoke",
				Color = ColorSequence.new(SOOT, SMOKE_GREY),
				LightInfluence = 1,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.4),
					NumberSequenceKeypoint.new(1, 2.6),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.12, 0.64),
					NumberSequenceKeypoint.new(0.6, 0.82),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(1.4, 2.4),
				Speed = NumberRange.new(2, 3.5),
				SpreadAngle = Vector2.new(12, 12),
				Acceleration = Vector3.new(0.4, 2, 0),
				Drag = 0.6,
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-40, 40),
				EmissionDirection = Enum.NormalId.Top,
				Rate = if isHead then 5 else 8,
			}, nil, isHead, ownHead)
			addEmitter(session, top, {
				Name = "RiftBurnHaze",
				Color = ColorSequence.new(Color3.fromRGB(220, 214, 206)),
				LightInfluence = 1,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.8),
					NumberSequenceKeypoint.new(1, 2.2),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, 0.9),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(0.5, 0.9),
				Speed = NumberRange.new(3, 5),
				SpreadAngle = Vector2.new(18, 18),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-90, 90),
				EmissionDirection = Enum.NormalId.Top,
				Rate = 7,
			}, nil, isHead, ownHead)
		end
	end
	local torso = model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		local light = Instance.new("PointLight")
		light.Name = "RiftBurnLight"
		light.Color = FIRE_LIGHT
		light.Brightness = 2.4
		light.Range = 11
		light.Shadows = false
		light.Parent = torso
		session.light = light
	end
end

local function pourAcid(session: Session, ownHead: boolean)
	local model = session.model
	for _, name in BODY do
		local part = model:FindFirstChild(name)
		if not (part and part:IsA("BasePart")) then
			continue
		end
		local share = SHARE[name] or 0.3
		local isHead = name == "Head"
		local host = if isHead then headHost(session, part) else part
		-- Froth: pale foam crawling over the skin.
		addEmitter(session, host, {
			Name = "RiftBurnFroth",
			Color = ColorSequence.new(FROTH, FOAM),
			LightInfluence = 1,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.12),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(1, 0.22),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.35, 0.7),
			Speed = NumberRange.new(0.05, 0.3),
			Rotation = NumberRange.new(0, 360),
			EmissionDirection = Enum.NormalId.Top,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ZOffset = 0.1,
			Rate = 32 * share,
		}, 6, isHead, ownHead and isHead)
		-- Fizz: tiny green spatters jumping off and falling.
		addEmitter(session, host, {
			Name = "RiftBurnFizz",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(ACID, ACID_DARK),
			LightEmission = 0.35,
			Size = NumberSequence.new(0.08, 0.015),
			Transparency = NumberSequence.new(0.05, 1),
			Lifetime = NumberRange.new(0.2, 0.45),
			Speed = NumberRange.new(1.2, 3),
			SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0, -10, 0),
			EmissionDirection = Enum.NormalId.Top,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Rate = 24 * share,
		}, 8, isHead, ownHead and isHead)
		-- Caustic vapour: pale yellow-green, rising and spreading.
		addEmitter(session, host, {
			Name = "RiftBurnVapour",
			Color = ColorSequence.new(VAPOUR, Color3.fromRGB(150, 160, 120)),
			LightInfluence = 1,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(1, 2),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.62),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(0.6, 1.4),
			SpreadAngle = Vector2.new(25, 25),
			Acceleration = Vector3.new(0, 2.2, 0),
			Drag = 0.5,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-30, 30),
			EmissionDirection = Enum.NormalId.Top,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Rate = 10 * share,
		}, 2, isHead, ownHead and isHead)
	end
	-- The fizz of the bubbles popping (one emitter, moved to each pop).
	local point = Instance.new("Attachment")
	point.Name = "RiftBurnPopPoint"
	point.Parent = workspace.Terrain
	table.insert(session.emitters, point)
	session.popPoint = point
	session.pop = addEmitter(session, point, {
		Name = "RiftBurnPop",
		Color = ColorSequence.new(FROTH, FOAM),
		LightInfluence = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.06),
			NumberSequenceKeypoint.new(1, 0.22),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(0.6, 1.6),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -3, 0),
		Rotation = NumberRange.new(0, 360),
	}, nil, false)
	addBubbles(session, ownHead)
end

------------------------------------------------------------------------------
-- Start / stop
------------------------------------------------------------------------------

local function stopHeartbeatIfIdle()
	if next(sessions) == nil and next(tints) == nil and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local step: (number) -> ()

local function ensureHeartbeat()
	if heartbeat == nil then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
end

-- Stops the fading of ended patches (taken back, or wiped).
local function haltFade(fade: Fade)
	fade.token += 1
	for _, tween in fade.tweens do
		tween:Cancel()
	end
	table.clear(fade.tweens)
end

-- Everything of a model's burn gone now (destroyed, out of the game).
local function wipe(model: Model)
	local session = sessions[model]
	sessions[model] = nil
	if session then
		for _, item in session.emitters do
			item:Destroy()
		end
		if session.light then
			session.light:Destroy()
		end
		session.folder:Destroy()
	end
	for folder, fade in fading do
		if fade.model == model then
			fading[folder] = nil
			haltFade(fade)
			folder:Destroy()
		end
	end
	restoreTint(model)
	stopHeartbeatIfIdle()
end

local function play(fade: Fade, instance: Instance, info: TweenInfo, goal: { [string]: any })
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	table.insert(fade.tweens, tween)
end

-- The burn ends: the effects die out, the patches fade, the skin goes back
-- (slowly, in the Heartbeat).
local function stopBurning(model: Model)
	local session = sessions[model]
	sessions[model] = nil
	local tint = tints[model]
	if tint then
		tint.charGoal = 0
		tint.rawGoal = 0
	end
	if session == nil then
		return
	end
	local isFire = session.kind == "Fire"
	-- The flames die down (their rate falls), they don't just stop.
	local dieDown = TweenInfo.new(if isFire then 0.6 else 0.35, Enum.EasingStyle.Quad)
	for _, item in session.emitters do
		if item:IsA("ParticleEmitter") and item.Enabled and item.Rate > 0 then
			TweenService:Create(item, dieDown, { Rate = 0 }):Play()
		end
		Debris:AddItem(item, 2.6)
	end
	local light = session.light
	if light then
		TweenService
			:Create(light, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = 0, Range = 4 })
			:Play()
		Debris:AddItem(light, 1)
	end
	-- Bubbles pop at once.
	for _, bubble in session.bubbles do
		for _, part in bubble.parts do
			part:Destroy()
		end
	end
	-- Smouldering: grey smoke off the body for a while, thinning out.
	if isFire then
		for _, name in { "Torso", "Head", "Right Arm", "Left Arm" } do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				local smoke = emitter(part, {
					Name = "RiftBurnSmoulder",
					Color = ColorSequence.new(SMOKE_GREY, Color3.fromRGB(120, 116, 110)),
					LightInfluence = 1,
					Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.3),
						NumberSequenceKeypoint.new(1, 1.8),
					}),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.2, 0.6),
						NumberSequenceKeypoint.new(1, 1),
					}),
					Lifetime = NumberRange.new(1.2, 2),
					Speed = NumberRange.new(0.5, 1.2),
					SpreadAngle = Vector2.new(15, 15),
					Acceleration = Vector3.new(0, 1.8, 0),
					Rotation = NumberRange.new(0, 360),
					RotSpeed = NumberRange.new(-25, 25),
					EmissionDirection = Enum.NormalId.Top,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					Rate = (SHARE[name] or 0.5) * 12,
				})
				TweenService
					:Create(smoke, TweenInfo.new(SMOULDER, Enum.EasingStyle.Linear), { Rate = 0 })
					:Play()
				Debris:AddItem(smoke, SMOULDER + 2.1)
			end
		end
	end
	-- The patches stay a while, then fade (and go).
	local folder = session.folder
	local markFade = if isFire then MARK_FADE_FIRE else MARK_FADE_ACID
	local fade: Fade = {
		model = model,
		kind = session.kind,
		folder = folder,
		marks = session.marks,
		glows = session.glows,
		tweens = {},
		token = 0,
	}
	local now = os.clock()
	for _, mark in session.marks do
		if not mark.shown then
			continue -- (never showed: nothing built)
		end
		-- One still growing ends its growth (it doesn't freeze half-grown).
		if not mark.done then
			local left = (1 - math.min((now - mark.startedAt) / mark.grow, 1)) * mark.grow
			for _, item in mark.layers do
				play(
					fade,
					item.mesh,
					TweenInfo.new(math.max(left, 0.05), Enum.EasingStyle.Quad),
					{ Scale = Vector3.one }
				)
			end
			mark.done = true
		end
		for _, item in mark.layers do
			play(
				fade,
				item.part,
				TweenInfo.new(
					markFade * random:NextNumber(0.7, 1),
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.In
				),
				{ Transparency = 1 }
			)
		end
	end
	-- The glowing specks cool down to black char (and fade with the rest).
	local token = fade.token
	for _, speck in session.glows do
		local cool = random:NextNumber(0.8, 2)
		play(fade, speck, TweenInfo.new(cool, Enum.EasingStyle.Quad), { Color = CHAR })
		task.delay(cool, function()
			if fade.token == token and speck.Parent then
				speck.Material = Enum.Material.Slate
			end
		end)
	end
	folder.Name = "RiftBurnFading"
	fading[folder] = fade
	task.delay(markFade + 0.1, function()
		if fade.token == token and fading[folder] == fade then
			fading[folder] = nil
			folder:Destroy()
		end
	end)
	stopHeartbeatIfIdle()
end

-- The same burn again before the last one's patches are gone: take them
-- back (they are where the body burnt; a whole new set somewhere else
-- would pile up and jump around).
local function takeBack(model: Model, kind: string): Fade?
	for folder, fade in fading do
		if fade.model == model and fade.kind == kind then
			fading[folder] = nil
			haltFade(fade)
			if folder.Parent ~= model then
				folder:Destroy()
				return nil
			end
			return fade
		end
	end
	return nil
end

local function startBurning(model: Model, kind: string)
	local current = sessions[model]
	if current and current.kind == kind then
		return
	end
	stopBurning(model)
	if kind ~= "Fire" and kind ~= "Acid" then
		return
	end
	local back = takeBack(model, kind)
	local folder: Folder
	if back then
		folder = back.folder
	else
		folder = Instance.new("Folder")
		folder.Parent = model
	end
	folder.Name = "RiftBurn"
	local session: Session = {
		model = model,
		kind = kind,
		folder = folder,
		emitters = {},
		flickers = {},
		headEmitters = {},
		viewEmitters = {},
		light = nil,
		marks = {},
		glows = {},
		bubbles = {},
		pop = nil,
		popPoint = nil,
		nextDrip = os.clock() + 0.2,
		seed = random:NextNumber(0, 1000),
		headGone = false,
	}
	-- Our own head: no patches or bubbles on it (they'd block the camera in
	-- first person); its flames hide in first person (Heartbeat).
	local ownHead = model == Players.LocalPlayer.Character
	sessions[model] = session
	if back then
		-- The old patches come back as they were, the specks glow again; a
		-- few new ones join them.
		local now = os.clock()
		for _, mark in back.marks do
			local gone = mark.shown and (#mark.layers == 0 or mark.layers[1].part.Parent == nil)
			if mark.base.Parent == nil or gone then
				continue -- (its head burst)
			end
			if mark.shown then
				for _, item in mark.layers do
					item.part.Transparency = item.alpha
					item.mesh.Scale = Vector3.one
				end
			else
				mark.showAt = now + random:NextNumber(0, MARK_SPREAD)
			end
			table.insert(session.marks, mark)
		end
		for _, speck in back.glows do
			if speck.Parent then
				speck.Color = GLOW
				speck.Material = Enum.Material.Neon
				table.insert(session.glows, speck)
			end
		end
		addMarks(session, ownHead, 0.35)
	else
		addMarks(session, ownHead, 1)
	end
	if kind == "Fire" then
		lightFire(session, ownHead)
	else
		pourAcid(session, ownHead)
	end
	local tint = tintOf(model)
	if kind == "Fire" then
		tint.charGoal = 1
		tint.rawGoal = 0
	else
		tint.rawGoal = 1
		tint.charGoal = 0
	end
	ensureHeartbeat()
	SoundController.play(if kind == "Fire" then "Burn" else "AcidSizzle", model)
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function approach(value: number, goal: number, up: number, down: number, dt: number): number
	if value < goal then
		return math.min(value + up * dt, goal)
	end
	return math.max(value - down * dt, goal)
end

-- The head burst while it burns: its patches, bubbles and flames go.
local function dropHead(session: Session)
	session.headGone = true
	local onHead: { [ParticleEmitter]: boolean } = {}
	for _, item in session.headEmitters do
		item.Enabled = false
		onHead[item] = true
	end
	table.clear(session.headEmitters)
	for index = #session.viewEmitters, 1, -1 do
		if onHead[session.viewEmitters[index]] then
			table.remove(session.viewEmitters, index)
		end
	end
	for _, mark in session.marks do
		if mark.base.Name == "Head" then
			mark.done = true
			for _, item in mark.layers do
				item.part:Destroy()
			end
		end
	end
	for _, bubble in session.bubbles do
		if bubble.base.Name == "Head" then
			bubble.nextAt = math.huge -- (never built if it wasn't yet)
			bubble.popAt = 0
			for _, part in bubble.parts do
				part:Destroy()
			end
		end
	end
end

step = function(_dt: number)
	local now = os.clock()
	budget = BUILD_PER_FRAME
	for model, session in sessions do
		if not session.headGone and HeadBlast.isBlown(model) then
			dropHead(session)
		end
		if session.kind == "Fire" then
			-- Flicker: each layer's rate wanders (smooth noise), the light
			-- throbs and jumps with it.
			for _, flicker in session.flickers do
				local n = math.noise(now * flicker.speed, flicker.seed)
				flicker.emitter.Rate = flicker.rate * math.max(0.75 + n * 1.4, 0.15)
			end
			local light = session.light
			if light then
				local slow = math.noise(now * 3, session.seed)
				local fast = math.noise(now * 13, session.seed + 7.7)
				light.Brightness = math.max(2.4 + slow * 2.2 + fast * 1.2, 0.6)
				light.Range = 10.5 + slow * 2.5
			end
		else
			stepBubbles(session, now)
			if now >= session.nextDrip then
				session.nextDrip = now + random:NextNumber(0.12, 0.32)
				drip(session)
			end
		end
		stepMarks(session, now)
		-- Our own first person: the flames / fumes around the head would
		-- fill the view.
		if #session.viewEmitters > 0 and model == Players.LocalPlayer.Character then
			local head = model:FindFirstChild("Head")
			local hidden = head ~= nil
				and head:IsA("BasePart")
				and head.LocalTransparencyModifier > 0.5
			for _, item in session.viewEmitters do
				item.Enabled = not hidden
			end
		end
	end
	-- The skin tints, ten times a second (slow changes: no visible steps).
	for model, tint in tints do
		local elapsed = now - tint.applied
		if elapsed < 0.1 then
			continue
		end
		tint.applied = now
		elapsed = math.min(elapsed, 0.5)
		tint.char = approach(tint.char, tint.charGoal, CHAR_ON, CHAR_OFF, elapsed)
		tint.raw = approach(tint.raw, tint.rawGoal, RAW_ON, RAW_OFF, elapsed)
		-- (new skin pieces: a cut, gore; looked for once a second)
		if now - tint.scanned >= 1 then
			tint.scanned = now
			rescan(tint)
		end
		local faded = tint.char <= 0 and tint.raw <= 0 and tint.charGoal <= 0 and tint.rawGoal <= 0
		if faded and not headIsBusy(model, tint, now) then
			restoreTint(model)
		elseif not faded then
			applyTint(model, tint, now)
		end
	end
	stopHeartbeatIfIdle()
end

------------------------------------------------------------------------------
-- Watching a model
------------------------------------------------------------------------------

local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- A copy of a burning body (a clone): its effects and its tint were copied
-- too; take them off (it burns again only if its own attribute says so).
local function scrubCopy(model: Model)
	for _, item in model:GetDescendants() do
		if string.sub(item.Name, 1, 8) == "RiftBurn" and item ~= model then
			if item:IsA("BasePart") and item:GetAttribute(ORIGINAL_ATTRIBUTE) ~= nil then
				continue -- (a body part: only its colour)
			end
			item:Destroy()
		end
	end
	for _, name in BODY do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local saved = part:GetAttribute(ORIGINAL_ATTRIBUTE)
			if typeof(saved) == "Color3" then
				-- (its skin pieces wear the tinted colour it had)
				for _, piece in findCopies(part, saved, part.Color) do
					piece.Color = saved
				end
				part.Color = saved
				part:SetAttribute(ORIGINAL_ATTRIBUTE, nil)
			end
		end
	end
end

function RiftBurn.watch(model: Model)
	if watched[model] then
		return
	end
	watched[model] = true
	scrubCopy(model)
	local function refresh()
		if not model:IsDescendantOf(game) then
			return
		end
		local kind = model:GetAttribute("Burning")
		local body = model:FindFirstChildOfClass("Humanoid")
		local alive = body == nil or body.Health > 0
		if typeof(kind) == "string" and alive then
			startBurning(model, kind)
		else
			stopBurning(model)
		end
	end
	local changed = model:GetAttributeChangedSignal("Burning"):Connect(refresh)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local died: RBXScriptConnection? = if humanoid
		then humanoid.Died:Connect(function()
			stopBurning(model)
		end)
		else nil
	local moved: RBXScriptConnection
	moved = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(game) then
			wipe(model)
		else
			refresh() -- (back in the game: streaming)
		end
	end)
	model.Destroying:Once(function()
		changed:Disconnect()
		moved:Disconnect()
		if died then
			died:Disconnect()
		end
		watched[model] = nil
		wipe(model)
	end)
	refresh()
end

return RiftBurn
