-- Shared colors, fonts and small drawing helpers for every ui/ file.
-- Sprites: assets/ui/*.png (nine-slice, drawn 1:1 in 1920x1080 game pixels)
-- Font:    assets/fonts/Jersey10-Regular.ttf (SIL Open Font License)

local Theme = {}

Theme.colors = {
    panel    = {0.05, 0.05, 0.08, 0.75},
    border   = {1, 1, 1, 0.15},
    text     = {1, 1, 1, 1},
    dim      = {0.75, 0.80, 0.90, 1},
    chips    = {0.004, 0.573, 0.976, 1},   -- Balatro blue
    mult     = {0.996, 0.298, 0.251, 1},   -- Balatro red
    gold     = {0.99, 0.65, 0.15, 1},
    orange   = {1, 0.63, 0, 1},
    good     = {0.35, 0.85, 0.45, 1},
    bad      = {0.90, 0.30, 0.30, 1},
    button   = {0.20, 0.70, 0.42, 1},
    disabled = {0.33, 0.36, 0.44, 1},
    ink      = {0.26, 0.33, 0.34, 1},      -- dark slate text on white cards
    sidebar      = {0.157, 0.298, 0.737, 1},
    sidebar_edge = {0.086, 0.125, 0.235, 1},
    -- flat fallbacks used only if a sprite file is missing
    blue = {0.21, 0.37, 0.89, 1}, dark = {0.08, 0.11, 0.17, 1}, inset = {0.12, 0.17, 0.27, 1},
    card = {1, 1, 1, 1}, button_red = {0.996, 0.298, 0.251, 1}, button_orange = {1, 0.63, 0, 1},
}

Theme.SHADOW = 3   -- text drop shadow, in game pixels

-- name -> { file, left, top, right, bottom }   (nine-slice margins in pixels)
local SLICES = {
    panel         = { "panel_navy", 20, 20, 20, 20 },
    dark          = { "panel_dark", 20, 20, 20, 20 },
    inset         = { "inset",      16, 16, 16, 16 },
    blue          = { "box_blue",   18, 18, 18, 24 },
    header        = { "box_blue",   18, 18, 18, 24 },
    button        = { "btn_green",  18, 18, 18, 24 },
    button_red    = { "btn_red",    18, 18, 18, 24 },
    button_orange = { "btn_orange", 18, 18, 18, 24 },
    disabled      = { "btn_gray",   18, 18, 18, 24 },
    chips         = { "box_chips",  18, 18, 18, 24 },
    mult          = { "box_mult",   18, 18, 18, 24 },
    card          = { "card",       16, 16, 16, 22 },
}
Theme.slices = {}

local FONT = "assets/fonts/Jersey10-Regular.ttf"
local function makeFont(size)
    if love.filesystem.getInfo(FONT) then
        local f = love.graphics.newFont(FONT, size)
        f:setFilter("nearest", "nearest")      -- keep the pixel font crisp
        return f
    end
    return love.graphics.newFont(size)         -- fallback: LÖVE default font
end

local function loadImage(file)
    local path = "assets/ui/" .. file .. ".png"
    if not love.filesystem.getInfo(path) then return nil end   -- falls back to flat colors
    return love.graphics.newImage(path)
end

local function loadSlice(file, l, t, r, b)
    local img = loadImage(file)
    if not img then return nil end
    local iw, ih = img:getDimensions()
    local Q = function(x, y, w, h) return love.graphics.newQuad(x, y, w, h, iw, ih) end
    return {
        img = img, l = l, t = t, r = r, b = b, iw = iw, ih = ih,
        q = {
            tl = Q(0, 0, l, t),           tm = Q(l, 0, iw - l - r, t),           tr = Q(iw - r, 0, r, t),
            ml = Q(0, t, l, ih - t - b),  mm = Q(l, t, iw - l - r, ih - t - b),  mr = Q(iw - r, t, r, ih - t - b),
            bl = Q(0, ih - b, l, b),      bm = Q(l, ih - b, iw - l - r, b),      br = Q(iw - r, ih - b, r, b),
        },
    }
end

-- Call once from love.load
function Theme.load()
    Theme.fonts = { tiny = makeFont(20), small = makeFont(30), normal = makeFont(40), big = makeFont(60), num = makeFont(70) }
    love.graphics.setFont(Theme.fonts.normal)
    for name, d in pairs(SLICES) do Theme.slices[name] = loadSlice(unpack(d)) end
    Theme.chipImage  = loadImage("chip_icon")
    Theme.tokenImage = loadImage("token")
    Theme.tokenRed   = loadImage("token_red")
end

function Theme.color(name, alpha)
    local c = Theme.colors[name]
    love.graphics.setColor(c[1], c[2], c[3], (alpha or 1) * c[4])
end

-- Draws a nine-slice sprite stretched to w x h (corners keep their size)
function Theme.nine(sl, x, y, w, h)
    local l, t, r, b = sl.l, sl.t, sl.r, sl.b
    x, y, w, h = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
    local mw, mh = math.max(0, w - l - r), math.max(0, h - t - b)
    local sx, sy = mw / (sl.iw - l - r), mh / (sl.ih - t - b)
    local q, img, g = sl.q, sl.img, love.graphics
    g.setColor(1, 1, 1, 1)
    g.draw(img, q.tl, x,          y,          0, 1,  1)
    g.draw(img, q.tm, x + l,      y,          0, sx, 1)
    g.draw(img, q.tr, x + l + mw, y,          0, 1,  1)
    g.draw(img, q.ml, x,          y + t,      0, 1,  sy)
    g.draw(img, q.mm, x + l,      y + t,      0, sx, sy)
    g.draw(img, q.mr, x + l + mw, y + t,      0, 1,  sy)
    g.draw(img, q.bl, x,          y + t + mh, 0, 1,  1)
    g.draw(img, q.bm, x + l,      y + t + mh, 0, sx, 1)
    g.draw(img, q.br, x + l + mw, y + t + mh, 0, 1,  1)
end

function Theme.box(x, y, w, h, name, radius)
    local sl = Theme.slices[name]
    if sl then Theme.nine(sl, x, y, w, h) return end
    Theme.color(name)
    love.graphics.rectangle("fill", x, y, w, h, radius or 8, radius or 8)
end

function Theme.panel(x, y, w, h)
    if Theme.slices.panel then Theme.nine(Theme.slices.panel, x, y, w, h) return end
    Theme.box(x, y, w, h, "panel", 10)
    Theme.color("border")
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
end

-- Poker-chip icon (size = width in pixels)
function Theme.chip(x, y, size)
    local img = Theme.chipImage
    if not img then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor(x), math.floor(y), 0, size / img:getWidth())
end

-- Big blind token; red = boss floor
function Theme.token(x, y, size, red)
    local img = (red and Theme.tokenRed) or Theme.tokenImage
    if not img then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor(x), math.floor(y), 0, size / img:getWidth())
end

-- Text with a Balatro-style drop shadow (uses the current color)
function Theme.print(text, x, y, ...)
    x, y = math.floor(x), math.floor(y)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(0, 0, 0, 0.5 * a)
    love.graphics.print(text, x + Theme.SHADOW, y + Theme.SHADOW, ...)
    love.graphics.setColor(r, g, b, a)
    love.graphics.print(text, x, y, ...)
end

function Theme.printf(text, x, y, limit, align, ...)
    x, y = math.floor(x), math.floor(y)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(0, 0, 0, 0.5 * a)
    love.graphics.printf(text, x + Theme.SHADOW, y + Theme.SHADOW, limit, align, ...)
    love.graphics.setColor(r, g, b, a)
    love.graphics.printf(text, x, y, limit, align, ...)
end

return Theme
