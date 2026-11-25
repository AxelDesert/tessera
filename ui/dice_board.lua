local Screen   = require("ui.screen")
local Settings = require("core.settings")
local Theme    = require("ui.theme")
local Combos   = require("core.combos")
local Fx       = require("ui.fx")
local DiceTypes  = require("core.dice_types")
local JokerIcons = require("ui.joker_icons")

local DiceBoard = {}

local DICE_W, DICE_H = 206, 202
local GAP = 20
local SIDEBAR_W = Screen.SIDEBAR_W
local faceFrame = {1, 2, 3, 4, 5, 6}
local SELECT_LIFT, HOVER_LIFT = 30, 10

local anim, dustPS
local hovered = nil      -- die currently under the mouse (for the hover tick)
local cursor = nil       -- die picked with the keyboard (A/D or arrows)
local keyboard = false   -- true after a key was used, until the mouse moves
local lastMx, lastMy = 0, 0
local maskKey, lastMask = nil, {}

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

local function visible(dice)
    local n = 0
    for _, d in ipairs(dice) do
        if not d.kept then n = n + 1 end
    end
    return n
end

-- per-die animation state, created lazily so main.lua's dice tables stay simple
local function fx(d, i)
    if not d.phase then
        d.phase = i * 1.7 + math.random()
        d.hover, d.lift, d.pop = 0, 0, 0
    end
end

-- Float offset (bob in pixels, sway in radians); zero when Options > Floaty dice is off.
-- Rolling dice hop and tumble instead.
local function float(d)
    if d.rolling and d.rolling > 0 then
        local k = math.min(1, d.rolling / 0.4)
        return -math.abs(math.sin(d.rolling * 11 + d.phase)) * 34 * k, math.sin(d.rolling * 17 + d.phase) * 0.35 * k
    end
    if not Settings.data.float then return 0, 0 end
    local t = love.timer.getTime()
    return math.sin(t * 1.7 + d.phase) * 7, math.sin(t * 1.2 + d.phase * 1.3) * 0.05
end

-- Visual center of a die, including lift and float
local function center(d, y0, scale)
    local bob = float(d)
    local w, h = DICE_W * scale, DICE_H * scale
    return (d.x or 0) + w / 2, y0 + h / 2 - SELECT_LIFT * d.lift - HOVER_LIFT * d.hover + bob
end

local function hit(d, mx, my, y0, scale)
    return d.x and mx >= d.x and mx <= d.x + DICE_W * scale
        and my >= y0 - SELECT_LIFT and my <= y0 + DICE_H * scale
end

function DiceBoard.snapDice(dice)
    local _, y0, scale = layout(visible(dice))
    for i, d in ipairs(dice) do
        fx(d, i)
        if not d.kept and d.selected then
            local cx, cy = center(d, y0, scale)
            dustPS:setPosition(cx, cy)
            dustPS:emit(200)
            Fx.burst(cx, cy, Theme.colors.gold, 14, 380)

            d.dying = true
            d.selected = false
        end
    end
end

-- Kick every selected die (used while scoring). Returns the middle of the selection.
function DiceBoard.popSelected(dice, color, sparks)
    local _, y0, scale = layout(visible(dice))
    local sx, sy, n = 0, 0, 0
    for i, d in ipairs(dice) do
        fx(d, i)
        if not d.kept and not d.dying and d.selected then
            local cx, cy = center(d, y0, scale)
            d.pop = 1
            if sparks and sparks > 0 then Fx.burst(cx, cy, color, sparks, 320) end
            sx, sy, n = sx + cx, sy + cy, n + 1
        end
    end
    if n == 0 then return Screen.W / 2, Screen.H / 2 end
    return sx / n, sy / n
end

-- Kick one die (special die triggering). Returns its center.
function DiceBoard.popDie(dice, index, color, sparks)
    local _, y0, scale = layout(visible(dice))
    local d = dice[index]
    fx(d, index)
    local cx, cy = center(d, y0, scale)
    d.pop = 1
    Fx.burst(cx, cy, color, sparks, 360)
    return cx, cy
end

-- Select / deselect one die, with its effects
local function toggle(d, y0, scale)
    d.selected = not d.selected
    local cx, cy = center(d, y0, scale)
    if d.selected then
        d.pop = 1
        Fx.burst(cx, cy, Theme.colors.gold, 16, 360)
        Fx.ring(cx, cy, Theme.colors.gold, DICE_W * scale * 0.75)
        Fx.play("pick")
    else
        d.pop = 0.5
        Fx.play("unpick")
    end
end

-- free dice (can be picked), left to right
local function pickable(dice)
    local list = {}
    for i, d in ipairs(dice) do
        if not d.kept and not d.dying then list[#list + 1] = i end
    end
    return list
end

-- Keyboard picking: A/D or left/right move the cursor, W/up selects, S/down deselects,
-- SPACE toggles. Returns true when the selection changed.
function DiceBoard.keypressed(key, dice)
    local list = pickable(dice)
    if #list == 0 then return false end
    local pos = 1
    for n, i in ipairs(list) do if i == cursor then pos = n end end
    if not keyboard or not cursor then
        -- first key press: show the cursor where the mouse was (or on the first die)
        keyboard, cursor = true, hovered or list[1]
        for n, i in ipairs(list) do if i == cursor then pos = n end end
        if key == "a" or key == "d" or key == "left" or key == "right" then
            Fx.play("hover")
            return false
        end
    end

    if key == "a" or key == "left" then
        cursor = list[(pos - 2) % #list + 1]
        Fx.play("hover")
    elseif key == "d" or key == "right" then
        cursor = list[pos % #list + 1]
        Fx.play("hover")
    else
        local d = dice[cursor]
        local want
        if key == "w" or key == "up" then want = true
        elseif key == "s" or key == "down" then want = false
        elseif key == "space" then want = not d.selected
        else return false end
        if d.selected ~= want then
            local _, y0, scale = layout(visible(dice))
            toggle(d, y0, scale)
            return true
        end
    end
    return false
end

-- interactive = the player is picking dice (enables hover and scoring hints)
function DiceBoard.update(dt, dice, interactive)
    dustPS:update(dt)

    local count = visible(dice)
    local x0, y0, scale = layout(count)
    local mx, my = Screen.mouse()
    local drawIndex = 0
    local nowHovered = nil
    if mx ~= lastMx or my ~= lastMy then keyboard, lastMx, lastMy = false, mx, my end
    if not interactive then cursor = nil end
    if cursor and (dice[cursor].kept or dice[cursor].dying) then cursor = pickable(dice)[1] end

    -- which free dice could score (Options > Highlight scoring dice)
    local mask, free = {}, {}
    if interactive and Settings.data.hints then
        local values, wild, key = {}, {}, ""
        for i, d in ipairs(dice) do
            if not d.kept and not d.dying then
                values[#values + 1] = d.value
                wild[#values] = DiceTypes.get(d.type).wild
                free[#free + 1] = i
                key = key .. i .. d.value .. (wild[#values] and "w" or "")
            end
        end
        if key ~= maskKey then       -- only when the table changed
            maskKey, lastMask = key, Combos.scoringMask(Combos.resolve(values, wild) or values)
        end
        for n, ok in pairs(lastMask) do
            if ok then mask[free[n]] = true end
        end
    end

    for i, d in ipairs(dice) do
        fx(d, i)
        if not d.kept then
            local targetX = x0 + drawIndex * (DICE_W * scale + GAP)
            if not d.x then d.x = targetX end
            d.x = d.x + (targetX - d.x) * 15 * dt
            drawIndex = drawIndex + 1

            local over
            if keyboard then over = interactive and cursor == i
            else over = interactive and not d.dying and hit(d, mx, my, y0, scale) end
            if over then nowHovered = i end

            -- landing after a roll: squash, dust, thud
            if d.wasRolling and d.rolling <= 0 then
                local cx = center(d, y0, scale)
                d.pop = 0.8
                Fx.burst(cx, y0 + DICE_H * scale - 6, { 0.85, 0.85, 0.8 }, 10, 220)
                Fx.play("land", 0.85 + math.random() * 0.3)
                Fx.shake(0.07)
            end
            d.wasRolling = d.rolling > 0
            d.hover = d.hover + ((over and 1 or 0) - d.hover) * math.min(1, dt * 16)
            d.lift  = d.lift + ((d.selected and 1 or 0) - d.lift) * math.min(1, dt * 14)
            d.pop   = math.max(0, d.pop - dt * 2.5)
            d.hint  = mask[i] or false

            -- selected dice shed a few sparkles
            if d.selected and not d.dying and math.random() < dt * 7 then
                local cx, cy = center(d, y0, scale)
                local w, h = DICE_W * scale, DICE_H * scale
                Fx.sparkle(cx + (math.random() - 0.5) * w * 0.9, cy + (math.random() - 0.3) * h * 0.6)
            end
        end
    end

    if nowHovered and nowHovered ~= hovered and not keyboard then Fx.play("hover", 0.9 + math.random() * 0.2) end
    hovered = nowHovered
    if not keyboard and nowHovered then cursor = nowHovered end
end

-- Soft halo: the die sprite drawn bigger in additive blending, behind the die
local function glow(quad, cx, cy, rot, s, c, a)
    love.graphics.setBlendMode("add")
    for _, k in ipairs({ 1.16, 1.08 }) do
        love.graphics.setColor(c[1], c[2], c[3], a * (k > 1.1 and 0.5 or 1))
        love.graphics.draw(anim.spriteSheet, quad, cx, cy, rot, s * k, s * k, DICE_W / 2, DICE_H / 2)
    end
    love.graphics.setBlendMode("alpha")
end

-- One die with its type's tint and badge. face = quad or 1..6
function DiceBoard.drawDie(typeId, face, cx, cy, rot, s, isSelected, still)
    local t = DiceTypes.get(typeId)
    local c = t.tint
    local r, g, b = c[1], c[2], c[3]
    if t.wild then                       -- slow rainbow
        local k = love.timer.getTime() * 1.5
        r, g, b = 0.8 + 0.2 * math.sin(k), 0.8 + 0.2 * math.sin(k + 2.1), 0.8 + 0.2 * math.sin(k + 4.2)
        if still ~= false then face = anim.quads[1] end
    end
    if isSelected and t.id == "plain" then b = 0.6 end
    love.graphics.setColor(r, g, b, t.id == "crystal" and 0.88 or 1)
    local ox, oy = DICE_W / 2, DICE_H / 2
    if type(face) == "number" then       -- the faces are not centered in their frames
        ox, oy = ({ 94, 104, 113 })[(face - 1) % 3 + 1], face <= 3 and 95 or 109
        face = anim.quads[face]
    end
    love.graphics.draw(anim.spriteSheet, face, cx, cy, rot, s, s, ox, oy)
    if t.id == "plain" then return end
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(rot)
    love.graphics.setColor(1, 1, 1, 1)
    if t.wild then
        if still ~= false then JokerIcons.draw("badge_wild", -9 * s, -7 * s, 4 * s) end
    else
        JokerIcons.draw("badge_" .. t.id, 68 * s, 72 * s, 2.5 * s)
    end
    love.graphics.pop()
end

-- What the special die under the mouse / cursor does
function DiceBoard.drawTooltip(dice, interactive)
    local i = interactive and (keyboard and cursor or hovered)
    local d = i and dice[i]
    if not d or d.kept or not d.x or (d.type or "plain") == "plain" then return end
    local t = DiceTypes.get(d.type)
    local _, y0, scale = layout(visible(dice))
    local cx = center(d, y0, scale)
    local w, f = 340, Theme.fonts
    local _, lines = f.small:getWrap(t.desc, w - 30)
    local h = 70 + #lines * f.small:getHeight()
    local x = math.max(SIDEBAR_W + 10, math.min(Screen.W - w - 10, cx - w / 2))
    local y = y0 - 60 - h
    Theme.panel(x, y, w, h)
    love.graphics.setFont(f.normal)
    love.graphics.setColor(t.tint[1], t.tint[2], t.tint[3], 1)
    Theme.printf(t.name, x, y + 10, w, "center")
    love.graphics.setFont(f.small)
    Theme.color("dim")
    Theme.printf(t.desc, x + 15, y + 52, w - 30, "center")
end

function DiceBoard.draw(dice, interactive)
    local count = 0
    for _, d in ipairs(dice) do
        if d.slashed then
            return
        end
        if not d.kept then count = count + 1 end
    end
    local _, y0, scale = layout(count)
    local t = love.timer.getTime()
    local w, h = DICE_W * scale, DICE_H * scale

    for i, d in ipairs(dice) do
        if not d.kept and not d.dying and d.x then   -- d.x is set by the first update
            fx(d, i)
            local frame
            if d.rolling > 0 then
                frame = math.floor(t * 15 + i * 2) % #anim.quads + 1
            else
                frame = faceFrame[d.value]
            end
            local quad = anim.quads[frame]

            local _, sway = float(d)
            local cx, cy = center(d, y0, scale)
            local k = d.pop
            local s = scale * (1 + 0.06 * d.hover + 0.2 * k * k)
            local rot = sway + math.sin((1 - k) * 24) * 0.15 * k

            -- shadow on the table: smaller and lighter the higher the die floats
            local height = (y0 + h / 2) - cy
            local shrink = math.max(0.55, 1 - height / 120)
            love.graphics.setColor(0, 0, 0, 0.32 * shrink)
            love.graphics.ellipse("fill", cx, y0 + h + 4, w * 0.36 * shrink, 11 * shrink)

            if d.selected then
                glow(quad, cx, cy, rot, s, Theme.colors.gold, 0.45 + 0.2 * math.sin(t * 6 + i))
            elseif d.hint and interactive and d.rolling <= 0 then
                glow(quad, cx, cy, rot, s, Theme.colors.chips, 0.22 + 0.16 * math.sin(t * 4 + i * 0.6))
            end

            DiceBoard.drawDie(d.type, quad, cx, cy, rot, s, d.selected, d.rolling <= 0)
        end
    end

    -- keyboard cursor: bobbing yellow arrow above the die
    local cd = cursor and dice[cursor]
    if keyboard and interactive and cd and cd.x and not cd.kept and not cd.dying then
        local cx, cy = center(cd, y0, scale)
        local ay = cy - h / 2 - 34 + math.sin(t * 8) * 5
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.polygon("fill", cx - 17 + 3, ay - 14 + 3, cx + 17 + 3, ay - 14 + 3, cx + 3, ay + 14 + 3)
        love.graphics.setColor(1, 0.85, 0.3, 1)
        love.graphics.polygon("fill", cx - 17, ay - 14, cx + 17, ay - 14, cx, ay + 14)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(dustPS)
end

function DiceBoard.mousepressed(mx, my, dice)
    local _, y0, scale = layout(visible(dice))

    local clicked = false
    for i, d in ipairs(dice) do
        if not d.kept and not d.dying and hit(d, mx, my, y0, scale) then
            fx(d, i)
            toggle(d, y0, scale)
            clicked = true
            cursor, keyboard = i, false
        end
    end
    return clicked
end

return DiceBoard
