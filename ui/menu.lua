-- Title screen + pause menu.
--
--   Menu.load{ bg = <wallpaper Image>, music = <music Source> }   once, in love.load
--   Menu.update(dt) / Menu.draw()                                 every frame (always call both)
--   Menu.mousepressed(x, y, button) / Menu.keypressed(key)        return true when the event was used
--   Menu.open("main" | "pause") / Menu.close()
--   Menu.visible, Menu.mode
--
-- Callbacks set by main.lua:
--   Menu.onPlay()       start a fresh run (called while the screen is black)
--   Menu.onResume()     (optional) pause menu closed
--   Menu.onMainMenu()   (optional) player left the run for the title screen
--   Menu.onCombos()     open the combo table
--   Menu.overlayOpen()  (optional) true while an overlay covers the menu (no mouse hover)
--   Menu.runInfo()      string shown under "PAUSED"
--
-- Everything is drawn in the 1920x1080 virtual screen (see ui/screen.lua).

local Theme    = require("ui.theme")
local Screen   = require("ui.screen")
local Settings = require("core.settings")
local Fx       = require("ui.fx")

local Menu = { visible = true, mode = "main" }

local W, H = Screen.W, Screen.H
local FONT = "assets/fonts/Jersey10-Regular.ttf"
local DW, DH = 206, 202          -- one die in assets/dice.png (3 x 2 sheet)
local TITLE = "TESSERA"
local TITLE_SIZE = 320           -- multiples of 10 keep Jersey10 crisp

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function easeOutCubic(t) t = 1 - clamp(t, 0, 1); return 1 - t * t * t end
local function bounceOut(t)
    t = clamp(t, 0, 1)
    if t < 1 / 2.75 then return 7.5625 * t * t end
    if t < 2 / 2.75 then t = t - 1.5 / 2.75;   return 7.5625 * t * t + 0.75 end
    if t < 2.5 / 2.75 then t = t - 2.25 / 2.75; return 7.5625 * t * t + 0.9375 end
    t = t - 2.625 / 2.75
    return 7.5625 * t * t + 0.984375
end
local function inRect(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

---------------------------------------------------------------------------
-- state
---------------------------------------------------------------------------
local bg, diceImg, quads, vignette, titleFont, music
local bgDice, heroes = {}, {}
local sfx = {}
local time, introT, screenT = 0, 0, 0
local screens, current, screenName, sel, backSel = {}, nil, "main", 1, 1
local fade = { a = 1, target = 0, cb = nil }      -- black overlay; starts black and fades in
local lastMx, lastMy = -1, -1
local dragging = nil                               -- slider item being dragged

---------------------------------------------------------------------------
-- tiny synthesized UI sounds (no audio files needed)
---------------------------------------------------------------------------
local synth = Fx.synth   -- see ui/fx.lua

local function play(name)
    local s, v = sfx[name], Settings.data.sfx
    if not s or v <= 0 then return end
    s = s:clone()
    s:setVolume(v)
    s:play()
end

---------------------------------------------------------------------------
-- background: drifting wallpaper, vignette, floating dice, two "hero" dice
---------------------------------------------------------------------------
local function newBgDie(initial)
    local z = math.random()
    return {
        z = z, s = lerp(0.20, 0.70, z), a = lerp(0.16, 0.45, z),
        x = Screen.left + math.random() * (Screen.right - Screen.left),
        y = initial and (Screen.top + math.random() * (Screen.bottom - Screen.top)) or Screen.bottom + 160,
        vx = math.random(-12, 12), vy = -lerp(14, 55, z),
        r = math.random() * math.pi * 2, vr = (math.random() - 0.5) * 1.1,
        face = math.random(6),
    }
end

local function buildVignette()
    local w, h = 128, 72
    local data = love.image.newImageData(w, h)
    data:mapPixel(function(x, y)
        local dx, dy = (x / (w - 1) - 0.5) * 2, (y / (h - 1) - 0.5) * 2
        local d = math.sqrt(dx * dx * 0.75 + dy * dy)
        local a = clamp((d - 0.35) / 0.95, 0, 1) ^ 1.6 * 0.8
        return 0, 0, 0.02, a
    end)
    local img = love.graphics.newImage(data)
    img:setFilter("linear", "linear")
    return img
end

local function updateBackground(dt)
    for _, d in ipairs(bgDice) do
        d.x, d.y, d.r = d.x + d.vx * dt, d.y + d.vy * dt, d.r + d.vr * dt
        if d.y < Screen.top - 160 or d.x < Screen.left - 160 or d.x > Screen.right + 160 then
            local n = newBgDie(false)
            for k, v in pairs(n) do d[k] = v end
        end
    end
    for _, h in ipairs(heroes) do
        h.t = h.t - dt
        if h.t <= 0 then h.t, h.rollT = 2.6 + math.random() * 1.2, 0.8 end
        if h.rollT > 0 then
            h.rollT = h.rollT - dt
            h.flick = h.flick - dt
            if h.flick <= 0 then h.flick, h.face = 0.06, math.random(6) end
        end
    end
end

local function drawDie(face, x, y, rot, scale, alpha)
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(diceImg, quads[face], x, y, rot, scale, scale, DW / 2, DH / 2)
end

local function drawBackground()
    local mx, my = Screen.mouse()
    local px, py = clamp((mx - W / 2) / W, -0.5, 0.5), clamp((my - H / 2) / H, -0.5, 0.5)

    -- wallpaper: oversized so rotation and drift never reveal the edges
    local iw, ih = bg:getDimensions()
    local vw, vh = Screen.right - Screen.left, Screen.bottom - Screen.top
    local k = math.max(vw / iw, vh / ih) * 1.25 * (1 + math.sin(time * 0.2) * 0.03)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg,
        W / 2 - px * 30 + math.sin(time * 0.13) * 40, H / 2 - py * 20 + math.cos(time * 0.11) * 25,
        math.sin(time * 0.09) * 0.07, k, k, iw / 2, ih / 2)

    love.graphics.setColor(0, 0, 0, 0.18)
    Screen.fill()

    for _, d in ipairs(bgDice) do
        drawDie(d.face, d.x - px * 70 * d.z, d.y - py * 50 * d.z, d.r, d.s, d.a)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(vignette, Screen.left, Screen.top, 0, vw / vignette:getWidth(), vh / vignette:getHeight())
end

local function drawHeroes()
    for i, h in ipairs(heroes) do
        local rolling = h.rollT > 0
        local bob = rolling and -math.abs(math.sin(h.rollT * 18)) * 40 or math.sin(time * 1.5 + i * 2) * 8
        local rot = h.rot + (rolling and math.sin(time * 30) * 0.18 or math.sin(time * 0.9 + i) * 0.05)
        local s = 0.8
        -- contact shadow
        love.graphics.setColor(0, 0, 0, 0.30)
        love.graphics.ellipse("fill", h.x, h.y + DH * s / 2 + 34, DW * s * 0.42, 14)
        drawDie(h.face, h.x, h.y + bob, rot, s, 1)
    end
end

---------------------------------------------------------------------------
-- title logo
---------------------------------------------------------------------------
local function drawLogo(cx, cy)
    local font = titleFont
    love.graphics.setFont(font)
    local fh = font:getHeight()
    local widths, total = {}, 0
    for i = 1, #TITLE do
        widths[i] = font:getWidth(TITLE:sub(i, i))
        total = total + widths[i]
    end
    local fit = math.min(1, 1100 / total)
    local x = cx - total * fit / 2

    for i = 1, #TITLE do
        local ch, cw = TITLE:sub(i, i), widths[i]
        local drop = (1 - bounceOut((introT - (i - 1) * 0.07) / 0.7)) * -800
        local bob  = math.sin(time * 2.2 + i * 0.6) * 8
        local rot  = math.sin(time * 1.6 + i * 0.9) * 0.035
        local gx, gy = math.floor(-cw / 2), math.floor(-fh / 2)

        love.graphics.push()
        love.graphics.translate(math.floor(x + cw * fit / 2), math.floor(cy + drop + bob))
        love.graphics.rotate(rot)
        love.graphics.scale(fit)

        love.graphics.setColor(0, 0, 0, 0.35)                       -- drop shadow
        love.graphics.print(ch, gx + 10, gy + 30)
        for e = 20, 8, -4 do                                        -- navy extrusion
            love.graphics.setColor(0.07, 0.10, 0.22, 1)
            love.graphics.print(ch, gx, gy + e)
        end
        for e = 6, 2, -2 do                                         -- red lip
            love.graphics.setColor(0.93, 0.27, 0.25, 1)
            love.graphics.print(ch, gx, gy + e)
        end
        local glint = math.max(0, math.sin(time * 1.8 - i * 0.55)) ^ 10   -- gold shimmer wave
        love.graphics.setColor(1, 1 - 0.18 * glint, 1 - 0.65 * glint, 1)
        love.graphics.print(ch, gx, gy)

        love.graphics.pop()
        x = x + cw * fit
    end

    -- ribbon
    local rt = easeOutCubic((introT - 0.8) / 0.4)
    if rt > 0 then
        love.graphics.push()
        love.graphics.translate(cx, cy + 215 + (1 - rt) * 40)
        love.graphics.rotate(-0.03)
        Theme.box(-270, -32, 540, 66, "mult")
        love.graphics.setFont(Theme.fonts.normal)
        Theme.color("text")
        Theme.printf("A FARKLE ROGUELIKE", -270, -32 + (58 - Theme.fonts.normal:getHeight()) / 2, 540, "center")
        love.graphics.pop()
    end
end

---------------------------------------------------------------------------
-- item drawing (buttons, sliders, toggles)
---------------------------------------------------------------------------
-- Pointers are queued and drawn last (see flushPointers) so they always sit on top of
-- every other menu element. Positions are stored in screen space so any translate that
-- was active when they were queued (slide-in animations etc.) is preserved.
local pointerQueue = {}

local function pointer(cx, cy, dir)
    -- dir = 1: points right; -1: points left
    local gx, gy = love.graphics.transformPoint(cx, cy)
    pointerQueue[#pointerQueue + 1] = { gx, gy, dir }
end

local function flushPointers()
    for i, p in ipairs(pointerQueue) do
        local cx, cy = love.graphics.inverseTransformPoint(p[1], p[2])
        local dir = p[3]
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.polygon("fill", cx - 14 * dir + 3, cy - 17 + 3, cx - 14 * dir + 3, cy + 17 + 3, cx + 14 * dir + 3, cy + 3)
        love.graphics.setColor(1, 0.85, 0.3, 1)
        love.graphics.polygon("fill", cx - 14 * dir, cy - 17, cx - 14 * dir, cy + 17, cx + 14 * dir, cy)
        pointerQueue[i] = nil
    end
end

local function drawButton(it, selected)
    local r = it.rect
    local grow = selected and 10 or 0
    local x, w, h = r.x - grow, r.w + grow * 2, r.h
    local y = r.y + (selected and -4 or 0)
    local mx, my = Screen.mouse()
    if selected and love.mouse.isDown(1) and inRect(r, mx, my) then y = r.y + 4 end

    love.graphics.setColor(0, 0, 0, 0.30)                           -- shadow stays put when the button lifts
    love.graphics.rectangle("fill", r.x, r.y + 10, r.w, r.h - 4, 14, 14)

    Theme.box(x, y, w, h, it.style or "button")
    love.graphics.setFont(Theme.fonts.normal)
    Theme.color("text")
    Theme.printf(it.label, x, y + (h - 8 - Theme.fonts.normal:getHeight()) / 2, w, "center")

    if selected then
        local bob = math.sin(time * 8) * 5
        local cy = y + (h - 8) / 2
        pointer(x - 34 + bob, cy, 1)
        pointer(x + w + 34 - bob, cy, -1)
    end
end

local function sliderTrack(r)
    return r.x + 420, r.y + r.h / 2 - 16, r.w - 420 - 160
end

local function drawRowBackdrop(r, selected)
    if not selected then return end
    love.graphics.setColor(1, 1, 1, 0.10)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 12, 12)
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 12, 12)
    pointer(r.x + 24 + math.sin(time * 8) * 3, r.y + r.h / 2, 1)
end

local function drawRowLabel(it, r)
    love.graphics.setFont(Theme.fonts.normal)
    Theme.color("text")
    Theme.print(it.label, r.x + 56, r.y + (r.h - Theme.fonts.normal:getHeight()) / 2)
end

local function drawSlider(it, selected)
    local r = it.rect
    drawRowBackdrop(r, selected)
    drawRowLabel(it, r)
    local v = it.get()
    local tx, ty, tw = sliderTrack(r)
    Theme.box(tx, ty, tw, 32, "inset")
    local fw = (tw - 16) * v
    if fw > 0 then
        Theme.color("chips")
        love.graphics.rectangle("fill", tx + 8, ty + 8, fw, 16, 4, 4)
    end
    local kx = tx + 8 + fw
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", kx - 10 + 3, ty - 6 + 4, 20, 44, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", kx - 10, ty - 6, 20, 44, 5, 5)
    love.graphics.setFont(Theme.fonts.normal)
    Theme.color("gold")
    Theme.printf(("%d%%"):format(math.floor(v * 100 + 0.5)), tx + tw + 20, r.y + (r.h - Theme.fonts.normal:getHeight()) / 2, 120, "left")
end

local function drawToggle(it, selected)
    local r = it.rect
    drawRowBackdrop(r, selected)
    drawRowLabel(it, r)
    local on = it.get()
    local bx, bw, bh = r.x + r.w - 210, 190, 56
    local by = r.y + r.h / 2 - bh / 2
    Theme.box(bx, by, bw, bh, "inset")
    local c = on and Theme.colors.good or Theme.colors.disabled
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.rectangle("fill", bx + 8, by + 8, bw - 16, bh - 16, 6, 6)
    local kw = 70
    local kx = on and (bx + bw - 8 - kw) or (bx + 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", kx, by + 8, kw, bh - 16, 6, 6)
    love.graphics.setFont(Theme.fonts.small)
    Theme.color("text")
    Theme.printf(on and "ON" or "OFF", on and (bx + 8) or (bx + 8 + kw),
        by + (bh - Theme.fonts.small:getHeight()) / 2, bw - 16 - kw, "center")
end

local function drawItems(items)
    for i, it in ipairs(items) do
        if it.kind == "button" then drawButton(it, i == sel)
        elseif it.kind == "slider" then drawSlider(it, i == sel)
        else drawToggle(it, i == sel) end
    end
end

local function panelTitle(text, px, py, pw)
    love.graphics.setFont(Theme.fonts.big)
    Theme.color("gold")
    Theme.printf(text, px, py + 26, pw, "center")
end

---------------------------------------------------------------------------
-- navigation
---------------------------------------------------------------------------
local function go(name, index)
    screenName, current = name, screens[name]
    sel, screenT, dragging = index or 1, 0, nil
    lastMx, lastMy = Screen.mouse()
end

local function enter(name) backSel = sel; go(name, 1) end
local function back(name) go(name, backSel or 1) end

local function startGame()
    if fade.target == 1 then return end
    play("start")
    fade.target = 1
    fade.cb = function()
        Menu.visible = false
        if Menu.onPlay then Menu.onPlay() end
    end
end

local function leaveRun()
    fade.target = 1
    fade.cb = function()
        if Menu.onMainMenu then Menu.onMainMenu() end
        Menu.open("main")
    end
end

local function resume()
    Menu.visible = false
    if Menu.onResume then Menu.onResume() end
end

---------------------------------------------------------------------------
-- screens
---------------------------------------------------------------------------
local function button(label, style, act) return { kind = "button", label = label, style = style, act = act } end
local function slider(label, key)
    return { kind = "slider", label = label,
             get = function() return Settings.data[key] end,
             set = function(v) Settings.data[key] = clamp(v, 0, 1) end }
end
local function toggle(label, get, set) return { kind = "toggle", label = label, get = get, set = set } end

local function stack(items, x, y0, w, h, gap)
    for i, it in ipairs(items) do it.rect = { x = x, y = y0 + (i - 1) * (h + gap), w = w, h = h } end
end

local function buildScreens()
    ---- main -----------------------------------------------------------
    local main = {}
    main.items = {
        button("Play",        "button",        startGame),
        button("How to play", "chips",         function() enter("howto") end),
        button("Options",     "button_orange", function() enter("options") end),
        button("Quit",        "button_red",    function() love.event.quit() end),
    }
    function main.layout() stack(main.items, W / 2 - 260, 575, 520, 84, 16) end
    function main.draw()
        drawHeroes()
        drawLogo(W / 2, 255)
        local items = main.items
        for i, it in ipairs(items) do
            -- buttons rise in after the logo lands
            local t = easeOutCubic((introT - 1.0 - (i - 1) * 0.08) / 0.35)
            love.graphics.push()
            love.graphics.translate(0, (1 - t) * 140)
            if t > 0 then drawButton(it, i == sel) end
            love.graphics.pop()
        end
        local d = Settings.data
        if d.runs > 0 and introT > 1.4 then
            love.graphics.setFont(Theme.fonts.small)
            Theme.color("dim")
            Theme.printf(("BEST RUN: %d / 7 FLOORS   |   ESCAPES: %d   |   RUNS: %d"):format(d.best_floors, d.escapes, d.runs),
                0, H - 100, W, "center")
        end
    end

    ---- pause ----------------------------------------------------------
    local pause = {}
    pause.items = {
        button("Resume",    "button",        resume),
        button("Combos",    "chips",         function() if Menu.onCombos then Menu.onCombos() end end),
        button("Options",   "button_orange", function() enter("options") end),
        button("Main menu", "button_red",    function() enter("confirm") end),
    }
    local PAW, PAH = 680, 580
    function pause.layout()
        local px, py = (W - PAW) / 2, (H - PAH) / 2
        stack(pause.items, W / 2 - 260, py + 150, 520, 84, 16)
    end
    function pause.draw()
        local px, py = (W - PAW) / 2, (H - PAH) / 2
        Theme.panel(px, py, PAW, PAH)
        panelTitle("PAUSED", px, py, PAW)
        if Menu.runInfo then
            love.graphics.setFont(Theme.fonts.small)
            Theme.color("dim")
            Theme.printf(Menu.runInfo(), px, py + 98, PAW, "center")
        end
        drawItems(pause.items)
    end
    function pause.back() resume() end

    ---- options --------------------------------------------------------
    local options = {}
    options.items = {
        slider("Music volume", "music"),
        slider("Sound effects", "sfx"),
        toggle("Fullscreen", function() return love.window.getFullscreen() end,
                             function(v) Settings.setFullscreen(v) end),
        toggle("Screen shake", function() return Settings.data.shake end,
                               function(v) Settings.data.shake = v end),
        toggle("Floaty dice", function() return Settings.data.float end,
                              function(v) Settings.data.float = v end),
        toggle("Highlight scoring dice", function() return Settings.data.hints end,
                                         function(v) Settings.data.hints = v end),
        button("Back", "button", function() Settings.save(); back(Menu.mode) end),
    }
    local OW, ROW, ROWGAP = 1180, 80, 12
    local NROWS = #options.items - 1                 -- every item but the Back button
    local OH = 120 + NROWS * (ROW + ROWGAP) + 20 + 84 + 46
    function options.layout()
        local px, py = (W - OW) / 2, (H - OH) / 2
        for i = 1, NROWS do
            options.items[i].rect = { x = px + 40, y = py + 120 + (i - 1) * (ROW + ROWGAP), w = OW - 80, h = ROW }
        end
        options.items[NROWS + 1].rect = { x = W / 2 - 180, y = py + 120 + NROWS * (ROW + ROWGAP) + 20, w = 360, h = 84 }
    end
    function options.draw()
        local px, py = (W - OW) / 2, (H - OH) / 2
        Theme.panel(px, py, OW, OH)
        panelTitle("OPTIONS", px, py, OW)
        drawItems(options.items)
    end
    function options.back() Settings.save(); back(Menu.mode) end

    ---- how to play ----------------------------------------------------
    local STEPS = {
        { "The goal",     "Every floor has a target score and a limited number of rounds. Reach the target before you run out. Clear all 7 floors to escape the casino." },
        { "Roll",         "Press SPACE to roll your dice. Click the dice that score, then press ENTER to confirm. Every selected die must belong to a combo." },
        { "Chips x Mult", "Each combo adds Chips and Mult. Your score is Chips x Mult, so stacking Mult pays off. Press H any time to see every combo." },
        { "Push or bank", "After scoring, press R to roll the dice you have left, or B to bank your points. Use all six dice and you get six fresh ones: HOT DICE!" },
        { "Farkle!",      "If a roll has nothing that scores, you FARKLE and lose everything you built up in that round. Greed is expensive." },
        { "Shop",         "Clearing a floor pays out cash, with interest on your savings. Spend it on Jokers that bend the rules, and click a Joker to sell it. Every 5th floor is a boss with one round less." },
    }
    local howto = {}
    howto.items = {
        button("Combos", "chips",  function() if Menu.onCombos then Menu.onCombos() end end),
        button("Back",   "button", function() back("main") end),
    }
    howto.horizontal = true
    local CARD_W, CARD_GAP, PAD = 680, 40, 24
    local HW = CARD_W * 2 + CARD_GAP + 80
    local cache
    local function measure()
        if cache then return cache end
        local body, title = Theme.fonts.small, Theme.fonts.normal
        local rows, y, cards = 3, 0, {}
        local rowH = {}
        for i, s in ipairs(STEPS) do
            local _, lines = body:getWrap(s[2], CARD_W - PAD * 2)
            local h = PAD + 46 + 8 + #lines * body:getHeight() + PAD - 4
            local row = math.floor((i - 1) / 2) + 1
            rowH[row] = math.max(rowH[row] or 0, h)
        end
        local total = 0
        for r = 1, rows do total = total + rowH[r] end
        total = total + (rows - 1) * 24
        cache = { rowH = rowH, cardsH = total, ph = 100 + total + 28 + 84 + 44 }
        return cache
    end
    function howto.layout()
        local m = measure()
        local py = (H - m.ph) / 2
        local by = py + 100 + m.cardsH + 28
        howto.items[1].rect = { x = W / 2 - 330 - 15, y = by, w = 330, h = 84 }
        howto.items[2].rect = { x = W / 2 + 15,       y = by, w = 330, h = 84 }
    end
    function howto.draw()
        local m = measure()
        local px, py = (W - HW) / 2, (H - m.ph) / 2
        Theme.panel(px, py, HW, m.ph)
        panelTitle("HOW TO PLAY", px, py, HW)
        local cx0 = px + 40
        local rowY = py + 100
        for i, s in ipairs(STEPS) do
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2) + 1
            if col == 0 and row > 1 then rowY = rowY + m.rowH[row - 1] + 24 end
            local x, y = cx0 + col * (CARD_W + CARD_GAP), rowY
            Theme.box(x, y, CARD_W, m.rowH[row], "inset")
            -- number badge
            Theme.box(x + PAD, y + PAD - 2, 46, 46, "button_orange")
            love.graphics.setFont(Theme.fonts.normal)
            Theme.color("text")
            Theme.printf(tostring(i), x + PAD, y + PAD - 2 + (46 - 8 - Theme.fonts.normal:getHeight()) / 2 + 2, 46, "center")
            -- title + body
            Theme.color("gold")
            Theme.print(s[1], x + PAD + 62, y + PAD - 2 + (46 - Theme.fonts.normal:getHeight()) / 2)
            love.graphics.setFont(Theme.fonts.small)
            Theme.color("dim")
            Theme.printf(s[2], x + PAD, y + PAD + 54, CARD_W - PAD * 2, "left")
        end
        drawItems(howto.items)
    end
    function howto.back() back("main") end

    ---- confirm leaving a run -----------------------------------------
    local confirm = {}
    confirm.items = {
        button("Stay",  "button",     function() back("pause") end),
        button("Leave", "button_red", function() leaveRun() end),
    }
    confirm.horizontal = true
    local CW, CH = 820, 440
    function confirm.layout()
        local py = (H - CH) / 2
        local by = py + CH - 84 - 50
        confirm.items[1].rect = { x = W / 2 - 320 - 20, y = by, w = 320, h = 84 }
        confirm.items[2].rect = { x = W / 2 + 20,       y = by, w = 320, h = 84 }
    end
    function confirm.draw()
        local px, py = (W - CW) / 2, (H - CH) / 2
        Theme.panel(px, py, CW, CH)
        panelTitle("LEAVE RUN?", px, py, CW)
        love.graphics.setFont(Theme.fonts.normal)
        Theme.color("dim")
        Theme.printf("Your current run will be lost.", px + 40, py + 150, CW - 80, "center")
        drawItems(confirm.items)
    end
    function confirm.back() back("pause") end

    screens = { main = main, pause = pause, options = options, howto = howto, confirm = confirm }
end

---------------------------------------------------------------------------
-- public API
---------------------------------------------------------------------------
function Menu.load(opts)
    bg, music = opts.bg, opts.music
    diceImg = love.graphics.newImage("assets/dice.png")
    quads = {}
    for i = 0, 5 do
        quads[i + 1] = love.graphics.newQuad((i % 3) * DW, math.floor(i / 3) * DH, DW, DH, diceImg:getDimensions())
    end

    titleFont = love.graphics.newFont(FONT, TITLE_SIZE)
    titleFont:setFilter("nearest", "nearest")
    vignette = buildVignette()

    bgDice = {}
    for i = 1, 16 do bgDice[i] = newBgDie(true) end
    table.sort(bgDice, function(a, b) return a.z < b.z end)      -- far dice first
    heroes = {
        { x = 300,  y = 255, rot = -0.25, face = 6, t = 0.8, rollT = 0, flick = 0 },
        { x = 1620, y = 255, rot =  0.25, face = 1, t = 2.1, rollT = 0, flick = 0 },
    }

    sfx = {
        tick   = synth({ { 1200, 0.025 } }, 0.20),
        select = synth({ { 600, 0.05 }, { 900, 0.08 } }, 0.30),
        back   = synth({ { 700, 0.05 }, { 420, 0.08 } }, 0.30),
        start  = synth({ { 523, 0.08 }, { 659, 0.08 }, { 784, 0.08 }, { 1047, 0.18 } }, 0.30),
    }

    buildScreens()
    Menu.open("main")
end

function Menu.open(mode)
    Menu.visible, Menu.mode = true, mode
    if mode == "main" then introT = 0 end
    backSel = 1
    go(mode, 1)
end

function Menu.close() Menu.visible = false end

-- While the logo is still dropping in, any click or key skips the intro instead
local function introLocked()
    if screenName == "main" and Menu.mode == "main" and introT < 1.6 then
        introT = 2
        return true
    end
    return false
end

local function activate(it)
    if it.kind == "button" then
        play(it.label == "Back" and "back" or "select")
        it.act()
    elseif it.kind == "toggle" then
        play("select")
        it.set(not it.get())
        Settings.save()
    end
end

local function setSliderFromMouse(it, mx)
    local tx, _, tw = sliderTrack(it.rect)
    local v = clamp((mx - (tx + 8)) / (tw - 16), 0, 1)
    v = math.floor(v * 100 + 0.5) / 100
    if v ~= it.get() then it.set(v) end
end

function Menu.update(dt)
    time = time + dt
    introT = introT + dt

    -- screen fade (to black, run callback, back from black)
    if fade.a < fade.target then
        fade.a = math.min(1, fade.a + dt / 0.30)
        if fade.a >= 1 then
            local cb = fade.cb
            fade.cb, fade.target = nil, 0
            if cb then cb() end
        end
    elseif fade.a > fade.target then
        fade.a = math.max(fade.target, fade.a - dt / 0.45)
    end

    if music then music:setVolume(Settings.data.music) end
    if not Menu.visible then return end

    screenT = screenT + dt
    if Menu.mode == "main" then updateBackground(dt) end
    current.layout()

    local mx, my = Screen.mouse()
    if dragging then
        if love.mouse.isDown(1) then
            setSliderFromMouse(dragging, mx)
        else
            dragging = nil
            Settings.save()
        end
    end
    if (mx ~= lastMx or my ~= lastMy) and not dragging and not (screenName == "main" and introT < 1.6)
            and not (Menu.overlayOpen and Menu.overlayOpen()) then
        lastMx, lastMy = mx, my
        for i, it in ipairs(current.items) do
            if inRect(it.rect, mx, my) then
                if sel ~= i then sel = i; play("tick") end
                break
            end
        end
    end
end

function Menu.draw()
    if Menu.visible then
        if Menu.mode == "main" then
            drawBackground()
        else
            love.graphics.setColor(0, 0, 0, 0.65 * clamp(screenT * 4, 0, 1))
            Screen.fill()
        end

        -- panels slide up into place; the title screen has its own intro
        local slide = (screenName == "main") and 0 or (1 - easeOutCubic(screenT / 0.3)) * 50
        love.graphics.push()
        love.graphics.translate(0, slide)
        current.draw()
        love.graphics.pop()

        love.graphics.setFont(Theme.fonts.small)
        Theme.color("dim", 0.8)
        Theme.printf("W/S or arrows: move   |   ENTER: select   |   ESC: back   |   F11: fullscreen",
            0, H - 56, W, "center")

        flushPointers()
    end

    if fade.a > 0 then
        love.graphics.setColor(0, 0, 0, fade.a)
        Screen.fill()
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Menu.mousepressed(mx, my, button)
    if fade.target == 1 then return true end
    if not Menu.visible then return false end
    if introLocked() then return true end
    if button ~= 1 then return true end
    for i, it in ipairs(current.items) do
        if inRect(it.rect, mx, my) then
            sel = i
            if it.kind == "slider" then
                local tx, ty, tw = sliderTrack(it.rect)
                if mx >= tx - 14 and mx <= tx + tw + 14 then
                    dragging = it
                    setSliderFromMouse(it, mx)
                    play("tick")
                end
            else
                activate(it)
            end
            break
        end
    end
    return true
end

function Menu.keypressed(key)
    if fade.target == 1 then return true end
    if not Menu.visible then return false end
    if introLocked() then return true end
    local items = current.items
    local function move(d)
        sel = (sel - 1 + d) % #items + 1
        play("tick")
    end
    local it = items[sel]

    if key == "up" or key == "w" then move(-1)
    elseif key == "down" or key == "s" then move(1)
    elseif key == "left" or key == "a" then
        if it.kind == "slider" then
            it.set(it.get() - 0.1); play("tick"); Settings.save()
        elseif it.kind == "toggle" then
            if it.get() then activate(it) end
        elseif current.horizontal then move(-1) end
    elseif key == "right" or key == "d" then
        if it.kind == "slider" then
            it.set(it.get() + 0.1); play("tick"); Settings.save()
        elseif it.kind == "toggle" then
            if not it.get() then activate(it) end
        elseif current.horizontal then move(1) end
    elseif key == "return" or key == "kpenter" or key == "space" then
        activate(it)
    elseif key == "escape" then
        if current.back then play("back"); current.back() end
    end
    return true
end

return Menu
