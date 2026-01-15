export *
_ = require 'lib/underscore'
wrap = => --credit to https://github.com/leafo/moonscript/issues/347#issuecomment-640084617
	setmetatable {_val: @},
		__index: (k) =>
			(_, ...) -> @_val=@_val[k] @_val, ...
unwrap = => @_val

num = tonumber
split = (str, sep = "%s") -> --splits on sep and trims each output
	[s\match "^%s*(.-)%s*$" for s in str\gmatch("([^#{sep}]+)")]

ascii = (str) ->
	s = {}
	for i=1, str\len!
		byte = str\byte(i)
		if byte >= 32 and byte <= 126 then
			s[#s+1] = string.char(byte)
	return table.concat(s)

utf8_clean = (str) ->
	-- Strip invalid UTF-8 sequences from string
	s = {}
	i = 1
	len = str\len!
	while i <= len
		byte = str\byte(i)
		char_len = 1
		valid = false
		
		-- Check UTF-8 byte sequences
		if byte < 0x80 then
			-- Single byte character (ASCII)
			char_len = 1
			valid = true
		elseif byte >= 0xC2 and byte <= 0xDF then
			-- 2-byte sequence
			if i + 1 <= len
				byte2 = str\byte(i + 1)
				if byte2 >= 0x80 and byte2 <= 0xBF
					char_len = 2
					valid = true
		elseif byte >= 0xE0 and byte <= 0xEF then
			-- 3-byte sequence
			if i + 2 <= len
				byte2 = str\byte(i + 1)
				byte3 = str\byte(i + 2)
				if byte2 >= 0x80 and byte2 <= 0xBF and byte3 >= 0x80 and byte3 <= 0xBF
					char_len = 3
					valid = true
		elseif byte >= 0xF0 and byte <= 0xF4 then
			-- 4-byte sequence
			if i + 3 <= len
				byte2 = str\byte(i + 1)
				byte3 = str\byte(i + 2)
				byte4 = str\byte(i + 3)
				if byte2 >= 0x80 and byte2 <= 0xBF and byte3 >= 0x80 and byte3 <= 0xBF and byte4 >= 0x80 and byte4 <= 0xBF
					char_len = 4
					valid = true
		
		-- Add valid character to output
		if valid
			s[#s+1] = str\sub(i, i + char_len - 1)
			i += char_len
		else
			-- Skip invalid byte
			i += 1
	
	return table.concat(s)

get = (t, ...) ->
	for _, k in ipairs{...} do
		t = t[k]
		if not t then return nil
	return t
center = (size, bounds) -> (bounds - size)/2
deepcopy = (orig) -> -- http://lua-users.org/wiki/CopyTable
    orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    return copy
