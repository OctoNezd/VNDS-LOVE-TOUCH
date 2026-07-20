local colorlib = require("text.text_color")
local colorify = colorlib.colorify
local pprint = require("lib.pprint")

local buffer = {}
local backlog = {}
lastlines = {}
-- Letter-by-letter rendering state
local text_reveal_progress = 0 -- How many characters have been revealed
local text_reveal_speed = 0.03 -- Time between each character (in seconds)
local text_reveal_timer = nil
local text_fully_revealed = true

local function getHeight()
    local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
    -- we dont need all that bottom space that is reserved for nav
    -- cuz we just display text there
    SAFE_HEIGHT = love.graphics.getHeight() - SAFE_X * 2
    return SAFE_HEIGHT
end

local function getWidth()
    local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
    return SAFE_WIDTH
end

local function getSafeX()
    local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
    return SAFE_X
end

local function getSafeY()
    local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
    return SAFE_Y
end

local function calculate_lines()
    return math.floor(getHeight() / (love.text_font:getHeight() + pad))
end

local override_font = nil
local custom_font = nil

local function update_font()
    local fonts = {}
    if interpreter and not override_font then
        local font_path = interpreter.base_dir .. "default.ttf"
        local font_path_otf = interpreter.base_dir .. "default.otf"
        table.insert(fonts, font_path)
        table.insert(fonts, font_path_otf)
    end
    if custom_font then
        table.insert(fonts, "/documents/custom.ttf")
        table.insert(fonts, "/documents/custom.otf")
    end
    for _, f in pairs(fonts) do
        print("Checking font", f)
        if love.filesystem.exists(f) then
            love.text_font = lg.newFont(f, 32)
            return
        end
    end
    love.text_font = love.graphics.newFont(32)
end

local bg_color_red = 0
local bg_color_blue = 0
local bg_color_green = 0
local bg_color_alpha = .8

on("cleartext", function(self)
    buffer = {}
    dispatch("next_ins")
end)

on("config", function(self)
    override_font = self.font.override_font
    custom_font = self.font.custom_font
    bg_color_red = self.background.red
    bg_color_green = self.background.green
    bg_color_blue = self.background.blue
    bg_color_alpha = self.background.alpha
    update_font()
end)

local fast_forward = nil

on("restore", function()
    update_font()
    buffer = {} -- clear text state when restoring
    backlog = {}
    if fast_forward then
        fast_forward:remove()
        fast_forward = nil
    end
end)

-- Count total characters in buffer (using string.len for byte-based counting)
local function count_buffer_chars()
    local total = 0
    local draw_buffer = _.first(buffer, calculate_lines())
    for _, line in ipairs(draw_buffer) do
        -- Each line is a table with alternating colors and text
        for i = 2, #line, 2 do
            total = total + string.len(line[i])
        end
    end
    return total
end

-- Start text reveal animation
local function start_text_reveal()
    text_reveal_progress = 0
    text_fully_revealed = false
    if text_reveal_timer then
        text_reveal_timer:remove()
    end
    text_reveal_timer = Timer.every(text_reveal_speed, function()
        text_reveal_progress = text_reveal_progress + 1
        local total_chars = count_buffer_chars()
        if text_reveal_progress >= total_chars then
            text_fully_revealed = true
            if text_reveal_timer then
                text_reveal_timer:remove()
                text_reveal_timer = nil
            end
        end
    end)
end

-- Instantly reveal all text
local function instant_reveal()
    text_reveal_progress = count_buffer_chars()
    text_fully_revealed = true
    if text_reveal_timer then
        text_reveal_timer:remove()
        text_reveal_timer = nil
    end
end

local function concat(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
    return t1
end

local function word_wrap(text, max_width)
    -- Come up with a way to handle a single word that is longer than the width
    -- This code is complex
    local colored = colorify(text)
    local list = {{}}
    local l = 1
    local line = ""
    local last_color = {}
    for i = 2, #colored, 2 do -- Skip over the colors themselves
        local words = split(colored[i], " ")
        if #words > 0 then
            line = line .. words[1]
            last_color = colored[i - 1]
            for j = 2, #words do
                local tmp = line .. " " .. words[j]
                if love.text_font:getWidth(tmp) > max_width then
                    table.insert(list[l], last_color)
                    table.insert(list[l], line)
                    l = l + 1
                    table.insert(list, {})
                    line = words[j]
                else
                    line = tmp
                end
            end
            if #words > 1 then
                line = line .. " "
            end
        end
        table.insert(list[l], last_color)
        table.insert(list[l], line)
        line = ""
    end
    return list
end

local function done()
    buffer = _.rest(buffer, calculate_lines() + 1)
end

on("text", function(self)
    if self.text == nil then
        return
    end
    local no_input = false
    if self.text:sub(1, 1) == "@" then
        self.text = self.text:sub(2, -1)
        no_input = true
    end
    table.insert(lastlines, colorlib.strip_colors(self.text))
    if #lastlines > 3 then
        table.remove(lastlines, 1)
    end
    local add_lines = word_wrap(self.text, getWidth() - 2 * pad)
    for _, line in ipairs(add_lines) do
        table.insert(backlog, line)
    end
    local lines = calculate_lines()
    if #buffer == lines and not no_input then
        -- Buffer is full, replace with new text
        buffer = add_lines
        start_text_reveal()
    else
        -- Get the character count of existing buffer before adding new text
        local old_chars = count_buffer_chars()
        buffer = concat(buffer, add_lines)
        -- Start reveal with old text already revealed
        text_reveal_progress = old_chars
        text_fully_revealed = false
        if text_reveal_timer then
            text_reveal_timer:remove()
        end
        text_reveal_timer = Timer.every(text_reveal_speed, function()
            text_reveal_progress = text_reveal_progress + 1
            local total_chars = count_buffer_chars()
            if text_reveal_progress >= total_chars then
                text_fully_revealed = true
                if text_reveal_timer then
                    text_reveal_timer:remove()
                    text_reveal_timer = nil
                end
            end
        end)
        if no_input then
            dispatch("next_ins")
        end
    end
end)

on("sfx", function(self)
    table.insert(backlog, self)
end)

on("input", function(self)
    if self == "a" then
        -- If text is still being revealed, instantly reveal it
        if not text_fully_revealed then
            instant_reveal()
        elseif #buffer > calculate_lines() then
            done()
        else
            dispatch("next_ins")
        end
    elseif self == "y" then
        if fast_forward then
            fast_forward:remove()
            fast_forward = nil
        else
            -- When starting fast forward, instantly reveal current text
            instant_reveal()
            fast_forward = Timer.every(0.2, function()
                if #buffer > calculate_lines() then
                    done()
                else
                    dispatch("next_ins")
                end
            end)
        end
    elseif self == "x" then
        local last_ins = {}
        local images = {}
        local file, line = interpreter.file, interpreter.n
        local cancelled = deepcopy(interpreter)
        while true do
            local ins
            interpreter, ins = script.next_instruction(interpreter)
            if interpreter.file == file and interpreter.n == line then
                interpreter = cancelled
                break
            end
            if ins.type == "setimg" then
                table.insert(images, ins)
            elseif ins.type == "text" or ins.type == "sound" or ins.type == "music" or ins.type == "bgload" then
                last_ins[ins.type] = ins
                if ins.type == "bgload" then
                    images = {}
                end
            end
            if ins.type == "choice" then
                buffer = {} -- clear text state when skipping
                for _, img in ipairs(images) do
                    dispatch("next_ins", img)
                end
                for _, value in pairs(last_ins) do
                    dispatch("next_ins", value)
                end
                dispatch("next_ins", ins)
                break
            end
        end
    elseif self == "up" then
        local choices = {}
        for _, line in ipairs(backlog) do
            if line.file then
                table.insert(choices, {
                    text = "[SFX]",
                    action = function()
                        line.file:play()
                        return false
                    end
                })
            else
                table.insert(choices, {
                    text = line,
                    action = function()
                    end
                })
            end
        end
        create_listbox({
            choices = choices,
            closable = true,
            selected = #choices
        })
    end
    return false
end)

on("draw_text", function()
    if #buffer > 0 then
        lg.setFont(love.text_font)
        local w = lg.getWidth() - 2 * pad
        local h = pad + (love.text_font:getHeight() + pad) * calculate_lines()
        local x = pad
        local y = getHeight() - h - pad
        lg.setColor(bg_color_red, bg_color_green, bg_color_blue, bg_color_alpha)
        lg.rectangle("fill", x, y, w, h)
        lg.setColor(1, 1, 1)
        local y_pos = y + pad
        local draw_buffer = _.first(buffer, calculate_lines())

        -- Track characters revealed so far
        local chars_drawn = 0

        for _, line in ipairs(draw_buffer) do
            -- Create a revealed version of the line
            local revealed_line = {}
            local line_finished = false

            -- Each line is a table with alternating colors (odd indices) and text (even indices)
            for i = 1, #line do
                if i % 2 == 1 then
                    -- This is a color table, copy it
                    table.insert(revealed_line, line[i])
                else
                    -- This is text, only show revealed portion
                    local text = line[i]
                    local text_len = string.len(text)

                    if text_fully_revealed or chars_drawn + text_len <= text_reveal_progress then
                        -- Show entire text segment
                        table.insert(revealed_line, text)
                        chars_drawn = chars_drawn + text_len
                    elseif chars_drawn < text_reveal_progress then
                        -- Show partial text segment
                        local chars_to_show = text_reveal_progress - chars_drawn
                        -- Use string.sub for substring
                        local partial_text = string.sub(text, 1, chars_to_show)
                        table.insert(revealed_line, partial_text)
                        chars_drawn = text_reveal_progress
                        line_finished = true
                        break
                    else
                        -- No more characters to show
                        line_finished = true
                        break
                    end
                end
            end

            -- Only draw if there's something to show
            if #revealed_line > 0 then
                if revealed_line[2] ~= '' then
                    lg.print(revealed_line, 2 * pad, y_pos)
                end
            end

            y_pos = y_pos + love.text_font:getHeight() + pad

            -- Stop if we've shown all revealed characters
            if line_finished and chars_drawn >= text_reveal_progress then
                break
            end
        end

        lg.setFont(font)
    end
end)
