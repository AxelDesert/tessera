-- Joker cards. drawCard() is also used by the shop screen.

local Theme = require("ui.theme")

local JokerBar = {}

local CARD_W, CARD_H, GAP = 150, 104, 10

function JokerBar.drawCard(joker, x, y, w, h)
    Theme.box(x, y, w, h, "card")
    love.graphics.setFont(Theme.fonts.small)
    Theme.color("mult")
    love.graphics.printf(joker.name, x + 8, y + 8, w - 16, "center")
    Theme.color("ink")
    love.graphics.printf(joker.desc, x + 8, y + 34, w - 16, "center")
end

-- Row of all joker slots, centered in [x, x + w]
function JokerBar.draw(player, x, y, w)
    local n = player.max_jokers
    local cardW = math.min(CARD_W, (w - (n - 1) * GAP) / n)
    local startX = x + (w - (n * cardW + (n - 1) * GAP)) / 2

    for i = 1, n do
        local cx = startX + (i - 1) * (cardW + GAP)
        local joker = player.jokers[i]
        if joker then
            JokerBar.drawCard(joker, cx, y, cardW, CARD_H)
        else
            Theme.box(cx, y, cardW, CARD_H, "inset")
            love.graphics.setFont(Theme.fonts.small)
            Theme.color("dim", 0.6)
            love.graphics.printf("empty", cx, y + CARD_H / 2 - 9, cardW, "center")
        end
    end
end

JokerBar.HEIGHT = CARD_H

return JokerBar
