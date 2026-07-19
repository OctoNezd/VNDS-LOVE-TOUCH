before_menu_screenshot = nil
function store_screenshot(img)
    before_menu_screenshot = img
end
menu_pending = false
on("input", function(input)
    if input == "start" then
        if interpreter.base_dir ~= nil then
            love.graphics.captureScreenshot(store_screenshot)
        end
        menu_pending = true
    end
end)
on("menu", function()
    local res = love.window.showMessageBox("Pause", "", {"Continue", "Save", "Load", "Settings", "Main Menu"}, "info",
        true)
    love.timer.sleep(0.005)

    if res == 1 then
        return
    elseif res == 2 then
        dispatch("save_slot")
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
end)
