-- main.lua
-- Core logic modules
local Farkle       = require("core.farkle")
local Combos       = require("core.combos")
local Scoring      = require("core.scoring")
local Player       = require("core.player")
local FloorManager = require("core.floor_manager")
local Shop         = require("core.shop")

-- UI modules
local Theme      = require("ui.theme")
local Button     = require("ui.button")
local HUD        = require("ui.hud")
local ScorePanel = require("ui.score_panel")
local JokerBar   = require("ui.joker_bar")
local ComboHelp  = require("ui.combo_help")
local ShopScreen = require("ui.shop_screen")
local DiceBoard  = require("ui.dice_board")
local FarkleAnim   = require("ui.animation")

local ROLL_TIME = 0.8
local SIDEBAR_W = 300

local dice, bg
local state = "ready" -- ready | rolling | selecting | scoring | snapping | decide | farkled | shop | won | lost
local roundScore, message = 0, "Press SPACE to roll"
local pendingScore = 0
local snapTimer = 0

local player, fm, shop, shopScreen
local scorePanel
local helpButton = Button.new("Combos  [H]", "button_orange")

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
    
    bg = love.graphics.newImage("assets/wallpaper.png")
    DiceBoard.load()
    FarkleAnim.load()
    source = love.audio.newSource("audio/music.mp3", "stream")
    
    dice = {}
    for i = 1, 6 do
        dice[i] = {value = 1, rolling = 0, selected = false, kept = false, dying = false, x = nil}
    end
    scorePanel = ScorePanel.new()
    
    newGame()
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
            state, message = "farkled", "Press SPACE for the next round"
            FarkleAnim.trigger()
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

local function refreshPreview()
    local vals = collect(function(d) return d.selected end)
    if #vals == 0 then
        scorePanel:reset()
    elseif Combos.isValidSelection(vals) then
        scorePanel:preview(Scoring.compute(vals, {}))
    else
        scorePanel:preview(nil, "Not a scoring combination")
    end
end

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

local function finishScoring()
    roundScore = roundScore + pendingScore
    
    DiceBoard.snapDice(dice) -- Triggers the dust!
    
    snapTimer = 0.5 
    state = "snapping"
    message = ""
end

function love.update(dt)
    if not source:isPlaying( ) then
        love.audio.play( source )
    end
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
    DiceBoard.update(dt, dice)
    FarkleAnim.update(dt)

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

function love.draw()
    local w, h = love.graphics.getDimensions()
    local areaX, areaW = SIDEBAR_W + 20, w - SIDEBAR_W - 40

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bg, 0, 0, 0, w / bg:getWidth(), h / bg:getHeight())

    HUD.draw(fm, player, roundScore, 20, 20, SIDEBAR_W - 20)
    scorePanel:draw(20, 20 + HUD.HEIGHT + 20, SIDEBAR_W - 20)
    helpButton:setRect(20, h - 64, SIDEBAR_W - 20, 44)
    helpButton:draw()

    if state == "shop" then
        shopScreen:draw(areaX, 20, areaW)
    else
        JokerBar.draw(player, areaX, 20, areaW)
        DiceBoard.draw(dice)
        
        love.graphics.setFont(Theme.fonts.normal)
        Theme.color("text")
        Theme.printf(message, areaX, h - 70, areaW, "center")
    end

    ComboHelp.draw()
    FarkleAnim.draw()
end

function love.mousepressed(mx, my, button)
    if button ~= 1 then return end

    if ComboHelp.open then ComboHelp.open = false return end
    if helpButton:hit(mx, my) then ComboHelp.toggle() return end

    if state == "shop" then
        if shopScreen:mousepressed(mx, my) == "next" then leaveShop() end
        return
    end

    if state == "selecting" then
        if DiceBoard.mousepressed(mx, my, dice) then
            refreshPreview()
        end
    end
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