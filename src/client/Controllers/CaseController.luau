--!strict
-- CaseController: the BX-7 case in people's hands, on THIS screen (the server decides who
-- holds a case: Server/Systems/Contraband/Case).
--
--   • THE HELD CASE: every character with the attribute Carrying = "Case" gets a local copy
--     of the case (Shared/Contraband/CaseModel) welded to its LEFT arm. Nothing about it is
--     sent over the network: each client draws it from the attribute, like a held weapon.
--     It hangs from the fist and swings a little like a heavy pendulum: it lags behind when
--     the body speeds up, stops or turns (a spring on the weld, driven by the root's
--     acceleration and gravity), never more than 18° and never more than 4° per frame.
--   • THE CARRY POSE (Animation/CarryClips, through CharacterAnimationController.setHoldPose):
--     the left arm hangs straight, 7° out, swings only a little with the steps; the torso
--     leans 1.5° away from the case, the loaded shoulder drops; a grip shift every 6–10 s.
--     The case always stays in the ARM's space, its handle in the fist: hanging, lying flat
--     to sell (CarryClips.PRESENT_TURN) or up as a shield (SHIELD_TURN) are only turns of it
--     in the fist (never placed from the torso: it can't float off the hand or lag a frame).
--   • BLOCKING while carrying: the arm brings the case up in front of the chest (0.12 s up,
--     0.2 s down). During a hit reaction the hold lets the arm go a little (weight 0.7: the
--     arm jolts with the hit); no grip shift while fighting.
--   • SELLING (character attribute CaseOpen = true, started at CaseOpenAt on the SERVER's
--     clock, so every screen plays the same timeline and one who streams in mid-sale joins
--     it instead of replaying it): the arm brings the case up, lying flat in front of the
--     hip; an event table ("markers") fires on the timeline: the lock wheels tick (0–0.26 s),
--     the latches flip (0.4 / 0.5 s), the seal pops with a cold breath (0.6 s) and the lid
--     swings open (0.6–1.1 s, ease-out); the foam and the cold LED show. On the HOLDER's
--     screen only, the capsules lie in their cradles (he knows the grades from "CaseState");
--     everybody else sees the foam and the LED, never what is inside. Closing: the lid
--     (0.5 s), the latches click (0.5 s), then the case comes down.
--   • SET DOWN: Config.Controls.CASE_SET_DOWN (G) while carrying asks the server
--     (Remotes.CaseAction "SetDown") and plays the 0.5 s crouch (CarryClips.CaseSetDown).
--     The case leaves the hand at the clip's contact marker (SET_DOWN_CONTACT: the hand on
--     the floor), not on the server's reply; the ground case the server spawns is hidden
--     here until then. Refused by the server: it comes back to the hand. Other players'
--     set-downs play the same crouch here when their case leaves the hand while they stand
--     (not for a knockout or a death), and their case also leaves the hand at the contact.
--   • PICK UP: the crouch (CarryClips.CasePickUp) when a case was just taken from the ground
--     next to the character; it is in the hand from the contact marker (a local stand-in
--     stays on the floor until then).
--   • DROPPED CASES (attribute LidAjar): they fall shut and the lid pops ajar on the first
--     impact (a damped spring: a little past, then settles).
--   • PROMPTS (this screen only, the server still checks everything): the buyer's
--     "SellPrompt" only shows while we carry a case; a case's "PickupPrompt" hides while we
--     already carry one, and inside a lab when the lab isn't ours.
--
--   CaseController.trySetDown()     G (also the HUD's SET DOWN button on touch screens)
--   CaseController.isCarrying()     our character holds a case
--   CaseController.grades()         the grades in the case we hold (from "CaseState")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CaseModel = require(ReplicatedStorage.Shared.Contraband.CaseModel)
local CarryClips = require(script.Parent.Parent.Animation.CarryClips)
local Locomotion = require(script.Parent.Parent.Animation.Locomotion)
local CoreModel = require(script.Parent.Parent.Contraband.CoreModel)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local SoundController = require(script.Parent.SoundController)

local CaseController = {}

local player = Players.LocalPlayer

-- Pendulum (the case swinging from the fist): natural frequency (rad/s) and damping ratio
-- (under 1 = it swings a little past and settles), the share of the "hang straight down"
-- it follows (the fist holds it a bit), the largest swing and the fastest change.
local SWING_FREQUENCY = 14
local SWING_DAMPING = 0.35
local HANG_FOLLOW = 0.8
local SWING_MAX = math.rad(18)
local SWING_MAX_SPEED = math.rad(240) -- per second: 4° per frame at 60 fps
-- Smoothing of the measured acceleration (seconds), its cap (studs/s²) and how much of it
-- swings the case (the fist holds it: ~±8° on a walking stop, ~±14° sprinting).
local ACCEL_SMOOTHING = 0.05
local ACCEL_GAIN = 0.38
local ACCEL_MAX = 150
-- Hold pose fade in / out (seconds).
local HOLD_FADE = 0.15
-- During a hit reaction the hold lets the arm follow the hit a little.
local REACTION_HOLD = 0.7
-- Selling: the case comes up (seconds), the locks and latches, the lid opening, closing.
local PRESENT_TIME = 0.35
local LID_OPEN_AT = 0.6 -- 0.4 s of wheels + 0.2 s of latches, after the start
local LID_OPEN_TIME = 0.5
local LID_OPEN_ANGLE = 100
local LID_CLOSE_TIME = 0.5
local LOWER_AFTER_CLOSE = 0.55
-- A latch tongue flips (seconds, degrees).
local LATCH_FLIP_TIME = 0.06
local LATCH_OPEN_ANGLE = 80
-- The opening's / closing's events (seconds from the start of each; the "markers").
type CaseEvent = { t: number, sound: string?, latch: number?, latchOpen: boolean?, puff: boolean? }
local OPEN_EVENTS: { CaseEvent } = {
	{ t = 0, sound = "CaseWheelTick" },
	{ t = 0.13, sound = "CaseWheelTick" },
	{ t = 0.26, sound = "CaseWheelTick" },
	{ t = 0.4, sound = "CaseLatch", latch = 1, latchOpen = true },
	{ t = 0.5, sound = "CaseLatch", latch = 2, latchOpen = true },
	{ t = 0.6, sound = "CaseSealPop", puff = true },
	{ t = 0.6, sound = "CaseLidOpen" },
}
local CLOSE_EVENTS: { CaseEvent } = {
	{ t = 0, sound = "CaseLidClose" },
	{ t = 0.5, sound = "CaseLatch", latch = 1, latchOpen = false },
	{ t = 0.55, sound = "CaseLatch", latch = 2, latchOpen = false },
}
-- Set down / pick up: how long the hold lets go for the crouch; how long we wait for the
-- server before giving a refused set-down back to the hand.
local SET_DOWN_RELEASE = 0.45
local SET_DOWN_REFUSED = 1.2
-- A ground case taken this recently, this close to a character that starts carrying, was
-- picked up from the floor by it (seconds, studs): the pick-up crouch plays.
local PICK_UP_WINDOW = 0.6
local PICK_UP_RANGE = 7
-- Ground cases this close to a character putting its case down are hidden until its hand
-- reaches the floor (studs).
local SET_DOWN_HIDE_RANGE = 5
-- Farther than this from the camera, a held case doesn't swing or move in the hand.
local DETAIL_DISTANCE = 120
-- A dropped case's lid: spring (rad/s, damping ratio) and the longest wait for the impact.
local LID_POP_FREQUENCY = 35
local LID_POP_DAMPING = 0.45
local LID_POP_WAIT = 2

type Latch = { weld: Weld, rest: CFrame, open: boolean, changedAt: number, shown: number }

type Held = {
	character: Model,
	model: Model,
	hitbox: BasePart,
	baseShell: BasePart,
	weld: Weld,
	arm: BasePart,
	root: BasePart,
	mine: boolean,
	latches: { Latch },
	puff: ParticleEmitter,
	far: boolean,
	-- pendulum (radians: forward / back about the arm's X, sideways about its Z)
	swing: Vector2,
	swingSpeed: Vector2,
	lastVelocity: Vector3?,
	accel: Vector3,
	-- hold pose
	weight: number,
	react: number, -- 1, or REACTION_HOLD during a hit reaction (smoothed)
	shield: number, -- 0..1 toward the block pose
	gripShift: number,
	nextGripAt: number,
	gripStartedAt: number?,
	releaseUntil: number,
	-- set down / pick up (os.clock() when the crouch started), the hand at the contact
	setDownAt: number?,
	letGo: boolean, -- the hand reached the floor: the case is out of it
	detachAtContact: boolean, -- the server already took it: gone at the contact
	pickUpAt: number?,
	standIn: Model?, -- the ground case shown on the floor until the hand reaches it
	hiddenGround: { [BasePart]: boolean }, -- ground cases hidden until the contact
	-- selling (the SERVER's clock: workspace:GetServerTimeNow())
	openedAt: number?, -- when CaseOpen came (CaseOpenAt)
	closedAt: number?, -- when it went
	openEvent: number, -- the next OPEN_EVENTS / CLOSE_EVENTS entry to fire
	present: number, -- 0..1
	lid: number, -- degrees
	shownLid: number, -- what setLid last got (only called on a change)
	lidAtClose: number,
	capsules: Model?,
}

-- A ground case that falls shut and pops its lid ajar on the impact (attribute LidAjar).
type Ajar = {
	model: Model,
	hitbox: BasePart,
	target: number, -- degrees
	since: number,
	lastVelocityY: number,
	hit: boolean,
	angle: number,
	speed: number,
}
-- A ground case that just left the floor (picked up?): where it was, when.
type Taken = { cframe: CFrame, lid: number, cradles: number?, at: number }

local held: { [Model]: Held } = {}
local watched: { [Model]: { RBXScriptConnection } } = {}
local folder: Folder? = nil
local random = Random.new()
local ajarCases: { [Model]: Ajar } = {}
local takenCases: { Taken } = {}
local groundFolder: Instance? = nil -- workspace.ContrabandCases once found

-- What the server told us about the case WE hold.
local myGrades: { Types.CoreGrade } = {}
local myHolding = false
local nextSetDownAt = 0

-- Prompts we hide / show locally.
local sellPrompts: { [ProximityPrompt]: boolean } = {}
local pickupPrompts: { [ProximityPrompt]: boolean } = {}

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function heldFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "HeldCases (local)"
	made.Parent = workspace
	folder = made
	return made
end

local function smooth(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeOut(t: number): number
	local x = math.clamp(t, 0, 1)
	return 1 - (1 - x) * (1 - x) * (1 - x)
end

local function myCharacter(): Model?
	return player.Character
end

function CaseController.isCarrying(): boolean
	local character = myCharacter()
	return character ~= nil and character:GetAttribute("Carrying") == "Case"
end

function CaseController.grades(): { Types.CoreGrade }
	return table.clone(myGrades)
end

------------------------------------------------------------------------------
-- Capsules (holder's screen only, while the lid is open)
------------------------------------------------------------------------------

local function clearCapsules(entry: Held)
	if entry.capsules then
		entry.capsules:Destroy()
		entry.capsules = nil
	end
end

local function showCapsules(entry: Held)
	if entry.capsules or not entry.mine or #myGrades == 0 then
		return
	end
	local group = Instance.new("Model")
	group.Name = "Capsules"
	local cradles = CaseModel.cradleCFrames(entry.model)
	for index, grade in myGrades do
		if index > #cradles then
			break
		end
		local cradle = cradles[index]
		local capsule = CoreModel.capsule(grade, cradle)
		capsule:ScaleTo(CaseModel.CAPSULE_SCALE)
		CoreModel.weldTo(capsule, entry.baseShell)
		capsule.Parent = group
	end
	group.Parent = entry.model
	entry.capsules = group
end

------------------------------------------------------------------------------
-- The hold pose (CharacterAnimationController.setHoldPose)
------------------------------------------------------------------------------

local function makeProvider(entry: Held): CharacterAnimationController.HoldProvider
	local pose: CharacterAnimationController.HoldPose = { weight = 0 }
	local character = entry.character
	return function(dt: number, loco: Locomotion.State, onFeet: boolean)
		local now = os.clock()
		-- Fade in when it appears, out while a set-down / pick-up crouch plays (and while the
		-- hand is empty: let go at the contact, the server's answer not here yet).
		local target = if now < entry.releaseUntil or entry.letGo or entry.pickUpAt then 0 else 1
		local step = dt / HOLD_FADE
		entry.weight = if entry.weight < target
			then math.min(target, entry.weight + step)
			else math.max(target, entry.weight - step)
		-- What the body is busy with: a hit reaction moves the arm a little (the hold yields),
		-- no grip shift in a fight.
		local busy = CharacterAnimationController.actionState(character)
		local react = if busy == "Reaction" then REACTION_HOLD else 1
		entry.react += (react - entry.react) * (1 - math.exp(-dt * 20))
		-- Blocking: the case comes up as a shield (not while selling).
		local blocking = CharacterAnimationController.isBlocking(character)
			and entry.openedAt == nil
		local shieldStep = dt / (if blocking then CarryClips.SHIELD_IN else CarryClips.SHIELD_OUT)
		entry.shield =
			math.clamp(entry.shield + (if blocking then shieldStep else -shieldStep), 0, 1)
		-- Grip shift: every 6–10 s, 0.4 s there and 0.4 s back.
		if
			entry.gripStartedAt == nil
			and now >= entry.nextGripAt
			and entry.openedAt == nil
			and busy == nil
			and entry.shield <= 0
		then
			entry.gripStartedAt = now
		end
		local startedAt = entry.gripStartedAt
		if startedAt then
			local t = (now - startedAt) / CarryClips.GRIP_BLEND
			if t >= 2 then
				entry.gripStartedAt = nil
				entry.gripShift = 0
				entry.nextGripAt = now
					+ random:NextNumber(CarryClips.GRIP_EVERY_MIN, CarryClips.GRIP_EVERY_MAX)
			else
				entry.gripShift = smooth(if t < 1 then t else 2 - t)
			end
		end
		local swing = if onFeet then CarryClips.armSwing(loco.phase, loco.amp, loco.sprint) else 0
		local present = smooth(entry.present)
		local shield = smooth(entry.shield)
		local raised = math.max(present, shield)
		pose.leftShoulder =
			CarryClips.holdShoulder(swing * (1 - raised), entry.gripShift, present, shield)
		pose.root = CarryClips.rootTilt(raised)
		-- (eased: the fade has no hard start or stop)
		pose.weight = smooth(entry.weight) * entry.react
		return pose
	end
end

------------------------------------------------------------------------------
-- Attach / detach
------------------------------------------------------------------------------

-- Ground cases near `at` hidden on this screen (LocalTransparencyModifier) into `into`.
local function hideGroundCasesNear(at: Vector3, into: { [BasePart]: boolean })
	local ground = groundFolder
	if ground == nil then
		return
	end
	for _, model in ground:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("CaseId") ~= nil then
			if (model:GetPivot().Position - at).Magnitude <= SET_DOWN_HIDE_RANGE then
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") and not into[part] then
						into[part] = true
						part.LocalTransparencyModifier = 1
					end
				end
			end
		end
	end
end

local function showGroundCases(hidden: { [BasePart]: boolean })
	for part in hidden do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	table.clear(hidden)
end

local function detach(character: Model)
	local entry = held[character]
	if entry == nil then
		return
	end
	held[character] = nil
	CharacterAnimationController.setHoldPose(character, nil)
	showGroundCases(entry.hiddenGround)
	if entry.standIn then
		entry.standIn:Destroy()
		entry.standIn = nil
	end
	entry.puff.Enabled = false
	entry.puff:Clear()
	entry.model:Destroy()
end

-- The latch tongues turn on a Weld (not the build's WeldConstraint) so they can flip.
local function hingedLatches(model: Model): { Latch }
	local list: { Latch } = {}
	local lidShell = model:FindFirstChild("LidShell")
	if lidShell == nil or not lidShell:IsA("BasePart") then
		return list
	end
	for _, part in model:GetChildren() do
		if part.Name == "Latch" and part:IsA("BasePart") then
			local constraint = part:FindFirstChildOfClass("WeldConstraint")
			if constraint then
				constraint:Destroy()
			end
			local rest = lidShell.CFrame:ToObjectSpace(part.CFrame)
			local weld = Instance.new("Weld")
			weld.Name = "LatchHinge"
			weld.Part0 = lidShell
			weld.Part1 = part
			weld.C0 = rest
			weld.Parent = part
			table.insert(
				list,
				{ weld = weld, rest = rest, open = false, changedAt = -100, shown = 0 }
			)
		end
	end
	-- (latch 1 = the +X one, by the vent; 2 = the −X one)
	table.sort(list, function(a, b)
		return a.rest.Position.X > b.rest.Position.X
	end)
	return list
end

-- The cold breath out of the seal when it pops (one burst, roblox-vfx: Rate 0 + Emit):
-- the same heavy, matte cryogenic vapour as the lab's bench, smaller.
local function sealPuff(baseShell: BasePart): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "SealSeam"
	-- at the seam on the handle side, aimed out of the lid face (an Attachment's emitter
	-- emits along the Attachment's up axis)
	attachment.CFrame = CFrame.fromMatrix(Vector3.new(0, 0.5, 0.23), Vector3.xAxis, Vector3.zAxis)
	attachment.Parent = baseShell
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SealBreath"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds" -- built in, no upload
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(Color3.fromRGB(236, 244, 248), Color3.fromRGB(205, 220, 228))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.4, 0.3, 0.06),
		NumberSequenceKeypoint.new(1, 0.5, 0.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.65),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.7, 1.1)
	emitter.Speed = NumberRange.new(0.6, 1.4)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.Drag = 3
	emitter.Acceleration = Vector3.new(0, -0.8, 0) -- heavier than air: it sinks
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-25, 25)
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Parent = attachment
	return emitter
end

-- The last ground case taken from the floor next to `root` (just now), if any.
local function takenNear(root: BasePart): Taken?
	local now = os.clock()
	for index = #takenCases, 1, -1 do
		local taken = takenCases[index]
		if now - taken.at > PICK_UP_WINDOW then
			table.remove(takenCases, index)
		elseif (taken.cframe.Position - root.Position).Magnitude <= PICK_UP_RANGE then
			table.remove(takenCases, index)
			return taken
		end
	end
	return nil
end

local function standingUp(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil
		and humanoid.Health > 0
		and character:GetAttribute("KnockedOut") ~= true
		and character:GetAttribute("Ragdolled") ~= true
end

local function attach(character: Model, pickedUp: boolean?)
	if held[character] then
		return
	end
	local arm = character:WaitForChild("Left Arm", 5)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	-- (still carrying once the parts are here? the attribute may have gone meanwhile)
	if
		arm == nil
		or not arm:IsA("BasePart")
		or root == nil
		or not root:IsA("BasePart")
		or character:GetAttribute("Carrying") ~= "Case"
		or character.Parent == nil
		or held[character]
	then
		return
	end

	local cradles = character:GetAttribute("CaseCradles")
	local model = CaseModel.build({
		lidAngle = 0,
		interior = true,
		cradles = if typeof(cradles) == "number" then cradles else nil,
	})
	model.Name = "HeldCase"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
	local hitbox = model.PrimaryPart :: BasePart
	local baseShell = model:FindFirstChild("BaseShell") :: BasePart
	local latches = hingedLatches(model)
	local puff = sealPuff(baseShell)
	local c0 = CaseModel.heldCFrame(nil)
	model:PivotTo(arm.CFrame * c0)
	local weld = Instance.new("Weld")
	weld.Name = "CaseGrip"
	weld.Part0 = arm
	weld.Part1 = hitbox
	weld.C0 = c0
	weld.Parent = hitbox

	local now = os.clock()
	-- Already selling when we see it (streamed in, joined): on the server's timeline, the
	-- events already past are skipped (no replayed opening, no late sounds).
	local openAt = character:GetAttribute("CaseOpenAt")
	local opened: number? = nil
	local openEvent = 1
	if character:GetAttribute("CaseOpen") == true then
		opened = if typeof(openAt) == "number" then openAt else workspace:GetServerTimeNow()
		local elapsed = workspace:GetServerTimeNow() - (opened :: number)
		while OPEN_EVENTS[openEvent] and OPEN_EVENTS[openEvent].t <= elapsed do
			local event = OPEN_EVENTS[openEvent]
			if event.latch and latches[event.latch] then
				latches[event.latch].open = true
				latches[event.latch].changedAt = -100
			end
			openEvent += 1
		end
	end

	-- Picked up from the floor here: the crouch, the case in the hand at the contact (a
	-- stand-in on the floor until then).
	local taken = if pickedUp and standingUp(character) then takenNear(root) else nil
	local standIn: Model? = nil
	if taken then
		local copy = CaseModel.build({
			lidAngle = taken.lid,
			interior = taken.lid > 0,
			cradles = taken.cradles,
		})
		copy.Name = "PickUpStandIn"
		for _, descendant in copy:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
		copy:PivotTo(taken.cframe)
		copy.Parent = heldFolder()
		standIn = copy
		CharacterAnimationController.playAction(character, "CasePickUp")
	else
		model.Parent = heldFolder()
		if pickedUp then
			SoundController.play("CasePickup", character)
		end
	end

	local entry: Held = {
		character = character,
		model = model,
		hitbox = hitbox,
		baseShell = baseShell,
		weld = weld,
		arm = arm,
		root = root,
		mine = character == player.Character,
		latches = latches,
		puff = puff,
		far = false,
		swing = Vector2.zero,
		swingSpeed = Vector2.zero,
		lastVelocity = nil,
		accel = Vector3.zero,
		weight = 0,
		react = 1,
		shield = 0,
		gripShift = 0,
		nextGripAt = now + random:NextNumber(CarryClips.GRIP_EVERY_MIN, CarryClips.GRIP_EVERY_MAX),
		gripStartedAt = nil,
		releaseUntil = 0,
		setDownAt = nil,
		letGo = false,
		detachAtContact = false,
		pickUpAt = if taken then now else nil,
		standIn = standIn,
		hiddenGround = {},
		openedAt = opened,
		closedAt = nil,
		openEvent = openEvent,
		present = 0,
		lid = 0,
		shownLid = 0,
		lidAtClose = 0,
		capsules = nil,
	}
	held[character] = entry
	CharacterAnimationController.setHoldPose(character, makeProvider(entry))
end

------------------------------------------------------------------------------
-- Every frame: pendulum, selling pose, lid
------------------------------------------------------------------------------

local GRAVITY_DOWN = Vector3.new(0, -1, 0)

local function updatePendulum(entry: Held, dt: number)
	-- Acceleration of the body (smoothed): the case lags behind it.
	local velocity = entry.root.AssemblyLinearVelocity
	local last = entry.lastVelocity
	entry.lastVelocity = velocity
	if last and dt > 0 then
		local measured = (velocity - last) / dt
		if measured.Magnitude > ACCEL_MAX then
			measured = measured.Unit * ACCEL_MAX
		end
		local keep = math.exp(-dt / ACCEL_SMOOTHING)
		entry.accel = entry.accel:Lerp(measured, 1 - keep)
	end
	-- Where "down" is for the case: gravity minus the body's acceleration, seen from the arm.
	local effective = GRAVITY_DOWN * workspace.Gravity - entry.accel * ACCEL_GAIN
	if effective.Magnitude < 1e-3 then
		effective = GRAVITY_DOWN
	end
	local down = entry.arm.CFrame:VectorToObjectSpace(effective.Unit)
	local target = Vector2.new(math.atan2(-down.Z, -down.Y), math.atan2(down.X, -down.Y))
		* HANG_FOLLOW
	target = Vector2.new(
		math.clamp(target.X, -SWING_MAX, SWING_MAX),
		math.clamp(target.Y, -SWING_MAX, SWING_MAX)
	)
	-- A damped spring toward it (small steps: stable on a slow frame).
	local stiffness = SWING_FREQUENCY * SWING_FREQUENCY
	local damping = 2 * SWING_DAMPING * SWING_FREQUENCY
	local remaining = math.min(dt, 0.1)
	local before = entry.swing
	local swing, speed = entry.swing, entry.swingSpeed
	while remaining > 1e-6 do
		local step = math.min(remaining, 1 / 120)
		remaining -= step
		speed += ((target - swing) * stiffness - speed * damping) * step
		swing += speed * step
	end
	-- Never faster than SWING_MAX_SPEED (no snap on a teleport or a lag spike).
	local change = swing - before
	local limit = SWING_MAX_SPEED * math.max(dt, 1 / 240)
	if change.Magnitude > limit then
		swing = before + change.Unit * limit
		speed = speed * 0.5
	end
	entry.swing = Vector2.new(
		math.clamp(swing.X, -SWING_MAX, SWING_MAX),
		math.clamp(swing.Y, -SWING_MAX, SWING_MAX)
	)
	entry.swingSpeed = speed
end

-- Fires one opening / closing event (sound at the case, latch flip, cold breath).
local function fireEvent(entry: Held, event: CaseEvent, now: number)
	if event.sound and not entry.far then
		SoundController.play(event.sound, entry.character)
	end
	local latch = if event.latch then entry.latches[event.latch] else nil
	if latch and latch.open ~= event.latchOpen then
		latch.open = event.latchOpen == true
		latch.changedAt = now
	end
	if event.puff and not entry.far then
		entry.puff:Emit(6)
	end
end

-- The latch tongues: a quick flip (mechanical: fast, no easing back) to open / shut.
local function updateLatches(entry: Held, now: number)
	for _, latch in entry.latches do
		local t = math.clamp((now - latch.changedAt) / LATCH_FLIP_TIME, 0, 1)
		local open = if latch.open then t else 1 - t
		if open ~= latch.shown then
			latch.shown = open
			-- turns about its lid-side edge: the free end lifts off the lock
			latch.weld.C0 = latch.rest
				* CFrame.new(0, 0, 0.03)
				* CFrame.Angles(math.rad(LATCH_OPEN_ANGLE * open), 0, 0)
				* CFrame.new(0, 0, -0.03)
		end
	end
end

-- Selling, on the server's clock (`serverNow`); `now` = os.clock() for the local effects.
local function updateOpening(entry: Held, serverNow: number, now: number)
	local opened = entry.openedAt
	local closed = entry.closedAt
	if opened and closed == nil then
		local t = math.max(0, serverNow - opened)
		entry.present = math.clamp(t / PRESENT_TIME, 0, 1)
		entry.lid = LID_OPEN_ANGLE * easeOut((t - LID_OPEN_AT) / LID_OPEN_TIME)
		while OPEN_EVENTS[entry.openEvent] and t >= OPEN_EVENTS[entry.openEvent].t do
			fireEvent(entry, OPEN_EVENTS[entry.openEvent], now)
			entry.openEvent += 1
		end
	elseif closed then
		local t = math.max(0, serverNow - closed)
		entry.lid = entry.lidAtClose * (1 - smooth(t / LID_CLOSE_TIME))
		entry.present =
			math.min(entry.present, 1 - math.clamp((t - LOWER_AFTER_CLOSE) / PRESENT_TIME, 0, 1))
		while CLOSE_EVENTS[entry.openEvent] and t >= CLOSE_EVENTS[entry.openEvent].t do
			fireEvent(entry, CLOSE_EVENTS[entry.openEvent], now)
			entry.openEvent += 1
		end
		if entry.present <= 0 and entry.lid <= 0 and CLOSE_EVENTS[entry.openEvent] == nil then
			entry.openedAt = nil
			entry.closedAt = nil
			entry.present = 0
			entry.lid = 0
		end
	end
	if #entry.latches > 0 then
		updateLatches(entry, now)
	end
	-- (setLid only on a change: it also walks the interior parts)
	if entry.lid ~= entry.shownLid then
		entry.shownLid = entry.lid
		CaseModel.setLid(entry.model, entry.lid)
	end
	if entry.lid > 5 and entry.closedAt == nil then
		showCapsules(entry)
	elseif entry.lid <= 5 then
		clearCapsules(entry)
	end
	local capsules = entry.capsules
	if capsules then
		for _, capsule in capsules:GetChildren() do
			if capsule:IsA("Model") then
				CoreModel.animate(capsule, now)
			end
		end
	end
end

-- Set down / pick up: the case leaves / joins the hand at the clip's contact marker.
local function updateHandOff(entry: Held, now: number): boolean
	local setDownAt = entry.setDownAt
	if setDownAt then
		if not entry.letGo then
			-- (the ground case the server spawns stays hidden until the hand is down)
			hideGroundCasesNear(entry.root.Position, entry.hiddenGround)
			if now - setDownAt >= CarryClips.SET_DOWN_CONTACT then
				entry.letGo = true
				entry.model.Parent = nil
				showGroundCases(entry.hiddenGround)
				SoundController.play("CaseSetDown", entry.character)
				if entry.detachAtContact then
					detach(entry.character)
					return false
				end
			end
		elseif now - setDownAt >= SET_DOWN_REFUSED then
			-- the server said no (still carrying): back in the hand
			entry.setDownAt = nil
			entry.letGo = false
			entry.model.Parent = heldFolder()
		end
	end
	local pickUpAt = entry.pickUpAt
	if pickUpAt and now - pickUpAt >= CarryClips.PICK_UP_CONTACT then
		entry.pickUpAt = nil
		entry.model.Parent = heldFolder()
		if entry.standIn then
			entry.standIn:Destroy()
			entry.standIn = nil
		end
		SoundController.play("CasePickup", entry.character)
	end
	return true
end

-- A dropped case: shut while it falls, the lid pops ajar on the first impact (its vertical
-- speed stops going down), a damped spring: a little past the angle, then settles.
local function updateAjar(dt: number, now: number)
	for model, ajar in ajarCases do
		if model.Parent == nil then
			ajarCases[model] = nil
			continue
		end
		if not ajar.hit then
			local velocityY = ajar.hitbox.AssemblyLinearVelocity.Y
			if
				(ajar.lastVelocityY < -1 and velocityY > ajar.lastVelocityY * 0.5)
				or ajar.hitbox.Anchored
				or now - ajar.since > LID_POP_WAIT
			then
				ajar.hit = true
			end
			ajar.lastVelocityY = velocityY
			continue
		end
		local stiffness = LID_POP_FREQUENCY * LID_POP_FREQUENCY
		local damping = 2 * LID_POP_DAMPING * LID_POP_FREQUENCY
		local remaining = math.min(dt, 0.1)
		while remaining > 1e-6 do
			local step = math.min(remaining, 1 / 120)
			remaining -= step
			ajar.speed += ((ajar.target - ajar.angle) * stiffness - ajar.speed * damping) * step
			ajar.angle += ajar.speed * step
		end
		if math.abs(ajar.target - ajar.angle) < 0.05 and math.abs(ajar.speed) < 0.5 then
			ajar.angle = ajar.target
			ajarCases[model] = nil
		end
		CaseModel.setLid(model, math.max(0, ajar.angle))
	end
end

local function onPreSimulation(dt: number)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else nil
	for character, entry in held do
		local waiting = entry.letGo or entry.pickUpAt ~= nil
		if
			character.Parent == nil
			or entry.arm.Parent ~= character
			or (entry.model.Parent == nil and not waiting)
		then
			-- (the arm came off, the character is gone: no floating case)
			detach(character)
			continue
		end
		if not updateHandOff(entry, now) then
			continue
		end
		entry.far = eye ~= nil and (eye - entry.root.Position).Magnitude > DETAIL_DISTANCE
		updateOpening(entry, serverNow, now)
		if entry.far then
			-- (too far to see it swing: no pendulum, the case keeps its last place in the hand)
			entry.lastVelocity = nil
			continue
		end
		updatePendulum(entry, dt)
		-- Always in the arm's space, the handle in the fist: only its turn in the fist changes
		-- (hanging and swinging, lying flat to sell, up as a shield).
		local turn = CaseModel.heldCFrame(CFrame.Angles(entry.swing.X, 0, entry.swing.Y)).Rotation
		local present = smooth(entry.present)
		if present > 0 then
			turn = turn:Lerp(CarryClips.PRESENT_TURN, present)
		end
		local shield = smooth(entry.shield)
		if shield > 0 then
			turn = turn:Lerp(CarryClips.SHIELD_TURN, shield)
		end
		entry.weld.C0 = CFrame.new(CaseModel.HAND) * turn * CFrame.new(-CaseModel.GRIP)
	end
	if next(ajarCases) then
		updateAjar(dt, now)
	end
end

------------------------------------------------------------------------------
-- Characters
------------------------------------------------------------------------------

local function onCarryingChanged(character: Model, owner: Player)
	local carrying = character:GetAttribute("Carrying") == "Case"
	if carrying then
		-- (the pick-up crouch and its sound: attach, at the contact)
		task.spawn(attach, character, true)
		if owner == player then
			CaseController.refreshPrompts()
		end
		return
	end
	local entry = held[character]
	if entry == nil then
		if owner == player then
			CaseController.refreshPrompts()
		end
		return
	end
	if not standingUp(character) then
		-- knocked out / dead: it falls out of the hand now
		detach(character)
		SoundController.play("CaseDrop", character)
	elseif entry.letGo or entry.pickUpAt then
		-- our own set-down: the hand already put it on the floor (sound played there); or
		-- taken away again before the hand even reached it
		detach(character)
	elseif entry.setDownAt then
		-- our own set-down, the hand not down yet: it leaves the hand at the contact
		entry.detachAtContact = true
	else
		-- someone else put it down (standing, alive): the crouch, then the case leaves the
		-- hand when it reaches the floor (their ground case hidden here until then)
		local now = os.clock()
		CharacterAnimationController.playAction(character, "CaseSetDown")
		entry.setDownAt = now
		entry.releaseUntil = now + SET_DOWN_RELEASE
		entry.detachAtContact = true
		hideGroundCasesNear(entry.root.Position, entry.hiddenGround)
	end
	if owner == player then
		CaseController.refreshPrompts()
	end
end

local function onCaseOpenChanged(character: Model)
	local entry = held[character]
	if entry == nil then
		return
	end
	local serverNow = workspace:GetServerTimeNow()
	if character:GetAttribute("CaseOpen") == true then
		-- (the server's start time: the timeline is the same on every screen; its events
		-- fire from updateOpening when the timeline crosses them)
		local openAt = character:GetAttribute("CaseOpenAt")
		entry.openedAt = if typeof(openAt) == "number"
			then math.min(openAt, serverNow)
			else serverNow
		entry.closedAt = nil
		entry.openEvent = 1
	elseif entry.openedAt then
		entry.closedAt = serverNow
		entry.openEvent = 1
		entry.lidAtClose = entry.lid
	end
end

local function watchCharacter(character: Model, owner: Player)
	if watched[character] then
		return
	end
	watched[character] = {
		character:GetAttributeChangedSignal("Carrying"):Connect(function()
			onCarryingChanged(character, owner)
		end),
		character:GetAttributeChangedSignal("CaseOpen"):Connect(function()
			onCaseOpenChanged(character)
		end),
		character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				detach(character)
				local connections = watched[character]
				watched[character] = nil
				if connections then
					for _, connection in connections do
						connection:Disconnect()
					end
				end
			end
		end),
	}
	if character:GetAttribute("Carrying") == "Case" then
		task.spawn(attach, character)
	end
end

local function onPlayerAdded(owner: Player)
	owner.CharacterAdded:Connect(function(character)
		watchCharacter(character, owner)
	end)
	if owner.Character then
		watchCharacter(owner.Character, owner)
	end
end

------------------------------------------------------------------------------
-- Set down (G)
------------------------------------------------------------------------------

function CaseController.trySetDown()
	local character = myCharacter()
	if character == nil or character:GetAttribute("Carrying") ~= "Case" then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local now = os.clock()
	if
		humanoid == nil
		or humanoid.Health <= 0
		or humanoid.FloorMaterial == Enum.Material.Air
		or now < nextSetDownAt
		or character:GetAttribute("CaseOpen") == true
		or character:GetAttribute("KnockedOut") == true
		or character:GetAttribute("Ragdolled") == true
		or character:GetAttribute("InCinematic") == true
		or player:GetAttribute("Extracting") == true
	then
		return
	end
	local entry = held[character]
	if entry and (entry.setDownAt or entry.pickUpAt) then
		return -- (already putting it down / still picking it up)
	end
	nextSetDownAt = now + Config.Case.SETDOWN_COOLDOWN
	Remotes.CaseAction:FireServer("SetDown")
	CharacterAnimationController.playAction(character, "CaseSetDown")
	if entry then
		entry.releaseUntil = now + SET_DOWN_RELEASE
		-- the case leaves the hand at the clip's contact marker (updateHandOff)
		entry.setDownAt = now
		entry.letGo = false
		entry.detachAtContact = false
	end
end

------------------------------------------------------------------------------
-- Prompts (local visibility only)
------------------------------------------------------------------------------

local function pickupAllowed(prompt: ProximityPrompt): boolean
	if CaseController.isCarrying() then
		return false
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	local labOwner = model and model:GetAttribute("LabOwner")
	return labOwner == nil or labOwner == player.UserId
end

function CaseController.refreshPrompts()
	local carrying = CaseController.isCarrying()
	for prompt in sellPrompts do
		if prompt.Parent then
			prompt.Enabled = carrying
		else
			sellPrompts[prompt] = nil
		end
	end
	for prompt in pickupPrompts do
		if prompt.Parent then
			prompt.Enabled = pickupAllowed(prompt)
		else
			pickupPrompts[prompt] = nil
		end
	end
end

local function onPromptFound(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	if instance.Name == "SellPrompt" then
		sellPrompts[instance] = true
		instance.Enabled = CaseController.isCarrying()
	elseif instance.Name == "PickupPrompt" then
		pickupPrompts[instance] = true
		instance.Enabled = pickupAllowed(instance)
	end
end

-- A ground case that falls shut (LidAjar): its lid pops on the impact. One already lying
-- there (settled, anchored) shows it ajar at once.
local function watchGroundCase(model: Model)
	local target = model:GetAttribute("LidAjar")
	if typeof(target) ~= "number" or ajarCases[model] then
		return
	end
	local hitbox = model.PrimaryPart or model:FindFirstChild("Hitbox")
	if hitbox == nil or not hitbox:IsA("BasePart") then
		return
	end
	if hitbox.Anchored then
		CaseModel.setLid(model, target)
		return
	end
	ajarCases[model] = {
		model = model,
		hitbox = hitbox,
		target = target,
		since = os.clock(),
		lastVelocityY = hitbox.AssemblyLinearVelocity.Y,
		hit = false,
		angle = 0,
		speed = 0,
	}
end

-- A ground case leaving (picked up? streamed out?): remembered a moment, so a character
-- that starts carrying right next to it shows the pick-up crouch over it.
local function groundCaseLeaving(model: Model)
	ajarCases[model] = nil
	local hitbox = model.PrimaryPart
	if hitbox == nil then
		return
	end
	local lid = model:GetAttribute("LidAngle")
	local plugs = 0
	for _, part in model:GetChildren() do
		if part.Name == "FoamPlug" then
			plugs += 1
		end
	end
	table.insert(takenCases, {
		cframe = hitbox.CFrame,
		lid = if typeof(lid) == "number" then lid else 0,
		cradles = CaseModel.CRADLES - plugs,
		at = os.clock(),
	})
	if #takenCases > 8 then
		table.remove(takenCases, 1)
	end
end

-- The server's folders appear once (and parts stream in / out): watch them when they come.
local function watchFolder(name: string)
	task.spawn(function()
		local found: Instance? = workspace:FindFirstChild(name)
		while found == nil do
			task.wait(2)
			found = workspace:FindFirstChild(name)
		end
		local where = found :: Instance
		local cases = name == "ContrabandCases"
		if cases then
			groundFolder = where
		end
		where.DescendantAdded:Connect(function(instance)
			onPromptFound(instance)
			if cases and instance:IsA("Model") and instance.Parent == where then
				watchGroundCase(instance)
			end
		end)
		where.DescendantRemoving:Connect(function(instance)
			if instance:IsA("ProximityPrompt") then
				sellPrompts[instance] = nil
				pickupPrompts[instance] = nil
			elseif cases and instance:IsA("Model") and instance.Parent == where then
				groundCaseLeaving(instance)
			end
		end)
		for _, descendant in where:GetDescendants() do
			onPromptFound(descendant)
			if cases and descendant:IsA("Model") and descendant.Parent == where then
				watchGroundCase(descendant)
			end
		end
	end)
end

------------------------------------------------------------------------------
-- Server messages about our case
------------------------------------------------------------------------------

local function onContrabandEvent(kind: string, data: any)
	if typeof(data) ~= "table" then
		return
	end
	if kind == "CaseState" then
		myHolding = data.holding == true
		local grades: { Types.CoreGrade } = {}
		if myHolding and typeof(data.grades) == "table" then
			for _, grade in data.grades do
				if grade == "A" or grade == "B" or grade == "C" then
					table.insert(grades, grade)
				end
			end
		end
		myGrades = grades
	elseif kind == "SaleResult" and data.ok == true then
		-- The buyer took them: the cradles are empty now.
		myGrades = {}
		local character = myCharacter()
		local entry = character and held[character]
		if entry then
			clearCapsules(entry)
		end
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function CaseController.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, owner in Players:GetPlayers() do
		onPlayerAdded(owner)
	end
	RunService.PreSimulation:Connect(onPreSimulation)
	Remotes.ContrabandEvent.OnClientEvent:Connect(onContrabandEvent)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return -- typing in chat...
		end
		if input.KeyCode == Config.Controls.CASE_SET_DOWN then
			CaseController.trySetDown()
		end
	end)

	watchFolder("ContrabandSites")
	watchFolder("ContrabandCases")
	player.CharacterAdded:Connect(function()
		myGrades = {}
		myHolding = false
		CaseController.refreshPrompts()
	end)
end

return CaseController
