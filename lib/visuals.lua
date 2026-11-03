-- estuary / visuals
-- six quiet themes for the 128x64 OLED, drawn from what the music is doing:
-- the notes as they land, the chord voices, the four motif slots, the water
-- swells, the bloom's history, the motifs' cycle lengths. sparse on purpose:
-- soft greys, a lot of black, nothing that flashes the whole screen.
-- the script feeds events as they happen (VIS.event) and the conductor
-- state every frame (VIS.draw(theme, S)).
--
--   ripples    each note drops a ring where its pitch is, in its slot's band;
--              echoes follow at the echo time, fading by the feedback
--   horizon    the chord voices as soft bands under a waterline; the
--              waterline rises with a water swell
--   postcards  four small frames, one per motif slot; a frame lights when
--              its motif plays, an empty slot dims
--   rain       notes as drops sliding down from their pitch; long notes
--              fall slowly
--   tide       the last ~80 bars of bloom as a shoreline; swells leave wet sand
--   drift      each motif a point orbiting at its own cycle length; a line
--              joins two when their phases line up

local VIS = {}

VIS.names = {"ripples", "horizon", "postcards", "rain", "tide", "drift"}

local FPS = 20
local ECHO_BEATS = {0.5, 1, 1.5, 2}     -- same order as the echo time param

-- state (declared before any function that uses it)
local last_S                            -- conductor state as of the last frame
local frame = 0
local B = 1                             -- brightness scale for this frame
local SP = 1                            -- speed scale (1 at the default 3)

-- shared by every theme, built from events whatever is on screen so a theme
-- switch has history to show at once
local recent = {}                       -- last notes: {slot, midi, dur, f}
local slot_flash = {0, 0, 0, 0}         -- motif slot just played, decays
local slot_last = {}                    -- slot -> last midi
local sw_state, sw_level, sw_disp = "idle", 0, 0
local bar_pulse = 0
local moment_age, moment_kind = 999, nil
local hist = {}                         -- per bar: {bloom, wet}
local HIST_N = 80

-- per-theme animation state
local rings, pending = {}, {}
local drops, splashes = {}, {}
local step_seen, step_frame = -1, 0
local cur = 1                           -- theme on screen; ripples/rain only queue for their own

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- note -> screen column: the motif range (G3..G6) spans the width
local function px(m) return clamp(math.floor(6 + (m - 55) / 36 * 116 + 0.5), 3, 124) end

local function opt(id, d)
  local ok, v = pcall(function() return params:get(id) end)
  if ok and v then return v end
  return d
end

------------------------------------------------------------------------
-- batched rects: one fill per brightness level, not one per rect
------------------------------------------------------------------------

local batch, bn = {}, {}
for l = 1, 15 do batch[l], bn[l] = {}, 0 end

local function put(l, x, y, w, h)
  l = math.floor(l * B + 0.5)
  if l <= 0 then return end
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

local function stroke_line(l, x0, y0, x1, y1)
  l = math.floor(l * B + 0.5)
  if l <= 0 then return end
  screen.level(math.min(15, l))
  screen.move(x0, y0)
  screen.line(x1, y1)
  screen.stroke()
end

------------------------------------------------------------------------
-- ripples
------------------------------------------------------------------------

local function slot_y(slot) return 10 + (slot - 1) * 14 end

local function add_ring(x, y, lvl)
  rings[#rings + 1] = {x = x, y = y, f = frame, lvl = lvl}
  if #rings > 24 then table.remove(rings, 1) end
end

local function on_note_ripples(slot, midi)
  local x, y = px(midi), slot_y(slot)
  add_ring(x, y, 1)
  -- echoes: one every echo time, each the feedback quieter
  local fb = clamp(opt("echo_fb", 0.45), 0, 0.85)
  local beat = (last_S and last_S.tempo and 60 / last_S.tempo) or (60 / 72)
  local delay = ECHO_BEATS[opt("echo_div", 3)] * beat * FPS
  local lvl = fb
  local k = 1
  while lvl > 0.2 and k <= 3 do
    pending[#pending + 1] = {at = frame + k * delay, x = x, y = y, lvl = lvl}
    lvl = lvl * fb
    k = k + 1
  end
  if #pending > 24 then table.remove(pending, 1) end
end

local function draw_ripples(S)
  -- the four bands, as faint dotted baselines
  for s = 1, 4 do
    local y = slot_y(s)
    local lit = S.sounding and S.sounding[s]
    for x = 4, 124, 8 do put(lit and 2 or 1, x, y, 1, 1) end
  end
  for i = #pending, 1, -1 do
    local p = pending[i]
    if frame >= p.at then
      add_ring(p.x, p.y, p.lvl)
      table.remove(pending, i)
    end
  end
  for i = #rings, 1, -1 do
    local r = rings[i]
    local rad = (frame - r.f) * 0.42 * SP
    local life = rad / 30
    if life >= 1 then
      table.remove(rings, i)
    elseif rad >= 1 then
      local lv = 9 * r.lvl * (1 - life) ^ 1.4
      if lv >= 0.5 then
        local ry = rad * 0.42
        local n = math.max(8, math.floor(2 * math.pi * rad * 0.75))
        for k = 0, n - 1 do
          local a = k / n * 2 * math.pi
          local x, y = r.x + math.cos(a) * rad, r.y + math.sin(a) * ry
          if x >= 0 and x < 128 and y >= 0 and y < 64 then put(lv, x, y, 1, 1) end
        end
      end
    end
  end
end

------------------------------------------------------------------------
-- horizon
------------------------------------------------------------------------

local STARS = {{9, 5}, {30, 11}, {47, 3}, {71, 8}, {92, 4}, {108, 12}, {120, 6}, {18, 17}, {84, 15}}

local function draw_horizon(S)
  local t = frame / FPS * SP
  local yw = math.floor(40 - sw_disp * 16)
  -- sky: a few far lights
  for i, s in ipairs(STARS) do
    if s[2] < yw - 3 then put(1 + (i + math.floor(t * 0.35)) % 2, s[1], s[2], 1, 1) end
  end
  -- a passing moment: a small mark crossing the sky
  if moment_age < 4 * 3.3 * FPS then
    local f = moment_age / (4 * 3.3 * FPS)
    if f < 1 then
      local x = 10 + f * 108
      local y = 10 + math.sin(f * 6) * 3
      local lv = 5 * math.sin(f * math.pi)
      put(lv, x, y, 1, 1); put(lv, x + 1, y - 1, 1, 1); put(lv, x + 2, y, 1, 1)
      put(lv, x - 1, y - 1, 1, 1)
    end
  end
  -- the waterline
  for x = 0, 127, 4 do
    local sh = math.sin(t * 0.9 + x * 0.07)
    put(2.5 + sh * 1 + bar_pulse * 2.5, x, yw, 4, 1)
  end
  -- swell crests: a few short dashes sliding along the line
  if sw_disp > 0.05 then
    for k = 0, 4 do
      local x = (k * 29 + t * 6) % 140 - 6
      put(2 + sw_disp * 4, x, yw - 1, 6, 1)
    end
  end
  -- chord voices: soft bands under the line, lower notes deeper
  local c = S.chord or {48, 55, 62, 64}
  for i = 1, 4 do
    local m = c[i] or 60
    local y = yw + 4 + (84 - m) * 0.32 + i * 0.5
    local cx = 64 + (i - 2.5) * 15 + math.sin(t * 0.25 + i * 1.7) * 5
    local w = 22 + i * 4 + sw_disp * 8
    local base = 3 + (S.gain and S.gain.pad or 0.5) * 3
    for x = 0, 126, 2 do
      local d = (x - cx) / w
      local v = math.exp(-d * d)
      if v > 0.12 then
        local sh = 0.75 + 0.25 * math.sin(t * 0.8 + x * 0.1 + i * 2)
        put((base + 1) * v * sh + bar_pulse * v, x, y, 2, 2)
      end
    end
  end
end

------------------------------------------------------------------------
-- postcards
------------------------------------------------------------------------

local CARD_W, CARD_H, CARD_Y = 26, 22, 18

local function draw_postcards(S)
  if S.step ~= step_seen then step_seen, step_frame = S.step, frame end
  local sub = clamp((frame - step_frame) / (60 / (S.tempo or 72) / 2 * FPS), 0, 1)
  for i = 1, 4 do
    local x0 = 6 + (i - 1) * 31
    local y0 = CARD_Y
    local m = S.motifs and S.motifs[i]
    local on = S.sounding and S.sounding[i] and (S.gain["motif" .. i] or 0) > 0.02
      and not (S.muted and S.muted["motif" .. i])
    local f = slot_flash[i]
    local edge = (on and 4 or 2) + f * 9
    -- the frame
    put(edge, x0, y0, CARD_W, 1)
    put(edge, x0, y0 + CARD_H - 1, CARD_W, 1)
    put(edge, x0, y0, 1, CARD_H)
    put(edge, x0 + CARD_W - 1, y0, 1, CARD_H)
    if f > 0.05 then
      -- the card lights inside, softly
      for yy = y0 + 2, y0 + CARD_H - 3, 2 do put(f * 2, x0 + 2, yy, CARD_W - 4, 1) end
    end
    -- the picture: a ground line and a spot at the last note's height
    put(on and 2 or 1, x0 + 3, y0 + CARD_H - 6, CARD_W - 6, 1)
    local lm = slot_last[i]
    if lm then
      local dx = x0 + 3 + (lm - 55) / 36 * (CARD_W - 9)
      local dy = y0 + CARD_H - 9 - (lm - 55) / 36 * (CARD_H - 13)
      local lv = (on and 4 or 1) + f * 9
      put(lv, dx, dy, 2, 2)
    end
    -- caption: where the motif is in its cycle
    local capy = y0 + CARD_H + 3
    put(on and 2 or 1, x0 + 1, capy, CARD_W - 2, 1)
    if on and m and m.cycle then
      local ph = ((S.step + sub) % m.cycle) / m.cycle
      put(7, x0 + 1 + ph * (CARD_W - 3), capy - 1, 1, 3)
    end
  end
end

------------------------------------------------------------------------
-- rain
------------------------------------------------------------------------

local GROUND = 60

local function on_note_rain(slot, midi, dur)
  local v = clamp(36 / ((dur or 0.5) + 0.5), 10, 50) / FPS      -- px per frame
  drops[#drops + 1] = {x = px(midi), y = 0, v = v, lvl = 12 - (slot - 1) * 1.5}
  if #drops > 36 then table.remove(drops, 1) end
end

local function draw_rain()
  for x = 1, 126, 3 do put(1, x, GROUND + 1, 1, 1) end
  for i = #drops, 1, -1 do
    local d = drops[i]
    d.y = d.y + d.v * SP
    if d.y >= GROUND then
      splashes[#splashes + 1] = {x = d.x, f = frame, lvl = d.lvl}
      if #splashes > 24 then table.remove(splashes, 1) end
      table.remove(drops, i)
    else
      local tail = math.floor(d.v * 7) + 4
      put(d.lvl, d.x, d.y, 2, 2)
      for k = 1, tail do put(d.lvl * (1 - k / (tail + 1)) * 0.6, d.x, d.y - k, 2, 1) end
    end
  end
  for i = #splashes, 1, -1 do
    local s = splashes[i]
    local a = (frame - s.f) * SP
    if a > 22 then
      table.remove(splashes, i)
    else
      local lv = s.lvl * 0.7 * (1 - a / 22)
      local sp = math.floor(a * 0.4) + 1
      put(lv, s.x - sp - 1, GROUND, 2, 1)
      put(lv, s.x + sp, GROUND, 2, 1)
      put(lv * 0.6, s.x - sp - 3, GROUND + 1, 2 * sp + 8, 1)
      if a < 5 then put(lv, s.x, GROUND - 1, 2, 1) end
    end
  end
end

------------------------------------------------------------------------
-- tide
------------------------------------------------------------------------

local function shore_y(b) return 56 - b * 32 end

local function draw_tide(S)
  local n = #hist
  if n < 2 then return end
  local t = frame / FPS * SP
  local bw = 128 / HIST_N
  local x0 = 128 - n * bw
  for x = math.floor(x0), 126, 2 do
    local f = (x - x0) / bw
    local i = clamp(math.floor(f) + 1, 1, n - 1)
    local u = clamp(f - (i - 1), 0, 1)
    local a, b = hist[i], hist[i + 1]
    local bloom = a.bloom + (b.bloom - a.bloom) * u
    local wet = a.wet + (b.wet - a.wet) * u
    local y = shore_y(bloom)
    if x > 112 then y = y + math.sin(t * 1.1 + x * 0.3) * 0.8 end   -- the live edge laps
    y = math.floor(y + 0.5)
    put(9, x, y, 2, 1)
    if wet > 0.02 then
      -- wet sand: darker, glossy, running down from the line
      put(2 + wet * 3, x, y - 1, 2, 1)
      put(1.5 + wet * 2.5, x, y + 1, 2, math.floor(3 + wet * 8))
    end
    -- dry sand: sparse dashes
    local row = 0
    for yy = y + 4 + ((x // 2) % 2) * 2, 62, 4 do
      if (x // 2 + row) % 2 == 0 then put(1, x, yy, 2, 1) end
      row = row + 1
    end
  end
end

------------------------------------------------------------------------
-- drift
------------------------------------------------------------------------

local ORBIT_RY = {6, 12, 18, 24}

local function draw_drift(S)
  if S.step ~= step_seen then step_seen, step_frame = S.step, frame end
  local sub = clamp((frame - step_frame) / (60 / (S.tempo or 72) / 2 * FPS), 0, 1)
  local cx, cy = 64, 32
  local pts, ph = {}, {}
  for i = 1, 4 do
    local ry = ORBIT_RY[i]
    local rx = ry * 1.7
    for k = 0, 27 do
      local a = k / 28 * 2 * math.pi
      put(1.6, cx + math.cos(a) * rx, cy + math.sin(a) * ry, 1, 1)
    end
    local m = S.motifs and S.motifs[i]
    local on = m and S.sounding and S.sounding[i] and (S.gain["motif" .. i] or 0) > 0.02
      and not (S.muted and S.muted["motif" .. i])
    if m and m.cycle then
      local p = ((S.step + sub) % m.cycle) / m.cycle
      local a = p * 2 * math.pi - math.pi / 2
      local x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
      if on then
        local lv = 6 + slot_flash[i] * 7
        put(lv, x - 1, y - 1, 3, 3)
        put(lv * 0.5, x - 2, y, 5, 1)
        put(lv * 0.5, x, y - 2, 1, 5)
        pts[#pts + 1] = {x, y}
        ph[#ph + 1] = p
      else
        put(2, x, y, 1, 1)
      end
    end
  end
  put(3 + clamp(1 - moment_age / (3 * FPS), 0, 1) * 6, cx, cy, 1, 1)
  flush()
  -- a line joins two points when their phases line up
  for i = 1, #pts - 1 do
    for j = i + 1, #pts do
      local d = math.abs(ph[i] - ph[j])
      d = math.min(d, 1 - d)
      if d < 0.12 then
        stroke_line((1 - d / 0.12) * 8, pts[i][1], pts[i][2], pts[j][1], pts[j][2])
      end
    end
  end
end

------------------------------------------------------------------------
-- dispatch
------------------------------------------------------------------------

function VIS.init()
  recent, rings, pending, drops, splashes, hist = {}, {}, {}, {}, {}, {}
  slot_flash = {0, 0, 0, 0}
  slot_last = {}
  sw_state, sw_level, sw_disp, bar_pulse = "idle", 0, 0, 0
  moment_age, moment_kind = 999, nil
  step_seen = -1
  cur = 1
end

-- kind: "note" (slot, midi, dur_s), "chord" (S), "bar" (S), "swell"
-- (state, level), "moment" (kind)
function VIS.event(kind, a, b, c)
  if kind == "note" then
    local slot = a
    slot_flash[slot] = 1
    slot_last[slot] = b
    recent[#recent + 1] = {slot, b, c, frame}
    if #recent > 24 then table.remove(recent, 1) end
    if cur == 1 then on_note_ripples(slot, b) end
    if cur == 4 then on_note_rain(slot, b, c) end
  elseif kind == "bar" then
    bar_pulse = 1
    local wet = 0
    if sw_state ~= "idle" then wet = math.max(0.35, sw_level) end
    hist[#hist + 1] = {bloom = (a and a.bloom) or 0, wet = wet}
    if #hist > HIST_N then table.remove(hist, 1) end
  elseif kind == "swell" then
    sw_state, sw_level = a, b or 0
  elseif kind == "moment" then
    moment_age, moment_kind = 0, a
  end
  -- "chord": the bands read S.chord every frame; nothing to keep
end

local DRAW = {draw_ripples, draw_horizon, draw_postcards, draw_rain, draw_tide, draw_drift}

function VIS.draw(i, S)
  local fn = DRAW[i]
  if not fn or not S then return end
  if i ~= cur then
    -- a new theme starts from calm: nothing queued while it was off screen
    rings, pending, drops, splashes = {}, {}, {}, {}
    cur = i
  end
  last_S = S
  frame = frame + 1
  B  = opt("vis_brightness", 10) / 10
  SP = opt("vis_speed", 3) / 3
  fn(S)
  flush()
  for s = 1, 4 do slot_flash[s] = slot_flash[s] * 0.86 end
  bar_pulse = bar_pulse * 0.93
  moment_age = moment_age + 1
  sw_disp = sw_disp + ((sw_state ~= "idle" and sw_level or 0) - sw_disp) * 0.04
end

return VIS
