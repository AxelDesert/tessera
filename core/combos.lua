-- Dice combinations.
--
-- This file answers two questions:
--   * which combinations are in a set of dice?   (Combos.evaluate)
--   * is a selection made only of scoring dice?  (Combos.isValidSelection)
--
-- Every combo gives CHIPS and MULT. The numbers live ONLY in the LIST below,
-- so this is the place to tune the balance.
--   chips : number, or function(face) -> number
--   mult  : added to the base mult (see scoring.lua)
--   used  : how many dice the combo consumes
--   up    : what one upgrade gives (combo cards, see consumables.lua)
--
-- With the default numbers a lone combo is worth the same as the old
-- console version (ex: three 2s = 100 chips x (1 + 1) = 200).

local Combos = {}

Combos.LIST = {
    { id = "single_one", up = { chips = 30, mult = 1 },     name = "Single 1",        used = 1, chips = 100, mult = 0,
      desc = "Each 1 that is not part of another combo",  example = {1} },
    { id = "single_five", up = { chips = 20, mult = 1 },    name = "Single 5",        used = 1, chips = 50,  mult = 0,
      desc = "Each 5 that is not part of another combo",  example = {5} },
    { id = "three_kind", up = { chips = 60, mult = 1 },     name = "Three of a kind", used = 3, mult = 1, showFace = true,
      chips = function(face) return face == 1 and 500 or face * 50 end,
      chipsLabel = "50 x face (500 for 1s)",              example = {4, 4, 4} },
    { id = "four_kind", up = { chips = 120, mult = 2 },      name = "Four of a kind",  used = 4, chips = 500,  mult = 1, showFace = true,
      example = {3, 3, 3, 3} },
    { id = "five_kind", up = { chips = 250, mult = 3 },      name = "Five of a kind",  used = 5, chips = 1000, mult = 1, showFace = true,
      example = {2, 2, 2, 2, 2} },
    { id = "six_kind", up = { chips = 400, mult = 4 },       name = "Six of a kind",   used = 6, chips = 1000, mult = 2, showFace = true,
      example = {6, 6, 6, 6, 6, 6} },
    { id = "small_straight", up = { chips = 100, mult = 2 }, name = "Small straight",  used = 5, chips = 250,  mult = 2,
      desc = "1-2-3-4-5 or 2-3-4-5-6",                    example = {1, 2, 3, 4, 5} },
    { id = "large_straight", up = { chips = 200, mult = 3 }, name = "Straight",        used = 6, chips = 750,  mult = 1,
      example = {1, 2, 3, 4, 5, 6} },
    { id = "three_pairs", up = { chips = 200, mult = 3 },    name = "Three pairs",     used = 6, chips = 750,  mult = 1,
      example = {1, 1, 3, 3, 6, 6} },
    { id = "two_triples", up = { chips = 250, mult = 3 },    name = "Two triples",     used = 6, chips = 1250, mult = 1,
      example = {2, 2, 2, 5, 5, 5} },
    { id = "four_pair", up = { chips = 200, mult = 3 },      name = "Four + a pair",   used = 6, chips = 750,  mult = 1,
      example = {4, 4, 4, 4, 6, 6} },
}

local DEFS = {}
for _, def in ipairs(Combos.LIST) do DEFS[def.id] = def end

-- Builds one result entry: { id, label, chips, mult, used }
-- `levels` = player.levels: how many upgrades each combo has { [id] = { chips = n, mult = n } }
local levels
local function makeEntry(id, face, times)
    local def = DEFS[id]
    times = times or 1
    local chips = type(def.chips) == "function" and def.chips(face) or def.chips
    local lv = levels and levels[id]
    if lv then chips = chips + lv.chips * def.up.chips end
    local label = def.name
    if def.showFace then label = label .. " (" .. face .. "s)" end
    if times > 1 then label = label .. " x" .. times end
    return {
        id    = id,
        label = label,
        chips = chips * times,
        mult  = def.mult * times + (lv and lv.mult * def.up.mult or 0),
        used  = def.used * times,
    }
end

-- Returns the list of combos found in `values` (a list of die faces).
-- Same rules as the original console version.
function Combos.evaluate(values, comboLevels)
    levels = comboLevels
    local freq = {0, 0, 0, 0, 0, 0}
    for _, v in ipairs(values) do freq[v] = freq[v] + 1 end

    -- Combos that need all six dice
    if #values == 6 then
        local pairsN, triples, distinct, quad = 0, 0, 0, false
        for face = 1, 6 do
            local c = freq[face]
            if c == 6 then return { makeEntry("six_kind", face) } end
            if c == 4 then quad = true end
            if c == 3 then triples = triples + 1 end
            if c == 2 then pairsN = pairsN + 1 end
            if c == 1 then distinct = distinct + 1 end
        end
        if pairsN == 3 then return { makeEntry("three_pairs") } end
        if triples == 2 then return { makeEntry("two_triples") } end
        if distinct == 6 then return { makeEntry("large_straight") } end
        if quad and pairsN == 1 then return { makeEntry("four_pair") } end
    end

    local found = {}

    -- Small straight: 1-2-3-4-5 or 2-3-4-5-6
    if (freq[1] >= 1 or freq[6] >= 1)
            and freq[2] >= 1 and freq[3] >= 1 and freq[4] >= 1 and freq[5] >= 1 then
        found[#found + 1] = makeEntry("small_straight")
        for face = 2, 5 do freq[face] = freq[face] - 1 end
        if freq[1] >= 1 then freq[1] = freq[1] - 1 else freq[6] = freq[6] - 1 end
    end

    -- Three / four / five of a kind
    for face = 1, 6 do
        local c = freq[face]
        if c == 5 then
            found[#found + 1] = makeEntry("five_kind", face)
            freq[face] = 0
        elseif c == 4 then
            found[#found + 1] = makeEntry("four_kind", face)
            freq[face] = 0
        elseif c == 3 then
            found[#found + 1] = makeEntry("three_kind", face)
            freq[face] = 0
        end
    end

    -- Leftover single 1s and 5s
    if freq[1] > 0 then found[#found + 1] = makeEntry("single_one", 1, freq[1]) end
    if freq[5] > 0 then found[#found + 1] = makeEntry("single_five", 5, freq[5]) end

    return found
end

-- Gives wild dice the faces that score best. wild[i] = true for wild dice.
-- all = every die must be used (a selection). Returns nil when that is impossible.
-- A wild die may join any combo of 3+ dice but never counts as a lone 1 or 5.
function Combos.resolve(values, wild, comboLevels, all)
    local slots, try = {}, {}
    for i, v in ipairs(values) do
        try[i] = v
        if wild and wild[i] then slots[#slots + 1] = i end
    end
    if #slots == 0 then return try end

    local best, bestScore
    local function check()
        local found = Combos.evaluate(try, comboLevels)
        local chips, mult, used, lone = 0, 1, 0, { [1] = 0, [5] = 0 }
        for _, e in ipairs(found) do
            chips, mult, used = chips + e.chips, mult + e.mult, used + e.used
            if e.id == "single_one" then lone[1] = e.used elseif e.id == "single_five" then lone[5] = e.used end
        end
        if all and (used == 0 or used ~= #try) then return end
        for face, n in pairs(lone) do
            local total, wilds = 0, 0
            for i, v in ipairs(try) do
                if v == face then total, wilds = total + 1, wilds + (wild[i] and 1 or 0) end
            end
            if wilds + n > total then return end
        end
        local score = chips * mult
        if not bestScore or score > bestScore then
            best, bestScore = {}, score
            for i, v in ipairs(try) do best[i] = v end
        end
    end
    local function fill(k, from)          -- order does not matter, so faces never decrease
        if k > #slots then check() return end
        for face = from, 6 do
            try[slots[k]] = face
            fill(k + 1, face)
        end
    end
    fill(1, 1)
    return best
end

-- Can this set of dice score anything at all? (used for the Farkle check)
function Combos.canScore(values)
    return #Combos.evaluate(values) > 0
end

-- Which of these dice can be part of a combo? Returns mask[i] = true for each
-- scoring die (used to highlight dice while the player picks).
function Combos.scoringMask(values)
    local mask, found = {}, Combos.evaluate(values)
    if #found == 0 then return mask end

    -- a six-dice combo uses every die
    if #found == 1 and found[1].used == 6 and #values == 6 then
        for i = 1, #values do mask[i] = true end
        return mask
    end

    local freq = {0, 0, 0, 0, 0, 0}
    for _, v in ipairs(values) do freq[v] = freq[v] + 1 end
    for i, v in ipairs(values) do
        mask[i] = v == 1 or v == 5 or freq[v] >= 3
    end

    -- small straight: one die of each face 2..5, plus a 1 (or a 6 if there is no 1)
    for _, e in ipairs(found) do
        if e.id == "small_straight" then
            local need = { [2] = true, [3] = true, [4] = true, [5] = true }
            if freq[1] >= 1 then need[1] = true else need[6] = true end
            for i, v in ipairs(values) do
                if need[v] then mask[i], need[v] = true, nil end
            end
        end
    end
    return mask
end

-- A selection is valid only if EVERY selected die is part of a combo.
function Combos.isValidSelection(values)
    local found = Combos.evaluate(values)
    if #found == 0 then return false end
    local used = 0
    for _, entry in ipairs(found) do used = used + entry.used end
    return used == #values
end

return Combos
