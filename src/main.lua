is_swiftheart = false

local event = require 'event'
dispatch = event.dispatch
dispatch_often = event.dispatch_often
on = event.on
local remove = event.remove
local register = event.register

local json = require "lib.json"

local mouseui = require "mouseui"
create_listbox = mouseui.create_listbox

love.graphics.setDefaultFilter("linear", "linear")
pad = 10

script = require "script"
pprint = require "lib.pprint"
Timer = require 'lib.timer'
local profile = require 'lib.profile'
profile.setclock(love.timer.getTime)
lfs = love.filesystem
lg = love.graphics
interpreter = nil
-- require "lovelog"
require "audio"
require "debugging"
require "images"
require "text.text"
require "choose"
require "save"
require "input"
require "menu"
require "config"
require "config_ui"
local mount = require 'mount'
local parse_info = require "parse_info"
local create_grid_ui = require "gridui"
print(create_grid_ui)
os.setlocale("", "time") -- Needed for the correct time
lfs.setIdentity("VNDS-LOVE")
sx, sy = 0, 0
px, py = 0, 0
original_width, original_height = lg.getWidth(), lg.getHeight()

font = nil
love.text_font = nil

function love.resize(w, h)
    sx, sy = w / original_width, h / original_height
    px, py = w / 256, h / 192 -- resolution of the DS
    local font_size = 32 -- fix the font scaling to work based on resolution
    if w < 600 then
        font_size = 20
    end
    font = lg.newFont(font_size)
    lg.setFont(font)
    if love.text_font == nil then
        love.text_font = font
    end
    dispatch("resize", {
        sx = sx,
        sy = sy,
        px = px,
        py = py
    })
end

local function next_msg(ins)
    if ins == nil then
        interpreter, ins = script.next_instruction(interpreter)
    end
    if ins == nil then
        return
    end -- novel finished
    if ins.path then -- verify path exists before trying to run an instruction
        if ins.path:sub(-1) ~= "~" and not lfs.getInfo(ins.path) then
            return next_msg()
        end
    end
    if ins.type == "text" then
        if ins.text == "~" then
            ins.text = ""
            dispatch("text", ins)
            dispatch("next_ins")
        elseif ins.text == "!" then
            ins.text = ""
            dispatch("text", ins)
        else
            dispatch("text", ins)
        end
    elseif ins.type == "choice" then
        dispatch("choice", ins)
    elseif ins.type == "delay" then
        Timer.after(ins.frames / 60, function()
            next_msg()
        end)
    elseif ins.type == "cleartext" then
        dispatch("cleartext")
    else
        dispatch(ins.type, ins)
        next_msg()
    end
end

on("next_ins", next_msg)

function love.load(arg)
    pprint(arg)
    local root_path = "/documents/"
    if arg[1] == "nomount" then
        print("custom directory arg is set")
        root_path = "/work_around_symlink_bug/sample_vns/"
    else
        print("no arg, using userdocuments")
        lfs.mountCommonPath("userdocuments", root_path, "readwrite")
        if not arg[1] == "swiftheart" then
            -- apple moment
            local dummy_contents = lfs.read("dummy.txt")
            print(lfs.write(root_path .. "IOS-FILES-DUMDUM.TXT", dummy_contents))
        else
            is_swiftheart = true
        end
    end
    love.resize(lg.getWidth(), lg.getHeight())
    dispatch("load")
    print("Root path is", root_path)

    -- Parse command line arguments for game directory and save slot
    -- Usage: love . [game_directory] [save_slot]
    -- When launched from SwiftHeart the arg table looks like:
    --   arg[1] = "swiftheart"
    --   arg[2] = path/to/core.love
    --   arg[3] = "--fused"
    --   arg[4] = game_directory_name
    --   arg[5] = save_slot_number (optional, as string)
    local known_args = {
        nomount = true,
        swiftheart = true,
        ["--fused"] = true
    }
    local game_arg = nil
    local save_slot_arg = nil
    for _, a in ipairs(arg) do
        -- Skip known flag args and file paths (containing "/" or ".love").
        if not known_args[a] and not a:find("/") and not a:find("%.love$") then
            if not game_arg then
                game_arg = a
            elseif not save_slot_arg then
                save_slot_arg = tonumber(a)
                break
            end
        end
    end

    if game_arg then
        local base_dir = root_path .. game_arg .. "/"
        if not lfs.getInfo(base_dir, "directory") then
            dispatch("text", {
                text = "Game not found: " .. game_arg
            })
            return
        end
        mount(base_dir)
        local novel_name = game_arg
        if lfs.getInfo(base_dir .. "info.txt") ~= nil then
            local info = parse_info(base_dir .. "info.txt")
            if info["title"] ~= nil then
                novel_name = info["title"]
            end
        end
        if save_slot_arg and save_slot_arg >= 1 and save_slot_arg <= 30 then
            local fn = base_dir .. "save" .. save_slot_arg .. ".json"
            if lfs.getInfo(fn) then
                local save_data = json.decode(lfs.read(fn))
                interpreter = script.load(base_dir, lfs.read, save_data.interpreter, novel_name)
                dispatch("restore", save_data)
                dispatch("next_ins")
                return
            end
        end
        -- Start new game (no valid save slot specified or save not found)
        interpreter = script.load(base_dir, lfs.read, {
            file = "main.scr"
        }, novel_name)
        dispatch("restore", {})
        dispatch("next_ins")
        return
    end

    local novels = lfs.getDirectoryItems(root_path)
    pprint(novels)
    local opts = {}
    local item_height = font:getHeight() * 3
    for i, novel in ipairs(novels) do
        if string.find(novel, "^%.") ~= nil then
            goto continue
        end
        local base_dir = root_path .. novel .. "/"
        local novel_name = novel
        if lfs.getInfo(base_dir, "file") then
            goto continue
        end
        local icons = {"icon-high.png", "icon-high.jpg", "icon.png", "icon.jpg"}
        local thumbnails = {"thumbnail-high.png", "thumbnail-high.jpg", "thumbnail.png", "thumbnail.jpg"}
        local media = nil
        for _, icon in ipairs(icons) do
            if lfs.getInfo(base_dir .. icon) then
                media = love.graphics.newImage(base_dir .. icon)
                break
            end
        end
        local thumb = nil
        for _, thumb_path in ipairs(thumbnails) do
            if lfs.getInfo(base_dir .. thumb_path) then
                thumb = love.graphics.newImage(base_dir .. thumb_path)
                break
            end
        end
        if lfs.getInfo(base_dir .. "info.txt") ~= nil then
            local info = parse_info(base_dir .. "info.txt")
            if info["title"] ~= nil then
                novel_name = info["title"]
            end
        end
        table.insert(opts, {
            text = novel_name,
            media = media,
            thumb = thumb,
            action = function()
                local files = lfs.getDirectoryItems(base_dir)
                dispatch("load_slot", base_dir, false, novel_name)
            end
        })
        mount(base_dir)
        ::continue::
    end
    if next(opts) == nil then
        dispatch("text", {
            text = "No novels!"
        })
        dispatch("text", {
            text = "Add one to Files/VNDS and restart the program."
        })
        dispatch("text", {
            text = "Looking for visual novels to read? Click anywhere on this screen to open VNDB search"
        })
        on("input", function()
            love.system.openURL("https://vndb.org/v?q=&sb=Search%21&ch=&f=4ovnd&s=26w")
            return false
        end)
    else
        create_grid_ui(opts, item_height)
    end
end

local paused = 0
on("pause", function()
    paused = paused + 1
end)
on("play", function()
    paused = paused - 1
end)

function love.update(dt)
    dispatch_often("update", dt)
    if paused <= 0 then
        Timer.update(dt)
    end
end

function love.keyreleased(key)
    dispatch("keyboard_input", key)
end

local is_fullscreen = false
