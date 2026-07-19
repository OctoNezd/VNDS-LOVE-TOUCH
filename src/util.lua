_ = require 'lib/underscore'

num = tonumber

function split(str, sep) -- splits on sep and trims each output
    sep = sep or "%s"
    local result = {}
    for s in str:gmatch("([^" .. sep .. "]+)") do
        table.insert(result, s:match("^%s*(.-)%s*$"))
    end
    return result
end

function ascii(str)
    local s = {}
    for i = 1, str:len() do
        local byte = str:byte(i)
        if byte >= 32 and byte <= 126 then
            s[#s + 1] = string.char(byte)
        end
    end
    return table.concat(s)
end

function utf8_clean(str)
    -- Strip invalid UTF-8 sequences from string
    local s = {}
    local i = 1
    local len = str:len()
    while i <= len do
        local byte = str:byte(i)
        local char_len = 1
        local valid = false

        -- Check UTF-8 byte sequences
        if byte < 0x80 then
            -- Single byte character (ASCII)
            char_len = 1
            valid = true
        elseif byte >= 0xC2 and byte <= 0xDF then
            -- 2-byte sequence
            if i + 1 <= len then
                local byte2 = str:byte(i + 1)
                if byte2 >= 0x80 and byte2 <= 0xBF then
                    char_len = 2
                    valid = true
                end
            end
        elseif byte >= 0xE0 and byte <= 0xEF then
            -- 3-byte sequence
            if i + 2 <= len then
                local byte2 = str:byte(i + 1)
                local byte3 = str:byte(i + 2)
                if byte2 >= 0x80 and byte2 <= 0xBF and byte3 >= 0x80 and byte3 <= 0xBF then
                    char_len = 3
                    valid = true
                end
            end
        elseif byte >= 0xF0 and byte <= 0xF4 then
            -- 4-byte sequence
            if i + 3 <= len then
                local byte2 = str:byte(i + 1)
                local byte3 = str:byte(i + 2)
                local byte4 = str:byte(i + 3)
                if byte2 >= 0x80 and byte2 <= 0xBF and byte3 >= 0x80 and byte3 <= 0xBF and byte4 >= 0x80 and byte4 <= 0xBF then
                    char_len = 4
                    valid = true
                end
            end
        end

        -- Add valid character to output
        if valid then
            s[#s + 1] = str:sub(i, i + char_len - 1)
            i = i + char_len
        else
            -- Skip invalid byte
            i = i + 1
        end
    end

    return table.concat(s)
end

function get(t, ...)
    for _, k in ipairs({...}) do
        t = t[k]
        if not t then return nil end
    end
    return t
end

function center(size, bounds)
    return (bounds - size) / 2
end

function deepcopy(orig) -- http://lua-users.org/wiki/CopyTable
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
