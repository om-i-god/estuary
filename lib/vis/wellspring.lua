-- wellspring: a clear woodland spring seen from above. the water wells up
-- through a pale sandy bed, setting small boils of sand turning, and the
-- light comes down through the canopy in moving spots; round the rim the
-- forest floor, roots reaching in and ferns close by. the chord is the
-- light through the leaves: four bright spots on the bed across by pitch,
-- bigger for lower tones, drifting to their new places when the chord
-- moves. a note is a sand-boil blooming at its pitch's place, its size set
-- by motif: a small fizz (the first), a ring (the second), a broad boil
-- (the third), a boil that keeps welling for a while (the fourth). out_mid
-- sways the ferns, out_amp sets how fast the spring wells, out_lo heaves
-- the net of light on the surface, out_hi glints on it, and the water
-- sounds are the leaves' shadows flickering over the water. the bloom is
-- the day coming through the canopy; the bar breathes in the bed's light;
-- a swell is the spring surging, every boil swelling and rings running out
-- from the eye. a passing moment sweeps a shaft of sun across the bed, the
-- mica in the sand glittering. now and then a leaf spins down onto the
-- water, a water strider skates across, or a newt walks the bed
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"leaf", 16}, {"strider", 14}, {"newt", 20}}

  local CX, CY = 64, 33                   -- the pool's middle, the spring's eye
  local MARK_MAX = 4
  local marks
  local well = 0                          -- the spring's welling, integrated

  -- the pool's edge at angle a: an irregular round
  local function rim(a) return 1 + 0.08 * sin(a * 3 + 0.7) + 0.06 * sin(a * 5 + 2) end
  local RX, RY = 50, 27
  local function inside(x, y)
    local dx, dy = (x - CX) / RX, (y - CY) / RY
    local a = math.atan(dy, dx)
    return dx * dx + dy * dy < rim(a) ^ 2
  end
  -- each row's span of water, worked out once
  local SPAN = {}
  for y = 0, 63 do
    local a, b
    for x = 0, 127 do
      if inside(x, y) then a = a or x; b = x end
    end
    SPAN[y] = a and {a, b} or false
  end
  -- the bed: pale sand with darker grains, baked once; the rim's stones
  -- and the forest floor beyond, baked once
  local bed = K.bake(function(rec)
    local k = 0
    for y = 0, 63 do
      local s = SPAN[y]
      if s then
        local x = s[1] + 1
        while x < s[2] do
          k = k + 1
          local len = 1 + floor(3 * K.hash(k, 1801))
          if K.hash(k, 1802) < 0.12 then rec(K.hash(k, 1803) < 0.25 and 1.6 or 1, x, y, math.min(len, s[2] - x), 1) end
          x = x + len + 1 + floor(2 * K.hash(k, 1804))
        end
      end
    end
  end)
  local floor_l = K.bake(function(rec)
    local k = 0
    for y = 0, 63 do
      local s = SPAN[y]
      local x = 0
      while x < 128 do
        k = k + 1
        local len = 2 + floor(4 * K.hash(k, 1805))
        local inw = s and x + len > s[1] - 2 and x < s[2] + 2
        if not inw and K.hash(k, 1806) < 0.045 then rec(K.hash(k, 1807) < 0.2 and 1.8 or 1.1, x, y, len, 1) end
        x = x + len + 1 + floor(4 * K.hash(k, 1808))
      end
    end
    -- the rim's stones: merged into upright runs (one rect per step out)
    for side = 1, 2 do
      local rx, ry, n = nil, nil, 0
      for y = 0, 64 do
        local s = y < 64 and SPAN[y]
        local x = s and (side == 1 and s[1] - 2 or s[2] + 1)
        if x and rx and abs(x - rx) <= 1 and n < 4 then
          n = n + 1
        else
          if rx then rec(2.3 + 0.6 * K.hash(ry * 2 + side, 1809), rx, ry, 2, n) end
          if x then rx, ry, n = x, y, 1 else rx = nil end
        end
      end
    end
    -- roots reaching into the water from the rim
    for r = 1, 5 do
      local a = r / 5 * K.TAU + 0.4
      local x0, y0 = CX + cos(a) * RX * 1.1, CY + sin(a) * RY * 1.1
      for j = 0, 9 do
        local u = j / 9
        rec(2.2 - u * 0.8, x0 - cos(a) * j * 1.6 + sin(j * 0.9 + r) * 1.2, y0 - sin(a) * j * 0.9, 2, 1)
      end
    end
  end)
  -- the boils that always well: {x, y, size, phase}
  local BOIL = {}
  for k = 1, 7 do
    local a = k * 2.39
    local r = 0.15 + 0.5 * K.hash(k, 1811)
    BOIL[k] = {CX + cos(a) * RX * r, CY + sin(a) * RY * r, 1.5 + 1.5 * K.hash(k, 1812), K.hash(k, 1813)}
  end
  -- ferns close by at the corners: {x, y, dir x, dir y, length, phase}
  local FERN = {{2, 63, 1, -1, 14, 0.3}, {10, 62, 1, -1.3, 11, 1.5}, {126, 2, -1, 1, 15, 2.7}, {118, 1, -1, 1.2, 10, 3.9},
    {126, 62, -1.2, -0.8, 13, 4.6}, {3, 2, 1.2, 0.8, 12, 5.4}}
  local MICA = K.scatter(90, CX - RX + 6, CY - RY + 6, CX + RX - 6, CY + RY - 6, 1814)
  local SURF = K.scatter(72, CX - RX + 6, CY - RY + 4, CX + RX - 6, CY + RY - 4, 1815)

  function M.init() marks, well = {}, 0 end
  function M.clear() marks = {} end

  function M.note(slot, midi)
    local x = clamp(K.px(midi), CX - RX + 10, CX + RX - 10)
    local y = CY + (0.5 - K.pu(midi)) * RY * 0.8
    K.cap_add(marks, {slot = slot, x = x, y = y, t0 = K.T}, MARK_MAX)
  end

  local function sample(u, v)
    local y = floor(CY - RY + 3 + v * (RY * 2 - 6))
    local s = SPAN[y]
    if not s then return nil end
    return s[1] + 2 + u * (s[2] - s[1] - 4), y
  end

  -- a boil of sand: a ring of grains turning over, size r, light l
  local function boil(x, y, r, l, ph)
    if l < 0.3 or r < 0.5 then return end
    local n = math.max(5, floor(r * 2.2))
    for k = 0, n - 1 do
      local a = k / n * K.TAU + ph
      put(l * (0.7 + 0.3 * sin(a * 2 + ph * 3)), x + cos(a) * r, y + sin(a) * r * 0.6, 1, 1)
    end
    put(l * 0.6, x - 1, y, 2, 1)
  end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo, amp = A[K.HI], A[K.MID], A[K.NAT], A[K.LO], A[K.AMP]
    well = well + K.DTS * (0.4 + 1.2 * amp + 1.2 * sw)
    -- the bed: its sand catching the day coming down, breathing on the bar
    K.blit(bed, 1 + 0.8 * bloom + 1.5 * breath)
    -- the chord: light through the canopy lying on the bed
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local x = CX - RX + 10 + (K.cx(m) - 4) / 119 * (RX * 2 - 20) + sin(T * 0.11 + i) * 2
        local y = CY - 10 + ((i * 7) % 4) * 6
        local r = clamp(4 + (64 - m) * 0.12, 3, 8)
        local l = (1.6 + 2 * K.chord_glow + 0.8 * bloom) * p
        for dy = -floor(r * 0.6), floor(r * 0.6) do
          local hw = r * math.sqrt(math.max(0, 1 - (dy / (r * 0.6 + 0.5)) ^ 2))
          K.dither_row(l * (1 - abs(dy) / (r * 0.6 + 1) * 0.5), y + dy, nil, math.max(0, floor(x - hw)), math.min(128, floor(x + hw)))
        end
      end
    end
    -- the boils that always well, turning with the spring; a swell swells
    -- them all
    for k, b in ipairs(BOIL) do
      local pulse = 0.5 + 0.5 * sin(well * 2 + b[4] * 6)
      boil(b[1], b[2], b[3] * (0.8 + 0.4 * pulse) * (1 + 1.2 * sw), 2.4 + 1.6 * pulse + 2.5 * sw + 2 * breath, well * (1 + k * 0.1))
    end
    -- a swell: rings running out from the spring's eye
    if sw > 0.02 then
      for q = 0, 2 do
        local rr = ((T * 0.35 + q / 3) % 1)
        K.ring(CX, CY, 3 + rr * 40, 0.55, sw * 5 * (1 - rr) * ease(rr / 0.1), 18, 0)
      end
    end
    -- the forest floor beyond the rim, and the roots
    K.blit(floor_l, 1 + 0.35 * bloom)
    -- the surface: a net of light heaving slowly with out_lo
    for y = CY - RY + 3, CY + RY - 3, 6 do
      local s = SPAN[y]
      if s then
        local hv = K.heave(y * 4) * (0.4 + 1.6 * lo)
        -- (shared between the rows the heave lifts it across)
        local yy = y + hv
        local y0 = floor(yy)
        local fy = yy - y0
        local l = 1.3 + 0.6 * bloom + breath + 1.5 * amp
        local off = K.drift_x * 0.1 + y * 6.37 + well * 3 + hv * 2
        if fy < 0.9 then K.streaks(l * (1 - fy), y0, 3, 9, off, nil, nil, s[1] + 2, s[2] - 1) end
        if fy > 0.1 then K.streaks(l * fy, y0 + 1, 3, 9, off, nil, nil, s[1] + 2, s[2] - 1) end
      end
    end
    K.twinkle(SURF, hi, 13)
    -- the water sounds: the leaves' shadows and light flickering over it
    if nat > 0.02 then
      for k = 0, 19 do
        local x = 4 + (k * 29) % 120
        local y = 3 + (k * 17) % 58
        local f = sin(T * 3.3 + k * 1.7) * sin(T * 1.3 + k)
        if f > 0 then
          K.dash(nat * 13 * f, x + sin(T * 0.7 + k) * 2, y, 5)
          put(nat * 9 * f, x + 1, y + 1, 4, 1)
          put(nat * 5 * f, x + 2, y - 1, 3, 1)
        end
      end
    end
    -- the notes: sand-boils blooming, as big as their motif
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      local life = mk.slot == 4 and 6 or 4
      if age > life or done then table.remove(marks, i)
      else
        local e = ease(age / 0.3) * (1 - ease((age - (life - 2)) / 2)) * cf
        local x, y = mk.x, mk.y
        if mk.slot == 1 then
          for q = 0, 7 do
            local a = q * 0.79 + age * 3
            put(9 * e, x + cos(a) * (1.5 + age * 1.8), y + sin(a) * (1 + age), 2, 1)
          end
          put(10 * e, x - 1, y, 3, 1)
          K.ring(x, y, 3 + age * 4, 0.55, 5 * e, 16)
        elseif mk.slot == 2 then
          boil(x, y, 2 + age * 1.6, 8 * e, age * 2)
        elseif mk.slot == 3 then
          boil(x, y, 3 + age * 2.4, 8 * e, age * 1.5)
          boil(x, y, 1.5 + age * 1.2, 6 * e, -age * 2)
          K.ring(x, y, 4 + age * 4, 0.55, 4 * e, 20)
        else
          local pulse = 0.5 + 0.5 * sin(age * 4)
          boil(x, y, 2.5 + pulse * 1.5, 8.5 * e, age * 2.5)
          put(6 * e * pulse, x - 1, y - 1, 3, 2)
        end
      end
    end
    -- the moment: a shaft of sun sweeping across the bed, the mica glittering
    local ma = K.moment_age
    if ma < 14 then
      local e = ease(ma / 2) * (1 - ease((ma - 9) / 5))
      local sx = -20 + ma * 12
      for y = CY - RY, CY + RY do
        local s = SPAN[y]
        if s then
          local x0 = sx + (y - CY) * 0.5
          K.dither_row(e * 1.5, y, nil, math.max(s[1], floor(x0 - 5)), math.min(s[2], floor(x0 + 5)))
        end
      end
      for k = 1, #MICA, 2 do
        local d = abs(MICA[k] - sx - (MICA[k + 1] - CY) * 0.5)
        if d < 18 then
          local w = sin(ma * 6 + k * 1.3)
          if w > 0 then put(e * 12 * w * (1 - d / 18), MICA[k], MICA[k + 1], 2, 1) end
        end
      end
    end
    -- the ferns close by, swaying with out_mid
    for i, f in ipairs(FERN) do
      local sway = sin(T * (0.6 + 1.2 * mid) + f[6]) * (0.5 + 4.5 * mid) + K.heave(f[1]) * 0.4
      local nx, ny = -f[4], f[3]
      local nn = math.sqrt(nx * nx + ny * ny)
      nx, ny = nx / nn, ny / nn
      for j = 1, f[5] do
        local u = j / f[5]
        -- (each piece rounds its own way: a fern sways a few pieces at a
        -- time, never all of it hopping together)
        local x = f[1] + f[3] * j * 0.9 + nx * sway * u * u + K.hash(i * 16 + j, 1816)
        local y = f[2] + f[4] * j * 0.6 + ny * sway * u * u
        local l = (2.8 + bloom + 1.5 * mid) * (1 - u * 0.35) + K.bj(i * 16 + j) * 0.4
        if j % 2 == 1 then put(l, x, y, 2, 1) end
        if j % 2 == 0 and j < f[5] - 1 then
          local s = 2.2 * (1 - u * 0.6)
          put(l * 0.8, x + nx * s, y + ny * s, 1, 1); put(l * 0.8, x - nx * s, y - ny * s, 1, 1)
        end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "leaf" then
        -- a leaf spins down and lands, then drifts on the welling water
        local fall = clamp(inc.age / 4, 0, 1)
        local x0, y0 = 30 + inc.s * 60, CY + (inc.s2 - 0.5) * 20
        local x = x0 + sin(inc.age * 3) * 6 * (1 - fall) + math.max(0, inc.age - 4) * 2.5
        local y = y0 - (1 - fall) * 22 + math.max(0, inc.age - 4) * 0.8
        local a = inc.age * (fall < 1 and 4 or 0.4)
        for q = -3, 3 do put(9 * e * (1 - abs(q) * 0.12), x + cos(a) * q, y + sin(a) * q * 0.6, 2, 2) end
        put(3 * e, x - 3, y0 + 3, 7, 1)                   -- its shadow on the bed
        if fall >= 1 then
          local ra = inc.age - 4
          if ra < 4 then K.ring(x0 + 0.5, y0, 2 + ra * 4, 0.55, 6 * e * (1 - ra / 4) * ease(ra / 0.3), 18) end
        end
      elseif inc.name == "strider" then
        -- a water strider skates in short glides, dimples under its feet
        local glides = floor(inc.age / 1.4)
        local f = ease(clamp((inc.age % 1.4) / 0.45, 0, 1))
        local x = 26 + inc.s * 14 + (glides + f) * 7
        local y = CY - 8 + inc.s2 * 16 + sin(glides * 1.9) * 4
        put(9 * e, x - 2, y, 5, 1); put(6 * e, x - 1, y - 1, 3, 1)
        for k = -1, 1, 2 do
          put(6 * e, x - 4, y + k * 2, 2, 1); put(6 * e, x + 3, y + k * 2, 2, 1)
          local rr = 1.2 + 1.5 * sin(math.pi * f)
          K.ring(x - 3, y + k * 2, rr, 0.6, 4.5 * e, 8)
          K.ring(x + 3, y + k * 2, rr, 0.6, 4.5 * e, 8)
        end
      else
        -- a newt walks slowly across the bed, its tail swaying
        local x = CX - RX + 6 + u * (RX * 2 - 12)
        local y = CY + 8 + inc.s * 6 + sin(u * 4) * 2
        local step = sin(K.T * 3)
        put(6.5 * e, x - 4, y, 9, 2); put(7.5 * e, x + 4, y, 3, 2)
        put(5 * e, x - 2 + step, y - 1, 1, 1); put(5 * e, x + 2 - step, y + 2, 1, 1)
        put(5 * e, x - 2 - step, y + 2, 1, 1); put(5 * e, x + 2 + step, y - 1, 1, 1)
        for q = 1, 5 do put(5 * e * (1 - q / 6), x - 4 - q * 1.6, y + sin(K.T * 2 + q * 0.8) * q * 0.4, 2, 1) end
      end
    end
    K.glitter(sample, 40)
  end

  M.init()
  return M
end
