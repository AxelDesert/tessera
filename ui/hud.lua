-- Floor information block (top of the left sidebar).

local Theme = require("ui.theme")

local HUD = {}
HUD.HEIGHT = 170

function HUD.draw(fm, player, roundScore, x, y, w)
    local f = Theme.fonts
    local boss = fm:is_boss(fm.floor)
    Theme.panel(x, y, w, HUD.HEIGHT)

    love.graphics.setFont(f.normal)
    Theme.color(boss and "bad" or "gold")
    love.graphics.print(("Floor %d / %d%s"):format(fm.floor, fm.cfg.total_floors, boss and "  BOSS" or ""),
        x + 14, y + 10)

    -- progress bar: banked score (green) + points of the current round (gold)
    local bx, by, bw, bh = x + 14, y + 46, w - 28, 16
    Theme.box(bx, by, bw, bh, "disabled", 5)
    local function fill(color, ratio, alpha)
        local fw = bw * math.min(1, ratio)
        if fw < 1 then return end
        Theme.color(color, alpha)
        love.graphics.rectangle("fill", bx, by, fw, bh, math.min(5, fw / 2), math.min(5, fw / 2))
    end
    fill("gold", (fm.score + roundScore) / fm.target, 0.6)
    fill("good", fm.score / fm.target)

    love.graphics.setFont(f.small)
    Theme.color("text")
    love.graphics.print(("Score        %d / %d"):format(fm.score, fm.target), x + 14, y + 70)
    love.graphics.print(("This round  +%d"):format(roundScore), x + 14, y + 92)
    love.graphics.print(("Rounds left  %d"):format(fm.rounds_left), x + 14, y + 114)
    Theme.color("gold")
    love.graphics.print(("Money  $%d"):format(player.money), x + 14, y + 136)
end

return HUD
