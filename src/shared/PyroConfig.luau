--!strict
-- The Pyromaniac's numbers that are not one move's (Shared/Kits/Pyromaniac):
-- fuel on a body, the fire pools' budget, the finisher's burning body.
-- Read by the server (Combat, Gadgets) and by the clients (PyroFx).

local PyroConfig = {}

-- Soaked in fuel (his DOUSE, a Molotov breaking on someone): the server
-- time it dries off, on the fighter. Meanwhile any FIRE burn on them is
-- stronger and lasts longer, and a fire pool reaches them from further.
PyroConfig.DOUSED_ATTRIBUTE = "DousedUntil"
PyroConfig.DOUSED_RATE = 1.5 -- fire damage per second × this
PyroConfig.DOUSED_EXTRA = 2 -- seconds added to a fire burn
PyroConfig.DOUSED_REACH = 1.5 -- studs: a pool's cells catch them from this much further

-- Fire pools (Molotov): at most this many burning cells in the whole server
-- at once (a new pool gets fewer when many are already burning), and this
-- many pools (the oldest goes out early).
PyroConfig.MAX_CELLS = 48
PyroConfig.MAX_POOLS = 4
-- How long the pool takes to spread from the burst to its edge (seconds).
PyroConfig.SPREAD_TIME = 0.6
-- A cell's own size (studs, radius): standing within it = in the fire.
PyroConfig.CELL_RADIUS = 1.5
-- Feet within this height of the pool's floor (no burning while jumping over).
PyroConfig.FLAME_HEIGHT = 4.5
-- How often the server checks who stands in the fire (seconds).
PyroConfig.POOL_TICK = 0.25
-- The black mark it leaves, after the fire is out (seconds, client).
PyroConfig.SCORCH_TIME = 45

-- The finisher (Shared/Finishers "Immolate"): the body burns on after the
-- kill for this long (seconds), then smoulders. On the dead body: the
-- server time it caught fire (the clients draw it, a body seen later too).
PyroConfig.IMMOLATED_ATTRIBUTE = "Immolated"
PyroConfig.IMMOLATE_BURN = 12
PyroConfig.IMMOLATE_SMOULDER = 25

-- His Awakening: his forearms are on fire (the clients draw them).
PyroConfig.KIT_ID = "Pyromaniac"

return table.freeze(PyroConfig)
