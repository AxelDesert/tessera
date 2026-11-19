-- Joker cards. drawCard() is also used by the shop screen.
--   JokerBar.trigger(slot)                   bounce + flash a card when its joker activates
--   JokerBar.update(dt)
--   JokerBar.cardCenter(player, slot, x, y, w)

local Theme = require("ui.theme")

local JokerBar = {}

local CARD_W, CARD_H, GAP = 220, 170, 14

local kick = {}   -- kick[slot] = 1 right after the joker fires, decays to 0

function JokerBar.trigger(slot) kick[slot] = 1 end

function JokerBar.update(dt)
    for slot, k in pairs(kick) do
        k = k - dt * 1.8
        kick[slot] = k > 0 and k or nil
    end
end

local function slots(player, x, w)
    local n = player.max_jokers
    local cardW = math.min(CARD_W, (w - (n - 1) * GAP) / n)
    return n, cardW, x + (w - (n * cardW + (n - 1) * GAP)) / 2
end

function JokerBar.cardCenter(player, slot, x, y, w)
    local _, cardW, startX = slots(player, x, w)
    return startX + (slot - 1) * (cardW + GAP) + cardW / 2, y + CARD_H / 2
end

function JokerBar.drawCard(joker, x, y, w, h)
    Theme.box(x, y, w, h, "card")
    love.graphics.setFont(Theme.fonts.small)
    Theme.color("mult")
    love.graphics.printf(joker.name, x + 10, y + 12, w - 20, "center")
    Theme.color("ink")
    love.graphics.printf(joker.desc, x + 10, y + 54, w - 20, "center")
end

-- Row of all joker slots, centered in [x, x + w]
function JokerBar.draw(player, x, y, w)
    local n, cardW, startX = slots(player, x, w)

    for i = 1, n do
        local cx = startX + (i - 1) * (cardW + GAP)
        local joker = player.jokers[i]
        local k = kick[i]
        if joker and k then
            -- punch up, wiggle, white flash that fades
            local age = 1 - k
            local s = 1 + 0.22 * k * k
            local rot = math.sin(age * 28) * 0.12 * k
            local lift = -26 * math.sin(math.min(1, age * 3) * math.pi) * k
            love.graphics.push()
            love.graphics.translate(cx + cardW / 2, y + CARD_H / 2 + lift)
            love.graphics.rotate(rot)
            love.graphics.scale(s)
            JokerBar.drawCard(joker, -cardW / 2, -CARD_H / 2, cardW, CARD_H)
            love.graphics.setBlendMode("add")
            love.graphics.setColor(1, 0.85, 0.4, 0.55 * k * k)
            love.graphics.rectangle("fill", -cardW / 2 + 4, -CARD_H / 2 + 4, cardW - 8, CARD_H - 12, 14, 14)
            love.graphics.setBlendMode("alpha")
            love.graphics.pop()
        elseif joker then
            JokerBar.drawCard(joker, cx, y, cardW, CARD_H)
        else
            Theme.box(cx, y, cardW, CARD_H, "inset")
            love.graphics.setFont(Theme.fonts.small)
            Theme.color("dim", 0.5)
            love.graphics.printf("empty", cx, y + CARD_H / 2 - 17, cardW, "center")
        end
    end

    -- "3/5" under the row, like Balatro
    love.graphics.setFont(Theme.fonts.small)
    Theme.color("text")
    Theme.printf(("%d/%d"):format(#player.jokers, n), x, y + CARD_H + 8, w, "center")
end

JokerBar.HEIGHT = CARD_H

return JokerBar
