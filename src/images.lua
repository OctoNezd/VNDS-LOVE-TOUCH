local Timer = require 'lib/timer'

local background = {}
local images = {}
local alpha = {value = 1}

on("save", function(self)
    self.background = {path = background.path}
    self.images = _.map(images, function(img)
        return {path = img.path, x = img.x, y = img.y}
    end)
end)

on("restore", function(self)
    background = {}
    images = {}
    alpha = {value = 1}
    if get(self, "background", "path") then dispatch("bgload", self.background) end
    if self.images then
        for _, image in ipairs(self.images) do
            dispatch("setimg", image)
        end
    end
end)

on("bgload", function(self)
    background = {}
    if self.path:sub(-1) == "~" then return end
    if self.frames ~= nil then
        alpha.value = 0
        Timer.tween(self.frames / 60, {[alpha] = {value = 1}})
    end
    background = {path = self.path, img = lg.newImage(self.path)}
    local w, h = background.img:getDimensions()
    if w ~= original_width or h ~= original_height then
        original_width = w
        original_height = h
        love.resize(lg.getWidth(), lg.getHeight())
    end
    images = {}
end)

on("setimg", function(self)
    table.insert(images, {path = self.path, img = lg.newImage(self.path), x = self.x, y = self.y})
end)

on("draw_background", function()
    lg.setColor(1, 1, 1, alpha.value)
    local scale = math.min(sx, sy)
    if next(background) then
        lg.draw(background.img, lg.getWidth() / 2, lg.getHeight() / 2, 0, scale, scale,
            background.img:getWidth() / 2, background.img:getHeight() / 2)
    end
end)

on("draw_foreground", function()
    local scale = math.min(sx, sy)
    local pscale = math.min(px, py)
    local offsetX = lg.getWidth() / 2 - original_width * scale / 2
    local offsetY = lg.getHeight() / 2 - original_height * scale / 2
    _.each(images, function(img)
        lg.draw(img.img, img.x * pscale + offsetX, img.y * pscale + offsetY, 0, scale, scale)
    end)
end)
