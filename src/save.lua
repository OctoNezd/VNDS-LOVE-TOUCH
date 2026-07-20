local json = require "lib.json"
local create_grid_ui = require "gridui"

local media = 0

on("resize", function()
    media = font:getHeight() * 3
end)

local function preview_slot(i, fn, save, info)
    local img = nil
    if love.filesystem.exists(fn .. ".png") then
        img = lg.newImage(fn .. ".png")
    else
        if save.background and save.background.path then
            img = lg.newImage(save.background.path)
        end
    end
    return {
        text = "Save " .. i .. " " .. os.date("%x %H:%M"),
        media = img,
        data = {
            save = save,
            fn = fn,
            i = i
        }
    }
end

-- ---------------------------------------------------------------------------
-- Native iOS save/load dialog (SwiftVN only)
-- ---------------------------------------------------------------------------
-- Presents the SwiftUI slot-picker sheet (non-blocking) and calls `callback`
-- with the chosen slot number (1-based) or nil when the user cancels.
-- While the sheet is open the game loop continues running normally.

local function native_slot_ui(base_dir, mode, callback)
    local swiftvn = require("swiftvn")

    -- Convert the Love virtual path (/documents/GameName/) to a real
    -- filesystem path using the same substitution as mount.lua.
    -- getFullCommonPath("userdocuments") returns the real Documents path,
    -- possibly with a trailing slash — strip it first to avoid double slashes.
    local docs_real = love.filesystem.getFullCommonPath("userdocuments"):gsub("/$", "")
    local real_dir = base_dir:gsub("/documents", docs_real)
    -- Normalise double slashes and strip any trailing slash.
    real_dir = real_dir:gsub("//", "/"):gsub("/$", "")

    -- Present the sheet (returns immediately).
    swiftvn.showSaveDialog(real_dir, mode)

    -- Poll each frame until the user makes a choice.
    local poll_evt
    poll_evt = on("update", function()
        local result = swiftvn.pollSlotResult()
        if result == nil then
            return -- still open, keep polling
        end
        poll_evt:remove()
        -- result is a slot number (integer) or false (cancelled)
        if result == false then
            callback(nil)
        else
            callback(result)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Love grid-based slot UI (non-SwiftVN)
-- ---------------------------------------------------------------------------

local function slot_ui(base_dir, existing_slot, new_slot, closable)
    if closable == nil then
        closable = true
    end
    local choices = {}
    for i = 1, 30 do
        lfs.createDirectory(base_dir)
        local fn = base_dir .. "save" .. i .. ".json"
        local info = lfs.getInfo(fn)
        if info then
            local save = json.decode(lfs.read(fn))
            local choice = preview_slot(i, fn, save, info)
            choice.action = existing_slot
            table.insert(choices, choice)
        else
            table.insert(choices, {
                text = "Save " .. i .. " --",
                action = new_slot,
                data = {
                    fn = fn,
                    i = i
                }
            })
        end
    end
    -- HACK
    Timer.after(0.1, function()
        create_grid_ui(choices, font:getHeight() * 3)
    end)
end

-- ---------------------------------------------------------------------------
-- Save event
-- ---------------------------------------------------------------------------

on("save_slot", function()
    if interpreter == nil then
        return
    end
    local base_dir = interpreter.base_dir

    if is_swiftvn then
        -- Native iOS dialog: present sheet, then write when user picks a slot.
        native_slot_ui(base_dir, "save", function(chosen)
            if chosen == nil then
                return
            end -- user cancelled
            local fn = base_dir .. "save" .. chosen .. ".json"
            local save_table = {
                interpreter = script.save(interpreter),
                last_line = table.concat(lastlines, ' '),
                timestamp = os.time()
            }
            dispatch_often("save", save_table)
            if before_menu_screenshot ~= nil then
                before_menu_screenshot:encode("png", fn .. ".png")
            else
                print("WARN: before_menu_screenshot is nil. This shouldnt happen.")
            end
            print("write res:", love.filesystem.write(fn, json.encode(save_table)))
        end)
        return
    end

    -- Non-SwiftVN: use the Love grid UI.
    local function write_slot(self)
        local save_table = {
            interpreter = script.save(interpreter),
            last_line = table.concat(lastlines, ' '),
            timestamp = os.time()
        }
        dispatch_often("save", save_table)
        if before_menu_screenshot ~= nil then
            before_menu_screenshot:encode("png", self.data.fn .. ".png")
        else
            print("WARN: before_menu_screenshot is nil. This shouldnt happen.")
        end
        print("write res:", love.filesystem.write(self.data.fn, json.encode(save_table)))
        local choice = preview_slot(self.data.i, self.data.fn, save_table, lfs.getInfo(self.data.fn))
        self.text = choice.text
        self.action = write_slot
        self.media = choice.media
        return false
    end
    slot_ui(base_dir, write_slot, write_slot)
end)

-- ---------------------------------------------------------------------------
-- Load event
-- ---------------------------------------------------------------------------

on("load_slot", function(base_dir, closable, novel_name)
    if closable == nil then
        closable = true
    end
    novel_name = novel_name or ""

    if is_swiftvn then
        -- Native iOS dialog: present sheet, then load when user picks a slot.
        native_slot_ui(base_dir, "load", function(chosen)
            if chosen == nil then
                return
            end -- user cancelled
            local fn = base_dir .. "save" .. chosen .. ".json"
            if lfs.getInfo(fn) then
                local save_data = json.decode(lfs.read(fn))
                interpreter = script.load(base_dir, lfs.read, save_data.interpreter, novel_name)
                dispatch("restore", save_data)
                dispatch("next_ins")
            else
                -- Empty slot chosen → start new game
                interpreter = script.load(base_dir, lfs.read, {
                    file = "main.scr"
                }, novel_name)
                dispatch("restore", {})
                dispatch("next_ins")
            end
        end)
        return
    end

    -- Non-SwiftVN: use the Love grid UI.
    slot_ui(base_dir, function(self)
        interpreter = script.load(base_dir, lfs.read, self.data.save.interpreter, novel_name)
        dispatch("restore", self.data.save)
        dispatch("next_ins")
        return true
    end, function(self)
        interpreter = script.load(base_dir, lfs.read, {
            file = "main.scr"
        }, novel_name)
        dispatch("restore", {})
        dispatch("next_ins")
        return true
    end, closable)
end)

on("draw_done", function()
    if save_ui_pending then
        save_ui_pending = false
        dispatch("save_slot")
    end
end)
