-- Special dice (pure data). player.dice[i] holds the type id of each of the six dice.
--
--   id, name, desc, price
--   tint    color the white die sprite is multiplied by
--   icon    icon in ui/joker_icons.lua (default "die_<id>"); the badge is "badge_<id>"
--   roll    function(left) -> face     (optional; left = face of the die before it, or nil)
--   scored  function(ctx) -> { chips, mult, xmult, money }   when the die is scored   (optional)
--   idle    same, when a score is made while the die stays on the table               (optional)
--   wild    true = stands for any face inside a combo of 3+ dice (never as a lone 1 or 5)
--   rescue  true = rerolls a Farkle once per floor
--   fragile chance to become plain again after being scored

local DiceTypes = {}

local LOADED = { 1, 1, 2, 3, 4, 5, 5, 6 }

DiceTypes.LIST = {
    { id = "sapphire", name = "Sapphire Die", price = 4, desc = "+60 Chips when scored", tint = { 0.50, 0.74, 1 },
      scored = function() return { chips = 60 } end },
    { id = "ruby", name = "Ruby Die", price = 5, desc = "+3 Mult when scored", tint = { 1, 0.52, 0.50 },
      scored = function() return { mult = 3 } end },
    { id = "gold", name = "Gold Die", price = 5, desc = "Earn $1 when scored", tint = { 1, 0.80, 0.32 },
      scored = function() return { money = 1 } end },
    { id = "iron", name = "Iron Die", price = 5, desc = "+3 Mult per score while left on the table", tint = { 0.64, 0.68, 0.78 },
      idle = function() return { mult = 3 } end },
    { id = "crystal", name = "Crystal Die", price = 6, desc = "x1.5 Mult when scored, 1 in 5 cracks", tint = { 0.70, 1, 0.98 },
      fragile = 0.2, scored = function() return { xmult = 1.5 } end },
    { id = "loaded", name = "Loaded Die", price = 6, desc = "Rolls 1s and 5s twice as often", tint = { 0.80, 0.62, 1 },
      roll = function() return LOADED[math.random(#LOADED)] end },
    { id = "heavy", name = "Heavy Die", price = 4, desc = "Only rolls 4, 5 or 6", tint = { 1, 0.70, 0.42 },
      roll = function() return math.random(4, 6) end },
    { id = "magnet", name = "Magnet Die", price = 6, desc = "Half the time, copies the die before it", tint = { 1, 0.66, 0.86 },
      roll = function(left)
          if left and math.random(2) == 1 then return left end
          return math.random(6)
      end },
    { id = "phoenix", name = "Phoenix Die", price = 7, desc = "Unscored: rerolls one Farkle per floor", tint = { 1, 0.62, 0.30 },
      rescue = true },
    { id = "wild", name = "Wild Die", price = 8, desc = "Any face, in combos of 3+ dice", tint = { 0.75, 1, 0.70 },
      wild = true },
}

local BY_ID = {}
for _, t in ipairs(DiceTypes.LIST) do
    BY_ID[t.id] = t
    t.kind, t.icon = "die", "die_" .. t.id
end

local PLAIN = { id = "plain", name = "Plain Die", desc = "Nothing special", tint = { 1, 1, 1 }, icon = "die_plain" }

function DiceTypes.get(id) return BY_ID[id] or PLAIN end

function DiceTypes.random() return DiceTypes.LIST[math.random(#DiceTypes.LIST)] end

function DiceTypes.roll(id, left)
    local t = DiceTypes.get(id)
    return t.roll and t.roll(left) or math.random(6)
end

return DiceTypes
