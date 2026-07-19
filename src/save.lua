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

on("save_slot", function()
    if interpreter == nil then
        return
    end
    local base_dir = interpreter.base_dir
    local function write_slot(self)
        local save_table = {
            interpreter = script.save(interpreter),
            last_line = table.concat(lastlines, ' ')
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

on("load_slot", function(base_dir, closable, novel_name)
    if closable == nil then
        closable = true
    end
    novel_name = novel_name or ""
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
