json = require "lib.json"
local *
media = 0
on "resize", -> media = font\getHeight! * 3
on "save_slot", ->
	if interpreter == nil return
	base_dir = interpreter.base_dir
	write_slot = =>
		save_table = {interpreter: script.save(interpreter)}
		dispatch_often "save", save_table
		print("write res:", love.filesystem.write(@data.fn, json.encode(save_table)))
		choice = preview_slot(@data.i, @data.fn, save_table, lfs.getInfo(@data.fn))
		@text = choice.text
		@action = write_slot
		@media = choice.media
		return false
	slot_ui(base_dir, write_slot, write_slot)
on "load_slot", (base_dir, closable = true, novel_name="") ->
	slot_ui(base_dir,
		=>
			export interpreter = script.load(base_dir, lfs.read, @data.save.interpreter, novel_name)
			dispatch "restore", @data.save
			dispatch "next_ins"
			return true
		=>
			export interpreter = script.load(base_dir, lfs.read, file: "main.scr", novel_name)
			dispatch "restore", {}
			dispatch "next_ins"
			return true
		closable
	)
preview_slot = (i, fn, save, info) ->
	bg_path = save.background.path
	img = nil
	if save.background and save.background.path
		img = lg.newImage(save.background.path)
		
	return {
		text: "Save #{i}\n#{os.date("%x %H:%M")}"
		media: img
		data: {:save, :fn, :i}
	}
slot_ui = (base_dir, existing_slot, new_slot, closable = true) ->
	choices = {}
	for i = 1, 30
		lfs.createDirectory(base_dir)
		fn = base_dir.."save#{i}.json"
		info = lfs.getInfo(fn)
		if info
			save = json.decode(lfs.read(fn))
			choice = preview_slot(i, fn, save, info)
			choice.action = existing_slot
			table.insert(choices, choice)
		else
			table.insert(choices, {
				text: "Save #{i} --"
				action: new_slot
				data: {:fn, :i}
			})
	create_listbox({:choices, :closable, :media})
