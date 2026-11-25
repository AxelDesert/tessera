local Player = {}
Player.__index = Player

function Player.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Player)
    self.money          = opts.money or 0
    self.floors_cleared  = 0
    self.alive          = true
    self.escaped        = false
    self.jokers         = {}
    self.stats          = { farkles = 0, rerolls = 0, sold = 0 }   -- this run, for jokers
    self.max_jokers     = opts.max_jokers or 5
    -- Placeholder dice/relics/etc
    self.dice           = {}
    self.relics         = {}
    self.consumables    = {}
    self.augments       = {}
    return self
end

function Player:add_money(amount)
    assert(amount >= 0, "add_money expects a positive amount")
    self.money = self.money + amount
    return self.money
end

function Player:can_afford(cost)
    return self.money >= cost
end

function Player:spend_money(cost)
    assert(cost >= 0, "spend_money expects a positive amount")
    if not self:can_afford(cost) then
        return false
    end
    self.money = self.money - cost
    return true
end

function Player:has_joker(id)
    for _, joker in ipairs(self.jokers) do
        if joker.id == id then return true end
    end
    return false
end

function Player:has_joker_room()
    return #self.jokers < self.max_jokers
end

function Player:add_joker(joker)
    assert(self:has_joker_room(), "add_joker: no free slot")
    -- own copy: falls back to the definition, but can hold its own values
    local own = setmetatable({ n = joker.start or 0 }, { __index = joker })
    table.insert(self.jokers, own)
    return own
end

-- Adds up a passive perk ("discount", "extra_rounds", ...) over all owned jokers
function Player:perk(name)
    local total = 0
    for _, joker in ipairs(self.jokers) do total = total + (joker[name] or 0) end
    return total
end

-- Calls a hook ("on_bank", "on_farkle", ...) on every owned joker
function Player:notify(hook, ...)
    for _, joker in ipairs(self.jokers) do
        if joker[hook] then joker[hook](joker, ...) end
    end
end

-- Half the price (at least $1), or what it cost with a full_sell joker (never more, so no free money)
function Player:sell_value(joker)
    local value = math.max(1, math.floor(joker.price / 2))
    for _, other in ipairs(self.jokers) do
        if other.full_sell and other ~= joker then value = joker.paid or joker.price end
    end
    return value + (joker.bonus_sell or 0)
end

-- Returns the money earned and the sold joker, or nil if the slot is empty
function Player:sell_joker(slot)
    local joker = self.jokers[slot]
    if not joker then return nil end
    local value = self:sell_value(joker)
    table.remove(self.jokers, slot)
    self.stats.sold = self.stats.sold + 1
    self:add_money(value)
    return value, joker
end

function Player:lose()
    self.alive = false
end

function Player:escape()
    self.escaped = true
end

function Player:is_game_over()
    return (not self.alive) or self.escaped
end

return Player
