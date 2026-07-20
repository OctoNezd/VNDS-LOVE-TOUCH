local colorlib = require("text.text_color")
local colorify = colorlib.colorify
local pprint = require("lib.pprint")
local utf8 = require("utf8")

local buffer = {}
local backlog = {}
lastlines = {}
-- Letter-by-letter rendering state
local text_reveal_progress = 0 -- How many characters have been revealed
local text_reveal_speed = 0.03 -- Time between each character (in seconds)
local text_reveal_timer = nil
local text_fully_revealed = true

local function getSafeX()
    local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
    return SAFE_X
end

local function getSafeY()
    local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
    if SAFE_Y == 0 then
        return pad_h
    end
    return SAFE_Y
end

local function getWidth()
    local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
    return SAFE_WIDTH
end

local function getHeight()
    -- we dont need all that bottom space that is reserved for nav
    -- cuz we just display text there
    local SAFE_HEIGHT = love.graphics.getHeight() - getSafeY() * 2
    return SAFE_HEIGHT
end

local function calculate_lines()
    return math.floor((getHeight() - pad_h * 2 - pad_h_inner * 2) / (love.text_font:getHeight() + linepad))
end

local override_font = nil
local custom_font = nil

-- System fonts with CJK (Japanese/Chinese/Korean) glyph coverage,
-- tried in order on macOS and iOS.
local cjk_system_fonts = {"NotoSansCJK-Regular.ttc"}

local function make_cjk_fallback(size)
    for _, path in ipairs(cjk_system_fonts) do
        local ok, f = pcall(love.graphics.newFont, path, size)
        if ok and f then
            print("Using CJK fallback font:", path)
            return f
        end
    end
    return nil
end

function update_font()
    local fonts = {}
    if interpreter and not override_font then
        local font_path = interpreter.base_dir .. "default.ttf"
        local font_path_otf = interpreter.base_dir .. "default.otf"
        table.insert(fonts, font_path)
        table.insert(fonts, font_path_otf)
    end
    if custom_font or customFontCheckbox.value then
        table.insert(fonts, root_path .. "/custom.ttf")
        table.insert(fonts, root_path .. "/custom.otf")
    end
    local primary = nil
    for _, f in pairs(fonts) do
        print("Checking font", f)
        if love.filesystem.exists(f) then
            print("Font", f, "exists")
            primary = lg.newFont(f, 32)
            break
        end
    end
    if not primary then
        primary = love.graphics.newFont(32)
    end
    local cjk = make_cjk_fallback(32)
    if cjk then
        primary:setFallbacks(cjk)
    end
    love.text_font = primary
end

local default_pad = 8

function setup_padding_vars(config)
    pad_h = default_pad + config.padding.height
    pad_w = default_pad + config.padding.width
    pad_h_inner = default_pad + config.padding.height_inner
    pad_w_inner = default_pad + config.padding.width_inner
    linepad = default_linepad + config.padding.line
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
    setup_padding_vars(self)
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

-- Count total characters in buffer (using utf8.len for proper Unicode character counting)
local function count_buffer_chars()
    local total = 0
    local draw_buffer = _.first(buffer, calculate_lines())
    for _, line in ipairs(draw_buffer) do
        -- Each line is a table with alternating colors and text
        for i = 2, #line, 2 do
            total = total + utf8.len(line[i])
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

-- Build the demo buffer at runtime using the same word_wrap logic as the
-- normal buffer so it respects the current padding/font settings.
local demo_text = [[Oh, the universe!
 Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam non mauris velit. Etiam congue arcu varius metus pharetra, id ornare tellus finibus. Nullam nec turpis in magna imperdiet euismod in non libero. Integer non porttitor mauris, et lobortis neque. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec iaculis dignissim ligula vitae gravida. Nam placerat quam enim, nec malesuada metus sagittis eu. Integer sed elit posuere, dignissim eros vel, cursus risus.

Vestibulum suscipit, mauris id condimentum efficitur, felis lacus egestas nulla, quis mattis tellus odio et libero. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Donec egestas nisi ligula, sed consectetur justo fringilla a. Cras sagittis a turpis nec sagittis. Quisque vulputate scelerisque elit, id eleifend nibh lobortis id. Fusce nisi velit, luctus id dignissim vel, suscipit tincidunt nisi. Integer blandit tincidunt tellus nec elementum. Aliquam sed suscipit est, ut tristique turpis. Maecenas sodales magna purus, in mollis nibh ullamcorper in. Vivamus id elit nec erat dictum fringilla. Ut fringilla sem vitae congue gravida. Sed vehicula est in quam finibus vestibulum. Suspendisse sed sagittis lectus. Phasellus quis dolor at leo facilisis suscipit ac vel justo. Nulla facilisi. Pellentesque pharetra viverra venenatis.

Donec eleifend gravida sem, at cursus urna ullamcorper vitae. Quisque nec vehicula ipsum. In hac habitasse platea dictumst. Praesent rutrum eros vel eros aliquam efficitur ut sit amet justo. Ut vehicula porta risus, sit amet ultricies risus mollis sit amet. Morbi justo nisl, lacinia et posuere sed, convallis sed orci. Nunc a tortor facilisis, suscipit ipsum vitae, convallis massa. Donec vitae pharetra nulla. Sed tincidunt justo tellus, ac lobortis mauris iaculis vitae. Cras ullamcorper quam quis ligula semper suscipit. Vestibulum ultricies vestibulum condimentum. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Vestibulum tempus tellus quis nunc volutpat ornare. In eget nisl feugiat nisi luctus iaculis sagittis eget nunc.

Donec sit amet posuere augue. Duis purus justo, bibendum vel velit id, aliquet viverra eros. Nulla egestas ligula magna, vel blandit enim pellentesque vitae. Integer tristique orci tellus, tincidunt luctus orci sodales nec. Mauris ac pellentesque odio. Integer eu rhoncus ligula. Donec ultricies sodales risus id rhoncus. Praesent mollis id urna non suscipit. Morbi quam leo, ultricies vitae pharetra in, vestibulum eget nibh. Vivamus est lacus, pellentesque venenatis ante non, bibendum scelerisque dolor. Pellentesque eleifend porttitor sollicitudin. Nam a euismod neque, faucibus sagittis est.

Nam aliquam mauris eros. Maecenas ornare interdum nulla eu tempor. Nam tellus tortor, pulvinar et tellus sit amet, venenatis finibus urna. Praesent lobortis ante purus, et tincidunt nulla luctus accumsan. Quisque sed leo accumsan, cursus felis id, lobortis mi. Cras ultricies volutpat turpis. Aliquam in ipsum vel magna blandit volutpat quis in sem. Cras sed convallis risus, pretium dapibus turpis. Maecenas pulvinar semper elementum. Morbi non pulvinar dui, a porta elit. Mauris non hendrerit nunc, vehicula iaculis lacus. Praesent et commodo erat.

Donec tristique et libero eget facilisis. Donec eleifend rutrum libero, sed gravida tortor molestie eu. Nunc at venenatis sapien. Phasellus vel. 
]]
local function build_demo_buffer()
    local max_width = getWidth() - 2 * pad_w - 2 * pad_w_inner
    local result = {}
    -- Split demo text by newlines first, then word-wrap each line separately.
    -- word_wrap doesn't handle embedded newlines, which causes lines to overlap
    -- because love.graphics.print renders \n as a line break but y_pos only
    -- advances by one line height per buffer entry.
    for segment in demo_text:gmatch("([^\n]*)\n?") do
        if segment == "" then
            -- Preserve blank lines as empty entries
            table.insert(result, {{1, 1, 1, 1}, ""})
        else
            local wrapped = word_wrap(segment, max_width)
            for _, line in ipairs(wrapped) do
                table.insert(result, line)
            end
        end
    end
    return result
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
    local add_lines = word_wrap(self.text, getWidth() - 2 * pad_w - 2 * pad_w_inner)
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
    local used_buffer = buffer
    if configui_active then
        used_buffer = build_demo_buffer()
    end
    if #used_buffer > 0 then
        lg.setFont(love.text_font)
        local w = getWidth() - 2 * pad_w
        local draw_buffer = _.first(used_buffer, calculate_lines())
        local h = pad_h * 2 + pad_h_inner * 2 + (love.text_font:getHeight() + linepad) * calculate_lines()
        local x = getSafeX() + pad_w
        local y = (love.graphics.getHeight() - h) / 2
        if configui_active then
            local red, green, blue = unpack(backgroundColorPicker.color)
            lg.setColor(red, green, blue, opacitySlider.value)
        else
            lg.setColor(bg_color_red, bg_color_green, bg_color_blue, bg_color_alpha)
        end
        lg.rectangle("fill", x, y, w, h)
        lg.setColor(1, 1, 1)
        local y_pos = y + pad_h + pad_h_inner

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
                    local text_len = utf8.len(text)

                    if text_fully_revealed or chars_drawn + text_len <= text_reveal_progress then
                        -- Show entire text segment
                        table.insert(revealed_line, text)
                        chars_drawn = chars_drawn + text_len
                    elseif chars_drawn < text_reveal_progress then
                        -- Show partial text segment (use utf8.offset to avoid splitting multi-byte chars)
                        local chars_to_show = text_reveal_progress - chars_drawn
                        local byte_end = utf8.offset(text, chars_to_show + 1) - 1
                        local partial_text = string.sub(text, 1, byte_end)
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
                    lg.print(revealed_line, x + pad_w_inner, y_pos)
                end
            end

            y_pos = y_pos + love.text_font:getHeight() + linepad

            -- Stop if we've shown all revealed characters
            if line_finished and chars_drawn >= text_reveal_progress then
                break
            end
        end

        lg.setFont(font)
    end
end)
