--!strict
-- Icons: the top bar's and the cards' icons, drawn with frames (no image
-- assets to upload). Line icons like Roblox's own (menu, chat, mic): one
-- stroke width for every line, round ends, drawn on a 22 × 22 grid and
-- scaled to the size asked for, so every icon has the same weight. Rings are
-- at least 6 grid units wide so their holes stay open at 22 px.
--
--   local icon = Icons.draw("kits", parent, 22)       -- a 22 × 22 icon
--   Icons.paint(icon, Color3.new(0, 0, 0))           -- recolour it
--
-- Names: kits, duel, rewards, emotes, shop, profile, settings, effect, title.

local Theme = require(script.Parent.Theme)

export type IconName =
	"kits"
	| "duel"
	| "rewards"
	| "emotes"
	| "shop"
	| "profile"
	| "settings"
	| "effect"
	| "title"

local Icons = {}

local WHITE = Color3.new(1, 1, 1)
local GRID = 22 -- every icon is drawn on this grid
local STROKE = 2 -- line width on the grid (2 px at 22 px)

type Pen = {
	holder: Frame,
	unit: number, -- pixels per grid step
	stroke: number, -- line width in pixels (whole pixels: crisp)
}

-- Grid position → offset pixels.
local function at(pen: Pen, value: number): number
	return value * pen.unit
end

-- A straight line from (x1, y1) to (x2, y2), round ends.
local function line(pen: Pen, x1: number, y1: number, x2: number, y2: number)
	local dx = at(pen, x2 - x1)
	local dy = at(pen, y2 - y1)
	local length = math.sqrt(dx * dx + dy * dy) + pen.stroke
	local frame = Theme.make("Frame", {
		Name = "Part",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at(pen, (x1 + x2) / 2), at(pen, (y1 + y2) / 2)),
		Size = UDim2.fromOffset(length, pen.stroke),
		Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = WHITE,
		Parent = pen.holder,
	})
	Theme.make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
end

-- An outlined box from (x1, y1) to (x2, y2) (the line's middle), corner `round` (grid).
local function box(
	pen: Pen,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	round: number,
	parent: Instance?
)
	local s = pen.stroke
	Theme.make("Frame", {
		Name = "Box",
		Position = UDim2.fromOffset(at(pen, x1) + s / 2, at(pen, y1) + s / 2),
		Size = UDim2.fromOffset(at(pen, x2 - x1) - s, at(pen, y2 - y1) - s),
		BackgroundTransparency = 1,
		Parent = parent or pen.holder,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, at(pen, round)) }),
		Theme.make("UIStroke", {
			Thickness = s,
			Color = WHITE,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

-- An outlined circle: centre (x, y), diameter `d` (grid, the line's middle).
local function ring(pen: Pen, x: number, y: number, d: number, parent: Instance?)
	local s = pen.stroke
	Theme.make("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at(pen, x), at(pen, y)),
		Size = UDim2.fromOffset(at(pen, d) - s, at(pen, d) - s),
		BackgroundTransparency = 1,
		Parent = parent or pen.holder,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Theme.make("UIStroke", {
			Thickness = s,
			Color = WHITE,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

-- A filled dot: centre (x, y), diameter `d` (grid).
local function dot(pen: Pen, x: number, y: number, d: number)
	local frame = Theme.make("Frame", {
		Name = "Part",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at(pen, x), at(pen, y)),
		Size = UDim2.fromOffset(at(pen, d), at(pen, d)),
		BackgroundColor3 = WHITE,
		Parent = pen.holder,
	})
	Theme.make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
end

-- A filled block centred on (x, y): `length` along its axis, `width` across,
-- turned `angle` degrees (0 = the length points up). For gear teeth.
local function slab(pen: Pen, x: number, y: number, length: number, width: number, angle: number)
	Theme.make("Frame", {
		Name = "Part",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at(pen, x), at(pen, y)),
		Size = UDim2.fromOffset(at(pen, width), at(pen, length)),
		Rotation = angle,
		BorderSizePixel = 0,
		BackgroundColor3 = WHITE,
		Parent = pen.holder,
	})
end

-- A frame where only rows y1 to y2 of the icon show (for an arc). Shapes
-- drawn in it keep the icon's own grid positions.
local function clip(pen: Pen, y1: number, y2: number): Frame
	local window = Theme.make("Frame", {
		Name = "Clip",
		Position = UDim2.fromOffset(0, at(pen, y1)),
		Size = UDim2.fromOffset(at(pen, GRID), at(pen, y2 - y1)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = pen.holder,
	})
	return Theme.make("Frame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, -at(pen, y1)),
		Size = UDim2.fromOffset(at(pen, GRID), at(pen, GRID)),
		BackgroundTransparency = 1,
		Parent = window,
	}) :: Frame
end

function Icons.draw(name: IconName, parent: Instance, size: number): Frame
	local holder = Theme.make("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	local pen: Pen = {
		holder = holder,
		unit = size / GRID,
		stroke = math.max(1, math.floor(STROKE * size / GRID + 0.5)),
	}
	if name == "kits" then
		-- A fighter: head, and shoulders closed by a base line.
		ring(pen, 11, 7, 8)
		ring(pen, 11, 20, 14, clip(pen, 12, 20))
		line(pen, 4, 19, 18, 19)
	elseif name == "duel" then
		-- Two crossed swords, hilts in the bottom corners: blade, a guard
		-- square to the blade, and a short grip.
		line(pen, 18, 3, 6, 16)
		line(pen, 8.2, 18.03, 3.8, 13.97)
		line(pen, 6, 16, 3.5, 19)
		line(pen, 4, 3, 16, 16)
		line(pen, 18.2, 13.97, 13.8, 18.03)
		line(pen, 16, 16, 18.5, 19)
	elseif name == "rewards" then
		-- A gift: lid, box, ribbon and a two-loop bow.
		box(pen, 3, 8, 19, 12, 1.5)
		box(pen, 4.5, 12, 17.5, 20, 1.5)
		line(pen, 11, 8, 11, 20)
		ring(pen, 8, 5, 6)
		ring(pen, 14, 5, 6)
	elseif name == "emotes" then
		-- A smiley face, like Roblox's emote button: eyes and a smile.
		ring(pen, 11, 11, 18)
		dot(pen, 8, 9, 2.5)
		dot(pen, 14, 9, 2.5)
		ring(pen, 11, 10.5, 10, clip(pen, 13.5, 17))
	elseif name == "shop" then
		-- A hat: a tapered crown with a band, on a wide brim.
		line(pen, 7, 16, 8, 5)
		line(pen, 8, 5, 14, 5)
		line(pen, 14, 5, 15, 16)
		line(pen, 7.4, 12, 14.6, 12)
		line(pen, 2.5, 16, 19.5, 16)
	elseif name == "profile" then
		-- A chart: three bars on a base line.
		line(pen, 6, 11, 6, 16)
		line(pen, 11, 5, 11, 16)
		line(pen, 16, 8, 16, 16)
		line(pen, 3, 19.5, 19, 19.5)
	elseif name == "settings" then
		-- A gear: a ring with eight solid teeth on it, and an open hub.
		ring(pen, 11, 11, 12)
		ring(pen, 11, 11, 6)
		for index = 0, 7 do
			local angle = math.rad(index * 45)
			slab(pen, 11 + math.sin(angle) * 7.5, 11 - math.cos(angle) * 7.5, 4, 3.5, index * 45)
		end
	elseif name == "effect" then
		-- A burst: eight rays around a dot, the long ones on the axes.
		for index = 0, 7 do
			local angle = math.rad(index * 45)
			local reach = if index % 2 == 0 then 9.5 else 7
			local sin, cos = math.sin(angle), math.cos(angle)
			line(pen, 11 + sin * 4.5, 11 - cos * 4.5, 11 + sin * reach, 11 - cos * reach)
		end
		dot(pen, 11, 11, 4)
	elseif name == "title" then
		-- A name tag: a plate with two lines.
		box(pen, 2, 5, 20, 17, 2.5)
		line(pen, 6, 9.5, 16, 9.5)
		line(pen, 6, 12.5, 12, 12.5)
	end
	return holder
end

-- Recolours every part of an icon.
function Icons.paint(icon: Frame, color: Color3)
	for _, child in icon:GetDescendants() do
		if child:IsA("Frame") and child.Name == "Part" then
			child.BackgroundColor3 = color
		elseif child:IsA("UIStroke") then
			child.Color = color
		end
	end
end

return table.freeze(Icons)
