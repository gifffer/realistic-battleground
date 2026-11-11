--!strict
-- Minimal event object for module-to-module communication on ONE side
-- (server code talking to server code, or client to client).
-- For client <-> server, use Remotes instead.
--
--   local changed = Signal.new() :: Signal.Signal<number>
--   local connection = changed.connect(function(value) print(value) end)
--   changed.fire(42)
--   connection.disconnect()

export type Connection = {
	disconnect: () -> (),
}

export type Signal<T> = {
	connect: (listener: (T) -> ()) -> Connection,
	fire: (value: T) -> (),
	disconnectAll: () -> (),
}

local Signal = {}

function Signal.new<T>(): Signal<T>
	local listeners: { (T) -> () } = {}

	local function connect(listener: (T) -> ()): Connection
		table.insert(listeners, listener)
		local connected = true
		return {
			disconnect = function()
				if not connected then
					return
				end
				connected = false
				local index = table.find(listeners, listener)
				if index then
					table.remove(listeners, index)
				end
			end,
		}
	end

	local function fire(value: T)
		-- Clone: a listener may disconnect itself while we loop.
		-- task.spawn: one listener erroring or yielding never blocks the others.
		for _, listener in table.clone(listeners) do
			task.spawn(listener, value)
		end
	end

	local function disconnectAll()
		table.clear(listeners)
	end

	return {
		connect = connect,
		fire = fire,
		disconnectAll = disconnectAll,
	}
end

return table.freeze(Signal)
