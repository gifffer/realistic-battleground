--!strict
-- Every RemoteEvent of the game, declared in ONE place.
-- The server creates them (ReplicatedStorage > Remotes), clients wait for them.
--
-- Security reminder: anything a client sends through a remote can be faked.
-- Server handlers must check types, ranges and rate (see PlayerData).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local IS_SERVER = RunService:IsServer()

local function getFolder(): Instance
	if not IS_SERVER then
		return ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local folder = getFolder()

local function event(name: string): RemoteEvent
	if not IS_SERVER then
		return folder:WaitForChild(name) :: RemoteEvent
	end
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

return table.freeze({
	-- server → client  (snapshot: Types.ProfileSnapshot)
	-- The player's save, sent when it loads and after each change.
	ProfileUpdated = event("ProfileUpdated"),

	-- client → server  ()
	-- "Send me my save again" (the first push can arrive before the client listens).
	RequestProfile = event("RequestProfile"),

	-- client → server  (wantSprint: boolean, wantCrouch: boolean)
	-- Which movement keys the player is holding. Only an INTENT: the server
	-- decides the real state (stamina, exhaustion) — see Server/Systems/Movement.
	SetMovementInput = event("SetMovementInput"),
})
