-- Virtual 1920x1080 screen, letterboxed into whatever window size the player has.
-- All UI code works in these 1920x1080 coordinates:
--   Screen.begin() / Screen.finish()   wrap love.draw
--   Screen.toGame(x, y)                window coords -> game coords (mouse)
--   Screen.left/top/right/bottom       the whole window in game coords. Equal to
--                                      0/0/1920/1080 at 16:9, larger otherwise (the
--                                      letterbox area). Fill THIS, not 0,0,W,H, so
--                                      backgrounds and overlays never leave black bars.
--   Screen.fill()                      fills that whole area with the current color

local Screen = { W = 1920, H = 1080, SIDEBAR_W = 480, scale = 1, ox = 0, oy = 0,
                 left = 0, top = 0, right = 1920, bottom = 1080 }

function Screen.begin()
    local ww, wh = love.graphics.getDimensions()
    Screen.scale = math.min(ww / Screen.W, wh / Screen.H)
    Screen.ox = (ww - Screen.W * Screen.scale) / 2
    Screen.oy = (wh - Screen.H * Screen.scale) / 2
    Screen.left   = -Screen.ox / Screen.scale
    Screen.top    = -Screen.oy / Screen.scale
    Screen.right  = (ww - Screen.ox) / Screen.scale
    Screen.bottom = (wh - Screen.oy) / Screen.scale
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.push()
    love.graphics.translate(Screen.ox, Screen.oy)
    love.graphics.scale(Screen.scale)
end

function Screen.finish()
    love.graphics.pop()
end

function Screen.fill()
    love.graphics.rectangle("fill", Screen.left, Screen.top, Screen.right - Screen.left, Screen.bottom - Screen.top)
end

function Screen.toGame(x, y)
    return (x - Screen.ox) / Screen.scale, (y - Screen.oy) / Screen.scale
end

function Screen.mouse()
    return Screen.toGame(love.mouse.getPosition())
end

return Screen
