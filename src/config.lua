local LIP = require "lib.LIP"

local config = {
    audio = {music = 100, sound = 100},
    font = {override_font = false, custom_font = false},
    background = {red = 0, green = 0, blue = 0, alpha = .4}
}

local function range(copy, section, key, text)
    return {
        text = text(copy),
        action = function() end,
        right = function(self)
            copy[section][key] = math.min(copy[section][key] + 10, 100)
            self.text = text(copy)
            dispatch("config", copy)
        end,
        left = function(self)
            copy[section][key] = math.max(copy[section][key] - 10, 0)
            self.text = text(copy)
            dispatch("config", copy)
        end,
    }
end

local function toggle(copy, section, key, true_text, false_text)
    local function text()
        if copy[section][key] then return true_text else return false_text end
    end
    return {
        text = text(),
        action = function(self)
            copy[section][key] = not copy[section][key]
            self.text = text()
            dispatch("config", copy)
        end,
    }
end

on("config_menu", function()
    local copy = deepcopy(config)
    create_listbox({
        choices = {
            range(copy, "audio", "music", function(c) return "Music Volume " .. c.audio.music .. "%" end),
            range(copy, "audio", "sound", function(c) return "Sound Volume " .. c.audio.sound .. "%" end),
            toggle(copy, "font", "override_font", "Using System Font", "Using Novel Font"),
            {
                text = "Save Settings",
                action = function(choice, close)
                    close()
                    dispatch("save_config", copy)
                end,
            },
        },
        closable = true,
        onclose = function() dispatch("config", config) end,
    })
end)

on("load", function()
    local new_config = LIP.load("config.ini")
    for key, value in pairs(new_config) do -- override defaults with config
        _.extend(config[key], new_config[key])
    end
    dispatch("config", config)
end)

on("save_config", function(new_config)
    config = new_config
    LIP.save('config.ini', config)
end)
