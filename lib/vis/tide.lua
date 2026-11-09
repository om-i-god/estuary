-- tide: a beach seen from the dunes, the sea above, the sand below, a thin
-- strip of sky on the far line. the last ~80 bars of bloom make the
-- shoreline, scrolling smoothly to the left; at the live edge, waves wash up
-- the sand and draw back, as far as the sound and the water sounds carry
-- them, with a lace of foam at their front (thicker with out_mid) and a wet
-- sheen left behind as they retreat. out_lo heaves the line and slows the
-- waves' rhythm; out_hi glitters on the foam and the sheen. the chord rolls
-- in as four long swells out at sea, nearer for lower tones, moving to their
-- new places when it changes. notes land at their pitch: foam bursts on the
-- wash (the first motif), a shell glints on the wet sand (the second), spray
-- lifts off a swell (the third), a gull settles on the water, rings
-- spreading (the fourth). the bar breathes on the shoreline; a swell floods
-- the beach; a passing moment lets a patch of sunlight cross the sea. the
-- dune grass close by bends in the wind. two small shore birds keep just
-- ahead of the wash, pecking; now and then a gull glides along the shore, a
-- crab scuttles over the sand, or driftwood rides the wash
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, floor = math.sin, math.floor

  M.incidents = {{"gull", 14}, {"crab", 16}, {"driftwood", 20}}
  local MARK_MAX = 10
  local marks = {}
  local sand_top = {}                     -- per column: where the dry sand starts
  local fronts = {}                       -- per column: the wash front this frame
  local cyc_ph = 0                        -- the waves' rhythm, integrated

  local hist = K.hist
  local foam = {}                         -- this frame's foam front
  local wet_y = {}                        -- per column: how far the last wash reached
  local birds

  function M.init()
    foam, wet_y, marks, cyc_ph = {}, {}, {}, 0
    birds = {{x = 104, y = 50, ph = 0.4}, {x = 116, y = 52, ph = 2.2}}
  end

  function M.clear() wet_y, marks = {}, {} end

  function M.note(slot, midi)
    -- (when the list is full, the oldest mark fades out quickly)
    K.cap_add(marks, {slot = slot, x = K.px(midi), u = K.pu(midi), t0 = K.T}, MARK_MAX)
  end

  -- the dry sand's stipple and ripple marks, fixed per column (so the beach
  -- stays put while the water moves): SAND[c] = {y, dx, level, ...}
  local SAND = {}
  for c = 0, 63 do
    local col = {}
    for y = 5, 62 do
      local h = K.hash(c * 64 + y, 7)
      local ripple = ((y // 4) % 3 == 0) and sin(c * 0.4 + y * 0.4) > 0.3
      if h < 0.07 or (ripple and h < 0.4) then
        col[#col + 1], col[#col + 2], col[#col + 3] = y, h < 0.035 and 1 or 0, (h < 0.02 or ripple) and 1.6 or 1
      end
    end
    SAND[c] = col
  end

  -- dune grass in the near corner: {x, height, phase}
  local GRASS = {}
  for k = 1, 6 do GRASS[k] = {104 + k * 3.6 + 2 * K.hash(k, 71), 4 + 6 * K.hash(k, 72), K.hash(k, 73) * 6} end

  local function shore_y(b) return 52 - b * 30 end

  local live_pt = {bloom = 0, wet = 0}

  -- the shoreline's bloom and wetness at a column: the live bloom at the right
  -- edge, history to the left of it sliding along smoothly between bars, the
  -- oldest value held beyond it
  local function hist_at(x, scroll)
    local n = #hist
    local d = (127 - x) / (128 / K.HIST_N)          -- bars back from the edge
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

  local function sample(u)
    local n = #foam
    if n == 0 then return nil end
    local p = foam[math.floor(u * n) + 1]
    return p[1] + 1, p[2]
  end

  -- the wash front at a column, for the birds
  local front = {}

  -- the chord's swells: tone i -> y out at sea, presence
  local SWY, SWP = {0, 0, 0, 0}, {0, 0, 0, 0}

  function M.draw(S)
    local T, NOW = K.T, K.NOW
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    live_pt.bloom = bloom
    live_pt.wet = K.sw_state ~= "idle" and math.max(0.35, K.sw_level) or 0
    local scroll = clamp((NOW - K.bar_t) / K.bar_len, 0, 1)
    local nf = 0
    -- the waves' slow rhythm, slower and deeper with out_lo
    cyc_ph = cyc_ph + K.DTS / (7.5 + 2.5 * lo) * K.TAU
    local cyc = cyc_ph
    local reach0 = 4 + 8 * A[K.AMP] + 7 * nat
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      SWY[i], SWP[i] = m and clamp(4 + (m - 36) / 40 * 14, 4, 19) or 0, m and p or 0
    end
    -- the moment: a patch of sunlight crossing the sea
    local ma = K.moment_age
    local sun_e = ma < 14 and ease(ma / 2) * (1 - ease((ma - 9) / 5)) or 0
    local sun_x, sun_y = -20 + ma * 12, 12 + 3 * sin(ma * 0.3)
    -- the far line: a thin strip of sky
    for y = 0, 2 do K.dither_row((1 + 0.9 * bloom) * (0.5 + y * 0.3) + breath * 1.2, y) end
    K.hline(2 + bloom, 3, 0, 128, 7)
    for x = 0, 126, 2 do
      local c = x // 2
      local bl, wet = hist_at(x, scroll)
      local edge = ease((x - 40) / 76)               -- 0 to the left .. 1 at the live edge
      -- (the beach has its own small cusps and bays, so even a flat
      -- history never draws a ruled line)
      local yl = shore_y(bl) + K.heave(x) * 0.5 + edge * sin(T * 1.1 + x * 0.3) * 0.6
        + 1.1 * sin(x * 0.17 + 1.3) + 0.6 * sin(x * 0.41)
      -- the sea above the line: swell lines that run in toward the beach,
      -- brighter near it; the chord's four long swells among them
      -- (every other column, two px wide: the lines read the same at half
      -- the cost)
      if c % 2 == 0 then
        -- (the lines' bend is fixed: they move by their light, never by a
        -- column of dashes hopping a row)
        local bend = floor(1.5 * sin(x * 0.045 + 1.1) + 0.5)
        for yy = 5 + (c // 2) % 3, yl - 3, 4 do
          local near = 1 - (yl - yy) / 50
          local w = sin(x * 0.07 + yy * 0.55 - T * 0.9 + K.drift_x * 0.08) + 0.6 * sin(x * 0.03 - yy * 0.2 + T * 0.3)
          local lit = 0
          if sun_e > 0 then
            local dx, dy = (x - sun_x) / 40, (yy - sun_y) / 14
            local d = dx * dx + dy * dy
            if d < 1 then lit = sun_e * (1 - d) * 5 end
          end
          -- (a dash fades in and out with its wave, brightens on the crest
          -- and grows a fourth pixel by its light: nothing switches)
          local th = 0.7 - 0.35 * near - 0.45 * mid - lit * 0.3
          if w > th then
            local l = (1 + K.ramp(w, 1.05, 1.45) + near * (0.8 + breath * 1.5) + mid * 1.3 + lit
              + hi * 5 * math.max(0, sin(x * 1.3 + yy * 2.1 + T * 8))) * K.ramp(w, th, th + 0.3) * clamp((yl - 3 - yy) / 3, 0, 1)
            put(l, x, yy + bend, 3, 1)
            put(l * K.ramp(w, 1, 1.25), x + 3, yy + bend, 1, 1)
          end
        end
      end
      if c % 2 == 1 then
        for i = 1, 4 do
          local p = SWP[i]
          if p > 0.02 then
            local y = SWY[i] + 1.2 * sin(x * 0.05 - T * 0.6 + i * 1.7)
            local crest = 0.5 + 0.5 * sin(x * 0.11 - T * 0.9 + i * 2.3)
            if y < yl - 3 and crest > 0.25 then
              put(p * (1.6 + 1.8 * crest + 2 * K.chord_glow), x - 1, y, 4, 1)
            end
          end
        end
      end
      -- waves wash up the sand and draw back, as far as the sound carries
      -- them; a swell floods the whole beach
      local ph = 0.5 - 0.5 * math.cos(cyc - x * 0.02)
      local reach = reach0 * ph * (0.8 + 0.2 * sin(x * 0.09 + T * 0.3)) * edge + sw * 24
      local yf = math.min(62, yl + reach)
      front[c] = yf
      fronts[c] = yf
      put(4 + breath * 3.5 + K.bj(c), x, yl, 2, 1)
      -- the damp strip the sea always keeps dark-bright just above the line
      if c % 3 ~= 0 then put(1.5 + breath + K.bj(c + 64), x, yl - 2, 2, 1) end
      if wet > 0.02 then put(2 + wet * 3, x, yl - 1, 2, 1) end
      -- where the last wash reached: it creeps back up slowly as it drains
      local wy = wet_y[c] or yf
      wy = math.max(yf, wy - K.DTS * 1.2)
      wet_y[c] = wy
      if reach > 1.5 then
        -- the sheet of water over the sand: sparse glossy dashes that slide
        for yy = floor(yl) + 2 + c % 2, yf - 2, 4 do
          local w = sin(x * 0.15 + yy * 0.5 - T * 1.2 + K.drift_x * 0.1)
            + 0.6 * sin(x * 0.07 - yy * 0.9 + T * 0.5)
          local th = 0.75 - 0.4 * mid
          if w > th then put((1.5 + mid + K.ramp(w, 0.85, 1.05)) * K.ramp(w, th, th + 0.2), x, yy, 2, 1) end
        end
        -- the foam: a lace of broken rows at the front, brighter as it runs
        -- up, thicker with out_mid, glittering with out_hi
        local sparkle = hi * 5 * math.max(0, sin(x * 1.7 + T * 9))
        -- (the lace churns by its light, its pieces in place: no pixel
        -- hops sideways or switches on)
        local lace = sin(x * 0.9 + T * 2.3 + sin(x * 0.31))
        local upl = 4 + 2 * clamp(sin(cyc - x * 0.02) * 4, 0, 1)
        put(upl + sparkle - 1 + lace, x, yf, 2, 1)
        put((upl * 0.5) * K.ramp(lace, -0.5, 0), x + (c % 2), yf - 1, 1, 1)
        if mid > 0.15 then put((2 + 2.5 * mid) * K.ramp(lace, 0.6 - mid, 0.9 - mid) * K.ramp(mid, 0.15, 0.3), x + ((c + 1) % 2), yf - 2, 1, 1) end
        nf = nf + 1
        foam[nf] = foam[nf] or {}
        foam[nf][1], foam[nf][2] = x, yf
      end
      -- the wet sheen the retreating wash leaves: a glossy band from the
      -- front back up to where the water reached, reflecting the light
      local ys = math.max(yl, yf)
      if wy > ys + 1.5 then
        local g = math.min(1, (wy - ys) / 6)
        for yy = floor(ys) + 2 + c % 2, wy, 3 do
          if (c + yy) % 4 ~= 0 then put(1 + g * (1 + bloom) + breath * 2.2 + hi * 3.5 * math.max(0, sin(x * 0.7 + yy + T * 5)), x, yy, 2, 1) end
        end
        ys = wy
      end
      if wet > 0.02 then
        -- (a flooded beach hides most of it)
        local deep = (2 + wet * 8) * (1 - 0.7 * sw)
        for yy = floor(ys) + 1 + c % 3, ys + 1 + deep, 3 do put(1 + wet * 2, x, yy, 2, 1) end
        ys = ys + 1 + deep
      end
      sand_top[c] = ys + 3
    end
    for k = nf + 1, #foam do foam[k] = nil end
    -- dry sand: rows of the hand-made stipple wherever the beach is dry,
    -- ripple marks every few rows; it stays put while the water moves, and
    -- warms with the daylight
    local sl = 1 + 0.6 * bloom
    for c = 0, 63 do
      local col, top = SAND[c], sand_top[c]
      for i = 1, #col, 3 do
        if col[i] >= top then put(col[i + 2] * sl, c * 2 + col[i + 1], col[i], 1, 1) end
      end
    end
    -- the dune grass close by, bending with the wind
    for _, g in ipairs(GRASS) do
      local x0, h = g[1], g[2]
      local lean = sin(T * 0.9 + g[3]) * (0.5 + 2 * nat) + K.heave(x0) * 0.4 + K.cur_u * 0.1
      if 63 - h > (sand_top[math.min(63, x0 // 2)] or 99) - 3 then
        -- (a blade that arches over as it rises, its tip catching the light)
        local dir = (g[3] > 3) and 1 or -1
        put(2.2 + bloom + K.bj(x0 * 3) * 0.4, x0, 63 - h * 0.5, 1, h * 0.5 + 1)
        put(2.4 + bloom, x0 + lean * 0.5 + dir * 0.5, 63 - h * 0.8, 1, h * 0.3 + 0.5)
        put(3 + bloom, x0 + lean + dir * 1.5, 63 - h, 1, 1 + h * 0.2)
      end
    end
    -- the notes, each at its pitch
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 5 or done then table.remove(marks, i)
      else
        local e = (1.2 * ease(age / 0.2) * (1 - ease((age - 1.2) / 3.8))) * cf
        local x = mk.x
        local fy = fronts[x // 2] or 50
        if mk.slot == 1 then
          -- foam bursts on the wash
          -- foam bursts along the wash, spray thrown up off it
          local spread = 4 + math.min(age, 1.5) * 6
          put(7 * e, x - spread, fy, spread * 2, 1); put(4.5 * e, x - spread * 0.7, fy + 1, spread * 1.4, 1)
          for k = -2, 2 do
            local hy = sin(math.pi * clamp(age / 1.2, 0, 1)) * (3 + (2 - math.abs(k)))
            put(6 * e, x + k * 3 + (k % 2), fy - 1 - hy, 1, 1)
          end
          put(2.5 * e, x - spread, fy + 3, spread * 2, 1)
        elseif mk.slot == 2 then
          -- a shell glints on the wet sand, below the front
          local y = math.min(61, fy + 3 + mk.u * 4)
          put(8 * e, x - 1, y, 4, 1); put(5 * e, x - 2, y + 1, 6, 1)
          put(3.5 * e * (0.5 + 0.5 * sin(T * 6)), x - 3, y - 1, 1, 1); put(3.5 * e, x + 4, y - 1, 1, 1)
          put(2 * e, x - 4, y + 2, 10, 1)
        elseif mk.slot == 3 then
          -- spray lifts off a swell out at sea, higher for a higher note
          local y = 8 + (1 - mk.u) * 10
          for k = 0, 4 do
            local a = age * 1.6
            put(6 * e * (1 - k / 6), x - 4 + k * 2, y - sin(math.pi * math.min(1, a)) * (2 + k % 3) , 2, 1)
          end
          put(4 * e, x - 6, y + 1, 12, 1)
        else
          -- a gull settles on the water: rings spread from it
          local y = 10 + (1 - mk.u) * 8
          put(6.5 * e, x - 2, y - 1, 4, 1); put(5.5 * e, x + 1, y - 2, 2, 1)
          K.ring(x, y, 2 + age * 4, 0.4, 4.5 * e, 16)
          K.ring(x, y, 1 + age * 2.5, 0.4, 3 * e, 10)
        end
      end
    end
    -- the birds keep a few pixels ahead of the wash on dry sand, run when it
    -- comes, and peck while it draws back
    for _, b in ipairs(birds) do
      local fy = front[floor(b.x) // 2] or 50
      local want = clamp(fy + 4, 10, 61)
      local run = want - b.y
      b.y = b.y + run * (1 - math.exp(-K.DT * (run > 0 and 6 or 1.5)))
      b.x = clamp(b.x + sin(T * 0.13 + b.ph) * K.DTS * 1.5, 92, 124)
      local peck = (math.abs(run) < 1 and sin(T * 2.2 + b.ph * 3) > 0.6) and 1 or 0
      local x, y = floor(b.x), floor(b.y)
      local lv = 4 + bloom * 2
      put(lv, x, y - 3, 3, 2)                        -- body
      put(lv, x + 3, y - 4 + peck, 1, 1)             -- head
      put(lv - 1, x + 4, y - 3 + peck * 2, 1, 1)     -- bill
      put(lv - 2, x + 1, y - 1, 1, 1)                -- legs
      put(lv - 2, x + 1 + ((run > 1 and sin(T * 14) > 0) and 1 or 0), y, 1, 1)
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "gull" then
        -- a gull glides along the shore, its shadow on the sand
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (-12 + u * 152) or (140 - u * 152)
        local sy = fronts[clamp(floor(x) // 2, 0, 63)] or 40
        local y = clamp(sy - 14 + sin(u * 9) * 2, 6, 50)
        K.bird(x, y, 6 * e, sin(K.NOW * 1.5) * 0.4, 2)
        put(2 * e, x - 4, math.min(62, sy + 6), 9, 1)
      elseif inc.name == "crab" then
        -- a crab scuttles sideways over the dry sand in short runs
        local t = inc.age
        local runs = floor(t / 1.6)
        local f = clamp((t % 1.6) / 0.7, 0, 1)
        local x = 14 + inc.s * 40 + (runs + ease(f)) * 8
        local y = clamp(55 + inc.s2 * 5, 30, 61)
        local leg = (f > 0 and f < 1 and sin(K.NOW * 24) > 0) and 1 or 0
        put(7.5 * e, x - 2, y - 1, 5, 2)
        put(5 * e, x - 4, y - leg, 2, 1); put(5 * e, x + 3, y - 1 + leg, 2, 1)
        put(5 * e, x - 4, y + 1 - leg, 1, 1); put(5 * e, x + 4, y + leg, 1, 1)
        put(6 * e, x - 3, y - 3, 1, 2); put(6 * e, x + 3, y - 3, 1, 2)
        put(2 * e, x - 3, y + 2, 7, 1)
      else
        -- a branch of driftwood rides the wash up and back, foam round it
        local x = 66 + inc.s * 40
        -- (riding the front between columns, so it never hops a row)
        local c0 = clamp(floor(x) // 2, 0, 62)
        local fu = x / 2 - c0
        local y = (fronts[c0] or 50) * (1 - fu) + (fronts[c0 + 1] or fronts[c0] or 50) * fu
        -- (its light shared between the two rows it lies across, so it
        -- rises and falls with the wash instead of hopping)
        local yi = floor(y)
        local fy = y - yi
        local function v(l, dx, dy, w, h)
          put(l * (1 - fy), x + dx, yi + dy, w, h); put(l * fy, x + dx, yi + dy + 1, w, h)
        end
        v(6 * e, -7, -1, 6, 1); v(6.5 * e, -2, -2, 7, 1); v(5.5 * e, 4, -3, 3, 1)
        v(5 * e, -4, -3, 1, 2); v(5 * e, 2, -4, 1, 2)
        v(3.5 * e, -9, 1, 18, 1)
      end
    end
    K.glitter(sample)
  end

  M.init()
  return M
end
