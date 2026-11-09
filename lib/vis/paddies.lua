-- paddies: terraced rice paddies after rain, stepping down a hillside
-- toward you, each flooded terrace a mirror of the sky, young rice in
-- rows across it, misty hills behind. the chord is the terraces' light:
-- four terraces, each mirroring a bright patch of sky across by its tone's
-- pitch, brighter for a higher tone, the light moving to its new place when
-- the chord moves. a note sends a ripple out on the terrace that matches
-- its pitch (higher notes on the higher, further terraces), across by
-- pitch, by motif: a ring (the first), a double ring (the second), a ring
-- with a bounced drop (the third), a cluster of dimples (the fourth).
-- out_lo sways the rice, out_mid ruffles the mirrors with cat's paws,
-- out_amp keeps the water moving, out_hi glints on the wet rice, and the
-- water sounds are the water trickling down from terrace to terrace. the
-- bloom is the sky's light in the mirrors; the bar breathes in it; a swell
-- brings a soft shower over the hill. a passing moment sends a band of
-- sunlight sweeping down the terraces. now and then an egret glides in to
-- land, a farmer's hat moves along a far path, or frogs ring a pool
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"egret", 18}, {"farmer", 24}, {"frogs", 12}}

  local MARK_MAX = 7
  local marks
  -- the bunds: the edge at the top of each terrace (k = 1 the furthest)
  local BASE = {13, 21, 31, 44}
  local BUND = {}
  for k = 1, 4 do
    BUND[k] = K.profile(function(x)
      return BASE[k] + (1 + k * 0.6) * sin(x * (0.035 - k * 0.003) + k * 1.3) + (0.5 + k * 0.3) * sin(x * 0.09 + k * 2.1)
    end)
  end
  -- the bottom of terrace k: the next bund, or the screen's edge
  local function bottom(k, x) return k < 4 and K.at(BUND[k + 1], x) or 64 end

  -- the hills behind, misty
  local hills = K.profile(function(x) return 6 + 3 * sin(x * 0.04 + 1) + 2 * sin(x * 0.11) + 1.5 * K.hash(x // 6, 901) end)
  local hill_l = K.bake(function(rec)
    for c = 0, 63 do
      local t = floor(hills[c] + 0.5)
      rec(1.5, c * 2, t, 2, 1)
      for y = t + 2, 12, 2 do
        if K.hash(c * 64 + y, 902) < 0.3 then rec(1, c * 2 + (y // 2) % 2, y, 1, 1) end
      end
    end
  end)
  -- the bunds' grassy tops, baked once
  local bunds = K.bake(function(rec)
    -- (merged into runs along each bund: one rect per step in its height)
    for k = 1, 4 do
      local run, ry, n = 0, floor(BUND[k][0] + 0.5), 0
      for c = 1, 64 do
        local y = c < 64 and floor(BUND[k][c] + 0.5) or -1
        if y ~= ry or c - run >= 8 then
          n = n + 1
          rec(2.6 + K.hash(n * 8 + k, 903) * 0.6, run * 2, ry, (c - run) * 2, 1)
          if k == 4 then rec(1.6, run * 2, ry + 1, (c - run) * 2, 1) end
          if K.hash(n * 8 + k, 904) < 0.5 then rec(1.4, run * 2 + 3, ry - 1, 1, 1) end
          run, ry = c, y
        end
      end
    end
  end)
  -- the rice: tufts in rows, small far off, bigger close by: {x, y, height, terrace}
  local RICE = {}
  for k = 1, 4 do
    local rows = (k + 1) // 2
    for r = 1, rows do
      local n = 5 + k * 2
      for j = 1, n do
        local x = (j - 0.5 + 0.35 * (K.hash(j * 9 + r, 905 + k) - 0.5)) / n * 128 + (r % 2) * 64 / n
        local top = K.at(BUND[k], x) + 2
        local y = top + (bottom(k, x) - top - 1) * (r / (rows + 0.6))
        if y < 63 then RICE[#RICE + 1] = {x, y, 1 + floor(k * 0.7), k, K.hash(j + r * 31, 906 + k) * 6} end
      end
    end
  end
  -- where the water trickles from one terrace into the next: {x, terrace}
  local SPILL = {{22, 1}, {84, 1}, {50, 2}, {108, 2}, {16, 3}, {74, 3}, {116, 3}, {40, 3}}
  local WGLINT = {}
  for _, r in ipairs(RICE) do WGLINT[#WGLINT + 1] = r[1]; WGLINT[#WGLINT + 1] = r[2] - r[3] end
  local FROG = {}
  for k = 1, 5 do FROG[k] = {(K.hash(k, 907) - 0.5) * 30, (K.hash(k, 908) - 0.5) * 6, K.hash(k, 909) * 0.7} end

  function M.init() marks = {} end
  function M.clear() marks = {} end

  -- the terrace a pitch belongs to, and a place on it
  local function place(midi, x)
    local u = K.pu(midi)
    local k = clamp(4 - floor(u * 3.99), 1, 4)
    local top = K.at(BUND[k], x) + 2
    local y = top + (bottom(k, x) - top) * (0.35 + 0.3 * (1 - (u * 4 % 1)))
    return k, y
  end

  function M.note(slot, midi)
    local x = K.px(midi)
    local k, y = place(midi, x)
    K.cap_add(marks, {slot = slot, x = x, y = y, k = k, t0 = K.T}, MARK_MAX)
  end

  local function sample(u, v)
    local r = RICE[1 + floor(u * #RICE) % #RICE]
    return r[1], r[2] - r[3] * v
  end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    -- the sky over the hills, and the hills in the mist
    for y = 0, 9, 1 do K.dither_row((0.12 + 0.25 * bloom + 0.45 * breath) * (1 - y / 12), y, hills, 0, 128) end
    K.blit(hill_l, 1 + 0.4 * bloom, K.drift_x * 0.03)
    -- the mirrors: each terrace lies under the sky, brightest toward its far
    -- edge; the chord's light lies across its terrace by pitch; out_mid
    -- ruffles them in cat's paws
    local sky = 0.3 + 0.4 * bloom + 0.8 * breath + 0.35 * sw
    local ma = K.moment_age
    local sweep = ma < 14 and ease(ma / 2) * (1 - ease((ma - 9) / 5)) or 0
    local sy = 10 + ma * 5
    for k = 1, 4 do
      local m, p = K.chord_at(5 - k)
      local cxp = m and K.cx(m) or 64
      local ck = m and p * (0.5 + (m - 36) / 40) * (1 + 1.5 * K.chord_glow) or 0
      local top = BASE[k] + 2
      local bot = k < 4 and BASE[k + 1] or 63
      -- (the sky's light lies near the terrace's far edge; below it, a few
      -- slow streaks of cloud drifting in the mirror)
      for y = top, math.min(bot, top + 3), 2 do
        local u = (y - top) / math.max(1, bot - top)
        K.dither_row(sky * 0.28 * (1 - u), y, nil, 0, 128)
      end
      for y = top + 2, bot - 1, 4 do
        local u = (y - top) / math.max(1, bot - top)
        local l = 1 + sky * 1.3 * (1 - 0.5 * u)
        if sweep > 0 then l = l + sweep * 6 * math.max(0, 1 - abs(y - sy) / 7) end
        K.streaks(l, y, 4 + k, 21 + k * 3, T * (3.5 + 4 * A[K.AMP]) * (0.5 + k * 0.2) + K.drift_x * 0.1 + y * 13)
        if ck > 0.02 then
          local hw = 10 + k * 3
          K.dither_row(math.min(0.6, ck * (1 - u)), y, nil, math.max(0, floor(cxp - hw)), math.min(128, floor(cxp + hw)))
          put(1.5 + ck * 3 + K.bj(y + k) * 0.4, cxp - hw * 0.4, y, hw * 0.8, 1)
        end
      end
      -- cat's paws: short bright ripples where the wind touches the water
      if mid > 0.04 then
        for j = 0, 7 do
          local x = (j * 19 + T * (3 + k) + k * 17) % 140 - 6
          local y = top + 1 + (bot - top - 2) * ((j * 0.37 + k * 0.21) % 1)
          local w = math.max(0, sin(T * 0.6 + j * 1.3 + k))
          if w > 0.1 then put(mid * 7 * w + K.bj(j + k * 8) * 0.4, x, y, 4 + k, 1) end
        end
      end
    end
    if sweep > 0 then
      for y = floor(sy / 2) * 2 - 2, floor(sy / 2) * 2 + 2, 2 do
        if y > 10 and y < 64 then
          K.streaks(sweep * (6 - abs(y - sy) * 0.6), y, 7, 18, y * 7 + T * 2)
        end
      end
    end
    K.blit(bunds, 1 + 0.4 * bloom + 0.5 * breath)
    -- the rice, swaying with out_lo, glinting with out_hi
    for i, r in ipairs(RICE) do
      local sway = sin(T * 0.8 + r[5] + r[1] * 0.03) * (0.5 + 1.8 * lo) * r[4] * 0.35 + K.heave(r[1]) * 0.15 * r[4]
      local l = 2.2 + 0.6 * bloom + r[4] * 0.3 + K.bj(i) * 0.4 + 0.6 * K.energy
      put(l, r[1], r[2] - r[3] + 1, 1, r[3])
      put(l * 0.85 + hi * 4 * math.max(0, sin(T * 3.1 + i * 1.7)), r[1] + sway, r[2] - r[3] - 1, 1, 2)
      if r[4] >= 3 then put(l * 0.8, r[1] + 1 + sway * 0.6, r[2] - r[3], 1, 1) end
    end
    K.twinkle(WGLINT, hi, 12)
    -- the water trickling down from terrace to terrace
    if nat > 0.03 then
      for i, s in ipairs(SPILL) do
        local y0 = K.at(BUND[s[2] + 1], s[1])
        for q = 0, 3 do
          local u = ((T * 1.5 + q * 0.25 + i * 0.13) % 1)
          put(nat * (7 - u * 3), s[1] + sin(u * 3 + i) * 0.5, y0 - 1 + u * 4, 2, 2)
        end
        K.ring(s[1], y0 + 4, 1.5 + ((T * 2 + i) % 1) * 3, 0.4, nat * 4, 10)
      end
    end
    -- the notes' ripples
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.12) * (1 - age / 4) * cf
        local sq = 0.2 + mk.k * 0.06
        local s = 0.6 + mk.k * 0.2
        local x, y = mk.x, mk.y
        if mk.slot == 1 then
          K.ring(x, y, (1.5 + age * 5) * s, sq, 8 * e, 18)
        elseif mk.slot == 2 then
          K.ring(x, y, (2 + age * 8) * s, sq, 7 * e, 22)
          K.ring(x, y, (1 + age * 5) * s, sq, 6 * e, 14)
          put(7 * e, x - 1, y - 2, 3, 1); put(7 * e, x, y - 3, 1, 3)
        elseif mk.slot == 3 then
          K.ring(x, y, (1.5 + age * 4.5) * s, sq, 7.5 * e, 16)
          if age < 0.6 then put(9 * e * sin(age / 0.6 * math.pi), x, y - sin(age / 0.6 * math.pi) * 5 * s, 1, 1) end
        else
          for q = 0, 3 do
            local a = q * 1.7
            K.ring(x + cos(a) * 4 * s, y + sin(a) * 1.5, (1 + age * 2.5) * s, sq, 6.5 * e, 10)
          end
        end
        put(4 * e, x - 1, y, 3, 1)
      end
    end
    -- a swell: a soft shower drifting over the hill, rings on every terrace
    if sw > 0.03 then
      for q = 0, 13 do
        local x = (q * 9.3 + T * 4) % 128
        local y = (q * 11 + T * 40) % 60 + 2
        put(sw * 5 + K.bj(q) * 0.4, x - y * 0.1, y, 1, 4)
        local rr = (T * 1.5 + q * 0.37) % 1
        local ry = 16 + (q * 17) % 46
        if q % 3 == 0 then K.ring((q * 29) % 124 + 2, ry, 1 + rr * 4, 0.3, sw * 4.5 * (1 - rr), 8) end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "egret" then
        -- an egret glides in, lands in a terrace and stands
        local lx, ly = 30 + inc.s * 60, K.at(BUND[4], 30 + inc.s * 60) + 8
        local land = ease(clamp(inc.age / 5, 0, 1))
        local fe = e * (1 - ease(clamp((inc.age - 4) / 1.2, 0, 1)))
        local se = e * ease(clamp((inc.age - 4) / 1.2, 0, 1))
        if fe > 0.01 then
          K.bird(lx - (1 - land) * 60, ly - 6 - (1 - land) * 30, 9 * fe, sin(K.NOW * 3), 2)
        end
        if se > 0.01 then
          local look = sin(inc.age * 0.5) > 0.6 and 1 or 0
          put(9 * se, lx - 2, ly - 7, 5, 3); put(9 * se, lx + 2, ly - 12 + look, 1, 5)
          put(9.5 * se, lx + 3, ly - 12 + look, 3, 1)
          put(6 * se, lx - 1, ly - 4, 1, 4); put(6 * se, lx + 1, ly - 4, 1, 4)
          for d = 1, 4 do put(3 * se, lx - 2, ly + d, 6, 1) end
        end
      elseif inc.name == "farmer" then
        -- a farmer's hat moving along the far bund, tiny
        local x = 10 + u * 108
        local y = K.at(BUND[2], x) - 1
        local bob = sin(inc.age * 3) > 0 and 0 or 1
        put(8 * e, x - 3, y - 3 + bob, 7, 1); put(9 * e, x - 2, y - 4 + bob, 5, 1); put(9 * e, x - 1, y - 5 + bob, 3, 1)
        put(6 * e, x - 1, y - 2 + bob, 3, 3)
        put(4 * e, x - 3, y + 3, 7, 1); put(3 * e, x - 2, y + 5, 5, 1)
      else
        -- frogs ringing a pool, one after another
        local cx, cy = 40 + inc.s * 50, K.at(BUND[3], 40 + inc.s * 50) + 6
        for q, f in ipairs(FROG) do
          local t = (inc.age * 0.45 + f[3]) % 1.4
          if t < 1 then
            local re = e * (1 - t)
            K.ring(cx + f[1], cy + f[2], 1.5 + t * 7, 0.3, 7 * re, 16)
            if t < 0.3 then put(8 * e * sin(t / 0.3 * math.pi), cx + f[1] - 1, cy + f[2] - 1, 3, 2) end
          end
        end
      end
    end
    K.glitter(sample, 30)
  end

  M.init()
  return M
end
