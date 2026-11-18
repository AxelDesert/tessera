-- Cash-out screen: shown when a floor is cleared, before the shop.
-- Lists what the player earned line by line (like Balatro), then a "Cash out" button.
--   CashoutScreen.new(payout, player)   payout = fm.lastPayout
--   screen:update(dt)                   reveals one line every REVEAL seconds
--   screen:draw(x, y, w)
--   screen:advance()                    1st call shows every line, then returns "next"
--   screen:mousepressed(mx, my)         returns "next" when the player cashes out

local Theme  = require("ui.theme")
local Button = require("ui.button")

local CashoutScreen = {}
CashoutScreen.__index = CashoutScreen

local ROW_H, REVEAL = 58, 0.45

function CashoutScreen.new(payout, player)
    local self = setmetatable({}, CashoutScreen)
    self.lines, self.total, self.player = payout.lines, payout.total, player
    self.shown, self.timer = 0, 0.5
    self.button = Button.new("Cash out", "button_orange")
    return self
end

function CashoutScreen:done()
    return self.shown >= #self.lines
end

function CashoutScreen:update(dt)
    if self:done() then return end
    self.timer = self.timer - dt
    if self.timer <= 0 then
        self.shown, self.timer = self.shown + 1, REVEAL
    end
end

function CashoutScreen:advance()
    if not self:done() then
        self.shown = #self.lines
        return nil
    end
    return "next"
end

function CashoutScreen:draw(x, y, w)
    local f = Theme.fonts
    local pw = math.min(900, w - 40)
    local ph = 150 + #self.lines * ROW_H + 130
    local px, py = x + (w - pw) / 2, y + 50
    Theme.panel(px, py, pw, ph)

    love.graphics.setFont(f.big)
    Theme.color("gold")
    Theme.printf("FLOOR CLEARED", px, py + 24, pw, "center")

    love.graphics.setFont(f.normal)
    local lx, rx = px + 40, px + pw - 40
    local dotW = f.normal:getWidth(". ")
    local ry = py + 118
    for i = 1, self.shown do
        local line = self.lines[i]
        local amount = "+$" .. line.amount
        local lw, aw = f.normal:getWidth(line.label), f.normal:getWidth(amount)

        Theme.color(line.kind == "joker" and "orange" or "text")
        Theme.print(line.label, lx, ry)
        local dots = math.floor((rx - aw - lx - lw - 28) / dotW)
        if dots > 0 then
            Theme.color("dim", 0.45)
            Theme.print(string.rep(". ", dots), lx + lw + 14, ry)
        end
        Theme.color("gold")
        Theme.print(amount, rx - aw, ry)
        ry = ry + ROW_H
    end

    -- cash out button (gray until every line is shown)
    local bw, bh = 560, 84
    self.button.label = ("Cash out  $%d"):format(self.total)
    self.button.enabled = self:done()
    self.button:setRect(px + (pw - bw) / 2, py + ph - bh - 30, bw, bh)
    self.button:draw()
end

function CashoutScreen:mousepressed(mx, my)
    if self.button:hit(mx, my) then return self:advance() end
end

return CashoutScreen
