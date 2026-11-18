local FloorManager = {}
FloorManager.__index = FloorManager

-- Floor conf
FloorManager.CONFIG = {
    total_floors     = 7,       -- reach the top => escape the casino
    base_target      = 1000,     -- target score on floor 1
    growth          = 2,      -- multiplier per floor
    rounds_per_floor  = 6,      -- rounds (Farkle turns) allowed per floor
    boss_every       = 5,       -- every 5th floor is a boss
    boss_target_mult  = 1,
    boss_rounds_penalty = 1,    -- bosses give 1 round less
    round_to         = 50,      -- scores are multiples of 50

    -- Money paid when a floor is cleared (Balatro style, see compute_payout)
    base_reward      = 5,       -- $ for a normal floor
    boss_reward      = 8,       -- $ for a boss floor
    reward_per_round = 1,       -- $ for every round you did not need
    interest_per     = 5,       -- every $5 you hold earns...
    interest_amount  = 1,       -- ...$1 of interest...
    interest_cap     = 5,       -- ...up to $5 (so money above $25 earns nothing more)
}

function FloorManager.new(player, config)
    local self = setmetatable({}, FloorManager)
    self.player = player
    self.cfg = setmetatable(config or {}, { __index = FloorManager.CONFIG })
    self.floor = 0
    self.state = "idle"  -- idle | playing | game_won | game_lost
    return self
end

function FloorManager:is_boss(n)
    return n % self.cfg.boss_every == 0
end

function FloorManager:get_target(n)
    local c = self.cfg
    local t = c.base_target * (c.growth ^ (n - 1))
    if self:is_boss(n) then
        t = t * c.boss_target_mult
    end
    return math.floor(t / c.round_to + 0.5) * c.round_to
end

function FloorManager:get_rounds(n)
    local r = self.cfg.rounds_per_floor
    if self:is_boss(n) then
        r = r - self.cfg.boss_rounds_penalty
    end
    return r
end

-- Base reward of floor n (what the HUD shows as "to earn")
function FloorManager:get_rewards(n)
    return self:is_boss(n) and self.cfg.boss_reward or self.cfg.base_reward
end

-- Everything the player earns for clearing the current floor, line by line:
--   { total = n, lines = { { label, amount, kind }, ... } }
-- kind = "base" | "rounds" | "interest" | "joker"
-- Jokers can add a line with `payout = function(ctx) return dollars end`
-- (ctx: player, fm, floor, boss, rounds_left, interest).
function FloorManager:compute_payout()
    local c, p = self.cfg, self.player
    local lines, total = {}, 0
    local function add(label, amount, kind)
        if amount and amount > 0 then
            lines[#lines + 1] = { label = label, amount = amount, kind = kind }
            total = total + amount
        end
    end

    local boss = self:is_boss(self.floor)
    add(boss and "Boss floor cleared" or "Floor cleared", self:get_rewards(self.floor), "base")
    add(("%d round%s left  ($%d each)"):format(self.rounds_left, self.rounds_left == 1 and "" or "s", c.reward_per_round),
        self.rounds_left * c.reward_per_round, "rounds")

    local interest = math.min(c.interest_cap, math.floor(p.money / c.interest_per) * c.interest_amount)
    add(("Interest  ($%d per $%d, max $%d)"):format(c.interest_amount, c.interest_per, c.interest_cap), interest, "interest")

    local ctx = { player = p, fm = self, floor = self.floor, boss = boss,
                  rounds_left = self.rounds_left, interest = interest }
    for _, joker in ipairs(p.jokers) do
        if joker.payout then add(joker.name, joker.payout(ctx), "joker") end
    end
    return { lines = lines, total = total }
end

-- Puts the money of the last payout in the player's wallet (once)
function FloorManager:collect_payout()
    if self.lastPayout and not self.payoutCollected then
        self.player:add_money(self.lastPayout.total)
        self.payoutCollected = true
    end
end

function FloorManager:start_next_floor()
    if self.state == "game_won" or self.state == "game_lost" then
        return false
    end
    self.floor       = self.floor + 1
    self.target      = self:get_target(self.floor)
    self.rounds_left  = self:get_rounds(self.floor)
    self.score       = 0
    self.state       = "playing"
    return true
end

-- Dice system calls this with the points banked at the end of a Farkle turn
-- (0 if farkled). Returns "playing" | "floor_cleared" | "game_won" | "game_lost".
function FloorManager:submit_round(points)
    if self.state ~= "playing" then return self.state end
    self.score      = self.score + (points or 0)
    self.rounds_left = self.rounds_left - 1

    if self.score >= self.target then
        return self:_clear_floor()
    elseif self.rounds_left <= 0 then
        self.state = "game_lost"
        self.player:lose()
        return "game_lost"
    end
    return "playing"
end

function FloorManager:_clear_floor()
    self.lastPayout = self:compute_payout()
    self.lastReward = self.lastPayout.total
    self.payoutCollected = false
    self.player.floors_cleared = self.player.floors_cleared + 1

    if self.floor >= self.cfg.total_floors then
        self:collect_payout()          -- no cash-out screen after the last floor
        self.state = "game_won"
        self.player:escape()
        return "game_won"
    end
    self.state = "floor_cleared"
    -- main shows the cash-out screen, calls collect_payout(), then the shop
    return "floor_cleared"
end

return FloorManager
