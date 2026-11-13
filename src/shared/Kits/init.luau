--!strict
-- Kits: the fighting styles a player can equip (Street Brawler, Boxer,
-- Bouncer...).
--
-- A kit = 4 moves on keys 1–4 + an Awakening (key G, when its gauge is
-- full) that swaps the 4 moves for stronger versions for a few seconds.
-- Each kit is described as DATA in its own file (Shared/Kits/<Kit>.luau):
-- names, numbers, timings, effects. The server (Server/Systems/Kits) runs
-- the moves from these descriptions and decides every hit; the client
-- only shows them (animations, props, sounds, the move bar).
--
-- Shared by client and server so both read the same numbers. Nothing here
-- is secret: a client changing its copy changes nothing on the server.
--
--   Kits.get("StreetBrawler")  → KitDef (or nil)
--   Kits.list()                → every kit, in display order
--   Kits.DEFAULT               → the kit everybody starts with

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local KitTypes = require(script.KitTypes)

export type HitDef = KitTypes.HitDef
export type MoveDef = KitTypes.MoveDef
export type AwakeningDef = KitTypes.AwakeningDef
export type KitDef = KitTypes.KitDef
export type FinisherDef = KitTypes.FinisherDef
export type GrabDef = KitTypes.GrabDef
export type BurnDef = KitTypes.BurnDef
export type GadgetDef = KitTypes.GadgetDef
export type FlaskDef = KitTypes.FlaskDef
export type RayDef = KitTypes.RayDef
export type PortalDef = KitTypes.PortalDef
export type WaveDef = KitTypes.WaveDef
export type SwarmDef = KitTypes.SwarmDef
export type ClonesDef = KitTypes.ClonesDef

local Kits = {}

Kits.DEFAULT = "StreetBrawler"

local registry: { [string]: KitDef } = {}
local ordered: { KitDef } = {}

local function add(kit: KitDef)
	registry[kit.id] = kit
	table.insert(ordered, kit)
	table.sort(ordered, function(a, b)
		return a.order < b.order
	end)
end

add(require(script.StreetBrawler))
add(require(script.Boxer))
add(require(script.Bouncer))
add(require(script.Rift))

function Kits.get(id: string?): KitDef?
	return if id then registry[id] else nil
end

function Kits.list(): { KitDef }
	return ordered
end

-- Does this save own `kit`? Free kits (no price, no level) belong to
-- everyone; the others once bought (data.ownedKits).
function Kits.owns(data: { ownedKits: { [string]: boolean } }, kit: KitDef): boolean
	if kit.price == nil and kit.unlockLevel == nil then
		return true
	end
	-- (testing in Studio: everything, Config.Dev)
	if Config.Dev.UNLOCK_KITS_IN_STUDIO and RunService:IsStudio() then
		return true
	end
	return data.ownedKits[kit.id] == true
end

-- How a fighter with kit `id` finishes a knocked-out opponent: the kit's
-- own finisher, or the default one (kneel and strike, Config.Knockout).
local DEFAULT_FINISHER: FinisherDef = table.freeze({
	animation = "Finisher",
	impact = Config.Knockout.FINISH_IMPACT,
	duration = Config.Knockout.FINISH_DURATION,
})

function Kits.finisher(id: string?): FinisherDef
	local kit = Kits.get(id)
	return (if kit then kit.finisher else nil) or DEFAULT_FINISHER
end

-- The move in `slot` (1–4) of `kit`, the Awakening version if `awakened`.
function Kits.move(kit: KitDef, slot: number, awakened: boolean): MoveDef?
	local awakening = kit.awakening
	if awakened and awakening then
		return awakening.moves[slot]
	end
	return kit.moves[slot]
end

return table.freeze(Kits)
