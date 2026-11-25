-- Shop logic only (no drawing): jokers, special dice and one-use cards for sale, buying, rerolling.
-- The screen is in ui/shop_screen.lua.

local Jokers      = require("core.jokers")
local DiceTypes   = require("core.dice_types")
local Consumables = require("core.consumables")

local Shop = {}
Shop.__index = Shop

Shop.CONFIG = {
    offers      = 3,    -- jokers on sale at once
    cards       = 3,    -- one-use cards: first a combo card, then a charm, then either
    reroll_cost = 5,
}

function Shop.new(player, config)
    local self = setmetatable({}, Shop)
    self.player = player
    self.cfg = setmetatable(config or {}, { __index = Shop.CONFIG })
    self.offer_count = self.cfg.offers + player:perk("extra_offers")
    self.offers = {}    -- joker definition, or false once sold
    self.extra_count = 1 + self.cfg.cards + player:perk("extra_cards")
    self.extras = {}    -- special die, then one-use cards; false once sold
    self:restock()
    return self
end

-- Picks random jokers the player does not own yet
function Shop:restock()
    local pool = {}
    for _, joker in ipairs(Jokers.LIST) do
        if not self.player:has_joker(joker.id) then pool[#pool + 1] = joker end
    end
    for i = #pool, 2, -1 do                      -- shuffle
        local k = math.random(i)
        pool[i], pool[k] = pool[k], pool[i]
    end
    self.offers = {}
    for i = 1, math.min(self.offer_count, #pool) do
        self.offers[i] = pool[i]
    end

    self.extras = { DiceTypes.random() }
    local seen = {}
    for i = 2, self.extra_count do
        local card
        repeat card = Consumables.random(i == 2 and "combo" or i == 3 and "charm" or nil) until not seen[card.id]
        seen[card.id] = true
        self.extras[i] = card
    end
end

-- Prices after joker perks
function Shop:price(joker)
    if joker.kind == "die" then return joker.price end
    if joker.kind == "combo" or joker.kind == "charm" then
        return math.max(1, joker.price - self.player:perk("card_discount"))
    end
    return math.max(1, joker.price - self.player:perk("discount"))
end

function Shop:reroll_cost()
    return math.max(0, self.cfg.reroll_cost - self.player:perk("reroll_discount"))
end

-- Returns true, or false + a reason
function Shop:buy(index)
    local joker = self.offers[index]
    if not joker then return false, "Already sold" end
    if not self.player:has_joker_room() then return false, "No free joker slot" end
    local cost = self:price(joker)
    if not self.player:spend_money(cost) then return false, "Not enough money" end
    self.player:add_joker(joker).paid = cost
    self.offers[index] = false
    return true
end

-- Second row: slot = which of the six dice to replace (special dice only)
function Shop:buy_extra(index, slot)
    local item = self.extras[index]
    if not item then return false, "Already sold" end
    if item.kind == "die" then
        if not slot then return false, "Choose a die" end
        if self.player.dice[slot] == item.id then return false, "That die is already a " .. item.name end
    elseif not self.player:has_consumable_room() then
        return false, "No free card slot"
    end
    if not self.player:spend_money(self:price(item)) then return false, "Not enough money" end
    if item.kind == "die" then self.player.dice[slot] = item.id else self.player:add_consumable(item) end
    self.extras[index] = false
    return true
end

function Shop:reroll()
    if not self.player:spend_money(self:reroll_cost()) then return false, "Not enough money" end
    self.player.stats.rerolls = self.player.stats.rerolls + 1
    self:restock()
    return true
end

return Shop
