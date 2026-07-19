local puremagic = require "lib/puremagic"

local sound = {}
local music = {}
local sound_volume, music_volume = nil, nil
local filetype = {
    ["audio/x-aiff"] = "file.aiff",
    ["audio/x-flac"] = "file.flac",
    ["audio/mp4"] = "file.m4a",
    ["audio/x-matroska"] = "file.mka",
    ["audio/mpeg"] = "file.mp3",
    ["audio/vorbis"] = "file.ogg",
    ["audio/ogg"] = "file.ogg",
    ["audio/x-wav"] = "file.wav",
    ["audio/webm"] = "file.webm",
    ["audio/x-ms-wma"] = "file.wma",
}

local function load_source(path)
    local success, source = pcall(love.audio.newSource, path, "stream")
    if success then return source end
    local mime = puremagic.via_path(path)
    if filetype[mime] == nil then return nil end
    local original = lfs.newFileData(path)
    local actual = lfs.newFileData(original:getString(), filetype[mime])
    return love.audio.newSource(actual, "stream")
end

local function clear(t)
    if next(t) then
        t.file:stop()
        -- clear the table in-place
        for k in pairs(t) do t[k] = nil end
    end
end

local function exists(path)
    return path:sub(-1) ~= "~"
end

on("config", function(self)
    sound_volume = self.audio.sound / 100
    music_volume = self.audio.music / 100
    if next(sound) then sound.file:setVolume(sound_volume) end
    if next(music) then music.file:setVolume(music_volume) end
end)

on("save", function(self)
    self.music = {path = music.path}
    self.sound = {path = sound.path, n = sound.n}
end)

on("restore", function(self)
    clear(music)
    clear(sound)
    if get(self, "music", "path") then dispatch("music", self.music) end
    if get(self, "sound", "path") then dispatch("sound", self.sound) end
end)

on("sound", function(self)
    clear(sound)
    if exists(self.path) then
        local file = load_source(self.path)
        if file == nil then return end
        file:setLooping(self.n == -1)
        file:setVolume(sound_volume)
        file:play()
        sound = {path = self.path, file = file, n = self.n or 0}
        dispatch("sfx", sound)
    else
        print("SFX", self.path, "not found!")
    end
end)

on("music", function(self)
    clear(music)
    if exists(self.path) then
        local file = load_source(self.path)
        if file == nil then return end
        file:setLooping(true)
        file:setVolume(music_volume)
        file:play()
        music = {path = self.path, file = file}
    else
        print("Music file", self.path, "not found!")
    end
end)

on("update", function()
    if next(sound) and not sound.file:isPlaying() and sound.n > 1 then
        sound.file:play()
        sound.n = sound.n - 1
    end
end)
