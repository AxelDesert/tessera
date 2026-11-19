-- Game-feel effects: particles, floating text, screen shake and tiny synth sounds.
-- Everything is drawn in the 1920x1080 virtual screen (see ui/screen.lua).
--
--   Fx.load()                        once, in love.load
--   Fx.update(dt) / Fx.draw()        every frame (draw on top of the game layer)
--   Fx.burst(x, y, color, n, speed)  pixel sparks flying out of a point
--   Fx.sparkle(x, y, color)          one small rising sparkle
--   Fx.ring(x, y, color, size)       expanding shockwave ring
--   Fx.text(x, y, str, color, big, rise)  popup text that rises (rise px/s) and fades
--   Fx.shake(amount)                 add screen shake (0..1), ignored if Options > Screen shake is off
--   Fx.offset()                      dx, dy to translate the game layer by
--   Fx.play(name, pitch)             play a synthesized sound (scaled by Options > Sound effects)
--   Fx.synth(notes, vol)             build a sound source (also used by ui/menu.lua)
--   Fx.confetti(n)                   colorful paper raining from the top of the screen
--   Fx.firework(x, y)                colorful burst + ring
--   Fx.counter(value)                number that counts up/down smoothly to a target:
--                                      c:set(target)  c:snap(value)  c:update(dt) -> true on each tick
--                                      c.value (number to show)  c.pop (0..1, kicks on every tick)  c:busy()

local Settings = require("core.settings")
local Theme    = require("ui.theme")

local Fx = {}

local parts, rings, texts = {}, {}, {}
local trauma, time = 0, 0
local MAX_SHAKE = 26          -- pixels at full trauma
local sounds = {}

---------------------------------------------------------------------------
-- sounds
---------------------------------------------------------------------------
-- notes = { {freq, seconds [, endFreq]}, ... }   pulse wave with a decay envelope
function Fx.synth(notes, vol)
    local rate, total = 22050, 0
    for _, n in ipairs(notes) do total = total + math.floor(n[2] * rate) end
    local sd = love.sound.newSoundData(total, rate, 16, 1)
    local pos, phase = 0, 0
    for _, n in ipairs(notes) do
        local len = math.floor(n[2] * rate)
        local f0, f1 = n[1], n[3] or n[1]
        for i = 0, len - 1 do
            local p = i / len
            phase = phase + (f0 + (f1 - f0) * p) / rate
            local wave = ((phase % 1) < 0.3) and 1 or -1
            local env = math.min(1, i / (rate * 0.004)) * (1 - p) ^ 1.5
            sd:setSample(pos + i, wave * env * vol)
        end
        pos = pos + len
    end
    return love.audio.newSource(sd, "static")
end

function Fx.play(name, pitch)
    local s, v = sounds[name], Settings.data.sfx
    if not s or v <= 0 then return end
    s = s:clone()
    s:setVolume(v)
    s:setPitch(pitch or 1)
    s:play()
end

function Fx.load()
    sounds = {
        hover   = Fx.synth({ { 900, 0.02 } }, 0.10),
        pick    = Fx.synth({ { 520, 0.04 }, { 880, 0.07, 1100 } }, 0.28),
        unpick  = Fx.synth({ { 700, 0.04 }, { 420, 0.07, 360 } }, 0.22),
        chip    = Fx.synth({ { 660, 0.05 }, { 990, 0.09 } }, 0.26),
        joker   = Fx.synth({ { 392, 0.05 }, { 523, 0.05 }, { 784, 0.12, 820 } }, 0.28),
        score   = Fx.synth({ { 523, 0.06 }, { 659, 0.06 }, { 784, 0.06 }, { 1047, 0.25, 1100 } }, 0.32),
        tick    = Fx.synth({ { 1400, 0.018 } }, 0.12),
        coin    = Fx.synth({ { 1320, 0.04 }, { 1760, 0.12 } }, 0.22),
        land    = Fx.synth({ { 180, 0.05, 90 } }, 0.30),
        bank    = Fx.synth({ { 392, 0.05 }, { 523, 0.05 }, { 659, 0.05 }, { 784, 0.05 }, { 1047, 0.3, 1047 } }, 0.30),
        fanfare = Fx.synth({ { 523, 0.10 }, { 523, 0.06 }, { 523, 0.06 }, { 659, 0.12 }, { 784, 0.12 },
                             { 659, 0.08 }, { 784, 0.08 }, { 1047, 0.5, 1050 } }, 0.32),
    }
end

---------------------------------------------------------------------------
-- spawners
---------------------------------------------------------------------------
local function col(c) return { c[1], c[2], c[3] } end

function Fx.burst(x, y, color, n, speed)
    color, n, speed = color or Theme.colors.gold, n or 20, speed or 420
    for _ = 1, n do
        local a = math.random() * math.pi * 2
        local v = speed * (0.35 + math.random() * 0.65)
        local life = 0.45 + math.random() * 0.45
        local light = math.random() < 0.35
        parts[#parts + 1] = {
            x = x, y = y, vx = math.cos(a) * v, vy = math.sin(a) * v - speed * 0.25,
            life = life, max = life, size = 5 + math.random() * 7,
            rot = math.random() * 6, spin = (math.random() - 0.5) * 14,
            grav = 900, drag = 2.2,
            color = light and { 1, 1, 1 } or col(color),
        }
    end
end

function Fx.sparkle(x, y, color)
    local life = 0.6 + math.random() * 0.5
    parts[#parts + 1] = {
        x = x, y = y, vx = (math.random() - 0.5) * 40, vy = -60 - math.random() * 60,
        life = life, max = life, size = 3 + math.random() * 4,
        rot = 0.785, spin = 0, grav = 0, drag = 0.5,
        color = col(color or Theme.colors.gold),
    }
end

function Fx.ring(x, y, color, size)
    rings[#rings + 1] = { x = x, y = y, r = 10, max = size or 160, life = 0.45, t = 0.45, color = col(color or Theme.colors.gold) }
end

function Fx.text(x, y, str, color, big, rise)
    texts[#texts + 1] = { x = x, y = y, str = str, color = col(color or Theme.colors.gold),
                          rise = rise or (big and 50 or 70),
                          life = big and 1.4 or 1.0, max = big and 1.4 or 1.0, big = big }
end

local PALETTE = {
    { 0.99, 0.65, 0.15 }, { 0.996, 0.298, 0.251 }, { 0.004, 0.573, 0.976 },
    { 0.35, 0.85, 0.45 }, { 1, 1, 1 }, { 0.75, 0.45, 0.95 },
}

function Fx.confetti(n)
    local Screen = require("ui.screen")
    for _ = 1, n or 120 do
        local life = 2.5 + math.random() * 2
        parts[#parts + 1] = {
            x = Screen.left + math.random() * (Screen.right - Screen.left),
            y = Screen.top - 20 - math.random() * 400,
            vx = (math.random() - 0.5) * 160, vy = 80 + math.random() * 160,
            life = life, max = life, size = 10 + math.random() * 8,
            rot = math.random() * 6, spin = (math.random() - 0.5) * 10,
            grav = 120, drag = 0.6, confetti = true, flip = math.random() * 6,
            color = PALETTE[math.random(#PALETTE)],
        }
    end
end

function Fx.firework(x, y)
    local c = PALETTE[math.random(#PALETTE)]
    Fx.burst(x, y, c, 46, 620)
    Fx.ring(x, y, c, 200)
end

-- smoothly counting number (see header)
local Counter = {}
Counter.__index = Counter

function Fx.counter(value)
    return setmetatable({ value = value or 0, from = value or 0, target = value or 0,
                          t = 0, dur = 0, pop = 0, tickT = 0 }, Counter)
end

function Counter:snap(v)
    self.value, self.from, self.target, self.t, self.dur = v, v, v, 0, 0
end

function Counter:set(target)
    if target == self.target then return end
    local diff = math.abs(target - self.value)
    self.from, self.target, self.t = self.value, target, 0
    self.dur = math.min(1.3, 0.35 + math.log10(diff + 1) * 0.2)
end

function Counter:busy() return self.value ~= self.target end

function Counter:update(dt)
    self.pop = math.max(0, self.pop - dt * 5)
    if self.value == self.target then return false end
    self.t = self.t + dt
    local p = math.min(1, self.t / self.dur)
    local e = 1 - (1 - p) ^ 3
    local nv = math.floor(self.from + (self.target - self.from) * e + 0.5)
    if p >= 1 then nv = self.target end
    local changed = nv ~= self.value
    self.value = nv
    self.tickT = self.tickT - dt
    if changed and (self.tickT <= 0 or p >= 1) then
        self.tickT, self.pop = 0.05, 1
        return true
    end
    return false
end

function Fx.shake(amount)
    trauma = math.min(1, trauma + amount)
end

function Fx.offset()
    if not Settings.data.shake or trauma <= 0 then return 0, 0 end
    local k = MAX_SHAKE * trauma * trauma
    return (love.math.noise(time * 28, 1.7) * 2 - 1) * k, (love.math.noise(4.3, time * 28) * 2 - 1) * k
end

---------------------------------------------------------------------------
-- update / draw
---------------------------------------------------------------------------
local function sweep(list, dt)
    for i = #list, 1, -1 do
        local p = list[i]
        p.life = p.life - dt
        if p.life <= 0 then table.remove(list, i) end
    end
end

function Fx.update(dt)
    time = time + dt
    trauma = math.max(0, trauma - dt * 1.6)

    for _, p in ipairs(parts) do
        local d = math.max(0, 1 - p.drag * dt)
        p.vx, p.vy = p.vx * d, p.vy * d + p.grav * dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.rot = p.rot + p.spin * dt
        if p.confetti then
            p.flip = p.flip + dt * 7
            p.vx = p.vx + math.sin(p.flip * 0.7) * 120 * dt     -- flutter side to side
        end
    end
    for _, r in ipairs(rings) do
        r.r = r.r + (r.max - r.r) * math.min(1, dt * 9)
    end
    for _, t in ipairs(texts) do
        t.y = t.y - dt * t.rise
    end
    sweep(parts, dt); sweep(rings, dt); sweep(texts, dt)
end

function Fx.draw()
    for _, r in ipairs(rings) do
        local a = r.life / r.t
        love.graphics.setColor(r.color[1], r.color[2], r.color[3], a * 0.8)
        love.graphics.setLineWidth(3 + 10 * a)
        love.graphics.circle("line", r.x, r.y, r.r)
    end
    love.graphics.setLineWidth(1)

    for _, p in ipairs(parts) do
        local a = p.life / p.max
        local s = p.size * (0.4 + 0.6 * a)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], math.min(1, a * 1.6))
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.rot)
        if p.confetti then
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], math.min(1, p.life))
            love.graphics.rectangle("fill", -p.size / 2 * math.cos(p.flip), -p.size * 0.3, p.size * math.cos(p.flip), p.size * 0.6)
        else
            love.graphics.rectangle("fill", -s / 2, -s / 2, s, s)
        end
        love.graphics.pop()
    end

    for _, t in ipairs(texts) do
        local age = t.max - t.life
        local font = t.big and Theme.fonts.big or Theme.fonts.normal
        local pop = 1 + 0.6 * math.max(0, 1 - age * 6)            -- punch in, then settle
        local a = math.min(1, t.life / 0.35)
        love.graphics.setFont(font)
        love.graphics.setColor(t.color[1], t.color[2], t.color[3], a)
        Theme.print(t.str, t.x, t.y, 0, pop, pop, math.floor(font:getWidth(t.str) / 2), math.floor(font:getHeight() / 2))
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Fx
