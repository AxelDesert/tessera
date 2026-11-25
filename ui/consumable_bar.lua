-- Row of one-use cards (rules in core/consumables.lua).
--   ConsumableBar.draw(player, x, y, w)            the slots, centered in [x, x + w]
--   ConsumableBar.drawOverlay(player)              tooltip + use / sell buttons, after everything else
--   ConsumableBar.mousepressed(player, mx, my)     "use", slot, track | "sell", slot | true | nil
--   ConsumableBar.keypressed(player, key)          same; 1-9 pick a card, U / M use it
--   ConsumableBar.clear()                          unselect
--   ConsumableBar.locked                           true while cards cannot be used

local Theme    = require("ui.theme")
local Screen   = require("ui.screen")
local Button   = require("ui.button")
local JokerBar = require("ui.joker_bar")
local Fx       = require("ui.fx")

local Bar = { locked = false, HEIGHT = 170 }

local CARD_W, GAP, BTN_H = 150, 14, 58
local selected, hovered
local rects = {}
local useBtn   = Button.new("Use [U]", "button")
local chipsBtn = Button.new("Chips [U]", "chips")
local multBtn  = Button.new("Mult [M]", "button_red")
local sellBtn  = Button.new("Sell", "button_orange")

function Bar.clear() selected = nil end

local function selectedSlot(player)
    for i, c in ipairs(player.consumables) do if c == selected then return i end end
end

function Bar.center(slot)
    local r = rects[slot]
    if not r then return Screen.W / 2, Screen.H - 200 end
    return r.x + r.w / 2, r.y + r.h / 2
end

function Bar.draw(player, x, y, w)
    local n = math.max(player:consumable_slots(), #player.consumables)
    local cw = math.min(CARD_W, (w - (n - 1) * GAP) / n)
    local sx = x + (w - n * cw - (n - 1) * GAP) / 2
    local mx, my = Screen.mouse()
    rects, hovered = {}, nil
    for i = 1, n do
        local cx, c = sx + (i - 1) * (cw + GAP), player.consumables[i]
        if c then
            rects[i] = { x = cx, y = y, w = cw, h = Bar.HEIGHT }
            if mx >= cx and mx <= cx + cw and my >= y and my <= y + Bar.HEIGHT then hovered = i end
            JokerBar.drawCard(c, cx, y - ((hovered == i or c == selected) and 10 or 0), cw, Bar.HEIGHT)
        else
            Theme.box(cx, y, cw, Bar.HEIGHT, "inset")
            love.graphics.setFont(Theme.fonts.small)
            Theme.color("dim", 0.5)
            love.graphics.printf("card", cx, y + Bar.HEIGHT / 2 - 17, cw, "center")
        end
    end
end

local function buttons(card)
    return card.kind == "combo" and { chipsBtn, multBtn, sellBtn } or { useBtn, sellBtn }
end

function Bar.drawOverlay(player)
    local slot = selectedSlot(player)
    local shown = hovered or slot
    local r = rects[shown]
    if not r then return end
    local card = player.consumables[shown]
    if not card then return end

    local top = r.y - 10
    if slot and not Bar.locked and rects[slot] then
        local sr, sc = rects[slot], player.consumables[slot]
        if sc.combo then
            chipsBtn.label = ("+%d Chips [U]"):format(sc.combo.up.chips)
            multBtn.label  = ("+%d Mult [M]"):format(sc.combo.up.mult)
        end
        sellBtn.label = "Sell $" .. player:consumable_value(sc)
        local list, total = buttons(sc), 0
        local widths = sc.combo and { 260, 240, 160 } or { 160, 160 }
        for _, bw in ipairs(widths) do total = total + bw + 8 end
        local bx = math.max(Screen.SIDEBAR_W + 10, math.min(Screen.W - total - 10, sr.x + sr.w / 2 - total / 2))
        for i, b in ipairs(list) do
            b:setRect(bx, sr.y - BTN_H - 14, widths[i], BTN_H)
            b:draw()
            bx = bx + widths[i] + 8
        end
        top = sr.y - BTN_H - 18
    end

    local f, w, pad = Theme.fonts, 400, 16
    local _, lines = f.small:getWrap(card.desc, w - pad * 2)
    local lh = f.small:getHeight()
    local extra = card.combo and ("Level %d"):format(player:combo_level(card.combo.id)) or "Charm"
    local h = pad * 2 + f.normal:getHeight() + (#lines + 1) * lh
    local tx = math.max(Screen.SIDEBAR_W + 10, math.min(Screen.W - w - 10, r.x + r.w / 2 - w / 2))
    local ty = top - h - 6
    Theme.panel(tx, ty, w, h)
    love.graphics.setFont(f.normal)
    Theme.color("text")
    Theme.printf(card.name, tx, ty + pad - 6, w, "center")
    love.graphics.setFont(f.small)
    Theme.color("dim")
    Theme.printf(card.desc, tx + pad, ty + pad + f.normal:getHeight() - 4, w - pad * 2, "center")
    Theme.color("gold")
    Theme.printf(extra, tx + pad, ty + h - pad - lh, w - pad * 2, "center")
end

function Bar.mousepressed(player, mx, my)
    local slot = selectedSlot(player)
    if slot and not Bar.locked then
        if sellBtn:hit(mx, my) then return "sell", slot end
        if selected.kind == "combo" then
            if chipsBtn:hit(mx, my) then return "use", slot, "chips" end
            if multBtn:hit(mx, my) then return "use", slot, "mult" end
        elseif useBtn:hit(mx, my) then
            return "use", slot
        end
    end
    for i, r in pairs(rects) do
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            local c = player.consumables[i]
            selected = selected ~= c and c or nil
            Fx.play(selected and "pick" or "unpick")
            return true
        end
    end
end

function Bar.keypressed(player, key)
    local card = player.consumables[tonumber(key) or 0]
    if card then
        selected = selected ~= card and card or nil
        Fx.play(selected and "pick" or "unpick")
        return true
    end
    local slot = selectedSlot(player)
    if not slot or Bar.locked then return end
    if key == "u" then return "use", slot, selected.kind == "combo" and "chips" or nil end
    if key == "m" and selected.kind == "combo" then return "use", slot, "mult" end
end

return Bar
