require "util"
local pprint = require "lib.pprint"

local find_script = require "find_script"

local function escape_pattern(text)
    return text:gsub("([^%w])", "%%%1")
end

local function read_file(s, script_file)
    local file = find_script(s, script_file)
    local scriptpath = s.base_dir .. "script/" .. file
    local data = s.fs(scriptpath)
    if data == nil then error("Cannot read " .. scriptpath .. "! Please check the scripts folder/zip") end
    data = utf8_clean(data) -- Strip non-UTF-8 characters
    local ins = {}
    for line in string.gmatch(data, "[^\n]+") do
        if line ~= '' and line:sub(1, 1) ~= "#" then
            table.insert(ins, parse(line))
        end
    end
    local labels = {}
    for i, instruction in ipairs(ins) do
        if instruction.type == "label" then
            labels[instruction.label] = i
        end
    end
    return {file = file, ins = ins, labels = labels, n = 1}
end

local function add(a, b) -- adds two strings, two ints, or an int and a string
    if a == nil then
        return b
    elseif _.any({a, b}, function(v) return type(v) == "string" end) then
        return tostring(a) .. tostring(b)
    else
        return a + b
    end
end

local function getvalue(chunks, index)
    local r = _.join(_.rest(chunks, index), " ")
    if r:sub(1, 1) == '"' then
        return {literal = r:sub(2, -2)}
    elseif num(r) ~= nil then
        return {literal = num(r)}
    else
        return {var = r}
    end
end

local function rest(chunks, i)
    return _.join(_.rest(chunks, i), " ")
end

function parse(line)
    local c = {}
    for word in line:gmatch("%S+") do table.insert(c, word) end
    c[1] = ascii(c[1] or '') -- strip non-ascii values from the instruction, since it is english
    local t = {type = c[1]}
    local extra
    if c[1] == "bgload" then
        extra = {path = "background/" .. (c[2] or ""), frames = num(c[3])}
    elseif c[1] == "setimg" then
        extra = {path = "foreground/" .. (c[2] or ""), x = num(c[3] or 0), y = num(c[4] or 0)}
    elseif c[1] == "sound" or c[1] == "music" then
        extra = {path = "sound/" .. (c[2] or ""), n = num(c[3])}
    elseif c[1] == "text" then
        extra = {text = rest(c, 2)}
    elseif c[1] == "choice" then
        extra = {choices = split(rest(c, 2), "|")}
    elseif c[1] == "gsetvar" or c[1] == "setvar" or c[1] == "if" then
        extra = {var = c[2], modifier = c[3], value = getvalue(c, 4)}
    elseif c[1] == "jump" then
        extra = {filename = c[2], label = c[3]}
    elseif c[1] == "delay" then
        extra = {frames = num(c[2])}
    elseif c[1] == "random" then
        extra = {var = c[2], low = num(c[3]), high = num(c[4])}
    elseif c[1] == "label" or c[1] == "goto" then
        extra = {label = c[2]}
    elseif c[1] == "cleartext" then
        extra = {modifier = c[2]}
    else
        extra = {}
    end
    return _.extend(t, extra)
end

local ops = {
    ["=="] = function(a, b) return a == b end,
    ["!="] = function(a, b) return a ~= b end,
    [">="] = function(a, b) return a >= b end,
    ["<="] = function(a, b) return a <= b end,
    ["<"]  = function(a, b) return a < b end,
    [">"]  = function(a, b) return a > b end,
    ["+"]  = function(a, b) return add(b, a) end,
    ["-"]  = function(a, b) return add(b, -a) end,
    ["="]  = function(a, b) return a end,
    ["~"]  = function(a, b) return nil end,
    ["if"] = 1,
    ["fi"] = -1,
}

local function mem(s, key)
    if s.locals[key] ~= nil then return s.locals else return s.globals end
end

local function mem_type(s, t)
    if t == "setvar" then return s.locals else return s.globals end
end

local function interpolate(s, text)
    for var in text:gmatch("{$([^}]*)}")  do
        text = text:gsub("{$" .. escape_pattern(var) .. "}", tostring(mem(s, var)[var]))
    end
    for var in text:gmatch("$(%S*)") do
        text = text:gsub("$" .. escape_pattern(var), tostring(mem(s, var)[var]))
    end
    return text
end

local function next_instruction(s)
    local ins = s.ins[s.n]
    if ins == nil then return s, ins end -- means novel is finished
    s.n = s.n + 1
    if ins.path then ins.path = s.base_dir .. ins.path end
    local MEM
    if ins.var then MEM = mem(s, ins.var) end
    if ins.type == "bgload" or ins.type == "setimg" or ins.type == "sound" or ins.type == "music"
        or ins.type == "delay" or ins.type == "cleartext" or ins.type == "text" or ins.type == "choice" then
        if ins.type == "text" then ins.text = interpolate(s, ins.text) end
        if ins.type == "bgload" then ins.path = interpolate(s, ins.path) end
        if ins.type == "setimg" then ins.path = interpolate(s, ins.path) end
        if ins.type == "choice" then
            ins.choices = _.map(ins.choices, function(c) return interpolate(s, c) end)
        end
        return s, ins
    elseif ins.type == "setvar" or ins.type == "gsetvar" then
        MEM = mem_type(s, ins.type)
        ins.value.literal = ins.value.literal or MEM[ins.value.var] or 0
        MEM[ins.var] = ops[ins.modifier](ins.value.literal, MEM[ins.var])
        if ins.modifier == "~" then
            for k in pairs(MEM) do MEM[k] = nil end
        end
    elseif ins.type == "random" then
        MEM[ins.var] = math.random(ins.low, ins.high)
    elseif ins.type == "if" then
        local lhs = MEM[ins.var] or 0 -- default to 0
        local rhs = ins.value.literal or MEM[ins.value.var] or 0
        if not ops[ins.modifier](lhs, rhs) then
            local count = 1
            while count > 0 do
                s.n = s.n + 1
                count = count + (ops[s.ins[s.n].type] or 0)
            end
        end
    elseif ins.type == "goto" then
        ins.label = interpolate(s, ins.label)
        s.n = s.labels[ins.label]
    elseif ins.type == "jump" then
        if ins.label ~= nil then ins.label = interpolate(s, ins.label) end
        -- add string interpolation
        ins.filename = interpolate(s, ins.filename):gsub('{', ''):gsub('}', '')
        s = _.extend(s, read_file(s, ins.filename))
        s.n = s.labels[ins.label] or s.n
    end
    return next_instruction(s)
end

local function load(base_dir, fs, data, novel_name)
    data = data or {file = "main.scr"}
    novel_name = novel_name or ""
    local s = {base_dir = base_dir, fs = fs, locals = {}, globals = {}, novel_name = novel_name}
    s = _.extend(s, read_file(s, data.file))
    _.extend(s, data)
    return s
end

local function save(s)
    return {file = s.file, locals = s.locals, globals = s.globals, n = s.n - 1}
end

local function choose(s, val)
    s.locals["selected"] = val
end

return {load = load, save = save, next_instruction = next_instruction, choose = choose}
