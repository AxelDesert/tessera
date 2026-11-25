-- Pixel-art card bodies, painted in code (4x4 blocks) and cached per size.
-- Every family has its own silhouette, so they can be told apart at a glance:
--   joker   playing card with a harlequin border in the joker's color
--   combo   blue ticket: perforated sides, two notches and a tear line
--   charm   purple talisman: cut corners, gold trim and light rays
--   die     felt tray with a wooden rim (the die itself is drawn on top)
--
--   CardFrames.draw(style, x, y, w, h, tileH, color)   color = joker tile color
--   CardFrames.TEXT[style] = { title color, description color }

local CardFrames = {}

local PX = 4
local INK, CLEAR = { 30, 38, 52 }, nil

CardFrames.TEXT = {
    joker = { { 0.26, 0.33, 0.34 }, { 0.45, 0.52, 0.58 } },
    combo = { { 0.08, 0.20, 0.50 }, { 0.22, 0.36, 0.62 } },
    charm = { { 1, 0.86, 0.48 },    { 0.90, 0.80, 0.98 } },
    die   = { { 1, 1, 1 },          { 0.80, 0.86, 0.92 } },
}

local function mix(c, k) return { c[1] * k, c[2] * k, c[3] * k } end

-- Each painter: (x, y) block, (w, h) size in blocks, t = first block row under the picture, c = color
local PAINT = {}

function PAINT.joker(x, y, w, h, t, c)
    local e = math.min(x, y, w - 1 - x, h - 1 - y)
    local corner = math.min(x, w - 1 - x) + math.min(y, h - 1 - y)
    if corner < 2 then return CLEAR end
    if e == 0 or corner == 2 then return INK end
    if y == h - 2 then return { 176, 186, 200 } end
    if e <= 2 then return (x + y) % 6 < 3 and mix(c, 0.9) or { 250, 250, 252 } end
    if e == 3 then return y < t and INK or { 255, 255, 255 } end
    if y < t - 1 then return mix(c, y < t / 2 and 1.14 or 1) end
    if y == t - 1 then return INK end
    return { 255, 255, 255 }
end

function PAINT.combo(x, y, w, h, t)
    local side = math.min(x, w - 1 - x)
    local edgeY = math.min(y, h - 1 - y)
    local function inside(sx, sy)
        if sx < 0 or sy < 0 or sy > h - 1 then return false end
        if sx == 0 and sy % 4 < 2 then return false end              -- perforation
        local dy = sy - t
        return sx * sx + dy * dy > 12                                -- notch at the tear line
    end
    if not inside(side, y) then return CLEAR end
    if edgeY == 0 or side == 0 or not inside(side - 1, y) or not inside(side, y - 1) or not inside(side, y + 1) then return INK end
    if y == t then return x % 4 < 2 and { 40, 80, 160 } or { 214, 230, 255 } end
    if y > t then return y >= h - 2 and { 150, 176, 222 } or { 214, 230, 255 } end
    if side < 3 or y < 3 then return { 24, 58, 130 } end
    return ((x - 3) % 5 == 0 or (y - 3) % 5 == 0) and { 62, 118, 208 } or { 42, 94, 186 }
end

function PAINT.charm(x, y, w, h, t)
    local sx, sy = math.min(x, w - 1 - x), math.min(y, h - 1 - y)
    local corner = sx + sy - 5                                       -- cut corners
    local e = math.min(sx, sy, corner)
    if e < 0 then return CLEAR end
    if e == 0 then return INK end
    if e == 1 then return y > h / 2 and { 206, 140, 40 } or { 253, 190, 60 } end
    if e == 2 then return { 44, 20, 66 } end
    if y == t - 1 then return (sx > 3) and { 206, 140, 40 } or { 44, 20, 66 } end
    if y >= t then return { 66, 34, 98 } end
    local ang = math.atan2(y + 0.5 - t / 2, x + 0.5 - w / 2) / (2 * math.pi)
    return (ang * 16) % 1 < 0.5 and { 168, 74, 168 } or { 130, 54, 148 }
end

function PAINT.die(x, y, w, h, t)
    local e = math.min(x, y, w - 1 - x, h - 1 - y)
    local corner = math.min(x, w - 1 - x) + math.min(y, h - 1 - y)
    if corner < 1 then return CLEAR end
    if e == 0 then return INK end
    if e <= 2 then return (e == 1) and { 168, 108, 62 } or { 118, 72, 44 } end
    if y >= t then return y == t and { 118, 72, 44 } or { 36, 50, 76 } end
    if e == 3 then return { 20, 78, 56 } end                         -- shadow of the rim
    return (x + y) % 8 == 0 and { 40, 128, 88 } or { 32, 112, 78 }
end

local cache = {}

local function build(style, w, h, t, c)
    local data = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local p = PAINT[style](x, y, w, h, t, c)
            if p then
                data:setPixel(x, y, math.min(1, p[1] / 255), math.min(1, p[2] / 255), math.min(1, p[3] / 255), 1)
            end
        end
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return img
end

function CardFrames.draw(style, x, y, w, h, tileH, color)
    color = color or { 1, 1, 1 }
    local bw, bh = math.floor(w / PX + 0.5), math.floor(h / PX + 0.5)
    local t = math.floor(tileH / PX + 0.5)
    local key = table.concat({ style, bw, bh, t, color[1], color[2], color[3] }, "|")
    local img = cache[key]
    if not img then
        img = build(style, bw, bh, t, { color[1] * 255, color[2] * 255, color[3] * 255 })
        cache[key] = img
    end
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.draw(img, x + 4, y + 6, 0, w / bw, h / bh)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, x, y, 0, w / bw, h / bh)
end

return CardFrames
