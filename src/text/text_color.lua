local pprint = require "lib.pprint"

local function rgb(r, g, b)
    return {r / 256, g / 256, b / 256, 1}
end

local reset = rgb(236, 239, 244)

local color_map = {
    ["x1b[;1m"] = reset,
    ["x1b[0m"] = reset,
    ["x1b[30;1m"] = rgb(59, 66, 82),
    ["x1b[31;1m"] = rgb(191, 97, 106),
    ["x1b[32;1m"] = rgb(163, 190, 140),
    ["x1b[33;1m"] = rgb(235, 203, 139),
    ["x1b[34;1m"] = rgb(129, 162, 193),
    ["x1b[35;1m"] = rgb(180, 142, 173),
    ["x1b[36;1m"] = rgb(143, 188, 187),
    ["x1b[37;1m"] = rgb(236, 239, 244)
}

local function colorify(str, i, last_color, result)
    i = i or 1
    last_color = last_color or reset
    result = result or {}
    local s, e = str:find("\\*x1b%[%d*;*%dm", i)
    if s == nil then
        table.insert(result, last_color)
        table.insert(result, str:sub(i, -1))
        return result
    end
    local offset = 0
    if str:sub(s, s) == "\\" then -- remove the backslash
        offset = 1
    end
    local color = color_map[str:sub(s + offset, e)]
    if i ~= s then
        table.insert(result, last_color)
        table.insert(result, str:sub(i, s - 1))
    end
    colorify(str, e + 1, color, result)
    return result
end

local function strip_colors(str, i, stripped_string)
    i = i or 1
    stripped_string = stripped_string or ''
    local s, e = str:find("\\*x1b%[%d*;*%dm", i)
    if s == nil then
        return str
    end
    local offset = 0
    if str:sub(s, s) == "\\" then -- remove the backslash
        offset = 1
    end
    if i ~= s then
        stripped_string = stripped_string .. str:sub(i, s - 1)
    end
    colorify(str, e + 1, stripped_string)
    return stripped_string
end

return {
    colorify = colorify,
    strip_colors = strip_colors
}
