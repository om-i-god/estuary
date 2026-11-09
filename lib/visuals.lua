-- estuary / visuals
-- twenty-eight quiet places on the 128x64 OLED, drawn from what the music is doing
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
-- chord = fn(S), moment = fn(), clear = fn(), incidents = {{name, secs}, ..}};
-- all but draw are optional.
--
-- shared by every theme besides the water:
--   the breath    a slow swell of light on each bar (K.breath, 0..1)
--   the chord     its tones, gliding from the last chord over ~3 s
--                 (K.chord_at(i) -> midi, presence)
--   the daylight  the eased bloom (K.bloom): themes warm and brighten with it
--   incidents     small natural happenings, one at a time, rare (a minute or
--                 two apart), eased in and out over ~3 s; the kit picks when
--                 and which (K.inc = {name, u, e, age, s} or nil)

local VIS = {}

-- (the list only grows at the end: saved psets keep pointing at the same place)
VIS.names = {"ripples", "horizon", "postcards", "rain", "tide", "drift",
  "reeds", "koi", "kelp", "fireflies", "mist", "flock",
  "brook", "rockpool", "dew", "cascade", "mangrove", "aurora", "shoal", "paddies",
  "echo bridge", "confluence",
  "delta", "onsen", "lotus", "glacier", "pod", "wellspring"}

local FPS = 20
local TAU = 2 * math.pi

-- state (declared before any function that uses it)
local B = 1                             -- brightness scale for this frame
local FJ = 0                            -- while a place fades in or out: a fixed
                                        -- per-place level jitter, so its dim
                                        -- texture fades a few rects at a time
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
local rseed = 1                         -- the visuals' own dice (themes, events)
local gseed = 7                         -- the glitter's, so a note never moves it
local iseed = 3                         -- the incidents'
local breath, breath_mid, breath_kick = 0, 0, 0   -- the bar's slow breath
local ch_now, ch_prev = {}, {}          -- the chord's tones, and the last chord's
local ch_prev_p = {}                    -- how present each last tone was when the chord moved
local ch_age = 999                      -- s since the chord moved
local ch_glow, ch_glow_mid, ch_kick = 0, 0, 0           -- the glow a chord change brings: up ~1 s, down ~3 s, never a step
local inc, inc_next, inc_last = nil, 0, 0  -- the incident on screen, when the next may start

local GLINT_MAX = 20

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
local function grnd()
  gseed = (gseed * 1103515245 + 12345) & 0x7fffffff
  return gseed / 0x80000000
end
local function irnd()
  iseed = (iseed * 1103515245 + 12345) & 0x7fffffff
  return iseed / 0x80000000
end

-- a fixed hash 0..1 of an integer (and a salt): for shapes that must not move
local function hash(i, s)
  i = tonumber(i) or 0
  if not (i > -1e9 and i < 1e9) then i = 0 end                 -- also NaN
  i = math.floor(i) // 1 | 0
  s = tonumber(s) or 0
  if not (s > -1e9 and s < 1e9) then s = 0 end
  s = math.floor(s) // 1 | 0
  local h = ((i * 374761393 + s * 668265263) & 0x7fffffff)
  h = ((h ~ (h >> 13)) * 1274126177) & 0x7fffffff
  return (h ~ (h >> 16)) / 0x80000000
end

-- note -> screen column: the motif range (G3..G6) spans the width
local function px(m)
  m = tonumber(m) or 60
  if m ~= m then m = 60 end
  return clamp(math.floor(6 + (m - 55) / 36 * 116 + 0.5), 3, 124)
end

-- a chord tone -> screen column: the pad's range (C2..E5) spans the width
local function cx(m)
  m = tonumber(m) or 60
  if m ~= m then m = 60 end
  return clamp(8 + (m - 36) / 40 * 112, 4, 123)
end

-- a note's height 0 (low) .. 1 (high) over the motif range
local function pu(m)
  m = tonumber(m) or 60
  if m ~= m then m = 60 end
  return clamp((m - 55) / 36, 0, 1)
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
  w, h = w or 1, h or 1
  if x ~= x or y ~= y then return end                        -- NaN
  if FJ > 0 and l > 0 and x > -1e6 and x < 1e6 and y > -1e6 and y < 1e6 then
    l = l + FJ * (((x * 7 + y * 13) // 1 & 15) / 16 - 0.47)
  end
  if not (l >= 0.5) then return end                          -- also drops NaN
  if not (w >= 1 and h >= 1) then return end                 -- empty / negative sizes
  if l > 14.5 then l = 15 else l = (l + 0.5) // 1 end
  local n = bn[l]
  local b = batch[l]
  b[n + 1], b[n + 2], b[n + 3], b[n + 4] = x // 1, y // 1, w, h
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

-- a baked layer: rects recorded once (at load or init) and replayed every
-- frame straight into the batches, grouped by level. bake(fn) calls
-- fn(rec) where rec(l, x, y, w, h) records one rect; a rect's level gets a
-- small fixed jitter (+-0.25) so a group scaled by the daylight steps up a
-- few rects at a time rather than all at once
local function bake(fn)
  local L, groups, k = {}, {}, 0
  fn(function(l, x, y, w, h)
    w, h = math.floor(w or 1), math.floor(h or 1)
    if not (l > 0) or w < 1 or h < 1 or x ~= x or y ~= y then return end
    k = k + 1
    local j = ((k * 2654435761) & 0xff) / 255 * 0.5 - 0.25
    local key = math.floor((l + j) * 8 + 0.5) / 8
    local g = groups[key]
    if not g then g = {lv = key, n = 0}; groups[key] = g; L[#L + 1] = g end
    local n = g.n
    g[n + 1], g[n + 2], g[n + 3], g[n + 4] = math.floor(x), math.floor(y), w, h
    g.n = n + 4
  end)
  return L
end

-- replay a baked layer at `mul` times its levels, slid `dx` px (wrapping
-- round the 128-px width when `wrap`). `soft`: a layer sliding slowly
-- moves on a few rects at a time, each its own share of the way between
-- the whole-pixel places either side of dx, so it glides instead of the
-- whole layer hopping a pixel in one frame (same number of rects)
local function blit(L, mul, dx, wrap, soft)
  mul = (mul or 1) * B
  dx = dx or 0
  local fr = 0
  if soft then fr = dx - math.floor(dx) end
  dx = math.floor(dx)
  if wrap then dx = dx % 128 end
  local q = 0
  if FJ > 0 then
    -- (fading: each rect rounds its own way, through put)
    local b0 = B
    B = 1
    for gi = 1, #L do
      local g = L[gi]
      local l = g.lv * mul
      for i = 1, g.n, 4 do
        local x = g[i] + dx
        -- (keeping the soft slide's stagger while it fades)
        if fr > 0 then
          q = q + 1
          if (((q * 2654435761) >> 8) & 255) / 256 < fr then x = x + 1 end
        end
        if wrap and x >= 128 then x = x - 128 end
        put(l, x, g[i + 1], g[i + 2], g[i + 3])
        if wrap and x + g[i + 2] > 128 then put(l, x - 128, g[i + 1], g[i + 2], g[i + 3]) end
      end
    end
    B = b0
    return
  end
  for gi = 1, #L do
    local g = L[gi]
    local l = g.lv * mul
    if l >= 0.5 then
      l = math.floor(l + 0.5)
      if l > 15 then l = 15 end
      local b, n = batch[l], bn[l]
      for i = 1, g.n, 4 do
        local x, w = g[i] + dx, g[i + 2]
        if fr > 0 then
          q = q + 1
          if (((q * 2654435761) >> 8) & 255) / 256 < fr then x = x + 1 end
        end
        if wrap and x >= 128 then x = x - 128 end
        b[n + 1], b[n + 2], b[n + 3], b[n + 4] = x, g[i + 1], w, g[i + 3]
        n = n + 4
        if wrap and x + w > 128 then
          b[n + 1], b[n + 2], b[n + 3], b[n + 4] = x - 128, g[i + 1], w, g[i + 3]
          n = n + 4
        end
      end
      bn[l] = n
    elseif fr > 0 then
      -- (a group too dim to draw still takes its turns, so the stagger
      -- never re-deals when it brightens)
      q = q + g.n // 4
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

-- the hand-made dither: every row is cut into strokes 3..13 px long, each
-- with its own threshold, part fixed noise, part a slow blotchy field, so a
-- gradient breaks into irregular brushed strokes instead of ruled rows. a
-- row at light 2.4 is level 2 with ~40% of its strokes at 3; at 0.3 it is
-- ~30% of its strokes at level 1 and the rest dark. fixed, so the texture
-- never crawls: it changes only as the light does
local MASK = {}
for y = 0, 63 do
  local m, x, k = {}, 0, 0
  while x < 128 do
    k = k + 1
    local len = 3 + math.floor(11 * hash(y * 61 + k, 91))
    local x1 = math.min(128, x + len)
    local blot = 0.5 + 0.27 * math.sin(x * 0.13 + y * 0.71) + 0.23 * math.sin(x * 0.047 - y * 0.29 + 1.7)
    m[#m + 1], m[#m + 2], m[#m + 3] = x, x1, clamp(0.08 + 0.84 * (0.55 * hash(y * 977 + k, 92) + 0.45 * blot), 0.04, 0.96)
    x = x1
  end
  MASK[y] = m
end
-- where each column's stroke starts in its row's list
local SEGAT = {}
for y = 0, 63 do
  local m, at = MASK[y], {}
  for i = 1, #m, 3 do
    for x = m[i], m[i + 1] - 1 do at[x] = i end
  end
  SEGAT[y] = at
end

-- the open runs of a row above a profile, worked out once per profile
local OPEN = setmetatable({}, {__mode = "k"})
local function open_runs(prof, y)
  local P = OPEN[prof]
  if not P then P = {}; OPEN[prof] = P end
  local r = P[y]
  if r then return r end
  r = {}
  local run
  for c = 0, 64 do
    if c < 64 and y < prof[c] then
      run = run or c * 2
    elseif run then
      r[#r + 1], r[#r + 2] = run, c * 2; run = nil
    end
  end
  P[y] = r
  return r
end
local ALL = {0, 128}

-- one row of light v (0..~7, fractional) by the hand-made dither, between
-- x0 and x1, above the profile when one is given
local function dither_row(v, y, prof, x0, x1)
  if not (v > 0.05) or y < 0 or y > 63 then return end
  x0, x1 = x0 or 0, x1 or 128
  local base = math.floor(v)
  local fr = v - base
  y = y // 1
  local m, at = MASK[y], SEGAT[y]
  local runs = prof and open_runs(prof, y) or ALL
  local nm = #m
  for r = 1, #runs, 2 do
    local a, b = runs[r], runs[r + 1]
    if x0 > a then a = x0 end
    if x1 < b then b = x1 end
    a, b = a // 1, b // 1
    if b > a then
      local rl, rx = -1, a
      local i = at[a]
      while i and i <= nm and m[i] < b do
        local l = base + (fr > m[i + 2] and 1 or 0)
        if l ~= rl then
          local sx = m[i] > a and m[i] or a
          if rl > 0 and sx > rx then put(rl, rx, y, sx - rx, 1) end
          rl, rx = l, sx
        end
        i = i + 3
      end
      if rl > 0 and b > rx then put(rl, rx, y, b - rx, 1) end
    end
  end
end

-- a vertical gradient: `lv(y)` is the light at row y (0..~6, fractional),
-- each row by the hand-made dither; above the profile only, when one is given
local function gradient(y0, y1, lv, prof, x0, x1)
  for y = y0, y1 do dither_row(lv(y), y, prof, x0, x1) end
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
-- and nudged by nudge(x, y) -> dx, dl (nil: none). each dash's length and
-- place wander a little (fixed to the dash, so they slide with it): drawn by
-- hand, not ruled
local function streaks(l, y, w, gap, off, keep, nudge, x0, x1)
  x0, x1 = x0 or 0, x1 or 128
  local k0 = math.floor(off / gap)
  if not (k0 > -1e9 and k0 < 1e9) then k0 = 0 end
  local s = x0 + (off % gap) - gap
  local i = -k0 + math.floor(y) * 131
  for x = s, x1 - 1, gap do
    local h = (((i * 2654435761) >> 7) & 0xffff) / 65536
    i = i + 1
    local ww = math.floor(w * (0.55 + 0.9 * h) + 0.5)
    local xx = x + math.floor((h - 0.5) * gap * 0.4)
    local mx = xx + ww * 0.5
    if ww >= 1 and mx >= x0 and mx < x1 and (not keep or keep(mx)) then
      local dx, dl = 0, 0
      if nudge then dx, dl = nudge(mx, y) end
      put(l + dl + h * 0.8 - 0.4, xx + dx, y, ww, 1)
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
-- (its depth and phase are worked out once a frame, in physics)
local HV_A, HV_P = 0.6, 0
local sin = math.sin
local function heave(x)
  return HV_A * sin(x * 0.045 + HV_P)
end

-- the faint moving surface: short dashes on staggered rows that ride the
-- current (nearer rows faster) and the heave. a dash shows where two slow
-- waves agree, so the pattern breathes rather than scrolls. `dens` (0..1,
-- optional) lets more of the dashes show: the rows and their spacing never
-- move with it, so a rising input thickens the surface rather than
-- re-laying it. each dash fades in and out with the waves (never a switch,
-- so a still surface never sparkles), and is twice as bright on a crest
local function surface(x0, y0, x1, y1, lvl, gap, dy, wlen, dens)
  local row = 0
  wlen = wlen or 2
  local thr = 0.35 - 0.8 * (dens or 0)
  for y = y0, y1 - 1, dy do
    local par = 0.6 + 0.8 * (y / 64)
    local o = drift_x * par + row * gap * 0.5
    local off = o % gap
    -- each dash rounds its level a little differently (fixed to the dash as
    -- it slides), so a slowly brightening surface brightens a few dashes at
    -- a time instead of all at once
    local k = -math.floor(o / gap) + row * 31
    if k ~= k or k > 1e9 or k < -1e9 then k = 0 end
    for x = x0 + off, x1 - 1, gap do
      local w = sin(x * 0.11 + y * 0.6 - T * 0.8) + 0.7 * sin(x * 0.043 - y * 0.27 + T * 0.37)
      if w > thr then
        local f = (w - thr) / 0.5
        if f > 1 then f = 1 else f = f * f * (3 - 2 * f) end
        local up = (w - 1) / 0.5
        if up < 0 then up = 0 elseif up > 1 then up = 1 end
        put((lvl * (1 + up) + (((k * 2654435761) >> 9) & 7) / 8 - 0.44) * f, x, y + heave(x) * 0.5, wlen, 1)
      end
      k = k + 1
    end
    row = row + 1
  end
end

-- a soft threshold: 0 below a, 1 above b, eased between (for anything that
-- would otherwise switch on as an input crosses a line)
local function ramp(v, a, b)
  local u = (v - a) / (b - a)
  if u <= 0 then return 0 elseif u >= 1 then return 1 end
  return u * u * (3 - 2 * u)
end

-- a dash at a fractional x: its end pixels take a share of the light, so a
-- slowly sliding dash glides instead of hopping a whole pixel at a time
local function dash(l, x, y, w, h)
  if not (x > -1e6 and x < 1e6) then return end
  w, h = w or 1, h or 1
  local xi = x // 1
  local f = x - xi
  if f < 0.12 then put(l, xi, y, w, h); return end
  if f > 0.88 then put(l, xi + 1, y, w, h); return end
  put(l * (1 - f), xi, y, 1, h)
  if w > 1 then put(l, xi + 1, y, w - 1, h) end
  put(l * f, xi + w, y, 1, h)
end

-- a row's light shared with the row below by f (0..1): one rect while it
-- sits on a row, two only while it is between them
local function vshare(l, x, y, w, f)
  if f < 0.06 then put(l, x, y, w, 1)
  elseif f > 0.94 then put(l, x, y + 1, w, 1)
  else put(l * (1 - f), x, y, w, 1); put(l * f, x, y + 1, w, 1) end
end

-- a soft point at a fractional place: its light shared between the pixels
-- it lies across, so a slowly drifting point never hops
local function dot(l, x, y)
  if not (x > -1e6 and x < 1e6 and y > -1e6 and y < 1e6) then return end
  local xi, yi = x // 1, y // 1
  local fx, fy = x - xi, y - yi
  local a, b = l * (1 - fx), l * fx
  put(a * (1 - fy), xi, yi, 1, 1); put(b * (1 - fy), xi + 1, yi, 1, 1)
  if fy > 0.12 then put(a * fy, xi, yi + 1, 1, 1); put(b * fy, xi + 1, yi + 1, 1, 1) end
end

-- how far inside the screen's sides x is, eased over m px (1 well inside,
-- 0 at the edge and beyond): for anything that wraps round
local function edge(x, m)
  m = m or 8
  local d = x < 64 and x + 1 or 128 - x
  return ramp(d, 0, m)
end

-- glitter: out_hi spawns short-lived points where `sample(u, v)` says the
-- surface is; each rises and fades on a sine, never a flash
local function glitter(sample, rate)
  glint_acc = glint_acc + A[HI] * (rate or 22) * DTS
  while glint_acc >= 1 do
    glint_acc = glint_acc - 1
    if #glints < GLINT_MAX then
      local x, y = sample(grnd(), grnd())
      if x then glints[#glints + 1] = {x = x, y = y, t0 = T, life = 0.4 + 0.5 * grnd(), pk = 4.5 + 3 * grnd()} end
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
      -- (its halo grows with it: nothing switches on as it brightens)
      local hl = (lv - 2.5) * 0.4
      if hl >= 0.5 then put(hl, g.x - 1, g.y, 1, 1); put(hl, g.x + 1, g.y, 1, 1) end
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
-- copy a chord's numbers into t (at most 4)
local function chord_into(t, src)
  for i = 4, 1, -1 do t[i] = nil end
  if type(src) ~= "table" then return end
  local n = 0
  for i = 1, 4 do
    local m = tonumber(src[i])
    if m and m == m and m > -1e6 and m < 1e6 then n = n + 1; t[n] = m end
  end
end

-- chord tone i as it glides from the last chord: its midi, and how present
-- it is (a tone that is new or gone fades rather than appears)
local function chord_at(i)
  local a, b = ch_prev[i], ch_now[i]
  local u = K.chord_mix or 1
  local pa = ch_prev_p[i] or 1
  if a and b then return a + (b - a) * u, pa + (1 - pa) * u end
  if b then return b, u end
  if a then return a, pa * (1 - u) end
  return nil, 0
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
  -- the breath: up over ~0.5 s, down over ~1.5 s, never a step
  -- (two followers in a row: it starts rising gently, never with a step)
  breath_mid = follow(breath_mid, breath_kick, 0.22, DT)
  breath = follow(breath, breath_mid, 0.25, DT)
  breath_kick = breath_kick * math.exp(-DT / 1.7)
  moment_age = moment_age + DT
  HV_A, HV_P = 0.6 + 2.6 * A[LO], -T * 0.55 + 0.8 * math.sin(T * 0.07)
  ch_age = ch_age + DT
  ch_glow_mid = follow(ch_glow_mid, ch_kick, 0.35, DT)
  ch_glow = follow(ch_glow, ch_glow_mid, 0.4, DT)
  ch_kick = ch_kick * math.exp(-DT / 1.6)
  if #ch_now == 0 and type(S.chord) == "table" then chord_into(ch_now, S.chord) end
  -- where the step clock is between steps (0..1), for smooth phases
  local step = tonumber(S.step) or 0
  if step ~= step_seen then step_seen, step_t = step, NOW end
end

-- incidents: one at a time, a minute or two apart, each eased in and out
local INC_RAMP = 3
local function incident_gap(first)
  if first then return 25 + 35 * irnd() end
  return 50 + 70 * irnd()
end
-- (the first one waits too, whether or not VIS.init is ever called)
inc_next = incident_gap(true)

local function incident_start(th, k)
  local list = th and th.incidents
  if not list or not list[k] then return end
  local d = tonumber(list[k][2]) or 12
  inc = {k = k, name = list[k][1], t0 = T, dur = d * (0.85 + 0.3 * irnd()), s = irnd(), s2 = irnd(),
    u = 0, e = 0, age = 0}
  inc_last = k
end

local function incidents(th)
  local list = th and th.incidents
  if not list or #list == 0 then inc = nil; return end
  if inc then
    local age = T - inc.t0
    if age >= inc.dur then
      inc = nil
      inc_next = T + incident_gap()
    else
      local r = math.min(INC_RAMP, inc.dur / 3)
      inc.age, inc.u = age, age / inc.dur
      inc.e = ease(age / r) * ease((inc.dur - age) / r)
    end
  elseif T >= inc_next then
    local k = 1 + math.floor(irnd() * #list)
    if #list > 1 and k == inc_last then k = k % #list + 1 end
    incident_start(th, k)
  end
end

-- the read-only view of the water the themes see this frame
local function sync(S)
  K.T, K.NOW, K.DT, K.DTS, K.SP = T, NOW, DT, DTS, SP
  K.energy, K.flow_k, K.cur_u, K.drift_x = energy, flow_k, cur_u, drift_x
  K.bloom, K.tide_dir = bloom_s, tide_dir
  K.sw_state, K.sw_level, K.sw_disp = sw_state, clamp(tonumber(sw_level) or 0, 0, 1), sw_disp
  K.bar_pulse, K.moment_age, K.bar_t, K.bar_len = bar_pulse, moment_age, bar_t, bar_len
  K.breath = breath
  K.chord_age, K.chord_mix = ch_age, ease(ch_age / 3)
  K.chord_glow = math.min(1, ch_glow * 2)
  K.inc = inc
  K.S = S
end

K.clamp, K.ease, K.follow, K.rnd, K.hash, K.px, K.opt = clamp, ease, follow, rnd, hash, px, opt
K.cx, K.pu, K.chord_at, K.chord_now, K.chord_prev = cx, pu, chord_at, ch_now, ch_prev
K.chord_prev_p = ch_prev_p
K.put, K.profile, K.mass, K.row_above, K.gradient, K.dashes = put, profile, mass, row_above, gradient, dashes
K.streaks, K.at, K.crowns = streaks, at, crowns
K.bake, K.blit, K.dither_row = bake, blit, dither_row
K.flow, K.heave, K.surface, K.glitter = flow, heave, surface, glitter
K.ramp, K.dash, K.dot, K.edge, K.vshare = ramp, dash, dot, edge, vshare
K.substep, K.sounding, K.motif, K.phase, K.chord = substep, sounding, motif, phase, chord
K.echo = function() return clamp(opt("echo_fb", 0.45), 0, 0.85), opt("echo_div", 3) end

-- small shapes several places share
-- an ellipse of points: centre, radius, vertical squash, level, at most n points
function K.ring(x, y, rad, sq, lv, n, a0, ylo, yhi)
  if not (rad >= 0.5) or not (lv >= 0.5) then return end
  n = n or math.max(6, math.floor(rad * 2.2))
  a0 = a0 or 0
  ylo, yhi = ylo or -1, yhi or 64
  for k = 0, n - 1 do
    local a = a0 + k / n * TAU
    local yy = y + math.sin(a) * rad * sq
    if yy > ylo and yy < yhi then put(lv, x + math.cos(a) * rad, yy, 1, 1) end
  end
end

-- a bird in flight seen from afar: a body and two wings that beat
-- (flap -1..1); size 1 small, 2 large (a heron, a gull)
function K.bird(x, y, lv, flap, size)
  local w = flap > 0.3 and -1 or (flap < -0.3 and 1 or 0)
  if (size or 1) >= 2 then
    -- broad slow wings, two rows deep at the shoulder
    put(lv, x - 2, y, 5, 1)
    put(lv * 0.9, x - 6, y + w, 5, 1); put(lv * 0.9, x + 2, y + w, 5, 1)
    put(lv * 0.7, x - 5, y + w + 1, 3, 1); put(lv * 0.7, x + 3, y + w + 1, 3, 1)
    put(lv * 0.6, x - 9, y + 2 * w, 3, 1); put(lv * 0.6, x + 7, y + 2 * w, 3, 1)
  else
    put(lv, x, y, 1, 1)
    put(lv * 0.8, x - 1, y + w, 1, 1); put(lv * 0.8, x + 1, y + w, 1, 1)
    put(lv * 0.6, x - 2, y + w, 1, 1); put(lv * 0.6, x + 2, y + w, 1, 1)
  end
end

-- a fixed level jitter (-0.42..0.42) for element k: added to the level of
-- each of many same-level rects, a slowly rising light (the breath, the
-- bloom) brightens them a few at a time instead of all in one frame
local BJ = {}
for k = 0, 255 do BJ[k] = (((k * 2654435761) >> 9) & 15) / 16 * 0.84 - 0.42 end
local function bj(k)
  if not (k > -1e9 and k < 1e9) then return 0 end      -- also NaN, nil-safe callers only
  return BJ[(k // 1 | 0) & 255]
end
K.bj = bj

-- a horizontal line cut into `seg`-px pieces, each with its own jitter
function K.hline(l, y, x0, x1, seg)
  seg = seg or 8
  local yk = math.floor(y) * 131
  for x = x0, x1 - 1, seg do put(l + bj(x + yk), x, y, math.min(seg, x1 - x), 1) end
end

-- capped lists of marks (rings, drops, lights): add an item; when the list
-- already holds `max` live items, the oldest starts fading out (eased, over
-- 0.3 s) instead of being cut while it is still bright
local CAP_FADE = 0.3
function K.cap_add(list, item, max)
  local live, first = 0, nil
  for i = 1, #list do
    if not list[i].gone then live = live + 1; first = first or list[i] end
  end
  if live >= max and first then first.gone = T end
  list[#list + 1] = item
  -- (a hard ceiling, reached only if marks arrive faster than they can fade)
  while #list > max + 8 do table.remove(list, 1) end
end
-- how much of a capped item is still there (1 .. 0), and whether it is gone
-- (dur: the fade, 0.3 s unless given)
function K.cap_fade(item, dur)
  local g = item.gone
  if not g then return 1, false end
  local u = (T - g) / (dur or CAP_FADE)
  return 1 - ease(u), u >= 1
end

-- fine glints at fixed points (pts: flat {x, y, ...}), each twinkling on
-- its own slow phase, as bright as amt (0..1) allows: out_hi's shimmer
function K.twinkle(pts, amt, lv)
  if not (amt > 0.02) then return end
  lv = (lv or 5) * amt
  local t = T * 2.3
  for i = 1, #pts, 2 do
    local w = sin(t + i * 1.37) * sin(t * 0.61 + i * 0.71)
    -- (rising from nothing as the phase comes round: never a switch)
    if w > 0.2 then put(lv * (w - 0.2) * 1.25, pts[i], pts[i + 1], 2, 1) end
  end
end

-- a fixed scatter of n points in a box, for K.twinkle
function K.scatter(n, x0, y0, x1, y1, salt)
  local p = {}
  for k = 1, n do
    p[#p + 1] = math.floor(x0 + (x1 - x0) * hash(k, salt or 97))
    p[#p + 1] = math.floor(y0 + (y1 - y0) * hash(k, (salt or 97) + 1))
  end
  return p
end

sync({})

-- the themes, each in its own file (include, not require: norns resolves it
-- against the script's folder); a name with a space lives in a file with
-- an underscore ("echo bridge" -> lib/vis/echo_bridge.lua)
for i, name in ipairs(VIS.names) do
  THEMES[i] = include("lib/vis/" .. (name:gsub(" ", "_")))(K)
end

------------------------------------------------------------------------
-- dispatch
------------------------------------------------------------------------

local function clear_theme(i)
  local th = THEMES[i]
  if th and th.clear then th.clear() end
  inc, inc_last = nil, 0
  inc_next = T + incident_gap(true)
end

function VIS.init()
  for i = #glints, 1, -1 do glints[i] = nil end
  for i = #hist, 1, -1 do hist[i] = nil end
  for k in pairs(slot_last) do slot_last[k] = nil end
  glint_acc = 0
  for s = 1, 4 do slot_kick[s], slot_flash[s], slot_glow[s] = 0, 0, 0 end
  sw_state, sw_level, sw_disp, bar_kick, bar_pulse = "idle", 0, 0, 0, 0
  breath, breath_mid, breath_kick = 0, 0, 0
  chord_into(ch_now, nil); chord_into(ch_prev, nil)
  for i = 1, 4 do ch_prev_p[i] = nil end
  ch_age = 999
  ch_glow, ch_glow_mid, ch_kick = 0, 0, 0
  moment_age = 999
  step_seen, step_t, bar_t, bar_len = -1, 0, 0, 3.3
  for k = 1, 5 do raw[k], A[k] = 0, 0 end
  energy, flow_k, cur_u, drift_x, bloom_s, tide_dir = 0, 1.2, 0, 0, 0, 0
  bloom_seen = false
  T, NOW, last_clock = 0, 0, nil
  cur, xf = nil, 0
  rseed, gseed, iseed = 1, 7, 3
  inc, inc_last = nil, 0
  inc_next = incident_gap(true)
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
    local m = tonumber(b)
    if m and m == m then slot_last[slot] = m end
    if th and th.note then th.note(slot, m or slot_last[slot] or 60, c) end
  elseif kind == "bar" then
    bar_kick = 1
    breath_kick = 1
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
    if type(a) == "table" then
      -- the last chord as it stands now (mid-glide), each tone in its place
      -- and as present as it was, so a tone still fading in or out carries
      -- on from where it is; then the new one
      local was, wp = {}, {}
      for i = 1, 4 do
        local m, p = chord_at(i)
        if m and p > 0 then was[i], wp[i] = m, p end
      end
      for i = 1, 4 do ch_prev[i], ch_prev_p[i] = was[i], wp[i] end
      chord_into(ch_now, a.chord)
      ch_age = 0
      ch_kick = 1
      K.chord_mix = 0
      if th and th.chord then th.chord(a) end
    end
  end
end

-- test hooks: what incident is on screen (and which kinds the theme has),
-- and a way to start one now (contact sheets, tests)
function VIS._probe()
  local th = THEMES[cur or 1]
  local kinds = {}
  for i, d in ipairs(th and th.incidents or {}) do kinds[i] = d[1] end
  return {incident = inc and inc.name, env = inc and inc.e or 0, active = inc and 1 or 0, kinds = kinds}
end
function VIS._incident(k) incident_start(THEMES[cur or 1], k) end

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
    xf = xf - DT / 0.6
    if xf <= 0 then
      clear_theme(cur)
      for k = #glints, 1, -1 do glints[k] = nil end
      xf, cur = 0, i
    end
  else
    -- (the new place comes up a little slower than the old one went:
    -- even the busiest scene never brightens by much in one frame)
    xf = math.min(1, xf + DT / 0.8)
  end
  incidents(THEMES[cur])
  B = opt("vis_brightness", 10) / 10 * ease(xf)
  FJ = xf < 1 and 0.9 * (1 - ease(xf)) or 0
  sync(S)
  THEMES[cur].draw(S)
  flush()
end

return VIS
