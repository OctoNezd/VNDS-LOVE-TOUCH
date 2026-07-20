local utils = require("luis.3rdparty.utils")
local Vector2D = require("luis.3rdparty.vector")
local decorators = require("luis.3rdparty.decorators")

local pointInRect = utils.pointInRect

local numberSpinner = {}

local luis -- This will store the reference to the core library
function numberSpinner.setluis(luisObj)
    luis = luisObj
end

local function drawElevatedRectangle(x, y, width, height, color, elevation, cornerRadius)
    local shadowColor = {0, 0, 0, 0.2}
    local shadowBlur = elevation * 2

    -- Draw shadow
    love.graphics.setColor(shadowColor)
    love.graphics.rectangle("fill", x - shadowBlur / 2, y - shadowBlur / 2 + elevation, width + shadowBlur,
        height + shadowBlur, cornerRadius)

    -- Draw main rectangle
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, width, height, cornerRadius)
end

-- NumberSpinner: [−] value [+]
function numberSpinner.new(min, max, value, step, width, height, onChange, row, col, customTheme)
    local buttonTheme = luis.theme.button
    local textInputTheme = luis.theme.textinput
    local spinnerTheme = customTheme or {
        buttonColor = buttonTheme.color,
        buttonHoverColor = buttonTheme.hoverColor,
        buttonPressedColor = buttonTheme.pressedColor,
        buttonTextColor = buttonTheme.textColor,
        backgroundColor = textInputTheme.backgroundColor,
        textColor = textInputTheme.textColor,
        borderColor = textInputTheme.borderColor,
        cornerRadius = buttonTheme.cornerRadius,
        elevation = buttonTheme.elevation,
        elevationHover = buttonTheme.elevationHover,
        elevationPressed = buttonTheme.elevationPressed,
        transitionDuration = buttonTheme.transitionDuration
    }

    local totalWidth = width * luis.gridSize
    local totalHeight = height * luis.gridSize
    -- Square buttons, but cap so they don't exceed 1/4 of total width each
    local btnWidth = math.min(totalHeight, math.floor(totalWidth / 4))
    local fieldWidth = totalWidth - btnWidth * 2

    return {
        type = "NumberSpinner",
        min = min,
        max = max,
        value = value,
        step = step or 1,
        width = totalWidth,
        height = totalHeight,
        onChange = onChange,
        position = Vector2D.new((col - 1) * luis.gridSize, (row - 1) * luis.gridSize),
        focused = false,
        focusable = true,
        theme = spinnerTheme,
        decorator = nil,

        -- Internal button states
        decHover = false,
        decPressed = false,
        incHover = false,
        incPressed = false,

        -- Animated colors for decrease button
        decColorR = spinnerTheme.buttonColor[1],
        decColorG = spinnerTheme.buttonColor[2],
        decColorB = spinnerTheme.buttonColor[3],
        decColorA = spinnerTheme.buttonColor[4],
        decElevation = spinnerTheme.elevation,

        -- Animated colors for increase button
        incColorR = spinnerTheme.buttonColor[1],
        incColorG = spinnerTheme.buttonColor[2],
        incColorB = spinnerTheme.buttonColor[3],
        incColorA = spinnerTheme.buttonColor[4],
        incElevation = spinnerTheme.elevation,

        -- Internal dimensions
        btnWidth = btnWidth,
        fieldWidth = fieldWidth,

        -- Hold-to-repeat state
        holdDirection = 0, -- -1 for decrease, 1 for increase, 0 for none
        holdTimer = 0,
        holdDelay = 0.4, -- initial delay before repeating (seconds)
        holdInterval = 0.08, -- interval between repeats (seconds)

        update = function(self, mx, my, dt)
            local x = self.position.x
            local y = self.position.y

            -- Hold-to-repeat: if a button is held down, keep changing value
            if self.holdDirection ~= 0 and (self.decPressed or self.incPressed) then
                self.holdTimer = self.holdTimer + dt
                if self.holdTimer >= self.holdDelay then
                    -- After initial delay, repeat at holdInterval rate
                    local repeatTime = self.holdTimer - self.holdDelay
                    local prevTicks = math.floor((repeatTime - dt) / self.holdInterval)
                    local curTicks = math.floor(repeatTime / self.holdInterval)
                    if curTicks > prevTicks then
                        self:setValue(self.value + self.step * self.holdDirection)
                    end
                end
            end

            -- Decrease button hover
            local wasDecHover = self.decHover
            self.decHover = pointInRect(mx, my, x, y, self.btnWidth, self.height)
            if self.decHover and not wasDecHover then
                luis.flux.to(self, spinnerTheme.transitionDuration, {
                    decElevation = spinnerTheme.elevationHover,
                    decColorR = spinnerTheme.buttonHoverColor[1],
                    decColorG = spinnerTheme.buttonHoverColor[2],
                    decColorB = spinnerTheme.buttonHoverColor[3],
                    decColorA = spinnerTheme.buttonHoverColor[4]
                })
            elseif not self.decHover and wasDecHover and not self.decPressed then
                luis.flux.to(self, spinnerTheme.transitionDuration, {
                    decElevation = spinnerTheme.elevation,
                    decColorR = spinnerTheme.buttonColor[1],
                    decColorG = spinnerTheme.buttonColor[2],
                    decColorB = spinnerTheme.buttonColor[3],
                    decColorA = spinnerTheme.buttonColor[4]
                })
            end

            -- Increase button hover
            local incX = x + self.btnWidth + self.fieldWidth
            local wasIncHover = self.incHover
            self.incHover = pointInRect(mx, my, incX, y, self.btnWidth, self.height)
            if self.incHover and not wasIncHover then
                luis.flux.to(self, spinnerTheme.transitionDuration, {
                    incElevation = spinnerTheme.elevationHover,
                    incColorR = spinnerTheme.buttonHoverColor[1],
                    incColorG = spinnerTheme.buttonHoverColor[2],
                    incColorB = spinnerTheme.buttonHoverColor[3],
                    incColorA = spinnerTheme.buttonHoverColor[4]
                })
            elseif not self.incHover and wasIncHover and not self.incPressed then
                luis.flux.to(self, spinnerTheme.transitionDuration, {
                    incElevation = spinnerTheme.elevation,
                    incColorR = spinnerTheme.buttonColor[1],
                    incColorG = spinnerTheme.buttonColor[2],
                    incColorB = spinnerTheme.buttonColor[3],
                    incColorA = spinnerTheme.buttonColor[4]
                })
            end
        end,

        defaultDraw = function(self)
            local x = self.position.x
            local y = self.position.y
            local cr = spinnerTheme.cornerRadius

            -- Draw decrease button [−]
            drawElevatedRectangle(x, y, self.btnWidth, self.height,
                {self.decColorR, self.decColorG, self.decColorB, self.decColorA}, self.decElevation, cr)
            love.graphics.setColor(spinnerTheme.buttonTextColor)
            love.graphics.setFont(luis.theme.text.font)
            love.graphics.printf("−", x, y + (self.height - luis.theme.text.font:getHeight()) / 2, self.btnWidth,
                "center")

            -- Draw text field (center area)
            local fieldX = x + self.btnWidth
            love.graphics.setColor(spinnerTheme.backgroundColor)
            love.graphics.rectangle("fill", fieldX, y, self.fieldWidth, self.height)
            love.graphics.setColor(spinnerTheme.borderColor)
            love.graphics.rectangle("line", fieldX, y, self.fieldWidth, self.height)
            love.graphics.setColor(spinnerTheme.textColor)
            love.graphics.setFont(luis.theme.text.font)
            love.graphics.printf(tostring(self.value), fieldX, y + (self.height - luis.theme.text.font:getHeight()) / 2,
                self.fieldWidth, "center")

            -- Draw increase button [+]
            local incX = fieldX + self.fieldWidth
            drawElevatedRectangle(incX, y, self.btnWidth, self.height,
                {self.incColorR, self.incColorG, self.incColorB, self.incColorA}, self.incElevation, cr)
            love.graphics.setColor(spinnerTheme.buttonTextColor)
            love.graphics.setFont(luis.theme.text.font)
            love.graphics.printf("+", incX, y + (self.height - luis.theme.text.font:getHeight()) / 2, self.btnWidth,
                "center")

            -- Draw focus indicator
            if self.focused then
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.rectangle("line", x - 2, y - 2, self.width + 4, self.height + 4, cr + 2)
            end
        end,

        -- Draw method that can use a decorator
        draw = function(self)
            if self.decorator then
                self.decorator:draw(self)
            else
                self:defaultDraw()
            end
        end,

        -- Method to set a decorator
        setDecorator = function(self, decoratorType, ...)
            self.decorator = decorators[decoratorType].new(self, ...)
        end,

        setValue = function(self, newValue)
            newValue = math.max(self.min, math.min(self.max, newValue))
            if newValue ~= self.value then
                self.value = newValue
                if self.onChange then
                    self.onChange(self.value)
                end
            end
        end,

        getValue = function(self)
            return self.value
        end,

        click = function(self, x, y, button, istouch, presses)
            if button ~= 1 then
                return false
            end

            local bx = self.position.x
            local by = self.position.y

            -- Decrease button clicked
            if pointInRect(x, y, bx, by, self.btnWidth, self.height) then
                self.decPressed = true
                self.holdDirection = -1
                self.holdTimer = 0
                luis.flux.to(self, spinnerTheme.transitionDuration, {
                    decElevation = spinnerTheme.elevationPressed,
                    decColorR = spinnerTheme.buttonPressedColor[1],
                    decColorG = spinnerTheme.buttonPressedColor[2],
                    decColorB = spinnerTheme.buttonPressedColor[3],
                    decColorA = spinnerTheme.buttonPressedColor[4]
                })
                self:setValue(self.value - self.step)
                return true
            end

            -- Increase button clicked
            local incX = bx + self.btnWidth + self.fieldWidth
            if pointInRect(x, y, incX, by, self.btnWidth, self.height) then
                self.incPressed = true
                self.holdDirection = 1
                self.holdTimer = 0
                luis.flux.to(self, spinnerTheme.transitionDuration, {
                    incElevation = spinnerTheme.elevationPressed,
                    incColorR = spinnerTheme.buttonPressedColor[1],
                    incColorG = spinnerTheme.buttonPressedColor[2],
                    incColorB = spinnerTheme.buttonPressedColor[3],
                    incColorA = spinnerTheme.buttonPressedColor[4]
                })
                self:setValue(self.value + self.step)
                return true
            end

            return false
        end,

        release = function(self, x, y, button, istouch, presses)
            if button ~= 1 then
                return false
            end
            local handled = false
            self.holdDirection = 0
            self.holdTimer = 0

            if self.decPressed then
                self.decPressed = false
                local targetColor = self.decHover and spinnerTheme.buttonHoverColor or spinnerTheme.buttonColor
                luis.flux.to(self, spinnerTheme.transitionDuration, {
                    decElevation = self.decHover and spinnerTheme.elevationHover or spinnerTheme.elevation,
                    decColorR = targetColor[1],
                    decColorG = targetColor[2],
                    decColorB = targetColor[3],
                    decColorA = targetColor[4]
                })
                handled = true
            end

            if self.incPressed then
                self.incPressed = false
                local targetColor = self.incHover and spinnerTheme.buttonHoverColor or spinnerTheme.buttonColor
                luis.flux.to(self, spinnerTheme.transitionDuration, {
                    incElevation = self.incHover and spinnerTheme.elevationHover or spinnerTheme.elevation,
                    incColorR = targetColor[1],
                    incColorG = targetColor[2],
                    incColorB = targetColor[3],
                    incColorA = targetColor[4]
                })
                handled = true
            end

            return handled
        end,

        -- Focus update for joystick/gamepad
        updateFocus = function(self, jx, jy)
            if math.abs(jx) > luis.deadzone then
                if jx > 0 then
                    self:setValue(self.value + self.step)
                else
                    self:setValue(self.value - self.step)
                end
            end
        end,

        -- Gamepad support
        gamepadpressed = function(self, id, btn)
            if self.focused then
                if btn == 'dpright' or btn == 'a' then
                    self:setValue(self.value + self.step)
                    return true
                elseif btn == 'dpleft' then
                    self:setValue(self.value - self.step)
                    return true
                end
            end
            return false
        end,

        gamepadreleased = function(self, id, btn)
            return false
        end
    }
end

return numberSpinner
