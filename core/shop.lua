-- Shop logic only (no drawing): which jokers are for sale, buying, rerolling.
-- The screen is in ui/shop_screen.lua.

local Jokers = require("core.jokers")

local Shop = {}
Shop.__index = Shop

Shop.CONFIG = {
    offers      = 3,    -- jokers on sale at once
    reroll_cost = 5,
}

function Shop.new(player, config)
    local self = setmetatable({}, Shop)
    self.player = player
    self.cfg = setmetatable(config or {}, { __index = Shop.CONFIG })
    self.offers = {}    -- joker definition, or false once sold
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
    for i = 1, math.min(self.cfg.offers, #pool) do
        self.offers[i] = pool[i]
    end
end

-- Returns true, or false + a reason
function Shop:buy(index)
    local joker = self.offers[index]
    if not joker then return false, "Already sold" end
    if not self.player:has_joker_room() then return false, "No free joker slot" end
    if not self.player:spend_money(joker.price) then return false, "Not enough money" end
    self.player:add_joker(joker)
    self.offers[index] = false
    return true
end

function Shop:reroll()
    if not self.player:spend_money(self.cfg.reroll_cost) then return false, "Not enough money" end
    self:restock()
    return true
end

return Shop
