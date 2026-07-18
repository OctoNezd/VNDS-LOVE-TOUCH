local function mount_game(base_dir)
    print("loading zips under", base_dir)
    for i, v in ipairs({ "background.zip", "foreground.zip", "script.zip", "sound.zip" }) do
        local source = base_dir .. v
        local zip_exists = love.filesystem.getInfo(source) ~= nil
        print("checking", source, zip_exists)
        if zip_exists then
            local destination = base_dir .. v:sub(1, -5) .. '/'
            local abs_source = source:gsub("/documents", love.filesystem.getFullCommonPath("userdocuments"))
            abs_source = abs_source:gsub("^/work_around_symlink_bug/", love.filesystem.getSourceBaseDirectory() .. "/")
            local mountres = love.filesystem.mountFullPath(abs_source, base_dir)
            print("mount res for", source, "to", destination, ":", mountres)
            if (not mountres) then
                error("Failed to mount " .. v .. ". Please check your zip files")
            end
        end
    end
end

return mount_game
