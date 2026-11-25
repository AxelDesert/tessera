-- "How much is each combination worth?" overlay.
-- Built from Combos.LIST, so it always matches the real values.

local Combos = require("core.combos")
local Theme  = require("ui.theme")
local Screen = require("ui.screen")

local ComboHelp = { open = false, levels = nil }   -- levels = player.levels, set by main

function ComboHelp.toggle()
    ComboHelp.open = not ComboHelp.open
end

function ComboHelp.draw()
    if not ComboHelp.open then return end
    local f = Theme.fonts
    local w, h = Screen.W, Screen.H

    love.graphics.setColor(0, 0, 0, 0.75)
    Screen.fill()

    local rowH = 44
    local pw, ph = math.min(1300, w - 40), 270 + #Combos.LIST * rowH
    local px, py = (w - pw) / 2, math.max(10, (h - ph) / 2)
    Theme.panel(px, py, pw, ph)

    local colName, colDice = px + 24, px + pw * 0.30
    local colChips, colMult = px + pw * 0.50, px + pw * 0.83
    local colLevel = px + pw * 0.92

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
    Theme.print("Lv", colLevel, y)
    y = y + 46

    for _, c in ipairs(Combos.LIST) do
        local lv = ComboHelp.levels and ComboHelp.levels[c.id] or { chips = 0, mult = 0 }
        local level, plus = 1 + lv.chips + lv.mult, lv.chips * c.up.chips
        local chips = c.chipsLabel and (c.chipsLabel .. (plus > 0 and " +" .. plus or "")) or tostring(c.chips + plus)
        Theme.color(level > 1 and "gold" or "text")
        Theme.print(tostring(level), colLevel, y)
        Theme.print(c.name, colName, y)
        Theme.color("dim")
        Theme.print(table.concat(c.example, " "), colDice, y)
        Theme.color("chips")
        Theme.print("+" .. chips, colChips, y)
        Theme.color("mult")
        Theme.print("+" .. (c.mult + lv.mult * c.up.mult), colMult, y)
        y = y + rowH
    end

    Theme.color("dim")
    Theme.printf(
        "Score = Chips x Mult.  Mult starts at 1 and each combo adds its Mult.\n" ..
        "Every selected die must be part of a combo.  Special dice trigger next, then Jokers, left to right.",
        px + 20, y + 14, pw - 40, "center")
    Theme.printf("H / ESC / click to close", px, py + ph - 44, pw, "center")
end

return ComboHelp
