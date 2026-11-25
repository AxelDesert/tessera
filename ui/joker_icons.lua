-- Pixel-art joker icons, 24x24, drawn in code when the game starts.
--   JokerIcons.load()                      once, after Theme.load
--   JokerIcons.draw(id, cx, cy, scale)     centered on (cx, cy)
--
-- Want to draw one by hand? Put a PNG at assets/jokers/<id>.png and it is used instead.
--
-- Each icon is a list of shapes separated by ";", painted in order (pixels, 0-23):
--   r C x y w h        rectangle            o C x y radius     disc
--   l C x1 y1 x2 y2    2px line             p C x y x y x y..  polygon
--   d C x y size face  die (C = body color) n C x y text       tiny digits / symbols
-- C is one letter of COLORS ("_" erases). A dark outline and a shaded bottom edge are added.

local JokerIcons = {}

local SIZE = 24
local COLORS = {
    w = { 255, 255, 255 }, k = { 66, 84, 85 },   b = { 1, 146, 249 },  r = { 254, 76, 64 },
    y = { 253, 190, 60 },  o = { 255, 140, 20 }, g = { 80, 200, 110 }, G = { 40, 140, 80 },
    p = { 165, 105, 235 }, s = { 190, 200, 216 }, S = { 120, 135, 160 }, n = { 150, 95, 55 },
    N = { 100, 62, 40 },   c = { 140, 220, 255 }, m = { 255, 150, 180 }, d = { 30, 43, 70 },
    t = { 240, 205, 160 }, R = { 180, 40, 45 },  B = { 30, 85, 190 },
}
local OUTLINE = { 30, 38, 52 }

local ART = {
    -- chips
    pocket_change  = "o S 9 16 6;o s 9 14 6;o y 16 9 6;r o 15 6 2 7",
    snake_eyes     = "d w 2 5 13 1;d w 11 9 11 1",
    five_alive     = "o g 12 12 9;d w 7 7 11 5",
    odd_todd       = "o t 12 13 8;r n 5 4 14 5;r w 7 11 4 3;r w 13 11 4 3;r d 9 12 2 2;r d 15 12 2 2;r R 9 17 7 2",
    pip_counter    = "r S 3 4 18 16;r d 5 6 14 12;o r 9 9 2;o y 15 9 2;o b 9 15 2;o g 15 15 2",
    trio           = "d w 7 2 10 3;d w 2 12 10 3;d w 12 12 10 3",
    ladder         = "r n 5 2 3 20;r n 16 2 3 20;r y 8 5 8 2;r y 8 10 8 2;r y 8 15 8 2",
    loose_deuces   = "d w 2 3 12 2;d c 10 10 12 2",
    threepenny     = "o o 12 12 9;o y 12 12 7;n N 10 9 3;r N 5 11 2 2;r N 17 11 2 2",
    four_leaf      = "l G 12 12 15 21;o g 8 7 4;o g 16 7 4;o g 8 14 4;o g 16 14 4;r G 11 9 2 4",
    six_pack       = "r b 3 8 5 12;r r 9 8 6 12;r b 16 8 5 12;r s 4 6 3 2;r s 11 6 3 2;r s 17 6 3 2;l k 3 13 20 13",
    dice_bag       = "o n 12 15 7;r n 8 6 8 4;r y 7 9 10 2;d w 8 12 8 5",
    loaded_dice    = "d r 4 4 16 6;r S 4 19 16 3",
    small_fry      = "p r 5 10 19 10 17 21 7 21;r y 6 4 3 8;r y 11 2 3 10;r y 16 5 2 7",
    marathon       = "p r 2 13 8 8 14 13 21 14 21 18 2 18;r w 2 18 19 3;l w 9 11 12 13",
    rainy_day      = "r n 11 11 2 9;r n 13 18 3 2;o b 12 11 9;r _ 1 12 10 10;r _ 13 12 10 6;r c 11 3 2 8",
    stacked        = "r r 5 17 14 4;r w 10 17 4 4;r b 5 12 14 4;r w 10 12 4 4;r g 5 7 14 4;r w 10 7 4 4;r y 5 2 14 4",
    house_key      = "o y 8 8 6;o _ 8 8 2;l y 12 12 19 19;l y 16 19 18 17;l y 13 16 15 14",
    spare_parts    = "r S 10 2 4 20;r S 2 10 20 4;r S 5 5 14 14;o s 12 12 6;o _ 12 12 3",
    stepladder     = "r b 2 16 20 5;r c 8 11 14 5;r w 14 6 8 5",
    bookends       = "r n 2 5 3 16;r n 19 5 3 16;r r 6 7 4 14;r y 10 5 4 16;r b 14 8 4 13",
    empty_chair    = "r n 6 2 3 19;r n 6 11 12 3;r n 15 13 3 8;r r 9 4 2 6",
    snowball       = "o c 12 13 9;o w 10 11 6",
    -- mult
    two_is_company = "o b 7 7 4;r b 3 12 8 9;o r 17 7 4;r r 13 12 8 9",
    number_one     = "r y 5 14 14 7;r w 8 4 8 10;n r 10 6 1;r o 5 18 14 3",
    lone_wolf      = "p S 4 2 9 7 15 7 20 2 20 13 12 21 4 13;r y 7 10 3 2;r y 14 10 3 2;r d 11 17 3 3",
    sixer          = "o R 12 12 9;d w 6 6 12 6",
    low_roller     = "p g 3 8 21 8 12 21;r g 8 2 8 7",
    triple_threat  = "p r 5 3 9 13 1 13;p r 12 8 16 20 8 20;p r 19 3 22 13 15 13",
    even_steven    = "o t 12 13 8;r b 4 4 16 4;r w 7 11 4 3;r w 13 11 4 3;r d 8 12 2 2;r d 14 12 2 2;r d 9 17 6 1",
    top_heavy      = "r r 3 3 18 9;p S 8 12 16 12 13 21 11 21",
    straight_shooter = "o r 11 13 8;o w 11 13 5;o r 11 13 2;l n 11 13 20 4;p g 18 2 22 2 22 6",
    quad_squad     = "d w 2 2 9 4;d r 13 2 9 4;d r 2 13 9 4;d w 13 13 9 4",
    full_set       = "d w 1 4 6 1;d w 9 4 6 1;d w 17 4 6 1;d y 1 14 6 1;d y 9 14 6 1;d y 17 14 6 1",
    quintet        = "l k 8 6 8 18;l k 18 4 18 16;r k 8 4 12 3;o r 6 18 4;o r 16 16 4",
    double_trouble = "p r 3 2 7 6 3 10;p r 21 2 17 6 21 10;o r 12 13 8;r y 8 11 3 3;r y 14 11 3 3;r d 9 17 7 2",
    top_dog        = "o n 12 14 7;p N 3 5 8 8 5 15;p N 21 5 16 8 19 15;r d 9 12 2 2;r d 14 12 2 2;o d 12 17 2;p y 7 2 9 5 12 1 15 5 17 2 17 7 7 7",
    pentagon       = "p p 12 1 22 9 18 21 6 21 2 9;n w 10 10 5",
    triangle       = "p y 12 2 22 21 2 21;p _ 12 9 17 18 7 18",
    rubber_duck    = "o y 11 15 7;o y 14 8 5;r o 18 8 4 2;r d 15 6 2 2;p o 4 12 10 13 8 18",
    quartz         = "p m 9 2 13 6 13 21 5 21 5 6;p p 17 9 21 12 20 21 14 21 14 12;l w 8 7 8 17",
    fruit_machine  = "r r 3 3 16 18;r w 5 7 12 7;n R 6 8 7;n R 10 8 7;n R 14 8 7;r s 20 7 2 8;o y 20 6 2;r y 6 17 10 2",
    momentum       = "p o 3 4 11 12 3 20;p r 11 4 20 12 11 20",
    night_owl      = "o n 12 13 8;p n 4 3 10 7 5 10;p n 20 3 14 7 19 10;o w 8 11 3;o w 16 11 3;r d 8 11 2 2;r d 15 11 2 2;p y 10 14 14 14 12 18",
    penny_pincher  = "l S 5 3 12 14;l S 18 3 11 14;o s 12 16 1;o o 12 18 4;r y 11 16 2 5",
    high_society   = "r d 7 3 10 13;r r 7 12 10 3;r d 2 16 20 4",
    mountaineer    = "p S 12 2 22 21 2 21;p w 12 2 16 10 12 9 8 10",
    underdog       = "o t 12 12 7;p n 3 6 8 7 6 17;p n 21 6 16 7 18 17;r d 9 11 2 2;r d 14 11 2 2;o d 12 15 1;r m 11 18 3 4",
    home_stretch   = "r n 4 2 2 20;r w 6 3 15 11;r d 6 3 4 4;r d 14 3 4 4;r d 10 7 4 3;r d 18 7 3 3;r d 6 10 4 4;r d 14 10 4 4",
    medley         = "o r 8 9 5;p y 14 4 22 12 13 13;r b 8 14 9 7",
    snowflake      = "l c 12 2 12 21;l c 3 7 21 16;l c 21 7 3 16;r w 10 10 4 4",
    odd_one_out    = "o s 6 7 4;o s 17 7 4;o s 6 17 4;o r 17 17 4",
    good_company   = "p r 12 21 2 10 2 5 7 2 12 6 17 2 22 5 22 10;r m 5 5 3 3",
    scar_tissue    = "r t 4 4 16 16;l R 6 17 17 6;l R 8 10 11 13;l R 12 7 15 10",
    vending        = "r r 4 2 16 20;r c 6 4 8 11;r d 16 5 2 4;r y 7 5 2 3;r g 11 5 2 3;r p 7 10 2 3;r d 6 17 8 3",
    garage_sale    = "p y 3 3 13 3 21 12 13 21 3 12;o w 7 7 2;n R 9 10 $",
    sprout         = "l G 12 10 12 17;p g 12 12 3 10 3 4 10 5;p g 12 10 14 3 21 3 20 9;p n 5 16 19 16 17 22 7 22",
    furnace        = "r S 3 3 18 18;r d 6 8 12 10;p o 7 18 12 8 17 18;p y 10 18 12 13 14 18;r k 6 5 12 1",
    candle         = "r w 8 11 8 10;p o 12 1 16 8 12 11 8 8;p y 12 5 14 8 12 10 10 8;r s 5 20 14 2",
    hot_streak     = "p r 13 1 20 12 17 21 7 21 4 13 8 8 10 11;p y 12 11 16 17 13 21 9 20 8 16",
    straight_edge  = "p y 2 17 17 2 22 7 7 22;l N 7 14 9 16;l N 11 10 13 12;l N 15 6 17 8",
    piggy_bank     = "o m 11 13 8;r m 4 18 4 4;r m 14 18 4 4;o m 19 13 3;r d 14 10 2 2;r d 8 5 6 1;p m 13 2 17 6 12 8",
    crowd          = "o b 5 9 3;r b 2 13 7 8;o g 19 9 3;r g 15 13 7 8;o r 12 7 4;r r 7 12 10 9",
    last_call      = "o y 12 10 7;r y 4 12 16 6;r o 3 17 18 2;r y 11 2 3 2;o o 12 20 2",
    -- x mult
    all_even       = "d p 2 2 12 2;d w 10 10 12 4",
    all_odd        = "d p 2 2 12 3;d w 10 10 12 5",
    big_hand       = "r t 5 4 3 10;r t 9 2 3 10;r t 13 3 3 10;r t 17 6 3 8;r t 5 11 15 8;r b 7 19 11 3;r t 2 12 4 4",
    twin_peaks     = "p S 8 4 16 21 1 21;p p 16 4 22 21 8 21;p w 8 4 11 10 5 10;p w 16 4 19 10 13 10",
    high_five      = "r m 5 5 3 9;r m 9 2 3 10;r m 13 2 3 10;r m 17 5 3 9;r m 5 11 15 10;n R 11 13 5",
    opening_move   = "o w 12 6 4;p w 9 8 15 8 18 18 6 18;r w 4 18 16 3",
    boss_slayer    = "l s 20 3 9 14;l s 19 2 8 13;l y 5 11 12 18;l n 7 16 3 20",
    trophy         = "r y 7 3 10 9;o y 12 11 5;l y 3 5 5 10;l y 19 5 17 10;r o 11 14 2 5;r n 7 18 10 4;r w 9 5 2 5",
    solo_act       = "r S 11 11 3 11;o k 12 6 5;r s 8 5 9 1;r s 8 8 9 1;r k 7 20 10 2",
    full_table     = "o n 12 12 10;o G 12 12 8;r w 9 4 6 3;r w 9 17 6 3;r w 4 10 3 5;r w 17 10 3 5;o r 12 12 2",
    daredevil      = "o r 12 12 9;r w 11 3 3 18;r c 5 9 15 6;r d 5 12 15 2",
    clean_sweep    = "l n 18 2 12 11;p y 8 10 15 13 14 21 3 18;l o 8 14 6 18;l o 12 15 11 19",
    third_time     = "o g 12 12 10;o w 12 12 8;n G 10 10 3",
    jackpot        = "p c 6 4 18 4 22 10 12 21 2 10;p w 8 5 13 5 11 9 5 9;l b 3 10 20 10",
    lucky_seven    = "p r 4 2 20 2 20 8 13 21 7 21 13 8 4 8",
    coin_flip      = "o o 12 12 9;o y 11 12 7;p o 11 6 13 10 17 11 14 14 15 18 11 16 7 18 8 14 5 11 9 10",
    snake_oil      = "r n 10 1 4 4;r G 9 5 6 4;r g 6 9 12 13;r w 7 12 10 7;l G 9 15 11 13;l G 12 16 14 14",
    red_carpet     = "p r 8 3 16 3 22 21 2 21;r y 3 3 3 12;r y 18 3 3 12;l R 10 8 14 8;l R 8 15 16 15",
    six_shooter    = "r S 3 6 18 4;r s 8 5 6 7;p n 5 10 10 10 7 20 2 20;l k 11 12 13 14",
    flat_broke     = "r n 3 7 18 13;r N 3 11 18 2;p d 8 2 14 2 16 8 6 8;p c 10 4 13 5 11 7",
    mirror         = "o y 12 9 8;o c 12 9 6;l w 9 10 13 6;r y 10 16 4 6",
    -- money
    early_bird     = "o b 11 13 7;o b 14 8 4;p o 18 7 23 9 18 10;r d 15 6 2 2;p B 2 10 11 13 7 18;r w 9 17 5 2",
    boss_bounty    = "r t 4 2 16 20;o R 12 10 4;r d 10 9 1 2;r d 13 9 1 2;n R 10 16 $;r n 6 4 12 1",
    golden_die     = "d y 4 4 16 5",
    investor       = "r G 2 18 20 3;r g 4 13 4 5;r g 10 9 4 9;r g 16 4 4 14;l y 4 9 10 5;l y 10 5 14 2",
    tip_jar        = "r s 7 2 10 3;r c 5 5 14 16;o y 10 17 3;o y 14 16 3;o o 12 12 3",
    busker         = "o n 8 16 6;o n 12 11 4;o N 9 15 2;l N 12 10 19 3;r k 18 1 4 4",
    hot_tip        = "r g 2 8 20 12;r w 4 10 16 8;o g 12 14 3;p o 12 1 15 6 12 8 9 6",
    landlord       = "p r 12 2 22 11 2 11;r t 5 11 14 10;r n 10 14 4 7;r c 6 13 3 3;r c 15 13 3 3",
    overachiever   = "p y 12 1 15 8 22 9 17 14 18 21 12 18 6 21 7 14 2 9 9 8;n R 10 10 +",
    fine_wine      = "r G 10 2 4 6;r G 7 8 10 14;r w 8 12 8 6;o R 12 15 2",
    insurance      = "p b 3 3 21 3 21 12 12 22 3 12;r w 10 6 4 11;r w 7 9 10 4",
    trust_fund     = "r S 3 3 18 17;r s 5 5 14 13;o k 12 11 4;r y 11 8 2 7;r y 8 10 8 2;r k 4 20 4 2;r k 16 20 4 2",
    -- utility
    safety_net     = "r n 2 5 3 17;r n 19 5 3 17;l w 5 9 12 14;l w 12 14 18 9;l w 5 14 12 19;l w 12 19 18 14;d r 8 2 8 4",
    overtime       = "o r 6 5 3;o r 18 5 3;o r 12 13 9;o w 12 13 7;l d 12 8 12 13;l d 12 13 16 14",
    second_wind    = "l c 2 8 14 8;l c 14 8 16 5;l c 2 12 19 12;l c 19 12 20 16;l c 4 16 12 16;l c 12 16 13 19",
    bargain_bin    = "p r 3 10 21 10 19 21 5 21;r y 5 5 5 5;r b 11 3 5 7;r g 17 6 3 4;n w 10 13 %",
    window_shopper = "r n 3 8 18 13;r c 5 12 8 7;r N 15 12 4 9;r r 2 3 5 6;r w 7 3 5 6;r r 12 3 5 6;r w 17 3 5 6",
    haggler        = "r w 2 3 13 9;p w 4 11 9 11 4 16;r y 10 11 12 8;p y 16 18 20 18 20 22;n R 6 5 $;n R 14 13 $",
    pawn_ticket    = "l y 4 4 19 4;r y 11 2 2 3;l y 5 4 5 9;l y 18 4 18 9;l y 11 4 11 12;o y 5 12 4;o y 18 12 4;o y 12 17 4",
    -- jokers: dice, upgrades, cards
    gemcutter      = "p b 6 4 18 4 22 10 12 21 2 10;p c 8 5 13 5 11 9 5 9;l S 14 20 21 13;r n 18 15 4 6",
    blue_blood     = "p b 12 1 20 13 19 19 12 22 5 19 4 13;o c 9 15 2",
    plain_jane     = "o n 12 9 8;r n 4 9 16 11;o t 12 11 6;r d 9 10 2 2;r d 14 10 2 2;r R 10 15 4 1",
    bookworm       = "r r 3 14 18 7;r w 5 16 15 3;o g 7 10 3;o g 12 8 3;o g 17 6 4;r d 18 5 2 2",
    deep_pockets   = "r b 3 5 18 16;r B 5 11 14 9;r y 5 11 14 1;r w 8 2 6 9;r r 10 4 2 3",
    big_spender    = "r g 2 9 15 10;r g 7 4 15 10;r w 9 6 11 6;n G 13 7 $",
    countdown      = "r n 5 2 14 3;r n 5 19 14 3;p c 6 5 18 5 12 12;p c 12 11 18 19 6 19;p y 12 14 17 19 7 19",
    sandcastle     = "r y 3 12 18 9;r y 3 8 4 5;r y 10 8 4 5;r y 17 8 4 5;r N 10 16 4 5;l n 12 2 12 7;p r 13 2 18 4 13 6",
    checkerboard   = "r w 3 3 18 18;r d 3 3 6 6;r d 15 3 6 6;r d 9 9 6 6;r d 3 15 6 6;r d 15 15 6 6",
    high_low       = "p g 8 2 14 10 2 10;r g 6 10 4 10;p r 16 22 22 13 10 13;r r 14 4 4 10",
    red_alert      = "o r 12 11 7;r r 5 11 14 7;r S 3 18 18 3;l y 2 4 4 6;l y 20 4 18 6;r m 9 7 3 5",
    blacksmith     = "r n 11 8 3 14;r S 4 3 16 7;r s 4 3 16 2",
    scholar        = "p d 12 3 23 8 12 13 1 8;r d 6 11 12 6;l y 20 9 20 16;o y 20 18 1",
    pack_rat       = "o S 12 13 7;o S 5 6 4;o S 19 6 4;o m 5 6 2;o m 19 6 2;r d 8 11 2 2;r d 14 11 2 2;o m 12 17 2",
    curator        = "r y 2 3 20 18;r d 5 6 14 12;p g 5 18 10 10 15 18;o y 15 9 2",
    purist         = "o w 12 12 9;o c 12 12 6;o w 12 12 3",
    warm_up        = "r r 4 9 13 12;o r 18 14 3;o _ 18 14 1;l w 7 3 7 7;l w 11 2 11 7;r m 6 11 2 7",
    slow_burn      = "r n 2 16 19 4;o o 19 15 4;o y 19 15 2;l s 14 4 16 9;l s 9 3 11 10",
    middle_child   = "o b 5 8 3;r b 2 12 6 9;o r 19 8 3;r r 16 12 6 9;o y 12 13 3;r y 9 16 6 5",
    tightrope      = "l n 1 17 22 17;o t 11 5 3;r r 9 8 5 6;l r 9 14 8 17;l r 13 14 14 17;l y 2 10 20 10",
    broken_record  = "o d 12 12 10;o S 12 12 7;o d 12 12 6;o r 12 12 3;l _ 13 2 16 7;l _ 16 7 14 10",
    comeback       = "p g 2 10 10 3 10 7 18 7 18 16 10 16 10 13 14 13 14 11 10 11 10 17",
    metronome      = "p n 9 2 15 2 20 21 4 21;p t 10 5 14 5 16 16 8 16;l R 12 16 17 4;r y 6 18 12 2",
    librarian      = "r r 3 4 4 17;r b 7 6 4 15;r g 11 3 4 18;r y 15 7 5 14;r w 3 8 4 1;r w 11 7 4 1",
    mystic         = "o p 12 10 8;o m 9 7 2;r n 6 18 12 3;r w 13 12 2 2;r w 10 10 1 1",
    chandelier     = "r y 11 1 2 6;r y 3 7 18 2;p c 3 9 7 9 5 17;p c 10 9 14 9 12 21;p c 17 9 21 9 19 17",
    prism          = "p w 10 4 18 19 2 19;l r 14 10 22 7;l y 15 13 22 13;l b 16 16 22 19",
    wild_side      = "o o 12 12 9;r d 11 3 3 5;r d 4 9 5 2;r d 15 9 5 2;r y 8 11 2 3;r y 14 11 2 3;p m 10 15 14 15 12 18",
    specialist     = "o y 12 9 7;o o 12 9 5;n w 11 7 4;p r 7 14 11 16 8 22 5 20;p r 17 14 13 16 16 22 19 20",
    empty_hands    = "r t 2 10 8 10;r t 3 5 2 6;r t 7 5 2 6;r t 14 10 8 10;r t 15 5 2 6;r t 19 5 2 6",
    tycoon         = "r d 7 1 10 5;r d 4 5 16 2;o t 12 12 6;r w 7 14 10 3;o y 15 11 2;r d 8 10 2 2;r R 9 19 6 2",
    cliffhanger    = "r n 2 3 10 18;p g 2 2 13 2 13 6 2 6;l t 13 8 17 12;o t 18 14 2;r r 16 16 4 5",
    ritual         = "l p 12 2 4 20;l p 12 2 20 20;l p 2 9 21 9;l p 2 9 19 20;l p 21 9 5 20;o y 12 12 2",
    grand_slam     = "l n 3 20 17 6;l n 4 20 18 6;l n 5 20 19 7;o w 18 17 4;r r 16 15 1 4;r r 20 15 1 4",
    goldsmith      = "p y 5 14 19 14 22 20 2 20;p o 9 7 15 7 18 13 6 13;r w 9 15 6 1",
    toll_road      = "r S 2 6 5 16;r w 6 9 16 4;r r 9 9 3 4;r r 15 9 3 4;r r 21 9 1 4;o r 4 4 2",
    scholarship    = "r w 3 4 18 12;l S 6 7 16 7;l S 6 10 13 10;o y 16 16 4;p r 14 18 19 18 18 23 15 23",
    museum         = "p s 12 2 22 9 2 9;r s 3 19 18 3;r w 5 10 3 9;r w 11 10 3 9;r w 16 10 3 9",
    tenure         = "r w 5 2 14 19;l S 7 6 15 6;l S 7 9 15 9;l S 7 12 12 12;o r 14 17 3;n y 13 15 $",
    extra_shelf    = "r n 2 9 20 3;r n 2 19 20 3;r r 5 3 5 6;r b 11 3 5 6;r y 5 13 5 6;l g 17 14 17 18;l g 15 16 19 16",
    coupon         = "r y 2 6 20 13;r o 8 6 1 13;n R 13 10 %;r _ 2 11 2 3;r _ 20 11 2 3",
    newsstand      = "r w 3 3 18 18;r d 5 5 14 3;r S 5 10 6 7;l S 13 10 18 10;l S 13 13 18 13;l S 13 16 18 16",
    bubble_wrap    = "r c 2 3 20 18;o w 6 7 2;o w 12 7 2;o w 18 7 2;o w 6 13 2;o w 12 13 2;o w 18 13 2;r w 4 17 16 2",
    care_package   = "r n 3 9 18 12;r r 11 9 3 12;p w 4 7 8 2 16 2 20 7;l S 5 7 9 11;l S 18 7 14 11",
    study_group    = "r b 2 11 9 9;r r 13 11 9 9;r w 3 12 7 6;r w 14 12 7 6;o y 12 5 4;r s 11 9 3 2",
    dice_maker     = "d y 2 8 12 5;l n 12 14 20 4;r S 16 2 6 5",
    -- special dice (shop) and the badges shown on them
    die_plain      = "d w 4 4 16 5",   die_sapphire = "d b 4 4 16 5",  die_ruby    = "d r 4 4 16 5",
    die_gold       = "d y 4 4 16 5",   die_iron     = "d S 4 4 16 5",  die_crystal = "d c 4 4 16 5;l w 6 12 12 6",
    die_loaded     = "d p 4 4 16 1;r S 4 18 16 3", die_heavy = "d o 4 4 16 6", die_magnet = "d m 4 4 16 2",
    die_phoenix    = "d o 4 7 14 3;p r 12 1 17 7 8 7;p y 12 3 14 7 10 7",
    die_wild       = "d g 4 4 16 1;p y 12 5 14 10 19 11 15 14 16 19 12 16 8 19 9 14 5 11 10 10",
    badge_sapphire = "p b 6 4 18 4 22 10 12 21 2 10;p c 8 5 13 5 11 9 5 9",
    badge_ruby     = "p r 12 2 21 8 21 15 12 22 3 15 3 8;p m 12 5 16 9 8 9",
    badge_gold     = "o o 12 12 9;o y 11 11 7;n R 10 9 $",
    badge_iron     = "p S 4 6 20 6 22 11 15 13 17 20 7 20 9 13 4 11;r s 5 7 13 1",
    badge_crystal  = "p c 12 1 18 8 12 22 6 8;p w 12 3 14 8 12 14 10 8",
    badge_loaded   = "r p 5 7 14 14;r p 9 3 6 3;r m 7 9 2 10;n w 11 11 5",
    badge_heavy    = "r o 2 7 4 11;r o 18 7 4 11;r S 5 11 14 3;r r 6 5 3 15;r r 15 5 3 15",
    badge_magnet   = "o r 12 10 9;r r 3 10 18 10;o _ 12 10 4;r _ 8 10 8 12;r w 3 17 5 4;r w 16 17 5 4",
    badge_phoenix  = "p r 13 1 20 12 17 21 7 21 4 13 8 8 10 11;p y 12 11 16 17 13 21 9 20 8 16",
    badge_wild     = "p y 12 1 15 8 22 9 17 14 18 21 12 18 6 21 7 14 2 9 9 8",
    -- combo cards
    combo_single_one     = "d w 5 5 14 1",
    combo_single_five    = "d w 5 5 14 5",
    combo_three_kind     = "d c 7 2 10 2;d c 2 12 10 2;d c 12 12 10 2",
    combo_four_kind      = "d g 2 2 9 3;d g 13 2 9 3;d g 2 13 9 3;d g 13 13 9 3",
    combo_five_kind      = "d m 2 2 8 4;d m 14 2 8 4;d m 8 8 8 4;d m 2 14 8 4;d m 14 14 8 4",
    combo_six_kind       = "d y 1 4 6 6;d y 9 4 6 6;d y 17 4 6 6;d y 1 14 6 6;d y 9 14 6 6;d y 17 14 6 6",
    combo_small_straight = "r b 2 18 4 4;r b 6 14 4 8;r b 10 10 4 12;r b 14 6 4 16;r c 18 2 4 20",
    combo_large_straight = "r r 1 18 4 4;r o 5 15 4 7;r y 9 12 4 10;r g 13 9 4 13;r b 17 6 4 16;p w 18 1 22 5 14 5",
    combo_three_pairs    = "d r 2 2 6 1;d r 9 2 6 1;d w 5 9 6 2;d w 13 9 6 2;d b 9 16 6 3;d b 17 16 6 3",
    combo_two_triples    = "d r 1 4 6 2;d r 9 4 6 2;d r 17 4 6 2;d b 1 14 6 5;d b 9 14 6 5;d b 17 14 6 5",
    combo_four_pair      = "d p 1 2 6 4;d p 9 2 6 4;d p 1 9 6 4;d p 9 9 6 4;d y 9 17 6 6;d y 17 17 6 6",
    -- charms
    nudge          = "d w 2 8 12 2;l g 19 6 19 18;l g 16 9 19 6;l g 22 9 19 6",
    flip           = "d w 6 7 11 3;p b 2 6 9 1 9 5 20 5 20 7 9 7;p r 22 19 15 23 15 20 4 20 4 18 15 18",
    ace            = "r w 5 2 14 20;p r 12 6 17 13 12 18 7 13;n R 6 3 1;n R 15 17 1",
    sixth_sense    = "p w 1 12 12 4 23 12 12 20;o p 12 12 5;n w 11 10 6",
    copycat        = "o o 12 13 8;p o 4 2 10 7 4 13;p o 20 2 14 7 20 13;r d 8 11 2 3;r d 14 11 2 3;o m 12 16 1",
    redo           = "o b 12 12 9;o _ 12 12 6;r _ 12 2 10 8;p b 11 1 19 5 11 10",
    alchemy        = "r S 10 2 4 7;p g 10 9 14 9 20 21 4 21;p p 8 14 16 14 20 21 4 21;o w 10 18 1;o w 14 17 1",
    gilding        = "r n 11 12 3 10;p y 4 2 20 2 18 10 6 10;r o 6 10 12 3",
    twin_cast      = "d p 2 4 9 3;d p 13 11 9 3;l y 13 5 19 8;l y 4 16 10 19",
    hot_hand       = "r t 5 11 14 10;r t 6 6 3 7;r t 10 5 3 7;r t 14 6 3 7;p o 12 1 17 7 12 10 7 7;p y 12 4 14 8 10 8",
    spotlight      = "p S 2 3 10 2 11 9 4 11;p y 8 9 12 6 22 18 10 22;o w 16 19 2",
    lifeline       = "o w 12 12 9;o _ 12 12 4;r r 9 2 6 5;r r 9 17 6 5;r r 2 9 5 6;r r 17 9 5 6",
    extra_time     = "o S 12 13 8;o w 12 13 6;r S 10 2 4 4;l d 12 13 12 9;l d 12 13 15 13;n G 17 3 +",
    bribe          = "r w 3 6 18 14;p s 3 6 21 6 12 14;r g 7 2 10 8;n w 10 4 $",
    payday         = "r G 2 5 20 14;r g 4 7 16 10;o y 12 12 4;n G 11 10 $",
    study          = "p b 12 7 22 4 22 18 12 21;p B 12 7 2 4 2 18 12 21;p w 13 8 20 6 20 16 13 19;p w 11 8 4 6 4 16 11 19",
    favorite       = "p r 12 21 2 10 2 5 7 2 12 6 17 2 22 5 22 10;n w 11 9 1",
    new_face       = "o t 12 14 7;p r 5 11 2 3 11 7;p b 19 11 22 3 13 7;r d 9 13 2 2;r d 14 13 2 2;r R 9 18 7 1;n w 11 8 +",
    grab_bag       = "o n 12 15 7;r n 8 6 8 4;r y 7 9 10 2;r w 7 2 5 6;r w 13 2 5 6;r r 9 4 1 2;r b 15 4 1 2",
    -- fallback
    unknown        = "d w 4 4 16 5",
}

local GLYPHS = {
    ["1"] = "010110010010111", ["2"] = "111001111100111", ["3"] = "111001111001111", ["4"] = "101101111001001",
    ["5"] = "111100111001111", ["6"] = "111100111101111", ["7"] = "111001010010010",
    ["+"] = "000010111010000", ["$"] = "111110111011111", ["%"] = "101001010100101",
}

local PIPS = { { 5 }, { 3, 7 }, { 3, 5, 7 }, { 1, 3, 7, 9 }, { 1, 3, 5, 7, 9 }, { 1, 3, 4, 6, 7, 9 } }

local function paint(spec)
    local data = love.image.newImageData(SIZE, SIZE)
    local function put(x, y, color)
        if x < 1 or y < 1 or x > SIZE - 2 or y > SIZE - 2 then return end   -- keep room for the outline
        if not color then data:setPixel(x, y, 0, 0, 0, 0) return end
        data:setPixel(x, y, color[1] / 255, color[2] / 255, color[3] / 255, 1)
    end
    local function rect(x, y, w, h, c)
        for py = y, y + h - 1 do for px = x, x + w - 1 do put(px, py, c) end end
    end

    for op in spec:gmatch("[^;]+") do
        local a = {}
        for word in op:gmatch("%S+") do a[#a + 1] = tonumber(word) or word end
        local what, c = a[1], COLORS[a[2]]
        if what == "r" then
            rect(a[3], a[4], a[5], a[6], c)
        elseif what == "o" then
            local r = a[5]
            for y = -r, r do for x = -r, r do
                if x * x + y * y <= (r + 0.4) * (r + 0.4) then put(a[3] + x, a[4] + y, c) end
            end end
        elseif what == "l" then
            local dx, dy = a[5] - a[3], a[6] - a[4]
            local n = math.max(math.abs(dx), math.abs(dy), 1)
            for i = 0, n do
                rect(math.floor(a[3] + dx * i / n + 0.5), math.floor(a[4] + dy * i / n + 0.5), 2, 2, c)
            end
        elseif what == "p" then
            local n = (#a - 2) / 2
            for y = 0, SIZE - 1 do for x = 0, SIZE - 1 do
                local inside, j = false, n
                for i = 1, n do
                    local xi, yi, xj, yj = a[1 + 2 * i], a[2 + 2 * i], a[1 + 2 * j], a[2 + 2 * j]
                    local px, py = x + 0.5, y + 0.5
                    if (yi > py) ~= (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi then inside = not inside end
                    j = i
                end
                if inside then put(x, y, c) end
            end end
        elseif what == "d" then
            local x, y, s, face = a[3], a[4], a[5], a[6]
            rect(x + 1, y, s - 2, s, c)
            rect(x, y + 1, s, s - 2, c)
            -- dice overlapping another shape keep a visible border
            local lo = math.floor((s - 2) * 0.15 + 0.5)
            local pos = { lo, math.floor((s - 2) / 2), s - 2 - lo }
            for _, cell in ipairs(PIPS[face]) do
                rect(x + pos[(cell - 1) % 3 + 1], y + pos[math.floor((cell - 1) / 3) + 1], 2, 2, COLORS.k)
            end
            for i = 1, s - 2 do
                put(x - 1, y + i, OUTLINE); put(x + i, y - 1, OUTLINE)
                put(x + s, y + i, OUTLINE); put(x + i, y + s, OUTLINE)
            end
            put(x, y, OUTLINE); put(x + s - 1, y, OUTLINE); put(x, y + s - 1, OUTLINE); put(x + s - 1, y + s - 1, OUTLINE)
        elseif what == "n" then
            local g = GLYPHS[tostring(a[5])]
            for i = 1, 15 do
                if g:sub(i, i) == "1" then put(a[3] + (i - 1) % 3, a[4] + math.floor((i - 1) / 3), c) end
            end
        else
            error("joker icon: unknown shape " .. tostring(what))
        end
    end

    -- shaded bottom edge, then a dark outline around everything
    local out = love.image.newImageData(SIZE, SIZE)
    local function solid(x, y)
        if x < 0 or y < 0 or x >= SIZE or y >= SIZE then return false end
        local _, _, _, al = data:getPixel(x, y)
        return al > 0
    end
    for y = 0, SIZE - 1 do for x = 0, SIZE - 1 do
        if solid(x, y) then
            local r, g, b = data:getPixel(x, y)
            local k = (solid(x, y + 1) and solid(x, y + 2)) and 1 or 0.8
            out:setPixel(x, y, r * k, g * k, b * k, 1)
        elseif solid(x - 1, y) or solid(x + 1, y) or solid(x, y - 1) or solid(x, y + 1) then
            out:setPixel(x, y, OUTLINE[1] / 255, OUTLINE[2] / 255, OUTLINE[3] / 255, 1)
        end
    end end
    return out
end

JokerIcons.ART = ART
local images = {}

function JokerIcons.load()
    for id, spec in pairs(ART) do
        local file = "assets/jokers/" .. id .. ".png"
        local img = love.graphics.newImage(love.filesystem.getInfo(file) and file or paint(spec))
        img:setFilter("nearest", "nearest")
        images[id] = img
    end
end

function JokerIcons.draw(id, cx, cy, scale)
    local img = images[id] or images.unknown
    local iw, ih = img:getDimensions()
    local s = scale * SIZE / iw        -- hand-drawn icons of any size fit the same space
    love.graphics.draw(img, cx, cy, 0, s, s, iw / 2, ih / 2)
end

return JokerIcons
