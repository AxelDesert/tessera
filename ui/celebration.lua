-- Big "FLOOR CLEARED!" moment between the last bank and the cash-out screen:
-- a banner slams in over spinning light rays, fireworks pop, confetti rains.
--
--   Celebration.start(title, subtitle)
--   Celebration.update(dt)    returns true once, when it is over
--   Celebration.skip()        jump to the end (after a short minimum)
--   Celebration.draw()
--   Celebration.active

local Theme  = require("ui.theme")
local Screen = require("ui.screen")
local Fx     = require("ui.fx")

local Celebration = { active = false }

local DURATION, MIN_TIME = 2.8, 0.6
local t, title, subtitle, nextFirework = 0, "", "", 0

local function easeOutBack(x)
    local c1, c3 = 1.9, 2.9
    return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

function Celebration.start(text, sub)
    Celebration.active = true
    t, title, subtitle, nextFirework = 0, text, sub or "", 0.25
    Fx.play("fanfare")
    Fx.confetti(160)
end

function Celebration.skip()
    if Celebration.active and t > MIN_TIME then t = DURATION end
end

function Celebration.update(dt)
    if not Celebration.active then return false end
    t = t + dt

    -- the banner lands
    if t - dt < 0.32 and t >= 0.32 then
        Fx.shake(0.7)
        Fx.ring(Screen.W / 2 + 240, Screen.H / 2 - 40, Theme.colors.gold, 700)
    end
    -- fireworks around the banner
    if t >= nextFirework and t < DURATION - 0.6 then
        nextFirework = t + 0.22 + math.random() * 0.2
        local cx = Screen.SIDEBAR_W + 100 + math.random() * (Screen.W - Screen.SIDEBAR_W - 200)
        Fx.firework(cx, 140 + math.random() * 520)
        Fx.play("coin", 0.7 + math.random() * 0.6)
    end

    if t >= DURATION then
        Celebration.active = false
        return true
    end
    return false
end

function Celebration.draw()
    if not Celebration.active then return end
    local cx, cy = Screen.SIDEBAR_W + (Screen.W - Screen.SIDEBAR_W) / 2, Screen.H / 2 - 40
    local fadeIn = math.min(1, t / 0.25)
    local fadeOut = math.min(1, (DURATION - t) / 0.35)
    local a = fadeIn * fadeOut

    -- everything stays inside the play area (the sidebar keeps showing the score)
    love.graphics.setScissor(Screen.ox + Screen.SIDEBAR_W * Screen.scale, 0,
        love.graphics.getWidth(), love.graphics.getHeight())

    -- dim the table
    love.graphics.setColor(0, 0, 0, 0.6 * a)
    love.graphics.rectangle("fill", Screen.SIDEBAR_W, Screen.top, Screen.right - Screen.SIDEBAR_W, Screen.bottom - Screen.top)

    -- spinning light rays
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(t * 0.5)
    love.graphics.setBlendMode("add")
    local g = Theme.colors.gold
    for i = 0, 15 do
        local ang = i / 16 * math.pi * 2
        love.graphics.setColor(g[1], g[2], g[3], 0.10 * a)
        love.graphics.polygon("fill", 0, 0,
            math.cos(ang - 0.08) * 1400, math.sin(ang - 0.08) * 1400,
            math.cos(ang + 0.08) * 1400, math.sin(ang + 0.08) * 1400)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()

    -- dark band behind the banner
    local band = math.min(1, t / 0.2)
    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.rectangle("fill", Screen.SIDEBAR_W, cy - 110 * band, Screen.right - Screen.SIDEBAR_W, 250 * band)
    love.graphics.setColor(g[1], g[2], g[3], 0.8 * a)
    love.graphics.rectangle("fill", Screen.SIDEBAR_W, cy - 110 * band, Screen.right - Screen.SIDEBAR_W, 4)
    love.graphics.rectangle("fill", Screen.SIDEBAR_W, cy + 140 * band - 4, Screen.right - Screen.SIDEBAR_W, 4)

    -- banner: drops in big, overshoots, then breathes
    local p = math.min(1, t / 0.32)
    local s = (p < 1) and (2.6 - 1.6 * p * p) or (1 + 0.03 * math.sin((t - 0.32) * 6))
    local rot = (p < 1) and (-0.25 * (1 - p)) or math.sin(t * 2.2) * 0.02
    local font = Theme.fonts.big
    love.graphics.setFont(font)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(rot)
    love.graphics.scale(s * 2.3)
    local w = font:getWidth(title)
    love.graphics.setColor(0, 0, 0, 0.6 * a)
    love.graphics.print(title, -w / 2 + 4, -font:getHeight() / 2 + 5)
    love.graphics.setColor(g[1], g[2], g[3], a)
    love.graphics.print(title, -w / 2, -font:getHeight() / 2)
    love.graphics.pop()

    -- subtitle slides up a beat later
    if subtitle ~= "" then
        local sp = math.max(0, math.min(1, (t - 0.45) / 0.35))
        if sp > 0 then
            local e = easeOutBack(sp)
            love.graphics.setFont(Theme.fonts.normal)
            Theme.color("text", a * sp)
            Theme.printf(subtitle, cx - 600, cy + 80 + (1 - e) * 60, 1200, "center")
        end
    end
    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1, 1)
end

return Celebration
