export *
import dispatch, dispatch_often, on, remove, register from require 'event'
import create_listbox, onload from require "mouseui"
love.graphics.setDefaultFilter("linear", "linear")
pad = 10

script = require "script"
pprint = require "lib/pprint"
Timer = require 'lib/timer'
profile = require 'lib/profile'
profile.setclock(love.timer.getTime)
lfs = love.filesystem
lfs.mountCommonPath("userdocuments", "/documents", "readwrite")
-- apple moment
print(lfs.write("/documents/.dummy.txt", "dummy file to make ios show up the app folder"))
lg = love.graphics
interpreter = nil
-- require "lovelog"
require "audio"
require "debugging"
require "images"
require "text/text"
require "choose"
require "save"
require "input"
require "menu"
require "config"
require "config_ui"
mount = require 'mount'
parse_info = require "parse_info"
os.setlocale("", "time") --Needed for the correct time
lfs.setIdentity("VNDS-LOVE")
sx, sy = 0,0
px, py = 0,0
original_width, original_height = lg.getWidth!,lg.getHeight!
-- on "input", =>
-- 	if @ == "y"
-- 		love.filesystem.write('profile.txt', profile.report(40))

font = nil
love.text_font = nil
love.resize = (w, h) ->
	sx, sy = w / original_width, h / original_height
	px, py = w/256, h/192 --resolution of the DS
	font_size = 32 -- fix the font scaling to work based on resolution
	if w < 600 then font_size = 20
	lg.setNewFont(font_size)
	font = lg.getFont!
	if love.text_font == nil then love.text_font = font
	dispatch "resize", {:sx, :sy, :px, :py}
next_msg = (ins) ->
	if ins == nil
		interpreter, ins = script.next_instruction(interpreter)
	if ins.path --verify path exists before trying to run an instruction
		if ins.path\sub(-1) ~= "~" and not lfs.getInfo(ins.path)
			return next_msg!
	switch ins.type
		when "text"
			if ins.text == "~" then next_msg!
			else dispatch "text", ins
		when "choice"
			dispatch "choice", ins
		when "delay"
			Timer.after(ins.frames/60, -> next_msg!)
		--when "cleartext"
		else
			dispatch ins.type, ins
			next_msg!
on "next_ins", next_msg
love.load = ->
	love.resize(lg.getWidth!, lg.getHeight!)
	dispatch "load"
	root_path = "/documents/"
	novels = lfs.getDirectoryItems(root_path)
	opts = {}
	media = font\getHeight! * 3
	for i,novel in ipairs novels
		continue if string.find(novel, "^%.") ~= nil
		base_dir = root_path..novel.."/"
		novel_name = novel
		if lfs.getInfo(base_dir, "file") then continue
		icons = {"icon-high.png", "icon-high.jpg", "icon.png", "icon.jpg"}
		thumbnails = {"thumbnail-high.png", "thumbnail-high.jpg", "thumbnail.png", "thumbnail.jpg"}
		preview = nil
		for icon in *icons
			if lfs.getInfo(base_dir..icon)
				img = lg.newImage(base_dir..icon)
				preview = img
				break
		path = "~"
		for thumb in *thumbnails
			if lfs.getInfo(base_dir..thumb)
				path = base_dir..thumb
				break
		if lfs.getInfo(base_dir .. "info.txt") ~= nil
		    info = parse_info(base_dir.."info.txt")
			if info["title"] ~= nil then
				novel_name = info["title"]
		table.insert(opts, {
			text: novel_name
			media: preview
			onchange: () -> dispatch "bgload", {:path}
			action: () ->
				files = lfs.getDirectoryItems(base_dir)
				dispatch "load_slot", base_dir, false, novel_name
		})
		mount(base_dir)
	if next(opts) == nil
		dispatch "text", {text: "No novels!"}
		dispatch "text", {text: "Add one to Files/VNDS and restart the program."}
		dispatch "text", {text: "Looking for visual novels to read? Click anywhere on this screen to open VNDB search"}
		on "input", -> 
			love.system.openURL("https://vndb.org/v?q=&sb=Search%21&ch=&f=4ovnd&s=26w")
			return false
	else create_listbox(choices: opts, :media)


paused = 0
on "pause", -> paused += 1
on "play", -> paused -= 1
love.update = (dt) ->
	dispatch_often "update", dt
	if paused <= 0 then Timer.update(dt)

is_fullscreen = false
