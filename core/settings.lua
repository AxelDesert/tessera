-- Player settings and run records, saved to LÖVE's save directory
-- (identity "tessera", see conf.lua) as a tiny  key=value  text file.
--
--   Settings.data.music / sfx   0..1 volume
--   Settings.data.fullscreen    bool
--   Settings.data.shake         bool (screen shake on a Farkle and when scoring)
--   Settings.data.float         bool (dice gently bob and sway)
--   Settings.data.hints         bool (glow on dice that can score)
--   Settings.data.background    1..4 (see ui/background.lua)
--   Settings.data.best_floors   most floors cleared in one run
--   Settings.data.escapes       runs that escaped the casino
--   Settings.data.runs          finished runs (won or lost)

local Settings = {}

local FILE = "settings.cfg"
local DEFAULTS = {
    music = 0.6, sfx = 0.7, fullscreen = false, shake = true, float = true, hints = true, background = 2,
    best_floors = 0, escapes = 0, runs = 0,
}
local ORDER = { "music", "sfx", "fullscreen", "shake", "float", "hints", "background", "best_floors", "escapes", "runs" }

Settings.data = {}
for k, v in pairs(DEFAULTS) do Settings.data[k] = v end

function Settings.load()
    if not love.filesystem.getInfo(FILE) then return end
    local text = love.filesystem.read(FILE)
    if not text then return end
    for key, raw in tostring(text):gmatch("([%w_]+)%s*=%s*([^\r\n]+)") do
        local default = DEFAULTS[key]
        if default ~= nil then
            raw = raw:match("^%s*(.-)%s*$")
            local value
            if raw == "true" then value = true
            elseif raw == "false" then value = false
            else value = tonumber(raw) end
            if value ~= nil and type(value) == type(default) then
                Settings.data[key] = value
            end
        end
    end
    local b = Settings.data.background
    if b ~= math.floor(b) or b < 1 or b > 4 then Settings.data.background = DEFAULTS.background end
    Settings.data.music = math.max(0, math.min(1, Settings.data.music))
    Settings.data.sfx   = math.max(0, math.min(1, Settings.data.sfx))
end

function Settings.save()
    local lines = {}
    for _, key in ipairs(ORDER) do
        lines[#lines + 1] = key .. "=" .. tostring(Settings.data[key])
    end
    love.filesystem.write(FILE, table.concat(lines, "\n") .. "\n")
end

-- Call once after love.window.setMode to restore fullscreen
function Settings.applyWindow()
    if Settings.data.fullscreen then
        love.window.setFullscreen(true, "desktop")
    end
end

function Settings.setFullscreen(on)
    Settings.data.fullscreen = on and true or false
    love.window.setFullscreen(Settings.data.fullscreen, "desktop")
    Settings.save()
end

function Settings.toggleFullscreen()
    Settings.setFullscreen(not love.window.getFullscreen())
end

-- Called by main when a run ends. `cleared` = floors cleared, `escaped` = won the run.
function Settings.recordRun(cleared, escaped)
    local d = Settings.data
    d.runs = d.runs + 1
    if escaped then d.escapes = d.escapes + 1 end
    if cleared > d.best_floors then d.best_floors = cleared end
    Settings.save()
end

return Settings
