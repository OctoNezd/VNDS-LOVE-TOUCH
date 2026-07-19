on("load", function()
    love.filesystem.remove('log.txt')
end)

on("event", function(name, ...)
    if name == "load" then return end
    local log = os.date('%H:%M:%S') .. " " .. name .. " " .. pprint.pformat({...}) .. "\n"
    love.filesystem.append('log.txt', log)
end)

local should_debug = on("draw_debug", function()
    love.graphics.print(love.graphics.getWidth(), 1, 1)
    love.graphics.print(love.graphics.getHeight(), 1, 20)
    love.graphics.print(sx, 1, 40)
    love.graphics.print(sy, 1, 60)
end)

should_debug:remove()
