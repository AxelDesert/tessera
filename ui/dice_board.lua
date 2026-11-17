local Screen = require("ui.screen")

local DiceBoard = {}

local DICE_W, DICE_H = 206, 202
local GAP = 20
local SIDEBAR_W = Screen.SIDEBAR_W
local faceFrame = {1, 2, 3, 4, 5, 6}

local anim, dustPS

-- Absorbed animation logic!
local function newAnimation(image, width, height)
    local animation = { spriteSheet = image, quads = {} }
    for y = 0, image:getHeight() - height, height do
        for x = 0, image:getWidth() - width, width do
            table.insert(animation.quads, love.graphics.newQuad(x, y, width, height, image:getDimensions()))
        end
    end
    return animation
end

function DiceBoard.load()
    anim = newAnimation(love.graphics.newImage("assets/dice.png"), DICE_W, DICE_H)

    local pixel = love.image.newImageData(2, 2)
    pixel:mapPixel(function() return 1, 1, 1, 1 end)
    
    dustPS = love.graphics.newParticleSystem(love.graphics.newImage(pixel), 2000)
    dustPS:setParticleLifetime(1, 2.5)
    dustPS:setEmissionArea("uniform", DICE_W / 3, DICE_H / 3, 0, true)
    dustPS:setColors(0.4, 0.4, 0.4, 1, 0.2, 0.2, 0.2, 0.8, 0.1, 0.1, 0.1, 0)
    dustPS:setSizes(2.5, 1.5, 5.5)
    dustPS:setLinearAcceleration(20, -30, 80, -120)
    dustPS:setSpin(-5, 5)
end

local function layout(visibleCount)
    visibleCount = visibleCount or 6
    local w, h = Screen.W, Screen.H
    local areaX, areaW = SIDEBAR_W + 20, w - SIDEBAR_W - 40
    local scale = math.min(1, (areaW - 5 * GAP) / (6 * DICE_W))
    local totalW = visibleCount * DICE_W * scale + math.max(0, visibleCount - 1) * GAP
    return areaX + (areaW - totalW) / 2, h / 2 - DICE_H * scale / 2 + 30, scale
end

function DiceBoard.snapDice(dice)
    local visibleCount = 0
    for _, d in ipairs(dice) do
        if not d.kept then visibleCount = visibleCount + 1 end
    end
    
    local x0, y0, scale = layout(visibleCount)
    local drawIndex = 0
    
    for _, d in ipairs(dice) do
        if not d.kept then
            if d.selected then 
                local cx = x0 + drawIndex * (DICE_W * scale + GAP) + (DICE_W * scale) / 2
                local cy = y0 - 30 + (DICE_H * scale) / 2
                dustPS:setPosition(cx, cy)
                dustPS:emit(200)
                
                d.dying = true 
                d.selected = false 
            end
            drawIndex = drawIndex + 1
        end
    end
end

function DiceBoard.update(dt, dice)
    dustPS:update(dt)
    
    local visibleCount = 0
    for _, d in ipairs(dice) do
        if not d.kept then visibleCount = visibleCount + 1 end
    end
    
    local x0, y0, scale = layout(visibleCount)
    local drawIndex = 0
    
    for i, d in ipairs(dice) do
        if not d.kept then
            local targetX = x0 + drawIndex * (DICE_W * scale + GAP)
            if not d.x then d.x = targetX end 
            d.x = d.x + (targetX - d.x) * 15 * dt
            drawIndex = drawIndex + 1
        end
    end
end

function DiceBoard.draw(dice)
    local visibleCount = 0
    for _, d in ipairs(dice) do
        if d.slashed then
            return
        end
        if not d.kept then visibleCount = visibleCount + 1 end
    end
    local _, y0, scale = layout(visibleCount)
    
    for i, d in ipairs(dice) do
        if not d.kept and not d.dying then
            local x = d.x or 0 
            local y = y0
            local frame
            
            if d.rolling > 0 then
                frame = math.floor(love.timer.getTime() * 15 + i * 2) % #anim.quads + 1
            else
                frame = faceFrame[d.value]
            end
            
            if d.selected then y = y - 30 end
            if d.selected then love.graphics.setColor(1, 1, 0.4)
            else love.graphics.setColor(1, 1, 1) end
            
            love.graphics.draw(anim.spriteSheet, anim.quads[frame], x, y, 0, scale)
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(dustPS)
end

function DiceBoard.mousepressed(mx, my, dice)
    local visibleCount = 0
    for _, d in ipairs(dice) do
        if not d.kept then visibleCount = visibleCount + 1 end
    end
    local _, y0, scale = layout(visibleCount)
    
    local clicked = false
    for _, d in ipairs(dice) do
        if not d.kept and not d.dying then
            if d.x and mx >= d.x and mx <= d.x + DICE_W * scale
                    and my >= y0 - 30 and my <= y0 + DICE_H * scale then
                d.selected = not d.selected
                clicked = true
            end
        end
    end
    return clicked
end

return DiceBoard