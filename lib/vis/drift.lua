-- drift: a pool seen from above, between two grassy banks, turning in four
-- slow eddies. you look down through the water to its bed, where the
-- chord lies as four pools of sunlight (across by pitch, nearer the middle
-- for higher tones) that slide to their new places when it changes. each
-- motif is a leaf carried round its eddy at its own cycle length, a wake
-- fading behind it; petals ride the eddies more slowly. a note lands on its
-- motif's eddy, across by its pitch, and the motif decides what lands: a
-- drop that rings, a petal, a spinning seed, a few bubbles. the eddies
-- wobble with out_lo and precess with the current, their paths a shimmer on
-- the surface that out_mid brightens and out_hi sparkles; the water sounds
-- ruffle the surface with wind; a shimmering line joins two leaves whose
-- phases line up. grass blades lean out over the water from the banks. the
-- bar breathes along the eddies; a swell raises the pool, the banks drawing
-- back; a moment opens a slow whirlpool in the middle. now and then a water
-- strider skates across, a big leaf drifts through, or a fish's shadow
-- passes under
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor = math.sin, math.cos, math.floor

  M.incidents = {{"strider", 14}, {"leaf", 22}, {"fish", 12}}

  local ORBIT_RY = {6, 12, 18, 24}
  local PETALS = 10
  local MARK_MAX = 10
  local petals, marks
  local snd = {0, 0, 0, 0}                -- each motif sounding, eased

  function M.init()
    petals, marks = {}, {}
    for k = 1, PETALS do
      petals[k] = {i = (k - 1) % 4 + 1, a = K.hash(k, 21) * K.TAU, r = 0.75 + 0.5 * K.hash(k, 22),
        w = 0.05 + 0.06 * K.hash(k, 23), lv = 2 + 1.5 * K.hash(k, 24)}
    end
  end

  function M.clear() marks = {}; for i = 1, 4 do snd[i] = 0 end end

  -- the banks' grass, baked once: dashes in the corners, a lit lip
  local function e1(y) return y < 16 and 40 * (1 - (y / 16) ^ 1.6) + 2 * sin(y * 1.3) or 0 end
  local function e2(y) return y > 46 and 46 * (1 - ((63 - y) / 17) ^ 1.6) + 2 * sin(y * 1.7) or 0 end
  local grass = K.bake(function(rec)
    for y = 0, 63 do
      local a, b = e1(y), e2(y)
      if a > 1 then
        for x = (y * 5) % 4, a - 3, 4 do
          if K.hash(x * 64 + y, 25) < 0.5 then rec(1 + (K.hash(x + y, 26) < 0.2 and 1 or 0), x, y, 1, 2) end
        end
      end
      if b > 1 then
        for x = 128 - b + 3 + (y * 5) % 4, 127, 4 do
          if K.hash(x * 64 + y, 27) < 0.5 then rec(1 + (K.hash(x + y, 28) < 0.2 and 1 or 0), x, y, 1, 2) end
        end
      end
    end
  end)
  -- long blades leaning out over the water: {x, y, length, dir, phase}
  local BLADES = {{30, 6, 9, 1, 0.3}, {36, 3, 7, 1, 1.7}, {22, 10, 8, 1, 2.9}, {94, 58, 9, -1, 0.8}, {100, 54, 7, -1, 2.2}, {88, 61, 8, -1, 3.6}}

  -- a point on eddy i at angle a (scaled out by r): an ellipse that wobbles
  -- with out_lo, its wobble carried round by the current, tilted a little
  -- back and forth
  local function orbit_pt(i, a, rr)
    local T, dx = K.T, K.drift_x
    local ry = ORBIT_RY[i] * (rr or 1)
    local rx = ry * 1.7
    local lo = A[K.LO]
    local dir = (i % 2 == 0) and 1 or -1
    local r = 1 + (0.03 + 0.11 * lo) * sin(3 * a + T * 0.8 + i + dir * dx * 0.02)
      + (0.02 + 0.05 * lo) * sin(2 * a - T * 0.45 + i * 2)
    local x, y = cos(a) * rx * r, sin(a) * ry * r
    local tl = 0.15 * sin(T * (0.05 + 0.01 * i) + dx * 0.01 * dir + i)
    local c, s = cos(tl), sin(tl)
    return 64 + x * c - y * s, 32 + x * s + y * c
  end

  local function sample(u, v) return orbit_pt(floor(u * 4) + 1, v * K.TAU) end

  -- the sheens' keep and glint, made once (their row and the time are set
  -- each frame); the leaves' places this frame, reused
  local F_T, F_hi, F_y = 0, 0, 0
  local function sheen_keep(x) return sin(x * 0.05 + F_y * 0.13 - F_T * 0.1) > -0.3 end
  local function sheen_glint(x) return 0, F_hi * 3 * math.max(0, sin(x * 0.9 + F_y * 1.7 + F_T * 6)) end
  local PX, PY, PH, PO = {}, {}, {}, {}

  -- a note lands on its motif's eddy, across by its pitch: the eddy's near
  -- side for a low note, its far side for a high one
  function M.note(slot, midi)
    local x = K.px(midi)
    local rx = ORBIT_RY[slot] * 1.7
    local c = clamp((x - 64) / rx, -1, 1)
    local a = math.acos(c) * (K.pu(midi) > 0.5 and -1 or 1)
    -- (when the list is full, the oldest mark fades out quickly)
    K.cap_add(marks, {slot = slot, a = a, t0 = K.T}, MARK_MAX)
  end

  -- a leaf lying along its heading: a bright midrib and a dimmer blade
  local function leaf(x, y, hx, hy, lv, big)
    local n = math.sqrt(hx * hx + hy * hy)
    if n < 1e-6 then hx, hy = 1, 0 else hx, hy = hx / n, hy / n end
    local s = big or 1
    put(lv, x, y, 1, 1)
    put(lv * 0.8, x + hx * 1.5 * s, y + hy * 1.5 * s, 1, 1)
    put(lv * 0.6, x - hx * 1.5 * s, y - hy * 1.5 * s, 1, 1)
    put(lv * 0.45, x - hx * 2.6 * s, y - hy * 2.6 * s, 1, 1)          -- the stalk
    put(lv * 0.55, x - hy * s, y + hx * s, 1, 1)
    put(lv * 0.55, x + hy * s + hx * 0.7, y - hx * s + hy * 0.7, 1, 1)
    if s > 1 then
      put(lv * 0.5, x - hy * s * 0.5 - hx, y + hx * s * 0.5 - hy, 1, 1)
      put(lv * 0.5, x + hy * s * 0.5 + hx * 2, y - hx * s * 0.5 + hy * 2, 1, 1)
      put(lv * 0.7, x + hx * 3, y + hy * 3, 1, 1)
    end
  end

  function M.draw(S)
    local T = K.T
    local hi, mid, nat = A[K.HI], A[K.MID], A[K.NAT]
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    -- the bed under the water: the chord's four pools of sunlight, soft
    -- dithered patches that slide when it changes
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local cx = K.cx(m)
        local cy = 32 + ((i % 2 == 0) and 1 or -1) * (6 + (76 - m) / 40 * 14)
        local l = (0.5 + 0.5 * bloom + 0.9 * K.chord_glow) * p
        for dy = -4, 4 do
          local hw = 11 * math.sqrt(1 - (dy / 5) ^ 2)
          K.dither_row(l * (1 - math.abs(dy) / 6), cy + dy, nil, math.max(0, floor(cx - hw)), math.min(128, floor(cx + hw)))
        end
      end
    end
    -- the banks: grass in the top left and bottom right corners, a lit lip
    -- where they meet the water, the pool's light lapping at it; a swell
    -- raises the water over their edges
    K.blit(grass, 1 + 0.4 * bloom)
    local cut = sw * 8
    for y = 0, 63, 1 do
      local a, b = e1(y) - cut, e2(y) - cut
      local lap = 1 + 0.8 * sin(T * 0.9 + y * 0.5) + breath + K.bj(y)
      if a > 1 then put(2 + bloom, a - 2, y, 2, 1); put(lap, a + 1, y, 1, 1) end
      if b > 1 then put(2 + bloom, 128 - b, y, 2, 1); put(lap, 128 - b - 2, y, 1, 1) end
    end
    if cut > 1 then
      -- the flooded edge: water lying over the grass
      for y = 0, 63, 2 do
        local a, b = e1(y), e2(y)
        if a > 1 then put(1.2 + 0.5 * bloom, a - cut, y, cut, 1) end
        if b > 1 then put(1.2 + 0.5 * bloom, 128 - b, y, cut, 1) end
      end
    end
    -- the sky lying on the pool: long faint sheens that slide with the
    -- current, broken where the eddies turn the surface
    F_T, F_hi = T, hi
    -- (sparse enough that the eddies' round paths read through them)
    for y = 7, 58, 6 do
      F_y = y
      K.streaks(0.9 + 0.6 * bloom + breath * 2.4, y, 6 + (y * 3) % 5, 26 + (y * 7) % 9, K.drift_x * (0.5 + y * 0.01) + y * 9.7 + sin(T * 0.2 + y) * 3,
        sheen_keep, sheen_glint)
    end
    -- the surface: a faint light texture moving with the current, ruffled
    -- by the wind the water sounds bring
    -- (on fixed rows: the wind thickens it rather than re-laying it)
    K.surface(0, 1, 128, 64, 1 + nat * 1.8, 14, 6, 3, nat * 0.9)
    -- the eddies' paths: arcs of light that run round with the water,
    -- fuller and brighter with out_mid, breathing on the bar
    for i = 1, 4 do
      local n = 14 + i * 14
      for k = 0, n - 1 do
        local a = k / n * K.TAU
        local sh = sin(a * 3 - T * (0.5 + 0.1 * i) * (i % 2 == 0 and 1 or -1) + i)
        local th = 0.3 - 0.55 * mid
        if sh > th then
          local x, y = orbit_pt(i, a)
          put((1.2 + K.ramp(sh, 0.65, 0.95) + mid * 1.2 + breath * 2.2 + K.bj(k + i * 64) + hi * 3.5 * math.max(0, sin(k * 2.3 + T * 7 + i))) * K.ramp(sh, th, th + 0.25), x, y, 2, 1)
        end
      end
    end
    -- petals, slower than the leaves, each at its own distance out
    for _, p in ipairs(petals) do
      p.a = p.a + p.w * (1 + 1.5 * K.energy) * K.DTS * (p.i % 2 == 0 and 1 or -1)
      local x, y = orbit_pt(p.i, p.a, p.r)
      put(p.lv + bloom, x, y, 2, 2)
      put(p.lv * 0.5, x + 2, y + 1, 1, 1)
    end
    -- grass blades leaning out over the water, close to you
    for _, b in ipairs(BLADES) do
      local sway = sin(T * 0.7 + b[5]) * (0.8 + 1.5 * nat) + K.heave(b[1]) * 0.5
      for k = 1, b[3] do
        local u = k / b[3]
        put(2.5 + bloom, b[1] + b[4] * k * 1.1, b[2] + b[4] * (k * 0.6 + u * u * (2 + sway)), 1, 1)
      end
    end
    -- the leaves
    local np = 0
    for i = 1, 4 do
      local p = K.phase(S, i)
      if p then
        local a = p * K.TAU - math.pi / 2
        local x, y = orbit_pt(i, a)
        local nx, ny = orbit_pt(i, a + 0.05)
        -- (a leaf brightens as its motif comes in and its wake opens, and
        -- both fade as it goes)
        snd[i] = K.follow(snd[i], K.sounding(S, i) and 1 or 0, 0.6, K.DT)
        local on = snd[i]
        if on > 0.02 then
          local lv = 2.5 + (3.5 + K.slot_flash[i] * 6) * on
          -- the wake: two fading arms opening behind it
          for k = 1, 7 do
            local tx, ty = orbit_pt(i, a - k * 0.06)
            local l = lv * 0.4 * (1 - k / 8) * (0.7 + 0.6 * A[K.AMP]) * on
            put(l, tx, ty, 1, 1)
            if k > 2 then
              local ox, oy = orbit_pt(i, a - k * 0.06, 1 + k * 0.012)
              put(l * 0.6, ox, oy, 1, 1)
            end
          end
          leaf(x, y, nx - x, ny - y, lv)
          np = np + 1
          PX[np], PY[np], PH[np], PO[np] = x, y, p, on
        else
          leaf(x, y, nx - x, ny - y, 2.5)
        end
      end
    end
    -- the notes, landing on their eddies
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4 or done then table.remove(marks, i)
      else
        local e = (1.3 * ease(age / 0.2) * (1 - ease((age - 0.8) / 3.2))) * cf
        local x, y = orbit_pt(mk.slot, mk.a + age * 0.06 * (mk.slot % 2 == 0 and 1 or -1))
        if mk.slot == 1 then
          K.ring(x, y, 1.5 + age * 4, 0.7, 5 * e, 14)
          put(6 * e, x, y, 1, 1)
        elseif mk.slot == 2 then
          -- a petal lands, a small ring under it
          put(7 * e, x - 1, y, 3, 2); put(4 * e, x + 2, y + 1, 1, 1)
          K.ring(x, y + 1, 2 + age * 2.5, 0.7, 3 * e, 10)
        elseif mk.slot == 3 then
          -- a winged seed spinning on the water
          local a = T * 5 + i
          for k = -1, 1, 2 do put(6 * e, x + cos(a) * 2.5 * k, y + sin(a) * 1.5 * k, 2, 1) end
          put(7 * e, x, y, 1, 1)
        else
          -- a few bubbles come up and sit
          for k = 0, 3 do
            local bx, by = x + (k - 1.5) * 2.5, y + sin(k * 2.1) * 1.5
            put(5 * e * ease((age - k * 0.15) / 0.3), bx, by, 2, 1)
          end
        end
      end
    end
    -- a moment: a slow whirlpool opens in the middle, its arms turning
    local ma = K.moment_age
    if ma < 14 then
      local e = ease(ma / 2) * (1 - ease((ma - 9) / 5))
      for arm = 0, 3 do
        for k = 0, 18 do
          local r = 2 + k * 1.1
          local a = arm * K.TAU / 4 + k * 0.32 - ma * 1.4
          put(e * (6 - k * 0.2), 64 + cos(a) * r * 1.6, 32 + sin(a) * r, 2, 1)
        end
      end
    end
    -- a shimmering dotted line joins two leaves whose phases line up
    for i = 1, np - 1 do
      for j = i + 1, np do
        local d = math.abs(PH[i] - PH[j])
        d = math.min(d, 1 - d)
        if d < 0.12 then
          local x0, y0, x1, y1 = PX[i], PY[i], PX[j], PY[j]
          local n = math.max(2, floor(math.max(math.abs(x1 - x0), math.abs(y1 - y0)) / 2))
          local base = (1 - d / 0.12) * 5 * (0.8 + 0.5 * hi) * math.min(PO[i], PO[j])
          for s = 1, n - 1 do
            local u = s / n
            local lv = base * (0.55 + 0.45 * sin(T * 6 + s * 0.9 + i * j))
            put(lv, x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, 1, 1)
          end
        end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "strider" then
        -- a water strider skates in short glides, four dimples under its feet
        local glides = floor(inc.age / 1.5)
        local f = ease(clamp((inc.age % 1.5) / 0.5, 0, 1))
        local x = 20 + inc.s * 20 + (glides + f) * 8
        local y = 18 + inc.s2 * 28 + sin(glides * 1.7) * 4
        put(6 * e, x - 1, y, 4, 1)
        for k = -1, 1, 2 do
          put(4 * e, x - 3, y + k * 3, 1, 1); put(4 * e, x + 5, y + k * 3, 1, 1)
          put(3 * e, x - 2, y + k * 2, 1, 1); put(3 * e, x + 4, y + k * 2, 1, 1)
          K.ring(x - 3, y + k * 3, 1.5 + (1 - f) * 2, 0.7, 3.5 * e, 8)
          K.ring(x + 5, y + k * 3, 1.5 + (1 - f) * 2, 0.7, 3.5 * e, 8)
        end
      elseif inc.name == "leaf" then
        -- a big leaf drifting through on the current, turning slowly
        local x = -10 + u * 150
        local y = 30 + sin(u * 4 + inc.s * 6) * 10
        local a = u * 5 + inc.s * 6
        put(4 * e, x - 3, y - 1, 7, 3)                      -- the blade
        leaf(x, y, cos(a), sin(a), 9 * e, 3)
        leaf(x + 2, y + 2, cos(a), sin(a), 6 * e, 2)
        put(2 * e, x - 4, y + 4, 9, 2)                      -- its shadow on the bed
      else
        -- a fish's shadow passes under: a dim long shape, its back a little
        -- lighter, the tail sweeping
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (-16 + u * 160) or (144 - u * 160)
        local y = 26 + inc.s2 * 14 + sin(u * 7) * 3
        local tail = sin(K.T * 4) * 1.5
        put(2.6 * e, x - 7, y - 2, 15, 4)
        put(3.8 * e, x - 5, y - 1, 10, 2)
        put(2.4 * e, x - 10 * dir - 1, y - 2 + tail, 3, 3)
        put(2.4 * e, x + 2 * dir - 1, y - 3, 3, 1); put(2.4 * e, x + 2 * dir - 1, y + 2, 3, 1)
      end
    end
    K.glitter(sample)
  end

  M.init()
  return M
end
