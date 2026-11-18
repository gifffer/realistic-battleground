--!strict
-- Icons: the top bar's and the cards' icons, drawn with frames (no image
-- assets to upload). Every part is placed in scale (0-1) inside its holder,
-- so one icon reads at any size.
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

-- A filled part: centre (x, y), size (w, h), all in scale; `round` 0-1.
local function part(
	holder: Frame,
	x: number,
	y: number,
	w: number,
	h: number,
	rotation: number?,
	round: number?
): Frame
	local frame = Theme.make("Frame", {
		Name = "Part",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		Rotation = rotation or 0,
		BackgroundColor3 = WHITE,
		Parent = holder,
	}) :: Frame
	if round and round > 0 then
		Theme.make("UICorner", { CornerRadius = UDim.new(round, 0), Parent = frame })
	end
	return frame
end

-- An outlined circle: centre (x, y), diameter `d` (scale), line `thick` (scale).
local function ring(holder: Frame, x: number, y: number, d: number, thick: number, size: number)
	Theme.make("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(d, d),
		BackgroundTransparency = 1,
		Parent = holder,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Theme.make("UIStroke", {
			Thickness = math.max(1, thick * size),
			Color = WHITE,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

function Icons.draw(name: IconName, parent: Instance, size: number): Frame
	local holder = Theme.make("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	if name == "kits" then
		-- A fighter: head and shoulders.
		part(holder, 0.5, 0.27, 0.38, 0.38, 0, 1)
		part(holder, 0.5, 0.8, 0.78, 0.42, 0, 0.45)
	elseif name == "duel" then
		-- Two crossed blades with their guards.
		part(holder, 0.5, 0.5, 0.12, 1.02, 45, 0)
		part(holder, 0.5, 0.5, 0.12, 1.02, -45, 0)
		part(holder, 0.27, 0.73, 0.36, 0.11, 45, 0)
		part(holder, 0.73, 0.73, 0.36, 0.11, -45, 0)
	elseif name == "rewards" then
		-- A gift: two halves of the box and of the lid (the gap is the ribbon), a bow.
		part(holder, 0.3, 0.7, 0.34, 0.46, 0, 0)
		part(holder, 0.7, 0.7, 0.34, 0.46, 0, 0)
		part(holder, 0.27, 0.38, 0.4, 0.16, 0, 0)
		part(holder, 0.73, 0.38, 0.4, 0.16, 0, 0)
		part(holder, 0.38, 0.18, 0.22, 0.22, 45, 0.3)
		part(holder, 0.62, 0.18, 0.22, 0.22, 45, 0.3)
	elseif name == "emotes" then
		-- A figure cheering: arms up, legs apart.
		part(holder, 0.5, 0.14, 0.24, 0.24, 0, 1)
		part(holder, 0.5, 0.47, 0.16, 0.36, 0, 0.3)
		part(holder, 0.3, 0.32, 0.12, 0.38, -35, 1)
		part(holder, 0.7, 0.32, 0.12, 0.38, 35, 1)
		part(holder, 0.38, 0.8, 0.13, 0.4, 18, 1)
		part(holder, 0.62, 0.8, 0.13, 0.4, -18, 1)
	elseif name == "shop" then
		-- A hat: crown and brim.
		part(holder, 0.5, 0.45, 0.56, 0.44, 0, 0.35)
		part(holder, 0.5, 0.7, 1, 0.14, 0, 1)
		part(holder, 0.5, 0.59, 0.56, 0.06, 0, 0)
	elseif name == "profile" then
		-- A chart: three bars on a line.
		part(holder, 0.22, 0.66, 0.2, 0.44, 0, 0)
		part(holder, 0.5, 0.5, 0.2, 0.76, 0, 0)
		part(holder, 0.78, 0.58, 0.2, 0.6, 0, 0)
		part(holder, 0.5, 0.95, 1, 0.08, 0, 0)
	elseif name == "settings" then
		-- A gear: a ring with eight teeth.
		for index = 0, 7 do
			local angle = math.rad(index * 45)
			part(
				holder,
				0.5 + math.sin(angle) * 0.38,
				0.5 - math.cos(angle) * 0.38,
				0.2,
				0.2,
				index * 45,
				0.2
			)
		end
		ring(holder, 0.5, 0.5, 0.62, 0.16, size)
	elseif name == "effect" then
		-- A burst: four crossed rays and a core.
		for index = 0, 3 do
			part(holder, 0.5, 0.5, 0.09, if index % 2 == 0 then 1 else 0.7, index * 45, 1)
		end
		part(holder, 0.5, 0.5, 0.34, 0.34, 0, 1)
	elseif name == "title" then
		-- A name tag: a plate with two lines.
		part(holder, 0.5, 0.36, 0.9, 0.12, 0, 0)
		part(holder, 0.42, 0.6, 0.74, 0.12, 0, 0)
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
