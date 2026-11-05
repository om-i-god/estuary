-- drift: a pool seen from above, between two grassy banks, turning in four
-- slow eddies. each motif
-- is a leaf carried round its eddy at its own cycle length, a wake fading
-- behind it; petals ride the eddies more slowly. the eddies wobble with
-- out_lo and precess with the current, their paths a faint shimmer on the
-- surface, and a shimmering line joins two leaves whose phases line up
return function(K)
  local M = {}
  local put, A, clamp = K.put, K.A, K.clamp

  local ORBIT_RY = {6, 12, 18, 24}
  local PETALS = 16
  local petals

  function M.init()
    petals = {}
    for k = 1, PETALS do
      petals[k] = {i = (k - 1) % 4 + 1, a = K.hash(k, 21) * K.TAU, r = 0.75 + 0.5 * K.hash(k, 22),
        w = 0.05 + 0.06 * K.hash(k, 23), lv = 2 + 1.5 * K.hash(k, 24)}
    end
  end

  -- a point on eddy i at angle a (scaled out by r): an ellipse that wobbles
  -- with out_lo, its wobble carried round by the current, tilted a little
  -- back and forth
  local function orbit_pt(i, a, rr)
    local T, dx = K.T, K.drift_x
    local ry = ORBIT_RY[i] * (rr or 1)
    local rx = ry * 1.7
    local lo = A[K.LO]
    local dir = (i % 2 == 0) and 1 or -1
    local r = 1 + (0.03 + 0.11 * lo) * math.sin(3 * a + T * 0.8 + i + dir * dx * 0.02)
      + (0.02 + 0.05 * lo) * math.sin(2 * a - T * 0.45 + i * 2)
    local x, y = math.cos(a) * rx * r, math.sin(a) * ry * r
    local tl = 0.15 * math.sin(T * (0.05 + 0.01 * i) + dx * 0.01 * dir + i)
    local c, s = math.cos(tl), math.sin(tl)
    return 64 + x * c - y * s, 32 + x * s + y * c
  end

  local function sample(u, v) return orbit_pt(math.floor(u * 4) + 1, v * K.TAU) end

  -- a leaf lying along its heading: a bright midrib and a dimmer blade
  local function leaf(x, y, hx, hy, lv)
    local n = math.sqrt(hx * hx + hy * hy)
    if n < 1e-6 then hx, hy = 1, 0 else hx, hy = hx / n, hy / n end
    put(lv, x, y, 1, 1)
    put(lv * 0.8, x + hx * 1.5, y + hy * 1.5, 1, 1)
    put(lv * 0.6, x - hx * 1.5, y - hy * 1.5, 1, 1)
    put(lv * 0.45, x - hx * 2.6, y - hy * 2.6, 1, 1)          -- the stalk
    put(lv * 0.55, x - hy, y + hx, 1, 1)
    put(lv * 0.55, x + hy + hx * 0.7, y - hx + hy * 0.7, 1, 1)
  end

  function M.draw(S)
    local T = K.T
    local hi = A[K.HI]
    -- the banks: grass in the top left and bottom right corners, a lit lip
    -- where they meet the water, the pool's light lapping at it
    for y = 0, 63 do
      local e1 = y < 16 and 40 * (1 - (y / 16) ^ 1.6) + 2 * math.sin(y * 1.3) or 0
      local e2 = y > 46 and 46 * (1 - ((63 - y) / 17) ^ 1.6) + 2 * math.sin(y * 1.7) or 0
      local lap = 1 + 0.8 * math.sin(T * 0.9 + y * 0.5)
      if e1 > 1 then
        for x = (y * 5) % 4, e1 - 3, 4 do
          if K.hash(x * 64 + y, 25) < 0.5 then put(1 + (K.hash(x + y, 26) < 0.2 and 1 or 0), x, y, 1, 2) end
        end
        put(2 + K.bloom, e1 - 2, y, 2, 1); put(lap, e1 + 1, y, 1, 1)
      end
      if e2 > 1 then
        for x = 128 - e2 + 3 + (y * 5) % 4, 127, 4 do
          if K.hash(x * 64 + y, 27) < 0.5 then put(1 + (K.hash(x + y, 28) < 0.2 and 1 or 0), x, y, 1, 2) end
        end
        put(2 + K.bloom, 128 - e2, y, 2, 1); put(lap, 128 - e2 - 2, y, 1, 1)
      end
    end
    -- the surface: a faint light texture moving with the current
    K.surface(0, 1, 128, 64, 1, 13, 6, 3)
    -- the eddies' paths: arcs of light that run round with the water
    for i = 1, 4 do
      local n = 14 + i * 14
      for k = 0, n - 1 do
        local a = k / n * K.TAU
        local sh = math.sin(a * 3 - T * (0.5 + 0.1 * i) * (i % 2 == 0 and 1 or -1) + i)
        if sh > 0.35 then
          local x, y = orbit_pt(i, a)
          put(1 + (sh > 0.8 and 1 or 0) + hi * 2.5 * math.max(0, math.sin(k * 2.3 + T * 7 + i)), x, y, 2, 1)
        end
      end
    end
    -- petals, slower than the leaves, each at its own distance out
    for _, p in ipairs(petals) do
      p.a = p.a + p.w * (1 + 1.5 * K.energy) * K.DTS * (p.i % 2 == 0 and 1 or -1)
      local x, y = orbit_pt(p.i, p.a, p.r)
      put(p.lv + K.bloom, x, y, 2, 2)
      put(p.lv * 0.5, x + 2, y + 1, 1, 1)
    end
    -- the leaves
    local pts, ph, np = {}, {}, 0
    for i = 1, 4 do
      local p = K.phase(S, i)
      if p then
        local a = p * K.TAU - math.pi / 2
        local x, y = orbit_pt(i, a)
        local dir = 1
        local nx, ny = orbit_pt(i, a + 0.05 * dir)
        if K.sounding(S, i) then
          local lv = 6 + K.slot_flash[i] * 6
          -- the wake: two fading arms opening behind it
          for k = 1, 7 do
            local tx, ty = orbit_pt(i, a - k * 0.06)
            local l = lv * 0.4 * (1 - k / 8)
            put(l, tx, ty, 1, 1)
            if k > 2 then
              local ox, oy = orbit_pt(i, a - k * 0.06, 1 + k * 0.012)
              put(l * 0.6, ox, oy, 1, 1)
            end
          end
          leaf(x, y, nx - x, ny - y, lv)
          np = np + 1
          pts[np], ph[np] = {x, y}, p
        else
          leaf(x, y, nx - x, ny - y, 2.5)
        end
      end
    end
    -- a moment: a petal spins in the still centre
    put(3 + clamp(1 - K.moment_age / 3, 0, 1) * 6, 64, 32, 1, 1)
    -- a shimmering dotted line joins two leaves whose phases line up
    for i = 1, np - 1 do
      for j = i + 1, np do
        local d = math.abs(ph[i] - ph[j])
        d = math.min(d, 1 - d)
        if d < 0.12 then
          local x0, y0, x1, y1 = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
          local n = math.max(2, math.floor(math.max(math.abs(x1 - x0), math.abs(y1 - y0)) / 2))
          local base = (1 - d / 0.12) * 5 * (0.8 + 0.5 * hi)
          for s = 1, n - 1 do
            local u = s / n
            local lv = base * (0.55 + 0.45 * math.sin(T * (5 + 4 * hi) + s * 0.9 + i * j))
            put(lv, x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, 1, 1)
          end
        end
      end
    end
    K.glitter(sample)
  end

  M.init()
  return M
end
