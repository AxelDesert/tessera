local newAnimation = require("animation")
local Farkle       = require("farkle")
local Combos       = require("combos")
local Scoring      = require("scoring")
local Player       = require("player")
local FloorManager = require("floor_manager")
local Shop         = require("shop")

local Theme      = require("ui.theme")
local Button     = require("ui.button")
local HUD        = require("ui.hud")
local ScorePanel = require("ui.score_panel")
local JokerBar   = require("ui.joker_bar")
local ComboHelp  = require("ui.combo_help")
local ShopScreen = require("ui.shop_screen")

local DICE_W, DICE_H = 206, 202
local GAP = 20
local ROLL_TIME = 0.8
local SIDEBAR_W = 300
local faceFrame = {1, 2, 3, 4, 5, 6}

local anim, dice, bg
-- ready | rolling | selecting | scoring | decide | farkled | shop | won | lost
local state = "ready"
local roundScore, message = 0, "Press SPACE to roll"
local pendingScore = 0
local snapTimer = 0 -- NEW: Timer for the dust delay

local player, fm, shop, shopScreen
local scorePanel
local helpButton = Button.new("Combos  [H]")

local function resetDice()
    for _, d in ipairs(dice) do
        d.value, d.rolling, d.selected, d.kept = 1, 0, false, false
        d.dying = false
        d.x = nil
    end
end

local function newGame()
    player = Player.new({ money = 0 })
    fm = FloorManager.new(player)
    fm:start_next_floor()
    resetDice()
    scorePanel:reset()
    roundScore = 0
    state = "ready"
    message = "Press SPACE to roll"
end

function love.load()
    love.window.setMode(1280, 720, {resizable=true, vsync=0, minwidth=1100, minheight=640})
    Theme.load()
    bg = love.graphics.newImage("wallpaper.jpg")
    anim = newAnimation(love.graphics.newImage("dice.png"), DICE_W, DICE_H, 5)
    dice = {}
    for i = 1, 6 do
        dice[i] = {value = 1, rolling = 0, selected = false, kept = false}
    end
    scorePanel = ScorePanel.new()

    local pixel = love.image.newImageData(2, 2)
    pixel:mapPixel(function() return 1, 1, 1, 1 end)
    
    dustPS = love.graphics.newParticleSystem(love.graphics.newImage(pixel), 2000)
    dustPS:setParticleLifetime(1, 2.5)
    dustPS:setEmissionArea("uniform", DICE_W / 3, DICE_H / 3, 0, true)
    dustPS:setColors(
        0.4, 0.4, 0.4, 1,
        0.2, 0.2, 0.2, 0.8,
        0.1, 0.1, 0.1, 0
    )
    dustPS:setSizes(2.5, 1.5, 5.5)
    dustPS:setLinearAcceleration(20, -30, 80, -120)
    dustPS:setSpin(-5, 5)

    newGame()
end

-- Dice row: centered in the area to the right of the sidebar
local function layout(visibleCount)
    visibleCount = visibleCount or 6
    local w, h = love.graphics.getDimensions()
    local areaX, areaW = SIDEBAR_W + 20, w - SIDEBAR_W - 40
    
    -- We still calculate scale based on 6 dice so they don't suddenly turn giant
    local scale = math.min(1, (areaW - 5 * GAP) / (6 * DICE_W))
    
    -- But we calculate the total width based ONLY on the remaining dice to close the gaps
    local totalW = visibleCount * DICE_W * scale + math.max(0, visibleCount - 1) * GAP
    return areaX + (areaW - totalW) / 2, h / 2 - DICE_H * scale / 2 + 30, scale
end

local function collect(filter)
    local vals = {}
    for _, d in ipairs(dice) do
        if filter(d) then table.insert(vals, d.value) end
    end
    return vals
end

local function rollFree()
    local free = {}
    for i, d in ipairs(dice) do
        if not d.kept then table.insert(free, i) end
    end
    
    if #free == 0 then
        for i = 1, 6 do 
            table.insert(free, i)
            dice[i].kept = false 
            dice[i].dying = false
            dice[i].x = nil
        end
    end

    local values = Farkle.rollDice(#free)
    for n, i in ipairs(free) do
        dice[i].value = values[n]
        dice[i].rolling = ROLL_TIME + n * 0.1
        dice[i].selected = false
    end
    scorePanel:reset()
    state = "rolling"
    message = ""
end

local function openShop()
    shop = Shop.new(player)
    shopScreen = ShopScreen.new(shop, player, fm.lastReward)
    state, message = "shop", ""
end

local function leaveShop()
    fm:start_next_floor()
    resetDice()
    scorePanel:reset()
    roundScore = 0
    state, message = "ready", "Press SPACE to roll"
end

local function endRound(points, farkled)
    local result = fm:submit_round(points)
    roundScore = 0
    scorePanel:reset()

    if result == "playing" then
        if farkled then
            state, message = "farkled", "FARKLEEEEE !!!  Press SPACE for the next round"
        else
            state, message = "ready", "Banked " .. points .. "! Press SPACE to roll"
        end
    elseif result == "floor_cleared" then
        openShop()
    elseif result == "game_won" then
        state = "won"
        message = ("YOU ESCAPED THE CASINO! +$%d  |  Press R to play again"):format(fm.lastReward)
    elseif result == "game_lost" then
        state = "lost"
        message = (farkled and "FARKLE! " or "") .. "Out of rounds, you lose.  Press R to restart"
    end
end

-- Live preview in the score panel while the player picks dice
local function refreshPreview()
    local vals = collect(function(d) return d.selected end)
    if #vals == 0 then
        scorePanel:reset()
    elseif Combos.isValidSelection(vals) then
        scorePanel:preview(Scoring.compute(vals, {}))   -- base combos, jokers not included
    else
        scorePanel:preview(nil, "Not a scoring combination")
    end
end

-- ENTER: validate the selection and start the score animation
local function confirmSelection()
    local vals = collect(function(d) return d.selected end)
    if not Combos.isValidSelection(vals) then
        message = "Invalid selection: every selected die must be part of a combination"
        return
    end
    local result = Scoring.compute(vals, player.jokers)
    pendingScore = result.total
    state, message = "scoring", ""
    scorePanel:start(result)
end

-- Called when the score animation has finished
local function finishScoring()
    roundScore = roundScore + pendingScore
    
    local visibleCount = 0
    for _, d in ipairs(dice) do
        if not d.kept then visibleCount = visibleCount + 1 end
    end
    
    local x0, y0, scale = layout(visibleCount)
    local drawIndex = 0
    
    for i, d in ipairs(dice) do
        if not d.kept then
            if d.selected then 
                -- Spawn dust at their current screen coordinates
                local cx = x0 + drawIndex * (DICE_W * scale + GAP) + (DICE_W * scale) / 2
                local cy = y0 - 30 + (DICE_H * scale) / 2
                dustPS:setPosition(cx, cy)
                dustPS:emit(200)
                
                d.dying = true -- Mark as dying to hide them, but maintain the gap
                d.selected = false 
            end
            drawIndex = drawIndex + 1
        end
    end
    
    snapTimer = 0.5 -- Wait 0.5 seconds before sliding the remaining dice
    state = "snapping"
    message = ""
end

function love.update(dt)
    if dustPS then dustPS:update(dt) end
    
    if state == "scoring" then
        if scorePanel:update(dt) then finishScoring() end
        return
    end
    
    if state == "snapping" then
        snapTimer = snapTimer - dt
        if snapTimer <= 0 then
            local allKept = true
            for _, d in ipairs(dice) do
                if d.dying then
                    d.kept = true
                    d.dying = false
                end
                if not d.kept then allKept = false end
            end
            
            message = "+" .. pendingScore .. "  |  R = re-roll, B = bank"
            if allKept then message = "HOT DICE! 6 fresh dice  |  R = re-roll, B = bank" end
            state = "decide"
        end
    end

    scorePanel:update(dt)
    
    local visibleCount = 0
    for _, d in ipairs(dice) do
        if not d.kept then visibleCount = visibleCount + 1 end
    end
    
    local x0, y0, scale = layout(visibleCount)
    local drawIndex = 0
    
    for i, d in ipairs(dice) do
        if not d.kept then
            local targetX = x0 + drawIndex * (DICE_W * scale + GAP)
            if not d.x then d.x = targetX end -- Instantly position if it has no X yet
            
            d.x = d.x + (targetX - d.x) * 15 * dt
            drawIndex = drawIndex + 1
        end
    end

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
        if not Combos.canScore(free) then
            endRound(0, true)
        else
            state = "selecting"
            message = "Click dice to select, ENTER to confirm"
        end
    end
end

local function drawDice()
    local visibleCount = 0
    for _, d in ipairs(dice) do
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
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    local areaX, areaW = SIDEBAR_W + 20, w - SIDEBAR_W - 40

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bg, 0, 0, 0, w / bg:getWidth(), h / bg:getHeight())

    -- left sidebar
    HUD.draw(fm, player, roundScore, 20, 20, SIDEBAR_W - 20)
    scorePanel:draw(20, 20 + HUD.HEIGHT + 20, SIDEBAR_W - 20)
    helpButton:setRect(20, h - 64, SIDEBAR_W - 20, 44)
    helpButton:draw()

    -- main area
    if state == "shop" then
        shopScreen:draw(areaX, 20, areaW)
    else
        JokerBar.draw(player, areaX, 20, areaW)
        drawDice()
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(dustPS)

        love.graphics.setFont(Theme.fonts.normal)
        Theme.color("text")
        love.graphics.printf(message, areaX, h - 70, areaW, "center")
    end

    ComboHelp.draw()
end

function love.mousepressed(mx, my, button)
    if button ~= 1 then return end

    if ComboHelp.open then ComboHelp.open = false return end
    if helpButton:hit(mx, my) then ComboHelp.toggle() return end

    if state == "shop" then
        if shopScreen:mousepressed(mx, my) == "next" then leaveShop() end
        return
    end

    if state ~= "selecting" then return end
    
    local visibleCount = 0
    for _, d in ipairs(dice) do
        if not d.kept then visibleCount = visibleCount + 1 end
    end
    local _, y0, scale = layout(visibleCount)
    
    for i, d in ipairs(dice) do
        if not d.kept and not d.dying then
            if d.x and mx >= d.x and mx <= d.x + DICE_W * scale
                    and my >= y0 - 30 and my <= y0 + DICE_H * scale then
                d.selected = not d.selected
            end
        end
    end
    refreshPreview()
end

function love.keypressed(key)
    if key == "h" then ComboHelp.toggle() return end
    if ComboHelp.open then
        if key == "escape" then ComboHelp.open = false end
        return
    end

    if key == "space" and state == "shop" then
        leaveShop()

    elseif key == "space" and (state == "ready" or state == "farkled") then
        for _, d in ipairs(dice) do d.kept, d.selected = false, false end
        roundScore = 0
        rollFree()

    elseif key == "return" and state == "selecting" then
        confirmSelection()

    elseif key == "r" and state == "decide" then
        rollFree()

    elseif key == "b" and state == "decide" then
        endRound(roundScore, false)

    elseif key == "r" and (state == "won" or state == "lost") then
        newGame()
    end
end
