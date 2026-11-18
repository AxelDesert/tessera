-- Joker definitions (pure data, no state).
--
-- To add a joker, append an entry to LIST:
--   id      unique string
--   name    shown on the card
--   desc    short text shown on the card (keep it under ~36 characters)
--   price   shop price in $
--   effect  function(ctx) -> nil | { chips = n, mult = n, xmult = n }     (optional)
--   payout  function(ctx) -> dollars paid when a floor is cleared          (optional)
--
-- ctx for `effect` (see scoring.lua):
--   ctx.size        number of dice scored        ctx.values   the scored faces
--   ctx.faces[n]    scored dice showing n        ctx.has.<id> combo present (ids from combos.lua)
--   ctx.money, ctx.rounds_left, ctx.round_index, ctx.floor, ctx.boss, ctx.joker_count
--                   game state, given by main.lua (use `or 0` defaults when in doubt)
-- ctx for `payout` (see floor_manager.lua):
--   ctx.player, ctx.floor, ctx.boss, ctx.rounds_left, ctx.interest (what interest paid)
--
-- Returning nil means "does not trigger".
-- Prices follow the economy: ~$5 per floor + $1 per round left + interest, so $3-$9.

local Jokers = {}

local EVEN, ODD, LOW = { [2] = true, [4] = true, [6] = true }, { [1] = true, [3] = true, [5] = true },
                       { [1] = true, [2] = true, [3] = true }

-- true when every scored die is in `set`
local function only(ctx, set)
    for _, v in ipairs(ctx.values) do
        if not set[v] then return false end
    end
    return ctx.size > 0
end

Jokers.LIST = {
    -- ===== chips =====
    {
        id = "pocket_change", name = "Pocket Change", price = 3,
        desc = "+50 Chips on every score",
        effect = function(ctx) return { chips = 50 } end,
    },
    {
        id = "snake_eyes", name = "Snake Eyes", price = 4,
        desc = "+30 Chips per 1 scored",
        effect = function(ctx)
            if ctx.faces[1] > 0 then return { chips = 30 * ctx.faces[1] } end
        end,
    },
    {
        id = "five_alive", name = "Five Alive", price = 3,
        desc = "+40 Chips per 5 scored",
        effect = function(ctx)
            if ctx.faces[5] > 0 then return { chips = 40 * ctx.faces[5] } end
        end,
    },
    {
        id = "odd_todd", name = "Odd Todd", price = 4,
        desc = "+25 Chips per odd die scored",
        effect = function(ctx)
            local n = ctx.faces[1] + ctx.faces[3] + ctx.faces[5]
            if n > 0 then return { chips = 25 * n } end
        end,
    },
    {
        id = "pip_counter", name = "Pip Counter", price = 4,
        desc = "+4 Chips per pip on scored dice",
        effect = function(ctx)
            local sum = 0
            for _, v in ipairs(ctx.values) do sum = sum + v end
            return { chips = 4 * sum }
        end,
    },
    {
        id = "trio", name = "Trio", price = 4,
        desc = "Three of a kind: +100 Chips",
        effect = function(ctx)
            if ctx.has.three_kind then return { chips = 100 } end
        end,
    },
    {
        id = "ladder", name = "Ladder", price = 4,
        desc = "Small straight: +150 Chips",
        effect = function(ctx)
            if ctx.has.small_straight then return { chips = 150 } end
        end,
    },

    -- ===== mult =====
    {
        id = "two_is_company", name = "Two's Company", price = 3,
        desc = "Exactly 2 dice scored: +3 Mult",
        effect = function(ctx)
            if ctx.size == 2 then return { mult = 3 } end
        end,
    },
    {
        id = "number_one", name = "Number One", price = 4,
        desc = "Single 1 scored: +3 Mult",
        effect = function(ctx)
            if ctx.has.single_one then return { mult = 3 } end
        end,
    },
    {
        id = "lone_wolf", name = "Lone Wolf", price = 4,
        desc = "+5 Mult when scoring a single die",
        effect = function(ctx)
            if ctx.size == 1 then return { mult = 5 } end
        end,
    },
    {
        id = "sixer", name = "Sixer", price = 4,
        desc = "+2 Mult per 6 scored",
        effect = function(ctx)
            if ctx.faces[6] > 0 then return { mult = 2 * ctx.faces[6] } end
        end,
    },
    {
        id = "low_roller", name = "Low Roller", price = 4,
        desc = "Every scored die is 1-3: +4 Mult",
        effect = function(ctx)
            if only(ctx, LOW) then return { mult = 4 } end
        end,
    },
    {
        id = "triple_threat", name = "Triple Threat", price = 5,
        desc = "Three of a kind: +4 Mult",
        effect = function(ctx)
            if ctx.has.three_kind then return { mult = 4 } end
        end,
    },
    {
        id = "even_steven", name = "Even Steven", price = 5,
        desc = "+1 Mult per even die scored",
        effect = function(ctx)
            local n = ctx.faces[2] + ctx.faces[4] + ctx.faces[6]
            if n > 0 then return { mult = n } end
        end,
    },
    {
        id = "top_heavy", name = "Top Heavy", price = 5,
        desc = "+1 Mult per die 4 or higher",
        effect = function(ctx)
            local n = ctx.faces[4] + ctx.faces[5] + ctx.faces[6]
            if n > 0 then return { mult = n } end
        end,
    },
    {
        id = "straight_shooter", name = "Straight Shooter", price = 6,
        desc = "Any straight: +8 Mult",
        effect = function(ctx)
            if ctx.has.small_straight or ctx.has.large_straight then return { mult = 8 } end
        end,
    },
    {
        id = "quad_squad", name = "Quad Squad", price = 6,
        desc = "Four of a kind: +10 Mult",
        effect = function(ctx)
            if ctx.has.four_kind then return { mult = 10 } end
        end,
    },
    {
        id = "full_set", name = "Full Set", price = 7,
        desc = "All 6 dice scored: +12 Mult",
        effect = function(ctx)
            if ctx.size == 6 then return { mult = 12 } end
        end,
    },

    -- ===== x mult =====
    {
        id = "all_even", name = "All Even", price = 6,
        desc = "Every scored die is even: x1.5 Mult",
        effect = function(ctx)
            if only(ctx, EVEN) then return { xmult = 1.5 } end
        end,
    },
    {
        id = "all_odd", name = "Odd Squad", price = 6,
        desc = "Every scored die is odd: x1.5 Mult",
        effect = function(ctx)
            if only(ctx, ODD) then return { xmult = 1.5 } end
        end,
    },
    {
        id = "big_hand", name = "Big Hand", price = 7,
        desc = "4 or more dice scored: x1.5 Mult",
        effect = function(ctx)
            if ctx.size >= 4 then return { xmult = 1.5 } end
        end,
    },
    {
        id = "twin_peaks", name = "Twin Peaks", price = 8,
        desc = "Three pairs or two triples: x2 Mult",
        effect = function(ctx)
            if ctx.has.three_pairs or ctx.has.two_triples then return { xmult = 2 } end
        end,
    },
    {
        id = "high_five", name = "High Five", price = 9,
        desc = "Five or six of a kind: x3 Mult",
        effect = function(ctx)
            if ctx.has.five_kind or ctx.has.six_kind then return { xmult = 3 } end
        end,
    },

    -- ===== situational (use the game state) =====
    {
        id = "piggy_bank", name = "Piggy Bank", price = 5,
        desc = "+1 Mult per $5 you hold",
        effect = function(ctx)
            local n = math.floor((ctx.money or 0) / 5)
            if n > 0 then return { mult = n } end
        end,
    },
    {
        id = "crowd", name = "Crowd", price = 5,
        desc = "+2 Mult per other joker owned",
        effect = function(ctx)
            local others = (ctx.joker_count or 1) - 1
            if others > 0 then return { mult = 2 * others } end
        end,
    },
    {
        id = "last_call", name = "Last Call", price = 5,
        desc = "Last round of a floor: +10 Mult",
        effect = function(ctx)
            if ctx.rounds_left == 1 then return { mult = 10 } end
        end,
    },
    {
        id = "opening_move", name = "Opening Move", price = 6,
        desc = "First round of a floor: x1.5 Mult",
        effect = function(ctx)
            if ctx.round_index == 1 then return { xmult = 1.5 } end
        end,
    },
    {
        id = "boss_slayer", name = "Boss Slayer", price = 7,
        desc = "Boss floors: x2 Mult",
        effect = function(ctx)
            if ctx.boss then return { xmult = 2 } end
        end,
    },

    -- ===== money (paid when a floor is cleared) =====
    {
        id = "early_bird", name = "Early Bird", price = 5,
        desc = "+$1 per round left on a floor",
        payout = function(ctx) return ctx.rounds_left end,
    },
    {
        id = "boss_bounty", name = "Boss Bounty", price = 5,
        desc = "+$6 after a boss floor",
        payout = function(ctx) return ctx.boss and 6 or 0 end,
    },
    {
        id = "golden_die", name = "Golden Die", price = 6,
        desc = "+$4 at the end of each floor",
        payout = function(ctx) return 4 end,
    },
    {
        id = "investor", name = "Investor", price = 7,
        desc = "Doubles your interest",
        payout = function(ctx) return ctx.interest end,
    },
}

return Jokers
