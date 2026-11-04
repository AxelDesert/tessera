-- Joker definitions (pure data, no state).
--
-- To add a joker, append an entry to LIST:
--   id     unique string
--   name   shown on the card
--   desc   short text shown on the card
--   price  shop price
--   effect function(ctx) -> nil | { chips = n, mult = n, xmult = n }
--
-- ctx (see scoring.lua):
--   ctx.size      number of dice scored
--   ctx.faces[n]  number of scored dice showing n
--   ctx.has.<id>  true if that combo is present (ids from combos.lua)
--
-- Returning nil means "does not trigger".

local Jokers = {}

Jokers.LIST = {
    {
        id = "pocket_change", name = "Pocket Change", price = 40,
        desc = "+50 Chips on every score",
        effect = function(ctx) return { chips = 50 } end,
    },
    {
        id = "snake_eyes", name = "Snake Eyes", price = 50,
        desc = "+30 Chips per 1 scored",
        effect = function(ctx)
            if ctx.faces[1] > 0 then return { chips = 30 * ctx.faces[1] } end
        end,
    },
    {
        id = "lone_wolf", name = "Lone Wolf", price = 60,
        desc = "+5 Mult when scoring a single die",
        effect = function(ctx)
            if ctx.size == 1 then return { mult = 5 } end
        end,
    },
    {
        id = "triple_threat", name = "Triple Threat", price = 60,
        desc = "Three of a kind: +4 Mult",
        effect = function(ctx)
            if ctx.has.three_kind then return { mult = 4 } end
        end,
    },
    {
        id = "even_steven", name = "Even Steven", price = 80,
        desc = "+1 Mult per even die scored",
        effect = function(ctx)
            local n = ctx.faces[2] + ctx.faces[4] + ctx.faces[6]
            if n > 0 then return { mult = n } end
        end,
    },
    {
        id = "straight_shooter", name = "Straight Shooter", price = 90,
        desc = "Any straight: +8 Mult",
        effect = function(ctx)
            if ctx.has.small_straight or ctx.has.large_straight then return { mult = 8 } end
        end,
    },
    {
        id = "big_hand", name = "Big Hand", price = 120,
        desc = "4 or more dice scored: x1.5 Mult",
        effect = function(ctx)
            if ctx.size >= 4 then return { xmult = 1.5 } end
        end,
    },
    {
        id = "twin_peaks", name = "Twin Peaks", price = 130,
        desc = "Three pairs or two triples: x2 Mult",
        effect = function(ctx)
            if ctx.has.three_pairs or ctx.has.two_triples then return { xmult = 2 } end
        end,
    },
}

return Jokers
