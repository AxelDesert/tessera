-- Dice rolling only.
-- Combination detection lives in combos.lua, score maths in scoring.lua.
math.randomseed(os.time())

local Farkle = {}

function Farkle.rollDice(amount)
    local dice = {}
    for i = 1, amount do
        dice[i] = math.random(1, 6)
    end
    return dice
end

return Farkle
