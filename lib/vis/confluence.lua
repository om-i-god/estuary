-- confluence: a park where a creek meets a river, under a row of tall
-- concrete petals: curved shells rising from narrow feet and flaring wide
-- at the top, leaning together in pairs to make arches, shaped to gather
-- rain and dew and run it down to a cistern at their feet. a soft sky
-- behind, the two waters meeting in the distance, native grasses and
-- wildflowers close by. the chord is the petals' lit faces: each of the
-- four arches catches the light on one face, higher for a higher tone,
-- the light gliding to its new place when the chord moves. a note becomes
-- a drop running down the petal nearest its pitch into the cistern, by
-- motif: a single drop (the first), a pair (the second), a drop leaving a
-- glistening trail (the third), a drop that rings the cistern where it
-- lands (the fourth). the cistern's glow at the petals' feet rises with
-- the bloom; the bar breathes in the sky. out_lo sways the grasses,
-- out_mid stirs the flowers, out_amp keeps the waters moving, out_hi
-- glints as dew along the petals' edges, and the water sounds shimmer where
-- the two waters meet. a swell is a shower sliding down every petal; a
-- passing moment sends light flowing down the whole canopy. now and then a
-- monarch drifts by, an egret stands at the confluence, or a rain cloud
-- passes
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"monarch", 16}, {"egret", 20}, {"cloud", 22}}

  local GROUND, TOP = 53, 11
  local ARCH = {17, 49, 80, 111}          -- the arches' centres
  local MARK_MAX = 6
  local marks

  -- a petal: its foot, the arch it leans into, which side (-1 left, 1 right)
  local PET = {}
  for i, c in ipairs(ARCH) do
    PET[#PET + 1] = {c - 8, c, -1, i}
    PET[#PET + 1] = {c + 8, c, 1, i}
  end
  -- a petal's edges at height fraction u (0 foot, 1 top): the inner edge
  -- leans in to meet its partner over the arch, the outer one flares out
  local function edges(p, u)
    local s = p[3]
    local xi = p[1] - s * 7.5 * u ^ 1.4
    local xo = p[1] + s * (0.8 + 8 * u * u)
    return xi, xo, GROUND - u * (GROUND - TOP)
  end
  -- its centre line and half width there
  local function petal(p, u)
    local xi, xo, y = edges(p, u)
    return (xi + xo) * 0.5, abs(xo - xi) * 0.5, y
  end

  -- the two waters meeting in the distance, and the far bank
  local function creek(x) return 40 + (64 - x) * 0.06 + 1.2 * sin(x * 0.08) end
  local function river(x) return 43 + 1.5 * sin(x * 0.05 + 1) end
  local far = K.bake(function(rec)
    for x = 0, 127, 2 do
      rec(1.4, x, floor(37 + 1.2 * sin(x * 0.07) + K.hash(x, 1201)), 2, 1)
      if K.hash(x, 1202) < 0.35 then rec(1, x, 35 - floor(3 * K.hash(x, 1203)), 1, 2) end
    end
  end)
  -- the petals' bodies: rows of concrete, their edges, baked once
  local shells = K.bake(function(rec)
    -- (each edge is merged into vertical runs: one rect per step sideways)
    local function edge(l, p, side, u1, dy)
      local rx, ry, n
      for y = GROUND, floor(GROUND - u1 * (GROUND - TOP)), -1 do
        local u = (GROUND - y) / (GROUND - TOP)
        local xi, xo = edges(p, u)
        local x = floor((side < 0 and xi or xo) + 0.5)
        local yy = y + floor(u * dy + 0.5)
        if x == rx and yy == ry - n then
          n = n + 1
        else
          if rx then rec(l, rx, ry - n + 1, 1, n) end
          rx, ry, n = x, yy, 1
        end
      end
      if rx then rec(l, rx, ry - n + 1, 1, n) end
    end
    for _, p in ipairs(PET) do
      edge(2.4, p, -1, 1, 0)
      edge(1.8, p, 1, 0.86, 4)
      for j = 24, 34, 4 do
        local u = j / 40
        local xi, xo, y = edges(p, u)
        local a, b = math.min(xi, xo) + 1, math.max(xi, xo) - 1
        if b > a then rec(1, a, y + u * 2, b - a, 1) end
      end
      -- the sloping top edge, from the outer corner up to where the pair meet
      local xi, _, yt = edges(p, 1)
      local _, xo, yo = edges(p, 0.86)
      yo = yo + 0.86 * 4
      for q = 0, 8 do
        local f = q / 8
        rec(2.7, xo + (xi - xo) * f, yo + (yt - yo) * f, 1, 1)
      end
    end
  end)
  -- long thin clouds drifting slowly over
  local clouds = K.bake(function(rec)
    for k = 1, 4 do
      local cx, cy, w = K.hash(k, 1211) * 128, 3 + 7 * K.hash(k, 1212), 20 + 18 * K.hash(k, 1213)
      rec(1.5, cx - w * 0.5, cy, w, 1)
      rec(1, cx - w * 0.3, cy + 1, w * 0.6, 1)
    end
  end)
  -- the native garden close by: grasses {x, height, phase}, flowers {x, y, phase}
  local GRASS, FLOW = {}, {}
  -- (clumps at their own spacing: a garden, not a border)
  do
    local x = 1
    for k = 1, 18 do
      GRASS[k] = {x, 3 + 8 * K.hash(k, 1205), K.hash(k, 1206) * 6, K.hash(k, 1210) < 0.5 and -1 or 1}
      x = x + 3 + 10 * K.hash(k, 1204)
      if x > 127 then break end
    end
  end
  for k = 1, 22 do FLOW[k] = {4 + 120 * K.hash(k, 1207), 56 + 6 * K.hash(k, 1208), K.hash(k, 1209) * 6} end
  local DEW = {}
  for _, p in ipairs(PET) do
    for j = 8, 40, 4 do
      local x, w, y = petal(p, j / 40)
      DEW[#DEW + 1] = floor(x + p[3] * w); DEW[#DEW + 1] = floor(y)
    end
  end

  function M.init() marks = {} end
  function M.clear() marks = {} end

  function M.note(slot, midi)
    local x = K.px(midi)
    local best, bd = 1, 1e9
    for i, p in ipairs(PET) do
      local d = abs(p[1] - x)
      if d < bd then best, bd = i, d end
    end
    K.cap_add(marks, {slot = slot, p = best, t0 = K.T, u0 = 0.75 + 0.2 * K.pu(midi)}, MARK_MAX)
  end

  local function sample(u, v)
    local n = #DEW // 2
    local k = 1 + floor(u * n) % n
    return DEW[k * 2 - 1], DEW[k * 2]
  end

  -- the sky's light, made once (its strength is set each frame)
  local F_glow = 1
  local function sky(y) return F_glow * (0.2 + 0.6 * (y / 36)) end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    -- a soft sky, brightening toward the horizon, breathing on the bar
    F_glow = 0.2 + 0.06 * bloom + 0.4 * breath
    K.gradient(0, 34, sky)
    K.blit(clouds, 1 + 0.5 * bloom, T * 0.6 + K.drift_x * 0.05, true)
    K.blit(far, 1 + 0.4 * bloom)
    -- the two waters meeting: the creek coming in from the left, the river
    -- from the right, shimmering where they meet
    -- (each dash keeps its own jitter as it runs on, so the row never
    -- re-levels when the run wraps)
    local run = T * (2 + 6 * A[K.AMP])
    local sh = floor(run / 4)
    local off = run - sh * 4
    for x0 = 0, 127, 4 do
      local x = x0 + off - 2
      local y = x < 64 and creek(x) or river(x)
      local meet = math.max(0, 1 - abs(x - 64) / 34)
      local f = sin(x * 0.3 - T * (1.5 + 3 * A[K.AMP]))
      K.dash(1.6 + 0.6 * bloom + K.ramp(f, 0.15, 0.45) + nat * 4.5 + meet * nat * 8 * math.max(0, sin(x * 0.9 + T * 4)) + K.bj(x0 // 4 - sh) * 0.4, x, y, 3)
    end
    for q = 0, 9 do
      local x = 38 + q * 6 + sin(T * 1.3 + q) * 2
      put(1.4 + nat * 7 * math.max(0, sin(T * 2.6 + q * 1.9)), x, 44 + (q % 3), 4, 1)
    end
    -- the petals, and the chord's light on their faces
    K.blit(shells, 1 + 0.35 * bloom + 0.6 * breath)
    local ma = K.moment_age
    local flowl = ma < 14 and ease(ma / 2) * (1 - ease((ma - 9) / 5)) or 0
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local pt = PET[i * 2 - 1 + (i % 2)]
        local hu = clamp((m - 36) / 40, 0.1, 0.95)
        local l = (5 + 3 * K.chord_glow) * p
        -- (every row of the face, the light falling off smoothly from its
        -- height: a lit surface, not ruled hatching)
        for j = 4, 40 do
          local u = j / 40
          local x, w, y = petal(pt, u)
          local d = abs(u - hu) / 0.3
          if d < 1 then put(l * (1 - d * d) * 0.85 + K.bj(j * 3 + i * 40) * 0.85, x - w * 0.7, y, math.max(1, w * 1.4), 1) end
        end
      end
    end
    -- the moment: light flowing down the whole canopy into the cistern
    if flowl > 0 then
      -- (the front enters from beyond the top and leaves past the foot: it
      -- never wraps while it is on a petal)
      local front = (ma * 0.22) % 1.5 - 0.25
      for _, p in ipairs(PET) do
        for j = 4, 40, 3 do
          local u = j / 40
          local d = abs((1 - u) - front) / 0.25
          if d < 1 then
            local x, w, y = petal(p, u)
            put(flowl * 9 * (1 - d), x - w * 0.6, y, math.max(1, w * 1.2), 1)
          end
        end
      end
    end
    -- dew glinting along the petals' edges with out_hi
    K.twinkle(DEW, hi, 13)
    for i, p in ipairs(PET) do
      local xi, _, yt = edges(p, 1)
      local g = sin(T * 3.4 + i * 1.7)
      if g > 0.1 then put(hi * 10 * (g - 0.1), xi - 3, yt, 6, 1) end
    end
    -- the cistern at the petals' feet, its glow rising with the bloom
    -- (the water stands higher in it with the bloom: more rows of light,
    -- each broken into strokes)
    local lvl = 0.6 + 2.3 * bloom
    for y = GROUND + 2, GROUND - floor(lvl) + 2, -1 do
      local u = (GROUND + 2 - y) / 3
      K.streaks(2 + 1.5 * bloom + breath * 1.2 - u * 0.8, y, 6 - u * 2, 12, y * 17 + K.drift_x * 0.1, nil, nil, 6, 122)
    end
    put(3 + 2 * bloom, 6, GROUND + 3, 116, 1)
    -- ripples running along the cistern, livelier with out_amp
    local ro = T * (2 + 9 * A[K.AMP])
    for x = 6 + ro % 9, 120, 9 do put(2.5 + 4 * A[K.AMP] + K.bj(floor(x)) * 0.4, x, GROUND + 3, 3, 1) end
    -- the drops
    for k = #marks, 1, -1 do
      local mk = marks[k]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4 or done then table.remove(marks, k)
      else
        local e = ease(age / 0.2) * (1 - ease((age - 2.4) / 1.6)) * cf
        local p = PET[mk.p]
        local run = clamp(age / 2.2, 0, 1)
        local u = mk.u0 * (1 - run * run)
        local x, w, y = petal(p, u)
        x = x + p[3] * w * 0.3
        put(4 * e, x - 2, y, 1, 2); put(4 * e, x + 2, y, 1, 2); put(4 * e, x, y - 2, 1, 1)
        if mk.slot == 1 then
          put(10 * e, x - 1, y, 3, 3)
        elseif mk.slot == 2 then
          put(9 * e, x - 1, y, 2, 2)
          local x2, w2, y2 = petal(p, math.min(1, u + 0.25))
          put(9 * e, x2 + p[3] * w2 * 0.3 - 1, y2, 2, 2)
          put(4 * e, x2 + p[3] * w2 * 0.3 - 3, y2, 1, 2)
        elseif mk.slot == 3 then
          put(9 * e, x - 1, y, 2, 2)
          for q = 1, 5 do
            local xq, wq, yq = petal(p, math.min(1, u + q * 0.05))
            put(6 * e * (1 - q / 6), xq + p[3] * wq * 0.3, yq, 1, 1)
          end
        else
          put(9 * e, x - 1, y, 2, 2)
          put(6 * e, x - 4, y, 2, 1); put(6 * e, x + 3, y, 2, 1); put(6 * e, x, y - 3, 1, 2); put(6 * e, x, y + 3, 1, 2)
        end
        if run >= 1 then
          local ra = age - 2.2
          local sc = mk.slot == 4 and 1.6 or 1
          K.ring(p[1], GROUND + 2, (1.5 + ra * 4) * sc, 0.3, 7 * e * ease(ra / 0.2), 14)
        end
      end
    end
    -- a swell: a shower sliding down every petal, and rain falling
    if sw > 0.03 then
      for i, p in ipairs(PET) do
        for q = 0, 2 do
          local u = 1 - ((T * 0.5 + q / 3 + i * 0.11) % 1)
          local x, w, y = petal(p, u)
          put(sw * 6.5, x - w * 0.3 + q, y, 1, 3)
        end
      end
      for q = 0, 13 do
        local x = (q * 9.7 + T * 6) % 128
        local y = (q * 13 + T * 35) % 50
        put(sw * 3.5 * clamp(math.min(y, 48 - y) / 8, 0, 1), x, y, 1, 3)
      end
    end
    -- the native garden: grasses swaying with out_lo, flowers nodding with out_mid
    for k, g in ipairs(GRASS) do
      local lean = sin(T * 0.8 + g[3]) * (0.4 + 2.6 * lo) + K.heave(g[1]) * 0.4
      -- (a clump: three blades fanning out)
      for b = -1, 1 do
        local h = g[2] * (1 - abs(b) * 0.3)
        put(2.4 + 0.6 * bloom + K.bj(k * 3 + b) * 0.4, g[1] + b, 63 - h * 0.5, 1, h * 0.5 + 1)
        put(2.2 + 0.6 * bloom, g[1] + b * 2 + lean + g[4] * 0.5, 63 - h, 1, h * 0.5)
      end
    end
    for k, f in ipairs(FLOW) do
      local nod = sin(T * (1.2 + 2 * mid) + f[3]) * (0.3 + 2.2 * mid)
      put(3.5 + 1.5 * bloom + mid * 4 + K.bj(k) * 0.4, f[1] + nod, f[2], 2, 1)
      if mid > 0.5 then put(mid * 3, f[1] + nod, f[2] - 1, 1, 1) end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "monarch" then
        local x = -8 + u * 144
        local y = 46 + sin(inc.age * 1.1) * 6 + sin(inc.age * 3.3) * 1.5
        -- (its wings open and close slowly: the light on them swells, the shape stays)
        local wing = 0.75 + 0.25 * sin(K.NOW * 5)
        put(9 * e, x, y - 1, 1, 4)
        put(8 * e * wing, x - 4, y - 2, 4, 3); put(8 * e * wing, x + 1, y - 2, 4, 3)
        put(6.5 * e * wing, x - 3, y + 1, 3, 2); put(6.5 * e * wing, x + 1, y + 1, 3, 2)
      elseif inc.name == "egret" then
        local x, y = 60 + inc.s * 10, 45
        local look = sin(inc.age * 0.4) > 0.5 and 1 or 0
        put(9 * e, x - 2, y - 6, 5, 3); put(9 * e, x + 2, y - 11 + look, 1, 5)
        put(9.5 * e, x + 3, y - 11 + look, 3, 1)
        put(6 * e, x - 1, y - 3, 1, 3); put(6 * e, x + 1, y - 3, 1, 3)
        for d = 1, 3 do put(3 * e, x - 2, y + d, 6, 1) end
      else
        -- a rain cloud drifts across the sky, a few drops under it
        local x = -30 + u * 190
        for q = 0, 5 do
          local w = 18 - abs(q - 2.5) * 4
          put(2.6 * e + K.bj(q) * 0.4, x - w, 4 + q, w * 2, 1)
        end
        for q = 0, 6 do
          local dy = (inc.age * 18 + q * 7) % 22
          put(3.5 * e * (1 - dy / 22), x - 12 + q * 4, 11 + dy, 1, 2)
        end
      end
    end
    K.glitter(sample, 36)
  end

  M.init()
  return M
end
