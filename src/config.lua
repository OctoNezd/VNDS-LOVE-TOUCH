local LIP = require "lib.LIP"

local config = {
    audio = {
        music = 100,
        sound = 100
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

function load_config()
    local new_config = LIP.load("config.ini")
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
    LIP.save('config.ini', config)
end)
