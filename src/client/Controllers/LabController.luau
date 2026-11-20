--!strict
-- LabController: your private lab, as YOU see it (client only).
--
-- The server builds the lab room (Server/Systems/Contraband/LabBuilder: Model "Lab_<your
-- UserId>" in Workspace > Labs, with named marker parts) and owns every rule. This
-- controller only DRAWS what the server tells it:
--   • the vat's contents (Contraband/VatVisual: fluid, bubbles, glow, the clone growing
--     MATRIX → FRAME → SHELL, the vat screen), computed every frame from the last
--     "LabState" timestamps: progress = (grown + (now - at)) / total while running. The server
--     never ticks the progress over the network; it only sends a new LabState when something
--     changes (and every RESYNC_EVERY seconds while you are in the lab);
--   • your stash: one capsule per bio-core on the stash shelf, coloured by grade (the server
--     sends only the grades, never ids);
--   • the "Lab" lighting look is NOT done here: the server sets the ZoneLook attribute and
--     ZoneLookController blends it.
-- The extraction itself (bench, camera, gestures) is ExtractionController.
--
--   LabController.state()            the last LabState (or nil)
--   LabController.parts()            the lab's named parts once streamed in (or nil)
--   LabController.visuals()          the local Folder the lab visuals live in
--   LabController.setCloneHidden(b)  hides the vat clone (it is on the bench meanwhile)
--   LabController.progress()         culture progress now (0..1)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local Contraband = script.Parent.Parent.Contraband
local CoreModel = require(Contraband.CoreModel)
local VatVisual = require(Contraband.VatVisual)
local SoundController = require(script.Parent.SoundController)

local player = Players.LocalPlayer

local LabController = {}

export type LabParts = {
	model: Model,
	vatCore: BasePart,
	vatScreen: BasePart?,
	benchAnchor: BasePart,
	chuteMouth: BasePart?,
	stashShelf: BasePart?,
}

-- Draw the vat only when the camera is this close (studs): the labs are far from the city.
local DRAW_DISTANCE = 90
-- How often we look for our lab model (seconds).
local FIND_EVERY = 0.5

local state: Types.LabStatePayload? = nil
local labParts: LabParts? = nil
local vat: VatVisual.Vat? = nil
local folder: Folder? = nil
local cloneHidden = false
local snapNext = true
local shelf: { Model } = {}
local shelfKey = ""
local findTimer = 0

local function getFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "LabVisuals"
	made.Parent = workspace
	folder = made
	return made
end

local function findPart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function clearShelf()
	for _, capsule in shelf do
		capsule:Destroy()
	end
	table.clear(shelf)
	shelfKey = ""
end

local function teardown()
	if vat then
		VatVisual.destroy(vat)
		vat = nil
	end
	clearShelf()
	labParts = nil
end

-- Looks for Workspace > Labs > Lab_<UserId> and its markers; builds / drops the visuals.
local function findLab()
	local labs = workspace:FindFirstChild("Labs")
	local model = if labs then labs:FindFirstChild(`Lab_{player.UserId}`) else nil
	if model == nil or not model:IsA("Model") then
		if labParts then
			teardown()
		end
		return
	end
	local current = labParts
	if current and current.model == model and current.vatCore.Parent ~= nil then
		return
	end
	teardown()
	local vatCore = findPart(model, "VatCore")
	local bench = findPart(model, "BenchAnchor")
	if vatCore == nil or bench == nil then
		return -- (still streaming in)
	end
	labParts = {
		model = model,
		vatCore = vatCore,
		vatScreen = findPart(model, "VatScreen"),
		benchAnchor = bench,
		chuteMouth = findPart(model, "ChuteMouth"),
		stashShelf = findPart(model, "StashShelf"),
	}
	vat = VatVisual.new(vatCore, findPart(model, "VatScreen"), getFolder())
	snapNext = true
	-- (ask for our state again: the lab may have been built before we listened)
	Remotes.ContrabandSync:FireServer()
end

-- One capsule per stash core on the shelf, rebuilt only when the list changes.
local function updateShelf()
	local parts = labParts
	local current = state
	local shelfPart = if parts then parts.stashShelf else nil
	if current == nil or shelfPart == nil then
		clearShelf()
		return
	end
	local key = table.concat(current.bench, ",")
	if key == shelfKey then
		return
	end
	clearShelf()
	shelfKey = key
	for index, grade in current.bench do
		if index > 8 then
			break -- (overflow cores after a disconnect: only 8 places on the shelf)
		end
		local capsule = CoreModel.capsule(grade, CoreModel.shelfCFrame(shelfPart.CFrame, index))
		capsule.Parent = getFolder()
		table.insert(shelf, capsule)
	end
end

function LabController.state(): Types.LabStatePayload?
	return state
end

function LabController.parts(): LabParts?
	return labParts
end

function LabController.visuals(): Folder
	return getFolder()
end

function LabController.setCloneHidden(hidden: boolean)
	cloneHidden = hidden
	if vat then
		VatVisual.setCloneHidden(vat, hidden)
	end
end

function LabController.progress(): number
	local current = state
	if current == nil or current.total <= 0 then
		return 0
	end
	local grown = current.grown
	if current.running then
		grown += math.max(0, workspace:GetServerTimeNow() - current.at)
	end
	return math.clamp(grown / current.total, 0, 1)
end

local function render(dt: number)
	findTimer += dt
	if findTimer >= FIND_EVERY then
		findTimer = 0
		findLab()
		updateShelf()
	end
	local currentVat = vat
	local current = state
	local camera = workspace.CurrentCamera
	if currentVat == nil or current == nil or camera == nil then
		return
	end
	if (camera.CFrame.Position - currentVat.core.Position).Magnitude > DRAW_DISTANCE then
		snapNext = true -- (coming back: no phase shift for what happened meanwhile)
		return
	end
	local now = os.clock()
	local progress = LabController.progress()
	VatVisual.setCloneHidden(currentVat, cloneHidden)
	VatVisual.update(currentVat, {
		stage = current.stage,
		progress = progress,
		timeLeft = math.max(0, current.total * (1 - progress)),
		total = current.total,
		running = current.running,
		snap = snapNext,
	}, dt, now)
	snapNext = false
	for _, capsule in shelf do
		CoreModel.animate(capsule, now)
	end
end

function LabController.init()
	Remotes.ContrabandEvent.OnClientEvent:Connect(function(kind: string, data: any)
		if kind ~= "LabState" or typeof(data) ~= "table" then
			return
		end
		local previous = state
		state = data :: Types.LabStatePayload
		if previous and previous.stage == "Growing" and data.stage == "Ready" then
			SoundController.play2D("VatReadyChime")
		end
		-- a new stage that is not just growing on (planted, extracted...): no phase shift
		if previous == nil or previous.stage ~= data.stage then
			snapNext = true
		end
		updateShelf()
	end)
end

function LabController.start()
	RunService.RenderStepped:Connect(render)
	-- (the first LabState can be sent before we listen)
	Remotes.ContrabandSync:FireServer()
end

return LabController
