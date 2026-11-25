-- Balatro-style score: (chips) x (mult).
--
--   1. every combo in the selection adds its chips and mult
--   2. special dice (dice_types.lua) and one-use buffs add theirs
--   3. every joker, left to right, may add chips / mult or multiply mult
--   4. score = chips x mult
--
-- compute() also returns `steps`: the list of changes, in order, which the
-- score panel replays as an animation.

local Combos    = require("core.combos")
local DiceTypes = require("core.dice_types")

local Scoring = {}

Scoring.BASE_MULT = 1

function Scoring.formatNumber(n)
    if n == math.floor(n) then return string.format("%d", n) end
    return string.format("%.1f", n)
end
local fmt = Scoring.formatNumber

local function describe(dChips, dMult, xMult, money)
    local parts = {}
    if dChips and dChips ~= 0 then parts[#parts + 1] = "+" .. fmt(dChips) .. " chips" end
    if dMult  and dMult  ~= 0 then parts[#parts + 1] = "+" .. fmt(dMult) .. " mult" end
    if xMult then                  parts[#parts + 1] = "x" .. fmt(xMult) .. " mult" end
    if money then                  parts[#parts + 1] = "+$" .. money end
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
    ctx.types, ctx.special = {}, 0                       -- scored dice: count per type, and all special ones
    for _, d in ipairs(ctx.dice or {}) do
        local id = d.type or "plain"
        ctx.types[id] = (ctx.types[id] or 0) + 1
        if id ~= "plain" then ctx.special = ctx.special + 1 end
    end
    return ctx
end

-- values : faces of the dice being scored (must be a valid selection)
-- jokers : list of joker definitions (player.jokers)
-- extra  : optional game state for jokers (see buildContext), plus
--            levels = player.levels, dice / table = scored / unscored dice { index, value, type },
--            buffs = player.buffs (one-use chips / xmult from charms)
function Scoring.compute(values, jokers, extra)
    local entries = Combos.evaluate(values, extra and extra.levels)
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
    ctx.jokers = jokers

    local function apply(fx, step)
        chips = chips + (fx.chips or 0)
        mult  = mult + (fx.mult or 0)
        if fx.xmult then mult = mult * fx.xmult end
        step.text, step.money = describe(fx.chips, fx.mult, fx.xmult, fx.money), fx.money
        step.chips, step.mult = chips, mult
        steps[#steps + 1] = step
    end
    local function dieSteps(list, hook)
        for _, d in ipairs(list or {}) do
            local t = DiceTypes.get(d.type)
            local fx = t[hook] and t[hook](ctx)
            if fx then apply(fx, { kind = "die", label = t.name, die = d.index }) end
        end
    end
    dieSteps(ctx.dice, "scored")
    dieSteps(ctx.table, "idle")
    local buffs = ctx.buffs
    if buffs and (buffs.chips or buffs.xmult) then
        apply({ chips = buffs.chips, xmult = buffs.xmult }, { kind = "buff", label = "Charm" })
    end

    for slot, joker in ipairs(jokers or {}) do
        ctx.slot = slot
        local fx = joker.effect and joker.effect(ctx, joker)   -- payout-only jokers have no effect
        if fx then
            -- slot = position in the joker bar, so the UI can animate that card
            apply(fx, { kind = "joker", label = joker.name, slot = slot })
        end
    end

    return {
        chips   = chips,
        mult    = mult,
        total   = math.floor(chips * mult + 0.5),
        steps   = steps,
        name    = table.concat(names, " + "),
        entries = entries,
        ctx     = ctx,       -- for the jokers' after() hook
    }
end

return Scoring
