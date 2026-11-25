-- Shop screen (drawing + clicks). The rules are in shop.lua.
-- Buttons get their rectangle while drawing, so draw() and mousepressed()
-- always agree on where things are.

local Theme    = require("ui.theme")
local Button   = require("ui.button")
local JokerBar = require("ui.joker_bar")
local Fx       = require("ui.fx")
local Screen   = require("ui.screen")
local DiceBoard = require("ui.dice_board")
local DiceTypes = require("core.dice_types")
local ConsumableBar = require("ui.consumable_bar")

local ShopScreen = {}
ShopScreen.__index = ShopScreen

local CARD_W, CARD_H, GAP, BTN_H = 300, 236, 28, 52

function ShopScreen.new(shop, player, reward)
    local self = setmetatable({}, ShopScreen)
    self.shop, self.player, self.reward = shop, player, reward
    self.notice = ""
    self.nextButton = Button.new("Next floor  [SPACE]", "button")
    self.rerollButton = Button.new("Reroll", "button_red")
    self.buyButtons = {}
    for i = 1, shop.offer_count do self.buyButtons[i] = Button.new("Buy", "button_orange") end
    self.extraButtons = {}
    for i = 1, shop.extra_count do self.extraButtons[i] = Button.new("Buy", "button_orange") end
    self.cancelButton = Button.new("Cancel  [ESC]", "button_red")
    self.placing = nil          -- index of the special die being placed
    return self
end

-- One row of things for sale
function ShopScreen:drawRow(items, buttons, n, x, y, w)
    local shop, player = self.shop, self.player
    local cw = math.min(CARD_W, (w - (n - 1) * GAP) / n)
    local startX = x + (w - (n * cw + (n - 1) * GAP)) / 2
    for i = 1, n do
        local cx = startX + (i - 1) * (cw + GAP)
        local item, btn = items[i], buttons[i]
        if item then
            local room = true
            if item.kind == "combo" or item.kind == "charm" then room = player:has_consumable_room()
            elseif item.kind ~= "die" then room = player:has_joker_room() end
            JokerBar.drawCard(item, cx, y, cw, CARD_H, true)
            btn.label = "Buy  $" .. shop:price(item)
            btn.enabled = room and player:can_afford(shop:price(item))
            btn:setRect(cx, y + CARD_H + 6, cw, BTN_H)
            btn:draw()
        else
            Theme.box(cx, y, cw, CARD_H, "inset")
            love.graphics.setFont(Theme.fonts.normal)
            Theme.color("dim", 0.6)
            Theme.printf("SOLD", cx, y + CARD_H / 2 - 20, cw, "center")
            btn:setRect(-1, -1, 0, 0)   -- not clickable
        end
    end
end

function ShopScreen:draw(x, y, w)
    local f = Theme.fonts
    local shop, player = self.shop, self.player

    love.graphics.setFont(f.big)
    Theme.color("gold")
    Theme.printf("SHOP", x, y - 14, w, "center")
    love.graphics.setFont(f.small)
    Theme.color("good")
    Theme.printf(("Floor cleared!  +$%d"):format(self.reward), x + w - 420, y + 6, 410, "right")
    for i = 1, 6 do DiceBoard.drawDie(player.dice[i], i, x + 40 + (i - 1) * 60, y + 24, 0, 0.25) end

    local y1 = y + 54
    local y2 = y1 + CARD_H + BTN_H + 16
    self:drawRow(shop.offers, self.buyButtons, shop.offer_count, x, y1, w)
    self:drawRow(shop.extras, self.extraButtons, shop.extra_count, x, y2, w)

    -- reroll / next floor
    local ry = y2 + CARD_H + BTN_H + 18
    local rx = x + (w - 720) / 2
    self.rerollButton.label = ("Reroll  $%d"):format(shop:reroll_cost())
    self.rerollButton.enabled = player:can_afford(shop:reroll_cost())
    self.rerollButton:setRect(rx, ry, 300, 62)
    self.rerollButton:draw()
    self.nextButton:setRect(rx + 330, ry, 390, 62)
    self.nextButton:draw()

    -- what the player owns
    local by = ry + 112
    love.graphics.setFont(f.small)
    if self.notice ~= "" then
        Theme.color("gold")
        Theme.printf(self.notice, x, ry + 66, w, "center")
    else
        Theme.color("dim")
        Theme.printf("Your jokers  (click to sell)", x, ry + 66, w - 510, "center")
        Theme.printf("Your cards  (click to use)", x + w - 490, ry + 66, 490, "center")
    end
    JokerBar.draw(player, x, by, w - 510)
    ConsumableBar.draw(player, x + w - 490, by, 490)
end

-- "Which die do you replace?" on top of everything
function ShopScreen:drawOverlay()
    if not self.placing then return end
    local f, player = Theme.fonts, self.player
    local item = self.shop.extras[self.placing]
    love.graphics.setColor(0, 0, 0, 0.75)
    Screen.fill()
    local w, h = 1240, 480
    local x, y = Screen.SIDEBAR_W + (Screen.W - Screen.SIDEBAR_W - w) / 2, (Screen.H - h) / 2
    Theme.panel(x, y, w, h)
    love.graphics.setFont(f.normal)
    Theme.color("gold")
    Theme.printf("Replace which die with the " .. item.name .. "?", x, y + 22, w, "center")
    love.graphics.setFont(f.small)
    Theme.color("dim")
    Theme.printf(item.desc, x, y + 70, w, "center")
    local mx, my = Screen.mouse()
    self.dieRects = {}
    for i = 1, 6 do
        local cx, cy = x + w / 2 + (i - 3.5) * 196, y + 220
        local r = { x = cx - 90, y = cy - 90, w = 180, h = 220 }
        self.dieRects[i] = r
        local over = mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
        DiceBoard.drawDie(over and item.id or player.dice[i], i, cx, cy - (over and 10 or 0), 0, 0.8)
        love.graphics.setFont(f.small)
        Theme.color(over and "gold" or "text")
        Theme.printf((DiceTypes.get(player.dice[i]).name:gsub(" Die", "")) .. "  [" .. i .. "]", cx - 98, cy + 92, 196, "center")
    end
    self.cancelButton:setRect(x + w / 2 - 150, y + h - 96, 300, 66)
    self.cancelButton:draw()
end

function ShopScreen:place(slot)
    local ok, err = self.shop:buy_extra(self.placing, slot)
    self.notice = ok and "" or err
    if ok then
        Fx.burst(Screen.W / 2 + Screen.SIDEBAR_W / 2, Screen.H / 2, Theme.colors.gold, 40, 520)
        Fx.play("joker")
    end
    self.placing = nil
end

-- Returns true when the key was used by the die picker
function ShopScreen:keypressed(key)
    if not self.placing then return false end
    local n = tonumber(key)
    if key == "escape" then self.placing = nil
    elseif n and n >= 1 and n <= 6 then self:place(n) end
    return true
end

-- Click while the die picker is open; true when it was open
function ShopScreen:overlayPressed(mx, my)
    if not self.placing then return false end
    if self.cancelButton:hit(mx, my) then self.placing = nil return true end
    for i, r in ipairs(self.dieRects or {}) do
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then self:place(i) break end
    end
    return true
end

-- Returns "next" when the player wants to leave the shop
function ShopScreen:mousepressed(mx, my)
    if self.nextButton:hit(mx, my) then return "next" end

    if self.rerollButton:hit(mx, my) then
        local ok, err = self.shop:reroll()
        self.notice = ok and "" or err
        return
    end

    local function bought(ok, err, btn)
        self.notice = ok and "" or err
        if ok then
            Fx.burst(btn.x + btn.w / 2, btn.y, Theme.colors.gold, 24, 420)
            Fx.play("coin")
        end
        return ok
    end
    for i, btn in ipairs(self.buyButtons) do
        if btn:hit(mx, my) then
            -- the new card pops into its slot
            local ok, err = self.shop:buy(i)
            if bought(ok, err, btn) then JokerBar.trigger(#self.player.jokers) end
            return
        end
    end
    for i, btn in ipairs(self.extraButtons) do
        if btn:hit(mx, my) then
            local item = self.shop.extras[i]
            if item.kind == "die" then
                if self.player:can_afford(self.shop:price(item)) then self.placing, self.notice = i, ""
                else self.notice = "Not enough money" end
            else
                local ok, err = self.shop:buy_extra(i)
                bought(ok, err, btn)
            end
            return
        end
    end
end

return ShopScreen
