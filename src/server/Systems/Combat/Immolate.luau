--!strict
-- Immolate: the Pyromaniac's finisher on the server (Shared/Finishers
-- "Immolate"). Only attributes on the victim; every client draws them
-- (Client/Combat/PyroFx), a body seen later too:
--   • "Douse": soaked in petrol (PyroConfig.DOUSED_ATTRIBUTE);
--   • "Ignite": alight ("Burning" = "Fire": flames all over, Client RiftBurn);
--   • the kill: PyroConfig.IMMOLATED_ATTRIBUTE = the server time it caught
--     fire; the corpse burns on, then smoulders. "Burning" goes after
--     PyroConfig.IMMOLATE_BURN seconds (the flames die down, the char stays).
-- Cut short before the kill, Combat puts every attribute back (woundsBefore).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Finishers = require(ReplicatedStorage.Shared.Finishers)
local PyroConfig = require(ReplicatedStorage.Shared.PyroConfig)

local Immolate = {}

-- (remembers the old value once, as Combat's other finisher wounds do)
local function set(target: Model, name: string, value: any, before: { [string]: any })
	if before[name] == nil then
		local old = target:GetAttribute(name)
		before[name] = if old == nil then false else old
	end
	target:SetAttribute(name, value)
end

-- At the timeline's beats. `going()` = the cinematic still plays (not cut
-- short, the attacker still alive). `onIgnite()`: Combat clears the
-- victim's own burn slot (its end must not put this fire out).
function Immolate.run(
	cinematic: Finishers.Cinematic,
	target: Model,
	before: { [string]: any },
	going: () -> boolean,
	onIgnite: () -> ()
)
	for _, event in cinematic.events do
		if event.kind == "Douse" then
			task.delay(event.time, function()
				if going() and target.Parent then
					set(
						target,
						PyroConfig.DOUSED_ATTRIBUTE,
						workspace:GetServerTimeNow() + 30,
						before
					)
				end
			end)
		elseif event.kind == "Ignite" then
			task.delay(event.time, function()
				if going() and target.Parent then
					onIgnite()
					-- (its own burn slot is cleared: cut short, the flames go out too)
					before["Burning"] = false
					set(target, "Burning", "Fire", before)
				end
			end)
		end
	end
end

-- The kill landed and the body is dead: it burns on.
function Immolate.killed(target: Model)
	local caught = workspace:GetServerTimeNow()
	target:SetAttribute(PyroConfig.IMMOLATED_ATTRIBUTE, caught)
	target:SetAttribute("Burning", "Fire")
	task.delay(PyroConfig.IMMOLATE_BURN, function()
		if target.Parent and target:GetAttribute(PyroConfig.IMMOLATED_ATTRIBUTE) == caught then
			target:SetAttribute("Burning", nil)
		end
	end)
end

return table.freeze(Immolate)
