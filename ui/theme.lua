-- Shared colors, fonts and small drawing helpers for every ui/ file.

local Theme = {}

Theme.colors = {
    panel    = {0.05, 0.05, 0.08, 0.75},
    border   = {1, 1, 1, 0.15},
    text     = {1, 1, 1, 1},
    dim      = {0.75, 0.75, 0.8, 1},
    chips    = {0.18, 0.50, 0.95, 1},
    mult     = {0.90, 0.22, 0.22, 1},
    gold     = {1, 0.84, 0.30, 1},
    good     = {0.35, 0.85, 0.45, 1},
    bad      = {0.90, 0.30, 0.30, 1},
    button   = {0.20, 0.55, 0.35, 1},
    disabled = {0.30, 0.30, 0.33, 1},
    ink      = {0.26, 0.33, 0.34, 1},   -- dark slate text on white cards
}

-- Pixel-art skin: art is drawn at 1 pixel, shown at SCALE screen pixels.
-- name -> { file, left, top, right, bottom } (nine-slice margins, art pixels)
Theme.SCALE  = 2
Theme.SHADOW = 2
local SLICES = {
    panel         = { "panel",      4, 4, 4, 4 },
    inset         = { "inset",      3, 3, 3, 3 },
    header        = { "header",     4, 4, 4, 5 },
    button        = { "btn_green",  4, 4, 4, 5 },
    button_red    = { "btn_red",    4, 4, 4, 5 },
    button_orange = { "btn_orange", 4, 4, 4, 5 },
    disabled      = { "btn_gray",   4, 4, 4, 5 },
    chips         = { "box_chips",  4, 4, 4, 5 },
    mult          = { "box_mult",   4, 4, 4, 5 },
    card          = { "card",       4, 4, 4, 4 },
}
Theme.slices = {}

local function loadSlice(file, l, t, r, b)
    local path = "assets/ui/" .. file .. ".png"
    if not love.filesystem.getInfo(path) then return nil end   -- falls back to flat colors
    local img = love.graphics.newImage(path)
    img:setFilter("nearest", "nearest")
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
    Theme.fonts = {
        small  = love.graphics.newFont(16),
        normal = love.graphics.newFont(22),
        big    = love.graphics.newFont(40),
    }
    love.graphics.setFont(Theme.fonts.normal)

    for name, d in pairs(SLICES) do Theme.slices[name] = loadSlice(unpack(d)) end
    local chip = "assets/ui/chip_icon.png"
    if love.filesystem.getInfo(chip) then
        Theme.chipIcon = love.graphics.newImage(chip)
        Theme.chipIcon:setFilter("nearest", "nearest")
    end
end

-- Draws a nine-slice sprite stretched to w x h (corners keep their pixel size)
function Theme.nine(sl, x, y, w, h)
    local s = Theme.SCALE
    local l, t, r, b = sl.l * s, sl.t * s, sl.r * s, sl.b * s
    x, y, w, h = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
    local mw, mh = math.max(0, w - l - r), math.max(0, h - t - b)
    local sx, sy = mw / (sl.iw - sl.l - sl.r), mh / (sl.ih - sl.t - sl.b)
    local q, img, g = sl.q, sl.img, love.graphics
    g.setColor(1, 1, 1, 1)
    g.draw(img, q.tl, x,         y,         0, s,  s)
    g.draw(img, q.tm, x + l,     y,         0, sx, s)
    g.draw(img, q.tr, x + l + mw, y,        0, s,  s)
    g.draw(img, q.ml, x,         y + t,     0, s,  sy)
    g.draw(img, q.mm, x + l,     y + t,     0, sx, sy)
    g.draw(img, q.mr, x + l + mw, y + t,    0, s,  sy)
    g.draw(img, q.bl, x,         y + t + mh, 0, s,  s)
    g.draw(img, q.bm, x + l,     y + t + mh, 0, sx, s)
    g.draw(img, q.br, x + l + mw, y + t + mh, 0, s, s)
end

-- Text with a Balatro-style drop shadow (uses the current color)
function Theme.print(text, x, y, ...)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.print(text, x + Theme.SHADOW, y + Theme.SHADOW, ...)
    love.graphics.setColor(r, g, b, a)
    love.graphics.print(text, x, y, ...)
end

function Theme.printf(text, x, y, limit, align, ...)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.printf(text, x + Theme.SHADOW, y + Theme.SHADOW, limit, align, ...)
    love.graphics.setColor(r, g, b, a)
    love.graphics.printf(text, x, y, limit, align, ...)
end

function Theme.color(name, alpha)
    local c = Theme.colors[name]
    love.graphics.setColor(c[1], c[2], c[3], (alpha or 1) * c[4])
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

return Theme
