-- Dice rolling only.
-- Combination detection lives in combos.lua, score maths in scoring.lua.
local DiceTypes = require("core.dice_types")

math.randomseed(os.time())

local Farkle = {}

-- types = all six type ids, values = all six faces, free = indexes to roll (left to right).
-- Writes the new faces into `values`.
function Farkle.rollDice(types, values, free)
    for _, i in ipairs(free) do
        values[i] = DiceTypes.roll(types[i], values[i - 1])
    end
    return values
end

return Farkle
