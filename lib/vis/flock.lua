-- flock: a flock of small waders over the mudflats. a far shore lies under
-- a pale sky; below, channels wind across the mud and shine as the water
-- rises with the water sounds, a swell and the bloom. the flock keeps
-- together by simple rules (stay close, match your neighbours, do not
-- crowd), drifts the way the tide is turning and spreads wider as the sound
-- grows; a swell lifts it higher. each note makes a few birds near its
-- pitch bank and catch the light
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease

  local N = 18
  local HZ = 40                           -- the far shore
  local birds

  function M.init()
    birds = {}
    for k = 1, N do
      birds[k] = {x = 50 + 28 * K.hash(k, 81), y = 14 + 12 * K.hash(k, 82),
        vx = 6 + 4 * K.hash(k, 83), vy = (K.hash(k, 84) - 0.5) * 3, ph = K.hash(k, 85) * 6, lit = -99}
    end
  end

  function M.clear() for _, b in ipairs(birds) do b.lit = -99 end end

  function M.note(slot, midi)
    local x = K.px(midi)
    -- the two or three birds nearest the note's column bank into the light
    local n = 1 + (slot % 2)
    for _ = 1, n do
      local best, bd
      for _, b in ipairs(birds) do
        local d = math.abs(b.x - x)
        if K.T - b.lit > 3 and (not bd or d < bd) then best, bd = b, d end
      end
      if best then best.lit = K.T end
    end
  end

  -- one step of the flock's rules
  local function step(dt)
    local T = K.T
    local spread = 5.5 + 7 * K.energy
    local tx = 64 + 30 * math.sin(T * 0.045) + 18 * K.tide_dir
    local ty = 20 + 6 * math.sin(T * 0.07 + 1) - 9 * K.sw_disp
    local vmax = 9 + 6 * K.energy
    local cx, cy, ax, ay = 0, 0, 0, 0
    for _, b in ipairs(birds) do cx, cy, ax, ay = cx + b.x, cy + b.y, ax + b.vx, ay + b.vy end
    cx, cy, ax, ay = cx / N, cy / N, ax / N, ay / N
    for i, b in ipairs(birds) do
      local fx = (cx - b.x) * 0.25 + (ax - b.vx) * 0.6 + (tx - cx) * 0.15 - b.vx * 0.05
      local fy = (cy - b.y) * 0.25 + (ay - b.vy) * 0.6 + (ty - cy) * 0.15
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
      fy = fy + math.sin(T * 0.9 + b.ph) * 1.5 + K.heave(b.x) * 0.8
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

  -- the channels across the mud: y of channel k at x
  local function chan(k, x)
    if k == 1 then return HZ + 6 + 2 * math.sin(x * 0.05 + 1) end
    if k == 2 then return 51 + 4 * math.sin(x * 0.035 + 2.5) + 1.5 * math.sin(x * 0.11) end
    return 58 + 3 * math.sin(x * 0.045 - 1) + 1.5 * math.sin(x * 0.13 + 2)
  end

  function M.draw()
    local T = K.T
    local bloom = K.bloom
    -- the flock moves on its own small steps, whatever the frame rate
    local left = K.DTS
    while left > 1e-6 do
      local dt = math.min(left, 0.05)
      step(dt)
      left = left - dt
    end
    -- the sky: pale low down, over the far shore
    local glow = 1.5 + 1.2 * bloom
    K.gradient(12, HZ - 1, function(y) local u = (HZ - y) / 24; return glow * math.max(0, 1 - u) ^ 1.8 end)
    put(2, 0, HZ, 128, 1)
    for x = 0, 126, 6 do put(1.5, x + 2 * K.hash(x, 86), HZ - 1 - math.floor(2 * K.hash(x, 87)), 2, 1) end
    -- the mud: a fixed stipple
    for y = HZ + 2, 63, 2 do
      for x = (y * 3) % 7, 127, 7 do
        if K.hash(x * 64 + y, 88) < 0.4 then put(1, x, y, 2, 1) end
      end
    end
    -- the channels: as the water rises they widen and shine, and the light
    -- runs along them
    local water = clamp(0.3 + 0.5 * A[K.NAT] + 0.4 * K.sw_disp + 0.2 * bloom, 0, 1)
    local hi = A[K.HI]
    for k = 1, 3 do
      local w = 1 + math.floor(water * (k == 1 and 0.8 or 1.6))
      for x = 0, 126, 2 do
        local y = chan(k, x) + K.heave(x * 1.5 + k * 20) * 0.35
        local sh = math.sin(x * 0.2 - T * 1.1 + K.drift_x * 0.1 + k)
        local l = 1 + water * 1.5 + (sh > 0.7 and 1 or 0)
        put(l, x, y, 2, w)
        local g = hi * 3 * math.max(0, math.sin(x * 1.3 + T * 7 + k))
        if g > 0.5 then put(l + g, x, y, 1, 1) end
      end
    end
    -- the birds
    for _, b in ipairs(birds) do
      local age = T - b.lit
      local catch = age < 1.6 and math.sin(math.min(1, age / 1.6) * math.pi) or 0
      local x, y = math.floor(b.x + 0.5), math.floor(b.y + 0.5)
      local lv = 4 + 1.5 * bloom + catch * 5
      if catch > 0.3 then
        -- banking: the wings flat and wide, the light along them
        put(lv, x - 2, y, 5, 1)
        put(lv * 0.5, x, y + 1, 1, 1)
      else
        local f = math.sin(K.NOW * (7 + b.ph * 0.3) + b.ph)
        local wy = f > 0.3 and -1 or (f < -0.3 and 1 or 0)
        put(lv, x, y, 1, 1)
        put(lv * 0.8, x - 1, y + wy, 1, 1)
        put(lv * 0.8, x + 1, y + wy, 1, 1)
      end
      -- its shadow on the mud, faint, far below
      if catch > 0.3 then put(1.5, x - 1, HZ + 4 + (y / HZ) * 16, 3, 1) end
    end
    K.glitter(sample, 12)
  end

  M.init()
  return M
end
