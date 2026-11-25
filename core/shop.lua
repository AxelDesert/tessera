-- Shop logic only (no drawing): jokers, special dice and one-use cards for sale, buying, rerolling.
-- The screen is in ui/shop_screen.lua.

local Jokers      = require("core.jokers")
local DiceTypes   = require("core.dice_types")
local Consumables = require("core.consumables")

local Shop = {}
Shop.__index = Shop

-- Categories, in tab order
Shop.TABS = { "joker", "die", "card" }

Shop.CONFIG = {
    joker       = 3,    -- how many of each are on sale
    die         = 3,
    card        = 3,    -- first a combo card, then a charm, then either
    reroll_cost = 5,    -- restocks one category
}

function Shop.new(player, config)
    local self = setmetatable({}, Shop)
    self.player = player
    self.cfg = setmetatable(config or {}, { __index = Shop.CONFIG })
    self.count = {
        joker = self.cfg.joker + player:perk("extra_offers"),
        die   = self.cfg.die,
        card  = self.cfg.card + player:perk("extra_cards"),
    }
    self.stock = {}     -- stock[tab][i] = definition, or false once sold
    for _, tab in ipairs(Shop.TABS) do self:restock(tab) end
    return self
end

-- First n of a shuffled copy
local function pick(list, n)
    local pool = {}
    for i, v in ipairs(list) do pool[i] = v end
    for i = #pool, 2, -1 do
        local k = math.random(i)
        pool[i], pool[k] = pool[k], pool[i]
    end
    local out = {}
    for i = 1, math.min(n, #pool) do out[i] = pool[i] end
    return out
end

function Shop:restock(tab)
    local n = self.count[tab]
    if tab == "joker" then           -- only jokers the player does not own yet
        local pool = {}
        for _, joker in ipairs(Jokers.LIST) do
            if not self.player:has_joker(joker.id) then pool[#pool + 1] = joker end
        end
        self.stock.joker = pick(pool, n)
    elseif tab == "die" then
        self.stock.die = pick(DiceTypes.LIST, n)
    else
        local list, seen = {}, {}
        for i = 1, n do
            local card
            repeat card = Consumables.random(i == 1 and "combo" or i == 2 and "charm" or nil) until not seen[card.id]
            seen[card.id] = true
            list[i] = card
        end
        self.stock.card = list
    end
end

-- How many things of a category are still for sale
function Shop:left(tab)
    local n = 0
    for _, item in ipairs(self.stock[tab]) do if item then n = n + 1 end end
    return n
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

-- Is there a free slot for this category?
function Shop:has_room(tab)
    if tab == "joker" then return self.player:has_joker_room() end
    if tab == "card" then return self.player:has_consumable_room() end
    return true
end

-- slot = which of the six dice to replace (special dice only). Returns true, or false + a reason
function Shop:buy(tab, index, slot)
    local item, player = self.stock[tab][index], self.player
    if not item then return false, "Already sold" end
    if not self:has_room(tab) then return false, tab == "joker" and "No free joker slot" or "No free card slot" end
    if tab == "die" then
        if not slot then return false, "Choose a die" end
        if player.dice[slot] == item.id then return false, "That die is already a " .. item.name end
    end
    local cost = self:price(item)
    if not player:spend_money(cost) then return false, "Not enough money" end
    if tab == "joker" then player:add_joker(item).paid = cost
    elseif tab == "die" then player.dice[slot] = item.id
    else player:add_consumable(item) end
    self.stock[tab][index] = false
    return true
end

function Shop:reroll(tab)
    if not self.player:spend_money(self:reroll_cost()) then return false, "Not enough money" end
    self.player.stats.rerolls = self.player.stats.rerolls + 1
    self:restock(tab)
    return true
end

return Shop
