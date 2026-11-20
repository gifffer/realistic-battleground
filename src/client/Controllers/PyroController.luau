--!strict
-- PyroController: starts the Pyromaniac's fire looks (Client/Combat/PyroFx):
-- the Molotovs and fire pools from the server, soaked / burning bodies, his
-- finisher. Its own controller so the shared combat controllers stay as
-- they are.

local PyroFx = require(script.Parent.Parent.Combat.PyroFx)

local PyroController = {}

function PyroController.start()
	PyroFx.start()
end

return PyroController
