-- Shop screen (drawing + clicks). The rules are in shop.lua.
-- Buttons get their rectangle while drawing, so draw() and mousepressed()
-- always agree on where things are.

local Theme    = require("ui.theme")
local Button   = require("ui.button")
local JokerBar = require("ui.joker_bar")

local ShopScreen = {}
ShopScreen.__index = ShopScreen

local CARD_W, CARD_H, GAP = 200, 120, 24

function ShopScreen.new(shop, player, reward)
    local self = setmetatable({}, ShopScreen)
    self.shop, self.player, self.reward = shop, player, reward
    self.notice = ""
    self.nextButton = Button.new("Next floor  [SPACE]", "button")
    self.rerollButton = Button.new("Reroll", "button_red")
    self.buyButtons = {}
    for i = 1, shop.cfg.offers do self.buyButtons[i] = Button.new("Buy", "button_orange") end
    return self
end

function ShopScreen:draw(x, y, w)
    local f = Theme.fonts
    local shop, player = self.shop, self.player

    love.graphics.setFont(f.big)
    Theme.color("gold")
    Theme.printf("SHOP", x, y, w, "center")
    love.graphics.setFont(f.normal)
    Theme.color("good")
    Theme.printf(("Floor cleared!  +$%d"):format(self.reward), x, y + 52, w, "center")

    -- offers
    local n = shop.cfg.offers
    local startX = x + (w - (n * CARD_W + (n - 1) * GAP)) / 2
    local cy = y + 100
    for i = 1, n do
        local cx = startX + (i - 1) * (CARD_W + GAP)
        local joker, btn = shop.offers[i], self.buyButtons[i]
        if joker then
            JokerBar.drawCard(joker, cx, cy, CARD_W, CARD_H)
            btn.label = "Buy  $" .. joker.price
            btn.enabled = player:can_afford(joker.price) and player:has_joker_room()
            btn:setRect(cx, cy + CARD_H + 8, CARD_W, 40)
            btn:draw()
        else
            Theme.box(cx, cy, CARD_W, CARD_H, "inset")
            love.graphics.setFont(f.normal)
            Theme.color("dim", 0.6)
            Theme.printf("SOLD", cx, cy + CARD_H / 2 - 12, CARD_W, "center")
            btn:setRect(-1, -1, 0, 0)   -- not clickable
        end
    end

    -- reroll / next floor
    local ry = cy + CARD_H + 68
    local rx = x + (w - 480) / 2
    self.rerollButton.label = ("Reroll  $%d"):format(shop.cfg.reroll_cost)
    self.rerollButton.enabled = player:can_afford(shop.cfg.reroll_cost)
    self.rerollButton:setRect(rx, ry, 200, 44)
    self.rerollButton:draw()
    self.nextButton:setRect(rx + 220, ry, 260, 44)
    self.nextButton:draw()

    love.graphics.setFont(f.small)
    Theme.color("bad")
    Theme.printf(self.notice, x, ry + 54, w, "center")

    -- jokers the player already owns
    love.graphics.setFont(f.small)
    Theme.color("dim")
    Theme.printf("Your jokers", x, ry + 84, w, "center")
    JokerBar.draw(player, x, ry + 108, w)
end

-- Returns "next" when the player wants to leave the shop
function ShopScreen:mousepressed(mx, my)
    if self.nextButton:hit(mx, my) then return "next" end

    if self.rerollButton:hit(mx, my) then
        local ok, err = self.shop:reroll()
        self.notice = ok and "" or err
        return
    end

    for i, btn in ipairs(self.buyButtons) do
        if btn:hit(mx, my) then
            local ok, err = self.shop:buy(i)
            self.notice = ok and "" or err
            return
        end
    end
end

return ShopScreen
