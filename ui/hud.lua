-- Left sidebar, laid out like Balatro's: floor title, target, score so far,
-- (score panel in the middle, see score_panel.lua), then stat boxes and buttons.
-- Positions were measured on a 604-wide reference and scaled to the sidebar width.

local Theme  = require("ui.theme")
local Button = require("ui.button")
local Screen = require("ui.screen")

local HUD = {}

-- Optional animated values set by main (Fx.counter objects). When missing, the real values are shown.
--   HUD.counters = { score = c, round = c, money = c }
HUD.counters = {}

HUD.comboButton  = Button.new("Combos\n[H]", "button_red")
HUD.newRunButton = Button.new("New\nrun", "button_orange")

local REF_W, BOTTOM_SHIFT = 604, 16

local function scale(w) return (w - 6) / REF_W end

-- Centers of the floor score and money boxes (for effects)
function HUD.scoreCenter(x, y, w)
    local k = scale(w)
    return x + 389 * k, y + 467 * k
end

function HUD.moneyCenter(x, y, w)
    local k = scale(w)
    return x + 420 * k, y + 1072 * k + BOTTOM_SHIFT
end

-- Draws fn() scaled by (1 + pop) around (cx, cy)
local function popped(pop, cx, cy, fn)
    if pop <= 0 then return fn() end
    local s = 1 + 0.25 * pop
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(s)
    love.graphics.translate(-cx, -cy)
    fn()
    love.graphics.pop()
end

-- Where the score panel goes (between the round score and the stat boxes)
function HUD.scoreRect(x, y, w)
    local k = scale(w)
    return x + 18 * k, y + 548 * k, 576 * k
end

-- Text centered on (cx, cy), shrunk to fit maxW
local function centered(text, font, cx, cy, maxW)
    love.graphics.setFont(font)
    local s = math.min(1, maxW / font:getWidth(text))
    Theme.print(text, cx, cy, 0, s, s, math.floor(font:getWidth(text) / 2), math.floor(font:getHeight() / 2))
end

-- [chip icon] 1,340,000
local function chipNumber(text, color, cx, cy, maxW, icon)
    local font = Theme.fonts.big
    local gap = 10
    local total = icon + gap + font:getWidth(text)
    local s = math.min(1, maxW / total)
    local x0 = cx - total * s / 2
    Theme.chip(x0, cy - icon * s / 2, icon * s)
    love.graphics.setFont(font)
    Theme.color(color)
    Theme.print(text, x0 + (icon + gap) * s, cy, 0, s, s, 0, math.floor(font:getHeight() / 2))
end

-- 12 big in `color`, "/8" small in white
local function fraction(a, b, color, cx, cy, maxW)
    local big, small = Theme.fonts.num, Theme.fonts.small
    local wa, wb = big:getWidth(a), small:getWidth("/" .. b)
    local s = math.min(1, maxW / (wa + wb))
    local x0 = cx - (wa + wb) * s / 2
    love.graphics.setFont(big)
    Theme.color(color)
    Theme.print(a, x0, cy, 0, s, s, 0, math.floor(big:getHeight() / 2))
    love.graphics.setFont(small)
    Theme.color("text")
    Theme.print("/" .. b, x0 + wa * s, cy + 8 * s, 0, s, s, 0, math.floor(small:getHeight() / 2))
end

-- Blue box with a label on top and a dark inset; returns the inset's center and width
local function statBox(label, bx, by, bw, bh, k)
    Theme.box(bx, by, bw, bh, "blue")
    love.graphics.setFont(Theme.fonts.normal)
    Theme.color("text")
    Theme.printf(label, bx, by, bw, "center")
    local ix, iy, iw, ih = bx + 14 * k, by + 40, bw - 28 * k, bh - 40 - 14 * k
    Theme.box(ix, iy, iw, ih, "inset")
    return ix + iw / 2, iy + ih / 2 - 2, iw - 14
end

function HUD.draw(fm, player, roundScore, x, y, w)
    local f, k = Theme.fonts, scale(w)
    local function Z(n) return n * k end
    local boss = fm:is_boss(fm.floor)

    -- sidebar background
    Theme.color("sidebar")
    local sx, sy, sh = math.min(x, Screen.left), math.min(y, Screen.top), Screen.bottom - math.min(y, Screen.top)
    love.graphics.rectangle("fill", sx, sy, x + w - sx, sh)
    Theme.color("sidebar_edge")
    love.graphics.rectangle("fill", x + w - 6, sy, 6, sh)

    -- title bar
    local hx, hy, hw, hh = x + Z(10), y + Z(24), Z(588), Z(82)
    Theme.box(hx, hy, hw, hh, boss and "button_red" or "header")
    love.graphics.setFont(f.num)
    Theme.color("text")
    Theme.printf(boss and ("BOSS  Floor " .. fm.floor) or ("Floor " .. fm.floor),
        hx, hy + (hh - 6 - f.num:getHeight()) / 2, hw, "center")

    -- target (Balatro's blind box)
    local bx, by, bw, bh = x + Z(8), y + Z(114), Z(590), Z(284)
    Theme.box(bx, by, bw, bh, "panel")
    love.graphics.setFont(f.small)
    Theme.color("text")
    Theme.printf(boss and "Boss floor: one round less" or "Reach the target score",
        bx, by + Z(14), bw, "center")
    Theme.token(x + Z(36), y + Z(206), Z(168), boss)
    local ix, iy, iw, ih = x + Z(222), y + Z(190), Z(362), Z(188)
    Theme.box(ix, iy, iw, ih, "inset")
    love.graphics.setFont(f.normal)
    Theme.color("text")
    Theme.printf("Score at least", ix, iy + 2, iw, "center")
    chipNumber(tostring(fm.target), "mult", ix + iw / 2, iy + ih / 2, iw - 20, Z(52))
    love.graphics.setFont(f.small)
    Theme.color("text")
    local earn = Theme.fonts.small:getWidth("to earn ")
    local money = "$" .. fm:get_rewards(fm.floor)
    local ex = ix + iw / 2 - (earn + Theme.fonts.small:getWidth(money)) / 2
    Theme.print("to earn ", ex, iy + ih - 36)
    Theme.color("gold")
    Theme.print(money, ex + earn, iy + ih - 36)

    -- score so far
    local rx, ry, rw, rh = x + Z(14), y + Z(422), Z(580), Z(100)
    Theme.box(rx, ry, rw, rh, "blue")
    love.graphics.setFont(f.normal)
    f.normal:setLineHeight(0.8)
    Theme.color("text")
    Theme.printf("Floor\nscore", rx + Z(18), ry + (rh - 6 - f.normal:getHeight() * 1.6) / 2, Z(170), "left")
    local sx, sy, sw, sh = x + Z(198), y + Z(432), Z(382), Z(70)
    Theme.box(sx, sy, sw, sh, "inset")
    local C = HUD.counters
    local score = C.score and C.score.value or fm.score
    local shownRound = C.round and C.round.value or roundScore
    local scx = sx + sw / 2 - (shownRound > 0 and Z(40) or 0)
    popped(C.score and C.score.pop or 0, scx, sy + sh / 2, function()
        chipNumber(tostring(score), score >= fm.target and "gold" or "text", scx, sy + sh / 2 - 2, sw - 40, Z(44))
    end)
    if shownRound > 0 then
        local rxr = sx + sw - 14
        popped(C.round and C.round.pop or 0, rxr - 30, sy + sh / 2, function()
            love.graphics.setFont(f.small)
            Theme.color("gold")
            Theme.printf("+" .. shownRound, sx, sy + (sh - f.small:getHeight()) / 2 - 2, sw - 14, "right")
        end)
    end

    -- progress toward the target: a thin bar under the floor score
    local prog = math.min(1, score / math.max(1, fm.target))
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", rx + Z(18), ry + rh - Z(14), rw - Z(36), Z(6), 3, 3)
    if prog > 0 then
        Theme.color(prog >= 1 and "gold" or "chips")
        love.graphics.rectangle("fill", rx + Z(18), ry + rh - Z(14), (rw - Z(36)) * prog, Z(6), 3, 3)
    end

    -- stat boxes (Hands / Discards in the original)
    local s = BOTTOM_SHIFT
    local cx, cy, mw = statBox("Rounds", x + Z(242), y + Z(854) + s, Z(170), Z(134), k)
    Theme.color("chips")
    centered(tostring(fm.rounds_left), f.num, cx, cy, mw)
    cx, cy, mw = statBox("Jokers", x + Z(428), y + Z(854) + s, Z(170), Z(134), k)
    Theme.color("mult")
    centered(#player.jokers .. "/" .. player.max_jokers, f.num, cx, cy, mw)

    -- money
    local mx, my, mw2, mh = x + Z(242), y + Z(1022) + s, Z(356), Z(120)
    Theme.box(mx, my, mw2, mh, "blue")
    Theme.box(mx + Z(14), my + Z(10), mw2 - Z(28), mh - Z(28), "inset")
    local cash = C.money and C.money.value or player.money
    local mcx, mcy = mx + mw2 / 2, my + Z(10) + (mh - Z(28)) / 2 - 2
    popped(C.money and C.money.pop or 0, mcx, mcy, function()
        Theme.color("gold")
        centered("$" .. cash, f.num, mcx, mcy, mw2 - Z(60))
    end)

    -- floor / round
    local round = math.min(fm:get_rounds(fm.floor), fm:get_rounds(fm.floor) - fm.rounds_left + 1)
    cx, cy, mw = statBox("Floor", x + Z(242), y + Z(1176) + s, Z(170), Z(128), k)
    fraction(tostring(fm.floor), tostring(fm.cfg.total_floors), "orange", cx, cy, mw)
    cx, cy, mw = statBox("Round", x + Z(428), y + Z(1176) + s, Z(170), Z(128), k)
    fraction(tostring(round), tostring(fm:get_rounds(fm.floor)), "orange", cx, cy, mw)

    -- buttons
    HUD.comboButton:setRect(x + Z(36), y + Z(866) + s, Z(176), Z(202))
    HUD.comboButton:draw()
    HUD.newRunButton:setRect(x + Z(36), y + Z(1094) + s, Z(176), Z(202))
    HUD.newRunButton:draw()
end

return HUD
