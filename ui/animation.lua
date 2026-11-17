-- animation.lua
local Screen = require("ui.screen")

local FarkleAnim = {
    active = false,
    timer = 0,
    duration = 2.0, -- Increased slightly so you can see the whole 40-frame animation
    shake = 0,
    lines = {},
    
    -- Spritesheet variables
    spritesheet = nil,
    quads = {},
    frameWidth = 0,
    frameHeight = 0,
    
    -- Animation state
    currentFrame = 1,
    frameTimer = 0,
    fps = 24 -- 40 frames at 24fps takes about 1.6 seconds
}

-- CALL THIS ONCE IN love.load() IN YOUR main.lua
function FarkleAnim.load()
    -- Load the spritesheet image
    FarkleAnim.spritesheet = love.graphics.newImage("assets/farke_anim_spritesheet.png")
    FarkleAnim.quads = {}

    local imgW = FarkleAnim.spritesheet:getWidth()
    local imgH = FarkleAnim.spritesheet:getHeight()
    
    -- The grid is 5 columns by 8 rows based on your image
    local columns = 5
    local rows = 8
    
    FarkleAnim.frameWidth = imgW / columns
    FarkleAnim.frameHeight = imgH / rows
    
    -- Generate Quads from left to right, top to bottom
    for y = 0, rows - 1 do
        for x = 0, columns - 1 do
            local quad = love.graphics.newQuad(
                x * FarkleAnim.frameWidth,
                y * FarkleAnim.frameHeight,
                FarkleAnim.frameWidth,
                FarkleAnim.frameHeight,
                imgW,
                imgH
            )
            table.insert(FarkleAnim.quads, quad)
        end
    end
end

function FarkleAnim.trigger()
    FarkleAnim.active = true
    FarkleAnim.timer = 0
    FarkleAnim.shake = 40
    
    -- Reset animation to the first frame
    FarkleAnim.currentFrame = 1
    FarkleAnim.frameTimer = 0
    
    FarkleAnim.lines = {}
    for i = 1, 80 do
        table.insert(FarkleAnim.lines, {
            angle = math.random() * math.pi * 2,
            speed = math.random(1000, 2500),
            distance = math.random(50, 400),
            length = math.random(200, 800),
            thickness = math.random(1, 5)
        })
    end
end

function FarkleAnim.update(dt)
    if not FarkleAnim.active then return end
    
    FarkleAnim.timer = FarkleAnim.timer + dt
    
    -- 1. Advance the animation frames
    FarkleAnim.frameTimer = FarkleAnim.frameTimer + dt
    if FarkleAnim.frameTimer >= 1 / FarkleAnim.fps then
        FarkleAnim.frameTimer = FarkleAnim.frameTimer - (1 / FarkleAnim.fps)
        
        -- Stop advancing at the last frame so the final "FARKLEEE!!!" stays on screen
        if FarkleAnim.currentFrame < #FarkleAnim.quads then
            FarkleAnim.currentFrame = FarkleAnim.currentFrame + 1
        end
    end
    
    -- 2. Calm the screen shake
    if FarkleAnim.shake > 0 then
        FarkleAnim.shake = math.max(0, FarkleAnim.shake - (60 * dt))
    end
    
    -- 3. Move the action lines
    for _, line in ipairs(FarkleAnim.lines) do
        line.distance = line.distance + (line.speed * dt)
        if line.distance > 1500 then
            line.distance = math.random(0, 100)
        end
    end

    -- 4. End the animation
    if FarkleAnim.timer >= FarkleAnim.duration then
        FarkleAnim.active = false
    end
end

function FarkleAnim.draw()
    if not FarkleAnim.active then return end
    
    local w, h = Screen.W, Screen.H
    local centerX, centerY = w / 2, h / 2
    
    local dx = (math.random() * 2 - 1) * FarkleAnim.shake
    local dy = (math.random() * 2 - 1) * FarkleAnim.shake
    
    love.graphics.push()
    love.graphics.translate(dx, dy)
    
    -- Dark background for emphasis
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", -dx, -dy, w, h)
    
    -- Draw Action Lines
    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.setColor(1, 1, 1, 0.4)
    for _, line in ipairs(FarkleAnim.lines) do
        love.graphics.push()
        love.graphics.rotate(line.angle)
        love.graphics.setLineWidth(line.thickness)
        love.graphics.line(line.distance, 0, line.distance + line.length, 0)
        love.graphics.pop()
    end
    love.graphics.pop()
    
    -- Draw the current Spritesheet Frame
    love.graphics.setColor(1, 1, 1, 1)
    if FarkleAnim.spritesheet and #FarkleAnim.quads > 0 then
        -- Scale the animation up since individual frames might be small
        local scale = 1.8 
        
        love.graphics.draw(
            FarkleAnim.spritesheet,
            FarkleAnim.quads[FarkleAnim.currentFrame],
            centerX, centerY,
            0, -- rotation
            scale, scale,
            FarkleAnim.frameWidth / 2, FarkleAnim.frameHeight / 2 -- origin centered
        )
    end
    
    love.graphics.pop()
end

return FarkleAnim