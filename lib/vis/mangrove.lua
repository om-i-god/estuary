-- mangrove: a mangrove at the waterline. a dark canopy hangs across the
-- top, far trunks stand dim in the shade behind, and close by three trunks
-- split into prop roots that arch down into slow, tea-coloured water, with
-- aerial roots hanging from the branches. the tide comes in among the roots
-- as the bloom rises and drains as it falls. the chord is four big roots
-- arching into the water in front, across by pitch, wider for lower tones,
-- their backs catching the light, shifting to their new places when the
-- chord moves, each lying again in the water. out_lo sways the hanging
-- roots, out_mid wobbles the reflections, out_amp keeps the water moving,
-- out_hi glints on it and lets flecks of sun through the leaves, and the
-- water sounds lap at the roots. a note at its pitch: a small fish flicks
-- between the roots (the first motif), a pair dart together (the second), a
-- fish rises and rings the surface (the third), a fish turns, trailing a
-- glint (the fourth). the bar breathes on the water; a swell surges the
-- tide in. a passing moment sends shafts of sun down through the canopy.
-- now and then a heron stalks the shallows, a mudskipper hops along a root,
-- or a canoe glides past
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"heron", 20}, {"mudskipper", 12}, {"canoe", 20}}

  local MARK_MAX = 6
  local marks
  local wl = 40                           -- the water's surface this frame

  -- the canopy: leaves hanging down from the top, ragged below
  local can = K.profile(function(x)
    return 7 + 3 * sin(x * 0.06 + 0.5) + 3 * K.hash(x // 4, 601) + 2 * math.max(0, sin(x * 0.17 + 2))
  end)
  local canopy = K.bake(function(rec)
    local k = 0
    for y = 0, 15 do
      local x = 0
      while x < 128 do
        k = k + 1
        local len = 2 + floor(4 * K.hash(k, 602))
        local b = K.at(can, x)
        if y < b and K.hash(k, 603) < 0.36 - 0.22 * (y / b) then rec(K.hash(k, 604) < 0.2 and 2 or 1, x, y, len, 1) end
        x = x + len + floor(3 * K.hash(k, 605))
      end
    end
    for c = 0, 63 do rec(1.6, c * 2, floor(can[c] + 0.5), 2, 1) end
  end)
  -- far trunks in the shade, and the near trunks with their prop roots
  local far = K.bake(function(rec)
    for k = 1, 6 do
      local x = floor(10 + (k - 1) * 22 + 8 * K.hash(k, 606))
      rec(1, x, 8, 1, 34)
      for r = 1, 2 do
        local d = (K.hash(k * 3 + r, 607) < 0.5) and -1 or 1
        for j = 1, 6 do rec(1, x + d * j, 30 + j * 1.6, 1, 2) end
      end
    end
  end)
  local TRUNK = {20, 63, 107}
  local near = K.bake(function(rec)
    for t, x in ipairs(TRUNK) do
      -- (a trunk with bark: short pieces of their own levels, a little
      -- crooked, its lit side broken; never a solid bar)
      for y = 6, 24, 2 do
        local jog = floor(1.6 * K.hash(t * 40 + y, 615) - 0.3)
        rec(2 + 0.8 * K.hash(t * 40 + y, 616), x - 1 + jog, y, 3, 2)
        if K.hash(t * 40 + y, 617) < 0.75 then rec(1.5, x + 2 + jog, y, 1, 2) end
        if K.hash(t * 40 + y, 618) < 0.3 then rec(2.9, x - 1 + jog, y, 1, 1) end
      end
      -- its prop roots: arching out and down
      for r = 1, 4 do
        local d = (r % 2 == 0) and -1 or 1
        local span = 6 + 9 * K.hash(t * 8 + r, 608)
        local y0 = 18 + 6 * K.hash(t * 8 + r, 609)
        for j = 0, 10 do
          local u = j / 10
          local xx = x + d * span * u
          local yy = y0 - 4 * sin(u * math.pi * 0.8) + u * u * (48 - y0)
          rec(1.8 - u * 0.4, xx, yy, 1 + (j % 2), 2)
        end
      end
    end
  end)
  -- aerial roots hanging from the branches: {x, length, phase}
  local HANG = {}
  for k = 1, 9 do HANG[k] = {6 + (k - 1) * 14 + 6 * K.hash(k, 610), 6 + 16 * K.hash(k, 611), K.hash(k, 612) * 6} end
  local SUNFLECK = K.scatter(26, 2, 2, 126, 14, 613)
  local WGLINT = K.scatter(44, 2, 44, 126, 62, 614)

  function M.init() marks = {} end
  function M.clear() marks = {} end

  function M.note(slot, midi)
    local x = K.px(midi)
    local y = 46 + (1 - K.pu(midi)) * 14
    K.cap_add(marks, {slot = slot, x = x, y = y, t0 = K.T, dir = K.rnd() < 0.5 and -1 or 1}, MARK_MAX)
  end

  local function sample(u, v) return u * 127, wl + 2 + v * (61 - wl) end
  -- the reflections' wobble, made once (its inputs set each frame)
  local F_y, F_wob = 0, 0
  local function nudge(x) return sin(F_y * 0.9 + K.T * 1.7 + x * 0.05) * F_wob, 0 end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    -- the tide: up among the roots as the bloom rises, a swell surges it in
    wl = 43 - 5 * bloom - 4 * sw + 0.8 * K.tide_dir
    local W = floor(wl + 0.5)
    -- light filtering down under the canopy, warmer with the daylight
    for y = 15, W - 1, 3 do
      K.dither_row((0.08 + 0.14 * bloom + 0.5 * breath) * (1 - (W - y) / 40), y, can, 0, 128)
    end
    K.blit(far, 1 + 0.4 * bloom, K.drift_x * 0.05)
    K.blit(near, 1 + 0.35 * bloom)
    K.blit(canopy, 1 + 0.5 * bloom)
    K.twinkle(SUNFLECK, math.max(hi, 0.25 * bloom), 11)
    -- the tea-coloured water: a faint body, streaks of light, the reflections
    -- (the rows keep to a fixed grid: the tide rising covers or uncovers
    -- one row at a time, never shifts them all)
    for y = 30, 63, 3 do
      if y > W then
      local d = (y - W) / 22
      K.dither_row((0.06 + 0.09 * bloom + 0.55 * breath) * (1 - d * 0.5), y, nil, 0, 128)
      end
    end
    local wob = 0.5 + 2.5 * mid
    for y = 29, 63, 3 do
      if y > W + 1 then
      local d = (y - W) / 22
      local off = K.drift_x * (0.4 + d * 0.6) + T * (1 + 3 * A[K.AMP]) + y * 6.1
      F_y, F_wob = y, wob
      K.streaks(1.6 + 0.6 * bloom + breath * 2.2 + d * 0.5, y, 3 + d * 4, 17, off, nil, nudge)
      end
    end
    K.streaks(2.2 + bloom + breath * 1.4, W, 8, 11, K.drift_x * 0.2)
    -- the near trunks' reflections, broken and wobbling
    for _, x in ipairs(TRUNK) do
      for d = 2, 14, 3 do K.dash(1.6, x - 1 + sin(T * 1.5 + d + x) * wob * 0.6, W + d, 3, 2) end
    end
    -- the chord's roots: four big arches into the water, their backs lit
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      if m and p > 0.02 then
        local x = 8 + K.cx(m) * 0.88
        local span = clamp(9 + (60 - m) * 0.3, 7, 17)
        local base = 45
        local top = base - 14 - (m - 36) * 0.12
        local l = (2.6 + 0.9 * bloom + 3 * K.chord_glow + 1.2 * breath) * p
        for j = 0, 14 do
          local u = j / 14
          local xx = x - span + 2 * span * u
          local yy = base - (base - top) * sin(u * math.pi)
          -- (at a fraction of a pixel: an arch gliding to its new place
          -- slides, its pieces never hop)
          K.dash(l + 1.2 * sin(u * math.pi) + K.bj(i * 16 + j) * 0.5, xx, yy, 2, 2)
          -- (and lying in the water below)
          local ry = 2 * W - yy + 3
          if yy > W + 1 then ry = 99 end
          -- (its wobble shared between columns, so the reflection shivers
          -- softly instead of flicking a pixel back and forth)
          if ry < 63 and j % 2 == 0 then K.dash(l * 0.4, xx + sin(T * 1.5 + j) * wob * 0.5, ry, 2) end
        end
      end
    end
    -- the water sounds lapping at the roots
    if nat > 0.03 then
      for k = 0, 20 do
        local x = k * 6 + 2 + sin(T * 1.3 + k) * 2
        local f = sin(T * 2.2 + k * 1.7)
        local l = nat * (3.5 + 3.5 * math.max(0, f))
        local up = K.ramp(f, 0.3, 0.7)
        put(l * up, x, W, 5, 1); put(l * (1 - up), x, W + 1, 5, 1)
        local g = sin(T * 1.6 + k * 2.3)
        if g > 0 then put(nat * 4 * g, x + 3, W + 3 + (k % 3) * 3, 3, 1) end
      end
    end
    K.twinkle(WGLINT, hi, 13)
    -- out_lo rolls broad slow swells of light across the water
    if lo > 0.05 then
      for b = 0, 1 do
        local bx = (T * 5 + b * 64 + K.drift_x * 0.3) % 170 - 20
        for y = 30, 63, 3 do
          if y > W + 1 then put(lo * 2.6 + K.bj(y + b * 7) * 0.4, bx + sin(y * 0.2 + T * 0.3) * 5, y, 16, 1) end
        end
      end
    end
    -- the hanging aerial roots, swaying with out_lo
    for k, h in ipairs(HANG) do
      local top = K.at(can, h[1])
      local sway = sin(T * 0.6 + h[3]) * (0.3 + 5 * lo) + K.heave(h[1]) * 0.6
      for j = 0, h[2], 3 do
        local u = j / h[2]
        put(2 + 0.6 * bloom + K.bj(k * 8 + j) * 0.4, h[1] + sway * u * u, top + j, 1, 3)
      end
      put(2.4 + bloom, h[1] + sway, top + h[2] + 2, 1, 1)
    end
    -- the notes: small fish between the roots
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4.5 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.15) * (1 - ease((age - 2) / 2.5)) * cf
        local go = 1 - math.exp(-age * 2.2)
        local x, y, d = mk.x, math.max(mk.y, W + 3), mk.dir
        if mk.slot == 1 then
          local fx = x + d * go * 14
          put(9 * e, fx - 3, y, 7, 1); put(7 * e, fx - 2, y - 1, 5, 1); put(5 * e, fx - d * 5, y - 1, 1, 3)
          put(3.5 * e, fx - 4, y + 2, 9, 1)
        elseif mk.slot == 2 then
          for q = 0, 1 do
            local fx = x + d * go * (10 + q * 4) - q * 3
            local fy = y + q * 3 - 1
            put(8 * e, fx - 1, fy, 4, 1); put(4.5 * e, fx - d * 3, fy, 1, 1)
          end
        elseif mk.slot == 3 then
          put(7 * e * (1 - go), x - 2, y, 5, 1)
          local ra = age - 0.5
          if ra > 0 then
            K.ring(x, W + 1, 1.5 + ra * 4, 0.35, 8 * e, 16, 0, W - 1, 64)
            K.ring(x, W + 1, 1 + ra * 2.2, 0.35, 5 * e, 10, 0, W - 1, 64)
          end
        else
          local a = age * 2.4
          local fx, fy = x + sin(a) * 7, y + cos(a) * 2.5
          put(8.5 * e, fx - 1, fy, 3, 1)
          for q = 1, 4 do put(6 * e * (1 - q / 5), x + sin(a - q * 0.35) * 7, y + cos(a - q * 0.35) * 2.5, 1, 1) end
        end
      end
    end
    -- the moment: shafts of sun slanting down through the canopy
    local ma = K.moment_age
    if ma < 15 then
      local e = ease(ma / 3) * (1 - ease((ma - 10) / 5))
      for s = 0, 3 do
        local x0 = 18 + s * 28 + sin(ma * 0.15 + s) * 3
        for y = 12, W, 2 do
          local u = (y - 12) / (W - 12)
          put(e * (3.2 - u * 1.4) + K.bj(s * 32 + y) * 0.5, x0 + y * 0.45, y, 2 + floor(u * 2.5), 1)
        end
        put(e * 3, x0 + W * 0.45 - 2, W + 1, 9, 1)
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "heron" then
        -- a heron stalks slowly through the shallows, stopping to look
        local x = 100 - u * 60 + sin(inc.age * 0.3) * 2
        local step = sin(inc.age * 1.2)
        local y = W
        put(6 * e, x - 2, y - 9, 6, 3); put(5 * e, x - 4, y - 8, 2, 1)
        put(6 * e, x - 2, y - 14, 1, 5); put(6.5 * e, x - 5, y - 14, 4, 1)
        put(5 * e, x + step * 0.8, y - 6, 1, 6); put(5 * e, x + 2 - step * 0.8, y - 6, 1, 6)
        for d = 2, 8, 3 do put(2.5 * e, x - 2 + sin(T + d) * 0.5, y + d, 5, 1) end
      elseif inc.name == "mudskipper" then
        -- a mudskipper hops along a root, pausing between hops
        local hops = floor(inc.age / 1.8)
        local f = clamp((inc.age % 1.8) / 0.5, 0, 1)
        local x = 14 + inc.s * 30 + (hops + ease(f)) * 7
        local y = W - 1 - sin(f * math.pi) * 5
        put(8 * e, x - 3, y - 3, 7, 3); put(10 * e, x + 2, y - 4, 2, 1)
        put(6.5 * e, x - 6, y - 2, 3, 1); put(6 * e, x - 1, y, 3, 1)
        put(2.5 * e, x - 3, W + 1, 7, 1)
      else
        -- a canoe glides past, a paddler dipping
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (-24 + u * 176) or (152 - u * 176)
        local y = W + 3
        local pd = sin(inc.age * 1.6)
        put(6.5 * e, x - 12, y, 25, 1); put(5 * e, x - 10, y + 1, 21, 1)
        put(6 * e, x - 1, y - 5, 3, 5); put(6.5 * e, x - 1, y - 7, 2, 2)
        put(5 * e, x + 2 + pd * 2, y - 3 + pd, 1, 4)
        for d = 3, 9, 3 do put(2.2 * e, x - 12 + sin(T + d) * 0.6, y + d, 25, 1) end
      end
    end
    K.glitter(sample, 34)
  end

  M.init()
  return M
end
