-- ============================================================================
-- Configuration UI Module
-- Provides a visual settings interface using the LUIS UI library
-- ============================================================================
-- Global state flag
configui_active = false

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local FONT_SIZE_LARGE = 46
local FONT_SIZE_SMALL = 18

local TITLE_FONT_PATH = "Roboto-Italic.ttf"
local LUIS_FONT_PATH = "luis/themes/fonts/Roboto-Regular.ttf"

-- Layout constants
local COLORPICKER_Y_POSITION = 12
local COLORPICKER_HEIGHT = 15
local COLORPICKER_LABEL_Y_OFFSET = 9

local ALPHA_SLIDER_Y_OFFSET = 9
local ALPHA_LABEL_Y_OFFSET = 30

local BUTTON_HEIGHT = 4
local BUTTON_MARGIN_BOTTOM = 5

local LYR_BG = "background"
local LYR_SOUNDS = "sounds"

-- Preview window constants
local PREVIEW_WIDTH_RATIO = 0.8
local PREVIEW_HEIGHT_RATIO = 0.2
local PREVIEW_VERTICAL_OFFSET = 32
local PREVIEW_SAMPLE_Y_OFFSET = 100

-- Update rate constants
local TARGET_FPS = 60

-- ============================================================================
-- LUIS UI LIBRARY INITIALIZATION
-- ============================================================================

local initLuis = require("luis.init")
local luis = initLuis("luis/widgets")

-- Register flux for UI animations
luis.flux = require("luis.3rdparty.flux")
luis.theme.text.font = love.graphics.newFont(LUIS_FONT_PATH, FONT_SIZE_LARGE)

-- Create main UI layer
luis.newLayer(LYR_BG)
luis.newLayer(LYR_SOUNDS)
luis.setCurrentLayer(LYR_BG)

-- ============================================================================
-- GRID LAYOUT CALCULATIONS
-- ============================================================================

local gridWidth = math.floor(luis.baseWidth / luis.gridSize)
local gridHeight = math.floor(luis.baseHeight / luis.gridSize)
print("Grid dimensions - Width:", gridWidth, "Height:", gridHeight)

local centerX = math.floor(gridWidth / 2)
local pickerWidth = math.floor(gridWidth / 2)
local pickerX = centerX - pickerWidth / 2 - 180 / gridWidth

-- ============================================================================
-- UI ELEMENTS SETUP
-- ============================================================================

-- Empty callback for widgets that don't need immediate actions
local function doNothing()
end

-- Title
local titleTheme = {
    font = love.graphics.newFont(TITLE_FONT_PATH, FONT_SIZE_LARGE),
    color = {1, 1, 1}
}
local titleLabel = luis.newLabel("Settings", FONT_SIZE_SMALL, 6, 1, pickerX - 6, "left", titleTheme)
luis.createElement(LYR_BG, "Label", titleLabel)
luis.createElement(LYR_SOUNDS, "Label", titleLabel)

-- Background Color Picker
local colorPicker = luis.newColorPicker(pickerWidth, COLORPICKER_HEIGHT, COLORPICKER_Y_POSITION, pickerX, doNothing)
local colorPickerLabel = luis.newLabel("Background color", FONT_SIZE_SMALL, 1, COLORPICKER_LABEL_Y_OFFSET, pickerX)

luis.createElement(LYR_BG, "ColorPicker", colorPicker)
luis.createElement(LYR_BG, "Label", colorPickerLabel)

-- Background Opacity Slider
local opacitySlider = luis.newSlider(0, -- min value
1, -- max value
0.8, -- default value
pickerWidth + ALPHA_SLIDER_Y_OFFSET, 1, doNothing, ALPHA_LABEL_Y_OFFSET + 2, pickerX)
local opacityLabel = luis.newLabel("Background opacity", ALPHA_LABEL_Y_OFFSET + 2, 1, ALPHA_LABEL_Y_OFFSET, pickerX)

luis.createElement(LYR_BG, "Slider", opacitySlider)
luis.createElement(LYR_BG, "Label", opacityLabel)

-- ============================================================================
-- SOUND SLIDERS
-- ============================================================================

-- Music Volume Slider
local musicVolumeSlider = luis.newSlider(0, -- min value
100, -- max value
100, -- default value
pickerWidth + ALPHA_SLIDER_Y_OFFSET, 1, doNothing, COLORPICKER_Y_POSITION, pickerX)
local musicVolumeLabel = luis.newLabel("Music volume", ALPHA_LABEL_Y_OFFSET + 2, 1, COLORPICKER_LABEL_Y_OFFSET, pickerX)

luis.createElement(LYR_SOUNDS, "Slider", musicVolumeSlider)
luis.createElement(LYR_SOUNDS, "Label", musicVolumeLabel)

-- SFX Volume Slider
local sfxVolumeSlider = luis.newSlider(0, -- min value
100, -- max value
100, -- default value
pickerWidth + ALPHA_SLIDER_Y_OFFSET, 1, doNothing, ALPHA_LABEL_Y_OFFSET + 2, pickerX)
local sfxVolumeLabel = luis.newLabel("SFX volume", ALPHA_LABEL_Y_OFFSET + 2, 1, ALPHA_LABEL_Y_OFFSET, pickerX)

luis.createElement(LYR_SOUNDS, "Slider", sfxVolumeSlider)
luis.createElement(LYR_SOUNDS, "Label", sfxVolumeLabel)

-- ============================================================================
-- BUTTON ACTIONS
-- ============================================================================

local function applySettings()
    configui_active = false

    local red, green, blue = unpack(colorPicker.color)
    local newConfig = {
        audio = {
            music = math.floor(musicVolumeSlider.value),
            sound = math.floor(sfxVolumeSlider.value)
        },
        font = {
            override_font = false
        },
        background = {
            red = red,
            green = green,
            blue = blue,
            alpha = opacitySlider.value
        }
    }

    dispatch("config", newConfig)
    dispatch("save_config", newConfig)
end

local function cancelSettings()
    configui_active = false
end

-- ============================================================================
-- BUTTONS
-- ============================================================================

local buttonWidth = gridWidth / 4
local TAB_BASE = gridWidth / 3 + 2
-- Apply Button
local applyButton = luis.newButton("Apply", buttonWidth, BUTTON_HEIGHT, applySettings, doNothing,
    gridHeight - BUTTON_MARGIN_BOTTOM, gridWidth / 4 - buttonWidth / 2)
luis.createElement(LYR_BG, "Button", applyButton)
luis.createElement(LYR_SOUNDS, "Button", applyButton)

-- Cancel Button
local cancelButton = luis.newButton("Cancel", buttonWidth, BUTTON_HEIGHT, doNothing, cancelSettings,
    gridHeight - BUTTON_MARGIN_BOTTOM, gridWidth - gridWidth / 4 - buttonWidth / 2)
luis.createElement(LYR_BG, "Button", cancelButton)
luis.createElement(LYR_SOUNDS, "Button", cancelButton)

local TAB_THEME = {
    color = {0.2, 0.2, 0.2, 1},
    hoverColor = {0.25, 0.25, 0.25, 1},
    pressedColor = {0.15, 0.15, 0.15, 1},
    textColor = {1, 1, 1, 1},
    align = "left",
    cornerRadius = 4,
    elevation = 4,
    elevationHover = 8,
    elevationPressed = 12,
    transitionDuration = 0.25
}
local switchBgLyr = luis.newButton(" Background", buttonWidth, BUTTON_HEIGHT, doNothing, function()
    luis.setCurrentLayer(LYR_BG)
end, 2, TAB_BASE, TAB_THEME)
luis.createElement(LYR_BG, "Button", switchBgLyr)
luis.createElement(LYR_SOUNDS, "Button", switchBgLyr)
local switchSoundsLyr = luis.newButton(" Sounds", buttonWidth, BUTTON_HEIGHT, doNothing, function()
    luis.setCurrentLayer(LYR_SOUNDS)
end, 2, TAB_BASE + buttonWidth, TAB_THEME)
luis.createElement(LYR_BG, "Button", switchSoundsLyr)
luis.createElement(LYR_SOUNDS, "Button", switchSoundsLyr)
-- ============================================================================
-- DIALOG PREVIEW RENDERING
-- ============================================================================

local function renderDialogPreview()
    -- Calculate preview window position
    local previewX = love.graphics.getWidth() / 2 - preview_width / 2
    local previewY = applyButton.position.y * luis.scale - preview_height - PREVIEW_VERTICAL_OFFSET

    -- Draw background sample image
    love.graphics.draw(background_sample, background_sample_quad, previewX, previewY)

    -- Draw colored overlay with current settings
    local red, green, blue = unpack(colorPicker.color)
    local alpha = opacitySlider.value
    love.graphics.setColor(red, green, blue, alpha)
    love.graphics.rectangle("fill", previewX + pad, previewY + pad, preview_width - pad * 2, preview_height - pad * 2)

    -- Draw sample text
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.text_font)
    love.graphics.print("Yes, it's puzzling.", previewX + pad * 2, previewY + pad * 2)
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

on("load", function()
    background_sample = love.graphics.newImage("dialog_preview.png")
end)

on("config", function(config)
    -- Update UI elements with loaded configuration
    colorPicker.color =
        {config.background.red, config.background.green, config.background.blue, config.background.alpha}
    opacitySlider.value = config.background.alpha
    musicVolumeSlider.value = config.audio.music
    sfxVolumeSlider.value = config.audio.sound
end)

on("start_cfgui", function()
    configui_active = true
end)

on("draw_configui", function()
    luis.draw()
    if luis.currentLayer == LYR_BG then
        renderDialogPreview()
    end
end)

on("configui_mr", function(x, y, button, istouch)
    luis.mousereleased(x, y, button, istouch)
end)

on("configui_mp", function(x, y, button, istouch)
    luis.mousepressed(x, y, button, istouch)
end)

-- ============================================================================
-- UPDATE LOOP
-- ============================================================================

local accumulatedTime = 0

on("update", function(dt)
    -- Update preview dimensions based on window size
    preview_width = love.graphics.getWidth() * PREVIEW_WIDTH_RATIO
    preview_height = love.graphics.getHeight() * PREVIEW_HEIGHT_RATIO

    -- Calculate quad for background sample
    local sampleXOffset = background_sample:getWidth() / 2 - preview_width / 2
    background_sample_quad = love.graphics.newQuad(sampleXOffset, PREVIEW_SAMPLE_Y_OFFSET, preview_width,
        preview_height, background_sample)

    -- Update UI scale
    luis.updateScale()

    -- Only update if config UI is active
    if not configui_active then
        return
    end

    -- Update animations at target framerate
    accumulatedTime = accumulatedTime + dt
    if accumulatedTime >= 1 / TARGET_FPS then
        luis.flux.update(accumulatedTime)
        accumulatedTime = 0
    end

    luis.update(dt)
end)
