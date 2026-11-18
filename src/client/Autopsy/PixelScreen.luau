--!strict
-- PixelScreen: the old-school PIXEL screen of the operation. Roblox has no
-- post-process hook, so the picture is drawn by script: a small software
-- ray tracer (PixelWorker, in parallel in a few Actors) fills ONE low-res
-- EditableImage (PIXEL_HEIGHT rows), shown full screen with Pixelated
-- resampling: crisp square pixels, a limited palette, dither, outlines.
-- (DevForum "RetroRaster" approach; the ViewportFrame trick blurs and
-- can't see the live scene.)
--
--   PixelScreen.start(scene) -> boolean   false: EditableImage not allowed here
--   PixelScreen.stop()
--   PixelScreen.isOn() -> boolean

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PixelScreen = {}

export type Scene = {
	include: { Instance }, -- what the rays see
	lamp: Vector3,
	lampDown: Vector3,
	side: Vector3,
}

local PIXEL_HEIGHT = 108 -- rows (90 = chunkier and faster, 135 = finer)
local BANDS = 8 -- Actors (CPU cores) sharing the rows
local NAVY = 45 + 47 * 256 + 77 * 65536 + 255 * 16777216
local CURSOR = 223 + 246 * 256 + 179 * 65536 + 255 * 16777216

local player = Players.LocalPlayer

local actors: { Actor } = {}
local doneEvent: BindableEvent? = nil
local gui: ScreenGui? = nil
local label: ImageLabel? = nil
local image: EditableImage? = nil
local frame: buffer = buffer.create(4)
local compose: buffer = buffer.create(4)
local width, height = 0, 0
local offsets: { number } = {}
local busy: { number } = {} -- (when each band was sent; 0 = free)
local scene: Scene? = nil
local on = false
local parity = 0
local resizeCheck = 0

local function makeActors()
	if #actors > 0 then
		return
	end
	local template = script.Parent:FindFirstChild("PixelWorker")
	local scripts = player:WaitForChild("PlayerScripts")
	local event = Instance.new("BindableEvent")
	event.Name = "PixelBandDone"
	event.Event:Connect(function(bandIndex: number, data: buffer)
		local offset = offsets[bandIndex]
		if offset and buffer.len(data) + offset <= buffer.len(frame) then
			buffer.copy(frame, offset, data)
		end
		busy[bandIndex] = 0
	end)
	doneEvent = event
	event.Parent = scripts
	for index = 1, BANDS do
		local actor = Instance.new("Actor")
		actor.Name = `AutopsyPixels{index}`
		if template then
			template:Clone().Parent = actor
		end
		actor.Parent = scripts
		actors[index] = actor
		busy[index] = 0
	end
	task.wait(0.3) -- (the workers bind their messages)
end

-- (Re)creates the image for the screen's shape and tells the workers.
local function setup(): boolean
	local camera = workspace.CurrentCamera
	local current = scene
	if camera == nil or current == nil then
		return false
	end
	local view = camera.ViewportSize
	height = PIXEL_HEIGHT
	width = math.max(16, math.floor(PIXEL_HEIGHT * view.X / math.max(view.Y, 1) + 0.5))
	local ok, made = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })
	end)
	if not ok or made == nil then
		warn(
			`[Autopsy] no pixel screen: EditableImage refused ({made}). Studio: Game Settings > Security > allow Mesh / Image APIs.`
		)
		return false
	end
	if image then
		image:Destroy()
	end
	image = made
	frame = buffer.create(width * height * 4)
	compose = buffer.create(width * height * 4)
	for index = 0, width * height - 1 do
		buffer.writeu32(frame, index * 4, NAVY)
	end
	if label then
		-- (Content: a newer global than selene's std knows)
		-- selene: allow(undefined_variable)
		label.ImageContent = Content.fromObject(made)
	end
	local rows = math.ceil(height / BANDS)
	for index, actor in actors do
		local row0 = (index - 1) * rows
		local row1 = math.min(height - 1, index * rows - 1)
		offsets[index] = row0 * width * 4
		busy[index] = 0
		actor:SendMessage("Setup", {
			width = width,
			height = height,
			row0 = row0,
			row1 = row1,
			band = index,
			include = current.include,
			lamp = current.lamp,
			lampDown = current.lampDown,
			side = current.side,
			done = doneEvent,
		})
	end
	return true
end

-- The cursor: a small pixel cross, on the low-res grid too.
local function drawCursor()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local view = camera.ViewportSize
	local cx = math.floor(mouse.X / view.X * width)
	local cy = math.floor(mouse.Y / view.Y * height)
	for _, d in
		{
			{ 0, 0 },
			{ -2, 0 },
			{ 2, 0 },
			{ 0, -2 },
			{ 0, 2 },
			{ -3, 0 },
			{ 3, 0 },
			{ 0, -3 },
			{ 0, 3 },
		}
	do
		local x, y = cx + d[1], cy + d[2]
		if x >= 0 and x < width and y >= 0 and y < height then
			buffer.writeu32(
				compose,
				(y * width + x) * 4,
				if d[1] == 0 and d[2] == 0 then NAVY else CURSOR
			)
		end
	end
end

local function step()
	local camera = workspace.CurrentCamera
	local img = image
	if not on or camera == nil or img == nil then
		return
	end
	local now = os.clock()
	if now > resizeCheck then
		resizeCheck = now + 1
		local view = camera.ViewportSize
		local want = math.max(16, math.floor(PIXEL_HEIGHT * view.X / math.max(view.Y, 1) + 0.5))
		if want ~= width and not setup() then
			return
		end
	end
	-- send the next frame to every free worker (odd / even rows in turn)
	parity = 1 - parity
	local tanY = math.tan(math.rad(camera.FieldOfView) / 2)
	for index, actor in actors do
		local sent = busy[index]
		if sent == 0 or now - sent > 1 then
			busy[index] = now
			actor:SendMessage("Frame", camera.CFrame, tanY, parity)
		end
	end
	buffer.copy(compose, 0, frame)
	drawCursor()
	img:WritePixelsBuffer(Vector2.zero, img.Size, compose)
end

function PixelScreen.start(sceneInfo: Scene): boolean
	if on then
		return true
	end
	scene = sceneInfo
	makeActors()
	if gui == nil then
		local screen = Instance.new("ScreenGui")
		screen.Name = "AutopsyPixels"
		screen.IgnoreGuiInset = true
		screen.ResetOnSpawn = false
		screen.DisplayOrder = 50
		local picture = Instance.new("ImageLabel")
		picture.Name = "Picture"
		picture.Size = UDim2.fromScale(1, 1)
		picture.BackgroundColor3 = Color3.fromRGB(45, 47, 77)
		picture.BorderSizePixel = 0
		picture.ScaleType = Enum.ScaleType.Stretch
		picture.ResampleMode = Enum.ResamplerMode.Pixelated
		picture.Parent = screen
		label = picture
		gui = screen
	end
	if not setup() then
		return false
	end
	local screen = gui :: ScreenGui
	screen.Enabled = true
	screen.Parent = player:WaitForChild("PlayerGui")
	on = true
	RunService:BindToRenderStep("AutopsyPixels", Enum.RenderPriority.Last.Value, step)
	return true
end

function PixelScreen.stop()
	if not on then
		return
	end
	on = false
	RunService:UnbindFromRenderStep("AutopsyPixels")
	if gui then
		gui.Enabled = false
	end
end

function PixelScreen.isOn(): boolean
	return on
end

return PixelScreen
