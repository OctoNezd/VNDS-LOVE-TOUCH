local keyboard_map = {
    ["down"] = "down",
    ["j"] = "down",
    ["k"] = "up",
    ["h"] = "left",
    ["l"] = "right",
    ["up"] = "up",
    ["left"] = "left",
    ["right"] = "right",
    ["space"] = "a",
    ["return"] = "a",
    ["x"] = "x",
    ["y"] = "y",
    ["m"] = "start",
    ["b"] = "b"
}
on("keyboard_input", function(key)
    if key == "c" then
        dispatch("start_cfgui")
    end
    if key == "d" then
        ui_debug = not ui_debug
        dispatch("luis_debug")
    end
    if keyboard_map[key] then
        return dispatch("input", keyboard_map[key])
    end
end)
local gamepad_map = {
    ["dpdown"] = "down",
    ["dpup"] = "up",
    ["dpleft"] = "left",
    ["dpright"] = "right",
    ["a"] = "a",
    ["b"] = "b",
    ["y"] = "y",
    ["x"] = "x",
    ["start"] = "start"
}
on("gamepad_input", function(self)
    if gamepad_map[self] then
        return dispatch("input", gamepad_map[self])
    end
end)
