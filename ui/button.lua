-- Minimal button: the owner sets its rectangle every frame (setRect),
-- draws it, and calls hit() on mouse clicks (game coordinates, see screen.lua).
-- style: "button" (green), "button_red" or "button_orange". The label may have several lines.

local Theme  = require("ui.theme")
local Screen = require("ui.screen")

local Button = {}
Button.__index = Button

local LIP = 8   -- height of the darker bottom edge of the sprite

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
    -- pressed look: the button sinks into its bottom edge
    local mx, my = Screen.mouse()
    local dy = (self.enabled and love.mouse.isDown(1) and self:hit(mx, my)) and 4 or 0
    Theme.box(self.x, self.y + dy, self.w, self.h, self.enabled and self.style or "disabled")
    Theme.color("text")
    local font = Theme.fonts.normal
    love.graphics.setFont(font)
    local _, lines = font:getWrap(self.label, self.w - 16)
    local th = #lines * font:getHeight()
    Theme.printf(self.label, self.x + 8, self.y + dy + (self.h - LIP - th) / 2, self.w - 16, "center")
end

return Button
