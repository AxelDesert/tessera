-- Balatro-style score display: [CHIPS] X [MULT] = total.
--
--   panel:preview(result | nil, text)  live preview while the player selects dice
--   panel:start(result)                animate every step of Scoring.compute()
--   panel:update(dt)                   returns true once, when the animation ends
--   panel:reset()                      back to 0 x 0
--   panel:draw(x, y, w)

local Theme   = require("ui.theme")
local Scoring = require("core.scoring")

local fmt = Scoring.formatNumber

local ScorePanel = {}
ScorePanel.__index = ScorePanel

ScorePanel.HEIGHT = 244

local STEP_TIME = 0.6   -- seconds each step (combo / joker) stays on screen
local HOLD_TIME = 0.9   -- pause on the final total

function ScorePanel.new()
    local self = setmetatable({}, ScorePanel)
    self:reset()
    return self
end

function ScorePanel:reset()
    self.busy, self.showTotal = false, false
    self.chips, self.mult, self.total = 0, 0, 0
    self.label, self.detail, self.kind = "", "", "combo"
    self.result, self.index, self.timer, self.pop = nil, 0, 0, 0
end

function ScorePanel:preview(result, invalidText)
    self:reset()
    if result then
        self.chips, self.mult, self.label = result.chips, result.mult, result.name
    else
        self.label = invalidText or ""
    end
end

function ScorePanel:start(result)
    self:reset()
    self.result, self.busy = result, true
end

function ScorePanel:update(dt)
    self.pop = math.max(0, self.pop - dt * 4)
    if not self.busy then return false end

    self.timer = self.timer - dt
    if self.timer > 0 then return false end

    local steps = self.result.steps
    if self.index < #steps then
        self.index = self.index + 1
        local s = steps[self.index]
        self.chips, self.mult = s.chips, s.mult
        self.label, self.detail, self.kind = s.label, s.text, s.kind
        self.pop, self.timer = 1, STEP_TIME
    elseif not self.showTotal then
        self.showTotal, self.total = true, self.result.total
        self.label, self.detail, self.kind = "", "", "combo"
        self.pop, self.timer = 1, HOLD_TIME
    else
        self.busy = false
        return true
    end
    return false
end

-- Number centered on (cx, cy), shrunk to fit maxW, with a "pop" scale
local function drawValue(text, cx, cy, scale, maxW)
    local font = Theme.fonts.num
    love.graphics.setFont(font)
    local s = scale * math.min(1, maxW / font:getWidth(text))
    Theme.print(text, cx, cy, 0, s, s, math.floor(font:getWidth(text) / 2), math.floor(font:getHeight() / 2))
end

function ScorePanel:draw(x, y, w)
    local f = Theme.fonts
    Theme.box(x, y, w, ScorePanel.HEIGHT, "dark")

    -- what is being counted right now (combo or joker name)
    love.graphics.setFont(f.normal)
    Theme.color(self.kind == "joker" and "gold" or "text")
    Theme.printf(self.label, x + 10, y + 2, w - 20, "center")
    love.graphics.setFont(f.small)
    Theme.color("dim")
    Theme.printf(self.detail, x + 10, y + 42, w - 20, "center")

    -- chips X mult
    local gap = 44
    local boxW, by, bh = (w - 24 - gap) / 2, y + 78, 108
    local chipsX, multX = x + 12, x + 12 + boxW + gap
    local scale = 1 + 0.3 * self.pop

    Theme.box(chipsX, by, boxW, bh, "chips")
    Theme.box(multX, by, boxW, bh, "mult")

    love.graphics.setFont(f.tiny)
    Theme.color("text", 0.85)
    Theme.printf("CHIPS", chipsX, by + 4, boxW, "center")
    Theme.printf("MULT", multX, by + 4, boxW, "center")
    Theme.color("text")
    drawValue(fmt(self.chips), chipsX + boxW / 2, by + 60, scale, boxW - 16)
    drawValue(fmt(self.mult), multX + boxW / 2, by + 60, scale, boxW - 16)

    love.graphics.setFont(f.normal)
    Theme.color("mult")
    Theme.printf("X", x + 12 + boxW, by + 60 - f.normal:getHeight() / 2, gap, "center")

    if self.showTotal then
        Theme.color("gold")
        drawValue("= " .. fmt(self.total), x + w / 2, y + 216, scale, w - 20)
    end
end

return ScorePanel
