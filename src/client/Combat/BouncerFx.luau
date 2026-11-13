--!strict
-- BouncerFx: what the Bouncer's moves look like when they land (Shared/Kits/
-- Bouncer). Purely visual, on this client; the server decided everything.
--
--   • A body driven into the floor (Body Slam, Powerbomb, a thrown body
--     landing): a ring of dust kicked up from the floor's own colour, chips
--     of it, a ripple of air low along the ground, the camera shaking for
--     whoever is close (more the closer).
--   • Hammer fists: sweat and spit thrown off the head.
--   • A shove: the feet scraping back, a puff of dust under them.
--   • A choke: the face going red-violet then deep violet with each squeeze, spit at the
--     lips; for the one choked, the edges of the screen closing in (black at
--     the end of a Sleeper Hold). It all fades back when they breathe again.
--   • The Awakening: a stamp of dust at his feet when he squares up, his
--     breath steaming.
--
--   BouncerFx.onHit(victim, attacker, moveId, shake)   a move landed
--   BouncerFx.onAction(model, animation)                a move / clip started
-- `shake(strength, seconds)` shakes our camera (CombatEffectsController).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BouncerFx = {}

export type Shake = (strength: number, seconds: number) -> ()

local player = Players.LocalPlayer

local DUST = Color3.fromRGB(150, 142, 128)
local SPIT = Color3.fromRGB(226, 226, 220)
-- (a choked face: red-violet, then deep violet - never a plain red)
local CHOKED_RED = Color3.fromRGB(148, 52, 96)
local CHOKED_PURPLE = Color3.fromRGB(98, 40, 104)
local SHAKE_RANGE = 40 -- studs: farther, the camera doesn't feel a slam

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

-- The floor under `position`: where, and its colour (dust looks like it).
local function floorUnder(position: Vector3, ignore: { Instance }): (Vector3?, Color3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -8, 0), params)
	if hit == nil then
		return nil, DUST
	end
	local part = hit.Instance
	local color = if part:IsA("BasePart") and not part:IsA("Terrain")
		then part.Color:Lerp(DUST, 0.55)
		else DUST
	return hit.Position, color
end

local function attachmentAt(position: Vector3): Attachment
	local point = Instance.new("Attachment")
	point.WorldPosition = position
	point.Parent = workspace.Terrain
	return point
end

local function dustEmitter(parent: Attachment, color: Color3): ParticleEmitter
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.15))
	dust.LightEmission = 0
	dust.LightInfluence = 1
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.4, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 2.6),
	})
	dust.Lifetime = NumberRange.new(0.8, 1.6)
	dust.Speed = NumberRange.new(6, 12)
	dust.SpreadAngle = Vector2.new(80, 8) -- out along the floor, not up
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Drag = 3.5
	dust.Acceleration = Vector3.new(0, 0.6, 0)
	dust.RotSpeed = NumberRange.new(-40, 40)
	dust.Rotation = NumberRange.new(0, 360)
	dust.Rate = 0
	dust.Parent = parent
	return dust
end

local function chip(at: Vector3, color: Color3, velocity: Vector3)
	local piece = Instance.new("Part")
	piece.Name = "Debris"
	local s = math.random() * 0.12 + 0.05
	piece.Size = Vector3.new(s * 1.4, s * 0.5, s)
	piece.Material = Enum.Material.Concrete
	piece.Color = color:Lerp(Color3.new(0, 0, 0), 0.15)
	piece.CanCollide = true
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CFrame = CFrame.new(at)
		* CFrame.Angles(math.random() * 6.3, math.random() * 6.3, math.random() * 6.3)
	piece.AssemblyLinearVelocity = velocity
	piece.AssemblyAngularVelocity = Vector3.new(
		math.random() - 0.5,
		math.random() - 0.5,
		math.random() - 0.5
	) * 25
	piece.Parent = workspace
	Debris:AddItem(piece, 5)
end

-- Our camera shakes for an impact at `position`, less with distance.
local function shakeNear(position: Vector3, strength: number, seconds: number, shake: Shake)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance < SHAKE_RANGE then
		local k = 1 - distance / SHAKE_RANGE
		shake(strength * k * k, seconds)
	end
end

------------------------------------------------------------------------------
-- A body driven into the floor
------------------------------------------------------------------------------

local function groundImpact(position: Vector3, size: number, ignore: { Instance }, shake: Shake)
	local floor, color = floorUnder(position, ignore)
	if floor == nil then
		return
	end
	local point = attachmentAt(floor + Vector3.new(0, 0.1, 0))
	local dust = dustEmitter(point, color)
	dust.Speed = NumberRange.new(6 * size, 12 * size)
	dust:Emit(math.floor(26 * size))
	-- a low, slow cloud hanging after it
	local haze = dustEmitter(point, color)
	haze.Speed = NumberRange.new(1, 3)
	haze.Lifetime = NumberRange.new(1.8, 2.8)
	haze.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 4 * size),
	})
	haze.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	haze:Emit(math.floor(8 * size))
	Debris:AddItem(point, 4)
	-- Chips of the floor thrown out.
	for _ = 1, math.floor(10 * size) do
		local angle = math.random() * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		chip(
			floor + out * 0.6 + Vector3.new(0, 0.15, 0),
			color,
			out * (6 + math.random() * 8) + Vector3.new(0, 6 + math.random() * 8, 0)
		)
	end
	-- A ripple of air, low along the floor (barely there).
	local ring = Instance.new("Part")
	ring.Name = "Shockwave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = color
	ring.Transparency = 0.6
	ring.Size = Vector3.new(0.08, 1, 1)
	ring.CFrame = CFrame.new(floor + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	TweenService:Create(
		ring,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.02, 9 * size, 9 * size), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, 0.5)
	shakeNear(floor, 2.4 * size, 0.45, shake)
end

-- A body thrown through the air: dust where it comes down.
local function watchLanding(victim: Model, shake: Shake)
	local torso = victim:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	local start = os.clock()
	local wasFalling = false
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - start
		if elapsed > 2.5 or torso.Parent == nil then
			if connection then
				connection:Disconnect()
			end
			return
		end
		local vy = torso.AssemblyLinearVelocity.Y
		if vy < -8 then
			wasFalling = true
		end
		if wasFalling and vy > -2 and elapsed > 0.15 then
			if connection then
				connection:Disconnect()
			end
			groundImpact(torso.Position, 0.8, { victim }, shake)
		end
	end)
end

------------------------------------------------------------------------------
-- Sprays off a head, feet scraping
------------------------------------------------------------------------------

local function spray(head: BasePart, attacker: Model, count: number, color: Color3)
	local point = Instance.new("Attachment")
	-- out of the face, away from him
	local away = head.Position - attacker:GetPivot().Position
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.1 then away.Unit else -head.CFrame.LookVector
	point.WorldCFrame = CFrame.lookAt(head.Position, head.Position + away + Vector3.new(0, 0.3, 0))
	point.Parent = workspace.Terrain
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = "rbxasset://textures/particles/smoke_main.dds"
	drops.Color = ColorSequence.new(color)
	drops.LightEmission = 0.1
	drops.LightInfluence = 1
	drops.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	drops.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.07),
		NumberSequenceKeypoint.new(1, 0.03),
	})
	drops.Lifetime = NumberRange.new(0.3, 0.6)
	drops.Speed = NumberRange.new(5, 11)
	drops.SpreadAngle = Vector2.new(35, 35)
	drops.Acceleration = Vector3.new(0, -50, 0)
	drops.EmissionDirection = Enum.NormalId.Front
	drops.Rate = 0
	drops.Parent = point
	drops:Emit(count)
	Debris:AddItem(point, 1)
end

local function scrape(victim: Model, seconds: number)
	local feet: { BasePart } = {}
	for _, name in { "Right Leg", "Left Leg" } do
		local leg = victim:FindFirstChild(name)
		if leg and leg:IsA("BasePart") then
			table.insert(feet, leg)
		end
	end
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < seconds do
			for _, leg in feet do
				if leg.Parent then
					local sole = leg.Position - Vector3.new(0, leg.Size.Y / 2, 0)
					local floor, color = floorUnder(sole, { victim })
					if floor then
						local point = attachmentAt(floor + Vector3.new(0, 0.1, 0))
						local dust = dustEmitter(point, color)
						dust.Speed = NumberRange.new(1, 3)
						dust.Size = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.4),
							NumberSequenceKeypoint.new(1, 1.2),
						})
						dust:Emit(3)
						Debris:AddItem(point, 2)
					end
				end
			end
			task.wait(0.06)
		end
	end)
end

------------------------------------------------------------------------------
-- Choked: the face, and (if it's us) the screen
------------------------------------------------------------------------------

type Choked = { squeezes: number, skin: Color3, head: BasePart, fade: Tween? }
local choked: { [Model]: Choked } = setmetatable({}, { __mode = "k" }) :: any
-- Each head's own colour, read once before it is ever tinted (a new choke
-- while the last one is still fading must not take the red for the skin).
local trueSkin: { [BasePart]: Color3 } = setmetatable({}, { __mode = "k" }) :: any
local vignette: ColorCorrectionEffect? = nil

local function ourVignette(): ColorCorrectionEffect?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local effect = vignette
	if effect == nil or effect.Parent == nil then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "Choked"
		made.Parent = camera
		vignette = made
		effect = made
	end
	return effect
end

local function squeeze(victim: Model, attacker: Model, sleeper: boolean)
	local head = victim:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local known: Color3? = trueSkin[head]
	local skin: Color3 = known or head.Color
	if known == nil then
		trueSkin[head] = skin
	end
	local entry = choked[victim]
	if entry == nil or entry.head ~= head then
		entry = { squeezes = 0, skin = skin, head = head, fade = nil }
		choked[victim] = entry
		victim.Destroying:Once(function()
			choked[victim] = nil
		end)
	end
	local current: Choked = entry
	if current.fade then
		current.fade:Cancel()
		current.fade = nil
	end
	current.squeezes += 1
	-- red, then purple
	local k = math.min(1, current.squeezes / 4)
	local target = if k < 0.5
		then current.skin:Lerp(CHOKED_RED, k * 1.4)
		else CHOKED_RED:Lerp(CHOKED_PURPLE, (k - 0.5) * 2)
	TweenService:Create(head, TweenInfo.new(0.35), { Color = target }):Play()
	spray(head, attacker, 6, SPIT)
	if victim == player.Character then
		local effect = ourVignette()
		if effect then
			local dark = if sleeper then -0.18 * current.squeezes else -0.1 * current.squeezes
			TweenService:Create(effect, TweenInfo.new(0.3), {
				Brightness = math.max(dark, -0.75),
				Saturation = -0.25 * k,
				Contrast = 0.15 * k,
			}):Play()
		end
	end
end

-- They breathe again ("Held" gone): the colour comes back, the screen clears.
local function breathe(victim: Model)
	local entry = choked[victim]
	if entry == nil then
		return
	end
	choked[victim] = nil
	if entry.head.Parent then
		TweenService
			:Create(entry.head, TweenInfo.new(4, Enum.EasingStyle.Quad), { Color = entry.skin })
			:Play()
	end
	if victim == player.Character and vignette then
		TweenService:Create(vignette, TweenInfo.new(1.6, Enum.EasingStyle.Quad), {
			Brightness = 0,
			Saturation = 0,
			Contrast = 0,
		}):Play()
	end
end

------------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------------

function BouncerFx.onHit(victim: Model, attacker: Model, moveId: string, shake: Shake)
	local head = victim:FindFirstChild("Head")
	local torso = victim:FindFirstChild("Torso")
	if moveId == "BodySlam_Hold" or moveId == "Powerbomb_Hold" then
		if torso and torso:IsA("BasePart") then
			local size = if moveId == "Powerbomb_Hold" then 1.35 else 1.1
			groundImpact(torso.Position, size, { victim, attacker }, shake)
		end
		if head and head:IsA("BasePart") then
			spray(head, attacker, 10, SPIT)
		end
	elseif moveId == "ThrowOut_Hold" then
		watchLanding(victim, shake)
	elseif moveId == "HammerFist" or moveId == "DoubleHammer" then
		if head and head:IsA("BasePart") then
			spray(head, attacker, 12, SPIT)
			shakeNear(head.Position, 0.9, 0.25, shake)
		end
	elseif moveId == "Shove" then
		scrape(victim, 0.3)
	elseif moveId == "Chokehold_Hold" or moveId == "SleeperHold_Hold" then
		-- (only while held: the Sleeper's last blow drops them, let go)
		if victim:GetAttribute("Held") ~= nil then
			squeeze(victim, attacker, moveId == "SleeperHold_Hold")
		end
	end
end

function BouncerFx.onAction(model: Model, animation: string)
	if animation == "Bouncer_Awaken" then
		-- squares up at 0.55-0.7 s: a stamp of dust, breath steaming
		task.delay(0.62, function()
			if model.Parent == nil then
				return
			end
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local floor, color = floorUnder(root.Position - Vector3.new(0, 2.5, 0), { model })
				if floor then
					local point = attachmentAt(floor + Vector3.new(0, 0.1, 0))
					local dust = dustEmitter(point, color)
					dust.Speed = NumberRange.new(3, 7)
					dust:Emit(16)
					Debris:AddItem(point, 3)
				end
			end
			local head = model:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				local point = Instance.new("Attachment")
				point.Position = Vector3.new(0, -0.15, -0.55)
				point.Parent = head
				local breath = dustEmitter(point, Color3.fromRGB(235, 235, 235))
				breath.EmissionDirection = Enum.NormalId.Front
				breath.SpreadAngle = Vector2.new(15, 15)
				breath.Speed = NumberRange.new(2, 4)
				breath.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.15),
					NumberSequenceKeypoint.new(1, 0.9),
				})
				breath.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.7),
					NumberSequenceKeypoint.new(1, 1),
				})
				breath:Emit(10)
				Debris:AddItem(point, 2)
			end
		end)
	end
end

-- (CombatEffectsController: "Held" changed on a fighter)
function BouncerFx.onReleased(victim: Model)
	breathe(victim)
end

return table.freeze(BouncerFx)
