-- ============================================================================
-- Configuration UI Module
-- Provides a visual settings interface using the LUIS UI library
-- ============================================================================
-- Global state flag
configui_active = false
luis_debug = false
-- ============================================================================
-- CONSTANTS
-- ============================================================================
local runningConfig = {}
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

-- Update rate constants
local TARGET_FPS = 60

-- ============================================================================
-- LUIS UI LIBRARY INITIALIZATION
-- ============================================================================

local initLuis = require("luis.init")
local luis = initLuis("luis/widgets")

-- Register local custom widgets
local numberSpinner = require("widgets.numberSpinner")
numberSpinner.setluis(luis)
luis.widgets["numberSpinner"] = numberSpinner
luis.newNumberSpinner = numberSpinner.new

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
local pickerWidth = math.floor(gridWidth / 4)
-- The color picker renders extra content (color preview + values) adding 180px (9 grid units) beyond pickerWidth
local colorPickerExtraWidth = math.ceil(180 / luis.gridSize)
local columnGap = colorPickerExtraWidth + 2
local totalContentWidth = pickerWidth + columnGap + pickerWidth
local leftColumnX = centerX - math.floor(totalContentWidth / 2)
local rightColumnX = leftColumnX + pickerWidth + columnGap

-- ============================================================================
-- UI ELEMENTS SETUP
-- ============================================================================

-- Empty callback for widgets that don't need immediate actions
local function doNothing()
end

--- background for background settings

local function drawBgFunc(widget)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, widget.width, widget.height)
end

local bgPadding = 2
local bgLeft = leftColumnX - bgPadding
local bgRight = rightColumnX + pickerWidth + bgPadding
local bgWidth = bgRight - bgLeft
local bgCol = bgLeft
local bgRow = 2
local bgTabBackground = luis.newCustom(drawBgFunc, bgWidth, gridHeight - bgRow, bgRow, bgCol)
luis.createElement(LYR_BG, "Custom", bgTabBackground)

-- ============================================================================
-- LEFT COLUMN: BACKGROUND SETTINGS
-- ============================================================================

-- Background Section Header

-- Background Color Picker
backgroundColorPicker = luis.newColorPicker(pickerWidth, COLORPICKER_HEIGHT, COLORPICKER_Y_POSITION, leftColumnX,
    doNothing)
local backgroundColorPickerLabel = luis.newLabel("Color", FONT_SIZE_SMALL, 1, COLORPICKER_LABEL_Y_OFFSET, leftColumnX)

luis.createElement(LYR_BG, "ColorPicker", backgroundColorPicker)
luis.createElement(LYR_BG, "Label", backgroundColorPickerLabel)

-- Background Opacity Slider
opacitySlider = luis.newSlider(0, -- min value
1, -- max value
0.4, -- default value
pickerWidth + ALPHA_SLIDER_Y_OFFSET, 1, doNothing, ALPHA_LABEL_Y_OFFSET + 2, leftColumnX)
local opacityLabel = luis.newLabel("Opacity", ALPHA_LABEL_Y_OFFSET + 2, 1, ALPHA_LABEL_Y_OFFSET, leftColumnX)

luis.createElement(LYR_BG, "Slider", opacitySlider)
luis.createElement(LYR_BG, "Label", opacityLabel)

-- ============================================================================
-- RIGHT COLUMN: FONT SETTINGS
-- ============================================================================

-- Custom Font Checkbox
customFontCheckbox = luis.newCheckBox(false, 3, update_font, COLORPICKER_LABEL_Y_OFFSET - 1, rightColumnX)
local customFontLabel = luis.newLabel("Use custom font", FONT_SIZE_SMALL, 3, COLORPICKER_LABEL_Y_OFFSET - 1,
    rightColumnX + 4)
local customFontLabelHint = luis.newLabel("(custom.ttf in app folder)", FONT_SIZE_SMALL + 30, 2,
    COLORPICKER_LABEL_Y_OFFSET + 2, rightColumnX + 4, "left", {
        font = love.graphics.newFont(32, "normal"),
        color = {1, 1, 1}
    })

luis.createElement(LYR_BG, "CheckBox", customFontCheckbox)
luis.createElement(LYR_BG, "Label", customFontLabel)
luis.createElement(LYR_BG, "Label", customFontLabelHint)

local noVnFontCheckbox = luis.newCheckBox(false, 3, doNothing, COLORPICKER_LABEL_Y_OFFSET + 5, rightColumnX)
local noVnFontLabel = luis.newLabel("Don't use VN font", FONT_SIZE_SMALL, 3, COLORPICKER_LABEL_Y_OFFSET + 5,
    rightColumnX + 4)

luis.createElement(LYR_BG, "CheckBox", noVnFontCheckbox)
luis.createElement(LYR_BG, "Label", noVnFontLabel)

-- ============================================================================
--- padding!
-- ============================================================================

local spinnerHeight = 5
local spinnerWidth = 10
local paddingLabelsY = ALPHA_LABEL_Y_OFFSET + 3
local paddingLabelsHeightY = paddingLabelsY + 4
local paddingLabelsWidthY = paddingLabelsHeightY + spinnerHeight
local paddingOuterLabelsX = leftColumnX + spinnerWidth * 2
local linePaddingLabelsX = paddingOuterLabelsX + spinnerWidth * 1.5

local paddingInnerLabel = luis.newLabel("Padding Inner", FONT_SIZE_LARGE, 3, paddingLabelsY, leftColumnX)
local paddingHeightLabel = luis.newLabel("Height", FONT_SIZE_LARGE, 3, paddingLabelsHeightY, leftColumnX)
local paddingWidthLabel = luis.newLabel("Width", FONT_SIZE_LARGE, 3, paddingLabelsWidthY, leftColumnX)

luis.createElement(LYR_BG, "Label", paddingHeightLabel)
luis.createElement(LYR_BG, "Label", paddingWidthLabel)

-- comments for formatter to fuck off
padHInnerSpinner = luis.newNumberSpinner(-default_pad, 50, 0, 1, -- vals
spinnerWidth, spinnerHeight - 2, -- wh
doNothing, -- act
paddingLabelsHeightY, leftColumnX + 8 -- pos
)
padWInnerSpinner = luis.newNumberSpinner(-default_pad, 50, 0, 1, -- vals
spinnerWidth, spinnerHeight - 2, -- wh
doNothing, -- act
paddingLabelsWidthY, leftColumnX + 8 -- pos
)

luis.createElement(LYR_BG, "NumberSpinner", padHInnerSpinner)
luis.createElement(LYR_BG, "NumberSpinner", padWInnerSpinner)
luis.createElement(LYR_BG, "Label", paddingInnerLabel)

local paddingOuterLabel = luis.newLabel("Outer", FONT_SIZE_LARGE, 3, paddingLabelsY, paddingOuterLabelsX)

-- comments for formatter to fuck off
padHSpinner = luis.newNumberSpinner(-50, 50, 0, 1, -- vals
spinnerWidth, spinnerHeight - 2, -- wh
doNothing, -- act
paddingLabelsHeightY, paddingOuterLabelsX -- pos
)
padWSpinner = luis.newNumberSpinner(-50, 50, 0, 1, -- vals
spinnerWidth, spinnerHeight - 2, -- wh
doNothing, -- act
paddingLabelsWidthY, paddingOuterLabelsX -- pos
)
luis.createElement(LYR_BG, "NumberSpinner", padHSpinner)
luis.createElement(LYR_BG, "NumberSpinner", padWSpinner)
luis.createElement(LYR_BG, "Label", paddingOuterLabel)

linePadSpinner = luis.newNumberSpinner(-default_linepad, 50, 0, 1, -- vals
spinnerWidth, spinnerHeight - 2, -- wh
doNothing, -- act
paddingLabelsHeightY, linePaddingLabelsX -- pos
)
local linePaddingLabel = luis.newLabel("In-between lines", FONT_SIZE_LARGE, 3, paddingLabelsY, linePaddingLabelsX)
luis.createElement(LYR_BG, "NumberSpinner", linePadSpinner)
luis.createElement(LYR_BG, "Label", linePaddingLabel)

-- ============================================================================
-- SOUND SLIDERS
-- ============================================================================

-- Music Volume Slider
local function updateVolume(vol)
    if currentMusic == nil then
        return
    end
    currentMusic:setVolume(vol)
end
local musicVolumeSlider = luis.newSlider(0, -- min value
1, -- max value
1, -- default value
pickerWidth + ALPHA_SLIDER_Y_OFFSET, 1, updateVolume, COLORPICKER_Y_POSITION, leftColumnX)
local musicVolumeLabel = luis.newLabel("Music volume", ALPHA_LABEL_Y_OFFSET + 2, 1, COLORPICKER_LABEL_Y_OFFSET,
    leftColumnX)

local musicPlaying = false
local musicPlayingText = '⏸'
local musicNotPlayingText = "▶"
local function playPauseMusic()
    musicPlaying = not musicPlaying
    if musicPlaying then
        dispatch("music", {
            path = "Space Jazz.mp3"
        })
        playPauseMusic.text = musicPlayingText
    else
        dispatch("music", {})
        playPauseMusic.text = musicNotPlayingText
    end
end
local emojiFont = love.graphics.newFont("NotoEmoji-Regular.ttf", FONT_SIZE_LARGE)
-- Place button right after the slider, spanning the same rows as the label + slider
local playButtonCol = leftColumnX + pickerWidth + ALPHA_SLIDER_Y_OFFSET
local playButtonHeight = COLORPICKER_Y_POSITION - COLORPICKER_LABEL_Y_OFFSET + 4

playPauseMusic = luis.newButton("▶", 4, playButtonHeight, doNothing, playPauseMusic, COLORPICKER_LABEL_Y_OFFSET - 2,
    playButtonCol, {
        color = {0, 0, 0, 0},
        hoverColor = {0, 0, 0, 0},
        pressedColor = {0, 0, 0, 0},
        textColor = {1, 1, 1, 1},
        align = "center",
        cornerRadius = 0,
        elevation = 0,
        elevationHover = 0,
        elevationPressed = 0,
        transitionDuration = 0.25,
        text = {
            font = emojiFont
        }
    })
-- Override draw to skip background/shadow, only render the emoji text
playPauseMusic.defaultDraw = function(self)
    local textFont = emojiFont
    love.graphics.setColor(self.theme.textColor)
    love.graphics.setFont(textFont)
    love.graphics.printf(self.text, self.position.x, self.position.y + (self.height - textFont:getHeight()) / 2,
        self.width, self.theme.align)
end

luis.createElement(LYR_SOUNDS, "Slider", musicVolumeSlider)
luis.createElement(LYR_SOUNDS, "Label", musicVolumeLabel)
luis.createElement(LYR_SOUNDS, "Button", playPauseMusic)

-- SFX Volume Slider
local function playBonk()
    dispatch("sound", {
        path = "bongo-hit.mp3"
    })
end

sfxVolumeSlider = luis.newSlider(0, -- min value
1, -- max value
0.4, -- default value
pickerWidth + ALPHA_SLIDER_Y_OFFSET, 1, playBonk, ALPHA_LABEL_Y_OFFSET + 2, leftColumnX)
local sfxVolumeLabel = luis.newLabel("SFX volume", ALPHA_LABEL_Y_OFFSET + 2, 1, ALPHA_LABEL_Y_OFFSET, leftColumnX)

luis.createElement(LYR_SOUNDS, "Slider", sfxVolumeSlider)
luis.createElement(LYR_SOUNDS, "Label", sfxVolumeLabel)

-- ============================================================================
-- BUTTON ACTIONS
-- ============================================================================

local function cancelSettings()
    configui_active = false
    dont_render_game = false
    dispatch("music", {})
end

local function applySettings()
    local red, green, blue = unpack(backgroundColorPicker.color)
    local newConfig = {
        audio = {
            music = musicVolumeSlider.value,
            sound = sfxVolumeSlider.value
        },
        font = {
            custom_font = customFontCheckbox.value,
            override_font = noVnFontCheckbox.value
        },
        background = {
            red = red,
            green = green,
            blue = blue,
            alpha = opacitySlider.value
        },
        padding = {
            width_inner = padWInnerSpinner.value,
            height_inner = padHInnerSpinner.value,
            width = padWSpinner.value,
            height = padHSpinner.value,
            line_pad = linePadSpinner.value
        }
    }
    for key, value in pairs(runningConfig) do -- override defaults with config
        if newConfig[key] ~= nil then
            _.extend(runningConfig[key], newConfig[key])
        end
    end
    dispatch("config", runningConfig)
    dispatch("save_config", runningConfig)
    Timer.after(0.1, cancelSettings)
end

local function resetSettings()
    dispatch("reset_config")
end

-- ============================================================================
-- BUTTONS
-- ============================================================================

local buttonWidth = gridWidth / 8
-- Position Apply and Cancel buttons centered within the background
local applyButtonCol = bgLeft + math.floor((bgWidth / 2 - buttonWidth / 2) / 2)
local resetButtonCol = applyButtonCol + buttonWidth
local cancelButtonCol = resetButtonCol + buttonWidth

-- Apply Button
local applyButton = luis.newButton("Apply", buttonWidth, BUTTON_HEIGHT, applySettings, doNothing,
    gridHeight - BUTTON_MARGIN_BOTTOM, applyButtonCol)
luis.createElement(LYR_BG, "Button", applyButton)
luis.createElement(LYR_SOUNDS, "Button", applyButton)

-- Reset Button
local resetButton = luis.newButton("Reset", buttonWidth, BUTTON_HEIGHT, resetSettings, doNothing,
    gridHeight - BUTTON_MARGIN_BOTTOM, resetButtonCol)
luis.createElement(LYR_BG, "Button", resetButton)
luis.createElement(LYR_SOUNDS, "Button", resetButton)

-- Cancel Button
local cancelButton = luis.newButton("Cancel", buttonWidth, BUTTON_HEIGHT, cancelSettings, doNothing,
    gridHeight - BUTTON_MARGIN_BOTTOM, cancelButtonCol)
luis.createElement(LYR_BG, "Button", cancelButton)
luis.createElement(LYR_SOUNDS, "Button", cancelButton)

-- Position tab buttons centered within the background
local tabTotalWidth = 2 * buttonWidth
local TAB_BASE = bgLeft + math.floor((bgWidth - tabTotalWidth) / 2)

local TAB_THEME = {
    color = {0.2, 0.2, 0.2, 0},
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
local switchBgLyr = luis.newButton(" UI", buttonWidth, BUTTON_HEIGHT, doNothing, function()
    luis.setCurrentLayer(LYR_BG)
    dont_render_game = false
end, bgRow, TAB_BASE, TAB_THEME)
luis.createElement(LYR_BG, "Button", switchBgLyr)
luis.createElement(LYR_SOUNDS, "Button", switchBgLyr)
local switchSoundsLyr = luis.newButton(" Sounds", buttonWidth, BUTTON_HEIGHT, doNothing, function()
    dont_render_game = true
    luis.setCurrentLayer(LYR_SOUNDS)
end, bgRow, TAB_BASE + buttonWidth, TAB_THEME)
luis.createElement(LYR_BG, "Button", switchSoundsLyr)
luis.createElement(LYR_SOUNDS, "Button", switchSoundsLyr)

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

on("config", function(config)
    -- Update UI elements with loaded configuration
    backgroundColorPicker.color = {config.background.red, config.background.green, config.background.blue,
                                   config.background.alpha}
    opacitySlider.value = config.background.alpha

    customFontCheckbox:setValue(config.font.custom_font)
    noVnFontCheckbox:setValue(config.font.override_font)

    musicVolumeSlider.value = config.audio.music
    sfxVolumeSlider.value = config.audio.sound

    padWInnerSpinner.value = config.padding.width_inner
    padHInnerSpinner.value = config.padding.height_inner

    padWSpinner.value = config.padding.width
    padHSpinner.value = config.padding.height

    linePadSpinner.value = config.padding.line_pad

    runningConfig = config
end)

on("start_cfgui", function()
    configui_active = true
    dont_render_game = false
end)

on("draw_configui", function()
    luis.draw()
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
    -- Only update if config UI is active
    if not configui_active then
        return
    end
    -- Update UI scale
    luis.updateScale()

    -- Update animations at target framerate
    accumulatedTime = accumulatedTime + dt
    if accumulatedTime >= 1 / TARGET_FPS then
        luis.flux.update(accumulatedTime)
        accumulatedTime = 0
    end

    luis.update(dt)
end)
on("luis_debug", function()
    luis.showGrid = not luis.showGrid
    luis.showLayerNames = not luis.showLayerNames
    luis.showElementOutlines = not luis.showElementOutlines
end)
