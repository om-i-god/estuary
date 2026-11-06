-- kelp: under the water, looking along a kelp forest. the surface glows
-- overhead, brighter as the bloom opens, the light fading with depth to a
-- sandy, stony floor; far fronds stand dim in the haze behind. the chord
-- comes down as four shafts of light from the surface, across by pitch,
-- moving to their new places when it changes; out_hi makes them and the
-- floor's caustics shimmer. fronds rise from the floor and sway with the
-- heave (out_lo) and the current, their blades fluttering with the sound. a
-- note at its pitch: a column of bubbles (the first motif), one big wobbling
-- bubble (the second), a small fish darting out (the third), a glint
-- running up the nearest frond (the fourth). a school turns slowly in the
-- middle water, wider and brighter with out_mid; the water sounds stir up
-- drifting motes. the bar breathes in the surface; a swell is a surge that
-- leans every frond; a passing moment sends a turtle gliding through. now
-- and then a seal passes far off, a jellyfish drifts up, or a crab walks
-- the floor
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor = math.sin, math.cos, math.floor

  M.incidents = {{"seal", 12}, {"jelly", 22}, {"crab", 16}}

  local SURF, FLOOR = 4, 56
  local BUB_MAX, DART_MAX, GLINT_MAX = 36, 4, 3
  local bubbles, fronds, school, darts, glints

  local floor_p = K.profile(function(x)
    return FLOOR + 2 * sin(x * 0.05 + 1) + 1.5 * K.hash(x // 5, 61) - 3 * math.max(0, sin(x * 0.11 - 2)) ^ 3
  end)
  -- the floor's sand and stones, baked once
  local sand = K.bake(function(rec)
    for c = 0, 63 do
      local t = floor(floor_p[c] + 0.5)
      rec(2, c * 2, t, 2, 1)
      for y = t + 2, 63, 2 do
        if K.hash(c * 64 + y, 68) < 0.4 then rec(1, c * 2 + (y % 2), y, 1, 1) end
      end
    end
  end)
  -- far fronds in the haze, baked once: thin dim stalks with a few blades
  local far = K.bake(function(rec)
    for k = 1, 7 do
      local x = 4 + (k - 1) * 18 + 8 * K.hash(k, 69)
      local h = 22 + 16 * K.hash(k, 70)
      for s = 0, h, 3 do
        local xx = x + 2 * sin(s * 0.09 + k)
        rec(1, xx, FLOOR - 2 - s, 1, 3)
        if s % 6 == 3 then rec(1, xx + ((s // 6) % 2 == 0 and 1 or -3), FLOOR - 3 - s, 3, 1) end
      end
    end
  end)
  local CAUSTIC = K.scatter(70, 2, FLOOR - 1, 126, 63, 71)
  local MOTES = K.scatter(60, 2, 8, 126, 54, 72)

  function M.init()
    bubbles, fronds, school, darts, glints = {}, {}, {}, {}, {}
    local n = 7
    for k = 1, n do
      local x = 8 + (k - 1) * 18 + 8 * K.hash(k, 62)
      fronds[k] = {x = x, h = 30 + 18 * K.hash(k, 63), ph = K.hash(k, 64) * 6, near = K.hash(k, 65) > 0.5}
    end
    for k = 1, 12 do
      school[k] = {a = k * 0.5, r = 6 + 4 * K.hash(k, 66), dy = (K.hash(k, 67) - 0.5) * 6}
    end
  end

  function M.clear() bubbles, darts, glints = {}, {}, {} end

  -- (no new bubbles while the water already holds as many as it can; the
  -- ones there rise out on their own)
  local function add_bubble(x, y, r, v)
    if #bubbles < BUB_MAX then
      bubbles[#bubbles + 1] = {x = x, y = y, t0 = K.T, r = r, ph = K.rnd() * 6, v = v}
    end
  end

  function M.note(slot, midi)
    local x = K.px(midi)
    if slot == 1 then
      for k = 1, 5 do add_bubble(x + (K.rnd() - 0.5) * 3, FLOOR - 4 - k * 3, k % 2 + 1, 7 + K.rnd() * 5) end
    elseif slot == 2 then
      add_bubble(x, FLOOR - 8, 3, 6)
    elseif slot == 3 then
      -- (capped lists: the oldest fades out quickly when full)
      K.cap_add(darts, {x = x, y = 18 + (1 - K.pu(midi)) * 26, t0 = K.T, dir = K.rnd() < 0.5 and -1 or 1}, DART_MAX)
    else
      local best, bd
      for k, f in ipairs(fronds) do
        local d = math.abs(f.x - x)
        if not bd or d < bd then best, bd = k, d end
      end
      K.cap_add(glints, {k = best, t0 = K.T}, GLINT_MAX)
    end
  end

  -- a frond's spine at height s above the floor: leaning with the heave,
  -- the current, a swell's surge and the frond's own slow sway, more toward
  -- the tip
  local function spine(f, s)
    local T = K.T
    local u = s / f.h
    local push = K.flow(f.x, FLOOR - s) * 0.5 + K.heave(f.x - s * 0.5) * (1 + 1.5 * A[K.LO]) - K.sw_disp * 7
    return f.x + (push + sin(T * 0.5 + f.ph + s * 0.08) * 2.5) * u * u
  end

  local function sample(u, v) return u * 127, SURF + 1 + v * 3 end

  -- the water's light from above, made once (its inputs set each frame)
  local F_glow, F_bloom = 1, 0
  local function water_glow(y) local u = (y - SURF) / (26 - 7 * F_bloom); return F_glow * math.max(0, 1 - u) ^ 2.8 end

  function M.draw()
    local T, DTS = K.T, K.DTS
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat = A[K.HI], A[K.MID], A[K.NAT]
    -- the water: light from the surface fading with depth, breathing on the bar
    F_glow, F_bloom = 0.75 + 0.9 * bloom + 1.3 * breath, bloom
    K.gradient(SURF + 1, FLOOR, water_glow, nil)
    K.blit(far, 1 + 0.5 * bloom, K.drift_x * 0.1, true)
    -- the surface seen from below: a bright wavering skin
    for x = 0, 126, 2 do
      local w = sin(x * 0.12 - T * 1.2 + K.drift_x * 0.05) + 0.6 * sin(x * 0.31 + T * 0.7)
      put(2.5 + bloom + breath * 3 + K.bj(x) + (w > 0.6 and 1.5 or 0) + hi * 4 * math.max(0, sin(x * 1.3 + T * 5)), x, SURF + (w > 0 and 0 or 1) + K.heave(x) * 0.25, 2, 1)
    end
    -- the chord's shafts of light down from the surface, shimmering with
    -- out_hi
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local a = p * (0.8 + 0.6 * bloom + 1.2 * K.chord_glow)
        local x0 = K.cx(m) - 12 + 3 * sin(T * 0.05 + i) + 2 * sin(K.drift_x * 0.03 + i)
        for y = SURF + 2, 48, 2 do
          local d = (y - SURF) / 44
          local fl = 1 + hi * 1.2 * sin(T * 3 + y * 0.7 + i)
          put((a * 3 * (1 - d) + 0.5) * fl, x0 + y * 0.35, y, 1 + d * 3, 1)
        end
      end
    end
    -- the floor: sand with stones, and the light playing on it
    K.blit(sand, 1 + 0.3 * bloom)
    K.twinkle(CAUSTIC, math.max(hi, 0.15 * bloom), 7)
    -- drifting motes stirred up by the water sounds
    if nat > 0.03 then
      for i = 1, #MOTES, 2 do
        local x = (MOTES[i] + K.drift_x * 0.4 + T * 1.5) % 128
        local y = MOTES[i + 1] + sin(T * 0.4 + i) * 3
        if (i // 2) % 10 < nat * 10 then put(2.5 + 3 * nat, x, y, 2, 1) end
      end
    end
    -- the school: small fish turning slowly together, wider and brighter
    -- with out_mid
    local cx = 64 + 30 * sin(T * 0.045) + K.cur_u * 2
    local cy = 26 + 6 * sin(T * 0.07)
    local ns = 6 + floor(mid * 6 + 0.5)
    for k = 1, ns do
      local f = school[k]
      f.a = f.a + DTS * (0.5 + 0.4 * K.energy)
      local spread = 1.6 + 0.8 * mid
      local x = cx + cos(f.a) * f.r * spread
      local y = cy + sin(f.a) * f.r * 0.5 * (1 + 0.5 * mid) + f.dy
      local dir = -sin(f.a) >= 0 and 1 or -1
      put(2.5 + bloom + 3.2 * mid, x, y, 2 + floor(mid * 1.5), 1)
      put(1.5 + 1.5 * mid, x - dir, y, 1, 1)
    end
    -- the fronds: a stalk with blades along it, near ones brighter and wider
    for k, f in ipairs(fronds) do
      local lv = f.near and 4 or 2.5
      local w = f.near and 2 or 1
      local base = K.at(floor_p, f.x)
      local gl = 0
      local gcf = 1
      for _, g in ipairs(glints) do
        local v = 1 - (T - g.t0) / 2.5
        if g.k == k and v > gl then gl, gcf = v, (K.cap_fade(g)) end
      end
      for s = 0, f.h, 2 do
        local x = spine(f, s)
        local y = base - s
        -- a glint running up the frond: a bright band climbing it
        local run = gl > 0 and math.max(0, 1 - math.abs(s / f.h - (1 - gl)) * 5) * 5 * gcf or 0
        put(lv + run, x, y - 2, w, 2)
        if s % 4 == 2 and s > 4 then
          -- a long blade streaming up and out, fluttering with the sound;
          -- the current turns them all the same way
          local side = (s % 8 == 2) and 1 or -1
          if K.cur_u > 1.2 then side = 1 elseif K.cur_u < -1.2 then side = -1 end
          local fl = sin(T * (1.6 + 0 * A[K.AMP]) + s * 0.4 + f.ph) * (1 + 1.2 * A[K.AMP])
          local len = 3 + (f.near and 2 or 1) + fl
          local bx = side > 0 and x + w or x - len
          put(lv * 0.75 + run * 0.6, bx, y - 2, len, 1)
          if f.near then put(lv * 0.5, bx + side * 2, y - 3 - (fl > 0 and 1 or 0), len - 2, 1) end
        end
      end
      -- a float at the tip
      local tx = spine(f, f.h)
      put(lv + 1, tx - 0.5, base - f.h - 3, 2, 2)
    end
    for i = #glints, 1, -1 do
      local _, done = K.cap_fade(glints[i])
      if T - glints[i].t0 > 2.5 or done then table.remove(glints, i) end
    end
    -- small fish darting out from their pitch
    for i = #darts, 1, -1 do
      local d = darts[i]
      local age = T - d.t0
      local cf, done = K.cap_fade(d)
      if age > 2.5 or done then table.remove(darts, i)
      else
        local e = ease(age / 0.15) * (1 - ease((age - 1.2) / 1.3)) * cf
        local x = d.x + d.dir * (1 - math.exp(-age * 3)) * 22
        put(7 * e, x, d.y, 3, 1); put(4 * e, x - d.dir * 2, d.y, 1, 1)
        put(3 * e, x - d.dir * 4, d.y - 1, 1, 1); put(3 * e, x - d.dir * 4, d.y + 1, 1, 1)
      end
    end
    -- bubbles: rise, wobble, swell a little and vanish at the surface
    for i = #bubbles, 1, -1 do
      local b = bubbles[i]
      local age = T - b.t0
      b.y = b.y - b.v * DTS * (1 + 0.1 * age)
      local x = b.x + sin(age * 4 + b.ph) * (b.r == 3 and 2 or 1.2) + K.flow(b.x, b.y) * 0.1
      b.x = b.x + K.flow(b.x, b.y) * DTS * 0.4
      if b.y <= SURF + 1 then table.remove(bubbles, i)
      else
        local lv = (5 + A[K.AMP] * 3) * ease(age / 0.3)
        if b.r == 3 then
          -- one big bubble, its rim lit, wobbling out of round
          local rx = 3 + 0.6 * sin(age * 5)
          K.ring(x, b.y, rx, 1.1 - 0.15 * sin(age * 5), lv, 12)
          put(lv + 2, x - 1, b.y - 2, 1, 1)
        elseif b.r == 2 then
          put(lv, x - 1, b.y, 1, 2); put(lv, x + 2, b.y, 1, 2)
          put(lv, x, b.y - 1, 2, 1); put(lv * 0.6, x, b.y + 2, 2, 1)
          put(lv + 2, x, b.y, 1, 1)
        else
          put(lv, x, b.y, 1, 1); put(lv * 0.5, x + 1, b.y - 1, 1, 1)
        end
      end
    end
    -- the moment: a turtle glides through the middle water
    local ma = K.moment_age
    if ma < 16 then
      local e = ease(ma / 2) * (1 - ease((ma - 11) / 5))
      local tx, ty = -14 + ma * 9.5, 30 + sin(ma * 0.4) * 4
      local fl = sin(ma * 2)
      put(1.5 * e, tx - 5, ty - 3, 11, 7)
      put(5.5 * e, tx - 4, ty - 2, 9, 5); put(6.5 * e, tx - 2, ty - 3, 5, 1)
      put(6 * e, tx + 5, ty - 1, 3, 2)
      put(4 * e, tx - 1 + fl, ty - 5 - fl, 3, 2); put(4 * e, tx - 1 + fl, ty + 3 + fl, 3, 2)
      put(3.5 * e, tx - 6, ty - 3 - fl * 0.5, 2, 1); put(3.5 * e, tx - 6, ty + 2 + fl * 0.5, 2, 1)
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "seal" then
        -- a seal passes far off, a long sleek shape, rolling once
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (-20 + u * 170) or (150 - u * 170)
        local y = 16 + inc.s2 * 10 + sin(u * 6) * 3
        local fl = sin(K.T * 3)
        put(5 * e, x - 7, y, 15, 3); put(6 * e, x - 4, y, 9, 1); put(5 * e, x + 7 * dir - 1, y, 3, 2)
        put(4 * e, x - 10 * dir - 1, y - 1 + fl, 3, 1); put(4 * e, x - 10 * dir - 1, y + 3 - fl, 3, 1)
      elseif inc.name == "jelly" then
        -- a jellyfish drifts up, its bell pulsing, its tendrils trailing
        local x = 20 + inc.s * 88 + sin(inc.age * 0.5) * 4
        local y = 50 - u * 40
        local pulse = 0.5 + 0.5 * sin(inc.age * 2.2)
        local hw = 4 + pulse
        put(7.5 * e, x - hw, y, hw * 2, 1); put(6.5 * e, x - hw + 1, y - 1, hw * 2 - 2, 1); put(5.5 * e, x - 2, y - 2, 4, 1)
        put(3 * e, x - hw + 1, y - 3, hw * 2 - 2, 1)
        for k = -1, 1 do
          for j = 1, 5 do put(4 * e * (1 - j / 6), x + k * 2 + sin(inc.age * 1.5 + j + k) * 0.8, y + 1 + j * 1.5, 1, 2) end
        end
      else
        -- a crab walks sideways along the floor
        local x = 10 + inc.s * 30 + u * 70
        local y = K.at(floor_p, x) - 1
        local leg = sin(K.NOW * 12) > 0 and 1 or 0
        put(7.5 * e, x - 3, y - 3, 7, 3)
        put(6 * e, x - 5, y - leg, 2, 1); put(6 * e, x + 4, y - 1 + leg, 2, 1)
        put(6 * e, x - 5, y - 2 + leg, 2, 1); put(6 * e, x + 4, y - 2 - leg + 1, 2, 1)
        put(7 * e, x - 4, y - 6, 2, 2); put(7 * e, x + 3, y - 6, 2, 2)
      end
    end
    K.glitter(sample, 14)
  end

  M.init()
  return M
end
