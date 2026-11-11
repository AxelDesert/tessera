-- "How much is each combination worth?" overlay.
-- Built from Combos.LIST, so it always matches the real values.

local Combos = require("core.combos")
local Theme  = require("ui.theme")

local ComboHelp = { open = false }

function ComboHelp.toggle()
    ComboHelp.open = not ComboHelp.open
end

function ComboHelp.draw()
    if not ComboHelp.open then return end
    local f = Theme.fonts
    local w, h = love.graphics.getDimensions()

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local rowH = 32
    local pw, ph = math.min(860, w - 40), 185 + #Combos.LIST * rowH
    local px, py = (w - pw) / 2, math.max(10, (h - ph) / 2)
    Theme.panel(px, py, pw, ph)

    local colName, colDice = px + 24, px + pw * 0.30
    local colChips, colMult = px + pw * 0.52, px + pw * 0.86

    love.graphics.setFont(f.normal)
    Theme.color("gold")
    love.graphics.printf("COMBINATIONS", px, py + 14, pw, "center")

    local y = py + 56
    love.graphics.setFont(f.small)
    Theme.color("dim")
    love.graphics.print("Combination", colName, y)
    love.graphics.print("Example", colDice, y)
    love.graphics.print("Chips", colChips, y)
    love.graphics.print("Mult", colMult, y)
    y = y + 28

    for _, c in ipairs(Combos.LIST) do
        Theme.color("text")
        love.graphics.print(c.name, colName, y)
        Theme.color("dim")
        love.graphics.print(table.concat(c.example, " "), colDice, y)
        Theme.color("chips")
        love.graphics.print("+" .. (c.chipsLabel or tostring(c.chips)), colChips, y)
        Theme.color("mult")
        love.graphics.print("+" .. c.mult, colMult, y)
        y = y + rowH
    end

    Theme.color("dim")
    love.graphics.printf(
        "Score = Chips x Mult.  Mult starts at 1 and each combo adds its Mult.\n" ..
        "Every selected die must be part of a combo.  Jokers trigger after the combos, left to right.",
        px + 20, y + 8, pw - 40, "center")
    love.graphics.printf("H / ESC / click to close", px, py + ph - 26, pw, "center")
end

return ComboHelp
