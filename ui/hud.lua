-- Floor information block (top of the left sidebar).

local Theme = require("ui.theme")

local HUD = {}
HUD.HEIGHT = 184

function HUD.draw(fm, player, roundScore, x, y, w)
    local f = Theme.fonts
    local boss = fm:is_boss(fm.floor)
    Theme.panel(x, y, w, HUD.HEIGHT)

    -- title bar (red on boss floors)
    Theme.box(x + 8, y + 8, w - 16, 36, boss and "mult" or "header")
    love.graphics.setFont(f.normal)
    Theme.color("text")
    Theme.printf(("Floor %d / %d%s"):format(fm.floor, fm.cfg.total_floors, boss and "  BOSS" or ""),
        x + 8, y + 8 + (36 - 6 - f.normal:getHeight()) / 2, w - 16, "center")

    -- progress bar: banked score (green) + points of the current round (gold)
    local bx, by, bw, bh = x + 14, y + 52, w - 28, 22
    Theme.box(bx, by, bw, bh, "inset")
    local function fill(color, ratio, alpha)
        local fw = (bw - 8) * math.min(1, ratio)
        if fw < 1 then return end
        Theme.color(color, alpha)
        love.graphics.rectangle("fill", bx + 4, by + 4, fw, bh - 8, 2, 2)
    end
    fill("gold", (fm.score + roundScore) / fm.target, 0.6)
    fill("good", fm.score / fm.target)

    love.graphics.setFont(f.small)
    Theme.color("text")
    Theme.print(("Score        %d / %d"):format(fm.score, fm.target), x + 14, y + 82)
    Theme.print(("This round  +%d"):format(roundScore), x + 14, y + 104)
    Theme.print(("Rounds left  %d"):format(fm.rounds_left), x + 14, y + 126)
    Theme.color("gold")
    Theme.print(("Money  $%d"):format(player.money), x + 14, y + 148)
end

return HUD
