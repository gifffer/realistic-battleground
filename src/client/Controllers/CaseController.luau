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
--   • SELLING (character attribute CaseOpen = true, 1.6 s): the arm brings the case up, lying
--     flat in front of the hip; the locks (0.4 s) and latches (0.2 s), then the lid swings
--     open (0.5 s, ease-out); the foam and the cold LED show. On the HOLDER's screen only,
--     the capsules lie in their cradles (he knows the grades from "CaseState"); everybody
--     else sees the foam and the LED, never what is inside. Closes in ~0.8 s afterwards.
--   • SET DOWN: Config.Controls.CASE_SET_DOWN (G) while carrying asks the server
--     (Remotes.CaseAction "SetDown") and plays the 0.5 s crouch (CarryClips.CaseSetDown).
--     Other players' set-downs play the same crouch here when their case leaves the hand
--     while they stand (not for a knockout or a death).
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
-- Selling: the case comes up (seconds), the locks and latches, the lid opening, closing.
local PRESENT_TIME = 0.35
local LID_OPEN_AT = 0.6 -- 0.4 s of wheels + 0.2 s of latches, after the start
local LID_OPEN_TIME = 0.5
local LID_OPEN_ANGLE = 100
local LID_CLOSE_TIME = 0.5
local LOWER_AFTER_CLOSE = 0.45
-- Set down: how long the hold lets go for our own crouch.
local SET_DOWN_RELEASE = 0.45

type Held = {
	character: Model,
	model: Model,
	hitbox: BasePart,
	baseShell: BasePart,
	weld: Weld,
	arm: BasePart,
	torso: BasePart,
	root: BasePart,
	mine: boolean,
	-- pendulum (radians: forward / back about the arm's X, sideways about its Z)
	swing: Vector2,
	swingSpeed: Vector2,
	lastVelocity: Vector3?,
	accel: Vector3,
	-- hold pose
	weight: number,
	gripShift: number,
	nextGripAt: number,
	gripStartedAt: number?,
	releaseUntil: number,
	-- selling
	openedAt: number?, -- os.clock() when CaseOpen came
	closedAt: number?, -- os.clock() when it went
	present: number, -- 0..1
	lid: number, -- degrees
	lidAtClose: number,
	capsules: Model?,
}

local held: { [Model]: Held } = {}
local watched: { [Model]: { RBXScriptConnection } } = {}
local folder: Folder? = nil
local random = Random.new()

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
	return function(dt: number, loco: Locomotion.State, onFeet: boolean)
		local now = os.clock()
		-- Fade in when it appears, out while our own set-down crouch plays.
		local target = if now < entry.releaseUntil then 0 else 1
		local step = dt / HOLD_FADE
		entry.weight = if entry.weight < target
			then math.min(target, entry.weight + step)
			else math.max(target, entry.weight - step)
		-- Grip shift: every 6–10 s, 0.4 s there and 0.4 s back.
		if entry.gripStartedAt == nil and now >= entry.nextGripAt and entry.openedAt == nil then
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
		pose.leftShoulder = CarryClips.holdShoulder(swing * (1 - present), entry.gripShift, present)
		pose.root = CarryClips.rootTilt(present)
		pose.weight = entry.weight
		return pose
	end
end

------------------------------------------------------------------------------
-- Attach / detach
------------------------------------------------------------------------------

local function detach(character: Model)
	local entry = held[character]
	if entry == nil then
		return
	end
	held[character] = nil
	CharacterAnimationController.setHoldPose(character, nil)
	entry.model:Destroy()
end

local function attach(character: Model)
	if held[character] then
		return
	end
	local arm = character:WaitForChild("Left Arm", 5)
	local torso = character:WaitForChild("Torso", 5)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	-- (still carrying once the parts are here? the attribute may have gone meanwhile)
	if
		arm == nil
		or not arm:IsA("BasePart")
		or torso == nil
		or not torso:IsA("BasePart")
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
	local c0 = CaseModel.heldCFrame(nil)
	model:PivotTo(arm.CFrame * c0)
	local weld = Instance.new("Weld")
	weld.Name = "CaseGrip"
	weld.Part0 = arm
	weld.Part1 = hitbox
	weld.C0 = c0
	weld.Parent = hitbox
	model.Parent = heldFolder()

	local entry: Held = {
		character = character,
		model = model,
		hitbox = hitbox,
		baseShell = baseShell,
		weld = weld,
		arm = arm,
		torso = torso,
		root = root,
		mine = character == player.Character,
		swing = Vector2.zero,
		swingSpeed = Vector2.zero,
		lastVelocity = nil,
		accel = Vector3.zero,
		weight = 0,
		gripShift = 0,
		nextGripAt = os.clock()
			+ random:NextNumber(CarryClips.GRIP_EVERY_MIN, CarryClips.GRIP_EVERY_MAX),
		gripStartedAt = nil,
		releaseUntil = 0,
		openedAt = if character:GetAttribute("CaseOpen") == true then os.clock() else nil,
		closedAt = nil,
		present = 0,
		lid = 0,
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

local function updateOpening(entry: Held, now: number)
	local opened = entry.openedAt
	local closed = entry.closedAt
	if opened and closed == nil then
		local t = now - opened
		entry.present = math.clamp(t / PRESENT_TIME, 0, 1)
		entry.lid = LID_OPEN_ANGLE * easeOut((t - LID_OPEN_AT) / LID_OPEN_TIME)
	elseif closed then
		local t = now - closed
		entry.lid = entry.lidAtClose * (1 - smooth(t / LID_CLOSE_TIME))
		entry.present =
			math.min(entry.present, 1 - math.clamp((t - LOWER_AFTER_CLOSE) / PRESENT_TIME, 0, 1))
		if entry.present <= 0 and entry.lid <= 0 then
			entry.openedAt = nil
			entry.closedAt = nil
			entry.present = 0
			entry.lid = 0
		end
	end
	CaseModel.setLid(entry.model, entry.lid)
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

local function onPreSimulation(dt: number)
	local now = os.clock()
	for character, entry in held do
		if
			character.Parent == nil
			or entry.arm.Parent ~= character
			or entry.model.Parent == nil
		then
			-- (the arm came off, the character is gone: no floating case)
			detach(character)
			continue
		end
		updatePendulum(entry, dt)
		updateOpening(entry, now)
		local hang = CaseModel.heldCFrame(CFrame.Angles(entry.swing.X, 0, entry.swing.Y))
		local present = smooth(entry.present)
		if present > 0 then
			-- Selling: the case lies flat in front of the hip (torso space), whatever the arm does.
			local lying = entry.arm.CFrame:Inverse() * entry.torso.CFrame * CarryClips.PRESENT_CASE
			entry.weld.C0 = hang:Lerp(lying, present)
		else
			entry.weld.C0 = hang
		end
	end
end

------------------------------------------------------------------------------
-- Characters
------------------------------------------------------------------------------

local function onCarryingChanged(character: Model, owner: Player)
	local carrying = character:GetAttribute("Carrying") == "Case"
	if carrying then
		SoundController.play("CasePickup", character)
		task.spawn(attach, character)
	else
		local had = held[character] ~= nil
		detach(character)
		if had then
			-- (knocked out / dead: it falls; else it is put down)
			local down = character:GetAttribute("KnockedOut") == true
				or character:GetAttribute("Ragdolled") == true
			SoundController.play(if down then "CaseDrop" else "CaseSetDown", character)
		end
		-- Someone else put it down (standing, alive, not knocked out): show the crouch.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if
			had
			and owner ~= player
			and humanoid
			and humanoid.Health > 0
			and character:GetAttribute("KnockedOut") ~= true
			and character:GetAttribute("Ragdolled") ~= true
		then
			CharacterAnimationController.playAction(character, "CaseSetDown")
		end
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
	local now = os.clock()
	if character:GetAttribute("CaseOpen") == true then
		entry.openedAt = now
		entry.closedAt = nil
		SoundController.play("CaseLatch", character)
		SoundController.play("CaseLidOpen", character)
	elseif entry.openedAt then
		SoundController.play("CaseLidClose", character)
		entry.closedAt = now
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
	nextSetDownAt = now + Config.Case.SETDOWN_COOLDOWN
	Remotes.CaseAction:FireServer("SetDown")
	CharacterAnimationController.playAction(character, "CaseSetDown")
	local entry = held[character]
	if entry then
		entry.releaseUntil = now + SET_DOWN_RELEASE
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

-- The server's folders appear once (and parts stream in / out): watch them when they come.
local function watchFolder(name: string)
	task.spawn(function()
		local found: Instance? = workspace:FindFirstChild(name)
		while found == nil do
			task.wait(2)
			found = workspace:FindFirstChild(name)
		end
		local where = found :: Instance
		where.DescendantAdded:Connect(onPromptFound)
		where.DescendantRemoving:Connect(function(instance)
			if instance:IsA("ProximityPrompt") then
				sellPrompts[instance] = nil
				pickupPrompts[instance] = nil
			end
		end)
		for _, descendant in where:GetDescendants() do
			onPromptFound(descendant)
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
