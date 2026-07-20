before_menu_screenshot = nil
function store_screenshot(img)
    before_menu_screenshot = img
end
save_ui_pending = false
on("input", function(input)
    if input == "start" then
        if interpreter ~= nil and interpreter.base_dir ~= nil then
            love.graphics.captureScreenshot(store_screenshot)
        end
        love.timer.sleep(0.005)

        local res
        if is_swiftvn then
            -- Use the native iOS action sheet instead of Love's message box.
            local swiftvn = require("swiftvn")
            local choice = swiftvn.showPauseMenu()
            if choice == "continue" then
                res = 1
            elseif choice == "save" then
                res = 2
            elseif choice == "load" then
                res = 3
            elseif choice == "settings" then
                res = 4
            elseif choice == "mainmenu" then
                res = 5
            else
                -- Dismissed without a choice → continue
                res = 1
            end
        else
            res = love.window.showMessageBox("Pause", "", {"Continue", "Save", "Load", "Settings", "Main Menu"}, "info",
                true)
        end

        if res == 1 then
            return
        elseif res == 2 then
            save_ui_pending = true
        elseif res == 3 then
            if interpreter == nil then
                return
            end
            dispatch("load_slot", interpreter.base_dir)
        elseif res == 4 then
            dispatch("start_cfgui")
        elseif res == 5 then
            if is_swiftvn then
                love.event.quit()
            else
                love.event.quit("restart")
            end
        else
            love.event.quit()
        end

    end
end)
