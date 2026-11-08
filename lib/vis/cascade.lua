-- cascade: a small waterfall stepping down a rock face into a pool, woods
-- above it and ferns close by. the chord is the stepped ledges the water
-- falls over: four lips one below the other, each set across by its
-- tone's pitch and wider for lower tones, so the fall steps left and right
-- down the rock and shifts slowly when the chord moves. the falling sheet
-- runs faster as the sound grows; out_mid textures it with streaks, the
-- water sounds whiten it where it lands on each ledge and in the pool, and
-- out_hi throws up spray. out_lo sways the ferns and heaves the pool. a
-- note at its pitch flashes in the pool: a fish turning silver (the first
-- motif), a pebble glinting (the second), a fish leaping (the third), a
-- ring spreading (the fourth). the bloom is daylight on the woods and the
-- mist; the bar breathes in the falling water; a swell swells the fall and
-- raises the pool. a passing moment lights the mist over the pool. now and
-- then a kingfisher dives, a rainbow stands in the spray, or a log drifts
-- across the pool
return function(K)
  local M = {}
  local put, A, clamp, ease = K.put, K.A, K.clamp, K.ease
  local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs

  M.incidents = {{"kingfisher", 14}, {"rainbow", 20}, {"log", 22}}

  local POOL = 51                         -- the pool's surface
  local SRC_Y = 7                         -- the lip at the top of the fall
  local LY = {14, 23, 32, 41}             -- the ledges' heights
  local MARK_MAX = 6
  local marks
  local fall = 0                          -- how far the water has fallen (px)
  local LED = {}                          -- the ledges this frame: centre, half width, presence
  for i = 1, 4 do LED[i] = {64 + (i - 2.5) * 6, 8, 0} end

  -- the woods above the cliff: crowns against a pale strip of sky
  local woods = K.crowns(501, 14, 9, 2, 8, 4, 8)
  local canopy = K.bake(function(rec)
    for x = 0, 127, 2 do
      local t = floor(woods(x) + 0.5)
      for y = math.max(0, t), 8 do
        if K.hash(x * 16 + y, 502) < 0.5 then rec(1, x, y, 2, 1) end
      end
      rec(1.6, x, math.max(0, t), 2, 1)
    end
  end)
  -- the rock face: brushed strokes, cracks and moss, baked once
  local rock = K.bake(function(rec)
    local k = 0
    for y = 9, POOL - 1 do
      local x = 0
      while x < 128 do
        k = k + 1
        local len = 2 + floor(6 * K.hash(k, 503))
        local d = 0.09 + 0.13 * sin(x * 0.11 + y * 0.37) + 0.12 * sin(x * 0.04 - y * 0.2)
        if K.hash(k, 504) < d then rec(K.hash(k, 505) < 0.15 and 2 or 1, x, y, len, 1) end
        x = x + len + 1 + floor(3 * K.hash(k, 506))
      end
    end
  end)
  -- a branch reaching out over the pool from the left
  local BR = {}
  for k = 0, 14 do BR[#BR + 1] = {k * 2, 41 + k * 0.25 + sin(k * 0.7) * 0.6} end
  -- ferns close by, bottom corners: {x, y, dir, length, phase}
  local FERN = {{2, 63, 1, 13, 0.2}, {7, 63, 1, 10, 1.4}, {12, 63, 1, 8, 2.6}, {125, 63, -1, 14, 3.3}, {120, 63, -1, 10, 4.1}, {115, 63, -1, 8, 5}}
  local POOLGLINT = K.scatter(30, 4, POOL + 2, 124, 62, 507)

  function M.init() marks, fall = {}, 0 end
  function M.clear() marks = {} end

  function M.note(slot, midi)
    local x = K.px(midi)
    local y = POOL + 10 - K.pu(midi) * 7
    K.cap_add(marks, {slot = slot, x = x, y = y, t0 = K.T, dir = K.rnd() < 0.5 and -1 or 1}, MARK_MAX)
  end

  local function ledges()
    for i = 1, 4 do
      local m, p = K.chord_at(i)
      local L = LED[i]
      -- (a ledge whose tone has gone keeps its place: only its lip fades)
      if m then
        L[1] = 64 + (K.cx(m) - 64) * 0.32
        L[2] = clamp(8 + (60 - m) * 0.18, 6, 13)
      end
      L[3] = m and p or 0
    end
  end

  -- one stretch of the falling sheet, from y0 down to y1 between x0 and x1
  local function sheet(x0, x1, y0, y1, a, bright)
    if x1 - x0 < 2 or y1 - y0 < 2 then return end
    local mid, nat = A[K.MID], A[K.NAT]
    local h = y1 - y0
    -- (columns keep to an even grid, so a ledge sliding never shifts them all)
    for x = floor(x0 / 2) * 2, floor(x1) - 1, 2 do
      local c = x * 7 + 3
      -- the sheet's body, then streaks running down it
      put((1.1 + 0.5 * bright) * a + K.bj(c) * 0.5, x + (x // 2) % 2, y0, 1, h)
      local sp = 0.85 + 0.3 * K.hash(c, 508)
      for q = 0, 1 do
        local yy = y0 + (fall * sp + K.hash(c + q, 509) * h * 3) % h
        local len = 2 + floor(2 * K.hash(c + q, 510) + mid * 3)
        local l = (3 + bright + mid * 3.5 * K.hash(c + q * 5, 511)) * a
        -- (the light catching the falling water: out_hi)
        local g = sin(yy * 0.7 + x * 1.9 + K.T * 2)
        if g > 0.5 then l = l + A[K.HI] * 6 * (g - 0.5) end
        put(l, x + q % 2, yy, 1, math.min(len, y1 - yy))
      end
    end
    -- white water where it lands
    local w = (2 + 4.5 * nat + 1.5 * K.sw_disp) * a
    for x = floor(x0) - 1, floor(x1), 3 do
      local f = sin(x * 1.3 + K.T * 7)
      put(w * (0.6 + 0.4 * f) + K.bj(x), x, y1 - 1 - (f > 0.5 and 1 or 0), 3, 1)
    end
  end

  local function sample(u, v)
    if v < 0.5 then
      local L = LED[4]
      return L[1] - 16 + u * 32, POOL - 2 - v * 24
    end
    return 4 + u * 120, POOL + 2 + (v - 0.5) * 20
  end

  function M.draw()
    local T = K.T
    local bloom, breath, sw = K.bloom, K.breath, K.sw_disp
    local hi, mid, nat, lo = A[K.HI], A[K.MID], A[K.NAT], A[K.LO]
    fall = fall + (7 + 9 * A[K.AMP] + 3 * sw) * K.DTS
    ledges()
    -- the woods and a little sky above the cliff
    for y = 0, 5 do K.dither_row((0.25 + 0.35 * bloom + 0.4 * breath) * (1 - y / 7), y, nil, 0, 128) end
    K.blit(canopy, 1 + 0.6 * bloom, sin(T * 0.25) * (0.4 + nat))
    K.blit(rock, 1 + 0.3 * bloom)
    -- the fall: from the top lip down over each ledge into the pool; a
    -- swell widens it
    local ma = K.moment_age
    local sun = ma < 15 and ease(ma / 3) * (1 - ease((ma - 10) / 5)) or 0
    local bright = 0.6 * bloom + 1.4 * breath + 1.2 * K.energy + 2.5 * sun
    local grow = 1 + 0.3 * sw
    local px0, px1, py, pa = 64 - 6 * grow, 64 + 6 * grow, SRC_Y, 1
    put(3 + bloom, 56, SRC_Y - 1, 16, 1)
    for i = 1, 4 do
      local L = LED[i]
      do
        local a = L[3]
        -- the water falls from the stretch above onto this ledge
        local sx = sin(T * 0.6 + i) * 0.6 * lo
        sheet(px0 + sx, px1 + sx, py, LY[i], pa, bright)
        -- the ledge's lip, catching the light, and its shelf into the rock
        local hw = L[2] * (0.8 + 0.2 * a)
        local ll = (2.6 + 0.8 * bloom + 2.5 * K.chord_glow) * a
        put(ll + K.bj(i * 9), L[1] - hw, LY[i], hw * 2, 1)
        put(ll * 0.55, L[1] - hw - 6, LY[i] + 1, hw * 2 + 12, 1)
        put(ll * 0.35, L[1] - hw, LY[i] + 2, hw * 2, 1)
        px0, px1, py = L[1] - hw * 0.7 * grow, L[1] + hw * 0.7 * grow, LY[i] + 1
        pa = 1
      end
    end
    sheet(px0, px1, py, POOL, pa, bright)
    -- the pool: its surface heaving, rings spreading from the plunge, the
    -- sky's light on it
    local pl = POOL - floor(sw * 2 + 0.5)
    K.streaks(2 + bloom + breath * 1.5, pl, 9, 12, K.drift_x * 0.2)
    local cx = (px0 + px1) * 0.5
    for y = pl + 2, 63, 3 do
      local d = (y - pl) / 13
      local gap = 9 + floor(d * 6)
      local off = K.drift_x * 0.3 + y * 5 + T * 2
      for x = off % gap - gap, 127, gap do
        local w = sin(x * 0.12 + y * 0.8 - T * 0.9) + 0.5 * sin(x * 0.05 - T * 0.3)
        local near = math.max(0, 1 - abs(x - cx) / 30)
        local l = 1 + (w > 0.4 and 1 or 0) + near * (1.5 + 2.5 * nat) + 0.5 * bloom
        if w > -0.4 or near > 0.3 then put(l + K.bj(floor(x) + y * 3), x, y + K.heave(x) * 0.4 * (0.5 + lo), 3 + floor(near * 3), 1) end
      end
    end
    -- the plunge: foam boiling where the fall lands
    for k = 0, 6 do
      local x = cx - 10 + k * 3 + sin(T * 3 + k) * 1.5
      put((2.5 + 3.5 * nat + 2 * sw) * (1 - abs(k - 3) / 4) + K.bj(k), x, pl + 1 + (k % 2), 3, 1)
    end
    K.twinkle(POOLGLINT, hi, 12)
    -- spray thrown up round the plunge, riding out_hi
    if hi > 0.03 then
      for k = 1, 26 do
        local u = (T * (0.5 + 0.4 * K.hash(k, 512)) + K.hash(k, 513)) % 1
        local x = cx + (K.hash(k, 514) - 0.5) * (18 + 14 * u) + sin(T + k) * 2
        local y = pl - 1 - sin(u * math.pi) * (5 + 9 * K.hash(k, 515))
        put(hi * 8 * (1 - u), x, y, 1 + (k % 3 == 0 and 1 or 0), 1)
      end
    end
    -- the branch over the pool
    for _, b in ipairs(BR) do put(2.6 + bloom, b[1], b[2] + sin(T * 0.5) * 0.3 * b[1] / 28, 2, 1) end
    -- the ferns, close by
    for i, f in ipairs(FERN) do
      local sway = sin(T * 0.7 + f[5]) * (0.5 + 1.5 * nat) + K.heave(f[1]) * (0.5 + 0.8 * lo)
      for j = 1, f[4] do
        local u = j / f[4]
        local x = f[1] + f[3] * (j * 0.9) + sway * u * u
        local y = f[2] - j * 1.3 + u * u * 6
        put((2.5 + bloom) * (1 - u * 0.3) + K.bj(i * 16 + j) * 0.5, x, y, 1, 1)
        if j % 2 == 0 then put(2 + bloom, x - f[3], y - 2, 1, 2); put(2 + bloom, x + f[3], y + 1, 2, 1) end
      end
    end
    -- the notes: flashes in the pool
    for i = #marks, 1, -1 do
      local mk = marks[i]
      local age = T - mk.t0
      local cf, done = K.cap_fade(mk)
      if age > 4.5 or done then table.remove(marks, i)
      else
        local e = ease(age / 0.15) * (1 - ease((age - 1.8) / 2.6)) * cf
        local x, y, d = mk.x, mk.y, mk.dir
        put(2.5 * e, x - 4, y + 2, 9, 1)                  -- (its light in the water)
        if mk.slot == 1 then
          -- a fish turns, flashing silver along its flank
          local turn = math.max(0, sin(age * 3)) * e
          put(6 * e + 5 * turn, x - 4 + d * age * 3, y, 9, 1)
          put(5 * e + 3 * turn, x - 3 + d * age * 3, y - 1, 7, 1)
          put(4 * e, x + 4 * d + d * age * 3 - (d < 0 and 1 or 0), y - 1, 1, 3)
        elseif mk.slot == 2 then
          -- a pebble on the bottom glints
          local g = e * (0.6 + 0.4 * sin(age * 6))
          put(9.5 * g, x - 1, y, 3, 2)
          put(6 * g, x - 4, y, 2, 1); put(6 * g, x + 3, y, 2, 1)
          put(5 * g, x - 3, y, 1, 1); put(5 * g, x + 3, y + 1, 1, 1); put(5 * g, x, y - 2, 1, 1); put(5 * g, x, y + 3, 1, 1)
        elseif mk.slot == 3 then
          -- a small fish leaps and falls back, rings where it lands
          local a = clamp(age / 0.9, 0, 1)
          if a < 1 then
            local fx, fy = x - 4 + a * 8, pl - 1 - sin(a * math.pi) * 8
            put(9 * e, fx - 1, fy, 4, 1); put(5 * e, fx - 2, fy + 1, 2, 1)
          end
          local ra = age - 0.9
          if ra > 0 then K.ring(x + 4, pl + 2, 1.5 + ra * 4, 0.35, 7 * e, 16) end
        else
          -- a ring spreading on the surface
          K.ring(x, y - 3, 1.5 + age * 4.5, 0.35, 8 * e, 18)
          K.ring(x, y - 3, 1 + age * 2.5, 0.35, 5 * e, 10)
        end
      end
    end
    -- the moment: the mist over the pool lights up and rises
    if sun > 0 then
      local e = sun
      -- (rows stay put: the glow's shape rises through them, so the light
      -- changes stroke by stroke and never slides a whole row)
      local cy = POOL - 6 - ma * 1.1
      for y = 24, POOL, 2 do
        local d = (y - cy) / 11
        local v = e * (0.9 + 0.6 * bloom) * math.max(0, 1 - d * d)
        if v > 0.05 then
          local hw = 20 + (POOL - y) * 0.6
          K.dither_row(v, y, nil, floor(cx - hw), floor(cx + hw))
        end
      end
    end
    -- incidents
    local inc = K.inc
    if inc then
      local e, u = inc.e, inc.u
      if inc.name == "kingfisher" then
        -- a kingfisher on the branch, then a dive and away low over the pool
        local bx, by = 20 + inc.s * 6, 40
        local dive = clamp((inc.age - 0.55 * inc.dur) / 1.2, 0, 1)
        local pe = e * (1 - ease(dive / 0.4))
        if pe > 0.01 then
          local bob = sin(inc.age * 2) > 0.9 and 1 or 0
          put(9 * pe, bx - 2, by - 4 + bob, 5, 4); put(10 * pe, bx + 2, by - 5 + bob, 3, 3)
          put(8 * pe, bx + 5, by - 4 + bob, 3, 1)                      -- the bill
          put(6 * pe, bx - 3, by - 2 + bob, 2, 1)                      -- the tail
          put(10 * pe, bx, by - 1 + bob, 2, 1)                         -- its bright breast
        end
        if dive > 0 then
          local de = e * ease(dive / 0.3)
          local x = bx + dive * 30
          local y = by + sin(dive * math.pi) * 6 + dive * 4
          local d1 = de * (1 - ease((dive - 0.45) / 0.2))
          if d1 > 0.01 then put(9.5 * d1, x - 3, y - 1, 6, 2); put(8 * d1, x + 3, y, 3, 1) end
          local ra = (dive - 0.5) * 3
          if ra > 0 then K.ring(bx + 18, pl + 2, 1.5 + ra * 5, 0.35, 6 * de * math.max(0, 1 - ra / 3), 18) end
          local d2 = de * ease((dive - 0.55) / 0.25)
          if d2 > 0.01 then K.bird(bx + 18 + (dive - 0.55) * 100, pl - 6 - (dive - 0.55) * 18, 8 * d2, sin(K.NOW * 14), 2) end
        end
      elseif inc.name == "rainbow" then
        -- a rainbow standing in the spray: three soft bands, eased in and out
        local r0 = 20 + inc.s * 4
        for b = 0, 2 do
          local r = r0 + b * 2.5
          local lv = e * (3.6 - b * 0.6) * (0.85 + 0.15 * sin(inc.age * 0.7 + b))
          for k = 0, 22 do
            local a = math.pi * (0.12 + 0.76 * k / 22)
            local x, y = cx - cos(a) * r * 1.3, pl + 2 - sin(a) * r
            if k % 2 == b % 2 or b == 1 then put(lv + K.bj(k * 3 + b), x, y, 2, 1) end
          end
        end
      else
        -- a log drifts slowly across the pool, turning a little
        local x = -20 + u * 160
        local y = pl + 4 + inc.s2 * 4 + sin(inc.age * 0.5) * 0.8
        put(5 * e, x - 9, y, 18, 2); put(6.5 * e, x - 9, y, 18, 1)
        put(4 * e, x + 9, y, 2, 2); put(7 * e, x - 10, y, 1, 2)
        put(5.5 * e, x - 3, y - 1, 2, 1)
        put(2 * e, x - 8, y + 3, 16, 1)
      end
    end
    K.glitter(sample, 22)
  end

  M.init()
  return M
end
