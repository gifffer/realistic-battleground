--!strict
-- Characters: prepares every character when it spawns.
--
--   • Sets health from Config.
--   • Turns OFF passive regeneration (game design: a kill heals, time doesn't;
--     only a slow regen up to 25 HP out of combat, see Combat + Config.Injuries).
--     Roblox puts a script named "Health" in every character that heals 1 %
--     of max health per second; we delete it as soon as the character spawns.
--   • Checks the avatar is R6. The game is built for R6 (6 body parts:
--     simpler animations, ragdoll and hit zones). R6 is NOT forced by code:
--     it is a setting of the place (see docs/SETUP_FR.md, "Avatar R6").
--     If it's wrong, we print a clear warning instead of failing silently.
--   • Gives every fighter the CLASSIC R6 head (their face and skin colour
--     stay): the glass cuts are drawn on an exact copy of that head (see
--     Client/Combat/Gashes), so it must be the same for everyone.
--   • Keeps only the accessories worn on the head (hair, hats, glasses /
--     face accessories) that aren't too big, without collisions: big or
--     body accessories get in the way of the fights (and of the cuts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Characters = {}

local HEAD_SCALE = Vector3.new(1.25, 1.25, 1.25) -- the classic head mesh on a 2x1x1 head
-- Accessories that are kept (the rest is removed).
local KEPT_ACCESSORIES: { [Enum.AccessoryType]: boolean } = {
	[Enum.AccessoryType.Hat] = true,
	[Enum.AccessoryType.Hair] = true,
	[Enum.AccessoryType.Face] = true, -- glasses, masks on the upper face...
	[Enum.AccessoryType.Eyebrow] = true,
	[Enum.AccessoryType.Eyelash] = true,
}
-- Old accessories have no type: kept if they hang on the head.
local HEAD_ATTACHMENTS: { [string]: boolean } = {
	HatAttachment = true,
	HairAttachment = true,
	FaceFrontAttachment = true,
	FaceCenterAttachment = true,
}
local MAX_ACCESSORY_SIDE = 3 -- studs: the biggest side of its handle
local MAX_ACCESSORY_VOLUME = 6 -- cubic studs

-- The classic head: a Head part with a SpecialMesh of type Head.
local function makeClassicHead(head: BasePart)
	if head:IsA("MeshPart") then
		return -- (not an R6 head: left alone)
	end
	local found = head:FindFirstChildOfClass("SpecialMesh")
	local mesh: SpecialMesh
	if found then
		mesh = found
	else
		mesh = Instance.new("SpecialMesh")
		mesh.Parent = head
	end
	if mesh.MeshType ~= Enum.MeshType.Head then
		mesh.MeshType = Enum.MeshType.Head
	end
	if mesh.MeshId ~= "" then
		mesh.MeshId = ""
	end
	if mesh.TextureId ~= "" then
		mesh.TextureId = ""
	end
	if mesh.Scale ~= HEAD_SCALE then
		mesh.Scale = HEAD_SCALE
	end
	if mesh.Offset ~= Vector3.zero then
		mesh.Offset = Vector3.zero
	end
end

local function isKeptAccessory(accessory: Accoutrement): boolean
	local handle = accessory:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		return false
	end
	local size = handle.Size
	local mesh = handle:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		-- (an old hat's mesh can be much bigger than its handle)
		size = Vector3.new(
			math.max(size.X, math.abs(mesh.Scale.X)),
			math.max(size.Y, math.abs(mesh.Scale.Y)),
			math.max(size.Z, math.abs(mesh.Scale.Z))
		)
	end
	if math.max(size.X, size.Y, size.Z) > MAX_ACCESSORY_SIDE then
		return false
	end
	if size.X * size.Y * size.Z > MAX_ACCESSORY_VOLUME then
		return false
	end
	if accessory:IsA("Accessory") and KEPT_ACCESSORIES[accessory.AccessoryType] then
		return true
	end
	if accessory:IsA("Accessory") and accessory.AccessoryType ~= Enum.AccessoryType.Unknown then
		return false -- a body accessory (back, waist, shoulders, clothing...)
	end
	for _, child in handle:GetChildren() do
		if child:IsA("Attachment") and HEAD_ATTACHMENTS[child.Name] then
			return true
		end
	end
	return false
end

local function checkAccessory(child: Instance)
	if not child:IsA("Accoutrement") then
		return
	end
	if not isKeptAccessory(child) then
		child:Destroy()
		return
	end
	-- Kept: it never collides or blocks a hit ray.
	local handle = child:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.CanCollide = false
		handle.CanQuery = false
		handle.CanTouch = false
		handle.Massless = true
	end
end

-- The avatar loads a moment after the character appears: checked now and
-- each time something is added.
local function cleanAppearance(character: Model)
	for _, child in character:GetChildren() do
		checkAccessory(child)
	end
	character.ChildAdded:Connect(function(child: Instance)
		checkAccessory(child)
		if child.Name == "Head" and child:IsA("BasePart") then
			makeClassicHead(child)
		end
	end)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		makeClassicHead(head)
		head.ChildAdded:Connect(function(child: Instance)
			if child:IsA("SpecialMesh") then
				makeClassicHead(head)
			end
		end)
	end
end

local warnedAboutRig = false

-- Deletes Roblox's regeneration script, now or if it shows up a bit later.
local function removeRegeneration(character: Model)
	local function check(child: Instance)
		if child.Name == "Health" and child:IsA("Script") then
			child:Destroy()
		end
	end
	for _, child in character:GetChildren() do
		check(child)
	end
	-- The connection dies with the character (Destroy on respawn), no leak.
	character.ChildAdded:Connect(check)
end

local function onCharacterAdded(character: Model)
	removeRegeneration(character)
	cleanAppearance(character)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R6 and not warnedAboutRig then
		warnedAboutRig = true
		warn(
			"[Characters] Avatars are not R6. Set Avatar Type to R6 in Studio "
				.. "(see docs/SETUP_FR.md, 'Avatar R6'), then publish the place."
		)
	end

	humanoid.MaxHealth = Config.Character.MAX_HEALTH
	humanoid.Health = Config.Character.MAX_HEALTH
	humanoid.WalkSpeed = Config.Character.WALK_SPEED
end

local function onPlayerAdded(player: Player)
	-- Roblox's built-in "Shift lock" uses Shift, which is our sprint key.
	-- Our CameraController already locks the mouse, so turn Roblox's one off.
	-- (Also set in default.project.json; done here too in case it isn't synced.)
	player.DevEnableMouseLock = false

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

function Characters.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this script ran (happens in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Characters
