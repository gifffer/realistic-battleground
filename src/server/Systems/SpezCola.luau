--!strict
-- SpezCola: the free cola machines of the city. Useless, just for fun.
--
-- The city (Server/Systems/City) builds 3 machines: a Model named "SpezColaMachine", tagged
-- "SpezColaMachine", with these children:
--   Button     the button column: the "GET A SPEZCOLA" prompt is put on it;
--   Dispenser  an invisible marker: its position is the tray opening, its LookVector points
--              OUT of the machine, towards the player;
--   Hum        the machine's centre: the humming sound plays there (on every client,
--              Client/Controllers/SpezColaController).
--
-- What happens (all on the server, nothing is trusted from a client):
--   1. Someone uses the machine's prompt (free, no coins): the button lights up, and a
--      moment later (the clunk) a CAN drops out of the tray, rolling a little towards them.
--      Max one can every Config.Cola.COOLDOWN seconds per player; at most MAX_PER_MACHINE
--      cans lying in front of one machine and MAX_TOTAL in the server (the oldest goes).
--      A can nobody drinks disappears after CAN_LIFETIME seconds.
--   2. The can on the ground has its own prompt, "DRINK". Using it: the can goes into the
--      player's right hand (welded to the Right Arm, so it follows the arm that every client
--      animates), everyone sees the "Emote_Drink" clip (Remotes.CombatAction, like an emote),
--      and the player walks slower meanwhile (Movement speed modifier "Drinking").
--   3. At the end, the can is crushed a bit and tossed away; it disappears EMPTY_LIFETIME
--      seconds later.
--   Refused (nothing happens, nothing shown): in a duel, knocked out, dead, in a finisher's
--   cutscene, in combat (the player's CombatUntil attribute), or busy (attacking, blocking,
--   stunned, sliding...: Combat.isIdle).
--   Cancelled (the can just falls): getting hit (Combat.onDamaged), attacking / blocking /
--   sliding meanwhile, dying.
--
-- The cans live in Workspace > SpezColaCans (the client plays the "can falls" sound when
-- one arrives there). Each can: a Model tagged "SpezColaCan", PrimaryPart "Body".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Knockout = require(script.Parent.Knockout)
local Movement = require(script.Parent.Movement)

local CC = Config.Cola

local SpezCola = {}

local MACHINE_TAG = "SpezColaMachine"
local CAN_TAG = "SpezColaCan"
local FOLDER_NAME = "SpezColaCans"
local DRINK_ANIMATION = "Emote_Drink"
local SPEED_KEY = "Drinking"
-- A cylinder part's round axis is its X axis: this turn makes it point UP (Y).
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
-- Where the can sits in the right hand, in the Right Arm's space: at the bottom of the arm
-- (the hand), on its front, upright while the arm hangs.
local GRIP = CFrame.new(0, -0.78, -0.37)

type Machine = {
	model: Model,
	button: BasePart,
	dispenser: BasePart,
	cans: { Can }, -- cans of this machine still lying on the ground (oldest first)
	busyUntil: number,
}

-- "Loose": on the ground, can be taken. "Held": being drunk. "Empty": crushed, thrown away.
type Can = {
	model: Model,
	body: BasePart,
	prompt: ProximityPrompt,
	machine: Machine?,
	state: "Loose" | "Held" | "Empty",
	born: number,
}

type Drink = {
	can: Can,
	player: Player,
	character: Model,
	humanoid: Humanoid,
	weld: Weld,
}

local machines: { [Model]: Machine } = {}
local allCans: { Can } = {} -- every can in the world (oldest first)
local drinks: { [Player]: Drink } = {}
local lastCanAt: { [Player]: number } = {}
local folder: Folder

------------------------------------------------------------------------------
-- The can (built in code, ~9 parts, about 0.45 × 0.8 studs)
------------------------------------------------------------------------------

local CAN_RED = Color3.fromRGB(196, 18, 30)
local SILVER = Color3.fromRGB(196, 198, 204)
local SILVER_DARK = Color3.fromRGB(150, 152, 158)

-- One part of the can. `offset` is in the can's own space (Y = up, -Z = front, where the
-- label is). Every part but the body is massless, never collides, welded to the body.
local function canPart(
	model: Model,
	body: BasePart?,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = offset * (if shape == Enum.PartType.Cylinder then UPRIGHT else CFrame.identity)
	if body then
		part.CanCollide = false
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
	end
	part.Parent = model
	return part
end

-- The "SPEZ" label, printed on one side of the can (a transparent sheet with a SurfaceGui
-- just outside the round body): white script letters on the red, and a white wave.
local function addLabel(model: Model, body: BasePart, name: string, offset: CFrame)
	local sheet = canPart(
		model,
		body,
		name,
		Enum.PartType.Block,
		Vector3.new(0.26, 0.34, 0.01),
		offset,
		CAN_RED,
		Enum.Material.SmoothPlastic
	)
	sheet.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Print"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 200
	gui.LightInfluence = 1
	gui.Parent = sheet
	-- the wave: a white stripe, slightly tilted, under the name
	local wave = Instance.new("Frame")
	wave.Name = "Wave"
	wave.AnchorPoint = Vector2.new(0.5, 0.5)
	wave.Position = UDim2.fromScale(0.5, 0.78)
	wave.Size = UDim2.fromScale(1.3, 0.12)
	wave.Rotation = -9
	wave.BorderSizePixel = 0
	wave.BackgroundColor3 = Color3.fromRGB(248, 246, 240)
	wave.Parent = gui
	local text = Instance.new("TextLabel")
	text.Name = "Brand"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromScale(0, 0.12)
	text.Size = UDim2.fromScale(1, 0.5)
	text.Font = Enum.Font.Kalam
	text.TextScaled = true
	text.Text = "Spez"
	text.TextColor3 = Color3.fromRGB(252, 250, 246)
	text.Rotation = -6
	text.Parent = gui
end

-- Builds a full can, upright at `cframe` (its centre). Not parented yet.
local function buildCan(cframe: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "SpezColaCan"
	-- The body: the only part that collides (it rolls and bounces a little).
	local body = canPart(
		model,
		nil,
		"Body",
		Enum.PartType.Cylinder,
		Vector3.new(0.72, 0.44, 0.44),
		cframe,
		CAN_RED,
		Enum.Material.SmoothPlastic
	)
	body.Reflectance = 0.06
	body.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.6, 0.2, 1, 1)
	model.PrimaryPart = body

	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	-- the tapered neck and the rolled top rim (aluminium)
	canPart(
		model,
		body,
		"Neck",
		Enum.PartType.Cylinder,
		Vector3.new(0.05, 0.41, 0.41),
		at(0, 0.385, 0),
		SILVER,
		Enum.Material.Metal
	)
	canPart(
		model,
		body,
		"TopRim",
		Enum.PartType.Cylinder,
		Vector3.new(0.04, 0.37, 0.37),
		at(0, 0.425, 0),
		SILVER,
		Enum.Material.Metal
	)
	-- the lid, a bit darker, sunk inside the rim
	canPart(
		model,
		body,
		"Lid",
		Enum.PartType.Cylinder,
		Vector3.new(0.02, 0.32, 0.32),
		at(0, 0.44, 0),
		SILVER_DARK,
		Enum.Material.Metal
	)
	-- the pull tab (and its rivet) on the lid
	canPart(
		model,
		body,
		"Tab",
		Enum.PartType.Block,
		Vector3.new(0.09, 0.015, 0.15),
		at(0, 0.455, 0.035),
		SILVER,
		Enum.Material.Metal
	)
	canPart(
		model,
		body,
		"Rivet",
		Enum.PartType.Cylinder,
		Vector3.new(0.02, 0.04, 0.04),
		at(0, 0.458, -0.02),
		SILVER_DARK,
		Enum.Material.Metal
	)
	-- the bottom dome
	canPart(
		model,
		body,
		"BottomRim",
		Enum.PartType.Cylinder,
		Vector3.new(0.05, 0.4, 0.4),
		at(0, -0.38, 0),
		SILVER,
		Enum.Material.Metal
	)
	-- a thin white ring around the lower part (the brand's band)
	canPart(
		model,
		body,
		"Band",
		Enum.PartType.Cylinder,
		Vector3.new(0.04, 0.446, 0.446),
		at(0, -0.24, 0),
		Color3.fromRGB(246, 244, 238),
		Enum.Material.SmoothPlastic
	)
	-- the printed label, on the front and the back
	addLabel(model, body, "LabelFront", at(0, 0.02, -0.226))
	addLabel(model, body, "LabelBack", at(0, 0.02, 0.226) * CFrame.Angles(0, math.pi, 0))
	CollectionService:AddTag(model, CAN_TAG)
	return model, body
end

------------------------------------------------------------------------------
-- Cans in the world
------------------------------------------------------------------------------

local function removeFrom(list: { Can }, can: Can)
	local index = table.find(list, can)
	if index then
		table.remove(list, index)
	end
end

local function destroyCan(can: Can)
	removeFrom(allCans, can)
	local machine = can.machine
	if machine then
		removeFrom(machine.cans, can)
	end
	can.model:Destroy()
end

-- Too many cans: the oldest LOOSE / EMPTY one goes (never one in someone's hand).
local function trimOldest(list: { Can }, max: number)
	while #list > max do
		local victim: Can? = nil
		for _, can in list do
			if can.state ~= "Held" then
				victim = can
				break
			end
		end
		if victim == nil then
			return
		end
		destroyCan(victim)
	end
end

-- Takes the can out of the hand (removes the weld to the arm).
local function unweld(can: Can)
	local grip = can.body:FindFirstChild("Grip")
	if grip then
		grip:Destroy()
	end
end

-- After the can left the hand: it falls / flies with `velocity`, becomes "Empty" and goes
-- away a few seconds later.
local function releaseCan(can: Can, velocity: Vector3)
	can.state = "Empty"
	can.prompt.Enabled = false
	unweld(can)
	local body = can.body
	body.Massless = false
	body.CanCollide = true
	-- Out of the hand it is its own piece again: the server moves it (the same for everyone,
	-- and no client can fling it around).
	pcall(function()
		body:SetNetworkOwner(nil)
	end)
	body.AssemblyLinearVelocity = velocity
	body.AssemblyAngularVelocity = Vector3.new(math.random() * 16 - 8, math.random() * 8 - 4, 10)
	task.delay(CC.EMPTY_LIFETIME, function()
		if can.model.Parent ~= nil then
			destroyCan(can)
		end
	end)
end

------------------------------------------------------------------------------
-- Drinking
------------------------------------------------------------------------------

-- Can this player start drinking right now? (No message when not: the prompt just does
-- nothing, as asked.)
local function canDrink(player: Player, character: Model, humanoid: Humanoid): boolean
	if humanoid.Health <= 0 or drinks[player] ~= nil then
		return false
	end
	if player:GetAttribute("InDuel") == true or character:GetAttribute("DuelId") ~= nil then
		return false
	end
	if Knockout.isKnockedOut(character) or Combat.isInCinematic(character) then
		return false
	end
	if character:GetAttribute("InCinematic") == true then
		return false
	end
	local combatUntil = player:GetAttribute("CombatUntil")
	if typeof(combatUntil) == "number" and combatUntil > workspace:GetServerTimeNow() then
		return false
	end
	return Combat.isIdle(character)
end

-- Ends a drink. `finished` = drunk to the end (crushed and tossed), else it just drops.
-- `leaving` = the player is leaving the game: their Movement state is (or is about to be)
-- gone, so we don't touch it (setSpeedModifier would create a new one that never goes away).
local function endDrink(drink: Drink, finished: boolean, leaving: boolean?)
	if drinks[drink.player] ~= drink then
		return
	end
	drinks[drink.player] = nil
	if leaving ~= true then
		Movement.setSpeedModifier(drink.player, SPEED_KEY, nil)
	end
	local can = drink.can
	if can.model.Parent == nil then
		return
	end
	local root = drink.character:FindFirstChild("HumanoidRootPart")
	local look = if root and root:IsA("BasePart") then root.CFrame.LookVector else Vector3.zero
	local right = if root and root:IsA("BasePart") then root.CFrame.RightVector else Vector3.zero
	unweld(can) -- (before scaling: a welded part would drag the arm along)
	if finished then
		-- crushed in the hand: a bit smaller and squashed-looking (the lid sinks)
		can.model:ScaleTo(0.85)
		local lid = can.model:FindFirstChild("Lid")
		if lid and lid:IsA("BasePart") then
			lid.Color = Color3.fromRGB(110, 112, 118)
		end
		can.body.Color = can.body.Color:Lerp(Color3.new(0, 0, 0), 0.15)
		-- tossed forward-right, over the shoulder of nobody
		releaseCan(can, look * 9 + right * 4 + Vector3.new(0, 11, 0))
	else
		-- dropped (hit, attacked, died): it just falls
		releaseCan(can, Vector3.new(0, -2, 0))
	end
end

local function startDrink(player: Player, can: Can)
	local character = player.Character
	if character == nil or can.state ~= "Loose" then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local arm = character:FindFirstChild("Right Arm")
	local root = character:FindFirstChild("HumanoidRootPart")
	if
		humanoid == nil
		or arm == nil
		or not arm:IsA("BasePart")
		or root == nil
		or not root:IsA("BasePart")
	then
		return
	end
	-- (the prompt's distance is checked by Roblox; a small margin for the server's view)
	if (root.Position - can.body.Position).Magnitude > CC.DRINK_DISTANCE + 4 then
		return
	end
	if not canDrink(player, character, humanoid) then
		return
	end

	-- The can is ours now: off the machine's list, into the hand.
	can.state = "Held"
	can.prompt.Enabled = false
	local machine = can.machine
	if machine then
		removeFrom(machine.cans, can)
		can.machine = nil
	end
	local body = can.body
	body.Anchored = false
	body.CanCollide = false
	body.Massless = true -- (doesn't weigh the arm down / tip the character)
	body.AssemblyLinearVelocity = Vector3.zero
	body.AssemblyAngularVelocity = Vector3.zero
	-- A Weld (not a WeldConstraint) to the Right Arm: it follows the arm that each client
	-- poses for the drinking clip. C0 = where the can sits in the hand (upright).
	local weld = Instance.new("Weld")
	weld.Name = "Grip"
	weld.Part0 = arm
	weld.Part1 = body
	weld.C0 = GRIP * UPRIGHT
	weld.Parent = body

	local drink: Drink = {
		can = can,
		player = player,
		character = character,
		humanoid = humanoid,
		weld = weld,
	}
	drinks[player] = drink
	Movement.setSpeedModifier(player, SPEED_KEY, CC.DRINK_SPEED)
	Remotes.CombatAction:FireAllClients(character, DRINK_ANIMATION)

	-- Watch the drink: cancelled if they start fighting / sliding, die or leave.
	task.spawn(function()
		local started = os.clock()
		while drinks[player] == drink do
			task.wait(0.1)
			if drinks[player] ~= drink then
				return
			end
			local gone = character.Parent == nil
				or humanoid.Health <= 0
				or weld.Parent == nil
				or weld.Part0 == nil
				or Knockout.isKnockedOut(character)
				or not Combat.isIdle(character)
			if gone then
				endDrink(drink, false, player.Parent == nil)
				return
			end
			-- (tossed while the arm comes down, just before the clip ends)
			if os.clock() - started >= CC.DRINK_TIME - 0.2 then
				endDrink(drink, true)
				return
			end
		end
	end)
end

------------------------------------------------------------------------------
-- The machines
------------------------------------------------------------------------------

-- The button lights up for a moment (white flash, then back to its colour).
local function flashButton(button: BasePart)
	local light = button:FindFirstChild("PressLight")
	if light == nil then
		local newLight = Instance.new("PointLight")
		newLight.Name = "PressLight"
		newLight.Range = 5
		newLight.Color = Color3.fromRGB(255, 236, 220)
		newLight.Brightness = 0
		newLight.Shadows = false
		newLight.Parent = button
		light = newLight
	end
	if light and light:IsA("PointLight") then
		light.Brightness = 3
		TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	end
	local color = button:GetAttribute("BaseColor")
	if typeof(color) ~= "Color3" then
		button:SetAttribute("BaseColor", button.Color)
		color = button.Color
	end
	button.Color = Color3.fromRGB(255, 250, 240)
	TweenService:Create(button, TweenInfo.new(0.45), { Color = color :: Color3 }):Play()
end

-- Drops a can out of the machine's tray.
local function dispense(machine: Machine)
	local dispenser = machine.dispenser
	local out = dispenser.CFrame.LookVector
	local flatOut = Vector3.new(out.X, 0, out.Z)
	flatOut = if flatOut.Magnitude > 1e-3 then flatOut.Unit else Vector3.new(0, 0, -1)
	-- The can comes out lying on its side (across the tray), a hair in front of the opening.
	local position = dispenser.Position + flatOut * 0.25
	local across = CFrame.lookAt(position, position + flatOut) * CFrame.Angles(0, 0, math.pi / 2)
	local model, body = buildCan(across)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrinkPrompt"
	prompt.ActionText = "DRINK"
	prompt.ObjectText = "SPEZCOLA"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = CC.DRINK_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	local can: Can = {
		model = model,
		body = body,
		prompt = prompt,
		machine = machine,
		state = "Loose",
		born = os.clock(),
	}
	prompt.Triggered:Connect(function(player)
		startDrink(player, can)
	end)
	model.Parent = folder
	pcall(function()
		body:SetNetworkOwner(nil) -- the server moves it (no client can throw it around)
	end)
	-- out of the tray, a little push towards the player, a bit of spin
	body.AssemblyLinearVelocity = flatOut * 5.5 + Vector3.new(0, 1.5, 0)
	body.AssemblyAngularVelocity = Vector3.new(0, math.random() * 2 - 1, 0)

	table.insert(machine.cans, can)
	table.insert(allCans, can)
	trimOldest(machine.cans, CC.MAX_PER_MACHINE)
	trimOldest(allCans, CC.MAX_TOTAL)

	task.delay(CC.CAN_LIFETIME, function()
		if can.state == "Loose" and model.Parent ~= nil then
			destroyCan(can)
		end
	end)
end

local function onMachinePrompt(machine: Machine, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if Knockout.isKnockedOut(character) then
		return
	end
	-- (Roblox checks the prompt's distance, but never trust the client: our own check too)
	local root = character:FindFirstChild("HumanoidRootPart")
	if
		root == nil
		or not root:IsA("BasePart")
		or (root.Position - machine.button.Position).Magnitude > CC.PROMPT_DISTANCE + 4
	then
		return
	end
	local time = os.clock()
	local last = lastCanAt[player]
	if last and time - last < CC.COOLDOWN then
		return
	end
	if time < machine.busyUntil then
		return -- the machine is still dropping the last one
	end
	lastCanAt[player] = time
	machine.busyUntil = time + CC.DISPENSE_DELAY + 0.2
	flashButton(machine.button)
	task.delay(CC.DISPENSE_DELAY, function()
		if machine.model.Parent ~= nil then
			dispense(machine)
		end
	end)
end

local function addMachine(instance: Instance)
	if not instance:IsA("Model") or machines[instance] then
		return
	end
	local model = instance :: Model
	-- (the city is built in the background: the children may still be arriving)
	local button = model:WaitForChild("Button", 15)
	local dispenser = model:WaitForChild("Dispenser", 15)
	if
		button == nil
		or dispenser == nil
		or not button:IsA("BasePart")
		or not dispenser:IsA("BasePart")
		or machines[model]
	then
		if button == nil or dispenser == nil then
			warn(`[SpezCola] {model:GetFullName()} has no Button / Dispenser part`)
		end
		return
	end
	local machine: Machine = {
		model = model,
		button = button,
		dispenser = dispenser,
		cans = {},
		busyUntil = 0,
	}
	machines[model] = machine

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ColaPrompt"
	prompt.ActionText = "GET A SPEZCOLA"
	prompt.ObjectText = "SPEZCOLA"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = CC.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = button
	prompt.Triggered:Connect(function(player)
		onMachinePrompt(machine, player)
	end)

	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			machines[model] = nil
		end
	end)
end

function SpezCola.start()
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = workspace
	end

	-- Hit while drinking: the can falls.
	Combat.onDamaged(function(info)
		local player = Players:GetPlayerFromCharacter(info.victim)
		local drink = player and drinks[player]
		if drink then
			endDrink(drink, false)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local drink = drinks[player]
		if drink then
			endDrink(drink, false, true)
		end
		lastCanAt[player] = nil
	end)

	CollectionService:GetInstanceAddedSignal(MACHINE_TAG):Connect(function(instance)
		task.spawn(addMachine, instance)
	end)
	for _, instance in CollectionService:GetTagged(MACHINE_TAG) do
		task.spawn(addMachine, instance)
	end
end

return SpezCola
