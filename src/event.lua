local Event = require 'lib.event'

local function dispatch(name, ...)
    Event.dispatch("event", name, ...)
    Event.dispatch(name, ...)
end

local dispatch_often = Event.dispatch -- ignored in logs

local function remove(self)
    for _, e in ipairs(self) do
        Event.dispatch("event", "remove_handler", e.name)
        e:remove()
    end
end

local function register(self)
    for _, e in ipairs(self) do
        Event.dispatch("event", "register_handler", e.name)
        e:register()
    end
end

return {dispatch = dispatch, dispatch_often = dispatch_often, on = Event.on, hook = Event.hook, remove = remove, register = register}
