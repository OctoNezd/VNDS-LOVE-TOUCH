import colorify from require "text/text_color"
import pprint from require "lib/pprint"
local *
buffer = {}
backlog = {}
-- Letter-by-letter rendering state
text_reveal_progress = 0  -- How many characters have been revealed
text_reveal_speed = 0.03  -- Time between each character (in seconds)
text_reveal_timer = nil
text_fully_revealed = true
-- lines = 3
-- if love._console_name == "3DS" then lines = 7
getHeight = -> 
	SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
	return SAFE_HEIGHT
getWidth = ->
    SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
    return SAFE_WIDTH
getSafeX = ->
    SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
	return SAFE_X
getSafeY = ->
    SAFE_X, SAFE_Y, SAFE_WIDTH, SAFE_HEIGHT = love.window.getSafeArea()
	return SAFE_Y
calculate_lines = ->
	return math.floor(getHeight() / (love.text_font\getHeight() + pad))
override_font = nil
custom_font = nil
update_font = ->
	fonts = {}
	if interpreter and not override_font
		font_path = interpreter.base_dir.."default.ttf"
		font_path_otf = interpreter.base_dir.."default.otf"		
		table.insert(fonts, font_path)
		table.insert(fonts, font_path_otf)
	if custom_font
		table.insert(fonts, "/documents/custom.ttf")
		table.insert(fonts, "/documents/custom.otf")
	for _, font in pairs(fonts)
		print("Checking font", font)
		if (love.filesystem.exists(font))
			love.text_font = lg.newFont(font, 32)
			return
	love.text_font = love.graphics.newFont(32)
	-- if interpreter and not override_font
	-- 	font_path = interpreter.base_dir.."default.ttf"
	-- 	if lfs.getInfo(font_path) then love.text_font = lg.newFont(font_path, 32)
	-- else love.text_font = font
bg_color_red = 0
bg_color_blue = 0
bg_color_green = 0
bg_color_alpha = .8
on "config", =>
	override_font = @font.override_font
	custom_font = @font.custom_font
	bg_color_red = @background.red
	bg_color_green = @background.green
	bg_color_blue = @background.blue
	bg_color_alpha = @background.alpha
	update_font!
on "restore", ->
	update_font!
	buffer = {} --clear text state when restoring
	backlog = {}
	if fast_forward
		fast_forward\remove!
		fast_forward = nil
-- Count total characters in buffer (using string.len for byte-based counting)
count_buffer_chars = ->
	total = 0
	draw_buffer = _.first(buffer, calculate_lines())
	for line in *draw_buffer
		-- Each line is a table with alternating colors and text
		for i = 2, #line, 2
			total += string.len(line[i])
	return total

-- Start text reveal animation
start_text_reveal = ->
	text_reveal_progress = 0
	text_fully_revealed = false
	if text_reveal_timer
		text_reveal_timer\remove!
	text_reveal_timer = Timer.every(text_reveal_speed, ->
		text_reveal_progress += 1
		total_chars = count_buffer_chars!
		if text_reveal_progress >= total_chars
			text_fully_revealed = true
			if text_reveal_timer
				text_reveal_timer\remove!
				text_reveal_timer = nil
	)

-- Instantly reveal all text
instant_reveal = ->
	text_reveal_progress = count_buffer_chars!
	text_fully_revealed = true
	if text_reveal_timer
		text_reveal_timer\remove!
		text_reveal_timer = nil

done = () -> buffer = _.rest(buffer, calculate_lines() + 1)
on "text", =>
	if @text == nil then return
	if @text\sub(1, 1) == "@"
		@text = @text\sub(2, -1)
		no_input = true
	if @text == '' or @text == '!' then return
	add = word_wrap(@text, getWidth! - 2*pad)
	for line in *add do table.insert(backlog, line)
	lines = calculate_lines()
	if #buffer == lines and not no_input
		-- Buffer is full, replace with new text
		buffer = add
		start_text_reveal!
	else
		-- Get the character count of existing buffer before adding new text
		old_chars = count_buffer_chars!
		buffer = concat(buffer, add)
		-- Start reveal with old text already revealed
		text_reveal_progress = old_chars
		text_fully_revealed = false
		if text_reveal_timer
			text_reveal_timer\remove!
		text_reveal_timer = Timer.every(text_reveal_speed, ->
			text_reveal_progress += 1
			total_chars = count_buffer_chars!
			if text_reveal_progress >= total_chars
				text_fully_revealed = true
				if text_reveal_timer
					text_reveal_timer\remove!
					text_reveal_timer = nil
		)
		if no_input then dispatch "next_ins"
on "sfx", => table.insert(backlog, @)
fast_forward = nil
on "input", =>
	if @ == "a"
		-- If text is still being revealed, instantly reveal it
		if not text_fully_revealed
			instant_reveal!
		else if #buffer > calculate_lines() then done!
		else dispatch "next_ins"
	else if @ == "y"
		if fast_forward then
			fast_forward\remove!
			fast_forward = nil
		else
			-- When starting fast forward, instantly reveal current text
			instant_reveal!
			fast_forward = Timer.every(0.2, ->
				if #buffer > calculate_lines() then done!
				else dispatch "next_ins"
			)
	else if @ == "x"
		last_ins = {}
		images = {}
		file, line = interpreter.file, interpreter.n
		cancelled = deepcopy(interpreter)
		while true
			interpreter, ins = script.next_instruction(interpreter)
			export interpreter = interpreter
			if interpreter.file == file and interpreter.n == line
				export interpreter = cancelled
				break
			switch ins.type
				when "setimg"
					table.insert(images, ins)
				when "text", "sound", "music", "bgload"
					last_ins[ins.type] = ins
					if ins.type == "bgload" then images = {}
			if ins.type == "choice"
				export interpreter = interpreter
				buffer = {} --clear text state when skipping
				for img in *images do dispatch "next_ins", img
				for key, value in *last_ins
					dispatch "next_ins", value
				dispatch "next_ins", ins
				break
	else if @ == "up"
		choices = {}
		-- choices = [text: t, action: -> for t in *backlog]
		for line in *backlog
			if line.file
				table.insert(choices, {
					text: "[SFX]"
					action: ->
						line.file\play!
						return false
				})
			else
				table.insert(choices, {text: line, action: ->})
		create_listbox(:choices, closable: true, selected: #choices)
	return false
on "draw_text", ->
	if #buffer > 0
		lg.setFont(love.text_font)
		w, h = lg.getWidth! - 2*pad, pad + (love.text_font\getHeight! + pad) * calculate_lines()
		x, y = pad, getHeight! - h - pad
		lg.setColor(bg_color_red, bg_color_green, bg_color_blue, bg_color_alpha)
		lg.rectangle("fill", x, y, w, h)
		lg.setColor(1, 1, 1)
		y_pos = y + pad
		draw_buffer = _.first(buffer, calculate_lines())
		
		-- Track characters revealed so far
		chars_drawn = 0
		
		for line in *draw_buffer
			-- Create a revealed version of the line
			revealed_line = {}
			line_finished = false
			
			-- Each line is a table with alternating colors (odd indices) and text (even indices)
			for i = 1, #line
				if i % 2 == 1
					-- This is a color table, copy it
					table.insert(revealed_line, line[i])
				else
					-- This is text, only show revealed portion
					text = line[i]
					text_len = string.len(text)
					
					if text_fully_revealed or chars_drawn + text_len <= text_reveal_progress
						-- Show entire text segment
						table.insert(revealed_line, text)
						chars_drawn += text_len
					else if chars_drawn < text_reveal_progress
						-- Show partial text segment
						chars_to_show = text_reveal_progress - chars_drawn
						-- Use string.sub for substring
						partial_text = string.sub(text, 1, chars_to_show)
						table.insert(revealed_line, partial_text)
						chars_drawn = text_reveal_progress
						line_finished = true
						break
					else
						-- No more characters to show
						line_finished = true
						break
			
			-- Only draw if there's something to show
			if #revealed_line > 0
				lg.print(revealed_line, 2*pad, y_pos)
			
			y_pos += love.text_font\getHeight! + pad
			
			-- Stop if we've shown all revealed characters
			if line_finished and chars_drawn >= text_reveal_progress
				break
		
		lg.setFont(font)
word_wrap = (text, max_width) ->
	-- Come up with a way to handle a single word that is longer than the width
	-- This code is complex
	colored = colorify(text)
	colors, words, last_color = {}, {}, {}
	list = {{}}
	l = 1
	line = ""
	for i=2, #colored, 2 -- Skip over the colors themselves
		words = split(colored[i], " ")
		if #words > 0
			line = line..words[1]
			last_color = colored[i-1]
			for j=2, #words
				tmp = line.." "..words[j]
				if love.text_font\getWidth(tmp) > max_width
					table.insert(list[l], last_color)
					table.insert(list[l], line)
					l += 1
					table.insert(list, {})
					line = words[j]
				else line = tmp
			if #words > 1 then line = line.." "
		table.insert(list[l], last_color)
		table.insert(list[l], line)
		line = ""
	return list

concat = (t1,t2) ->
	for i=1,#t2 do t1[#t1+1] = t2[i]
	return t1
