--!strict
-- AimController: where you aim — the opponent's head, torso or legs.
--
-- The centre of the screen (where the crosshair is) decides:
--   • a ray goes from the camera through the crosshair; if it touches an
--     opponent, the body part it touches gives the zone (head = "Head",
--     torso / arms = "Torso", legs = "Legs");
--   • if it touches nothing, the camera's angle decides: looking up = head,
--     looking down = legs, straight = torso.
-- CombatController sends the AIM DIRECTION (from our head to the point under
-- the crosshair) with each M1. The SERVER casts that ray itself to find the
-- zone, and checks the body part is inside the punch's hitbox: the zone
-- shown here is only for the crosshair colour.
--
-- Also draws the crosshair while the mouse is locked: four short arms with
-- a thin dark outline (readable on bright scenes), off-white normally, RED
-- on an opponent's head.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

-- How far the aim ray looks (studs): a bit more than a punch's reach.
local AIM_DISTANCE = 40
-- Camera angle fallback (LookVector.Y): above → head, below → legs.
local LOOK_UP = 0.12
local LOOK_DOWN = -0.35
-- Body part name (R6) → zone.
local PART_ZONES: { [string]: Types.HitZone } = {
	Head = "Head",
	Torso = "Torso",
	HumanoidRootPart = "Torso",
	["Right Arm"] = "Torso",
	["Left Arm"] = "Torso",
	["Right Leg"] = "Legs",
	["Left Leg"] = "Legs",
}
-- Crosshair geometry (px): 25×25, four arms around a 4 px gap.
local ARMS = {
	{ position = Vector2.new(0, 12), size = Vector2.new(8, 1) }, -- left
	{ position = Vector2.new(17, 12), size = Vector2.new(8, 1) }, -- right
	{ position = Vector2.new(12, 0), size = Vector2.new(1, 8) }, -- top
	{ position = Vector2.new(12, 17), size = Vector2.new(1, 8) }, -- bottom
}

local AimController = {}

local currentZone: Types.HitZone = "Torso"
local aimPoint: Vector3 = Vector3.zero -- the world point under the crosshair
local onOpponent = false
local crosshair: Frame? = nil
local arms: { Frame } = {}
local onHead = false
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- Is this part a body part of a fighter (player or training dummy)?
local function fighterPart(part: Instance): Types.HitZone?
	local model = part:FindFirstAncestorOfClass("Model")
	if model == nil or model == player.Character then
		return nil
	end
	if not CollectionService:HasTag(model, Config.Combat.TAG) then
		return nil
	end
	-- Hats, hair... are worn on the head (same rule as the server).
	if part.Parent and part.Parent:IsA("Accessory") then
		return "Head"
	end
	return PART_ZONES[part.Name]
end

local function updateAim()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	-- Where the crosshair is: the centre when the mouse is locked, the mouse otherwise.
	local screenPoint = if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		then camera.ViewportSize / 2
		else UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)

	rayParams.FilterDescendantsInstances = { player.Character :: any }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, rayParams)
	aimPoint = if hit then hit.Position else ray.Origin + ray.Direction * AIM_DISTANCE
	local zone = if hit then fighterPart(hit.Instance) else nil
	onOpponent = zone ~= nil
	if zone == nil then
		local lookY = camera.CFrame.LookVector.Y
		zone = if lookY > LOOK_UP then "Head" elseif lookY < LOOK_DOWN then "Legs" else "Torso"
	end
	currentZone = zone :: Types.HitZone

	local frame = crosshair
	if frame then
		local character = player.Character
		local down = character ~= nil and character:GetAttribute("KnockedOut") == true
		frame.Visible = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and not down
		local head = onOpponent and currentZone == "Head"
		if head ~= onHead then
			onHead = head
			for _, arm in arms do
				Theme.tween(arm, 0.08, {
					BackgroundColor3 = if head then Theme.Colors.BloodHi else Theme.Colors.Ink,
					BackgroundTransparency = if head then 0 else 0.1,
				}, Enum.EasingStyle.Linear)
			end
		end
	end
end

-- The zone aimed at right now (crosshair colour).
function AimController.getZone(): Types.HitZone
	return currentZone
end

-- Direction from our head to the point under the crosshair (sent to the
-- server with each M1), or nil if we have no head.
function AimController.getAimDirection(): Vector3?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return nil
	end
	local offset = aimPoint - head.Position
	return if offset.Magnitude > 0.1 then offset.Unit else nil
end

function AimController.start()
	local gui = Theme.make("ScreenGui", {
		Name = "Crosshair",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local frame = Theme.make("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(25, 25),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}) :: Frame
	for _, arm in ARMS do
		table.insert(
			arms,
			Theme.make("Frame", {
				Position = UDim2.fromOffset(arm.position.X, arm.position.Y),
				Size = UDim2.fromOffset(arm.size.X, arm.size.Y),
				BackgroundColor3 = Theme.Colors.Ink,
				BackgroundTransparency = 0.1,
				Parent = frame,
			}, {
				Theme.make("UIStroke", {
					Thickness = 1,
					Color = Theme.Colors.Scrim,
					Transparency = 0.55,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			})
		)
	end
	crosshair = frame
	RunService.RenderStepped:Connect(updateAim)
end

return AimController
