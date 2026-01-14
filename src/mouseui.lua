SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()

on("load", function()
    love.window.setMode(1280, 720)
    pprint(love.window.getMode())
    if love.system.getOS() == 'iOS' or love.system.getOS() == 'Android' then
        love.window.setMode(0, 0, { fullscreen = true })
    end
    SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
end)

function love.draw()
    if configui_active then
        dispatch_often("draw_configui")
    else
        dispatch_often("draw_background")
        dispatch_often("draw_foreground")
        dispatch_often("draw_text")
        dispatch_often("draw_mainmenu_button")
        dispatch_often("draw_ui")
        dispatch_often("draw_debug")
        dispatch_often("draw_choice")
    end
end

local menu_fnt = love.graphics.getFont()
menu_fnt:setLineHeight(0.5)
local menu_txt = love.graphics.newText(menu_fnt)

MENU_BUTTON_START_X = 0
MENU_BUTTON_START_Y = 0
MENU_BUTTON_END_X = 0
MENU_BUTTON_END_Y = 0
MENU_BUTTON_WIDTH = 100
MENU_BUTTON_HEIGHT = 20
MENU_TEXT = "MENU"
on("draw_mainmenu_button", function()
    love.graphics.setColor(0, 0, 0)
    local w = love.graphics.getWidth() - 5
    local h = love.graphics.getHeight() - 5
    MENU_BUTTON_START_X = w - MENU_BUTTON_WIDTH
    MENU_BUTTON_START_Y = h - MENU_BUTTON_HEIGHT
    MENU_BUTTON_END_X = MENU_BUTTON_START_X + 100
    MENU_BUTTON_END_Y = h - 30

    love.graphics.rectangle("fill", MENU_BUTTON_START_X, MENU_BUTTON_START_Y, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", MENU_BUTTON_START_X, h - MENU_BUTTON_HEIGHT, MENU_BUTTON_WIDTH, MENU_BUTTON_HEIGHT, 5,
        5)
    menu_txt:clear()
    local font_width = menu_fnt:getWidth(MENU_TEXT)
    menu_txt:add(MENU_TEXT, MENU_BUTTON_START_X + MENU_BUTTON_WIDTH / 2 - font_width / 2, MENU_BUTTON_START_Y)
    love.graphics.draw(menu_txt)
end)

SCROLL_OFFSET = 0
OLD_SCROLL_OFFSET = 0
SCROLL_ACTIVE = false
SCROLL_LOCKED = false
SCROLLED = false
SCROLL_MIN = 0
SCROLL_MAX = 0
function love.mousepressed(x, y, button, istouch)
    if configui_active then 
        dispatch("configui_mp", x, y, button, istouch)
        return
    end
    SCROLL_ACTIVE = true
end

function love.mousemoved(x, y, dx, dy)
    if configui_active then
        return
    end
    if SCROLL_ACTIVE and not SCROLL_LOCKED then
        local tmp = SCROLL_OFFSET + dy
        if tmp < SCROLL_MIN then
            SCROLL_OFFSET = SCROLL_MIN
        elseif tmp > SCROLL_MAX then
            SCROLL_OFFSET = SCROLL_MAX
        else
            SCROLL_OFFSET = tmp
        end
        SCROLLED = true
    end
end

function love.mousereleased(x, y, button, istouch)
    if configui_active then
        dispatch("configui_mr", x, y, button, istouch)
        return
    end
    SCROLL_ACTIVE = false
    if x >= MENU_BUTTON_START_X and y > MENU_BUTTON_START_Y then
        dispatch("input", "start")
        return
    end
    if not SCROLLED then
        -- No movement happened. We clicked on item and thats all.
        dispatch("click", x, y, button)
    end
    SCROLLED = false
end

on("click", function(x, y, button, istouch)
    if not istouch then
        if button == 1 then
            dispatch("input", "a")
        elseif button == 2 then
            dispatch("input", "start")
        end
    else
    end
end)
local function get_media_size(media)
    local max_media_size = love.graphics.getHeight() / 4

    local media_height = media:getHeight()
    local media_width = media:getWidth()
    local media_scale = 1
    if (media_height > max_media_size) then
        media_scale = max_media_size / media_height
        media_height = max_media_size
        media_width = media_width * media_scale
    end
    return media_width, media_height, media_scale
end
BUTTON_MARGIN = 5
BUTTON_PADDING = 15
BUTTON_WIDTH = SAFE_WIDTH - BUTTON_MARGIN * 2
local function create_listbox(self)
    local winwidth = SAFE_WIDTH
    local font = love.graphics.getFont()
    local text = love.graphics.newText(font)
    local draw_evt, input_evt
    self.selected = self.selected or 1
    if self.choices[self.selected].onchange then
        self.choices[self.selected].onchange(self.choices[self.selected])
    end
    self.closable = self.closable or false
    self.allow_menu = self.allow_menu or false
    local function close()
        draw_evt:remove()
        input_evt:remove()
        dispatch("play")
    end
    self.onclose = self.onclose or close
    dispatch("pause")
    local buttons = {}
    SCROLL_OFFSET = 0
    SCROLL_MIN = 0
    SCROLL_MAX = 0
    SCROLL_LOCKED = false
    local height_offset = 0
    for _, v in ipairs(self.choices) do
        local _, wrapped_text_seq = font:getWrap(v.text, winwidth - BUTTON_PADDING * 2)
        local wrapped_text = ""
        if (#wrapped_text_seq == 1) then
            wrapped_text = wrapped_text_seq[1]
        else
            for _, v in ipairs(wrapped_text_seq) do
                wrapped_text = wrapped_text .. v .. '\n'
            end
        end
        local button_height = font:getHeight() * #wrapped_text_seq + BUTTON_MARGIN * 2
        if (v.media) then
            local _, media_height, _ = get_media_size(v.media)
            button_height = button_height + media_height
        end
        height_offset = height_offset + button_height
    end
    SCROLL_MIN = -(height_offset - love.graphics.getHeight()) - 200
    if height_offset < love.graphics.getHeight() then
        SCROLL_LOCKED = true
        SCROLL_OFFSET = love.graphics.getHeight() / 2 - height_offset / 2
    end
    draw_evt = on("draw_choice", function()
        text:clear()
        buttons = {}
        local last_y = SCROLL_OFFSET

        for _, v in ipairs(self.choices) do
            local width, wrapped_text_seq = font:getWrap(v.text, winwidth - BUTTON_PADDING * 2)
            local wrapped_text = ""
            if (#wrapped_text_seq == 1) then
                wrapped_text = wrapped_text_seq[1]
            else
                for _, v in ipairs(wrapped_text_seq) do
                    wrapped_text = wrapped_text .. v .. '\n'
                end
            end
            local button_width = winwidth - BUTTON_MARGIN * 2
            local button_height = font:getHeight() * #wrapped_text_seq + BUTTON_MARGIN * 2
            local media_width = 0
            local media_height = 0
            local media_scale = 1
            if (v.media) then
                media_width, media_height, media_scale = get_media_size(v.media)
            end
            button_height = button_height + media_height
            local y = last_y + BUTTON_MARGIN
            table.insert(buttons, ({
                y_start = y,
                y_end = y + button_height,
                choice = v
            }))
            text:add(wrapped_text, math.floor(winwidth / 2 - width / 2), math.floor(y + media_height))
            love.graphics.setColor(1, 1, 1, .5)
            love.graphics.rectangle("fill", SAFE_X + BUTTON_MARGIN, y,
                button_width, button_height, 10, 10)
            love.graphics.setColor(.5, .5, .5, .5)

            love.graphics.rectangle("line", SAFE_X + BUTTON_MARGIN, y,
                button_width, button_height, 10, 10)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.draw(text)
            if (v.media) then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(v.media, math.floor(winwidth / 2 - media_width / 2), y + 3, 0, media_scale,
                    media_scale)
            end
            last_y = y + button_height
        end
    end)
    input_evt = on("click", function(x, y, button, istouch)
        if istouch and love.touch.getTouches() > 1 then return true end
        if button == 1 then
            for _, v in ipairs(buttons) do
                if (y >= v.y_start and y <= v.y_end) then
                    local outcome = v.choice.action(v.choice, close)
                    if v.choice.right ~= nil and x > love.graphics.getWidth() / 2 then
                        v.choice.right(v.choice, close)
                    end
                    if v.choice.left ~= nil and x < love.graphics.getWidth() / 2 then
                        v.choice.left(v.choice, close)
                    end
                    -- close()
                    self:onclose()
                    break
                end
            end
        else
            if self.closable then close() end
            self:onclose()
        end
        return false
    end)
end

return { create_listbox = create_listbox, luis = luis }
