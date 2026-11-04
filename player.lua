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
    table.insert(self.jokers, joker)
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
