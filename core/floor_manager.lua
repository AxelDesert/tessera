local FloorManager = {}
FloorManager.__index = FloorManager

-- Floor conf
FloorManager.CONFIG = {
    total_floors     = 7,       -- reach the top => escape the casino
    base_target      = 500,     -- target score on floor 1
    growth          = 1.2,      -- multiplier per floor
    rounds_per_floor  = 5,      -- rounds (Farkle turns) allowed per floor
    boss_every       = 5,       -- every 5th floor is a boss
    boss_target_mult  = 1.4,
    boss_rounds_penalty = 1,    -- bosses give 1 round less
    boss_reward      = 100,
    reward_per_floor  = 25,
    boss_reward_mult  = 2,
    round_to         = 50,      -- scores are multiples of 50
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

function FloorManager:get_rewards(n)
    local c = self.cfg
    local r = c.boss_reward + c.reward_per_floor * (n - 1)
    if self:is_boss(n) then
        r = r * c.boss_reward_mult
    end
    return r
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
    local reward = self:get_rewards(self.floor)
    self.player:add_money(reward)
    self.player.floors_cleared = self.player.floors_cleared + 1
    self.lastReward = reward

    if self.floor >= self.cfg.total_floors then
        self.state = "game_won"
        self.player:escape()
        return "game_won"
    end
    self.state = "floor_cleared"
    -- shop goes here then start_next_floor() (in main)
    return "floor_cleared"
end

return FloorManager
