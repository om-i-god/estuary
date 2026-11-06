-- rain: soft rain on the water. a far tree line stands dark against a pale
-- rainy sky, a nearer grassy bank comes down on the right, and low cloud
-- hangs over it all: the chord is four heavier clouds, across by pitch and
-- higher for higher tones, drifting to their new places when it changes,
-- and out_mid thickens the cloud. notes fall as drops from their pitch,
-- slanted by the wind of the current, and the motif decides the drop: a
-- long one, a pair, a heavy one that throws a crown, a slow drip that
-- leaves a bubble riding the water. the water heaves with out_lo and every
-- drop rings it; a misty band over the water rises with out_lo and breathes
-- on the bar. the water sounds bring the rain itself: curtains of it in the
-- distance and fine rings all over the water; out_hi glitters a drizzle
-- close by. a swell is a squall: the rain slants harder and the water
-- rises. a passing moment lets a rainbow stand over the trees for a while.
-- now and then a duck paddles across, a few birds cross under the cloud, or
-- a gust drives a curtain of rain over the water
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor = math.sin, math.cos, math.floor

  M.incidents = {{"duck", 22}, {"birds", 12}, {"gust", 12}}

  local GROUND = 54
  local DROP_MAX, SPLASH_MAX, DRIZZLE_MAX, FINE_MAX, BUB_MAX = 16, 12, 20, 8, 4
  local drops, splashes, drizzle, fine, bubbles = {}, {}, {}, {}, {}
  local fine_acc = 0
  local curtain_x = 0                     -- the far rain's drift, integrated
  local cloud_x = 0                       -- the low cloud's

  -- the far trees, on the far shore just above the water
  local trees = K.crowns(11, 17, GROUND - 3, 3, 10, 4, 7)
  local function poplars(x)
    return math.min(GROUND - 15 + math.abs(x - 41) * 1.6, GROUND - 13 + math.abs(x - 77) * 1.8)
  end
  local far = K.profile(function(x) return math.min(trees(x), poplars(x)) + 0.5 * sin(x * 1.1) end)
  -- the near bank: rising out of the water to the right
  local function bank_y(x)
    if x < 92 then return 99 end
    local u = (x - 92) / 36
    return GROUND - 1 - 13 * u ^ 0.8 + 0.8 * sin(x * 0.7)
  end
  local bank = K.profile(bank_y)
  -- the bank's grass texture, baked once
  local grass = K.bake(function(rec)
    for c = 46, 63 do
      local t = bank[c]
      if t < GROUND then
        for y = floor(t) + 2 + c % 2, GROUND - 1, 2 do
          if K.hash(c * 64 + y, 41) < 0.7 then rec(1, c * 2, y, 2, 1) end
        end
        rec(2, c * 2, t, 2, 1)
      end
    end
  end)
  -- a far rain curtain's slanted strokes, baked once and slid along
  local curtain = K.bake(function(rec)
    for k = 1, 26 do
      local x, y = K.hash(k, 42) * 128, 18 + K.hash(k, 43) * 26
      for j = 0, 3 do rec(1, x - j, y + j * 2, 1, 2) end
    end
  end)

  function M.clear() drops, splashes, drizzle, fine, bubbles, fine_acc = {}, {}, {}, {}, {}, 0 end

  -- the water the rain falls into
  local function surf_y(x)
    return GROUND - K.sw_disp * 2 + K.heave(x) * 0.8 + 0.5 * sin(x * 0.27 - K.T * 1.3 + K.drift_x * 0.05)
  end

  local function wind(x, y)
    local u = K.flow(x, y)
    return u * 0.6 - K.sw_disp * 8
  end

  function M.note(slot, midi, dur)
    local v = clamp(36 / ((tonumber(dur) or 0.5) + 0.5), 10, 50)          -- px/s
    local x = math.min(K.px(midi), 120)
    if slot == 2 then
      for k = 0, 1 do
        drops[#drops + 1] = {x = x - 2 + k * 4, y = -1 - k * 5, v = v * 1.1, t0 = K.T, lvl = 8, kind = 2}
      end
    elseif slot == 4 then
      drops[#drops + 1] = {x = x, y = -1, v = v * 0.55, t0 = K.T, lvl = 7, kind = 4}
    else
      drops[#drops + 1] = {x = x, y = -1, v = v * (slot == 3 and 1.3 or 1), t0 = K.T, lvl = slot == 3 and 10 or 11, kind = slot}
    end
    while #drops > DROP_MAX do table.remove(drops, 1) end
  end

  local function add_splash(x, lvl, kind)
    splashes[#splashes + 1] = {x = x, t0 = K.T, lvl = lvl, kind = kind or 1}
    if #splashes > SPLASH_MAX then table.remove(splashes, 1) end
    if kind == 4 and #bubbles < BUB_MAX then bubbles[#bubbles + 1] = {x = x, t0 = K.T} end
  end

  local function sample(u) local x = u * 92; return x, surf_y(x) - 1 end

  -- the chord's clouds: tone i -> x, y, presence
  local CL = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}, {0, 0, 0}}

  function M.draw()
    local T, DTS = K.T, K.DTS
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local mid, hi, nat, lo = A[K.MID], A[K.HI], A[K.NAT], A[K.LO]
    -- the pale rainy sky low down, behind the trees
    local pale = 1.3 + 0.9 * bloom
    K.gradient(28, GROUND - 1, function(y)
      local v = y < 37 and ((y - 29) / 8) ^ 2 * (0.55 + 0.2 * bloom) or 0.4 + pale * ((y - 37) / 16) ^ 1.5
      return v + breath * 1.2 * clamp((y - 36) / 14, 0, 1)
    end, far)
    -- the far rain: curtains of strokes in the distance, as many as the
    -- water sounds bring
    curtain_x = curtain_x - DTS * (1.2 + 3 * sw)
    if nat > 0.05 then K.blit(curtain, 0.5 + 1.3 * nat, K.drift_x * 0.1 + curtain_x, true) end
    -- the low cloud: banks of soft strokes drifting over, thicker with
    -- out_mid; the chord's four heavier clouds among them
    cloud_x = cloud_x + DTS * (0.6 + mid)
    for r = 0, 3 do
      local y = 2 + r * 4 + (r % 2)
      local off = K.drift_x * (0.5 + r * 0.15) + r * 23 + cloud_x
      for x = (off % 40) - 40, 127, 40 do
        local w = 12 + 8 * sin(x * 0.07 + r + T * 0.05) + 9 * mid
        put(1 + 0.8 * mid, x, y, w, 1)
        if r % 2 == 0 and w > 9 then put(1 + mid, x + 4, y + 1, w - 8, 1) end
      end
    end
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      local c = CL[i]
      if m then
        c[1] = K.cx(m) + 5 * sin(T * 0.04 + i * 2) + K.drift_x * 0.05
        c[2] = clamp(3 + (72 - m) / 36 * 12, 3, 16)
        c[3] = p
        local l = (1.6 + 0.6 * mid + 0.4 * bloom + 1.8 * K.chord_glow) * p
        -- a heaped cloud: a rounded top lit along its edge, a flatter base
        for r = -2, 1 do
          local hw = ({5, 8, 10, 9})[r + 3] * (1 + 0.3 * mid)
          local y = c[2] + r
          local x0 = c[1] - hw + (K.hash(i * 7 + r, 44) - 0.5) * 3
          put(l, x0, y, hw * 2, 1)
          if r == -2 then put(l + 1.2, x0 + 1, y, hw * 1.2, 1) end
          if r == -1 then put(l + 0.8, x0, y, 3, 1) end
        end
        -- its rain: a few dim strokes falling under it
        for k = 0, 3 do
          local x = c[1] - 8 + k * 5 + ((T * 6 + k * 3) % 5)
          put(1 * p + nat, x, c[2] + 4 + ((T * 9 + k * 7) % 12), 1, 3)
        end
      end
    end
    -- the near bank: dim grass, tufts leaning with the wind
    K.blit(grass, 1 + 0.5 * bloom)
    for c = 46, 63 do
      local t = bank[c]
      if t < GROUND then
        local lean = clamp(wind(c * 2, t) * 0.4 + nat * 1.2 * sin(T * 2 + c), -2, 2)
        put(2 + bloom, c * 2 + lean, t - 1 - (c % 3), 1, 2 + (c % 3))
      end
    end
    -- mist over the water, deeper with out_lo, brightening on the bar
    local mh = 2 + 5 * lo + 2 * sw
    for k = 0, floor(mh) do
      local y = GROUND - 2 - k - floor(sw * 2)
      local d = 1 - k / (mh + 1)
      K.streaks(1 + d * 0.8 + breath * 1.6 * d, y, 5 + k * 1.5, 22 + k * 4, K.drift_x * 0.8 + k * 9 + T * (1 + k * 0.1))
    end
    -- the water: a surface line, crests brighter, the trees' dark reflection
    -- with the pale sky's between
    for x = 0, 126, 2 do
      if x < 92 or bank_y(x) > GROUND + 1 then
        local y = surf_y(x)
        put(2 + (sin(x * 0.27 - T * 1.3 + K.drift_x * 0.05) > 0.6 and 1 or 0) + breath * 2, x, y, 2, 1)
      end
    end
    for d = 2, 9, 2 do
      local y = GROUND + d
      K.streaks(pale * 0.6 * (1 - d / 12) + breath * 1.8, y, 6, 8, K.drift_x * 0.5 + d * 3,
        function(x) return GROUND - d * 1.4 < K.at(far, x) end)
    end
    K.surface(0, GROUND + 4, 128, 64, 1, 8, 3)
    -- the rain on the water: fine rings everywhere, as many as the water
    -- sounds bring
    fine_acc = fine_acc + nat * 9 * DTS
    while fine_acc >= 1 do
      fine_acc = fine_acc - 1
      if #fine < FINE_MAX then fine[#fine + 1] = {x = K.rnd() * 124 + 2, y = GROUND + 1 + K.rnd() * 9, t0 = T} end
    end
    for i = #fine, 1, -1 do
      local f = fine[i]
      local age = T - f.t0
      if age > 0.8 then table.remove(fine, i)
      else
        K.ring(f.x, f.y, 1 + age * 5, 0.3, (2.5 + nat * 2) * (1 - age / 0.8), 8)
      end
    end
    -- drops, slanted by the wind, easing in at the top
    for i = #drops, 1, -1 do
      local d = drops[i]
      local wx = wind(d.x, d.y)
      d.y = d.y + d.v * (0.8 + 0.5 * A[K.AMP]) * DTS
      d.x = clamp(d.x + wx * DTS, 1, 125)
      local sy = surf_y(d.x)
      if d.y >= sy then
        add_splash(d.x, d.lvl, d.kind)
        table.remove(drops, i)
      else
        local lv = d.lvl * ease((T - d.t0) / 0.15) * (0.75 + 0.4 * A[K.AMP])
        local slant = wx / d.v
        if d.kind == 4 then
          -- a slow fat drip
          put(lv, d.x, d.y, 2, 3); put(lv * 0.5, d.x, d.y - 2, 2, 2)
        else
          local tail = floor(d.v * (d.kind == 2 and 0.2 or 0.35)) + 4
          local w = d.kind == 3 and 3 or 2
          put(lv, d.x, d.y, w, 2)
          for k = 2, tail, 2 do put(lv * (1 - k / (tail + 1)) * 0.6, d.x - k * slant + (w > 2 and 1 or 0), d.y - k, 1, 2) end
        end
      end
    end
    -- drizzle: as much as out_hi asks for, none at silence
    local want = hi * 45 * DTS
    while want > 0 and #drizzle < DRIZZLE_MAX do
      if K.rnd() < want then drizzle[#drizzle + 1] = {x = K.rnd() * 127, y = K.rnd() * 24 - 4} end
      want = want - 1
    end
    for i = #drizzle, 1, -1 do
      local d = drizzle[i]
      local wx = wind(d.x, d.y)
      d.y = d.y + 55 * DTS
      d.x = (d.x + wx * DTS) % 128
      if d.y >= math.min(surf_y(d.x), bank_y(d.x)) then
        table.remove(drizzle, i)
      else
        put(1 + hi * 3.5, d.x, d.y, 1, 2)
      end
    end
    -- each drop rings the water: the kind of drop decides the ring
    for i = #splashes, 1, -1 do
      local s = splashes[i]
      local age = T - s.t0
      local life = age / 0.9
      if life >= 1 then
        table.remove(splashes, i)
      else
        local y0 = surf_y(s.x)
        local lv = s.lvl * 0.6 * (1 - life) ^ 1.2
        if s.kind == 2 then
          K.ring(s.x - 2, y0, 1 + age * 8, 0.28, lv, 8); K.ring(s.x + 2, y0 + 1, 1 + age * 7, 0.28, lv, 8)
        else
          local rad = 1 + age * 13
          K.ring(s.x, y0, rad, 0.28, lv, math.max(6, floor(rad * 1.4)))
          if s.kind == 3 and age < 0.5 then
            -- a crown of droplets thrown up and out
            for k = -2, 2 do
              local a = age / 0.5
              put(lv * 1.3, s.x + k * 2 * (0.5 + a * 2), y0 - 2 - 6 * sin(math.pi * a) * (1 - math.abs(k) * 0.25), 1, 1)
            end
          end
        end
        if age < 0.2 then put(lv, s.x, y0 - 2 - age * 10, 1, 1) end
      end
    end
    -- slot 4's bubbles ride the water for a while
    for i = #bubbles, 1, -1 do
      local b = bubbles[i]
      local age = T - b.t0
      if age > 6 then table.remove(bubbles, i)
      else
        b.x = b.x + K.flow(b.x, GROUND) * DTS * 0.5
        local y = surf_y(b.x) - 1
        local l = 5 * ease(age / 0.3) * (1 - ease((age - 4) / 2))
        put(l, b.x - 1, y, 3, 1); put(l * 0.6, b.x, y - 1, 1, 1)
      end
    end
    -- a passing moment: a rainbow stands over the trees, faint and banded
    local ma = K.moment_age
    if ma < 16 then
      local e = ease(ma / 2.5) * (1 - ease((ma - 11) / 5))
      local cx, cy = 64, GROUND + 6
      for band = 0, 1 do
        local r = 44 - band * 3
        local l = e * (3 - band * 0.8) * (1 + 0.4 * bloom)
        for k = 0, 56 do
          local a = math.pi * (0.1 + 0.8 * k / 56)
          local x, y = cx - cos(a) * r * 1.3, cy - sin(a) * r
          -- broken by the rain, the way a rainbow is
          if (k + band) % 4 ~= 0 and y < K.at(far, x) - 1 then put(l, x, y, 2, 1) end
        end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "duck" then
        -- a duck paddles across, a V of wake opening behind it
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (-6 + u * 104) or (98 - u * 104)
        local y = surf_y(x)
        put(5 * e, x - 2, y - 2, 5, 2); put(5.5 * e, x + 2 * dir, y - 4, 2, 2); put(4 * e, x + 3 * dir + (dir > 0 and 1 or -1), y - 3, 1, 1)
        for k = 1, 6 do
          local wx = x - dir * k * 3
          put(3 * e * (1 - k / 7), wx, y + k * 0.6, 2, 1); put(3 * e * (1 - k / 7), wx, y - 1 - k * 0.3, 2, 1)
        end
      elseif inc.name == "birds" then
        -- a few birds cross under the cloud
        for k = 0, 4 do
          local x = -10 + u * 150 - k * 6 - (k % 2) * 3
          local y = 18 + k % 3 * 3 + sin(u * 6 + k) * 2
          K.bird(x, y, 5 * e, sin(K.NOW * 6 + k), 1)
        end
      else
        -- a gust drives a curtain of rain across the water
        local gx = -30 + u * 190
        for k = 0, 14 do
          local x = gx + (k * 37 % 30) - 15
          local y = 20 + (k * 13 % 30) + ((T * 30 + k * 7) % 8)
          if x > -2 and x < 128 then
            for j = 0, 2 do put(3 * e, x - j * 2, y + j * 2, 1, 2) end
          end
        end
        for k = 0, 8 do K.ring(gx - 12 + k * 3, GROUND + 3 + (k % 3) * 2, 1 + (T * 5 + k) % 4, 0.3, 3 * e, 6) end
      end
    end
    K.glitter(sample)
  end

  return M
end
