-- estuary / visuals
-- twelve quiet places on the 128x64 OLED, drawn from what the music is doing
-- and from what the engine hears of itself. soft greys, a lot of black,
-- nothing that flashes the whole screen; the dim levels make the atmosphere
-- (sky, far shores, mist, water texture) and the brighter ones are kept for
-- what the music is doing.
--
-- the script feeds events as they happen (VIS.event), the engine's output
-- polls as they arrive (VIS.audio) and the conductor state every frame
-- (VIS.draw(theme, S)). under every theme runs the same water:
--
--   the current  a slow flow field of a few drifting sine terms. it runs out
--                to sea (right) while the bloom rises, back in while it
--                falls, and a swell pushes it inland. sound makes it stronger
--   the heave    a long slow undulation, deeper with out_lo
--   the glitter  a few short-lived bright points on the surface, as many as
--                out_hi asks for (none at silence)
--
-- motion runs on time, not frames: the speed param scales time, and a
-- dropped frame changes nothing but smoothness. events arrive eased: a note
-- never pops in at full brightness on its first frame.
--
-- each theme lives in lib/vis/<name>.lua. it returns a function that takes
-- the kit (K: the helpers below plus a read-only view of the water, refreshed
-- every frame) and returns {draw = fn(S), note = fn(slot, midi, dur),
-- chord = fn(S), moment = fn(), clear = fn()}; all but draw are optional.

local VIS = {}

VIS.names = {"ripples", "horizon", "postcards", "rain", "tide", "drift",
  "reeds", "koi", "kelp", "fireflies", "mist", "flock"}

local FPS = 20
local TAU = 2 * math.pi

-- state (declared before any function that uses it)
local B = 1                             -- brightness scale for this frame
local SP = 1                            -- speed scale (1 at the default 3)
local T = 0                             -- motion time, s (scaled by speed)
local NOW = 0                           -- real time since init, s
local DT, DTS = 1 / FPS, 1 / FPS        -- this frame's real / motion step
local last_clock                        -- util.time() at the last frame
local cur, xf = nil, 0                  -- theme on screen, its fade (0..1)
local THEMES = {}                       -- the loaded theme modules, by index

-- the engine's output, as polled: raw targets and eased followers
local AMP, LO, MID, HI, NAT = 1, 2, 3, 4, 5
local A_IDX = {out_amp = AMP, out_lo = LO, out_mid = MID, out_hi = HI, nat_amp = NAT}
local raw = {0, 0, 0, 0, 0}
local A = {0, 0, 0, 0, 0}
local RISE = {0.08, 0.35, 0.1, 0.06, 0.3}       -- s: rise fast-ish...
local FALL = {0.9, 2.2, 0.9, 0.7, 1.8}          -- ...fall slowly

-- the water
local energy = 0                        -- 0..1, how much sound is moving it
local flow_k = 1.2                      -- strength of the eddying terms, px/s
local cur_u = 0                         -- mean current, px/s; + is out to sea
local drift_x = 0                       -- the current, integrated (px)
local bloom_s, tide_dir = 0, 0          -- eased bloom; tide -1 in .. +1 out
local bloom_seen = false                -- the eased bloom starts where the music is

-- shared by every theme, built from events whatever is on screen so a theme
-- switch has history to show at once
local slot_kick = {0, 0, 0, 0}          -- a note just landed; decays
local slot_flash = {0, 0, 0, 0}         -- follows the kick, eased up
local slot_glow = {0, 0, 0, 0}          -- recent notes, slow
local slot_last = {}                    -- slot -> last midi
local sw_state, sw_level, sw_disp = "idle", 0, 0
local bar_kick, bar_pulse = 0, 0
local moment_age = 999
local hist = {}                         -- per bar: {bloom, wet}
local HIST_N = 80
local step_seen, step_t = -1, 0
local bar_t, bar_len = 0, 3.3           -- when the last bar landed, a bar's length (s)
local glints, glint_acc = {}, 0
local rseed = 1                         -- the visuals' own dice

local GLINT_MAX = 14

-- the kit every theme draws with (filled in below, refreshed every frame)
local K = {A = A, AMP = AMP, LO = LO, MID = MID, HI = HI, NAT = NAT, TAU = TAU,
  slot_kick = slot_kick, slot_flash = slot_flash, slot_glow = slot_glow,
  slot_last = slot_last, hist = hist, HIST_N = HIST_N}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- smoothstep: 0..1 eased at both ends
local function ease(u)
  u = clamp(u, 0, 1)
  return u * u * (3 - 2 * u)
end

-- a follower step toward `to` with time constant `tau` over dt
local function follow(v, to, tau, dt) return v + (to - v) * (1 - math.exp(-dt / tau)) end

-- own dice so the visuals never disturb (or depend on) math.random
local function rnd()
  rseed = (rseed * 1103515245 + 12345) & 0x7fffffff
  return rseed / 0x80000000
end

-- a fixed hash 0..1 of an integer (and a salt): for shapes that must not move
local function hash(i, s)
  i = tonumber(i) or 0
  if not (i > -1e9 and i < 1e9) then i = 0 end                 -- also NaN
  i = math.floor(i) // 1 | 0
  local h = ((i * 374761393 + (s or 0) * 668265263) & 0x7fffffff)
  h = ((h ~ (h >> 13)) * 1274126177) & 0x7fffffff
  return (h ~ (h >> 16)) / 0x80000000
end

-- note -> screen column: the motif range (G3..G6) spans the width
local function px(m)
  m = tonumber(m) or 60
  return clamp(math.floor(6 + (m - 55) / 36 * 116 + 0.5), 3, 124)
end

local function opt(id, d)
  local ok, v = pcall(function() return params:get(id) end)
  if ok and type(v) == "number" then return v end
  return d
end

------------------------------------------------------------------------
-- batched rects: one fill per brightness level, not one per rect
------------------------------------------------------------------------

local batch, bn = {}, {}
for l = 1, 15 do batch[l], bn[l] = {}, 0 end

local function put(l, x, y, w, h)
  l = l * B
  if not (l >= 0.5) or x ~= x or y ~= y then return end     -- also drops NaN
  l = math.floor(l + 0.5)
  if l > 15 then l = 15 end
  local b, n = batch[l], bn[l]
  b[n + 1], b[n + 2], b[n + 3], b[n + 4] = math.floor(x), math.floor(y), w or 1, h or 1
  bn[l] = n + 4
end

local function flush()
  for l = 1, 15 do
    local n = bn[l]
    if n > 0 then
      local b = batch[l]
      screen.level(l)
      for i = 1, n, 4 do screen.rect(b[i], b[i + 1], b[i + 2], b[i + 3]) end
      screen.fill()
      bn[l] = 0
    end
  end
end

------------------------------------------------------------------------
-- scenery: profiles, silhouettes and dithered gradients from few wide rects
------------------------------------------------------------------------

-- a skyline profile: prof[c] is the top y of the land at column 2c (c = 0..64)
local function profile(fn)
  local p = {}
  for c = 0, 64 do p[c] = fn(c * 2) end
  return p
end

-- a profile's height at any x
local function at(prof, x)
  local c = math.floor(x / 2)
  if c < 0 then c = 0 elseif c > 64 then c = 64 end
  return prof[c]
end

-- a tree line: n rounded crowns of seeded size along the width, standing on
-- `base`; returns x -> the top of the trees there (base where there are none)
local function crowns(seed, n, base, hmin, hmax, rmin, rmax, x0, x1)
  x0, x1 = x0 or -6, x1 or 134
  local tr = {}
  for i = 1, n do
    local u = (i - 1 + 0.2 + 0.6 * hash(i, seed)) / n
    tr[i] = {x = x0 + u * (x1 - x0), h = hmin + (hmax - hmin) * hash(i, seed + 1),
      r = rmin + (rmax - rmin) * hash(i, seed + 2)}
  end
  return function(x)
    local top = base
    for i = 1, n do
      local t = tr[i]
      local d = (x - t.x) / t.r
      if d > -1 and d < 1 then
        local y = base - t.h + t.r * (1 - math.sqrt(1 - d * d)) * 0.8
        if y < top then top = y end
      end
    end
    return top
  end
end

-- a solid silhouette from a profile down to y_bot, one 2-px column per rect
local function mass(l, prof, y_bot, x0, x1)
  for c = (x0 or 0) // 2, math.min(63, ((x1 or 128) - 1) // 2) do
    local top = math.floor(prof[c] + 0.5)
    if top < y_bot then put(l, c * 2, top, 2, y_bot - top) end
  end
end

-- one row lit where it is above the profile (prof may be nil: all of it),
-- merged into runs so a row costs one rect per gap in the land
local function row_above(l, y, prof, x0, x1)
  x0, x1 = x0 or 0, x1 or 128
  if not prof then put(l, x0, y, x1 - x0, 1); return end
  local run
  for c = x0 // 2, (x1 - 1) // 2 do
    if y < prof[c] then
      run = run or c * 2
    elseif run then
      put(l, run, y, c * 2 - run, 1); run = nil
    end
  end
  if run then put(l, run, y, x1 - run, 1) end
end

-- ordered dither thresholds down the rows: any 8 rows in a row hold each
-- step once, so a light of 3/8 lights 3 rows in every 8, evenly spread
local TH8 = {0, 4, 2, 6, 1, 5, 3, 7}

-- a vertical gradient made of whole rows: `lv(y)` is the light at row y
-- (0..~6, fractional). each row draws at the floor level, and the fraction
-- decides by ordered dither whether it steps up a level; rows whose light is
-- under 1 are lit by density instead (a row every 2, 3, 4...). above the
-- profile only, when one is given
local function gradient(y0, y1, lv, prof, x0, x1)
  for y = y0, y1 do
    local v = lv(y)
    if v > 0.05 then
      local th = (TH8[y % 8 + 1] + 0.5) / 8
      local l
      if v < 1 then l = (v > th) and 1 or 0
      else
        l = math.floor(v)
        if v - l > th then l = l + 1 end
      end
      if l > 0 then row_above(l, y, prof, x0, x1) end
    end
  end
end

-- a dashed row: dashes of `w` px every `gap` px, slid by `off`
local function dashes(l, y, w, gap, off, x0, x1)
  x0, x1 = x0 or 0, x1 or 128
  local s = x0 + (off % gap) - gap
  for x = s, x1 - 1, gap do
    local a, b = math.max(x0, x), math.min(x1, x + w)
    if b > a then put(l, a, y, b - a, 1) end
  end
end

-- a row of reflection: dashes `w` long every `gap`, slid by `off`, each kept
-- only where keep(x) says the mirrored scene is lit there (nil: everywhere)
-- and nudged by nudge(x, y) -> dx, dl (nil: none)
local function streaks(l, y, w, gap, off, keep, nudge, x0, x1)
  x0, x1 = x0 or 0, x1 or 128
  for x = x0 + (off % gap) - gap, x1 - 1, gap do
    local cx = x + w * 0.5
    if cx >= x0 and cx < x1 and (not keep or keep(cx)) then
      local dx, dl = 0, 0
      if nudge then dx, dl = nudge(cx, y) end
      put(l + dl, x + dx, y, w, 1)
    end
  end
end

------------------------------------------------------------------------
-- the water every theme shares
------------------------------------------------------------------------

-- the current at a point: the mean flow plus slow eddying terms (px/s)
local function flow(x, y)
  local u = cur_u + flow_k * (0.45 * math.sin(y * 0.11 + T * 0.23)
    + 0.25 * math.sin((x + y) * 0.05 - T * 0.15))
  local v = flow_k * 0.3 * math.sin(x * 0.07 - T * 0.19 + 1.3)
  return u, v
end

-- the heave: a long slow undulation, always a little, deeper with out_lo
local function heave(x)
  return (0.6 + 2.6 * A[LO]) * math.sin(x * 0.045 - T * 0.55 + 0.8 * math.sin(T * 0.07))
end

-- the faint moving surface: short dashes on staggered rows that ride the
-- current (nearer rows faster) and the heave. a dash shows where two slow
-- waves agree, so the pattern breathes rather than scrolls
local function surface(x0, y0, x1, y1, lvl, gap, dy, wlen)
  local row = 0
  wlen = wlen or 2
  for y = y0, y1 - 1, dy do
    local par = 0.6 + 0.8 * (y / 64)
    local off = (drift_x * par + row * gap * 0.5) % gap
    for x = x0 + off, x1 - 1, gap do
      local w = math.sin(x * 0.11 + y * 0.6 - T * 0.8) + 0.7 * math.sin(x * 0.043 - y * 0.27 + T * 0.37)
      if w > 0.35 then put(lvl * (w > 1.2 and 2 or 1), x, y + heave(x) * 0.5, wlen, 1) end
    end
    row = row + 1
  end
end

-- glitter: out_hi spawns short-lived points where `sample(u, v)` says the
-- surface is; each rises and fades on a sine, never a flash
local function glitter(sample, rate)
  glint_acc = glint_acc + A[HI] * (rate or 22) * DTS
  while glint_acc >= 1 do
    glint_acc = glint_acc - 1
    if #glints < GLINT_MAX then
      local x, y = sample(rnd(), rnd())
      if x then glints[#glints + 1] = {x = x, y = y, t0 = T, life = 0.2 + 0.3 * rnd(), pk = 4 + 3 * rnd()} end
    end
  end
  for i = #glints, 1, -1 do
    local g = glints[i]
    local u = (T - g.t0) / g.life
    if u >= 1 then
      table.remove(glints, i)
    elseif u > 0 then
      local lv = g.pk * math.sin(math.pi * u)
      put(lv, g.x, g.y, 1, 1)
      if lv > 4 then put(lv * 0.35, g.x - 1, g.y, 1, 1); put(lv * 0.35, g.x + 1, g.y, 1, 1) end
    end
  end
end

local function substep(S)
  local tempo = clamp(tonumber(S.tempo) or 72, 20, 300)
  return clamp((NOW - step_t) / (60 / tempo / 2), 0, 1)
end

local function sounding(S, i)
  local snd, g, mu = S.sounding, S.gain, S.muted
  if type(snd) ~= "table" or not snd[i] then return false end
  if type(g) ~= "table" or (tonumber(g["motif" .. i]) or 0) <= 0.02 then return false end
  return not (type(mu) == "table" and mu["motif" .. i])
end

local function motif(S, i)
  local m = type(S.motifs) == "table" and S.motifs[i]
  if type(m) == "table" and (tonumber(m.cycle) or 0) > 0 then return m end
end

-- where a motif is in its cycle, 0..1 (nil when it has none)
local function phase(S, i)
  local m = motif(S, i)
  if not m then return nil end
  local step = tonumber(S.step) or 0
  return ((step + substep(S)) % m.cycle) / m.cycle
end

-- the chord as a plain list of numbers (a missing or short chord is fine)
local function chord(S)
  local c, out = type(S.chord) == "table" and S.chord or {}, {}
  for i = 1, 4 do
    local m = tonumber(c[i])
    if m and m == m then out[#out + 1] = m end
  end
  return out
end

-- once a frame: the followers, the tide, the current, the eased events
local function physics(S)
  for k = 1, 5 do
    local to = raw[k]
    A[k] = follow(A[k], to, to > A[k] and RISE[k] or FALL[k], DT)
  end
  energy = clamp(0.7 * A[AMP] + 0.3 * A[MID], 0, 1)
  -- the tide turns with the bloom: out while it rises, in while it falls
  local b = clamp(tonumber(S.bloom) or 0, 0, 1)
  if not bloom_seen then bloom_s, bloom_seen = b, true end
  local nb = follow(bloom_s, b, 2, DT)
  local slope = DT > 0 and (nb - bloom_s) / DT or 0
  bloom_s = nb
  tide_dir = follow(tide_dir, clamp(slope * 150, -1, 1), 6, DT)
  sw_disp = follow(sw_disp, sw_state ~= "idle" and clamp(tonumber(sw_level) or 0, 0, 1) or 0, 1.25, DT)
  flow_k = 1.2 + 4 * energy
  local to_u = (1.5 + 4 * energy) * (0.8 * tide_dir - 1.3 * sw_disp + 0.35 * math.sin(T * 0.029 + 2))
  cur_u = follow(cur_u, to_u, 3, DT)
  drift_x = drift_x + cur_u * DTS
  for s = 1, 4 do
    slot_flash[s] = follow(slot_flash[s], slot_kick[s], 0.05, DT)
    slot_kick[s] = slot_kick[s] * math.exp(-DT / 0.33)
    slot_glow[s] = slot_glow[s] * math.exp(-DT / 3)
  end
  bar_pulse = follow(bar_pulse, bar_kick, 0.08, DT)
  bar_kick = bar_kick * math.exp(-DT / 0.7)
  moment_age = moment_age + DT
  -- where the step clock is between steps (0..1), for smooth phases
  local step = tonumber(S.step) or 0
  if step ~= step_seen then step_seen, step_t = step, NOW end
end

-- the read-only view of the water the themes see this frame
local function sync(S)
  K.T, K.NOW, K.DT, K.DTS, K.SP = T, NOW, DT, DTS, SP
  K.energy, K.flow_k, K.cur_u, K.drift_x = energy, flow_k, cur_u, drift_x
  K.bloom, K.tide_dir = bloom_s, tide_dir
  K.sw_state, K.sw_level, K.sw_disp = sw_state, clamp(tonumber(sw_level) or 0, 0, 1), sw_disp
  K.bar_pulse, K.moment_age, K.bar_t, K.bar_len = bar_pulse, moment_age, bar_t, bar_len
  K.S = S
end

K.clamp, K.ease, K.follow, K.rnd, K.hash, K.px, K.opt = clamp, ease, follow, rnd, hash, px, opt
K.put, K.profile, K.mass, K.row_above, K.gradient, K.dashes = put, profile, mass, row_above, gradient, dashes
K.streaks, K.at, K.crowns = streaks, at, crowns
K.flow, K.heave, K.surface, K.glitter = flow, heave, surface, glitter
K.substep, K.sounding, K.motif, K.phase, K.chord = substep, sounding, motif, phase, chord
K.echo = function() return clamp(opt("echo_fb", 0.45), 0, 0.85), opt("echo_div", 3) end

sync({})

-- the themes, each in its own file (include, not require: norns resolves it
-- against the script's folder)
for i, name in ipairs(VIS.names) do
  THEMES[i] = include("lib/vis/" .. name)(K)
end

------------------------------------------------------------------------
-- dispatch
------------------------------------------------------------------------

local function clear_theme(i)
  local th = THEMES[i]
  if th and th.clear then th.clear() end
end

function VIS.init()
  for i = #glints, 1, -1 do glints[i] = nil end
  for i = #hist, 1, -1 do hist[i] = nil end
  for k in pairs(slot_last) do slot_last[k] = nil end
  glint_acc = 0
  for s = 1, 4 do slot_kick[s], slot_flash[s], slot_glow[s] = 0, 0, 0 end
  sw_state, sw_level, sw_disp, bar_kick, bar_pulse = "idle", 0, 0, 0, 0
  moment_age = 999
  step_seen, step_t, bar_t, bar_len = -1, 0, 0, 3.3
  for k = 1, 5 do raw[k], A[k] = 0, 0 end
  energy, flow_k, cur_u, drift_x, bloom_s, tide_dir = 0, 1.2, 0, 0, 0, 0
  bloom_seen = false
  T, NOW, last_clock = 0, 0, nil
  cur, xf = nil, 0
  rseed = 1
  for i = 1, #THEMES do
    local th = THEMES[i]
    if th.init then th.init() elseif th.clear then th.clear() end
  end
end

-- a poll value from the engine (out_amp, out_lo, out_mid, out_hi, nat_amp).
-- anything that is not a number in 0..1 is clamped, NaN reads as 0
function VIS.audio(name, v)
  local i = A_IDX[name]
  if not i then return end
  if type(v) ~= "number" or v ~= v then v = 0 end
  raw[i] = clamp(v, 0, 1)
end

-- kind: "note" (slot, midi, dur_s), "chord" (S), "bar" (S), "swell"
-- (state, level), "moment" (kind)
function VIS.event(kind, a, b, c)
  local th = cur and THEMES[cur]
  if kind == "note" then
    local slot = clamp(math.floor(tonumber(a) or 1), 1, 4)
    slot_kick[slot] = 1
    slot_glow[slot] = math.min(1, slot_glow[slot] + 0.5)
    slot_last[slot] = tonumber(b) or slot_last[slot]
    if th and th.note then th.note(slot, b, c) end
  elseif kind == "bar" then
    bar_kick = 1
    local wet = 0
    if sw_state ~= "idle" then wet = math.max(0.35, clamp(tonumber(sw_level) or 0, 0, 1)) end
    -- the eased bloom, so the shoreline meets its live edge without a step
    hist[#hist + 1] = {bloom = bloom_s, wet = wet}
    bar_t = NOW
    local bs = type(a) == "table" and tonumber(a.bar_sec)
    bar_len = clamp(bs or (type(a) == "table" and 240 / clamp(tonumber(a.tempo) or 72, 20, 300)) or 3.3, 0.5, 20)
    if #hist > HIST_N then table.remove(hist, 1) end
  elseif kind == "swell" then
    sw_state, sw_level = a or "idle", tonumber(b) or 0
  elseif kind == "moment" then
    moment_age = 0
    if th and th.moment then th.moment() end
  elseif kind == "chord" then
    if th and th.chord and type(a) == "table" then th.chord(a) end
  end
end

-- this frame's real step: given (tests), or from the clock; a stall or a
-- repeat draw never jumps the water
local function frame_dt(dt)
  if dt == nil then
    local now = util and util.time and util.time()
    if type(now) == "number" and last_clock then dt = now - last_clock else dt = 1 / FPS end
    last_clock = now
  end
  if type(dt) ~= "number" or dt ~= dt then dt = 1 / FPS end
  return clamp(dt, 0, 0.25)
end

-- draw theme i. dt (s) is optional: on the norns it comes from the clock
function VIS.draw(i, S, dt)
  if not THEMES[i] or type(S) ~= "table" then return end
  DT = frame_dt(dt)
  SP = clamp(opt("vis_speed", 3) / 3, 0.1, 5)
  DTS = DT * SP
  NOW = NOW + DT
  T = T + DTS
  physics(S)
  -- a theme switch: the old picture eases to black, the new one eases up
  if cur == nil then cur = i end
  if i ~= cur then
    xf = xf - DT / 0.3
    if xf <= 0 then
      clear_theme(cur)
      for k = #glints, 1, -1 do glints[k] = nil end
      xf, cur = 0, i
    end
  else
    xf = math.min(1, xf + DT / 0.6)
  end
  B = opt("vis_brightness", 10) / 10 * ease(xf)
  sync(S)
  THEMES[cur].draw(S)
  flush()
end

return VIS
