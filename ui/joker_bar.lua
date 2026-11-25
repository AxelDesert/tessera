-- Joker cards. drawCard() is also used by the shop screen.
--   JokerBar.trigger(slot)                   bounce + flash a card when its joker activates
--   JokerBar.update(dt)
--   JokerBar.draw(player, x, y, w)           the row of slots
--   JokerBar.drawOverlay(player)             tooltip + sell button; draw it after everything else
--   JokerBar.mousepressed(player, mx, my)    returns "sell", slot  |  true (click used)  |  nil
--   JokerBar.locked                          true while selling is not allowed (scoring, ...)
--   JokerBar.cardCenter(player, slot, x, y, w)

local Theme      = require("ui.theme")
local Screen     = require("ui.screen")
local Button     = require("ui.button")
local JokerIcons = require("ui.joker_icons")
local Fx         = require("ui.fx")
local CardFrames = require("ui.card_frames")
local DiceBoard  = require("ui.dice_board")

local JokerBar = { locked = false }

local CARD_W, CARD_H, GAP = 220, 170, 14
local SELL_H = 60

-- color of the tile behind the icon (joker.kind)
local KIND = {
    chips   = { 0.004, 0.573, 0.976 },
    mult    = { 0.996, 0.298, 0.251 },
    xmult   = { 0.56, 0.36, 0.86 },
    money   = { 0.99, 0.65, 0.15 },
    utility = { 0.20, 0.70, 0.42 },
    combo   = { 0.16, 0.36, 0.72 },
    charm   = { 0.80, 0.34, 0.62 },
    die     = { 0.22, 0.30, 0.42 },
}
local KIND_NAME = { chips = "Chips", mult = "Mult", xmult = "X Mult", money = "Money", utility = "Utility" }

local kick = {}        -- kick[slot] = 1 right after the joker fires, decays to 0
local lift = {}        -- lift[slot] = 0..1, hovered / selected cards rise
local selected = nil   -- the joker (not its slot) whose sell button is shown
local hovered = nil    -- slot under the mouse
local rects = {}       -- card rectangles of the last draw
local sellButton = Button.new("Sell", "button")

function JokerBar.trigger(slot) kick[slot] = 1 end

-- Call after a joker left the row: the other cards change slot
function JokerBar.clear() kick, lift, selected, hovered = {}, {}, nil, nil end

function JokerBar.update(dt)
    for slot, k in pairs(kick) do
        k = k - dt * 1.8
        kick[slot] = k > 0 and k or nil
    end
    for slot, r in pairs(rects) do
        local goal = (slot == hovered or (selected and r.joker == selected)) and 1 or 0
        local l = lift[slot] or 0
        lift[slot] = l + (goal - l) * math.min(1, dt * 16)
    end
end

local function slots(player, x, w)
    local n = math.max(player.max_jokers, #player.jokers)
    local cardW = math.min(CARD_W, (w - (n - 1) * GAP) / n)
    return n, cardW, x + (w - (n * cardW + (n - 1) * GAP)) / 2
end

function JokerBar.cardCenter(player, slot, x, y, w)
    local r = rects[slot]                     -- where it was drawn last
    if r then return r.x + r.w / 2, r.y + r.h / 2 end
    local _, cardW, startX = slots(player, x, w)
    return startX + (slot - 1) * (cardW + GAP) + cardW / 2, y + CARD_H / 2
end

-- One line of text, centered and shrunk to fit
local function fitted(text, cx, y, maxW)
    local font = love.graphics.getFont()
    local s = math.min(1, maxW / font:getWidth(text))
    love.graphics.print(text, math.floor(cx - font:getWidth(text) * s / 2), math.floor(y + font:getHeight() * (1 - s) / 2), 0, s, s)
end

-- Any card, with the body of its family (see card_frames.lua).
-- showDesc = bigger, and also write what it does (shop); otherwise it is in the tooltip
function JokerBar.drawCard(joker, x, y, w, h, showDesc)
    local kind = joker.kind
    local style = (kind == "combo" or kind == "charm" or kind == "die") and kind or "joker"
    local tileH = showDesc and 168 or 116
    local top = 12                                                  -- rim above the picture
    local iconS = math.min(showDesc and 5 or 4, (w - 28) / 24)      -- narrow cards get a smaller icon
    local cx, cy = math.floor(x + w / 2), y + (top + tileH) / 2
    CardFrames.draw(style, x, y, w, h, tileH, KIND[kind] or KIND.utility)

    if style == "die" then
        local s = (tileH - 46) / 188
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.ellipse("fill", cx, cy + 94 * s + 4, 84 * s, 12 * s)
        DiceBoard.drawDie(joker.id, 5, cx, cy, 0, s)
    else
        love.graphics.setColor(0, 0, 0, 0.25)
        JokerIcons.draw(joker.icon or joker.id, cx + 4, cy + 5, iconS)
        love.graphics.setColor(1, 1, 1, 1)
        JokerIcons.draw(joker.icon or joker.id, cx, cy, iconS)
    end

    local text = CardFrames.TEXT[style]
    love.graphics.setFont(showDesc and Theme.fonts.normal or Theme.fonts.small)
    love.graphics.setColor(text[1])
    fitted(joker.name, x + w / 2, y + tileH + (showDesc and 8 or 4), w - 36)
    if showDesc then
        love.graphics.setFont(Theme.fonts.small)
        love.graphics.setColor(text[2])
        love.graphics.printf(joker.desc, x + 22, y + tileH + 56, w - 44, "center")
    end
end

-- Row of all joker slots, centered in [x, x + w]
function JokerBar.draw(player, x, y, w)
    local n, cardW, startX = slots(player, x, w)
    local mx, my = Screen.mouse()
    rects, hovered = {}, nil
    JokerBar.lastY = y

    for i = 1, n do
        local cx = startX + (i - 1) * (cardW + GAP)
        local joker = player.jokers[i]
        local k = kick[i]
        if joker then
            rects[i] = { x = cx, y = y, w = cardW, h = CARD_H, joker = joker }
            if mx >= cx and mx <= cx + cardW and my >= y and my <= y + CARD_H then hovered = i end
        end
        if joker and k then
            -- punch up, wiggle, white flash that fades
            local age = 1 - k
            local s = 1 + 0.22 * k * k
            local rot = math.sin(age * 28) * 0.12 * k
            local hop = -26 * math.sin(math.min(1, age * 3) * math.pi) * k
            love.graphics.push()
            love.graphics.translate(cx + cardW / 2, y + CARD_H / 2 + hop)
            love.graphics.rotate(rot)
            love.graphics.scale(s)
            JokerBar.drawCard(joker, -cardW / 2, -CARD_H / 2, cardW, CARD_H)
            love.graphics.setBlendMode("add")
            love.graphics.setColor(1, 0.85, 0.4, 0.55 * k * k)
            love.graphics.rectangle("fill", -cardW / 2 + 4, -CARD_H / 2 + 4, cardW - 8, CARD_H - 12, 14, 14)
            love.graphics.setBlendMode("alpha")
            love.graphics.pop()
        elseif joker then
            JokerBar.drawCard(joker, cx, y - math.floor(10 * (lift[i] or 0) + 0.5), cardW, CARD_H)
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
    Theme.printf(("%d/%d"):format(#player.jokers, player.max_jokers), x, y + CARD_H + 8, w, "center")
end

local function selectedSlot()
    for i, r in pairs(rects) do
        if r.joker == selected then return i end
    end
end

local function drawTooltip(player, r, sellShown)
    local joker, f = r.joker, Theme.fonts
    local w, pad = 380, 18
    local lines = select(2, f.small:getWrap(joker.desc, w - pad * 2))
    local info = joker.info and joker.info(joker)
    local lh = f.small:getHeight()
    local h = pad + f.normal:getHeight() + #lines * lh + (info and lh or 0) + lh + pad + 4
    local x = math.max(Screen.SIDEBAR_W + 10, math.min(Screen.W - w - 10, r.x + r.w / 2 - w / 2))
    -- below the card when there is room (leaving space for the sell button), else above it
    local y = r.y + r.h + 14 + (sellShown and SELL_H + 8 or 0)
    if y + h > Screen.H - 10 then y = r.y - h - 22 end

    Theme.panel(x, y, w, h)
    local c = KIND[joker.kind] or KIND.utility
    love.graphics.setFont(f.normal)
    love.graphics.setColor(1, 1, 1, 1)
    Theme.printf(joker.name, x + pad, y + pad - 6, w - pad * 2, "center")
    local ty = y + pad + f.normal:getHeight()
    love.graphics.setFont(f.small)
    Theme.color("dim")
    Theme.printf(joker.desc, x + pad, ty, w - pad * 2, "center")
    ty = ty + #lines * lh
    if info then
        Theme.color("good")
        Theme.printf(info, x + pad, ty, w - pad * 2, "center")
        ty = ty + lh
    end
    love.graphics.setColor(c[1], c[2], c[3], 1)
    Theme.printf(KIND_NAME[joker.kind] or "", x + pad, ty + 4, w - pad * 2, "left")
    Theme.color("gold")
    Theme.printf("Sells for $" .. player:sell_value(joker), x + pad, ty + 4, w - pad * 2, "right")
end

function JokerBar.drawOverlay(player)
    local slot = selectedSlot()
    if slot and not JokerBar.locked then
        local r = rects[slot]
        sellButton.label = "Sell  $" .. player:sell_value(r.joker)
        sellButton:setRect(r.x, r.y + r.h + 6, r.w, SELL_H)
        sellButton:draw()
    end
    local r = rects[hovered or slot]
    if r then drawTooltip(player, r, slot ~= nil and not JokerBar.locked) end
end

function JokerBar.mousepressed(player, mx, my)
    local slot = selectedSlot()
    if slot and not JokerBar.locked and sellButton:hit(mx, my) then return "sell", slot end
    for _, r in pairs(rects) do
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            selected = (selected ~= r.joker) and r.joker or nil
            Fx.play(selected and "pick" or "unpick")
            return true
        end
    end
    selected = nil
end

JokerBar.HEIGHT = CARD_H

return JokerBar
