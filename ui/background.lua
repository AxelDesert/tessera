-- Backgrounds behind the table and the title screen (Options > Background).
--   Background.load()                 once, in love.load
--   Background.draw(px, py, drift)    fills the whole window. px, py = parallax offset in pixels,
--                                     drift = slowly sway the wallpaper image (title screen)
--   Background.LIST                   names, in the order of Settings.data.background
--
-- The drawn ones are shaders, snapped to 4x4 blocks so they match the pixel art.

local Screen   = require("ui.screen")
local Settings = require("core.settings")

local Background = { LIST = { "Emerald Swirl", "High Roller", "Neon Night", "Roulette" } }

local COMMON = [[
extern vec4 view;      // left, top, width, height of the window in game pixels
extern vec2 shift;     // parallax
extern float time;

float hash(vec2 p) {
    p = fract(p * vec2(0.1031, 0.1130));
    p += dot(p, p.yx + 33.33);
    return fract((p.x + p.y) * p.x * 7.13 + p.y);
}
vec2 blocks(vec2 tc) { return floor((view.xy + tc * view.zw) / 4.0) * 4.0; }
]]

-- casino carpet: diamonds with card suits, drifting diagonally
local CARPET = COMMON .. [[
float disc(vec2 p, vec2 c, float r) { return step(length(p - c), r); }

float heart(vec2 p) {
    float lobes = max(disc(p, vec2(-13.0, -9.0), 15.5), disc(p, vec2(13.0, -9.0), 15.5));
    float tip = step(-4.0, p.y) * step(abs(p.x), (30.0 - p.y) * 0.80);
    return max(lobes, tip);
}
float stem(vec2 p) { return step(0.0, p.y) * step(p.y, 32.0) * step(abs(p.x), 3.0 + max(0.0, p.y - 18.0) * 0.6); }

float suit(vec2 p, float kind) {
    if (kind < 0.5) return heart(p);
    if (kind < 1.5) return max(heart(vec2(p.x, -p.y - 4.0)), stem(p));
    if (kind < 2.5) return step(abs(p.x) * 1.35 + abs(p.y), 34.0);
    float c = max(disc(p, vec2(0.0, -15.0), 13.0), max(disc(p, vec2(-14.0, 6.0), 13.0), disc(p, vec2(14.0, 6.0), 13.0)));
    return max(max(c, disc(p, vec2(0.0), 8.0)), stem(p));
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 p = blocks(tc);
    vec2 q = p + floor((vec2(time * 14.0, time * 9.0) + shift) / 4.0) * 4.0;
    vec2 a = vec2(q.x + q.y, q.x - q.y) / 240.0;
    vec2 id = floor(a);
    vec2 g = fract(a) - 0.5;
    vec2 l = vec2(g.x + g.y, g.x - g.y) * 120.0;              // pixels from the center of the diamond
    float edge = (0.5 - max(abs(g.x), abs(g.y))) * 240.0;
    float kind = mod(id.x + 2.0 * id.y, 4.0);

    float odd = mod(id.x + id.y, 2.0);
    vec3 col = mix(vec3(0.115, 0.085, 0.240), vec3(0.150, 0.100, 0.300), odd);
    col *= 0.88 + 0.12 * step(0.5, fract((l.x + l.y) / 32.0));         // woven stripes
    vec3 ink = (kind < 0.5 || (kind > 1.5 && kind < 2.5)) ? vec3(0.50, 0.12, 0.24) : vec3(0.20, 0.22, 0.52);
    col = mix(col, col * 0.55, suit(l - vec2(4.0, 6.0), kind));        // shadow
    col = mix(col, ink, suit(l, kind));
    col = mix(col, vec3(0.56, 0.36, 0.14), step(edge, 10.0) * step(2.0, edge));
    col = mix(col, vec3(0.06, 0.04, 0.13), step(edge, 2.0));

    float sweep = sin((p.x * 0.8 + p.y) * 0.0032 - time * 0.55);       // light rolling over the carpet
    col *= 1.0 + 0.22 * floor(sweep * 4.0 + 0.5) / 4.0;
    vec2 c = (tc - 0.5) * vec2(1.0, 0.9);
    col *= 1.0 - 0.8 * dot(c, c);
    return vec4(col, 1.0) * color;
}
]]

-- city at night: three layers of buildings with lit windows, reflected in the water
local NEON = COMMON .. [[
const float WATER = 850.0;

vec3 sky(vec2 p) {
    float h = clamp(p.y / WATER, 0.0, 1.0);
    h = floor(h * 14.0) / 14.0;
    vec3 col = mix(vec3(0.025, 0.035, 0.110), vec3(0.160, 0.070, 0.300), smoothstep(0.0, 0.6, h));
    col = mix(col, vec3(0.500, 0.130, 0.360), smoothstep(0.5, 1.0, h));
    vec2 s = floor(p / 4.0);
    float star = step(0.9972, hash(s)) * step(h, 0.55);
    col += star * (0.35 + 0.35 * sin(time * 2.0 + hash(s.yx) * 40.0));
    float m = length(p - vec2(1560.0, 330.0) - shift * 0.2);
    col = mix(col, vec3(0.62, 0.22, 0.42), step(m, 132.0) * 0.35);
    col = mix(col, vec3(0.99, 0.72, 0.42), step(m, 108.0) * 0.75);
    float crater = length(p - vec2(1590.0, 310.0) - shift * 0.2);
    col = mix(col, vec3(0.85, 0.52, 0.36), step(crater, 24.0) * 0.7);
    return col;
}

vec3 city(vec2 p) {
    vec3 col = sky(p);
    for (int i = 0; i < 3; i++) {
        float f = float(i);
        float w = 148.0 - f * 4.0;
        float x = p.x + floor((time * (3.0 + f * 5.0) + shift.x * (0.5 + f * 0.5)) / 4.0) * 4.0 + f * 1000.0;
        float n = floor(x / w);
        float lx = x - n * w;
        float r = hash(vec2(n, f * 17.0 + 3.0));
        float top = WATER - (430.0 - f * 125.0) * (0.35 + 0.65 * r);
        top = floor(top / 4.0) * 4.0;
        float mast = step(0.6, r) * step(abs(lx - w * 0.5), 3.0) * step(top - 56.0, p.y);
        float body = step(top, p.y) * step(4.0, lx);
        if (max(body, mast) > 0.5) {
            vec3 wall = mix(vec3(0.200, 0.085, 0.300), vec3(0.030, 0.040, 0.105), f / 2.0);
            col = wall;
            // neon trim on the roof
            vec3 neon = r < 0.33 ? vec3(0.004, 0.573, 0.976) : (r < 0.66 ? vec3(0.996, 0.298, 0.251) : vec3(0.99, 0.65, 0.15));
            col = mix(col, neon, step(p.y, top + 4.0) * body * (0.35 + 0.25 * f));
            // windows
            vec2 wp = vec2(lx - 16.0, p.y - top - 20.0);
            vec2 wi = floor(wp / vec2(24.0, 28.0));
            vec2 wf = wp - wi * vec2(24.0, 28.0);
            float inside = step(0.0, wp.x) * step(lx, w - 16.0) * step(0.0, wp.y) * step(wf.x, 11.0) * step(wf.y, 15.0);
            float h = hash(wi + vec2(n * 7.0, f * 31.0 + 11.0));
            float on = step(0.62, h) * step(0.06, fract(h * 37.0 + time * 0.03));
            vec3 lamp = mix(vec3(0.99, 0.70, 0.30), vec3(0.45, 0.75, 1.0), step(0.86, h));
            col = mix(col, lamp, body * inside * on * (0.22 + 0.16 * f));
        }
    }
    return col;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 p = blocks(tc);
    vec3 col;
    if (p.y < WATER) {
        col = city(p);
    } else {
        float d = p.y - WATER;
        float wave = floor(sin(p.y * 0.21 + time * 1.8) * (1.0 + d * 0.035)) * 4.0;
        col = city(vec2(p.x + wave, WATER - 4.0 - d * 1.5)) * vec3(0.42, 0.45, 0.62);
        col += vec3(0.05, 0.04, 0.10) * step(0.93, sin(p.x * 0.013 + p.y * 1.7 + time));
        col = mix(col, vec3(0.99, 0.45, 0.55), step(d, 3.0) * 0.35);
    }
    vec2 c = tc - 0.5;
    col *= 1.0 - 0.6 * dot(c, c);
    return vec4(col, 1.0) * color;
}
]]

-- a huge roulette wheel turning on green felt, with a ball and marquee lights
local ROULETTE = COMMON .. [[
extern vec2 center;
const float TAU = 6.2831853;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 p = blocks(tc);
    vec2 d = p - center + floor(shift / 4.0) * 4.0;
    float r = length(d);
    float ang = atan(d.y, d.x);

    // felt, with a faint diamond weave
    vec3 col = vec3(0.030, 0.165, 0.120);
    vec2 weave = mod(vec2(d.x + d.y, d.x - d.y), 64.0);
    col *= 0.90 + 0.10 * step(4.0, min(weave.x, weave.y));
    col *= 0.94 + 0.10 * hash(floor(p / 4.0));
    col *= 1.0 - 0.45 * step(length(d - vec2(12.0, 20.0)), 640.0);        // shadow of the wheel

    float spin = fract((ang - time * 0.10) / TAU);                        // 0..1 around the turning wheel
    float pocket = spin * 37.0;
    float n = floor(pocket);
    float side = min(fract(pocket), 1.0 - fract(pocket)) * TAU * r / 37.0; // pixels to the pocket border
    vec3 gold = vec3(0.62, 0.40, 0.14);
    vec3 wood = vec3(0.200, 0.095, 0.070);

    if (r < 640.0) {
        // outer wooden rim with twinkling lights
        col = wood * (0.85 + 0.15 * step(0.5, fract(r / 24.0)));
        float b = fract(ang / TAU + 0.5) * 48.0;
        vec2 bulb = vec2((fract(b) - 0.5) * TAU * 608.0 / 48.0, r - 608.0);
        float lit = step(0.5, fract((floor(b) + floor(time * 2.5)) / 3.0 + 0.17));
        col = mix(col, vec3(0.09, 0.04, 0.04), step(length(bulb), 17.0));
        col = mix(col, mix(vec3(0.40, 0.22, 0.10), vec3(1.0, 0.76, 0.34), lit), step(length(bulb), 12.0));
    }
    if (r < 576.0) col = gold;
    if (r < 568.0) {
        // ball track
        col = wood * 0.72;
        col += 0.03 * step(0.5, fract(r / 16.0));
    }
    if (r < 516.0) col = gold;
    if (r < 508.0) {
        // pockets: one green, the others red / black
        float odd = mod(n, 2.0);
        col = n < 0.5 ? vec3(0.05, 0.42, 0.24) : (odd > 0.5 ? vec3(0.46, 0.08, 0.11) : vec3(0.060, 0.065, 0.100));
        col *= r < 412.0 ? 0.62 : 1.0;                                    // deeper inner half
        col = mix(col, gold, step(side, 3.0));
        col = mix(col, gold, step(abs(r - 412.0), 4.0));
    }
    if (r < 316.0) col = gold;
    if (r < 308.0) {
        // turning cone with eight inlaid rays
        float ray = abs(fract(spin * 8.0) - 0.5) * 2.0;
        col = wood * (0.95 + 0.35 * (1.0 - r / 308.0));
        col = mix(col, wood * 1.55, step(0.5, fract(spin * 16.0)) * 0.6);
        col = mix(col, gold * 0.85, step(ray, 0.16) * step(r, 270.0) * step(110.0, r));
    }
    if (r < 112.0) col = gold * 0.75;
    if (r < 100.0) col = gold * (0.95 + 0.25 * step(d.x + d.y, 0.0));
    if (r < 44.0)  col = vec3(0.85, 0.60, 0.24) * (0.80 + 0.30 * step(d.x + d.y, -20.0));

    // the ball runs the other way, with a short trail
    float ba = -time * 0.75;
    for (int i = 3; i >= 0; i--) {
        float a = ba + float(i) * 0.045;
        vec2 c = floor(vec2(cos(a), sin(a)) * 542.0 / 4.0) * 4.0;
        float k = i == 0 ? 1.0 : 0.22 / float(i);
        if (i == 0) col *= 1.0 - 0.5 * step(length(d - c - vec2(6.0, 8.0)), 17.0);
        col = mix(col, vec3(0.92, 0.93, 0.96), step(length(d - c), 17.0 - float(i) * 3.0) * k);
        if (i == 0) col = mix(col, vec3(0.68, 0.72, 0.80), step(length(d - c), 17.0) * step(11.0, length(d - c + vec2(5.0))));
    }

    // glossy highlight that stays still while the wheel turns
    float gloss = step(r, 576.0) * step(0.955, cos(ang * 2.0 + 1.5));
    col += gloss * vec3(0.045, 0.045, 0.055);

    col *= 0.78;                                                           // keep dice and text readable
    vec2 v = tc - 0.5;
    col *= 1.0 - 0.9 * dot(v, v);
    return vec4(col, 1.0) * color;
}
]]

local wallpaper, pixel
local shaders = {}

function Background.load()
    wallpaper = love.graphics.newImage("assets/wallpaper.png")
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    pixel = love.graphics.newImage(data)
    for i, code in pairs({ [2] = CARPET, [3] = NEON, [4] = ROULETTE }) do
        local ok, result = pcall(love.graphics.newShader, code)
        if ok then shaders[i] = result else print("background shader: " .. tostring(result)) end
    end
end

function Background.draw(px, py, drift)
    px, py = px or 0, py or 0
    local vw, vh = Screen.right - Screen.left, Screen.bottom - Screen.top
    local t = love.timer.getTime() % 3600          -- small numbers keep the shaders precise
    love.graphics.setColor(1, 1, 1, 1)

    local shader = shaders[Settings.data.background]
    if shader then
        shader:send("view", { Screen.left, Screen.top, vw, vh })
        shader:send("shift", { px, py })
        shader:send("time", t)
        if shader:hasUniform("center") then      -- the wheel sits behind the dice, or the title
            shader:send("center", { drift and Screen.W / 2 or (Screen.W + Screen.SIDEBAR_W) / 2, Screen.H / 2 + 20 })
        end
        love.graphics.setShader(shader)
        love.graphics.draw(pixel, Screen.left, Screen.top, 0, vw, vh)
        love.graphics.setShader()
        return
    end

    -- the wallpaper image (also used if a shader is not supported)
    local iw, ih = wallpaper:getDimensions()
    local k, x, y, rot = math.max(vw / iw, vh / ih), Screen.W / 2, Screen.H / 2, 0
    if drift then   -- oversized so rotation and drift never reveal the edges
        k = k * 1.25 * (1 + math.sin(t * 0.2) * 0.03)
        x, y = x - px + math.sin(t * 0.13) * 40, y - py + math.cos(t * 0.11) * 25
        rot = math.sin(t * 0.09) * 0.07
    end
    love.graphics.draw(wallpaper, x, y, rot, k, k, iw / 2, ih / 2)
end

return Background
