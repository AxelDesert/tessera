-- Joker definitions (pure data, no state).
--
-- To add a joker, append an entry to LIST:
--   id      unique string
--   name    shown on the card
--   desc    short text shown on the card (keep it under ~36 characters)
--   price   shop price in $
--   kind    chips | mult | xmult | money | utility   (color of the card, see ui/joker_bar.lua)
--   effect  function(ctx, self) -> nil | { chips = n, mult = n, xmult = n, money = n }   (optional)
--   payout  function(ctx, self) -> dollars paid when a floor is cleared                  (optional)
--   info    function(self) -> extra tooltip line, for jokers that change                 (optional)
-- The icon is in ui/joker_icons.lua (same id).
--
-- `self` is the copy owned by the player (see Player:add_joker). It can store its own values;
-- self.n starts at `start` (default 0) and is what growing jokers use. Hooks:
--   after(self, ctx)            after each score         on_bank(self, player)    points banked
--   on_farkle(self, player)     Farkle                   on_round(self, player)   any round ends
--   on_floor(self, player)      floor cleared
-- Passive perks (read by floor_manager.lua, shop.lua, player.lua and main.lua):
--   farkle_keep, free_farkle, extra_rounds, interest_cap, discount, extra_offers, reroll_discount, full_sell
--
-- ctx for `effect` (see scoring.lua):
--   ctx.size        number of dice scored        ctx.values   the scored faces
--   ctx.faces[n]    scored dice showing n        ctx.has.<id> combo present (ids from combos.lua)
--   ctx.money, ctx.rounds_left, ctx.round_index, ctx.floor, ctx.boss, ctx.joker_count,
--   ctx.max_jokers, ctx.score_index, ctx.dice_left, ctx.round_score, ctx.floor_score, ctx.target, ctx.stats
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
        kind = "chips", id = "pocket_change", name = "Pocket Change", price = 3,
        desc = "+50 Chips on every score",
        effect = function(ctx) return { chips = 50 } end,
    },
    {
        kind = "chips", id = "snake_eyes", name = "Snake Eyes", price = 4,
        desc = "+30 Chips per 1 scored",
        effect = function(ctx)
            if ctx.faces[1] > 0 then return { chips = 30 * ctx.faces[1] } end
        end,
    },
    {
        kind = "chips", id = "five_alive", name = "Five Alive", price = 3,
        desc = "+40 Chips per 5 scored",
        effect = function(ctx)
            if ctx.faces[5] > 0 then return { chips = 40 * ctx.faces[5] } end
        end,
    },
    {
        kind = "chips", id = "odd_todd", name = "Odd Todd", price = 4,
        desc = "+25 Chips per odd die scored",
        effect = function(ctx)
            local n = ctx.faces[1] + ctx.faces[3] + ctx.faces[5]
            if n > 0 then return { chips = 25 * n } end
        end,
    },
    {
        kind = "chips", id = "pip_counter", name = "Pip Counter", price = 4,
        desc = "+4 Chips per pip on scored dice",
        effect = function(ctx)
            local sum = 0
            for _, v in ipairs(ctx.values) do sum = sum + v end
            return { chips = 4 * sum }
        end,
    },
    {
        kind = "chips", id = "trio", name = "Trio", price = 4,
        desc = "Three of a kind: +100 Chips",
        effect = function(ctx)
            if ctx.has.three_kind then return { chips = 100 } end
        end,
    },
    {
        kind = "chips", id = "ladder", name = "Ladder", price = 4,
        desc = "Small straight: +150 Chips",
        effect = function(ctx)
            if ctx.has.small_straight then return { chips = 150 } end
        end,
    },

    -- ===== mult =====
    {
        kind = "mult", id = "two_is_company", name = "Two's Company", price = 3,
        desc = "Exactly 2 dice scored: +3 Mult",
        effect = function(ctx)
            if ctx.size == 2 then return { mult = 3 } end
        end,
    },
    {
        kind = "mult", id = "number_one", name = "Number One", price = 4,
        desc = "Single 1 scored: +3 Mult",
        effect = function(ctx)
            if ctx.has.single_one then return { mult = 3 } end
        end,
    },
    {
        kind = "mult", id = "lone_wolf", name = "Lone Wolf", price = 4,
        desc = "+5 Mult when scoring a single die",
        effect = function(ctx)
            if ctx.size == 1 then return { mult = 5 } end
        end,
    },
    {
        kind = "mult", id = "sixer", name = "Sixer", price = 4,
        desc = "+2 Mult per 6 scored",
        effect = function(ctx)
            if ctx.faces[6] > 0 then return { mult = 2 * ctx.faces[6] } end
        end,
    },
    {
        kind = "mult", id = "low_roller", name = "Low Roller", price = 4,
        desc = "Every scored die is 1-3: +4 Mult",
        effect = function(ctx)
            if only(ctx, LOW) then return { mult = 4 } end
        end,
    },
    {
        kind = "mult", id = "triple_threat", name = "Triple Threat", price = 5,
        desc = "Three of a kind: +4 Mult",
        effect = function(ctx)
            if ctx.has.three_kind then return { mult = 4 } end
        end,
    },
    {
        kind = "mult", id = "even_steven", name = "Even Steven", price = 5,
        desc = "+1 Mult per even die scored",
        effect = function(ctx)
            local n = ctx.faces[2] + ctx.faces[4] + ctx.faces[6]
            if n > 0 then return { mult = n } end
        end,
    },
    {
        kind = "mult", id = "top_heavy", name = "Top Heavy", price = 5,
        desc = "+1 Mult per die 4 or higher",
        effect = function(ctx)
            local n = ctx.faces[4] + ctx.faces[5] + ctx.faces[6]
            if n > 0 then return { mult = n } end
        end,
    },
    {
        kind = "mult", id = "straight_shooter", name = "Straight Shooter", price = 6,
        desc = "Any straight: +8 Mult",
        effect = function(ctx)
            if ctx.has.small_straight or ctx.has.large_straight then return { mult = 8 } end
        end,
    },
    {
        kind = "mult", id = "quad_squad", name = "Quad Squad", price = 6,
        desc = "Four of a kind: +10 Mult",
        effect = function(ctx)
            if ctx.has.four_kind then return { mult = 10 } end
        end,
    },
    {
        kind = "mult", id = "full_set", name = "Full Set", price = 7,
        desc = "All 6 dice scored: +12 Mult",
        effect = function(ctx)
            if ctx.size == 6 then return { mult = 12 } end
        end,
    },

    -- ===== x mult =====
    {
        kind = "xmult", id = "all_even", name = "All Even", price = 6,
        desc = "Every scored die is even: x1.5 Mult",
        effect = function(ctx)
            if only(ctx, EVEN) then return { xmult = 1.5 } end
        end,
    },
    {
        kind = "xmult", id = "all_odd", name = "Odd Squad", price = 6,
        desc = "Every scored die is odd: x1.5 Mult",
        effect = function(ctx)
            if only(ctx, ODD) then return { xmult = 1.5 } end
        end,
    },
    {
        kind = "xmult", id = "big_hand", name = "Big Hand", price = 7,
        desc = "4 or more dice scored: x1.5 Mult",
        effect = function(ctx)
            if ctx.size >= 4 then return { xmult = 1.5 } end
        end,
    },
    {
        kind = "xmult", id = "twin_peaks", name = "Twin Peaks", price = 8,
        desc = "Three pairs or two triples: x2 Mult",
        effect = function(ctx)
            if ctx.has.three_pairs or ctx.has.two_triples then return { xmult = 2 } end
        end,
    },
    {
        kind = "xmult", id = "high_five", name = "High Five", price = 9,
        desc = "Five or six of a kind: x3 Mult",
        effect = function(ctx)
            if ctx.has.five_kind or ctx.has.six_kind then return { xmult = 3 } end
        end,
    },

    -- ===== situational (use the game state) =====
    {
        kind = "mult", id = "piggy_bank", name = "Piggy Bank", price = 5,
        desc = "+1 Mult per $5 you hold",
        effect = function(ctx)
            local n = math.floor((ctx.money or 0) / 5)
            if n > 0 then return { mult = n } end
        end,
    },
    {
        kind = "mult", id = "crowd", name = "Crowd", price = 5,
        desc = "+2 Mult per other joker owned",
        effect = function(ctx)
            local others = (ctx.joker_count or 1) - 1
            if others > 0 then return { mult = 2 * others } end
        end,
    },
    {
        kind = "mult", id = "last_call", name = "Last Call", price = 5,
        desc = "Last round of a floor: +10 Mult",
        effect = function(ctx)
            if ctx.rounds_left == 1 then return { mult = 10 } end
        end,
    },
    {
        kind = "xmult", id = "opening_move", name = "Opening Move", price = 6,
        desc = "First round of a floor: x1.5 Mult",
        effect = function(ctx)
            if ctx.round_index == 1 then return { xmult = 1.5 } end
        end,
    },
    {
        kind = "xmult", id = "boss_slayer", name = "Boss Slayer", price = 7,
        desc = "Boss floors: x2 Mult",
        effect = function(ctx)
            if ctx.boss then return { xmult = 2 } end
        end,
    },

    -- ===== money (paid when a floor is cleared) =====
    {
        kind = "money", id = "early_bird", name = "Early Bird", price = 5,
        desc = "+$1 per round left on a floor",
        payout = function(ctx) return ctx.rounds_left end,
    },
    {
        kind = "money", id = "boss_bounty", name = "Boss Bounty", price = 5,
        desc = "+$6 after a boss floor",
        payout = function(ctx) return ctx.boss and 6 or 0 end,
    },
    {
        kind = "money", id = "golden_die", name = "Golden Die", price = 6,
        desc = "+$4 at the end of each floor",
        payout = function(ctx) return 4 end,
    },
    {
        kind = "money", id = "investor", name = "Investor", price = 7,
        desc = "Doubles your interest",
        payout = function(ctx) return ctx.interest end,
    },
}

---------------------------------------------------------------------------
-- More jokers, in compact form:  add(kind, id, name, price, desc, effect, extra)
-- `extra` is merged into the definition (payout, hooks, shop perks, ...)
---------------------------------------------------------------------------
local function add(kind, id, name, price, desc, effect, extra)
    local j = { kind = kind, id = id, name = name, price = price, desc = desc, effect = effect }
    for k, v in pairs(extra or {}) do j[k] = v end
    Jokers.LIST[#Jokers.LIST + 1] = j
end

local function pips(ctx)
    local sum = 0
    for _, v in ipairs(ctx.values) do sum = sum + v end
    return sum
end

-- effect: `amount` of `what` for every scored die showing `face`
local function perFace(face, what, amount)
    return function(ctx)
        if ctx.faces[face] > 0 then return { [what] = amount * ctx.faces[face] } end
    end
end

-- effect: fx when test(ctx) is true
local function when(test, fx)
    return function(ctx) if test(ctx) then return fx end end
end

-- effect: `amount` of `what` times count(ctx, self)
local function per(what, amount, count)
    return function(ctx, self)
        local n = count(ctx, self)
        if n > 0 then return { [what] = amount * n } end
    end
end

local function has(id) return function(ctx) return ctx.has[id] end end
local function straight(ctx) return ctx.has.small_straight or ctx.has.large_straight end
local function grown(_, self) return self.n end                    -- growing jokers count in self.n
local function earlier(ctx) return (ctx.score_index or 1) - 1 end  -- scores already made this round

-- ===== chips =====
add("chips", "loose_deuces", "Loose Deuces", 3, "+45 Chips per 2 scored", perFace(2, "chips", 45))
add("chips", "threepenny", "Threepenny", 3, "+50 Chips per 3 scored", perFace(3, "chips", 50))
add("chips", "four_leaf", "Four Leaf", 4, "+55 Chips per 4 scored", perFace(4, "chips", 55))
add("chips", "six_pack", "Six Pack", 4, "+45 Chips per 6 scored", perFace(6, "chips", 45))
add("chips", "dice_bag", "Dice Bag", 4, "+25 Chips per die scored", per("chips", 25, function(c) return c.size end))
add("chips", "loaded_dice", "Loaded Dice", 5, "15 or more pips scored: +200 Chips",
    when(function(c) return pips(c) >= 15 end, { chips = 200 }))
add("chips", "small_fry", "Small Fry", 4, "5 pips or less scored: +120 Chips",
    when(function(c) return pips(c) <= 5 end, { chips = 120 }))
add("chips", "marathon", "Marathon", 5, "+80 Chips per earlier score this round", per("chips", 80, earlier))
add("chips", "rainy_day", "Rainy Day", 5, "+15 Chips per $1 held (max 300)",
    per("chips", 15, function(c) return math.min(20, c.money or 0) end))
add("chips", "stacked", "Stacked", 5, "Four of a kind: +300 Chips", when(has("four_kind"), { chips = 300 }))
add("chips", "house_key", "House Key", 5, "Four + a pair: +500 Chips", when(has("four_pair"), { chips = 500 }))
add("chips", "spare_parts", "Spare Parts", 4, "+40 Chips per die left unscored",
    per("chips", 40, function(c) return c.dice_left or 0 end))
add("chips", "stepladder", "Stepladder", 5, "+50 Chips per floor reached", per("chips", 50, function(c) return c.floor or 1 end))
add("chips", "bookends", "Bookends", 4, "Score a 1 and a 5: +150 Chips",
    when(function(c) return c.faces[1] > 0 and c.faces[5] > 0 end, { chips = 150 }))
add("chips", "empty_chair", "Empty Chair", 4, "+100 Chips per empty joker slot",
    per("chips", 100, function(c) return (c.max_jokers or 5) - (c.joker_count or 1) end))
add("chips", "snowball", "Snowball", 5, "Gains +8 Chips on every score", per("chips", 1, grown), {
    after = function(self) self.n = self.n + 8 end,
    info = function(self) return ("Now +%d Chips"):format(self.n) end,
})

-- ===== mult =====
add("mult", "quintet", "Quintet", 6, "Five of a kind: +15 Mult", when(has("five_kind"), { mult = 15 }))
add("mult", "double_trouble", "Double Trouble", 6, "Two triples: +16 Mult", when(has("two_triples"), { mult = 16 }))
add("mult", "top_dog", "Top Dog", 5, "+2 Mult per 1 scored", perFace(1, "mult", 2))
add("mult", "pentagon", "Pentagon", 4, "+1 Mult per 5 scored", perFace(5, "mult", 1))
add("mult", "triangle", "Triangle", 4, "+2 Mult per 3 scored", perFace(3, "mult", 2))
add("mult", "rubber_duck", "Rubber Duck", 4, "+2 Mult per 2 scored", perFace(2, "mult", 2))
add("mult", "quartz", "Quartz", 4, "+2 Mult per 4 scored", perFace(4, "mult", 2))
add("mult", "fruit_machine", "Fruit Machine", 4, "+1 to +10 Mult at random", function() return { mult = math.random(1, 10) } end)
add("mult", "momentum", "Momentum", 5, "+3 Mult per earlier score this round", per("mult", 3, earlier))
add("mult", "night_owl", "Night Owl", 5, "Last 2 rounds of a floor: +5 Mult",
    when(function(c) return (c.rounds_left or 9) <= 2 end, { mult = 5 }))
add("mult", "penny_pincher", "Penny Pincher", 4, "$4 or less held: +4 Mult",
    when(function(c) return (c.money or 0) <= 4 end, { mult = 4 }))
add("mult", "high_society", "High Society", 6, "$20 or more held: +8 Mult",
    when(function(c) return (c.money or 0) >= 20 end, { mult = 8 }))
add("mult", "mountaineer", "Mountaineer", 5, "+1 Mult per floor reached", per("mult", 1, function(c) return c.floor or 1 end))
add("mult", "underdog", "Underdog", 4, "Below half the target: +4 Mult",
    when(function(c) return (c.floor_score or 0) < (c.target or 1) / 2 end, { mult = 4 }))
add("mult", "home_stretch", "Home Stretch", 4, "Past 75% of the target: +8 Mult",
    when(function(c) return (c.floor_score or 0) >= (c.target or 1) * 0.75 end, { mult = 8 }))
add("mult", "medley", "Medley", 4, "2 or more combos at once: +5 Mult", when(function(c) return #c.entries >= 2 end, { mult = 5 }))
add("mult", "snowflake", "Snowflake", 4, "2+ dice, all different: +5 Mult", when(function(c)
    if c.size < 2 then return false end
    for f = 1, 6 do if c.faces[f] > 1 then return false end end
    return true
end, { mult = 5 }))
add("mult", "odd_one_out", "Odd One Out", 4, "Odd number of dice scored: +3 Mult", when(function(c) return c.size % 2 == 1 end, { mult = 3 }))
add("mult", "good_company", "Good Company", 4, "Even number of dice scored: +4 Mult", when(function(c) return c.size % 2 == 0 end, { mult = 4 }))
add("mult", "scar_tissue", "Scar Tissue", 5, "+2 Mult per Farkle this run", per("mult", 2, function(c) return c.stats and c.stats.farkles or 0 end))
add("mult", "vending", "Vending", 5, "+2 Mult per shop reroll this run", per("mult", 2, function(c) return c.stats and c.stats.rerolls or 0 end))
add("mult", "garage_sale", "Garage Sale", 5, "+3 Mult per joker sold this run", per("mult", 3, function(c) return c.stats and c.stats.sold or 0 end))

local function showMult(self) return ("Now +%d Mult"):format(self.n) end
add("mult", "sprout", "Sprout", 5, "Gains +1 Mult on every bank", per("mult", 1, grown), {
    on_bank = function(self) self.n = self.n + 1 end, info = showMult,
})
add("mult", "furnace", "Furnace", 6, "Gains +3 Mult on every Hot Dice", per("mult", 1, grown), {
    after = function(self, ctx) if ctx.dice_left == 0 then self.n = self.n + 3 end end, info = showMult,
})
add("mult", "candle", "Candle", 4, "+6 Mult, loses 1 every round", per("mult", 1, grown), {
    start = 6, on_round = function(self) self.n = math.max(0, self.n - 1) end, info = showMult,
})
add("mult", "hot_streak", "Hot Streak", 5, "+2 Mult per bank in a row without a Farkle", per("mult", 1, grown), {
    on_bank = function(self) self.n = self.n + 2 end, on_farkle = function(self) self.n = 0 end, info = showMult,
})
add("mult", "straight_edge", "Straight Edge", 6, "Gains +3 Mult per straight scored", per("mult", 1, grown), {
    after = function(self, ctx) if straight(ctx) then self.n = self.n + 3 end end, info = showMult,
})

-- ===== x mult =====
add("xmult", "trophy", "Trophy", 8, "Gains x0.25 Mult per floor cleared", function(_, self)
    if self.n > 0 then return { xmult = 1 + 0.25 * self.n } end
end, {
    on_floor = function(self) self.n = self.n + 1 end,
    info = function(self) return ("Now x%.2f Mult"):format(1 + 0.25 * self.n) end,
})
add("xmult", "solo_act", "Solo Act", 6, "Your only joker: x3 Mult", when(function(c) return c.joker_count == 1 end, { xmult = 3 }))
add("xmult", "full_table", "Full Table", 7, "All joker slots full: x1.5 Mult",
    when(function(c) return (c.joker_count or 0) >= (c.max_jokers or 5) end, { xmult = 1.5 }))
add("xmult", "daredevil", "Daredevil", 7, "Exactly 1 die left unscored: x2 Mult", when(function(c) return c.dice_left == 1 end, { xmult = 2 }))
add("xmult", "clean_sweep", "Clean Sweep", 7, "No dice left unscored: x2 Mult", when(function(c) return c.dice_left == 0 end, { xmult = 2 }))
add("xmult", "third_time", "Third Time", 6, "Third score of a round: x2 Mult", when(function(c) return c.score_index == 3 end, { xmult = 2 }))
add("xmult", "jackpot", "Jackpot", 7, "3 or more 6s scored: x2.5 Mult", when(function(c) return c.faces[6] >= 3 end, { xmult = 2.5 }))
add("xmult", "lucky_seven", "Lucky Seven", 6, "Scored pips divisible by 7: x2 Mult", when(function(c) return pips(c) % 7 == 0 end, { xmult = 2 }))
add("xmult", "coin_flip", "Coin Flip", 5, "1 in 2 chance: x2 Mult", when(function() return math.random(2) == 1 end, { xmult = 2 }))
add("xmult", "snake_oil", "Snake Oil", 6, "1000+ round score: x1.5 Mult", when(function(c) return (c.round_score or 0) >= 1000 end, { xmult = 1.5 }))
add("xmult", "red_carpet", "Red Carpet", 8, "Any straight: x2 Mult", when(straight, { xmult = 2 }))
add("xmult", "six_shooter", "Six Shooter", 9, "Six of a kind: x5 Mult", when(has("six_kind"), { xmult = 5 }))
add("xmult", "flat_broke", "Flat Broke", 6, "$0 held: x2.5 Mult", when(function(c) return c.money == 0 end, { xmult = 2.5 }))
add("xmult", "mirror", "Mirror", 8, "Copies the joker to its left", function(ctx)
    local left = ctx.jokers and ctx.jokers[ctx.slot - 1]
    if left and left.effect and left.id ~= "mirror" then return left.effect(ctx, left) end
end)

-- ===== money =====
add("money", "tip_jar", "Tip Jar", 5, "4 or more dice scored: earn $1", when(function(c) return c.size >= 4 end, { money = 1 }))
add("money", "busker", "Busker", 5, "Three of a kind: earn $1", when(has("three_kind"), { money = 1 }))
add("money", "hot_tip", "Hot Tip", 5, "No dice left unscored: earn $3", when(function(c) return c.dice_left == 0 end, { money = 3 }))
add("money", "landlord", "Landlord", 6, "+$1 per joker owned after each floor", nil, { payout = function(c) return #c.player.jokers end })
add("money", "overachiever", "Overachiever", 5, "+$1 per 25% over the target (max $6)", nil, {
    payout = function(c)
        return math.min(6, math.floor((c.fm.score - c.fm.target) / (c.fm.target * 0.25)))
    end,
})
add("money", "fine_wine", "Fine Wine", 4, "Sell value +$2 after each floor", nil, {
    on_floor = function(self) self.bonus_sell = (self.bonus_sell or 0) + 2 end,
})
add("money", "insurance", "Insurance", 4, "Earn $2 on every Farkle", nil, { on_farkle = function(_, player) player:add_money(2) end })
add("money", "trust_fund", "Trust Fund", 6, "Interest cap raised by $5", nil, { interest_cap = 5 })

-- ===== utility =====
add("utility", "safety_net", "Safety Net", 7, "Farkle: keep half the round score", nil, { farkle_keep = 0.5 })
add("utility", "overtime", "Overtime", 7, "+1 round on every floor", nil, { extra_rounds = 1 })
add("utility", "second_wind", "Second Wind", 6, "First Farkle of a floor costs no round", nil, {
    free_farkle = true,
    on_floor = function(self) self.used = false end,
    info = function(self) return self.used and "Used on this floor" or "Ready" end,
})
add("utility", "bargain_bin", "Bargain Bin", 5, "Shop jokers cost $1 less", nil, { discount = 1 })
add("utility", "window_shopper", "Window Shopper", 5, "+1 joker on sale in every shop", nil, { extra_offers = 1 })
add("utility", "haggler", "Haggler", 4, "Shop rerolls cost $3 less", nil, { reroll_discount = 3 })
add("utility", "pawn_ticket", "Pawn Ticket", 5, "Other jokers sell for what you paid", nil, { full_sell = true })

---------------------------------------------------------------------------
-- Jokers for special dice, combo upgrades and one-use cards.
-- More ctx: ctx.types[id] / ctx.special (scored dice by type / special ones), ctx.owned_special, ctx.owned_kinds,
-- ctx.upgrades (all combo upgrades), ctx.combo_level(id), ctx.cards (held). Hook: on_consume(self, player, card)
-- Perks: card_slots, card_discount, extra_cards, no_crack
---------------------------------------------------------------------------
local function ofType(id) return function(c) return c.types[id] or 0 end end
local function cards(c) return c.cards or 0 end
local function sameCombo(self, c) return c.entries[1] and c.entries[1].id == self.last end
local function showX(step)
    return function(self) return ("Now x%.2f Mult"):format(1 + step * self.n) end
end
local function grownX(step)
    return function(_, self) if self.n > 0 then return { xmult = 1 + step * self.n } end end
end

-- ===== chips =====
add("chips", "gemcutter", "Gemcutter", 5, "+60 Chips per special die scored", per("chips", 60, function(c) return c.special end))
add("chips", "blue_blood", "Blue Blood", 5, "+100 Chips per Sapphire Die scored", per("chips", 100, ofType("sapphire")))
add("chips", "plain_jane", "Plain Jane", 4, "+30 Chips per plain die scored", per("chips", 30, ofType("plain")))
add("chips", "bookworm", "Bookworm", 5, "+20 Chips per combo upgrade", per("chips", 20, function(c) return c.upgrades or 0 end))
add("chips", "deep_pockets", "Deep Pockets", 4, "+80 Chips per card held", per("chips", 80, cards))
add("chips", "big_spender", "Big Spender", 5, "+3 Chips per $1 spent this run (max 300)",
    per("chips", 3, function(c) return math.min(100, c.stats and c.stats.spent or 0) end))
add("chips", "countdown", "Countdown", 4, "+30 Chips per round left", per("chips", 30, function(c) return c.rounds_left or 0 end))
add("chips", "sandcastle", "Sandcastle", 4, "+200 Chips, loses 10 every round", per("chips", 1, grown), {
    start = 200, on_round = function(self) self.n = math.max(0, self.n - 10) end,
    info = function(self) return ("Now +%d Chips"):format(self.n) end,
})
add("chips", "checkerboard", "Checkerboard", 4, "As many odd as even dice: +140 Chips",
    when(function(c) return (c.faces[1] + c.faces[3] + c.faces[5]) * 2 == c.size end, { chips = 140 }))
add("chips", "high_low", "High-Low", 4, "Score a 1 and a 6: +160 Chips",
    when(function(c) return c.faces[1] > 0 and c.faces[6] > 0 end, { chips = 160 }))

-- ===== mult =====
add("mult", "red_alert", "Red Alert", 5, "+4 Mult per Ruby Die scored", per("mult", 4, ofType("ruby")))
add("mult", "blacksmith", "Blacksmith", 5, "+4 Mult per Iron Die left unscored", per("mult", 4, function(c)
    local n = 0
    for _, d in ipairs(c.table or {}) do if d.type == "iron" then n = n + 1 end end
    return n
end))
add("mult", "scholar", "Scholar", 5, "+1 Mult per combo upgrade", per("mult", 1, function(c) return c.upgrades or 0 end))
add("mult", "pack_rat", "Pack Rat", 4, "+3 Mult per card held", per("mult", 3, cards))
add("mult", "curator", "Curator", 5, "+2 Mult per kind of special die owned", per("mult", 2, function(c) return c.owned_kinds or 0 end))
add("mult", "purist", "Purist", 5, "No special dice owned: +7 Mult", when(function(c) return (c.owned_special or 0) == 0 end, { mult = 7 }))
add("mult", "warm_up", "Warm Up", 4, "First score of a round: +4 Mult", when(function(c) return c.score_index == 1 end, { mult = 4 }))
add("mult", "slow_burn", "Slow Burn", 5, "Fourth score of a round or later: +14 Mult", when(function(c) return (c.score_index or 1) >= 4 end, { mult = 14 }))
add("mult", "middle_child", "Middle Child", 4, "+1 Mult per 3 or 4 scored", per("mult", 1, function(c) return c.faces[3] + c.faces[4] end))
add("mult", "tightrope", "Tightrope", 4, "1 or 2 dice left unscored: +6 Mult",
    when(function(c) return c.dice_left == 1 or c.dice_left == 2 end, { mult = 6 }))
add("mult", "broken_record", "Broken Record", 5, "Same combo as your last score: +6 Mult", function(c, self)
    if sameCombo(self, c) then return { mult = 6 } end
end, { after = function(self, c) self.last = c.entries[1] and c.entries[1].id end })
add("mult", "comeback", "Comeback Kid", 5, "+10 Mult until you bank, after a Farkle", per("mult", 1, grown), {
    on_farkle = function(self) self.n = 10 end, on_bank = function(self) self.n = 0 end,
    info = function(self) return self.n > 0 and "Active" or "Waiting for a Farkle" end,
})
add("mult", "metronome", "Metronome", 5, "Every third score: +12 Mult", function(_, self)
    if self.n % 3 == 2 then return { mult = 12 } end
end, {
    after = function(self) self.n = self.n + 1 end,
    info = function(self) return self.n % 3 == 2 and "Next score!" or ("%d to go"):format(3 - self.n % 3) end,
})
add("mult", "librarian", "Librarian", 5, "Gains +2 Mult per combo card used", per("mult", 1, grown), {
    on_consume = function(self, _, card) if card.kind == "combo" then self.n = self.n + 2 end end, info = showMult,
})
add("mult", "mystic", "Mystic", 5, "Gains +2 Mult per charm used", per("mult", 1, grown), {
    on_consume = function(self, _, card) if card.kind == "charm" then self.n = self.n + 2 end end, info = showMult,
})

-- ===== x mult =====
add("xmult", "chandelier", "Chandelier", 7, "x1.3 Mult per Crystal Die scored", function(c)
    local n = c.types.crystal or 0
    if n > 0 then return { xmult = 1.3 ^ n } end
end)
add("xmult", "prism", "Prism", 8, "3 kinds of special dice owned: x2 Mult", when(function(c) return (c.owned_kinds or 0) >= 3 end, { xmult = 2 }))
add("xmult", "wild_side", "Wild Side", 7, "Wild Die scored: x1.75 Mult", when(function(c) return (c.types.wild or 0) > 0 end, { xmult = 1.75 }))
add("xmult", "specialist", "Specialist", 8, "Combo of level 4+ scored: x2 Mult", when(function(c)
    for _, e in ipairs(c.entries) do if c.combo_level and c.combo_level(e.id) >= 4 then return true end end
end, { xmult = 2 }))
add("xmult", "empty_hands", "Empty Hands", 6, "No cards held: x1.5 Mult", when(function(c) return cards(c) == 0 end, { xmult = 1.5 }))
add("xmult", "tycoon", "Tycoon", 8, "$30 or more held: x2 Mult", when(function(c) return (c.money or 0) >= 30 end, { xmult = 2 }))
add("xmult", "cliffhanger", "Cliffhanger", 7, "Last round of a floor: x2 Mult", when(function(c) return c.rounds_left == 1 end, { xmult = 2 }))
add("xmult", "ritual", "Ritual", 7, "Gains x0.1 Mult per card used", grownX(0.1), {
    on_consume = function(self) self.n = self.n + 1 end, info = showX(0.1),
})
add("xmult", "grand_slam", "Grand Slam", 8, "Gains x0.2 Mult per 6 dice scored at once", grownX(0.2), {
    after = function(self, c) if c.size == 6 then self.n = self.n + 1 end end, info = showX(0.2),
})

-- ===== money =====
add("money", "goldsmith", "Goldsmith", 5, "Gold Dice earn $1 more", per("money", 1, ofType("gold")))
add("money", "toll_road", "Toll Road", 5, "Any straight: earn $2", when(straight, { money = 2 }))
add("money", "scholarship", "Scholarship", 5, "Earn $1 per combo card used", nil, {
    on_consume = function(_, player, card) if card.kind == "combo" then player:add_money(1) end end,
})
add("money", "museum", "Museum", 6, "+$1 per special die owned after each floor", nil, { payout = function(c) return (c.player:special_dice()) end })
add("money", "tenure", "Tenure", 6, "+$1 per 3 combo upgrades after each floor (max $6)", nil, {
    payout = function(c) return math.min(6, math.floor(c.player:total_upgrades() / 3)) end,
})

-- ===== utility =====
add("utility", "extra_shelf", "Extra Shelf", 5, "+1 card slot", nil, { card_slots = 1 })
add("utility", "coupon", "Coupon", 4, "Shop cards cost $1 less", nil, { card_discount = 1 })
add("utility", "newsstand", "Newsstand", 5, "+1 card on sale in every shop", nil, { extra_cards = 1 })
add("utility", "bubble_wrap", "Bubble Wrap", 5, "Crystal Dice never crack", nil, { no_crack = 1 })
add("utility", "care_package", "Care Package", 6, "Floor cleared: get a random card", nil, {
    on_floor = function(_, player) player:add_consumable(require("core.consumables").random()) end,
})
add("utility", "study_group", "Study Group", 6, "Floor cleared: upgrades a random combo", nil, {
    on_floor = function(_, player)
        local list = require("core.combos").LIST
        player:upgrade_combo(list[math.random(#list)].id, math.random(2) == 1 and "chips" or "mult")
    end,
})
add("utility", "dice_maker", "Dice Maker", 7, "Floor cleared: 1 in 2 to improve a plain die", nil, {
    on_floor = function(_, player)
        local plain = {}
        for i, id in ipairs(player.dice) do if id == "plain" then plain[#plain + 1] = i end end
        if #plain > 0 and math.random(2) == 1 then
            player.dice[plain[math.random(#plain)]] = require("core.dice_types").random().id
        end
    end,
})

return Jokers
