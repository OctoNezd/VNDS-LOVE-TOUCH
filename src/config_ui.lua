configui_active = false
-- Initialize LUIS
local initLuis = require("luis.init")

-- Direct this to your widgets folder.
local luis = initLuis("luis/widgets")

-- register flux in luis, some widgets need it for animations
luis.flux = require("luis.3rdparty.flux")
luis.theme.text.font = love.graphics.newFont("luis/themes/fonts/Roboto-Regular.ttf", 46)

luis.newLayer("main")
luis.setCurrentLayer("main")

local gridWidth = math.floor(luis.baseWidth / luis.gridSize)
local gridHeight = math.floor(luis.baseHeight / luis.gridSize)
print("GW", gridWidth, "GH", gridHeight)
local cpicker_y = 12
local center = math.floor(gridWidth / 2)
local picker_width = math.floor(gridWidth / 2)
local cpicker_pos = center - picker_width / 2 - 180 / gridWidth

local title_theme = {
    font = love.graphics.newFont("Roboto-Italic.ttf", 46),
    color = {1, 1, 1}
}
local title = luis.newLabel("Settings", 18, 6, 1, cpicker_pos - 6, "left", title_theme)

luis.createElement(luis.currentLayer, "Label", title)

local function nop()
end
local cpicker = luis.newColorPicker(picker_width, 15, cpicker_y, cpicker_pos, nop)
local cpicker_label = luis.newLabel("Background color", 18, 1, 9, cpicker_pos)

local calpha = luis.newSlider(0, 1, .8, picker_width + 9, 1, nop, 32, cpicker_pos)
local calpha_label = luis.newLabel("Background opacity", 32, 1, 30, cpicker_pos)

luis.createElement(luis.currentLayer, "ColorPicker", cpicker)
luis.createElement(luis.currentLayer, "Label", cpicker_label)
luis.createElement(luis.currentLayer, "Slider", calpha)
luis.createElement(luis.currentLayer, "Label", calpha_label)

local button_width = gridWidth / 4
local apply = luis.newButton("Apply", button_width, 4, function()
    configui_active = false
    local red, green, blue = unpack(cpicker.color)
    local new_config = {
        audio = {
            music = 100,
            sound = 100
        },
        font = {
            override_font = false
        },
        background = {
            red = red,
            green = green,
            blue = blue,
            alpha = calpha.value
        }
    }
    dispatch("config", new_config)
    dispatch("save_config", new_config)
end, function()
end, gridHeight - 5, gridWidth / 4 - button_width / 2)
luis.createElement(luis.currentLayer, "Button", apply)

local cancel = luis.newButton("Cancel", button_width, 4, function()
end, function()
    configui_active = false
end, gridHeight - 5, gridWidth - gridWidth / 4 - button_width / 2)
luis.createElement(luis.currentLayer, "Button", cancel)

local function refresh_dialog_preview()
    local x = love.graphics.getWidth() / 2 - preview_width / 2
    local y = apply.position.y * luis.scale - preview_height - 32
    love.graphics.draw(background_sample, background_sample_quad, x, y)
    local red, green, blue = unpack(cpicker.color)
    local alpha = calpha.value
    love.graphics.setColor(red, green, blue, alpha)
    love.graphics.rectangle("fill", x + pad, y + pad, preview_width - pad * 2, preview_height - pad * 2)
    local w, h = love.graphics.getWidth() - 2 * pad, pad + (love.text_font:getHeight() + pad)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.text_font)
    love.graphics.print("Yes, it’s puzzling.", x + pad * 2, y + pad * 2)
end

on("load", function()
    background_sample = love.graphics.newImage("dialog_preview.png")
end)
on("config", function(config)
    cpicker.color = {config.background.red, config.background.green, config.background.blue, config.background.alpha}
    calpha.value = config.background.alpha
end)
on("start_cfgui", function()
    configui_active = true
end)
on("draw_configui", function()
    luis.draw()
    refresh_dialog_preview()
end)
on("configui_mr", function(x, y, button, istouch)
    luis.mousereleased(x, y, button, istouch)
end)
on("configui_mp", function(x, y, button, istouch)
    luis.mousepressed(x, y, button, istouch)
end)

local time = 0
on("update", function(dt)
    preview_width = love.graphics.getWidth() * 0.8
    preview_height = love.graphics.getHeight() * 0.2
    local background_sample_pos = background_sample:getWidth() / 2 - preview_width / 2
    background_sample_quad = love.graphics.newQuad(background_sample_pos, 100, preview_width, preview_height,
        background_sample)
    luis.updateScale()
    if not configui_active then
        return
    end
    time = time + dt
    if time >= 1 / 60 then
        luis.flux.update(time)
        time = 0
    end

    luis.update(dt)
end)
