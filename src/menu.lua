before_menu_screenshot = nil
function store_screenshot(img)
    before_menu_screenshot = img
end
save_ui_pending = false
on("input", function(input)
    if input == "start" then
        local res = love.window.showMessageBox("Pause", "", {"Continue", "Save", "Load", "Settings", "Main Menu"},
            "info", true)
        if interpreter ~= nil and interpreter.base_dir ~= nil then
            love.graphics.captureScreenshot(store_screenshot)
        end
        love.timer.sleep(0.005)

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
            if is_swiftheart then
                love.event.quit()
            else
                love.event.quit("restart")
            end
        else
            love.event.quit()
        end

    end
end)

