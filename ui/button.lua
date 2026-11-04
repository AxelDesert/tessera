-- Minimal button: the owner sets its rectangle every frame (setRect),
-- draws it, and calls hit() on mouse clicks.

local Theme = require("ui.theme")

local Button = {}
Button.__index = Button

function Button.new(label)
    return setmetatable({ label = label, x = 0, y = 0, w = 0, h = 0, enabled = true }, Button)
end

function Button:setRect(x, y, w, h)
    self.x, self.y, self.w, self.h = x, y, w, h
end

-- Pure hit test: the caller decides what a click on a disabled button means
function Button:hit(mx, my)
    return mx >= self.x and mx <= self.x + self.w and my >= self.y and my <= self.y + self.h
end

function Button:draw()
    Theme.box(self.x, self.y, self.w, self.h, self.enabled and "button" or "disabled")
    Theme.color("text")
    love.graphics.setFont(Theme.fonts.normal)
    local th = Theme.fonts.normal:getHeight()
    love.graphics.printf(self.label, self.x, self.y + (self.h - th) / 2, self.w, "center")
end

return Button
