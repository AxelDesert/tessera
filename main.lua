-- main.lua
-- Core logic modules
local Farkle       = require("core.farkle")
local Combos       = require("core.combos")
local Scoring      = require("core.scoring")
local Player       = require("core.player")
local FloorManager = require("core.floor_manager")
local Shop         = require("core.shop")
local Settings     = require("core.settings")
local DiceTypes    = require("core.dice_types")

-- UI modules
local Theme      = require("ui.theme")
local Screen     = require("ui.screen")
local Background = require("ui.background")
local Button     = require("ui.button")
local HUD        = require("ui.hud")
local ScorePanel = require("ui.score_panel")
local JokerBar   = require("ui.joker_bar")
local JokerIcons = require("ui.joker_icons")
local ComboHelp  = require("ui.combo_help")
local ConsumableBar = require("ui.consumable_bar")
local ShopScreen = require("ui.shop_screen")
local CashoutScreen = require("ui.cashout_screen")
local DiceBoard  = require("ui.dice_board")
local FarkleAnim   = require("ui.animation")
local Menu         = require("ui.menu")
local Fx           = require("ui.fx")
local Celebration  = require("ui.celebration")

local ROLL_TIME = 0.8
local START_MONEY = 4   -- like Balatro
local SIDEBAR_W = Screen.SIDEBAR_W
local AREA_X, AREA_W = SIDEBAR_W + 20, Screen.W - SIDEBAR_W - 40   -- play area right of the sidebar

local dice, source
local state = "ready" -- ready | rolling | selecting | scoring | snapping | decide | banking | celebrating
                      -- | farkled | cashout | shop | won | lost
local roundScore, message = 0, "Press SPACE to roll"
local pendingScore = 0
local scoreIndex = 0        -- scores made this round, for jokers
local snapTimer = 0

-- numbers shown in the sidebar count up/down to the real values (see HUD.counters)
local scoreC, roundC, moneyC = Fx.counter(0), Fx.counter(0), Fx.counter(START_MONEY)
HUD.counters = { score = scoreC, round = roundC, money = moneyC }
local bank = nil            -- { result, points, hold } while the banked points count into the floor score
local afterCelebration = nil

local player, fm, shop, shopScreen, cashoutScreen
local scorePanel

local function resetDice()
    for _, d in ipairs(dice) do
        d.value, d.rolling, d.selected, d.kept = 1, 0, false, false
        d.dying = false
        d.rescued = false
        d.x = nil
    end
end

local function newGame()
    player = Player.new({ money = START_MONEY })
    ComboHelp.levels = player.levels
    ConsumableBar.clear()
    fm = FloorManager.new(player)
    fm:start_next_floor()
    resetDice()
    scorePanel:reset()
    roundScore, scoreIndex = 0, 0
    JokerBar.clear()
    state = "ready"
    message = "Press SPACE to roll"
    scoreC:snap(0); roundC:snap(0); moneyC:snap(player.money)
    bank, afterCelebration, Celebration.active = nil, nil, false
end

-- Effects for each step of the score animation (see ScorePanel.onStep)
local function onScoreStep(step, index)
    local R = scorePanel.rects or { chips = { x = 240, y = 700 }, mult = { x = 240, y = 700 }, total = { x = 240, y = 760 } }
    local pitch = 1 + 0.07 * (index - 1)          -- every step sounds a bit higher

    if step == nil then
        -- final total: the big moment
        local total = pendingScore
        local punch = math.min(0.75, 0.3 + math.log10(total + 1) * 0.08)
        Fx.burst(R.total.x, R.total.y, Theme.colors.gold, 40, 560)
        Fx.ring(R.total.x, R.total.y, Theme.colors.gold, 220)
        local cx, cy = DiceBoard.popSelected(dice, Theme.colors.gold, 24)
        Fx.text(cx, cy - 170, "+" .. Scoring.formatNumber(total), Theme.colors.gold, true)
        Fx.shake(punch)
        Fx.play("score", pitch)
    elseif step.kind == "die" then
        if step.money then player:add_money(step.money) end
        local dx, dy = DiceBoard.popDie(dice, step.die, Theme.colors.gold, 18)
        Fx.text(dx, dy - 130, step.text, Theme.colors.gold)
        Fx.burst(R.mult.x, R.mult.y, Theme.colors.mult, 10, 280)
        Fx.shake(0.14)
        Fx.play("joker", pitch)
    elseif step.kind == "joker" then
        JokerBar.trigger(step.slot)
        if step.money then player:add_money(step.money) end
        local jx, jy = JokerBar.cardCenter(player, step.slot, AREA_X, 20, AREA_W)
        Fx.burst(jx, jy, Theme.colors.gold, 26, 420)
        Fx.text(jx, jy + JokerBar.HEIGHT / 2 + 70, step.text, Theme.colors.gold, false, 15)
        Fx.burst(R.mult.x, R.mult.y, Theme.colors.mult, 12, 300)
        Fx.shake(0.22)
        Fx.play("joker", pitch)
    else
        Fx.burst(R.chips.x, R.chips.y, Theme.colors.chips, 16, 340)
        Fx.burst(R.mult.x, R.mult.y, Theme.colors.mult, 16, 340)
        local cx, cy = DiceBoard.popSelected(dice, Theme.colors.chips, 10)
        Fx.text(cx, cy - 150, step.label, Theme.colors.text)
        Fx.shake(0.16)
        Fx.play("chip", pitch)
    end
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
    JokerIcons.load()
    
    Background.load()
    DiceBoard.load()
    FarkleAnim.load()
    Fx.load()
    source = love.audio.newSource("audio/music.mp3", "stream")
    
    dice = {}
    for i = 1, 6 do
        dice[i] = {value = 1, rolling = 0, selected = false, kept = false, dying = false, x = nil}
    end
    scorePanel = ScorePanel.new()
    scorePanel.onStep = onScoreStep
    
    newGame()

    -- title screen / pause menu (see ui/menu.lua)
    Menu.load({ music = source })
    Menu.onPlay   = newGame
    Menu.onCombos = function() ComboHelp.open = true end
    Menu.overlayOpen = function() return ComboHelp.open end
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

-- Scored (or unscored) dice as the rules see them
local function diceInfo(filter)
    local list = {}
    for i, d in ipairs(dice) do
        if filter(d) then list[#list + 1] = { index = i, value = d.value, type = player.dice[i] } end
    end
    return list
end
local function isSelected(d) return d.selected end
local function isOnTable(d) return not d.kept and not d.dying and not d.selected end
local function isFree(d) return not d.kept end

-- Faces of those dice with the wild ones filled in; nil when a selection cannot be used
local function resolved(list, all)
    local values, wild = {}, {}
    for n, d in ipairs(list) do
        values[n], wild[n] = d.value, DiceTypes.get(d.type).wild
    end
    return Combos.resolve(values, wild, player.levels, all)
end

-- only = list of indexes (a charm rerolling some dice), default every free die
local function rollFree(only)
    local free = only or {}
    if not only then
        for i, d in ipairs(dice) do
            if not d.kept then table.insert(free, i) end
        end
    end

    if #free == 0 then
        for i = 1, 6 do 
            table.insert(free, i)
            dice[i].kept = false 
            dice[i].dying = false
            dice[i].x = nil
        end
    end

    local values = {}
    for i, d in ipairs(dice) do values[i] = d.value end
    Farkle.rollDice(player.dice, values, free)
    for n, i in ipairs(free) do
        dice[i].value = values[i]
        dice[i].rolling = ROLL_TIME + n * 0.1
        dice[i].selected = false
    end
    for _, d in ipairs(dice) do d.selected = false end
    scorePanel:reset()
    state = "rolling"
    message = ""
end

local function openShop()
    ConsumableBar.clear()
    shop = Shop.new(player)
    shopScreen = ShopScreen.new(shop, player, fm.lastReward)
    state, message = "shop", ""
end

local function leaveShop()
    fm:start_next_floor()
    resetDice()
    scorePanel:reset()
    roundScore = 0
    scoreC:snap(0); roundC:snap(0)
    state, message = "ready", "Press SPACE to roll"
end

-- Floor cleared: show what was earned, then (on "Cash out") pay it and open the shop
local function openCashout()
    cashoutScreen = CashoutScreen.new(fm.lastPayout, player)
    state, message = "cashout", ""
end

local function leaveCashout()
    fm:collect_payout()
    -- the money counter in the sidebar counts up while the shop opens
    local mx, my = HUD.moneyCenter(0, 0, SIDEBAR_W)
    Fx.burst(mx, my, Theme.colors.gold, 30, 420)
    Fx.ring(mx, my, Theme.colors.gold, 140)
    Fx.play("bank")
    openShop()
end

-- What happens once a round is over (after the banked points have counted in)
local function resolveRound(result, points, farkled)
    if result == "playing" then
        if farkled then
            state = "farkled"
            message = (points > 0 and ("You keep " .. points .. "!  ") or "") .. "Press SPACE for the next round"
            FarkleAnim.trigger()
        else
            state, message = "ready", "Banked " .. points .. "! Press SPACE to roll"
        end
    elseif result == "floor_cleared" then
        state, message = "celebrating", ""
        Celebration.start("FLOOR CLEARED!", ("Floor %d beaten with %d points"):format(fm.floor, fm.score))
        afterCelebration = openCashout
    elseif result == "game_won" then
        state, message = "celebrating", ""
        Settings.recordRun(player.floors_cleared, true)
        Celebration.start("YOU ESCAPED!", "The casino could not hold you")
        afterCelebration = function()
            state = "won"
            message = ("YOU ESCAPED THE CASINO! +$%d  |  Press R to play again"):format(fm.lastReward)
        end
    elseif result == "game_lost" then
        state = "lost"
        Settings.recordRun(player.floors_cleared, false)
        message = (farkled and "FARKLE! " or "") .. "Out of rounds, you lose.  Press R to restart"
    end
end

local function endRound(points, farkled)
    if farkled then
        player.stats.farkles = player.stats.farkles + 1
        local keep = math.min(1, player:perk("farkle_keep"))                        -- Safety Net
        if player.buffs.lifeline and roundScore > 0 then keep, player.buffs.lifeline = 1, nil end
        points = math.floor(roundScore * keep)
        for _, joker in ipairs(player.jokers) do
            if joker.free_farkle and not joker.used then                            -- Second Wind
                joker.used = true
                fm.rounds_left = fm.rounds_left + 1
            end
        end
        player:notify("on_farkle", player)
    elseif points > 0 then
        player:notify("on_bank", player)
    end
    player:notify("on_round", player)

    local result = fm:submit_round(points)
    roundScore = 0
    scorePanel:reset()

    if farkled or points <= 0 then
        resolveRound(result, points, farkled)
    else
        -- the round score drains into the floor score, then the round resolves
        state, message = "banking", ""
        bank = { result = result, points = points, hold = 0.35, landed = false }
        local sx, sy = HUD.scoreCenter(0, 0, SIDEBAR_W)
        Fx.ring(sx, sy, Theme.colors.gold, 160)
        Fx.play("bank")
    end
end

local function refreshPreview()
    local picked = diceInfo(isSelected)
    local vals = resolved(picked, true)
    if #picked == 0 then
        scorePanel:reset()
    elseif vals and Combos.isValidSelection(vals) then
        scorePanel:preview(Scoring.compute(vals, {}, {
            levels = player.levels, dice = picked, table = diceInfo(isOnTable), buffs = player.buffs }))
    else
        scorePanel:preview(nil, "Not a scoring combination")
    end
end

-- Game state that jokers can look at (see core/jokers.lua)
local function jokerContext()
    local special, kinds = player:special_dice()
    return {
        levels = player.levels, buffs = player.buffs,
        dice = diceInfo(isSelected), table = diceInfo(isOnTable),
        owned_special = special, owned_kinds = kinds,
        upgrades = player:total_upgrades(), cards = #player.consumables,
        combo_level = function(id) return player:combo_level(id) end,
        money = player.money, rounds_left = fm.rounds_left,
        round_index = fm.rounds_total - fm.rounds_left + 1,
        floor = fm.floor, boss = fm:is_boss(fm.floor), joker_count = #player.jokers,
        max_jokers = player.max_jokers, stats = player.stats,
        score_index = scoreIndex, round_score = roundScore,
        floor_score = fm.score, target = fm.target,
        dice_left = #collect(function(d) return not d.kept and not d.selected end),
    }
end

local function confirmSelection()
    local vals = resolved(diceInfo(isSelected), true)
    if not vals or not Combos.isValidSelection(vals) then
        message = "Invalid selection: every selected die must be part of a combination"
        return
    end
    scoreIndex = scoreIndex + 1
    local result = Scoring.compute(vals, player.jokers, jokerContext())
    player.buffs.chips, player.buffs.xmult = nil, nil      -- one-use charms are spent
    for _, e in ipairs(result.entries) do player.plays[e.id] = (player.plays[e.id] or 0) + 1 end
    player:notify("after", result.ctx)          -- growing jokers
    ConsumableBar.clear()
    pendingScore = result.total
    state, message = "scoring", ""
    scorePanel:start(result)
end

-- Selling is off while jokers are being counted or the run is over
local LOCKED = { scoring = true, snapping = true, banking = true, celebrating = true, won = true, lost = true }
local CARDS_OK = { ready = true, selecting = true, decide = true, farkled = true, shop = true }

local function sellJoker(slot)
    local y = JokerBar.lastY or 20
    local jx, jy = JokerBar.cardCenter(player, slot, AREA_X, y, AREA_W)
    local value = player:sell_joker(slot)
    if not value then return end
    JokerBar.clear()
    Fx.burst(jx, jy, Theme.colors.gold, 34, 460)
    Fx.ring(jx, jy, Theme.colors.gold, 160)
    Fx.text(jx, jy, "+$" .. value, Theme.colors.gold, true)
    Fx.play("coin")
end

local function notice(text)
    if state == "shop" then shopScreen.notice = text else message = text end
end

-- What charms can see and change (see core/consumables.lua)
local function charmGame()
    return {
        player = player, fm = fm,
        playing = fm.state == "playing" and state ~= "shop",
        picking = state == "selecting",
        selected = diceInfo(isSelected),
        set_faces = function(map)
            local old = {}
            for i, v in pairs(map) do old[i], dice[i].value = dice[i].value, v end
            if Combos.canScore(resolved(diceInfo(isFree))) then
                for i in pairs(map) do DiceBoard.popDie(dice, i, Theme.colors.gold, 20) end
                return true
            end
            for i, v in pairs(old) do dice[i].value = v end
            return false
        end,
        reroll = function(list)
            local only = {}
            for n, d in ipairs(list) do only[n] = d.index end
            rollFree(only)
        end,
    }
end

local function useCard(slot, track)
    if not CARDS_OK[state] then return end
    local cx, cy = ConsumableBar.center(slot)
    local ok, text = player:use_consumable(slot, charmGame(), track)
    if not ok then
        notice(text or "")
        Fx.play("unpick")
        return
    end
    ConsumableBar.clear()
    Fx.burst(cx, cy, Theme.colors.gold, 34, 460)
    Fx.ring(cx, cy, Theme.colors.gold, 160)
    if text then Fx.text(cx, cy - 60, text, Theme.colors.gold, false) end
    Fx.play("joker")
    if state == "selecting" then refreshPreview() end
end

local function sellCard(slot)
    local cx, cy = ConsumableBar.center(slot)
    local value = player:sell_consumable(slot)
    if not value then return end
    ConsumableBar.clear()
    Fx.burst(cx, cy, Theme.colors.gold, 24, 400)
    Fx.text(cx, cy, "+$" .. value, Theme.colors.gold, true)
    Fx.play("coin")
end

local function cardAction(action, slot, track)
    if action == "use" then useCard(slot, track) elseif action == "sell" then sellCard(slot) end
end

local function finishScoring()
    roundScore = roundScore + pendingScore

    -- crystal dice may crack
    for i, d in ipairs(dice) do
        local chance = d.selected and DiceTypes.get(player.dice[i]).fragile
        if chance and player:perk("no_crack") == 0 and math.random() < chance then
            player.dice[i] = "plain"
            local cx, cy = DiceBoard.popDie(dice, i, { 0.7, 1, 1 }, 40)
            Fx.text(cx, cy - 120, "CRACKED!", { 0.7, 1, 1 }, false)
        end
    end
    
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

    Fx.update(dt)
    JokerBar.locked = LOCKED[state] or false
    ConsumableBar.locked = not CARDS_OK[state]
    for i, d in ipairs(dice) do d.type = player.dice[i] end
    JokerBar.update(dt)
    DiceBoard.update(dt, dice, state == "selecting")
    FarkleAnim.update(dt)

    -- sidebar counters
    scoreC:set(fm.score); roundC:set(roundScore); moneyC:set(player.money)
    if scoreC:update(dt) then
        local sx, sy = HUD.scoreCenter(0, 0, SIDEBAR_W)
        local p = scoreC.value / math.max(1, fm.target)
        Fx.sparkle(sx + (math.random() - 0.5) * 160, sy, Theme.colors.chips)
        Fx.play("tick", 1 + math.min(1, p) * 0.8)
    end
    roundC:update(dt)
    if moneyC:update(dt) then
        local mx, my = HUD.moneyCenter(0, 0, SIDEBAR_W)
        Fx.sparkle(mx + (math.random() - 0.5) * 120, my, Theme.colors.gold)
        Fx.play("tick", 1.6)
    end

    if state == "banking" then
        if not scoreC:busy() and not roundC:busy() then
            if not bank.landed then
                bank.landed = true
                local sx, sy = HUD.scoreCenter(0, 0, SIDEBAR_W)
                Fx.burst(sx, sy, Theme.colors.gold, 24, 380)
                Fx.shake(0.25)
            end
            bank.hold = bank.hold - dt
            if bank.hold <= 0 then
                local b = bank
                bank = nil
                resolveRound(b.result, b.points, false)
            end
        end
        return
    end

    if state == "celebrating" then
        if Celebration.update(dt) then
            local nextStep = afterCelebration
            afterCelebration = nil
            if nextStep then nextStep() end
        end
        return
    end

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

    if state ~= "rolling" then return end
    local stillRolling = false
    for _, d in ipairs(dice) do
        if d.rolling > 0 then
            d.rolling = d.rolling - dt
            stillRolling = true
        end
    end
    if not stillRolling then
        local free = resolved(diceInfo(isFree))
        if not Combos.canScore(free) then
            for i, d in ipairs(dice) do            -- a Phoenix die on the table saves one Farkle per floor
                if not d.kept and not d.rescued and DiceTypes.get(player.dice[i]).rescue then
                    d.rescued = true
                    local cx, cy = DiceBoard.popDie(dice, i, Theme.colors.mult, 50)
                    Fx.text(cx, cy - 140, "PHOENIX!", Theme.colors.gold, true)
                    Fx.shake(0.4)
                    Fx.play("score")
                    rollFree()
                    return
                end
            end
            endRound(0, true)
        else
            state = "selecting"
            message = "Click dice (or A/D + W/S) to select, ENTER to confirm"
        end
    end
end

function love.draw()
    Screen.begin()
    if Menu.visible and Menu.mode == "main" then
        Menu.draw()
        ComboHelp.draw()     -- opened from "How to play" > "Combos"; must sit above the menu
        Screen.finish()
        return
    end

    local w, h = Screen.W, Screen.H
    local areaX, areaW = AREA_X, AREA_W

    Background.draw()

    -- everything on the table shakes together (Options > Screen shake)
    love.graphics.push()
    love.graphics.translate(Fx.offset())

    HUD.draw(fm, player, roundScore, 0, 0, SIDEBAR_W)
    scorePanel:draw(HUD.scoreRect(0, 0, SIDEBAR_W))

    if state == "shop" then
        shopScreen:draw(areaX, 20, areaW)
    elseif state == "cashout" then
        cashoutScreen:draw(areaX, 20, areaW)
    else
        JokerBar.draw(player, areaX, 20, areaW)
        DiceBoard.draw(dice, state == "selecting")
        ConsumableBar.draw(player, areaX, 806, areaW)

        love.graphics.setFont(Theme.fonts.normal)
        Theme.color("text")
        Theme.printf(message, areaX, h - 90, areaW, "center")
    end

    if state ~= "cashout" and state ~= "celebrating" then
        if state ~= "shop" then DiceBoard.drawTooltip(dice, state == "selecting") end
        JokerBar.drawOverlay(player)
        ConsumableBar.drawOverlay(player)
        if state == "shop" then shopScreen:drawOverlay() end
    end
    Celebration.draw()

    love.graphics.setFont(Theme.fonts.small)
    Theme.color("dim", 0.6)
    Theme.printf("ESC: menu", w - 260, h - 50, 240, "right")

    Fx.draw()
    love.graphics.pop()

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
    if state == "celebrating" then Celebration.skip() return end

    if state == "cashout" then
        if cashoutScreen:mousepressed(mx, my) == "next" then leaveCashout() end
        return
    end

    if state == "shop" and shopScreen:overlayPressed(mx, my) then return end

    local what, cardSlot, track = ConsumableBar.mousepressed(player, mx, my)
    cardAction(what, cardSlot, track)
    if what then return end

    local action, slot = JokerBar.mousepressed(player, mx, my)
    if action == "sell" then sellJoker(slot) end
    if action then return end

    if state == "shop" then
        if shopScreen:mousepressed(mx, my) == "next" then leaveShop() end
        return
    end

    if state == "selecting" then
        if DiceBoard.mousepressed(mx, my, dice) then
            refreshPreview()
            return              -- keep the picked card: some charms need dice
        end
    end
    ConsumableBar.clear()
end

function love.keypressed(key)
    if key == "f11" then Settings.toggleFullscreen() return end
    if ComboHelp.open then
        if key == "escape" or key == "h" then ComboHelp.open = false end
        return
    end
    if Menu.visible then Menu.keypressed(key) return end
    if state == "shop" and shopScreen:keypressed(key) then return end
    if key == "escape" then Menu.open("pause") return end
    if key == "h" then ComboHelp.toggle() return end

    if state == "celebrating" then
        if key == "space" or key == "return" then Celebration.skip() end
        return
    end
    if state ~= "cashout" then
        local what, slot, track = ConsumableBar.keypressed(player, key)
        cardAction(what, slot, track)
        if what then return end
    end
    if state == "selecting" and DiceBoard.keypressed(key, dice) then
        refreshPreview()
        return
    end

    if (key == "space" or key == "return") and state == "cashout" then
        if cashoutScreen:advance() == "next" then leaveCashout() end
    elseif key == "space" and state == "shop" then
        leaveShop()
    elseif key == "space" and (state == "ready" or state == "farkled") then
        for _, d in ipairs(dice) do d.kept, d.selected = false, false end
        roundScore, scoreIndex = 0, 0
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
