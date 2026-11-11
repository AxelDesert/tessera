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
--
-- With the default numbers a lone combo is worth the same as the old
-- console version (ex: three 2s = 100 chips x (1 + 1) = 200).

local Combos = {}

Combos.LIST = {
    { id = "single_one",     name = "Single 1",        used = 1, chips = 100, mult = 0,
      desc = "Each 1 that is not part of another combo",  example = {1} },
    { id = "single_five",    name = "Single 5",        used = 1, chips = 50,  mult = 0,
      desc = "Each 5 that is not part of another combo",  example = {5} },
    { id = "three_kind",     name = "Three of a kind", used = 3, mult = 1, showFace = true,
      chips = function(face) return face == 1 and 500 or face * 50 end,
      chipsLabel = "50 x face (500 for 1s)",              example = {4, 4, 4} },
    { id = "four_kind",      name = "Four of a kind",  used = 4, chips = 500,  mult = 1, showFace = true,
      example = {3, 3, 3, 3} },
    { id = "five_kind",      name = "Five of a kind",  used = 5, chips = 1000, mult = 1, showFace = true,
      example = {2, 2, 2, 2, 2} },
    { id = "six_kind",       name = "Six of a kind",   used = 6, chips = 1000, mult = 2, showFace = true,
      example = {6, 6, 6, 6, 6, 6} },
    { id = "small_straight", name = "Small straight",  used = 5, chips = 250,  mult = 2,
      desc = "1-2-3-4-5 or 2-3-4-5-6",                    example = {1, 2, 3, 4, 5} },
    { id = "large_straight", name = "Straight",        used = 6, chips = 750,  mult = 1,
      example = {1, 2, 3, 4, 5, 6} },
    { id = "three_pairs",    name = "Three pairs",     used = 6, chips = 750,  mult = 1,
      example = {1, 1, 3, 3, 6, 6} },
    { id = "two_triples",    name = "Two triples",     used = 6, chips = 1250, mult = 1,
      example = {2, 2, 2, 5, 5, 5} },
    { id = "four_pair",      name = "Four + a pair",   used = 6, chips = 750,  mult = 1,
      example = {4, 4, 4, 4, 6, 6} },
}

local DEFS = {}
for _, def in ipairs(Combos.LIST) do DEFS[def.id] = def end

-- Builds one result entry: { id, label, chips, mult, used }
local function makeEntry(id, face, times)
    local def = DEFS[id]
    times = times or 1
    local chips = type(def.chips) == "function" and def.chips(face) or def.chips
    local label = def.name
    if def.showFace then label = label .. " (" .. face .. "s)" end
    if times > 1 then label = label .. " x" .. times end
    return {
        id    = id,
        label = label,
        chips = chips * times,
        mult  = def.mult * times,
        used  = def.used * times,
    }
end

-- Returns the list of combos found in `values` (a list of die faces).
-- Same rules as the original console version.
function Combos.evaluate(values)
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

-- Can this set of dice score anything at all? (used for the Farkle check)
function Combos.canScore(values)
    return #Combos.evaluate(values) > 0
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
