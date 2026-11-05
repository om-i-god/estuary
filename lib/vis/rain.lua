-- rain: soft rain on the water. a far tree line stands dark against a pale
-- rainy sky, a nearer grassy bank comes down on the right, and low cloud
-- drifts over. notes fall as drops from their pitch, slanted by the wind of
-- the current; a drizzle comes and goes with out_hi. the water heaves with
-- out_lo and every drop rings it; a misty band over the water rises with
-- out_lo
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease

  local GROUND = 54
  local DROP_MAX, SPLASH_MAX, DRIZZLE_MAX = 28, 14, 30
  local drops, splashes, drizzle = {}, {}, {}

  -- the far trees, on the far shore just above the water
  local trees = K.crowns(11, 17, GROUND - 3, 3, 10, 4, 7)
  local function poplars(x)
    return math.min(GROUND - 15 + math.abs(x - 41) * 1.6, GROUND - 13 + math.abs(x - 77) * 1.8)
  end
  local far = K.profile(function(x) return math.min(trees(x), poplars(x)) + 0.5 * math.sin(x * 1.1) end)
  -- the near bank: rising out of the water to the right
  local function bank_y(x)
    if x < 92 then return 99 end
    local u = (x - 92) / 36
    return GROUND - 1 - 13 * u ^ 0.8 + 0.8 * math.sin(x * 0.7)
  end
  local bank = K.profile(bank_y)

  function M.clear() drops, splashes, drizzle = {}, {}, {} end

  -- the water the rain falls into
  local function surf_y(x)
    return GROUND + K.heave(x) * 0.8 + 0.5 * math.sin(x * 0.27 - K.T * 1.3 + K.drift_x * 0.05)
  end

  local function wind(x, y)
    local u = K.flow(x, y)
    return u * 0.6
  end

  function M.note(slot, midi, dur)
    local v = clamp(36 / ((tonumber(dur) or 0.5) + 0.5), 10, 50)          -- px/s
    drops[#drops + 1] = {x = math.min(K.px(midi), 120), y = -1, v = v, t0 = K.T, lvl = 11 - (slot - 1) * 1.5}
    if #drops > DROP_MAX then table.remove(drops, 1) end
  end

  local function add_splash(x, lvl)
    splashes[#splashes + 1] = {x = x, t0 = K.T, lvl = lvl}
    if #splashes > SPLASH_MAX then table.remove(splashes, 1) end
  end

  local function sample(u) local x = u * 92; return x, surf_y(x) - 1 end

  function M.draw()
    local T, DTS = K.T, K.DTS
    -- the pale rainy sky low down, behind the trees; low cloud drifting above
    local pale = 1.3 + 0.8 * K.bloom
    K.gradient(27, GROUND - 1, function(y) return y < 37 and ((y - 27) / 10) ^ 1.6 or 1 + pale * ((y - 37) / 16) ^ 1.3 end, far)
    for r = 0, 3 do
      local y = 2 + r * 4 + (r % 2)
      local off = K.drift_x * (0.5 + r * 0.15) + r * 23 + T * 0.6
      for x = (off % 40) - 40, 127, 40 do
        local w = 14 + 8 * math.sin(x * 0.07 + r + T * 0.05)
        put(1, x, y, w, 1)
        if r % 2 == 0 then put(1, x + 4, y + 1, w - 8, 1) end
      end
    end
    -- the near bank: dim grass, tufts leaning with the wind
    for c = 46, 63 do
      local t = bank[c]
      if t < GROUND then
        for y = t + 2 + c % 2, GROUND - 1, 2 do put(1, c * 2, y, 2, 1) end
        local lean = clamp(wind(c * 2, t) * 0.4, -1, 1)
        put(2 + K.bloom, c * 2 + lean, t - 1 - (c % 3), 1, 2 + (c % 3))
        put(2, c * 2, t, 2, 1)
      end
    end
    -- mist over the water, deeper with out_lo
    local mh = 2 + 7 * A[K.LO] + 2 * K.sw_disp
    for k = 0, math.floor(mh) do
      local y = GROUND - 2 - k
      local d = 1 - k / (mh + 1)
      K.dashes(1 + d * 0.8, y, 7 + k * 2, 19 + k * 3, K.drift_x * 0.8 + k * 9 + T * (1 + k * 0.1))
    end
    -- the water: a surface line, crests brighter, the trees' dark reflection
    -- with the pale sky's between
    for x = 0, 126, 2 do
      if x < 92 or bank_y(x) > GROUND + 1 then
        local y = surf_y(x)
        put(2 + (math.sin(x * 0.27 - T * 1.3 + K.drift_x * 0.05) > 0.6 and 1 or 0), x, y, 2, 1)
      end
    end
    for d = 2, 9, 2 do
      local y = GROUND + d
      K.streaks(pale * 0.6 * (1 - d / 12), y, 6, 8, K.drift_x * 0.5 + d * 3,
        function(x) return GROUND - d * 1.4 < K.at(far, x) end)
    end
    K.surface(0, GROUND + 4, 128, 64, 1, 8, 3)
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
    local want = A[K.HI] * 40 * DTS
    while want > 0 and #drizzle < DRIZZLE_MAX do
      if K.rnd() < want then drizzle[#drizzle + 1] = {x = K.rnd() * 127, y = K.rnd() * 24 - 4} end
      want = want - 1
    end
    for i = #drizzle, 1, -1 do
      local d = drizzle[i]
      local wx = wind(d.x, d.y)
      d.y = d.y + 75 * DTS
      d.x = (d.x + wx * DTS) % 128
      if d.y >= math.min(surf_y(d.x), bank_y(d.x)) then
        table.remove(drizzle, i)
      else
        put(1 + A[K.HI] * 1.5, d.x, d.y, 1, 2)
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
          local a = k / n * K.TAU
          put(lv, s.x + math.cos(a) * rad, y0 + math.sin(a) * ry, 1, 1)
        end
        if age < 0.2 then put(lv, s.x, y0 - 2 - age * 10, 1, 1) end
      end
    end
    K.glitter(sample)
  end

  return M
end
