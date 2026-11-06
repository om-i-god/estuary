-- flock: a flock of small waders over the mudflats. a far shore lies under
-- a pale sky with long clouds; below, channels wind across the mud and
-- shine as the water rises with the water sounds, a swell and the bloom,
-- and salt-marsh grass stands close by. the chord lies on the mud as four
-- shining pools, across by pitch, bigger for lower tones, the water
-- finding its new places when the chord moves. the flock keeps together by
-- simple rules (stay close, match your neighbours, do not crowd), drifts
-- the way the tide is turning and spreads wider as the sound grows; out_mid
-- quickens and brightens its wingbeats, out_lo lifts and drops it slowly, a
-- swell lifts it higher. a note at its pitch: a few birds bank and catch
-- the light (the first motif), one bird flares up (the second), a pool
-- ripples on the mud (the third), one bird peels off in a loop (the
-- fourth). the bar breathes in the sky and the channels. a passing moment
-- gathers the flock into a slow wheeling murmuration. now and then a heron
-- stalks along a channel, a curlew probes the mud, or a far flock passes
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor = math.sin, math.cos, math.floor

  M.incidents = {{"heron", 22}, {"curlew", 18}, {"far", 12}}

  local N = 18
  local HZ = 40                           -- the far shore
  local MARK_MAX = 8
  local birds, marks

  function M.init()
    birds, marks = {}, {}
    for k = 1, N do
      birds[k] = {x = 50 + 28 * K.hash(k, 81), y = 14 + 12 * K.hash(k, 82),
        vx = 6 + 4 * K.hash(k, 83), vy = (K.hash(k, 84) - 0.5) * 3, ph = K.hash(k, 85) * 6, lit = -99}
    end
  end

  function M.clear()
    for _, b in ipairs(birds) do b.lit = -99 end
    marks = {}
  end

  -- the mud: a fixed stipple, baked once
  local mud = K.bake(function(rec)
    for y = HZ + 2, 63, 2 do
      for x = (y * 3) % 7, 127, 7 do
        if K.hash(x * 64 + y, 88) < 0.3 then rec(1, x, y, 2, 1) end
      end
    end
    for x = 0, 126, 6 do rec(1.5, x + 2 * K.hash(x, 86), HZ - 1 - floor(2 * K.hash(x, 87)), 2, 1) end
  end)
  -- long thin clouds in the pale sky, baked once and slid slowly round
  local clouds = K.bake(function(rec)
    for k = 1, 4 do
      local cx, cy, w = K.hash(k, 89) * 128, 6 + 14 * K.hash(k, 90), 24 + 20 * K.hash(k, 91)
      rec(1.4, cx - w * 0.5, cy, w, 1)
      rec(1, cx - w * 0.35, cy + 1, w * 0.6, 1)
    end
  end)
  -- salt-marsh grass along the near edge: {x, height, phase}
  local GRASS = {}
  for k = 1, 16 do GRASS[k] = {k * 8 - 4 + 3 * K.hash(k, 92), 3 + 4 * K.hash(k, 93), K.hash(k, 94) * 6} end

  -- the few birds nearest a column bank and swing out toward it
  local function nearest(x, n)
    for _ = 1, n do
      local best, bd
      for _, b in ipairs(birds) do
        local d = math.abs(b.x - x)
        if K.T - b.lit > 3 and (not bd or d < bd) then best, bd = b, d end
      end
      if best then best.lit, best.go = K.T, x end
    end
  end
  local WET = K.scatter(84, 2, HZ + 3, 126, 63, 95)

  function M.note(slot, midi)
    local x = K.px(midi)
    if slot == 1 then
      nearest(x, 3)
    else
      -- (when the list is full, the oldest mark fades out quickly)
      K.cap_add(marks, {slot = slot, x = x, u = K.pu(midi), t0 = K.T}, MARK_MAX)
    end
  end

  -- one step of the flock's rules; a moment draws it into a wheel
  local function step(dt)
    local T = K.T
    local ma = K.moment_age
    local wheel = ma < 14 and ease(ma / 2) * (1 - ease((ma - 10) / 4)) or 0
    local spread = (5.5 + 7 * K.energy) * (1 - 0.35 * wheel)
    local tx = 64 + 30 * sin(T * 0.045) + 18 * K.tide_dir
    local ty = 20 + 6 * sin(T * 0.07 + 1) - 9 * K.sw_disp + 4 * A[K.LO] * sin(T * 0.3)
    if wheel > 0 then
      tx = tx + wheel * 24 * cos(ma * 0.9)
      ty = ty + wheel * 9 * sin(ma * 0.9)
    end
    local vmax = 9 + 6 * K.energy + 6 * wheel
    local cx, cy, ax, ay = 0, 0, 0, 0
    for _, b in ipairs(birds) do cx, cy, ax, ay = cx + b.x, cy + b.y, ax + b.vx, ay + b.vy end
    cx, cy, ax, ay = cx / N, cy / N, ax / N, ay / N
    for i, b in ipairs(birds) do
      local fx = (cx - b.x) * (0.25 + 0.3 * wheel) + (ax - b.vx) * 0.6 + (tx - cx) * (0.15 + 0.25 * wheel) - b.vx * 0.05
      local fy = (cy - b.y) * (0.25 + 0.3 * wheel) + (ay - b.vy) * 0.6 + (ty - cy) * (0.15 + 0.25 * wheel)
      for j, o in ipairs(birds) do
        if j ~= i then
          local dx, dy = b.x - o.x, b.y - o.y
          local d2 = dx * dx + dy * dy
          if d2 < spread * spread and d2 > 1e-4 then
            local d = math.sqrt(d2)
            local push = (spread - d) / spread * 9
            fx, fy = fx + dx / d * push, fy + dy / d * push
          end
        end
      end
      -- the air: a little lift and wander, and the edges of the screen
      fy = fy + sin(T * 0.9 + b.ph) * 1.5 + K.heave(b.x) * 0.8
      if b.go and T - b.lit < 2 then fx = fx + (b.go - b.x) * 1.2 end
      if b.x < 8 then fx = fx + (8 - b.x) * 2 elseif b.x > 120 then fx = fx - (b.x - 120) * 2 end
      if b.y < 5 then fy = fy + (5 - b.y) * 2 elseif b.y > HZ - 6 then fy = fy - (b.y - HZ + 6) * 2 end
      b.vx, b.vy = b.vx + fx * dt, b.vy + fy * dt
      local sp = math.sqrt(b.vx * b.vx + b.vy * b.vy)
      if sp > vmax then b.vx, b.vy = b.vx / sp * vmax, b.vy / sp * vmax end
      if sp < 3 then b.vx = b.vx + (b.vx >= 0 and 1 or -1) * (3 - sp) end
    end
    for _, b in ipairs(birds) do b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt end
  end

  local function sample(u, v) return u * 127, HZ + 6 + v * 16 end

  -- the sky's light, made once (its strength is set each frame)
  local F_glow = 1
  local function sky_glow(y) local u = (HZ - y) / 24; return F_glow * math.max(0, 1 - u) ^ 2.5 end

  -- the channels across the mud: y of channel k at x
  local function chan(k, x)
    if k == 1 then return HZ + 6 + 2 * sin(x * 0.05 + 1) end
    if k == 2 then return 51 + 4 * sin(x * 0.035 + 2.5) + 1.5 * sin(x * 0.11) end
    return 58 + 3 * sin(x * 0.045 - 1) + 1.5 * sin(x * 0.13 + 2)
  end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat = A[K.HI], A[K.MID], A[K.NAT]
    -- the flock moves on its own small steps, whatever the frame rate
    local left = K.DTS
    while left > 1e-6 do
      local dt = math.min(left, 0.05)
      step(dt)
      left = left - dt
    end
    -- the sky: pale low down, over the far shore, breathing on the bar
    F_glow = 0.72 + 0.55 * bloom + 1.3 * breath
    K.gradient(14, HZ - 1, sky_glow)
    K.blit(clouds, 0.9 + 0.6 * bloom, K.drift_x * 0.05 + T * 0.25, true)
    put(2, 0, HZ, 128, 1)
    K.blit(mud, 1)
    K.twinkle(WET, hi, 8)
    -- the chord's pools on the mud, shining with the sky
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local px = K.cx(m)
        local py = 45 + ((i * 5) % 4) * 4
        local r = clamp(4 + (60 - m) * 0.15, 3, 9)
        local l = p * (2 + 1.2 * bloom + 1.5 * K.chord_glow + breath)
        for dy = -1, 1 do
          local hw = r * (1 - math.abs(dy) * 0.35)
          put(l * (dy == -1 and 1.15 or 1), px - hw, py + dy, hw * 2, 1)
        end
        put(l * 0.6 + hi * 3 * math.max(0, sin(T * 4 + i)), px - r * 0.4, py - 1, 2, 1)
      end
    end
    -- the channels: as the water rises they widen and shine, and the light
    -- runs along them
    local water = clamp(0.3 + 0.6 * nat + 0.4 * sw + 0.2 * bloom, 0, 1)
    for k = 1, 3 do
      local w = 1 + floor(water * (k == 1 and 0.8 or 1.6))
      for x = 0, 126, 2 do
        local y = chan(k, x) + K.heave(x * 1.5 + k * 20) * 0.35
        local sh = sin(x * 0.2 - T * 1.1 + K.drift_x * 0.1 + k)
        local l = 1 + water * 1.6 + (sh > 0.7 and 1 or 0) + breath * 1.2 + K.bj(x + k * 64)
        put(l, x, y, 2, w)
        local g = hi * 3.5 * math.max(0, sin(x * 1.3 + T * 7 + k))
        if g > 0.5 then put(l + g, x, y, 1, 1) end
      end
    end
    -- the notes that are not banking birds
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4 or done then table.remove(marks, i)
      else
        local e = (ease(age / 0.2) * (1 - ease((age - 1) / 3))) * cf
        if mk.slot == 2 then
          -- one bird flares up out of the flock near the pitch
          local x, y = mk.x + age * 5, 14 + (1 - mk.u) * 14 - sin(math.min(1, age / 1.5) * math.pi) * 6
          K.bird(x, y, 8 * e, sin(K.NOW * 9), 2)
        elseif mk.slot == 3 then
          -- a pool ripples on the mud
          local y = 47 + (1 - mk.u) * 10
          K.ring(mk.x, y, 1.5 + age * 3.5, 0.4, 5 * e, 16)
          put(5 * e, mk.x - 2, y, 5, 1)
        else
          -- one bird peels off in a slow loop
          local a = age * 1.8
          local x, y = mk.x + sin(a) * 10, 18 + (1 - mk.u) * 12 - cos(a) * 6
          K.bird(x, y, 7 * e, sin(K.NOW * 8), 1)
        end
      end
    end
    -- the birds
    local flap = 7 + 6 * mid
    for _, b in ipairs(birds) do
      local age = T - b.lit
      local catch = age < 1.6 and sin(math.min(1, age / 1.6) * math.pi) or 0
      local x, y = floor(b.x + 0.5), floor(b.y + 0.5)
      local lv = 4 + 1.5 * bloom + catch * 5 + 2 * mid
      if catch > 0.3 then
        -- banking: the wings flat and wide, the light along them
        put(lv, x - 2, y, 5, 1)
        put(lv * 0.5, x, y + 1, 1, 1)
      else
        local f = sin(K.NOW * (flap + b.ph * 0.3) + b.ph)
        local wy = f > 0.3 and -1 or (f < -0.3 and 1 or 0)
        put(lv, x, y, 1, 1)
        put(lv * 0.8, x - 1, y + wy, 1, 1)
        put(lv * 0.8, x + 1, y + wy, 1, 1)
        if mid > 0.4 then put(lv * 0.5, x - 2, y + wy * 2, 1, 1); put(lv * 0.5, x + 2, y + wy * 2, 1, 1) end
      end
      -- its shadow on the mud, faint, far below
      if catch > 0.3 then put(1.5, x - 1, HZ + 4 + (y / HZ) * 16, 3, 1) end
    end
    -- salt-marsh grass close by, in the wind
    for _, g in ipairs(GRASS) do
      local lean = sin(T * 0.8 + g[3]) * (0.5 + 2 * nat) + K.heave(g[1]) * 0.4
      put(2 + bloom, g[1], 63 - g[2] * 0.5, 1, g[2] * 0.5 + 1)
      put(2 + bloom, g[1] + lean, 63 - g[2], 1, g[2] * 0.5)
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "heron" then
        -- a heron stalks slowly along a channel, stopping to look
        local x = 10 + inc.s * 20 + u * 70
        local y = chan(2, x) - 1
        local stride = sin(inc.age * 1.4)
        put(5 * e, x - 2, y - 7, 5, 3); put(4.5 * e, x - 4, y - 6, 2, 1)
        put(5 * e, x + 2, y - 12, 1, 5); put(5.5 * e, x + 3, y - 12, 3, 1)
        put(4 * e, x + stride, y - 4, 1, 4); put(4 * e, x - stride, y - 4, 1, 4)
        put(2 * e, x - 2, y + 2, 6, 1)
      elseif inc.name == "curlew" then
        -- a curlew walks the mud, its long bill probing
        local x = 100 - u * 60
        local y = 50 + inc.s2 * 6
        local probe = 2 * math.max(0, sin(inc.age * 2.5)) ^ 4
        put(8 * e, x - 2, y - 4, 6, 3); put(8 * e, x - 3, y - 5, 2, 2)
        put(7 * e, x - 4, y - 4 + probe, 1, 1); put(7 * e, x - 5, y - 3 + probe, 1, 1); put(6.5 * e, x - 6, y - 2 + probe, 1, 1)
        put(6 * e, x, y - 1, 1, 2); put(6 * e, x + 2, y - 1, 1, 2)
        put(2.5 * e, x - 3, y + 2, 8, 1)
      else
        -- a far flock passes high over, a loose line of specks
        for k = 0, 11 do
          local x = -10 + u * 150 - k * 5
          local y = 5 + (k % 3) * 2 + sin(u * 5 + k) * 1.5
          K.bird(x, y, (5.5 + 1.5 * sin(K.NOW * 6 + k)) * e, sin(K.NOW * 7 + k), 1)
        end
      end
    end
    K.glitter(sample, 12)
  end

  M.init()
  return M
end
