-- Joker cards. drawCard() is also used by the shop screen.

local Theme = require("ui.theme")

local JokerBar = {}

local CARD_W, CARD_H, GAP = 220, 170, 14

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
