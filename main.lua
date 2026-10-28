local newAnimation = require("animation")
require("farkle")

local DICE_W, DICE_H = 206, 202
local GAP = 20
local ROLL_TIME = 0.8
local faceFrame = {1, 2, 3, 4, 5, 6}

local anim, dice, font
local state = "ready"
local roundScore, bank, message = 0, 0, "Press SPACE to roll"

function love.load()
    love.window.setMode(1920, 1080, {resizable=true, vsync=0, minwidth=400, minheight=300})
    font = love.graphics.newFont(28)
    love.graphics.setFont(font)
    bg = love.graphics.newImage("wallpaper.jpg")
    anim = newAnimation(love.graphics.newImage("dice.png"), DICE_W, DICE_H, 5)
    dice = {}
    for i = 1, 6 do
        dice[i] = {value = 1, rolling = 0, selected = false, kept = false}
    end
end

local function layout()
    local w, h = love.graphics.getDimensions()
    local scale = math.min(1, (w - 40) / (6 * DICE_W + 5 * GAP))
    local totalW = 6 * DICE_W * scale + 5 * GAP
    return (w - totalW) / 2, h / 2 - DICE_H * scale / 2, scale
end

local function collect(filter)
    local vals = {}
    for _, d in ipairs(dice) do
        if filter(d) then table.insert(vals, d.value) end
    end
    return vals
end

local function score(vals)
    local idx = {}
    for i = 1, #vals do idx[i] = i end
    return CalculateScore(vals, idx)
end

local function allDiceScore(vals)
    local total = score(vals)
    if total == 0 then return false end
    for i = 1, #vals do
        local without = {}
        for j, v in ipairs(vals) do
            if j ~= i then table.insert(without, v) end
        end
        if score(without) >= total then return false end
    end
    return true
end

local function rollFree()
    local free = {}
    for i, d in ipairs(dice) do
        if not d.kept then table.insert(free, i) end
    end
    local values = RollDice(#free)
    for n, i in ipairs(free) do
        dice[i].value = values[n]
        dice[i].rolling = ROLL_TIME + n * 0.1
        dice[i].selected = false
    end
    state = "rolling"
    message = ""
end

function love.update(dt)
    if state ~= "rolling" then return end
    local stillRolling = false
    for _, d in ipairs(dice) do
        if d.rolling > 0 then
            d.rolling = d.rolling - dt
            stillRolling = true
        end
    end
    if not stillRolling then
        local free = collect(function(d) return not d.kept end)
        if score(free) == 0 then
            state, roundScore = "farkled", 0
            message = "FARKLEEEEE !!!  Press SPACE for the next round"
        else
            state = "selecting"
            message = "Click dice to select, ENTER to confirm"
        end
    end
end

function love.draw()
    local x0, y0, scale = layout()
    love.graphics.draw(bg)
    for i, d in ipairs(dice) do
        local x, y = x0 + (i - 1) * (DICE_W * scale + GAP), y0
        local frame
        if d.rolling > 0 then
            frame = math.floor(love.timer.getTime() * 15 + i * 2) % #anim.quads + 1
        else
            frame = faceFrame[d.value]
        end
        if d.selected then y = y - 30 end
        if d.kept then love.graphics.setColor(0.5, 0.5, 0.5)
        elseif d.selected then love.graphics.setColor(1, 1, 0.4)
        else love.graphics.setColor(1, 1, 1) end
        love.graphics.draw(anim.spriteSheet, anim.quads[frame], x, y, 0, scale)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Round: " .. roundScore .. "   Bank: " .. bank, 20, 20)
    love.graphics.print(message, 20, 60)
end

function love.mousepressed(mx, my, button)
    if state ~= "selecting" or button ~= 1 then return end
    local x0, y0, scale = layout()
    for i, d in ipairs(dice) do
        local x = x0 + (i - 1) * (DICE_W * scale + GAP)
        if not d.kept and mx >= x and mx <= x + DICE_W * scale
                and my >= y0 - 30 and my <= y0 + DICE_H * scale then
            d.selected = not d.selected
        end
    end
end

function love.keypressed(key)
    if key == "space" and (state == "ready" or state == "farkled") then
        for _, d in ipairs(dice) do d.kept, d.selected = false, false end
        roundScore = 0
        rollFree()

    elseif key == "return" and state == "selecting" then
        local vals = collect(function(d) return d.selected end)
        local s = score(vals)
        if #vals == 0 or not allDiceScore(vals) then
            message = "Invalid selection: every selected die must score"
            return
        end
        roundScore = roundScore + s
        local allKept = true
        for _, d in ipairs(dice) do
            if d.selected then d.kept, d.selected = true, false end
            if not d.kept then allKept = false end
        end
        message = "+" .. s .. "  |  R = re-roll, B = bank"
        if allKept then
            for _, d in ipairs(dice) do d.kept = false end
            message = "HOT DICE! 6 fresh dice  |  R = re-roll, B = bank"
        end
        state = "decide"

    elseif key == "r" and state == "decide" then
        rollFree()

    elseif key == "b" and state == "decide" then
        bank = bank + roundScore
        roundScore = 0
        if bank >= 10000 then
            state, message = "won", "YOU WON !!!! GGEZ"
        else
            state, message = "ready", "Banked! Press SPACE to roll"
        end
    end
end