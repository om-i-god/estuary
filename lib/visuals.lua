-- estuary / visuals
-- six quiet themes for the 128x64 OLED, drawn from what the music is doing
-- and from what the engine hears of itself. sparse on purpose: soft greys,
-- a lot of black, nothing that flashes the whole screen.
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
--   ripples    each note drops a ring where its pitch is, in its slot's band;
--              rings drift with the current and glow softly where they cross.
--              echoes follow at the echo time. ring brightness rides out_amp,
--              so a reverb tail keeps the surface alive
--   horizon    a layered waterline whose height and roughness follow out_lo
--              and the water level; the chord voices as bands under it,
--              refracted by the same wave, the top one reflected in a
--              shimmering path. the sky brightens with the bloom
--   postcards  four small windows onto the same estuary from four spots:
--              water and horizon in each, lit by that slot's recent notes
--   rain       notes fall as drops from their pitch, slanted by the wind;
--              drizzle as out_hi; the ground is water and drops ring it
--   tide       the last ~80 bars of bloom as a shoreline; at the live edge
--              waves wash up the sand and draw back, as far as the sound
--              carries them; a swell floods the beach
--   drift      each motif a point circling its eddy at its own cycle length,
--              trailing; eddies wobble with out_lo and precess with the
--              current; a shimmering line joins two points in phase

local VIS = {}

VIS.names = {"ripples", "horizon", "postcards", "rain", "tide", "drift"}

local FPS = 20
local TAU = 2 * math.pi
local ECHO_BEATS = {0.5, 1, 1.5, 2}     -- same order as the echo time param

-- state (declared before any function that uses it)
local last_S                            -- conductor state as of the last frame
local B = 1                             -- brightness scale for this frame
local SP = 1                            -- speed scale (1 at the default 3)
local T = 0                             -- motion time, s (scaled by speed)
local NOW = 0                           -- real time since init, s
local DT, DTS = 1 / FPS, 1 / FPS        -- this frame's real / motion step
local last_clock                        -- util.time() at the last frame
local cur, xf = nil, 0                  -- theme on screen, its fade (0..1)

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

-- per-theme animation state
local rings, pending = {}, {}
local drops, splashes, drizzle = {}, {}, {}
local glints, glint_acc = {}, 0
local foam = {}                         -- tide: this frame's foam front
local card_wl = {0, 0, 0, 0}            -- postcards: each window's water line
local hz_line = 40                      -- horizon: this frame's waterline
local rseed = 1                         -- the visuals' own dice

local RING_MAX, RING_R = 16, 28
local DROP_MAX, SPLASH_MAX, DRIZZLE_MAX, GLINT_MAX = 28, 14, 30, 14

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
local function surface(x0, y0, x1, y1, lvl, gap, dy)
  local row = 0
  for y = y0, y1 - 1, dy do
    local par = 0.6 + 0.8 * (y / 64)
    local off = (drift_x * par + row * gap * 0.5) % gap
    for x = x0 + off, x1 - 1, gap do
      local w = math.sin(x * 0.11 + y * 0.6 - T * 0.8) + 0.7 * math.sin(x * 0.043 - y * 0.27 + T * 0.37)
      if w > 0.35 then put(lvl * (w > 1.2 and 2 or 1), x, y + heave(x) * 0.5, 2, 1) end
    end
    row = row + 1
  end
end

-- glitter: out_hi spawns short-lived points where `sample(u, v)` says the
-- surface is; each rises and fades on a sine, never a flash
local function glitter(sample)
  glint_acc = glint_acc + A[HI] * 22 * DTS
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

------------------------------------------------------------------------
-- ripples
------------------------------------------------------------------------

local function slot_y(slot) return 10 + (slot - 1) * 14 end

local function add_ring(x, y, lvl)
  rings[#rings + 1] = {x = x, y = y, t0 = T, lvl = lvl, a0 = rnd() * TAU, rad = 0, lv = 0}
  if #rings > RING_MAX then table.remove(rings, 1) end
end

local function on_note_ripples(slot, midi)
  local x, y = px(midi), slot_y(slot)
  add_ring(x, y, 1)
  -- echoes: one every echo time, each the feedback quieter; they land where
  -- the current has carried the spot by then
  local fb = clamp(opt("echo_fb", 0.45), 0, 0.85)
  local tempo = last_S and tonumber(last_S.tempo) or 72
  local beat = 60 / clamp(tempo, 20, 300)
  local delay = (ECHO_BEATS[opt("echo_div", 3)] or 1.5) * beat
  local lvl = fb
  local k = 1
  while lvl > 0.2 and k <= 3 do
    pending[#pending + 1] = {at = NOW + k * delay, x = x, y = y, lvl = lvl}
    lvl = lvl * fb
    k = k + 1
  end
  while #pending > 24 do table.remove(pending, 1) end
end

local function sample_ripples(u, v) return u * 127, 2 + v * 60 end

local function draw_ripples(S)
  surface(0, 3, 128, 63, 1, 9, 6)
  -- a sounding motif's band glints faintly along its row
  for s = 1, 4 do
    if sounding(S, s) then
      local y = slot_y(s)
      for x = drift_x % 8, 127, 8 do put(2, x, y + heave(x) * 0.35, 1, 1) end
    end
  end
  for i = #pending, 1, -1 do
    local p = pending[i]
    local u, v = flow(p.x, p.y)
    p.x, p.y = p.x + u * DTS, p.y + v * DTS * 0.42
    if NOW >= p.at then
      add_ring(p.x, p.y, p.lvl)
      table.remove(pending, i)
    end
  end
  -- rings drift with the current; brightness rides the output level
  local amp = 0.55 + 0.65 * A[AMP]
  local live, nl = {}, 0
  for i = #rings, 1, -1 do
    local r = rings[i]
    local age = T - r.t0
    local rad = age * 8.5
    local life = rad / RING_R
    if life >= 1 or r.x < -RING_R or r.x > 128 + RING_R then
      table.remove(rings, i)
    else
      local u, v = flow(r.x, r.y)
      r.x, r.y = r.x + u * DTS, r.y + v * DTS * 0.42
      local lv = 8 * r.lvl * (1 - life) ^ 1.4 * amp * ease(age / 0.18)
      r.rad, r.lv = rad, lv
      if lv >= 0.5 and rad >= 1 then
        local ry = rad * 0.42
        local n = math.max(6, math.floor(TAU * rad * 0.4))
        for k = 0, n - 1 do
          local a = r.a0 + k / n * TAU
          local x = r.x + math.cos(a) * rad
          local y = r.y + math.sin(a) * ry + heave(x) * 0.35
          if x >= 0 and x < 128 and y >= 0 and y < 64 then put(lv, x, y, 1, 1) end
        end
        nl = nl + 1
        live[nl] = r
      end
    end
  end
  -- where two rings cross (circles once the 0.42 squash is undone), the
  -- crossing glows softly
  local glows = 0
  for i = 1, nl - 1 do
    local a = live[i]
    for j = i + 1, nl do
      local b = live[j]
      local dx, dy = b.x - a.x, (b.y - a.y) / 0.42
      local d2 = dx * dx + dy * dy
      local d = math.sqrt(d2)
      if glows < 24 and d > 0.5 and d < a.rad + b.rad and d > math.abs(a.rad - b.rad) then
        local l = (a.rad * a.rad - b.rad * b.rad + d2) / (2 * d)
        local h = math.sqrt(math.max(0, a.rad * a.rad - l * l))
        local mx, my = a.x + dx * l / d, a.y / 0.42 + dy * l / d
        local lv = math.min(a.lv, b.lv) * 0.8 + 1
        for sgn = -1, 1, 2 do
          local x, y = mx + sgn * dy * h / d, (my - sgn * dx * h / d) * 0.42
          y = y + heave(x) * 0.35
          if x >= 0 and x < 127 and y >= 0 and y < 64 then put(lv, x, y, 2, 1); glows = glows + 1 end
        end
      end
    end
  end
  glitter(sample_ripples)
end

------------------------------------------------------------------------
-- horizon
------------------------------------------------------------------------

local STARS = {{9, 5}, {30, 11}, {47, 3}, {71, 8}, {92, 4}, {108, 12}, {120, 6}, {18, 17}, {84, 15}}

-- the layered wave: a long swell (out_lo), a chop and a ripple (the water
-- level, out of the nature bus)
local function hz_wave(x)
  return (0.5 + 2.2 * A[LO]) * math.sin(x * 0.05 - T * 0.5 + drift_x * 0.02)
    + (0.3 + 1.1 * A[NAT]) * math.sin(x * 0.16 + T * 1.1)
    + (0.15 + 0.6 * A[NAT]) * math.sin(x * 0.39 - T * 1.9)
end

local function sample_horizon(u, v) return u * 127, hz_line + 3 + v * (60 - hz_line) end

local function draw_horizon(S)
  local yw = 40 - sw_disp * 14 - A[LO] * 1.5 - A[NAT] * 2.5
  hz_line = yw
  -- sky: a few far lights and a low haze, brighter as the bloom opens
  local sky = 0.5 + 0.9 * bloom_s
  for i, s in ipairs(STARS) do
    if s[2] < yw - 5 then put(sky * (1.2 + 0.8 * math.sin(T * 0.6 + i * 2.1)), s[1], s[2], 1, 1) end
  end
  for r = 1, 2 do
    local y = yw - 3 - r * 3
    for x = (r * 3 + drift_x * 0.3) % 6, 127, 6 do put(sky * (1.15 - r * 0.3), x, y + hz_wave(x) * 0.15, 1, 1) end
  end
  -- a passing moment: a small mark crossing the sky
  local mdur = 13.2
  if moment_age < mdur then
    local f = moment_age / mdur
    local x = 10 + f * 108
    local y = 10 + math.sin(f * 6) * 3
    local lv = 5 * math.sin(f * math.pi)
    put(lv, x, y, 1, 1); put(lv, x + 1, y - 1, 1, 1); put(lv, x + 2, y, 1, 1)
    put(lv, x - 1, y - 1, 1, 1)
  end
  -- the back swell: only its crests show, just above the line
  for x = 0, 126, 3 do
    local w2 = math.sin(x * 0.09 - T * 0.8 + 2 + drift_x * 0.03)
    if w2 > 0.4 then put(1 + w2 * (1 + A[LO]), x, yw - 2 + hz_wave(x) * 0.5, 3, 1) end
  end
  -- the waterline: crests brighter
  for x = 0, 126, 2 do
    local w = hz_wave(x)
    local sparkle = A[HI] * 2.5 * math.max(0, math.sin(x * 1.1 - T * 6))
    put(3 + clamp(-w * 0.6, -1, 1.5) + bar_pulse * 2 + sparkle, x, yw + w, 2, 1)
  end
  -- chord voices: soft bands under the line, lower notes deeper, refracted
  -- by the same wave
  local c = type(S.chord) == "table" and S.chord or {}
  local pad = type(S.gain) == "table" and tonumber(S.gain.pad) or 0.5
  local base = 3 + clamp(pad, 0, 1) * 3
  local top_y, top_cx, low_y
  for i = 1, 4 do
    local m = tonumber(c[i])
    if m then
      local y = clamp(yw + 4 + (84 - m) * 0.32 + i * 0.5, yw + 3, 61)
      local cx = 64 + (i - 2.5) * 15 + math.sin(T * 0.25 + i * 1.7) * 5
      local w = 22 + i * 4 + sw_disp * 8
      for x = 0, 126, 2 do
        local d = (x - cx) / w
        local v = math.exp(-d * d)
        if v > 0.12 then
          local sh = 0.75 + 0.25 * math.sin(T * 0.8 + x * 0.1 + i * 2)
          put((base + 1) * v * sh + bar_pulse * v, x, y + hz_wave(x + i * 9) * 0.6, 2, 2)
        end
      end
      if not top_y or y < top_y then top_y, top_cx = y, cx end
      if not low_y or y > low_y then low_y = y end
    end
  end
  -- the top band's reflection: a broken path of glints down the water
  -- below the bands, shimmering with out_hi
  if top_y then
    local hi = A[HI]
    for yy = math.floor(low_y) + 4, 62, 2 do
      local fl = 0.5 + 0.5 * math.sin(T * (3 + 5 * hi) + yy * 1.9) * math.sin(T * 1.3 + yy * 0.7)
      if fl > 0.35 then
        local wd = 1 + math.floor((1 + 4 * hi) * fl + 0.5)
        put((1 + 3.5 * hi) * fl, top_cx + hz_wave(yy * 3) * 1.5 + math.sin(yy * 2.3 + T) * 2 - wd / 2, yy, wd, 1)
      end
    end
  end
  glitter(sample_horizon)
end

------------------------------------------------------------------------
-- postcards
------------------------------------------------------------------------

local CARD_W, CARD_H, CARD_Y = 26, 24, 13
local SPOT = {0, 37, 74, 111}           -- where along the water each window looks

local function sample_postcards(u, v)
  local i = math.floor(u * 4) + 1
  return 6 + (i - 1) * 31 + 2 + v * (CARD_W - 5), card_wl[i]
end

local function draw_postcards(S)
  local sub = substep(S)
  local step = tonumber(S.step) or 0
  local chop = 0.7 + 0.8 * energy + 0.5 * A[NAT]
  for i = 1, 4 do
    local x0, y0 = 6 + (i - 1) * 31, CARD_Y
    local m = motif(S, i)
    local on = sounding(S, i)
    local f, glow = slot_flash[i], slot_glow[i]
    -- the frame
    local edge = (on and 3 or 2) + f * 5
    put(edge, x0, y0, CARD_W, 1)
    put(edge, x0, y0 + CARD_H - 1, CARD_W, 1)
    put(edge, x0, y0, 1, CARD_H)
    put(edge, x0 + CARD_W - 1, y0, 1, CARD_H)
    -- the water in this window: the shared heave at this spot, raised by a
    -- swell, with chop from the sound and the water level
    local sp = SPOT[i]
    local wl = y0 + 14 - sw_disp * 4 + heave(sp + 13) * 0.7
    card_wl[i] = wl
    local lm = slot_last[i]
    local u = lm and clamp((lm - 55) / 36, 0, 1)
    local sx = u and (x0 + 4 + u * 17)
    local lit = glow * 0.8 + f
    for c = 0, 11 do
      local xx = x0 + 1 + c * 2
      local vx = sp + c * 2
      local y = wl + chop * math.sin(vx * 0.33 - T * 1.5 + drift_x * 0.15) + 0.4 * math.sin(vx * 0.12 + T * 0.6)
      y = clamp(y, y0 + 3, y0 + CARD_H - 3)
      local near = sx and math.max(0, 1 - math.abs(xx - sx) / 6) or 0
      local sparkle = A[HI] * 2.5 * math.max(0, math.sin(vx * 1.3 + T * 8))
      put((on and 3 or 1) + near * lit * 5 + sparkle, xx, y, 2, 1)
    end
    for r = 1, 2 do
      local yy = math.floor(wl + 2 + r * 3)
      if yy < y0 + CARD_H - 1 then
        local off = (drift_x * (0.8 + 0.4 * r) + sp) % 8
        for xx = x0 + 1 + off, x0 + CARD_W - 4, 8 do put(on and 1.5 or 1, xx, yy, 2, 1) end
      end
    end
    -- the light: the slot's last note hangs in this window's sky at its
    -- pitch, its path on the water below
    if sx and lit > 0.04 then
      local sy = y0 + 3 + (1 - u) * math.max(1, wl - y0 - 7)
      put(2 + lit * 6, sx, sy, 2, 2)
      for yy = math.floor(wl) + 2, y0 + CARD_H - 3, 2 do
        local fl = 0.5 + 0.5 * math.sin(T * 4 + yy * 1.7 + i)
        local w = 1 + math.floor(fl * 2.5 + A[HI] * 2)
        put(lit * 4 * fl, sx + 1 - w / 2, yy, w, 1)
      end
    end
    -- caption: where the motif is in its cycle
    local capy = y0 + CARD_H + 3
    put(on and 2 or 1, x0 + 1, capy, CARD_W - 2, 1)
    if on and m then
      local ph = ((step + sub) % m.cycle) / m.cycle
      put(6, x0 + 1 + ph * (CARD_W - 3), capy - 1, 1, 3)
    end
  end
  glitter(sample_postcards)
end

------------------------------------------------------------------------
-- rain
------------------------------------------------------------------------

local GROUND = 54

-- the water the rain falls into
local function surf_y(x)
  return GROUND + heave(x) * 0.8 + 0.5 * math.sin(x * 0.27 - T * 1.3 + drift_x * 0.05)
end

local function wind(x, y)
  local u = flow(x, y)
  return u * 0.6
end

local function on_note_rain(slot, midi, dur)
  local v = clamp(36 / ((tonumber(dur) or 0.5) + 0.5), 10, 50)          -- px/s
  drops[#drops + 1] = {x = px(midi), y = -1, v = v, t0 = T, lvl = 11 - (slot - 1) * 1.5}
  if #drops > DROP_MAX then table.remove(drops, 1) end
end

local function add_splash(x, lvl)
  splashes[#splashes + 1] = {x = x, t0 = T, lvl = lvl}
  if #splashes > SPLASH_MAX then table.remove(splashes, 1) end
end

local function sample_rain(u) local x = u * 127; return x, surf_y(x) - 1 end

local function draw_rain()
  -- the water: a surface line, crests brighter, and faint rows beneath
  for x = 0, 126, 2 do
    local y = surf_y(x)
    put(2 + (math.sin(x * 0.27 - T * 1.3 + drift_x * 0.05) > 0.6 and 1 or 0), x, y, 2, 1)
  end
  surface(0, GROUND + 4, 128, 64, 1, 8, 3)
  -- drops, slanted by the wind, easing in at the top
  for i = #drops, 1, -1 do
    local d = drops[i]
    local wx = wind(d.x, d.y)
    d.y = d.y + d.v * DTS
    d.x = clamp(d.x + wx * DTS, 1, 125)
    local sy = surf_y(d.x)
    if d.y >= sy then
      add_splash(d.x, d.lvl)
      table.remove(drops, i)
    else
      local lv = d.lvl * ease((T - d.t0) / 0.15)
      local slant = wx / d.v
      local tail = math.floor(d.v * 0.35) + 4
      put(lv, d.x, d.y, 2, 2)
      for k = 2, tail, 2 do put(lv * (1 - k / (tail + 1)) * 0.6, d.x - k * slant, d.y - k, 2, 2) end
    end
  end
  -- drizzle: as much as out_hi asks for, none at silence
  local want = A[HI] * 40 * DTS
  while want > 0 and #drizzle < DRIZZLE_MAX do
    if rnd() < want then drizzle[#drizzle + 1] = {x = rnd() * 127, y = rnd() * 24 - 4} end
    want = want - 1
  end
  for i = #drizzle, 1, -1 do
    local d = drizzle[i]
    local wx = wind(d.x, d.y)
    d.y = d.y + 75 * DTS
    d.x = (d.x + wx * DTS) % 128
    if d.y >= surf_y(d.x) then
      table.remove(drizzle, i)
    else
      put(1 + A[HI] * 1.5, d.x, d.y, 1, 2)
    end
  end
  -- each drop rings the water
  for i = #splashes, 1, -1 do
    local s = splashes[i]
    local age = T - s.t0
    local life = age / 0.9
    if life >= 1 then
      table.remove(splashes, i)
    else
      local rad = 1 + age * 13
      local ry = rad * 0.28
      local y0 = surf_y(s.x)
      local lv = s.lvl * 0.6 * (1 - life) ^ 1.2
      local n = math.max(6, math.floor(rad * 1.4))
      for k = 0, n - 1 do
        local a = k / n * TAU
        put(lv, s.x + math.cos(a) * rad, y0 + math.sin(a) * ry, 1, 1)
      end
      if age < 0.2 then put(lv, s.x, y0 - 2 - age * 10, 1, 1) end
    end
  end
  glitter(sample_rain)
end

------------------------------------------------------------------------
-- tide
------------------------------------------------------------------------

local function shore_y(b) return 52 - b * 30 end

local live_pt = {bloom = 0, wet = 0}

-- the shoreline's bloom and wetness at a column: the live bloom at the right
-- edge, history to the left of it sliding along smoothly between bars, the
-- oldest value held beyond it
local function hist_at(x, scroll)
  local n = #hist
  local d = (127 - x) / (128 / HIST_N)            -- bars back from the edge
  local a, b, u
  if n == 0 then return live_pt.bloom, live_pt.wet end
  if d <= scroll then
    a, b, u = live_pt, hist[n], scroll > 0 and d / scroll or 0
  else
    local f = n - (d - scroll)
    if f <= 1 then return hist[1].bloom, hist[1].wet end
    local j = math.floor(f)
    a, b, u = hist[j], hist[j + 1] or hist[j], f - j
  end
  return a.bloom + (b.bloom - a.bloom) * u, a.wet + (b.wet - a.wet) * u
end

local function sample_tide(u)
  local n = #foam
  if n == 0 then return nil end
  local p = foam[math.floor(u * n) + 1]
  return p[1] + 1, p[2]
end

local function draw_tide(S)
  live_pt.bloom = bloom_s
  live_pt.wet = sw_state ~= "idle" and math.max(0.35, clamp(tonumber(sw_level) or 0, 0, 1)) or 0
  local scroll = clamp((NOW - bar_t) / bar_len, 0, 1)
  local nf = 0
  local cyc = T / 7.5 * TAU                        -- the waves' slow rhythm
  local reach0 = 4 + 8 * A[AMP] + 6 * A[NAT]
  for x = 0, 126, 2 do
    local bl, wet = hist_at(x, scroll)
    local edge = ease((x - 40) / 76)               -- 0 to the left .. 1 at the live edge
    local yl = shore_y(bl) + heave(x) * 0.3 + edge * math.sin(T * 1.1 + x * 0.3) * 0.6
    -- the sea above the line: a faint moving surface
    for yy = 3 + (x // 2) % 3, yl - 3, 5 do
      local w = math.sin(x * 0.11 + yy * 0.6 - T * 0.8 + drift_x * 0.11) + 0.7 * math.sin(x * 0.043 - yy * 0.27 + T * 0.37)
      if w > 0.6 then
        put((w > 1.3 and 2 or 1) + A[HI] * 2 * math.max(0, math.sin(x * 1.3 + yy * 2.1 + T * 8)), x, yy, 2, 1)
      end
    end
    -- waves wash up the sand and draw back, as far as the sound carries
    -- them; a swell floods the whole beach
    local ph = 0.5 - 0.5 * math.cos(cyc - x * 0.02)
    local reach = reach0 * ph * (0.8 + 0.2 * math.sin(x * 0.09 + T * 0.3)) * edge + sw_disp * 24
    local yf = math.min(62, yl + reach)
    put(7, x, yl, 2, 1)
    if wet > 0.02 then put(2 + wet * 3, x, yl - 1, 2, 1) end
    if reach > 1.5 then
      -- the sheet of water over the sand: sparse glossy dashes that slide
      for yy = math.floor(yl) + 2, yf - 2, 4 do
        local w = math.sin(x * 0.15 + yy * 0.5 - T * 1.2 + drift_x * 0.1)
          + 0.6 * math.sin(x * 0.07 - yy * 0.9 + T * 0.5)
        if w > 0.5 then put(w > 0.85 and 2 or 1, x, yy, 2, 1) end
      end
      -- the foam at the front, brighter as it runs up, glittering with out_hi
      local sparkle = A[HI] * 3 * math.max(0, math.sin(x * 1.7 + T * 9))
      put((math.sin(cyc - x * 0.02) > 0 and 5 or 3) + sparkle, x, yf, 2, 1)
      nf = nf + 1
      foam[nf] = foam[nf] or {}
      foam[nf][1], foam[nf][2] = x, yf
    end
    -- the sand below the reach: wet first, then sparse dry dashes
    local ys = math.max(yl, yf)
    if wet > 0.02 then
      -- (a flooded beach hides most of it)
      local deep = (2 + wet * 8) * (1 - 0.7 * sw_disp)
      for yy = math.floor(ys) + 1 + (x // 2) % 2, ys + 1 + deep, 2 do put(1 + wet * 2, x, yy, 2, 1) end
    end
    -- dry sand on fixed rows, so the beach stays put while the water moves
    for yy = 4 + ((x // 2) % 2) * 2, 62, 4 do
      if yy >= ys + 3 and (x // 2 + yy // 4) % 2 == 0 then put(1, x, yy, 2, 1) end
    end
  end
  for k = nf + 1, #foam do foam[k] = nil end
  glitter(sample_tide)
end

------------------------------------------------------------------------
-- drift
------------------------------------------------------------------------

local ORBIT_RY = {6, 12, 18, 24}

-- a point on eddy i at angle a: an ellipse that wobbles with out_lo, its
-- wobble carried round by the current, tilted a little back and forth
local function orbit_pt(i, a)
  local ry = ORBIT_RY[i]
  local rx = ry * 1.7
  local lo = A[LO]
  local dir = (i % 2 == 0) and 1 or -1
  local r = 1 + (0.03 + 0.11 * lo) * math.sin(3 * a + T * 0.8 + i + dir * drift_x * 0.02)
    + (0.02 + 0.05 * lo) * math.sin(2 * a - T * 0.45 + i * 2)
  local x, y = math.cos(a) * rx * r, math.sin(a) * ry * r
  local tl = 0.15 * math.sin(T * (0.05 + 0.01 * i) + drift_x * 0.01 * dir + i)
  local c, s = math.cos(tl), math.sin(tl)
  return 64 + x * c - y * s, 32 + x * s + y * c
end

local function sample_drift(u, v)
  return orbit_pt(math.floor(u * 4) + 1, v * TAU)
end

local function draw_drift(S)
  local sub = substep(S)
  local step = tonumber(S.step) or 0
  local pts, ph, np = {}, {}, 0
  for i = 1, 4 do
    for k = 0, 27 do
      local a = k / 28 * TAU
      local x, y = orbit_pt(i, a)
      local sh = math.sin(a * 2 - T * 0.7 + i)
      put(1 + (sh > 0.3 and 1 or 0) + A[HI] * 2.5 * math.max(0, math.sin(k * 2.3 + T * 7 + i)), x, y, 1, 1)
    end
    local m = motif(S, i)
    if m then
      local p = ((step + sub) % m.cycle) / m.cycle
      local a = p * TAU - math.pi / 2
      local x, y = orbit_pt(i, a)
      if sounding(S, i) then
        local lv = 6 + slot_flash[i] * 6
        -- a short fading trail behind it
        for k = 1, 6 do
          local tx, ty = orbit_pt(i, a - k * 0.07)
          put(lv * 0.5 * (1 - k / 7), tx, ty, 1, 1)
        end
        put(lv, x - 1, y - 1, 3, 3)
        put(lv * 0.5, x - 2, y, 5, 1)
        put(lv * 0.5, x, y - 2, 1, 5)
        np = np + 1
        pts[np], ph[np] = {x, y}, p
      else
        put(2, x, y, 1, 1)
      end
    end
  end
  put(3 + clamp(1 - moment_age / 3, 0, 1) * 6, 64, 32, 1, 1)
  -- a shimmering dotted line joins two points whose phases line up
  local hi = A[HI]
  for i = 1, np - 1 do
    for j = i + 1, np do
      local d = math.abs(ph[i] - ph[j])
      d = math.min(d, 1 - d)
      if d < 0.12 then
        local x0, y0, x1, y1 = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
        local n = math.max(2, math.floor(math.max(math.abs(x1 - x0), math.abs(y1 - y0)) / 2))
        local base = (1 - d / 0.12) * 6 * (0.8 + 0.5 * hi)
        for s = 1, n - 1 do
          local u = s / n
          local lv = base * (0.55 + 0.45 * math.sin(T * (5 + 4 * hi) + s * 0.9 + i * j))
          put(lv, x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, 1, 1)
        end
      end
    end
  end
  glitter(sample_drift)
end

------------------------------------------------------------------------
-- dispatch
------------------------------------------------------------------------

function VIS.init()
  rings, pending, drops, splashes, drizzle, glints, foam, hist = {}, {}, {}, {}, {}, {}, {}, {}
  glint_acc = 0
  slot_kick, slot_flash, slot_glow = {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}
  slot_last = {}
  sw_state, sw_level, sw_disp, bar_kick, bar_pulse = "idle", 0, 0, 0, 0
  moment_age = 999
  step_seen, step_t, bar_t, bar_len = -1, 0, 0, 3.3
  raw, A = {0, 0, 0, 0, 0}, {0, 0, 0, 0, 0}
  energy, flow_k, cur_u, drift_x, bloom_s, tide_dir = 0, 1.2, 0, 0, 0, 0
  bloom_seen = false
  T, NOW, last_clock = 0, 0, nil
  cur, xf = nil, 0
  rseed = 1
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
  if kind == "note" then
    local slot = clamp(math.floor(tonumber(a) or 1), 1, 4)
    slot_kick[slot] = 1
    slot_glow[slot] = math.min(1, slot_glow[slot] + 0.5)
    slot_last[slot] = tonumber(b) or slot_last[slot]
    if cur == 1 then on_note_ripples(slot, b) end
    if cur == 4 then on_note_rain(slot, b, c) end
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
  end
  -- "chord": the bands read S.chord every frame; nothing to keep
end

local DRAW = {draw_ripples, draw_horizon, draw_postcards, draw_rain, draw_tide, draw_drift}

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
  if not DRAW[i] or type(S) ~= "table" then return end
  DT = frame_dt(dt)
  SP = clamp(opt("vis_speed", 3) / 3, 0.1, 5)
  DTS = DT * SP
  NOW = NOW + DT
  T = T + DTS
  last_S = S
  physics(S)
  -- a theme switch: the old picture eases to black, the new one eases up
  if cur == nil then cur = i end
  if i ~= cur then
    xf = xf - DT / 0.3
    if xf <= 0 then
      xf, cur = 0, i
      rings, pending, drops, splashes, drizzle, glints = {}, {}, {}, {}, {}, {}
    end
  else
    xf = math.min(1, xf + DT / 0.6)
  end
  B = opt("vis_brightness", 10) / 10 * ease(xf)
  DRAW[cur](S)
  flush()
end

return VIS
