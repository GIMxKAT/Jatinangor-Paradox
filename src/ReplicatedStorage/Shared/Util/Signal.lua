--!strict
-- Minimal Signal implementation (BindableEvent-free, pure Lua) for
-- decoupled communication between Services without polling on Heartbeat.

local Signal = {}
Signal.__index = Signal

export type Connection = {
    Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = typeof(setmetatable(
    {} :: {
        _handlers: { (T...) -> () },
    },
    Signal
))

function Signal.new<T...>(): Signal<T...>
    local self = setmetatable({
        _handlers = {},
    }, Signal)
    return (self :: any) :: Signal<T...>
end

function Signal.Connect<T...>(self: Signal<T...>, handler: (T...) -> ()): Connection
    table.insert(self._handlers, handler)
    local connection = {}
    function connection.Disconnect(_self)
        local index = table.find(self._handlers, handler)
        if index then
            table.remove(self._handlers, index)
        end
    end
    return connection :: Connection
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
    for _, handler in self._handlers do
        task.spawn(handler, ...)
    end
end

return Signal
