local json = require("lib.json")
local config_filename = "conf.json"
local baseLineConfig = {
    audio = {
        music = 1,
        sound = 1
    },
    font = {
        override_font = false,
        custom_font = false
    },
    background = {
        red = 0,
        green = 0,
        blue = 0,
        alpha = .4
    },
    padding = {
        width = 0,
        height = 0,
        width_inner = 0,
        height_inner = 0,
        line_pad = 0
    }
}
local config = deepcopy(baseLineConfig)

function load_config()
    local confjson = love.filesystem.openFile(config_filename, 'r')
    local new_config = {}
    if confjson ~= nil then
        new_config = json.decode(confjson:read())
    end
    for key, value in pairs(new_config) do -- override defaults with config
        _.extend(config[key], new_config[key])
    end
    return config
end

on("load", function()
    dispatch("config", load_config())
end)

on("save_config", function(new_config)
    config = new_config
    local confjson = love.filesystem.openFile(config_filename, 'w')
    confjson:write(json.encode(new_config))
end)

on("reset_config", function()
    config = deepcopy(baseLineConfig)
    dispatch("config", config)
    dispatch("save_config", config)
end)
