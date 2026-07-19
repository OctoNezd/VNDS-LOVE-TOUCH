FILECACHE = nil
local pprint = require "lib.pprint"
local script_folder_name = "script"
local function populate_filecache(base_dir, location)
    local root = base_dir .. script_folder_name .. location
    print("Scanning directory", root)
    local filesTable = love.filesystem.getDirectoryItems(root)
    for i, v in ipairs(filesTable) do
        local file = root .. "/" .. v
        -- this code is ass
        local intname
        if location == "/" then
            intname = v
        else
            intname = location:sub(2) .. "/" .. v
        end
        local info = love.filesystem.getInfo(file)
        if info then
            if info.type == "file" then
                print("Learned about file", intname)
                ---@diagnostic disable-next-line: param-type-mismatch
                FILECACHE[#FILECACHE + 1] = intname
            elseif info.type == "directory" then
                populate_filecache(base_dir, "/" .. v)
            end
        end
    end
end
local function find_script(s, script_query)
    if FILECACHE == nil then
        FILECACHE = {}                    -- Initialize the cache table if it's nil.
        print("Populating file cache...") -- Inform the user.
        populate_filecache(s.base_dir, "/")
        print("FC:")
        pprint(FILECACHE)
    end
    for _, script_file in ipairs(FILECACHE) do
        if script_file:lower() == script_query:lower() then
            return script_file
        end
    end
end

return find_script
