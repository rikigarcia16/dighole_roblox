--!strict
-- Minimal synchronous signal.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (Connection) -> () }

function Signal.new()
	return setmetatable({ handlers = {} :: { any } }, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	table.insert(self.handlers, handler)
	local handlers = self.handlers
	return {
		Disconnect = function()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	} :: any
end

function Signal:Fire(...: any)
	for _, handler in table.clone(self.handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
