--!strict
-- Guard: small helpers shared by the contraband modules.
--   • Guard.send / Guard.notice: the ONLY way they talk to a client (Remotes.ContrabandEvent,
--     always to ONE player, never to everyone).
--   • Guard.canAct: the checks every prompt and remote of the domain does first (the player is
--     alive, standing, not in a cutscene, not busy with an extraction...).
--   • Guard.promptAllowed: Guard.canAct + the shared prompt rate limit + a distance re-check
--     (a ProximityPrompt can be fired by an exploiter from anywhere: never trust it).
--   • Guard.debug: a log line, only in Studio with Config.Contraband.DEBUG_LOG.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Combat = require(script.Parent.Parent.Combat)
local Knockout = require(script.Parent.Parent.Knockout)
local RateLimiter = require(script.Parent.Parent.Parent.Util.RateLimiter)

local Guard = {}

local promptLimiter =
	RateLimiter.new(Config.Contraband.PROMPT_RATE.capacity, Config.Contraband.PROMPT_RATE.perSecond)
local debugOn = RunService:IsStudio() and Config.Contraband.DEBUG_LOG

-- Sends one ContrabandEvent to ONE player.
function Guard.send(player: Player, kind: Types.ContrabandEventKind, data: { [string]: any })
	if player.Parent ~= nil then
		Remotes.ContrabandEvent:FireClient(player, kind, data)
	end
end

-- Typed senders: the payload's shape is checked by --!strict here, the kind can't be mixed up.
-- (the client reads them with the same Types.*Payload)
function Guard.sendLabState(player: Player, payload: Types.LabStatePayload)
	Guard.send(player, "LabState", payload :: any)
end

function Guard.sendCaseState(player: Player, payload: Types.CaseStatePayload)
	Guard.send(player, "CaseState", payload :: any)
end

function Guard.sendExtractState(player: Player, payload: Types.ExtractStatePayload)
	Guard.send(player, "ExtractState", payload :: any)
end

function Guard.sendExtractPicked(player: Player, payload: Types.ExtractPickedPayload)
	Guard.send(player, "ExtractPicked", payload :: any)
end

function Guard.sendExtractDone(player: Player, payload: Types.ExtractDonePayload)
	Guard.send(player, "ExtractDone", payload :: any)
end

function Guard.sendSaleResult(player: Player, payload: Types.SaleResultPayload)
	Guard.send(player, "SaleResult", payload :: any)
end

-- A short English line on the player's screen.
function Guard.notice(player: Player, text: string)
	Guard.send(player, "Notice", { text = text })
end

-- Studio with Config.Contraband.DEBUG_LOG (extra checks and log lines).
function Guard.isDebug(): boolean
	return debugOn
end

function Guard.debug(message: string)
	if debugOn then
		print(`[Contraband] {message}`)
	end
end

-- The player's character, its root and humanoid, if they are all there and alive.
function Guard.body(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if character == nil or character.Parent == nil then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, root, humanoid
end

-- Is the player free to use a contraband prompt / remote right now?
-- (alive, not knocked out, not ragdolled, not in a finisher cutscene, not extracting)
function Guard.canAct(player: Player): boolean
	local character = Guard.body(player)
	if character == nil then
		return false
	end
	if Knockout.isKnockedOut(character) or character:GetAttribute("KnockedOut") == true then
		return false
	end
	if character:GetAttribute("Ragdolled") == true or Combat.isInCinematic(character) then
		return false
	end
	if character:GetAttribute("BeingFinished") == true then
		return false
	end
	return player:GetAttribute("Extracting") ~= true
end

-- Is the player's root within `distance` studs of `position`?
function Guard.near(player: Player, position: Vector3, distance: number): boolean
	local _, root = Guard.body(player)
	return root ~= nil and (root.Position - position).Magnitude <= distance
end

-- The checks every contraband ProximityPrompt does on the server when it is triggered.
function Guard.promptAllowed(player: Player, prompt: ProximityPrompt): boolean
	if not promptLimiter.allow(player) or not Guard.canAct(player) then
		return false
	end
	local part = prompt.Parent
	if part == nil or not part:IsA("BasePart") then
		return false
	end
	return Guard.near(player, part.Position, prompt.MaxActivationDistance + 2)
end

-- Makes a server ProximityPrompt (E by default).
function Guard.makePrompt(
	parent: BasePart,
	name: string,
	actionText: string,
	objectText: string,
	hold: number,
	distance: number,
	lineOfSight: boolean
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = lineOfSight
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = parent
	return prompt
end

-- An invisible, anchored marker part (no collisions, no queries, no touches).
function Guard.marker(name: string, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.one
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = cframe
	part.Parent = parent
	return part
end

-- A folder directly under Workspace (found or made).
function Guard.worldFolder(name: string): Folder
	local found = workspace:FindFirstChild(name)
	if found and found:IsA("Folder") then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

-- Is the number a real, finite number (not NaN, not ±inf)?
function Guard.isFinite(value: any): boolean
	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

-- Waits (max `timeout` s) until the city is built. Returns the City folder, or nil.
function Guard.waitForCity(timeout: number): Instance?
	local city = workspace:WaitForChild("City", timeout)
	if city == nil then
		return nil
	end
	local deadline = os.clock() + timeout
	while city:GetAttribute("Built") ~= true do
		if os.clock() > deadline or city.Parent == nil then
			return nil
		end
		task.wait(0.5)
	end
	return city
end

return Guard
