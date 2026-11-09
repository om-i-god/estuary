-- shoal: under the water by a pier. the surface wavers overhead with the
-- deck's shadow across it, far piles stand dim in the haze, the sandy bed
-- lies below with a little weed, and a silver school of fish turns as one
-- through the middle water. the chord is four piles close by, across by
-- pitch, each with a band of sunlight lying down it, higher for a higher
-- tone; they shift to their new places when the chord moves. the school
-- keeps together by simple rules; out_amp quickens it and lets it spread,
-- the tide turns which way it heads, out_lo lifts and drops it slowly and
-- sways the weed, out_mid ripples the light on the piles, out_hi glints on
-- the surface and the fish, and the water sounds stir up drifting motes. a
-- note at its pitch's height: a few fish turn and flash (the first motif),
-- one darts out (the second), one rolls silver (the third), a string of
-- bubbles rises (the fourth). the bar breathes in the light from above; a
-- swell is a surge that pushes the whole school and leans the weed. a
-- passing moment draws the school into a tight, turning ball. now and then
-- a ray glides along the bed, a turtle passes, or a bigger fish cruises
-- through and the school parts round it
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs, sqrt = math.sin, math.cos, math.floor, math.abs, math.sqrt

  M.incidents = {{"ray", 20}, {"turtle", 18}, {"hunter", 12}}

  local N = 30
  local SURF, BED = 4, 57
  local MARK_MAX = 6
  local fish, marks
  local hx, hy = -99, -99                 -- the big fish the school parts round (incident)

  local far = K.bake(function(rec)
    for k = 1, 6 do
      local x = floor(8 + (k - 1) * 22 + 6 * K.hash(k, 801))
      for y = SURF + 2, BED - 2, 3 do rec(1, x, y, 2, 1) end
    end
  end)
  local bed = K.bake(function(rec)
    for c = 0, 63 do
      local t = BED + floor(1.5 * sin(c * 0.2) + K.hash(c, 802) * 1.5)
      rec(1.8, c * 2, t, 2, 1)
      for y = t + 2, 63, 2 do
        if K.hash(c * 64 + y, 803) < 0.25 then rec(1, c * 2 + (y % 2), y, 1, 1) end
      end
    end
  end)
  -- the deck's shadow: where the surface's light is broken
  local DECK0, DECK1 = 30, 92
  local WEED = {}
  for k = 1, 8 do WEED[k] = {6 + (k - 1) * 16 + 6 * K.hash(k, 804), 5 + 6 * K.hash(k, 805), K.hash(k, 806) * 6} end
  local MOTES = K.scatter(44, 2, 8, 126, 54, 807)
  local PILE = {}                         -- the near piles this frame: x, band height, presence
  for i = 1, 4 do PILE[i] = {16 + i * 24, 30, 0} end

  function M.init()
    fish, marks = {}, {}
    hx, hy = -99, -99
    for k = 1, N do
      fish[k] = {x = 40 + 40 * K.hash(k, 808), y = 22 + 14 * K.hash(k, 809), vx = 6 + 3 * K.hash(k, 810),
        vy = (K.hash(k, 811) - 0.5) * 2, lit = -99, ph = K.hash(k, 812) * 6}
    end
  end
  function M.clear()
    marks = {}
    for _, f in ipairs(fish) do f.lit = -99 end
  end

  local function y_of(midi) return 46 - K.pu(midi) * 30 end

  function M.note(slot, midi)
    local x, y = K.px(midi), y_of(midi)
    if slot == 1 then
      -- the three fish nearest turn and flash
      for _ = 1, 3 do
        local best, bd
        for _, f in ipairs(fish) do
          local d = (f.x - x) ^ 2 + (f.y - y) ^ 2
          if K.T - f.lit > 2 and (not bd or d < bd) then best, bd = f, d end
        end
        if best then best.lit = K.T end
      end
    end
    K.cap_add(marks, {slot = slot, x = x, y = y, t0 = K.T, dir = K.rnd() < 0.5 and -1 or 1}, MARK_MAX)
  end

  -- one step of the school's rules
  local function step(dt)
    local T = K.T
    local ma = K.moment_age
    local ball = ma < 14 and ease(ma / 2) * (1 - ease((ma - 10) / 4)) or 0
    local spread = (5 + 6 * A[K.AMP]) * (1 - 0.45 * ball)
    local tx = clamp(64 + 34 * sin(T * 0.05) + 20 * K.tide_dir - 18 * K.sw_disp, 20, 108)
    local ty = 30 + 6 * sin(T * 0.08) + 5 * A[K.LO] * sin(T * 0.35)
    if ball > 0 then tx, ty = tx + ball * 9 * cos(ma * 1.2), ty + ball * 5 * sin(ma * 1.2) end
    local vmax = 8 + 8 * A[K.AMP] + 5 * ball
    local cx, cy, ax, ay = 0, 0, 0, 0
    for _, f in ipairs(fish) do cx, cy, ax, ay = cx + f.x, cy + f.y, ax + f.vx, ay + f.vy end
    cx, cy, ax, ay = cx / N, cy / N, ax / N, ay / N
    for i, f in ipairs(fish) do
      local fx = (cx - f.x) * (0.3 + 0.5 * ball) + (ax - f.vx) * 0.9 + (tx - cx) * 0.2
      local fy = (cy - f.y) * (0.3 + 0.5 * ball) + (ay - f.vy) * 0.9 + (ty - cy) * 0.2
      for j, o in ipairs(fish) do
        if j ~= i then
          local dx, dy = f.x - o.x, f.y - o.y
          local d2 = dx * dx + dy * dy
          if d2 < spread * spread and d2 > 1e-4 then
            local d = sqrt(d2)
            local push = (spread - d) / spread * 8
            fx, fy = fx + dx / d * push, fy + dy / d * push
          end
        end
      end
      -- (the big fish: the school parts round it)
      local dx, dy = f.x - hx, f.y - hy
      local d2 = dx * dx + dy * dy
      if d2 < 400 and d2 > 1e-4 then
        local d = sqrt(d2)
        fx, fy = fx + dx / d * (20 - d) * 3, fy + dy / d * (20 - d) * 3
      end
      fx = fx - K.sw_disp * 6
      if f.x < 6 then fx = fx + (6 - f.x) * 2 elseif f.x > 122 then fx = fx - (f.x - 122) * 2 end
      if f.y < SURF + 6 then fy = fy + (SURF + 6 - f.y) * 2 elseif f.y > BED - 6 then fy = fy - (f.y - BED + 6) * 2 end
      f.vx, f.vy = f.vx + fx * dt, f.vy + fy * dt
      local sp = sqrt(f.vx * f.vx + f.vy * f.vy)
      if sp > vmax then f.vx, f.vy = f.vx / sp * vmax, f.vy / sp * vmax end
      if sp < 3 then f.vx = f.vx + (f.vx >= 0 and 1 or -1) * (3 - sp) end
    end
    for _, f in ipairs(fish) do f.x, f.y = f.x + f.vx * dt, f.y + f.vy * dt end
  end

  local function sample(u, v) return u * 127, SURF + v * v * 40 end

  -- the light from above, made once (its strength is set each frame)
  local F_glow = 1
  local function water(y) local u = (y - SURF) / 30; return F_glow * 0.75 * math.max(0, 1 - u) ^ 2.5 end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    local inc = K.inc
    -- the big fish's place, if one is cruising through
    if inc and inc.name == "hunter" then
      hx, hy = -20 + inc.u * 170, 24 + inc.s2 * 12 + sin(inc.age * 0.5) * 3
    else
      hx, hy = -99, -99
    end
    -- (at most two small steps a frame: a stall never runs the school away)
    local n = math.min(2, math.ceil(K.DTS / 0.05))
    local dt = math.min(0.1, K.DTS / math.max(1, n))
    for _ = 1, n do step(dt) end
    -- the water's light, fading down, breathing on the bar
    F_glow = 0.35 + 0.4 * bloom + 1 * breath
    K.gradient(SURF + 1, SURF + 26, water, nil)
    K.blit(far, 1 + 0.4 * bloom, K.drift_x * 0.08, true)
    K.blit(bed, 1 + 0.4 * bloom)
    -- the surface overhead, broken by the deck's shadow
    for x = 0, 126, 2 do
      if x < DECK0 or x >= DECK1 then
        local w = sin(x * 0.13 - T * 1.1 + K.drift_x * 0.04) + 0.6 * sin(x * 0.29 + T * 0.8)
        local g = hi * 8 * math.max(0, sin(x * 1.1 + T * 4.5))
        put(math.min(12, 2.4 + bloom + breath * 2.5 + K.bj(x) + (w > 0.6 and 1.4 or 0) + g), x, SURF + (w > 0 and 0 or 1) + K.heave(x) * 0.25, 2, 1)
      else
        put(1, x, SURF - 1, 2, 1)
      end
    end
    -- the chord's piles, each with its band of sunlight down it
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      local P = PILE[i]
      if m then P[1], P[2] = 10 + K.cx(m) * 0.84, clamp(48 - (m - 36) / 40 * 36, 10, 50) end
      P[3] = m and p or 0
      -- (its light shared between the columns it stands across, so a pile
      -- sliding to a new place moves smoothly, never a column at a time)
      local x = floor(P[1])
      local fx = P[1] - x
      local pl = 1.4 + 0.5 * bloom
      for y = SURF, BED - 1, 3 do
        -- (the band: brightest at its height, rippling with out_mid)
        local d = abs(y - P[2]) / 9
        local band = math.max(0, 1 - d * d) * P[3] * (2 + 2.5 * K.chord_glow + bloom)
        local rip = mid * 4.5 * math.max(0, sin(y * 0.6 - T * 3 + i * 2))
        local j = K.bj(i * 32 + y) * 0.5
        local lit = pl + 0.8 + band + rip * (0.4 + P[3])
        put(lit * (1 - fx) + j, x - 1, y, 1, 3)
        put(lit * fx + pl * (1 - fx) + j, x, y, 1, 3)
        put(pl + j, x + 1, y, 1, 3)
        put(pl * fx + j * fx, x + 2, y, 1, 3)
      end
    end
    -- light from the surface rippling over the bed, livelier with out_mid
    for x = 2, 124, 6 do
      local c = sin(x * 0.17 - T * 1.4) + sin(x * 0.07 + T * 0.9)
      if c > 0.6 then put((0.8 + 3.5 * mid) * (c - 0.6) * 1.5 + K.bj(x) * 0.4, x, BED + 2 + (x // 6) % 3 * 2, 4, 1) end
    end
    -- the weed on the bed, swaying with the heave and a surge
    for k, w in ipairs(WEED) do
      local lean = sin(T * 0.7 + w[3]) * (0.5 + 2.5 * lo) - sw * 4 + K.heave(w[1]) * 0.5
      for j = 0, w[2] do
        local u = j / w[2]
        put(2.4 + bloom * 0.6 + K.bj(k * 9 + j) * 0.4, w[1] + lean * u * u, BED - j, 1, 1)
      end
    end
    -- motes stirred up by the water sounds
    if nat > 0.03 then
      for i = 1, #MOTES, 2 do
        local x = (MOTES[i] + K.drift_x * 0.4 + T * (1.5 + 6 * sw)) % 128
        local y = MOTES[i + 1] + sin(T * 0.4 + i) * 3
        if (i // 2) % 10 < nat * 10 then put(2.5 + 4.5 * nat, x, y, 2, 1) end
      end
    end
    -- the school
    for k, f in ipairs(fish) do
      local x, y = floor(f.x + 0.5), floor(f.y + 0.5)
      local dir = f.vx >= 0 and 1 or -1
      -- (a fish flashes silver as it turns side-on to the light)
      local turn = clamp(abs(f.vy) / 5, 0, 1)
      local age = K.T - f.lit
      local catch = age < 1.8 and sin(math.min(1, age / 1.8) * math.pi) or 0
      local l = math.min(12, 4 + 1.2 * bloom + 3 * turn + 5 * catch + hi * 5 * math.max(0, sin(T * 3 + f.ph * 4)))
      put(l + K.bj(k) * 0.5, x - (dir > 0 and 2 or 0), y, 3, 1)
      put(l * 0.55, x - dir * 2 - (dir > 0 and 1 or 0), y + (f.vy > 1 and -1 or (f.vy < -1 and 1 or 0)), 1, 1)
    end
    -- the notes' other marks
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.15) * (1 - ease((age - 1.5) / 2.5)) * cf
        local x, y, d = mk.x, mk.y, mk.dir
        if mk.slot == 1 then
          -- (the fish themselves flash; the light lies round them briefly)
          K.ring(x, y, 3 + age * 2, 0.6, 5 * e, 14)
          put(6 * e, x - 2, y, 5, 1); put(4 * e, x - 1, y - 1, 3, 1)
        elseif mk.slot == 2 then
          local fx = x + d * (1 - math.exp(-age * 2.5)) * 20
          put(9 * e, fx - 2, y, 5, 1); put(6 * e, fx - d * 3, y - 1, 1, 3)
          put(3 * e, fx - d * 10, y, 6, 1)
        elseif mk.slot == 3 then
          local roll = math.max(0, sin(age * 5))
          put((5 + 5 * roll) * e, x - 3, y, 7, 2)
          put(4 * e * roll, x - 5, y - 2, 11, 1); put(4 * e * roll, x - 5, y + 3, 11, 1)
        else
          for q = 0, 4 do
            local by = y - age * 9 - q * 3
            if by > SURF + 1 then put(7 * e * (1 - q * 0.12), x + sin(age * 3 + q) * 1.2, by, 1 + (q % 2), 1 + (q % 2)) end
          end
        end
      end
    end
    -- incidents
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "ray" then
        -- a ray glides along the bed, its wings rippling
        local x = -16 + u * 160
        local y = BED - 4 + sin(inc.age * 0.4) * 1.5
        local fl = sin(inc.age * 1.8)
        for j = -7, 7 do
          local t = abs(j) / 7
          local w = (1 - t) * 4
          put(6 * e * (1 - t * 0.3), x + j * 1.5, y - w * 0.5 + t * fl * 1.5, 2, math.max(1, floor(w)))
        end
        put(4.5 * e, x - 16, y, 6, 1)
        put(2.5 * e, x - 9, BED + 2, 20, 1)
      elseif inc.name == "turtle" then
        local tx, ty = 140 - u * 160, 18 + inc.s2 * 10 + sin(inc.age * 0.4) * 3
        local fl = sin(inc.age * 1.6)
        put(6 * e, tx - 4, ty - 2, 9, 5); put(7 * e, tx - 2, ty - 3, 5, 1)
        put(6.5 * e, tx - 7, ty - 1, 3, 2)
        put(5 * e, tx - 1 - fl, ty - 5 + fl, 3, 2); put(5 * e, tx - 1 - fl, ty + 3 - fl, 3, 2)
        put(4 * e, tx + 5, ty - 2 + fl * 0.5, 2, 1); put(4 * e, tx + 5, ty + 2 - fl * 0.5, 2, 1)
      else
        -- a bigger fish cruises through; the school parts round it
        local fl = sin(inc.age * 3)
        put(6 * e, hx - 7, hy - 1, 14, 3); put(7 * e, hx - 5, hy - 2, 9, 1)
        put(5 * e, hx - 11, hy - 2 + fl, 3, 2); put(5 * e, hx - 13, hy - 3 + fl * 1.5, 2, 4)
        put(5.5 * e, hx - 1, hy - 4, 3, 2)
        put(8 * e, hx + 5, hy - 1, 1, 1)
      end
    end
    K.glitter(sample, 24)
  end

  M.init()
  return M
end
