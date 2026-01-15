local colorify
colorify = require("text/text_color").colorify
local pprint
pprint = require("lib/pprint").pprint
local buffer, backlog, text_reveal_progress, text_reveal_speed, text_reveal_timer, text_fully_revealed, getHeight, getWidth, getSafeX, getSafeY, calculate_lines, override_font, custom_font, update_font, bg_color_red, bg_color_blue, bg_color_green, bg_color_alpha, count_buffer_chars, start_text_reveal, instant_reveal, done, fast_forward, word_wrap, concat
buffer = { }
backlog = { }
text_reveal_progress = 0
text_reveal_speed = 0.03
text_reveal_timer = nil
text_fully_revealed = true
getHeight = function()
  local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
  return SAFE_HEIGHT
end
getWidth = function()
  local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
  return SAFE_WIDTH
end
getSafeX = function()
  local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
  return SAFE_X
end
getSafeY = function()
  local SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
  return SAFE_Y
end
calculate_lines = function()
  return math.floor(getHeight() / (love.text_font:getHeight() + pad))
end
override_font = nil
custom_font = nil
update_font = function()
  local fonts = { }
  if interpreter and not override_font then
    local font_path = interpreter.base_dir .. "default.ttf"
    table.insert(fonts, font_path)
  end
  if custom_font then
    local font_path = "/documents/custom.ttf"
    table.insert(fonts, font_path)
  end
  for _, font in pairs(fonts) do
    if (love.filesystem.exists(font_path)) then
      love.text_font = lg.newFont(font_path, 32)
      return 
    end
  end
  love.text_font = love.graphics.newFont(32)
end
bg_color_red = 0
bg_color_blue = 0
bg_color_green = 0
bg_color_alpha = .8
on("config", function(self)
  override_font = self.font.override_font
  custom_font = self.font.custom_font
  bg_color_red = self.background.red
  bg_color_green = self.background.green
  bg_color_blue = self.background.blue
  bg_color_alpha = self.background.alpha
  return update_font()
end)
on("restore", function()
  update_font()
  buffer = { }
  backlog = { }
  if fast_forward then
    fast_forward:remove()
    fast_forward = nil
  end
end)
count_buffer_chars = function()
  local total = 0
  local draw_buffer = _.first(buffer, calculate_lines())
  for _index_0 = 1, #draw_buffer do
    local line = draw_buffer[_index_0]
    for i = 2, #line, 2 do
      total = total + string.len(line[i])
    end
  end
  return total
end
start_text_reveal = function()
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
instant_reveal = function()
  text_reveal_progress = count_buffer_chars()
  text_fully_revealed = true
  if text_reveal_timer then
    text_reveal_timer:remove()
    text_reveal_timer = nil
  end
end
done = function()
  buffer = _.rest(buffer, calculate_lines() + 1)
end
on("text", function(self)
  if self.text == nil then
    return 
  end
  if self.text:sub(1, 1) == "@" then
    self.text = self.text:sub(2, -1)
    local no_input = true
  end
  if self.text == '' or self.text == '!' then
    return 
  end
  local add = word_wrap(self.text, getWidth() - 2 * pad)
  for _index_0 = 1, #add do
    local line = add[_index_0]
    table.insert(backlog, line)
  end
  local lines = calculate_lines()
  if #buffer == lines and not no_input then
    buffer = add
    return start_text_reveal()
  else
    local old_chars = count_buffer_chars()
    buffer = concat(buffer, add)
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
      return dispatch("next_ins")
    end
  end
end)
on("sfx", function(self)
  return table.insert(backlog, self)
end)
fast_forward = nil
on("input", function(self)
  if self == "a" then
    if not text_fully_revealed then
      instant_reveal()
    else
      if #buffer > calculate_lines() then
        done()
      else
        dispatch("next_ins")
      end
    end
  else
    if self == "y" then
      if fast_forward then
        fast_forward:remove()
        fast_forward = nil
      else
        instant_reveal()
        fast_forward = Timer.every(0.2, function()
          if #buffer > calculate_lines() then
            return done()
          else
            return dispatch("next_ins")
          end
        end)
      end
    else
      if self == "x" then
        local last_ins = { }
        local images = { }
        local file, line = interpreter.file, interpreter.n
        local cancelled = deepcopy(interpreter)
        while true do
          local interpreter, ins = script.next_instruction(interpreter)
          interpreter = interpreter
          if interpreter.file == file and interpreter.n == line then
            interpreter = cancelled
            break
          end
          local _exp_0 = ins.type
          if "setimg" == _exp_0 then
            table.insert(images, ins)
          elseif "text" == _exp_0 or "sound" == _exp_0 or "music" == _exp_0 or "bgload" == _exp_0 then
            last_ins[ins.type] = ins
            if ins.type == "bgload" then
              images = { }
            end
          end
          if ins.type == "choice" then
            interpreter = interpreter
            buffer = { }
            for _index_0 = 1, #images do
              local img = images[_index_0]
              dispatch("next_ins", img)
            end
            for _index_0 = 1, #last_ins do
              local key, value = last_ins[_index_0]
              dispatch("next_ins", value)
            end
            dispatch("next_ins", ins)
            break
          end
        end
      else
        if self == "up" then
          local choices = { }
          for _index_0 = 1, #backlog do
            local line = backlog[_index_0]
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
                action = function() end
              })
            end
          end
          create_listbox({
            choices = choices,
            closable = true,
            selected = #choices
          })
        end
      end
    end
  end
  return false
end)
on("draw_text", function()
  if #buffer > 0 then
    lg.setFont(love.text_font)
    local w, h = lg.getWidth() - 2 * pad, pad + (love.text_font:getHeight() + pad) * calculate_lines()
    local x, y = pad, getHeight() - h - pad
    lg.setColor(bg_color_red, bg_color_green, bg_color_blue, bg_color_alpha)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(1, 1, 1)
    local y_pos = y + pad
    local draw_buffer = _.first(buffer, calculate_lines())
    local chars_drawn = 0
    for _index_0 = 1, #draw_buffer do
      local line = draw_buffer[_index_0]
      local revealed_line = { }
      local line_finished = false
      for i = 1, #line do
        if i % 2 == 1 then
          table.insert(revealed_line, line[i])
        else
          local text = line[i]
          local text_len = string.len(text)
          if text_fully_revealed or chars_drawn + text_len <= text_reveal_progress then
            table.insert(revealed_line, text)
            chars_drawn = chars_drawn + text_len
          else
            if chars_drawn < text_reveal_progress then
              local chars_to_show = text_reveal_progress - chars_drawn
              local partial_text = string.sub(text, 1, chars_to_show)
              table.insert(revealed_line, partial_text)
              chars_drawn = text_reveal_progress
              line_finished = true
              break
            else
              line_finished = true
              break
            end
          end
        end
      end
      if #revealed_line > 0 then
        lg.print(revealed_line, 2 * pad, y_pos)
      end
      y_pos = y_pos + (love.text_font:getHeight() + pad)
      if line_finished and chars_drawn >= text_reveal_progress then
        break
      end
    end
    return lg.setFont(font)
  end
end)
word_wrap = function(text, max_width)
  local colored = colorify(text)
  local colors, words, last_color = { }, { }, { }
  local list = {
    { }
  }
  local l = 1
  local line = ""
  for i = 2, #colored, 2 do
    words = split(colored[i], " ")
    if #words > 0 then
      line = line .. words[1]
      last_color = colored[i - 1]
      for j = 2, #words do
        local tmp = line .. " " .. words[j]
        if love.text_font:getWidth(tmp) > max_width then
          table.insert(list[l], last_color)
          table.insert(list[l], line)
          l = l + 1
          table.insert(list, { })
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
concat = function(t1, t2)
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end
