local test = require("animation")

function love.load()
    love.window.setMode(1920, 1080, {resizable=true, vsync=0, minwidth=400, minheight=300})
    animation = test(love.graphics.newImage("dice.png"), 206, 202, 5)
end

function love.update(dt)
    animation.currentTime = animation.currentTime + dt
    if animation.currentTime >= animation.duration then
        animation.currentTime = animation.currentTime - animation.duration
    end
end

function love.draw()
    local spriteNum = math.floor(animation.currentTime / animation.duration * #animation.quads) + 1
    love.graphics.draw(animation.spriteSheet, animation.quads[spriteNum], 0, 0, 0, 4)
end