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
}

-- Call once from love.load
function Theme.load()
    Theme.fonts = {
        small  = love.graphics.newFont(16),
        normal = love.graphics.newFont(22),
        big    = love.graphics.newFont(40),
    }
    love.graphics.setFont(Theme.fonts.normal)
end

function Theme.color(name, alpha)
    local c = Theme.colors[name]
    love.graphics.setColor(c[1], c[2], c[3], (alpha or 1) * c[4])
end

function Theme.box(x, y, w, h, name, radius)
    Theme.color(name)
    love.graphics.rectangle("fill", x, y, w, h, radius or 8, radius or 8)
end

function Theme.panel(x, y, w, h)
    Theme.box(x, y, w, h, "panel", 10)
    Theme.color("border")
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
end

return Theme
