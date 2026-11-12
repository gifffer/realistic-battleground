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

	-- client → server  (wantsToSprint: boolean)
	-- "Shift pressed / released". The server decides if the player can
	-- actually sprint (stamina) and sets their speed.
	SetSprinting = event("SetSprinting"),

	-- client → server  (crouching: boolean)
	-- "C pressed": crouch / stand up. Only a wish, like SetSprinting.
	SetCrouching = event("SetCrouching"),

	-- client → server  (action: Types.MoveAction)
	-- "I start a slide / a ledge climb" (or "Cancel"). The client starts the
	-- move right away so it feels instant; the server checks it (stamina,
	-- cooldown, is there really a ledge?) and confirms it through the
	-- "MoveState" attribute. No confirmation = the client stops the move.
	RequestMoveAction = event("RequestMoveAction"),

	-- client → server  (name: string, value: any)
	-- Change one setting from the Settings window. The server checks the name
	-- and the type of the value (see Server/Systems/Settings).
	UpdateSetting = event("UpdateSetting"),

	-- client → server  (aim: Vector3?, attackId: number?)
	-- `attackId` = a number the client gives each M1, sent back in CombatEvent
	-- so the client can match the result with what it predicted.
	-- "I want to M1", aiming in this direction (from my head to the point
	-- under my crosshair). The server checks timing and the direction, finds
	-- who is hit, then casts the aim ray ITSELF to find the zone (head /
	-- torso) and checks that body part is inside the hitbox.
	-- (Near a knocked-out fighter, an M1 finishes them instead.)
	Attack = event("Attack"),

	-- client → server  (wantsToBlock: boolean)
	-- F pressed / released.
	SetBlocking = event("SetBlocking"),

	-- client → server  (animation: string)
	-- "I just dashed". The client moves itself right away (feels instant);
	-- the server checks cooldown + stamina and gives the dodge frames.
	-- `animation` = "DashForward" / "DashBack" / "DashLeft" / "DashRight"
	-- (only used so the other players see the right dash animation).
	Dash = event("Dash"),

	-- server → all clients  (fighter: Model, action: string)
	-- A fighter started a move (an M1 "Brawler_M1_2", a dash "DashLeft"...):
	-- every client plays the matching animation and sound on that fighter.
	-- (The fighter's own client already did, the moment the key was pressed.)
	CombatAction = event("CombatAction"),

	-- server → all clients  (kind: Types.CombatEventKind, victim: Model, attacker: Model,
	--                        zone: Types.HitZone?, side: Types.HitSide?, attackId: number?,
	--                        moveId: string?, blood: boolean?, skinTearSeed: number?)
	-- Something happened in a fight; clients show effects (flash, text, shake)
	-- and the victim's reaction, chosen from where (zone) and from which side
	-- of the victim (side) the hit landed. `attackId` = the attacker's number
	-- for that M1 (see Attack), nil for dummies. `moveId` = the kit move that
	-- landed ("BottleSmash"...), nil for an M1. `blood` = the hit draws
	-- visible blood (rolled by the server: every client shows it). A number in
	-- `skinTearSeed` = glass cut the skin: every client shows the same blood
	-- and shreds (random numbers from that seed). The cut itself is a
	-- "Gash_<Part>_<n>" attribute (Shared/Util/Gash).
	CombatEvent = event("CombatEvent"),

	-- server → all clients  (attacker: Model, victim: Model, cinematic: string, anchor: CFrame)
	-- A cinematic finisher starts (Shared/Finishers): every client plays its
	-- effects; the two fighters' clients also play its camera. `anchor` =
	-- where the attacker stands (the timeline's positions are relative to it).
	FinisherStarted = event("FinisherStarted"),

	-- server → all  (attacker: Model, victim: Model, killed: boolean)
	-- That cinematic finisher is over: played to the end (killed), or cut
	-- short before the killing blow (killed = false: stop the cutscene).
	FinisherEnded = event("FinisherEnded"),

	-- TEMPORARY (FinisherShowcase, Studio only; delete with it):
	-- client → server  (fighter: string)  "play this showcase fighter's
	-- finisher once" ("Street Brawler" / "Boxer").
	ShowcaseTrigger = event("ShowcaseTrigger"),

	-- server → ONE client  (attackId: number)
	-- "Your M1 number `attackId` is over" (after all its CombatEvents). Lets
	-- the attacker undo a hit it predicted that the server never confirmed.
	AttackResolved = event("AttackResolved"),

	-- client → server  (slot: number, aim: Vector3?, requestId: number)
	-- "I use the move on key `slot` (1–4) of my kit" (the Awakening version
	-- if I'm awakened). The server checks everything (cooldown, stamina,
	-- stun...) and answers with CombatAction to everyone, or MoveRefused.
	UseMove = event("UseMove"),

	-- client → server  ()
	-- "G pressed": awaken (Street Fury...) if the gauge is full.
	Awaken = event("Awaken"),

	-- server → ONE client  (slot: number, requestId: number?)
	-- "Your move request `requestId` was refused" (the client had already
	-- started its animation to feel instant: it stops it).
	MoveRefused = event("MoveRefused"),

	-- client → server  (kitId: string)
	-- Equip a kit from the Kits menu. Saved. Only kits that are available.
	EquipKit = event("EquipKit"),

	-- server → ONE client  (kind: Types.RewardKind, xp: number, coins: number)
	-- "You earned this" (kill, assist...): the HUD shows "+50 XP · +10". The
	-- new totals arrive with the save (ProfileUpdated) as usual.
	Progress = event("Progress"),

	-- client → server  (kitId: string)
	-- Buy a kit from the Kits menu (level and coins checked by the server).
	BuyKit = event("BuyKit"),

	-- client → server  (targetUserId: number)
	-- "I challenge this player to a duel" (Duel menu).
	DuelChallenge = event("DuelChallenge"),

	-- client → server  (challengerUserId: number, accept: boolean)
	-- Answer to a challenge.
	DuelRespond = event("DuelRespond"),

	-- client → server  (searching: boolean)
	-- Join / leave the ranked matchmaking.
	DuelQueue = event("DuelQueue"),

	-- server → ONE client  (kind: Types.DuelEventKind, data: { [string]: any })
	-- Everything about your duels (see Types.DuelEventKind for the data).
	DuelEvent = event("DuelEvent"),

	-- client → server  (itemId: string)
	-- Buy a cosmetic in the SHOP (coins, level checked by the server).
	BuyCosmetic = event("BuyCosmetic"),

	-- client → server  (category: string, itemId: string)  ("" = take it off)
	-- Equip a cosmetic you own.
	EquipCosmetic = event("EquipCosmetic"),

	-- client → server  ()
	-- "B pressed": play my equipped emote (not while fighting).
	Emote = event("Emote"),

	-- server → all clients  (effect: string, position: Vector3)
	-- A finisher with a kill effect equipped: every client plays it there.
	KillEffect = event("KillEffect"),

	-- server → all clients  (kind: Types.KillFeedKind, victimName: string, killerName: string?,
	--                        victimLevel: number?, killerLevel: number?)
	-- A fighter was eliminated: one line in the kill feed (top right).
	KillFeed = event("KillFeed"),
})
