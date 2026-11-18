-- main.lua
-- Core logic modules
local Farkle       = require("core.farkle")
local Combos       = require("core.combos")
local Scoring      = require("core.scoring")
local Player       = require("core.player")
local FloorManager = require("core.floor_manager")
local Shop         = require("core.shop")
local Settings     = require("core.settings")

-- UI modules
local Theme      = require("ui.theme")
local Screen     = require("ui.screen")
local Button     = require("ui.button")
local HUD        = require("ui.hud")
local ScorePanel = require("ui.score_panel")
local JokerBar   = require("ui.joker_bar")
local ComboHelp  = require("ui.combo_help")
local ShopScreen = require("ui.shop_screen")
local CashoutScreen = require("ui.cashout_screen")
local DiceBoard  = require("ui.dice_board")
local FarkleAnim   = require("ui.animation")
local Menu         = require("ui.menu")

local ROLL_TIME = 0.8
local START_MONEY = 4   -- like Balatro
local SIDEBAR_W = Screen.SIDEBAR_W

local dice, bg, source
local state = "ready" -- ready | rolling | selecting | scoring | snapping | decide | farkled | cashout | shop | won | lost
local roundScore, message = 0, "Press SPACE to roll"
local pendingScore = 0
local snapTimer = 0

local player, fm, shop, shopScreen, cashoutScreen
local scorePanel

local function resetDice()
    for _, d in ipairs(dice) do
        d.value, d.rolling, d.selected, d.kept = 1, 0, false, false
        d.dying = false
        d.x = nil
    end
end

local function newGame()
    player = Player.new({ money = START_MONEY })
    fm = FloorManager.new(player)
    fm:start_next_floor()
    resetDice()
    scorePanel:reset()
    roundScore = 0
    state = "ready"
    message = "Press SPACE to roll"
end

function love.load()
    -- game is laid out for 1920x1080 and scaled into the window (F11 = fullscreen)
    local dw, dh = love.window.getDesktopDimensions()
    local k = math.min(1, dw * 0.95 / Screen.W, dh * 0.90 / Screen.H)
    love.window.setMode(math.floor(Screen.W * k), math.floor(Screen.H * k),
        {resizable = true, vsync = 0, minwidth = 960, minheight = 540})
    Settings.load()
    Settings.applyWindow()
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

    -- title screen / pause menu (see ui/menu.lua)
    Menu.load({ bg = bg, music = source })
    Menu.onPlay   = newGame
    Menu.onCombos = function() ComboHelp.open = true end
    Menu.runInfo  = function()
        return ("FLOOR %d / %d   |   $%d"):format(fm.floor, fm.cfg.total_floors, player.money)
    end
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

-- Floor cleared: show what was earned, then (on "Cash out") pay it and open the shop
local function openCashout()
    cashoutScreen = CashoutScreen.new(fm.lastPayout, player)
    state, message = "cashout", ""
end

local function leaveCashout()
    fm:collect_payout()
    openShop()
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
        openCashout()
    elseif result == "game_won" then
        state = "won"
        Settings.recordRun(player.floors_cleared, true)
        message = ("YOU ESCAPED THE CASINO! +$%d  |  Press R to play again"):format(fm.lastReward)
    elseif result == "game_lost" then
        state = "lost"
        Settings.recordRun(player.floors_cleared, false)
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

-- Game state that jokers can look at (see core/jokers.lua)
local function jokerContext()
    return {
        money = player.money, rounds_left = fm.rounds_left,
        round_index = fm:get_rounds(fm.floor) - fm.rounds_left + 1,
        floor = fm.floor, boss = fm:is_boss(fm.floor), joker_count = #player.jokers,
    }
end

local function confirmSelection()
    local vals = collect(function(d) return d.selected end)
    if not Combos.isValidSelection(vals) then
        message = "Invalid selection: every selected die must be part of a combination"
        return
    end
    local result = Scoring.compute(vals, player.jokers, jokerContext())
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
    Menu.update(dt)
    if not source:isPlaying( ) then
        love.audio.play( source )
    end
    if Menu.visible then return end   -- title screen / pause: the game is frozen

    if state == "cashout" then cashoutScreen:update(dt) end
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
    Screen.begin()
    if Menu.visible and Menu.mode == "main" then
        Menu.draw()
        Screen.finish()
        return
    end

    local w, h = Screen.W, Screen.H
    local areaX, areaW = SIDEBAR_W + 20, w - SIDEBAR_W - 40

    love.graphics.setColor(1, 1, 1)
    local bw, bh = bg:getDimensions()
    local cover = math.max((Screen.right - Screen.left) / bw, (Screen.bottom - Screen.top) / bh)
    love.graphics.draw(bg, w / 2, h / 2, 0, cover, cover, bw / 2, bh / 2)

    HUD.draw(fm, player, roundScore, 0, 0, SIDEBAR_W)
    scorePanel:draw(HUD.scoreRect(0, 0, SIDEBAR_W))

    if state == "shop" then
        shopScreen:draw(areaX, 20, areaW)
    elseif state == "cashout" then
        cashoutScreen:draw(areaX, 20, areaW)
    else
        JokerBar.draw(player, areaX, 20, areaW)
        DiceBoard.draw(dice)

        love.graphics.setFont(Theme.fonts.normal)
        Theme.color("text")
        Theme.printf(message, areaX, h - 90, areaW, "center")
    end

    love.graphics.setFont(Theme.fonts.small)
    Theme.color("dim", 0.6)
    Theme.printf("ESC: menu", w - 260, h - 50, 240, "right")

    FarkleAnim.draw()
    Menu.draw()          -- pause overlay + screen fades
    ComboHelp.draw()
    Screen.finish()
end

function love.mousepressed(mx, my, button)
    if button ~= 1 then return end
    mx, my = Screen.toGame(mx, my)

    if ComboHelp.open then ComboHelp.open = false return end
    if Menu.mousepressed(mx, my, button) then return end
    if HUD.comboButton:hit(mx, my) then ComboHelp.toggle() return end
    if HUD.newRunButton:hit(mx, my) then newGame() return end

    if state == "cashout" then
        if cashoutScreen:mousepressed(mx, my) == "next" then leaveCashout() end
        return
    end

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
    if key == "f11" then Settings.toggleFullscreen() return end
    if ComboHelp.open then
        if key == "escape" or key == "h" then ComboHelp.open = false end
        return
    end
    if Menu.visible then Menu.keypressed(key) return end
    if key == "escape" then Menu.open("pause") return end
    if key == "h" then ComboHelp.toggle() return end

    if (key == "space" or key == "return") and state == "cashout" then
        if cashoutScreen:advance() == "next" then leaveCashout() end
    elseif key == "space" and state == "shop" then
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

-- alt-tab during a run opens the pause menu
function love.focus(focused)
    if not focused and not Menu.visible then Menu.open("pause") end
end

function love.quit()
    Settings.save()
end
