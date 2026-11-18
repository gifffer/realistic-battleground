--!strict
-- CityGlass: turns the city's window panes into real-looking glass, for everyone.
--
-- The city is built by code (Systems/City, generated data we don't edit), so this runs once
-- the City folder says Built = true and changes the panes it finds, by name:
--   CLEAR (see-through, a dark room or a shop behind): ShopGlass, DoorGlass, Transom,
--     PhoneGlass, Skylight. → Material Glass, a very light green-grey, Transparency
--     CLEAR_TRANSPARENCY, Reflectance CLEAR_REFLECTANCE, no shadow (light goes through,
--     like the pale shadow of the pane in the glass video).
--   DARK (a brick wall is right behind them, so they can't be see-through): Window,
--     Glass (the ones on panels), GlassStrip, LobbyGlass, BoothGlass, Fanlight.
--     → Material Glass, opaque, mirror-like (DARK_REFLECTANCE), each pane's tint a little
--     different (old glass is never twice the same).
-- Boarded windows (Wood), bottles (already Glass), car glass and the far backdrop bands are
-- left alone. No part is added (the city is near its part budget).
--
-- Every pane gets the tag "CityGlass" and the attribute GlassKind ("Clear" / "Dark"):
-- Client/Controllers/GlassController adds the dirt, the rain running down the glass and the
-- low-quality fallback from that.
--
-- Lit windows (tag CityWindowLit): Server/Systems/Ambience turns them into a glowing pane at
-- night and puts back the "Built*" attributes when they go dark, so we write the glass look
-- into those attributes too (and only touch the part itself while it is dark).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local G = Config.Glass

local CityGlass = {}

local TAG = "CityGlass"

-- Name → kind. `plainOnly`: only panes still made of SmoothPlastic (not boarded / bottles).
local KINDS: { [string]: { kind: string, plainOnly: boolean } } = {
	ShopGlass = { kind = "Clear", plainOnly = false },
	DoorGlass = { kind = "Clear", plainOnly = false },
	PhoneGlass = { kind = "Clear", plainOnly = false },
	Window = { kind = "Dark", plainOnly = true },
	Glass = { kind = "Dark", plainOnly = true },
	GlassStrip = { kind = "Dark", plainOnly = true },
	LobbyGlass = { kind = "Dark", plainOnly = true },
	BoothGlass = { kind = "Dark", plainOnly = true },
	Fanlight = { kind = "Dark", plainOnly = true },
}
-- These names are also used by stone parts: only the ones already made of Glass count.
local GLASS_ONLY: { [string]: boolean } = { Transom = true, Skylight = true }

local function kindOf(part: BasePart): string?
	if GLASS_ONLY[part.Name] then
		return if part.Material == Enum.Material.Glass then "Clear" else nil
	end
	local entry = KINDS[part.Name]
	if entry == nil then
		return nil
	end
	if entry.plainOnly and part.Material ~= Enum.Material.SmoothPlastic then
		return nil
	end
	return entry.kind
end

-- A number 0..1 that depends only on where the pane is (same on every server).
local function hash(position: Vector3, salt: number): number
	local n = math.sin(position.X * 12.9898 + position.Y * 78.233 + position.Z * 37.719 + salt)
		* 43758.5453
	return n - math.floor(n)
end

-- Old window glass: a little darker or lighter, a little greener or bluer.
local function darkTint(part: BasePart): Color3
	local base = part.Color
	local spread = G.DARK_TINT_SPREAD
	local light = 1 + (hash(part.Position, 1) - 0.5) * 2 * spread
	local green = (hash(part.Position, 2) - 0.5) * spread
	return Color3.new(
		math.clamp(base.R * light * (1 - green * 0.5), 0, 1),
		math.clamp(base.G * light * (1 + green * 0.6), 0, 1),
		math.clamp(base.B * light * (1 + green * 0.2), 0, 1)
	)
end

local function apply(part: BasePart, kind: string)
	local color, transparency, reflectance
	if kind == "Clear" then
		color, transparency, reflectance = G.CLEAR_COLOR, G.CLEAR_TRANSPARENCY, G.CLEAR_REFLECTANCE
	else
		color, transparency, reflectance = darkTint(part), 0, G.DARK_REFLECTANCE
	end
	part:SetAttribute("GlassKind", kind)
	if part:HasTag("CityWindowLit") then
		-- Ambience puts these back when the window goes dark.
		part:SetAttribute("BuiltColor", color)
		part:SetAttribute("BuiltMaterial", Enum.Material.Glass.Name)
		part:SetAttribute("BuiltReflectance", reflectance)
		part:SetAttribute("BuiltTransparency", transparency)
		local level = part:GetAttribute("LitLevel")
		if level ~= nil and level ~= "off" then
			CollectionService:AddTag(part, TAG)
			return -- glowing right now: it gets the glass look when it goes dark
		end
	end
	part.Material = Enum.Material.Glass
	part.Color = color
	part.Transparency = transparency
	part.Reflectance = reflectance
	part.CastShadow = false
	CollectionService:AddTag(part, TAG)
end

local function dress(city: Instance)
	local count = 0
	for index, descendant in city:GetDescendants() do
		if descendant:IsA("BasePart") then
			local kind = kindOf(descendant)
			if kind then
				apply(descendant, kind)
				count += 1
			end
		end
		if index % 2000 == 0 then
			task.wait()
		end
	end
	city:SetAttribute("GlassPanes", count)
end

function CityGlass.start()
	local city = workspace:WaitForChild("City", 60)
	if city == nil then
		return
	end
	if city:GetAttribute("Built") == false then
		city:GetAttributeChangedSignal("Built"):Wait()
	end
	dress(city)
end

return CityGlass
