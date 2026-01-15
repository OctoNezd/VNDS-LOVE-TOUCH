gridui_active = false
local function create_gridui(items, MEDIA_HEIGHT)
    gridui_active = true
    local scroll_offset = 0
    local old_scroll_offset = 0
    local scroll_active = false
    local scroll_locked = false
    local scrolled = false
    local scroll_min = 0
    local scroll_max = 0
    local TEXT_HEIGHT = love.graphics.getFont():getHeight("AAA")

    -- Calculate scroll bounds
    local rows = math.ceil(#items / 3)
    local total_height = rows * (MEDIA_HEIGHT + TEXT_HEIGHT + pad) + pad * 4
    local screen_height = love.graphics.getHeight()
    scroll_max = 0
    scroll_min = math.min(0, -(total_height - screen_height))

    -- Lock scrolling if content fits on screen
    if total_height < screen_height then
        scroll_locked = true
    end

    -- Forward declare close function
    local close
    local drawEvt, mousePressedEvt, mouseReleasedEvt, mouseMovedEvt
    local width = love.graphics.getWidth()
    drawEvt = on("draw_gridui", function()
        local item_width = width / 3 - pad * 4
        local total_grid_width = item_width * 3 + pad * 2
        local start_x = (width - total_grid_width) / 2
        for idx = 1, #items do
            local item = items[idx]
            local item_x = start_x + (item_width + pad) * math.fmod(idx - 1, 3)
            local item_y = scroll_offset + pad * 4 + (MEDIA_HEIGHT + TEXT_HEIGHT + pad) * math.floor((idx - 1) / 3)

            -- Store bounds for click detection
            item._bounds = {
                x = item_x,
                y = item_y,
                width = item_width,
                height = MEDIA_HEIGHT + TEXT_HEIGHT
            }
            -- Draw thumb property fitted inside the rectangle
            if item.thumb ~= nil then
                local image = item.thumb
                local thumb_width = image:getWidth()
                local thumb_height = image:getHeight()
                local scale_x = item_width / thumb_width
                local scale_y = MEDIA_HEIGHT / thumb_height
                local scale = math.min(scale_x, scale_y)
                local draw_width = thumb_width * scale
                local draw_height = thumb_height * scale
                local offset_x = (item_width - draw_width) / 2
                local offset_y = (MEDIA_HEIGHT - draw_height) / 2
                love.graphics.draw(image, item_x + offset_x, item_y + offset_y + 3, 0, scale, scale)
            end
            -- Draw media property on top of thumb, fitted inside the rectangle
            if item.media ~= nil then
                local image = item.media
                local media_width = image:getWidth()
                local media_height = image:getHeight()
                local scale = 1
                if media_height > MEDIA_HEIGHT or media_width > media_width then
                    local scale_x = item_width / media_width
                    local scale_y = MEDIA_HEIGHT / media_height
                    scale = math.min(scale_x, scale_y)
                end
                local draw_width = media_width * scale
                local draw_height = media_height * scale
                local offset_x = (item_width - draw_width) / 2
                local offset_y = (MEDIA_HEIGHT - draw_height) / 2
                love.graphics.draw(image, item_x + offset_x, item_y + offset_y, 0, scale, scale)
            end
            love.graphics.print(item.text, item_x, item_y + MEDIA_HEIGHT)
            love.graphics.rectangle("line", item_x, item_y, item_width, MEDIA_HEIGHT + TEXT_HEIGHT)
        end
    end)
    mousePressedEvt = on("gridui_mp", function(x, y, button, istouch)
        scroll_active = true
    end)
    mouseReleasedEvt = on("gridui_mr", function(x, y, button, istouch)
        scroll_active = false
        if not scrolled and button == 1 then
            -- Check if any item was clicked
            for idx = 1, #items do
                local item = items[idx]
                if item._bounds then
                    local bounds = item._bounds
                    if x >= bounds.x and x <= bounds.x + bounds.width and y >= bounds.y and y <= bounds.y +
                        bounds.height then
                        -- Item was clicked, call its action if it exists
                        if item.action then
                            item.action(item)
                            close()
                        end
                        break
                    end
                end
            end
        end
        scrolled = false
    end)
    mouseMovedEvt = on("gridui_mm", function(x, y, dx, dy)
        if scroll_active and not scroll_locked then
            local new_offset = scroll_offset + dy

            -- Clamp scroll offset to valid range
            if new_offset < scroll_min then
                scroll_offset = scroll_min
            elseif new_offset > scroll_max then
                scroll_offset = scroll_max
            else
                scroll_offset = new_offset
            end

            scrolled = true
        end
    end)
    close = function()
        drawEvt:remove()
        mousePressedEvt:remove()
        mouseReleasedEvt:remove()
        mouseMovedEvt:remove()
        gridui_active = false
    end
end

return create_gridui
