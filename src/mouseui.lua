-- ============================================================================
-- Mouse and Touch UI Handler for VNDS-LOVE-TOUCH
-- ============================================================================
-- This module handles mouse/touch input and provides UI components like
-- menu buttons and listboxes for the visual novel engine.
-- ============================================================================
-- Safe Area and Window Configuration
-- ============================================================================
SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
ui_debug = false

on("load", function()
    -- Initialize window with default desktop size
    love.window.setMode(1280, 720)
    pprint(love.window.getMode())

    -- Switch to fullscreen for mobile devices
    if love.system.getOS() == 'iOS' or love.system.getOS() == 'Android' then
        love.window.setMode(0, 0, {
            fullscreen = true
        })
    end

    -- Update safe area after window mode change
    SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
end)

-- ============================================================================
-- Main Drawing Function
-- ============================================================================

function love.draw()
    if ui_debug then
        love.graphics.print("Current FPS: " .. tostring(love.timer.getFPS()), 10, 10)
    end
    if configui_active then
        dispatch_often("draw_configui")
    elseif gridui_active then
        dispatch_often("draw_gridui")
    else
        -- Draw game elements in order from back to front
        dispatch_often("draw_background")
        dispatch_often("draw_foreground")
        dispatch_often("draw_text")
        dispatch_often("draw_ui")
        dispatch_often("draw_debug")
        dispatch_often("draw_choice")
    end
    dispatch_often("draw_mainmenu_button")
end

-- ============================================================================
-- Menu Button Configuration and Rendering
-- ============================================================================

-- Menu button constants
local MENU_BUTTON_WIDTH = 100
local MENU_BUTTON_HEIGHT = 20
local MENU_TEXT = "MENU"
local MENU_SCREEN_MARGIN = 5
local MENU_CORNER_RADIUS = 5

-- Menu button position (updated each frame)
MENU_BUTTON_START_X = 0
MENU_BUTTON_START_Y = 0
MENU_BUTTON_END_X = 0
MENU_BUTTON_END_Y = 0

-- Text rendering setup for menu button
local menu_font = love.graphics.getFont()
menu_font:setLineHeight(0.5)
local menu_text = love.graphics.newText(menu_font)

on("draw_mainmenu_button", function()
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()

    -- Position button in bottom-right corner with margin
    MENU_BUTTON_START_X = screen_width - MENU_BUTTON_WIDTH - MENU_SCREEN_MARGIN
    MENU_BUTTON_START_Y = screen_height - MENU_BUTTON_HEIGHT - MENU_SCREEN_MARGIN
    MENU_BUTTON_END_X = MENU_BUTTON_START_X + MENU_BUTTON_WIDTH
    MENU_BUTTON_END_Y = screen_height - 30

    -- Draw filled button background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", MENU_BUTTON_START_X, MENU_BUTTON_START_Y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT,
        MENU_CORNER_RADIUS, MENU_CORNER_RADIUS)

    -- Draw button border
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", MENU_BUTTON_START_X, MENU_BUTTON_START_Y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT,
        MENU_CORNER_RADIUS, MENU_CORNER_RADIUS)

    -- Draw centered text
    menu_text:clear()
    local font_width = menu_font:getWidth(MENU_TEXT)
    local text_x = MENU_BUTTON_START_X + MENU_BUTTON_WIDTH / 2 - font_width / 2
    menu_text:add(MENU_TEXT, text_x, MENU_BUTTON_START_Y)
    love.graphics.draw(menu_text)
end)

-- ============================================================================
-- Scroll System
-- ============================================================================

-- Scroll state variables
local SCROLL_OFFSET = 0
local OLD_SCROLL_OFFSET = 0
local SCROLL_ACTIVE = false
local SCROLL_LOCKED = false
local SCROLLED = false
local SCROLL_MIN = 0
local SCROLL_MAX = 0

-- ============================================================================
-- Mouse/Touch Input Handlers
-- ============================================================================

function love.mousepressed(x, y, button, istouch)
    -- Delegate to config UI if active
    if configui_active then
        dispatch_often("configui_mp", x, y, button, istouch)
        return
    end
    if gridui_active then
        dispatch_often("gridui_mp", x, y, button, istouch)
        return
    end

    -- Enable scrolling when mouse/touch is pressed
    SCROLL_ACTIVE = true
end

function love.mousemoved(x, y, dx, dy)
    -- Skip if config UI is active
    if configui_active then
        return
    end
    if gridui_active then
        dispatch_often("gridui_mm", x, y, dx, dy)
        return
    end
    -- Handle scrolling if active and not locked
    if SCROLL_ACTIVE and not SCROLL_LOCKED then
        local new_offset = SCROLL_OFFSET + dy

        -- Clamp scroll offset to valid range
        if new_offset < SCROLL_MIN then
            SCROLL_OFFSET = SCROLL_MIN
        elseif new_offset > SCROLL_MAX then
            SCROLL_OFFSET = SCROLL_MAX
        else
            SCROLL_OFFSET = new_offset
        end

        SCROLLED = true
    end
end

function love.mousereleased(x, y, button, istouch)
    -- Check if menu button was clicked
    if x >= MENU_BUTTON_START_X and y > MENU_BUTTON_START_Y then
        dispatch("input", "start")
        return
    end
    -- Delegate to config UI if active
    if configui_active then
        dispatch_often("configui_mr", x, y, button, istouch)
        return
    end
    if gridui_active then
        dispatch_often("gridui_mr", x, y, button, istouch)
        return
    end
    SCROLL_ACTIVE = false

    -- Only trigger click if no scrolling occurred
    if not SCROLLED then
        dispatch("click", x, y, button)
    end

    SCROLLED = false
end

-- ============================================================================
-- Click Event Handler
-- ============================================================================

on("click", function(x, y, button, istouch)
    -- Handle non-touch (mouse) clicks
    if not istouch then
        if button == 1 then
            dispatch("input", "a") -- Left click = advance
        elseif button == 2 then
            dispatch("input", "start") -- Right click = menu
        end
    end
end)

-- ============================================================================
-- Media Sizing Utility
-- ============================================================================

---Calculate scaled dimensions for media to fit within screen constraints
---@param media table The media object (image, etc.)
---@return number width Scaled width
---@return number height Scaled height
---@return number scale Scale factor applied
local function get_media_size(media)
    local max_media_height = love.graphics.getHeight() / 4

    local original_height = media:getHeight()
    local original_width = media:getWidth()
    local scale = 1

    -- Scale down if media is too tall
    if original_height > max_media_height then
        scale = max_media_height / original_height
        original_height = max_media_height
        original_width = original_width * scale
    end

    return original_width, original_height, scale
end

-- ============================================================================
-- Listbox Component
-- ============================================================================

-- Listbox layout constants
local BUTTON_MARGIN = 5
local BUTTON_PADDING = 15
local BUTTON_WIDTH = SAFE_WIDTH - BUTTON_MARGIN * 2
local BUTTON_CORNER_RADIUS = 10
local BUTTON_FILL_OPACITY = 0.5
local BUTTON_BORDER_OPACITY = 0.5
local SCROLL_BOTTOM_PADDING = 200

---Create an interactive scrollable listbox with choices
---@param self table Configuration table with choices array and optional callbacks
local function create_listbox(self)
    local window_width = SAFE_WIDTH
    local font = love.graphics.getFont()
    local text = love.graphics.newText(font)
    local draw_event, input_event

    -- Initialize selected choice
    self.selected = self.selected or 1
    if self.choices[self.selected].onchange then
        self.choices[self.selected].onchange(self.choices[self.selected])
    end

    -- Configuration options
    self.closable = self.closable or false
    self.allow_menu = self.allow_menu or false

    -- Default close handler
    local function close()
        draw_event:remove()
        input_event:remove()
        dispatch("play")
    end
    self.onclose = self.onclose or close

    -- Pause game while listbox is active
    dispatch("pause")

    -- ========================================================================
    -- Calculate Scroll Bounds
    -- ========================================================================

    local buttons = {}
    SCROLL_OFFSET = 0
    SCROLL_MIN = 0
    SCROLL_MAX = 0
    SCROLL_LOCKED = false

    -- Calculate total height of all choices
    local total_height = 0
    for _, choice in ipairs(self.choices) do
        local _, wrapped_lines = font:getWrap(choice.text, window_width - BUTTON_PADDING * 2)
        local button_height = font:getHeight() * #wrapped_lines + BUTTON_MARGIN * 2

        -- Add media height if present
        if choice.media then
            local _, media_height, _ = get_media_size(choice.media)
            button_height = button_height + media_height
        end

        total_height = total_height + button_height
    end

    -- Set scroll bounds
    local screen_height = love.graphics.getHeight()
    SCROLL_MIN = -(total_height - screen_height) - SCROLL_BOTTOM_PADDING

    -- Lock scrolling if content fits on screen
    if total_height < screen_height then
        SCROLL_LOCKED = true
        SCROLL_OFFSET = screen_height / 2 - total_height / 2
    end

    -- ========================================================================
    -- Draw Event Handler
    -- ========================================================================

    draw_event = on("draw_choice", function()
        text:clear()
        buttons = {}
        local current_y = SCROLL_OFFSET

        -- Draw each choice button
        for _, choice in ipairs(self.choices) do
            local text_width, wrapped_lines = font:getWrap(choice.text, window_width - BUTTON_PADDING * 2)

            -- Join wrapped text lines
            local wrapped_text = ""
            if #wrapped_lines == 1 then
                wrapped_text = wrapped_lines[1]
            else
                for _, line in ipairs(wrapped_lines) do
                    wrapped_text = wrapped_text .. line .. '\n'
                end
            end

            -- Calculate button dimensions
            local button_width = window_width - BUTTON_MARGIN * 2
            local button_height = font:getHeight() * #wrapped_lines + BUTTON_MARGIN * 2

            -- Get media dimensions if present
            local media_width = 0
            local media_height = 0
            local media_scale = 1
            if choice.media then
                media_width, media_height, media_scale = get_media_size(choice.media)
                button_height = button_height + media_height
            end

            local button_y = current_y + BUTTON_MARGIN

            -- Store button bounds for click detection
            table.insert(buttons, {
                y_start = button_y,
                y_end = button_y + button_height,
                choice = choice
            })

            -- Draw button background
            love.graphics.setColor(1, 1, 1, BUTTON_FILL_OPACITY)
            love.graphics.rectangle("fill", SAFE_X + BUTTON_MARGIN, button_y, button_width, button_height,
                BUTTON_CORNER_RADIUS, BUTTON_CORNER_RADIUS)

            -- Draw button border
            love.graphics.setColor(0.5, 0.5, 0.5, BUTTON_BORDER_OPACITY)
            love.graphics.rectangle("line", SAFE_X + BUTTON_MARGIN, button_y, button_width, button_height,
                BUTTON_CORNER_RADIUS, BUTTON_CORNER_RADIUS)

            -- Draw button text
            local text_x = math.floor(window_width / 2 - text_width / 2)
            local text_y = math.floor(button_y + media_height)
            text:add(wrapped_text, text_x, text_y)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.draw(text)

            -- Draw media if present
            if choice.media then
                love.graphics.setColor(1, 1, 1)
                local media_x = math.floor(window_width / 2 - media_width / 2)
                love.graphics.draw(choice.media, media_x, button_y + 3, 0, media_scale, media_scale)
            end

            current_y = button_y + button_height
        end
    end)

    -- ========================================================================
    -- Input Event Handler
    -- ========================================================================

    input_event = on("click", function(x, y, button, istouch)
        -- Ignore multi-touch
        if istouch and love.touch.getTouches() > 1 then
            return true
        end

        if button == 1 then
            -- Check if any button was clicked
            for _, button_data in ipairs(buttons) do
                if y >= button_data.y_start and y <= button_data.y_end then
                    local choice = button_data.choice

                    -- Execute main action
                    local outcome = choice.action(choice, close)

                    -- Handle split button actions (left/right side)
                    local screen_center = love.graphics.getWidth() / 2
                    if choice.right ~= nil and x > screen_center then
                        choice.right(choice, close)
                    end
                    if choice.left ~= nil and x < screen_center then
                        choice.left(choice, close)
                    end

                    self:onclose()
                    break
                end
            end
        else
            -- Non-left-click: close if closable
            if self.closable then
                close()
            end
            self:onclose()
        end

        return false
    end)
end

-- ============================================================================
-- Module Exports
-- ============================================================================

return {
    create_listbox = create_listbox,
    luis = luis
}
