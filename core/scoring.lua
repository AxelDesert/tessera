-- Balatro-style score: (chips) x (mult).
--
--   1. every combo in the selection adds its chips and mult
--   2. every joker, left to right, may add chips / mult or multiply mult
--   3. score = chips x mult
--
-- compute() also returns `steps`: the list of changes, in order, which the
-- score panel replays as an animation.

local Combos = require("core.combos")

local Scoring = {}

Scoring.BASE_MULT = 1

function Scoring.formatNumber(n)
    if n == math.floor(n) then return string.format("%d", n) end
    return string.format("%.1f", n)
end
local fmt = Scoring.formatNumber

local function describe(dChips, dMult, xMult)
    local parts = {}
    if dChips and dChips ~= 0 then parts[#parts + 1] = "+" .. fmt(dChips) .. " chips" end
    if dMult  and dMult  ~= 0 then parts[#parts + 1] = "+" .. fmt(dMult) .. " mult" end
    if xMult then                  parts[#parts + 1] = "x" .. fmt(xMult) .. " mult" end
    return table.concat(parts, "   ")
end

-- What jokers get to look at
-- `extra` = optional table from main (money, rounds_left, boss, ...) merged into the context
local function buildContext(values, entries, extra)
    local faces, has = {0, 0, 0, 0, 0, 0}, {}
    for _, v in ipairs(values) do faces[v] = faces[v] + 1 end
    for _, e in ipairs(entries) do has[e.id] = true end
    local ctx = {
        values  = values,    -- scored dice
        size    = #values,   -- how many dice are scored
        faces   = faces,     -- faces[n] = how many dice show n
        has     = has,       -- has.three_kind == true, ...
        entries = entries,   -- raw combo list
    }
    for k, v in pairs(extra or {}) do ctx[k] = v end
    return ctx
end

-- values : faces of the dice being scored (must be a valid selection)
-- jokers : list of joker definitions (player.jokers)
-- extra  : optional game state for jokers (see buildContext)
function Scoring.compute(values, jokers, extra)
    local entries = Combos.evaluate(values)
    local chips, mult = 0, Scoring.BASE_MULT
    local steps, names = {}, {}

    for _, e in ipairs(entries) do
        chips, mult = chips + e.chips, mult + e.mult
        names[#names + 1] = e.label
        steps[#steps + 1] = {
            kind = "combo", label = e.label, text = describe(e.chips, e.mult),
            chips = chips, mult = mult,
        }
    end

    local ctx = buildContext(values, entries, extra)
    for slot, joker in ipairs(jokers or {}) do
        local fx = joker.effect and joker.effect(ctx)   -- payout-only jokers have no effect
        if fx then
            chips = chips + (fx.chips or 0)
            mult  = mult + (fx.mult or 0)
            if fx.xmult then mult = mult * fx.xmult end
            steps[#steps + 1] = {
                kind = "joker", label = joker.name, text = describe(fx.chips, fx.mult, fx.xmult),
                slot = slot,   -- position in the joker bar, so the UI can animate that card
                chips = chips, mult = mult,
            }
        end
    end

    return {
        chips   = chips,
        mult    = mult,
        total   = math.floor(chips * mult + 0.5),
        steps   = steps,
        name    = table.concat(names, " + "),
        entries = entries,
    }
end

return Scoring
