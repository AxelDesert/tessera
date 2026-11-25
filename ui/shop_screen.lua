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

local CARD_W, CARD_H, GAP, BTN_H = 320, 344, 36, 60
local TAB_W, TAB_H = 330, 72

local TABS = {
    joker = { label = "Jokers",       style = "button_red" },
    die   = { label = "Special dice", style = "button" },
    card  = { label = "Cards",        style = "chips" },
}

local lastTab = "joker"      -- remembered from shop to shop

function ShopScreen.new(shop, player, reward)
    local self = setmetatable({}, ShopScreen)
    self.shop, self.player, self.reward = shop, player, reward
    self.notice = ""
    self.tab = lastTab
    self.nextButton = Button.new("Next floor  [SPACE]", "button")
    self.rerollButton = Button.new("Reroll", "button_red")
    self.tabButtons, self.buyButtons = {}, {}
    for _, id in ipairs(shop.TABS) do
        self.tabButtons[id] = Button.new(TABS[id].label, TABS[id].style)
        self.buyButtons[id] = {}
        for i = 1, shop.count[id] do self.buyButtons[id][i] = Button.new("Buy", "button_orange") end
    end
    self.cancelButton = Button.new("Cancel  [ESC]", "button_red")
    self.placing = nil          -- index of the special die being placed
    return self
end

function ShopScreen:setTab(id)
    if id == self.tab then return end
    self.tab, lastTab, self.notice = id, id, ""
    ConsumableBar.clear()
    Fx.play("hover")
end

function ShopScreen:cycleTab(d)
    local list = self.shop.TABS
    for i, id in ipairs(list) do
        if id == self.tab then return self:setTab(list[(i - 1 + d) % #list + 1]) end
    end
end

function ShopScreen:drawTabs(x, y, w)
    local list = self.shop.TABS
    local tx = x + (w - #list * TAB_W - (#list - 1) * 12) / 2
    for _, id in ipairs(list) do
        local b, active = self.tabButtons[id], id == self.tab
        b.style = active and TABS[id].style or "disabled"
        b.label = ("%s  (%d)"):format(TABS[id].label, self.shop:left(id))
        b:setRect(tx, active and y - 8 or y, TAB_W, TAB_H)
        b:draw()
        if active then
            local ax, ay = tx + TAB_W / 2, y + TAB_H + 2
            Theme.color("gold")
            love.graphics.polygon("fill", ax - 16, ay, ax + 16, ay, ax, ay + 14)
        end
        tx = tx + TAB_W + 12
    end
end

function ShopScreen:drawStock(x, y, w)
    local shop, tab = self.shop, self.tab
    local n = shop.count[tab]
    local cw = math.min(CARD_W, (w - (n - 1) * GAP) / n)
    local startX = x + (w - (n * cw + (n - 1) * GAP)) / 2
    for i = 1, n do
        local cx = startX + (i - 1) * (cw + GAP)
        local item, btn = shop.stock[tab][i], self.buyButtons[tab][i]
        if item then
            JokerBar.drawCard(item, cx, y, cw, CARD_H, true)
            btn.label = "Buy  $" .. shop:price(item)
            btn.enabled = shop:has_room(tab) and self.player:can_afford(shop:price(item))
            btn:setRect(cx, y + CARD_H + 12, cw, BTN_H)
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

    self:drawTabs(x, y + 66, w)
    local y1 = y + 166
    self:drawStock(x, y1, w)

    -- reroll / next floor
    local ry = y1 + CARD_H + BTN_H + 36
    local rx = x + (w - 780) / 2
    self.rerollButton.label = ("Reroll %s  $%d"):format(TABS[self.tab].label:lower(), shop:reroll_cost())
    self.rerollButton.enabled = player:can_afford(shop:reroll_cost())
    self.rerollButton:setRect(rx, ry, 390, 66)
    self.rerollButton:draw()
    self.nextButton:setRect(rx + 410, ry, 370, 66)
    self.nextButton:draw()

    -- what the player owns
    local by = 826
    love.graphics.setFont(f.small)
    if self.notice ~= "" then
        Theme.color("gold")
        Theme.printf(self.notice, x, by - 44, w, "center")
    else
        Theme.color("dim")
        Theme.printf("Your jokers  (click to sell)", x, by - 44, w - 510, "center")
        Theme.printf("Your cards  (click to use)", x + w - 490, by - 44, 490, "center")
    end
    JokerBar.draw(player, x, by, w - 510)
    ConsumableBar.draw(player, x + w - 490, by, 490)
end

-- "Which die do you replace?" on top of everything
function ShopScreen:drawOverlay()
    if not self.placing then return end
    local f, player = Theme.fonts, self.player
    local item = self.shop.stock.die[self.placing]
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
    local ok, err = self.shop:buy("die", self.placing, slot)
    self.notice = ok and "" or err
    if ok then
        Fx.burst(Screen.W / 2 + Screen.SIDEBAR_W / 2, Screen.H / 2, Theme.colors.gold, 40, 520)
        Fx.play("joker")
    end
    self.placing = nil
end

-- Returns true when the key was used: tabs (Q / E, arrows, TAB) or the die picker
function ShopScreen:keypressed(key)
    if not self.placing then
        if key == "tab" or key == "e" or key == "d" or key == "right" then self:cycleTab(1) return true end
        if key == "q" or key == "a" or key == "left" then self:cycleTab(-1) return true end
        return false
    end
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

    for id, b in pairs(self.tabButtons) do
        if b:hit(mx, my) then self:setTab(id) return end
    end

    local shop, tab = self.shop, self.tab
    if self.rerollButton:hit(mx, my) then
        local ok, err = shop:reroll(tab)
        self.notice = ok and "" or err
        if ok then Fx.play("coin") end
        return
    end

    for i, btn in ipairs(self.buyButtons[tab]) do
        local item = shop.stock[tab][i]
        if item and btn:hit(mx, my) then
            if tab == "die" then             -- choose which die to replace first
                local rich = self.player:can_afford(shop:price(item))
                self.notice = rich and "" or "Not enough money"
                if rich then self.placing = i end
                return
            end
            local ok, err = shop:buy(tab, i)
            self.notice = ok and "" or err
            if ok then
                if tab == "joker" then JokerBar.trigger(#self.player.jokers) end   -- pops into its slot
                Fx.burst(btn.x + btn.w / 2, btn.y, Theme.colors.gold, 24, 420)
                Fx.play("coin")
            end
            return
        end
    end
end

return ShopScreen
