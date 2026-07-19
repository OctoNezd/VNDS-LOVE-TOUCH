local pad = 10

-- can also provide "data" as a part of choices
local function remove_color(t)
    local w = ""
    if type(t) == "string" then
        return t
    else
        for i = 2, #t, 2 do
            w = w .. t[i]
        end
    end
    return w
end

local function create_listbox(self)
    self.selected = self.selected or 1
    if self.choices[self.selected].onchange then
        self.choices[self.selected].onchange(self.choices[self.selected])
    end
    self.closable = self.closable or false
    self.allow_menu = self.allow_menu or false
    self.onclose = self.onclose or function() end
    self.media = self.media or -pad

    local input_event, draw_event

    dispatch("pause")

    local function font_height(text)
        local _, count = string.gsub(remove_color(text), "\n", "\n")
        return math.max(love.text_font:getHeight() * (1 + count), self.media)
    end

    local function close()
        input_event:remove()
        draw_event:remove()
        dispatch("play")
    end

    input_event = on("input", function(input)
        if input == "up" then
            self.selected = (self.selected - 2) % #self.choices + 1
        elseif input == "down" then
            self.selected = self.selected % #self.choices + 1
        end
        local chosen = self.choices[self.selected]
        if input == "up" or input == "down" then
            if chosen.onchange then chosen.onchange(chosen) end
        end
        if input == "a" then
            local outcome = chosen.action(chosen, close)
            if self.closable and outcome then close() end
            if not self.closable then close() end
        elseif input == "start" and self.allow_menu then
            return true -- passes it to the below layer
        elseif input == "b" and self.closable then
            close()
            self.onclose()
        elseif input == "right" then
            if chosen.right then chosen.right(chosen) end
        elseif input == "left" then
            if chosen.left then chosen.left(chosen) end
        end
        return false
    end)

    draw_event = on("draw_choice", function()
        lg.setFont(love.text_font)
        local max_w = 0
        for _, c in ipairs(self.choices) do
            local w = love.text_font:getWidth(remove_color(c.text))
            if w > max_w then max_w = w end
        end
        local w = 3 * pad + max_w + self.media
        local h, y_selected = pad, 0
        for i, c in ipairs(self.choices) do
            h = h + font_height(c.text) + pad
            if i == self.selected then y_selected = h end
        end
        local x, y = center(w, lg.getWidth()), center(h, lg.getHeight())
        y = lg.getHeight() / 2 - y_selected
        lg.setColor(.18, .204, .251, .8)
        lg.rectangle("fill", x, y, w, h)
        local text_y = y + pad
        for i, c in ipairs(self.choices) do
            lg.setColor(1, 1, 1)
            if c.media then c.media(x + pad, text_y) end
            if i == self.selected then lg.setColor(.506, .631, .757) end
            lg.print(c.text, x + 2 * pad + self.media, text_y)
            text_y = text_y + pad + font_height(c.text)
        end
        lg.setFont(font)
        return false
    end)
end

return {create_listbox = create_listbox}
