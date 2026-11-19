-- Cash-out screen: shown when a floor is cleared, before the shop.
-- Lists what the player earned line by line (like Balatro), then a "Cash out" button.
--   CashoutScreen.new(payout, player)   payout = fm.lastPayout
--   screen:update(dt)                   reveals one line every REVEAL seconds
--   screen:draw(x, y, w)
--   screen:advance()                    1st call shows every line, then returns "next"
--   screen:mousepressed(mx, my)         returns "next" when the player cashes out

local Theme  = require("ui.theme")
local Button = require("ui.button")
local Fx     = require("ui.fx")

local CashoutScreen = {}
CashoutScreen.__index = CashoutScreen

local ROW_H, REVEAL, DROP_TIME = 58, 0.45, 0.45

local function easeOutBack(x)
    local c1, c3 = 1.7, 2.7
    return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

function CashoutScreen.new(payout, player)
    local self = setmetatable({}, CashoutScreen)
    self.lines, self.total, self.player = payout.lines, payout.total, player
    self.shown, self.timer, self.age = 0, 0.7, 0
    self.lineAge = {}
    self.sum = Fx.counter(0)               -- the "Cash out $N" total counts up as lines appear
    self.button = Button.new("Cash out", "button_orange")
    return self
end

function CashoutScreen:done()
    return self.shown >= #self.lines
end

-- reveal line i: coin sound, sparks on its amount, the total counts up
function CashoutScreen:reveal(i, quiet)
    self.shown = i
    self.lineAge[i] = 0
    local revealed = 0
    for n = 1, i do revealed = revealed + self.lines[n].amount end
    self.sum:set(revealed)
    if not quiet then
        Fx.play("coin", 1 + 0.08 * (i - 1))
        if self.geom then
            local g = self.geom
            Fx.burst(g.rx - 30, g.ry + (i - 1) * ROW_H + 20, Theme.colors.gold, 14, 300)
        end
    end
    if self:done() and not quiet then Fx.play("score") end
end

function CashoutScreen:update(dt)
    self.age = self.age + dt
    for i, a in pairs(self.lineAge) do self.lineAge[i] = a + dt end
    if self.sum:update(dt) then Fx.play("tick", 1.2) end
    if self:done() then return end
    self.timer = self.timer - dt
    if self.timer <= 0 then
        self:reveal(self.shown + 1)
        self.timer = REVEAL
    end
end

function CashoutScreen:advance()
    if not self:done() then
        for i = self.shown + 1, #self.lines do self:reveal(i, true) end
        self.sum:snap(self.total)
        Fx.play("score")
        return nil
    end
    return "next"
end

function CashoutScreen:draw(x, y, w)
    local f = Theme.fonts
    local pw = math.min(900, w - 40)
    local ph = 150 + #self.lines * ROW_H + 130
    -- panel drops in from above with a little overshoot
    local drop = easeOutBack(math.min(1, self.age / DROP_TIME))
    local px, py = x + (w - pw) / 2, y + 50 - (1 - drop) * 700
    Theme.panel(px, py, pw, ph)

    -- title, gently breathing
    love.graphics.setFont(f.big)
    Theme.color("gold")
    local s = 1 + 0.04 * math.sin(self.age * 3)
    local tw = f.big:getWidth("FLOOR CLEARED")
    Theme.print("FLOOR CLEARED", px + pw / 2, py + 24 + f.big:getHeight() / 2, 0, s, s,
        math.floor(tw / 2), math.floor(f.big:getHeight() / 2))

    love.graphics.setFont(f.normal)
    local lx, rx = px + 40, px + pw - 40
    local dotW = f.normal:getWidth(". ")
    local ry = py + 118
    self.geom = { rx = rx, ry = ry }
    for i = 1, self.shown do
        local line = self.lines[i]
        local amount = "+$" .. line.amount
        local lw, aw = f.normal:getWidth(line.label), f.normal:getWidth(amount)
        local age = self.lineAge[i] or 1
        local slide = (1 - math.min(1, age / 0.25)) * 40       -- slides in from the left
        local la = math.min(1, age / 0.2)

        Theme.color(line.kind == "joker" and "orange" or "text", la)
        Theme.print(line.label, lx - slide, ry)
        local dots = math.floor((rx - aw - lx - lw - 28) / dotW)
        if dots > 0 then
            Theme.color("dim", 0.45 * la)
            Theme.print(string.rep(". ", dots), lx + lw + 14 - slide, ry)
        end
        -- the amount punches in
        local ps = 1 + 0.6 * math.max(0, 1 - age * 4)
        Theme.color("gold", la)
        Theme.print(amount, rx - aw / 2, ry + f.normal:getHeight() / 2, 0, ps, ps,
            math.floor(aw / 2), math.floor(f.normal:getHeight() / 2))
        ry = ry + ROW_H
    end

    -- cash out button (gray until every line is shown), pulses once it is ready
    local bw, bh = 560, 84
    local bx, by = px + (pw - bw) / 2, py + ph - bh - 30
    self.button.label = ("Cash out  $%d"):format(self.sum.value)
    self.button.enabled = self:done()
    if self:done() then
        local pulse = 0.5 + 0.5 * math.sin(self.age * 5)
        love.graphics.setBlendMode("add")
        Theme.color("gold", 0.18 + 0.2 * pulse)
        love.graphics.rectangle("fill", bx - 8 - 6 * pulse, by - 8 - 6 * pulse, bw + 16 + 12 * pulse, bh + 12 + 12 * pulse, 18, 18)
        love.graphics.setBlendMode("alpha")
    end
    self.button:setRect(bx, by, bw, bh)
    self.button:draw()
end

function CashoutScreen:mousepressed(mx, my)
    if self.button:hit(mx, my) then return self:advance() end
end

return CashoutScreen
