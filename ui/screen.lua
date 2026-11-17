-- Virtual 1920x1080 screen, letterboxed into whatever window size the player has.
-- All UI code works in these 1920x1080 coordinates:
--   Screen.begin() / Screen.finish()   wrap love.draw
--   Screen.toGame(x, y)                window coords -> game coords (mouse)

local Screen = { W = 1920, H = 1080, SIDEBAR_W = 480, scale = 1, ox = 0, oy = 0 }

function Screen.begin()
    local ww, wh = love.graphics.getDimensions()
    Screen.scale = math.min(ww / Screen.W, wh / Screen.H)
    Screen.ox = (ww - Screen.W * Screen.scale) / 2
    Screen.oy = (wh - Screen.H * Screen.scale) / 2
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.push()
    love.graphics.translate(Screen.ox, Screen.oy)
    love.graphics.scale(Screen.scale)
end

function Screen.finish()
    love.graphics.pop()
end

function Screen.toGame(x, y)
    return (x - Screen.ox) / Screen.scale, (y - Screen.oy) / Screen.scale
end

function Screen.mouse()
    return Screen.toGame(love.mouse.getPosition())
end

return Screen
