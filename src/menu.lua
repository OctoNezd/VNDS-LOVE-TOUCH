on("input", function(input)
	if input == "start" then
		-- create_listbox({
		-- 	choices: {
		-- 		{text: "Save", action: -> dispatch "save_slot"}
		-- 		{text: "Load", action: -> dispatch "load_slot", interpreter.base_dir}
		-- 		{text: "Settings", action: -> dispatch "config_menu"}
		-- 		{text: "Main Menu", action: -> love.event.quit("restart")}
		-- 		{text: "Quit", action: love.event.quit}
		-- 	},
		-- 	closable: true
		-- })
		local res = love.window.showMessageBox("Pause", "", {
			"Continue", "Save", "Load", "Settings", "Main Menu"
		}, "info", true)
		love.timer.sleep(0.005)

		if res == 1 then
			return
		elseif res == 2 then
			dispatch("save_slot")
		elseif res == 3 then
			dispatch("load_slot", interpreter.base_dir)
		elseif res == 4 then
			dispatch("start_cfgui")
		elseif res == 5 then
			love.event.quit("restart")
		else
			love.event.quit()
		end
	end
end)
