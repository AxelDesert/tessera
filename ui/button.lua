-- Minimal button: the owner sets its rectangle every frame (setRect),
-- draws it, and calls hit() on mouse clicks.

local Theme = require("ui.theme")

local Button = {}
Button.__index = Button

-- style: "button" (green), "button_red" or "button_orange"
function Button.new(label, style)
    return setmetatable({ label = label, style = style or "button", x = 0, y = 0, w = 0, h = 0, enabled = true }, Button)
end

function Button:setRect(x, y, w, h)
    self.x, self.y, self.w, self.h = x, y, w, h
end

-- Pure hit test: the caller decides what a click on a disabled button means
function Button:hit(mx, my)
    return mx >= self.x and mx <= self.x + self.w and my >= self.y and my <= self.y + self.h
end

function Button:draw()
    -- pressed look: the button sinks into its bottom lip
    local dy = (self.enabled and love.mouse.isDown(1) and self:hit(love.mouse.getPosition())) and 2 or 0
    Theme.box(self.x, self.y + dy, self.w, self.h, self.enabled and self.style or "disabled")
    Theme.color("text")
    love.graphics.setFont(Theme.fonts.normal)
    local th = Theme.fonts.normal:getHeight()
    local lip = 3 * Theme.SCALE
    Theme.printf(self.label, self.x, self.y + dy + (self.h - lip - th) / 2, self.w, "center")
end

return Button
