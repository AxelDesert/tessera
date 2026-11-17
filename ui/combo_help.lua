-- "How much is each combination worth?" overlay.
-- Built from Combos.LIST, so it always matches the real values.

local Combos = require("core.combos")
local Theme  = require("ui.theme")
local Screen = require("ui.screen")

local ComboHelp = { open = false }

function ComboHelp.toggle()
    ComboHelp.open = not ComboHelp.open
end

function ComboHelp.draw()
    if not ComboHelp.open then return end
    local f = Theme.fonts
    local w, h = Screen.W, Screen.H

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local rowH = 44
    local pw, ph = math.min(1300, w - 40), 270 + #Combos.LIST * rowH
    local px, py = (w - pw) / 2, math.max(10, (h - ph) / 2)
    Theme.panel(px, py, pw, ph)

    local colName, colDice = px + 24, px + pw * 0.30
    local colChips, colMult = px + pw * 0.52, px + pw * 0.86

    love.graphics.setFont(f.normal)
    Theme.color("gold")
    Theme.printf("COMBINATIONS", px, py + 18, pw, "center")

    local y = py + 86
    love.graphics.setFont(f.small)
    Theme.color("dim")
    Theme.print("Combination", colName, y)
    Theme.print("Example", colDice, y)
    Theme.print("Chips", colChips, y)
    Theme.print("Mult", colMult, y)
    y = y + 46

    for _, c in ipairs(Combos.LIST) do
        Theme.color("text")
        Theme.print(c.name, colName, y)
        Theme.color("dim")
        Theme.print(table.concat(c.example, " "), colDice, y)
        Theme.color("chips")
        Theme.print("+" .. (c.chipsLabel or tostring(c.chips)), colChips, y)
        Theme.color("mult")
        Theme.print("+" .. c.mult, colMult, y)
        y = y + rowH
    end

    Theme.color("dim")
    Theme.printf(
        "Score = Chips x Mult.  Mult starts at 1 and each combo adds its Mult.\n" ..
        "Every selected die must be part of a combo.  Jokers trigger after the combos, left to right.",
        px + 20, y + 14, pw - 40, "center")
    Theme.printf("H / ESC / click to close", px, py + ph - 44, pw, "center")
end

return ComboHelp
