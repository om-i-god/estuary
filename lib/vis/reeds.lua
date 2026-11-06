-- reeds: a reed bed at the water's edge under an open evening sky, a low
-- glow on the far bank and the first stars, in three layers: a dim far
-- bank, a middle bed, and a few tall reeds close by with seed heads. the
-- chord shows as four brighter stars, across by pitch and higher for higher
-- tones, gliding to their new places when it changes, each lying again in
-- the water. every stem sways with the current and the heave, sound bends
-- them further, out_mid sets the middle bed swaying, and the wind the water
-- sounds bring runs along the far bank; a swell sends a slow wave of bending
-- across the bed. a note at its pitch: the nearest reed nods (the first
-- motif), a seed head lets go a few seeds (the second), a dragonfly hovers
-- (the third), a ring opens on the water (the fourth). out_hi glints on the
-- seed heads and the water. the bar breathes in the glow; a passing moment
-- brings the moon up over the bank. now and then a heron stands in the
-- shallows, a small bird swings on a near reed, or a fish jumps
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor = math.sin, math.cos, math.floor

  M.incidents = {{"heron", 20}, {"warbler", 14}, {"fish", 9}}

  local WL = 50                           -- the water's edge
  local FLY_MAX, SEED_MAX, RING_MAX = 3, 12, 4
  local layers, nods, flies, seeds, rings

  -- three layers, far to near: count, height range, level, sway, width
  local LAYERS = {
    {n = 22, h0 = 9, h1 = 16, lv = 1.5, sway = 0.5, w = 1, seed = 31},
    {n = 14, h0 = 14, h1 = 26, lv = 2.5, sway = 0.8, w = 1, seed = 32},
    {n = 6, h0 = 28, h1 = 42, lv = 4, sway = 1.1, w = 2, seed = 33},
  }

  -- the far bank: a low dark mass of reeds, its top ragged
  local bank = K.profile(function(x)
    return WL - 3 - 3 * K.hash(x // 2, 41) - 2 * math.max(0, sin(x * 0.06 + 1)) - 2 * K.hash(x // 7, 42)
  end)
  local bank_tex = K.bake(function(rec)
    for c = 0, 63 do
      local t = floor(bank[c] + 0.5)
      for y = t + 2, WL - 1, 2 do
        if K.hash(c * 64 + y, 43) < 0.3 then rec(1, c * 2 + (y // 2) % 2, y, 1, 1) end
      end
    end
  end)
  local STARS = {}
  for i = 1, 7 do STARS[i] = {9 + (i - 1) * 18 + 7 * K.hash(i, 44), 4 + 16 * K.hash(i, 45)} end

  function M.init()
    layers, nods, flies, seeds, rings = {}, {}, {}, {}, {}
    for li, L in ipairs(LAYERS) do
      local r = {}
      for k = 1, L.n do
        local u = (k - 1 + 0.15 + 0.7 * K.hash(k, L.seed)) / L.n
        r[k] = {x = -4 + u * 136, h = L.h0 + (L.h1 - L.h0) * K.hash(k, L.seed + 7),
          ph = K.hash(k, L.seed + 9) * 6, head = K.hash(k, L.seed + 11) > (li == 3 and 0.2 or 0.6)}
      end
      layers[li] = r
    end
  end

  function M.clear() nods, flies, seeds, rings = {}, {}, {}, {} end

  local function nearest(x)
    local best, bd, br
    for li = 2, 3 do
      for k, r in ipairs(layers[li]) do
        local d = math.abs(r.x - x)
        if not bd or d < bd then best, bd, br = li * 100 + k, d, r end
      end
    end
    return best, br
  end

  function M.note(slot, midi, dur)
    local x = K.px(midi)
    if slot == 1 then
      -- the nearest reed nods, and the water at its foot rings
      local key = nearest(x)
      if key then nods[key] = K.T end
      rings[#rings + 1] = {x = x, y = WL + 3, t0 = K.T, small = true}
      while #rings > RING_MAX do table.remove(rings, 1) end
    elseif slot == 2 then
      -- the nearest reed's head lets go a few seeds
      local key, r = nearest(x)
      if key then nods[key] = K.T end
      local li = key and key // 100 or 2
      local h = r and r.h or 20
      for k = 1, 5 do
        if #seeds < SEED_MAX then
          seeds[#seeds + 1] = {x = x, y = WL - h - 4 - (li == 3 and 3 or 0), t0 = K.T, vx = 3 + 4 * K.rnd(), vy = -2 - 3 * K.rnd(), ph = K.rnd() * 6}
        end
      end
    elseif slot == 3 then
      if #flies >= FLY_MAX then table.remove(flies, 1) end
      flies[#flies + 1] = {x = x, y = 12 + (1 - K.pu(midi)) * 20, t0 = K.T, dir = K.rnd() < 0.5 and -1 or 1, ph = K.rnd() * 6,
        life = 4 + math.min(3, tonumber(dur) or 1)}
    else
      rings[#rings + 1] = {x = x, y = WL + 4 + (1 - K.pu(midi)) * 8, t0 = K.T}
      while #rings > RING_MAX do table.remove(rings, 1) end
    end
  end

  -- how far a reed's tip leans (px), from everything that moves it
  local function lean(r, L, key, li)
    local T = K.T
    local u = K.flow(r.x, WL - r.h)
    local wave = K.sw_disp * 3 * sin(r.x * 0.05 - T * 1.1)
    local midsway = li == 2 and A[K.MID] * 2.2 * sin(T * 1.1 + r.ph * 2) or 0
    local wind = A[K.NAT] * 1.2 * (0.6 + 0.4 * sin(T * 0.5 + r.x * 0.03))
    local l = (u * 0.3 + sin(T * 0.7 + r.ph) * (0.6 + 1.3 * K.energy) + K.heave(r.x) * 0.3 + wave + wind) * L.sway + midsway
    local n = nods[key]
    if n then
      local age = T - n
      if age > 3 then nods[key] = nil
      else l = l + 7 * sin(age * 3.2) * math.exp(-age * 0.9) * ease(age / 0.15) end
    end
    return l
  end

  local function stem(r, L, key, base_l, li)
    local l = lean(r, L, key, li)
    local nod = nods[key] and math.max(0, 1 - (K.T - nods[key]) / 3) or 0
    base_l = math.min(8, base_l + nod * 3.5 + (li == 3 and K.breath * 1.2 or 0))
    local h = r.h
    local seg = L.w == 2 and 2 or 3
    local tx, ty
    for s = 0, h - 1, seg do
      local u = s / h
      local x = r.x + l * u * u
      put(base_l, x, WL - s - seg, L.w, seg)
      tx, ty = x, WL - s - seg
    end
    -- a long blade leaving the near reeds partway up, arching out and over
    if L.w == 2 then
      local by = WL - h * 0.45
      local dir = r.ph > 3 and 1 or -1
      for k = 1, 6 do
        local bx = r.x + l * 0.2 + dir * (k * 1.5 + 0.5) + l * 0.1 * k
        put(base_l * 0.8, bx, by - k * 1.7 + (k * k) * 0.1, 2, 1)
      end
    end
    if r.head and tx then
      local hl = math.min(11, base_l + 1 + nod * 3 + A[K.HI] * 3.5 * math.max(0, sin(K.T * 6 + r.ph * 3)))
      put(hl, tx, ty - 4, L.w == 2 and 2 or 1, L.w == 2 and 5 or 3)
      if L.w == 2 then put(base_l, tx + l * 0.12 + 0.5, ty - 7, 1, 3) end
    end
    return l, tx, ty
  end

  local function sample(u, v) return u * 127, WL + 2 + v * 11 end

  function M.draw(S)
    local T, DTS = K.T, K.DTS
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, nat = A[K.HI], A[K.NAT]
    -- the glow behind the bed, brighter with the bloom
    local glow = 0.75 + 0.7 * bloom
    -- open sky: a low glow hugging the bank, warmer with the bloom and
    -- breathing on the bar, a few first stars above
    K.gradient(WL - 12, WL - 1, function(y)
      return (0.6 + 0.45 * bloom + 1.3 * breath + 0.9 * K.chord_glow) * clamp((y - WL + 13) / 13, 0, 1) ^ 1.5
    end, bank)
    for i, s in ipairs(STARS) do
      put((1.4 - 0.5 * bloom) * (1 + 0.5 * sin(T * 0.5 + i * 2.1)), s[1], s[2], 1, 1)
    end
    -- the chord's stars: brighter, a small cross each, lying in the water too
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local x = K.cx(m) + K.drift_x * 0.02
        local y = clamp(26 - (m - 36) / 40 * 22, 3, 30)
        local l = (5 + 2 * K.chord_glow) * p * (1.1 - 0.3 * bloom)
        put(l, x, y, 1, 1)
        put(l * 0.5, x - 1, y, 1, 1); put(l * 0.5, x + 1, y, 1, 1); put(l * 0.5, x, y - 1, 1, 1); put(l * 0.5, x, y + 1, 1, 1)
        put(l * 0.25, x - 3, y, 2, 1); put(l * 0.25, x + 2, y, 2, 1); put(l * 0.25, x, y - 3, 1, 2); put(l * 0.25, x, y + 2, 1, 2)
        local ry = WL + (WL - y) * 0.25 + 2
        if ry < 63 then put(l * 0.45, x - 1 + K.heave(x + ry) * 0.6, ry, 3, 1) end
        -- and the glow over the bank is warmer under it
        for yy = WL - 10, WL - 1 do
          local hw = 15 * (1 - (WL - yy) / 13)
          K.dither_row((2.1 + 1.2 * K.chord_glow) * p * (1 - (WL - yy) / 12), yy, bank, math.max(0, floor(x - hw)), math.min(128, floor(x + hw)))
        end
      end
    end
    -- the moment: the moon comes up over the bank and its light lies on the
    -- water
    local ma = K.moment_age
    if ma < 18 then
      local e = ease(ma / 3) * (1 - ease((ma - 12) / 6))
      local mx, my = 96, WL - 7 - ease(ma / 12) * 16
      for dy = -5, 5 do
        local hw = floor(math.sqrt(30 - dy * dy) + 0.5)
        local y = my + dy
        if y < K.at(bank, mx) then put(e * (4.5 + (dy < -3 and 1 or 0)), mx - hw, y, 2 * hw, 1) end
      end
      -- its halo and its path on the water
      for dy = -8, 8, 2 do
        local hw = floor(math.sqrt(math.max(0, 90 - dy * dy)) + 0.5)
        if my + dy < K.at(bank, mx) then put(e * 1.5, mx - hw, my + dy, 2 * hw, 1) end
      end
      for d = 2, 13, 1 do put(e * (4 - d * 0.2), mx - 3 - d * 0.3 + sin(T * 2 + d) * 2, WL + d, 6 + d * 0.6, 1) end
    end
    K.blit(bank_tex, 1)
    for c = 0, 63 do
      local t = floor(bank[c] + 0.5)
      -- wind running along the far bank's top
      local gust = nat * 2.2 * math.max(0, sin(c * 0.25 - T * 1.6))
      put(1 + gust + breath * 1.5, c * 2, t - (gust > 1 and 1 or 0), 2, 1)
    end
    -- the water: the glow comes back, broken by the current
    local wl = WL - floor(sw * 2 + 0.5)
    for d = 2, 13, 2 do
      local y = WL + d
      local l = (glow + 0.6 + breath * 2.2 + K.chord_glow * 1.6) * (1 - d / 16)
      K.streaks(l, y, 3 + (d * 7) % 4, 14 + d % 3, K.drift_x * (0.4 + d * 0.05) + d * 7, nil,
        function(x) return K.heave(x + d * 5) * 0.4, hi * 5 * math.max(0, sin(x * 0.8 + d + T * 6)) end)
    end
    put(2 + K.bar_pulse, 0, wl, 128, 1)
    if wl < WL then put(1.5, 0, wl + 1, 128, 1) end
    -- rings on the water
    for i = #rings, 1, -1 do
      local r = rings[i]
      local age = T - r.t0
      if age > 3 then table.remove(rings, i)
      else
        local e = ease(age / 0.15) * (1 - age / 3)
        if r.small then
          K.ring(r.x, r.y, 1.5 + age * 4, 0.3, 6 * e, 16, 0, WL, 64)
          K.ring(r.x, r.y + 1, 1 + age * 2.5, 0.3, 4 * e, 10, 0, WL, 64)
        else
          K.ring(r.x, r.y, 1.5 + age * 5, 0.35, 6 * e, 18, 0, WL, 64)
          K.ring(r.x, r.y, 1 + age * 3, 0.35, 4 * e, 12, 0, WL, 64)
        end
      end
    end
    -- the far bank, the middle bed, the near reeds: further is dimmer
    for li, L in ipairs(LAYERS) do
      local lv = L.lv * (0.8 + 0.3 * bloom)
      for k, r in ipairs(layers[li]) do
        local l = stem(r, L, li * 100 + k, lv, li)
        -- the near reeds' reflections, broken in the water
        if li == 3 then
          for d = 2, 10, 3 do put(lv * 0.5, r.x - l * 0.08 * d + K.heave(r.x + d) * 0.6, WL + d, 2, 2) end
        end
      end
    end
    -- seeds drifting off on the air
    for i = #seeds, 1, -1 do
      local s = seeds[i]
      local age = T - s.t0
      if age > 5 then table.remove(seeds, i)
      else
        s.x = s.x + (s.vx + K.cur_u * 0.5) * DTS
        s.y = s.y + (s.vy + sin(age * 2 + s.ph) * 2) * DTS
        local l = 6 * ease(age / 0.3) * (1 - age / 5)
        put(l, s.x, s.y, 2, 1); put(l * 0.5, s.x - 1, s.y + 1, 1, 1)
      end
    end
    -- dragonflies: hover at their column, drift on, wings a-shimmer
    for i = #flies, 1, -1 do
      local f = flies[i]
      local age = T - f.t0
      if age > f.life then table.remove(flies, i)
      else
        local a = ease(age / 0.6) * ease((f.life - age) / 1)
        local x = f.x + f.dir * (math.max(0, age - 2) ^ 1.4) * 6 + sin(age * 2.3 + f.ph) * 1.5
        local y = f.y + sin(age * 1.7 + f.ph) * 2
        local lv = 7 * a
        put(lv, x, y, 4, 1)
        local wing = sin(K.NOW * 30 + f.ph) > 0 and 1 or 0
        put(lv * 0.6 + hi * 3 * a, x + 1, y - 1 - wing, 1, 1)
        put(lv * 0.6 + hi * 3 * a, x + 2, y - 1 - (1 - wing), 1, 1)
        put(lv * 0.5, x + 1, y + 1, 2, 1)
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "heron" then
        -- a heron stands in the shallows, still, then lifts away
        local hx = 30 + inc.s * 50
        if u < 0.7 then
          local stab = (inc.age % 5 > 4.3) and 2 or 0
          put(4 * e, hx, WL - 2, 1, 4); put(4 * e, hx + 2, WL - 2, 1, 4)
          put(5 * e, hx - 2, WL - 7, 6, 3); put(4 * e, hx - 4, WL - 6, 2, 1)
          put(5 * e, hx + 3, WL - 12 + stab, 1, 5); put(5.5 * e, hx + 4, WL - 12 + stab, 3, 1)
          for d = 2, 8, 3 do put(2 * e, hx - 1 + K.heave(hx + d) * 0.5, WL + d, 4, 1) end
        else
          local f = (u - 0.7) / 0.3
          K.bird(hx + f * 50, WL - 8 - f * 30, 5.5 * e, sin(K.NOW * 2.5), 2)
        end
      elseif inc.name == "warbler" then
        -- a small bird swings on the tallest near reed, then flits off
        local r = layers[3][1 + floor(inc.s * #layers[3]) % #layers[3]]
        local l = lean(r, LAYERS[3], -1, 3)
        local bx, by = r.x + l * 0.8, WL - r.h * 0.8
        if u < 0.8 then
          local sway = sin(K.T * 1.3) * 1.5
          put(6 * e, bx - 2 + sway, by - 3, 4, 3); put(6 * e, bx + 2 + sway, by - 4, 2, 2)
          put(4.5 * e, bx - 4 + sway, by - 1, 2, 1); put(5 * e, bx + 4 + sway, by - 3, 1, 1)
          -- it sings: now and then its head tips up
          if sin(K.T * 0.9) > 0.6 then put(5 * e, bx + 3 + sway, by - 6, 1, 2) end
        else
          local f = (u - 0.8) / 0.2
          K.bird(bx + f * 30, by - f * 12, 5 * e, sin(K.NOW * 9), 1)
        end
      else
        -- a fish jumps out of the shallows and back, rings after
        local fx, fy = 20 + inc.s * 80, WL + 6 + inc.s2 * 5
        local a = clamp((inc.age - 2) / 1.2, 0, 1)
        if a > 0 and a < 1 then
          local x, y = fx - 5 + a * 10, fy - 8 * sin(math.pi * a)
          put(8 * e, x, y, 3, 1); put(4 * e, x - 1, y + 1, 1, 1)
        end
        for k = 0, 2 do
          local age = inc.age - 3.2 - k * 0.5
          if age > 0 and age < 4 then K.ring(fx + 5, fy, 2 + age * 5, 0.35, 5 * e * (1 - age / 4), 18, 0, WL, 64) end
        end
      end
    end
    K.glitter(sample, 14)
  end

  M.init()
  return M
end
