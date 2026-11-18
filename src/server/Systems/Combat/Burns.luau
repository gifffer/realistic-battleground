--!strict
-- Burns (server): where a body is burnt, how deep, and what burns now.
-- Every burn source goes through here (Dr. Rift's acid, ray and explosive
-- flask, the Pyromaniac's fire, anything else): Combat's startBurning
-- keeps the damage over time and the "Burning" attribute; this module adds
-- the body's burns, written as attributes (Shared/Util/BurnCode), which
-- every client draws (Client/Combat/Burns), a corpse copy too.
--
--   Burns.expose(model, burn, zone?, from?, noFlame?)  a burn lands: on the part of
--       `zone` ("Head" / "Torso" / "Legs"; nil = the feet, a burning floor)
--       on the face turned toward `from`. A focused burn (burn.spot: a
--       laser / ray) leaves a deep spot there and little around it.
--       `noFlame`: only the mark (the heat vision's cooked skin).
--   Burns.ignite(model, kind, perSecond, duration)  it keeps burning
--       (startBurning): the burnt parts deepen; fire spreads to the parts
--       next to them, upward first.
--   Burns.extinguish(model)  out (the burn ended, or a death): the flames
--       go (a burning body goes on a few seconds after death), it
--       smoulders, the degrees settle.
--   Burns.clear(model)       healed (a kill, a new round): no burns left.
--   Burns.watch(model)       a fighter: "Burning" set from outside (a
--       finisher's attributes) sets it on fire all over; cleared, it's out.
--   Burns.start()            the loop, corpse copies.
--
-- How deep: degree 0..4 per face. Fire adds FIRE_RATE degrees a second on
-- each face of a part in flames (a stronger burn more), acid ACID_RATE on
-- the faces it touched (never past 3). Settled degrees round to a stage
-- (a burn deepens once it's out, like a real one).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BurnCode = require(ReplicatedStorage.Shared.Util.BurnCode)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Corpses = require(script.Parent.Parent.Corpses)

type Kind = BurnCode.Kind

local Burns = {}

local FIRE_RATE = 0.42 -- degrees / s on a part fully in flames
local ACID_RATE = 0.22 -- degrees / s on the faces the acid touched
local ACID_MAX = 3
local SPOT_RATE = 0.35 -- a laser spot deepens this fast while it burns
local LIT_GROW = 0.45 -- flames get going (share / s)
local SPREAD_AFTER = 1.2 -- s in flames before it can catch next door
local SPREAD_UP = 0.5 -- chance / s to catch a part above (flames rise)
local SPREAD_SIDE = 0.2
local SPREAD_DOWN = 0.08
local SPOT_SPREAD = 0.15 -- a laser burn barely spreads (its clothes catch)
local AFTER_DEATH = 4 -- s a burning body goes on burning once dead
local SMOKE_AFTER = 18 -- s of smouldering after a deep fire
local SMOKE_LIGHT = 6 -- after a light one
local CORPSE_BURN = 8 -- s a corpse copy burns on, if its body was alight
local WRITE_EVERY = 0.2

-- Which parts touch which (to spread), and which way it is from there.
local NEXT: { [string]: { { string } } } = {
	Torso = { { "Head", "up" }, { "Right Arm", "side" }, { "Left Arm", "side" }, { "Right Leg", "down" }, { "Left Leg", "down" } },
	Head = { { "Torso", "down" } },
	["Right Arm"] = { { "Torso", "up" } },
	["Left Arm"] = { { "Torso", "up" } },
	["Right Leg"] = { { "Torso", "up" }, { "Left Leg", "side" } },
	["Left Leg"] = { { "Torso", "up" }, { "Right Leg", "side" } },
}
-- Acid runs down: a share of it reaches the part below.
local BELOW: { [string]: string } = {
	Head = "Torso",
	Torso = "Right Leg",
	["Right Arm"] = "Right Arm",
	["Left Arm"] = "Left Arm",
}
-- Opposite face index (FACES order: Right, Left, Top, Bottom, Back, Front).
local OPPOSITE = { 2, 1, 4, 3, 6, 5 }

type PartState = {
	kind: Kind,
	faces: { number },
	spots: { BurnCode.Spot },
	lit: number, -- 0..1 in flames (fire) / acid still eating (acid)
	litSince: number,
	spot: boolean, -- lit by a focused burn (a laser): it stays small
	written: string?,
}

type Entry = {
	model: Model,
	parts: { [string]: PartState },
	active: boolean,
	kind: Kind?,
	rate: number, -- damage / s of the burn: a stronger one burns deeper
	endsAt: number?, -- burns out by itself at this time (after death, corpse copy)
	nextWrite: number,
	litWritten: string?,
	watched: boolean,
}

local entries: { [Model]: Entry } = {}
local random = Random.new()
local heartbeat: RBXScriptConnection? = nil

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function entryOf(model: Model): Entry
	local entry = entries[model]
	if entry == nil then
		local created: Entry = {
			model = model,
			parts = {},
			active = false,
			kind = nil,
			rate = 3,
			endsAt = nil,
			nextWrite = 0,
			litWritten = nil,
			watched = false,
		}
		entry = created
		entries[model] = created
		model.Destroying:Once(function()
			entries[model] = nil
		end)
	end
	return entry
end

local function partState(entry: Entry, partName: string, kind: Kind): PartState
	local state = entry.parts[partName]
	if state == nil then
		state = {
			kind = kind,
			faces = table.create(6, 0),
			spots = {},
			lit = 0,
			litSince = 0,
			spot = false,
			written = nil,
		}
		entry.parts[partName] = state
	elseif kind == "Fire" and state.kind == "Acid" then
		state.kind = "Fire" -- (fire over an acid burn: it reads as fire now)
	end
	return state
end

local function maxOf(kind: Kind): number
	return if kind == "Acid" then ACID_MAX else BurnCode.MAX_DEGREE
end

local function add(state: PartState, face: number, amount: number)
	state.faces[face] = math.min(maxOf(state.kind), state.faces[face] + amount)
end

-- Adds `amount` on `face`, less around it, least on the far side.
local function dose(state: PartState, face: number, amount: number, around: number, far: number)
	for index = 1, 6 do
		if index == face then
			add(state, index, amount)
		elseif index == OPPOSITE[face] then
			add(state, index, amount * far)
		else
			add(state, index, amount * around)
		end
	end
end

local function light(state: PartState, amount: number, spot: boolean)
	if state.lit <= 0 then
		state.litSince = os.clock()
		state.spot = spot
	elseif not spot then
		state.spot = false
	end
	state.lit = math.max(state.lit, amount)
end

local function bodyPart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- Writes what changed (throttled by the loop; `force` now).
local function write(entry: Entry, force: boolean)
	local time = os.clock()
	if not force and time < entry.nextWrite then
		return
	end
	entry.nextWrite = time + WRITE_EVERY
	local model = entry.model
	local lit: { [string]: number } = {}
	for partName, state in entry.parts do
		local attribute = BurnCode.attribute(partName)
		if attribute == nil then
			continue
		end
		local any = #state.spots > 0
		for index = 1, 6 do
			if state.faces[index] >= 0.125 then
				any = true
			end
		end
		local text = if any then BurnCode.encode(state) else nil
		if text ~= state.written then
			state.written = text
			model:SetAttribute(attribute, text)
		end
		if state.lit > 0 then
			lit[BurnCode.CODE_OF[partName]] = if state.lit > 0.7 then 3 elseif state.lit > 0.35 then 2 else 1
		end
	end
	local litText = BurnCode.encodeLit(lit)
	if litText ~= entry.litWritten then
		entry.litWritten = litText
		model:SetAttribute(BurnCode.LIT, litText)
	end
end

local putOut: (entry: Entry) -> ()

local function step(dt: number)
	local any = false
	local time = os.clock()
	for model, entry in entries do
		if model.Parent == nil then
			continue
		end
		local busy = false
		local scale = math.clamp(entry.rate / 3, 0.6, 1.6)
		for partName, state in entry.parts do
			if state.lit <= 0 then
				continue
			end
			busy = true
			if state.kind == "Fire" then
				local cap = if state.spot then 0.5 else 1
				state.lit = math.min(cap, state.lit + LIT_GROW * dt)
				local amount = FIRE_RATE * dt * state.lit * scale
				for index = 1, 6 do
					-- (the underside of a limb burns less: flames go up)
					add(state, index, if index == 4 then amount * 0.5 else amount)
				end
				for _, spot in state.spots do
					spot.degree = math.min(BurnCode.MAX_DEGREE, spot.degree + SPOT_RATE * dt)
				end
				-- Spread to the parts next to it.
				if time - state.litSince >= SPREAD_AFTER then
					for _, link in NEXT[partName] or {} do
						local other = entry.parts[link[1]]
						if other and other.lit > 0 then
							continue
						end
						local chance = if link[2] == "up"
							then SPREAD_UP
							elseif link[2] == "side" then SPREAD_SIDE
							else SPREAD_DOWN
						if state.spot then
							chance *= SPOT_SPREAD
						end
						if random:NextNumber() < chance * state.lit * dt and bodyPart(model, link[1]) then
							local caught = partState(entry, link[1], "Fire")
							light(caught, 0.25, false)
							-- (it catches at the side touching the fire)
							dose(caught, if link[2] == "up" then 4 elseif link[2] == "down" then 3 else 6, 0.4, 0.2, 0.05)
						end
					end
				end
			else
				for index = 1, 6 do
					if state.faces[index] > 0 then
						add(state, index, ACID_RATE * dt * scale)
					end
				end
			end
		end
		local endsAt = entry.endsAt
		if endsAt and serverNow() >= endsAt then
			putOut(entry)
			busy = false
		end
		if busy then
			any = true
			write(entry, false)
		end
	end
	if not any and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function ensureLoop()
	if heartbeat == nil then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
end

-- Where on a part a burn coming from `from` lands: the face toward it, and
-- the point where the line from there to the part's middle goes in.
local function landing(part: BasePart, from: Vector3?): (number, Vector3)
	if from == nil then
		local face = random:NextInteger(1, 6)
		return face, BurnCode.NORMALS[face] * part.Size / 2
	end
	local offset = part.CFrame:PointToObjectSpace(from)
	if offset.Magnitude < 1e-3 then
		offset = Vector3.new(0, 0, -1)
	end
	local half = part.Size / 2
	-- scale the direction up to the box's surface
	local t = math.huge
	local ax, ay, az = math.abs(offset.X), math.abs(offset.Y), math.abs(offset.Z)
	if ax > 1e-4 then
		t = math.min(t, half.X / ax)
	end
	if ay > 1e-4 then
		t = math.min(t, half.Y / ay)
	end
	if az > 1e-4 then
		t = math.min(t, half.Z / az)
	end
	local point = offset * t
	return BurnCode.faceToward(point / half), point
end

local function zoneParts(model: Model, zone: string?, from: Vector3?): { string }
	if zone == "Head" then
		return { "Head" }
	elseif zone == "Torso" then
		return { "Torso" }
	elseif zone == "Legs" then
		-- the leg nearer to where it came from
		local right = bodyPart(model, "Right Leg")
		local left = bodyPart(model, "Left Leg")
		if right and left and from then
			return {
				if (right.Position - from).Magnitude <= (left.Position - from).Magnitude
					then "Right Leg"
					else "Left Leg",
			}
		end
		return { "Right Leg" }
	end
	return { "Right Leg", "Left Leg" } -- (a floor on fire / an acid puddle: the feet)
end

function Burns.expose(model: Model, burn: Kits.BurnDef, zone: string?, from: Vector3?, noFlame: boolean?)
	local entry = entryOf(model)
	local kind: Kind = if burn.kind == "Acid" then "Acid" else "Fire"
	local focused = burn.spot == true and kind == "Fire"
	local strength = math.clamp(burn.perSecond / 3, 0.6, 1.6)
	for _, partName in zoneParts(model, zone, from) do
		local part = bodyPart(model, partName)
		if part == nil then
			continue
		end
		local state = partState(entry, partName, kind)
		if zone == nil then
			-- standing in it: the soles and the lower legs
			add(state, 4, 0.9 * strength)
			for _, face in { 1, 2, 5, 6 } do
				add(state, face, 0.45 * strength)
			end
		else
			local face, point = landing(part, from)
			if focused then
				-- a laser: a deep spot where it went in, redness around
				local u, v = BurnCode.faceUV(part.Size, face, point)
				u = math.clamp(u + random:NextNumber(-0.12, 0.12), 0.15, 0.85)
				v = math.clamp(v + random:NextNumber(-0.12, 0.12), 0.15, 0.85)
				local merged = false
				for _, spot in state.spots do
					if spot.face == face and math.abs(spot.u - u) + math.abs(spot.v - v) < 0.3 then
						spot.degree = math.min(BurnCode.MAX_DEGREE, spot.degree + 0.8 * strength)
						merged = true
						break
					end
				end
				if not merged then
					if #state.spots >= BurnCode.MAX_SPOTS then
						table.remove(state.spots, 1)
					end
					table.insert(state.spots, { face = face, u = u, v = v, degree = 2.6 * strength })
				end
				dose(state, face, 0.7, 0.2, 0)
			elseif kind == "Fire" then
				dose(state, face, 1.0 * strength, 0.4, 0.1)
			else
				dose(state, face, 1.0 * strength, 0.3, 0)
				-- it runs down onto the part below
				local below = BELOW[partName]
				if below and bodyPart(model, below) then
					local under = partState(entry, below, "Acid")
					add(under, face, 0.5 * strength)
				end
			end
		end
		if noFlame then
			continue
		elseif kind == "Fire" then
			light(state, if focused then 0.3 else 0.5, focused)
		else
			light(state, 0.5, false)
		end
	end
	if entry.active then
		ensureLoop()
	end
	write(entry, true)
end

function Burns.ignite(model: Model, kind: string, perSecond: number, _duration: number)
	local entry = entryOf(model)
	local burnKind: Kind = if kind == "Acid" then "Acid" else "Fire"
	entry.active = true
	entry.kind = burnKind
	entry.rate = perSecond
	entry.endsAt = nil
	local anyLit = false
	for _, state in entry.parts do
		if state.lit > 0 then
			anyLit = true
		end
	end
	if not anyLit then
		-- (burning with nothing touched yet: it starts at the chest)
		Burns.expose(model, { kind = burnKind, perSecond = perSecond, duration = 0 }, "Torso", nil)
	end
	ensureLoop()
	write(entry, true)
end

-- Set on fire all over at once (a body doused and lit).
local function engulf(model: Model, kind: Kind)
	local entry = entryOf(model)
	for _, partName in BurnCode.PARTS do
		if bodyPart(model, partName) then
			local state = partState(entry, partName, kind)
			light(state, 0.6, false)
			for index = 1, 6 do
				add(state, index, 0.5)
			end
		end
	end
	entry.active = true
	entry.kind = kind
	entry.endsAt = nil
	entry.rate = math.max(entry.rate, 4)
	ensureLoop()
	write(entry, true)
end

local function settle(degree: number): number
	-- a burn left half-way deepens to the next stage (or stays light)
	if degree < 1 then
		return BurnCode.quantize(degree)
	end
	local whole = math.floor(degree)
	return if degree - whole >= 0.45 then math.min(whole + 1, BurnCode.MAX_DEGREE) else whole
end

function putOut(entry: Entry)
	local deep = false
	local fire = false
	for _, state in entry.parts do
		if state.lit > 0 and state.kind == "Fire" then
			fire = true
		end
		state.lit = 0
		state.spot = false
		for index = 1, 6 do
			state.faces[index] = math.min(maxOf(state.kind), settle(state.faces[index]))
			if state.faces[index] >= 2 then
				deep = true
			end
		end
		for _, spot in state.spots do
			spot.degree = settle(spot.degree)
		end
	end
	entry.active = false
	entry.kind = nil
	entry.endsAt = nil
	if not entry.watched then
		entry.model:SetAttribute("Burning", nil) -- (a corpse copy: nobody else will)
	end
	if fire then
		entry.model:SetAttribute(BurnCode.SMOKE, serverNow() + (if deep then SMOKE_AFTER else SMOKE_LIGHT))
	end
	write(entry, true)
end

function Burns.extinguish(model: Model)
	local entry = entries[model]
	if entry == nil or (not entry.active and entry.endsAt == nil) then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local dead = humanoid ~= nil and humanoid.Health <= 0
	if dead and entry.active and entry.kind == "Fire" and entry.endsAt == nil then
		-- (a burning body doesn't go out when it dies: a few seconds more)
		entry.active = false
		entry.endsAt = serverNow() + AFTER_DEATH
		ensureLoop()
		return
	end
	putOut(entry)
end

function Burns.clear(model: Model)
	local entry = entries[model]
	entries[model] = nil
	if entry then
		entry.active = false
	end
	for name in model:GetAttributes() do
		if BurnCode.isAttribute(name) then
			model:SetAttribute(name, nil)
		end
	end
end

function Burns.isBurning(model: Model): boolean
	local entry = entries[model]
	return entry ~= nil and (entry.active or entry.endsAt ~= nil)
end

-- A fighter: "Burning" set by something else than startBurning (a
-- finisher sets it itself) puts them on fire all over; cleared, it's out.
function Burns.watch(model: Model)
	local entry = entryOf(model)
	if entry.watched then
		return
	end
	entry.watched = true
	model:GetAttributeChangedSignal("Burning"):Connect(function()
		local value = model:GetAttribute("Burning")
		local current = entries[model]
		if typeof(value) == "string" then
			if current == nil or not current.active then
				engulf(model, if value == "Acid" then "Acid" else "Fire")
			end
		elseif current and current.active then
			Burns.extinguish(model)
		end
	end)
end

function Burns.start()
	-- A corpse copy takes the body's burns; alight, it burns on a while.
	Corpses.onCopy(function(copy: Model, original: Model)
		local source = entries[original]
		if source == nil then
			return
		end
		local entry = entryOf(copy)
		for partName, state in source.parts do
			entry.parts[partName] = {
				kind = state.kind,
				faces = table.clone(state.faces),
				spots = table.clone(state.spots),
				lit = state.lit,
				litSince = state.litSince,
				spot = state.spot,
				written = copy:GetAttribute(BurnCode.attribute(partName) or "") :: string?,
			}
		end
		entry.rate = source.rate
		entry.kind = source.kind
		entry.litWritten = copy:GetAttribute(BurnCode.LIT) :: string?
		if source.active or source.endsAt ~= nil then
			entry.endsAt = serverNow() + CORPSE_BURN
			ensureLoop()
		end
	end)
end

return Burns
