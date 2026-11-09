-- echo bridge: an old concrete bridge over a slow river at sunset, one
-- broad arch under a closed spandrel wall, its reflection completing the
-- ellipse in the water; trees stand on the banks behind it, and through
-- the arch the far bank and the evening sky. the place is about echoes: a
-- note rises as a soft ring of light under the arch at its pitch, then
-- comes back as fading copies at the echo time, bouncing along the arch's
-- curve, each the feedback quieter (a ring, an opening arc, a pair of
-- small rings, a burst of points: one for each motif). out_amp and out_mid
-- set how far along the arch the echoes travel, and as the sound falls
-- away its tail lingers as light on the arch's underside. the chord is four
-- warm lanterns strung along the far bank through the arch, across by
-- pitch, sliding to their new places when it changes, each lying in the
-- water. out_lo rolls a slow swell under the arch, out_hi glints on the
-- water and the lanterns, and the water sounds are the river's murmur
-- across its surface. the bloom is the sunset's glow, deepening and
-- warming; the bar breathes in it; a swell brings the river up the piers.
-- a passing moment makes the whole arch ring with light. now and then a
-- heron flies through the arch, a kayak passes beneath, or swallows dart
-- out from under it
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs, sqrt = math.sin, math.cos, math.floor, math.abs, math.sqrt

  M.incidents = {{"heron", 9}, {"kayak", 20}, {"swallows", 10}}

  local AX, AY, AW, AH = 64, 41, 40, 21   -- the arch: centre of its springing, half span, rise
  local DECK = 12                         -- the deck's top
  local WL = 41
  local MARK_MAX = 6
  local ECHO_BEATS = {0.5, 1, 1.5, 2}     -- same order as the echo time param
  local marks
  local tail = 0                          -- the sound's tail, lingering

  -- the arch's inner edge at angle a (0 at the left springing, pi at the right)
  local function arch(a) return AX - cos(a) * AW, AY - sin(a) * AH end
  -- the opening under the arch on row y: its left and right edges
  local function opening(y)
    local d = (AY - y) / AH
    if d < 0 or d > 1 then return nil end
    local hw = AW * sqrt(1 - d * d)
    return AX - hw, AX + hw
  end

  -- the trees on the banks behind, above the deck
  local trees = K.crowns(1101, 10, DECK - 1, 3, 9, 4, 9)
  local tprof = K.profile(function(x) return trees(x) end)
  local wood = K.bake(function(rec)
    for c = 0, 63 do
      local t = floor(tprof[c] + 0.5)
      if t < DECK - 1 then
        rec(1.6, c * 2, t, 2, 1)
        for y = t + 2, DECK - 1, 2 do
          if K.hash(c * 64 + y, 1102) < 0.35 then rec(1, c * 2 + (y // 2) % 2, y, 1, 1) end
        end
      end
    end
  end)
  -- the bridge: parapet and deck, the spandrel wall's concrete, the arch
  -- ring's stones, the piers; baked once
  local bridge = K.bake(function(rec)
    -- (the parapet's coping in weathered pieces, its posts at their own
    -- spacing: old concrete, not a ruled line)
    for x = 0, 127, 5 do rec(2.3 + 0.6 * K.hash(x, 1114), x, DECK, math.min(5, 128 - x), 1) end
    local px = 1
    while px < 128 do
      rec(1.8 + 0.4 * K.hash(px, 1115), px, DECK - 1, 2, 1)
      px = px + 5 + floor(3 * K.hash(px, 1116))
    end
    for x = 0, 127, 7 do rec(1.4 + 0.4 * K.hash(x, 1117), x, DECK + 2, math.min(7, 128 - x), 1) end
    local k = 0
    for y = DECK + 3, WL do
      local l, r = opening(y)
      local x = 0
      while x < 128 do
        k = k + 1
        local len = 2 + floor(5 * K.hash(k, 1103))
        local inside = l and x + len > l - 2 and x < r + 2
        if not inside and K.hash(k, 1104) < 0.13 + 0.08 * sin(x * 0.1 + y * 0.5) then
          rec(K.hash(k, 1105) < 0.15 and 2 or 1, x, y, len, 1)
        end
        x = x + len + 1 + floor(2 * K.hash(k, 1106))
      end
    end
    -- the arch ring: stones round the opening, their joints showing
    for j = 0, 40 do
      local a = j / 40 * math.pi
      local x, y = arch(a)
      rec(j % 3 == 0 and 2 or 3.4, x - 1, y - 1, 2, 1)
      local ox, oy = AX - cos(a) * (AW + 3), AY - sin(a) * (AH + 3)
      rec(1.5, ox - 1, oy, 2, 1)
    end
    -- the piers' feet in the water
    rec(2, 0, WL, AX - AW, 1); rec(2, AX + AW, WL, 128 - AX - AW, 1)
  end)
  -- the far bank seen through the arch
  local farbank = K.bake(function(rec)
    for x = AX - AW + 2, AX + AW - 2, 2 do
      local y = 33 + floor(1.5 * sin(x * 0.15) + K.hash(x, 1107) * 1.5)
      rec(1.4, x, y, 2, 1)
      if K.hash(x, 1108) < 0.4 then rec(1, x, y - 1 - floor(2 * K.hash(x, 1109)), 1, 1) end
    end
  end)
  local WGLINT = K.scatter(34, 2, WL + 3, 126, 62, 1110)
  local LAN = {}                          -- the lanterns this frame: x, y, presence
  for i = 1, 4 do LAN[i] = {AX - 20 + i * 8, 34, 0} end
  local SWALLOW = {}
  for k = 1, 5 do SWALLOW[k] = {K.hash(k, 1111) * 6, 0.6 + 0.6 * K.hash(k, 1112), (K.hash(k, 1113) - 0.5) * 2} end

  function M.init() marks, tail = {}, 0 end
  function M.clear() marks, tail = {}, 0 end

  function M.note(slot, midi)
    local x = clamp(K.px(midi), AX - AW + 6, AX + AW - 6)
    local a0 = math.acos(clamp((AX - x) / AW, -1, 1))
    K.cap_add(marks, {slot = slot, x = x, a0 = a0, t0 = K.T, dir = (x < AX) and 1 or -1}, MARK_MAX)
  end

  local function sample(u, v) return u * 127, WL + 2 + v * 20 end
  -- the water rows' sparkle (out_hi), made once (inputs set each frame)
  local F_y, F_hi = 0, 0
  local function sparkle(x)
    local g = sin(x * 0.8 + F_y * 1.7 + K.T * 3.6)
    return 0, g > 0.3 and F_hi * 7 * (g - 0.3) or 0
  end

  -- one note's mark: a soft ring (or arc, pair, burst) of light at x, y
  local function mark(slot, x, y, l, age)
    if l < 0.3 then return end
    if slot == 1 then
      K.ring(x, y, 2.5 + age * 1.5, 0.8, l, 12)
      put(l * 0.7, x - 1, y, 2, 1)
    elseif slot == 2 then
      K.ring(x, y, 3.5 + age * 1.5, 0.7, l, 14, math.pi, -1, y + 0.5)
      put(l * 0.6, x - 2, y, 4, 1)
    elseif slot == 3 then
      K.ring(x - 3, y, 1.8 + age, 0.9, l, 8); K.ring(x + 3, y, 1.8 + age, 0.9, l, 8)
    else
      for q = 0, 5 do
        local a = q / 6 * K.TAU + age
        put(l, x + cos(a) * (2 + age * 2), y + sin(a) * (1.5 + age * 1.2), 1, 1)
      end
      put(l, x, y, 1, 1)
    end
  end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    local amp = A[K.AMP]
    -- the tail: follows the sound up quickly and lets go slowly
    tail = K.follow(tail, amp, amp > tail and 0.15 or 3.5, K.DT)
    -- the sunset sky over the deck and through the arch, glowing deeper
    -- and warmer with the bloom
    local glow = 0.45 + 0.6 * bloom + 0.9 * breath
    for y = 0, DECK - 2 do K.dither_row(glow * (0.35 + 0.65 * y / DECK) * 0.6, y, tprof, 0, 128) end
    for y = AY - AH + 1, 32, 2 do
      local l, r = opening(y)
      if l then K.dither_row(glow * (0.3 + 0.4 * (y - AY + AH) / AH), y, nil, floor(l + 2), floor(r - 1)) end
    end
    K.blit(wood, 1 + 0.35 * bloom)
    K.blit(farbank, 1 + 0.4 * bloom)
    K.blit(bridge, 0.9 + 0.35 * bloom + 0.3 * breath)
    -- the low sun catching the parapet, glinting with out_hi
    if hi > 0.03 then
      for x = 1, 127, 4 do
        local g = sin(x * 0.9 + T * 3.3) * sin(x * 0.23 - T * 1.1)
        if g > 0.25 then put(hi * 9 * (g - 0.25), x, DECK, 2, 1) end
      end
    end
    -- the tail lingering on the arch's underside as light
    if tail > 0.03 then
      for j = 2, 38, 2 do
        local a = j / 40 * math.pi
        local x, y = arch(a)
        put(tail * 7 * (0.6 + 0.4 * sin(a)) + K.bj(j) * 0.4, x - 1, y + 1, 2, 1)
        if j % 4 == 2 then put(tail * 3.5, x - 1, y + 3, 2, 1) end
      end
    end
    -- the lanterns (the chord), strung along the far bank
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      local L = LAN[i]
      if m then
        L[1] = AX - AW + 8 + (K.cx(m) - 4) / 119 * (AW * 2 - 16)
        local u = (L[1] - (AX - AW)) / (AW * 2)
        L[2] = 27 + 4 * sin(u * math.pi)
      end
      L[3] = m and p or 0
    end
    for q = 0, 20 do
      local u = q / 20
      local x = AX - AW + 6 + u * (AW * 2 - 12)
      put(1.3 + 0.4 * bloom, x, 27 + 4 * sin(u * math.pi) - 1, 2, 1)
    end
    for i = 1, 4 do
      local L = LAN[i]
      if L[3] > 0.02 then
        local l = (6.5 + 2.5 * K.chord_glow + 1.2 * breath) * L[3]
        local tw = hi * 3 * math.max(0, sin(T * 4.1 + i * 2))
        -- (a lantern and its rounded halo, not a lit box)
        put(l + tw, L[1] - 1, L[2], 2, 2)
        put(l * 0.42, L[1] - 3, L[2], 6, 2)
        put(l * 0.32, L[1] - 2, L[2] - 1, 4, 1); put(l * 0.32, L[1] - 2, L[2] + 2, 4, 1)
        for d = 2, 10, 2 do put(l * (0.5 - d * 0.03), L[1] - 1 + sin(T * 1.6 + d + i) * (0.6 + 1.6 * lo), WL + (WL - L[2]) * 0.6 + d * 0.6, 2, 1) end
      end
    end
    -- the river: the arch's reflection completing the ellipse, the murmur
    -- of the water sounds across it, a slow swell rolling under the arch
    local wl = WL - floor(sw * 2.5 + 0.5)
    for j = 1, 39, 2 do
      local a = j / 40 * math.pi
      local x, y = arch(a)
      local ry = 2 * WL - y + 1
      if ry > wl + 1 and ry < 64 then
        put(1.8 + 0.6 * bloom + breath, x - 1 + K.heave(x + ry) * (0.4 + lo), ry, 2, 1)
      end
    end
    for y = 44, 63, 4 do
      if y > wl then
        local d = (y - WL) / 22
        F_y, F_hi = y, hi
        K.streaks(1.3 + 0.8 * bloom + breath * 1.2 + nat * 2.2, y, 3 + d * 4 + nat * 4, 18 - floor(nat * 5), K.drift_x * (0.3 + d * 0.4) + T * (2.5 + 2.5 * nat + 3 * amp) + y * 7, nil, sparkle)
      end
    end
    if lo > 0.05 then
      for b = 0, 1 do
        local bx = (T * 5 + b * 64) % 170 - 20
        for y = 43, 63, 3 do
          if y > wl then put(lo * 3.2 + K.bj(y + b) * 0.4, bx + sin(y * 0.2 + T * 0.3) * 4, y, 14, 1) end
        end
      end
    end
    K.streaks(2.2 + bloom + breath, wl, 6, 9, K.drift_x * 0.2)
    K.twinkle(WGLINT, hi, 12)
    -- the sky through the arch lying in the water, wavering with out_mid
    for y = WL + 2, WL + 18, 2 do
      local l, r = opening(2 * WL - y)
      if l and y > wl then
        local w = (0.6 + 4.5 * mid)
        for x = floor(l) + 2, r - 3, 6 do
          local f = sin(x * 0.4 + y * 0.9 - T * 2.2)
          if f > -0.2 then put(1 + w * (f + 0.2) * 0.6 + K.bj(x + y) * 0.4, x + f * mid * 2, y, 3, 1) end
        end
      end
    end
    -- the notes and their echoes bouncing along the arch
    local fb, div = K.echo()
    if div == 1 then fb = math.min(fb, 0.6) end    -- (as the engine caps it at 1/8)
    local tempo = K.S and tonumber(K.S.tempo) or 72
    local delay = (ECHO_BEATS[div] or 1.5) * 60 / clamp(tempo or 72, 20, 300)
    local reach = 0.25 + 0.45 * amp + 0.35 * mid      -- how far along the arch each echo goes (rad)
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      local life = 3 + 3 * delay
      if age > life or done then table.remove(marks, i)
      else
        -- the note: rising from the water toward the arch
        local e = ease(age / 0.25) * (1 - ease((age - 1) / 1.6)) * cf
        local ax, ay = arch(mk.a0)
        local rise = ease(age / 1.2)
        mark(mk.slot, mk.x, (WL - 4) + (ay + 5 - WL + 4) * rise, 8.5 * e, age)
        -- its echoes, each the feedback quieter, further along the curve
        local lvl = fb
        for n = 1, 3 do
          local ea = age - n * delay
          if lvl < 0.15 then break end
          if ea > 0 then
            local ee = ease(ea / 0.25) * (1 - ease((ea - 0.6) / 1.2)) * cf
            local a = clamp(mk.a0 + mk.dir * n * reach, 0.15, math.pi - 0.15)
            local x, y = arch(a)
            mark(mk.slot, x, y + 5, 8.5 * lvl * ee, ea)
          end
          lvl = lvl * fb
        end
      end
    end
    -- the moment: the whole arch rings with light, rings opening under it
    local ma = K.moment_age
    if ma < 14 then
      local e = ease(ma / 2.5) * (1 - ease((ma - 9) / 5))
      for r = 0, 2 do
        local s = 0.55 + ((ma * 0.12 + r / 3) % 1) * 0.45
        local f = 1 - abs(s - 0.775) * 4.5
        if f > 0 then
          for j = 1, 23 do
            local a = j / 24 * math.pi
            put(e * f * 8 + K.bj(j + r * 8) * 0.4, AX - cos(a) * AW * s - 1, AY - sin(a) * AH * s, 2, 1)
          end
        end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "heron" then
        -- a heron flies through under the arch, slow wingbeats
        local dir = inc.s > 0.5 and 1 or -1
        local x = dir > 0 and (-14 + u * 156) or (142 - u * 156)
        local y = 31 + sin(u * 3) * 2
        K.bird(x, y, 8 * e, sin(K.NOW * 2.6), 2)
        put(3 * e, x - 3, WL + (WL - y) * 0.6, 7, 1)
      elseif inc.name == "kayak" then
        local x = -20 + u * 168
        local y = WL + 5 + inc.s2 * 4
        local pd = sin(inc.age * 1.8)
        put(7 * e, x - 9, y, 19, 1); put(5.5 * e, x - 7, y + 1, 15, 1)
        put(6.5 * e, x - 1, y - 4, 2, 4); put(7 * e, x - 1, y - 6, 2, 2)
        put(6 * e, x - 4 + pd * 2, y - 3 - pd, 9, 1)
        for d = 3, 9, 3 do put(2.4 * e, x - 9 + sin(T + d) * 0.6, y + d, 19, 1) end
      else
        -- swallows dart out from under the arch and loop away
        for k, s in ipairs(SWALLOW) do
          local t = inc.age * s[2] + s[1] * 0.2
          local f = clamp((inc.age - k * 0.4) / (inc.dur - 2), 0, 1)
          local x = AX + s[3] * 10 + sin(t * 2.5 + s[1]) * (12 + 40 * f)
          local y = AY - AH + 3 + f * 6 + cos(t * 3 + s[1]) * (3 + 10 * f)
          K.bird(x, y, 9 * e * ease(f / 0.1), sin(K.NOW * 16 + k), 1)
          put(4 * e * ease(f / 0.1), x - 1, y + 1, 3, 1)
        end
      end
    end
    K.glitter(sample, 26)
  end

  M.init()
  return M
end
