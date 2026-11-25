-- One-use cards. Two kinds:
--   combo  raise one combination for the rest of the run: the player picks Chips or Mult
--   charm  everything else
--
-- To add a charm:  charm(id, name, price, desc, use)      (icon: ui/joker_icons.lua, same id)
--   use = function(game) -> ok [, text]    ok = false keeps the card and shows `text`
--
-- game (built by main.lua):
--   player, fm, playing (a floor is being played), picking (the player is choosing dice)
--   selected                 selected dice, left to right: { index, value, type }
--   set_faces{ [index]=n }   change faces; false when nothing could score any more
--   reroll(list)             roll those dice again (can Farkle!)

local Combos    = require("core.combos")
local DiceTypes = require("core.dice_types")
local Jokers    = require("core.jokers")

local Consumables = { COMBO = {}, CHARM = {} }

for _, def in ipairs(Combos.LIST) do
    table.insert(Consumables.COMBO, {
        id = "combo_" .. def.id, kind = "combo", name = def.name, price = 3, combo = def,
        desc = ("Combo upgrade: +%d Chips or +%d Mult"):format(def.up.chips, def.up.mult),
        use = function(game, track)
            game.player:upgrade_combo(def.id, track)
            return true, ("%s +%d %s"):format(def.name, def.up[track], track == "chips" and "Chips" or "Mult")
        end,
    })
end

local function charm(id, name, price, desc, use)
    table.insert(Consumables.CHARM, { id = id, kind = "charm", name = name, price = price, desc = desc, use = use })
end

-- Wraps a charm that works on lo..hi selected dice
local function onDice(lo, hi, use)
    local need = lo == hi and ("exactly %d %s"):format(lo, lo == 1 and "die" or "dice") or ("%d to %d dice"):format(lo, hi)
    return function(game)
        local s = game.selected
        if not game.picking or #s < lo or #s > hi then return false, "After a roll, select " .. need .. " first" end
        return use(game, s)
    end
end

local function faces(fn)
    return function(game, s)
        local map = {}
        for _, d in ipairs(s) do
            if d.type == "wild" then return false, "A wild die has no face to change" end
            map[d.index] = fn(d, s)
        end
        if not game.set_faces(map) then return false, "That would leave nothing to score" end
        return true
    end
end

local function onFloor(use)
    return function(game)
        if not game.playing then return false, "Use it during a floor" end
        return use(game)
    end
end

-- ===== dice =====
charm("nudge", "Nudge", 3, "+1 pip on up to 2 selected dice (6 becomes 1)", onDice(1, 2, faces(function(d) return d.value % 6 + 1 end)))
charm("flip", "Flip", 3, "Flips up to 3 selected dice to their opposite face", onDice(1, 3, faces(function(d) return 7 - d.value end)))
charm("ace", "Ace Up", 3, "Turns 1 selected die into a 1", onDice(1, 1, faces(function() return 1 end)))
charm("sixth_sense", "Sixth Sense", 3, "Turns up to 3 selected dice into 6s", onDice(1, 3, faces(function() return 6 end)))
charm("copycat", "Copycat", 4, "2 to 3 selected dice copy the leftmost one", onDice(2, 3, faces(function(_, s) return s[1].value end)))
charm("redo", "Redo", 3, "Rerolls the selected dice (can Farkle)", onDice(1, 6, function(game, s)
    game.reroll(s)
    return true
end))
charm("alchemy", "Alchemy", 4, "Turns 1 selected die into a random special die", onDice(1, 1, function(game, s)
    local t
    repeat t = DiceTypes.random() until t.id ~= s[1].type
    game.player.dice[s[1].index] = t.id
    return true, t.name .. "!"
end))
charm("gilding", "Gilding", 4, "Turns 1 selected die into a Gold Die", onDice(1, 1, function(game, s)
    game.player.dice[s[1].index] = "gold"
    return true, "Gold Die!"
end))
charm("twin_cast", "Twin Cast", 5, "Select 2: the right die becomes the left one's type", onDice(2, 2, function(game, s)
    if s[1].type == s[2].type then return false, "Those dice are already the same type" end
    game.player.dice[s[2].index] = s[1].type
    return true, DiceTypes.get(s[1].type).name .. "!"
end))

-- ===== score =====
charm("hot_hand", "Hot Hand", 4, "Your next score gets x2 Mult", function(game)
    local b = game.player.buffs
    if b.xmult then return false, "Already active" end
    b.xmult = 2
    return true, "Next score x2 Mult"
end)
charm("spotlight", "Spotlight", 3, "Your next score gets +300 Chips", function(game)
    local b = game.player.buffs
    b.chips = (b.chips or 0) + 300
    return true, "Next score +300 Chips"
end)
charm("lifeline", "Lifeline", 4, "Your next Farkle keeps the whole round score", function(game)
    local b = game.player.buffs
    if b.lifeline then return false, "Already active" end
    b.lifeline = true
    return true, "Lifeline ready"
end)
charm("extra_time", "Extra Time", 4, "+1 round on this floor", onFloor(function(game)
    game.fm.rounds_left, game.fm.rounds_total = game.fm.rounds_left + 1, game.fm.rounds_total + 1
    return true, "+1 round"
end))
charm("bribe", "Bribe", 4, "Lowers this floor's target by 15%", onFloor(function(game)
    local fm = game.fm
    fm.target = math.max(fm.cfg.round_to, math.floor(fm.target * 0.85 / fm.cfg.round_to + 0.5) * fm.cfg.round_to)
    return true, "Target lowered"
end))

-- ===== run =====
charm("payday", "Payday", 4, "Doubles your money (max +$8)", function(game)
    local n = math.min(8, game.player.money)
    if n <= 0 then return false, "You have no money to double" end
    game.player:add_money(n)
    return true, "+$" .. n
end)
charm("study", "Study Night", 4, "Upgrades 2 random combos", function(game)
    local names = {}
    for _ = 1, 2 do
        local def = Combos.LIST[math.random(#Combos.LIST)]
        game.player:upgrade_combo(def.id, math.random(2) == 1 and "chips" or "mult")
        names[#names + 1] = def.name
    end
    return true, table.concat(names, " + ")
end)
charm("favorite", "Favorite", 5, "Your most scored combo gains Chips and Mult", function(game)
    local best, count
    for _, def in ipairs(Combos.LIST) do
        local n = game.player.plays[def.id] or 0
        if n > (count or 0) then best, count = def, n end
    end
    if not best then return false, "Score a combo first" end
    game.player:upgrade_combo(best.id, "chips")
    game.player:upgrade_combo(best.id, "mult")
    return true, best.name .. " upgraded"
end)
charm("new_face", "New Face", 4, "Creates a random joker (needs a free slot)", function(game)
    local p, pool = game.player, {}
    if not p:has_joker_room() then return false, "No free joker slot" end
    for _, j in ipairs(Jokers.LIST) do if not p:has_joker(j.id) then pool[#pool + 1] = j end end
    if #pool == 0 then return false, "You already own every joker" end
    local own = p:add_joker(pool[math.random(#pool)])
    own.paid = 1                    -- no profit from selling it with a full_sell joker
    return true, own.name .. "!"
end)
charm("grab_bag", "Grab Bag", 4, "Creates 2 random combo cards", function(game)
    for _ = 1, 2 do
        if game.player:has_consumable_room() then game.player:add_consumable(Consumables.random("combo")) end
    end
    return true
end)

-- kind = "combo" | "charm" | nil (either)
function Consumables.random(kind)
    kind = kind or (math.random(2) == 1 and "combo" or "charm")
    local list = kind == "combo" and Consumables.COMBO or Consumables.CHARM
    return list[math.random(#list)]
end

return Consumables
