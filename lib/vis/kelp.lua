-- kelp: under the water, looking along a kelp forest. the surface glows
-- overhead, brighter as the bloom opens, the light fading with depth to a
-- sandy, stony floor. fronds rise from the floor and sway with the heave
-- (out_lo) and the current, their blades fluttering. notes release bubbles
-- that wobble up from the pitch's column; out_hi lets shafts of light down
-- from the surface. a small school of fish turns slowly in the middle water
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease

  local SURF, FLOOR = 4, 56
  local BUB_MAX = 40
  local bubbles, fronds, school

  local floor = K.profile(function(x)
    return FLOOR + 2 * math.sin(x * 0.05 + 1) + 1.5 * K.hash(x // 5, 61) - 3 * math.max(0, math.sin(x * 0.11 - 2)) ^ 3
  end)

  function M.init()
    bubbles, fronds, school = {}, {}, {}
    local n = 7
    for k = 1, n do
      local x = 8 + (k - 1) * 18 + 8 * K.hash(k, 62)
      fronds[k] = {x = x, h = 30 + 18 * K.hash(k, 63), ph = K.hash(k, 64) * 6, near = K.hash(k, 65) > 0.5}
    end
    for k = 1, 7 do
      school[k] = {a = k * 0.5, r = 6 + 4 * K.hash(k, 66), dy = (K.hash(k, 67) - 0.5) * 6}
    end
  end

  function M.clear() bubbles = {} end

  function M.note(slot, midi)
    local x = K.px(midi)
    for k = 1, 2 + (slot % 2) do
      if #bubbles < BUB_MAX then
        bubbles[#bubbles + 1] = {x = x + (K.rnd() - 0.5) * 3, y = FLOOR - 4 - K.rnd() * 6 - k * 3, t0 = K.T,
          r = K.rnd() < 0.3 and 2 or 1, ph = K.rnd() * 6, v = 7 + K.rnd() * 5}
      end
    end
  end

  -- a frond's spine at height s above the floor: leaning with the heave,
  -- the current and the frond's own slow sway, more toward the tip
  local function spine(f, s)
    local T = K.T
    local u = s / f.h
    local push = K.flow(f.x, FLOOR - s) * 0.5 + K.heave(f.x - s * 0.5) * (1 + 1.5 * A[K.LO])
    return f.x + (push + math.sin(T * 0.5 + f.ph + s * 0.08) * 2.5) * u * u
  end

  local function sample(u, v) return u * 127, SURF + 1 + v * 3 end

  function M.draw()
    local T, DTS = K.T, K.DTS
    local bloom = K.bloom
    -- the water: light from the surface fading with depth
    local glow = 1.0 + 1.0 * bloom
    K.gradient(SURF + 1, FLOOR, function(y) local u = (y - SURF) / (26 - 7 * bloom); return glow * math.max(0, 1 - u) ^ 2 end, nil)
    -- the surface seen from below: a bright wavering skin
    for x = 0, 126, 2 do
      local w = math.sin(x * 0.12 - T * 1.2 + K.drift_x * 0.05) + 0.6 * math.sin(x * 0.31 + T * 0.7)
      put(2.5 + bloom + (w > 0.6 and 1.5 or 0), x, SURF + (w > 0 and 0 or 1) + K.heave(x) * 0.25, 2, 1)
    end
    -- shafts of light down from the surface, as many as out_hi lets in
    local hi = A[K.HI]
    for k = 0, 4 do
      local a = clamp(hi * 1.6 - k * 0.25, 0, 1) * (0.6 + 0.4 * math.sin(T * 0.3 + k * 2))
      if a > 0.05 then
        local x0 = 14 + k * 26 + 8 * math.sin(T * 0.05 + k) + K.drift_x * 0.05 % 4
        for y = SURF + 2, 46, 2 do
          local d = (y - SURF) / 42
          put(a * 3.5 * (1 - d) + 0.5, x0 + y * 0.35, y, 1 + d * 2.5, 1)
        end
      end
    end
    -- the floor: sand with stones, a dim stipple
    for c = 0, 63 do
      local t = math.floor(floor[c] + 0.5)
      put(2, c * 2, t, 2, 1)
      for y = t + 2, 63, 2 do
        if K.hash(c * 64 + y, 68) < 0.4 then put(1, c * 2 + (y % 2), y, 1, 1) end
      end
    end
    -- the school: small fish turning slowly together
    local cx = 64 + 30 * math.sin(T * 0.045) + K.cur_u * 2
    local cy = 26 + 6 * math.sin(T * 0.07)
    for k, f in ipairs(school) do
      f.a = f.a + DTS * (0.5 + 0.3 * K.energy)
      local x = cx + math.cos(f.a) * f.r * 1.6
      local y = cy + math.sin(f.a) * f.r * 0.5 + f.dy
      local dir = -math.sin(f.a) >= 0 and 1 or -1
      put(2.5 + bloom, x, y, 2, 1)
      put(1.5, x - dir, y, 1, 1)
    end
    -- the fronds: a stalk with blades along it, near ones brighter and wider
    for _, f in ipairs(fronds) do
      local lv = f.near and 4 or 2.5
      local w = f.near and 2 or 1
      local base = K.at(floor, f.x)
      for s = 0, f.h, 2 do
        local x = spine(f, s)
        local y = base - s
        put(lv, x, y - 2, w, 2)
        if s % 4 == 2 and s > 4 then
          -- a long blade streaming up and out, fluttering; the current
          -- turns them all the same way
          local side = (s % 8 == 2) and 1 or -1
          if K.cur_u > 1.2 then side = 1 elseif K.cur_u < -1.2 then side = -1 end
          local fl = math.sin(T * 1.6 + s * 0.4 + f.ph)
          local len = 3 + (f.near and 2 or 1) + fl
          local bx = side > 0 and x + w or x - len
          put(lv * 0.75, bx, y - 2, len, 1)
          if f.near then put(lv * 0.5, bx + side * 2, y - 3 - (fl > 0 and 1 or 0), len - 2, 1) end
        end
      end
      -- a float at the tip
      local tx = spine(f, f.h)
      put(lv + 1, tx - 0.5, base - f.h - 3, 2, 2)
    end
    -- bubbles: rise, wobble, swell a little and vanish at the surface
    for i = #bubbles, 1, -1 do
      local b = bubbles[i]
      local age = T - b.t0
      b.y = b.y - b.v * DTS * (1 + 0.1 * age)
      local x = b.x + math.sin(age * 4 + b.ph) * 1.2 + K.flow(b.x, b.y) * 0.1
      b.x = b.x + K.flow(b.x, b.y) * DTS * 0.4
      if b.y <= SURF + 1 then table.remove(bubbles, i)
      else
        local lv = (5 + A[K.AMP] * 3) * ease(age / 0.3)
        if b.r == 2 then
          put(lv, x - 1, b.y, 1, 2); put(lv, x + 2, b.y, 1, 2)
          put(lv, x, b.y - 1, 2, 1); put(lv * 0.6, x, b.y + 2, 2, 1)
          put(lv + 2, x, b.y, 1, 1)
        else
          put(lv, x, b.y, 1, 1); put(lv * 0.5, x + 1, b.y - 1, 1, 1)
        end
      end
    end
    K.glitter(sample, 14)
  end

  M.init()
  return M
end
